"""
test_agent_contracts.py — Contract and unit tests for DawaaCheck agent pipeline.

Tests cover:
  1. Agent output contract (required keys and value types)
  2. _make_error_result factory function
  3. _AGENT_NAMES constant completeness
  4. _PIPELINE_TIMEOUT constant
  5. Agent 7 (HIFAZAT) unit tests with mocked Supabase
  6. sanitize_like SQL wildcard escaping

Third-party dependencies (anthropic, httpx, supabase) are stubbed via
sys.modules so the test file works without installing the full backend
requirements.  Only agent_7_amr.py and crew_config.py constants are
exercised — no network calls are made.
"""

import sys
import types
from unittest.mock import MagicMock

# ---------------------------------------------------------------------------
# Stub heavy third-party packages BEFORE importing any agent code.
# This prevents ImportError when anthropic / httpx / supabase are not
# installed in the test environment.
# ---------------------------------------------------------------------------

_THIRD_PARTY_STUBS = [
    "anthropic",
    "httpx",
    "supabase",
    "dotenv",
    "google",
    "google.auth",
    "google.auth.transport",
    "google.auth.transport.requests",
    "google.oauth2",
    "google.oauth2.id_token",
]

for _mod_name in _THIRD_PARTY_STUBS:
    if _mod_name not in sys.modules:
        sys.modules[_mod_name] = types.ModuleType(_mod_name)

# supabase.create_client and supabase.Client must be importable names
_supabase_stub = sys.modules["supabase"]
if not hasattr(_supabase_stub, "create_client"):
    _supabase_stub.create_client = MagicMock()  # type: ignore[attr-defined]
if not hasattr(_supabase_stub, "Client"):
    _supabase_stub.Client = MagicMock  # type: ignore[attr-defined]

# ---------------------------------------------------------------------------
# Now it is safe to import from the agents / utils packages.
# ---------------------------------------------------------------------------

import pytest  # noqa: E402
from unittest.mock import patch  # noqa: E402

from agents.crew_config import _AGENT_NAMES, _PIPELINE_TIMEOUT, _make_error_result  # noqa: E402
from agents.agent_7_amr import (  # noqa: E402
    AGENT_NAME as AMR_AGENT_NAME,
    AGENT_NUMBER as AMR_AGENT_NUMBER,
    PAKISTAN_RESISTANCE_STATS,
    _sanitize_like,
    check_amr,
)
from utils.supabase_client import sanitize_like as canonical_sanitize_like  # noqa: E402

# ---------------------------------------------------------------------------
# Shared helpers
# ---------------------------------------------------------------------------

VALID_STATUSES = {"PASS", "FAIL", "UNCERTAIN", "WARNING"}

REQUIRED_AGENT_KEYS = {
    "agent_number": int,
    "agent_name": str,
    "status": str,
    "confidence_score": float,
    "display_message": str,
    "fail_reason": (str, type(None)),
}


def assert_valid_agent_result(result: dict) -> None:
    """Assert that *result* satisfies the standard agent output contract."""
    for key, expected_type in REQUIRED_AGENT_KEYS.items():
        assert key in result, f"Missing required key: {key}"
        if isinstance(expected_type, tuple):
            assert isinstance(result[key], expected_type), (
                f"{key}: expected one of {expected_type}, got {type(result[key])}"
            )
        else:
            assert isinstance(result[key], expected_type), (
                f"{key}: expected {expected_type.__name__}, got {type(result[key]).__name__}"
            )

    assert result["status"] in VALID_STATUSES, (
        f"status must be one of {VALID_STATUSES}, got '{result['status']}'"
    )
    assert 0.0 <= result["confidence_score"] <= 1.0, (
        f"confidence_score must be 0.0-1.0, got {result['confidence_score']}"
    )


# ===========================================================================
# 1. _make_error_result factory
# ===========================================================================

