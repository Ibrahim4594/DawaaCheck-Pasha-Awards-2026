"""Agent 7 — HIFAZAT (The Protector)
AMR (Antimicrobial Resistance) Guard
Queries Supabase `who_aware_antibiotics` and `generic_drugs` tables to
classify antibiotics and provide stewardship guidance based on the
WHO ACCESS / WATCH / RESERVE framework, with Pakistan-specific context.
"""

import logging
from typing import Optional

from utils.supabase_client import get_supabase

logger = logging.getLogger(__name__)

AGENT_NUMBER = 7
AGENT_NAME = "HIFAZAT — The Protector"

# ---------------------------------------------------------------------------
# Pakistan-specific AMR resistance statistics
# Sources: Pakistan AMR National Action Plan, WHO GLASS, published literature
# ---------------------------------------------------------------------------
PAKISTAN_RESISTANCE_STATS = {
    "ciprofloxacin": {
        "resistance_note": "In Pakistan, ~70% of E. coli isolates are resistant to ciprofloxacin. Fluoroquinolone resistance is among the highest globally.",
        "overused": True,
        "common_resistant_organisms": ["E. coli", "Klebsiella pneumoniae", "Salmonella typhi"],
    },
    "amoxicillin": {
        "resistance_note": "Amoxicillin resistance in Pakistani clinical isolates of E. coli exceeds 80%. Often dispensed without prescription.",
        "overused": True,
        "common_resistant_organisms": ["E. coli", "H. influenzae", "S. pneumoniae"],
    },
    "azithromycin": {
        "resistance_note": "Azithromycin resistance is rising in Pakistan due to widespread OTC sales. XDR Salmonella typhi strains show azithromycin resistance.",
        "overused": True,
        "common_resistant_organisms": ["Salmonella typhi", "Shigella", "N. gonorrhoeae"],
    },
    "metronidazole": {
        "resistance_note": "Metronidazole resistance in H. pylori has been reported at 80-90% in Pakistani studies, limiting its effectiveness for gastric ulcers.",
        "overused": True,
        "common_resistant_organisms": ["H. pylori"],
    },
    "ceftriaxone": {
        "resistance_note": "Third-generation cephalosporin resistance is significant in Pakistan. ESBL-producing E. coli and Klebsiella are common in hospital settings.",
        "overused": True,
        "common_resistant_organisms": ["E. coli (ESBL)", "Klebsiella pneumoniae (ESBL)", "Salmonella typhi (XDR)"],
    },
    "levofloxacin": {
        "resistance_note": "Fluoroquinolone resistance in M. tuberculosis is a growing concern in Pakistan, limiting MDR-TB treatment options.",
        "overused": True,
        "common_resistant_organisms": ["M. tuberculosis", "E. coli", "P. aeruginosa"],
    },
    "co-amoxiclav": {
        "resistance_note": "Co-amoxiclav (amoxicillin/clavulanate) is one of the most frequently self-prescribed antibiotics in Pakistan. Resistance rates are rising.",
        "overused": True,
        "common_resistant_organisms": ["E. coli", "K. pneumoniae"],
    },
    "meropenem": {
        "resistance_note": "Carbapenem-resistant organisms (CROs) are increasingly reported in Pakistani tertiary hospitals, making meropenem a critical last-line agent.",
        "overused": False,
        "common_resistant_organisms": ["A. baumannii (CR)", "K. pneumoniae (CR)", "P. aeruginosa (CR)"],
    },
    "colistin": {
        "resistance_note": "Pakistan was among the first countries where plasmid-mediated colistin resistance (mcr-1) was detected. Agricultural overuse is a key driver.",
        "overused": False,
        "common_resistant_organisms": ["E. coli (mcr-1)", "K. pneumoniae"],
    },
    "vancomycin": {
        "resistance_note": "Vancomycin-resistant Enterococci (VRE) have been reported in multiple Pakistani hospitals. MRSA rates exceed 40% in some centres.",
        "overused": False,
        "common_resistant_organisms": ["Enterococcus faecium (VRE)", "S. aureus (VISA)"],
    },
    "trimethoprim/sulfamethoxazole": {
        "resistance_note": "Co-trimoxazole resistance in urinary E. coli exceeds 60% in Pakistan, making it unreliable for empiric UTI treatment.",
        "overused": True,
        "common_resistant_organisms": ["E. coli", "Shigella", "S. pneumoniae"],
    },
    "doxycycline": {
        "resistance_note": "Tetracycline-class resistance is widespread in Pakistan, though doxycycline retains some activity against respiratory pathogens.",
        "overused": True,
        "common_resistant_organisms": ["S. aureus", "E. coli"],
    },
}

