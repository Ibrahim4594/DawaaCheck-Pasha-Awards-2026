"""Agent 6 — HAKIM (The Wise Judge)
Final Verdict Synthesizer
Aggregates results from ALL 10 agents (core verification 1-5 + safety layer 7-10)
and produces a comprehensive overall verdict with risk scoring and safety alerts.

Three-tier verdict: VERIFIED / DANGER / UNVERIFIED
Risk score: 0-100 (LOW / MODERATE / HIGH / CRITICAL)
"""

import logging
from typing import Optional

logger = logging.getLogger(__name__)

AGENT_NUMBER = 6
AGENT_NAME = "HAKIM — The Wise Judge"

# ---------------------------------------------------------------------------
# Agent whose FAIL triggers an automatic DANGER verdict
# ---------------------------------------------------------------------------
CRITICAL_AGENTS = {
    1,   # Registration - unregistered medicine
    3,   # Recall - recalled medicine
    8,   # Pediatric Safety - unsafe for child
    10,  # Drug Interactions - contraindicated / major interaction
}

# ---------------------------------------------------------------------------
# Weighted confidence scoring (sum = 1.00)
# ---------------------------------------------------------------------------
AGENT_WEIGHTS: dict[int, float] = {
    1:  0.22,   # Registration - highest weight
    2:  0.10,   # Barcode
    3:  0.20,   # Recall - high weight
    4:  0.15,   # Ingredients
    5:  0.05,   # Price - lowest weight
    7:  0.05,   # AMR Guard
    8:  0.10,   # Pediatric Safety
    9:  0.03,   # ADR Reporter
    10: 0.10,   # Drug Interactions
}

# ---------------------------------------------------------------------------
# Severity levels for concerns
# ---------------------------------------------------------------------------
SEVERITY_CRITICAL = "CRITICAL"
SEVERITY_HIGH = "HIGH"
SEVERITY_MEDIUM = "MEDIUM"
SEVERITY_LOW = "LOW"

# ---------------------------------------------------------------------------
# Risk band definitions
# ---------------------------------------------------------------------------
RISK_BANDS = [
    (0, 20, "LOW", "Safe to use as directed"),
    (21, 50, "MODERATE", "Use with caution"),
    (51, 80, "HIGH", "Consult a pharmacist before using"),
    (81, 100, "CRITICAL", "Do NOT use - seek professional advice immediately"),
]


def _get_risk_band(score: int) -> dict:
    """Return the risk band dict for a given 0-100 score."""
    for low, high, label, advice in RISK_BANDS:
        if low <= score <= high:
            return {"level": label, "advice": advice}
    return {"level": "UNKNOWN", "advice": "Consult your pharmacist."}


# ===================================================================
# Confidence calculation
# ===================================================================

def _calculate_overall_confidence(agent_results: list[dict]) -> float:
    """Calculate weighted overall confidence score across all available agents."""
    total_weight = 0.0
    weighted_score = 0.0

    for res in agent_results:
        agent_num = res.get("agent_number", 0)
        if agent_num == AGENT_NUMBER:
            continue  # skip self
        weight = AGENT_WEIGHTS.get(agent_num, 0.0)
        if weight == 0.0:
            continue

        confidence = res.get("confidence_score", 0.0)

        status = res.get("status", "UNCERTAIN")
        if status == "FAIL":
            confidence *= 0.3
        elif status == "UNCERTAIN":
            confidence *= 0.5

        weighted_score += weight * confidence
        total_weight += weight

    return round(weighted_score / total_weight, 3) if total_weight > 0 else 0.0


# ===================================================================
# Risk score calculation (0-100, higher = more dangerous)
# ===================================================================

