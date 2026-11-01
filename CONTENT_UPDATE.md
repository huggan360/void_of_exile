# Realm content integration

The first five modeled enemies are live. Their editable, rigged assets are in `creatures/<enemy>/`; the original staging batch remains an authoring reference. Gameplay tuning is defined in `scripts/enemies/enemies.gd`.

## Enemies

| Enemy | Home / rank | HP / defence | Main attack before player defence | Movement |
| --- | --- | --- | --- | --- |
| Sporeback | Woods / medium | 360 / 4 | Three spores, 26–34 each, 16° gaps | Slow skirmisher, stops to shoot |
| Thorn Hopper | Woods and Jungle / medium | 300 / 3 | Two aimed seeds, 24–32 each | Darts between rooted bursts |
| Cinder Beetle | Woods / medium | 550 / 10 | Small voxel fireball, 36–46 | Armored, slow skirmisher |
| Frost Moth | Fosen / god | 3200 / 10 | Three ice shards, 150–170 each, 20° gaps | Strafes, pauses and beats wings before firing |
| Ruin Watcher | Bluelay / god | 4200 / 16 | Three aimed rune orbs, 160–180 each; occasional eight-shot ring, 140–160 | Stationary floating sentry; magic shots can be blocked by the warp shield |

New authored spore, seed, ice-chip and rune-orb VOX meshes are used for their projectiles. Cinder Beetle uses the existing animated voxel-fire projectile. Gods visibly brighten as their shots wind up. Existing spirits and the Blue Genie also have higher damage: the main shots of gods deal 58–98 damage after a level-50 archer's 87 defence in G4 cloak/crucifix gear. These are deliberately dangerous, dodgeable encounters; final feel can be tuned after extended play.

Teleporting spirits and the Blue Genie now squash, dissolve into creature-colored cubes, transfer, and reassemble in about 0.34 seconds. They finish a windup/volley before blinking. This is a visual transition rather than a sudden position snap or new immunity state.

## Realm population and persistence

God and Blue Dragon packs do not respawn. Each realm's seed fixes the available sites and pack rolls. Distant packs still load lazily for performance. Each casualty in a finite pack is saved immediately, including when its followers remain alive. Chunk sleep/wake, leaving the realm, and save/reload cannot revive the killed members. A deliberate realm reset starts a fresh population.

Center biomes use approximately 75–83% occupancy per eligible 36×36 placement cell, rather than rare god encounters. Fosen favors Frost Moths, Bluelay favors Watchers and Blue Genies; Doom, Deep Desert and Deep Dark have frequent spirit packs. Normal terrain, safe-arrival clearance and structure placement rules still apply.

## Drops

- All 85 regular gear items are registered, including the 40 bonuses and the graded wands, robes and tridents. G7/G8 remain cataloged for later content, but **no realm enemy, including the Blue Dragon, can roll them**.
- Medium enemies roll G1–G3, with a 0.5% G4 roll.
- Gods roll G3/G4, with **0.1% G5** per eligible player. They never roll G6, G7/G8 or divine gear.
- Blue bags hold permanent stat potions. Rare G5 gear has red bags; G6 has purple bags. Loot is separated by color, so rare gear does not absorb a potion into its bag.
- Gods have a 35% roll for their encounter biome's signature stat potion. The encounter's original site fixes its identity even if the enemy is kited over a border.
- The Blue Dragon rolls **each of the five existing Blue-set items independently at 3% per eligible player**, in white bags: cloak, spell, robe, trident and crucifix. No other divine sets are enabled. Blue Dragon's G6 gear roll remains available.

| Biome | Signature permanent potion |
| --- | --- |
| Shores | Dexterity |
| Woods | Speed |
| Jungle | Dexterity |
| Desert | Defence |
| Doom | Attack |
| Fosen | Magic |
| Bluelay | Magic Points |
| Deep Desert | Health |
| Deep Dark | Defence |

Archer can equip bows, cloaks, spells and every bonus family. Wands, robes and tridents can be carried and looted, but drag/drop and double-click cannot equip them. Tooltips explain the restriction. The six player classes and class-specific right-click abilities remain for the next pass.

## Spell correction

The old G5 ring started at 70 damage, retained only 15% at the edge (about 10 before enemy defence), and did not scale with Magic. The new ring bases are G4 **220**, G5 **360**, and Blue **280 per pulse, three pulses**. Rings retain 50% at their full range and gain 1.5% damage per point of Magic. Mana costs/cooldowns are 35/1.0s, 45/1.1s and 55/1.5s respectively. G1–G3 remain shield spells.

