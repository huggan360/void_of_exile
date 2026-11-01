# Dungeons

`Dungeons.DEFINITIONS` describes the theme, room parameters, rating, enemies, encounter, optional rooms and loot bias. `DungeonLayout` deterministically carves a spanning-tree maze into 16 cavern rooms, keeps branch ends, puts the boss at the greatest graph distance from spawn, and rolls treasure/miniboss rooms at branch tips. `DungeonGenerator` builds six-block voxel walls with seeded mossy stone, cracked stone, earth and gravel patches. `DungeonScenery` batches seeded rocks, stalagmites, mushrooms, bones, broken crates, cold campfires, goblin banners and floor-to-wall vines into one collision-free voxel mesh. Props sit at diagonal room edges, preserving cardinal corridors and encounter space. Dedicated servers skip scenery. `DungeonFireflies` is client-only: three candidates per room, at most twelve visible nearby flies and shadowless, short-range lights, selected twice per second. `DungeonWorld` registers finite room packs with the normal enemy director, so streaming preserves survivors and cleared rooms stay cleared.

`DungeonServer` owns portal rolls, expiry, instance identity and travel grants. Goblin Masters have a 20% roll. Realm portals accept entry for 30 seconds. Killing the instance boss immediately removes its source entrance across the entire origin realm; stale entry requests are rejected by the server. Entrances and exits share a dark horizontal voxel hole with a textured earth/stone rim, moss and roots. The floor and its collision remain intact beneath the depth illusion. White hurt-style voxel debris opens the hole, the rim pops outward and moss grows over a second. Expiry or completion immediately disables interaction and removes the minimap marker, then withers moss and seals the hole with a white burst over 1.2 seconds. Spawn and boss exits do not expire. Each portal lazily opens its own `dng_goblins_cave_<n>` instance. Party members in the same realm receive grants to that instance and the leader's announcement. Clients cannot enter a dungeon id without a grant. Portal state is replayed to late arrivals and broadcast across the realm for minimap markers.

Spawn and boss exits return to the originating realm; if it has closed, they return to the Tavern. Empty instances use the realm unload timer (120 seconds by default). Layouts, finite pack progress and dungeon records are never saved. Each definition owns a `portal_hole` style (fixed appearance seed, radius, voxel size and earth/stone/moss/leaf/root palette). There is no per-portal appearance seed; drops and exits use identical art. Add a generator implementation when introducing another shaping style.

Goblins Cave is rated 2.5/10: Cave Goblin Slinger, Moss Bat and Mushroom Crawler; Goblin Brute and Cave Shaman; 35% Goblin Warlord room; 25% treasure cache room. Common gear caps at G4, with an 8% G5 boss roll. The King has 5,200 base HP and +20% per extra participant, light/slower attacks, three phases and three-second rests. His fight uses coin rings, curving spiked clubs, a ground-pound ripple, symmetric delayed summons and telegraphed charges.

Eligible contributors deal at least 4% of scaled boss health. Each independently gets a 95% speed/dexterity stat-potion roll, without the usual lower contributor penalty. Fallenwood bow and trident each roll 2.5% into white bags; the wand rolls 2% into a black bag. The source-art ownership file is `~/Documents/Voidrealm_textures/DIVINE_SET_USAGE.txt`.

## Review tools

- Import new scripts: `/home/hugo/Godot/godot_voxel_editor --headless --path . --import`
- Checks: `... --headless --path . res://tools/check_dungeons.tscn`
- Layout: `... --path . res://tools/review_dungeon.tscn -- --mode=layout --seed=4217 --out=/tmp/goblins_cave_layout.png`
- Models and portal: same scene with `--mode=cast`.
- Portal closeups on actual terrain: `... --path . res://tools/review_portals.tscn -- --mode=realm|cave --out=/tmp/portal.png`; `--exit=boss` shows the boss exit variant and `--remaining=2` reviews the final fade. No account or connection is used.
- Live fight: `tools/boss_watch/watch_goblin.sh` (also on the Desktop). P pauses, D toggles auto damage, R replays, Escape exits. No account is used. `-- --shots --watch-seconds=115` saves phase screenshots and exits.
- Online smoke: run a local `--test` server on port 24987, then `... --path . res://main.tscn -- --online=127.0.0.1:24987 --login=p2:12345 --dungeon-test`. The test creates a portal, activates its real interaction, verifies the boss, defeats it through normal phase handling, checks the replicated exit/bags and returns. Its server actions are available only in `--test` mode. Use an isolated copied `--config` directory to keep realm test data outside the project.

Checks cover 128 deterministic, connected layouts and their farthest boss placement; 2,000 threshold/loot rolls; hole opening/expiry/animated sealing; portal distance/expiry; same-portal grouping versus independent instances; same-realm party selection; boss exit creation; originating realm and Tavern fallback. The party checks use synthetic player records and do not contact accounts.


## Files

Added `scripts/dungeons/*.gd`, `scripts/enemies/bosses/goblin_king.gd`, the cave creature/projectile folders and editable King masters under `creatures/`, `tools/make_goblin_cave.py`, `tools/review_dungeon.*`, `tools/check_dungeons.*`, and `tools/boss_watch/goblin*` / `watch_goblin.sh`.

Updated `scripts/main.gd`; `scripts/net/{net_server,net_client,realm_instance}.gd`; `scripts/server/{game_server,world_server}.gd`; `scripts/enemies/{enemy_def,enemies,enemy_director,boss,boss_hazards,creature_model}.gd`; `scripts/world/{game_world,blocks,interaction_target}.gd`; `scripts/ui/interaction_card.gd`; `scripts/loot/loot.gd`; `scripts/game/items.gd`; `tools/import_textures.py`. The Fallenwood item icons were imported and the source-art usage documents updated.

Review images and test logs are in `/home/hugo/tmp/voidrealm_dungeons_review_20261101/`. Initial source backup: `/home/hugo/tmp/voidrealm_before_dungeons_20261101_165810/`. The original online smoke and watcher completed without script errors; the full game still reports resource/RID leak warnings on shutdown.

## Hole and cave detail follow-up

Validation is offline: headless import, `tools/check_dungeons.tscn`, and a short headless `tools/review_dungeon.tscn` run. The dungeon preview now exits before screenshot capture in headless mode. Visual approval belongs to the owner; no online account service or deployment is needed.

## Themes, layout styles and follow-ups
- `theme` (Dungeons.THEMES): floor/wall blocks, lava `crack` block, atmosphere (light, fog, reveal radius), room lights
  (mushrooms or braziers) and props (DungeonScenery: moss cave, sand hall, volcano, burning forest).
- `generator_style`: `cave_maze` (scattered rooms, winding corridors), `hall` (square chambers on a loose grid, straight
  passages, blind stubs), `arena` (a short path through guardian rooms into one big clearing).
- `params.lava_cracks`: thin glowing cracks through the rooms (`DungeonLayout.hazard_cells`); `DungeonWorld.is_hazard`
  makes them burn like lava (Player._update_lava).
- `follow_up` (dungeon id): its boss opens a follow-up portal by the boss's `follow_up.chance` (default 0.5); campaign
  story dungeons always open theirs, and keep both story portals until the follow-up is cleared.
- Dungeons: goblins_cave 2.5/10, sunken_court 4/10 (hall), cinder_depths 5/10 (volcano) -> cinder_depths_encore 7/10 (arena).
