"""
DRAP Database Loader
Loads the DRAP registered medicines JSON database into memory.
Provides fast search by name, registration number, barcode, and generic name
with fuzzy matching support.
"""
import json
import logging
import os
from difflib import SequenceMatcher, get_close_matches
from typing import Optional

logger = logging.getLogger(__name__)

# In-memory DRAP database
_drap_database: dict = {}
_drap_by_brand: dict[str, list[dict]] = {}
_drap_by_generic: dict[str, list[dict]] = {}
_drap_by_barcode: dict[str, dict] = {}
_all_brand_names: list[str] = []
_drap_loaded = False

# Generic drugs database (922 generics from pakistandrugindex)
_generic_database: dict[str, dict] = {}
_generic_loaded = False

# Path to JSON datasets
_DATA_DIR = os.path.dirname(os.path.abspath(__file__))
_JSON_PATH = os.path.join(_DATA_DIR, "drap_medicines.json")
_GENERIC_JSON_PATH = os.path.join(_DATA_DIR, "generic_drugs_database.json")


def load_drap_database(json_path: Optional[str] = None) -> dict:
    """Load DRAP registered medicines from JSON file into memory."""
    global _drap_database, _drap_by_brand, _drap_by_generic, _drap_by_barcode
    global _all_brand_names, _drap_loaded

    if _drap_loaded:
        return _drap_database

    path = json_path or _JSON_PATH

    if os.path.exists(path):
        try:
            with open(path, "r", encoding="utf-8") as f:
                medicines = json.load(f)

            for med in medicines:
                reg_num = str(med.get("registration_number", "")).strip()
                if not reg_num:
                    continue

                record = {
                    "registration_number": reg_num,
                    "brand_name": str(med.get("brand_name", "")).strip(),
                    "generic_name": str(med.get("generic_name", "")).strip(),
                    "manufacturer": str(med.get("manufacturer", "")).strip(),
                    "active_ingredients": med.get("active_ingredients", []),
                    "dosage_form": str(med.get("dosage_form", "")).strip(),
                    "strength": str(med.get("strength", "")).strip(),
                    "pack_size": str(med.get("pack_size", "")).strip(),
                    "mrp": med.get("mrp"),
                    "registration_date": med.get("registration_date"),
                    "expiry_date": med.get("expiry_date"),
                    "status": str(med.get("status", "Active")).strip(),
                    "barcode": str(med.get("barcode", "")).strip(),
                }

                # Index by registration number
                _drap_database[reg_num] = record

                # Index by brand name (lowercase) for fast lookup
                brand_key = record["brand_name"].lower()
                if brand_key:
                    _drap_by_brand.setdefault(brand_key, []).append(record)
                    if record["brand_name"] not in _all_brand_names:
                        _all_brand_names.append(record["brand_name"])

                # Index by generic name (lowercase)
                generic_key = record["generic_name"].lower()
                if generic_key:
                    _drap_by_generic.setdefault(generic_key, []).append(record)

                # Index by barcode
                barcode = record.get("barcode", "")
                if barcode:
                    _drap_by_barcode[barcode] = record

            print(f"[DRAP Loader] Loaded {len(_drap_database)} medicines from JSON")

        except Exception as e:
            logger.exception("Error loading DRAP database from JSON")
            _load_sample_data()
    else:
        print(f"[DRAP Loader] JSON not found at {path}, using sample data")
        _load_sample_data()

    _drap_loaded = True
    return _drap_database


