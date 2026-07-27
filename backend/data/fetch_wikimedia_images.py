"""
Fetch real medicine images from working sources:
1. Wikipedia REST API — drug page thumbnails/images
2. DailyMed API (NIH) — actual pill & package photos (public domain)

Uploads to Supabase medicine_images table.
"""
import json
import logging
import os
import sys
import time
import urllib.parse
from pathlib import Path

logger = logging.getLogger(__name__)

import httpx

try:
    from dotenv import load_dotenv
    load_dotenv(Path(__file__).parent.parent / ".env")
except ImportError:
    pass

DATA_DIR = Path(__file__).parent

client = httpx.Client(timeout=15, follow_redirects=True, headers={
    "User-Agent": "DawaaCheck/1.0 (https://dawaacheck.pk; health-education-app) Python/httpx",
    "Accept": "application/json",
})

# All medicines — (brand, generic)
MEDICINES = [
    ("Panadol", "paracetamol"), ("Augmentin", "amoxicillin"),
    ("Brufen", "ibuprofen"), ("Flagyl", "metronidazole"),
    ("Amoxil", "amoxicillin"), ("Calpol", "paracetamol"),
    ("Ponstan", "mefenamic acid"), ("Risek", "omeprazole"),
    ("Novidat", "ciprofloxacin"), ("Rigix", "cetirizine"),
    ("Ventolin", "salbutamol"), ("Glucophage", "metformin"),
    ("Disprin", "aspirin"), ("Zyrtec", "cetirizine"),
    ("Nexium", "esomeprazole"), ("Norvasc", "amlodipine"),
    ("Lipitor", "atorvastatin"), ("Zoloft", "sertraline"),
    ("Crestor", "rosuvastatin"), ("Metformin", "metformin"),
    ("Amlodipine", "amlodipine"), ("Atorvastatin", "atorvastatin"),
    ("Omeprazole", "omeprazole"), ("Losartan", "losartan"),
    ("Ciprofloxacin", "ciprofloxacin"), ("Azithromycin", "azithromycin"),
    ("Cetirizine", "cetirizine"), ("Doxycycline", "doxycycline"),
    ("Montelukast", "montelukast"), ("Pregabalin", "pregabalin"),
    ("Gabapentin", "gabapentin"), ("Pantoprazole", "pantoprazole"),
    ("Sertraline", "sertraline"), ("Escitalopram", "escitalopram"),
    ("Diclofenac", "diclofenac"), ("Tramadol", "tramadol"),
    ("Metoprolol", "metoprolol"), ("Furosemide", "furosemide"),
    ("Warfarin", "warfarin"), ("Clopidogrel", "clopidogrel"),
    ("Levothyroxine", "levothyroxine"), ("Prednisolone", "prednisolone"),
    ("Clarithromycin", "clarithromycin"), ("Levofloxacin", "levofloxacin"),
    ("Loratadine", "loratadine"), ("Bisoprolol", "bisoprolol"),
    ("Rosuvastatin", "rosuvastatin"), ("Aspirin", "aspirin"),
    ("Fluconazole", "fluconazole"), ("Lisinopril", "lisinopril"),
    ("Valsartan", "valsartan"), ("Telmisartan", "telmisartan"),
    ("Ramipril", "ramipril"), ("Glimepiride", "glimepiride"),
    ("Sitagliptin", "sitagliptin"), ("Empagliflozin", "empagliflozin"),
    ("Quetiapine", "quetiapine"), ("Diazepam", "diazepam"),
    ("Alprazolam", "alprazolam"), ("Carbamazepine", "carbamazepine"),
    ("Lamotrigine", "lamotrigine"), ("Duloxetine", "duloxetine"),
    ("Fluoxetine", "fluoxetine"), ("Amitriptyline", "amitriptyline"),
    ("Risperidone", "risperidone"), ("Olanzapine", "olanzapine"),
    ("Aripiprazole", "aripiprazole"), ("Insulin", "insulin"),
    ("Domperidone", "domperidone"), ("Ranitidine", "ranitidine"),
    ("Prednisone", "prednisone"), ("Erythromycin", "erythromycin"),
    ("Hydrochlorothiazide", "hydrochlorothiazide"),
    ("Valproic Acid", "valproic acid"), ("Phenytoin", "phenytoin"),
    ("Sildenafil", "sildenafil"), ("Tadalafil", "tadalafil"),
    ("Rivaroxaban", "rivaroxaban"), ("Apixaban", "apixaban"),
    ("Clonazepam", "clonazepam"),
]


