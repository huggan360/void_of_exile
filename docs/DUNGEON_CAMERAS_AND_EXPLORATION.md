# Dungeon cameras and exploration

Standard DungeonWorld instances now receive GroundView, so the saved
third-person preference and V camera toggle work just as they do on the
Surface. TheoryWorld remains a separate SpatialWorld with TheoryTraversal;
its scripted cameras, first-person zones and map behavior are unchanged.

GroundView and the on-foot SpaceTraversal shoulder camera use the shared
ShoulderCameraSmoothing helper. It eases the orbit basis and follow anchor,
with 24/s follow and 26/s turn rates (about 40 ms time constants). Anchor lag
is capped at 0.5 m. A first frame, mode change or teleport beyond 8 m snaps
instead of drifting through the map. First person, overhead views and ship
seat/cinematic cameras keep their existing behavior. Camera shake is applied
after the unshaken follow pose. Collision is checked after easing so walls
still pull the camera in immediately; standard dungeon scenery is included
in that check.

DungeonWorld explicitly enables opaque exploration fog on its cloned biome.
The newer themes previously inherited disabled fog from outdoor biomes such
as Woods and Beach, exposing both the environment and the minimap. All
standard dungeons now use their theme's reveal radius and the real explored
texture in both minimap sizes. Outdoor biome definitions stay unchanged.

Validation:
- tools/test_dungeon_camera_exploration.tscn: 152 checks, covering every
  standard dungeon, both map sizes, party discovery, Theory's controller,
  frame-rate independence, teleport resets and terrain/scenery camera collision.
- tools/pets/check_yard.tscn: existing indoor first-person, roof and outdoor
  camera restoration checks pass.
- tools/preview_dungeon_camera.tscn: actual offline Saltbone Wreck captures
  /home/hugo/tmp/dungeon_third_person.png and dungeon_exploration_map.png.
- tools/test_city.tscn: five failures also reproduced on unchanged HEAD
  1153006 in an isolated worktree (drink actions and old camera expectations).
  These are existing test failures, not introduced by this camera pass.

Included in 26.5-beta.
