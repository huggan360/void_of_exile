#!/usr/bin/env python3
"""Generates the Archer as MagicaVoxel .vox parts (body, arm, leg, bow).

Run:  python3 tools/make_hero.py
Then open characters/archer/*.vox in Goxel to tweak by hand.

The whole character fits a 16x16x16 grid. Coordinates here are y-up,
1 unit = 1 voxel, feet at y=0, centered on x=0, facing -z (Godot's forward).
Each limb part has its pivot (shoulder/hip/grip) at its local origin.
"""
import os
import struct

PALETTE = {
    "skin": (232, 182, 140),
    "eye": (24, 20, 28),
    "hood": (62, 118, 56),
    "hood_dark": (40, 82, 40),
    "tunic": (122, 86, 52),
    "tunic_dark": (94, 64, 38),
    "belt": (64, 42, 28),
    "gold": (232, 186, 66),
    "pants": (76, 66, 52),
    "boot": (52, 36, 28),
    "quiver": (112, 68, 36),
    "fletch": (236, 232, 220),
    "fletch_red": (190, 52, 42),
    "bow": (150, 102, 56),
    "grip": (70, 44, 30),
    "string": (224, 222, 210),
    # Extra shades: each voxel of a base color picks one of its variants, so
    # the cloth and leather look varied and alive instead of flat.
    "hood_b": (54, 108, 50),
    "hood_c": (72, 130, 62),
    "hood_dark_b": (34, 74, 36),
    "tunic_b": (132, 94, 58),
    "tunic_c": (112, 78, 46),
    "pants_b": (68, 60, 48),
    "quiver_b": (100, 60, 32),
}
VARIANTS = {
    "hood": ["hood", "hood", "hood_b", "hood_c"],
    "hood_dark": ["hood_dark", "hood_dark", "hood_dark_b"],
    "tunic": ["tunic", "tunic", "tunic_b", "tunic_c"],
    "pants": ["pants", "pants_b"],
    "quiver": ["quiver", "quiver_b"],
}
NAMES = list(PALETTE)
INDEX = {name: i + 1 for i, name in enumerate(NAMES)}  # .vox indices start at 1


def box(vox, x0, x1, y0, y1, z0, z1, color):
    """Fills the half-open box [x0,x1) x [y0,y1) x [z0,z1)."""
    for x in range(x0, x1):
        for y in range(y0, y1):
            for z in range(z0, z1):
                vox[(x, y, z)] = color


def body():
    v = {}
    # Torso y 4..9: leather tunic, darker sides, belt with buckle.
    box(v, -3, 3, 4, 9, -2, 2, "tunic")
    box(v, -3, -2, 5, 9, -2, 2, "tunic_dark")
    box(v, 2, 3, 5, 9, -2, 2, "tunic_dark")
    box(v, -3, 3, 4, 5, -2, 2, "belt")
    box(v, -1, 1, 4, 5, -3, -2, "gold")
    # Cloak down the back.
    box(v, -3, 3, 2, 9, 2, 3, "hood_dark")
    # Hood y 9..16 wraps the head; the face shows through the front.
    box(v, -4, 4, 9, 16, -3, 3, "hood")
    box(v, -4, 4, 9, 10, -3, 3, "hood_dark")  # rim where it meets the cloak
    box(v, -1, 1, 13, 15, 3, 4, "hood")  # pointed tip at the back
    box(v, -2, 2, 10, 14, -3, -2, "skin")
    box(v, -2, -1, 12, 13, -3, -2, "eye")
    box(v, 1, 2, 12, 13, -3, -2, "eye")
    # Bevel the hood's top edges so it reads as a hood, not a box.
    for x in range(-4, 4):
        for z in range(-3, 3):
            if x in (-4, 3) or z in (-3, 2):
                v.pop((x, 15, z), None)
    box(v, -1, 1, 15, 16, -2, 2, "hood_dark")  # seam along the top
    # Quiver on the back, arrows poking over the right shoulder.
    box(v, 1, 3, 4, 10, 3, 5, "quiver")
    box(v, 1, 3, 10, 12, 3, 5, "fletch")
    box(v, 1, 2, 11, 12, 3, 4, "fletch_red")
    box(v, 2, 3, 11, 12, 4, 5, "fletch_red")
    return v