def fetch_wikipedia_image(drug_name: str) -> list[dict]:
    """Get drug image from Wikipedia REST API (summary endpoint)."""
    images = []
    try:
        # Try exact name first, then capitalized
        for name_variant in [drug_name.title(), drug_name.lower(), drug_name.upper()]:
            url = f"https://en.wikipedia.org/api/rest_v1/page/summary/{urllib.parse.quote(name_variant)}"
            resp = client.get(url)
            if resp.status_code == 200:
                data = resp.json()
                original = data.get("originalimage", {})
                thumb = data.get("thumbnail", {})
                img_url = original.get("source") or thumb.get("source")
                if img_url:
                    images.append({
                        "drug_name": drug_name.title(),
                        "image_url": img_url,
                        "image_type": "molecular",
                        "source": "Wikipedia",
                        "license": "CC BY-SA",
                        "width": original.get("width") or thumb.get("width"),
                        "height": original.get("height") or thumb.get("height"),
                    })
                break
    except Exception:
        logger.debug("Failed to fetch Wikipedia image for %s", drug_name)
    return images


def fetch_wikipedia_all_images(drug_name: str) -> list[dict]:
    """Get ALL images from a drug's Wikipedia article (not just the page image)."""
    images = []
    try:
        # First get the page images list
        params = {
            "action": "query",
            "format": "json",
            "titles": drug_name.title(),
            "prop": "images",
            "imlimit": "30",
        }
        resp = client.get("https://en.wikipedia.org/w/api.php", params=params)
        if resp.status_code != 200:
            return images

        data = resp.json()
        pages = data.get("query", {}).get("pages", {})

        image_titles = []
        for page_id, page in pages.items():
            for img in page.get("images", []):
                title = img.get("title", "")
                lower = title.lower()
                # Only JPG/PNG, skip wiki icons/logos
                if not any(ext in lower for ext in [".jpg", ".jpeg", ".png"]):
                    continue
                if any(skip in lower for skip in [
                    "logo", "icon", "flag", "map", "commons", "wiki",
                    "edit", "ambox", "symbol", "pictogram", "lock",
                    "folder", "question", "information", "crystal",
                    "nuvola", "gnome", "portal", "padlock", "fairuse",
                    "unbalanced", "circle", "red_pencil",
                ]):
                    continue
                image_titles.append(title)

        # Get URLs for the good images
        for title in image_titles[:4]:
            try:
                params = {
                    "action": "query",
                    "format": "json",
                    "titles": title,
                    "prop": "imageinfo",
                    "iiprop": "url|size|mime",
                }
                resp = client.get("https://en.wikipedia.org/w/api.php", params=params)
                if resp.status_code != 200:
                    continue

                data = resp.json()
                for pid, p in data.get("query", {}).get("pages", {}).items():
                    info_list = p.get("imageinfo", [])
                    if info_list:
                        info = info_list[0]
                        mime = info.get("mime", "")
                        url = info.get("url", "")
                        width = info.get("width", 0)

                        if "svg" in mime or width < 100:
                            continue

                        # Determine type from filename
                        lower_url = url.lower()
                        img_type = "molecular"
                        if any(w in lower_url for w in ["pill", "tablet", "capsule", "package", "box", "blister"]):
                            img_type = "pill"
                        elif any(w in lower_url for w in ["bottle", "vial", "injection", "inhaler"]):
                            img_type = "package"

                        images.append({
                            "drug_name": drug_name.title(),
                            "image_url": url,
                            "image_type": img_type,
                            "source": "Wikipedia",
                            "license": "CC BY-SA",
                            "width": info.get("width"),
                            "height": info.get("height"),
                        })
                        if len(images) >= 3:
                            return images
            except Exception:
                continue
            time.sleep(0.1)

    except Exception:
        logger.debug("Failed to fetch Wikipedia all images for %s", drug_name)
    return images


