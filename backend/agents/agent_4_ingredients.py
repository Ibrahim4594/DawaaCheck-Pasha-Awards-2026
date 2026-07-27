"""
Agent 4 — BASIR (The All-Seeing)

Uses Claude Vision with a detailed pharmaceutical prompt to extract and analyze
every ingredient (active, inactive, excipients) from medicine packaging images.
Cross-references against Supabase production database (drap_medicines, generic_drugs,
drug_side_effects), OpenFDA drug labels, and PubChem for compound verification.

Includes:
- Comprehensive ingredient extraction with role classification
- Banned substance detection (phenylpropanolamine, nimesulide pediatric, etc.)
- Dangerous excipient screening (diethylene glycol, methanol, etc.)
- Allergen warnings (gluten, lactose, tartrazine, sulfites)
- Preservative assessment (parabens, benzalkonium chloride)
- Fuzzy synonym matching (paracetamol = acetaminophen, etc.)
- Strength verification with 5% tolerance
- Dosage form identification
- Label quality assessment
"""

import asyncio
import os
import json
import re
import logging
from typing import Optional

import anthropic

from utils.supabase_client import get_supabase, sanitize_like
from utils.api_retry import retry_api_call
from utils.model_config import VISION_MODEL, MAX_TOKENS_INGREDIENTS
from data.api_clients import openfda_client, pubchem_client


logger = logging.getLogger(__name__)

ANTHROPIC_API_KEY = os.getenv("ANTHROPIC_API_KEY", "")

AGENT_NUMBER = 4
AGENT_NAME = "BASIR — The All-Seeing"

# Tolerance for quantity matching (5%)
QUANTITY_TOLERANCE = 0.05

# ---------------------------------------------------------------------------
# Comprehensive ingredient synonym map for fuzzy matching
# ---------------------------------------------------------------------------
INGREDIENT_SYNONYMS: dict[str, str] = {
    # Analgesics / Antipyretics
    "acetaminophen": "paracetamol",
    "apap": "paracetamol",
    "n-acetyl-p-aminophenol": "paracetamol",
    "tylenol": "paracetamol",
    # NSAIDs
    "ibuprofen lysine": "ibuprofen",
    "aspirin": "acetylsalicylic acid",
    "asa": "acetylsalicylic acid",
    "naproxen sodium": "naproxen",
    "diclofenac sodium": "diclofenac",
    "diclofenac potassium": "diclofenac",
    # Vitamins
    "vitamin c": "ascorbic acid",
    "vitamin b1": "thiamine",
    "vitamin b2": "riboflavin",
    "vitamin b3": "niacin",
    "nicotinic acid": "niacin",
    "nicotinamide": "niacinamide",
    "vitamin b5": "pantothenic acid",
    "vitamin b6": "pyridoxine",
    "pyridoxine hydrochloride": "pyridoxine",
    "pyridoxine hcl": "pyridoxine",
    "vitamin b7": "biotin",
    "vitamin b9": "folic acid",
    "folate": "folic acid",
    "vitamin b12": "cyanocobalamin",
    "methylcobalamin": "cyanocobalamin",
    "vitamin d": "cholecalciferol",
    "vitamin d3": "cholecalciferol",
    "vitamin d2": "ergocalciferol",
    "vitamin e": "tocopherol",
    "alpha-tocopherol": "tocopherol",
    "vitamin a": "retinol",
    "vitamin k": "phytonadione",
    "vitamin k1": "phytonadione",
    # Antibiotics
    "amoxycillin": "amoxicillin",
    "co-amoxiclav": "amoxicillin/clavulanate",
    "augmentin": "amoxicillin/clavulanate",
    # Antihypertensives
    "amlodipine besylate": "amlodipine",
    "losartan potassium": "losartan",
    "atenolol": "atenolol",
    # Antidiabetics
    "metformin hydrochloride": "metformin",
    "metformin hcl": "metformin",
    # Gastrointestinal
    "omeprazole magnesium": "omeprazole",
    "esomeprazole magnesium": "esomeprazole",
    "ranitidine hydrochloride": "ranitidine",
    # Antihistamines
    "cetirizine hydrochloride": "cetirizine",
    "cetirizine hcl": "cetirizine",
    "loratadine": "loratadine",
    "chlorpheniramine maleate": "chlorpheniramine",
    "cpm": "chlorpheniramine",
    # Antacids / Supplements
    "calcium carbonate": "calcium carbonate",
    "ferrous sulfate": "ferrous sulphate",
    "ferrous fumarate": "iron",
    "ferrous sulphate": "iron",
    # Note: generic salt form names are handled by _normalize_name's suffix stripping.
    # Do not map short strings to empty — that causes matching failures.
}

# ---------------------------------------------------------------------------
# Banned / restricted substances
# ---------------------------------------------------------------------------
BANNED_SUBSTANCES: dict[str, str] = {
    "phenylpropanolamine": "Banned globally - cardiovascular risk (hemorrhagic stroke). Removed from market in most countries.",
    "nimesulide": "Banned for pediatric use in many countries - hepatotoxicity risk. Restricted in Pakistan for children under 12.",
    "rofecoxib": "Withdrawn globally (Vioxx) - increased cardiovascular events.",
    "valdecoxib": "Withdrawn globally (Bextra) - serious skin reactions and cardiovascular risk.",
    "cisapride": "Withdrawn - fatal cardiac arrhythmias (QT prolongation).",
    "terfenadine": "Withdrawn - fatal cardiac arrhythmias. Replaced by fexofenadine.",
    "astemizole": "Withdrawn - cardiac arrhythmias risk.",
    "sibutramine": "Withdrawn - cardiovascular events (heart attacks, strokes).",
    "rosiglitazone": "Severely restricted - increased heart failure risk.",
    "gatifloxacin": "Withdrawn from systemic use - severe dysglycemia.",
    "tegaserod": "Withdrawn - cardiovascular ischemic events.",
    "dextropropoxyphene": "Withdrawn - fatal overdose risk, cardiac toxicity.",
    "propoxyphene": "Withdrawn - cardiac toxicity at therapeutic doses.",
    "phenformin": "Withdrawn - lactic acidosis risk (predecessor of metformin).",
    "oxyphenbutazone": "Withdrawn - severe blood dyscrasias.",
    "analgin": "Banned in many countries (metamizole) - agranulocytosis risk.",
    "metamizole": "Banned in many countries - agranulocytosis risk.",
    "dipyrone": "Banned in many countries - agranulocytosis risk (same as metamizole).",
    "nifedipine sublingual": "Banned route - dangerous hypotension. Only sustained-release oral forms allowed.",
    "loperamide high dose": "Abuse potential at high doses - cardiac arrhythmias.",
}

