#!/usr/bin/env python3
"""Create-only Surface dungeon shots, facing -Z. Run from the repository root.

Uses the shared coarse pixel geometry and exposed-face x8 VOX writer. Each shot
has its own palette. Existing models and manifest records are never replaced.
"""
import json
import math
import sys
from pathlib import Path

sys.dont_write_bytecode = True
import redesign_pixel_bosses as a

R = Path(__file__).resolve().parents[1]
MANIFEST = R / 'creatures/boss_projectiles/manifest.json'


def pal(base, light, shade, dark, glow_eye, glow_core, bone):
    return dict(base=base, light=light, shade=shade, dark=dark, belly=light,
                bone=bone, wing=base, accent=light, glow_eye=glow_eye,
                glow_core=glow_core)


# Independent entries keep future recolors local to a single attack.
PALETTES = {
    'mycelium_seed': pal((31,140,128), (102,219,186), (21,78,79), (12,35,43), (196,255,225), (59,239,197), (234,225,187)),
    'cannonball': pal((39,45,55), (93,108,117), (23,28,37), (12,16,23), (255,242,156), (255,143,46), (172,136,83)),
    'ghost_lantern': pal((140,98,48), (217,172,81), (73,57,40), (29,35,37), (204,255,226), (47,226,184), (111,153,137)),
    'brine_hook': pal((142,72,43), (208,132,72), (79,48,38), (30,33,35), (176,230,197), (76,163,136), (135,160,139)),
    'jade_fang': pal((38,145,91), (125,220,150), (21,83,61), (12,39,36), (210,255,190), (82,238,122), (218,184,69)),
    'gold_plume': pal((192,135,35), (255,222,109), (110,72,30), (23,55,37), (232,255,173), (85,224,113), (44,149,82)),
    'sun_glyph': pal((194,139,42), (250,213,99), (116,76,25), (45,55,29), (205,255,154), (86,236,103), (47,119,60)),
    'soul_wisp': pal((35,150,184), (136,238,241), (28,78,121), (15,34,64), (225,255,255), (67,221,238), (38,101,152)),
    'moth_scale': pal((192,120,173), (243,199,226), (115,69,122), (43,31,69), (255,234,252), (238,134,231), (230,193,133)),
    'lantern_flame': pal((127,107,77), (221,196,134), (72,66,63), (32,37,48), (255,250,211), (250,207,110), (196,172,121)),
    'ice_axe': pal((78,155,195), (186,239,247), (40,83,127), (22,40,64), (236,255,255), (103,217,250), (111,140,154)),
    'frost_rune': pal((58,85,124), (126,164,195), (32,51,85), (17,29,52), (211,253,255), (71,185,255), (77,114,153)),
    'crow_feather': pal((39,47,65), (80,95,115), (23,30,48), (12,19,33), (227,255,255), (121,210,237), (157,199,220)),
    'glass_shard': pal((150,197,210), (229,250,249), (83,128,153), (33,60,90), (255,255,255), (167,238,250), (191,213,231)),
    'lens_disc': pal((153,207,218), (231,251,247), (73,129,151), (59,67,72), (255,255,240), (167,237,244), (232,182,77)),
    'prism_ray': pal((132,192,217), (227,249,255), (72,107,153), (28,42,75), (255,255,255), (183,237,255), (217,220,238)),
    'wax_tear': pal((214,206,201), (255,244,220), (155,139,160), (65,43,86), (250,222,255), (175,105,235), (230,217,212)),
    'glass_pane': pal((156,57,104), (237,133,166), (89,45,117), (39,39,55), (255,203,227), (181,105,236), (112,117,135)),
    'candle_flame': pal((224,209,173), (255,244,209), (154,131,119), (66,47,63), (255,253,200), (255,173,68), (103,72,81)),
    'kintsugi_star': pal((32,33,48), (74,72,91), (19,22,35), (10,13,23), (255,238,162), (229,177,69), (151,109,45)),
    'void_shard': pal((31,29,53), (70,64,105), (19,21,39), (9,12,23), (239,246,255), (148,175,248), (206,170,92)),
    'gold_seam': pal((204,145,43), (255,220,109), (123,79,29), (49,36,33), (255,251,207), (255,191,58), (234,187,81)),
    'fallen_star': pal((224,192,113), (255,248,211), (145,110,57), (55,46,48), (255,255,247), (255,220,135), (187,155,89)),
}

