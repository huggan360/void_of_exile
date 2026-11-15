#!/usr/bin/env python3
"""The monster remake (2026-11): monsters that looked cheap, noisy or too
blocky, rebuilt at a readable voxel size with a few hand-picked tones and a
story-game look. Each keeps its size in game, its rig roles (so its
animations and boss poses still work) and its projectile.

    python3 tools/remake_monsters.py                # every remade monster
    python3 tools/remake_monsters.py ember_lich ... # some
    python3 tools/remake_monsters.py --sheet out.png ember_lich ...

See tools/monster_studio.py for the art rules.
"""
import json
import math
import sys

from preview_voxel_batch import ROOT, read_vox
from monster_studio import Model, sheet, robe, hood, staff, ring, plate, mirror_part

# --- Fosen -----------------------------------------------------------------------------

def aurora_sentinel():
    """A watcher of the northern lights: a tall frost mage in a long night-blue
    coat with a white fur mantle, the hood drawn, two cold eyes in the dark,
    and a slender ice wand that he raises toward you to cast."""
    m = Model('aurora_sentinel', 0.07, {
        'coat': (44, 56, 92), 'coat_dark': (26, 32, 58), 'fur': (214, 228, 236), 'void': (8, 10, 20),
        'leather': (72, 54, 50), 'boot': (36, 34, 44), 'glove': (56, 62, 86), 'silver': (178, 196, 210),
        'glow_ice': (150, 240, 255), 'glow_aurora': (96, 236, 186),
    }, rough=('fur',))
    b = m.part('body')
    robe(b, 1.5, 0.5, 0.21, 0.34, 'coat', trim='fur', trim_h=0.07)
    b.box((-0.05, 0.5, -0.36), (0.05, 1.05, -0.2), 'coat_dark')          # the coat's split
    b.ellipsoid((0, 1.42, 0.0), (0.25, 0.26, 0.17), 'coat')               # chest
    ring(b, (0, 1.08, 0), 0.25, 0.035, 'leather')                         # belt
    b.ellipsoid((0, 1.08, -0.25), (0.05, 0.045, 0.03), 'glow_aurora')     # buckle stone
    b.capsule((-0.17, 1.52, -0.16), (0.16, 1.14, -0.21), 0.025, 0.025, 'glow_aurora')  # aurora sash
    b.ellipsoid((0, 1.6, 0.02), (0.35, 0.12, 0.24), 'fur')               # mantle
    b.ellipsoid((0, 1.53, 0.08), (0.3, 0.1, 0.2), 'fur')
    hood(b, (0, 1.86, 0.0), 0.17, 'coat', 'void', eyes='glow_ice', eye_gap=0.06)
    b.capsule((0, 1.64, 0.18), (0, 0.9, 0.3), 0.12, 0.2, 'coat')         # hood falls to a short cape
    leg = m.part('leg')
    leg.capsule((0, -0.05, 0), (0, -0.5, 0), 0.075, 0.07, 'boot')
    leg.ellipsoid((0, -0.53, -0.05), (0.08, 0.05, 0.12), 'boot')
    ring(leg, (0, -0.2, 0), 0.075, 0.018, 'leather', n=16)
    m.joint('leg_l', 'leg', (-0.1, 0.56, 0), 'leg', 1)
    m.joint('leg_r', 'leg', (0.1, 0.56, 0), 'leg', -1)
    # Arms: the left hangs at his side, the right holds the wand and casts.
    arm_l = m.part('arm_l')
    arm_l.capsule((0, 0, 0), (0, -0.48, 0.02), 0.085, 0.1, 'coat')
    ring(arm_l, (0, -0.46, 0.02), 0.1, 0.03, 'fur', n=16)
    arm_l.ellipsoid((0, -0.56, 0.01), (0.06, 0.07, 0.06), 'glove')
    arm_r = m.part('arm_r')
    arm_r.capsule((0, 0, 0), (0, -0.48, -0.02), 0.085, 0.1, 'coat')
    ring(arm_r, (0, -0.46, -0.02), 0.1, 0.03, 'fur', n=16)
    arm_r.ellipsoid((0, -0.56, -0.03), (0.06, 0.07, 0.06), 'glove')
    # The wand runs on from the hand, angled forward: raised to cast it points
    # ahead and a little up.
    arm_r.capsule((0, -0.5, -0.02), (0, -0.98, -0.27), 0.034, 0.03, 'silver')
    ring(arm_r, (0, -0.86, -0.2), 0.045, 0.02, 'glow_aurora', axis='x', n=12)
    arm_r.ellipsoid((0, -1.05, -0.3), (0.06, 0.08, 0.06), 'glow_ice')
    m.joint('arm_l', 'arm_l', (-0.29, 1.55, 0.0), 'arm', 1, throws=False)
    m.joint('arm_r', 'arm_r', (0.29, 1.55, 0.0), 'arm', -1, throws=True)
    m.hand = (0.0, -1.04, -0.3)
    m.extra = dict(hand_limb='arm_r', hover=0, bob=0, waddle=0.25)
    return m


# --- Doom --------------------------------------------------------------------------------

def ember_lich():
    """A long-dead fire priest that floats: tattered ash robes glowing at the
    seams, a bone mask under the hood, a crown of black horns, and a tall
    staff of charred bone caging a molten heart. The right claw casts."""
    m = Model('ember_lich', 0.07, {
        'robe': (64, 50, 52), 'robe_dark': (36, 28, 34), 'void': (10, 7, 10), 'bone': (214, 196, 158),
        'bone_dark': (138, 116, 92), 'char': (40, 34, 36), 'gold': (176, 128, 64),
        'glow': (255, 116, 36), 'glow_hot': (255, 214, 120),
    }, rough=('robe', 'char'))
    b = m.part('body')
    robe(b, 1.55, 0.3, 0.22, 0.32, 'robe')
    # Ragged hem: tatters of different lengths with embers at their tips.
    for i in range(12):
        a = i * 6.283 / 12
        r = 0.31
        x, z = r * math.cos(a), r * math.sin(a)
        length = (0.18, 0.3, 0.12, 0.24)[i % 4]
        b.capsule((x, 0.36, z), (x * 1.08, 0.36 - length, z * 1.08), 0.06, 0.02, 'robe_dark')
        if i % 3 == 0:
            b.ellipsoid((x * 1.08, 0.33 - length, z * 1.08), (0.03, 0.03, 0.03), 'glow')
    # Cracks in the ash cloth where the fire inside shows through.
    b.chain([(0.02, 0.42, -0.32), (-0.04, 0.7, -0.29), (0.03, 0.95, -0.25), (-0.02, 1.18, -0.2)], 0.012, 0.012, 'glow')
    b.chain([(0.17, 0.55, -0.27), (0.14, 0.72, -0.25)], 0.012, 0.012, 'glow')
    b.ellipsoid((0, 1.42, 0.0), (0.25, 0.26, 0.17), 'robe')
    ring(b, (0, 1.1, 0), 0.24, 0.03, 'gold')
    # Bone pauldrons: small skulls on the shoulders.
    for side in (-1, 1):
        b.ellipsoid((side * 0.27, 1.6, 0.0), (0.12, 0.1, 0.13), 'bone')
        b.ellipsoid((side * 0.27, 1.58, -0.11), (0.06, 0.035, 0.02), 'void')
    hood(b, (0, 1.85, 0.02), 0.17, 'robe', 'void')
    # The mask: a long skull face set deep in the hood, embers for eyes.
    b.ellipsoid((0, 1.81, -0.1), (0.1, 0.13, 0.08), 'bone')
    b.box((-0.06, 1.69, -0.18), (0.06, 1.72, -0.14), 'bone_dark')        # teeth
    b.box((-0.015, 1.76, -0.19), (0.015, 1.79, -0.16), 'void')            # nose
    for side in (-1, 1):
        b.ellipsoid((side * 0.045, 1.84, -0.16), (0.03, 0.025, 0.02), 'void')
        b.ellipsoid((side * 0.045, 1.84, -0.18), (0.016, 0.016, 0.01), 'glow_hot')
    # Crown of bone horns through the hood, embers at the tips.
    for side, h in ((-1, 0.18), (0, 0.25), (1, 0.18)):
        tip = (side * 0.15, 2.02 + h, 0.06)
        b.capsule((side * 0.09, 1.98, 0.02), tip, 0.035, 0.014, 'bone_dark')
        b.ellipsoid(tip, (0.02, 0.025, 0.02), 'glow')
    # The staff in the left hand: charred bone, a cage, a molten heart.
    staff(b, (-0.36, 0.25, -0.14), (-0.36, 2.25, -0.14), 0.035, 'char')
    for a in range(4):
        dx, dz = ((0.08, 0), (0, 0.08), (-0.08, 0), (0, -0.08))[a]
        b.capsule((-0.36, 2.02, -0.14), (-0.36 + dx, 2.15, -0.14 + dz), 0.018, 0.018, 'bone_dark')
        b.capsule((-0.36 + dx, 2.15, -0.14 + dz), (-0.36, 2.34, -0.14), 0.018, 0.012, 'bone_dark')
    b.ellipsoid((-0.36, 2.17, -0.14), (0.06, 0.07, 0.06), 'glow_hot')
    b.capsule((-0.29, 1.52, -0.02), (-0.36, 1.25, -0.14), 0.08, 0.07, 'robe')   # the arm on the staff
    b.ellipsoid((-0.36, 1.2, -0.14), (0.05, 0.06, 0.05), 'bone')
    # The casting claw.
    arm = m.part('arm')
    arm.capsule((0, 0, 0), (0, -0.46, 0), 0.08, 0.11, 'robe')
    arm.capsule((0, -0.4, 0), (0, -0.5, 0), 0.115, 0.12, 'robe_dark')
    for dx in (-0.04, 0.0, 0.04):
        arm.capsule((0, -0.52, 0), (dx, -0.66, -0.06), 0.02, 0.012, 'bone')
    arm.ellipsoid((0, -0.58, -0.04), (0.04, 0.04, 0.04), 'glow')
    m.joint('arm_r', 'arm', (0.29, 1.56, 0.0), 'arm', -1, throws=True)
    m.hand = (0.0, -0.62, -0.06)
    m.extra = dict(hand_limb='arm_r', hover=0.2, bob=0.05, waddle=0.0)
    return m


def hoarfrost_owl():
    """A great snow owl that hunts the blizzards: a pale, speckled body, a
    flat facial disc with two ice-lit eyes and ear tufts, and broad layered
    wings whose longest feathers end in ice."""
    m = Model('hoarfrost_owl', 0.065, {
        'feather': (222, 230, 236), 'speckle': (150, 164, 182), 'wingtop': (186, 200, 214), 'quill': (98, 116, 146),
        'disc': (238, 242, 246), 'beak': (60, 62, 74), 'talon': (44, 46, 56), 'gold': (210, 170, 84),
        'glow_ice': (140, 236, 255),
    }, rough=('feather', 'wingtop'))
    b = m.part('body')
    b.ellipsoid((0, 1.0, 0.04), (0.3, 0.38, 0.28), 'feather')
    b.ellipsoid((0, 1.38, -0.02), (0.25, 0.22, 0.22), 'feather')            # head
    for x, y in ((-0.12, 0.82), (0.1, 0.92), (-0.05, 1.04), (0.14, 1.12), (-0.15, 1.15), (0.02, 0.74)):
        b.ellipsoid((x, y, -0.25), (0.035, 0.02, 0.02), 'speckle')          # chest bars
    b.ellipsoid((0, 1.37, -0.17), (0.21, 0.17, 0.07), 'disc')               # facial disc
    for side in (-1, 1):
        b.ellipsoid((side * 0.085, 1.4, -0.23), (0.06, 0.06, 0.03), 'gold')
        b.ellipsoid((side * 0.085, 1.4, -0.25), (0.035, 0.035, 0.02), 'glow_ice')
        b.capsule((side * 0.15, 1.52, -0.05), (side * 0.22, 1.66, 0.0), 0.05, 0.015, 'speckle')  # ear tufts
    b.capsule((0, 1.33, -0.24), (0, 1.27, -0.26), 0.025, 0.012, 'beak')
    for tx in (-0.12, 0.0, 0.12):                                           # tail fan
        b.capsule((0, 0.82, 0.22), (tx * 1.6, 0.6, 0.42), 0.05, 0.025, 'wingtop')
    for side in (-1, 1):                                                    # icy talons
        for dz in (-0.04, 0.04):
            b.capsule((side * 0.09, 0.66, dz), (side * 0.1, 0.55, dz - 0.06), 0.022, 0.012, 'talon')
    w = m.part('wing_l')
    # A broad wing: shoulder, wrist, tip and the trailing edge, as plates.
    shoulder, wrist, tip = (0, 0, 0), (-0.5, 0.12, 0.04), (-0.98, 0.02, 0.22)
    trail = [(-0.82, -0.02, 0.44), (-0.55, -0.03, 0.5), (-0.28, -0.03, 0.44), (-0.04, -0.02, 0.3)]
    w.triangle(shoulder, wrist, trail[3], 0.07, 'wingtop')
    w.triangle(wrist, trail[2], trail[3], 0.07, 'wingtop')
    w.triangle(wrist, trail[1], trail[2], 0.07, 'feather')
    w.triangle(wrist, tip, trail[1], 0.07, 'feather')
    w.triangle(tip, trail[0], trail[1], 0.07, 'feather')
    w.chain([shoulder, wrist, tip], 0.07, 0.03, 'wingtop')                  # leading edge
    for i, (a, b) in enumerate(zip([tip] + trail[:-1], trail)):             # dark feather tips
        w.capsule(a, ((a[0] + b[0]) / 2, -0.03, (a[2] + b[2]) / 2 + 0.05), 0.03, 0.02, 'quill')
    for t in (tip, trail[0], trail[1]):
        w.ellipsoid((t[0], t[1], t[2] + 0.03), (0.03, 0.025, 0.04), 'glow_ice')
    m.parts['wing_r'] = mirror_part(m, w)
    m.joint('wing_l', 'wing_l', (-0.26, 1.16, 0.04), 'wing', 1)
    m.joint('wing_r', 'wing_r', (0.26, 1.16, 0.04), 'wing', -1)
    m.hand = (0.0, 1.4, -0.3)
    m.extra = dict(hover=0.65, bob=0.05, waddle=0.0)
    return m