# ---------------------------------------------------------------------------
# Dangerous excipients
# ---------------------------------------------------------------------------
DANGEROUS_EXCIPIENTS: dict[str, str] = {
    "diethylene glycol": "LETHAL contaminant - has caused mass poisoning events worldwide. Must NEVER be present in medicines. Substitute for propylene glycol in counterfeit/contaminated products.",
    "ethylene glycol": "Toxic - causes renal failure and death. Industrial antifreeze, never for pharmaceutical use.",
    "methanol": "Toxic alcohol - causes blindness and death. Should never appear in oral medicines.",
    "benzene": "Carcinogen - should never be present in pharmaceuticals.",
    "carbon tetrachloride": "Hepatotoxin - banned from pharmaceutical use.",
    "chloroform": "Hepatotoxin and carcinogen - removed from pharmaceutical preparations.",
    "nitrosamine": "Carcinogenic impurity - multiple drug recalls (ranitidine, metformin batches).",
    "ndma": "N-Nitrosodimethylamine - probable human carcinogen found as contaminant.",
    "ndea": "N-Nitrosodiethylamine - carcinogenic impurity.",
    "asbestos": "Carcinogen - potential talc contaminant.",
    "mercury": "Neurotoxin - banned from most pharmaceutical products.",
    "lead": "Neurotoxin - should never be present in medicines.",
    "melamine": "Toxic adulterant - causes renal failure. Found in counterfeit products.",
}

# ---------------------------------------------------------------------------
# Allergen ingredients
# ---------------------------------------------------------------------------
ALLERGEN_INGREDIENTS: dict[str, str] = {
    "lactose": "Dairy allergen / intolerance - affects ~65% of global population. Unsuitable for lactose-intolerant patients.",
    "lactose monohydrate": "Dairy allergen / intolerance - affects ~65% of global population.",
    "gluten": "Celiac disease trigger - must be avoided by celiac patients and gluten-sensitive individuals.",
    "wheat starch": "May contain gluten - potential celiac disease trigger.",
    "tartrazine": "Synthetic dye (E102/FD&C Yellow #5) - can cause allergic reactions, especially in aspirin-sensitive patients. Linked to hyperactivity in children.",
    "sunset yellow": "Synthetic dye (E110/FD&C Yellow #6) - allergic reactions, hyperactivity concerns.",
    "fd&c yellow no. 5": "Tartrazine (E102) - allergic reactions, aspirin cross-sensitivity.",
    "fd&c yellow no. 6": "Sunset yellow (E110) - allergic reactions.",
    "fd&c red no. 40": "Allura red (E129) - hyperactivity concerns, allergic reactions.",
    "allura red": "Synthetic dye (E129) - hyperactivity concerns.",
    "brilliant blue": "Synthetic dye (E133) - allergic reactions in sensitive individuals.",
    "sulfites": "Allergic reactions, bronchospasm in asthmatics. Must be declared on label.",
    "sodium metabisulfite": "Sulfite - allergic reactions and bronchospasm in sensitive patients.",
    "sodium sulfite": "Sulfite allergen - dangerous for sulfite-sensitive asthmatics.",
    "potassium metabisulfite": "Sulfite allergen.",
    "soy lecithin": "Soy allergen - affects soy-allergic patients.",
    "soybean oil": "Soy allergen.",
    "gelatin": "Animal-derived - unsuitable for vegetarians/vegans. Pork gelatin unsuitable for halal/kosher diets.",
    "peanut oil": "Peanut allergen - potentially fatal in peanut-allergic patients.",
    "arachis oil": "Peanut oil - severe allergen.",
    "casein": "Milk protein allergen.",
    "shellac": "Insect-derived coating - may cause allergic reactions.",
    "carmine": "Insect-derived colorant (E120) - allergic reactions.",
    "cochineal": "Insect-derived colorant - same as carmine.",
    "aspartame": "Contains phenylalanine - dangerous for phenylketonuria (PKU) patients.",
    "phenylalanine": "Dangerous for PKU patients. Must be declared on label.",
    "benzyl alcohol": "Toxic in neonates - 'gasping syndrome'. Contraindicated in premature infants.",
    "propylene glycol": "May cause toxicity in neonates and renal impairment at high doses.",
    "polysorbate 80": "Hypersensitivity reactions reported, especially in IV formulations.",
    "egg protein": "Egg allergen - relevant for some vaccine formulations.",
}

# ---------------------------------------------------------------------------
# Preservative concerns
# ---------------------------------------------------------------------------
PRESERVATIVE_CONCERNS: dict[str, str] = {
    "methylparaben": "Paraben preservative - weak estrogenic activity. Generally considered safe at low concentrations but consumer concern exists.",
    "propylparaben": "Paraben preservative - higher estrogenic activity than methylparaben.",
    "butylparaben": "Paraben preservative - strongest estrogenic activity. Restricted in some cosmetic regulations.",
    "ethylparaben": "Paraben preservative - mild endocrine disruption concern.",
    "benzalkonium chloride": "Quaternary ammonium preservative - can cause bronchospasm in asthmatics when inhaled. Eye irritation in ophthalmic products. Toxic to contact lenses.",
    "thimerosal": "Mercury-containing preservative - removed from most vaccines. Neurotoxicity concerns.",
    "thiomersal": "Same as thimerosal - mercury-based preservative.",
    "formaldehyde": "Carcinogen and sensitizer - minimized in modern pharmaceuticals.",
    "phenol": "Preservative - tissue irritant at higher concentrations.",
    "chlorobutanol": "Preservative - CNS depressant properties, unstable at high temperatures.",
    "sodium benzoate": "When combined with ascorbic acid (vitamin C), can form benzene (carcinogen).",
    "potassium sorbate": "Generally safe preservative - rare allergic reactions.",
    "bht": "Butylated hydroxytoluene - antioxidant preservative. Possible endocrine disruption at high doses.",
    "bha": "Butylated hydroxyanisole - possible carcinogen at high doses (animal studies).",
}


