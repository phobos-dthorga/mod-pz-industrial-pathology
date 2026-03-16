#!/usr/bin/env python3
"""
generate_poster.py — Generate Steam Workshop poster for PhobosIndustrialPathology
using OpenAI gpt-image-1.

Usage:
    python scripts/generate_poster.py [--dry-run] [--variations N]

Requires:
    pip install openai pillow
    OPENAI_API_KEY environment variable (read from Windows registry if not set)

Output:
    source-images/steam-workshop/poster_N_512.png  (512x512 source)
    poster.png                                      (deployed copy)
"""

import argparse
import base64
import os
import sys
import time
from pathlib import Path

# ---------------------------------------------------------------------------
# Ensure OPENAI_API_KEY is available
# ---------------------------------------------------------------------------

def load_api_key():
    key = os.environ.get("OPENAI_API_KEY")
    if key:
        return key
    # Fallback: read from Windows registry (user env var)
    try:
        import winreg
        reg_key = winreg.OpenKey(winreg.HKEY_CURRENT_USER, r"Environment")
        val, _ = winreg.QueryValueEx(reg_key, "OPENAI_API_KEY")
        winreg.CloseKey(reg_key)
        os.environ["OPENAI_API_KEY"] = val
        return val
    except Exception:
        return None


# ---------------------------------------------------------------------------
# Poster prompt
# ---------------------------------------------------------------------------

POSTER_PROMPT = """\
A moody scene poster for a 2D isometric survival video game mod, 512x512 pixels.
Project Zomboid Build 42 art style: pixel art with clean dark outlines, soft \
interior shading, muted post-apocalyptic colour palette (desaturated greens, \
greys, rusty browns, clinical whites).

The scene depicts a dimly-lit mobile pathology laboratory inside a converted \
recreational vehicle (RV). In the centre, a stainless steel autopsy/morgue \
table with a partially-covered zombie corpse under a sheet, greenish skin \
visible. Beside the table: a tray of surgical instruments (scalpel, bone saw, \
forceps), specimen jars with murky fluid, a clipboard with notes. \
A harsh overhead surgical lamp casts a cone of cold white light onto the \
table, leaving the edges in shadow.

On the wall behind: a pinned biohazard poster, a whiteboard with scrawled \
diagrams of the zombie virus, vials of coloured liquid on a shelf. The RV \
interior walls are visible — cramped, with medical supply crates stacked in \
the corner.

The overall mood is tense, clinical, and slightly eerie — a makeshift field \
lab where someone is desperately researching the zombie plague. \
No text, no labels, no UI elements, no watermarks. Isometric perspective, \
dark background fading to black at the edges.\
"""

POSTER_PROMPT_ALT = """\
A poster illustration for a 2D isometric zombie survival video game mod, \
512x512 pixels. Project Zomboid Build 42 pixel art style: clean dark outlines, \
soft shading, muted desaturated colour palette.

Close-up of a gloved hand holding a glass vial containing a sickly green \
luminescent liquid — a zombie virus sample — against a dark background. \
Behind the vial, out of focus: the silhouette of a zombie corpse on a steel \
autopsy table, draped in a stained sheet. Scattered around: a biohazard \
symbol stencilled on a metal case, surgical tools on a tray, a microscope.

Cold clinical lighting from above, high contrast. The mood is ominous and \
scientific — the intersection of horror and research. \
No text, no labels, no UI elements, no watermarks. Dark atmospheric background.\
"""

POSTER_PROMPT_C = """\
A poster for a 2D isometric zombie survival video game mod about pathology \
research, 512x512 pixels. Project Zomboid Build 42 art style: pixel art, \
clean dark outlines, soft shading, muted post-apocalyptic colours.

Top-down isometric view of a cramped RV interior converted into a field \
pathology lab. A steel morgue table dominates the centre with a zombie \
corpse (grey-green skin, tattered clothing) laid out for examination. \
A survivor in a lab coat, surgical mask, and rubber gloves stands beside \
the table holding a scalpel, leaning over the body.

The RV walls are lined with shelves: specimen jars, chemical bottles, a \
battered first-aid kit, stacked medical crates. A desk lamp and overhead \
fluorescent tube provide harsh white light. On a small side table: a \
microscope, test tubes in a rack, a worn notebook. A biohazard symbol \
is spray-painted on a metal locker.

Mood: tense, clinical, determined. A lone researcher trying to understand \
the zombie plague from inside a mobile lab. Muted greens, greys, sterile \
whites, rust-brown accents. No text, no labels, no UI, no watermarks.\
"""

PROMPTS = [POSTER_PROMPT, POSTER_PROMPT_ALT, POSTER_PROMPT_C]


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(description="Generate PIP poster via gpt-image-1")
    parser.add_argument("--dry-run", action="store_true", help="Print prompts without calling API")
    parser.add_argument("--variations", type=int, default=3, help="Number of variations (1-3)")
    args = parser.parse_args()

    repo_root = Path(__file__).resolve().parent.parent
    out_dir = repo_root / "source-images" / "steam-workshop"
    out_dir.mkdir(parents=True, exist_ok=True)

    n = min(args.variations, len(PROMPTS))

    if args.dry_run:
        for i in range(n):
            print(f"\n{'='*60}")
            print(f"  Variation {i+1}")
            print(f"{'='*60}")
            print(PROMPTS[i])
        print(f"\nOutput directory: {out_dir}")
        print("[DRY RUN] No API calls made.")
        return

    api_key = load_api_key()
    if not api_key:
        print("ERROR: OPENAI_API_KEY not found in environment or Windows registry.")
        sys.exit(1)

    from openai import OpenAI
    from PIL import Image
    import io

    client = OpenAI(api_key=api_key)

    generated = []
    for i in range(n):
        prompt = PROMPTS[i]
        out_path = out_dir / f"poster_{i+1}_512.png"

        print(f"\nGenerating variation {i+1}/{n}...")
        print(f"  Prompt: {prompt[:80]}...")

        result = client.images.generate(
            model="gpt-image-1",
            prompt=prompt,
            size="1024x1024",
            quality="high",
            n=1,
        )

        # Decode base64 image
        img_b64 = result.data[0].b64_json
        img_bytes = base64.b64decode(img_b64)
        img = Image.open(io.BytesIO(img_bytes)).convert("RGBA")

        # Downscale to 512x512
        img_512 = img.resize((512, 512), Image.LANCZOS)
        img_512.save(out_path, "PNG")
        print(f"  Saved: {out_path}")
        print(f"  Size:  {os.path.getsize(out_path):,} bytes")

        generated.append(out_path)

        if i < n - 1:
            print("  (waiting 2s for rate limit...)")
            time.sleep(2)

    print(f"\n{'='*60}")
    print(f"  Generated {len(generated)} variation(s)")
    print(f"  Review in: {out_dir}")
    print(f"{'='*60}")
    print("\nTo deploy the best one as the mod poster:")
    print(f"  copy <chosen>.png  {repo_root / 'poster.png'}")
    print(f"  copy <chosen>.png  {repo_root / '42.14' / 'poster.png'}")
    print(f"  copy <chosen>.png  {repo_root / '42.15' / 'poster.png'}")


if __name__ == "__main__":
    main()
