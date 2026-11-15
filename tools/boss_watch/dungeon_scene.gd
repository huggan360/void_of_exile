extends "res://scripts/main.gd"
## Offline preview of a dungeon's boss fight in its own generated dungeon.
@export var watched_dungeon := "afterlife"

func _parse_args() -> void:
	super._parse_args()
	_args.erase("online")
	_args["watch-dungeon"] = watched_dungeon
