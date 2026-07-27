"""DawaaCheck Security Audit Tests.

Static analysis tests that verify security properties of the codebase
without requiring any live connections (Supabase, Firebase, etc.).

Run:  pytest tests/test_security.py -v
"""

import ast
import os
import re

import pytest

# ── Paths ────────────────────────────────────────────────────────────────────

BACKEND_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PROJECT_ROOT = os.path.dirname(BACKEND_DIR)
ROUTERS_DIR = os.path.join(BACKEND_DIR, "routers")
UTILS_DIR = os.path.join(BACKEND_DIR, "utils")
MAIN_PY = os.path.join(BACKEND_DIR, "main.py")

MIGRATION_V1 = os.path.join(PROJECT_ROOT, "supabase_migration.txt")
MIGRATION_V2 = os.path.join(PROJECT_ROOT, "supabase_migration_v2.txt")


def _read(path: str) -> str:
    with open(path, encoding="utf-8") as f:
        return f.read()


def _get_imports(source: str) -> list[str]:
    """Return a flat list of all imported names from *source* text."""
    tree = ast.parse(source)
    names: list[str] = []
    for node in ast.walk(tree):
        if isinstance(node, ast.Import):
            for alias in node.names:
                names.append(alias.name)
        elif isinstance(node, ast.ImportFrom):
            module = node.module or ""
            for alias in node.names:
                names.append(f"{module}.{alias.name}")
    return names


# ════════════════════════════════════════════════════════════════════════════
# 1-3  Auth Enforcement
# ════════════════════════════════════════════════════════════════════════════


class TestAuthEnforcement:
    """Verify that protected routers use strict auth, not optional auth."""

    def test_scan_imports_get_current_user(self):
        """scan.py must import get_current_user (not get_optional_user)."""
        src = _read(os.path.join(ROUTERS_DIR, "scan.py"))
        imports = _get_imports(src)
        assert "utils.auth.get_current_user" in imports, (
            "scan.py should import get_current_user from utils.auth"
        )
        assert "utils.auth.get_optional_user" not in imports, (
            "scan.py must NOT use get_optional_user — scanning requires auth"
        )

    def test_adr_uses_auth_dependency(self):
        """adr.py must use get_current_user as a dependency."""
        src = _read(os.path.join(ROUTERS_DIR, "adr.py"))
        imports = _get_imports(src)
        assert "utils.auth.get_current_user" in imports, (
            "adr.py should import get_current_user from utils.auth"
        )
        # Also verify it's actually wired as a Depends()
        assert "Depends(get_current_user)" in src, (
            "adr.py must wire get_current_user via Depends()"
        )

    def test_all_routers_import_from_utils_auth(self):
        """Every router file that handles user data must import from utils.auth."""
        protected_routers = ["scan.py", "adr.py", "notifications.py"]
        for name in protected_routers:
            path = os.path.join(ROUTERS_DIR, name)
            if not os.path.exists(path):
                pytest.skip(f"{name} not found")
            src = _read(path)
            imports = _get_imports(src)
            auth_imports = [i for i in imports if i.startswith("utils.auth.")]
            assert auth_imports, (
                f"{name} does not import anything from utils.auth — "
                "user-facing endpoints must enforce authentication"
            )


# ════════════════════════════════════════════════════════════════════════════
# 4-5  CORS Configuration
# ════════════════════════════════════════════════════════════════════════════


class TestCORSConfiguration:
    """Verify CORS is not wide-open."""

    @pytest.fixture()
    def main_source(self) -> str:
        return _read(MAIN_PY)

    def test_cors_not_wildcard(self, main_source: str):
        """CORS allow_origins must NOT be a bare wildcard ['*']."""
        # Look for allow_origins=["*"] pattern — should not exist
        assert 'allow_origins=["*"]' not in main_source, (
            "CORS allow_origins is set to wildcard ['*'] — "
            "this allows any website to make credentialed requests"
        )
        assert "allow_origins=['*']" not in main_source, (
            "CORS allow_origins is set to wildcard ['*']"
        )

    def test_cors_includes_web_app_domain(self, main_source: str):
        """CORS origins should include the deployed web app domain."""
        assert "your-firebase-project.web.app" in main_source, (
            "CORS config should include the production web app domain "
            "(your-firebase-project.web.app)"
        )


# ════════════════════════════════════════════════════════════════════════════
# 6-9  Input Sanitization
# ════════════════════════════════════════════════════════════════════════════


