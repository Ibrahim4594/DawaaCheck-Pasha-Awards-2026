"""
Upload all DawaaCheck drug data from JSON files into Supabase.
Run AFTER supabase_migration_v2.sql has been executed in Supabase SQL Editor.

Usage:
  pip install supabase python-dotenv
  python upload_to_supabase.py

Requires .env with:
  SUPABASE_URL=https://<your-project-ref>.supabase.co
  SUPABASE_KEY=<service_role_key>  # Use service_role key for inserts (bypasses RLS)
"""
import json
import logging
import os
import sys
import time
from pathlib import Path

logger = logging.getLogger(__name__)

try:
    from supabase import create_client, Client
except ImportError:
    print("Install supabase: pip install supabase")
    sys.exit(1)

try:
    from dotenv import load_dotenv
    load_dotenv()
except ImportError:
    logger.debug("python-dotenv not installed, skipping .env loading")

DATA_DIR = Path(__file__).parent
SUPABASE_URL = os.getenv("SUPABASE_URL", "")
SUPABASE_KEY = os.getenv("SUPABASE_KEY", "")

if not SUPABASE_URL:
    print("ERROR: Set SUPABASE_URL in .env (https://<your-project-ref>.supabase.co)")
    print("Find it at: Supabase Dashboard > Settings > API > Project URL")
    sys.exit(1)

if not SUPABASE_KEY:
    print("ERROR: Set SUPABASE_KEY in .env (use the service_role key, not anon key)")
    print("Find it at: Supabase Dashboard > Settings > API > service_role key")
    sys.exit(1)


def get_client() -> Client:
    return create_client(SUPABASE_URL, SUPABASE_KEY)


def load_json(filename: str):
    path = DATA_DIR / filename
    if not path.exists():
        print(f"  SKIP: {filename} not found")
        return None
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)


def batch_upsert(client: Client, table: str, rows: list[dict], batch_size: int = 50, conflict_col: str = None):
    """Insert rows in batches. Uses upsert if conflict_col specified."""
    total = len(rows)
    inserted = 0
    errors = 0

    for i in range(0, total, batch_size):
        batch = rows[i:i + batch_size]
        try:
            if conflict_col:
                client.table(table).upsert(batch, on_conflict=conflict_col).execute()
            else:
                client.table(table).insert(batch).execute()
            inserted += len(batch)
        except Exception as e:
            err_str = str(e)
            if "duplicate" in err_str.lower() or "unique" in err_str.lower():
                # Try one by one for dedup
                for row in batch:
                    try:
                        if conflict_col:
                            client.table(table).upsert(row, on_conflict=conflict_col).execute()
                        else:
                            client.table(table).insert(row).execute()
                        inserted += 1
                    except Exception:
                        logger.debug("Skipped duplicate row in table '%s'", table)
                        errors += 1
            else:
                print(f"\n    ERROR batch {i}-{i+len(batch)}: {err_str[:200]}")
                errors += len(batch)
        time.sleep(0.1)  # Rate limit friendly

    return inserted, errors


def upload_drap_medicines(client: Client):
    """Upload 329 Pakistani branded medicines."""
    print("\n[1/14] drap_medicines (329 branded medicines)...")
    data = load_json("drap_medicines.json")
    if not data:
        return

    rows = []
    for med in data:
        rows.append({
            "registration_number": str(med.get("registration_number", "")),
            "brand_name": med.get("brand_name", ""),
            "generic_name": med.get("generic_name", ""),
            "manufacturer": med.get("manufacturer", ""),
            "active_ingredients": med.get("active_ingredients", []),
            "dosage_form": med.get("dosage_form", ""),
            "strength": med.get("strength", ""),
            "pack_size": med.get("pack_size", ""),
            "mrp": med.get("mrp"),
            "registration_date": med.get("registration_date"),
            "expiry_date": med.get("expiry_date"),
            "status": med.get("status", "Active"),
            "category": med.get("category", ""),
            "barcode": med.get("barcode", ""),
            "is_otc": med.get("otc", False),
        })

    inserted, errors = batch_upsert(client, "drap_medicines", rows, conflict_col="registration_number")
    print(f"  Inserted: {inserted}, Errors: {errors}")


