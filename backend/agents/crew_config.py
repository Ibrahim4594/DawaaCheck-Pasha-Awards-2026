"""
DawaaCheck Crew Configuration
Orchestrates all 10 named AI agents using concurrent execution.

Agent Names:
  1. RAKIB (The Watchman)    — DRAP Registration & Authenticity
  2. KASHIF (The Revealer)   — Barcode & Tamper Detection
  3. MUNZIR (The Warner)     — Recall Status Checker
  4. BASIR (The All-Seeing)  — Ingredient Verification
  5. ADIL (The Just One)     — Price & Alternative Finder
  6. HAKIM (The Wise Judge)  — Final Verdict Synthesizer
  7. HIFAZAT (The Protector) — Antimicrobial Resistance Guard
  8. SHAFIQ (The Compassionate) — Pediatric Safety Checker
  9. SHAHID (The Witness)    — ADR Reporter (Naranjo Algorithm)
 10. RAFIQ (The Companion)   — Drug Interaction Checker

Execution: Phase 1 (1-5 parallel) → Re-enrich (2,3,4,5 parallel) → Phase 2 (7-10 parallel) → Phase 3 (6 verdict)
"""

import asyncio
import logging
import traceback
from concurrent.futures import ThreadPoolExecutor, as_completed
from typing import Any, Callable, Optional

from .agent_1_registration import check_registration
from .agent_2_barcode import validate_barcode
from .agent_3_recall import check_recall
from .agent_4_ingredients import verify_ingredients
from .agent_5_price import verify_price
from .agent_6_verdict import synthesize_verdict
from utils.verification_cache import (
    build_cache_key,
    lookup as cache_lookup,
    store as cache_store,
)
from .agent_7_amr import check_amr
from .agent_8_pediatric import check_pediatric
from .agent_9_adr import process_adr_report
from .agent_10_interactions import check_interactions

logger = logging.getLogger(__name__)

# Overall pipeline timeout (seconds). Individual agent timeouts are shorter.
_PIPELINE_TIMEOUT = 180

# Agent name constants (used in error results for consistency with real agents)
_AGENT_NAMES: dict[int, str] = {
    1: "RAKIB — The Watchman",
    2: "KASHIF — The Revealer",
    3: "MUNZIR — The Warner",
    4: "BASIR — The All-Seeing",
    5: "ADIL — The Just One",
    6: "HAKIM — The Wise Judge",
    7: "HIFAZAT — The Protector",
    8: "SHAFIQ — The Compassionate",
    9: "SHAHID — The Witness",
    10: "RAFIQ — The Companion",
}


def _safe_callback(
    callback: Optional[Callable],
    agent_number: int,
    status: str,
    result_dict: dict,
) -> None:
    """Safely invoke the update callback."""
    if callback is None:
        return
    try:
        callback(agent_number, status, result_dict)
    except Exception as exc:  # noqa: BLE001
        logger.warning("Callback failed for agent %d: %s", agent_number, exc)


def _make_error_result(agent_num: int, exc: Exception) -> dict:
    """Build a standardized error result for a failed agent."""
    return {
        "agent_number": agent_num,
        "agent_name": _AGENT_NAMES.get(agent_num, f"Agent {agent_num}"),
        "status": "UNCERTAIN",
        "confidence_score": 0.0,
        "fail_reason": str(exc),
        "display_message": f"{_AGENT_NAMES.get(agent_num, f'Agent {agent_num}')} encountered an error: {exc}",
    }


def _run_agent_1(
    front_image_b64: str,
    drap_data: Optional[dict],
) -> dict:
    """Run Agent 1 — RAKIB (The Watchman)."""
    return check_registration(front_image_b64, drap_data)


def _run_agent_2(
    back_image_b64: str,
    medicine_name: Optional[str],
    reg_number: Optional[str],
) -> dict:
    """Run Agent 2 — KASHIF (The Revealer)."""
    return validate_barcode(back_image_b64, medicine_name, reg_number)


def _run_agent_3(
    reg_number: Optional[str],
    batch_number: Optional[str],
    brand_name: Optional[str],
) -> dict:
    """Run Agent 3 — MUNZIR (The Warner)."""
    return check_recall(reg_number, batch_number, brand_name)


