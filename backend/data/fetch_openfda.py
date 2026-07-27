"""
fetch_openfda.py
Downloads drug label data and recall/enforcement data from the free OpenFDA API
for medicines commonly sold in Pakistan. Saves results as JSON files.

Usage:
    python fetch_openfda.py
"""

import json
import time
import urllib.request
import urllib.parse
import urllib.error
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent

LABEL_API = "https://api.fda.gov/drug/label.json"
ENFORCEMENT_API = "https://api.fda.gov/drug/enforcement.json"

DRUGS = [
    "paracetamol", "acetaminophen", "ibuprofen", "mefenamic acid",
    "diclofenac", "aspirin", "amoxicillin", "amoxicillin clavulanate",
    "azithromycin", "ciprofloxacin", "metronidazole", "cefixime",
    "cephalexin", "levofloxacin", "clarithromycin", "doxycycline",
    "omeprazole", "esomeprazole", "ranitidine", "pantoprazole",
    "domperidone", "metformin", "glimepiride", "sitagliptin",
    "amlodipine", "atenolol", "losartan", "enalapril", "lisinopril",
    "atorvastatin", "rosuvastatin", "salbutamol", "montelukast",
    "cetirizine", "loratadine", "fexofenadine", "sertraline",
    "fluoxetine", "escitalopram", "alprazolam", "pregabalin",
    "gabapentin", "insulin", "levothyroxine", "prednisolone",
    "dexamethasone", "clotrimazole", "fluconazole", "acyclovir",
    "warfarin",
]

REQUEST_DELAY = 2.0  # seconds between requests (rate limit: 40/min without key)


def _safe_first(obj: dict, key: str) -> str:
    """Return first element of a list field, or empty string."""
    val = obj.get(key)
    if isinstance(val, list) and val:
        return val[0]
    if isinstance(val, str):
        return val
    return ""


def _extract_ingredients(result: dict) -> list:
    """Extract active ingredients with strengths from openfda + spl fields."""
    ingredients = []
    openfda = result.get("openfda", {})

    substance_names = openfda.get("substance_name", [])
    # Try to pair with active_ingredient text
    active_text = _safe_first(result, "active_ingredient")

    for name in substance_names:
        entry = {"name": name, "strength": ""}
        # Try to find strength in active_ingredient text
        if active_text:
            lower = active_text.lower()
            idx = lower.find(name.lower())
            if idx != -1:
                # Look for a dosage pattern after the name
                snippet = active_text[idx + len(name):idx + len(name) + 80]
                # crude extraction of strength
                for part in snippet.replace(",", " ").split():
                    if any(u in part.lower() for u in ["mg", "ml", "mcg", "g", "%", "iu", "unit"]):
                        entry["strength"] = part.strip(" .-)(")
                        break
        ingredients.append(entry)

    if not ingredients and active_text:
        ingredients.append({"name": active_text[:200], "strength": ""})

    return ingredients


def _extract_drug(result: dict, search_term: str) -> dict:
    """Extract relevant fields from an OpenFDA drug label result."""
    openfda = result.get("openfda", {})

    brand_names = openfda.get("brand_name", [])
    generic_names = openfda.get("generic_name", [])

    return {
        "search_term": search_term,
        "brand_name": brand_names[0] if brand_names else "",
        "generic_name": generic_names[0] if generic_names else "",
        "all_brand_names": brand_names,
        "all_generic_names": generic_names,
        "active_ingredients": _extract_ingredients(result),
        "warnings": _safe_first(result, "warnings"),
        "indications_and_usage": _safe_first(result, "indications_and_usage"),
        "dosage_and_administration": _safe_first(result, "dosage_and_administration"),
        "pregnancy_category": (
            _safe_first(result, "pregnancy")
            or _safe_first(result, "pregnancy_or_breast_feeding")
        ),
        "pediatric_use": _safe_first(result, "pediatric_use"),
        "storage_and_handling": (
            _safe_first(result, "storage_and_handling")
            or _safe_first(result, "how_supplied")
        ),
        "manufacturer": openfda.get("manufacturer_name", [None])[0] if openfda.get("manufacturer_name") else "",
        "route": openfda.get("route", []),
        "product_type": openfda.get("product_type", []),
    }


def fetch_json(url: str) -> dict | None:
    """Fetch JSON from a URL, return None on error."""
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "DawaaCheck/1.0"})
        with urllib.request.urlopen(req, timeout=30) as resp:
            return json.loads(resp.read().decode("utf-8"))
    except urllib.error.HTTPError as e:
        if e.code == 404:
            return None
        print(f"  HTTP {e.code} for {url[:100]}")
        return None
    except Exception as e:
        print(f"  Error: {e}")
        return None


