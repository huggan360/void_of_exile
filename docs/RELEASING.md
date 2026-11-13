# Releasing Void of Exile

A release goes from a commit on `main` to every player's launcher in one command.

```
main (committed)  ->  tools/release/publish.sh  ->  GitHub release v<version> (game)
                                                 +->  GitHub release v<version> in void_of_exile_server
                                                         |
                       Pi: void-release-sync.timer (every 5 min)
                                                         |
   /srv/void/game/<platform>  +  chunk store (game and server)  +  website wiki
                     +  /launcher/v1/latest (game)  +  /launcher/v1/server (server)
                                                         |
                         launcher: downloads only the chunks that changed
```

## Rules for prod

1. **Only Hugo decides when something goes to prod.** Nobody runs `publish.sh`, tags a release or deploys the
   website or account server without being asked to.
2. **Prod is built from committed `main`, never from the working tree.** `publish.sh` builds `HEAD` in a clean
   worktree, so uncommitted work never ships. Commit what should ship first. Never commit someone else's
   unfinished work just to get it into a release.
3. **One version, one meaning.** A new release gets a new version in `release/release.json`. Re-publishing the
   same version (`--replace`) is only for rebuilding the same content (a fix, new art, a wrong build), and
   launchers then update to it as a new build.
4. **The game must start before it ships.** At least: `--import` with no script errors, start the game, log in,
   enter the Tavern and the Surface. Online changes: one run against a local dedicated server (see
   `docs/DEVELOPING.md`).
5. **Protocol and save changes go with the release.** `Net.VERSION` (`scripts/net/net.gd`) is the release
   version and must equal `release/release.json` (`publish.sh` refuses otherwise); bump `Net.PROTOCOL` when
   clients and servers no longer understand each other. If world coordinates or saved world state changed, bump
   `WorldServer.LAYOUT_VERSION`. Restart the dedicated servers after the release so they run the same build.
6. **The account server goes first.** If the new game needs new account endpoints, deploy the account server
   (`void_of_exile_account`: `deploy/deploy.sh accounts`) before publishing the game, and keep it working for
   the game version that is live now.
7. **Only game files ship.** The export excludes `tools/`, `docs/`, `server_config/`, `release/`, staging art and
   tests. Never add secrets, server keys or databases to the repo (`server_config/` is git-ignored).
8. **Notes are short and plain.** A few short lines, no middle dots or bullet glyphs, no marketing words.
   The cover is a real in-game shot.

## Release step by step

1. Commit everything that should ship to `main`, then check it imports cleanly:

   ```sh
   ~/Godot/godot_voxel_editor --headless --path . --import
   ```

2. Set the version, title and notes in `release/release.json`:

   ```json
   {
     "version": "26.1-beta",
     "title": "Short title",
     "date": "2026-12-01",
     "notes": ["One short line per change"]
   }
   ```

   Versions are `<year>.<number>` with `-beta` while in beta: `26.0-beta`, `26.1-beta`, `26.1.1-beta` for a hotfix.

3. Replace `release/cover.png` (1600 x 900) if the release deserves a new image. Cinematic stills of the Surface:

   ```sh
   ~/Godot/godot_voxel_editor --path . --resolution 2560x1440 res://tools/surface/cinematic_shot.tscn -- \
     --shots=$HOME/tmp/shots --first=0 --count=2 --angles=3 --seed=11
   ```

   `--first` picks the village (forts follow the villages), `--seed` the camera angles.

4. Commit `release/`, push `main`, and publish:

   ```sh
   git add release && git commit -m "Release 26.1-beta" && git push origin main
   tools/release/publish.sh --now
   ```

   It builds the Linux export, packs the game and the same files as `VoidOfExileServer`, exports the wiki data
   (a Godot window opens for a few seconds to render models), tags `v<version>` and creates the game release
   here and the server release in `huggan360/void_of_exile_server`. `--now` makes the Pi sync at once instead
   of within five minutes. The server shares the game's chunks in the store, so hosting costs players almost
   no extra download.

5. Check that it is live:

   ```sh
   curl -s https://void.plainshow.se/launcher/v1/latest | python3 -m json.tool | head
   ssh hugohansson@192.168.1.5 'journalctl -u void-release-sync -n 5 --no-pager -o cat'
   ```

   Open the launcher: it shows the new cover and notes and offers UPDATE.

### Other publish options

| Command | Use |
| --- | --- |
| `publish.sh --build-only` | Build and pack into `~/tmp/void_release` without publishing |
| `publish.sh --replace --now` | Publish the same version again as a new build |

## Launcher releases

Repo `huggan360/void_of_exile_launcher` (stock Godot 4.7.2). Bump the version in `scripts/launcher.gd`
(`VERSION`), `project.godot` and `export_presets.cfg`, commit, then:

```sh
git tag -a v1.1.0 -m "Launcher 1.1.0" && git push origin main v1.1.0
```

GitHub Actions builds Linux, Windows and macOS and attaches the zips; the website's download buttons always
point at the newest launcher release. `./build.sh <godot> Linux` builds locally.

## Website and account server

Repo `huggan360/void_of_exile_account` (private). From its root:

| Command | What |
| --- | --- |
| `deploy/deploy.sh site` | Build the Laravel site on the Pi and switch to it (keeps the last 3 builds) |
| `deploy/deploy.sh accounts` | Deploy `server/void_accounts.py` (backs up the old one first) |
| `deploy/deploy.sh sync` | Deploy the release sync tool and sync now |

The wiki on the website comes from the game release (`wiki.tar.gz`), so it refreshes with every game release.

## Rolling back

Revert the bad commits on `main`, then publish a new version (or `--replace` the same one). Launchers rebuild
their files from chunks they already have, so going back is quick. The Pi keeps the chunks of the last four
releases.

## Where things are

| What | Where |
| --- | --- |
| Release metadata | `release/release.json`, `release/cover.png` |
| Publish script | `tools/release/publish.sh` |
| Wiki data export | `tools/web/build_site_data.py`, `tools/export_review_catalog.tscn`, `tools/export_wiki_media.tscn` |
| Release store on the Pi | `/srv/void/files/game` (`latest.json`, `manifests/`, `chunks/`), served at `/files/game/` |
| The Pi's own game copy | `/srv/void/game/<platform>` (updated in place on every release) |
| Sync tool | `void_of_exile_account/server/void_release.py`, systemd `void-release-sync.timer` |
| Launcher API | `GET https://void.plainshow.se/launcher/v1/latest`, `/launcher/v1/releases`, `/launcher/v1/server` |
| Server releases | `huggan360/void_of_exile_server` (`server-latest.json`, `manifests/server-*` in the store) |

## Limits

- The game uses a custom Godot build with the voxel module, and only a Linux release template exists, so only
  `linux-x86_64` is published. Windows and macOS launchers show "Soon" until those templates are built.
- The macOS launcher is ad-hoc signed and not notarized.
