# Claude handoff: five realm boss encounters

This is an implementation brief, not a report that these fights already run. Inspect the project before editing. Preserve the current voxel visual language, seeded realm layout, permanent encounter clears and fixed editor-authored home village.

Project: `/home/hugo/Godot/Projects/VoxelRealms`
Source items: `/home/hugo/Documents/Voidrealm_textures/Divine/`
New boss art: `creatures/staging/realm_bosses_01/`

## 1. Current state and required work

Blue Dragon is the only registered, playable boss. Its three combat phases, dragonlings, fireballs, wing-beat shockwaves and enraged model exist. It currently wakes through proximity/an intro; it does NOT have a breakable egg or a true hatch sequence.

The other four bosses are staged artwork only. Their fights, enemy definitions, drops, summons, beam collision, healing, hatch forms and encounter registration are NOT implemented. An art-preview beam or spinning model is not working gameplay.

Read these first:

- `scripts/enemies/enemies.gd`: current Blue Dragon phases, enemy definitions and packs.
- `scripts/enemies/boss.gd`, `boss_def.gd`, `enemy.gd`: lifecycle, phases, summons and attack patterns.
- `scripts/enemies/creature_model.gd`: rig animation, glow and variant swaps.
- `scripts/enemies/enemy_bullets.gd`, `enemy_ripple.gd`: projectile collision and magic shockwaves.
- `scripts/world/stronghold_feature.gd`: five strongholds and their real geometry.
- `scripts/enemies/enemy_director.gd`, `enemy_pack.gd`: spawn clearance, pack ownership and permanent clears.
- `scripts/loot/loot.gd`, `scripts/game/items.gd`, `item.gd`, `scripts/server/game_server.gd`: authoritative rewards and damage rules.
- The staged art README, manifest, rigs, phase-art plan, and `divine_set_assignments.json`.

### Improve the models before wiring them in

Review the existing Blue Dragon and every staged boss in Godot from the actual gameplay camera. Improve their detail, silhouette, materials and articulation. Keep their identities and assigned sets. Do not just enlarge the sculptures or cover everything with bloom.

- **Crystal:** stronger hexagonal facets, chipped edges, internal fracture veins, readable cyan runes, asymmetric ice growth and visibly different plate arrangements. Improve conduit bases and add readable lower attack ports. Make the spinning star silhouette clear from above.
- **Demon:** make the face more threatening: pronounced brow, shaped jaw, irregular teeth, curved horn grooves, split hooves and individual hooked claws. Add layered obsidian armor, damaged rib plates, wing veins, shoulder blades and restrained molten cracks. Keep substantial dark/red surfaces around the emissive heart.
- **Scarab:** distinct chitin segments, layered elytra, convincing six-leg joints, carved pharaoh mask, articulated solar wing blades, gold edging and small pink/white jewel details. The opened-wing and exposed-heart forms must change geometry.
- **Void spirit:** layered torn robes with gaps, bony fingers, etched crown fragments, a genuinely hollow hood, asymmetric hanging cloth and distinct rune tablets. Keep the core/eye readable against the dark body without whitening the whole model.
- **Blue Dragon:** retain its identity and established attacks; refine scales, claws, horns, wing ribs and the hatch transition where useful. Do not replace its existing fight with an unrelated design.

Use native VOX parts with no dimension greater than 256 voxels per part, comparable density to the Blue Dragon, and game-scale footprints that fit the strongholds. Existing boss voxel sizes are 0.04m, except scarab 0.044m; frost conduit 0.032m; shardling 0.03m. These are fitted part frames, not mandatory empty 256³ allocations. Split larger articulated shapes into parts. Preserve separate emissive palettes/meshes. Base and alternate parts sharing a CreatureModel holder MUST have the same frame origin and dimensions. Rebuild editor-visible scenes after changing sources.

### Model inventory: what exists and what must be made

| Encounter | Existing art | Missing art / animation |
|---|---|---|
| Blue Dragon | `creatures/blue_dragon/`, normal and `enraged`; red/gold/purple/pink/cyan/blue dragonlings | Azure egg, crack states, hatch shell fragments and hatch animation |
| Rimeheart Prism | `rimeheart_prism/`: default/sealed, `conduit`, `tempest`; six-shard rig; separate `rimeheart_conduit/` and `rimeheart_shardling/` models | Distinct dormant geode egg and cracks; hatch/plate-opening animation; gameplay beam curtains, attacks and summons |
| Vharok | `vharok_cinder_tyrant/`: default and `infernal`; arms, legs, wings and tail; existing `creatures/ember_mite/` can be reused | Obsidian cocoon and cracks; Cinder Sentinel guard model; final `heart_unbound` form; hatch, charge, slam and death poses |
| Scarab Regent | `aureate_scarab_regent/`: one normal model, six articulated legs and wing plates | Sealed solar egg/reliquary, cracks; `sunwings` and `sunheart` forms; Dawn Scarab minion; solar lens attachments; wing-opening, charge and hatch animation |
| Hollow Crown | `hollow_crown/`: one normal model, separate arms/sleeves and broken halo | Sealed black reliquary, cracks; `fractured_court` and `unbound` forms; Mirror Shade minion; teleport dissolve/reassembly, hatch and death animations |

The crystal's existing **sealed combat form is not its egg**. Create a genuinely different dormant shape. The demon's existing infernal variant does not satisfy the missing final structural transformation. All five hatch shells are missing. New boss-specific projectile sculptures/effects are also missing; generic fireballs/bolts/orbs/shockwaves exist as starting points.

## 2. Shared encounter rules

### Breakable shell -> hatch -> combat -> death

Every stronghold initially contains a dormant, solid-looking seal/egg instead of a visible standing boss. Walking near it does not start combat. Player attacks damage its separate shell health; ordinary enemies cannot open it. Show progressive cracks at 75%, 50% and 25% shell health, light escaping through real gaps and a clear breaking animation.

