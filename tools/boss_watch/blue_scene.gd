extends "res://scripts/main.gd"
## Offline previews borrow an existing stronghold arena, without account access.
@export_enum("abyssal_siren", "drowned_cantor") var watched_boss := "abyssal_siren"

func _parse_args() -> void:
	super._parse_args()
	_args.erase("online")
	_args["watch-boss"] = "blue"

func _ready() -> void:
	super._ready()
	for child in get_children():
		if child.get_script() == load("res://tools/boss_watch/fight_watcher.gd"):
			child.game = null
			remove_child(child)
			child.free()
	var viewer = load("res://tools/boss_watch/court_watcher.gd").new()
	viewer.game = self
	viewer.key = _args["watch-boss"]
	viewer.watched_boss = watched_boss
	add_child(viewer)
