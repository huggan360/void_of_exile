#!/usr/bin/env python3
"""Generates creature models: .vox parts plus a rig.json describing how the
parts fit together (pivots for arms and legs), read by CreatureModel.

Run:  python3 tools/make_creatures.py [name ...]   (no names = all of them)
Output: creatures/<name>/<part>.vox and rig.json

Coordinates: y-up, 1 unit = 1 voxel, feet at y=0, facing -z. Each part is
written in a fixed frame (frame_min / frame_size) so hand edits in Goxel
never shift it in game (a frame of None is fitted to the voxels instead).
Arm and leg pivots are at their top center.

Limbs can have a role telling CreatureModel how to move them: "leg"
(swings with the stride; phase +1/-1, axis "x" or "y", amount, yaw at rest),
"arm" (swings opposite the legs; "throws" raises it to attack), "claw"
(snaps and lifts when attacking) and "tail" (cocks back while winding up and
strikes forward when it fires), "wing" (flaps; phase +1 left / -1 right)
and "sway" (swings side to side, for dragon tails). hand_limb makes
projectiles leave from a point on that limb (e.g. a stinger) instead of
from the body.

Palette colors whose names start with "glow" glow in the game: they're
written to a separate <part>_glow.vox. Rig extras: "hover" (meters off the
ground, for floating creatures), "bob" (how much they float up and down),
"spin" (radians per second, the whole model turns) and "variants" (other
looks a boss can switch to: {name: {part: other part}}).

Round creatures (dragons, spirits, genies...) are sculpted with numpy in
tools/voxel_sculpt.py.
"""
import json
import os
import struct
import sys

from voxel_sculpt import Part

VOXEL_SIZE = 1.8 / 16.0  # same voxel size as the Archer


def box(v, x0, x1, y0, y1, z0, z1, c):
    for x in range(x0, x1):
        for y in range(y0, y1):
            for z in range(z0, z1):
                v[(x, y, z)] = c


