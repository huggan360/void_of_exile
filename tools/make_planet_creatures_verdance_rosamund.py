#!/usr/bin/env python3
"""Create-only Verdance and Rosamund voxel cast. Run from the repository root.

Uses the court small-rig helper and shared pixel boss/projectile exporters.
All geometry is authored in coarse cells, forward -Z, up +Y. Gods have x8
surface exports and editable source_32 rigs. Behavior is manifest metadata.
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
MANIFEST = R / 'creatures/planet_creatures_verdance_rosamund_manifest.json'
a.PAL['verdance'] = dict(base=(115,77,45), light=(181,131,73),
    shade=(65,48,33), dark=(27,39,28), belly=(239,221,166),
    bone=(221,186,112), wing=(102,153,62), accent=(51,103,62),
    glow_eye=(255,221,115), glow_core=(152,255,126))
a.PAL['rosamund'] = dict(base=(221,103,157), light=(255,186,216),
    shade=(147,65,119), dark=(60,40,81), belly=(255,237,211),
    bone=(246,201,117), wing=(164,207,238), accent=(68,129,108),
    glow_eye=(132,233,255), glow_core=(255,146,222))

# Import only function definitions: the court module has top-level asset writes.
for filename, names in [('make_court_creatures.py', {'small', 'boss'}),
                         ('make_theory_creatures.py', {'assemble', 'read_vox'})]:
    tree = ast.parse((R / 'tools' / filename).read_text())
    for node in tree.body:
        if isinstance(node, ast.FunctionDef) and node.name in names:
            exec(compile(ast.Module(body=[node], type_ignores=[]), filename, 'exec'))

# The established boss writer has a literal biome lookup. Extend in memory only.
tree = ast.parse((R / 'tools/redesign_pixel_bosses.py').read_text())
node = next(n for n in tree.body if isinstance(n, ast.FunctionDef) and n.name == 'save')
tables = [n for n in ast.walk(node) if isinstance(n, ast.Dict)
          and any(isinstance(k, ast.Constant) and k.value == 'blue' for k in n.keys)]
assert len(tables) == 1
for key, title in [('verdance', 'Verdance'), ('rosamund', 'Rosamund')]:
    tables[0].keys.append(ast.Constant(key))
    tables[0].values.append(ast.Constant(title))
exec(compile(ast.fix_missing_locations(ast.Module(body=[node], type_ignores=[])),
             'planet_boss_writer', 'exec'), a.__dict__)


def add(parts, limbs, name, voxels, pivot, role, phase=1, **extra):
    parts[name] = voxels
    limbs[name] = a.limb(name, pivot, role, phase, throws=False, **extra)
    limbs[name]['pivot'] = list(pivot)


def face(v, y=0, z=-3, spacing=2, sleepy=False):
    for s in (-1, 1):
        a.box(v, (s * spacing - 1, y, z), (s * spacing + 1, y + 2, z + 1), 'dark')
        v[s * spacing, y, z - 1] = 'glow_eye'
        if sleepy:
            a.line(v, (s * spacing - 1, y + 1, z - 1),
                   (s * spacing + 1, y + 1, z - 1), 'base')
    v[0, y - 1, z] = 'dark'


def wings(parts, limbs, root_y, reach=9, queen=False):
    # Wing role invokes the existing flap() and idle wing beat animation.
    for s, label in [(-1, 'l'), (1, 'r')]:
        for i in range(2):
            v = {}
            if queen:
                outline = [(0, 0), (3, 5), (reach - 1, 8), (reach, 4),
                           (reach - 2, 0), (3, -2)] if i == 0 else [
                           (0, 0), (reach - 2, 0), (reach - 1, -5), (5, -9), (2, -5)]
                a.polygon(v, [(s*x, y) for x, y in outline], 0, 2, 'glow_eye')
                for x, y in [(3, 1), (6, 3 if i == 0 else -3)]:
                    a.ell(v, (s*x, y, 0), (2, 2, 1), 'glow_core')
                a.line(v, (0, 0, -1), (s*(reach-2), 4 if i == 0 else -5, -1), 'bone')
            else:
                # Broad horizontal petals are clearly visible from above.
                a.ell(v, (s*4, 1, -2 if i == 0 else 2),
                      (5, 1.5, 3.5), 'glow_eye')
                a.line(v, (0, 0, 0), (s*7, 1, -3 if i == 0 else 3), 'glow_core')
            add(parts, limbs, f'wing_{label}_{i}', v,
                (s*2, root_y, 2 if queen else (-2 if i == 0 else 2)), 'wing', s,
                amount=1.0)


def sprite(moth=False):
    b, p, l = {}, {}, {}
    if moth:
        a.ell(b, (0, 6, 2), (3, 3, 4), 'glow_core')
        a.ell(b, (0, 7, -2), (2, 2, 2), 'wing')
        for z in (1, 4):
            a.line(b, (-2, 7, z), (1, 8, z), 'glow_eye')
    else:
        a.ell(b, (0, 7, 0), (2, 3, 2), 'glow_core')
        for s in (-1, 1):
            a.polygon(b, [(0, 7), (s*5, 3), (s*3, 2)], -2, 2, 'light')
        a.ell(b, (0, 5, 0), (3, 2, 2), 'glow_core')
    h = {}
    a.ell(h, (0, 1, 0), (3, 3, 3), 'belly')
    face(h, 1, -3, 1)
    if moth:
        for s in (-1, 1):
            a.line(h, (s, 3, 0), (s*3, 5, -1), 'bone')
            h[s*3, 5, -1] = 'glow_eye'
    else:
        for x in (-2, 0, 2):
            a.diamond(h, (x, 4, 0), 1, 2, 'glow_core')
    add(p, l, 'head', h, (0, 9, -3 if moth else -1), 'head')
    wings(p, l, 8)
    for s, label in [(-1, 'l'), (1, 'r')]:
        arm = {}
        a.line(arm, (0, 0, 0), (s*2, -2, -2), 'glow_eye')
        add(p, l, 'arm_' + label, arm, (s*2, 8, -2), 'arm', s)
        if not moth:
            leg = {}
            a.line(leg, (0, 0, 0), (s, -3, -1), 'glow_core')
            add(p, l, 'leg_' + label, leg, (s, 3, 0), 'leg', s)
    return b, p, l


def capling():
    b, p, l = {}, {}, {}
    a.ell(b, (0, 7, 0), (4, 5, 3), 'belly')
    h = {}
    a.ell(h, (0, 1, 0), (4, 3, 3), 'belly')
    face(h, 0, -3, 2, True)
    a.ell(h, (0, 4, 0), (9, 4, 7), 'wing')
    a.ell(h, (0, 3, 0), (9, 1, 7), 'bone')
    for x, y, z in [(-5, 5, -3), (3, 6, -3), (0, 7, 1), (5, 5, 2), (-4, 6, 3)]:
        a.ell(h, (x, y, z), (2, 1.5, 2), 'glow_eye')
    add(p, l, 'head', h, (0, 10, 0), 'head')
    jaw = {}; a.ell(jaw, (0, 0, -1), (1.5, 1, 1.5), 'shade')
    add(p, l, 'jaw', jaw, (0, -1, -3), 'jaw', parent_limb='head')
    for s, label in [(-1, 'l'), (1, 'r')]:
        leg = {}; a.ell(leg, (0, -2, -1), (2, 2, 2.5), 'base')
        add(p, l, 'leg_' + label, leg, (s*2, 4, 0), 'leg', s)
        arm = {}; a.line(arm, (0, 0, 0), (s*2, -2, -1), 'belly', 2)
        add(p, l, 'arm_' + label, arm, (s*3, 7, 0), 'arm', s)
    return b, p, l


def guardian(rose=False):
    b, p, l = {}, {}, {}
    a.box(b, (-4, 7, -3), (4, 19, 4), 'base')
    a.box(b, (-5, 15, -3), (5, 20, 3), 'light' if rose else 'wing')
    if rose:
        for x, y, z in [(-3, 14, -4), (3, 18, -3), (0, 19, 1)]:
            a.diamond(b, (x, y, z), 2, 4, 'base')
        a.diamond(b, (0, 13, -4), 2, 3, 'glow_eye')
        for y in range(8, 20):
            x = round(3*math.sin(y*.65))
            b[x, y, -4] = 'accent'
            if y % 3 == 0:
                b[x+1, y, -5] = 'bone'
    else:
        for x in (-3, 0, 3):
            a.line(b, (x, 8, -4), (x, 19, -4), 'shade')
        a.box(b, (-2, 11, -5), (3, 17, -3), 'dark')
        for x, y in [(-1, 12), (1, 14), (-1, 16)]:
            b[x, y, -5] = 'glow_eye'
        for x in (-2, 2):
            a.line(b, (x, 11, -6), (x, 17, -6), 'bone')
        for y in (11, 17):
            a.line(b, (-2, y, -6), (2, y, -6), 'bone')
    h = {}; a.box(h, (-3, 0, -3), (3, 5, 3), 'light' if rose else 'base')
    face(h, 2, -3)
    if rose:
        a.diamond(h, (0, 5, 0), 2, 3, 'glow_core')
    else:
        a.ell(h, (0, 5, 0), (4, 2, 3), 'wing')
        for s in (-1, 1):
            a.line(h, (s*2, 4, 0), (s*4, 7, 1), 'base')
            a.line(h, (s*4, 7, 1), (s*5, 8, 1), 'wing')
    add(p, l, 'head', h, (0, 20, 0), 'head')
    for s, label in [(-1, 'l'), (1, 'r')]:
        leg = {}; a.box(leg, (-2, -7, -2), (2, 1, 2), 'shade')
        a.box(leg, (-2, -7, -4), (3, -5, 2), 'base')
        add(p, l, 'leg_' + label, leg, (s*3, 7, 0), 'leg', s)
        arm = {}; a.line(arm, (0, 0, 0), (s*2, -5, 0), 'base', 3)
        a.box(arm, (s*2-1, -10, -2), (s*2+3, -4, 2), 'base')
        if rose:
            a.diamond(arm, (s*2, -5, -2), 2, 3, 'light')
            a.line(arm, (0, 0, -1), (s*2, -8, -3), 'accent')
            a.ell(arm, (s*2, -8, -3), (2, 2, 1), 'glow_core')
        else:
            for dx in (-1, 1, 3):
                a.line(arm, (s*2+dx, -9, -1), (s*2+dx, -12, -3), 'light')
            a.ell(arm, (s*2, -2, 0), (3, 2, 3), 'wing')
        add(p, l, 'arm_' + label, arm, (s*5, 18, 0), 'arm', s)
    return b, p, l


def stag():
    b, p, l = {}, {}, {}
    a.ell(b, (0, 12, 2), (5, 5, 8), 'base')
    a.ell(b, (0, 16, -4), (4, 6, 4), 'wing')
    a.ell(b, (0, 15, 3), (5, 2, 7), 'accent')
    a.diamond(b, (0, 15, -8), 2, 3, 'glow_core')
    for x in (-3, -1, 1, 3):
        a.line(b, (x, 18, -6), (x, 9 + abs(x), -7), 'wing')
        b[x, 10 + abs(x), -7] = 'glow_core'
    h = {}; a.ell(h, (0, 0, -1), (3, 3, 4), 'base')
    a.ell(h, (0, -1, -4), (2, 2, 3), 'belly')
    face(h, 0, -4)
    h[0, -1, -7] = 'dark'
    for s in (-1, 1):
        a.ell(h, (s*4, 1, 0), (3, 1, 2), 'wing')
        a.line(h, (s*2, 2, 0), (s*6, 5, 1), 'bone', 2)
        a.line(h, (s*6, 5, 1), (s*10, 9, 2), 'glow_core')
        for x, y in [(4, 5), (7, 7), (10, 9)]:
            a.line(h, (s*x, y-2, 1), (s*x, y+1, 1), 'glow_core')
        a.line(h, (s*6, 5, 1), (s*12, 6, 1), 'glow_eye')
    add(p, l, 'head', h, (0, 21, -5), 'head')
    for s, label in [(-1, 'l'), (1, 'r')]:
        for i, x in enumerate((6, 11)):
            lantern = {}
            a.line(lantern, (0, 0, 0), (0, -2, 0), 'bone')
            a.ell(lantern, (0, -3, 0), (1.5, 2, 1.5), 'glow_eye')
            lantern[0, -5, 0] = 'bone'
            add(p, l, f'lantern_{label}_{i}', lantern, (s*x, 5+i, 1),
                'sway', s, parent_limb='head')
        for i, z in enumerate((-3, 7)):
            leg = {}; a.line(leg, (0, 0, 0), (0, -4, 1), 'base', 2)
            a.line(leg, (0, -4, 1), (0, -8, -1), 'light', 2)
            a.box(leg, (-1, -9, -2), (2, -7, 1), 'shade')
            add(p, l, f'leg_{label}_{i}', leg, (s*3, 9, z), 'leg', s*(-1)**i)
    tail = {}; a.ell(tail, (0, -1, 2), (2, 2, 3), 'wing')
    add(p, l, 'tail', tail, (0, 13, 9), 'tail')
    return b, p, l


def hopper():
    b, p, l = {}, {}, {}
    a.ell(b, (0, 6, 1), (5, 4, 5), 'belly')
    for x, z, h in [(-3, 2, 3), (0, 3, 5), (3, 2, 3), (0, 5, 3)]:
        a.diamond(b, (x, 10, z), 2, h, 'base')
        b[x, 10+h, z] = 'glow_core'
    head = {}; a.ell(head, (0, 0, 0), (4, 3, 3), 'belly')
    face(head, 0, -3, 2)
    head[0, -1, -4] = 'base'
    add(p, l, 'head', head, (0, 8, -4), 'head')
    for s, label in [(-1, 'l'), (1, 'r')]:
        ear = {}; a.ell(ear, (s, 4, 0), (1.5, 5, 1.5), 'base')
        a.line(ear, (s, 1, -1), (s, 7, -1), 'glow_core')
        add(p, l, 'ear_' + label, ear, (s*2, 2, 0), 'sway', s, parent_limb='head')
        leg = {}; a.ell(leg, (s, -1, 1), (3, 3, 3), 'base')
        a.box(leg, (-2, -4, -4), (3, -2, 2), 'belly')
        add(p, l, 'leg_' + label, leg, (s*4, 4, 3), 'leg', s, amount=1.4)
        arm = {}; a.line(arm, (0, 0, 0), (0, -3, -2), 'belly', 2)
        add(p, l, 'arm_' + label, arm, (s*3, 5, -3), 'arm', s)
    return b, p, l


def queen():
    b, p, l = {}, {}, {}
    a.ell(b, (0, 15, 0), (3, 5, 3), 'belly')
    a.ell(b, (0, 12, 0), (4, 3, 3), 'base')
    a.diamond(b, (0, 16, -3), 1, 2, 'glow_eye')
    # Four independently swaying, pointed rose petals form the gown.
    for i, (x, z) in enumerate([(-3, 0), (3, 0), (0, -2), (0, 2)]):
        petal = {}; a.polygon(petal, [(-2, 0), (2, 0), (4, -7),
                            (0, -11), (-4, -7)], -1, 2, 'base' if i % 2 else 'light')
        a.line(petal, (0, -1, -2), (0, -9, -2), 'glow_core')
        add(p, l, 'gown_' + str(i), petal, (x, 12, z), 'sway', (-1)**i)
    h = {}; a.ell(h, (0, 1, 0), (3, 4, 3), 'belly')
    a.ell(h, (0, 2, 1), (4, 4, 3), 'light')
    face(h, 1, -3, 2)
    a.box(h, (-3, 5, -2), (4, 6, 2), 'bone')
    for x in (-3, 0, 3):
        a.diamond(h, (x, 7, 0), 1, 3 if x == 0 else 2, 'glow_eye')
    add(p, l, 'head', h, (0, 20, -1), 'head')
    wings(p, l, 18, reach=12, queen=True)
    for s, label in [(-1, 'l'), (1, 'r')]:
        arm = {}; a.line(arm, (0, 0, 0), (s*3, -5, -1), 'belly', 2)
        a.ell(arm, (0, 0, 0), (2, 2, 2), 'light')
        if s > 0:
            a.line(arm, (4, -10, -2), (4, 5, -2), 'bone')
            a.diamond(arm, (4, 6, -2), 2, 3, 'glow_eye')
            for dx in (-2, 2):
                arm[4+dx, 6, -2] = 'glow_core'
        add(p, l, 'arm_' + label, arm, (s*3, 17, -1), 'arm', s)
        leg = {}; a.line(leg, (0, 0, 0), (0, -4, -1), 'belly')
        add(p, l, 'leg_' + label, leg, (s, 5, 0), 'leg', s)
    return b, p, l


DEFINITIONS = [
    ('moss_glimmer', 'Moss Glimmer', 'Verdance', .7, 'dart', lambda: sprite(True), False, True,
     'Flies in swarms with two pairs of fluttering wings.'),
    ('capling', 'Capling', 'Verdance', 1.0, 'skirmish', capling, False, False,
     'Spits spores and spawns around glowing mushrooms.'),
    ('bark_warden', 'Bark Warden', 'Verdance', 2.4, 'chase', guardian, False, False,
     'Treant guardian that slams the ground.'),
    ('elder_thornheart', 'Elder Thornheart', 'Verdance', 4.0, 'strafe', stag, True, False,
     'Ancient moss stag god with lantern antlers and a luminous green heart.'),
    ('petal_sprite', 'Petal Sprite', 'Rosamund', .7, 'orbit', sprite, False, True,
     'Circles its queen or leader.'),
    ('quartz_hopper', 'Quartz Hopper', 'Rosamund', 1.0, 'skirmish', hopper, False, False,
     'Rabbit-frog that hops on large hind legs.'),
    ('rose_golem', 'Rose Golem', 'Rosamund', 2.2, 'chase', lambda: guardian(True), False, False,
     'Pink crystal guardian wrapped in thorny rose vines.'),
    ('queen_lumeria', 'Queen Lumeria', 'Rosamund', 3.2, 'strafe', queen, True, False,
     'Fairy queen god with four butterfly wings; petal sprites orbit her.'),
]
SHOTS = ('spore_puff', 'rose_shard')


def validate(folder):
    rig = json.loads((folder / 'rig.json').read_text())
    assert rig['voxel_size'] > 0
    for name, info in rig['parts'].items():
        assert info.get('solid', True) or info.get('glow')
        for suffix, present in [('', info.get('solid', True)), ('_glow', info.get('glow'))]:
            if present:
                size, points = read_vox(folder / (name + suffix + '.vox'))
                assert size == tuple(info['frame_size'][i] for i in (2, 0, 1))
    seen = set()
    for name, spec in rig['limbs'].items():
        assert spec['part'] in rig['parts']
        assert not spec.get('parent_limb') or spec['parent_limb'] in seen
        assert spec['role'] in {'leg', 'arm', 'wing', 'head', 'jaw', 'sway', 'tail'}
        seen.add(name)
    return rig


def preview(folder, full, theme):
    """Front, top (forward up), side (forward left), using standard-library PNG."""
    import zlib
    width, height = 720, 280
    pixels = bytearray(bytes((29, 33, 43)) * width * height)
    for panel, (horizontal, vertical, depth, reverse) in enumerate([
        (0, 1, 2, True), (0, 2, 1, False), (2, 1, 0, False)]):
        projected = {}
        for pos, c in sorted(full.items(), key=lambda item: item[0][depth], reverse=reverse):
            projected[pos[horizontal], pos[vertical]] = c
        xs, ys = zip(*projected)
        unit = min(7, 210 // (max(xs)-min(xs)+1), 232 // (max(ys)-min(ys)+1))
        left = panel*240 + (240-(max(xs)-min(xs)+1)*unit)//2
        for (x, y), c in projected.items():
            py = y-min(ys) if panel == 1 else max(ys)-y
            px, py = left+(x-min(xs))*unit, 24+py*unit
            color = bytes(a.PAL[theme][c])
            for row in range(py, py+unit):
                offset = (row*width+px)*3
                pixels[offset:offset+unit*3] = color*unit
    def chunk(tag, payload):
        return (struct.pack('>I', len(payload)) + tag + payload
                + struct.pack('>I', zlib.crc32(tag+payload) & 0xffffffff))
    raw = b''.join(b'\0'+pixels[y*width*3:(y+1)*width*3] for y in range(height))
    data = (b'\x89PNG\r\n\x1a\n'
            + chunk(b'IHDR', struct.pack('>IIBBBBB', width, height, 8, 2, 0, 0, 0))
            + chunk(b'IDAT', zlib.compress(raw)) + chunk(b'IEND', b''))
    destination = folder / 'preview.png'
    assert not destination.exists(), destination
    destination.write_bytes(data)


def main():
    targets = [R / 'creatures' / row[0] for row in DEFINITIONS]
    targets += [R / 'creatures/boss_projectiles' / name for name in SHOTS]
    existing = [str(p.relative_to(R)) for p in [*targets, MANIFEST] if p.exists()]
    if existing:
        raise SystemExit('Create-only generator refuses existing outputs: ' + ', '.join(existing))
    authored = []
    for row in DEFINITIONS:
        body, parts, limbs = row[5]()
        full = assemble(body, parts, limbs)
        assert all(-16 <= x < 16 and 0 <= y < 32 and -16 <= z < 16 for x, y, z in full), row[0]
        for v in [body, *parts.values()]:
            assert v and all(c in a.PAL[row[2].lower()] for c in v.values())
        authored.append((body, parts, limbs, full))
    records = []
    for row, (body, parts, limbs, full) in zip(DEFINITIONS, authored):
        name, title, biome, height, behavior, _, god, glowing, notes = row
        theme = biome.lower()
        scale = 8 if god else 1
        unit = height / (a.bounds(full)[1][1] * scale)
        flying = name in ('moss_glimmer', 'petal_sprite', 'queen_lumeria')
        hover = .18 if flying else 0
        folder = R / 'creatures' / name
        if god:
            scaled = json.loads(json.dumps(limbs))
            for spec in scaled.values():
                spec['pivot'] = [q*8 for q in spec['pivot']]
            a.save(name, title, theme, {'body': body, **parts}, scaled, {},
                   (0, 15, -8), unit=unit, hover=hover)
        else:
            small(name, theme, body, parts, limbs, unit, hover)
        for location in [folder, *([folder / 'source_32'] if god else [])]:
            path = location / 'rig.json'
            rig = json.loads(path.read_text())
            rig.update(pixel_art=True, material_jitter=0.0,
                       glow_strength=2.3 if glowing else 1.5 if god else 1.2,
                       bob=.025 if flying else .015,
                       waddle=.24 if name == 'quartz_hopper' else .04,
                       flap_rate=12.0 if name == 'moss_glimmer' else 7.0 if glowing else 2.8)
            if not god:
                rig['hand'] = [0, 9, -5]
            path.write_text(json.dumps(rig, indent=2) + '\n')
            validate(location)
        rig = validate(folder)
        assert math.isclose(unit*scale*a.bounds(full)[1][1], height)
        for path in folder.glob('model*.vox'):
            read_vox(path)
        record = dict(id=name, display_name=title, biome=biome,
                      folder='creatures/' + name, status='live', height_m=height,
                      voxel_size=unit, parts=list(rig['parts']), behavior=behavior,
                      behavior_notes=notes, god=god, glow=glowing,
                      design_grid=[32, 32, 32], upscale=scale,
                      projectile='spore_puff' if biome == 'Verdance' else 'rose_shard')
        records.append(record)
        preview(folder, full, theme)
        print(f'{name}: {len(rig["parts"])} parts, {height:.1f} m, voxel_size={unit:.9f}')
    puff = {}
    a.ell(puff, (0, 0, 0), (3, 3, 3), 'glow_core')
    for pos in [(-3, 1, 0), (2, 2, 1), (1, -2, 2), (-1, 0, -3)]:
        a.ell(puff, pos, (2, 2, 2), 'glow_eye')
    puff[4, -2, 2] = 'glow_eye'
    a.projectile('spore_puff', 'verdance', puff, .012)
    shard = {}
    for z in range(-7, 6):
        radius = max(0, 3 - abs(z+1)//2)
        for x in range(-radius, radius+1):
            for y in range(-radius, radius+1):
                if abs(x)+abs(y) <= radius:
                    shard[x, y, z] = 'glow_eye' if x == 0 else 'glow_core'
    a.projectile('rose_shard', 'rosamund', shard, .010)
    for name in SHOTS:
        folder = R / 'creatures/boss_projectiles' / name
        read_vox(folder / 'model.vox')
        assert json.loads((folder / 'rig.json').read_text())['upscale'] == 8
    MANIFEST.write_text(json.dumps(records, indent=2) + '\n')
    assert {r['id'] for r in records} == {row[0] for row in DEFINITIONS}
    for target in [*targets, MANIFEST, Path(__file__)]:
        paths = [target] if target.is_file() else target.rglob('*')
        for path in paths:
            if path.suffix in ('.py', '.json'):
                assert all(chr(code) not in path.read_text() for code in (0x00B7, 0x2022))
    print('Validated all creature rigs, VOX frames, heights, hierarchy, manifest and projectiles.')


if __name__ == '__main__':
    main()
