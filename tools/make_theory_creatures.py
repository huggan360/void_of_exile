#!/usr/bin/env python3
"""Create the Theory of Everything cast without replacing existing project files.

Forward is -Z, Y is up. Author all geometry and local pivots in coarse cells.
The queen uses the existing exposed-surface x8 writer and editable 32-grid rig.
Run once from any directory; remove generated files explicitly before rebuilding.
"""
import ast
import json
import math
import struct
import sys
from pathlib import Path

# Importing the shared writer must not create cache files beside existing tools.
sys.dont_write_bytecode = True
import redesign_pixel_bosses as a

R = Path(__file__).resolve().parents[1]
IDS = ("hull_skitter", "vent_stalker", "gloom_spitter", "void_lamprey",
       "crest_brute", "void_empress")
SHOTS = ("acid_glob", "void_spine")
MANIFEST = R / "creatures/theory_creatures_manifest.json"
a.PAL["xeno"] = dict(
    base=(20, 18, 30), light=(62, 58, 86), shade=(10, 9, 16),
    dark=(4, 4, 8), belly=(38, 34, 52), bone=(150, 146, 128),
    wing=(28, 22, 40), accent=(70, 46, 96),
    glow_eye=(125, 255, 106), glow_core=(255, 95, 210),
)

# Load only the established rig helpers, as make_blue_creatures.py does.
source = ast.parse((R / "tools/make_court_creatures.py").read_text())
for node in source.body:
    if isinstance(node, ast.FunctionDef) and node.name in ("small", "boss"):
        exec(compile(ast.Module(body=[node], type_ignores=[]), "court_rig_helpers", "exec"))

# save() has a literal theme-to-biome dictionary. Extend its in-memory AST only.
# Geometry, glow splitting, local parent pivots, masters and poses stay unchanged.
writer_source = ast.parse((R / "tools/redesign_pixel_bosses.py").read_text())
save_node = next(n for n in writer_source.body
                 if isinstance(n, ast.FunctionDef) and n.name == "save")
theme_tables = [n for n in ast.walk(save_node) if isinstance(n, ast.Dict)
                and any(isinstance(k, ast.Constant) and k.value == "blue" for k in n.keys)]
assert len(theme_tables) == 1, "The shared save theme lookup changed"
theme_tables[0].keys.append(ast.Constant("xeno"))
theme_tables[0].values.append(ast.Constant("Theory of Everything"))
module = ast.fix_missing_locations(ast.Module(body=[save_node], type_ignores=[]))
exec(compile(module, "theory_boss_writer", "exec"), a.__dict__)


def joint(part, pivot, role, phase=1, **extra):
    """Use the common limb schema, retaining coarse pivots until boss export."""
    spec = a.limb(part, pivot, role, phase, throws=False, **extra)
    spec["pivot"] = list(pivot)
    return spec


def mirror(v):
    return {(-x, y, z): c for (x, y, z), c in v.items()}


def ribs(v, levels, width, front, back):
    """Broken curved ribs reveal a recessed black sternum."""
    for y in levels:
        for s in (-1, 1):
            a.line(v, (s, y, front), (s * width, y + 1, front + 1), "belly")
            a.line(v, (s * width, y + 1, front + 1),
                   (s * width, y + 1, back), "belly")
        v[0, y, front] = "dark"


def dome(width=3, length=7):
    """Smooth swept skull, narrow face and one controlled wet highlight."""
    v = {}
    a.ell(v, (0, 1, 1), (width, 3, length), "base")
    a.ell(v, (0, 2, 2), (max(1, width - 1), 2, length - 1), "shade")
    a.line(v, (-1, 3, -1), (-1, 3, length - 2), "light")
    a.box(v, (-2, -1, -length + 1), (2, 1, -length + 3), "dark")
    for s in (-1, 1):
        v[s, 1, -length + 1] = "glow_eye"
        a.line(v, (s, -1, -length + 1), (s, -2, -length + 1), "bone")
    return v


def inner_jaw(length=5):
    v = {}
    a.line(v, (0, 0, 0), (0, 0, -length + 1), "belly")
    a.box(v, (-1, -1, -length), (2, 1, -length + 1), "dark")
    v[-1, 0, -length] = "bone"
    v[1, 0, -length] = "bone"
    return v