def line(v, a, b, c, t=1):
    """A thick line of voxels from a to b (cubes of size t centered on it)."""
    steps = max(abs(b[i] - a[i]) for i in range(3)) or 1
    for i in range(steps + 1):
        p = [round(a[k] + (b[k] - a[k]) * i / steps) - t // 2 for k in range(3)]
        box(v, p[0], p[0] + t, p[1], p[1] + t, p[2], p[2] + t, c)


def mirror(v):
    """Mirrors a left-side part (x <= 0) into the right side."""
    return {(-x - 1, y, z): c for (x, y, z), c in v.items()}


def fit_frame(vox):
    xs, ys, zs = zip(*vox)
    lo = (min(xs), min(ys), min(zs))
    return lo, (max(xs) - lo[0] + 1, max(ys) - lo[1] + 1, max(zs) - lo[2] + 1)


def write_vox(path, vox, palette, frame_min, frame_size):
    names = list(palette)
    index = {n: i + 1 for i, n in enumerate(names)}
    minx, miny, minz = frame_min
    sx, sy, sz = frame_size
    for x, y, z in vox:
        assert minx <= x < minx + sx and miny <= y < miny + sy and minz <= z < minz + sz, \
            f"{path}: voxel {(x, y, z)} outside frame"

    def chunk(cid, content, children=b""):
        return cid + struct.pack("<ii", len(content), len(children)) + content + children

    # godot_voxel's loader maps file (a, b, c) to Godot (b, c, a): write (z, x, y).
    xyzi = struct.pack("<i", len(vox))
    for (x, y, z), c in vox.items():
        xyzi += struct.pack("<BBBB", z - minz, x - minx, y - miny, index[c])
    rgba = b""
    for i in range(256):
        r, g, b = palette[names[i]] if i < len(names) else (0, 0, 0)
        rgba += struct.pack("<BBBB", r, g, b, 255)
    children = chunk(b"SIZE", struct.pack("<iii", sz, sx, sy)) + chunk(b"XYZI", xyzi) + chunk(b"RGBA", rgba)
    with open(path, "wb") as f:
        f.write(b"VOX " + struct.pack("<i", 150) + chunk(b"MAIN", b"", children))


def shade(v, src, variants):
    """Recolors some voxels of color `src` into `variants`, for texture."""
    for (x, y, z), c in list(v.items()):
        if c == src:
            v[(x, y, z)] = variants[((x * 73856093) ^ (y * 19349663) ^ (z * 83492791)) % len(variants)]


# --- Goblin --------------------------------------------------------------------------

GOBLIN = {
    "skin": (110, 168, 64), "skin_b": (96, 152, 54), "skin_dark": (72, 120, 42),
    "eye": (250, 220, 60), "pupil": (30, 20, 10), "mouth": (40, 24, 20), "tooth": (240, 236, 210),
    "leather": (120, 82, 48), "leather_b": (104, 70, 40), "belt": (70, 44, 28), "pants": (82, 64, 44),
    "boot": (52, 36, 26),
}


def goblin_body():
    v = {}
    box(v, -3, 3, 3, 7, -2, 2, "leather")  # tunic
    box(v, -3, 3, 3, 4, -2, 2, "belt")
    box(v, -2, 2, 2, 3, -2, -1, "leather_b")  # loincloth flap
    box(v, -3, 3, 7, 12, -3, 2, "skin")  # big head
    box(v, -3, 3, 11, 12, -3, 2, "skin_dark")
    box(v, -1, 1, 12, 13, -1, 1, "skin_dark")  # tuft
    for side in (-1, 1):  # long pointy ears
        ox = -6 if side < 0 else 3
        box(v, ox, ox + 3, 9, 10, -1, 0, "skin")
        tip = -6 if side < 0 else 5
        box(v, tip, tip + 1, 10, 11, -1, 0, "skin_dark")
    box(v, -2, 0, 10, 11, -3, -2, "eye")
    box(v, 1, 3, 10, 11, -3, -2, "eye")
    v[(-1, 10, -3)] = "pupil"
    v[(2, 10, -3)] = "pupil"
    box(v, -1, 1, 9, 10, -4, -3, "skin_dark")  # nose
    box(v, -2, 2, 8, 9, -3, -2, "mouth")
    v[(-1, 8, -3)] = "tooth"
    v[(1, 8, -3)] = "tooth"
    shade(v, "skin", ["skin", "skin", "skin_b"])
    shade(v, "leather", ["leather", "leather_b"])
    return v


def goblin_arm():
    v = {}
    box(v, -1, 1, -1, 0, -1, 1, "leather")
    box(v, -1, 1, -4, -1, -1, 1, "skin")
    return v


def goblin_leg():
    v = {}
    box(v, -1, 1, -2, 0, -1, 1, "pants")
    box(v, -1, 1, -3, -2, -1, 1, "boot")
    v[(0, -3, -2)] = "boot"
    return v


# --- Goblin master ---------------------------------------------------------------------

MASTER = {
    "skin": (84, 132, 52), "skin_b": (72, 118, 44), "skin_dark": (56, 94, 34),
    "eye": (255, 70, 50), "mouth": (40, 24, 20), "tooth": (240, 236, 210),
    "iron": (120, 124, 132), "iron_b": (100, 104, 112), "iron_dark": (66, 68, 76),
    "horn": (232, 220, 190), "cape": (150, 36, 40), "cape_dark": (110, 24, 30),
    "leather": (96, 64, 38), "boot": (48, 34, 24), "gold": (236, 190, 70),
}


def master_body():
    v = {}
    box(v, -4, 4, 4, 10, -3, 3, "iron")  # armored chest
    box(v, -4, 4, 4, 5, -3, 3, "leather")  # belt
    box(v, -1, 1, 4, 5, -4, -3, "gold")  # buckle
    box(v, -4, 4, 9, 10, -3, 3, "iron_dark")  # collar
    box(v, -3, 3, 3, 4, -3, 3, "leather")  # skirt
    box(v, -4, 4, 2, 10, 3, 4, "cape")  # cape
    box(v, -4, 4, 2, 3, 3, 4, "cape_dark")
    box(v, -4, 4, 10, 15, -4, 3, "skin")  # head
    box(v, -4, 4, 14, 16, -4, 3, "iron")  # helmet
    box(v, -4, 4, 14, 15, -4, -3, "iron_dark")  # brim
    for x in (-5, 4):  # horns curving up
        box(v, x, x + 1, 14, 16, -1, 1, "horn")
        box(v, x + (-1 if x < 0 else 1), x + (0 if x < 0 else 2), 16, 17, -1, 0, "horn")
    for side in (-1, 1):  # ears
        ox = -7 if side < 0 else 4
        box(v, ox, ox + 3, 12, 13, 0, 1, "skin")
    box(v, -3, -1, 12, 13, -4, -3, "eye")
    box(v, 1, 3, 12, 13, -4, -3, "eye")
    box(v, -1, 1, 11, 12, -5, -4, "skin_dark")  # nose
    box(v, -3, 3, 10, 11, -4, -3, "mouth")
    v[(-2, 10, -4)] = "tooth"
    v[(2, 10, -4)] = "tooth"
    shade(v, "iron", ["iron", "iron", "iron_b"])
    shade(v, "skin", ["skin", "skin_b"])
    return v


def master_arm():
    v = {}
    box(v, -1, 2, -2, 0, -1, 2, "iron")  # pauldron
    box(v, -1, 2, -5, -2, -1, 2, "skin")
    box(v, -1, 2, -6, -5, -1, 2, "leather")  # glove
    return v


def master_leg():
    v = {}
    box(v, -1, 2, -2, 0, -1, 2, "leather")
    box(v, -1, 2, -4, -2, -1, 2, "boot")
    box(v, -1, 2, -4, -3, -2, -1, "boot")
    return v


# --- Scorpions ----------------------------------------------------------------------------
# Low and wide (about 32 voxels across with legs and claws), eight legs, two
# claws and a tail curled up over the back that shoots from the stinger.

SCORPION_VOXEL = 0.08

SAND_SCORPION = {
    "shell": (214, 176, 112), "shell_b": (198, 160, 98), "shell_dark": (150, 112, 64),
    "belly": (232, 204, 150), "leg": (196, 156, 96), "leg_dark": (130, 96, 56),
    "eye": (30, 20, 14), "claw_tip": (110, 78, 44), "sting_bulb": (226, 186, 110), "sting": (60, 40, 24),
}

BLACK_SCORPION = {
    "shell": (36, 32, 42), "shell_b": (48, 42, 56), "shell_dark": (18, 16, 22),
    "belly": (66, 58, 78), "leg": (42, 38, 48), "leg_dark": (22, 20, 26),
    "eye": (210, 80, 255), "claw_tip": (120, 70, 170), "sting_bulb": (130, 60, 200), "sting": (230, 170, 255),
}

SCORPION_LEGS = [(-7, -35), (-4, -12), (0, 12), (3, 35)]  # (z, rest yaw of the left leg)


def scorpion_body():
    v = {}
    # Head and chest (front), with a rounded top.
    box(v, -5, 5, 3, 7, -9, -1, "shell")
    box(v, -4, 4, 7, 8, -8, -2, "shell")
    box(v, -4, 4, 2, 3, -8, -1, "belly")
    box(v, -2, 2, 3, 5, -10, -9, "shell_dark")  # mouth parts
    for x in (-1, 0):
        v[(x, 7, -6)] = "eye"
    for x in (-4, 3):
        v[(x, 6, -9)] = "eye"
    # Segmented back.
    for i, z0 in enumerate(range(-1, 9, 2)):
        w = 6 if i < 3 else 5
        box(v, -w, w, 3, 7, z0, z0 + 2, "shell")
        box(v, -w + 1, w - 1, 7, 8, z0, z0 + 2, "shell")
        box(v, -w + 1, w - 1, 7, 8, z0, z0 + 1, "shell_dark")
        box(v, -w, w, 6, 7, z0, z0 + 1, "shell_dark")
        box(v, -w + 1, w - 1, 2, 3, z0, z0 + 2, "belly")
    shade(v, "shell", ["shell", "shell", "shell_b"])
    return v


def scorpion_leg():
    v = {}
    line(v, (0, 0, 0), (-3, 2, 0), "leg", 2)
    box(v, -5, -3, 2, 4, 0, 1, "leg_dark")  # knee
    line(v, (-5, 2, 0), (-7, -3, 0), "leg")
    line(v, (-7, -4, 0), (-8, -5, 0), "leg_dark")
    return v


def scorpion_claw():
    v = {}
    line(v, (0, 0, 0), (-3, 1, -4), "leg", 2)
    line(v, (-3, 1, -4), (-2, 1, -7), "leg", 2)
    box(v, -5, 0, 0, 3, -11, -7, "shell")  # the pincer's hand
    box(v, -4, -1, 3, 4, -10, -8, "shell_b")
    box(v, -5, -3, 0, 2, -15, -11, "shell")  # outer finger
    box(v, -2, 0, 0, 2, -14, -11, "shell")  # inner finger
    box(v, -5, -3, 0, 2, -16, -15, "claw_tip")
    box(v, -2, 0, 0, 2, -15, -14, "claw_tip")
    return v


def scorpion_tail():
    v = {}
    path = [(0, 0, 0), (0, 4, 3), (0, 9, 5), (0, 13, 4), (0, 16, 1), (0, 17, -2)]
    for i in range(len(path) - 1):
        t = 4 if i < 2 else 3
        line(v, path[i], path[i + 1], "shell" if i % 2 == 0 else "shell_b", t)
        box(v, -1, 1, path[i + 1][1] - 1, path[i + 1][1] + 1, path[i + 1][2] - 1, path[i + 1][2] + 1, "shell_dark")
    box(v, -2, 2, 14, 18, -6, -2, "sting_bulb")
    line(v, (0, 14, -6), (0, 12, -8), "sting")
    return v


def scorpion(palette):
    rig = {
        "tail": {"part": "tail", "pivot": [0, 7, 8], "role": "tail"},
        "claw_l": {"part": "claw_l", "pivot": [-4, 5, -9], "role": "claw", "phase": 1},
        "claw_r": {"part": "claw_r", "pivot": [4, 5, -9], "role": "claw", "phase": -1},
    }
    for i, (z, yaw) in enumerate(SCORPION_LEGS):
        x = 5 if z < -1 else 6
        phase = 1 if i % 2 == 0 else -1
        rig[f"leg_l{i}"] = {"part": "leg_l", "pivot": [-x, 5, z], "role": "leg", "axis": "y",
                            "phase": phase, "amount": 0.55, "yaw": yaw}
        rig[f"leg_r{i}"] = {"part": "leg_r", "pivot": [x, 5, z], "role": "leg", "axis": "y",
                            "phase": -phase, "amount": 0.55, "yaw": -yaw}
    return {
        "palette": palette,
        "voxel_size": SCORPION_VOXEL,
        "parts": {
            "body": (scorpion_body, None, None),
            "tail": (scorpion_tail, None, None),
            "claw_l": (scorpion_claw, None, None),
            "claw_r": (lambda: mirror(scorpion_claw()), None, None),
            "leg_l": (scorpion_leg, None, None),
            "leg_r": (lambda: mirror(scorpion_leg()), None, None),
        },
        "rig": rig,
        "hand_limb": "tail",
        "hand": [0, 13, -8],
        "waddle": 0.15,
    }


# --- Crab ------------------------------------------------------------------------------
# Lives in groups on the shores, around the Tide Rocks. Flat shell, six legs,
# two big claws, eyes on stalks.

CRAB = {
    "shell": (214, 84, 52), "shell_b": (196, 70, 44), "shell_dark": (150, 48, 32), "belly": (240, 196, 150),
    "claw_tip": (60, 30, 24), "eye": (20, 16, 16), "spots": (240, 150, 90),
}
CRAB_SCALE = 20  # voxels per unit


def crab_body():
    p = Part(CRAB_SCALE, CRAB)
    p.ellipsoid((0, 0.45, 0), (0.55, 0.22, 0.42), "shell")
    p.ellipsoid((0, 0.36, 0), (0.48, 0.14, 0.38), "belly")
    for x in (-1, 1):
        p.capsule((0.15 * x, 0.6, -0.28), (0.18 * x, 0.82, -0.36), 0.035, 0.03, "shell_dark")
        p.ellipsoid((0.18 * x, 0.86, -0.37), (0.06, 0.06, 0.06), "eye")
        p.ellipsoid((0.25 * x, 0.6, 0.05), (0.09, 0.05, 0.09), "spots")
    p.ellipsoid((0, 0.65, 0.12), (0.1, 0.04, 0.1), "spots")
    return p.voxels(shade={"shell": ["shell", "shell", "shell_b"]})


def crab_leg():
    p = Part(CRAB_SCALE, CRAB)
    p.chain([(0, 0, 0), (-0.32, 0.16, 0), (-0.55, -0.38, 0)], 0.06, 0.03, "shell_dark")
    return p.voxels()


def crab_claw():
    p = Part(CRAB_SCALE, CRAB)
    p.chain([(0, 0, 0), (-0.12, 0.05, -0.22)], 0.06, 0.06, "shell_dark")
    p.ellipsoid((-0.18, 0.08, -0.42), (0.14, 0.1, 0.19), "shell")
    p.capsule((-0.24, 0.1, -0.55), (-0.2, 0.11, -0.72), 0.06, 0.03, "shell")
    p.capsule((-0.1, 0.06, -0.55), (-0.15, 0.06, -0.68), 0.045, 0.02, "claw_tip")
    return p.voxels()


def crab():
    rig = {
        "claw_l": {"part": "claw_l", "pivot": [-6, 9, -6], "role": "claw", "phase": 1},
        "claw_r": {"part": "claw_r", "pivot": [6, 9, -6], "role": "claw", "phase": -1},
    }
    for i, z in enumerate((-2, 1, 4)):
        phase = 1 if i % 2 == 0 else -1
        for side, name in ((-1, "l"), (1, "r")):
            rig[f"leg_{name}{i}"] = {"part": f"leg_{name}", "pivot": [9 * side, 9, z], "role": "leg", "axis": "y",
                                     "phase": phase * -side, "amount": 0.6, "yaw": (i - 1) * 25 * side}
    return {
        "palette": CRAB, "voxel_size": 0.07,
        "parts": {
            "body": (crab_body, None, None),
            "leg_l": (crab_leg, None, None),
            "leg_r": (lambda: mirror(crab_leg()), None, None),
            "claw_l": (crab_claw, None, None),
            "claw_r": (lambda: mirror(crab_claw()), None, None),
        },
        "rig": rig, "hand": [0, 9, -10], "waddle": 0.2,
    }


# --- Dragons ----------------------------------------------------------------------------
# One design at any size: the small green dragons of the jungle (about 32
# voxels long), the Blue Dragon's glowing dragonlings, and the Blue Dragon
# himself (96 voxels per unit: a body about 215 voxels long, a 190 voxel
# tail and 165 voxel wings, some 380 voxels from snout to tail and across
# the wings, 150 tall). Units: the body is about 2.3 long, feet at y = 0, facing -z.
# Parts: body (with neck, head and legs), tail (sways) and two wings (flap).

WING_PIVOT = (0.28, 0.85, -0.1)
TAIL_PIVOT = (0.0, 0.6, 0.6)


def _dragon_names(glowing, hot=False):
    spike = ("glow_spike_hot" if hot else "glow_spike") if glowing else "spike"
    membrane = ("glow_membrane_hot" if hot else "glow_membrane") if glowing else "membrane"
    return spike, membrane


def dragon_body(palette, scale, glowing, hot=False):
    p = Part(scale, palette)
    spike, _ = _dragon_names(glowing, hot)
    for x in (-1, 1):
        p.chain([(0.24 * x, 0.55, -0.25), (0.34 * x, 0.3, -0.36), (0.32 * x, 0.06, -0.42)], 0.12, 0.07, "scale_dark")
        p.chain([(0.24 * x, 0.5, 0.4), (0.37 * x, 0.32, 0.56), (0.34 * x, 0.06, 0.42)], 0.14, 0.08, "scale_dark")
        for foot_z in (-0.45, 0.4):
            for k in (-1, 0, 1):
                p.capsule((0.33 * x, 0.04, foot_z), (0.33 * x + 0.05 * k, 0.02, foot_z - 0.15), 0.035, 0.012, "claw")
    p.ellipsoid((0, 0.62, 0.1), (0.33, 0.3, 0.55), "scale")
    p.ellipsoid((0, 0.46, 0.05), (0.26, 0.18, 0.46), "belly")
    p.chain([(0, 0.78, -0.3), (0, 1.0, -0.62), (0, 1.18, -0.88)], 0.2, 0.13, "scale")
    p.ellipsoid((0, 1.24, -1.08), (0.17, 0.15, 0.24), "scale")
    p.ellipsoid((0, 1.17, -1.32), (0.12, 0.09, 0.17), "scale")
    p.ellipsoid((0, 1.09, -1.25), (0.11, 0.05, 0.18), "belly")
    for x in (-1, 1):
        p.ellipsoid((0.11 * x, 1.29, -1.18), (0.04, 0.035, 0.05), "glow_eye")
        p.chain([(0.08 * x, 1.33, -1.0), (0.15 * x, 1.45, -0.82), (0.17 * x, 1.5, -0.62)], 0.045, 0.012, "horn")
        p.capsule((0.05 * x, 1.2, -1.47), (0.05 * x, 1.21, -1.49), 0.02, 0.02, "scale_dark")  # nostrils
    size = 0.22 if hot else 0.13
    for x, y, z in [(0, 1.32, -0.95), (0, 1.15, -0.7), (0, 0.98, -0.45), (0, 0.94, -0.15),
                    (0, 0.94, 0.15), (0, 0.9, 0.42), (0, 0.84, 0.62)]:
        p.capsule((x, y - 0.05, z), (x, y + size, z + 0.07), 0.05, 0.008, spike)
    if hot:
        # Cracks of light across the chest and flanks.
        for i in range(14):
            a = i * 2.39996
            p.ellipsoid((0.3 * (1 if i % 2 else -1) * (0.7 + 0.3 * abs(((i * 37) % 10) / 10)),
                         0.5 + 0.25 * ((i * 53) % 10) / 10, -0.3 + 0.8 * ((i * 71) % 10) / 10),
                        (0.03, 0.06 + 0.02 * (i % 3), 0.05), "glow_spike_hot")
    return p.voxels(shade={"scale": ["scale", "scale", "scale_b"]})


def dragon_tail(palette, scale, glowing, hot=False):
    p = Part(scale, palette)
    spike, membrane = _dragon_names(glowing, hot)
    pts = [(0, 0, 0), (0, -0.08, 0.4), (0.12, -0.18, 0.8), (0.28, -0.22, 1.15), (0.36, -0.18, 1.45)]
    p.chain(pts, 0.21, 0.04, "scale")
    for x, y, z in pts[1:4]:
        p.capsule((x, y + 0.05, z), (x, y + (0.2 if hot else 0.13), z + 0.08), 0.04, 0.008, spike)
    tip = pts[-1]
    p.triangle(tip, (tip[0] + 0.2, tip[1], tip[2] + 0.3), (tip[0] - 0.1, tip[1], tip[2] + 0.28), 0.04, membrane)
    return p.voxels(shade={"scale": ["scale", "scale", "scale_b"]})


def dragon_wing(palette, scale, glowing, hot=False):
    """The left wing, around its shoulder pivot; it reaches out along -x."""
    p = Part(scale, palette)
    _, membrane = _dragon_names(glowing, hot)
    s, e, w = (0, 0, 0), (-0.55, 0.35, 0.15), (-1.05, 0.6, 0.05)
    tips = [(-1.6, 0.45, 0.25), (-1.55, 0.15, 0.6), (-1.2, -0.05, 0.85), (-0.75, 0.0, 0.75)]
    back = (-0.15, 0.0, 0.45)
    for i in range(len(tips) - 1):
        p.triangle(w, tips[i], tips[i + 1], 0.035, membrane)
    p.triangle(w, tips[-1], e, 0.035, membrane)
    p.triangle(e, tips[-1], back, 0.035, membrane)
    p.triangle(e, back, s, 0.035, membrane)
    p.chain([s, e, w], 0.08, 0.045, "scale_dark")
    for t in tips:
        p.capsule(w, t, 0.035, 0.012, "scale_dark")
    p.capsule(w, (w[0] + 0.05, w[1] + 0.15, w[2] - 0.08), 0.035, 0.008, "claw")
    return p.voxels()


def dragon(palette, scale, voxel_size, glowing, hover=0.0, variants=False, flap_rate=8.0):
    def v(t):
        return [round(t[0] * scale), round(t[1] * scale), round(t[2] * scale)]
    parts = {
        "body": (lambda: dragon_body(palette, scale, glowing), None, None),
        "tail": (lambda: dragon_tail(palette, scale, glowing), None, None),
        "wing_l": (lambda: dragon_wing(palette, scale, glowing), None, None),
        "wing_r": (lambda: mirror(dragon_wing(palette, scale, glowing)), None, None),
    }
    spec = {
        "palette": palette, "voxel_size": voxel_size, "parts": parts,
        "rig": {
            "tail": {"part": "tail", "pivot": v(TAIL_PIVOT), "role": "sway"},
            "wing_l": {"part": "wing_l", "pivot": v((-WING_PIVOT[0], WING_PIVOT[1], WING_PIVOT[2])), "role": "wing",
                       "phase": 1},
            "wing_r": {"part": "wing_r", "pivot": v(WING_PIVOT), "role": "wing", "phase": -1},
        },
        "hand": v((0, 1.15, -1.5)), "waddle": 0.0, "hover": hover, "bob": 0.08 if hover else 0.0,
        "flap_rate": flap_rate,
    }
    if variants:
        parts["body_enraged"] = (lambda: dragon_body(palette, scale, glowing, True), None, None)
        parts["tail_enraged"] = (lambda: dragon_tail(palette, scale, glowing, True), None, None)
        parts["wing_l_enraged"] = (lambda: dragon_wing(palette, scale, glowing, True), None, None)
        parts["wing_r_enraged"] = (lambda: mirror(dragon_wing(palette, scale, glowing, True)), None, None)
        spec["variants"] = {"enraged": {"body": "body_enraged", "tail": "tail_enraged",
                                        "wing_l": "wing_l_enraged", "wing_r": "wing_r_enraged"}}
    return spec


GREEN_DRAGON = {
    "scale": (72, 150, 62), "scale_b": (60, 130, 52), "scale_dark": (40, 94, 40), "belly": (206, 194, 124),
    "horn": (232, 222, 190), "claw": (40, 34, 30), "spike": (214, 176, 80), "membrane": (122, 172, 84),
    "glow_eye": (255, 214, 60),
}


def glowing_dragon_palette(base, glow):
    def mul(c, k):
        return tuple(max(0, min(255, int(v * k))) for v in c)
    return {
        "scale": base, "scale_b": mul(base, 0.86), "scale_dark": mul(base, 0.6), "belly": mul(glow, 0.9),
        "horn": (236, 232, 222), "claw": (30, 28, 40), "glow_spike": glow, "glow_membrane": mul(glow, 0.85),
        "glow_eye": (255, 255, 230),
    }


DRAGONLINGS = {
    "red": ((170, 40, 40), (255, 110, 80)), "gold": ((180, 130, 30), (255, 220, 90)),
    "purple": ((110, 50, 170), (210, 130, 255)), "pink": ((180, 60, 130), (255, 140, 210)),
    "cyan": ((30, 130, 150), (100, 240, 255)), "blue": ((40, 80, 190), (110, 190, 255)),
}

BLUE_DRAGON = glowing_dragon_palette((36, 72, 170), (90, 180, 255))
BLUE_DRAGON.update({"glow_spike_hot": (220, 248, 255), "glow_membrane_hot": (130, 215, 255)})


# --- Spirits, genies and stars -----------------------------------------------------------
# Spirits are gods that haunt ruins: a hooded head on a body that trails off
# into a wisp, a floating crown of light. Genies follow them around (and the
# blue genie is a god of its own in Bluelay). Stars are harmless glowing
# minions that circle a spirit.

def spirit_palette(body, glow):
    return {"body": body, "body_b": tuple(int(v * 0.85) for v in body), "dark": (20, 14, 30),
            "glow_eye": (255, 255, 240), "glow_crown": glow}


SPIRITS = {
    "brown": spirit_palette((140, 100, 66), (255, 196, 110)),
    "blue": spirit_palette((70, 110, 190), (130, 200, 255)),
    "purple": spirit_palette((110, 60, 160), (220, 140, 255)),
}


def spirit_body(palette):
    p = Part(14, palette)
    p.chain([(0, 1.35, 0.02), (0, 0.95, 0.08), (0.05, 0.55, 0.2), (0.12, 0.22, 0.42)], 0.34, 0.05, "body")
    p.ellipsoid((0, 1.55, 0), (0.33, 0.34, 0.3), "body")
    for x in (-1, 1):
        p.ellipsoid((0.12 * x, 1.6, -0.26), (0.06, 0.08, 0.04), "glow_eye")
        p.chain([(0.28 * x, 1.25, 0), (0.5 * x, 1.05, -0.15), (0.55 * x, 0.92, -0.35)], 0.09, 0.05, "body")
    p.ellipsoid((0, 1.44, -0.27), (0.07, 0.05, 0.03), "dark")
    for k in range(5):
        a = k * 6.2832 / 5
        import math
        c = (0.22 * math.cos(a), 2.0, 0.22 * math.sin(a))
        p.capsule((c[0], c[1] - 0.04, c[2]), (c[0], c[1] + 0.12, c[2]), 0.05, 0.015, "glow_crown")
    return p.voxels(shade={"body": ["body", "body", "body_b"]})


def spirit(color):
    pal = SPIRITS[color]
    return {"palette": pal, "voxel_size": 0.075, "parts": {"body": (lambda: spirit_body(pal), None, None)},
            "rig": {}, "hand": [0, 16, -6], "waddle": 0.0, "hover": 0.35, "bob": 0.12}


def genie_palette(skin, glow_all=False):
    pal = {"skin": skin, "skin_b": tuple(int(v * 0.85) for v in skin), "smoke": tuple(int(v * 0.75) for v in skin),
           "hair": (30, 24, 40), "gold": (240, 196, 80), "glow_eye": (255, 255, 240)}
    if glow_all:
        pal = {("glow_" + k if not k.startswith("glow") else k): v for k, v in pal.items()}
    return pal


def genie_body(palette, scale):
    g = "glow_" if "glow_skin" in palette else ""
    p = Part(scale, palette)
    p.chain([(0, 0.85, 0), (0.05, 0.55, 0.1), (0.15, 0.3, 0.25), (0.3, 0.18, 0.35)], 0.26, 0.04, g + "smoke")
    p.ellipsoid((0, 1.15, 0), (0.32, 0.3, 0.22), g + "skin")
    p.ellipsoid((0, 0.9, 0), (0.29, 0.08, 0.21), g + "gold")
    p.ellipsoid((0, 1.6, 0), (0.22, 0.24, 0.22), g + "skin")
    p.capsule((0, 1.8, 0.05), (0, 2.05, 0.16), 0.08, 0.03, g + "hair")
    for x in (-1, 1):
        p.ellipsoid((0.08 * x, 1.64, -0.19), (0.045, 0.05, 0.03), "glow_eye")
        p.chain([(0.3 * x, 1.32, 0), (0.42 * x, 1.1, -0.12), (-0.08 * x, 1.06, -0.24)], 0.08, 0.07, g + "skin")
        p.ellipsoid((0.4 * x, 1.12, -0.12), (0.09, 0.05, 0.09), g + "gold")
    return p.voxels(shade={g + "skin": [g + "skin", g + "skin", g + "skin_b"]})


def genie(skin, scale, glow_all=False):
    pal = genie_palette(skin, glow_all)
    return {"palette": pal, "voxel_size": 0.07, "parts": {"body": (lambda: genie_body(pal, scale), None, None)},
            "rig": {}, "hand": [round(0.4 * scale), round(1.1 * scale), round(-0.2 * scale)], "waddle": 0.0,
            "hover": 0.3, "bob": 0.1}


STAR = {"glow_star": (255, 240, 150), "glow_core": (255, 255, 235)}


def star_body():
    import math
    p = Part(9, STAR)
    pts = []
    for k in range(10):
        a = k * math.pi / 5 - math.pi / 2
        r = 0.6 if k % 2 == 0 else 0.26
        pts.append((r * math.cos(a), 0.0, r * math.sin(a)))
    for k in range(10):
        p.triangle((0, 0, 0), pts[k], pts[(k + 1) % 10], 0.22, "glow_star")
    p.ellipsoid((0, 0, 0), (0.14, 0.14, 0.14), "glow_core")
    return p.voxels()


CREATURES = {
    "goblin": {
        "palette": GOBLIN,
        "parts": {
            "body": (goblin_body, (-6, 0, -4), (12, 13, 8)),
            "arm": (goblin_arm, (-1, -4, -1), (2, 4, 2)),
            "leg": (goblin_leg, (-1, -3, -2), (2, 3, 3)),
        },
        "rig": {
            "arm_l": {"part": "arm", "pivot": [-4, 7, 0]},
            "arm_r": {"part": "arm", "pivot": [4, 7, 0]},
            "leg_l": {"part": "leg", "pivot": [-2, 3, 0]},
            "leg_r": {"part": "leg", "pivot": [2, 3, 0]},
        },
        "hand": [4, 3.5, -1],
    },
    "goblin_master": {
        "palette": MASTER,
        "parts": {
            "body": (master_body, (-8, 0, -6), (16, 17, 10)),
            "arm": (master_arm, (-1, -6, -1), (3, 6, 3)),
            "leg": (master_leg, (-1, -4, -2), (3, 4, 4)),
        },
        "rig": {
            "arm_l": {"part": "arm", "pivot": [-6, 9, 0]},
            "arm_r": {"part": "arm", "pivot": [5, 9, 0]},
            "leg_l": {"part": "leg", "pivot": [-3, 4, 0]},
            "leg_r": {"part": "leg", "pivot": [2, 4, 0]},
        },
        "hand": [5.5, 3.5, -1],
    },
    "sand_scorpion": scorpion(SAND_SCORPION),
    "black_scorpion": scorpion(BLACK_SCORPION),
    "crab": crab(),
    "green_dragon": dragon(GREEN_DRAGON, 10, 0.085, False, hover=0.5),
    **{f"dragonling_{c}": dragon(glowing_dragon_palette(*DRAGONLINGS[c]), 10, 0.085, True, hover=0.7)
       for c in DRAGONLINGS},
    "blue_dragon": dragon(BLUE_DRAGON, 96, 0.045, True, hover=0.3, variants=True, flap_rate=1.6),
    **{f"spirit_{c}": spirit(c) for c in SPIRITS},
    **{f"genie_{c}": genie(SPIRITS[c]["body"], 9) for c in SPIRITS},
    "blue_genie": genie((70, 140, 230), 14, glow_all=True),
    "star": {"palette": STAR, "voxel_size": 0.07, "parts": {"body": (star_body, None, None)}, "rig": {},
             "hand": [0, 0, 0], "waddle": 0.0, "hover": 1.0, "bob": 0.15, "spin": 2.5},
}


if __name__ == "__main__":
    root = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "creatures")
    only = sys.argv[1:]
    for name, spec in CREATURES.items():
        if only and name not in only:
            continue
        out = os.path.join(root, name)
        os.makedirs(out, exist_ok=True)
        rig = {"voxel_size": spec.get("voxel_size", VOXEL_SIZE), "parts": {}, "limbs": spec["rig"],
               "hand": spec["hand"]}
        for key in ("hand_limb", "waddle", "hover", "bob", "spin", "variants", "flap_rate"):
            if key in spec:
                rig[key] = spec[key]
        for part, (fn, fmin, fsize) in spec["parts"].items():
            vox = fn()
            if fmin is None:
                fmin, fsize = fit_frame(vox)
            assert max(fsize) <= 256, f"{name}/{part} is {fsize}: .vox parts can be at most 256 a side"
            # Glowing colors go in their own file (drawn with the glow material).
            glow = {k: c for k, c in vox.items() if c.startswith("glow")}
            base = {k: c for k, c in vox.items() if not c.startswith("glow")}
            rig["parts"][part] = {"frame_min": list(fmin)}
            if base:
                write_vox(os.path.join(out, part + ".vox"), base, spec["palette"], fmin, fsize)
            else:
                rig["parts"][part]["solid"] = False  # glows all over: only a _glow.vox
            if glow:
                write_vox(os.path.join(out, part + "_glow.vox"), glow, spec["palette"], fmin, fsize)
                rig["parts"][part]["glow"] = True
            print(f"{name}/{part}.vox: {len(base)} voxels" + (f" + {len(glow)} glowing" if glow else "")
                  + f"  ({fsize[0]} x {fsize[1]} x {fsize[2]})")
        with open(os.path.join(out, "rig.json"), "w") as f:
            json.dump(rig, f, indent=1)
