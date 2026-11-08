#!/usr/bin/env python3
"""Create-only Amberfall and Tidewell cast using the established VOX pipeline.

Run from the repository root with Python 3. Forward is -Z and Y is up.
All creature geometry uses coarse cells and parent-relative limb pivots.
No existing outputs are replaced, and importing helpers creates no bytecode.
"""
import ast
import json
import math
import struct
import sys
from pathlib import Path

sys.dont_write_bytecode = True
import redesign_pixel_bosses as a

R = Path(__file__).resolve().parents[1]
MANIFEST = R / "creatures/planet_creatures_amberfall_tidewell_manifest.json"
SHOTS = ("honey_comet", "tide_pearl")
a.PAL["amberfall"] = dict(base=(212,137,35), light=(255,208,93),
    shade=(122,71,34), dark=(40,35,32), belly=(247,188,78),
    bone=(255,233,165), wing=(39,119,121), accent=(54,178,164),
    glow_eye=(133,255,226), glow_core=(255,184,42))
a.PAL["tidewell"] = dict(base=(41,128,177), light=(93,190,213),
    shade=(25,68,109), dark=(12,35,60), belly=(128,220,221),
    bone=(237,250,234), wing=(40,125,81), accent=(249,121,107),
    glow_eye=(191,255,248), glow_core=(64,211,255))

# Extract only the rig helper, avoiding the court module's top-level writes.
source = ast.parse((R / "tools/make_court_creatures.py").read_text())
for node in source.body:
    if isinstance(node, ast.FunctionDef) and node.name == "small":
        exec(compile(ast.Module(body=[node], type_ignores=[]), "court_rig_helpers", "exec"))


def joint(name, pivot, role, phase=1, **extra):
    spec = a.limb(name, pivot, role, phase, throws=False, **extra)
    spec["pivot"] = list(pivot)
    return spec


def attach(parts, limbs, name, v, pivot, role, phase=1, **extra):
    parts[name] = v
    limbs[name] = joint(name, pivot, role, phase, **extra)


def face(v, width=3, front=-3, y=1):
    for s in (-1, 1):
        a.box(v, (s * (width - 1) - 1, y, front),
              (s * (width - 1) + 1, y + 2, front + 1), "dark")
        v[s * (width - 1), y + 1, front - 1] = "glow_eye"
    a.line(v, (-1, y - 1, front), (1, y - 1, front), "shade")


def walking_legs(parts, limbs, rows, width, height, insect=False):
    for s, label in ((-1, "l"), (1, "r")):
        for i, z in enumerate(rows):
            v = {}
            reach = 4 if insect else 1
            a.line(v, (0, 0, 0), (s * reach, -2, 0), "shade", 1 if insect else 2)
            a.line(v, (s * reach, -2, 0), (s * (reach + 1), -height, -1), "base", 1 if insect else 2)
            a.box(v, (s * (reach + 1) - 1, -height, -3),
                  (s * (reach + 1) + 2, -height + 2, 0), "light")
            attach(parts, limbs, f"leg_{label}_{i}", v, (s * width, height, z),
                   "leg", s * (-1) ** i, amount=.55, axis="y" if insect else "x")


def chain(parts, limbs, prefix, points, radius=2, color="base", fin=False):
    """Curved authored chain; each new pivot meets the previous segment endpoint."""
    count = len(points) - 1
    for i, (start, end) in enumerate(zip(points, points[1:])):
        delta = tuple(end[k] - start[k] for k in range(3))
        r = max(.7, radius * (1 - .65 * i / count))
        v = {}
        steps = max(abs(q) for q in delta) * 2 + 1
        for step in range(steps + 1):
            center = tuple(round(q * step / steps) for q in delta)
            a.ell(v, center, (r, r, r), color)
            v[center] = color
        a.line(v, (0, math.ceil(r) - 1, 0),
               (delta[0], delta[1] + math.ceil(r) - 1, delta[2]), "belly")
        if fin:
            for s in (-1, 1):
                a.line(v, delta, (delta[0] + s * 2, delta[1] + 2, delta[2]),
                       "glow_core" if i == count - 1 else "accent")
        extra = dict(segment=i, segments=count)
        if i:
            extra["parent_limb"] = f"{prefix}_{i - 1}"
        pivot = start if not i else tuple(start[k] - points[i - 1][k] for k in range(3))
        attach(parts, limbs, f"{prefix}_{i}", v, pivot, "tail_chain", **extra)


