#!/usr/bin/env python3
"""Generates reusable obstacle prefabs as .vox files (0.25 m voxels in game).

Run:  python3 tools/make_obstacles.py

Prefabs don't store real colors: each palette index is a *slot* that the biome
fills in (see BiomeDef.obstacle_colors), so one shape is reused everywhere.
The colors written here are only a preview for Goxel. Voxels in the GLOW slot
are drawn glowing (lanterns, embers, mushroom caps); the rest is normal.
Prefabs named decor_* are small ground clutter at 0.125 m voxels.
"""
import math
import os
import random
import struct

# Slot ids (palette indices). Must match ObstacleLibrary / BiomeDef.obstacle_colors.
STONE, STONE_DARK, FOLIAGE, WOOD, ACCENT, FOLIAGE_DARK, GLOW, CHAR = range(1, 9)
PREVIEW = {
    STONE: (140, 140, 140), STONE_DARK: (96, 96, 100), FOLIAGE: (76, 140, 56),
    WOOD: (108, 76, 46), ACCENT: (220, 220, 200), FOLIAGE_DARK: (50, 100, 40),
    GLOW: (255, 190, 100), CHAR: (22, 18, 18),
}


def box(v, x0, x1, y0, y1, z0, z1, c):
    """Fills the half-open box [x0,x1) x [y0,y1) x [z0,z1)."""
    for x in range(x0, x1):
        for y in range(y0, y1):
            for z in range(z0, z1):
                v[(x, y, z)] = c


def ellipsoid(v, cx, cy, cz, rx, ry, rz, c, rng, rough=0.0, min_y=0):
    for x in range(math.floor(cx - rx), math.ceil(cx + rx) + 1):
        for y in range(max(min_y, math.floor(cy - ry)), math.ceil(cy + ry) + 1):
            for z in range(math.floor(cz - rz), math.ceil(cz + rz) + 1):
                d = ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 + ((z - cz) / rz) ** 2
                if d <= 1.0 - rough * rng.random():
                    v[(x, y, z)] = c


def disk(v, cx, cz, r, y, c):
    for x in range(math.floor(cx - r), math.ceil(cx + r) + 1):
        for z in range(math.floor(cz - r), math.ceil(cz + r) + 1):
            if (x - cx) ** 2 + (z - cz) ** 2 <= r * r:
                v[(x, y, z)] = c


def line(v, p0, p1, c):
    steps = int(max(abs(p1[i] - p0[i]) for i in range(3))) + 1
    for i in range(steps + 1):
        t = i / steps
        v[tuple(round(p0[k] + (p1[k] - p0[k]) * t) for k in range(3))] = c


def top_layer(v, c, chance, rng, skip=()):
    """Recolors the highest voxel of each column (moss, snow, sand...)."""
    tops = {}
    for (x, y, z) in v:
        if (x, z) not in tops or y > tops[(x, z)]:
            tops[(x, z)] = y
    for (x, z), y in tops.items():
        if v[(x, y, z)] not in skip and rng.random() < chance:
            v[(x, y, z)] = c


def bottom_rows(v, rows, c, only=None):
    for p, col in list(v.items()):
        if p[1] < rows and (only is None or col == only):
            v[p] = c


# --- Prefabs -----------------------------------------------------------------

def rock(rng):
    v = {}
    ellipsoid(v, 0, 3, 0, 5, 4, 4.5, STONE, rng, rough=0.25)
    bottom_rows(v, 2, STONE_DARK)
    top_layer(v, ACCENT, 0.5, rng)
    return v


def boulder(rng):
    v = {}
    ellipsoid(v, 0, 5, 0, 8, 6.5, 7, STONE, rng, rough=0.2)
    ellipsoid(v, 4, 3, 3, 4, 3.5, 4, STONE_DARK, rng, rough=0.3)
    bottom_rows(v, 2, STONE_DARK)
    top_layer(v, ACCENT, 0.6, rng)
    return v


