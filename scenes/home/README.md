# Editing the Tavern

Open `res://scenes/home/tavern.tscn` in the Godot editor. The home island is fixed: no seed or runtime generator changes it. The voxel ground is baked from this scene each time the Tavern loads.

## Layout
North to south: the **realm gate** on the northern headland, then the **Grand Tavern** with its yard, then the **fountain square** (you arrive just north of the fountain), then the **formal garden** and the **chapel**. Two cobbled avenues run down both sides of the square and the garden. Market streets lead west to the **harbor and pier** and east to the **lookout**. The smith's forge is on the west street and the magician's tower on the east street. Residential lanes loop through the four quarters, and every house has a footpath from its door to the street. Coastal woods, beaches and palms ring the island.

## What you can edit
- **Coastline** (Path3D): drag its points to reshape the island. Beaches and shallows follow automatically.
- **Roads** (`HomeRoad` Path3D nodes): move the curve points. In the Inspector, set `width`, `surface` (cobble, gravel, dirt, tiles, pier) and `curbs`. Roads lower in the tree are painted over earlier ones. A `pier` builds a timber deck on posts over the water.
- **Plazas** (`HomePlaza` markers): round paved squares with a `radius` and a `pattern` (rings, tiles, cobble).
- **EditorGround**: a top-down preview of the baked ground. Click **Rebuild Preview** in its Inspector after you move the coastline, a road or a plaza.
- **Buildings, Gardens, StreetFurniture, Trees**: prefab instances that you can move or rotate. A prefab's front (door, forge, bench seat) faces its local -Z. Nodes named `Lantern*` also get a warm light.
- **Spawn** and **RealmGate** markers. The gate faces along the marker's -Z.
- **Residents**: marker position, role, name, stationary flag and greeting. The smith, magician and innkeeper have interaction prompts.

Navigation, the minimap and the ground decoration (grass tufts, flowers, beach pebbles) are all derived from the scene. Keep residents outside building and prop colliders.

## Tools (never run by the game)
- `tools/author_home_scene.py` wrote the initial layout and `docs/realm_expansion/tavern_plan.png`. **Re-running it replaces your scene edits.**
- `tools/bake_home_nature.gd` bakes the realm trees, rocks and palms into `prefabs/nature_*.tscn`.
- `tools/make_home_assets.py` and `tools/bake_home_prefabs.gd` rebuild the building models.

Validation: `godot_voxel_editor --headless --path . res://tools/test_home_village.tscn`
