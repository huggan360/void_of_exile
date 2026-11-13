# The world

Three places to play: the Tavern (home), the Surface (the realm everyone shares) and the Astral Reach
(open space with planets). Dungeons, including the Theory of Everything (`docs/dungeons/`), open from them.

## The Surface

A 2048 x 2048 m world in 0.25 m voxels, baked offline and streamed in.

| Piece | Where | What it does |
| --- | --- | --- |
| Baker | `tools/surface/bake_surface.py` | numpy, about 30 s. Continent, islands, biomes, terraced hills, Fosen mountains, Doom volcanoes, rivers, lakes, waterfalls, settlements, roads, bridges, fields, glades, the launch pad. Writes `realm/surface/` |
| Models | `tools/surface/make_surface_models.py` | Trees, bushes, stones (`obstacles/surface/`), barns, tents, windmills (`props/surface/`). Run before the baker |
| Map reader | `scripts/world/surface/surface_map.gd` | Loads the baked layers once; voxel heights, stone walls, beams and fences |
| Generator | `scripts/world/island_generator.gd` | Fills voxel columns from the map; plans trees, obstacles, packs and lamps from the realm seed |
| Blocks | `scripts/world/surface/surface_blocks.gd`, `shaders/surface_terrain.gdshader` | Every block in one material, one draw call per chunk |
| Water | `scripts/world/surface/surface_water.gd` | River and lake sheets that slope downstream, waterfalls, mist |
| Flora | `scripts/world/surface/surface_flora.gd` | Instanced trees (coarse copy beyond 75 m), ground cover on clients only; leans away from players and creatures |
| Fog | `shaders/surface_fog.gdshader`, `scripts/fog_of_war.gd` | Volumetric fog over Doom, Bluelay and the Deep Dark |
| Towns | `VillageFeature.from_baked()` | Capital, towns, villages and farmsteads from the baker |

The terrain node is scaled by 1/4, so the voxel terrain works in voxels and the game in meters.

To change the Surface: edit the baker (or the models tool, then run both), run
`python3 tools/surface/bake_surface.py`; the terrain cache notices the new files. `SEED` in the baker shapes the
land, `WorldServer.MAP_SEED` places trees, obstacles, packs and features. Campaign anchors can name
`{glade = "<town>"}` or `{glade = "<town>", along = 0.4}`.

On foot, V switches between overhead and over the shoulder (no first person outdoors); depth of field keeps
the area round the character sharp.

## The Astral Reach

Open space with round planets, reached by ship from the Surface's Skyward Launch Pad or the Tavern.

- **Layout** (`SpaceLayout`): each planet's town (`TOWNS`), fortress (`FORTS`, near the top so realm combat
  works there), four story places and 3 to 11 scattered villages, all levelled into the terrain.
- **Planet art** (`tools/space/make_planet_models.py`): flora, houses, landmarks, landing pads, Nexus pieces.
  `SpacePlanet` builds a town or village only within 650 m of the camera and frees it past 850 m. Flora streams
  in 220 m patches with full models near (130 m) and coarse copies beyond; ground cover is tiled on worker
  threads. Water per planet: Tidewell's sea, lakes elsewhere.
- **Combat** on each planet's top (`SpaceLayout.COMBAT_CAP`) works like the realm. 32 planet creatures, 3 to 4
  per planet with a god each (`scripts/enemies/space_enemies.gd`); gods drop their planet's fortress key.
- **Fortresses** (`scripts/space/planet_strongholds.gd`): Rose Bastion (Queen Briarrose), Amber Ziggurat
  (Aurum), Shattered Observatory (Selenarch), Rotting Hive (Brood Matriarch), Stormeye Citadel (Vaelith). Sealed
  until a key is turned, barred while the boss fights, not saved between loads. Bosses in
  `scripts/enemies/planet_bosses.gd` and `scripts/enemies/bosses/`.
- **Camera**: V toggles overhead and over the shoulder; first person only indoors (ship rooms, the diner, the
  Nexus's Lantern Bar, the Lantern City's shops).
- **Campaigns** (`scripts/campaign/`): the Reach tales run in private spaces. Mission 6, The Eye Behind the
  Stars, ends at the Veiled Herald on Shardheart and Vaelith on the Pale Eye; its films are shot in the real
  places (cutscene shots with `space = {planet, at, from, to, look}`, actors from `CutsceneActors`).

### Known gaps

- `reach_kill` and `reach_repair` (Lantern Road, Shardfield tales) haven't been replayed online since the brood
  rework.
- No pilot prediction online (input lag); ships vanish when the Reach unloads or the server restarts.
- Planet terrain is smooth, not block-stepped; flora and props are voxel.
- The voxel module prints harmless `!is_inside_tree` errors from `direct_static_body.cpp` on clients.

## Versions that matter here

`WorldServer.LAYOUT_VERSION` (7 since the Surface remake) archives saved world progress when coordinates
change. `Net.VERSION` (0.14.0) must match between clients and servers.