def _run_agent_4(
    ingredients_image_b64: str,
    medicine_name: Optional[str],
    expected_ingredients: Optional[list],
) -> dict:
    """Run Agent 4 — BASIR (The All-Seeing)."""
    # Skip Vision call if no ingredients image provided
    if not ingredients_image_b64 or not ingredients_image_b64.strip():
        return {
            "agent_number": 4,
            "agent_name": _AGENT_NAMES[4],
            "status": "UNCERTAIN",
            "confidence_score": 0.2,
            "extracted_ingredients": [],
            "display_message": (
                "No ingredients image was provided. "
                "Ingredient verification could not be performed. "
                "Retake the scan with the ingredients panel visible for full analysis."
            ),
            "fail_reason": None,
        }
    return verify_ingredients(ingredients_image_b64, medicine_name, expected_ingredients)


def _run_agent_5(
    medicine_name: str,
    pack_size: Optional[str],
) -> dict:
    """Run Agent 5 — ADIL (The Just One)."""
    return verify_price(medicine_name, pack_size)


def build_and_run_crew(
    front_image_b64: str,
    back_image_b64: str,
    ingredients_image_b64: str,
    user_id: Optional[str] = None,
    patient_type: str = "adult",
    child_age: Optional[float] = None,
    child_weight: Optional[float] = None,
    update_callback: Optional[Callable[[int, str, dict], None]] = None,
    drap_data: Optional[dict] = None,
    expected_ingredients: Optional[list] = None,
    adr_report_data: Optional[dict] = None,
    current_medicines: Optional[list[str]] = None,
    skip_cache: bool = False,
) -> dict:
    """
    Build and run the full DawaaCheck crew of 10 AI agents.

    Execution order:
        Phase 1 (parallel): Agents 1-5 (registration, barcode, recall, ingredients, price)
        Re-enrich (parallel): Agents 2,3,4,5 re-run with Agent 1 extracted data
        Phase 2 (parallel): Agents 7-10 (AMR guard, pediatric safety, ADR reporter, drug interactions)
        Phase 3 (sequential): Agent 6 (verdict synthesis from ALL agents 1-5 + 7-10)

    Args:
        front_image_b64: Base64-encoded front label image.
        back_image_b64: Base64-encoded back label image.
        ingredients_image_b64: Base64-encoded ingredients panel image.
        user_id: Optional user identifier for tracking.
        patient_type: "adult" or "child".
        child_age: Child age in months (if patient_type is "child"). Float to support fractional months.
        child_weight: Child weight in kg (if patient_type is "child").
        update_callback: Called as (agent_number, status, result_dict) after each agent.
        drap_data: Optional DRAP database record for cross-reference.
        expected_ingredients: Optional expected ingredient list for comparison.
        adr_report_data: Optional ADR report data (if user is filing a report).
        current_medicines: Optional list of user's current medicines for interaction check.
        skip_cache: Force a full re-verification, ignoring any cached verdict.

    Returns:
        ScanResult dict with overall_verdict and all agent results.
    """
    import time as _time

    pipeline_start = _time.monotonic()

    scan_result: dict[str, Any] = {
        "user_id": user_id,
        "patient_type": patient_type,
        "overall_verdict": "UNVERIFIED",
        "confidence_score": 0.0,
        "verdict_summary": "",
        "consumer_message": "",
        "agent_results": {},
        "errors": [],
    }

    agent_results_list: list[dict] = []

    # ─── Phase 1: Run Agents 1-5 in parallel ───────────────────────────
    logger.info("Phase 1: Starting agents 1-5 in parallel")

    phase1_results: dict[int, dict] = {}

    with ThreadPoolExecutor(max_workers=5, thread_name_prefix="agent") as executor:
        futures = {
            executor.submit(
                _run_agent_1, front_image_b64, drap_data
            ): 1,
            executor.submit(
                _run_agent_2, back_image_b64, None, None
            ): 2,
            executor.submit(
                _run_agent_3, None, None, None
            ): 3,
            executor.submit(
                _run_agent_4, ingredients_image_b64, None, expected_ingredients
            ): 4,
            executor.submit(
                _run_agent_5, "unknown", None
            ): 5,
        }

        for future in as_completed(futures):
            agent_num = futures[future]
            try:
                res = future.result(timeout=90)
                phase1_results[agent_num] = res
                # Only send callback for Agent 1 now; agents 2,3,4,5 will be
                # re-enriched so we defer their final callback to avoid
                # sending stale intermediate results to the frontend.
                if agent_num == 1:
                    _safe_callback(update_callback, agent_num, res.get("status", "UNCERTAIN"), res)
                logger.info("Agent %d completed: %s", agent_num, res.get("status"))
            except Exception as exc:  # noqa: BLE001
                error_result = _make_error_result(agent_num, exc)
                phase1_results[agent_num] = error_result
                scan_result["errors"].append(
                    {"agent": agent_num, "error": str(exc)}
                )
                if agent_num == 1:
                    _safe_callback(update_callback, agent_num, "UNCERTAIN", error_result)
                logger.error("Agent %d failed: %s\n%s", agent_num, exc, traceback.format_exc())

    # Extract data from Agent 1 to feed into other agents
    agent1_data = phase1_results.get(1, {})
    extracted = agent1_data.get("extracted_data", {})
    brand_name = extracted.get("brand_name")
    reg_number = extracted.get("registration_number")
    batch_number = extracted.get("batch_number")
    pack_size = extracted.get("pack_size")
    active_ingredient = extracted.get("generic_name") or brand_name or "unknown"

    # ─── Verification cache ────────────────────────────────────────────
    # Agent 1 has now identified the pack, so the rest of the pipeline can be
    # skipped entirely if this exact pack+batch was already verified recently.
    # Agent 1 always runs: identity has to be established from *this* photo
    # before any cached answer can safely be attributed to it.
    cache_key = build_cache_key(
        registration_number=reg_number,
        batch_number=batch_number,
        barcode=extracted.get("barcode"),
    )
    if cache_key and not skip_cache:
        cached = cache_lookup(cache_key)
        if cached is not None:
            logger.info("Serving cached verdict for %s (skipped agents 2-10)", cache_key)
            # Replay the cached agent findings so the client's live rail and
            # console still fill in exactly as they would on a fresh run.
            for num in (2, 3, 4, 5, 7, 8, 9, 10, 6):
                agent_res = cached.get("agent_results", {}).get(f"agent_{num}")
                if agent_res:
                    _safe_callback(
                        update_callback, num, agent_res.get("status", "PASS"), agent_res
                    )
            cached["user_id"] = user_id
            cached["patient_type"] = patient_type
            cached["cache_key"] = cache_key
            return cached

    # ─── Re-enrich agents 2, 3, 4, 5 with Agent 1 data (parallel) ────
    # Agents 2,3,5 ran with None/placeholder values in Phase 1 for parallelism.
    # Agent 4 ran without medicine_name. Now re-run them all with extracted data.
    if brand_name or reg_number:
        logger.info("Re-enriching agents 2, 3, 4, 5 with Agent 1 extracted data (parallel)")

        with ThreadPoolExecutor(max_workers=4, thread_name_prefix="re-enrich") as executor:
            re_futures: dict[int, Any] = {}

            # Agent 2 re-enrichment (only if back image exists)
            if back_image_b64 and back_image_b64.strip():
                re_futures[2] = executor.submit(
                    _run_agent_2, back_image_b64, brand_name, reg_number
                )

            # Agent 3 re-enrichment
            re_futures[3] = executor.submit(
                _run_agent_3, reg_number, batch_number, brand_name
            )

            # Agent 4 re-enrichment (with medicine_name for database cross-ref)
            if ingredients_image_b64 and ingredients_image_b64.strip():
                re_futures[4] = executor.submit(
                    _run_agent_4, ingredients_image_b64, brand_name, expected_ingredients
                )

            # Agent 5 re-enrichment
            re_futures[5] = executor.submit(
                _run_agent_5, brand_name or "unknown", pack_size
            )

            for agent_num, future in re_futures.items():
                try:
                    enriched = future.result(timeout=90)
                    phase1_results[agent_num] = enriched
                    _safe_callback(
                        update_callback, agent_num,
                        enriched.get("status", "UNCERTAIN"), enriched,
                    )
                except Exception as exc:  # noqa: BLE001
                    logger.warning("Agent %d re-enrichment failed: %s", agent_num, exc)
                    # Keep the original Phase 1 result; still send its callback
                    orig = phase1_results.get(agent_num)
                    if orig:
                        _safe_callback(
                            update_callback, agent_num,
                            orig.get("status", "UNCERTAIN"), orig,
                        )
    else:
        # No useful data from Agent 1 -- send callbacks for the original results
        for agent_num in (2, 3, 4, 5):
            orig = phase1_results.get(agent_num)
            if orig:
                _safe_callback(
                    update_callback, agent_num,
                    orig.get("status", "UNCERTAIN"), orig,
                )

    # Collect phase 1 results
    for i in range(1, 6):
        if i in phase1_results:
            agent_results_list.append(phase1_results[i])
            scan_result["agent_results"][f"agent_{i}"] = phase1_results[i]

    # ─── Pipeline timeout check ──────────────────────────────────────
    elapsed = _time.monotonic() - pipeline_start
    if elapsed > _PIPELINE_TIMEOUT:
        logger.error("Pipeline timeout after %.1fs, skipping Phase 2 & 3", elapsed)
        scan_result["errors"].append({"agent": "pipeline", "error": f"Timeout after {elapsed:.0f}s"})
        scan_result["overall_verdict"] = "UNVERIFIED"
        scan_result["verdict_summary"] = "Analysis timed out before all agents could run."
        scan_result["consumer_message"] = (
            "The analysis took too long and could not be completed. "
            "Please try again. If the problem persists, consult your pharmacist."
        )
        return scan_result

    # ─── Phase 2: Run Agents 7-10 in parallel ──────────────────────────
    logger.info("Phase 2: Starting agents 7-10 in parallel")

    with ThreadPoolExecutor(max_workers=4, thread_name_prefix="agent-post") as executor:
        futures_phase2 = {}

        # Agent 7 — HIFAZAT (The Protector) - AMR Guard
        futures_phase2[executor.submit(check_amr, active_ingredient)] = 7

        # Agent 8 — SHAFIQ (The Compassionate) - Pediatric Safety
        if patient_type == "child":
            futures_phase2[executor.submit(
                check_pediatric, active_ingredient, child_age, child_weight
            )] = 8
        else:
            # Still run but without child-specific data
            futures_phase2[executor.submit(
                check_pediatric, active_ingredient, None, None
            )] = 8

        # Agent 9 — SHAHID (The Witness) - ADR Reporter
        if adr_report_data:
            # Shallow-copy to avoid mutating the caller's dict
            enriched_adr = dict(adr_report_data)
            enriched_adr.setdefault("medicine_name", brand_name or "Unknown")
            enriched_adr.setdefault("active_ingredient", active_ingredient)
            enriched_adr.setdefault("batch_number", batch_number)
            enriched_adr.setdefault("patient_type", patient_type)
            enriched_adr.setdefault("patient_age", child_age)
            enriched_adr.setdefault("patient_weight", child_weight)
            futures_phase2[executor.submit(process_adr_report, enriched_adr)] = 9
        else:
            futures_phase2[executor.submit(process_adr_report, {})] = 9

        # Agent 10 — RAFIQ (The Companion) - Drug Interaction Checker
        if current_medicines:
            futures_phase2[executor.submit(
                check_interactions, active_ingredient, current_medicines
            )] = 10
        else:
            futures_phase2[executor.submit(
                check_interactions, active_ingredient, []
            )] = 10

        for future in as_completed(futures_phase2):
            agent_num = futures_phase2[future]
            try:
                res = future.result(timeout=60)
                scan_result["agent_results"][f"agent_{agent_num}"] = res
                _safe_callback(update_callback, agent_num, res.get("status", "UNCERTAIN"), res)
                logger.info("Agent %d completed: %s", agent_num, res.get("status"))
            except Exception as exc:  # noqa: BLE001
                error_result = _make_error_result(agent_num, exc)
                scan_result["agent_results"][f"agent_{agent_num}"] = error_result
                scan_result["errors"].append(
                    {"agent": agent_num, "error": str(exc)}
                )
                _safe_callback(update_callback, agent_num, "UNCERTAIN", error_result)
                logger.error("Agent %d failed: %s\n%s", agent_num, exc, traceback.format_exc())

    # Collect phase 2 (safety layer) results into agent_results_list
    for i in (7, 8, 9, 10):
        agent_key = f"agent_{i}"
        if agent_key in scan_result["agent_results"]:
            agent_results_list.append(scan_result["agent_results"][agent_key])

    # ─── Phase 3: Run Agent 6 (Verdict Synthesis with ALL agents) ──────
    logger.info("Phase 3: Running Agent 6 - Verdict Synthesis (all 10 agents)")

    try:
        verdict_result = synthesize_verdict(agent_results_list)
        scan_result["agent_results"]["agent_6"] = verdict_result
        scan_result["overall_verdict"] = verdict_result.get("overall_verdict", "UNVERIFIED")
        scan_result["confidence_score"] = verdict_result.get("confidence_score", 0.0)
        scan_result["verdict_summary"] = verdict_result.get("display_message", "")
        scan_result["consumer_message"] = verdict_result.get("consumer_message", "")
        scan_result["risk_score"] = verdict_result.get("risk_score", 0)
        scan_result["risk_level"] = verdict_result.get("risk_level", "UNKNOWN")
        scan_result["safety_alerts"] = verdict_result.get("safety_alerts", [])
        scan_result["recommendations"] = verdict_result.get("recommendations", [])
        scan_result["detailed_analysis"] = verdict_result.get("detailed_analysis", {})
        _safe_callback(update_callback, 6, verdict_result.get("status", "UNCERTAIN"), verdict_result)
        logger.info("Agent 6 verdict: %s (risk: %d)", verdict_result.get("overall_verdict"), verdict_result.get("risk_score", 0))
    except Exception as exc:  # noqa: BLE001
        error_result = _make_error_result(6, exc)
        scan_result["agent_results"]["agent_6"] = error_result
        scan_result["errors"].append({"agent": 6, "error": str(exc)})
        logger.error("Agent 6 failed: %s\n%s", exc, traceback.format_exc())
        _safe_callback(update_callback, 6, "UNCERTAIN", error_result)

    # Cache the completed verdict so the next scan of this pack is instant and
    # costs nothing. Only confident, error-free results are stored — see
    # `verification_cache.is_cacheable`.
    if cache_key:
        scan_result["cache_key"] = cache_key
        cache_store(cache_key, scan_result)

    total_elapsed = _time.monotonic() - pipeline_start
    logger.info(
        "Crew execution complete in %.1fs. Verdict: %s (confidence: %.2f, risk: %s)",
        total_elapsed,
        scan_result["overall_verdict"],
        scan_result["confidence_score"],
        scan_result.get("risk_score", "N/A"),
    )

    return scan_result


