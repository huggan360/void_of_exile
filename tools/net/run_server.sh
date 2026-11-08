#!/bin/sh
# Starts the Void Realms dedicated server (headless).
#   tools/net/run_server.sh [--config=/path/to/config_folder] [--port=24565]
# Config defaults to <project>/server_config (written on first start).
PROJECT="$(cd "$(dirname "$0")/../.." && pwd)"
# Defaults: the voxel engine and server data under ~/godot (everything in one place).
GODOT="${GODOT:-$HOME/godot/engine/godot_voxel_editor}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/godot/server_data}"
exec "$GODOT" --headless --path "$PROJECT" res://scenes/server/dedicated.tscn -- "$@"
