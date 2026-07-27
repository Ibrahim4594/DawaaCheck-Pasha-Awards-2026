"""
Scrape real Pakistani medicine box images from Dawaai.pk using Playwright.
Dawaai.pk is JS-rendered so we need a real browser.

Saves images to:
  1. dawaacheck/assets/images/medicines/ (for Flutter app)
  2. Supabase medicine_images table (URLs for production)
  3. pakistan_scraped_images.json (backup)
"""
import asyncio
import json
import logging
import os
import re
import sys
import time

logger = logging.getLogger(__name__)
from pathlib import Path

try:
    from playwright.async_api import async_playwright
except ImportError:
    print("Install: pip install playwright && python -m playwright install chromium")
    sys.exit(1)

try:
    from dotenv import load_dotenv
    load_dotenv(Path(__file__).parent.parent / ".env")
except ImportError:
    pass

DATA_DIR = Path(__file__).parent
PROJECT_DIR = DATA_DIR.parent.parent
ASSETS_DIR = PROJECT_DIR / "dawaacheck" / "assets" / "images" / "medicines"
ASSETS_DIR.mkdir(parents=True, exist_ok=True)

# Top Pakistani medicines to scrape
MEDICINES = [
    "panadol extra",
    "augmentin 625mg",
    "brufen 400mg",
    "flagyl 400mg",
    "amoxil 500mg",
    "calpol",
    "ponstan forte",
    "arinac forte",
    "risek 20mg",
    "novidat 500mg",
    "rigix",
    "septran ds",
    "ventolin inhaler",
    "glucophage 500mg",
    "disprin",
    "zyrtec",
    "velosef 500mg",
    "azomax 500mg",
    "entamizole",
    "sinarest",
    "nexium 40mg",
    "amaryl 2mg",
    "concor 5mg",
    "norvasc 5mg",
    "lipitor 20mg",
    "plavix 75mg",
    "crestor 10mg",
    "lantus",
    "zoloft 50mg",
    "lyrica 75mg",
    "duphalac",
    "motilium",
    "flagyl suspension",
    "amoxil suspension",
    "iberet folic",
    "neurobion",
    "ciproxin 500mg",
    "xarelto 20mg",
    "tegretol 200mg",
    "maxigesic",
]


async def scrape_dawaai():
    """Scrape medicine images from Dawaai.pk using Playwright."""
    results = []

    async with async_playwright() as p:
        browser = await p.chromium.launch(headless=True)
        context = await browser.new_context(
            user_agent="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
            viewport={"width": 1280, "height": 720},
        )
        page = await context.new_page()

        print(f"Scraping {len(MEDICINES)} medicines from Dawaai.pk...\n")

        for med_name in MEDICINES:
            slug = med_name.lower().replace(" ", "+")
            search_url = f"https://dawaai.pk/search?q={slug}"

            try:
                print(f"  [{med_name}]...", end=" ", flush=True)

                await page.goto(search_url, wait_until="networkidle", timeout=20000)
                await page.wait_for_timeout(2000)  # Extra wait for JS

                # Look for product cards with images
                img_elements = await page.query_selector_all("img")

                product_img = None
                for img in img_elements:
                    src = await img.get_attribute("src") or ""
                    alt = (await img.get_attribute("alt") or "").lower()
                    data_src = await img.get_attribute("data-src") or ""

                    actual_src = data_src or src

                    # Filter: must be a product image, not site chrome
                    if not actual_src:
                        continue
                    if any(skip in actual_src.lower() for skip in [
                        "logo", "icon", "banner", "placeholder", "avatar",
                        "googleplay", "appstore", "map-pin", "shopping-bag",
                        "rx_new", "fast-logo", "offers-icon", "file-prescription",
                        "dawaaiog", "footer", "header", "sprite", "social",
                    ]):
                        continue
                    if actual_src.endswith((".svg", ".gif")):
                        continue

                    # Product images are typically on CDN or have 'product'/'medicine' in path
                    is_product = (
                        "static-media.dawaai.pk" in actual_src
                        or "product" in actual_src.lower()
                        or "medicine" in actual_src.lower()
                        or "catalog" in actual_src.lower()
                        or "upload" in actual_src.lower()
                        # Or if alt text matches medicine name
                        or any(word in alt for word in med_name.lower().split() if len(word) > 3)
                    )

                    if is_product and (actual_src.startswith("http") or actual_src.startswith("//")):
                        if actual_src.startswith("//"):
                            actual_src = "https:" + actual_src
                        product_img = actual_src
                        break

                if not product_img:
                    # Try clicking first product result
                    product_links = await page.query_selector_all("a[href*='/medicine/']")
                    if product_links:
                        href = await product_links[0].get_attribute("href")
                        if href:
                            if not href.startswith("http"):
                                href = "https://dawaai.pk" + href

                            await page.goto(href, wait_until="networkidle", timeout=20000)
                            await page.wait_for_timeout(2000)

                            # Now look for product image on detail page
                            img_elements = await page.query_selector_all("img")
                            for img in img_elements:
                                src = await img.get_attribute("src") or ""
                                data_src = await img.get_attribute("data-src") or ""
                                actual_src = data_src or src

                                if not actual_src or actual_src.endswith((".svg", ".gif")):
                                    continue
                                if any(skip in actual_src.lower() for skip in [
                                    "logo", "icon", "banner", "placeholder",
                                    "googleplay", "appstore", "dawaaiog",
                                ]):
                                    continue

                                # On product page, the main product image is usually large
                                width = await img.get_attribute("width")
                                natural_width = await img.evaluate("el => el.naturalWidth")

                                if natural_width and natural_width > 100:
                                    if actual_src.startswith("//"):
                                        actual_src = "https:" + actual_src
                                    if actual_src.startswith("http"):
                                        product_img = actual_src
                                        break

                if product_img:
                    safe_name = re.sub(r'[^a-z0-9]+', '_', med_name.lower()).strip('_')
                    results.append({
                        "medicine_name": med_name,
                        "image_url": product_img,
                        "source": "Dawaai.pk",
                        "asset_name": f"{safe_name}.png",
                    })
                    print(f"FOUND: {product_img[:80]}")
                else:
                    print("NO IMAGE")

            except Exception as e:
                print(f"ERROR: {str(e)[:60]}")

            await page.wait_for_timeout(500)  # Be respectful

        await browser.close()

    return results