| Boss | Shell appearance | Shell HP, solo | Hatch time | Boss HP, solo | XP |
|---|---|---:|---:|---:|---:|
| Blue Dragon | Blue-scaled egg with cyan seams | 2,000 | 5.0s | 40,000 | 4,000 |
| Rimeheart Prism | Low, closed six-sided frost geode | 1,500 | 4.5s | 44,000 | 4,500 |
| Vharok | Black cocoon hanging in a cracked red rock cradle | 2,200 | 5.0s | 48,000 | 5,000 |
| Scarab Regent | Closed oval gold/ivory solar reliquary | 1,800 | 4.2s | 42,000 | 4,500 |
| Hollow Crown | Upright black reliquary bound by floating crown pieces | 1,600 | 4.6s | 46,000 | 4,800 |

Shell defense is 0. Shell damage, hatch debris and the hatch burst award no loot, XP or boss-damage contribution. Shell fragments are harmless. The shell is a stage of the encounter, not a defeated boss.

At shell break: stop shell damage, remove its blocking collider safely, begin the boss-bar fill and reveal the boss through an authored animation. Do not overlap a solid egg collider with the player. Have wings/plates unfold, a clear audio cue, a restrained camera shake and a local light pulse. The first damaging attack starts at least one second after the boss becomes combat-ready. No proximity-based premature summon wave.

Boss HP scales once at the end of the hatch, using Blue's existing model: `base_HP * (1 + 0.20 * (N - 1))`, with N at least 1 and counted within the encounter's 45m participation/bar radius. Freeze that HP for the attempt; late arrivals never heal or rescale it. Shell HP can use the same multiplier with N captured at its first hit. Scale new objective/guard HP by `1 + 0.35 * (N - 1)`; do not increase projectile density per player. Preserve Blue's existing dragonling values initially.

### Space, targeting and persistence

Use the existing strongholds: Azure Crucible/Bluelay, Crown of the Rime/Fosen, Cinder Bastion/DOOM, Court of the Sun/DESERT and Hollow Throne/DEEP_DARK. There is one encounter at each, generated with the realm. Never scatter boss packs through ordinary biome spawns.

The raised patterned square is exactly 16x16m. The surrounding approach is flattened out to roughly +/-14m and blends outward to +/-20m. Use the flat apron for larger dodges, but keep targets/objectives reachable from the raised arena. Do not invent a 40m arena or permanent arena wall that traps the player. Keep the four non-Blue bosses' centers within about 5m of the stronghold center, except the crystal, which stays centered. Ground hazards cannot fill every escape route. Preserve a roughly 1.5m usable dodge lane after accounting for the player's radius and the projectile's radius.

All projectile emitters, summon positions, teleports and charge endpoints must use actual ground and collision queries. Never spawn inside ruins, pillars, houses, another boss, or the player. Static crystal towers must occupy their planned hex positions; do not let a generic spawn search silently turn the hexagon into random points. Validate/reserve all six sockets before starting the phase. If a required objective cannot spawn, retry or fail open safely rather than leave an unwinnable shield/health gate.

Floating bosses must be hittable by the current Archer's shots at ground+1m. Use a clearly visible grounded energy anchor/column or appropriate readable hit proxy; do not create an untargetable aerial fight. Glowing projectiles should have a visible solid damage core, and the collision radius must match it; outer bloom and sparks are decorative.

A defeated encounter stays defeated for that realm, including leaving/re-entering and normal save restoration. Hatch transitions must not call the final boss loot/pack-clear path. Keep one stable encounter/pack identity across shell, hatch, boss, summons and death. If swapping actors, add the replacement atomically and suppress shell rewards/clear notifications. Summoned minions cannot become permanent independent realm packs.

For a wipe/abandon: after 15 seconds with no living player within 28m, cancel the attempt, clear its attacks/summons/effects, restore a fresh shell and reset contribution/phase state. This is a retry of an undefeated encounter, not a respawn after a kill. Unloading must preserve either a coherent attempt state or reset an unfinished attempt cleanly; never duplicate an encounter or restore a killed boss.

### Damage, fairness and effects

All damage values below are **raw, before defense/shield**. Current defense uses `max(raw * 0.15, raw - defense)`. For example, 75 raw against 35 defense deals 40 HP without shielding. Test with actual high-level gear. Do not force every high-level character to lose exactly 40 HP regardless of defense.

Use normal mitigation for the listed primary attacks. Emissive/elemental visuals do not automatically mean the engine's `magic=true` damage flag: the current shield blocks magic completely. Only the explicitly marked magic shockwaves below should deliberately use that behavior. Armor piercing is not required for these fights. Existing warp-ring clashes and shield interactions should remain useful.

Heavy attacks need 0.8-1.4s telegraphs. Aimed shots snapshot the target near the end of windup and then travel predictably; they do not keep turning into unavoidable homing projectiles. Beams/hazards use explicit per-player hit cooldowns, never damage every frame. One overlapping attack instance cannot shotgun the player several times through adjacent segments. Status stuns/roots are not needed; avoid freezing player controls.

Use rich voxel projectiles: shaped ice shards, broken obsidian, churning fire cores, gold needle blades, orbiting solar discs, violet torn-rune bolts, voxel trails and impact fragments. Use cast silhouettes, ground warnings and sound as well as color. Telegraphs are visually distinct from active damage. Boss cores and a few large effects can cast dynamic local light; most projectiles use emission and pooled unshadowed effects rather than one shadowed light per bullet. Keep floor, player and safe lanes readable. Death/hatch flashes must decay quickly and never become full-screen whiteouts.

Phase changes are monotonic and execute once. Cap a threshold-crossing hit at the next mandatory boundary where required; do not allow one huge hit to skip a summon objective. Healing must never return a boss to an earlier phase. Cancel old scheduled volleys and retire phase-owned hazards clearly before a new incompatible attack starts. At final death, disable every encounter-owned damage source BEFORE the visual death sequence; award rewards exactly once afterward.

## 3. Blue Dragon — Azure Crucible, Bluelay

Use the existing fight as the mechanical reference. Add the egg/hatch entry and improve transitions/readability. Keep the current combat attacks and loot unless resolving the lifecycle bugs described later.

