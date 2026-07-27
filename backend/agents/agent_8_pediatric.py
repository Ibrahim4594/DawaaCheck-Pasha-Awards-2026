"""Agent 8 — SHAFIQ (The Compassionate)
Pediatric Safety Checker (Enhanced)

Uses Supabase pediatric_safety + drug_side_effects tables as primary data source,
DailyMed API as fallback, WHO weight-for-age validation, advanced dose calculations
(per-kg and BSA-based via Mosteller formula), built-in dangerous-drug overrides,
age-based formulation recommendations, and Pakistan-specific warnings.
"""

import asyncio
import logging
import math
import re
from typing import Optional

from utils.supabase_client import get_supabase
from data.api_clients import dailymed_client

logger = logging.getLogger(__name__)

AGENT_NUMBER = 8
AGENT_NAME = "SHAFIQ — The Compassionate"

# ---------------------------------------------------------------------------
# WHO Weight-for-Age Reference Data (50th percentile, boys/girls averaged)
# Keys are age in months, values are (p3, p50, p97) in kg
# Source: WHO Child Growth Standards & Reference 2007
# ---------------------------------------------------------------------------
WHO_WEIGHT_FOR_AGE: dict[int, tuple[float, float, float]] = {
    0:   (2.5,  3.3,  4.3),    # Newborn
    1:   (3.2,  4.3,  5.7),
    2:   (3.9,  5.2,  6.9),
    3:   (4.5,  6.0,  7.9),
    4:   (5.0,  6.6,  8.6),
    5:   (5.4,  7.1,  9.2),
    6:   (5.8,  7.5,  9.7),    # 6 months
    9:   (6.6,  8.5, 10.9),
    12:  (7.2,  9.6, 12.4),    # 1 year  (~10 kg)
    15:  (7.8, 10.3, 13.3),
    18:  (8.3, 10.9, 14.1),
    24:  (9.2, 12.0, 15.7),    # 2 years (~12 kg)
    30:  (9.9, 13.0, 17.1),
    36:  (10.6, 13.9, 18.5),   # 3 years
    48:  (11.9, 15.7, 21.5),   # 4 years
    60:  (13.3, 18.0, 25.0),   # 5 years (~18 kg)
    72:  (14.7, 20.0, 28.5),   # 6 years
    84:  (16.2, 22.2, 32.2),   # 7 years
    96:  (17.8, 24.5, 36.5),   # 8 years
    108: (19.5, 27.0, 41.0),   # 9 years
    120: (21.5, 32.0, 47.0),   # 10 years (~32 kg)
    132: (23.5, 35.5, 53.0),   # 11 years
    144: (26.0, 40.0, 59.0),   # 12 years
    156: (29.0, 45.0, 65.0),   # 13 years
    168: (33.0, 50.0, 72.0),   # 14 years
    180: (37.0, 55.0, 78.0),   # 15 years
    192: (40.0, 58.0, 82.0),   # 16 years
    204: (42.0, 60.0, 85.0),   # 17 years
    216: (44.0, 62.0, 88.0),   # 18 years
}

# ---------------------------------------------------------------------------
# Drugs that are NEVER safe below a certain age (overrides any DB data)
# age_limit is in months
# ---------------------------------------------------------------------------
DANGEROUS_PEDIATRIC_DRUGS: dict[str, dict] = {
    "aspirin": {
        "age_limit_months": 192,   # 16 years
        "reason": "Risk of Reye's syndrome - a rare but life-threatening condition",
        "severity": "CRITICAL",
        "alternative": "Use paracetamol (acetaminophen) or ibuprofen instead",
    },
    "acetylsalicylic acid": {
        "age_limit_months": 192,
        "reason": "Risk of Reye's syndrome - a rare but life-threatening condition",
        "severity": "CRITICAL",
        "alternative": "Use paracetamol (acetaminophen) or ibuprofen instead",
    },
    "codeine": {
        "age_limit_months": 144,   # 12 years
        "reason": "Risk of fatal respiratory depression in ultra-rapid CYP2D6 metabolizers",
        "severity": "CRITICAL",
        "alternative": "Use age-appropriate analgesics; consult pediatrician",
    },
    "loperamide": {
        "age_limit_months": 24,    # 2 years
        "reason": "Risk of serious cardiac and CNS events in young children",
        "severity": "CRITICAL",
        "alternative": "Use oral rehydration salts (ORS) for diarrhea management",
    },
    "metoclopramide": {
        "age_limit_months": 12,    # 1 year
        "reason": "Risk of extrapyramidal symptoms and tardive dyskinesia in infants",
        "severity": "HIGH",
        "alternative": "Consult pediatric gastroenterologist for anti-emetic options",
    },
    "honey": {
        "age_limit_months": 12,    # 1 year
        "reason": "Risk of infant botulism from Clostridium botulinum spores",
        "severity": "CRITICAL",
        "alternative": "No honey-based formulations for children under 1 year",
    },
    "tetracycline": {
        "age_limit_months": 96,    # 8 years
        "reason": "Causes permanent teeth discoloration and enamel hypoplasia",
        "severity": "HIGH",
        "alternative": "Use amoxicillin or azithromycin as alternatives",
    },
    "doxycycline": {
        "age_limit_months": 96,    # 8 years
        "reason": "Tetracycline-class: risk of permanent teeth staining in children under 8",
        "severity": "HIGH",
        "alternative": "Use amoxicillin or azithromycin as alternatives",
    },
    "minocycline": {
        "age_limit_months": 96,
        "reason": "Tetracycline-class: risk of permanent teeth staining in children under 8",
        "severity": "HIGH",
        "alternative": "Use amoxicillin or azithromycin as alternatives",
    },
    "ciprofloxacin": {
        "age_limit_months": 216,   # 18 years (with exceptions)
        "reason": "Risk of tendon damage and cartilage toxicity in growing children",
        "severity": "HIGH",
        "alternative": "Use only if no safer alternative exists; requires specialist approval",
    },
    "bismuth subsalicylate": {
        "age_limit_months": 144,   # 12 years
        "reason": "Contains salicylate - risk of Reye's syndrome similar to aspirin",
        "severity": "HIGH",
        "alternative": "Use ORS for diarrhea; paracetamol for pain/fever",
    },
}

