#!/usr/bin/env python3
"""Voxel models for the Surface: trees, bushes, stones and farm buildings.

Run:  python3 tools/surface/make_surface_models.py

Writes
  obstacles/surface/<name>.vox      flora and stones (ObstacleLibrary prefabs:
                                    0.25 m voxels, names with "fine_" 0.125 m)
  props/surface/<name>/body.vox     buildings (VillageHouse: 0.125 m voxels,
                     body_glow.vox  with rig.json), barns, sheds, tents...
                     rig.json

Colors are real colors (palette indices 9 and up are never recolored by a
biome); index 7 is the glow slot (lanterns, embers, glowing caps), which the
biome tints. Shapes are seeded, so a run always gives the same models.
"""
import json
import math
import os
import random
import struct

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
GLOW = 7


class Palette:
    def __init__(self):
        self.colors = {GLOW: (255, 190, 100)}
        self.index = {}

    def __call__(self, rgb):
        rgb = tuple(int(max(0, min(255, c))) for c in rgb)
        if rgb not in self.index:
            i = 9 + len(self.index)
            assert i < 256, "palette full"
            self.index[rgb] = i
            self.colors[i] = rgb
        return self.index[rgb]


def shade(rgb, k):
    return tuple(c * k for c in rgb)


def mix(a, b, t):
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(3))


# --- Shape helpers (voxels: dict (x, y, z) -> palette index) -------------------------
# Shapes are drawn in design units; G voxels per unit (trees are drawn at 1.75
# so they stand 6 to 10 m tall in 0.25 m voxels, everything else at 1).
G = 1.0

def box(v, x0, x1, y0, y1, z0, z1, c):
    for x in range(x0, x1):
        for y in range(y0, y1):
            for z in range(z0, z1):
                v[(x, y, z)] = c(x, y, z) if callable(c) else c


def blob(v, cx, cy, cz, rx, ry, rz, c, rng, rough=0.25, min_y=0, only_empty=False):
    cx, cy, cz, rx, ry, rz = cx * G, cy * G, cz * G, rx * G, ry * G, rz * G
    for x in range(math.floor(cx - rx), math.ceil(cx + rx) + 1):
        for y in range(max(min_y, math.floor(cy - ry)), math.ceil(cy + ry) + 1):
            for z in range(math.floor(cz - rz), math.ceil(cz + rz) + 1):
                d = ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 + ((z - cz) / rz) ** 2
                if d <= 1.0 - rough * rng.random():
                    if only_empty and (x, y, z) in v:
                        continue
                    v[(x, y, z)] = c(x, y, z, d) if callable(c) else c


def limb(v, p0, p1, r0, r1, c):
    p0, p1, r0, r1 = [k * G for k in p0], [k * G for k in p1], r0 * G, r1 * G
    steps = int(max(abs(p1[i] - p0[i]) for i in range(3)) * 2) + 1
    for i in range(steps + 1):
        t = i / steps
        p = [p0[k] + (p1[k] - p0[k]) * t for k in range(3)]
        r = r0 + (r1 - r0) * t
        ri = math.ceil(r)
        for dx in range(-ri, ri + 1):
            for dz in range(-ri, ri + 1):
                for dy in range(-ri, ri + 1):
                    if dx * dx + dz * dz + dy * dy <= r * r + 0.3:
                        q = (round(p[0] + dx), round(p[1] + dy), round(p[2] + dz))
                        v[q] = c(*q) if callable(c) else c


def trunk(v, h, r_base, r_top, c, rng, lean=(0.0, 0.0), roots=True):
    """A tapered trunk with flared roots; returns the top point (design units)."""
    x, z = 0.0, 0.0
    h0 = h
    h, r_base, r_top = round(h * G), r_base * G, r_top * G
    lean = (lean[0] * G, lean[1] * G)
    for y in range(h):
        t = y / max(h - 1, 1)
        r = r_base + (r_top - r_base) * t
        x += lean[0] / h
        z += lean[1] / h
        ri = math.ceil(r)
        for dx in range(-ri, ri + 1):
            for dz in range(-ri, ri + 1):
                if (dx + 0.5 - (x % 1)) ** 2 + (dz + 0.5 - (z % 1)) ** 2 <= r * r + 0.25:
                    q = (math.floor(x) + dx, y, math.floor(z) + dz)
                    v[q] = c(*q) if callable(c) else c
    if roots:
        for k in range(rng.randint(3, 5)):
            a = k * math.tau / 4 + rng.uniform(-0.5, 0.5)
            ln = rng.uniform(r_base / G + 1.5, r_base / G + 3.0)
            limb(v, (0, 1, 0), (math.cos(a) * ln, 0, math.sin(a) * ln), 1.0, 0.5, c)
    return (x / G, h0, z / G)


def ground_trim(v):
    for p in list(v):
        if p[1] < 0:
            del v[p]


def leaf_color(pal, base, rng, light=(1.18, 1.0, 0.82)):
    """A leaf voxel color: lighter on top, darker deep inside, a little noise."""
    def f(x, y, z, d=0.5):
        k = light[0] if d < 0.35 and rng.random() < 0.3 else light[2] if d > 0.8 or rng.random() < 0.18 else light[1]
        k *= rng.uniform(0.94, 1.06)
        return pal(shade(base, k))
    return f


def top_light(v, pal, factor=1.15, chance=0.6, rng=None):
    tops = {}
    for (x, y, z) in v:
        if (x, z) not in tops or y > tops[(x, z)]:
            tops[(x, z)] = y
    for (x, z), y in tops.items():
        if rng is None or rng.random() < chance:
            c = pal.colors[v[(x, y, z)]]
            if v[(x, y, z)] != GLOW:
                v[(x, y, z)] = pal(shade(c, factor))