# ---------------------------------------------------------------------------
# Claude Vision prompt
# ---------------------------------------------------------------------------
VISION_PROMPT = """You are a senior pharmaceutical analyst and regulatory inspector performing a detailed
ingredient panel analysis on a medicine package image. Analyze step by step with chain-of-thought reasoning.

STEP 1 - COMPLETE INGREDIENT EXTRACTION:
Carefully read EVERY ingredient visible on this medicine label/packaging. This includes:
- Active pharmaceutical ingredients (APIs) with exact strengths
- Inactive ingredients / excipients (fillers, binders, disintegrants)
- Preservatives (parabens, benzalkonium chloride, etc.)
- Colorants and dyes (tartrazine E102, sunset yellow E110, FD&C dyes, etc.)
- Coating agents (HPMC, shellac, Opadry, Eudragit, etc.)
- Flavoring agents
- Sweeteners (sucralose, aspartame, saccharin, etc.)
- Solvents and vehicles (propylene glycol, PEG, alcohol, etc.)
- Antioxidants (BHT, BHA, ascorbic acid as antioxidant, etc.)
- Any "contains" or "may contain" allergen declarations

STEP 2 - DOSAGE FORM IDENTIFICATION:
Based on the ingredients list and any visible text, determine the dosage form:
- Tablet (film-coated, enteric-coated, chewable, dispersible, sublingual, effervescent)
- Capsule (hard gelatin, soft gelatin, vegetarian/HPMC capsule)
- Syrup / Suspension / Solution / Elixir
- Injection / IV solution
- Cream / Ointment / Gel
- Drops (eye, ear, nasal)
- Inhaler / Nebulizer solution
- Suppository
- Patch (transdermal)
- Powder / Granules / Sachet

STEP 3 - SAFETY SCREENING:
Flag any of these if found:
- Banned substances: phenylpropanolamine, nimesulide (if pediatric), rofecoxib, sibutramine, cisapride,
  terfenadine, astemizole, dextropropoxyphene, phenformin
- Dangerous excipients: diethylene glycol, ethylene glycol, methanol, benzene
- Common allergens: gluten, lactose, tartrazine, sulfites, soy, peanut oil, gelatin, aspartame
- Preservative concerns: parabens, thimerosal, benzalkonium chloride, formaldehyde

STEP 4 - LABEL QUALITY ASSESSMENT:
Assess the print quality of the ingredient text:
- Is the text clearly printed and easily legible?
- Are there signs of degradation, smearing, or poor print quality?
- Does the font and printing style look consistent and professional?
- Any signs of label tampering, re-pasting, or overprinting?
- Is the text aligned properly or does it appear crooked/misaligned?

Return ONLY valid JSON in this exact format (no markdown, no explanation outside JSON):
{
  "ingredients": [
    {
      "name": "exact ingredient name as printed",
      "quantity": 500,
      "unit": "mg",
      "role": "active"
    },
    {
      "name": "microcrystalline cellulose",
      "quantity": null,
      "unit": null,
      "role": "inactive"
    }
  ],
  "dosage_form": "film-coated tablet",
  "dosage_form_confidence": "high",
  "label_composition_text": "exact text of the composition/ingredients section as printed on label",
  "banned_substances_found": [],
  "allergen_declarations": [],
  "label_quality": {
    "legibility": "clear",
    "print_consistency": "professional",
    "tampering_signs": "none",
    "overall_assessment": "good"
  },
  "drug_class_consistency": "The ingredients are consistent with an analgesic/antipyretic formulation",
  "unusual_ingredients": [],
  "reasoning": "Step-by-step reasoning of the analysis..."
}

ROLE VALUES: "active", "inactive", "preservative", "colorant", "coating", "flavoring", "sweetener", "antioxidant", "solvent", "unknown"

IMPORTANT RULES:
- Extract ALL ingredients, not just active ones
- For combination drugs, list EACH active ingredient as a separate entry
- quantity must be a number or null (not a string like "500mg")
- unit must be a string: "mg", "mcg", "ml", "g", "IU", "%", "mg/5ml", "mg/ml", etc.
- If a quantity/unit cannot be determined, use null
- For "Each 5ml contains..." formulations, note the per-volume basis in the unit
- Read carefully - do not guess or hallucinate ingredients that are not visible
- If text is partially obscured, note this in reasoning
"""


def _get_client() -> anthropic.Anthropic:
    if not ANTHROPIC_API_KEY:
        raise RuntimeError(
            "ANTHROPIC_API_KEY is not set. Cannot perform ingredient image analysis."
        )
    return anthropic.Anthropic(api_key=ANTHROPIC_API_KEY)


def _extract_ingredients_vision(client: anthropic.Anthropic, ingredients_image_b64: str) -> dict:
    """Use Claude Vision with pharmaceutical-grade prompt to analyze the ingredient panel."""

    if not ingredients_image_b64 or not ingredients_image_b64.strip():
        raise ValueError("No ingredient image provided for analysis")

    message = retry_api_call(lambda: client.messages.create(
        model=VISION_MODEL,
        max_tokens=MAX_TOKENS_INGREDIENTS,
        messages=[
            {
                "role": "user",
                "content": [
                    {
                        "type": "image",
                        "source": {
                            "type": "base64",
                            "media_type": "image/jpeg",
                            "data": ingredients_image_b64,
                        },
                    },
                    {"type": "text", "text": VISION_PROMPT},
                ],
            }
        ],
    ))

    if not message.content:
        raise ValueError("Claude Vision returned empty response for ingredient image")

    raw = message.content[0].text.strip()
    # Strip markdown code fences if present
    if raw.startswith("```"):
        raw = raw.split("\n", 1)[1]
        raw = raw.rsplit("```", 1)[0]
    # Handle case where JSON is wrapped in ```json ... ```
    raw = raw.strip()
    return json.loads(raw)