def _load_sample_data():
    """Load sample DRAP data for demo/testing."""
    global _drap_database, _drap_by_brand, _drap_by_generic, _all_brand_names

    sample_medicines = [
        {
            "registration_number": "000001",
            "brand_name": "Panadol Extra",
            "generic_name": "Paracetamol + Caffeine",
            "manufacturer": "GlaxoSmithKline Pakistan Limited",
            "active_ingredients": [
                {"name": "Paracetamol", "strength": "500mg"},
                {"name": "Caffeine", "strength": "65mg"},
            ],
            "dosage_form": "Tablet",
            "strength": "500mg/65mg",
            "pack_size": "10 tablets",
            "mrp": 185,
            "status": "Active",
            "barcode": "",
        },
        {
            "registration_number": "000002",
            "brand_name": "Augmentin 625mg",
            "generic_name": "Amoxicillin + Clavulanic Acid",
            "manufacturer": "GlaxoSmithKline Pakistan Limited",
            "active_ingredients": [
                {"name": "Amoxicillin", "strength": "500mg"},
                {"name": "Clavulanic Acid", "strength": "125mg"},
            ],
            "dosage_form": "Tablet",
            "strength": "625mg",
            "pack_size": "6 tablets",
            "mrp": 850,
            "status": "Active",
            "barcode": "",
        },
        {
            "registration_number": "000003",
            "brand_name": "Brufen 400mg",
            "generic_name": "Ibuprofen",
            "manufacturer": "Abbott Laboratories Pakistan Limited",
            "active_ingredients": [{"name": "Ibuprofen", "strength": "400mg"}],
            "dosage_form": "Tablet",
            "strength": "400mg",
            "pack_size": "20 tablets",
            "mrp": 180,
            "status": "Active",
            "barcode": "",
        },
        {
            "registration_number": "000004",
            "brand_name": "Azomax 500mg",
            "generic_name": "Azithromycin",
            "manufacturer": "Hilton Pharma Private Limited",
            "active_ingredients": [{"name": "Azithromycin", "strength": "500mg"}],
            "dosage_form": "Tablet",
            "strength": "500mg",
            "pack_size": "3 tablets",
            "mrp": 420,
            "status": "Active",
            "barcode": "",
        },
        {
            "registration_number": "000005",
            "brand_name": "Flagyl 400mg",
            "generic_name": "Metronidazole",
            "manufacturer": "Sanofi-Aventis Pakistan Limited",
            "active_ingredients": [{"name": "Metronidazole", "strength": "400mg"}],
            "dosage_form": "Tablet",
            "strength": "400mg",
            "pack_size": "20 tablets",
            "mrp": 150,
            "status": "Active",
            "barcode": "",
        },
    ]

    for med in sample_medicines:
        reg = med["registration_number"]
        _drap_database[reg] = med
        brand_key = med["brand_name"].lower()
        _drap_by_brand.setdefault(brand_key, []).append(med)
        _all_brand_names.append(med["brand_name"])
        generic_key = med["generic_name"].lower()
        _drap_by_generic.setdefault(generic_key, []).append(med)


# ---------------------------------------------------------------------------
# Search functions
# ---------------------------------------------------------------------------

def _ensure_loaded():
    """Ensure database is loaded before any search."""
    if not _drap_loaded:
        load_drap_database()


def search_by_name(query: str, fuzzy: bool = True, limit: int = 20) -> list[dict]:
    """
    Search by brand name with optional fuzzy matching.
    First tries exact substring match, then falls back to fuzzy if enabled.
    """
    _ensure_loaded()
    query_lower = query.lower().strip()
    results = []

    # Exact substring matches first
    for brand_key, meds in _drap_by_brand.items():
        if query_lower in brand_key:
            results.extend(meds)

    if results:
        return results[:limit]

    # Fuzzy matching using difflib
    if fuzzy:
        all_keys = list(_drap_by_brand.keys())
        close_matches = get_close_matches(query_lower, all_keys, n=10, cutoff=0.5)
        for match_key in close_matches:
            results.extend(_drap_by_brand[match_key])

    return results[:limit]


def search_by_registration_number(reg_number: str) -> Optional[dict]:
    """Search by exact registration number."""
    _ensure_loaded()
    return _drap_database.get(reg_number.strip())


def search_by_barcode(barcode: str) -> Optional[dict]:
    """Search by barcode string."""
    _ensure_loaded()
    return _drap_by_barcode.get(barcode.strip())


def search_by_generic_name(generic_name: str, limit: int = 20) -> list[dict]:
    """Search by generic / salt name. Returns all brands with that generic."""
    _ensure_loaded()
    query_lower = generic_name.lower().strip()
    results = []

    # Exact key match
    if query_lower in _drap_by_generic:
        results.extend(_drap_by_generic[query_lower])
        return results[:limit]

    # Substring match across generic names
    for key, meds in _drap_by_generic.items():
        if query_lower in key or key in query_lower:
            results.extend(meds)

    if not results:
        # Fuzzy fallback
        all_keys = list(_drap_by_generic.keys())
        close_matches = get_close_matches(query_lower, all_keys, n=5, cutoff=0.5)
        for match_key in close_matches:
            results.extend(_drap_by_generic[match_key])

    return results[:limit]


