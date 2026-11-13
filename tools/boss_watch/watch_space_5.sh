#!/bin/sh
set -eu
export XDG_DATA_HOME="/home/hugo/.cache/voidrealm-boss-watch/space_5"
exec /home/hugo/Godot/godot_voxel_editor --path /home/hugo/Godot/Projects/VoxelRealms res://tools/boss_watch/space_5.tscn "$@"