def _calculate_risk_score(
    agent_results: list[dict],
    concerns: list[dict],
) -> int:
    """
    Calculate a 0-100 risk score.
    Starts at 0 (perfect) and accumulates penalty points.
    """
    score = 0

    # --- Penalty from agent statuses ---
    agent_map = {r.get("agent_number"): r for r in agent_results if r.get("agent_number") != AGENT_NUMBER}

    # Agent 1: Registration
    a1 = agent_map.get(1)
    if a1:
        if a1.get("status") == "FAIL":
            score += 35  # unregistered is very dangerous
        elif a1.get("status") == "UNCERTAIN":
            score += 15

    # Agent 2: Barcode
    a2 = agent_map.get(2)
    if a2:
        if a2.get("status") == "FAIL":
            score += 10
        elif a2.get("status") == "UNCERTAIN":
            score += 5

    # Agent 3: Recall
    a3 = agent_map.get(3)
    if a3:
        if a3.get("status") == "FAIL":
            score += 30  # recalled medicine
        elif a3.get("status") == "UNCERTAIN":
            score += 10

    # Agent 4: Ingredients
    a4 = agent_map.get(4)
    if a4:
        if a4.get("status") == "FAIL":
            score += 20
        elif a4.get("status") == "UNCERTAIN":
            score += 8

    # Agent 5: Price
    a5 = agent_map.get(5)
    if a5:
        if a5.get("status") == "FAIL":
            # Suspiciously cheap medicines may be counterfeit — higher penalty
            if a5.get("is_suspicious_cheap"):
                score += 15
            else:
                score += 5
        elif a5.get("status") == "UNCERTAIN":
            score += 2

    # Agent 7: AMR Guard
    a7 = agent_map.get(7)
    if a7 and a7.get("is_antibiotic"):
        classification = (a7.get("aware_classification") or "").upper()
        if classification == "RESERVE":
            score += 12
        elif classification == "WATCH":
            score += 5

    # Agent 8: Pediatric Safety
    a8 = agent_map.get(8)
    if a8:
        if a8.get("status") == "FAIL":
            score += 25  # unsafe for child
        elif a8.get("status") == "UNCERTAIN":
            score += 8

    # Agent 9: ADR Reporter
    a9 = agent_map.get(9)
    if a9 and a9.get("signal_triggered"):
        score += 10

    # Agent 10: Drug Interactions
    a10 = agent_map.get(10)
    if a10 and a10.get("interaction_found"):
        severity = (a10.get("highest_severity") or "").upper()
        if severity == "CONTRAINDICATED":
            score += 30
        elif severity == "MAJOR":
            score += 20
        elif severity == "MODERATE":
            score += 8
        elif severity == "MINOR":
            score += 3
        else:
            # Unknown severity with interaction found — treat conservatively
            score += 15
    elif a10 and a10.get("status") == "FAIL" and not a10.get("interaction_found"):
        # Agent 10 FAIL without interaction_found (e.g. error during check)
        score += 10

    # Clamp to 0-100
    return max(0, min(100, score))


# ===================================================================
# Concern / safety alert extraction
# ===================================================================

