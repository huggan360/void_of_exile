#!/usr/bin/env python3
"""Jade Ziggurat and Afterlife creature sculpts, in meters.

    python3 tools/make_dungeon_creatures_jade_afterlife.py
    python3 tools/make_dungeon_creatures_jade_afterlife.py ixalith lantern_shepherd
    python3 tools/make_dungeon_creatures_jade_afterlife.py --sheet /tmp/jade.png

Only the fourteen folders in BUILDERS are written. No editor or import step.
"""
import argparse
import math
import sys

import monster_studio
from monster_studio import Model, hood, plate, ring, robe, sheet
from make_creatures import fit_frame, write_vox
from preview_voxel_batch import ROOT


JADE = {
    'jade': (48, 150, 104), 'deep': (24, 77, 69),
    'gold': (219, 172, 67), 'bone': (232, 221, 171),
    'orchid': (178, 75, 135), 'void': (13, 30, 34),
    'glow_jade': (124, 248, 164), 'glow_gold': (255, 225, 130),
}
AFTER = {
    'ink': (29, 32, 65), 'veil': (58, 58, 106),
    'fold': (91, 83, 139), 'bone': (221, 221, 207),
    'gold': (190, 160, 105), 'void': (10, 16, 34),
    'glow_cyan': (111, 237, 240), 'glow_rose': (230, 113, 195),
}


def model(name, vs, colors, rough=()):
    """Select only the materials this creature actually uses."""
    source = AFTER if name in AFTERLIFE else JADE
    return Model(name, vs, {k: source[k] for k in colors.split()}, rough=rough)


def feather(p, root, tip, width, color, quill=None):
    """A broad overlapping vane, pointed at both ends, with an optional shaft."""
    a, b = root, tip
    mid = tuple(a[k] + (b[k] - a[k]) * 0.48 for k in range(3))
    p.capsule(a, mid, width * 0.35, width, color)
    p.capsule(mid, b, width, width * 0.1, color)
    if quill:
        p.capsule(a, b, width * 0.14, width * 0.08, quill)


def eyes(p, y, z, gap, radius, light, socket='void'):
    for s in (-1, 1):
        p.ellipsoid((s * gap, y, z), (radius * 1.65, radius * 1.35, radius), socket)
        p.ellipsoid((s * gap, y + radius * 0.15, z - radius * 0.7),
                    (radius, radius * 0.8, radius * 0.6), light)


def legs(m, hip, spread, length, radius, color, foot, z=0):
    p = m.part('leg')
    p.capsule((0, 0, 0), (0, -length + radius, 0), radius, radius * 0.8, color)
    p.ellipsoid((0, -length + radius * 0.5, -radius * 0.5),
                (radius, radius * 0.5, radius * 1.6), foot)
    for s, name in ((-1, 'leg_l'), (1, 'leg_r')):
        m.joint(name, 'leg', (s * spread, hip, z), 'leg', -s)


def lantern(p, center, radius, metal='gold', light='glow_cyan'):
    """Open cage: a bright suspended core, sparse ribs and pointed end caps."""
    x, y, z = center
    p.ellipsoid((x, y, z), (radius * 0.72, radius * 0.96, radius * 0.72), light)
    # Four corner posts leave a broad window from the front and both diagonals.
    for a in range(4):
        t = a * math.tau / 4 + math.pi / 4
        dx, dz = math.cos(t) * radius, math.sin(t) * radius
        p.chain([(x, y + radius * 1.5, z), (x + dx, y + radius * 0.7, z + dz),
                 (x + dx, y - radius * 0.7, z + dz), (x, y - radius * 1.4, z)],
                radius * 0.12, radius * 0.1, metal)
    for yy in (-0.7, 0.7):
        ring(p, (x, y + radius * yy, z), radius, radius * 0.12, metal, n=20)


def temple_skink():
    """Low, alert temple lizard with a golden dorsal comb and long curling tail."""
    m = model('temple_skink', .04, 'jade deep gold bone void glow_jade')
    b = m.part('body')
    b.ellipsoid((0, .43, .09), (.22, .19, .42), 'deep')
    b.ellipsoid((0, .50, .06), (.21, .17, .37), 'jade')
    for z, y in ((-.08, .68), (.08, .73), (.23, .69)):
        b.triangle((-.025, y - .12, z - .09), (.025, y - .12, z + .1),
                   (0, y, z), .045, 'gold')
    for s in (-1, 1):
        b.chain([(s * .19, .5, -.19), (s * .22, .5, .08), (s * .13, .48, .37)],
                .025, .02, 'gold')
    h = m.part('head')
    h.ellipsoid((0, .02, -.08), (.20, .17, .23), 'jade')
    h.ellipsoid((0, -.04, -.24), (.15, .095, .17), 'jade')
    h.box((-.12, -.09, -.40), (.12, -.065, -.24), 'deep')
    eyes(h, .08, -.24, .13, .035, 'glow_jade')
    h.capsule((0, .17, -.01), (0, .19, -.17), .03, .02, 'gold')
    m.joint('head', 'head', (0, .60, -.30), 'head')
    for s in (-1, 1):
        p = m.part('leg_l' if s < 0 else 'leg_r')
        p.chain([(0, 0, 0), (s * .20, -.10, .05), (s * .22, -.28, -.06)],
                .075, .04, 'jade')
        for dx in (-.05, .02, .08):
            p.capsule((s * .22, -.28, -.06), (s * .22 + dx, -.32, -.19), .025, .012, 'gold')
        for i, z in enumerate((-.21, .34)):
            m.joint(f'leg_{"l" if s < 0 else "r"}_{i}', 'leg_l' if s < 0 else 'leg_r',
                    (s * .16, .34, z), 'leg', s * (-1 if i else 1))
    t = m.part('tail')
    t.chain([(0, 0, 0), (.05, -.06, .30), (.24, -.15, .56), (.31, -.12, .84),
             (.16, -.05, 1.0)], .12, .015, 'jade')
    t.chain([(.03, .03, .16), (.14, -.02, .42), (.30, -.10, .73)], .025, .015, 'gold')
    m.joint('tail', 'tail', (0, .43, .43), 'tail')
    m.hand = (0, .61, -.69)
    m.extra = dict(waddle=.18, bob=.01)
    return m


