"""
Medicine Price Fetcher
Loads price data from the local JSON dataset and provides price lookups
with generic alternative suggestions. Includes a placeholder scraper for dawaai.pk.
"""
import json
import os
from typing import Optional

# In-memory price database
_price_database: dict[str, dict] = {}
_price_by_generic: dict[str, list[dict]] = {}
_prices_loaded = False

# Path to JSON dataset
_DATA_DIR = os.path.dirname(os.path.abspath(__file__))
_JSON_PATH = os.path.join(_DATA_DIR, "price_database.json")


def load_price_database(json_path: Optional[str] = None) -> dict:
    """Load price data from JSON file into memory."""
    global _price_database, _price_by_generic, _prices_loaded

    if _prices_loaded:
        return _price_database

    path = json_path or _JSON_PATH

    if os.path.exists(path):
        try:
            with open(path, "r", encoding="utf-8") as f:
                prices = json.load(f)

            for entry in prices:
                brand_key = entry.get("brand_name", "").lower().strip()
                if not brand_key:
                    continue

                record = {
                    "brand_name": entry.get("brand_name", ""),
                    "generic_name": entry.get("generic_name", ""),
                    "manufacturer": entry.get("manufacturer", ""),
                    "dosage_form": entry.get("dosage_form", ""),
                    "strength": entry.get("strength", ""),
                    "pack_size": entry.get("pack_size", ""),
                    "mrp": entry.get("mrp", 0),
                    "generic_alternatives": entry.get("generic_alternatives", []),
                }

                _price_database[brand_key] = record

                # Index by generic name for cross-lookups
                generic_key = record["generic_name"].lower().strip()
                if generic_key:
                    _price_by_generic.setdefault(generic_key, []).append(record)

            print(f"[Price Fetcher] Loaded {len(_price_database)} price entries from JSON")

        except Exception as e:
            print(f"Error loading price database: {e}")
            _load_inline_data()
    else:
        print(f"[Price Fetcher] JSON not found at {path}, using inline data")
        _load_inline_data()

    _prices_loaded = True
    return _price_database


def _load_inline_data():
    """Inline sample price data as fallback."""
    global _price_database, _price_by_generic

    inline_data = [
        {
            "brand_name": "Panadol",
            "generic_name": "Paracetamol",
            "manufacturer": "GlaxoSmithKline",
            "dosage_form": "Tablet",
            "strength": "500mg",
            "pack_size": "100 tablets",
            "mrp": 250,
            "generic_alternatives": [
                {"brand_name": "Panol", "manufacturer": "Searle", "mrp": 120},
                {"brand_name": "Paracip", "manufacturer": "Cipla", "mrp": 95},
            ],
        },
        {
            "brand_name": "Brufen",
            "generic_name": "Ibuprofen",
            "manufacturer": "Abbott",
            "dosage_form": "Tablet",
            "strength": "400mg",
            "pack_size": "30 tablets",
            "mrp": 195,
            "generic_alternatives": [
                {"brand_name": "Ibugesic", "manufacturer": "Sami Pharma", "mrp": 95},
                {"brand_name": "Ibucap", "manufacturer": "Captek Pharma", "mrp": 80},
            ],
        },
        {
            "brand_name": "Augmentin",
            "generic_name": "Co-Amoxiclav",
            "manufacturer": "GlaxoSmithKline",
            "dosage_form": "Tablet",
            "strength": "625mg",
            "pack_size": "6 tablets",
            "mrp": 620,
            "generic_alternatives": [
                {"brand_name": "Clavumax", "manufacturer": "Searle", "mrp": 380},
                {"brand_name": "Novaclav", "manufacturer": "Novartis", "mrp": 400},
            ],
        },
        {
            "brand_name": "Azomax",
            "generic_name": "Azithromycin",
            "manufacturer": "Hilton Pharma",
            "dosage_form": "Tablet",
            "strength": "500mg",
            "pack_size": "3 tablets",
            "mrp": 420,
            "generic_alternatives": [
                {"brand_name": "Zetro", "manufacturer": "Getz Pharma", "mrp": 350},
                {"brand_name": "Azithral", "manufacturer": "Alembic", "mrp": 280},
            ],
        },
    ]

    for entry in inline_data:
        brand_key = entry["brand_name"].lower()
        _price_database[brand_key] = entry
        generic_key = entry["generic_name"].lower()
        _price_by_generic.setdefault(generic_key, []).append(entry)


