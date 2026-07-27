"""
WHO AWaRe Classification & Pediatric Safety Loader
Loads WHO antibiotic classification data and pediatric safety information
from local JSON datasets. Provides both class-based and function-based APIs.
"""
import json
import logging
import os
from difflib import get_close_matches
from typing import Optional

logger = logging.getLogger(__name__)

_DATA_DIR = os.path.dirname(os.path.abspath(__file__))


# ---------------------------------------------------------------------------
# WHO AWaRe Loader (class-based, preserved from original)
# ---------------------------------------------------------------------------

class WHOAWaReLoader:
    """Loads and queries WHO AWaRe antibiotic classification data."""

    _data: Optional[dict] = None
    _brand_index: Optional[dict] = None

    @classmethod
    def _load(cls) -> None:
        if cls._data is not None:
            return
        filepath = os.path.join(_DATA_DIR, "who_aware.json")
        try:
            with open(filepath, "r", encoding="utf-8") as f:
                raw = json.load(f)
            cls._data = {}
            cls._brand_index = {}
            for entry in raw.get("antibiotics", []):
                name = entry.get("name", "").strip().lower()
                if name:
                    cls._data[name] = entry
                # Index by Pakistani brand names
                for brand in entry.get("common_brands_pakistan", []):
                    cls._brand_index[brand.lower().strip()] = entry
            logger.info("Loaded %d WHO AWaRe entries", len(cls._data))
        except Exception as exc:
            logger.error("Failed to load WHO AWaRe data: %s", exc)
            cls._data = {}
            cls._brand_index = {}

    @classmethod
    def classify(cls, ingredient_name: str) -> Optional[dict]:
        """
        Look up an ingredient in the WHO AWaRe database.

        Returns a dict with keys: name, category (ACCESS/WATCH/RESERVE),
        description, common_brands_pakistan, resistance_risk, route, common_doses.
        Returns None if the ingredient is not an antibiotic in the database.
        """
        cls._load()
        norm = ingredient_name.strip().lower()

        # Direct match
        if norm in cls._data:
            return cls._data[norm]

        # Partial / substring match
        for key, value in cls._data.items():
            if norm in key or key in norm:
                return value

        # Check brand names
        if norm in cls._brand_index:
            return cls._brand_index[norm]

        # Fuzzy match on generic names
        close = get_close_matches(norm, list(cls._data.keys()), n=1, cutoff=0.7)
        if close:
            return cls._data[close[0]]

        # Fuzzy match on brand names
        close = get_close_matches(norm, list(cls._brand_index.keys()), n=1, cutoff=0.7)
        if close:
            return cls._brand_index[close[0]]

        return None

    @classmethod
    def get_stewardship_message(cls, category: str) -> str:
        """Return stewardship guidance for an AWaRe category."""
        messages = {
            "ACCESS": (
                "This is an ACCESS group antibiotic - first-line treatment for common infections. "
                "It should be widely available, affordable, and quality-assured. "
                "Complete the full course as prescribed."
            ),
            "WATCH": (
                "This is a WATCH group antibiotic with higher resistance potential. "
                "It should only be used for specific indications when Access antibiotics are not suitable. "
                "Using this antibiotic unnecessarily contributes to antimicrobial resistance. "
                "Ensure it was prescribed by a qualified doctor."
            ),
            "RESERVE": (
                "CAUTION: This is a RESERVE group antibiotic - a LAST RESORT treatment. "
                "It should ONLY be used for confirmed multidrug-resistant infections in hospital settings. "
                "Misuse of Reserve antibiotics accelerates the global AMR crisis. "
                "Verify this was prescribed by a specialist for a confirmed resistant infection."
            ),
        }
        return messages.get(category.upper(), "")

    @classmethod
    def get_all_by_category(cls, category: str) -> list[dict]:
        """Get all antibiotics in a given AWaRe category."""
        cls._load()
        cat = category.upper().strip()
        return [v for v in cls._data.values() if v.get("category") == cat]


# ---------------------------------------------------------------------------
# Function-based API for WHO AWaRe (convenience wrappers)
# ---------------------------------------------------------------------------

def classify_antibiotic(name: str) -> Optional[str]:
    """
    Classify an antibiotic into WHO AWaRe categories.
    Returns: "ACCESS", "WATCH", "RESERVE", or None if not found.
    """
    result = WHOAWaReLoader.classify(name)
    if result:
        return result.get("category")
    return None


def get_antibiotic_info(name: str) -> Optional[dict]:
    """
    Get full WHO AWaRe information for an antibiotic.
    Searches by generic name and Pakistani brand names.
    Returns the full info dict or None.
    """
    return WHOAWaReLoader.classify(name)


