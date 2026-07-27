"""
Agent 1 — RAKIB (The Watchman)
DRAP Registration & Authenticity Inspector
Extracts medicine details from the front label using Claude Vision
with forensic-level analysis and cross-references against the DRAP
registration database hosted on Supabase.
"""

import os
import base64
import json
import logging
import re
from datetime import datetime, date
from typing import Optional

import anthropic

from utils.supabase_client import get_supabase, sanitize_like
from utils.api_retry import retry_api_call
from utils.model_config import VISION_MODEL, MAX_TOKENS_REGISTRATION


logger = logging.getLogger(__name__)

ANTHROPIC_API_KEY = os.getenv("ANTHROPIC_API_KEY", "")

AGENT_NUMBER = 1
AGENT_NAME = "RAKIB — The Watchman"

# ---------------------------------------------------------------------------
# Weights for confidence scoring (total = 1.0)
# ---------------------------------------------------------------------------
FIELD_WEIGHTS = {
    "registration_number": 0.25,
    "brand_name": 0.15,
    "manufacturer": 0.15,
    "generic_name": 0.10,
    "strength": 0.10,
    "dosage_form": 0.08,
    "pack_size": 0.05,
    "expiry_valid": 0.02,
    "label_quality": 0.10,  # from 1-10 score mapped to 0-1
}


def _get_client() -> anthropic.Anthropic:
    return anthropic.Anthropic(api_key=ANTHROPIC_API_KEY)


# ---------------------------------------------------------------------------
# Vision extraction with forensic-level prompt
# ---------------------------------------------------------------------------

VISION_PROMPT = """You are a senior pharmaceutical forensic analyst specializing in \
Pakistani medicine packaging inspection. Your task is to perform an exhaustive, \
forensic-level analysis of the medicine front label image provided.

Think step by step through the following stages:

## STAGE 1 -- Complete Text Extraction
Carefully read every piece of text visible on the front label. Examine:
- Brand / trade name (the large, prominent product name)
- Generic / active ingredient name (usually in smaller text, often below the brand name; may be an INN name)
- Manufacturer / company name and city (often at the bottom or side)
- DRAP Registration Number -- look for any of these patterns: "Reg. No.", "DRN", "DRAP Reg.", \
"Registration No.", a code starting with digits followed by dashes (e.g. 012345-0001-000111)
- Batch / Lot number (often preceded by "B.No.", "Batch No.", "Lot")
- Expiry date (preceded by "Exp", "Exp.", "Expiry", "Best Before"; look for MM/YY, MM/YYYY, or month-year)
- Manufacturing date if visible
- Dosage form (Tablet, Capsule, Syrup, Suspension, Injection, Cream, Ointment, Drops, Inhaler, etc.)
- Strength / concentration (e.g. "500 mg", "250 mg/5 ml", "10%")
- Pack size / quantity (e.g. "10 Tablets", "60 ml", "30 Capsules", "1x10", "2x10")
- Storage conditions (e.g. "Store below 30C", "Keep refrigerated", "Protect from light")
- "Rx only" or prescription-only marking
- Any other regulatory text, warnings, or codes

## STAGE 2 -- Packaging Quality Assessment
Evaluate the physical quality of the packaging by examining:
- Hologram presence: Is there a visible holographic sticker or security seal? Describe it.
- Print quality: Is text sharp and crisp, or blurry / pixelated / smudged?
- Color consistency: Are colors uniform and vibrant, or faded / inconsistent?
- Font uniformity: Are fonts consistent throughout, or do some sections look like different typefaces?
- Print alignment: Is text straight and well-aligned, or tilted / misaligned?
- Foil / blister quality (if visible): Is foil smooth and cleanly sealed, or wrinkled / poorly cut?
- Overall professional appearance: Does this look like it was produced by a legitimate pharmaceutical manufacturer?

## STAGE 3 -- Language Detection
Identify all languages present on the label:
- English text
- Urdu text (Nastaliq script)
- Arabic text
- Any other languages
Note whether bilingual labeling is present (English + Urdu is standard for Pakistani medicines).

## STAGE 4 -- Suspicious Indicator Detection
Look carefully for any signs of counterfeit or substandard packaging:
- Spelling mistakes or grammatical errors in English or Urdu text
- Blurry, smudged, or low-resolution printing
- Misaligned text or graphics
- Unusual or inconsistent fonts (mixing serif / sans-serif inappropriately)
- Missing DRAP logo or registration number
- Missing manufacturer address or city
- Inconsistent color between different panels
- Poor quality hologram or missing security features
- Incomplete or missing batch number / expiry date
- Registration number format that does not match standard DRAP patterns
- Any signs of label tampering, overprinting, or sticker-over-sticker

## STAGE 5 -- Overall Label Quality Rating
Based on all observations, assign a label_quality_score from 1 to 10:
- 9-10: Excellent -- professional pharma packaging, all details present, sharp print, hologram intact
- 7-8: Good -- minor issues but clearly legitimate manufacturer
- 5-6: Fair -- some concerns, missing some details or moderate print quality issues
- 3-4: Poor -- multiple quality issues, several missing details, suspicious indicators
- 1-2: Very Poor -- strong counterfeit indicators, illegible text, major quality issues

## OUTPUT FORMAT
Return ONLY valid JSON (no markdown fences, no commentary before or after) with these exact keys:
{
  "brand_name": "...",
  "generic_name": "...",
  "registration_number": "...",
  "manufacturer": "...",
  "manufacturer_city": "...",
  "batch_number": "...",
  "expiry_date": "...",
  "manufacturing_date": "...",
  "dosage_form": "...",
  "strength": "...",
  "pack_size": "...",
  "storage_conditions": "...",
  "rx_only": true/false,
  "languages_detected": ["English", "Urdu"],
  "hologram_present": true/false/null,
  "print_quality": "sharp" | "acceptable" | "blurry" | "poor",
  "color_consistency": "consistent" | "minor_issues" | "inconsistent",
  "font_uniformity": "uniform" | "minor_variation" | "inconsistent",
  "print_alignment": "aligned" | "slightly_off" | "misaligned",
  "suspicious_indicators": ["list of any suspicious observations"],
  "label_quality_score": 7,
  "label_quality_reasoning": "Brief explanation of the quality score",
  "all_extracted_text": "Complete dump of every readable text string on the label"
}

If a field is not visible or legible, set it to null.
For boolean fields, use true/false or null if uncertain.
For the suspicious_indicators list, use an empty list [] if nothing suspicious is found.
"""