def _normalize_name(name: str) -> str:
    """
    Normalize ingredient name for comparison using the synonym map.
    Strips salt forms, whitespace, and maps known synonyms.
    """
    name = name.lower().strip()
    # Remove common salt suffixes for matching
    salt_suffixes = [
        " hydrochloride", " hcl", " sodium", " potassium", " calcium",
        " maleate", " besylate", " mesylate", " fumarate", " tartrate",
        " succinate", " phosphate", " sulfate", " sulphate", " acetate",
        " citrate", " bromide", " nitrate", " monohydrate", " dihydrate",
        " trihydrate",
    ]
    base_name = name
    for suffix in salt_suffixes:
        if base_name.endswith(suffix):
            base_name = base_name[: -len(suffix)].strip()
            break

    # Check synonym map for both full name and base name
    if name in INGREDIENT_SYNONYMS:
        mapped = INGREDIENT_SYNONYMS[name]
        if mapped:  # Guard against empty-string mappings
            return mapped
    if base_name in INGREDIENT_SYNONYMS:
        mapped = INGREDIENT_SYNONYMS[base_name]
        if mapped:
            return mapped
    # Return the base name (salt-stripped), falling back to original if empty
    return base_name if base_name else name


def _parse_quantity(qty_str) -> Optional[float]:
    """Parse a quantity string/number to a float."""
    if qty_str is None:
        return None
    try:
        if isinstance(qty_str, (int, float)):
            return float(qty_str)
        cleaned = re.sub(r"[^\d.]", "", str(qty_str))
        return float(cleaned) if cleaned else None
    except (ValueError, TypeError):
        return None


# ---------------------------------------------------------------------------
# Supabase data fetchers
# ---------------------------------------------------------------------------

def _get_expected_from_supabase(medicine_name: Optional[str]) -> tuple[list[dict], list[str]]:
    """
    Fetch expected ingredients from Supabase production database.
    Queries drap_medicines and generic_drugs tables.
    Returns (ingredients_list, data_sources).
    """
    if not medicine_name:
        return [], []

    ingredients: list[dict] = []
    sources: list[str] = []

    try:
        supabase = get_supabase()

        # --- Source 1: drap_medicines table (Pakistani branded medicines) ---
        # Try full-text search first
        try:
            drap_result = (
                supabase.table("drap_medicines")
                .select("brand_name, generic_name, active_ingredients, dosage_form, strength")
                .ilike("brand_name", f"%{sanitize_like(medicine_name)}%")
                .limit(3)
                .execute()
            )
            if not drap_result.data:
                # Fallback: search by generic name
                drap_result = (
                    supabase.table("drap_medicines")
                    .select("brand_name, generic_name, active_ingredients, dosage_form, strength")
                    .ilike("generic_name", f"%{sanitize_like(medicine_name)}%")
                    .limit(3)
                    .execute()
                )
        except Exception as e:
            logger.warning("DRAP medicines query failed: %s", e)
            drap_result = None

        if drap_result and drap_result.data:
            record = drap_result.data[0]
            active_ings = record.get("active_ingredients")

            if isinstance(active_ings, list):
                for ing in active_ings:
                    if isinstance(ing, dict):
                        ingredients.append({
                            "name": ing.get("name", ""),
                            "quantity": ing.get("quantity") or ing.get("strength"),
                            "unit": ing.get("unit", ""),
                            "source": "DRAP",
                        })
                    elif isinstance(ing, str):
                        ingredients.append({"name": ing, "quantity": None, "unit": None, "source": "DRAP"})
            elif isinstance(active_ings, dict):
                for name, details in active_ings.items():
                    ingredients.append({
                        "name": name,
                        "quantity": details.get("quantity") or details.get("strength") if isinstance(details, dict) else None,
                        "unit": details.get("unit") if isinstance(details, dict) else None,
                        "source": "DRAP",
                    })
            elif isinstance(active_ings, str):
                # Parse comma-separated string
                parts = [p.strip() for p in active_ings.split(",") if p.strip()]
                for p in parts:
                    ingredients.append({"name": p, "quantity": None, "unit": None, "source": "DRAP"})

            # Also try to parse strength field if ingredients are empty
            if not ingredients and record.get("strength"):
                strength_str = record["strength"]
                generic = record.get("generic_name", medicine_name)
                ingredients.append({
                    "name": generic,
                    "quantity": _parse_quantity(strength_str),
                    "unit": re.sub(r"[\d.]", "", str(strength_str)).strip() or "mg",
                    "source": "DRAP",
                })

            if ingredients:
                sources.append("DRAP")
                logger.info("Got %d expected ingredients from DRAP for '%s'", len(ingredients), medicine_name)

        # --- Source 2: generic_drugs table (comprehensive generic data) ---
        try:
            generic_result = (
                supabase.table("generic_drugs")
                .select("generic_name, drug_class, mechanism_of_action, clinical_data")
                .ilike("generic_name", f"%{sanitize_like(medicine_name)}%")
                .limit(3)
                .execute()
            )
        except Exception as e:
            logger.warning("Generic drugs query failed: %s", e)
            generic_result = None

        if generic_result and generic_result.data:
            for rec in generic_result.data:
                generic_name = rec.get("generic_name", "")
                # If we didn't get ingredients from DRAP, use generic as reference
                if not ingredients and generic_name:
                    ingredients.append({
                        "name": generic_name,
                        "quantity": None,
                        "unit": None,
                        "source": "GenericDB",
                    })
            if "GenericDB" not in sources:
                sources.append("GenericDB")

    except RuntimeError as e:
        logger.warning("Supabase not configured: %s", e)
    except Exception as e:
        logger.warning("Supabase ingredient lookup failed: %s", e)

    return ingredients, sources


def _get_side_effects_from_supabase(ingredient_names: list[str]) -> list[dict]:
    """
    Query drug_side_effects table for safety warnings on found ingredients.
    """
    side_effects: list[dict] = []
    try:
        supabase = get_supabase()
        for name in ingredient_names[:10]:  # Limit to avoid too many queries
            try:
                result = (
                    supabase.table("drug_side_effects")
                    .select("drug_name, common_side_effects, serious_side_effects, black_box_warnings")
                    .ilike("drug_name", f"%{sanitize_like(name)}%")
                    .limit(1)
                    .execute()
                )
                if result.data:
                    rec = result.data[0]
                    side_effects.append({
                        "drug_name": rec.get("drug_name", name),
                        "common": rec.get("common_side_effects", []),
                        "serious": rec.get("serious_side_effects", []),
                        "black_box": rec.get("black_box_warnings", []),
                    })
            except Exception as e:
                logger.debug("Side effect lookup failed for '%s': %s", name, e)
    except RuntimeError:
        logger.debug("Supabase not configured for side effects lookup")
    except Exception as e:
        logger.warning("Side effects lookup failed: %s", e)
    return side_effects