def tail(parts, limbs, count, root, length, radius, kind="blade"):
    """Unbent chain: every centerline begins at zero and ends at local +Z."""
    for i in range(count):
        name = f"tail_{i}"
        start = radius + (0.5 - radius) * i / count
        end = radius + (0.5 - radius) * (i + 1) / count
        v = {}
        for z in range(length):
            r = start + (end - start) * z / max(1, length - 1)
            for x in range(-math.ceil(r), math.ceil(r) + 1):
                for y in range(-math.ceil(r), math.ceil(r) + 1):
                    if x * x + y * y <= r * r:
                        v[x, y, z] = "base" if y >= 0 else "shade"
            v[0, 0, z] = "base"
        # Raised joint collars and dorsal sheen keep segmentation visible.
        v[0, math.floor(start), 0] = "belly"
        if start >= 1:
            v[0, math.floor(start), length - 1] = "accent"
        if kind == "plated" and i < count - 1:
            a.line(v, (-math.floor(start), 0, 0),
                   (math.floor(start), 0, 0), "belly")
        if kind == "eel":
            a.polygon(v, [(0, 0), (0, 3), (1, 1), (1, 0)],
                      0, length, "wing")
            v[0, 2, 0] = "accent"
        if i == count - 1:
            # Lateral blades keep the endpoint at exactly length cells.
            reach = 4 if kind == "queen" else 3 if kind == "plated" else 2
            a.polygon(v, [(-reach, 0), (-1, 2), (0, 3 if kind == "queen" else 2),
                          (reach, 0), (1, -1), (0, -2)],
                      max(0, length - 2), length, "base")
            a.line(v, (0, 0, length - 1), (reach - 1, 0, length - 1),
                   "glow_core" if kind in ("queen", "eel") else "glow_eye")
            if kind == "queen":
                a.line(v, (-3, 0, length - 1), (0, 2, length - 1), "glow_core")
                a.line(v, (0, 2, length - 1), (3, 0, length - 1), "glow_core")
        parts[name] = v
        extra = dict(segment=i, segments=count)
        if i:
            extra["parent_limb"] = f"tail_{i - 1}"
        limbs[name] = joint(name, root if i == 0 else (0, 0, length),
                            "tail_chain", 1, **extra)


def skitter():
    b = {}
    a.ell(b, (0, 5, 0), (4, 3, 5), "base")
    a.ell(b, (0, 6, 1), (3, 2, 4), "shade")
    a.line(b, (-1, 7, -1), (-1, 7, 3), "light")
    a.line(b, (0, 8, 0), (0, 8, 2), "accent")
    a.box(b, (-2, 4, -5), (2, 6, -4), "dark")
    for x, y in ((-2, 5), (0, 5), (2, 5), (-1, 4), (1, 4)):
        b[x, y, -5] = "glow_eye"
    for s in (-1, 1):
        a.line(b, (s, 3, -4), (s * 2, 3, -6), "bone")
    parts, limbs = {}, {}
    for s, label in ((-1, "l"), (1, "r")):
        for i, z in enumerate((-3, 0, 3)):
            v = {}
            spread = (-2, 0, 2)[i]
            a.line(v, (0, 0, 0), (s * 3, 0, spread), "base")
            a.line(v, (s * 3, 0, spread), (s * 5, -3, spread - 1), "base")
            v[s * 5, -4, spread - 2] = "bone"
            v[s * 3, 0, spread] = "light"
            name = f"leg_{label}_{i}"
            parts[name] = v
            limbs[name] = joint(name, (s * 3, 4, z), "leg", s * (-1) ** i)
    tail(parts, limbs, 5, (0, 4, 4), 3, 1.3)
    return b, parts, limbs, (0, 4, -6)


