#!/usr/bin/env python3
"""Build weapon variants from the original authored rigs; icons supply palettes.
Run from any directory. Pillow is only needed by this offline art tool.
"""
import json
from collections import Counter
from pathlib import Path
from PIL import Image
import make_hero
from make_player_class_models import write_vox, bounds, wizard, merrow, COMMON, SPECS
ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'characters/equipment'
SIGNATURES = {row['id']: row for row in json.loads((ROOT/'items/signatures.json').read_text())['items']}


def colors(im):
    return Counter(im.getpixel((x, y))[:3] for y in range(im.height)
                   for x in range(im.width) if im.getpixel((x, y))[3] > 127)


def weapon_template(kind):
    if kind == 'bow':
        return ({p: c for p, c in make_hero.bow().items() if c != 'string'},
                dict(make_hero.PALETTE), (.9, 1, .8), (-.45, -.5, -.4))
    name, builder = ('wizard', wizard) if kind == 'wand' else ('merrow', merrow)
    palette = dict(COMMON)
    palette.update({k: v for k, v in SPECS[name].items() if k != 'title'})
    return dict(builder()[1]), palette, (.9, 1, .9), (-.45, 0, -.45)


def weapon_variant(kind, grade, item_id, counts):
    voxels, palette, scale, offset = weapon_template(kind)
    # G1 is the original sculpt, palette and fitting, shared by all wand users.
    if grade == 'G1':
        return voxels, palette, scale, offset
    ranked = [c for c, _ in counts.most_common() if max(c) > 50] or [c for c, _ in counts.most_common()]
    chromatic = [c for c in ranked if max(c)-min(c) > 35]
    finish = max(chromatic, key=lambda c: max(c)-min(c)) if chromatic else ranked[0]
    bright = tuple(min(255, int(v*.65+255*.35)) for v in finish)
    signature = SIGNATURES.get(item_id)
    if signature:
        finish = tuple(bytes.fromhex(signature['appearance']['main']))
        bright = tuple(bytes.fromhex(signature['appearance']['accent']))
    shade = tuple(int(v*.62) for v in finish)
    palette.update(finish=finish, trim=bright, finish_shade=shade, glow=bright)
    roles = {'bow': ['bow'], 'wand': ['gold', 'gold_dark'],
             'trident': ['gold', 'gold_dark', 'glass']}[kind]
    for pos, role in list(voxels.items()):
        if role in roles:
            voxels[pos] = 'finish_shade' if role == 'gold_dark' else 'finish'
    ornate = grade in ['D', 'L', 'A', 'G7', 'G8']
    if ornate:
        # Keep the grip and animated string tips fixed. Small forged details
        # grow out of the existing limbs/crown instead of enlarging the weapon.
        if kind == 'bow':
            for side in [-1, 1]:
                voxels[0, side*4, 0] = 'trim'
                voxels[0, side*5, 0] = 'finish'
                voxels[0, side*4, -1] = 'glow' if grade in ['D', 'L', 'A'] else 'trim'
        elif kind == 'wand':
            for x in [-2, 2]:
                voxels[x, 12, 0] = 'finish'
                voxels[x, 13, 0] = 'trim'
            voxels[0, 14, 0] = 'glow'
            for y in [-2, 5]:
                voxels[0, y, 0] = 'finish_shade'
            if any(theme in item_id for theme in ['frost', 'storm', 'jade']):
                voxels[0, 15, 0] = 'glow'
            if 'mycelium' in item_id:
                for x in range(-2, 3): voxels[x, 13, 0] = 'finish'
        else:
            for side in [-1, 1]:
                voxels[side*3, 10, 0] = 'trim'
                voxels[side*2, 12, 0] = 'glow'
            voxels[0, 13, 0] = 'trim'
            voxels[0, 14, 0] = 'glow'
            voxels[0, 4, 0] = 'finish_shade'
    if signature:
        form = int(signature['appearance']['form'])
        if kind == 'bow':
            for side in [-1, 1]:
                for y in range(3, 6):
                    voxels[(1 if form % 2 else -1), side*y, 1] = 'trim'
                voxels[0, side*5, -1] = 'glow'
                voxels[(1 if form < 2 else -1), side*4, -1] = 'glow'
        elif kind == 'wand':
            for side in [-1, 1]:
                voxels[side*3, 12, 0] = 'trim'
                voxels[side*3, 13+(form % 2), 0] = 'glow'
            voxels[0, 15, 0] = 'glow'
            if form >= 2:
                voxels[-1, 14, 0] = 'trim'
                voxels[1, 14, 0] = 'trim'
        else:
            for side in [-1, 1]:
                voxels[side*3, 11, 0] = 'trim'
                voxels[side*3, 12+(form % 2), 0] = 'glow'
            voxels[0, 15, 0] = 'glow'
            voxels[-1 if form < 2 else 1, 14, 0] = 'trim'
    return voxels, palette, scale, offset


def main():
    OUT.mkdir(exist_ok=True)
    profiles = {}
    for path in sorted((ROOT/'items/textures').glob('*.png')):
        bits = path.stem.split('_')
        if len(bits) < 2 or bits[1] not in ['bow', 'wand', 'trident', 'robe', 'cloak']:
            continue
        kind = bits[1]
        counts = colors(Image.open(path).convert('RGBA'))
        ornate = bits[0] in ['D', 'L', 'A', 'G7', 'G8']
        if kind in ['robe', 'cloak']:
            visible = [c for c, n in counts.most_common() if max(c) > 45]
            primary = visible[0]
            accent = max(visible, key=lambda c: (max(c)-min(c))*.7+max(c)*.3)
            if path.stem in ['G7_cloak', 'D_cloak_blood', 'D_cloak_goldslinger',
                             'D_cloak_theblue', 'D_cloak_thevoid',
                             'D_robe_robeofpower', 'D_robe_ofthegalaxy']:
                primary = counts.most_common()[0][0]
            overrides = {'G2_cloak': (129, 86, 58), 'G3_cloak': (35, 51, 47),
                         'G4_cloak': (66, 57, 35), 'G5_cloak': (63, 63, 63),
                         'G6_cloak': (35, 45, 51)}
            profiles[path.stem] = dict(main=overrides.get(path.stem, primary),
                                       accent=accent, ornate=ornate)
            if path.stem in SIGNATURES:
                spec = SIGNATURES[path.stem]['appearance']
                profiles[path.stem].update(main=list(bytes.fromhex(spec['main'])), accent=list(bytes.fromhex(spec['accent'])),
                                          signature=True, form=spec['form'], body_glow=spec.get('body_glow', 0.0))
            continue
        v, palette, scale, offset = weapon_variant(kind, bits[0], path.stem, counts)
        lo, size = bounds(v)
        glow = {p: c for p, c in v.items() if c == 'glow'}
        write_vox(OUT/(path.stem+'.vox'), {p: c for p, c in v.items() if c != 'glow'}, palette, lo, size)
        if glow:
            write_vox(OUT/(path.stem+'_glow.vox'), glow, palette, lo, size)
        else:
            (OUT/(path.stem+'_glow.vox')).unlink(missing_ok=True)
            (OUT/(path.stem+'_glow.vox.import')).unlink(missing_ok=True)
        profiles[path.stem] = dict(offset=[lo[i]*scale[i]+offset[i] for i in range(3)],
                                   scale=scale, glow=bool(glow))
    (OUT/'profiles.json').write_text(json.dumps(profiles, indent=2)+'\n')
    print(f'Generated {len(profiles)} equipment appearances from original weapon templates')

if __name__ == '__main__':
    main()
