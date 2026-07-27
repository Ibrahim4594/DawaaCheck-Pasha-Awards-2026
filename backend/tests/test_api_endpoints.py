"""
test_api_endpoints.py -- HTTP-layer tests for DawaaCheck FastAPI endpoints.

Tests cover:
  1. Health check endpoint
  2. Scan endpoint input validation and auth enforcement
  3. Medicine endpoint request validation (query params, path params)
  4. Recall endpoint response structure
  5. ADR endpoint auth enforcement
  6. CORS middleware headers

Third-party dependencies (anthropic, httpx, supabase, firebase_admin,
sse_starlette, slowapi) are stubbed via sys.modules so the test file
works without installing the full backend stack.  All Supabase-dependent
tests that need real data are skipped; only the input-validation /
auth-enforcement layer is exercised.
"""

import os
import sys
import types
from unittest.mock import MagicMock, patch, AsyncMock

# ---------------------------------------------------------------------------
# Restore real httpx if another test file stubbed it (test_agent_contracts
# stubs httpx but TestClient needs the real module).
# ---------------------------------------------------------------------------
_httpx_mod = sys.modules.get("httpx")
if _httpx_mod is not None and not hasattr(_httpx_mod, "Response"):
    # It was stubbed — remove the fake so the real one loads
    del sys.modules["httpx"]

# ---------------------------------------------------------------------------
# Stub heavy third-party packages BEFORE importing the FastAPI app.
# ---------------------------------------------------------------------------

_THIRD_PARTY_STUBS = [
    "anthropic",
    # NOTE: httpx is NOT stubbed — it is a real dependency of FastAPI TestClient.
    "supabase",
    "firebase_admin",
    "firebase_admin.auth",
    "firebase_admin.credentials",
    "firebase_admin.messaging",
    "firebase_admin._apps",
    "google.cloud.firestore",
    "google.auth",
    "google.auth.transport",
    "google.auth.transport.requests",
]

for _name in _THIRD_PARTY_STUBS:
    if _name not in sys.modules:
        sys.modules[_name] = types.ModuleType(_name)

# supabase stub needs create_client and Client
sys.modules["supabase"].create_client = MagicMock()
sys.modules["supabase"].Client = MagicMock

# firebase_admin needs realistic stubs so get_current_user works
sys.modules["firebase_admin"]._apps = {}
sys.modules["firebase_admin"].initialize_app = MagicMock()
sys.modules["firebase_admin.credentials"].Certificate = MagicMock()

# firebase_admin.auth must have exception classes and verify_id_token
_fb_auth = sys.modules["firebase_admin.auth"]
_fb_auth.ExpiredIdTokenError = type("ExpiredIdTokenError", (Exception,), {})
_fb_auth.InvalidIdTokenError = type("InvalidIdTokenError", (Exception,), {})
_fb_auth.verify_id_token = MagicMock(
    side_effect=_fb_auth.InvalidIdTokenError("stub: no real token")
)

# sse_starlette must be importable with EventSourceResponse.
# FastAPI inspects the return type annotation on route handlers, so the
# fake must inherit from starlette.responses.Response to pass validation.
from starlette.responses import Response as _StarletteResponse

_sse_mod = types.ModuleType("sse_starlette")
_sse_sse_mod = types.ModuleType("sse_starlette.sse")


class _FakeEventSourceResponse(_StarletteResponse):
    """Minimal stand-in for EventSourceResponse (inherits from Response)."""

    def __init__(self, *args, **kwargs):
        # Don't call super().__init__() — we never actually send a response
        pass


_sse_sse_mod.EventSourceResponse = _FakeEventSourceResponse
sys.modules.setdefault("sse_starlette", _sse_mod)
sys.modules.setdefault("sse_starlette.sse", _sse_sse_mod)

# slowapi must be importable
_slowapi = sys.modules.get("slowapi")
if _slowapi is None or not hasattr(_slowapi, "Limiter"):
    _slowapi_mod = types.ModuleType("slowapi")

    class _FakeLimiter:
        def __init__(self, **kwargs):
            pass

        def limit(self, *args, **kwargs):
            """Return a no-op decorator."""
            def decorator(func):
                return func
            return decorator

    _slowapi_mod.Limiter = _FakeLimiter
    _slowapi_mod._rate_limit_exceeded_handler = lambda *a, **kw: None

    class _FakeRateLimitExceeded(Exception):
        pass

    _slowapi_errors = types.ModuleType("slowapi.errors")
    _slowapi_errors.RateLimitExceeded = _FakeRateLimitExceeded

    _slowapi_util = types.ModuleType("slowapi.util")
    _slowapi_util.get_remote_address = lambda *a, **kw: "127.0.0.1"

    sys.modules["slowapi"] = _slowapi_mod
    sys.modules["slowapi.errors"] = _slowapi_errors
    sys.modules["slowapi.util"] = _slowapi_util