# ---------------------------------------------------------------------------
# Pakistan-specific warnings
# ---------------------------------------------------------------------------
PAKISTAN_WARNINGS: list[str] = [
    "PAKISTAN ALERT: Be cautious of unregulated cough syrups. Multiple incidents "
    "of diethylene glycol contamination in locally manufactured syrups have caused "
    "child fatalities. Only use medicines from DRAP-registered manufacturers.",

    "PAKISTAN ALERT: When using powder-for-suspension antibiotics (e.g., amoxicillin, "
    "cefixime), ensure proper reconstitution with the correct volume of clean, boiled "
    "water. Improper mixing leads to incorrect dosing.",

    "PAKISTAN ALERT: Pediatric formulations (drops, syrups) may not be available at "
    "all pharmacies. Never crush adult tablets for children without pharmacist guidance "
    "as some formulations are not designed to be split.",
]


# ---------------------------------------------------------------------------
# Helper functions
# ---------------------------------------------------------------------------


def _sanitize_like(value: str) -> str:
    """Escape SQL LIKE/ILIKE wildcard characters in user-supplied values."""
    return value.replace("\\", "\\\\").replace("%", r"\%").replace("_", r"\_")


def _run_async_safely(coro):
    """Run an async coroutine safely from a sync context."""
    try:
        loop = asyncio.get_event_loop()
        if loop.is_running():
            import concurrent.futures
            with concurrent.futures.ThreadPoolExecutor() as pool:
                return pool.submit(asyncio.run, coro).result(timeout=20)
        else:
            return asyncio.run(coro)
    except RuntimeError:
        return asyncio.run(coro)
    except Exception as exc:
        logger.warning("Async call failed: %s", exc)
        return None


def _fetch_dailymed_pediatric(drug_name: str) -> Optional[dict]:
    """Fetch pediatric info from DailyMed API as fallback."""
    try:
        return _run_async_safely(dailymed_client.get_pediatric_info(drug_name))
    except Exception as exc:
        logger.warning("DailyMed pediatric fetch failed: %s", exc)
        return None


def _query_supabase_pediatric(drug_name: str) -> Optional[dict]:
    """
    Query the pediatric_safety table in Supabase.
    Columns: drug_name, minimum_age_months, contraindications, warnings,
             dose_per_kg, max_daily_doses, available_forms
    """
    if not drug_name or not drug_name.strip():
        return None
    try:
        sb = get_supabase()
        safe_name = _sanitize_like(drug_name.strip().lower())
        # Exact match first
        resp = (
            sb.table("pediatric_safety")
            .select("*")
            .ilike("drug_name", safe_name)
            .limit(1)
            .execute()
        )
        if resp.data and len(resp.data) > 0:
            return resp.data[0]
        # Partial match fallback
        resp = (
            sb.table("pediatric_safety")
            .select("*")
            .ilike("drug_name", f"%{safe_name}%")
            .limit(1)
            .execute()
        )
        if resp.data and len(resp.data) > 0:
            return resp.data[0]
        return None
    except Exception as exc:
        logger.warning("Supabase pediatric_safety query failed for '%s': %s", drug_name, exc)
        return None