def snow_cap(v, pal, rng, chance=0.85):
    tops = {}
    for (x, y, z) in v:
        if (x, z) not in tops or y > tops[(x, z)]:
            tops[(x, z)] = y
    for (x, z), y in tops.items():
        if rng.random() < chance:
            v[(x, y, z)] = pal((236, 242, 248) if rng.random() < 0.7 else (214, 226, 238))


# --- Trees (0.25 m voxels) -----------------------------------------------------------

BARK = (96, 70, 46)
BARK_DARK = (70, 50, 34)


def bark(pal, rng, base=BARK):
    return lambda x, y, z: pal(shade(base, rng.choice((0.85, 1.0, 1.0, 1.1))))


def oak(rng, leaves=(78, 136, 52), tall=False):
    v, pal = {}, Palette()
    h = rng.randint(14, 18) if tall else rng.randint(10, 13)
    top = trunk(v, h, 1.6, 1.0, bark(pal, rng), rng, lean=(rng.uniform(-2, 2), rng.uniform(-2, 2)))
    lc = leaf_color(pal, leaves, rng)
    clusters = []
    for k in range(rng.randint(4, 5)):
        a = k * math.tau / 5 + rng.uniform(-0.4, 0.4)
        r = rng.uniform(3.5, 6.0)
        p = (top[0] + math.cos(a) * r, h + rng.uniform(-2, 3), top[2] + math.sin(a) * r)
        limb(v, (top[0], h - 3, top[2]), p, 1.0, 0.6, bark(pal, rng))
        clusters.append(p)
    clusters.append((top[0], h + 4, top[2]))
    for p in clusters:
        blob(v, p[0], p[1] + 1.5, p[2], rng.uniform(4.2, 5.8), rng.uniform(3.2, 4.2), rng.uniform(4.2, 5.8), lc, rng, rough=0.3)
    top_light(v, pal, 1.12, 0.5, rng)
    ground_trim(v)
    return v, pal


def birch(rng):
    v, pal = {}, Palette()
    h = rng.randint(15, 19)
    white = lambda x, y, z: pal((222, 218, 206) if rng.random() > 0.16 else (40, 38, 36))
    top = trunk(v, h, 1.0, 0.6, white, rng, lean=(rng.uniform(-2.5, 2.5), rng.uniform(-2.5, 2.5)), roots=False)
    lc = leaf_color(pal, (150, 186, 70), rng)
    for k in range(5):
        y = h - 6 + k * 2.2
        a = rng.uniform(0, math.tau)
        blob(v, top[0] + math.cos(a) * 1.5, y, top[2] + math.sin(a) * 1.5, rng.uniform(2.6, 3.6), 2.6, rng.uniform(2.6, 3.6), lc, rng, 0.35)
    top_light(v, pal, 1.12, 0.5, rng)
    ground_trim(v)
    return v, pal


def maple(rng, tone):
    colors = {"orange": (214, 118, 40), "red": (184, 52, 38), "gold": (226, 176, 52)}
    return oak(rng, colors[tone])


def blossom(rng):
    v, pal = {}, Palette()
    h = rng.randint(8, 10)
    top = trunk(v, h, 1.2, 0.8, bark(pal, rng, (88, 60, 52)), rng, lean=(rng.uniform(-1.5, 1.5), rng.uniform(-1.5, 1.5)))
    for k in range(4):
        a = k * math.tau / 4 + rng.uniform(-0.3, 0.3)
        p = (top[0] + math.cos(a) * 4.5, h + rng.uniform(0, 2), top[2] + math.sin(a) * 4.5)
        limb(v, (top[0], h - 2, top[2]), p, 0.8, 0.5, bark(pal, rng, (88, 60, 52)))
        pink = lambda x, y, z, d=0.5: pal(rng.choice([(244, 178, 196), (236, 150, 176), (250, 206, 216), (226, 132, 162)]))
        blob(v, p[0], p[1] + 1.5, p[2], 4.0, 3.0, 4.0, pink, rng, 0.35)
    blob(v, top[0], h + 3, top[2], 4.5, 3.2, 4.5, lambda x, y, z, d: pal((246, 190, 206)), rng, 0.35, only_empty=True)
    ground_trim(v)
    return v, pal


def orchard(rng):
    v, pal = oak(rng, (88, 146, 58))
    for p in list(v):
        if pal.colors[v[p]][1] > 120 and rng.random() < 0.06:
            v[p] = pal((200, 40, 36) if rng.random() < 0.7 else (230, 190, 60))
    return v, pal


def willow(rng):
    v, pal = {}, Palette()
    h = rng.randint(10, 12)
    top = trunk(v, h, 1.8, 1.2, bark(pal, rng, (84, 72, 52)), rng)
    lc = leaf_color(pal, (120, 160, 70), rng)
    blob(v, top[0], h + 2, top[2], 6.5, 3.5, 6.5, lc, rng, 0.3)
    # Hanging curtains.
    for k in range(70):
        a = rng.uniform(0, math.tau)
        r = rng.uniform(3.5, 6.8)
        x, z = round((top[0] + math.cos(a) * r) * G), round((top[2] + math.sin(a) * r) * G)
        for y in range(round((h + 1) * G), round((h + 1 - rng.randint(5, 10)) * G), -1):
            if y > 0:
                v[(x, y, z)] = lc(x, y, z, 0.6)
    ground_trim(v)
    return v, pal