def _extract_concerns(agent_results: list[dict]) -> list[dict]:
    """
    Walk every agent result and extract individual concerns with severity.
    Returns a list sorted by severity (CRITICAL first).
    """
    severity_order = {SEVERITY_CRITICAL: 0, SEVERITY_HIGH: 1, SEVERITY_MEDIUM: 2, SEVERITY_LOW: 3}
    concerns: list[dict] = []

    agent_map = {r.get("agent_number"): r for r in agent_results if r.get("agent_number") != AGENT_NUMBER}

    # --- Agent 1: Registration ---
    a1 = agent_map.get(1)
    if a1:
        if a1.get("status") == "FAIL":
            concerns.append({
                "agent": 1,
                "agent_name": "DRAP Registration",
                "severity": SEVERITY_CRITICAL,
                "title": "Medicine not registered with DRAP",
                "detail": a1.get("fail_reason") or a1.get("display_message", ""),
            })
        elif a1.get("status") == "UNCERTAIN":
            concerns.append({
                "agent": 1,
                "agent_name": "DRAP Registration",
                "severity": SEVERITY_HIGH,
                "title": "Registration could not be confirmed",
                "detail": a1.get("display_message", ""),
            })

    # --- Agent 2: Barcode ---
    a2 = agent_map.get(2)
    if a2:
        if a2.get("status") == "FAIL":
            concerns.append({
                "agent": 2,
                "agent_name": "Barcode Verification",
                "severity": SEVERITY_MEDIUM,
                "title": "Barcode verification failed",
                "detail": a2.get("fail_reason") or a2.get("display_message", ""),
            })
        elif a2.get("status") == "UNCERTAIN":
            concerns.append({
                "agent": 2,
                "agent_name": "Barcode Verification",
                "severity": SEVERITY_LOW,
                "title": "Barcode could not be verified",
                "detail": a2.get("display_message", ""),
            })

    # --- Agent 3: Recall ---
    a3 = agent_map.get(3)
    if a3:
        if a3.get("status") == "FAIL":
            concerns.append({
                "agent": 3,
                "agent_name": "Recall Check",
                "severity": SEVERITY_CRITICAL,
                "title": "Medicine has been RECALLED",
                "detail": a3.get("fail_reason") or a3.get("display_message", ""),
            })
        elif a3.get("status") == "UNCERTAIN":
            concerns.append({
                "agent": 3,
                "agent_name": "Recall Check",
                "severity": SEVERITY_HIGH,
                "title": "Recall status could not be confirmed",
                "detail": a3.get("display_message", ""),
            })

    # --- Agent 4: Ingredients ---
    a4 = agent_map.get(4)
    if a4:
        if a4.get("status") == "FAIL":
            concerns.append({
                "agent": 4,
                "agent_name": "Ingredient Verification",
                "severity": SEVERITY_HIGH,
                "title": "Ingredient mismatch detected",
                "detail": a4.get("fail_reason") or a4.get("display_message", ""),
            })
        elif a4.get("status") == "UNCERTAIN":
            concerns.append({
                "agent": 4,
                "agent_name": "Ingredient Verification",
                "severity": SEVERITY_MEDIUM,
                "title": "Ingredients could not be fully verified",
                "detail": a4.get("display_message", ""),
            })

    # --- Agent 5: Price ---
    a5 = agent_map.get(5)
    if a5:
        if a5.get("status") == "FAIL":
            # Suspiciously cheap medicines may be counterfeit — higher severity
            if a5.get("is_suspicious_cheap"):
                concerns.append({
                    "agent": 5,
                    "agent_name": "Price Verification",
                    "severity": SEVERITY_MEDIUM,
                    "title": "Suspiciously cheap — possible counterfeit",
                    "detail": a5.get("fail_reason") or a5.get("display_message", ""),
                })
            else:
                concerns.append({
                    "agent": 5,
                    "agent_name": "Price Verification",
                    "severity": SEVERITY_LOW,
                    "title": "Price anomaly detected",
                    "detail": a5.get("fail_reason") or a5.get("display_message", ""),
                })

    # --- Agent 7: AMR Guard ---
    a7 = agent_map.get(7)
    if a7 and a7.get("is_antibiotic"):
        classification = (a7.get("aware_classification") or "").upper()
        if classification == "RESERVE":
            concerns.append({
                "agent": 7,
                "agent_name": "AMR Guard",
                "severity": SEVERITY_HIGH,
                "title": "RESERVE antibiotic - last resort medicine",
                "detail": (
                    f"{a7.get('display_message', '')} "
                    "RESERVE antibiotics should only be used under specialist supervision "
                    "with a valid prescription. Misuse accelerates antimicrobial resistance."
                ),
            })
        elif classification == "WATCH":
            concerns.append({
                "agent": 7,
                "agent_name": "AMR Guard",
                "severity": SEVERITY_MEDIUM,
                "title": "WATCH antibiotic - use with caution",
                "detail": a7.get("display_message", ""),
            })

    # --- Agent 8: Pediatric Safety ---
    a8 = agent_map.get(8)
    if a8:
        if a8.get("status") == "FAIL":
            concerns.append({
                "agent": 8,
                "agent_name": "Pediatric Safety",
                "severity": SEVERITY_CRITICAL,
                "title": "UNSAFE for child",
                "detail": a8.get("fail_reason") or a8.get("display_message", ""),
            })
        elif a8.get("status") == "UNCERTAIN":
            concerns.append({
                "agent": 8,
                "agent_name": "Pediatric Safety",
                "severity": SEVERITY_MEDIUM,
                "title": "Pediatric safety could not be confirmed",
                "detail": a8.get("display_message", ""),
            })

    # --- Agent 9: ADR Reporter ---
    a9 = agent_map.get(9)
    if a9 and a9.get("signal_triggered"):
        signal_details = a9.get("signal_details") or {}
        reasons = signal_details.get("signal_reasons", []) if isinstance(signal_details, dict) else []
        concerns.append({
            "agent": 9,
            "agent_name": "ADR Reporter",
            "severity": SEVERITY_HIGH,
            "title": "Safety signal triggered",
            "detail": (
                "An adverse drug reaction safety signal has been detected. "
                + ("; ".join(reasons) if reasons else a9.get("display_message", ""))
            ),
        })

    # --- Agent 10: Drug Interactions ---
    a10 = agent_map.get(10)
    if a10 and a10.get("interaction_found"):
        severity = (a10.get("highest_severity") or "").upper()
        if severity == "CONTRAINDICATED":
            concerns.append({
                "agent": 10,
                "agent_name": "Drug Interaction Checker",
                "severity": SEVERITY_CRITICAL,
                "title": "CONTRAINDICATED drug interaction",
                "detail": a10.get("display_message", ""),
            })
        elif severity == "MAJOR":
            concerns.append({
                "agent": 10,
                "agent_name": "Drug Interaction Checker",
                "severity": SEVERITY_CRITICAL,
                "title": "MAJOR drug interaction detected",
                "detail": a10.get("display_message", ""),
            })
        elif severity == "MODERATE":
            concerns.append({
                "agent": 10,
                "agent_name": "Drug Interaction Checker",
                "severity": SEVERITY_MEDIUM,
                "title": "Moderate drug interaction",
                "detail": a10.get("display_message", ""),
            })
        elif severity == "MINOR":
            concerns.append({
                "agent": 10,
                "agent_name": "Drug Interaction Checker",
                "severity": SEVERITY_LOW,
                "title": "Minor drug interaction",
                "detail": a10.get("display_message", ""),
            })
        else:
            # Unknown severity — treat conservatively
            concerns.append({
                "agent": 10,
                "agent_name": "Drug Interaction Checker",
                "severity": SEVERITY_HIGH,
                "title": "Drug interaction detected (severity unknown)",
                "detail": a10.get("display_message", ""),
            })
    elif a10 and a10.get("status") == "FAIL" and not a10.get("interaction_found"):
        # Agent 10 errored out — flag the uncertainty
        concerns.append({
            "agent": 10,
            "agent_name": "Drug Interaction Checker",
            "severity": SEVERITY_HIGH,
            "title": "Drug interaction check could not be completed",
            "detail": a10.get("fail_reason") or a10.get("display_message", ""),
        })

    # Sort by severity: CRITICAL > HIGH > MEDIUM > LOW
    concerns.sort(key=lambda c: severity_order.get(c["severity"], 99))

    return concerns