def obsidian_ram():
    """A ram of volcanic glass: a heavy black body cracked with magma, a crest
    of obsidian shards along the spine and two great spiral horns with fire
    in their grooves. Head low, ready to charge."""
    m = Model('obsidian_ram', 0.07, {
        'glass': (36, 30, 44), 'glass_light': (86, 74, 104), 'hoof': (22, 18, 24), 'horn': (168, 138, 118),
        'fleece': (66, 56, 76), 'glow': (255, 110, 34), 'glow_hot': (255, 210, 110),
    }, rough=('fleece',))
    b = m.part('body')
    b.ellipsoid((0, 1.0, 0.18), (0.34, 0.31, 0.6), 'glass')              # glassy barrel
    b.ellipsoid((0, 1.06, -0.22), (0.38, 0.38, 0.34), 'fleece')           # woolly chest and shoulders
    b.ellipsoid((0, 1.04, -0.62), (0.16, 0.19, 0.26), 'glass')            # long head, held low
    b.ellipsoid((0, 0.9, -0.86), (0.11, 0.12, 0.13), 'glass_light')       # muzzle
    b.ellipsoid((0, 0.84, -0.97), (0.06, 0.035, 0.03), 'glow')            # molten breath
    for side in (-1, 1):
        b.ellipsoid((side * 0.12, 1.08, -0.82), (0.035, 0.025, 0.02), 'glow_hot')
        # Spiral horn: back from the brow, down, and forward round the ear.
        pts = [(side * 0.1, 1.2, -0.6), (side * 0.22, 1.3, -0.5), (side * 0.3, 1.18, -0.42),
               (side * 0.29, 1.0, -0.48), (side * 0.23, 0.95, -0.6), (side * 0.21, 1.03, -0.7)]
        b.chain(pts, 0.085, 0.03, 'horn')
        b.chain(pts[1:5], 0.02, 0.02, 'glow')
    for i in range(6):                                                    # shard crest
        z = -0.3 + i * 0.16
        b.capsule((0, 1.36 - i * 0.02, z), (0, 1.56 - i * 0.03, z + 0.05), 0.06, 0.012, 'glass_light')
    b.chain([(0.38, 1.0, -0.2), (0.4, 0.86, 0.1), (0.36, 1.02, 0.4)], 0.015, 0.015, 'glow')
    b.chain([(-0.38, 1.04, -0.1), (-0.39, 0.9, 0.2)], 0.015, 0.015, 'glow')
    leg = m.part('leg')
    leg.capsule((0, 0, 0), (0, -0.48, 0.02), 0.09, 0.065, 'glass')
    leg.capsule((0, -0.48, 0.02), (0, -0.62, 0), 0.065, 0.07, 'glass_light')
    leg.ellipsoid((0, -0.66, -0.02), (0.1, 0.05, 0.11), 'hoof')
    for x in (-1, 1):
        for z in (-0.3, 0.42):
            m.joint(f'leg_{x}_{"f" if z < 0 else "b"}', 'leg', (x * 0.24, 0.7, z), 'leg', x * (1 if z < 0 else -1))
    m.hand = (0.0, 0.86, -0.96)
    m.extra = dict(hover=0, bob=0, waddle=0.2)
    return m


def dune_monolith():
    """A floating standing stone of the old desert kings: a carved obelisk
    wearing a pharaoh's mask, a sun eye burning in its brow, gold and
    turquoise inlay, stone fragments orbiting and sand pouring from its foot."""
    m = Model('dune_monolith', 0.07, {
        'stone': (196, 152, 98), 'stone_dark': (138, 102, 70), 'gold': (226, 178, 72), 'lapis': (54, 132, 150),
        'sand': (232, 200, 140), 'void': (40, 28, 30), 'glow': (255, 196, 80), 'glow_hot': (255, 240, 170),
    }, rough=('stone', 'stone_dark'))
    b = m.part('body')
    # The obelisk tapers up and ends in a pyramidion capped with gold.
    b.box((-0.32, 0.6, -0.24), (0.32, 1.9, 0.24), 'stone')
    b.box((-0.26, 1.9, -0.2), (0.26, 2.3, 0.2), 'stone')
    for i in range(4):
        r = 0.22 - i * 0.055
        b.box((-r, 2.3 + i * 0.06, -r * 0.8), (r, 2.36 + i * 0.06, r * 0.8), 'gold')
    b.box((-0.35, 0.9, -0.27), (0.35, 0.96, 0.27), 'gold')               # bands
    b.box((-0.35, 1.5, -0.27), (0.35, 1.54, 0.27), 'lapis')
    # The mask: headdress stripes, a calm face, the sun eye in the brow.
    b.box((-0.3, 1.62, -0.27), (0.3, 2.2, -0.22), 'stone_dark')
    for i in range(5):
        y = 1.66 + i * 0.1
        b.box((-0.3, y, -0.29), (-0.2, y + 0.05, -0.25), 'lapis')
        b.box((0.2, y, -0.29), (0.3, y + 0.05, -0.25), 'lapis')
    b.box((-0.18, 1.66, -0.3), (0.18, 2.05, -0.26), 'gold')
    for side in (-1, 1):
        b.box((side * 0.12 - 0.04, 1.86, -0.32), (side * 0.12 + 0.04, 1.89, -0.29), 'void')
    b.box((-0.03, 1.72, -0.32), (0.03, 1.82, -0.29), 'stone_dark')
    b.ellipsoid((0, 2.08, -0.29), (0.07, 0.07, 0.04), 'glow_hot')
    ring(b, (0, 2.08, -0.29), 0.1, 0.02, 'glow', axis='z', n=16)
    # Orbiting shards of the same stone, and the sand pouring from the broken foot.
    for i, (x, y, z) in enumerate(((-0.58, 1.3, 0.1), (0.56, 1.66, -0.08), (0.52, 0.92, 0.18), (-0.54, 2.02, -0.12))):
        s = 1 if x > 0 else -1
        b.triangle((x, y + 0.16, z), (x - s * 0.1, y - 0.12, z - 0.05), (x + s * 0.08, y - 0.1, z + 0.06), 0.1,
                   'stone' if i % 2 else 'stone_dark')
    for side in (-1, 1):                                                  # carved glyphs on the flanks
        for y in (1.05, 1.2, 1.35):
            b.box((side * 0.33 - 0.01, y, -0.1), (side * 0.33 + 0.01, y + 0.06, 0.1), 'stone_dark')
    b.box((-0.26, 0.45, -0.2), (0.22, 0.6, 0.2), 'stone_dark')
    b.capsule((0, 0.48, 0), (0, 0.0, 0), 0.14, 0.02, 'sand')
    m.hand = (0.0, 2.08, -0.36)
    m.extra = dict(hover=0.5, bob=0.05, waddle=0.0)
    return m


def runic_archivist():
    """A drowned scholar who never stopped reading: a hooded, floating figure
    in deep-sea blue robes trailing into a long scroll, an open book of
    glowing runes held before it and loose pages circling."""
    m = Model('runic_archivist', 0.06, {
        'robe': (34, 64, 112), 'robe_dark': (20, 36, 72), 'void': (6, 10, 22), 'paper': (226, 214, 180),
        'leather': (96, 56, 44), 'brass': (190, 150, 80), 'glow': (110, 220, 255), 'glow_rune': (170, 255, 236),
    })
    b = m.part('body')
    robe(b, 1.62, 0.98, 0.2, 0.27, 'robe', trim='brass', trim_h=0.05)
    b.chain([(0, 1.0, 0.05), (0.05, 0.84, 0.15), (-0.03, 0.72, 0.28), (0.02, 0.66, 0.42)], 0.2, 0.06, 'robe_dark')   # trailing scroll of cloth
    b.ellipsoid((0, 1.54, 0.0), (0.24, 0.22, 0.17), 'robe')
    b.ellipsoid((0, 1.68, 0.02), (0.3, 0.09, 0.22), 'robe_dark')         # shoulder cape
    hood(b, (0, 1.88, 0.0), 0.16, 'robe', 'void', eyes='glow', eye_gap=0.055)
    # Sleeves reaching forward to the open book.
    for side in (-1, 1):
        b.capsule((side * 0.24, 1.6, -0.02), (side * 0.18, 1.42, -0.3), 0.08, 0.1, 'robe')
        b.ellipsoid((side * 0.17, 1.4, -0.36), (0.05, 0.05, 0.05), 'paper')
    b.box((-0.26, 1.34, -0.52), (0.26, 1.38, -0.32), 'leather')
    b.box((-0.24, 1.38, -0.5), (-0.01, 1.42, -0.34), 'paper')
    b.box((0.01, 1.38, -0.5), (0.24, 1.42, -0.34), 'paper')
    for x in (-0.18, -0.08, 0.08, 0.18):
        b.box((x - 0.03, 1.42, -0.46), (x + 0.03, 1.44, -0.38), 'glow_rune')
    b.ellipsoid((0, 1.56, -0.42), (0.06, 0.06, 0.06), 'glow')               # a rune rising from the page
    for x, y, z, a in ((-0.5, 1.9, 0.1, 0), (0.48, 1.7, -0.1, 1), (0.42, 2.1, 0.2, 0), (-0.44, 1.48, -0.18, 1)):
        b.box((x - 0.08, y - 0.06, z - 0.01), (x + 0.08, y + 0.06, z + 0.01), 'paper')
        b.box((x - 0.04, y - 0.01, z - 0.02), (x + 0.04, y + 0.01, z + 0.02), 'glow_rune')
    m.hand = (0.0, 1.56, -0.46)
    m.extra = dict(hover=0.0, bob=0.06, waddle=0.0)
    return m


def azure_medusa():
    """A deep-sea medusa: a tall glassy bell with a glowing heart, a calm
    pale mask beneath its rim like a drowned saint, and six long tentacles
    strung with light."""
    m = Model('azure_medusa', 0.06, {
        'bell': (58, 118, 196), 'bell_light': (110, 176, 232), 'rim': (178, 222, 248), 'mask': (216, 226, 236),
        'void': (10, 22, 42), 'tentacle': (70, 110, 186), 'glow': (120, 230, 255), 'glow_core': (230, 255, 255),
    })
    b = m.part('body')
    b.ellipsoid((0, 1.62, 0), (0.42, 0.34, 0.42), 'bell')
    b.ellipsoid((0, 1.74, 0), (0.32, 0.26, 0.32), 'bell_light')
    b.ellipsoid((0, 1.62, 0), (0.16, 0.16, 0.16), 'glow_core')
    ring(b, (0, 1.36, 0), 0.4, 0.05, 'rim', n=36)
    for i in range(10):                                                    # frilled rim
        a = i * math.tau / 10
        b.ellipsoid((math.cos(a) * 0.4, 1.3, math.sin(a) * 0.4), (0.07, 0.07, 0.07), 'rim')
    for i in range(6):                                                     # light veins on the bell
        a = i * math.tau / 6
        b.chain([(math.cos(a) * 0.12, 1.92, math.sin(a) * 0.12), (math.cos(a) * 0.33, 1.72, math.sin(a) * 0.33),
                 (math.cos(a) * 0.4, 1.46, math.sin(a) * 0.4)], 0.015, 0.015, 'glow')
    # The mask beneath the rim, eyes closed, a single tear of light.
    b.ellipsoid((0, 1.12, -0.24), (0.14, 0.17, 0.08), 'mask')
    for side in (-1, 1):
        b.box((side * 0.055 - 0.035, 1.16, -0.33), (side * 0.055 + 0.035, 1.18, -0.3), 'void')
    b.box((-0.03, 1.03, -0.33), (0.03, 1.05, -0.3), 'void')
    b.ellipsoid((0.055, 1.1, -0.32), (0.015, 0.03, 0.01), 'glow')
    b.capsule((0, 1.3, -0.2), (0, 1.22, -0.24), 0.06, 0.05, 'rim')       # the mask hangs from the rim
    t = m.part('tentacle')
    t.chain([(0, 0, 0), (0.02, -0.25, 0.03), (-0.02, -0.5, 0.0), (0.03, -0.75, 0.04), (0, -0.95, 0)], 0.05, 0.018, 'tentacle')
    for y in (-0.3, -0.55, -0.8):
        t.ellipsoid((0.0, y, 0.0), (0.03, 0.03, 0.03), 'glow')
    for i in range(6):
        a = -0.15 + i * (math.pi + 0.3) / 5                                # sides and back: the face stays clear
        m.joint(f'tentacle_{i}', 'tentacle', (math.cos(a) * 0.28, 1.32, math.sin(a) * 0.28), 'sway', 1)
    m.hand = (0.0, 1.62, -0.4)
    m.extra = dict(hover=0.45, bob=0.05, waddle=0.0)
    return m


def vine_mantis():
    """A mantis grown from the forest: a slim green body, folded leaf wings,
    a triangular head with amber eyes and two scythes of thorned vine."""
    m = Model('vine_mantis', 0.06, {
        'leaf': (88, 150, 64), 'leaf_dark': (52, 98, 48), 'bark': (98, 74, 50), 'wing': (150, 196, 98),
        'thorn': (214, 196, 140), 'eye': (226, 168, 60), 'glow': (190, 240, 110),
    }, rough=('leaf_dark',))
    b = m.part('body')
    # A broad leaf-shaped abdomen low behind, the thorax rearing up, the head
    # on top: the classic praying silhouette.
    b.ellipsoid((0, 0.7, 0.36), (0.2, 0.17, 0.46), 'leaf_dark')
    for z in (0.12, 0.3, 0.48, 0.66):
        ring(b, (0, 0.7, z), 0.16 - abs(z - 0.38) * 0.15, 0.02, 'leaf', axis='x', n=16)
    b.chain([(0, 0.72, -0.02), (0, 0.98, -0.12), (0, 1.22, -0.18)], 0.12, 0.08, 'leaf')
    b.ellipsoid((0, 1.34, -0.22), (0.16, 0.1, 0.1), 'leaf')              # wide triangular head
    b.ellipsoid((0, 1.25, -0.29), (0.06, 0.07, 0.05), 'leaf_dark')
    for side in (-1, 1):
        b.ellipsoid((side * 0.14, 1.37, -0.23), (0.06, 0.07, 0.06), 'eye')
        b.capsule((side * 0.04, 1.42, -0.27), (side * 0.14, 1.66, -0.36), 0.014, 0.008, 'leaf_dark')
        b.triangle((side * 0.05, 0.92, -0.04), (side * 0.24, 0.8, 0.62), (side * 0.04, 0.76, 0.7), 0.05, 'wing')
        b.chain([(side * 0.06, 0.92, -0.02), (side * 0.15, 0.82, 0.46)], 0.014, 0.014, 'leaf_dark')
    b.ellipsoid((0, 0.64, 0.8), (0.05, 0.05, 0.05), 'glow')
    for side in (-1, 1):                                                   # middle legs, bent like a mantis
        b.chain([(side * 0.08, 0.74, 0.06), (side * 0.36, 0.6, 0.0), (side * 0.42, 0.0, -0.06)], 0.035, 0.022, 'leaf_dark')
    leg = m.part('leg')
    leg.chain([(0, 0, 0), (0.18, -0.12, 0.08), (0.24, -0.66, 0.16)], 0.035, 0.022, 'leaf_dark')
    m.joint('leg_l', 'leg', (-0.08, 0.66, 0.4), 'leg', 1)
    m.joint('leg_r', 'leg', (0.08, 0.66, 0.4), 'leg', -1)
    for side, name in ((-1, 'arm_l'), (1, 'arm_r')):
        a = m.part(name)
        # Folded scythes: upper arm forward and down, the blade folded back up.
        a.chain([(0, 0, 0), (side * 0.04, -0.2, -0.24)], 0.055, 0.05, 'leaf')
        a.chain([(side * 0.04, -0.2, -0.24), (side * 0.05, 0.08, -0.4), (side * 0.04, 0.26, -0.34)], 0.045, 0.014, 'bark')
        for t in (0.2, 0.45, 0.7):
            y, z = -0.2 + 0.4 * t, -0.24 - 0.16 * t
            a.capsule((side * 0.05, y, z), (side * 0.05, y - 0.07, z + 0.07), 0.02, 0.008, 'thorn')
        m.joint(name, name, (side * 0.1, 1.14, -0.16), 'claw', 1 if side < 0 else -1)
    m.hand = (0.0, 1.34, -0.34)
    m.extra = dict(hover=0, bob=0, waddle=0.2)
    return m