def beetle(scarab=False):
    b, parts, limbs = {}, {}, {}
    a.ell(b, (0, 6, 1), (5, 4, 6), "shade")
    a.ell(b, (0, 8, 2), (5, 4, 5), "glow_core" if scarab else "base")
    if not scarab:
        a.ell(b, (0, 9, 2), (3, 4, 3), "glow_core")
        a.line(b, (0, 11, 2), (0, 14, 3), "glow_core", 2)
    a.line(b, (0, 9, -3), (0, 11, 6), "shade")
    a.line(b, (-3, 10, 0), (-3, 10, 3), "bone")
    if scarab:
        for z in (-1, 2, 5):
            a.line(b, (-4, 9, z), (4, 9, z), "belly")
    head = {}
    a.ell(head, (0, 0, 0), (4, 3, 3), "base")
    face(head, 3, -3, 0)
    for s in (-1, 1):
        a.line(head, (s * 2, 2, -1), (s * 4, 4, -2), "shade")
        head[s * 4, 4, -2] = "glow_eye"
    if scarab:
        a.line(head, (0, 2, 0), (0, 8, -2), "light", 2)
        a.line(head, (-2, 8, -2), (2, 8, -2), "glow_core")
    attach(parts, limbs, "head", head, (0, 6, -5), "sway")
    walking_legs(parts, limbs, (-3, 1, 4), 4, 4, True)
    return b, parts, limbs, (0, 6, -9), {}


def drake():
    b, parts, limbs = {}, {}, {}
    a.ell(b, (0, 9, -3), (5, 4, 7), "base")
    a.ell(b, (0, 8, -6), (3, 3, 4), "belly")
    # A vertical dorsal sail viewed from either side, edged with teal.
    for z, top in ((-6, 14), (-5, 16), (-4, 18), (-3, 19), (-2, 18), (-1, 16), (0, 14), (1, 12)):
        a.box(b, (-1, 11, z), (1, top, z + 1), "wing")
        a.line(b, (-1, top, z), (0, top, z), "accent")
    head = {}
    a.ell(head, (0, 0, 0), (4, 4, 4), "base")
    a.ell(head, (0, -2, -3), (3, 2, 3), "belly")
    face(head, 3, -4, 0)
    a.box(head, (-2, -3, -4), (2, -1, -3), "glow_core")
    for s in (-1, 1):
        a.line(head, (s * 2, 2, 1), (s * 3, 5, 2), "bone")
    attach(parts, limbs, "head", head, (0, 12, -9), "head")
    jaw = {}
    a.box(jaw, (-2, -1, -3), (2, 1, 1), "base")
    a.line(jaw, (-1, 0, -3), (1, 0, -3), "glow_core")
    attach(parts, limbs, "jaw", jaw, (0, -3, -2), "jaw", parent_limb="head")
    walking_legs(parts, limbs, (-7, 1), 4, 6)
    chain(parts, limbs, "tail", [(0, 7, 2), (0, 6, 5), (0, 5, 8),
          (1, 4, 11), (2, 4, 14)], 2)
    return b, parts, limbs, (0, 10, -15), dict(animation_style="cantor")


def sphinx():
    b, parts, limbs = {}, {}, {}
    a.ell(b, (0, 9, 1), (6, 5, 8), "base")
    a.ell(b, (0, 12, -5), (5, 6, 4), "belly")
    for y in (10, 12, 14):
        a.line(b, (-4, y, -8), (4, y, -8), "wing")
    b[0, 13, -9] = "glow_core"
    head = {}
    a.ell(head, (0, 0, 0), (4, 5, 4), "light")
    face(head, 3, -4, 0)
    a.box(head, (-1, 3, -5), (1, 5, -4), "glow_eye")
    a.box(head, (-4, 4, -2), (4, 6, 3), "base")
    for s in (-1, 1):
        a.polygon(head, [(s * 3, 5), (s * 6, 4), (s * 7, -4), (s * 4, -5)], -1, 3, "wing")
        for y in (-3, -1, 1, 3):
            a.line(head, (s * 4, y, -2), (s * 6, y, -2), "light")
    a.line(head, (0, 5, 0), (0, 9, 0), "glow_core", 2)
    a.line(head, (-2, 7, 0), (2, 7, 0), "bone")
    attach(parts, limbs, "head", head, (0, 21, -5), "sway")
    walking_legs(parts, limbs, (-5, 5), 4, 6)
    for s, label in ((-1, "l"), (1, "r")):
        wing = {}
        # Folded feathers point backwards, leaving the divine face unobscured.
        for z in range(9):
            top = 7 - z // 2
            a.box(wing, (min(0, s * 3), 0, z), (max(0, s * 3) + 1, top, z + 1), "wing")
            a.line(wing, (s * 3, 1, z), (s * 3, top, z), "light" if z % 2 else "glow_core")
        attach(parts, limbs, "wing_" + label, wing, (s * 5, 12, -2), "wing", s)
    chain(parts, limbs, "tail", [(0, 8, 7), (2, 7, 10), (4, 8, 12), (5, 10, 13)], 1.4, fin=True)
    return b, parts, limbs, (0, 24, -10), dict(flap_rate=.8)


