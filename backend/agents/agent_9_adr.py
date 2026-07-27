"""Agent 9 — SHAHID (The Witness)
ADR (Adverse Drug Reaction) Reporter
Processes ADR reports with Naranjo causality assessment, Supabase-backed signal
detection, MedDRA SOC categorization, report quality scoring, and Pakistan
pharmacovigilance context.

Data sources:
  - Supabase tables: openfda_adverse_events, drug_side_effects
  - OpenFDA live API: real-time FAERS signal detection
"""

import asyncio
import logging
import uuid
from datetime import datetime, timezone
from typing import Optional

from data.api_clients import openfda_client
from utils.supabase_client import get_supabase

logger = logging.getLogger(__name__)

AGENT_NUMBER = 9
AGENT_NAME = "SHAHID — The Witness"

# ---------------------------------------------------------------------------
# MedDRA System Organ Class (SOC) hierarchy with symptom mappings
# ---------------------------------------------------------------------------
MEDDRA_SOC: dict[str, dict] = {
    "Gastrointestinal disorders": {
        "code": "10017947",
        "terms": [
            "nausea", "vomiting", "diarrhea", "diarrhoea", "constipation",
            "abdominal pain", "stomach upset", "stomach pain", "dyspepsia",
            "gastritis", "bloating", "flatulence", "acid reflux", "heartburn",
            "gi bleed", "melena", "hematemesis", "pancreatitis",
        ],
    },
    "Skin and subcutaneous tissue disorders": {
        "code": "10040785",
        "terms": [
            "rash", "itching", "pruritus", "hives", "urticaria", "skin reaction",
            "swelling", "dermatitis", "eczema", "skin peeling", "blistering",
            "photosensitivity", "erythema", "acne", "alopecia", "hair loss",
            "stevens-johnson", "sjs", "toxic epidermal necrolysis", "ten",
        ],
    },
    "Nervous system disorders": {
        "code": "10029205",
        "terms": [
            "headache", "dizziness", "drowsiness", "insomnia", "tremor",
            "seizure", "convulsion", "vertigo", "paresthesia", "numbness",
            "tingling", "confusion", "ataxia", "syncope", "fainting",
            "neuropathy", "stroke", "cerebrovascular",
        ],
    },
    "Cardiac disorders": {
        "code": "10007541",
        "terms": [
            "palpitation", "palpitations", "chest pain", "tachycardia",
            "bradycardia", "arrhythmia", "cardiac arrest", "heart attack",
            "myocardial infarction", "heart failure", "qt prolongation",
            "atrial fibrillation",
        ],
    },
    "Vascular disorders": {
        "code": "10047065",
        "terms": [
            "hypertension", "hypotension", "high blood pressure",
            "low blood pressure", "deep vein thrombosis", "dvt",
            "pulmonary embolism", "bleeding", "hemorrhage", "bruising",
        ],
    },
    "Respiratory, thoracic and mediastinal disorders": {
        "code": "10038738",
        "terms": [
            "cough", "dyspnea", "shortness of breath", "wheezing",
            "bronchospasm", "asthma", "respiratory failure",
            "pulmonary edema", "pneumonitis", "interstitial lung disease",
        ],
    },
    "Immune system disorders": {
        "code": "10021428",
        "terms": [
            "anaphylaxis", "anaphylactic", "angioedema", "allergic reaction",
            "allergy", "swelling of face", "difficulty breathing",
            "hypersensitivity", "serum sickness", "drug reaction with eosinophilia",
            "dress syndrome",
        ],
    },
    "Hepatobiliary disorders": {
        "code": "10019805",
        "terms": [
            "jaundice", "liver injury", "elevated liver enzymes",
            "hepatitis", "hepatotoxicity", "liver failure",
            "cholestasis", "alt elevated", "ast elevated", "bilirubin elevated",
        ],
    },
    "Renal and urinary disorders": {
        "code": "10038359",
        "terms": [
            "kidney injury", "renal failure", "decreased urine output",
            "blood in urine", "hematuria", "proteinuria", "nephritis",
            "acute kidney injury", "aki", "renal impairment",
        ],
    },
    "Blood and lymphatic system disorders": {
        "code": "10005329",
        "terms": [
            "anemia", "anaemia", "thrombocytopenia", "neutropenia",
            "pancytopenia", "leukopenia", "agranulocytosis",
            "bleeding disorder", "coagulopathy", "disseminated intravascular",
        ],
    },
    "Musculoskeletal and connective tissue disorders": {
        "code": "10028395",
        "terms": [
            "muscle pain", "myalgia", "arthralgia", "joint pain",
            "back pain", "muscle weakness", "rhabdomyolysis",
            "tendon rupture", "tendinitis", "bone pain",
        ],
    },
    "Psychiatric disorders": {
        "code": "10037175",
        "terms": [
            "depression", "anxiety", "suicidal", "suicide", "hallucination",
            "psychosis", "mania", "agitation", "panic", "mood changes",
            "behavioral changes", "nightmares",
        ],
    },
    "Metabolism and nutrition disorders": {
        "code": "10027433",
        "terms": [
            "hypoglycemia", "hyperglycemia", "hyponatremia", "hyperkalemia",
            "hypokalemia", "lactic acidosis", "weight gain", "weight loss",
            "appetite loss", "appetite increased", "dehydration",
        ],
    },
    "Infections and infestations": {
        "code": "10021881",
        "terms": [
            "infection", "sepsis", "candidiasis", "opportunistic infection",
            "clostridium difficile", "c diff", "superinfection",
        ],
    },
    "General disorders and administration site conditions": {
        "code": "10018065",
        "terms": [
            "fatigue", "fever", "chills", "malaise", "injection site reaction",
            "edema", "swelling", "pain", "weakness", "asthenia",
            "drug ineffective", "drug interaction",
        ],
    },
    "Eye disorders": {
        "code": "10015919",
        "terms": [
            "blurred vision", "vision loss", "visual disturbance",
            "eye pain", "conjunctivitis", "dry eyes", "glaucoma",
        ],
    },
    "Ear and labyrinth disorders": {
        "code": "10013993",
        "terms": [
            "tinnitus", "hearing loss", "ear pain", "ototoxicity",
            "vertigo",
        ],
    },
    "Reproductive system and breast disorders": {
        "code": "10038604",
        "terms": [
            "gynecomastia", "sexual dysfunction", "erectile dysfunction",
            "menstrual irregularity", "infertility",
        ],
    },
    "Endocrine disorders": {
        "code": "10014698",
        "terms": [
            "thyroid disorder", "hypothyroidism", "hyperthyroidism",
            "adrenal insufficiency", "cushing",
        ],
    },
}