def _extract_label_data(client: anthropic.Anthropic, front_image_b64: str) -> dict:
    """Use Claude Vision to perform forensic-level label extraction."""

    if not front_image_b64 or not front_image_b64.strip():
        raise ValueError("Front image data is empty or missing")

    message = retry_api_call(lambda: client.messages.create(
        model=VISION_MODEL,
        max_tokens=MAX_TOKENS_REGISTRATION,
        messages=[
            {
                "role": "user",
                "content": [
                    {
                        "type": "image",
                        "source": {
                            "type": "base64",
                            "media_type": "image/jpeg",
                            "data": front_image_b64,
                        },
                    },
                    {"type": "text", "text": VISION_PROMPT},
                ],
            }
        ],
    ))

    if not message.content:
        raise ValueError("Claude Vision returned empty response for front label")

    raw = message.content[0].text.strip()
    # Strip markdown fences if present
    if raw.startswith("```"):
        raw = raw.split("\n", 1)[1]
        raw = raw.rsplit("```", 1)[0]
    return json.loads(raw)


# ---------------------------------------------------------------------------
# Supabase-backed DRAP search
# ---------------------------------------------------------------------------

def _normalize(text: Optional[str]) -> str:
    """Lowercase, strip, collapse whitespace."""
    if not text:
        return ""
    return re.sub(r"\s+", " ", text.strip().lower())