def crab():
    b, parts, limbs = {}, {}, {}
    a.ell(b, (0, 6, 1), (7, 4, 5), "accent")
    a.ell(b, (0, 8, 2), (6, 2, 4), "base")
    for x, z, r in ((-3, 1, 2), (2, 2, 2), (0, 4, 1)):
        a.ell(b, (x, 10, z), (r, 2, r), "bone")
        b[x, 11, z] = "shade"
    for s, label in ((-1, "l"), (1, "r")):
        eye = {}
        a.line(eye, (0, 0, 0), (s, 3, -1), "accent", 2)
        a.ell(eye, (s, 3, -1), (2, 2, 2), "bone")
        a.box(eye, (s - 1, 3, -3), (s + 1, 5, -2), "dark")
        eye[s, 4, -4] = "glow_eye"
        attach(parts, limbs, "eyestalk_" + label, eye, (s * 3, 7, -3), "sway")
        claw = {}
        a.line(claw, (0, 0, 0), (s * 3, 1, -2), "accent", 2)
        a.ell(claw, (s * 4, 2, -4), (3, 3, 3), "accent")
        for x in (-2, 2):
            a.line(claw, (s * 4 + x, 2, -5), (s * 4 + x, 3, -8), "bone", 2)
        attach(parts, limbs, "claw_" + label, claw, (s * 5, 5, -2), "claw", s)
    a.line(b, (-2, 5, -4), (2, 5, -4), "dark")
    b[-2, 6, -4] = b[2, 6, -4] = "bone"
    walking_legs(parts, limbs, (-1, 2, 4), 6, 4, True)
    return b, parts, limbs, (0, 7, -6), {}


def siren():
    b, parts, limbs = {}, {}, {}
    # A rising foam spiral supports the mermaid's narrowing fish body.
    for i in range(56):
        t = i / 55
        angle = t * math.tau * 1.5
        radius = 7 - 4 * t
        center = (round(math.cos(angle) * radius), round(1 + t * 6), round(math.sin(angle) * radius))
        a.ell(b, center, (2, 2, 2), "glow_core" if i % 9 else "glow_eye")
    a.ell(b, (0, 9, 0), (3, 5, 3), "glow_core")
    a.ell(b, (0, 15, 0), (3, 4, 2), "belly")
    a.box(b, (-3, 14, -2), (3, 16, -1), "accent")
    head = {}
    a.ell(head, (0, 0, 0), (4, 4, 3), "bone")
    a.ell(head, (0, 2, 1), (4, 3, 3), "glow_core")
    face(head, 3, -3, 0)
    a.box(head, (-1, -2, -3), (1, -1, -2), "dark")
    attach(parts, limbs, "head", head, (0, 21, 0), "head")
    for s, label in ((-1, "l"), (1, "r")):
        hair = {}
        a.line(hair, (0, 0, 0), (s * 2, -4, 2), "glow_core", 2)
        a.line(hair, (s * 2, -4, 2), (s * 3, -7, 1), "glow_eye", 2)
        attach(parts, limbs, "hair_" + label, hair, (s * 3, 1, 1), "cloth", s, parent_limb="head")
        fin = {}
        a.polygon(fin, [(0, 0), (s * 7, 3), (s * 5, -3), (s * 2, -5)], 0, 1, "glow_core")
        a.line(fin, (0, 0, -1), (s * 6, 2, -1), "glow_eye")
        attach(parts, limbs, "fin_" + label, fin, (s * 2, 8, 0), "cloth", s)
        arm = {}
        a.line(arm, (0, 0, 0), (s * 2, -4, -1), "belly", 2)
        a.ell(arm, (s * 2, -4, -1), (2, 2, 2), "glow_eye")
        attach(parts, limbs, "arm_" + label, arm, (s * 3, 17, 0), "arm", s)
    return b, parts, limbs, (0, 20, -4), dict(animation_style="cantor", glow_strength=2.8)