def stalker():
    b = {}
    a.ell(b, (0, 15, 0), (3, 5, 3), "base")
    a.ell(b, (0, 11, 1), (3, 2, 3), "shade")
    a.line(b, (0, 16, 0), (0, 22, -2), "base", 2)
    ribs(b, (12, 14, 16, 18), 3, -3, 2)
    for y in (13, 16, 19):
        a.line(b, (0, y, 2), (0, y + 2, 5), "base")
        b[0, y + 2, 5] = "accent"
    parts = dict(head=dome(3, 7), jaw=inner_jaw(3))
    limbs = dict(head=joint("head", (0, 22, -2), "head"),
                 jaw=joint("jaw", (0, -1, -5), "jaw", parent_limb="head"))
    for s, label in ((-1, "l"), (1, "r")):
        leg = {}
        a.line(leg, (0, 0, 0), (s, -5, 3), "base", 2)
        a.line(leg, (s, -5, 3), (s * 2, -9, 1), "base")
        a.line(leg, (s * 2, -9, 1), (s * 2, -11, -3), "base")
        for x in (s, s * 3):
            leg[x, -12, -3] = "bone"
        arm = {}
        a.line(arm, (0, 0, 0), (s * 2, -5, 1), "base")
        a.line(arm, (s * 2, -5, 1), (s * 2, -10, -2), "base")
        arm[s * 2, -5, 0] = "light"
        for x in (-1, 0, 1):
            a.line(arm, (s * 2, -10, -2), (s * 2 + x, -12, -4), "bone")
        for name, v, pivot, role in ((f"leg_{label}", leg, (s * 2, 12, 0), "leg"),
                                     (f"arm_{label}", arm, (s * 3, 18, 0), "arm")):
            parts[name] = v
            limbs[name] = joint(name, pivot, role, s)
    tail(parts, limbs, 7, (0, 11, 3), 3, 1.6)
    return b, parts, limbs, (0, 21, -10)


def spitter():
    b = {}
    a.ell(b, (0, 10, 1), (5, 5, 6), "base")
    a.ell(b, (0, 13, 2), (4, 3, 4), "shade")
    ribs(b, (7, 9, 11), 4, -4, 3)
    for z in (0, 3, 5):
        a.line(b, (0, 14, z), (0, 18, z + 1), "base")
        b[0, 18, z + 1] = "accent"
    head = dome(4, 4)
    a.ell(head, (0, -2, -2), (3, 3, 3), "glow_eye")
    # Dark vascular bands divide the swollen luminous throat.
    for x in (-2, 1):
        a.line(head, (x, -4, -3), (x, -1, -5), "belly")
    a.polygon(head, [(-2, 2), (0, 7), (2, 2)], 0, 3, "base")
    a.line(head, (0, 3, 1), (0, 6, 1), "accent")
    jaw = {}
    for s in (-1, 1):
        a.line(jaw, (s, 0, 0), (s * 4, -1, -2), "base")
        a.line(jaw, (s * 4, -1, -2), (s * 2, 0, -5), "bone")
    parts = dict(head=head, jaw=jaw)
    limbs = dict(head=joint("head", (0, 12, -5), "head"),
                 jaw=joint("jaw", (0, 0, -3), "jaw", parent_limb="head"))
    for s, label in ((-1, "l"), (1, "r")):
        for i, z in enumerate((-3, 4)):
            leg = {}
            a.line(leg, (0, 0, 0), (s * 3, -3, 1), "base", 2)
            a.line(leg, (s * 3, -3, 1), (s * 3, -7, -1), "base")
            a.line(leg, (s * 3, -7, -1), (s * 3, -8, -3), "bone")
            name = f"leg_{label}_{i}"
            parts[name] = leg
            limbs[name] = joint(name, (s * 4, 8, z), "leg", s * (-1) ** i)
    tail(parts, limbs, 6, (0, 8, 6), 4, 1.8)
    return b, parts, limbs, (0, 12, -13)


def lamprey():
    b = {}
    a.ell(b, (0, 7, 0), (3, 4, 4), "base")
    ribs(b, (5, 7, 9), 3, -3, 2)
    # Tall dorsal ridge and small lateral fins belong to the short front trunk.
    a.polygon(b, [(0, 9), (0, 14), (2, 10), (2, 8)], -1, 3, "wing")
    a.line(b, (0, 11, 0), (0, 13, 0), "accent")
    for s in (-1, 1):
        a.line(b, (s * 2, 7, 0), (s * 6, 4, 2), "wing")
    head = {}
    a.ell(head, (0, 0, 0), (4, 4, 3), "base")
    # A true annulus with a black central tunnel, viewed from -Z.
    for x in range(-4, 5):
        for y in range(-4, 5):
            r2 = x * x + y * y
            if r2 <= 13:
                head[x, y, -3] = "dark" if r2 < 6 else "glow_core"
    for x, y in ((-2, 0), (2, 0), (0, -2), (0, 2)):
        head[x, y, -4] = "bone"
    for s in (-1, 1):
        head[s * 3, 2, -2] = "glow_eye"
    parts = dict(head=head, jaw=inner_jaw(2))
    limbs = dict(head=joint("head", (0, 7, -3), "head"),
                 jaw=joint("jaw", (0, 0, -3), "jaw", parent_limb="head"))
    tail(parts, limbs, 8, (0, 7, 3), 3, 2.3, "eel")
    return b, parts, limbs, (0, 7, -8)


