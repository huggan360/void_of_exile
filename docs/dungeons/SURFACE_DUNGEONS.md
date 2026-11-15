# Surface dungeons (November 2026)

Eight dungeons that open from Surface creatures, from a 3.5/10 fungus hollow to the 10/10 Starless
Sepulchre. They are the first dungeons built in the Surface's 0.25 m voxels (`generator_style` keeps the
room layout; `fine = true` turns on `FineDungeonGenerator`), and the first to use the glow framework
(`GlowRipples`): blinking and rippling light through vegetation, veins and glass.

| Dungeon | Rating | Opens from | Boss | Potions | Divine set |
| --- | ---: | --- | --- | --- | --- |
| The Sporewomb | 3.5 | Sporeback, Moss Tortoise (Woods) | Mother Mycora | hp, mp | Mycelium (2) |
| Saltbone Wreck | 4.5 | Tide Snail, Shore Crab (Shores) | Captain Saltmourn | attack, dexterity | Saltmourn (3) |
| The Jade Ziggurat | 5.5 | Green Dragon, Vine Mantis (Jungle) | Ixalith, the Jade Coil | magic, speed | Jade (3) |
| Afterlife | 6.0 | Brown, Blue and Purple Spirits | Elegy, the Lantern Shepherd | speed, dexterity | Afterlife (3) |
| Rimewake Barrow | 7.0 | Icebound Colossus, Rime Stag, Glacier Hermit (Fosen) | Jarl Hrimvald, the Barrow King | defense, attack | Barrow (4) |
| The Glass Labyrinth | 8.0 | Glass Scorpion, Dune Monolith (Desert) | Solenne, the Prism Oracle | magic, mp | Prism (4) |
| The Unlit Cathedral | 9.0 | Nightbell Idol, Umbral Reaper, Amethyst Widow (Deep Dark) | The Choirless Seraph | attack, mp | Requiem (5) |
| The Starless Sepulchre | 10.0 | The Unlit Cathedral (25%), the Glass Labyrinth (8%) | Oblivara, the Unmade God | 1 to 3 of any | The Unmade (6) |

Divine items are special, not automatically better: each set leans the way its boss does and pays for it
(the Afterlife gear trades attack for speed and dexterity). Their power follows the rating, and the
10/10 set is the strongest gear in the game.

## Creatures

Ids are folder names in `creatures/`. Height is the in-game height in meters (model_scale 1).
Bosses use `animation_style = "cantor"` (arms, head with a jaw, cloth/tail) and two phase variants.

### The Sporewomb (3.5) - warm fungal hollow under the Woods
Amber caps with teal gills, pale mycelium threads, puffballs, gold spore motes.
- `spore_puffling` 0.9 m: a round walking puffball on two stubby legs, a pore-mouth, amber cap dots.
- `mycelid_crawler` 0.7 m tall, 1.5 m long: a pale centipede of knotted mycelium, glowing teal joints.
- `glowcap_sprite` 1.0 m: a floating little mushroom fairy, teal cap, moth-like gill wings.
- `shroom_brute` 2.4 m: a hulking troll whose head is a split bracket fungus, club of root.
- `spore_witch` 2.0 m: a hunched crone in a cap-hat with a lantern of drifting spores.
- `bracket_warden` 3.2 m (miniboss): an old stump golem stacked with shelf fungi, mossy arms.
- `mother_mycora` 5.5 m (boss): a fungal matriarch. A huge frilled cap worn like a parasol-crown, amber
  above and glowing teal gills beneath; a pale gown of draped mycelium threads trailing roots; long thin
  arms with root fingers; small kind-looking glowing eyes under the brim; spore sacs on her back.
  Variants `bloom` (cap wider, gills blazing, flowers of fungus) and `rot` (violet rot, torn cap).

### Saltbone Wreck (4.5) - a sea cave where ships go to die
Wet planks, barnacled rock, kelp curtains, hulls and ribs, warm ship lanterns over teal water.
- `bilge_rat` 1.0 m: a big scruffy rat with a bandana and a rusty hook.
- `barnacle_crab` 0.9 m: a crab encrusted in barnacles and a bit of hull.
- `drowned_deckhand` 1.8 m: a bloated pale sailor with a striped shirt and a cutlass, seaweed hair.
- `kelp_shambler` 2.6 m: a dripping mound of kelp with two lantern-bright eyes.
- `cannon_gunner` 2.0 m: a drowned gunner hauling a small bronze cannon on his shoulder.
- `first_mate_grisk` 3.2 m (miniboss): a hulking crab-man first mate with an anchor.
- `captain_saltmourn` 5.0 m (boss): a drowned pirate captain. Huge tricorn hat with a hanging lantern,
  a long tattered coat crusted with barnacles and coral, an octopus-tentacle beard, sea-green glowing eyes,
  a hand cannon for the right arm and a cutlass in the left. Variants `storm` (coat and lantern blaze teal)
  and `abyss` (tentacles grown over, coral spreading, eyes deep red).