# Symptom-to-medical-term mapping (user language -> MedDRA preferred term)
SYMPTOM_TO_MEDICAL: dict[str, str] = {
    "stomach upset": "Dyspepsia",
    "stomach pain": "Abdominal pain",
    "throwing up": "Vomiting",
    "feeling sick": "Nausea",
    "loose stools": "Diarrhoea",
    "can't sleep": "Insomnia",
    "trouble sleeping": "Insomnia",
    "dizzy": "Dizziness",
    "feeling dizzy": "Dizziness",
    "skin rash": "Rash",
    "itchy skin": "Pruritus",
    "swollen face": "Facial swelling",
    "hard to breathe": "Dyspnoea",
    "breathing difficulty": "Dyspnoea",
    "heart racing": "Tachycardia",
    "fast heartbeat": "Tachycardia",
    "slow heartbeat": "Bradycardia",
    "yellow skin": "Jaundice",
    "yellow eyes": "Jaundice",
    "bloody urine": "Haematuria",
    "blood in urine": "Haematuria",
    "muscle ache": "Myalgia",
    "joint ache": "Arthralgia",
    "feeling tired": "Fatigue",
    "exhaustion": "Fatigue",
    "high blood pressure": "Hypertension",
    "low blood pressure": "Hypotension",
    "hair falling out": "Alopecia",
    "weight gain": "Weight increased",
    "weight loss": "Weight decreased",
    "suicidal thoughts": "Suicidal ideation",
    "blurry vision": "Vision blurred",
    "ringing in ears": "Tinnitus",
}

# Severity indicator keywords
SEVERITY_CRITICAL = [
    "died", "death", "fatal", "cardiac arrest", "respiratory arrest",
    "anaphylactic shock", "coma", "brain death",
]
SEVERITY_SEVERE = [
    "severe", "emergency", "hospitalized", "hospitalised", "icu",
    "intensive care", "life threatening", "life-threatening",
    "anaphylaxis", "seizure", "convulsion", "stroke",
    "liver failure", "renal failure", "kidney failure",
    "stevens-johnson", "toxic epidermal", "sjs", "ten",
]
SEVERITY_MODERATE = [
    "moderate", "persistent", "worsening", "significant",
    "required treatment", "doctor visit", "clinic",
]

# Seriousness criteria (ICH E2B standard)
SERIOUSNESS_CRITERIA = [
    "death",
    "life_threatening",
    "hospitalization",
    "disability",
    "congenital_anomaly",
    "medically_important",
]

# Pakistan pharmacovigilance information
PAKISTAN_PV_INFO = {
    "authority": "Drug Regulatory Authority of Pakistan (DRAP)",
    "reporting_url": "https://www.dfrh.org/index.php/adr-online-reporting-form",
    "website": "https://www.drap.gov.pk",
    "hotline": "0800-33727 (toll-free)",
    "email": "pharmacovigilance@drap.gov.pk",
    "note": (
        "Pakistan has one of the lowest ADR reporting rates in Asia. "
        "Every report matters and helps protect patients across the country. "
        "Healthcare professionals and consumers can submit reports directly to DRAP."
    ),
}


# ---------------------------------------------------------------------------
# Async helper
# ---------------------------------------------------------------------------

def _run_async_safely(coro):
    """Run an async coroutine safely from a sync context."""
    try:
        loop = asyncio.get_event_loop()
        if loop.is_running():
            import concurrent.futures
            with concurrent.futures.ThreadPoolExecutor() as pool:
                return pool.submit(asyncio.run, coro).result(timeout=20)
        else:
            return asyncio.run(coro)
    except RuntimeError:
        return asyncio.run(coro)
    except Exception as exc:
        logger.warning("Async call failed: %s", exc)
        return None


# ---------------------------------------------------------------------------
# Supabase queries
# ---------------------------------------------------------------------------

def _query_supabase_adverse_events(drug_name: str) -> list[dict]:
    """
    Query the openfda_adverse_events table for existing adverse event profiles.
    Returns a list of stored adverse event records for the given drug.
    """
    if not drug_name:
        return []
    try:
        sb = get_supabase()
        # Try exact match first, then ilike
        result = sb.table("openfda_adverse_events").select("*").ilike(
            "drug_name", f"%{drug_name}%"
        ).execute()
        return result.data if result.data else []
    except Exception as exc:
        logger.warning("Supabase openfda_adverse_events query failed for '%s': %s", drug_name, exc)
        return []


def _query_supabase_side_effects(drug_name: str) -> Optional[dict]:
    """
    Query the drug_side_effects table to retrieve known side effects.
    Returns the side effect record or None.
    """
    if not drug_name:
        return None
    try:
        sb = get_supabase()
        result = sb.table("drug_side_effects").select("*").ilike(
            "drug_name", f"%{drug_name}%"
        ).limit(1).execute()
        if result.data:
            return result.data[0]
        return None
    except Exception as exc:
        logger.warning("Supabase drug_side_effects query failed for '%s': %s", drug_name, exc)
        return None


# ---------------------------------------------------------------------------
# MedDRA SOC categorization
# ---------------------------------------------------------------------------