def brute():
    b = {}
    a.ell(b, (0, 16, 0), (6, 7, 5), "base")
    a.ell(b, (0, 11, 2), (5, 4, 4), "shade")
    ribs(b, (12, 15, 18), 5, -5, 3)
    for y in (13, 17, 21):
        a.box(b, (-3, y, 4), (3, y + 1, 6), "belly")
    head = dome(4, 5)
    a.polygon(head, [(-10, 2), (-9, 6), (-4, 8), (4, 8), (9, 6),
                     (10, 2), (5, 0), (-5, 0)], 0, 4, "base")
    a.line(head, (-8, 5, -1), (8, 5, -1), "light")
    for x in (-7, -3, 3, 7):
        a.line(head, (x, 2, -1), (x, 5, -1), "accent")
    parts = dict(head=head, jaw=inner_jaw(3))
    limbs = dict(head=joint("head", (0, 23, -2), "head"),
                 jaw=joint("jaw", (0, -1, -3), "jaw", parent_limb="head"))
    for s, label in ((-1, "l"), (1, "r")):
        leg = {}
        a.line(leg, (0, 0, 0), (s, -5, 2), "base", 2)
        a.line(leg, (s, -5, 2), (s * 2, -9, 0), "base", 2)
        a.box(leg, (min(s, s * 3), -10, -3), (max(s, s * 3) + 1, -8, 2), "base")
        arm = {}
        a.line(arm, (0, 0, 0), (s * 3, -4, 1), "base", 2)
        a.ell(arm, (s * 3, -7, 0), (3, 5, 3), "base")
        a.box(arm, (s * 3 - 2, -8, -3), (s * 3 + 2, -6, -2), "belly")
        for x in (-1, 1):
            a.line(arm, (s * 3 + x, -10, -1), (s * 3 + x, -12, -3), "bone")
        for name, v, pivot, role in ((f"leg_{label}", leg, (s * 3, 10, 1), "leg"),
                                     (f"arm_{label}", arm, (s * 5, 20, 0), "arm")):
            parts[name] = v
            limbs[name] = joint(name, pivot, role, s)
    tail(parts, limbs, 6, (0, 10, 5), 3, 2.6, "plated")
    return b, parts, limbs, (0, 22, -9)


