extends "res://scripts/main.gd"
## Offline viewers for the Astral Reach's bosses, in their real fortresses,
## without account access.
@export_enum("space_1", "space_2", "space_3", "space_4", "space_5", "space_6") var watched_boss := "space_1"

func _parse_args() -> void:
	super._parse_args()
	_args.erase("online")
	_args["play-space"] = true

func _ready() -> void:
	GameServer.debug_godmode = true
	super._ready()
	var viewer = load("res://tools/boss_watch/space_watcher.gd").new()
	viewer.game = self
	viewer.key = watched_boss
	add_child(viewer)
