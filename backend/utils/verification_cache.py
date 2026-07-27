"""
Persistent verification cache.

A pack that has already been verified does not need to be verified again. The
same Panadol batch is scanned by thousands of people; re-running ten Claude
agents on each of those scans costs real money and adds seconds of latency for
an answer that is already known.

This module caches completed verdicts in Supabase, keyed on the pack's identity
(registration number + batch, with a perceptual image hash as fallback for packs
whose registration could not be read). A cache hit returns the stored verdict in
milliseconds at zero model cost.

Correctness rules that keep a cache from becoming a liability in a safety
product:

* **Only confident results are cached.** A verdict the pipeline itself was
  unsure about is recomputed every time.
* **Entries expire.** A cached verdict is a snapshot of what was known when it
  was produced, so it is given a bounded lifetime — short for anything flagged
  as risky, longer for clean results.
* **Recalls invalidate.** When DRAP publishes a recall, every cached verdict for
  the affected medicine is dropped, so a pack that was clean yesterday is
  re-verified today rather than served stale from cache.
"""

from __future__ import annotations

import hashlib
import json
import logging
import re
from datetime import datetime, timedelta, timezone
from typing import Any, Optional

from utils.supabase_client import get_supabase

logger = logging.getLogger(__name__)

TABLE = "verification_cache"

# How long a cached verdict stays servable, by verdict. Anything that is not a
# clean pass is re-checked sooner — the cost of a stale "this is fine" is much
# higher than the cost of recomputing it.
TTL_BY_VERDICT: dict[str, timedelta] = {
    "VERIFIED": timedelta(days=14),
    "UNVERIFIED": timedelta(days=2),
    "DANGER": timedelta(hours=12),
}
DEFAULT_TTL = timedelta(days=1)

# Below this, the pipeline was not confident enough for the answer to be reused.
MIN_CACHEABLE_CONFIDENCE = 0.75


def _norm(value: Optional[str]) -> str:
    """Uppercase alphanumerics only, so formatting differences do not split keys."""
    if not value:
        return ""
    return re.sub(r"[^A-Z0-9]", "", str(value).upper())


def build_cache_key(
    registration_number: Optional[str] = None,
    batch_number: Optional[str] = None,
    barcode: Optional[str] = None,
    image_hash: Optional[str] = None,
) -> Optional[str]:
    """
    Derive a stable identity for a physical pack.

    Preference order reflects how specific each identifier is: a registration
    number plus a batch identifies one production run; a barcode identifies the
    product; an image hash is the last resort for packs whose text could not be
    read. Returns None when nothing identifying was available, which means the
    scan must not be cached at all.
    """
    reg, batch, code = _norm(registration_number), _norm(batch_number), _norm(barcode)

    if reg and batch:
        return f"reg:{reg}|batch:{batch}"
    if reg:
        return f"reg:{reg}"
    if code and len(code) >= 8:
        return f"gtin:{code}"
    if image_hash:
        return f"img:{hashlib.sha256(image_hash.encode()).hexdigest()[:32]}"
    return None


def _ttl_for(scan_result: dict[str, Any]) -> timedelta:
    return TTL_BY_VERDICT.get(str(scan_result.get("overall_verdict", "")).upper(), DEFAULT_TTL)


def is_cacheable(scan_result: dict[str, Any]) -> bool:
    """A verdict is reusable only if the pipeline completed and was confident."""
    if scan_result.get("errors"):
        return False
    try:
        confidence = float(scan_result.get("confidence_score") or 0.0)
    except (TypeError, ValueError):
        return False
    return confidence >= MIN_CACHEABLE_CONFIDENCE


def lookup(cache_key: str) -> Optional[dict[str, Any]]:
    """
    Return a cached verdict for *cache_key*, or None on a miss.

    Never raises: a cache that is down must degrade into a normal (slower)
    verification, not into a failed scan.
    """
    if not cache_key:
        return None
    try:
        response = (
            get_supabase()
            .table(TABLE)
            .select("verdict, expires_at, hit_count")
            .eq("cache_key", cache_key)
            .limit(1)
            .execute()
        )
        rows = response.data or []
        if not rows:
            return None

        row = rows[0]
        expires_at = datetime.fromisoformat(str(row["expires_at"]).replace("Z", "+00:00"))
        if datetime.now(timezone.utc) >= expires_at:
            logger.info("Verification cache expired for %s", cache_key)
            return None

        verdict = row["verdict"]
        if isinstance(verdict, str):
            verdict = json.loads(verdict)

        _record_hit(cache_key, int(row.get("hit_count") or 0))

        verdict["served_from_cache"] = True
        logger.info("Verification cache HIT for %s", cache_key)
        return verdict
    except Exception:
        logger.warning("Verification cache lookup failed for %s", cache_key, exc_info=True)
        return None


def _record_hit(cache_key: str, current: int) -> None:
    """Bump the hit counter. Best-effort — a failure here must not affect the scan."""
    try:
        get_supabase().table(TABLE).update(
            {
                "hit_count": current + 1,
                "last_hit_at": datetime.now(timezone.utc).isoformat(),
            }
        ).eq("cache_key", cache_key).execute()
    except Exception:
        logger.debug("Could not update cache hit count for %s", cache_key, exc_info=True)


def store(cache_key: str, scan_result: dict[str, Any]) -> bool:
    """
    Cache a completed verdict. Returns whether it was stored.

    Never raises, for the same reason as `lookup`.
    """
    if not cache_key or not is_cacheable(scan_result):
        return False

    try:
        payload = {k: v for k, v in scan_result.items() if k != "served_from_cache"}
        medicine = payload.get("medicine_name") or payload.get("brand_name")

        get_supabase().table(TABLE).upsert(
            {
                "cache_key": cache_key,
                "medicine_name": medicine,
                "registration_number": payload.get("registration_number"),
                "verdict": json.dumps(payload),
                "overall_verdict": payload.get("overall_verdict"),
                "confidence_score": payload.get("confidence_score"),
                "cached_at": datetime.now(timezone.utc).isoformat(),
                "expires_at": (datetime.now(timezone.utc) + _ttl_for(payload)).isoformat(),
                "hit_count": 0,
            },
            on_conflict="cache_key",
        ).execute()
        logger.info("Verification cached for %s", cache_key)
        return True
    except Exception:
        logger.warning("Could not cache verification for %s", cache_key, exc_info=True)
        return False


def invalidate_medicine(medicine_name: str) -> int:
    """
    Drop every cached verdict for a medicine.

    Called when a recall is published: a pack that verified clean before the
    recall must not keep being served that answer. Returns the number of entries
    removed.
    """
    if not medicine_name:
        return 0
    try:
        response = (
            get_supabase()
            .table(TABLE)
            .delete()
            .ilike("medicine_name", f"%{medicine_name}%")
            .execute()
        )
        removed = len(response.data or [])
        logger.info("Invalidated %d cached verdicts for %s", removed, medicine_name)
        return removed
    except Exception:
        logger.warning("Cache invalidation failed for %s", medicine_name, exc_info=True)
        return 0


def stats() -> dict[str, Any]:
    """Cache size and cumulative hits — surfaced on the ops/health endpoint."""
    try:
        response = get_supabase().table(TABLE).select("hit_count").execute()
        rows = response.data or []
        hits = sum(int(r.get("hit_count") or 0) for r in rows)
        return {
            "entries": len(rows),
            "total_hits": hits,
            "estimated_scans_served_free": hits,
        }
    except Exception:
        logger.debug("Cache stats unavailable", exc_info=True)
        return {"entries": 0, "total_hits": 0, "estimated_scans_served_free": 0}
