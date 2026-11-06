#!/bin/sh
set -eu
export XDG_DATA_HOME="/home/hugo/.cache/voidrealm-boss-watch/drowned_cantor"
exec /home/hugo/Godot/godot_voxel_editor --path /home/hugo/Godot/Projects/VoxelRealms res://tools/boss_watch/drowned_cantor.tscn "$@"