def fetch_dailymed_images(drug_name: str) -> list[dict]:
    """Fetch pill/package photos from DailyMed (NIH). Public domain.
    Uses the correct response structure: data.media[]
    """
    images = []
    try:
        search_url = f"https://dailymed.nlm.nih.gov/dailymed/services/v2/spls.json?drug_name={urllib.parse.quote(drug_name)}&page=1&pagesize=5"
        resp = client.get(search_url)
        if resp.status_code != 200:
            return images

        data = resp.json()
        results = data.get("data", [])
        if not isinstance(results, list):
            return images

        for spl in results[:3]:
            setid = spl.get("setid", "")
            if not setid:
                continue
            try:
                media_url = f"https://dailymed.nlm.nih.gov/dailymed/services/v2/spls/{setid}/media.json"
                media_resp = client.get(media_url)
                if media_resp.status_code != 200:
                    continue
                media_data = media_resp.json()

                # Correct path: data -> media -> []
                inner = media_data.get("data", {})
                if isinstance(inner, dict):
                    media_list = inner.get("media", [])
                else:
                    continue

                if not isinstance(media_list, list):
                    continue

                for media in media_list:
                    if not isinstance(media, dict):
                        continue
                    mime = media.get("mime_type", "")
                    name = media.get("name", "")
                    img_url = media.get("url", "")

                    if "image" not in mime:
                        continue

                    if not img_url:
                        img_url = f"https://dailymed.nlm.nih.gov/dailymed/image.cfm?setid={setid}&name={name}"

                    images.append({
                        "drug_name": drug_name.title(),
                        "image_url": img_url,
                        "image_type": "pill",
                        "source": "DailyMed NIH",
                        "license": "Public Domain (US Government)",
                    })
                    if len(images) >= 3:
                        return images
            except Exception:
                continue
    except Exception:
        logger.debug("Failed to fetch DailyMed images for %s", drug_name)
    return images


def main():
    print("=" * 60)
    print("DawaaCheck — Fetch Medicine Images (Wikipedia + DailyMed)")
    print("=" * 60)

    all_images = []
    seen_generics = set()
    found_count = 0

    for brand_name, generic_name in MEDICINES:
        if generic_name in seen_generics:
            continue
        seen_generics.add(generic_name)

        print(f"\n  [{brand_name}] ({generic_name})...", end=" ", flush=True)
        drug_images = []

        # 1. Wikipedia summary image
        imgs = fetch_wikipedia_image(generic_name)
        if imgs:
            drug_images.extend(imgs)

        # 2. Wikipedia article images (expanded)
        imgs = fetch_wikipedia_all_images(generic_name)
        if imgs:
            # Deduplicate with summary image
            existing_urls = {i["image_url"] for i in drug_images}
            for img in imgs:
                if img["image_url"] not in existing_urls:
                    drug_images.append(img)
                    existing_urls.add(img["image_url"])

        # 3. DailyMed pill photos
        imgs = fetch_dailymed_images(generic_name)
        if imgs:
            drug_images.extend(imgs)

        if drug_images:
            found_count += 1
            sources = set(i["source"] for i in drug_images)
            print(f"{len(drug_images)} images ({', '.join(sources)})")
        else:
            print("none")

        all_images.extend(drug_images)
        time.sleep(0.3)

    print(f"\n{'=' * 60}")
    print(f"Total images: {len(all_images)}")
    print(f"Drugs with images: {found_count}/{len(seen_generics)}")

    # Count by source
    from collections import Counter
    sources = Counter(i["source"] for i in all_images)
    for s, c in sources.most_common():
        print(f"  {s}: {c}")

    # Count by type
    types = Counter(i["image_type"] for i in all_images)
    for t, c in types.most_common():
        print(f"  {t}: {c}")

    # Save to JSON
    output = DATA_DIR / "wikimedia_medicine_images.json"
    with open(output, "w", encoding="utf-8") as f:
        json.dump(all_images, f, indent=2, ensure_ascii=False)
    print(f"\nSaved to {output}")

    # Upload to Supabase
    supabase_url = os.getenv("SUPABASE_URL")
    supabase_key = os.getenv("SUPABASE_KEY")
    if supabase_url and supabase_key:
        print("\nUploading to Supabase...")
        from supabase import create_client
        sb = create_client(supabase_url, supabase_key)

        # Get existing URLs to skip duplicates
        existing = sb.table("medicine_images").select("image_url").execute()
        existing_urls = {r["image_url"] for r in existing.data}

        uploaded = 0
        skipped = 0
        for img in all_images:
            url = img["image_url"]
            if url in existing_urls:
                skipped += 1
                continue
            existing_urls.add(url)
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

        count = sb.table("medicine_images").select("id", count="exact").limit(0).execute()
        print(f"Uploaded {uploaded} new, skipped {skipped} existing. Total: {count.count}")
    else:
        print("\nNo Supabase credentials — saved JSON only")


if __name__ == "__main__":
    main()
