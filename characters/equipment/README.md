# Equipment appearance

Weapons use the original authored Archer bow, Wizard wand and Merrow trident as
templates. The G1 voxel files are identical to those sources, with their original
socket offsets and scales. All wand classes share the Wizard's wand. Higher tiers
recolor the same sculptures; G7/G8/Divine add small crown, prong or limb details
without changing the grip or the animated bowstring endpoints. Item icons supply
palettes, not extruded geometry.

Rebuild with `python tools/make_equipment_models.py` (Pillow required). This tool
owns the `.vox` files and `profiles.json` in this directory. Weapon templates come
from `make_hero.py` and `make_player_class_models.py`; item PNGs supply colors.

`EquipmentAppearance` recolors garment roles while preserving skin, hair,
leather, accessories and Merrow anatomy. G1/empty armor retains the original
class colors. Advanced armor has small collar clasps rather than rectangular
borders around the legs. Hands are solid fists; unarmed figures relax their arms.

The original rear garment moves with the walking stride. Body meshes are split
at the pinned waist (5.5 voxel units), and vertex alpha identifies only lower rear
cloth. The shared voxel shader defaults to zero motion for every other mesh.
Quivers, satchels and bottles retain their original positions. Recoloring preserves
the cloth mask, and each actor's material supplies its own stride value. Source
meshes and shared materials remain immutable.

World actors and portraits use the same equipment method. Empty weapon slots
hide weapons and strings. Portraits accept live items, ID strings and serialized
item dictionaries. Their materials ignore the world dissolve window. Remote
figures use existing equipment IDs; spells and bonus slots are unchanged. Social
props consult current equipment visibility when hiding and restoring weapons.

Validation (use the project's custom voxel editor in place of `godot`):

```
godot --headless --path . res://tools/test_equipment_appearance.tscn
godot --path . res://tools/preview_equipment.tscn
godot --path . res://tools/preview_equipment.tscn -- --rear --walk
```

The test covers 254 compatible catalog entries, original G1 source equality,
cloth recoloring and mask preservation, unchanged base geometry, empty/default
slots, remote updates, portraits, social props and inventory save/load. It samples
65 stride positions per class and checks rearward boot clearance against the
animated cloth plane.

The review writes `/tmp/equipment-review.png` (G1, G2, G8, Stormeye and empty
slots). `--rear` selects the rear view; `--walk` shows five stride positions in
G8 gear. Rear walk output is `/tmp/equipment-walk-back.png`.
