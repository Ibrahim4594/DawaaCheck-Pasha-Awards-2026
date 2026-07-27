"""Agent 10 — RAFIQ (The Companion)
Drug Interaction Checker
Checks the scanned medicine's active ingredient against the user's current
medicines list.  Queries the local Supabase drug_interactions table and the
RxNav interaction API for comprehensive coverage.

Severity levels: CONTRAINDICATED, MAJOR, MODERATE, MINOR
"""

import logging
from typing import Optional

import httpx

from utils.supabase_client import get_supabase, sanitize_like

logger = logging.getLogger(__name__)

AGENT_NUMBER = 10
AGENT_NAME = "RAFIQ — The Companion"

# RxNav interaction API (free, no key required)
RXNAV_INTERACTION_URL = "https://rxnav.nlm.nih.gov/REST/interaction/list.json"
RXNAV_RXCUI_URL = "https://rxnav.nlm.nih.gov/REST/rxcui.json"

# Severity ordering for sorting (highest first)
_SEVERITY_ORDER = {
    "CONTRAINDICATED": 0,
    "MAJOR": 1,
    "MODERATE": 2,
    "MINOR": 3,
}


def check_interactions(
    active_ingredient: str,
    current_medicines: Optional[list[str]] = None,
) -> dict:
    """
    Main entry point for Agent 10.

    Args:
        active_ingredient: Active ingredient of the scanned medicine.
        current_medicines: List of medicine/ingredient names the user is
                          currently taking.

    Returns:
        Standardized agent result dict.
    """
    result: dict = {
        "agent_number": AGENT_NUMBER,
        "agent_name": AGENT_NAME,
        "status": "PASS",
        "confidence_score": 0.0,
        "interaction_found": False,
        "interactions": [],
        "highest_severity": None,
        "total_interactions": 0,
        "display_message": "",
        "fail_reason": None,
    }

    if not active_ingredient or not active_ingredient.strip():
        result["confidence_score"] = 0.50
        result["display_message"] = (
            "No active ingredient identified. Interaction check could not be performed."
        )
        result["fail_reason"] = "Missing active ingredient"
        return result

    if not current_medicines:
        result["confidence_score"] = 1.0
        result["display_message"] = (
            "No current medicines provided. Interaction check skipped."
        )
        return result

    # Clean input
    scanned_drug = active_ingredient.strip().lower()
    user_drugs = [m.strip() for m in current_medicines if m and m.strip()]

    if not user_drugs:
        result["confidence_score"] = 1.0
        result["display_message"] = (
            "No current medicines provided. Interaction check skipped."
        )
        return result

    all_interactions: list[dict] = []

    try:
        # Track data source availability for confidence adjustment
        supabase_ok = True
        rxnav_ok = True

        # ── 1. Check Supabase drug_interactions table ─────────────────
        db_interactions, supabase_ok = _check_supabase_interactions(scanned_drug, user_drugs)
        all_interactions.extend(db_interactions)

        # ── 2. Check RxNav API for additional interactions ────────────
        rxnav_interactions, rxnav_ok = _check_rxnav_interactions(scanned_drug, user_drugs)
        # Only add RxNav results not already found in Supabase
        existing_pairs = {
            (i["drug_a"].lower(), i["drug_b"].lower()) for i in all_interactions
        }
        for interaction in rxnav_interactions:
            pair = (interaction["drug_a"].lower(), interaction["drug_b"].lower())
            reverse_pair = (pair[1], pair[0])
            if pair not in existing_pairs and reverse_pair not in existing_pairs:
                all_interactions.append(interaction)
                existing_pairs.add(pair)

        # Confidence penalty when data sources are unavailable
        confidence_penalty = 0.0
        if not supabase_ok:
            confidence_penalty += 0.15
        if not rxnav_ok:
            confidence_penalty += 0.10

        # ── 3. Build result ───────────────────────────────────────────
        if all_interactions:
            # Sort by severity
            all_interactions.sort(
                key=lambda x: _SEVERITY_ORDER.get(x.get("severity", "MINOR"), 99)
            )

            result["interaction_found"] = True
            result["interactions"] = all_interactions
            result["total_interactions"] = len(all_interactions)
            result["highest_severity"] = all_interactions[0].get("severity", "UNKNOWN")

            # Determine status based on highest severity
            top_severity = result["highest_severity"]
            if top_severity in ("CONTRAINDICATED", "MAJOR"):
                result["status"] = "FAIL"
                result["confidence_score"] = max(0.50, 0.90 - confidence_penalty)
            elif top_severity == "MODERATE":
                result["status"] = "WARNING"
                result["confidence_score"] = max(0.50, 0.80 - confidence_penalty)
            else:
                result["status"] = "PASS"
                result["confidence_score"] = max(0.50, 0.85 - confidence_penalty)

            result["display_message"] = _build_display_message(
                scanned_drug, all_interactions
            )
        else:
            result["status"] = "PASS"
            result["confidence_score"] = max(0.50, 0.85 - confidence_penalty)
            disclaimer = ""
            if not supabase_ok or not rxnav_ok:
                failed_sources = []
                if not supabase_ok:
                    failed_sources.append("local database")
                if not rxnav_ok:
                    failed_sources.append("RxNav API")
                disclaimer = (
                    f" Note: {', '.join(failed_sources)} could not be reached, "
                    "so this result may be incomplete."
                )
            result["display_message"] = (
                f"No known interactions found between '{active_ingredient}' and "
                f"your {len(user_drugs)} current medicine(s). "
                "Always consult your doctor or pharmacist when combining medicines."
                + disclaimer
            )

    except Exception as exc:  # noqa: BLE001
        result["status"] = "UNCERTAIN"
        result["confidence_score"] = 0.0
        result["fail_reason"] = f"Error checking drug interactions: {exc}"
        result["display_message"] = (
            "Could not complete drug interaction check. "
            "Please consult your pharmacist about potential interactions."
        )
        logger.error("Agent 10 error: %s", exc)

    return result


