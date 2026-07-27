"""
Fetch real pill/tablet photos from Drugs.com imprints database.
These are actual photos of tablets, capsules, and pills.
Free, server-rendered, no JS needed.

Uploads to Supabase medicine_images table.
"""
import json
import logging
import os
import re
import sys
import time
from pathlib import Path

logger = logging.getLogger(__name__)

import httpx

try:
    from dotenv import load_dotenv
    load_dotenv(Path(__file__).parent.parent / ".env")
except ImportError:
    pass

DATA_DIR = Path(__file__).parent

# All generic drug names to fetch images for
DRUGS = [
    "paracetamol", "acetaminophen", "ibuprofen", "amoxicillin", "azithromycin",
    "metformin", "amlodipine", "omeprazole", "ciprofloxacin", "losartan",
    "atorvastatin", "metronidazole", "cetirizine", "salbutamol", "albuterol",
    "doxycycline", "montelukast", "pregabalin", "gabapentin", "pantoprazole",
    "sertraline", "escitalopram", "diclofenac", "tramadol", "metoprolol",
    "furosemide", "warfarin", "clopidogrel", "levothyroxine", "prednisolone",
    "prednisone", "clarithromycin", "levofloxacin", "ranitidine", "domperidone",
    "loratadine", "bisoprolol", "rosuvastatin", "esomeprazole", "aspirin",
    "mefenamic acid", "sulfamethoxazole", "erythromycin", "fluconazole",
    "hydrochlorothiazide", "lisinopril", "valsartan", "telmisartan",
    "ramipril", "glimepiride", "sitagliptin", "empagliflozin", "rivaroxaban",
    "apixaban", "quetiapine", "diazepam", "clonazepam", "alprazolam",
    "carbamazepine", "phenytoin", "valproic acid", "lamotrigine",
    "duloxetine", "fluoxetine", "amitriptyline", "risperidone",
    "olanzapine", "aripiprazole", "sildenafil", "tadalafil",
]

headers = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
    "Accept": "text/html,application/xhtml+xml",
}
client = httpx.Client(timeout=15, follow_redirects=True, headers=headers)


def clean_url(raw: str) -> str:
    """Clean up scraped URL (remove trailing attributes)."""
    # URLs often have trailing ' data-image-scale etc
    url = raw.split("'")[0].split('"')[0].split(" ")[0]
    return url


def fetch_drugs_com(drug_name: str) -> list[dict]:
    """Fetch pill images from drugs.com imprints page."""
    images = []
    try:
        url = f"https://www.drugs.com/imprints.php?drugname={drug_name}"
        resp = client.get(url)
        if resp.status_code != 200:
            return images

        # Find pill image URLs
        patterns = [
            r'(https://www\.drugs\.com/images/pills/[^\"\'>\s]+\.(?:jpg|JPG|png|webp))',
            r'data-image=\"(https://[^\"]+\.(?:jpg|JPG|png|webp))\"',
            r'src=\"(https://www\.drugs\.com/images/pills/[^\"]+)\"',
        ]

        found_urls = set()
        for pattern in patterns:
            matches = re.findall(pattern, resp.text)
            for m in matches:
                clean = clean_url(m)
                if clean and clean not in found_urls and "pill" in clean.lower():
                    found_urls.add(clean)
                    images.append({
                        "drug_name": drug_name.title(),
                        "image_url": clean,
                        "image_type": "pill",
                        "source": "Drugs.com",
                        "license": "Fair use / educational",
                    })
                    if len(images) >= 2:  # Max 2 per drug
                        return images
    except Exception:
        logger.debug("Failed to fetch pill images from Drugs.com for %s", drug_name)
    return images


def main():
    print("=" * 60)
    print("DawaaCheck — Fetch Real Pill Photos from Drugs.com")
    print("=" * 60)

    all_images = []
    found_count = 0

    for drug in DRUGS:
        print(f"  {drug}...", end=" ", flush=True)
        imgs = fetch_drugs_com(drug)
        if imgs:
            print(f"{len(imgs)} pill photos")
            all_images.extend(imgs)
            found_count += 1
        else:
            print("none")
        time.sleep(0.4)  # Be respectful

    print(f"\n{'=' * 60}")
    print(f"Found pill images for {found_count}/{len(DRUGS)} drugs ({len(all_images)} total images)")

    # Save to JSON
    output = DATA_DIR / "pill_images.json"
    with open(output, "w", encoding="utf-8") as f:
        json.dump(all_images, f, indent=2, ensure_ascii=False)
    print(f"Saved to {output}")

    # Upload to Supabase
    supabase_url = os.getenv("SUPABASE_URL")
    supabase_key = os.getenv("SUPABASE_KEY")
    if supabase_url and supabase_key:
        print("\nUploading to Supabase...")
        from supabase import create_client
        sb = create_client(supabase_url, supabase_key)

        uploaded = 0
        seen = set()
        for img in all_images:
            url = img["image_url"]
            if url in seen:
                continue
            seen.add(url)
            try:
                sb.table("medicine_images").insert({
                    "drug_name": img["drug_name"],
                    "image_url": url,
                    "image_type": "pill",
                    "source": img["source"],
                    "license": img.get("license", ""),
                }).execute()
                uploaded += 1
            except Exception:
                logger.debug("Skipped duplicate image upload for %s", img["drug_name"])
            time.sleep(0.05)

        count = sb.table("medicine_images").select("id", count="exact").limit(0).execute()
        print(f"Uploaded {uploaded} pill photos. Total images in Supabase: {count.count}")


if __name__ == "__main__":
    main()
