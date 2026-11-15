#!/usr/bin/env python3
"""Rimewake Barrow and Glass Labyrinth sculptures, in meters.

    python3 tools/make_dungeon_creatures_barrow_glass.py
    python3 tools/make_dungeon_creatures_barrow_glass.py jarl_hrimvald solenne
    python3 tools/make_dungeon_creatures_barrow_glass.py --sheet /tmp/barrow.png

Only the fourteen named creature folders are written. No engine or importer is
needed. Boss phase meshes share export frames; combined VOX files include the
head-relative jaws. The workshop's normal painter and three-tone ramps are used.
"""
import argparse
import json
import math
import sys

import monster_studio
from monster_studio import Model, ring, robe, staff, mirror_part
from make_creatures import fit_frame, write_vox
from preview_voxel_batch import ROOT


BARROW = {
    'iron': (76, 99, 121), 'bone': (208, 220, 211),
    'night': (37, 51, 77), 'fur': (167, 190, 202),
    'ice': (170, 215, 233), 'dark': (16, 26, 43),
    'glow_ice': (116, 229, 255), 'glow_heart': (116, 255, 207),
}
GLASS = {
    'glass': (174, 221, 226), 'facet': (195, 193, 228),
    'gold': (210, 168, 91), 'veil': (237, 229, 202),
    'shade': (77, 118, 143), 'dark': (25, 39, 62),
    'glow_cyan': (131, 251, 255), 'glow_rose': (255, 149, 222),
    'glow_amber': (255, 226, 142), 'glow_blue': (154, 173, 255),
}
RAINBOW = ('glow_cyan', 'glow_rose', 'glow_amber', 'glow_blue')


class Sculpture(Model):
    """Workshop export, with shared variant frames and hierarchical rest pose.

    CreatureModel swaps meshes inside the original holder. Frame equality is
    therefore needed even when a phase adds spikes or separates glass shards.
    All correction stays in this generator and in its own output folders.
    """

    def save(self, keep=None):
        folder = super().save(keep)
        rig_path = folder / 'rig.json'
        rig = json.loads(rig_path.read_text())
        painted = {name: self._shade(p.voxels(hollow_above=6000))
                   for name, p in self.parts.items()}
        families = {}
        for swaps in rig.get('variants', {}).values():
            for base, alternate in swaps.items():
                families.setdefault(base, {base}).add(alternate)
        palette = self._full_palette()
        for family in families.values():
            union = {xyz: color for name in family
                     for xyz, color in painted[name].items()}
            lo, size = fit_frame(union)
            lo = tuple(n - 1 for n in lo)
            size = tuple(n + 2 for n in size)
            assert max(size) <= 256
            for name in sorted(family):
                info = {'frame_min': list(lo)}
                for glow, suffix in ((False, ''), (True, '_glow')):
                    vox = {xyz: c for xyz, c in painted[name].items()
                           if c.startswith('glow') == glow}
                    target = folder / (name + suffix + '.vox')
                    if vox:
                        write_vox(str(target), vox, palette, lo, size)
                    elif target.exists():
                        target.unlink()
                    if glow and vox:
                        info['glow'] = True
                    if not glow and not vox:
                        info['solid'] = False
                rig['parts'][name] = info
        rig_path.write_text(json.dumps(rig, indent=2) + '\n')

        def origin(name):
            spec = rig['limbs'][name]
            parent = spec.get('parent_limb')
            q = origin(parent) if parent else (0, 0, 0)
            return tuple(q[i] + spec['pivot'][i] for i in range(3))

        full = dict(painted['body'])
        for name, spec in rig['limbs'].items():
            assert spec['part'] in painted
            pivot = origin(name)
            angle = math.radians(spec.get('yaw', 0))
            ca, sa = math.cos(angle), math.sin(angle)
            for (x, y, z), c in painted[spec['part']].items():
                xyz = (round(ca * x + sa * z + pivot[0]), y + pivot[1],
                       round(-sa * x + ca * z + pivot[2]))
                full[xyz] = c
        lo, size = fit_frame(full)
        assert max(size) <= 256
        write_vox(str(folder / 'model.vox'), full, palette, lo, size)
        return folder


class CutGlass:
    """Open seams in a phase sculpture without changing its local frame."""

    def __init__(self, part, vs):
        self.part, self.vs = part, vs

    def voxels(self, hollow_above=6000):
        vox = self.part.voxels(hollow_above=hollow_above)
        # Broad air gaps divide the chest into suspended plates around the core.
        return {(x, y, z): c for (x, y, z), c in vox.items()
                if c.startswith('glow') or not (
                    abs(y * self.vs - 2.84) < .14
                    or abs(y * self.vs - 3.78) < .13
                    or (abs(y * self.vs - 3.36) < .12 and abs(x * self.vs) > .34)
                    or (2.95 < y * self.vs < 3.65 and z * self.vs > -.40
                        and abs(abs(x * self.vs) - .25) < .065))}


def rune(p, at, scale, color='glow_ice'):
    """A deliberately spare forked rune, drawn on a front-facing surface."""
    x, y, z = at
    p.capsule((x, y - scale, z), (x, y + scale, z), scale * .15, scale * .15, color)
    for sign in (-1, 1):
        p.capsule((x, y, z), (x + sign * scale * .65, y + scale * .60, z),
                  scale * .15, scale * .12, color)


def crystal(p, c, r, height, color='glass', facet='facet', edge=None):
    """A solid pointed hexagonal crystal, with a single broad painted facet."""
    x, y, z = c
    p.capsule((x, y - height * .18, z), (x, y + height * .18, z), r, r, color)
    p.capsule((x, y + height * .18, z), (x, y + height * .5, z), r, .012, color)
    p.capsule((x, y - height * .18, z), (x, y - height * .5, z), r, .012, color)
    a, b = (x, y + height * .5, z), (x, y - height * .5, z)
    q, t = (x - r * .8, y, z - r * .65), (x + r * .5, y, z - r * .86)
    p.triangle(a, q, t, max(.025, r * .18), facet)
    p.triangle(b, q, t, max(.025, r * .18), facet)
    if edge:
        p.chain([a, q, b], r * .10, r * .10, edge)