def empress():
    # The complete resting pose fits the shared 32-cell editor canvas. A 20-cell
    # tail is twice the trunk length, laid straight behind the raised rear sac.
    b = {}
    a.ell(b, (0, 17, -9), (5, 7, 4), "base")
    a.ell(b, (0, 10, -8), (5, 4, 4), "shade")
    a.ell(b, (0, 10, -6), (4, 3, 2), "wing")
    a.line(b, (0, 20, -9), (0, 25, -9), "base", 2)
    ribs(b, (13, 15, 17, 19, 21), 4, -13, -6)
    for z in (-9, -7, -5):
        a.line(b, (-3, 9, z), (3, 9, z), "belly")
    # Sparse violet seam cells become pink fissures in the brood variant.
    for y in (14, 17, 20):
        a.line(b, (0, y, -5), (0, y + 2, -3), "base")
        b[0, y + 2, -3] = "accent"
    b[0, 21, -13] = "glow_core"
    head = {}
    a.ell(head, (0, 0, -1), (3, 3, 5), "base")
    a.line(head, (-1, 2, -3), (-1, 2, 2), "light")
    # Huge fan crown: an outer saw-toothed shell with a narrow raised neck.
    crown = [(-3, 0), (-8, 1), (-14, 6), (-10, 5), (-10, 7),
             (-6, 5), (-4, 8), (-2, 5), (0, 8), (2, 5), (4, 8),
             (6, 5), (10, 7), (10, 5), (14, 6), (8, 1), (3, 0)]
    a.polygon(head, crown, 1, 4, "base")
    for s in (-1, 1):
        for x, y in ((4, 6), (9, 5), (12, 5)):
            a.line(head, (s * 2, 1, 0), (s * x, y, 0), "belly")
            head[s * x, y, 0] = "accent"
        a.box(head, (s * 2, -1, -6), (s * 2 + 1, 0, -5), "glow_eye")
        head[s, -2, -6] = "bone"
    a.box(head, (-1, -2, -6), (2, -1, -5), "dark")
    parts = dict(head=head, jaw=inner_jaw(2))
    limbs = dict(head=joint("head", (0, 24, -9), "head"),
                 jaw=joint("jaw", (0, -2, -5), "jaw", parent_limb="head"))
    for s, label in ((-1, "l"), (1, "r")):
        arm = {}
        a.line(arm, (0, 0, 0), (s * 5, -4, 1), "base", 2)
        a.line(arm, (s * 5, -4, 1), (s * 6, -9, -1), "base", 2)
        a.polygon(arm, [(s * 6, -7), (s * 8, -10), (s * 6, -16),
                        (s * 5, -11)], -3, -1, "base")
        a.line(arm, (s * 6, -11, -4), (s * 6, -15, -4), "bone")
        arm[s * 5, -4, 0] = "light"
        little = {}
        a.line(little, (0, 0, 0), (s * 2, -3, -1), "base")
        a.line(little, (s * 2, -3, -1), (s, -4, -3), "bone")
        parts[f"arm_{label}"] = arm
        limbs[f"arm_{label}"] = joint(f"arm_{label}", (s * 5, 21, -8), "arm", s)
        parts[f"chest_arm_{label}"] = little
        limbs[f"chest_arm_{label}"] = joint(f"chest_arm_{label}", (s * 3, 17, -12), "arm", -s)
        for i, z in enumerate((-10, -5)):
            upper = {}
            a.line(upper, (0, 0, 0), (s * 3, -3, 1), "base", 2)
            a.line(upper, (s * 3, -3, 1), (s * 4, -7, 2), "base")
            lower = {}
            a.line(lower, (0, 0, 0), (s, -4, -1), "base")
            a.line(lower, (s, -4, -1), (s, -6, -3), "base")
            a.line(lower, (s, -6, -3), (s, -7, -4), "bone")
            name = f"leg_{label}_{i}"
            parts[name] = upper
            parts[name + "_lower"] = lower
            limbs[name] = joint(name, (s * 4, 14, z), "leg", s * (-1) ** i)
            limbs[name + "_lower"] = joint(name + "_lower", (s * 4, -7, 2),
                                           "knee", s * (-1) ** i, parent_limb=name)
    tail(parts, limbs, 10, (0, 10, -4), 2, 2.5, "queen")
    variants = {}
    for form, colors in (("brood", {"accent": "glow_core"}),
                         ("unmade", {"accent": "glow_core", "belly": "glow_core", "wing": "belly"})):
        cracked = a.recolor(b, colors)
        if form == "unmade":
            # Open a branching fissure through the remaining chest shell.
            for y in range(12, 22):
                x = (y // 2) % 3 - 1
                for z in range(-13, -10):
                    if (x, y, z) in cracked:
                        cracked[x, y, z] = "glow_core"
        parts["body_" + form] = cracked
        parts["head_" + form] = a.recolor(head, colors)
        variants[form] = dict(body="body_" + form, head="head_" + form)
    return b, parts, limbs, (0, 22, -16), variants


def assemble(body, parts, limbs, swaps=None):
    """Compose a coarse resting pose using the same local-parent convention."""
    swaps = swaps or {}
    geometries = {"body": body, **parts}
    full = dict(geometries[swaps.get("body", "body")])
    for spec in limbs.values():
        pivot = list(spec["pivot"])
        ancestor = spec.get("parent_limb")
        seen = set()
        while ancestor:
            assert ancestor not in seen, "Cyclic limb hierarchy"
            seen.add(ancestor)
            parent = limbs[ancestor]
            pivot = [p + q for p, q in zip(pivot, parent["pivot"])]
            ancestor = parent.get("parent_limb")
        for (x, y, z), c in geometries[swaps.get(spec["part"], spec["part"])].items():
            full[x + pivot[0], y + pivot[1], z + pivot[2]] = c
    return full


def projectiles():
    v = {}
    a.ell(v, (0, 0, 0), (3, 3, 4), "glow_eye")
    for center in ((-2, -1, 1), (2, 1, 0), (1, -2, 2)):
        a.ell(v, center, (2, 2, 2), "glow_eye")
    a.ell(v, (0, 0, -2), (2, 2, 2), "belly")
    a.line(v, (0, -1, 2), (0, -2, 6), "glow_eye")
    v[0, -3, 6] = "glow_eye"
    a.projectile("acid_glob", "xeno", v, .012)
    v = {}
    a.line(v, (0, 0, -8), (0, 0, 6), "base")
    a.box(v, (-1, -1, -3), (2, 1, 5), "base")
    a.line(v, (0, 0, -7), (0, 0, 5), "glow_core")
    v[0, 0, -8] = "bone"
    for z in (-2, 2, 5):
        for s in (-1, 1):
            a.line(v, (0, 0, z - 2), (s * 3, 0, z + 1), "base")
            v[s * 2, 0, z] = "glow_core"
    a.projectile("void_spine", "xeno", v, .010)


def read_vox(path):
    """Validate the helper's VOX chunk framing and return engine-space voxels."""
    data = path.read_bytes()
    assert data[:8] == b"VOX " + struct.pack("<I", 150), path
    assert data[8:12] == b"MAIN", path
    assert struct.unpack_from("<I", data, 16)[0] == len(data) - 20, path
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
    assert size and points and all(1 <= d <= 256 for d in size), path
    assert all(all(p[k] < size[k] for k in range(3)) and p[3] > 0 for p in points), path
    assert len({p[:3] for p in points}) == len(points), path
    assert 1000 < len(data) < 20_000_000, path
    return size, points


def validate_rig(folder, count, length, scale, queen=False):
    rig = json.loads((folder / "rig.json").read_text())
    assert rig["voxel_size"] > 0
    assert (rig.get("animation_style") == "xeno_queen") if queen else "animation_style" not in rig
    for name, info in rig["parts"].items():
        assert all(0 < d <= 256 for d in info["frame_size"]), name
        assert all(abs(p) <= 256 for p in info["frame_min"]), name
        paths = []
        if info.get("solid", True):
            paths.append(folder / (name + ".vox"))
        if info.get("glow"):
            paths.append(folder / (name + "_glow.vox"))
        assert paths, name
        for path in paths:
            size, _ = read_vox(path)
            assert size == tuple(info["frame_size"][i] for i in (2, 0, 1)), path
    for name, spec in rig["limbs"].items():
        assert spec["part"] in rig["parts"], name
        assert len(spec["pivot"]) == 3 and all(math.isfinite(p) and abs(p) <= 256 for p in spec["pivot"]), name
        parent = spec.get("parent_limb")
        assert not parent or parent in rig["limbs"], name
        seen = {name}
        while parent:
            assert parent not in seen, name
            seen.add(parent)
            parent = rig["limbs"][parent].get("parent_limb")
    chain = {n for n, s in rig["limbs"].items() if s["role"] == "tail_chain"}
    assert chain == {f"tail_{i}" for i in range(count)}
    previous_end = None
    for i in range(count):
        spec = rig["limbs"][f"tail_{i}"]
        assert (spec["segment"], spec["segments"], spec["phase"]) == (i, count, 1)
        assert spec["part"] == f"tail_{i}"
        assert spec.get("parent_limb") == (f"tail_{i - 1}" if i else None)
        if i:
            assert spec["pivot"] == [0, 0, length * scale]
        info = rig["parts"][spec["part"]]
        assert info["frame_min"][2] == 0
        assert info["frame_size"][2] == length * scale
        # Check actual serialized solid and glow cells meet across joint faces.
        occupied = set()
        for suffix in ("", "_glow"):
            path = folder / (spec["part"] + suffix + ".vox")
            if path.exists():
                _, points = read_vox(path)
                lo = info["frame_min"]
                occupied.update((p[1] + lo[0], p[2] + lo[1], p[0] + lo[2])
                                for p in points)
        start_face = {(x, y) for x, y, z in occupied if z == 0}
        end_face = {(x, y) for x, y, z in occupied if z == length * scale - 1}
        assert start_face and end_face
        if previous_end is not None:
            assert previous_end & start_face, f"Disconnected tail joint {i} in {folder}"
        previous_end = end_face
    for swaps in rig.get("variants", {}).values():
        assert all(base in rig["parts"] and replacement in rig["parts"]
                   for base, replacement in swaps.items())
    return rig


def previews(cast):
    """Optional orthographic silhouettes, written only to the requested temp path."""
    try:
        from PIL import Image, ImageDraw
    except ImportError:
        print("Pillow unavailable; skipping optional previews")
        return
    folder = Path("/tmp/theory_creature_previews")
    folder.mkdir(exist_ok=True)
    cards = []
    for name, full, variants in cast:
        for form, voxels in [("default", full), *variants.items()]:
            canvas = Image.new("RGB", (960, 400), (17, 23, 32))
            draw = ImageDraw.Draw(canvas)
            draw.text((16, 12), name + " - " + form, fill=(225, 220, 232))
            for panel, (label, horizontal, vertical, depth, reverse) in enumerate(
                    (("front", 0, 1, 2, True), ("top - nose up", 0, 2, 1, False),
                     ("side - nose left", 2, 1, 0, False))):
                pixels = {}
                for p, c in sorted(voxels.items(), key=lambda kv: kv[0][depth], reverse=reverse):
                    pixels[p[horizontal], p[vertical]] = c
                xs, ys = zip(*pixels)
                unit = min(9, 270 // (max(xs) - min(xs) + 1), 310 // (max(ys) - min(ys) + 1))
                unit = max(unit, 1)
                width = (max(xs) - min(xs) + 1) * unit
                left = panel * 320 + (320 - width) // 2
                draw.text((panel * 320 + 20, 38), label, fill=(150, 148, 165))
                for (x, y), color in pixels.items():
                    py = y - min(ys) if label.startswith("top") else max(ys) - y
                    px = left + (x - min(xs)) * unit
                    py = 66 + py * unit
                    # Preview exposure lift makes near-black planes legible.
                    rgb = a.PAL["xeno"][color]
                    if not color.startswith("glow"):
                        rgb = tuple(min(255, round(c * 1.65 + 7)) for c in rgb)
                    draw.rectangle((px, py, px + unit - 1, py + unit - 1), fill=rgb)
            canvas.save(folder / (name + ("_" + form if form != "default" else "") + ".png"))
            if form == "default":
                cards.append(canvas.resize((720, 300), Image.Resampling.NEAREST))
    sheet = Image.new("RGB", (1440, 900), (17, 23, 32))
    for i, card in enumerate(cards):
        sheet.paste(card, ((i % 2) * 720, (i // 2) * 300))
    sheet.save(folder / "contact_sheet.png")


def main():
    targets = [R / "creatures" / name for name in IDS]
    targets += [R / "creatures/boss_projectiles" / name for name in SHOTS]
    existing = [str(p.relative_to(R)) for p in [*targets, MANIFEST] if p.exists()]
    if existing:
        raise SystemExit("Create-only generator refuses existing outputs: " + ", ".join(existing))
    definitions = [
        ("hull_skitter", "Hull Skitter", .9, 5, 3, "dart", 0, skitter),
        ("vent_stalker", "Vent Stalker", 2.6, 7, 3, "chase", 0, stalker),
        ("gloom_spitter", "Gloom Spitter", 2.0, 6, 4, "skirmish", 0, spitter),
        ("void_lamprey", "Void Lamprey", 1.8, 8, 3, "strafe", .45, lamprey),
        ("crest_brute", "Crest Brute", 3.1, 6, 3, "chase", 0, brute),
        ("void_empress", "The Hollow Empress", 7.5, 10, 2, "boss", 0, empress),
    ]
    records, cast, summaries = [], [], []
    # Validate all authored geometry before the first asset is written.
    authored = []
    for name, title, height, count, length, behavior, hover, factory in definitions:
        data = factory()
        body, parts, limbs, hand = data[:4]
        variants = data[4] if len(data) == 5 else {}
        full = assemble(body, parts, limbs)
        for v in [body, *parts.values()]:
            assert v and all(c in a.PAL["xeno"] for c in v.values()), name
        for i in range(count):
            v = parts[f"tail_{i}"]
            assert (0, 0, 0) in v and (0, 0, length - 1) in v, name
            assert min(p[2] for p in v) == 0 and max(p[2] for p in v) == length - 1
        if name == "void_empress":
            assert all(-16 <= x < 16 and 0 <= y < 32 and -16 <= z < 16
                       for x, y, z in full), "Queen exceeds the 32-grid pose canvas"
        authored.append((body, parts, limbs, hand, variants, full))
    for definition, data in zip(definitions, authored):
        name, title, height, count, length, behavior, hover, _ = definition
        body, parts, limbs, hand, variants, full = data
        queen = name == "void_empress"
        scale = 8 if queen else 1
        _, size = a.bounds(full)
        unit = height / (size[1] * scale)
        folder = R / "creatures" / name
        if queen:
            scaled = json.loads(json.dumps(limbs))
            for spec in scaled.values():
                spec["pivot"] = [p * 8 for p in spec["pivot"]]
            a.save(name, title, "xeno", {"body": body, **parts}, scaled,
                   variants, hand, unit=unit)
            for rig_folder in (folder, folder / "source_32"):
                path = rig_folder / "rig.json"
                rig = json.loads(path.read_text())
                rig.update(animation_style="xeno_queen", bob=.018, glow_strength=1.25)
                path.write_text(json.dumps(rig, indent=2) + "\n")
        else:
            small(name, "xeno", body, parts, limbs, unit, hover)
            path = folder / "rig.json"
            rig = json.loads(path.read_text())
            rig.update(hand=list(hand), bob=.018, waddle=.035,
                       pixel_art=True, material_jitter=0.0, glow_strength=1.15)
            path.write_text(json.dumps(rig, indent=2) + "\n")
        rig = validate_rig(folder, count, length, scale, queen)
        if queen:
            coarse = validate_rig(folder / "source_32", count, length, 1, True)
            assert coarse["voxel_size"] == unit * 8
            for n, spec in rig["limbs"].items():
                assert spec["pivot"] == [q * 8 for q in coarse["limbs"][n]["pivot"]]
            for path in folder.glob("model*.vox"):
                read_vox(path)
        variants_full = {form: assemble(body, parts, limbs, swaps)
                         for form, swaps in variants.items()}
        cast.append((name, full, variants_full))
        record = dict(id=name, display_name=title, biome="Theory of Everything",
                      folder="creatures/" + name, status="live", height_m=height,
                      voxel_size=unit, parts=list(rig["parts"]), tail_segments=count,
                      variants=list(variants), behavior=behavior)
        if queen:
            record.update(design_grid=[32, 32, 32], upscale=8,
                          poses=json.loads((folder / "poses.json").read_text()))
        records.append(record)
        total = sum(len(read_vox(path)[1]) for n in ["body", *[s["part"] for s in limbs.values()]]
                    for path in (folder / (n + ".vox"), folder / (n + "_glow.vox")) if path.exists())
        summaries.append(f"{name}: parts={len(rig['parts'])} default_voxels={total} voxel_size={unit:.9f}")
    projectiles()
    for name in SHOTS:
        read_vox(R / "creatures/boss_projectiles" / name / "model.vox")
    MANIFEST.write_text(json.dumps(records, indent=2) + "\n")
    previews(cast)
    for target in [*targets, MANIFEST]:
        paths = [target] if target.is_file() else list(target.rglob("*"))
        for path in paths:
            assert not path.name.endswith(".import"), path
            if path.suffix == ".json":
                content = path.read_text()
                assert all(chr(code) not in content for code in (0x00B7, 0x2022)), path
    print("\nTheory creatures complete - Python rig and VOX validation passed")
    print("\n".join(summaries))
    print("Projectiles: " + ", ".join(SHOTS))
    print("Voxel totals count default rig parts, including separate glow parts.")
    print("Optional previews: /tmp/theory_creature_previews/")


if __name__ == "__main__":
    main()