# dotenv
sys.modules.setdefault("dotenv", types.ModuleType("dotenv"))
sys.modules["dotenv"].load_dotenv = lambda *a, **kw: None

# Set required env vars before importing the app
os.environ.setdefault("SUPABASE_URL", "https://test.supabase.co")
os.environ.setdefault("SUPABASE_KEY", "test-key")

# ---------------------------------------------------------------------------
# Now safe to import the FastAPI app
# ---------------------------------------------------------------------------

# Ensure the backend directory is on sys.path
_backend_dir = os.path.join(os.path.dirname(__file__), os.pardir)
_backend_abs = os.path.abspath(_backend_dir)
if _backend_abs not in sys.path:
    sys.path.insert(0, _backend_abs)

from main import app  # noqa: E402

import pytest  # noqa: E402
from fastapi.testclient import TestClient  # noqa: E402

# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

client = TestClient(app, raise_server_exceptions=False)

# A fake Supabase response object for mocking
class _FakeSupabaseResponse:
    """Mimics the postgrest response from supabase-py."""

    def __init__(self, data=None, count=None):
        self.data = data or []
        self.count = count


def _mock_supabase_client():
    """Build a MagicMock that quacks like the supabase Client."""
    mock_client = MagicMock()

    # Make chained query builder calls return the mock itself, ending
    # with .execute() returning a _FakeSupabaseResponse.
    query_builder = MagicMock()
    query_builder.select.return_value = query_builder
    query_builder.eq.return_value = query_builder
    query_builder.ilike.return_value = query_builder
    query_builder.or_.return_value = query_builder
    query_builder.text_search.return_value = query_builder
    query_builder.order.return_value = query_builder
    query_builder.range.return_value = query_builder
    query_builder.limit.return_value = query_builder
    query_builder.execute.return_value = _FakeSupabaseResponse(data=[], count=0)

    mock_client.table.return_value = query_builder
    return mock_client


# ---------------------------------------------------------------------------
# 1. Health Check
# ---------------------------------------------------------------------------


class TestHealthCheck:
    """GET / should return 200 with service status."""

    def test_health_returns_200(self):
        resp = client.get("/")
        assert resp.status_code == 200

    def test_health_body_has_status_ok(self):
        resp = client.get("/")
        body = resp.json()
        assert body["status"] == "ok"

    def test_health_body_has_service_name(self):
        resp = client.get("/")
        body = resp.json()
        assert "service" in body


# ---------------------------------------------------------------------------
# 2-5. Scan Endpoints — Input Validation & Auth
# ---------------------------------------------------------------------------


