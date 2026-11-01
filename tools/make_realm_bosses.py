#!/usr/bin/env python3
"""Live realm boss art (offline tool, never run by the game).

Promotes the staged bosses into creatures/<id>/ with refined sculpting and
all encounter forms, and adds the dormant shells and new minions:

  rimeheart_prism        sealed (default), conduit, tempest
  rimeheart_conduit      healing tower        rimeheart_shardling  hostile add
  vharok_cinder_tyrant   default, infernal, heart_unbound
  cinder_sentinel        obsidian shield guard
  aureate_scarab_regent  default, sunwings, sunheart
  dawn_scarab            optional beetle minion
  hollow_crown           default, fractured_court, unbound
  mirror_shade           optional spectral minion
  egg_blue_dragon, egg_rimeheart, egg_vharok, egg_scarab, egg_hollow_crown
                         dormant shells with crack1..crack3 variants

Coordinates: voxels, y up, facing -Z. Parts stay within 256 voxels per axis;
variants of a part share one frame (CreatureModel.set_variant needs that).
Run:  python tools/make_realm_bosses.py
then: godot --headless --path . --script tools/bake_realm_boss_art.gd
"""
import math, random
import make_realm_boss_art as art
from make_realm_boss_art import ring, crystal, enrich_ice, limb, part, ICE, FIRE, GOLD, VOID
from preview_voxel_batch import ROOT

art.OUT = ROOT / 'creatures'
save = art.save
rng = random.Random(4242)

# Extra colors (appended so existing palette indices stay put).
ICE.update({'stone': (96, 104, 118), 'stone_light': (138, 146, 158), 'stone_dark': (58, 63, 76), 'frost': (220, 236, 244),
            'glow_vein': (120, 220, 255)})
FIRE.update({'tooth': (230, 214, 178), 'rock': (66, 34, 30), 'rock_light': (104, 49, 38), 'cocoon': (24, 20, 26),
             'cocoon_light': (46, 36, 44), 'glow_seam': (255, 96, 40), 'hoof': (22, 18, 20), 'vein': (60, 14, 22)})
GOLD.update({'jewel': (247, 160, 205), 'pearl': (250, 244, 236), 'chitin': (34, 52, 60), 'glow_slit': (255, 120, 190),
             'glow_lens': (255, 236, 160), 'sand': (196, 160, 104)})
VOID.update({'bone': (206, 196, 176), 'bone_dark': (142, 130, 116), 'tablet': (40, 30, 56), 'shade': (60, 46, 86),
             'glow_dim': (150, 64, 150), 'glow_cyan': (96, 230, 238)})
BLUE = {'scale': (46, 92, 156), 'scale_light': (84, 140, 206), 'scale_dark': (26, 52, 104), 'nest': (70, 66, 74),
        'nest_light': (104, 98, 106), 'glow_seam': (102, 236, 255), 'glow_core': (186, 250, 255)}


def recolor(v, fn):
    return {k: fn(k, c) for k, c in v.items()}


def chip(v, chance, keep=('glow',)):
    """Knocks random surface voxels off for chipped, weathered edges."""
    out = {}
    for k, c in v.items():
        exposed = any((k[0] + d[0], k[1] + d[1], k[2] + d[2]) not in v for d in ((1, 0, 0), (-1, 0, 0), (0, 1, 0), (0, -1, 0), (0, 0, 1), (0, 0, -1)))
        if exposed and not c.startswith(keep) and rng.random() < chance:
            continue
        out[k] = c
    return out


def crack_paths(seed, count, center, radius, height):
    """Random wandering crack polylines over an egg's surface."""
    r = random.Random(seed)
    paths = []
    for _ in range(count):
        a = r.random() * math.tau
        y = center[1] + (r.random() - 0.3) * height * 0.6
        pts = []
        for step in range(14):
            a += r.uniform(-0.25, 0.25)
            y += r.uniform(-4, 7)
            pts.append((center[0] + math.cos(a) * radius, y, center[2] + math.sin(a) * radius))
        paths.append(pts)
    return paths


def carve_cracks(v, paths, width, glow):
    """Removes voxels along crack paths (real gaps) and lights their rims."""
    out = dict(v)
    near = set()
    for pts in paths:
        for a, b in zip(pts, pts[1:]):
            for t in range(12):
                k = t / 12
                p = (a[0] + (b[0] - a[0]) * k, a[1] + (b[1] - a[1]) * k, a[2] + (b[2] - a[2]) * k)
                cx, cy, cz = (round(q) for q in p)
                r = int(math.ceil(width + 2))
                for dx in range(-r, r + 1):
                    for dy in range(-r, r + 1):
                        for dz in range(-r, r + 1):
                            q = (cx + dx, cy + dy, cz + dz)
                            if q not in out:
                                continue
                            d = math.sqrt(dx * dx + dy * dy + dz * dz)
                            if d <= width and not out[q].startswith('glow'):
                                del out[q]
                            elif d <= width + 1.6:
                                near.add(q)
    for q in near:
        if q in out and not out[q].startswith('glow'):
            out[q] = glow
    return out