def vine_strangler():
    """A loose braid of walking roots, crowned with a five-petalled orchid."""
    m = model('vine_strangler', .05, 'deep jade orchid gold void glow_gold', rough=('deep',))
    b = m.part('body')
    for i in range(5):
        a = i * math.tau / 5
        b.chain([(math.cos(a) * .14, .39, math.sin(a) * .14),
                 (math.cos(a + 1.2) * .17, .75, math.sin(a + 1.2) * .17),
                 (math.cos(a + 2.2) * .15, 1.14, math.sin(a + 2.2) * .15)],
                .09, .06, 'jade' if i % 2 else 'deep')
    for s in (-1, 1):
        feather(b, (s * .10, .85, 0), (s * .39, 1.11, .04), .12, 'jade', 'gold')
    h = m.part('head')
    for i in range(5):
        a = i * math.tau / 5 + math.pi / 2
        feather(h, (0, 0, .02), (math.cos(a) * .32, math.sin(a) * .31, -.06),
                .13, 'orchid', 'gold')
    h.ellipsoid((0, -.02, -.11), (.14, .13, .09), 'gold')
    h.ellipsoid((0, -.015, -.19), (.09, .09, .04), 'void')
    h.ellipsoid((0, -.025, -.22), (.035, .06, .025), 'glow_gold')
    m.joint('head', 'head', (0, 1.27, -.04), 'head')
    for s, name in ((-1, 'arm_l'), (1, 'arm_r')):
        p = m.part(name)
        p.chain([(0, 0, 0), (s * .19, -.25, -.04), (s * .10, -.51, -.13),
                 (s * .26, -.67, -.23)], .065, .025, 'deep')
        p.chain([(s * .05, -.05, 0), (s * .25, -.27, .02), (s * .13, -.5, -.08)],
                .035, .02, 'jade')
        for dx in (-.06, .04):
            p.capsule((s * .24, -.62, -.20), (s * .26 + dx, -.76, -.30), .025, .012, 'gold')
        m.joint(name, name, (s * .20, 1.07, 0), 'arm', -s, throws=s > 0)
    l = m.part('leg')
    l.chain([(0, 0, 0), (.04, -.19, 0), (0, -.37, -.04)], .08, .045, 'deep')
    for dx in (-.08, .04, .1):
        l.capsule((0, -.32, -.03), (dx, -.40, -.17), .03, .012, 'jade')
    m.joint('leg_l', 'leg', (-.12, .42, 0), 'leg')
    m.joint('leg_r', 'leg', (.12, .42, 0), 'leg', -1)
    m.hand = (.26, -.68, -.24)
    m.extra = dict(hand_limb='arm_r', waddle=.12)
    return m


def plume_wisp():
    """A little airborne serpent; a curved jade body inside a fan of gold."""
    m = model('plume_wisp', .045, 'jade deep gold bone void glow_gold')
    b = m.part('body')
    b.chain([(0, .39, .27), (.10, .61, .13), (0, .81, -.04)], .12, .145, 'jade')
    b.chain([(0, .37, .17), (.08, .59, .01), (0, .79, -.15)], .045, .05, 'gold')
    h = m.part('head')
    h.ellipsoid((0, .02, -.06), (.16, .16, .19), 'jade')
    h.ellipsoid((0, -.03, -.22), (.12, .08, .14), 'bone')
    eyes(h, .065, -.20, .095, .025, 'glow_gold')
    for s in (-1, 1):
        feather(h, (s * .08, .10, .03), (s * .23, .34, .12), .07, 'gold')
    m.joint('head', 'head', (0, .84, -.08), 'head')
    for s, name in ((-1, 'wing_l'), (1, 'wing_r')):
        w = m.part(name)
        for i in range(5):
            feather(w, (0, -.02 * i, 0),
                    (s * (.55 - i * .065), .18 - i * .09, .12 + i * .07),
                    .075, 'gold', 'bone' if i % 2 == 0 else 'deep')
        m.joint(name, name, (s * .10, .77, .04), 'wing', -s)
    t = m.part('tail')
    t.chain([(0, 0, 0), (-.16, -.14, .20), (-.14, -.27, .42), (.02, -.31, .52)], .1, .015, 'jade')
    for i in range(3):
        feather(t, (-.1, -.23, .4), ((i - 1) * .16, -.33, .73), .05, 'gold')
    m.joint('tail', 'tail', (0, .39, .22), 'tail')
    m.hand = (0, .87, -.40)
    m.extra = dict(hover=.32, bob=.055, waddle=0, flap_rate=4.5)
    return m


def jade_guardian():
    """Broad stepped masonry, a fierce carved face, and a radial sun shield."""
    m = model('jade_guardian', .08, 'jade deep gold bone void glow_jade', rough=('jade',))
    b = m.part('body')
    plate(b, (-.36, 1.01, -.26), (.36, 1.99, .25), 'deep')
    plate(b, (-.43, 1.42, -.34), (.43, 2.11, .20), 'jade')
    b.box((-.38, 1.18, -.30), (.38, 1.30, .29), 'gold')
    for x in (-.28, 0, .28):
        plate(b, (x - .12, .85, -.35), (x + .12, 1.15, -.17), 'jade')
    b.box((-.11, 1.6, -.38), (.11, 1.91, -.32), 'gold')
    b.box((-.19, 1.69, -.40), (.19, 1.80, -.35), 'glow_jade')
    for s in (-1, 1):
        plate(b, (s * .52 - .20, 1.96, -.24), (s * .52 + .20, 2.25, .23), 'jade')
        b.box((s * .52 - .21, 2.15, -.27), (s * .52 + .21, 2.23, .25), 'gold')
    h = m.part('head')
    plate(h, (-.25, -.15, -.23), (.25, .31, .20), 'jade')
    h.box((-.29, .26, -.27), (.29, .37, .23), 'gold')
    for x, top in ((-.20, .48), (0, .57), (.20, .48)):
        h.box((x - .065, .35, -.10), (x + .065, top, .09), 'jade')
    eyes(h, .12, -.27, .12, .043, 'glow_jade')
    h.box((-.055, -.06, -.33), (.055, .15, -.21), 'gold')
    h.box((-.14, -.12, -.27), (.14, -.07, -.23), 'void')
    m.joint('head', 'head', (0, 2.22, 0), 'head')
    legs(m, .94, .24, .94, .145, 'deep', 'jade')
    for s, name in ((-1, 'arm_l'), (1, 'arm_r')):
        a = m.part(name)
        a.capsule((0, 0, 0), (0, -.67, -.04), .14, .16, 'deep')
        plate(a, (-.17, -.59, -.19), (.17, -.32, .12), 'jade')
        a.ellipsoid((0, -.76, -.05), (.16, .15, .16), 'jade')
        if s < 0:
            center = (-.12, -.48, -.28)
            a.ellipsoid(center, (.46, .46, .10), 'gold')
            a.ellipsoid((-.12, -.48, -.36), (.35, .35, .06), 'deep')
            ring(a, (-.12, -.48, -.42), .25, .045, 'gold', axis='z', n=24)
            for i in range(8):
                t = i * math.tau / 8
                a.capsule((-.12 + .31 * math.cos(t), -.48 + .31 * math.sin(t), -.38),
                          (-.12 + .53 * math.cos(t), -.48 + .53 * math.sin(t), -.37), .06, .025, 'gold')
            a.ellipsoid((-.12, -.48, -.45), (.12, .12, .04), 'glow_jade')
        else:
            a.capsule((0, -.55, -.08), (0, -1.32, -.13), .055, .055, 'gold')
            plate(a, (-.11, -.40, -.16), (.11, .44, -.04), 'deep')
            for yy in (-.28, -.05, .18, .41):
                a.box((-.15, yy, -.18), (.15, yy + .10, -.02), 'bone')
        m.joint(name, name, (s * .57, 2.0, 0), 'arm', -s, throws=s > 0)
    m.hand = (0, .44, -.12)
    m.extra = dict(hand_limb='arm_r', waddle=.08)
    return m