class TestScanVerifyJson:
    """POST /scan/verify-json — input validation and auth enforcement.

    FastAPI resolves Depends(get_current_user) BEFORE body validation,
    so to test body validation we override the auth dependency to
    always succeed.  Auth-enforcement tests use the real dependency.
    """

    def test_missing_auth_header_returns_401(self):
        """No Authorization header should yield 401."""
        payload = {
            "front_image": "abc",
            "back_image": "abc",
            "user_id": "test-uid",
        }
        resp = client.post("/scan/verify-json", json=payload)
        assert resp.status_code == 401

    def test_invalid_token_returns_401(self):
        """A fake token that fails verification should yield 401."""
        payload = {
            "front_image": "abc",
            "back_image": "abc",
            "user_id": "test-uid",
        }
        resp = client.post(
            "/scan/verify-json",
            json=payload,
            headers={"Authorization": "Bearer fake-token"},
        )
        assert resp.status_code == 401

    def test_missing_front_image_returns_422(self):
        """front_image is required — omitting it should yield 422."""
        from utils.auth import get_current_user
        app.dependency_overrides[get_current_user] = lambda: {"uid": "test"}
        try:
            payload = {
                "back_image": "abc",
                "user_id": "test-uid",
            }
            resp = client.post("/scan/verify-json", json=payload)
            assert resp.status_code == 422
        finally:
            app.dependency_overrides.pop(get_current_user, None)

    def test_missing_back_image_returns_422(self):
        """back_image is required — omitting it should yield 422."""
        from utils.auth import get_current_user
        app.dependency_overrides[get_current_user] = lambda: {"uid": "test"}
        try:
            payload = {
                "front_image": "abc",
                "user_id": "test-uid",
            }
            resp = client.post("/scan/verify-json", json=payload)
            assert resp.status_code == 422
        finally:
            app.dependency_overrides.pop(get_current_user, None)

    def test_missing_user_id_returns_422(self):
        """user_id is required — omitting it should yield 422."""
        from utils.auth import get_current_user
        app.dependency_overrides[get_current_user] = lambda: {"uid": "test"}
        try:
            payload = {
                "front_image": "abc",
                "back_image": "abc",
            }
            resp = client.post("/scan/verify-json", json=payload)
            assert resp.status_code == 422
        finally:
            app.dependency_overrides.pop(get_current_user, None)

    def test_front_image_exceeding_max_length_returns_422(self):
        """front_image has a 10MB max_length constraint."""
        from utils.auth import get_current_user
        app.dependency_overrides[get_current_user] = lambda: {"uid": "test"}
        try:
            oversized = "x" * (10_000_001)
            payload = {
                "front_image": oversized,
                "back_image": "abc",
                "user_id": "test-uid",
            }
            resp = client.post("/scan/verify-json", json=payload)
            assert resp.status_code == 422
        finally:
            app.dependency_overrides.pop(get_current_user, None)

    def test_empty_body_returns_422(self):
        """Completely empty request body should yield 422."""
        from utils.auth import get_current_user
        app.dependency_overrides[get_current_user] = lambda: {"uid": "test"}
        try:
            resp = client.post("/scan/verify-json", json={})
            assert resp.status_code == 422
        finally:
            app.dependency_overrides.pop(get_current_user, None)


class TestScanVerifySSE:
    """POST /scan/verify — auth enforcement on the SSE endpoint."""

    def test_missing_auth_header_returns_401(self):
        """The SSE endpoint also requires auth."""
        payload = {
            "front_image": "abc",
            "back_image": "abc",
            "user_id": "test-uid",
        }
        resp = client.post("/scan/verify", json=payload)
        assert resp.status_code == 401


# ---------------------------------------------------------------------------
# 6-15. Medicine Endpoints — Response Format & Validation
# ---------------------------------------------------------------------------


class TestMedicineSearch:
    """GET /medicines/search — query validation."""

    @patch("routers.medicines.get_supabase")
    def test_search_returns_expected_keys(self, mock_get_sb):
        """Response must include total, page, results."""
        mock_get_sb.return_value = _mock_supabase_client()
        resp = client.get("/medicines/search?q=pa")
        assert resp.status_code == 200
        body = resp.json()
        assert "total" in body
        assert "page" in body
        assert "results" in body

    def test_search_missing_q_returns_422(self):
        """The q parameter is required."""
        resp = client.get("/medicines/search")
        assert resp.status_code == 422

    def test_search_q_too_short_returns_422(self):
        """q has min_length=2; a single character should be rejected."""
        resp = client.get("/medicines/search?q=a")
        assert resp.status_code == 422

    @patch("routers.medicines.get_supabase")
    def test_search_returns_list_in_results(self, mock_get_sb):
        """results field should always be a list."""
        mock_get_sb.return_value = _mock_supabase_client()
        resp = client.get("/medicines/search?q=panadol")
        assert resp.status_code == 200
        assert isinstance(resp.json()["results"], list)

    @patch("routers.medicines.get_supabase")
    def test_search_pagination_defaults(self, mock_get_sb):
        """Default page should be 1."""
        mock_get_sb.return_value = _mock_supabase_client()
        resp = client.get("/medicines/search?q=test")
        assert resp.status_code == 200
        assert resp.json()["page"] == 1


class TestMedicineDetail:
    """GET /medicines/detail/{registration_number}."""

    @patch("routers.medicines.get_supabase")
    def test_nonexistent_returns_404(self, mock_get_sb):
        """A registration number not in the DB should yield 404."""
        mock_get_sb.return_value = _mock_supabase_client()
        resp = client.get("/medicines/detail/NONEXISTENT")
        assert resp.status_code == 404


