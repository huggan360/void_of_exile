#!/usr/bin/env python3
"""Authoring utility for the fixed home island. NEVER called in play.

Writes scenes/home/tavern.tscn: coastline, HomeRoad curves, plazas, buildings,
gardens, trees, street furniture and residents. Re-running it REPLACES any
editor changes to that scene, so only run it to start the layout over.
Also writes docs/realm_expansion/tavern_plan.png, a top-down plan preview.
"""
from pathlib import Path
import math, json, random

ROOT = Path(__file__).resolve().parents[1]
E = 136
SIDE = E * 2 + 1
Y = 10  # standing height on the town plateau
rng = random.Random(1807)  # fixed: the home island never changes between runs

# --- footprints (local x width, local z depth); fronts face local -Z ----------
SIZES = {
    'grand_tavern': (15.3, 11.25), 'chapel': (11, 16), 'smithy': (9.8, 9), 'magicians_house': (10, 10),
    'tall_townhouse': (6.8, 9), 'broad_lodge': (11.5, 9.5), 'blue_bakery': (8.5, 7.7), 'rose_cottage': (7.3, 7.7),
    'woodland_0': (8.5, 9), 'woodland_1': (8.5, 9), 'woodland_2': (8.5, 9),
    'desert_0': (8.5, 9), 'desert_1': (8.5, 9), 'desert_2': (8.5, 9),
    'fountain': (12.5, 12.5), 'garden_bed': (7.7, 11.5), 'lantern': (1.4, 1.4), 'market': (3.5, 2.8),
    'bench': (2.7, 1.3), 'well': (2.8, 2.8), 'blossom_tree': (1.2, 1.2), 'orchard_tree': (1.2, 1.2),
    'nature_tree_round': (1.6, 1.6), 'nature_tree_tall': (1.8, 1.8), 'nature_tree_small': (1.2, 1.2),
    'nature_bush': (2.5, 2.0), 'nature_pine': (1.6, 1.6), 'nature_rock': (2.5, 2.5), 'nature_boulder': (4, 3.5),
    'nature_palm': (1.2, 1.2),
}
HOMES = ['woodland_0', 'rose_cottage', 'woodland_1', 'blue_bakery', 'desert_1', 'tall_townhouse',
         'woodland_2', 'broad_lodge', 'desert_0', 'rose_cottage', 'woodland_1', 'desert_2']


def yaw_facing(dx, dz):
    """Rotation that turns a prefab's front (-Z) toward direction (dx, dz)."""
    return math.atan2(-dx, -dz)


# --- coastline ------------------------------------------------------------------
def coast_radius(a):
    def bump(center, width, amount):
        d = math.atan2(math.sin(a - center), math.cos(a - center))
        return amount * math.exp(-(d / width) ** 2)
    r = 96 + 5 * math.sin(3 * a + 0.5) + 3 * math.sin(5 * a + 1.9) + 1.6 * math.sin(9 * a + 0.3)
    r += bump(-math.pi / 2, 0.2, 20)       # northern headland for the realm gate
    r += bump(math.pi, 0.15, -18)          # western harbor cove
    r += bump(math.pi / 2, 0.45, 9)        # broad southern shore behind the chapel
    r += bump(-0.25, 0.2, 7)               # eastern point
    return r


COAST = [(math.cos(i * math.tau / 72) * coast_radius(i * math.tau / 72),
          math.sin(i * math.tau / 72) * coast_radius(i * math.tau / 72)) for i in range(72)]


# --- bezier curves (match Godot's Curve3D baking) -------------------------------
def handles(points, closed=False):
    out = []
    n = len(points)
    for i, p in enumerate(points):
        if closed:
            a, b = points[(i - 1) % n], points[(i + 1) % n]
        else:
            a, b = points[max(i - 1, 0)], points[min(i + 1, n - 1)]
        t = ((b[0] - a[0]) / 6, (b[1] - a[1]) / 6) if (closed or 0 < i < n - 1) else ((b[0] - a[0]) / 3, (b[1] - a[1]) / 3)
        out.append((p, (-t[0], -t[1]), t))
    return out


