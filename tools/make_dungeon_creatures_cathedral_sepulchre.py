#!/usr/bin/env python3
"""The Unlit Cathedral and Starless Sepulchre, sculpted in meters.

    python3 tools/make_dungeon_creatures_cathedral_sepulchre.py
    python3 tools/make_dungeon_creatures_cathedral_sepulchre.py oblivara
    python3 tools/make_dungeon_creatures_cathedral_sepulchre.py --sheet /tmp/cathedral.png

Only the twelve folders in BUILDERS are written. No editor or import is needed.
Sheets use the workshop renderer and the game's Bree Serif font. Phase sheets
are written alongside the requested sheet, without temporary creature folders.
"""
import argparse
import json
import math
from pathlib import Path

import monster_studio as studio
from monster_studio import Model, hood, ring
from make_creatures import fit_frame, write_vox
from preview_voxel_batch import ROOT, read_vox, render


class _BakedPart:
    def __init__(self, voxels):
        self.data = voxels

    def voxels(self, hollow_above=6000):
        return self.data


class DungeonModel(Model):
    """Keep phase frames identical and include parent joints in model.vox.

    The workshop's standard export builds model.vox using root pivots only.
    Jaws here are children of heads, so rebuild that convenience file using
    the same hierarchy as CreatureModel. Runtime parts still use Model.save.
    """
    def save(self, keep=None):
        self.parts = {n: _BakedPart(p.voxels(hollow_above=6000))
                      for n, p in self.parts.items()}
        # The SDF's subvoxel tolerance can put one row under an exact sole.
        # Trim that row in the joint's frame so walking feet land at y = 0.
        for spec in self.limbs.values():
            if spec['role'] == 'leg':
                part = self.parts[spec['part']]
                floor = -spec['pivot'][1]
                part.data = {pos: c for pos, c in part.data.items() if pos[1] >= floor}
        folder = super().save(keep)
        rig = json.loads((folder / 'rig.json').read_text())
        vox = {n: self._shade(p.data) for n, p in self.parts.items()}
        palette = self._full_palette()
        groups = {}
        for swaps in self.extra.get('variants', {}).values():
            for base, variant in swaps.items():
                groups.setdefault(base, {base}).add(variant)
        for names in groups.values():
            union = {pos: color for name in names for pos, color in vox[name].items()}
            minimum, size = fit_frame(union)
            minimum = tuple(c - 1 for c in minimum)
            size = tuple(c + 2 for c in size)
            assert max(size) <= 256
            for name in names:
                rig['parts'][name]['frame_min'] = list(minimum)
                for suffix, emissive in (('', False), ('_glow', True)):
                    data = {pos: c for pos, c in vox[name].items()
                            if c.startswith('glow') == emissive}
                    if data:
                        write_vox(str(folder / (name + suffix + '.vox')),
                                  data, palette, minimum, size)
        (folder / 'rig.json').write_text(json.dumps(rig, indent=2) + '\n')

        def origin(name):
            spec = self.limbs[name]
            parent = origin(spec['parent_limb']) if spec.get('parent_limb') else (0, 0, 0)
            return tuple(spec['pivot'][i] + parent[i] for i in range(3))

        full = dict(vox['body'])
        for name, spec in self.limbs.items():
            at = origin(name)
            assert not spec.get('yaw'), 'These sculpts have no rest yaw.'
            for pos, color in vox[spec['part']].items():
                full[tuple(pos[i] + at[i] for i in range(3))] = color
        minimum, size = fit_frame(full)
        assert max(size) <= 256
        write_vox(str(folder / 'model.vox'), full, palette, minimum, size)
        return folder


def gown(p, top, hem, shoulder, flare, cloth, lining=None, folds=8):
    """A bell-shaped skirt with deliberate broad folds, flattened in depth."""
    for i in range(7):
        t = i / 6
        ry = (top - hem) / 7 + .03
        y = top - ry + (hem + ry - (top - ry)) * t
        r = shoulder + (flare - shoulder) * t ** 1.3
        p.ellipsoid((0, y, .04), (r, ry, r * .66), cloth)
    if lining:
        for i in range(folds):
            a = math.tau * i / folds
            x, z = math.cos(a), math.sin(a) * .66
            p.capsule((x * shoulder * .82, top - .18, z * shoulder + .04),
                      (x * flare * .94, hem, z * flare + .04),
                      shoulder * .18, flare * .11, lining if i % 2 else cloth)


def legs(m, hip, spread, length, radius, color, boot=None):
    p = m.part('leg')
    p.capsule((0, 0, 0), (0, -length + radius, .015), radius, radius * .8, color)
    p.ellipsoid((0, -length + radius * .48, -radius * .45),
                (radius * 1.05, radius * .48, radius * 1.55), boot or color)
    for s, side in ((-1, 'l'), (1, 'r')):
        m.joint('leg_' + side, 'leg', (s * spread, hip, 0), 'leg', -s)


def sleeve(m, name, length, radius, cloth, hand, s=1):
    p = m.part(name)
    p.capsule((0, 0, 0), (s * .055, -length * .78, -.025),
              radius, radius * 1.25, cloth)
    p.ellipsoid((s * .055, -length, -.05),
                (radius * .67, radius * .82, radius * .67), hand)
    return p


def bell(p, c, r, metal='brass', inside='void', light=None):
    x, y, z = c
    p.capsule((x, y + r * .58, z), (x, y - r * .33, z), r * .40, r * .84, metal)
    p.ellipsoid((x, y - r * .47, z), (r, r * .18, r), metal)
    p.ellipsoid((x, y - r * .60, z), (r * .76, r * .12, r * .76), inside)
    p.capsule((x, y - r * .52, z), (x, y - r * .84, z), r * .10, r * .13, metal)
    if light:
        ring(p, (x, y - r * .43, z), r * .9, r * .055, light, n=20)


def flame(p, c, h, wax='wax', fire='glow_wax'):
    x, y, z = c
    p.capsule((x, y, z), (x, y + h * .45, z), h * .17, h * .14, wax)
    p.capsule((x, y + h * .50, z), (x + h * .08, y + h * .86, z),
              h * .17, .008, fire)


def chain_links(p, points, radius, color):
    """Wide alternating iron links, legible at the workshop resolution."""
    for i, (x, y, z) in enumerate(points):
        ring(p, (x, y, z), radius, radius * .27, color,
             axis='z' if i % 2 == 0 else 'x', n=12)


def candle_wraith():
    m = DungeonModel('candle_wraith', .05, {
        'robe': (66, 43, 85), 'fold': (35, 27, 50), 'wax': (224, 195, 139),
        'brass': (157, 109, 60), 'void': (17, 14, 24),
        'glow_wax': (255, 212, 116), 'glow_eye': (255, 241, 193),
    })
    b = m.part('body')
    gown(b, 1.03, .29, .19, .34, 'robe', 'fold')
    b.ellipsoid((0, 1.04, .02), (.29, .11, .19), 'fold')
    ring(b, (0, 1.07, 0), .20, .035, 'brass', n=18)
    h = m.part('head')
    h.capsule((0, 0, 0), (0, .24, 0), .15, .135, 'wax')
    h.ellipsoid((0, .25, 0), (.145, .045, .14), 'brass')
    h.box((-.025, .25, -.02), (.025, .33, .02), 'void')
    h.capsule((0, .34, 0), (.025, .47, 0), .072, .008, 'glow_wax')
    for x, dy in ((-.12, -.10), (-.04, -.02), (.09, -.14)):
        h.capsule((x, .22, -.10), (x, dy, -.15), .034, .02, 'wax')
    for s in (-1, 1):
        h.ellipsoid((s * .07, .14, -.17), (.035, .025, .02), 'void')
        h.ellipsoid((s * .07, .14, -.195), (.02, .014, .012), 'glow_eye')
    h.ellipsoid((0, -.015, -.15), (.035, .04, .02), 'void')
    m.joint('head', 'head', (0, 1.12, 0), 'head')
    for s, side in ((-1, 'l'), (1, 'r')):
        sleeve(m, 'arm_' + side, .42, .08, 'robe', 'wax', s)
        m.joint('arm_' + side, 'arm_' + side, (s * .28, 1.0, 0),
                'arm', -s, throws=s > 0)
        p = m.part('cloth_' + side)
        p.chain([(0, 0, 0), (s * .055, -.18, .04), (s * .02, -.32, .12)],
                .10, .018, 'fold')
        m.joint('cloth_' + side, 'cloth_' + side, (s * .23, .34, .04), 'cloth', -s)
    m.hand = (.055, -.43, -.08)
    m.extra = dict(hover=.17, bob=.035, waddle=0, hand_limb='arm_r')
    return m


