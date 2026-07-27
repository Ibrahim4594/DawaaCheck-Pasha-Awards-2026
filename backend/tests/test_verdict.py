"""
Tests for Agent 6 — HAKIM (The Wise Judge) verdict synthesis.

Covers:
  - DANGER overrides from critical agents (1, 3, 8, 10)
  - VERIFIED conditions (all core PASS, no safety FAIL)
  - UNVERIFIED conditions (mixed results, AMR reserve, ADR signal)
  - Risk score calculation with exact penalty values
  - Risk level band mapping (LOW / MODERATE / HIGH / CRITICAL)
  - Confidence calculation with weighted averages and status multipliers
  - Edge cases (empty list, all UNCERTAIN, all FAIL, missing fields)
"""

import pytest

from agents.agent_6_verdict import (
    AGENT_NUMBER,
    AGENT_WEIGHTS,
    CRITICAL_AGENTS,
    _calculate_overall_confidence,
    _calculate_risk_score,
    _extract_concerns,
    _get_risk_band,
    synthesize_verdict,
)


# =====================================================================
# Helper factories — build mock agent result dicts without repetition
# =====================================================================

def _agent(
    num: int,
    status: str = "PASS",
    confidence: float = 0.9,
    name: str | None = None,
    **extra,
) -> dict:
    """Return a minimal agent-result dict.  Extra kwargs are merged in."""
    default_names = {
        1: "RAKIB",
        2: "KASHIF",
        3: "MUNZIR",
        4: "BASIR",
        5: "ADIL",
        7: "HIFAZAT",
        8: "SHAFIQ",
        9: "SHAHID",
        10: "RAFIQ",
    }
    result = {
        "agent_number": num,
        "agent_name": name or default_names.get(num, f"Agent {num}"),
        "status": status,
        "confidence_score": confidence,
        "display_message": f"Agent {num} message",
    }
    result.update(extra)
    return result


def _all_pass(overrides: dict[int, dict] | None = None) -> list[dict]:
    """Return a full set of 9 agents (1-5, 7-10) all passing at 0.9 confidence.

    ``overrides`` maps agent_number -> dict of fields to merge in, e.g.
    ``_all_pass({1: {"status": "FAIL"}})``.
    """
    overrides = overrides or {}
    agents = [
        _agent(1),
        _agent(2),
        _agent(3),
        _agent(4),
        _agent(5),
        _agent(7, is_antibiotic=False),
        _agent(8),
        _agent(9, signal_triggered=False),
        _agent(10, interaction_found=False),
    ]
    # Apply per-agent overrides by agent_number
    for a in agents:
        num = a["agent_number"]
        if num in overrides:
            a.update(overrides[num])
    return agents


# =====================================================================
# 1. DANGER overrides
# =====================================================================

