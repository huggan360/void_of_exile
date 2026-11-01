# Detailed outdoor villages — revised

The earlier terrain-block houses have been removed. Villages now use nine native, editable VOX building variants in `props/houses/`, built from **12.5 cm voxels** using the same mesh loader/materials as the portal. Each has **two floors** of rounded, stacked logs with exposed growth rings, timber bands, framed windows/mullions/shutters, flower boxes, balconies and railings, shingle courses, gables/dormers, chimneys, hanging lanterns, signs, wood piles and barrels. Fosen variants have snow-laden roofs; desert variants use warm timber and teal roofs. A model's VOX palette and geometry carry its detail rather than metre-sized terrain blocks.

All buildings are **closed exterior models** with solid collision across the complete building volume, including the entrance. Players and residents cannot enter them. The market stalls, well and benches are also small-voxel models in `props/town/`.

Smiths, magicians and other service NPCs now stand **outside**, on the street side of their house. Future shop UI metadata and portraits remain available, but no indoor travel or shop entry is implemented.

Residents use shared per-town pathfinding across the **whole settlement and about 12 metres beyond its boundary**, avoiding buildings, props, trees and terrain hazards. Ordinary walking goals can lie in the outskirts. They can step up terrain blocks. Nearby living creatures trigger fear: an exclamation mark appears and the NPC runs away at 2.9 m/s, compared with a normal walk of 1.1 m/s. Shopkeepers also flee; after four seconds without nearby threats they calm down and return to their outdoor stations. Hostiles still cannot spawn inside the settlement.

The seeded central village (12 houses), forest/desert/Fosen outposts, required smiths/magician, lake, roads, strongholds and Blue Dragon placement are preserved. This revision does not reset realm progress or change the realm layout version.

## Preview and source

- `detailed_houses.png`: all nine native geometry previews.
- `log_houses_engine.png`: buildings rendered through Godot's actual VOX loader and shaders.
- `log_village_ingame.png`: the rebuilt capital in the running game.
- `townsfolk.png`: six small resident designs.
- `realm_map.png`: the seeded region/road overview.
- `tools/make_village_houses.py`: rebuild houses and small town props.
- `scripts/world/village_house.gd`: shared building meshes and closed collision bodies.
- `scripts/world/town_navigation.gd`: shared local pathfinding and creature detection.
- `scripts/world/town_npc.gd`: roaming, fear, fleeing, recovery and return behavior.

## Validation

`tools/test_outdoor_towns.tscn` includes the multi-seed settlement suite, plus closed-door collision, outdoor shopkeeper stations, cross-town paths, outside-town goals, and a live goblin frightening a shopkeeper into fleeing and later calming down. In-game Forward+ rendering and the native model review are also checked.

```sh
env XDG_DATA_HOME=/home/hugo/tmp/voidrealm_towns_test \
  /home/hugo/Godot/godot_voxel_editor --headless --path . \
  res://tools/test_outdoor_towns.tscn
```

Earlier `central_village.png`, `desert_village.png` and `fosen_village.png` screenshots show the superseded block-based prototype; use the new log-house previews above for this revision. The realm seed/layout migration introduced in the previous pass still archives version-1 progress under `legacy_layout_v1` once; this house/NPC revision requires no further migration.