def bell_imp():
    m = DungeonModel('bell_imp', .04, {
        'stone': (94, 85, 113), 'wing': (53, 42, 66), 'brass': (178, 121, 58),
        'void': (23, 17, 30), 'tooth': (218, 194, 153), 'glow_eye': (251, 191, 83),
    }, rough=('stone',))
    b = m.part('body')
    b.ellipsoid((0, .42, .04), (.22, .25, .18), 'stone')
    b.ellipsoid((0, .38, -.11), (.16, .17, .11), 'wing')
    h = m.part('head')
    h.ellipsoid((0, .06, -.03), (.22, .18, .17), 'stone')
    for s in (-1, 1):
        h.chain([(s * .15, .17, .01), (s * .22, .28, .03), (s * .17, .35, -.015)],
                .055, .012, 'wing')
        h.triangle((s * .13, .12, 0), (s * .34, .17, .02),
                   (s * .18, -.02, -.02), .055, 'stone')
        h.ellipsoid((s * .085, .075, -.175), (.061, .045, .025), 'void')
        h.box((s * .085 - .025, .066, -.207), (s * .085 + .025, .092, -.18), 'glow_eye')
        h.capsule((s * .10, -.04, -.17), (s * .09, -.10, -.18), .027, .008, 'tooth')
    h.ellipsoid((0, -.03, -.18), (.13, .035, .035), 'void')
    m.joint('head', 'head', (0, .64, -.08), 'head')
    legs(m, .23, .13, .23, .075, 'stone', 'wing')
    for s, side in ((-1, 'l'), (1, 'r')):
        a = m.part('arm_' + side)
        a.chain([(0, 0, 0), (s * .07, -.15, -.06), (0, -.24, -.17)], .065, .045, 'stone')
        if s > 0:
            ring(a, (0, -.28, -.18), .055, .018, 'brass', axis='z', n=16)
            bell(a, (0, -.35, -.18), .15)
        m.joint('arm_' + side, 'arm_' + side, (s * .23, .54, 0), 'arm', -s, throws=s > 0)
        w = m.part('wing_' + side)
        root, tip, low = (0, 0, 0), (s * .38, .25, .06), (s * .31, -.16, .10)
        w.triangle(root, tip, low, .045, 'wing')
        w.chain([root, (s * .18, .17, .04), tip], .038, .012, 'stone')
        for xx, yy in ((.21, -.02), (.31, -.16)):
            w.capsule((s * .13, .09, .04), (s * xx, yy, .10), .023, .012, 'stone')
        m.joint('wing_' + side, 'wing_' + side, (s * .17, .57, .16), 'wing', -s)
    t = m.part('tail')
    t.chain([(0, 0, 0), (.08, -.12, .20), (.17, -.10, .32)], .04, .018, 'wing')
    m.joint('tail', 'tail', (0, .35, .18), 'tail')
    m.hand = (0, -.48, -.18)
    m.extra = dict(hand_limb='arm_r', waddle=.35, bob=0, flap_rate=4.0)
    return m


def censer_bearer():
    m = DungeonModel('censer_bearer', .06, {
        'cloth': (67, 52, 88), 'fold': (33, 28, 47), 'void': (14, 12, 24),
        'wax': (192, 175, 149), 'brass': (154, 107, 69), 'smoke': (117, 73, 155),
        'glow_smoke': (191, 121, 248), 'glow_eye': (239, 211, 151),
    })
    b = m.part('body')
    gown(b, 1.34, .33, .23, .36, 'cloth', 'fold')
    b.ellipsoid((0, 1.38, .03), (.35, .11, .24), 'fold')
    ring(b, (0, .93, .01), .28, .035, 'brass', n=22)
    for s in (-1, 1):
        b.capsule((s * .14, 1.37, -.17), (s * .16, .42, -.25), .045, .04, 'wax')
    h = m.part('head')
    hood(h, (0, .05, 0), .24, 'cloth', 'void')
    h.capsule((0, .19, .05), (0, .34, .12), .12, .014, 'fold')
    for s in (-1, 1):
        h.ellipsoid((s * .072, .04, -.29), (.029, .019, .02), 'glow_eye')
    m.joint('head', 'head', (0, 1.53, -.01), 'head')
    legs(m, .36, .13, .36, .08, 'fold')
    sleeve(m, 'arm_l', .49, .10, 'cloth', 'wax', -1)
    a = sleeve(m, 'arm_r', .42, .10, 'cloth', 'wax')
    a.chain([(0, -.43, -.05), (.09, -.60, -.14), (.21, -.71, -.19)], .018, .018, 'brass')
    for dx in (-.09, .09):
        a.capsule((.21, -.70, -.19), (.21 + dx, -.91, -.19), .016, .016, 'brass')
    a.ellipsoid((.21, -.99, -.19), (.18, .14, .16), 'brass')
    ring(a, (.21, -.94, -.19), .15, .026, 'glow_smoke', n=18)
    a.ellipsoid((.21, -1.08, -.19), (.11, .07, .11), 'fold')
    for x, y, z, r in ((.23, -.83, -.18, .10), (.30, -.67, -.16, .13),
                        (.37, -.49, -.11, .15), (.33, -.30, -.07, .11), (.45, -.16, -.03, .075)):
        a.ellipsoid((x, y, z), (r, r * .85, r * .70), 'smoke')
    a.chain([(.22, -.88, -.27), (.26, -.70, -.27), (.33, -.60, -.24)], .027, .012, 'glow_smoke')
    m.joint('arm_l', 'arm_l', (-.31, 1.34, 0), 'arm', 1, throws=False)
    m.joint('arm_r', 'arm_r', (.31, 1.34, -.03), 'arm', -1, throws=True)
    m.hand = (.21, -.95, -.20)
    m.extra = dict(hand_limb='arm_r', waddle=.12, bob=.015)
    return m


