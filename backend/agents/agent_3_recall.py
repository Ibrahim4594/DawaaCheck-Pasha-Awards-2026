"""
Agent 3 — MUNZIR (The Warner)
Checks Supabase recall tables (drap_recalls + openfda_recalls) first,
then queries OpenFDA enforcement API as a real-time fallback.
Includes batch range matching, severity classification, and temporal analysis.
"""

import asyncio
import json
import logging
import re
from datetime import datetime, timedelta
from typing import Optional

from utils.supabase_client import get_supabase, sanitize_like
from data.api_clients import openfda_client

AGENT_NUMBER = 3
AGENT_NAME = "MUNZIR — The Warner"

logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# Severity mapping
# ---------------------------------------------------------------------------

_FDA_CLASS_TO_SEVERITY = {
    "Class I": "CRITICAL",
    "Class II": "HIGH",
    "Class III": "MEDIUM",
}

_SEVERITY_ORDER = {"CRITICAL": 4, "HIGH": 3, "MEDIUM": 2, "LOW": 1, "UNKNOWN": 0}


def _classify_severity(
    classification: Optional[str] = None,
    severity_field: Optional[str] = None,
) -> str:
    """Map an FDA classification or raw severity string to a normalised level."""
    if classification:
        for key, val in _FDA_CLASS_TO_SEVERITY.items():
            if key.lower() in classification.lower():
                return val
    if severity_field:
        upper = severity_field.upper()
        if upper in _SEVERITY_ORDER:
            return upper
    return "UNKNOWN"


# ---------------------------------------------------------------------------
# Batch matching helpers
# ---------------------------------------------------------------------------

_RANGE_RE = re.compile(
    r"^([A-Za-z]*)(\d+)\s*[-\u2013]\s*([A-Za-z]*)(\d+)$"
)


def _parse_batch_list(raw) -> list[str]:
    """Parse batch_numbers from JSON array, comma-separated string, or plain string."""
    if raw is None:
        return []
    if isinstance(raw, list):
        return [str(b).strip() for b in raw if b]
    if isinstance(raw, str):
        raw = raw.strip()
        # Try JSON array first
        if raw.startswith("["):
            try:
                parsed = json.loads(raw)
                if isinstance(parsed, list):
                    return [str(b).strip() for b in parsed if b]
            except (json.JSONDecodeError, TypeError):
                pass
        # Comma-separated
        if "," in raw:
            return [b.strip() for b in raw.split(",") if b.strip()]
        return [raw] if raw else []
    return [str(raw)]


def _batch_in_range(batch: str, range_str: str) -> bool:
    """Check if *batch* falls inside a range like 'L100-L200'."""
    m_range = _RANGE_RE.match(range_str.strip())
    if not m_range:
        return False
    prefix_lo, num_lo, prefix_hi, num_hi = m_range.groups()
    # The batch must share the same prefix
    m_batch = re.match(r"^([A-Za-z]*)(\d+)$", batch.strip())
    if not m_batch:
        return False
    prefix_b, num_b = m_batch.groups()
    if prefix_b.upper() != prefix_lo.upper():
        return False
    try:
        return int(num_lo) <= int(num_b) <= int(num_hi)
    except ValueError:
        return False


def _batch_matches(batch_number: str, recall_batches, lot_numbers_str: Optional[str] = None):
    """
    Compare a user batch against a recall's batch list / lot string.

    Returns:
        "exact"   - exact (case-insensitive) match
        "range"   - batch falls inside a recalled range
        "partial" - substring / partial match (with warning)
        None      - no match
    """
    batch_upper = batch_number.strip().upper()

    entries = _parse_batch_list(recall_batches)
    # Also fold in lot_numbers string (OpenFDA code_info style)
    if lot_numbers_str:
        entries.extend(_parse_batch_list(lot_numbers_str))

    for entry in entries:
        entry_upper = entry.strip().upper()
        # Exact match
        if batch_upper == entry_upper:
            return "exact"
        # Range match
        if _batch_in_range(batch_number, entry):
            return "range"

    # Partial / substring match
    for entry in entries:
        entry_upper = entry.strip().upper()
        if batch_upper in entry_upper or entry_upper in batch_upper:
            return "partial"

    return None


# ---------------------------------------------------------------------------
# Temporal helpers
# ---------------------------------------------------------------------------

_DATE_FORMATS = ["%Y-%m-%d", "%Y-%m-%dT%H:%M:%S", "%Y%m%d", "%d/%m/%Y", "%m/%d/%Y"]


