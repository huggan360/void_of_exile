# Wand model review

Included in 26.5-beta.

All 38 equipped wands have authored voxel crowns with equal depth and matching
detail on the front, back and sides. The geometry and palette roles are
invariant under quarter turns and reflections around the vertical shaft.
Rounded pearls, faceted crystals, mushroom caps, bells, cages, forks and halos
keep the individual item themes. Vertical halos cross in two planes; branches,
prongs and glowing details repeat around the shaft. The grip and shaft length
retain their original geometry and scale. Equipped wands sit one voxel lower
in the hand than the original fitting.

`tools/sculpt_wand_heads.py` authors the crowns. Run
`python3 tools/make_equipment_models.py` to regenerate the shared world, remote
player and portrait equipment assets. Inventory icons and combat stats are
unchanged. The mesh cache version increases so existing installations discard
the old flat meshes even when a release retains its version number.

Validation:

- `python3 tools/test_wand_sculpts.py` checks all 38 emitted assets for volume,
  rotational and mirror symmetry, connected geometry and unchanged grips.
- `tools/test_equipment_appearance.tscn` exercises all 367 compatible equipment
  combinations, remote players, portraits, animation and saved inventory.
- `tools/preview_wand_sculpts.tscn` renders the actual models from the front,
  back, side and an angle, plus six equipped figures from the front and back.
  Local output is `/home/hugo/tmp/wand_review/`.
