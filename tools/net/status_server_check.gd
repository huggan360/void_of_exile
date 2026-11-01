extends Node
## Account-free localhost fixture; gameplay and replication use the real NetServer.
const DIR := "/home/hugo/tmp/voidrealm_status_network/"
const PORT := 24783
var deadline := 0
var checks := 0
var failures := 0
class Fixture:
	extends NetServer
	func on_hello(peer_id: int, protocol: int, _token: String, character_id: int, account_name: String) -> void:
		if protocol!=Net.PROTOCOL: return
		var stats := PlayerStats.new()
		var pid := GameServer.add_player(stats)
		var p := _new_record(peer_id,character_id,account_name)
		p.player_id = pid
		p.joined = true
		p.realm = "hall"
		p.pos = Vector3(character_id*3,0,0)
		peers[peer_id] = p
		by_player[pid] = peer_id
		GameServer.enter_realm(pid,"hall")
		GameServer.report_position(pid,"hall",p.pos)
		Net.c_welcome.rpc_id(peer_id,{player_id=pid,name=account_name,data=stats.to_data()})
	func _on_peer_left(peer_id: int) -> void:
		if peers.has(peer_id):
			GameServer.remove_player(peers[peer_id].player_id)
			peers.erase(peer_id)
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures+=1; push_error(message)
func wait_for(condition: Callable) -> bool:
	while not condition.call():
		if Time.get_ticks_msec()>deadline: push_error("Status network server timed out"); get_tree().quit(1); return false
		await get_tree().create_timer(.05).timeout
	return true
func mark(name: String) -> void:
	FileAccess.open(DIR+name,FileAccess.WRITE).store_string("ok")
func _ready() -> void: _run.call_deferred()
func _run() -> void:
	deadline = Time.get_ticks_msec()+25000
	var config := ServerConfig.new()
	config.singleplayer = true
	config.global.set_value("server","name","Status fixture")
	config.global.set_value("server","port",PORT)
	config.global.set_value("server","lan_discovery",false)
	config.global.set_value("accounts","server_key","local-fixture")
	Net.server = Fixture.new()
	Net.server.name = "Server"
	Net.mode = Net.Mode.SERVER
	Net.add_child(Net.server)
	check(Net.server.start(config)==OK,"Local fixture listens")
	Net.server.set_process(false)
	mark("ready")
	if not await wait_for(func(): return Net.server.peers.size()==2): return
	# Realm entry now grants a real three-second immunity window.
	await get_tree().create_timer(3.1).timeout
	for p: Dictionary in Net.server.peers.values():
		GameServer.apply_buff(p.player_id,"static",4,1,"fixture")
		GameServer.apply_buff(p.player_id,"quiet",4,1,"fixture")
		GameServer.apply_buff(p.player_id,"speed",12,3,"fixture")
		GameServer.apply_buff(p.player_id,"loot_chance",120,.25,"fixture")
	if not await wait_for(func(): return FileAccess.file_exists(DIR+"observed1") and FileAccess.file_exists(DIR+"observed2")): return
	# Actual server enemy-shot event includes an authorized armour-break impact.
	var source := Node.new()
	source.set_meta("net_realm","hall")
	add_child(source)
	for p: Dictionary in Net.server.peers.values():
		Net.server.enemy_shot(source,p.pos+Vector3(0,1,3),Vector3.FORWARD,
			{speed=5.0,range=6.0,damage_min=0,damage_max=0,effects=[{id="armour_broken",duration="5s"}]},null,1.0)
	if not await wait_for(func(): return FileAccess.file_exists(DIR+"impact1") and FileAccess.file_exists(DIR+"impact2")): return
	for p: Dictionary in Net.server.peers.values():
		check(GameServer.character(p.player_id).buffs.has_effect("armour_broken"),"Projectile effect resolved on server")
	# Clear/re-enter tests require a fresh snapshot even when effect revisions did not change.
	mark("reenter")
	if not await wait_for(func(): return FileAccess.file_exists(DIR+"reentered1") and FileAccess.file_exists(DIR+"reentered2")): return
	for p: Dictionary in Net.server.peers.values(): GameServer.remove_buff(p.player_id,"speed","fixture")
	if not await wait_for(func(): return FileAccess.file_exists(DIR+"removed1") and FileAccess.file_exists(DIR+"removed2")): return
	if not await wait_for(func(): return FileAccess.file_exists(DIR+"expired1") and FileAccess.file_exists(DIR+"expired2")): return
	for p: Dictionary in Net.server.peers.values():
		check(not GameServer.character(p.player_id).buffs.has_effect("static"),"Server expires control effects")
	mark("done")
	await get_tree().create_timer(.3).timeout
	print("STATUS NETWORK SERVER: %d checks, %d failures" % [checks,failures])
	get_tree().quit(1 if failures else 0)