def _query_supabase_side_effects(drug_name: str) -> Optional[dict]:
    """
    Query the drug_side_effects table for pediatric-relevant warnings.
    Columns typically include: drug_name, common_side_effects, serious_side_effects,
    black_box_warnings, etc.
    """
    if not drug_name or not drug_name.strip():
        return None
    try:
        sb = get_supabase()
        safe_name = _sanitize_like(drug_name.strip().lower())
        resp = (
            sb.table("drug_side_effects")
            .select("*")
            .ilike("drug_name", f"%{safe_name}%")
            .limit(1)
            .execute()
        )
        if resp.data and len(resp.data) > 0:
            return resp.data[0]
        return None
    except Exception as exc:
        logger.warning("Supabase drug_side_effects query failed for '%s': %s", drug_name, exc)
        return None


def _get_who_reference(age_months: float) -> Optional[tuple[float, float, float]]:
    """
    Get the closest WHO weight-for-age reference (p3, p50, p97) for a given age.
    Linearly interpolates between the two nearest reference points.
    """
    if age_months < 0 or age_months > 216:
        return None

    sorted_keys = sorted(WHO_WEIGHT_FOR_AGE.keys())

    # Exact match
    rounded = int(round(age_months))
    if rounded in WHO_WEIGHT_FOR_AGE:
        return WHO_WEIGHT_FOR_AGE[rounded]

    # Interpolate
    lower_key = None
    upper_key = None
    for k in sorted_keys:
        if k <= age_months:
            lower_key = k
        if k >= age_months and upper_key is None:
            upper_key = k

    if lower_key is None:
        return WHO_WEIGHT_FOR_AGE[sorted_keys[0]]
    if upper_key is None:
        return WHO_WEIGHT_FOR_AGE[sorted_keys[-1]]
    if lower_key == upper_key:
        return WHO_WEIGHT_FOR_AGE[lower_key]

    # Linear interpolation
    fraction = (age_months - lower_key) / (upper_key - lower_key)
    low_vals = WHO_WEIGHT_FOR_AGE[lower_key]
    high_vals = WHO_WEIGHT_FOR_AGE[upper_key]

    return (
        round(low_vals[0] + fraction * (high_vals[0] - low_vals[0]), 1),
        round(low_vals[1] + fraction * (high_vals[1] - low_vals[1]), 1),
        round(low_vals[2] + fraction * (high_vals[2] - low_vals[2]), 1),
    )


def _validate_weight_for_age(
    age_months: float, weight_kg: float
) -> dict:
    """
    Validate a child's weight against WHO growth percentiles.
    Returns a dict with validation status and any warnings.
    """
    result = {
        "weight_valid": True,
        "percentile_warning": None,
        "expected_p50": None,
        "expected_range": None,
    }

    ref = _get_who_reference(age_months)
    if ref is None:
        return result

    p3, p50, p97 = ref
    result["expected_p50"] = p50
    result["expected_range"] = f"{p3}-{p97} kg"

    if weight_kg < p3:
        result["weight_valid"] = False
        result["percentile_warning"] = (
            f"Weight {weight_kg} kg is BELOW the 3rd percentile for age "
            f"({age_months:.0f} months). Expected range: {p3}-{p97} kg. "
            f"Dose calculations may be inaccurate. Consider malnutrition screening. "
            f"Consult pediatrician for dose adjustment."
        )
    elif weight_kg > p97:
        result["weight_valid"] = False
        result["percentile_warning"] = (
            f"Weight {weight_kg} kg is ABOVE the 97th percentile for age "
            f"({age_months:.0f} months). Expected range: {p3}-{p97} kg. "
            f"Dose calculations based on actual weight may lead to overdosing. "
            f"Consider using ideal body weight for dosing. Consult pediatrician."
        )

    return result


def _calculate_bsa(weight_kg: float, height_cm: Optional[float] = None) -> float:
    """
    Calculate Body Surface Area using the Mosteller formula.
    BSA (m^2) = sqrt( (height_cm x weight_kg) / 3600 )

    If height is not provided, estimate from WHO median height-for-weight.
    """
    if height_cm and height_cm > 0:
        return math.sqrt((height_cm * weight_kg) / 3600.0)

    # Estimate height from weight using approximate WHO median relationship
    # These are rough estimates when height is not available
    if weight_kg <= 3.5:
        est_height = 50.0  # newborn
    elif weight_kg <= 6.0:
        est_height = 60.0
    elif weight_kg <= 8.0:
        est_height = 68.0
    elif weight_kg <= 10.0:
        est_height = 75.0
    elif weight_kg <= 12.0:
        est_height = 82.0
    elif weight_kg <= 15.0:
        est_height = 92.0
    elif weight_kg <= 18.0:
        est_height = 105.0
    elif weight_kg <= 22.0:
        est_height = 115.0
    elif weight_kg <= 28.0:
        est_height = 125.0
    elif weight_kg <= 35.0:
        est_height = 138.0
    elif weight_kg <= 45.0:
        est_height = 150.0
    elif weight_kg <= 55.0:
        est_height = 160.0
    else:
        est_height = 170.0

    return math.sqrt((est_height * weight_kg) / 3600.0)


