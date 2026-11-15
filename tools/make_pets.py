#!/usr/bin/env python3
"""Build the Pet Yard art contract without touching gameplay code.

    python3 tools/make_pets.py
    python3 tools/make_pets.py --validate
    python3 tools/make_pets.py --previews /tmp/voe_pet_art

Facing -Z, Y up. All creature heights match docs/PETS.md at rest. Gait motion
and flight altitude belong to PetFollower; these rigs add articulated limbs.
Props use VillageHouse's body.vox, body_glow.vox and rig.json convention.
Previews are optional and restricted to scratch directories outside the project.
"""
import argparse
import json
import math
import struct
import sys
from pathlib import Path

sys.dont_write_bytecode = True
from PIL import Image, ImageDraw, ImageFont
from make_creatures import fit_frame, write_vox
from voxel_sculpt import Part

ROOT = Path(__file__).resolve().parents[1]
SPECIES = {
    'duck': (.55, 'waddle'), 'puffbun': (.5, 'hop'), 'gloop': (.45, 'squash'),
    'ember_kit': (.6, 'trot'), 'cinderling': (.7, 'flap'), 'hoot': (.5, 'glide'),
    'lilyhop': (.45, 'leap'), 'mossback': (.45, 'plod'), 'wisp': (.6, 'float'),
    'shardling': (.75, 'stomp'), 'moonpaw': (.5, 'trot'), 'axie': (.4, 'wiggle'),
    'capling': (.5, 'hop'), 'nebula_jelly': (.8, 'pulse'), 'skywhale': (.7, 'swim'),
}
COMMON = {
    'dark': (28, 31, 48), 'white': (255, 246, 222), 'pink': (244, 147, 164),
    'gold': (247, 188, 69), 'orange': (238, 129, 47), 'brown': (119, 77, 57),
    'glow_amber': (255, 204, 92), 'glow_hot': (255, 119, 55),
    'glow_blue': (120, 232, 255), 'glow_star': (237, 226, 255),
}


def palette(base, light, shade, **extra):
    return dict(COMMON, base=base, light=light, shade=shade, **extra)


def part(pal):
    return Part(1, pal)


def joint(name, pivot, role='leg', phase=1, **extra):
    return dict(part=name, pivot=list(pivot), role=role, phase=phase,
                amount=.55, throws=False, **extra)


def eyes(p, y, z, spacing=3, radius=1.5, iris='dark'):
    # Tall, proud eyes extend above the muzzle for an overhead camera.
    for s in (-1, 1):
        x = s * spacing
        p.ellipsoid((x, y, z), (radius + .55, radius + .65, .85), 'white')
        p.ellipsoid((x, y, z - .75), (radius, radius + .2, .65), iris)
        p.box((x - .6, y + .25, z - 1.4), (x + .15, y + 1, z - .8), 'white')


def smile(p, y, z, width=1.5):
    p.box((-width, y, z), (width, y + .65, z + .65), 'dark')


def feet(pal, limbs, parts, positions, color='base', length=3, wide=1.5):
    f = part(pal)
    f.capsule((0, 0, 0), (0, -length + 1, -.25), wide, wide * .85, color)
    f.ellipsoid((0, -length + .5, -1), (wide * 1.3, .85, 2), color)
    parts['foot'] = f
    for name, pivot, phase in positions:
        limbs[name] = joint('foot', pivot, phase=phase)


def four_feet(pal, limbs, parts, x=3, front=-3, back=3, y=3, color='base'):
    feet(pal, limbs, parts,
         [(f'leg_{end}_{side}', (s*x, y, z), s*phase)
          for end, z, phase in [('front', front, 1), ('back', back, -1)]
          for side, s in [('l', -1), ('r', 1)]], color, length=y)


def wings(pal, limbs, parts, pivot, style='feather'):
    for side, s in [('l', -1), ('r', 1)]:
        w = part(pal)
        if style == 'dragon':
            w.triangle((0, 0, 0), (s*9, 3, 2), (s*5, -2, 6), 1.6, 'shade')
            w.triangle((0, 0, 0), (s*8, 2, 1), (s*4, -1, 5), 1.1, 'pink')
            for tip in [(s*9, 3, 2), (s*5, -2, 6)]:
                w.capsule((0, 0, 0), tip, .8, .4, 'base')
        elif style == 'fin':
            w.ellipsoid((s*3, -.5, 1), (4.2, 1, 2.4), 'base')
            w.ellipsoid((s*4, -.9, .5), (2.6, .7, 1.6), 'light')
        else:
            w.ellipsoid((s*2.4, -1.3, 1), (2.6, 3, 3.4), 'shade')
            for i in range(3):
                w.ellipsoid((s*(2+i*.45), -2-i*.7, 2-i*1.7),
                            (1.6, 2.3, 1.1), 'light' if i == 1 else 'base')
        name = 'fin_' + side if style == 'fin' else 'wing_' + side
        parts[name] = w
        limbs[name] = joint(name, (s*pivot[0], pivot[1], pivot[2]), 'wing', -s)