for name, palette in PALETTES.items():
    a.PAL['surface_' + name] = palette
for name in ('glass_shard', 'prism_ray'):
    PALETTES[name].update(glow_rose=(255,133,172), glow_gold=(255,218,113),
                          glow_green=(120,241,170), glow_blue=(104,189,255),
                          glow_violet=(198,147,255))


def plate(v, points, bottom, top, color):
    """An XZ polygon with thickness in Y, readable from the game camera."""
    flat = {}
    a.polygon(flat, points, bottom, top, color)
    v.update({(x, y, z): c for (x, z, y), c in flat.items()})


def path(v, points, color, width=1):
    for p, q in zip(points, points[1:]):
        a.line(v, p, q, color, width)


def ring(v, radius, y, color, inner=None):
    inner = radius - 1.2 if inner is None else inner
    for x in range(-math.ceil(radius), math.ceil(radius)):
        for z in range(-math.ceil(radius), math.ceil(radius)):
            if inner ** 2 <= (x + .5) ** 2 + (z + .5) ** 2 <= radius ** 2:
                v[x, y, z] = color


def mycelium_seed():
    v = {}
    a.ell(v, (0, 0, -2), (3, 2.5, 4), 'shade')
    a.ell(v, (0, 1, -2.5), (2.4, 2, 3.4), 'glow_core')
    a.line(v, (-1, 2, -5), (-1, 2, -2), 'glow_eye')
    for points in [[(-2,0,0),(-4,0,3),(-3,1,6),(-5,1,9)],
                   [(0,0,1),(0,1,5),(2,1,8),(1,2,11)],
                   [(2,0,0),(4,0,3),(3,1,6),(5,1,8)]]:
        path(v, points, 'bone')
    v[-4,0,5] = 'light'
    return v


def cannonball():
    v = {}
    a.ell(v, (0, 0, -1), (4, 4, 4), 'base')
    a.ell(v, (0, -1, 0), (3.7, 3, 3), 'shade')
    a.ell(v, (-1.6, 2.4, -2.5), (1.6, 1.1, 1.4), 'light')
    a.box(v, (-1, 2, 1), (1, 4, 3), 'dark')
    path(v, [(0,3,2),(0,4,4),(2,4,5),(2,5,7)], 'bone')
    for p,q in [((2,5,7),(4,5,8)),((2,5,7),(1,6,9)),((2,5,7),(0,5,6))]:
        a.line(v, p, q, 'glow_core')
    v[2,5,7] = 'glow_eye'
    return v


def cage(v, color, flame, soft=False):
    # Open roof and four corner uprights leave the flame visible from above.
    for y in (-3, 3):
        ring(v, 3.7, y, color, 2.3)
    for x in (-3, 2):
        for z in (-3, 2):
            a.line(v, (x,-3,z), (x,3,z), color)
    a.ell(v, (0, 0, 0), (1.8, 2.6, 1.8), flame)
    path(v, [(0,1,0),(-1,3,0),(0,5,0)], 'glow_eye' if soft else flame)
    a.ell(v, (0, 0, -1), (1, 1.5, 1), 'glow_eye')


def ghost_lantern():
    v = {}
    cage(v, 'shade', 'glow_core')
    a.box(v, (-3,-4,-3), (3,-3,3), 'shade')
    # A peaked ship-lantern hood with an open center, plus a carrying loop.
    for side in (-1, 1):
        a.line(v, (side*3,3,-2), (side,5,-1), 'light')
        a.line(v, (side*3,3,2), (side,5,1), 'light')
    # Ghost fire escapes through the hood and stays visible at steep angles.
    a.ell(v, (0,5,-1), (1.8,2,1.6), 'glow_core')
    path(v, [(0,6,-1),(-1,7,-1),(0,8,0)], 'glow_eye')
    path(v, [(-1,5,1),(-1,7,2),(1,7,2),(1,5,1)], 'base')
    return v