def kelp():
    b, parts, limbs = {}, {}, {}
    a.ell(b, (0, 7, 0), (7, 7, 6), "shade")
    a.ell(b, (0, 10, 0), (6, 5, 5), "wing")
    for x, z in ((-5, 0), (-3, 3), (1, 4), (4, 1), (3, -3), (-3, -3)):
        a.line(b, (x, 5, z), (x, 14, z), "wing", 2)
        a.line(b, (x, 14, z), (x + 1, 17, z + 1), "belly")
    eye = {}
    a.ell(eye, (0, 0, 0), (4, 4, 2), "dark")
    a.ell(eye, (0, 0, -1), (3, 3, 2), "glow_eye")
    a.box(eye, (-1, -2, -3), (1, 2, -2), "dark")
    eye[-1, 1, -4] = "bone"
    attach(parts, limbs, "head", eye, (0, 10, -5), "head")
    for s, label in ((-1, "l"), (1, "r")):
        for j, z in enumerate((-3, 3)):
            chain(parts, limbs, f"tentacle_{label}_{j}", [(s * 5, 6, z),
                  (s * 8, 3, z + 1), (s * 10, 2, z + 3),
                  (s * 12, 4, z + 5)], 1.6, "wing", True)
    return b, parts, limbs, (0, 10, -9), dict(animation_style="cantor")


def herald():
    b, parts, limbs = {}, {}, {}
    a.ell(b, (0, 12, -4), (4, 8, 4), "base")
    a.ell(b, (0, 15, -6), (3, 5, 2), "belly")
    # Priestly stole and pearl fastenings sit on the serpent's chest.
    for s in (-1, 1):
        a.line(b, (s * 3, 18, -7), (s * 2, 8, -7), "bone", 2)
        for y in (10, 14, 18):
            b[s * 3, y, -8] = "glow_core"
    head = {}
    a.ell(head, (0, 0, 0), (4, 4, 4), "base")
    a.ell(head, (0, -1, -3), (3, 2, 3), "belly")
    face(head, 3, -4, 0)
    # Coral antlers branch upward around a floating-looking central pearl.
    for s in (-1, 1):
        a.line(head, (s * 2, 3, 0), (s * 4, 7, 0), "accent", 2)
        a.line(head, (s * 4, 6, 0), (s * 6, 8, 1), "accent")
        a.line(head, (s * 3, 5, 0), (s, 7, -1), "accent")
        head[s * 6, 8, 1] = "glow_eye"
    a.ell(head, (0, 6, 0), (2, 2, 2), "glow_eye")
    attach(parts, limbs, "head", head, (0, 22, -5), "head")
    jaw = {}
    a.box(jaw, (-2, -1, -3), (2, 1, 1), "bone")
    attach(parts, limbs, "jaw", jaw, (0, -3, -2), "jaw", parent_limb="head")
    for s, label in ((-1, "l"), (1, "r")):
        arm = {}
        a.line(arm, (0, 0, 0), (s * 3, -4, -1), "base", 2)
        a.line(arm, (s * 3, -4, -1), (s * 4, -3, -3), "belly", 2)
        if s == 1:
            a.line(arm, (4, -13, -3), (4, 7, -3), "wing", 2)
            for dx in (-2, 2):
                a.line(arm, (4, 5, -3), (4 + dx, 9, -3), "accent")
            a.ell(arm, (4, 9, -3), (3, 3, 3), "glow_eye")
            arm[3, 10, -6] = "bone"
        attach(parts, limbs, "arm_" + label, arm, (s * 4, 17, -4), "arm", s)
    # Ten jointed sections form a complete broad coil and curling finned tip.
    chain(parts, limbs, "tail", [(0, 5, -2), (4, 4, 0), (7, 3, 3),
          (8, 3, 7), (5, 3, 10), (0, 3, 11), (-5, 3, 9),
          (-8, 3, 5), (-8, 4, 1), (-6, 5, -2), (-4, 6, -1)], 2.6, fin=True)
    return b, parts, limbs, (4, 9, -3), dict(animation_style="cantor", hand_limb="arm_r", glow_strength=1.7)