def upload_generic_drugs(client: Client):
    """Upload 922 generic drugs with clinical data."""
    print("\n[2/14] generic_drugs (922 generics)...")
    data = load_json("generic_drugs_database.json")
    if not data:
        return

    rows = []
    for drug in data:
        name = drug.get("generic_name", "").strip()
        if not name:
            continue
        pregnancy = drug.get("pregnancy", {})
        lactation = drug.get("lactation", {})
        addiction = drug.get("addiction", {})
        rows.append({
            "generic_name": name,
            "therapeutic_class": drug.get("therapeutic_class", ""),
            "mechanism_of_action": drug.get("mechanism_of_action", ""),
            "dosage_guidance": drug.get("dosage_guidance", ""),
            "pregnancy_category": pregnancy.get("category", ""),
            "pregnancy_notes": pregnancy.get("notes", ""),
            "pregnancy_score": pregnancy.get("numeric_score"),
            "lactation_safe": lactation.get("safe"),
            "lactation_notes": lactation.get("notes", ""),
            "fertility_notes": str(drug.get("fertility", {}).get("male", "")) + " " + str(drug.get("fertility", {}).get("female", "")),
            "is_controlled": addiction.get("controlled_substance", False) if addiction else False,
            "addiction_notes": addiction.get("potential", "") if addiction else "",
            "contraindications": drug.get("contraindications", []),
            "drug_interactions_list": drug.get("drug_interactions", []),
            "special_populations": drug.get("special_populations", {}),
            "forms": drug.get("forms", []),
            "source_version": drug.get("source_version", ""),
            "last_updated": drug.get("last_updated", ""),
        })

    inserted, errors = batch_upsert(client, "generic_drugs", rows, conflict_col="generic_name")
    print(f"  Inserted: {inserted}, Errors: {errors}")


def upload_drug_interactions(client: Client):
    """Upload 50 drug-drug interactions."""
    print("\n[3/14] drug_interactions (50 interactions)...")
    data = load_json("drug_interactions.json")
    if not data:
        return

    rows = []
    for ix in data:
        rows.append({
            "drug_a": ix.get("drug_a", ""),
            "drug_b": ix.get("drug_b", ""),
            "severity": ix.get("severity", "MODERATE"),
            "description": ix.get("description", ""),
            "recommendation": ix.get("recommendation", ""),
        })

    inserted, errors = batch_upsert(client, "drug_interactions", rows, conflict_col="drug_a,drug_b")
    print(f"  Inserted: {inserted}, Errors: {errors}")


def upload_side_effects(client: Client):
    """Upload 149 drug side effects."""
    print("\n[4/14] drug_side_effects (149 drugs)...")
    data = load_json("common_side_effects.json")
    if not data:
        return

    rows = []
    for drug_name, info in data.items():
        common = info.get("common", [])
        serious = info.get("serious", [])
        # Normalize: some have string values instead of lists
        if isinstance(common, str):
            common = [common]
        if isinstance(serious, str):
            serious = [serious]

        contraindicated = info.get("contraindicated", "")
        if isinstance(contraindicated, str):
            contraindicated = [contraindicated] if contraindicated else []

        avoid_with = info.get("avoid_with", "")
        if isinstance(avoid_with, str):
            avoid_with = [avoid_with] if avoid_with else []

        rows.append({
            "drug_name": drug_name,
            "common_effects": common,
            "serious_effects": serious,
            "black_box_warning": info.get("black_box", info.get("black_box_warning", "")),
            "max_dose": info.get("max_dose", ""),
            "overdose_antidote": info.get("overdose_antidote", ""),
            "contraindicated": contraindicated,
            "avoid_with": avoid_with,
        })

    inserted, errors = batch_upsert(client, "drug_side_effects", rows, conflict_col="drug_name")
    print(f"  Inserted: {inserted}, Errors: {errors}")