def glass_knight():
    m = DungeonModel('glass_knight', .08, {
        'lead': (57, 52, 69), 'violet': (106, 65, 147), 'rose': (178, 65, 111),
        'amber': (204, 150, 74), 'void': (18, 18, 31), 'glass': (149, 143, 190),
        'glow_rose': (248, 146, 186), 'glow_eye': (248, 213, 132),
    })
    b = m.part('body')
    b.capsule((0, 1.02, .02), (0, 2.22, .02), .33, .40, 'lead')
    for s in (-1, 1):
        b.triangle((0, 2.31, -.38), (s * .33, 2.01, -.34),
                   (0, 1.51, -.37), .11, 'rose' if s < 0 else 'violet')
        b.triangle((s * .34, 1.97, -.30), (s * .32, 1.36, -.29),
                   (0, 1.51, -.37), .10, 'amber')
        b.chain([(0, 2.31, -.40), (s * .33, 2.01, -.39), (0, 1.51, -.42)], .038, .038, 'lead')
        b.ellipsoid((s * .49, 2.22, 0), (.26, .20, .27), 'lead')
        b.triangle((s * .27, 2.25, -.23), (s * .54, 2.44, -.10),
                   (s * .70, 2.14, -.20), .12, 'violet')
        b.triangle((s * .08, 1.20, -.29), (s * .34, 1.36, -.27),
                   (s * .35, .85, -.30), .09, 'rose')
    ring(b, (0, 1.36, 0), .34, .05, 'lead', n=22)
    ring(b, (0, 1.93, -.41), .15, .035, 'amber', axis='z', n=20)
    b.ellipsoid((0, 1.93, -.43), (.067, .067, .05), 'glow_rose')
    # The back and sides are glass too, not an opaque plate cuirass.
    for s in (-1, 1):
        b.triangle((0, 2.31, .38), (s * .32, 2.01, .34),
                   (0, 1.47, .36), .10, 'violet' if s < 0 else 'rose')
        b.chain([(0, 2.31, .41), (s * .32, 2.01, .39), (0, 1.47, .40)], .035, .035, 'lead')
        b.triangle((s * .38, 2.16, -.15), (s * .38, 2.16, .15),
                   (s * .35, 1.62, 0), .10, 'violet')
    h = m.part('head')
    h.capsule((0, -.10, 0), (0, .23, 0), .22, .19, 'lead')
    h.triangle((-.18, .17, -.20), (0, .48, -.02), (.18, .17, -.20), .10, 'violet')
    h.box((-.16, -.09, -.23), (.16, .16, -.16), 'glass')
    h.box((-.19, .06, -.265), (.19, .12, -.22), 'void')
    h.box((-.135, .075, -.28), (.135, .105, -.24), 'glow_eye')
    h.box((-.025, -.12, -.28), (.025, .20, -.23), 'lead')
    m.joint('head', 'head', (0, 2.49, 0), 'head')
    legs(m, 1.04, .22, 1.04, .145, 'lead')
    l = m.parts['leg']
    l.box((-.09, -.84, -.15), (.09, -.20, -.10), 'violet')
    l.capsule((0, -.64, -.18), (0, -.20, -.18), .025, .025, 'amber')
    for s, side in ((-1, 'l'), (1, 'r')):
        a = sleeve(m, 'arm_' + side, .80, .135, 'lead', 'lead', s)
        a.box((-.09, -.55, -.15), (.09, -.20, -.10), 'rose')
        if s < 0:
            # A leaded lancet shield, facing the player rather than edge on.
            a.triangle((-.33, -.20, -.36), (.21, -.20, -.36),
                       (-.06, -1.09, -.36), .12, 'violet')
            a.triangle((-.33, -.20, -.44), (-.06, .02, -.44),
                       (.21, -.20, -.44), .09, 'rose')
            a.chain([(-.06, .02, -.45), (-.33, -.20, -.45), (-.06, -1.09, -.45),
                     (.21, -.20, -.45), (-.06, .02, -.45)], .038, .038, 'lead')
            a.capsule((-.06, -.10, -.47), (-.06, -.86, -.47), .025, .025, 'amber')
        else:
            a.box((-.24, -.83, -.17), (.24, -.75, -.07), 'amber')
            a.capsule((0, -.83, -.12), (0, -1.99, -.26), .09, .008, 'glass')
            a.capsule((0, -.87, -.21), (0, -1.81, -.31), .022, .014, 'glow_rose')
        m.joint('arm_' + side, 'arm_' + side, (s * .50, 2.16, 0), 'arm', -s, throws=s > 0)
    m.hand = (0, -1.75, -.30)
    m.extra = dict(hand_limb='arm_r', waddle=.06, bob=0)
    return m


def hymn_abbess():
    m = DungeonModel('hymn_abbess', .07, {
        'veil': (60, 40, 83), 'rose': (112, 50, 91), 'void': (19, 16, 31),
        'ivory': (221, 207, 180), 'gold': (172, 132, 72),
        'glow_page': (247, 214, 143), 'glow_song': (221, 171, 252),
    })
    b = m.part('body')
    gown(b, 1.65, .22, .27, .49, 'veil', 'rose')
    b.ellipsoid((0, 1.68, .01), (.43, .13, .28), 'rose')
    for s in (-1, 1):
        b.capsule((s * .15, 1.68, -.24), (s * .19, .42, -.36), .06, .05, 'ivory')
    h = m.part('head')
    hood(h, (0, .03, .02), .24, 'veil', 'void')
    h.ellipsoid((0, -.01, -.24), (.13, .17, .09), 'ivory')
    for s in (-1, 1):
        h.capsule((s * .04, .03, -.33), (s * .105, .04, -.31), .016, .016, 'void')
        h.triangle((s * .02, .20, -.13), (s * .18, .49, .01),
                   (s * .25, .18, .04), .09, 'ivory')
        h.capsule((s * .18, .44, -.05), (s * .23, .20, -.08), .028, .028, 'gold')
    h.ellipsoid((0, -.09, -.33), (.04, .045, .02), 'glow_song')
    m.joint('head', 'head', (0, 1.88, -.015), 'head')
    legs(m, .29, .17, .29, .085, 'void')
    for s, side in ((-1, 'l'), (1, 'r')):
        a = sleeve(m, 'arm_' + side, .58, .115, 'veil', 'ivory', s)
        if s > 0:
            # An open book: two sloped page blocks and a dark spine.
            for q in (-1, 1):
                a.triangle((0, -.46, -.31), (q * .28, -.36, -.32),
                           (q * .28, -.57, -.66), .09, 'gold')
                a.triangle((0, -.46, -.33), (q * .24, -.37, -.35),
                           (q * .24, -.55, -.62), .065, 'glow_page')
                for i in range(3):
                    z = -.42 - i * .065
                    a.capsule((q * .055, -.43 - i * .035, z),
                              (q * .20, -.40 - i * .035, z), .012, .012, 'rose')
            a.capsule((0, -.45, -.32), (0, -.61, -.68), .026, .026, 'rose')
        m.joint('arm_' + side, 'arm_' + side, (s * .36, 1.65, -.02), 'arm', -s, throws=s > 0)
        p = m.part('cloth_' + side)
        p.capsule((0, 0, 0), (s * .13, -1.18, .16), .14, .09, 'veil')
        p.capsule((s * .03, -.08, -.11), (s * .14, -1.15, .07), .027, .025, 'ivory')
        m.joint('cloth_' + side, 'cloth_' + side, (s * .26, 1.92, .15), 'cloth', -s)
    m.hand = (0, -.53, -.57)
    m.extra = dict(hand_limb='arm_r', waddle=.07, bob=.01)
    return m