def ruin_wall(rng):
    v = {}
    height = 9
    for x in range(-10, 10):
        height = max(4, min(14, height + rng.choice((-2, -1, 0, 0, 1, 2))))
        box(v, x, x + 1, 0, height, -1, 2, STONE)
    for _ in range(3):  # missing chunks
        x, y = rng.randrange(-8, 8), rng.randrange(3, 8)
        for p in [(x + dx, y + dy, z) for dx in range(2) for dy in range(2) for z in range(-1, 2)]:
            v.pop(p, None)
    bottom_rows(v, 1, STONE_DARK)
    top_layer(v, ACCENT, 0.5, rng)
    return v


def ruin_house(rng):
    """A roofless ruined building: 6 x 6 m, with a doorway and a window."""
    v = {}
    half, thick = 12, 2

    def wall_heights(n):
        h, out = 10, []
        for _ in range(n):
            h = max(5, min(13, h + rng.choice((-2, -1, 0, 0, 1))))
            out.append(h)
        return out

    for side in range(4):
        for i, h in enumerate(wall_heights(half * 2)):
            t = i - half
            if side == 0:
                box(v, t, t + 1, 0, h, -half, -half + thick, STONE)
            elif side == 1:
                box(v, t, t + 1, 0, h, half - thick, half, STONE)
            elif side == 2:
                box(v, -half, -half + thick, 0, h, t, t + 1, STONE)
            else:
                box(v, half - thick, half, 0, h, t, t + 1, STONE)
    for cx in (-half, half - 3):  # sturdier corners
        for cz in (-half, half - 3):
            box(v, cx, cx + 3, 0, 13 + rng.randrange(3), cz, cz + 3, STONE_DARK)
    for p in [p for p in v if -3 <= p[0] < 3 and p[2] >= half - thick]:  # doorway
        del v[p]
    for p in [p for p in v if p[0] < -half + thick and -2 <= p[2] < 2 and 4 <= p[1] < 7]:  # window
        del v[p]
    ellipsoid(v, -7, 0, -7, 3.5, 2.5, 3.5, STONE_DARK, rng, rough=0.4)  # rubble pile
    bottom_rows(v, 1, STONE_DARK)
    top_layer(v, ACCENT, 0.45, rng, skip=(STONE_DARK,))
    return v


def pillar(rng):
    v = {}
    box(v, -3, 3, 0, 2, -3, 3, STONE_DARK)
    top = 10 + rng.randrange(5)
    for x in range(-2, 2):
        for z in range(-2, 2):
            box(v, x, x + 1, 2, top + rng.randrange(-2, 2), z, z + 1, STONE)
    top_layer(v, ACCENT, 0.5, rng)
    return v


def tree_round(rng):
    v = {}
    box(v, -1, 1, 0, 11, -1, 1, WOOD)
    ellipsoid(v, 0, 13, 0, 6, 5, 6, FOLIAGE, rng, rough=0.2)
    ellipsoid(v, 3, 11, -2, 3.5, 3, 3.5, FOLIAGE, rng, rough=0.2)
    for p, c in list(v.items()):
        if c == FOLIAGE and p[1] < 12:
            v[p] = FOLIAGE_DARK
    return v


def tree_tall(rng):
    v = {}
    box(v, -1, 1, 0, 16, -1, 1, WOOD)
    line(v, (0, 10, 0), (4, 14, 1), WOOD)
    ellipsoid(v, 0, 18, 0, 7, 4.5, 7, FOLIAGE, rng, rough=0.2)
    ellipsoid(v, 4, 14, 1, 4, 3, 4, FOLIAGE, rng, rough=0.2)
    ellipsoid(v, -3, 15, -3, 3.5, 2.5, 3.5, FOLIAGE, rng, rough=0.2)
    for p, c in list(v.items()):
        if c == FOLIAGE and p[1] < 16:
            v[p] = FOLIAGE_DARK
    return v