def upload_who_aware(client: Client):
    """Upload 60 WHO AWaRe antibiotics."""
    print("\n[5/14] who_aware_antibiotics (60 antibiotics)...")
    data = load_json("who_aware.json")
    if not data:
        return

    rows = []
    for category in ["access", "watch", "reserve"]:
        items = data.get(category, [])
        for item in items:
            rows.append({
                "name": item.get("name", ""),
                "category": category,
                "antibiotic_class": item.get("class", ""),
                "key_access": item.get("key_access", False),
                "oral_available": item.get("oral_available", False),
            })

    inserted, errors = batch_upsert(client, "who_aware_antibiotics", rows)
    print(f"  Inserted: {inserted}, Errors: {errors}")


def upload_pediatric_safety(client: Client):
    """Upload 35 pediatric safety entries."""
    print("\n[6/14] pediatric_safety (35 entries)...")
    data = load_json("pediatric_safety.json")
    if not data:
        return

    rows = []
    for safety_type in ["contraindicated", "dose_adjustment_required", "monitoring_required"]:
        items = data.get(safety_type, [])
        # Normalize safety_type key
        db_type = safety_type.replace("_required", "")
        if db_type == "dose_adjustment":
            db_type = "dose_adjustment"
        elif db_type == "monitoring":
            db_type = "monitoring_required"

        for item in items:
            rows.append({
                "drug_name": item.get("drug", ""),
                "safety_type": db_type if db_type in ("contraindicated", "dose_adjustment", "monitoring_required") else "contraindicated",
                "reason": item.get("reason", ""),
                "age_limit": item.get("age_limit", ""),
                "alternative": item.get("alternative", ""),
                "dose_info": item.get("dose_adjustment", item.get("dose_info", "")),
                "monitoring_parameters": item.get("monitoring", item.get("monitoring_parameters", "")),
            })

    inserted, errors = batch_upsert(client, "pediatric_safety", rows)
    print(f"  Inserted: {inserted}, Errors: {errors}")


def upload_prices(client: Client):
    """Upload 135 price entries with generic alternatives."""
    print("\n[7/14] medicine_prices (135 entries)...")
    data = load_json("price_database.json")
    if not data:
        return

    rows = []
    for item in data:
        rows.append({
            "brand_name": item.get("brand_name", ""),
            "generic_name": item.get("generic_name", ""),
            "manufacturer": item.get("manufacturer", ""),
            "dosage_form": item.get("dosage_form", ""),
            "strength": item.get("strength", ""),
            "pack_size": item.get("pack_size", ""),
            "mrp": item.get("mrp"),
            "generic_alternatives": item.get("generic_alternatives", []),
        })

    inserted, errors = batch_upsert(client, "medicine_prices", rows)
    print(f"  Inserted: {inserted}, Errors: {errors}")


def upload_images(client: Client):
    """Upload 69 medicine image URLs."""
    print("\n[8/14] medicine_images (69 images)...")
    data = load_json("medicine_images.json")
    if not data:
        return

    rows = []
    for drug_name, entry in data.items():
        images = entry.get("images", [])
        for img in images:
            rows.append({
                "drug_name": drug_name,
                "image_url": img.get("url", ""),
                "image_type": "molecular" if "wikipedia" in img.get("source", "").lower() else "label",
                "source": img.get("source", ""),
                "license": img.get("license", ""),
                "width": img.get("width"),
                "height": img.get("height"),
            })

    inserted, errors = batch_upsert(client, "medicine_images", rows)
    print(f"  Inserted: {inserted}, Errors: {errors}")


