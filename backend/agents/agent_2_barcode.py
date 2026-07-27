"""
Agent 2 — KASHIF (The Revealer)
Uses Claude Vision with a forensic-grade prompt to read and analyze barcodes
from the back label, validates EAN-13/UPC-A check digits, checks GS1 country
prefixes, detects tamper indicators, and cross-checks against Supabase
DRAP database.
"""

import os
import json
import logging
from typing import Optional

import anthropic

from utils.supabase_client import get_supabase, sanitize_like
from utils.api_retry import retry_api_call
from utils.model_config import VISION_MODEL, MAX_TOKENS_BARCODE


logger = logging.getLogger(__name__)

ANTHROPIC_API_KEY = os.getenv("ANTHROPIC_API_KEY", "")

AGENT_NUMBER = 2
AGENT_NAME = "KASHIF — The Revealer"

# GS1 country prefixes relevant for Pakistan pharma
GS1_PAKISTAN_PREFIX = "896"
GS1_KNOWN_PREFIXES = {
    "000-019": "United States",
    "020-029": "Restricted (in-store use)",
    "030-039": "United States (drugs)",
    "300-379": "France",
    "380": "Bulgaria",
    "400-440": "Germany",
    "450-459": "Japan",
    "460-469": "Russia",
    "471": "Taiwan",
    "480": "Philippines",
    "489": "Hong Kong",
    "490-499": "Japan",
    "500-509": "United Kingdom",
    "520-521": "Greece",
    "528": "Lebanon",
    "530": "Albania",
    "531": "Macedonia",
    "539": "Ireland",
    "540-549": "Belgium & Luxembourg",
    "560": "Portugal",
    "569": "Iceland",
    "570-579": "Denmark",
    "590": "Poland",
    "600-601": "South Africa",
    "609": "Mauritius",
    "611": "Morocco",
    "613": "Algeria",
    "616": "Kenya",
    "618": "Ivory Coast",
    "619": "Tunisia",
    "621": "Syria",
    "622": "Egypt",
    "624": "Libya",
    "625": "Jordan",
    "626": "Iran",
    "627": "Kuwait",
    "628": "Saudi Arabia",
    "629": "UAE",
    "690-699": "China",
    "729": "Israel",
    "730-739": "Sweden",
    "740": "Guatemala",
    "741": "El Salvador",
    "742": "Honduras",
    "743": "Nicaragua",
    "744": "Costa Rica",
    "745": "Panama",
    "746": "Dominican Republic",
    "750": "Mexico",
    "754-755": "Canada",
    "759": "Venezuela",
    "760-769": "Switzerland",
    "770-771": "Colombia",
    "773": "Uruguay",
    "775": "Peru",
    "777": "Bolivia",
    "778-779": "Argentina",
    "780": "Chile",
    "784": "Paraguay",
    "786": "Ecuador",
    "789-790": "Brazil",
    "800-839": "Italy",
    "840-849": "Spain",
    "850": "Cuba",
    "858": "Slovakia",
    "859": "Czech Republic",
    "860": "Serbia",
    "865": "Mongolia",
    "867": "North Korea",
    "868-869": "Turkey",
    "870-879": "Netherlands",
    "880": "South Korea",
    "884": "Cambodia",
    "885": "Thailand",
    "888": "Singapore",
    "890": "India",
    "893": "Vietnam",
    "896": "Pakistan",
    "899": "Indonesia",
    "900-919": "Austria",
    "930-939": "Australia",
    "940-949": "New Zealand",
    "955": "Malaysia",
    "958": "Macau",
}


def _get_client() -> anthropic.Anthropic:
    return anthropic.Anthropic(api_key=ANTHROPIC_API_KEY)