def _parse_date(raw) -> Optional[datetime]:
    if not raw:
        return None
    raw_str = str(raw).strip()
    for fmt in _DATE_FORMATS:
        try:
            return datetime.strptime(raw_str, fmt)
        except (ValueError, IndexError):
            pass
    # Try truncated versions (some strings have trailing timezone / extra info)
    for fmt in _DATE_FORMATS:
        try:
            # Attempt to parse the first N characters matching the format length
            # Use a safe length estimate: count non-directive characters + 2-4 per directive
            test_len = min(len(raw_str), 10)
            return datetime.strptime(raw_str[:test_len], fmt)
        except (ValueError, IndexError):
            pass
    # Last resort: try the first 10 chars as ISO
    try:
        return datetime.fromisoformat(raw_str[:10])
    except (ValueError, IndexError):
        return None


def _is_recent(recall_date_raw, months: int = 6) -> bool:
    dt = _parse_date(recall_date_raw)
    if not dt:
        return False
    return (datetime.now() - dt) < timedelta(days=months * 30)


def _is_active(status: Optional[str]) -> bool:
    if not status:
        return True  # assume active if unknown
    s = status.strip().lower()
    return s not in ("completed", "terminated", "closed")


# ---------------------------------------------------------------------------
# Supabase queries
# ---------------------------------------------------------------------------

def _query_drap_recalls(
    reg_number: Optional[str],
    batch_number: Optional[str],
    brand_name: Optional[str],
) -> list[dict]:
    """Query drap_recalls table in Supabase."""
    supabase = get_supabase()
    recalls: list[dict] = []
    seen_ids: set = set()

    def _add(rows):
        for r in rows:
            rid = r.get("id")
            if rid and rid not in seen_ids:
                r["source"] = r.get("source") or "DRAP"
                recalls.append(r)
                seen_ids.add(rid)

    try:
        # Search by medicine_name (brand)
        if brand_name:
            resp = (
                supabase.table("drap_recalls")
                .select("*")
                .ilike("medicine_name", f"%{sanitize_like(brand_name)}%")
                .execute()
            )
            _add(resp.data or [])

        # Search by batch_numbers containing the batch
        if batch_number:
            resp = (
                supabase.table("drap_recalls")
                .select("*")
                .ilike("batch_numbers", f"%{sanitize_like(batch_number)}%")
                .execute()
            )
            _add(resp.data or [])

        # If reg_number provided, also try medicine_name (some DRAP entries
        # embed the reg number in the name or other fields)
        if reg_number:
            resp = (
                supabase.table("drap_recalls")
                .select("*")
                .ilike("medicine_name", f"%{sanitize_like(reg_number)}%")
                .execute()
            )
            _add(resp.data or [])
    except Exception as exc:
        logger.warning("Supabase drap_recalls query failed: %s", exc)

    return recalls


def _query_openfda_recalls_db(
    brand_name: Optional[str],
    batch_number: Optional[str],
) -> list[dict]:
    """Query openfda_recalls table in Supabase."""
    supabase = get_supabase()
    recalls: list[dict] = []
    seen_ids: set = set()

    def _add(rows):
        for r in rows:
            rid = r.get("id")
            if rid and rid not in seen_ids:
                r["source"] = r.get("source") or "OpenFDA-DB"
                recalls.append(r)
                seen_ids.add(rid)

    try:
        if brand_name:
            # Search brand_name
            resp = (
                supabase.table("openfda_recalls")
                .select("*")
                .ilike("brand_name", f"%{sanitize_like(brand_name)}%")
                .execute()
            )
            _add(resp.data or [])

            # Also search generic_name
            resp = (
                supabase.table("openfda_recalls")
                .select("*")
                .ilike("generic_name", f"%{sanitize_like(brand_name)}%")
                .execute()
            )
            _add(resp.data or [])

        if batch_number:
            resp = (
                supabase.table("openfda_recalls")
                .select("*")
                .ilike("lot_numbers", f"%{sanitize_like(batch_number)}%")
                .execute()
            )
            _add(resp.data or [])
    except Exception as exc:
        logger.warning("Supabase openfda_recalls query failed: %s", exc)

    return recalls


# ---------------------------------------------------------------------------
# Live OpenFDA fallback
# ---------------------------------------------------------------------------

async def _check_openfda_live(brand_name: str) -> list[dict]:
    """Query OpenFDA enforcement API as a real-time fallback."""
    try:
        return await openfda_client.check_recalls(brand_name)
    except Exception as exc:
        logger.warning("OpenFDA live recall check failed: %s", exc)
        return []


def _run_async(coro):
    """Safely run an async coroutine from sync context."""
    try:
        try:
            loop = asyncio.get_running_loop()
        except RuntimeError:
            loop = None

        if loop is not None and loop.is_running():
            import concurrent.futures
            with concurrent.futures.ThreadPoolExecutor() as pool:
                return pool.submit(asyncio.run, coro).result(timeout=20)
        else:
            return asyncio.run(coro)
    except Exception as exc:
        logger.warning("Async execution failed: %s", exc)
        return []