def fetch_drug_labels() -> list[dict]:
    """Fetch drug labels for all drugs in the list."""
    all_drugs = []
    seen_brands = set()

    for i, drug in enumerate(DRUGS):
        print(f"[{i+1}/{len(DRUGS)}] Searching labels for: {drug}")
        search = urllib.parse.quote(f'openfda.generic_name:"{drug}"')
        url = f"{LABEL_API}?search={search}&limit=3"
        data = fetch_json(url)

        if data and "results" in data:
            count = 0
            for result in data["results"]:
                extracted = _extract_drug(result, drug)
                key = (extracted["brand_name"].lower(), extracted["generic_name"].lower())
                if key not in seen_brands and (extracted["brand_name"] or extracted["generic_name"]):
                    seen_brands.add(key)
                    all_drugs.append(extracted)
                    count += 1
            print(f"  Found {count} new drug(s)")
        else:
            # Fallback: search in substance_name
            search2 = urllib.parse.quote(f'openfda.substance_name:"{drug}"')
            url2 = f"{LABEL_API}?search={search2}&limit=3"
            time.sleep(REQUEST_DELAY)
            data2 = fetch_json(url2)
            if data2 and "results" in data2:
                count = 0
                for result in data2["results"]:
                    extracted = _extract_drug(result, drug)
                    key = (extracted["brand_name"].lower(), extracted["generic_name"].lower())
                    if key not in seen_brands and (extracted["brand_name"] or extracted["generic_name"]):
                        seen_brands.add(key)
                        all_drugs.append(extracted)
                        count += 1
                print(f"  Fallback found {count} new drug(s)")
            else:
                print(f"  No results for {drug}")

        time.sleep(REQUEST_DELAY)

    return all_drugs


def fetch_recalls() -> list[dict]:
    """Fetch drug enforcement/recall data for all drugs."""
    all_recalls = []
    seen_ids = set()

    for i, drug in enumerate(DRUGS):
        print(f"[{i+1}/{len(DRUGS)}] Searching recalls for: {drug}")
        search = urllib.parse.quote(f'reason_for_recall:"{drug}"')
        url = f"{ENFORCEMENT_API}?search={search}&limit=5"
        data = fetch_json(url)

        if data and "results" in data:
            count = 0
            for r in data["results"]:
                recall_id = r.get("recall_number", r.get("event_id", ""))
                if recall_id and recall_id in seen_ids:
                    continue
                if recall_id:
                    seen_ids.add(recall_id)

                all_recalls.append({
                    "search_term": drug,
                    "recall_number": recall_id,
                    "event_id": r.get("event_id", ""),
                    "status": r.get("status", ""),
                    "classification": r.get("classification", ""),
                    "product_description": r.get("product_description", ""),
                    "reason_for_recall": r.get("reason_for_recall", ""),
                    "recalling_firm": r.get("recalling_firm", ""),
                    "city": r.get("city", ""),
                    "state": r.get("state", ""),
                    "country": r.get("country", ""),
                    "recall_initiation_date": r.get("recall_initiation_date", ""),
                    "report_date": r.get("report_date", ""),
                    "voluntary_mandated": r.get("voluntary_mandated", ""),
                })
                count += 1
            print(f"  Found {count} recall(s)")
        else:
            print(f"  No recalls for {drug}")

        time.sleep(REQUEST_DELAY)

    return all_recalls


def main():
    print("=" * 60)
    print("DawaaCheck - OpenFDA Data Fetcher")
    print("=" * 60)

    # Fetch drug labels
    print("\n--- Fetching Drug Labels ---")
    drugs = fetch_drug_labels()
    drugs_path = BASE_DIR / "openfda_drugs.json"
    with open(drugs_path, "w", encoding="utf-8") as f:
        json.dump(drugs, f, indent=2, ensure_ascii=False)
    print(f"\nSaved {len(drugs)} drugs to {drugs_path}")

    # Fetch recalls
    print("\n--- Fetching Recalls/Enforcement ---")
    recalls = fetch_recalls()
    recalls_path = BASE_DIR / "openfda_recalls.json"
    with open(recalls_path, "w", encoding="utf-8") as f:
        json.dump(recalls, f, indent=2, ensure_ascii=False)
    print(f"\nSaved {len(recalls)} recalls to {recalls_path}")

    # Summary
    print("\n" + "=" * 60)
    print("SUMMARY")
    print(f"  Drug labels downloaded: {len(drugs)}")
    print(f"  Recalls downloaded:     {len(recalls)}")
    print(f"  Drugs file: {drugs_path}")
    print(f"  Recalls file: {recalls_path}")
    print("=" * 60)


if __name__ == "__main__":
    main()
