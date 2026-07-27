"""
Agent 5 — ADIL (The Just One)

Verifies medicine pricing against DRAP-registered MRP using Supabase,
finds generic alternatives with savings calculations from the
medicine_prices table, and fetches international alternatives via RxNorm.

Pakistan pricing context:
  - DRAP (Drug Regulatory Authority of Pakistan) controls maximum retail prices.
  - Pharmacies cannot legally charge above MRP.
  - Generic alternatives are typically 30-70% cheaper than branded equivalents.
  - Very cheap medicines (>30% below DRAP MRP) may be counterfeit.
"""

import asyncio
import logging
from typing import Optional

from utils.supabase_client import get_supabase, sanitize_like
from data.api_clients import rxnorm_client

logger = logging.getLogger(__name__)

AGENT_NUMBER = 5
AGENT_NAME = "ADIL — The Just One"

# --- Thresholds ---
OVERPRICED_THRESHOLD = 0.10   # >10% above DRAP MRP
SUSPICIOUS_THRESHOLD = 0.30   # >30% below DRAP MRP (possible counterfeit)


# ---------------------------------------------------------------------------
# Async helper
# ---------------------------------------------------------------------------

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


# ---------------------------------------------------------------------------
# Supabase price queries
# ---------------------------------------------------------------------------

def _query_medicine_prices(medicine_name: str, pack_size: Optional[str] = None) -> Optional[dict]:
    """
    Look up medicine in the medicine_prices table.
    Returns the best-matching row or None.
    """
    try:
        sb = get_supabase()
        query = (
            sb.table("medicine_prices")
            .select("*")
            .ilike("brand_name", f"%{sanitize_like(medicine_name)}%")
        )
        if pack_size:
            query = query.ilike("pack_size", f"%{sanitize_like(pack_size)}%")

        resp = query.execute()
        rows = resp.data or []
        if not rows:
            return None

        # Prefer exact (case-insensitive) match over partial
        for row in rows:
            if row.get("brand_name", "").lower() == medicine_name.lower():
                return row
        return rows[0]
    except Exception as exc:
        logger.warning("medicine_prices query failed for '%s': %s", medicine_name, exc)
        return None


def _query_drap_mrp(medicine_name: str, pack_size: Optional[str] = None) -> Optional[dict]:
    """
    Look up official DRAP-registered MRP from drap_medicines table.
    Returns the best-matching row or None.
    """
    try:
        sb = get_supabase()
        query = (
            sb.table("drap_medicines")
            .select("brand_name, generic_name, manufacturer, mrp, strength, pack_size, registration_number, status")
            .ilike("brand_name", f"%{sanitize_like(medicine_name)}%")
            .eq("status", "Active")
        )
        if pack_size:
            query = query.ilike("pack_size", f"%{sanitize_like(pack_size)}%")

        resp = query.execute()
        rows = resp.data or []
        if not rows:
            return None

        # Prefer exact match
        for row in rows:
            if row.get("brand_name", "").lower() == medicine_name.lower():
                return row
        return rows[0]
    except Exception as exc:
        logger.warning("drap_medicines query failed for '%s': %s", medicine_name, exc)
        return None


def _query_generic_alternatives(generic_name: str, exclude_brand: str = "") -> list[dict]:
    """
    Find alternative medicines with the same generic_name from
    medicine_prices table, sorted by price (cheapest first).
    Returns up to 5 alternatives.
    """
    if not generic_name:
        return []
    try:
        sb = get_supabase()
        resp = (
            sb.table("medicine_prices")
            .select("brand_name, generic_name, manufacturer, strength, pack_size, mrp")
            .ilike("generic_name", f"%{sanitize_like(generic_name)}%")
            .order("mrp", desc=False)
            .limit(20)
            .execute()
        )
        rows = resp.data or []
        # Filter out the original brand and rows without price
        alternatives = []
        for row in rows:
            if exclude_brand and row.get("brand_name", "").lower() == exclude_brand.lower():
                continue
            if row.get("mrp") is None or row["mrp"] <= 0:
                continue
            alternatives.append(row)
        return alternatives[:5]
    except Exception as exc:
        logger.warning("Generic alternatives query failed for '%s': %s", generic_name, exc)
        return []


