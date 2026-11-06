Realm streaming and remote movement
==================================

IslandWorld now schedules obstacle generation in 8 by 8 tiles, individual
houses, trees and NPCs, and separate decor generation and mesh groups. It
checks a 2 ms main thread budget between operations. Decorations still share
one MultiMesh per prefab/biome group within a chunk. Initial realm entry can
finish the queue synchronously behind the existing transition.

Distant chunks retire one per streaming update, including their enemy sites
and obstacle references. Unfinished work is cancelled when its chunk retires.
Clients retain the existing extra chunk of hysteresis to prevent border
thrashing. Servers rebuild their desired set only when occupied chunk centers
change and prioritize chunks nearest to any player.

The voxel engine's main thread budget is 3 ms (the installed engine default
was 8 ms). VoxelViewer continues to bound terrain residency by view distance.
Navigation caches have fixed limits: 16,384 columns and 128 obstacle-box
chunks. Column eviction uses a circular insertion-order queue. Box geometry
and its spatial index are evicted together. Immutable shared prefab meshes
remain cached to avoid repeatedly loading and meshing the same assets.

Remote players retain the existing 120 ms snapshot delay. Short snapshot gaps
use measured velocity, capped at 20 metres per second, eased to zero over
100 ms. This adds at most one metre after the last authoritative position;
long outages hold there and stop walking animation. Prediction is disabled
across teleports, frozen states, and snapshot intervals above 250 ms. Late
snapshots are ignored. Frame-rate independent position/facing smoothing
softens resumed updates, while corrections of six metres or more snap.
These changes do not predict the local player's combat or change authority.

Validation
----------
Run from the project directory:

    /home/hugo/Godot/godot.sh --headless --path . tools/test_streaming_smoothing.tscn
    /home/hugo/Godot/godot.sh --headless --path . tools/test_town_npc_placement.tscn
    /home/hugo/Godot/godot.sh --headless --path . tools/test_quest_guide.tscn
    /home/hugo/Godot/godot.sh --headless --path . tools/test_quest_realm_navigation.tscn

Budgets are cooperative: a single asset load, mesh creation, physics update,
or GPU upload can exceed them. Headless timing covers CPU scheduling only.
For graphics validation, travel through towns and multiple biomes while
watching Godot's frame-time profiler; repeat the route after assets are warm.
Check that terrain keeps ahead of the player, memory stabilizes after leaving
an area, remote players stop during sustained packet loss, and large
teleports do not slide through intervening geometry. The two existing quest
scenes currently report resource/RID cleanup warnings on headless exit.