def _get_openfda_ingredients_from_supabase(medicine_name: str) -> list[dict]:
    """
    Query openfda_drugs table in Supabase for additional ingredient validation.
    """
    ingredients: list[dict] = []
    try:
        supabase = get_supabase()
        result = (
            supabase.table("openfda_drugs")
            .select("brand_name, generic_name, substance_name, active_ingredients, spl_id")
            .ilike("brand_name", f"%{sanitize_like(medicine_name)}%")
            .limit(3)
            .execute()
        )
        if not result.data:
            result = (
                supabase.table("openfda_drugs")
                .select("brand_name, generic_name, substance_name, active_ingredients, spl_id")
                .ilike("generic_name", f"%{sanitize_like(medicine_name)}%")
                .limit(3)
                .execute()
            )
        if result.data:
            rec = result.data[0]
            # substance_name may be a list or comma-separated string
            substances = rec.get("substance_name") or rec.get("active_ingredients")
            if isinstance(substances, list):
                for s in substances:
                    if isinstance(s, str):
                        ingredients.append({"name": s, "source": "OpenFDA_DB"})
                    elif isinstance(s, dict):
                        ingredients.append({"name": s.get("name", ""), "source": "OpenFDA_DB"})
            elif isinstance(substances, str):
                for s in substances.split(","):
                    s = s.strip()
                    if s:
                        ingredients.append({"name": s, "source": "OpenFDA_DB"})
    except Exception as e:
        logger.debug("OpenFDA Supabase lookup failed: %s", e)
    return ingredients


# ---------------------------------------------------------------------------
# OpenFDA API fallback
# ---------------------------------------------------------------------------

async def _get_expected_from_openfda_api(medicine_name: str) -> list[dict]:
    """Fetch expected ingredients from OpenFDA drug labels API (fallback)."""
    try:
        labels_response = await openfda_client.search_drug_labels(medicine_name)
        labels = labels_response.get("results", []) if isinstance(labels_response, dict) else []
        if labels:
            openfda_section = labels[0].get("openfda", {})
            substance_names = openfda_section.get("substance_name", [])
            return [{"name": ing, "source": "OpenFDA_API"} for ing in substance_names]
    except Exception as exc:
        logger.warning("OpenFDA API ingredient lookup failed: %s", exc)
    return []


# ---------------------------------------------------------------------------
# PubChem verification
# ---------------------------------------------------------------------------

async def _verify_compounds_pubchem(ingredient_names: list[str]) -> list[dict]:
    """Verify that ingredient names correspond to real compounds using PubChem."""
    try:
        return await pubchem_client.verify_compounds_batch(ingredient_names)
    except Exception as exc:
        logger.warning("PubChem verification failed: %s", exc)
        return []


# ---------------------------------------------------------------------------
# Safety analysis functions
# ---------------------------------------------------------------------------

def _check_banned_substances(extracted_ingredients: list[dict]) -> list[dict]:
    """Check extracted ingredients against banned substance list."""
    found: list[dict] = []
    for ing in extracted_ingredients:
        name_lower = ing.get("name", "").lower().strip()
        if not name_lower:
            continue
        for banned, reason in BANNED_SUBSTANCES.items():
            # Use word-boundary regex to avoid false positives from partial substrings
            if re.search(r'\b' + re.escape(banned) + r'\b', name_lower):
                found.append({
                    "ingredient": ing.get("name"),
                    "banned_substance": banned,
                    "reason": reason,
                    "severity": "CRITICAL",
                })
    return found


def _check_dangerous_excipients(extracted_ingredients: list[dict]) -> list[dict]:
    """Check for dangerous excipients that should never be in medicines."""
    found: list[dict] = []
    for ing in extracted_ingredients:
        name_lower = ing.get("name", "").lower().strip()
        if not name_lower:
            continue
        for excipient, reason in DANGEROUS_EXCIPIENTS.items():
            # Use word-boundary regex to avoid false positives
            if re.search(r'\b' + re.escape(excipient) + r'\b', name_lower):
                found.append({
                    "ingredient": ing.get("name"),
                    "dangerous_excipient": excipient,
                    "reason": reason,
                    "severity": "CRITICAL",
                })
    return found


def _check_allergens(extracted_ingredients: list[dict]) -> list[dict]:
    """Detect allergen-containing ingredients."""
    found: list[dict] = []
    for ing in extracted_ingredients:
        name_lower = ing.get("name", "").lower().strip()
        if not name_lower:
            continue
        for allergen, warning in ALLERGEN_INGREDIENTS.items():
            # Use word-boundary regex to reduce false positives
            if re.search(r'\b' + re.escape(allergen) + r'\b', name_lower):
                found.append({
                    "ingredient": ing.get("name"),
                    "allergen": allergen,
                    "warning": warning,
                    "severity": "WARNING",
                })
    return found


def _check_preservatives(extracted_ingredients: list[dict]) -> list[dict]:
    """Assess preservatives and flag concerns."""
    found: list[dict] = []
    for ing in extracted_ingredients:
        name_lower = ing.get("name", "").lower().strip()
        if not name_lower:
            continue
        for preservative, concern in PRESERVATIVE_CONCERNS.items():
            # Use word-boundary regex to reduce false positives
            if re.search(r'\b' + re.escape(preservative) + r'\b', name_lower):
                found.append({
                    "ingredient": ing.get("name"),
                    "preservative": preservative,
                    "concern": concern,
                    "severity": "INFO",
                })
    return found


# ---------------------------------------------------------------------------
# Ingredient comparison with fuzzy matching
# ---------------------------------------------------------------------------

