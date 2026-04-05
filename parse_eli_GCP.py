import os
import re
import sys
import tempfile
import threading
import time
import urllib.error
import urllib.request
from datetime import date, datetime


from typing import Any, Dict, Optional
from docling.datamodel.accelerator_options import AcceleratorDevice, AcceleratorOptions
from docling.datamodel.base_models import InputFormat
from docling.datamodel.pipeline_options import PdfPipelineOptions, ThreadedPdfPipelineOptions
from docling.document_converter import DocumentConverter, PdfFormatOption

# Threaded pipeline uses larger batches for layout (better MPS/GPU utilization).
try:
    from docling.pipeline.threaded_standard_pdf_pipeline import ThreadedStandardPdfPipeline
except ImportError:
    ThreadedStandardPdfPipeline = None  # type: ignore[misc, assignment]

from docling.datamodel.settings import settings

# Clean the parsed markdown file in place
def clean_markdown_file(file_path: str) -> None:
    """Normalize docling Markdown in place (same rules as clean_md.py)."""
    with open(file_path, encoding="utf-8") as f:
        content = f.read()

    content = re.sub(r"<!-- image -->\n*", "", content)

    content = re.sub(
        r"^(?:-\s+|\d+\.\s+)?(§\s*\d+[a-z]*\.)",
        r"### \1",
        content,
        flags=re.MULTILINE,
    )
    content = re.sub(
        r"^(?:-\s+|\d+\.\s+)?(Art\.\s*\d+[a-z]*\.)",
        r"### \1",
        content,
        flags=re.MULTILINE,
    )

    content = re.sub(
        r"^\d+\.\s+((?:'|\")?\d+\))",
        r"\1",
        content,
        flags=re.MULTILINE,
    )
    content = re.sub(r"^-\s+(\d+\))", r"\1", content, flags=re.MULTILINE)
    content = re.sub(r"^-\s+(\d+\.\s+)", r"\1", content, flags=re.MULTILINE)
    content = re.sub(r"\n{3,}", "\n\n", content)
    content = re.sub(r"^['\"](\d+\))", r"\1", content, flags=re.MULTILINE)

    with open(file_path, "w", encoding="utf-8") as f:
        f.write(content)


CATEGORIES = ("DU", "MP")

# Default Firebase/GCS bucket; override with env GCS_BUCKET if needed.
_DEFAULT_GCS_BUCKET = "smbp-ios.firebasestorage.app"

_GCS_IMPORT_WARNED = False

# macOS Apple Silicon: use PyTorch MPS (Metal). Else AUTO (CUDA/XPU/CPU as available).
_ACCEL_DEVICE = AcceleratorDevice.MPS if sys.platform == "darwin" else AcceleratorDevice.AUTO
_NUM_THREADS = min(8, os.cpu_count() or 8)

# Rolling estimate of conversion seconds per PDF page (updated after each doc).
_ema_sec_per_page: Optional[float] = None


def _doc_status(msg: str, *, done: bool = False) -> None:
    """One terminal line: reuse \\r so each phase replaces the previous for the same doc."""
    width = 100
    padded = (msg + " " * max(0, width - len(msg)))[:width]
    print(f"\r{padded}", end="\n" if done else "", flush=True)


def _pdf_page_count(path: str) -> Optional[int]:
    """Best-effort page count before conversion (pypdf or PyPDF2 if installed)."""
    try:
        from pypdf import PdfReader

        return len(PdfReader(path).pages)
    except Exception:
        pass
    try:
        from PyPDF2 import PdfReader

        return len(PdfReader(path).pages)
    except Exception:
        return None


def _run_convert_with_live_status(
    converter: DocumentConverter,
    tmp_pdf: str,
    out_md: str,
) -> Any:
    """
    While docling runs (no built-in progress in older versions), refresh one status line:
    elapsed time, optional page count, optional ETA from prior documents' pace.
    """
    global _ema_sec_per_page

    pages_before = _pdf_page_count(tmp_pdf)
    stop = threading.Event()
    t_start = time.time()

    def _tick() -> None:
        while not stop.wait(0.25):
            elapsed = time.time() - t_start
            base = f" \u270F Converting {os.path.basename(out_md)} — {elapsed:.1f}s"
            bits = [base]
            if pages_before is not None:
                bits.append(f"{pages_before} pages")
            if (
                _ema_sec_per_page is not None
                and pages_before is not None
                and pages_before > 0
            ):
                est = _ema_sec_per_page * pages_before
                bits.append(f"est ~{est:.0f}s")
            _doc_status(" | ".join(bits))

    _doc_status(
        f" \u270F Converting {os.path.basename(out_md)} — 0.0s"
        + (f" | {pages_before} pages" if pages_before is not None else "")
    )
    worker = threading.Thread(target=_tick, daemon=True)
    worker.start()
    try:
        result = converter.convert(tmp_pdf)
    finally:
        stop.set()
        worker.join(timeout=2.0)

    conv_elapsed = time.time() - t_start
    n_pages: Optional[int] = None
    pages_attr = getattr(result, "pages", None)
    if pages_attr is not None:
        try:
            n_pages = len(pages_attr)
        except TypeError:
            n_pages = None
    if not n_pages:
        n_pages = pages_before
    if n_pages and n_pages > 0:
        sp = conv_elapsed / n_pages
        if _ema_sec_per_page is None:
            _ema_sec_per_page = sp
        else:
            _ema_sec_per_page = 0.35 * sp + 0.65 * _ema_sec_per_page

    return result