def sample(points, closed=False, step=0.25):
    hs = handles(points, closed)
    if closed:
        hs = hs + [hs[0]]
    pts = []
    for (p0, _, o0), (p3, i3, _) in zip(hs, hs[1:]):
        p1 = (p0[0] + o0[0], p0[1] + o0[1])
        p2 = (p3[0] + i3[0], p3[1] + i3[1])
        length = math.dist(p0, p3)
        steps = max(2, int(length / step))
        for k in range(steps):
            t = k / steps
            u = 1 - t
            pts.append((u**3 * p0[0] + 3 * u * u * t * p1[0] + 3 * u * t * t * p2[0] + t**3 * p3[0],
                        u**3 * p0[1] + 3 * u * u * t * p1[1] + 3 * u * t * t * p2[1] + t**3 * p3[1]))
    pts.append(hs[-1][0])
    return pts


# --- occupancy grid -------------------------------------------------------------
FREE, ROAD, BUILDING, PROP, TREE = 0, 1, 2, 3, 4
grid = bytearray(SIDE * SIDE)
land = bytearray(SIDE * SIDE)


def idx(x, z):
    if abs(x) > E or abs(z) > E:
        return -1
    return (z + E) * SIDE + x + E


def rasterize_coast():
    poly = sample(COAST, closed=True, step=1.0)
    n = len(poly)
    for z in range(-E, E + 1):
        y = z + 0.5
        hits = []
        for k in range(n):
            a, b = poly[k], poly[(k + 1) % n]
            if (a[1] <= y) != (b[1] <= y):
                hits.append(a[0] + (y - a[1]) / (b[1] - a[1]) * (b[0] - a[0]))
        hits.sort()
        for k in range(0, len(hits) - 1, 2):
            for x in range(math.ceil(hits[k] - 0.5), math.floor(hits[k + 1] - 0.5) + 1):
                i = idx(x, z)
                if i >= 0:
                    land[i] = 1


rasterize_coast()
shore = [0.0] * (SIDE * SIDE)


def chamfer():
    big = 1e6
    d = [big if land[i] else 0.0 for i in range(SIDE * SIDE)]
    for z in range(SIDE):
        for x in range(SIDE):
            i = z * SIDE + x
            if d[i] == 0:
                continue
            b = d[i]
            if x > 0: b = min(b, d[i - 1] + 1)
            if z > 0:
                b = min(b, d[i - SIDE] + 1)
                if x > 0: b = min(b, d[i - SIDE - 1] + 1.4142)
                if x < SIDE - 1: b = min(b, d[i - SIDE + 1] + 1.4142)
            d[i] = b
    for z in range(SIDE - 1, -1, -1):
        for x in range(SIDE - 1, -1, -1):
            i = z * SIDE + x
            if d[i] == 0:
                continue
            b = d[i]
            if x < SIDE - 1: b = min(b, d[i + 1] + 1)
            if z < SIDE - 1:
                b = min(b, d[i + SIDE] + 1)
                if x < SIDE - 1: b = min(b, d[i + SIDE + 1] + 1.4142)
                if x > 0: b = min(b, d[i + SIDE - 1] + 1.4142)
            d[i] = b
    return d


shore = chamfer()


def shore_at(x, z):
    i = idx(math.floor(x), math.floor(z))
    return -1 if i < 0 else shore[i]


def rect_cells(cx, cz, w, d, yaw, margin=0.0):
    """Grid cells covered by an oriented rectangle (local width w along x, depth d along z)."""
    hw, hd = w / 2 + margin, d / 2 + margin
    c, s = math.cos(yaw), math.sin(yaw)
    reach = math.ceil(math.hypot(hw, hd)) + 1
    cells = []
    for z in range(math.floor(cz - reach), math.ceil(cz + reach) + 1):
        for x in range(math.floor(cx - reach), math.ceil(cx + reach) + 1):
            px, pz = x + 0.5 - cx, z + 0.5 - cz
            # world -> local for a Godot Y rotation
            lx = px * c - pz * s
            lz = px * s + pz * c
            if abs(lx) <= hw and abs(lz) <= hd:
                cells.append((x, z))
    return cells


def fits(cells, allowed=(FREE,), min_shore=5.0):
    for x, z in cells:
        i = idx(x, z)
        if i < 0 or not land[i] or shore[i] < min_shore or grid[i] not in allowed:
            return False
    return True


