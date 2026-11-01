# Common enemies — batch 01

Five new **ordinary enemies**, saved as art assets inside VoxelRealms. Nothing is registered in `Enemies`, packs, biome tables, loot or the main scene. No bosses, phases, summons or gameplay changes.

Open `lineup.png` for front/back views and matching projectile concepts. `engine_preview.png` shows the models rendered by the game's actual voxel loader and shaders.

| Enemy | Intended home | Suggested attack |
| --- | --- | --- |
| Sporeback | Woods | Three slow green spores in a spread, fired from the nozzle under its cap |
| Thorn Hopper | Jungle | Two aimed barbed seeds, fired in a short burst from its throat |
| Cinder Beetle | Doom | One small, slow ember from the furnace mouth |
| Frost Moth | Fosen | Two ice chips, with a wing-beat telegraph |
| Ruin Watcher | Bluelay ruins | One small magic orb from its recessed eye; stationary sentry |

These designs complement the existing goblins, scorpions, crabs, dragons and spirits. All attack suggestions use existing movement modes and projectile patterns. Their proposed health (95–180) stays in the existing ordinary-enemy range; final balance and spawn density are untested suggestions.

## Files in each enemy folder

- `model.vox`: complete rest-pose model, ready to open directly in Goxel/MagicaVoxel. This is an editing/reference export; the rig uses the separate parts.
- `body.vox`, limb `.vox` files and matching `_glow.vox` files: the game's existing split-part format.
- `rig.json`: native `CreatureModel` format, with fixed frames, pivots, animation roles, voxel size, and projectile origin.
- `palette.json`: named source colors.
- `design.json`: suggested movement, attack timings, colors, hitbox dimensions and counterplay. Documentation only; this is not a live enemy definition.
- `projectile/`: editable projectile concept, with its own combined model, parts and rig.
- `preview.png`, `preview_front.png`, `preview_back.png`: renders generated directly from voxel geometry.

The wings of Frost Moth are decorative hitbox extensions, like the existing dragon wings; its suggested collision radius covers the body only. The projectiles deliberately propose no poison, freeze or burn status systems. A custom projectile VOX is an art reference: current `EnemyBullets` builds procedural pellet, bolt, orb and fireball geometry, and has not been changed to load these concept files. Mouth/eye origins include resting hover where needed; the small idle bob is visual, as in the current rig system.

## Animated review in Godot

Open `preview.tscn` and press **F6** to run only this asset gallery. **Space** pauses, **A/D** rotates the creatures, and **Enter** plays attack/flap animations. The gallery creates only `CreatureModel` instances and display platforms; it does not create an `Enemy`, realm, director or active projectiles.

To regenerate these staged assets:

```sh
python tools/make_common_batch_01.py
```

Validate against the actual loader and animation code without running gameplay:

```sh
/home/hugo/Godot/godot_voxel_editor --headless --path . \
  res://creatures/staging/common_batch_01/preview.tscn -- --validate-only
```

The generator reuses the existing `make_creatures.py` VOX writer and `voxel_sculpt.py` shape tools. `tools/preview_voxel_batch.py` renders assembled rigs from actual voxel geometry and can rebuild the existing-enemy reference sheet. No image-generation service was used.
