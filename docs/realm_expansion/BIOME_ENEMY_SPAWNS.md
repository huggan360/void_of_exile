# Realm enemy spawns — expansion 03

Current production definitions, not the earlier staged-art plan. There are three new gods in each of the five stronghold biomes, seven new ordinary creatures, and all six batch-2 gods remain enabled. Five boss packs are also registered by the current project.

## Spawn and persistence rules

- Each eligible 36×36m wilderness cell has at most one seeded pack. Pack percentages below are unconditional configured probabilities per eligible cell, not respawn chances rolled every second.
- The chunk-boundary bug is fixed: iteration includes the partially overlapping 36m cells, and each jittered candidate is owned by exactly one 32m streaming chunk. Whole-area and streamed results are tested for equality on three seeds.
- Water, structures, road footprints, town radius +14m, and arrival/home-portal radius 26m exclude sites. Runtime placement checks the whole creature capsule against terrain and obstacles.
- Gods and attached finite-pack followers do not respawn. Existing killed sites and saved finite survivors are preserved; the rebalance does not reset your realm. Ordinary standalone packs return after a complete wipe on the listed timer.
- Packs generally activate at 30–36m, Bile Bandit patrols at 40m, bosses at 60m. These are streaming activation distances, not attack/aggro distances. Inactive packs can sleep beyond 70m.
- New gods roll one signature permanent-stat potion at 35% for an eligible solo/top contributor (31.5% for other eligible contributors). Potions use personal blue bags. Their other loot stays G3 12%, G4 10%, exceptionally G5 0.1%, backpack 2%, HP/MP refills 40% each. Gods never drop divine, G6, G7 or G8.
- Ordinary new fauna and bandits use the existing medium-creature loot table: HP refill 35%, MP refill 20%, G1 16%, G2 20%, G3 6%, G4 0.5%; no divine/stat potion/high-tier gear.
- Damage is raw per projectile before defense/shielding; 150 raw against 100 defense deals 50 HP unshielded. Current gods are intentionally dangerous, with slower telegraphed attacks rather than dense instant volleys.

## New gods and assigned potions

| Biome | God | HP | Defense | Raw damage | Potion |
|---|---|---:|---:|---|---|
| doom | Slag Seraph | 3900 | 14 | 165–185 | attack |
| doom | Obsidian Ram | 5200 | 24 | 185–205 | defense |
| doom | Ember Lich | 3600 | 12 | 160–180 | magic |
| fosen | Aurora Sentinel | 4100 | 20 | 150–170 | magic |
| fosen | Hoarfrost Owl | 3100 | 10 | 145–165 | dexterity |
| fosen | Icebound Colossus | 5400 | 25 | 175–195 | hp |
| blue | Prism Ray | 3000 | 10 | 145–165 | dexterity |
| blue | Runic Archivist | 3800 | 16 | 155–175 | magic |
| blue | Azure Medusa | 3500 | 12 | 140–160 | mp |
| desert | Sun Jackal | 2900 | 10 | 135–155 | speed |
| desert | Dune Monolith | 4500 | 24 | 155–175 | hp |
| desert | Glass Scorpion | 3700 | 18 | 145–165 | defense |
| dark | Umbral Reaper | 4200 | 16 | 165–185 | speed |
| dark | Amethyst Widow | 3900 | 18 | 155–175 | defense |
| dark | Nightbell Idol | 4400 | 20 | 150–170 | mp |

All seven permanent stats are covered directly by these gods. Older gods without an override retain their origin-biome potion selection.

## Deep Dark patrols

Bile Bandits are ordinary enemies: exactly three per fresh patrol, one leader and two companions. Each has 600 HP and 8 defense. They share a seeded obstacle-aware route within an 18m patrol radius, stay in Deep Dark, avoid town safety zones, and alert together within 16m. Each carries an actual warm flickering light at its voxel torch. Their 48–58 raw fireballs travel at 7.5m/s, use a 0.65s windup and 2.7s base cooldown, and illuminate nearby terrain while flying. Projectile lights are limited to 12 globally, with no dynamic shadows. Patrols respawn 240s after all three die. Their separate god neighbors remain finite.