def moss_tortoise():
    """An old forest tortoise that has slept under the trees for a century:
    a high domed shell grown over with moss, a standing stone, mushrooms and
    small lights, a wise wrinkled head and four slow, heavy legs."""
    m = Model('moss_tortoise', 0.065, {
        'shell': (104, 84, 58), 'plate': (138, 112, 72), 'moss': (82, 132, 60), 'moss_dark': (54, 92, 46),
        'skin': (122, 120, 92), 'skin_dark': (84, 82, 66), 'stone': (132, 132, 128), 'cap': (196, 84, 64),
        'stem': (226, 214, 186), 'eye': (24, 22, 20), 'glow': (190, 255, 140),
    }, rough=('moss', 'moss_dark', 'shell'))
    b = m.part('body')
    b.ellipsoid((0, 0.62, 0.06), (0.48, 0.36, 0.6), 'shell')
    for x, z in ((0, 0.06), (-0.28, -0.18), (0.28, -0.18), (-0.3, 0.3), (0.3, 0.3), (0, -0.38), (0, 0.48)):
        b.ellipsoid((x, 0.74 + (0.18 if x == 0 else 0.06), z), (0.16, 0.08, 0.16), 'plate')
    b.ellipsoid((0, 0.88, 0.0), (0.36, 0.14, 0.44), 'moss')
    b.ellipsoid((-0.12, 0.95, 0.18), (0.18, 0.08, 0.2), 'moss_dark')
    b.box((0.08, 0.92, -0.06), (0.2, 1.22, 0.06), 'stone')                 # standing stone
    b.box((0.06, 1.18, -0.08), (0.22, 1.24, 0.08), 'moss')
    for x, z, h in ((-0.2, -0.12, 0.12), (-0.26, 0.0, 0.08), (0.24, 0.24, 0.1)):
        b.capsule((x, 0.92, z), (x, 0.92 + h, z), 0.025, 0.025, 'stem')
        b.ellipsoid((x, 0.94 + h, z), (0.06, 0.035, 0.06), 'cap')
    for x, z in ((0.0, 0.3), (-0.12, -0.24), (0.3, -0.02)):
        b.ellipsoid((x, 1.0, z), (0.025, 0.025, 0.025), 'glow')
    b.ellipsoid((0, 0.4, 0.04), (0.44, 0.08, 0.54), 'plate')               # belly rim
    # The head reaching out, heavy-lidded.
    b.chain([(0, 0.48, -0.5), (0, 0.5, -0.66), (0, 0.54, -0.76)], 0.12, 0.1, 'skin')
    b.ellipsoid((0, 0.56, -0.82), (0.12, 0.1, 0.13), 'skin')
    for side in (-1, 1):
        b.ellipsoid((side * 0.08, 0.6, -0.88), (0.02, 0.02, 0.02), 'eye')
        b.capsule((side * 0.05, 0.63, -0.86), (side * 0.11, 0.62, -0.84), 0.015, 0.015, 'skin_dark')   # heavy lids
    b.box((-0.06, 0.5, -0.94), (0.06, 0.52, -0.9), 'skin_dark')            # mouth
    b.capsule((0, 0.5, 0.6), (0, 0.42, 0.72), 0.06, 0.02, 'skin')          # tail
    leg = m.part('leg')
    leg.capsule((0, 0, 0), (0, -0.3, -0.02), 0.12, 0.11, 'skin')
    leg.ellipsoid((0, -0.32, -0.05), (0.12, 0.05, 0.14), 'skin_dark')
    for x in (-1, 1):
        for z in (-0.3, 0.36):
            m.joint(f'leg_{x}_{"f" if z < 0 else "b"}', 'leg', (x * 0.32, 0.36, z), 'leg', x * (1 if z < 0 else -1), amount=0.5)
    m.hand = (0.0, 0.54, -0.96)
    m.extra = dict(hover=0, bob=0, waddle=0.1)
    return m



# --- The courts beneath the world: Cinder Depths, the Sunken Court ------------------------

def cinder_cultist():
    """A fire cultist of the Cinder Depths: a tall pointed hood over an iron
    mask with a burning slit, robes the color of dried blood scorched at
    the hem, chains across the chest, and a smoking censer on a short chain."""
    m = Model('cinder_cultist', 0.075, {
        'robe': (112, 34, 34), 'robe_dark': (64, 20, 26), 'iron': (74, 70, 74), 'iron_dark': (40, 38, 44),
        'rope': (150, 112, 70), 'skin': (126, 92, 80), 'void': (14, 8, 10), 'ash': (58, 50, 50),
        'glow': (255, 120, 40), 'glow_hot': (255, 214, 120),
    }, rough=('robe', 'ash'))
    b = m.part('body')
    robe(b, 1.55, 0.36, 0.22, 0.29, 'robe', trim='ash', trim_h=0.08)
    b.ellipsoid((0, 1.45, 0), (0.26, 0.27, 0.18), 'robe')
    b.box((-0.06, 0.36, -0.31), (0.06, 1.2, -0.2), 'robe_dark')
    ring(b, (0, 1.06, 0), 0.25, 0.03, 'rope')
    b.capsule((-0.04, 1.04, -0.26), (-0.08, 0.78, -0.3), 0.02, 0.02, 'rope')
    b.chain([(-0.2, 1.58, -0.16), (0, 1.4, -0.2), (0.2, 1.58, -0.16)], 0.02, 0.02, 'iron')      # chains
    b.ellipsoid((0, 1.38, -0.2), (0.05, 0.05, 0.03), 'glow')                                      # brand
    b.ellipsoid((0, 1.6, 0.04), (0.33, 0.1, 0.22), 'robe_dark')                                    # mantle
    hood(b, (0, 1.86, 0.0), 0.18, 'robe', 'void', point=0.3)
    b.capsule((0, 1.98, 0.04), (0, 2.38, 0.14), 0.12, 0.02, 'robe')                                # tall point
    b.ellipsoid((0, 1.84, -0.12), (0.11, 0.13, 0.06), 'iron')                                      # the mask
    b.box((-0.08, 1.86, -0.19), (0.08, 1.88, -0.16), 'glow_hot')                                    # burning slit
    b.box((-0.01, 1.74, -0.19), (0.01, 1.84, -0.16), 'iron_dark')
    leg = m.part('leg')
    leg.capsule((0, -0.1, 0), (0, -0.38, 0), 0.07, 0.065, 'ash')
    leg.ellipsoid((0, -0.41, -0.05), (0.07, 0.04, 0.11), 'iron_dark')
    m.joint('leg_l', 'leg', (-0.1, 0.44, 0), 'leg', 1)
    m.joint('leg_r', 'leg', (0.1, 0.44, 0), 'leg', -1)
    arm = m.part('arm')
    arm.capsule((0, 0, 0), (0, -0.5, 0), 0.085, 0.11, 'robe')
    arm.ellipsoid((0, -0.58, -0.02), (0.06, 0.07, 0.06), 'skin')
    w = m.part('weapon')
    w.capsule((0, 0, 0), (0, -0.5, 0), 0.085, 0.11, 'robe')
    w.ellipsoid((0, -0.58, -0.02), (0.06, 0.07, 0.06), 'skin')
    w.chain([(0, -0.6, -0.04), (0, -0.72, -0.12), (0, -0.84, -0.16)], 0.016, 0.016, 'iron')       # censer chain
    w.ellipsoid((0, -0.94, -0.18), (0.11, 0.1, 0.11), 'iron_dark')
    ring(w, (0, -0.94, -0.18), 0.11, 0.02, 'iron', n=16)
    w.ellipsoid((0, -0.9, -0.18), (0.07, 0.04, 0.07), 'glow_hot')
    w.capsule((0, -0.88, -0.18), (0.02, -0.72, -0.22), 0.04, 0.01, 'glow')                         # flame tongue
    m.joint('arm_l', 'arm', (-0.3, 1.56, 0), 'arm', 1, throws=False)
    m.joint('arm_r', 'weapon', (0.3, 1.56, 0), 'arm', -1, throws=True)
    m.hand = (0.0, -0.94, -0.18)
    m.extra = dict(hand_limb='arm_r', hover=0, bob=0.03, waddle=0.15)
    return m


def mummy_guard():
    """A guard of the Sunken Court who never left his post: linen wrappings
    loose at the ends, a striped royal headdress, a gold collar, two pale
    eyes, a bronze shield on one arm and a curved khopesh in the other."""
    m = Model('mummy_guard', 0.08, {
        'linen': (198, 182, 146), 'linen_dark': (146, 130, 100), 'nemes': (40, 86, 140), 'gold': (222, 176, 70),
        'bronze': (170, 110, 60), 'bronze_dark': (110, 70, 44), 'void': (30, 24, 22), 'glow': (110, 255, 220),
    }, rough=('linen', 'linen_dark'))
    b = m.part('body')
    b.capsule((0, 1.0, 0), (0, 1.62, 0), 0.24, 0.27, 'linen')                                     # torso
    for y in (1.06, 1.22, 1.38, 1.54):
        ring(b, (0, y, 0), 0.25 + (y - 1.0) * 0.04, 0.022, 'linen_dark')
    b.box((-0.26, 0.86, -0.24), (0.26, 1.06, 0.24), 'nemes')                                       # kilt
    b.box((-0.08, 0.66, -0.26), (0.08, 1.06, -0.22), 'gold')
    ring(b, (0, 1.68, 0.0), 0.24, 0.07, 'gold', n=28)                                             # broad collar
    b.capsule((0, 1.72, 0), (0, 1.86, 0), 0.08, 0.08, 'linen')
    b.ellipsoid((0, 2.0, -0.02), (0.16, 0.18, 0.16), 'linen')                                      # head
    b.box((-0.11, 2.0, -0.18), (0.11, 2.04, -0.15), 'void')
    for side in (-1, 1):
        b.ellipsoid((side * 0.06, 2.02, -0.18), (0.022, 0.018, 0.012), 'glow')
    # The nemes: a striped headcloth over the crown and down to the shoulders.
    b.ellipsoid((0, 2.08, 0.02), (0.19, 0.16, 0.18), 'nemes')
    for side in (-1, 1):
        b.box((side * 0.2 - 0.06, 1.62, -0.08), (side * 0.2 + 0.06, 2.06, 0.08), 'nemes')
        for y in (1.7, 1.82, 1.94):
            b.box((side * 0.2 - 0.065, y, -0.085), (side * 0.2 + 0.065, y + 0.04, 0.085), 'gold')
    b.box((-0.03, 2.12, -0.2), (0.03, 2.2, -0.16), 'gold')                                          # uraeus
    for x, y in ((-0.18, 1.0), (0.12, 0.82), (0.22, 1.3)):                                         # loose ends
        b.capsule((x, y, 0.2), (x * 1.3, y - 0.24, 0.3), 0.03, 0.015, 'linen_dark')
    leg = m.part('leg')
    leg.capsule((0, 0, 0), (0, -0.78, 0.02), 0.1, 0.08, 'linen')
    for y in (-0.2, -0.42, -0.62):
        ring(leg, (0, y, 0.01), 0.09, 0.018, 'linen_dark', n=16)
    leg.ellipsoid((0, -0.82, -0.05), (0.08, 0.04, 0.12), 'linen_dark')
    m.joint('leg_l', 'leg', (-0.13, 0.86, 0), 'leg', 1)
    m.joint('leg_r', 'leg', (0.13, 0.86, 0), 'leg', -1)
    arm = m.part('arm')                                                                             # shield arm
    arm.capsule((0, 0, 0), (0, -0.55, -0.04), 0.075, 0.07, 'linen')
    arm.ellipsoid((-0.1, -0.42, -0.16), (0.06, 0.3, 0.3), 'bronze')
    ring(arm, (-0.13, -0.42, -0.16), 0.27, 0.025, 'gold', axis='x', n=24)
    arm.ellipsoid((-0.16, -0.42, -0.16), (0.03, 0.07, 0.07), 'bronze_dark')
    w = m.part('weapon')
    w.capsule((0, 0, 0), (0, -0.55, -0.04), 0.075, 0.07, 'linen')
    w.ellipsoid((0, -0.62, -0.06), (0.05, 0.06, 0.05), 'linen_dark')
    w.capsule((0, -0.6, -0.06), (0, -0.62, -0.28), 0.025, 0.025, 'gold')                           # khopesh: grip
    w.chain([(0, -0.62, -0.28), (0, -0.56, -0.46), (0, -0.66, -0.62), (0, -0.82, -0.62)], 0.04, 0.02, 'bronze')
    m.joint('arm_l', 'arm', (-0.33, 1.6, 0), 'arm', 1, throws=False)
    m.joint('arm_r', 'weapon', (0.33, 1.6, 0), 'arm', -1, throws=True)
    m.hand = (0.0, -0.66, -0.6)
    m.extra = dict(hand_limb='arm_r', hover=0, bob=0.02, waddle=0.12)
    return m