class TestMakeErrorResult:
    """Tests for the standardized error result builder."""

    def test_returns_valid_agent_contract(self):
        result = _make_error_result(3, ValueError("test error"))
        assert_valid_agent_result(result)

    def test_status_is_uncertain(self):
        result = _make_error_result(1, RuntimeError("boom"))
        assert result["status"] == "UNCERTAIN"

    def test_confidence_is_zero(self):
        result = _make_error_result(5, Exception("fail"))
        assert result["confidence_score"] == 0.0

    def test_agent_number_matches(self):
        for num in range(1, 11):
            result = _make_error_result(num, Exception("err"))
            assert result["agent_number"] == num

    def test_agent_name_from_lookup(self):
        result = _make_error_result(7, Exception("err"))
        assert result["agent_name"] == _AGENT_NAMES[7]

    def test_unknown_agent_number_uses_fallback(self):
        result = _make_error_result(99, Exception("err"))
        assert result["agent_name"] == "Agent 99"

    def test_fail_reason_contains_exception_text(self):
        result = _make_error_result(1, ConnectionError("timeout talking to Supabase"))
        assert "timeout talking to Supabase" in result["fail_reason"]

    def test_display_message_contains_exception_text(self):
        result = _make_error_result(2, ValueError("bad image"))
        assert "bad image" in result["display_message"]

    def test_display_message_contains_agent_name(self):
        result = _make_error_result(6, Exception("x"))
        assert _AGENT_NAMES[6] in result["display_message"]


# ===========================================================================
# 2. _AGENT_NAMES constant
# ===========================================================================

class TestAgentNames:
    """Ensure _AGENT_NAMES covers all 10 agents."""

    def test_has_entries_for_agents_1_through_10(self):
        for i in range(1, 11):
            assert i in _AGENT_NAMES, f"Missing _AGENT_NAMES entry for agent {i}"

    def test_all_values_are_nonempty_strings(self):
        for num, name in _AGENT_NAMES.items():
            assert isinstance(name, str) and len(name) > 0, (
                f"Agent {num} name must be a non-empty string"
            )

    def test_no_extra_entries(self):
        assert set(_AGENT_NAMES.keys()) == set(range(1, 11))

    def test_each_name_contains_dash_separator(self):
        """Each name follows the 'NAME \u2014 The Title' pattern."""
        for num, name in _AGENT_NAMES.items():
            assert "\u2014" in name, (
                f"Agent {num} name should contain em-dash separator, got: {name!r}"
            )


# ===========================================================================
# 3. Pipeline timeout constant
# ===========================================================================

class TestPipelineTimeout:
    """Validate the pipeline timeout constant."""

    def test_pipeline_timeout_is_180(self):
        assert _PIPELINE_TIMEOUT == 180

    def test_pipeline_timeout_is_int(self):
        assert isinstance(_PIPELINE_TIMEOUT, int)

    def test_pipeline_timeout_is_positive(self):
        assert _PIPELINE_TIMEOUT > 0


# ===========================================================================
# 4. sanitize_like SQL wildcard escaping
# ===========================================================================

class TestSanitizeLike:
    """Tests for _sanitize_like from agent_7_amr."""

    def test_escapes_percent(self):
        assert _sanitize_like("100%") == r"100\%"

    def test_escapes_underscore(self):
        assert _sanitize_like("drug_name") == r"drug\_name"

    def test_escapes_backslash(self):
        assert _sanitize_like("path\\value") == "path\\\\value"

    def test_escapes_all_wildcards_together(self):
        result = _sanitize_like(r"50%_off\sale")
        # Backslash escaped first, then % and _
        assert r"\%" in result
        assert r"\_" in result
        assert "\\\\" in result

    def test_plain_string_unchanged(self):
        assert _sanitize_like("amoxicillin") == "amoxicillin"

    def test_empty_string(self):
        assert _sanitize_like("") == ""

    def test_multiple_wildcards(self):
        result = _sanitize_like("%%__")
        assert result == r"\%\%\_\_"


class TestSanitizeLikeCanonical:
    """Canonical sanitize_like in utils.supabase_client must behave identically."""

    @pytest.mark.parametrize("value", [
        "simple",
        "100%",
        "drug_name",
        r"back\slash",
        r"50%_off\deal",
        "",
        "%%__",
    ])
    def test_canonical_matches_agent7_version(self, value):
        assert canonical_sanitize_like(value) == _sanitize_like(value), (
            f"Mismatch for {value!r}"
        )


# ===========================================================================
# 5. Agent 7 (HIFAZAT) — AMR Guard unit tests
# ===========================================================================

# ---- Supabase mock helpers ------------------------------------------------