async def scrape_dvago(results_so_far: list):
    """Try DVAGO.pk for medicines not found on Dawaai."""
    found_names = {r["medicine_name"] for r in results_so_far}
    missing = [m for m in MEDICINES if m not in found_names]

    if not missing:
        print("\nAll medicines found on Dawaai! Skipping DVAGO.")
        return []

    print(f"\nTrying DVAGO.pk for {len(missing)} missing medicines...")
    results = []

    async with async_playwright() as p:
        browser = await p.chromium.launch(headless=True)
        context = await browser.new_context(
            user_agent="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
        )
        page = await context.new_page()

        for med_name in missing:
            slug = med_name.lower().replace(" ", "+")
            try:
                print(f"  [{med_name}]...", end=" ", flush=True)
                await page.goto(f"https://dvago.pk/catalogsearch/result/?q={slug}", wait_until="networkidle", timeout=15000)
                await page.wait_for_timeout(2000)

                img_elements = await page.query_selector_all("img.product-image-photo, img[class*='product']")
                for img in img_elements:
                    src = await img.get_attribute("src") or ""
                    if src and "product" in src.lower() and src.startswith("http"):
                        safe_name = re.sub(r'[^a-z0-9]+', '_', med_name.lower()).strip('_')
                        results.append({
                            "medicine_name": med_name,
                            "image_url": src,
                            "source": "DVAGO.pk",
                            "asset_name": f"{safe_name}.png",
                        })
                        print(f"FOUND: {src[:80]}")
                        break
                else:
                    print("NO IMAGE")
            except Exception as e:
                print(f"ERROR: {str(e)[:60]}")

            await page.wait_for_timeout(500)

        await browser.close()

    return results


async def main():
    print("=" * 60)
    print("DawaaCheck — Scrape Pakistani Medicine Images")
    print("=" * 60)

    # Scrape Dawaai.pk
    dawaai_results = await scrape_dawaai()

    # Try DVAGO for missing ones
    dvago_results = await scrape_dvago(dawaai_results)

    all_results = dawaai_results + dvago_results

    print(f"\n{'=' * 60}")
    print(f"Total images found: {len(all_results)}/{len(MEDICINES)}")

    # Save to JSON
    output = DATA_DIR / "pakistan_scraped_images.json"
    with open(output, "w", encoding="utf-8") as f:
        json.dump(all_results, f, indent=2, ensure_ascii=False)
    print(f"Saved to {output}")

    # Download images to Flutter assets
    if all_results:
        print(f"\nDownloading images to {ASSETS_DIR}...")
        import httpx
        client = httpx.Client(timeout=15, follow_redirects=True, headers={
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"
        })

        downloaded = 0
        for item in all_results:
            try:
                resp = client.get(item["image_url"])
                if resp.status_code == 200 and len(resp.content) > 1000:
                    # Determine extension
                    content_type = resp.headers.get("content-type", "")
                    ext = ".png"
                    if "jpeg" in content_type or "jpg" in content_type:
                        ext = ".jpg"
                    elif "webp" in content_type:
                        ext = ".webp"

                    filename = item["asset_name"].rsplit(".", 1)[0] + ext
                    filepath = ASSETS_DIR / filename
                    filepath.write_bytes(resp.content)
                    item["local_path"] = f"assets/images/medicines/{filename}"
                    downloaded += 1
                    print(f"  Downloaded: {filename} ({len(resp.content)} bytes)")
                else:
                    print(f"  Skip {item['medicine_name']}: status={resp.status_code} size={len(resp.content)}")
            except Exception as e:
                print(f"  Failed {item['medicine_name']}: {str(e)[:60]}")
            time.sleep(0.2)

        print(f"\nDownloaded {downloaded} images to Flutter assets")
        client.close()

    # Upload to Supabase
    supabase_url = os.getenv("SUPABASE_URL")
    supabase_key = os.getenv("SUPABASE_KEY")
    if supabase_url and supabase_key and all_results:
        print("\nUploading to Supabase medicine_images...")
        from supabase import create_client
        sb = create_client(supabase_url, supabase_key)

        uploaded = 0
        for item in all_results:
            try:
                sb.table("medicine_images").insert({
                    "drug_name": item["medicine_name"],
                    "image_url": item["image_url"],
                    "image_type": "package",
                    "source": item["source"],
                    "license": "Scraped for educational use",
                }).execute()
                uploaded += 1
            except Exception:
                logger.debug("Skipped duplicate image upload for %s", item["medicine_name"])
            time.sleep(0.05)

        count = sb.table("medicine_images").select("id", count="exact").limit(0).execute()
        print(f"Uploaded {uploaded} new images. Total in Supabase: {count.count}")

    # Save updated JSON with local paths
    with open(output, "w", encoding="utf-8") as f:
        json.dump(all_results, f, indent=2, ensure_ascii=False)

    print(f"\n{'=' * 60}")
    print("Done! Images are in:")
    print(f"  Flutter assets: {ASSETS_DIR}")
    print(f"  JSON backup: {output}")
    print(f"  Supabase: medicine_images table")


if __name__ == "__main__":
    asyncio.run(main())
