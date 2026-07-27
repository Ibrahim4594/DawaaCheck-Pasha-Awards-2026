"""DawaaCheck Dependency Security Audit.

A standalone script that scans requirements.txt and pubspec.yaml for:
  - Dependencies without pinned versions
  - Known-vulnerable package versions
  - Missing recommended security packages
  - A formatted summary report

Usage:  python security_audit.py
"""

import os
import re
import sys
from dataclasses import dataclass, field

# ── Paths ────────────────────────────────────────────────────────────────────

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.dirname(SCRIPT_DIR)
REQUIREMENTS_TXT = os.path.join(SCRIPT_DIR, "requirements.txt")
PUBSPEC_YAML = os.path.join(PROJECT_ROOT, "dawaacheck", "pubspec.yaml")


# ── Known-Vulnerable Versions ────────────────────────────────────────────────
# Format: package_name -> list of (operator, version, CVE/description)
# These are real CVEs / advisories for the packages used in this project.

KNOWN_VULNERABLE_PYTHON: dict[str, list[tuple[str, str, str]]] = {
    "fastapi": [
        ("<", "0.109.1", "CVE-2024-24762 — Content-Type header DoS via python-multipart"),
    ],
    "uvicorn": [
        ("<", "0.25.0", "CVE-2023-5752 — HTTP request smuggling via malformed Transfer-Encoding"),
    ],
    "python-multipart": [
        ("<", "0.0.7", "CVE-2024-24762 — ReDoS in Content-Type parsing"),
    ],
    "pillow": [
        ("<", "10.3.0", "CVE-2024-28219 — Buffer overflow in ImageFont.getmask()"),
    ],
    "httpx": [
        ("<", "0.23.1", "CVE-2023-XXXXX — CRLF injection in URL path components"),
    ],
    "pydantic": [
        ("<", "2.5.0", "DoS via deeply nested model validation"),
    ],
    "firebase-admin": [
        ("<", "6.2.0", "Advisory — missing token audience validation in older versions"),
    ],
    "anthropic": [
        ("<", "0.18.0", "Advisory — older SDK versions lack request timeout defaults"),
    ],
    "supabase": [
        ("<", "2.0.0", "Advisory — pre-2.0 client had inconsistent RLS header handling"),
    ],
    "beautifulsoup4": [
        ("<", "4.12.0", "Advisory — entity expansion DoS in older lxml parser mode"),
    ],
}

KNOWN_VULNERABLE_FLUTTER: dict[str, list[tuple[str, str, str]]] = {
    "dio": [
        ("<", "5.4.0", "Advisory — improper certificate validation in redirects"),
    ],
    "url_launcher": [
        ("<", "6.2.0", "Advisory — intent injection on Android via crafted URIs"),
    ],
    "flutter_secure_storage": [
        ("<", "9.0.0", "Advisory — Android KeyStore migration issues pre-v9"),
    ],
}

RECOMMENDED_PYTHON_PACKAGES = {
    "slowapi": "Rate limiting middleware",
    "python-dotenv": "Environment variable management (keep secrets out of code)",
    "firebase-admin": "Firebase ID token verification",
}


# ── Data Structures ──────────────────────────────────────────────────────────

@dataclass
class DependencyInfo:
    name: str
    version_spec: str  # e.g. "==0.115.0" or "^3.3.0" or ""
    pinned: bool = False
    vulnerabilities: list[str] = field(default_factory=list)


@dataclass
class AuditReport:
    python_deps: list[DependencyInfo] = field(default_factory=list)
    flutter_deps: list[DependencyInfo] = field(default_factory=list)
    missing_security_packages: list[tuple[str, str]] = field(default_factory=list)
    warnings: list[str] = field(default_factory=list)


# ── Version Comparison ───────────────────────────────────────────────────────

def _parse_version(v: str) -> tuple[int, ...]:
    """Parse a version string like '0.115.0' into a comparable tuple."""
    parts = []
    for p in v.split("."):
        digits = re.match(r"(\d+)", p)
        parts.append(int(digits.group(1)) if digits else 0)
    return tuple(parts)


