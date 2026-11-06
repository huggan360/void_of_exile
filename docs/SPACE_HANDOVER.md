# Space update - handover

For the next Claude session. The user's request: "check this file and it starts working". Read this whole
file, then begin at **Next steps** without asking for confirmation. Keep the user informed with short updates.

## Ground rules (from the user and project memory)

- Never write the middle dot (U+00B7) or the bullet glyph (U+2022) anywhere in the project. Use "-".
  Tell Codex workers this too, and grep for it after they finish.
- The user does the visual testing. Keep checks light: scripts load, one short scripted smoke test,
  a screenshot only when a visual is uncertain.
- Back up before big edits: `rsync -a --exclude .godot <project>/ ~/tmp/voidrealm_before_<task>_<timestamp>/`
  (no git in this project).
- Codex may be used as a worker when the user allows it (see memory note `codex-helper`). Give it
  self-contained tasks touching files nobody else is editing. It cannot render screenshots.
- Online tests: use account p2 (`--login=p2:12345`), never p1. Kill only the server PID you started.
- Godot binary: `/home/hugo/Godot/godot_voxel_editor`. Project: `/home/hugo/Godot/Projects/VoxelRealms`.
  After adding `class_name` scripts, run `--headless --path . --import` first.

## Background

- The user's notes: `SPACE_INSTRUCTIONS.md`. The plan: `docs/SPACE_PLAN.md`. Pass 1 (Theory of Everything
  brood, Hollow Empress boss, fairytale art, M map) is done. Pass 2 (this file) is mostly built.
- Backups: `~/tmp/voidrealm_before_theory_creatures_20261106_1040` (before pass 1) and
  `~/tmp/voidrealm_before_space_pass2_20261106_1207` (before pass 2).

## What pass 2 built

The Astral Reach (`SpaceWorld`, realm id `astral`): one shared space world per server.

| Area | Files |
|---|---|
| Shared spatial base (Theory and space) | `scripts/world/spatial/spatial_world.gd`, `spatial_controller.gd` |
| Layout contract (planets, regions, berths, pockets, asteroids) | `scripts/space/space_layout.gd` |
| World, authority, requests, marks, NPCs | `scripts/space/space_world.gd` |
| Ship state and flight model | `scripts/space/space_ship.gd` |
| Client hull view (interpolation, turrets) | `scripts/space/space_ship_view.gd` |
| Player controller (walk, seats, cameras, HUD) | `scripts/space/space_traversal.gd` |
| Space enemies and cannon bolts | `scripts/space/space_foes.gd` |
| Interactables, NPCs, beacons, crosshair, map, cutscenes | `space_interaction.gd`, `space_npc.gd`, `space_beacon.gd`, `space_crosshair.gd`, `space_map.gd`, `space_cinematic.gd` |
| Art builders (by Codex) | `scripts/space/art/` (station, planets, backdrop, hull, interior, rocket, Tavern launchpad) + `shaders/space_*` |
| Campaign extension (reach_* step kinds) | `scripts/campaign/reach_campaign.gd`; tales and NPCs inside `scripts/campaign/campaigns.gd` (pack `astral_frontier`) |

Key design decisions:
- Ship interiors are static rooms far below the map (`SpaceLayout.POCKET_*`); the hull flies outside.
  Players never ride a moving platform; seats switch the camera to the hull.
- Planets: SphereShape3D ground, gravity toward the centre via `SpaceWorld.sample_gravity`.
- Client requests go through `SpaceWorld.request()` on the existing "theory" action channel
  (`SpatialWorld.server_action`); the authority teleports with `Net.c_correct`.
- Entry: the Theory boss kill opens a "To the Nexus" portal (`TheoryWorld._open_star_portal`);
  `NetServer._astral_unlocked` gates travel (Theory campaign done, standing in a Theory with the boss dead,
  or a `--test` server). The Tavern launchpad (`HallWorld._build_launchpad`, Lookout plaza at 81,10,-8) uses
  `record.astral_unlocked`. First visit per account sets `book.astral_intro` and plays the Nexus tour.
