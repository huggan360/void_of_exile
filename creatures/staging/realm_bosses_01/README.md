# Realm boss art, batch 01

> **Superseded:** these bosses are live now. Their models moved to `creatures/<id>/` (built by `tools/make_realm_bosses.py`). See `docs/realm_expansion/REALM_BOSS_FIGHTS_IMPLEMENTED.md`. This folder is kept as the original art reference.

Four bosses for the four empty strongholds. **Staged art only**: no enemies, fights, spawns, damage, healing or new loot tables are registered. Blue Dragon remains the only active boss.

| Biome | Model | Reserved divine set | Visual design |
|---|---|---|---|
| Fosen | Rimeheart Prism | Frost | Six-faceted ice heart, orbiting shards, three genuinely different forms |
| Lava | Vharok, the Cinder Tyrant | Satan | Dark red demon, black armor, curved horns, bat wings, molten heart and tail |
| Desert | Aureate Scarab Regent | Holy Divine | Gilded six-legged scarab, ivory pharaoh mask, solar halo and pink jewel inlays |
| Dark | The Hollow Crown | Void | Floating torn mantle, hollow face, magenta eye/core, bony hands, broken runic halo |

## Inspect and edit

Open any boss folder's **`model.tscn`** in Godot to see actual meshes at game scale in the editor. The scenes contain named body/limb nodes and emissive geometry, without gameplay scripts. `model_conduit.tscn`, `model_tempest.tscn` and `model_infernal.tscn` expose alternative forms. `meshes/*.res` are baked from the native VOX parts.

Open **`preview.tscn` and press F6** for the animated art showroom. Keys 1–4 focus the corresponding boss, 0 shows the lineup, mouse wheel zooms, Escape exits. Showroom assets use the existing `CreatureModel` renderer and its limb/variant conventions.

For crystal stages and six-tower visual mock-up:

```sh
/home/hugo/Godot/godot_voxel_editor --path . creatures/staging/realm_bosses_01/preview.tscn -- --crystal
```

For one model, optionally animate its three crystal forms:

```sh
/home/hugo/Godot/godot_voxel_editor --path . creatures/staging/realm_bosses_01/preview.tscn -- --model=rimeheart_prism --cycle
```

The `.vox` files are the native editable sculpture sources, at comparable density to the Blue Dragon. `model.vox` combines the rest pose for voxel editors; named part files and `rig.json` preserve articulation. Whole poses and part frames fit within 256 voxels per axis; they are fitted frames, rather than allocating an empty 256³ cube to every small part. World voxel sizes are 0.04m (bosses), 0.044m (scarab), 0.032m (tower), 0.03m (shardling). Base/variant parts share fixed frames so transformations never jump position. Palette entries beginning `glow` have separate emissive meshes. Preserve frame origins when hand-editing part files.

## Crystal art and future encounter intent

1. **Sealed** (`model.vox`, normal rig): central pointed ice crystal and six upright ice plates. Fine cyan runes and floating basal shards.
2. **Conduit** (`model_conduit.vox`, variant `conduit`): plates spread out, exposing a bright heart and two hexagonal rings. Six `rimeheart_conduit` support models sit at radius 6.2m in a hexagon, 60° apart. Their top ring has six beam ports. The preview draws links between neighboring towers and to the boss heart. `rimeheart_shardling` is a separate hostile minion design, with four ice claws, bright eyes and a dorsal crystal.
3. **Tempest** (`model_tempest.vox`, variant `tempest`): a much wider six-bladed radial ice star, exposed heart, crown shard and larger rings. The art preview rotates it rapidly at 8 radians/second; this is visual demonstration only.

`rimeheart_prism/phase_art_plan.json` also records the form names, support positions, beam links and model references for the next pass.

Future combat proposal: each living tower channels a small heal (suggested 0.15% maximum HP/sec per tower, 0.9% total for six). All six must be destroyed to finish the conduit phase; no tower respawns within that phase. Shardlings pressure the player while the towers channel. Beam damage, target rules, immunity and final balance are left for the combat pass. Towers/minions never award divine loot. No healing, shield, combat summons, HP thresholds or tower objectives run in the current game.

Vharok also includes an `infernal` look: molten fissures spread across his body. His arms, legs, wings and tail are separate rigged parts. Scarab legs and wing plates are articulated; the spirit has separate hands/sleeves and halo.

## Divine ownership and drops

`divine_set_assignments.json` records all 17 sets and 85 unique source items. The four selected sets are reserved, with **proposed** independent 3% drops per item per eligible kill, personal white bags. Their current live rate is 0%. No divine items were imported or activated for these bosses.

User-facing text documentation:

- `/home/hugo/Documents/Voidrealm_textures/DIVINE_SET_USAGE.txt`
- `/home/hugo/Documents/Voidrealm_textures/Divine/SET_USAGE_INDEX.txt`
- Every set folder: `USAGE_AND_DROPS.txt` lists its individual source filenames and rates.

The Blue set stays live on Blue Dragon: each of its five items independently rolls 3%, with the existing 4% boss-health damage eligibility requirement. Other sets marked AVAILABLE remain unclaimed.

## Rebuild and validate

Run from the project root:

```sh
python tools/make_realm_boss_art.py
/home/hugo/Godot/godot_voxel_editor --headless --path . --script tools/bake_realm_boss_art.gd
python tools/document_divine_boss_sets.py
/home/hugo/Godot/godot_voxel_editor --headless --path . tools/test_realm_boss_art.tscn
```

Regeneration intentionally replaces generated model files; keep hand-edited VOX changes before rebuilding. None of these utilities runs during game startup.