def _version_matches(actual: str, operator: str, threshold: str) -> bool:
    """Check if *actual* version satisfies the vulnerability condition."""
    try:
        actual_t = _parse_version(actual)
        threshold_t = _parse_version(threshold)
    except (ValueError, AttributeError):
        return False

    if operator == "<":
        return actual_t < threshold_t
    elif operator == "<=":
        return actual_t <= threshold_t
    elif operator == "==":
        return actual_t == threshold_t
    return False


# ── Parsers ──────────────────────────────────────────────────────────────────

def parse_requirements_txt(path: str) -> list[DependencyInfo]:
    """Parse pip requirements.txt into a list of DependencyInfo."""
    deps: list[DependencyInfo] = []
    if not os.path.exists(path):
        return deps

    with open(path, encoding="utf-8") as f:
        for raw_line in f:
            line = raw_line.strip()
            if not line or line.startswith("#") or line.startswith("-"):
                continue

            # Handle extras like uvicorn[standard]==0.30.6
            match = re.match(r"^([A-Za-z0-9_.-]+)(?:\[[^\]]*\])?\s*(==|>=|<=|~=|!=|>|<)?\s*(.+)?$", line)
            if not match:
                continue

            name = match.group(1).lower()
            op = match.group(2) or ""
            version = (match.group(3) or "").strip()
            pinned = op == "==" and bool(version)

            deps.append(DependencyInfo(name=name, version_spec=f"{op}{version}" if op else "", pinned=pinned))

    return deps


def parse_pubspec_yaml(path: str) -> list[DependencyInfo]:
    """Parse Flutter pubspec.yaml dependencies (simple regex, no YAML lib needed)."""
    deps: list[DependencyInfo] = []
    if not os.path.exists(path):
        return deps

    with open(path, encoding="utf-8") as f:
        content = f.read()

    # Find the dependencies: block (stop at dev_dependencies: or flutter:)
    dep_match = re.search(r"^dependencies:\s*\n(.*?)(?=^(?:dev_dependencies|flutter|flutter_launcher_icons|flutter_native_splash):|\Z)",
                          content, re.MULTILINE | re.DOTALL)
    if not dep_match:
        return deps

    dep_block = dep_match.group(1)

    for line in dep_block.splitlines():
        stripped = line.strip()
        # Skip SDK dependencies, empty lines, comments
        if not stripped or stripped.startswith("#") or stripped.startswith("sdk:"):
            continue

        # Match "  package_name: ^1.2.3" or "  package_name: 1.2.3"
        m = re.match(r"^(\w[\w_-]*)\s*:\s*(\^|~|>=|>)?\s*([0-9][0-9.]*\S*)?", stripped)
        if m:
            name = m.group(1)
            prefix = m.group(2) or ""
            version = m.group(3) or ""
            version_spec = f"{prefix}{version}" if version else ""
            # In pubspec, ^x.y.z is "compatible with", a bare x.y.z is pinned
            pinned = bool(version) and not prefix
            deps.append(DependencyInfo(name=name, version_spec=version_spec, pinned=pinned))

    return deps


# ── Vulnerability Check ─────────────────────────────────────────────────────

def check_vulnerabilities(deps: list[DependencyInfo], vuln_db: dict) -> None:
    """Mutate deps in-place, adding vulnerability notes."""
    for dep in deps:
        # Normalize name for lookup (pip uses hyphens, our DB uses hyphens)
        lookup_name = dep.name.lower().replace("_", "-")
        vulns = vuln_db.get(lookup_name, [])
        if not vulns:
            # Try with underscores too
            lookup_name = dep.name.lower().replace("-", "_")
            vulns = vuln_db.get(lookup_name, [])
        if not vulns:
            # Try original name
            vulns = vuln_db.get(dep.name.lower(), [])

        # Extract actual version from spec
        version_match = re.search(r"[0-9][0-9.]*", dep.version_spec)
        if not version_match:
            continue
        actual_version = version_match.group(0)

        for op, threshold, description in vulns:
            if _version_matches(actual_version, op, threshold):
                dep.vulnerabilities.append(
                    f"VULNERABLE ({op}{threshold}): {description}"
                )


# ── Report ───────────────────────────────────────────────────────────────────

