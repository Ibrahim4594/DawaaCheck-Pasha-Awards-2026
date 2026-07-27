"""Generate DawaaCheck app icons and splash logo using Pillow.

Run: python generate_icons.py
Requires: pip install Pillow

Generates:
  - assets/icons/app_icon.png (1024x1024 — launcher icon)
  - assets/icons/app_icon_foreground.png (1024x1024 — adaptive icon foreground)
  - assets/icons/splash_logo.png (384x384 — native splash branding)
"""

from PIL import Image, ImageDraw, ImageFont
import os

# Brand colors
PRIMARY = (26, 111, 232)       # #1A6FE8
PRIMARY_DARK = (11, 61, 145)   # #0B3D91
WHITE = (255, 255, 255)
BG_LIGHT = (244, 248, 255)     # #F4F8FF
VERIFIED = (18, 160, 92)       # #12A05C

ICONS_DIR = os.path.join(os.path.dirname(__file__), "assets", "icons")
os.makedirs(ICONS_DIR, exist_ok=True)


def draw_shield(draw, cx, cy, size, fill_color, outline_color=None):
    """Draw a shield shape centered at (cx, cy)."""
    w = size * 0.45
    h = size * 0.52
    top = cy - h
    bot = cy + h * 0.6

    # Shield path points
    points = [
        (cx, top),                          # top center
        (cx + w, top + h * 0.15),           # top right
        (cx + w, cy),                       # mid right
        (cx + w * 0.7, cy + h * 0.55),     # lower right
        (cx, bot),                          # bottom center (point)
        (cx - w * 0.7, cy + h * 0.55),     # lower left
        (cx - w, cy),                       # mid left
        (cx - w, top + h * 0.15),           # top left
    ]

    draw.polygon(points, fill=fill_color, outline=outline_color, width=3)


def draw_checkmark(draw, cx, cy, size, color, width=None):
    """Draw a checkmark centered at (cx, cy)."""
    if width is None:
        width = max(int(size * 0.06), 4)
    s = size * 0.15

    # Checkmark: short left stroke + long right stroke
    points = [
        (cx - s * 1.0, cy - s * 0.1),   # start (left)
        (cx - s * 0.2, cy + s * 0.7),   # bottom of check
        (cx + s * 1.2, cy - s * 0.8),   # end (top right)
    ]

    draw.line([points[0], points[1]], fill=color, width=width, joint="curve")
    draw.line([points[1], points[2]], fill=color, width=width, joint="curve")


def draw_plus_cross(draw, cx, cy, size, color):
    """Draw a small medical cross/plus."""
    s = size * 0.05
    w = max(int(size * 0.02), 2)
    draw.line([(cx - s, cy), (cx + s, cy)], fill=color, width=w)
    draw.line([(cx, cy - s), (cx, cy + s)], fill=color, width=w)


def generate_app_icon(filepath, size=1024):
    """Full app icon: blue shield + white checkmark on gradient-like background."""
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Rounded rectangle background
    margin = int(size * 0.05)
    radius = int(size * 0.18)
    draw.rounded_rectangle(
        [margin, margin, size - margin, size - margin],
        radius=radius,
        fill=PRIMARY,
    )

    # Subtle inner glow (lighter rectangle)
    inner_margin = int(size * 0.08)
    draw.rounded_rectangle(
        [inner_margin, inner_margin, size - inner_margin, int(size * 0.55)],
        radius=int(radius * 0.8),
        fill=(35, 125, 240, 40),
    )

    cx, cy = size // 2, int(size * 0.48)
    # White shield
    draw_shield(draw, cx, cy, size * 0.85, WHITE)
    # Blue checkmark inside shield
    draw_checkmark(draw, cx, int(cy + size * 0.02), size * 0.85, PRIMARY, width=max(int(size * 0.055), 6))

    # Small decorative crosses
    draw_plus_cross(draw, int(size * 0.2), int(size * 0.2), size, (255, 255, 255, 80))
    draw_plus_cross(draw, int(size * 0.82), int(size * 0.25), size, (255, 255, 255, 60))

    img.save(filepath, "PNG")
    print(f"  Created: {filepath}")


def generate_adaptive_foreground(filepath, size=1024):
    """Adaptive icon foreground: shield + checkmark with transparent background + safe zone padding."""
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Adaptive icons need content within 66% safe zone (center 66%)
    cx, cy = size // 2, int(size * 0.48)
    scale = 0.65  # Keep within safe zone

    draw_shield(draw, cx, cy, size * scale, PRIMARY)
    draw_checkmark(draw, cx, int(cy + size * 0.015), size * scale, WHITE, width=max(int(size * 0.045), 5))

    img.save(filepath, "PNG")
    print(f"  Created: {filepath}")


def generate_splash_logo(filepath, size=384):
    """Splash screen logo: shield + checkmark, clean and centered."""
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    cx, cy = size // 2, int(size * 0.46)

    # Shield with slight shadow effect
    draw_shield(draw, cx + 2, cy + 3, size * 0.8, (0, 0, 0, 20))  # shadow
    draw_shield(draw, cx, cy, size * 0.8, PRIMARY)
    draw_checkmark(draw, cx, int(cy + size * 0.015), size * 0.8, WHITE, width=max(int(size * 0.05), 4))

    img.save(filepath, "PNG")
    print(f"  Created: {filepath}")


if __name__ == "__main__":
    print("Generating DawaaCheck icons...")
    generate_app_icon(os.path.join(ICONS_DIR, "app_icon.png"))
    generate_adaptive_foreground(os.path.join(ICONS_DIR, "app_icon_foreground.png"))
    generate_splash_logo(os.path.join(ICONS_DIR, "splash_logo.png"))
    print("\nDone! Now run:")
    print("  cd dawaacheck")
    print("  dart run flutter_launcher_icons")
    print("  dart run flutter_native_splash:create")