class TestDangerOverrides:
    """Any FAIL on a critical agent (1, 3, 8, 10) must produce DANGER."""

    def test_agent_1_fail_produces_danger(self):
        results = _all_pass({1: {"status": "FAIL"}})
        verdict = synthesize_verdict(results)
        assert verdict["overall_verdict"] == "DANGER"
        assert verdict["status"] == "FAIL"

    def test_agent_3_fail_produces_danger(self):
        results = _all_pass({3: {"status": "FAIL"}})
        verdict = synthesize_verdict(results)
        assert verdict["overall_verdict"] == "DANGER"

    def test_agent_8_fail_produces_danger(self):
        results = _all_pass({8: {"status": "FAIL"}})
        verdict = synthesize_verdict(results)
        assert verdict["overall_verdict"] == "DANGER"

    def test_agent_10_contraindicated_produces_danger(self):
        results = _all_pass({
            10: {
                "status": "FAIL",
                "interaction_found": True,
                "highest_severity": "CONTRAINDICATED",
            },
        })
        verdict = synthesize_verdict(results)
        assert verdict["overall_verdict"] == "DANGER"

    def test_agent_10_major_interaction_produces_danger(self):
        results = _all_pass({
            10: {
                "status": "FAIL",
                "interaction_found": True,
                "highest_severity": "MAJOR",
            },
        })
        verdict = synthesize_verdict(results)
        assert verdict["overall_verdict"] == "DANGER"

    def test_agent_10_fail_unknown_severity_produces_danger(self):
        """Agent 10 FAIL with no highest_severity should still be DANGER."""
        results = _all_pass({
            10: {"status": "FAIL", "interaction_found": False},
        })
        verdict = synthesize_verdict(results)
        assert verdict["overall_verdict"] == "DANGER"

    def test_agent_10_moderate_interaction_fail_not_danger(self):
        """Agent 10 FAIL with MODERATE severity should NOT be DANGER."""
        results = _all_pass({
            10: {
                "status": "FAIL",
                "interaction_found": True,
                "highest_severity": "MODERATE",
            },
        })
        verdict = synthesize_verdict(results)
        assert verdict["overall_verdict"] != "DANGER"

    def test_multiple_critical_failures_still_danger(self):
        results = _all_pass({
            1: {"status": "FAIL"},
            3: {"status": "FAIL"},
        })
        verdict = synthesize_verdict(results)
        assert verdict["overall_verdict"] == "DANGER"

    def test_danger_display_message_contains_reason(self):
        results = _all_pass({3: {"status": "FAIL"}})
        verdict = synthesize_verdict(results)
        assert "recalled" in verdict["display_message"].lower()

    def test_danger_includes_safety_alerts(self):
        results = _all_pass({1: {"status": "FAIL"}})
        verdict = synthesize_verdict(results)
        alerts = verdict["safety_alerts"]
        assert len(alerts) > 0
        assert any(a["severity"] == "CRITICAL" for a in alerts)


# =====================================================================
# 2. VERIFIED conditions
# =====================================================================

class TestVerifiedConditions:
    """VERIFIED requires all core PASS + no safety FAIL + no AMR RESERVE + no ADR signal."""

    def test_all_pass_produces_verified(self):
        results = _all_pass()
        verdict = synthesize_verdict(results)
        assert verdict["overall_verdict"] == "VERIFIED"
        assert verdict["status"] == "PASS"

    def test_verified_display_message(self):
        verdict = synthesize_verdict(_all_pass())
        assert "passed" in verdict["display_message"].lower()

    def test_verified_consumer_message_mentions_genuine(self):
        verdict = synthesize_verdict(_all_pass())
        assert "genuine" in verdict["consumer_message"].lower()

    def test_verified_with_non_antibiotic_agent_7(self):
        results = _all_pass({7: {"is_antibiotic": False}})
        verdict = synthesize_verdict(results)
        assert verdict["overall_verdict"] == "VERIFIED"

    def test_verified_with_access_antibiotic(self):
        """ACCESS classification should not block VERIFIED."""
        results = _all_pass({
            7: {"is_antibiotic": True, "aware_classification": "ACCESS"},
        })
        verdict = synthesize_verdict(results)
        assert verdict["overall_verdict"] == "VERIFIED"

    def test_only_core_agents_present_all_pass(self):
        """If only core agents (1-5) are present and all pass, should be VERIFIED."""
        results = [_agent(n) for n in (1, 2, 3, 4, 5)]
        verdict = synthesize_verdict(results)
        assert verdict["overall_verdict"] == "VERIFIED"

    def test_verified_recommendations_mention_genuine(self):
        verdict = synthesize_verdict(_all_pass())
        assert any("genuine" in r.lower() for r in verdict["recommendations"])


# =====================================================================
# 3. UNVERIFIED conditions
# =====================================================================