DEFINITIONS = [
    ("honey_mite", "Honey Mite", "Amberfall", .7, "dart", "Swarms in quick darts.", lambda: beetle(False)),
    ("amber_scarab", "Amber Scarab", "Amberfall", 1.3, "strafe", "Armored strafing beetle.", lambda: beetle(True)),
    ("dune_drake", "Dune Drake", "Amberfall", 2.6, "chase", "Four-legged pursuit with ember throat.", drake),
    ("amber_sphinx", "The Amber Sphinx", "Amberfall", 4.5, "stationary", "God guarding the ruins.", sphinx),
    ("surf_crab", "Surf Crab", "Tidewell", .9, "skirmish", "Skirmishes with snapping claws.", crab),
    ("tide_siren", "Tide Siren", "Tidewell", 1.6, "strafe", "Sings needle bursts while strafing.", siren),
    ("kelp_horror", "Kelp Horror", "Tidewell", 2.2, "stationary", "Sits at the shore with swaying tentacles.", kelp),
    ("leviathan_herald", "The Leviathan Herald", "Tidewell", 4., "strafe", "Serpent priest god with a pearl staff.", herald),
]


def assemble(body, parts, limbs):
    full, origins = dict(body), {}
    for name, spec in limbs.items():
        parent = spec.get("parent_limb")
        assert not parent or parent in origins, "Parents must precede their children"
        origin = tuple(p + q for p, q in zip(spec["pivot"], origins.get(parent, (0, 0, 0))))
        origins[name] = origin
        for p, color in parts[spec["part"]].items():
            full[tuple(p[k] + origin[k] for k in range(3))] = color
    return full


def read_vox(path):
    data = path.read_bytes()
    assert data[:8] == b"VOX " + struct.pack("<I", 150), path
    assert data[8:12] == b"MAIN" and struct.unpack_from("<I", data, 16)[0] == len(data) - 20, path
    offset, size, points = 20, None, None
    while offset < len(data):
        tag, length, children = struct.unpack_from("<4sII", data, offset)
        start = offset + 12
        assert children == 0 and start + length <= len(data), path
        if tag == b"SIZE":
            size = struct.unpack_from("<III", data, start)
        if tag == b"XYZI":
            count = struct.unpack_from("<I", data, start)[0]
            assert length == 4 + count * 4, path
            points = [tuple(data[p:p + 4]) for p in range(start + 4, start + length, 4)]
        offset = start + length
    assert size and points and all(0 < d <= 256 for d in size), path
    assert all(all(p[k] < size[k] for k in range(3)) and p[3] for p in points), path
    assert len({p[:3] for p in points}) == len(points), path
    return size, points


def validate(folder, height):
    rig = json.loads((folder / "rig.json").read_text())
    geometries = {}
    for name, info in rig["parts"].items():
        points = {}
        for suffix, present in (("", info.get("solid", True)), ("_glow", info.get("glow", False))):
            if not present:
                continue
            path = folder / (name + suffix + ".vox")
            size, cells = read_vox(path)
            assert size == tuple(info["frame_size"][k] for k in (2, 0, 1)), path
            lo = info["frame_min"]
            decoded = {(p[1] + lo[0], p[2] + lo[1], p[0] + lo[2]): p[3] for p in cells}
            assert not points.keys() & decoded.keys(), "Glow must not duplicate solid cells"
            points.update(decoded)
        assert points, name
        geometries[name] = points
    assert set(geometries) == {"body"} | {s["part"] for s in rig["limbs"].values()}
    full = assemble(geometries["body"], geometries, rig["limbs"])
    lo, size = a.bounds(full)
    assert math.isclose(size[1] * rig["voxel_size"], height, abs_tol=1e-9)
    assert all(-16 <= x < 16 and 0 <= y < 32 and -16 <= z < 16 for x, y, z in full)
    assert any(info.get("glow") for info in rig["parts"].values())
    for spec in rig["limbs"].values():
        if spec["role"] == "tail_chain":
            assert 0 <= spec["segment"] < spec["segments"]
            if spec["segment"]:
                previous = rig["limbs"][spec["parent_limb"]]
                assert previous["segment"] == spec["segment"] - 1
                assert tuple(spec["pivot"]) in geometries[previous["part"]]
            assert (0, 0, 0) in geometries[spec["part"]]
    return rig