def _categorize_reaction_meddra(reaction_description: str) -> dict:
    """
    Categorize the reaction using MedDRA System Organ Class hierarchy.
    Returns SOC matches with codes and mapped medical terms.
    """
    desc_lower = reaction_description.lower()

    matched_socs: list[dict] = []
    matched_medical_terms: list[str] = []

    # Map user symptoms to medical terms
    for user_term, medical_term in SYMPTOM_TO_MEDICAL.items():
        if user_term in desc_lower:
            matched_medical_terms.append(medical_term)

    # Match against MedDRA SOC hierarchy
    for soc_name, soc_data in MEDDRA_SOC.items():
        matching_terms = [t for t in soc_data["terms"] if t in desc_lower]
        if matching_terms:
            matched_socs.append({
                "soc_name": soc_name,
                "soc_code": soc_data["code"],
                "matched_terms": matching_terms,
            })

    # Detect severity
    severity = "mild"
    severity_indicators: list[str] = []
    for kw in SEVERITY_CRITICAL:
        if kw in desc_lower:
            severity = "critical"
            severity_indicators.append(kw)
    if severity != "critical":
        for kw in SEVERITY_SEVERE:
            if kw in desc_lower:
                severity = "severe"
                severity_indicators.append(kw)
    if severity not in ("critical", "severe"):
        for kw in SEVERITY_MODERATE:
            if kw in desc_lower:
                severity = "moderate"
                severity_indicators.append(kw)

    return {
        "soc_classifications": matched_socs if matched_socs else [{
            "soc_name": "General disorders and administration site conditions",
            "soc_code": "10018065",
            "matched_terms": [],
        }],
        "mapped_medical_terms": matched_medical_terms,
        "detected_severity": severity,
        "severity_indicators": severity_indicators,
        "primary_soc": matched_socs[0]["soc_name"] if matched_socs else "Uncategorized",
    }


# ---------------------------------------------------------------------------
# Naranjo Causality Assessment Algorithm
# ---------------------------------------------------------------------------