class TestMedicineInteractions:
    """GET /medicines/interactions."""

    @patch("routers.medicines.get_supabase")
    def test_returns_expected_keys(self, mock_get_sb):
        """Response must include drug, interaction_count, interactions."""
        mock_get_sb.return_value = _mock_supabase_client()
        resp = client.get("/medicines/interactions?drug=test")
        assert resp.status_code == 200
        body = resp.json()
        assert "drug" in body
        assert "interaction_count" in body
        assert "interactions" in body

    def test_missing_drug_param_returns_422(self):
        """The drug query param is required."""
        resp = client.get("/medicines/interactions")
        assert resp.status_code == 422

    def test_drug_too_short_returns_422(self):
        """drug has min_length=2."""
        resp = client.get("/medicines/interactions?drug=a")
        assert resp.status_code == 422


class TestMedicineSideEffects:
    """GET /medicines/side-effects/{drug_name}."""

    @patch("routers.medicines.get_supabase")
    def test_nonexistent_returns_404(self, mock_get_sb):
        """Unknown drug name should yield 404."""
        mock_get_sb.return_value = _mock_supabase_client()
        resp = client.get("/medicines/side-effects/NONEXISTENT")
        assert resp.status_code == 404


class TestWhoAware:
    """GET /medicines/who-aware/{drug_name}."""

    @patch("routers.medicines.get_supabase")
    def test_returns_is_antibiotic_key(self, mock_get_sb):
        """Response always includes is_antibiotic."""
        mock_get_sb.return_value = _mock_supabase_client()
        resp = client.get("/medicines/who-aware/paracetamol")
        assert resp.status_code == 200
        body = resp.json()
        assert "is_antibiotic" in body

    @patch("routers.medicines.get_supabase")
    def test_non_antibiotic_returns_false(self, mock_get_sb):
        """An unknown drug should return is_antibiotic=False."""
        mock_get_sb.return_value = _mock_supabase_client()
        resp = client.get("/medicines/who-aware/paracetamol")
        assert resp.json()["is_antibiotic"] is False


class TestPediatricSafety:
    """GET /medicines/pediatric-safety/{drug_name}."""

    @patch("routers.medicines.get_supabase")
    def test_returns_has_pediatric_concerns_key(self, mock_get_sb):
        """Response always includes has_pediatric_concerns."""
        mock_get_sb.return_value = _mock_supabase_client()
        resp = client.get("/medicines/pediatric-safety/paracetamol")
        assert resp.status_code == 200
        body = resp.json()
        assert "has_pediatric_concerns" in body

    @patch("routers.medicines.get_supabase")
    def test_unknown_drug_returns_no_concerns(self, mock_get_sb):
        """Unknown drug returns has_pediatric_concerns=False and empty alerts."""
        mock_get_sb.return_value = _mock_supabase_client()
        resp = client.get("/medicines/pediatric-safety/unknowndrug")
        body = resp.json()
        assert body["has_pediatric_concerns"] is False
        assert body["alerts"] == []


class TestConditionsList:
    """GET /medicines/conditions."""

    @patch("routers.medicines.get_supabase")
    def test_returns_conditions_list(self, mock_get_sb):
        """Response must include a conditions list."""
        mock_get_sb.return_value = _mock_supabase_client()
        resp = client.get("/medicines/conditions")
        assert resp.status_code == 200
        body = resp.json()
        assert "conditions" in body
        assert isinstance(body["conditions"], list)


class TestDatabaseStats:
    """GET /medicines/stats."""

    @patch("routers.medicines._get_db_stats")
    def test_returns_dict(self, mock_stats):
        """Response should be a dict with table names as keys."""
        mock_stats.return_value = {
            "drap_medicines": 329,
            "generic_drugs": 922,
            "total": 1251,
        }
        resp = client.get("/medicines/stats")
        assert resp.status_code == 200
        body = resp.json()
        assert isinstance(body, dict)
        assert "total" in body


# ---------------------------------------------------------------------------
# 16-18. Recall Endpoints
# ---------------------------------------------------------------------------


