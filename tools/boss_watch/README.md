# Watch the five boss fights

These viewers run the current real encounters automatically, from shell cracking through all phases and the final death burst. They do not change boss patterns, health, helper health or gameplay definitions.

Open one scene in Godot and press **F6**:

- `blue.tscn` — Blue Dragon
- `frost.tscn` — Rimeheart Prism
- `lava.tscn` — Vharok
- `desert.tscn` — Scarab Regent
- `dark.tscn` — Hollow Crown

Alternatively, launch the corresponding executable `.sh` file here, or use the launchers in `~/Desktop/Boss Fight Watchers/`.

The account/login screen is bypassed. Shells take steady damage, then the real hatch intro runs. The camera stays wide above the courtyard. A moving, invulnerable player gives the attacks something to aim at. The boss loses roughly 1/90 of its maximum HP per second while vulnerable, and each living encounter helper loses roughly 1/18 per second. Normal defense, immunity, healing, objectives, phase thresholds and scripted delays still apply, so guarded phases take longer. Unrelated wilderness enemies are removed from the preview.

**P or Space:** pause/resume the entire simulation. **D:** toggle automatic damage to study a phase for as long as you want. **R:** restart this viewer from a fresh shell. **Escape:** close. The viewer stays open after the boss dies.

Preview launchers use their own XDG data folders. Preview realm records are also kept in a separate `user://boss_watch/` directory and reset on replay. They do not use online accounts or edit normal realm progress.

Command-line alternative:

`godot --path /home/hugo/Godot/Projects/VoxelRealms -- --watch-boss=blue`

Valid keys: `blue`, `frost`, `lava`, `desert`, `dark`.

Implemented as visual-review scripts only. Not run or tested in this pass, as requested.

## Dungeon court previews

`gilded_vizier.tscn`, `magma_warden.tscn` and `pyre_ent.tscn` use the real dungeon boss definitions in an existing desert/lava stronghold arena. Launch `watch_gilded_vizier.sh`, `watch_magma_warden.sh` or `watch_pyre_ent.sh` here or from `~/Desktop/Boss Fight Watchers/`. Each launcher isolates its user data. These viewers stay offline, bypass login, and remove unrelated wilderness enemies. Controls match the realm viewers above.

For an automatic preview exit, pass `-- --watch-seconds=115`; add `--shots` for phase screenshots in `/tmp/<boss>_phase_<n>.png`. All three encounters were checked through phase 3 headlessly; the Ent was also viewed with the Vulkan renderer.

Runtime definitions and loot: `scripts/enemies/court_enemies.gd`. Source art: `tools/make_court_creatures.py`; editable boss masters are in each creature's `source_32/` folder. `BossDef.follow_up` exposes the Warden's 50% encore portal rule to the dungeon server.

## Astral Reach previews (space_1 to space_6)

`space_<n>.tscn` (driver `space_watcher.gd`) load the offline Reach (`--play-space`) and watch a Reach boss in its real
fortress: space_1 Queen Briarrose, space_2 Aurum, space_3 Selenarch, space_4 Brood Matriarch, space_5 Vaelith,
space_6 the Veiled Herald (the Veiled Shrine on Shardheart). Launch `watch_space_<n>.sh` here or `space_<n>` in
`~/Desktop/Boss Fight Watchers/`. Same controls and auto damage as the others; Vaelith's arms take a share of the
damage while they lie on the ground. `-- --watch-seconds=<s>` closes it after that long.
