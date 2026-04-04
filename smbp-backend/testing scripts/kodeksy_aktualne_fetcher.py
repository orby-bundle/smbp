#!/usr/bin/env python3
"""
Polish Sejm API - Kodeksy Aktualne Fetcher
Fetches legislative acts from the Polish Sejm API for years 2001-2025,
filters for acts containing "kodeks" in the title and with type "Obwieszczenie",
and downloads PDFs to /kodeksy-aktualne directory.
If title-cleaned is the same, keeps only the newer file based on promulgation date.
"""

import os
import re
import json
from datetime import datetime
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
		print(f"Failed to retrieve data for year {year}: HTTP {response.status_code}")
		return None
	except requests.exceptions.RequestException as error:
		print(f"Request failed for year {year}: {error}")
		return None
	except json.JSONDecodeError as error:
		print(f"Failed to parse JSON response for year {year}: {error}")
		return None


def filter_kodeks_obwieszczenia(acts: List[Dict]) -> List[Dict]:
	"""Return acts where title contains 'kodeks' and '-' and type is exactly 'Obwieszczenie' and status is not 'wygaśnięcie aktu'."""
	filtered: List[Dict] = []
	for act in acts:
		title = act.get("title", "")
		type_name = act.get("type", "")
		status = act.get("status", "")
		if "kodeks" in title.lower() and " - " in title and type_name == "Obwieszczenie" and status != "wygaśnięcie aktu":
			filtered.append(act)
	return filtered


def ensure_directory(path: str) -> bool:
	"""Create directory if it does not exist. Returns True on success, False otherwise."""
	try:
		os.makedirs(path, exist_ok=True)
		return True
	except OSError as error:
		print(f"Cannot create directory '{path}': {error}")
		return False


def build_pdf_url(year: int, pos: int) -> str:
	"""Construct PDF URL per API: /acts/{publisher}/{year}/{position}/text/{type}/{fileName}"""
	publisher = "DU"
	pos_4digits = f"{pos:04d}"
	fileName = f"D{year}{pos_4digits}Lj.pdf"
	return f"https://api.sejm.gov.pl/eli/acts/{publisher}/{year}/{pos}/text/U/{fileName}"


def build_html_url(year: int, pos: int) -> str:
	"""Construct HTML URL per API: /acts/{publisher}/{year}/{position}/text/{type}/{fileName}"""
	publisher = "DU"
	pos_4digits = f"{pos:04d}"
	fileName = f"D{year}{pos_4digits}Lj.html"
	return f"https://api.sejm.gov.pl/eli/acts/{publisher}/{year}/{pos}/text/H/{fileName}"


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


def get_existing_files_with_same_title(save_dir: str, title_cleaned: str, file_extension: str = ".pdf") -> List[str]:
	"""Get list of existing files with the same title_cleaned and extension."""
	if not os.path.exists(save_dir):
		return []
	
	existing_files = []
	for filename in os.listdir(save_dir):
		if filename.endswith(f"_{sanitize_filename(title_cleaned)}{file_extension}"):
			existing_files.append(filename)
	return existing_files


def should_keep_newer_file(existing_files: List[str], new_promulgation: str) -> bool:
	"""Check if we should keep the new file (True) or skip it (False)."""
	if not existing_files:
		return True
	
	# Extract promulgation dates from existing files
	existing_promulgations = []
	for filename in existing_files:
		parts = filename.split('_')
		if len(parts) >= 1:
			existing_promulgations.append(parts[0])
	
	# If any existing file has a newer promulgation date, skip the new file
	for existing_promulgation in existing_promulgations:
		if existing_promulgation > new_promulgation:
			return False
	
	return True


def remove_older_files(save_dir: str, existing_files: List[str], new_promulgation: str) -> None:
	"""Remove older files with the same title_cleaned."""
	for filename in existing_files:
		parts = filename.split('_')
		if len(parts) >= 1:
			existing_promulgation = parts[0]
			if existing_promulgation < new_promulgation:
				filepath = os.path.join(save_dir, filename)
				try:
					os.remove(filepath)
					print(f"Removed older file: {filename}")
				except OSError as error:
					print(f"Failed to remove {filename}: {error}")


def download_file(year: int, pos: int, title: str, promulgation: str, save_dir: str, file_type: str = "pdf") -> Optional[str]:
	"""Download a file (PDF or HTML) for a given act. Returns path on success, None on failure."""
	if not ensure_directory(save_dir):
		return None
	title_cleaned = extract_title_after_dash(title)
	file_extension = f".{file_type}"
	
	# Check for existing files with same title_cleaned
	existing_files = get_existing_files_with_same_title(save_dir, title_cleaned, file_extension)
	
	# Check if we should keep this file
	if not should_keep_newer_file(existing_files, promulgation):
		print(f"Skipping older file: {promulgation}_{pos}_{sanitize_filename(title_cleaned)}{file_extension}")
		return None
	
	# Remove older files if any
	remove_older_files(save_dir, existing_files, promulgation)
	
	# Download the new file
	filename = f"{promulgation}_{pos}_{sanitize_filename(title_cleaned)}{file_extension}"
	filepath = os.path.join(save_dir, filename)
	
	# Build URLs based on file type
	if file_type == "pdf":
		urls_to_try = [
			build_pdf_url(year, pos),  # New format
			f"https://api.sejm.gov.pl/eli/acts/DU/{year}/{pos}/text.pdf"  # Old format fallback
		]
		expected_content_type = "application/pdf"
	elif file_type == "html":
		urls_to_try = [
			build_html_url(year, pos),  # New format
			f"https://api.sejm.gov.pl/eli/acts/DU/{year}/{pos}/text.html"  # Old format fallback
		]
		expected_content_type = "text/html"
	else:
		print(f"Unsupported file type: {file_type}")
		return None
	
	for url in urls_to_try:
		try:
			resp = requests.get(url, timeout=60)
			if resp.status_code == 200 and resp.headers.get("Content-Type", "").lower().startswith(expected_content_type):
				with open(filepath, "wb") as f:
					f.write(resp.content)
				print(f"Downloaded {file_type.upper()} using URL: {url}")
				return filepath
			if resp.status_code == 200 and resp.content:
				with open(filepath, "wb") as f:
					f.write(resp.content)
				print(f"Downloaded {file_type.upper()} using URL: {url}")
				return filepath
		except requests.exceptions.RequestException as error:
			print(f"Download failed for pos={pos} with URL {url}: {error}")
			continue
	
	print(f"Failed to download {file_type.upper()} for pos={pos} with all URL formats")
	return None