def projectiles():
    comet = {}
    a.ell(comet, (0, 0, -1), (3, 3, 4), "glow_core")
    a.ell(comet, (-1, 1, -3), (1.5, 1.5, 1.5), "glow_eye")
    a.line(comet, (0, 0, 2), (0, 1, 6), "glow_core", 2)
    a.line(comet, (0, 1, 6), (0, 2, 9), "glow_core")
    comet[-2, -1, 0] = "light"
    pearl = {}
    a.ell(pearl, (0, 0, 0), (4, 4, 4), "glow_core")
    a.ell(pearl, (-1, 1, -2), (2, 2, 2), "glow_eye")
    for x, y, z in ((-5, 0, 0), (5, 0, 0), (0, 5, 0), (0, -5, 0)):
        pearl[x, y, z] = "glow_eye"
    for name, theme, v in (("honey_comet", "amberfall", comet), ("tide_pearl", "tidewell", pearl)):
        assert sum(c.startswith("glow") for c in v.values()) / len(v) > .9
        a.projectile(name, theme, v, .012)
        read_vox(R / "creatures/boss_projectiles" / name / "model.vox")


def main():
    targets = [R / "creatures" / d[0] for d in DEFINITIONS]
    targets += [R / "creatures/boss_projectiles" / name for name in SHOTS]
    existing = [str(p.relative_to(R)) for p in [*targets, MANIFEST] if p.exists()]
    if existing:
        raise SystemExit("Create-only generator refuses existing outputs: " + ", ".join(existing))
    authored = []
    # Fully check coarse geometry before creating any output folder.
    for name, title, biome, height, behavior, notes, factory in DEFINITIONS:
        body, parts, limbs, hand, settings = factory()
        full = assemble(body, parts, limbs)
        # Ground each model, preserving all parent-relative articulation.
        bottom = min(p[1] for p in full)
        if bottom:
            body = {(x, y - bottom, z): c for (x, y, z), c in body.items()}
            for spec in limbs.values():
                if not spec.get("parent_limb"):
                    spec["pivot"][1] -= bottom
            if not settings.get("hand_limb"):
                hand = (hand[0], hand[1] - bottom, hand[2])
            full = assemble(body, parts, limbs)
        assert all(-16 <= x < 16 and 0 <= y < 32 and -16 <= z < 16 for x, y, z in full), (name, a.bounds(full))
        assert all(v and all(c in a.PAL[biome.lower()] for c in v.values()) for v in [body, *parts.values()])
        unit = height / a.bounds(full)[1][1]
        authored.append((body, parts, limbs, hand, settings, unit))
    records = []
    for definition, data in zip(DEFINITIONS, authored):
        name, title, biome, height, behavior, notes, _ = definition
        body, parts, limbs, hand, settings, unit = data
        small(name, biome.lower(), body, parts, limbs, unit)
        folder = R / "creatures" / name
        path = folder / "rig.json"
        rig = json.loads(path.read_text())
        rig.update(hand=list(hand), bob=.018, waddle=.06, pixel_art=True,
                   material_jitter=0., glow_strength=1.4)
        rig.update(settings)
        path.write_text(json.dumps(rig, indent=2) + "\n")
        rig = validate(folder, height)
        records.append(dict(id=name, display_name=title, biome=biome,
            folder="creatures/" + name, status="live", height_m=height,
            voxel_size=unit, parts=list(rig["parts"]), behavior=behavior,
            behavior_notes=notes, god=name in ("amber_sphinx", "leviathan_herald"),
            glow=name == "tide_siren", design_grid=[32, 32, 32],
            projectile="honey_comet" if biome == "Amberfall" else "tide_pearl"))
    projectiles()
    MANIFEST.write_text(json.dumps(records, indent=2) + "\n")
    assert {r["id"] for r in json.loads(MANIFEST.read_text())} == {d[0] for d in DEFINITIONS}
    for target in [*targets, MANIFEST, Path(__file__)]:
        for path in ([target] if target.is_file() else target.rglob("*")):
            if path.suffix in (".json", ".py"):
                assert all(chr(code) not in path.read_text() for code in (0x00B7, 0x2022))
    print("Validated eight creature rigs, exact authored heights, all VOX parts and two projectiles.")
    for record in records:
        print(f"{record['id']}: {len(record['parts'])} parts, {record['height_m']} m, voxel_size={record['voxel_size']:.9f}")


if __name__ == "__main__":
    main()