def _compare_ingredients(
    extracted: list[dict],
    expected: list[dict],
) -> dict:
    """
    Compare extracted ingredients against expected list.
    Uses fuzzy synonym matching and 5% tolerance for quantity matching.
    """
    matched: list[dict] = []
    mismatched: list[dict] = []
    missing: list[dict] = []
    extra: list[dict] = []

    # Build normalized maps (keep first occurrence if duplicates normalize to same key)
    extracted_norm: dict[str, dict] = {}
    for ing in extracted:
        norm = _normalize_name(ing.get("name", ""))
        if norm and norm not in extracted_norm:
            extracted_norm[norm] = ing

    expected_norm: dict[str, dict] = {}
    for ing in expected:
        name = ing.get("name", "")
        if name:
            norm = _normalize_name(name)
            if norm and norm not in expected_norm:
                expected_norm[norm] = ing

    for norm_name, exp_ing in expected_norm.items():
        if norm_name in extracted_norm:
            ext_ing = extracted_norm[norm_name]
            ext_qty = _parse_quantity(ext_ing.get("quantity") or ext_ing.get("strength"))
            exp_qty = _parse_quantity(exp_ing.get("quantity") or exp_ing.get("strength"))

            qty_match = True
            if ext_qty is not None and exp_qty is not None and exp_qty > 0:
                diff_ratio = abs(ext_qty - exp_qty) / exp_qty
                qty_match = diff_ratio <= QUANTITY_TOLERANCE

            if qty_match:
                matched.append({
                    "name": exp_ing.get("name", norm_name),
                    "expected_qty": exp_ing.get("quantity") or exp_ing.get("strength"),
                    "extracted_qty": ext_ing.get("quantity"),
                    "unit": ext_ing.get("unit") or exp_ing.get("unit"),
                    "match": True,
                })
            else:
                mismatched.append({
                    "name": exp_ing.get("name", norm_name),
                    "expected_qty": exp_ing.get("quantity") or exp_ing.get("strength"),
                    "extracted_qty": ext_ing.get("quantity"),
                    "unit": ext_ing.get("unit") or exp_ing.get("unit"),
                    "match": False,
                    "deviation_pct": round(
                        abs((ext_qty or 0) - (exp_qty or 0)) / (exp_qty or 1) * 100, 1
                    ) if ext_qty and exp_qty else None,
                })
        else:
            # Try partial matching as last resort
            partial_match_found = False
            for ext_norm, ext_ing in extracted_norm.items():
                if (norm_name in ext_norm or ext_norm in norm_name) and len(min(norm_name, ext_norm, key=len)) >= 4:
                    partial_match_found = True
                    matched.append({
                        "name": exp_ing.get("name", norm_name),
                        "expected_qty": exp_ing.get("quantity") or exp_ing.get("strength"),
                        "extracted_qty": ext_ing.get("quantity"),
                        "match": True,
                        "match_type": "partial",
                    })
                    break
            if not partial_match_found:
                missing.append({
                    "name": exp_ing.get("name", norm_name),
                    "expected_qty": exp_ing.get("quantity") or exp_ing.get("strength"),
                })

    # Check for extra active ingredients not in expected list
    for norm_name, ext_ing in extracted_norm.items():
        if norm_name not in expected_norm:
            role = ext_ing.get("role", ext_ing.get("type", "unknown"))
            if role == "active":
                # Also check partial match against expected
                partial_found = any(
                    norm_name in en or en in norm_name
                    for en in expected_norm
                    if len(min(norm_name, en, key=len)) >= 4
                )
                if not partial_found:
                    extra.append({
                        "name": ext_ing.get("name", norm_name),
                        "quantity": ext_ing.get("quantity"),
                        "unit": ext_ing.get("unit"),
                        "concern": "Unexpected active ingredient not in reference database",
                    })

    total_expected = len(expected_norm)
    total_matched = len(matched)

    return {
        "matched": matched,
        "mismatched": mismatched,
        "missing": missing,
        "extra_active": extra,
        "match_ratio": total_matched / total_expected if total_expected > 0 else 0.0,
        "total_expected": total_expected,
        "total_matched": total_matched,
    }


# ---------------------------------------------------------------------------
# Async runner
# ---------------------------------------------------------------------------

def _run_async_safely(coro):
    """Run an async coroutine safely from a sync context."""
    try:
        try:
            loop = asyncio.get_running_loop()
        except RuntimeError:
            loop = None

        if loop is not None and loop.is_running():
            import concurrent.futures
            with concurrent.futures.ThreadPoolExecutor() as pool:
                return pool.submit(asyncio.run, coro).result(timeout=30)
        else:
            return asyncio.run(coro)
    except Exception as exc:
        logger.warning("Async call failed: %s", exc)
        return None


# ---------------------------------------------------------------------------
# Main entry point
# ---------------------------------------------------------------------------

