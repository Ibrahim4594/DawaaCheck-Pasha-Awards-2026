"""DRAP Recalls router — serves active drug recalls from Supabase."""

from typing import Optional

from fastapi import APIRouter, Query

from utils.supabase_client import get_supabase, sanitize_like
from utils.cache_utils import timed_cache

router = APIRouter()


@timed_cache(ttl_seconds=300)
def _fetch_active_recalls() -> list[dict]:
    """Fetch active DRAP recalls with 5-minute cache."""
    client = get_supabase()
    response = (
        client.table("drap_recalls")
        .select("*")
        .eq("is_active", True)
        .order("recall_date", desc=True)
        .execute()
    )
    return response.data


@router.get("/")
async def get_recalls(
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    search: Optional[str] = Query(None, description="Search term"),
    recall_class: Optional[str] = Query(None, description="CLASS_I, CLASS_II, CLASS_III"),
) -> dict:
    """Return active DRAP drug recalls with pagination and optional filters."""
    recalls = _fetch_active_recalls()

    if search:
        term = search.lower()
        recalls = [
            r for r in recalls
            if term in (r.get("medicine_name") or "").lower()
            or term in (r.get("recall_reason") or "").lower()
            or term in (r.get("manufacturer") or "").lower()
        ]

    if recall_class:
        recalls = [r for r in recalls if r.get("recall_class") == recall_class]

    total = len(recalls)
    start = (page - 1) * page_size
    end = start + page_size

    return {
        "total": total,
        "page": page,
        "page_size": page_size,
        "results": recalls[start:end],
    }


@router.get("/all")
async def get_all_recalls(
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    source: Optional[str] = Query(None, description="DRAP or FDA"),
) -> dict:
    """Get combined DRAP + FDA recalls."""
    client = get_supabase()

    results = []

    # DRAP recalls
    if not source or source.upper() == "DRAP":
        drap_resp = client.table("drap_recalls").select("*").order("recall_date", desc=True).execute()
        for r in drap_resp.data:
            results.append({
                "source": "DRAP",
                "classification": r.get("recall_class", ""),
                "medicine_name": r.get("medicine_name", ""),
                "reason": r.get("recall_reason", ""),
                "recall_date": r.get("recall_date", ""),
                "manufacturer": r.get("manufacturer", ""),
                "is_active": r.get("is_active", True),
            })

    # FDA recalls
    if not source or source.upper() == "FDA":
        fda_resp = client.table("openfda_recalls").select("*").limit(100).execute()
        for r in fda_resp.data:
            results.append({
                "source": "FDA",
                "classification": r.get("classification", ""),
                "medicine_name": r.get("product_description", ""),
                "reason": r.get("reason_for_recall", ""),
                "recall_date": r.get("recall_initiation_date", ""),
                "manufacturer": r.get("recalling_firm", ""),
                "is_active": True,
            })

    total = len(results)
    start = (page - 1) * page_size
    end = start + page_size

    return {
        "total": total,
        "page": page,
        "page_size": page_size,
        "results": results[start:end],
    }


@router.get("/check/{medicine_name}")
async def check_recall_status(medicine_name: str) -> dict:
    """Check if a specific medicine has any active recalls."""
    client = get_supabase()

    resp = (
        client.table("drap_recalls")
        .select("*")
        .eq("is_active", True)
        .ilike("medicine_name", f"%{sanitize_like(medicine_name)}%")
        .execute()
    )

    if resp.data:
        return {
            "has_recall": True,
            "recall_count": len(resp.data),
            "recalls": resp.data,
        }

    return {"has_recall": False, "recall_count": 0, "recalls": []}
