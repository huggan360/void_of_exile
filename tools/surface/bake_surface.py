#!/usr/bin/env python3
"""Bakes the Surface: a 2048 x 2048 m world that the game streams as 0.25 m voxels.

Run:  python3 tools/surface/bake_surface.py      (about a minute)

Writes realm/surface/ (read by SurfaceMap in the game, the same on the
server and every client):
  height.bin.gz  uint16 per meter: ground height in 0.25 m voxels
  water.bin.gz   uint16 per meter: river / lake surface in 0.25 m voxels (0 = none)
  ground.bin.gz  uint8  per meter: ground material (MAT_* below = SurfaceMap.Mat)
  biome.bin.gz   uint8  per meter: biome id (Biomes enum)
  flora.bin.gz   uint8  per meter: forest density 0..255
  flags.bin.gz   uint8  per meter: FLAG_* bits below
  shape.bin.gz   uint8  per meter: S_* bits (cliffs, ivy...)
  current.bin.gz uint8 pairs per meter: river current x/z (128 = still)
  tiles.bin.gz   uint16 pairs per 4 x 4 m tile: lowest and highest voxel that
                 can be solid there, so empty blocks are skipped at once
  surface.json   settlements, strongholds, landmarks, roads, stairs, bridges,
                 fences, piers, waterfalls, camps, volcanoes, lights
  map.bin.gz     uint8 RGB per meter: the map screen's picture
  preview.png    a colored overview (for people, not the game)

The world is not round: a continent shaped by noise with bays, peninsulas and
islands. Biomes grow from several seeds each with warped borders, so they
interlock naturally. Hills are terraced with stone risers, Fosen rises into
real mountains, Doom has volcanoes with lava flows, rivers drain the land to
the sea with waterfalls where they drop over terraces. Settlements range
from the capital to single farmsteads, joined by graded roads; trails wind
through the woods and climb steep places on wooden stairs.
"""
import gzip
import heapq
import json
import math
import os
import random
import struct
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from surface_noise import (fbm, ridged, smoothstep, sample, terrace, block_mean, upscale, box_blur,
                           distance_to, chaikin, resample)

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
OUT = os.path.join(ROOT, "realm", "surface")
N = 2048
HALF = N // 2
SEA = 8.0  # meters (IslandGenerator.SEA_LEVEL)
FINE = 4  # voxels per meter
SEED = 1337
C = 4  # coarse cell (m) for rivers and routing
NC = N // C

# Biomes (scripts/world/biomes.gd)
HALL, OCEAN, BEACH, WOODS, JUNGLE, DESERT, DOOM, FOSEN, BLUELAY, DEEP_DESERT, DEEP_DARK = range(11)

# Ground materials (SurfaceMap.Mat)
(M_DEFAULT, M_GRASS, M_MEADOW, M_FOREST, M_DIRT, M_TRAIL, M_ROAD_COBBLE, M_ROAD_DIRT, M_PLAZA, M_FARM,
 M_SAND, M_RIVERBED, M_ROCK, M_SNOW, M_TUNDRA, M_ASH, M_BASALT, M_LAVA, M_DESERT_SAND, M_DEEP_SAND,
 M_SANDSTONE, M_BLUE_MOSS, M_DEEP_STONE, M_JUNGLE_GRASS, M_STAIRS, M_SEAFLOOR, M_CRACKED, M_BLACK_SAND,
 M_ICE, M_YARD, M_ROAD_SAND, M_ROAD_ASH, M_ROAD_SNOW, M_OBSIDIAN, M_GRAVEL, M_MOSS_ROCK) = range(36)

# Flag bits (SurfaceMap.Flag)
F_ROAD, F_TRAIL, F_TOWN, F_FIELD, F_RIVER, F_CLEAR, F_LAKE, F_BRIDGE = (1, 2, 4, 8, 16, 32, 64, 128)
# Shape bits (SurfaceMap.Shape): stone walls, the foot of walls, ivy, rough rock
S_CLIFF, S_BASE, S_VINES, S_ROCKY = (1, 2, 4, 8)
TILE = 4  # meters per tile in tiles.bin.gz (one 16-voxel block)

rng = np.random.default_rng(SEED)
prng = random.Random(SEED)

xs = (np.arange(N, dtype=np.float32) - HALF + 0.5)
WX, WZ = np.meshgrid(xs, xs)  # world x / z of each pixel center


def pix(x, z):
    return int(np.clip(round(z + HALF - 0.5), 0, N - 1)), int(np.clip(round(x + HALF - 0.5), 0, N - 1))


def log(*a):
    print(*a, flush=True)


# --------------------------------------------------------------------------------------
# Continent
# --------------------------------------------------------------------------------------

def continent():
    shape = fbm(rng, 5, N, 6, 0.55)
    detail = fbm(rng, 22, N, 4)
    sq = ((np.abs(WX) / 1000.0) ** 4 + (np.abs(WZ) / 1000.0) ** 4) ** 0.25
    fall = smoothstep(0.5, 1.02, sq) * 1.35
    v = shape * 0.55 + detail * 0.08 - fall + 0.35 * (1.0 - smoothstep(0.0, 0.45, sq))
    # Offshore islands, some in little archipelagos.
    for k in range(9):
        a = prng.uniform(0, math.tau)
        d = prng.uniform(860, 960)
        cx, cz = math.cos(a) * d, math.sin(a) * d
        r = prng.uniform(28, 75)
        dist = np.sqrt((WX - cx) ** 2 + (WZ - cz) ** 2) / r
        island = (1.0 - dist) * 0.9 + detail * 0.25
        v = np.maximum(v, island - 0.15)
    land = v > np.quantile(v, 0.44)
    # No big lakes from the continent noise: fill water not joined to the sea.
    coarse = block_mean(land.astype(np.float32), 8) > 0.5
    sea = flood_from_edges(~coarse)
    lakes = (~coarse) & (~sea)
    land |= np.kron(lakes, np.ones((8, 8), bool))
    return land


def flood_from_edges(water):
    n = water.shape[0]
    seen = np.zeros_like(water)
    stack = [(z, x) for z in range(n) for x in (0, n - 1) if water[z, x]]
    stack += [(z, x) for x in range(n) for z in (0, n - 1) if water[z, x]]
    for p in stack:
        seen[p] = True
    while stack:
        z, x = stack.pop()
        for dz, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            zz, xx = z + dz, x + dx
            if 0 <= zz < n and 0 <= xx < n and water[zz, xx] and not seen[zz, xx]:
                seen[zz, xx] = True
                stack.append((zz, xx))
    return seen


# --------------------------------------------------------------------------------------
# Biomes
# --------------------------------------------------------------------------------------

ANCHORS = {
    WOODS: [(0, 0, 560, 1.0), (-380, -380, 260, 0.82), (420, -300, 240, 0.8), (-300, 330, 230, 0.8), (380, 330, 200, 0.78)],
    FOSEN: [(-120, -840, 520, 1.0), (320, -800, 380, 0.95), (-560, -740, 300, 0.92)],
    DOOM: [(840, 120, 470, 1.0), (720, 540, 320, 0.95)],
    DESERT: [(-560, 660, 430, 1.0), (-140, 840, 300, 0.95)],
    DEEP_DESERT: [(-640, 760, 250, 1.1)],
    BLUELAY: [(-880, -120, 430, 1.0), (-780, 280, 300, 0.95)],
    JUNGLE: [(360, 740, 360, 1.04), (170, 560, 220, 0.95)],
    DEEP_DARK: [(640, -600, 250, 1.12)],
}
BIOME_LIST = [WOODS, FOSEN, DOOM, DESERT, DEEP_DESERT, BLUELAY, JUNGLE, DEEP_DARK]


def biome_scores():
    wa = fbm(rng, 4, N, 4)
    wb = fbm(rng, 4, N, 4)
    wc = fbm(rng, 20, N, 3)
    wd = fbm(rng, 20, N, 3)
    px = WX + wa * 110 + wc * 22
    pz = WZ + wb * 110 + wd * 22
    scores = {}
    for b, anchors in ANCHORS.items():
        s = np.full((N, N), -9.0, np.float32)
        for ax, az, r, strength in anchors:
            s = np.maximum(s, strength - np.sqrt((px - ax) ** 2 + (pz - az) ** 2) / r)
        scores[b] = s
    return scores


# --------------------------------------------------------------------------------------
# Height
# --------------------------------------------------------------------------------------

def relief(scores, land, coast_in, coast_out):
    n1 = fbm(rng, 7, N, 5)
    n2 = fbm(rng, 26, N, 4)
    n3 = fbm(rng, 80, N, 3)
    mask_t = fbm(rng, 6, N, 3)
    r1 = ridged(rng, 9, N, 6)
    r2 = ridged(rng, 30, N, 4)
    hill = np.maximum(0, n1 - 0.25)

    H = {}
    base = 5.0 + 8.0 * n1 + 3.5 * n2 + 0.6 * n3 + hill * 30.0
    step = 3.0 + 1.4 * n2
    # Stone-walled shelves: flat grassy steps, short sheer risers.
    H[WOODS] = base + (terrace(base + 2.0, step, 0.045) - base) * smoothstep(-0.25, 0.25, mask_t)
    # Rocky outcrops standing out of the meadows.
    crag = smoothstep(0.5, 0.53, fbm(rng, 40, N, 3)) * (2.5 + 4.0 * np.abs(n3))
    H[WOODS] += crag
    jb = 7.0 + 11.0 * n1 + 5.0 * n2 + r2 * 4.0 + hill * 20.0
    H[JUNGLE] = terrace(jb, 4.0 + n2, 0.05)
    fos_core = smoothstep(0.05, 0.75, scores[FOSEN] - np.maximum(scores[WOODS], scores[DEEP_DARK]) * 0.3)
    mountains = (r1 ** 1.25) * 150.0 * fos_core + 7.0 + 6.0 * n2 + hill * 12.0
    H[FOSEN] = mountains + (terrace(mountains, 6.0, 0.05) - mountains) * 0.5
    H[DOOM] = 3.5 + 3.0 * n2 + 2.0 * np.abs(n3) + (r2 ** 2) * 9.0 * smoothstep(0.2, 0.6, n1 + 0.4)
    dunes = 3.0 + 2.2 * np.sin(WX * 0.045 + WZ * 0.018 + n2 * 3.0) + 2.0 * n1
    mesa_n = fbm(rng, 13, N, 3)
    mesa = smoothstep(0.38, 0.42, mesa_n) * (15.0 + 5.0 * n3)
    H[DESERT] = dunes + terrace(mesa, 5.0, 0.07)
    H[DEEP_DESERT] = 5.0 + 6.5 * (np.sin(WX * 0.028 + WZ * 0.011 + n1 * 4.0) * 0.5 + 0.5) + 2.5 * n1
    pools = fbm(rng, 34, N, 3)
    H[BLUELAY] = 1.6 + 1.6 * n2 + 0.8 * n3 - smoothstep(0.32, 0.5, pools) * 3.4
    spires = smoothstep(0.82, 0.9, r2) * (9.0 + 9.0 * np.abs(n3))
    H[DEEP_DARK] = 0.9 + 1.3 * np.abs(n3) + spires

    # Soft biome weights: heights blend over ~40 m at the borders.
    smax = np.maximum.reduce([scores[b] for b in BIOME_LIST])
    weights = {b: np.exp((scores[b] - smax) / 0.045) for b in BIOME_LIST}
    total = sum(weights.values())
    rel = sum(weights[b] * H[b] for b in BIOME_LIST) / total
    cliffy = (weights[FOSEN] + weights[DOOM] + weights[DEEP_DARK]) / total

    # Coast: beaches slope gently into the sea, rocky biomes drop as cliffs.
    beach = 0.5 + 0.035 * coast_in
    ramp = smoothstep(1.0, 42.0, coast_in) * (1 - cliffy) + smoothstep(0.0, 7.0, coast_in) * cliffy
    rel = beach + (rel - beach) * ramp
    sea_floor = -0.9 - 0.13 * coast_out
    rel = np.where(land, np.maximum(rel, 0.35), np.maximum(sea_floor, -7.5))
    return rel, weights, total


def volcanoes(rel, scores, land):
    """Two big cones and a small one in Doom, each with a crater lava lake."""
    doom = np.where(land, scores[DOOM] - np.maximum(scores[WOODS], scores[JUNGLE]), -9)
    out = []
    n4 = fbm(rng, 40, N, 3)
    for k, (height, radius) in enumerate([(66.0, 165.0), (48.0, 120.0), (30.0, 85.0)]):
        masked = doom.copy()
        for v in out:
            masked[(WX - v["x"]) ** 2 + (WZ - v["z"]) ** 2 < (v["r"] + radius + 40) ** 2] = -9
        masked[np.sqrt(WX ** 2 + WZ ** 2) > 900] = -9
        z, x = np.unravel_index(np.argmax(masked[::8, ::8]), masked[::8, ::8].shape)
        cx, cz = float(WX[z * 8, x * 8]), float(WZ[z * 8, x * 8])
        d = np.sqrt((WX - cx) ** 2 + (WZ - cz) ** 2)
        ang = np.arctan2(WZ - cz, WX - cx)
        rr = radius * (1.0 + 0.1 * np.sin(ang * 3 + k) + 0.06 * np.sin(ang * 7 + 2 * k))
        t = np.clip(1.0 - d / rr, 0.0, 1.0)
        crater = radius * 0.16
        cone = height * t ** 1.6 + n4 * 3.0 * t
        rim_h = height * (1.0 - crater / radius) ** 1.6
        inside = d < crater
        bowl = rim_h - 14.0 * (1.0 - (d / crater) ** 2)
        cone = np.where(inside, bowl, cone)
        # Gullies down the flanks.
        cone -= (np.abs(np.sin(ang * 9 + n4 * 2)) < 0.12) * t * 2.5
        rel[:] = np.where(t > 0, np.maximum(rel, cone + 2.0 * t), rel)
        out.append({"x": cx, "z": cz, "r": radius, "h": float(SEA + rim_h), "crater": crater,
                    "lake": float(SEA + rim_h - 12.0)})
    return out


# --------------------------------------------------------------------------------------
# Rivers (4 m grid): priority flood, flow directions, accumulation
# --------------------------------------------------------------------------------------

D8 = [(-1, -1), (-1, 0), (-1, 1), (0, -1), (0, 1), (1, -1), (1, 0), (1, 1)]