def _mock_supabase_who_aware(rows):
    """Build a mock Supabase client returning *rows* for who_aware_antibiotics."""
    mock_sb = MagicMock()
    mock_response = MagicMock()
    mock_response.data = rows

    mock_table = MagicMock()
    mock_select = MagicMock()
    mock_ilike = MagicMock()
    mock_ilike.execute.return_value = mock_response

    mock_select.ilike.return_value = mock_ilike
    mock_table.select.return_value = mock_select
    mock_sb.table.return_value = mock_table

    return mock_sb


def _make_supabase_mock_for_who_aware_hit(category: str, drug_name: str):
    """
    Supabase mock that returns a single ACCESS / WATCH / RESERVE row on the
    first ilike call to who_aware_antibiotics.
    """
    return _mock_supabase_who_aware([
        {
            "drug_name": drug_name,
            "category": category,
            "description": f"Test {category} antibiotic",
            "resistance_risk": "Low" if category == "ACCESS" else "High",
            "common_brands_pakistan": "BrandX, BrandY",
        }
    ])


def _make_empty_supabase_mock():
    """Supabase mock that returns empty rows for every table query."""
    mock_sb = MagicMock()
    mock_resp = MagicMock()
    mock_resp.data = []
    mock_table = MagicMock()
    mock_select = MagicMock()
    mock_ilike = MagicMock()
    mock_ilike.execute.return_value = mock_resp
    mock_select.ilike.return_value = mock_ilike
    mock_table.select.return_value = mock_select
    mock_sb.table.return_value = mock_table
    return mock_sb


# ---- Contract tests -------------------------------------------------------

class TestAgent7Contract:
    """Every call to check_amr must return a valid agent result dict."""

    @patch("agents.agent_7_amr.get_supabase")
    def test_output_contract_for_known_antibiotic(self, mock_get_sb):
        mock_get_sb.return_value = _make_supabase_mock_for_who_aware_hit(
            "ACCESS", "amoxicillin"
        )
        result = check_amr("amoxicillin")
        assert_valid_agent_result(result)

    @patch("agents.agent_7_amr.get_supabase")
    def test_output_contract_for_non_antibiotic(self, mock_get_sb):
        mock_get_sb.return_value = _make_empty_supabase_mock()
        result = check_amr("paracetamol")
        assert_valid_agent_result(result)

    def test_output_contract_for_empty_input(self):
        result = check_amr("")
        assert_valid_agent_result(result)

    def test_output_contract_for_none_input(self):
        result = check_amr(None)
        assert_valid_agent_result(result)

    @patch("agents.agent_7_amr.get_supabase")
    def test_output_contract_for_reserve_antibiotic(self, mock_get_sb):
        mock_get_sb.return_value = _make_supabase_mock_for_who_aware_hit(
            "RESERVE", "colistin"
        )
        result = check_amr("colistin")
        assert_valid_agent_result(result)


# ---- Identity tests -------------------------------------------------------

class TestAgent7Identity:
    """Agent 7 metadata constants."""

    def test_agent_number_is_7(self):
        assert AMR_AGENT_NUMBER == 7

    def test_agent_name_is_hifazat(self):
        assert "HIFAZAT" in AMR_AGENT_NAME

    @patch("agents.agent_7_amr.get_supabase")
    def test_returned_agent_number_matches_constant(self, mock_get_sb):
        mock_get_sb.return_value = _make_supabase_mock_for_who_aware_hit(
            "ACCESS", "amoxicillin"
        )
        result = check_amr("amoxicillin")
        assert result["agent_number"] == AMR_AGENT_NUMBER

    @patch("agents.agent_7_amr.get_supabase")
    def test_returned_agent_name_matches_constant(self, mock_get_sb):
        mock_get_sb.return_value = _make_supabase_mock_for_who_aware_hit(
            "ACCESS", "amoxicillin"
        )
        result = check_amr("amoxicillin")
        assert result["agent_name"] == AMR_AGENT_NAME


# ---- Empty / placeholder input tests -------------------------------------