def fir(rng, snow=False, tall=False):
    v, pal = {}, Palette()
    h = rng.randint(22, 28) if tall else rng.randint(16, 20)
    trunk(v, h - 2, 1.0, 0.5, bark(pal, rng, (80, 56, 38)), rng, roots=False)
    dark = (38, 84, 58)
    layers = 6 if not tall else 7
    for k in range(layers):
        y0 = (3 + k * (h - 4) / layers) * G
        r = ((layers - k) * 1.1 + 1.6) * G
        for y in range(int(y0), int(y0 + 4 * G)):
            rr = r * (1.0 - (y - y0) / (4.5 * G))
            for x in range(-math.ceil(rr), math.ceil(rr) + 1):
                for z in range(-math.ceil(rr), math.ceil(rr) + 1):
                    if x * x + z * z <= rr * rr - rng.random() * 2.0:
                        v[(x, y, z)] = pal(shade(dark, rng.choice((0.85, 1.0, 1.0, 1.15))))
    for y in range(round((h - 2) * G), round((h + 1) * G)):
        v[(0, y, 0)] = pal(shade(dark, 1.1))
    if snow:
        snow_cap(v, pal, rng, 0.9)
    ground_trim(v)
    return v, pal


def pine(rng):
    """A tall Scots pine: bare trunk, a high flat crown."""
    v, pal = {}, Palette()
    h = rng.randint(20, 25)
    top = trunk(v, h, 1.0, 0.7, bark(pal, rng, (132, 82, 52)), rng, lean=(rng.uniform(-2, 2), rng.uniform(-2, 2)), roots=False)
    lc = leaf_color(pal, (52, 102, 60), rng)
    for k in range(3):
        a = rng.uniform(0, math.tau)
        blob(v, top[0] + math.cos(a) * 2.5, h - 1 + k * 1.5, top[2] + math.sin(a) * 2.5, 4.0, 1.8, 4.0, lc, rng, 0.3)
    ground_trim(v)
    return v, pal


def palm(rng):
    v, pal = {}, Palette()
    h = round(rng.randint(14, 18) * G)
    lean = rng.uniform(2, 5) * G
    a0 = rng.uniform(0, math.tau)
    x = z = 0.0
    for y in range(h):
        t = y / h
        x = math.cos(a0) * lean * t * t
        z = math.sin(a0) * lean * t * t
        c = pal((140, 104, 70) if y % 3 else (112, 82, 54))
        for dx in (0, 1):
            for dz in (0, 1):
                v[(round(x) + dx, y, round(z) + dz)] = c
    green = (74, 150, 62)
    for k in range(7):
        a = k * math.tau / 7 + rng.uniform(-0.2, 0.2)
        for s in range(round(9 * G)):
            r = s + 1
            y = h + 1.5 - (s * s) * 0.06 / G
            px, pz = x + math.cos(a) * r, z + math.sin(a) * r
            for w in (-1, 0, 1):
                q = (round(px - math.sin(a) * w * 0.8), round(y), round(pz + math.cos(a) * w * 0.8))
                v[q] = pal(shade(green, 1.0 if w == 0 else 0.85))
    for k in range(3):
        v[(round(x) + rng.randint(-1, 1), h - 1, round(z) + rng.randint(-1, 1))] = pal((120, 84, 40))
    ground_trim(v)
    return v, pal


def acacia(rng):
    v, pal = {}, Palette()
    h = rng.randint(9, 11)
    top = trunk(v, h, 1.0, 0.8, bark(pal, rng, (110, 80, 56)), rng, lean=(rng.uniform(-2, 2), rng.uniform(-2, 2)), roots=False)
    lc = leaf_color(pal, (120, 140, 60), rng)
    for k in range(3):
        a = k * math.tau / 3 + rng.uniform(-0.3, 0.3)
        p = (top[0] + math.cos(a) * 4, h + 2, top[2] + math.sin(a) * 4)
        limb(v, top, p, 0.8, 0.5, bark(pal, rng, (110, 80, 56)))
        blob(v, p[0], p[1] + 1, p[2], 4.5, 1.4, 4.5, lc, rng, 0.25)
    ground_trim(v)
    return v, pal


def jungle_giant(rng):
    v, pal = {}, Palette()
    h = rng.randint(24, 30)
    top = trunk(v, h, 2.2, 1.4, bark(pal, rng, (92, 74, 50)), rng)
    for k in range(5):  # buttress roots
        a = k * math.tau / 5 + rng.uniform(-0.3, 0.3)
        limb(v, (0, 6, 0), (math.cos(a) * 5, 0, math.sin(a) * 5), 1.2, 0.6, bark(pal, rng, (92, 74, 50)))
    lc = leaf_color(pal, (44, 120, 50), rng)
    for k in range(6):
        a = k * math.tau / 6 + rng.uniform(-0.3, 0.3)
        p = (top[0] + math.cos(a) * 6, h + rng.uniform(-3, 1), top[2] + math.sin(a) * 6)
        limb(v, (top[0], h - 5, top[2]), p, 1.1, 0.6, bark(pal, rng))
        blob(v, p[0], p[1] + 1, p[2], 5.5, 2.6, 5.5, lc, rng, 0.3)
    blob(v, top[0], h + 2, top[2], 6, 3, 6, lc, rng, 0.3)
    # Hanging vines.
    for k in range(40):
        x, z = round((top[0] + rng.uniform(-8, 8)) * G), round((top[2] + rng.uniform(-8, 8)) * G)
        for y in range(round((h - 1) * G), round((h - rng.randint(4, 12)) * G), -1):
            v.setdefault((x, y, z), pal((60, 130, 50)))
    ground_trim(v)
    return v, pal


