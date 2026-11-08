# Space update - implementation plan

Source: `SPACE_INSTRUCTIONS.md` (the user's notes). This plan splits the work into two passes.
Pass 1 finishes the Theory of Everything as a complete, playable dungeon with the new fairytale look.
Pass 2 builds everything that comes after the boss: the Nexus station, the battleship, the open
space world with round planets and the five new campaigns.

## Reading of the instructions

- The Theory of Everything keeps its route (Aurora, Chromatic Expanse ribbon, Vessel 02 wreck,
  The Unravelling, Convergence arena) and its puzzles. The look changes from grey and industrial to
  a fairytale ship: wooden hulls, green fire, green crystals, many soft amber lights, green and pink
  accents. The wreck becomes a scary fairytale. Ship interiors become less like rows of identical
  rooms and more like story places. The rainbow ribbon stays.
- The dungeon gets enemies and a boss: black, xenomorph-like creatures with long, moving tails and
  glowing eyes. Five enemy types and one large, dreadful boss. Difficulty 6/10.
- Killing the boss opens a portal to a new hub, the Astral Nexus (a space station "tavern").
  Arriving plays a showcase cutscene (this npc does X, this rocket goes to the Tavern, this
  battleship goes to the planets...). Every trip to or from the Nexus is a cutscene.
- The normal Tavern gets a small launchpad with a rocket, locked until the pack's first campaign is
  done, that flies straight to the Nexus. Campaigns can be started from the Nexus, and R in space
  returns to the Nexus.
- From the Nexus the party boards a battleship (one shared ship, or anyone can spawn their own from a
  command table). One player pilots; others take turrets and other stations. Z toggles between
  walking around inside the ship and the seat view. Pilot and turret seats have their own cameras
  and crosshairs. Nexus camera is top-down, in the ship first person, seated defaults to third
  person with optional first person flying.
- Space is one huge world, "like No Man's Sky": many planets in one 3D space, round planets you can
  land on and walk around with gravity toward the ground, new biomes, structures. Regions: the
  peaceful region around the Nexus, an asteroid field with crystals, and behind it a dark,
  dangerous region. Vibrant unique textures, cosy ships, scary deep space.
- M opens a large minimap in the middle of the screen everywhere; in space it shows a space map
  with every planet.
- Five long campaign missions take place up here (one flies through the crystal asteroid field,
  others go to planets; quests to find things, talk to people, repair the ship, and so on).

## Pass 1 - finish the Theory of Everything

1. Creatures (Codex builds the voxel art, I integrate):
   - Five enemies and a boss, black chitin with acid-green and fairy-pink glows, all with long
     segmented tails.
   - New rig role `tail_chain` in `CreatureModel`: tail segments chained through `parent_limb`,
     driven by a spring-damper per segment (travelling wave, drag when the body turns or moves,
     curls up during windups, whips on strikes). Works for every creature that uses the role.
   - Enemy and boss definitions at 6/10 (between the Azure Grotto and the Drowned Spire), boss
     script with four phases bound to the four shrinking arena stages.
   - Packs placed in both decks of Vessel 02, a few in the Aurora's rear and on the Convergence
     approach. Spawning respects the deck height (upper deck, arena bowl).
   - Dungeon rating 9.0 -> 6.0. The Astral Frontier's waiting objective becomes "defeat the boss".
2. Fairytale art rework of the Theory (`theory_art.gd` palettes, materials, lights): wood planking
   for hulls and decks, green crystal clusters, green fire in braziers and engines, many small amber
   lights, pink and green accents, warmer haze. Wreck: twisted wood, dead crystals, green
   ghost-fire, darker amber. Rainbow ribbon kept. Interiors broken up with story props (bunks, maps,
   lanterns, plants, books, crystal growths) instead of repeated machinery.
3. Large minimap on M (centered overlay, works in every world; the Theory shows its route).
4. Boss defeat -> portal toward the Nexus. In pass 1 the portal returns to the Tavern with a
   placeholder; it is retargeted in pass 2.

## Pass 2 - the Astral Nexus and open space

1. Astral Nexus world: station hub, top-down camera, npcs, campaign book, command table, rocket
   back to the Tavern, R returns here when in space. Unlocked by the first Astral campaign.
2. Travel cutscenes: Theory portal -> Nexus intro showcase; Tavern launchpad <-> Nexus rocket (Tavern
   launchpad locked until the pack's first campaign is done).
3. Battleship: walkable 3D interior, pilot seat, turrets and other stations; Z toggles walk/seat;
   per-station cameras and crosshairs; server-authoritative flight with the whole party aboard; the
   command table spawns a private ship.
4. Space world: one large streamed space with regions (peaceful, crystal asteroid field, dark
   region), space map on M, unique planet and asteroid textures.
5. Round planets: spherical gravity on foot (extends the Theory's local gravity frames), landing,
   planet biomes and structures, enemies that walk on curved ground.
6. Five Astral campaigns (asteroid-field flight, planet quests, ship breakdown, npc quests) using
   the existing campaign step system plus new step kinds where needed.

## Pass 1 status

Done:
- Creatures: `tools/make_theory_creatures.py` (Codex) writes hull_skitter, void_lamprey,
  gloom_spitter, vent_stalker, crest_brute and void_empress (variants brood/unmade) plus the
  acid_glob and void_spine projectiles. Manifest: `creatures/theory_creatures_manifest.json`.
- `CreatureModel` role `tail_chain` (spring-damper chain; `_animate_tail_chain`), boss style
  `xeno_queen` uses the shared dungeon boss poses.
- `scripts/enemies/theory_enemies.gd` (stats at 6/10), `scripts/enemies/bosses/void_empress.gd`
  (four phases; each one drops an arena ring; tail lash, acid rain, spine ring, lunge, acid
  spiral, brood summons).
- `TheoryWorld.PACKS` places 11 packs (Aurora rear, both wreck decks, arena entrance) and the boss
  site. Spawns keep their deck (`enemy_floor`), the bowl has a real `ground_height`, enemy shots
  in the arena follow the curved floor (`attack.bowl` in EnemyBullets). Abandoned attempts rebuild
  fallen rings. `boss_defeated` is part of the replicated theory state.
- Dungeon rating 6.0, common loot G6 (+2 tier bias). Astral campaign step `convergence` now waits
  for the boss kill, then `beyond` holds the party until pass 2.
- Large map: M (`map` action) opens the minimap large and centred; the Theory still has no planar
  map.
- Fairytale art rework (Codex, `theory_art.gd` and theory shaders).

Not yet (moved to pass 2 or later in pass 1):
- No enemies on the twisting ribbons (ground enemies would fall off rolled frames; needs
  gravity-aware enemy movement, which pass 2 needs for round planets anyway).
- Boss kill is not saved in `run.astral`; resuming a paused run after the kill means fighting her
  again.
- The Convergence exit portal still returns to the realm; pass 2 retargets it to the Nexus.

## Pass 2 status

Built as planned (see `docs/SPACE_HANDOVER.md` for files): the Nexus, travel
cutscenes, the Tavern launchpad, battleships with seats and cameras, the space
world and five Reach tales. Online docking, the launchpad and First Light were
verified end to end.

## Pass 3 - the big Reach rework

From the user's notes after playing pass 2:
- The Reach is a sphere of 42 km (`SpaceLayout.WORLD_RADIUS`). Near its edge the
  ship's charm turns her back (`SpaceShip.step`); a red hex ward shows on the
  sphere close to it, and the star chart draws it as a red circle.
- Planets are 300 to 1300 m worlds with real terrain (`SpaceLayout.surface_height`,
  shared by server and art), streamed in LOD chunks with collision near the crew
  (`PlanetTerrain`), painted by `PlanetPalette`, and covered in the realm's voxel
  obstacles (`PlanetFlora`).
- Air: from space a thin glowing rim and a far gloria; diving in, the planet's day
  sky replaces space and the sun swings to daylight over the landing site
  (`SpaceBackdrop.set_air`). No blanket fog.
- Space is darker and mysterious: depth fog hides far things, drifting dust shows
  speed, the Shardfield's rocks fade in by distance. The Nexus floats on a voxel
  rock with glowing crystals.
- The battleship is a sky-galleon built around its walk-in room; its windows show
  live views of space (`ShipWindowView`), and the pilot can fly from the helm in
  first person (V). C toggles the pulse drive for long trips.
- Ships land anywhere: flying low over a planet sets the ship down on the nearest
  level, clear ground (`PlanetLanding`), X lands too, the pad is used near it.
- Brood ships (`BroodShip`): skiffs make attack runs, void eels circle and lunge,
  carriers launch skiffs. They never enter a planet's air and leave landed ships
  alone.
- The large map (M) fits between the HUD bars and dims the world; in space it is a
  tilted star chart (drag to turn, wheel to zoom).

## Pass 4 - life aboard and in the Reach

- Ship parts (`SpaceShip.PARTS`): engines and hull plating mended outside (airlock or on the ground),
  helm, cannons and heart crystal inside. Hits wear the nearest part; damaged parts slow, weaken or
  jam the ship and smoke or burn (`ShipDamage`). Mending a part restores it and 12% hull.
- Aboard, the HUD bars are the ship's hull and boost; on a spacewalk your health and the jetpack.
  No magic or weapons aboard. A lost ship leaves the crew floating; R only calls Orin's rescue skiff
  for the stranded (15 s); anywhere else in the Reach R does nothing.
- Airlock on the port side, spacewalks with jetpack, X clips a line to the ship (rides along).
- Ship tavern: armchairs (X drink, C cigar), sloshing beer glasses (`ShipTavern`), a beer tap.
  Drinks stack the `drunk` status effect (badge, walking sway, screen swirl).
- Helmet domes in the Reach and the Theory (`SpaceHelmet`), the standard quest marker for marks,
  hit glitches and health bars on brood ships, turret cameras past the barrels.
- The plasma sun (`SpaceLayout.SUN_CENTER`) burns ships that come too close.
- A town on every planet (`SpaceLayout.TOWNS`, `PlanetTown`): townsfolk, a smith (sell items for
  Dots) and a shipwright (a ship for 500 Dots, also at the Nexus table; lent free on a Reach tale).
