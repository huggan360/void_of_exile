# The Hollow Castle

`res://scenes/castle/hollow_castle.tscn` is the fixed final-campaign castle.
`CastleWorld` extends `GameWorld`, defaults to realm `castle`, and owns the
playable encounter. See the integration API below.

The 164 × 165 block silhouette encloses a bridge, gatehouse, courtyard, vaulted
pillar nave, raised side chapels and a throne room. The combat floor is level
at Y=0; keep the central ~44-block-wide arena clear. The throne/dais sit along
the back wall. `BossSpot` is at (0, 0, -51), and `Spawn` at (0, 0.15, 79).

## Edit the scene

Architecture is **hand-authored in the scene**, like the Tavern: each named
`Architecture` child is a solid editable `BoxMesh` brush. On load, CastleWorld
snapshots its bounds, block and checker setting into an immutable voxel
terrain generator. This is a scene bake, with no random seed or procedural
layout. Brush previews hide in play; the rendered, collidable masonry is
`VoxelTerrain`, using the shared `Blocks.mesher()`. Keep brush edges on the
integer block grid. `walk_surface` marks floors/stair treads for ground queries;
other solids block walking. The checker uses 3 × 3 block tiles. New block IDs
are appended to the existing Blocks enum.

Props are editable `Props` children using `props/castle/castle_prop.gd`. Sixteen
hand-sculpted palette voxel models cover sentinels, braziers, banners,
candelabras, chandeliers, bones, cobwebs, broken lancets, chains, the empty
throne, charred/burning trees, fallen logs, stumps, embers and discarded armour. The models use the project's voxel mesher/material and share their
cached meshes. Solid props have box collision. Flames share a lightweight
animated shader; interior burning props have 12 embers (chandeliers 24), while exterior
particle emitters are capped at 32. The 28 cold
white omni lights use two shadows total. Architecture intentionally has an
open roof for top-down play and cinematic camera access.

## Cinematic stage

Use `CastleWorld.stage()` under **any Node3D parent**, set its local offset before adding it,
and later `queue_free()` it. A scenery stage does not register as the active game world,
spawn actors, connect networking, create portals, change the environment or
add a viewer/camera. All terrain, props, lights and anchors inherit transforms.
Use translation and yaw; keep voxel worlds at unit scale.

```gdscript
var castle := CastleWorld.stage() # or preload(...hollow_castle.tscn).instantiate()
castle.position = Vector3(0, -600, 0)
cutscene_root.add_child(castle)
# The cinematic's VoxelViewer must be near the stage to load its voxel chunks.
viewer.global_position = castle.to_global(Vector3(0, 12, 0))
viewer.view_distance = 240
camera.environment = preload("res://scenes/castle/castle_environment.tres")
camera.global_position = castle.get_node("ShotBridgeFrom").global_position
camera.look_at(castle.get_node("ShotBridgeLook").global_position)
# Tween toward ShotBridgeTo.global_position while keeping the look target.
# Restore camera.environment/viewer placement when the cinematic ends.
castle.queue_free()
```

The eleven direct `Marker3D` children are named exactly:

- `Spawn`, `BossSpot`
- `ShotBridgeFrom`, `ShotBridgeTo`, `ShotBridgeLook`
- `ShotHallFrom`, `ShotHallTo`, `ShotHallLook`
- `ShotThroneFrom`, `ShotThroneTo`, `ShotThroneLook`

Use global marker positions for camera work, so nested/offset stages work.
`spawn_point`, `ground_height(x,z)`, `is_walkable(pos)` and `map_color(x,z)` use
castle-local coordinates, matching HallWorld's query convention. Translate
queries with `castle.to_local(world_position)` when using an offset stage.
The supplied environment is opt-in, so a stage cannot override its host's
WorldEnvironment. The review tool adds a cool moon directional light at 0.8
energy; the cinematic can supply equivalent lighting.

## Review and verification

```sh
/home/hugo/Godot/godot_voxel_editor --path . --resolution 1600x900 tools/review_castle.tscn -- --offset
/home/hugo/Godot/godot_voxel_editor --headless --path . --import
/home/hugo/Godot/godot_voxel_editor --headless --path . tools/review_castle.tscn -- --offset
```

The graphical review writes `/tmp/castle_overview.png`, `/tmp/castle_bridge.png`,
`/tmp/castle_hall.png`, `/tmp/castle_throne.png`. It uses the real baked voxel
terrain. Both modes check the central route, chasm exclusion, pillar exclusion,
raised chapel ground, physical voxel collision heights and nested stage marker
transforms. Review creates its
own viewer (240-block distance); normal gameplay must provide its player viewer.

## Playable castle / integration (2026-11-01)

The scene now defaults to a playable CastleWorld. Set `realm_id` and `display_name`
before `add_child`; neither is overwritten in `_ready`. RealmInstance chooses this
scene when `record.castle == true`. The campaign owns private realm records and
IDs (`cst_<account>_<pack>`). It exposes the DungeonWorld director, streaming,
obstacle and pack query interface, plus a no-op `gates.states()`/`try_open()` adapter.
The encounter validates its own server barriers because NetServer's gate movement
check is restricted to IslandWorld. Client director binding is deferred until after
NetClient.attach_world and uses the existing public director/player/bullets fields.

