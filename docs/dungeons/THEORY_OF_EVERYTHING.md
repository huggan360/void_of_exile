# Theory of Everything

Two large fairytale timber spacecraft and over a kilometre of rainbow ribbon in
deep space. The route is authored; puzzle programs and circuits
are generated from each dungeon instance's seed. The boss is left for later.

## Route and controls

- **Aurora**: warm wooden cabins, two decks, observation bow, panoramic windows,
  brass fittings, green crystal gardens, timber ribs and green magical engines.
  Quilted bunks, books, chart desks, wardrobes, cargo barrels and a little galley
  vary the rooms. Hanging lanterns and amber diffusers soften the green/pink trim.
  All five electrical boxes are visible along the main corridor on the lower
  deck. A short objective hint names the nearest unchecked circuit and its side
  of the corridor. Find the randomly chosen relay to open the forward airlock.
  Each switch has a short
  result that explicitly identifies the airlock relay or rules that box out.
- **Chromatic Expanse**: a twisting gravity ribbon, rainbow inlays, crystal rail posts, amber lanterns and brass-capped
  timber frames and the Pathfinder grid lock. Floors roll into walls and roofs.
- **Vessel 02**: a damaged two-deck ship with blocked corridors, alternate routes,
  maintenance ducts, shootable grilles, sparks, emergency flicker, blood and an
  abandoned suit. Repair all five sparking electrical boxes across both decks
  to release the escape airlock. Each repaired box stops sparking and its lever
  flips down. The parity engine upstairs is an optional diagnostic puzzle.
  Rotten timber, splinters, brood resin, claw marks, webs, failing amber lamps,
  green ghost-fires and drifting smoke fill both decks. Fires apply the normal 3.5-second Burning status through
  the shared contact-fire system, including on the server.
  Larger ghost-fire spills vary in position, size and flame shape by dungeon seed.
  Independent green cores, tilted plumes, spectral embers, surges and soft smoke replace
  the repeated small tray fires. The centre of the corridor remains clear.
- **The Unravelling**: a protected escape cinematic reveals unstable architecture
  and a second exterior ribbon with wall turrets.
- **Convergence**: a raised approach enters the curved wood/crystal boss arena,
  edged with alternating pink and green glow rings and mineral-tipped pillars.
  Four shrinking, bending floor stages are ready for the future boss. A return portal is available.

Seven voxel celestial bodies, including two suns, occupy the same 3D world as
the ships, along with rings, stars and vibrant green/pink nebula dust. Distant dust
remains darker behind the far route. Windows have clear glass and
physical collision, with actual space behind them.

Both ships blend to first person over 1.15 seconds. Mouse look uses a white dot;
normal weapons and charged attacks retain vertical aim. Shots originate beside
the camera and converge on the crosshair; nearby hulls retract the muzzle.
Walking adds subtle camera sway. First person shows the inner surface of the
full shield bubble around the body, following spell colours, impacts, local
gravity and release fade as the player looks around. Opening UI releases the
mouse. Exterior views use the normal camera setting and zoom. Bodies, cameras,
sound listeners and remote players follow the local gravity frame. E reads
consoles; standing on physical tiles operates puzzles.

Fog of war and the planar minimap are disabled. Aurora has faint volumetric haze.
The wreck uses a flashlight,
darkness, occlusion and subtle volumetric haze. Local equipment auras and trails
are hidden in first person. The wreck's narrower flashlight beam intermittently
stutters and dims, with long usable intervals between brief battery faults.
Zone music and ambience remain
unassigned until the supplied audio arrives; normal combat/UI sounds continue.

## Generated puzzles and multiplayer

Pathfinder generates a monotone N/E/W program on a 6 by 6 chess grid. A wrong
tile or leaving the board resets that player's route. The harmonic lock has
been removed. The optional parity engine
generates an invertible four-switch XOR circuit and a reachable target; its
console supplies the circuit masks and target lamps.

The server evaluates actual player positions, opens gates and validates surface
hit requests. Reliable `theory` events share progress, impact flashes, broken
grilles and turret shots. Electrical interactions validate proximity on the server;
the hidden relay is chosen once per run and progress is shared with the party.
Switches engage with one interaction. Device cards update as the authoritative
reply arrives; checked boxes retain their result. Cabinets have distinct circuit
names and wall mounts, with no numbered labels. The successful relay identity,
lever states and repairs are shared with joining players.
`theory_state` in the world-entry record restores solved gates, checked/repaired
boxes, broken props and arena phase for joining players.

## Code and future boss hook

The implementation lives in `scripts/dungeons/theory/`: layout/frame queries,
voxel art/collision plans, puzzle generators, surface effects, sparks, world state
and traversal. Art preparation runs on the loading worker; rendering publishes
in bounded steps. The server skips visual work. Coordinate hashes keep cosmetic
randomness separate from structural RNG, preserving collision parity.

The shared dungeon factory selects TheoryWorld on client and server. Collision
bodies replace height-only terrain here. Falling recovery returns a character to
the nearby magnetic surface and is validated separately from movement speed.
Exterior surfaces and obstacles blink and ripple when hit. Ship walls, floors,
window frames and structural trim stay still and never flash white on impact.
Sparks use ballistic motion, aligned streaks
and a pale green/acid-green/pink fading gradient, with no attached audio yet.