def _check_price_records_for_trends(medicine_name: str) -> Optional[dict]:
    """
    Check if multiple price records exist for the same medicine,
    which could indicate a price change / trend.
    """
    try:
        sb = get_supabase()
        resp = (
            sb.table("medicine_prices")
            .select("brand_name, mrp, strength, pack_size")
            .ilike("brand_name", f"%{sanitize_like(medicine_name)}%")
            .order("mrp", desc=True)
            .execute()
        )
        rows = resp.data or []
        if len(rows) < 2:
            return None

        prices = [r["mrp"] for r in rows if r.get("mrp")]
        if len(prices) < 2:
            return None

        highest = max(prices)
        lowest = min(prices)
        if lowest > 0:
            variation_pct = ((highest - lowest) / lowest) * 100
        else:
            variation_pct = 0.0

        return {
            "record_count": len(rows),
            "highest_mrp": highest,
            "lowest_mrp": lowest,
            "variation_pct": round(variation_pct, 1),
        }
    except Exception as exc:
        logger.warning("Price trend query failed for '%s': %s", medicine_name, exc)
        return None


# ---------------------------------------------------------------------------
# RxNorm international alternatives
# ---------------------------------------------------------------------------

def _fetch_rxnorm_alternatives(medicine_name: str) -> list[dict]:
    """Fetch generic alternatives from RxNorm API with fallback."""
    try:
        result = _run_async_safely(rxnorm_client.get_generic_alternatives(medicine_name))
        return result if result else []
    except Exception as exc:
        logger.warning("RxNorm alternatives fetch failed: %s", exc)
        return []


# ---------------------------------------------------------------------------
# Price analysis helpers
# ---------------------------------------------------------------------------

def _analyse_price_vs_drap(label_mrp: float, drap_mrp: float) -> dict:
    """
    Compare a label/scanned MRP against the DRAP-registered MRP.

    Returns a dict with:
      - pct_diff: signed percentage difference (positive = above DRAP)
      - is_overpriced: True if >10% above DRAP MRP
      - is_suspicious: True if >30% below DRAP MRP (counterfeit risk)
      - flag: human-readable flag string or None
    """
    # Guard against non-numeric or invalid inputs
    try:
        label_mrp = float(label_mrp)
        drap_mrp = float(drap_mrp)
    except (TypeError, ValueError):
        return {
            "pct_diff": 0.0,
            "is_overpriced": False,
            "is_suspicious": False,
            "flag": None,
        }

    if drap_mrp <= 0:
        return {
            "pct_diff": 0.0,
            "is_overpriced": False,
            "is_suspicious": False,
            "flag": None,
        }

    pct_diff = (label_mrp - drap_mrp) / drap_mrp
    is_overpriced = pct_diff > OVERPRICED_THRESHOLD
    is_suspicious = pct_diff < -SUSPICIOUS_THRESHOLD

    flag = None
    if is_overpriced:
        flag = (
            f"OVERPRICED: Label MRP Rs. {label_mrp:.0f} is {pct_diff:.0%} above "
            f"DRAP-registered MRP Rs. {drap_mrp:.0f}. Pharmacies cannot legally "
            "charge above DRAP MRP in Pakistan."
        )
    elif is_suspicious:
        flag = (
            f"SUSPICIOUS PRICE: Label MRP Rs. {label_mrp:.0f} is {abs(pct_diff):.0%} below "
            f"DRAP-registered MRP Rs. {drap_mrp:.0f}. Unusually cheap medicines in "
            "Pakistan can be a sign of counterfeit or substandard product."
        )

    return {
        "pct_diff": round(pct_diff * 100, 1),
        "is_overpriced": is_overpriced,
        "is_suspicious": is_suspicious,
        "flag": flag,
    }