def _naranjo_assessment(
    report_data: dict,
    openfda_events: list,
    openfda_counts: dict,
    supabase_ae: list[dict],
    side_effects_record: Optional[dict],
) -> dict:
    """
    Implement the standard Naranjo Adverse Drug Reaction Probability Scale.

    10 questions, each scored as Yes / No / Don't Know:
      Q1:  Are there previous conclusive reports on this reaction?
      Q2:  Did the adverse event appear after the suspected drug was given?
      Q3:  Did the adverse reaction improve when the drug was discontinued or
           a specific antagonist was given?
      Q4:  Did the adverse reaction reappear when the drug was re-administered?
      Q5:  Are there alternative causes that could have caused the reaction?
      Q6:  Did the reaction reappear when a placebo was given?
      Q7:  Was the drug detected in blood (or other fluids) in concentrations
           known to be toxic?
      Q8:  Was the reaction more severe when the dose was increased or less
           severe when the dose was decreased?
      Q9:  Did the patient have a similar reaction to the same or similar drugs
           in a previous exposure?
      Q10: Was the adverse event confirmed by any objective evidence?

    Scoring: Yes=+1/+2, No=-1/0, DontKnow=0 (varies per question)
    Total: -4 to +13
    Interpretation:
      >= 9  -> Definite
      5-8   -> Probable
      1-4   -> Possible
      <= 0  -> Doubtful
    """
    # Naranjo question weights: (yes_score, no_score, dk_score)
    QUESTION_WEIGHTS = {
        1: (+1, 0, 0),   # Previous conclusive reports
        2: (+2, -1, 0),  # Event after drug given (temporal)
        3: (+1, 0, 0),   # Improved on dechallenge
        4: (+2, -1, 0),  # Reappeared on rechallenge
        5: (-1, +2, 0),  # Alternative causes (Yes = bad)
        6: (-1, +1, 0),  # Reaction with placebo
        7: (+1, 0, 0),   # Toxic blood levels
        8: (+1, 0, 0),   # Dose-response
        9: (+1, 0, 0),   # Previous similar reaction
        10: (+1, 0, 0),  # Objective evidence
    }

    answers: dict[int, str] = {}
    question_details: list[dict] = []
    score = 0

    reaction_desc = report_data.get("reaction_description", "").lower()
    medicine = report_data.get("medicine_name", "")

    # --- Q1: Previous conclusive reports ---
    has_prior_reports = False
    prior_report_count = 0
    if openfda_counts:
        for term, count in openfda_counts.items():
            if any(w in term.lower() for w in reaction_desc.split() if len(w) > 3):
                has_prior_reports = True
                prior_report_count = max(prior_report_count, count)
                break
    if supabase_ae:
        has_prior_reports = True
    if side_effects_record:
        known_common = side_effects_record.get("common_side_effects", "") or ""
        known_serious = side_effects_record.get("serious_side_effects", "") or ""
        if any(w in (known_common + known_serious).lower() for w in reaction_desc.split() if len(w) > 3):
            has_prior_reports = True

    if has_prior_reports:
        answers[1] = "yes"
        score += QUESTION_WEIGHTS[1][0]
    else:
        answers[1] = "don't know"
        score += QUESTION_WEIGHTS[1][2]

    question_details.append({
        "question": "Are there previous conclusive reports on this reaction?",
        "answer": answers[1],
        "reasoning": f"OpenFDA reports found: {prior_report_count}, Supabase AE records: {len(supabase_ae)}",
    })

    # --- Q2: Temporal relationship (event appeared after drug?) ---
    onset = report_data.get("onset_date") or report_data.get("onset_time")
    if onset:
        answers[2] = "yes"
        score += QUESTION_WEIGHTS[2][0]
        q2_reason = f"Onset reported: {onset}"
    else:
        answers[2] = "don't know"
        score += QUESTION_WEIGHTS[2][2]
        q2_reason = "Onset time not provided"

    question_details.append({
        "question": "Did the adverse event appear after the suspected drug was given?",
        "answer": answers[2],
        "reasoning": q2_reason,
    })

    # --- Q3: Dechallenge (improved when drug stopped?) ---
    dechallenge = report_data.get("dechallenge") or report_data.get("drug_stopped")
    outcome = (report_data.get("outcome") or "").lower()
    if dechallenge or outcome in ("recovered", "recovering", "resolved"):
        answers[3] = "yes"
        score += QUESTION_WEIGHTS[3][0]
        q3_reason = f"Dechallenge positive / outcome: {outcome}"
    elif outcome in ("not recovered", "fatal", "not resolved"):
        answers[3] = "no"
        score += QUESTION_WEIGHTS[3][1]
        q3_reason = f"Outcome indicates no improvement: {outcome}"
    else:
        answers[3] = "don't know"
        score += QUESTION_WEIGHTS[3][2]
        q3_reason = "Dechallenge information not available"

    question_details.append({
        "question": "Did the adverse reaction improve when the drug was discontinued?",
        "answer": answers[3],
        "reasoning": q3_reason,
    })

    # --- Q4: Rechallenge (reappeared when drug re-given?) ---
    rechallenge = report_data.get("rechallenge")
    if rechallenge == "positive" or rechallenge is True:
        answers[4] = "yes"
        score += QUESTION_WEIGHTS[4][0]
        q4_reason = "Positive rechallenge reported"
    elif rechallenge == "negative" or rechallenge is False:
        answers[4] = "no"
        score += QUESTION_WEIGHTS[4][1]
        q4_reason = "Negative rechallenge reported"
    else:
        answers[4] = "don't know"
        score += QUESTION_WEIGHTS[4][2]
        q4_reason = "Rechallenge information not available"

    question_details.append({
        "question": "Did the adverse reaction reappear when the drug was re-administered?",
        "answer": answers[4],
        "reasoning": q4_reason,
    })

    # --- Q5: Alternative causes ---
    concomitant_meds = report_data.get("concomitant_medications", [])
    medical_history = report_data.get("medical_history", "")
    if concomitant_meds or medical_history:
        answers[5] = "yes"
        score += QUESTION_WEIGHTS[5][0]
        q5_reason = f"Concomitant meds: {len(concomitant_meds)}, medical history provided"
    else:
        answers[5] = "don't know"
        score += QUESTION_WEIGHTS[5][2]
        q5_reason = "No information on alternative causes"

    question_details.append({
        "question": "Are there alternative causes that could have caused the reaction?",
        "answer": answers[5],
        "reasoning": q5_reason,
    })

    # --- Q6: Placebo reaction ---
    # Almost never available in consumer reports
    answers[6] = "don't know"
    score += QUESTION_WEIGHTS[6][2]
    question_details.append({
        "question": "Did the reaction reappear when a placebo was given?",
        "answer": answers[6],
        "reasoning": "Placebo information not applicable in this context",
    })

    # --- Q7: Toxic blood levels ---
    blood_levels = report_data.get("blood_levels") or report_data.get("lab_results")
    if blood_levels:
        answers[7] = "yes"
        score += QUESTION_WEIGHTS[7][0]
        q7_reason = f"Lab/blood level data provided: {blood_levels}"
    else:
        answers[7] = "don't know"
        score += QUESTION_WEIGHTS[7][2]
        q7_reason = "No blood level data available"

    question_details.append({
        "question": "Was the drug detected in blood in toxic concentrations?",
        "answer": answers[7],
        "reasoning": q7_reason,
    })

    # --- Q8: Dose-response relationship ---
    dose_info = report_data.get("dose") or report_data.get("dosage")
    dose_changed = report_data.get("dose_changed")
    if dose_changed or (dose_info and any(w in reaction_desc for w in ["increased dose", "higher dose", "overdose"])):
        answers[8] = "yes"
        score += QUESTION_WEIGHTS[8][0]
        q8_reason = "Dose-response relationship indicated"
    else:
        answers[8] = "don't know"
        score += QUESTION_WEIGHTS[8][2]
        q8_reason = "No dose-response information available"

    question_details.append({
        "question": "Was the reaction more severe when dose increased or less severe when decreased?",
        "answer": answers[8],
        "reasoning": q8_reason,
    })

    # --- Q9: Previous similar reaction ---
    prev_reaction = report_data.get("previous_reaction") or report_data.get("drug_allergy")
    if prev_reaction:
        answers[9] = "yes"
        score += QUESTION_WEIGHTS[9][0]
        q9_reason = f"Previous reaction reported: {prev_reaction}"
    else:
        answers[9] = "don't know"
        score += QUESTION_WEIGHTS[9][2]
        q9_reason = "No information on previous similar reactions"

    question_details.append({
        "question": "Did the patient have a similar reaction to the same or similar drugs before?",
        "answer": answers[9],
        "reasoning": q9_reason,
    })

    # --- Q10: Objective evidence ---
    has_objective = False
    objective_details = []
    if report_data.get("lab_results"):
        has_objective = True
        objective_details.append("lab results")
    if report_data.get("images") or report_data.get("photo"):
        has_objective = True
        objective_details.append("photos/images")
    if report_data.get("medical_records"):
        has_objective = True
        objective_details.append("medical records")
    reporter_type = (report_data.get("reporter_type") or "consumer").lower()
    if reporter_type in ("physician", "pharmacist", "healthcare_professional", "doctor"):
        has_objective = True
        objective_details.append("healthcare professional report")

    if has_objective:
        answers[10] = "yes"
        score += QUESTION_WEIGHTS[10][0]
        q10_reason = f"Objective evidence: {', '.join(objective_details)}"
    else:
        answers[10] = "don't know"
        score += QUESTION_WEIGHTS[10][2]
        q10_reason = "No objective evidence provided"

    question_details.append({
        "question": "Was the adverse event confirmed by any objective evidence?",
        "answer": answers[10],
        "reasoning": q10_reason,
    })

    # --- Interpret score ---
    if score >= 9:
        category = "Definite"
    elif score >= 5:
        category = "Probable"
    elif score >= 1:
        category = "Possible"
    else:
        category = "Doubtful"

    return {
        "naranjo_score": score,
        "naranjo_category": category,
        "naranjo_scale_range": "-4 to +13",
        "interpretation": {
            "Definite": ">= 9",
            "Probable": "5 - 8",
            "Possible": "1 - 4",
            "Doubtful": "<= 0",
        },
        "answers": answers,
        "question_details": question_details,
    }


