"""
Fetch medicine images from free sources:
1. RxImage API (NIH) — pill/tablet photos
2. DailyMed — official package label images
3. Build image URL database for the app
"""
import json
import urllib.request
import urllib.parse
import time
import sys
import os

# Top medicines to fetch images for (demo + common Pakistani brands)
MEDICINES = [
    # Demo medicines (most important)
    "paracetamol", "acetaminophen", "amoxicillin", "azithromycin",
    "ibuprofen", "metronidazole", "ciprofloxacin", "omeprazole",
    "metformin", "amlodipine", "losartan", "atorvastatin",
    "cephalexin", "diclofenac", "prednisolone", "doxycycline",
    "salbutamol", "albuterol", "cetirizine", "montelukast",
    # More common drugs
    "aspirin", "naproxen", "clarithromycin", "levofloxacin",
    "cefuroxime", "cefixime", "pantoprazole", "esomeprazole",
    "metoprolol", "atenolol", "furosemide", "hydrochlorothiazide",
    "warfarin", "clopidogrel", "rosuvastatin", "simvastatin",
    "sertraline", "escitalopram", "fluoxetine", "quetiapine",
    "gabapentin", "pregabalin", "carbamazepine", "lamotrigine",
    "levothyroxine", "glimepiride", "sitagliptin", "insulin",
    "fluconazole", "acyclovir", "albendazole", "loratadine",
    "domperidone", "ondansetron", "ranitidine", "famotidine",
    "tramadol", "codeine", "morphine", "diazepam",
    "clindamycin", "erythromycin", "moxifloxacin", "vancomycin",
    "meropenem", "ceftriaxone", "ampicillin", "gentamicin",
    "spironolactone", "ramipril", "valsartan", "telmisartan",
    "bisoprolol", "propranolol", "digoxin", "amiodarone",
    "dexamethasone", "hydrocortisone", "methylprednisolone",
    "budesonide", "fluticasone", "montelukast", "theophylline",
    "sildenafil", "tadalafil", "tamsulosin", "finasteride",
    "allopurinol", "colchicine", "methotrexate", "hydroxychloroquine",
    "fexofenadine", "diphenhydramine", "promethazine",
    "loperamide", "lactulose", "bisacodyl",
    "calcium", "iron", "folic acid", "vitamin d", "zinc",
]

# Remove duplicates
MEDICINES = list(dict.fromkeys(MEDICINES))


def fetch_url(url, timeout=15):
    try:
        req = urllib.request.Request(url, headers={'User-Agent': 'DawaaCheck/1.0'})
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            return json.loads(resp.read().decode('utf-8'))
    except Exception as e:
        return None


def fetch_rximage(drug_name):
    """Fetch pill/tablet images from RxImage API (NIH)"""
    encoded = urllib.parse.quote(drug_name)
    url = f"https://rximage.nlm.nih.gov/api/rximage/1/rxnav?name={encoded}&resolution=600"
    data = fetch_url(url)
    if data and 'nlmRxImages' in data:
        images = []
        for img in data['nlmRxImages'][:3]:  # Top 3 images
            images.append({
                'url': img.get('imageUrl', ''),
                'name': img.get('name', ''),
                'ndc': img.get('ndc11', ''),
                'shape': img.get('shape', ''),
                'color': img.get('color', ''),
                'imprint': img.get('imprint', ''),
                'size': img.get('imageSize', 0),
                'source': 'RxImage (NIH)',
            })
        return images
    return []


def fetch_dailymed_images(drug_name):
    """Search DailyMed for package label images"""
    encoded = urllib.parse.quote(drug_name)
    # DailyMed SPL search API
    url = f"https://dailymed.nlm.nih.gov/dailymed/services/v2/spls.json?drug_name={encoded}&pagesize=3"
    data = fetch_url(url)
    images = []
    if data and 'data' in data:
        for spl in data['data'][:3]:
            set_id = spl.get('setid', '')
            title = spl.get('title', '')
            if set_id:
                # Get media for this SPL
                media_url = f"https://dailymed.nlm.nih.gov/dailymed/services/v2/spls/{set_id}/media.json"
                media_data = fetch_url(media_url)
                if media_data and 'data' in media_data:
                    media_list = media_data['data']
                    if isinstance(media_list, list):
                        for media in media_list[:2]:
                            media_name = media.get('name', '') if isinstance(media, dict) else ''
                            mime = media.get('mime', '') if isinstance(media, dict) else ''
                            if media_name and ('image' in mime.lower() or media_name.lower().endswith(('.jpg', '.png', '.gif'))):
                                img_url = f"https://dailymed.nlm.nih.gov/dailymed/image.cfm?setid={set_id}&name={media_name}"
                                images.append({
                                    'url': img_url,
                                    'name': title,
                                    'set_id': set_id,
                                    'source': 'DailyMed (NIH)',
                                })
    return images


def main():
    all_images = {}
    total = len(MEDICINES)

    print(f"Fetching medicine images for {total} drugs...")
    print("Sources: RxImage (NIH) + DailyMed (NIH)")
    print()

    rximage_count = 0
    dailymed_count = 0

    for i, drug in enumerate(MEDICINES):
        sys.stdout.write(f"\r[{i+1}/{total}] {drug}...                         ")
        sys.stdout.flush()

        entry = {
            'drug_name': drug,
            'rximage': [],
            'dailymed': [],
        }

        # Fetch RxImage
        rx_imgs = fetch_rximage(drug)
        if rx_imgs:
            entry['rximage'] = rx_imgs
            rximage_count += len(rx_imgs)

        time.sleep(0.3)

        # Fetch DailyMed (every other drug to save time)
        if i % 2 == 0:
            dm_imgs = fetch_dailymed_images(drug)
            if dm_imgs:
                entry['dailymed'] = dm_imgs
                dailymed_count += len(dm_imgs)
            time.sleep(0.3)

        if entry['rximage'] or entry['dailymed']:
            all_images[drug] = entry

        time.sleep(0.2)

    print(f"\n\nResults:")
    print(f"  Drugs with images: {len(all_images)}/{total}")
    print(f"  RxImage photos: {rximage_count}")
    print(f"  DailyMed labels: {dailymed_count}")
    print(f"  Total image URLs: {rximage_count + dailymed_count}")

    with open('medicine_images.json', 'w', encoding='utf-8') as f:
        json.dump(all_images, f, indent=2, ensure_ascii=False)

    print(f"\nSaved to medicine_images.json")

    # Also create a simple lookup for the Flutter app
    simple_lookup = {}
    for drug, data in all_images.items():
        best_url = ''
        if data['rximage']:
            best_url = data['rximage'][0]['url']
        elif data['dailymed']:
            best_url = data['dailymed'][0]['url']
        if best_url:
            simple_lookup[drug] = best_url

    with open('medicine_image_urls.json', 'w', encoding='utf-8') as f:
        json.dump(simple_lookup, f, indent=2, ensure_ascii=False)

    print(f"Saved simple URL lookup ({len(simple_lookup)} drugs) to medicine_image_urls.json")


if __name__ == '__main__':
    main()
