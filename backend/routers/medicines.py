"""Medicines router — production-level endpoints querying Supabase."""

import logging
from typing import Optional

from fastapi import APIRouter, HTTPException, Query

from utils.supabase_client import get_supabase, sanitize_like
from utils.cache_utils import timed_cache

logger = logging.getLogger(__name__)

router = APIRouter()


# ---------------------------------------------------------------------------
# Search
# ---------------------------------------------------------------------------

@router.get("/search")
async def search_medicines(
    q: str = Query(..., min_length=2, description="Search query"),
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    category: Optional[str] = Query(None),
) -> dict:
    """Full-text search on drap_medicines. Falls back to ilike if FTS unavailable."""
    try:
        client = get_supabase()
        query = client.table("drap_medicines").select("*", count="exact")

        try:
            query = query.text_search("search_vector", q, config="english")
        except Exception:
            logger.warning("FTS unavailable, falling back to ilike search for query: %s", q)
            safe_q = sanitize_like(q)
            query = query.or_(
                f"brand_name.ilike.%{safe_q}%,generic_name.ilike.%{safe_q}%,manufacturer.ilike.%{safe_q}%"
            )

        if category:
            query = query.eq("category", category)

        start = (page - 1) * page_size
        response = query.range(start, start + page_size - 1).execute()

        return {
            "total": response.count if response.count is not None else len(response.data),
            "page": page,
            "page_size": page_size,
            "results": response.data,
        }
    except Exception as e:
        raise HTTPException(
            status_code=503,
            detail=f"Database temporarily unavailable: {type(e).__name__}"
        )


# ---------------------------------------------------------------------------
# Medicine detail (with generic info + side effects joined)
# ---------------------------------------------------------------------------

@router.get("/detail/{registration_number}")
async def get_medicine_detail(registration_number: str) -> dict:
    """Get full medicine details including generic info and side effects."""
    client = get_supabase()

    # Get branded medicine
    med_resp = (
        client.table("drap_medicines")
        .select("*")
        .eq("registration_number", registration_number)
        .limit(1)
        .execute()
    )
    if not med_resp.data:
        raise HTTPException(status_code=404, detail="Medicine not found")

    medicine = med_resp.data[0]
    generic_name = medicine.get("generic_name", "")

    # Fetch generic info
    generic_info = None
    if generic_name:
        gen_resp = (
            client.table("generic_drugs")
            .select("*")
            .ilike("generic_name", f"%{sanitize_like(generic_name.split('+')[0].strip())}%")
            .limit(1)
            .execute()
        )
        if gen_resp.data:
            generic_info = gen_resp.data[0]

    # Fetch side effects
    side_effects = None
    if generic_name:
        se_resp = (
            client.table("drug_side_effects")
            .select("*")
            .ilike("drug_name", f"%{sanitize_like(generic_name.split('+')[0].strip())}%")
            .limit(1)
            .execute()
        )
        if se_resp.data:
            side_effects = se_resp.data[0]

    # Fetch price + alternatives
    price_info = None
    brand_name = medicine.get("brand_name", "")
    if brand_name:
        price_resp = (
            client.table("medicine_prices")
            .select("*")
            .ilike("brand_name", f"%{sanitize_like(brand_name.split(' ')[0])}%")
            .limit(1)
            .execute()
        )
        if price_resp.data:
            price_info = price_resp.data[0]

    # Fetch image
    image_url = medicine.get("image_url")
    if not image_url and generic_name:
        img_resp = (
            client.table("medicine_images")
            .select("image_url")
            .ilike("drug_name", f"%{sanitize_like(generic_name.split('+')[0].strip().split(' ')[0])}%")
            .limit(1)
            .execute()
        )
        if img_resp.data:
            image_url = img_resp.data[0].get("image_url")

    return {
        "medicine": medicine,
        "generic_info": generic_info,
        "side_effects": side_effects,
        "price_info": price_info,
        "image_url": image_url,
    }


# ---------------------------------------------------------------------------
# Drug interactions checker
# ---------------------------------------------------------------------------

@router.get("/interactions")
async def check_interactions(
    drug: str = Query(..., min_length=2, description="Drug name to check"),
) -> dict:
    """Find all known interactions for a given drug."""
    client = get_supabase()

    resp_a = (
        client.table("drug_interactions")
        .select("*")
        .ilike("drug_a", f"%{sanitize_like(drug)}%")
        .execute()
    )
    resp_b = (
        client.table("drug_interactions")
        .select("*")
        .ilike("drug_b", f"%{sanitize_like(drug)}%")
        .execute()
    )

    # Deduplicate
    seen = set()
    interactions = []
    for item in (resp_a.data or []) + (resp_b.data or []):
        key = f"{item['drug_a']}|{item['drug_b']}"
        if key not in seen:
            seen.add(key)
            interactions.append(item)

    return {
        "drug": drug,
        "interaction_count": len(interactions),
        "interactions": interactions,
    }


# ---------------------------------------------------------------------------
# Drug interaction pair check (for scan agent use)
# ---------------------------------------------------------------------------

@router.get("/interactions/check-pair")
async def check_interaction_pair(
    drug_a: str = Query(..., min_length=2),
    drug_b: str = Query(..., min_length=2),
) -> dict:
    """Check if two specific drugs have a known interaction."""
    client = get_supabase()

    resp = (
        client.table("drug_interactions")
        .select("*")
        .or_(
            f"and(drug_a.ilike.%{sanitize_like(drug_a)}%,drug_b.ilike.%{sanitize_like(drug_b)}%),"
            f"and(drug_a.ilike.%{sanitize_like(drug_b)}%,drug_b.ilike.%{sanitize_like(drug_a)}%)"
        )
        .execute()
    )

    if resp.data:
        return {"has_interaction": True, "interaction": resp.data[0]}
    return {"has_interaction": False, "interaction": None}


