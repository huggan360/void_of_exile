extends Node
const DIR := "/home/hugo/tmp/realm_network_checks/"
var failures := 0
var checks := 0
var deadline := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(message)
func mark(name: String) -> void:
	var file := FileAccess.open(DIR+name,FileAccess.WRITE)
	file.store_string("ok")
func until(condition: Callable) -> bool:
	while not condition.call():
		if Time.get_ticks_msec()>deadline: push_error("Server fixture timed out"); get_tree().quit(1); return false
		await get_tree().create_timer(.05).timeout
	return true
func _ready() -> void:
	deadline = Time.get_ticks_msec()+120000
	add_child((load("res://scenes/server/dedicated.tscn") as PackedScene).instantiate())
	_run.call_deferred()
func _run() -> void:
	await until(func() -> bool: return Net.server!=null)
	GameServer.debug_godmode = true
	mark("server_ready")
	await until(func() -> bool: return FileAccess.file_exists(DIR+"ready1") and FileAccess.file_exists(DIR+"ready2"))
	var boss: Boss
	await until(func() -> bool:
		return Net.server.enemies.values().any(func(e: Enemy) -> bool: return e.def.id=="vharok" and e.state==Enemy.State.INTRO))
	for enemy: Enemy in Net.server.enemies.values():
		if enemy.def.id=="vharok": boss = enemy as Boss
	check(boss!=null and boss.intro_players.size()==2,"Both network participants admitted by server")
	GameServer.debug_godmode = false
	for id: int in boss.intro_players:
		var hp := GameServer.character(id).hp
		GameServer.hit_player(id,5000,true)
		check(GameServer.character(id).hp==hp and GameServer.intro_locked(id),"Server rejects lethal damage during cinematic without godmode")
	var world := boss.director.world as IslandWorld
	var center := world.gates.center_for(boss.global_position)
	await until(func() -> bool: return world.gates.entries[center].locked)
	check(world.gates.states().size()==1,"Only active fortress gates close")
	mark("gate_closed")
	await until(func() -> bool: return FileAccess.file_exists(DIR+"ready3"))
	await until(func() -> bool: return FileAccess.file_exists(DIR+"active1") and FileAccess.file_exists(DIR+"active2"))
	check(boss.state==Enemy.State.ACTIVE and boss.players_counted==2,"Authoritative fight starts with two-player health scaling")
	check(boss.max_hp==1200,"Actual server max HP uses participating player count")
	GameServer.debug_godmode = true
	boss.reset_attempt()
	await until(func() -> bool: return FileAccess.file_exists(DIR+"reset1") and FileAccess.file_exists(DIR+"reset2"))
	check(not world.gates.entries[center].locked,"Reset opens authoritative gates")
	boss._hatch()
	await until(func() -> bool: return world.gates.entries[center].locked)
	await get_tree().create_timer(.5).timeout
	boss._start_dying()
	await until(func() -> bool: return FileAccess.file_exists(DIR+"done1") and FileAccess.file_exists(DIR+"done2") and FileAccess.file_exists(DIR+"done3"))
	check(not world.gates.entries[center].locked,"Death opens authoritative gates")
	mark("server_done")
	await get_tree().create_timer(.3).timeout
	print("NETWORK SERVER: %d checks; %d failures" % [checks,failures])
	get_tree().quit(1 if failures else 0)