### Dormant and hatch

The azure egg sits in the stronghold center. Each crack reveals brighter cyan veins. On break, four shell plates lift, crumble outward, the dragon uncurls, braces its forelegs and unfolds both wings. No shell explosion damage. Fill the health bar during the 5s intro, then wait the shared one-second safety window before damaging attacks.

### Phase 1: Five-Colored Brood — 100% to 70%

Boss defense 20. Boss stays centered. Spawn exactly five guards once: red, gold, purple, pink and cyan dragonlings, around radius 9m, using the flat apron. Each has 3,000 HP, 10 defense, move speed 5.5, keep-distance 7m, and a colored 32-40 raw fireball: speed 11m/s, range 16m, 1.1s cooldown, 0.2s windup. Their existing behavior is skirmish.

The boss is shielded until all five die. In the current code he has no offensive attack during this first guarded section; preserve that breathing room. Display five colored guard pips on the boss bar. Never respawn a killed guard in that phase.

After the guards die, visibly collapse the shield. He uses his existing heavy fire burst: six aimed fireballs, 0.14s apart, 70-85 raw each, speed 6.5m/s, range 22m, 0.4s windup, 2.6s cooldown, wing-flap animation. Give the large slow cores bright cyan fronts and cooling blue trails; use the existing attack logic rather than silently changing its timing. Remain in this phase until 70% boss HP.

### Phase 2: Blue Orbit — 70% to 30%

Boss defense 25. Spawn exactly four blue dragonlings once, orbit radius 8m. Each has 2,400 HP, 10 defense, orbit speed 0.8rad/s and the same 32-40 fireball attack. The boss is shielded until these four die.

While shielded, the dragon fires its existing three-shot 12-degree spread: 28-34 raw, speed 11m/s, range 18m, cooldown 1.1s, windup 0.2s. Do not also enable his large six-shot burst during this guarded subsection.

After the fourth blue guard dies, the shield disappears and the boss strafes at 4.5m/s using the heavy six-fireball burst from phase 1. Constrain this movement to the usable stronghold area. No further summon waves. Transition at 30%.

### Phase 3: Azure Rupture — 30% to death

Use existing `enraged` geometry. Boss becomes stationary and defense falls to 5. Preserve the existing repeating sequence:

1. Wing-beat magic shockwave: 60-75 raw, radius 16m, speed 9m/s, knockback multiplier 1.3; then 2.0s.
2. A second wing-beat shockwave; then 1.2s.
3. Sweep of 34 blue fireballs over 120 degrees, one every 0.05s: 60-70 raw, speed 9.5m/s, range 24m; then 2.2s as currently scheduled.
4. Another wing-beat shockwave; then 2.5s before looping.

The existing shockwaves are magic and are deliberately shield-blockable/clashable. Fireball cores remain normally mitigated. Check the scheduler's actual volley duration so effects and the next attack do not overlap unintentionally. No new dragonlings in this phase. At death, retain the glow/voxel burst but clear attacks first and avoid cleanup kills paying extra rewards.

## 4. Rimeheart Prism — Crown of the Rime, Fosen

Identity: a living ice geode becoming an exposed six-point storm engine. Boss HP 44,000; XP 4,500. It remains centered so its six-tower geometry is stable.

### Dormant and hatch

The egg is a squat, closed hexagonal geode, frosted stone outside, tiny cyan seams inside. At break, the outer rock splits into six heavy wedges; the inner prism rises on a visible light column. Individual ice plates lift into the existing sealed combat arrangement over 4.5s. Use ice grinding, prismatic highlights and falling harmless chips.

### Phase 1: Sealed Heart — 100% to 70%

Use default/sealed model. Defense 24. Gentle hover and slow plate movement; no walking or teleports. No minions or towers yet.

Repeat this approximately 12s attack cycle:

- At 0s, show a 0.8s core pulse, then fire a fan of five faceted shards at -24/-12/0/12/24 degrees around the snapshotted aim: 55-65 raw, speed 8m/s, radius about 0.16m, range 18m.
- At 3s, repeat that fan from the alternate visible emitter. It is a new aim snapshot, not homing.
- At 6s, warn for 1.0s and release a radial shard ring: start with 18 evenly spaced directions and omit the directions inside two opposite 40-degree safe sectors. Rotate the sector orientation between cycles. Bolts deal 60-70 raw at 6m/s. Draw the two gaps before release.
- At 8.5s, mark three separate circles near recent player positions, radius 0.9m. After 1.2s, ice spears erupt once for 75-85 raw and shatter. Positions stop following the player as soon as marked. No lingering damaging spikes.
- Finish with roughly 1.5s of quiet recovery. The arena floor remains readable throughout.

At 70%, stop/cap the threshold-crossing hit, cancel pending phase-1 eruptions and enter the conduit transformation exactly once.

### Phase 2: Hexagonal Conduit — enter at 70%, gated until all six towers die and HP reaches 35%

Switch to the existing `conduit` form. Plates spread to reveal the glowing heart and hexagonal rings. Reserve six tower positions at radius 6.2m, 60 degrees apart, all at local stronghold ground height. Use the existing `rimeheart_conduit` art. Each tower: 1,200 base HP, defense 10, stationary, no contact damage and no loot/XP.

Upper beams connect neighboring towers and each tower to the visible heart. Each living tower heals **0.15% of scaled boss maximum HP per second**; six heal 0.9% total. Healing is proportional to elapsed time, stops immediately on tower death, and is capped at the phase-entry 70% HP. The boss remains damageable while towers heal it. Do NOT make him completely immune while also promising a healing mechanic.

Boss defense is `14 + 2 * living_towers`: 26 initially, down to 14 with none. While any tower lives, boss HP cannot fall below 35%. Damage that would cross this floor is capped; show “Break the conduits” and count only actual HP lost toward loot contribution. The player must destroy all six towers to unlock the final phase. No destroyed tower ever respawns in this attempt.