def build_document_converter() -> DocumentConverter:
    accelerator_options = AcceleratorOptions(
        num_threads=_NUM_THREADS,
        device=_ACCEL_DEVICE,
    )

    if ThreadedStandardPdfPipeline is not None:
        pipeline_options = ThreadedPdfPipelineOptions(
            accelerator_options=accelerator_options,
            layout_batch_size=64,
            ocr_batch_size=4,
            table_batch_size=4,
        )
        pipeline_options.do_ocr = False
        converter = DocumentConverter(
            format_options={
                InputFormat.PDF: PdfFormatOption(
                    pipeline_cls=ThreadedStandardPdfPipeline,
                    pipeline_options=pipeline_options,
                )
            }
        )
        converter.initialize_pipeline(InputFormat.PDF)
    else:
        pipeline_options = PdfPipelineOptions()
        pipeline_options.accelerator_options = accelerator_options
        pipeline_options.do_ocr = False
        converter = DocumentConverter(
            format_options={
                InputFormat.PDF: PdfFormatOption(
                    pipeline_options=pipeline_options,
                )
            }
        )

    _dev = accelerator_options.device
    _device_label = _dev.value if hasattr(_dev, "value") else str(_dev)
    print(
        f" \u26A1 Accelerator: {_device_label} ({accelerator_options.num_threads} threads)"
    )

    return converter


def fetch_pdf_to_temp(url: str) -> Optional[str]:
    """Download PDF to a temp file; return path, or None if not available (404 / non-200)."""
    try:
        req = urllib.request.Request(url)
        with urllib.request.urlopen(req) as resp:
            if resp.status != 200:
                return None
            data = resp.read()
    except urllib.error.HTTPError:
        return None

    with tempfile.NamedTemporaryFile(suffix=".pdf", delete=False) as tmp:
        tmp.write(data)
        return tmp.name


def _upload_md_to_gcs(
    local_path: str,
    gcs_bucket: str,
    object_name: str,
) -> bool:
    """
    Upload a local file to GCS. object_name uses forward slashes, e.g. DU/DU_2026/DU_2026_1.md.
    Returns True on success, False on failure or missing dependency.
    """
    global _GCS_IMPORT_WARNED
    try:
        from google.cloud import storage
    except ImportError:
        if not _GCS_IMPORT_WARNED:
            print(
                "\nWarning: google-cloud-storage not installed; "
                "pip install google-cloud-storage for GCS upload."
            )
            _GCS_IMPORT_WARNED = True
        return False

    client = storage.Client()
    bucket = client.bucket(gcs_bucket)
    blob = bucket.blob(object_name)
    blob.upload_from_filename(local_path, content_type="text/markdown; charset=utf-8")
    return True


def main() -> None:
    if os.environ.get("DOCLING_PROFILE"):
        settings.debug.profile_pipeline_timings = True

    year_str = str(date.today().year)
    gcs_bucket = os.environ.get("GCS_BUCKET", _DEFAULT_GCS_BUCKET)

    converter = build_document_converter()
    total_elapsed = 0.0
    gcs_enabled = os.environ.get("GCS_UPLOAD", "1").lower() not in ("0", "false", "no")
    per_category: Dict[str, Dict[str, int]] = {
        cat: {"converted": 0, "submitted": 0} for cat in CATEGORIES
    }

    for category in CATEGORIES:
        output_dir = f"{category}_{year_str}"
        os.makedirs(output_dir, exist_ok=True)
        base_url = f"https://eli.gov.pl/api/acts/{category}/{year_str}/{{n}}/text.pdf"

        print(f"\n--- {category} ({year_str}) → local ./{output_dir}/ & gs://{gcs_bucket}/{category}/ ---")

        n = 1
        while True:
            filename = f"{category}_{year_str}_{n}.md"
            out_md = os.path.join(output_dir, filename)
            if os.path.isfile(out_md):
                n += 1
                continue

            url = base_url.format(n=n)
            _doc_status(f" [{category}] Fetching {url}...")
            t0 = time.time()
            tmp_pdf = fetch_pdf_to_temp(url)
            if tmp_pdf is None:
                _doc_status(f" [{category}] Stopped at {n}: not found or non-200.", done=True)
                break

            try:
                result = _run_convert_with_live_status(converter, tmp_pdf, out_md)
                with open(out_md, "w", encoding="utf-8") as f:
                    f.write(result.document.export_to_markdown())

                clean_markdown_file(out_md)
                per_category[category]["converted"] += 1

                gcs_object = f"{category}/{category}_{year_str}/{filename}"
                gcs_note = ""
                if gcs_enabled:
                    if _upload_md_to_gcs(out_md, gcs_bucket, gcs_object):
                        per_category[category]["submitted"] += 1
                        gcs_note = f" + gs://{gcs_bucket}/{gcs_object}"
            finally:
                os.unlink(tmp_pdf)

            elapsed = time.time() - t0
            total_elapsed += elapsed
            _doc_status(
                f" \u2705 {out_md} in {elapsed:.1f}s{gcs_note}",
                done=True,
            )
            n += 1

    if total_elapsed > 0:
        print(f"\nTotal conversion time (this run): {total_elapsed:.1f}s")

    print(f"\n--- Summary ({datetime.now().strftime('%Y-%m-%d %H:%M:%S')}) ---")
    for cat in CATEGORIES:
        c = per_category[cat]["converted"]
        s = per_category[cat]["submitted"]
        if gcs_enabled:
            print(f"  {cat}:  converted: {c}  |  submitted: {s}")
            print()
        else:
            print(f"  {cat}:  converted: {c}  |  GCS upload: disabled")


if __name__ == "__main__":
    main()