# ---------------------------------------------------------------------------
# Recall analysis helpers
# ---------------------------------------------------------------------------

def _analyse_recalls(
    all_recalls: list[dict],
    batch_number: Optional[str],
) -> dict:
    """
    Analyse collected recall records and produce:
      - batch_match_type: "exact" | "range" | "partial" | None
      - highest_severity: CRITICAL / HIGH / MEDIUM / LOW / UNKNOWN
      - has_recent_recalls: bool
      - active_count: int
      - total_count: int
      - multi_recall_pattern: bool (3+ recalls = pattern of issues)
    """
    analysis = {
        "batch_match_type": None,
        "highest_severity": "UNKNOWN",
        "has_recent_recalls": False,
        "active_count": 0,
        "total_count": len(all_recalls),
        "multi_recall_pattern": len(all_recalls) >= 3,
        "matched_recall": None,
    }

    best_match_rank = -1  # exact=3, range=2, partial=1
    match_rank_map = {"exact": 3, "range": 2, "partial": 1}
    best_severity_rank = 0

    for rec in all_recalls:
        # Severity
        sev = _classify_severity(
            rec.get("classification"),
            rec.get("severity"),
        )
        sev_rank = _SEVERITY_ORDER.get(sev, 0)

        # Boost severity for recent recalls
        recall_date = rec.get("recall_date") or rec.get("recall_initiation_date")
        if _is_recent(recall_date):
            analysis["has_recent_recalls"] = True
            if sev == "UNKNOWN":
                sev = "MEDIUM"
                sev_rank = _SEVERITY_ORDER["MEDIUM"]

        if sev_rank > best_severity_rank:
            best_severity_rank = sev_rank
            analysis["highest_severity"] = sev

        # Active status
        status = rec.get("status", "")
        if _is_active(status):
            analysis["active_count"] += 1

        # Batch matching
        if batch_number:
            match_type = _batch_matches(
                batch_number,
                rec.get("batch_numbers"),
                rec.get("lot_numbers") or rec.get("code_info"),
            )
            if match_type:
                rank = match_rank_map.get(match_type, 0)
                if rank > best_match_rank:
                    best_match_rank = rank
                    analysis["batch_match_type"] = match_type
                    analysis["matched_recall"] = rec

    return analysis


def _build_message(analysis: dict, all_recalls: list[dict]) -> str:
    """Build a consumer-facing message based on analysis."""
    match_type = analysis["batch_match_type"]
    severity = analysis["highest_severity"]
    active = analysis["active_count"]
    total = analysis["total_count"]
    pattern = analysis["multi_recall_pattern"]
    recent = analysis["has_recent_recalls"]

    parts: list[str] = []

    if match_type in ("exact", "range"):
        # Batch IS in recall
        parts.append(
            "\U0001f6a8 CRITICAL: This specific batch has been recalled. "
            "Do NOT use. Return to pharmacy."
        )
        matched = analysis.get("matched_recall") or {}
        reason = matched.get("reason") or matched.get("reason_for_recall") or "See recall notice"
        parts.append(f"Reason: {reason}")
        if match_type == "range":
            parts.append(
                "Note: Your batch number falls within a recalled batch range."
            )
    elif match_type == "partial":
        parts.append(
            "\u26a0\ufe0f WARNING: A partial batch number match was found. "
            "This may indicate your batch is affected. "
            "Verify your batch number carefully and consult your pharmacist."
        )
    elif total > 0:
        # Product recalled but different batch
        parts.append(
            "\u26a0\ufe0f WARNING: This medicine has active recalls for other batches. "
            "Verify your batch carefully."
        )
    else:
        parts.append(
            "\u2705 No active recalls found for this medicine."
        )
        return parts[0]

    # Supplementary info
    if severity in ("CRITICAL", "HIGH"):
        parts.append(f"Recall severity: {severity}.")

    if recent:
        parts.append("This recall is recent (within the last 6 months).")

    if active > 0:
        parts.append(f"{active} of {total} recall(s) are still active/ongoing.")

    if pattern:
        parts.append(
            "Note: This medicine has multiple recall records, indicating a pattern of quality issues."
        )

    return " ".join(parts)


# ---------------------------------------------------------------------------
# Main entry point
# ---------------------------------------------------------------------------