def pet(kind):
    p = palette((250, 208, 61), (255, 234, 116), (221, 161, 43))
    parts, limbs = {}, {}
    b = part(p)
    parts['body'] = b
    if kind == 'duck':
        b.ellipsoid((0, 7, 1.5), (5, 4.8, 6), 'base')
        b.ellipsoid((0, 12.5, -2), (5.2, 4.7, 4.5), 'light')
        b.ellipsoid((0, 11, -6.5), (3.4, 1.25, 2.7), 'orange')
        b.box((-2.4, 10.8, -9), (2.4, 11.3, -8.6), 'brown')
        for a, c in [((-1, 16, -1), (-2, 19, -.5)), ((1, 16, -1), (1, 18.5, 0))]:
            b.capsule(a, c, 1.3, .65, 'base')
        eyes(b, 14.1, -5.9, spacing=3, radius=1.1)
        feet(p, limbs, parts, [('leg_l', (-2.8, 3, 1), 1),
                               ('leg_r', (2.8, 3, 1), -1)], 'orange', 2)
        wings(p, limbs, parts, (4.3, 9, 1))
        t = part(p)
        t.capsule((0, 0, 0), (0, 2, 3), 2, .5, 'light')
        parts['tail'] = t
        limbs['tail'] = joint('tail', (0, 8, 6), 'sway')
    elif kind == 'puffbun':
        p = palette((237, 219, 186), (255, 243, 215), (197, 167, 145))
        b = part(p); parts['body'] = b
        b.ellipsoid((0, 6.5, 1), (5.9, 5, 5.1), 'base')
        b.ellipsoid((0, 10, -2), (5.6, 4.7, 4.4), 'light')
        b.ellipsoid((0, 8, -5.8), (2.5, 1.5, 1), 'base')
        eyes(b, 11, -5.8, spacing=3, radius=1.25)
        b.ellipsoid((0, 9, -7), (1, .75, .7), 'pink')
        for side, s in [('l', -1), ('r', 1)]:
            e = part(p)
            e.chain([(0, 0, 0), (s*1.3, 5.6, .5), (s*3.9, 5, .7),
                     (s*5.1, 1.8, .2), (s*5, -1, -.5)], 1.5, 1.3, 'base')
            e.chain([(s*1.2, 3.5, -.8), (s*3.3, 4.3, -.7),
                     (s*4.6, 1.5, -1)], .7, .7, 'pink')
            parts['ear_'+side] = e
            limbs['ear_'+side] = joint('ear_'+side, (s*3, 13, -.5), 'sway', s)
        feet(p, limbs, parts, [('leg_l', (-3.8, 3, 0), 1),
                               ('leg_r', (3.8, 3, 0), -1)], length=2, wide=1.8)
        b.ellipsoid((0, 6, 6), (2, 2, 2), 'light')
    elif kind == 'gloop':
        p = palette((86, 205, 91), (176, 244, 127), (43, 149, 94), bubble=(210, 255, 190))
        b = part(p); parts['body'] = b
        b.ellipsoid((0, 5, 0), (7, 4.7, 5.8), 'shade')
        b.ellipsoid((0, 7, 0), (6.2, 6.3, 5), 'base')
        b.ellipsoid((-1.7, 10.8, -1.4), (2.7, 1.4, 2.5), 'light')
        # A pale refraction rim and raised bubble suggest a translucent center.
        b.ellipsoid((1, 7, -4.8), (2.4, 2.5, 1), 'light')
        b.ellipsoid((1, 7.3, -5.5), (1.6, 1.6, .7), 'bubble')
        b.ellipsoid((.4, 8, -6), (.6, .6, .4), 'white')
        eyes(b, 9.4, -4.6, spacing=3.6, radius=1)
        smile(b, 5, -5.5)
        for s in (-1, 1):
            b.ellipsoid((s*5, 2, -2), (2.4, 1.6, 2.8), 'base')
    elif kind in ('ember_kit', 'moonpaw'):
        fox = kind == 'ember_kit'
        p = (palette((233, 120, 48), (255, 181, 82), (164, 70, 44)) if fox else
             palette((46, 48, 75), (80, 85, 116), (28, 31, 49), blue=(92, 181, 244)))
        b = part(p); parts['body'] = b
        b.ellipsoid((0, 6, 2), (3.5, 3.6, 5), 'base')
        b.ellipsoid((0, 10, -3), (5.5, 4.7, 4.5), 'base')
        b.ellipsoid((0, 8, -6.1), (3.4, 2, 1.7), 'white' if fox else 'light')
        for s in (-1, 1):
            b.capsule((s*3.6, 12, -2.8), (s*4.1, 17, -2), 2, .25, 'base')
            b.capsule((s*3.7, 13, -4), (s*4.1, 15.8, -3), .9, .15, 'pink')
        eyes(b, 11.5, -6.2, spacing=3.2, radius=1.25, iris='dark' if fox else 'blue')
        b.ellipsoid((0, 9, -8), (.9, .65, .7), 'dark' if fox else 'pink')
        if not fox:
            b.ellipsoid((0, 13.8, -7), (1.5, 1.5, .6), 'gold')
            b.ellipsoid((.7, 14.4, -7.7), (1.3, 1.3, .6), 'base')
        four_feet(p, limbs, parts, x=2.7, front=-2, back=4, color='shade')
        t = part(p)
        t.chain([(0, 0, 0), (1, 2, 3), (2, 5, 5), (2, 7, 4)],
                2.4 if fox else 1.3, 1.5 if fox else .8, 'base')
        if fox:
            t.ellipsoid((2, 6, 5), (2.6, 2.5, 2.2), 'glow_hot')
            t.capsule((2, 6, 5), (3, 10, 4), 2, .1, 'glow_amber')
        parts['tail'] = t; limbs['tail'] = joint('tail', (0, 7, 6), 'sway')
    elif kind == 'cinderling':
        p = palette((169, 69, 55), (212, 122, 70), (111, 57, 59), smoke=(148, 141, 153))
        b = part(p); parts['body'] = b
        b.ellipsoid((0, 7, 2), (4.5, 5, 4.5), 'base')
        b.ellipsoid((0, 6, -1.3), (3.2, 3.5, 1.6), 'light')
        b.ellipsoid((0, 12, -2.5), (5.1, 4, 4.4), 'base')
        b.ellipsoid((0, 10.5, -6), (3.4, 2, 2.3), 'light')
        for s in (-1, 1):
            b.capsule((s*3.5, 14.5, -1), (s*4.5, 18, 0), 1.4, .2, 'gold')
            b.ellipsoid((s*1.4, 11.8, -7.7), (.6, .5, .5), 'dark')
        eyes(b, 13, -5.5, spacing=3.2, radius=1.1)
        b.ellipsoid((0, 13, -9), (1.2, 1.1, 1.2), 'smoke')
        b.ellipsoid((.7, 15.3, -10), (1.7, 1.5, 1.4), 'smoke')
        feet(p, limbs, parts, [('leg_l', (-3, 3, 1), 1), ('leg_r', (3, 3, 1), -1)], 'shade', 2)
        wings(p, limbs, parts, (3.6, 10, 3), 'dragon')
        t = part(p); t.chain([(0, 0, 0), (0, -1, 3), (1, 1, 6)], 2, .45, 'base')
        for z in (1, 3, 5): t.capsule((0, 1, z), (0, 3, z), .9, .1, 'gold')
        parts['tail'] = t; limbs['tail'] = joint('tail', (0, 6, 6), 'sway')
    elif kind == 'hoot':
        p = palette((101, 132, 158), (164, 189, 199), (62, 86, 121), amber=(242, 174, 56))
        b = part(p); parts['body'] = b
        b.ellipsoid((0, 7.5, 0), (5.3, 5.9, 4.5), 'base')
        b.ellipsoid((0, 11, -1), (6, 4.6, 4.8), 'base')
        for s in (-1, 1):
            b.ellipsoid((s*3.1, 11.3, -5), (2.9, 3.2, 1.3), 'light')
            b.ellipsoid((s*3.1, 11.8, -6.1), (2.1, 2.2, .8), 'amber')
            b.ellipsoid((s*3.1, 12, -6.8), (1.15, 1.55, .5), 'dark')
            b.box((s*3.1-.7, 12.5, -7.3), (s*3.1+.1, 13.3, -6.8), 'white')
            b.capsule((s*4.3, 13, 0), (s*5.6, 17, 1), 1.8, .2, 'shade')
        b.capsule((0, 10, -6), (0, 8, -7), 1.2, .1, 'gold')
        b.ellipsoid((0, 5, -3.5), (3, 3, 1.7), 'light')
        for x in (-2, 0, 2): b.capsule((x, 6, -4.8), (x, 4, -4.5), .4, .7, 'shade')
        wings(p, limbs, parts, (4.9, 9, 0))
        feet(p, limbs, parts, [('leg_l', (-2.5, 2, 0), 1), ('leg_r', (2.5, 2, 0), -1)], 'gold', 1)
    elif kind == 'lilyhop':
        p = palette((96, 176, 88), (189, 219, 126), (49, 121, 77), leaf=(50, 140, 95))
        b = part(p); parts['body'] = b
        b.ellipsoid((0, 5, 1), (6.1, 4, 5.3), 'base')
        b.ellipsoid((0, 7, -2), (6, 3.6, 4), 'base')
        b.ellipsoid((0, 5, -5), (4.8, 2.1, 1), 'light')
        for s in (-1, 1): b.ellipsoid((s*3.5, 9.2, -3), (2.4, 2.6, 2), 'base')
        eyes(b, 10, -4.8, spacing=3.5, radius=1.3)
        smile(b, 5.3, -6.2, 2.5)
        b.ellipsoid((0, 12.2, 1.4), (6.2, .85, 4.8), 'leaf')
        b.capsule((0, 13, 1), (0, 13, -2), .4, .2, 'light')
        # Cut a wedge from the front of the pad after rasterizing it below.
        b.ellipsoid((2.5, 13.1, 2), (1.7, .8, 1.5), 'pink')
        b.ellipsoid((2.5, 14, 2), (.6, .6, .6), 'gold')
        four_feet(p, limbs, parts, x=4.6, front=-3, back=3, y=2)
    elif kind == 'mossback':
        p = palette((117, 158, 83), (183, 202, 120), (67, 105, 70), shell=(133, 106, 68), moss=(70, 135, 81))
        b = part(p); parts['body'] = b
        b.ellipsoid((0, 5, 1.5), (6.3, 4.3, 6), 'shell')
        b.ellipsoid((0, 7, 1.7), (5.9, 3, 5.7), 'moss')
        for x, z in [(-3, 0), (3, 0), (0, 3), (0, -2)]:
            b.ellipsoid((x, 8.8, z), (2.1, 1.2, 2), 'base')
        b.ellipsoid((0, 5, -5), (3.8, 2.9, 3.6), 'light')
        eyes(b, 6.5, -7.2, spacing=2.2, radius=.9)
        b.capsule((0, 9, 2), (0, 14, 2), .7, .55, 'shade')
        b.ellipsoid((-1.8, 13, 2), (2.3, .8, 1.3), 'base')
        b.ellipsoid((1.7, 14, 2), (2.1, .85, 1.2), 'light')
        four_feet(p, limbs, parts, x=4.4, front=-2, back=5, y=2)
        t = part(p); t.capsule((0, 0, 0), (0, 0, 3), 1, .1, 'light')
        parts['tail'] = t; limbs['tail'] = joint('tail', (0, 3, 7), 'sway')
    elif kind == 'wisp':
        p = palette((172, 213, 221), (224, 243, 234), (101, 165, 189))
        b = part(p); parts['body'] = b
        b.ellipsoid((0, 10, 0), (5.4, 7.5, 4), 'base')
        b.ellipsoid((-1, 14, -.5), (4.6, 3.7, 3.8), 'light')
        b.capsule((0, 15, 0), (-2, 20, 1), 2.2, .1, 'light')
        for x, y in [(-3.3, 2), (0, 1), (3.3, 3)]:
            b.capsule((x, 5, 0), (x-1, y, .5), 1.8, .2, 'base')
        eyes(b, 14, -3.7, spacing=2.6, radius=1)
        # Chest recess, brass cage and warm core are separate glowing voxels.
        b.box((-2.6, 5, -4.3), (2.6, 10.5, -3.2), 'shade')
        b.box((-2, 5.7, -4.8), (2, 9.5, -4), 'glow_amber')
        for x in (-2.5, 2): b.box((x, 5, -5), (x+.6, 10, -4.3), 'gold')
        for y in (5, 9.6): b.box((-2.5, y, -5), (2.6, y+.7, -4.3), 'gold')
        b.capsule((0, 10, -4), (0, 11, -4), .6, .6, 'gold')
        for side, s in [('l', -1), ('r', 1)]:
            a = part(p); a.capsule((0, 0, 0), (s*2, -3, -1), 1.5, .4, 'light')
            parts['arm_'+side] = a
            limbs['arm_'+side] = joint('arm_'+side, (s*4, 10, 0), 'sway', s)
    elif kind == 'shardling':
        p = palette((126, 109, 174), (188, 164, 224), (77, 74, 121), crystal=(162, 104, 224))
        b = part(p); parts['body'] = b
        b.box((-4, 3, -2), (4, 11, 4), 'shade')
        b.ellipsoid((0, 11, -1.4), (4.8, 4.7, 4.1), 'base')
        b.box((-3.5, 9, -5), (3.5, 12.8, -3), 'shade')
        for s in (-1, 1):
            b.box((s*2-1, 10.4, -5.6), (s*2+1, 12.1, -4.7), 'glow_blue')
        for x, y, z in [(-3, 13, 2), (0, 15, 3), (3, 12, 3)]:
            b.capsule((x, y-4, z), (x*1.5, y+4, z+1), 1.9, .05, 'crystal')
            b.capsule((x-.5, y-2, z-.9), (x*1.5-.5, y+2, z), .55, .1, 'light')
        feet(p, limbs, parts, [('leg_l', (-2.7, 3, 0), 1), ('leg_r', (2.7, 3, 0), -1)], 'shade', 3, 1.8)
        for side, s in [('l', -1), ('r', 1)]:
            a = part(p); a.ellipsoid((s*.6, -2, 0), (2.1, 3.3, 2.1), 'base')
            a.box((-1.8, -5, -2), (1.8, -2, 1), 'shade')
            parts['arm_'+side] = a
            limbs['arm_'+side] = joint('arm_'+side, (s*5, 10, 0), 'arm', s)
    elif kind == 'axie':
        p = palette((240, 162, 185), (255, 210, 213), (209, 104, 153), gill=(222, 91, 144))
        b = part(p); parts['body'] = b
        b.ellipsoid((0, 4.5, 2), (3.6, 3.3, 6), 'base')
        b.ellipsoid((0, 7, -3), (6, 4, 4), 'light')
        eyes(b, 8, -6.6, spacing=3.5, radius=1.2)
        smile(b, 5.6, -7.2)
        for side, s in [('l', -1), ('r', 1)]:
            g = part(p)
            for dy, dz in [(3, .3), (0, -1), (-2.3, .5)]:
                g.capsule((0, 0, 0), (s*3.4, dy, dz), .85, .75, 'gill')
                g.ellipsoid((s*3.4, dy, dz), (1.1, 1.3, 1), 'pink')
            parts['gill_'+side] = g
            limbs['gill_'+side] = joint('gill_'+side, (s*5, 8, -2), 'sway', s)
        four_feet(p, limbs, parts, x=3, front=-1, back=5, y=2)
        t = part(p); t.capsule((0, 0, 0), (0, 1, 7), 2, .2, 'base')
        t.ellipsoid((0, 1.5, 4), (.8, 2.8, 3.8), 'gill')
        parts['tail'] = t; limbs['tail'] = joint('tail', (0, 4, 7), 'sway')
    elif kind == 'capling':
        p = palette((210, 66, 69), (243, 119, 104), (155, 47, 65), stem=(238, 213, 166))
        b = part(p); parts['body'] = b
        b.ellipsoid((0, 6, -2.6), (4.2, 4.6, 4.4), 'stem')
        b.ellipsoid((0, 7.5, -6.6), (3.6, 2.8, 2), 'stem')
        b.ellipsoid((0, 10.5, 0), (7.7, 1, 6.6), 'white')
        b.ellipsoid((0, 12.5, 0), (7.7, 3.5, 6.6), 'base')
        b.ellipsoid((-1, 14.3, -.5), (5.8, 1.9, 5.1), 'light')
        for x, y, z, r in [(-4, 14.5, -2, 1.5), (2, 15.3, -1, 1.9),
                             (4.8, 13.9, 2, 1.3), (-1.5, 15, 3.5, 1.2)]:
            b.ellipsoid((x, y, z), (r, .75, r), 'white')
        eyes(b, 8.8, -8, spacing=2.1, radius=1.15)
        smile(b, 6, -8.3, .8)
        feet(p, limbs, parts, [('leg_l', (-1.9, 2, 0), 1), ('leg_r', (1.9, 2, 0), -1)], 'stem', 1)
        for side, s in [('l', -1), ('r', 1)]:
            a = part(p); a.capsule((0, 0, 0), (s*2, -1, -1), 1.1, .8, 'stem')
            parts['arm_'+side] = a
            limbs['arm_'+side] = joint('arm_'+side, (s*3, 7, 0), 'arm', s)
    elif kind == 'nebula_jelly':
        p = palette((54, 67, 135), (99, 104, 184), (38, 43, 100), tendril=(126, 106, 196))
        b = part(p); parts['body'] = b
        b.ellipsoid((0, 15, 0), (6.8, 5.7, 5.6), 'base')
        b.ellipsoid((-1, 18, 0), (4.8, 2.3, 4.3), 'light')
        b.ellipsoid((0, 11.3, 0), (7.4, 1.7, 6), 'shade')
        for x, y, z in [(-3, 16.5, -5), (2, 18, -4.4), (4.5, 14, -4.3),
                         (-2, 20, 0), (2.5, 19.5, 2), (-6, 14, 0), (3, 16, 4.5)]:
            b.box((x-1, y, z), (x+1.7, y+.8, z+.9), 'glow_star')
            b.box((x, y-1, z), (x+.7, y+1.7, z+.9), 'glow_star')
        eyes(b, 13.5, -5.4, spacing=2.6, radius=.9)
        for i, (x, z) in enumerate([(-4, 0), (-2, 3), (0, 0), (2, 3), (4, 0)]):
            t = part(p)
            t.chain([(0, 0, 0), (1, -3, .3), (-1, -6-i%2, 1),
                     (0, -9-i%3, 1.5)], .85, .45, 'tendril')
            t.ellipsoid((0, -9-i%3, 1.5), (.8, .9, .8), 'glow_blue')
            name = 'tendril_'+str(i); parts[name] = t
            limbs[name] = joint(name, (x, 11, z), 'sway', 1 if i%2 else -1)
    elif kind == 'skywhale':
        p = palette((97, 160, 195), (162, 209, 220), (60, 113, 166))
        b = part(p); parts['body'] = b
        b.ellipsoid((0, 7, -.5), (6.1, 5.5, 8.1), 'base')
        b.ellipsoid((0, 5, -2), (5.7, 3.3, 7), 'white')
        b.ellipsoid((-1, 10, -2), (4.9, 2.6, 5.8), 'light')
        for s in (-1, 1):
            b.ellipsoid((s*4.4, 8.2, -6.1), (1.7, 1.8, 1), 'white')
            b.ellipsoid((s*4.4, 8.4, -6.9), (1.1, 1.2, .6), 'dark')
            b.ellipsoid((s*4.4-.3, 9, -7.3), (.4, .4, .4), 'white')
        smile(b, 5.5, -8.9, 2.2)
        b.capsule((0, 11, 2), (0, 14, 3), 1.6, .1, 'shade')
        wings(p, limbs, parts, (5, 6, 0), 'fin')
        t = part(p); t.capsule((0, 0, 0), (0, 1, 5), 2.7, 1.1, 'base')
        for s in (-1, 1):
            t.ellipsoid((s*3, 1.5, 5.5), (3.8, 1.1, 2.6), 'base')
            t.ellipsoid((s*3, 2.2, 5), (2.9, .6, 1.8), 'light')
        parts['tail'] = t; limbs['tail'] = joint('tail', (0, 7, 6), 'sway')
    else:
        raise ValueError(kind)
    return p, parts, limbs


