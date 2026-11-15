#!/usr/bin/env python3
"""Surface dungeon art: the Sporewomb and Saltbone Wreck, in meters.

    python3 tools/make_dungeon_creatures_sporewomb_wreck.py
    python3 tools/make_dungeon_creatures_sporewomb_wreck.py mother_mycora
    python3 tools/make_dungeon_creatures_sporewomb_wreck.py --sheet /tmp/sporewreck.png

Only the fourteen folders in BUILDERS are written. Sheets and phase previews
are opt-in; put them in /tmp. No engine, import, or gameplay registration.
"""
import argparse
import json
import math
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont

import monster_studio as studio
from monster_studio import Model, ring, sheet
from make_creatures import fit_frame, write_vox
from preview_voxel_batch import ROOT, read_vox, render


# Six tactile materials and two unshaded lights in each dungeon's family.
FUNGUS = {
    'ivory': (222, 209, 166), 'amber': (192, 107, 43),
    'bark': (89, 65, 48), 'dark': (30, 57, 55),
    'moss': (98, 129, 72), 'rot': (121, 68, 125),
    'glow_teal': (93, 230, 196), 'glow_gold': (255, 204, 101),
}
WRECK = {
    'skin': (159, 186, 166), 'navy': (39, 65, 79),
    'bone': (221, 209, 172), 'rust': (160, 89, 55),
    'brass': (187, 145, 73), 'dark': (24, 35, 42),
    'glow_sea': (97, 230, 192), 'glow_lamp': (255, 206, 108),
}
HEIGHTS = dict(spore_puffling=.9, mycelid_crawler=.7, glowcap_sprite=1.,
               shroom_brute=2.4, spore_witch=2., bracket_warden=3.2,
               mother_mycora=5.5, bilge_rat=1., barnacle_crab=.9,
               drowned_deckhand=1.8, kelp_shambler=2.6, cannon_gunner=2.,
               first_mate_grisk=3.2, captain_saltmourn=5.)


def fungus(name, vs):
    return Model(name, vs, FUNGUS, rough=('bark', 'moss'))


def wreck(name, vs, **colors):
    return Model(name, vs, dict(WRECK, **colors), rough=('rust', 'bone'))


def eyes(p, y, z, gap, size, light, socket='dark'):
    for s in (-1, 1):
        p.ellipsoid((s * gap, y, z), (size * 1.55, size * 1.25, size), socket)
        p.ellipsoid((s * gap, y, z - size * .7), (size, size * .65, size * .6), light)


def cap(p, c, rx, rz, dome, top='amber', gill='dark', light='glow_teal', frills=0):
    """Low parasol: dark gill bed, separate radial lights, raised amber roof."""
    x, y, z = c
    p.ellipsoid((x, y, z), (rx, rx * .075, rz), gill)
    for i in range(18):
        a = i * math.tau / 18
        p.capsule((x + math.cos(a) * rx * .24, y - rx * .084, z + math.sin(a) * rz * .24),
                  (x + math.cos(a) * rx * .94, y - rx * .070, z + math.sin(a) * rz * .94),
                  rx * .018, rx * .024, light)
    p.ellipsoid((x, y + rx * .10, z), (rx * .98, dome, rz * .98), top)
    # A flat-bottomed dome leaves the gills exposed. A full ellipsoid would
    # grow down through the gill bed and bury the radial lights.
    lo, hi, sdf, index = p.shapes[-1]
    p.shapes[-1] = (lo, hi, lambda points: np.maximum(sdf(points), y + rx * .025 - points[..., 1]), index)
    for i in range(frills):
        a = i * math.tau / frills
        p.ellipsoid((x + rx * .89 * math.cos(a), y + .025, z + rz * .89 * math.sin(a)),
                    (rx * .15, rx * .065, rz * .15), 'ivory')


def spots(p, c, rx, rz, dome, color='ivory'):
    x, y, z = c
    for u, v, r in ((-.45, -.3, .13), (.22, -.50, .10), (.48, .10, .16),
                    (-.20, .35, .16), (-.68, .23, .08)):
        yy = y + rx * .10 + dome * math.sqrt(1 - u * u - v * v)
        p.ellipsoid((x + rx * u, yy, z + rz * v), (rx * r, rx * .032, rz * r), color)


def legs(m, hip, length, spread, radius, skin, foot=None):
    p = m.part('leg')
    p.capsule((0, -.03, 0), (0, -length + radius * .6, 0), radius, radius * .78, skin)
    p.ellipsoid((0, -length + radius * .40, -radius * .55),
                (radius * 1.15, radius * .4, radius * 1.65), foot or skin)
    for s, side in ((-1, 'l'), (1, 'r')):
        m.joint('leg_' + side, 'leg', (s * spread, hip, 0), 'leg', -s)


def simple_arm(m, name, at, length, radius, cloth, hand, throws=False):
    a = m.part(name)
    a.capsule((0, 0, 0), (0, -length * .76, -.025), radius, radius * .85, cloth)
    a.ellipsoid((0, -length, -.04), (radius * .85, radius * 1.1, radius * .85), hand)
    m.joint(name, name, at, 'arm', 1 if name.endswith('_l') else -1, throws=throws)
    return a


def lantern(p, c, r, metal='brass', light='glow_lamp'):
    x, y, z = c
    p.ellipsoid(c, (r * .77, r * 1.12, r * .77), light)
    for yy in (y - r * 1.18, y + r * 1.18):
        p.box((x - r, yy - r * .13, z - r), (x + r, yy + r * .13, z + r), metal)
    for dx, dz in ((-1, -1), (1, -1), (-1, 1), (1, 1)):
        p.capsule((x + dx * r * .75, y - r, z + dz * r * .75),
                  (x + dx * r * .75, y + r, z + dz * r * .75), r * .12, r * .12, metal)
    ring(p, (x, y + r * 1.5, z), r * .43, r * .12, metal, axis='z', n=12)


def barnacles(p, points, color='bone', hole='dark'):
    for x, y, z, r in points:
        p.ellipsoid((x, y, z), (r, r * .7, r * .8), color)
        p.ellipsoid((x, y + r * .50, z - r * .30), (r * .42, r * .24, r * .43), hole)


def cutlass(p, grip, length, metal='bone', guard='brass', direction=1):
    x, y, z = grip
    p.capsule((x, y + .10 * length, z), (x, y - .17 * length, z), .055 * length, .055 * length, 'dark')
    p.chain([(x - .14 * length, y + .06 * length, z),
             (x - .21 * length, y - .13 * length, z),
             (x, y - .25 * length, z), (x + .18 * length, y - .17 * length, z)],
            .045 * length, .035 * length, guard)
    p.chain([(x, y - .19 * length, z), (x, y - .64 * length, z - .12 * length),
             (x + direction * .13 * length, y - .92 * length, z - .24 * length),
             (x + direction * .23 * length, y - length, z - .28 * length)],
            .085 * length, .018 * length, metal)