# ---------------------------------------------------------------------------
# Seriousness assessment
# ---------------------------------------------------------------------------

def _assess_seriousness(report_data: dict) -> dict:
    """Assess the seriousness of the ADR based on ICH E2B criteria."""
    is_serious = False
    criteria_met: list[str] = []

    seriousness_data = report_data.get("seriousness", {})
    if isinstance(seriousness_data, dict):
        for criterion in SERIOUSNESS_CRITERIA:
            if seriousness_data.get(criterion, False):
                is_serious = True
                criteria_met.append(criterion)

    # Check free-text for serious keywords
    reaction_text = report_data.get("reaction_description", "").lower()

    for kw in SEVERITY_CRITICAL:
        if kw in reaction_text:
            is_serious = True
            is_death_related = (
                "died" in reaction_text
                or "death" in reaction_text
                or "fatal" in reaction_text
            )
            if is_death_related and "death" not in criteria_met:
                criteria_met.append("death")
            elif not is_death_related and "life_threatening" not in criteria_met:
                criteria_met.append("life_threatening")

    for kw in SEVERITY_SEVERE:
        if kw in reaction_text:
            is_serious = True
            if "hospitalized" in reaction_text or "hospitalised" in reaction_text or "icu" in reaction_text:
                if "hospitalization" not in criteria_met:
                    criteria_met.append("hospitalization")
            elif "medically_important" not in criteria_met:
                criteria_met.append("medically_important")

    # Deduplicate
    criteria_met = list(dict.fromkeys(criteria_met))

    return {
        "is_serious": is_serious,
        "criteria_met": criteria_met,
    }


# ---------------------------------------------------------------------------
# Expected vs. unexpected reaction check (Supabase-backed)
# ---------------------------------------------------------------------------

def _check_expected_reaction(
    reaction_description: str,
    side_effects_record: Optional[dict],
) -> dict:
    """
    Determine if the reported reaction is a known/expected side effect
    or a potential new signal (unexpected).
    """
    reaction_lower = reaction_description.lower()
    reaction_words = [w for w in reaction_lower.split() if len(w) > 3]

    is_expected = False
    is_black_box = False
    matched_known: list[str] = []
    expectedness = "unknown"

    if not side_effects_record:
        return {
            "is_expected": False,
            "is_black_box": False,
            "expectedness": "unknown",
            "matched_known_effects": [],
            "detail": "No side effect data available for this drug in the database.",
        }

    # Check common side effects
    common = (side_effects_record.get("common_side_effects") or "").lower()
    if common:
        for word in reaction_words:
            if word in common:
                is_expected = True
                matched_known.append(f"common: {word}")

    # Check serious side effects
    serious = (side_effects_record.get("serious_side_effects") or "").lower()
    if serious:
        for word in reaction_words:
            if word in serious:
                is_expected = True
                matched_known.append(f"serious: {word}")

    # Check black box warnings
    black_box = (side_effects_record.get("black_box_warnings") or "").lower()
    if black_box:
        for word in reaction_words:
            if word in black_box:
                is_expected = True
                is_black_box = True
                matched_known.append(f"BLACK BOX: {word}")

    if is_black_box:
        expectedness = "expected_black_box_warning"
    elif is_expected:
        expectedness = "expected_known_effect"
    else:
        expectedness = "unexpected_potential_signal"

    detail = ""
    if is_black_box:
        detail = (
            "CRITICAL: This reaction matches a BLACK BOX WARNING for this drug. "
            "This is a known serious risk that requires immediate medical attention."
        )
    elif is_expected:
        detail = "This reaction is a known side effect of this drug."
    else:
        detail = (
            "This reaction is NOT listed among the known side effects of this drug. "
            "This may represent a NEW SAFETY SIGNAL requiring further investigation."
        )

    return {
        "is_expected": is_expected,
        "is_black_box": is_black_box,
        "expectedness": expectedness,
        "matched_known_effects": matched_known,
        "detail": detail,
    }


# ---------------------------------------------------------------------------
# Enhanced signal detection
# ---------------------------------------------------------------------------

def _enhanced_signal_detection(
    report_data: dict,
    seriousness: dict,
    expected_reaction: dict,
    openfda_counts: dict,
    supabase_ae: list[dict],
) -> dict:
    """
    Enhanced safety signal detection combining multiple data sources.
    """
    signal_triggered = False
    signal_reasons: list[str] = []
    signal_level = "none"  # none, low, medium, high, critical

    # 1. Serious reactions automatically trigger a signal
    if seriousness["is_serious"]:
        signal_triggered = True
        signal_reasons.append(
            f"Serious ADR reported: {', '.join(seriousness['criteria_met'])}"
        )
        signal_level = "high"

    # 2. Black box warning match -> critical
    if expected_reaction.get("is_black_box"):
        signal_triggered = True
        signal_reasons.append(
            "Reaction matches a BLACK BOX WARNING for this drug"
        )
        signal_level = "critical"

    # 3. Unexpected reaction -> potential new signal
    if expected_reaction.get("expectedness") == "unexpected_potential_signal":
        signal_triggered = True
        signal_reasons.append(
            "UNEXPECTED reaction: not listed in known side effects -- potential new safety signal"
        )
        if signal_level in ("none", "low"):
            signal_level = "medium"

    # 4. Compare reaction frequency against background rate from OpenFDA
    reaction_desc = report_data.get("reaction_description", "").lower()
    if openfda_counts:
        total_reports = sum(openfda_counts.values())
        for term, count in openfda_counts.items():
            if any(w in term.lower() for w in reaction_desc.split() if len(w) > 3):
                proportion = count / total_reports if total_reports > 0 else 0
                if proportion > 0.1:  # More than 10% of all reactions
                    signal_reasons.append(
                        f"High-frequency reaction: '{term}' accounts for "
                        f"{proportion:.1%} of all reported reactions ({count}/{total_reports})"
                    )
                elif count >= 50:
                    signal_reasons.append(
                        f"Notable signal: '{term}' reported {count} times internationally"
                    )

    # 5. Supabase AE profile data
    if supabase_ae:
        for ae_record in supabase_ae:
            serious_count = ae_record.get("serious_count") or ae_record.get("serious_outcomes", 0)
            if isinstance(serious_count, int) and serious_count > 10:
                signal_triggered = True
                signal_reasons.append(
                    f"Database shows {serious_count} serious outcome reports for this drug"
                )
                if signal_level in ("none", "low"):
                    signal_level = "medium"

    return {
        "signal_triggered": signal_triggered,
        "signal_reasons": signal_reasons,
        "signal_level": signal_level,
    }


