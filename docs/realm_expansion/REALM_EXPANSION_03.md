# Realm expansion 03

Production content: 15 gods (three per stronghold biome) and seven ordinary creatures. Models are native articulated VOX assets under `creatures/<id>/`; `creatures/realm_expansion_03.json` lists the 22 new models. Rebuild native art with `python tools/make_realm_expansion_03.py`. The existing five boss encounters and fixed home village are preserved.

| Biome | New gods | Potion assignments |
|---|---|---|
| Doom / lava | Slag Seraph, Obsidian Ram, Ember Lich | Attack, Defense, Magic |
| Fosen | Aurora Sentinel, Hoarfrost Owl, Icebound Colossus | Magic, Dexterity, HP |
| Bluelay | Prism Ray, Runic Archivist, Azure Medusa | Dexterity, Magic, MP |
| Desert | Sun Jackal, Dune Monolith, Glass Scorpion | Speed, HP, Defense |
| Deep Dark | Umbral Reaper, Amethyst Widow, Nightbell Idol | Speed, Defense, MP |

New ordinary creatures: Bramble Fox and Moss Tortoise in Woods; Vine Mantis in Jungle; Tide Snail in Shores and Bluelay; Dune Crawler in Desert/Deep Desert; Gloam Bat and Bile Bandit in Deep Dark.

All six batch-2 gods remain registered and distributed: Basalt Bulwark, Furnace Maw, Cinder Oracle, Rime Stag, Glacier Hermit and Hail Harrier. Their existing models/projectiles and finite attached followers are preserved and exercised by runtime tests.

Gods use explicit `god_potion_stats` when assigned, otherwise their origin biome. The new gods provide every permanent stat. The existing 35% signature-potion roll, 0.1% G5 exception, G3/G4 gear and no-divine/G6-G8 restrictions remain. Ordinary creatures use the medium loot table. See `BIOME_ENEMY_SPAWNS.md` for full statistics and exact probabilities.

Bile Bandits spawn in threes (one leader, two companions), use a shared seeded AStar patrol within 18m, avoid terrain/obstacles/towns, and alert together. Each carries an authored voxel torch and a real flickering warm light, and launches animated fireballs with moving environmental light. The projectile-light budget is 12; lights are unshadowed and freed with their shots. Ordinary patrols respawn 240 seconds after a complete wipe.

The 36m-cell/32m-chunk spawn omission is fixed using floor for the starting cell and the existing candidate ownership filter. Three-seed tests verify no omissions or duplicates. Final seed-20261031 audit produces 263 planned sites and exactly 263 streamed sites. Wilderness density was redistributed to keep the added variety manageable: Shores 18%, Woods 82%, Jungle 54%, Desert 69%, Doom 78%, Fosen 79%, Bluelay 78%, Deep Desert 70%, Deep Dark 80%, before exclusions. Large star-heavy spirit groups have lower weights in the hardest biomes, making room for distinct gods and smaller patrols.

Existing cleared sites are never reset. Persisted finite survivor records retain their finite lifecycle even if a new table assigns that site a different pack; killed gods are not reconstructed. No world-layout version bump or realm reset is performed.

Validation:

- `tools/test_realm_expansion_03.tscn`: three new gods in each stronghold biome; every new god and batch-2 god executes an actual attack through a real director; model/projectile loading; all seven potion sources; forbidden loot; exact chunk/whole-area agreement over three seeds; three-person patrol movement, group alert, obstacle navigation, torch/fire lighting, light cleanup/budget and finite-save compatibility.
- `tools/test_god_batch_02.tscn`: existing item, spell, loot, persistence, spawn-clearance and batch-2 regressions. Obsolete Blue-only catalog expectation updated to the five current boss sets. The single-seed legacy presence check now allows one pack because the roster is broader; multi-seed production coverage is tested separately.
- `tools/test_outdoor_towns.tscn`: realm generation, five strongholds, roads, towns, house collision and villager movement/fleeing regressions.

Run tests with an isolated `XDG_DATA_HOME` to keep fixture writes away from player saves. Inspect native models via `tools/review_realm_expansion_03.tscn` with `-- --biome=doom|fosen|blue|desert|dark|normal`. In-game patrol screenshot: `bile_bandit_patrol_ingame.png`.

Regenerate the readable spawn audit:

```sh
/home/hugo/Godot/godot_voxel_editor --headless --path . tools/export_biome_enemy_report.tscn
python tools/format_biome_enemy_report.py
```

The formatted report is also written to `/home/hugo/Documents/Voidrealm_textures/BIOME_ENEMY_SPAWNS.txt`.

Final checks: expansion 03 **3,752/3,752**, batch-2/integration **103,573/103,573**, outdoor towns/settlements **9,038/9,038**. Total **116,363 passing checks**. Godot editor import and rendered production previews are clean. In-game patrol inspection confirms the native torches and warm terrain illumination.