FORENSIC_BARCODE_PROMPT = """You are a forensic pharmaceutical barcode analyst specializing in detecting counterfeit medicines. Analyze this medicine back-label image with extreme attention to detail.

STEP-BY-STEP ANALYSIS (use chain-of-thought reasoning):

**Step 1 - Barcode Identification:**
- Scan the ENTIRE image for ALL barcodes and machine-readable codes
- Identify each barcode type: EAN-13, UPC-A, QR Code, DataMatrix, Code 128, Code 39, or other
- For each barcode found, attempt to read the exact digits/data printed below or beside it
- Count the total number of distinct barcodes visible

**Step 2 - Digit Extraction:**
- For numeric barcodes (EAN-13, UPC-A), carefully read EVERY digit
- EAN-13 has exactly 13 digits; UPC-A has exactly 12 digits
- Read left-to-right, noting any digits that are unclear or ambiguous
- If digits are printed below the barcode lines, read those (they are the human-readable interpretation)
- For QR codes or DataMatrix, describe the data if decodable

**Step 3 - Print Quality Assessment:**
- Evaluate barcode CLARITY: Are the bars sharp and well-defined, or blurry/fuzzy?
- Evaluate CONTRAST: Is there strong black-on-white contrast, or is it faded/grey?
- Check for DAMAGE: Any scratches, tears, or wear across the barcode area?
- Check for SMUDGING: Any ink smearing or bleeding that could affect scanning?
- Rate overall print quality as: EXCELLENT, GOOD, FAIR, POOR, or VERY_POOR

**Step 4 - Tamper Detection:**
- Look for MULTIPLE OVERLAPPING barcodes (a barcode sticker placed over another barcode)
- Check for STICKER EVIDENCE: adhesive residue, raised edges, different paper texture, color mismatch between barcode area and surrounding label
- Look for REPRINTING signs: misaligned printing, different ink density in barcode area vs rest of label
- Check if the barcode area looks like it was digitally edited or pasted on
- Look for inconsistent fonts between barcode digits and other label text

**Step 5 - Surrounding Information:**
- Note any BATCH NUMBER (Batch No., Lot No., B.No.) visible near the barcode
- Note any MANUFACTURING DATE (Mfg Date, Mfg. Dt., MFD) visible
- Note any EXPIRY DATE (Exp Date, Exp. Dt., EXP, Best Before) visible
- Note any MANUFACTURING LOCATION or plant code

**Step 6 - Anomaly Detection:**
- Is the barcode PROPORTIONALLY sized for the packaging? (too small or too large is suspicious)
- Is the barcode POSITIONED normally? (typically bottom back of box)
- Does the barcode style match what you'd expect for this type of product?

Return ONLY valid JSON with this exact structure:
{
  "analysis_reasoning": "Your step-by-step chain-of-thought analysis here (2-4 sentences summarizing what you observed)",
  "barcodes_found": [
    {
      "barcode_type": "EAN-13 | UPC-A | QR | DataMatrix | Code128 | Code39 | other",
      "barcode_number": "the exact digits/data or null if unreadable",
      "digits_confident": true,
      "position_on_label": "bottom-center | bottom-left | bottom-right | other"
    }
  ],
  "total_barcodes_detected": 1,
  "primary_barcode_type": "EAN-13",
  "primary_barcode_number": "the main barcode digits or null",
  "barcode_readable": true,
  "print_quality": {
    "clarity": "EXCELLENT | GOOD | FAIR | POOR | VERY_POOR",
    "contrast": "EXCELLENT | GOOD | FAIR | POOR | VERY_POOR",
    "damage_detected": false,
    "smudging_detected": false,
    "overall_quality": "EXCELLENT | GOOD | FAIR | POOR | VERY_POOR"
  },
  "tamper_indicators": {
    "multiple_overlapping_barcodes": false,
    "sticker_residue_detected": false,
    "raised_edges_detected": false,
    "color_mismatch_in_barcode_area": false,
    "misaligned_printing": false,
    "different_ink_density": false,
    "digitally_edited_appearance": false,
    "font_inconsistency": false,
    "abnormal_barcode_size": false,
    "abnormal_barcode_position": false
  },
  "nearby_info": {
    "batch_number": "string or null",
    "manufacturing_date": "string or null",
    "expiry_date": "string or null",
    "manufacturing_location": "string or null"
  }
}

CRITICAL RULES:
- Return ONLY the JSON object, no markdown formatting, no extra text
- If you cannot read digits with confidence, set digits_confident to false and still attempt to provide your best reading
- Be extremely thorough in tamper detection - counterfeit medicines kill people
- When in doubt about tamper indicators, flag them as true (better safe than sorry)"""