def _calculate_advanced_dose(
    drug_data: dict,
    weight_kg: float,
    age_months: float,
    height_cm: Optional[float] = None,
) -> dict:
    """
    Calculate dose per-kg AND per-BSA using Mosteller formula.
    Checks against maximum single dose, maximum daily dose, and adult dose limits.
    Includes frequency recommendations.
    """
    dose_result = {
        "weight_kg": weight_kg,
        "dose_per_kg": None,
        "recommended_single_dose_mg": None,
        "recommended_daily_dose_mg": None,
        "max_single_dose_mg": None,
        "max_daily_dose_mg": None,
        "frequency": None,
        "bsa_m2": None,
        "dose_per_bsa": None,
        "exceeds_max_single": False,
        "exceeds_max_daily": False,
        "adult_dose_warning": False,
        "notes": [],
    }

    dose_per_kg_raw = drug_data.get("dose_per_kg")
    max_daily_doses = drug_data.get("max_daily_doses")

    # Parse dose_per_kg - may be string like "10-15 mg/kg/day" or numeric
    dose_per_kg_value = None
    if dose_per_kg_raw is not None:
        dose_result["dose_per_kg"] = dose_per_kg_raw
        if isinstance(dose_per_kg_raw, (int, float)):
            dose_per_kg_value = float(dose_per_kg_raw)
        elif isinstance(dose_per_kg_raw, str):
            # Try to extract numeric value(s) from string
            numbers = re.findall(r"[\d.]+", str(dose_per_kg_raw))
            if numbers:
                # Use the first number (or average of range)
                if len(numbers) >= 2:
                    dose_per_kg_value = (float(numbers[0]) + float(numbers[1])) / 2.0
                    dose_result["notes"].append(
                        f"Dose range: {numbers[0]}-{numbers[1]} mg/kg; "
                        f"using midpoint {dose_per_kg_value:.1f} mg/kg for calculation"
                    )
                else:
                    dose_per_kg_value = float(numbers[0])

    # Calculate BSA
    bsa = _calculate_bsa(weight_kg, height_cm)
    dose_result["bsa_m2"] = round(bsa, 3)

    if dose_per_kg_value is not None:
        # Per-kg dose
        single_dose = round(dose_per_kg_value * weight_kg, 1)
        dose_result["recommended_single_dose_mg"] = single_dose

        # Per-BSA dose (for reference)
        dose_per_bsa = round(single_dose / bsa, 1) if bsa > 0 else None
        dose_result["dose_per_bsa"] = dose_per_bsa

        # Parse max_daily_doses for frequency
        frequency_count = None
        if max_daily_doses is not None:
            if isinstance(max_daily_doses, (int, float)):
                frequency_count = int(max_daily_doses)
            elif isinstance(max_daily_doses, str):
                nums = re.findall(r"\d+", str(max_daily_doses))
                if nums:
                    frequency_count = int(nums[0])

        if frequency_count:
            daily_dose = round(single_dose * frequency_count, 1)
            dose_result["recommended_daily_dose_mg"] = daily_dose

            # Map frequency count to human-readable
            freq_map = {
                1: "Once daily",
                2: "Every 12 hours (twice daily)",
                3: "Every 8 hours (three times daily)",
                4: "Every 6 hours (four times daily)",
                6: "Every 4 hours (six times daily)",
            }
            dose_result["frequency"] = freq_map.get(
                frequency_count,
                f"{frequency_count} times daily"
            )

        # Check maximum thresholds
        # Common adult single dose limits by broad drug category
        ADULT_MAX_SINGLE_DOSES = {
            "paracetamol": 1000, "acetaminophen": 1000,
            "ibuprofen": 800, "amoxicillin": 1000,
            "cetirizine": 10, "loratadine": 10,
            "metformin": 1000, "omeprazole": 40,
        }
        ADULT_MAX_DAILY_DOSES = {
            "paracetamol": 4000, "acetaminophen": 4000,
            "ibuprofen": 3200, "amoxicillin": 3000,
            "cetirizine": 10, "loratadine": 10,
            "metformin": 2550, "omeprazole": 40,
        }

        drug_lower = (drug_data.get("drug_name") or "").lower().strip()

        max_single = ADULT_MAX_SINGLE_DOSES.get(drug_lower)
        max_daily = ADULT_MAX_DAILY_DOSES.get(drug_lower)

        if max_single:
            dose_result["max_single_dose_mg"] = max_single
            if single_dose >= max_single:
                dose_result["exceeds_max_single"] = True
                dose_result["notes"].append(
                    f"ALERT: Calculated single dose ({single_dose} mg) meets or exceeds "
                    f"the maximum adult single dose ({max_single} mg). Reduce dose."
                )

        if max_daily and dose_result["recommended_daily_dose_mg"]:
            dose_result["max_daily_dose_mg"] = max_daily
            if dose_result["recommended_daily_dose_mg"] >= max_daily:
                dose_result["exceeds_max_daily"] = True
                dose_result["notes"].append(
                    f"ALERT: Calculated daily dose ({dose_result['recommended_daily_dose_mg']} mg) "
                    f"meets or exceeds the maximum adult daily dose ({max_daily} mg). Reduce dose."
                )

        # Adult dose warning: if child is getting an adult-level dose
        if age_months < 144 and max_single and single_dose >= max_single * 0.8:
            dose_result["adult_dose_warning"] = True
            dose_result["notes"].append(
                "WARNING: This child would receive near-adult dosing. "
                "Verify weight and dose with a pediatrician."
            )

    return dose_result