def lens(p, c, radius, rim='gold', face='glass', glow='glow_cyan', axis='z'):
    ring(p, c, radius, radius * .115, rim, axis=axis, n=32)
    radii = (radius * .84, radius * .84, radius * .15) if axis == 'z' else (
        radius * .84, radius * .15, radius * .84)
    p.ellipsoid(c, radii, face)
    # Only a short arc catches emissive light; the aperture stays readable.
    x, y, z = c
    for i in range(5):
        a = math.radians(32 + i * 12)
        q = (x + math.cos(a) * radius, y + math.sin(a) * radius, z - radius * .08)
        if axis == 'y':
            q = (x + math.cos(a) * radius, y + radius * .08, z + math.sin(a) * radius)
        p.ellipsoid(q, (radius * .09,) * 3, glow)


def boots(m, hip, spread, radius, color='iron', greave='ice'):
    p = m.part('leg')
    p.capsule((0, 0, 0), (0, -hip + radius * .95, 0), radius, radius * .80, color)
    p.ellipsoid((0, -hip * .47, -radius * .6), (radius, radius * 1.05, radius * .65), greave)
    p.ellipsoid((0, -hip + radius * .5 + m.vs * .4, -radius * .45),
                (radius * 1.04, radius * .5, radius * 1.55), color)
    for side, label in ((-1, 'l'), (1, 'r')):
        m.joint('leg_' + label, 'leg', (side * spread, hip, 0), 'leg', -side)


def skull(p, size, helm=False, eyes='glow_ice'):
    p.ellipsoid((0, .03 * size, 0), (.40 * size, .42 * size, .32 * size), 'bone')
    if helm:
        p.ellipsoid((0, .19 * size, .04 * size), (.44 * size, .34 * size, .36 * size), 'iron')
        p.box((-.43 * size, .12 * size, -.32 * size), (.43 * size, .21 * size, .08 * size), 'ice')
    for s in (-1, 1):
        p.ellipsoid((s * .17 * size, .035 * size, -.29 * size),
                    (.13 * size, .11 * size, .09 * size), 'dark')
        p.ellipsoid((s * .17 * size, .04 * size, -.36 * size),
                    (.065 * size, .052 * size, .035 * size), eyes)
    p.triangle((0, -.04 * size, -.35 * size), (-.065 * size, -.18 * size, -.32 * size),
               (.065 * size, -.18 * size, -.32 * size), .04 * size, 'dark')
    p.box((-.21 * size, -.29 * size, -.28 * size), (.21 * size, -.22 * size, -.16 * size), 'dark')
    for x in (-.15, -.05, .05, .15):
        p.box(((x - .025) * size, -.29 * size, -.31 * size),
              ((x + .025) * size, -.18 * size, -.24 * size), 'bone')


def round_shield(p, c, r, frozen=False):
    x, y, z = c
    p.ellipsoid(c, (r, r, r * .18), 'iron')
    ring(p, (x, y, z - r * .10), r * .94, r * .09, 'ice', axis='z', n=32)
    p.ellipsoid((x, y, z - r * .22), (r * .21, r * .21, r * .12), 'bone')
    for side in (-1, 1):
        rune(p, (x + side * r * .53, y + r * .05, z - r * .20), r * .16)
    if frozen:
        for i, dx in enumerate((-.7, -.36, .06, .48, .75)):
            xx = x + dx * r
            yy = y - math.sqrt(1 - dx * dx) * r
            p.capsule((xx, yy + r * .12, z - r * .10),
                      (xx, yy - r * (.24 + .13 * (i % 2)), z - r * .12),
                      r * .09, .012, 'ice')
        p.chain([(x - r * .7, y + r * .5, z - r * .20),
                 (x - r * .18, y + r * .16, z - r * .23),
                 (x + r * .35, y - r * .68, z - r * .19)], r * .06, r * .04, 'glow_ice')


def axe(p, x, lower, upper, width, ice=False):
    """An upright broad axe, offset to its hand; blade lies in the XY plane."""
    z = -.18
    staff(p, (x, lower, z), (x, upper, z), width * .085, 'night')
    material = 'ice' if ice else 'iron'
    # Swept, asymmetric crescent with a separate spine and bright cutting edge.
    a = (x, upper - width * .25, z)
    b = (x + width, upper + width * .08, z)
    c = (x + width * .86, upper - width * .95, z)
    d = (x, upper - width * .68, z)
    p.triangle(a, b, c, width * .22, material)
    p.triangle(a, c, d, width * .22, material)
    p.chain([b, (x + width * 1.05, upper - width * .4, z), c],
            width * .08, width * .05, 'glow_ice' if ice else 'ice')
    p.capsule((x, upper - width * .4, z), (x - width * .37, upper - width * .58, z),
              width * .18, .015, material)
    rune(p, (x + width * .47, upper - width * .4, z - width * .14), width * .17)


def barrow_wight():
    """Exposed ribs, a dented brow and an ice-heavy round shield."""
    m = Sculpture('barrow_wight', .065, BARROW, rough=('night',))
    b = m.part('body')
    b.capsule((0, .72, .03), (0, 1.40, .03), .10, .12, 'bone')
    b.ellipsoid((0, .78, 0), (.24, .16, .16), 'iron')
    for y, width in ((1.05, .19), (1.20, .23), (1.35, .25)):
        for s in (-1, 1):
            b.chain([(0, y + .06, .02), (s * width, y, -.05),
                     (s * width * .5, y - .04, -.18)], .045, .035, 'bone')
    b.ellipsoid((-.28, 1.43, 0), (.18, .13, .20), 'night')
    h = m.part('head')
    skull(h, .45, helm=True)
    m.joint('head', 'head', (0, 1.63, -.02), 'head')
    boots(m, .70, .15, .078, 'bone', 'iron')
    for s, label in ((-1, 'l'), (1, 'r')):
        a = m.part('arm_' + label)
        a.chain([(0, 0, 0), (s * .04, -.27, 0), (s * .01, -.55, -.08)], .065, .048, 'bone')
        a.ellipsoid((0, -.55, -.08), (.08, .075, .075), 'iron')
        if s < 0:
            round_shield(a, (-.12, -.40, -.20), .35, True)
        else:
            a.capsule((0, -.51, -.08), (0, -1.15, -.23), .05, .015, 'iron')
            a.box((-.14, -.65, -.16), (.14, -.59, -.05), 'ice')
        m.joint('arm_' + label, 'arm_' + label, (s * .28, 1.42, 0), 'arm', -s, throws=s > 0)
    m.hand = (0, -1.15, -.23)
    m.extra = dict(hand_limb='arm_r', waddle=.15)
    return m