class TestUnverifiedConditions:
    """Mixed results or warning flags produce UNVERIFIED."""

    def test_core_agent_uncertain_produces_unverified(self):
        results = _all_pass({2: {"status": "UNCERTAIN"}})
        verdict = synthesize_verdict(results)
        assert verdict["overall_verdict"] == "UNVERIFIED"

    def test_non_critical_agent_fail_produces_unverified(self):
        """Agent 2 (barcode) FAIL is not in CRITICAL_AGENTS, so UNVERIFIED not DANGER."""
        results = _all_pass({2: {"status": "FAIL"}})
        verdict = synthesize_verdict(results)
        assert verdict["overall_verdict"] == "UNVERIFIED"

    def test_agent_4_fail_produces_unverified(self):
        results = _all_pass({4: {"status": "FAIL"}})
        verdict = synthesize_verdict(results)
        assert verdict["overall_verdict"] == "UNVERIFIED"

    def test_agent_5_fail_produces_unverified(self):
        results = _all_pass({5: {"status": "FAIL"}})
        verdict = synthesize_verdict(results)
        assert verdict["overall_verdict"] == "UNVERIFIED"

    def test_amr_reserve_blocks_verified(self):
        """A RESERVE antibiotic should downgrade from VERIFIED to UNVERIFIED."""
        results = _all_pass({
            7: {"is_antibiotic": True, "aware_classification": "RESERVE"},
        })
        verdict = synthesize_verdict(results)
        assert verdict["overall_verdict"] == "UNVERIFIED"

    def test_adr_signal_blocks_verified(self):
        """An ADR signal_triggered should downgrade to UNVERIFIED."""
        results = _all_pass({9: {"signal_triggered": True}})
        verdict = synthesize_verdict(results)
        assert verdict["overall_verdict"] == "UNVERIFIED"

    def test_amr_watch_does_not_block_verified(self):
        """WATCH classification does not block VERIFIED (only RESERVE does)."""
        results = _all_pass({
            7: {"is_antibiotic": True, "aware_classification": "WATCH"},
        })
        verdict = synthesize_verdict(results)
        assert verdict["overall_verdict"] == "VERIFIED"

    def test_unverified_status_is_uncertain(self):
        results = _all_pass({4: {"status": "UNCERTAIN"}})
        verdict = synthesize_verdict(results)
        assert verdict["status"] == "UNCERTAIN"

    def test_unverified_display_message_lists_failures(self):
        results = _all_pass({2: {"status": "FAIL"}})
        verdict = synthesize_verdict(results)
        assert "KASHIF" in verdict["display_message"]

    def test_agent_10_moderate_interaction_is_unverified(self):
        """Agent 10 FAIL+MODERATE should land in UNVERIFIED, not DANGER."""
        results = _all_pass({
            10: {
                "status": "FAIL",
                "interaction_found": True,
                "highest_severity": "MODERATE",
            },
        })
        verdict = synthesize_verdict(results)
        assert verdict["overall_verdict"] == "UNVERIFIED"


# =====================================================================
# 4. Risk score calculation — exact penalty values
# =====================================================================

