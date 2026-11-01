extends "res://scripts/main.gd"
## F6 opens this boss directly, with no account/server needed.
@export_enum("blue","frost","lava","desert","dark") var watched_boss := "blue"
func _parse_args() -> void:
	super._parse_args()
	_args["watch-boss"] = watched_boss