def rime_hound():
    """Low running wolf, blade-like frost mane and an alert long muzzle."""
    m = Sculpture('rime_hound', .05, BARROW)
    b = m.part('body')
    b.ellipsoid((0, .65, .15), (.24, .28, .60), 'night')
    b.ellipsoid((0, .77, -.30), (.29, .31, .32), 'ice')
    for s in (-1, 1):
        b.chain([(s * .19, .74, -.48), (s * .26, .75, -.02),
                 (s * .18, .69, .46)], .032, .020, 'glow_ice')
    for i in range(5):
        b.capsule((0, .92 - i * .025, -.35 + i * .20),
                  (0, 1.09 - i * .065, -.23 + i * .20), .09, .012, 'ice')
    h = m.part('head')
    h.ellipsoid((0, 0, 0), (.20, .20, .25), 'ice')
    h.ellipsoid((0, -.075, -.25), (.13, .10, .22), 'fur')
    h.ellipsoid((0, -.07, -.43), (.085, .065, .055), 'dark')
    for s in (-1, 1):
        h.capsule((s * .12, .12, .02), (s * .15, .35, .04), .085, .01, 'ice')
        h.ellipsoid((s * .13, .045, -.215), (.070, .065, .055), 'dark')
        h.ellipsoid((s * .13, .05, -.26), (.035, .03, .025), 'glow_ice')
        h.capsule((s * .09, -.12, -.28), (s * .09, -.21, -.28), .025, .01, 'bone')
    m.joint('head', 'head', (0, .87, -.61), 'head')
    for i, z in enumerate((-.37, .53)):
        for s, label in ((-1, 'l'), (1, 'r')):
            name = f'leg_{label}_{i}'
            p = m.part(name)
            p.chain([(0, 0, 0), (s * .025, -.21, .08 if i else -.02),
                     (0, -.46, -.04)], .075, .048, 'ice')
            p.ellipsoid((0, -.49, -.10), (.075, .05, .115), 'fur')
            m.joint(name, name, (s * .19, .54, z), 'leg', -s * (1 if i else -1))
    t = m.part('tail')
    t.chain([(0, 0, 0), (.10, -.03, .29), (.14, -.15, .52), (.10, -.20, .66)], .12, .02, 'ice')
    t.capsule((.14, -.15, .50), (.10, -.20, .66), .05, .015, 'glow_ice')
    m.joint('tail', 'tail', (0, .74, .65), 'tail')
    m.hand = (0, .80, -1.07)
    m.extra = dict(waddle=.08)
    return m


def cairn_crow():
    """A blue-black raven with a heavy beak and rime along broad flight feathers."""
    m = Sculpture('cairn_crow', .045, BARROW)
    b = m.part('body')
    b.ellipsoid((0, .43, .03), (.19, .26, .28), 'dark')
    b.ellipsoid((0, .67, -.15), (.18, .20, .19), 'night')
    b.capsule((0, .65, -.29), (0, .58, -.51), .085, .018, 'iron')
    for s in (-1, 1):
        b.ellipsoid((s * .14, .72, -.29), (.035, .035, .025), 'glow_ice')
        b.capsule((s * .11, .79, -.07), (s * .14, .96, .04), .045, .01, 'fur')
    for i in range(3):
        b.capsule(((i - 1) * .09, .28, .18), ((i - 1) * .14, .14, .57), .065, .035, 'night')
    w = m.part('wing_l')
    w.triangle((0, 0, 0), (-.43, .09, .02), (-.72, -.04, .32), .09, 'night')
    w.triangle((0, 0, 0), (-.72, -.04, .32), (-.12, -.05, .39), .09, 'dark')
    for i in range(6):
        x = -.23 - .105 * i
        w.capsule((x, .01, .12), (x - .10, -.06, .50 - .03 * i), .055, .026, 'iron')
        w.capsule((x - .07, -.04, .37 - .03 * i),
                  (x - .10, -.06, .50 - .03 * i), .03, .018, 'ice')
    m.parts['wing_r'] = mirror_part(m, w)
    for s, label in ((-1, 'l'), (1, 'r')):
        m.joint('wing_' + label, 'wing_' + label, (s * .16, .50, 0), 'wing', -s)
        p = m.part('leg_' + label)
        p.capsule((0, 0, 0), (0, -.15, -.03), .03, .025, 'iron')
        for dx in (-.04, .04):
            p.capsule((0, -.15, -.03), (dx, -.18, -.11), .022, .01, 'ice')
        m.joint('leg_' + label, 'leg_' + label, (s * .08, .24, .03), 'leg', -s)
    m.hand = (0, .66, -.52)
    m.extra = dict(hover=.05, bob=.035, waddle=0, flap_rate=7.0)
    return m


def draugr_huscarl():
    """An axe-bearing iron wall; broad shoulders, visible skull and frost beard."""
    m = Sculpture('draugr_huscarl', .08, BARROW, rough=('fur', 'night'))
    b = m.part('body')
    b.capsule((0, 1.04, .04), (0, 2.05, 0), .35, .45, 'night')
    for y, r in ((1.23, .39), (1.49, .43), (1.78, .46), (2.01, .43)):
        b.ellipsoid((0, y, -.12), (r, .18, .27), 'iron')
    rune(b, (0, 1.76, -.41), .17)
    for s in (-1, 1):
        b.ellipsoid((s * .48, 2.12, .03), (.27, .23, .30), 'fur')
    h = m.part('head')
    skull(h, .66, helm=True)
    for s in (-1, 1):
        h.capsule((s * .30, .19, .02), (s * .42, .44, .04), .075, .015, 'ice')
        h.capsule((s * .12, -.19, -.25), (s * .10, -.45, -.20), .065, .012, 'ice')
    m.joint('head', 'head', (0, 2.36, -.02), 'head')
    boots(m, 1.02, .26, .15, 'night', 'iron')
    for s, label in ((-1, 'l'), (1, 'r')):
        a = m.part('arm_' + label)
        a.capsule((0, 0, 0), (s * .03, -.76, -.08), .17, .145, 'iron')
        a.ellipsoid((0, -.81, -.09), (.16, .15, .16), 'bone')
        if s > 0:
            axe(a, .07, -1.77, .28, .66)
        else:
            a.ellipsoid((-.04, -.42, -.15), (.20, .25, .13), 'ice')
        m.joint('arm_' + label, 'arm_' + label, (s * .57, 2.10, 0), 'arm', -s, throws=s > 0)
    m.hand = (.65, -.38, -.18)
    m.extra = dict(hand_limb='arm_r', waddle=.10)
    return m