def stamp(cells, value):
    for x, z in cells:
        i = idx(x, z)
        if i >= 0 and grid[i] < value or i >= 0 and value == ROAD:
            grid[i] = max(grid[i], value) if value != ROAD else (grid[i] if grid[i] else ROAD)


# --- scene records --------------------------------------------------------------
roads = []      # dict(name, points, width, surface, curbs, closed)
plazas = []     # dict(name, x, z, radius, pattern)
placed = []     # dict(group, name, asset, x, z, yaw)
residents = []  # dict(name, role, x, z, yaw, stationary, greeting, interaction)
lamp_spots = []


def road(name, points, width, surface='cobble', curbs=True):
    pts = sample(points)
    roads.append(dict(name=name, points=points, width=width, surface=surface, curbs=curbs, samples=pts))
    for px, pz in pts:
        r = width / 2 + 0.6
        for z in range(math.floor(pz - r), math.ceil(pz + r) + 1):
            for x in range(math.floor(px - r), math.ceil(px + r) + 1):
                if math.hypot(x + 0.5 - px, z + 0.5 - pz) < r:
                    i = idx(x, z)
                    if i >= 0 and grid[i] == FREE:
                        grid[i] = ROAD
    return pts


def plaza(name, x, z, radius, pattern):
    plazas.append(dict(name=name, x=x, z=z, radius=radius, pattern=pattern))
    for gz in range(math.floor(z - radius), math.ceil(z + radius) + 1):
        for gx in range(math.floor(x - radius), math.ceil(x + radius) + 1):
            if math.hypot(gx + 0.5 - x, gz + 0.5 - z) < radius + 0.6:
                i = idx(gx, gz)
                if i >= 0 and grid[i] == FREE:
                    grid[i] = ROAD


def place(group, name, asset, x, z, yaw=0.0, margin=0.6, check=True, min_shore=5.0, value=BUILDING, allowed=(FREE,)):
    w, d = SIZES[asset]
    cells = rect_cells(x, z, w, d, yaw, margin)
    if check and not fits(cells, allowed, min_shore):
        return False
    for cx, cz in cells:
        i = idx(cx, cz)
        if i >= 0:
            grid[i] = value
    placed.append(dict(group=group, name=name, asset=asset, x=x, z=z, yaw=yaw))
    return True


def nearest_on(points, x, z):
    best = None
    for k, (px, pz) in enumerate(points):
        d = math.hypot(px - x, pz - z)
        if best is None or d < best[0]:
            best = (d, k, px, pz)
    return best


# ================================================================================
# 1. Spine: realm gate (north headland) -> tavern -> fountain -> garden -> chapel
# ================================================================================
GATE_Z = -104
plaza('GateCourt', 0, GATE_Z + 4, 9, 'tiles')
road('GateRoad', [(0, GATE_Z + 12), (1, -88), (0, -76)], 6, 'cobble')
road('GateForkWest', [(0, -77), (-8, -71), (-17, -66), (-22, -60)], 5, 'cobble')
road('GateForkEast', [(0, -77), (8, -71), (17, -66), (22, -60)], 5, 'cobble')

# Two main avenues run past both sides of the fountain square and the garden.
west_avenue = road('WestAvenue', [(-22, -61), (-21.5, -36), (-21, -12), (-21, 12), (-21.5, 40), (-22, 66), (-17, 78)], 6, 'cobble')
east_avenue = road('EastAvenue', [(22, -61), (21.5, -36), (21, -12), (21, 12), (21.5, 40), (22, 66), (17, 78)], 6, 'cobble')

plaza('FountainSquare', 0, 0, 18, 'rings')
road('TavernWalk', [(0, -17), (0, -35)], 6, 'tiles')
plaza('TavernYard', 0, -38, 9, 'tiles')
road('TavernLaneWest', [(-8, -38), (-21.5, -38)], 4, 'cobble')
road('TavernLaneEast', [(8, -38), (21.5, -38)], 4, 'cobble')

# Market streets lead west to the harbor and east to the lookout.
west_street = road('MarketStreetWest', [(-18, 0), (-34, 0.5), (-50, -1.5), (-63, 0)], 5, 'cobble')
east_street = road('MarketStreetEast', [(18, 0), (34, -0.5), (50, 1.5), (66, 0), (78, -6)], 5, 'cobble')
plaza('HarborSquare', -68, 0, 7, 'cobble')
road('Pier', [(-72, 0), (-84, 0), (-97, 0)], 4, 'pier', False)
road('PierArm', [(-93, 0), (-93, -9)], 3, 'pier', False)
plaza('Lookout', 81, -8, 6, 'rings')

