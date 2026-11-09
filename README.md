# Void Realms

Play Singleplayer or join a multiplayer server from the start screen. Both require a Void Realms account. Singleplayer starts its own local server and saves through the account service.

Linux release: extract the archive and run `./play.sh`.

To build the release, run `./build_linux.sh` with the custom Godot voxel engine and matching Linux release template. Set `GODOT` to override the editor and `OUT_DIR` to choose the archive folder. The export preset contains the local release-template path; update it when building on another machine.

For dedicated hosting, run `./run_server.sh --config=/path/to/server_config`, or launch an exported game with `--headless -- --dedicated --config=/path/to/server_config`. Configure the account-service URL and server key before accepting players. See [server settings](server_config/README.md).

Permanent worlds use local disk caches. Empty worlds sleep; `server.max_memory_mb` controls the budget for unloading empty worlds. It is a soft budget, not an operating-system memory limit.

Spaceship controls have separate sections in Options > Controls. Their keys may overlap on-foot controls; the ship action takes priority while piloting. Defaults: W/S thrust, A/D turn, Up/Down pitch, Q/E roll, Shift boost, C pulse drive, left mouse cannons, X land/dock/descend. The mouse looks around. V changes the seat camera and Z stands up. A grounded pilot launches with Space; flight controls activate after takeoff.