## The Tavern

No hostile packs. Friendly residents inhabit the Tavern.

## Ocean

No hostile packs in Ocean.

## Shores

| Pack | Cell chance | Composition | Respawn |
|---|---:|---|---|
| tide_snail_pack | 18% | 2–4 Tide Snail | 120s |

Total wilderness occupancy: **18%** before area exclusions.

Tide Rocks additionally roll Shore Crabs at 85% per placed feature: 3–6 crabs, 180 HP each, 120s respawn.

Default potion signature for older gods: dexterity. New gods use their explicit assignment above.

## Woods

| Pack | Cell chance | Composition | Respawn |
|---|---:|---|---|
| goblin_pack | 26% | 1 Goblin Master if ≥4 goblins + 3–10 Goblin | 120s |
| sporeback_pack | 12% | 2–4 Sporeback | 150s |
| cinder_beetle_pack | 10% | 1–3 Cinder Beetle | 180s |
| thorn_hopper_pack | 12% | 2–4 Thorn Hopper | 150s |
| bramble_fox_pack | 12% | 2–3 Bramble Fox | 150s |
| moss_tortoise_pack | 10% | 1–2 Moss Tortoise | 180s |

Total wilderness occupancy: **82%** before area exclusions.

Ruins may additionally contain one finite spirit pack: Brown 13.5%, Blue 3.6%, Purple 1.5%, empty 81.4%. A spirit comes with 5–10 non-attacking Stars and 1–4 matching small Genies.

Default potion signature for older gods: speed. New gods use their explicit assignment above.

## Jungle

| Pack | Cell chance | Composition | Respawn |
|---|---:|---|---|
| green_dragon_pack | 20% | 1 Green Dragon + 1 Green Dragon (30% extra roll) | 240s |
| thorn_hopper_pack | 16% | 2–4 Thorn Hopper | 150s |
| vine_mantis_pack | 18% | 2–3 Vine Mantis | 180s |

Total wilderness occupancy: **54%** before area exclusions.

Ruins may additionally contain one finite spirit pack: Brown 13.5%, Blue 3.6%, Purple 1.5%, empty 81.4%. A spirit comes with 5–10 non-attacking Stars and 1–4 matching small Genies.

Default potion signature for older gods: dexterity. New gods use their explicit assignment above.

## Desert

| Pack | Cell chance | Composition | Respawn |
|---|---:|---|---|
| sand_scorpion_pack | 18% | 1 Sand Scorpion + 1 Sand Scorpion (20% extra roll) | 150s |
| black_scorpion_pack | 5% | 1 Black Scorpion | 300s |
| sun_jackal_pack | 12% | 1 Sun Jackal | Never / finite |
| dune_monolith_pack | 12% | 1 Dune Monolith | Never / finite |
| glass_scorpion_pack | 12% | 1 Glass Scorpion | Never / finite |
| dune_crawler_pack | 10% | 2–4 Dune Crawler | 180s |

Total wilderness occupancy: **69%** before area exclusions.

Ruins may additionally contain one finite spirit pack: Brown 13.5%, Blue 3.6%, Purple 1.5%, empty 81.4%. A spirit comes with 5–10 non-attacking Stars and 1–4 matching small Genies.

Default potion signature for older gods: defense, hp. New gods use their explicit assignment above.

## Doom

| Pack | Cell chance | Composition | Respawn |
|---|---:|---|---|
| basalt_bulwark_pack | 11% | 1 Basalt Bulwark + 2–3 Ember Mite | Never / finite |
| furnace_maw_pack | 11% | 1 Furnace Maw | Never / finite |
| cinder_oracle_pack | 11% | 1 Cinder Oracle + 2–3 Ember Mite | Never / finite |
| spirit_purple_pack | 1.5% | 1 Purple Spirit + 5–10 Star + 1–4 Genie | Never / finite |
| slag_seraph_pack | 10% | 1 Slag Seraph | Never / finite |
| obsidian_ram_pack | 10% | 1 Obsidian Ram | Never / finite |
| ember_lich_pack | 10% | 1 Ember Lich | Never / finite |
| ember_mite_pack | 10% | 2–4 Ember Mite | 180s |