def rune_seer():
    """Blindfolded seeress in a dark bell cloak; a forked runestone staff."""
    m = Sculpture('rune_seer', .07, BARROW, rough=('night', 'fur'))
    b = m.part('body')
    robe(b, 1.58, .47, .23, .40, 'night', trim='fur', trim_h=.07)
    b.ellipsoid((0, 1.57, .02), (.40, .15, .29), 'fur')
    for x in (-.19, .19):
        b.chain([(x, 1.45, -.18), (x * 1.1, 1.03, -.28),
                 (x * 1.4, .45, -.30)], .037, .045, 'iron')
        for y in (.62, .91, 1.20):
            rune(b, (x * 1.15, y, -.32), .055, 'glow_heart')
    h = m.part('head')
    h.ellipsoid((0, 0, .03), (.21, .27, .20), 'fur')
    h.ellipsoid((0, -.015, -.12), (.145, .19, .12), 'bone')
    h.box((-.17, -.015, -.24), (.17, .075, -.17), 'iron')
    rune(h, (0, .03, -.26), .05)
    for s in (-1, 1):
        h.chain([(s * .15, .04, 0), (s * .21, -.23, -.07),
                 (s * .18, -.51, -.10)], .06, .035, 'fur')
    m.joint('head', 'head', (0, 1.87, -.03), 'head')
    boots(m, .45, .16, .07, 'night', 'iron')
    for s, label in ((-1, 'l'), (1, 'r')):
        p = m.part('arm_' + label)
        p.capsule((0, 0, 0), (s * .04, -.52, -.03), .095, .13, 'night')
        ring(p, (s * .04, -.49, -.03), .13, .035, 'fur', n=16)
        p.ellipsoid((s * .04, -.62, -.05), (.07, .08, .06), 'bone')
        if s > 0:
            staff(p, (.06, -1.47, -.11), (.06, .29, -.11), .04, 'iron')
            crystal(p, (.06, .42, -.11), .13, .47, 'ice', 'fur')
            rune(p, (.06, .42, -.24), .12, 'glow_heart')
            for side in (-1, 1):
                p.capsule((.06, .20, -.11), (.06 + side * .19, .49, -.08), .045, .015, 'ice')
        m.joint('arm_' + label, 'arm_' + label, (s * .36, 1.53, 0), 'arm', -s, throws=s > 0)
    m.hand = (.06, .64, -.11)
    m.extra = dict(hand_limb='arm_r', waddle=.10)
    return m


def frostbound_shieldmaiden():
    """Sigrun's arm and towering shield are one glacier; braided warrior face."""
    m = Sculpture('frostbound_shieldmaiden', .07, BARROW, rough=('fur',))
    b = m.part('body')
    robe(b, 2.23, .77, .31, .48, 'night', trim='iron')
    b.ellipsoid((0, 2.10, -.08), (.40, .43, .25), 'iron')
    b.ellipsoid((0, 2.36, .06), (.58, .17, .36), 'fur')
    rune(b, (0, 2.11, -.36), .17)
    for s in (-1, 1):
        b.ellipsoid((s * .47, 2.35, 0), (.24, .19, .23), 'iron')
    h = m.part('head')
    skull(h, .57, helm=True)
    h.capsule((0, .19, .04), (0, .40, .03), .09, .015, 'ice')
    for s in (-1, 1):
        h.chain([(s * .20, .03, .04), (s * .29, -.30, -.01),
                 (s * .24, -.68, -.10)], .09, .055, 'fur')
        for y in (-.22, -.40, -.57):
            ring(h, (s * .26, y, -.05), .07, .023, 'iron', n=12)
    m.joint('head', 'head', (0, 2.80, 0), 'head')
    boots(m, .85, .25, .125, 'iron', 'ice')
    a = m.part('arm_l')
    a.capsule((0, 0, 0), (-.07, -.64, -.06), .17, .20, 'ice')
    round_shield(a, (-.19, -.65, -.27), .72, True)
    # The ice web joins the shield to her upper arm, rather than a loose prop.
    for i in range(3):
        a.capsule((.08, -.12 - .13 * i, -.10),
                  (-.40 + .18 * i, -.60 - .16 * i, -.41), .11, .045, 'ice')
    m.joint('arm_l', 'arm_l', (-.54, 2.34, 0), 'arm', 1, throws=False, amount=.5)
    a = m.part('arm_r')
    a.capsule((0, 0, 0), (0, -.77, -.06), .14, .12, 'iron')
    a.ellipsoid((0, -.84, -.08), (.13, .12, .12), 'bone')
    a.capsule((0, -.83, -.09), (0, -1.96, -.36), .08, .015, 'ice')
    a.capsule((0, -1.04, -.17), (0, -1.84, -.34), .022, .015, 'glow_ice')
    a.box((-.23, -1.06, -.19), (.23, -.97, -.07), 'iron')
    m.joint('arm_r', 'arm_r', (.56, 2.34, 0), 'arm', -1, throws=True)
    m.hand = (0, -1.96, -.36)
    m.extra = dict(hand_limb='arm_r', waddle=.07)
    return m