def verify_ingredients(
    ingredients_image_b64: str,
    medicine_name: Optional[str] = None,
    expected_ingredients: Optional[list] = None,
) -> dict:
    """
    Main entry point for Agent 4 - Pharmaceutical-Grade Ingredient Verification.

    Args:
        ingredients_image_b64: Base64-encoded ingredient panel image.
        medicine_name: Medicine name for database cross-referencing.
        expected_ingredients: Optional pre-supplied list of expected ingredient dicts.

    Returns:
        Standardized agent result dict with status PASS/FAIL/UNCERTAIN.
    """
    result: dict = {
        "agent_number": AGENT_NUMBER,
        "agent_name": AGENT_NAME,
        "status": "UNCERTAIN",
        "confidence_score": 0.0,
        "extracted_ingredients": [],
        "dosage_form": None,
        "label_quality": None,
        "verification_result": None,
        "safety_analysis": {
            "banned_substances": [],
            "dangerous_excipients": [],
            "allergen_warnings": [],
            "preservative_concerns": [],
        },
        "side_effect_warnings": [],
        "pubchem_verification": None,
        "data_sources": [],
        "limitation_note": (
            "Ingredient verification is based on label reading only. "
            "It cannot detect actual chemical composition inside the medicine. "
            "Differences may exist between what is printed and what is inside. "
            "A PASS result means the label contents match reference databases, "
            "not that the actual product has been chemically tested."
        ),
        "display_message": "",
        "fail_reason": None,
    }

    # Guard: if no image provided, return early
    if not ingredients_image_b64 or not ingredients_image_b64.strip():
        result["status"] = "UNCERTAIN"
        result["confidence_score"] = 0.0
        result["fail_reason"] = "No ingredient image provided"
        result["display_message"] = (
            "No ingredient panel image was provided. "
            "Please take a clear photo of the ingredient list on the medicine packaging."
        )
        return result

    try:
        client = _get_client()

        # ==================================================================
        # STEP 1: Extract ingredients from image using Claude Vision
        # ==================================================================
        vision_output = _extract_ingredients_vision(client, ingredients_image_b64)

        extracted = vision_output.get("ingredients", [])
        result["extracted_ingredients"] = extracted
        result["dosage_form"] = vision_output.get("dosage_form")
        result["label_quality"] = vision_output.get("label_quality")

        # Store additional vision analysis
        vision_metadata = {
            "drug_class_consistency": vision_output.get("drug_class_consistency"),
            "unusual_ingredients": vision_output.get("unusual_ingredients", []),
            "dosage_form_confidence": vision_output.get("dosage_form_confidence"),
            "label_composition_text": vision_output.get("label_composition_text"),
            "vision_reasoning": vision_output.get("reasoning"),
        }
        result["vision_analysis"] = vision_metadata

        # Check label quality - flag tampering concerns
        label_quality = vision_output.get("label_quality", {})
        if isinstance(label_quality, dict):
            tampering = label_quality.get("tampering_signs", "none")
            if tampering and tampering.lower() not in ("none", "no", "n/a", ""):
                result["fail_reason"] = f"Label tampering detected: {tampering}"
                result["status"] = "FAIL"
                result["confidence_score"] = 0.85
                result["display_message"] = (
                    f"WARNING: Possible label tampering detected - {tampering}. "
                    "This medicine should be physically inspected by a pharmacist."
                )
                # Continue analysis but flag status

        # Check banned substances detected by Vision
        vision_banned = vision_output.get("banned_substances_found", [])
        if vision_banned:
            for b in vision_banned:
                if isinstance(b, str):
                    result["safety_analysis"]["banned_substances"].append({
                        "ingredient": b,
                        "reason": BANNED_SUBSTANCES.get(b.lower(), "Flagged by vision analysis"),
                        "severity": "CRITICAL",
                    })

        # ==================================================================
        # STEP 2: Safety analysis on extracted ingredients
        # ==================================================================
        banned_found = _check_banned_substances(extracted)
        dangerous_found = _check_dangerous_excipients(extracted)
        allergens_found = _check_allergens(extracted)
        preservatives_found = _check_preservatives(extracted)

        result["safety_analysis"]["banned_substances"].extend(banned_found)
        result["safety_analysis"]["dangerous_excipients"] = dangerous_found
        result["safety_analysis"]["allergen_warnings"] = allergens_found
        result["safety_analysis"]["preservative_concerns"] = preservatives_found

        # Critical safety failures
        if banned_found or dangerous_found:
            result["status"] = "FAIL"
            result["confidence_score"] = 0.95
            critical_items = [b["ingredient"] for b in banned_found] + [d["ingredient"] for d in dangerous_found]
            result["fail_reason"] = f"CRITICAL: Banned/dangerous substance(s) detected: {', '.join(critical_items)}"
            result["display_message"] = (
                f"CRITICAL SAFETY ALERT: {', '.join(critical_items)} detected. "
                "This medicine contains substances that are banned or dangerous. "
                "DO NOT USE. Report to DRAP immediately."
            )
            # Still continue to gather more data, but status is locked to FAIL

        # ==================================================================
        # STEP 3: Build expected ingredients from Supabase + OpenFDA
        # ==================================================================
        if not expected_ingredients:
            expected_ingredients = []

            # Source 1: Supabase (DRAP + generic_drugs)
            supabase_ings, supabase_sources = _get_expected_from_supabase(medicine_name)
            if supabase_ings:
                expected_ingredients = supabase_ings
                result["data_sources"].extend(supabase_sources)
                logger.info("Got %d expected ingredients from Supabase", len(supabase_ings))

            # Source 2: OpenFDA from Supabase
            if medicine_name:
                openfda_db_ings = _get_openfda_ingredients_from_supabase(medicine_name)
                if openfda_db_ings:
                    if not expected_ingredients:
                        expected_ingredients = openfda_db_ings
                    result["data_sources"].append("OpenFDA_DB")
                    logger.info("Got %d ingredients from OpenFDA DB", len(openfda_db_ings))

            # Source 3: OpenFDA API fallback
            if medicine_name and not expected_ingredients:
                fda_api_ings = _run_async_safely(_get_expected_from_openfda_api(medicine_name))
                if fda_api_ings:
                    expected_ingredients = fda_api_ings
                    result["data_sources"].append("OpenFDA_API")
                    logger.info("Got %d ingredients from OpenFDA API", len(fda_api_ings))

        # ==================================================================
        # STEP 4: Verify ingredient names via PubChem
        # ==================================================================
        active_names = [
            ing.get("name", "") for ing in extracted
            if ing.get("role", ing.get("type", "")) == "active" and ing.get("name")
        ]
        if active_names:
            pubchem_results = _run_async_safely(_verify_compounds_pubchem(active_names))
            if pubchem_results:
                result["pubchem_verification"] = pubchem_results
                result["data_sources"].append("PubChem")
                unverified = [r for r in pubchem_results if r and not r.get("verified")]
                if unverified:
                    unverified_names = [r.get("name", "?") for r in unverified]
                    logger.warning("PubChem could not verify: %s", unverified_names)

        # ==================================================================
        # STEP 5: Get side effect warnings from Supabase
        # ==================================================================
        all_active_names = [
            ing.get("name", "") for ing in extracted
            if ing.get("role", ing.get("type", "")) == "active" and ing.get("name")
        ]
        if all_active_names:
            side_effects = _get_side_effects_from_supabase(all_active_names)
            if side_effects:
                result["side_effect_warnings"] = side_effects
                if "DrugSideEffects" not in result["data_sources"]:
                    result["data_sources"].append("DrugSideEffects")

        # ==================================================================
        # STEP 6: Compare ingredients (only if status not already FAIL from safety)
        # ==================================================================
        if not expected_ingredients:
            # No reference data - can only report extraction
            if result["status"] != "FAIL":  # Don't override safety FAIL
                result["status"] = "PASS"
                result["confidence_score"] = 0.55
                result["verification_result"] = "extracted_only"
                result["display_message"] = (
                    f"Extracted {len(extracted)} ingredient(s) from the label. "
                    f"Dosage form: {result.get('dosage_form', 'unknown')}. "
                    "No reference data available for cross-verification. "
                    "Label ingredients could not be independently confirmed."
                )
                if allergens_found:
                    allergen_names = [a["allergen"] for a in allergens_found]
                    result["display_message"] += f" Allergen warnings: {', '.join(allergen_names)}."
            return result

        # Perform ingredient comparison with fuzzy matching
        comparison = _compare_ingredients(extracted, expected_ingredients)
        result["verification_result"] = comparison

        # Determine status based on comparison (only if not already FAIL from safety)
        if result["status"] != "FAIL":
            if comparison["match_ratio"] >= 0.90 and not comparison["mismatched"] and not comparison["extra_active"]:
                result["status"] = "PASS"
                result["confidence_score"] = 0.88
                sources_str = ", ".join(result["data_sources"]) if result["data_sources"] else "reference"
                result["display_message"] = (
                    f"Ingredients VERIFIED against {sources_str}. "
                    f"{comparison['total_matched']}/{comparison['total_expected']} active ingredients matched. "
                    f"Dosage form: {result.get('dosage_form', 'N/A')}."
                )
                if allergens_found:
                    allergen_names = list(set(a["allergen"] for a in allergens_found))
                    result["display_message"] += f" Note: contains allergens ({', '.join(allergen_names)})."
                if preservatives_found:
                    result["display_message"] += f" Contains {len(preservatives_found)} preservative(s) - see details."

            elif comparison["extra_active"]:
                result["status"] = "FAIL"
                result["confidence_score"] = 0.82
                extra_names = ", ".join(e["name"] for e in comparison["extra_active"])
                result["fail_reason"] = f"Unexpected active ingredients found: {extra_names}"
                result["display_message"] = (
                    f"WARNING: Unexpected active ingredient(s) detected: {extra_names}. "
                    "These are NOT in the reference database for this medicine. "
                    "This may indicate a counterfeit, adulterated, or mislabeled product."
                )

            elif comparison["mismatched"]:
                result["status"] = "FAIL"
                result["confidence_score"] = 0.80
                mismatch_details = []
                for m in comparison["mismatched"]:
                    detail = m["name"]
                    if m.get("deviation_pct"):
                        detail += f" ({m['deviation_pct']}% off)"
                    mismatch_details.append(detail)
                mismatch_str = ", ".join(mismatch_details)
                result["fail_reason"] = f"Ingredient strength mismatch: {mismatch_str}"
                result["display_message"] = (
                    f"WARNING: Ingredient strength mismatch detected for: {mismatch_str}. "
                    "The quantities on this label differ from reference databases by more than 5%. "
                    "This may indicate a counterfeit, sub-potent, or reformulated product."
                )

            elif comparison["missing"] and comparison["match_ratio"] < 0.5:
                result["status"] = "FAIL"
                result["confidence_score"] = 0.75
                missing_names = ", ".join(m["name"] for m in comparison["missing"])
                result["fail_reason"] = f"Missing expected ingredients: {missing_names}"
                result["display_message"] = (
                    f"WARNING: Expected active ingredients not found on label: {missing_names}. "
                    "This is a significant discrepancy from reference data."
                )

            elif comparison["missing"]:
                result["status"] = "UNCERTAIN"
                result["confidence_score"] = 0.55
                missing_names = ", ".join(m["name"] for m in comparison["missing"])
                result["display_message"] = (
                    f"Partial match: {comparison['total_matched']}/{comparison['total_expected']} ingredients verified. "
                    f"Could not confirm: {missing_names}. "
                    "This may be due to label format differences. Manual verification recommended."
                )

            else:
                result["status"] = "UNCERTAIN"
                result["confidence_score"] = 0.50
                result["display_message"] = (
                    "Partial ingredient verification. Some ingredients could not be definitively matched. "
                    "Manual review by a pharmacist is recommended."
                )

        # Add safety summary to display message if there are concerns
        if result["status"] == "FAIL" and (banned_found or dangerous_found):
            pass  # Already set critical message above
        elif allergens_found and "allergen" not in result.get("display_message", "").lower():
            allergen_names = list(set(a["allergen"] for a in allergens_found))
            result["display_message"] += f" ALLERGEN ALERT: {', '.join(allergen_names)}."

    except ValueError as exc:
        logger.warning("Agent 4 value error: %s", exc)
        result["status"] = "UNCERTAIN"
        result["confidence_score"] = 0.10
        result["fail_reason"] = f"Input/parsing error: {exc}"
        result["display_message"] = (
            "Could not process the ingredient image. "
            "Please ensure the image is clear and the ingredient list is fully visible."
        )
    except json.JSONDecodeError as exc:
        result["status"] = "UNCERTAIN"
        result["confidence_score"] = 0.20
        result["fail_reason"] = f"Failed to parse ingredient data from vision: {exc}"
        result["display_message"] = (
            "Could not read ingredient panel clearly. The image may be blurry, "
            "too dark, or the text too small. Please retake the photo with better lighting "
            "and ensure the ingredient list is fully visible."
        )
    except anthropic.APIError as exc:
        result["status"] = "UNCERTAIN"
        result["confidence_score"] = 0.0
        result["fail_reason"] = f"Vision API error: {exc}"
        result["display_message"] = "Ingredient analysis service temporarily unavailable. Please try again."
    except RuntimeError as exc:
        logger.warning("Agent 4 runtime error: %s", exc)
        result["status"] = "UNCERTAIN"
        result["confidence_score"] = 0.0
        result["fail_reason"] = f"Configuration error: {exc}"
        result["display_message"] = "Ingredient analysis service is not configured. Please contact support."
    except Exception as exc:  # noqa: BLE001
        logger.exception("Agent 4 unexpected error")
        result["status"] = "UNCERTAIN"
        result["confidence_score"] = 0.0
        result["fail_reason"] = f"Unexpected error: {exc}"
        result["display_message"] = "An unexpected error occurred during ingredient verification."

    return result
