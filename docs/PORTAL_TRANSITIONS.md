# Portal travel

`Transition` carries departure, loading and arrival through the same near-black
field. The HUD stays hidden and player controls stay locked until arrival ends.

- Departure lasts 3.4 seconds. A few small patches peel away first, then the
  tear spreads through the scene. Detached cubes are 22% smaller, lift, spin
  and occasionally flash white. The zoom and edge stretch build up later.
- Loading shows a rotating 3D voxel portal, destination and smoothed progress.
- Arrival lasts 4 seconds. Cubes travel from behind the camera to their final
  positions. The loader fades first, then the cubes settle and hand back to the
  live world with a short dither dissolve.

## Rendering

`PortalFracture` snapshots mesh resources and their world transforms, plus a
private copy of loaded terrain blocks. `PortalVoxelBuilder` samples the native
voxel mesh faces and terrain volume on a worker. A single GPU MultiMesh carries
real world-space cubes with the models' orientation, size and palette colours.
Terrain includes side walls and a second layer of soil. There is no screen-space
sampling grid, depth capture or full-screen capture quad.

Actors and the world pause during the snapshot and animation so the live models
match their reconstructed poses. A small camera orbit gives depth parallax.
Fragment lighting uses the scene lights, a cool fill and strong voxel face
contrast, with restrained glow on sparse white/chromatic glitch pulses.

Arrival keeps the loading portal visible until the first cubes pass the camera.
All fragments settle before the live world is revealed at 90%; the last 10%
dissolves the cubes into the live geometry. Camera, environment, visibility mask
and paused processing modes restore on completion or scene exit. Headless runs
skip the graphics effect.

Startup is separate: branding plays while the menu world prepares underneath.
The logos wait for that world before fading to the menu; boot never plays a
portal departure, loading screen or reconstruction.

## Loading work

`WorldLoader` uses threaded resource loading and one preparation worker for
terrain plans, navigation, scenery plans, creature/prop mesh resources and fog
maps. Only the main thread instantiates scenes and publishes rendering nodes.
The old world stops processing while detached replacement data is prepared.

Ground dressing and Chambers dressing publish in queued steps. Realm streaming
uses its bounded build queue instead of forcing every nearby chunk into one
frame. Old trees detach immediately and free incrementally. The main loop can
therefore keep presenting the portal while expensive CPU preparation runs.
Publishing still requires the main thread; first-use driver shader compilation
or an unusually expensive individual publication step can cause a brief hitch.

Thread ownership follows Godot's [thread-safe API guidance](https://docs.godotengine.org/en/stable/tutorials/performance/thread_safe_apis.html).

## Short smoke check

`tools/test_portal_transition.tscn` checks worker responsiveness, native geometry,
visibility during handoff, camera restoration and the complete departure/loading/arrival sequence. With a
renderer it writes example frames to `/tmp/void_portal_*.png`. Headless mode
checks preparation only; `-- --prepare-worlds` includes all destination types.
`-- --actual-world` uses Tavern geometry for a brief renderer check.
The fixture uses generated world records and does not change account data.