# Garden between the avenues, closed by the chapel.
garden_walk = road('GardenWalk', [(0, 17), (0, 68)], 5, 'gravel')
for z in (36, 52):
    road('GardenCross%d' % z, [(-18.5, z), (18.5, z)], 3, 'gravel')
plaza('ChapelYard', 0, 71, 7, 'cobble')
road('ChapelLane', [(-18, 77), (-7, 73)], 3.5, 'gravel')
road('ChapelLaneEast', [(18, 77), (7, 73)], 3.5, 'gravel')

# Residential lanes: they leave the avenues and wind through the quarters.
lanes = {}
lanes['NorthwestLane'] = road('NorthwestLane', [(-22, -24), (-38, -26), (-52, -34), (-60, -48), (-56, -64), (-42, -72), (-24, -64)], 4, 'gravel')
lanes['NortheastLane'] = road('NortheastLane', [(22, -24), (38, -27), (54, -33), (62, -46), (58, -62), (44, -72), (24, -64)], 4, 'gravel')
lanes['SouthwestLane'] = road('SouthwestLane', [(-36, 0), (-38, 18), (-50, 30), (-56, 46), (-48, 62), (-30, 70), (-22, 64)], 4, 'gravel')
lanes['SoutheastLane'] = road('SoutheastLane', [(36, 0), (38, 18), (50, 30), (58, 46), (50, 62), (32, 70), (22, 64)], 4, 'gravel')
lanes['WestShoreLane'] = road('WestShoreLane', [(-60, -2), (-70, -16), (-72, -32), (-62, -48)], 3.5, 'dirt')
lanes['SouthShoreLane'] = road('SouthShoreLane', [(-56, 46), (-64, 30), (-66, 12), (-64, 2)], 3.5, 'dirt')
lanes['EastShoreLane'] = road('EastShoreLane', [(62, -46), (74, -32), (78, -16)], 3.5, 'dirt')
lanes['SoutheastShoreLane'] = road('SoutheastShoreLane', [(58, 46), (70, 32), (74, 14), (68, 2)], 3.5, 'dirt')
road('CrossLaneWest', [(-21.5, 30), (-40, 22)], 3, 'dirt')
road('CrossLaneEast', [(21.5, 30), (40, 22)], 3, 'dirt')

# ================================================================================
# 2. Landmarks
# ================================================================================
place('Buildings', 'GrandTavern', 'grand_tavern', 0, -50, math.pi, check=False)
place('Buildings', 'Chapel', 'chapel', 0, 84, 0.0, check=False)
place('Buildings', 'Smithy', 'smithy', -36, -12.5, math.pi, check=False)
place('Buildings', 'MagiciansHouse', 'magicians_house', 36, -13, math.pi, check=False)
place(None, 'Fountain', 'fountain', 0, 0, 0.0, check=False, value=PROP)
for side in (-1, 1):
    for k, z in enumerate((27.5, 43.5, 60.5)):
        place('Gardens', 'FlowerBed%s%d' % ('West' if side < 0 else 'East', k + 1), 'garden_bed', side * 9.5, z, 0.0, check=False, value=PROP)

# Market stalls line the streets near the square; a well by each quarter.
for k, x in enumerate((-30, -44)):
    place('StreetFurniture', 'MarketWest%d' % (k + 1), 'market', x, 6.2, yaw_facing(0, -1), margin=0.3)
for k, x in enumerate((29, 43, 57)):
    place('StreetFurniture', 'MarketEast%d' % (k + 1), 'market', x, 6.4, yaw_facing(0, -1), margin=0.3)
for k, (x, z) in enumerate([(-33, -32), (33, -32), (-33, 26), (33, 26), (-60, 10), (-62, -4.5)]):
    place('StreetFurniture', 'Well%d' % (k + 1), 'well', x, z, 0.0, margin=0.4)

# ================================================================================
# 3. Houses along the lanes and avenues, fronts toward the street
# ================================================================================
house_count = 0