def bellringer():
    m = DungeonModel('bellringer', .08, {
        'skin': (132, 117, 133), 'cloth': (61, 39, 64), 'iron': (53, 49, 60),
        'brass': (171, 117, 59), 'bone': (208, 185, 148), 'void': (22, 17, 28),
        'glow_eye': (249, 197, 103), 'glow_bell': (201, 134, 246),
    }, rough=('skin', 'cloth'))
    b = m.part('body')
    b.ellipsoid((0, 2.13, .27), (.72, .88, .58), 'skin')
    b.ellipsoid((-.16, 2.87, .33), (.67, .68, .62), 'cloth')
    gown(b, 1.74, .82, .57, .67, 'cloth', 'iron', folds=6)
    for s in (-1, 1):
        b.ellipsoid((s * .76, 2.69, .11), (.40, .34, .38), 'skin')
        b.capsule((s * .32, 3.16, -.20), (s * .48, 1.67, -.48), .075, .065, 'iron')
    ring(b, (0, 1.67, .06), .61, .07, 'brass', n=26)
    b.ellipsoid((0, 1.67, -.58), (.12, .12, .07), 'glow_bell')
    h = m.part('head')
    h.ellipsoid((0, .01, -.06), (.30, .38, .29), 'skin')
    h.ellipsoid((0, -.08, -.29), (.23, .24, .13), 'bone')
    for s in (-1, 1):
        h.ellipsoid((s * .12, .02, -.38), (.085, .055, .033), 'void')
        h.ellipsoid((s * .12, .02, -.41), (.037, .027, .015), 'glow_eye')
    h.box((-.17, -.22, -.40), (.17, -.16, -.34), 'void')
    for x in (-.10, 0, .10):
        h.box((x - .025, -.215, -.42), (x + .025, -.16, -.39), 'bone')
    m.joint('head', 'head', (0, 2.76, -.48), 'head')
    legs(m, .94, .38, .94, .24, 'skin', 'iron')
    for s, side in ((-1, 'l'), (1, 'r')):
        a = m.part('arm_' + side)
        a.chain([(0, 0, 0), (s * .14, -.60, -.05), (s * .08, -1.17, -.18)],
                .28, .20, 'skin')
        ring(a, (s * .08, -1.01, -.15), .22, .06, 'iron', n=18)
        a.ellipsoid((s * .08, -1.20, -.18), (.23, .24, .23), 'skin')
        if s > 0:
            pts = [(.12 + i * .055, -1.30 - i * .115, -.18 - i * .035) for i in range(5)]
            chain_links(a, pts, .10, 'iron')
            bell(a, (.38, -1.99, -.34), .61, light='glow_bell')
            for dx in (-.27, .27):
                a.capsule((.38 + dx, -1.73, -.75), (.38 + dx * 1.3, -2.13, -.86), .026, .026, 'iron')
        m.joint('arm_' + side, 'arm_' + side, (s * .84, 2.70, -.04), 'arm', -s, throws=s > 0)
    m.hand = (.38, -2.25, -.34)
    m.extra = dict(hand_limb='arm_r', waddle=.23, bob=.01)
    return m


def _glass_wing(p, s, upper, form):
    """A cathedral lancet stretched into a wing, with real holes when hollow."""
    a = (0, 0, 0)
    b = (s * 1.48, .77 if upper else -.48, .12)
    c = (s * 3.12, 1.60 if upper else -1.42, .24)
    d = (s * 2.15, .04 if upper else -1.56, .19)
    e = (s * .86, -.34 if upper else -.80, .07)
    if form != 'hollow':
        for aa, bb, cc, color in ((a, b, e, 'violet'), (b, d, e, 'rose'),
                                   (b, c, d, 'rose' if upper else 'violet')):
            p.triangle(aa, bb, cc, .12, color)
        p.triangle((s * 1.46, .60 if upper else -.65, -.015),
                   (s * 2.53, 1.20 if upper else -1.27, .10),
                   (s * 1.94, .12 if upper else -1.30, .045), .10, 'gold')
    p.chain([a, b, c, d, e, a], .065, .045, 'lead')
    p.capsule(b, d, .045, .045, 'lead')
    p.capsule(b, e, .045, .045, 'lead')
    p.capsule(a, d, .045, .045, 'lead')
    if form == 'hollow':
        # A few remaining panes caught in the broken tracery.
        p.triangle(a, (s * .60, .27 if upper else -.20, .04),
                   (s * .37, -.15 if upper else -.33, .03), .11, 'violet')
        p.capsule((s * 1.48, .77 if upper else -.48, .12),
                  (s * 1.81, .53 if upper else -.83, .13), .045, .015, 'gold')
    if form == 'kindled':
        for x, y, z in (b, c, d):
            flame(p, (x, y, z), .36)


def choirless_seraph():
    m = DungeonModel('choirless_seraph', .095, {
        'violet': (86, 47, 120), 'rose': (155, 57, 109), 'lead': (49, 41, 59),
        'feather': (28, 24, 38), 'gold': (189, 144, 73), 'wax': (235, 210, 159),
        'glow_wax': (255, 211, 115), 'glow_void': (181, 130, 234),
    })

    def body(name, form):
        b = m.part(name)
        gown(b, 4.52, .47, .55, 1.05, 'feather' if form == 'hollow' else 'violet', 'lead')
        b.ellipsoid((0, 4.40, .04), (.69, .55, .44), 'violet')
        b.ellipsoid((0, 4.65, .08), (1.0, .18, .57), 'lead')
        for s in (-1, 1):
            b.chain([(s * .35, 4.62, -.36), (s * .25, 3.45, -.46),
                     (s * .46, 1.18, -.61)], .12, .09, 'rose')
            b.chain([(s * .48, 4.60, -.34), (s * .38, 3.42, -.47),
                     (s * .59, 1.17, -.60)], .035, .035, 'gold')
        # Reliquary on the sternum, kept smaller than the mask.
        ring(b, (0, 4.08, -.48), .22, .05, 'gold', axis='z', n=24)
        b.ellipsoid((0, 4.08, -.49), (.10, .14, .06), 'glow_void')
        for i in range(9):
            a = math.tau * i / 9
            x, z = .97 * math.cos(a), .67 * math.sin(a)
            b.capsule((x, .63, z), (x * 1.03, .12 + (i % 3) * .10, z + .10), .14, .025, 'violet')
            if form == 'kindled':
                flame(b, (x, .58, z), .36)
        if form == 'hollow':
            b.chain([(-.23, 3.40, -.46), (.04, 3.03, -.53), (-.15, 2.56, -.60),
                     (.07, 2.05, -.65)], .055, .04, 'glow_void')

    def head(name, form):
        h = m.part(name)
        h.ellipsoid((0, 0, .02), (.46, .65, .39), 'lead')
        h.ellipsoid((0, -.06, -.30), (.34, .49, .20), 'gold')
        # Deliberately faceless. Only raised brow, nose and candle tears.
        h.capsule((0, .08, -.48), (0, -.20, -.51), .055, .032, 'gold')
        for s in (-1, 1):
            h.chain([(s * .16, .08, -.45), (s * .18, -.21, -.48),
                     (s * .22, -.48 - (s > 0) * .14, -.40)], .043, .021, 'wax')
        if form == 'hollow':
            h.chain([(-.09, .40, -.42), (.02, .17, -.50), (-.05, -.04, -.52),
                     (.13, -.24, -.49)], .05, .035, 'feather')
            h.ellipsoid((.01, .03, -.535), (.045, .08, .018), 'glow_void')
        elif form == 'kindled':
            h.capsule((-.24, .33, -.41), (.22, .33, -.41), .027, .027, 'glow_wax')

    forms = ('base', 'kindled', 'hollow')
    for form in forms:
        suffix = '' if form == 'base' else '_' + form
        body('body' + suffix, form)
        head('head' + suffix, form)
        for s, side in ((-1, 'l'), (1, 'r')):
            for upper, label in ((True, 'upper'), (False, 'lower')):
                _glass_wing(m.part('wing_' + label + '_' + side + suffix), s, upper, form)
    m.joint('head', 'head', (0, 5.26, -.10), 'head')
    j = m.part('jaw')
    j.ellipsoid((0, -.11, -.055), (.235, .17, .13), 'gold')
    j.capsule((-.09, -.10, -.16), (-.10, -.35, -.13), .038, .018, 'wax')
    m.joint('jaw', 'jaw', (0, -.42, -.31), 'jaw', parent_limb='head')
    for s, side in ((-1, 'l'), (1, 'r')):
        for upper, label, y in ((True, 'upper', 4.40), (False, 'lower', 3.74)):
            name = 'wing_' + label + '_' + side
            m.joint(name, name, (s * .63, y, .39), 'wing', -s)
        # The innermost pair is black, fingered feathers, separate from glass.
        w = m.part('wing_inner_' + side)
        w.chain([(0, 0, 0), (s * .67, .83, .08), (s * 1.30, 1.49, .10)], .20, .09, 'feather')
        for i in range(6):
            w.capsule((s * (.23 + i * .17), .26 + i * .17, .05),
                      (s * (.54 + i * .26), .16 + i * .22, -.04), .13, .025, 'feather')
        m.joint('wing_inner_' + side, 'wing_inner_' + side, (s * .50, 4.54, .16), 'wing', -s)
        a = sleeve(m, 'arm_' + side, 1.46, .21, 'violet', 'wax', s)
        a.capsule((s * .04, -.30, -.19), (s * .08, -1.02, -.21), .035, .035, 'gold')
        if s > 0:
            # Three broken organ pipes, each with its own visible dark mouth.
            a.capsule((0, -2.44, -.13), (0, .25, -.13), .07, .065, 'lead')
            for dx, height in ((-.20, .55), (0, .86), (.20, .36)):
                a.capsule((dx, -.52, -.12), (dx, height, -.12), .095, .095, 'gold')
                a.ellipsoid((dx, height + .025, -.12), (.065, .025, .065), 'feather')
                a.box((dx - .048, -.10, -.225), (dx + .048, .06, -.17), 'feather')
            a.box((-.30, -.57, -.24), (.30, -.44, .0), 'lead')
        m.joint('arm_' + side, 'arm_' + side, (s * .87, 4.48, -.10), 'arm', -s, throws=s > 0)
        c = m.part('cloth_' + side)
        c.chain([(0, 0, 0), (s * .21, -1.05, .05), (s * .15, -2.70, .23)], .19, .065, 'violet')
        c.capsule((s * .05, -.20, -.13), (s * .16, -2.61, .13), .032, .027, 'wax')
        m.joint('cloth_' + side, 'cloth_' + side, (s * .50, 3.16, .35), 'cloth', -s)
    halo = m.part('halo')
    ring(halo, (0, 0, 0), .98, .055, 'gold', axis='z', n=56)
    for i, a in enumerate((.25, .80, 1.36, 1.92, 2.48, 2.98, 3.65, 4.38, 5.10, 5.76)):
        x, y = math.cos(a) * .98, math.sin(a) * .98
        if i % 2:
            flame(halo, (x, y, -.025), .30)
        else:
            halo.capsule((x, y, 0), (x, y - .16, 0), .018, .018, 'lead')
            bell(halo, (x, y - .29, 0), .18, metal='gold', inside='feather')
    m.joint('halo', 'halo', (0, 5.36, 0), 'sway')
    m.hand = (0, .86, -.12)
    m.extra = dict(animation_style='cantor', hand_limb='arm_r', hover=.28,
                   bob=.045, waddle=0, flap_rate=1.25, glow_strength=1.2,
                   variants={form: {base: base + '_' + form for base in
                             ('body', 'head', 'wing_upper_l', 'wing_upper_r', 'wing_lower_l', 'wing_lower_r')}
                             for form in ('kindled', 'hollow')})
    return m