# ---------------------------------------------------------------------------
# International signal detection (OpenFDA live API)
# ---------------------------------------------------------------------------

def _check_international_signals(medicine_name: str, reaction_description: str) -> dict:
    """
    Check OpenFDA adverse event database for international signal detection.
    Returns existing reports and reaction counts.
    """
    international_data: dict = {
        "checked": False,
        "existing_reports": [],
        "reaction_counts": {},
        "total_report_count": 0,
        "signal_detected": False,
        "signal_details": "",
    }

    if not medicine_name:
        return international_data

    try:
        # Get existing adverse events for this drug
        events = _run_async_safely(openfda_client.get_adverse_events(medicine_name, limit=10))
        if events:
            international_data["checked"] = True
            international_data["existing_reports"] = events
            international_data["total_report_count"] = len(events)

        # Get reaction counts for signal detection
        counts = _run_async_safely(openfda_client.get_adverse_event_counts(medicine_name))
        if counts:
            international_data["reaction_counts"] = counts
            international_data["checked"] = True

            # Check if the reported reaction is among the top reported reactions
            reaction_lower = reaction_description.lower()
            for term, count in counts.items():
                if any(word in term.lower() for word in reaction_lower.split() if len(word) > 3):
                    if count >= 10:
                        international_data["signal_detected"] = True
                        international_data["signal_details"] = (
                            f"Similar reaction '{term}' has been reported {count} times "
                            f"internationally for this drug in the FDA FAERS database."
                        )
                        break

    except Exception as exc:
        logger.warning("International signal detection failed: %s", exc)

    return international_data


# ---------------------------------------------------------------------------
# Report quality scoring
# ---------------------------------------------------------------------------

def _calculate_report_quality(report_data: dict) -> dict:
    """
    Rate report completeness on a 0-100% scale.

    Scoring breakdown:
      Required (40 pts):
        - drug/medicine name:      20 pts
        - reaction description:    20 pts
      Important (40 pts):
        - onset time/date:         10 pts
        - dose/dosage:             10 pts
        - patient age:              8 pts
        - patient weight:           4 pts
        - patient sex/gender:       4 pts
        - reporter type:            4 pts
      Helpful (20 pts):
        - concomitant medications:  5 pts
        - medical history:          5 pts
        - outcome:                  4 pts
        - batch number:             3 pts
        - dechallenge info:         3 pts
    """
    score = 0
    max_score = 100
    filled_fields: list[str] = []
    missing_fields: list[str] = []

    # Required fields (40 pts)
    if report_data.get("medicine_name", "").strip():
        score += 20
        filled_fields.append("medicine_name")
    else:
        missing_fields.append("medicine_name (required)")

    if report_data.get("reaction_description", "").strip():
        score += 20
        filled_fields.append("reaction_description")
    else:
        missing_fields.append("reaction_description (required)")

    # Important fields (40 pts)
    if report_data.get("onset_date") or report_data.get("onset_time"):
        score += 10
        filled_fields.append("onset_time")
    else:
        missing_fields.append("onset_time (important)")

    if report_data.get("dose") or report_data.get("dosage"):
        score += 10
        filled_fields.append("dose")
    else:
        missing_fields.append("dose (important)")

    if report_data.get("patient_age"):
        score += 8
        filled_fields.append("patient_age")
    else:
        missing_fields.append("patient_age (important)")

    if report_data.get("patient_weight"):
        score += 4
        filled_fields.append("patient_weight")
    else:
        missing_fields.append("patient_weight (important)")

    if report_data.get("patient_sex") or report_data.get("patient_gender"):
        score += 4
        filled_fields.append("patient_sex")
    else:
        missing_fields.append("patient_sex (important)")

    if report_data.get("reporter_type"):
        score += 4
        filled_fields.append("reporter_type")
    else:
        missing_fields.append("reporter_type (important)")

    # Helpful fields (20 pts)
    if report_data.get("concomitant_medications"):
        score += 5
        filled_fields.append("concomitant_medications")
    else:
        missing_fields.append("concomitant_medications (helpful)")

    if report_data.get("medical_history"):
        score += 5
        filled_fields.append("medical_history")
    else:
        missing_fields.append("medical_history (helpful)")

    if report_data.get("outcome"):
        score += 4
        filled_fields.append("outcome")
    else:
        missing_fields.append("outcome (helpful)")

    if report_data.get("batch_number"):
        score += 3
        filled_fields.append("batch_number")
    else:
        missing_fields.append("batch_number (helpful)")

    if report_data.get("dechallenge") or report_data.get("drug_stopped"):
        score += 3
        filled_fields.append("dechallenge_info")
    else:
        missing_fields.append("dechallenge_info (helpful)")

    # Quality grade
    if score >= 80:
        grade = "Excellent"
    elif score >= 60:
        grade = "Good"
    elif score >= 40:
        grade = "Adequate"
    elif score >= 20:
        grade = "Minimal"
    else:
        grade = "Insufficient"

    return {
        "report_quality_score": score,
        "max_score": max_score,
        "quality_percentage": f"{score}%",
        "quality_grade": grade,
        "filled_fields": filled_fields,
        "missing_fields": missing_fields,
        "improvement_tips": _get_quality_tips(missing_fields),
    }