def line_houses(points, half_width, start, step_range, sides=(1, -1), min_shore=7.0, setback=1.8):
    global house_count
    for side in sides:
        s = start
        total = len(points)
        while s < total - 1:
            k = int(s)
            ax, az = points[k]
            bx, bz = points[min(k + 8, total - 1)]
            tx, tz = bx - ax, bz - az
            length = math.hypot(tx, tz) or 1
            tx, tz = tx / length, tz / length
            nx, nz = -tz * side, tx * side
            asset = HOMES[house_count % len(HOMES)]
            w, d = SIZES[asset]
            dist = half_width + setback + d / 2
            hx, hz = ax + nx * dist, az + nz * dist
            yaw = yaw_facing(-nx, -nz)
            if place('Buildings', 'House%02d' % (house_count + 1), asset, hx, hz, yaw, margin=1.0, min_shore=min_shore):
                house_count += 1
                door = (hx - nx * (d / 2 + 0.2), hz - nz * (d / 2 + 0.2))
                street = (ax + nx * (half_width - 0.5), az + nz * (half_width - 0.5))
                walks.append((door, street))
                s += (w + rng.uniform(*step_range)) * 4
            else:
                s += 6


walks = []
for name in ('NorthwestLane', 'NortheastLane', 'SouthwestLane', 'SoutheastLane'):
    line_houses(lanes[name], 2, 10, (3, 7))
for name in ('WestShoreLane', 'SouthShoreLane', 'EastShoreLane', 'SoutheastShoreLane'):
    line_houses(lanes[name], 1.75, 8, (5, 10), min_shore=6.0)
line_houses(west_avenue, 3, 30, (3, 5), sides=(1,))
line_houses(east_avenue, 3, 30, (3, 5), sides=(-1,))
line_houses(west_street, 2.5, 50, (4, 6), sides=(1, -1))
line_houses(east_street, 2.5, 50, (4, 6), sides=(1, -1))
for k, (door, street) in enumerate(walks):
    road('DoorWalk%02d' % (k + 1), [door, street], 1.8, 'dirt', False)

# ================================================================================
# 4. Street furniture: lanterns along the main roads, benches facing views
# ================================================================================
def near_lamp(x, z, distance):
    return any(math.hypot(x - lx, z - lz) < distance for lx, lz in lamp_spots)


def line_lamps(points, half_width, spacing, offset=0.9):
    walked = spacing * 0.5
    side = 1
    for k in range(1, len(points)):
        walked += math.dist(points[k], points[k - 1])
        if walked < spacing:
            continue
        ax, az = points[k - 1]
        bx, bz = points[k]
        length = math.dist(points[k], points[k - 1]) or 1
        nx, nz = -(bz - az) / length, (bx - ax) / length
        for s in (side, -side):
            x, z = ax + nx * s * (half_width + offset), az + nz * s * (half_width + offset)
            if near_lamp(x, z, spacing * 0.6):
                continue
            if place('StreetFurniture', 'Lantern%02d' % (len(lamp_spots) + 1), 'lantern', x, z, 0.0, margin=0.3, min_shore=3.0):
                lamp_spots.append((x, z))
                walked = 0
                side = -side
                break


for r in roads:
    if r['name'] in ('WestAvenue', 'EastAvenue', 'GateRoad', 'MarketStreetWest', 'MarketStreetEast'):
        line_lamps(r['samples'], r['width'] / 2, 15)
    elif r['name'] in lanes and r['surface'] == 'gravel':
        line_lamps(r['samples'], r['width'] / 2, 20)
    elif r['name'] == 'GardenWalk':
        line_lamps(r['samples'], r['width'] / 2, 16, 0.8)
# Lanterns ring the fountain square and stand at the gate and harbor.
for k in range(8):
    a = (k + 0.5) * math.tau / 8
    x, z = math.cos(a) * 19.4, math.sin(a) * 19.4
    if place('StreetFurniture', 'Lantern%02d' % (len(lamp_spots) + 1), 'lantern', x, z, 0.0, margin=0.2, min_shore=3.0):
        lamp_spots.append((x, z))
for x, z in [(-6, GATE_Z + 9), (6, GATE_Z + 9), (-68, 7.5), (-68, -7.5)]:
    if place('StreetFurniture', 'Lantern%02d' % (len(lamp_spots) + 1), 'lantern', x, z, 0.0, margin=0.2, min_shore=0.5, check=False):
        lamp_spots.append((x, z))