def serpent_priest():
    """Cobra priest in gold-edged vestments, a feather crown and a jade staff."""
    m = model('serpent_priest', .07, 'jade deep gold bone orchid void glow_jade')
    b = m.part('body')
    robe(b, 1.43, .38, .20, .35, 'deep', trim='gold')
    b.ellipsoid((0, 1.41, 0), (.27, .26, .20), 'jade')
    for y, r in ((1.52, .26), (1.43, .28), (1.33, .26)):
        ring(b, (0, y, 0), r, .035, 'gold', n=24)
    b.box((-.09, .36, -.35), (.09, 1.29, -.22), 'orchid')
    for y in (.54, .83, 1.1):
        b.box((-.06, y, -.37), (.06, y + .08, -.31), 'gold')
    h = m.part('head')
    h.ellipsoid((0, .02, .03), (.27, .26, .12), 'jade')
    for s in (-1, 1):
        feather(h, (s * .16, -.12, .03), (s * .27, .23, .03), .08, 'gold')
    h.ellipsoid((0, .06, -.13), (.14, .18, .20), 'jade')
    h.ellipsoid((0, -.035, -.30), (.135, .075, .14), 'bone')
    eyes(h, .12, -.29, .09, .028, 'glow_jade')
    h.box((-.11, -.07, -.42), (.11, -.04, -.30), 'deep')
    for i in range(7):
        a = math.pi * i / 6
        feather(h, (math.cos(a) * .14, .17, .07),
                (math.cos(a) * .38, .22 + math.sin(a) * .27, .12),
                .065, 'gold' if i % 2 else 'orchid', 'deep')
    m.joint('head', 'head', (0, 1.68, -.015), 'head')
    legs(m, .34, .13, .34, .075, 'jade', 'deep')
    for s, name in ((-1, 'arm_l'), (1, 'arm_r')):
        a = m.part(name)
        a.capsule((0, 0, 0), (0, -.50, -.04), .09, .12, 'deep')
        ring(a, (0, -.46, -.04), .12, .03, 'gold', n=16)
        a.ellipsoid((0, -.57, -.05), (.065, .075, .075), 'jade')
        if s > 0:
            a.capsule((0, -1.40, -.12), (0, .40, -.12), .035, .035, 'gold')
            a.chain([(0, .40, -.12), (-.12, .52, -.12), (0, .65, -.12),
                     (.12, .52, -.12), (0, .40, -.12)], .065, .05, 'jade')
            a.ellipsoid((0, .52, -.18), (.055, .065, .025), 'glow_jade')
        m.joint(name, name, (s * .30, 1.50, 0), 'arm', -s, throws=s > 0)
    m.hand = (0, .52, -.19)
    m.extra = dict(hand_limb='arm_r', waddle=.1)
    return m


def obsidian_jaguar():
    """A muscular low stalking cat, with luminous broken-ring jade rosettes."""
    m = Model('obsidian_jaguar', .045, {
        'obsidian': (28, 34, 45), 'facet': (49, 58, 72), 'muzzle': (94, 112, 113),
        'gold': (210, 166, 72), 'void': (8, 16, 25),
        'glow_jade': (105, 234, 156), 'glow_eye': (242, 237, 154),
    }, rough=())
    b = m.part('body')
    b.ellipsoid((0, 1.06, .20), (.47, .45, .97), 'obsidian')
    b.ellipsoid((0, 1.22, -.36), (.53, .55, .48), 'facet')
    b.ellipsoid((0, 1.13, .84), (.46, .48, .48), 'obsidian')
    # Paired shoulder rosettes read both from above and in profile.
    for s in (-1, 1):
        for z, y in ((-.49, 1.38), (-.02, 1.26), (.43, 1.24), (.84, 1.3)):
            x = s * (.46 if z < .5 else .40)
            ring(b, (x, y, z), .105, .025, 'glow_jade', axis='x', n=12)
        for z in (-.22, .26, .70):
            ring(b, (s * .22, 1.48, z), .105, .025, 'glow_jade', n=12)
    h = m.part('head')
    h.ellipsoid((0, .02, -.08), (.34, .31, .36), 'obsidian')
    for s in (-1, 1):
        h.ellipsoid((s * .26, .28, .015), (.13, .15, .10), 'facet')
        h.ellipsoid((s * .26, .28, -.06), (.075, .08, .03), 'gold')
        h.ellipsoid((s * .17, -.09, -.36), (.17, .13, .15), 'muzzle')
        h.capsule((s * .16, .12, -.35), (s * .30, .16, -.25), .04, .02, 'glow_jade')
    eyes(h, .12, -.37, .17, .055, 'glow_eye')
    h.ellipsoid((0, -.04, -.49), (.10, .07, .04), 'void')
    h.capsule((0, .16, -.39), (0, .30, -.20), .035, .03, 'gold')
    m.joint('head', 'head', (0, 1.56, -.96), 'head')
    j = m.part('jaw')
    j.ellipsoid((0, -.045, -.12), (.25, .09, .22), 'facet')
    for s in (-1, 1):
        j.capsule((s * .17, .015, -.23), (s * .17, .15, -.25), .04, .015, 'gold')
    m.joint('jaw', 'jaw', (0, -.16, -.18), 'jaw', parent_limb='head')
    for front in (True, False):
        part = 'leg_front' if front else 'leg_back'
        l = m.part(part)
        l.chain([(0, 0, 0), (0, -.35, .10 if front else -.12), (0, -.86, -.03)],
                .19 if front else .22, .12, 'obsidian')
        l.ellipsoid((0, -.91, -.12), (.16, .11, .25), 'facet')
        for dx in (-.09, .01, .10):
            l.capsule((dx, -.94, -.28), (dx, -.97, -.36), .035, .015, 'gold')
        ring(l, (0, -.40, .04), .15, .025, 'glow_jade', n=16)
        for s in (-1, 1):
            m.joint(f'leg_{"front" if front else "back"}_{"l" if s < 0 else "r"}',
                    part, (s * .39, 1.01, -.48 if front else .88), 'leg', s * (1 if front else -1))
    t = m.part('tail')
    t.chain([(0, 0, 0), (.14, -.12, .45), (.45, -.32, .83), (.60, -.17, 1.10),
             (.52, .1, 1.17)], .12, .055, 'obsidian')
    for x, y, z in ((.16, -.14, .5), (.42, -.3, .8), (.58, -.12, 1.1)):
        ring(t, (x, y, z), .075, .025, 'glow_jade', axis='z', n=12)
    m.joint('tail', 'tail', (0, 1.2, 1.11), 'tail')
    m.hand = (0, 1.53, -1.46)
    m.extra = dict(waddle=.08, bob=.015, glow_strength=.9)
    return m


