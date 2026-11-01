#!/usr/bin/env python3
"""Generates the realm portal: a carved stone arch (frame.vox) plus its
glowing runes (runes.vox, rendered emissive). 0.25 m voxels in game.

Run:  python3 tools/make_portal.py

The arch opening is 3 m wide; its straight sides run from 0.5 m to 4.5 m and
it closes with a 1.5 m radius half-circle (see Portal.gd for the swirl).
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from make_obstacles import write_vox  # noqa: E402

COLORS = {
    1: (150, 144, 136),  # stone light
    2: (124, 118, 112),  # stone mid
    3: (102, 96, 92),  # stone dark
    4: (52, 48, 48),  # mortar
    5: (72, 112, 58),  # moss
    6: (196, 160, 84),  # keystone gold
    7: (84, 78, 76),  # plinth
    8: (160, 120, 255),  # rune glow
}
STONES = (1, 2, 3)

OPEN_HALF = 6  # opening half width, voxels
ARCH_Y = 18  # where the round top starts
OUTER_R = 11


def h(*a):
    """Deterministic hash -> 0..1."""
    n = 0
    for k in a:
        n = (n * 1_000_003 + k * 7919) & 0xFFFFFFFF
    n ^= n >> 13
    n = (n * 1274126177) & 0xFFFFFFFF
    return ((n ^ (n >> 16)) & 0xFFFF) / 0xFFFF


def in_frame(x, y):
    """Is (x, y) part of the arch silhouette (pillars + round top)?"""
    if y < 2:
        return False
    if y < ARCH_Y:
        return OPEN_HALF <= abs(x) + 0.5 <= OUTER_R
    r = math.hypot(x + 0.5, y - ARCH_Y + 0.5)
    return OPEN_HALF <= r <= OUTER_R


def frame():
    v = {}
    # Plinth with a lighter top edge.
    for x in range(-13, 13):
        for z in range(-3, 3):
            for y in range(2):
                v[(x, y, z)] = 7 if y == 0 or abs(x + 0.5) > 12 or abs(z + 0.5) > 2 else 3
    for x in range(-OUTER_R - 1, OUTER_R + 1):
        for y in range(2, ARCH_Y + OUTER_R + 1):
            if not in_frame(x, y):
                continue
            for z in range(-2, 2):
                if y < ARCH_Y:
                    # Pillar bricks: 3 tall, 5 long, staggered rows, 1-voxel mortar.
                    row = (y - 2) // 3
                    u = x + z + (row % 2) * 2
                    mortar = (y - 2) % 3 == 2 or u % 5 == 4
                    brick = (row, u // 5)
                else:
                    # Arch stones (voussoirs): radial joints every 15 degrees.
                    a = math.degrees(math.atan2(y - ARCH_Y + 0.5, x + 0.5))
                    r = math.hypot(x + 0.5, y - ARCH_Y + 0.5)
                    mortar = a % 15 < 2.2 or abs(r - 8.5) < 0.5
                    brick = (int(a // 15), int(r > 8.5))
                    if 84 < a < 96:
                        v[(x, y, z)] = 6  # keystone
                        continue
                c = 4 if mortar else STONES[int(h(*brick) * 3)]
                v[(x, y, z)] = c
    # Moss creeping up the lower pillars.
    for (x, y, z), c in list(v.items()):
        if y < 7 and c != 4 and h(x, y, z, 5) < 0.35 - y * 0.04:
            v[(x, y, z)] = 5
    return v


GLYPHS = [
    ["x.x", ".x.", "x.x"],
    ["xxx", "x..", "xxx"],
    [".x.", "xxx", ".x."],
    ["x..", "xxx", "..x"],
    ["xxx", ".x.", ".x."],
]


def runes():
    v = {}
    for side in (-1, 1):
        cx = side * 8 - (1 if side < 0 else 0)  # pillar center column
        for i, y0 in enumerate(range(4, ARCH_Y - 2, 4)):
            glyph = GLYPHS[(i + (side > 0) * 2) % len(GLYPHS)]
            for gy, row in enumerate(glyph):
                for gx, ch in enumerate(row):
                    if ch == "x":
                        for z in (-3, 2):  # front and back faces
                            v[(cx + gx - 1, y0 + 2 - gy, z)] = 8
    for k in range(1, 12):  # dots following the arch
        a = math.radians(k * 15)
        x, y = round(math.cos(a) * 8.5 - 0.5), round(math.sin(a) * 8.5 + ARCH_Y - 0.5)
        if k != 6:
            for z in (-3, 2):
                v[(x, y, z)] = 8
    return v


if __name__ == "__main__":
    out = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "props", "portal")
    os.makedirs(out, exist_ok=True)
    # write_vox centers every file on x/z = 0 and keeps y absolute, so the
    # frame and runes line up in game even though their extents differ.
    write_vox(os.path.join(out, "frame.vox"), frame(), COLORS)
    write_vox(os.path.join(out, "runes.vox"), runes(), COLORS)
