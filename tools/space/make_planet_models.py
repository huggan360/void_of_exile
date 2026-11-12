#!/usr/bin/env python3
"""Voxel models for the Astral Reach's planets and the Nexus.

Run:  python3 tools/space/make_planet_models.py

Writes
  obstacles/planet/<name>.vox     each planet's own flora, stones and oddities
                                  (ObstacleLibrary prefabs "planet/<name>": 0.25 m
                                  voxels, names with "fine_" 0.125 m)
  props/planet/<name>/            houses, halls, landmarks, landing pads, wells,
                                  stalls and lamps (VillageHouse: body.vox,
                                  body_glow.vox, rig.json)
  props/nexus/<name>/             the Nexus deck, bar and its furniture
  props/planet/catalog.json       per building: size (m), sink (m) and voxel size

Buildings stand on a stone plinth that reaches `sink` metres below their
floor, so on the round planets (and on uneven ground) no side ever floats:
the game lowers each building by `sink` along its own up.

Colors are real colors (palette index 9 and up); index 7 is the glow slot,
which a planet tints with its own glow color (flora only). Buildings keep
their glow voxels in body_glow.vox with their own colors. Seeded: every
run gives the same models.
"""
import json
import math
import os
import random
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "surface"))
import make_surface_models as sm  # noqa: E402
from make_surface_models import (GLOW, Palette, shade, mix, box, blob, limb, trunk, ground_trim,  # noqa: E402
                                 leaf_color, top_light, bark, stone, crystal, bush, write_vox, write_vox_framed)

ROOT = sm.ROOT
CATALOG = {}


def T(g):
    """Trees and big flora are drawn in design units of `g` voxels."""
    sm.G = g


# =====================================================================================
# Flora (0.25 m voxels; "fine_" 0.125 m)
# =====================================================================================

# --- Verdance: mossy forest, giant glowing mushrooms, fireflies ------------------------

def moss_oak(rng, leaves=(70, 140, 60)):
    v, pal = {}, Palette()
    h = rng.randint(12, 15)
    moss_bark = lambda x, y, z: pal((86, 128, 58) if rng.random() < 0.3 else shade((92, 68, 46), rng.choice((0.85, 1.0, 1.1))))
    top = trunk(v, h, 2.0, 1.2, moss_bark, rng, lean=(rng.uniform(-2, 2), rng.uniform(-2, 2)))
    lc = leaf_color(pal, leaves, rng)
    clusters = []
    for k in range(5):
        a = k * math.tau / 5 + rng.uniform(-0.4, 0.4)
        r = rng.uniform(4.5, 7.0)
        p = (top[0] + math.cos(a) * r, h + rng.uniform(-1, 3), top[2] + math.sin(a) * r)
        limb(v, (top[0], h - 3, top[2]), p, 1.1, 0.6, moss_bark)
        clusters.append(p)
    clusters.append((top[0], h + 4, top[2]))
    for p in clusters:
        blob(v, p[0], p[1] + 1.5, p[2], rng.uniform(4.6, 6.2), rng.uniform(3.2, 4.4), rng.uniform(4.6, 6.2), lc, rng, rough=0.3)
    top_light(v, pal, 1.12, 0.5, rng)
    # Hanging moss strands and a few fireflies in the crown.
    G = sm.G
    for k in range(34):
        x, z = round((top[0] + rng.uniform(-8, 8)) * G), round((top[2] + rng.uniform(-8, 8)) * G)
        y0 = round((h + 1) * G)
        while y0 > 0 and (x, y0, z) not in v:
            y0 -= 1
        if y0 <= 0:
            continue
        for y in range(y0 - 1, y0 - rng.randint(3, 9), -1):
            if y > 2:
                v.setdefault((x, y, z), pal((104, 150, 70) if y % 2 else (90, 136, 60)))
    for p in list(v):
        if rng.random() < 0.004:
            v[p] = GLOW
    ground_trim(v)
    return v, pal


def glow_cap(rng, cap=(70, 170, 120)):
    """A giant glowing mushroom: pale ribbed stem, wide spotted cap, glowing gills."""
    v, pal = {}, Palette()
    h = rng.randint(9, 14)
    stem = lambda x, y, z: pal((226, 222, 204) if (x + z) % 3 else (206, 202, 186))
    top = trunk(v, h, 1.3, 0.9, stem, rng, lean=(rng.uniform(-2.5, 2.5), rng.uniform(-2.5, 2.5)), roots=False)
    G = sm.G
    r = rng.uniform(5.0, 6.5) * G
    hv = round(h * G)
    tx, tz = round(top[0] * G), round(top[2] * G)
    for x in range(-math.ceil(r), math.ceil(r) + 1):
        for z in range(-math.ceil(r), math.ceil(r) + 1):
            d = math.hypot(x, z) / r
            if d > 1.0:
                continue
            y0 = hv + int((1 - d * d) * 3.2 * G)
            for y in range(hv - 1 + int(d * 1.2 * G), y0 + 1):
                spot = rng.random() < 0.08 and y == y0
                v[(tx + x, y, tz + z)] = GLOW if spot else pal(shade(cap, 0.85 if y < y0 else rng.choice((1.0, 1.06, 0.95))))
    for x in range(-math.ceil(r) + 1, math.ceil(r)):
        for z in range(-math.ceil(r) + 1, math.ceil(r)):
            if 0.25 < math.hypot(x, z) / r < 0.92 and (x + z) % 2 == 0:
                v[(tx + x, hv - 2, tz + z)] = GLOW
    # A ring of small caps round the foot.
    for k in range(rng.randint(3, 5)):
        a = rng.uniform(0, math.tau)
        bx, bz = round(math.cos(a) * 3.2 * G), round(math.sin(a) * 3.2 * G)
        hh = rng.randint(2, 4)
        for y in range(hh):
            v[(bx, y, bz)] = stem(bx, y, bz)
        for dx in range(-2, 3):
            for dz in range(-2, 3):
                if dx * dx + dz * dz <= 4:
                    v[(bx + dx, hh, bz + dz)] = pal(cap) if rng.random() > 0.2 else GLOW
    ground_trim(v)
    return v, pal


def tree_fern(rng):
    v, pal = {}, Palette()
    h = rng.randint(7, 10)
    trunk_c = lambda x, y, z: pal((84, 64, 44) if y % 2 else (70, 54, 38))
    top = trunk(v, h, 0.8, 0.6, trunk_c, rng, lean=(rng.uniform(-1.5, 1.5), rng.uniform(-1.5, 1.5)), roots=False)
    G = sm.G
    for k in range(9):
        a = k * math.tau / 9 + rng.uniform(-0.15, 0.15)
        ln = rng.uniform(5.5, 7.0)
        prev = None
        for s in range(int(ln * G)):
            t = s / (ln * G)
            px = top[0] * G + math.cos(a) * s
            pz = top[2] * G + math.sin(a) * s
            py = h * G + 1.5 * G * math.sin(t * math.pi * 0.9) - t * t * 2.5 * G
            c = pal(shade((66, 140, 60), 1.0 + 0.2 * t))
            for w in range(-2, 3):
                if abs(w) <= 2 - t * 2:
                    q = (round(px - math.sin(a) * w), round(py), round(pz + math.cos(a) * w))
                    if q[1] > 0:
                        v[q] = c
    ground_trim(v)
    return v, pal


def firefly_bush(rng):
    v, pal = bush(rng, (58, 120, 64), None, 1.1)
    for p in list(v):
        if rng.random() < 0.03:
            v[p] = GLOW
    return v, pal


# --- Rosamund: candy trees, rose crystals, fairy stones -------------------------------