YARD = palette((145, 99, 63), (194, 143, 85), (88, 65, 53),
               straw=(206, 168, 81), straw_light=(244, 210, 123),
               grass=(110, 149, 78), soil=(121, 91, 66), cream=(236, 215, 171),
               teal=(73, 142, 138), teal_light=(126, 186, 165),
               roof=(170, 91, 73), roof_light=(206, 126, 91),
               stone=(137, 139, 121), leaf=(73, 125, 79), speckle=(143, 115, 145))
YARD['egg_shell'] = YARD['cream']


def egg(p, at=(0, 0, 0), radius=3):
    x, y, z = at
    p.ellipsoid((x, y+radius*1.15, z), (radius, radius*1.15, radius), 'egg_shell')
    p.ellipsoid((x, y+radius*1.9, z), (radius*.72, radius*.95, radius*.72), 'egg_shell')
    # The speckles are painted only on the shell, never floating above it.


def speckle_eggs(vox):
    for (x, y, z), c in list(vox.items()):
        if c == 'egg_shell' and ((x*17+y*31+z*13) % 37 < 4):
            vox[x, y, z] = 'speckle'
    return vox


def crate(p, at, eggs=True):
    x, y, z = at
    p.box((x-5, y, z-4), (x+5, y+1, z+4), 'shade')
    for yy in (1, 3):
        for zz in (-4, 3): p.box((x-5, y+yy, z+zz), (x+5, y+yy+1, z+zz+1), 'light')
        for xx in (-5, 4): p.box((x+xx, y+yy, z-4), (x+xx+1, y+yy+1, z+4), 'light')
    for xx in (-5, 4):
        for zz in (-4, 3): p.box((x+xx, y, z+zz), (x+xx+1, y+5, z+zz+1), 'base')
    if eggs:
        for xx in (-2.5, 2.5): egg(p, (x+xx, y+1, z), 1.8)