def ixalith():
    """The Jade Coil: nested heavy coils below an emerald and gold feather crown.

    The two feather fans are arms, so the cantor conducts with its wings.
    All forms use identical geometry bounds and joint frames.
    """
    m = model('ixalith', .09, 'jade deep gold bone orchid void glow_jade glow_gold')

    def body(name, form):
        b = m.part(name)
        scale = 'jade'
        plume = 'glow_gold' if form == 'radiant' else 'gold'
        # A real three-dimensional spiral, with the tip curled over the outer coil.
        pts = []
        for i in range(65):
            t = i / 64
            a = t * math.tau * 1.65 + .35
            r = 1.12 - t * .47
            pts.append((math.cos(a) * r, .39 + t * 1.16, math.sin(a) * r + .14))
        b.chain(pts, .36, .32, scale)
        b.chain([pts[-1], (-.28, 2.06, .10), (.28, 2.80, .14),
                 (.12, 3.53, .08), (0, 4.37, -.03)], .36, .43, scale)
        # Broad cream ventral scutes, stepping up the forward curve of the neck.
        for i, (x, y, z) in enumerate(((-.10, 1.88, -.19), (.12, 2.23, -.22),
                                      (.26, 2.60, -.24), (.24, 2.96, -.26),
                                      (.13, 3.32, -.31), (.05, 3.68, -.34), (0, 4.04, -.37))):
            b.ellipsoid((x, y, z), (.27, .115, .09), 'bone')
            b.capsule((x - .19, y + .08, z - .03), (x + .19, y + .08, z - .03), .025, .025, 'gold')
        # Dorsal scallops remain legible on the back of the coils.
        for i in range(0, 60, 4):
            x, y, z = pts[i]
            b.ellipsoid((x, y + .31, z), (.14, .065, .13), 'deep')
            if i % 8 == 0:
                b.ellipsoid((x, y + .36, z), (.055, .04, .06), 'glow_jade')
                a = i / 64 * math.tau * 1.65 + .35
                dx, dz = math.cos(a), math.sin(a)
                b.chain([(x - dx * .08, y + .35, z - dz * .08),
                         (x + dx * .23, y + .26, z + dz * .23),
                         (x + dx * .36, y + .03, z + dz * .36),
                         (x + dx * .31, y - .17, z + dz * .31)],
                        .04, .03, 'glow_gold' if form == 'molted' else 'jade')
        for s in (-1, 1):
            for i in range(5):
                feather(b, (s * .22, 4.07, .02),
                        (s * (.67 + i * .15), 4.99 - i * .24, -.02 + i * .025),
                        .16, plume if i % 3 != 1 else 'jade', 'deep')
        # These seams are paint in the same positions in every form.
        for pts2 in ([(-.24, 2.23, -.20), (-.12, 2.47, -.26), (-.20, 2.65, -.25)],
                     [(.42, 3.12, -.12), (.30, 3.38, -.25), (.37, 3.60, -.15)],
                     [(-.77, .56, -.83), (-.48, .69, -.97), (-.26, .80, -.88)]):
            b.chain(pts2, .045, .035, 'glow_gold' if form == 'molted' else scale)

    def head(name, form):
        h = m.part(name)
        plume = 'glow_gold' if form == 'radiant' else 'gold'
        skin = 'jade'
        h.ellipsoid((0, .05, -.04), (.45, .40, .47), skin)
        h.ellipsoid((0, -.06, -.48), (.36, .23, .43), skin)
        h.ellipsoid((0, .05, -.73), (.30, .15, .20), 'gold')
        for s in (-1, 1):
            h.ellipsoid((s * .30, .18, -.48), (.16, .13, .13), 'void')
            h.ellipsoid((s * .30, .19, -.57), (.10, .055, .055), 'glow_jade')
            # A sweeping ceremonial brow mask and flared cheek plates.
            h.chain([(s * .08, .28, -.68), (s * .30, .30, -.54), (s * .49, .22, -.25)],
                    .085, .055, 'gold')
            feather(h, (s * .37, -.02, -.20), (s * .67, .20, .04), .13, plume)
            h.capsule((s * .18, -.13, -.68), (s * .18, -.36, -.73), .045, .015, 'bone')
        h.ellipsoid((0, .30, -.53), (.12, .15, .08), 'gold')
        h.ellipsoid((0, .32, -.60), (.055, .075, .035), 'glow_gold')
        for i in range(7):
            a = math.pi * i / 6
            feather(h, (math.cos(a) * .20, .30, .07),
                    (math.cos(a) * .66, .48 + math.sin(a) * .70, .23),
                    .14, plume if i % 2 else 'jade', 'deep')
        h.chain([(-.30, .14, -.63), (-.17, .22, -.72), (-.07, .10, -.78)],
                .035, .03, 'glow_gold' if form == 'molted' else 'gold')

    def wing(name, s, form):
        w = m.part(name)
        c = 'glow_gold' if form == 'radiant' else 'gold'
        w.chain([(0, 0, 0), (s * .86, .30, .05), (s * 2.13, .35, .18)], .18, .09, 'jade')
        # Separate primaries make a scalloped fan instead of a flat triangle.
        for i in range(9):
            root = (s * (.12 + i * .20), .08 + i * .022, .06)
            tip = (s * (.64 + i * .265), -1.39 + i * .20, .35 + i * .035)
            feather(w, root, tip, .17, c if i % 3 != 1 else 'jade', 'deep')
        for i in range(6):
            feather(w, (s * i * .27, .24, -.10),
                    (s * (.45 + i * .31), -.28 + i * .075, -.12), .14,
                    'glow_jade' if form == 'molted' else 'jade', c)
        w.ellipsoid((s * .24, .08, -.18), (.13, .13, .08), 'glow_jade')

    for form in ('base', 'radiant', 'molted'):
        suffix = '' if form == 'base' else '_' + form
        body('body' + suffix, form)
        head('head' + suffix, form)
        for s, name in ((-1, 'arm_l'), (1, 'arm_r')):
            wing(name + suffix, s, form)
    m.joint('head', 'head', (0, 4.78, -.06), 'head')
    j = m.part('jaw')
    j.ellipsoid((0, -.07, -.30), (.32, .13, .45), 'jade')
    j.ellipsoid((0, -.06, -.53), (.28, .09, .20), 'bone')
    j.box((-.23, .02, -.63), (.23, .065, -.27), 'void')
    for s in (-1, 1):
        j.capsule((s * .18, .015, -.54), (s * .18, .16, -.57), .04, .015, 'bone')
    m.joint('jaw', 'jaw', (0, -.22, -.19), 'jaw', parent_limb='head')
    for s, name in ((-1, 'arm_l'), (1, 'arm_r')):
        m.joint(name, name, (s * .37, 3.93, .07), 'arm', -s, throws=s > 0)
    t = m.part('tail')
    t.chain([(0, 0, 0), (.35, -.12, .27), (.67, -.20, .14), (.79, -.14, -.10)], .22, .05, 'jade')
    for i in range(3):
        feather(t, (.62, -.16, .12), (.91 + i * .12, -.10, .30 - i * .18), .10, 'gold')
    m.joint('tail', 'tail', (.55, .47, .83), 'tail')
    m.hand = (2.76, .21, .63)
    m.extra = dict(animation_style='cantor', hand_limb='arm_r', hover=.02, bob=.015,
                   waddle=0, glow_strength=1.2,
                   variants={f: {p: p + '_' + f for p in ('body', 'head', 'arm_l', 'arm_r')}
                             for f in ('radiant', 'molted')})
    return m


