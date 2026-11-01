# Player character art

All five classes are playable (see `scripts/game/player_classes.gd`): Archer (Bow, Cloak), Wizard (Wand, Robe), Priest (Wand, Robe), Alchemist (Wand, Cloak), Merrow (Trident, Cloak); every class uses Spells and bonus items. The Archer uses `ArcherModel`; the others are animated from their `model.tscn` by `ClassModel` (walk, cast with the weapon arm).

Open `class_model_lineup.tscn` to inspect the four new characters together in Godot. Each class folder contains `model.tscn`, assembled `model.vox`, separate voxel parts, baked meshes, palette and a rig descriptor. Right-hand equipment lives under `Rig/ArmR/RightHand`. The Priest's book and Alchemist's flask use separate left-hand attachments.

All four use the Archer's 0.1125 m voxel size, 16-voxel body proportions, four-pixel face opening with dot eyes, shoulder pivots at ±4/9/0, and hip pivots at -2/4/0 and 1/4/0. Headwear and held items extend beyond the body envelope. Faces point toward -Z and anatomical right is +X.

- **Wizard:** blue/violet robes, a crooked pointed hat, a little white beard and a crystal-tipped wooden staff.
- **Priest:** ivory/gold robes, a blue mantle, a small pointed mitre, a gold cross staff and a prayer book.
- **Alchemist:** teal coat, raised brass goggles, reagent bottles on a satchel, an elixir-topped staff and a hand flask.
- **Merrow:** seafoam skin, small side fins and a crest, a coral hair ornament, teal clothing, webbed boots and a right-hand trident.

Class stats, growth, equipment and the class choice (New Character) all come from `PlayerClasses`; portraits are rendered from these models by `CharacterAvatar`.

Regenerate source assets with `python3 tools/make_player_class_models.py`. Generate editor scenes with `godot --headless --path . --script tools/bake_player_class_models.gd`. The art manifest is `class_model_manifest.json`; gameplay does not read it. The Archer's files are unchanged.
