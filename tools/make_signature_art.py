#!/usr/bin/env python3
"""8x8 icons and editable Pixelorama sources for items/signatures.json.

The standalone silhouettes and palettes differ from the Divine set pieces.
Run python3 -B tools/make_signature_art.py, then make_equipment_models.py.
"""
from pathlib import Path
import json
from PIL import Image, ImageColor, ImageDraw
from make_surface_dungeon_icons import load_template, write_pxo
from import_textures import flatten

ROOT = Path(__file__).resolve().parents[1]
SOURCE = Path.home() / 'Documents/Voidrealm_textures'
GRIDS = {
    'Bow': [
        ('...hm...', '..hams..', '.ham.h..', 'hams.h..', 'ams..h..', '.ams.h..', '..ams...', '...so...'),
        ('..ahm...', '.ham.a..', 'ha...h..', 'am...h..', '.am..h..', '..am.h..', '...ma...', '...so...'),
        ('..ahm...', '.ham.h..', '..am.h..', '...amh..', '..am.h..', '.ham.h..', '..amo...', '...o....'),
        ('...ha...', '..hamh..', '.ham.h..', 'ham..h..', '.am..h..', '..am.h..', '...mh...', '...o....'),
    ],
    'Wand': [
        ('....hah.', '...hamah', '....hah.', '....ah..', '...am...', '..am....', '.am.....', 'so......'),
        ('...a.ha.', '....hamh', '....amah', '....ha..', '...am...', '..am....', '.am.....', 'so......'),
        ('....hh..', '...ahma.', '...h.a.h', '....ahh.', '...am...', '..am....', '.am.....', 'so......'),
        ('....a.h.', '...hamah', '....ama.', '....hh..', '...am...', '..am....', '.am.....', 'so......'),
    ],
    'Trident': [
        ('.h.a..h.', '.a.ham..', '.maham..', '..amha..', '...ah...', '...am...', '..am....', '..so....'),
        ('.h.h..h.', '.a.am.a.', '.maham..', '..amha..', '...ha...', '...am...', '..am....', '..so....'),
        ('...h..h.', '.h.ah.a.', '.amham..', '..amha..', '...ha...', '...am...', '..am....', '..so....'),
        ('.h.a..h.', '.ahhm.a.', '.maham..', '..ahma..', '...ah...', '...am...', '..am....', '..so....'),
    ],
    'Cloak': [('..hmmh..', '.ahhhha.', '.amooma.', '..maam..', '.amhamh.', '.amahma.', 'hamhhamh', 'omaaamso')],
    'Robe': [('..ahha..', '.hammha.', 'hamhhamh', 'amsaasma', 'o.amma.o', '.ahmmah.', 'hammamah', 'omaammso')],
    'Talisman': [('..shhs..', '..s..s..', '...hh...', '..hahh..', '.hasmah.', '.hamsah.', '..hhhs..', '...so...')],
    'Crystal': [('...hh...', '..hhaa..', '.hhamaa.', '.hammam.', '.sammms.', '..samso.', '...ss...', '...o....')],
    'Eye': [('........', '..ahha..', '.hammah.', 'hamooamh', '.hammah.', '..ahha..', '...oo...', '........')],
}


def draw(row):
    main, accent = [ImageColor.getrgb('#'+c) for c in row['colors']]
    colors = {'m': (*main, 255), 'a': (*accent, 255), 'h': (*(round(c*.45+255*.55) for c in accent), 255),
              's': (*(round(c*.6) for c in main), 255), 'o': (*(round(c*.28) for c in main), 255), '.': (0,0,0,0)}
    variants = GRIDS[row['kind']]
    rows = variants[int(row['appearance']['form']) % len(variants)]
    assert len(rows)==8 and all(len(r)==8 for r in rows), row['id']
    image = Image.new('RGBA', (8,8))
    image.putdata([colors[p] for r in rows for p in r])
    return image


def main():
    rows = json.loads((ROOT/'items/signatures.json').read_text())['items']
    entries, metadata = load_template()
    sheet = Image.new('RGB', (8*180, ((len(rows)+7)//8)*148), '#141b2b')
    ink = ImageDraw.Draw(sheet)
    folders = {}
    for i, row in enumerate(rows):
        image = draw(row)
        folder = SOURCE / ('Artifacts' if row['rarity']=='A' else 'Legendary') / ('Ash' if row['id']=='L_wand_thewandofash' else row['boss'])
        folder.mkdir(parents=True, exist_ok=True)
        image.save(folder/(row['id']+'.png'))
        write_pxo(folder/(row['id']+'.pxo'), image, row['name'], entries, metadata)
        assert flatten(folder/(row['id']+'.pxo')).tobytes()==image.tobytes()
        image.save(ROOT/'items/textures'/(row['id']+'.png'))
        folders.setdefault(folder, []).append(row)
        x,y=i%8*180,i//8*148
        big=image.resize((96,96), Image.Resampling.NEAREST)
        sheet.paste(big,(x+40,y+8),big)
        ink.text((x+4,y+113),row['rarity']+' '+row['name'],fill='#65ef89' if row['rarity']=='A' else '#4ba9ff')
    sheet.save('/home/hugo/tmp/signature_icons.png')
    for folder, items in folders.items():
        lines = [items[0]['rarity']+' EQUIPMENT', 'Chest: Black (personal, soulbound)',
                 'Inventory glow: '+('green' if items[0]['rarity']=='A' else 'blue'), '']
        for row in items:
            lines += [row['id']+' | '+row['name'], 'Source: '+row['boss'],
                      f"Base drop chance: {row['chance']*100:g}% before contributor share and loot modifiers.", row['lore'], '']
        (folder/'USAGE_AND_DROPS.txt').write_text('\n'.join(lines))
    print(f'Authored and verified {len(rows)} signature icons and Pixelorama sources')


if __name__=='__main__':
    main()