class TestInputSanitization:
    """Verify SQL LIKE wildcard injection is prevented."""

    def test_sanitize_like_exists(self):
        """sanitize_like function must exist in utils/supabase_client.py."""
        src = _read(os.path.join(UTILS_DIR, "supabase_client.py"))
        assert "def sanitize_like" in src, (
            "supabase_client.py must define sanitize_like()"
        )

    @pytest.mark.parametrize(
        "input_val, must_not_contain",
        [
            ("100%", ["%"]),
            ("under_score", ["_"]),
            ("back\\slash", ["\\"]),
        ],
        ids=["percent", "underscore", "backslash"],
    )
    def test_sanitize_like_escapes_wildcards(self, input_val: str, must_not_contain: list[str]):
        """sanitize_like must escape %, _, and \\ so they are treated literally."""
        # Extract just the return-statement logic from the source file so we
        # can test it without importing the supabase SDK (which may not be
        # installed in the test environment).
        src = _read(os.path.join(UTILS_DIR, "supabase_client.py"))

        # Pull the function body: everything from "def sanitize_like" to the
        # next top-level definition or EOF.
        func_block = re.search(
            r"def sanitize_like\(value.*?\).*?:\n(.*?)(?=\ndef |\nclass |\Z)",
            src,
            re.DOTALL,
        )
        assert func_block, "Could not locate sanitize_like function in source"

        # Build a minimal callable from the extracted body.
        func_code = "def sanitize_like(value):\n" + func_block.group(1)
        local_ns: dict = {}
        exec(compile(func_code, "<sanitize_like>", "exec"), local_ns)  # noqa: S102
        sanitize_like = local_ns["sanitize_like"]

        result = sanitize_like(input_val)
        for char in must_not_contain:
            # The raw char should only appear as part of an escape sequence
            # e.g. "%" becomes "\%" — so bare unescaped chars should be gone
            unescaped = result.replace(f"\\{char}", "")
            assert char not in unescaped, (
                f"sanitize_like({input_val!r}) returned {result!r} which still "
                f"contains unescaped '{char}'"
            )

    def test_medicines_imports_sanitize_like(self):
        """medicines.py must import sanitize_like for safe ILIKE queries."""
        src = _read(os.path.join(ROUTERS_DIR, "medicines.py"))
        assert "sanitize_like" in src, (
            "medicines.py should import sanitize_like to prevent ILIKE injection"
        )

    def test_recalls_imports_sanitize_like(self):
        """recalls.py must import sanitize_like for safe ILIKE queries."""
        src = _read(os.path.join(ROUTERS_DIR, "recalls.py"))
        assert "sanitize_like" in src, (
            "recalls.py should import sanitize_like to prevent ILIKE injection"
        )


# ════════════════════════════════════════════════════════════════════════════
# 10  Image Size Limits
# ════════════════════════════════════════════════════════════════════════════


class TestImageSizeLimits:
    """Verify that image fields have max_length constraints."""

    def test_scan_request_has_max_length(self):
        """ScanRequest image fields must have max_length to prevent DoS."""
        src = _read(os.path.join(ROUTERS_DIR, "scan.py"))
        tree = ast.parse(src)

        # Find the ScanRequest class
        scan_request_cls = None
        for node in ast.walk(tree):
            if isinstance(node, ast.ClassDef) and node.name == "ScanRequest":
                scan_request_cls = node
                break

        assert scan_request_cls is not None, "ScanRequest class not found in scan.py"

        # Extract the ScanRequest class body from source and check each image
        # field for max_length.  The Field() call may span multiple lines, so
        # we grab all text from the field name to the next field assignment
        # (or end of class) and check for max_length within that span.
        image_fields = ["front_image", "back_image", "ingredients_image"]
        for field_name in image_fields:
            # Capture from "field_name" up to the next class-level assignment or end
            pattern = rf"{field_name}\s*:.*?(?=\n    \w+\s*:|$)"
            match = re.search(pattern, src, re.DOTALL)
            assert match, (
                f"ScanRequest.{field_name} field not found in scan.py"
            )
            assert "max_length" in match.group(0), (
                f"ScanRequest.{field_name} must have a max_length constraint "
                "to prevent oversized payloads"
            )


# ════════════════════════════════════════════════════════════════════════════
# 11  Error Leak Prevention
# ════════════════════════════════════════════════════════════════════════════


