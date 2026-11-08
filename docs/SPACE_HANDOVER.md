# Space update - handover

For the next Claude session. Read this file, then `docs/SPACE_PLAN.md` (pass 3 is the
current state). The user's notes are in `SPACE_INSTRUCTIONS.md`.

## Ground rules (from the user and project memory)

- Never write the middle dot (U+00B7) or the bullet glyph (U+2022) anywhere in the project. Use "-".
- Keep everything voxel and fairytale: reuse the realm's voxel obstacles (`ObstacleLibrary`,
  `obstacles/*.vox`) and props before inventing primitive art. Glowing, cosy near the Nexus,
  dark and mysterious in deep space.
- The user does the visual testing but wants careful work: check each change with a render
  (`tools/space_lab.tscn`) before moving on.
- The project is a git repository now (github.com/huggan360/void_of_exile). Work on a branch;
  commit only when the user asks.
- Online tests: use account p2 (`--login=p2:12345`), never p1. Kill only the server PID you started.
- Keep every file under `/home/hugo/godot` (the user asked for that): test data in
  `/home/hugo/godot/tmp`, renders in `/home/hugo/godot/tmp/space_renders`.

## Machine

- Engine: `/home/hugo/godot/engine/godot_voxel_editor` (Godot 4.7.2 with the voxel module,
  godot_voxel release v1.7). Self-contained mode (`_sc_`), so editor data lives in
  `/home/hugo/godot/engine/editor_data`. Export template beside it.
- Project: `/home/hugo/godot/projects/void_of_exile`. After adding `class_name` scripts run
  `--headless --path . --import` first.

## State (pass 3)

All of the user's pass 3 notes are built (see the plan). Verified:
- `tools/test_space.tscn` offline: 18/18, including free landing far from the pad, the landing
  spot clear of obstacles and brood ignoring a landed ship.
- `tools/test_space_online.tscn`: 12/12. `tools/test_reach_online.tscn` (First Light end to end
  online): 23/23.
- Look-development renders of planets from orbit and on the ground, the Nexus rock, the ship
  (hull, live windows, helm), brood ships, the Shardfield, the edge and the star chart.

## Known gaps

- `reach_kill` and `reach_repair` (Lantern Road, Shardfield tales) were not replayed online
  after the brood rework; the ambush now spawns outside the planet's air.
- No walking enemies on planets; no pilot prediction online (input lag); ships vanish when the
  Reach unloads or the server restarts.
- Landmarks at the story places are still primitive (box) art; the realm's voxel houses in
  `props/houses` and `props/home` would fit them better.
- Planet terrain is smooth (not block-stepped); the flora and props are voxel.
- The voxel module prints `!is_inside_tree` errors from `direct_static_body.cpp` on the client;
  harmless, came with the engine.

## Commands

```sh
cd /home/hugo/godot/projects/void_of_exile
G=/home/hugo/godot/engine/godot_voxel_editor
T=/home/hugo/godot/tmp
$G --headless --path . --import

# Offline smoke with screenshots
XDG_DATA_HOME=$T/vr_off $G --path . --resolution 1600x900 res://tools/test_space.tscn -- --shots=$T/space_renders

# Look-development shots (--only=a,b  --hide=NodeName  --ship  --brood)
XDG_DATA_HOME=$T/vr_off $G --path . --resolution 1600x900 res://tools/space_lab.tscn -- --shots=$T/space_renders

# Online: test server (scratch data dir) + client as p2
mkdir -p $T/vr_srv $T/vr_cli
XDG_DATA_HOME=$T/vr_srv $G --headless --path . res://scenes/server/dedicated.tscn -- --port=24987 --test &
SRV=$!; sleep 15
XDG_DATA_HOME=$T/vr_cli $G --path . --resolution 1280x720 res://tools/test_space_online.tscn -- \
  --online=127.0.0.1:24987 --login=p2:12345 --space-test | grep space-online
XDG_DATA_HOME=$T/vr_cli $G --path . --resolution 1280x720 res://tools/test_reach_online.tscn -- \
  --online=127.0.0.1:24987 --login=p2:12345 --space-test | grep reach-online
kill $SRV

# Play the Reach offline
$G --path . -- --play-space
```