AFTERLIFE = ('lost_soul', 'lantern_moth', 'grave_creeper', 'mourning_wraith',
             'soul_warden', 'willow_matron', 'lantern_shepherd')


def lost_soul():
    """A small hollow-faced person, fingers drawn in, tapering into a wisp."""
    m = model('lost_soul', .04, 'ink veil fold bone void glow_cyan glow_rose')
    b = m.part('body')
    b.ellipsoid((0, .62, .02), (.17, .25, .13), 'veil')
    b.ellipsoid((0, .60, -.10), (.09, .13, .035), 'ink')
    b.ellipsoid((0, .67, -.13), (.045, .055, .02), 'glow_rose')
    h = m.part('head')
    h.ellipsoid((0, .02, .01), (.22, .24, .18), 'fold')
    h.ellipsoid((0, .015, -.12), (.155, .18, .09), 'bone')
    h.ellipsoid((0, .005, -.20), (.115, .135, .035), 'void')
    eyes(h, .04, -.23, .057, .021, 'glow_cyan')
    h.ellipsoid((0, -.07, -.24), (.025, .04, .014), 'ink')
    m.joint('head', 'head', (0, .94, -.02), 'head')
    for s, name in ((-1, 'arm_l'), (1, 'arm_r')):
        a = m.part(name)
        a.chain([(0, 0, 0), (s * .07, -.13, -.04), (s * .02, -.28, -.14)], .065, .025, 'veil')
        a.ellipsoid((s * .02, -.28, -.14), (.035, .045, .035), 'glow_cyan')
        m.joint(name, name, (s * .18, .77, 0), 'arm', -s, throws=s > 0)
    t = m.part('tail')
    t.chain([(0, 0, 0), (.045, -.15, .05), (.16, -.27, .09), (.22, -.34, .02)], .13, .012, 'veil')
    t.chain([(.07, -.17, -.01), (.17, -.28, .04), (.22, -.34, .02)], .025, .012, 'glow_cyan')
    m.joint('tail', 'tail', (0, .36, .02), 'tail')
    m.hand = (.02, -.28, -.14)
    m.extra = dict(hand_limb='arm_r', hover=.22, bob=.07, waddle=0)
    return m


def lantern_moth():
    """Pale scalloped moth with cyan and soft gold lantern eyes on four lobes."""
    m = Model('lantern_moth', .045, {
        'ink': AFTER['ink'], 'veil': AFTER['veil'], 'bone': AFTER['bone'],
        'gold': AFTER['gold'], 'void': AFTER['void'],
        'glow_cyan': AFTER['glow_cyan'], 'glow_gold': (250, 221, 151),
    })
    b = m.part('body')
    b.ellipsoid((0, .56, .04), (.12, .30, .13), 'veil')
    b.ellipsoid((0, .76, -.02), (.20, .18, .17), 'bone')
    b.ellipsoid((0, .89, -.07), (.14, .14, .13), 'bone')
    eyes(b, .91, -.18, .075, .03, 'glow_gold')
    for s in (-1, 1):
        b.chain([(s * .07, 1.0, -.07), (s * .14, 1.16, -.13), (s * .26, 1.26, -.10)],
                .02, .012, 'gold')
        feather(b, (s * .14, 1.16, -.13), (s * .26, 1.26, -.10), .04, 'bone')
        for yy in (.49, .61, .73):
            b.capsule((s * .08, yy, -.08), (s * .22, yy - .10, -.18), .015, .008, 'ink')
    for s, name in ((-1, 'wing_l'), (1, 'wing_r')):
        w = m.part(name)
        for x, y, rx, ry in ((.42, .13, .47, .39), (.33, -.33, .36, .32)):
            w.ellipsoid((s * x, y, .06), (rx, ry, .07), 'veil')
            w.ellipsoid((s * x, y, -.005), (rx * .87, ry * .86, .045), 'bone')
        w.chain([(0, 0, -.08), (s * .33, .23, -.075), (s * .72, .34, -.02)], .025, .015, 'gold')
        w.chain([(0, 0, -.08), (s * .32, -.22, -.075), (s * .56, -.49, -.02)], .025, .015, 'gold')
        for x, y, r, light in ((.51, .16, .14, 'glow_cyan'), (.36, -.34, .105, 'glow_gold')):
            w.ellipsoid((s * x, y, -.065), (r * 1.35, r * 1.15, .04), 'ink')
            w.ellipsoid((s * x, y, -.10), (r, r * .90, .025), light)
            w.ellipsoid((s * x, y, -.13), (r * .38, r * .65, .02), 'veil')
            # Eye-spots remain luminous from behind, too.
            w.ellipsoid((s * x, y, .13), (r * .70, r * .65, .025), light)
        for i in range(4):
            feather(w, (s * (.20 + i * .13), -.45, .04),
                    (s * (.25 + i * .14), -.63 + i * .07, .05), .05, 'bone')
        m.joint(name, name, (s * .10, .73, .04), 'wing', -s)
    m.hand = (0, .87, -.22)
    m.extra = dict(hover=.28, bob=.055, flap_rate=4.8, waddle=0)
    return m


def grave_creeper():
    """A gnarled crawling root with a little buried face and three seed lanterns."""
    m = model('grave_creeper', .04, 'ink veil fold bone gold void glow_cyan glow_rose', rough=('veil',))
    b = m.part('body')
    b.ellipsoid((0, .30, .08), (.24, .19, .43), 'ink')
    for i, x in enumerate((-.16, -.04, .10, .18)):
        b.chain([(x, .32, -.29), (x * .5, .46, .02), (x, .34, .45)], .065, .05, 'veil')
    for x, y, z, r, light in ((-.16, .66, -.03, .13, 'glow_cyan'),
                              (.13, .74, .18, .13, 'glow_rose'), (.02, .53, .42, .105, 'glow_cyan')):
        b.capsule((x, .38, z), (x, y, z), .035, .025, 'gold')
        b.ellipsoid((x, y, z), (r, r * 1.15, r), light)
        for s in (-1, 1):
            b.chain([(x, y - r, z), (x + s * r * .9, y, z - r * .5), (x, y + r, z)],
                    .025, .018, 'veil')
    h = m.part('head')
    h.ellipsoid((0, 0, -.08), (.20, .16, .19), 'veil')
    h.ellipsoid((0, .015, -.20), (.13, .12, .06), 'bone')
    eyes(h, .04, -.26, .065, .028, 'glow_cyan')
    h.box((-.045, -.07, -.27), (.045, -.04, -.23), 'void')
    m.joint('head', 'head', (0, .32, -.39), 'head')
    for s in (-1, 1):
        name = 'root_l' if s < 0 else 'root_r'
        l = m.part(name)
        l.chain([(0, 0, 0), (s * .23, .02, -.04), (s * .37, -.15, -.15),
                 (s * .40, -.24, -.29)], .065, .015, 'veil')
        l.capsule((s * .32, -.12, -.11), (s * .48, -.21, -.10), .03, .012, 'gold')
        for i, z in enumerate((-.23, .08, .36)):
            m.joint(f'leg_{"l" if s < 0 else "r"}_{i}', name, (s * .14, .27, z),
                    'leg', s * (1 if i % 2 else -1), amount=.6)
    m.hand = (0, .35, -.64)
    m.extra = dict(waddle=.08)
    return m