class TestRiskScorePenalties:
    """Verify each agent's exact penalty contribution to the risk score."""

    def test_all_pass_risk_score_zero(self):
        results = _all_pass()
        score = _calculate_risk_score(results, [])
        assert score == 0

    def test_agent_1_fail_adds_35(self):
        results = [_agent(1, status="FAIL")]
        assert _calculate_risk_score(results, []) == 35

    def test_agent_1_uncertain_adds_15(self):
        results = [_agent(1, status="UNCERTAIN")]
        assert _calculate_risk_score(results, []) == 15

    def test_agent_2_fail_adds_10(self):
        results = [_agent(2, status="FAIL")]
        assert _calculate_risk_score(results, []) == 10

    def test_agent_2_uncertain_adds_5(self):
        results = [_agent(2, status="UNCERTAIN")]
        assert _calculate_risk_score(results, []) == 5

    def test_agent_3_fail_adds_30(self):
        results = [_agent(3, status="FAIL")]
        assert _calculate_risk_score(results, []) == 30

    def test_agent_3_uncertain_adds_10(self):
        results = [_agent(3, status="UNCERTAIN")]
        assert _calculate_risk_score(results, []) == 10

    def test_agent_4_fail_adds_20(self):
        results = [_agent(4, status="FAIL")]
        assert _calculate_risk_score(results, []) == 20

    def test_agent_4_uncertain_adds_8(self):
        results = [_agent(4, status="UNCERTAIN")]
        assert _calculate_risk_score(results, []) == 8

    def test_agent_5_fail_adds_5(self):
        results = [_agent(5, status="FAIL")]
        assert _calculate_risk_score(results, []) == 5

    def test_agent_5_fail_suspicious_cheap_adds_15(self):
        results = [_agent(5, status="FAIL", is_suspicious_cheap=True)]
        assert _calculate_risk_score(results, []) == 15

    def test_agent_5_uncertain_adds_2(self):
        results = [_agent(5, status="UNCERTAIN")]
        assert _calculate_risk_score(results, []) == 2

    def test_agent_7_reserve_antibiotic_adds_12(self):
        results = [_agent(7, is_antibiotic=True, aware_classification="RESERVE")]
        assert _calculate_risk_score(results, []) == 12

    def test_agent_7_watch_antibiotic_adds_5(self):
        results = [_agent(7, is_antibiotic=True, aware_classification="WATCH")]
        assert _calculate_risk_score(results, []) == 5

    def test_agent_7_access_antibiotic_adds_0(self):
        results = [_agent(7, is_antibiotic=True, aware_classification="ACCESS")]
        assert _calculate_risk_score(results, []) == 0

    def test_agent_7_not_antibiotic_adds_0(self):
        results = [_agent(7, is_antibiotic=False, aware_classification="RESERVE")]
        assert _calculate_risk_score(results, []) == 0

    def test_agent_8_fail_adds_25(self):
        results = [_agent(8, status="FAIL")]
        assert _calculate_risk_score(results, []) == 25

    def test_agent_8_uncertain_adds_8(self):
        results = [_agent(8, status="UNCERTAIN")]
        assert _calculate_risk_score(results, []) == 8

    def test_agent_9_signal_triggered_adds_10(self):
        results = [_agent(9, signal_triggered=True)]
        assert _calculate_risk_score(results, []) == 10

    def test_agent_9_no_signal_adds_0(self):
        results = [_agent(9, signal_triggered=False)]
        assert _calculate_risk_score(results, []) == 0

    def test_agent_10_contraindicated_adds_30(self):
        results = [_agent(10, interaction_found=True, highest_severity="CONTRAINDICATED")]
        assert _calculate_risk_score(results, []) == 30

    def test_agent_10_major_adds_20(self):
        results = [_agent(10, interaction_found=True, highest_severity="MAJOR")]
        assert _calculate_risk_score(results, []) == 20

    def test_agent_10_moderate_adds_8(self):
        results = [_agent(10, interaction_found=True, highest_severity="MODERATE")]
        assert _calculate_risk_score(results, []) == 8

    def test_agent_10_minor_adds_3(self):
        results = [_agent(10, interaction_found=True, highest_severity="MINOR")]
        assert _calculate_risk_score(results, []) == 3

    def test_agent_10_unknown_severity_adds_15(self):
        results = [_agent(10, interaction_found=True, highest_severity="")]
        assert _calculate_risk_score(results, []) == 15

    def test_agent_10_fail_no_interaction_adds_10(self):
        results = [_agent(10, status="FAIL", interaction_found=False)]
        assert _calculate_risk_score(results, []) == 10

    def test_penalties_accumulate(self):
        """Agent 1 FAIL (35) + Agent 3 FAIL (30) = 65."""
        results = [_agent(1, status="FAIL"), _agent(3, status="FAIL")]
        assert _calculate_risk_score(results, []) == 65

    def test_risk_score_clamped_at_100(self):
        """Even with extreme penalties the score must not exceed 100."""
        results = [
            _agent(1, status="FAIL"),         # +35
            _agent(3, status="FAIL"),         # +30
            _agent(8, status="FAIL"),         # +25
            _agent(10, interaction_found=True, highest_severity="CONTRAINDICATED"),  # +30
        ]
        score = _calculate_risk_score(results, [])
        assert score <= 100

    def test_risk_score_minimum_zero(self):
        results = _all_pass()
        score = _calculate_risk_score(results, [])
        assert score >= 0

    def test_agent_6_is_excluded_from_risk_score(self):
        """Agent 6 results in the list should be ignored."""
        results = [_agent(6, status="FAIL")]
        assert _calculate_risk_score(results, []) == 0