def search_drap(query: str) -> list[dict]:
    """
    General-purpose search across all fields.
    Searches brand name, generic name, manufacturer, and registration number.
    """
    _ensure_loaded()
    query_lower = query.lower().strip()
    results = []
    seen_regs = set()

    for reg_num, med in _drap_database.items():
        if (
            query_lower in med.get("brand_name", "").lower()
            or query_lower in med.get("generic_name", "").lower()
            or query_lower in med.get("manufacturer", "").lower()
            or query_lower in reg_num.lower()
        ):
            if reg_num not in seen_regs:
                results.append(med)
                seen_regs.add(reg_num)

    # If no exact matches, try fuzzy on brand names
    if not results:
        fuzzy_results = search_by_name(query, fuzzy=True, limit=20)
        return fuzzy_results

    return results[:20]


def get_medicine_by_reg(reg_number: str) -> Optional[dict]:
    """Get medicine details by registration number."""
    _ensure_loaded()
    return _drap_database.get(reg_number.strip())


def get_all_brand_names() -> list[str]:
    """Return all known brand names (for autocomplete / typeahead)."""
    _ensure_loaded()
    return _all_brand_names.copy()


def get_database_size() -> int:
    """Return number of medicines in the database."""
    _ensure_loaded()
    return len(_drap_database)


# ---------------------------------------------------------------------------
# Generic Drugs Database (922 generics from pakistandrugindex)
# ---------------------------------------------------------------------------

def _load_generic_database():
    """Load the 922 generic drugs database."""
    global _generic_database, _generic_loaded

    if _generic_loaded:
        return

    if os.path.exists(_GENERIC_JSON_PATH):
        try:
            with open(_GENERIC_JSON_PATH, "r", encoding="utf-8") as f:
                generics = json.load(f)
            for drug in generics:
                name = drug.get("generic_name", "").lower().strip()
                if name:
                    _generic_database[name] = drug
            print(f"[DRAP Loader] Loaded {len(_generic_database)} generic drugs")
        except Exception as e:
            logger.exception("Error loading generic drugs database")

    _generic_loaded = True


def get_generic_info(generic_name: str) -> Optional[dict]:
    """Look up clinical info for a generic drug (therapeutic class, pregnancy, etc)."""
    _load_generic_database()
    query = generic_name.lower().strip()

    # Exact match
    if query in _generic_database:
        return _generic_database[query]

    # Substring match
    for key, data in _generic_database.items():
        if query in key or key in query:
            return data

    # Fuzzy match
    matches = get_close_matches(query, list(_generic_database.keys()), n=1, cutoff=0.6)
    if matches:
        return _generic_database[matches[0]]

    return None


def get_therapeutic_class(generic_name: str) -> Optional[str]:
    """Get therapeutic class for a generic drug."""
    info = get_generic_info(generic_name)
    return info.get("therapeutic_class") if info else None


def get_pregnancy_safety(generic_name: str) -> Optional[dict]:
    """Get pregnancy safety data for a generic drug."""
    info = get_generic_info(generic_name)
    return info.get("pregnancy") if info else None


def is_controlled_substance(generic_name: str) -> bool:
    """Check if a drug is a controlled substance."""
    info = get_generic_info(generic_name)
    if info and info.get("addiction"):
        return info["addiction"].get("controlled_substance", False)
    return False


def get_total_database_size() -> dict:
    """Return size of both databases."""
    _ensure_loaded()
    _load_generic_database()
    return {
        "branded_medicines": len(_drap_database),
        "generic_drugs": len(_generic_database),
        "total": len(_drap_database) + len(_generic_database),
    }


# ---------------------------------------------------------------------------
# OpenFDA / Extended Drug Data
# ---------------------------------------------------------------------------

_openfda_drugs: list[dict] = []
_openfda_loaded = False
_drug_interactions: list[dict] = []
_interactions_loaded = False
_drug_conditions: dict = {}
_conditions_loaded = False