def jarl_hrimvald():
    """Hrimvald: an ice-crowned skull in a wolf mantle, with a great ice axe."""
    m = Sculpture('jarl_hrimvald', .09, BARROW, rough=('fur',))

    def body(name, phase):
        b = m.part(name)
        cloak = 'bone' if phase == 'wrath' else 'night'
        b.capsule((0, 1.70, .10), (0, 3.95, .04), .67, .84, 'night')
        # Broad but flat cloak, not a solid sphere behind the body.
        b.triangle((-.90, 4.18, .45), (.90, 4.18, .45), (-1.15, .70, .90), .27, cloak)
        b.triangle((.90, 4.18, .45), (1.15, .70, .90), (-1.15, .70, .90), .27, cloak)
        for x in (-.90, -.45, 0, .45, .90):
            b.capsule((x, 3.95, .65), (x * 1.15, .66 + .16 * abs(x), 1.0), .13, .18, cloak)
        # Stepped iron lamellae and an inset window for the thawed heart.
        for i, y in enumerate((1.65, 2.12, 2.59, 3.06, 3.53)):
            b.ellipsoid((0, y, -.12), (.76 + .035 * i, .29, .58), 'iron')
        b.ellipsoid((0, 3.30, -.60), (.41, .48, .16), 'ice')
        if phase == 'thaw':
            b.ellipsoid((0, 3.30, -.73), (.29, .34, .14), 'dark')
            b.ellipsoid((0, 3.30, -.84), (.16, .23, .07), 'glow_heart')
            for s in (-1, 1):
                b.chain([(s * .12, 3.37, -.79), (s * .40, 3.66, -.67),
                         (s * .58, 3.48, -.63), (s * .70, 3.95, -.51)], .045, .035, 'glow_heart')
                b.chain([(s * .17, 3.15, -.78), (s * .44, 2.88, -.68),
                         (s * .64, 2.56, -.64)], .04, .025, 'glow_heart')
        else:
            rune(b, (0, 3.30, -.79), .26, 'glow_heart' if phase == 'wrath' else 'glow_ice')
        for s in (-1, 1):
            for y in (1.72, 2.21, 2.69):
                rune(b, (s * .48, y, -.66), .13,
                     'glow_ice' if phase == 'wrath' else 'ice')
            b.ellipsoid((s * .96, 4.13, .02), (.51, .34, .47), 'fur')
            for i in range(4):
                b.capsule((s * (.72 + .16 * i), 4.10, -.24),
                          (s * (.80 + .18 * i), 3.74 - .10 * (i % 2), -.35), .12, .025, 'fur')
        # A recognizable wolf skull draped over his left shoulder.
        b.ellipsoid((-.98, 4.35, -.06), (.30, .22, .40), 'fur')
        b.ellipsoid((-.98, 4.24, -.43), (.20, .13, .25), 'bone')
        b.ellipsoid((-.98, 4.23, -.65), (.11, .09, .07), 'dark')
        for x in (-1.15, -.81):
            b.capsule((x, 4.48, .02), (x, 4.70, .08), .10, .015, 'fur')
            b.ellipsoid((x, 4.35, -.36), (.055, .05, .04), 'glow_ice')

    def head(name, phase):
        h = m.part(name)
        skull(h, 1.32)
        # The seven points form a jagged crown with breathing space around it.
        ring(h, (0, .40, .02), .51, .10, 'iron', n=28)
        for i in range(7):
            a = i * math.tau / 7
            x, z = math.cos(a) * .47, math.sin(a) * .40
            height = .98 if i in (1, 2) else .64 + .12 * (i % 2)
            h.capsule((x, .42, z), (x * 1.32, height, z * 1.35), .13, .015, 'ice')
            if phase == 'wrath':
                h.capsule((x * 1.14, .65, z * 1.17), (x * 1.32, height, z * 1.35),
                          .05, .018, 'glow_ice')
        if phase == 'thaw':
            h.chain([(-.40, .28, -.30), (-.19, .13, -.46),
                     (-.26, -.06, -.44)], .04, .035, 'glow_heart')

    def jaw(name, phase):
        j = m.part(name)
        j.ellipsoid((0, -.08, -.16), (.39, .18, .23), 'bone')
        j.box((-.30, -.01, -.38), (.30, .07, -.21), 'dark')
        for x in (-.23, -.08, .08, .23):
            j.box((x - .04, .0, -.40), (x + .04, .10, -.32), 'bone')
        # Separate pointed locks preserve a skull face above an icicle beard.
        for i, x in enumerate((-.36, -.18, 0, .18, .36)):
            j.capsule((x, -.15, -.34), (x * .88, -.69 - .20 * (2 - abs(i - 2)), -.60),
                      .09, .012, 'ice')
        if phase == 'wrath':
            j.capsule((0, -.20, -.42), (0, -1.02, -.60), .035, .015, 'glow_ice')

    for phase in ('base', 'wrath', 'thaw'):
        suffix = '' if phase == 'base' else '_' + phase
        body('body' + suffix, phase)
        head('head' + suffix, phase)
        jaw('jaw' + suffix, phase)
    m.joint('head', 'head', (0, 5.02, -.06), 'head')
    m.joint('jaw', 'jaw', (0, -.34, -.43), 'jaw', parent_limb='head')
    boots(m, 1.65, .48, .27, 'night', 'iron')
    for s, label in ((-1, 'l'), (1, 'r')):
        p = m.part('arm_' + label)
        p.chain([(0, 0, 0), (s * .12, -.64, -.04), (s * .08, -1.43, -.19)], .28, .23, 'iron')
        p.ellipsoid((s * .08, -1.48, -.19), (.25, .24, .26), 'bone')
        ring(p, (s * .10, -.94, -.10), .25, .07, 'ice', n=20)
        rune(p, (s * .10, -.67, -.29), .18)
        if s > 0:
            # Entire axe belongs to arm_r. The long grip has room for two hands.
            axe(p, .10, -3.32, .31, 1.18, ice=True)
            ring(p, (.10, -1.83, -.18), .12, .045, 'ice', n=16)
        else:
            for dx in (-.13, 0, .13):
                p.capsule((dx, -1.54, -.29), (dx, -1.80, -.35), .065, .035, 'bone')
        m.joint('arm_' + label, 'arm_' + label, (s * 1.18, 4.02, .0), 'arm', -s, throws=s > 0)
    cloth = m.part('cloth')
    cloth.capsule((0, 0, 0), (0, -1.38, .14), .15, .11, 'fur')
    cloth.capsule((0, -1.30, .14), (0, -1.76, .20), .14, .02, 'ice')
    for s, label in ((-1, 'l'), (1, 'r')):
        m.joint('cloth_' + label, 'cloth', (s * .92, 2.22, .61), 'cloth', -s)
    m.hand = (1.34, -.16, -.18)
    m.extra = dict(animation_style='cantor', hand_limb='arm_r', waddle=.045,
                   glow_strength=1.2, pixel_art=True, material_jitter=0,
                   variants={phase: {part: part + '_' + phase for part in ('body', 'head', 'jaw')}
                             for phase in ('wrath', 'thaw')})
    return m


