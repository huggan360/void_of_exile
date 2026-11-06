# Player character art

All five classes are playable (see `scripts/game/player_classes.gd`): Archer (Bow, Cloak), Wizard (Wand, Robe), Priest (Wand, Robe), Alchemist (Wand, Cloak), Merrow (Trident, Cloak). Every class uses Spells and bonus items. `ArcherModel` animates the bow/string; `ClassModel` animates the four staff/trident classes. Local and remote players use these same models and the same `animate(move_ratio, delta)`, `play_shot()`, `hold` and `class_id` API.

Open `class_model_lineup.tscn` to inspect all five characters. Each class folder contains `model.tscn`, separate voxel parts, baked meshes, palette and `rig.json`. `model.vox` is a coarse unposed reference for voxel editors; use the scene for exact fractional pivots, grip clearance and rest poses.

Coordinates use Godot's +Y up and **-Z forward**, on the face side; anatomical right is +X. Player faces the aim with `atan2(-direction.x, -direction.z)` and applies that yaw to the model. Animations use the inner rig's coordinates, so these signs also hold after any model yaw:

- Positive X pitch moves a hanging arm (-Y) toward -Z, forward. Negative X pitch moves an upright weapon (+Y) toward -Z; positive pitch would tip its head backward.
- Shoulder and elbow rotations compose. The wrist cancels both, including any shoulder spread, keeping the fist and shaft upright together. Casts add a **negative** wrist pitch (up to -35 degrees) to swing the weapon tip forward.
- The Archer holds the bow in the **right (+X) hand** and draws with the **left (-X) hand**. The string sits behind the bow (+Z); drawing moves its center farther +Z, and releasing returns it toward -Z. The bow advances clear of the hood before moving inward to the firing pose.

All classes use 0.1125 m voxels, 16-voxel body proportions, a four-pixel face opening with dot eyes, shoulders at X ±4 / Y 9 and hips at -2/4/0 and 1/4/0. The Archer's shoulders sit one voxel forward (Z -1) so the elbows can reach across in front of the chest. Each arm has a 2.5-voxel upper segment, a 3-voxel elbow-to-wrist segment and a separate wrist. `scripts/player_arm_rig.gd` handles composed rotations and the Archer's two-bone reaching; walking keeps a small elbow bend and the existing bounce, lean and leg stride.

The hierarchy is `Rig/ArmR/ForearmR/RightHand` and `Rig/ArmL/ForearmL/LeftHand`. Weapon sockets live below `RightHand`; the Priest's book and Alchemist's flask attach to `LeftHand`. The fist is a ring with an empty center column. Staff shafts and the bow grip are centered in that hole, with a 0.05-voxel gap on each X side; staff Z clearance is also 0.05 voxels. Forearms end behind the grip. Hand and weapon share the wrist transform, preserving clearance throughout the animation. The Archer's narrower drawing fist has its own socket offset and follows the moving string center.

`hold` prepares the thrust/draw during windup or charging. `play_shot()` immediately poses the extended attack when Player/RemotePlayer emit the projectile; `SHOT_TIME` remains 0.25 s. The bowstring releases during the first quarter of that interval, then both arms settle. Staff elbows extend from 55 to 5 degrees while the shoulder advances and the wrist swings the tip forward. No projectile timing or aiming code is handled by these rigs.

- **Wizard:** blue/violet robes, crooked pointed hat, little white beard and crystal-tipped wooden staff.
- **Priest:** ivory/gold robes, blue mantle, small pointed mitre, gold cross staff and prayer book.
- **Alchemist:** teal coat, raised brass goggles, reagent bottles on a satchel, elixir-topped staff and hand flask.
- **Merrow:** seafoam skin, side fins and crest, coral hair ornament, teal clothing, webbed boots and right-hand trident.

Regenerate source assets with `python3 tools/make_player_class_models.py`, then bake scenes/meshes with `~/Godot/godot_voxel_editor --headless --path . --script tools/bake_player_class_models.gd`. The generator retains the Archer's existing body/leg files; its new `bow_frame.vox` omits the old static string. Two thin mesh segments in the baked scene form the animated string. Legacy unsplit arm/bow files are unused by the current rigs. `class_model_manifest.json` lists all five playable rigs; gameplay does not read the manifest.

Class stats, growth, equipment and New Character choices come from `PlayerClasses`; `CharacterAvatar` renders portraits from these models.
