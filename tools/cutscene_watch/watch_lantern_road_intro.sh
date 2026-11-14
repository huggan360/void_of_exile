#!/bin/sh
# Cutscene viewer: isolated preview data; no account/login required.
set -eu
export XDG_DATA_HOME="/home/hugo/.cache/voidrealm-cutscene-watch/lantern_road_intro"
exec /home/hugo/Godot/godot_voxel_editor --path /home/hugo/Godot/Projects/VoxelRealms -- --watch-cutscene=lantern_road_intro
