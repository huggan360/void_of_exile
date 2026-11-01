#!/usr/bin/env python3
"""Documents divine set ownership and every boss's live drop table for the
texture folder. Reads the live game tables; never changes gameplay or sprites.
Run after changing Items.DIVINE_SETS, Items.BOSS_DIVINE_SET or boss loot."""
import json, re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TEXTURES = Path('/home/hugo/Documents/Voidrealm_textures')
DIVINE = TEXTURES / 'Divine'
BOSSES = {  # set -> (boss, stronghold, biome, boss id, model folder)
    'The_Blue': ('Blue Dragon', 'The Azure Crucible', 'Bluelay', 'blue_dragon', 'creatures/blue_dragon/'),
    'Frost': ('Rimeheart Prism', 'Crown of the Rime', 'Fosen', 'rimeheart_prism', 'creatures/rimeheart_prism/'),
    'Satan': ('Vharok, the Cinder Tyrant', 'The Cinder Bastion', 'Lava (Doom)', 'vharok', 'creatures/vharok_cinder_tyrant/'),
    'Holy_Divine': ('Aureate Scarab Regent', 'Court of the Sun', 'Desert', 'scarab_regent', 'creatures/aureate_scarab_regent/'),
    'Void': ('The Hollow Crown', 'The Hollow Throne', 'Deep Dark', 'hollow_crown', 'creatures/hollow_crown/'),
}
ALIASES = {'crucefix of the blue': 'D_bonus_crucifix_oftheblue', 'croucefix of satan': 'D_bonus_crucifix_ofsatan',
           'flame of the divine': 'D_bonus_flame_ofthedivine'}
POTIONS = {  # boss id -> top/solo chance per stat potion (others get 90%)
    'blue_dragon': dict(attack=50, defense=50, speed=50, dexterity=50, magic=50, hp=50, mp=50),
    'rimeheart_prism': dict(attack=15, defense=15, speed=15, dexterity=75, magic=75, hp=15, mp=15),
    'vharok': dict(attack=75, defense=75, speed=15, dexterity=15, magic=15, hp=15, mp=15),
    'scarab_regent': dict(attack=15, defense=75, speed=25, dexterity=15, magic=15, hp=35, mp=15),
    'hollow_crown': dict(attack=15, defense=15, speed=50, dexterity=15, magic=25, hp=15, mp=75),
}
POTION_NAMES = dict(attack='Attack', defense='Defense', speed='Speed', dexterity='Dexterity', magic='Magic', hp='Maximum HP', mp='Maximum MP')

# The documentation must agree with the game's live tables.
items_src = (ROOT / 'scripts/game/items.gd').read_text()
sets_block = items_src.split('const DIVINE_SETS := {', 1)[1].split('\n}', 1)[0]
LIVE = {}
for name in BOSSES:
    if name == 'The_Blue':
        LIVE[name] = re.findall(r'"(D_[^"]+)"', items_src.split('const BLUE_DIVINE_IDS :=', 1)[1].split(']', 1)[0])
    else:
        LIVE[name] = re.findall(r'"(D_[^"]+)"', sets_block.split(name + ' = [', 1)[1].split(']', 1)[0])
bosses_src = (ROOT / 'scripts/enemies/realm_bosses.gd').read_text()
assert 'b.loot_threshold = 0.04' in bosses_src and 'chance = 0.03' in bosses_src


def boss_table(boss_id):
    blue = boss_id == 'blue_dragon'
    rows = ['HP refill elixir: 100% (gray bag, public)', 'MP refill elixir: 100% (gray bag, public)']
    if blue:
        rows += ['One random G6 item: 50% top/solo, 45% other eligible (purple bag, personal)',
                 'G4 / G5 / backpack: 0%']
    else:
        rows += ['One random G4 item: 30% (green bag, public)',
                 'One random G5 item: 15% top/solo, 13.5% other eligible (red bag, personal)',
                 'One random G6 item: 50% top/solo, 45% other eligible (purple bag, personal)',
                 'Backpack: 5% (public)']
    rows.append('G7 / G8: never in the realm')
    rows.append('Permanent stat potions (blue bag, personal; top/solo, others get 90%):')
    for stat, pct in POTIONS[boss_id].items():
        rows.append(f'  {POTION_NAMES[stat]}: {pct}% / {pct * 0.9:g}%')
    return rows


