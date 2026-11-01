#!/usr/bin/env python3
"""Format the current runtime audit, including explicit god potion sources."""
import json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
r=json.loads((ROOT/'docs/realm_expansion/biome_enemy_report.json').read_text())
lines=[]
def add(s=''):lines.append(s)
def spirit_chances(entries):
 names={'spirit_brown_pack':'Brown','spirit_blue_pack':'Blue','spirit_purple_pack':'Purple'}
 return ', '.join(f"{names[e['pack']]} {e['chance']*100:g}%" for e in entries)+f", empty {(1-sum(e['chance'] for e in entries))*100:g}%"
add('# Realm enemy spawns — expansion 03\n')
add('Current production definitions, not the earlier staged-art plan. There are three new gods in each of the five stronghold biomes, seven new ordinary creatures, and all six batch-2 gods remain enabled. Five boss packs are also registered by the current project.\n')
add('## Spawn and persistence rules\n')
add('- Each eligible 36×36m wilderness cell has at most one seeded pack. Pack percentages below are unconditional configured probabilities per eligible cell, not respawn chances rolled every second.')
add('- The chunk-boundary bug is fixed: iteration includes the partially overlapping 36m cells, and each jittered candidate is owned by exactly one 32m streaming chunk. Whole-area and streamed results are tested for equality on three seeds.')
add('- Water, structures, road footprints, town radius +14m, and arrival/home-portal radius 26m exclude sites. Runtime placement checks the whole creature capsule against terrain and obstacles.')
add('- Gods and attached finite-pack followers do not respawn. Existing killed sites and saved finite survivors are preserved; the rebalance does not reset your realm. Ordinary standalone packs return after a complete wipe on the listed timer.')
add('- Packs generally activate at 30–36m, Bile Bandit patrols at 40m, bosses at 60m. These are streaming activation distances, not attack/aggro distances. Inactive packs can sleep beyond 70m.')
add('- New gods roll one signature permanent-stat potion at 35% for an eligible solo/top contributor (31.5% for other eligible contributors). Potions use personal blue bags. Their other loot stays G3 12%, G4 10%, exceptionally G5 0.1%, backpack 2%, HP/MP refills 40% each. Gods never drop divine, G6, G7 or G8.')
add('- Ordinary new fauna and bandits use the existing medium-creature loot table: HP refill 35%, MP refill 20%, G1 16%, G2 20%, G3 6%, G4 0.5%; no divine/stat potion/high-tier gear.')
add('- Damage is raw per projectile before defense/shielding; 150 raw against 100 defense deals 50 HP unshielded. Current gods are intentionally dangerous, with slower telegraphed attacks rather than dense instant volleys.\n')
add('## New gods and assigned potions\n')
manifest=json.loads((ROOT/'creatures/realm_expansion_03.json').read_text())
add('| Biome | God | HP | Defense | Raw damage | Potion |')
add('|---|---|---:|---:|---|---|')
for m in manifest:
 e=r['enemies'][m['id']]
 if not e['is_god']:continue
 a=e['attacks'][0]
 add(f"| {m['biome']} | {e['name']} | {e['hp']} | {e['defense']} | {a['damage_min']}–{a['damage_max']} | {', '.join(e['god_potion_stats'])} |")