def brine_hook():
    v = {}
    # The long shank faces -Z; three swept talons create a grappling silhouette.
    a.line(v, (0,0,-6), (0,0,3), 'shade', 2)
    a.line(v, (0,2,-5), (0,2,3), 'light')
    eye = {}
    ring(eye, 1.8, 0, 'base', .8)
    v.update({(x,y,z+6):c for (x,y,z),c in eye.items()})
    for side in (-1, 1):
        path(v, [(0,0,2),(side*4,0,4),(side*6,0,2),(side*6,0,-2),(side*4,0,-4)], 'base', 2)
        path(v, [(side*4,2,4),(side*6,2,2),(side*6,2,-2),(side*4,2,-4)], 'light')
        v[side*4,2,-4] = 'bone'
    path(v, [(0,0,3),(0,3,5),(0,5,2),(0,4,0)], 'shade')
    v[-5,2,1] = 'bone'
    return v


def jade_fang():
    v = {}
    plate(v, [(-3,5),(-4,1),(-3,-3),(0,-7),(4,-9),(2,-5),(0,-2),(0,2),(2,4)], -1, 2, 'base')
    plate(v, [(-3,3),(-3,-1),(-1,-4),(3,-8),(0,-3),(-1,1),(0,3)], 2, 3, 'light')
    a.line(v, (-2,3,2), (-2,3,-2), 'glow_core')
    a.line(v, (-3,0,4), (1,0,4), 'bone', 2)
    v[3,1,-8] = 'glow_eye'
    return v


def feather(frost=False):
    v = {}
    plate(v, [(0,-8),(-3,-5),(-4,-1),(-3,3),(-1,5),(0,8),(2,3),(4,0),(3,-4)], 0, 1, 'base')
    for side in (-1,1):
        for z in (-4,-1,2):
            x = side * (3 if z < 2 else 2)
            a.line(v, (0,1,z+1), (x,1,z-1), 'light' if frost else 'bone')
            if frost:
                v[x,1,z-1] = 'glow_core'
                v[x,1,z] = 'bone'
    a.line(v, (0,2,-7), (0,2,8), 'bone' if frost else 'light')
    if frost:
        for p in [(-1,1,-7),(-3,1,-4),(3,1,-3),(3,1,0),(-3,1,2)]:
            v[p] = 'glow_eye'
    else:
        a.line(v, (1,1,-5), (1,1,0), 'glow_core')
    return v


def gold_plume():
    return feather()


def sun_glyph():
    v = {}
    a.ell(v, (0,0,0), (5.5,1.5,5.5), 'shade')
    a.ell(v, (0,1,0), (4.8,1,4.8), 'base')
    ring(v, 5.5, 1, 'light', 4.3)
    # Dark recess below a stepped green serpent/sun glyph.
    path(v, [(-2,2,-3),(1,2,-3),(1,2,-1),(-1,2,-1),(-1,2,2),(2,2,2)], 'dark')
    path(v, [(-2,2,-2),(0,2,-2),(0,2,0),(-2,2,0),(-2,2,3),(2,2,3)], 'glow_core')
    v[2,2,-2] = 'glow_eye'
    for x,z in [(0,-6),(-6,0),(5,0),(0,5)]:
        v[x,0,z] = 'bone'
    return v


def soul_wisp():
    v = {}
    a.ell(v, (0,0,-3), (3.5,2.5,3.5), 'base')
    a.ell(v, (0,1,-3.5), (3,2,3), 'glow_core')
    for i in range(10):
        a.ell(v, (round(1.5*math.sin(i*.45)),i/8, i),
              (max(.7,2.2-i*.18),max(.6,1.5-i*.09),1.4), 'glow_core' if i<5 else 'light')
    for x in (-2, 1):
        v[x,2,-5] = 'dark'
        v[x,1,-6] = 'dark'
    v[0,2,-4] = 'glow_eye'
    return v


