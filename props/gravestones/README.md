# Five grave-marker props

Open `lineup.tscn` to inspect all five together in Godot. Each tier folder has a standalone `model.tscn`, assembled `model.vox`, editable solid/glow voxel sources, rig metadata and baked mesh resources. Ground level is y=0, the inscription faces -Z and each voxel is 0.08 m. The same-scale render is `preview.png`; a copy and individual renders are on the Desktop.

1. **Novice — Wooden Marker:** small weathered wooden cross, rope binding, iron nail and a little earth/grass at its foot.
2. **Adventurer — Weathered Headstone:** rounded fieldstone, chipped edge, a crack, lichen and a dark RIP inscription.
3. **Veteran — Carved Veteran Grave:** a broad stepped stone plinth, a bordered epitaph panel and carved cross.
4. **Hero — Hero Memorial:** dark blue granite, bronze/gold edging, sword-and-shield relief and two small blue votive stones.
5. **Legend — Winged Legend Monument:** tiered marble pedestal, paired carved wings, gold crown, funerary skull, RIP inscription and restrained spirit-crystal accents.

Rank names describe the visual progression only. No character-quality thresholds, death-spawn behavior, collisions, loot, UI or gameplay registration were added.

Source generation: `python3 tools/make_gravestones.py`.
Editor asset generation: `godot --headless --path . --script tools/bake_gravestones.gd`.
Render: `godot --path . tools/render_gravestones.tscn`, then `python3 tools/compose_gravestone_preview.py`.