def spore_puffling():
    """A soft bread-colored puffball, not a miniature mushroom soldier."""
    m = fungus('spore_puffling', .045)
    b = m.part('body')
    b.ellipsoid((0, .52, .02), (.36, .36, .32), 'ivory')
    for x, y, z, r in ((-.20, .77, -.09, .07), (.08, .84, .03, .085),
                        (.25, .66, .05, .065), (-.12, .78, .21, .06)):
        b.ellipsoid((x, y, z), (r, r * .37, r), 'amber')
    b.ellipsoid((0, .43, -.287), (.13, .115, .08), 'amber')
    b.ellipsoid((0, .44, -.346), (.07, .075, .028), 'dark')
    eyes(b, .62, -.27, .145, .038, 'glow_gold')
    for s in (-1, 1):
        b.capsule((s * .29, .47, -.06), (s * .40, .36, -.10), .065, .04, 'ivory')
    legs(m, .22, .22, .14, .085, 'bark', 'ivory')
    m.hand = (0, .44, -.38)
    m.extra = dict(waddle=.65, bob=.01)
    return m


def mycelid_crawler():
    """Seven woven knots and twelve independently scuttling root legs."""
    m = fungus('mycelid_crawler', .04)
    b = m.part('body')
    for i in range(7):
        z = -.52 + i * .18
        yy = .40 + .06 * math.sin(i * .7)
        b.ellipsoid((0, yy, z), (.20, .17, .15), 'ivory')
        b.ellipsoid((0, yy + .15, z + .065), (.10, .025, .035), 'glow_teal')
        for s in (-1, 1):
            b.chain([(s * .11, yy + .09, z - .08), (s * .21, yy, z),
                     (s * .13, yy - .09, z + .09)], .037, .025, 'bark')
    b.ellipsoid((0, .42, -.64), (.22, .18, .15), 'ivory')
    eyes(b, .48, -.755, .105, .037, 'glow_teal')
    for s in (-1, 1):
        b.chain([(s * .10, .55, -.65), (s * .20, .66, -.71), (s * .28, .67, -.74)], .025, .012, 'ivory')
        p = m.part('leg_' + str(s))
        p.chain([(0, 0, 0), (s * .17, -.06, .03), (s * .26, -.25, -.01),
                 (s * .32, -.28, -.07)], .04, .018, 'ivory')
        for i in range(6):
            m.joint(f'leg_{s}_{i}', 'leg_' + str(s), (s * .15, .28, -.49 + i * .20),
                    'leg', s * (-1 if i % 2 else 1), amount=.65)
    m.hand = (0, .43, -.79)
    m.extra = dict(waddle=.10)
    return m


def glowcap_sprite():
    """A hovering teal parasol with pale moth wings and luminous gill veins."""
    m = fungus('glowcap_sprite', .045)
    m.palette['moss'] = (44, 133, 128)
    b = m.part('body')
    b.ellipsoid((0, .38, .02), (.12, .24, .11), 'ivory')
    b.ellipsoid((0, .54, -.14), (.15, .15, .13), 'ivory')
    cap(b, (0, .66, 0), .34, .27, .18, top='moss')
    spots(b, (0, .66, 0), .34, .27, .18, 'glow_teal')
    eyes(b, .53, -.27, .065, .027, 'glow_gold')
    for s in (-1, 1):
        b.chain([(s * .07, .24, 0), (s * .12, .13, -.03), (s * .10, .08, -.07)], .03, .02, 'bark')
        w = m.part('wing_' + str(s))
        for cx, yy, rx, ry in ((.31, .16, .28, .22), (.25, -.17, .23, .18)):
            w.ellipsoid((s * cx, yy, .025), (rx, ry, .055), 'dark')
            w.ellipsoid((s * cx, yy, -.015), (rx * .87, ry * .83, .045), 'ivory')
            for j in (-1, 0, 1):
                w.capsule((0, 0, -.06), (s * (cx + .12), yy + j * .07, -.06), .015, .014, 'glow_teal')
        m.joint('wing_' + ('l' if s < 0 else 'r'), 'wing_' + str(s), (s * .09, .46, .09), 'wing', -s)
    simple_arm(m, 'arm_l', (-.12, .47, -.02), .20, .032, 'ivory', 'ivory')
    a = simple_arm(m, 'arm_r', (.12, .47, -.02), .20, .032, 'ivory', 'ivory', True)
    a.ellipsoid((0, -.22, -.06), (.05, .05, .05), 'glow_gold')
    m.hand = (0, -.22, -.06)
    m.extra = dict(hover=.10, bob=.035, waddle=0, flap_rate=5.5, hand_limb='arm_r')
    return m


def shroom_brute():
    """Low knuckles, a bifurcated bracket head, and a knotted root cudgel."""
    m = fungus('shroom_brute', .075)
    b = m.part('body')
    b.ellipsoid((0, 1.18, .09), (.51, .66, .38), 'moss')
    b.ellipsoid((0, 1.53, -.04), (.63, .36, .40), 'bark')
    b.ellipsoid((0, 1.08, -.28), (.37, .39, .17), 'ivory')
    h = m.part('head')
    h.ellipsoid((0, .05, -.20), (.29, .29, .25), 'ivory')
    for s in (-1, 1):
        cap(h, (s * .28, .27, .02), .38, .39, .27)
        h.capsule((s * .12, .48, -.22), (s * .40, .57, .01), .05, .055, 'ivory')
    h.chain([(0, .35, -.36), (0, .52, -.16), (0, .55, .20)], .038, .035, 'dark')
    eyes(h, .04, -.44, .135, .052, 'glow_teal')
    h.box((-.13, -.13, -.46), (.13, -.07, -.40), 'dark')
    m.joint('head', 'head', (0, 1.74, -.13), 'head')
    legs(m, .62, .62, .29, .19, 'bark', 'moss')
    simple_arm(m, 'arm_l', (-.63, 1.57, .02), .85, .19, 'moss', 'ivory')
    a = simple_arm(m, 'arm_r', (.63, 1.57, .02), .85, .19, 'moss', 'ivory', True)
    a.chain([(0, -.73, -.06), (.14, -1.01, -.17), (.25, -1.24, -.26)], .10, .22, 'bark')
    a.ellipsoid((.23, -1.20, -.25), (.25, .29, .23), 'bark')
    for dx in (-.12, .12):
        a.capsule((.23, -1.22, -.30), (.23 + dx, -1.49, -.40), .07, .035, 'ivory')
    m.hand = (.25, -1.25, -.30)
    m.extra = dict(hand_limb='arm_r', waddle=.24)
    return m