def priority_flood(h):
    n = h.shape[0]
    filled = h.copy()
    done = np.zeros((n, n), bool)
    heap = []
    for z in range(n):
        for x in range(n):
            if h[z, x] < 0 or z in (0, n - 1) or x in (0, n - 1):
                heap.append((float(h[z, x]), z, x))
                done[z, x] = True
    heapq.heapify(heap)
    hl = filled.tolist()
    dl = done.tolist()
    while heap:
        v, z, x = heapq.heappop(heap)
        for dz, dx in D8:
            zz, xx = z + dz, x + dx
            if 0 <= zz < n and 0 <= xx < n and not dl[zz][xx]:
                dl[zz][xx] = True
                nv = max(hl[zz][xx], v + 0.001)
                hl[zz][xx] = nv
                heapq.heappush(heap, (nv, zz, xx))
    return np.array(hl, np.float32)


def flow(filled, rain):
    n = filled.shape[0]
    fl = filled.tolist()
    down = [[-1] * n for _ in range(n)]
    for z in range(n):
        row = fl[z]
        for x in range(n):
            best, bi = row[x], -1
            for k, (dz, dx) in enumerate(D8):
                zz, xx = z + dz, x + dx
                if 0 <= zz < n and 0 <= xx < n:
                    v = fl[zz][xx] + (0.0 if dz == 0 or dx == 0 else 0.0004)
                    if v < best:
                        best, bi = v, zz * n + xx
            down[z][x] = bi
    order = np.argsort(-filled, axis=None)
    acc = rain.flatten().astype(np.float64).tolist()
    flat_down = [d for row in down for d in row]
    for i in order.tolist():
        d = flat_down[i]
        if d >= 0:
            acc[d] += acc[i]
    return np.array(acc, np.float32).reshape(n, n), flat_down


# --------------------------------------------------------------------------------------
# Rasterizing polylines (rivers, roads, trails)
# --------------------------------------------------------------------------------------

def segments_field(points, reach, values=None):
    """Distance from pixels to a polyline (within `reach`), the interpolated
    value of the nearest point and the 0..1 position along it. Returns
    (rows, cols, dist, value, along) for every pixel within reach."""
    pts = np.array(points, np.float32)
    if values is None:
        values = np.zeros(len(points), np.float32)
    vals = np.array(values, np.float32)
    seg_len = np.sqrt(((pts[1:] - pts[:-1]) ** 2).sum(1))
    cum = np.concatenate([[0], np.cumsum(seg_len)])
    total = max(cum[-1], 1e-3)
    best = {}
    for i in range(len(pts) - 1):
        a, b = pts[i], pts[i + 1]
        x0 = int(math.floor(min(a[0], b[0]) - reach)) + HALF
        x1 = int(math.ceil(max(a[0], b[0]) + reach)) + HALF
        z0 = int(math.floor(min(a[1], b[1]) - reach)) + HALF
        z1 = int(math.ceil(max(a[1], b[1]) + reach)) + HALF
        x0, z0 = max(x0, 0), max(z0, 0)
        x1, z1 = min(x1, N - 1), min(z1, N - 1)
        if x1 < x0 or z1 < z0:
            continue
        gz, gx = np.mgrid[z0:z1 + 1, x0:x1 + 1]
        px = gx - HALF + 0.5
        pz = gz - HALF + 0.5
        ab = b - a
        l2 = max(float(ab @ ab), 1e-6)
        t = np.clip(((px - a[0]) * ab[0] + (pz - a[1]) * ab[1]) / l2, 0, 1)
        d = np.sqrt((px - a[0] - ab[0] * t) ** 2 + (pz - a[1] - ab[1] * t) ** 2)
        val = vals[i] + (vals[i + 1] - vals[i]) * t
        along = (cum[i] + t * seg_len[i]) / total
        for zz, xx, dd, vv, aa in zip(gz[d < reach].tolist(), gx[d < reach].tolist(), d[d < reach].tolist(),
                                      val[d < reach].tolist(), along[d < reach].tolist()):
            k = zz * N + xx
            if k not in best or best[k][0] > dd:
                best[k] = (dd, vv, aa)
    if not best:
        e = np.zeros(0, np.int64)
        return e, e, np.zeros(0), np.zeros(0), np.zeros(0)
    keys = np.fromiter(best.keys(), np.int64)
    arr = np.array(list(best.values()), np.float32)
    return keys // N, keys % N, arr[:, 0], arr[:, 1], arr[:, 2]


# --------------------------------------------------------------------------------------
# Routing (4 m grid A*)
# --------------------------------------------------------------------------------------

def astar(cost, heights, start, goal, slope_k, slope_max, road_mask=None, road_bonus=1.0, cliff_cost=None):
    """cost: per-cell base cost (inf = blocked), heights: coarse meters."""
    n = cost.shape[0]
    cl = cost.tolist()
    hl = heights.tolist()
    rl = road_mask.tolist() if road_mask is not None else None
    sz, sx = start
    gz, gx = goal
    openh = [(0.0, 0.0, sz, sx)]
    came = {}
    g = {(sz, sx): 0.0}
    closed = set()
    while openh:
        _, gc, z, x = heapq.heappop(openh)
        if (z, x) in closed:
            continue
        if (z, x) == (gz, gx):
            path = [(z, x)]
            while (z, x) in came:
                z, x = came[(z, x)]
                path.append((z, x))
            return path[::-1]
        closed.add((z, x))
        for dz, dx in D8:
            zz, xx = z + dz, x + dx
            if not (0 <= zz < n and 0 <= xx < n) or (zz, xx) in closed:
                continue
            c = cl[zz][xx]
            if c == math.inf:
                continue
            step = 1.4142 if dz and dx else 1.0
            slope = abs(hl[zz][xx] - hl[z][x]) / (step * C)
            if slope > slope_max:
                if cliff_cost is None:
                    continue
                c += cliff_cost
            c = c + slope * slope_k
            if rl is not None and rl[zz][xx]:
                c *= road_bonus
            ng = gc + c * step
            if ng < g.get((zz, xx), math.inf):
                g[(zz, xx)] = ng
                came[(zz, xx)] = (z, x)
                hcost = math.hypot(gz - zz, gx - xx) * 0.55
                heapq.heappush(openh, (ng + hcost, ng, zz, xx))
    return None