# ─── Supabase lookup ──────────────────────────────────────────────────────────


def _check_supabase_interactions(
    scanned_drug: str, user_drugs: list[str]
) -> tuple[list[dict], bool]:
    """Check the drug_interactions table for each user drug vs scanned drug.

    Returns:
        Tuple of (interactions list, success flag).
    """
    interactions: list[dict] = []

    try:
        client = get_supabase()

        for user_drug in user_drugs:
            resp = (
                client.table("drug_interactions")
                .select("*")
                .or_(
                    f"and(drug_a.ilike.%{sanitize_like(scanned_drug)}%,drug_b.ilike.%{sanitize_like(user_drug)}%),"
                    f"and(drug_a.ilike.%{sanitize_like(user_drug)}%,drug_b.ilike.%{sanitize_like(scanned_drug)}%)"
                )
                .execute()
            )

            if resp.data:
                for row in resp.data:
                    interactions.append({
                        "drug_a": row.get("drug_a", scanned_drug),
                        "drug_b": row.get("drug_b", user_drug),
                        "severity": row.get("severity", "UNKNOWN"),
                        "description": row.get("description", ""),
                        "recommendation": row.get("recommendation", ""),
                        "source": "DRAP/Local Database",
                    })

    except Exception as exc:  # noqa: BLE001
        logger.warning("Supabase interaction check failed: %s", exc)
        return interactions, False

    return interactions, True


# ─── RxNav API lookup ─────────────────────────────────────────────────────────


def _get_rxcui(drug_name: str) -> Optional[str]:
    """Resolve a drug name to an RxNorm CUI using the RxNav API."""
    try:
        resp = httpx.get(
            RXNAV_RXCUI_URL,
            params={"name": drug_name, "search": 2},
            timeout=10,
        )
        if resp.status_code == 200:
            data = resp.json()
            candidates = data.get("idGroup", {}).get("rxnormId", [])
            if candidates:
                return candidates[0]
    except Exception as exc:  # noqa: BLE001
        logger.debug("RxCUI lookup failed for '%s': %s", drug_name, exc)
    return None