Tooltips show the actual predicted damage range with that spell equipped, its mana cost, range, pulses and cooldown. At level 1, without other Magic gear, the G4 ring deals 150–299 and G5 deals 253–506 before enemy defence. Real near/far physics-hit tests verify those changes; wave clashes can still cancel individual arcs.

## Verification

`tools/test_realm_integration.tscn` checks catalog/icons, drop pools, class restrictions, damage through high-level defence, seeded spawn placement, all projectile meshes, partial-pack save/reload, teleport completion, real physics-ring damage, and independent Blue-set loot rolls.

A seeded run of 10,000 Blue Dragon kills rolled each divine item 277–320 times. A seeded run of 20,000 god kills produced 23 G5 items and 7,065 signature potions. A full sample realm had 13 Frost Moth pack sites and 10 Watcher pack sites, plus the existing spirit/genie encounters. Combat smoke runs in Fosen, Bluelay and Woods completed without script errors.

Run the checks with isolated save data:

```sh
env XDG_DATA_HOME=/home/hugo/tmp/voidrealm_integration_test \
  /home/hugo/Godot/godot_voxel_editor --headless --path . \
  res://tools/test_realm_integration.tscn
```

The recursive `tools/import_textures.py` importer reads the reorganized source folders and imports regular gear plus `Divine/The_Blue`, preserving all source artwork. Existing source code and item textures were backed up before this pass at `/home/hugo/tmp/voidrealm_before_integration_20261031_132309/`.

## Batch 02 — six additional gods and three lesser enemies

All models are editable rigged VOX assets in `creatures/<id>/`; rebuild with `python tools/make_god_batch_02.py`. See `creatures/batch_02_preview.png` for the geometry preview.

| God | Biome | HP / defence | Main shot damage | Attack / movement | Followers |
| --- | --- | --- | --- | --- | --- |
| Basalt Bulwark | Doom | 5500 / 28 | 190–210 | Three basalt bolts in a fan; slow armored skirmisher | 2–3 Ember Mites |
| Furnace Maw | Doom | 6500 / 18 | 200–220 | Three aimed fireballs in a burst; advances between attacks | None |
| Cinder Oracle | Doom | 4800 / 14 | 185–205 | Five-shot magic sweep; weaves sideways | 2–3 Ember Mites |
| Rime Stag | Fosen | 3800 / 12 | 160–180 | Three ice bolts in a fan; darts between volleys | 2–3 Rime Skitters |
| Glacier Hermit | Fosen | 4900 / 24 | 170–190 | Two aimed ice bolts; slow armored skirmisher | 2–3 Rime Skitters |
| Hail Harrier | Fosen | 3400 / 10 | 155–175 | Five-shot ice sweep with wing-beat animation; strafes | 2–3 Snow Wisps |

These are gods, not bosses: no phases, summons or divine drops. All their packs are finite and persist individual casualties. The followers are ordinary enemies (180–220 HP, 32–44 shot damage), stay near their leader, and have separate roaming packs in their home biome. Roaming lesser packs respawn; followers belonging to a god's pack do not. Existing G3/G4 green bags, 0.1% G5 red bags, and no G7/G8 realm loot are preserved.

Doom's god potion pool is now **Attack / Defence**; Fosen's is **Magic / Dexterity**, including its existing Frost Moths. Each successful signature-potion roll picks either stat equally, in a blue bag. Every stat already had an assignment somewhere in the realm, so these are biome specializations rather than globally unused stats. This supersedes the single-stat table above for those two biomes.

Enemy placement now plans the whole pack before instantiating actors, checks full body clearance against streamed colliders, and checks procedural terrain/structure geometry even before colliders exist. It searches nearby safe locations outside structure footprints, including ruins, rather than placing enemies at an obstructed center or on a roof. Boss summons use the same placement checks. If no complete safe layout exists, the original roster is retained and retried later without counting it as killed. Followers are also separated from one another at spawn.

Validation: `tools/test_god_batch_02.tscn` runs the previous integration suite plus checks for all nine new rigs/projectiles, actual god/follower pack construction and animations, both biome potion pools, physics obstacles, blocked-pack retries, and eight procedural ruin relocation cases. The final run passed with zero failures. A Doom combat smoke run also completed without script errors. Isolated test save directories leave the player's realm saves untouched.

## Fixed home village — 31 October 2026