class TestAgent7EmptyAndPlaceholderInputs:
    """Agent 7 must handle missing/empty/placeholder inputs gracefully."""

    @pytest.mark.parametrize("ingredient", ["", "  ", None])
    def test_empty_or_none_returns_pass_with_zero_confidence(self, ingredient):
        result = check_amr(ingredient)
        assert result["status"] == "PASS"
        assert result["confidence_score"] == 0.0
        assert result["is_antibiotic"] is False

    @pytest.mark.parametrize("ingredient", [
        "unknown", "Unknown", "UNKNOWN", "n/a", "N/A", "none", "None",
    ])
    def test_placeholder_values_return_pass_with_zero_confidence(self, ingredient):
        result = check_amr(ingredient)
        assert result["status"] == "PASS"
        assert result["confidence_score"] == 0.0

    def test_empty_input_has_informative_display_message(self):
        result = check_amr("")
        assert "No active ingredient" in result["display_message"]

    def test_whitespace_only_treated_as_empty(self):
        result = check_amr("   ")
        assert result["confidence_score"] == 0.0
        assert "No active ingredient" in result["display_message"]


# ---- ACCESS classification tests -----------------------------------------

class TestAgent7AccessClassification:
    """Agent 7 with ACCESS group antibiotics (e.g., amoxicillin)."""

    @patch("agents.agent_7_amr.get_supabase")
    def test_amoxicillin_is_classified_as_access(self, mock_get_sb):
        mock_get_sb.return_value = _make_supabase_mock_for_who_aware_hit(
            "ACCESS", "amoxicillin"
        )
        result = check_amr("amoxicillin")
        assert result["is_antibiotic"] is True
        assert result["aware_classification"] == "ACCESS"

    @patch("agents.agent_7_amr.get_supabase")
    def test_access_status_is_pass(self, mock_get_sb):
        mock_get_sb.return_value = _make_supabase_mock_for_who_aware_hit(
            "ACCESS", "amoxicillin"
        )
        result = check_amr("amoxicillin")
        assert result["status"] == "PASS"

    @patch("agents.agent_7_amr.get_supabase")
    def test_access_confidence_is_092(self, mock_get_sb):
        mock_get_sb.return_value = _make_supabase_mock_for_who_aware_hit(
            "ACCESS", "amoxicillin"
        )
        result = check_amr("amoxicillin")
        assert result["confidence_score"] == 0.92

    @patch("agents.agent_7_amr.get_supabase")
    def test_access_risk_level_is_low(self, mock_get_sb):
        mock_get_sb.return_value = _make_supabase_mock_for_who_aware_hit(
            "ACCESS", "amoxicillin"
        )
        result = check_amr("amoxicillin")
        assert result["risk_level"] == "LOW"

    @patch("agents.agent_7_amr.get_supabase")
    def test_access_display_message_mentions_access(self, mock_get_sb):
        mock_get_sb.return_value = _make_supabase_mock_for_who_aware_hit(
            "ACCESS", "amoxicillin"
        )
        result = check_amr("amoxicillin")
        assert "ACCESS" in result["display_message"]

    @patch("agents.agent_7_amr.get_supabase")
    def test_access_susceptibility_testing_not_required(self, mock_get_sb):
        mock_get_sb.return_value = _make_supabase_mock_for_who_aware_hit(
            "ACCESS", "amoxicillin"
        )
        result = check_amr("amoxicillin")
        assert result["susceptibility_testing_advised"] is False


# ---- WATCH classification tests ------------------------------------------