def palm(rng):
    v = {}
    height = 18
    for y in range(height):
        ox = round((y / height) ** 2 * 4)
        box(v, ox - 1, ox + 1, y, y + 1, -1, 1, WOOD if y % 3 else STONE_DARK)
    top = (4, height, 0)
    for k in range(7):
        a = k / 7 * math.tau + rng.random() * 0.4
        for t in range(1, 9):
            x = top[0] + math.cos(a) * t
            z = math.sin(a) * t
            y = top[1] + 1 - (t * t) / 10
            v[(round(x), round(y), round(z))] = FOLIAGE
            v[(round(x), round(y) - 1, round(z))] = FOLIAGE_DARK
    box(v, 3, 5, height - 1, height + 1, -1, 1, WOOD)
    return v


def bush(rng):
    v = {}
    ellipsoid(v, 0, 2, 0, 4, 3, 4, FOLIAGE, rng, rough=0.3)
    ellipsoid(v, 2.5, 1.5, 1.5, 2.5, 2, 2.5, FOLIAGE, rng, rough=0.3)
    bottom_rows(v, 2, FOLIAGE_DARK)
    return v


def cactus(rng):
    v = {}
    box(v, -1, 2, 0, 13, -1, 2, FOLIAGE)
    box(v, 2, 4, 5, 7, -1, 2, FOLIAGE)
    box(v, 3, 5, 7, 11, -1, 1, FOLIAGE)
    box(v, -4, -1, 7, 9, 0, 2, FOLIAGE)
    box(v, -4, -2, 9, 12, 0, 2, FOLIAGE)
    for p in list(v):
        if (p[0] + p[2]) % 2 == 0 and v[p] == FOLIAGE:
            v[p] = FOLIAGE_DARK  # ribbed look
    v[(0, 13, 0)] = ACCENT
    return v


def dead_tree(rng):
    v = {}
    box(v, -1, 1, 0, 13, -1, 1, WOOD)
    for _ in range(6):
        y = rng.randrange(5, 13)
        a = rng.random() * math.tau
        length = rng.randrange(4, 8)
        end = (round(math.cos(a) * length), y + rng.randrange(2, 5), round(math.sin(a) * length))
        line(v, (0, y, 0), end, WOOD)
    bottom_rows(v, 2, STONE_DARK)
    return v


def obelisk(rng):
    v = {}
    height = 22
    for y in range(height):
        hw = 3 - y * 3 / height
        c = STONE_DARK if y % 6 == 0 else STONE
        box(v, -math.ceil(hw), math.ceil(hw), y, y + 1, -math.ceil(hw), math.ceil(hw), c)
    v[(0, height, 0)] = ACCENT
    v[(-1, height - 1, -1)] = ACCENT
    return v


def pine(rng):
    v = {}
    box(v, -1, 1, 0, 6, -1, 1, WOOD)
    for tier in range(5):
        y0 = 4 + tier * 4
        r = 7 - tier * 1.4
        for dy in range(5):
            disk(v, -0.5, -0.5, r * (1 - dy / 5), y0 + dy, FOLIAGE if dy else FOLIAGE_DARK)
    v[(0, 25, 0)] = FOLIAGE
    top_layer(v, ACCENT, 0.8, rng)
    return v


def ice_spike(rng):
    v = {}
    for (ox, oz, h, lean) in [(0, 0, 18, 0.15), (4, 2, 11, 0.3), (-3, 3, 9, -0.3)]:
        for y in range(h):
            hw = max(0.5, 2.2 * (1 - y / h))
            cx = ox + lean * y
            for x in range(math.floor(cx - hw), math.ceil(cx + hw)):
                for z in range(math.floor(oz - hw), math.ceil(oz + hw)):
                    v[(x, y, z)] = ACCENT
    bottom_rows(v, 1, STONE_DARK)
    return v


def glowshroom(rng):
    v = {}
    for (ox, oz, h, r) in [(0, 0, 7, 5), (5, 3, 4, 2.5), (-4, 4, 3, 2)]:
        box(v, ox - 1, ox + 1, 0, h, oz - 1, oz + 1, ACCENT)
        ellipsoid(v, ox, h, oz, r, r * 0.5, r, GLOW, rng, min_y=h)
    return v


