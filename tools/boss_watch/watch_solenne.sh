#!/bin/sh
set -eu
export XDG_DATA_HOME="/home/hugo/.cache/voidrealm-boss-watch/solenne"
exec /home/hugo/Godot/godot_voxel_editor --path /home/hugo/Godot/Projects/VoxelRealms res://tools/boss_watch/solenne.tscn "$@"
