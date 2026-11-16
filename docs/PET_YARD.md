# Pet Yard integration

The Tavern's `PetYardGate` marker is beside `ChambersGate`, at `(82, 10, 4)`.
Online and Singleplayer players enter through its "Pet Yard" sign. The server
resolves `pet_yard` to `pty_<account id>` and rejects another account's id.
Party teleports and shared fog cannot enter the yard. The return portal goes
to the player's Tavern, including a campaign Tavern.

`PetYardWorld` is an island (about 150 m across) in a quiet sea, in the
Surface's 0.25 m voxels (`PetYardTerrain`, SurfaceBlocks). Its shape is sampled
once onto a 1 m grid (`PetYardWorld.build_grid()`, shared by every yard and the
server) from round land blobs with a noisy coast, rolling hills, a wooded hill
in the north-west, beaches and a sea floor (`SEA_LEVEL`). `column(x, z)` gives
each terrain column's top and block; the generator and `ground_height()` both
read it. The terrain is cached on disk (`TerrainCache` "pet_yard").

- The fenced **meadow** (`FENCE`, flat at y = 0, the nest's mound, the pond and
  bridge) is the pets' own: wanderers keep to it (`pet_walkable()`). A gate in
  its east fence (`GATE_Z`, `GATE_HALF`, three fence pieces wide, a timber arch
  and a signpost) opens onto the trail.
- The **trail** (`TRAIL`, a dirt path with lanterns) winds over the hills to the
  **Pet Store**: the walk-in model `pet_store_house` with its roof as a second
  model `pet_store_roof` (tools/make_pet_store.py, baked by
  tools/bake_vesperis_houses.tscn into scenes/vesperis/catalog.json). It stands
  at `SHOP_POS` facing +Z, its walls and furniture collide (`shop_solids()`,
  also on the server), its floor is a collider at `SHOP_POS.y` with the terrain
  a voxel lower inside `SHOP_FLOOR`, and its roof hides while you are inside.
  The storekeeper stands behind the counter at `STORE_POS`.
- `scripts/world/pet_yard_island.gd` draws the island on clients: the shop and
  its lights, trees (Surface prefabs: oaks, maples, blossom, birch, firs on the
  hill, palms by the shore) with trunk colliders, bushes, rocks and logs, and
  SurfaceFlora ground cover in 24 m chunks that leans away from players and
  pets (group `pet_visuals`).

The dedicated server creates only the layout data. There is no enemy director.
The core's PetServer excludes `pty_` worlds from ability pulses.

The Caretaker calls `PetPanel.open_for(main)`. The store uses ShopKeeper and
the account service shop `pets`. Shops also provides a 350 Dot egg in its test
fallback. The live account service still needs that shop and its stock.

Yard art uses `props/pets/` rigs or `obstacles/pets/` voxel files. Current names
include `hatching_nest`, `pet_store`, `caretaker_cottage`, `pet_fence`,
`food_bowl`, `toy_ball`, `egg_crate` and `lantern_post`. Missing art uses the
existing cottage, market and lantern props or small batched voxel details.
NPCs use `caretaker` and `pet_storekeeper`, falling back to existing residents.
Wandering uses `PetFollower.animate_gait`, including its rarity effects.

## Checks

```sh
XDG_DATA_HOME=/tmp/voe_yard_check ~/Godot/godot_voxel_editor --headless --path . --import
XDG_DATA_HOME=/tmp/voe_yard_check ~/Godot/godot_voxel_editor --headless --path . res://tools/pets/check_yard.tscn
```

The check covers layout reachability, bridge terrain, a scene-free dedicated
layout, all 15 wandering species, equip changes and the confirmed hatch moment.
A live server attempt in the Codex sandbox could not bind UDP port 24987, so
account login, travel, purchasing and party isolation still need a live check.
No windows or screenshots were used.

## Core handoff

On this engine, external `PetsClient.changed` resolves to the Script resource's
built-in `changed` signal, while `PetsClient.receive()` emits `_events.changed`.
The yard bridges the latter to the former while it is loaded. This also wakes
the core's NetClient follower and PetPanel subscribers in the yard. Core should
make its public changed event consistent for consumers outside the yard; the
compatibility bridge can then be removed. No core pet files were edited by
the yard session.