# ---------------------------------------------------------------------------
# Side effects lookup
# ---------------------------------------------------------------------------

@router.get("/side-effects/{drug_name}")
async def get_side_effects(drug_name: str) -> dict:
    """Get common and serious side effects for a drug."""
    client = get_supabase()

    resp = (
        client.table("drug_side_effects")
        .select("*")
        .ilike("drug_name", f"%{sanitize_like(drug_name)}%")
        .limit(1)
        .execute()
    )

    if not resp.data:
        raise HTTPException(status_code=404, detail="Side effects not found for this drug")

    return resp.data[0]


# ---------------------------------------------------------------------------
# WHO AWaRe classification
# ---------------------------------------------------------------------------

@router.get("/who-aware/{drug_name}")
async def get_who_aware(drug_name: str) -> dict:
    """Check WHO AWaRe antibiotic classification."""
    client = get_supabase()

    resp = (
        client.table("who_aware_antibiotics")
        .select("*")
        .ilike("name", f"%{sanitize_like(drug_name)}%")
        .limit(1)
        .execute()
    )

    if not resp.data:
        return {"is_antibiotic": False, "classification": None}

    data = resp.data[0]
    return {
        "is_antibiotic": True,
        "classification": data["category"],
        "antibiotic_class": data.get("antibiotic_class"),
        "key_access": data.get("key_access"),
        "oral_available": data.get("oral_available"),
    }


# ---------------------------------------------------------------------------
# Pediatric safety check
# ---------------------------------------------------------------------------

@router.get("/pediatric-safety/{drug_name}")
async def get_pediatric_safety(drug_name: str) -> dict:
    """Check pediatric safety for a drug."""
    client = get_supabase()

    resp = (
        client.table("pediatric_safety")
        .select("*")
        .ilike("drug_name", f"%{sanitize_like(drug_name)}%")
        .execute()
    )

    if not resp.data:
        return {"has_pediatric_concerns": False, "alerts": []}

    return {
        "has_pediatric_concerns": True,
        "alerts": resp.data,
    }


# ---------------------------------------------------------------------------
# Treatment guidelines by condition
# ---------------------------------------------------------------------------

@router.get("/conditions/{condition_name}")
async def get_treatment_guidelines(condition_name: str) -> dict:
    """Get treatment guidelines for a medical condition."""
    client = get_supabase()

    resp = (
        client.table("drug_conditions")
        .select("*")
        .ilike("condition_name", f"%{sanitize_like(condition_name)}%")
        .limit(1)
        .execute()
    )

    if not resp.data:
        raise HTTPException(status_code=404, detail="Condition not found")

    return resp.data[0]


# ---------------------------------------------------------------------------
# Conditions list
# ---------------------------------------------------------------------------

@router.get("/conditions")
async def list_conditions() -> dict:
    """List all available treatment conditions."""
    client = get_supabase()
    resp = client.table("drug_conditions").select("condition_name").execute()
    return {"conditions": [r["condition_name"] for r in resp.data]}


# ---------------------------------------------------------------------------
# Generic alternatives (price comparison)
# ---------------------------------------------------------------------------

@router.get("/alternatives/{brand_name}")
async def get_generic_alternatives(brand_name: str) -> dict:
    """Get cheaper generic alternatives for a branded medicine."""
    client = get_supabase()

    resp = (
        client.table("medicine_prices")
        .select("*")
        .ilike("brand_name", f"%{sanitize_like(brand_name)}%")
        .limit(1)
        .execute()
    )

    if not resp.data:
        raise HTTPException(status_code=404, detail="Price data not found")

    data = resp.data[0]
    return {
        "brand_name": data["brand_name"],
        "mrp": data["mrp"],
        "generic_name": data.get("generic_name"),
        "alternatives": data.get("generic_alternatives", []),
    }


# ---------------------------------------------------------------------------
# Manufacturer info
# ---------------------------------------------------------------------------

@router.get("/manufacturer/{name}")
async def get_manufacturer(name: str) -> dict:
    """Get information about a pharmaceutical manufacturer."""
    client = get_supabase()

    resp = (
        client.table("manufacturers")
        .select("*")
        .ilike("name", f"%{sanitize_like(name)}%")
        .limit(1)
        .execute()
    )

    if not resp.data:
        raise HTTPException(status_code=404, detail="Manufacturer not found")

    return resp.data[0]


# ---------------------------------------------------------------------------
# Database stats
# ---------------------------------------------------------------------------

@timed_cache(ttl_seconds=600)
def _get_db_stats() -> dict:
    client = get_supabase()
    tables = [
        "drap_medicines", "generic_drugs", "drug_interactions", "drug_side_effects",
        "who_aware_antibiotics", "pediatric_safety", "medicine_prices", "medicine_images",
        "drug_conditions", "manufacturers", "openfda_drugs", "openfda_adverse_events",
        "drap_recalls", "rxnorm_classifications",
    ]
    stats = {}
    total = 0
    for table in tables:
        try:
            resp = client.table(table).select("id", count="exact").limit(0).execute()
            count = resp.count or 0
            stats[table] = count
            total += count
        except Exception:
            logger.warning("Failed to get row count for table '%s'", table)
            stats[table] = 0
    stats["total"] = total
    return stats


@router.get("/stats")
async def get_database_stats() -> dict:
    """Get record counts for all drug data tables."""
    return _get_db_stats()