def mushroom_giant(rng):
    v, pal = {}, Palette()
    h = rng.randint(10, 15)
    stem = lambda x, y, z: pal((210, 214, 224) if rng.random() > 0.2 else (180, 190, 210))
    top = trunk(v, h, 1.6, 1.1, stem, rng, lean=(rng.uniform(-2, 2), rng.uniform(-2, 2)), roots=False)
    r = rng.uniform(5.5, 7.0) * G
    hv = round(h * G)
    tx, tz = round(top[0] * G), round(top[2] * G)
    for x in range(-math.ceil(r), math.ceil(r) + 1):
        for z in range(-math.ceil(r), math.ceil(r) + 1):
            d = math.hypot(x, z) / r
            if d <= 1.0:
                y0 = hv + int((1 - d * d) * 3.5 * G)
                for y in range(hv - 1 + int(d * 1.5 * G), y0 + 1):
                    q = (tx + x, y, tz + z)
                    v[q] = pal((40, 70, 160)) if y < y0 else (GLOW if rng.random() < 0.18 else pal((60, 110, 210)))
    # Glowing gills underneath.
    for x in range(-math.ceil(r) + 1, math.ceil(r)):
        for z in range(-math.ceil(r) + 1, math.ceil(r)):
            if 0.3 < math.hypot(x, z) / r < 0.9 and rng.random() < 0.35:
                v[(tx + x, hv - 2, tz + z)] = GLOW
    ground_trim(v)
    return v, pal


def dead_tree(rng, burnt=False):
    v, pal = {}, Palette()
    h = rng.randint(9, 13)
    base = (34, 30, 30) if burnt else (110, 96, 82)
    c = lambda x, y, z: (GLOW if burnt and rng.random() < 0.05 else pal(shade(base, rng.choice((0.8, 1.0, 1.15)))))
    top = trunk(v, h, 1.3, 0.6, c, rng, lean=(rng.uniform(-2, 2), rng.uniform(-2, 2)))
    for k in range(rng.randint(3, 5)):
        a = rng.uniform(0, math.tau)
        y = rng.uniform(h * 0.45, h)
        p = (top[0] + math.cos(a) * rng.uniform(3, 5), y + rng.uniform(1, 4), top[2] + math.sin(a) * rng.uniform(3, 5))
        limb(v, (top[0] * y / h, y, top[2] * y / h), p, 0.6, 0.3, c)
        q = (p[0] + math.cos(a + 0.8) * 2, p[1] + 2, p[2] + math.sin(a + 0.8) * 2)
        limb(v, p, q, 0.4, 0.3, c)
    ground_trim(v)
    return v, pal


def saguaro(rng):
    v, pal = {}, Palette()
    green = lambda x, y, z: pal((70, 130, 70) if (x + z) % 2 else (58, 112, 60))
    h = round(rng.randint(10, 14) * G)
    box(v, -1, 2, 0, h, -1, 2, green)
    for side in (-1, 1):
        if rng.random() < 0.85:
            y = round(rng.randint(4, 7) * G)
            box(v, 2 if side > 0 else -4, 4 if side > 0 else -1, y, y + 2, 0, 2, green)
            x = 4 if side > 0 else -5
            box(v, x, x + 2, y, y + round(rng.randint(3, 5) * G), 0, 2, green)
    for k in range(3):
        v[(rng.randint(-1, 1), h, rng.randint(-1, 1))] = pal((236, 120, 150))
    return v, pal


def ash_spire(rng):
    """The Deep Dark's leafless black trees, thin and crooked."""
    v, pal = {}, Palette()
    h = rng.randint(14, 18)
    c = lambda x, y, z: pal(shade((30, 28, 36), rng.choice((0.8, 1.0, 1.2))))
    top = trunk(v, h, 0.9, 0.4, c, rng, lean=(rng.uniform(-3, 3), rng.uniform(-3, 3)))
    for k in range(4):
        a = rng.uniform(0, math.tau)
        y = rng.uniform(h * 0.5, h)
        limb(v, (top[0] * y / h, y, top[2] * y / h), (math.cos(a) * 4, y + 3, math.sin(a) * 4), 0.4, 0.3, c)
    ground_trim(v)
    return v, pal


# --- Bushes, stones, logs ------------------------------------------------------------

def bush(rng, color=(70, 128, 52), berries=None, size=1.0):
    v, pal = {}, Palette()
    lc = leaf_color(pal, color, rng)
    for k in range(rng.randint(2, 4)):
        blob(v, rng.uniform(-2, 2) * size, 2.4 * size, rng.uniform(-2, 2) * size, rng.uniform(2.6, 3.6) * size,
             rng.uniform(2.0, 2.8) * size, rng.uniform(2.6, 3.6) * size, lc, rng, 0.3)
    if berries:
        for p in list(v):
            if rng.random() < 0.07:
                v[p] = pal(berries)
    ground_trim(v)
    return v, pal


def stone(rng, base=(132, 130, 126), size=1.0, moss=0.0, flat=False, cracks=0.0, glow_cracks=False):
    """Faceted stone (0.125 m voxels when fine): a few overlapping chunks
    with lit tops, darker undersides, moss and cracks."""
    v, pal = {}, Palette()
    chunks = rng.randint(2, 4)
    for k in range(chunks):
        rx = rng.uniform(3.0, 5.5) * size
        ry = (rng.uniform(1.6, 2.6) if flat else rng.uniform(2.6, 4.5)) * size
        rz = rng.uniform(3.0, 5.0) * size
        cx, cz = rng.uniform(-2.5, 2.5) * size, rng.uniform(-2.5, 2.5) * size
        cy = ry * 0.55

        def col(x, y, z, d, cy=cy, ry=ry):
            t = (y - (cy - ry)) / (2 * ry)
            k = 0.78 + 0.34 * t + rng.uniform(-0.05, 0.05)
            return pal(shade(base, k))
        # Facets: clip each chunk with a couple of planes.
        planes = [(rng.uniform(-1, 1), rng.uniform(0.2, 1), rng.uniform(-1, 1), rng.uniform(0.5, 0.9)) for _ in range(2)]
        for x in range(math.floor(cx - rx), math.ceil(cx + rx) + 1):
            for y in range(0, math.ceil(cy + ry) + 1):
                for z in range(math.floor(cz - rz), math.ceil(cz + rz) + 1):
                    d = ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 + ((z - cz) / rz) ** 2
                    if d > 1.0 - 0.12 * rng.random():
                        continue
                    cut = False
                    for a, b, c, off in planes:
                        n = math.sqrt(a * a + b * b + c * c)
                        if ((x - cx) / rx * a + (y - cy) / ry * b + (z - cz) / rz * c) / n > off:
                            cut = True
                    if not cut:
                        v[(x, y, z)] = col(x, y, z, d)
    tops = {}
    for (x, y, z) in v:
        if (x, z) not in tops or y > tops[(x, z)]:
            tops[(x, z)] = y
    for (x, z), y in tops.items():
        if moss and rng.random() < moss:
            v[(x, y, z)] = pal(rng.choice([(86, 128, 58), (72, 112, 50), (100, 140, 66)]))
            if rng.random() < 0.4 and (x, y - 1, z) in v:
                v[(x, y - 1, z)] = pal((80, 118, 54))
    if cracks:
        for p in list(v):
            if rng.random() < cracks:
                v[p] = GLOW if glow_cracks else pal(shade(base, 0.55))
    return v, pal