def arm():
    """Shared by both arms. Pivot = shoulder (top center)."""
    v = {}
    box(v, -1, 1, -2, 0, -1, 1, "hood")  # sleeve
    box(v, -1, 1, -4, -2, -1, 1, "tunic_dark")  # bracer
    box(v, -1, 1, -5, -4, -1, 1, "skin")  # hand
    return v


def leg():
    """Shared by both legs. Pivot = hip (top center)."""
    v = {}
    box(v, -1, 2, -2, 0, -1, 2, "pants")
    box(v, -1, 2, -4, -2, -1, 2, "boot")
    box(v, -1, 2, -4, -3, -2, -1, "boot")  # toe
    return v


def bow():
    """Vertical longbow. Pivot = grip; limbs curve back toward the string (+z)."""
    v = {}
    for y in range(-6, 7):
        bend = round(2 * (y / 6) ** 2)
        v[(0, y, bend)] = "bow"
    for y in range(-1, 2):
        v[(0, y, 0)] = "grip"
    for y in range(-5, 6):
        v[(0, y, 2)] = "string"
    return v


def arrow():
    """Points along -z. Pivot = middle of the shaft."""
    v = {}
    box(v, 0, 1, 0, 1, -3, 4, "bow")
    v[(0, 0, -4)] = "string"  # tip
    for p in [(-1, 0, 3), (1, 0, 3), (0, 1, 3), (0, -1, 3)]:
        v[p] = "fletch_red"
    return v


def write_vox(path, vox, frame_min, frame_size):
    """Writes vox into a fixed frame, so edits never shift the part in game."""
    minx, miny, minz = frame_min
    sx, sy, sz = frame_size
    for x, y, z in vox:
        assert minx <= x < minx + sx and miny <= y < miny + sy and minz <= z < minz + sz, \
            f"{path}: voxel {(x, y, z)} outside frame"

    def chunk(cid, content, children=b""):
        return cid + struct.pack("<ii", len(content), len(children)) + content + children

    # .vox is z-up. godot_voxel's loader maps file (a, b, c) to Godot (b, c, a),
    # so we write (z, x, y) to land on Godot's (x, y, z) unchanged.
    xyzi = struct.pack("<i", len(vox))
    for (x, y, z), color in vox.items():
        if color in VARIANTS:
            options = VARIANTS[color]
            color = options[((x * 73856093) ^ (y * 19349663) ^ (z * 83492791)) % len(options)]
        xyzi += struct.pack("<BBBB", z - minz, x - minx, y - miny, INDEX[color])
    rgba = b""
    for i in range(256):
        r, g, b = PALETTE[NAMES[i]] if i < len(NAMES) else (0, 0, 0)
        rgba += struct.pack("<BBBB", r, g, b, 255)
    children = (
        chunk(b"SIZE", struct.pack("<iii", sz, sx, sy))
        + chunk(b"XYZI", xyzi)
        + chunk(b"RGBA", rgba)
    )
    with open(path, "wb") as f:
        f.write(b"VOX " + struct.pack("<i", 150) + chunk(b"MAIN", b"", children))
    print(f"{os.path.basename(path)}: {len(vox)} voxels in {sx}x{sy}x{sz} frame at {frame_min}")


if __name__ == "__main__":
    out = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "characters", "archer")
    os.makedirs(out, exist_ok=True)
    # name: (builder, frame min corner, frame size). Must match archer_model.gd.
    parts = {
        "body": (body, (-8, 0, -8), (16, 16, 16)),
        "arm": (arm, (-1, -5, -1), (2, 5, 2)),
        "leg": (leg, (-1, -4, -2), (3, 4, 4)),
        "bow": (bow, (0, -6, 0), (1, 13, 3)),
        "arrow": (arrow, (-1, -1, -4), (3, 3, 8)),
    }
    for name, (fn, frame_min, frame_size) in parts.items():
        write_vox(os.path.join(out, name + ".vox"), fn(), frame_min, frame_size)