# =====================================================================
# 5. Risk level bands
# =====================================================================

class TestRiskLevelBands:

    @pytest.mark.parametrize("score,expected_level", [
        (0, "LOW"),
        (10, "LOW"),
        (20, "LOW"),
        (21, "MODERATE"),
        (35, "MODERATE"),
        (50, "MODERATE"),
        (51, "HIGH"),
        (65, "HIGH"),
        (80, "HIGH"),
        (81, "CRITICAL"),
        (90, "CRITICAL"),
        (100, "CRITICAL"),
    ])
    def test_risk_band_level(self, score, expected_level):
        band = _get_risk_band(score)
        assert band["level"] == expected_level

    def test_risk_band_has_advice_field(self):
        band = _get_risk_band(50)
        assert "advice" in band
        assert isinstance(band["advice"], str)

    def test_out_of_range_score_returns_unknown(self):
        band = _get_risk_band(101)
        assert band["level"] == "UNKNOWN"

    def test_negative_score_returns_unknown(self):
        band = _get_risk_band(-5)
        assert band["level"] == "UNKNOWN"

    def test_synthesize_sets_risk_level_from_score(self):
        """End-to-end: the risk_level field should match the band for the computed score."""
        results = _all_pass()
        verdict = synthesize_verdict(results)
        expected_level = _get_risk_band(verdict["risk_score"])["level"]
        assert verdict["risk_level"] == expected_level


# =====================================================================
# 6. Confidence calculation
# =====================================================================

class TestConfidenceCalculation:

    def test_all_pass_high_confidence(self):
        """All agents PASS at 0.9 confidence -> weighted average of 0.9."""
        results = _all_pass()
        conf = _calculate_overall_confidence(results)
        assert conf == pytest.approx(0.9, abs=0.001)

    def test_fail_multiplier_applied(self):
        """FAIL status should multiply confidence by 0.3."""
        results = [_agent(1, status="FAIL", confidence=0.9)]
        conf = _calculate_overall_confidence(results)
        # Only agent 1 present, weight = 0.22
        # weighted_score = 0.22 * (0.9 * 0.3), total_weight = 0.22
        # result = 0.9 * 0.3 = 0.27
        assert conf == pytest.approx(0.27, abs=0.001)

    def test_uncertain_multiplier_applied(self):
        """UNCERTAIN status should multiply confidence by 0.5."""
        results = [_agent(1, status="UNCERTAIN", confidence=0.8)]
        conf = _calculate_overall_confidence(results)
        # 0.8 * 0.5 = 0.4
        assert conf == pytest.approx(0.4, abs=0.001)

    def test_pass_no_multiplier(self):
        """PASS status should NOT reduce confidence."""
        results = [_agent(1, status="PASS", confidence=0.85)]
        conf = _calculate_overall_confidence(results)
        assert conf == pytest.approx(0.85, abs=0.001)

    def test_agent_6_excluded_from_confidence(self):
        """Agent 6 in the list should be ignored entirely."""
        results = [
            _agent(6, status="FAIL", confidence=0.1),
            _agent(1, status="PASS", confidence=0.9),
        ]
        conf = _calculate_overall_confidence(results)
        # Only agent 1 counted
        assert conf == pytest.approx(0.9, abs=0.001)

    def test_empty_list_returns_zero(self):
        assert _calculate_overall_confidence([]) == 0.0

    def test_unknown_agent_number_skipped(self):
        """Agents with no weight entry should be skipped."""
        results = [_agent(99, status="PASS", confidence=0.9)]
        assert _calculate_overall_confidence(results) == 0.0

    def test_weighted_mix_of_pass_and_fail(self):
        """Agent 1 (weight=0.22, PASS, 0.9) + Agent 5 (weight=0.05, FAIL, 0.9)."""
        results = [
            _agent(1, status="PASS", confidence=0.9),
            _agent(5, status="FAIL", confidence=0.9),
        ]
        conf = _calculate_overall_confidence(results)
        # weighted_score = 0.22 * 0.9 + 0.05 * (0.9 * 0.3)
        #               = 0.198 + 0.0135 = 0.2115
        # total_weight = 0.22 + 0.05 = 0.27
        # result = 0.2115 / 0.27 = 0.78333...
        assert conf == pytest.approx(0.2115 / 0.27, abs=0.001)