def log_fallen(rng):
    v, pal = {}, Palette()
    ln = rng.randint(14, 22)
    for x in range(-ln // 2, ln // 2):
        for y in range(0, 4):
            for z in range(-2, 2):
                if (y - 1.5) ** 2 + (z + 0.5) ** 2 <= 4.2:
                    end = x in (-ln // 2, ln // 2 - 1)
                    v[(x, y, z)] = pal((168, 134, 92) if end and (y - 1.5) ** 2 + (z + 0.5) ** 2 < 2 else
                                       shade(BARK, rng.choice((0.85, 1.0, 1.1))))
    for p in list(v):
        if p[1] == 3 and rng.random() < 0.35:
            v[p] = pal((88, 128, 58))
    for k in range(rng.randint(1, 3)):  # mushrooms on the side
        x = rng.randint(-ln // 2 + 2, ln // 2 - 2)
        v[(x, 2, 2)] = pal((200, 70, 50))
    return v, pal


def stump(rng):
    v, pal = {}, Palette()
    h = rng.randint(3, 5)
    for x in range(-3, 4):
        for z in range(-3, 4):
            if x * x + z * z <= 9.5:
                for y in range(h + (1 if x * x + z * z > 6 else 0)):
                    v[(x, y, z)] = pal((168, 134, 92) if y == h - 1 and x * x + z * z < 6 else shade(BARK, rng.choice((0.85, 1.0))))
    for k in range(4):
        a = k * math.tau / 4 + rng.uniform(-0.4, 0.4)
        for r in range(3, 6):
            v[(round(math.cos(a) * r), 0, round(math.sin(a) * r))] = pal(BARK_DARK)
    return v, pal


def crystal(rng, color=(110, 200, 240)):
    v, pal = {}, Palette()
    for k in range(rng.randint(3, 6)):
        a = rng.uniform(0, math.tau)
        tilt = rng.uniform(0, 0.5)
        h = rng.randint(6, 14)
        x0, z0 = rng.randint(-2, 2), rng.randint(-2, 2)
        for y in range(h):
            r = 1.6 * (1 - y / h) + 0.4
            cx = x0 + math.cos(a) * tilt * y
            cz = z0 + math.sin(a) * tilt * y
            for dx in range(-2, 3):
                for dz in range(-2, 3):
                    if dx * dx + dz * dz <= r * r:
                        v[(round(cx + dx), y, round(cz + dz))] = GLOW if y > h * 0.6 and rng.random() < 0.5 else pal(shade(color, 0.7 + 0.5 * y / h))
    return v, pal


def reeds(rng):
    v, pal = {}, Palette()
    for k in range(rng.randint(8, 14)):
        x, z = rng.randint(-4, 4), rng.randint(-4, 4)
        h = rng.randint(6, 12)
        for y in range(h):
            v[(x, y, z)] = pal((92, 128, 60) if y < h - 2 else (110, 140, 70))
        if rng.random() < 0.6:
            v[(x, h, z)] = pal((110, 76, 44))
            v[(x, h + 1, z)] = pal((110, 76, 44))
    return v, pal


def lily_pads(rng):
    v, pal = {}, Palette()
    for k in range(rng.randint(3, 5)):
        cx, cz, r = rng.uniform(-6, 6), rng.uniform(-6, 6), rng.uniform(1.6, 2.6)
        for x in range(math.floor(cx - r), math.ceil(cx + r) + 1):
            for z in range(math.floor(cz - r), math.ceil(cz + r) + 1):
                if (x - cx) ** 2 + (z - cz) ** 2 <= r * r and not (abs(z - cz) < 0.6 and x > cx):
                    v[(x, 0, z)] = pal((70, 132, 60) if rng.random() > 0.2 else (90, 150, 70))
        if rng.random() < 0.5:
            v[(round(cx), 1, round(cz))] = pal((240, 210, 230))
    return v, pal


def mushrooms(rng, cap=(200, 60, 50)):
    v, pal = {}, Palette()
    for k in range(rng.randint(3, 6)):
        x, z = rng.randint(-4, 4), rng.randint(-4, 4)
        h = rng.randint(2, 4)
        for y in range(h):
            v[(x, y, z)] = pal((230, 222, 200))
        for dx in (-1, 0, 1):
            for dz in (-1, 0, 1):
                v[(x + dx, h, z + dz)] = pal(cap) if (dx + dz) % 2 or rng.random() < 0.6 else pal((246, 240, 230))
    return v, pal


def campfire_ring(rng):
    v, pal = {}, Palette()
    for k in range(10):
        a = k * math.tau / 10
        x, z = round(math.cos(a) * 5), round(math.sin(a) * 5)
        g = rng.choice([(120, 118, 114), (100, 98, 96), (140, 136, 130)])
        for dx in (0, 1):
            for dz in (0, 1):
                v[(x + dx, 0, z + dz)] = pal(g)
                if rng.random() < 0.5:
                    v[(x + dx, 1, z + dz)] = pal(shade(g, 1.1))
    for k in range(4):
        a = k * math.tau / 4 + 0.4
        limb(v, (math.cos(a) * 3, 0, math.sin(a) * 3), (math.cos(a) * 0.5, 2, math.sin(a) * 0.5), 0.6, 0.5, pal((92, 64, 40)))
    for x in range(-1, 2):
        for z in range(-1, 2):
            v[(x, 0, z)] = GLOW
    return v, pal


TREES = {"oak_round", "oak_tall", "birch", "maple", "maple_red", "maple_gold", "blossom", "orchard_apple", "willow",
         "fir", "fir_tall", "fir_snow", "fir_snow_tall", "pine_tall", "palm", "acacia", "jungle_giant", "mushroom_giant",
         "dead_tree", "burnt_tree", "saguaro", "ash_spire"}
FLORA = {
    "oak_round": lambda r: oak(r), "oak_tall": lambda r: oak(r, (70, 128, 48), True), "birch": birch,
    "maple": lambda r: maple(r, "orange"), "maple_red": lambda r: maple(r, "red"), "maple_gold": lambda r: maple(r, "gold"),
    "blossom": blossom, "orchard_apple": orchard, "willow": willow, "fir": lambda r: fir(r), "fir_tall": lambda r: fir(r, tall=True),
    "fir_snow": lambda r: fir(r, snow=True), "fir_snow_tall": lambda r: fir(r, snow=True, tall=True), "pine_tall": pine,
    "palm": palm, "acacia": acacia, "jungle_giant": jungle_giant, "mushroom_giant": mushroom_giant,
    "dead_tree": lambda r: dead_tree(r), "burnt_tree": lambda r: dead_tree(r, burnt=True), "saguaro": saguaro,
    "ash_spire": ash_spire,
    "bush_green": lambda r: bush(r), "bush_berry": lambda r: bush(r, (60, 112, 52), (176, 40, 70)),
    "bush_flower": lambda r: bush(r, (74, 124, 56), (240, 220, 110)), "bush_jungle": lambda r: bush(r, (40, 112, 48), (230, 90, 120), 1.3),
    "bush_snow": lambda r: snow_bush(r), "bush_dry": lambda r: bush(r, (150, 140, 80), None, 0.8),
    "bush_blue": lambda r: bush(r, (50, 90, 150), (120, 230, 255)),
    "log": log_fallen, "stump": stump,
    "rock_mossy": lambda r: stone(r, (128, 126, 120), 1.6, moss=0.55), "rock_grey": lambda r: stone(r, (136, 134, 130), 1.5, moss=0.12),
    "rock_slab": lambda r: stone(r, (122, 120, 116), 1.9, moss=0.3, flat=True), "rock_snow": lambda r: snowy_rock(r),
    "rock_sand": lambda r: stone(r, (196, 152, 104), 1.6), "rock_lava": lambda r: stone(r, (46, 40, 42), 1.6, cracks=0.05, glow_cracks=True),
    "rock_dark": lambda r: stone(r, (52, 52, 62), 1.6), "rock_blue": lambda r: stone(r, (64, 76, 110), 1.5, moss=0.2),
    "crystal_blue": lambda r: crystal(r), "crystal_violet": lambda r: crystal(r, (170, 110, 230)),
    "fine_stone_a": lambda r: stone(r, (140, 138, 132), 0.55, moss=0.2), "fine_stone_b": lambda r: stone(r, (116, 112, 108), 0.45),
    "fine_stone_c": lambda r: stone(r, (150, 146, 136), 0.5, flat=True), "fine_stone_sand": lambda r: stone(r, (200, 160, 112), 0.5),
    "fine_stone_dark": lambda r: stone(r, (60, 58, 66), 0.5), "fine_reeds": reeds, "fine_lilies": lily_pads,
    "fine_mushrooms": lambda r: mushrooms(r), "fine_mushrooms_blue": lambda r: glow_mushrooms(r),
    "campfire_ring": campfire_ring,
}


def snow_bush(rng):
    v, pal = bush(rng, (50, 92, 70))
    snow_cap(v, pal, rng, 0.8)
    return v, pal


def snowy_rock(rng):
    v, pal = stone(rng, (120, 124, 132), 1.6)
    snow_cap(v, pal, rng, 0.9)
    return v, pal


def glow_mushrooms(rng):
    v, pal = mushrooms(rng, (60, 120, 220))
    for p in list(v):
        if pal.colors.get(v[p], (0, 0, 0)) == (60, 120, 220) and rng.random() < 0.5:
            v[p] = GLOW
    return v, pal


# --- Buildings (0.125 m voxels) ------------------------------------------------------

def barn(rng, wall=(156, 52, 42), roof=(70, 64, 62)):
    v, pal = {}, Palette()
    W, D, H = 26, 36, 22  # half width, half depth (voxels), wall height
    trim = pal((236, 230, 214))
    stone_c = lambda x, y, z: pal(rng.choice([(120, 118, 112), (104, 102, 98), (136, 132, 124)]))
    box(v, -W, W + 1, 0, 4, -D, D + 1, stone_c)  # stone footing
    plank = lambda x, y, z: pal(shade(wall, 0.9 if x % 4 == 0 or z % 4 == 0 else rng.choice((0.97, 1.0, 1.03))))
    for y in range(4, H):
        for x in range(-W, W + 1):
            for z in (-D, D):
                v[(x, y, z)] = plank(x, y, z)
        for z in range(-D, D + 1):
            for x in (-W, W):
                v[(x, y, z)] = plank(x, y, z)
    # Gable ends and a pitched roof with an overhang.
    for y in range(H, H + W + 2):
        half = W + 2 - (y - H)
        for x in range(-half, half + 1):
            for z in (-D, D):
                if abs(x) < half - 1:
                    v[(x, y, z)] = plank(x, y, z)
        for z in range(-D - 3, D + 4):
            for x in (-half, half):
                v[(x, y, z)] = pal(shade(roof, 1.08 if (z // 3) % 2 else 0.94))
                v[(x, y + 1, z)] = pal(shade(roof, 1.0))
    # Big doors with white cross bracing on the front (-z), a hayloft door above.
    for x in range(-9, 10):
        for y in range(4, 20):
            edge = abs(x) == 9 or y == 19 or abs(x) == abs(y - 12) or x == 0
            v[(x, y, -D)] = trim if edge else pal(shade(wall, 0.8))
    for x in range(-4, 5):
        for y in range(24, 31):
            v[(x, y, -D)] = trim if abs(x) == 4 or y in (24, 30) else pal((60, 40, 30))
    for y in range(4, H):
        for c in ((-W, -D), (W, -D), (-W, D), (W, D)):
            v[(c[0], y, c[1])] = trim
    # Hay peeking from the loft.
    for x in range(-3, 4):
        v[(x, 25, -D - 1)] = pal((220, 190, 90))
    return v, pal, None


def shed(rng):
    v, pal = {}, Palette()
    W, D, H = 14, 12, 16
    wood = lambda x, y, z: pal(shade((128, 92, 58), 0.88 if x % 3 == 0 else rng.choice((0.96, 1.0, 1.06))))
    box(v, -W, W + 1, 0, 2, -D, D + 1, lambda x, y, z: pal((110, 106, 100)))
    for y in range(2, H):
        for x in range(-W, W + 1):
            for z in (-D, D):
                v[(x, y, z)] = wood(x, y, z)
        for z in range(-D, D + 1):
            for x in (-W, W):
                v[(x, y, z)] = wood(x, y, z)
    for y in range(H, H + 6):
        for x in range(-W - 2, W + 3):
            z0 = -D - 2 + (y - H) * 3
            for z in range(z0, z0 + 3):
                if z <= D + 2:
                    v[(x, y, z)] = pal((92, 110, 70) if (x + y) % 5 else (80, 96, 62))
        for x in range(-W - 2, W + 3):
            for z in range(-D - 2 + (y - H) * 3 + 3, D + 3):
                pass
    box(v, -W - 2, W + 3, H, H + 1, -D - 2, D + 3, lambda x, y, z: pal((92, 110, 70)))
    for x in range(-4, 5):
        for y in range(2, 13):
            v[(x, y, -D)] = pal((76, 52, 34)) if abs(x) < 4 and y < 12 else pal((150, 110, 70))
    glow = {}
    for y in range(9, 12):
        glow[(6, y, -D - 1)] = GLOW
    return v, pal, glow


def tent(rng, cloth):
    v, pal = {}, Palette()
    L, Wd, H = 18, 14, 16
    for z in range(-L, L + 1):
        for x in range(-Wd, Wd + 1):
            y = H - round(abs(x) * H / Wd)
            if y < 0:
                continue
            front = z == -L
            if front and abs(x) < Wd * 0.45 and y > 1:
                continue  # open flap
            v[(x, y, z)] = pal(shade(cloth, 0.86 if (z // 4) % 2 else 1.0))
            if z in (-L, L):
                for yy in range(0, y):
                    if not (front and abs(x) < Wd * 0.45):
                        v[(x, yy, z)] = pal(shade(cloth, 0.8))
    # Poles and pegs.
    for y in range(0, H + 3):
        v[(0, y, -L - 1)] = pal((96, 70, 44))
        v[(0, y, L + 1)] = pal((96, 70, 44))
    # The open flap folded back, a bedroll inside.
    for y in range(2, H - 2):
        for k in range(2):
            v[(-round(Wd * 0.45) - k, y, -L - 1 - k)] = pal(shade(cloth, 0.75))
    box(v, -4, 5, 0, 1, -L + 4, L - 4, lambda x, y, z: pal((150, 60, 50) if x < 0 else (120, 90, 60)))
    glow = {(3, 6, -L + 3): GLOW, (3, 7, -L + 3): GLOW}
    v[(3, 8, -L + 3)] = pal((60, 50, 40))
    return v, pal, glow


def windmill(rng):
    v, pal = {}, Palette()
    H = 72
    stone_c = lambda x, y, z: pal(rng.choice([(196, 190, 176), (180, 174, 160), (210, 204, 190)]))
    for y in range(H):
        r = 16 - y * 6 / H
        for x in range(-17, 18):
            for z in range(-17, 18):
                d = math.hypot(x, z)
                if r - 1.6 <= d <= r:
                    v[(x, y, z)] = stone_c(x, y, z)
    for y in range(H, H + 14):
        r = 12 - (y - H) * 0.9
        for x in range(-13, 14):
            for z in range(-13, 14):
                if math.hypot(x, z) <= r:
                    v[(x, y, z)] = pal((80, 52, 40) if (x + z) % 4 else (66, 44, 34))
    for x in range(-3, 4):
        for y in range(0, 12):
            v[(x, y, -16)] = pal((80, 56, 36))
    # Sails on the front.
    hub = (0, H + 2, -14)
    for k in range(4):
        a = k * math.tau / 4 + 0.35
        for r in range(2, 36):
            cx, cy = math.cos(a) * r, math.sin(a) * r
            v[(round(cx), round(hub[1] + cy), hub[2] - 2)] = pal((100, 74, 48))
            if r > 6:
                for w in range(1, 7):
                    px = cx - math.sin(a) * w
                    py = cy + math.cos(a) * w
                    v[(round(px), round(hub[1] + py), hub[2] - 2)] = pal((230, 224, 206) if (r + w) % 4 else (100, 74, 48))
    for y in range(20, 26):
        v[(0, y, -16)] = pal((60, 80, 110))
    glow = {(0, y, -17): GLOW for y in range(21, 25)}
    ground_trim(v)
    return v, pal, glow


BUILDINGS = {
    "barn_red": lambda r: barn(r), "barn_grey": lambda r: barn(r, (120, 112, 104), (60, 74, 84)), "shed": shed,
    "tent_canvas": lambda r: tent(r, (214, 200, 168)), "tent_green": lambda r: tent(r, (96, 128, 80)),
    "tent_red": lambda r: tent(r, (176, 76, 58)), "windmill": windmill,
}


# --- .vox writing --------------------------------------------------------------------

def write_vox(path, vox, colors):
    """Writes vox centered on x/z (origin = base center); returns the frame
    (min corner in voxels, Godot axes) and size."""
    xs = [p[0] for p in vox]
    zs = [p[2] for p in vox]
    ys = [p[1] for p in vox]
    hx = max(-min(xs), max(xs) + 1)
    hz = max(-min(zs), max(zs) + 1)
    assert min(ys) >= 0, f"{path}: voxels below ground"
    sx, sy, sz = hx * 2, max(ys) + 1, hz * 2
    assert max(sx, sy, sz) <= 256, f"{path}: too big {sx}x{sy}x{sz}"

    def chunk(cid, content, children=b""):
        return cid + struct.pack("<ii", len(content), len(children)) + content + children

    # godot_voxel's loader maps file (a, b, c) to Godot (b, c, a): write (z, x, y).
    xyzi = struct.pack("<i", len(vox))
    for (x, y, z), c in vox.items():
        xyzi += struct.pack("<BBBB", z + hz, x + hx, y, c)
    rgba = b""
    for i in range(1, 257):
        r, g, b = colors.get(i, (0, 0, 0))
        rgba += struct.pack("<BBBB", r, g, b, 255)
    children = (chunk(b"SIZE", struct.pack("<iii", sz, sx, sy)) + chunk(b"XYZI", xyzi) + chunk(b"RGBA", rgba))
    with open(path, "wb") as f:
        f.write(b"VOX " + struct.pack("<i", 150) + chunk(b"MAIN", b"", children))
    return (-hx, 0, -hz), (sx, sy, sz)


def write_building(name, v, pal, glow):
    folder = os.path.join(ROOT, "props", "surface", name)
    os.makedirs(folder, exist_ok=True)
    # One frame for body and glow so they line up.
    allv = dict(v)
    if glow:
        allv.update(glow)
    xs = [p[0] for p in allv]
    zs = [p[2] for p in allv]
    hx = max(-min(xs), max(xs) + 1)
    hz = max(-min(zs), max(zs) + 1)
    corner_a = (-hx, 0, -hz)
    corner_b = (hx - 1, 0, hz - 1)
    for part, voxels in (("body", v), ("body_glow", glow)):
        if not voxels:
            continue
        vv = dict(voxels)
        # Pin both files to the same frame with invisible corners? .vox can't:
        # instead keep the same extents by padding with the frame corners.
        for c in (corner_a, corner_b):
            if c not in vv:
                vv[c] = None
        clean = {p: c for p, c in vv.items() if c is not None}
        frame_min, size = write_vox_framed(os.path.join(folder, part + ".vox"), clean, pal.colors, hx, hz,
                                           max(p[1] for p in allv) + 1)
    rig = {"voxel_size": 0.125, "parts": {"body": {"frame_min": [-hx, 0, -hz], "glow": bool(glow)}}, "limbs": {},
           "hand": [0, 0, 0], "waddle": 0}
    with open(os.path.join(folder, "rig.json"), "w") as f:
        json.dump(rig, f, indent=2)
    print(f"props/surface/{name}: {len(v)} voxels")


def write_vox_framed(path, vox, colors, hx, hz, sy):
    def chunk(cid, content, children=b""):
        return cid + struct.pack("<ii", len(content), len(children)) + content + children

    sx, sz = hx * 2, hz * 2
    xyzi = struct.pack("<i", len(vox))
    for (x, y, z), c in vox.items():
        xyzi += struct.pack("<BBBB", z + hz, x + hx, y, c)
    rgba = b""
    for i in range(1, 257):
        r, g, b = colors.get(i, (0, 0, 0))
        rgba += struct.pack("<BBBB", r, g, b, 255)
    children = (chunk(b"SIZE", struct.pack("<iii", sz, sx, sy)) + chunk(b"XYZI", xyzi) + chunk(b"RGBA", rgba))
    with open(path, "wb") as f:
        f.write(b"VOX " + struct.pack("<i", 150) + chunk(b"MAIN", b"", children))
    return (-hx, 0, -hz), (sx, sy, sz)


if __name__ == "__main__":
    out = os.path.join(ROOT, "obstacles", "surface")
    os.makedirs(out, exist_ok=True)
    for name, fn in FLORA.items():
        for variant in range(1):
            G = 1.75 if name in TREES else 1.0
            v, pal = fn(random.Random(name))
            frame, size = write_vox(os.path.join(out, name + ".vox"), v, pal.colors)
            print(f"obstacles/surface/{name}: {len(v)} voxels {size}")
    for name, fn in BUILDINGS.items():
        v, pal, glow = fn(random.Random(name))
        write_building(name, v, pal, glow)