Tower beam attacks: upper links are non-damaging while charging. Every 6s, alternate the three even and three odd neighbor edges. Give selected edges 0.8s of floor warning, then form visible energy curtains from floor to the upper link for 2.0s, followed by 3.2s rest. Curtains deal 55-65 raw, at most once per player per 0.7s across this curtain system. At least three edges are open. A link dies instantly when either endpoint tower is destroyed. Spokes to the boss are healing visuals only, not invisible player damage.

The boss itself fires a modest three-shard aimed fan every 3s: 45-55 raw, speed 7m/s, 0.7s windup. Do not add the phase-1 ring or spear eruptions on top of the curtain puzzle.

Hostile summons: two existing-art `rimeheart_shardling` minions appear once the towers are fully established. Then spawn two every 8s while towers remain, maximum six alive. Each: 500 base HP, defense 5, move speed 3m/s, short dart followed by a recovery; one 35-45 raw ice bolt every 2.5s. Spawn on valid outer-apron points with a 0.8s icy arrival tell, never on the player or safe crossing. These minions do not heal, grant immunity, count as tower objectives, or award drops/XP.

On the final tower's destruction: stop healing/curtains/summon timer, dissolve remaining shardlings harmlessly, stun the boss for 3s with defense 4 and a collapsing blue hexagon. If HP is already 35%, enter phase 3 after that recovery. If above 35%, stay in a post-conduit phase-2 subsection at defense 14, with the modest aimed fan only, until 35%. No tower resummon. Display six objective pips throughout this stage.

### Phase 3: Rime Tempest — 35% to death

Switch to existing `tempest` geometry: six long radial blades, exposed core and larger rings. Defense 8. Use a 1.2s plate-opening warning, then rotate the visual assembly at roughly 8rad/s. The collision target stays stable; spinning mesh blades are not automatic contact damage.

Repeat a 10s cycle:

- 0-0.8s: core charge and clear spiral direction cue.
- 0.8-4.8s: emit two opposite shard streams, one pair every 0.25s. Projectile directions rotate slowly at 0.55rad/s, independently of the much faster visual mesh spin. Bolts: 60-75 raw, speed 6m/s, radius 0.15m, range 18m. Reverse stream direction next cycle; preserve wide weaveable gaps.
- 6s: warn 0.9s, then send three heavier pointed comets in a broad 20-degree fan: 75-90 raw, speed 7.5m/s, radius 0.25m.
- 8-10s: recovery, no new projectiles; outer shards brighten/fade rather than flooding the floor with white bloom.

No towers, heals or minions in phase 3. On death, stop the spin, contract the core, let plates hang for a moment, then shatter outward into harmless cyan-lit voxels.

## 5. Vharok, the Cinder Tyrant — Cinder Bastion, lava/DOOM

Identity: a black-armored red demon that shifts from heavy deliberate attacks to a broken-heart aerial assault. Boss HP 48,000; XP 5,000.

### Dormant and hatch

A dark cocoon sits within a fractured red volcanic cradle. Cracks reveal a pulsing heart glow, followed by horns pushing through. On break, the demon tears the shell apart with his claws, unfolds charred wings, lands and roars. Use a short local heat shimmer and falling embers, not a damaging eruption during the 5s hatch.

### Phase 1: Obsidian Warden — 100% to 65%

Use default model, defense 24. Walk deliberately at 1.6m/s, keeping his center within 4.5m of the stronghold center. Face the target during windup; do not snap-turn a cleave through a successful dodge. No summons.

Repeat a 12s cycle:

- 0s: horns glow for 0.8s; launch five ember-core fireballs in a wide fan, 70-85 raw, speed 8m/s, radius 0.22m, range 19m.
- 4s: raise one arm for 1.0s, show a 60-degree forward cleave wedge, then send two visible crescent/slab projectiles through that wedge. Each deals 90-105 raw, speed 6m/s, radius around 0.3m. One cleave instance may hit a player once, not once per crescent segment.
- 7s: mark three circles at snapshotted nearby player/ground positions, radius 1.1m. After 1.2s, brands erupt for 75-90 raw and leave glowing patches for 3s. Patches deal 20-25 raw per 0.75s; do not stack patch ticks. Never occupy the whole safe approach; cap active patches at four.
- 10-12s: guarded recovery with dimming cracks and audible breathing.

At 65%, his chest armor splits and the existing `infernal` fissures appear.

### Phase 2: The Furnace Pact — 65% to 30%

Use `infernal`. Spawn exactly two **Cinder Sentinels**, one at each of two reserved side sockets around x +/-5m. New model required: compact obsidian guardians with molten shoulder seals, visually distinct from ordinary Basalt Bulwarks. Each: 2,000 base HP, defense 14; primarily stationary, one three-shot ember fan every 2.8s, 45-60 raw, speed 7m/s, 0.8s windup. Offset their clocks by 1.4s.

The two Sentinels alone maintain a visible red shield on the demon. Display two objective pips. The boss is immune during this subsection; unlike the frost crystal, there is NO healing here. Killing unrelated mites must not affect the shield. Sentinels never respawn in this phase.

While guarded, the boss uses only branded ground circles: two circles every 4s, 1.2s warning, 70-85 raw eruption, no persistent fire pool. Do not add his heavy cleave or large fans during this guard puzzle.

Summon two existing-art Ember Mites every 10s during the guarded subsection, maximum four alive, and at most eight mites spawned in that subsection. Each: 300 base HP, defense 3, chase speed 3.5m/s; a clearly wound-up short-range bite/ember spit for 35-45 raw every 2s. They do not shield, heal, explode on death, or drop rewards.

After both Sentinels die: red chains snap, mites dissolve harmlessly, summon timers stop and the boss kneels for 2.5s at defense 4. Then defense becomes 14 and he uses a charge subsection until 30% HP:

- Draw a broad straight charge lane for 0.9s, lock its direction, then move at 8m/s for at most 8m to a valid endpoint. Charge hit: 85-100 raw, once per player, limited knockback that does not intentionally throw players into unavoidable lava.
- Cinders behind the charge are decorative unless a separate floor telegraph makes an actual hazard explicit.
- After stopping, pulse the heart and fire a three-shot fan for 70-85 raw at 8m/s; then recover for 2s before lining up the next charge.

