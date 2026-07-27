"""
Fetch real medicine images from FREE sources:
1. RxImage API (NIH) — actual pill/tablet photos
2. DailyMed API (NIH) — official FDA label images
3. Wikipedia — box photos + molecular structures
4. OpenFDA — package NDC image links

Stores results in medicine_images table in Supabase.
"""
import json
import logging
import os
import sys
import time
import urllib.parse
from pathlib import Path

logger = logging.getLogger(__name__)

try:
    import httpx
except ImportError:
    print("Installing httpx...")
    os.system(f"{sys.executable} -m pip install httpx")
    import httpx

try:
    from dotenv import load_dotenv
    load_dotenv(Path(__file__).parent.parent / ".env")
except ImportError:
    pass

try:
    from supabase import create_client
except ImportError:
    print("Installing supabase...")
    os.system(f"{sys.executable} -m pip install supabase")
    from supabase import create_client

DATA_DIR = Path(__file__).parent

# Top medicines to fetch images for (demo priority)
PRIORITY_MEDICINES = [
    # Pakistani brands (top demo medicines)
    ("Panadol", "Paracetamol"),
    ("Augmentin", "Amoxicillin"),
    ("Brufen", "Ibuprofen"),
    ("Flagyl", "Metronidazole"),
    ("Amoxil", "Amoxicillin"),
    ("Septran", "Sulfamethoxazole"),
    ("Disprin", "Aspirin"),
    ("Ponstan", "Mefenamic Acid"),
    ("Arinac", "Ibuprofen"),
    ("Calpol", "Paracetamol"),
    ("Risek", "Omeprazole"),
    ("Novidat", "Ciprofloxacin"),
    ("Rigix", "Cetirizine"),
    ("Ventolin", "Salbutamol"),
    ("Glucophage", "Metformin"),
    ("Norvasc", "Amlodipine"),
    ("Lipitor", "Atorvastatin"),
    ("Zoloft", "Sertraline"),
    ("Nexium", "Esomeprazole"),
    ("Crestor", "Rosuvastatin"),
    # Common generics
    ("Metformin", "Metformin"),
    ("Amlodipine", "Amlodipine"),
    ("Atorvastatin", "Atorvastatin"),
    ("Omeprazole", "Omeprazole"),
    ("Losartan", "Losartan"),
    ("Ciprofloxacin", "Ciprofloxacin"),
    ("Azithromycin", "Azithromycin"),
    ("Cetirizine", "Cetirizine"),
    ("Doxycycline", "Doxycycline"),
    ("Montelukast", "Montelukast"),
    ("Pregabalin", "Pregabalin"),
    ("Gabapentin", "Gabapentin"),
    ("Pantoprazole", "Pantoprazole"),
    ("Sertraline", "Sertraline"),
    ("Escitalopram", "Escitalopram"),
    ("Diclofenac", "Diclofenac"),
    ("Tramadol", "Tramadol"),
    ("Metoprolol", "Metoprolol"),
    ("Furosemide", "Furosemide"),
    ("Warfarin", "Warfarin"),
    ("Clopidogrel", "Clopidogrel"),
    ("Insulin", "Insulin"),
    ("Levothyroxine", "Levothyroxine"),
    ("Prednisolone", "Prednisolone"),
    ("Clarithromycin", "Clarithromycin"),
    ("Levofloxacin", "Levofloxacin"),
    ("Ranitidine", "Ranitidine"),
    ("Domperidone", "Domperidone"),
    ("Loratadine", "Loratadine"),
    ("Bisoprolol", "Bisoprolol"),
]

client = httpx.Client(
    timeout=15,
    follow_redirects=True,
    headers={"User-Agent": "DawaaCheck/1.0 (health-app; contact@dawaacheck.pk)"},
)
all_images = []


def fetch_rximage(drug_name: str) -> list[dict]:
    """RxImage API is permanently down (DNS dead). Skip."""
    return []


def fetch_dailymed(drug_name: str) -> list[dict]:
    """Fetch official label images from DailyMed. Uses search → media pipeline."""
    images = []
    try:
        search_url = f"https://dailymed.nlm.nih.gov/dailymed/services/v2/spls.json?drug_name={urllib.parse.quote(drug_name)}&page=1&pagesize=3"
        resp = client.get(search_url)
        if resp.status_code != 200:
            return images
        data = resp.json()
        results = data.get("data", [])
        if not isinstance(results, list) or not results:
            return images

        for spl in results[:2]:
            setid = spl.get("setid", "")
            if not setid:
                continue
            # Try media endpoint
            try:
                media_url = f"https://dailymed.nlm.nih.gov/dailymed/services/v2/spls/{setid}/media.json"
                media_resp = client.get(media_url)
                if media_resp.status_code == 200:
                    media_data = media_resp.json()
                    media_list = media_data.get("data", [])
                    if isinstance(media_list, list):
                        for media in media_list[:2]:
                            if not isinstance(media, dict):
                                continue
                            mime = media.get("mime_type", "")
                            name = media.get("name", "")
                            if "image" in mime or name.lower().endswith((".jpg", ".png", ".gif")):
                                img_url = f"https://dailymed.nlm.nih.gov/dailymed/image.cfm?setid={setid}&name={name}"
                                images.append({
                                    "drug_name": drug_name,
                                    "image_url": img_url,
                                    "image_type": "label",
                                    "source": "DailyMed NIH",
                                    "license": "Public Domain (US Government)",
                                })
                                if len(images) >= 2:
                                    return images
            except Exception:
                continue
    except Exception:
        logger.debug("Failed to fetch DailyMed images for %s", drug_name)
    return images