def check_recall(
    reg_number: Optional[str] = None,
    batch_number: Optional[str] = None,
    brand_name: Optional[str] = None,
) -> dict:
    """
    Main entry point for Agent 3.

    Args:
        reg_number: DRAP registration number from Agent 1.
        batch_number: Batch/lot number from Agent 1.
        brand_name: Medicine brand name from Agent 1.

    Returns:
        Standardised agent result dict.
    """
    result: dict = {
        "agent_number": AGENT_NUMBER,
        "agent_name": AGENT_NAME,
        "status": "UNCERTAIN",
        "confidence_score": 0.0,
        "recall_found": False,
        "batch_recalled": False,
        "batch_match_type": None,
        "recall_severity": "UNKNOWN",
        "recall_records": [],
        "display_message": "",
        "fail_reason": None,
    }

    try:
        # Guard: if no identifiers at all, return early with low confidence
        if not reg_number and not batch_number and not brand_name:
            result["status"] = "UNCERTAIN"
            result["confidence_score"] = 0.10
            result["display_message"] = (
                "No medicine identifiers provided (name, batch, or registration number). "
                "Cannot check recall status."
            )
            result["fail_reason"] = "No identifiers provided for recall lookup"
            return result

        all_recalls: list[dict] = []
        live_api_checked = False

        # ------------------------------------------------------------------
        # Step 1: Query Supabase — drap_recalls
        # ------------------------------------------------------------------
        drap_recalls = _query_drap_recalls(reg_number, batch_number, brand_name)
        all_recalls.extend(drap_recalls)
        logger.info("Supabase drap_recalls found: %d", len(drap_recalls))

        # ------------------------------------------------------------------
        # Step 2: Query Supabase — openfda_recalls
        # ------------------------------------------------------------------
        fda_db_recalls = _query_openfda_recalls_db(brand_name, batch_number)
        all_recalls.extend(fda_db_recalls)
        logger.info("Supabase openfda_recalls found: %d", len(fda_db_recalls))

        # ------------------------------------------------------------------
        # Step 3: Live OpenFDA fallback (if no DB hits or for freshness)
        # ------------------------------------------------------------------
        if brand_name and len(all_recalls) == 0:
            live_recalls = _run_async(_check_openfda_live(brand_name))
            live_api_checked = True
            if live_recalls:
                for lr in live_recalls:
                    lr["source"] = "OpenFDA-Live"
                    all_recalls.append(lr)
                logger.info("OpenFDA live recalls added: %d", len(live_recalls))

        # ------------------------------------------------------------------
        # Step 4: Analyse results
        # ------------------------------------------------------------------
        analysis = _analyse_recalls(all_recalls, batch_number)

        result["recall_records"] = all_recalls
        result["recall_found"] = len(all_recalls) > 0
        result["batch_match_type"] = analysis["batch_match_type"]
        result["recall_severity"] = analysis["highest_severity"]
        result["batch_recalled"] = analysis["batch_match_type"] in ("exact", "range")

        # Build consumer message
        result["display_message"] = _build_message(analysis, all_recalls)

        # Status & confidence
        if result["batch_recalled"]:
            result["status"] = "FAIL"
            result["confidence_score"] = 0.95
            result["fail_reason"] = (
                "This specific batch has been recalled"
                if analysis["batch_match_type"] == "exact"
                else "This batch falls within a recalled batch range"
            )
        elif analysis["batch_match_type"] == "partial":
            result["status"] = "FAIL"
            result["confidence_score"] = 0.75
            result["fail_reason"] = "Partial batch number match with a recalled batch"
        elif result["recall_found"]:
            result["status"] = "FAIL"
            result["confidence_score"] = 0.80
            result["fail_reason"] = "Active recall exists for this product (different batch)"
        else:
            result["status"] = "PASS"
            result["confidence_score"] = 0.85
            result["display_message"] = (
                "\u2705 No active recalls found for this medicine."
            )

        # Boost confidence when we checked all sources and found nothing
        if result["status"] == "PASS" and len(drap_recalls) == 0 and len(fda_db_recalls) == 0:
            if live_api_checked:
                # Checked both DBs + live API and found nothing — high confidence
                result["confidence_score"] = 0.90
            # else: only DBs checked (no brand_name for live), keep default 0.85

        # Lower confidence slightly for partial matches
        if analysis["batch_match_type"] == "partial":
            result["confidence_score"] = min(result["confidence_score"], 0.75)

    except Exception as exc:  # noqa: BLE001
        logger.exception("Agent 3 recall check error")
        result["status"] = "UNCERTAIN"
        result["confidence_score"] = 0.0
        result["fail_reason"] = f"Error checking recall databases: {exc}"
        result["display_message"] = (
            "Could not check recall status. Databases may be temporarily unavailable."
        )

    # A live recall makes every previously cached verdict for this medicine
    # wrong — those packs were verified before the recall existed and would
    # otherwise keep being served a clean answer. Drop them so the next scan
    # re-runs against current recall data.
    if result.get("status") == "FAIL" and brand_name:
        try:
            from utils.verification_cache import invalidate_medicine

            invalidate_medicine(brand_name)
        except Exception:  # noqa: BLE001
            logger.warning(
                "Could not invalidate cached verdicts for %s", brand_name, exc_info=True
            )

    return result
