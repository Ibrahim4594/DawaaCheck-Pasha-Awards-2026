"""
Central model configuration.

Three of the ten agents call Claude, and all three read a label from a
photograph: RAKIB (registration), KASHIF (barcode and tamper) and BASIR
(ingredients). Keeping the model id in one place means it can be changed — or
pinned for a reproducible evaluation — without editing agent code.

The remaining seven agents are deterministic: recall matching, MRP checking,
WHO AWaRe classification, weight-based paediatric dosing, Naranjo causality
scoring, the interaction matrix, and verdict synthesis all run as rules against
the database. That is a deliberate choice — a safety verdict should be
reproducible and auditable, not resampled from a model on every scan.
"""

import os

#: Model used by the vision agents. Override with ANTHROPIC_VISION_MODEL.
VISION_MODEL: str = os.getenv("ANTHROPIC_VISION_MODEL", "claude-opus-4-6")

#: Output ceilings per agent, sized to the structured JSON each one returns.
MAX_TOKENS_REGISTRATION: int = 4096
MAX_TOKENS_BARCODE: int = 2048
MAX_TOKENS_INGREDIENTS: int = 4096