def candy_tree(rng, crown=(244, 160, 200), trunk_c=(150, 96, 120)):
    v, pal = {}, Palette()
    h = rng.randint(8, 11)
    top = trunk(v, h, 1.0, 0.7, lambda x, y, z: pal(shade(trunk_c, 1.0 if (y // 2) % 2 else 1.15)), rng,
                lean=(rng.uniform(-1.5, 1.5), rng.uniform(-1.5, 1.5)), roots=False)
    c = lambda x, y, z, d=0.5: pal(shade(crown, 1.12 if d < 0.4 else rng.choice((1.0, 0.96, 1.04))))
    blob(v, top[0], h + 3.2, top[2], 5.0, 4.4, 5.0, c, rng, rough=0.08)
    blob(v, top[0] + rng.uniform(-2, 2), h + 6.2, top[2] + rng.uniform(-2, 2), 3.2, 2.8, 3.2, c, rng, rough=0.08)
    G = sm.G
    # Sugar sprinkles and a few glowing berries.
    for p in list(v):
        if rng.random() < 0.025 and pal.colors.get(v[p], (0, 0, 0))[0] > 120:
            v[p] = pal(rng.choice([(255, 250, 240), (140, 220, 255), (255, 230, 120)]))
        elif rng.random() < 0.004:
            v[p] = GLOW
    ground_trim(v)
    return v, pal


def rose_bush(rng):
    v, pal = bush(rng, (66, 120, 70), None, 1.0)
    for p in list(v):
        if rng.random() < 0.09:
            v[p] = pal(rng.choice([(226, 64, 110), (246, 120, 160), (255, 196, 214)]))
    return v, pal


def giant_flower(rng, petal=(250, 150, 200)):
    v, pal = {}, Palette()
    h = rng.randint(14, 22)
    for y in range(h):
        v[(0, y, 0)] = pal((90, 160, 80))
        v[(1, y, 0)] = pal((80, 148, 72))
        if y in (h // 3, 2 * h // 3):
            for s in range(1, 5):
                side = 1 if y == h // 3 else -1
                v[(side * s + (1 if side > 0 else 0), y + s // 2, 0)] = pal((100, 172, 84))
                v[(side * s + (1 if side > 0 else 0), y + s // 2, 1)] = pal((100, 172, 84))
    for k in range(6):
        a = k * math.tau / 6
        for r in range(1, 6):
            for w in range(-1, 2):
                x = round(math.cos(a) * r - math.sin(a) * w * 0.8)
                z = round(math.sin(a) * r + math.cos(a) * w * 0.8)
                v[(x, h + (1 if r > 3 else 0), z)] = pal(shade(petal, 1.0 if r < 4 else 1.12))
    for x in range(-1, 2):
        for z in range(-1, 2):
            v[(x, h + 1, z)] = GLOW
    return v, pal


def fairy_stone(rng):
    v, pal = {}, Palette()
    h = rng.randint(10, 14)
    for y in range(h):
        r = 2.6 - y * 0.08
        for x in range(-3, 4):
            for z in range(-2, 3):
                if (x / r) ** 2 + (z / (r * 0.7)) ** 2 <= 1.0:
                    v[(x, y, z)] = pal(rng.choice([(214, 196, 210), (196, 178, 194), (226, 210, 222)]))
    for y in range(3, h - 2, 2):
        v[(0, y, -2)] = GLOW
        v[(rng.choice((-1, 1)), y + 1, -2)] = GLOW
    for p in list(v):
        if p[1] < 3 and rng.random() < 0.3:
            v[p] = pal((120, 170, 110))
    return v, pal


# --- Amberfall: amber spires, desert plants, hoodoos -----------------------------------

def amber_spire(rng):
    v, pal = crystal(rng, (236, 160, 60))
    return v, pal


def date_palm(rng):
    v, pal = sm.palm(rng)
    for p in list(v):
        if pal.colors.get(v[p]) == (120, 84, 40):
            v[p] = pal((200, 120, 40))
    return v, pal


def barrel_cactus(rng):
    v, pal = {}, Palette()
    for k in range(rng.randint(2, 4)):
        cx, cz = rng.randint(-4, 4), rng.randint(-4, 4)
        r = rng.uniform(1.8, 2.8)
        h = rng.randint(4, 7)
        for y in range(h):
            rr = r * math.sqrt(max(0.15, 1 - ((y - h * 0.45) / (h * 0.6)) ** 2))
            for x in range(-3, 4):
                for z in range(-3, 4):
                    if x * x + z * z <= rr * rr:
                        rib = (round(math.degrees(math.atan2(z, x))) // 40) % 2
                        v[(cx + x, y, cz + z)] = pal((84, 140, 76) if rib else (70, 120, 64))
        v[(cx, h, cz)] = pal((246, 120, 150))
        v[(cx + 1, h, cz)] = pal((250, 200, 90))
    return v, pal


def hoodoo(rng, base=(204, 140, 86)):
    """A desert rock chimney: banded stacked chunks with a cap stone."""
    v, pal = {}, Palette()
    h = rng.randint(10, 16)
    G = sm.G
    hv = round(h * G)
    for y in range(hv):
        t = y / hv
        r = (2.4 - 0.9 * math.sin(t * math.pi * 1.3)) * G * 0.6 + 1.0
        band = shade(base, 0.82 if (y // 3) % 3 == 0 else 1.0 + 0.1 * math.sin(y))
        for x in range(-math.ceil(r) - 1, math.ceil(r) + 2):
            for z in range(-math.ceil(r) - 1, math.ceil(r) + 2):
                if x * x + z * z <= r * r - rng.random() * 1.5:
                    v[(x, y, z)] = pal(shade(band, rng.uniform(0.95, 1.05)))
    cap = 3.2 * G * 0.6 + 1
    for x in range(-math.ceil(cap), math.ceil(cap) + 1):
        for z in range(-math.ceil(cap), math.ceil(cap) + 1):
            if x * x + z * z <= cap * cap:
                for y in range(hv, hv + 2):
                    v[(x, y, z)] = pal(shade((150, 96, 60), rng.uniform(0.9, 1.05)))
    return v, pal


def honeycomb_rock(rng):
    v, pal = stone(rng, (210, 150, 70), 1.4)
    for p in list(v):
        if (p[0] + p[1] * 2 + p[2]) % 5 == 0 and rng.random() < 0.6:
            v[p] = GLOW if rng.random() < 0.3 else pal((240, 180, 70))
    return v, pal


# --- Tidewell: beaches, coral, shells --------------------------------------------------

def coral(rng, color=(240, 110, 120)):
    v, pal = {}, Palette()
    for k in range(rng.randint(4, 7)):
        a = rng.uniform(0, math.tau)
        x, y, z = 0.0, 0.0, 0.0
        for s in range(rng.randint(8, 14)):
            x += math.cos(a) * 0.5 + rng.uniform(-0.4, 0.4)
            z += math.sin(a) * 0.5 + rng.uniform(-0.4, 0.4)
            y += 1
            for dx in (0, 1):
                v[(round(x) + dx, round(y), round(z))] = pal(shade(color, 0.85 + 0.03 * s))
            if s % 4 == 3:
                a += rng.uniform(-1.0, 1.0)
        v[(round(x), round(y) + 1, round(z))] = GLOW
    for x in range(-3, 4):
        for z in range(-3, 4):
            if x * x + z * z <= 9:
                v[(x, 0, z)] = pal((200, 190, 170))
    return v, pal


def conch(rng):
    v, pal = {}, Palette()
    for i in range(70):
        t = i / 70
        r = 5.2 * (1 - t) + 0.6
        a = t * math.tau * 2.2
        cx, cy, cz = math.cos(a) * r * 0.5, 1.5 + t * 7, math.sin(a) * r * 0.5
        rr = r * 0.55
        for dx in range(-math.ceil(rr), math.ceil(rr) + 1):
            for dy in range(-math.ceil(rr), math.ceil(rr) + 1):
                for dz in range(-math.ceil(rr), math.ceil(rr) + 1):
                    if dx * dx + dy * dy + dz * dz <= rr * rr:
                        q = (round(cx + dx), round(cy + dy), round(cz + dz))
                        if q[1] >= 0:
                            v[q] = pal((248, 214, 190) if (i // 6) % 2 else (236, 178, 150))
    for y in range(1, 5):
        for x in range(2, 5):
            v[(x, y, -3)] = pal((250, 150, 160))
    return v, pal


def driftwood(rng):
    v, pal = {}, Palette()
    a = rng.uniform(0, math.tau)
    ln = rng.randint(10, 16)
    limb(v, (-math.cos(a) * ln / 2, 1, -math.sin(a) * ln / 2), (math.cos(a) * ln / 2, 1.5, math.sin(a) * ln / 2), 1.2, 0.8,
         lambda x, y, z: pal(rng.choice([(196, 182, 160), (178, 164, 144), (210, 198, 178)])))
    limb(v, (0, 1.5, 0), (math.cos(a + 1.2) * 4, 3.5, math.sin(a + 1.2) * 4), 0.6, 0.4, pal((186, 172, 150)))
    ground_trim(v)
    return v, pal


def sea_rock(rng):
    v, pal = stone(rng, (96, 104, 112), 1.5)
    for p in list(v):
        if p[1] < 4 and rng.random() < 0.25:
            v[p] = pal(rng.choice([(226, 222, 206), (60, 110, 80)]))
    return v, pal


def beach_grass(rng):
    v, pal = {}, Palette()
    for k in range(rng.randint(10, 16)):
        x, z = rng.randint(-5, 5), rng.randint(-5, 5)
        h = rng.randint(5, 10)
        lean = rng.uniform(-0.3, 0.3)
        for y in range(h):
            v[(round(x + lean * y), y, z)] = pal((168, 176, 96) if y < h - 3 else (206, 196, 120))
    return v, pal


# --- Shardheart: singing crystals and geodes ------------------------------------------

def shard_spire(rng, color=(90, 230, 200)):
    v, pal = {}, Palette()
    for k in range(rng.randint(2, 4)):
        a = rng.uniform(0, math.tau)
        tilt = rng.uniform(0.05, 0.35) if k else 0.0
        h = rng.randint(22, 34) if k == 0 else rng.randint(10, 18)
        x0, z0 = (0, 0) if k == 0 else (round(math.cos(a) * 3), round(math.sin(a) * 3))
        r0 = 3.2 if k == 0 else 2.0
        for y in range(h):
            r = r0 * (1 - (y / h) ** 1.6) + 0.5
            cx = x0 + math.cos(a) * tilt * y
            cz = z0 + math.sin(a) * tilt * y
            for dx in range(-4, 5):
                for dz in range(-4, 5):
                    if abs(dx) + abs(dz) * 0.8 <= r:  # faceted (diamond) section
                        edge = abs(dx) + abs(dz) * 0.8 > r - 1.0
                        q = (round(cx + dx), y, round(cz + dz))
                        v[q] = GLOW if (edge and (y + dx) % 5 == 0) else pal(shade(color, 0.6 + 0.6 * y / h + (0.12 if edge else 0)))
    return v, pal


def geode(rng):
    v, pal = stone(rng, (70, 74, 90), 1.6)
    tops = {}
    for (x, y, z) in v:
        if (x, z) not in tops or y > tops[(x, z)]:
            tops[(x, z)] = y
    for (x, z), y in tops.items():
        if rng.random() < 0.08:
            for k in range(rng.randint(2, 5)):
                v[(x, y + 1 + k, z)] = GLOW if k > 1 else pal((255, 140, 224))
    return v, pal


# --- Hollowmoon: bones, ghost lights, graves -------------------------------------------

BONE = (220, 214, 196)


def bone_tree(rng):
    v, pal = {}, Palette()
    bone = lambda x, y, z: pal(shade(BONE, rng.choice((0.88, 1.0, 1.05))))
    h = rng.randint(10, 14)
    top = trunk(v, h, 0.9, 0.6, bone, rng, lean=(rng.uniform(-2, 2), rng.uniform(-2, 2)))
    for k in range(rng.randint(4, 6)):
        a = rng.uniform(0, math.tau)
        y = rng.uniform(h * 0.4, h)
        p = (top[0] * y / h + math.cos(a) * rng.uniform(3, 5), y + rng.uniform(1, 3), top[2] * y / h + math.sin(a) * rng.uniform(3, 5))
        limb(v, (top[0] * y / h, y, top[2] * y / h), p, 0.5, 0.35, bone)
        # Knuckles and a ghost-light bulb at each tip.
        G = sm.G
        q = (round(p[0] * G), round(p[1] * G), round(p[2] * G))
        for dx in (-1, 0, 1):
            v[(q[0] + dx, q[1], q[2])] = bone(*q)
        v[(q[0], q[1] - 1, q[2])] = GLOW
        v[(q[0], q[1] - 2, q[2])] = GLOW
    ground_trim(v)
    return v, pal


def ribcage(rng):
    """Giant ribs arching out of the ground: a fallen titan."""
    v, pal = {}, Palette()
    bone = lambda x, y, z: pal(shade(BONE, rng.choice((0.85, 0.95, 1.05))))
    G = sm.G
    ln = 9
    for x in range(-ln * 2, ln * 2 + 1):  # spine
        for y in range(0, 3):
            for z in range(-1, 2):
                if y * y + z * z <= 3:
                    v[(x, y, z)] = bone(x, y, z)
    for k in range(-3, 4):
        x0 = k * 5
        for side in (-1, 1):
            for s in range(40):
                t = s / 40
                y = math.sin(t * math.pi * 0.9) * 16
                z = side * math.cos(t * math.pi * 0.9) * -10 * (1 - t * 0.3) + side * 10 * 0.0
                z = side * (t * 14)
                for dx in (0, 1):
                    for dy in (0, 1):
                        q = (x0 + dx, round(y) + dy, round(z))
                        if q[1] >= 0:
                            v[q] = bone(*q)
    ground_trim(v)
    return v, pal


def ghost_lamp(rng):
    v, pal = {}, Palette()
    iron = pal((52, 56, 62))
    h = rng.randint(14, 18)
    for y in range(h):
        v[(0, y, 0)] = iron
    for x in range(0, 5):
        v[(x, h, 0)] = iron
    for y in range(h - 4, h):
        v[(4, y, 0)] = iron
    for dx in (-1, 0, 1):
        for dz in (-1, 0, 1):
            for y in range(h - 7, h - 4):
                v[(4 + dx, y, dz)] = GLOW if abs(dx) + abs(dz) < 2 else iron
    for x in range(-2, 3):
        for z in range(-2, 3):
            v[(x, 0, z)] = pal((90, 92, 98))
    return v, pal


def tombstones(rng):
    v, pal = {}, Palette()
    for k in range(rng.randint(3, 5)):
        cx, cz = rng.randint(-8, 8), rng.randint(-8, 8)
        h = rng.randint(5, 8)
        tilt = rng.uniform(-0.15, 0.15)
        g = rng.choice([(140, 142, 150), (120, 122, 130), (160, 158, 150)])
        for y in range(h):
            w = 2 if y < h - 1 else 1
            for x in range(-w, w + 1):
                v[(cx + x + round(tilt * y), y, cz)] = pal(shade(g, rng.uniform(0.9, 1.05)))
                v[(cx + x + round(tilt * y), y, cz + 1)] = pal(shade(g, 0.85))
        v[(cx + round(tilt * 3), 3, cz - 1)] = GLOW if rng.random() < 0.5 else pal((80, 120, 80))
    return v, pal


def moon_rock(rng):
    v, pal = stone(rng, (150, 152, 160), 1.7)
    # Craters: dark pocks on the top.
    tops = {}
    for (x, y, z) in v:
        if (x, z) not in tops or y > tops[(x, z)]:
            tops[(x, z)] = y
    for (x, z), y in tops.items():
        if rng.random() < 0.06:
            v[(x, y, z)] = pal((96, 98, 106))
        elif rng.random() < 0.01:
            v[(x, y, z)] = GLOW
    return v, pal


# --- Mawgrave: fungal stacks, spore pods, hive mounds, tendrils -------------------------

def fungal_stack(rng):
    v, pal = {}, Palette()
    h = rng.randint(12, 18)
    stem = lambda x, y, z: pal(shade((120, 80, 140), rng.choice((0.85, 1.0, 1.1))))
    top = trunk(v, h, 1.1, 0.7, stem, rng, lean=(rng.uniform(-3, 3), rng.uniform(-3, 3)), roots=False)
    G = sm.G
    for k in range(3):
        y = h * (0.45 + 0.27 * k)
        cx, cz = top[0] * y / h, top[2] * y / h
        r = (4.2 - k * 0.9) * G
        for x in range(-math.ceil(r), math.ceil(r) + 1):
            for z in range(-math.ceil(r), math.ceil(r) + 1):
                d = math.hypot(x, z) / r
                if d <= 1.0:
                    yy = round(y * G + (1 - d) * 2.2 * G)
                    q = (round(cx * G) + x, yy, round(cz * G) + z)
                    v[q] = GLOW if rng.random() < 0.06 else pal(shade((150, 70, 170), 0.9 + (1 - d) * 0.25))
                    v[(q[0], yy - 1, q[2])] = pal((90, 40, 110)) if d > 0.4 else GLOW
    ground_trim(v)
    return v, pal


def spore_pod(rng):
    v, pal = {}, Palette()
    for k in range(rng.randint(2, 4)):
        cx, cz = rng.uniform(-3, 3), rng.uniform(-3, 3)
        h = rng.randint(3, 7)
        for y in range(h):
            v[(round(cx), y, round(cz))] = pal((90, 60, 100))
        blob(v, cx, h + 2.2, cz, 2.6, 3.0, 2.6, lambda x, y, z, d: GLOW if d < 0.45 or rng.random() < 0.15 else pal((200, 80, 190)), rng, 0.1)
    return v, pal


def hive_mound(rng):
    v, pal = {}, Palette()
    G = sm.G
    blob(v, 0, 0, 0, 7, 9, 7, lambda x, y, z, d: pal(shade((80, 50, 90), 0.8 + (1 - d) * 0.3 + rng.uniform(-0.05, 0.05))), rng, 0.12)
    blob(v, 2, 6, 1, 4, 6, 4, lambda x, y, z, d: pal(shade((100, 60, 110), 0.9 + rng.uniform(-0.05, 0.05))), rng, 0.12)
    # Glowing holes all over.
    for p in list(v):
        if rng.random() < 0.012:
            for dx in (0, 1):
                for dy in (0, 1):
                    q = (p[0] + dx, p[1] + dy, p[2])
                    if q in v:
                        v[q] = GLOW
    ground_trim(v)
    return v, pal


def tendrils(rng):
    v, pal = {}, Palette()
    for k in range(rng.randint(4, 7)):
        a = rng.uniform(0, math.tau)
        x, z = rng.uniform(-2, 2), rng.uniform(-2, 2)
        h = rng.randint(12, 20)
        for y in range(h):
            t = y / h
            curl = t * t * 4.0
            px = x + math.cos(a + t * 3) * curl
            pz = z + math.sin(a + t * 3) * curl
            w = 1 if t < 0.6 else 0
            for dx in range(0, w + 1):
                for dz in range(0, w + 1):
                    v[(round(px) + dx, y, round(pz) + dz)] = pal(shade((110, 60, 130), 0.8 + 0.5 * t))
        v[(round(x + math.cos(a + 3) * 4), h, round(z + math.sin(a + 3) * 4))] = GLOW
    return v, pal


def shelf_tree(rng):
    v, pal = sm.dead_tree(rng, burnt=False)
    for p in list(v):
        v[p] = pal((70, 52, 72)) if v[p] != GLOW else GLOW
    for p in list(v):
        if rng.random() < 0.05:
            for dx in range(-2, 3):
                for dz in range(-2, 3):
                    if dx * dx + dz * dz <= 4:
                        v.setdefault((p[0] + dx, p[1], p[2] + dz), pal((210, 110, 200)) if rng.random() > 0.15 else GLOW)
    return v, pal


# --- The Pale Eye: obsidian, storm rods, charred trees ----------------------------------

def obsidian_spire(rng):
    v, pal = shard_spire(rng, (44, 46, 64))
    for p in list(v):
        if v[p] == GLOW and rng.random() < 0.7:
            v[p] = pal((70, 76, 110))
    return v, pal


def storm_rod(rng):
    v, pal = {}, Palette()
    h = rng.randint(24, 32)
    iron = lambda y: pal((60, 64, 76) if y % 4 else (90, 96, 112))
    for y in range(h):
        for dx in (0, 1):
            for dz in (0, 1):
                v[(dx, y, dz)] = iron(y)
    for y in (h // 3, 2 * h // 3):
        for x in range(-3, 5):
            v[(x, y, 0)] = iron(1)
    for y in range(h, h + 4):
        v[(0, y, 0)] = GLOW
    for x in range(-4, 6):
        for z in range(-4, 6):
            if (x - 0.5) ** 2 + (z - 0.5) ** 2 <= 20:
                v[(x, 0, z)] = pal((36, 38, 48))
                if rng.random() < 0.15:
                    v[(x, 1, z)] = GLOW
    return v, pal


def storm_crystal(rng):
    return shard_spire(rng, (110, 140, 255))


# --- Small things (0.125 m) -------------------------------------------------------------

def scatter(rng, colors, count=(6, 10), height=(1, 3), spread=4, glow=0.0):
    v, pal = {}, Palette()
    for k in range(rng.randint(*count)):
        x, z = rng.randint(-spread, spread), rng.randint(-spread, spread)
        h = rng.randint(*height)
        c = rng.choice(colors)
        for y in range(h):
            v[(x, y, z)] = GLOW if (y == h - 1 and rng.random() < glow) else pal(c)
        if rng.random() < 0.5:
            v[(x + 1, 0, z)] = pal(c)
    return v, pal


def petals(rng):
    v, pal = {}, Palette()
    for k in range(rng.randint(10, 16)):
        x, z = rng.randint(-6, 6), rng.randint(-6, 6)
        v[(x, 0, z)] = pal(rng.choice([(250, 180, 210), (255, 220, 236), (236, 140, 190)]))
    return v, pal


def bone_bits(rng):
    v, pal = {}, Palette()
    for k in range(rng.randint(2, 4)):
        a = rng.uniform(0, math.tau)
        cx, cz = rng.randint(-4, 4), rng.randint(-4, 4)
        for s in range(-3, 4):
            v[(round(cx + math.cos(a) * s), 0, round(cz + math.sin(a) * s))] = pal(BONE)
        for e in (-3, 3):
            v[(round(cx + math.cos(a) * e), 1, round(cz + math.sin(a) * e))] = pal(shade(BONE, 0.9))
    return v, pal


def fine_caps(rng, cap, glow):
    v, pal = sm.mushrooms(rng, cap)
    if glow:
        for p in list(v):
            if pal.colors.get(v[p]) == cap and rng.random() < 0.5:
                v[p] = GLOW
    return v, pal


TREES = {"moss_oak", "moss_oak_gold", "glow_cap", "glow_cap_blue", "tree_fern", "candy_tree", "candy_tree_mint", "candy_tree_lilac",
         "giant_flower", "date_palm", "hoodoo", "bone_tree", "ribcage", "fungal_stack", "shelf_tree", "obsidian_spire", "storm_crystal"}
FLORA = {
    # Verdance
    "moss_oak": lambda r: moss_oak(r), "moss_oak_gold": lambda r: moss_oak(r, (150, 170, 60)),
    "glow_cap": lambda r: glow_cap(r), "glow_cap_blue": lambda r: glow_cap(r, (70, 120, 210)), "tree_fern": tree_fern,
    "firefly_bush": firefly_bush, "mossy_boulder": lambda r: stone(r, (120, 124, 116), 1.8, moss=0.75),
    # Rosamund
    "candy_tree": lambda r: candy_tree(r), "candy_tree_mint": lambda r: candy_tree(r, (150, 230, 200), (150, 110, 130)),
    "candy_tree_lilac": lambda r: candy_tree(r, (200, 170, 250), (140, 96, 130)),
    "rose_crystal": lambda r: crystal(r, (250, 140, 200)), "rose_bush": rose_bush, "giant_flower": lambda r: giant_flower(r),
    "fairy_stone": fairy_stone,
    # Amberfall
    "amber_spire": amber_spire, "date_palm": date_palm, "barrel_cactus": barrel_cactus, "hoodoo": lambda r: hoodoo(r),
    "honeycomb_rock": honeycomb_rock, "dune_bush": lambda r: bush(r, (150, 150, 80), (240, 180, 60), 0.8),
    # Tidewell
    "coral_pink": lambda r: coral(r), "coral_teal": lambda r: coral(r, (90, 200, 200)), "conch": conch, "driftwood": driftwood,
    "sea_rock": sea_rock, "beach_grass": beach_grass,
    # Shardheart
    "shard_spire": lambda r: shard_spire(r), "shard_spire_pink": lambda r: shard_spire(r, (250, 130, 220)), "geode": geode,
    # Hollowmoon
    "bone_tree": bone_tree, "ribcage": ribcage, "ghost_lamp": ghost_lamp, "tombstones": tombstones, "moon_rock": moon_rock,
    # Mawgrave
    "fungal_stack": fungal_stack, "spore_pod": spore_pod, "hive_mound": hive_mound, "tendrils": tendrils, "shelf_tree": shelf_tree,
    # The Pale Eye
    "obsidian_spire": obsidian_spire, "storm_rod": storm_rod, "storm_crystal": storm_crystal,
    "charred_tree": lambda r: sm.dead_tree(r, burnt=True), "basalt": lambda r: stone(r, (40, 42, 54), 1.7, cracks=0.03, glow_cracks=True),
    # Ground clutter (0.125 m)
    "fine_glow_caps": lambda r: fine_caps(r, (80, 200, 140), True), "fine_moss_stone": lambda r: stone(r, (120, 124, 116), 0.5, moss=0.7),
    "fine_petals": petals, "fine_pink_shards": lambda r: scatter(r, [(250, 150, 210), (255, 190, 230)], (4, 7), (2, 5), 3, 0.4),
    "fine_amber_shards": lambda r: scatter(r, [(240, 170, 60), (255, 210, 110)], (4, 7), (2, 4), 3, 0.3),
    "fine_sand_stone": lambda r: stone(r, (210, 160, 104), 0.5),
    "fine_shells": lambda r: scatter(r, [(250, 226, 210), (240, 180, 160), (250, 240, 230)], (3, 6), (1, 2), 5),
    "fine_starfish": lambda r: scatter(r, [(250, 120, 80), (240, 150, 60)], (3, 5), (1, 1), 4),
    "fine_teal_shards": lambda r: scatter(r, [(90, 230, 200), (140, 250, 230)], (4, 7), (2, 6), 3, 0.5),
    "fine_bone_bits": bone_bits, "fine_moon_pebbles": lambda r: stone(r, (150, 152, 160), 0.45),
    "fine_ghost_sprouts": lambda r: scatter(r, [(120, 200, 140)], (5, 9), (1, 3), 4, 0.6),
    "fine_spore_caps": lambda r: fine_caps(r, (200, 80, 200), True), "fine_violet_tufts": lambda r: scatter(r, [(130, 80, 150), (160, 100, 170)], (8, 12), (2, 4), 4),
    "fine_obsidian": lambda r: scatter(r, [(40, 42, 56), (60, 64, 84)], (3, 6), (1, 4), 3),
    "fine_storm_sparks": lambda r: scatter(r, [(60, 64, 84)], (4, 7), (1, 2), 4, 0.5),
}


# =====================================================================================
# Buildings (0.125 m voxels) -- shapes in voxels, y = 0 is the bottom of the plinth
# =====================================================================================

class Building:
    """Body and glow voxels, a palette, and where the floor is (the plinth below
    it is the part sunk into the ground)."""

    def __init__(self, floor=12):
        self.v = {}
        self.glow = {}
        self.pal = Palette()
        self.floor = floor

    def c(self, rgb):
        return self.pal(rgb)

    def put(self, x, y, z, rgb):
        self.v[(x, y, z)] = self.pal(rgb) if isinstance(rgb, tuple) else rgb

    def light(self, x, y, z, rgb=(255, 196, 110)):
        self.v.pop((x, y, z), None)
        self.glow[(x, y, z)] = self.pal(rgb)

    def fill(self, x0, x1, y0, y1, z0, z1, rgb):
        for x in range(x0, x1):
            for y in range(y0, y1):
                for z in range(z0, z1):
                    self.v[(x, y, z)] = self.pal(rgb(x, y, z) if callable(rgb) else rgb)


def jitter(rng, rgb, k=0.06):
    """A few shades of `rgb` (a model's palette has only 247 slots)."""
    return shade(rgb, 1 + k * rng.choice((-1.0, -0.5, 0.0, 0.0, 0.5, 1.0)))


def plinth(b, rng, hx, hz, rgb, round_=False, flare=3):
    """Stone footing from y = 0 up to the floor, flaring out toward the bottom."""
    for y in range(b.floor):
        grow = round((b.floor - y) / b.floor * flare)
        for x in range(-hx - grow, hx + grow + 1):
            for z in range(-hz - grow, hz + grow + 1):
                if round_ and x * x + z * z > (hx + grow + 0.5) ** 2:
                    continue
                edge = abs(x) >= hx + grow - 1 or abs(z) >= hz + grow - 1 or (round_ and x * x + z * z > (hx + grow - 1.5) ** 2)
                if edge or y == b.floor - 1:
                    b.put(x, y, z, jitter(rng, rgb if (x // 3 + y // 2 + z // 3) % 2 else shade(rgb, 0.9)))


def walls(b, rng, hx, hz, h, rgb, timber=None, door=(0, 6, 14), windows=True, win_rgb=(255, 196, 110), sill=None):
    """Hollow walls from the floor up `h`; a door on -z (centre x, half width,
    height), windows with glowing panes, optional timber framing."""
    f = b.floor
    for y in range(f, f + h):
        for x in range(-hx, hx + 1):
            for z in (-hz, hz):
                b.put(x, y, z, _wall(rng, rgb, timber, x, y - f, z, hx, hz, h))
        for z in range(-hz, hz + 1):
            for x in (-hx, hx):
                b.put(x, y, z, _wall(rng, rgb, timber, x, y - f, z, hx, hz, h))
    dx, dw, dh = door
    for x in range(dx - dw, dx + dw + 1):
        for y in range(f, f + dh):
            edge = abs(x - dx) == dw or y == f + dh - 1
            b.put(x, y, -hz, (88, 60, 40) if edge else (64, 42, 30) if (x - dx) % 3 else (54, 36, 26))
    b.light(dx + dw - 2, f + dh // 2, -hz - 1, (255, 210, 120))
    if windows:
        wy = f + max(4, h // 2 - 2)
        for side_z in (-hz, hz):
            for wx in range(-hx + 5, hx - 4, 9):
                if side_z == -hz and abs(wx - dx) <= dw + 3:
                    continue
                _window(b, wx, wy, side_z, 0, win_rgb, sill)
        for side_x in (-hx, hx):
            for wz in range(-hz + 5, hz - 4, 9):
                _window(b, side_x, wy, wz, 1, win_rgb, sill)


def _wall(rng, rgb, timber, x, y, z, hx, hz, h):
    if timber and (abs(x) == hx or abs(z) == hz) and (abs(x) == hx and abs(z) == hz or y == 0 or y == h - 1 or (x + z) % 8 == 0):
        return jitter(rng, timber, 0.05)
    return jitter(rng, rgb, 0.04)


def _window(b, x, y, z, axis, rgb, sill):
    for a in range(-2, 3):
        for yy in range(y, y + 5):
            px, pz = (x + a, z) if axis == 0 else (x, z + a)
            if abs(a) == 2 or yy in (y, y + 4):
                b.put(px, yy, pz, (70, 50, 36))
            else:
                b.light(px, yy, pz, rgb)
    if sill:
        for a in range(-2, 3):
            px, pz = (x + a, z - 1 if z < 0 else z + 1) if axis == 0 else (x - 1 if x < 0 else x + 1, z + a)
            b.put(px, y - 1, pz, sill)


def gable_roof(b, rng, hx, hz, base, rgb, over=2, pitch=1.0, gable_rgb=None):
    """A pitched roof along z with an overhang; gable ends filled."""
    y = base
    half = hx + over
    k = 0
    while half >= 0:
        for z in range(-hz - over, hz + over + 1):
            for x in (-half, half):
                b.put(x, y, z, jitter(rng, shade(rgb, 1.08 if (z // 3 + k) % 2 else 0.94), 0.03))
        if gable_rgb is not None:
            for x in range(-half + 1, half):
                if abs(x) <= hx:
                    for z in (-hz, hz):
                        b.put(x, y, z, jitter(rng, gable_rgb, 0.04))
        k += 1
        y += 1
        if k % max(1, round(1 / pitch)) == 0:
            half -= 1
    for z in range(-hz - over, hz + over + 1):
        b.put(0, y, z, shade(rgb, 0.8))
    return y


def cone_roof(b, rng, r, base, height, rgb, over=2):
    top = base + height
    for y in range(base, top + 1):
        rr = (r + over) * (1 - (y - base) / (height + 1))
        for x in range(-math.ceil(rr), math.ceil(rr) + 1):
            for z in range(-math.ceil(rr), math.ceil(rr) + 1):
                d = math.hypot(x, z)
                if rr - 1.6 <= d <= rr:
                    b.put(x, y, z, jitter(rng, shade(rgb, 1.08 if (y // 2) % 2 else 0.95), 0.03))
    return top


def dome(b, rng, r, base, rgb, squash=1.0, shell=1.5, glow_every=0):
    for x in range(-r, r + 1):
        for z in range(-r, r + 1):
            for y in range(0, round(r * squash) + 1):
                d = math.sqrt(x * x + z * z + (y / squash) ** 2)
                if r - shell <= d <= r:
                    if glow_every and (x + y + z) % glow_every == 0 and y > 1:
                        b.light(x, base + y, z, glow_every_color(rgb))
                    else:
                        b.put(x, base + y, z, jitter(rng, rgb, 0.05))


def glow_every_color(rgb):
    return tuple(min(255, int(c * 1.3 + 30)) for c in rgb)


def round_walls(b, rng, r, h, rgb, door=True, windows=4, win_rgb=(255, 196, 110), bands=None):
    f = b.floor
    for y in range(f, f + h):
        for x in range(-r - 1, r + 2):
            for z in range(-r - 1, r + 2):
                d = math.hypot(x, z)
                if r - 1.4 <= d <= r:
                    c = bands[(y - f) // 3 % len(bands)] if bands else rgb
                    b.put(x, y, z, jitter(rng, c, 0.04))
    if door:
        for x in range(-3, 4):
            for y in range(f, f + 12):
                for z in range(-r - 1, -r + 3):
                    if math.hypot(x, z) >= r - 1.6:
                        b.put(x, y, z, (64, 42, 30) if abs(x) < 3 and y < f + 11 else (96, 66, 44))
    for k in range(windows):
        a = (k + 0.5) * math.tau / windows + math.pi / 2
        cx, cz = round(math.cos(a) * r), round(math.sin(a) * r)
        if cz < -r * 0.7:
            continue
        for yy in range(f + h // 2 - 2, f + h // 2 + 2):
            b.light(cx, yy, cz, win_rgb)


def chimney(b, rng, x, z, y0, y1, rgb):
    for y in range(y0, y1):
        for dx in (0, 1, 2):
            for dz in (0, 1, 2):
                b.put(x + dx, y, z + dz, jitter(rng, rgb, 0.06))
    b.light(x + 1, y1, z + 1, (255, 150, 80))


def lantern_pole(b, x, z, y0, h, glow=(255, 196, 110), iron=(60, 52, 48)):
    for y in range(y0, y0 + h):
        b.put(x, y, z, iron)
    for dx in (-1, 0, 1):
        for dz in (-1, 0, 1):
            b.put(x + dx, y0 + h, z + dz, iron)
            if abs(dx) + abs(dz) < 2:
                b.light(x + dx, y0 + h - 1, z + dz, glow)
                b.light(x + dx, y0 + h - 2, z + dz, glow)
    b.put(x, y0 + h + 1, z, iron)


# --- Houses by planet style ----------------------------------------------------------

def moss_cottage(rng, roof=(80, 130, 64)):
    b = Building(10)
    hx, hz, h = 20, 17, 20
    plinth(b, rng, hx + 1, hz + 1, (120, 116, 108))
    walls(b, rng, hx, hz, h, (214, 200, 168), timber=(100, 70, 46), sill=(90, 130, 70))
    top = gable_roof(b, rng, hx, hz, b.floor + h, roof, over=3, gable_rgb=(214, 200, 168))
    chimney(b, rng, 10, 6, b.floor + h, top + 2, (130, 120, 110))
    # Moss tufts on the roof.
    for p in list(b.v):
        if p[1] > b.floor + h and rng.random() < 0.08:
            b.put(p[0], p[1] + 1, p[2], (100, 156, 70))
    return b


def mushroom_house(rng, cap=(196, 64, 60)):
    b = Building(8)
    r = 20
    plinth(b, rng, r - 4, r - 4, (110, 104, 96), round_=True, flare=2)
    round_walls(b, rng, r - 4, 26, (232, 222, 200), windows=5)
    base = b.floor + 24
    for x in range(-r - 8, r + 9):
        for z in range(-r - 8, r + 9):
            d = math.hypot(x, z) / (r + 8)
            if d > 1:
                continue
            y0 = base + int((1 - d * d) * 16)
            for y in range(base + int(d * 4), y0 + 1):
                spot = (x // 5 + z // 5) % 3 == 0 and ((x % 5) - 2) ** 2 + ((z % 5) - 2) ** 2 < 4 and y == y0
                b.put(x, y, z, (250, 244, 230) if spot else jitter(rng, cap if y > y0 - 2 else shade(cap, 0.8), 0.04))
    for k in range(10):
        a = k * math.tau / 10
        b.light(round(math.cos(a) * (r + 3)), base + 2, round(math.sin(a) * (r + 3)), (180, 255, 200))
    return b


def petal_cottage(rng, wall=(250, 214, 228), roof=(214, 96, 150)):
    b = Building(10)
    hx, hz, h = 18, 16, 20
    plinth(b, rng, hx + 1, hz + 1, (220, 200, 214))
    walls(b, rng, hx, hz, h, wall, timber=(170, 120, 150), win_rgb=(255, 220, 160), sill=(240, 120, 170))
    # Scalloped cone-ish hip roof.
    y = b.floor + h
    half = hx + 3
    k = 0
    while half > 2:
        for x in range(-half, half + 1):
            for z in range(-half + (hx - hz), half - (hx - hz) + 1):
                if abs(x) >= half - 1 or abs(z) >= half - (hx - hz) - 1:
                    scallop = (x + z) % 4 == 0 and k % 2 == 0
                    b.put(x, y, z, shade(roof, 1.15) if scallop else jitter(rng, roof, 0.04))
        y += 1
        k += 1
        half -= 1
    b.light(0, y, 0, (255, 160, 220))
    b.light(0, y + 1, 0, (255, 160, 220))
    for x in range(-hx - 2, hx + 3, 3):  # flower boxes under the windows
        b.put(x, b.floor + 8, -hz - 1, (240, 120, 170) if x % 2 else (255, 230, 120))
    return b


def fairy_tower(rng):
    b = Building(10)
    r = 12
    plinth(b, rng, r, r, (210, 190, 206), round_=True)
    round_walls(b, rng, r, 46, (236, 220, 232), windows=6, win_rgb=(255, 180, 230), bands=[(236, 220, 232), (226, 206, 222)])
    top = cone_roof(b, rng, r, b.floor + 46, 30, (196, 96, 170), over=3)
    b.light(0, top + 1, 0, (255, 190, 240))
    b.light(0, top + 2, 0, (255, 190, 240))
    return b


def adobe_house(rng, wall=(222, 178, 120)):
    b = Building(8)
    hx, hz, h = 19, 16, 22
    plinth(b, rng, hx + 1, hz + 1, (186, 146, 100))
    walls(b, rng, hx, hz, h, wall, win_rgb=(255, 200, 120))
    # Flat roof with a parapet, a little dome and rafters poking out.
    y = b.floor + h
    b.fill(-hx, hx + 1, y, y + 1, -hz, hz + 1, lambda x, yy, z: jitter(rng, shade(wall, 0.95), 0.03))
    for x in range(-hx, hx + 1):
        for z in (-hz, hz):
            b.put(x, y + 1, z, wall)
            if x % 3 == 0:
                b.put(x, y + 2, z, wall)
    for z in range(-hz, hz + 1):
        for x in (-hx, hx):
            b.put(x, y + 1, z, wall)
    for z in range(-hz + 4, hz - 3, 5):
        for k in range(1, 4):
            b.put(-hx - k, y - 3, z, (110, 76, 44))
    dome(b, rng, 9, y + 1, (250, 236, 210), squash=0.9)
    b.light(0, y + 10, 0, (255, 200, 120))
    # A striped cloth awning over the door.
    for x in range(-8, 9):
        for k in range(4):
            b.put(x, b.floor + 15 - k, -hz - 1 - k, (220, 80, 60) if (x // 2) % 2 else (250, 230, 200))
    return b


def sand_dome(rng):
    b = Building(8)
    r = 18
    plinth(b, rng, r, r, (190, 150, 100), round_=True)
    round_walls(b, rng, r, 12, (226, 186, 128), windows=5)
    dome(b, rng, r, b.floor + 12, (236, 200, 140), squash=0.85, glow_every=0)
    for k in range(8):
        a = k * math.tau / 8
        b.put(round(math.cos(a) * (r - 3)), b.floor + 12 + round((r - 3) * 0.6), round(math.sin(a) * (r - 3)), (90, 170, 160))
    b.light(0, b.floor + 12 + round(r * 0.85) + 1, 0, (255, 200, 100))
    return b


def stilt_hut(rng, wall=(160, 120, 80), roof=(196, 170, 100)):
    b = Building(4)
    hx, hz, h = 16, 14, 16
    lift = 22
    for sx in (-hx, -hx // 3, hx // 3, hx):
        for sz in (-hz, hz):
            for y in range(0, b.floor + lift):
                for dx in (0, 1):
                    for dz in (0, 1):
                        b.put(sx + dx - (1 if sx > 0 else 0), y, sz + dz - (1 if sz > 0 else 0), (110, 82, 56))
    b.floor += lift
    b.fill(-hx - 4, hx + 5, b.floor - 1, b.floor, -hz - 6, hz + 5, lambda x, y, z: jitter(rng, (150, 112, 74) if x % 4 else (130, 96, 64), 0.04))
    walls(b, rng, hx, hz, h, wall, timber=(110, 82, 56), door=(0, 5, 13))
    top = gable_roof(b, rng, hx, hz, b.floor + h, roof, over=4, gable_rgb=wall)
    # Ladder down from the porch, nets on the rail.
    for y in range(4, b.floor):
        for x in (-3, 3):
            b.put(x, y, -hz - 6, (110, 82, 56))
        if y % 3 == 0:
            for x in range(-3, 4):
                b.put(x, y, -hz - 6, (130, 96, 64))
    for x in range(-hx - 4, hx + 5):
        b.put(x, b.floor + 4, -hz - 6, (110, 82, 56))
    b.floor -= lift
    return b


def fisher_house(rng):
    b = moss_cottage(rng, roof=(60, 110, 160))
    return b


def crystal_hut(rng, color=(90, 220, 200)):
    b = Building(8)
    r = 16
    plinth(b, rng, r, r, (60, 70, 86), round_=True)
    round_walls(b, rng, r, 10, (70, 84, 104), windows=4, win_rgb=(140, 255, 230))
    # A faceted crystal roof: spikes rising from the walls.
    for k in range(14):
        a = k * math.tau / 14
        cx, cz = math.cos(a) * (r - 4), math.sin(a) * (r - 4)
        hh = 18 + (k * 7) % 11
        for y in range(hh):
            rr = 3.2 * (1 - y / hh) + 0.4
            for dx in range(-4, 5):
                for dz in range(-4, 5):
                    if abs(dx) + abs(dz) <= rr:
                        p = (round(cx + dx - math.cos(a) * y * 0.45), b.floor + 10 + y, round(cz + dz - math.sin(a) * y * 0.45))
                        if (dx + y) % 6 == 0:
                            b.light(*p, rgb=glow_every_color(color))
                        else:
                            b.put(*p, jitter(rng, shade(color, 0.7 + 0.4 * y / hh), 0.04))
    return b


def ruin_cottage(rng, stone_rgb=(150, 150, 156)):
    b = Building(8)
    hx, hz, h = 19, 16, 20
    plinth(b, rng, hx + 1, hz + 1, (110, 110, 116))
    walls(b, rng, hx, hz, h, stone_rgb, timber=(120, 120, 128), win_rgb=(140, 255, 150))
    # Broken: knock the top of the walls down in a ragged line, half a roof left.
    for p in list(b.v):
        x, y, z = p
        if y > b.floor + h - 9 + round(6 * math.sin(x * 0.3 + z * 0.2)) and (x + z) % 7 != 0 and x > -6:
            del b.v[p]
    top = b.floor + h
    for z in range(-hz - 2, hz + 3):
        for k in range(0, 10):
            if rng.random() < 0.88:
                b.put(-hx - 2 + k, top + k, z, jitter(rng, (90, 84, 90), 0.06))
    for p in list(b.v):  # ivy
        if p[1] < b.floor + 12 and rng.random() < 0.04:
            b.put(*p, (90, 120, 90))
    return b


def crypt(rng):
    b = Building(8)
    hx, hz, h = 16, 22, 18
    plinth(b, rng, hx + 2, hz + 2, (96, 96, 104))
    walls(b, rng, hx, hz, h, (130, 130, 138), timber=(100, 100, 108), windows=False, door=(0, 5, 14))
    top = gable_roof(b, rng, hx, hz, b.floor + h, (70, 72, 82), over=1, pitch=1.0, gable_rgb=(130, 130, 138))
    for y in range(top, top + 8):
        b.put(0, y, -hz, (150, 150, 158))
    for x in range(-3, 4):
        b.put(x, top + 5, -hz, (150, 150, 158))
    for x in (-hx - 2, hx + 2):
        lantern_pole(b, x, -hz - 3, b.floor, 10, (140, 255, 150), (50, 54, 60))
    return b


def spore_hut(rng, cap=(150, 70, 170)):
    b = mushroom_house(rng, cap)
    return b


def hive_house(rng):
    b = Building(6)
    r = 18
    for x in range(-r, r + 1):
        for z in range(-r, r + 1):
            for y in range(0, 2 * r + 8):
                d = math.sqrt(x * x + z * z + ((y - 10) / 1.4) ** 2)
                if r - 1.8 <= d <= r and y >= 0:
                    b.put(x, y, z, jitter(rng, (90, 54, 104) if (y // 4) % 2 else (110, 66, 124), 0.05))
    for k in range(24):  # glowing pores
        a = rng.uniform(0, math.tau)
        y = rng.randint(6, 28)
        d = math.sqrt(max(0, r * r - ((y - 10) / 1.4) ** 2))
        b.light(round(math.cos(a) * d), y, round(math.sin(a) * d), (255, 110, 230))
    for x in range(-4, 5):  # door hole
        for y in range(b.floor, b.floor + 12):
            for z in range(-r - 1, -r + 4):
                if (x, y, z) in b.v:
                    b.put(x, y, z, (40, 20, 50))
    return b


def obsidian_hut(rng):
    b = Building(8)
    hx, hz, h = 17, 15, 20
    plinth(b, rng, hx + 2, hz + 2, (30, 32, 42))
    walls(b, rng, hx, hz, h, (44, 46, 60), timber=(70, 76, 100), win_rgb=(150, 180, 255))
    y = b.floor + h
    # A stepped pyramid roof with a storm crystal on top.
    for k in range(10):
        half_x, half_z = hx + 2 - k * 2, hz + 2 - k * 2
        if half_x < 2 or half_z < 2:
            break
        for x in range(-half_x, half_x + 1):
            for z in range(-half_z, half_z + 1):
                if abs(x) >= half_x - 1 or abs(z) >= half_z - 1:
                    b.put(x, y + k, z, jitter(rng, (36, 38, 50), 0.05))
    for yy in range(y + 8, y + 18):
        b.light(0, yy, 0, (150, 180, 255))
    return b


def obsidian_hall(rng):
    b = obsidian_hut(rng)
    for x in (-24, 24):
        for y in range(b.floor, b.floor + 34):
            for dx in range(-2, 3):
                for dz in range(-2, 3):
                    b.put(x + dx, y, -20 + dz, (40, 42, 56))
        for yy in range(b.floor + 34, b.floor + 38):
            b.light(x, yy, -20, (255, 90, 110))
    return b


# --- Landmarks -------------------------------------------------------------------------

def lighthouse(rng):
    b = Building(10)
    r = 18
    plinth(b, rng, 26, 26, (120, 124, 130), round_=True, flare=4)
    # Keeper's cottage at the foot, the striped tower rising out of it.
    for y in range(b.floor, b.floor + 150):
        rr = r - y * 0.05
        for x in range(-r - 1, r + 2):
            for z in range(-r - 1, r + 2):
                d = math.hypot(x, z)
                if rr - 1.5 <= d <= rr:
                    band = ((y - b.floor) // 16) % 2
                    b.put(x, y, z, jitter(rng, (236, 232, 222) if band else (200, 60, 54), 0.03))
        if (y - b.floor) % 30 == 15:
            b.light(0, y, -round(rr), (255, 210, 130))
    top = b.floor + 150
    for x in range(-r - 2, r + 3):  # gallery
        for z in range(-r - 2, r + 3):
            if math.hypot(x, z) <= r + 2:
                b.put(x, top, z, (60, 64, 70))
            if r + 0.6 <= math.hypot(x, z) <= r + 2:
                b.put(x, top + 4, z, (60, 64, 70))
                if (x + z) % 3 == 0:
                    for yy in range(top + 1, top + 4):
                        b.put(x, yy, z, (60, 64, 70))
    for y in range(top + 1, top + 16):  # lantern room
        for x in range(-10, 11):
            for z in range(-10, 11):
                d = math.hypot(x, z)
                if d <= 7:
                    if d >= 5.6:
                        if (round(math.degrees(math.atan2(z, x))) // 45) % 2 == 0 and y < top + 14:
                            b.put(x, y, z, (50, 54, 60))
                        else:
                            b.light(x, y, z, (255, 236, 160))
                    elif d < 3 and top + 4 < y < top + 12:
                        b.light(x, y, z, (255, 246, 200))
    cone_roof(b, rng, 8, top + 16, 10, (200, 60, 54), over=1)
    return b


def lantern_tower(rng):
    b = Building(10)
    hx = 14
    plinth(b, rng, hx + 2, hx + 2, (186, 146, 100))
    for y in range(b.floor, b.floor + 150):
        w = hx - (y - b.floor) // 40
        for x in range(-w, w + 1):
            for z in range(-w, w + 1):
                if abs(x) == w or abs(z) == w:
                    b.put(x, y, z, jitter(rng, (222, 178, 120) if (y // 6) % 4 else (196, 150, 96), 0.04))
        if (y - b.floor) % 24 == 12:
            for s in (-1, 1):
                for a in range(-2, 3):
                    b.light(a, y, s * w, (255, 190, 90))
                    b.light(s * w, y, a, (255, 190, 90))
    top = b.floor + 150
    for k in range(4):  # lantern cages hanging off each side
        a = k * math.pi / 2
        lx, lz = round(math.cos(a) * (hx + 3)), round(math.sin(a) * (hx + 3))
        for yy in range(top - 22, top - 2):
            b.put(round(math.cos(a) * hx), yy if yy == top - 3 else top - 3, round(math.sin(a) * hx), (110, 80, 50))
        for dx in (-1, 0, 1):
            for dz in (-1, 0, 1):
                for yy in range(top - 12, top - 6):
                    b.light(lx + dx, yy, lz + dz, (255, 180, 70))
    dome(b, rng, 11, top, (250, 220, 150), squash=1.1)
    b.light(0, top + 13, 0, (255, 200, 90))
    return b


def observatory(rng):
    b = Building(10)
    r = 34
    plinth(b, rng, r + 2, r + 2, (100, 102, 110), round_=True, flare=4)
    round_walls(b, rng, r, 34, (150, 150, 158), windows=8, win_rgb=(140, 255, 150), bands=[(150, 150, 158), (130, 132, 140)])
    # The dome, broken open on one side, a brass telescope poking out.
    base = b.floor + 34
    for x in range(-r, r + 1):
        for z in range(-r, r + 1):
            for y in range(0, r + 1):
                d = math.sqrt(x * x + z * z + y * y)
                if r - 1.5 <= d <= r:
                    broken = x > 6 and z < 0 and y > 8 + 6 * math.sin(z * 0.4)
                    if not broken:
                        b.put(x, base + y, z, jitter(rng, (110, 120, 140) if (x // 6 + z // 6) % 2 else (96, 104, 124), 0.04))
    for s in range(60):
        t = s / 60
        p = (round(4 + t * 34), round(base + 6 + t * 30), round(-4 - t * 20))
        for dx in (-2, -1, 0, 1, 2):
            for dy in (-2, -1, 0, 1, 2):
                if dx * dx + dy * dy <= 5 - (1 if t > 0.7 else 0):
                    b.put(p[0], p[1] + dy, p[2] + dx, (200, 160, 90) if s % 10 else (150, 110, 60))
    b.light(38, base + 37, -24, (160, 255, 170))
    return b


def treehouse(rng):
    """A giant mossy tree holding a round house on a ring deck (0.25 m)."""
    b = Building(4)
    T(1.0)
    v = {}
    pal = b.pal
    moss_bark = lambda x, y, z: pal((86, 128, 58) if rng.random() < 0.25 else shade((92, 68, 46), rng.choice((0.85, 1.0, 1.1))))
    top = trunk(v, 70, 7.0, 5.0, moss_bark, rng)
    for p, c in v.items():
        b.v[(p[0], p[1] + b.floor, p[2])] = c
    deck = b.floor + 40
    for x in range(-22, 23):
        for z in range(-22, 23):
            d = math.hypot(x, z)
            if 6 <= d <= 22:
                b.put(x, deck, z, (150, 108, 70) if (x + z) % 4 else (128, 92, 60))
            if 20.6 <= d <= 22 and (x + z) % 3 == 0:
                for yy in range(deck + 1, deck + 5):
                    b.put(x, yy, z, (110, 80, 50))
    b.floor = deck + 1
    round_walls(b, rng, 12, 14, (200, 170, 120), windows=6)
    cone_roof(b, rng, 12, b.floor + 14, 12, (90, 140, 70), over=3)
    leaves = leaf_color(pal, (70, 140, 60), rng)
    for k in range(7):
        a = k * math.tau / 7
        cx, cz = math.cos(a) * 16, math.sin(a) * 16
        blob(b.v, cx, b.floor + 34 + rng.uniform(-3, 4), cz, 12, 8, 12, leaves, rng, 0.3)
    blob(b.v, 0, b.floor + 44, 0, 14, 9, 14, leaves, rng, 0.3)
    for p in list(b.v):
        if p[1] > b.floor + 26 and rng.random() < 0.005:
            del b.v[p]
            b.glow[p] = pal((200, 255, 160))
    # A spiral stair round the trunk.
    for s in range(0, 40):
        a = s * 0.35
        for w in range(7, 11):
            b.put(round(math.cos(a) * w), 4 + s, round(math.sin(a) * w), (150, 108, 70))
    b.floor = 4
    return b


def rose_shrine(rng):
    b = Building(8)
    plinth(b, rng, 22, 22, (220, 200, 214), round_=True)
    f = b.floor
    for x in (-14, 14):  # arch pillars
        for y in range(f, f + 50):
            for dx in range(-3, 4):
                for dz in range(-3, 4):
                    b.put(x + dx, y, dz, jitter(rng, (236, 220, 232), 0.03))
    for s in range(0, 61):
        a = math.pi * s / 60
        x, y = round(-math.cos(a) * 14), round(f + 50 + math.sin(a) * 14)
        for dx in range(-2, 3):
            for dz in range(-3, 4):
                b.put(x + dx, y, dz, jitter(rng, (236, 220, 232), 0.03))
    for y in range(f, f + 30):  # the crystal heart
        rr = 6 * (1 - abs(y - f - 15) / 16)
        for x in range(-6, 7):
            for z in range(-6, 7):
                if abs(x) + abs(z) <= rr:
                    b.light(x, y, z + 8, (255, 140, 210)) if (x + y) % 4 == 0 else b.put(x, y, z + 8, (240, 130, 190))
    for p in list(b.v):  # climbing roses
        if rng.random() < 0.05 and abs(p[0]) > 10:
            b.put(p[0], p[1], p[2], (226, 64, 110) if rng.random() < 0.5 else (80, 140, 80))
    return b


def crystal_hall(rng):
    b = crystal_hut(rng, (90, 230, 200))
    return b


def hive_spire(rng):
    b = Building(6)
    for y in range(0, 190):
        t = y / 190
        r = 22 * (1 - t) ** 0.8 + 2 + 3 * math.sin(y * 0.15)
        for x in range(-28, 29):
            for z in range(-28, 29):
                d = math.hypot(x, z)
                if r - 2 <= d <= r:
                    if rng.random() < 0.01:
                        b.light(x, y, z, (255, 100, 220))
                    else:
                        b.put(x, y, z, jitter(rng, (90, 54, 104) if (y // 5) % 2 else (70, 40, 84), 0.05))
    return b


def storm_tower(rng):
    b = Building(10)
    hx = 14
    plinth(b, rng, hx + 3, hx + 3, (30, 32, 42))
    for y in range(b.floor, b.floor + 170):
        w = hx - (y - b.floor) // 30
        if w < 3:
            break
        for x in range(-w, w + 1):
            for z in range(-w, w + 1):
                if abs(x) == w or abs(z) == w:
                    if (y - b.floor) % 20 == 10 and abs(x + z) % 5 == 0:
                        b.light(x, y, z, (150, 180, 255))
                    else:
                        b.put(x, y, z, jitter(rng, (40, 42, 56), 0.05))
    top = b.floor + 170
    for y in range(top - 10, top + 30):
        b.put(0, y, 0, (90, 96, 112))
    for y in range(top + 30, top + 36):
        b.light(0, y, 0, (255, 90, 110))
    return b


def market_stall(rng, cloth=(220, 80, 60)):
    b = Building(2)
    hx, hz = 14, 9
    b.fill(-hx, hx + 1, 0, b.floor, -hz, hz + 1, (120, 110, 100))
    f = b.floor
    for x in (-hx, hx):
        for z in (-hz, hz):
            for y in range(f, f + 24):
                b.put(x, y, z, (110, 80, 50))
    b.fill(-hx + 1, hx, f, f + 8, -hz + 2, -hz + 5, lambda x, y, z: jitter(rng, (150, 108, 70), 0.05))
    for x in range(-hx + 2, hx - 1, 2):  # wares on the counter
        b.put(x, f + 8, -hz + 3, rng.choice([(240, 200, 80), (200, 60, 50), (120, 180, 80), (250, 150, 60)]))
    for x in range(-hx - 2, hx + 3):
        for k in range(0, 2 * hz + 5):
            y = f + 26 - abs(k - hz - 2) // 3
            b.put(x, y, -hz - 2 + k, cloth if (x // 3) % 2 else (250, 236, 210))
    b.light(-hx + 2, f + 22, -hz, (255, 190, 100))
    return b


def well(rng, stone_rgb=(140, 136, 128), roof=(120, 70, 50)):
    b = Building(2)
    f = b.floor
    for x in range(-9, 10):
        for z in range(-9, 10):
            d = math.hypot(x, z)
            for y in range(0, f + 7):
                if 6 <= d <= 9 or (y < f and d < 9):
                    b.put(x, y, z, jitter(rng, stone_rgb, 0.06))
            if d < 6:
                b.put(x, f + 2, z, (60, 120, 170))
    for x in (-7, 7):
        for y in range(f + 7, f + 22):
            b.put(x, y, 0, (110, 80, 50))
    for x in range(-11, 12):
        for k in range(-7, 8):
            b.put(x, f + 22 + (7 - abs(k)) // 2, k, roof)
    b.light(0, f + 18, 0, (255, 200, 110))
    return b


def lamp(rng, glow=(255, 196, 110), iron=(60, 52, 48)):
    b = Building(2)
    b.fill(-2, 3, 0, b.floor + 1, -2, 3, (90, 88, 86))
    lantern_pole(b, 0, 0, b.floor, 26, glow, iron)
    return b


def plaza(rng, stone_rgb=(150, 146, 136), ring=(214, 170, 90)):
    """A round paved plaza (0.25 m voxels, 36 m across) on a thick footing."""
    b = Building(10)
    r = 72
    for x in range(-r - 3, r + 4):
        for z in range(-r - 3, r + 4):
            d = math.hypot(x, z)
            for y in range(b.floor):
                grow = (b.floor - 1 - y) * 0.3
                if d <= r + grow and (y == b.floor - 1 or d >= r + grow - 1.5):
                    if y == b.floor - 1:
                        ring_band = r - 4 <= d <= r - 2 or 30 <= d <= 31.5
                        tile = (x // 6 + z // 6) % 2
                        b.put(x, y, z, ring if ring_band else jitter(rng, stone_rgb if tile else shade(stone_rgb, 0.9), 0.05))
                    else:
                        b.put(x, y, z, jitter(rng, shade(stone_rgb, 0.8), 0.06))
    return b


def landing_pad(rng, deck=(150, 104, 70), rim=(214, 172, 100), base=(110, 104, 98), glow=(255, 200, 120), marks=(214, 172, 100)):
    """A round landing pad, 54 m across (0.25 m voxels), on a stone footing
    that flares down 4 m into the ground; brass rim, landing ring, lantern posts
    and the shipwright's crystal pedestal at (0, -21 m)."""
    b = Building(16)
    R = 108  # deck radius in voxels (27 m)
    f = b.floor
    for x in range(-R - 10, R + 11):
        for z in range(-R - 10, R + 11):
            d = math.hypot(x, z)
            if d > R + 9:
                continue
            for y in range(0, f):
                reach = R + (f - 1 - y) * 0.55
                if d > reach:
                    continue
                if y == f - 1:
                    if d >= R - 2:
                        c = rim
                    elif 84 <= d <= 86:
                        c = marks
                    elif abs(x) <= 1 and abs(z) <= 26 or abs(z) <= 1 and abs(x) <= 26:
                        c = marks
                    else:
                        plank = (z // 3) % 2
                        c = jitter(rng, deck if plank else shade(deck, 0.9), 0.04)
                        if x % 24 == 0:
                            c = shade(deck, 0.75)
                    b.put(x, y, z, c)
                elif d >= reach - 1.6:
                    b.put(x, y, z, jitter(rng, base if (x // 4 + y // 3 + z // 4) % 2 else shade(base, 0.88), 0.05))
    for k in range(48):  # rim studs that glow
        a = k * math.tau / 48
        b.light(round(math.cos(a) * (R - 4)), f, round(math.sin(a) * (R - 4)), glow)
    for k in range(8):  # lantern posts round the edge
        a = k * math.tau / 8 + 0.2
        lantern_pole(b, round(math.cos(a) * (R - 12)), round(math.sin(a) * (R - 12)), f, 14, glow)
    # The crystal pedestal (the crystal itself is drawn by the game, it glows).
    for x in range(-5, 6):
        for z in range(-5, 6):
            if x * x + z * z <= 25:
                for y in range(f, f + 4):
                    b.put(x, y, z - 84, rim if y == f + 3 else shade(rim, 0.8))
    return b


# --- The Nexus ---------------------------------------------------------------------------

def nexus_deck(rng):
    """The station deck: a round timber floor 103 m across (0.5 m voxels) on a
    thick beam frame; planks run in rows like the old deck."""
    b = Building(4)
    R = 103  # half voxels (51.5 m)
    wood = (139, 88, 58)
    for x in range(-R, R + 1):
        for z in range(-R, R + 1):
            d = math.hypot(x, z)
            if d > R:
                continue
            for y in range(0, b.floor):
                if y == b.floor - 1:
                    row = (z + 200) // 2
                    seam = (x + row * 7) % 11 == 0
                    c = shade(wood, 0.78) if seam else jitter(rng, shade(wood, 1.0 + 0.05 * ((row * 3) % 5 - 2)), 0.03)
                    if d >= R - 1.2:
                        c = (66, 48, 45)
                    b.put(x, y, z, c)
                elif d >= R - 1.5:
                    b.put(x, y, z, (66, 48, 45) if y % 2 else (82, 58, 50))
    return b


def nexus_bar(rng):
    """The Lantern Bar's shell (walls, posts, windows frames, pitched roof);
    the station draws its furniture. Station space: x -14.5..14.5, z -35..-19."""
    b = Building(1)
    wood, dark, roof = (119, 81, 59), (60, 44, 40), (76, 101, 95)
    f = b.floor
    hx, z0, z1 = 116, -64, 64  # 0.125 m voxels, the bar's own centre (station z = -27)
    for x in range(-hx, hx + 1):  # back wall
        for y in range(f, f + 30):
            for z in (z0, z0 + 1):
                b.put(x, y, z, jitter(rng, dark if (x // 8) % 2 else shade(dark, 1.1), 0.03))
    for side in (-1, 1):
        x = side * hx
        for z in range(z0, z1 + 1):
            for y in range(f, f + 30):
                low = y < f + 9
                high = y >= f + 22
                post = (z - z0) % 30 < 2
                if low or high or post:
                    b.put(x, y, z, wood if low or post else dark)
                    b.put(x - side, y, z, wood if low or post else dark)
        # Front wall: low sill, header, posts; a door gap in the middle.
    for x in range(-hx, hx + 1):
        if abs(x) <= 13:
            for y in range(f + 22, f + 30):
                b.put(x, y, z1, dark)
            continue
        for y in range(f, f + 30):
            low = y < f + 8
            high = y >= f + 22
            post = (abs(x) - 13) % 36 < 2
            if low or high or post:
                b.put(x, y, z1, wood if low or post else dark)
    # Pitched roof: two slopes meeting at a ridge over x = 0.
    for x in range(-hx - 4, hx + 5):
        y = f + 44 - round(abs(x) * 0.106)
        for z in range(z0 - 4, z1 + 5):
            b.put(x, y, z, jitter(rng, shade(roof, 1.06 if (abs(x) // 12) % 2 else 0.96), 0.03))
            b.put(x, y - 1, z, shade(roof, 0.8))
    for x in range(-hx, hx + 1):  # gable fill above the walls
        top = f + 43 - round(abs(x) * 0.106)
        for y in range(f + 30, top):
            b.put(x, y, z0, dark)
            b.put(x, y, z1, wood if (x // 4) % 2 else shade(wood, 0.9))
    for z in range(z0 - 4, z1 + 5):
        b.put(0, f + 45, z, dark)
    for x in range(-hx + 8, hx - 7, 24):  # lanterns under the eaves
        b.light(x, f + 27, z1 - 2, (255, 206, 140))
    return b


def nexus_lantern_tree(rng):
    b = Building(2)
    f = b.floor
    b.fill(-5, 6, 0, f + 2, -5, 6, (78, 66, 80))
    for y in range(f + 2, f + 26):
        for dx in (-1, 0, 1):
            for dz in (-1, 0, 1):
                b.put(dx, y, dz, (139, 88, 58))
    for side in (-1, 1):
        for x in range(0, 8):
            b.put(side * x, f + 24, 0, (217, 172, 96))
        for y in range(f + 15, f + 23):
            b.put(side * 7, y, 0, (60, 44, 40))
        for dx in (-2, -1, 0, 1, 2):
            for dz in (-2, -1, 0, 1, 2):
                for y in range(f + 13, f + 18):
                    edge = abs(dx) == 2 or abs(dz) == 2
                    if edge:
                        if abs(dx) == 2 and abs(dz) == 2 or y in (f + 13, f + 17):
                            b.put(side * 7 + dx, y, dz, (148, 112, 74))
                    else:
                        b.light(side * 7 + dx, y, dz, (255, 207, 131))
    # Leaves: a small round crown of glowing green and pink buds.
    for p in [(0, f + 28, 0)]:
        for dx in range(-4, 5):
            for dz in range(-4, 5):
                for dy in range(-2, 4):
                    if dx * dx + dz * dz + dy * dy * 2 <= 18:
                        if rng.random() < 0.15:
                            b.light(dx, p[1] + dy, dz, (133, 239, 172) if rng.random() < 0.6 else (239, 156, 207))
                        else:
                            b.put(dx, p[1] + dy, dz, jitter(rng, (79, 122, 74), 0.08))
    return b


def nexus_bench(rng):
    b = Building(1)
    f = b.floor
    wood = (139, 88, 58)
    b.fill(-11, 12, f + 3, f + 5, -3, 4, lambda x, y, z: jitter(rng, wood if (z + 10) % 3 else shade(wood, 0.85), 0.04))
    b.fill(-11, 12, f + 5, f + 12, 3, 5, lambda x, y, z: jitter(rng, shade(wood, 0.85), 0.04))
    for x in (-9, 9):
        b.fill(x, x + 2, 0, f + 3, -2, 3, (66, 48, 45))
    return b


def nexus_barrel(rng):
    b = Building(1)
    for y in range(0, 11):
        r = 4.2 + math.sin(y / 10 * math.pi) * 0.8
        for x in range(-5, 6):
            for z in range(-5, 6):
                d = math.hypot(x, z)
                if d <= r and (d >= r - 1.2 or y in (0, 10)):
                    band = y in (2, 8)
                    b.put(x, y, z, (217, 172, 96) if band else jitter(rng, (122, 74, 44) if (round(math.atan2(z, x) * 4)) % 2 else (108, 66, 40), 0.03))
    return b


def nexus_crate(rng):
    b = Building(0)
    for x in range(-4, 5):
        for y in range(0, 9):
            for z in range(-4, 5):
                edge = (abs(x) == 4) + (y in (0, 8)) + (abs(z) == 4) >= 2
                shell = abs(x) == 4 or y in (0, 8) or abs(z) == 4
                if shell:
                    b.put(x, y, z, (66, 48, 45) if edge else jitter(rng, (160, 112, 63), 0.05))
    return b


def nexus_planter(rng):
    b = Building(0)
    b.fill(-9, 9, 0, 7, -4, 4, lambda x, y, z: (66, 48, 45) if y == 6 or abs(x) == 8 else jitter(rng, (118, 76, 50), 0.04))
    for k in range(9):
        x, z = rng.randint(-7, 6), rng.randint(-3, 2)
        for y in range(7, 7 + rng.randint(2, 4)):
            b.put(x, y, z, (95, 174, 110))
        c = (239, 156, 207) if k % 2 else (255, 224, 143)
        for dx in (-1, 0, 1):
            for dz in (-1, 0, 1):
                if abs(dx) + abs(dz) < 2:
                    b.put(x + dx, 10, z + dz, c)
    return b


def nexus_stall(rng, cloth=(133, 239, 172)):
    b = market_stall(rng, cloth)
    for x in range(-10, 11, 4):
        for y in range(b.floor + 8, b.floor + 12):
            b.light(x, y, -6, (133, 239, 172) if x % 8 else (239, 156, 207))
    return b


def nexus_board(rng):
    b = Building(0)
    for x in (-15, 15):
        b.fill(x - 2, x + 2, 0, 33, -2, 2, (66, 48, 45))
    b.fill(-19, 20, 14, 38, -2, 2, lambda x, y, z: jitter(rng, (139, 88, 58), 0.04))
    for k in range(4):
        x0 = -14 + k * 8
        y0 = 18 + (k % 2) * 3
        b.fill(x0, x0 + 6, y0, y0 + 12, -3, -2, (255, 228, 173))
        for yy in range(y0 + 2, y0 + 11, 2):
            for xx in range(x0 + 1, x0 + 5):
                if rng.random() < 0.7:
                    b.put(xx, yy, -3, (110, 80, 60))
    for x in range(-20, 21):
        b.put(x, 38, -2, (217, 172, 96))
        b.put(x, 38, 1, (217, 172, 96))
    return b


def nexus_chart_table(rng):
    b = Building(0)
    for y in range(0, 8):
        for x in range(-2, 3):
            for z in range(-2, 3):
                b.put(x, y, z, (66, 48, 45))
    for x in range(-6, 7):
        for z in range(-6, 7):
            if x * x + z * z <= 30:
                b.put(x, 0, z, (66, 48, 45))
    for x in range(-11, 12):
        for z in range(-11, 12):
            d = math.hypot(x, z)
            if d <= 11:
                b.put(x, 8, z, (139, 88, 58))
                if d <= 9.6:
                    b.put(x, 9, z, (37, 63, 76))
                if d >= 10.4:
                    b.put(x, 9, z, (217, 172, 96))
    for k in range(18):
        a = k * 2.39996
        r = math.sqrt(k / 18) * 8.5
        b.light(round(math.cos(a) * r), 10, round(math.sin(a) * r), (133, 239, 172) if k % 3 else (239, 156, 207))
    return b


def nexus_hearth(rng):
    b = Building(0)
    stone_rgb = (106, 86, 96)
    for x in range(-22, 23):
        for z in range(-22, 23):
            d = math.hypot(x, z)
            if d <= 22:
                for y in range(0, 8):
                    if d >= 18 or y == 0:
                        b.put(x, y, z, jitter(rng, stone_rgb if (x // 3 + y // 2 + z // 3) % 2 else shade(stone_rgb, 1.12), 0.05))
                if d < 18:
                    b.light(x, 7, z, (40, 140, 80)) if rng.random() < 0.3 else b.put(x, 7, z, (29, 42, 36))
            if 19 <= d <= 22.5 and (round(math.atan2(z, x) * 5)) % 2 == 0:
                b.put(x, 8, z, shade(stone_rgb, 1.15))
    for k in range(3):  # logs
        a = k * math.pi / 3
        for s in range(-12, 13):
            for w in (-1, 0, 1):
                for h in (0, 1):
                    b.put(round(math.cos(a) * s - math.sin(a) * w), 8 + h, round(math.sin(a) * s + math.cos(a) * w), (74, 46, 33))
    for k in range(6):  # crystals round the rim
        a = (k + 0.5) * math.tau / 6
        cx, cz = round(math.cos(a) * 23), round(math.sin(a) * 23)
        for y in range(0, 10 + (k % 2) * 4):
            rr = 2.2 * (1 - y / 14)
            for dx in range(-2, 3):
                for dz in range(-2, 3):
                    if abs(dx) + abs(dz) <= rr:
                        b.light(cx + dx, y, cz + dz, (133, 239, 172) if k % 3 else (239, 156, 207))
    return b


def nexus_gate(rng):
    """The timber gate and arch at the end of a boarding walk."""
    b = Building(0)
    wood, dark, brass = (139, 88, 58), (66, 48, 45), (217, 172, 96)
    for x in (-21, 21):
        b.fill(x - 1, x + 2, 0, 22, -1, 2, dark)
        b.fill(x - 2, x + 3, 22, 24, -2, 3, brass)
    for y in (3, 9, 15):
        b.fill(-20, 21, y, y + 1, -1, 1, wood)
    for k in range(9):
        x = -16 + k * 4
        b.fill(x, x + 1, 1, 16, 0, 1, jitter(rng, shade(wood, 1.1), 0.04))
        b.put(x, 16, 0, brass)
    b.fill(-23, 24, 25, 28, -2, 2, shade(wood, 0.85))
    b.fill(-13, 14, 28, 29, -1, 1, brass)
    for y in (20, 21, 22, 23, 24):
        b.put(0, y, 0, dark)
    for dx in (-1, 0, 1):
        for dz in (-1, 0, 1):
            for y in range(16, 20):
                if abs(dx) + abs(dz) < 2:
                    b.light(dx, y, dz, (255, 207, 131))
                else:
                    b.put(dx, y, dz, (148, 112, 74))
    return b


def nexus_rail(rng):
    """One straight rail section (3.5 m) of the deck's edge."""
    b = Building(0)
    for x in (-1, 0):
        b.fill(x, x + 1, 0, 19, -1, 1, (217, 172, 96))
    for y in (5, 17):
        b.fill(-14, 14, y, y + 1, -1, 1, (139, 88, 58))
    for x in range(-12, 12, 4):
        b.fill(x, x + 1, 6, 17, 0, 1, shade((139, 88, 58), 0.85))
    return b


def nexus_lamp(rng):
    return lamp(rng, (255, 207, 131), (66, 48, 45))


# --- Writing ---------------------------------------------------------------------------

def write_prop(folder, name, b, voxel_size=0.125, kind="house"):
    """Writes props/<folder>/<name>/ and adds it to the catalog."""
    path = os.path.join(ROOT, "props", folder, name)
    os.makedirs(path, exist_ok=True)
    allv = dict(b.v)
    allv.update(b.glow)
    xs = [p[0] for p in allv]
    zs = [p[2] for p in allv]
    ys = [p[1] for p in allv]
    assert min(ys) >= 0, f"{name}: voxels below 0"
    hx = max(-min(xs), max(xs) + 1)
    hz = max(-min(zs), max(zs) + 1)
    sy = max(ys) + 1
    assert max(hx * 2, hz * 2, sy) <= 256, f"{name}: too big {hx * 2} x {sy} x {hz * 2}"
    for part, voxels in (("body", b.v), ("body_glow", b.glow)):
        file = os.path.join(path, part + ".vox")
        if not voxels:
            if os.path.exists(file):
                os.remove(file)
            continue
        write_vox_framed(file, voxels, b.pal.colors, hx, hz, sy)
    rig = {"voxel_size": voxel_size, "parts": {"body": {"frame_min": [-hx, 0, -hz], "glow": bool(b.glow)}}, "limbs": {},
           "hand": [0, 0, 0], "waddle": 0}
    with open(os.path.join(path, "rig.json"), "w") as f:
        json.dump(rig, f, indent=2)
    # Solid footprint: the walls' extent (no overhangs), from the floor up.
    body = [p for p in b.v if p[1] == b.floor] or list(b.v)
    fx = max(abs(p[0]) for p in body) + 1
    fz = max(abs(p[2]) for p in body) + 1
    key = f"{folder}/{name}"
    CATALOG[key] = {"size": [round(hx * 2 * voxel_size, 2), round(sy * voxel_size, 2), round(hz * 2 * voxel_size, 2)],
                    "foot": [round(fx * 2 * voxel_size, 2), round(fz * 2 * voxel_size, 2)],
                    "sink": round(b.floor * voxel_size, 3), "voxel": voxel_size, "kind": kind}
    print(f"props/{key}: {len(b.v)} + {len(b.glow)} glow voxels, {hx * 2} x {sy} x {hz * 2}")


BUILDINGS = {
    # name: (builder, voxel size, kind)
    "moss_cottage": (lambda r: moss_cottage(r), 0.125, "house"),
    "moss_cottage_blue": (lambda r: moss_cottage(r, (70, 110, 150)), 0.125, "house"),
    "mushroom_house": (lambda r: mushroom_house(r), 0.125, "house"),
    "mushroom_house_teal": (lambda r: mushroom_house(r, (60, 160, 140)), 0.125, "house"),
    "petal_cottage": (lambda r: petal_cottage(r), 0.125, "house"),
    "petal_cottage_lilac": (lambda r: petal_cottage(r, (236, 222, 250), (150, 110, 210)), 0.125, "house"),
    "fairy_tower": (fairy_tower, 0.125, "house"),
    "adobe_house": (lambda r: adobe_house(r), 0.125, "house"),
    "adobe_house_rose": (lambda r: adobe_house(r, (226, 160, 130)), 0.125, "house"),
    "sand_dome": (sand_dome, 0.125, "house"),
    "stilt_hut": (lambda r: stilt_hut(r), 0.125, "house"),
    "stilt_hut_blue": (lambda r: stilt_hut(r, (120, 150, 170), (190, 166, 100)), 0.125, "house"),
    "fisher_house": (fisher_house, 0.125, "house"),
    "crystal_hut": (lambda r: crystal_hut(r), 0.125, "house"),
    "crystal_hut_pink": (lambda r: crystal_hut(r, (250, 130, 220)), 0.125, "house"),
    "ruin_cottage": (lambda r: ruin_cottage(r), 0.125, "house"),
    "crypt": (crypt, 0.125, "house"),
    "spore_hut": (lambda r: spore_hut(r), 0.125, "house"),
    "hive_house": (hive_house, 0.125, "house"),
    "obsidian_hut": (obsidian_hut, 0.125, "house"),
    "obsidian_hall": (obsidian_hall, 0.125, "house"),
    # Landmarks
    "lighthouse": (lighthouse, 0.125, "landmark"),
    "lantern_tower": (lantern_tower, 0.125, "landmark"),
    "observatory": (observatory, 0.125, "landmark"),
    "treehouse": (treehouse, 0.25, "landmark"),
    "rose_shrine": (rose_shrine, 0.125, "landmark"),
    "crystal_hall": (crystal_hall, 0.25, "landmark"),
    "hive_spire": (hive_spire, 0.125, "landmark"),
    "storm_tower": (storm_tower, 0.125, "landmark"),
    # Town pieces
    "market_stall_red": (lambda r: market_stall(r), 0.125, "stall"),
    "market_stall_blue": (lambda r: market_stall(r, (70, 110, 200)), 0.125, "stall"),
    "market_stall_green": (lambda r: market_stall(r, (80, 160, 90)), 0.125, "stall"),
    "market_stall_violet": (lambda r: market_stall(r, (160, 80, 180)), 0.125, "stall"),
    "well": (lambda r: well(r), 0.125, "well"),
    "well_sand": (lambda r: well(r, (206, 166, 116), (180, 80, 60)), 0.125, "well"),
    "well_dark": (lambda r: well(r, (70, 72, 84), (50, 52, 64)), 0.125, "well"),
    "lamp_warm": (lambda r: lamp(r), 0.125, "lamp"),
    "lamp_green": (lambda r: lamp(r, (140, 255, 150), (50, 54, 60)), 0.125, "lamp"),
    "lamp_pink": (lambda r: lamp(r, (255, 150, 220), (120, 80, 110)), 0.125, "lamp"),
    "lamp_violet": (lambda r: lamp(r, (255, 110, 230), (60, 40, 70)), 0.125, "lamp"),
    "lamp_storm": (lambda r: lamp(r, (150, 180, 255), (40, 42, 56)), 0.125, "lamp"),
    "lamp_teal": (lambda r: lamp(r, (140, 255, 230), (50, 60, 70)), 0.125, "lamp"),
    "plaza_stone": (lambda r: plaza(r), 0.25, "plaza"),
    "plaza_sand": (lambda r: plaza(r, (214, 178, 126), (180, 90, 60)), 0.25, "plaza"),
    "plaza_rose": (lambda r: plaza(r, (232, 206, 222), (240, 130, 190)), 0.25, "plaza"),
    "plaza_dark": (lambda r: plaza(r, (80, 82, 96), (150, 180, 255)), 0.25, "plaza"),
    "plaza_moon": (lambda r: plaza(r, (130, 132, 140), (140, 255, 150)), 0.25, "plaza"),
    "plaza_violet": (lambda r: plaza(r, (90, 66, 104), (255, 110, 230)), 0.25, "plaza"),
    "plaza_crystal": (lambda r: plaza(r, (64, 80, 100), (90, 230, 200)), 0.25, "plaza"),
    # Landing pads
    "pad_timber": (lambda r: landing_pad(r), 0.25, "pad"),
    "pad_stone": (lambda r: landing_pad(r, (120, 122, 130), (140, 255, 150), (80, 82, 90), (140, 255, 150), (110, 170, 120)), 0.25, "pad"),
    "pad_obsidian": (lambda r: landing_pad(r, (50, 52, 68), (150, 180, 255), (30, 32, 42), (150, 180, 255), (100, 120, 200)), 0.25, "pad"),
    "pad_crystal": (lambda r: landing_pad(r, (60, 76, 96), (90, 230, 200), (40, 50, 64), (140, 255, 230), (90, 230, 200)), 0.25, "pad"),
    "pad_fungal": (lambda r: landing_pad(r, (96, 64, 110), (255, 110, 230), (60, 40, 70), (255, 110, 230), (200, 100, 200)), 0.25, "pad"),
    "pad_sand": (lambda r: landing_pad(r, (200, 160, 110), (214, 172, 100), (170, 130, 90), (255, 190, 90), (180, 90, 60)), 0.25, "pad"),
    "pad_rose": (lambda r: landing_pad(r, (226, 190, 206), (240, 130, 190), (190, 160, 180), (255, 160, 220), (240, 130, 190)), 0.25, "pad"),
}

NEXUS = {
    "deck": (nexus_deck, 0.5, "deck"),
    "bar": (nexus_bar, 0.125, "house"),
    "lantern_tree": (nexus_lantern_tree, 0.125, "prop"),
    "bench": (nexus_bench, 0.125, "prop"),
    "barrel": (nexus_barrel, 0.125, "prop"),
    "crate": (nexus_crate, 0.125, "prop"),
    "planter": (nexus_planter, 0.125, "prop"),
    "stall_green": (lambda r: nexus_stall(r), 0.125, "prop"),
    "stall_pink": (lambda r: nexus_stall(r, (239, 156, 207)), 0.125, "prop"),
    "board": (nexus_board, 0.125, "prop"),
    "chart_table": (nexus_chart_table, 0.125, "prop"),
    "hearth": (nexus_hearth, 0.125, "prop"),
    "gate": (nexus_gate, 0.125, "prop"),
    "rail": (nexus_rail, 0.125, "prop"),
    "lamp": (nexus_lamp, 0.125, "prop"),
}


if __name__ == "__main__":
    only = set(sys.argv[1:])
    out = os.path.join(ROOT, "obstacles", "planet")
    os.makedirs(out, exist_ok=True)
    for name, fn in FLORA.items():
        if only and name not in only:
            continue
        T(1.75 if name in TREES else 1.0)
        v, pal = fn(random.Random("planet:" + name))
        frame, size = write_vox(os.path.join(out, name + ".vox"), v, pal.colors)
        print(f"obstacles/planet/{name}: {len(v)} voxels {size}")
    for folder, table in (("planet", BUILDINGS), ("nexus", NEXUS)):
        for name, (fn, size, kind) in table.items():
            if only and name not in only:
                continue
            T(1.0)
            write_prop(folder, name, fn(random.Random(folder + ":" + name)), size, kind)
    if not only:
        with open(os.path.join(ROOT, "props", "planet", "catalog.json"), "w") as f:
            json.dump(CATALOG, f, indent=1, sort_keys=True)
        print(f"{len(CATALOG)} buildings in props/planet/catalog.json")