def _get_formulation_recommendation(age_months: float) -> dict:
    """
    Recommend appropriate drug formulation based on child's age.
    """
    if age_months < 6:
        return {
            "recommended_forms": ["Oral drops"],
            "description": "Under 6 months: Drops ONLY with precise dropper dosing. "
                           "Use the calibrated dropper provided with the medicine. "
                           "Never use a household teaspoon.",
            "avoid": ["Tablets", "Capsules", "Chewable tablets"],
        }
    elif age_months < 24:
        return {
            "recommended_forms": ["Oral drops", "Syrup"],
            "description": "6-24 months: Drops or syrup formulations. "
                           "Use an oral syringe for precise measurement. "
                           "Avoid honey-based syrups for children under 12 months.",
            "avoid": ["Tablets", "Capsules", "Chewable tablets"],
        }
    elif age_months < 72:
        return {
            "recommended_forms": ["Syrup", "Chewable tablets", "Dispersible tablets"],
            "description": "2-6 years: Syrup or chewable/dispersible tablets preferred. "
                           "Ensure child can chew properly before giving chewable tablets.",
            "avoid": ["Large tablets", "Capsules"],
        }
    elif age_months < 144:
        return {
            "recommended_forms": ["Tablets (may need half-dose)", "Syrup", "Chewable tablets"],
            "description": "6-12 years: Tablets (may need to be halved if scored) or syrup. "
                           "Only split tablets along score line. "
                           "Do not crush enteric-coated or sustained-release tablets.",
            "avoid": ["Adult-strength capsules without dose adjustment"],
        }
    else:
        return {
            "recommended_forms": ["Tablets", "Capsules", "Adult formulations"],
            "description": "12+ years: Adult formulations may be appropriate with "
                           "weight-adjusted dosing. Verify dose does not exceed "
                           "maximum adult dose.",
            "avoid": [],
        }


def _check_dangerous_drug_override(
    drug_name: str, age_months: float
) -> Optional[dict]:
    """
    Check if the drug is in the built-in dangerous pediatric drugs list.
    These overrides take precedence over ANY database data.
    Returns a warning dict if dangerous, None if not in the list.
    """
    drug_lower = drug_name.lower().strip()

    # Check exact match and partial match
    for dangerous_drug, info in DANGEROUS_PEDIATRIC_DRUGS.items():
        if dangerous_drug in drug_lower or drug_lower in dangerous_drug:
            if age_months < info["age_limit_months"]:
                limit_months = info["age_limit_months"]
                if limit_months >= 24:
                    age_limit_str = f"{limit_months // 12} years"
                else:
                    age_limit_str = f"{limit_months} months"
                return {
                    "is_dangerous": True,
                    "drug_matched": dangerous_drug,
                    "age_limit": age_limit_str,
                    "age_limit_months": limit_months,
                    "reason": info["reason"],
                    "severity": info["severity"],
                    "alternative": info["alternative"],
                }
    return None


# ---------------------------------------------------------------------------
# Main agent entry point
# ---------------------------------------------------------------------------