# ===================================================================
# Safety alerts (urgent items only)
# ===================================================================

def _build_safety_alerts(concerns: list[dict]) -> list[dict]:
    """
    Extract only CRITICAL and HIGH concerns into a compact safety_alerts list.
    These are the items that should be shown prominently in the UI.
    """
    alerts: list[dict] = []
    for c in concerns:
        if c["severity"] in (SEVERITY_CRITICAL, SEVERITY_HIGH):
            alerts.append({
                "severity": c["severity"],
                "title": c["title"],
                "agent": c["agent_name"],
                "detail": c["detail"],
            })
    return alerts


# ===================================================================
# Recommendations
# ===================================================================

def _build_recommendations(
    verdict: str,
    concerns: list[dict],
    agent_results: list[dict],
) -> list[str]:
    """Generate actionable recommendations based on the verdict and concerns."""
    recommendations: list[str] = []
    agent_map = {r.get("agent_number"): r for r in agent_results if r.get("agent_number") != AGENT_NUMBER}

    if verdict == "DANGER":
        recommendations.append(
            "Do NOT use this medicine until you have consulted a healthcare professional."
        )

        # Specific recommendations based on what failed
        concern_agents = {c["agent"] for c in concerns if c["severity"] == SEVERITY_CRITICAL}

        if 1 in concern_agents:
            recommendations.append(
                "This medicine is not registered with DRAP (Drug Regulatory Authority of Pakistan). "
                "Report it to DRAP at 0800-02345 or visit your nearest Drug Inspector office."
            )
        if 3 in concern_agents:
            recommendations.append(
                "This medicine has been recalled. Return it to the pharmacy for a refund or replacement. "
                "Do not dispose of it yourself."
            )
        if 8 in concern_agents:
            recommendations.append(
                "This medicine is NOT safe for the specified child. "
                "Consult a pediatrician for a safe alternative immediately."
            )
        if 10 in concern_agents:
            recommendations.append(
                "A dangerous drug interaction has been detected with your current medicines. "
                "Contact your doctor or pharmacist before taking this medicine."
            )

    elif verdict == "UNVERIFIED":
        recommendations.append(
            "This medicine could not be fully verified. Consult your pharmacist before using."
        )

        has_ingredient_concern = any(c["agent"] == 4 for c in concerns)
        if has_ingredient_concern:
            recommendations.append(
                "The ingredient list could not be confirmed. Ask your pharmacist to verify."
            )

        has_amr_concern = any(c["agent"] == 7 for c in concerns)
        if has_amr_concern:
            recommendations.append(
                "This is a restricted antibiotic. Ensure you have a valid prescription "
                "and complete the full course as directed."
            )

        has_adr_signal = any(c["agent"] == 9 for c in concerns)
        if has_adr_signal:
            recommendations.append(
                "A safety signal has been flagged for this medicine. "
                "Monitor for adverse reactions and report any to your doctor."
            )

        has_suspicious_price = any(
            c["agent"] == 5 and "counterfeit" in c.get("title", "").lower()
            for c in concerns
        )
        if has_suspicious_price:
            recommendations.append(
                "The price of this medicine is unusually low. "
                "This can indicate a counterfeit or substandard product in Pakistan. "
                "Verify the source and purchase only from licensed pharmacies."
            )

    else:  # VERIFIED
        recommendations.append(
            "This medicine appears genuine. Always purchase from licensed pharmacies."
        )

        # Still add minor guidance if relevant
        a7 = agent_map.get(7)
        if a7 and a7.get("is_antibiotic"):
            recommendations.append(
                "This is an antibiotic. Complete the full prescribed course even if you feel better. "
                "Do not share antibiotics with others."
            )

        a10 = agent_map.get(10)
        if a10 and a10.get("interaction_found"):
            severity = (a10.get("highest_severity") or "").upper()
            if severity in ("MODERATE", "MINOR"):
                recommendations.append(
                    "Minor/moderate drug interactions were detected. "
                    "Inform your doctor about all medicines you are taking."
                )

    return recommendations


