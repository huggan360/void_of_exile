# The world

Three places to play: the Tavern (home), the Surface (the realm everyone shares) and the Astral Reach
(open space with planets). Dungeons, including the Theory of Everything (`docs/dungeons/`), open from them.

## The Surface

A 2048 x 2048 m world in 0.25 m voxels, baked offline and streamed in.

| Piece | Where | What it does |
| --- | --- | --- |
| Baker | `tools/surface/bake_surface.py` | numpy, about 30 s. Continent, islands, biomes, terraced hills, Fosen mountains, Doom volcanoes, rivers, lakes, waterfalls, settlements, roads, bridges, fields, glades, the launch pad. Writes `realm/surface/` |
| Models | `tools/surface/make_surface_models.py` | Trees, bushes, stones and Deep Dark glow growth (`obstacles/surface/`), barns, tents, windmills (`props/surface/`). Run before the baker |
| Map reader | `scripts/world/surface/surface_map.gd` | Loads the baked layers once; voxel heights, stone walls, beams and fences |
| Generator | `scripts/world/island_generator.gd` | Fills voxel columns from the map; plans trees, obstacles, packs and lamps from the realm seed |
| Blocks | `scripts/world/surface/surface_blocks.gd`, `shaders/surface_terrain.gdshader` | Every block in one material, one draw call per chunk |
| Water | `scripts/world/surface/surface_water.gd` | River and lake sheets that slope downstream, waterfalls, mist |
| Flora | `scripts/world/surface/surface_flora.gd` | Instanced trees (coarse copy beyond 75 m), ground cover on clients only; leans away from players and creatures |
| Deep Dark glow | `scripts/world/surface/deep_dark_glow.gd`, `shaders/deep_dark_model.gdshader` | Client pink/lime ripple chatter through instanced plants and obstacles; four-second walking trails in the flora shader |
| Fog | `shaders/surface_fog.gdshader`, `scripts/fog_of_war.gd` | Volumetric fog over Doom, Bluelay and the Deep Dark |
| Towns | `VillageFeature.from_baked()` | Capital, towns, villages and farmsteads from the baker |

The terrain node is scaled by 1/4, so the voxel terrain works in voxels and the game in meters.

Voxels come from the engine's C++ `SurfaceVoxelGenerator` (engine/modules/voxel_surface, a port of
`IslandGenerator._generate_block`, configured by `IslandGenerator.native_config()`); an engine without it
falls back to the GDScript generator and its disk cache. Change both together and run
`tools/check_surface_generator.tscn` (every voxel must match). Grass, flowers and water chunks are gathered on
worker threads, and town walking grids are built ahead on workers; `tools/bench_surface_stream.tscn` times it.

To change the Surface: edit the baker (or the models tool, then run both), run
`python3 tools/surface/bake_surface.py`. `SEED` in the baker shapes the
land, `WorldServer.MAP_SEED` places trees, obstacles, packs and features. Campaign anchors can name
`{glade = "<town>"}` or `{glade = "<town>", along = 0.4}`.

On foot, V switches between overhead and over the shoulder (no first person outdoors); depth of field keeps
the area round the character sharp.

The Deep Dark keeps its black ground and the pink `surface/crystal_violet` clusters. Black lantern trees,
bushes and grass carry pink/lime bulbs, tips and flowers, with spires, crystals and lime fungus between them.
Roads, trails and arrival clearings stay open. IslandWorld owns the client-only GlowRipples controller:
streamed batches register a few glow sources, nearby sources chatter every 1.8 to 3.6 seconds, and unloading
removes them. A 32-position ring tracks walking by the local player and one nearby player; only glow plants
read it, lighting their accents within 1.4 m and fading over four seconds. Emission supplies the light without
extra OmniLights. This dressing change needs no terrain or placement bake.
Check the dressing, shader compilation and streaming cleanup headlessly with `tools/surface/check_deep_dark.tscn`.

## The Astral Reach

Open space with round planets, reached by ship from the Surface's Skyward Launch Pad or the Tavern.

- **Layout** (`SpaceLayout`): each planet's town (`TOWNS`), fortress (`FORTS`, near the top so realm combat
  works there), four story places and 3 to 11 scattered villages, all levelled into the terrain.