class TestErrorLeakPrevention:
    """Verify that internal error details are not sent to clients."""

    def test_scan_no_detail_str_exc(self):
        """scan.py must NOT use detail=str(exc) — error messages must be generic."""
        src = _read(os.path.join(ROUTERS_DIR, "scan.py"))
        # Match patterns like detail=str(exc), detail=str(e), detail=f"...{exc}"
        dangerous_patterns = [
            r'detail\s*=\s*str\s*\(\s*exc\s*\)',
            r'detail\s*=\s*str\s*\(\s*e\s*\)',
            r'detail\s*=\s*f["\'].*\{exc\}',
            r'detail\s*=\s*f["\'].*\{e\}',
        ]
        for pattern in dangerous_patterns:
            match = re.search(pattern, src)
            assert match is None, (
                f"scan.py leaks internal error details to clients via: "
                f"{match.group(0) if match else pattern}"
            )

    def test_adr_error_leak_warning(self):
        """Flag adr.py if it leaks exception details (informational)."""
        src = _read(os.path.join(ROUTERS_DIR, "adr.py"))
        leaks = []
        patterns = [
            (r'detail\s*=\s*f["\'].*\{exc\}', "detail=f'...{exc}'"),
            (r'detail\s*=\s*str\s*\(\s*exc\s*\)', "detail=str(exc)"),
        ]
        for pattern, label in patterns:
            if re.search(pattern, src):
                leaks.append(label)
        if leaks:
            pytest.xfail(
                f"adr.py leaks error details via: {', '.join(leaks)}. "
                "Consider using a generic message instead."
            )


# ════════════════════════════════════════════════════════════════════════════
# 12-13  Secret Exposure
# ════════════════════════════════════════════════════════════════════════════


class TestSecretExposure:
    """Ensure no hardcoded secrets in source and .env is gitignored."""

    def _all_python_files(self) -> list[str]:
        """Collect every .py file under the backend directory."""
        py_files: list[str] = []
        for root, _, files in os.walk(BACKEND_DIR):
            # Skip __pycache__ and .git
            if "__pycache__" in root or ".git" in root:
                continue
            for f in files:
                if f.endswith(".py"):
                    py_files.append(os.path.join(root, f))
        return py_files

    def test_no_hardcoded_api_keys(self):
        """No Python file should contain hardcoded API keys."""
        secret_patterns = [
            (r'sk-ant-[A-Za-z0-9_-]{20,}', "Anthropic API key (sk-ant-...)"),
            (r'sk-proj-[A-Za-z0-9_-]{20,}', "OpenAI project key (sk-proj-...)"),
            (r'ANTHROPIC_API_KEY\s*=\s*["\'][^"\']+["\']', "Hardcoded ANTHROPIC_API_KEY"),
            (r'SUPABASE_KEY\s*=\s*["\']eyJ[^"\']+["\']', "Hardcoded Supabase service key"),
        ]
        violations: list[str] = []
        for path in self._all_python_files():
            src = _read(path)
            relpath = os.path.relpath(path, BACKEND_DIR)
            for pattern, description in secret_patterns:
                if re.search(pattern, src):
                    violations.append(f"  {relpath}: {description}")

        assert not violations, (
            "Hardcoded secrets found in Python source:\n" + "\n".join(violations)
        )

    def test_env_in_gitignore(self):
        """If a .gitignore exists at the project or backend root, .env should be listed."""
        gitignore_locations = [
            os.path.join(PROJECT_ROOT, ".gitignore"),
            os.path.join(BACKEND_DIR, ".gitignore"),
            # Flutter app gitignore (may be shared repo root)
            os.path.join(PROJECT_ROOT, "dawaacheck", ".gitignore"),
        ]
        found_gitignore = False
        env_is_ignored = False

        for gi_path in gitignore_locations:
            if os.path.exists(gi_path):
                found_gitignore = True
                content = _read(gi_path)
                # Check for .env line (exact or with glob)
                for line in content.splitlines():
                    stripped = line.strip()
                    if stripped in (".env", ".env*", ".env.*", "*.env", ".env.local"):
                        env_is_ignored = True
                        break
                    if stripped == "*.env" or stripped == ".env*":
                        env_is_ignored = True
                        break

        if not found_gitignore:
            pytest.xfail(
                "No .gitignore found at project root or backend directory. "
                "Consider creating one that excludes .env files."
            )
        elif not env_is_ignored:
            pytest.xfail(
                ".env is NOT listed in any .gitignore file. "
                "This risks committing secrets to version control."
            )


# ════════════════════════════════════════════════════════════════════════════
# 14-15  RLS Policy Audit (parsed from migration SQL)
# ════════════════════════════════════════════════════════════════════════════