# ===================================================================
# Consumer message generation
# ===================================================================

def _generate_consumer_message(
    verdict: str,
    concerns: list[dict],
    safety_alerts: list[dict],
    risk_score: int,
    agent_results: list[dict],
) -> str:
    """Generate a clear, actionable consumer message based on the full analysis."""

    if verdict == "VERIFIED":
        msg = (
            "This medicine appears to be GENUINE. All verification and safety checks "
            "passed successfully. Registration, barcode, recall status, ingredients, "
            "and drug safety have been verified."
        )
        # Mention any low-severity notes
        minor_notes = [c for c in concerns if c["severity"] in (SEVERITY_LOW, SEVERITY_MEDIUM)]
        if minor_notes:
            msg += "\n\nMinor notes:"
            for note in minor_notes:
                msg += f"\n- {note['title']}"
        msg += "\n\nAlways purchase medicines from licensed pharmacies."
        return msg

    elif verdict == "DANGER":
        msg = "WARNING: This medicine has FAILED critical safety checks!\n\nIssues found:"
        for alert in safety_alerts:
            msg += f"\n- [{alert['severity']}] {alert['title']}"
            if alert.get("detail"):
                # Truncate long details for consumer readability
                detail = alert["detail"]
                if len(detail) > 200:
                    detail = detail[:197] + "..."
                msg += f"\n  {detail}"
        msg += (
            "\n\nDo NOT use this medicine. Contact your doctor or pharmacist immediately. "
            "Report suspicious medicines to DRAP at 0800-02345."
        )
        return msg

    else:  # UNVERIFIED
        msg = (
            "This medicine could NOT be fully verified. "
            "Some checks were inconclusive or raised concerns.\n\nConcerns:"
        )
        for c in concerns:
            msg += f"\n- [{c['severity']}] {c['title']}"
        risk_band = _get_risk_band(risk_score)
        msg += (
            f"\n\nRisk Level: {risk_band['level']} ({risk_score}/100). "
            f"{risk_band['advice']}."
        )
        msg += (
            "\n\nConsult your pharmacist before using. If in doubt, request an alternative "
            "from a different manufacturer."
        )
        return msg