PAKISTAN_GENERAL_AMR_CONTEXT = (
    "Pakistan faces one of the highest antimicrobial resistance burdens globally. "
    "Key drivers include over-the-counter antibiotic sales without prescription, "
    "self-medication, incomplete courses, and unregulated use in livestock. "
    "DRAP regulations require antibiotics to be dispensed only with a valid prescription, "
    "but enforcement remains limited. Always consult a qualified physician before using antibiotics."
)

# Known antibiotic therapeutic classes for fallback detection
ANTIBIOTIC_THERAPEUTIC_CLASSES = {
    "antibiotic", "antibacterial", "antimicrobial", "cephalosporin",
    "penicillin", "fluoroquinolone", "quinolone", "macrolide",
    "tetracycline", "aminoglycoside", "carbapenem", "sulfonamide",
    "nitroimidazole", "glycopeptide", "oxazolidinone", "lincosamide",
    "polymyxin", "monobactam", "rifamycin", "anti-infective",
    "antitubercular", "antituberculosis",
}


def _normalize(name: str) -> str:
    """Lowercase and strip a drug name for comparison."""
    return name.strip().lower()


def _sanitize_like(value: str) -> str:
    """Escape SQL LIKE/ILIKE wildcard characters in user-supplied values."""
    # Escape backslash first to avoid double-escaping the ones we add below
    return value.replace("\\", "\\\\").replace("%", r"\%").replace("_", r"\_")


def _lookup_who_aware(ingredient: str) -> Optional[dict]:
    """Query the who_aware_antibiotics table in Supabase."""
    if not ingredient:
        return None
    try:
        sb = get_supabase()
        safe_ingredient = _sanitize_like(ingredient)
        # Case-insensitive exact match first
        resp = (
            sb.table("who_aware_antibiotics")
            .select("drug_name, category, description, resistance_risk, common_brands_pakistan")
            .ilike("drug_name", safe_ingredient)
            .execute()
        )
        if resp.data and len(resp.data) > 0:
            return resp.data[0]

        # Try partial / fuzzy match
        resp = (
            sb.table("who_aware_antibiotics")
            .select("drug_name, category, description, resistance_risk, common_brands_pakistan")
            .ilike("drug_name", f"%{safe_ingredient}%")
            .execute()
        )
        if resp.data and len(resp.data) > 0:
            return resp.data[0]
    except Exception as exc:
        logger.warning("WHO AWaRe Supabase lookup failed: %s", exc)
    return None


def _is_antibiotic_via_generic_drugs(ingredient: str) -> bool:
    """
    Fall back to the generic_drugs table to detect antibiotics that are
    not in the WHO AWaRe list, using the therapeutic_class column.
    """
    if not ingredient:
        return False
    try:
        sb = get_supabase()
        safe_ingredient = _sanitize_like(ingredient)
        resp = (
            sb.table("generic_drugs")
            .select("therapeutic_class")
            .ilike("drug_name", f"%{safe_ingredient}%")
            .execute()
        )
        if resp.data:
            for row in resp.data:
                tc = _normalize(row.get("therapeutic_class", ""))
                for keyword in ANTIBIOTIC_THERAPEUTIC_CLASSES:
                    if keyword in tc:
                        return True
    except Exception as exc:
        logger.warning("generic_drugs antibiotic check failed: %s", exc)
    return False


def _get_resistance_patterns(ingredient: str) -> Optional[dict]:
    """Return Pakistan-specific resistance data if available."""
    key = _normalize(ingredient)
    # Direct match
    if key in PAKISTAN_RESISTANCE_STATS:
        return PAKISTAN_RESISTANCE_STATS[key]
    # Partial match
    for drug_key, data in PAKISTAN_RESISTANCE_STATS.items():
        if drug_key in key or key in drug_key:
            return data
    return None