def star_eater():
    m = DungeonModel('star_eater', .045, {
        'shell': (42, 42, 65), 'belly': (19, 20, 36), 'fin': (74, 62, 94),
        'gold': (159, 119, 64), 'glow_gold': (251, 204, 105), 'glow_star': (241, 230, 189),
    })
    b = m.part('body')
    b.chain([(0, .29, -.40), (0, .37, -.06), (.12, .66, .40), (.18, .90, .66)],
            .21, .14, 'shell')
    b.ellipsoid((0, .32, -.18), (.19, .20, .37), 'belly')
    for x, y, z in ((-.15, .43, -.43), (.13, .48, -.25), (-.19, .31, -.18),
                     (.19, .38, -.09), (-.15, .49, .03), (.21, .66, .29)):
        b.ellipsoid((x, y, z), (.028, .024, .03), 'glow_star')
    b.chain([(-.16, .35, -.42), (-.19, .28, -.11), (-.10, .45, .16)], .015, .015, 'glow_gold')
    h = m.part('head')
    h.ellipsoid((0, 0, -.08), (.22, .19, .31), 'shell')
    h.ellipsoid((0, -.04, -.33), (.15, .11, .06), 'belly')
    for s in (-1, 1):
        h.ellipsoid((s * .14, .07, -.27), (.038, .032, .025), 'glow_gold')
        h.capsule((s * .10, -.02, -.35), (s * .08, -.08, -.37), .023, .008, 'glow_star')
    m.joint('head', 'head', (0, .26, -.48), 'head')
    t = m.part('tail')
    t.chain([(0, 0, 0), (-.04, .20, .24), (-.26, .21, .43), (-.40, .07, .48)],
            .14, .035, 'shell')
    t.triangle((-.22, .18, .39), (-.24, .44, .41), (-.43, .10, .53), .06, 'fin')
    m.joint('tail', 'tail', (.18, .90, .66), 'tail')
    for s, side in ((-1, 'l'), (1, 'r')):
        w = m.part('wing_' + side)
        w.triangle((0, 0, 0), (s * .31, .15, .16), (s * .22, -.10, .26), .055, 'fin')
        w.capsule((0, 0, 0), (s * .31, .15, .16), .023, .012, 'gold')
        m.joint('wing_' + side, 'wing_' + side, (s * .17, .38, -.02), 'wing', -s)
    m.hand = (0, -.04, -.38)
    m.extra = dict(hand_limb='head', hover=.25, bob=.055, waddle=0, flap_rate=3.0)
    return m


def kintsugi_shade():
    m = DungeonModel('kintsugi_shade', .06, {
        'porcelain': (205, 200, 187), 'shadow': (116, 117, 128), 'void': (24, 24, 39),
        'cloth': (46, 39, 61), 'glow_gold': (255, 204, 92),
    })
    b = m.part('body')
    b.ellipsoid((0, 1.13, .01), (.24, .34, .17), 'void')
    for x, y, rx, ry in ((-.13, 1.28, .16, .22), (.13, 1.23, .15, .27),
                          (-.04, .94, .18, .14)):
        b.ellipsoid((x, y, -.06), (rx, ry, .17), 'porcelain')
    b.chain([(-.05, 1.47, -.18), (.02, 1.28, -.24), (-.06, 1.13, -.25),
             (.08, .97, -.22)], .018, .018, 'glow_gold')
    b.chain([(.02, 1.28, -.24), (.18, 1.36, -.20), (.24, 1.28, -.08)], .016, .016, 'glow_gold')
    gown(b, .88, .54, .22, .29, 'cloth', 'void', folds=6)
    h = m.part('head')
    h.ellipsoid((0, .06, 0), (.20, .25, .17), 'shadow')
    h.ellipsoid((-.025, .055, -.09), (.17, .23, .13), 'porcelain')
    h.chain([(.015, .28, -.15), (-.035, .15, -.215), (.04, .03, -.23),
             (-.02, -.16, -.19)], .017, .017, 'glow_gold')
    for s in (-1, 1):
        h.capsule((s * .045, .07, -.225), (s * .12, .09, -.205), .023, .019, 'void')
    h.ellipsoid((0, -.06, -.225), (.035, .012, .015), 'void')
    m.joint('head', 'head', (0, 1.58, -.02), 'head')
    legs(m, .63, .13, .63, .08, 'shadow', 'porcelain')
    m.parts['leg'].chain([(0, -.13, -.08), (.04, -.31, -.085), (-.015, -.45, -.09)],
                         .013, .013, 'glow_gold')
    for s, side in ((-1, 'l'), (1, 'r')):
        a = m.part('arm_' + side)
        a.capsule((0, 0, 0), (s * .03, -.48, -.03), .075, .065, 'shadow')
        for y in (-.08, -.29, -.49):
            a.ellipsoid((s * .025, y, -.015), (.087, .10, .08), 'porcelain')
        a.chain([(-.02, -.08, -.09), (.04, -.20, -.09), (0, -.35, -.10), (.05, -.50, -.09)],
                .014, .014, 'glow_gold')
        m.joint('arm_' + side, 'arm_' + side, (s * .28, 1.38, 0), 'arm', -s, throws=s > 0)
    m.hand = (.04, -.53, -.10)
    m.extra = dict(hand_limb='arm_r', waddle=.08, bob=.015)
    return m


