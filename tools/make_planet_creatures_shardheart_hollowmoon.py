#!/usr/bin/env python3
"""Create-only Shardheart and Hollowmoon cast. Run from the repository root.

Geometry uses coarse cells, Y up and forward -Z. Gods use the shared x8
surface writer and source_32 masters; projectiles match acid_glob's format.
Existing output paths are refused before any assets are written.
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
MANIFEST = R / 'creatures/planet_creatures_shardheart_hollowmoon_manifest.json'
SHOTS = ('prism_note', 'ghost_star')
a.PAL['shardheart'] = dict(base=(24, 112, 148), light=(104, 231, 228),
    shade=(22, 43, 96), dark=(10, 18, 47), belly=(46, 170, 188),
    bone=(205, 244, 244), wing=(35, 77, 122), accent=(180, 54, 170),
    glow_eye=(161, 255, 246), glow_core=(253, 96, 222), glow_teal=(45, 226, 214))
a.PAL['hollowmoon'] = dict(base=(115, 125, 132), light=(176, 185, 185),
    shade=(57, 65, 76), dark=(17, 24, 31), belly=(144, 159, 150),
    bone=(230, 225, 197), wing=(37, 48, 65), accent=(181, 139, 71),
    glow_eye=(187, 255, 211), glow_core=(75, 237, 151), glow_teal=(119, 221, 177))

# Execute only rig helper definitions, never the court generator's asset writes.
source = ast.parse((R / 'tools/make_court_creatures.py').read_text())
for node in source.body:
    if isinstance(node, ast.FunctionDef) and node.name in ('small', 'boss'):
        exec(compile(ast.Module(body=[node], type_ignores=[]), 'court_helpers', 'exec'))

# Extend only the imported writer's in-memory biome lookup, as in the template.
source = ast.parse((R / 'tools/redesign_pixel_bosses.py').read_text())
node = next(n for n in source.body if isinstance(n, ast.FunctionDef) and n.name == 'save')
tables = [n for n in ast.walk(node) if isinstance(n, ast.Dict)
          and any(isinstance(k, ast.Constant) and k.value == 'blue' for k in n.keys)]
assert len(tables) == 1
for key, title in [('shardheart', 'Shardheart'), ('hollowmoon', 'Hollowmoon')]:
    tables[0].keys.append(ast.Constant(key))
    tables[0].values.append(ast.Constant(title))
exec(compile(ast.fix_missing_locations(ast.Module(body=[node], type_ignores=[])),
             'planet_writer', 'exec'), a.__dict__)


def joint(name, pivot, role, phase=1, **extra):
    spec = a.limb(name, pivot, role, phase, throws=False, **extra)
    spec['pivot'] = list(pivot)
    return spec


def add(parts, limbs, name, voxels, pivot, role, phase=1, **extra):
    parts[name] = voxels
    limbs[name] = joint(name, pivot, role, phase, **extra)


def crystal(center=(0, 0, 0), radius=3, height=5, color='glow_teal'):
    v = {}
    a.diamond(v, center, radius, height, color)
    # Broad emissive front facets, deep blue right facets and a bright ridge.
    for (x, y, z), c in list(v.items()):
        if c == 'light': v[x, y, z] = color
    x, y, z = center
    a.line(v, (x, y-height+1, z), (x, y+height, z), 'glow_eye')
    return v


def face(v, y, z, gap=2):
    for s in (-1, 1):
        a.box(v, (s*gap-1, y-1, z), (s*gap+1, y+2, z+1), 'dark')
        v[s*gap, y, z-1] = 'glow_eye'


def wisp():
    b = crystal((0, 8, 0), 4, 6)
    face(b, 9, -3)
    b[0, 6, -3] = 'dark'
    p, l = {}, {}
    for i, (x, y, z) in enumerate(((7, 0, 0), (-6, 2, 2), (0, -2, -7))):
        add(p, l, f'chip_{i}', crystal((x, y, z), 1, 2, 'glow_core'),
            (0, 8, 0), '')
    return b, p, l


def crawler(bone=False):
    b, p, l = {}, {}, {}
    if bone:
        a.line(b, (0, 5, -4), (0, 5, 6), 'bone', 2)
        for z in (-2, 1, 4):
            for s in (-1, 1):
                a.line(b, (0, 7, z), (s*4, 6, z), 'bone')
                a.line(b, (s*4, 6, z), (s*4, 3, z), 'light')
        head = {}
        a.ell(head, (0, 0, 0), (4, 3, 3), 'bone')
        face(head, 0, -3)
        head[0, -1, -3] = 'dark'
        jaw = {}
        a.box(jaw, (-3, -1, -1), (3, 0, 1), 'bone')
        for x in (-2, 0, 2): jaw[x, 0, -1] = 'bone'
        add(p, l, 'head', head, (0, 6, -5), 'head')
        add(p, l, 'jaw', jaw, (0, -2, -2), 'jaw', parent_limb='head')
    else:
        b = crystal((0, 7, 1), 5, 4)
        for s in (-1, 1):
            b.update(crystal((s*2, 9, 2), 2, 3, 'glow_core'))
        head = crystal((0, 0, 0), 3, 2)
        face(head, 0, -2)
        add(p, l, 'head', head, (0, 6, -4), 'head')
    for s, label in ((-1, 'l'), (1, 'r')):
        for i, z in enumerate((-4, -1, 2, 5)):
            v = {}
            a.line(v, (0, 0, 0), (s*4, 2, i-2), 'bone' if bone else 'glow_core', 2)
            a.line(v, (s*4, 2, i-2), (s*6, -4, i-3), 'bone' if bone else 'glow_teal')
            v[s*6, -5, i-3] = 'light'
            add(p, l, f'leg_{label}_{i}', v, (s*3, 5, z), 'leg', s*(-1)**i)
    return b, p, l


def guardian(stone=False):
    b, p, l = {}, {}, {}
    if stone:
        a.box(b, (-5, 9, -3), (5, 21, 4), 'base')
        a.box(b, (-6, 18, -4), (6, 22, 4), 'light')
        a.box(b, (-3, 12, -4), (3, 18, -3), 'shade')
        for start, end in [((0, 20, -4), (-2, 16, -4)),
                           ((-2, 16, -4), (1, 12, -4)), ((0, 18, -4), (4, 16, -4))]:
            a.line(b, start, end, 'glow_core')
        head = {}
        a.box(head, (-4, -2, -3), (4, 4, 3), 'light')
        a.box(head, (-5, 4, -4), (5, 6, 4), 'base')
        face(head, 1, -4)
        a.line(head, (0, 5, -4), (1, 3, -4), 'glow_core')
        add(p, l, 'head', head, (0, 24, 0), 'head')
    else:
        b = crystal((0, 12, 0), 5, 8)
        for s in (-1, 1):
            b.update(crystal((s*4, 23, 0), 2, 7))
            a.line(b, (s*2, 8, 0), (s*7, 0, 2), 'glow_teal', 2)
        head = crystal((0, 0, 0), 3, 3, 'glow_core')
        face(head, 0, -3)
        add(p, l, 'head', head, (0, 19, -2), 'head')
    for s, label in ((-1, 'l'), (1, 'r')):
        arm = {}
        a.line(arm, (0, 0, 0), (s*3, -3, 0), 'base' if stone else 'glow_teal', 3)
        a.line(arm, (s*3, -3, 0), (s*3, -9, -2), 'light' if stone else 'glow_core', 2)
        a.line(arm, (s*3, -5, -1), (s*3, -8, -2), 'glow_core')
        add(p, l, 'arm_'+label, arm, (s*5, 20, 0), 'arm', s)
        leg = {}
        a.box(leg, (-2, -8, -2), (2, 0, 2), 'shade' if stone else 'base')
        a.box(leg, (-2, -9, -4), (3, -7, 2), 'base')
        leg[0, -3, -2] = 'glow_core'
        add(p, l, 'leg_'+label, leg, (s*3, 9, 0), 'leg', s)
    return b, p, l


def choir():
    b, p, l = {}, {}, {}
    outline = [(0, 4), (-9, 14), (-10, 21), (-7, 25), (-3, 25),
               (0, 22), (3, 25), (7, 25), (10, 21), (9, 14)]
    a.polygon(b, outline, -3, 4, 'glow_teal')
    a.polygon(b, [(0, 5), (0, 21), (7, 24), (9, 20), (8, 14)], -4, -3, 'accent')
    a.line(b, (0, 6, -4), (-6, 20, -4), 'glow_eye')
    face(b, 20, -5, 4)
    for i, (x, y) in enumerate(((-5, 15), (0, 12), (5, 15))):
        a.ell(b, (x, y, -4), (2, 3, 1), 'dark')
        jaw = {}
        a.box(jaw, (-2, -1, -1), (2, 0, 1), 'glow_core')
        jaw[0, 0, -1] = 'bone'
        add(p, l, f'jaw_{i}', jaw, (x, y-2, -4), 'jaw')
    halo = {}
    for i in range(9):
        angle = i*math.tau/9
        halo.update(crystal((round(12*math.cos(angle)), 0, round(12*math.sin(angle))),
                            1, 2, 'glow_core'))
    add(p, l, 'shard_halo', halo, (0, 29, 0), 'tail')
    for s, label in ((-1, 'l'), (1, 'r')):
        arm = crystal((s*2, -3, 0), 2, 5)
        add(p, l, 'arm_'+label, arm, (s*10, 17, 0), 'arm', s)
    return b, p, l


def ghost():
    b, p, l = {}, {}, {}
    a.polygon(b, [(-5, 5), (-4, 15), (0, 18), (4, 15), (5, 5), (2, 7), (0, 4), (-2, 7)],
              -2, 3, 'glow_teal')
    a.line(b, (-3, 7, -3), (-2, 14, -3), 'bone')
    head = {}
    a.ell(head, (0, 0, 0), (5, 5, 4), 'shade')
    a.box(head, (-3, -3, -4), (3, 3, -3), 'dark')
    face(head, 0, -4)
    a.line(head, (-3, 3, -4), (0, 5, -2), 'glow_teal')
    add(p, l, 'head', head, (0, 19, 0), 'head')
    for s, label in ((-1, 'l'), (1, 'r')):
        arm = {}
        a.line(arm, (0, 0, 0), (s*3, -5, -1), 'glow_teal', 2)
        add(p, l, 'arm_'+label, arm, (s*4, 14, 0), 'arm', s)
    lantern = {}
    a.box(lantern, (-2, -5, -2), (3, 0, 3), 'glow_core')
    for x in (-2, 2):
        for z in (-2, 2): a.line(lantern, (x, -5, z), (x, 0, z), 'accent')
    for y in (-6, 0): a.box(lantern, (-3, y, -3), (4, y+1, 4), 'shade')
    a.line(lantern, (-1, 1, 0), (-1, 3, 0), 'accent')
    a.line(lantern, (1, 1, 0), (1, 3, 0), 'accent')
    a.line(lantern, (-1, 3, 0), (1, 3, 0), 'accent')
    add(p, l, 'lantern', lantern, (3, -7, -1), 'tail', parent_limb='arm_r')
    for i in range(4):
        tail = {}
        radius = 2 if i < 2 else 1
        for z in range(3):
            a.box(tail, (-radius, -radius, z), (radius+1, radius+1, z+1), 'glow_teal')
        tail[0, 0, 2] = 'glow_eye'
        extra = dict(segment=i, segments=4)
        if i: extra['parent_limb'] = f'tail_{i-1}'
        add(p, l, f'tail_{i}', tail, (0, 5, 2) if i == 0 else (0, 0, 3),
            'tail_chain', **extra)
    return b, p, l


def astronomer():
    b, p, l = {}, {}, {}
    a.polygon(b, [(-8, 2), (-5, 21), (5, 21), (8, 2)], -3, 4, 'wing')
    a.polygon(b, [(-2, 3), (-2, 21), (2, 21), (3, 3)], -4, -3, 'bone')
    for x, y in ((-5, 6), (5, 9), (-4, 15), (4, 18)):
        a.line(b, (x-1, y, -4), (x+1, y, -4), 'glow_eye')
        a.line(b, (x, y-1, -4), (x, y+1, -4), 'glow_eye')
    # Face stays visible below the pointed observatory hood and brass diadem.
    a.ell(b, (0, 24, 0), (4, 4, 3), 'bone')
    a.polygon(b, [(-5, 25), (0, 31), (5, 25)], 0, 4, 'wing')
    a.box(b, (-4, 26, -3), (4, 27, -2), 'accent')
    face(b, 24, -3)
    a.line(b, (0, 22, -3), (0, 19, -4), 'light')
    for s, label in ((-1, 'l'), (1, 'r')):
        arm = {}
        a.box(arm, (-2, -6, -2), (3, 0, 3), 'wing')
        a.box(arm, (-2, -7, -2), (3, -5, 3), 'accent')
        a.box(arm, (-1, -9, -2), (2, -7, 1), 'bone')
        add(p, l, 'arm_'+label, arm, (s*6, 21, 0), 'arm', s)
        cape = {}
        a.polygon(cape, [(-2, 0), (2, 0), (4, -16), (-3, -18)], 0, 2, 'shade')
        a.line(cape, (0, -2, -1), (0, -16, -1), 'glow_teal')
        add(p, l, 'cloak_'+label, cape, (s*5, 21, 4), 'wing', s)
    scope = {}
    a.box(scope, (-2, -2, -10), (3, 3, 3), 'accent')
    for z in (-10, -5, 1): a.box(scope, (-3, -3, z), (4, 4, z+1), 'bone')
    a.box(scope, (-2, -2, -11), (3, 3, -10), 'dark')
    a.box(scope, (-1, -1, -12), (2, 2, -11), 'glow_core')
    add(p, l, 'telescope', scope, (0, -7, -2), 'sway', parent_limb='arm_r')
    for i, (x, z, y) in enumerate(((11, 0, 28), (-10, -4, 26), (-3, 11, 28))):
        moon = {}
        a.ell(moon, (x, 0, z), (2, 2, 2), 'bone')
        moon[x, 1, z-1] = 'shade'
        moon[x-1, 0, z-2] = 'glow_core'
        add(p, l, f'moon_{i}', moon, (0, y, 0), '')
    return b, p, l


DEFINITIONS = [
    ('shard_wisp', 'Shard Wisp', 'Shardheart', .7, 'orbit', .18, 'wraith', wisp, False, True),
    ('prism_crawler', 'Prism Crawler', 'Shardheart', 1.1, 'dart', 0, 'cantor', crawler, False, True),
    ('resonance_sentinel', 'Resonance Sentinel', 'Shardheart', 2.4, 'stationary', 0, 'cantor', guardian, False, True),
    ('heart_choir', 'The Heart Choir', 'Shardheart', 3.5, 'stationary', .25, 'cantor', choir, True, True),
    ('lantern_ghost', 'Lantern Ghost', 'Hollowmoon', 1.4, 'spirit', .2, 'cantor', ghost, False, True),
    ('bone_crawler', 'Bone Crawler', 'Hollowmoon', 1., 'dart', 0, 'cantor', lambda: crawler(True), False, False),
    ('grave_watcher', 'Grave Watcher', 'Hollowmoon', 2.6, 'stationary', 0, 'cantor', lambda: guardian(True), False, False),
    ('pale_astronomer', 'The Pale Astronomer', 'Hollowmoon', 3.5, 'strafe', .16, 'wraith', astronomer, True, False),
]


def assemble(body, parts, limbs):
    full, pivots = dict(body), {}
    for name, spec in limbs.items():
        parent = spec.get('parent_limb')
        assert not parent or parent in pivots, 'Parents must precede children'
        pivot = tuple(x+y for x, y in zip(spec['pivot'], pivots.get(parent, (0, 0, 0))))
        pivots[name] = pivot
        for point, color in parts[spec['part']].items():
            full[tuple(x+y for x, y in zip(point, pivot))] = color
    return full


def read_vox(path):
    data = path.read_bytes()
    assert data[:8] == b'VOX ' + struct.pack('<I', 150), path
    assert data[8:12] == b'MAIN' and struct.unpack_from('<I', data, 16)[0] == len(data)-20
    offset, size, points = 20, None, None
    while offset < len(data):
        tag, length, children = struct.unpack_from('<4sII', data, offset)
        start = offset+12
        assert children == 0 and start+length <= len(data)
        if tag == b'SIZE': size = struct.unpack_from('<III', data, start)
        if tag == b'XYZI':
            count = struct.unpack_from('<I', data, start)[0]
            assert length == 4+count*4
            points = [tuple(data[i:i+4]) for i in range(start+4, start+length, 4)]
        offset = start+length
    assert size and points and all(0 < n <= 256 for n in size), path
    assert all(all(p[k] < size[k] for k in range(3)) and p[3] > 0 for p in points), path
    assert len(set(p[:3] for p in points)) == len(points), path
    return size, points


def validate(folder, height):
    rig = json.loads((folder/'rig.json').read_text())
    geometry = {}
    for name, info in rig['parts'].items():
        voxels = {}
        for suffix, enabled in (('', info.get('solid', True)), ('_glow', info.get('glow', False))):
            if not enabled: continue
            size, points = read_vox(folder/(name+suffix+'.vox'))
            assert size == tuple(info['frame_size'][k] for k in (2, 0, 1))
            for z, x, y, color in points:
                point = tuple(q+r for q, r in zip((x, y, z), info['frame_min']))
                assert point not in voxels, 'Solid/glow overlap'
                voxels[point] = color
        assert voxels
        geometry[name] = voxels
    assert set(geometry) == {'body'} | {s['part'] for s in rig['limbs'].values()}
    full = assemble(geometry['body'], geometry, rig['limbs'])
    assert math.isclose(a.bounds(full)[1][1]*rig['voxel_size'], height, abs_tol=1e-8)
    chain = [s for s in rig['limbs'].values() if s['role'] == 'tail_chain']
    for i, spec in enumerate(chain):
        assert spec['segment'] == i and spec['segments'] == len(chain)
        assert spec.get('parent_limb') == (f'tail_{i-1}' if i else None)
    return rig


def projectiles():
    note = crystal((0, 0, 0), 2, 3, 'glow_core')
    a.line(note, (1, 0, 0), (1, 7, 0), 'glow_teal', 2)
    a.line(note, (1, 7, 0), (4, 5, 0), 'glow_eye')
    a.projectile('prism_note', 'shardheart', note, .009)
    star = {}
    a.polygon(star, [(0, 6), (2, 2), (6, 1), (3, -1), (4, -5),
                     (0, -3), (-4, -5), (-3, -1), (-6, 1), (-2, 2)], -1, 2, 'glow_core')
    a.line(star, (-2, 0, -2), (2, 0, -2), 'glow_eye')
    a.line(star, (0, -2, -2), (0, 3, -2), 'glow_eye')
    a.projectile('ghost_star', 'hollowmoon', star, .008)


def main():
    targets = [R/'creatures'/d[0] for d in DEFINITIONS]
    targets += [R/'creatures/boss_projectiles'/name for name in SHOTS]
    existing = [str(p.relative_to(R)) for p in [*targets, MANIFEST] if p.exists()]
    if existing:
        raise SystemExit('Create-only generator refuses existing outputs: '+', '.join(existing))
    authored = []
    for definition in DEFINITIONS:
        body, parts, limbs = definition[7]()
        full = assemble(body, parts, limbs)
        assert all(-16 <= x < 16 and 0 <= y < 32 and -16 <= z < 16 for x, y, z in full), definition[0]
        assert all(v and all(c in a.PAL[definition[2].lower()] for c in v.values())
                   for v in [body, *parts.values()])
        authored.append((body, parts, limbs, full))
    records = []
    for definition, data in zip(DEFINITIONS, authored):
        name, title, biome, height, behavior, hover, style, _, god, glowing = definition
        body, parts, limbs, full = data
        scale = 8 if god else 1
        unit = height/(a.bounds(full)[1][1]*scale)
        folder = R/'creatures'/name
        if god:
            scaled = json.loads(json.dumps(limbs))
            for spec in scaled.values(): spec['pivot'] = [q*8 for q in spec['pivot']]
            a.save(name, title, biome.lower(), {'body': body, **parts}, scaled, {},
                   (0, 16, -6), unit=unit, hover=hover)
        else:
            small(name, biome.lower(), body, parts, limbs, unit, hover)
        for rig_folder in ([folder, folder/'source_32'] if god else [folder]):
            path = rig_folder/'rig.json'
            rig = json.loads(path.read_text())
            rig.update(animation_style=style, pixel_art=True, material_jitter=0.,
                       glow_strength=2.4 if glowing else 1.4,
                       bob=.035 if hover else .008, waddle=.025,
                       flap_rate=1.2, design_grid=[32, 32, 32])
            path.write_text(json.dumps(rig, indent=2)+'\n')
            validate(rig_folder, height)
        rig = validate(folder, height)
        if god:
            read_vox(folder/'model.vox')
            coarse = json.loads((folder/'source_32/rig.json').read_text())
            assert math.isclose(coarse['voxel_size'], unit*8)
            for key, spec in limbs.items():
                assert coarse['limbs'][key]['pivot'] == spec['pivot']
        record = dict(id=name, display_name=title, biome=biome, folder='creatures/'+name,
                      status='live', height_m=height, voxel_size=unit, parts=list(rig['parts']),
                      behavior=behavior, god=god, glow=glowing, design_grid=[32, 32, 32],
                      upscale=scale, variants=[],
                      tail_segments=sum(s['role'] == 'tail_chain' for s in limbs.values()))
        if god: record['poses'] = json.loads((folder/'poses.json').read_text())
        records.append(record)
        print(f'{name}: {len(rig["parts"])} parts, {height:g} m', flush=True)
    projectiles()
    for name in SHOTS:
        folder = R/'creatures/boss_projectiles'/name
        read_vox(folder/'model.vox')
        rig = json.loads((folder/'rig.json').read_text())
        assert rig['design_grid'] == 32 and rig['upscale'] == 8
    MANIFEST.write_text(json.dumps(records, indent=2)+'\n')
    assert {r['id'] for r in json.loads(MANIFEST.read_text())} == {d[0] for d in DEFINITIONS}
    for target in [*targets, MANIFEST, Path(__file__)]:
        for path in ([target] if target.is_file() else target.rglob('*')):
            if path.suffix in ('.json', '.py'):
                assert not any(chr(c) in path.read_text() for c in (0x00B7, 0x2022))
    print('Validated all rigs, serialized VOX parts, heights, masters and projectiles.')


if __name__ == '__main__':
    main()