def spore_witch():
    """A stooped cap-hatted crone with a spore lantern and mycelium shawl."""
    m = fungus('spore_witch', .065)
    b = m.part('body')
    b.ellipsoid((0, .83, .13), (.32, .56, .26), 'bark')
    b.ellipsoid((0, 1.26, .12), (.37, .31, .30), 'moss')
    for i in range(9):
        a = i * math.tau / 9
        b.chain([(.27 * math.cos(a), 1.25, .12 + .22 * math.sin(a)),
                 (.34 * math.cos(a), .74, .12 + .29 * math.sin(a)),
                 (.37 * math.cos(a), .30 + .05 * (i % 3), .14 + .31 * math.sin(a))], .055, .027, 'ivory')
    h = m.part('head')
    h.ellipsoid((0, -.01, -.20), (.17, .21, .18), 'ivory')
    h.capsule((0, -.03, -.34), (0, -.11, -.49), .065, .04, 'ivory')
    cap(h, (0, .19, .02), .49, .39, .27, frills=12)
    h.chain([(0, .28, .08), (.08, .43, .12), (.22, .50, .19)], .20, .045, 'amber')
    spots(h, (0, .19, .02), .49, .39, .27)
    eyes(h, .02, -.37, .085, .037, 'glow_teal')
    m.joint('head', 'head', (0, 1.45, -.19), 'head')
    legs(m, .35, .35, .16, .09, 'bark')
    simple_arm(m, 'arm_l', (-.34, 1.28, .02), .51, .09, 'moss', 'ivory')
    a = simple_arm(m, 'arm_r', (.34, 1.28, -.03), .51, .09, 'moss', 'ivory', True)
    a.chain([(0, -.43, -.06), (.18, -.45, -.14), (.22, -.26, -.19)], .035, .025, 'bark')
    a.capsule((.22, -.26, -.19), (.22, -.53, -.19), .014, .014, 'ivory')
    lantern(a, (.22, -.69, -.19), .12, 'bark', 'glow_gold')
    for dx, yy in ((-.08, -.62), (.07, -.70), (.0, -.80)):
        a.ellipsoid((.22 + dx, yy, -.29), (.025, .025, .025), 'glow_teal')
    m.hand = (.22, -.69, -.19)
    m.extra = dict(hand_limb='arm_r', waddle=.15, bob=.015)
    return m


def bracket_warden():
    """A walking old stump, stepped shelves and a deep kindly tree face."""
    m = fungus('bracket_warden', .075)
    b = m.part('body')
    b.capsule((0, .72, .05), (0, 2.25, .05), .62, .54, 'bark')
    for s in (-1, 1):
        b.chain([(s * .35, 2.3, -.35), (s * .43, 1.5, -.48), (s * .53, .60, -.39)], .075, .035, 'ivory')
    for x, y, z, r in ((-.48, 1.1, -.05, .46), (.46, 1.65, .06, .49),
                        (-.48, 2.20, .02, .51), (.1, 1.3, .53, .45)):
        cap(b, (x, y, z), r, r * .75, .13)
    h = m.part('head')
    h.ellipsoid((0, 0, -.04), (.39, .38, .34), 'bark')
    cap(h, (0, .25, .08), .62, .49, .25, frills=14)
    h.ellipsoid((0, -.08, -.32), (.25, .24, .08), 'dark')
    eyes(h, .02, -.39, .15, .058, 'glow_teal')
    for s in (-1, 1):
        h.capsule((s * .08, -.11, -.39), (s * .12, -.25, -.40), .05, .025, 'ivory')
    m.joint('head', 'head', (0, 2.64, -.09), 'head')
    legs(m, .65, .65, .38, .24, 'bark', 'moss')
    for s, side in ((-1, 'l'), (1, 'r')):
        a = simple_arm(m, 'arm_' + side, (s * .72, 2.23, .01), 1.22, .25, 'bark', 'bark', s > 0)
        a.ellipsoid((s * .04, -.30, -.03), (.30, .35, .29), 'moss')
        cap(a, (s * .15, -.61, .08), .32, .30, .10)
        for dx in (-.16, 0, .16):
            a.capsule((dx, -1.18, -.12), (dx * 1.1, -1.46, -.23), .075, .04, 'ivory')
    m.hand = (0, -1.35, -.23)
    m.extra = dict(hand_limb='arm_r', waddle=.12)
    return m


class CutPart:
    """Remove deliberate tears after the same underlying phase sculpture."""
    def __init__(self, part, cuts):
        self.part, self.cuts = part, cuts

    def voxels(self, hollow_above=6000):
        vs = 1 / self.part.scale
        return {v: c for v, c in self.part.voxels(hollow_above=hollow_above).items()
                if not any(all(lo[k] <= (v[k] + .5) * vs <= hi[k] for k in range(3))
                           for lo, hi in self.cuts)}


class GroundedPart:
    """Trim primitive raster padding at the foot's actual joint-relative floor."""
    def __init__(self, part, floor):
        self.part, self.floor = part, floor

    def voxels(self, hollow_above=6000):
        return {v: c for v, c in self.part.voxels(hollow_above=hollow_above).items()
                if v[1] >= self.floor}