No more Sentinels or mites after the shield breaks. Do not require killing mites to damage the boss.

### Phase 3: Heart Unbound — 30% to death

Create `heart_unbound`: broken chest plates, brighter exposed heart, damaged wing edge and one chipped horn. Keep dark areas and visible anatomy. Defense 8. No new minions. Body remains targetable during brief hover animations.

Repeat a 14s cycle:

- 0s: lift slightly and mark a 2.2m landing circle for 1.4s. Slam at its locked location for 95-110 raw inside the circle. Send a separate outward magic shockwave for 55-65 raw, radius 12m, speed 6m/s; the shield can block this ring. Prevent the same slam/ring combo hitting one player twice immediately.
- 4s and 6s: send seven-fireball fans, 50-65 raw, speed 7m/s, broad spacing. Animate wing beats and a yellow-white heart pulse before each fan.
- 9s: warn two crossing molten floor lanes, each about 0.8m wide and 12m long, for 1.2s. They activate for 1.5s, 80-95 raw, one shared hit per player per 0.8s. Leave four clear corner escape sectors; no extra aimed heavy volley during the cross.
- 11.7-14s: recovery. Let old fireballs expire before the next slam telegraph becomes active.

No permanent lava conversion on the stronghold floor. Death: wings fold, knees buckle, the heart contracts, then a red/gold burst of harmless obsidian fragments. Clear every brand, lane and projectile first.

## 6. Aureate Scarab Regent — Court of the Sun, Desert

Identity: a gilded six-legged pharaoh scarab, becoming a rotating solar weapon before exposing a fragile pink/white heart. Boss HP 42,000; XP 4,500. Holy Divine set: gold, ivory, pink and white.

### Dormant and hatch

Start as a closed oval solar reliquary, not a visible beetle. A thin pink slit pulses beneath gold plates. Breaking it opens the shell in opposing engraved segments; six legs unfold, the mask rises and a small sun ignites inside the halo. Give the 4.2s hatch an architectural/mechanical sound and a low sand gust. Sand dust never hides the floor.

### Phase 1: The Gilded March — 100% to 70%

Use existing normal model. Defense 28. Follow a slow clockwise path around a 3m radius at about 2m/s; avoid side-stepping instantly with each arrow. No summons.

Repeat a 12s cycle:

- 0s and 3s: mask eyes brighten for 0.8s, then fire seven gold needle blades in a broad fan, 10 degrees apart: 55-70 raw, speed 10m/s, radius 0.13m, range 18m. Aim is locked before release.
- 6s: halo charges for 1s, then throws one visibly spinning solar disc: 75-90 raw, speed 5.5m/s, radius 0.35m. It travels 7m on a fixed outward line and returns toward its original launch point, not toward the player's new position. A visible trailing path forecasts the return. It cannot hit the same player more than once on either leg, with at least 0.6s between outward/return hits.
- 9-12s: finish the return, settle the wings and recover. No hidden contact damage from the decorative halo.

### Phase 2: Wings of Noon — 70% to 35%

Create `sunwings`: open elytra, spread layered solar wings and four visible lens attachments. Defense 20. Move to the center; hover visuals are modest and the lower target remains readable.

Spawn exactly six **Dawn Scarabs** once on valid outer points. New models required: small ivory/gold beetles with pink eye dots, not scaled copies of the boss. Each: 700 base HP, defense 8, move speed 2.5m/s, one 40-50 raw needle every 2.4s after a 0.6s windup. Stagger clocks. They do NOT shield or heal the Regent, are not mandatory objectives, and never respawn. Killing them simply makes the fight safer. No additional summon timer.

Repeat a 14s cycle:

- 0s: show two opposite beam lanes for 1.1s. The wing lenses then emit two opposite 0.55m-wide solar rays for 3s. Sweep their shared axis through only 45 degrees, about 15 degrees/s. Rays deal 70-85 raw at most once per player per 0.75s across the beam system. Light the floor clearly along active rays and show the direction of rotation. Two broad perpendicular sectors remain open.
- During the active rays, the boss fires no additional aimed attack. Scarab minions may keep their staggered needles.
- 4.1-7s: rays switch off and lenses cool; recovery.
- 7s: five-shot aimed gold fan, 60-75 raw, speed 8m/s, 0.8s windup.
- 9s: mark three sand-spear circles, radius 0.8m, for 1.2s. Spears erupt once for 75-90 raw and crumble immediately.
- 11-14s: recovery with no new heavy attack.

The four lenses are attachments, not four more killable towers. The boss is damageable throughout this phase. At 35%, remove remaining Dawn Scarabs with a harmless retreat/fade and stop their attacks before the final transformation.

### Phase 3: Exposed Sunheart — 35% to death

Create `sunheart`: cracked/open breast shell, a strongly defined pink/white heart, damaged solar wing tips and a less complete halo. Defense 15 normally, 6 during the exposed recovery after a charge. No summons, healing or immunity.

Repeat a 14s cycle:

- 0s: telegraph a charge lane for 1s. Dash up to 8m at 9m/s, toward a locked valid endpoint, dealing 90-105 raw once if crossed. Direction never follows the player after launch.
- After stopping: plant the legs, open the shell and expose the heart for 2.5s at defense 6. This is the clear damage window; do not also fire a beam during it.
- Around 4.5s: warn 0.9s and release a gold projectile ring, initially 18 directions with two opposite 60-degree safe sectors removed. Bolts: 65-80 raw, speed 6m/s. Show the gaps before the ring fires.
- 6.5s: mark four comet circles, radius 1.1m, with at least 1.2s warning for each. Land the comets at 0.5s intervals, 80-95 raw each; never place all four on the same spot or keep following a moving player.
- 9.5s: telegraph a second charge on a different line, using the same rules, followed by another heart exposure. Space the comet sequence so its final hit is finished before the second charge becomes active.
- Finish the cycle with the last exposed recovery; no rays from phase 2.