def moth_scale():
    v = {}
    plate(v, [(0,-7),(-4,-4),(-5,0),(-3,4),(0,6),(3,4),(5,0),(4,-4)], -1, 1, 'shade')
    plate(v, [(0,-6),(-3,-3),(-4,0),(-2,3),(0,5),(2,3),(4,0),(3,-3)], 1, 2, 'light')
    for side in (-1,1):
        a.line(v, (0,2,-4), (side*3,2,1), 'base')
        a.line(v, (0,2,0), (side*2,2,4), 'base')
    # Concentric eye spot on the broad upper surface.
    a.ell(v, (0,2,0), (2.8,1,2.8), 'glow_core')
    a.ell(v, (0,3,0), (1.8,.6,1.8), 'dark')
    v[-1,3,-1] = 'glow_eye'
    a.line(v, (0,0,5), (0,0,7), 'bone')
    return v


def lantern_flame():
    v = {}
    cage(v, 'bone', 'glow_core', soft=True)
    a.box(v, (-2,-4,-2), (2,-3,2), 'shade')
    for x in (-3,2):
        a.line(v, (x,3,-2), (x,4,1), 'light')
    a.ell(v, (0,4,0), (1.5,2,1.5), 'glow_core')
    a.line(v, (0,5,0), (0,6,-1), 'glow_eye')
    return v


def ice_axe():
    v = {}
    plate(v, [(-6,-5),(-5,-2),(-2,-1),(-1,-3),(1,-3),(2,-1),(5,-2),(6,-5),
              (7,-1),(6,3),(3,4),(1,2),(-1,2),(-3,4),(-6,3),(-7,-1)], -1, 1, 'base')
    for side in (-1,1):
        path(v, [(side*6,1,-4),(side*7,1,-1),(side*6,1,2),(side*3,1,3)], 'light')
        a.line(v, (side*2,1,0), (side*5,1,1), 'glow_core')
    a.line(v, (0,-1,-2), (0,-1,6), 'shade', 2)
    a.line(v, (0,1,-2), (0,1,5), 'bone')
    v[0,2,0] = 'glow_eye'
    return v


def frost_rune():
    v = {}
    plate(v, [(-3,-5),(1,-6),(4,-3),(4,3),(2,5),(-3,4),(-4,0)], -2, 1, 'shade')
    plate(v, [(-2,-5),(1,-5),(3,-3),(3,3),(1,4),(-3,3),(-3,-1)], 1, 2, 'base')
    a.line(v, (-3,2,-2), (-2,2,-4), 'light')
    a.line(v, (0,2,-4), (0,2,3), 'glow_eye')
    path(v, [(0,2,-3),(2,2,-1),(0,2,1),(-2,2,-1)], 'glow_core')
    a.line(v, (0,2,1), (2,2,3), 'glow_core')
    return v


def crow_feather():
    return feather(frost=True)