def _search_drap_supabase(extracted: dict) -> Optional[dict]:
    """
    Search the Supabase drap_medicines table using extracted label data.
    Tries registration number first, then brand name (ilike), then full-text
    search via the search_vector column.
    Returns the best matching DRAP record, or None.
    """
    sb = get_supabase()

    # --- 1. Try registration number (most specific) ---
    reg_num = extracted.get("registration_number")
    if reg_num:
        clean_reg = reg_num.replace(" ", "").replace("-", "").strip()
        try:
            resp = (
                sb.table("drap_medicines")
                .select("*")
                .ilike("registration_number", f"%{sanitize_like(clean_reg)}%")
                .limit(1)
                .execute()
            )
            if resp.data:
                return resp.data[0]
        except Exception as exc:
            logger.warning("Supabase reg search error: %s", exc)

        # Try with original format too
        try:
            resp = (
                sb.table("drap_medicines")
                .select("*")
                .eq("registration_number", reg_num.strip())
                .limit(1)
                .execute()
            )
            if resp.data:
                return resp.data[0]
        except Exception as exc:
            logger.warning("Supabase reg eq search error: %s", exc)

    # --- 2. Try brand name (ilike) ---
    brand = extracted.get("brand_name")
    if brand:
        try:
            resp = (
                sb.table("drap_medicines")
                .select("*")
                .ilike("brand_name", f"%{sanitize_like(brand.strip())}%")
                .limit(5)
                .execute()
            )
            if resp.data:
                # Prefer exact match
                brand_lower = brand.strip().lower()
                for r in resp.data:
                    if r.get("brand_name", "").strip().lower() == brand_lower:
                        return r
                return resp.data[0]
        except Exception as exc:
            logger.warning("Supabase brand search error: %s", exc)

    # --- 3. Full-text search using search_vector column ---
    generic = extracted.get("generic_name")
    search_term = brand or generic
    if search_term:
        try:
            # Use Postgres full-text search via textSearch
            resp = (
                sb.table("drap_medicines")
                .select("*")
                .text_search("search_vector", f"'{search_term.strip()}'")
                .limit(5)
                .execute()
            )
            if resp.data:
                return resp.data[0]
        except Exception as exc:
            logger.warning("Supabase FTS search error: %s", exc)

    # --- 4. Fallback: ilike on generic_name ---
    if generic:
        try:
            resp = (
                sb.table("drap_medicines")
                .select("*")
                .ilike("generic_name", f"%{sanitize_like(generic.strip())}%")
                .limit(3)
                .execute()
            )
            if resp.data:
                return resp.data[0]
        except Exception as exc:
            logger.warning("Supabase generic search error: %s", exc)

    return None


def _fetch_generic_drug_data(generic_name: str) -> Optional[dict]:
    """
    Fetch clinical data for a generic drug from the generic_drugs table.
    """
    if not generic_name:
        return None
    sb = get_supabase()
    try:
        resp = (
            sb.table("generic_drugs")
            .select("*")
            .ilike("name", f"%{sanitize_like(generic_name.strip())}%")
            .limit(1)
            .execute()
        )
        if resp.data:
            return resp.data[0]
    except Exception as exc:
        logger.warning("Supabase generic_drugs lookup error: %s", exc)
    return None


def _fetch_manufacturer_info(manufacturer_name: str) -> Optional[dict]:
    """
    Fetch manufacturer details from the manufacturers table.
    """
    if not manufacturer_name:
        return None
    sb = get_supabase()
    try:
        resp = (
            sb.table("manufacturers")
            .select("*")
            .ilike("name", f"%{sanitize_like(manufacturer_name.strip())}%")
            .limit(1)
            .execute()
        )
        if resp.data:
            return resp.data[0]
    except Exception as exc:
        logger.warning("Supabase manufacturer lookup error: %s", exc)
    return None


# ---------------------------------------------------------------------------
# Cross-reference and confidence scoring
# ---------------------------------------------------------------------------

def _parse_expiry_date(expiry_str: Optional[str]) -> Optional[date]:
    """Attempt to parse expiry date from various formats."""
    if not expiry_str:
        return None
    # Common formats: MM/YY, MM/YYYY, MM-YY, MM-YYYY, Month YYYY, YYYY-MM
    formats = [
        "%m/%y", "%m/%Y", "%m-%y", "%m-%Y",
        "%B %Y", "%b %Y", "%Y-%m", "%Y-%m-%d",
        "%d/%m/%Y", "%d-%m-%Y",
    ]
    clean = expiry_str.strip()
    for fmt in formats:
        try:
            return datetime.strptime(clean, fmt).date()
        except ValueError:
            continue
    return None