### The Jade Ziggurat (5.5) - an overgrown jungle temple
Carved jade and mossy limestone, gold glyph inlays, reflecting pools, vines and orchids, green fire.
- `temple_skink` 0.8 m: a quick jade-and-gold lizard.
- `vine_strangler` 1.6 m: a living bundle of vines with an orchid head.
- `plume_wisp` 1.2 m: a small feathered serpent that glides, gold plumes.
- `jade_guardian` 2.8 m: a carved jade statue warrior with a sun shield.
- `serpent_priest` 2.2 m: a snake-headed priest with a feather headdress and a jade staff.
- `obsidian_jaguar` 2.0 m tall (miniboss): a black jaguar with glowing jade rosettes.
- `ixalith` 6.0 m (boss): a feathered serpent coiled upright on its tail. Jade scales, a ruff and crest of gold
  and emerald plumes, two great feather wings (rigged as arms), a gold ceremonial mask over the brow,
  a jaw that opens. Variants `radiant` (plumes glowing gold) and `molted` (jade cracking to gold).

### Afterlife (6.0) - where the spirits go
Dark and soft: indigo loam, violet mist, bioluminescent ferns and bulbs along the walls in cyan, magenta and
gold that pass ripples of light between them, lotus pools, pale stone arches, floating motes.
- `lost_soul` 1.2 m: a small floating wisp-person, a hollow face and a tail instead of legs.
- `lantern_moth` 1.3 m: a pale moth with glowing eye-spots on its wings.
- `grave_creeper` 0.9 m: a crawling root-thing with glowing seed pods.
- `mourning_wraith` 2.6 m: a tall veiled weeping spirit, long sleeves, a lantern-glow face.
- `soul_warden` 2.6 m: a stone-masked guardian with a soul lantern and a staff.
- `willow_matron` 3.6 m (miniboss): a weeping willow spirit, a woman's face in the bark, glowing tendrils.
- `lantern_shepherd` 6.0 m (boss): Elegy, the guide of souls. Tall and slender in long layered veils of deep
  indigo; bone-white antlers rising from a faceless porcelain mask with one vertical glowing slit; a shawl of
  moth wings; a long shepherd's crook topped with a caged soul lantern (cyan); soul wisps round the hem.
  Variants `veil` (veils glow magenta) and `unbound` (mask cracked, antlers glowing).

### Rimewake Barrow (7.0) - a king's burial hall under the glacier
Blue glacier ice, runestones, frozen warriors in the walls, snowdrifts, cold blue braziers, aurora light.
- `barrow_wight` 1.9 m: a skeletal warrior with an ice-crusted round shield.
- `rime_hound` 1.2 m: a spectral ice wolf.
- `cairn_crow` 1.0 m: a big black crow rimed with frost.
- `draugr_huscarl` 2.8 m: a huge armored undead with a greataxe.
- `rune_seer` 2.2 m: a blind seeress with a runestaff.
- `frostbound_shieldmaiden` 3.2 m (miniboss): Sigrun, an undead shieldmaiden frozen into her shield.
- `jarl_hrimvald` 6.0 m (boss): the Barrow King. A crown of ice spikes, a skull face with blue glowing eyes,
  a frozen beard of icicles, a heavy fur cloak with a wolf pelt, iron plates carved with runes, a two-handed
  axe of ice. Variants `wrath` (runes blaze, cloak frosted white) and `thaw` (ice cracks over a glowing heart).

### The Glass Labyrinth (8.0) - a buried maze of fused sand
Walls of amber and clear glass, white-gold sand, mirrors, rainbow light running along the glass.
- `glass_mite` 0.8 m: a crystal beetle.
- `mirror_wisp` 1.2 m: a floating mirror shard with a ring of light.
- `lens_crawler` 1.0 m: a crab carrying a great lens on its back.
- `prism_golem` 3.0 m: a golem of glass with a rainbow core.
- `mirror_dervish` 2.2 m: a whirling robed dancer with mirror blades.
- `the_refractor` 3.2 m (miniboss): a floating cluster of lenses round one eye.
- `solenne` 6.0 m (boss): the Prism Oracle. A tall hovering oracle of faceted glass with a rainbow light
  core, a sun-disc halo of lenses, four arms holding prisms, a flowing white-gold veil, a gold blindfold.
  Variants `refracted` (body split into floating shards) and `eclipse` (core gone dark, light inverted).