def mother_mycora():
    """An ivory root matriarch beneath a scalloped amber parasol crown."""
    m = fungus('mother_mycora', .085)

    def body(name, form):
        b = m.part(name)
        cloth = 'rot' if form == 'rot' else 'ivory'
        b.capsule((0, 1.10, .10), (0, 3.55, .10), .66, .42, cloth)
        b.ellipsoid((0, .78, .15), (1.03, .63, .74), 'bark')
        # Draped bundles, never a featureless cone. Front threads frame a
        # dark central opening; the roots spread low, not a wide upper torso.
        for i in range(14):
            a = i * math.tau / 14
            xx, zz = math.cos(a), math.sin(a)
            b.chain([(xx * .35, 3.42, .10 + zz * .32),
                     (xx * .48, 2.50, .10 + zz * .45),
                     (xx * .75, 1.36, .13 + zz * .63),
                     (xx * 1.02, .42 + .12 * (i % 3), .16 + zz * .79)],
                    .15, .065, cloth)
            if i % 3 == 0:
                b.chain([(xx * .52, 2.45, .10 + zz * .48),
                         (xx * .77, 1.35, .13 + zz * .68),
                         (xx * 1.06, .50, .16 + zz * .82)], .028, .025,
                        'glow_teal' if form == 'bloom' else 'amber')
        b.ellipsoid((0, 3.40, 0), (.63, .30, .37), cloth)
        # Amber spore sacs are visible from the back and above the shoulders.
        for x, y, z, r in ((-.42, 3.26, .47, .29), (.40, 3.10, .48, .33), (0, 2.84, .61, .27)):
            b.ellipsoid((x, y, z), (r, r * 1.28, r), 'rot' if form == 'rot' else 'amber')
            b.ellipsoid((x, y + r * .5, z + r * .8), (r * .28, r * .25, r * .17), 'glow_gold')
        if form == 'bloom':
            for s in (-1, 1):
                for i in range(3):
                    cap(b, (s * (.53 + .13 * i), 2.6 - i * .63, -.40), .26, .22, .12,
                        top='ivory', light='glow_gold', frills=6)
        if form == 'rot':
            for s in (-1, 1):
                b.chain([(s * .2, 3.45, -.27), (s * .32, 2.78, -.35), (s * .45, 2.12, -.45)],
                        .05, .03, 'dark')

    def head(name, form):
        h = m.part(name)
        h.capsule((0, -.20, .02), (0, .42, .06), .25, .30, 'rot' if form == 'rot' else 'ivory')
        # Face sits well forward and below the brim, visible to the camera.
        h.capsule((0, -.02, -.05), (0, -.02, -.58), .22, .28, 'ivory')
        h.ellipsoid((0, -.02, -.66), (.36, .32, .27), 'dark')
        h.ellipsoid((0, -.035, -.82), (.28, .25, .16), 'ivory')
        eyes(h, .04, -.96, .14, .063, 'glow_gold')
        for s in (-1, 1):
            h.capsule((s * .06, .16, -.98), (s * .23, .18, -.92), .035, .025, 'bark')
        h.ellipsoid((0, -.07, -.99), (.055, .075, .04), 'amber')
        width = 2.28 if form == 'bloom' else 2.02
        cap(h, (0, .68, .30), width, 1.45, .48,
            top='rot' if form == 'rot' else 'amber',
            gill='glow_teal' if form == 'bloom' else 'dark', frills=28)
        spots(h, (0, .68, .30), width, 1.45, .48, 'rot' if form == 'rot' else 'ivory')
        # Crown is a little grove of mushrooms rather than spikes.
        for x, yy, z, r in ((-.42, 1.23, .25, .23), (.26, 1.27, .11, .28), (.64, 1.14, .48, .18)):
            h.capsule((x, yy - .14, z), (x, yy + .05, z), .045, .04, 'ivory')
            cap(h, (x, yy + .04, z), r, r * .8, .09,
                top='ivory' if form == 'bloom' else 'amber', light='glow_gold')
        if form == 'bloom':
            for i in range(7):
                a = i * math.tau / 7
                x, z = math.cos(a) * 1.85, .3 + math.sin(a) * 1.20
                cap(h, (x, 1.02, z), .25, .21, .11, top='ivory', light='glow_gold', frills=6)
        if form == 'rot':
            h.chain([(-.9, .99, -.68), (-.72, .94, -.89), (-.6, .72, -1.18)], .055, .035, 'dark')
            m.parts[name] = CutPart(h, [((1.05, .36, -.95), (2.6, 1.4, -.48)),
                                       ((-1.5, .32, .85), (-.95, .9, 2.))])

    for form in ('base', 'bloom', 'rot'):
        body('body' if form == 'base' else 'body_' + form, form)
        head('head' if form == 'base' else 'head_' + form, form)
    m.joint('head', 'head', (0, 4.03, -.12), 'head')
    j = m.part('jaw')
    j.ellipsoid((0, -.035, -.09), (.23, .095, .16), 'ivory')
    j.capsule((-.11, .035, -.18), (.11, .035, -.18), .025, .025, 'bark')
    m.joint('jaw', 'jaw', (0, -.23, -.77), 'jaw', parent_limb='head')
    # Long angular arms with separate root fingers; no oversized gauntlets.
    for s, side in ((-1, 'l'), (1, 'r')):
        a = m.part('arm_' + side)
        a.chain([(0, 0, 0), (s * .20, -.67, .04), (s * .16, -1.28, -.18)], .11, .075, 'ivory')
        for k in (-1, 0, 1):
            a.chain([(s * .16 + k * .07, -1.23, -.18),
                     (s * .21 + k * .10, -1.53 - .08 * (k == 0), -.27),
                     (s * .23 + k * .10, -1.64, -.42)], .04, .02, 'bark')
        a.ellipsoid((s * .16, -1.30, -.24), (.07, .08, .05), 'glow_teal')
        m.joint('arm_' + side, 'arm_' + side, (s * .79, 3.42, -.04), 'arm', -s, throws=s > 0)
    legs(m, .42, .42, .54, .21, 'bark', 'ivory')
    for s, side in ((-1, 'l'), (1, 'r')):
        c = m.part('cloth_' + side)
        c.chain([(0, 0, 0), (s * .19, -.85, .08), (s * .37, -1.58, .20)], .14, .045, 'ivory')
        m.joint('cloth_' + side, 'cloth_' + side, (s * .58, 2.15, .52), 'cloth', -s)
    m.hand = (.16, -1.40, -.30)
    m.extra = dict(animation_style='cantor', hand_limb='arm_r', glow_strength=1.2,
                   waddle=.07, bob=.018,
                   variants={v: {'body': 'body_' + v, 'head': 'head_' + v} for v in ('bloom', 'rot')})
    return m


def bilge_rat():
    """A scruffy upright dock rat with a red bandana and an iron hook."""
    m = wreck('bilge_rat', .045, skin=(112, 108, 91), bone=(185, 170, 133))
    b = m.part('body')
    b.ellipsoid((0, .43, .06), (.25, .29, .23), 'skin')
    b.ellipsoid((0, .38, -.14), (.17, .19, .08), 'bone')
    for x, y, z in ((-.20, .55, .13), (.20, .51, .12), (-.12, .60, .18), (.13, .33, .21)):
        b.capsule((x, y, z), (x * 1.25, y + .10, z + .06), .045, .012, 'skin')
    h = m.part('head')
    h.ellipsoid((0, 0, -.015), (.21, .19, .19), 'skin')
    h.ellipsoid((0, -.08, -.22), (.14, .10, .20), 'bone')
    h.ellipsoid((0, -.05, -.40), (.075, .055, .045), 'dark')
    for s in (-1, 1):
        h.ellipsoid((s * .19, .15, .02), (.105, .12, .055), 'skin')
        h.ellipsoid((s * .19, .15, -.025), (.063, .075, .025), 'rust')
        h.capsule((s * .09, -.10, -.28), (s * .30, -.07, -.35), .014, .01, 'bone')
    eyes(h, .03, -.17, .13, .035, 'glow_lamp')
    h.ellipsoid((0, .095, .01), (.215, .055, .18), 'rust')
    h.chain([(.18, .1, .03), (.30, .03, .08), (.33, -.07, .13)], .045, .02, 'rust')
    for dx in (-.035, .035):
        h.box((dx - .018, -.18, -.32), (dx + .018, -.11, -.27), 'bone')
    m.joint('head', 'head', (0, .72, -.10), 'head')
    legs(m, .20, .20, .13, .075, 'skin', 'bone')
    simple_arm(m, 'arm_l', (-.23, .56, -.01), .27, .055, 'skin', 'bone')
    a = simple_arm(m, 'arm_r', (.23, .56, -.01), .24, .06, 'skin', 'rust', True)
    a.chain([(0, -.25, -.04), (.02, -.36, -.06), (.12, -.40, -.08),
             (.18, -.34, -.08), (.14, -.28, -.09)], .035, .016, 'rust')
    t = m.part('tail')
    t.chain([(0, 0, 0), (.18, -.04, .20), (.35, -.10, .38), (.40, -.02, .55)], .055, .018, 'rust')
    m.joint('tail', 'tail', (0, .25, .23), 'tail')
    m.hand = (.13, -.34, -.09)
    m.extra = dict(hand_limb='arm_r', waddle=.30)
    return m