def _field_match_score(extracted_val: Optional[str], drap_val: Optional[str]) -> float:
    """
    Compare two field values and return a match score between 0.0 and 1.0.
    0.0 = no match or missing data, 0.5 = partial match, 1.0 = exact match.
    """
    if not extracted_val or not drap_val:
        return 0.0  # cannot compare

    ext = _normalize(extracted_val)
    drap = _normalize(drap_val)

    if not ext or not drap:
        return 0.0

    # Exact match
    if ext == drap:
        return 1.0

    # One contains the other (substring match)
    if ext in drap or drap in ext:
        return 0.85

    # Token overlap
    ext_tokens = set(ext.split())
    drap_tokens = set(drap.split())
    if ext_tokens and drap_tokens:
        overlap = len(ext_tokens & drap_tokens)
        total = max(len(ext_tokens), len(drap_tokens))
        if total > 0:
            ratio = overlap / total
            if ratio >= 0.5:
                return 0.5 + (ratio * 0.35)

    return 0.0


def _check_drap_database(extracted: dict, drap_data: Optional[dict]) -> dict:
    """
    Cross-reference extracted data against the DRAP database record.
    Returns detailed verification with field-by-field match scores,
    overall confidence, and pass/fail determination.
    """
    if drap_data is None:
        return {
            "verified": False,
            "partial_match": False,
            "reason": "No matching record found in DRAP database",
            "match_details": {},
            "field_scores": {},
            "overall_match_score": 0.0,
            "drap_record": None,
        }

    field_scores: dict[str, float] = {}
    match_details: dict[str, bool] = {}
    mismatches: list[str] = []
    fields_checked = 0

    # --- Registration Number ---
    if extracted.get("registration_number") and drap_data.get("registration_number"):
        fields_checked += 1
        ext_reg = re.sub(r"[\s\-]", "", extracted["registration_number"]).upper()
        drap_reg = re.sub(r"[\s\-]", "", drap_data["registration_number"]).upper()
        if ext_reg == drap_reg:
            field_scores["registration_number"] = 1.0
            match_details["registration_number"] = True
        elif ext_reg in drap_reg or drap_reg in ext_reg:
            field_scores["registration_number"] = 0.7
            match_details["registration_number"] = True
        else:
            field_scores["registration_number"] = 0.0
            match_details["registration_number"] = False
            mismatches.append("registration_number")

    # --- Brand Name ---
    score = _field_match_score(extracted.get("brand_name"), drap_data.get("brand_name"))
    if extracted.get("brand_name") and drap_data.get("brand_name"):
        fields_checked += 1
        field_scores["brand_name"] = score
        match_details["brand_name"] = score >= 0.5
        if score < 0.5:
            mismatches.append("brand_name")

    # --- Generic Name ---
    score = _field_match_score(extracted.get("generic_name"), drap_data.get("generic_name"))
    if extracted.get("generic_name") and drap_data.get("generic_name"):
        fields_checked += 1
        field_scores["generic_name"] = score
        match_details["generic_name"] = score >= 0.5
        if score < 0.5:
            mismatches.append("generic_name")

    # --- Manufacturer ---
    score = _field_match_score(extracted.get("manufacturer"), drap_data.get("manufacturer"))
    if extracted.get("manufacturer") and drap_data.get("manufacturer"):
        fields_checked += 1
        field_scores["manufacturer"] = score
        match_details["manufacturer"] = score >= 0.5
        if score < 0.5:
            mismatches.append("manufacturer")

    # --- Strength ---
    if extracted.get("strength") and drap_data.get("strength"):
        fields_checked += 1
        ext_str = re.sub(r"\s+", "", extracted["strength"].lower())
        drap_str = re.sub(r"\s+", "", drap_data["strength"].lower())
        if ext_str == drap_str:
            field_scores["strength"] = 1.0
            match_details["strength"] = True
        elif ext_str in drap_str or drap_str in ext_str:
            field_scores["strength"] = 0.7
            match_details["strength"] = True
        else:
            # Try extracting numeric values
            ext_nums = re.findall(r"[\d.]+", ext_str)
            drap_nums = re.findall(r"[\d.]+", drap_str)
            if ext_nums and drap_nums and ext_nums[0] == drap_nums[0]:
                field_scores["strength"] = 0.8
                match_details["strength"] = True
            else:
                field_scores["strength"] = 0.0
                match_details["strength"] = False
                mismatches.append("strength")

    # --- Dosage Form ---
    score = _field_match_score(extracted.get("dosage_form"), drap_data.get("dosage_form"))
    if extracted.get("dosage_form") and drap_data.get("dosage_form"):
        fields_checked += 1
        field_scores["dosage_form"] = score
        match_details["dosage_form"] = score >= 0.5
        if score < 0.5:
            mismatches.append("dosage_form")

    # --- Pack Size ---
    score = _field_match_score(extracted.get("pack_size"), drap_data.get("pack_size"))
    if extracted.get("pack_size") and drap_data.get("pack_size"):
        fields_checked += 1
        field_scores["pack_size"] = score
        match_details["pack_size"] = score >= 0.5
        if score < 0.5:
            mismatches.append("pack_size")

    # --- Expiry Date Validity ---
    expiry_str = extracted.get("expiry_date")
    expiry_date = _parse_expiry_date(expiry_str)
    expiry_valid = None
    if expiry_date:
        today = date.today()
        if expiry_date < today:
            expiry_valid = False
            field_scores["expiry_valid"] = 0.0
            mismatches.append("expiry_date (EXPIRED)")
        else:
            expiry_valid = True
            field_scores["expiry_valid"] = 1.0
        fields_checked += 1

    # --- Check Registration Expiry (if DRAP record has date fields) ---
    registration_expired = False
    drap_expiry = drap_data.get("registration_expiry") or drap_data.get("expiry_date")
    if drap_expiry:
        reg_exp_date = _parse_expiry_date(str(drap_expiry))
        if reg_exp_date and reg_exp_date < date.today():
            registration_expired = True
            mismatches.append("registration_expired")

    # --- Label Quality Score ---
    label_quality = extracted.get("label_quality_score")
    if label_quality is not None:
        try:
            lq = float(label_quality)
            field_scores["label_quality"] = lq / 10.0
        except (ValueError, TypeError):
            field_scores["label_quality"] = 0.5

    # --- Suspicious Indicators Penalty ---
    suspicious = extracted.get("suspicious_indicators", [])
    suspicious_penalty = min(len(suspicious) * 0.05, 0.25)  # max 25% penalty

    # --- Manufacturer Authorization ---
    # Note: manufacturers table may not exist in all deployments; this
    # lookup is a best-effort enhancement that degrades gracefully.
    manufacturer_authorized = None
    mfr_name = extracted.get("manufacturer")
    if mfr_name:
        manufacturer_info = _fetch_manufacturer_info(mfr_name)
        if manufacturer_info:
            manufacturer_authorized = manufacturer_info.get("authorized", True)
            if manufacturer_authorized is False:
                mismatches.append("manufacturer_not_authorized")

    # --- Compute overall weighted confidence ---
    if fields_checked == 0:
        return {
            "verified": False,
            "partial_match": False,
            "reason": "Insufficient data for cross-reference",
            "match_details": match_details,
            "field_scores": field_scores,
            "overall_match_score": 0.0,
            "drap_record": drap_data,
        }

    weighted_score = 0.0
    weight_sum = 0.0
    for field, weight in FIELD_WEIGHTS.items():
        if field in field_scores:
            weighted_score += field_scores[field] * weight
            weight_sum += weight

    # Normalize to the fields we actually compared
    if weight_sum > 0:
        overall_score = weighted_score / weight_sum
    else:
        overall_score = 0.0

    # Apply suspicious indicators penalty
    overall_score = max(0.0, overall_score - suspicious_penalty)

    # Apply registration expiry penalty
    if registration_expired:
        overall_score = max(0.0, overall_score - 0.15)

    # Apply manufacturer authorization penalty
    if manufacturer_authorized is False:
        overall_score = max(0.0, overall_score - 0.20)

    # Determine verification status
    critical_mismatches = [
        m for m in mismatches
        if m in ("registration_number", "brand_name", "manufacturer")
    ]
    verified = (
        overall_score >= 0.75
        and len(critical_mismatches) == 0
        and not registration_expired
    )
    partial_match = (
        not verified
        and overall_score >= 0.45
        and len(critical_mismatches) <= 1
    )

    reason_parts = []
    if mismatches:
        reason_parts.append(f"Mismatches in: {', '.join(mismatches)}")
    if registration_expired:
        reason_parts.append("DRAP registration appears expired")
    if manufacturer_authorized is False:
        reason_parts.append("Manufacturer not found in authorized list")
    if suspicious:
        reason_parts.append(
            f"Suspicious indicators detected: {'; '.join(suspicious[:3])}"
        )
    reason = ". ".join(reason_parts) if reason_parts else ""

    return {
        "verified": verified,
        "partial_match": partial_match,
        "reason": reason,
        "match_details": match_details,
        "field_scores": field_scores,
        "overall_match_score": round(overall_score, 3),
        "fields_checked": fields_checked,
        "registration_expired": registration_expired,
        "manufacturer_authorized": manufacturer_authorized,
        "expiry_valid": expiry_valid,
        "suspicious_indicators": suspicious,
        "suspicious_penalty": round(suspicious_penalty, 3),
        "drap_record": drap_data,
    }