def check_amr(active_ingredient: str) -> dict:
    """
    Main entry point for Agent 7.

    Args:
        active_ingredient: The active ingredient name to check.

    Returns:
        Standardized agent result dict.
    """
    result: dict = {
        "agent_number": AGENT_NUMBER,
        "agent_name": AGENT_NAME,
        "status": "PASS",
        "confidence_score": 0.0,
        "is_antibiotic": False,
        "aware_classification": None,
        "antibiotic_category": None,
        "common_use": None,
        "common_brands_pakistan": [],
        "resistance_risk": None,
        "risk_level": None,
        "stewardship_message": None,
        "resistance_patterns": None,
        "pakistan_context": None,
        "susceptibility_testing_advised": False,
        "commonly_overused_in_pakistan": False,
        "display_message": "",
        "fail_reason": None,
    }

    try:
        # Guard: empty, None, or placeholder ingredient
        if not active_ingredient or not active_ingredient.strip() or active_ingredient.strip().lower() in ("unknown", "n/a", "none"):
            result["status"] = "PASS"
            result["confidence_score"] = 0.0
            result["display_message"] = (
                "No active ingredient provided. "
                "Cannot perform antimicrobial resistance assessment."
            )
            return result

        ingredient_lower = _normalize(active_ingredient)

        # ── Step 1: Look up in WHO AWaRe table via Supabase ──
        aware_data = _lookup_who_aware(ingredient_lower)

        # ── Step 2: If not found, check if it is still an antibiotic ──
        if aware_data is None:
            is_ab = _is_antibiotic_via_generic_drugs(ingredient_lower)
            if is_ab:
                # It is an antibiotic but not in WHO AWaRe list
                result["is_antibiotic"] = True
                result["status"] = "PASS"
                result["confidence_score"] = 0.70
                result["risk_level"] = "MEDIUM"
                result["stewardship_message"] = (
                    "This antibiotic is not classified in the WHO AWaRe system. "
                    "Use only as prescribed by a healthcare professional. "
                    "Complete the full course to reduce resistance development."
                )
                resistance = _get_resistance_patterns(ingredient_lower)
                if resistance:
                    result["resistance_patterns"] = resistance
                    result["commonly_overused_in_pakistan"] = resistance.get("overused", False)
                result["pakistan_context"] = PAKISTAN_GENERAL_AMR_CONTEXT
                result["display_message"] = (
                    f"'{active_ingredient}' appears to be an antibiotic but is not in the "
                    "WHO AWaRe classification. Use responsibly and only with a prescription. "
                    + PAKISTAN_GENERAL_AMR_CONTEXT
                )
                return result

            # Not an antibiotic at all
            result["is_antibiotic"] = False
            result["status"] = "PASS"
            result["confidence_score"] = 0.80
            result["risk_level"] = None
            result["display_message"] = (
                f"'{active_ingredient}' is not classified as an antibiotic in the WHO AWaRe "
                "database. No antimicrobial resistance concerns."
            )
            return result

        # ── Step 3: Antibiotic found in WHO AWaRe ──
        classification = (aware_data.get("category") or "").upper()

        result["is_antibiotic"] = True
        result["aware_classification"] = classification
        result["antibiotic_category"] = aware_data.get("description", "")
        result["common_use"] = aware_data.get("description", "")

        # Parse brands — may be a list or a comma-separated string
        brands_raw = aware_data.get("common_brands_pakistan", [])
        if isinstance(brands_raw, str):
            brands_raw = [b.strip() for b in brands_raw.split(",") if b.strip()]
        result["common_brands_pakistan"] = brands_raw or []

        result["resistance_risk"] = aware_data.get("resistance_risk", "")

        # Resistance patterns from our Pakistan-specific data
        resistance = _get_resistance_patterns(ingredient_lower)
        if resistance:
            result["resistance_patterns"] = resistance
            result["commonly_overused_in_pakistan"] = resistance.get("overused", False)

        # ── Step 4: Classification-specific logic ──
        brands_str = ", ".join((brands_raw or [])[:4])

        if classification == "ACCESS":
            result["status"] = "PASS"
            result["confidence_score"] = 0.92
            result["risk_level"] = "LOW"
            result["stewardship_message"] = (
                "This antibiotic is first-line treatment. Complete the full course as prescribed."
            )
            result["susceptibility_testing_advised"] = False
            msg = (
                f"'{active_ingredient}' is an ACCESS group antibiotic (first-line). "
                f"{aware_data.get('description', '')} "
                f"Resistance risk: {aware_data.get('resistance_risk', 'Low')}. "
                "This antibiotic is first-line treatment. Complete the full course as prescribed."
            )
            if brands_str:
                msg += f" Common Pakistan brands: {brands_str}."
            if resistance:
                msg += f" {resistance['resistance_note']}"
                if resistance.get("overused"):
                    msg += (
                        " This antibiotic is commonly overused in Pakistan. "
                        "Do not self-medicate; obtain a proper prescription."
                    )

        elif classification == "WATCH":
            result["status"] = "PASS"
            result["confidence_score"] = 0.88
            result["risk_level"] = "HIGH"
            result["stewardship_message"] = (
                "\u26a0\ufe0f This is a higher-priority antibiotic. Only use when prescribed "
                "by a doctor. Misuse accelerates resistance."
            )
            result["susceptibility_testing_advised"] = True
            msg = (
                f"\u26a0\ufe0f WATCH GROUP: '{active_ingredient}' is a WATCH group antibiotic "
                f"with higher resistance potential. "
                f"{aware_data.get('description', '')} "
                f"Resistance risk: {aware_data.get('resistance_risk', 'Medium-High')}. "
                "Only use when prescribed by a doctor. Misuse accelerates resistance. "
                "Culture & susceptibility testing is recommended before use."
            )
            if brands_str:
                msg += f" Common Pakistan brands: {brands_str}."
            if resistance:
                msg += f" {resistance['resistance_note']}"
                if resistance.get("common_resistant_organisms"):
                    orgs = ", ".join(resistance["common_resistant_organisms"][:3])
                    msg += f" Commonly resistant organisms: {orgs}."
                if resistance.get("overused"):
                    msg += (
                        " This antibiotic is commonly overused in Pakistan through "
                        "self-medication and OTC purchase."
                    )
            msg += (
                " DRAP regulations require a valid prescription for this antibiotic."
            )

        elif classification == "RESERVE":
            result["status"] = "WARNING"
            result["confidence_score"] = 0.95
            result["risk_level"] = "CRITICAL"
            result["stewardship_message"] = (
                "\U0001f6a8 RESERVE antibiotic \u2014 last resort for drug-resistant infections. "
                "Should ONLY be prescribed by infectious disease specialists."
            )
            result["susceptibility_testing_advised"] = True
            msg = (
                f"\U0001f6a8 RESERVE GROUP: '{active_ingredient}' is a RESERVE antibiotic \u2014 "
                "a last-resort medicine for multidrug-resistant infections. "
                f"{aware_data.get('description', '')} "
                f"Resistance risk: {aware_data.get('resistance_risk', 'Very High')}. "
                "This should ONLY be prescribed by infectious disease specialists after "
                "culture & susceptibility testing confirms necessity. "
                "Inappropriate use threatens global antibiotic effectiveness."
            )
            if brands_str:
                msg += f" Common Pakistan brands: {brands_str}."
            if resistance:
                msg += f" {resistance['resistance_note']}"
                if resistance.get("common_resistant_organisms"):
                    orgs = ", ".join(resistance["common_resistant_organisms"])
                    msg += f" Known resistant organisms: {orgs}."
            msg += (
                " DRAP mandates specialist prescription for RESERVE-class antibiotics."
            )

        else:
            result["status"] = "PASS"
            result["confidence_score"] = 0.70
            result["risk_level"] = "MEDIUM"
            result["stewardship_message"] = (
                "This antibiotic has an unrecognized AWaRe classification. "
                "Consult a healthcare professional."
            )
            msg = (
                f"'{active_ingredient}' found in WHO AWaRe database with classification: "
                f"{classification}. Consult a healthcare professional for guidance."
            )

        # ── Step 5: Append Pakistan-specific AMR context for all antibiotics ──
        result["pakistan_context"] = PAKISTAN_GENERAL_AMR_CONTEXT
        msg += " " + PAKISTAN_GENERAL_AMR_CONTEXT
        result["display_message"] = msg

    except Exception as exc:  # noqa: BLE001
        logger.exception("Agent 7 AMR Guard error for '%s'", active_ingredient)
        result["status"] = "UNCERTAIN"
        result["confidence_score"] = 0.0
        result["fail_reason"] = f"Error checking AMR data: {exc}"
        result["display_message"] = "Could not check antimicrobial resistance data."

    return result