def gilded_sentinel():
    """A temple guardian of gold and lapis with a jackal's head, standing
    forever at its door: a tall glaive, a sun disc on its breast, a pleated
    kilt and two eyes of white fire."""
    m = Model('gilded_sentinel', 0.11, {
        'gold': (214, 168, 66), 'gold_dark': (150, 108, 46), 'lapis': (36, 72, 140), 'black': (34, 30, 36),
        'linen': (226, 214, 180), 'void': (20, 14, 16), 'glow': (255, 236, 170), 'glow_sun': (255, 190, 80),
    })
    b = m.part('body')
    b.capsule((0, 1.75, 0), (0, 2.65, 0), 0.4, 0.5, 'gold')                                       # torso
    b.ellipsoid((0, 2.5, -0.14), (0.42, 0.34, 0.3), 'gold')                                        # chest
    b.ellipsoid((0, 2.45, -0.42), (0.16, 0.16, 0.06), 'glow_sun')                                  # sun disc
    ring(b, (0, 2.45, -0.42), 0.2, 0.04, 'gold_dark', axis='z', n=24)
    b.box((-0.48, 1.4, -0.4), (0.48, 1.85, 0.4), 'linen')                                         # pleated kilt
    for x in (-0.36, -0.18, 0.0, 0.18, 0.36):
        b.box((x - 0.03, 1.4, -0.42), (x + 0.03, 1.85, -0.38), 'gold_dark')
    b.box((-0.5, 1.8, -0.42), (0.5, 1.9, 0.42), 'lapis')
    for side in (-1, 1):                                                                           # shoulder plates
        b.ellipsoid((side * 0.56, 2.72, 0), (0.24, 0.2, 0.26), 'gold_dark')
        b.box((side * 0.56 - 0.2, 2.7, -0.27), (side * 0.56 + 0.2, 2.74, 0.27), 'lapis')
    # The jackal head: long snout, tall ears, black and gold.
    b.capsule((0, 2.8, 0), (0, 3.0, 0), 0.16, 0.16, 'gold')
    b.ellipsoid((0, 3.18, 0.0), (0.22, 0.24, 0.24), 'black')
    b.chain([(0, 3.12, -0.16), (0, 3.06, -0.38), (0, 3.02, -0.52)], 0.13, 0.07, 'black')
    for side in (-1, 1):
        b.capsule((side * 0.12, 3.3, 0.02), (side * 0.16, 3.72, 0.08), 0.08, 0.02, 'black')
        b.capsule((side * 0.12, 3.32, -0.02), (side * 0.15, 3.62, 0.03), 0.04, 0.01, 'gold')
        b.ellipsoid((side * 0.1, 3.2, -0.18), (0.04, 0.025, 0.02), 'glow')
    ring(b, (0, 2.96, 0), 0.2, 0.05, 'gold_dark', n=24)                                            # collar
    leg = m.part('leg')
    leg.capsule((0, 0, 0), (0, -1.36, 0.04), 0.17, 0.13, 'black')
    leg.box((-0.16, -0.95, -0.17), (0.16, -0.55, 0.15), 'gold')                                     # greave
    leg.ellipsoid((0, -1.4, -0.08), (0.14, 0.07, 0.22), 'gold_dark')
    m.joint('leg_l', 'leg', (-0.24, 1.42, 0), 'leg', 1)
    m.joint('leg_r', 'leg', (0.24, 1.42, 0), 'leg', -1)
    arm = m.part('arm')
    arm.capsule((0, 0, 0), (0, -0.9, 0), 0.14, 0.12, 'black')
    arm.box((-0.14, -0.75, -0.14), (0.14, -0.45, 0.14), 'gold')
    arm.ellipsoid((0, -1.0, -0.02), (0.11, 0.12, 0.11), 'gold_dark')
    w = m.part('weapon')
    w.capsule((0, 0, 0), (0, -0.9, 0), 0.14, 0.12, 'black')
    w.box((-0.14, -0.75, -0.14), (0.14, -0.45, 0.14), 'gold')
    w.ellipsoid((0, -1.0, -0.02), (0.11, 0.12, 0.11), 'gold_dark')
    # The glaive stands upright at rest; raised to strike, it swings ahead.
    w.capsule((0, -1.75, -0.08), (0, 0.55, -0.08), 0.045, 0.045, 'black')
    w.triangle((0, 0.5, -0.08), (0, 0.78, -0.3), (0, 1.25, -0.02), 0.06, 'gold')
    w.ellipsoid((0, 0.5, -0.08), (0.06, 0.06, 0.06), 'glow_sun')
    w.ellipsoid((0, -1.78, -0.08), (0.06, 0.06, 0.06), 'gold_dark')
    m.joint('arm_l', 'arm', (-0.62, 2.62, 0), 'arm', 1, throws=False)
    m.joint('arm_r', 'weapon', (0.62, 2.62, 0), 'arm', -1, throws=True)
    m.hand = (0.0, 0.9, -0.12)
    m.extra = dict(hand_limb='arm_r', hover=0, bob=0.0, waddle=0.05)
    return m


def obsidian_brute():
    """A hulking brute of black volcanic glass: shoulders like boulders, a
    small head sunk between them, magma in every crack, knuckles that drag,
    and a club of raw obsidian."""
    m = Model('obsidian_brute', 0.11, {
        'glass': (40, 34, 46), 'glass_light': (88, 76, 104), 'rock': (66, 54, 52), 'glow': (255, 106, 30),
        'glow_hot': (255, 210, 110),
    }, rough=('rock',))
    b = m.part('body')
    b.ellipsoid((0, 2.3, 0.1), (0.78, 0.7, 0.62), 'glass')                                         # hunched back
    b.ellipsoid((0, 2.1, -0.2), (0.7, 0.62, 0.5), 'glass')
    b.ellipsoid((0, 1.6, 0.0), (0.5, 0.4, 0.4), 'rock')                                            # belly
    for side in (-1, 1):
        b.ellipsoid((side * 0.68, 2.58, 0.0), (0.42, 0.4, 0.42), 'glass_light')                  # boulder shoulders
        for i in range(3):
            b.capsule((side * (0.55 + i * 0.12), 2.86, 0.05 - i * 0.1), (side * (0.6 + i * 0.16), 3.25 - i * 0.08, 0.1 - i * 0.12),
                      0.1, 0.02, 'glass_light')                                                     # shard spikes
    b.ellipsoid((0, 2.5, -0.62), (0.22, 0.2, 0.2), 'glass')                                        # small sunk head
    b.box((-0.16, 2.55, -0.82), (0.16, 2.59, -0.78), 'glass_light')                                 # brow
    for side in (-1, 1):
        b.ellipsoid((side * 0.08, 2.5, -0.8), (0.035, 0.03, 0.02), 'glow_hot')
    b.box((-0.1, 2.36, -0.8), (0.1, 2.39, -0.76), 'glow')                                           # molten mouth
    for pts in ([(-0.3, 2.0, -0.62), (-0.16, 1.8, -0.5), (-0.24, 1.55, -0.38)], [(0.36, 2.3, -0.58), (0.2, 2.1, -0.66)],
                [(0.5, 2.0, 0.4), (0.3, 2.4, 0.56), (0.1, 2.6, 0.62)]):
        b.chain(pts, 0.03, 0.03, 'glow')
    leg = m.part('leg')
    leg.capsule((0, 0, 0), (0, -1.2, 0.06), 0.24, 0.2, 'glass')
    leg.ellipsoid((0, -1.3, -0.08), (0.24, 0.1, 0.3), 'rock')
    m.joint('leg_l', 'leg', (-0.36, 1.32, 0.06), 'leg', 1)
    m.joint('leg_r', 'leg', (0.36, 1.32, 0.06), 'leg', -1)
    arm = m.part('arm')
    arm.capsule((0, 0, 0), (0.06, -1.1, -0.06), 0.24, 0.22, 'glass')
    arm.ellipsoid((0.06, -1.3, -0.08), (0.28, 0.26, 0.28), 'glass_light')                          # fist
    arm.chain([(0.1, -0.3, -0.2), (0.0, -0.7, -0.22)], 0.025, 0.025, 'glow')
    w = m.part('weapon')
    w.capsule((0, 0, 0), (-0.06, -1.1, -0.06), 0.24, 0.22, 'glass')
    w.ellipsoid((-0.06, -1.26, -0.08), (0.24, 0.22, 0.24), 'glass_light')
    w.capsule((-0.06, -1.26, 0.25), (-0.06, -1.3, -0.5), 0.07, 0.07, 'rock')                        # club haft
    w.ellipsoid((-0.06, -1.32, -0.9), (0.26, 0.3, 0.42), 'glass_light')                             # club head
    for dz, dy in ((-0.7, 0.24), (-0.95, 0.28), (-1.15, 0.1), (-0.95, -0.28)):
        w.capsule((-0.06, -1.32, dz), (-0.06, -1.32 + dy * 1.6, dz - 0.1), 0.08, 0.01, 'glass')
    w.ellipsoid((-0.06, -1.32, -0.9), (0.08, 0.1, 0.2), 'glow')
    m.joint('arm_l', 'arm', (-0.86, 2.5, 0.0), 'arm', 1, throws=False)
    m.joint('arm_r', 'weapon', (0.86, 2.5, 0.0), 'arm', -1, throws=True)
    m.hand = (-0.06, -1.32, -1.0)
    m.extra = dict(hand_limb='arm_r', hover=0, bob=0.0, waddle=0.1)
    return m


def lava_golem():
    """Magma that learned to walk: a body of cooled black crust over a molten
    heart, the crust split into plates with fire between, a furnace for a
    head and heavy fists that drip."""
    m = Model('lava_golem', 0.095, {
        'crust': (62, 48, 44), 'crust_light': (104, 84, 74), 'ash': (130, 116, 108), 'glow': (255, 96, 24),
        'glow_hot': (255, 196, 90),
    }, rough=('crust',))
    b = m.part('body')
    b.ellipsoid((0, 1.9, 0), (0.56, 0.6, 0.42), 'glow')                                            # molten core
    plates = [((-0.3, 2.1, -0.32), (0.26, 0.3, 0.12)), ((0.3, 2.12, -0.32), (0.26, 0.28, 0.12)),
              ((0, 1.62, -0.36), (0.36, 0.22, 0.12)), ((-0.46, 1.86, 0.0), (0.12, 0.38, 0.32)),
              ((0.46, 1.86, 0.0), (0.12, 0.38, 0.32)), ((0, 1.95, 0.36), (0.48, 0.5, 0.12)),
              ((0, 2.42, 0.0), (0.46, 0.14, 0.36))]
    for c, r in plates:                       # crust plates, fire showing between them
        b.ellipsoid(c, tuple(v * 0.8 for v in r), 'crust')
    # Fissures: rivers of fire between the plates, front and back.
    for z in (-0.44, 0.46):
        b.chain([(-0.44, 2.3, z * 0.9), (-0.16, 2.08, z), (0.0, 2.24, z), (0.18, 1.98, z), (0.4, 2.18, z * 0.9)], 0.05, 0.05, 'glow')
        b.chain([(-0.3, 1.82, z * 0.95), (-0.04, 1.7, z), (0.26, 1.8, z * 0.95)], 0.045, 0.045, 'glow')
        b.chain([(0.0, 2.24, z), (0.04, 2.42, z * 0.9)], 0.04, 0.04, 'glow_hot')
    b.ellipsoid((0, 1.38, 0), (0.42, 0.24, 0.34), 'crust')                                          # hips
    for side in (-1, 1):
        b.ellipsoid((side * 0.6, 2.36, 0), (0.3, 0.26, 0.3), 'crust_light')
    # Furnace head: a crust helm with a grate of fire.
    b.ellipsoid((0, 2.7, -0.08), (0.22, 0.2, 0.2), 'crust')
    b.box((-0.13, 2.62, -0.29), (0.13, 2.76, -0.25), 'glow_hot')
    for x in (-0.07, 0.0, 0.07):
        b.box((x - 0.012, 2.6, -0.31), (x + 0.012, 2.78, -0.28), 'crust_light')
    b.ellipsoid((0, 2.88, 0.0), (0.06, 0.08, 0.06), 'ash')                                          # smoke
    b.ellipsoid((0.03, 3.0, 0.04), (0.08, 0.07, 0.08), 'ash')
    leg = m.part('leg')
    leg.capsule((0, 0, 0), (0, -0.98, 0.04), 0.19, 0.16, 'crust')
    leg.box((-0.2, -0.6, -0.02), (0.2, -0.56, 0.02), 'glow')
    leg.ellipsoid((0, -1.04, -0.06), (0.2, 0.08, 0.24), 'crust_light')
    m.joint('leg_l', 'leg', (-0.26, 1.1, 0), 'leg', 1)
    m.joint('leg_r', 'leg', (0.26, 1.1, 0), 'leg', -1)
    for name in ('arm', 'weapon'):
        a = m.part(name)
        a.capsule((0, 0, 0), (0, -0.85, -0.04), 0.17, 0.2, 'crust')
        a.chain([(-0.12, -0.2, -0.17), (0.06, -0.42, -0.19), (-0.04, -0.66, -0.2)], 0.035, 0.035, 'glow')
        a.box((-0.18, -0.5, -0.04), (0.18, -0.46, 0.0), 'glow')
        a.ellipsoid((0, -1.02, -0.06), (0.24, 0.24, 0.24), 'crust_light')                          # fist
        a.ellipsoid((0, -1.04, -0.2), (0.12, 0.1, 0.08), 'glow')
        a.capsule((0.05, -1.2, -0.08), (0.06, -1.36, -0.08), 0.04, 0.015, 'glow_hot')               # a drip
    m.joint('arm_l', 'arm', (-0.68, 2.3, 0), 'arm', 1, throws=False)
    m.joint('arm_r', 'weapon', (0.68, 2.3, 0), 'arm', -1, throws=True)
    m.hand = (0.0, -1.04, -0.3)
    m.extra = dict(hand_limb='arm_r', hover=0, bob=0.0, waddle=0.12)
    return m



# --- The Drowned Spire ----------------------------------------------------------------------

