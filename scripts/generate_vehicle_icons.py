#!/usr/bin/env python3
"""
generate_vehicle_icons.py
Generates vehicle appliance item icons for PIP using OpenAI gpt-image-1.

Usage:
    set OPENAI_API_KEY=sk-...
    py scripts/generate_vehicle_icons.py

    # Generate only missing icons:
    py scripts/generate_vehicle_icons.py --skip-existing

    # Generate a single item:
    py scripts/generate_vehicle_icons.py --items PortableLabFridge

    # Dry run (list items, don't generate):
    py scripts/generate_vehicle_icons.py --dry-run

Icons are saved to: common/media/textures/Item_PIP_<ItemName>.png
Style: 128x128 RGBA PNG, isometric pixel art, transparent background.
"""

import os
import sys
import argparse
import base64
from pathlib import Path

try:
    from openai import OpenAI
except ImportError:
    print("ERROR: openai package not found. Install with: pip install openai")
    sys.exit(1)

# --- Configuration ---
REPO_ROOT = Path(__file__).resolve().parent.parent
TEXTURE_DIR = REPO_ROOT / "common" / "media" / "textures"
IMAGE_SIZE = "1024x1024"

STYLE_PREFIX = (
    "A single item icon for a 2D top-down survival video game inventory. "
    "Isometric pixel-art style, 128x128 pixels, transparent background. "
    "Clean dark outlines, soft shading, item centered in frame with small padding. "
    "No text, no labels, no UI elements. Consistent with Project Zomboid art style. "
)

# --- Item Definitions ---
ITEMS = [
    ("PortableLabFridge",
     "A compact portable laboratory refrigerator/freezer unit. Small boxy metal "
     "appliance with a front-opening door, temperature dial, and a small digital "
     "readout. Industrial grey/white metal casing with a biohazard sticker. "
     "Sturdy carrying handles on top. Science equipment, medical/lab aesthetic."),

    ("PortableLabMicrowave",
     "A compact portable laboratory microwave oven. Small boxy metal appliance "
     "with a front-facing door with a small window, rotary timer knob, and a "
     "power indicator light. Industrial grey/white metal casing. Sturdy, "
     "utilitarian design for field lab use. Science equipment, medical/lab aesthetic."),
]


def resize_to_128(input_path: Path):
    """Resize a generated image down to 128x128 RGBA PNG."""
    try:
        from PIL import Image
        img = Image.open(input_path).convert("RGBA")
        img = img.resize((128, 128), Image.LANCZOS)
        img.save(input_path, "PNG")
        return True
    except ImportError:
        print("  WARNING: Pillow not installed -- image saved at original size. "
              "Install with: pip install Pillow")
        return False


def check_blank(input_path: Path) -> bool:
    """Return True if the image has meaningful (non-transparent) content."""
    try:
        from PIL import Image
        img = Image.open(input_path).convert("RGBA")
        non_transparent = sum(1 for _, _, _, a in img.getdata() if a > 0)
        if non_transparent < 100:
            print(f"  WARNING: Image appears blank ({non_transparent} non-transparent pixels)")
            return False
        return True
    except ImportError:
        return True  # Can't check without Pillow


def generate_icon(client, item_name: str, description: str, output_path: Path) -> bool:
    """Generate a single icon via OpenAI gpt-image-1 and save to output_path."""
    prompt = STYLE_PREFIX + description

    try:
        result = client.images.generate(
            model="gpt-image-1",
            prompt=prompt,
            n=1,
            size=IMAGE_SIZE,
            quality="high",
            background="transparent",
        )

        image_data = base64.b64decode(result.data[0].b64_json)
        output_path.parent.mkdir(parents=True, exist_ok=True)
        output_path.write_bytes(image_data)

        # Resize to 128x128
        resize_to_128(output_path)

        # Verify non-blank
        check_blank(output_path)

        return True

    except Exception as e:
        print(f"  ERROR generating {item_name}: {e}")
        return False


def main():
    parser = argparse.ArgumentParser(
        description="Generate PIP vehicle appliance icons via OpenAI gpt-image-1"
    )
    parser.add_argument("--skip-existing", action="store_true",
                        help="Skip items that already have non-placeholder icons (>1KB)")
    parser.add_argument("--dry-run", action="store_true",
                        help="List items without generating")
    parser.add_argument("--items", nargs="*",
                        help="Generate only these items (by stem name)")
    args = parser.parse_args()

    api_key = os.environ.get("OPENAI_API_KEY")
    if not api_key and not args.dry_run:
        print("ERROR: OPENAI_API_KEY environment variable not set.")
        print("  set OPENAI_API_KEY=sk-...")
        sys.exit(1)

    # Filter items if requested
    items = ITEMS
    if args.items:
        name_set = set(args.items)
        items = [(n, d) for n, d in ITEMS if n in name_set]
        if not items:
            print(f"No matching items found. Available: {[n for n, _ in ITEMS]}")
            sys.exit(1)

    print("PIP Vehicle Appliance Icon Generator")
    print(f"  Output: {TEXTURE_DIR}")
    print(f"  Items:  {len(items)}")
    print()

    if args.dry_run:
        for i, (name, desc) in enumerate(items, 1):
            path = TEXTURE_DIR / f"Item_PIP_{name}.png"
            size = path.stat().st_size if path.exists() else 0
            status = "PLACEHOLDER" if 0 < size < 1024 else ("EXISTS" if size >= 1024 else "MISSING")
            print(f"  {i:2d}. Item_PIP_{name}.png [{status}] ({size} bytes)")
        return

    client = OpenAI(api_key=api_key)
    success = 0
    failed = 0

    for i, (name, desc) in enumerate(items, 1):
        output_path = TEXTURE_DIR / f"Item_PIP_{name}.png"

        if args.skip_existing and output_path.exists() and output_path.stat().st_size >= 1024:
            print(f"  [{i}/{len(items)}] Item_PIP_{name}.png -- SKIPPED (exists, {output_path.stat().st_size} bytes)")
            continue

        print(f"  [{i}/{len(items)}] Generating Item_PIP_{name}.png ...")
        if generate_icon(client, name, desc, output_path):
            size = output_path.stat().st_size
            print(f"           OK ({size} bytes)")
            success += 1
        else:
            failed += 1

    print()
    print(f"Done: {success} generated, {failed} failed")


if __name__ == "__main__":
    main()