async def build_and_run_crew_async(
    front_image_b64: str,
    back_image_b64: str,
    ingredients_image_b64: str,
    user_id: Optional[str] = None,
    patient_type: str = "adult",
    child_age: Optional[float] = None,
    child_weight: Optional[float] = None,
    update_callback: Optional[Callable[[int, str, dict], None]] = None,
    drap_data: Optional[dict] = None,
    expected_ingredients: Optional[list] = None,
    adr_report_data: Optional[dict] = None,
    current_medicines: Optional[list[str]] = None,
    skip_cache: bool = False,
) -> dict:
    """
    Async wrapper for build_and_run_crew.
    Runs the synchronous crew in a thread pool to avoid blocking the event loop.
    """
    loop = asyncio.get_running_loop()
    return await loop.run_in_executor(
        None,
        lambda: build_and_run_crew(
            front_image_b64=front_image_b64,
            back_image_b64=back_image_b64,
            ingredients_image_b64=ingredients_image_b64,
            user_id=user_id,
            patient_type=patient_type,
            child_age=child_age,
            child_weight=child_weight,
            update_callback=update_callback,
            drap_data=drap_data,
            expected_ingredients=expected_ingredients,
            adr_report_data=adr_report_data,
            current_medicines=current_medicines,
            skip_cache=skip_cache,
        ),
    )