Death: solar halo splinters, the pink heart emits a brief white/gold pulse, then the boss collapses into harmless gold, ivory and sand voxels. The screen stays readable.

## 7. The Hollow Crown — Hollow Throne, Deep Dark

Identity: a floating crowned void spirit that moves from deliberate cursed volleys to readable teleport tricks, then breaks apart into a stationary unraveling core. Boss HP 46,000; XP 4,800. Void set: dark violet/black, magenta, small cyan highlights.

### Dormant and hatch

The dormant shape is a closed black reliquary bound by crown fragments, with no exposed spirit or obvious face. Breaking its seals makes the fragments lift into a crown; the black shell separates into hanging robe strips and the hollow hood opens around a magenta eye. Over 4.6s, use a low spatial ripple and voxel reassembly rather than a simple instantaneous actor swap.

### Phase 1: The Veiled Monarch — 100% to 72%

Use existing normal art. Defense 18. Drift at about 1.7m/s within radius 4.5m. No teleports or summons yet.

Repeat a 14s cycle:

- 0s: hands draw a visible rune for 0.8s, then fire three pairs of twisted rune bolts, pairs 0.12s apart: 60-75 raw, speed 7.5m/s, radius 0.16m. Curved visual trails are decorative; flight paths remain predictable.
- 3.5s: both hands wind up for 0.8s, then each emits four broadly spaced bolts, 55-70 raw at 7m/s. Do not overlap both fans into a point-blank unavoidable shotgun.
- 6.5s: charge for 1s, then fire one slow black-sun orb: 75-90 raw, speed 3.5m/s, radius 0.45m, range 10m. At its terminal point it visibly contracts for 0.4s before releasing eight outward needles, 45-55 raw at 6m/s. Needles cannot immediately hit the player already struck by the orb; preserve a 0.5s skip window/shared attack identity.
- Recover while the orb resolves. Do not start the next cycle's large attack until its dangerous children have cleared nearby players.

### Phase 2: Court of Echoes — 72% to 35%

Create `fractured_court`: split crown, displaced halo tablets, open robe seams and a stronger eye. Defense 16. Spawn exactly three **Mirror Shades** once. New models required: smaller incomplete spirits with broken half-crowns and dimmer cores; distinct from the real boss and from ordinary realm spirits. Each: 1,000 base HP, defense 8, primarily stationary around radius 5m; two 40-55 raw bolts every 2.8s at 6.5m/s, clocks staggered about 0.8s. They do not shield/heal the boss, are not mandatory objectives, and do not respawn.

Teleport behavior must look intentional:

- Mark the destination with a visible floor sigil at least 0.85s before arrival.
- Dissolve the departing model into voxel ribbons over 0.35s; use a short explicit non-damageable transit window no longer than 0.6s.
- Reassemble the full body over 0.5s. No attack for at least 0.6s after reassembly.
- Valid destinations remain within 5.5m of the stronghold center, at least 2.5m from a player, outside colliders/objectives. Maximum single travel is about 8m. If no safe destination exists, remain in place and show the failed cast; never appear inside a player or wall.
- Afterimages are dim, translucent visual effects, not solid fake damage targets. Update collision and rendering together, not one frame apart with a full solid model left behind.

Repeat an approximately 14s sequence: teleport at the start; an aimed three-shot fan after reassembly (60-75 raw, speed 7.5m/s); at 4s warn two 0.6m-wide, 8m-long void seams for 0.9s, then activate for 1.5s (60-70 raw per 0.75s, shared hit cooldown). Teleport again around 7s; after reassembly use the slow orb from phase 1; then recover while it resolves. Reuse a small set of visibly distinct safe destination sockets instead of random unreachable spots.

At 35%, remaining Mirror Shades dissipate harmlessly. Cancel teleport schedules and seams before the last transformation.

### Phase 3: Crown Unbound — 35% to death

Create `unbound`: detached crown sections, a larger exposed core, torn-open robe panels and stretched hand runes. The crown pieces orbit as non-damaging attachments, not new enemies. Boss becomes centered and stationary, defense 6, and remains vulnerable. No more teleports or summons.

Repeat an 18s sequence:

- 0-0.9s: two rune arms charge; show the spiral direction.
- 0.9-4.9s: two opposite spiral streams, one pair every 0.3s, direction rotates at about 0.45rad/s. Bolts: 65-80 raw, speed 6m/s, radius 0.16m, range 18m. Use magenta cores with small cyan tips. Reverse spiral direction next cycle.
- 5.5s: one clearly cyan magic null-ring, 55-65 raw, radius 12m, speed 5m/s; deliberately shield-blockable/clashable. This is visually and mechanically distinct from the normal rune bolts.
- By about 8s, preceding spiral shots and ring have left the central dodging area. At 9s, telegraph a hollow cross for 1.1s: two 0.8m-wide crossing lanes, then 1.4s active for 80-95 raw with a shared 0.8s hit cooldown. Four safe quadrants remain open. No new spiral during the cross.
- 12.3s: mark three crown-collapse circles, radius 1.25m, for 1.2s; each detonates once for 90-105 raw. Positions lock on warning.
- 14-18s: vulnerable recovery. Let lights contract to the eye instead of blacking out the whole arena.

Death: crown motion stops, all attacks become harmless, the eye contracts to a point and the cloak peels into violet voxel ribbons; finish with a brief magenta/cyan burst. Avoid a prolonged black screen or a damaging death nova.

## 8. Loot: exact assignments and roll rules

### Current versus proposed

Only The_Blue currently drops. The four other sets are RESERVED ART, currently 0% live. The tables below are the requested target design for implementation. Keep source notes honest during integration: only mark a set LIVE once its definitions, importer, encounter and reward path actually work.

Every listed divine item gets an independent 3.00% roll per eligible player per boss kill. Rolls are not divided across the set, not class-filtered and not mutually exclusive. Multiple divine items can drop in one kill. Divine items go in personal WHITE bags and are soulbound. Preserve splitting if more items roll than one bag can contain.

