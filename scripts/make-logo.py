#!/usr/bin/env python3
"""Build Space2Moon's logo files from the Muse-painted emblem.

    make-logo.py <emblem.png on black> <output dir>

Writes:
    emblem.png                 the mark alone, black removed, transparent
    logo-horizontal-white.png  mark + wordmark for dark backgrounds
    logo-horizontal-dark.png   mark + wordmark for light backgrounds
    logo-card.png              1600x900 lockup on the night gradient (README, social)
"""
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

CYAN = (94, 235, 212)
VIOLET = (158, 107, 255)
NIGHT = (9, 7, 27)
DUSK = (26, 15, 59)
FONT = "/System/Library/Fonts/SFNSRounded.ttf"


def unblack(img: Image.Image) -> Image.Image:
    """Turn a glowing mark on pure black into the same mark on transparency."""
    rgb = img.convert("RGB")
    pixels = []
    for r, g, b in (rgb.get_flattened_data() if hasattr(rgb, "get_flattened_data") else rgb.getdata()):
        a = max(0, min(255, int((max(r, g, b) - 10) * 1.15)))
        if a == 0:
            pixels.append((0, 0, 0, 0))
        else:
            # Un-premultiply so soft edges keep their colour instead of going grey.
            k = 255 / max(a, 1)
            pixels.append((min(255, int(r * k)), min(255, int(g * k)), min(255, int(b * k)), a))
    out = Image.new("RGBA", rgb.size)
    out.putdata(pixels)
    box = out.getbbox() or (0, 0, *out.size)
    pad = int(max(out.size) * 0.03)
    return out.crop((max(0, box[0] - pad), max(0, box[1] - pad), min(out.width, box[2] + pad), min(out.height, box[3] + pad)))


def font(size: int, weight: int = 800) -> ImageFont.FreeTypeFont:
    f = ImageFont.truetype(FONT, size)
    try:
        f.set_variation_by_axes([weight])
    except Exception:
        try:
            f.set_variation_by_name("Heavy")
        except Exception:
            pass
    return f


def gradient(size, a, b):
    w, h = size
    grad = Image.new("RGB", (w, 1))
    for x in range(w):
        t = x / max(1, w - 1)
        grad.putpixel((x, 0), tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3)))
    return grad.resize((w, h))


def wordmark(height: int, ink) -> Image.Image:
    """'Space2Moon' with the 2 in the cyan-to-violet comet gradient."""
    f = font(height)
    parts = [("Space", ink), ("2", None), ("Moon", ink)]
    widths = [f.getbbox(t)[2] - f.getbbox(t)[0] for t, _ in parts]
    gap = int(height * 0.02)
    top = min(f.getbbox(t)[1] for t, _ in parts)
    bottom = max(f.getbbox(t)[3] for t, _ in parts)
    canvas = Image.new("RGBA", (sum(widths) + gap * 2, bottom - top), (0, 0, 0, 0))
    x = 0
    for (text, colour), w in zip(parts, widths):
        left = f.getbbox(text)[0]
        mask = Image.new("L", canvas.size, 0)
        ImageDraw.Draw(mask).text((x - left, -top), text, font=f, fill=255)
        if colour is None:
            fill = Image.new("RGB", canvas.size, CYAN)
            fill.paste(gradient((w, canvas.height), CYAN, VIOLET), (x, 0))
        else:
            fill = Image.new("RGB", canvas.size, colour)
        canvas.paste(fill, (0, 0), mask)
        x += w + gap
    return canvas


def lockup(mark: Image.Image, ink, height=400) -> Image.Image:
    m = mark.resize((int(mark.width * height / mark.height), height), Image.LANCZOS)
    words = wordmark(int(height * 0.42), ink)
    gap = int(height * 0.12)
    out = Image.new("RGBA", (m.width + gap + words.width, height), (0, 0, 0, 0))
    out.alpha_composite(m, (0, 0))
    out.alpha_composite(words, (m.width + gap, (height - words.height) // 2))
    return out


def card(logo: Image.Image) -> Image.Image:
    w, h = 1600, 900
    bg = gradient((w, h), NIGHT, DUSK).convert("RGBA")
    glow = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    ImageDraw.Draw(glow).ellipse((w * 0.2, h * 0.1, w * 0.8, h * 0.9), fill=(*VIOLET, 60))
    bg.alpha_composite(glow.filter(ImageFilter.GaussianBlur(160)))
    scale = min(1200 / logo.width, 1.0)
    logo = logo.resize((int(logo.width * scale), int(logo.height * scale)), Image.LANCZOS)
    bg.alpha_composite(logo, ((w - logo.width) // 2, (h - logo.height) // 2 - 30))
    tag = font(40, 400)
    d = ImageDraw.Draw(bg)
    text = "Send your junk to the moon"
    tw = d.textlength(text, font=tag)
    d.text(((w - tw) / 2, h / 2 + logo.height / 2 + 10), text, font=tag, fill=(255, 255, 255, 150))
    return bg


def main():
    src, out = Path(sys.argv[1]), Path(sys.argv[2])
    out.mkdir(parents=True, exist_ok=True)
    mark = unblack(Image.open(src))
    mark.save(out / "emblem.png")
    white = lockup(mark, (245, 243, 255))
    white.save(out / "logo-horizontal-white.png")
    lockup(mark, (24, 18, 52)).save(out / "logo-horizontal-dark.png")
    card(white).convert("RGB").save(out / "logo-card.png")
    print(f"✓ logo → {out}")


if __name__ == "__main__":
    main()