def _read_barcode_forensic(client: anthropic.Anthropic, back_image_b64: str) -> dict:
    """Use Claude Vision with a forensic prompt to extract and analyze barcode information."""

    if not back_image_b64 or not back_image_b64.strip():
        raise ValueError("Back image data is empty or missing")

    message = retry_api_call(lambda: client.messages.create(
        model=VISION_MODEL,
        max_tokens=MAX_TOKENS_BARCODE,
        messages=[
            {
                "role": "user",
                "content": [
                    {
                        "type": "image",
                        "source": {
                            "type": "base64",
                            "media_type": "image/jpeg",
                            "data": back_image_b64,
                        },
                    },
                    {"type": "text", "text": FORENSIC_BARCODE_PROMPT},
                ],
            }
        ],
    ))

    if not message.content:
        raise ValueError("Claude Vision returned empty response for back label")

    raw = message.content[0].text.strip()
    # Strip markdown code fences if present
    if raw.startswith("```"):
        raw = raw.split("\n", 1)[1]
        raw = raw.rsplit("```", 1)[0]
    return json.loads(raw)


def _validate_ean13_check_digit(barcode_number: str) -> dict:
    """
    Validate an EAN-13 barcode check digit.
    Returns a dict with validation results.
    """
    digits_only = "".join(c for c in str(barcode_number) if c.isdigit())

    if len(digits_only) != 13:
        return {
            "valid_length": False,
            "check_digit_valid": None,
            "expected_check_digit": None,
            "actual_check_digit": None,
            "message": f"Expected 13 digits, got {len(digits_only)}",
        }

    total = 0
    for i, d in enumerate(digits_only[:12]):
        weight = 1 if i % 2 == 0 else 3
        total += int(d) * weight
    expected_check = (10 - (total % 10)) % 10
    actual_check = int(digits_only[12])

    is_valid = expected_check == actual_check
    return {
        "valid_length": True,
        "check_digit_valid": is_valid,
        "expected_check_digit": expected_check,
        "actual_check_digit": actual_check,
        "message": "Check digit valid" if is_valid else "Check digit INVALID - possible counterfeit",
    }


def _validate_upca_check_digit(barcode_number: str) -> dict:
    """
    Validate a UPC-A barcode check digit.
    UPC-A has 12 digits. The check digit algorithm:
      1. Sum digits at odd positions (1, 3, 5, 7, 9, 11) and multiply by 3
      2. Sum digits at even positions (2, 4, 6, 8, 10)
      3. Check digit = (10 - (total % 10)) % 10
    """
    digits_only = "".join(c for c in str(barcode_number) if c.isdigit())

    if len(digits_only) != 12:
        return {
            "valid_length": False,
            "check_digit_valid": None,
            "expected_check_digit": None,
            "actual_check_digit": None,
            "message": f"Expected 12 digits for UPC-A, got {len(digits_only)}",
        }

    # UPC-A: odd positions (0-indexed: 0,2,4,6,8,10) * 3 + even positions (1,3,5,7,9)
    total = 0
    for i, d in enumerate(digits_only[:11]):
        weight = 3 if i % 2 == 0 else 1
        total += int(d) * weight
    expected_check = (10 - (total % 10)) % 10
    actual_check = int(digits_only[11])

    is_valid = expected_check == actual_check
    return {
        "valid_length": True,
        "check_digit_valid": is_valid,
        "expected_check_digit": expected_check,
        "actual_check_digit": actual_check,
        "message": "UPC-A check digit valid" if is_valid else "UPC-A check digit INVALID - possible counterfeit",
    }


def _check_gs1_country_prefix(barcode_number: str) -> dict:
    """
    Check the GS1 country prefix of an EAN-13 barcode.
    The first 3 digits indicate the country of the issuing GS1 organization.
    896 = Pakistan.
    """
    digits_only = "".join(c for c in str(barcode_number) if c.isdigit())

    if len(digits_only) < 3:
        return {
            "prefix": None,
            "country": None,
            "is_pakistan": False,
            "message": "Barcode too short to extract country prefix",
        }

    prefix_3 = digits_only[:3]

    # Direct 3-digit lookup
    country = GS1_KNOWN_PREFIXES.get(prefix_3)

    # If not found, try range-based lookup
    if not country:
        prefix_int = int(prefix_3)
        for range_key, range_country in GS1_KNOWN_PREFIXES.items():
            if "-" in range_key:
                low, high = range_key.split("-")
                if int(low) <= prefix_int <= int(high):
                    country = range_country
                    break

    is_pakistan = prefix_3 == GS1_PAKISTAN_PREFIX

    return {
        "prefix": prefix_3,
        "country": country or "Unknown",
        "is_pakistan": is_pakistan,
        "message": (
            f"GS1 prefix {prefix_3} = {country or 'Unknown'}"
            + (" (Pakistan - expected for local medicines)" if is_pakistan else "")
        ),
    }