def astral_reaver():
    m = DungeonModel('astral_reaver', .075, {
        'armor': (43, 43, 60), 'edge': (76, 70, 90), 'void': (13, 15, 27),
        'cape': (42, 30, 57), 'gold': (166, 122, 65),
        'glow_gold': (248, 195, 86), 'glow_star': (243, 235, 191),
    })
    b = m.part('body')
    b.capsule((0, 1.20, 0), (0, 2.32, 0), .35, .42, 'armor')
    b.ellipsoid((0, 2.10, -.15), (.43, .41, .24), 'edge')
    b.chain([(-.24, 2.40, -.32), (-.08, 2.16, -.40), (-.16, 1.91, -.39),
             (.10, 1.65, -.34)], .023, .023, 'glow_gold')
    b.chain([(-.08, 2.16, -.40), (.19, 2.25, -.37), (.32, 2.11, -.33)], .018, .018, 'glow_gold')
    for s in (-1, 1):
        b.ellipsoid((s * .51, 2.38, .01), (.28, .21, .28), 'armor')
        b.triangle((s * .35, 2.48, -.18), (s * .62, 2.70, .03),
                   (s * .79, 2.31, -.13), .11, 'edge')
        b.capsule((s * .36, 2.48, -.22), (s * .68, 2.39, -.24), .023, .023, 'glow_gold')
        b.box((s * .20 - .14, .91, -.32), (s * .20 + .14, 1.39, -.20), 'armor')
    ring(b, (0, 1.43, 0), .36, .055, 'gold', n=24)
    h = m.part('head')
    h.capsule((0, -.10, .01), (0, .23, .01), .24, .20, 'armor')
    h.triangle((-.19, .18, 0), (0, .51, .06), (.19, .18, 0), .13, 'edge')
    h.box((-.19, .035, -.25), (.19, .105, -.19), 'void')
    h.box((-.14, .055, -.27), (.14, .085, -.23), 'glow_star')
    h.chain([(.03, .28, -.19), (-.03, .13, -.25), (.035, -.12, -.25)], .019, .019, 'glow_gold')
    m.joint('head', 'head', (0, 2.67, -.01), 'head')
    legs(m, 1.08, .23, 1.08, .15, 'armor')
    m.parts['leg'].capsule((-.06, -.15, -.14), (.04, -.81, -.14), .017, .017, 'glow_gold')
    for s, side in ((-1, 'l'), (1, 'r')):
        a = sleeve(m, 'arm_' + side, .87, .14, 'armor', 'edge', s)
        a.capsule((-.04, -.23, -.15), (.05, -.65, -.15), .019, .019, 'glow_gold')
        if s > 0:
            a.box((-.28, -.90, -.19), (.28, -.81, -.08), 'gold')
            a.capsule((0, -.89, -.13), (0, -2.14, -.28), .09, .009, 'edge')
            a.capsule((0, -.93, -.22), (0, -2.09, -.34), .032, .01, 'glow_star')
            # One bright four-point star on the blade, rather than a noisy aura.
            a.capsule((-.17, -1.38, -.30), (.17, -1.38, -.30), .018, .018, 'glow_star')
        m.joint('arm_' + side, 'arm_' + side, (s * .54, 2.32, 0), 'arm', -s, throws=s > 0)
    c = m.part('cloth')
    c.triangle((-.40, 0, 0), (.40, 0, 0), (-.49, -1.75, .24), .14, 'cape')
    c.triangle((.40, 0, 0), (.51, -1.51, .28), (-.49, -1.75, .24), .14, 'cape')
    for x, y in ((-.26, -1.35), (.31, -1.15), (.10, -.75)):
        c.ellipsoid((x, y, .14), (.025, .025, .025), 'glow_star')
    m.joint('cloth', 'cloth', (0, 2.35, .37), 'cloth')
    m.hand = (0, -1.40, -.31)
    m.extra = dict(hand_limb='arm_r', waddle=.05, bob=0)
    return m


def unmade_herald():
    m = DungeonModel('unmade_herald', .075, {
        'night': (30, 28, 47), 'fold': (58, 47, 77), 'void': (12, 14, 26),
        'porcelain': (222, 215, 192), 'gold': (162, 120, 64),
        'glow_gold': (252, 201, 100), 'glow_star': (236, 229, 191),
    })
    b = m.part('body')
    gown(b, 1.93, .66, .25, .53, 'night', 'fold', folds=7)
    b.ellipsoid((0, 1.94, .04), (.45, .12, .25), 'fold')
    b.capsule((-.30, 1.95, -.15), (.27, 1.95, -.15), .035, .035, 'gold')
    b.ellipsoid((0, 1.89, -.26), (.085, .095, .035), 'glow_gold')
    for x, y, z in ((-.29, 1.35, -.25), (.23, 1.13, -.33), (-.15, .90, -.34),
                     (.37, .67, -.21), (-.37, .67, -.25), (.16, .50, -.30)):
        b.ellipsoid((x, y, z), (.026, .03, .025), 'glow_star')
    h = m.part('head')
    h.ellipsoid((0, 0, 0), (.28, .38, .105), 'porcelain')
    for s in (-1, 1):
        h.ellipsoid((s * .12, .055, -.10), (.065, .055, .04), 'void')
        h.capsule((s * .12, -.02, -.11), (s * .09, -.18, -.09), .018, .012, 'glow_gold')
    h.capsule((0, .04, -.10), (0, -.10, -.14), .035, .025, 'porcelain')
    h.ellipsoid((0, -.23, -.095), (.045, .025, .02), 'void')
    h.chain([(.08, .32, -.065), (.02, .20, -.10), (.08, .08, -.13)], .016, .016, 'glow_gold')
    m.joint('head', 'head', (0, 2.18, -.22), 'head')
    for s, side in ((-1, 'l'), (1, 'r')):
        a = sleeve(m, 'arm_' + side, .68, .10, 'night', 'porcelain', s)
        a.capsule((s * .05, -.66, -.07), (s * .09, -.82, -.13), .035, .018, 'porcelain')
        m.joint('arm_' + side, 'arm_' + side, (s * .37, 1.89, .03), 'arm', -s, throws=s > 0)
        c = m.part('cloth_' + side)
        c.chain([(0, 0, 0), (s * .14, -.70, .10), (s * .22, -1.49, .24)], .19, .035, 'night')
        c.chain([(s * .12, -.45, -.01), (s * .20, -.91, .03), (s * .24, -1.28, .12)],
                .04, .015, 'fold')
        m.joint('cloth_' + side, 'cloth_' + side, (s * .35, 1.62, .14), 'cloth', -s)
    m.hand = (.09, -.81, -.13)
    m.extra = dict(hand_limb='arm_r', hover=.30, bob=.055, waddle=0)
    return m