### The Unlit Cathedral (9.0) - gothic halls in the Deep Dark
Black basalt, violet and rose stained glass, forests of candles, iron chandeliers, bells, red carpet.
- `candle_wraith` 1.6 m: an acolyte whose head is a melting candle.
- `bell_imp` 1.0 m: a gargoyle imp carrying a bell.
- `censer_bearer` 1.9 m: a hooded monk swinging a censer of violet smoke.
- `glass_knight` 3.0 m: a knight made of stained glass panes in a lead frame.
- `hymn_abbess` 2.4 m: a veiled choir abbess with a glowing hymnal.
- `bellringer` 3.6 m (miniboss): a hunched giant with a great bell on a chain.
- `choirless_seraph` 6.5 m (boss): a fallen seraph with six wings, the inner pair black feathers and the outer
  four stained-glass panes; a faceless gilded mask weeping wax; violet robes; a halo of hanging bells and
  candles; a broken organ-pipe scepter. Variants `kindled` (candle wings ignite) and `hollow` (glass shattered
  to bare lead frames, the mask cracked over a void).

### The Starless Sepulchre (10.0) - a vault outside the world
Black obsidian with glowing gold kintsugi seams, starfield walls, floating broken pillars, moon-white dust.
- `star_eater` 1.3 m: a void eel with stars in its belly.
- `kintsugi_shade` 1.9 m: a shattered porcelain figure mended with gold.
- `astral_reaver` 3.2 m: a void knight in black armor with gold seams and a star-sword.
- `unmade_herald` 2.6 m: a floating porcelain mask over a cape of night.
- `oblivara` 8.0 m (boss): the Unmade God. A colossal shell of black porcelain broken and mended with glowing
  gold seams; a serene cracked mask face with closed eyes; six arms in calm poses; a broken halo of gold shards;
  robes dissolving into starfield at the hem. Variants `awakened` (eyes open, seams brighter) and `unmade`
  (the body fragmenting into floating pieces, more void).

## How it is built

| Piece | Where |
| --- | --- |
| Definitions, themes, portal looks | `scripts/dungeons/dungeons.gd` (`fine = true`, theme `fine` and `glow`, `portal_hole.shape`) |
| 0.25 m terrain | `scripts/dungeons/fine_dungeon_generator.gd`; blocks appended to `SurfaceBlocks` (styles VEIN and PANES in `shaders/surface_terrain.gdshader`) |
| Glow framework | `scripts/effects/glow_ripples.gd`, `shaders/include/glow_ripple.gdshaderinc`, `shaders/glow_flora.gdshader` |
| Dressing, lamps, wall growth | `scripts/dungeons/fine_scenery.gd` (called by DungeonScenery) |
| Doors | `scripts/dungeons/dungeon_portal_styles.gd` (+ glow in `shaders/dungeon_hole.gdshader`) |
| Creatures, bosses, portal drops | `scripts/enemies/surface_dungeon_enemies.gd`, fights in `scripts/enemies/bosses/` (base `surface_boss.gd`) |
| Divine sets | `scripts/game/dungeon_divine_sets.gd`; new shot looks in `Arrows`, charge styles `beam` and `refract` in `Player` |
| Loot | `Loot.BOSS_POTIONS`, `BOSS_GRADES` / `GRADE_ROLLS` 4, 5, 6, 9, 10; rarity in `Items.DIVINE_SOURCE_SCALE` |
| Art | `tools/make_dungeon_creatures_*.py`, `tools/make_surface_dungeon_projectiles.py`, `tools/make_surface_dungeon_icons.py` |

### Glow framework
`GlowRipples.emit(source, at, color, {speed, width, range, strength, flat, rings, gap, delay})` sends a ring of
light; `GlowRipples.flood(source, level, time, back)` lights (or darkens, below 0) everything. Both work from
the server (sent to the realm's players). Plants "chatter": small ripples leave random glowing plants. Any
material that includes the shader include can be watched. Bosses (SurfaceBoss) ripple the walls on every new
stage and big attack; when they fall the whole dungeon lights up.

### Checks and watching
- `godot --headless --path . res://tools/check_surface_dungeons.tscn` (layouts, terrain, dressing, doors, art, loot).
- Watchers: `tools/boss_watch/watch_<boss>.sh` (Desktop: Boss Fight Watchers), in the real generated dungeon.
- Play one: `main.tscn -- --play-dungeon=afterlife` (offline, maxed archer).