def _compute_alternatives_with_savings(
    alternatives: list[dict], brand_mrp: float
) -> list[dict]:
    """
    Enrich each alternative with savings information relative to the
    brand's MRP.

    Returns a list sorted by price (cheapest first) with:
      - savings_amount: absolute Rs. saved
      - savings_pct: percentage saved
    """
    enriched = []
    for alt in alternatives:
        alt_mrp = alt.get("mrp")
        if alt_mrp is None or alt_mrp <= 0:
            continue
        savings_amount = brand_mrp - alt_mrp
        savings_pct = (savings_amount / brand_mrp * 100) if brand_mrp > 0 else 0.0
        enriched.append({
            "brand_name": alt.get("brand_name", "Unknown"),
            "generic_name": alt.get("generic_name", ""),
            "manufacturer": alt.get("manufacturer", "Unknown"),
            "strength": alt.get("strength", ""),
            "pack_size": alt.get("pack_size", ""),
            "mrp": alt_mrp,
            "savings_amount": round(savings_amount, 2),
            "savings_pct": round(savings_pct, 1),
        })

    enriched.sort(key=lambda x: x["mrp"])
    return enriched[:5]


# ---------------------------------------------------------------------------
# Main entry point
# ---------------------------------------------------------------------------

def verify_price(
    medicine_name: str,
    pack_size: Optional[str] = None,
    label_mrp: Optional[float] = None,
) -> dict:
    """
    Main entry point for Agent 5 - Price / MRP Verification.

    Args:
        medicine_name: Medicine brand name (as scanned or entered).
        pack_size: Pack size string (e.g. "10 tablets").
        label_mrp: MRP printed on the label (if extracted by another agent).

    Returns:
        Standardized agent result dict with price verification details.
    """
    result: dict = {
        "agent_number": AGENT_NUMBER,
        "agent_name": AGENT_NAME,
        "status": "UNCERTAIN",
        "confidence_score": 0.0,
        # Price fields
        "label_mrp": label_mrp,
        "drap_registered_mrp": None,
        "price_source": None,
        # Discrepancy analysis
        "price_discrepancy": False,
        "price_pct_diff": None,
        "is_overpriced": False,
        "is_suspicious_cheap": False,
        "price_flag": None,
        # Alternatives
        "generic_alternatives": [],
        "rxnorm_alternatives": [],
        "potential_savings": None,
        # Trends
        "price_trend": None,
        # Pakistan context
        "pakistan_pricing_notes": [
            "DRAP controls maximum retail prices for all registered medicines.",
            "Pharmacies cannot legally charge above the DRAP-registered MRP.",
            "Generic alternatives are typically 30-70% cheaper than branded equivalents.",
            "Unusually cheap medicines may indicate counterfeit or substandard products.",
        ],
        # Display
        "display_message": "",
        "fail_reason": None,
    }

    try:
        # Coerce label_mrp to float if provided as string from OCR/upstream
        if label_mrp is not None:
            try:
                label_mrp = float(label_mrp)
                result["label_mrp"] = label_mrp
                if label_mrp <= 0:
                    label_mrp = None
                    result["label_mrp"] = None
            except (TypeError, ValueError):
                logger.warning("Invalid label_mrp value: %s", label_mrp)
                label_mrp = None
                result["label_mrp"] = None

        # -----------------------------------------------------------------
        # Step 1: Look up DRAP-registered MRP (official price ceiling)
        # -----------------------------------------------------------------
        drap_record = _query_drap_mrp(medicine_name, pack_size)
        price_record = _query_medicine_prices(medicine_name, pack_size)

        # Determine the verified (DRAP) MRP
        drap_mrp = None
        generic_name = None
        brand_pack_size = pack_size

        if drap_record:
            raw_mrp = drap_record.get("mrp")
            # Only accept positive numeric MRP values
            try:
                drap_mrp = float(raw_mrp) if raw_mrp is not None else None
                if drap_mrp is not None and drap_mrp <= 0:
                    drap_mrp = None
            except (TypeError, ValueError):
                drap_mrp = None
            generic_name = drap_record.get("generic_name")
            brand_pack_size = drap_record.get("pack_size") or pack_size
            result["drap_registered_mrp"] = drap_mrp
            result["price_source"] = "DRAP Registry"

        if price_record:
            if drap_mrp is None:
                raw_mrp = price_record.get("mrp")
                try:
                    drap_mrp = float(raw_mrp) if raw_mrp is not None else None
                    if drap_mrp is not None and drap_mrp <= 0:
                        drap_mrp = None
                except (TypeError, ValueError):
                    drap_mrp = None
                result["drap_registered_mrp"] = drap_mrp
                result["price_source"] = "DawaaCheck Price Database"
            if not generic_name:
                generic_name = price_record.get("generic_name")
            if not brand_pack_size:
                brand_pack_size = price_record.get("pack_size")

        # If no price data at all, return UNCERTAIN
        if drap_mrp is None and price_record is None and drap_record is None:
            result["status"] = "UNCERTAIN"
            result["confidence_score"] = 0.30
            result["display_message"] = (
                f"Price data not available for '{medicine_name}'. "
                "Cannot verify MRP at this time."
            )
            # Still try RxNorm for international alternatives
            rxnorm_alts = _fetch_rxnorm_alternatives(medicine_name)
            if rxnorm_alts:
                result["rxnorm_alternatives"] = rxnorm_alts
                result["display_message"] += (
                    f" {len(rxnorm_alts)} international alternative(s) found via RxNorm."
                )
            return result

        # -----------------------------------------------------------------
        # Step 2: Compare label MRP against DRAP MRP
        # -----------------------------------------------------------------
        if label_mrp is not None and drap_mrp is not None and drap_mrp > 0:
            analysis = _analyse_price_vs_drap(label_mrp, drap_mrp)
            result["price_pct_diff"] = analysis["pct_diff"]
            result["is_overpriced"] = analysis["is_overpriced"]
            result["is_suspicious_cheap"] = analysis["is_suspicious"]
            result["price_flag"] = analysis["flag"]

            if analysis["is_overpriced"]:
                result["price_discrepancy"] = True
                result["status"] = "FAIL"
                result["confidence_score"] = 0.85
                result["fail_reason"] = analysis["flag"]
                result["display_message"] = (
                    f"OVERPRICED: Label MRP Rs. {label_mrp:.0f} is "
                    f"{analysis['pct_diff']:.1f}% above DRAP-registered MRP "
                    f"Rs. {drap_mrp:.0f} for {brand_pack_size or medicine_name}. "
                    "This exceeds the legal maximum retail price set by DRAP."
                )
            elif analysis["is_suspicious"]:
                result["price_discrepancy"] = True
                result["status"] = "FAIL"
                result["confidence_score"] = 0.75
                result["fail_reason"] = analysis["flag"]
                result["display_message"] = (
                    f"SUSPICIOUS: Label MRP Rs. {label_mrp:.0f} is "
                    f"{abs(analysis['pct_diff']):.1f}% below DRAP-registered MRP "
                    f"Rs. {drap_mrp:.0f} for {brand_pack_size or medicine_name}. "
                    "Very cheap medicines in Pakistan can indicate counterfeit "
                    "or substandard product. Exercise caution."
                )
            else:
                result["status"] = "PASS"
                result["confidence_score"] = 0.92
                result["display_message"] = (
                    f"Price verified. Label MRP Rs. {label_mrp:.0f} is within "
                    f"acceptable range of DRAP-registered MRP Rs. {drap_mrp:.0f} "
                    f"for {brand_pack_size or medicine_name}."
                )
        elif drap_mrp is not None:
            # No label MRP to compare — just report the verified price
            result["status"] = "PASS"
            result["confidence_score"] = 0.70
            result["display_message"] = (
                f"DRAP-registered MRP: Rs. {drap_mrp:.0f} for "
                f"{brand_pack_size or medicine_name}. "
                "No label MRP was provided for comparison."
            )
        else:
            result["status"] = "UNCERTAIN"
            result["confidence_score"] = 0.40
            result["display_message"] = (
                f"Medicine '{medicine_name}' found in database but MRP "
                "is not recorded. Cannot verify price."
            )

        # -----------------------------------------------------------------
        # Step 3: Generic alternatives with savings
        # -----------------------------------------------------------------
        reference_mrp = drap_mrp or 0.0

        # First: check embedded generic_alternatives in medicine_prices
        embedded_alts = []
        if price_record and price_record.get("generic_alternatives"):
            raw_alts = price_record["generic_alternatives"]
            if isinstance(raw_alts, list):
                embedded_alts = raw_alts

        # Second: query medicine_prices for same generic_name
        db_alternatives = _query_generic_alternatives(
            generic_name or "", exclude_brand=medicine_name
        )

        # Merge: DB alternatives take priority, then embedded ones
        all_local_alts = db_alternatives[:]
        seen_brands = {a.get("brand_name", "").lower() for a in all_local_alts}
        for ea in embedded_alts:
            name = ea.get("brand_name", ea.get("name", "")).lower()
            if name and name not in seen_brands:
                all_local_alts.append(ea)
                seen_brands.add(name)

        if all_local_alts and reference_mrp > 0:
            enriched_alts = _compute_alternatives_with_savings(all_local_alts, reference_mrp)
            result["generic_alternatives"] = enriched_alts

            # Potential savings summary
            if enriched_alts:
                cheapest = enriched_alts[0]
                if cheapest["savings_amount"] > 0:
                    result["potential_savings"] = {
                        "cheapest_alternative": cheapest["brand_name"],
                        "cheapest_mrp": cheapest["mrp"],
                        "savings_amount": cheapest["savings_amount"],
                        "savings_pct": cheapest["savings_pct"],
                        "manufacturer": cheapest["manufacturer"],
                    }
                    result["display_message"] += (
                        f" Cheaper alternative: {cheapest['brand_name']} by "
                        f"{cheapest['manufacturer']} at Rs. {cheapest['mrp']:.0f} "
                        f"(save Rs. {cheapest['savings_amount']:.0f}, "
                        f"{cheapest['savings_pct']:.0f}% less)."
                    )
        elif all_local_alts:
            # No reference MRP for savings calc, still list alternatives
            result["generic_alternatives"] = [
                {
                    "brand_name": a.get("brand_name", a.get("name", "Unknown")),
                    "generic_name": a.get("generic_name", ""),
                    "manufacturer": a.get("manufacturer", "Unknown"),
                    "strength": a.get("strength", ""),
                    "pack_size": a.get("pack_size", ""),
                    "mrp": a.get("mrp"),
                    "savings_amount": None,
                    "savings_pct": None,
                }
                for a in all_local_alts[:5]
            ]

        # -----------------------------------------------------------------
        # Step 4: RxNorm international alternatives
        # -----------------------------------------------------------------
        rxnorm_alts = _fetch_rxnorm_alternatives(medicine_name)
        if rxnorm_alts:
            result["rxnorm_alternatives"] = rxnorm_alts
            result["display_message"] += (
                f" {len(rxnorm_alts)} international generic alternative(s) "
                "found via RxNorm."
            )

        # -----------------------------------------------------------------
        # Step 5: Price trend awareness
        # -----------------------------------------------------------------
        trend = _check_price_records_for_trends(medicine_name)
        if trend and trend["record_count"] >= 2:
            result["price_trend"] = trend
            if trend["variation_pct"] > 15:
                result["display_message"] += (
                    f" Note: {trend['record_count']} price records found with "
                    f"{trend['variation_pct']}% price variation (Rs. {trend['lowest_mrp']:.0f}"
                    f" - Rs. {trend['highest_mrp']:.0f}). This may indicate "
                    "recent price changes or different pack sizes."
                )

    except Exception as exc:  # noqa: BLE001
        logger.exception("Error during price verification for '%s'", medicine_name)
        result["status"] = "UNCERTAIN"
        result["confidence_score"] = 0.0
        result["fail_reason"] = f"Error during price verification: {exc}"
        result["display_message"] = "Could not verify price. Please try again later."

    return result
