extends "res://scripts/main.gd"
## Offline Hollow Empress viewer in the real Convergence arena (Theory of Everything).
func _parse_args() -> void:
	super._parse_args()
	_args.erase("online")
	_args["play-dungeon"] = "theory_of_everything"

func _ready() -> void:
	GameServer.debug_godmode = true
	super._ready()
	var viewer = load("res://tools/boss_watch/void_empress_watcher.gd").new()
	viewer.game = self
	add_child(viewer)