def glass_mite():
    """A split crystal carapace, six gold legs and a small cyan face."""
    m = Sculpture('glass_mite', .04, GLASS)
    b = m.part('body')
    b.ellipsoid((0, .36, .08), (.27, .17, .35), 'shade')
    for s in (-1, 1):
        crystal(b, (s * .135, .49, .12), .19, .54, 'glass', 'facet')
        b.capsule((s * .05, .63, -.04), (s * .05, .63, .32), .022, .022, 'glow_cyan')
    b.ellipsoid((0, .35, -.33), (.19, .14, .17), 'glass')
    for s in (-1, 1):
        b.ellipsoid((s * .105, .39, -.47), (.042, .04, .025), 'glow_cyan')
        b.chain([(s * .10, .44, -.35), (s * .19, .57, -.48),
                 (s * .25, .61, -.53)], .025, .015, 'gold')
        b.chain([(s * .12, .27, -.42), (s * .18, .22, -.57),
                 (s * .08, .23, -.60)], .035, .015, 'gold')
        for i, z in enumerate((-.20, .06, .30)):
            name = f'leg_{"l" if s < 0 else "r"}_{i}'
            p = m.part(name)
            p.chain([(0, 0, 0), (s * .22, -.04, .03),
                     (s * .30, -.21, -.02)], .035, .022, 'gold')
            m.joint(name, name, (s * .20, .25, z), 'leg', s * (-1 if i % 2 else 1), amount=.5)
    m.hand = (0, .38, -.49)
    m.extra = dict(waddle=.10)
    return m


def mirror_wisp():
    """An upright silver-blue shard suspended in a thin tilted-looking ring."""
    m = Sculpture('mirror_wisp', .045, GLASS)
    b = m.part('body')
    crystal(b, (0, .61, 0), .17, 1.05, 'shade', 'glass', 'glow_cyan')
    b.triangle((-.13, .60, -.14), (.06, .95, -.09), (.10, .48, -.14), .04, 'veil')
    ring(b, (0, .61, 0), .40, .026, 'gold', axis='z', n=40)
    for i in range(8):
        a = i * math.tau / 8
        b.ellipsoid((math.cos(a) * .40, .61 + math.sin(a) * .40, -.02),
                    (.035,) * 3, 'glow_amber')
    b.ellipsoid((0, .65, -.18), (.045, .09, .025), 'glow_cyan')
    p = m.part('tail')
    crystal(p, (0, -.07, 0), .06, .20, 'glass', 'facet', 'glow_cyan')
    m.joint('tail', 'tail', (0, .13, 0), 'sway')
    m.hand = (0, .75, -.23)
    m.extra = dict(hover=.10, bob=.045, waddle=0)
    return m


def lens_crawler():
    """A broad squat crab, with an upward-facing optical lens as its shell."""
    m = Sculpture('lens_crawler', .045, GLASS)
    b = m.part('body')
    b.ellipsoid((0, .37, 0), (.38, .18, .33), 'shade')
    b.ellipsoid((0, .60, .06), (.43, .27, .40), 'glass')
    lens(b, (0, .85, .06), .44, axis='y')
    ring(b, (0, .88, .06), .24, .026, 'facet', n=32)
    b.ellipsoid((0, .92, .06), (.11, .06, .11), 'glow_cyan')
    for s in (-1, 1):
        b.capsule((s * .18, .43, -.21), (s * .23, .58, -.41), .045, .035, 'gold')
        b.ellipsoid((s * .23, .59, -.43), (.065, .06, .055), 'dark')
        b.ellipsoid((s * .23, .60, -.48), (.035, .035, .022), 'glow_amber')
        for i, z in enumerate((-.20, .04, .27)):
            name = f'leg_{"l" if s < 0 else "r"}_{i}'
            p = m.part(name)
            p.chain([(0, 0, 0), (s * .30, -.03, .08),
                     (s * .43, -.235, .02)], .055, .025, 'glass')
            p.ellipsoid((s * .28, -.04, .08), (.075, .06, .07), 'gold')
            m.joint(name, name, (s * .30, .28, z), 'leg', s * (-1 if i % 2 else 1), amount=.5)
        name = 'arm_' + ('l' if s < 0 else 'r')
        p = m.part(name)
        p.chain([(0, 0, 0), (s * .15, -.05, -.20), (s * .19, -.13, -.40)], .065, .075, 'gold')
        for dx in (-.06, .06):
            p.capsule((s * .19, -.13, -.40), (s * .19 + dx, -.12, -.56), .065, .018, 'glass')
        m.joint(name, name, (s * .29, .36, -.22), 'arm', -s, throws=s > 0)
    m.hand = (.19, -.12, -.56)
    m.extra = dict(hand_limb='arm_r', waddle=.08)
    return m


def prism_golem():
    """Heavy lower limbs, large hexagonal shoulders and a caged rainbow heart."""
    m = Sculpture('prism_golem', .08, GLASS)
    b = m.part('body')
    crystal(b, (0, 1.70, .08), .49, 1.46, 'glass', 'facet')
    b.ellipsoid((0, 1.78, -.40), (.26, .35, .12), 'dark')
    for i, c in enumerate(RAINBOW):
        b.capsule((-.13 + .085 * i, 1.59, -.51), (-.13 + .085 * i, 1.96, -.51), .035, .035, c)
    for s in (-1, 1):
        crystal(b, (s * .51, 2.15, .02), .27, .84, 'glass', 'facet', 'glow_cyan')
        b.capsule((s * .10, 1.3, -.39), (s * .37, 1.07, -.23), .045, .035, 'gold')
    h = m.part('head')
    crystal(h, (0, .02, 0), .22, .67, 'glass', 'facet')
    h.box((-.17, -.015, -.23), (.17, .075, -.17), 'dark')
    for s in (-1, 1):
        h.box((s * .09 - .04, .01, -.26), (s * .09 + .04, .055, -.21), 'glow_amber')
    m.joint('head', 'head', (0, 2.62, 0), 'head')
    boots(m, 1.0, .30, .20, 'shade', 'glass')
    for s, label in ((-1, 'l'), (1, 'r')):
        p = m.part('arm_' + label)
        p.capsule((0, 0, 0), (s * .07, -.62, -.02), .14, .14, 'shade')
        crystal(p, (s * .07, -.44, -.02), .22, .58, 'glass', 'facet')
        p.ellipsoid((s * .08, -.88, -.09), (.23, .23, .23), 'glass')
        p.capsule((s * .08, -.67, -.22), (s * .08, -.96, -.25), .03, .03, 'glow_cyan')
        m.joint('arm_' + label, 'arm_' + label, (s * .64, 2.17, 0), 'arm', -s, throws=s > 0)
    m.hand = (.08, -.87, -.34)
    m.extra = dict(hand_limb='arm_r', waddle=.10)
    return m