Eligibility target: at least 4% of that attempt's scaled maximum boss HP dealt as actual boss HP damage. Shell, decoy, tower and minion damage do not count. Immune/capped damage does not count. Divine rolls remain 3% for every eligible player, including non-top contributors.

IMPORTANT CURRENT CODE MISMATCH: `Loot.roll()` checks `def.hp * loot_threshold`, which is BASE HP, while boss combat HP is scaled separately in `Boss.max_hp`. Existing source notes describe maximum-HP eligibility, but this implementation does not use runtime scaled HP. Pass an explicit encounter/scaled maximum to the authoritative loot calculation and reconcile this correctly; do not mutate a shared EnemyDef resource to hack around it.

### Divine items, 3.00% EACH

**Blue Dragon — The_Blue — 5 items; live now.**

| Source item | Rate |
|---|---:|
| `D_cloak_theblue.pxo` | 3.00% |
| `D_robe_oftheblue.pxo` | 3.00% |
| `D_spell_oftheblue.pxo` | 3.00% |
| `D_trident_oftheblue.pxo` | 3.00% |
| `crucefix of the blue.pxo` | 3.00% |

The last source maps to runtime ID `D_bonus_crucifix_oftheblue`. Chance of at least one Blue divine item: `1 - 0.97^5 = 14.13%` per eligible kill.

**Rimeheart Prism — Frost — 11 items; proposed, not live.**

| Source item | Rate |
|---|---:|
| `D_bow_offrost.pxo` | 3.00% |
| `D_wand_offrost.pxo` | 3.00% |
| `D_trident_offrost.pxo` | 3.00% |
| `D_spell_offrost.pxo` | 3.00% |
| `D_cloak_offrost.pxo` | 3.00% |
| `D_robe_offrost.pxo` | 3.00% |
| `D_bonus_crucifix_offrost.pxo` | 3.00% |
| `D_bonus_flame_offrost.pxo` | 3.00% |
| `D_bonus_eye_offrost.pxo` | 3.00% |
| `D_bonus_crystal_offrost.pxo` | 3.00% |
| `D_bonus_talisman_offrost.pxo` | 3.00% |

Chance of at least one Frost divine item: `1 - 0.97^11 = 28.47%`. This higher whole-set chance follows from having more independent items; do not quietly normalize it back to 3% total.

**Vharok — Satan — 3 items; proposed, not live.**

| Source item | Rate |
|---|---:|
| `D_trident_ofsatan.pxo` | 3.00% |
| `D_wand_thewandofsatan.pxo` | 3.00% |
| `croucefix of satan.pxo` | 3.00% |

Use a documented runtime alias such as `D_bonus_crucifix_ofsatan` for the legacy crucifix filename. Whole-set chance: `1 - 0.97^3 = 8.73%`.

**Scarab Regent — Holy_Divine — 4 items; proposed, not live.**

| Source item | Rate |
|---|---:|
| `D_spell_ofthedivine.pxo` | 3.00% |
| `D_trident_ofthedivine.pxo` | 3.00% |
| `D_wand_thewandofthedivine.pxo` | 3.00% |
| `flame of the divine.pxo` | 3.00% |

Use a documented alias such as `D_bonus_flame_ofthedivine` for the legacy flame filename. Whole-set chance: `1 - 0.97^4 = 11.47%`.

**Hollow Crown — Void — 5 items; proposed, not live.**

| Source item | Rate |
|---|---:|
| `D_bow_Darkmatter.pxo` | 3.00% |
| `D_cloak_thevoid.pxo` | 3.00% |
| `D_robe_ofthegalaxy.pxo` | 3.00% |
| `D_trident_ofthevoid.pxo` | 3.00% |
| `D_wand_thewandofdarkness.pxo` | 3.00% |

Whole-set chance: `1 - 0.97^5 = 14.13%`.

Do not fabricate missing armor/bows for Satan or Holy Divine or claim they already exist. Their incomplete sets are intentional. Import/register the actual existing source items with appropriate stats/behaviors; preserve the current class restrictions: Archer uses bows, cloaks, spells and bonus items. Wands, tridents and robes can drop/be collected but cannot be equipped by Archer. Other classes are a separate pass.

### Non-divine boss loot

All entries below are separate rolls, not an exclusive weighted choice. Quantities are one unless a gear pool selects an item. Public means rolled once per encounter kill; personal means rolled for each eligible player.

| Reward | Blue Dragon, CURRENT | Each of the four new bosses, PROPOSED | Bag / ownership |
|---|---:|---:|---|
| HP elixir | 100% | 100% | Gray, public |
| MP elixir | 100% | 100% | Gray, public |
| One random G4 item | 0% | 30% | Green, public |
| One random G5 item | 0% | 15% | Red, personal |
| One random G6 item | 50% | 50% | Purple, personal |
| Backpack | 0% | 5% | Green, public |
| G7 or G8 gear | 0% | 0% | Never in realm |

For personal NON-divine rewards, preserve the existing 90% multiplier for eligible players who are not the top contributor. Thus G5 is 15% / 13.5%, and G6 is 50% / 45%, for top-or-solo / other eligible players. Public rolls and divine rolls do not receive this reduction.

Normal gear pools remain uniform over the catalog's matching tier and weapon/armor/spell/bonus slots. Currently G4/G5 each have 11 options: bow, wand, trident, cloak, robe, spell and five bonus families. G6 has 10 because no G6 spell exists. At these counts: a particular G4 item is 30%/11 = 2.7273% per public kill; a particular G5 item is 15%/11 = 1.3636% for top/solo or 1.2273% for others; a particular G6 item is 50%/10 = 5% top/solo or 4.5% others. Blue's individual G6 items use the same 5%/4.5%. If the catalog changes, recalculate and update the notes rather than claiming these denominators remain fixed.

### Permanent-stat potions

Each cell is an independent chance for one potion, BLUE personal bag. The table shows top/solo rates; other eligible players get 90% of these rates. These are permanent stat elixirs, not the ordinary HP/MP refill elixirs above.