# ---------------------------------------------------------------------------
# Main entry point
# ---------------------------------------------------------------------------

def check_registration(front_image_b64: str, drap_data: Optional[dict] = None) -> dict:
    """
    Main entry point for Agent 1.

    Args:
        front_image_b64: Base64-encoded front label image.
        drap_data: Optional dict with DRAP database record for cross-reference.

    Returns:
        Standardized agent result dict.
    """
    result: dict = {
        "agent_number": AGENT_NUMBER,
        "agent_name": AGENT_NAME,
        "status": "UNCERTAIN",
        "confidence_score": 0.0,
        "extracted_data": {
            "brand_name": None,
            "generic_name": None,
            "registration_number": None,
            "manufacturer": None,
            "manufacturer_city": None,
            "batch_number": None,
            "expiry_date": None,
            "manufacturing_date": None,
            "dosage_form": None,
            "strength": None,
            "pack_size": None,
            "storage_conditions": None,
            "rx_only": None,
            "languages_detected": None,
            "hologram_present": None,
            "print_quality": None,
            "label_quality_score": None,
            "suspicious_indicators": [],
        },
        "verification_details": {},
        "generic_drug_data": None,
        "display_message": "",
        "fail_reason": None,
    }

    try:
        client = _get_client()

        # ----- Step 1: Forensic label extraction via Claude Vision -----
        extracted = _extract_label_data(client, front_image_b64)
        result["extracted_data"].update(
            {k: v for k, v in extracted.items() if k in result["extracted_data"]}
        )

        # ----- Step 2: Fetch generic drug clinical data -----
        generic_name = extracted.get("generic_name")
        if generic_name:
            generic_data = _fetch_generic_drug_data(generic_name)
            if generic_data:
                result["generic_drug_data"] = generic_data

        # ----- Step 3: Search DRAP in Supabase if not provided -----
        if drap_data is None:
            drap_data = _search_drap_supabase(extracted)
            logger.info(
                "Supabase DRAP search for '%s' (reg: %s): %s",
                extracted.get("brand_name", "?"),
                extracted.get("registration_number", "?"),
                "found" if drap_data else "not found",
            )

        # ----- Step 4: Cross-reference with DRAP -----
        verification = _check_drap_database(extracted, drap_data)
        result["verification_details"] = verification

        # ----- Step 5: Determine final status and confidence -----
        label_quality = extracted.get("label_quality_score")
        label_quality_norm = 0.5  # default
        if label_quality is not None:
            try:
                label_quality_norm = float(label_quality) / 10.0
            except (ValueError, TypeError):
                pass

        suspicious_count = len(extracted.get("suspicious_indicators", []))
        overall_match = verification.get("overall_match_score", 0.0)

        if verification["verified"]:
            # Confidence is weighted: 70% match score + 20% label quality + 10% base
            confidence = 0.10 + (overall_match * 0.70) + (label_quality_norm * 0.20)
            confidence = min(0.99, confidence)

            result["status"] = "PASS"
            result["confidence_score"] = round(confidence, 2)

            brand = extracted.get("brand_name", "N/A")
            reg = extracted.get("registration_number", "N/A")
            match_pct = round(overall_match * 100)
            result["display_message"] = (
                f"Medicine '{brand}' is verified in the DRAP database. "
                f"Registration number {reg} matched with {match_pct}% field accuracy. "
                f"Label quality score: {label_quality or 'N/A'}/10."
            )

        elif verification.get("partial_match"):
            confidence = 0.05 + (overall_match * 0.65) + (label_quality_norm * 0.15)
            confidence = max(0.30, min(0.74, confidence))

            result["status"] = "UNCERTAIN"
            result["confidence_score"] = round(confidence, 2)

            reason = verification.get("reason", "")
            result["display_message"] = (
                f"Partial match found in DRAP database (score: {round(overall_match * 100)}%). "
                f"{reason}. "
                "Some details match but discrepancies were detected. Manual verification recommended."
            )
            if suspicious_count > 0:
                result["display_message"] += (
                    f" Warning: {suspicious_count} suspicious indicator(s) detected on label."
                )

        elif verification.get("drap_record") is not None and verification.get("reason"):
            # DRAP record was found but has mismatches / expired / suspicious -> FAIL
            confidence = 0.05 + (0.85 * (1.0 - overall_match))
            confidence = max(0.60, min(0.95, confidence))

            result["status"] = "FAIL"
            result["confidence_score"] = round(confidence, 2)
            result["fail_reason"] = verification["reason"]

            result["display_message"] = (
                f"Registration verification FAILED. {verification['reason']}. "
                "This medicine could not be verified and may be counterfeit or unregistered."
            )
            if suspicious_count > 0:
                result["display_message"] += (
                    f" Additionally, {suspicious_count} suspicious packaging indicator(s) detected."
                )

        else:
            # No DRAP record found at all
            confidence = 0.15 + (label_quality_norm * 0.20)
            if suspicious_count > 0:
                confidence = max(0.10, confidence - suspicious_count * 0.05)
            confidence = min(0.50, confidence)

            result["status"] = "UNCERTAIN"
            result["confidence_score"] = round(confidence, 2)
            result["display_message"] = (
                "Could not find this medicine in the DRAP database. "
                "This does not necessarily mean it is counterfeit -- it may be a newer registration "
                "or the database may not include this product yet. "
                "Manual verification with DRAP is recommended."
            )
            if suspicious_count > 0:
                result["display_message"] += (
                    f" Note: {suspicious_count} suspicious indicator(s) found on the label."
                )

    except ValueError as exc:
        logger.warning("Agent 1 input/response error: %s", exc)
        result["status"] = "UNCERTAIN"
        result["confidence_score"] = 0.0
        result["fail_reason"] = f"Input error: {exc}"
        result["display_message"] = (
            "Could not process the front label image. Please ensure the image is "
            "properly captured, well-lit, and try again."
        )
    except json.JSONDecodeError as exc:
        result["status"] = "UNCERTAIN"
        result["confidence_score"] = 0.15
        result["fail_reason"] = f"Failed to parse label data: {exc}"
        result["display_message"] = (
            "Could not read the label clearly. Please ensure the image is well-lit, "
            "in focus, and shows the front label fully. Retake the photo and try again."
        )
    except anthropic.APIError as exc:
        result["status"] = "UNCERTAIN"
        result["confidence_score"] = 0.0
        result["fail_reason"] = f"API error: {exc}"
        result["display_message"] = "Service temporarily unavailable. Please try again."
    except Exception as exc:  # noqa: BLE001
        logger.exception("Agent 1 unexpected error")
        result["status"] = "UNCERTAIN"
        result["confidence_score"] = 0.0
        result["fail_reason"] = f"Unexpected error: {exc}"
        result["display_message"] = "An unexpected error occurred during registration check."

    return result