- **Planet art** (`tools/space/make_planet_models.py`): flora, houses, landmarks, landing pads, Nexus pieces.
  `SpacePlanet` builds a town or village only within 650 m of the camera and frees it past 850 m. Flora streams
  in 220 m patches with full models near (130 m) and coarse copies beyond; ground cover is tiled on worker
  threads. Water per planet: Tidewell's sea, lakes elsewhere.
- **Asteroids** (`SpaceLayout.asteroids()`, drawn by `SpaceBackdrop`): voxel rocks from `AsteroidModels`
  (3 rock, 2 crystal and 2 giant shapes, each at three voxel resolutions), batched per 3 km cell; each batch
  swaps to the LOD its nearest rock needs (full under 1.4 km, middle under 4.2 km, giants 2.5x further).
- **View distance** (Options -> Graphics, `GraphicsSettings.view_scale()`): Short / Medium / Far scales
  Surface flora, obstacles, the client's chunk ring and terrain, and planet flora, ground cover and towns.
- **Combat** on each planet's top (`SpaceLayout.COMBAT_CAP`) works like the realm. 32 planet creatures, 3 to 4
  per planet with a god each (`scripts/enemies/space_enemies.gd`); gods drop their planet's fortress key.
- **Fortresses** (`scripts/space/planet_strongholds.gd`): Rose Bastion (Queen Briarrose), Amber Ziggurat
  (Aurum), Shattered Observatory (Selenarch), Rotting Hive (Brood Matriarch), Stormeye Citadel (Vaelith), Veiled
  Shrine on Shardheart (the Veiled Herald; mission 6 finds its key at the heart shrine). Sealed
  until a key is turned, barred while the boss fights, not saved between loads. Bosses in
  `scripts/enemies/planet_bosses.gd` and `scripts/enemies/bosses/`: four stages each (100-75-50-25%), solo HP
  36k / 52k / 68k / 84k / 100k (Veiled Herald 50k), each with a status-effect shot in its last stage. Vaelith's
  second stage binds it to eight squid arms (`vaelith_arm` bodies, only hittable while down, hits pass to
  Vaelith). Their projectile models come from `tools/make_space_boss_projectiles.py`.
- **Ship netcode**: everyone sees a ship interpolated 0.15 s in the past (`SpaceShipView`), except its pilot, whose
  client flies it ahead on its own helm input and replays what the server hasn't flown yet on each snapshot
  (`ShipPrediction`; snapshots carry the last helm input number and the ticks flown on it).
- **Camera**: V toggles overhead and over the shoulder; first person only indoors (ship rooms, the diner, the
  Nexus's Lantern Bar, the Lantern City's shops).
- **Campaigns** (`scripts/campaign/`): the Reach tales run in private spaces. Mission 6, The Eye Behind the
  Stars, ends at the Veiled Herald on Shardheart and Vaelith on the Pale Eye; its films are shot in the real
  places (cutscene shots with `space = {planet, at, from, to, look}`, actors from `CutsceneActors`).

### Known gaps

- `reach_kill` and `reach_repair` (Lantern Road, Shardfield tales) haven't been replayed online since the brood
  rework.
- Ships vanish when the Reach unloads or the server restarts.
- Planet terrain is smooth, not block-stepped; flora and props are voxel.
- The voxel module prints harmless `!is_inside_tree` errors from `direct_static_body.cpp` on clients.

## Light

- **Ambient occlusion**: the voxel meshers bake corner shading into every block (free), and SSAO adds contact
  shadows under creatures and props (Options -> Graphics -> Ambient occlusion).
- **Volumetric light** (`scripts/effects/volumetric_light.gd`, owned by the Atmosphere; Options -> Graphics ->
  Volumetric light, Off / Low / Medium / High). Two layers: a thin sun haze round the player
  (`shaders/sun_haze.gdshader`, a FogVolume in the engine's volumetric fog) that the sun's shadows cut into
  beams and lamps glow in, on the Surface, in the Tavern and on planet ground; and `SunShafts`
  (`scripts/effects/sun_shafts.gd`, compute shaders `shaders/sun_shafts*.glsl`), rays from the sun past
  anything against the sky, at a quarter (High: half) of the screen, skipped when the camera faces away from
  the sun. SpaceBackdrop reports the Haven sun each frame. With the setting on, distance fog also takes the
  sky's colour and a glow toward the sun.

## Versions that matter here

`WorldServer.LAYOUT_VERSION` (7 since the Surface remake) archives saved world progress when coordinates
change. `Net.VERSION` (0.15.0) must match between clients and servers.