def egg_set(name, title, biome, pal, shell, core, cracks, glow, unit=0.04, **rig):
    """A shell with three progressively cracked variants and a lit core inside."""
    parts = {'body': {**core, **shell}}
    for stage in (1, 2, 3):
        cut = carve_cracks(shell, cracks[:stage * len(cracks) // 3], 1.6 + stage * 0.9, glow)
        parts['body_crack%d' % stage] = {**core, **cut}
    variants = {'crack%d' % s: {'body': 'body_crack%d' % s} for s in (1, 2, 3)}
    save(name, title, biome, pal, parts, {}, variants, unit=unit, hover=0, hand=[0, 40, 0], **rig)


# --- Shells ---------------------------------------------------------------------------

def blue_egg():
    p = part(BLUE)
    p.ellipsoid((0, 48, 0), (34, 46, 34), 'scale')
    shell = p.voxels()
    # Overlapping scale rows with lighter rims and cyan seams between bands.
    def scales(k, c):
        x, y, z = k
        a = math.atan2(z, x)
        row = (y + 2) // 7
        col = int((a + math.pi) / math.tau * 18 + (row % 2) * 0.5)
        local = (y + 2) % 7
        if (y + int(a * 9)) % 23 == 0:
            return 'glow_seam'
        if local == 0:
            return 'scale_dark'
        return 'scale_light' if local >= 5 and col % 2 == 0 else 'scale'
    shell = recolor(shell, scales)
    n = part(BLUE)
    for i in range(11):
        a = i * math.tau / 11
        n.ellipsoid((math.cos(a) * 34, 6, math.sin(a) * 34), (12, 8 + i % 3 * 2, 10), 'nest' if i % 2 else 'nest_light')
    shell.update(chip(n.voxels(), 0.12))
    c = part(BLUE)
    c.ellipsoid((0, 48, 0), (24, 34, 24), 'glow_core')
    core = c.voxels()
    egg_set('egg_blue_dragon', 'Azure Egg', 'Bluelay', BLUE, shell, core, crack_paths(11, 9, (0, 48, 0), 33, 80), 'glow_seam')


def frost_geode():
    p = part(ICE)
    crystal(p, (0, 30, 0), 50, 64, 'stone', angle=0.3)
    p.box((-44, 0, -44), (44, 12, 44), 'stone_dark')
    shell = p.voxels()
    def frosted(k, c):
        x, y, z = k
        if y > 52 and (x * 3 + z * 5) % 7 < 3:
            return 'frost'
        if (x * 7 + y * 3 + z * 5) % 97 == 0:
            return 'glow_vein'
        return ['stone', 'stone_light', 'stone', 'stone_dark'][(x // 9 + z // 9 + y // 13) % 4]
    shell = chip(recolor(shell, frosted), 0.08)
    c = part(ICE)
    crystal(c, (0, 34, 0), 32, 46, 'glow_core', angle=0.3)
    egg_set('egg_rimeheart', 'Frost Geode', 'Fosen', ICE, shell, c.voxels(),
            crack_paths(12, 12, (0, 32, 0), 46, 50), 'glow_vein')


def vharok_cocoon():
    p = part(FIRE)
    p.ellipsoid((0, 70, 0), (26, 52, 24), 'cocoon')
    for i in range(9):
        y = 30 + i * 9
        ring(p, (0, y, 0), 26 - abs(i - 4) * 2, 2.2, 'cocoon_light', n=36)
    p.chain([(-8, 118, -10), (-14, 134, -6), (-10, 142, 2)], 5, 1, 'cocoon_light')
    p.chain([(8, 118, -10), (14, 134, -6), (10, 142, 2)], 5, 1, 'cocoon_light')
    cocoon = p.voxels()
    r = part(FIRE)
    # The cracked volcanic cradle: curved rock claws rising around the base.
    for i in range(7):
        a = i * math.tau / 7 + 0.2
        base = (math.cos(a) * 36, 4, math.sin(a) * 36)
        tip = (math.cos(a) * 24, 54 + (i % 3) * 8, math.sin(a) * 24)
        r.chain([base, (math.cos(a) * 40, 30, math.sin(a) * 40), tip], 11, 3, 'rock' if i % 2 else 'rock_light')
    r.ellipsoid((0, 6, 0), (42, 9, 42), 'rock')
    cradle = r.voxels()
    cradle = recolor(cradle, lambda k, c: 'glow_seam' if (k[0] * 5 + k[1] * 2 + k[2] * 3) % 61 == 0 else c)
    shell = {**cradle, **cocoon}
    c = part(FIRE)
    c.ellipsoid((0, 74, -4), (16, 34, 14), 'glow_core')
    c.ellipsoid((0, 86, -8), (7, 7, 6), 'glow_hot')
    egg_set('egg_vharok', 'Obsidian Cocoon', 'Lava', FIRE, shell, c.voxels(),
            crack_paths(13, 9, (0, 70, 0), 25, 90), 'glow_seam')


def scarab_reliquary():
    p = part(GOLD)
    p.ellipsoid((0, 46, 0), (48, 38, 36), 'gold')
    shell = p.voxels()
    def engraved(k, c):
        x, y, z = k
        if abs(x) <= 1 and z < 0:
            return 'glow_slit'
        band = (y + 60) % 12
        if band == 0:
            return 'gold_dark'
        if band in (5, 6) and (int(math.atan2(z, x) * 12) % 2 == 0):
            return 'ivory'
        if (x * 3 + y * 5 + z * 7) % 211 == 0:
            return 'jewel'
        return 'gold_light' if band in (1, 2) else 'gold'
    shell = recolor(shell, engraved)
    b = part(GOLD)
    b.ellipsoid((0, 8, 0), (40, 9, 30), 'ivory_dark')
    for s in (-1, 1):
        b.chain([(s * 48, 46, 0), (s * 54, 28, 0), (s * 44, 6, 0)], 5, 3, 'gold_dark')
    shell.update(b.voxels())
    c = part(GOLD)
    c.ellipsoid((0, 46, 0), (30, 24, 22), 'glow_heart')
    c.ellipsoid((0, 50, -6), (9, 9, 9), 'glow_sun')
    egg_set('egg_scarab', 'Solar Reliquary', 'Desert', GOLD, shell, c.voxels(),
            crack_paths(14, 9, (0, 46, 0), 44, 60), 'glow_slit', unit=0.044)


def crown_reliquary():
    p = part(VOID)
    p.box((-22, 4, -16), (22, 150, 16), 'cloth_dark')
    p.ellipsoid((0, 150, 0), (22, 16, 16), 'cloth_dark')
    for y in (30, 70, 110):
        p.box((-24, y, -18), (24, y + 6, 18), 'silver')
    p.box((-3, 20, -18), (3, 140, -16), 'edge')
    shell = p.voxels()
    shell = recolor(shell, lambda k, c: 'glow_rune' if c == 'cloth_dark' and (k[0] * 3 + k[1]) % 37 == 0 and k[2] < -14 else c)
    f = part(VOID)
    # Floating crown fragments bind the reliquary, hovering apart from it.
    for i in range(7):
        a = i * math.tau / 7
        x, z = math.cos(a) * 34, math.sin(a) * 34
        f.chain([(x, 104 + (i % 2) * 6, z), (x * 1.08, 124 + (i % 3) * 5, z * 1.08), (x * 0.95, 136, z * 0.95)], 4, 0.5, 'gold' if i % 2 else 'silver')
        f.ellipsoid((x, 112, z), (2, 3, 2), 'glow_rune')
    shell.update(f.voxels())
    b = part(VOID)
    b.box((-30, 0, -24), (30, 5, 24), 'armor')
    shell.update(b.voxels())
    c = part(VOID)
    c.ellipsoid((0, 90, 0), (16, 52, 11), 'glow_core')
    c.ellipsoid((0, 128, -6), (5, 4, 3), 'glow_eye')
    egg_set('egg_hollow_crown', 'Black Reliquary', 'Dark', VOID, shell, c.voxels(),
            crack_paths(15, 9, (0, 80, 0), 22, 130), 'glow_core')


# --- Rimeheart Prism ------------------------------------------------------------------

def frost_detail(v):
    """Chipped facets, fracture veins and asymmetric rime on top of enrich_ice."""
    v = enrich_ice(v)
    def veins(k, c):
        x, y, z = k
        if c in ('ice', 'ice_light', 'ice_dark') and (abs((x * 2 + y + z * 3) % 53) == 0 or abs((x - y * 2 + z) % 71) == 0):
            return 'glow_vein'
        return c
    return chip(recolor(v, veins), 0.05)


def frost():
    parts = {}
    for stage in ['sealed', 'conduit', 'tempest']:
        p = part(ICE)
        if stage == 'sealed':
            crystal(p, (0, 113, 0), 30, 152, 'ice')
            crystal(p, (0, 125, -18), 12, 56, 'glow_core')
            for s in [-1, 1]:
                p.capsule((s * 13, 78, -26), (s * 5, 119, -31), 1.3, 1.3, 'glow_rune')
            # Asymmetric rime growths on the flanks.
            for (x, y, z, r, h) in [(-24, 70, 8, 8, 30), (20, 150, -6, 6, 24), (-10, 40, 22, 7, 22)]:
                crystal(p, (x, y, z), r, h, 'ice_light', angle=0.5)
        else:
            p.ellipsoid((0, 111, 0), (19, 24, 19), 'glow_core')
            crystal(p, (0, 112, 0), 12, 47, 'glow_hot')
            for y in [75, 148]:
                ring(p, (0, y, 0), 28 if stage == 'conduit' else 34, 2, 'metal_light', n=6)
            crystal(p, (0, 180, 0), 9, 31, 'ice_light')
            crystal(p, (0, 41, 0), 13, 24, 'ice')
            if stage == 'tempest':
                ring(p, (0, 111, 0), 44, 1.6, 'glow_rune', n=6)
        for i in range(6):
            a = i * math.tau / 6
            x, z = math.cos(a) * 31, math.sin(a) * 31
            crystal(p, (x, 20 + (i % 2) * 6, z), 7, 23, 'metal_light')
            crystal(p, (x, 24 + (i % 2) * 6, z), 4, 15, 'glow_rune')
        parts['body' if stage == 'sealed' else 'body_' + stage] = frost_detail(p.voxels())
        q = part(ICE)
        if stage == 'sealed':
            crystal(q, (0, 2, 5), 13, 103, 'ice')
            crystal(q, (-8, -18, 9), 8, 44, 'ice_light')
            crystal(q, (0, 38, 4), 4, 18, 'glow_rune')
        elif stage == 'conduit':
            crystal(q, (0, 11, 28), 17, 118, 'ice')
            crystal(q, (0, 12, 25), 8, 75, 'ice_light')
            crystal(q, (0, 62, 28), 4, 18, 'glow_core')
            ring(q, (0, -29, 28), 19, 1.5, 'metal', n=6)
        else:
            q.triangle((-18, -3, 14), (18, -3, 14), (0, 3, 77), 5, 'ice')
            q.triangle((-11, 1, 19), (11, 1, 19), (0, 6, 69), 2, 'ice_light')
            q.capsule((0, 4, 16), (0, 6, 70), 1.4, .4, 'glow_core')
            crystal(q, (0, 17, 27), 9, 48, 'ice')
        parts['petal' if stage == 'sealed' else 'petal_' + stage] = frost_detail(q.voxels())
    limbs = {}
    for i in range(6):
        a = i * math.tau / 6
        limbs['shard_' + str(i)] = limb('petal', [round(math.sin(a) * 34), 100 + (i % 2) * 8, round(math.cos(a) * 34)], role='', yaw=i * 60)
    save('rimeheart_prism', 'Rimeheart Prism', 'Fosen', ICE, parts, limbs,
         {'conduit': {'body': 'body_conduit', 'petal': 'petal_conduit'}, 'tempest': {'body': 'body_tempest', 'petal': 'petal_tempest'}},
         hand=[0, 111, -30], hover=.6)
    # Healing conduit: hex base with lower attack ports, a six-port beam crown.
    p = part(ICE)
    crystal(p, (0, 6, 0), 19, 12, 'metal')
    for y, r, h in [(24, 10, 36), (60, 7, 58), (100, 13, 27)]:
        crystal(p, (0, y, 0), r, h, 'ice')
    ring(p, (0, 20, 0), 12, 2, 'metal_light', n=6)
    ring(p, (0, 84, 0), 14, 2, 'metal_light', n=6)
    crystal(p, (0, 100, 0), 7, 22, 'glow_core')
    for i in range(6):
        a = i * math.tau / 6
        p.ellipsoid((math.cos(a) * 12, 85, math.sin(a) * 12), (3, 3, 3), 'glow_hot')
        p.ellipsoid((math.cos(a + 0.5) * 16, 10, math.sin(a + 0.5) * 16), (2.5, 2, 2.5), 'glow_rune')
    save('rimeheart_conduit', 'Rimeheart Healing Conduit', 'Fosen', ICE, {'body': frost_detail(p.voxels())}, unit=.032, hover=0, hand=[0, 85, 0])
    p = part(ICE)
    crystal(p, (0, 29, 0), 13, 39, 'ice')
    crystal(p, (0, 33, -9), 7, 19, 'ice_dark')
    for s in [-1, 1]:
        p.ellipsoid((s * 5, 34, -14), (2, 2, 1.2), 'glow_hot')
        for z in [-3, 6]:
            p.chain([(s * 10, 24, z), (s * 21, 20, z + 2), (s * 24, 6, z - 5)], 3, .5, 'ice_light')
    crystal(p, (0, 45, 3), 5, 25, 'glow_core')
    save('rimeheart_shardling', 'Rimeheart Shardling', 'Fosen', ICE, {'body': enrich_ice(p.voxels())}, unit=.03, hover=.2, hand=[0, 33, -16])


# --- Vharok -----------------------------------------------------------------------------

def demon_body(form):
    """form: default, infernal or heart_unbound."""
    p = part(FIRE)
    p.ellipsoid((0, 111, 0), (33, 44, 21), 'skin')
    p.ellipsoid((0, 132, -4), (43, 25, 24), 'skin_light')
    for s in [-1, 1]:
        p.ellipsoid((s * 18, 135, -20), (18, 16, 8), 'skin')
        p.ellipsoid((s * 16, 88, 0), (19, 18, 18), 'armor')
        # Layered pauldrons and shoulder blades.
        p.ellipsoid((s * 43, 146, 0), (22, 15, 24), 'armor')
        p.ellipsoid((s * 44, 140, 4), (20, 9, 22), 'armor_light')
        for dx, dy, dz in [(0, 24, -5), (14, 10, 0), (-6, 9, 17)]:
            p.capsule((s * 43, 151, dz), (s * (43 + dx), 151 + dy, dz + 6), 7, .5, 'metal')
        p.ellipsoid((s * 22, 140, 18), (12, 18, 5), 'armor')  # shoulder blade
    # Head: heavy brow, shaped jaw, irregular teeth, burning eyes.
    p.ellipsoid((0, 168, -3), (18, 24, 16), 'skin_dark')
    p.ellipsoid((0, 166, -17), (15, 12, 13), 'skin')
    p.ellipsoid((0, 176, -22), (17, 4, 6), 'skin_dark')  # brow ridge
    p.ellipsoid((0, 154, -20), (13, 7, 9), 'skin_dark')  # jaw
    p.box((-11, 157, -29), (11, 161, -25), 'dark')
    for i, x in enumerate(range(-9, 11, 3)):
        length = 4 + (i * 7) % 4
        p.capsule((x, 161, -28), (x + (1 if i % 2 else -1), 161 - length, -29), 1.1, .2, 'tooth')
        p.capsule((x + 1, 157, -28), (x + 1, 157 + length - 1, -29), 1.0, .2, 'tooth')
    chipped = form == 'heart_unbound'
    for s in [-1, 1]:
        p.ellipsoid((s * 8, 172, -21), (5, 2.5, 3), 'glow_hot')
        p.capsule((s * 3, 182, -19), (s * 16, 181, -13), 3.5, 4, 'armor')
        tip = (s * 18, 235, -2) if not (chipped and s > 0) else (s * 26, 222, 4)
        p.chain([(s * 11, 186, 1), (s * 25, 201, 8), (s * 28, 223, 5), tip], 7, 1, 'horn')
        for k in range(4):  # grooves along the horn curve
            y = 195 + k * 9
            p.ellipsoid((s * (20 + k * 2), y, 6), (5.5 - k * 0.6, 1.2, 5.5 - k * 0.6), 'horn_light')
    # Rib plates over the abdomen; damaged and opened in the final form.
    for y in [101, 112, 123]:
        for s in [-1, 1]:
            if chipped and y == 112:
                p.capsule((s * 14, y, -18), (s * 26, y + 5, -15), 3, 4, 'armor_light')
            else:
                p.capsule((s * 6, y, -20), (s * 26, y + 3, -16), 3, 4, 'armor')
    if chipped:
        p.ellipsoid((0, 120, -21), (13, 18, 6), 'vein')
        p.ellipsoid((0, 122, -24), (9, 12, 5), 'glow_hot')
        p.ellipsoid((0, 122, -27), (5, 6, 3), 'glow_core')
        for a in range(8):
            ang = a * math.tau / 8
            p.capsule((0, 122, -25), (math.cos(ang) * 22, 122 + math.sin(ang) * 26, -19), 1.2, .4, 'glow_core')
    else:
        p.ellipsoid((0, 127, -25), (10, 14, 4), 'armor')
        p.triangle((0, 139, -30), (-6, 122, -30), (6, 122, -30), 2, 'glow_core')
        p.capsule((0, 123, -30), (0, 114, -25), 2.3, .8, 'glow_core')
    body = p.voxels()
    if form != 'default':
        body = recolor(body, lambda k, c: 'glow_core' if c in ('skin', 'skin_light') and k[2] < -13 and (k[0] + int(k[1] * .4)) % 21 in (0, 1) else c)
    return body


def demon():
    parts = {'body': demon_body('default'), 'body_infernal': demon_body('infernal'), 'body_unbound': demon_body('heart_unbound')}
    limbs = {}
    for s, label in [(-1, 'l'), (1, 'r')]:
        a = part(FIRE)
        a.chain([(0, 0, 0), (s * 11, -23, -2), (s * 12, -47, -12)], 12, 8, 'skin')
        a.ellipsoid((s * 10, -34, -5), (12, 16, 12), 'armor')
        a.ellipsoid((s * 12, -48, -13), (11, 12, 9), 'skin_light')
        for j in range(4):  # individual hooked claws
            a.chain([(s * (5 + j * 4), -51, -16), (s * (5 + j * 4), -61, -21), (s * (4 + j * 4), -66, -27), (s * (3 + j * 4), -64, -31)], 2.4, .3, 'horn')
        a.capsule((s * 10, -27, -15), (s * 13, -43, -22), 1.5, .8, 'glow_core')
        parts['arm_' + label] = a.voxels()
        limbs['arm_' + label] = limb('arm_' + label, [s * 44, 140, 0], 'arm', phase=-s, throws=False)
        lg = part(FIRE)
        lg.chain([(0, 0, 0), (s * 5, -30, 5), (s * 8, -58, -3)], 12, 7, 'skin_dark')
        lg.ellipsoid((s * 8, -62, -7), (11, 7, 15), 'armor')
        lg.ellipsoid((s * 6, -32, 0), (11, 14, 10), 'armor_light')
        for dx in (-4, 4):  # split hooves
            lg.ellipsoid((s * 8 + dx, -66, -16), (4, 4, 7), 'hoof')
        parts['leg_' + label] = lg.voxels()
        limbs['leg_' + label] = limb('leg_' + label, [s * 20, 69, 0], 'leg', phase=-s)
        for form in ('', '_unbound'):
            w = part(FIRE)
            shoulder = (0, 0, 0)
            elbow = (s * 30, 28, 8)
            wrist = (s * 53, 40, 6)
            tips = [(s * 84, 31, 8), (s * 81, -9, 14), (s * 64, -36, 20), (s * 35, -47, 18)]
            for i in range(3):
                w.triangle(wrist, tips[i], tips[i + 1], 2.8, 'wing' if i % 2 else 'wing_light')
            w.triangle(wrist, tips[-1], shoulder, 3, 'wing')
            w.chain([shoulder, elbow, wrist], 4.5, 3, 'armor')
            for tip in tips:
                w.capsule(wrist, tip, 2.5, 1, 'armor_light')
                mid = ((wrist[0] + tip[0]) / 2, (wrist[1] + tip[1]) / 2 - 4, (wrist[2] + tip[2]) / 2 + 1)
                w.capsule(mid, (tip[0] * .8, tip[1] * .8 - 6, tip[2]), .8, .5, 'vein')  # wing veins
                w.capsule((tip[0] * .95, tip[1], tip[2]), tip, 1, 1, 'glow_core')
            v = w.voxels()
            if form:
                # Torn membrane: ragged holes in the outer panels.
                v = {k: c for k, c in v.items() if not (c.startswith('wing') and abs(k[0]) > 58 and (k[1] * 3 + k[0] * 5) % 9 < 3)}
            parts['wing_' + label + form] = v
        limbs['wing_' + label] = limb('wing_' + label, [s * 34, 145, 15], 'wing', phase=-s)
    t = part(FIRE)
    t.chain([(0, 0, 0), (9, -15, 24), (25, -31, 49), (31, -18, 66)], 7, 2, 'skin_dark')
    t.triangle((25, -23, 60), (35, -1, 72), (41, -25, 78), 4, 'glow_core')
    parts['tail'] = t.voxels()
    limbs['tail'] = limb('tail', [0, 83, 18])
    save('vharok_cinder_tyrant', 'Vharok, the Cinder Tyrant', 'Lava', FIRE, parts, limbs,
         {'infernal': {'body': 'body_infernal'},
          'heart_unbound': {'body': 'body_unbound', 'wing_l': 'wing_l_unbound', 'wing_r': 'wing_r_unbound'}},
         hover=0, flap_rate=1.4, hand=[0, 128, -30])
    # Cinder Sentinel: a compact obsidian guardian with molten shoulder seals.
    p = part(FIRE)
    p.box((-16, 0, -12), (16, 6, 12), 'armor')
    p.ellipsoid((0, 30, 0), (18, 24, 14), 'armor')
    p.ellipsoid((0, 34, -8), (12, 16, 8), 'armor_light')
    for s in (-1, 1):
        p.ellipsoid((s * 20, 48, 0), (10, 9, 11), 'armor')
        p.ellipsoid((s * 20, 50, -2), (6, 5, 7), 'glow_seam')
        p.chain([(s * 20, 44, 0), (s * 23, 26, -4), (s * 20, 12, -6)], 6, 5, 'armor_light')
        p.box((s * 20 - 4, 6, -12), (s * 20 + 4, 14, -2), 'metal')
    p.ellipsoid((0, 60, -2), (9, 8, 9), 'armor')
    p.box((-7, 59, -12), (7, 62, -10), 'glow_hot')
    p.ellipsoid((0, 34, -15), (5, 7, 2), 'glow_core')
    for i in range(5):
        p.capsule((-12 + i * 6, 66, 0), (-14 + i * 7, 74 + (i % 2) * 4, 2), 2, .4, 'metal')
    save('cinder_sentinel', 'Cinder Sentinel', 'Lava', FIRE, {'body': chip(p.voxels(), 0.04)}, unit=.04, hover=0, hand=[0, 50, -14])


# --- Aureate Scarab Regent --------------------------------------------------------------

def scarab_body(form):
    p = part(GOLD)
    p.ellipsoid((0, 78, 14), (42, 28, 56), 'chitin')
    p.ellipsoid((0, 92, 12), (39, 22, 51), 'gold_dark')
    for s in [-1, 1]:
        if form == 'sunwings':
            # Elytra lifted and opened outward.
            p.ellipsoid((s * 34, 108, 22), (16, 10, 42), 'gold')
            p.ellipsoid((s * 36, 112, 22), (12, 6, 38), 'gold_light')
        else:
            p.ellipsoid((s * 19, 99, 16), (19, 18, 45), 'gold')
            for z in [-12, 6, 24, 42]:
                p.capsule((s * 5, 111, z), (s * 32, 102, z + 8), 2.3, 2.3, 'gold_light')
    # Chitin segments across the abdomen.
    for z in range(-10, 60, 9):
        ring(p, (0, 78, z), 40 - abs(z - 15) * 0.25, 1.4, 'carapace_light', axis='z', n=48)
    p.ellipsoid((0, 106, -34), (23, 34, 20), 'ivory')
    p.ellipsoid((0, 138, -42), (20, 27, 15), 'gold')
    for s in [-1, 1]:
        p.ellipsoid((s * 25, 129, -29), (13, 33, 17), 'carapace')
        for y in range(107, 159, 7):
            p.capsule((s * 17, y, -42), (s * 33, y - 4, -34), 2, 2, 'gold_light')
        p.box((s * 9 - 5, 141, -57), (s * 9 + 5, 145, -54), 'dark')
        p.box((s * 9 - 4, 142, -58), (s * 9 + 4, 144, -56), 'glow_eye')
        p.box((s * 9 - 1, 132, -57), (s * 9 + 1, 141, -55), 'gold_dark')  # carved kohl lines
        p.chain([(s * 15, 102, -42), (s * 29, 91, -61), (s * 18, 86, -77)], 5, 1, 'ivory')
        p.ellipsoid((s * 12, 126, -54), (2, 2, 1.5), 'jewel')
    p.capsule((0, 143, -56), (0, 129, -59), 3, 2, 'gold_light')
    p.box((-7, 123, -56), (7, 125, -54), 'gold_dark')
    p.chain([(0, 122, -53), (0, 111, -58), (0, 108, -54)], 4, 2, 'carapace')
    broken = form == 'sunheart'
    ring(p, (0, 145, -12), 36, 4, 'gold_light', axis='z', n=72 if not broken else 40)
    for i in range(12):
        if broken and i in (2, 3, 7):
            continue
        a = i * math.tau / 12
        p.capsule((math.cos(a) * 37, 145 + math.sin(a) * 37, -12), (math.cos(a) * 45, 145 + math.sin(a) * 45, -12), 3, .5, 'gold')
    p.ellipsoid((0, 161, -15), (10, 10, 5), 'glow_sun')
    if broken:
        # Cracked-open breast plates around a pink and white heart, set in
        # front of the ivory chest so it reads from the gameplay camera.
        for s in (-1, 1):
            p.chain([(s * 6, 104, -54), (s * 19, 94, -55), (s * 22, 76, -50)], 4, 2, 'gold_dark')
        p.ellipsoid((0, 90, -52), (15, 16, 7), 'pearl')
        p.ellipsoid((0, 90, -56), (11, 12, 5), 'glow_heart')
        p.ellipsoid((0, 91, -60), (5, 6, 3), 'glow_lens')
    else:
        p.ellipsoid((0, 98, -13), (9, 12, 5), 'glow_heart')
    v = p.voxels()
    return chip(v, 0.02) if broken else v


def scarab():
    parts = {'body': scarab_body('default'), 'body_sunwings': scarab_body('sunwings'), 'body_sunheart': scarab_body('sunheart')}
    limbs = {}
    for s, label in [(-1, 'l'), (1, 'r')]:
        lg = part(GOLD)
        lg.chain([(0, 0, 0), (s * 20, -9, 7), (s * 29, -39, -3)], 5, 2, 'carapace_light')
        lg.ellipsoid((s * 20, -9, 7), (5, 5, 5), 'gold_dark')  # knee joint
        lg.ellipsoid((s * 2, 0, 0), (6, 6, 6), 'gold')  # hip joint
        lg.capsule((s * 29, -39, -3), (s * 31, -43, -11), 3, .5, 'gold_light')
        lg.capsule((s * 29, -39, -3), (s * 33, -42, 4), 2, .4, 'gold_light')  # rear spur
        parts['leg_' + label] = lg.voxels()
        for i, z in enumerate([-22, 8, 37]):
            limbs[f'leg_{label}_{i}'] = limb('leg_' + label, [s * 37, 53, z], 'leg', phase=s * (-1 if i % 2 else 1), axis='y', amount=.4)
        for form in ('', '_sunwings', '_sunheart'):
            w = part(GOLD)
            spread = 1.35 if form == '_sunwings' else 1.0
            for i in range(5):
                a = (0, 0, i * 8 - 7)
                b = (s * (45 + i * 3) * spread, 7 - i * 4 + (8 if form == '_sunwings' else 0), 18 + i * 9)
                c = (s * (37 + i * 3) * spread, -3 - i * 4, 30 + i * 9)
                if form == '_sunheart' and i >= 3:
                    b = (b[0] * 0.75, b[1], b[2] * 0.85)  # damaged tips
                w.triangle(a, b, c, 3.5, 'gold' if i % 2 else 'ivory')
                w.capsule(a, b, 1.3, .6, 'gold_light')  # gold edging
            w.ellipsoid((s * 24, 0, 15), (5, 4, 8), 'glow_heart')
            if form == '_sunwings':
                for lx, lz in ((40, 16), (54, 44)):  # two solar lenses per wing
                    w.ellipsoid((s * lx, 10, lz), (6, 6, 6), 'gold_dark')
                    w.ellipsoid((s * lx, 10, lz - 2), (4, 4, 3), 'glow_lens')
            parts['wing_' + label + form] = w.voxels()
        limbs['wing_' + label] = limb('wing_' + label, [s * 35, 102, 2], 'wing', phase=-s)
    save('aureate_scarab_regent', 'Aureate Scarab Regent', 'Desert', GOLD, parts, limbs,
         {'sunwings': {'body': 'body_sunwings', 'wing_l': 'wing_l_sunwings', 'wing_r': 'wing_r_sunwings'},
          'sunheart': {'body': 'body_sunheart', 'wing_l': 'wing_l_sunheart', 'wing_r': 'wing_r_sunheart'}},
         hover=.15, flap_rate=1.0, hand=[0, 139, -59], unit=.044)
    # Dawn Scarab: a small ivory and gold beetle with pink eye dots.
    p = part(GOLD)
    p.ellipsoid((0, 14, 2), (11, 8, 15), 'ivory')
    p.ellipsoid((0, 18, 3), (10, 6, 13), 'gold')
    p.box((-0.5, 16, -10), (0.5, 25, 16), 'gold_dark')
    p.ellipsoid((0, 14, -14), (7, 6, 6), 'ivory_dark')
    for s in (-1, 1):
        p.ellipsoid((s * 3, 16, -19), (1.5, 1.5, 1), 'glow_heart')
        p.chain([(s * 2, 17, -18), (s * 6, 24, -24)], 1, .4, 'gold_light')
    body = p.voxels()
    lg = part(GOLD)
    lg.chain([(0, 0, 0), (6, -3, 2), (9, -11, -1)], 1.6, .8, 'gold_dark')
    lr = part(GOLD)
    lr.chain([(0, 0, 0), (-6, -3, 2), (-9, -11, -1)], 1.6, .8, 'gold_dark')
    limbs = {}
    for i, z in enumerate((-8, 2, 12)):
        limbs[f'leg_l_{i}'] = limb('leg_r', [9, 12, z], 'leg', phase=1 if i % 2 else -1, axis='y', amount=.5)
        limbs[f'leg_r_{i}'] = limb('leg_l', [-9, 12, z], 'leg', phase=-1 if i % 2 else 1, axis='y', amount=.5)
    save('dawn_scarab', 'Dawn Scarab', 'Desert', GOLD, {'body': body, 'leg_l': lr.voxels(), 'leg_r': lg.voxels()}, limbs,
         unit=.035, hover=0, hand=[0, 15, -20])


# --- The Hollow Crown -------------------------------------------------------------------

def wraith_body(form):
    p = part(VOID)
    torn = form != 'default'
    for s in [-1, 1]:
        # Layered robes with gaps; the right side hangs longer (asymmetry).
        p.chain([(s * 21, 127, 0), (s * 32, 91, 10), (s * 43, 46, 17), (s * 31, 9 - (6 if s > 0 else 0), 25)], 18, 3, 'cloth')
        p.chain([(s * 20, 121, -12), (s * 31, 78, -6), (s * 45, 32, 10)], 3, 1, 'edge')
        for i in range(4):
            if torn and i == 1:
                continue
            p.chain([(s * (12 + i * 10), 65, 12), (s * (18 + i * 9), 29 - i * 3, 21), (s * (8 + i * 12), 4 + i * 3, 30)], 5, .3, 'cloth_light' if i % 2 else 'cloth_dark')
    p.ellipsoid((0, 142, 0), (29, 34, 24), 'cloth_dark')
    p.ellipsoid((0, 147, -17), (25, 28, 10), 'armor')
    # A genuinely hollow hood: the opening is carved empty below.
    eye = 2 if form == 'default' else 3
    p.ellipsoid((0, 148, -32), (10 + eye, 5 + eye * 0.5, 2), 'glow_core')
    p.ellipsoid((0, 148, -34), (2, 5, 1), 'glow_eye')
    core = 13 if form != 'unbound' else 18
    p.ellipsoid((0, 99, -13), (core, 18, 8), 'armor')
    p.ellipsoid((0, 99, -21), (8 + (6 if form == 'unbound' else 0), 12 + (5 if form == 'unbound' else 0), 3), 'glow_core')
    crown_y = 184 if form == 'default' else 190
    for i in range(8):
        a = i * math.tau / 8
        if form == 'fractured_court' and i in (1, 5):
            continue  # split crown
        lift = (6 if form == 'fractured_court' and i % 2 else 0)
        x, z = math.cos(a) * 31, math.sin(a) * 31
        if form != 'unbound':
            p.capsule((math.cos(a) * 31, crown_y + lift, math.sin(a) * 31), (math.cos(a + 0.78) * 31, crown_y, math.sin(a + 0.78) * 31), 3, 3, 'silver')
            p.chain([(x, crown_y + lift, z), (x * 1.1, crown_y + 19 + lift + (i % 2) * 7, z * 1.1), (x * .85, crown_y + 34 + lift + (i % 2) * 5, z * .85)], 4, .4, 'gold' if i % 2 else 'edge')
            p.ellipsoid((x * 1.05, crown_y + 16 + lift, z * 1.05), (2, 3, 2), 'glow_rune')
    for s in [-1, 1]:
        p.ellipsoid((s * 40, 124, 0), (17, 13, 19), 'armor')
        for j in range(3):
            p.capsule((s * (32 + j * 7), 131, 0), (s * (39 + j * 9), 146 - j * 3, 3), 4, .3, 'silver')
        for x, y, z in [(s * 31, 63, 6), (s * 37, 42, 14), (s * 20, 85, -9)]:
            p.ellipsoid((x, y, z), (1.5, 2, 1.5), 'glow_eye')
    v = p.voxels()
    # Carve the hood opening hollow so the eye floats in real darkness.
    v = {k: c for k, c in v.items() if not (c in ('cloth_dark', 'armor') and k[2] < -14 and (k[0] ** 2) / 300 + ((k[1] - 148) ** 2) / 420 < 1)}
    if torn:
        v = recolor(v, lambda k, c: 'glow_dim' if c == 'cloth' and abs(k[0]) < 30 and (k[1] + abs(k[0]) * 2) % 31 == 0 else c)
    return v


def wraith():
    parts = {'body': wraith_body('default'), 'body_fractured': wraith_body('fractured_court'), 'body_unbound': wraith_body('unbound')}
    limbs = {}
    for s, label in [(-1, 'l'), (1, 'r')]:
        a = part(VOID)
        a.chain([(0, 0, 0), (s * 17, -23, -2), (s * 29, -33, -17)], 10, 6, 'cloth_light')
        a.ellipsoid((s * 28, -33, -17), (8, 7, 7), 'bone_dark')
        for j in range(4):  # long bony fingers with knuckles
            a.chain([(s * (20 + j * 4), -32, -20), (s * (24 + j * 5), -36, -33), (s * (21 + j * 5), -44, -38), (s * (18 + j * 5), -48, -36)], 2.0, .3, 'bone')
            a.ellipsoid((s * (24 + j * 5), -36, -33), (2.2, 2.2, 2.2), 'bone_dark')
        a.ellipsoid((s * 26, -40, -30), (4, 4, 4), 'glow_rune')
        for j in range(3):
            a.chain([(s * (4 + j * 4), -17, 5), (s * (13 + j * 5), -43 - j * 4, 8), (s * (7 + j * 8), -58 - j * 6, 13)], 3, .3, 'cloth_dark')
        parts['arm_' + label] = a.voxels()
        limbs['arm_' + label] = limb('arm_' + label, [s * 38, 118, 0], 'arm', phase=-s, throws=False)
    for form in ('', '_fractured', '_unbound'):
        h = part(VOID)
        push = {'': 71, '_fractured': 80, '_unbound': 90}[form]
        for i in range(9):
            a = (i * 32 + 10 + (9 if form and i % 2 else 0)) * math.pi / 180
            x, y = math.cos(a) * push, 121 + math.sin(a) * push
            h.box((x - 6, y - 11, 15), (x + 6, y + 11, 23), 'tablet')
            h.box((x - 5, y - 10, 14), (x + 5, y + 10, 15), 'armor')
            for k in range(3):  # etched runes
                h.box((x - 3 + k * 2, y - 6 + k * 4, 13), (x - 2 + k * 2, y - 2 + k * 4, 14), 'glow_rune')
        if form == '_unbound':
            # Detached crown sections orbit as part of the halo assembly.
            for i in range(6):
                a = i * math.tau / 6
                h.chain([(math.cos(a) * 46, 196 + (i % 2) * 8, math.sin(a) * 46), (math.cos(a) * 50, 214, math.sin(a) * 50)], 4, .5, 'gold' if i % 2 else 'silver')
                h.ellipsoid((math.cos(a) * 47, 204, math.sin(a) * 47), (2, 3, 2), 'glow_cyan')
        parts['halo' + form] = h.voxels()
    limbs['halo'] = limb('halo', [0, 0, 0], role='')
    save('hollow_crown', 'The Hollow Crown', 'Dark', VOID, parts, limbs,
         {'fractured_court': {'body': 'body_fractured', 'halo': 'halo_fractured'},
          'unbound': {'body': 'body_unbound', 'halo': 'halo_unbound'}},
         hover=.55, hand=[0, 99, -24])
    # Mirror Shade: a smaller, incomplete spirit with a broken half-crown.
    p = part(VOID)
    for s in (-1, 1):
        p.chain([(s * 12, 70, 0), (s * 20, 40, 6), (s * 15, 6, 12)], 9, 2, 'shade')
    p.ellipsoid((0, 78, 0), (16, 19, 13), 'cloth_dark')
    p.ellipsoid((0, 80, -10), (12, 14, 5), 'dark')
    p.ellipsoid((0, 81, -15), (5, 2.5, 1.5), 'glow_dim')
    p.ellipsoid((0, 54, -8), (5, 7, 3), 'glow_dim')
    for i in range(4):  # half a crown
        a = math.pi + i * math.pi / 4
        p.chain([(math.cos(a) * 15, 100, math.sin(a) * 15), (math.cos(a) * 16, 112 + (i % 2) * 5, math.sin(a) * 16)], 2.5, .3, 'silver')
    save('mirror_shade', 'Mirror Shade', 'Dark', VOID, {'body': chip(p.voxels(), 0.12)}, unit=.04, hover=.4, hand=[0, 60, -14])


def main():
    blue_egg(); frost_geode(); vharok_cocoon(); scarab_reliquary(); crown_reliquary()
    frost(); demon(); scarab(); wraith()
    import json
    (ROOT / 'creatures/realm_boss_manifest.json').write_text(json.dumps(art.MODELS, indent=2) + '\n')
    print('Saved', len(art.MODELS), 'live boss models.')


if __name__ == '__main__':
    main()