def get_all_by_category(category: str) -> list[dict]:
    """Get all antibiotics in a given AWaRe category (ACCESS/WATCH/RESERVE)."""
    return WHOAWaReLoader.get_all_by_category(category)


def is_antibiotic(name: str) -> bool:
    """Check if a given drug name is a known antibiotic in the AWaRe list."""
    return WHOAWaReLoader.classify(name) is not None


# ---------------------------------------------------------------------------
# Pediatric Safety Loader (class-based, preserved from original)
# ---------------------------------------------------------------------------

class PediatricSafetyLoader:
    """Loads and queries pediatric safety data from local JSON."""

    _data: Optional[dict] = None

    @classmethod
    def _load(cls) -> None:
        if cls._data is not None:
            return

        filepath = os.path.join(_DATA_DIR, "pediatric_safety.json")

        if os.path.exists(filepath):
            try:
                with open(filepath, "r", encoding="utf-8") as f:
                    raw = json.load(f)
                cls._data = {}
                # Handle multiple JSON structures
                entries = []
                if isinstance(raw, list):
                    entries = raw
                elif isinstance(raw, dict):
                    entries = raw.get("medicines", raw.get("drugs", []))
                    if not entries and not any(k in raw for k in ("medicines", "drugs")):
                        # Dict keyed by drug name
                        for key, val in raw.items():
                            if isinstance(val, dict):
                                val.setdefault("drug_name", key)
                                val.setdefault("generic_name", key)
                                entries.append(val)

                for entry in entries:
                    name = entry.get("generic_name", entry.get("drug_name", entry.get("name", ""))).strip().lower()
                    if name:
                        cls._data[name] = entry
                    # Also index by brand names
                    for brand in entry.get("brand_names", []):
                        cls._data[brand.strip().lower()] = entry

                logger.info("Loaded %d pediatric safety entries from JSON", len(cls._data))
            except Exception as exc:
                logger.error("Failed to load pediatric safety data: %s", exc)
                cls._data = {}
                _load_builtin_pediatric(cls)
        else:
            logger.info("Pediatric safety JSON not found at %s, using built-in data", filepath)
            cls._data = {}
            _load_builtin_pediatric(cls)

    @classmethod
    def lookup(cls, ingredient_name: str) -> Optional[dict]:
        """
        Look up pediatric safety data for a drug.

        Returns a dict with keys like: generic_name, brand_names, safe_for_children,
        minimum_age_months, dosing_by_weight, warnings, contraindications, etc.
        Returns None if not found.
        """
        cls._load()
        norm = ingredient_name.strip().lower()

        # Direct match
        if norm in cls._data:
            return cls._data[norm]

        # Partial match
        for key, value in cls._data.items():
            if norm in key or key in norm:
                return value

        # Fuzzy match
        close = get_close_matches(norm, list(cls._data.keys()), n=1, cutoff=0.6)
        if close:
            return cls._data[close[0]]

        return None

    @classmethod
    def calculate_dose(cls, drug_data: dict, weight_kg: float) -> Optional[dict]:
        """Calculate recommended dose based on weight using the dosing table."""
        dosing_table = drug_data.get("dosing_by_weight", [])
        if not dosing_table:
            return None

        for entry in dosing_table:
            weight_range = entry.get("weight_kg", "")
            try:
                parts = weight_range.split("-")
                low = float(parts[0])
                high = float(parts[1]) if len(parts) > 1 else low + 10
                if low <= weight_kg <= high:
                    return {
                        "weight_range_kg": weight_range,
                        "recommended_dose_mg": entry.get("dose_mg"),
                        "frequency": entry.get("frequency"),
                        "max_daily_doses": drug_data.get("max_daily_doses"),
                        "max_daily_mg_per_kg": drug_data.get("max_daily_mg_per_kg"),
                    }
            except (ValueError, IndexError):
                continue

        # If weight exceeds all ranges, return the last entry with a note
        if dosing_table:
            last = dosing_table[-1]
            return {
                "weight_range_kg": last.get("weight_kg"),
                "recommended_dose_mg": last.get("dose_mg"),
                "frequency": last.get("frequency"),
                "max_daily_doses": drug_data.get("max_daily_doses"),
                "max_daily_mg_per_kg": drug_data.get("max_daily_mg_per_kg"),
                "note": "Weight exceeds dosing table. Consult pediatrician for exact dose.",
            }
        return None


