"""
Fetch medicine images from working sources:
1. DailyMed SPL media images (NIH)
2. Wikipedia/Wikimedia Commons (Creative Commons)
"""
import json
import logging
import urllib.request
import urllib.parse
import time
import sys
import re

logger = logging.getLogger(__name__)

MEDICINES = [
    "acetaminophen", "amoxicillin", "azithromycin", "ibuprofen",
    "metronidazole", "ciprofloxacin", "omeprazole", "metformin",
    "amlodipine", "losartan", "atorvastatin", "diclofenac",
    "prednisolone", "doxycycline", "albuterol", "cetirizine",
    "aspirin", "naproxen", "clarithromycin", "levofloxacin",
    "pantoprazole", "esomeprazole", "metoprolol", "atenolol",
    "furosemide", "warfarin", "clopidogrel", "rosuvastatin",
    "simvastatin", "sertraline", "escitalopram", "fluoxetine",
    "gabapentin", "pregabalin", "carbamazepine", "lamotrigine",
    "levothyroxine", "glimepiride", "sitagliptin", "fluconazole",
    "acyclovir", "loratadine", "ondansetron", "famotidine",
    "tramadol", "morphine", "diazepam", "clindamycin",
    "erythromycin", "vancomycin", "meropenem", "ceftriaxone",
    "spironolactone", "ramipril", "valsartan", "propranolol",
    "digoxin", "dexamethasone", "hydrocortisone", "sildenafil",
    "tamsulosin", "allopurinol", "colchicine", "methotrexate",
    "hydroxychloroquine", "fexofenadine", "loperamide",
    "insulin glargine", "montelukast", "budesonide",
]

MEDICINES = list(dict.fromkeys(MEDICINES))

def fetch_url(url, timeout=15):
    try:
        req = urllib.request.Request(url, headers={'User-Agent': 'DawaaCheck/1.0 (medicine-verification-app)'})
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            return json.loads(resp.read().decode('utf-8'))
    except Exception:
        logger.debug("Failed to fetch URL: %s", url)
        return None


def get_dailymed_images(drug_name):
    """Get label images from DailyMed"""
    encoded = urllib.parse.quote(drug_name)
    url = f"https://dailymed.nlm.nih.gov/dailymed/services/v2/spls.json?drug_name={encoded}&pagesize=3"
    data = fetch_url(url)
    images = []

    if not data or 'data' not in data:
        return images

    for spl in data['data'][:2]:
        set_id = spl.get('setid', '')
        title = spl.get('title', '')
        if not set_id:
            continue

        # Get media list for this SPL
        media_url = f"https://dailymed.nlm.nih.gov/dailymed/services/v2/spls/{set_id}/media.json"
        media_data = fetch_url(media_url)
        if not media_data or 'data' not in media_data:
            continue

        media_list = media_data.get('data', [])
        if not isinstance(media_list, list):
            continue

        for media in media_list[:3]:
            if not isinstance(media, dict):
                continue
            name = media.get('name', '')
            mime = media.get('mime', '')
            if name and ('image' in str(mime).lower() or name.lower().endswith(('.jpg', '.png', '.gif'))):
                img_url = f"https://dailymed.nlm.nih.gov/dailymed/image.cfm?setid={set_id}&name={name}"
                images.append({
                    'url': img_url,
                    'title': title,
                    'source': 'DailyMed (NIH)',
                    'license': 'Public Domain (US Government)',
                })
                break  # One image per SPL

    return images


def get_wikipedia_image(drug_name):
    """Get medicine image from Wikipedia/Wikimedia Commons"""
    encoded = urllib.parse.quote(drug_name.replace(' ', '_'))
    # Use Wikipedia API to get page images
    url = f"https://en.wikipedia.org/api/rest_v1/page/summary/{encoded}"
    data = fetch_url(url)

    if data and 'thumbnail' in data:
        return {
            'url': data['thumbnail']['source'],
            'title': data.get('title', drug_name),
            'source': 'Wikipedia',
            'license': 'Creative Commons',
            'width': data['thumbnail'].get('width', 0),
            'height': data['thumbnail'].get('height', 0),
        }

    # Try with capitalized name
    cap_name = drug_name.capitalize()
    encoded2 = urllib.parse.quote(cap_name)
    url2 = f"https://en.wikipedia.org/api/rest_v1/page/summary/{encoded2}"
    data2 = fetch_url(url2)

    if data2 and 'thumbnail' in data2:
        return {
            'url': data2['thumbnail']['source'],
            'title': data2.get('title', drug_name),
            'source': 'Wikipedia',
            'license': 'Creative Commons',
            'width': data2['thumbnail'].get('width', 0),
            'height': data2['thumbnail'].get('height', 0),
        }

    return None


def main():
    all_images = {}
    total = len(MEDICINES)
    dm_count = 0
    wiki_count = 0

    print(f"Fetching medicine images for {total} drugs...")
    print("Sources: DailyMed (NIH) + Wikipedia")
    print()

    for i, drug in enumerate(MEDICINES):
        sys.stdout.write(f"\r[{i+1}/{total}] {drug}...                         ")
        sys.stdout.flush()

        entry = {'drug_name': drug, 'images': []}

        # DailyMed
        dm_imgs = get_dailymed_images(drug)
        if dm_imgs:
            entry['images'].extend(dm_imgs)
            dm_count += len(dm_imgs)

        time.sleep(0.3)

        # Wikipedia
        wiki_img = get_wikipedia_image(drug)
        if wiki_img:
            entry['images'].append(wiki_img)
            wiki_count += 1

        time.sleep(0.2)

        if entry['images']:
            all_images[drug] = entry

    print(f"\n\nResults:")
    print(f"  Drugs with images: {len(all_images)}/{total}")
    print(f"  DailyMed images: {dm_count}")
    print(f"  Wikipedia images: {wiki_count}")
    print(f"  Total: {dm_count + wiki_count}")

    with open('medicine_images.json', 'w', encoding='utf-8') as f:
        json.dump(all_images, f, indent=2, ensure_ascii=False)

    # Simple URL lookup
    simple = {}
    for drug, data in all_images.items():
        if data['images']:
            simple[drug] = data['images'][0]['url']

    with open('medicine_image_urls.json', 'w', encoding='utf-8') as f:
        json.dump(simple, f, indent=2, ensure_ascii=False)

    print(f"\nSaved {len(simple)} image URLs to medicine_image_urls.json")


if __name__ == '__main__':
    main()