def download_pdf(year: int, pos: int, title: str, promulgation: str, save_dir: str) -> Optional[str]:
	"""Download the PDF for a given act. Returns path on success, None on failure."""
	return download_file(year, pos, title, promulgation, save_dir, "pdf")


def download_html(year: int, pos: int, title: str, promulgation: str, save_dir: str) -> Optional[str]:
	"""Download the HTML for a given act. Returns path on success, None on failure."""
	return download_file(year, pos, title, promulgation, save_dir, "html")



def main() -> None:
	"""Main function to execute the script."""
	save_dir = "/kodeksy-aktualne"
	html_dir = "/kodeksy-html"
	json_dir = "/kodeksy-json"
	base_dir = os.path.dirname(os.path.abspath(__file__))
	
	# Ensure target directory or fallback to project-local directory if not writable
	if not ensure_directory(save_dir):
		fallback_dir = os.path.join(base_dir, "kodeksy-aktualne")
		print(f"Falling back to local directory: {fallback_dir}")
		save_dir = fallback_dir
		if not ensure_directory(save_dir):
			print("Failed to prepare any writable output directory. Exiting.")
			return
	
	# Ensure HTML directory or fallback to project-local directory if not writable
	if not ensure_directory(html_dir):
		fallback_html_dir = os.path.join(base_dir, "kodeksy-html")
		print(f"Falling back to local HTML directory: {fallback_html_dir}")
		html_dir = fallback_html_dir
		if not ensure_directory(html_dir):
			print("Failed to prepare any writable HTML directory. Exiting.")
			return
	
	# Ensure JSON directory or fallback to project-local directory if not writable
	if not ensure_directory(json_dir):
		fallback_json_dir = os.path.join(base_dir, "kodeksy-json")
		print(f"Falling back to local JSON directory: {fallback_json_dir}")
		json_dir = fallback_json_dir
		if not ensure_directory(json_dir):
			print("Failed to prepare any writable JSON directory. Exiting.")
			return
	current_year = datetime.now().year
	start_year = 1918
	
	print("Polish Sejm API - Kodeksy Aktualne Fetcher")
	print("=" * 60)
	print(f"Fetching acts from {start_year} to {current_year}")
	print(f"Saving PDFs to: {save_dir}")
	print(f"Saving HTMLs to: {html_dir}")
	print(f"Saving JSONs to: {json_dir}")
	print("=" * 60)
	
	total_acts_found = 0
	total_pdf_downloads = 0
	total_html_downloads = 0
	
	for year in range(start_year, current_year + 1):
		acts = fetch_acts_for_year(year)
		if acts is None:
			continue
		
		filtered = filter_kodeks_obwieszczenia(acts)
		total_acts_found += len(filtered)
		
		if filtered:
			print(f"\nYear {year}: Found {len(filtered)} kodeks obwieszczenia")
			
			# Save JSON for this year
			json_filename = f"kodeks_obwieszczenia_{year}.json"
			json_filepath = os.path.join(json_dir, json_filename)
			try:
				with open(json_filepath, "w", encoding="utf-8") as f:
					json.dump(filtered, f, ensure_ascii=False, indent=2)
				print(f"Saved JSON: {json_filepath}")
			except Exception as error:
				print(f"Failed to save JSON for year {year}: {error}")
			
			year_pdf_downloads = 0
			year_html_downloads = 0
			for act in filtered:
				pos = act.get("pos")
				title = act.get("title", f"act_{pos}")
				promulgation = act.get("promulgation", "")
				text_html = act.get("textHTML", False)
				
				try:
					pos_int = int(pos)
				except Exception:
					print(f"Skipping invalid position value: {pos}")
					continue
				
				# Download PDF
				saved_pdf_path = download_pdf(year, pos_int, title, promulgation, save_dir)
				if saved_pdf_path:
					print(f"Saved PDF: {os.path.basename(saved_pdf_path)}")
					year_pdf_downloads += 1
					total_pdf_downloads += 1
				
				# Download HTML if available
				if text_html:
					saved_html_path = download_html(year, pos_int, title, promulgation, html_dir)
					if saved_html_path:
						print(f"Saved HTML: {os.path.basename(saved_html_path)}")
						year_html_downloads += 1
						total_html_downloads += 1
			
			print(f"Year {year}: Downloaded {year_pdf_downloads}/{len(filtered)} PDFs, {year_html_downloads}/{len(filtered)} HTMLs")
	
	print(f"\n" + "=" * 60)
	print(f"SUMMARY:")
	print(f"Total acts found: {total_acts_found}")
	print(f"Total PDF downloads: {total_pdf_downloads}")
	print(f"Total HTML downloads: {total_html_downloads}")
	print(f"PDFs saved to: {save_dir}")
	print(f"HTMLs saved to: {html_dir}")
	print("=" * 60)


if __name__ == "__main__":
	main()