The Tavern now loads `scenes/home/tavern.tscn`: an editor-authored 149 × 149 island, over ten times the previous floor area. Its 26 buildings include a larger tavern, closed chapel with bell tower, forge, magician's tower, tall townhouses, broad lodges, blue bakeries and rose cottages. Roads, six formal garden beds, blossom/orchard trees, benches, lanterns, market stalls, water and resident stations are explicit editable scene nodes. Spawn is immediately north of the large three-tier fountain, whose 256 water voxels animate continuously. There are 27 outdoor residents; ordinary residents roam, while service residents stay at their stations and retain the existing flee/return behavior.

A reusable `InteractionTarget` and HUD `InteractionCard` provide range-checked portrait prompts, Enter/button activation, NPC greetings and Enter/Escape dismissal. Inventory, travel, fleeing NPCs, walking away and removed objects invalidate prompts safely. Buying and shop stock remain for a later pass. Scene collision envelopes drive town navigation; cached scene footprints drive the worker-painted minimap.

The home layout never uses a realm seed or runs an authoring utility. Native VOX sources are in `props/home`, baked editor-visible meshes/prefabs in `scenes/home/prefabs`. Editing instructions and authoring-tool cautions: `scenes/home/README.md`. The seeded realm towns are preserved. Validation: 247 home checks and 8,068 existing settlement checks pass, with live rendered previews under `docs/realm_expansion/tavern_*.png`.

## Staged realm boss art — 31 October 2026

Created four native voxel bosses for the remaining strongholds: Fosen's Rimeheart Prism, lava's Vharok the Cinder Tyrant, desert's Aureate Scarab Regent, and the dark biome's Hollow Crown. All are under `creatures/staging/realm_bosses_01`, with articulated rigs, separate emissive geometry, editable full-pose VOX sources and baked editor-visible Godot scenes. The crystal has three distinct forms (sealed, conduit, tempest), a six-pylon hexagon beam visual mock-up and a separate hostile shardling design. The demon has an additional infernal fissure variant. No new enemies, boss fights, healing, summons, drops or spawns are registered.

Reserved matching divine sets: Frost, Satan, Holy_Divine and Void. Documented all 17 source sets / 85 unique items in `/home/hugo/Documents/Voidrealm_textures/DIVINE_SET_USAGE.txt` and per-set `USAGE_AND_DROPS.txt` files. Every item states its live rate and any planned rate. Reserved boss items propose independent 3% personal white-bag rolls but remain at 0% live. Existing Blue Dragon retains five 3% independent Blue-set rolls and 4% damage eligibility. Other sets remain available/unassigned.

Validation: `tools/test_realm_boss_art.tscn` passes 322 checks covering native loader compatibility, 256-voxel part limits, shared variant frames, editor scenes, art-only isolation and unchanged live Blue drops. Rendered previews are in `docs/realm_expansion/realm_boss_lineup.png`, `boss_crystal_forms.png`, `boss_vharok.png`, `boss_scarab.png` and `boss_hollow_crown.png`. Run the staged `preview.tscn` for the animated showroom; its README documents controls and the crystal diorama.

## Home island and realm towns/roads — 31 October 2026 (evening)

**Tavern (Hearthhaven)** is now a real island instead of a square slab. Its shape comes from an editable `Coastline` curve, with beaches, shallows and coastal woods with palms. Roads and plazas are editable `HomeRoad`/`HomePlaza` nodes that are painted into the voxel ground. The layout runs from the gate headland to the tavern, the fountain square, the garden and the chapel, with two avenues, a harbor and pier, a lookout, four residential quarters on winding lanes (43 houses, each with a door footpath), an orchard, lanterns along the streets, and benches facing the fountain, the garden and the sea. See `scenes/home/README.md`.

**Realm towns** are seeded round villages. Each has a paved plaza (well, stalls, benches), main streets that leave town toward the realm roads, a ring lane, side lanes, houses facing the streets at natural angles with footpaths, lanterns and yard trees. Woodland towns mix in cottages and teal-roofed houses. Desert and Fosen towns use their own paving. Hostile packs keep 14 blocks beyond a town's edge.

**Realm roads**: one smoothed spoke leaves the capital toward each of the five outer biomes. The Fosen and desert spokes run to their outposts. The others stop shortly past the woodland edge (the Deep Dark road always stops). Some spoke ends are joined by a road that crosses the biome border to the neighbouring road. Roads never lead to boss strongholds and keep at least 34 blocks from their edge. Paving matches the biome. `LAYOUT_VERSION` is now 3, so old realm progress is archived once. Review a seed with `OUT=/tmp/map.png godot --headless --path . -s tools/review_realm_plan.gd -- <seed>`.

Backup taken before this pass: `/home/hugo/tmp/voidrealm_before_towns_20261031_210854/`.

## Five live stronghold bosses — 31 October 2026 (night)

