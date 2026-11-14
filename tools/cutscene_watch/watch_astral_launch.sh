#!/bin/sh
# Cutscene viewer: isolated preview data; no account/login required.
set -eu
export XDG_DATA_HOME="/home/hugo/.cache/voidrealm-cutscene-watch/astral_launch"
exec /home/hugo/Godot/godot_voxel_editor --path /home/hugo/Godot/Projects/VoxelRealms -- --watch-cutscene=astral_launch