Total wilderness occupancy: **74.5%** before area exclusions.

Ruins in this biome do not add a second feature-guard spawn table.

Default potion signature for older gods: attack, defense. New gods use their explicit assignment above.

## Fosen

| Pack | Cell chance | Composition | Respawn |
|---|---:|---|---|
| frost_moth_pack | 12% | 1–2 Frost Moth | Never / finite |
| rime_stag_pack | 10% | 1 Rime Stag + 2–3 Rime Skitter | Never / finite |
| glacier_hermit_pack | 10% | 1 Glacier Hermit + 2–3 Rime Skitter | Never / finite |
| hail_harrier_pack | 10% | 1 Hail Harrier + 2–3 Snow Wisp | Never / finite |
| aurora_sentinel_pack | 9% | 1 Aurora Sentinel | Never / finite |
| hoarfrost_owl_pack | 9% | 1 Hoarfrost Owl | Never / finite |
| icebound_colossus_pack | 9% | 1 Icebound Colossus | Never / finite |
| rime_skitter_pack | 5% | 2–4 Rime Skitter | 180s |
| snow_wisp_pack | 5% | 2–4 Snow Wisp | 180s |

Total wilderness occupancy: **79%** before area exclusions.

Ruins may additionally contain one finite spirit pack: Brown 13.5%, Blue 3.6%, Purple 1.5%, empty 81.4%. A spirit comes with 5–10 non-attacking Stars and 1–4 matching small Genies.

Default potion signature for older gods: magic, dexterity. New gods use their explicit assignment above.

## Bluelay

| Pack | Cell chance | Composition | Respawn |
|---|---:|---|---|
| ruin_watcher_pack | 22% | 1–2 Ruin Watcher | Never / finite |
| blue_genie_pack | 10% | 1 Blue Genie + 3–6 Star | Never / finite |
| spirit_blue_pack | 2.1% | 1 Blue Spirit + 5–10 Star + 1–4 Genie | Never / finite |
| prism_ray_pack | 11% | 1 Prism Ray | Never / finite |
| runic_archivist_pack | 11% | 1 Runic Archivist | Never / finite |
| azure_medusa_pack | 11% | 1 Azure Medusa | Never / finite |
| tide_snail_pack | 6% | 2–4 Tide Snail | 120s |

Total wilderness occupancy: **73.1%** before area exclusions.

Ruins instead use Brown 13.5%, Blue 6%, Purple 1.5%, empty 79%. Blue Dragon is a separate single stronghold encounter.

Default potion signature for older gods: mp. New gods use their explicit assignment above.

## Deep Desert

| Pack | Cell chance | Composition | Respawn |
|---|---:|---|---|
| spirit_brown_pack | 7.2% | 1 Brown Spirit + 5–10 Star + 1–4 Genie | Never / finite |
| spirit_blue_pack | 4.2% | 1 Blue Spirit + 5–10 Star + 1–4 Genie | Never / finite |
| spirit_purple_pack | 3.6% | 1 Purple Spirit + 5–10 Star + 1–4 Genie | Never / finite |
| dune_crawler_pack | 20% | 2–4 Dune Crawler | 180s |

Total wilderness occupancy: **35%** before area exclusions.

Ruins in this biome do not add a second feature-guard spawn table.

Default potion signature for older gods: hp. New gods use their explicit assignment above.

## The Deep Dark