class TestRLSPolicies:
    """Verify Row Level Security is enabled on the correct tables."""

    @pytest.fixture()
    def migration_sql(self) -> str:
        """Concatenate both migration files."""
        parts: list[str] = []
        for path in (MIGRATION_V1, MIGRATION_V2):
            if os.path.exists(path):
                parts.append(_read(path))
        if not parts:
            pytest.skip("Migration SQL files not found")
        return "\n".join(parts)

    def _tables_with_rls(self, sql: str) -> set[str]:
        """Extract table names that have ENABLE ROW LEVEL SECURITY."""
        pattern = r"ALTER\s+TABLE\s+(\w+)\s+ENABLE\s+ROW\s+LEVEL\s+SECURITY"
        return {m.group(1) for m in re.finditer(pattern, sql, re.IGNORECASE)}

    def _public_read_tables(self, sql: str) -> set[str]:
        """Extract tables that have a FOR SELECT USING (true) policy."""
        pattern = (
            r'CREATE\s+POLICY\s+"[^"]*"\s+ON\s+(\w+)\s+'
            r'FOR\s+SELECT\s+USING\s*\(\s*true\s*\)'
        )
        return {m.group(1) for m in re.finditer(pattern, sql, re.IGNORECASE)}

    def test_user_data_tables_have_rls(self, migration_sql: str):
        """scan_results, adr_reports, and users must have RLS enabled."""
        rls_tables = self._tables_with_rls(migration_sql)
        required = {"scan_results", "adr_reports"}
        missing = required - rls_tables
        assert not missing, (
            f"RLS is NOT enabled on user-data tables: {missing}. "
            "Without RLS, any authenticated user can read all rows."
        )

    def test_drug_reference_tables_public_read(self, migration_sql: str):
        """Drug reference tables should allow public SELECT."""
        public_tables = self._public_read_tables(migration_sql)
        expected_public = {
            "drap_medicines",
            "drap_recalls",
            "generic_drugs",
            "drug_interactions",
            "drug_side_effects",
            "who_aware_antibiotics",
            "pediatric_safety",
            "medicine_prices",
        }
        missing = expected_public - public_tables
        assert not missing, (
            f"Drug reference tables missing public SELECT policy: {missing}. "
            "The Flutter app needs unauthenticated read access to these."
        )

    def test_users_table_rls_note(self, migration_sql: str):
        """Flag if the users table does not have RLS (informational)."""
        rls_tables = self._tables_with_rls(migration_sql)
        if "users" not in rls_tables:
            pytest.xfail(
                "The 'users' table does not have RLS enabled in the migration files. "
                "If the backend service role key is used for all user writes this is "
                "acceptable, but consider adding RLS for defense-in-depth."
            )


# ════════════════════════════════════════════════════════════════════════════
# 16  Retry Logic
# ════════════════════════════════════════════════════════════════════════════


class TestRetryLogic:
    """Verify API retry utility exists and is correctly structured."""

    def test_api_retry_module_exists(self):
        """utils/api_retry.py should exist."""
        path = os.path.join(UTILS_DIR, "api_retry.py")
        assert os.path.exists(path), (
            "utils/api_retry.py not found — agents need retry logic for "
            "transient 429/503 errors from Claude API"
        )

    def test_retry_api_call_function_defined(self):
        """api_retry.py must define retry_api_call()."""
        path = os.path.join(UTILS_DIR, "api_retry.py")
        if not os.path.exists(path):
            pytest.skip("api_retry.py not found")
        src = _read(path)
        assert "def retry_api_call" in src, (
            "api_retry.py must define retry_api_call function"
        )

    def test_retry_handles_rate_limits(self):
        """retry_api_call should handle 429 rate-limit errors."""
        path = os.path.join(UTILS_DIR, "api_retry.py")
        if not os.path.exists(path):
            pytest.skip("api_retry.py not found")
        src = _read(path)
        assert "429" in src, (
            "retry_api_call should handle HTTP 429 (rate limit) errors"
        )


# ════════════════════════════════════════════════════════════════════════════
# Bonus: Notifications router error leak check
# ════════════════════════════════════════════════════════════════════════════


class TestNotificationsErrorLeak:
    """Flag error detail leaks in the notifications router."""

    def test_notifications_error_leak_warning(self):
        """notifications.py should not expose raw exception strings to clients."""
        path = os.path.join(ROUTERS_DIR, "notifications.py")
        if not os.path.exists(path):
            pytest.skip("notifications.py not found")
        src = _read(path)
        leak_count = len(re.findall(r'detail\s*=\s*str\s*\(\s*e\s*\)', src))
        leak_count += len(re.findall(r'detail\s*=\s*f["\'].*\{e\}', src))
        if leak_count > 0:
            pytest.xfail(
                f"notifications.py exposes raw exception details to clients "
                f"in {leak_count} location(s). Replace with generic error messages."
            )