def drowned_acolyte():
    """A priest who walked into the sea to pray: a soaked hooded robe in
    deep green, weed and barnacles hanging from it, a drowned pale face with
    lamp-white eyes, and a hooked crook carrying an angler's lantern."""
    m = Model('drowned_acolyte', 0.075, {
        'robe': (40, 82, 86), 'robe_dark': (22, 48, 56), 'weed': (64, 112, 60), 'barnacle': (196, 196, 180),
        'skin': (168, 190, 186), 'void': (8, 18, 22), 'wood': (78, 62, 50), 'brass': (170, 140, 80),
        'glow': (170, 255, 230), 'glow_lamp': (240, 255, 200),
    }, rough=('robe', 'weed'))
    b = m.part('body')
    robe(b, 1.52, 0.18, 0.21, 0.3, 'robe')
    for i in range(10):                                                  # dripping, ragged hem
        a = i * math.tau / 10 + 0.2
        x, z = math.cos(a) * 0.29, math.sin(a) * 0.29
        b.capsule((x, 0.24, z), (x * 1.05, 0.06 - (i % 3) * 0.05, z * 1.05), 0.05, 0.02, 'robe_dark')
    b.ellipsoid((0, 1.42, 0), (0.24, 0.26, 0.17), 'robe')
    for pts in ([(-0.2, 1.6, -0.12), (-0.24, 1.2, -0.2), (-0.2, 0.8, -0.26)], [(0.18, 1.56, 0.16), (0.24, 1.1, 0.22)],
                [(0.08, 1.22, -0.24), (0.12, 0.88, -0.29), (0.06, 0.58, -0.3)]):
        b.chain(pts, 0.035, 0.02, 'weed')                                # weed hanging off the robe
    for x, y, z in ((-0.24, 1.58, -0.06), (0.26, 1.62, 0.02), (0.2, 1.5, -0.12), (-0.14, 1.66, 0.12)):
        b.ellipsoid((x, y, z), (0.035, 0.03, 0.035), 'barnacle')
    hood(b, (0, 1.82, 0.0), 0.17, 'robe', 'void')
    b.ellipsoid((0, 1.79, -0.1), (0.09, 0.11, 0.07), 'skin')             # the drowned face
    for side in (-1, 1):
        b.ellipsoid((side * 0.04, 1.81, -0.16), (0.022, 0.018, 0.012), 'glow')
    b.box((-0.03, 1.72, -0.17), (0.03, 1.73, -0.15), 'void')
    arm = m.part('arm')
    arm.capsule((0, 0, 0), (0, -0.5, 0), 0.08, 0.11, 'robe')
    arm.ellipsoid((0, -0.58, -0.02), (0.05, 0.06, 0.05), 'skin')
    arm.chain([(0.05, -0.2, -0.1), (0.07, -0.5, -0.12)], 0.025, 0.015, 'weed')
    w = m.part('weapon')
    w.capsule((0, 0, 0), (0, -0.5, 0), 0.08, 0.11, 'robe')
    w.ellipsoid((0, -0.58, -0.02), (0.05, 0.06, 0.05), 'skin')
    # The crook: upright, hooked forward at the top, the lantern hanging from the hook.
    w.capsule((0, -1.22, -0.06), (0, 0.5, -0.06), 0.025, 0.025, 'wood')
    w.chain([(0, 0.5, -0.06), (0, 0.66, -0.14), (0, 0.6, -0.3), (0, 0.48, -0.32)], 0.025, 0.02, 'wood')
    w.capsule((0, 0.46, -0.32), (0, 0.36, -0.32), 0.01, 0.01, 'brass')
    w.ellipsoid((0, 0.28, -0.32), (0.06, 0.08, 0.06), 'glow_lamp')
    ring(w, (0, 0.28, -0.32), 0.065, 0.015, 'brass', n=12)
    m.joint('arm_l', 'arm', (-0.29, 1.54, 0), 'arm', 1, throws=False)
    m.joint('arm_r', 'weapon', (0.29, 1.54, 0), 'arm', -1, throws=True)
    m.hand = (0.0, 0.28, -0.32)
    m.extra = dict(hand_limb='arm_r', hover=0, bob=0.03, waddle=0.12)
    return m


def choir_wraith():
    """One of the drowned choir: a tall singing ghost whose veils trail into
    mist, a hood framing a mouth of light open in song, ribbons of sound,
    and a cracked bell held out in one hand."""
    m = Model('choir_wraith', 0.085, {
        'veil': (120, 140, 196), 'veil_dark': (62, 74, 130), 'void': (14, 16, 34), 'bone': (220, 226, 232),
        'bronze': (150, 128, 90), 'glow': (170, 220, 255), 'glow_song': (230, 250, 255),
    })
    b = m.part('body')
    robe(b, 2.2, 0.6, 0.24, 0.4, 'veil_dark')
    for i in range(9):                                                   # trailing veils into mist
        a = i * math.tau / 9
        x, z = math.cos(a) * 0.34, math.sin(a) * 0.34
        b.chain([(x, 0.7, z), (x * 1.1, 0.42, z * 1.1 + 0.05), (x * 0.8, 0.12 + (i % 2) * 0.12, z * 0.8 + 0.12)],
                0.08, 0.02, 'veil' if i % 2 else 'veil_dark')
    b.ellipsoid((0, 2.06, 0), (0.3, 0.3, 0.22), 'veil')
    b.ellipsoid((0, 2.24, 0.04), (0.42, 0.1, 0.28), 'veil')              # cowl over the shoulders
    hood(b, (0, 2.5, 0.0), 0.2, 'veil', 'void')
    b.ellipsoid((0, 2.44, -0.16), (0.04, 0.07, 0.03), 'glow_song')       # the open, singing mouth
    for side in (-1, 1):
        b.ellipsoid((side * 0.06, 2.58, -0.16), (0.025, 0.012, 0.012), 'glow')
    for i, (x0, y0) in enumerate(((-0.1, 2.44), (0.1, 2.46))):          # ribbons of song
        sx = -1 if i == 0 else 1
        b.chain([(x0, y0, -0.2), (sx * 0.12, 2.36, -0.42), (sx * 0.24, 2.44, -0.6), (sx * 0.2, 2.3, -0.78)], 0.02, 0.012, 'glow')
    arm = m.part('arm')
    arm.capsule((0, 0, 0), (0, -0.62, -0.02), 0.09, 0.13, 'veil')
    arm.chain([(0, -0.66, -0.04), (0.02, -0.8, -0.06)], 0.025, 0.015, 'bone')
    w = m.part('weapon')
    w.capsule((0, 0, 0), (0, -0.62, -0.02), 0.09, 0.13, 'veil')
    w.chain([(0, -0.66, -0.04), (0, -0.74, -0.08)], 0.03, 0.02, 'bone')
    w.capsule((0, -0.78, -0.1), (0, -0.84, -0.1), 0.03, 0.03, 'bronze')  # the bell
    w.ellipsoid((0, -0.96, -0.1), (0.13, 0.13, 0.13), 'bronze')
    w.ellipsoid((0, -1.02, -0.1), (0.1, 0.06, 0.1), 'glow_song')
    m.joint('arm_l', 'arm', (-0.34, 2.12, 0), 'arm', 1, throws=False)
    m.joint('arm_r', 'weapon', (0.34, 2.12, 0), 'arm', -1, throws=True)
    m.hand = (0.0, -1.0, -0.1)
    m.extra = dict(hand_limb='arm_r', hover=0.25, bob=0.05, waddle=0.0)
    return m


def reef_guardian():
    """A knight the reef grew over: shell and coral armor, a conch helm with
    a glowing visor, fins at the shoulders, barnacles in the joints and a
    trident of bleached coral."""
    m = Model('reef_guardian', 0.1, {
        'shell': (150, 196, 182), 'shell_dark': (82, 128, 126), 'conch': (232, 196, 172), 'conch_dark': (176, 120, 108),
        'coral': (236, 110, 84), 'coral_dark': (160, 60, 60),
        'sea': (34, 70, 92), 'barnacle': (206, 206, 192), 'bone': (232, 226, 206), 'void': (12, 22, 30),
        'glow': (120, 255, 230),
    }, rough=('coral',))
    b = m.part('body')
    b.capsule((0, 1.3, 0), (0, 2.1, 0), 0.4, 0.48, 'sea')
    for i, y in enumerate((1.4, 1.62, 1.84, 2.04)):                        # overlapping shell plates
        b.ellipsoid((0, y, -0.14), (0.44 - i * 0.02, 0.14, 0.34), 'shell' if i % 2 else 'shell_dark')
    b.box((-0.44, 1.0, -0.36), (0.44, 1.3, 0.36), 'shell_dark')         # tasset
    for side in (-1, 1):                                                 # shoulders: shell and a fin
        b.ellipsoid((side * 0.52, 2.2, 0), (0.24, 0.2, 0.26), 'conch')
        b.triangle((side * 0.56, 2.3, 0.1), (side * 0.9, 2.62, 0.3), (side * 0.66, 2.2, 0.42), 0.05, 'coral')
        for dz in (-0.1, 0.1):
            b.capsule((side * 0.6, 2.36, dz), (side * 0.72, 2.6, dz - 0.04), 0.04, 0.015, 'coral_dark')
    # Conch helm: a spiral shell around the head, the visor glowing.
    b.ellipsoid((0, 2.55, 0.02), (0.24, 0.26, 0.26), 'conch')
    b.chain([(0, 2.82, 0.14), (0.06, 2.96, 0.06), (0.0, 3.06, -0.04), (-0.05, 3.12, 0.04)], 0.12, 0.03, 'conch_dark')
    b.box((-0.16, 2.5, -0.27), (0.16, 2.58, -0.22), 'void')
    b.box((-0.12, 2.52, -0.28), (0.12, 2.56, -0.25), 'glow')
    for x, y, z in ((-0.3, 1.6, -0.3), (0.32, 1.9, -0.26), (0.2, 1.4, 0.36), (-0.36, 2.0, 0.2)):
        b.ellipsoid((x, y, z), (0.05, 0.04, 0.05), 'barnacle')
    leg = m.part('leg')
    leg.capsule((0, 0, 0), (0, -0.98, 0.04), 0.15, 0.12, 'sea')
    leg.ellipsoid((0, -0.5, -0.08), (0.14, 0.14, 0.1), 'shell')
    leg.ellipsoid((0, -1.02, -0.06), (0.13, 0.07, 0.2), 'shell_dark')
    m.joint('leg_l', 'leg', (-0.2, 1.08, 0), 'leg', 1)
    m.joint('leg_r', 'leg', (0.2, 1.08, 0), 'leg', -1)
    arm = m.part('arm')
    arm.capsule((0, 0, 0), (0, -0.78, -0.04), 0.13, 0.12, 'sea')
    arm.ellipsoid((0, -0.45, -0.06), (0.13, 0.16, 0.13), 'shell')
    arm.ellipsoid((0, -0.88, -0.06), (0.1, 0.1, 0.1), 'shell_dark')
    w = m.part('weapon')
    w.capsule((0, 0, 0), (0, -0.78, -0.04), 0.13, 0.12, 'sea')
    w.ellipsoid((0, -0.45, -0.06), (0.13, 0.16, 0.13), 'shell')
    w.ellipsoid((0, -0.88, -0.06), (0.1, 0.1, 0.1), 'shell_dark')
    # Coral trident, upright at rest.
    w.capsule((0, -1.9, -0.1), (0, 0.6, -0.1), 0.04, 0.04, 'bone')
    for dz, h in ((-0.16, 0.42), (0.0, 0.56), (0.16, 0.42)):
        w.chain([(0, 0.56, -0.1), (0, 0.62, -0.1 + dz), (0, 0.6 + h, -0.1 + dz)], 0.04, 0.012, 'coral')
    w.ellipsoid((0, 0.62, -0.1), (0.06, 0.06, 0.06), 'glow')
    m.joint('arm_l', 'arm', (-0.6, 2.06, 0), 'arm', 1, throws=False)
    m.joint('arm_r', 'weapon', (0.6, 2.06, 0), 'arm', -1, throws=True)
    m.hand = (0.0, 1.1, -0.1)
    m.extra = dict(hand_limb='arm_r', hover=0, bob=0.0, waddle=0.08)
    return m


# --- Boss attendants ----------------------------------------------------------------------

def dawn_scarab():
    """The Scarab Regent's sunrise beetle: a polished gold-and-copper shell
    with a sun disc rising over it, a horn like a sickle and six quick legs."""
    m = Model('dawn_scarab', 0.06, {
        'shell': (222, 160, 60), 'shell_dark': (150, 88, 40), 'copper': (174, 92, 50), 'black': (40, 30, 30),
        'lapis': (42, 88, 160), 'glow': (255, 214, 110), 'glow_sun': (255, 240, 190),
    })
    b = m.part('body')
    b.ellipsoid((0, 0.5, 0.12), (0.46, 0.3, 0.56), 'shell')
    b.box((-0.015, 0.5, -0.3), (0.015, 0.82, 0.68), 'shell_dark')       # the wing-case seam
    for side in (-1, 1):
        b.chain([(side * 0.18, 0.76, -0.24), (side * 0.36, 0.66, 0.2), (side * 0.3, 0.52, 0.6)], 0.02, 0.02, 'copper')
    b.ellipsoid((0, 0.42, -0.42), (0.3, 0.18, 0.18), 'black')            # pronotum
    b.ellipsoid((0, 0.36, -0.6), (0.2, 0.12, 0.12), 'black')             # head
    b.chain([(0, 0.42, -0.68), (0, 0.62, -0.82), (0, 0.78, -0.76)], 0.06, 0.02, 'copper')   # sickle horn
    for side in (-1, 1):
        b.ellipsoid((side * 0.13, 0.4, -0.7), (0.035, 0.03, 0.025), 'glow')
    # The sun disc rising over the shell, ringed in lapis.
    b.ellipsoid((0, 0.98, 0.24), (0.18, 0.18, 0.05), 'glow_sun')
    ring(b, (0, 0.98, 0.24), 0.21, 0.03, 'shell_dark', axis='z', n=24)
    for i in range(5):                                                   # short rays, upper half only
        a = math.pi * (0.1 + 0.2 * i)
        b.capsule((math.cos(a) * 0.23, 0.98 + math.sin(a) * 0.23, 0.26), (math.cos(a) * 0.3, 0.98 + math.sin(a) * 0.3, 0.26),
                  0.02, 0.01, 'shell')
    for side, name in ((-1, 'leg_l'), (1, 'leg_r')):
        leg = m.part(name)
        leg.chain([(0, 0, 0), (side * 0.22, 0.08, 0), (side * 0.32, -0.36, -0.04)], 0.035, 0.02, 'black')
        for i, z in enumerate((-0.3, 0.05, 0.4)):
            m.joint(f'{name}_{i}', name, (side * 0.3, 0.38, z), 'leg', (1 if i % 2 == 0 else -1) * side)
    m.hand = (0.0, 0.98, 0.18)
    m.extra = dict(hover=0, bob=0.07, waddle=0.0)
    return m


