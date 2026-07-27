"""
DawaaCheck AI Agents Package
10 named AI agents for medicine verification in Pakistan.

 1. RAKIB  (The Watchman)       — DRAP Registration & Authenticity
 2. KASHIF (The Revealer)       — Barcode & Tamper Detection
 3. MUNZIR (The Warner)         — Recall Status Checker
 4. BASIR  (The All-Seeing)     — Ingredient Verification
 5. ADIL   (The Just One)       — Price & Alternative Finder
 6. HAKIM  (The Wise Judge)     — Final Verdict Synthesizer
 7. HIFAZAT(The Protector)      — Antimicrobial Resistance Guard
 8. SHAFIQ (The Compassionate)  — Pediatric Safety Checker
 9. SHAHID (The Witness)        — ADR Reporter (Naranjo Algorithm)
10. RAFIQ  (The Companion)      — Drug Interaction Checker
"""

from .agent_1_registration import check_registration
from .agent_2_barcode import validate_barcode
from .agent_3_recall import check_recall
from .agent_4_ingredients import verify_ingredients
from .agent_5_price import verify_price
from .agent_6_verdict import synthesize_verdict
from .agent_7_amr import check_amr
from .agent_8_pediatric import check_pediatric
from .agent_9_adr import process_adr_report
from .agent_10_interactions import check_interactions
from .crew_config import build_and_run_crew, build_and_run_crew_async

__all__ = [
    "check_registration",
    "validate_barcode",
    "check_recall",
    "verify_ingredients",
    "verify_price",
    "synthesize_verdict",
    "check_amr",
    "check_pediatric",
    "process_adr_report",
    "check_interactions",
    "build_and_run_crew",
    "build_and_run_crew_async",
]