def to_coarse(x, z):
    return int(np.clip((z + HALF) // C, 0, NC - 1)), int(np.clip((x + HALF) // C, 0, NC - 1))


def from_coarse(cz, cx):
    return (cx * C - HALF + C / 2, cz * C - HALF + C / 2)


# --------------------------------------------------------------------------------------
# Assets (house footprints from the .vox files)
# --------------------------------------------------------------------------------------

def vox_dims(folder):
    path = os.path.join(ROOT, folder.replace("res://", ""), "body.vox")
    with open(path, "rb") as f:
        data = f.read()
    i = data.find(b"SIZE")
    sx, sy, sz = struct.unpack("<iii", data[i + 12:i + 24])
    rig = json.load(open(os.path.join(ROOT, folder.replace("res://", ""), "rig.json")))
    fmin = rig["parts"]["body"]["frame_min"]
    vs = rig["voxel_size"]
    gx, gy, gz = sy, sz, sx  # godot_voxel maps file (a, b, c) to Godot (b, c, a)
    lo = (fmin[0] * vs, fmin[1] * vs, fmin[2] * vs)
    hi = ((fmin[0] + gx) * vs, (fmin[1] + gy) * vs, (fmin[2] + gz) * vs)
    return lo, hi


ASSETS = {}


def asset(folder, solid_shrink=0.86):
    if folder not in ASSETS:
        lo, hi = vox_dims(folder)
        size = [(hi[0] - lo[0]) * solid_shrink, hi[1] - max(lo[1], 0) - 0.3, (hi[2] - lo[2]) * solid_shrink]
        center = [(lo[0] + hi[0]) * 0.5, size[1] * 0.5, (lo[2] + hi[2]) * 0.5]
        ASSETS[folder] = {"lo": lo, "hi": hi, "solid": size, "offset": center}
    return ASSETS[folder]


HOMES = {
    "woodland": ["res://props/houses/woodland_0", "res://props/houses/woodland_1", "res://props/houses/woodland_2",
                 "res://props/home/rose_cottage", "res://props/home/blue_bakery", "res://props/vesperis/cottage_moss",
                 "res://props/vesperis/cottage_plum", "res://props/vesperis/cottage_red", "res://props/vesperis/cottage_thatch",
                 "res://props/vesperis/house_blue", "res://props/vesperis/house_moss", "res://props/vesperis/house_plum",
                 "res://props/vesperis/townhouse_red", "res://props/vesperis/turret_house", "res://props/home/broad_lodge"],
    "fosen": ["res://props/houses/fosen_0", "res://props/houses/fosen_1", "res://props/houses/fosen_2",
              "res://props/vesperis/lodge_slate", "res://props/vesperis/cottage_thatch"],
    "desert": ["res://props/houses/desert_0", "res://props/houses/desert_1", "res://props/houses/desert_2"],
}
SERVICE = {
    "smith": "res://props/home/forge_house", "inn": "res://props/home/grand_tavern",
    "magician": "res://props/home/magicians_house", "herbalist": "res://props/home/rose_cottage",
}
BARNS = ["res://props/surface/barn_red", "res://props/surface/barn_grey"]
SHEDS = ["res://props/surface/shed"]
TENTS = ["res://props/surface/tent_canvas", "res://props/surface/tent_green", "res://props/surface/tent_red"]
WINDMILL = "res://props/surface/windmill"


# --------------------------------------------------------------------------------------
# The bake
# --------------------------------------------------------------------------------------

class World:
    pass


def main():
    W = World()
    log("continent...")
    land = continent()
    log("  land share %.2f" % land.mean())
    coast_in = distance_to(~land, 60)
    coast_out = distance_to(land, 50)
    log("biomes...")
    scores = biome_scores()
    stack = np.stack([scores[b] for b in BIOME_LIST])
    biome = np.array(BIOME_LIST, np.uint8)[np.argmax(stack, axis=0)]
    log("relief...")
    rel, weights, wtotal = relief(scores, land, coast_in, coast_out)
    vols = volcanoes(rel, scores, land)
    # Beaches on low coasts of the gentle biomes, ocean below the sea.
    beachy = land & (coast_in < 9 + 7 * fbm(rng, 30, N, 2)) & (rel < 2.6) & np.isin(biome, [WOODS, JUNGLE, DESERT, BLUELAY])
    biome = np.where(beachy, BEACH, biome).astype(np.uint8)
    biome = np.where(land, biome, OCEAN).astype(np.uint8)
    W.rel = rel
    W.biome = biome
    W.land = land
    W.coast_in = coast_in
    W.material = np.zeros((N, N), np.uint8)
    W.flags = np.zeros((N, N), np.uint8)
    W.water = np.zeros((N, N), np.float32)  # absolute meters, 0 = none
    W.current = np.zeros((N, N, 2), np.float32)  # river current per meter: x/z, length = speed
    W.json = {"size": N, "half": HALF, "sea": SEA, "volcanoes": vols, "settlements": [], "strongholds": [],
              "landmarks": [], "roads": [], "trails": [], "stairs": [], "beams": [], "posts": [], "waterfalls": [],
              "camps": [], "lights": [], "rivers": []}

    log("rivers...")
    rivers(W)
    keep_above_sea(W)
    log("water check...")
    settle_water(W)  # the water is final before anything is built beside it
    keep_above_sea(W)
    log("lava...")
    lava(W, vols)
    log("settlements...")
    settlements(W)
    log("strongholds...")
    strongholds(W)
    log("roads...")
    roads(W)
    log("trails...")
    trails(W)
    log("fields and camps...")
    fields(W)
    camps(W)
    keep_above_sea(W)
    log("reaching every plateau and island...")
    connect_land(W)
    log("materials...")
    materials(W)
    log("flora...")
    flora = forest(W)
    write(W, flora)


# --------------------------------------------------------------------------------------

def rivers(W):
    h4 = block_mean(W.rel, C)
    b4 = W.biome[C // 2::C, C // 2::C]
    rain_by = {WOODS: 1.0, JUNGLE: 1.3, FOSEN: 1.25, BLUELAY: 0.5, BEACH: 0.4, DESERT: 0.02, DEEP_DESERT: 0.0,
               DOOM: 0.0, DEEP_DARK: 0.05, OCEAN: 0.0}
    rain = np.vectorize(lambda b: rain_by.get(int(b), 0.0))(b4).astype(np.float32)
    filled = priority_flood(h4)
    acc, down = flow(filled, rain)
    land4 = h4 >= 0
    # Lakes: deep enough depressions that something flows into.
    depth = filled - h4
    lake4 = (depth > 1.1) & land4 & (acc > 180)
    lake4 = grow_components(lake4, 30)
    threshold = 520.0
    river4 = (acc > threshold) & land4 & ~lake4
    log("  river cells %d, lake cells %d" % (river4.sum(), lake4.sum()))
    # Lakes at 1 m: their surface is the filled level, beds slope down from the shore.
    lake_level = upscale(np.where(lake4, filled, 0), N, Image.NEAREST)
    lake1 = (lake_level > 0) & (W.rel < lake_level - 0.15)
    shore = distance_to(~lake1, 12)
    W.rel[:] = np.where(lake1, np.minimum(W.rel, lake_level - 0.4 - np.minimum(shore * 0.35, 3.0)), W.rel)
    W.water[:] = np.where(lake1, SEA + lake_level - 0.25, W.water)
    W.flags[lake1] |= F_LAKE
    # Lake shores slope gently up from the water, so you can wade out anywhere.
    shore_out = distance_to(lake1, 10)
    near = (~lake1) & (shore_out < 10)
    level_near = upscale(np.where(lake4, filled, 0), N, Image.NEAREST)
    spread = np.maximum.reduce([np.roll(np.roll(level_near, dz, 0), dx, 1) for dz in (-8, 0, 8) for dx in (-8, 0, 8)])
    has = near & (spread > 0)
    W.rel[has] = np.minimum(W.rel[has], spread[has] - 0.05 + shore_out[has] * 0.5)
    # Trace river polylines from their heads downstream.
    n = NC
    is_r = river4.flatten().tolist()
    up_count = [0] * (n * n)
    for i, r in enumerate(is_r):
        if r and down[i] >= 0 and is_r[down[i]]:
            up_count[down[i]] += 1
    visited = set()
    heads = [i for i, r in enumerate(is_r) if r and up_count[i] == 0]
    heads.sort(key=lambda i: -acc.flat[i])
    lines = []
    for hd in heads:
        line = []
        joins = False
        i = hd
        while i >= 0 and is_r[i]:
            line.append(i)
            if i in visited:
                joins = True
                break
            visited.add(i)
            i = down[i]
        if i >= 0 and not is_r[i]:
            line.append(i)  # into the sea or a lake
        if len(line) >= 6:
            lines.append((line, joins))
    rl = W.rel
    placed = []  # meandered courses so far, for tributaries to meet
    for line, joins in lines:
        pts = [from_coarse(i // n, i % n) for i in line]
        accs = [float(acc.flat[i]) for i in line]
        pts = chaikin(pts, 2)
        pts = resample(pts, 2.0)
        aw = np.interp(np.linspace(0, 1, len(pts)), np.linspace(0, 1, len(accs)), accs)
        widths = np.clip(1.1 + np.sqrt(aw) * 0.075, 1.2, 6.5)
        pts = meander(pts, widths)
        if joins and placed:
            # A tributary meets the bent course of the river it flows into.
            end = np.array(pts[-1])
            course = np.concatenate(placed)
            target = course[int(np.argmin(((course - end) ** 2).sum(1)))]
            shift = target - end
            k = len(pts)
            pts = [tuple(np.array(p) + shift * max(0.0, (i - (k - 12)) / 11.0)) for i, p in enumerate(pts)]
        pts = resample(chaikin(pts, 1), 2.0)
        placed.append(np.array(pts, np.float32))
        aw = np.interp(np.linspace(0, 1, len(pts)), np.linspace(0, 1, len(accs)), accs)
        widths = np.clip(1.1 + np.sqrt(aw) * 0.075, 1.2, 6.5)
        # Water surface: below the ground along the bed, never rising downstream.
        surf = []
        level = 1e9
        for (x, z), w in zip(pts, widths):
            pz, px = pix(x, z)
            r = int(max(1, w))
            ground = float(rl[max(pz - r, 0):pz + r + 1, max(px - r, 0):px + r + 1].min())
            level = min(level, ground - 0.35)
            surf.append(max(level, -0.2))
        # Smooth tiny wiggles but keep drops sharp (waterfalls).
        surf = np.array(surf, np.float32)
        for k in range(1, len(surf)):
            surf[k] = min(surf[k], surf[k - 1])
        record = {"points": [[round(x, 2), round(z, 2)] for x, z in pts], "width": [round(float(w), 2) for w in widths],
                  "surface": [round(float(SEA + s), 3) for s in surf]}
        W.json["rivers"].append(record)
        reach = float(widths.max()) + 10.0
        rows, cols, dist, val, along = segments_field(pts, reach, list(range(len(pts))))
        idx = np.clip(np.round(val).astype(int), 0, len(pts) - 1)
        w = widths[idx]
        s = surf[idx]
        inside = dist < w
        bed_depth = 0.3 + 0.55 * (1.0 - (dist / w) ** 2)  # wadeable all the way across
        bed = s - bed_depth
        r_in, c_in = rows[inside], cols[inside]
        rl[r_in, c_in] = np.minimum(rl[r_in, c_in], bed[inside])
        W.water[r_in, c_in] = np.maximum(W.water[r_in, c_in], SEA + s[inside])
        W.flags[r_in, c_in] |= F_RIVER
        # The current: along the river's course, faster where it drops.
        p_arr = np.array(pts, np.float32)
        ahead = p_arr[np.minimum(np.arange(len(pts)) + 2, len(pts) - 1)] - p_arr[np.maximum(np.arange(len(pts)) - 2, 0)]
        ahead /= np.maximum(np.linalg.norm(ahead, axis=1, keepdims=True), 1e-3)
        drop = surf[np.maximum(np.arange(len(pts)) - 2, 0)] - surf[np.minimum(np.arange(len(pts)) + 2, len(pts) - 1)]
        speed = np.clip(0.3 + drop / 4.0 * 6.0, 0.25, 1.0)
        reach_cur = dist < w + 1.5
        rc, cc = rows[reach_cur], cols[reach_cur]
        W.current[rc, cc] = ahead[idx[reach_cur]] * speed[idx[reach_cur], None]
        # Banks slope up from the water at a walkable grade (never a walled
        # channel you can't climb out of): a little valley along the river.
        bank = (~inside) & (dist < w + 10.0)
        rb, cb = rows[bank], cols[bank]
        rl[rb, cb] = np.minimum(rl[rb, cb], s[bank] + 0.2 + (dist[bank] - w[bank]) * 0.5)
        # Waterfalls where the surface drops sharply.
        k = 0
        while k < len(surf) - 3:
            drop = surf[k] - surf[k + 2]
            if drop > 1.4 and surf[k + 2] > -0.1:
                x, z = pts[k + 1]
                dx, dz = pts[k + 2][0] - pts[k][0], pts[k + 2][1] - pts[k][1]
                W.json["waterfalls"].append({"x": round(x, 2), "z": round(z, 2), "top": round(float(SEA + surf[k]), 2),
                                             "bottom": round(float(SEA + surf[k + 2]), 2), "width": round(float(widths[k]) * 2, 2),
                                             "dir": round(math.atan2(dz, dx), 3)})
                k += 4
            else:
                k += 1
    log("  rivers %d, waterfalls %d" % (len(lines), len(W.json["waterfalls"])))


# --------------------------------------------------------------------------------------
# Getting everywhere: stairs up stone walls, rope bridges to the islands
# --------------------------------------------------------------------------------------

CLIMB = 1.2  # meters between neighbouring cells the player can still step over
STAIR_REACH = 18  # meters a stair may span to reach a cut-off plateau
ISLAND_REACH = 170  # meters a rope bridge may span to an island


def land_components(W):
    """Areas you can walk around in without climbing a wall or swimming:
    a label per meter cell (0 = not walkable)."""
    deep = (W.water > 0) & (W.water - (W.rel + SEA) > 1.5)
    bridge = (W.flags & F_BRIDGE).astype(bool)
    walk = ((W.land & ~deep) | bridge) & (W.rel > -0.5)
    hl = W.rel.ravel().tolist()
    wl = walk.ravel().tolist()
    bl = bridge.ravel().tolist()
    labels = [0] * (N * N)
    sizes = [0]
    current = 0
    from collections import deque
    for start in range(N * N):
        if not wl[start] or labels[start]:
            continue
        current += 1
        labels[start] = current
        queue = deque([start])
        count = 0
        while queue:
            i = queue.popleft()
            count += 1
            h = hl[i]
            x = i % N
            for j in (i - 1 if x > 0 else -1, i + 1 if x < N - 1 else -1, i - N, i + N):
                if j < 0 or j >= N * N or labels[j] or not wl[j]:
                    continue
                if abs(hl[j] - h) <= CLIMB or bl[i] or bl[j]:
                    labels[j] = current
                    queue.append(j)
        sizes.append(count)
    return np.array(labels, np.int32).reshape(N, N), sizes


def nearest_to(mask, steps, scale=1):
    """For every cell within `steps` (cells) of `mask`: the distance and the
    flat index of the nearest mask cell (chamfer propagation)."""
    n = mask.shape[0]
    inf = np.float32(1e9)
    dist = np.where(mask, 0, inf).astype(np.float32)
    origin = np.where(mask, np.arange(n * n).reshape(n, n), -1).astype(np.int64)
    for _ in range(steps):
        changed = False
        for dz, dx, cost in ((1, 0, 1), (-1, 0, 1), (0, 1, 1), (0, -1, 1), (1, 1, 1.414), (1, -1, 1.414), (-1, 1, 1.414), (-1, -1, 1.414)):
            nd = np.roll(np.roll(dist, dz, 0), dx, 1) + cost
            no = np.roll(np.roll(origin, dz, 0), dx, 1)
            better = nd < dist
            if better.any():
                changed = True
                dist = np.where(better, nd, dist)
                origin = np.where(better, no, origin)
        if not changed:
            break
    return dist * scale, origin


def connect_land(W):
    capital = W.json["settlements"][0]["center"]
    stairs = 0
    bridges = 0
    for round_index in range(4):
        labels, sizes = land_components(W)
        main = labels[pix(*capital)]
        main_mask = labels == main
        dist, origin = nearest_to(main_mask, STAIR_REACH)
        made = 0
        for comp in range(1, len(sizes)):
            if comp == main or sizes[comp] < 300:
                continue
            cells = labels == comp
            d = np.where(cells, dist, 1e9)
            k = int(np.argmin(d))
            if d.flat[k] > STAIR_REACH:
                continue
            bz, bx = divmod(k, N)
            az, ax = divmod(int(origin.flat[k]), N)
            if carve_stairs(W, (ax - HALF + 0.5, az - HALF + 0.5), (bx - HALF + 0.5, bz - HALF + 0.5)):
                made += 1
        stairs += made
        if made == 0:
            break
    # Islands across the water: rope bridges, measured on a 4 m grid.
    labels, sizes = land_components(W)
    main = labels[pix(*capital)]
    coarse_main = block_mean((labels == main).astype(np.float32), C) > 0.3
    dist, origin = nearest_to(coarse_main, ISLAND_REACH // C, C)
    for comp in range(1, len(sizes)):
        if comp == main or sizes[comp] < 2500:
            continue
        cells = block_mean((labels == comp).astype(np.float32), C) > 0.5
        d = np.where(cells, dist, 1e9)
        k = int(np.argmin(d))
        if d.flat[k] > ISLAND_REACH:
            continue
        bz, bx = divmod(k, NC)
        az, ax = divmod(int(origin.flat[k]), NC)
        a = from_coarse(az, ax)
        b = from_coarse(bz, bx)
        if rope_bridge(W, a, b, labels, main, comp):
            bridges += 1
    log("  stairs up walls %d, rope bridges %d" % (stairs, bridges))


def carve_stairs(W, a, b):
    """A narrow path with wooden stairs from a (reachable ground) up or down a
    stone wall to b (a cut-off plateau), cut into the rock with railings."""
    ha = float(W.rel[pix(*a)])
    hb = float(W.rel[pix(*b)])
    dx, dz = b[0] - a[0], b[1] - a[1]
    length = math.hypot(dx, dz)
    if length < 0.5:
        return False
    ux, uz = dx / length, dz / length
    run = max(length + 2.0, abs(hb - ha) / 0.8 + 2.0)
    start = (a[0] - ux * 1.5, a[1] - uz * 1.5)
    pts = [(start[0] + ux * t, start[1] + uz * t) for t in np.arange(0, run + 1.5, 0.5)]
    for x, z in pts:
        q = pix(x, z)
        if W.water[q] > 0 or W.occupied[q] == 2 or not W.land[q]:
            return False
    heights = np.interp(np.linspace(0, 1, len(pts)), [0, 1.5 / (run + 1.5), 1], [ha, ha, hb]).astype(np.float32)
    half = 0.8
    rows, cols, dist, val, along = segments_field(pts, half + 0.8, list(range(len(pts))))
    idx = np.clip(np.round(val).astype(int), 0, len(pts) - 1)
    core = dist < half
    W.rel[rows[core], cols[core]] = heights[idx[core]]
    band = ~core
    t = smoothstep(half, half + 0.8, dist[band])
    W.rel[rows[band], cols[band]] = W.rel[rows[band], cols[band]] * t + heights[idx[band]] * (1 - t)
    W.material[rows[core], cols[core]] = M_STAIRS
    W.flags[rows[core], cols[core]] |= F_TRAIL
    W.occupied[rows[core], cols[core]] = np.maximum(W.occupied[rows[core], cols[core]], 1)
    W.json["stairs"].append({"points": [[round(p[0], 2), round(p[1], 2)] for p in pts],
                             "heights": [round(float(SEA + h), 2) for h in heights]})
    rails(W, pts, half + 0.2, [float(h) for h in heights], 1.5)
    return True


def rope_bridge(W, a, b, labels, main, comp):
    """A hanging bridge over the water from the mainland to an island:
    timber towers at both ends, a plank deck that sags (but stays well above
    the waves) and rope rails with hangers."""
    # Step each end a few meters onto its own dry land.
    dx, dz = b[0] - a[0], b[1] - a[1]
    length = math.hypot(dx, dz)
    ux, uz = dx / length, dz / length
    # Each end steps back onto its own land until the ground is well above
    # the sea (towers stand on dry rock, the deck never meets the waves).
    for k in range(16):
        if labels[pix(*a)] == main and W.water[pix(*a)] <= 0 and W.rel[pix(*a)] > 0.7:
            break
        a = (a[0] + ux, a[1] + uz)
    for k in range(16):
        if labels[pix(*b)] == comp and W.water[pix(*b)] <= 0 and W.rel[pix(*b)] > 0.7:
            break
        b = (b[0] - ux, b[1] - uz)
    for k in range(20):
        if W.rel[pix(*a)] >= 2.0 or labels[pix(a[0] - ux, a[1] - uz)] != main:
            break
        a = (a[0] - ux, a[1] - uz)
    for k in range(20):
        if W.rel[pix(*b)] >= 2.0 or labels[pix(b[0] + ux, b[1] + uz)] != comp:
            break
        b = (b[0] + ux, b[1] + uz)
    if W.rel[pix(*a)] < 1.6 or W.rel[pix(*b)] < 1.6:
        return False  # both shores too low for a hanging bridge
    length = math.hypot(b[0] - a[0], b[1] - a[1])
    if length < 6 or length > ISLAND_REACH + 20:
        return False
    ha = SEA + float(W.rel[pix(*a)]) + 0.25
    hb = SEA + float(W.rel[pix(*b)]) + 0.25
    n = int(length)
    pts = [(a[0] + (b[0] - a[0]) * i / n, a[1] + (b[1] - a[1]) * i / n) for i in range(n + 1)]
    lowest = SEA + 2.5
    sag = min(length * 0.035, max(0.0, min(ha, hb) - lowest))
    deck = [max(ha + (hb - ha) * i / n - sag * 4 * (i / n) * (1 - i / n), SEA + 1.8) for i in range(n + 1)]
    W.json["beams"].append({"line": [[round(p[0], 2), round(p[1], 2), round(y, 2)] for p, y in zip(pts, deck)],
                            "width": 1.7, "thick": 0.25, "block": "planks", "deck": True})
    rows, cols, dist, val, along = segments_field(pts, 1.0)
    W.flags[rows, cols] |= F_BRIDGE | F_TRAIL
    nx, nz = -uz, ux
    for side in (-1, 1):
        rope = []
        for i, (p, y) in enumerate(zip(pts, deck)):
            t = i / n
            q = (p[0] + nx * side * 0.95, p[1] + nz * side * 0.95)
            lift = 1.1 + (1 - 4 * t * (1 - t)) * 2.2  # high at the towers, down to the rail in the middle
            rope.append([round(q[0], 2), round(q[1], 2), round(y + lift, 2)])
            if i % 2 == 0:
                W.json["posts"].append({"x": q[0], "z": q[1], "y0": round(y - 0.25, 2), "y1": round(y + lift, 2), "block": "timber"})
        W.json["beams"].append({"line": rope, "width": 0.25, "thick": 0.25, "block": "timber"})
        for end, y in ((pts[0], deck[0]), (pts[-1], deck[-1])):
            q = (end[0] + nx * side * 1.1, end[1] + nz * side * 1.1)
            W.json["posts"].append({"x": q[0], "z": q[1], "y0": round(y - 2.0, 2), "y1": round(y + 3.8, 2), "block": "timber"})
    return True


def keep_above_sea(W):
    """The sea is one plane over the whole map (8.6 m), so dry ground inland
    must stay above it, or the sea shows through in fields and valleys. Only
    the coast itself slopes down under it."""
    marsh = (W.biome == BLUELAY) & ~(W.flags & (F_ROAD | F_TRAIL | F_TOWN | F_FIELD | F_CLEAR)).astype(bool)
    inland = W.land & (W.coast_in > 6) & (W.water <= 0) & (W.rel < 0.8) & ~marsh  # Bluelay keeps its pools
    W.rel[inland] = 0.8
    log("  raised %d low inland cells above the sea" % int(inland.sum()))


def settle_water(W):
    """Water sits in its bed, never in the air.

    Lakes are flat and can't stand higher than their lowest way out: a lake
    that touches a river or lower ground drains down to that level (cells left
    above the new level dry out). Rivers keep their slope and falls. Where a
    river's edge would hang over lower dry ground, that ground rises into a
    bank (built ground a little above the water); where the drop is too big
    for a bank, the edge water goes instead."""
    lake = (W.flags & F_LAKE).astype(bool) & (W.water > 0)
    level = W.water.copy()
    ground = W.rel + SEA
    big = np.float32(1e9)
    for it in range(400):
        wet = level > 0
        spill = np.full((N, N), big, np.float32)
        for dz, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            ng = np.roll(np.roll(ground, dz, 0), dx, 1)
            nl = np.roll(np.roll(level, dz, 0), dx, 1)
            nw = nl > 0
            out = np.where(nw, np.maximum(ng, nl), ng)
            spill = np.minimum(spill, out)
        new = np.where(lake & wet, np.minimum(level, spill), level)
        new = np.where(lake & (new <= ground + 0.05), 0, new)
        if np.array_equal(new, level):
            break
        level = new
    drained = lake & (level <= 0)
    W.water = level
    W.flags[drained] &= ~np.uint8(F_LAKE)
    for _ in range(6):
        wet = W.water > 0
        ground = W.rel + SEA
        dried = wet & (ground >= W.water - 0.05)
        W.water[dried] = 0
        W.flags[dried] &= ~np.uint8(F_RIVER | F_LAKE)
        wet = W.water > 0
        p = np.pad(W.water, 1)
        neighbour = np.maximum.reduce([p[1 + dz:N + 1 + dz, 1 + dx:N + 1 + dx] for dz in (-1, 0, 1) for dx in (-1, 0, 1)])
        low = ~wet & (neighbour > 0) & (ground < neighbour - 0.05) & W.land
        if not low.any():
            break
        bank = low & (neighbour - ground < 1.5)
        W.rel[bank] = neighbour[bank] - SEA + 0.05
        # Too deep a drop for a bank: the water beside it goes.
        cliff = low & ~bank
        if cliff.any():
            pc = np.pad(cliff, 1)
            touching = np.logical_or.reduce([pc[1 + dz:N + 1 + dz, 1 + dx:N + 1 + dx] for dz in (-1, 0, 1) for dx in (-1, 0, 1)])
            gone = wet & touching & (W.water > ground.max() * 0 + (W.rel + SEA) - 0.0)
            W.water[gone] = 0
            W.flags[gone] &= ~np.uint8(F_RIVER | F_LAKE)
    log("  water cells %d, lakes drained %d" % (int((W.water > 0).sum()), int(drained.sum())))


def meander(pts, widths):
    """Bends a river's course into natural S-curves: two waves along its
    length, bigger and longer on wide rivers, calming down at the source
    and toward the mouth or join so the river still arrives where it flows."""
    p = np.array(pts, np.float64)
    if len(p) < 8:
        return pts
    seg = np.sqrt(((p[1:] - p[:-1]) ** 2).sum(1))
    s = np.concatenate([[0.0], np.cumsum(seg)])
    total = s[-1]
    # Smoothed direction, so the bends follow the valley and not the grid.
    k = 6
    ahead = p[np.minimum(np.arange(len(p)) + k, len(p) - 1)] - p[np.maximum(np.arange(len(p)) - k, 0)]
    ahead /= np.maximum(np.linalg.norm(ahead, axis=1, keepdims=True), 1e-6)
    normal = np.stack([-ahead[:, 1], ahead[:, 0]], 1)
    w = np.interp(s, np.linspace(0, total, len(widths)), widths)
    amp = np.clip(5.0 + w * 2.2, 6.0, 16.0)
    wave = 38.0 + w * 7.0
    phase1, phase2 = prng.uniform(0, math.tau), prng.uniform(0, math.tau)
    off = amp * (0.72 * np.sin(math.tau * s / wave + phase1) + 0.28 * np.sin(math.tau * s / (wave * 0.41) + phase2))
    off *= smoothstep(0.0, 26.0, s) * smoothstep(0.0, 30.0, total - s)
    bent = p + normal * off[:, None]
    return [tuple(q) for q in bent]


def grow_components(mask, min_cells):
    """Drops components smaller than min_cells (4-connected)."""
    n = mask.shape[0]
    seen = np.zeros_like(mask)
    out = np.zeros_like(mask)
    ml = mask.tolist()
    for z in range(n):
        for x in range(n):
            if ml[z][x] and not seen[z, x]:
                comp = [(z, x)]
                seen[z, x] = True
                k = 0
                while k < len(comp):
                    cz, cx = comp[k]
                    k += 1
                    for dz, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                        zz, xx = cz + dz, cx + dx
                        if 0 <= zz < n and 0 <= xx < n and ml[zz][xx] and not seen[zz, xx]:
                            seen[zz, xx] = True
                            comp.append((zz, xx))
                if len(comp) >= min_cells:
                    for p in comp:
                        out[p] = True
    return out


def lava(W, vols):
    """Lava lakes in the craters and lava rivers running down the flanks."""
    W.lava = np.zeros((N, N), bool)
    for v in vols:
        d = np.sqrt((WX - v["x"]) ** 2 + (WZ - v["z"]) ** 2)
        crater = d < v["crater"] * 0.8
        W.rel[crater] = np.minimum(W.rel[crater], v["lake"] - SEA)
        W.lava |= crater
        W.json["lights"].append({"x": v["x"], "y": v["lake"] + 3.0, "z": v["z"], "color": [1.0, 0.45, 0.12],
                                 "energy": 4.0, "range": v["crater"] * 1.6})
        for k in range(3 if v["r"] > 100 else 1):
            a = prng.uniform(0, math.tau)
            x = v["x"] + math.cos(a) * v["crater"] * 1.05
            z = v["z"] + math.sin(a) * v["crater"] * 1.05
            pts = [(x, z)]
            for step in range(260):
                pz, px = pix(x, z)
                best = None
                for ang in np.linspace(0, math.tau, 16, endpoint=False):
                    nx, nz = x + math.cos(ang) * 3.0, z + math.sin(ang) * 3.0
                    qz, qx = pix(nx, nz)
                    hv = W.rel[qz, qx] + 0.08 * math.cos(ang - a)  # keep going outward
                    if best is None or hv < best[0]:
                        best = (hv, nx, nz)
                if best[0] > W.rel[pz, px] + 0.2 or best[0] < 1.0 or W.biome[pz, px] != DOOM:
                    break
                x, z = best[1], best[2]
                pts.append((x, z))
            if len(pts) < 10:
                continue
            pts = resample(chaikin(pts, 2), 1.5)
            rows, cols, dist, val, along = segments_field(pts, 4.5)
            w = 1.6 + 1.4 * np.sin(along * 23.0) ** 2
            inside = dist < w
            W.rel[rows[inside], cols[inside]] -= 0.5
            W.lava[rows[inside], cols[inside]] = True
            for p in pts[::14]:
                pz, px = pix(*p)
                W.json["lights"].append({"x": p[0], "y": float(SEA + W.rel[pz, px] + 1.6), "z": p[1],
                                         "color": [1.0, 0.42, 0.1], "energy": 2.4, "range": 9.0})


# --------------------------------------------------------------------------------------
# Settlements
# --------------------------------------------------------------------------------------

NAMES = {
    WOODS: ["Mossford", "Willowmere", "Thistledown", "Fernhollow", "Oakhaven", "Lanternbrook", "Briarwood",
            "Honeyvale", "Elderglen", "Bramblecross", "Applewick", "Hollytree"],
    JUNGLE: ["Vinecradle", "Orchid Rest", "Parrot Hollow"],
    FOSEN: ["Frostpine", "Rimeholt", "Kettlefell"],
    DESERT: ["Dunewell", "Amberreach", "Saltcairn"],
    BLUELAY: ["Glimmerreach", "Mistmarsh"],
    BEACH: ["Kettlecove", "Gullsrest", "Driftwood Bay"],
}
FARM_NAMES = ["Hollin Farm", "Pike's Barn", "Burrow Croft", "Old Mill", "Clover Croft", "Sedge Farm", "Lark Meadow",
              "Hayward's", "Wren Croft", "Fallowfield", "Tansy Farm", "Rook's End", "Dunmore Croft", "Ashby Farm",
              "Merrow Farm", "Bell Croft", "Cobble Farm", "Thornbury", "Pippin Farm", "Quill Croft"]
MAP_COLORS = [(1.0, 0.8, 0.35), (0.55, 0.85, 0.45), (0.95, 0.55, 0.4), (0.6, 0.75, 1.0), (0.95, 0.75, 0.95),
              (0.75, 0.95, 0.9), (1.0, 0.65, 0.25), (0.85, 0.85, 0.55)]


def stats_maps(W):
    h4 = block_mean(W.rel, C)
    m1 = box_blur(h4, 3)
    m2 = box_blur(h4 * h4, 3)
    W.rough12 = np.sqrt(np.maximum(m2 - m1 * m1, 0))
    m1 = box_blur(h4, 8)
    m2 = box_blur(h4 * h4, 8)
    W.rough32 = np.sqrt(np.maximum(m2 - m1 * m1, 0))
    wet = (W.water > 0) | ~W.land | W.lava
    W.wet_dist4 = distance_to(block_mean(wet.astype(np.float32), C) > 0.05, 30) * C
    W.occupied = np.zeros((N, N), np.uint8)  # 1 lane / road, 2 building or blocked


def pick_site(W, biomes, min_gap, others, rough_key="rough12", rough_max=1.0, near=None, avoid_wet=12.0, tries=None,
              prefer_water=False):
    best = None
    cand = tries or 900
    for _ in range(cand):
        if near is not None:
            x = near[0] + prng.uniform(-near[2], near[2])
            z = near[1] + prng.uniform(-near[2], near[2])
        else:
            x = prng.uniform(-HALF + 60, HALF - 60)
            z = prng.uniform(-HALF + 60, HALF - 60)
        pz, px = pix(x, z)
        if W.biome[pz, px] not in biomes or not W.land[pz, px] or W.rel[pz, px] < 0.9:
            continue
        cz, cx = to_coarse(x, z)
        if W.wet_dist4[cz, cx] < avoid_wet:
            continue
        rough = getattr(W, rough_key)[cz, cx]
        if rough > rough_max:
            continue
        if any(math.hypot(x - o[0], z - o[1]) < max(min_gap, o[2]) for o in others):
            continue
        score = -rough + prng.random() * 0.3
        if prefer_water:
            score -= W.wet_dist4[cz, cx] * 0.01
        if best is None or score > best[0]:
            best = (score, x, z)
    return None if best is None else (best[1], best[2])


def flatten(W, rows, cols, target, skirt_rows=None, skirt_cols=None, skirt_t=None):
    """Levels a pad (and blends its skirt), never touching water or the sea:
    the ground under a river stays the river's."""
    dry = (W.water[rows, cols] <= 0) & W.land[rows, cols]
    W.rel[rows[dry], cols[dry]] = target
    if skirt_rows is not None and len(skirt_rows):
        dry = (W.water[skirt_rows, skirt_cols] <= 0) & W.land[skirt_rows, skirt_cols]
        r, c, t = skirt_rows[dry], skirt_cols[dry], skirt_t[dry]
        W.rel[r, c] = W.rel[r, c] * t + target * (1 - t)


def rect_pixels(cx, cz, hx, hz, yaw, grow=0.0):
    """Pixels inside a rectangle turned by `yaw` (Godot Y rotation), plus the
    signed outside distance for a skirt band."""
    r = math.hypot(hx, hz) + grow + 1
    z0, x0 = pix(cx - r, cz - r)
    z1, x1 = pix(cx + r, cz + r)
    gz, gx = np.mgrid[z0:z1 + 1, x0:x1 + 1]
    px = gx - HALF + 0.5 - cx
    pz = gz - HALF + 0.5 - cz
    c, s = math.cos(yaw), math.sin(yaw)
    lx = px * c - pz * s
    lz = px * s + pz * c
    out = np.maximum(np.abs(lx) - hx, np.abs(lz) - hz)
    return gz, gx, out


def place_building(W, folder, x, z, yaw, role="home", skirt=2.5, check=True, scale=1.0, kind="house", margin=0.8):
    a = asset(folder)
    lo, hi = a["lo"], a["hi"]
    # The footprint's center in local space, turned into the world.
    lcx, lcz = (lo[0] + hi[0]) * 0.5 * scale, (lo[2] + hi[2]) * 0.5 * scale
    c, s = math.cos(yaw), math.sin(yaw)
    wx = x + lcx * c + lcz * s
    wz = z - lcx * s + lcz * c
    hx, hz = (hi[0] - lo[0]) * 0.5 * scale, (hi[2] - lo[2]) * 0.5 * scale
    gz, gx, out = rect_pixels(wx, wz, hx, hz, yaw, skirt + 1)
    inner = out <= margin
    if check:
        if not inner.any():
            return None
        if W.occupied[gz[inner], gx[inner]].max() > 0:
            return None
        if (W.water[gz[inner], gx[inner]] > 0).any() or (~W.land[gz[inner], gx[inner]]).any() or W.lava[gz[inner], gx[inner]].any():
            return None
        hs = W.rel[gz[inner], gx[inner]]
        if hs.max() - hs.min() > 3.2 or hs.min() < 0.6:
            return None
    pad = out <= 0.6
    target = float(np.median(W.rel[gz[pad], gx[pad]]))
    target = round(target * FINE) / FINE
    band = (out > 0.6) & (out < skirt)
    t = smoothstep(0.6, skirt, out[band])
    flatten(W, gz[pad], gx[pad], target, gz[band], gx[band], t)
    W.occupied[gz[out <= margin], gx[out <= margin]] = 2
    W.flags[gz[out <= 1.5], gx[out <= 1.5]] |= F_CLEAR
    W.material[gz[(out > 0) & (out < 1.6)], gx[(out > 0) & (out < 1.6)]] = M_YARD
    return {"asset": folder, "pos": [round(x, 3), round(SEA + target, 3), round(z, 3)], "yaw": round(yaw, 4),
            "role": role, "solid": [round(v * scale, 3) for v in a["solid"]],
            "offset": [round(v * scale, 3) for v in a["offset"]], "scale": scale, "kind": kind}


def lane(W, start, angle, length, step=2.0, max_slope=0.42):
    pts = [start]
    x, z = start
    a = angle
    for _ in range(int(length / step)):
        best = None
        for da in (-0.35, -0.15, 0.0, 0.15, 0.35):
            na = a + da + prng.uniform(-0.05, 0.05)
            nx, nz = x + math.cos(na) * step, z + math.sin(na) * step
            pz, px = pix(nx, nz)
            qz, qx = pix(x, z)
            if W.water[pz, px] > 0 or not W.land[pz, px] or W.occupied[pz, px] == 2 or W.lava[pz, px]:
                continue
            slope = abs(W.rel[pz, px] - W.rel[qz, qx]) / step
            if slope > max_slope:
                continue
            score = -slope - abs(da) * 0.4
            if best is None or score > best[0]:
                best = (score, na, nx, nz)
        if best is None:
            break
        _, a, x, z = best
        pts.append((x, z))
    return pts


def carve_path(W, pts, half, material, flag, grade, shoulder=2.5, smooth=6, deck_over_water=True, stairs_grade=None,
               record=None):
    """Grades a path into the terrain: a smoothed height profile with a
    maximum grade, the ground cut / filled to it across `half` and blended
    back over `shoulder`. Steep stretches (stairs_grade) become stairs."""
    pts = resample(pts, 1.0)
    if len(pts) < 2:
        return None
    hs = []
    wet = []
    for x, z in pts:
        pz, px = pix(x, z)
        hs.append(float(W.rel[pz, px]))
        # A bridge span where the path itself crosses water (its middle third).
        r = max(0, int(half * 0.35))
        window = W.water[max(pz - r, 0):pz + r + 1, max(px - r, 0):px + r + 1]
        sea = not W.land[max(pz - r, 0):pz + r + 1, max(px - r, 0):px + r + 1].all()
        wet.append(float(window.max()) - SEA if window.max() > 0 else (0.0 if sea else -99))
    hs = np.array(hs, np.float32)
    wet = np.array(wet, np.float32)
    k = np.ones(2 * smooth + 1) / (2 * smooth + 1)
    prof = np.convolve(np.pad(hs, smooth, mode="edge"), k, mode="valid")
    # Over water the road becomes a bridge deck above the surface.
    over = wet > -50
    if deck_over_water:
        prof = np.where(over, np.maximum(prof, wet + 1.0), prof)
    steep = np.zeros(len(prof), bool)
    for _ in range(3):
        for i in range(1, len(prof)):
            prof[i] = np.clip(prof[i], prof[i - 1] - grade, prof[i - 1] + grade)
        for i in range(len(prof) - 2, -1, -1):
            prof[i] = np.clip(prof[i], prof[i + 1] - grade, prof[i + 1] + grade)
    if deck_over_water and over.any():
        # Grading may have pulled a span down toward the water: lift it back to
        # a meter above the surface and raise the approaches to meet it.
        floor = np.where(over, wet + 1.0, -1e9)
        prof = np.maximum(prof, floor)
        for i in range(1, len(prof)):
            prof[i] = max(prof[i], prof[i - 1] - grade)
        for i in range(len(prof) - 2, -1, -1):
            prof[i] = max(prof[i], prof[i + 1] - grade)
    if stairs_grade is not None:
        # Stairs: where the terrain itself is steeper than walkable, follow it.
        raw = np.convolve(np.pad(hs, 2, mode="edge"), np.ones(5) / 5, mode="valid")
        diff = np.abs(np.gradient(raw))
        steep = diff > stairs_grade
        steep = np.convolve(steep.astype(float), np.ones(5), mode="same") > 0
        prof = np.where(steep, raw, prof)
    rows, cols, dist, val, along = segments_field(pts, half + shoulder, list(range(len(pts))))
    idx = np.clip(np.round(val).astype(int), 0, len(pts) - 1)
    target = prof[idx]
    is_over = over[idx]
    core = dist < half
    keep_bed = core & is_over  # bridges leave the river bed alone
    # Where the road's edge only brushes a river, that strip becomes bank.
    brush = core & ~is_over & (W.water[rows, cols] > 0)
    if brush.any():
        br, bc = rows[brush], cols[brush]
        W.rel[br, bc] = np.maximum(target[brush], W.water[br, bc] - SEA + 0.15)
        W.water[br, bc] = 0
        W.flags[br, bc] &= ~np.uint8(F_RIVER | F_LAKE)
    cut = core & ~is_over & (W.water[rows, cols] <= 0) & ~brush
    W.rel[rows[cut], cols[cut]] = target[cut]
    band = (dist >= half) & ~is_over & (W.water[rows, cols] <= 0)
    t = smoothstep(half, half + shoulder, dist[band])
    W.rel[rows[band], cols[band]] = W.rel[rows[band], cols[band]] * t + target[band] * (1 - t)
    mat = np.full(cut.sum(), material, np.uint8)
    if stairs_grade is not None:
        mat[steep[idx][cut]] = M_STAIRS
    W.material[rows[cut], cols[cut]] = np.where(W.material[rows[cut], cols[cut]] == M_PLAZA, M_PLAZA, mat)
    W.flags[rows[core], cols[core]] |= flag
    W.occupied[rows[core], cols[core]] = np.maximum(W.occupied[rows[core], cols[core]], 1)
    W.flags[rows[keep_bed], cols[keep_bed]] |= F_BRIDGE
    # Bridge decks and stair railings are voxel beams and posts.
    if deck_over_water and over.any():
        runs = runs_of(over)
        for a, b in runs:
            a0, b0 = max(a - 2, 0), min(b + 2, len(pts) - 1)
            seg = pts[a0:b0 + 1]
            # The deck follows the graded road, so it meets the ground at both
            # ends without a step.
            heights = [float(prof[i]) for i in range(a0, b0 + 1)]
            W.json["beams"].append({"line": [[round(p[0], 2), round(p[1], 2), round(SEA + h, 2)] for p, h in zip(seg, heights)],
                                    "width": round(half * 2 + 0.6, 2), "thick": 0.5, "block": "planks", "deck": True})
            rails(W, pts[a:b + 1], half + 0.25, [float(prof[i]) for i in range(a, b + 1)], 1.6)
    if stairs_grade is not None and steep.any():
        for a, b in runs_of(steep):
            if b - a < 2:
                continue
            seg = pts[a:b + 1]
            W.json["stairs"].append({"points": [[round(p[0], 2), round(p[1], 2)] for p in seg],
                                     "heights": [round(float(SEA + prof[i]), 2) for i in range(a, b + 1)]})
            rails(W, seg, half + 0.2, [float(prof[i]) for i in range(a, b + 1)], 1.5)
    if record is not None:
        record["points"] = [[round(p[0], 2), round(p[1], 2)] for p in pts[::2]]
    return prof


def runs_of(mask):
    out = []
    start = None
    for i, v in enumerate(list(mask) + [False]):
        if v and start is None:
            start = i
        elif not v and start is not None:
            out.append((start, i - 1))
            start = None
    return out


def rails(W, pts, offset, heights, spacing):
    """Posts and a handrail on both sides of a path (stairs, bridges)."""
    for side in (-1, 1):
        rail = []
        acc = 0.0
        for i in range(len(pts)):
            a = pts[max(i - 1, 0)]
            b = pts[min(i + 1, len(pts) - 1)]
            dx, dz = b[0] - a[0], b[1] - a[1]
            ln = math.hypot(dx, dz) or 1.0
            nx, nz = -dz / ln * side, dx / ln * side
            p = (pts[i][0] + nx * offset, pts[i][1] + nz * offset)
            y = SEA + heights[i]
            rail.append([round(p[0], 2), round(p[1], 2), round(y + 0.95, 2)])
            if i > 0:
                acc += math.hypot(pts[i][0] - pts[i - 1][0], pts[i][1] - pts[i - 1][1])
            if i == 0 or acc >= spacing or i == len(pts) - 1:
                acc = 0.0
                W.json["posts"].append({"x": p[0], "z": p[1], "y0": round(y - 1.5, 2), "y1": round(y + 1.15, 2), "block": "timber"})
        W.json["beams"].append({"line": rail, "width": 0.25, "thick": 0.25, "block": "timber"})


def settlement(W, name, kind, biome_id, x, z, color):
    theme = "fosen" if biome_id == FOSEN else "desert" if biome_id in (DESERT, DEEP_DESERT) else "woodland"
    size = {"capital": (12.0, 6, 46, 26), "town": (9.5, 4, 36, 14), "village": (6.5, 3, 26, 7), "hamlet": (0, 1, 14, 1)}[kind]
    plaza_r, lanes, reach, wanted = size
    pz, px = pix(x, z)
    base = float(W.rel[pz, px])
    s = {"name": name, "kind": kind, "biome": int(biome_id), "center": [round(x, 2), round(z, 2)], "radius": reach + 10.0,
         "plaza_radius": plaza_r, "height": round(SEA + round(base * FINE) / FINE, 3), "map_color": color, "houses": [], "props": [],
         "trees": [], "lights": [], "exits": []}
    # The plaza: a flat paved disc (or a farmyard for a hamlet).
    r_flat = max(plaza_r, 5.0) + 1.0
    gz, gx, out = rect_pixels(x, z, r_flat, r_flat, 0.0, 6)
    d = np.sqrt((gx - HALF + 0.5 - x) ** 2 + (gz - HALF + 0.5 - z) ** 2)
    target = round(base * FINE) / FINE
    inner = d <= r_flat
    band = (d > r_flat) & (d < r_flat + 5)
    flatten(W, gz[inner], gx[inner], target, gz[band], gx[band], smoothstep(r_flat, r_flat + 5, d[band]))
    W.flags[gz[d < reach + 8], gx[d < reach + 8]] |= F_TOWN
    if plaza_r > 0:
        pl = d <= plaza_r
        W.material[gz[pl], gx[pl]] = M_PLAZA
        W.occupied[gz[pl], gx[pl]] = 1
        W.flags[gz[pl], gx[pl]] |= F_CLEAR
        well = place_building(W, "res://props/town/well", x + plaza_r * 0.35, z - plaza_r * 0.2, prng.uniform(0, math.tau), "prop",
                              skirt=0.5, check=False, kind="prop")
        s["props"].append(well)
    street_mat = M_ROAD_COBBLE if kind in ("capital", "town") else M_ROAD_DIRT
    if theme == "desert":
        street_mat = M_ROAD_SAND
    elif theme == "fosen" and kind not in ("capital", "town"):
        street_mat = M_ROAD_SNOW
    lane_paths = []
    a0 = prng.uniform(0, math.tau)
    for k in range(lanes):
        a = a0 + k * math.tau / lanes + prng.uniform(-0.3, 0.3)
        start = (x + math.cos(a) * max(plaza_r - 1.0, 1.0), z + math.sin(a) * max(plaza_r - 1.0, 1.0))
        pts = lane(W, start, a, reach * prng.uniform(0.75, 1.05))
        if len(pts) < 5:
            continue
        pts = chaikin(pts, 2)
        half = 1.9 if kind == "capital" else 1.6 if kind == "town" else 1.25
        if kind == "hamlet":
            half = 1.0
        carve_path(W, pts, half, street_mat if kind != "hamlet" else M_TRAIL, F_ROAD, 0.3, shoulder=2.0, smooth=3)
        lane_paths.append((pts, half))
        s["exits"].append(round(a, 4))
    # Houses along the lanes, doors toward the lane, then a few tucked behind.
    service_roles = []
    if kind == "capital":
        service_roles = ["smith", "inn"]
    elif kind == "town":
        service_roles = ["smith" if theme == "fosen" else "magician" if theme == "desert" else "herbalist", "inn"]
    houses = []
    for pts, half in lane_paths:
        total = sum(math.hypot(b[0] - a[0], b[1] - a[1]) for a, b in zip(pts[:-1], pts[1:]))
        for side in (1, -1):
            walked = prng.uniform(2.0, 5.0)
            while walked < total - 2 and len(houses) < wanted:
                p, tangent = along_path(pts, walked)
                nx, nz = -tangent[1] * side, tangent[0] * side
                role = service_roles[len(houses)] if len(houses) < len(service_roles) else "home"
                folder = SERVICE[role] if role in SERVICE and role != "herbalist" else prng.choice(HOMES[theme])
                if theme == "desert" and role in ("magician", "inn"):
                    folder = prng.choice(HOMES["desert"])
                if theme == "fosen" and role == "inn":
                    folder = prng.choice(HOMES["fosen"])
                a = asset(folder)
                depth = (a["hi"][2] - a["lo"][2]) * 0.5
                setback = half + prng.uniform(1.4, 3.2) + depth
                hx, hz = p[0] + nx * setback, p[1] + nz * setback
                # The front (-Z) faces back toward the lane.
                yaw = math.atan2(nx, nz) + prng.uniform(-0.12, 0.12)
                b = place_building(W, folder, hx, hz, yaw, role)
                if b:
                    houses.append(b)
                    door = (hx - nx * (depth + 0.4), hz - nz * (depth + 0.4))
                    carve_path(W, [door, (p[0] + nx * (half - 0.3), p[1] + nz * (half - 0.3))], 0.7, M_TRAIL, F_ROAD, 0.5,
                               shoulder=0.8, smooth=0)
                    walked += (a["hi"][0] - a["lo"][0]) + prng.uniform(2.5, 7.0)
                else:
                    walked += 1.5
    s["houses"] = houses
    # Barns and sheds at the edge, fields beyond (fields() fills them in).
    extras = {"capital": 2, "town": 2, "village": 1, "hamlet": 1}[kind]
    for k in range(40):
        if extras == 0:
            break
        a = prng.uniform(0, math.tau)
        r = reach * prng.uniform(0.55, 0.95) if kind != "hamlet" else prng.uniform(9, 14)
        bx, bz = x + math.cos(a) * r, z + math.sin(a) * r
        folder = prng.choice(BARNS) if prng.random() < 0.75 else SHEDS[0]
        b = place_building(W, folder, bx, bz, math.atan2(x - bx, z - bz) + math.pi + prng.uniform(-0.3, 0.3), "barn", kind="barn")
        if b:
            s["houses"].append(b)
            extras -= 1
    if kind == "hamlet":
        # The farmhouse itself, facing the yard.
        for k in range(30):
            a = prng.uniform(0, math.tau)
            hx, hz = x + math.cos(a) * 8.0, z + math.sin(a) * 8.0
            b = place_building(W, prng.choice(HOMES[theme]), hx, hz, math.atan2(x - hx, z - hz) + math.pi, "home")
            if b:
                s["houses"].insert(0, b)
                break
        if not any(h["role"] == "home" for h in s["houses"]):
            return None
    if kind in ("village", "town") and theme == "woodland" and prng.random() < 0.6:
        for k in range(30):
            a = prng.uniform(0, math.tau)
            bx, bz = x + math.cos(a) * reach * 0.95, z + math.sin(a) * reach * 0.95
            b = place_building(W, WINDMILL, bx, bz, prng.uniform(0, math.tau), "prop", kind="windmill")
            if b:
                s["props"].append(b)
                break
    # Lanterns along the lanes, light spots for the game.
    for pts, half in lane_paths:
        total = sum(math.hypot(b[0] - a[0], b[1] - a[1]) for a, b in zip(pts[:-1], pts[1:]))
        walked = 4.0
        side = 1
        while walked < total:
            p, tangent = along_path(pts, walked)
            lx, lz = p[0] - tangent[1] * side * (half + 0.9), p[1] + tangent[0] * side * (half + 0.9)
            qz, qx = pix(lx, lz)
            if W.occupied[qz, qx] == 0 and W.water[qz, qx] <= 0:
                b = place_building(W, "res://props/home/lantern", lx, lz, 0.0, "prop", skirt=0.4, check=False, kind="lantern", margin=0.4)
                s["props"].append(b)
                s["lights"].append([round(lx, 2), 3.3, round(lz, 2)])
                side = -side
            walked += 11.0 if kind in ("capital", "town") else 15.0
    if plaza_r > 0:
        for k in range({"capital": 3, "town": 2}.get(kind, 0)):
            a = prng.uniform(0, math.tau)
            mx, mz = x + math.cos(a) * (plaza_r + 2.4), z + math.sin(a) * (plaza_r + 2.4)
            b = place_building(W, "res://props/town/market", mx, mz, math.atan2(x - mx, z - mz) + math.pi, "prop", skirt=0.8, kind="prop")
            if b:
                s["props"].append(b)
        for k in range(8 if kind == "capital" else 4):
            a = (k + 0.5) * math.tau / (8 if kind == "capital" else 4) + 0.2
            bx, bz = x + math.cos(a) * (plaza_r - 1.6), z + math.sin(a) * (plaza_r - 1.6)
            if any(abs(math.remainder(a - e, math.tau)) < 0.35 for e in s["exits"]):
                continue
            b = place_building(W, "res://props/town/bench", bx, bz, math.atan2(x - bx, z - bz) + math.pi, "prop", skirt=0.3,
                               check=False, kind="prop", margin=0.3)
            s["props"].append(b)
    # Yard trees between the houses.
    for k in range({"capital": 22, "town": 12, "village": 7, "hamlet": 3}[kind] * 4):
        if len(s["trees"]) >= {"capital": 22, "town": 12, "village": 7, "hamlet": 3}[kind]:
            break
        a = prng.uniform(0, math.tau)
        r = math.sqrt(prng.random()) * reach
        tx, tz = x + math.cos(a) * r, z + math.sin(a) * r
        qz, qx = pix(tx, tz)
        if W.occupied[max(qz - 2, 0):qz + 3, max(qx - 2, 0):qx + 3].max() > 0 or W.water[qz, qx] > 0:
            continue
        W.occupied[max(qz - 1, 0):qz + 2, max(qx - 1, 0):qx + 2] = 2
        kinds = ["fir_snow", "pine_tall", "birch"] if theme == "fosen" else ["palm", "palm", "acacia"] if theme == "desert" \
            else ["orchard_apple", "blossom", "oak_round", "birch", "maple"]
        s["trees"].append({"prefab": prng.choice(kinds), "pos": [round(tx, 2), round(SEA + float(W.rel[qz, qx]), 3), round(tz, 2)],
                           "yaw": round(prng.uniform(0, math.tau), 3)})
    return s


def along_path(pts, distance):
    for a, b in zip(pts[:-1], pts[1:]):
        step = math.hypot(b[0] - a[0], b[1] - a[1])
        if distance <= step:
            t = distance / max(step, 1e-3)
            return (a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t), ((b[0] - a[0]) / max(step, 1e-3), (b[1] - a[1]) / max(step, 1e-3))
        distance -= step
    a, b = pts[-2], pts[-1]
    step = math.hypot(b[0] - a[0], b[1] - a[1]) or 1.0
    return b, ((b[0] - a[0]) / step, (b[1] - a[1]) / step)


def settlements(W):
    stats_maps(W)
    taken = []  # (x, z, keep-out radius)
    plan = [("Hearthwick", "capital", [WOODS], (0, 0, 120)),
            ("Bramblebrook", "town", [WOODS], None),
            ("Snowbell", "town", [FOSEN], None),
            ("Sunveil", "town", [DESERT], None)]
    names = {b: list(v) for b, v in NAMES.items()}
    for b in names:
        prng.shuffle(names[b])
    for b, count in ((WOODS, 6), (JUNGLE, 1), (FOSEN, 1), (DESERT, 1), (BLUELAY, 1), (BEACH, 2)):
        for i in range(count):
            plan.append((names[b].pop(), "village", [b] if b != BEACH else [BEACH, WOODS], None))
    farm_names = list(FARM_NAMES)
    prng.shuffle(farm_names)
    for b, count in ((WOODS, 10), (JUNGLE, 2), (FOSEN, 2), (DESERT, 1), (BEACH, 1)):
        for i in range(count):
            plan.append((farm_names.pop(), "hamlet", [b], None))
    gaps = {"capital": 300, "town": 220, "village": 150, "hamlet": 95}
    for i, (name, kind, biomes, near) in enumerate(plan):
        site = None
        for attempt in range(6):
            rough_max = [0.7, 1.0, 1.4, 1.9, 2.6, 3.5][attempt]
            gap = gaps[kind] * (1.0 - attempt * 0.08)
            if name == "Bramblebrook":
                site = pick_site(W, biomes, gap, taken, rough_max=rough_max, near=(0, 0, 360), avoid_wet=28.0)
                if site and math.hypot(*site) < 220:
                    site = None
            else:
                site = pick_site(W, biomes, gap, taken, rough_max=rough_max, near=near,
                                 avoid_wet={"capital": 32.0, "town": 28.0, "village": 24.0, "hamlet": 22.0}[kind],
                                 prefer_water=kind in ("village", "hamlet"))
            if site:
                break
        if site is None:
            log("  could not place %s" % name)
            continue
        pz, px = pix(*site)
        s = settlement(W, name, kind, int(W.biome[pz, px]) if W.biome[pz, px] != BEACH else WOODS, site[0], site[1],
                       MAP_COLORS[i % len(MAP_COLORS)])
        if s is None:
            continue
        W.json["settlements"].append(s)
        taken.append((site[0], site[1], s["radius"] + 25))
    log("  settlements %d (%d houses)" % (len(W.json["settlements"]), sum(len(s["houses"]) for s in W.json["settlements"])))
    # The Skyward Launch Pad: level ground a short walk south of the capital.
    cap = W.json["settlements"][0]
    best = None
    for k in range(400):
        a = prng.uniform(0.15, math.pi - 0.15)  # south (+z)
        r = prng.uniform(95, 150)
        x, z = cap["center"][0] + math.cos(a) * r, cap["center"][1] + math.sin(a) * r
        cz, cx = to_coarse(x, z)
        pz, px = pix(x, z)
        if not W.land[pz, px] or W.wet_dist4[cz, cx] < 36 or W.occupied[pz, px]:
            continue
        score = -W.rough32[cz, cx]
        if best is None or score > best[0]:
            best = (score, x, z)
    _, x, z = best
    pz, px = pix(x, z)
    target = round(float(W.rel[pz, px]))
    # Level ground under everything SurfaceLaunchpad builds (pad space: the
    # moored ship and its fence reach 44 m west, the forecourt with the
    # boarding tower lies north, where the road comes in), as a rounded
    # rectangle with a 12 m skirt, kept clear of trees, rocks and bushes.
    ox, oz, hx, hz, round_r = -12.0, -9.0, 36.0, 31.0, 10.0
    gz, gx, _ = rect_pixels(x + ox, z + oz, hx, hz, 0.0, 14)
    lx = gx - HALF + 0.5 - x
    lz = gz - HALF + 0.5 - z
    qx = np.maximum(np.abs(lx - ox) - (hx - round_r), 0)
    qz = np.maximum(np.abs(lz - oz) - (hz - round_r), 0)
    out = np.hypot(qx, qz) - round_r
    inner = out <= 0
    band = (out > 0) & (out < 12)
    flatten(W, gz[inner], gx[inner], float(target), gz[band], gx[band], smoothstep(0, 12, out[band]))
    W.occupied[gz[inner], gx[inner]] = 2
    W.flags[gz[out < 7], gx[out < 7]] |= F_CLEAR
    # The forecourt north of the fence is paved, edged with gravel, and a
    # gravel lane runs up to where the road ends.
    edge = np.random.default_rng(SEED + 5).random(lx.shape)
    court = np.maximum(np.maximum(-30 - lx, lx - 17), np.maximum(-27 - lz, lz + 10))
    lane = np.maximum(np.abs(lx) - 2.2, np.maximum(-38 - lz, lz + 26))
    W.material[gz[(court <= 0) | (lane <= 0)], gx[(court <= 0) | (lane <= 0)]] = M_PLAZA
    rim = ((court > 0) & (court < 1.6)) | ((lane > 0) & (lane < 1.2))
    rim &= edge < 0.8
    W.material[gz[rim], gx[rim]] = M_GRAVEL
    W.json["landmarks"].append({"type": "launchpad", "at": [int(round(x)), int(round(z))], "height": int(SEA + target)})
    taken.append((x, z, 60))
    W.taken = taken


def strongholds(W):
    """A fortress for each boss biome on a wide level pad, deep in its land."""
    for b in (DOOM, FOSEN, BLUELAY, DESERT, DEEP_DARK):
        best = None
        for k in range(1500):
            x = prng.uniform(-HALF + 120, HALF - 120)
            z = prng.uniform(-HALF + 120, HALF - 120)
            pz, px = pix(x, z)
            if W.biome[pz, px] != b:
                continue
            ok = True
            misses = 0
            for a in range(12):
                q = pix(x + math.cos(a * math.tau / 12) * 64, z + math.sin(a * math.tau / 12) * 64)
                if not W.land[q]:
                    misses += 9
                elif W.biome[q] not in (b, DEEP_DESERT if b == DESERT else b):
                    misses += 1
            ok = misses <= (3 if b == DEEP_DARK else 1)
            if not ok:
                continue
            if any(math.hypot(x - o[0], z - o[1]) < o[2] + 90 for o in W.taken):
                continue
            if any(math.hypot(x - v["x"], z - v["z"]) < v["r"] + 70 for v in W.json["volcanoes"]):
                continue
            cz, cx = to_coarse(x, z)
            if W.wet_dist4[cz, cx] < (36 if b == DEEP_DARK else 60):
                continue
            score = -W.rough32[cz, cx] - abs(W.rel[pz, px] - 12) * 0.05 + math.hypot(x, z) * 0.002
            if best is None or score > best[0]:
                best = (score, x, z)
        if best is None:
            log("  no stronghold site for biome %d" % b)
            continue
        _, x, z = best
        x, z = round(x), round(z)
        pz, px = pix(x, z)
        floor = int(round(float(np.median(W.rel[pz - 30:pz + 31, px - 30:px + 31]))))
        gz, gx, out = rect_pixels(x, z, 52, 52, 0.0, 20)
        d = np.maximum(np.abs(gx - HALF + 0.5 - x), np.abs(gz - HALF + 0.5 - z))
        inner = d <= 40
        band = (d > 40) & (d < 60)
        flatten(W, gz[inner], gx[inner], float(floor), gz[band], gx[band], smoothstep(40, 60, d[band]))
        W.occupied[gz[d <= 54], gx[d <= 54]] = 2
        W.flags[gz[d <= 56], gx[d <= 56]] |= F_CLEAR
        # The gate faces the capital.
        toward = (-x, -z)
        gate = math.atan2(toward[1], toward[0])
        W.json["strongholds"].append({"biome": b, "at": [int(x), int(z)], "height": int(SEA + floor),
                                      "gate_angle": round(gate, 4), "seed": prng.randrange(1 << 30)})
        W.taken.append((x, z, 80))
    log("  strongholds %d" % len(W.json["strongholds"]))


def route_cost(W, kind):
    h4 = block_mean(W.rel, C)
    cost = np.ones((NC, NC), np.float32)
    water4 = block_mean((W.water > 0).astype(np.float32), C) > 0.3
    lake4 = block_mean((W.flags & F_LAKE).astype(bool).astype(np.float32), C) > 0.2
    sea4 = block_mean((~W.land).astype(np.float32), C) > 0.3
    lava4 = block_mean(W.lava.astype(np.float32), C) > 0.05
    occ4 = block_mean((W.occupied == 2).astype(np.float32), C) > 0.25
    b4 = W.biome[C // 2::C, C // 2::C]
    cost[water4] += 30.0 if kind == "road" else 14.0
    cost[lake4 | sea4 | lava4 | occ4] = math.inf
    cost[b4 == DEEP_DARK] *= 3.0
    if kind == "trail":
        forest = W.forest_hint[C // 2::C, C // 2::C]
        cost *= (1.15 - forest * 0.35)
    return cost, h4


def roads(W):
    sets = W.json["settlements"]
    nodes = [(s["center"][0], s["center"][1], s["kind"]) for s in sets]
    for lm in W.json["landmarks"]:
        nodes.append((lm["at"][0], lm["at"][1] - 36, "pad"))
    # Main roads: a spanning tree over the towns plus a few loops; branches to the rest.
    big = [i for i, n in enumerate(nodes) if n[2] in ("capital", "town", "village")]
    edges = mst([(nodes[i][0], nodes[i][1]) for i in big])
    edges = [(big[a], big[b]) for a, b in edges]
    for i in big:
        others = sorted((math.hypot(nodes[i][0] - nodes[j][0], nodes[i][1] - nodes[j][1]), j) for j in big if j != i)
        if others and others[0][0] < 420 and (i, others[0][1]) not in edges and (others[0][1], i) not in edges and prng.random() < 0.5:
            edges.append((i, others[0][1]))
    for i, n in enumerate(nodes):
        if n[2] in ("hamlet", "pad"):
            near = min(big, key=lambda j: math.hypot(n[0] - nodes[j][0], n[1] - nodes[j][1]))
            edges.append((i, near))
    # Approach roads to three fortresses; the others are found, not followed.
    for k, f in enumerate(W.json["strongholds"]):
        if f["biome"] in (DOOM, FOSEN, DESERT):
            a = f["gate_angle"]
            gate = (f["at"][0] + math.cos(a) * 64, f["at"][1] + math.sin(a) * 64)
            nodes.append((gate[0], gate[1], "fort"))
            near = min(big, key=lambda j: math.hypot(gate[0] - nodes[j][0], gate[1] - nodes[j][1]))
            edges.append((len(nodes) - 1, near))
    cost, h4 = route_cost(W, "road")
    road4 = np.zeros((NC, NC), bool)
    edges.sort(key=lambda e: math.hypot(nodes[e[0]][0] - nodes[e[1]][0], nodes[e[0]][1] - nodes[e[1]][1]))
    for a, b in edges:
        main = nodes[a][2] in ("capital", "town") and nodes[b][2] in ("capital", "town")
        sa, sb = to_coarse(nodes[a][0], nodes[a][1]), to_coarse(nodes[b][0], nodes[b][1])
        c2 = cost.copy()
        for s in (sa, sb):
            c2[max(s[0] - 4, 0):s[0] + 5, max(s[1] - 4, 0):s[1] + 5] = np.minimum(c2[max(s[0] - 4, 0):s[0] + 5, max(s[1] - 4, 0):s[1] + 5], 1.0)
        path = astar(c2, h4, sa, sb, slope_k=26.0, slope_max=0.55, road_mask=road4, road_bonus=0.35, cliff_cost=60.0)
        if path is None:
            log("  no road %s - %s" % (nodes[a][2], nodes[b][2]))
            continue
        for p in path:
            road4[p] = True
        pts = [from_coarse(*p) for p in path]
        pts = [(nodes[a][0], nodes[a][1])] + pts[1:-1] + [(nodes[b][0], nodes[b][1])]
        pts = straighten(pts)
        pts = chaikin(pts, 3)
        biome_here = W.biome[pix(*pts[len(pts) // 2])]
        mat = M_ROAD_COBBLE if main else M_ROAD_DIRT
        if biome_here in (DESERT, DEEP_DESERT):
            mat = M_ROAD_SAND
        elif biome_here == DOOM:
            mat = M_ROAD_ASH
        elif biome_here == FOSEN:
            mat = M_ROAD_SNOW
        rec = {"main": main}
        carve_path(W, pts, 2.1 if main else 1.5, mat, F_ROAD, 0.16 if main else 0.22, shoulder=3.5, smooth=8, record=rec)
        W.json["roads"].append(rec)
    log("  roads %d" % len(W.json["roads"]))


def straighten(pts):
    """Removes the grid staircase: keeps every 3rd point with a bit of wander."""
    if len(pts) < 5:
        return pts
    out = [pts[0]]
    for i in range(3, len(pts) - 1, 3):
        out.append((pts[i][0] + prng.uniform(-1.2, 1.2), pts[i][1] + prng.uniform(-1.2, 1.2)))
    out.append(pts[-1])
    return out


def mst(points):
    n = len(points)
    inside = {0}
    edges = []
    while len(inside) < n:
        best = None
        for i in inside:
            for j in range(n):
                if j in inside:
                    continue
                d = math.hypot(points[i][0] - points[j][0], points[i][1] - points[j][1])
                if best is None or d < best[0]:
                    best = (d, i, j)
        edges.append((best[1], best[2]))
        inside.add(best[2])
    return edges


def trails(W):
    """Forest trails between camps, lakes, waterfalls and lookouts; wooden
    stairs carry them up the stone terraces."""
    W.forest_hint = forest_hint(W)
    glades(W)
    pois = []
    for wf in W.json["waterfalls"]:
        pois.append((wf["x"] + math.cos(wf["dir"] + 1.57) * (wf["width"] * 0.5 + 4), wf["z"] + math.sin(wf["dir"] + 1.57) * (wf["width"] * 0.5 + 4)))
    # Lookouts: high, open spots in the friendly biomes.
    for k in range(260):
        x, z = prng.uniform(-HALF + 80, HALF - 80), prng.uniform(-HALF + 80, HALF - 80)
        pz, px = pix(x, z)
        if W.biome[pz, px] in (WOODS, JUNGLE, FOSEN) and W.rel[pz, px] > 12 and W.occupied[pz, px] == 0 and W.water[pz, px] <= 0:
            if all(math.hypot(x - p[0], z - p[1]) > 120 for p in pois):
                pois.append((x, z))
    W.camp_sites = []
    for k in range(400):
        x, z = prng.uniform(-HALF + 80, HALF - 80), prng.uniform(-HALF + 80, HALF - 80)
        pz, px = pix(x, z)
        cz, cx = to_coarse(x, z)
        if W.biome[pz, px] in (WOODS, JUNGLE, FOSEN, DESERT, BLUELAY) and W.rough12[cz, cx] < 0.8 and W.occupied[pz, px] == 0 \
                and W.water[pz, px] <= 0 and W.land[pz, px] and W.rel[pz, px] > 1.0:
            if all(math.hypot(x - p[0], z - p[1]) > 90 for p in pois + W.camp_sites) and \
                    all(math.hypot(x - o[0], z - o[1]) > o[2] + 15 for o in W.taken):
                W.camp_sites.append((x, z))
                if len(W.camp_sites) >= 16:
                    break
    pois += W.camp_sites
    cost, h4 = route_cost(W, "trail")
    trail4 = np.zeros((NC, NC), bool)
    road4 = block_mean((W.flags & F_ROAD).astype(bool).astype(np.float32), C) > 0.2
    count = 0
    for p in pois:
        # To the nearest road or settlement point within reach.
        pc = to_coarse(*p)
        rz, rx = np.nonzero(road4 | trail4)
        if len(rz) == 0:
            continue
        d = (rz - pc[0]) ** 2 + (rx - pc[1]) ** 2
        j = int(np.argmin(d))
        if d[j] > (220 // C) ** 2 or d[j] < 9:
            continue
        goal = (int(rz[j]), int(rx[j]))
        c2 = cost.copy()
        c2[pc] = 1.0
        path = astar(c2, h4, pc, goal, slope_k=5.0, slope_max=0.45, road_mask=trail4, road_bonus=0.5, cliff_cost=7.0)
        if path is None or len(path) < 4:
            continue
        for q in path:
            trail4[q] = True
        pts = [from_coarse(*q) for q in path]
        pts[0] = p
        pts = chaikin(straighten_soft(pts), 3)
        carve_path(W, pts, 0.85, M_TRAIL, F_TRAIL, 0.3, shoulder=1.2, smooth=2, stairs_grade=0.45)
        W.json["trails"].append({"points": [[round(a, 1), round(b, 1)] for a, b in pts[::3]]})
        count += 1
    log("  trails %d, stairs %d" % (count, len(W.json["stairs"])))


def straighten_soft(pts):
    out = [pts[0]]
    for i in range(2, len(pts) - 1, 2):
        out.append((pts[i][0] + prng.uniform(-1.5, 1.5), pts[i][1] + prng.uniform(-1.5, 1.5)))
    out.append(pts[-1])
    return out


def forest_hint(W):
    n = fbm(rng, 18, N, 4)
    m = fbm(rng, 60, N, 3)
    base = {WOODS: 0.62, JUNGLE: 0.9, FOSEN: 0.55, BLUELAY: 0.35, DOOM: 0.2, DESERT: 0.03, DEEP_DESERT: 0.01,
            DEEP_DARK: 0.14, BEACH: 0.1, OCEAN: 0.0}
    b = np.vectorize(lambda v: base.get(int(v), 0.0), otypes=[np.float32])(W.biome[::4, ::4])
    b = upscale(b, N)
    d = np.clip(b + n * 0.55 + m * 0.15, 0, 1)
    # Treeline on the mountains.
    d *= 1.0 - smoothstep(30.0, 48.0, W.rel)
    return d.astype(np.float32)


def glades(W):
    """Open clearings in the thick woods: a ragged ring of trees round a
    meadow with only a lone tree or two. Listed in surface.json ("glades") so
    the game can stage bosses, camps and people there. Uses its own random
    stream, so the rest of the world keeps its layout."""
    grng = random.Random(SEED * 31 + 7)
    W.glade = np.zeros((N, N), bool)
    busy = (W.flags & (F_ROAD | F_TOWN | F_FIELD | F_CLEAR | F_RIVER | F_LAKE)).astype(bool) | (W.occupied > 0) | ~W.land
    cands = []
    for gz in range(-HALF + 70, HALF - 70, 22):
        for gx in range(-HALF + 70, HALF - 70, 22):
            cands.append((gx + grng.uniform(-9, 9), gz + grng.uniform(-9, 9)))
    grng.shuffle(cands)
    out = []
    for x, z in cands:
        pz, px = pix(x, z)
        cz, cx = to_coarse(x, z)
        b = int(W.biome[pz, px])
        if b not in (WOODS, JUNGLE, FOSEN, BLUELAY) or W.rough12[cz, cx] > 0.7 or W.wet_dist4[cz, cx] < 16:
            continue
        if W.rel[pz, px] < 1.5 or W.rel[pz, px] > 30:
            continue
        r = grng.uniform(14, 23)
        reach = int(r + 6)
        win = (slice(pz - reach, pz + reach + 1), slice(px - reach, px + reach + 1))
        # Only where it is properly wooded, and nothing else claims the ground.
        if W.forest_hint[win].mean() < 0.45 or busy[win].any():
            continue
        if any(math.hypot(x - g["at"][0], z - g["at"][1]) < 110 for g in out):
            continue
        if any(math.hypot(x - o[0], z - o[1]) < o[2] + r + 10 for o in W.taken):
            continue
        p1, p2 = grng.uniform(0, math.tau), grng.uniform(0, math.tau)
        lz, lx = np.mgrid[-reach:reach + 1, -reach:reach + 1]
        d = np.hypot(lx, lz)
        a = np.arctan2(lz, lx)
        edge = r * (1 + 0.16 * np.sin(3 * a + p1) + 0.08 * np.sin(5 * a + p2))
        keep = 0.05 + 0.95 * smoothstep(edge * 0.7, edge * 1.25, d)
        W.forest_hint[win] *= keep.astype(np.float32)
        W.glade[win] |= d < edge * 0.8
        out.append({"at": [round(x, 1), round(z, 1)], "r": round(r, 1), "biome": b})
        if len(out) >= 60:
            break
    W.json["glades"] = out
    log("  glades %d" % len(out))


def fields(W):
    """Wheat and crop fields beside the farms and villages, fenced in voxels."""
    count = 0
    for s in W.json["settlements"]:
        if s["biome"] not in (WOODS, JUNGLE, FOSEN) and s["kind"] != "hamlet":
            continue
        want = {"capital": 4, "town": 3, "village": 3, "hamlet": 2}[s["kind"]]
        for k in range(60):
            if want == 0:
                break
            a = prng.uniform(0, math.tau)
            r = s["radius"] + prng.uniform(4, 24) if s["kind"] != "hamlet" else prng.uniform(18, 30)
            cx, cz = s["center"][0] + math.cos(a) * r, s["center"][1] + math.sin(a) * r
            hx, hz = prng.uniform(7, 15), prng.uniform(5, 11)
            yaw = prng.uniform(0, math.pi)
            gz, gx, out = rect_pixels(cx, cz, hx, hz, yaw, 2)
            inner = out <= 0
            if not inner.any():
                continue
            if W.occupied[gz[out <= 1.5], gx[out <= 1.5]].max() > 0 or (W.water[gz[out <= 1.5], gx[out <= 1.5]] > 0).any():
                continue
            if (~W.land[gz[inner], gx[inner]]).any():
                continue
            hs = W.rel[gz[inner], gx[inner]]
            if hs.max() - hs.min() > 2.6:
                continue
            # Gently smooth the field so the furrows read.
            W.rel[gz[inner], gx[inner]] = hs * 0.4 + float(np.mean(hs)) * 0.6
            W.material[gz[inner], gx[inner]] = M_FARM
            W.flags[gz[inner], gx[inner]] |= F_FIELD | F_CLEAR
            W.occupied[gz[out <= 1.0], gx[out <= 1.0]] = 2
            crop = prng.choice(["wheat", "wheat", "wheat", "greens", "pumpkins", "lavender"])
            W.json.setdefault("fields", []).append({"center": [round(cx, 2), round(cz, 2)], "half": [round(hx, 2), round(hz, 2)],
                                                    "yaw": round(yaw, 4), "crop": crop})
            fence(W, cx, cz, hx + 0.6, hz + 0.6, yaw)
            want -= 1
            count += 1
    log("  fields %d" % count)


def fence(W, cx, cz, hx, hz, yaw):
    c, s = math.cos(yaw), math.sin(yaw)

    def world(lx, lz):
        return (cx + lx * c + lz * s, cz - lx * s + lz * c)

    corners = [(-hx, -hz), (hx, -hz), (hx, hz), (-hx, hz), (-hx, -hz)]
    gate_side = prng.randrange(4)
    for k in range(4):
        a, b = corners[k], corners[k + 1]
        length = math.hypot(b[0] - a[0], b[1] - a[1])
        n = max(2, int(length / 2.0))
        line = []
        for i in range(n + 1):
            t = i / n
            if k == gate_side and 0.42 < t < 0.58:
                if line:
                    fence_rails(W, line)
                line = []
                continue
            p = world(a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t)
            pz, px = pix(*p)
            y = SEA + float(W.rel[pz, px])
            W.json["posts"].append({"x": round(p[0], 2), "z": round(p[1], 2), "y0": round(y - 0.5, 2), "y1": round(y + 1.1, 2),
                                    "block": "timber"})
            line.append((p, y))
        if line:
            fence_rails(W, line)


def fence_rails(W, line):
    if len(line) < 2:
        return
    for lift in (0.45, 0.85):
        W.json["beams"].append({"line": [[round(p[0], 2), round(p[1], 2), round(y + lift, 2)] for p, y in line],
                                "width": 0.25, "thick": 0.25, "block": "planks"})


def camps(W):
    for x, z in W.camp_sites:
        pz, px = pix(x, z)
        b = int(W.biome[pz, px])
        camp = {"center": [round(x, 2), round(z, 2)], "biome": b, "tents": [], "fire": None}
        gz, gx, out = rect_pixels(x, z, 7, 7, 0, 4)
        d = np.sqrt((gx - HALF + 0.5 - x) ** 2 + (gz - HALF + 0.5 - z) ** 2)
        target = round(float(W.rel[pz, px]) * FINE) / FINE
        inner = d < 6
        band = (d >= 6) & (d < 10)
        flatten(W, gz[inner], gx[inner], target, gz[band], gx[band], smoothstep(6, 10, d[band]))
        W.material[gz[d < 2.2], gx[d < 2.2]] = M_DIRT
        W.flags[gz[d < 8], gx[d < 8]] |= F_CLEAR
        camp["fire"] = [round(x, 2), round(SEA + target, 3), round(z, 2)]
        W.json["lights"].append({"x": x, "y": SEA + target + 1.2, "z": z, "color": [1.0, 0.62, 0.3], "energy": 2.6, "range": 11.0,
                                 "flicker": True})
        n = prng.randint(2, 3)
        a0 = prng.uniform(0, math.tau)
        for k in range(n):
            a = a0 + k * math.tau / n + prng.uniform(-0.3, 0.3)
            tx, tz = x + math.cos(a) * 4.6, z + math.sin(a) * 4.6
            t = place_building(W, prng.choice(TENTS), tx, tz, math.atan2(tx - x, tz - z), "prop", skirt=1.0, kind="tent", margin=0.3)
            if t:
                camp["tents"].append(t)
        W.json["camps"].append(camp)
    log("  camps %d" % len(W.json["camps"]))


# --------------------------------------------------------------------------------------

def materials(W):
    b = W.biome
    m = W.material
    n = fbm(rng, 40, N, 3)
    n2 = fbm(rng, 120, N, 2)
    free = m == 0
    forest = W.forest_hint

    def put(mask, value):
        m[free & mask] = value

    # Glades in the woods are flower meadows.
    m[free & W.glade & (b == WOODS)] = M_MEADOW
    free = m == 0
    put((b == WOODS) & (forest > 0.62) & (n2 > -0.2), M_FOREST)
    put((b == WOODS) & (n > 0.25), M_MEADOW)
    put((b == WOODS) & (n2 > 0.55), M_MOSS_ROCK)
    put(b == WOODS, M_GRASS)
    put((b == JUNGLE) & (forest > 0.75), M_FOREST)
    put(b == JUNGLE, M_JUNGLE_GRASS)
    put((b == FOSEN) & ((W.rel > 22 + n * 6) | (n2 > 0.35)), M_SNOW)
    put((b == FOSEN) & (n > 0.45), M_ROCK)
    put(b == FOSEN, M_TUNDRA)
    put((b == DOOM) & (n > 0.3), M_BASALT)
    put((b == DOOM) & (n2 > 0.6), M_OBSIDIAN)
    put(b == DOOM, M_ASH)
    put((b == DESERT) & (W.rel > 12), M_SANDSTONE)
    put((b == DESERT) & (n > 0.5), M_CRACKED)
    put(b == DESERT, M_DESERT_SAND)
    put(b == DEEP_DESERT, M_DEEP_SAND)
    put(b == BLUELAY, M_BLUE_MOSS)
    put(b == DEEP_DARK, M_DEEP_STONE)
    put(b == BEACH, M_SAND)
    put(b == OCEAN, M_SEAFLOOR)
    river = (W.flags & F_RIVER).astype(bool) | (W.flags & F_LAKE).astype(bool)
    m[river & (W.material != M_STAIRS)] = M_RIVERBED
    m[W.lava] = M_LAVA
    # Volcanic flanks are black rock, coasts near Doom black sand.
    for v in W.json["volcanoes"]:
        d = np.sqrt((WX - v["x"]) ** 2 + (WZ - v["z"]) ** 2)
        m[(d < v["r"] * 0.85) & ~W.lava & (m != M_ROAD_ASH)] = np.where(n[(d < v["r"] * 0.85) & ~W.lava & (m != M_ROAD_ASH)] > 0.1, M_OBSIDIAN, M_BASALT)
    m[(b == DOOM) & (W.rel < 1.6) & free] = M_BLACK_SAND


def forest(W):
    d = W.forest_hint.copy()
    blocked = (W.flags & (F_ROAD | F_TRAIL | F_FIELD | F_CLEAR | F_RIVER | F_LAKE)).astype(bool) | ~W.land | W.lava
    near_path = distance_to(blocked, 6)
    d *= smoothstep(1.0, 5.0, near_path)
    d[(W.flags & F_TOWN).astype(bool)] *= 0.15
    return (np.clip(d, 0, 1) * 255).astype(np.uint8)


def write(W, flora):
    os.makedirs(OUT, exist_ok=True)
    height = np.clip(np.round((W.rel + SEA) * FINE), 4, 65535).astype("<u2")
    water = np.clip(np.round(W.water * FINE), 0, 65535).astype("<u2")
    shape = shape_bits(W, height)
    tiles = tile_ranges(W, height, water)
    layers = {"height": height, "water": water, "ground": W.material.astype(np.uint8), "biome": W.biome.astype(np.uint8),
              "flora": flora, "flags": W.flags.astype(np.uint8), "shape": shape, "tiles": tiles,
              "current": np.clip(np.round(W.current * 127.0 + 128.0), 0, 255).astype(np.uint8)}
    for name, arr in layers.items():
        with gzip.open(os.path.join(OUT, name + ".bin.gz"), "wb", compresslevel=6) as f:
            f.write(np.ascontiguousarray(arr).tobytes())
    W.json["layers"] = {name: int(arr.nbytes) for name, arr in layers.items()}
    W.json["assets"] = ASSETS
    with open(os.path.join(OUT, "surface.json"), "w") as f:
        json.dump(W.json, f, separators=(",", ":"))
    preview(W, height)
    world_map(W, height, flora)
    log("wrote %s (max height %.1f m)" % (OUT, height.max() / FINE))


def shape_bits(W, height):
    h = height.astype(np.int32)
    p = np.pad(h, 1, mode="edge")
    neigh = [p[1:-1, :-2], p[1:-1, 2:], p[:-2, 1:-1], p[2:, 1:-1]]
    drop = np.maximum.reduce([h - q for q in neigh])  # how far this cell stands above a neighbour
    rise = np.maximum.reduce([q - h for q in neigh])  # how far a neighbour stands above it
    out = np.zeros((N, N), np.uint8)
    paths = (W.flags & (F_ROAD | F_TRAIL | F_BRIDGE)).astype(bool)
    out[(drop >= 5) & ~paths] |= S_CLIFF
    out[rise >= 6] |= S_BASE
    green = np.isin(W.biome, [WOODS, JUNGLE, BLUELAY, BEACH])
    ivy = fbm(rng, 70, N, 2) > -0.05
    out[(rise >= 6) & green & ivy & (W.water <= 0)] |= S_VINES
    rough = fbm(rng, 90, N, 2) > 0.25
    out[(np.isin(W.material, [M_ROCK, M_MOSS_ROCK, M_BASALT, M_OBSIDIAN, M_SANDSTONE, M_DEEP_STONE]) | rough)
        & ~(W.flags & (F_ROAD | F_TRAIL | F_FIELD | F_CLEAR | F_TOWN)).astype(bool)] |= S_ROCKY
    return out


def tile_ranges(W, height, water):
    """Lowest / highest voxel per 4 m tile, with a margin for the neighbours
    the terrain blends with, stones in rivers, rails, posts and fortresses."""
    h = height.astype(np.int32)
    lo = h.copy()
    hi = h + 2  # rough rock bumps
    hi = np.maximum(hi, np.where(water > 0, water.astype(np.int32) + 2, 0))
    for post in W.json["posts"]:
        z, x = pix(post["x"], post["z"])
        hi[z, x] = max(hi[z, x], int(post["y1"] * FINE) + 2)
    for beam in W.json["beams"]:
        pts = beam.get("line") or [[p[0], p[1], beam["y"]] for p in beam["points"]]
        for a, b in zip(pts[:-1], pts[1:]):
            for t in np.linspace(0, 1, 6):
                x, z, y = (a[i] + (b[i] - a[i]) * t for i in range(3))
                q = pix(x, z)
                r = int(beam["width"]) + 2
                zz, xx = slice(max(q[0] - r, 0), q[0] + r + 1), slice(max(q[1] - r, 0), q[1] + r + 1)
                hi[zz, xx] = np.maximum(hi[zz, xx], int((y + beam["thick"]) * FINE) + 2)
                lo[zz, xx] = np.minimum(lo[zz, xx], int((y - beam["thick"]) * FINE) - 2)
    for f in W.json["strongholds"]:
        z, x = pix(*f["at"])
        hi[max(z - 60, 0):z + 61, max(x - 60, 0):x + 61] = np.maximum(hi[max(z - 60, 0):z + 61, max(x - 60, 0):x + 61],
                                                                      (f["height"] + 26) * FINE)
    # Vines climb neighbouring walls: the neighbours' heights cover them.
    p = np.pad(hi, 2, mode="edge")
    hi_n = np.maximum.reduce([p[2 + dz:N + 2 + dz, 2 + dx:N + 2 + dx] for dz in range(-2, 3) for dx in range(-2, 3)])
    p = np.pad(lo, 2, mode="edge")
    lo_n = np.minimum.reduce([p[2 + dz:N + 2 + dz, 2 + dx:N + 2 + dx] for dz in range(-2, 3) for dx in range(-2, 3)])
    n = N // TILE
    tlo = lo_n.reshape(n, TILE, n, TILE).min(axis=(1, 3)) - 8  # under-layers start lower
    thi = hi_n.reshape(n, TILE, n, TILE).max(axis=(1, 3))
    out = np.stack([np.clip(tlo, 0, 65535), np.clip(thi, 0, 65535)], axis=-1).astype("<u2")
    return out


MAP_COLORS_BY_MAT = {
    M_GRASS: (104, 160, 66), M_MEADOW: (128, 178, 82), M_FOREST: (70, 112, 50), M_DIRT: (112, 82, 54), M_TRAIL: (160, 128, 86),
    M_ROAD_COBBLE: (176, 166, 148), M_ROAD_DIRT: (176, 140, 96), M_PLAZA: (196, 186, 164), M_FARM: (210, 182, 96),
    M_SAND: (226, 210, 160), M_RIVERBED: (120, 116, 104), M_ROCK: (138, 134, 128), M_SNOW: (236, 240, 246),
    M_TUNDRA: (128, 146, 124), M_ASH: (74, 66, 64), M_BASALT: (58, 52, 52), M_LAVA: (255, 110, 30),
    M_DESERT_SAND: (232, 188, 120), M_DEEP_SAND: (242, 196, 96), M_SANDSTONE: (200, 148, 106), M_BLUE_MOSS: (52, 85, 126),
    M_DEEP_STONE: (38, 38, 44), M_JUNGLE_GRASS: (52, 124, 48), M_STAIRS: (154, 110, 68), M_SEAFLOOR: (168, 156, 120),
    M_CRACKED: (200, 154, 104), M_BLACK_SAND: (60, 56, 58), M_ICE: (184, 216, 236), M_YARD: (130, 150, 80),
    M_ROAD_SAND: (216, 176, 128), M_ROAD_ASH: (90, 76, 72), M_ROAD_SNOW: (176, 180, 188), M_OBSIDIAN: (34, 28, 40),
    M_GRAVEL: (154, 150, 140), M_MOSS_ROCK: (126, 130, 112),
}


def world_map(W, height, flora):
    """The whole Surface as a picture for the map screen (1 px per meter):
    ground colours, forests darker, hills shaded from the north-west, the sea
    deepening away from the coast, rivers, lakes, lava, roads and towns."""
    img = np.zeros((N, N, 3), np.float32)
    for mat, color in MAP_COLORS_BY_MAT.items():
        img[W.material == mat] = color
    img *= (1.0 - flora.astype(np.float32)[..., None] / 255.0 * 0.38)
    h = height.astype(np.float32) / FINE
    light = (h - np.roll(h, 2, axis=1)) * 0.11 + (h - np.roll(h, 2, axis=0)) * 0.11
    img *= np.clip(1.0 + light + (h - SEA) * 0.003, 0.6, 1.45)[..., None]
    sea = h < SEA + 0.6
    depth = np.clip((SEA + 0.6 - h) / 7.0, 0, 1)[..., None]
    img = np.where(sea[..., None], np.array([70, 150, 176], np.float32) * (1 - depth) + np.array([22, 62, 104], np.float32) * depth, img)
    wet = W.water > 0
    img[wet] = (66, 140, 186)
    img[W.lava] = (255, 120, 40)
    for s in W.json["settlements"]:
        c = s["map_color"]
        d = np.sqrt((WX - s["center"][0]) ** 2 + (WZ - s["center"][1]) ** 2) < s["radius"]
        img[d] = img[d] * 0.6 + np.array(c, np.float32) * 255 * 0.4
    for f in W.json["strongholds"]:
        x, z = f["at"]
        d = np.maximum(np.abs(WX - x), np.abs(WZ - z)) < 36
        img[d] = img[d] * 0.5 + np.array([60, 52, 56], np.float32) * 0.5
    img[(W.flags & (F_ROAD | F_BRIDGE)).astype(bool)] = (214, 196, 152)
    img[(W.flags & F_TRAIL).astype(bool) & ~(W.flags & F_ROAD).astype(bool)] = (170, 136, 92)
    with gzip.open(os.path.join(OUT, "map.bin.gz"), "wb", compresslevel=6) as f:
        f.write(np.ascontiguousarray(np.clip(img, 0, 255).astype(np.uint8)).tobytes())


def preview(W, height):
    colors = {OCEAN: (40, 90, 140), BEACH: (225, 210, 160), WOODS: (80, 140, 60), JUNGLE: (40, 120, 50), DESERT: (220, 180, 110),
              DOOM: (90, 50, 45), FOSEN: (220, 225, 235), BLUELAY: (60, 80, 140), DEEP_DESERT: (240, 200, 100), DEEP_DARK: (35, 35, 45)}
    img = np.zeros((N, N, 3), np.float32)
    for b, c in colors.items():
        img[W.biome == b] = c
    h = height.astype(np.float32) / FINE
    shade = np.clip(1.0 + (h - np.roll(h, 1, axis=1)) * 0.25, 0.55, 1.4)
    img *= shade[..., None]
    img[W.water > 0] = (60, 120, 190)
    img[W.lava] = (255, 110, 30)
    img[(W.flags & F_ROAD).astype(bool)] = (200, 170, 120)
    img[(W.flags & F_TRAIL).astype(bool)] = (150, 110, 70)
    img[(W.flags & F_FIELD).astype(bool)] = (230, 200, 90)
    img[W.occupied == 2] = np.minimum(img[W.occupied == 2] * 0.5 + 120, 255)
    Image.fromarray(np.clip(img, 0, 255).astype(np.uint8)).resize((1024, 1024), Image.BILINEAR).save(os.path.join(OUT, "preview.png"))


if __name__ == "__main__":
    main()