# ===================================================================
# Detailed analysis builder
# ===================================================================

def _build_detailed_analysis(agent_results: list[dict]) -> dict:
    """
    Build a structured detailed analysis dict with per-agent breakdown.
    Useful for the app's expanded view or PDF report.
    """
    agent_map = {r.get("agent_number"): r for r in agent_results if r.get("agent_number") != AGENT_NUMBER}

    core_verification = {}
    safety_layer = {}

    # Core agents (1-5)
    agent_labels = {
        1: "registration",
        2: "barcode",
        3: "recall_status",
        4: "ingredients",
        5: "price",
    }
    for num, key in agent_labels.items():
        a = agent_map.get(num)
        if a:
            core_verification[key] = {
                "status": a.get("status", "UNCERTAIN"),
                "confidence": a.get("confidence_score", 0.0),
                "message": a.get("display_message", ""),
            }

    # Safety agents (7-10)
    safety_labels = {
        7: "amr_guard",
        8: "pediatric_safety",
        9: "adr_reporter",
        10: "drug_interactions",
    }
    for num, key in safety_labels.items():
        a = agent_map.get(num)
        if a:
            entry: dict = {
                "status": a.get("status", "UNCERTAIN"),
                "confidence": a.get("confidence_score", 0.0),
                "message": a.get("display_message", ""),
            }
            # Add agent-specific extra fields
            if num == 7:
                entry["is_antibiotic"] = a.get("is_antibiotic", False)
                entry["aware_classification"] = a.get("aware_classification")
                entry["resistance_risk"] = a.get("resistance_risk")
            elif num == 8:
                entry["is_safe_for_child"] = a.get("is_safe_for_child")
                entry["recommended_dose"] = a.get("recommended_dose")
                entry["contraindications"] = a.get("contraindications", [])
            elif num == 9:
                entry["signal_triggered"] = a.get("signal_triggered", False)
                entry["report_id"] = a.get("report_id")
            elif num == 10:
                entry["interaction_found"] = a.get("interaction_found", False)
                entry["highest_severity"] = a.get("highest_severity")
                entry["total_interactions"] = a.get("total_interactions", 0)
                entry["interactions"] = a.get("interactions", [])

            safety_layer[key] = entry

    return {
        "core_verification": core_verification,
        "safety_layer": safety_layer,
    }


# ===================================================================
# Main entry point
# ===================================================================