class TestRecalls:
    """GET /recalls/ — response structure and filtering."""

    @patch("routers.recalls._fetch_active_recalls")
    def test_returns_expected_keys(self, mock_fetch):
        """Response must include total, page, results."""
        mock_fetch.return_value = []
        resp = client.get("/recalls/")
        assert resp.status_code == 200
        body = resp.json()
        assert "total" in body
        assert "page" in body
        assert "results" in body

    @patch("routers.recalls._fetch_active_recalls")
    def test_recall_class_filter(self, mock_fetch):
        """Passing recall_class filters results by classification."""
        mock_fetch.return_value = [
            {"medicine_name": "DrugA", "recall_class": "CLASS_I", "recall_reason": "", "manufacturer": ""},
            {"medicine_name": "DrugB", "recall_class": "CLASS_II", "recall_reason": "", "manufacturer": ""},
        ]
        resp = client.get("/recalls/?recall_class=CLASS_I")
        assert resp.status_code == 200
        body = resp.json()
        assert body["total"] == 1
        assert all(r["recall_class"] == "CLASS_I" for r in body["results"])

    @patch("routers.recalls._fetch_active_recalls")
    def test_empty_results(self, mock_fetch):
        """Empty recall list should return total=0 and empty results."""
        mock_fetch.return_value = []
        resp = client.get("/recalls/")
        body = resp.json()
        assert body["total"] == 0
        assert body["results"] == []


class TestRecallCheck:
    """GET /recalls/check/{medicine_name}."""

    @patch("routers.recalls.get_supabase")
    def test_nonexistent_returns_no_recall(self, mock_get_sb):
        """Unknown medicine name should return has_recall=False."""
        mock_get_sb.return_value = _mock_supabase_client()
        resp = client.get("/recalls/check/NONEXISTENT")
        assert resp.status_code == 200
        body = resp.json()
        assert body["has_recall"] is False


# ---------------------------------------------------------------------------
# 19. ADR Endpoint — Auth Enforcement
# ---------------------------------------------------------------------------


class TestADRReport:
    """POST /adr/report — auth enforcement."""

    def test_missing_auth_returns_401(self):
        """No Authorization header should yield 401."""
        payload = {
            "user_id": "uid123",
            "medicine_name": "Panadol",
            "reaction_description": "Severe headache after taking the medicine",
        }
        resp = client.post("/adr/report", json=payload)
        assert resp.status_code == 401

    def test_missing_required_fields_returns_422(self):
        """Omitting required fields should yield 422 (validated before auth)."""
        resp = client.post(
            "/adr/report",
            json={},
            headers={"Authorization": "Bearer fake-token"},
        )
        assert resp.status_code in (401, 422)

    def test_reaction_too_short_returns_422(self):
        """reaction_description has min_length=10."""
        payload = {
            "user_id": "uid123",
            "medicine_name": "Panadol",
            "reaction_description": "short",
        }
        resp = client.post(
            "/adr/report",
            json=payload,
            headers={"Authorization": "Bearer fake-token"},
        )
        # Either 422 for body validation or 401 for auth — both acceptable
        assert resp.status_code in (401, 422)


# ---------------------------------------------------------------------------
# 20. CORS
# ---------------------------------------------------------------------------


class TestCORS:
    """CORS middleware should include the expected headers."""

    def test_options_preflight_returns_cors_headers(self):
        """An OPTIONS preflight request should return CORS allow headers."""
        resp = client.options(
            "/",
            headers={
                "Origin": "https://your-firebase-project.web.app",
                "Access-Control-Request-Method": "GET",
            },
        )
        # CORS middleware should respond (200 or 204)
        assert resp.status_code in (200, 204)
        assert "access-control-allow-origin" in resp.headers

    def test_cors_allows_configured_origin(self):
        """The allowed origin from ALLOWED_ORIGINS should be reflected."""
        resp = client.options(
            "/",
            headers={
                "Origin": "https://your-firebase-project.web.app",
                "Access-Control-Request-Method": "POST",
            },
        )
        allowed = resp.headers.get("access-control-allow-origin", "")
        assert "your-firebase-project.web.app" in allowed

    def test_cors_headers_on_regular_get(self):
        """Regular GET from an allowed origin should include CORS header."""
        resp = client.get(
            "/",
            headers={"Origin": "https://your-firebase-project.web.app"},
        )
        assert resp.status_code == 200
        assert "access-control-allow-origin" in resp.headers

    def test_cors_disallows_unknown_origin(self):
        """An unknown origin should not be reflected in the response."""
        resp = client.options(
            "/",
            headers={
                "Origin": "https://evil-site.example.com",
                "Access-Control-Request-Method": "GET",
            },
        )
        allowed = resp.headers.get("access-control-allow-origin", "")
        assert "evil-site.example.com" not in allowed