def _cross_check_supabase(
    barcode_number: Optional[str] = None,
    medicine_name: Optional[str] = None,
    reg_number: Optional[str] = None,
) -> Optional[dict]:
    """
    Cross-check the barcode/medicine against the Supabase DRAP database.
    Tries barcode lookup first, then registration number, then name-based search.
    """
    try:
        supabase = get_supabase()

        # Try barcode lookup in drap_medicines
        if barcode_number:
            resp = (
                supabase.table("drap_medicines")
                .select("*")
                .eq("barcode", barcode_number)
                .limit(1)
                .execute()
            )
            if resp.data:
                return resp.data[0]

        # Try registration number lookup
        if reg_number:
            resp = (
                supabase.table("drap_medicines")
                .select("*")
                .eq("registration_number", reg_number)
                .limit(1)
                .execute()
            )
            if resp.data:
                return resp.data[0]

        # Fallback: search by medicine name using ilike
        if medicine_name:
            resp = (
                supabase.table("drap_medicines")
                .select("*")
                .ilike("brand_name", f"%{sanitize_like(medicine_name)}%")
                .limit(5)
                .execute()
            )
            if resp.data:
                return resp.data[0]

    except Exception as exc:
        logger.warning("Supabase cross-check failed: %s", exc)

    return None


def _check_duplicate_barcode(barcode_number: str) -> dict:
    """
    Check if the same barcode is registered to multiple different products
    in the database (sign of barcode cloning/duplication).
    """
    result = {
        "is_duplicate": False,
        "duplicate_count": 0,
        "duplicate_products": [],
        "message": "No duplicate barcodes found",
    }

    if not barcode_number:
        return result

    try:
        supabase = get_supabase()
        resp = (
            supabase.table("drap_medicines")
            .select("brand_name, registration_number, manufacturer")
            .eq("barcode", barcode_number)
            .execute()
        )

        if resp.data and len(resp.data) > 1:
            result["is_duplicate"] = True
            result["duplicate_count"] = len(resp.data)
            result["duplicate_products"] = [
                {
                    "brand_name": r.get("brand_name"),
                    "registration_number": r.get("registration_number"),
                    "manufacturer": r.get("manufacturer"),
                }
                for r in resp.data
            ]
            result["message"] = (
                f"WARNING: Barcode {barcode_number} is registered to "
                f"{len(resp.data)} different products - possible cloning"
            )
    except Exception as exc:
        logger.warning("Duplicate barcode check failed: %s", exc)

    return result