add('\nAll seven permanent stats are covered directly by these gods. Older gods without an override retain their origin-biome potion selection.\n')
add('## Deep Dark patrols\n')
add('Bile Bandits are ordinary enemies: exactly three per fresh patrol, one leader and two companions. Each has 600 HP and 8 defense. They share a seeded obstacle-aware route within an 18m patrol radius, stay in Deep Dark, avoid town safety zones, and alert together within 16m. Each carries an actual warm flickering light at its voxel torch. Their 48–58 raw fireballs travel at 7.5m/s, use a 0.65s windup and 2.7s base cooldown, and illuminate nearby terrain while flying. Projectile lights are limited to 12 globally, with no dynamic shadows. Patrols respawn 240s after all three die. Their separate god neighbors remain finite.\n')
for b in r['biomes']:
 add('## '+b['name']+'\n')
 if not b['packs']:
  add('No hostile packs. Friendly residents inhabit the Tavern.' if b['name']=='The Tavern' else 'No hostile packs in Ocean.');add();continue
 add('| Pack | Cell chance | Composition | Respawn |')
 add('|---|---:|---|---|')
 for entry in b['packs']:
  pack=r['packs'][entry['pack']];parts=[]
  if 'leader' in pack:parts.append('1 '+r['enemies'][pack['leader']['enemy']]['name']+(' if ≥4 goblins' if pack['leader']['enemy']=='goblin_master' else ''))
  for m in pack['members']:
   count=str(m['min']) if m['min']==m['max'] else f"{m['min']}–{m['max']}"
   parts.append(count+' '+r['enemies'][m['enemy']]['name']+(f" ({m['chance']*100:g}% extra roll)" if 'chance' in m else ''))
  resp='Never / finite' if pack['respawn_time']<0 else f"{pack['respawn_time']:g}s"
  add(f"| {entry['pack']} | {entry['density']*100:g}% | {' + '.join(parts)} | {resp} |")
 add(f"\nTotal wilderness occupancy: **{sum(e['density'] for e in b['packs'])*100:g}%** before area exclusions.\n")
 if b['name']=='Shores':add('Tide Rocks additionally roll Shore Crabs at 85% per placed feature: 3–6 crabs, 180 HP each, 120s respawn.\n')
 if b['name'] in ['Woods','Jungle','Desert','Fosen']:add('Ruins may additionally contain one finite spirit pack: '+spirit_chances(r['spirit_packs'])+'. A spirit comes with 5–10 non-attacking Stars and 1–4 matching small Genies.\n')
 if b['name']=='Bluelay':add('Ruins instead use '+spirit_chances(r['spirit_packs_bluelay'])+'. Blue Dragon is a separate single stronghold encounter.\n')
 if b['name'] in ['Doom','Deep Desert','The Deep Dark']:add('Ruins in this biome do not add a second feature-guard spawn table.\n')
 add('Default potion signature for older gods: '+', '.join(b['god_stats'] or [b['god_stat']])+'. New gods use their explicit assignment above.\n')
add('## All enemy statistics\n')
add('| Enemy ID | Type | HP | Defense | XP | Speed m/s | Aggro m | Raw attacks | Potion override |')
add('|---|---|---:|---:|---:|---:|---:|---|---|')
for id,e in sorted(r['enemies'].items()):
 attacks='; '.join(f"{a['damage_min']}–{a['damage_max']} {a['pattern']}, {a['cooldown']:g}s" for a in e['attacks']) or ('Phase controller' if e['is_boss'] else 'None')
 add(f"| {id} | {'Boss' if e['is_boss'] else 'God' if e['is_god'] else 'Regular/helper'} | {e['hp']} | {e['defense']} | {e['xp']} | {e['speed']:g} | {e['aggro']:g} | {attacks} | {', '.join(e['god_potion_stats']) or 'Origin biome if god'} |")
add(f"\n## Fresh example realm, seed {r['example_seed']}\n")
add('These are seeded initial rosters before kills and before any runtime placement retry. Creatures include harmless Stars and companions. Only nearby chunks/packs are awake at once.\n')
add('| Biome | Planned packs | Streamed packs | God actors | All creatures |')
add('|---|---:|---:|---:|---:|')
for b in r['biomes']:
 e=r['example'].get(b['name'],{});stream=r['streamed_example'].get(b['name'],{})
 add(f"| {b['name']} | {e.get('total_packs',0)} | {stream.get('total_packs',0)} | {e.get('god_enemies',0)} | {e.get('total_enemies',0)} |")
add('\nSources: scripts/world/biomes.gd, island_generator.gd; scripts/enemies/enemies.gd, realm_enemy_expansion.gd, enemy_patrol.gd, enemy_director.gd. Native models: creatures/realm_expansion_03.json.\n')
text='\n'.join(lines)+'\n'
(ROOT/'docs/realm_expansion/BIOME_ENEMY_SPAWNS.md').write_text(text)
Path('/home/hugo/Documents/Voidrealm_textures/BIOME_ENEMY_SPAWNS.txt').write_text(text)
print('Updated production spawn report with',len(manifest),'new creatures.')