def barnacle_crab():
    """A squat crab sheltering under a broken, barnacled hull panel."""
    m = wreck('barnacle_crab', .045)
    b = m.part('body')
    b.ellipsoid((0, .43, .04), (.44, .23, .35), 'rust')
    b.ellipsoid((0, .34, -.10), (.37, .12, .29), 'skin')
    for i, x in enumerate((-.24, 0, .24)):
        b.box((x - .105, .57 + .04 * (i % 2), -.16), (x + .105, .77 + .05 * (i % 2), .39), 'navy')
        for z in (-.04, .27):
            b.ellipsoid((x, .79 + .04 * (i % 2), z), (.025, .025, .025), 'brass')
    b.capsule((-.38, .73, .16), (.38, .73, .16), .037, .037, 'brass')
    barnacles(b, [(-.24, .77, -.07, .09), (.18, .81, .17, .085), (.30, .67, .29, .09),
                  (-.33, .61, .26, .08), (.02, .82, -.05, .06)])
    for s in (-1, 1):
        b.capsule((s * .18, .46, -.22), (s * .22, .67, -.33), .045, .035, 'rust')
        b.ellipsoid((s * .22, .67, -.35), (.055, .055, .045), 'dark')
        b.ellipsoid((s * .22, .68, -.39), (.027, .027, .02), 'glow_lamp')
        l = m.part('legs_' + str(s))
        l.chain([(0, 0, 0), (s * .20, .01, .04), (s * .31, -.23, .06),
                 (s * .33, -.29, -.01)], .05, .02, 'rust')
        for i in range(3):
            m.joint(f'leg_{s}_{i}', 'legs_' + str(s), (s * .35, .29, -.16 + i * .20), 'leg',
                    s * (-1 if i % 2 else 1), amount=.65)
        a = m.part('arm_' + ('l' if s < 0 else 'r'))
        a.chain([(0, 0, 0), (s * .12, -.06, -.18), (s * .16, -.06, -.33)], .075, .10, 'rust')
        a.ellipsoid((s * .16, -.05, -.36), (.15, .12, .14), 'rust')
        for dx in (-.08, .08):
            a.chain([(s * .16 + dx, -.05, -.39), (s * .16 + dx * 1.4, -.05, -.56),
                     (s * .16 + dx * .5, -.05, -.63)], .055, .024, 'bone')
        side = 'l' if s < 0 else 'r'
        m.joint('arm_' + side, 'arm_' + side, (s * .37, .40, -.16), 'arm', -s, throws=s > 0)
    m.hand = (.16, -.05, -.60)
    m.extra = dict(hand_limb='arm_r', waddle=.12)
    return m


def drowned_deckhand():
    """A broad striped sailor: wet weed hair, bare feet, nicked cutlass."""
    m = wreck('drowned_deckhand', .065)
    b = m.part('body')
    b.ellipsoid((0, 1.02, .025), (.34, .43, .27), 'bone')
    for y, width, front in ((.77, .27, -.21), (.96, .33, -.25), (1.15, .32, -.24), (1.32, .23, -.18)):
        b.box((-width, y, front), (width, y + .075, .19), 'navy')
    b.ellipsoid((0, .62, .035), (.28, .19, .22), 'navy')
    ring(b, (0, .69, .02), .28, .035, 'rust', n=24)
    h = m.part('head')
    h.ellipsoid((0, -.01, 0), (.23, .23, .21), 'skin')
    h.ellipsoid((0, -.08, -.18), (.16, .13, .09), 'skin')
    eyes(h, .08, -.24, .10, .037, 'glow_sea')
    h.box((-.08, -.14, -.25), (.08, -.10, -.20), 'dark')
    for i in range(7):
        a = i * math.pi / 6
        x, z = .19 * math.cos(a), .16 * math.sin(a)
        h.chain([(x, .17, z), (x * 1.1, -.02, z + .06),
                 (x * 1.18, -.25 - .05 * (i % 2), z + .11)], .045, .025, 'navy')
    m.joint('head', 'head', (0, 1.55, -.035), 'head')
    legs(m, .55, .55, .17, .11, 'navy', 'skin')
    a = simple_arm(m, 'arm_l', (-.34, 1.30, 0), .50, .105, 'bone', 'skin')
    a.capsule((0, -.12, 0), (0, -.20, 0), .11, .11, 'navy')
    a = simple_arm(m, 'arm_r', (.43, 1.30, 0), .50, .105, 'bone', 'skin', True)
    a.capsule((0, -.12, 0), (0, -.20, 0), .11, .11, 'navy')
    cutlass(a, (0, -.48, -.09), .67)
    m.hand = (.08, -1.0, -.24)
    m.extra = dict(hand_limb='arm_r', waddle=.25)
    return m


def kelp_shambler():
    """Water-heavy hanging kelp blades surrounding two warm lantern eyes."""
    m = wreck('kelp_shambler', .075, skin=(65, 110, 73), bone=(137, 155, 86), rust=(94, 81, 48))
    b = m.part('body')
    b.ellipsoid((0, 1.22, .09), (.57, .92, .43), 'navy')
    b.ellipsoid((0, 1.98, .05), (.46, .45, .36), 'skin')
    for i in range(13):
        a = i * math.tau / 13
        x, z = math.cos(a), math.sin(a)
        color = 'bone' if i % 4 == 0 else 'skin'
        b.chain([(x * .28, 2.24 - .08 * (i % 3), .07 + z * .27),
                 (x * .53, 1.68, .09 + z * .41),
                 (x * .61, .95, .10 + z * .48),
                 (x * .65, .25 + .13 * (i % 3), .13 + z * .52)], .14, .045, color)
    h = m.part('head')
    h.ellipsoid((0, .02, -.03), (.35, .27, .24), 'navy')
    eyes(h, .06, -.25, .155, .076, 'glow_lamp')
    for s in (-1, 1):
        h.chain([(s * .16, .22, .04), (s * .23, .48, .08), (s * .36, .50, .04)], .08, .03, 'skin')
    m.joint('head', 'head', (0, 2.03, -.21), 'head')
    legs(m, .48, .48, .28, .18, 'rust', 'skin')
    for s, side in ((-1, 'l'), (1, 'r')):
        a = m.part('arm_' + side)
        a.chain([(0, 0, 0), (s * .10, -.46, .06), (s * .06, -.95, -.04)], .17, .12, 'skin')
        for k in (-1, 0, 1):
            a.chain([(k * .09, -.63, -.10), (k * .13, -1.10, -.15),
                     (k * .17, -1.32 + .08 * (k % 2), -.25)], .07, .025, 'bone' if k == 0 else 'skin')
        m.joint('arm_' + side, 'arm_' + side, (s * .55, 1.83, .03), 'arm', -s, throws=s > 0)
    for i, (x, y, z) in enumerate(((-.38, 1.80, .34), (.39, 1.93, .31), (0, 2.17, .39))):
        p = m.part('kelp_' + str(i))
        p.chain([(0, 0, 0), (.10, -.62, .10), (-.03, -1.18, .16), (.08, -1.56, .10)], .105, .027, 'skin')
        m.joint('kelp_' + str(i), 'kelp_' + str(i), (x, y, z), 'sway', (-1) ** i)
    m.hand = (0, -1.14, -.19)
    m.extra = dict(hand_limb='arm_r', waddle=.17, bob=.025)
    return m