def _load_openfda():
    """Load OpenFDA drug labels (massive dataset)."""
    global _openfda_drugs, _openfda_loaded
    if _openfda_loaded:
        return
    # Try massive first, fallback to original
    for fname in ["openfda_drugs_massive.json", "openfda_drugs.json"]:
        path = os.path.join(_DATA_DIR, fname)
        if os.path.exists(path):
            try:
                with open(path, "r", encoding="utf-8") as f:
                    _openfda_drugs = json.load(f)
                print(f"[DRAP Loader] Loaded {len(_openfda_drugs)} OpenFDA drug labels from {fname}")
                break
            except Exception as e:
                logger.exception("Error loading OpenFDA data from '%s'", fname)
    _openfda_loaded = True


def get_openfda_info(drug_name: str) -> list[dict]:
    """Search OpenFDA data for a drug by generic name."""
    _load_openfda()
    query = drug_name.lower().strip()
    results = []
    for drug in _openfda_drugs:
        gn = drug.get("generic_name", "").lower()
        brands = [b.lower() for b in drug.get("brand_names", [])]
        if query in gn or any(query in b for b in brands):
            results.append(drug)
    return results[:5]


def _load_drug_interactions():
    """Load drug interactions database."""
    global _drug_interactions, _interactions_loaded
    if _interactions_loaded:
        return
    path = os.path.join(_DATA_DIR, "drug_interactions.json")
    if os.path.exists(path):
        try:
            with open(path, "r", encoding="utf-8") as f:
                _drug_interactions = json.load(f)
            print(f"[DRAP Loader] Loaded {len(_drug_interactions)} drug interactions")
        except Exception as e:
            logger.exception("Error loading drug interactions database")
    _interactions_loaded = True


def check_drug_interactions(drug_name: str) -> list[dict]:
    """Find known interactions for a drug."""
    _load_drug_interactions()
    query = drug_name.lower().strip()
    results = []
    for interaction in _drug_interactions:
        if query in interaction.get("drug_a", "").lower() or query in interaction.get("drug_b", "").lower():
            results.append(interaction)
    return results


def _load_drug_conditions():
    """Load drug-condition mapping."""
    global _drug_conditions, _conditions_loaded
    if _conditions_loaded:
        return
    path = os.path.join(_DATA_DIR, "drug_conditions.json")
    if os.path.exists(path):
        try:
            with open(path, "r", encoding="utf-8") as f:
                data = json.load(f)
                _drug_conditions = data.get("conditions", {})
            print(f"[DRAP Loader] Loaded {len(_drug_conditions)} condition-drug mappings")
        except Exception as e:
            logger.exception("Error loading drug conditions database")
    _conditions_loaded = True


def get_conditions_for_drug(drug_name: str) -> list[str]:
    """Find which conditions a drug is used for."""
    _load_drug_conditions()
    query = drug_name.lower().strip()
    conditions = []
    for condition, data in _drug_conditions.items():
        for key, value in data.items():
            if isinstance(value, list):
                for item in value:
                    if isinstance(item, str) and query in item.lower():
                        conditions.append(condition)
                        break
    return list(set(conditions))


def get_full_database_stats() -> dict:
    """Return comprehensive statistics of all loaded data."""
    _ensure_loaded()
    _load_generic_database()
    _load_openfda()
    _load_drug_interactions()
    _load_drug_conditions()

    # Count other datasets
    recalls_count = 0
    prices_count = 0
    for fname, key in [("drap_recalls.json", "recalls"), ("price_database.json", "prices")]:
        path = os.path.join(_DATA_DIR, fname)
        if os.path.exists(path):
            try:
                with open(path, "r", encoding="utf-8") as f:
                    data = json.load(f)
                    if key == "recalls":
                        recalls_count = len(data)
                    else:
                        prices_count = len(data)
            except Exception:
                logger.exception("Failed to load data file '%s'", fname)

    return {
        "branded_medicines": len(_drap_database),
        "generic_drugs": len(_generic_database),
        "openfda_drug_labels": len(_openfda_drugs),
        "drug_interactions": len(_drug_interactions),
        "condition_mappings": len(_drug_conditions),
        "recalls": recalls_count,
        "price_entries": prices_count,
        "total_data_points": (
            len(_drap_database) + len(_generic_database) +
            len(_openfda_drugs) + len(_drug_interactions) +
            len(_drug_conditions) + recalls_count + prices_count
        ),
    }
