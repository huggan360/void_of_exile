# The Surface remake (0.25 m voxels)

Started 2026-11-11. The Surface is no longer a round island of 1 m blocks: it is a
2048 x 2048 m world (about twice the old land area) streamed as 0.25 m voxels, the
size of the obstacle voxels.

## How it fits together

| Piece | Where | What it does |
| --- | --- | --- |
| Baker | `tools/surface/bake_surface.py` | numpy only, about 30 s. Makes the whole map offline: continent, islands, biomes, terraced hills with stone walls, Fosen mountains, Doom volcanoes with lava, rivers (priority flood + flow), lakes, waterfalls, settlements, roads, trails with wooden stairs, bridges, fences, fields, camps, forest density. Writes `realm/surface/`. |
| Models | `tools/surface/make_surface_models.py` | Trees, bushes, stones, logs (`obstacles/surface/*.vox`) and barns, shed, tents, windmill (`props/surface/*/`). Run it before the baker (the baker reads the building sizes). |
| Map reader | `scripts/world/surface/surface_map.gd` | Loads the baked layers once (shared by worker threads). `fine_height()` blends meter samples per voxel column but keeps stone walls sheer with a ragged edge. Beams and posts (rails, decks, fences) become voxel overlays. |
| Blocks | `scripts/world/surface/surface_blocks.gd`, `shaders/surface_terrain.gdshader` | All block types in one material: the shader finds each block's palette row from the atlas tile, so a terrain chunk is one draw call. New styles: rock strata, planks, leaves. Ivy blocks have no collision. |
| Generator | `scripts/world/island_generator.gd` | Same API as before for the rest of the game (column, feature_at, surface...). Fills voxel columns from the map; fortresses and biome features are still 1 m blocks drawn 4 voxels to a side. Plans trees, obstacles, packs, lamps from the seed. |
| Water | `scripts/world/surface/surface_water.gd`, `shaders/surface_water.gdshader`, `shaders/surface_waterfall.gdshader` | River and lake sheets per chunk that slope downstream, waterfall curtains, mist. The sea is still the one plane. |
| Flora | `scripts/world/surface/surface_flora.gd`, `shaders/surface_flora.gdshader` | Trees (instanced, coarse copy beyond 75 m, trunk colliders also on the server) and ground cover (clients only): grass, flowers, wheat and crops, reeds, lilies, ferns, bushes, logs, stones. Everything sways and leans away from players and creatures near the camera (`IslandWorld._process` fills the pusher list each frame on clients). |
| Fog | `shaders/surface_fog.gdshader`, `scripts/fog_of_war.gd` | Regional volumetric fog (a FogVolume following the player) only over biomes with fog of war (Doom, Bluelay, Deep Dark). Thick over unexplored land, a low mist once explored. Falls back to the old screen fog when volumetric fog is off in the settings. |
| Towns | `VillageFeature.from_baked()` | Capital, towns, villages and farmsteads come from the baker (houses along winding lanes, barns, windmills, lanterns, yard trees). Residents and shops are planned as before. |

The terrain node is scaled by 1/4 (`IslandWorld._ready`), so `VoxelTerrain` works in
voxels while the game stays in meters. `IslandWorld.ground_height()` reads the voxel
columns directly.

## Changing the world

1. Edit `tools/surface/bake_surface.py` (or the models tool, then rerun both).
2. `python3 tools/surface/bake_surface.py`
3. The terrain cache (`user://cache/terrain/`) notices the new files by their dates.

Seeds: `SEED` in the baker shapes the land; the realm seed (`WorldServer.MAP_SEED`)
places trees, obstacles, packs and biome features.

## Other changes in this pass

- First person is gone on the ground (V toggles overhead and over the shoulder).
- Depth of field on the Surface: the area around the character stays sharp, far and
  very near things blur (`IslandWorld._update_focus`).
- The Surface's base light is the Tavern's (warm low sun, the same grade); the woods
  have no haze at all.
- `WorldServer.LAYOUT_VERSION` 7 archives old Surface progress (kills, broken
  obstacles, gate states) since the coordinates changed; `Net.VERSION` is 0.13.0.
- The portal shatter effect skips the terrain on the Surface (too many voxels).
- `realm/realm_layout.tscn` and `RealmLayout` are no longer used by the Surface.

## Check

`godot --headless --path . res://tools/surface/check_surface.tscn` builds the plan,
voxel blocks, trees, ground cover and water and prints timings.

## Ideas for next time

- Distant terrain beyond ~130 m (a low-detail ring or VoxelLodTerrain).
- Animals in the fields, smoke from chimneys, boats at the piers (no piers yet).
- A world map image from the baker's preview for the map screen.
