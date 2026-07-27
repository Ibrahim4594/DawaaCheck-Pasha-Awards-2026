"""
conftest.py — Isolated import of agent_6_verdict.

The agents/__init__.py imports ALL agents (1-10), which pull in heavy
dependencies like ``anthropic``.  We only need agent_6_verdict for these
tests, so we load it directly via importlib to avoid the package init.
"""

import importlib.util
import sys
from pathlib import Path

# Resolve paths
_backend_dir = Path(__file__).resolve().parent.parent
_module_path = _backend_dir / "agents" / "agent_6_verdict.py"

# Load agent_6_verdict as a standalone module (skip agents/__init__.py)
_spec = importlib.util.spec_from_file_location(
    "agents.agent_6_verdict",
    str(_module_path),
)
_module = importlib.util.module_from_spec(_spec)
sys.modules["agents.agent_6_verdict"] = _module
_spec.loader.exec_module(_module)