def cinder_sentinel():
    """Vharok's furnace guard: an iron statue on short legs whose chest is a
    roaring furnace door, two horns of flame on its helm, rivets and soot."""
    m = Model('cinder_sentinel', 0.09, {
        'iron': (104, 92, 88), 'iron_dark': (56, 48, 50), 'rivet': (176, 160, 140), 'soot': (34, 28, 30),
        'brass': (170, 120, 60), 'glow': (255, 110, 30), 'glow_hot': (255, 220, 120),
    }, rough=('iron', 'soot'))
    b = m.part('body')
    b.box((-0.36, 0.0, -0.3), (-0.12, 0.7, 0.24), 'iron_dark')           # stubby legs
    b.box((0.12, 0.0, -0.3), (0.36, 0.7, 0.24), 'iron_dark')
    b.box((-0.4, 0.0, -0.38), (-0.08, 0.12, 0.26), 'soot')
    b.box((0.08, 0.0, -0.38), (0.4, 0.12, 0.26), 'soot')
    b.capsule((0, 0.9, 0), (0, 2.1, 0), 0.56, 0.62, 'iron')              # the furnace body
    ring(b, (0, 1.1, 0), 0.6, 0.05, 'iron_dark')
    ring(b, (0, 1.95, 0), 0.62, 0.05, 'iron_dark')
    b.box((-0.38, 1.1, -0.68), (0.38, 1.9, -0.56), 'iron_dark')          # furnace door
    b.box((-0.32, 1.16, -0.71), (0.32, 1.84, -0.6), 'glow')
    b.box((-0.24, 1.2, -0.72), (0.24, 1.5, -0.62), 'glow_hot')
    for x in (-0.14, 0.14):                                              # two bars: the fire shows between
        b.box((x - 0.03, 1.16, -0.74), (x + 0.03, 1.84, -0.71), 'iron_dark')
    for side in (-1, 1):                                                 # vents leaking fire at the flanks
        b.box((side * 0.6 - 0.03, 1.4, -0.2), (side * 0.6 + 0.03, 1.7, 0.2), 'glow')
    for y in (1.0, 2.05):
        for i in range(10):
            a = i * math.tau / 10
            b.ellipsoid((math.cos(a) * 0.62, y, math.sin(a) * 0.62), (0.03, 0.03, 0.03), 'rivet')
    for side in (-1, 1):                                                 # pauldrons
        b.ellipsoid((side * 0.66, 2.0, 0), (0.24, 0.22, 0.28), 'iron_dark')
        b.capsule((side * 0.66, 1.9, 0), (side * 0.72, 1.3, -0.08), 0.13, 0.15, 'iron')
        b.ellipsoid((side * 0.72, 1.22, -0.1), (0.15, 0.15, 0.15), 'iron_dark')
    b.ellipsoid((0, 2.4, 0), (0.3, 0.26, 0.28), 'iron')                  # helm
    b.box((-0.2, 2.36, -0.3), (0.2, 2.42, -0.24), 'glow_hot')
    ring(b, (0, 2.24, 0), 0.32, 0.04, 'brass')
    for side in (-1, 1):                                                 # horns of flame
        b.chain([(side * 0.22, 2.56, 0), (side * 0.38, 2.78, 0.04), (side * 0.36, 3.04, 0.1)], 0.07, 0.02, 'iron_dark')
        b.capsule((side * 0.36, 2.98, 0.1), (side * 0.32, 3.2, 0.14), 0.06, 0.01, 'glow')
    m.hand = (0.0, 1.5, -0.7)
    m.extra = dict(hover=0, bob=0.0, waddle=0.0)
    return m


def mirror_shade():
    """A shade of the Deep Dark bound into an old mirror: a tall drifting
    shadow in tattered black, its chest an oval looking-glass framed in
    tarnished silver where a violet eye stares out, a crown of glass shards
    and long thin claws."""
    m = Model('mirror_shade', 0.1, {
        'shadow': (34, 26, 48), 'shadow_dark': (18, 14, 28), 'silver': (150, 150, 168), 'silver_dark': (90, 88, 108),
        'glass': (120, 96, 170), 'void': (6, 4, 12), 'glow': (200, 120, 255), 'glow_eye': (255, 220, 255),
    })
    b = m.part('body')
    robe(b, 3.2, 1.0, 0.36, 0.5, 'shadow')
    for i in range(10):                                                  # tatters trailing off into nothing
        a = i * math.tau / 10
        x, z = math.cos(a) * 0.48, math.sin(a) * 0.48
        b.chain([(x, 1.05, z), (x * 1.1, 0.7, z * 1.1), (x * 0.7, 0.3 + (i % 3) * 0.12, z * 0.7)], 0.1, 0.03,
                'shadow_dark' if i % 2 else 'shadow')
    b.ellipsoid((0, 3.0, 0), (0.48, 0.4, 0.32), 'shadow')
    # The mirror set in the chest: silver frame, violet glass, the eye.
    b.ellipsoid((0, 2.5, -0.34), (0.36, 0.52, 0.06), 'glass')
    ring(b, (0, 2.5, -0.36), 0.42, 0.05, 'silver', axis='z', n=36)
    for y in (2.96, 2.04):
        b.ellipsoid((0, y, -0.38), (0.08, 0.06, 0.04), 'silver_dark')
    b.ellipsoid((0, 2.5, -0.4), (0.14, 0.09, 0.04), 'glow')
    b.ellipsoid((0, 2.5, -0.42), (0.05, 0.06, 0.03), 'void')
    b.chain([(0.1, 2.85, -0.4), (0.0, 2.62, -0.41), (0.16, 2.3, -0.4)], 0.012, 0.012, 'silver')   # a crack
    hood(b, (0, 3.4, 0.02), 0.26, 'shadow', 'void', eyes='glow', eye_gap=0.08)
    for i, (x, h) in enumerate(((-0.24, 0.3), (-0.1, 0.44), (0.06, 0.5), (0.2, 0.36))):    # crown of shards
        b.triangle((x - 0.05, 3.62, 0.0), (x + 0.05, 3.62, 0.04), (x + 0.02, 3.62 + h, 0.06), 0.06, 'glass' if i % 2 else 'silver')
    for side in (-1, 1):                                                 # long arms and claws
        b.chain([(side * 0.44, 3.0, 0), (side * 0.66, 2.4, -0.1), (side * 0.7, 1.8, -0.26)], 0.11, 0.07, 'shadow')
        for dx in (-0.06, 0.0, 0.06):
            b.capsule((side * 0.7, 1.76, -0.26), (side * 0.74 + dx, 1.36, -0.4), 0.025, 0.008, 'silver_dark')
    m.hand = (0.0, 2.5, -0.44)
    m.extra = dict(hover=0.4, bob=0.07, waddle=0.0)
    return m


def rimeheart_shardling():
    """A splinter of the Rimeheart Prism: a cluster of ice crystals grown
    around a beating blue heart, small shards orbiting it."""
    m = Model('rimeheart_shardling', 0.06, {
        'ice': (150, 206, 236), 'ice_dark': (78, 134, 186), 'frost': (226, 244, 252), 'glow': (110, 210, 255),
        'glow_heart': (220, 250, 255),
    })
    b = m.part('body')
    b.ellipsoid((0, 0.85, 0), (0.16, 0.18, 0.16), 'glow_heart')
    spikes = [((0, 1.0, 0), (0, 1.62, 0.04), 0.14), ((0.1, 0.95, -0.06), (0.42, 1.36, -0.16), 0.11),
              ((-0.1, 0.95, -0.04), (-0.4, 1.4, -0.1), 0.11), ((0.08, 0.8, 0.1), (0.36, 0.6, 0.36), 0.1),
              ((-0.08, 0.8, 0.1), (-0.3, 0.5, 0.32), 0.1), ((0, 0.75, -0.1), (0.04, 0.36, -0.36), 0.12),
              ((0.06, 0.9, 0.12), (0.12, 1.2, 0.46), 0.09)]
    for i, (a, tip, r) in enumerate(spikes):
        b.capsule(a, tip, r, 0.02, 'ice' if i % 2 else 'ice_dark')
        b.ellipsoid(tip, (0.03, 0.03, 0.03), 'frost')
    for x, y, z in ((0.55, 0.95, 0.1), (-0.52, 0.8, -0.2), (0.1, 0.2, 0.5)):        # orbiting shards
        b.capsule((x, y - 0.1, z), (x + 0.04, y + 0.12, z), 0.05, 0.01, 'ice')
    m.hand = (0.0, 0.85, -0.2)
    m.extra = dict(hover=0.2, bob=0.07, waddle=0.0)
    return m



# --- Planets of the Reach -------------------------------------------------------------------

def bark_warden():
    """Verdance's old tree warden: a trunk of ridged bark with a face grown
    into it, amber eyes, branch antlers in leaf and blossom, moss on the
    shoulders and arms like long roots."""
    m = Model('bark_warden', 0.075, {
        'bark': (106, 78, 52), 'bark_dark': (66, 48, 34), 'moss': (88, 140, 62), 'leaf': (118, 176, 72),
        'blossom': (236, 170, 196), 'void': (26, 18, 14), 'glow': (255, 196, 100),
    }, rough=('bark', 'moss'))
    b = m.part('body')
    b.capsule((0, 0.62, 0), (0, 1.48, 0), 0.3, 0.34, 'bark')
    for x in (-0.2, -0.06, 0.08, 0.22):                                  # bark ridges
        b.capsule((x, 0.66, -0.28 + abs(x) * 0.25), (x * 0.9, 1.46, -0.3 + abs(x) * 0.25), 0.03, 0.03, 'bark_dark')
    for side in (-1, 1):
        b.ellipsoid((side * 0.32, 1.48, 0.0), (0.2, 0.14, 0.22), 'moss')
    b.ellipsoid((0, 1.52, 0.04), (0.3, 0.12, 0.26), 'moss')
    head = m.part('head')
    head.ellipsoid((0, 0.16, 0), (0.22, 0.22, 0.2), 'bark')
    head.box((-0.14, 0.18, -0.21), (0.14, 0.22, -0.18), 'bark_dark')      # heavy brow
    for side in (-1, 1):
        head.ellipsoid((side * 0.08, 0.13, -0.18), (0.035, 0.03, 0.02), 'glow')
    head.box((-0.06, 0.0, -0.2), (0.06, 0.03, -0.17), 'void')             # knot of a mouth
    for side in (-1, 1):                                                  # branch antlers
        tip = (side * 0.46, 0.78, 0.08)
        head.chain([(side * 0.1, 0.32, 0.02), (side * 0.22, 0.52, 0.04), tip], 0.05, 0.02, 'bark_dark')
        head.chain([(side * 0.22, 0.52, 0.04), (side * 0.38, 0.5, -0.06)], 0.03, 0.015, 'bark_dark')
        for c in (tip, (side * 0.38, 0.5, -0.06), (side * 0.3, 0.7, 0.12)):
            head.ellipsoid(c, (0.1, 0.08, 0.1), 'leaf')
        head.ellipsoid((side * 0.34, 0.72, 0.0), (0.04, 0.04, 0.04), 'blossom')
    m.joint('head', 'head', (0, 1.6, -0.02), 'head', 1)
    for side, name in ((-1, 'arm_l'), (1, 'arm_r')):
        a = m.part(name)
        a.chain([(0, 0, 0), (side * 0.06, -0.42, -0.04), (side * 0.04, -0.82, -0.08)], 0.11, 0.07, 'bark')
        for dx in (-0.05, 0.0, 0.05):                                     # root fingers
            a.capsule((side * 0.04, -0.82, -0.08), (side * 0.04 + dx, -1.0, -0.14), 0.03, 0.012, 'bark_dark')
        a.ellipsoid((side * 0.03, -0.3, -0.06), (0.08, 0.06, 0.06), 'moss')
        m.joint(name, name, (side * 0.4, 1.42, 0), 'arm', 1 if side < 0 else -1)
    for side, name in ((-1, 'leg_l'), (1, 'leg_r')):
        l = m.part(name)
        l.capsule((0, 0, 0), (0, -0.52, 0), 0.14, 0.16, 'bark')
        for dz, dx in ((-0.16, 0.0), (0.02, side * 0.14), (0.12, -side * 0.08)):    # spreading roots
            l.capsule((0, -0.5, 0), (dx, -0.6, dz), 0.06, 0.03, 'bark_dark')
        m.joint(name, name, (side * 0.18, 0.6, 0), 'leg', 1 if side < 0 else -1)
    m.hand = (0.0, 1.2, -0.4)
    m.extra = dict(hover=0, bob=0.015, waddle=0.04)
    return m


def grave_watcher():
    """Hollowmoon's gravekeeper: a gaunt figure in a long torn shroud with a
    deep hood, a skull's grin inside it, chains at its waist and a lantern
    of green grave-fire held out to find you."""
    m = Model('grave_watcher', 0.08, {
        'shroud': (62, 64, 76), 'shroud_dark': (34, 34, 44), 'scarf': (164, 158, 140), 'void': (8, 10, 12),
        'bone': (214, 210, 190), 'iron': (70, 72, 78), 'wood': (86, 70, 56),
        'glow': (125, 255, 106), 'glow_hot': (220, 255, 200),
    }, rough=('shroud',))
    b = m.part('body')
    robe(b, 1.7, 0.2, 0.2, 0.32, 'shroud')
    for i in range(10):                                                    # torn hem
        a = i * math.tau / 10
        x, z = math.cos(a) * 0.31, math.sin(a) * 0.31
        b.capsule((x, 0.26, z), (x * 1.05, 0.04 + (i % 3) * 0.06, z * 1.05), 0.06, 0.02, 'shroud_dark')
    b.ellipsoid((0, 1.62, 0.02), (0.26, 0.2, 0.18), 'shroud')
    ring(b, (0, 1.12, 0), 0.24, 0.03, 'iron')
    # A pale burial scarf wound round the shoulders, its ends hanging down.
    ring(b, (0, 1.72, 0.0), 0.2, 0.06, 'scarf', n=24)
    b.chain([(-0.12, 1.7, -0.18), (-0.16, 1.4, -0.22), (-0.13, 1.12, -0.24)], 0.05, 0.03, 'scarf')
    b.chain([(0.1, 1.7, 0.18), (0.18, 1.3, 0.24), (0.14, 0.9, 0.26)], 0.05, 0.03, 'scarf')
    b.chain([(0.1, 1.1, -0.22), (0.16, 0.86, -0.26), (0.12, 0.6, -0.28)], 0.02, 0.02, 'iron')
    b.ellipsoid((0.12, 0.56, -0.29), (0.05, 0.04, 0.03), 'iron')             # a key on the chain
    head = m.part('head')
    hood(head, (0, 0.2, 0), 0.19, 'shroud', 'void', point=0.2)
    head.ellipsoid((0, 0.17, -0.09), (0.1, 0.12, 0.08), 'bone')             # skull
    for side in (-1, 1):
        head.ellipsoid((side * 0.045, 0.2, -0.16), (0.03, 0.025, 0.02), 'void')
        head.ellipsoid((side * 0.045, 0.2, -0.18), (0.012, 0.012, 0.01), 'glow')
    head.box((-0.05, 0.06, -0.17), (0.05, 0.08, -0.15), 'void')
    m.joint('head', 'head', (0, 1.84, 0), 'head', 1)
    for side, name in ((-1, 'arm_l'), (1, 'arm_r')):
        a = m.part(name)
        a.capsule((0, 0, 0), (0, -0.62, -0.04), 0.075, 0.1, 'shroud')
        a.chain([(0, -0.66, -0.05), (0, -0.78, -0.08)], 0.03, 0.02, 'bone')
        if side > 0:                                  # a tall lantern pole, the grave-fire hung forward
            a.capsule((0.04, -1.6, -0.1), (0.04, 0.8, -0.1), 0.03, 0.03, 'wood')
            a.chain([(0.04, 0.8, -0.1), (0.04, 0.92, -0.32), (0.04, 0.84, -0.56)], 0.025, 0.02, 'iron')
            a.capsule((0.04, 0.82, -0.56), (0.04, 0.72, -0.56), 0.012, 0.012, 'iron')
            a.ellipsoid((0.04, 0.6, -0.56), (0.09, 0.12, 0.09), 'glow')
            a.ellipsoid((0.04, 0.6, -0.56), (0.045, 0.06, 0.045), 'glow_hot')
            ring(a, (0.04, 0.71, -0.56), 0.09, 0.02, 'iron', n=12)
            ring(a, (0.04, 0.48, -0.56), 0.09, 0.02, 'iron', n=12)
        m.joint(name, name, (side * 0.3, 1.64, 0), 'arm', 1 if side < 0 else -1)
    for side, name in ((-1, 'leg_l'), (1, 'leg_r')):
        l = m.part(name)
        l.capsule((0, -0.4, 0), (0, -0.7, 0), 0.06, 0.06, 'shroud_dark')
        m.joint(name, name, (side * 0.12, 0.74, 0), 'leg', 1 if side < 0 else -1)
    m.hand = (0.04, 0.6, -0.56)
    m.extra = dict(hand_limb='arm_r', hover=0, bob=0.008, waddle=0.025)
    return m