bench_count = 0


def bench(x, z, face_x, face_z, check=True):
    global bench_count
    if place('StreetFurniture', 'Bench%02d' % (bench_count + 1), 'bench', x, z, yaw_facing(face_x - x, face_z - z),
             margin=0.2, min_shore=2.0, check=check, allowed=(FREE, ROAD)):
        bench_count += 1


# Around the fountain, leaving the four walkways open.
for deg in (25, 65, 115, 155, 205, 245, 295, 335):
    a = math.radians(deg)
    bench(math.cos(a) * 11.5, math.sin(a) * 11.5, 0, 0, check=False)
# Garden benches face each other across the walk; tavern yard and chapel yard.
for z in (27.5, 43.5, 60.5):
    bench(-4.0, z, 0, z, check=False)
    bench(4.0, z, 0, z, check=False)
for x in (-6.5, 6.5):
    bench(x, -38, x * 2, -38 + 0.0, check=False)
bench(-5, 68.5, -5, 60, check=False)
bench(5, 68.5, 5, 60, check=False)
# Harbor and lookout benches face the sea.
bench(-70, 5.5, -90, 12, check=False)
bench(-70, -5.5, -90, -12, check=False)
bench(84, -12, 110, -30, check=False)
bench(84, -4, 110, 10, check=False)
bench(-5, GATE_Z + 1, -5, GATE_Z + 12, check=False)
bench(5, GATE_Z + 1, 5, GATE_Z + 12, check=False)

# ================================================================================
# 5. Trees: blossom avenues, an orchard, coastal woods and beach palms
# ================================================================================
tree_count = 0


def tree(asset, x, z, min_shore=4.0, margin=1.2, check=True):
    global tree_count
    if place('Trees', 'Tree%03d' % (tree_count + 1), asset, x, z, rng.uniform(0, math.tau), margin=margin,
             min_shore=min_shore, value=TREE, check=check):
        tree_count += 1
        return True
    return False


# Blossom trees in the grass strips between the garden and the avenues.
for side in (-1, 1):
    for z in (22, 35.5, 51.5, 68):
        tree('blossom_tree', side * 15.6, z, margin=0.8)
    for z in (-58, -46, -28):
        tree('blossom_tree', side * 12.5, z, margin=0.8)
# Orchard in the north-east corner, wild meadow orchard in the north-west.
for row in range(6):
    for col in range(6):
        x = 34 + col * 5.5 + (2.7 if row % 2 else 0)
        z = -60 + row * 5.0
        if math.hypot(x, z) < 80:
            tree('orchard_tree', x, z, margin=0.9)
# Woods along the coast, then scattered trees through the quarters.
WOODS = ['nature_tree_round', 'nature_tree_round', 'nature_tree_tall', 'nature_tree_tall', 'nature_tree_small', 'nature_bush', 'nature_pine', 'orchard_tree']
attempts = 0
while attempts < 40000:
    attempts += 1
    x, z = rng.uniform(-E, E), rng.uniform(-E, E)
    s = shore_at(x, z)
    if s < 0:
        continue
    if s < 4.5:
        if 2.1 < s < 2.9:
            continue  # the beach step: keep props clearly above or below it
        if s > 1.5 and rng.random() < 0.10:
            tree('nature_palm', x, z, min_shore=1.0, margin=2.0)
        elif s > 2.5 and rng.random() < 0.04:
            tree(rng.choice(['nature_rock', 'nature_boulder']), x, z, min_shore=0.5, margin=1.0)
        continue
    density = 0.7 if s < 18 else 0.08
    if rng.random() < density:
        tree(rng.choice(WOODS), x, z, min_shore=4.0, margin=1.1 if s < 18 else 2.4)

# ================================================================================
# 6. Residents
# ================================================================================
residents.append(dict(name='BramTheSmith', label='Bram the Smith', role='smith', x=-31.0, z=-5.0, yaw=0.0, stationary=True,
                      greeting='The forge is warm and the road is calling. Bring your equipment here when you need a smith.'))
