"""Draws the game cursor (ui/cursor/cursor.png, cursor_pressed.png): a
128 x 128 pointer head without the tail, white with a cool shade, a dark
outline and a soft shadow. The pressed one sits "into" the screen: smaller,
a little darker, its shadow tucked in. Hotspot: the tip, at HOTSPOT.
    python3 tools/make_cursor.py
"""
import os
from PIL import Image, ImageDraw, ImageFilter

SIZE = 128
SS = 4  # supersampling
HOTSPOT = (16, 14)
OUT = os.path.join(os.path.dirname(__file__), "..", "ui", "cursor")
# The head of a classic pointer: tip, down the left edge, the notch where the
# tail would start, out to the right corner.
SHAPE = [(16, 14), (16, 108), (42, 86), (84, 82)]


def scaled(points, k):
    tx, ty = HOTSPOT
    return [((tx + (x - tx) * k) * SS, (ty + (y - ty) * k) * SS) for x, y in points]


def draw(pressed):
    k = 0.88 if pressed else 1.0
    big = SIZE * SS
    img = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    pts = scaled(SHAPE, k)
    # Soft shadow under it (closer when pressed into the screen).
    off = (2 if pressed else 6) * SS
    shadow = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).polygon([(x + off, y + off * 1.2) for x, y in pts], fill=(0, 0, 0, 120 if pressed else 105))
    shadow = shadow.filter(ImageFilter.GaussianBlur((3 if pressed else 6) * SS))
    img.alpha_composite(shadow)
    # Dark outline: the shape grown by drawing it with a thick line.
    d = ImageDraw.Draw(img)
    d.polygon(pts, fill=(20, 18, 30, 255))
    d.line(pts + [pts[0]], fill=(20, 18, 30, 255), width=6 * SS, joint="curve")
    # Fill: shrink toward the centroid and paint a top-left to bottom-right shade.
    cx = sum(p[0] for p in pts) / len(pts)
    cy = sum(p[1] for p in pts) / len(pts)
    inner = [(cx + (x - cx) * 0.9, cy + (y - cy) * 0.9) for x, y in pts]
    mask = Image.new("L", (big, big), 0)
    ImageDraw.Draw(mask).polygon(inner, fill=255)
    shade = Image.new("RGBA", (big, big))
    top = (255, 255, 255) if not pressed else (226, 228, 238)
    bottom = (196, 204, 226) if not pressed else (168, 176, 200)
    sd = ImageDraw.Draw(shade)
    for i in range(big * 2):
        t = min(1.0, i / (big * 1.1))
        c = tuple(int(a + (b - a) * t) for a, b in zip(top, bottom))
        sd.line([(i, 0), (0, i)], fill=c + (255,))
    img.paste(shade, (0, 0), mask)
    # A thin highlight along the left edge, and a deeper line inside the notch.
    d.line([inner[0], inner[1]], fill=(255, 255, 255, 230 if not pressed else 150), width=3 * SS)
    d.line([inner[1], inner[2]], fill=(120, 128, 160, 200), width=2 * SS)
    d.line([inner[2], inner[3]], fill=(120, 128, 160, 200), width=2 * SS)
    return img.resize((SIZE, SIZE), Image.LANCZOS)


os.makedirs(OUT, exist_ok=True)
draw(False).save(os.path.join(OUT, "cursor.png"))
draw(True).save(os.path.join(OUT, "cursor_pressed.png"))
print("wrote", OUT)