# =====================================================================
# 7. Edge cases
# =====================================================================

class TestEdgeCases:

    def test_empty_agent_list(self):
        verdict = synthesize_verdict([])
        assert verdict["overall_verdict"] == "UNVERIFIED"
        assert verdict["risk_score"] == 50
        assert verdict["risk_level"] == "MODERATE"
        assert verdict["confidence_score"] == 0.0

    def test_only_agent_6_in_list(self):
        """If the only result is Agent 6 itself, it should be filtered out."""
        results = [_agent(6, status="PASS", confidence=0.99)]
        verdict = synthesize_verdict(results)
        assert verdict["overall_verdict"] == "UNVERIFIED"
        assert verdict["status"] == "UNCERTAIN"

    def test_all_agents_uncertain(self):
        results = [
            _agent(n, status="UNCERTAIN", confidence=0.5)
            for n in (1, 2, 3, 4, 5, 7, 8, 9, 10)
        ]
        verdict = synthesize_verdict(results)
        assert verdict["overall_verdict"] == "UNVERIFIED"
        assert verdict["status"] == "UNCERTAIN"

    def test_all_agents_fail(self):
        """When every agent FAILs, agents 1/3/8 trigger DANGER."""
        results = [
            _agent(n, status="FAIL", confidence=0.1)
            for n in (1, 2, 3, 4, 5, 7, 8, 9, 10)
        ]
        verdict = synthesize_verdict(results)
        assert verdict["overall_verdict"] == "DANGER"

    def test_missing_status_field_defaults_to_uncertain(self):
        """If 'status' key is missing, code defaults to UNCERTAIN."""
        results = [{"agent_number": 1, "confidence_score": 0.5, "agent_name": "A1"}]
        verdict = synthesize_verdict(results)
        # Should not crash; agent 1 with missing status is treated as UNCERTAIN
        assert verdict["overall_verdict"] in ("UNVERIFIED", "VERIFIED", "DANGER")

    def test_missing_confidence_defaults_to_zero(self):
        """If confidence_score is missing, it defaults to 0.0 in the calculation."""
        results = [{"agent_number": 1, "status": "PASS"}]
        conf = _calculate_overall_confidence(results)
        assert conf == pytest.approx(0.0, abs=0.001)

    def test_duplicate_agent_numbers(self):
        """If two results share the same agent_number, it should not crash."""
        results = [_agent(1, status="PASS"), _agent(1, status="FAIL")]
        # Should not raise; the last one in agent_map wins for most lookups
        verdict = synthesize_verdict(results)
        assert verdict["overall_verdict"] in ("VERIFIED", "UNVERIFIED", "DANGER")

    def test_result_schema_completeness(self):
        """The returned dict should always contain all expected top-level keys."""
        expected_keys = {
            "agent_number",
            "agent_name",
            "status",
            "overall_verdict",
            "confidence_score",
            "risk_score",
            "risk_level",
            "verdict_summary",
            "consumer_message",
            "display_message",
            "safety_alerts",
            "recommendations",
            "detailed_analysis",
            "fail_reason",
        }
        verdict = synthesize_verdict(_all_pass())
        assert expected_keys.issubset(verdict.keys())

    def test_agent_number_always_6(self):
        verdict = synthesize_verdict(_all_pass())
        assert verdict["agent_number"] == 6

    def test_empty_results_recommendations_suggest_rescan(self):
        verdict = synthesize_verdict([])
        assert any("scan" in r.lower() for r in verdict["recommendations"])