def check_pediatric(
    active_ingredient: str,
    child_age: Optional[float] = None,
    child_weight: Optional[float] = None,
) -> dict:
    """
    Main entry point for Agent 8 - Pediatric Safety Checker.

    Args:
        active_ingredient: The active ingredient / drug name.
        child_age: Child's age in months (float to support fractional months).
        child_weight: Child's weight in kg.

    Returns:
        Standardized agent result dict with comprehensive pediatric safety data.
    """
    result: dict = {
        "agent_number": AGENT_NUMBER,
        "agent_name": AGENT_NAME,
        "status": "PASS",
        "confidence_score": 0.0,
        "is_safe_for_child": None,
        "recommended_dose": None,
        "contraindications": [],
        "warnings": [],
        "suitable_formulation": None,
        "formulation_recommendation": None,
        "weight_validation": None,
        "dangerous_drug_override": None,
        "pakistan_warnings": [],
        "side_effects_info": None,
        "dailymed_info": None,
        "display_message": "",
        "fail_reason": None,
    }

    try:
        # -- Guard: empty, None, or placeholder ingredient --
        if (
            not active_ingredient
            or not active_ingredient.strip()
            or active_ingredient.strip().lower() in ("unknown", "n/a", "none")
        ):
            result["status"] = "PASS"
            result["confidence_score"] = 0.0
            result["display_message"] = (
                "No active ingredient provided. "
                "Cannot perform pediatric safety assessment."
            )
            return result

        # -- Early exit: no pediatric data provided --
        if child_age is None and child_weight is None:
            result["status"] = "PASS"
            result["confidence_score"] = 0.50
            result["display_message"] = (
                "No pediatric patient data provided. "
                "Skipping pediatric safety check."
            )
            return result

        # -- Validate and normalize age/weight --
        age_months = max(0.0, float(child_age)) if child_age is not None else None

        if child_weight is not None and child_weight <= 0:
            result["warnings"].append(
                f"Invalid weight provided ({child_weight} kg). "
                "Weight must be positive. Dose calculations skipped."
            )
            child_weight = None  # Treat as missing so dose calc is skipped

        # If only weight is provided without age, we cannot safely default
        # age to 0 (newborn) as that would trigger incorrect dangerous-drug
        # overrides and wrong formulation recommendations.
        if age_months is None and child_weight is not None:
            result["warnings"].append(
                "Child weight provided but age is missing. "
                "Some age-dependent safety checks cannot be performed."
            )
            # Use a conservative sentinel -- skip age-dependent checks below
            age_months = None

        # For the remainder of this function, age_months may be None
        # (meaning unknown). Default to 0.0 ONLY where a float is required
        # and the check is weight-only.
        age_for_checks = age_months if age_months is not None else 0.0

        # ====================================================================
        # STEP 0: Check dangerous drug overrides (HIGHEST PRIORITY)
        # These override ALL database data.
        # ====================================================================
        # Only run age-dependent dangerous-drug check when age is actually known
        dangerous_check = None
        if age_months is not None:
            dangerous_check = _check_dangerous_drug_override(
                active_ingredient, age_months
            )
        if dangerous_check and dangerous_check["is_dangerous"]:
            result["dangerous_drug_override"] = dangerous_check
            result["is_safe_for_child"] = False
            result["status"] = "FAIL"
            result["confidence_score"] = 0.99
            result["fail_reason"] = (
                f"CRITICAL: {active_ingredient.title()} is NEVER safe for children "
                f"under {dangerous_check['age_limit']}. "
                f"{dangerous_check['reason']}."
            )
            result["display_message"] = (
                f"CRITICAL SAFETY ALERT: '{active_ingredient.title()}' must NEVER be given "
                f"to children under {dangerous_check['age_limit']}. "
                f"Reason: {dangerous_check['reason']}. "
                f"Recommendation: {dangerous_check['alternative']}."
            )
            result["warnings"].append(dangerous_check["reason"])
            # Still add Pakistan warnings
            result["pakistan_warnings"] = PAKISTAN_WARNINGS
            return result

        # ====================================================================
        # STEP 1: WHO weight-for-age validation
        # ====================================================================
        if child_weight is not None and child_weight > 0 and age_months is not None:
            weight_validation = _validate_weight_for_age(age_months, child_weight)
            result["weight_validation"] = weight_validation
            if weight_validation["percentile_warning"]:
                result["warnings"].append(weight_validation["percentile_warning"])

        # ====================================================================
        # STEP 2: Query Supabase pediatric_safety table (primary data source)
        # ====================================================================
        drug_data = _query_supabase_pediatric(active_ingredient)
        data_source = "supabase"

        if drug_data:
            logger.info(
                "Found pediatric data in Supabase for '%s'", active_ingredient
            )
        else:
            logger.info(
                "No Supabase pediatric data for '%s', trying DailyMed fallback",
                active_ingredient,
            )
            data_source = "none"

        # ====================================================================
        # STEP 2b: Query Supabase drug_side_effects for pediatric warnings
        # ====================================================================
        side_effects_data = _query_supabase_side_effects(active_ingredient)
        if side_effects_data:
            result["side_effects_info"] = {
                "common": side_effects_data.get("common_side_effects"),
                "serious": side_effects_data.get("serious_side_effects"),
                "black_box": side_effects_data.get("black_box_warnings"),
            }
            # Add black box warnings to main warnings list
            black_box = side_effects_data.get("black_box_warnings")
            if black_box:
                if isinstance(black_box, list):
                    for warning in black_box:
                        result["warnings"].append(f"BLACK BOX: {warning}")
                elif isinstance(black_box, str) and black_box.strip():
                    result["warnings"].append(f"BLACK BOX: {black_box}")

        # ====================================================================
        # STEP 3: Fetch DailyMed as fallback / supplementary source
        # ====================================================================
        dailymed_info = _fetch_dailymed_pediatric(active_ingredient)
        if dailymed_info:
            result["dailymed_info"] = dailymed_info
            logger.info("Got DailyMed pediatric info for '%s'", active_ingredient)

        # ====================================================================
        # STEP 4: Handle case where no data found anywhere
        # ====================================================================
        if drug_data is None:
            msg = (
                f"'{active_ingredient}' not found in pediatric safety database. "
                "Consult a pediatrician before giving this medicine to a child."
            )
            if dailymed_info and dailymed_info.get("pediatric_use"):
                msg += " DailyMed reference information is available."
                data_source = "dailymed"

            result["status"] = "UNCERTAIN"
            result["confidence_score"] = 0.30
            result["display_message"] = msg

            # Still provide formulation recommendation based on age (if known)
            if age_months is not None:
                result["formulation_recommendation"] = _get_formulation_recommendation(
                    age_months
                )
            result["pakistan_warnings"] = PAKISTAN_WARNINGS
            return result

        # ====================================================================
        # STEP 5: Check age safety against database minimum age
        # ====================================================================
        contraindications_raw = drug_data.get("contraindications", [])
        if isinstance(contraindications_raw, str):
            contraindications_raw = [c.strip() for c in contraindications_raw.split(",") if c.strip()]
        elif not isinstance(contraindications_raw, list):
            contraindications_raw = []
        result["contraindications"] = contraindications_raw

        warnings_raw = drug_data.get("warnings", [])
        if isinstance(warnings_raw, str):
            warnings_raw = [w.strip() for w in warnings_raw.split(",") if w.strip()]
        elif not isinstance(warnings_raw, list):
            warnings_raw = []
        result["warnings"].extend(warnings_raw)

        min_age = drug_data.get("minimum_age_months", 0)
        if min_age is None:
            min_age = 0

        if age_months is not None and age_months < min_age:
            result["is_safe_for_child"] = False
            result["status"] = "FAIL"
            result["confidence_score"] = 0.95
            safe_from_str = (
                f"{min_age} months" if min_age < 24
                else f"{min_age // 12} years"
            )
            result["fail_reason"] = (
                f"Not recommended for children under {safe_from_str}"
            )
            result["display_message"] = (
                f"WARNING: '{active_ingredient}' is NOT safe for a child aged "
                f"{age_months:.0f} months. Minimum recommended age: {safe_from_str}. "
                f"Contraindications: {', '.join(contraindications_raw) if contraindications_raw else 'See prescribing info'}."
            )
            result["formulation_recommendation"] = _get_formulation_recommendation(
                age_months
            )
            result["pakistan_warnings"] = PAKISTAN_WARNINGS
            return result
        elif age_months is None and min_age > 0:
            # Age unknown but drug has a minimum age requirement -- warn
            result["warnings"].append(
                f"This medicine has a minimum age requirement of "
                f"{min_age} months. Cannot verify safety without child's age."
            )
            # Cannot confirm safety without age when a minimum age exists
            result["is_safe_for_child"] = None
        else:
            result["is_safe_for_child"] = True

        # ====================================================================
        # STEP 6: Advanced dose calculation
        # ====================================================================
        if child_weight is not None and child_weight > 0:
            dose_info = _calculate_advanced_dose(
                drug_data, child_weight, age_for_checks
            )
            result["recommended_dose"] = dose_info
        else:
            result["recommended_dose"] = {
                "dose_per_kg": drug_data.get("dose_per_kg"),
                "max_daily_doses": drug_data.get("max_daily_doses"),
                "note": "Provide child's weight for exact dose calculation "
                        "(per-kg and BSA-based).",
            }

        # ====================================================================
        # STEP 7: Formulation recommendation (age-based + DB available forms)
        # ====================================================================
        formulation_rec = _get_formulation_recommendation(age_for_checks)
        result["formulation_recommendation"] = formulation_rec

        # Match available forms from DB with age-appropriate recommendations
        available_forms = drug_data.get("available_forms", [])
        if isinstance(available_forms, str):
            available_forms = [f.strip() for f in available_forms.split(",") if f.strip()]
        elif not isinstance(available_forms, list):
            available_forms = []

        suitable = None
        if available_forms:
            # Prefer forms that match the age recommendation
            recommended_keywords = []
            if age_for_checks < 6:
                recommended_keywords = ["drop"]
            elif age_for_checks < 24:
                recommended_keywords = ["drop", "syrup"]
            elif age_for_checks < 72:
                recommended_keywords = ["syrup", "chewable", "dispersible"]
            elif age_for_checks < 144:
                recommended_keywords = ["tablet", "syrup", "chewable"]
            else:
                recommended_keywords = ["tablet", "capsule"]

            for keyword in recommended_keywords:
                for form in available_forms:
                    if keyword in form.lower():
                        suitable = form
                        break
                if suitable:
                    break

            if not suitable:
                suitable = available_forms[0]
                result["warnings"].append(
                    f"No ideal age-appropriate formulation found. "
                    f"Available: {', '.join(available_forms)}. "
                    f"Recommended for this age: {', '.join(formulation_rec['recommended_forms'])}."
                )

        result["suitable_formulation"] = suitable

        # ====================================================================
        # STEP 8: Add Pakistan-specific warnings
        # ====================================================================
        result["pakistan_warnings"] = PAKISTAN_WARNINGS

        # ====================================================================
        # STEP 9: Build comprehensive display message
        # ====================================================================
        result["status"] = "PASS"
        result["confidence_score"] = 0.90 if data_source == "supabase" else 0.70

        if age_months is not None:
            age_str = (
                f"{age_months:.0f} months" if age_months < 24
                else f"{age_months / 12:.1f} years"
            )
            msg_parts = [
                f"'{active_ingredient}' is generally considered safe for a child aged {age_str}.",
            ]
        else:
            msg_parts = [
                f"'{active_ingredient}' found in pediatric safety database. "
                "Age not provided -- verify age suitability with a pediatrician.",
            ]

        # Dose info
        if (
            result["recommended_dose"]
            and isinstance(result["recommended_dose"], dict)
            and result["recommended_dose"].get("recommended_single_dose_mg") is not None
        ):
            dose = result["recommended_dose"]["recommended_single_dose_mg"]
            freq = result["recommended_dose"].get("frequency", "consult doctor for frequency")
            bsa = result["recommended_dose"].get("bsa_m2")
            msg_parts.append(
                f"Recommended single dose: {dose} mg ({freq}). "
                f"BSA: {bsa} m2."
            )

            if result["recommended_dose"].get("exceeds_max_single"):
                msg_parts.append(
                    "ALERT: Calculated dose exceeds maximum adult single dose!"
                )
            if result["recommended_dose"].get("exceeds_max_daily"):
                msg_parts.append(
                    "ALERT: Calculated daily dose exceeds maximum adult daily dose!"
                )
            if result["recommended_dose"].get("adult_dose_warning"):
                msg_parts.append(
                    "WARNING: Near-adult dosing detected for a child. Verify with pediatrician."
                )
        elif result["recommended_dose"] and result["recommended_dose"].get("dose_per_kg"):
            msg_parts.append(
                f"Dose: {drug_data.get('dose_per_kg', 'consult doctor')}."
            )

        # Formulation
        if suitable:
            msg_parts.append(f"Suggested formulation: {suitable}.")

        # Weight validation warning
        if (
            result.get("weight_validation")
            and result["weight_validation"].get("percentile_warning")
        ):
            msg_parts.append(result["weight_validation"]["percentile_warning"])

        # Side effects
        if result.get("side_effects_info") and result["side_effects_info"].get("black_box"):
            msg_parts.append("This drug has BLACK BOX warnings. Review carefully.")

        # First clinical warning
        if warnings_raw:
            msg_parts.append(f"Clinical note: {warnings_raw[0]}")

        # DailyMed reference
        if dailymed_info:
            msg_parts.append("Additional reference available from DailyMed.")

        # Pakistan notice
        msg_parts.append(
            "Pakistan notice: Verify medicine is from a DRAP-registered manufacturer."
        )

        result["display_message"] = " ".join(msg_parts)

    except Exception as exc:  # noqa: BLE001
        logger.exception("Agent 8 error for '%s': %s", active_ingredient, exc)
        result["status"] = "UNCERTAIN"
        result["confidence_score"] = 0.0
        result["fail_reason"] = f"Error checking pediatric safety: {exc}"
        result["display_message"] = (
            "Could not complete pediatric safety check. "
            "Consult a pediatrician before administering any medicine to a child."
        )
        result["pakistan_warnings"] = PAKISTAN_WARNINGS

    return result