residents.append(dict(name='MiraTheMagician', label='Mira the Magician', role='magician', x=31.5, z=-5.2, yaw=0.0, stationary=True,
                      greeting='There is magic in every journey. My stall by the tower will be here when you return.'))
residents.append(dict(name='TessaTheInnkeeper', label='Tessa the Innkeeper', role='baker', x=5.5, z=-42.0, yaw=0.0, stationary=True,
                      greeting='Welcome to the Hearthhaven Tavern. Rest by the fountain, then follow the north road to the realm gate.'))
roles = ['villager', 'gardener', 'traveler', 'baker']
starts = [(-21, -50), (21, -50), (-12, 12), (12, -12), (-21, 20), (21, 20), (0, 30), (0, 60), (-40, 0), (40, 0),
          (-45, -30), (45, -30), (-45, 30), (45, 30), (-62, 0), (70, -4), (0, -90), (-36, -60), (36, -60), (-10, 75),
          (10, 75), (-58, 20), (60, 20), (-20, -72)]
for k, (x, z) in enumerate(starts):
    residents.append(dict(name='Neighbor%d' % (k + 1), label='Neighbor %d' % (k + 1), role=roles[k % 4], x=x, z=z, yaw=0.0,
                          stationary=False, greeting='Lovely day in Hearthhaven!'))


# ================================================================================
# 7. Write the scene
# ================================================================================
ext, sub, nodes = [], [], []


def resource(kind, path):
    ident = 'E%d' % len(ext)
    ext.append('[ext_resource type="%s" path="res://%s" id="%s"]' % (kind, path, ident))
    return ident


def v3(a):
    return 'Vector3(%s)' % ', '.join(str(round(i, 4)) for i in a)


def node(name, parent='.', kind='Node3D', props=None, instance=None):
    decl = '[node name="%s"' % name
    if parent is not None:
        decl += ' parent="%s"' % parent
    decl += ' instance=ExtResource("%s")]' % instance if instance else ' type="%s"]' % kind
    nodes.append(decl + ''.join('\n%s = %s' % (k, val) for k, val in (props or {}).items()))


def curve(points, closed=False):
    ident = 'Curve%d' % len(sub)
    hs = handles(points, closed)
    if closed:
        hs = hs + [hs[0]]
    data = []
    for p, i, o in hs:
        data += [i[0], 0, i[1], o[0], 0, o[1], p[0], Y, p[1]]
    sub.append('[sub_resource type="Curve3D" id="%s"]\n_data = {\n"points": PackedVector3Array(%s),\n"tilts": PackedFloat32Array(%s)\n}\npoint_count = %d'
               % (ident, ', '.join(str(round(c, 3)) for c in data), ', '.join('0' for _ in hs), len(hs)))
    return 'SubResource("%s")' % ident


def ground_y(x, z):
    """Standing height: beaches are one block below the town plateau."""
    return Y - 1 if shore_at(x, z) < 2.5 else Y


def rot(yaw):
    return v3((0, yaw, 0))


hall = resource('Script', 'scripts/world/hall_world.gd')
resident_script = resource('Script', 'scripts/world/home_resident.gd')
fountain_script = resource('Script', 'scripts/world/voxel_fountain.gd')
preview = resource('Script', 'scripts/world/home_preview_ground.gd')
road_script = resource('Script', 'scripts/world/home_road.gd')
plaza_script = resource('Script', 'scripts/world/home_plaza.gd')
water = resource('Shader', 'shaders/water.gdshader')
prefabs = {}
for p in placed:
    if p['asset'] not in prefabs:
        prefabs[p['asset']] = resource('PackedScene', 'scenes/home/prefabs/%s.tscn' % p['asset'])
sub.append('[sub_resource type="ShaderMaterial" id="SeaMaterial"]\nshader = ExtResource("%s")' % water)
sub.append('[sub_resource type="PlaneMesh" id="SeaPlane"]\nmaterial = SubResource("SeaMaterial")\nsize = Vector2(900, 900)')