def fungal_brute():
    """Mawgrave's fungus hulk: a stooped body of pale fibrous flesh, a broad
    spotted cap for a head, shelf fungi on the shoulders, glowing spore sacs
    swelling on its back and heavy club hands."""
    m = Model('fungal_brute', 0.085, {
        'flesh': (204, 186, 168), 'flesh_dark': (150, 126, 116), 'cap': (150, 52, 110), 'cap_dark': (96, 34, 76),
        'spot': (240, 214, 230), 'gill': (112, 80, 92), 'shelf': (180, 136, 92), 'void': (30, 14, 26),
        'glow': (255, 106, 224), 'glow_hot': (255, 200, 245),
    }, rough=('flesh', 'shelf'))
    b = m.part('body')
    b.ellipsoid((0, 1.5, 0.08), (0.62, 0.58, 0.5), 'flesh')                  # stooped mass
    b.ellipsoid((0, 1.0, 0.0), (0.44, 0.36, 0.38), 'flesh_dark')
    for x in (-0.3, -0.1, 0.12, 0.32):                                       # fibrous striations
        b.capsule((x, 1.0, -0.38 + abs(x) * 0.2), (x * 1.2, 1.9, -0.36 + abs(x) * 0.25), 0.025, 0.025, 'flesh_dark')
    for x, y, z, r in ((-0.3, 1.86, 0.42, 0.18), (0.22, 1.7, 0.5, 0.2), (0.0, 1.4, 0.54, 0.16), (0.4, 1.98, 0.3, 0.13)):
        b.ellipsoid((x, y, z), (r, r, r * 0.9), 'glow')                       # spore sacs
        b.ellipsoid((x, y + r * 0.3, z + r * 0.4), (r * 0.4, r * 0.4, r * 0.3), 'glow_hot')
    for side in (-1, 1):                                                     # shelf fungi pauldrons
        for i, y in enumerate((1.86, 1.74)):
            b.ellipsoid((side * (0.58 + i * 0.06), y, 0.0), (0.28 - i * 0.06, 0.06, 0.26 - i * 0.04), 'shelf')
    head = m.part('head')
    head.capsule((0, -0.12, 0), (0, 0.14, 0), 0.16, 0.16, 'flesh')
    head.ellipsoid((0, 0.24, 0), (0.46, 0.2, 0.42), 'cap')                    # the cap
    head.ellipsoid((0, 0.14, 0), (0.42, 0.06, 0.38), 'gill')
    for x, z in ((-0.22, -0.18), (0.18, -0.24), (0.0, 0.06), (-0.24, 0.2), (0.26, 0.12), (0.06, -0.32)):
        head.ellipsoid((x, 0.4, z), (0.06, 0.03, 0.06), 'spot')
    for side in (-1, 1):
        head.ellipsoid((side * 0.07, 0.02, -0.15), (0.03, 0.025, 0.02), 'glow')
    head.box((-0.07, -0.08, -0.16), (0.07, -0.06, -0.14), 'void')
    m.joint('head', 'head', (0, 2.2, -0.2), 'head', 1)
    for side, name in ((-1, 'arm_l'), (1, 'arm_r')):
        a = m.part(name)
        a.capsule((0, 0, 0), (side * 0.04, -0.72, -0.06), 0.16, 0.14, 'flesh')
        a.ellipsoid((side * 0.05, -0.9, -0.08), (0.22, 0.2, 0.22), 'flesh_dark')   # club hand
        a.ellipsoid((side * 0.05, -0.98, -0.18), (0.08, 0.06, 0.06), 'glow')
        m.joint(name, name, (side * 0.72, 1.86, 0), 'arm', 1 if side < 0 else -1)
    for side, name in ((-1, 'leg_l'), (1, 'leg_r')):
        l = m.part(name)
        l.capsule((0, 0, 0), (0, -0.52, 0.02), 0.17, 0.15, 'flesh_dark')
        l.ellipsoid((0, -0.56, -0.06), (0.17, 0.07, 0.22), 'flesh')
        m.joint(name, name, (side * 0.26, 0.6, 0), 'leg', 1 if side < 0 else -1)
    m.hand = (0.0, 1.5, -0.7)
    m.extra = dict(hover=0, bob=0.012, waddle=0.035)
    return m


def hive_mother():
    """The Hive Mother of Mawgrave: an insect queen grown huge, her chitin
    thorax standing tall over a swollen, glowing egg sac, six barbed arms,
    a crowned head with feelers and mandibles that open to scream."""
    m = Model('hive_mother', 0.12, {
        'chitin': (70, 40, 74), 'chitin_dark': (40, 22, 46), 'plate': (120, 70, 118), 'sac': (196, 120, 170),
        'vein': (120, 54, 104), 'void': (18, 8, 18), 'claw': (226, 196, 214),
        'glow': (255, 106, 224), 'glow_hot': (255, 214, 245),
    }, rough=('sac',))
    b = m.part('body')
    b.ellipsoid((0, 1.4, 1.2), (1.1, 0.95, 1.3), 'sac')                       # the egg sac behind
    for i in range(7):                                                       # veins and glowing eggs
        a = i * math.tau / 7
        b.chain([(math.cos(a) * 0.3, 2.2, 0.8), (math.cos(a) * 1.0, 1.5 + math.sin(a) * 0.4, 1.3),
                 (math.cos(a) * 0.7, 0.6, 1.6)], 0.04, 0.04, 'vein')
    for x, y, z in ((-0.6, 1.7, 1.9), (0.5, 1.2, 2.1), (0.0, 2.0, 1.8), (-0.3, 1.0, 2.2), (0.7, 1.9, 1.5)):
        b.ellipsoid((x, y, z), (0.16, 0.2, 0.16), 'glow')
    b.capsule((0, 1.3, 0.1), (0, 3.0, -0.2), 0.62, 0.48, 'chitin')            # thorax standing up
    for i, y in enumerate((1.6, 2.0, 2.4, 2.8)):                              # armor bands
        b.ellipsoid((0, y, -0.2 - i * 0.05), (0.56 - i * 0.04, 0.12, 0.42), 'plate')
    for side in (-1, 1):                                                     # short legs it stands on
        for dz in (-0.3, 0.4, 1.1):
            b.chain([(side * 0.5, 1.2, dz), (side * 1.0, 0.8, dz - 0.1), (side * 1.1, 0.0, dz - 0.2)], 0.1, 0.05, 'chitin_dark')
    head = m.part('head')
    head.ellipsoid((0, 0.2, -0.1), (0.4, 0.36, 0.42), 'chitin')
    for side in (-1, 1):
        head.ellipsoid((side * 0.22, 0.28, -0.44), (0.12, 0.1, 0.06), 'glow')     # compound eyes
        head.capsule((side * 0.12, 0.5, -0.2), (side * 0.5, 1.2, -0.5), 0.04, 0.015, 'chitin_dark')  # feelers
    for i, x in enumerate((-0.24, -0.08, 0.08, 0.24)):                         # crown
        head.capsule((x, 0.46, 0.0), (x * 1.3, 0.78 + (0.1 if i in (1, 2) else 0), 0.08), 0.06, 0.015, 'plate')
    jaw = m.part('jaw')
    for side in (-1, 1):
        jaw.chain([(side * 0.18, 0, -0.1), (side * 0.3, -0.12, -0.4), (side * 0.08, -0.2, -0.62)], 0.08, 0.025, 'claw')
    jaw.ellipsoid((0, -0.04, -0.3), (0.12, 0.08, 0.1), 'glow_hot')
    m.joint('head', 'head', (0, 3.3, -0.3), 'head', 1)
    m.joint('jaw', 'jaw', (0, -0.1, -0.3), 'jaw', 1, parent_limb='head')
    for side in (-1, 1):
        for i in range(3):
            name = f'arm_{"l" if side < 0 else "r"}_{i}'
            a = m.part(name)
            a.chain([(0, 0, 0), (side * 0.5, -0.3 - i * 0.05, -0.3), (side * 0.6, -0.9 + i * 0.1, -0.6)], 0.11 - i * 0.02, 0.06, 'chitin')
            a.capsule((side * 0.6, -0.9 + i * 0.1, -0.6), (side * 0.5, -1.25 + i * 0.1, -0.95), 0.06, 0.012, 'claw')
            m.joint(name, name, (side * 0.6, 2.9 - i * 0.48, -0.3), 'arm', 1 if side < 0 else -1)
    m.hand = (0.0, 3.0, -0.9)
    m.extra = dict(hover=0, bob=0.012, waddle=0.035)
    return m



# --- The Hollow Castle ----------------------------------------------------------------------

def _castle_knight(name, champion):
    """The Hollow King's knights: empty plate that still stands guard, the
    curse leaking from the visor and the joints as pale light. A faded royal
    tabard with the broken crown, a torn cape; the knight carries sword and
    kite shield, the champion a greatsword, a crowned helm and spiked plate.
    The skeleton (hips, knees, shoulders) is the castle rig's own."""
    pal = {
        'steel': (150, 152, 166), 'steel_dark': (82, 84, 98), 'gold': (196, 160, 84), 'tabard': (84, 54, 108),
        'tabard_dark': (52, 32, 72), 'cape': (60, 44, 84), 'leather': (78, 58, 48), 'void': (10, 8, 16),
        'blade': (206, 210, 222), 'glow': (210, 190, 255), 'glow_core': (246, 240, 255),
    }
    if champion:
        pal.update(steel=(112, 106, 112), steel_dark=(52, 48, 56), gold=(214, 170, 76), tabard=(120, 30, 40),
                   tabard_dark=(74, 18, 28), cape=(96, 22, 32))
    m = Model(name, 0.2, pal, rough=('cape',))
    b = m.part('body')
    b.capsule((0, 3.5, 0), (0, 5.9, 0), 0.95, 1.12, 'steel_dark')
    b.ellipsoid((0, 5.35, -0.22), (1.06, 0.95, 0.78), 'steel')                       # breastplate
    for y in (3.45, 3.0, 2.6):                                                        # faulds
        ring(b, (0, y, 0), 1.0 - (3.45 - y) * 0.1, 0.18, 'steel', n=28)
    b.box((-0.55, 2.3, -1.02), (0.55, 5.0, -0.86), 'tabard')                        # tabard front
    b.box((-0.55, 2.3, -1.04), (-0.4, 5.0, -0.86), 'tabard_dark')
    b.box((0.4, 2.3, -1.04), (0.55, 5.0, -0.86), 'tabard_dark')
    # The broken crown: three points, the right one snapped.
    b.box((-0.32, 4.2, -1.08), (0.32, 4.34, -1.0), 'gold')
    for x, h in ((-0.26, 0.36), (0.0, 0.46), (0.26, 0.18)):
        b.box((x - 0.06, 4.34, -1.08), (x + 0.06, 4.34 + h, -1.0), 'gold')
    ring(b, (0, 3.6, 0), 1.0, 0.1, 'leather', n=28)                                  # sword belt
    for side in (-1, 1):                                                             # pauldrons
        b.ellipsoid((side * 1.36, 5.95, 0.0), (0.66, 0.5, 0.72), 'steel')
        ring(b, (side * 1.36, 5.72, 0.0), 0.66, 0.08, 'gold', n=24)
        if champion:
            for dz in (-0.3, 0.0, 0.3):
                b.capsule((side * 1.5, 6.3, dz), (side * 1.8, 6.95, dz * 1.2), 0.14, 0.02, 'steel_dark')
    b.ellipsoid((0, 6.25, 0), (0.62, 0.3, 0.55), 'steel_dark')                       # gorget
    # Great helm with a T visor, the curse glowing inside it.
    b.capsule((0, 6.5, 0.05), (0, 7.5, 0.05), 0.56, 0.52, 'steel')
    b.box((-0.4, 7.0, -0.56), (0.4, 7.12, -0.46), 'void')
    b.box((-0.07, 6.62, -0.56), (0.07, 7.12, -0.46), 'void')
    b.box((-0.32, 7.03, -0.58), (0.32, 7.09, -0.52), 'glow')
    b.box((-0.035, 6.7, -0.58), (0.035, 7.03, -0.52), 'glow')
    if champion:                                                                      # crowned helm
        ring(b, (0, 7.85, 0.05), 0.5, 0.08, 'gold', n=24)
        for i in range(6):
            a = i * math.tau / 6
            b.capsule((math.cos(a) * 0.5, 7.9, 0.05 + math.sin(a) * 0.5), (math.cos(a) * 0.56, 8.35, 0.05 + math.sin(a) * 0.56),
                      0.08, 0.02, 'gold')
    else:                                                                             # crest
        b.chain([(0, 8.0, -0.3), (0, 8.35, 0.1), (0, 8.1, 0.6), (0, 7.6, 0.9)], 0.16, 0.06, 'tabard')
    # Cape from the shoulders, torn at the hem.
    b.capsule((0, 6.0, 0.95), (0, 2.7, 1.25), 0.9, 1.15, 'cape')
    for i, x in enumerate((-0.9, -0.45, 0.0, 0.45, 0.9)):
        b.capsule((x, 2.9, 1.3), (x * 1.05, 2.2 - (i % 2) * 0.4, 1.4), 0.24, 0.08, 'cape')
    for x, y, z in ((0.0, 4.6, -0.9), (-0.9, 3.9, -0.5), (0.9, 3.9, -0.5)):          # light at the seams
        b.ellipsoid((x, y, z), (0.08, 0.08, 0.05), 'glow')
    leg = m.part('leg')
    leg.capsule((0, 0, 0), (0, -1.4, 0), 0.44, 0.38, 'steel_dark')
    leg.ellipsoid((0, -0.7, -0.3), (0.38, 0.5, 0.2), 'steel')
    knee = m.part('knee')
    knee.ellipsoid((0, 0, -0.26), (0.32, 0.3, 0.22), 'steel')                          # knee cop
    knee.ellipsoid((0, 0, -0.36), (0.08, 0.08, 0.05), 'glow')
    knee.capsule((0, 0, 0), (0, -1.5, 0), 0.38, 0.32, 'steel')
    knee.ellipsoid((0, -1.66, -0.28), (0.4, 0.22, 0.62), 'steel_dark')                 # sabaton
    m.joint('leg_l', 'leg', (-0.56, 3.36, 0), 'leg', 1)
    m.joint('knee_l', 'knee', (0, -1.4, 0), 'knee', 1, parent_limb='leg_l')
    m.joint('leg_r', 'leg', (0.56, 3.36, 0), 'leg', -1)
    m.joint('knee_r', 'knee', (0, -1.4, 0), 'knee', -1, parent_limb='leg_r')
    arm_l = m.part('arm_l')
    arm_l.capsule((0, 0, 0), (0, -2.2, -0.1), 0.42, 0.36, 'steel_dark')
    arm_l.ellipsoid((0, -1.2, -0.05), (0.42, 0.3, 0.42), 'steel')                      # couter
    arm_l.ellipsoid((0, -2.4, -0.18), (0.36, 0.34, 0.38), 'steel')                     # gauntlet
    if not champion:                                                                  # kite shield
        arm_l.triangle((-0.5, -0.6, -0.6), (-0.5, -0.6, 0.6), (-0.5, -3.4, -0.1), 0.18, 'tabard')
        arm_l.ellipsoid((-0.5, -0.9, 0.0), (0.12, 0.62, 0.62), 'tabard')
        arm_l.chain([(-0.6, -0.4, -0.6), (-0.6, -0.4, 0.6), (-0.6, -3.3, -0.1), (-0.6, -0.4, -0.6)], 0.08, 0.08, 'gold')
        arm_l.box((-0.66, -1.6, -0.08), (-0.6, -0.9, 0.08), 'gold')
        arm_l.box((-0.66, -1.32, -0.3), (-0.6, -1.18, 0.3), 'gold')
    arm_r = m.part('arm_r')
    arm_r.capsule((0, 0, 0), (0, -2.2, -0.1), 0.42, 0.36, 'steel_dark')
    arm_r.ellipsoid((0, -1.2, -0.05), (0.42, 0.3, 0.42), 'steel')
    arm_r.ellipsoid((0, -2.4, -0.18), (0.36, 0.34, 0.38), 'steel')
    # The sword hangs from the fist, point down and a little ahead.
    length = 4.6 if champion else 3.6
    arm_r.capsule((0, -2.0, -0.26), (0, -2.8, -0.36), 0.1, 0.1, 'leather')            # grip
    arm_r.ellipsoid((0, -1.9, -0.24), (0.16, 0.16, 0.16), 'gold')                      # pommel
    arm_r.box((-0.55, -2.86, -0.48), (0.55, -2.74, -0.28), 'gold')                     # crossguard
    tip = (0, -2.8 - length, -0.36 - length * 0.22)
    arm_r.capsule((0, -2.86, -0.38), tip, 0.2 if champion else 0.16, 0.04, 'blade')
    arm_r.capsule((0, -3.0, -0.42), (0, -2.8 - length * 0.8, -0.36 - length * 0.18), 0.05, 0.03, 'glow')  # fuller
    m.joint('arm_l', 'arm_l', (-1.68, 5.88, 0), 'arm', 1)
    m.joint('arm_r', 'arm_r', (1.68, 5.88, 0), 'arm', -1)
    m.hand = (0, -2.8 - length * 0.6, -0.36 - length * 0.13)
    m.extra = dict(hand_limb='arm_r', hover=0, bob=0, waddle=0)
    return m