def cannon_gunner():
    """A stocky powder sailor carrying a short bronze shoulder cannon."""
    m = wreck('cannon_gunner', .065)
    b = m.part('body')
    b.ellipsoid((0, 1.00, .06), (.37, .45, .28), 'navy')
    b.ellipsoid((0, 1.14, -.18), (.24, .31, .13), 'skin')
    b.capsule((-.25, 1.36, -.20), (.25, .72, -.24), .06, .06, 'rust')
    for x, y in ((-.14, 1.18), (0, 1.02), (.13, .84)):
        b.ellipsoid((x, y, -.31), (.05, .055, .03), 'brass')
    b.ellipsoid((-.29, .76, .18), (.14, .18, .16), 'dark')
    h = m.part('head')
    h.ellipsoid((0, 0, 0), (.22, .23, .20), 'skin')
    eyes(h, .025, -.19, .105, .039, 'glow_sea')
    h.ellipsoid((0, -.13, -.08), (.21, .10, .17), 'dark')
    h.ellipsoid((0, .18, .02), (.26, .08, .22), 'rust')
    h.chain([(-.05, .23, .04), (-.18, .29, .05), (-.28, .24, .08)], .10, .035, 'rust')
    m.joint('head', 'head', (-.10, 1.60, -.05), 'head')
    legs(m, .59, .59, .20, .13, 'navy', 'dark')
    a = simple_arm(m, 'arm_l', (-.37, 1.35, 0), .55, .105, 'navy', 'skin')
    a.capsule((0, -.40, -.05), (-.10, -.42, -.20), .035, .025, 'rust')
    a.ellipsoid((-.10, -.42, -.22), (.035, .035, .035), 'glow_lamp')
    a = simple_arm(m, 'arm_r', (.39, 1.40, 0), .48, .13, 'navy', 'skin', True)
    # Breech rests on the shoulder. The flared muzzle tilts forward/down,
    # so the existing arm raise also brings the cannon up toward its target.
    a.capsule((0, .27, .16), (0, -.32, -.43), .21, .24, 'brass')
    for y, z in ((.20, .09), (-.08, -.19), (-.32, -.43)):
        ring(a, (0, y, z), .23, .035, 'rust', axis='z', n=24)
    a.ellipsoid((0, -.35, -.57), (.16, .15, .035), 'dark')
    a.ellipsoid((0, -.35, -.60), (.055, .06, .02), 'glow_lamp')
    a.ellipsoid((0, .27, .24), (.09, .09, .11), 'brass')
    m.hand = (0, -.35, -.62)
    m.extra = dict(hand_limb='arm_r', waddle=.17)
    return m


def first_mate_grisk():
    """A crab-backed first mate, one great pincer and a salvaged anchor."""
    m = wreck('first_mate_grisk', .075)
    b = m.part('body')
    b.ellipsoid((0, 1.66, .13), (.72, .72, .47), 'rust')
    b.ellipsoid((0, 1.70, .37), (.79, .72, .32), 'rust')
    for i, y in enumerate((1.24, 1.49, 1.74, 1.99)):
        b.ellipsoid((0, y, -.24), (.53 - i * .035, .17, .22), 'skin')
    b.capsule((-.49, 2.23, -.30), (.43, 1.05, -.42), .075, .075, 'navy')
    ring(b, (0, 1.12, .05), .58, .07, 'navy', n=24)
    b.box((-.14, 1.04, -.56), (.14, 1.23, -.48), 'brass')
    for s in (-1, 1):
        for z in (.18, .45):
            b.capsule((s * .60, 2.04, z), (s * .87, 2.34, z + .05), .11, .025, 'bone')
    barnacles(b, [(-.57, 2.16, .40, .15), (.55, 1.78, .63, .13),
                  (-.34, 1.28, .62, .12), (.65, 2.16, .25, .11)])
    h = m.part('head')
    h.ellipsoid((0, -.02, 0), (.36, .29, .29), 'rust')
    for s in (-1, 1):
        h.capsule((s * .19, .12, -.11), (s * .26, .40, -.17), .07, .06, 'skin')
        h.ellipsoid((s * .26, .40, -.20), (.085, .07, .05), 'dark')
        h.ellipsoid((s * .26, .40, -.24), (.046, .04, .025), 'glow_sea')
    h.ellipsoid((0, .13, .06), (.38, .08, .27), 'navy')
    h.ellipsoid((-.12, .27, .09), (.25, .16, .22), 'navy')
    h.ellipsoid((-.16, .31, -.11), (.06, .06, .03), 'brass')
    for s in (-1, 1):
        h.chain([(s * .23, -.13, -.18), (s * .15, -.24, -.34), (s * .04, -.16, -.37)], .08, .04, 'bone')
    m.joint('head', 'head', (0, 2.66, -.11), 'head')
    legs(m, .90, .90, .39, .23, 'rust', 'navy')
    a = m.part('arm_l')
    a.chain([(0, 0, 0), (-.17, -.53, -.05), (-.14, -.94, -.20)], .23, .26, 'rust')
    a.ellipsoid((-.14, -1.01, -.22), (.36, .38, .28), 'rust')
    for s in (-1, 1):
        a.chain([(-.14 + s * .20, -1.13, -.27), (-.14 + s * .27, -1.48, -.36),
                 (-.14 + s * .10, -1.61, -.39)], .13, .055, 'bone')
    m.joint('arm_l', 'arm_l', (-.78, 2.23, .02), 'arm', 1, throws=False)
    a = simple_arm(m, 'arm_r', (.78, 2.23, .02), .92, .23, 'rust', 'skin', True)
    # Anchor shaft, stock, ring and broad curved flukes, all on the arm.
    a.capsule((.10, -.50, -.19), (.10, -1.84, -.19), .08, .095, 'navy')
    ring(a, (.10, -.37, -.19), .15, .045, 'navy', axis='z', n=20)
    a.capsule((-.26, -.72, -.19), (.46, -.72, -.19), .065, .065, 'navy')
    for s in (-1, 1):
        a.chain([(.10, -1.75, -.19), (.10 + s * .37, -1.76, -.19),
                 (.10 + s * .54, -1.49, -.19)], .095, .065, 'navy')
        a.triangle((.10 + s * .35, -1.56, -.19), (.10 + s * .61, -1.35, -.19),
                   (.10 + s * .57, -1.71, -.19), .13, 'rust')
    barnacles(a, [(.10, -1.71, -.24, .09), (.46, -1.67, -.24, .08)])
    m.hand = (.10, -1.71, -.19)
    m.extra = dict(hand_limb='arm_r', waddle=.17)
    return m