node('Tavern', None, props={'script': 'ExtResource("%s")' % hall})
node('Spawn', kind='Marker3D', props={'position': v3((0, Y, -11.5))})
node('RealmGate', kind='Marker3D', props={'position': v3((0, Y, GATE_Z)), 'rotation': rot(math.pi)})
node('Coastline', kind='Path3D', props={'curve': curve(COAST, closed=True)})
node('EditorGround', kind='MeshInstance3D', props={'script': 'ExtResource("%s")' % preview})
node('CoastWater', kind='MeshInstance3D', props={'position': v3((0, 8.6, 0)), 'mesh': 'SubResource("SeaPlane")', 'cast_shadow': '0'})
node('Roads')
for r in roads:
    node(r['name'], 'Roads', 'Path3D', {'curve': curve(r['points']), 'script': 'ExtResource("%s")' % road_script,
                                         'width': r['width'], 'surface': json.dumps(r['surface']), 'curbs': str(r['curbs']).lower()})
node('Plazas')
for p in plazas:
    node(p['name'], 'Plazas', 'Marker3D', {'position': v3((p['x'], Y, p['z'])), 'script': 'ExtResource("%s")' % plaza_script,
                                            'radius': p['radius'], 'pattern': json.dumps(p['pattern'])})
for group in ('Buildings', 'Gardens', 'StreetFurniture', 'Trees'):
    node(group)
for p in placed:
    props = {'position': v3((p['x'], ground_y(p['x'], p['z']), p['z']))}
    if abs(p['yaw']) > 1e-6:
        props['rotation'] = rot(p['yaw'])
    node(p['name'], p['group'] or '.', props=props, instance=prefabs[p['asset']])
    if p['name'] == 'Fountain':
        node('CascadingWater', 'Fountain', props={'script': 'ExtResource("%s")' % fountain_script})
node('Residents')
for r in residents:
    node(r['name'], 'Residents', 'Marker3D', {
        'position': v3((r['x'], Y, r['z'])), 'rotation': rot(r['yaw']), 'script': 'ExtResource("%s")' % resident_script,
        'role': json.dumps(r['role']), 'resident_name': json.dumps(r['label']), 'stationary': str(r['stationary']).lower(),
        'greeting': json.dumps(r['greeting']), 'interaction_enabled': str(r['stationary']).lower()})
out = ROOT / 'scenes/home/tavern.tscn'
out.write_text('[gd_scene format=3]\n\n' + '\n\n'.join(ext + sub + nodes) + '\n')
counts = {}
for p in placed:
    counts[p['group']] = counts.get(p['group'], 0) + 1
print('Authored home island:', counts, 'houses', house_count, 'roads', len(roads), 'residents', len(residents))

# --- plan preview -----------------------------------------------------------------
try:
    from PIL import Image, ImageDraw
    S = 4
    img = Image.new('RGB', (SIDE * S, SIDE * S), (32, 61, 84))
    px = img.load()
    colors = {FREE: (86, 140, 66), ROAD: (150, 140, 120), BUILDING: (150, 82, 60), PROP: (200, 200, 220), TREE: (40, 96, 44)}
    for z in range(SIDE):
        for x in range(SIDE):
            i = z * SIDE + x
            if not land[i]:
                continue
            c = colors[grid[i]]
            if grid[i] == FREE and shore[i] < 4:
                c = (216, 200, 140)
            for dy in range(S):
                for dx in range(S):
                    px[x * S + dx, z * S + dy] = c
    draw = ImageDraw.Draw(img)
    for r in roads:
        pts = [((x + E) * S, (z + E) * S) for x, z in r['samples']]
        draw.line(pts, fill=(235, 225, 190) if r['surface'] != 'pier' else (120, 80, 50), width=max(1, int(r['width'] * S * 0.5)))
    for p in placed:
        if p['group'] == 'Buildings':
            draw.text(((p['x'] + E) * S - 10, (p['z'] + E) * S - 5), p['asset'][:6], fill=(255, 255, 255))
            fx, fz = -math.sin(p['yaw']), -math.cos(p['yaw'])
            cx, cz = (p['x'] + E) * S, (p['z'] + E) * S
            draw.line([(cx, cz), (cx + fx * 22, cz + fz * 22)], fill=(255, 230, 0), width=2)
    for r in residents:
        cx, cz = (r['x'] + E) * S, (r['z'] + E) * S
        draw.ellipse([cx - 4, cz - 4, cx + 4, cz + 4], fill=(255, 0, 255) if r['stationary'] else (0, 255, 255))
    img.save(ROOT / 'docs/realm_expansion/tavern_plan.png')
except ImportError:
    pass
