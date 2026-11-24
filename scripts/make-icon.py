#!/usr/bin/env python3
"""Turn a square painting into a macOS .icns with the standard rounded-square shape.

    make-icon.py <painting.png> <AppIcon.icns> [inset fraction, default 0.055]

Use an inset of 0 for full-bleed art that has no painted tile of its own.
"""
import subprocess
import sys
import tempfile
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

src, dest = Path(sys.argv[1]), Path(sys.argv[2])
size = 1024
art = Image.open(src).convert("RGBA")
side = min(art.size)
art = art.crop(((art.width - side) // 2, (art.height - side) // 2, (art.width + side) // 2, (art.height + side) // 2))
# Muse paints its own rounded tile with a margin around it: cut inside that
# tile so only our own mask decides the shape.
inset = int(side * float(sys.argv[3] if len(sys.argv) > 3 else 0.055))
art = art.crop((inset, inset, side - inset, side - inset))

# Apple's grid: an 824 px body centred on a 1024 canvas, corner radius ~185 px.
body = 824
# Muse returns ~500 px images; upscale and restore some crispness.
art = art.resize((body, body), Image.LANCZOS).filter(ImageFilter.UnsharpMask(radius=2, percent=80, threshold=2))
mask = Image.new("L", (body * 4, body * 4), 0)
ImageDraw.Draw(mask).rounded_rectangle((0, 0, body * 4, body * 4), radius=185 * 4, fill=255)
mask = mask.resize((body, body), Image.LANCZOS)
canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
canvas.paste(art, ((size - body) // 2, (size - body) // 2), mask)

with tempfile.TemporaryDirectory() as tmp:
    iconset = Path(tmp) / "AppIcon.iconset"
    iconset.mkdir()
    for px in (16, 32, 128, 256, 512):
        canvas.resize((px, px), Image.LANCZOS).save(iconset / f"icon_{px}x{px}.png")
        canvas.resize((px * 2, px * 2), Image.LANCZOS).save(iconset / f"icon_{px}x{px}@2x.png")
    dest.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(["iconutil", "-c", "icns", str(iconset), "-o", str(dest)], check=True)
canvas.save(dest.with_suffix(".png"))
print(f"✓ icon → {dest}")