def captain_saltmourn():
    """A drowned admiral: enormous tricorn, warm lantern, curled sea beard."""
    # Abyss uses the same six materials, exchanging coral for spreading bone.
    m = wreck('captain_saltmourn', .08)

    def body(name, form):
        b = m.part(name)
        coat = 'navy'
        b.ellipsoid((0, 2.64, .07), (.69, .80, .48), 'navy')
        b.ellipsoid((0, 2.67, -.33), (.44, .61, .20), 'skin')
        # Split front with overlapping naval lapels, broad weight at the hem.
        for s in (-1, 1):
            b.chain([(s * .41, 3.38, -.25), (s * .51, 2.65, -.40),
                     (s * .67, 1.65, -.29), (s * .91, .67, -.02)], .23, .30, coat)
            b.chain([(s * .42, 3.37, -.43), (s * .27, 2.92, -.53),
                     (s * .48, 2.41, -.53)], .095, .075, 'brass')
            for y in (2.40, 2.68, 2.95):
                b.ellipsoid((s * .44, y, -.54), (.06, .06, .03), 'brass')
            b.ellipsoid((s * .76, 3.34, .03), (.32, .18, .37), 'rust')
            for k in (-1, 0, 1):
                b.capsule((s * .78 + k * .14, 3.29, -.22),
                          (s * .80 + k * .14, 3.03, -.25), .045, .035, 'brass')
        b.capsule((0, 2.9, .41), (0, 1.14, .57), .60, .83, coat)
        for i, x in enumerate((-.72, -.39, 0, .35, .73)):
            b.chain([(x, 1.27, .59), (x * 1.14, .77, .68),
                     (x * 1.20, .42 + .16 * (i % 2), .74)], .18, .055, coat)
        b.capsule((-.54, 1.98, -.40), (.54, 1.98, -.40), .09, .09, 'dark')
        b.box((-.13, 1.87, -.54), (.13, 2.09, -.43), 'brass')
        barnacles(b, [(-.70, 1.24, -.29, .15), (.64, 2.91, -.18, .12),
                      (.62, 1.35, .58, .17), (-.56, 3.37, .17, .15),
                      (-.34, 1.24, .97, .13)])
        for s in (-1, 1):
            b.chain([(s * .64, 1.60, .43), (s * .88, 1.98, .51),
                     (s * .83, 2.24, .54)], .075, .035, 'rust')
            b.capsule((s * .87, 1.96, .51), (s * 1.10, 2.17, .55), .065, .025, 'rust')
        if form == 'storm':
            for s in (-1, 1):
                b.chain([(s * .58, 3.25, -.48), (s * .66, 2.70, -.57),
                         (s * .66, 1.80, -.49), (s * 1.03, .70, -.09)], .065, .045, 'glow_sea')
                b.chain([(s * .46, 3.08, .61), (s * .63, 2.48, .71),
                         (s * .80, 1.60, .84), (s * .80, .65, .82)], .065, .04, 'glow_sea')
            for y, r in ((1.12, .70), (1.48, .62), (2.28, .48)):
                b.chain([(-r, y + .16, .85), (-r * .4, y, 1.01),
                         (r * .3, y + .12, 1.02), (r, y + .05, .85)], .055, .045, 'glow_sea')
        if form == 'abyss':
            for s in (-1, 1):
                for y in (1.0, 1.8, 2.6):
                    x = s * (.67 + .06 * (y < 1.5))
                    b.chain([(x, y, -.10), (x + s * .25, y + .25, -.18),
                             (x + s * .21, y + .55, -.16)], .11, .04, 'bone')
                    b.capsule((x + s * .18, y + .18, -.17),
                              (x + s * .44, y + .37, -.12), .07, .025, 'bone')
            for s in (-1, 1):
                b.chain([(s * .25, 3.13, -.49), (s * .45, 2.48, -.61),
                         (s * .20, 1.86, -.61), (s * .63, 1.30, -.55)], .105, .035, 'skin')

    def head(name, form):
        h = m.part(name)
        h.ellipsoid((0, .04, -.02), (.39, .43, .34), 'skin')
        h.ellipsoid((0, -.09, -.27), (.27, .26, .15), 'bone')
        eyes(h, .13, -.35, .18, .075, 'glow_sea')
        for s in (-1, 1):
            h.capsule((s * .10, .27, -.36), (s * .29, .29, -.32), .045, .035, 'navy')
        h.ellipsoid((0, -.03, -.42), (.075, .14, .07), 'skin')
        # Tricorn: three upturned points around a domed crown, not a disk.
        h.ellipsoid((0, .55, .08), (1.14, .13, .70), 'navy')
        h.ellipsoid((0, .81, .15), (.63, .37, .45), 'navy')
        triangle = [(-1.16, .66, -.28), (1.16, .66, -.28), (0, .75, .95)]
        for i in range(3):
            a, b = triangle[i], triangle[(i + 1) % 3]
            h.triangle(a, b, (0, .95, .10), .16, 'navy')
            h.capsule(a, b, .055, .055, 'brass')
        # A small skull badge under crossed bones is readable at sprite size.
        h.ellipsoid((0, .86, -.37), (.16, .16, .07), 'bone')
        for s in (-1, 1):
            h.ellipsoid((s * .06, .89, -.43), (.04, .045, .025), 'dark')
            h.capsule((s * .21, .68, -.38), (-s * .20, .52, -.40), .025, .025, 'bone')
        # Lantern hangs off the left brim, with a little space around it.
        h.capsule((-.96, .64, -.20), (-.96, .06, -.20), .025, .025, 'brass')
        lantern(h, (-.96, -.16, -.20), .16,
                light='glow_sea' if form == 'storm' else 'glow_lamp')
        barnacles(h, [(.78, .68, -.27, .12), (.88, .57, .10, .10)])
        if form == 'abyss':
            for s in (-1, 1):
                h.chain([(s * .66, .65, .22), (s * .85, .99, .26),
                         (s * 1.05, 1.03, .29)], .10, .035, 'bone')
                h.capsule((s * .79, .86, .25), (s * .68, 1.16, .25), .06, .025, 'bone')

    def jaw(name, form):
        j = m.part(name)
        j.ellipsoid((0, -.025, -.08), (.28, .13, .20), 'skin')
        j.box((-.13, .015, -.27), (.13, .075, -.20), 'dark')
        # Six curled tentacles belong to the jaw, so the beard moves with it.
        for i, x in enumerate((-.30, -.18, -.06, .06, .18, .30)):
            length = (.64, .90, 1.06, .97, .82, .59)[i]
            if form == 'abyss':
                length *= 1.28
            s = -1 if x < 0 else 1
            j.chain([(x * .8, -.10, -.12), (x * 1.20, -length * .48, -.26),
                     (x * 1.60, -length * .86, -.26),
                     (x * 1.70 + s * .12, -length, -.34),
                     (x * 1.70 + s * .22, -length * .82, -.40)],
                    .09 if form != 'abyss' else .12, .025, 'skin')
            for k in (1, 2):
                j.ellipsoid((x * (1.05 + k * .23), -length * (.25 + .21 * k), -.33),
                            (.035, .045, .026), 'brass' if form == 'abyss' else 'bone')

    for form in ('base', 'storm', 'abyss'):
        suffix = '' if form == 'base' else '_' + form
        body('body' + suffix, form)
        head('head' + suffix, form)
        jaw('jaw' + suffix, form)
    m.joint('head', 'head', (0, 3.78, -.08), 'head')
    m.joint('jaw', 'jaw', (0, -.25, -.12), 'jaw', parent_limb='head')
    legs(m, 1.18, 1.18, .38, .22, 'navy', 'dark')
    a = simple_arm(m, 'arm_l', (-.85, 3.28, .02), 1.17, .21, 'navy', 'skin')
    ring(a, (0, -.94, -.02), .20, .055, 'brass', n=20)
    cutlass(a, (0, -1.16, -.12), 1.66, direction=-1)
    # Right forearm IS a cast-bronze hand cannon. Downward barrel becomes
    # forward-facing as the cantor rig raises the arm to cast.
    a = m.part('arm_r')
    a.capsule((0, 0, 0), (0, -.55, .015), .23, .21, 'navy')
    a.capsule((0, -.52, -.02), (0, -1.34, -.12), .25, .28, 'brass')
    for y in (-.63, -1.12, -1.36):
        ring(a, (0, y, -.02 - max(0, -y - .52) * .12), .27, .045, 'rust', n=24)
    a.ellipsoid((0, -1.40, -.12), (.18, .035, .18), 'dark')
    a.ellipsoid((0, -1.43, -.12), (.08, .02, .08), 'glow_lamp')
    barnacles(a, [(.18, -.75, -.18, .09), (-.14, -1.10, -.22, .08)])
    m.joint('arm_r', 'arm_r', (.85, 3.28, .02), 'arm', -1, throws=True)
    for s, side in ((-1, 'l'), (1, 'r')):
        c = m.part('cloth_' + side)
        c.chain([(0, 0, 0), (s * .12, -.74, .10), (s * .23, -1.16, .18)], .17, .05, 'navy')
        barnacles(c, [(s * .14, -.80, .18, .08)])
        m.joint('cloth_' + side, 'cloth_' + side, (s * .60, 1.78, .68), 'cloth', -s)
    m.hand = (0, -1.46, -.12)
    m.extra = dict(animation_style='cantor', hand_limb='arm_r', glow_strength=1.2,
                   waddle=.08, bob=.015,
                   variants={v: {part: part + '_' + v for part in ('body', 'head', 'jaw')}
                             for v in ('storm', 'abyss')})
    return m