class TestAgent7WatchClassification:
    """Agent 7 with WATCH group antibiotics (e.g., azithromycin)."""

    @patch("agents.agent_7_amr.get_supabase")
    def test_azithromycin_is_classified_as_watch(self, mock_get_sb):
        mock_get_sb.return_value = _make_supabase_mock_for_who_aware_hit(
            "WATCH", "azithromycin"
        )
        result = check_amr("azithromycin")
        assert result["is_antibiotic"] is True
        assert result["aware_classification"] == "WATCH"

    @patch("agents.agent_7_amr.get_supabase")
    def test_watch_status_is_pass(self, mock_get_sb):
        mock_get_sb.return_value = _make_supabase_mock_for_who_aware_hit(
            "WATCH", "azithromycin"
        )
        result = check_amr("azithromycin")
        assert result["status"] == "PASS"

    @patch("agents.agent_7_amr.get_supabase")
    def test_watch_confidence_is_088(self, mock_get_sb):
        mock_get_sb.return_value = _make_supabase_mock_for_who_aware_hit(
            "WATCH", "azithromycin"
        )
        result = check_amr("azithromycin")
        assert result["confidence_score"] == 0.88

    @patch("agents.agent_7_amr.get_supabase")
    def test_watch_risk_level_is_high(self, mock_get_sb):
        mock_get_sb.return_value = _make_supabase_mock_for_who_aware_hit(
            "WATCH", "azithromycin"
        )
        result = check_amr("azithromycin")
        assert result["risk_level"] == "HIGH"

    @patch("agents.agent_7_amr.get_supabase")
    def test_watch_susceptibility_testing_advised(self, mock_get_sb):
        mock_get_sb.return_value = _make_supabase_mock_for_who_aware_hit(
            "WATCH", "azithromycin"
        )
        result = check_amr("azithromycin")
        assert result["susceptibility_testing_advised"] is True

    @patch("agents.agent_7_amr.get_supabase")
    def test_watch_display_message_mentions_watch_group(self, mock_get_sb):
        mock_get_sb.return_value = _make_supabase_mock_for_who_aware_hit(
            "WATCH", "azithromycin"
        )
        result = check_amr("azithromycin")
        assert "WATCH" in result["display_message"]

    @patch("agents.agent_7_amr.get_supabase")
    def test_watch_display_mentions_drap_prescription(self, mock_get_sb):
        mock_get_sb.return_value = _make_supabase_mock_for_who_aware_hit(
            "WATCH", "azithromycin"
        )
        result = check_amr("azithromycin")
        assert "DRAP" in result["display_message"]


# ---- RESERVE classification tests ----------------------------------------

class TestAgent7ReserveClassification:
    """Agent 7 with RESERVE group antibiotics."""

    @patch("agents.agent_7_amr.get_supabase")
    def test_reserve_status_is_warning(self, mock_get_sb):
        mock_get_sb.return_value = _make_supabase_mock_for_who_aware_hit(
            "RESERVE", "colistin"
        )
        result = check_amr("colistin")
        assert result["status"] == "WARNING"

    @patch("agents.agent_7_amr.get_supabase")
    def test_reserve_confidence_is_095(self, mock_get_sb):
        mock_get_sb.return_value = _make_supabase_mock_for_who_aware_hit(
            "RESERVE", "colistin"
        )
        result = check_amr("colistin")
        assert result["confidence_score"] == 0.95

    @patch("agents.agent_7_amr.get_supabase")
    def test_reserve_risk_level_is_critical(self, mock_get_sb):
        mock_get_sb.return_value = _make_supabase_mock_for_who_aware_hit(
            "RESERVE", "colistin"
        )
        result = check_amr("colistin")
        assert result["risk_level"] == "CRITICAL"

    @patch("agents.agent_7_amr.get_supabase")
    def test_reserve_display_message_mentions_reserve(self, mock_get_sb):
        mock_get_sb.return_value = _make_supabase_mock_for_who_aware_hit(
            "RESERVE", "colistin"
        )
        result = check_amr("colistin")
        assert "RESERVE" in result["display_message"]

    @patch("agents.agent_7_amr.get_supabase")
    def test_reserve_susceptibility_testing_advised(self, mock_get_sb):
        mock_get_sb.return_value = _make_supabase_mock_for_who_aware_hit(
            "RESERVE", "colistin"
        )
        result = check_amr("colistin")
        assert result["susceptibility_testing_advised"] is True


# ---- Non-antibiotic tests -------------------------------------------------

class TestAgent7NonAntibiotic:
    """Agent 7 with non-antibiotic medications."""

    @patch("agents.agent_7_amr.get_supabase")
    def test_non_antibiotic_is_not_flagged(self, mock_get_sb):
        mock_get_sb.return_value = _make_empty_supabase_mock()
        result = check_amr("paracetamol")
        assert result["is_antibiotic"] is False
        assert result["status"] == "PASS"
        assert result["aware_classification"] is None

    @patch("agents.agent_7_amr.get_supabase")
    def test_non_antibiotic_confidence_is_080(self, mock_get_sb):
        mock_get_sb.return_value = _make_empty_supabase_mock()
        result = check_amr("paracetamol")
        assert result["confidence_score"] == 0.80

    @patch("agents.agent_7_amr.get_supabase")
    def test_non_antibiotic_display_says_not_antibiotic(self, mock_get_sb):
        mock_get_sb.return_value = _make_empty_supabase_mock()
        result = check_amr("paracetamol")
        assert "not classified as an antibiotic" in result["display_message"]


# ---- Pakistan resistance data tests --------------------------------------