def _load_builtin_pediatric(cls_or_none=None):
    """Load built-in pediatric safety data for common medicines."""
    builtin = {
        "paracetamol": {
            "generic_name": "Paracetamol",
            "drug_name": "Paracetamol",
            "brand_names": ["Panadol", "Calpol", "Tylenol"],
            "safe_for_children": True,
            "minimum_age_months": 2,
            "pediatric_dose": "10-15 mg/kg every 4-6 hours, max 4 doses/day",
            "max_daily_mg_per_kg": 60,
            "max_daily_doses": 4,
            "warnings": ["Do not exceed recommended dose", "Risk of hepatotoxicity in overdose"],
            "contraindications": ["Severe hepatic impairment"],
            "available_forms": ["Syrup 120mg/5ml", "Drops 100mg/ml", "Suppository"],
        },
        "ibuprofen": {
            "generic_name": "Ibuprofen",
            "drug_name": "Ibuprofen",
            "brand_names": ["Brufen", "Nurofen"],
            "safe_for_children": True,
            "minimum_age_months": 3,
            "pediatric_dose": "5-10 mg/kg every 6-8 hours",
            "max_daily_mg_per_kg": 40,
            "max_daily_doses": 3,
            "warnings": ["Avoid in dehydration", "Risk of GI bleeding", "Avoid in renal impairment"],
            "contraindications": ["Renal impairment", "Active GI bleeding", "Dehydration"],
            "available_forms": ["Syrup 100mg/5ml"],
        },
        "aspirin": {
            "generic_name": "Aspirin",
            "drug_name": "Aspirin",
            "brand_names": ["Disprin", "Ecotrin"],
            "safe_for_children": False,
            "minimum_age_months": 192,
            "pediatric_dose": "NOT recommended in children under 16",
            "warnings": ["Risk of Reye's syndrome in children", "Contraindicated in viral infections"],
            "contraindications": ["Children under 16 (except Kawasaki disease)", "Viral infections"],
            "available_forms": [],
        },
        "metronidazole": {
            "generic_name": "Metronidazole",
            "drug_name": "Metronidazole",
            "brand_names": ["Flagyl", "Metrozol"],
            "safe_for_children": True,
            "minimum_age_months": 1,
            "pediatric_dose": "7.5 mg/kg every 8 hours",
            "max_daily_mg_per_kg": 22.5,
            "warnings": ["Metallic taste common", "Avoid alcohol"],
            "available_forms": ["Suspension 200mg/5ml"],
        },
        "azithromycin": {
            "generic_name": "Azithromycin",
            "drug_name": "Azithromycin",
            "brand_names": ["Azomax", "Zetro", "Zithromax"],
            "safe_for_children": True,
            "minimum_age_months": 6,
            "pediatric_dose": "10 mg/kg on day 1, then 5 mg/kg days 2-5",
            "warnings": ["QT prolongation risk", "GI upset common"],
            "available_forms": ["Suspension 200mg/5ml"],
        },
        "amoxicillin": {
            "generic_name": "Amoxicillin",
            "drug_name": "Amoxicillin",
            "brand_names": ["Amoxil", "Moxyvit", "Ospamox"],
            "safe_for_children": True,
            "minimum_age_months": 0,
            "pediatric_dose": "25-50 mg/kg/day in divided doses every 8 hours",
            "max_daily_mg_per_kg": 100,
            "warnings": ["Allergy risk in penicillin-sensitive patients", "Rash common"],
            "available_forms": ["Suspension 125mg/5ml", "Suspension 250mg/5ml"],
        },
        "ciprofloxacin": {
            "generic_name": "Ciprofloxacin",
            "drug_name": "Ciprofloxacin",
            "brand_names": ["Cipro", "Ciproxin"],
            "safe_for_children": False,
            "minimum_age_months": 216,
            "pediatric_dose": "NOT routinely recommended; 10-20 mg/kg/day if essential",
            "warnings": [
                "Risk of tendon damage in growing children",
                "May affect cartilage development",
                "Use only when no safer alternative exists",
            ],
            "contraindications": ["Children (musculoskeletal toxicity)", "Growing adolescents"],
            "available_forms": [],
        },
    }

    if cls_or_none is not None and hasattr(cls_or_none, "_data"):
        cls_or_none._data.update(builtin)
        # Also index by brand names
        for key, val in builtin.items():
            for brand in val.get("brand_names", []):
                cls_or_none._data[brand.lower()] = val
    return builtin


# ---------------------------------------------------------------------------
# Function-based API for Pediatric Safety (convenience wrappers)
# ---------------------------------------------------------------------------

def get_pediatric_info(drug_name: str) -> Optional[dict]:
    """
    Get pediatric safety information for a drug.
    Returns safety details or None if not found.
    """
    return PediatricSafetyLoader.lookup(drug_name)


def is_safe_for_children(drug_name: str) -> Optional[bool]:
    """
    Quick check: is this drug safe for children?
    Returns True/False or None if not found in pediatric database.
    """
    info = PediatricSafetyLoader.lookup(drug_name)
    if info is not None:
        return info.get("safe_for_children")
    return None