def _get_quality_tips(missing_fields: list[str]) -> list[str]:
    """Generate tips to improve report quality based on missing fields."""
    tips: list[str] = []
    missing_names = [f.split(" (")[0] for f in missing_fields]

    if "onset_time" in missing_names:
        tips.append("Add when the reaction started (e.g., '2 hours after taking the medicine').")
    if "dose" in missing_names:
        tips.append("Include the dose/strength taken (e.g., '500mg tablet').")
    if "patient_age" in missing_names:
        tips.append("Provide the patient's age for better safety analysis.")
    if "concomitant_medications" in missing_names:
        tips.append("List other medicines being taken -- this helps rule out drug interactions.")
    if "medical_history" in missing_names:
        tips.append("Share relevant medical history to help assess alternative causes.")
    if "outcome" in missing_names:
        tips.append("Report the outcome (recovered, recovering, not recovered, fatal).")
    if "batch_number" in missing_names:
        tips.append("Include the batch/lot number from the medicine packaging for traceability.")

    return tips


# ---------------------------------------------------------------------------
# Report formatting
# ---------------------------------------------------------------------------

def _format_report(
    report_data: dict,
    report_id: str,
    meddra_categorization: dict,
    seriousness: dict,
    signal: dict,
    naranjo: dict,
    expected_reaction: dict,
    quality: dict,
) -> dict:
    """Format the ADR report for submission/storage."""
    return {
        "report_id": report_id,
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "medicine_name": report_data.get("medicine_name", "Unknown"),
        "active_ingredient": report_data.get("active_ingredient", "Unknown"),
        "batch_number": report_data.get("batch_number"),
        "patient_type": report_data.get("patient_type", "adult"),
        "patient_age": report_data.get("patient_age"),
        "patient_weight": report_data.get("patient_weight"),
        "patient_sex": report_data.get("patient_sex") or report_data.get("patient_gender"),
        "reaction_description": report_data.get("reaction_description", ""),
        "meddra_classification": meddra_categorization,
        "onset_date": report_data.get("onset_date") or report_data.get("onset_time"),
        "dose": report_data.get("dose") or report_data.get("dosage"),
        "concomitant_medications": report_data.get("concomitant_medications", []),
        "medical_history": report_data.get("medical_history"),
        "outcome": report_data.get("outcome", "unknown"),
        "seriousness": seriousness,
        "signal": signal,
        "naranjo_assessment": {
            "score": naranjo["naranjo_score"],
            "category": naranjo["naranjo_category"],
        },
        "expected_reaction": expected_reaction,
        "report_quality": {
            "score": quality["report_quality_score"],
            "grade": quality["quality_grade"],
        },
        "reporter_type": report_data.get("reporter_type", "consumer"),
        "country": "Pakistan",
        "regulatory_authority": "DRAP",
        "status": "submitted",
    }


# ---------------------------------------------------------------------------
# Main entry point
# ---------------------------------------------------------------------------

