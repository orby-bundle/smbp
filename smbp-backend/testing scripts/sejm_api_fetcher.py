#!/usr/bin/env python3
"""
Polish Sejm API Fetcher
Fetches legislative acts from the Polish Sejm API for year 2025,
filters for acts containing "kodeks" in the title and with type "Obwieszczenie",
and downloads PDFs for the matched acts using the documented endpoint pattern
https://api.sejm.gov.pl/eli/acts/DU/{year}/{pos}/text.pdf
"""

import os
import re
import json
from typing import List, Dict, Optional

import requests


def fetch_acts_for_year(year: int) -> Optional[List[Dict]]:
	"""Fetch all legislative acts from Dziennik Ustaw for a given year."""
	url = f"https://api.sejm.gov.pl/eli/acts/DU/{year}"
	try:
		print(f"Fetching acts for year {year}...")
		response = requests.get(url, timeout=30)
		if response.status_code == 200:
			data = response.json()
			acts = data.get("items", [])
			print(f"Successfully fetched {len(acts)} acts for {year}")
			return acts
		print(f"Failed to retrieve data: HTTP {response.status_code}")
		print(f"Response: {response.text}")
		return None
	except requests.exceptions.RequestException as error:
		print(f"Request failed: {error}")
		return None
	except json.JSONDecodeError as error:
		print(f"Failed to parse JSON response: {error}")
		return None


def filter_kodeks_obwieszczenia(acts: List[Dict]) -> List[Dict]:
	"""Return acts where title contains 'kodeks' and type is exactly 'Obwieszczenie'."""
	filtered: List[Dict] = []
	for act in acts:
		title = act.get("title", "")
		type_name = act.get("type", "")
		if "kodeks" in title.lower() and type_name == "Obwieszczenie":
			filtered.append(act)
	return filtered


def ensure_directory(path: str) -> None:
	"""Create directory if it does not exist."""
	os.makedirs(path, exist_ok=True)


def build_pdf_url(year: int, pos: int) -> str:
	"""Construct PDF URL per API: https://api.sejm.gov.pl/eli/acts/DU/{year}/{pos}/text.pdf"""
	return f"https://api.sejm.gov.pl/eli/acts/DU/{year}/{pos}/text.pdf"


def sanitize_filename(text: str) -> str:
	"""Sanitize a string to be safe for filenames."""
	sanitized = re.sub(r"\s+", "_", text.strip())
	sanitized = re.sub(r"[^\w.-]", "", sanitized)
	return sanitized[:140]


def extract_title_after_dash(title: str) -> str:
	"""Extract the part after '-' in the title for title-cleaned."""
	if " - " in title:
		return title.split(" - ", 1)[1].strip()
	return title


def download_pdf(year: int, pos: int, title: str, promulgation: str, out_dir: str) -> Optional[str]:
	"""Download the PDF for a given act. Returns path on success, None on failure."""
	url = build_pdf_url(year, pos)
	ensure_directory(out_dir)
	title_cleaned = extract_title_after_dash(title)
	filename = f"{promulgation}_{pos}_{sanitize_filename(title_cleaned)}.pdf"
	out_path = os.path.join(out_dir, filename)
	try:
		resp = requests.get(url, timeout=60)
		if resp.status_code == 200 and resp.headers.get("Content-Type", "").lower().startswith("application/pdf"):
			with open(out_path, "wb") as f:
				f.write(resp.content)
			return out_path
		if resp.status_code == 200 and resp.content:
			with open(out_path, "wb") as f:
				f.write(resp.content)
			return out_path
		print(f"Failed to download PDF for pos={pos}: HTTP {resp.status_code}")
		return None
	except requests.exceptions.RequestException as error:
		print(f"Download failed for pos={pos}: {error}")
		return None


def display_acts(acts: List[Dict]) -> None:
	"""Display filtered acts."""
	if not acts:
		print("No acts found containing 'kodeks' with type 'Obwieszczenie'.")
		return
	print(f"\nFound {len(acts)} act(s) containing 'kodeks' with type 'Obwieszczenie':")
	print("=" * 80)
	for index, act in enumerate(acts, 1):
		print(f"\n{index}. {act.get('title', 'No title')}")
		print(f"   Position: {act.get('pos', 'N/A')}")
		print(f"   Publication Date: {act.get('promulgation', 'N/A')}")
		print(f"   Status: {act.get('status', 'N/A')}")
		print(f"   ELI: {act.get('ELI', 'N/A')}")
		if 'year' in act:
			print(f"   Year: {act['year']}")
		if 'type' in act:
			print(f"   Type: {act['type']}")
		print("-" * 40)


def main() -> None:
	year = 2025
	out_dir = os.path.join("pdfs", "Obwieszczenie")

	print("Polish Sejm API - Kodeks Obwieszczenia Fetcher")
	print("=" * 50)

	acts = fetch_acts_for_year(year)
	if acts is None:
		print("Failed to fetch acts. Please check your internet connection and try again.")
		return

	filtered = filter_kodeks_obwieszczenia(acts)
	display_acts(filtered)

	if filtered:
		output_file = f"kodeks_obwieszczenia_{year}.json"
		try:
			with open(output_file, "w", encoding="utf-8") as f:
				json.dump(filtered, f, ensure_ascii=False, indent=2)
			print(f"\nFiltered results saved to {output_file}")
		except Exception as error:
			print(f"Failed to save results to file: {error}")

	if filtered:
		print("\nDownloading PDFs for matched acts...")
		ensure_directory(out_dir)
		success_count = 0
		for act in filtered:
			pos = act.get("pos")
			title = act.get("title", f"act_{pos}")
			promulgation = act.get("promulgation", "")
			try:
				pos_int = int(pos)
			except Exception:
				print(f"Skipping invalid position value: {pos}")
				continue
			saved_path = download_pdf(year, pos_int, title, promulgation, out_dir)
			if saved_path:
				print(f"Saved: {saved_path}")
				success_count += 1
		print(f"\nPDF download complete. {success_count}/{len(filtered)} files saved to {out_dir}")


if __name__ == "__main__":
	main()