`CastleWorld.stage()` sets `cinematic_stage = true`: no encounter or director.
Direct scene instances placed below Y=-200 (the campaign's -600 stage convention)
also become scenery stages. The existing marker and translated-stage API remains.

`world.encounter.on_action(p: Dictionary, args: Array)` accepts only `["door"]`,
with `p.player_id`, `p.realm`, `p.pos`. It checks authority, champion completion,
realm, <=8m flat distance and a carried story_throne_key; consumes it atomically.
The InteractionTarget sends `Net.client.send_action("castle", ["door"])`.

`world.castle_event(ev: Array)` accepts both plain arrays below and NetClient's
`[timestamp, "castle", kind, ...]`. All server events use exactly one transport:
`Net.server._to_realm(realm_id, Vector3.INF, ["castle", kind, ...])`.
Kinds and arguments:

- `state, stage:int`: idempotent gate/wall/door catch-up for arrivals.
- `gate_close`: portcullis collision and slam animation.
- `holes_open`: remove the two wall plugs, animate individual falling blocks.
- `key_dropped, pos:Vector3`: champion completion / door interaction enabled.
- `door_open`: iron door lifts; collision disabled.
- `cutscene, shot:String, seconds:float`: `guardians` or `throne` camera shot.
- `king_rise`: seated king stands; authoritative actor replaces the cinematic model.
- `king_dead, pos:Vector3`: final death burst completed, stage 6.

Stages: 0 entrance, 1 knights, 2 champions, 3 key/door, 4 throne procession,
5 king, 6 complete. Late arrivals receive `state`; active cutscenes do not replay.
Party gathering uses `social.warp`, including its existing portal transition.
GameServer boss-intro locks provide authoritative arrival/cutscene protection.

The king uses the normal `Boss._burst -> GameServer.enemy_killed` path, which
already calls `Net.server.campaigns.enemy_died(realm_id, def, pos)` exactly once.
Thus normal campaign kill objectives see **hollow_king**, castle_knight and
castle_champion. Additionally, `world.king_defeated(realm_id)` and
`world.encounter.king_defeated(realm_id)` fire after the king's final burst;
`enemy_director.enemy_killed(enemy)` also fires for the encounter's actors.

King and helpers use +20% HP per extra player. The four-phase king has 72k base HP,
telegraphed wide iron cleaves, aimed fans, curved magic and rings with safe gaps.
Phases 2/4 return to the throne, sit and call guarded summons with arm_summon.
All phase transitions use Boss.begin_rest; death holds a kneel for five seconds.
Editable 32-grid source models accompany enlarged voxel rigs in creatures/*/source_32.
Regenerate the new art with `python tools/build_hollow_king_art.py`; this authors
only the three castle creatures, three projectiles and new Iron/key icons.

Watcher: `tools/boss_watch/watch_king.sh` or
`~/Desktop/Boss Fight Watchers/watch_king.sh`. P pauses the king, D toggles automatic
damage, R replays, Escape closes. `-- --fast --shots --seconds=85` captures phase
images under `/tmp/hollow_king_phase_*.png` and exits. Saves use an isolated cache.
No login or account service is involved.

Playable castles hide overhead chains/chandeliers for a clear combat camera;
cinematic stages keep the complete authored decoration.

## Burned woodland exterior (2026-11-01)

The castle silhouette is unchanged; scene-authored ash shelves and wooded cliffs
now extend the scenery to a 384 × 384 block footprint. Charred trunks, snapped
limbs, fallen logs, stumps and smouldering ground frame the bridge ravine. A broken
road continues from the arrival plinth to a landslide at Z=148; bones and abandoned
armour line its verges. The terrain shelves and dense burning perimeter are
scenery barriers, not additional encounter floor. No forest prop overlaps the
original combat arena. Existing Spawn/BossSpot and hall/throne markers are intact.
The bridge fly-in starts farther out (Z=142 → 96) to include the road and woodland.
A taller rear ridge carries forest silhouettes above the hall/throne parapets.

Six shadowless, distance-faded exterior fire lights are the entire added light
budget. Other fires use cached voxel flame meshes and the shared flame shader;
only 32 woodland props emit particles. All models share the existing voxel palette
and mesher. Existing non-emissive gravel/slate blocks provide the ash/cliffs.

CastleWorld supplies its own private BiomeDef: cool moonlight, dark sky, zero
distance fog, zero volumetric fog and no fog of war. The opt-in cinematic
castle_environment.tres also disables both fog types. Stages still leave the host
environment untouched. The Tavern biome is never modified.

`scenes/castle/review_exterior.tscn` adds a brief headless check of the fog settings,
road continuity, closed exterior boundaries and the light/particle budgets. The
usual review_castle tool still checks the original route, stairs, chasm, pillars,
physical collision and translated markers, and renders all four views. Final
images are copied to `/home/hugo/Desktop/castle_renders/castle_*.png` as well as
`/tmp/castle_*.png`.