def process_adr_report(report_data: dict) -> dict:
    """
    Main entry point for Agent 9 -- ADR Reporter.

    Performs:
      1. MedDRA SOC reaction categorization with symptom mapping
      2. Seriousness assessment (ICH E2B)
      3. Supabase lookup for known side effects and adverse event profiles
      4. OpenFDA live signal detection
      5. Naranjo causality assessment (10-question algorithm)
      6. Expected vs. unexpected reaction classification
      7. Enhanced signal detection with multiple data sources
      8. Report quality scoring (0-100%)
      9. Pakistan pharmacovigilance context (DRAP)

    Args:
        report_data: Dict containing ADR report information:
            - medicine_name: str
            - active_ingredient: str
            - batch_number: str (optional)
            - reaction_description: str
            - seriousness: dict of criteria (optional)
            - patient_type: str (adult/child)
            - patient_age: int (optional)
            - patient_weight: float (optional)
            - patient_sex: str (optional)
            - onset_date / onset_time: str (optional)
            - dose / dosage: str (optional)
            - outcome: str (optional)
            - dechallenge / drug_stopped: bool (optional)
            - rechallenge: str/bool (optional)
            - concomitant_medications: list[str] (optional)
            - medical_history: str (optional)
            - previous_reaction / drug_allergy: str (optional)
            - lab_results / blood_levels: str (optional)
            - reporter_type: str (optional)

    Returns:
        Standardized agent result dict with Naranjo assessment and quality scoring.
    """
    result: dict = {
        "agent_number": AGENT_NUMBER,
        "agent_name": AGENT_NAME,
        "status": "PASS",
        "confidence_score": 0.0,
        "processed": False,
        "report_id": None,
        "signal_triggered": False,
        "signal_details": None,
        "signal_level": "none",
        "international_signals": None,
        "naranjo_score": None,
        "naranjo_category": None,
        "report_quality_score": None,
        "is_expected_reaction": None,
        "meddra_classification": None,
        "formatted_report": None,
        "pakistan_pharmacovigilance": PAKISTAN_PV_INFO,
        "display_message": "",
        "fail_reason": None,
    }

    try:
        if not report_data:
            result["status"] = "PASS"
            result["confidence_score"] = 1.0
            result["display_message"] = (
                "No ADR report data provided. ADR assessment skipped."
            )
            return result

        # Validate minimum required data
        reaction = report_data.get("reaction_description", "").strip()
        medicine = report_data.get("medicine_name", "").strip()

        if not reaction:
            result["status"] = "FAIL"
            result["confidence_score"] = 0.0
            result["fail_reason"] = "Missing reaction description"
            result["display_message"] = "ADR report requires a reaction description."
            return result

        if not medicine:
            result["status"] = "FAIL"
            result["confidence_score"] = 0.0
            result["fail_reason"] = "Missing medicine name"
            result["display_message"] = "ADR report requires the medicine name."
            return result

        # Generate report ID
        report_id = f"ADR-PK-{uuid.uuid4().hex[:8].upper()}"
        result["report_id"] = report_id

        # --- Step 1: MedDRA SOC categorization ---
        meddra = _categorize_reaction_meddra(reaction)
        result["meddra_classification"] = meddra

        # --- Step 2: Seriousness assessment ---
        seriousness = _assess_seriousness(report_data)

        # --- Step 3: Report quality scoring ---
        quality = _calculate_report_quality(report_data)
        result["report_quality_score"] = quality["report_quality_score"]

        # --- Step 4: Supabase queries ---
        supabase_ae = _query_supabase_adverse_events(medicine)
        side_effects_record = _query_supabase_side_effects(medicine)

        # Also try active ingredient if brand name yields nothing
        active_ingredient = report_data.get("active_ingredient", "").strip()
        if not side_effects_record and active_ingredient:
            side_effects_record = _query_supabase_side_effects(active_ingredient)
        if not supabase_ae and active_ingredient:
            supabase_ae = _query_supabase_adverse_events(active_ingredient)

        # --- Step 5: OpenFDA international signals ---
        international = _check_international_signals(medicine, reaction)
        result["international_signals"] = international
        openfda_counts = international.get("reaction_counts", {})

        # --- Step 6: Naranjo causality assessment ---
        naranjo = _naranjo_assessment(
            report_data,
            international.get("existing_reports", []),
            openfda_counts,
            supabase_ae,
            side_effects_record,
        )
        result["naranjo_score"] = naranjo["naranjo_score"]
        result["naranjo_category"] = naranjo["naranjo_category"]

        # --- Step 7: Expected vs. unexpected reaction ---
        expected_reaction = _check_expected_reaction(reaction, side_effects_record)
        result["is_expected_reaction"] = expected_reaction["is_expected"]

        # --- Step 8: Enhanced signal detection ---
        signal = _enhanced_signal_detection(
            report_data, seriousness, expected_reaction, openfda_counts, supabase_ae,
        )
        result["signal_triggered"] = signal["signal_triggered"]
        result["signal_details"] = signal
        result["signal_level"] = signal["signal_level"]

        # Incorporate international signal
        if international.get("signal_detected"):
            signal["signal_triggered"] = True
            signal["signal_reasons"].append(
                f"International signal: {international.get('signal_details', '')}"
            )
            result["signal_triggered"] = True
            if signal["signal_level"] in ("none", "low"):
                signal["signal_level"] = "medium"
                result["signal_level"] = "medium"

        # --- Step 9: Format complete report ---
        formatted = _format_report(
            report_data, report_id, meddra, seriousness, signal,
            naranjo, expected_reaction, quality,
        )
        result["formatted_report"] = formatted
        result["processed"] = True

        # --- Build display message ---
        result["status"] = "PASS"
        result["confidence_score"] = 0.90

        msg_parts: list[str] = []

        msg_parts.append(
            f"ADR Report {report_id} processed successfully for '{medicine}'."
        )

        # Seriousness
        if seriousness["is_serious"]:
            msg_parts.append(
                f"SERIOUS adverse reaction: {', '.join(seriousness['criteria_met'])}."
            )

        # MedDRA classification
        msg_parts.append(
            f"Classification: {meddra['primary_soc']} (Severity: {meddra['detected_severity']})."
        )

        # Naranjo
        msg_parts.append(
            f"Naranjo Causality Score: {naranjo['naranjo_score']}/13 "
            f"({naranjo['naranjo_category']} causal relationship)."
        )

        # Expected vs unexpected
        if expected_reaction["is_black_box"]:
            msg_parts.append(
                "CRITICAL: This reaction matches a BLACK BOX WARNING for this drug."
            )
        elif expected_reaction["is_expected"]:
            msg_parts.append("This is a KNOWN side effect of this drug.")
        elif expected_reaction["expectedness"] == "unexpected_potential_signal":
            msg_parts.append(
                "ATTENTION: This is an UNEXPECTED reaction -- not listed in known side effects. "
                "This may be a NEW SAFETY SIGNAL."
            )

        # Signal
        if signal["signal_triggered"]:
            msg_parts.append(
                f"SAFETY SIGNAL triggered (level: {signal['signal_level'].upper()}). "
                f"Reasons: {'; '.join(signal['signal_reasons'])}."
            )
        else:
            msg_parts.append("No immediate safety signal detected.")

        # International data
        if international.get("checked"):
            report_count = len(international.get("existing_reports", []))
            if report_count > 0:
                msg_parts.append(
                    f"OpenFDA FAERS database shows {report_count} existing adverse event "
                    f"report(s) for this drug."
                )

        # Report quality
        msg_parts.append(
            f"Report Quality: {quality['quality_percentage']} ({quality['quality_grade']})."
        )
        if quality["improvement_tips"]:
            msg_parts.append(
                f"To improve this report: {quality['improvement_tips'][0]}"
            )

        # Pakistan pharmacovigilance
        msg_parts.append(
            "This report can also be submitted to DRAP (Drug Regulatory Authority of Pakistan) "
            f"via {PAKISTAN_PV_INFO['reporting_url']} or by calling {PAKISTAN_PV_INFO['hotline']}. "
            "Pakistan has low ADR reporting rates -- every report matters and helps protect patients."
        )

        result["display_message"] = " ".join(msg_parts)

    except Exception as exc:  # noqa: BLE001
        logger.exception("Error processing ADR report: %s", exc)
        result["status"] = "UNCERTAIN"
        result["confidence_score"] = 0.0
        result["fail_reason"] = f"Error processing ADR report: {exc}"
        result["display_message"] = (
            "Could not process ADR report. Please try again or contact DRAP directly "
            f"at {PAKISTAN_PV_INFO['hotline']} or {PAKISTAN_PV_INFO['reporting_url']}."
        )

    return result