def _shard(p, c, size, color):
    x, y, z = c
    rx, ry = size
    p.triangle((x - rx, y, z), (x, y + ry, z), (x + rx, y, z), .14, color)
    p.triangle((x - rx, y, z), (x + rx, y, z), (x, y - ry * .65, z), .14, color)


def oblivara():
    """A quiet god: six offering hands and a face held inside a shattered sun."""
    m = DungeonModel('oblivara', .11, {
        'porcelain': (39, 42, 57), 'edge': (65, 65, 79), 'void': (11, 14, 24),
        'night': (24, 24, 40), 'gold': (171, 131, 68),
        'glow_gold': (255, 205, 102), 'glow_star': (246, 233, 184),
    })

    def body(name, form):
        b = m.part(name)
        # The inner void stays slim: missing shell plates leave real spaces.
        b.capsule((0, 2.65, .12), (0, 5.48, .10), .43, .65, 'void')
        b.ellipsoid((0, 5.29, .08), (1.03, .63, .59), 'porcelain')
        b.ellipsoid((0, 4.25, .04), (.73, .98, .48), 'porcelain')
        b.ellipsoid((0, 3.41, .03), (.76, .35, .47), 'edge')
        # Twelve broad porcelain facets form a heavy ceremonial gown. The
        # surface is intentionally quiet; only a few repaired joins emit.
        for i in range(12):
            a = math.tau * i / 12
            detached = form == 'unmade' and i in (1, 4, 6, 9, 11)
            offset = .24 if detached else 0
            bottom = .31 + (i % 3) * .10 + (.32 if detached else 0)
            half = math.pi / 12 - (.07 if detached else .008)

            def edge(angle, radius, y):
                return (math.cos(angle) * radius, y, math.sin(angle) * radius * .68 + .08)

            # Detached plates have a missing upper section and float outside
            # the silhouette, with actual clear air between neighboring pieces.
            top = 2.67 if detached else 3.47
            tl, tr = [edge(a + d, .64 + offset, top) for d in (-half, half)]
            ml, mr = [edge(a + d, 1.13 + offset, 1.87) for d in (-half, half)]
            bl, br = [edge(a + d, 1.69 + offset, bottom) for d in (-half, half)]
            color = 'night' if i % 4 == 0 else 'porcelain'
            for aa, bb, cc in ((tl, tr, mr), (tl, mr, ml), (ml, mr, br), (ml, br, bl)):
                b.triangle(aa, bb, cc, .17, color)
            if i in (2, 5, 8, 10):
                seam = [edge(a - half, .69 + offset, top - .11),
                        edge(a - half, 1.00 + offset, 2.21),
                        edge(a - half + .07, 1.22 + offset, 1.62),
                        edge(a - half + .04, 1.60 + offset, bottom + .28)]
                b.chain(seam, .012 if form != 'awakened' else .024, .012, 'glow_gold')
        # A quiet diagonal fault, with just two branch lines on the torso.
        for pts in ([(-.47, 5.72, -.43), (-.24, 5.35, -.55), (-.36, 5.06, -.55),
                     (.05, 4.70, -.49), (-.10, 4.19, -.49), (.22, 3.61, -.43)],
                    [(-.36, 5.06, -.55), (-.70, 5.14, -.43), (-.88, 4.99, -.29)],
                    [(.05, 4.70, -.49), (.45, 4.89, -.44), (.59, 4.65, -.35)],
                    [(.48, 5.60, .51), (.18, 5.15, .62), (.36, 4.68, .49)]):
            b.chain(pts, .012 if form != 'awakened' else .026, .012, 'glow_gold')
        # Repeated neck rings recall a votive statue rather than armor.
        for y in (5.69, 5.85, 6.01):
            ring(b, (0, y, .04), .32, .045, 'gold', n=28)
        # Dissolution is geometric and sparse, keeping the hem readable.
        for i in range(16):
            a = math.tau * i / 16
            r = 1.42 + (i % 3) * .13
            x, z = math.cos(a) * r, math.sin(a) * r * .68
            y = .17 + (i % 4) * .16
            _shard(b, (x, y, z), (.09, .14), 'night')
            if i % 2 == 0:
                b.ellipsoid((x, y + .09, z - .08), (.035, .035, .035), 'glow_star')
        b.ellipsoid((.30, .055, -1.16), (.035, .035, .035), 'glow_star')
        if form == 'unmade':
            # A missing diagonal strip divides the chest into porcelain islands.
            b.chain([(-.46, 5.69, -.46), (-.12, 5.29, -.60), (-.30, 4.98, -.60),
                     (.17, 4.57, -.52), (.04, 4.01, -.52)], .11, .09, 'void')
            for s in (-1, 1):
                _shard(b, (s * 1.20, 4.78, -.15), (.24, .43), 'porcelain')
                _shard(b, (s * 1.34, 3.60, .06), (.16, .28), 'edge')
                b.capsule((s * 1.12, 4.72, -.25), (s * 1.23, 4.99, -.25), .028, .028, 'glow_gold')
        elif form == 'awakened':
            # The heart is a small white-gold opening, not a giant light bulb.
            b.ellipsoid((0, 5.03, -.58), (.095, .15, .045), 'glow_star')

    def head(name, form):
        h = m.part(name)
        h.ellipsoid((0, .11, .04), (.61, .77, .43), 'porcelain')
        h.ellipsoid((0, -.01, -.29), (.53, .63, .27), 'edge')
        # Broad cheek planes, raised nose, closed eyelids and a small mouth.
        for s in (-1, 1):
            h.ellipsoid((s * .28, -.13, -.40), (.20, .24, .13), 'edge')
            h.capsule((s * .09, .10, -.565), (s * .36, .17, -.49), .037, .028, 'void')
            if form == 'awakened':
                h.ellipsoid((s * .23, .125, -.57), (.115, .050, .025), 'glow_star')
            else:
                h.capsule((s * .10, .075, -.57), (s * .34, .13, -.52), .014, .014, 'gold')
        h.capsule((0, .14, -.50), (0, -.17, -.61), .072, .047, 'edge')
        h.capsule((-.10, -.31, -.53), (.10, -.31, -.53), .016, .016, 'void')
        h.chain([(-.24, .73, -.18), (-.19, .48, -.43), (-.31, .29, -.50),
                 (-.27, .02, -.56), (-.36, -.17, -.49)],
                .013 if form != 'awakened' else .026, .013, 'glow_gold')
        if form == 'unmade':
            h.chain([(-.24, .73, -.20), (-.18, .45, -.45), (-.29, .27, -.54),
                     (-.23, .03, -.59)], .075, .055, 'void')
            _shard(h, (-.69, .20, -.05), (.12, .23), 'porcelain')
            h.capsule((-.70, .12, -.14), (-.65, .28, -.14), .018, .018, 'glow_gold')

    for form in ('base', 'awakened', 'unmade'):
        suffix = '' if form == 'base' else '_' + form
        body('body' + suffix, form)
        head('head' + suffix, form)
    m.joint('head', 'head', (0, 6.49, -.12), 'head')
    j = m.part('jaw')
    j.ellipsoid((0, -.09, -.025), (.25, .16, .12), 'porcelain')
    j.capsule((.09, .02, -.14), (.05, -.15, -.12), .023, .021, 'glow_gold')
    m.joint('jaw', 'jaw', (0, -.46, -.27), 'jaw', parent_limb='head')

    for s, side in ((-1, 'l'), (1, 'r')):
        # Middle pair hangs from its shoulder and is the cantor's casting pair.
        a = m.part('arm_' + side)
        a.chain([(0, 0, 0), (s * .47, -.66, -.02), (s * .54, -1.33, -.25)],
                .23, .16, 'porcelain')
        a.chain([(s * .11, -.15, -.22), (s * .40, -.59, -.22),
                 (s * .38, -.81, -.23), (s * .55, -1.19, -.38)], .013, .013, 'glow_gold')
        a.ellipsoid((s * .54, -1.42, -.28), (.20, .25, .15), 'porcelain')
        for i in range(3):
            a.capsule((s * (.43 + i * .11), -1.52, -.30),
                      (s * (.43 + i * .11), -1.72, -.37), .045, .025, 'porcelain')
        a.capsule((s * .38, -1.37, -.32), (s * .29, -1.51, -.40), .06, .035, 'porcelain')
        ring(a, (s * .53, -1.21, -.23), .17, .035, 'gold', n=20)
        m.joint('arm_' + side, 'arm_' + side, (s * 1.0, 5.25, .04), 'arm', -s, throws=s > 0)
        # Other hands fan out with space between each pair. The thumbs and
        # forefingers touch in calm mudras; no weapons or clenched fists.
        for tier, y, extent, drop in ((2, 5.63, 1.44, .32), (3, 4.61, 1.14, 1.55)):
            name = 'arm_' + side + str(tier)
            p = m.part(name)
            elbow = (s * extent * .67, -drop - .18, .04)
            wrist = (s * extent, -drop, -.15)
            p.chain([(0, 0, 0), elbow, wrist], .21, .135, 'porcelain')
            p.chain([(s * .10, -.07, -.19), (elbow[0], elbow[1] + .04, -.15),
                     (wrist[0], wrist[1], -.29)], .013, .013, 'glow_gold')
            p.ellipsoid((wrist[0], wrist[1] + .08, -.18), (.19, .14, .18), 'porcelain')
            # Upright gesture loop in the frontal plane and two extended fingers.
            ring(p, (wrist[0] + s * .045, wrist[1] + .25, -.22), .105, .038,
                 'porcelain', axis='z', n=18)
            for i in range(2):
                p.capsule((wrist[0] + s * (.12 + i * .08), wrist[1] + .10, -.15),
                          (wrist[0] + s * (.23 + i * .09), wrist[1] + .29 - i * .07, -.14),
                          .04, .022, 'porcelain')
            ring(p, wrist, .14, .035, 'gold', n=18)
            m.joint(name, name, (s * .91, y, .24 if tier == 2 else .12), 'arm', -s, throws=False)
    h = m.part('halo')
    # A broken sun in relief, behind the mask. Alternating arcs and pointed
    # gold fragments keep an open crown and substantial negative space.
    for i in range(14):
        if i in (3, 8, 12):
            continue
        a = math.tau * i / 14
        radius = 1.25 + (i % 3) * .065
        u, v = math.cos(a), math.sin(a)
        tangent = (-v, u)
        c = (u * radius, v * radius, 0)
        p0 = (c[0] - tangent[0] * .21, c[1] - tangent[1] * .21, 0)
        p1 = (u * (radius + .30), v * (radius + .30), 0)
        p2 = (c[0] + tangent[0] * .21, c[1] + tangent[1] * .21, 0)
        p3 = (u * (radius - .17), v * (radius - .17), 0)
        h.triangle(p0, p1, p2, .13, 'glow_gold')
        h.triangle(p0, p2, p3, .13, 'gold')
        if i % 2 == 0:
            pts = [(math.cos(a + t) * 1.14, math.sin(a + t) * 1.14, .04)
                   for t in (-.12, 0, .12)]
            h.chain(pts, .035, .035, 'glow_gold')
    m.joint('halo', 'halo', (0, 6.50, .72), 'sway')
    for s, side in ((-1, 'l'), (1, 'r')):
        c = m.part('cloth_' + side)
        c.chain([(0, 0, 0), (s * .22, -.82, .12), (s * .38, -2.35, .22)], .19, .035, 'night')
        for i in range(3):
            c.ellipsoid((s * (.19 + i * .07), -.92 - i * .47, -.015 + i * .08),
                        (.028, .028, .028), 'glow_star')
        m.joint('cloth_' + side, 'cloth_' + side, (s * .62, 2.52, .54), 'cloth', -s)
    m.hand = (.54, -1.59, -.37)
    m.extra = dict(animation_style='cantor', hand_limb='arm_r', hover=.24,
                   bob=.025, waddle=0, glow_strength=1.2,
                   variants={form: {'body': 'body_' + form, 'head': 'head_' + form}
                             for form in ('awakened', 'unmade')})
    return m