def mourning_wraith():
    """A bowed veiled mourner, two streams of cyan tears above long empty sleeves."""
    m = model('mourning_wraith', .075, 'ink veil fold bone gold void glow_cyan glow_rose')
    b = m.part('body')
    robe(b, 1.94, .38, .20, .37, 'ink')
    b.ellipsoid((0, 1.89, .02), (.28, .30, .20), 'veil')
    for s in (-1, 1):
        b.chain([(s * .19, 2.0, -.12), (s * .25, 1.40, -.20), (s * .36, .46, -.24)],
                .09, .075, 'fold')
        b.chain([(s * .20, 1.78, -.21), (s * .24, 1.23, -.27), (s * .34, .47, -.30)],
                .018, .012, 'glow_rose')
    h = m.part('head')
    hood(h, (0, .05, .02), .24, 'veil', 'void', point=.12)
    h.ellipsoid((0, -.02, -.14), (.12, .17, .07), 'bone')
    for s in (-1, 1):
        h.capsule((s * .055, .02, -.21), (s * .055, -.18, -.23), .018, .012, 'glow_cyan')
        h.capsule((s * .03, .035, -.215), (s * .09, .065, -.20), .02, .015, 'void')
    h.ellipsoid((0, -.11, -.22), (.025, .035, .015), 'glow_cyan')
    m.joint('head', 'head', (0, 2.27, -.06), 'head')
    for s, name in ((-1, 'arm_l'), (1, 'arm_r')):
        a = m.part(name)
        a.chain([(0, 0, 0), (s * .09, -.42, -.02), (s * .03, -.91, -.07)], .11, .17, 'veil')
        a.chain([(s * .02, -.30, -.13), (s * .05, -.76, -.20), (0, -1.12, -.16)],
                .06, .015, 'fold')
        a.capsule((0, -.90, -.16), (0, -1.07, -.22), .045, .025, 'bone')
        a.ellipsoid((0, -1.07, -.23), (.03, .045, .025), 'glow_cyan')
        m.joint(name, name, (s * .31, 1.94, .02), 'arm', -s, throws=s > 0)
    for s, name in ((-1, 'veil_l'), (1, 'veil_r')):
        c = m.part(name)
        c.chain([(0, 0, 0), (s * .12, -.52, .05), (s * .04, -.84, .16)], .12, .02, 'veil')
        m.joint(name, name, (s * .23, .91, .16), 'cloth', -s)
    m.hand = (0, -1.07, -.23)
    m.extra = dict(hand_limb='arm_r', hover=.20, bob=.04, waddle=0)
    return m


def soul_warden():
    """A compact stone-masked keeper; squared shoulders, soul cage and long staff."""
    m = model('soul_warden', .075, 'ink veil fold bone gold void glow_cyan glow_rose')
    b = m.part('body')
    robe(b, 1.88, .43, .25, .39, 'ink')
    plate(b, (-.29, 1.38, -.25), (.29, 2.05, .17), 'veil')
    for s in (-1, 1):
        plate(b, (s * .37 - .18, 1.96, -.21), (s * .37 + .18, 2.16, .20), 'bone')
        b.capsule((s * .22, 1.88, -.29), (s * .29, .60, -.32), .025, .025, 'gold')
    ring(b, (0, 1.20, 0), .30, .045, 'gold', n=24)
    b.ellipsoid((0, 1.66, -.29), (.07, .09, .04), 'glow_rose')
    h = m.part('head')
    h.ellipsoid((0, .06, .02), (.25, .25, .23), 'ink')
    plate(h, (-.17, -.14, -.26), (.17, .29, -.14), 'bone')
    h.box((-.19, .22, -.28), (.19, .30, -.12), 'gold')
    eyes(h, .09, -.29, .09, .03, 'glow_cyan')
    h.box((-.025, -.12, -.30), (.025, -.03, -.24), 'void')
    m.joint('head', 'head', (0, 2.27, 0), 'head')
    legs(m, .50, .17, .50, .10, 'ink', 'veil')
    for s, name in ((-1, 'arm_l'), (1, 'arm_r')):
        a = m.part(name)
        a.capsule((0, 0, 0), (0, -.64, -.04), .115, .10, 'veil')
        ring(a, (0, -.56, -.04), .11, .03, 'gold', n=16)
        a.ellipsoid((0, -.72, -.05), (.07, .08, .07), 'bone')
        if s < 0:
            a.chain([(0, -.70, -.08), (-.10, -.88, -.16), (0, -.93, -.16)], .02, .02, 'gold')
            lantern(a, (0, -1.16, -.16), .15)
        else:
            a.capsule((0, -1.88, -.12), (0, .48, -.12), .035, .035, 'gold')
            a.chain([(-.14, .37, -.12), (0, .58, -.12), (.14, .37, -.12)], .04, .035, 'bone')
            a.ellipsoid((0, .40, -.12), (.065, .12, .06), 'glow_rose')
        m.joint(name, name, (s * .40, 1.96, 0), 'arm', -s, throws=s > 0)
    m.hand = (0, .42, -.12)
    m.extra = dict(hand_limb='arm_r', waddle=.10)
    return m