# ---------------------------------------------------------------------------
# Lookup functions
# ---------------------------------------------------------------------------

def _ensure_loaded():
    if not _prices_loaded:
        load_price_database()


async def fetch_price(medicine_name: str, pack_size: Optional[str] = None) -> Optional[dict]:
    """
    Fetch current MRP for a medicine by brand name.
    Returns price record with generic alternatives.
    """
    _ensure_loaded()
    key = medicine_name.lower().strip()

    # Exact match
    if key in _price_database:
        return _price_database[key]

    # Substring match
    for db_key, record in _price_database.items():
        if key in db_key or db_key in key:
            return record

    return None


def get_price_sync(medicine_name: str) -> Optional[dict]:
    """Synchronous version of fetch_price for non-async contexts."""
    _ensure_loaded()
    key = medicine_name.lower().strip()

    if key in _price_database:
        return _price_database[key]

    for db_key, record in _price_database.items():
        if key in db_key or db_key in key:
            return record

    return None


async def get_generic_alternatives(medicine_name: str) -> list[dict]:
    """Get generic alternatives with prices for a brand-name medicine."""
    _ensure_loaded()
    key = medicine_name.lower().strip()

    # Try direct brand lookup
    data = _price_database.get(key)
    if data:
        return data.get("generic_alternatives", [])

    # Substring fallback
    for db_key, record in _price_database.items():
        if key in db_key or db_key in key:
            return record.get("generic_alternatives", [])

    return []


def get_price_and_alternatives(medicine_name: str) -> dict:
    """
    Get price info and generic alternatives in one call.
    Returns: {"brand": {...}, "alternatives": [...], "potential_savings": float}
    """
    _ensure_loaded()
    key = medicine_name.lower().strip()
    data = None

    if key in _price_database:
        data = _price_database[key]
    else:
        for db_key, record in _price_database.items():
            if key in db_key or db_key in key:
                data = record
                break

    if not data:
        return {"brand": None, "alternatives": [], "potential_savings": 0}

    alternatives = data.get("generic_alternatives", [])
    brand_mrp = data.get("mrp", 0)

    # Calculate potential savings vs cheapest generic
    cheapest = min((a.get("mrp", 0) for a in alternatives), default=brand_mrp)
    savings = max(0, brand_mrp - cheapest)

    return {
        "brand": {
            "brand_name": data.get("brand_name"),
            "generic_name": data.get("generic_name"),
            "manufacturer": data.get("manufacturer"),
            "strength": data.get("strength"),
            "pack_size": data.get("pack_size"),
            "mrp": brand_mrp,
        },
        "alternatives": alternatives,
        "potential_savings": savings,
    }


def get_all_by_generic(generic_name: str) -> list[dict]:
    """Get all brands with pricing for a given generic / salt name."""
    _ensure_loaded()
    key = generic_name.lower().strip()
    return _price_by_generic.get(key, [])


# ---------------------------------------------------------------------------
# Live scraper placeholder
# ---------------------------------------------------------------------------

async def scrape_dawaai_price(medicine_name: str) -> Optional[dict]:
    """
    Placeholder scraper for dawaai.pk price data.

    In production, this would:
    1. Search dawaai.pk for the medicine
    2. Parse the product page for pricing
    3. Return structured price data

    Returns None for now (falls back to local data).
    """
    try:
        import httpx
        from bs4 import BeautifulSoup

        async with httpx.AsyncClient(timeout=15.0) as client:
            search_url = f"https://dawaai.pk/search?q={medicine_name}"
            response = await client.get(search_url, follow_redirects=True)

            if response.status_code == 200:
                soup = BeautifulSoup(response.text, "html.parser")

                # Placeholder parsing logic:
                # product_cards = soup.find_all("div", class_="product-card")
                # for card in product_cards:
                #     name = card.find("h3").get_text(strip=True)
                #     price = card.find("span", class_="price").get_text(strip=True)
                #     return {"brand_name": name, "mrp": float(price.replace("Rs.", "").strip())}

                print(f"[Price Scraper] Fetched dawaai.pk page for '{medicine_name}'")
            else:
                print(f"[Price Scraper] HTTP {response.status_code} from dawaai.pk")

    except ImportError:
        print("[Price Scraper] httpx/beautifulsoup4 not installed; skipping live scrape")
    except Exception as e:
        print(f"[Price Scraper] Error scraping dawaai.pk: {e}")

    return None