def castle_knight():
    return _castle_knight('castle_knight', False)


def castle_champion():
    return _castle_knight('castle_champion', True)


# --- Amberfall ---------------------------------------------------------------------------

def amber_colossus():
    """Aurum, the Amber Colossus: the Ziggurat's guardian, a sphinx grown to
    a mountain. A lion's body of honey stone, a warrior's torso rising from
    it, a pharaoh-lion face in a honeycomb nemes, and in its chest a window
    of amber with an ancient insect caught inside. Molten: the amber has
    melted and runs with fire. Hive: the swarm has made it their comb."""
    m = Model('amber_colossus', 0.17, {
        'stone': (190, 138, 70), 'stone_dark': (126, 84, 46), 'gold': (236, 186, 76), 'gold_dark': (176, 122, 50),
        'lapis': (44, 86, 150), 'amber': (232, 148, 40), 'comb': (210, 150, 56), 'comb_dark': (120, 74, 30),
        'bee': (40, 30, 24), 'bee_band': (240, 196, 60), 'wing': (230, 236, 240), 'void': (40, 22, 14),
        'glow': (255, 176, 60), 'glow_hot': (255, 236, 160), 'glow_fire': (255, 96, 30),
    }, rough=('stone', 'comb'))

    def body(part, form):
        b = m.part(part)
        b.ellipsoid((0, 2.7, 1.4), (1.75, 1.3, 2.1), 'stone')                         # lion hindquarters
        b.ellipsoid((0, 3.7, 1.2), (1.2, 0.4, 1.6), 'gold_dark')                       # saddle cloth of gold
        for z in (0.4, 1.2, 2.0):
            ring(b, (0, 2.8, z), 1.55 - abs(z - 1.2) * 0.25, 0.08, 'gold', axis='x', n=28)
        b.chain([(0, 3.0, 3.3), (0.3, 2.4, 4.0), (0.1, 1.4, 4.3), (0.4, 1.0, 4.0)], 0.22, 0.12, 'stone')   # tail
        b.ellipsoid((0.4, 0.95, 3.95), (0.3, 0.35, 0.3), 'comb')
        b.capsule((0, 2.8, -0.6), (0, 5.4, -1.5), 1.45, 1.25, 'stone')                # the upright torso
        for side in (-1, 1):
            b.ellipsoid((side * 1.9, 5.3, -1.5), (0.8, 0.6, 0.8), 'gold')              # pauldrons
            b.box((side * 1.9 - 0.8, 5.15, -2.3), (side * 1.9 + 0.8, 5.28, -0.7), 'lapis')
        b.ellipsoid((0, 4.5, -2.45), (0.85, 0.95, 0.3), 'gold_dark')                  # amber window frame
        b.ellipsoid((0, 4.5, -2.55), (0.68, 0.8, 0.25), 'amber' if form != 'molten' else 'glow_fire')
        if form != 'molten':                                                          # the trapped insect
            b.ellipsoid((0, 4.6, -2.72), (0.12, 0.3, 0.08), 'void')
            for side in (-1, 1):
                b.capsule((0, 4.7, -2.74), (side * 0.32, 4.95, -2.74), 0.04, 0.02, 'void')
                b.capsule((0, 4.45, -2.74), (side * 0.3, 4.2, -2.74), 0.04, 0.02, 'void')
            b.ellipsoid((0, 4.5, -2.6), (0.22, 0.22, 0.1), 'glow')
        ring(b, (0, 3.0, -0.8), 1.4, 0.12, 'gold', n=32)                               # belt
        if form == 'molten':
            for pts in ([(-1.2, 2.4, -1.2), (-0.7, 3.2, -1.7), (-1.0, 4.0, -2.0)], [(1.1, 2.6, -1.3), (0.7, 3.6, -1.9)],
                        [(-1.4, 2.6, 0.8), (-1.0, 3.0, 1.8), (-1.5, 2.4, 2.6)], [(1.4, 2.8, 1.0), (1.2, 2.2, 2.2)]):
                b.chain(pts, 0.1, 0.1, 'glow_fire')
            for x, z in ((-0.6, -2.5), (0.5, -2.4)):
                b.capsule((x, 3.6, z), (x, 2.4, z - 0.1), 0.1, 0.04, 'glow_hot')
        if form == 'hive':
            for x, y, z, r in ((-1.4, 3.2, 0.4, 0.55), (1.2, 2.6, 1.8, 0.6), (0.2, 3.6, 2.2, 0.5), (-1.0, 4.8, -1.0, 0.4)):
                b.ellipsoid((x, y, z), (r, r * 0.9, r), 'comb')
                for dx, dy in ((-0.15, 0.1), (0.15, -0.05), (0.0, -0.2)):
                    b.ellipsoid((x + dx, y + dy, z - r * 0.85 * (1 if z < 1 else -1)), (0.07, 0.07, 0.05), 'comb_dark')
            for x, y, z in ((-2.4, 5.6, -0.6), (2.6, 4.4, 0.2), (-1.8, 3.4, 2.6), (1.8, 6.4, -1.8)):
                b.ellipsoid((x, y, z), (0.12, 0.1, 0.16), 'bee')
                b.ellipsoid((x, y, z + 0.02), (0.13, 0.04, 0.05), 'bee_band')
                b.ellipsoid((x, y + 0.12, z), (0.14, 0.03, 0.08), 'wing')

    def head(part, form):
        h = m.part(part)
        h.ellipsoid((0, 0.2, -0.2), (0.85, 0.95, 0.85), 'comb' if form == 'hive' else 'gold')   # nemes
        for side in (-1, 1):
            h.box((side * 0.85 - 0.25, -1.2, -0.55), (side * 0.85 + 0.25, 0.4, 0.15), 'gold')
            for y in (-1.0, -0.6, -0.2):
                h.box((side * 0.85 - 0.26, y, -0.56), (side * 0.85 + 0.26, y + 0.14, 0.16), 'lapis')
        h.ellipsoid((0, -0.05, -0.62), (0.62, 0.72, 0.45), 'stone')                  # the face
        h.box((-0.45, 0.22, -1.08), (0.45, 0.3, -0.96), 'stone_dark')                # brow
        for side in (-1, 1):
            h.ellipsoid((side * 0.24, 0.08, -1.02), (0.12, 0.07, 0.05), 'glow_fire' if form == 'molten' else 'glow')
        h.ellipsoid((0, -0.2, -1.04), (0.14, 0.16, 0.1), 'stone_dark')               # broad lion nose
        h.box((-0.22, -0.45, -1.05), (0.22, -0.4, -0.98), 'void')                    # mouth
        h.capsule((0, -0.62, -0.9), (0, -1.15, -0.95), 0.14, 0.1, 'gold')             # royal beard
        for y in (-0.75, -0.95):
            ring(h, (0, y, -0.92), 0.13, 0.03, 'lapis', n=12)
        h.capsule((0, 0.95, -0.7), (0, 1.25, -0.82), 0.12, 0.05, 'gold')             # uraeus
        h.ellipsoid((0, 1.3, -0.84), (0.1, 0.1, 0.08), 'glow')

    body('body', 'stone')
    body('body_molten', 'molten')
    body('body_hive', 'hive')
    head('head', 'stone')
    head('head_molten', 'molten')
    head('head_hive', 'hive')
    m.joint('head', 'head', (0, 6.79, -2.21), 'head', 1)
    for side, name in ((-1, 'arm_l'), (1, 'arm_r')):
        a = m.part(name)
        a.capsule((0, 0, 0), (0, -1.6, -0.3), 0.52, 0.46, 'stone')
        a.ellipsoid((0, -1.7, -0.36), (0.55, 0.42, 0.55), 'gold')                     # bracer
        a.ellipsoid((0, -2.3, -0.5), (0.62, 0.55, 0.62), 'stone_dark')                # fist
        for dx in (-0.25, 0.0, 0.25):
            a.ellipsoid((dx, -2.4, -1.02), (0.13, 0.14, 0.12), 'stone')
        m.joint(name, name, (side * 2.37, 5.21, -1.58), 'arm', 1 if side < 0 else -1)
    for side, z, name in ((-1, -1.58, 'leg_l_0'), (-1, 2.68, 'leg_l_1'), (1, -1.58, 'leg_r_0'), (1, 2.68, 'leg_r_1')):
        part = 'leg_front' if z < 0 else 'leg_back'
        if part not in m.parts:
            l = m.part(part)
            l.capsule((0, 0, 0), (0, -1.5, 0.05), 0.55, 0.42, 'stone')
            l.ellipsoid((0, -1.8, -0.2), (0.5, 0.25, 0.65), 'stone_dark')               # paw
            for dx in (-0.25, 0.0, 0.25):
                l.capsule((dx, -1.85, -0.7), (dx, -1.95, -0.9), 0.1, 0.04, 'gold')       # claws
        m.joint(name, part, (side * 2.05, 1.89, z), 'leg', (1 if z < 0 else -1) * side)
    m.hand = (0.0, 4.5, -2.8)
    m.extra = dict(hover=0, bob=0.035, waddle=0.025)
    return m



# --- Fixes to models that stay ----------------------------------------------------------------

def fix_hollow_crown_halo():
    """The Hollow Crown's halo is a vertical ring behind its head. It turned
    round the boss's feet (pivot at the origin, spinning on y) and swung
    round the body like a door; it now turns like a wheel on its own centre
    (pivot there, axis "z", CreatureModel._animate_wraith). Safe to run again
    after tools/redesign_pixel_bosses.py rewrites the rig."""
    folder = ROOT / 'creatures' / 'hollow_crown'
    rig = json.loads((folder / 'rig.json').read_text())
    halo = rig['limbs']['halo']
    old = halo['pivot']
    if halo.get('axis') == 'z':
        return
    pts = []
    fm = rig['parts']['halo']['frame_min']
    for suffix in ('', '_glow'):
        f = folder / ('halo' + suffix + '.vox')
        if f.exists():
            pts += [(x + fm[0] + old[0], y + fm[1] + old[1], z + fm[2] + old[2]) for (x, y, z) in read_vox(f)]
    center = [int(round((min(p[i] for p in pts) + max(p[i] for p in pts)) / 2)) for i in range(3)]
    for part in ('halo', 'halo_fractured', 'halo_unbound'):
        if part in rig['parts']:
            rig['parts'][part]['frame_min'] = [rig['parts'][part]['frame_min'][i] + old[i] - center[i] for i in range(3)]
    halo['pivot'] = center
    halo['axis'] = 'z'
    (folder / 'rig.json').write_text(json.dumps(rig, indent=2) + '\n')


BUILDERS = {f.__name__: f for f in [aurora_sentinel, ember_lich, hoarfrost_owl, obsidian_ram, dune_monolith,
                                     runic_archivist, azure_medusa, vine_mantis, moss_tortoise,
                                     cinder_cultist, mummy_guard, gilded_sentinel, obsidian_brute, lava_golem,
                                     drowned_acolyte, choir_wraith, reef_guardian,
                                     dawn_scarab, cinder_sentinel, mirror_shade, rimeheart_shardling,
                                     bark_warden, grave_watcher, fungal_brute, hive_mother,
                                     castle_knight, castle_champion, amber_colossus]}


def main(argv):
    out = None
    if '--sheet' in argv:
        i = argv.index('--sheet')
        out = argv[i + 1]
        argv = argv[:i] + argv[i + 2:]
    names = argv or list(BUILDERS)
    for name in names:
        BUILDERS[name]().save()
        print('remade', name, flush=True)
    if not argv:
        fix_hollow_crown_halo()
        print('fixed the hollow crown halo', flush=True)
    if out:
        sheet(names, out)


if __name__ == '__main__':
    main(sys.argv[1:])