def willow_matron():
    """A willow woman's face between parted bark, a canopy of hanging soul threads."""
    m = model('willow_matron', .075, 'ink veil fold bone gold void glow_cyan glow_rose', rough=('veil',))
    b = m.part('body')
    b.chain([(0, .45, .10), (-.16, 1.19, .06), (.02, 2.10, 0), (0, 2.72, .04)],
            .43, .27, 'ink')
    for s in (-1, 1):
        b.chain([(s * .10, 2.41, -.10), (s * .30, 1.56, -.15), (s * .48, .58, -.16)],
                .14, .11, 'veil')
        b.chain([(s * .10, 2.1, .20), (s * .33, 1.14, .31), (s * .68, .38, .38)],
                .10, .06, 'fold')
    for i in range(7):
        a = i * math.tau / 7
        b.chain([(math.cos(a) * .28, .76, math.sin(a) * .26),
                 (math.cos(a) * .56, .25, math.sin(a) * .52),
                 (math.cos(a) * .81, .12, math.sin(a) * .74)], .13, .04, 'veil')
    h = m.part('head')
    h.ellipsoid((0, .02, .01), (.27, .33, .22), 'veil')
    h.ellipsoid((0, -.02, -.19), (.17, .23, .09), 'bone')
    for s in (-1, 1):
        h.chain([(s * .10, .30, -.15), (s * .21, .08, -.21), (s * .16, -.29, -.19)],
                .065, .04, 'ink')
        h.capsule((s * .045, .04, -.28), (s * .11, .07, -.26), .025, .018, 'void')
        h.capsule((s * .11, .01, -.28), (s * .11, -.13, -.29), .018, .012, 'glow_cyan')
    h.ellipsoid((0, -.13, -.28), (.045, .025, .02), 'gold')
    # Branches arc over her face before falling into willow curtains.
    for s in (-1, 1):
        h.chain([(s * .15, .23, .05), (s * .35, .55, .05), (s * .70, .68, .12),
                 (s * .97, .46, .18)], .09, .035, 'veil')
        for i in range(4):
            x = s * (.32 + i * .20)
            feather(h, (x, .53, .10), (x + s * .15, .36, .22), .12, 'fold')
            feather(h, (x, .49, .03), (x + s * .08, .14 - .035 * i, -.01), .075, 'veil')
    m.joint('head', 'head', (0, 2.86, -.05), 'head')
    for s, name in ((-1, 'arm_l'), (1, 'arm_r')):
        a = m.part(name)
        a.chain([(0, 0, 0), (s * .29, -.29, .04), (s * .37, -.76, -.14)], .13, .07, 'veil')
        for dx in (-.10, .01, .11):
            a.chain([(s * .36, -.69, -.13), (s * .36 + dx, -.91, -.20),
                     (s * .36 + dx * 1.3, -1.15, -.33)], .035, .012, 'gold')
        a.ellipsoid((s * .37, -.84, -.22), (.07, .09, .05), 'glow_rose')
        m.joint(name, name, (s * .32, 2.35, .04), 'arm', -s, throws=s > 0)
    # Independently swaying curtains surround the trunk, with a clear opening at the face.
    for i in range(9):
        a = .05 + i * math.tau / 9
        x, z = math.cos(a) * .77, math.sin(a) * .52 + .14
        c = m.part(f'tendril_{i}')
        length = 1.32 + .15 * (i % 3)
        c.chain([(0, 0, 0), (.07 * math.cos(a), -.45, .08),
                 (-.04 * math.sin(a), -length, .12)], .045, .018, 'fold')
        c.chain([(0, -.18, -.035), (.06 * math.cos(a), -.46, .035),
                 (-.04 * math.sin(a), -length, .10)], .018, .012,
                'glow_cyan' if i % 3 else 'glow_rose')
        for yy in (-.4, -.8):
            feather(c, (0, yy, .06), (.10 * math.cos(a), yy - .17, .10), .045, 'veil')
        m.joint(f'tendril_{i}', f'tendril_{i}', (x, 3.21 - .10 * (i % 2), z), 'cloth', (-1) ** i)
    # The heavy roots float just above the loam instead of skating on it.
    m.hand = (.37, -.84, -.22)
    m.extra = dict(hand_limb='arm_r', hover=.09, bob=.025, waddle=0, glow_strength=1.05)
    return m


def lantern_shepherd():
    """Elegy: an antlered porcelain guide, nested veils and moth-wing shawl.

    The exposed cyan soul on the raised crook is the visual anchor. The mask
    has only one vertical slit; its small lower porcelain panel is the jaw.
    """
    m = model('lantern_shepherd', .09, 'ink veil fold bone gold void glow_cyan glow_rose')

    def body(name, form):
        b = m.part(name)
        robe(b, 3.90, .84, .29, .79, 'ink')
        b.ellipsoid((0, 3.85, .01), (.34, .46, .24), 'veil')
        # Long overlapping petal panels. The darker underskirt stays visible between them.
        for i in range(9):
            a = i * math.tau / 9 + .18
            dx, dz = math.cos(a), math.sin(a)
            top = (dx * .25, 3.56, dz * .23)
            mid = (dx * .45, 1.96, dz * .38)
            tip = (dx * .87, .19 + .12 * (i % 3), dz * .66 + .10)
            b.triangle(top, (dx * .79 - dz * .19, .64, dz * .62 + dx * .19),
                       (dx * .79 + dz * .19, .64, dz * .62 - dx * .19), .14,
                       'fold' if i % 3 == 0 else 'veil')
            b.chain([top, mid, tip], .09, .025, 'veil' if i % 3 == 0 else 'fold')
            # Thin lit hems become rose fire in the veil phase.
            b.chain([(dx * .59, 2.20, dz * .59), (dx * .82, 1.12, dz * .82), tip],
                    .028, .018, 'glow_rose' if form == 'veil' else 'fold')
        # A broad but delicate moth shawl. Its tips hang below the narrow shoulders.
        for s in (-1, 1):
            b.triangle((s * .16, 4.13, -.15), (s * 1.32, 3.68, -.12),
                       (s * .82, 2.69, .02), .15, 'veil')
            for i in range(5):
                feather(b, (s * (.20 + i * .13), 4.04 - i * .03, -.12),
                        (s * (.66 + i * .16), 2.72 + i * .20, -.02), .14,
                        'fold' if i % 2 else 'ink')
            b.chain([(s * .17, 4.14, -.19), (s * .76, 3.99, -.16), (s * 1.33, 3.68, -.14)],
                    .055, .025, 'gold')
            b.ellipsoid((s * .94, 3.50, -.18), (.23, .29, .07), 'gold')
            b.ellipsoid((s * .94, 3.50, -.245), (.17, .22, .05), 'ink')
            b.ellipsoid((s * .94, 3.50, -.29), (.07, .11, .025), 'glow_rose')
        b.ellipsoid((0, 3.80, -.27), (.11, .14, .06), 'gold')
        b.ellipsoid((0, 3.80, -.32), (.045, .075, .025), 'glow_rose')
        # Soul wisps orbit the hem, each a tiny hollow face with a curling tail.
        for i in range(5):
            a = i * math.tau / 5 - 1.40
            x, z = math.cos(a) * 1.0, math.sin(a) * .78
            y = .45 + .14 * (i % 3)
            b.ellipsoid((x, y, z), (.11, .14, .09), 'fold')
            b.ellipsoid((x, y + .015, z - .07), (.055, .075, .025), 'glow_rose')
            b.chain([(x, y - .07, z), (x + .08, y - .22, z + .04),
                     (x + .17, y - .26, z + .03)], .07, .015, 'veil')

    def head(name, form):
        h = m.part(name)
        h.ellipsoid((0, .02, .08), (.31, .46, .25), 'ink')
        h.ellipsoid((0, -.02, -.13), (.25, .35, .14), 'bone')
        # The long single slit remains readable from the elevated game camera.
        h.box((-.07, -.20, -.29), (.07, .25, -.21), 'void')
        h.box((-.035, -.16, -.34), (.035, .21, -.27), 'glow_rose')
        # Cracks are painted on identical geometry in all forms.
        for pts in ([(-.23, .12, -.19), (-.11, .07, -.26), (-.06, -.02, -.275)],
                    [(.19, -.02, -.23), (.13, -.10, -.26), (.21, -.19, -.22)]):
            h.chain(pts, .025, .022, 'glow_cyan' if form == 'unbound' else 'bone')
        # Bone antlers branch outward, then turn inward like a crescent moon.
        antler = 'glow_rose' if form == 'unbound' else 'bone'
        for s in (-1, 1):
            h.chain([(s * .17, .30, .04), (s * .37, .61, .05),
                     (s * .65, .86, .03), (s * .78, 1.16, .01), (s * .69, 1.35, -.04)],
                    .075, .018, antler)
            h.chain([(s * .41, .67, .05), (s * .34, .98, .02), (s * .43, 1.18, -.04)],
                    .055, .015, antler)
            h.chain([(s * .64, .86, .03), (s * .94, 1.01, .07), (s * 1.02, 1.22, .02)],
                    .05, .015, antler)
            # Veils frame the mask without hiding the porcelain or the antler roots.
            h.chain([(s * .23, .35, .08), (s * .35, -.10, .13),
                     (s * .41, -.63, .20), (s * .34, -.94, .28)], .095, .025,
                    'glow_rose' if form == 'veil' else 'veil')
            h.capsule((s * .30, -.20, .05), (s * .38, -.63, .09), .025, .018, 'gold')

    for form in ('base', 'veil', 'unbound'):
        suffix = '' if form == 'base' else '_' + form
        body('body' + suffix, form)
        head('head' + suffix, form)
    m.joint('head', 'head', (0, 4.62, -.02), 'head')
    j = m.part('jaw')
    j.ellipsoid((0, -.065, -.045), (.15, .11, .085), 'bone')
    j.capsule((0, .015, -.14), (0, -.06, -.14), .018, .012, 'glow_rose')
    m.joint('jaw', 'jaw', (0, -.28, -.13), 'jaw', parent_limb='head')
    for s, name in ((-1, 'arm_l'), (1, 'arm_r')):
        a = m.part(name)
        a.chain([(0, 0, 0), (s * .09, -.59, -.02), (s * .06, -1.21, -.13)], .12, .14, 'veil')
        a.chain([(0, -.32, -.13), (s * .08, -.81, -.16), (s * .04, -1.57, -.11)],
                .065, .018, 'fold')
        ring(a, (s * .06, -1.16, -.13), .14, .035, 'gold', n=20)
        a.ellipsoid((s * .06, -1.34, -.15), (.075, .12, .075), 'bone')
        for dx in (-.06, .025, .08):
            a.capsule((s * .06 + dx, -1.35, -.18), (s * .06 + dx, -1.53, -.24), .025, .012, 'bone')
        if s > 0:
            # Crook is wholly in the casting arm, including its hanging cage.
            a.capsule((.07, -3.66, -.13), (.07, .71, -.13), .05, .045, 'gold')
            a.chain([(.07, .71, -.13), (.18, 1.0, -.13), (.47, 1.11, -.13),
                     (.80, .99, -.13), (.92, .75, -.13), (.82, .62, -.13)], .055, .04, 'bone')
            a.capsule((.82, .62, -.13), (.82, .45, -.13), .02, .02, 'gold')
            lantern(a, (.82, .0, -.13), .30)
            # A curled soul inside the open cage, its white-cyan heart the brightest point.
            a.chain([(.78, -.12, -.14), (.71, .0, -.15), (.82, .18, -.14)], .055, .025, 'glow_cyan')
        m.joint(name, name, (s * .59, 4.04, -.08), 'arm', -s, throws=s > 0)
    # Secondary veil panels lift independently in cast, slam and kneel poses.
    for s, name in ((-1, 'veil_l'), (1, 'veil_r')):
        c = m.part(name)
        c.triangle((0, 0, 0), (s * .26, -2.32, .28), (s * .67, -2.04, .25), .12, 'veil')
        c.chain([(0, 0, 0), (s * .20, -1.13, .20), (s * .35, -2.43, .32)], .075, .018, 'fold')
        c.chain([(s * .10, -.52, .16), (s * .21, -1.24, .26), (s * .35, -2.42, .34)],
                .025, .018, 'gold')
        m.joint(name, name, (s * .31, 3.30, .21), 'cloth', -s)
    m.hand = (.82, .0, -.13)
    m.extra = dict(animation_style='cantor', hand_limb='arm_r', hover=.13, bob=.025,
                   waddle=0, glow_strength=1.2,
                   variants={f: {p: p + '_' + f for p in ('body', 'head')}
                             for f in ('veil', 'unbound')})
    return m


