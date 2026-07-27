"""
DRAP Recall Loader & Scraper
Loads recalls from the local JSON dataset and provides a placeholder scraper
for the live DRAP recalls page.
"""
import json
import os
from datetime import datetime
from typing import Optional

# In-memory recall storage
_recalls: list[dict] = []
_recalls_by_reg: dict[str, list[dict]] = {}
_recalls_by_name: dict[str, list[dict]] = {}
_recalls_loaded = False

# Path to JSON dataset
_DATA_DIR = os.path.dirname(os.path.abspath(__file__))
_JSON_PATH = os.path.join(_DATA_DIR, "drap_recalls.json")


def load_recalls(json_path: Optional[str] = None) -> list[dict]:
    """Load recalls from the JSON dataset into memory."""
    global _recalls, _recalls_by_reg, _recalls_by_name, _recalls_loaded

    if _recalls_loaded:
        return _recalls

    path = json_path or _JSON_PATH

    if os.path.exists(path):
        try:
            with open(path, "r", encoding="utf-8") as f:
                _recalls = json.load(f)

            # Build indexes
            for recall in _recalls:
                reg = str(recall.get("registration_number", "")).strip()
                if reg:
                    _recalls_by_reg.setdefault(reg, []).append(recall)

                name_key = recall.get("medicine_name", "").lower().strip()
                if name_key:
                    _recalls_by_name.setdefault(name_key, []).append(recall)

            print(f"[Recall Loader] Loaded {len(_recalls)} recalls from JSON")

        except Exception as e:
            print(f"Error loading recalls from JSON: {e}")
            _load_sample_data()
    else:
        print(f"[Recall Loader] JSON not found at {path}, using sample data")
        _load_sample_data()

    _recalls_loaded = True
    return _recalls


def _load_sample_data():
    """Fallback sample recall data."""
    global _recalls, _recalls_by_reg, _recalls_by_name

    _recalls = [
        {
            "id": "RC-2026-001",
            "recall_class": "CLASS_I",
            "medicine_name": "XYZ Cough Syrup",
            "registration_number": "999001",
            "batch_numbers": ["B2026-001", "B2026-002"],
            "recall_reason": "Contamination with diethylene glycol detected during post-market surveillance.",
            "recall_date": "2026-02-15",
            "drap_notice_number": "DRAP/QA/2026/001",
            "is_active": True,
            "manufacturer": "Unknown",
            "affected_regions": [],
        },
        {
            "id": "RC-2026-002",
            "recall_class": "CLASS_II",
            "medicine_name": "ABC Antibiotic Capsules",
            "registration_number": "999002",
            "batch_numbers": ["B2025-045"],
            "recall_reason": "Subpotent active ingredient detected.",
            "recall_date": "2026-02-20",
            "drap_notice_number": "DRAP/QA/2026/002",
            "is_active": True,
            "manufacturer": "Unknown",
            "affected_regions": [],
        },
    ]

    for recall in _recalls:
        reg = recall.get("registration_number", "")
        _recalls_by_reg.setdefault(reg, []).append(recall)
        name_key = recall.get("medicine_name", "").lower()
        _recalls_by_name.setdefault(name_key, []).append(recall)


# ---------------------------------------------------------------------------
# Lookup functions
# ---------------------------------------------------------------------------

def _ensure_loaded():
    if not _recalls_loaded:
        load_recalls()


def check_recall_by_registration_number(reg_number: str) -> list[dict]:
    """Check if a registration number has any active recalls."""
    _ensure_loaded()
    reg = reg_number.strip()
    recalls = _recalls_by_reg.get(reg, [])
    return [r for r in recalls if r.get("is_active", False)]


def check_recall_by_name(medicine_name: str) -> list[dict]:
    """
    Check if a medicine name has any active recalls.
    Uses substring matching so partial names work.
    """
    _ensure_loaded()
    query = medicine_name.lower().strip()
    results = []
    seen_ids = set()

    # Check exact key match
    for name_key, recalls in _recalls_by_name.items():
        if query in name_key or name_key in query:
            for r in recalls:
                if r.get("is_active", False) and r["id"] not in seen_ids:
                    results.append(r)
                    seen_ids.add(r["id"])

    return results


def check_recall_for_batch(reg_number: str, batch_number: str) -> Optional[dict]:
    """Check if a specific batch is under active recall."""
    _ensure_loaded()
    reg = reg_number.strip()
    batch = batch_number.strip()

    # Check by registration number first
    for recall in _recalls_by_reg.get(reg, []):
        if recall.get("is_active", False):
            if batch in recall.get("batch_numbers", []):
                return recall

    # Also check all recalls for the batch number
    for recall in _recalls:
        if recall.get("is_active", False) and batch in recall.get("batch_numbers", []):
            return recall

    return None


def check_recall_for_product(brand_name: str) -> list[dict]:
    """Check if any recall exists for this product name (backward-compatible)."""
    return check_recall_by_name(brand_name)


def get_all_active_recalls() -> list[dict]:
    """Return all currently active recalls."""
    _ensure_loaded()
    return [r for r in _recalls if r.get("is_active", False)]


def has_active_recall(medicine_name: str = "", reg_number: str = "") -> bool:
    """Quick boolean check: does this medicine have any active recall?"""
    if reg_number:
        if check_recall_by_registration_number(reg_number):
            return True
    if medicine_name:
        if check_recall_by_name(medicine_name):
            return True
    return False


# ---------------------------------------------------------------------------
# Live scraper placeholder
# ---------------------------------------------------------------------------

async def scrape_drap_recalls() -> list[dict]:
    """
    Scrape the live DRAP recall portal for the latest recalls.
    URL: https://www.dra.gov.pk/recalls-safety-alerts/

    This is a placeholder implementation. In production, it would:
    1. Fetch the page with httpx
    2. Parse the HTML with BeautifulSoup
    3. Extract recall entries from the table/list
    4. Merge with local data

    Returns the locally loaded recalls for now.
    """
    _ensure_loaded()

    try:
        import httpx
        from bs4 import BeautifulSoup

        async with httpx.AsyncClient(timeout=15.0) as client:
            response = await client.get(
                "https://www.dra.gov.pk/recalls-safety-alerts/",
                follow_redirects=True,
            )
            if response.status_code == 200:
                soup = BeautifulSoup(response.text, "html.parser")

                # Placeholder: parse the page structure
                # The actual structure needs to be inspected and adapted.
                # Example parsing logic:
                #
                # table = soup.find("table", class_="recall-table")
                # if table:
                #     rows = table.find_all("tr")[1:]  # skip header
                #     for row in rows:
                #         cols = row.find_all("td")
                #         if len(cols) >= 4:
                #             recall = {
                #                 "id": cols[0].get_text(strip=True),
                #                 "medicine_name": cols[1].get_text(strip=True),
                #                 "recall_reason": cols[2].get_text(strip=True),
                #                 "recall_date": cols[3].get_text(strip=True),
                #                 "is_active": True,
                #                 "source": "live_scrape",
                #             }
                #             scraped_recalls.append(recall)

                print("[Recall Scraper] Successfully fetched DRAP recalls page")
            else:
                print(f"[Recall Scraper] HTTP {response.status_code} from DRAP portal")

    except ImportError:
        print("[Recall Scraper] httpx/beautifulsoup4 not installed; skipping live scrape")
    except Exception as e:
        print(f"[Recall Scraper] Error scraping DRAP portal: {e}")

    # Always return local data (would merge with scraped data in production)
    return _recalls
