# Developing Void of Exile

## Machine

| What | Where |
| --- | --- |
| Project | `~/Godot/Projects/VoxelRealms` (github.com/huggan360/void_of_exile, public) |
| Engine | `~/Godot/godot_voxel_editor`: Godot 4.7.2 with the voxel module, self-contained (editor data in `~/Godot/editor_data`) |
| Linux release template | `~/Godot/templates/godot.linuxbsd.template_release.x86_64` |
| Account server and website | `~/Godot/Projects/void_of_exile_account` |
| Launcher | `~/Godot/Projects/void_of_exile_launcher` |
| Pi (accounts, website, release store) | `hugohansson@192.168.1.5` |

## Ground rules

- Work and commit on `main`. Push only when asked. Take a copy into `~/tmp/voidrealm_before_<task>_<time>`
  before big edits.
- Never write the middle dot (U+00B7) or the bullet glyph (U+2022) anywhere: text, comments, docs. Use "-".
- The UI uses Bree Serif and the black stone set (`assets/ui/black`, `UIStyle`). World art is voxel and
  fairytale: reuse `ObstacleLibrary`, `obstacles/*.vox` and props before making new primitives.
- Space is huge: Reach content streams by distance with LOD copies; nothing is built up front.
- Online tests use account `p2` (`--login=p2:12345`), never `p1`. Kill only the server you started.
- Testing stays light: an `--import` parse check, and one scripted run for networked changes. Hugo does the
  visual testing (boss watchers on the Desktop, playing).
- Releases follow `docs/RELEASING.md`.

## Commands

```sh
cd ~/Godot/Projects/VoxelRealms
G=~/Godot/godot_voxel_editor

# Parse check. New class_name scripts are only visible after this.
$G --headless --path . --import

# Play
$G --path .                      # start menu
$G --path . -- --play-space      # straight into the Astral Reach, offline

# Online: a test server with its own data dir, then a client as p2
mkdir -p ~/tmp/vr_srv ~/tmp/vr_cli
XDG_DATA_HOME=~/tmp/vr_srv $G --headless --path . res://scenes/server/dedicated.tscn -- --port=24987 --test &
SRV=$!; sleep 15
XDG_DATA_HOME=~/tmp/vr_cli $G --path . main.tscn -- --online=127.0.0.1:24987 --login=p2:12345
kill $SRV
```

`--test` keeps the server from saving characters. To test against your own account service instead, run a
copy of `void_accounts.py` from the account repo on port 18095 and start the server with
`--accounts=http://127.0.0.1:18095 --key=<server key>` (without `--test`).

## Checks worth knowing

| Scene | What it checks |
| --- | --- |
| `tools/surface/check_surface.tscn` | Surface plan, voxel blocks, trees, ground cover and water, with timings |
| `tools/space/check_layout.tscn`, `tools/space/check_planet_art.tscn` | Planet spots and overlaps, every planet's art built headless |
| `tools/test_space.tscn`, `tools/test_space_online.tscn`, `tools/test_reach_online.tscn` | The Reach offline and online |
| `tools/test_planet_boss.tscn`, `tools/test_planet_combat.tscn` | Planet fortresses and aiming |
| `tools/test_theory.tscn` | Theory of Everything |
| `tools/boss_watch/watch_*.sh` | Watch a boss fight live |

## Content tools

| Tool | Makes |
| --- | --- |
| `tools/surface/make_surface_models.py`, then `tools/surface/bake_surface.py` | The Surface (see `docs/WORLD.md`) |
| `tools/space/make_planet_models.py` | Planet flora, towns, landing pads, Nexus pieces |
| `tools/make_*.py` | Creature, boss and prop models (`creatures/`, `props/`, `obstacles/`) |
| `tools/import_textures.py` | Item icons from the Pixelorama sources |
| `tools/surface/cinematic_shot.tscn` | HUD-free stills for release covers |
| `tools/export_review_catalog.tscn`, `tools/export_wiki_media.tscn`, `tools/web/build_site_data.py` | Wiki data for the website (see `tools/REVIEW_WIKI.md`) |

Run model tools before `--import`; the editor picks up new `.vox` files on import.