BUILDERS = {f.__name__: f for f in (
    temple_skink, vine_strangler, plume_wisp, jade_guardian, serpent_priest,
    obsidian_jaguar, ixalith, lost_soul, lantern_moth, grave_creeper,
    mourning_wraith, soul_warden, willow_matron, lantern_shepherd,
)}
HEIGHTS = dict(zip(BUILDERS, (.8, 1.6, 1.2, 2.8, 2.2, 2.0, 6.0,
                             1.2, 1.3, .9, 2.6, 2.6, 3.6, 6.0)))


def save_model(m):
    """Use the workshop export, then correct its flat rest-pose child placement.

    The workshop's standalone model export places child joints as root joints.
    Runtime parts are already correct. Rebuild only this model's model.vox with
    recursive joint origins, so it also opens correctly in a voxel editor.
    """
    for variant in m.extra.get('variants', {}).values():
        for base, replacement in variant.items():
            a, _ = fit_frame(m.parts[base].voxels())
            b, _ = fit_frame(m.parts[replacement].voxels())
            assert a == b, (m.name, base, replacement, a, b)
    folder = m.save()
    vox = {name: m._shade(p.voxels(hollow_above=6000)) for name, p in m.parts.items()}

    def origin(name):
        spec = m.limbs[name]
        parent = origin(spec['parent_limb']) if 'parent_limb' in spec else (0, 0, 0)
        return tuple(parent[k] + spec['pivot'][k] for k in range(3))

    full = dict(vox['body'])
    for name, spec in m.limbs.items():
        pivot = origin(name)
        for xyz, color in vox[spec['part']].items():
            full[tuple(xyz[k] + pivot[k] for k in range(3))] = color
    frame, size = fit_frame(full)
    assert max(size) <= 256, (m.name, size)
    write_vox(str(folder / 'model.vox'), full, m._full_palette(), frame, size)
    actual = size[1] * m.vs
    assert abs(actual - HEIGHTS[m.name]) < max(m.vs * 2, .12), (m.name, actual)
    print(f'{m.name}: {actual:.2f} m sculpt, {m.vs:g} m voxels; '
          + ', '.join(f'{n} ({s["role"]})' for n, s in m.limbs.items()), flush=True)


def main(argv):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('names', nargs='*', help='creature ids; default: all fourteen')
    parser.add_argument('--sheet', metavar='PNG', help='render four views with monster_studio.sheet')
    args = parser.parse_args(argv)
    names = args.names or list(BUILDERS)
    unknown = sorted(set(names) - BUILDERS.keys())
    if unknown:
        parser.error('unknown creature ids: ' + ', '.join(unknown))
    for name in names:
        save_model(BUILDERS[name]())
    if args.sheet:
        monster_studio.BOLD = str(ROOT / 'fonts/BreeSerif.ttf')
        sheet(names, args.sheet)


if __name__ == '__main__':
    main(sys.argv[1:])
