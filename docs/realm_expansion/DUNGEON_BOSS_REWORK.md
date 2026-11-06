# Dungeon boss models and special shots

The Drowned Cantor, Gilded Vizier, Magma Warden and Hollow King now use new
articulated sculpts. Geometry is authored in coarse cells within a 32-cell
canvas, then enlarged by eight with the established voxel exporter. Runtime
parts retain those broad colour blocks. Glow is a separate voxel mesh.

- Cantor has a curved rib cage, a vertebral back, an abyssal bell-skull with a
  moving lower jaw, skeletal hands and two jointed eel-like robe tails. His
  bell staff and its hand anchor sit outside his body on the right arm.
- Vizier is a mummified serpent oracle with a convex, striped cobra hood,
  fangs, a crescent staff and a long coiled tail with a separate tip. Back
  scales and gold bands wrap around the volumes rather than facing one side.
- Warden is an obsidian furnace beast with four articulated legs and ankles,
  hooked toes, an iron grille over a glowing heart, horned jaws, layered rear
  plates, chimney vents, an offset hammer and an ember-filled tail flail.
- The Hollow King is a wasted armoured knight with a skull inside a deep
  hood, a broken crown, asymmetric pauldrons, jointed knees and sabatons, an
  executioner's blade, two torn front tabards and five independent cape strips.
  His existing throne, rise, sword, charge and kneeling poses use the new rig.

Head, jaw, cloth, hood, shell and tail motion follows the replicated attack
poses. Nested tails and ankles inherit their parent transforms. Weapon fire
origins follow the actual animated right-hand grip. Intros unfold the joints
without stretching the model; deaths settle the limbs and keep voxel size
constant. Existing phase palettes also recolour the head, jaw and shell.

Generate these four bosses with `python3 tools/rework_dungeon_bosses.py`.
It backs up their existing assets and the manifest under `~/tmp/` first.
The older court, blue-creature and Hollow King generators contain the
superseded models; running those requires running this generator afterwards.
Editable masters live under each creature's `source_32/`, with runtime rigs,
parts and assembled models beside that directory. No editor baking is needed
for the runtime loader.

## Projectile effects

Effects use the existing server-authorized hit and buff systems. Blocking or
evading a shot keeps its effect from landing. Repeated hits from the same
named attack refresh one effect instead of adding multiple copies. Normal
bullets, damage-free warnings and terminal burst fragments keep their
existing behaviour. Special centre shots replace an existing fan bullet.

| Boss | Special projectile | Effect |
| --- | --- | --- |
| Rimeheart Prism | Large, slow crystal-bloom orb, before its burst | Frozen / Static, 3 seconds |
| Thornmaw Bloom | Pale centre thorn seed; three pale seeds in its later ring | Speed -10, 1.75 seconds |
| Blue Dragon | Large, slow comet-wheel flames | Defence -8, 2 seconds |
| Vharok | Larger pale centre fireball | Defence -8, 2 seconds |
| Aureate Scarab Regent | Heavy curling discs | Dexterity -10, 2 seconds |
| Hollow Crown | Large black-sun parent orbs | Quiet, 1.75 seconds |
| Goblin King | Thrown clubs | Dexterity -8, 1.75 seconds |
| Abyssal Siren | Pearl song discs | Quiet, 1.25 seconds |
| Drowned Cantor | Larger pale centre note in the last refrain fan | Quiet, 1.75 seconds |
| Gilded Vizier | Rose sundial seals | Dexterity -10, 2 seconds |
| Magma Warden | Larger hot centre ember in the last cinder fan | Defence -8, 2 seconds |
| Pyre Ent | Brighter first canopy wave | Speed -8, 1.5 seconds |
| Hollow King | Warned executioner's cleave | Attack -8, 2.5 seconds |

Freeze uses the existing Static movement lock. The other special shots avoid
hard immobilization and complete armour removal. Encounter timing, bullet
counts, ordinary damage and loot stay as authored, including Rimeheart's
existing damage increase.

The initial work only ran asset generation. A subsequently requested short
headless check exercised intros, phases, joints and death transitions for
all 13 bosses, together with Burning checks (102 assertions, zero failures)
and the existing status checks (81 assertions, zero failures). It caught and
fixed a missing explicit bool type in the new tail animation. Visual and
audio presentation still need a gameplay pass.