| Potion | Blue CURRENT | Frost PROPOSED | Lava PROPOSED | Desert PROPOSED | Dark PROPOSED |
|---|---:|---:|---:|---:|---:|
| Attack | 50% | 15% | 75% | 15% | 15% |
| Defense | 50% | 15% | 75% | 75% | 15% |
| Speed | 50% | 15% | 15% | 25% | 50% |
| Dexterity | 50% | 75% | 15% | 15% | 15% |
| Magic | 50% | 75% | 15% | 15% | 25% |
| Maximum HP | 50% | 15% | 15% | 35% | 15% |
| Maximum MP | 50% | 15% | 15% | 15% | 75% |

Exact reduced rates: 75 -> 67.5%; 50 -> 45%; 35 -> 31.5%; 25 -> 22.5%; 15 -> 13.5%. Use actual IDs `elixir_of_attack`, `elixir_of_defense`, `elixir_of_speed`, `elixir_of_dexterity`, `elixir_of_magic`, `elixir_of_hp`, `elixir_of_mp`. Fosen emphasizes Magic/Dexterity; lava Attack/Defense, matching current biome rules. These proposed boss tables do not change existing ordinary-god potion tables.

### Summon, shell and objective loot

All NEW boss-only minions, Sentinels, conduits, shades, hatch shells, decoys and temporary attachments: 0% divine, 0% tiered gear, 0% consumables, 0 XP. Their purpose is the encounter, not an infinite farming loop.

Blue Dragon's CURRENT dragonlings each have HP elixir 40%, MP elixir 40%, XP 120; no divine or tiered drops. Preserve real player-earned dragonling rewards, but cleaning up leftover actors during a transition, wipe or boss death must not count as a rewarded kill. Do not call ordinary `_die()`/reward paths to silently despawn support actors.

Unassigned sets remain unassigned: Ash, Blood, Cindrella, Dragon_Fire, Eclipse, Fallenwood, Goldslinger, Madness, Silver, Spirit, Storm and Venom. Do not make any of them fall from regular realm enemies. Update `/home/hugo/Documents/Voidrealm_textures/DIVINE_SET_USAGE.txt` and each set's `USAGE_AND_DROPS.txt` after implementation, including live status, exact aliases and actual rates.

## 9. Required implementation changes and acceptance checks

Extend the current systems coherently rather than pretending dictionaries already implement every new mechanic:

1. Add dormant-shell/hatch states and separate shell health. Existing `wake_on` and generic intro alone do not provide this.
2. Add explicit encounter-owned registries for objective summons versus hostile adds, hazards and timers. The current single `_summons` list is insufficient for e.g. towers gating a phase while shardlings do not. Clearing the list must not orphan living actors. Clean every actor on wipe/death/unload.
3. Add the crystal's timed healing, monotonic phase/HP gate and fixed socket placement. Existing `shielded=true` is not a substitute.
4. Implement physical charge/landing telegraphs, finite ground hazards, explicit beam collision/ticks, return discs and safe teleport choreography. Current basic bullet styles fly straight; calling an attack `beam`, `boomerang` or `teleport` in a Dictionary does not implement it.
5. Keep authoritative HP, healing, eligibility and loot at the existing server/encounter boundary. In the current local game the client detects projectile hits; do not claim this is an existing network-authoritative multiplayer projectile system. Make repeated callbacks idempotent and leave a clean route to replication.
6. Fix scaled-HP loot eligibility and preserve all independent rolls. Import/register the four reserved sets. `tools/import_textures.py` currently skips non-Blue divine sets; `Items.divine()` currently filters to Blue IDs; `Loot._allowed()` currently accepts divine only from Blue Dragon. Update ALL three through an explicit boss-to-set allowlist; do not globally allow every divine item from any boss or god.
7. Preserve G7/G8's realm ban and current Archer equip restrictions. Keep each bag color separate, personal ownership intact and inventory-overflow bag splitting functional.
8. Add stronghold pack assignments for the four new encounters, with permanent no-respawn clears. Existing seeded stronghold positions remain the source of truth.
9. Finish the missing shells, structural variants and minion models before describing them as done; rebake scenes and maintain model status documentation.

Acceptance checks:

- All five shells can be inspected safely, cracked, broken once and hatched without player damage or early pack clears.
- Every phase can be reached normally and through a debug skip; the skip cleans old objectives and initializes all new ones correctly.
- Crystal: exactly six valid towers; six -> zero objective count; healing rate follows living count and frame time; all six dead is mandatory; healing never restores phase 1; failed tower spawn cannot soft-lock; no shardlings remain afterward.
- Demon: only Sentinels gate its shield; mites never do; mites have a cap and stop at shield break.
- Scarab and spirit: their optional minions never grant unintended immunity or respawn; all disappear safely before final phases.
- Teleports have visible tells/reassembly and safe colliders; charges stop on valid terrain; beams/ground effects have bounded hit rates and visible hit volumes.
- Bosses remain hittable by Archer while floating; no instant unavoidable shotgun from overlapping projectiles or attack children.
- Kill/save/re-enter cannot respawn a defeated boss; wipe cannot duplicate eggs, timers, loot or summons.
- No damage after death cleanup begins; rewards roll once; support cleanup grants nothing.
- Verify item/drop allowlists, actual icon imports, all per-item chances, non-top reductions, color separation and the scaled HP threshold. Seeded/statistical tests should distinguish a 3% independent roll from a 3% whole-set roll.
- Run existing realm integration tests, relevant settlement/spawn-clearance regressions, boss-art validation and new lifecycle/combat tests. Existing art validation expects the bosses to remain unregistered; update that assumption when promoting them live rather than retaining an obsolete art-only assertion.
- Inspect actual gameplay captures with normal, weak and high-level Archer gear. Tune hit rates, telegraph contrast and total fight duration; solo attempts should be substantial encounters, not hour-long HP walls. Preserve the specified identities/objectives/rates while adjusting only clearly documented combat balance where playtests require it.

Deliver a concise implementation report listing which encounters are live, which models were improved/added, final damage/timing differences from this brief, test results and any genuinely unfinished work. Do not present a showroom animation as a finished boss fight.
