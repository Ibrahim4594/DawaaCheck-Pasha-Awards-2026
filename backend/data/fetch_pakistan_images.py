"""
Fetch Pakistani medicine product images from Dawaai.pk
These are the actual box images patients will recognize.
"""
import json
import logging
import urllib.request
import urllib.parse
import time
import sys
import re

logger = logging.getLogger(__name__)

# Top Pakistani branded medicines for demo
PAKISTAN_BRANDS = [
    "Panadol", "Panadol Extra", "Panadol CF",
    "Augmentin", "Amoxil", "Brufen",
    "Ponstan", "Flagyl", "Calpol",
    "Azomax", "Novidat", "Risek",
    "Zyrtec", "Disprin", "Ventolin",
    "Septran", "Voltaren", "Motilium",
    "Imodium", "Zentel", "Gaviscon",
    "Neurobion", "Centrum", "Fefol",
    "Nexium", "Glucophage", "Norvasc",
    "Lipitor", "Concor", "Plavix",
    "Amaryl", "Singulair", "Seretide",
    "Arinac", "Sinarest", "Acefyl",
    "Clarityn", "Telfast", "Rigix",
    "Solvin", "Dulcolax", "Buscopan",
    "Dermovate", "Betnovate", "Canesten",
    "Zoloft", "Lexapro", "Lyrica",
]

def fetch_dawaai_image(brand_name):
    """Try to get product image URL from Dawaai.pk search"""
    encoded = urllib.parse.quote(brand_name)
    search_url = f"https://dawaai.pk/search?q={encoded}"

    try:
        req = urllib.request.Request(search_url, headers={
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
            'Accept': 'text/html',
        })
        with urllib.request.urlopen(req, timeout=10) as resp:
            html = resp.read().decode('utf-8', errors='ignore')

        # Look for product image URLs in the HTML
        # Dawaai typically uses CDN images
        img_patterns = [
            r'(https?://[^"\']+dawaai[^"\']*\.(?:jpg|jpeg|png|webp))',
            r'(https?://cdn[^"\']*\.(?:jpg|jpeg|png|webp))',
            r'src="(https?://[^"]+\.(?:jpg|jpeg|png|webp))"',
        ]

        for pattern in img_patterns:
            matches = re.findall(pattern, html, re.IGNORECASE)
            for match in matches:
                # Filter out tiny icons, logos, etc
                if 'logo' in match.lower() or 'icon' in match.lower() or 'banner' in match.lower():
                    continue
                if 'product' in match.lower() or 'medicine' in match.lower() or 'upload' in match.lower():
                    return match
            # Return first non-filtered image
            for match in matches:
                if 'logo' not in match.lower() and 'icon' not in match.lower():
                    return match

        return None
    except Exception as e:
        return None


def fetch_dvago_image(brand_name):
    """Try to get product image URL from DVAGO.pk"""
    encoded = urllib.parse.quote(brand_name)
    search_url = f"https://dvago.pk/catalogsearch/result/?q={encoded}"

    try:
        req = urllib.request.Request(search_url, headers={
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
            'Accept': 'text/html',
        })
        with urllib.request.urlopen(req, timeout=10) as resp:
            html = resp.read().decode('utf-8', errors='ignore')

        # Look for product images
        img_patterns = [
            r'(https?://dvago\.pk/media/catalog/product[^"\']+\.(?:jpg|jpeg|png|webp))',
            r'(https?://[^"\']*dvago[^"\']*product[^"\']*\.(?:jpg|jpeg|png|webp))',
        ]

        for pattern in img_patterns:
            matches = re.findall(pattern, html, re.IGNORECASE)
            if matches:
                return matches[0]

        return None
    except Exception:
        logger.debug("Failed to scrape image for medicine page")
        return None


def main():
    pakistan_images = {}
    total = len(PAKISTAN_BRANDS)

    print(f"Fetching Pakistani medicine images for {total} brands...")
    print("Sources: Dawaai.pk, DVAGO.pk")
    print()

    dawaai_count = 0
    dvago_count = 0

    for i, brand in enumerate(PAKISTAN_BRANDS):
        sys.stdout.write(f"\r[{i+1}/{total}] {brand}...                         ")
        sys.stdout.flush()

        entry = {'brand_name': brand, 'image_url': None, 'source': None}

        # Try Dawaai first
        img = fetch_dawaai_image(brand)
        if img:
            entry['image_url'] = img
            entry['source'] = 'dawaai.pk'
            dawaai_count += 1
        else:
            time.sleep(0.5)
            # Try DVAGO
            img = fetch_dvago_image(brand)
            if img:
                entry['image_url'] = img
                entry['source'] = 'dvago.pk'
                dvago_count += 1

        if entry['image_url']:
            pakistan_images[brand] = entry

        time.sleep(0.5)

    print(f"\n\nResults:")
    print(f"  Brands with images: {len(pakistan_images)}/{total}")
    print(f"  From Dawaai.pk: {dawaai_count}")
    print(f"  From DVAGO.pk: {dvago_count}")

    with open('pakistan_medicine_images.json', 'w', encoding='utf-8') as f:
        json.dump(pakistan_images, f, indent=2, ensure_ascii=False)

    print(f"\nSaved to pakistan_medicine_images.json")

    # Print what we found
    if pakistan_images:
        print("\nFound images for:")
        for brand, data in pakistan_images.items():
            print(f"  {brand}: {data['source']}")


if __name__ == '__main__':
    main()