| Pack | Cell chance | Composition | Respawn |
|---|---:|---|---|
| spirit_purple_pack | 3.6% | 1 Purple Spirit + 5–10 Star + 1–4 Genie | Never / finite |
| blue_genie_pack | 4% | 1 Blue Genie + 3–6 Star | Never / finite |
| umbral_reaper_pack | 13% | 1 Umbral Reaper | Never / finite |
| amethyst_widow_pack | 13% | 1 Amethyst Widow | Never / finite |
| nightbell_idol_pack | 13% | 1 Nightbell Idol | Never / finite |
| bile_bandit_patrol | 14% | 1 Bile Bandit + 2 Bile Bandit | 240s |
| gloam_bat_pack | 11% | 3–5 Gloam Bat | 150s |

Total wilderness occupancy: **71.6%** before area exclusions.

Ruins in this biome do not add a second feature-guard spawn table.

Default potion signature for older gods: speed, mp. New gods use their explicit assignment above.

## All enemy statistics

| Enemy ID | Type | HP | Defense | XP | Speed m/s | Aggro m | Raw attacks | Potion override |
|---|---|---:|---:|---:|---:|---:|---|---|
| amethyst_widow | God | 3900 | 18 | 400 | 4.1 | 15 | 155–175 burst, 2.6s | defense |
| aurora_sentinel | God | 4100 | 20 | 400 | 2.8 | 15 | 150–170 spread, 2.4s | magic |
| azure_medusa | God | 3500 | 12 | 400 | 2.8 | 15 | 140–160 ring, 3.4s | mp |
| basalt_bulwark | God | 5500 | 28 | 500 | 2.7 | 16 | 190–210 spread, 2.2s | Origin biome if god |
| bile_bandit | Regular/helper | 600 | 8 | 65 | 3.6 | 16 | 48–58 aimed, 2.7s | Origin biome if god |
| black_scorpion | Regular/helper | 625 | 15 | 110 | 4 | 11 | 26–34 spread, 1.7s; 34–44 aimed, 3.2s | Origin biome if god |
| blue_dragon | Boss | 40000 | 20 | 4000 | 3 | 24 | Phase controller | Origin biome if god |
| blue_genie | God | 5000 | 14 | 550 | 5.5 | 15 | 165–185 spread, 1.7s; 145–165 ring, 4.5s | Origin biome if god |
| bramble_fox | Regular/helper | 240 | 3 | 30 | 4 | 12 | 24–34 spread, 2.1s | Origin biome if god |
| cinder_beetle | Regular/helper | 550 | 10 | 55 | 2.7 | 14 | 36–46 aimed, 2.2s | Origin biome if god |
| cinder_oracle | God | 4800 | 14 | 500 | 4.2 | 16 | 185–205 sweep, 2.7s | Origin biome if god |
| cinder_sentinel | Regular/helper | 2000 | 14 | 0 | 4 | 60 | 45–60 spread, 2.8s | Origin biome if god |
| crab | Regular/helper | 180 | 4 | 18 | 3.6 | 11 | 15–22 spread, 1.7s | Origin biome if god |
| dawn_scarab | Regular/helper | 700 | 8 | 0 | 2.5 | 60 | 40–50 aimed, 2.4s | Origin biome if god |
| dragonling_blue | Regular/helper | 2400 | 10 | 120 | 5.5 | 40 | 32–40 aimed, 1.1s | Origin biome if god |
| dragonling_cyan | Regular/helper | 3000 | 10 | 120 | 5.5 | 40 | 32–40 aimed, 1.1s | Origin biome if god |
| dragonling_gold | Regular/helper | 3000 | 10 | 120 | 5.5 | 40 | 32–40 aimed, 1.1s | Origin biome if god |
| dragonling_pink | Regular/helper | 3000 | 10 | 120 | 5.5 | 40 | 32–40 aimed, 1.1s | Origin biome if god |
| dragonling_purple | Regular/helper | 3000 | 10 | 120 | 5.5 | 40 | 32–40 aimed, 1.1s | Origin biome if god |
| dragonling_red | Regular/helper | 3000 | 10 | 120 | 5.5 | 40 | 32–40 aimed, 1.1s | Origin biome if god |
| dune_crawler | Regular/helper | 300 | 5 | 30 | 3.2 | 12 | 28–38 aimed, 2s | Origin biome if god |
| dune_monolith | God | 4500 | 24 | 400 | 1.7 | 15 | 155–175 aimed, 2.6s | hp |
| ember_lich | God | 3600 | 12 | 500 | 3.2 | 15 | 160–180 sweep, 2.9s | magic |
| ember_mite | Regular/helper | 220 | 3 | 25 | 4.2 | 14 | 32–44 aimed, 1.8s | Origin biome if god |
| frost_moth | God | 3200 | 10 | 350 | 4.2 | 14 | 150–170 spread, 1.8s | Origin biome if god |
| furnace_maw | God | 6500 | 18 | 500 | 3.1 | 16 | 200–220 burst, 2.6s | Origin biome if god |
| genie_blue | Regular/helper | 500 | 4 | 40 | 5 | 14 | 24–32 spread, 1.2s | Origin biome if god |
| genie_brown | Regular/helper | 500 | 4 | 40 | 5 | 14 | 24–32 spread, 1.2s | Origin biome if god |
| genie_purple | Regular/helper | 500 | 4 | 40 | 5 | 14 | 24–32 spread, 1.2s | Origin biome if god |
| glacier_hermit | God | 4900 | 24 | 400 | 2.4 | 16 | 170–190 burst, 2.2s | Origin biome if god |
| glass_scorpion | God | 3700 | 18 | 400 | 3.4 | 15 | 145–165 spread, 2.5s | defense |
| gloam_bat | Regular/helper | 150 | 2 | 30 | 4.4 | 12 | 22–32 aimed, 2s | Origin biome if god |
| goblin | Regular/helper | 75 | 0 | 10 | 4.2 | 14 | 10–15 aimed, 1.5s | Origin biome if god |
| goblin_master | Regular/helper | 150 | 15 | 30 | 2.8 | 15 | 15–25 spread, 1.9s | Origin biome if god |
| green_dragon | Regular/helper | 1300 | 12 | 160 | 4.4 | 13 | 55–55 aimed, 1.4s; 55–55 spread, 4s | Origin biome if god |
| hail_harrier | God | 3400 | 10 | 400 | 5.1 | 16 | 155–175 sweep, 2.4s | Origin biome if god |
| hoarfrost_owl | God | 3100 | 10 | 400 | 4.3 | 15 | 145–165 sweep, 2.3s | dexterity |
| hollow_crown | Boss | 46000 | 18 | 4800 | 4 | 30 | Phase controller | Origin biome if god |
| icebound_colossus | God | 5400 | 25 | 400 | 2.1 | 15 | 175–195 burst, 2.9s | hp |
| mirror_shade | Regular/helper | 1000 | 8 | 0 | 4 | 60 | 40–55 spread, 2.8s | Origin biome if god |
| moss_tortoise | Regular/helper | 460 | 12 | 30 | 1.8 | 12 | 30–40 spread, 2.6s | Origin biome if god |
| nightbell_idol | God | 4400 | 20 | 400 | 2.1 | 15 | 150–170 ring, 3.6s | mp |
| obsidian_ram | God | 5200 | 24 | 500 | 3.5 | 15 | 185–205 burst, 2.7s | defense |
| pact_ember_mite | Regular/helper | 300 | 3 | 0 | 3.5 | 60 | 35–45 aimed, 2s | Origin biome if god |
| prism_ray | God | 3000 | 10 | 400 | 4.4 | 15 | 145–165 spread, 2.2s | dexterity |
| rime_skitter | Regular/helper | 220 | 3 | 25 | 4.2 | 14 | 32–44 aimed, 1.8s | Origin biome if god |
| rime_stag | God | 3800 | 12 | 400 | 4.6 | 16 | 160–180 spread, 1.9s | Origin biome if god |
| rimeheart_conduit | Regular/helper | 1200 | 10 | 0 | 4 | 60 | None | Origin biome if god |
| rimeheart_prism | Boss | 44000 | 24 | 4500 | 4 | 30 | Phase controller | Origin biome if god |
| rimeheart_shardling | Regular/helper | 500 | 5 | 0 | 3 | 60 | 35–45 aimed, 2.5s | Origin biome if god |
| ruin_watcher | God | 4200 | 16 | 420 | 0 | 14 | 160–180 burst, 2.5s; 140–160 ring, 5s | Origin biome if god |
| runic_archivist | God | 3800 | 16 | 400 | 2.6 | 15 | 155–175 cross, 2.5s | magic |
| sand_scorpion | Regular/helper | 220 | 6 | 35 | 4.6 | 9 | 20–28 spread, 1.8s | Origin biome if god |
| scarab_regent | Boss | 42000 | 28 | 4500 | 4 | 30 | Phase controller | Origin biome if god |
| slag_seraph | God | 3900 | 14 | 500 | 3.5 | 15 | 165–185 spread, 2.8s | attack |
| snow_wisp | Regular/helper | 180 | 3 | 25 | 4.2 | 14 | 32–44 aimed, 1.8s | Origin biome if god |
| spirit_blue | God | 4500 | 12 | 450 | 5.5 | 15 | 165–175 cross, 1.25s | Origin biome if god |
| spirit_brown | God | 3000 | 8 | 300 | 5 | 15 | 145–155 cross, 1.25s | Origin biome if god |
| spirit_purple | God | 6500 | 16 | 700 | 6 | 15 | 185–195 cross, 1.25s | Origin biome if god |
| sporeback | Regular/helper | 360 | 4 | 40 | 2.8 | 14 | 26–34 spread, 2.1s | Origin biome if god |
| star | Regular/helper | 40 | 0 | 4 | 5 | 12 | None | Origin biome if god |
| sun_jackal | God | 2900 | 10 | 400 | 4.6 | 15 | 135–155 burst, 2.2s | speed |
| thorn_hopper | Regular/helper | 300 | 3 | 35 | 4.2 | 14 | 24–32 burst, 2.3s | Origin biome if god |
| tide_snail | Regular/helper | 190 | 7 | 30 | 1.5 | 12 | 18–28 aimed, 2.4s | Origin biome if god |
| umbral_reaper | God | 4200 | 16 | 400 | 3.8 | 15 | 165–185 sweep, 2.8s | speed |
| vharok | Boss | 48000 | 24 | 5000 | 4 | 30 | Phase controller | Origin biome if god |
| vine_mantis | Regular/helper | 380 | 6 | 30 | 3.8 | 12 | 32–42 spread, 2.2s | Origin biome if god |

## Fresh example realm, seed 20261031

These are seeded initial rosters before kills and before any runtime placement retry. Creatures include harmless Stars and companions. Only nearby chunks/packs are awake at once.

| Biome | Planned packs | Streamed packs | God actors | All creatures |
|---|---:|---:|---:|---:|
| The Tavern | 0 | 0 | 0 | 0 |
| Ocean | 0 | 0 | 0 | 0 |
| Shores | 22 | 22 | 0 | 82 |
| Woods | 32 | 32 | 0 | 130 |
| Jungle | 2 | 2 | 0 | 4 |
| Desert | 22 | 22 | 12 | 33 |
| Doom | 44 | 44 | 37 | 80 |
| Fosen | 36 | 36 | 32 | 84 |
| Bluelay | 33 | 33 | 34 | 68 |
| Deep Desert | 6 | 6 | 4 | 51 |
| The Deep Dark | 44 | 44 | 24 | 97 |

Sources: scripts/world/biomes.gd, island_generator.gd; scripts/enemies/enemies.gd, realm_enemy_expansion.gd, enemy_patrol.gd, enemy_director.gd. Native models: creatures/realm_expansion_03.json.