BUILDERS = {f.__name__: f for f in (
    spore_puffling, mycelid_crawler, glowcap_sprite, shroom_brute, spore_witch,
    bracket_warden, mother_mycora, bilge_rat, barnacle_crab, drowned_deckhand,
    kelp_shambler, cannon_gunner, first_mate_grisk, captain_saltmourn)}


def origins(rig):
    """Resolve child joints exactly as CreatureModel does, including jaws."""
    result = {}
    for name, spec in rig['limbs'].items():
        parent = result.get(spec.get('parent_limb'), (0, 0, 0))
        result[name] = tuple(parent[k] + spec['pivot'][k] for k in range(3))
    return result


def save_model(m):
    """Use the workshop exporter, then align phase frames and child rest poses.

    CreatureModel swaps meshes inside the BASE holder. Its position never
    changes, so all phases of a part must have identical padded VOX frames.
    The workshop's standalone export also needs parent-relative jaw origins.
    These adjustments are confined to this batch's generated folders.
    """
    assert m.name in BUILDERS
    grounded = {}
    for spec in m.limbs.values():
        if spec['role'] == 'leg':
            assert 'parent_limb' not in spec
            part, floor = spec['part'], -spec['pivot'][1]
            if part in grounded:
                assert grounded[part] == floor
            else:
                m.parts[part] = GroundedPart(m.parts[part], floor)
                grounded[part] = floor
    folder = m.save()
    rig = json.loads((folder / 'rig.json').read_text())
    palette = m._full_palette()
    parts = {name: m._shade(p.voxels(hollow_above=6000)) for name, p in m.parts.items()}
    groups = {}
    for swaps in rig.get('variants', {}).values():
        for base, variant in swaps.items():
            groups.setdefault(base, {base}).add(variant)
    for group in groups.values():
        union = {v: c for name in sorted(group) for v, c in parts[name].items()}
        lo, size = fit_frame(union)
        lo, size = tuple(v - 1 for v in lo), tuple(v + 2 for v in size)
        assert max(size) <= 256
        for name in sorted(group):
            rig['parts'][name]['frame_min'] = list(lo)
            # Each VOX carries its own palette. Reuse the eye-light slot for
            # deep red in abyss, keeping six materials and two glow colors.
            part_palette = dict(palette, glow_sea=(208, 45, 61)) if name.endswith('_abyss') else palette
            for glowing, suffix in ((False, ''), (True, '_glow')):
                vox = {v: c for v, c in parts[name].items() if c.startswith('glow') == glowing}
                if vox:
                    write_vox(str(folder / (name + suffix + '.vox')), vox, part_palette, lo, size)
    full = dict(parts['body'])
    origin = origins(rig)
    for name, spec in rig['limbs'].items():
        assert not spec.get('yaw'), 'Add yaw support before using rotated rest joints'
        at = origin[name]
        full.update({tuple(v[k] + at[k] for k in range(3)): c for v, c in parts[spec['part']].items()})
    lo, size = fit_frame(full)
    assert max(size) <= 256
    write_vox(str(folder / 'model.vox'), full, palette, lo, size)
    (folder / 'rig.json').write_text(json.dumps(rig, indent=2) + '\n')
    return (max(v[1] for v in full) + 1) * m.vs + rig.get('hover', 0)


def assemble_phase(name, phase=''):
    folder = ROOT / 'creatures' / name
    rig = json.loads((folder / 'rig.json').read_text())
    swaps = rig.get('variants', {}).get(phase, {})
    joint_origins = origins(rig)
    instances = [('body', (0, 0, 0))] + [(spec['part'], joint_origins[limb])
                                                for limb, spec in rig['limbs'].items()]
    full = {}
    for base, at in instances:
        part = swaps.get(base, base)
        frame = rig['parts'][part]['frame_min']
        for suffix in ('', '_glow'):
            path = folder / (part + suffix + '.vox')
            if path.exists():
                full.update({tuple(v[k] + frame[k] + at[k] for k in range(3)): (c, bool(suffix))
                             for v, c in read_vox(path).items()})
    return full


def phase_sheet(names, out):
    rows = []
    font = ImageFont.truetype(str(ROOT / 'fonts/BreeSerif.ttf'), 22)
    for name in names:
        if name not in ('mother_mycora', 'captain_saltmourn'):
            continue
        phases = ('base', 'bloom', 'rot') if name == 'mother_mycora' else ('base', 'storm', 'abyss')
        for phase in phases:
            vox = assemble_phase(name, '' if phase == 'base' else phase)
            row = Image.new('RGB', (1440, 430), '#151b22')
            ImageDraw.Draw(row).text((14, 6), name + ' - ' + phase, fill='#e8e4da', font=font)
            for i, yaw in enumerate((0, 35, 90, 200)):
                row.paste(render(vox, 360, 390, yaw=yaw), (i * 360, 38))
            rows.append(row)
    if rows:
        im = Image.new('RGB', (1440, len(rows) * 430), '#151b22')
        for i, row in enumerate(rows):
            im.paste(row, (0, i * 430))
        im.save(out)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('names', nargs='*', help='Creature ids; defaults to all fourteen')
    parser.add_argument('--sheet', metavar='PNG', help='Four-view sheet, plus a sibling _phases.png for bosses')
    args = parser.parse_args(argv)
    names = args.names or list(BUILDERS)
    unknown = set(names) - BUILDERS.keys()
    if unknown:
        parser.error('Unknown creatures: ' + ', '.join(sorted(unknown)))
    for name in names:
        m = BUILDERS[name]()
        height = save_model(m)
        limbs = ', '.join(m.limbs)
        print(f'{name}: height {height:.3f} m (brief {HEIGHTS[name]:g} m), '
              f'voxel {m.vs:g} m; {limbs}', flush=True)
    if args.sheet:
        studio.BOLD = str(ROOT / 'fonts/BreeSerif.ttf')
        sheet(names, args.sheet)
        path = Path(args.sheet)
        phase_sheet(names, path.with_name(path.stem + '_phases.png'))


if __name__ == '__main__':
    main()