def synthesize_verdict(agent_results: list[dict]) -> dict:
    """
    Main entry point for Agent 6.

    Synthesizes results from ALL available agents (1-5 core + 7-10 safety)
    into a single comprehensive verdict.

    Three-tier verdict logic:
    - VERIFIED:   All core agents PASS + no safety agent FAIL/CRITICAL
    - DANGER:     Any critical agent FAIL (1=unregistered, 3=recalled,
                  8=unsafe for child, 10=contraindicated/major interaction)
                  OR AMR RESERVE without prescription context
    - UNVERIFIED: Mixed results, cannot fully confirm safety

    Args:
        agent_results: List of result dicts from any/all agents (1-5, 7-10).
                       Agent 6 results (if present) are ignored.

    Returns:
        Standardized agent result dict with overall verdict, risk score,
        safety alerts, recommendations, and detailed analysis.
    """
    result: dict = {
        "agent_number": AGENT_NUMBER,
        "agent_name": AGENT_NAME,
        "status": "PASS",
        "overall_verdict": "UNVERIFIED",
        "confidence_score": 0.0,
        "risk_score": 0,
        "risk_level": "UNKNOWN",
        "verdict_summary": {},
        "consumer_message": "",
        "display_message": "",
        "safety_alerts": [],
        "recommendations": [],
        "detailed_analysis": {},
        "fail_reason": None,
    }

    try:
        if not agent_results:
            result["overall_verdict"] = "UNVERIFIED"
            result["confidence_score"] = 0.0
            result["risk_score"] = 50
            result["risk_level"] = "MODERATE"
            result["consumer_message"] = "No agent results available for verdict."
            result["display_message"] = "Insufficient data to determine verdict."
            result["recommendations"] = [
                "Could not analyze this medicine. Please try scanning again with better lighting."
            ]
            return result

        # Filter out any existing Agent 6 results to avoid self-reference
        filtered_results = [r for r in agent_results if r.get("agent_number") != AGENT_NUMBER]

        if not filtered_results:
            result["overall_verdict"] = "UNVERIFIED"
            result["status"] = "UNCERTAIN"
            result["confidence_score"] = 0.0
            result["risk_score"] = 50
            result["risk_level"] = "MODERATE"
            result["consumer_message"] = "No agent results available for verdict."
            result["display_message"] = "Insufficient data to determine verdict."
            result["recommendations"] = [
                "Could not analyze this medicine. Please try scanning again with better lighting."
            ]
            return result

        # ── 1. Categorize agent statuses ─────────────────────────────
        statuses: dict[str, list[dict]] = {"PASS": [], "FAIL": [], "UNCERTAIN": []}
        for res in filtered_results:
            status = res.get("status", "UNCERTAIN")
            statuses.setdefault(status, []).append(res)

        # ── 2. Build verdict summary ─────────────────────────────────
        result["verdict_summary"] = {
            "total_agents": len(filtered_results),
            "passed": len(statuses.get("PASS", [])),
            "failed": len(statuses.get("FAIL", [])),
            "uncertain": len(statuses.get("UNCERTAIN", [])),
            "agent_details": [
                {
                    "agent_number": r.get("agent_number"),
                    "agent_name": r.get("agent_name"),
                    "status": r.get("status"),
                    "confidence": r.get("confidence_score"),
                }
                for r in filtered_results
            ],
        }

        # ── 3. Extract concerns and safety alerts ────────────────────
        concerns = _extract_concerns(filtered_results)
        safety_alerts = _build_safety_alerts(concerns)
        result["safety_alerts"] = safety_alerts

        # ── 4. Determine verdict ─────────────────────────────────────
        agent_map = {r.get("agent_number"): r for r in filtered_results}

        # Check for critical failures
        critical_fail = False
        critical_reasons: list[str] = []

        # Agent 1: Registration FAIL
        a1 = agent_map.get(1)
        if a1 and a1.get("status") == "FAIL":
            critical_fail = True
            critical_reasons.append("Medicine is not registered with DRAP")

        # Agent 3: Recall FAIL
        a3 = agent_map.get(3)
        if a3 and a3.get("status") == "FAIL":
            critical_fail = True
            critical_reasons.append("Medicine has been recalled")

        # Agent 8: Pediatric Safety FAIL (child is at risk)
        a8 = agent_map.get(8)
        if a8 and a8.get("status") == "FAIL":
            critical_fail = True
            critical_reasons.append("Medicine is unsafe for the specified child")

        # Agent 10: CONTRAINDICATED or MAJOR interaction
        a10 = agent_map.get(10)
        if a10 and a10.get("status") == "FAIL":
            highest = (a10.get("highest_severity") or "").upper()
            if highest in ("CONTRAINDICATED", "MAJOR"):
                critical_fail = True
                critical_reasons.append(
                    f"{highest} drug interaction detected with current medicines"
                )
            elif not highest:
                # Agent 10 returned FAIL but severity is missing/unknown --
                # treat conservatively as critical since Agent 10 is in CRITICAL_AGENTS
                critical_fail = True
                critical_reasons.append(
                    "Drug interaction check failed — severity could not be determined"
                )

        # Agent 7: RESERVE antibiotic triggers WARNING (upgrades to UNVERIFIED at minimum)
        a7 = agent_map.get(7)
        amr_reserve_warning = False
        if a7 and a7.get("is_antibiotic"):
            classification = (a7.get("aware_classification") or "").upper()
            if classification == "RESERVE":
                amr_reserve_warning = True

        # Agent 9: ADR signal_triggered adds a warning
        a9 = agent_map.get(9)
        adr_signal_warning = a9.get("signal_triggered", False) if a9 else False

        # Check if all non-safety-layer agents passed
        core_agent_nums = {1, 2, 3, 4, 5}
        core_results = [r for r in filtered_results if r.get("agent_number") in core_agent_nums]
        all_core_passed = all(r.get("status") == "PASS" for r in core_results) if core_results else False

        # Safety layer pass check (agents 7-10 that are present)
        safety_agent_nums = {7, 8, 9, 10}
        safety_results = [r for r in filtered_results if r.get("agent_number") in safety_agent_nums]
        any_safety_fail = any(r.get("status") == "FAIL" for r in safety_results)

        # Determine the final verdict
        if critical_fail:
            result["overall_verdict"] = "DANGER"
            result["status"] = "FAIL"
            result["display_message"] = (
                "DANGER: Critical safety check(s) FAILED. "
                + "; ".join(critical_reasons) + "."
            )
        elif all_core_passed and not any_safety_fail and not amr_reserve_warning and not adr_signal_warning:
            result["overall_verdict"] = "VERIFIED"
            result["status"] = "PASS"
            result["display_message"] = (
                "All verification and safety checks passed. Medicine appears genuine and safe to use."
            )
        else:
            result["overall_verdict"] = "UNVERIFIED"
            result["status"] = "UNCERTAIN"
            # Build descriptive message
            parts: list[str] = []
            failed_names = ", ".join(
                r.get("agent_name", "?") for r in statuses.get("FAIL", [])
            )
            uncertain_names = ", ".join(
                r.get("agent_name", "?") for r in statuses.get("UNCERTAIN", [])
            )
            if failed_names:
                parts.append(f"Failed: {failed_names}")
            if uncertain_names:
                parts.append(f"Uncertain: {uncertain_names}")
            if amr_reserve_warning:
                parts.append("RESERVE antibiotic requires specialist prescription")
            if adr_signal_warning:
                parts.append("Adverse reaction safety signal detected")

            result["display_message"] = (
                "Could not fully verify. " + ". ".join(parts) + "."
                if parts
                else "Could not fully verify this medicine."
            )

        # ── 5. Calculate confidence ──────────────────────────────────
        result["confidence_score"] = _calculate_overall_confidence(filtered_results)

        # ── 6. Calculate risk score ──────────────────────────────────
        risk_score = _calculate_risk_score(filtered_results, concerns)
        result["risk_score"] = risk_score
        result["risk_level"] = _get_risk_band(risk_score)["level"]

        # ── 7. Build recommendations ─────────────────────────────────
        result["recommendations"] = _build_recommendations(
            result["overall_verdict"], concerns, filtered_results
        )

        # ── 8. Build detailed analysis ───────────────────────────────
        result["detailed_analysis"] = _build_detailed_analysis(filtered_results)

        # ── 9. Generate consumer message ─────────────────────────────
        result["consumer_message"] = _generate_consumer_message(
            result["overall_verdict"],
            concerns,
            safety_alerts,
            risk_score,
            filtered_results,
        )

    except Exception as exc:  # noqa: BLE001
        logger.error("Error synthesizing verdict: %s", exc, exc_info=True)
        result["overall_verdict"] = "UNVERIFIED"
        result["confidence_score"] = 0.0
        result["risk_score"] = 50
        result["risk_level"] = "MODERATE"
        result["fail_reason"] = f"Error synthesizing verdict: {exc}"
        result["display_message"] = "An error occurred while determining the verdict."
        result["consumer_message"] = (
            "We could not determine the authenticity of this medicine due to a system error. "
            "Please consult your pharmacist."
        )
        result["recommendations"] = [
            "A system error occurred. Please try scanning again or consult your pharmacist."
        ]

    return result