def glass_shard():
    v = {}
    plate(v, [(1,-9),(-4,-2),(-3,4),(0,6),(4,1)], -1, 1, 'shade')
    plate(v, [(1,-9),(-3,-2),(0,3),(4,1)], 1, 2, 'light')
    plate(v, [(-3,-2),(-2,3),(0,5),(0,0)], 1, 2, 'base')
    a.line(v, (1,2,-8), (0,2,2), 'glow_eye')
    colors = ['glow_rose','glow_gold','glow_green','glow_blue','glow_violet']
    for i,color in enumerate(colors):
        a.line(v, (3-i//2,1,-2+i*2), (3-(i+1)//2,1,-1+i*2), color)
    return v


def lens_disc():
    v = {}
    a.ell(v, (0,0,0), (5,1.5,5), 'shade')
    a.ell(v, (0,1,0), (4.2,1.7,4.2), 'base')
    a.ell(v, (-.7,2,-.8), (2.7,.8,2.7), 'light')
    ring(v, 5.6, 0, 'bone', 4.3)
    ring(v, 5.6, 1, 'bone', 4.6)
    path(v, [(-3,2,-1),(-3,2,-2),(-1,2,-3),(0,2,-3)], 'glow_eye')
    a.line(v, (2,2,1), (1,2,3), 'glow_core')
    return v


def prism_ray():
    v = {}
    colors = ['glow_violet','glow_blue','glow_green','glow_gold','glow_rose']
    for z in range(-12,11):
        width = 0 if z < -8 or z > 8 else 1
        for x in range(-width,width+1):
            for y in range(-1,1):
                v[x,y,z] = 'base' if y<0 else colors[min(4,(z+12)//5)]
    a.line(v, (0,1,-12), (0,1,10), 'glow_eye')
    for z,color in zip((-6,-2,2,6), colors[1:]):
        a.line(v, (-2,0,z), (2,0,z), color)
    return v


def wax_tear():
    v = {}
    a.ell(v, (0,0,-2), (3,2.5,3.5), 'base')
    a.ell(v, (-.5,1,-2.5), (2.3,2,2.7), 'light')
    a.ell(v, (0,0,1), (2,1.8,2.6), 'base')
    path(v, [(0,1,2),(0,1,4),(1,2,6)], 'light')
    for side in (-1,1):
        a.line(v, (side*3,0,-3), (side*3,0,0), 'glow_core')
    v[-1,2,-4] = 'glow_eye'
    return v


def glass_pane():
    v = {}
    plate(v, [(0,-7),(-5,0),(0,7),(5,0)], -1, 1, 'dark')
    plate(v, [(0,-5),(-3,0),(0,5),(3,0)], 1, 2, 'base')
    plate(v, [(0,-5),(0,0),(3,0)], 1, 2, 'glow_core')
    plate(v, [(-3,0),(0,0),(0,5)], 1, 2, 'glow_core')
    path(v, [(0,0,-6),(-4,0,0),(0,0,6),(4,0,0),(0,0,-6)], 'bone')
    a.line(v, (0,2,-5), (0,2,5), 'dark')
    a.line(v, (-3,2,0), (3,2,0), 'dark')
    v[-1,2,-2] = 'glow_eye'
    v[1,2,2] = 'light'
    return v


def candle_flame():
    v = {}
    a.ell(v, (0,-1,1), (2.5,3,2.5), 'base')
    a.ell(v, (0,2,1), (2.5,1,2.5), 'light')
    a.line(v, (-2,2,0), (-2,-1,0), 'light')
    a.line(v, (1,2,3), (1,0,3), 'light')
    a.line(v, (0,2,0), (0,4,0), 'dark')
    a.ell(v, (0,5,-1), (2,3,2), 'glow_core')
    a.ell(v, (0,4,-2), (1,2,1), 'glow_eye')
    path(v, [(0,6,-1),(1,8,0),(0,10,1)], 'glow_core')
    a.line(v, (0,5,-1), (0,8,0), 'glow_eye')
    return v


def star(v, radius, inner, bottom, top, color):
    points = []
    for i in range(10):
        angle = -math.pi/2+i*math.pi/5
        r = radius if i%2 == 0 else inner
        points.append((round(math.cos(angle)*r),round(math.sin(angle)*r)))
    plate(v, points, bottom, top, color)


def kintsugi_star():
    v = {}
    star(v, 8, 3.8, -1, 1, 'shade')
    star(v, 8, 3.8, 1, 2, 'base')
    for x,y,z in list(v):
        if y == 1 and ((x-1,y,z) not in v or (x,y,z-1) not in v):
            v[x,y,z] = 'light'
    footprint = {(x,z) for x,y,z in v}
    path(v, [(0,2,-6),(0,2,-3),(-1,2,-2),(0,2,0),(3,2,1),(4,2,4)], 'glow_core')
    path(v, [(-6,2,-2),(-3,2,-1),(-2,2,1),(-4,2,4)], 'bone')
    path(v, [(0,2,0),(2,2,-1),(5,2,-2)], 'glow_eye')
    return {p:c for p,c in v.items() if (p[0],p[2]) in footprint}


def void_shard():
    v = {}
    plate(v, [(1,-9),(-4,0),(-2,5),(1,7),(4,0)], -1, 2, 'shade')
    plate(v, [(1,-8),(-3,0),(0,5),(2,0)], 2, 3, 'base')
    plate(v, [(0,-5),(-2,0),(0,4),(2,1)], 3, 4, 'dark')
    for p in [(0,4,-3),(-1,4,0),(1,4,1),(0,4,3)]:
        v[p] = 'glow_eye'
    a.line(v, (0,4,0), (1,4,0), 'glow_core')
    v[0,4,1] = 'glow_core'
    a.line(v, (2,3,-4), (3,3,-1), 'light')
    return v


def gold_seam():
    v = {}
    plate(v, [(2,-10),(-3,-3),(0,-3),(-3,2),(0,2),(-2,10),
              (4,1),(1,1),(4,-5),(1,-5)], -1, 1, 'base')
    path(v, [(2,1,-9),(-1,1,-3),(2,1,-3),(-1,1,2),(2,1,2),(-2,1,10)], 'glow_eye')
    path(v, [(-1,0,0),(-5,0,2),(-6,0,5)], 'glow_core')
    path(v, [(2,0,1),(6,0,3),(5,0,5)], 'glow_core')
    return v


def fallen_star():
    v = {}
    for x,length in [(-3,10),(0,15),(3,12)]:
        path(v, [(x,-1,3),(x+1,-1,7),(x-1,0,length)], 'base')
        a.line(v, (x,0,5), (x-1,0,length-1), 'glow_core')
    star(v, 7.5, 3.5, -1, 1, 'base')
    star(v, 7.5, 3.5, 1, 2, 'light')
    a.ell(v, (0,2,-1), (2,1,2), 'glow_eye')
    for p in [(-5,0,8),(4,0,13)]:
        v[p] = 'glow_eye'
    return v


SHOTS = [
    ('mycelium_seed', .011),
    ('cannonball', .012), ('ghost_lantern', .012), ('brine_hook', .010),
    ('jade_fang', .011), ('gold_plume', .010), ('sun_glyph', .011),
    ('soul_wisp', .011), ('moth_scale', .010), ('lantern_flame', .011),
    ('ice_axe', .011), ('frost_rune', .011), ('crow_feather', .010),
    ('glass_shard', .010), ('lens_disc', .011), ('prism_ray', .009),
    ('wax_tear', .011), ('glass_pane', .011), ('candle_flame', .011),
    ('kintsugi_star', .012), ('void_shard', .011), ('gold_seam', .010),
    ('fallen_star', .014),
]


def main():
    manifest = json.loads(MANIFEST.read_text())
    ids = {p['id'] for p in manifest}
    existing = [name for name, _ in SHOTS
                if name in ids or (R / 'creatures/boss_projectiles' / name).exists()]
    if existing:
        raise SystemExit('Create-only generator refuses existing outputs: ' + ', '.join(existing))
    # Validate every coarse model before writing any output.
    models = [(name, unit, globals()[name]()) for name, unit in SHOTS]
    for name, unit, v in models:
        assert v and all(c in PALETTES[name] for c in v.values()), name
        lo, size = a.bounds(v)
        assert all(s <= 32 for s in size), (name, size)
        assert all(-16 <= q < 16 for p in v for q in p), name
    for name, unit, v in models:
        a.projectile(name, 'surface_' + name, v, unit)
    names = {name for name, _ in SHOTS}
    manifest += [p for p in a.PROJECTILES if p['id'] in names]
    MANIFEST.write_text(json.dumps(manifest, indent=2) + '\n')
    print('Wrote', ', '.join(name for name, _ in SHOTS))


if __name__ == '__main__':
    main()