BUILDERS = {f.__name__: f for f in (
    candle_wraith, bell_imp, censer_bearer, glass_knight, hymn_abbess, bellringer,
    choirless_seraph, star_eater, kintsugi_shade, astral_reaver, unmade_herald, oblivara,
)}
HEIGHTS = dict(zip(BUILDERS, (1.6, 1.0, 1.9, 3.0, 2.4, 3.6, 6.5, 1.3, 1.9, 3.2, 2.6, 8.0)))


def phase_sheet(names, out):
    """Render every boss phase with the real part swaps and child pivots."""
    from PIL import Image, ImageDraw, ImageFont
    rows = []
    font = ImageFont.truetype(str(ROOT / 'fonts/BreeSerif.ttf'), 24)
    for name in names:
        folder = ROOT / 'creatures' / name
        rig = json.loads((folder / 'rig.json').read_text())
        for form, swaps in rig.get('variants', {}).items():
            def origin(limb):
                spec = rig['limbs'][limb]
                at = origin(spec['parent_limb']) if spec.get('parent_limb') else (0, 0, 0)
                return tuple(at[i] + spec['pivot'][i] for i in range(3))
            vox = {}
            for base, at in [('body', (0, 0, 0))] + [(s['part'], origin(n)) for n, s in rig['limbs'].items()]:
                part = swaps.get(base, base)
                frame = rig['parts'][part]['frame_min']
                for suffix in ('', '_glow'):
                    path = folder / (part + suffix + '.vox')
                    if path.exists():
                        for pos, rgb in read_vox(path).items():
                            vox[tuple(pos[i] + frame[i] + at[i] for i in range(3))] = (rgb, bool(suffix))
            row = Image.new('RGB', (1620, 440), '#151b22')
            ImageDraw.Draw(row).text((16, 7), name + ' - ' + form, font=font, fill='#e8e4da')
            for i, yaw in enumerate((0, 35, 90, 200)):
                row.paste(render(vox, 400, 390, yaw=yaw), (8 + i * 402, 43))
            rows.append(row)
    if rows:
        im = Image.new('RGB', (1620, 440 * len(rows)), '#151b22')
        for i, row in enumerate(rows):
            im.paste(row, (0, i * 440))
        im.save(out)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('names', nargs='*', help='Creature ids, or all twelve when omitted')
    parser.add_argument('--sheet', type=Path, help='Write a workshop four-view sheet and boss phase sheet')
    args = parser.parse_args(argv)
    names = args.names or list(BUILDERS)
    unknown = set(names) - BUILDERS.keys()
    if unknown:
        parser.error('Unknown creature ids: ' + ', '.join(sorted(unknown)))
    for name in names:
        m = BUILDERS[name]()
        m.save()
        print(f'{name}: {HEIGHTS[name]:g} m, {m.vs:g} m voxels; ' +
              ', '.join(n + ':' + s['role'] for n, s in m.limbs.items()), flush=True)
    if args.sheet:
        studio.BOLD = str(ROOT / 'fonts/BreeSerif.ttf')
        studio.sheet(names, args.sheet)
        phase_sheet(names, args.sheet.with_name(args.sheet.stem + '_phases.png'))


if __name__ == '__main__':
    main()