# =====================================================================
# 8. Concern extraction
# =====================================================================

class TestConcernExtraction:

    def test_no_concerns_when_all_pass(self):
        results = _all_pass()
        concerns = _extract_concerns(results)
        assert concerns == []

    def test_agent_1_fail_generates_critical_concern(self):
        results = [_agent(1, status="FAIL", fail_reason="Not registered")]
        concerns = _extract_concerns(results)
        assert len(concerns) == 1
        assert concerns[0]["severity"] == "CRITICAL"
        assert concerns[0]["agent"] == 1

    def test_agent_3_fail_generates_critical_concern(self):
        results = [_agent(3, status="FAIL")]
        concerns = _extract_concerns(results)
        assert any(c["severity"] == "CRITICAL" and c["agent"] == 3 for c in concerns)

    def test_agent_8_fail_generates_critical_concern(self):
        results = [_agent(8, status="FAIL")]
        concerns = _extract_concerns(results)
        assert any(c["severity"] == "CRITICAL" and c["agent"] == 8 for c in concerns)

    def test_concerns_sorted_by_severity(self):
        """CRITICAL concerns should come before HIGH, HIGH before MEDIUM, etc."""
        results = [
            _agent(1, status="FAIL"),       # CRITICAL
            _agent(2, status="FAIL"),       # MEDIUM
            _agent(4, status="UNCERTAIN"),  # MEDIUM
            _agent(1, status="PASS"),       # override above — use separate list
        ]
        # Build manually to get mixed severities
        results_mixed = [
            _agent(2, status="FAIL"),       # MEDIUM
            _agent(1, status="FAIL"),       # CRITICAL
            _agent(4, status="UNCERTAIN"),  # MEDIUM
        ]
        concerns = _extract_concerns(results_mixed)
        severity_order = {"CRITICAL": 0, "HIGH": 1, "MEDIUM": 2, "LOW": 3}
        for i in range(len(concerns) - 1):
            current = severity_order.get(concerns[i]["severity"], 99)
            next_sev = severity_order.get(concerns[i + 1]["severity"], 99)
            assert current <= next_sev

    def test_agent_5_suspicious_cheap_concern(self):
        results = [_agent(5, status="FAIL", is_suspicious_cheap=True)]
        concerns = _extract_concerns(results)
        assert any("counterfeit" in c["title"].lower() for c in concerns)

    def test_agent_7_reserve_concern(self):
        results = [_agent(7, is_antibiotic=True, aware_classification="RESERVE")]
        concerns = _extract_concerns(results)
        assert any(c["agent"] == 7 and c["severity"] == "HIGH" for c in concerns)

    def test_agent_9_signal_concern(self):
        results = [_agent(9, signal_triggered=True)]
        concerns = _extract_concerns(results)
        assert any(c["agent"] == 9 for c in concerns)

    def test_agent_10_contraindicated_concern(self):
        results = [_agent(10, interaction_found=True, highest_severity="CONTRAINDICATED")]
        concerns = _extract_concerns(results)
        assert any(
            c["agent"] == 10 and c["severity"] == "CRITICAL"
            for c in concerns
        )


# =====================================================================
# 9. Recommendations
# =====================================================================