def prop(kind):
    p = part(YARD)
    size = .1
    collision = [0, 0, 0]
    offset = None
    if kind == 'pet_egg':
        egg(p, radius=4)
        size = .035
    elif kind == 'hatching_nest':
        size = .09
        p.ellipsoid((0, 1, 0), (14, 2, 12), 'soil')
        p.ellipsoid((0, 2, 0), (13, 1.6, 11), 'grass')
        p.ellipsoid((0, 3, 0), (9.5, 1.5, 8.3), 'shade')
        for i in range(40):
            a = i*math.tau/40
            x, z = math.cos(a), math.sin(a)
            p.capsule((x*8-z*2, 3.8+i%2*.6, z*7+x*2),
                      (x*11+z*2, 4.5+i%3*.35, z*9-x*2), .8, .6,
                      'straw_light' if i%3 == 0 else 'straw')
        for at, r in [((-3, 3.4, -1), 2.5), ((3, 3.4, .5), 2.4), ((0, 3.4, 4), 2)]: egg(p, at, r)
        collision = [1.7, .55, 1.45]
    elif kind == 'egg_crate':
        size = .085
        crate(p, (0, 0, 0))
        collision = [.85, .45, .7]
    elif kind == 'pet_store':
        size = .1
        p.box((-17, 0, -10), (17, 2, 10), 'shade')
        for x in (-15, 14):
            for z in (-8, 7):
                p.box((x, 1, z), (x+2, 25, z+2), 'base')
                p.box((x-.5, 22, z-.5), (x+2.5, 25, z+2.5), 'light')
        # Open back and an inviting counter, front at -Z.
        p.box((-15, 2, -9), (16, 11, -6), 'base')
        for x in range(-14, 16, 4): p.box((x, 3, -9.6), (x+1, 9, -8.8), 'light')
        p.box((-17, 11, -11), (17, 13, -4), 'light')
        for x in range(-18, 18):
            for z in range(-13, 13):
                y = 27 - abs(z)//5
                p.box((x, y, z), (x+1, y+1.5, z+1), 'teal' if (x+18)//4%2 else 'cream')
            p.box((x, 21, -13), (x+1, 25, -12), 'teal' if (x+18)//4%2 else 'cream')
        crate(p, (-8, 13, -7)); crate(p, (8, 13, -7))
        crate(p, (-21, 0, 2)); crate(p, (-21, 5, 2))
        # Hanging sign uses an egg emblem instead of tiny lettering.
        p.box((-8, 18, -14.5), (8, 23, -13), 'shade')
        p.box((-7, 18.7, -15), (7, 22.5, -14.4), 'light')
        p.ellipsoid((0, 20.5, -15.5), (1.7, 2, .7), 'cream')
        for x in (-5, 5): p.capsule((x, 23, -13), (x, 25, -13), .4, .4, 'gold')
        collision = [3.3, 1.3, 1.7]
    elif kind == 'caretaker_cottage':
        size = .1
        p.box((-23, 0, -19), (23, 3, 19), 'stone')
        p.box((-21, 3, -17), (21, 27, 17), 'cream')
        for x in (-21, 19):
            for z in (-17, 15): p.box((x, 3, z), (x+2, 29, z+2), 'base')
        for y in (5, 24): p.box((-22, y, -17.6), (22, y+1.5, -16.7), 'light')
        # A front-facing gable; broad clay shingles read from above.
        for x in range(-25, 25):
            top = 29+(24-abs(x))//2
            p.box((x, 26, -17), (x+1, top, 17), 'cream')
            for z in range(-21, 22):
                p.box((x, top, z), (x+1, top+2, z+1),
                      'roof_light' if (z//4+x//5)%3 == 0 else 'roof')
        p.box((-1, 41, -22), (1, 43, 23), 'light')
        p.box((11, 31, 5), (16, 46, 10), 'stone')
        p.box((10, 44, 4), (17, 46, 11), 'shade')
        p.box((-5, 3, -18), (5, 20, -17), 'shade')
        p.box((-4, 3, -18.6), (4, 19, -17.7), 'teal')
        for y in (6, 10, 14): p.box((-3.6, y, -19), (3.6, y+.5, -18.5), 'teal_light')
        p.ellipsoid((2.5, 11, -19), (.7, .7, .6), 'gold')
        for x in (-14, 14):
            p.box((x-4, 12, -18), (x+4, 22, -16), 'base')
            p.box((x-3, 13, -18.5), (x+3, 21, -17.8), 'glow_amber')
            p.box((x-.5, 12, -19), (x+.5, 22, -18.3), 'light')
            p.box((x-4, 16, -19), (x+4, 17, -18.3), 'light')
            p.box((x-5, 9, -21), (x+5, 12, -18), 'base')
            for xx in (-3, 0, 3):
                p.ellipsoid((x+xx, 12.5, -20), (1.7, 1.4, 1.5), 'leaf')
                p.ellipsoid((x+xx, 14, -20), (.9, .8, .9), 'pink')
        p.box((-7, 0, -23), (7, 2, -18), 'stone')
        # Duck weather vane on the ridge.
        p.capsule((0, 42, 4), (0, 48, 4), .6, .6, 'shade')
        p.ellipsoid((0, 49, 4), (2.3, 1.2, 1), 'gold')
        p.ellipsoid((2, 50, 4), (1.1, 1.3, 1), 'gold')
        p.box((2.5, 49.5, 3.5), (4.5, 50.2, 4.5), 'orange')
        collision = [4.4, 3.9, 3.6]
    elif kind == 'food_bowl':
        size = .045
        p.ellipsoid((0, 1, 0), (5.4, 1.6, 5.4), 'teal')
        for i in range(24):
            a = i*math.tau/24
            p.ellipsoid((4.6*math.cos(a), 2.5, 4.6*math.sin(a)), (1, .8, 1), 'teal_light')
        p.ellipsoid((0, 2.3, 0), (3.7, .5, 3.7), 'shade')
        for x, z in [(-2, -1), (0, 1), (2, -.5), (-1, 2.3), (.3, -2)]:
            p.ellipsoid((x, 2.9, z), (.9, .6, .9), 'brown')
        # Cream paw mark on the front of the ceramic bowl.
        p.ellipsoid((0, 1.4, -5.2), (1, .75, .5), 'white')
        for x in (-1.3, 0, 1.3): p.ellipsoid((x, 2.5, -5), (.45, .45, .45), 'white')
    elif kind in ('pet_fence', 'pet_gate'):
        size = .08
        for x in (-15, 13):
            p.box((x, 0, -1), (x+2, 14, 1), 'base')
            p.ellipsoid((x+1, 14, 0), (1.8, 1.3, 1.8), 'light')
        if kind == 'pet_fence':
            for y in (4, 10): p.box((-14, y, -.8), (14, y+1.8, .8), 'light')
            for x in (-10, -5, 0, 5, 10):
                p.box((x-.8, 2, -1), (x+.8, 12, .8), 'base')
                p.capsule((x, 12, 0), (x, 13.5, 0), 1, .1, 'light')
        else:
            for y in (3, 11): p.box((-12, y, -1), (12, y+1.5, 1), 'teal')
            for x in range(-10, 11, 5): p.box((x-.7, 3, -.9), (x+.7, 12, .9), 'teal')
            p.capsule((-11, 4, 0), (11, 11, 0), .8, .8, 'teal_light')
            for y in (4, 10): p.box((-13, y, -1.5), (-9, y+1, -.8), 'gold')
            p.box((10, 7, -1.5), (14, 9, -.7), 'gold')
        collision = [2.4, 1.2, .24]
    elif kind == 'toy_ball':
        size = .04
        p.ellipsoid((0, 4, 0), (4, 4, 4), 'teal')
        p.ellipsoid((-.6, 6.8, -.6), (2.8, 1.1, 2.7), 'cream')
        p.ellipsoid((0, 3.7, -3.7), (2, 2.8, .7), 'roof')
        p.ellipsoid((-1.6, 6, -2.3), (.8, .8, .7), 'white')
    elif kind == 'lantern_post':
        size = .075
        p.box((-3, 0, -3), (3, 2, 3), 'stone')
        p.box((-1, 1, -1), (1, 29, 1), 'base')
        p.capsule((0, 29, 0), (6, 29, 0), 1, 1, 'light')
        p.capsule((6, 29, 0), (6, 26, 0), .6, .6, 'gold')
        for y in (17, 25): p.box((2, y, -4), (10, y+1, 4), 'shade')
        p.box((3, 18, -3), (9, 25, 3), 'glow_amber')
        for x in (2, 9):
            for z in (-4, 3): p.box((x, 17, z), (x+1, 26, z+1), 'gold')
        p.ellipsoid((6, 26, 0), (4.3, 1.4, 4.3), 'teal')
        collision = [.3, 2.2, .3]
    elif kind == 'little_bridge':
        size = .1
        for z in range(-18, 19):
            y = 2 + round(3*(1-(z/19)**2))
            p.box((-9, y, z), (9, y+2, z+1), 'light' if z%4 else 'base')
        for x in (-9, 8):
            for z in (-17, -8, 0, 8, 17):
                y = 2+round(3*(1-(z/19)**2))
                p.box((x, y, z-1), (x+1.4, y+10, z+1), 'base')
                p.ellipsoid((x+.5, y+10, z), (1.3, 1, 1.3), 'light')
            for z in range(-18, 19):
                y = 10+round(3*(1-(z/19)**2))
                p.box((x, y, z), (x+1.4, y+1.4, z+1), 'light')
        # No envelope: the yard owns the walkable deck and rail collision.
    else:
        raise ValueError(kind)
    vox = speckle_eggs(p.voxels()) if kind in ('pet_egg', 'egg_crate', 'pet_store', 'hatching_nest') else p.voxels()
    return vox, size, collision, offset


PROPS = ['hatching_nest', 'pet_store', 'caretaker_cottage', 'food_bowl',
         'pet_fence', 'pet_gate', 'egg_crate', 'toy_ball', 'lantern_post', 'little_bridge']


def npc(kind):
    keeper = kind == 'caretaker'
    p = palette((92, 139, 123) if keeper else (181, 102, 120),
                (145, 180, 147) if keeper else (224, 153, 150), (63, 88, 88),
                cream=(240, 222, 182), egg_shell=(240, 222, 182), speckle=(143, 115, 145),
                skin=(232, 177, 137), hair=(214, 214, 196) if keeper else (103, 63, 58),
                straw=(212, 177, 95), straw_light=(244, 211, 132), duck=(255, 215, 70))
    b = part(p)
    b.box((-3.5, 5, -2), (3.5, 13, 2.5), 'base')
    b.box((-2.8, 5, -2.8), (2.8, 12.5, -2), 'cream')
    for x in (-2.4, 1.7): b.box((x, 11, -2.7), (x+.7, 14, -2), 'cream')
    b.box((-1.4, 6.5, -3.4), (1.4, 8.5, -2.6), 'light')
    b.ellipsoid((0, 17, 0), (4.2, 4.2, 3.5), 'skin')
    b.ellipsoid((0, 19, 1), (4.3, 3, 3.3), 'hair')
    b.box((-3.2, 15, -3.4), (3.2, 19.5, -2), 'skin')
    eyes(b, 17.4, -3.3, spacing=2, radius=.7)
    b.ellipsoid((0, 15.6, -4), (.7, .8, .7), 'skin')
    for s in (-1, 1): b.ellipsoid((s*2.8, 15.4, -3.6), (.7, .6, .4), 'pink')
    smile(b, 14.8, -3.5, .9)
    if keeper:
        # Brows, sideburns, straw brim and a gently dented crown.
        for s in (-1, 1):
            b.box((s*2-1, 19, -3.7), (s*2+1, 19.7, -3.2), 'hair')
            b.capsule((s*3.8, 18, -1), (s*3.8, 15.3, -1), .7, .7, 'hair')
        b.ellipsoid((0, 21, .4), (7, .9, 6), 'straw')
        b.ellipsoid((0, 22.5, .6), (4.2, 2.5, 3.8), 'straw_light')
        b.ellipsoid((0, 21.8, .5), (4.4, .65, 4), 'base')
        # The little shoulder duck is fixed to the torso, clear of the hat.
        b.ellipsoid((-5.5, 14.2, -.6), (2.4, 1.6, 2), 'duck')
        b.ellipsoid((-6, 16, -1.6), (1.8, 1.9, 1.7), 'duck')
        b.ellipsoid((-6, 15.5, -3.3), (1.3, .6, 1), 'orange')
        for x in (-7, -5): b.ellipsoid((x, 16.5, -2.8), (.35, .45, .3), 'dark')
        b.capsule((-6.2, 17, -1), (-6.6, 18.5, -.5), .7, .2, 'duck')
    else:
        b.ellipsoid((0, 21, .5), (4.6, 1.6, 4), 'base')
        b.box((-4, 20, -4), (4, 21.5, -3), 'light')
        b.ellipsoid((2.5, 21.7, -2.5), (1.1, 1.3, .5), 'gold')
    parts, limbs = {'body': b}, {}
    for side, s in [('l', -1), ('r', 1)]:
        a = part(p)
        a.capsule((0, 0, 0), (0, -4.5, -.2), 1.5, 1.3, 'base')
        a.ellipsoid((0, -5, -.5), (1.3, 1.3, 1.3), 'skin')
        if not keeper and side == 'r':
            a.ellipsoid((0, -5.6, -3.2), (3.7, 2, 2.5), 'straw')
            for y in (-6, -5): a.box((-3.5, y, -5.4), (3.5, y+.5, -5), 'straw_light')
            a.chain([(-3, -5, -3), (-2, -1, -3), (2, -1, -3), (3, -5, -3)], .5, .5, 'brown')
            for x in (-1.7, 1.5): egg(a, (x, -5.3, -3.5), 1.25)
        parts['arm_'+side] = a
        limbs['arm_'+side] = joint('arm_'+side, (s*4.5, 13, 0), 'arm', s)
    f = part(p)
    f.box((-1.4, -4, -1.3), (1.4, 0, 1.5), 'shade')
    f.box((-1.5, -5, -2.7), (1.5, -3.5, 1.5), 'brown')
    parts['leg'] = f
    for side, s in [('l', -1), ('r', 1)]: limbs['leg_'+side] = joint('leg', (s*2, 5, 0), phase=s)
    return p, parts, limbs


def assembled(parts, limbs):
    full = dict(parts['body'])
    for spec in limbs.values():
        assert not spec.get('parent_limb'), 'This exporter expects root-relative pivots'
        for xyz, c in parts[spec['part']].items():
            key = tuple(round(xyz[i] + spec['pivot'][i]) for i in range(3))
            full[key] = c
    return full


def export(folder, parts, pal, limbs, height=None, voxel_size=None, **extra):
    """Export solid/glow frames together and a grounded editable rest pose."""
    folder.mkdir(parents=True, exist_ok=True)
    parts = {k: v.voxels() if isinstance(v, Part) else v for k, v in parts.items()}
    full = assembled(parts, limbs)
    lo, extent = fit_frame(full)
    # Make the lowest occupied cell rest on the ground, not its padded frame.
    ground = lo[1]
    parts['body'] = {(x, y-ground, z): c for (x, y, z), c in parts['body'].items()}
    limbs = {k: dict(v, pivot=[v['pivot'][0], v['pivot'][1]-ground, v['pivot'][2]])
             for k, v in limbs.items()}
    full = assembled(parts, limbs)
    vs = height / extent[1] if height is not None else voxel_size
    rig = dict(voxel_size=vs, parts={}, limbs=limbs,
               hand=[0, round(extent[1]*.65), lo[2]], hover=0, bob=0, waddle=.18, **extra)
    for name, vox in parts.items():
        origin, size = fit_frame(vox)
        origin = tuple(n-1 for n in origin); size = tuple(n+2 for n in size)
        assert max(size) <= 256
        info = {'frame_min': list(origin)}
        for glow, suffix in [(False, ''), (True, '_glow')]:
            selected = {p: c for p, c in vox.items() if c.startswith('glow') == glow}
            path = folder / (name+suffix+'.vox')
            if selected:
                write_vox(str(path), selected, pal, origin, size)
            elif path.exists():
                path.unlink()
            if glow and selected: info['glow'] = True
            if not glow and not selected: info['solid'] = False
        rig['parts'][name] = info
    origin, size = fit_frame(full)
    write_vox(str(folder/'model.vox'), full, pal, origin, size)
    (folder/'rig.json').write_text(json.dumps(rig, indent=2)+'\n')
    return dict(folder=folder.relative_to(ROOT).as_posix(), height_m=extent[1]*vs,
                voxel_size=vs, frame_min=list(origin), frame_size=list(size),
                parts=list(parts), limbs=list(limbs), glow_parts=[n for n, s in rig['parts'].items() if s.get('glow')])


def icon():
    # Draw at 32 px and enlarge with nearest filtering: crisp 2 px art at 64 px.
    im = Image.new('RGBA', (32, 32))
    d = ImageDraw.Draw(im)
    contour = [(10, 25), (7, 22), (6, 18), (7, 12), (10, 6), (13, 3),
               (17, 2), (21, 5), (24, 11), (26, 18), (25, 23), (22, 26), (15, 28)]
    d.polygon(contour, fill='#594556')
    d.polygon([(11, 24), (9, 22), (8, 18), (9, 12), (12, 6), (15, 4),
               (17, 4), (20, 6), (23, 12), (24, 18), (23, 23), (21, 24), (15, 26)], fill='#b99da4')
    d.polygon([(10, 21), (9, 17), (11, 10), (14, 5), (17, 4), (20, 7),
               (22, 12), (23, 18), (21, 22), (17, 24), (13, 24)], fill='#ebd6ae')
    d.polygon([(10, 15), (12, 9), (15, 6), (18, 6), (20, 10), (20, 17),
               (16, 21), (12, 21)], fill='#fff0c9')
    for rect in [(13, 9, 14, 10), (19, 12, 21, 13), (10, 17, 11, 18),
                 (15, 18, 16, 20), (20, 21, 21, 22), (16, 14, 17, 14), (22, 17, 23, 18)]:
        d.rectangle(rect, fill='#957b9b')
    d.rectangle((13, 8, 14, 8), fill='#fff9df')
    path = ROOT/'items/textures/pet_egg.png'
    im.resize((64, 64), Image.Resampling.NEAREST).save(path)


def validate(manifest):
    from preview_voxel_batch import assemble, read_vox
    contract = (ROOT/'docs/PETS.md').read_text()
    assert set(manifest['pets']) == set(SPECIES)
    for name, (height, gait) in SPECIES.items():
        row = next(line for line in contract.splitlines() if line.startswith(f'| {name} |'))
        cells = [c.strip() for c in row.split('|')]
        assert float(cells[4]) == height and cells[5] == gait
        record = manifest['pets'][name]
        assert record['gait'] == gait
        assert abs(record['height_m']-height) < 1e-8
    for group in ('pets', 'npcs', 'props'):
        for name, record in manifest[group].items():
            folder = ROOT/record['folder']
            vox, rig = assemble(folder)
            lo, extent = fit_frame(vox)
            assert lo[1] == 0, (name, lo)
            assert abs(extent[1]*rig['voxel_size']-record['height_m']) < 1e-8
            assert set(rig['parts']) == {'body'} | {s['part'] for s in rig['limbs'].values()}
            for n, info in rig['parts'].items():
                solid, glowing = {}, {}
                if info.get('solid', True): solid = read_vox(folder/(n+'.vox'))
                if info.get('glow'): glowing = read_vox(folder/(n+'_glow.vox'))
                assert not solid.keys() & glowing.keys(), (name, n)
                if glowing and solid:
                    def frame(path):
                        data = path.read_bytes()
                        return struct.unpack_from('<3I', data, 32)
                    assert frame(folder/(n+'.vox')) == frame(folder/(n+'_glow.vox'))
            model = read_vox(folder/'model.vox')
            expected = {tuple(p[k]-lo[k] for k in range(3)): c for p, (c, _) in vox.items()}
            assert model == expected, name
            assert set(rig['parts']) == set(record['parts'])
            assert len(vox) < 100000, (name, len(vox))
    for species, part_name in [('ember_kit', 'tail'), ('wisp', 'body'),
                               ('shardling', 'body'), ('nebula_jelly', 'body')]:
        assert part_name in manifest['pets'][species]['glow_parts']
    egg_vox, egg_rig = assemble(ROOT/'creatures/pet_egg')
    prop_vox, prop_rig = assemble(ROOT/'props/pets/pet_egg')
    assert egg_vox == prop_vox and egg_rig == prop_rig
    with Image.open(ROOT/'items/textures/pet_egg.png') as im:
        assert im.size == (64, 64) and im.mode == 'RGBA'
        assert im.getpixel((0, 0))[3] == 0
        assert im.getbbox() and im.getbbox()[0] > 0
    assert len(manifest['pets']) == 15 and len(manifest['npcs']) == 2
    print('Validated 15 pets, 2 NPCs, egg, 10 props and 64x64 egg icon.')


def overhead_preview(voxels, width, height):
    """Render exposed voxel faces with an actual 50 degree camera."""
    yaw, elevation = math.radians(25), math.radians(50)
    ca, sa, ch, sh = math.cos(yaw), math.sin(yaw), math.cos(elevation), math.sin(elevation)
    right, up = (ca, 0, sa), (-sa*sh, ch, ca*sh)
    eye = (sa*ch, sh, -ca*ch)

    def dot(a, b):
        return sum(a[i]*b[i] for i in range(3))

    projected = [(dot(p, right), dot(p, up)) for p in voxels]
    minx = min(p[0] for p in projected); maxx = max(p[0] for p in projected)
    miny = min(p[1] for p in projected); maxy = max(p[1] for p in projected)
    scale = min((width-36)/(maxx-minx+3), (height-36)/(maxy-miny+3))

    def project(p):
        return (width/2+(dot(p, right)-(minx+maxx)/2)*scale,
                height/2-(dot(p, up)-(miny+maxy)/2)*scale)

    shapes = [
        ((1, 0, 0), [(1, 0, 0), (1, 1, 0), (1, 1, 1), (1, 0, 1)], .77),
        ((0, 1, 0), [(0, 1, 0), (0, 1, 1), (1, 1, 1), (1, 1, 0)], 1.12),
        ((0, 0, -1), [(0, 0, 0), (0, 1, 0), (1, 1, 0), (1, 0, 0)], .94),
    ]
    faces = []
    for xyz, (color, glow) in voxels.items():
        for normal, corners, light in shapes:
            neighbor = tuple(xyz[k]+normal[k] for k in range(3))
            if neighbor in voxels:
                continue
            polygon = [project(tuple(xyz[k]+corner[k] for k in range(3))) for corner in corners]
            center = tuple(xyz[k]+.5+normal[k]*.5 for k in range(3))
            rgb = tuple(min(255, round(c*(1.08 if glow else light))) for c in color)
            faces.append((dot(center, eye), polygon, rgb))
    im = Image.new('RGB', (width*2, height*2), '#202832')
    draw = ImageDraw.Draw(im)
    for _, polygon, color in sorted(faces, key=lambda f: f[0]):
        draw.polygon([(x*2, y*2) for x, y in polygon], fill=color)
    return im.resize((width, height), Image.Resampling.LANCZOS)


def previews(manifest, destination):
    from preview_voxel_batch import assemble, render
    destination = destination.resolve()
    assert destination.is_relative_to(Path('/tmp')), 'Previews must stay in /tmp'
    destination.mkdir(parents=True, exist_ok=True)
    font = ImageFont.truetype(str(ROOT/'fonts/BreeSerif.ttf'), 18)
    for group, columns, tile in [('pets', 5, (240, 230)), ('npcs', 2, (320, 320)), ('props', 4, (300, 270))]:
        records = list(manifest[group].items())
        rows = math.ceil(len(records)/columns)
        sheet = Image.new('RGB', (columns*tile[0], rows*tile[1]), '#202832')
        overhead_sheet = sheet.copy()
        d = ImageDraw.Draw(sheet)
        od = ImageDraw.Draw(overhead_sheet)
        for i, (name, record) in enumerate(records):
            v, _ = assemble(ROOT/record['folder'])
            front = render(v, tile[0], tile[1]-38, yaw=25)
            front.save(destination/(name+'.png'))
            overhead = overhead_preview(v, tile[0], tile[1]-38)
            overhead.save(destination/(name+'_overhead.png'))
            x, y = i%columns*tile[0], i//columns*tile[1]
            sheet.paste(front, (x, y))
            overhead_sheet.paste(overhead, (x, y))
            d.text((x+12, y+tile[1]-32), name.replace('_', ' '), font=font, fill='#f5e6c5')
            od.text((x+12, y+tile[1]-32), name.replace('_', ' '), font=font, fill='#f5e6c5')
        sheet.save(destination/(group+'_sheet.png'))
        overhead_sheet.save(destination/(group+'_overhead_sheet.png'))
    with Image.open(ROOT/'items/textures/pet_egg.png') as im:
        im.resize((256, 256), Image.Resampling.NEAREST).save(destination/'egg_icon.png')
    print('Scratch previews:', destination)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--validate', action='store_true', help='Only check existing output')
    parser.add_argument('--previews', type=Path, help='Optional scratch folder under /tmp')
    args = parser.parse_args()
    target = ROOT/'props/pets/manifest.json'
    if args.validate:
        manifest = json.loads(target.read_text())
    else:
        manifest = dict(pets={}, npcs={}, props={})
        for name, (height, gait) in SPECIES.items():
            pal, parts, limbs = pet(name)
            if name == 'lilyhop':
                vox = parts['body'].voxels()
                parts['body'] = {p: c for p, c in vox.items()
                                 if not (c == 'leaf' and p[2] < 1 and abs(p[0]) < (1-p[2])*.55)}
            flap_rate = {'duck': 2.2, 'cinderling': 5.5, 'hoot': 1.8, 'skywhale': 1.35}.get(name, 2.5)
            manifest['pets'][name] = export(ROOT/'creatures'/('pet_'+name), parts, pal, limbs,
                                          height=height, gait=gait, flap_rate=flap_rate)
            manifest['pets'][name]['gait'] = gait
        for name in ('caretaker', 'pet_storekeeper'):
            pal, parts, limbs = npc(name)
            parts = {n: speckle_eggs(p.voxels()) for n, p in parts.items()}
            manifest['npcs'][name] = export(ROOT/'creatures'/name, parts, pal, limbs, height=1.75 if name == 'caretaker' else 1.7)
        for name in [*PROPS, 'pet_egg']:
            vox, vs, collision, offset = prop(name)
            record = export(ROOT/'props/pets'/name, {'body': vox}, YARD, {}, voxel_size=vs)
            record['solid_size'] = collision
            record['solid_offset'] = offset or [0, collision[1]/2, 0]
            manifest['props'][name] = record
            (ROOT/record['folder']/'building.json').write_text(json.dumps(dict(
                solid_size=collision, solid_offset=record['solid_offset'],
                closed=any(collision)), indent=2)+'\n')
        # Also provide CreatureModel.new("pet_egg") for a hatching animation.
        vox, vs, _, _ = prop('pet_egg')
        export(ROOT/'creatures/pet_egg', {'body': vox}, YARD, {}, voxel_size=vs)
        icon()
        target.write_text(json.dumps(manifest, indent=2)+'\n')
    validate(manifest)
    if args.previews: previews(manifest, args.previews)


if __name__ == '__main__':
    main()