All five boss strongholds now have a full encounter: a breakable shell, a hatch, three phases, telegraphed hazards and boss-specific summons. The Blue Dragon now sleeps in an azure egg; his fight is otherwise unchanged. The Frost, Satan, Holy Divine and Void divine sets are live: every item rolls 3% on its own, in personal white bags. Details, tests and known gaps are in `docs/realm_expansion/REALM_BOSS_FIGHTS_IMPLEMENTED.md`. Per-set drop notes are in `~/Documents/Voidrealm_textures/` (old copies backed up under `/home/hugo/tmp/voidrealm_before_towns_20261031_210854/Voidrealm_textures_docs/`).

## Realm gods, fauna and torch patrols — expansion 03

Added and wired 15 native voxel gods, three each for Doom, Fosen, Bluelay, Desert and Deep Dark, plus seven ordinary creature types including three-person Bile Bandit patrols. Explicit god signatures cover all seven permanent-stat potions; existing god gear caps and finite deaths remain. Batch-2's six gods remain enabled. Patrols share obstacle-aware routes, carry real torch lights and fire moving light-emitting fireballs with a bounded 12-light projectile budget.

Fixed omitted enemy sites at streaming chunk boundaries and redistributed spawn weights for the larger roster. Whole-area and streamed enumeration now agree (263/263 sites in seed 20261031), with no duplicate sites. Existing killed packs/saved finite survivors are preserved through the rebalance. Details, native assets, tests and current rates are documented in `docs/realm_expansion/REALM_EXPANSION_03.md` and `BIOME_ENEMY_SPAWNS.md`; the TXT spawn report in the source texture folder is refreshed.

## Tavern grass, options and shield — 31 October 2026

Fixed disappearing Tavern grass by replacing island-wide distance-culled decor batches with bounded spatial patches. Added Options to title/pause menus, with the five requested tabs, saved video settings, guarded display previews, proportional Small/Medium/Large GUI sizing and a categorized key/mouse mapper. General, Audio and Graphics remain empty.

Spirit wilderness and ruin probabilities are 30% of the previous values. Shielding now leaves 15% movement speed, cancels weapon actions, and blocks projectiles at the bubble surface with directional deformation, flashes and projectile-colored voxel fragments. Player rings now clash with enemy magic orbs, including the Ruin Watcher's shots. Current spawn reports were refreshed (241/241 planned/streamed sites for seed 20261031). Validation and previews: `docs/realm_expansion/OPTIONS_AND_SHIELD_UPDATE.md`.

## Loot sack artwork

Rebuilt all seven ground-bag variants as finer voxel cloth sacks. Each color has its own proportions: a small repaired gray pouch, broad green gathering sack, upright blue drawstring bag, squat red bundle, tall purple satchel, large ivory treasure sack and narrow black relic sack. Models have rounded weighted bodies, gathered cloth folds, sewn side seams, pinched necks, open ruffled cloth rims, double rope ties, hollow bow loops and hanging cord ends. Rare bags have small seals, with emissive gems/stitched details and restrained pulsing local light; common bags remain plain cloth. Ground alignment follows each model's bounds. Implemented without running tests or previews, as requested.

## Chunky pixel-art bosses — 1 November 2026

Redesigned all five live bosses and their shells around 32-cell silhouettes expanded eight times into 256-cell VOX canvases. Updated every phase form and animated rig, with clean palette blocks, sparse fine glow accents and editable `source_32` masters. All boss projectile paths now use authored colored pixel models rather than plain bright slabs/balls. Vharok's broad orange cleave is 200×24×24 voxels and uses matching swept rectangular collision. Details: `docs/realm_expansion/PIXEL_BOSS_REDESIGN.md`. No tests or previews run; source generation and editor asset baking only.

## Blue Dragon silhouette revision

Replaced the upright mascot-like dragon with a long, low quadruped: muscular rear haunches, planted clawed forelegs, an angular fanged snout, heavy eye ridges with narrow amber slits, swept-back horns, spinal spikes and much larger swept bat wings. Updated the enraged form, mouth attachment, editable coarse sources, game VOX parts and editor scenes. Desktop boss previews refreshed. Other bosses and encounter tuning are unchanged.

## Swept flame crescent

Bent Vharok's 200-voxel-wide flame shard backward into a pointed crescent, with a ragged fire edge and orange/amber heat. It remains 24 voxels high; the curved footprint is now 80 voxels deep. Generated offset collision boxes follow the ribbon instead of filling its concave interior. Updated the Desktop projectile overview and added `Flame Shard Preview.png`.
