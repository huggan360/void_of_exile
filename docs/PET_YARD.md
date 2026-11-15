# Pet Yard integration

The Tavern's `PetYardGate` marker is beside `ChambersGate`, at `(82, 10, 4)`.
Online and Singleplayer players enter through its "Pet Yard" sign. The server
resolves `pet_yard` to `pty_<account id>` and rejects another account's id.
Party teleports and shared fog cannot enter the yard. The return portal goes
to the player's Tavern, including a campaign Tavern.

`PetYardWorld` owns scene-independent spawn, pond, bridge, fence and solid
layout data. `NEST_POS`, `CARETAKER_POS` and `STORE_POS` are world coordinates.
The dedicated server creates only that layout; clients build terrain, props
and interactions. There is no enemy director. The core's PetServer excludes
`pty_` worlds from ability pulses.

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
