# Chunky pixel-art boss redesign

The five live boss models now use roughly 32×32×32 coarse design grids, enlarged eight times into 256×256×256 VOX canvases. Faces, claws, horns, plates, crystal facets and wing membranes use deliberate blocks of color instead of fine noisy sculpting. Only tiny eye/core glints use finer pixels. Material grain is disabled on these rigs, and emissive surfaces use restrained brightness to preserve their color.

- **Blue Dragon:** a long, crouched four-legged predator with a muscular cobalt body, towering swept bat wings, backward horns, a jagged spine, a long fanged jaw and small inset amber eye slits. The enraged form lights the wing ribs, tail spines and eyes with blue fire.
- **Rimeheart Prism:** a tall blue faceted core with a dark eye socket and cyan light. Six large surrounding crystals open into the conduit form and turn into outward storm blades in the tempest form.
- **Vharok:** a broad red demon with black shoulder/chest armor, split hooves, hooked claws, long ochre horns, dark red bat wings and an orange furnace heart. Infernal and heart-unbound forms expose progressively more fire.
- **Scarab Regent:** a dark teal beetle with gold armored wing covers, six angular legs, striped pharaoh mask, forked crown horn, mandibles and a warm glowing heart. Open-wing and sunheart forms retain their own animated wing shapes.
- **Hollow Crown:** a crowned purple wraith with a torn robe silhouette, asymmetric cyan/magenta eyes, oversized skeletal hands and a broken octagonal halo. Later forms fracture the crown and light the separated halo segments.

The five breakable shells also use the coarse style and keep their three crack stages. Existing encounter phases, animation roles, loot and attack timing remain in place.

All five bosses now select their own colored authored voxel shots at the central projectile spawn path. The twelve source shot models include azure/cyan bolts and orbs, dark ice shards, ember shots, gold/teal needles and returning sun discs, and violet/magenta bolts and void orbs. Terminal orb volleys inherit the same art. Small voxel trails replace bright fire clouds around these models, and glow is reduced so the palettes remain visible.

Vharok's cleave is a **200×24×80 voxel swept-back flame crescent**. It is authored at eight-times coarser resolution, with a thin ribbon curving backward along +Z (flight is -Z), tapered tips, jagged trailing flame tongues, dark red undersides, orange fire and an amber-hot edge. It stays broadside to flight with a subdued local light. Thin offset collision boxes follow the curved silhouette for terrain, player and shield contact, leaving the concave gap empty. A single broad check gates detailed terrain sweeps. The paired cleaves keep their shared hit list.

Live models and fixed variant frames are in `creatures/<boss>/`. Each model includes editable low-resolution originals in `source_32/`; game rigs use the enlarged sources. Full models, rigged editor scenes and part meshes are updated. Projectile sources are in `creatures/boss_projectiles/`.

Authoring: run `python3 tools/redesign_pixel_bosses.py`, then generate editor scenes with `godot --headless --path . --script tools/bake_realm_boss_art.gd -- --only=blue_dragon,rimeheart_prism,vharok_cinder_tyrant,aureate_scarab_regent,hollow_crown,egg_blue_dragon,egg_rimeheart,egg_vharok,egg_scarab,egg_hollow_crown`. The older `make_realm_bosses.py` produces the superseded sculpted art.

Original art backup: `/home/hugo/tmp/boss_art_before_pixel_redesign_20261101_095215/`. Only asset generation was run in this pass; no tests, visual previews or game sessions were run, as requested.