def mirror_dervish():
    """A veiled dancer with an asymmetric flaring skirt and two curved blades."""
    m = Sculpture('mirror_dervish', .07, GLASS)
    b = m.part('body')
    robe(b, 1.54, .52, .19, .39, 'veil', trim='gold', trim_h=.06)
    b.capsule((0, 1.47, 0), (0, 1.69, 0), .21, .23, 'shade')
    b.capsule((-.15, 1.65, -.16), (.14, 1.06, -.23), .055, .055, 'gold')
    h = m.part('head')
    h.ellipsoid((0, 0, .02), (.19, .25, .19), 'veil')
    h.ellipsoid((0, -.02, -.13), (.12, .16, .08), 'glass')
    h.box((-.15, -.02, -.22), (.15, .07, -.16), 'gold')
    h.ellipsoid((0, .02, -.24), (.035, .03, .02), 'glow_amber')
    m.joint('head', 'head', (0, 1.91, 0), 'head')
    boots(m, .62, .15, .075, 'gold', 'glass')
    for s, label in ((-1, 'l'), (1, 'r')):
        p = m.part('arm_' + label)
        p.chain([(0, 0, 0), (s * .16, -.24, -.02), (s * .26, -.45, -.13)], .07, .065, 'veil')
        p.ellipsoid((s * .26, -.47, -.13), (.075, .07, .07), 'gold')
        # Mirror blade curves outward, clear of the skirt silhouette.
        p.triangle((s * .26, -.50, -.14), (s * .69, -.86, -.18),
                   (s * .46, -1.12, -.24), .07, 'glass')
        p.triangle((s * .26, -.50, -.14), (s * .46, -1.12, -.24),
                   (s * .20, -.93, -.20), .06, 'facet')
        p.chain([(s * .69, -.86, -.18), (s * .46, -1.12, -.24),
                 (s * .20, -.93, -.20)], .022, .015, 'glow_cyan')
        m.joint('arm_' + label, 'arm_' + label, (s * .25, 1.62, 0), 'arm', -s, throws=s > 0)
        cloth = m.part('cloth_' + label)
        cloth.triangle((0, 0, 0), (s * .48, -.52, .16), (s * .27, -.88, .25), .06, 'veil')
        cloth.chain([(0, 0, 0), (s * .48, -.52, .16), (s * .27, -.88, .25)], .027, .025, 'gold')
        m.joint('cloth_' + label, 'cloth_' + label, (s * .20, 1.26, .13), 'cloth', -s)
    m.hand = (.46, -1.12, -.24)
    m.extra = dict(hand_limb='arm_r', waddle=.24)
    return m


def the_refractor():
    """A single huge watching eye suspended within a loose optical instrument."""
    m = Sculpture('the_refractor', .07, GLASS)
    b = m.part('body')
    lens(b, (0, 1.62, 0), .58, face='veil', glow='glow_amber')
    b.ellipsoid((0, 1.62, -.12), (.30, .32, .10), 'shade')
    b.ellipsoid((0, 1.62, -.21), (.21, .24, .06), 'glow_cyan')
    b.ellipsoid((0, 1.62, -.27), (.075, .18, .04), 'dark')
    b.ellipsoid((-.08, 1.72, -.31), (.05, .05, .02), 'veil')
    ring(b, (0, 1.62, .14), .82, .042, 'gold', axis='z', n=40)
    # Unequal lens sizes and distinct free gaps keep this from reading as a coin.
    for i in range(7):
        a = math.pi / 2 + i * math.tau / 7
        radius = 1.02 if i % 2 else 1.09
        x, y = math.cos(a) * radius, 1.62 + math.sin(a) * radius
        name = f'lens_{i}'
        p = m.part(name)
        lens(p, (0, 0, 0), .27 if i % 2 else .34, glow=RAINBOW[i % 4])
        # All decorative orbit pieces sway around their own centers.
        m.joint(name, name, (x, y, .07 + (i % 2) * .12), 'sway', (-1) ** i, amount=.4)
    h = m.part('head')
    crystal(h, (0, .10, 0), .11, .36, 'glass', 'facet', 'glow_amber')
    m.joint('head', 'head', (0, 2.88, .08), 'head')
    for s, label in ((-1, 'l'), (1, 'r')):
        p = m.part('arm_' + label)
        p.chain([(0, 0, 0), (s * .12, -.27, 0), (s * .04, -.51, -.06)], .045, .045, 'gold')
        crystal(p, (s * .04, -.64, -.06), .11, .29, 'glass', 'facet', 'glow_cyan')
        m.joint('arm_' + label, 'arm_' + label, (s * .68, 1.19, 0), 'arm', -s, throws=s > 0)
    m.hand = (.04, -.76, -.06)
    m.extra = dict(hover=.07, bob=.035, waddle=0, hand_limb='arm_r')
    return m