Ship bays meet edge to edge, including both decks, full-height partitions and
window bands. The observation bow tapers continuously; stair handrails follow
the stair slope and finish at their landings. Duct branches meet the trunk at
cut openings, with raised grating instead of overlapping the ship deck.
Door panels retract into fixed lintels. Fine cabinet controls, vents, fasteners,
workbenches, supply racks, cable ladders and ceiling mounts add close-up detail.
Conduits, split clamps, ceiling hangers, hex fasteners, cabinet hinges, lever
hardware and curtain rails use round native meshes rather than voxel boxes.
Every cabin on both decks also has connected service branches, wall-mounted
risers, valve wheels, pressure dials, perforated returns, safety plates and
equipment readouts. Risers are omitted over stair openings. Observation-bow
services follow its taper and feed the front header; navigation consoles have
actual inset displays, keyboard plates, encoders and operator seats.

World-space plank seams, wavering wood grain and knots add material detail
without stretching across different sized pieces. Brass fittings have a soft
antique finish; wreck wood has dark splits and rot. Colour distinguishes timber,
brass and minerals without changing the existing 20-float voxel buffer, swept
mesh alpha packing or impact eligibility. Exterior surfaces retain their impact
blink and ripple. Fine grain, seams and inlay marks fade with distance.
Instrument, vent, astrolabe display and amber lamp faces use batched procedural
inlays. New inlay modes provide parchment star charts, cobwebs and claw gouges.

Story props dress the original solid cabinet/cradle footprints; decorative
quilts, books, plants, rope coils and lanterns add no collision. The observation
bow has captain's chart desks beside its navigation consoles. Crystal posts and
lanterns follow the ribbon's true gravity frame, including rolls. Green engines
and green fire cores contrast with amber lantern glass. Existing real lights are
recoloured, with no extra real lights. Wreck ghost-fire illumination is dimmer
and keeps its existing distance fade. Fire hazard positions, sizes, styles and
counts are unchanged. New variation uses coordinate hashes and `_detail_seed`;
existing structural RNG consumption is preserved. Servers skip the new dressing.

The wreck uses fourteen main ceiling lights across both decks instead of the
previous eighteen lower-deck lights: ten failing dark amber fixtures with shadows
and four steady dim amber emergency lights. Their diffusers and illumination follow
the same server-clock fault cycle. Most additional sparks are emissive particles
without individual point lights. The flashlight is modestly brighter, broader
and reaches further, retaining its brief battery faults. Cabin diffusers remain
visible during failures while the larger ghost-fires provide limited green
local illumination.

Loose wires are round rope meshes driven by pinned Verlet chains. Cabin doors
have two cloth panels: rose and ochre fabric in Aurora, resin-stained and physically
torn fabric in Vessel 02. The top rings stay fixed while cloth and ropes move
around players and settle under gravity. Simulations run on the authority and
consider all players; clients interpolate per-object point packets and project
their own capsule for immediate contact. Millimetre point encoding fits each
panel in one small unreliable packet on a separate channel. Fixed structures
and gameplay collision remain independent of these soft details.

Each airlock and the Pathfinder gate schedule one reliable shared door scene.
The server announces a future start, opening time and ending time. Clients use
their synchronized server clock for the camera and the actual door pose; late
packets and joining players seek to the current phase. All living dungeon
players receive authoritative movement/combat locks, Invincible and Immune;
the HUD hides during the shot and restores afterwards. Completed scenes remain
in entry snapshots without replaying. This detail replication uses protocol 4;
restart both clients and the server after updating.

Exterior deck and rail cells are swept between shared gravity frames, so their
edges meet through curves and rolls. The same triangle skin provides static
collision. The road clips against the Pathfinder dais and the airlock sills;
attached service decks support exterior machines and closed antenna hoops.
Only separate fracture debris modules drift; intact structural modules remain
assembled. Mesh vertex alpha carries emission and impact eligibility for the
opaque Theory shader; MultiMesh custom data separately marks reactive props.
The final approach straightens and unrolls before meeting the wreck's docking
collar and flat entrance sill.

Call `world.set_arena_stage(stage)` on the server, with stages 0 through 3. Radius
changes from 27 to 21.5, 16 and 10.5 metres. Removed rings lose collision and fall;
surviving render geometry, collision and gravity bend together. The phase is
replicated and restored for joining players. Players cannot request boss phases.

## Entering and short checks

Developers can use `/theory` in a realm to open a party-capable entrance nearby.
It is not added to ordinary enemy drop tables yet. The existing manual preview
launches a maxed archer directly into it:

```sh
/home/hugo/Godot/godot_voxel_editor --path /home/hugo/Godot/Projects/VoxelRealms -- --play-dungeon=theory_of_everything
```

Add `--seed=1234` for another puzzle instance. `tools/test_theory.tscn` checks
puzzles, collision parity, upside-down locomotion, vertical aim, grilles, gates,
joining state and arena phases. Native mode writes `/tmp/void_theory_*.png`.
`-- --main-integration --play-dungeon=theory_of_everything` checks Main, HUD and
normal weapons as well. The fixture does not write account data.
