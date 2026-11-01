extends Node3D
const DIR := "/home/hugo/tmp/voidrealm_status_network/"
var role := 1
var deadline := 0
var checks := 0
var failures := 0
var client: NetClient
var player: Player
var world: GameWorld
var bullets: EnemyBullets
var arrows: Arrows
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures+=1; push_error(message)
func mark(name: String) -> void:
	FileAccess.open(DIR+name+str(role),FileAccess.WRITE).store_string("ok")
func wait_for(condition: Callable) -> bool:
	while not condition.call():
		if Time.get_ticks_msec()>deadline: push_error("Status network client timed out "+str(role)); get_tree().quit(1); return false
		await get_tree().create_timer(.05).timeout
	return true
func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--role="): role = int(arg.trim_prefix("--role="))
	_run.call_deferred()
func _run() -> void:
	deadline = Time.get_ticks_msec()+25000
	var old_id := GameServer.join(false)
	var stats := GameServer.character(old_id)
	client = Net.join("127.0.0.1",24783,"fixture",role,"StatusPlayer%d" % role)
	client.refused.connect(func(reason): push_error(reason);get_tree().quit(1))
	var info: Dictionary = await client.welcomed
	GameServer.adopt(old_id,info.player_id)
	stats.load_data(info.data)
	client.stats = stats
	world = GameWorld.new()
	world.realm_id = "hall"
	add_child(world)
	player = Player.new()
	player.player_id = info.player_id
	player.stats = stats
	add_child(player)
	player.set_physics_process(false)
	player.frozen = false
	player.position = Vector3(role*3,0,0)
	bullets = EnemyBullets.new()
	add_child(bullets)
	bullets.players.assign([player])
	arrows = Arrows.new()
	add_child(arrows)
	client.attach_world(world,bullets,arrows,player)
	if not await wait_for(func(): return stats.buffs.has_effect("static") and client._remote.size()==1): return
	var other: RemotePlayer = client._remote.values()[0]
	if not await wait_for(func(): return other.buffs.has_effect("loot_chance")): return
	check(other.status_visuals.player_name=="StatusPlayer%d" % (2 if role==1 else 1),"Remote player name arrives")
	check(stats.total("speed")==stats.base.speed+stats.gear_bonus("speed")+3,"Own replicated stat changes gameplay")
	check(other.buffs.has_effect("static") and other.buffs.has_effect("quiet"),"Other player's effects arrive over ENet")
	check(other.status_visuals._ice.visible,"Remote ice presentation follows network state")
	var start := player.position
	Net.s_move.rpc_id(1,start+Vector3(3,0,0),0.0,1.0,0)
	Net.s_shot.rpc_id(1,start+Vector3.UP,Vector3.FORWARD,stats.gear.weapon.id,0.0,{})
	await get_tree().create_timer(.35).timeout
	check(player.position.distance_to(start)<.1,"Server rejects movement while Static")
	check(arrows._shots.is_empty(),"Server refuses weapon shots during Quiet")
	check(not GameServer.apply_buff(player.player_id,"loot_chance",120,1.0),"Client cannot grant itself a gameplay buff")
	mark("observed")
	if not await wait_for(func(): return stats.buffs.has_effect("armour_broken")): return
	check(stats.total("defense")==stats.base.defense,"Real projectile applies Armour Broken")
	mark("impact")
	if not await wait_for(func(): return FileAccess.file_exists(DIR+"reenter")): return
	var record := await client.enter("hall")
	client.attach_world(world,bullets,arrows,player)
	check(record.id=="hall","Re-entry succeeds")
	if not await wait_for(func(): return client._remote.size()==1): return
	other = client._remote.values()[0]
	if not await wait_for(func(): return other.buffs.has_effect("loot_chance")): return
	check(other.buffs.has_effect("speed"),"Newly created remote mirror receives unchanged effects on re-entry")
	mark("reentered")
	if not await wait_for(func(): return not stats.buffs.has_effect("speed") and not other.buffs.has_effect("speed")): return
	check(not stats.buffs.has_effect("speed") and not other.buffs.has_effect("speed"),"Removal reaches owner and other observer")
	mark("removed")
	if not await wait_for(func(): return not stats.buffs.has_effect("static") and not other.buffs.has_effect("static")): return
	check(not stats.buffs.has_effect("quiet") and not other.buffs.has_effect("quiet"),"Timed expiry reaches owner and observer")
	mark("expired")
	if not await wait_for(func(): return FileAccess.file_exists(DIR+"done")): return
	print("STATUS NETWORK CLIENT %d: %d checks, %d failures" % [role,checks,failures])
	get_tree().quit(1 if failures else 0)