def _check_rxnav_interactions(
    scanned_drug: str, user_drugs: list[str]
) -> tuple[list[dict], bool]:
    """
    Use the RxNav interaction API to find interactions between the scanned
    drug and each user drug. The API accepts a list of RxCUIs and returns
    pairwise interactions.

    Returns:
        Tuple of (interactions list, success flag).
    """
    interactions: list[dict] = []

    try:
        # Resolve all drug names to RxCUIs
        all_drugs = [scanned_drug] + user_drugs
        rxcui_map: dict[str, str] = {}

        for drug in all_drugs:
            rxcui = _get_rxcui(drug)
            if rxcui:
                rxcui_map[drug] = rxcui

        scanned_rxcui = rxcui_map.get(scanned_drug)
        if not scanned_rxcui:
            # Could not resolve scanned drug -- not a failure, just unresolvable
            return interactions, True

        # Build list of RxCUIs that includes the scanned drug
        rxcuis_to_check = [scanned_rxcui]
        drug_by_rxcui: dict[str, str] = {scanned_rxcui: scanned_drug}

        for drug in user_drugs:
            rxcui = rxcui_map.get(drug)
            if rxcui:
                rxcuis_to_check.append(rxcui)
                drug_by_rxcui[rxcui] = drug

        if len(rxcuis_to_check) < 2:
            return interactions, True

        # Call the list interaction API
        resp = httpx.get(
            RXNAV_INTERACTION_URL,
            params={"rxcuis": "+".join(rxcuis_to_check)},
            timeout=15,
        )

        if resp.status_code != 200:
            return interactions, False

        data = resp.json()

        # Parse fullInteractionTypeGroup
        for group in data.get("fullInteractionTypeGroup", []):
            for itype in group.get("fullInteractionType", []):
                for pair in itype.get("interactionPair", []):
                    concepts = pair.get("interactionConcept", [])
                    if len(concepts) < 2:
                        continue

                    rxcui_a = concepts[0].get("minConceptItem", {}).get("rxcui", "")
                    rxcui_b = concepts[1].get("minConceptItem", {}).get("rxcui", "")

                    # Only include if one side is the scanned drug
                    if scanned_rxcui not in (rxcui_a, rxcui_b):
                        continue

                    name_a = drug_by_rxcui.get(rxcui_a, concepts[0].get("minConceptItem", {}).get("name", ""))
                    name_b = drug_by_rxcui.get(rxcui_b, concepts[1].get("minConceptItem", {}).get("name", ""))

                    raw_severity = pair.get("severity", "N/A")
                    severity = _map_rxnav_severity(raw_severity)

                    description = pair.get("description", "")

                    interactions.append({
                        "drug_a": name_a,
                        "drug_b": name_b,
                        "severity": severity,
                        "description": description,
                        "recommendation": "Consult your doctor or pharmacist.",
                        "source": "RxNav/NLM",
                    })

    except Exception as exc:  # noqa: BLE001
        logger.warning("RxNav interaction check failed: %s", exc)
        return interactions, False

    return interactions, True


def _map_rxnav_severity(raw: str) -> str:
    """Map RxNav severity string to our standard severity levels."""
    raw_lower = raw.lower().strip()
    if "contraindicated" in raw_lower:
        return "CONTRAINDICATED"
    if "high" in raw_lower or "critical" in raw_lower:
        return "MAJOR"
    if "moderate" in raw_lower:
        return "MODERATE"
    if "low" in raw_lower or "minor" in raw_lower:
        return "MINOR"
    return "MODERATE"  # Default to moderate for unknown severities


# ─── Display message builder ─────────────────────────────────────────────────


def _build_display_message(scanned_drug: str, interactions: list[dict]) -> str:
    """Build a user-friendly display message summarizing all interactions."""
    major = [i for i in interactions if i["severity"] in ("CONTRAINDICATED", "MAJOR")]
    moderate = [i for i in interactions if i["severity"] == "MODERATE"]
    minor = [i for i in interactions if i["severity"] == "MINOR"]

    parts: list[str] = []

    if major:
        drugs = ", ".join({i["drug_b"] if i["drug_a"].lower() == scanned_drug.lower() else i["drug_a"] for i in major})
        parts.append(
            f"DANGER: {len(major)} serious interaction(s) found with: {drugs}. "
            "Do NOT combine these medicines without consulting your doctor immediately."
        )

    if moderate:
        drugs = ", ".join({i["drug_b"] if i["drug_a"].lower() == scanned_drug.lower() else i["drug_a"] for i in moderate})
        parts.append(
            f"CAUTION: {len(moderate)} moderate interaction(s) with: {drugs}. "
            "Use with caution and consult your doctor."
        )

    if minor:
        parts.append(
            f"{len(minor)} minor interaction(s) detected. Low risk but be aware."
        )

    return " ".join(parts)