- Theory campaign: step `convergence` waits for the boss, step `beyond` (final) completes when a member
  arrives in `astral` (`AstralCampaign.tick`). XP 8000.

## Verified

- Offline smoke `tools/test_space.tscn`: 14/14 passed (arrive, launch, board, helm, fly, land on Verdance,
  hatch out, walk on the sphere, board again, skiffs spawn, cannon fire, map, R home). Screenshots in
  `~/Desktop/space_renders/`.
- Online smoke `tools/test_space_online.tscn`: 8/11 passed. Travel, launch, board, helm replication,
  server flight and hull interpolation work. **Failed: docking, then the hatch at the berth and its
  follow-up check.**
- `tools/test_theory.tscn` passed except "all electrical boxes are mounted against solid bulkheads", which
  already failed before any of this work.

## Next steps (in order)

1. **Fix online docking.** In the online test the pilot flew 13.8 km away at boost before `["dock"]`, so the
   server's 900 m check refused it (that message goes to `_tell`). Likely only the test: make the test
   fly briefly (or turn back) before docking, and check the hatch afterwards. If docking still fails,
   debug `SpaceWorld.server_action("dock")`. Rerun the online smoke (commands below).
2. **Station art polish** (Codex worker was stopped before it changed anything). From the normal camera
   the Nexus is a big empty plank floor with long diagonal streaks (likely grazing sun light / shadow acne
   from `SpaceBackdrop`'s DirectionalLight3D). Brief already written:
   `/tmp/claude-1000/-home-hugo/ed502364-757f-436b-ab76-0d110cc74c79/scratchpad/codex_station_polish.md`
   (the scratchpad may be gone; if so, rewrite it from this paragraph: dense cosy tavern plaza near the
   spawn, hearth of green fire, stalls, signposts, zoned floors, keep anchors/collision). Ask the user
   before launching Codex again (they told us to stop the last run).
3. **Look at the Tavern launchpad in game** (never rendered). Render it once and check it sits on the
   Lookout plaza and doesn't clip buildings.
4. **Play one Reach tale end to end online** (First Light is the shortest): the tale must be started by the
   party leader from the campaign board/book. Check talk steps with Captain Isolde and Elder Moss, the
   search marks on Verdance, dock and report. Then spot-check `reach_kill` (Lantern Road) and
   `reach_repair` (Shardfield).
5. **Update docs**: add a "Pass 2 status" section to `docs/SPACE_PLAN.md` and a short Astral Reach section to
   `scripts/campaign/README.md` (reach_* step kinds are documented as a comment in `campaigns.gd`).
6. Then tell the user what works and what they should look at with their watch scripts.

Known gaps to mention, not to fix unless asked: no walking enemies on planets, no pilot prediction online
(input lag), ships vanish when the Reach unloads (2 min empty) or the server restarts, account service on the
Pi not redeployed (no account-service changes were made, so probably not needed).

## Commands

```sh
cd /home/hugo/Godot/Projects/VoxelRealms
G=/home/hugo/Godot/godot_voxel_editor
$G --headless --path . --import

# Offline smoke with screenshots
$G --path . --resolution 1600x900 res://tools/test_space.tscn -- --shots=$HOME/Desktop/space_renders

# Online smoke: test server (scratch data dir) + client as p2
mkdir -p /tmp/vr_srv /tmp/vr_cli
XDG_DATA_HOME=/tmp/vr_srv $G --headless --path . res://scenes/server/dedicated.tscn -- --port=24987 --test &
echo $! > /tmp/vr_srv/pid; sleep 12
XDG_DATA_HOME=/tmp/vr_cli $G --path . --resolution 1280x720 res://tools/test_space_online.tscn -- \
  --online=127.0.0.1:24987 --login=p2:12345 --space-test | grep space-online
kill $(cat /tmp/vr_srv/pid)

# Play the Reach offline yourself / the Hollow Empress watcher
$G --path . -- --play-space
"$HOME/Desktop/Boss Fight Watchers/Watch Hollow Empress.sh"
```

`tools/_space_check.tscn` is a throwaway compile/instantiate check from this session; delete it when done.