class TestAgent7PakistanResistance:
    """Pakistan-specific resistance data integration."""

    def test_amoxicillin_in_resistance_stats(self):
        assert "amoxicillin" in PAKISTAN_RESISTANCE_STATS

    def test_azithromycin_in_resistance_stats(self):
        assert "azithromycin" in PAKISTAN_RESISTANCE_STATS

    def test_resistance_stats_have_required_fields(self):
        for drug, data in PAKISTAN_RESISTANCE_STATS.items():
            assert "resistance_note" in data, f"{drug} missing resistance_note"
            assert "overused" in data, f"{drug} missing overused"
            assert "common_resistant_organisms" in data, (
                f"{drug} missing common_resistant_organisms"
            )

    @patch("agents.agent_7_amr.get_supabase")
    def test_known_antibiotic_includes_pakistan_context(self, mock_get_sb):
        mock_get_sb.return_value = _make_supabase_mock_for_who_aware_hit(
            "ACCESS", "amoxicillin"
        )
        result = check_amr("amoxicillin")
        assert result["pakistan_context"] is not None
        assert "Pakistan" in result["pakistan_context"]

    @patch("agents.agent_7_amr.get_supabase")
    def test_access_antibiotic_brands_parsed(self, mock_get_sb):
        mock_get_sb.return_value = _make_supabase_mock_for_who_aware_hit(
            "ACCESS", "amoxicillin"
        )
        result = check_amr("amoxicillin")
        assert isinstance(result["common_brands_pakistan"], list)
        assert len(result["common_brands_pakistan"]) > 0


# ---- Exception handling tests ---------------------------------------------

class TestAgent7ExceptionHandling:
    """Agent 7 must catch exceptions and still return a valid dict."""

    @patch("agents.agent_7_amr.get_supabase")
    def test_supabase_failure_still_returns_valid_result(self, mock_get_sb):
        # When get_supabase() raises inside _lookup_who_aware and
        # _is_antibiotic_via_generic_drugs, those helpers catch and return
        # None/False respectively.  The agent gracefully degrades to
        # "not an antibiotic" rather than UNCERTAIN.
        mock_get_sb.side_effect = ConnectionError("Supabase unreachable")
        result = check_amr("amoxicillin")
        assert_valid_agent_result(result)
        # Agent still returns a valid dict — status depends on the graceful
        # degradation path (PASS as non-antibiotic fallback).
        assert result["status"] in VALID_STATUSES

    @patch("agents.agent_7_amr.get_supabase")
    def test_supabase_exception_preserves_agent_identity(self, mock_get_sb):
        mock_get_sb.side_effect = RuntimeError("db down")
        result = check_amr("amoxicillin")
        assert result["agent_number"] == 7
        assert result["agent_name"] == AMR_AGENT_NAME


# ---- Fallback via generic_drugs table -------------------------------------

class TestAgent7AntibioticFallbackViaGenericDrugs:
    """When WHO AWaRe table misses, Agent 7 falls back to generic_drugs."""

    @patch("agents.agent_7_amr.get_supabase")
    def test_antibiotic_not_in_aware_but_in_generic_drugs(self, mock_get_sb):
        def table_side_effect(table_name):
            mock_table = MagicMock()
            mock_select = MagicMock()
            mock_ilike = MagicMock()
            if table_name == "who_aware_antibiotics":
                empty_resp = MagicMock()
                empty_resp.data = []
                mock_ilike.execute.return_value = empty_resp
            elif table_name == "generic_drugs":
                resp = MagicMock()
                resp.data = [{"therapeutic_class": "Antibiotic - Cephalosporin"}]
                mock_ilike.execute.return_value = resp
            else:
                empty_resp = MagicMock()
                empty_resp.data = []
                mock_ilike.execute.return_value = empty_resp
            mock_select.ilike.return_value = mock_ilike
            mock_table.select.return_value = mock_select
            return mock_table

        mock_sb = MagicMock()
        mock_sb.table.side_effect = table_side_effect
        mock_get_sb.return_value = mock_sb

        result = check_amr("cefadroxil")
        assert_valid_agent_result(result)
        assert result["is_antibiotic"] is True
        assert result["confidence_score"] == 0.70
        assert result["risk_level"] == "MEDIUM"
        assert "not in the WHO AWaRe classification" in result["display_message"]