def crystal_cluster(rng):
    v = {}
    ellipsoid(v, 0, 0, 0, 5, 2, 5, STONE_DARK, rng, rough=0.3)
    for k in range(5):
        a = k / 5 * math.tau
        ox, oz = math.cos(a) * 2.5, math.sin(a) * 2.5
        h = rng.randrange(7, 15) if k else 17
        lx, lz = math.cos(a) * 0.25, math.sin(a) * 0.25
        for y in range(h):
            hw = 1.5 if y < h - 3 else 0.6
            cx, cz = ox + lx * y, oz + lz * y
            for x in range(math.floor(cx - hw), math.ceil(cx + hw)):
                for z in range(math.floor(cz - hw), math.ceil(cz + hw)):
                    v[(x, y + 1, z)] = GLOW
    return v


def tree_small(rng):
    v = {}
    box(v, 0, 1, 0, 9, 0, 1, WOOD)
    line(v, (0, 6, 0), (2, 8, 1), WOOD)
    ellipsoid(v, 0, 10, 0, 4, 3.5, 4, FOLIAGE, rng, rough=0.25)
    ellipsoid(v, 2, 8.5, 1, 2.5, 2, 2.5, FOLIAGE, rng, rough=0.25)
    for p, c in list(v.items()):
        if c == FOLIAGE and p[1] < 9:
            v[p] = FOLIAGE_DARK
    return v


def burnt_tree(rng):
    """Charred trunk and branches with glowing ember cracks."""
    v = {}
    box(v, -1, 1, 0, 12, -1, 1, CHAR)
    for _ in range(5):
        y = rng.randrange(5, 12)
        a = rng.random() * math.tau
        length = rng.randrange(3, 7)
        line(v, (0, y, 0), (round(math.cos(a) * length), y + rng.randrange(1, 4), round(math.sin(a) * length)), CHAR)
    for p in list(v):
        if rng.random() < 0.08:
            v[p] = GLOW  # embers
    bottom_rows(v, 1, STONE_DARK)
    return v


def campfire(rng):
    """Stone ring with crossed logs and glowing embers (a fire burns on top)."""
    v = {}
    for k in range(10):
        a = k / 10 * math.tau
        x, z = round(math.cos(a) * 3.5), round(math.sin(a) * 3.5)
        box(v, x, x + 1, 0, 1 + (k % 2), z, z + 1, STONE)
    line(v, (-2, 1, -2), (2, 1, 2), WOOD)
    line(v, (-2, 1, 2), (2, 1, -2), CHAR)
    for x in range(-1, 2):
        for z in range(-1, 2):
            v[(x, 0, z)] = GLOW
    return v


def lamppost(rng):
    """Stone base, dark post, arm and a hanging lantern."""
    v = {}
    box(v, -2, 2, 0, 2, -2, 2, STONE)
    box(v, -1, 1, 2, 15, -1, 1, STONE_DARK)
    box(v, -1, 4, 15, 16, -1, 1, STONE_DARK)
    box(v, 2, 5, 11, 14, -1, 2, STONE_DARK)  # lantern frame
    box(v, 3, 4, 12, 13, 0, 1, GLOW)
    v[(2, 12, 0)] = GLOW
    v[(4, 12, 0)] = GLOW
    v[(3, 12, -1)] = GLOW
    v[(3, 12, 1)] = GLOW
    return v


# --- Small ground decorations (0.125 m voxels) ------------------------------------

def decor_tuft(rng):
    v = {}
    for _ in range(9):
        x, z = rng.randrange(-3, 3), rng.randrange(-3, 3)
        for y in range(rng.randrange(1, 5)):
            v[(x, y, z)] = FOLIAGE if y else FOLIAGE_DARK
    return v


def decor_flowers(rng):
    v = decor_tuft(rng)
    for _ in range(4):
        x, z = rng.randrange(-3, 3), rng.randrange(-3, 3)
        h = rng.randrange(3, 6)
        for y in range(h):
            v[(x, y, z)] = FOLIAGE
        v[(x, h, z)] = ACCENT
    return v