def solenne():
    """The Prism Oracle: four hands, an open sun halo and a luminous glass heart."""
    m = Sculpture('solenne', .09, GLASS)

    def body(name, phase):
        b = m.part(name)
        glass = 'shade' if phase == 'eclipse' else 'glass'
        facet = 'dark' if phase == 'eclipse' else 'facet'
        # Long clear torso above a layered white-gold bell veil.
        # Shallow overlapping tiers keep the hem flat, unlike a capsule's cap.
        for i in range(12):
            t = i / 11
            y = 2.75 - 2.30 * t
            radius = .34 + .66 * t ** 1.25
            b.ellipsoid((0, y, 0), (radius, .17, radius * .80), 'veil')
        ring(b, (0, .38, 0), .98, .055, 'gold', n=48)
        for i in range(10):
            a = i * math.tau / 10
            x, z = math.cos(a), math.sin(a)
            b.capsule((x * .33, 2.70, z * .26), (x * 1.00, .38, z * .80),
                      .065, .10, 'gold' if i in (2, 6) else 'veil')
        crystal(b, (0, 3.32, 0), .54, 1.87, glass, facet)
        b.ellipsoid((0, 3.38, -.48), (.30, .46, .11), 'gold')
        b.ellipsoid((0, 3.38, -.58), (.23, .38, .10), 'dark')
        if phase != 'eclipse':
            for i, c in enumerate(RAINBOW):
                b.capsule((-.15 + i * .10, 3.12, -.68),
                          (-.15 + i * .10, 3.64, -.68), .043, .043, c)
            b.ellipsoid((0, 3.39, -.74), (.09, .12, .04), 'glow_amber')
        else:
            # Dark center surrounded by a cold inverted outline, no bright fill.
            ring(b, (0, 3.38, -.65), .31, .035, 'glow_blue', axis='z', n=32)
            b.ellipsoid((0, 3.38, -.69), (.23, .29, .04), 'dark')
        for s in (-1, 1):
            crystal(b, (s * .51, 3.85, .04), .22, .63, glass, facet)
            b.capsule((s * .36, 2.81, -.25), (s * .71, 1.39, -.58), .045, .055, 'gold')
        if phase == 'refracted':
            for s in (-1, 1):
                for i in range(3):
                    crystal(b, (s * (.69 + .11 * (i % 2)), 2.25 + .51 * i, .08),
                            .12, .35, 'glass', 'facet', RAINBOW[i])
            m.parts[name] = CutGlass(b, m.vs)

    def head(name, phase):
        h = m.part(name)
        glass = 'shade' if phase == 'eclipse' else 'glass'
        crystal(h, (0, .04, 0), .32, .95, glass, 'facet' if phase != 'eclipse' else 'dark')
        h.ellipsoid((0, -.04, -.21), (.24, .31, .13), glass)
        # The broad blindfold is legible across every phase, without false eyes.
        h.box((-.30, -.005, -.34), (.30, .13, -.22), 'gold')
        h.capsule((0, -.03, -.34), (0, -.18, -.38), .045, .025, glass)
        h.box((-.08, -.25, -.35), (.08, -.22, -.30), 'shade')
        # Sun-disc behind the face: open center, eight round optical apertures.
        ring(h, (0, .05, .31), 1.13, .055, 'gold', axis='z', n=48)
        for i in range(8):
            a = i * math.tau / 8
            x, y = math.cos(a), math.sin(a)
            lens(h, (x * 1.13, .05 + y * 1.13, .30), .23,
                 face='dark' if phase == 'eclipse' else 'glass',
                 glow='glow_blue' if phase == 'eclipse' else RAINBOW[i % 4])
            h.capsule((x * 1.40, .05 + y * 1.40, .30),
                      (x * 1.51, .05 + y * 1.51, .30), .045, .012, 'gold')
        if phase == 'refracted':
            h.capsule((-.27, -.15, -.13), (-.42, -.30, -.17), .07, .025, 'glow_cyan')

    def jaw(name, phase):
        j = m.part(name)
        j.ellipsoid((0, -.04, -.05), (.18, .11, .14),
                    'shade' if phase == 'eclipse' else 'glass')
        j.capsule((-.13, -.09, -.14), (.13, -.09, -.14), .028, .028, 'gold')

    for phase in ('base', 'refracted', 'eclipse'):
        suffix = '' if phase == 'base' else '_' + phase
        body('body' + suffix, phase)
        head('head' + suffix, phase)
        jaw('jaw' + suffix, phase)
    m.joint('head', 'head', (0, 4.35, -.02), 'head')
    m.joint('jaw', 'jaw', (0, -.26, -.24), 'jaw', parent_limb='head')
    # Four arms all use animated roles. The lower pair share the boss's poses.
    for lower in (False, True):
        for s, label in ((-1, 'l'), (1, 'r')):
            name = ('arm_low_' if lower else 'arm_') + label
            p = m.part(name)
            elbow_x = s * (.36 if lower else .40)
            hand_x = s * (.48 if lower else .70)
            p.chain([(0, 0, 0), (elbow_x, -.43, -.02), (hand_x, -.84, -.12)], .13, .09, 'glass')
            crystal(p, (elbow_x, -.43, -.02), .16, .34, 'glass', 'facet')
            ring(p, (hand_x, -.80, -.12), .12, .033, 'gold', n=16)
            p.ellipsoid((hand_x, -.92, -.15), (.12, .12, .11), 'veil')
            c = RAINBOW[(0 if s < 0 else 1) + (2 if lower else 0)]
            crystal(p, (hand_x, -1.14, -.18), .14, .49, 'glass', 'facet', c)
            p.ellipsoid((hand_x, -1.13, -.31), (.05, .09, .035), c)
            m.joint(name, name, (s * (.60 if lower else .64), 3.12 if lower else 3.89,
                                 .22 if lower else 0), 'arm', -s, throws=name == 'arm_r')
    # Two flowing veil panels with independent secondary motion.
    for s, label in ((-1, 'l'), (1, 'r')):
        p = m.part('cloth_' + label)
        p.triangle((0, 0, 0), (s * .72, -1.57, .42), (s * .35, -2.90, .58), .10, 'veil')
        p.triangle((0, 0, 0), (s * .35, -2.90, .58), (-s * .14, -1.95, .38), .10, 'veil')
        p.chain([(0, 0, 0), (s * .72, -1.57, .42), (s * .35, -2.90, .58)], .045, .045, 'gold')
        m.joint('cloth_' + label, 'cloth_' + label, (s * .48, 3.43, .39), 'cloth', -s)
    m.hand = (.70, -1.38, -.18)
    m.extra = dict(animation_style='cantor', hand_limb='arm_r', hover=.15,
                   bob=.06, waddle=0, glow_strength=1.2, pixel_art=True, material_jitter=0,
                   variants={phase: {part: part + '_' + phase for part in ('body', 'head', 'jaw')}
                             for phase in ('refracted', 'eclipse')})
    return m


BUILDERS = {f.__name__: f for f in (
    barrow_wight, rime_hound, cairn_crow, draugr_huscarl, rune_seer,
    frostbound_shieldmaiden, jarl_hrimvald, glass_mite, mirror_wisp,
    lens_crawler, prism_golem, mirror_dervish, the_refractor, solenne)}


def main(argv):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('names', nargs='*', help='Creature ids; omitted builds all fourteen')
    parser.add_argument('--sheet', metavar='PNG', help='Render workshop review sheet')
    args = parser.parse_args(argv)
    names = args.names or list(BUILDERS)
    unknown = set(names) - BUILDERS.keys()
    if unknown:
        parser.error('Unknown creatures: ' + ', '.join(sorted(unknown)))
    for name in names:
        m = BUILDERS[name]()
        folder = m.save()
        vox = monster_studio._assemble(folder)
        height = (max(p[1] for p in vox) + 1) * m.vs + m.extra.get('hover', 0)
        print(f'{name}: height={height:.3f} m; voxel_size={m.vs:g} m; limbs='
              + ', '.join(m.limbs), flush=True)
    if args.sheet:
        # Use the shared game font without changing the workshop source file.
        monster_studio.BOLD = str(ROOT / 'fonts' / 'BreeSerif.ttf')
        monster_studio.sheet(names, args.sheet)
        print('Review sheet: ' + args.sheet, flush=True)


if __name__ == '__main__':
    main(sys.argv[1:])