index = ['DIVINE SET OWNERSHIP AND DROPS', 'Updated: 2026-10-31', '',
         'LIVE = drops in the game now, from the named stronghold boss. AVAILABLE = not assigned; free for a future encounter.',
         'Every divine item rolls 3.00% on its own, per eligible player, per boss kill: rolls are independent, so several',
         'divine items can drop together and 3% is NOT split across the set. Divine items go in personal WHITE bags (soulbound).',
         'Eligibility: deal at least 4% of the boss\'s scaled maximum health (health is scaled once when it hatches:',
         '+20% per extra player). Shell, tower, guard and minion damage does not count. Divine rolls stay 3% for every eligible',
         'player; only personal non-divine rewards drop to 90% for non-top contributors.',
         'Shells, conduits, Sentinels, Dawn Scarabs, Mirror Shades, shardlings and pact mites drop nothing and give no XP.',
         'No god or ordinary enemy drops divine items. An item with PNG and PXO is counted once; original spelling kept.', '']
records = []
for folder in sorted(p for p in DIVINE.iterdir() if p.is_dir()):
    sources = sorted(folder.glob('*.pxo'))
    stems = {p.stem for p in sources}
    sources += sorted(p for p in folder.glob('*.png') if p.stem not in stems)
    if not sources:
        continue
    live = folder.name in BOSSES
    boss, fort, biome, boss_id, art = BOSSES.get(folder.name, ('None', 'None', 'None', '', 'none'))
    text = [f'DIVINE SET: {folder.name}', 'STATUS: ' + ('LIVE' if live else 'AVAILABLE / UNASSIGNED'),
            f'Dropped by: {boss}' + (f' at {fort} ({biome})' if live else ''), f'Boss model: {art}', '']
    item_records = []
    for source in sources:
        runtime = ALIASES.get(source.stem, source.stem if source.stem.startswith('D_') else None)
        if live:
            assert runtime in LIVE[folder.name], f'{runtime} missing from Items.DIVINE_SETS'
            text.append(f'{source.name} | LIVE 3.00% per eligible player | runtime id {runtime}' +
                        ('  (alias for the legacy filename)' if runtime != source.stem else ''))
        else:
            text.append(f'{source.name} | 0% | unassigned')
        item_records.append(dict(source_file=source.name, runtime_id=runtime, live_chance=0.03 if live else 0.0,
                                 planned_chance=0.03 if live else None))
    if live:
        chance = 100 * (1 - 0.97 ** len(sources))
        text += ['', f'At 3% per item across {len(sources)} items: {chance:.2f}% chance of at least one divine item per eligible kill.',
                 '', f'{boss}: the rest of its rewards (separate rolls):'] + ['  ' + r for r in boss_table(boss_id)]
    else:
        text += ['', 'UNUSED: no realm boss claims this set.']
    (folder / 'USAGE_AND_DROPS.txt').write_text('\n'.join(text) + '\n')
    index.append(f'{folder.name}: ' + (f'LIVE | {boss} | {fort} | {biome} | {len(sources)} items | 3% each'
                                       if live else f'AVAILABLE | {len(sources)} items | 0%'))
    records.append(dict(set=folder.name, status='LIVE' if live else 'AVAILABLE / UNASSIGNED', boss=boss, biome=biome,
                        boss_id=boss_id, items=item_records))
index += ['', 'Legacy filename aliases: ' + ', '.join(f'"{k}" -> {v}' for k, v in ALIASES.items()), '',
          'Per-set details and each boss\'s full reward table: Divine/<set>/USAGE_AND_DROPS.txt',
          'Runtime sources: scripts/game/items.gd (DIVINE_SETS, BOSS_DIVINE_SET), scripts/enemies/realm_bosses.gd,',
          'scripts/enemies/enemies.gd (Blue Dragon), scripts/loot/loot.gd.']
text = '\n'.join(index) + '\n'
(TEXTURES / 'DIVINE_SET_USAGE.txt').write_text(text)
(DIVINE / 'SET_USAGE_INDEX.txt').write_text(text)
(ROOT / 'creatures/staging/realm_bosses_01/divine_set_assignments.json').write_text(json.dumps(records, indent=2) + '\n')
print('Documented', len(records), 'sets;', sum(1 for r in records if r['status'] == 'LIVE'), 'live.')