def decor_pebbles(rng):
    v = {}
    for _ in range(3):
        x, z = rng.randrange(-3, 3), rng.randrange(-3, 3)
        box(v, x, x + rng.randrange(1, 3), 0, rng.randrange(1, 3), z, z + rng.randrange(1, 3), STONE)
    return v


def decor_fern(rng):
    v = {}
    for k in range(6):
        a = k / 6 * math.tau + rng.random() * 0.3
        for t in range(1, 6):
            v[(round(math.cos(a) * t), round(3 - (t - 2) ** 2 / 4), round(math.sin(a) * t))] = FOLIAGE
    v[(0, 0, 0)] = FOLIAGE_DARK
    return v


def decor_mushrooms(rng):
    v = {}
    for _ in range(3):
        x, z = rng.randrange(-3, 3), rng.randrange(-3, 3)
        h = rng.randrange(2, 4)
        box(v, x, x + 1, 0, h, z, z + 1, STONE)
        box(v, x - 1, x + 2, h, h + 1, z - 1, z + 2, ACCENT)
    return v


def decor_dry_grass(rng):
    v = {}
    for _ in range(7):
        x, z = rng.randrange(-3, 3), rng.randrange(-3, 3)
        for y in range(rng.randrange(1, 4)):
            v[(x + (y == 2), y, z)] = WOOD
    return v


def decor_embers(rng):
    v = {}
    for _ in range(5):
        x, z = rng.randrange(-3, 3), rng.randrange(-3, 3)
        v[(x, 0, z)] = CHAR
        if rng.random() < 0.6:
            v[(x, 1, z)] = GLOW
    return v


def decor_glow_sprouts(rng):
    v = {}
    for _ in range(5):
        x, z = rng.randrange(-3, 3), rng.randrange(-3, 3)
        h = rng.randrange(2, 5)
        for y in range(h):
            v[(x, y, z)] = FOLIAGE
        v[(x, h, z)] = GLOW
    return v


PREFABS = {
    "rock": rock, "boulder": boulder, "ruin_wall": ruin_wall, "ruin_house": ruin_house,
    "pillar": pillar, "tree_round": tree_round, "tree_tall": tree_tall, "palm": palm,
    "bush": bush, "cactus": cactus, "dead_tree": dead_tree, "obelisk": obelisk,
    "pine": pine, "ice_spike": ice_spike, "glowshroom": glowshroom,
    "crystal_cluster": crystal_cluster, "tree_small": tree_small, "burnt_tree": burnt_tree,
    "campfire": campfire, "lamppost": lamppost,
    "decor_tuft": decor_tuft, "decor_flowers": decor_flowers, "decor_pebbles": decor_pebbles,
    "decor_fern": decor_fern, "decor_mushrooms": decor_mushrooms, "decor_dry_grass": decor_dry_grass,
    "decor_embers": decor_embers, "decor_glow_sprouts": decor_glow_sprouts,
}


# --- .vox writing --------------------------------------------------------------

def write_vox(path, vox, colors):
    """Writes vox in a frame centered on x/z (origin = base center).

    colors: palette index -> (r, g, b) preview color.
    """
    xs = [p[0] for p in vox]
    zs = [p[2] for p in vox]
    ys = [p[1] for p in vox]
    hx = max(-min(xs), max(xs) + 1)
    hz = max(-min(zs), max(zs) + 1)
    assert min(ys) >= 0, f"{path}: voxels below ground"
    sx, sy, sz = hx * 2, max(ys) + 1, hz * 2

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
    children = (chunk(b"SIZE", struct.pack("<iii", sz, sx, sy)) + chunk(b"XYZI", xyzi)
                + chunk(b"RGBA", rgba))
    with open(path, "wb") as f:
        f.write(b"VOX " + struct.pack("<i", 150) + chunk(b"MAIN", b"", children))
    print(f"{os.path.basename(path)}: {len(vox)} voxels, {sx}x{sy}x{sz}")


if __name__ == "__main__":
    out = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "obstacles")
    os.makedirs(out, exist_ok=True)
    for name, fn in PREFABS.items():
        write_vox(os.path.join(out, name + ".vox"), fn(random.Random(name)), PREVIEW)