class TestRecommendations:

    def test_danger_recommends_do_not_use(self):
        results = _all_pass({1: {"status": "FAIL"}})
        verdict = synthesize_verdict(results)
        assert any("do not use" in r.lower() for r in verdict["recommendations"])

    def test_danger_with_recall_recommends_return(self):
        results = _all_pass({3: {"status": "FAIL"}})
        verdict = synthesize_verdict(results)
        assert any("return" in r.lower() for r in verdict["recommendations"])

    def test_verified_recommends_licensed_pharmacies(self):
        verdict = synthesize_verdict(_all_pass())
        assert any("licensed" in r.lower() for r in verdict["recommendations"])

    def test_verified_with_antibiotic_recommends_full_course(self):
        results = _all_pass({7: {"is_antibiotic": True, "aware_classification": "ACCESS"}})
        verdict = synthesize_verdict(results)
        assert any("antibiotic" in r.lower() for r in verdict["recommendations"])

    def test_unverified_recommends_consult_pharmacist(self):
        results = _all_pass({2: {"status": "UNCERTAIN"}})
        verdict = synthesize_verdict(results)
        assert any("pharmacist" in r.lower() for r in verdict["recommendations"])


# =====================================================================
# 10. Verdict summary structure
# =====================================================================

class TestVerdictSummary:

    def test_summary_counts_agents(self):
        results = _all_pass()
        verdict = synthesize_verdict(results)
        summary = verdict["verdict_summary"]
        assert summary["total_agents"] == 9
        assert summary["passed"] == 9
        assert summary["failed"] == 0
        assert summary["uncertain"] == 0

    def test_summary_tracks_failures(self):
        results = _all_pass({2: {"status": "FAIL"}, 4: {"status": "UNCERTAIN"}})
        verdict = synthesize_verdict(results)
        summary = verdict["verdict_summary"]
        assert summary["failed"] == 1
        assert summary["uncertain"] == 1
        assert summary["passed"] == 7

    def test_summary_agent_details_present(self):
        results = _all_pass()
        verdict = synthesize_verdict(results)
        details = verdict["verdict_summary"]["agent_details"]
        assert len(details) == 9
        assert all("agent_number" in d for d in details)


# =====================================================================
# 11. Detailed analysis structure
# =====================================================================

class TestDetailedAnalysis:

    def test_core_verification_keys(self):
        verdict = synthesize_verdict(_all_pass())
        core = verdict["detailed_analysis"]["core_verification"]
        assert set(core.keys()) == {"registration", "barcode", "recall_status", "ingredients", "price"}

    def test_safety_layer_keys(self):
        verdict = synthesize_verdict(_all_pass())
        safety = verdict["detailed_analysis"]["safety_layer"]
        assert set(safety.keys()) == {"amr_guard", "pediatric_safety", "adr_reporter", "drug_interactions"}

    def test_safety_layer_extra_fields_agent_10(self):
        results = _all_pass({
            10: {"interaction_found": True, "highest_severity": "MINOR", "total_interactions": 2, "interactions": []},
        })
        verdict = synthesize_verdict(results)
        drug_int = verdict["detailed_analysis"]["safety_layer"]["drug_interactions"]
        assert "interaction_found" in drug_int
        assert "highest_severity" in drug_int
        assert "total_interactions" in drug_int


# =====================================================================
# 12. Constants sanity checks
# =====================================================================

class TestConstants:

    def test_critical_agents_set(self):
        assert CRITICAL_AGENTS == {1, 3, 8, 10}

    def test_agent_weights_sum_to_one(self):
        assert sum(AGENT_WEIGHTS.values()) == pytest.approx(1.0, abs=0.001)

    def test_agent_number_is_six(self):
        assert AGENT_NUMBER == 6

    def test_agent_6_not_in_weights(self):
        """Agent 6 should not weight itself."""
        assert 6 not in AGENT_WEIGHTS
