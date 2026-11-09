extends Node
## The dedicated server (run headless, see run_server.sh):
##
##     godot --headless --path <project> res://scenes/server/dedicated.tscn -- [--config=<folder>] [--port=N]
##         [--name=NAME] [--accounts=URL]   (override server.cfg for this run)
##         [--set=section.key=value]   any server.cfg value, e.g. --set=gameplay.player_collision=true
##         [--singleplayer --key=SP_KEY --parent=PID]   run by the game for Singleplayer;
##         quits when the game (PID) is gone
##
## Loads the config folder (ServerConfig: server.cfg and the json files),
## puts its values into the game's definitions, builds every creature once,
## and opens the server (NetServer). Realms open as players arrive.

var _parent_pid := 0
var _watch := 0.0
var _alone := 0.0


func _ready() -> void:
	Engine.max_fps = 60
	var args := {}
	var sets: Array = []
	for arg in OS.get_cmdline_user_args():
		var parts := arg.trim_prefix("--").split("=", true, 1)
		args[parts[0]] = parts[1] if parts.size() > 1 else ""
		if parts[0] == "set" and parts.size() > 1:
			sets.append(parts[1])
	var config := ServerConfig.load_from(args.get("config", ""))
	for entry: String in sets:  # --set=gameplay.player_collision=true
		var kv := entry.split("=", true, 1)
		var key := kv[0].split(".", true, 1)
		if kv.size() == 2 and key.size() == 2:
			config.global.set_value(key[0], key[1], str_to_var(kv[1]) if str_to_var(kv[1]) != null else kv[1])
	if args.has("port"):
		config.global.set_value("server", "port", int(args.port))
	if args.has("name"):
		config.global.set_value("server", "name", args.name)
	if args.has("accounts"):
		config.global.set_value("accounts", "url", args.accounts)
	if args.has("key"):
		config.global.set_value("accounts", "server_key", args.key)
	if args.has("singleplayer"):
		# Started by the game for Singleplayer: one player, its own realms, not announced.
		config.singleplayer = true
		config.global.set_value("server", "max_players", 1)
		config.global.set_value("server", "lan_discovery", false)
		config.global.set_value("server", "name", "Singleplayer")
		config.global.set_value("server", "data_dir", ProjectSettings.globalize_path("user://singleplayer"))
		# Quick to start, and gentle on the player's own computer: worlds load on
		# the first visit and stay, within a memory budget.
		config.global.set_value("realms", "preload", false)
		config.global.set_value("server", "max_memory_mb", 1500)
		_parent_pid = int(args.get("parent", "0"))
	config.apply()
	print("[server] config: %s  data: %s" % [config.dir, config.data_dir()])
	var started := Time.get_ticks_msec()
	for id in Enemies.all_ids():
		CreatureModel.preload_creature(Enemies.get_def(id).model)
	print("[server] creatures ready in %.1f s" % ((Time.get_ticks_msec() - started) / 1000.0))
	if Net.host(config) != OK:
		get_tree().quit(1)


func _process(delta: float) -> void:
	if _parent_pid <= 0:
		return
	_alone += delta
	if Net.server and Net.server.player_count() > 0:
		_alone = 0.0
	elif _alone > 90.0:  # nobody came (or came back)
		print("[server] nobody joined: stopping the singleplayer server")
		_parent_pid = 0
		get_tree().quit()
		return
	_watch -= delta
	if _watch <= 0.0:
		_watch = 2.0
		if not _parent_alive():
			print("[server] the game closed: stopping the singleplayer server")
			_parent_pid = 0
			await Net.server.save_all()
			get_tree().quit()


## Whether the game that started us still runs (Linux: /proc; elsewhere the
## server relies on the player's connection dropping).
func _parent_alive() -> bool:
	if DirAccess.dir_exists_absolute("/proc/self"):
		return DirAccess.dir_exists_absolute("/proc/%d" % _parent_pid)
	return true