def upload_conditions(client: Client):
    """Upload 29 drug-condition treatment guidelines."""
    print("\n[9/14] drug_conditions (29 conditions)...")
    data = load_json("drug_conditions.json")
    if not data:
        return

    conditions = data.get("conditions", data)
    rows = []
    for condition_name, info in conditions.items():
        # Collect all drug list fields into first/second/third line
        first = info.get("first_line", info.get("reliever", []))
        second = info.get("second_line", info.get("controller_mild", info.get("controller_moderate", [])))
        third = info.get("third_line", info.get("add_on", []))

        rows.append({
            "condition_name": condition_name,
            "first_line": first if isinstance(first, list) else [first],
            "second_line": second if isinstance(second, list) else [second],
            "third_line": third if isinstance(third, list) else [third],
            "lifestyle": info.get("lifestyle", ""),
            "monitoring": info.get("monitoring", ""),
        })

    inserted, errors = batch_upsert(client, "drug_conditions", rows, conflict_col="condition_name")
    print(f"  Inserted: {inserted}, Errors: {errors}")


def upload_manufacturers(client: Client):
    """Upload 27 Pakistani pharma manufacturers."""
    print("\n[10/14] manufacturers (27 companies)...")
    data = load_json("pakistan_manufacturers.json")
    if not data:
        return

    rows = []
    for mfr in data:
        rows.append({
            "name": mfr.get("name", ""),
            "city": mfr.get("city", ""),
            "company_type": mfr.get("type", ""),
            "drap_license": mfr.get("drap_license", ""),
            "major_brands": mfr.get("major_brands", []),
            "established": mfr.get("established"),
        })

    inserted, errors = batch_upsert(client, "manufacturers", rows, conflict_col="name")
    print(f"  Inserted: {inserted}, Errors: {errors}")


def upload_openfda_drugs(client: Client):
    """Upload 920 OpenFDA drug labels."""
    print("\n[11/14] openfda_drugs (920 labels)...")
    data = load_json("openfda_drugs_massive.json")
    if not data:
        data = load_json("openfda_drugs.json")
    if not data:
        return

    rows = []
    for drug in data:
        # Truncate long text fields to stay within Supabase limits
        def trunc(val, maxlen=5000):
            if isinstance(val, list):
                val = "; ".join(str(v) for v in val)
            return str(val)[:maxlen] if val else ""

        rows.append({
            "generic_name": drug.get("generic_name", drug.get("search_term", "")),
            "brand_names": drug.get("brand_names", drug.get("all_brand_names", [])),
            "manufacturer": drug.get("manufacturer", ""),
            "route": drug.get("route", []),
            "substance_name": drug.get("substance_name", drug.get("active_ingredients", [])),
            "product_type": drug.get("product_type", []),
            "dosage_form": drug.get("dosage_form", ""),
            "indications": trunc(drug.get("indications", drug.get("indications_and_usage", ""))),
            "warnings": trunc(drug.get("warnings", "")),
            "contraindications": trunc(drug.get("contraindications", "")),
            "drug_interactions": trunc(drug.get("drug_interactions", "")),
            "pregnancy": trunc(drug.get("pregnancy", drug.get("pregnancy_category", ""))),
            "pediatric_use": trunc(drug.get("pediatric_use", "")),
            "adverse_reactions": trunc(drug.get("adverse_reactions", "")),
        })

    inserted, errors = batch_upsert(client, "openfda_drugs", rows, batch_size=30)
    print(f"  Inserted: {inserted}, Errors: {errors}")


def upload_adverse_events(client: Client):
    """Upload 104 adverse event profiles."""
    print("\n[12/14] openfda_adverse_events (104 profiles)...")
    data = load_json("openfda_adverse_events.json")
    if not data:
        return

    rows = []
    for event in data:
        rows.append({
            "drug_name": event.get("drug_name", ""),
            "top_reactions": event.get("top_reactions", []),
        })

    inserted, errors = batch_upsert(client, "openfda_adverse_events", rows)
    print(f"  Inserted: {inserted}, Errors: {errors}")