def _calculate_tamper_score(vision_data: dict, check_digit_valid: Optional[bool]) -> dict:
    """
    Calculate a tamper suspicion score based on all forensic indicators.

    Scoring:
      - Multiple overlapping barcodes = HIGH (+30)
      - Sticker residue detected = HIGH (+30)
      - Raised edges detected = HIGH (+25)
      - Color mismatch in barcode area = MEDIUM (+20)
      - Misaligned printing = MEDIUM (+15)
      - Different ink density = MEDIUM (+15)
      - Digitally edited appearance = HIGH (+30)
      - Font inconsistency = MEDIUM (+15)
      - Abnormal barcode size = LOW (+10)
      - Abnormal barcode position = LOW (+10)
      - Poor/Very Poor print quality = MEDIUM (+15)
      - Invalid check digit = CRITICAL (+50)

    Returns score 0-100 and severity level.
    """
    tamper = vision_data.get("tamper_indicators", {})
    print_quality = vision_data.get("print_quality", {})

    score = 0
    flags = []

    # Tamper indicator scoring
    indicator_weights = {
        "multiple_overlapping_barcodes": (30, "HIGH", "Multiple overlapping barcodes detected"),
        "sticker_residue_detected": (30, "HIGH", "Sticker/adhesive residue near barcode"),
        "raised_edges_detected": (25, "HIGH", "Raised edges around barcode area"),
        "color_mismatch_in_barcode_area": (20, "MEDIUM", "Color mismatch in barcode region"),
        "misaligned_printing": (15, "MEDIUM", "Misaligned printing in barcode area"),
        "different_ink_density": (15, "MEDIUM", "Different ink density near barcode"),
        "digitally_edited_appearance": (30, "HIGH", "Barcode area appears digitally edited"),
        "font_inconsistency": (15, "MEDIUM", "Font inconsistency in barcode digits"),
        "abnormal_barcode_size": (10, "LOW", "Abnormal barcode size for packaging"),
        "abnormal_barcode_position": (10, "LOW", "Barcode in unusual position"),
    }

    for indicator, (weight, severity, description) in indicator_weights.items():
        if tamper.get(indicator, False):
            score += weight
            flags.append({"indicator": indicator, "severity": severity, "description": description})

    # Print quality scoring
    overall_quality = print_quality.get("overall_quality", "GOOD")
    if overall_quality == "VERY_POOR":
        score += 20
        flags.append({
            "indicator": "very_poor_print_quality",
            "severity": "MEDIUM",
            "description": "Very poor barcode print quality",
        })
    elif overall_quality == "POOR":
        score += 15
        flags.append({
            "indicator": "poor_print_quality",
            "severity": "MEDIUM",
            "description": "Poor barcode print quality",
        })

    # Check digit validation
    if check_digit_valid is False:
        score += 50
        flags.append({
            "indicator": "invalid_check_digit",
            "severity": "CRITICAL",
            "description": "Barcode check digit is mathematically invalid",
        })

    # Cap at 100
    score = min(score, 100)

    # Determine overall severity
    if score >= 50:
        overall_severity = "CRITICAL"
    elif score >= 30:
        overall_severity = "HIGH"
    elif score >= 15:
        overall_severity = "MEDIUM"
    elif score > 0:
        overall_severity = "LOW"
    else:
        overall_severity = "NONE"

    return {
        "tamper_score": score,
        "overall_severity": overall_severity,
        "flags": flags,
        "flag_count": len(flags),
    }


