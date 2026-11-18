#!/usr/bin/env python3
"""Check the actual emitted assets, not only the offline sculpt primitives."""
import json
import struct
from pathlib import Path

from make_equipment_models import OUT, ROOT, colors, weapon_template, weapon_variant
from PIL import Image


def read_vox(path, profile):
    data = path.read_bytes()
    start = data.index(b'XYZI') + 12
    count, = struct.unpack_from('<I', data, start)
    offset = weapon_template('wand')[3]
    lo = [round((profile['offset'][i]-offset[i])/profile['scale'][i]) for i in range(3)]
    return {(x+lo[0], y+lo[1], z+lo[2]): c
            for z, x, y, c in struct.iter_unpack('BBBB', data[start+4:start+4+count*4])}


def main():
    profiles = json.loads((OUT/'profiles.json').read_text())
    _, _, original_scale, _ = weapon_template('wand')
    fingerprints = set()
    items = sorted((ROOT/'items/textures').glob('*_wand*.png'))
    for path in items:
        name = path.stem
        profile = profiles[name]
        assert tuple(profile['scale']) == original_scale, name + ': scale changes grip'
        solid = read_vox(OUT/(name+'.vox'), profile)
        glow = read_vox(OUT/(name+'_glow.vox'), profile) if profile['glow'] else {}
        assert not (solid.keys() & glow.keys()), name + ': overlapping glow faces'
        merged = solid | glow
        generated, palette, _, _ = weapon_variant('wand', name.split('_')[0], name, colors(Image.open(path).convert('RGBA')))
        if name == 'G1_wand':
            assert min(palette['finish']) > 210, 'G1 pearl crown took the shaft color'
        assert merged.keys() == generated.keys(), name + ': emitted geometry differs'
        for p, role in generated.items():
            x, y, z = p
            assert generated.get((-z, y, x)) == role, name + ': rotational asymmetry'
            assert generated.get((-x, y, z)) == role, name + ': mirror asymmetry'
        head = {p for p in merged if p[1] >= 8}
        assert max(p[2] for p in head)-min(p[2] for p in head) >= 4, name + ': flat head'
        # Every authored head voxel connects to the shaft, including glow parts.
        reached = {(0, -3, 0)}
        todo = list(reached)
        while todo:
            x, y, z = todo.pop()
            for p in [(x+1,y,z),(x-1,y,z),(x,y+1,z),(x,y-1,z),(x,y,z+1),(x,y,z-1)]:
                if p in merged and p not in reached:
                    reached.add(p)
                    todo.append(p)
        assert reached == merged.keys(), name + ': detached head detail'
        # Hand, shaft length and contact point remain at their authored origin.
        assert {(x,y,z) for x,y,z in merged if y < 8} == {(0,y,0) for y in range(-3,8)}, name + ': grip changed'
        fingerprints.add(tuple(sorted((p, generated[p]) for p in head)))
    print(f'Wand sculpts: {len(items)} assets checked, {len(fingerprints)} distinct crowns; solid, connected, symmetric on every side')


if __name__ == '__main__':
    main()