def upload_drap_recalls(client: Client):
    """Upload 50 DRAP recalls."""
    print("\n[13/14] drap_recalls (50 recalls)...")
    data = load_json("drap_recalls.json")
    if not data:
        return

    rows = []
    for recall in data:
        rows.append({
            "id": recall.get("id", ""),
            "recall_class": recall.get("recall_class", "CLASS_II"),
            "medicine_name": recall.get("medicine_name", ""),
            "registration_number": recall.get("registration_number", ""),
            "batch_numbers": recall.get("batch_numbers", []),
            "recall_reason": recall.get("recall_reason", ""),
            "recall_date": recall.get("recall_date", "2025-01-01"),
            "drap_notice_number": recall.get("drap_notice_number", ""),
            "is_active": recall.get("is_active", True),
            "manufacturer": recall.get("manufacturer", ""),
            "affected_regions": recall.get("affected_regions", []),
        })

    inserted, errors = batch_upsert(client, "drap_recalls", rows, conflict_col="id")
    print(f"  Inserted: {inserted}, Errors: {errors}")


def upload_rxnorm(client: Client):
    """Upload 46 RxNorm classifications."""
    print("\n[14/14] rxnorm_classifications (46 entries)...")
    data = load_json("rxnorm_classifications.json")
    if not data:
        return

    rows = []
    for drug in data:
        rows.append({
            "drug_name": drug.get("name", ""),
            "rxcui": drug.get("rxcui", ""),
            "classes": drug.get("classes", []),
            "properties": drug.get("properties", {}),
        })

    inserted, errors = batch_upsert(client, "rxnorm_classifications", rows)
    print(f"  Inserted: {inserted}, Errors: {errors}")


def main():
    print("=" * 60)
    print("DawaaCheck — Upload Drug Data to Supabase")
    print("=" * 60)
    print(f"URL: {SUPABASE_URL}")
    print(f"Data dir: {DATA_DIR}")
    print()

    client = get_client()

    # Test connection
    try:
        result = client.table("drap_medicines").select("id", count="exact").limit(1).execute()
        print(f"Connected! Current drap_medicines rows: {result.count}")
    except Exception as e:
        print(f"Connection test failed: {e}")
        print("Make sure you've run supabase_migration_v2.sql first!")
        sys.exit(1)

    print()
    start = time.time()

    upload_drap_medicines(client)
    upload_generic_drugs(client)
    upload_drug_interactions(client)
    upload_side_effects(client)
    upload_who_aware(client)
    upload_pediatric_safety(client)
    upload_prices(client)
    upload_images(client)
    upload_conditions(client)
    upload_manufacturers(client)
    upload_openfda_drugs(client)
    upload_adverse_events(client)
    upload_drap_recalls(client)
    upload_rxnorm(client)

    elapsed = time.time() - start
    print(f"\n{'=' * 60}")
    print(f"Upload complete in {elapsed:.1f}s")
    print(f"{'=' * 60}")

    # Verify counts
    print("\nVerifying table counts:")
    tables = [
        "drap_medicines", "generic_drugs", "drug_interactions", "drug_side_effects",
        "who_aware_antibiotics", "pediatric_safety", "medicine_prices", "medicine_images",
        "drug_conditions", "manufacturers", "openfda_drugs", "openfda_adverse_events",
        "drap_recalls", "rxnorm_classifications",
    ]
    total = 0
    for table in tables:
        try:
            result = client.table(table).select("id", count="exact").limit(0).execute()
            count = result.count or 0
            total += count
            print(f"  {table}: {count}")
        except Exception as e:
            print(f"  {table}: ERROR - {e}")

    print(f"\n  TOTAL RECORDS: {total}")


if __name__ == "__main__":
    main()