def fetch_wikipedia_image(drug_name: str) -> list[dict]:
    """Fetch medicine images from Wikipedia REST API."""
    images = []
    try:
        # Search Wikipedia for the drug
        search_url = f"https://en.wikipedia.org/api/rest_v1/page/summary/{urllib.parse.quote(drug_name)}"
        resp = client.get(search_url)
        if resp.status_code == 200:
            data = resp.json()
            thumb = data.get("thumbnail", {})
            original = data.get("originalimage", {})
            img_url = original.get("source") or thumb.get("source")
            if img_url:
                images.append({
                    "drug_name": drug_name,
                    "image_url": img_url,
                    "image_type": "molecular",
                    "source": "Wikipedia",
                    "license": "CC BY-SA",
                    "width": original.get("width") or thumb.get("width"),
                    "height": original.get("height") or thumb.get("height"),
                })
    except Exception:
        logger.debug("Failed to fetch Wikipedia image for %s", drug_name)
    return images


def fetch_openfda_image(drug_name: str) -> list[dict]:
    """Try to get package label images via OpenFDA → DailyMed link."""
    images = []
    try:
        url = f"https://api.fda.gov/drug/label.json?search=openfda.brand_name:\"{urllib.parse.quote(drug_name)}\"&limit=1"
        resp = client.get(url)
        if resp.status_code == 200:
            data = resp.json()
            results = data.get("results", [])
            if results:
                result = results[0]
                # Get set_id for DailyMed link
                set_id = result.get("set_id", "")
                if set_id:
                    dailymed_url = f"https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid={set_id}"
                    images.append({
                        "drug_name": drug_name,
                        "image_url": dailymed_url,
                        "image_type": "label_page",
                        "source": "OpenFDA/DailyMed",
                        "license": "Public Domain (US Government)",
                    })
    except Exception:
        logger.debug("Failed to fetch OpenFDA image for %s", drug_name)
    return images


def main():
    print("=" * 60)
    print("DawaaCheck — Fetch Real Medicine Images")
    print("=" * 60)

    total_found = 0
    results_by_drug = {}

    for brand_name, generic_name in PRIORITY_MEDICINES:
        drug_key = generic_name  # Use generic name as key for dedup
        if drug_key in results_by_drug:
            continue

        print(f"\n  [{generic_name}] ({brand_name})...")
        drug_images = []

        # 1. RxImage (pill photos - best source)
        imgs = fetch_rximage(generic_name)
        if imgs:
            print(f"    RxImage: {len(imgs)} pill photos")
            drug_images.extend(imgs)

        # 2. DailyMed (label images)
        imgs = fetch_dailymed(generic_name)
        if imgs:
            print(f"    DailyMed: {len(imgs)} label images")
            drug_images.extend(imgs)

        # 3. Wikipedia (molecular/box images)
        imgs = fetch_wikipedia_image(generic_name)
        if imgs:
            print(f"    Wikipedia: {len(imgs)} images")
            drug_images.extend(imgs)

        # 4. OpenFDA → DailyMed links
        imgs = fetch_openfda_image(brand_name)
        if not imgs:
            imgs = fetch_openfda_image(generic_name)
        if imgs:
            print(f"    OpenFDA: {len(imgs)} label links")
            drug_images.extend(imgs)

        if not drug_images:
            print(f"    No images found")

        results_by_drug[drug_key] = drug_images
        all_images.extend(drug_images)
        total_found += len(drug_images)

        time.sleep(0.3)  # Rate limit

    print(f"\n{'=' * 60}")
    print(f"Total images found: {total_found}")
    print(f"Drugs with images: {sum(1 for v in results_by_drug.values() if v)}/{len(results_by_drug)}")

    # Save to JSON
    output_path = DATA_DIR / "real_medicine_images.json"
    with open(output_path, "w", encoding="utf-8") as f:
        json.dump(all_images, f, indent=2, ensure_ascii=False)
    print(f"Saved to {output_path}")

    # Upload to Supabase
    supabase_url = os.getenv("SUPABASE_URL")
    supabase_key = os.getenv("SUPABASE_KEY")
    if supabase_url and supabase_key:
        print("\nUploading to Supabase...")
        sb = create_client(supabase_url, supabase_key)

        uploaded = 0
        seen_urls = set()
        for img in all_images:
            url = img["image_url"]
            if url in seen_urls:
                continue
            seen_urls.add(url)
            try:
                row = {
                    "drug_name": img["drug_name"],
                    "image_url": url,
                    "image_type": img["image_type"],
                    "source": img["source"],
                    "license": img.get("license", ""),
                    "width": img.get("width"),
                    "height": img.get("height"),
                }
                sb.table("medicine_images").insert(row).execute()
                uploaded += 1
            except Exception:
                logger.debug("Skipped duplicate image upload for %s", img["drug_name"])
            time.sleep(0.05)

        print(f"Uploaded {uploaded} new images to Supabase")

        # Show final count
        count_resp = sb.table("medicine_images").select("id", count="exact").limit(0).execute()
        print(f"Total medicine_images in Supabase: {count_resp.count}")
    else:
        print("\nNo Supabase credentials found — saved to JSON only")


if __name__ == "__main__":
    main()