def validate_barcode(
    back_image_b64: str,
    medicine_name: Optional[str] = None,
    reg_number: Optional[str] = None,
) -> dict:
    """
    Main entry point for Agent 2.

    Args:
        back_image_b64: Base64-encoded back label image.
        medicine_name: Medicine name from Agent 1 for cross-reference.
        reg_number: Registration number from Agent 1 for cross-reference.

    Returns:
        Standardized agent result dict.
    """
    result: dict = {
        "agent_number": AGENT_NUMBER,
        "agent_name": AGENT_NAME,
        "status": "UNCERTAIN",
        "confidence_score": 0.0,
        "barcode_data": {
            "barcode_detected": False,
            "primary_barcode_type": None,
            "primary_barcode_number": None,
            "barcode_readable": False,
            "total_barcodes_detected": 0,
            "all_barcodes": [],
        },
        "print_quality": None,
        "ean13_validation": None,
        "upca_validation": None,
        "gs1_country_check": None,
        "drap_match": None,
        "duplicate_barcode_check": None,
        "tamper_detection": None,
        "nearby_info": None,
        "vision_reasoning": None,
        "copied_barcode_detected": False,
        "display_message": "",
        "fail_reason": None,
    }

    try:
        client = _get_client()

        # ---- Forensic Vision Analysis ----
        vision_data = _read_barcode_forensic(client, back_image_b64)

        result["vision_reasoning"] = vision_data.get("analysis_reasoning")
        result["nearby_info"] = vision_data.get("nearby_info")
        result["print_quality"] = vision_data.get("print_quality")

        # Populate barcode data
        barcodes_found = vision_data.get("barcodes_found", [])
        total_barcodes = vision_data.get("total_barcodes_detected", len(barcodes_found))
        primary_type = vision_data.get("primary_barcode_type")
        primary_number = vision_data.get("primary_barcode_number")
        barcode_readable = vision_data.get("barcode_readable", False)

        result["barcode_data"] = {
            "barcode_detected": total_barcodes > 0,
            "primary_barcode_type": primary_type,
            "primary_barcode_number": primary_number,
            "barcode_readable": barcode_readable,
            "total_barcodes_detected": total_barcodes,
            "all_barcodes": barcodes_found,
        }

        # ---- No barcode detected ----
        if total_barcodes == 0:
            result["status"] = "FAIL"
            result["confidence_score"] = 0.70
            result["fail_reason"] = "No barcode detected on back label"
            result["display_message"] = (
                "No barcode found on the back label. "
                "Legitimate medicines typically have a barcode."
            )
            return result

        # ---- Barcode not readable ----
        if not barcode_readable or not primary_number:
            result["status"] = "UNCERTAIN"
            result["confidence_score"] = 0.40
            result["display_message"] = (
                "Barcode detected but not readable. "
                "This could indicate a low-quality photocopy or damaged packaging. "
                "Please retake photo with better lighting."
            )
            # Still compute tamper score from visual indicators
            tamper_result = _calculate_tamper_score(vision_data, check_digit_valid=None)
            result["tamper_detection"] = tamper_result
            if tamper_result["overall_severity"] in ("HIGH", "CRITICAL"):
                result["status"] = "FAIL"
                result["confidence_score"] = 0.65
                result["fail_reason"] = "Tamper indicators detected despite unreadable barcode"
                result["display_message"] += (
                    f" Additionally, {tamper_result['flag_count']} tamper indicator(s) were detected."
                )
            return result

        # ---- Check Digit Validation ----
        check_digit_valid = None

        digits_only = "".join(c for c in str(primary_number) if c.isdigit())

        if primary_type in ("EAN-13", "EAN13") or len(digits_only) == 13:
            ean_validation = _validate_ean13_check_digit(primary_number)
            result["ean13_validation"] = ean_validation
            if ean_validation.get("valid_length"):
                check_digit_valid = ean_validation["check_digit_valid"]

        elif primary_type in ("UPC-A", "UPC", "UPCA") or len(digits_only) == 12:
            upca_validation = _validate_upca_check_digit(primary_number)
            result["upca_validation"] = upca_validation
            if upca_validation.get("valid_length"):
                check_digit_valid = upca_validation["check_digit_valid"]

        # Also try EAN-13 if we have 13 digits regardless of reported type
        if len(digits_only) == 13 and result["ean13_validation"] is None:
            ean_validation = _validate_ean13_check_digit(primary_number)
            result["ean13_validation"] = ean_validation
            if ean_validation.get("valid_length"):
                check_digit_valid = ean_validation["check_digit_valid"]

        result["copied_barcode_detected"] = check_digit_valid is False

        # ---- GS1 Country Prefix Check ----
        if len(digits_only) >= 3 and len(digits_only) in (12, 13):
            gs1_result = _check_gs1_country_prefix(primary_number)
            result["gs1_country_check"] = gs1_result

        # ---- Cross-check against Supabase DRAP database ----
        drap_record = _cross_check_supabase(
            barcode_number=primary_number,
            medicine_name=medicine_name,
            reg_number=reg_number,
        )
        if drap_record:
            result["drap_match"] = {
                "found": True,
                "brand_name": drap_record.get("brand_name"),
                "registration_number": drap_record.get("registration_number"),
                "manufacturer": drap_record.get("manufacturer"),
                "generic_name": drap_record.get("generic_name"),
            }
        else:
            result["drap_match"] = {"found": False}

        # ---- Duplicate Barcode Check ----
        duplicate_result = _check_duplicate_barcode(primary_number)
        result["duplicate_barcode_check"] = duplicate_result

        # ---- Tamper Detection Scoring ----
        tamper_result = _calculate_tamper_score(vision_data, check_digit_valid)
        result["tamper_detection"] = tamper_result

        # ---- Registration Number Pattern Cross-Check ----
        reg_pattern_mismatch = False
        if reg_number and drap_record:
            db_reg = drap_record.get("registration_number", "")
            if db_reg and reg_number.strip().upper() != db_reg.strip().upper():
                reg_pattern_mismatch = True

        # ---- Determine Final Status ----
        tamper_score = tamper_result["tamper_score"]
        tamper_severity = tamper_result["overall_severity"]

        if check_digit_valid is False:
            # CRITICAL: Invalid check digit
            result["status"] = "FAIL"
            result["confidence_score"] = 0.92
            result["fail_reason"] = "Barcode check digit invalid - likely counterfeit"
            result["display_message"] = (
                "CRITICAL: Barcode validation FAILED. The check digit is mathematically "
                "invalid, which is a strong indicator of a counterfeit product. "
                "Do NOT use this medicine."
            )
        elif tamper_severity == "CRITICAL":
            result["status"] = "FAIL"
            result["confidence_score"] = 0.88
            result["fail_reason"] = f"Critical tamper indicators detected (score: {tamper_score}/100)"
            flags_desc = "; ".join(f["description"] for f in tamper_result["flags"][:3])
            result["display_message"] = (
                f"CRITICAL: Multiple tamper indicators detected on barcode area. "
                f"Findings: {flags_desc}. This medicine is highly suspicious."
            )
        elif tamper_severity == "HIGH":
            result["status"] = "FAIL"
            result["confidence_score"] = 0.78
            result["fail_reason"] = f"High tamper suspicion (score: {tamper_score}/100)"
            flags_desc = "; ".join(f["description"] for f in tamper_result["flags"][:3])
            result["display_message"] = (
                f"WARNING: Tamper indicators detected on barcode. "
                f"Findings: {flags_desc}. Exercise caution with this medicine."
            )
        elif duplicate_result.get("is_duplicate"):
            result["status"] = "FAIL"
            result["confidence_score"] = 0.80
            result["fail_reason"] = "Barcode registered to multiple products"
            result["display_message"] = (
                f"WARNING: This barcode ({primary_number}) is registered to "
                f"{duplicate_result['duplicate_count']} different products in the database. "
                "This is a sign of barcode cloning."
            )
        elif reg_pattern_mismatch:
            result["status"] = "FAIL"
            result["confidence_score"] = 0.75
            result["fail_reason"] = "Registration number mismatch with database record"
            result["display_message"] = (
                "WARNING: The registration number on this medicine does not match "
                "the database record associated with this barcode. Possible relabeling."
            )
        elif tamper_severity == "MEDIUM":
            result["status"] = "UNCERTAIN"
            result["confidence_score"] = 0.55
            flags_desc = "; ".join(f["description"] for f in tamper_result["flags"][:2])
            result["display_message"] = (
                f"Barcode ({primary_type or 'unknown'}) detected: {primary_number}. "
                f"Some quality concerns noted: {flags_desc}. "
                "Consider verifying with the manufacturer."
            )
        else:
            # PASS
            result["status"] = "PASS"
            confidence = 0.85

            # Boost confidence for additional positive signals
            if check_digit_valid is True:
                confidence += 0.05
            if drap_record:
                confidence += 0.05
            gs1 = result.get("gs1_country_check")
            if gs1 and gs1.get("is_pakistan"):
                confidence += 0.03

            result["confidence_score"] = min(confidence, 0.98)

            msg_parts = [
                f"Barcode ({primary_type or 'unknown type'}) validated successfully.",
                f"Number: {primary_number}.",
            ]
            if check_digit_valid is True:
                msg_parts.append("Check digit: VALID.")
            if gs1 and gs1.get("country"):
                msg_parts.append(f"Origin: {gs1['country']} (prefix {gs1['prefix']}).")
            if drap_record:
                msg_parts.append(
                    f"Matched DRAP record: {drap_record.get('brand_name', 'N/A')}."
                )
            nearby = result.get("nearby_info") or {}
            if nearby.get("batch_number"):
                msg_parts.append(f"Batch: {nearby['batch_number']}.")
            if nearby.get("expiry_date"):
                msg_parts.append(f"Expiry: {nearby['expiry_date']}.")

            result["display_message"] = " ".join(msg_parts)

    except ValueError as exc:
        logger.warning("Agent 2 input/response error: %s", exc)
        result["status"] = "UNCERTAIN"
        result["confidence_score"] = 0.0
        result["fail_reason"] = f"Input error: {exc}"
        result["display_message"] = (
            "Could not process the back label image. Please ensure the image is "
            "properly captured, well-lit, and try again."
        )
    except json.JSONDecodeError as exc:
        result["status"] = "UNCERTAIN"
        result["confidence_score"] = 0.20
        result["fail_reason"] = f"Failed to parse barcode analysis data: {exc}"
        result["display_message"] = "Could not analyze barcode data. Please retake the photo with better lighting."
    except anthropic.APIError as exc:
        result["status"] = "UNCERTAIN"
        result["confidence_score"] = 0.0
        result["fail_reason"] = f"API error: {exc}"
        result["display_message"] = "Service temporarily unavailable. Please try again."
    except Exception as exc:  # noqa: BLE001
        logger.exception("Agent 2 unexpected error")
        result["status"] = "UNCERTAIN"
        result["confidence_score"] = 0.0
        result["fail_reason"] = f"Unexpected error: {exc}"
        result["display_message"] = "An unexpected error occurred during barcode validation."

    return result