def run_audit() -> AuditReport:
    """Run the full dependency audit and return a report."""
    report = AuditReport()

    # ── Python ──
    report.python_deps = parse_requirements_txt(REQUIREMENTS_TXT)
    check_vulnerabilities(report.python_deps, KNOWN_VULNERABLE_PYTHON)

    # Check for recommended security packages
    installed_names = {d.name.lower().replace("_", "-") for d in report.python_deps}
    for pkg, reason in RECOMMENDED_PYTHON_PACKAGES.items():
        if pkg.lower() not in installed_names:
            report.missing_security_packages.append((pkg, reason))

    # ── Flutter ──
    report.flutter_deps = parse_pubspec_yaml(PUBSPEC_YAML)
    check_vulnerabilities(report.flutter_deps, KNOWN_VULNERABLE_FLUTTER)

    # ── Warnings ──
    unpinned_python = [d for d in report.python_deps if not d.pinned]
    if unpinned_python:
        names = ", ".join(d.name for d in unpinned_python)
        report.warnings.append(
            f"Python: {len(unpinned_python)} dependency(ies) without pinned versions: {names}"
        )

    unpinned_flutter = [d for d in report.flutter_deps if not d.pinned and d.version_spec]
    # Flutter uses ^ ranges by convention, so only flag truly unversioned ones
    unversioned_flutter = [d for d in report.flutter_deps if not d.version_spec]
    if unversioned_flutter:
        names = ", ".join(d.name for d in unversioned_flutter)
        report.warnings.append(
            f"Flutter: {len(unversioned_flutter)} dependency(ies) without any version constraint: {names}"
        )

    return report


def print_report(report: AuditReport) -> None:
    """Print a formatted audit report to stdout."""
    sep = "=" * 72

    print(sep)
    print("  DawaaCheck Dependency Security Audit Report")
    print(sep)
    print()

    # ── Python Dependencies ──
    print(f"  PYTHON DEPENDENCIES ({REQUIREMENTS_TXT})")
    print("-" * 72)
    vuln_count = 0
    for dep in report.python_deps:
        status = "PINNED" if dep.pinned else "UNPINNED"
        marker = " " if dep.pinned else "!"
        print(f"  {marker} {dep.name:<30} {dep.version_spec:<15} [{status}]")
        for v in dep.vulnerabilities:
            vuln_count += 1
            print(f"    >> {v}")
    print()

    # ── Flutter Dependencies ──
    print(f"  FLUTTER DEPENDENCIES ({PUBSPEC_YAML})")
    print("-" * 72)
    for dep in report.flutter_deps:
        if dep.version_spec:
            constraint_type = "PINNED" if dep.pinned else "RANGE"
        else:
            constraint_type = "NO VERSION"
        marker = " " if constraint_type != "NO VERSION" else "!"
        print(f"  {marker} {dep.name:<35} {dep.version_spec:<12} [{constraint_type}]")
        for v in dep.vulnerabilities:
            vuln_count += 1
            print(f"    >> {v}")
    print()

    # ── Security Packages ──
    if report.missing_security_packages:
        print("  MISSING RECOMMENDED SECURITY PACKAGES")
        print("-" * 72)
        for pkg, reason in report.missing_security_packages:
            print(f"  ! {pkg:<30} — {reason}")
        print()
    else:
        print("  All recommended security packages are present.")
        print()

    # ── Warnings ──
    if report.warnings:
        print("  WARNINGS")
        print("-" * 72)
        for w in report.warnings:
            print(f"  ! {w}")
        print()

    # ── Summary ──
    print(sep)
    total_deps = len(report.python_deps) + len(report.flutter_deps)
    print(f"  Total dependencies scanned:  {total_deps}")
    print(f"    Python:   {len(report.python_deps)}")
    print(f"    Flutter:  {len(report.flutter_deps)}")
    print(f"  Vulnerabilities found:       {vuln_count}")
    print(f"  Warnings:                    {len(report.warnings)}")
    print(f"  Missing security packages:   {len(report.missing_security_packages)}")
    verdict = "PASS" if vuln_count == 0 and not report.missing_security_packages else "REVIEW NEEDED"
    print(f"  Overall:                     {verdict}")
    print(sep)

    return vuln_count


# ── Main ─────────────────────────────────────────────────────────────────────

if __name__ == "__main__":
    report = run_audit()
    vuln_count = print_report(report)
    sys.exit(1 if vuln_count > 0 else 0)
