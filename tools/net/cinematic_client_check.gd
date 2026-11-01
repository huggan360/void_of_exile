extends Node3D
const DIR := "/home/hugo/tmp/realm_network_checks/"
var role := 1
var checks := 0
var failures := 0
var deadline := 0
var player: Player
var world: IslandWorld
var cinematic := BossIntroduction.new()
var center: Vector2i
var boss: Boss
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(message)
func mark(name: String) -> void:
	var file := FileAccess.open(DIR+name+str(role),FileAccess.WRITE)
	file.store_string("ok")
func until(condition: Callable) -> bool:
	while not condition.call():
		if Time.get_ticks_msec()>deadline: push_error("Client fixture timed out: "+str(role)); get_tree().quit(1); return false
		await get_tree().create_timer(.05).timeout
	return true
func _ready() -> void:
	Engine.max_fps = 60
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--role="): role = int(arg.trim_prefix("--role="))
	deadline = Time.get_ticks_msec()+120000
	_run.call_deferred()
func _run() -> void:
	var credentials: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DIR+"client%d.json" % role))
	var local_id := GameServer.join(false)
	var stats := GameServer.character(local_id)
	var client := Net.join("127.0.0.1",24675,credentials.token,int(credentials.id),credentials.name)
	client.refused.connect(func(reason: String) -> void: push_error(reason); get_tree().quit(1))
	var info: Dictionary = await client.welcomed
	GameServer.adopt(local_id,int(info.player_id))
	stats.load_data(info.data)
	client.stats = stats
	if role==3: await until(func() -> bool: return FileAccess.file_exists(DIR+"gate_closed"))
	var record := await client.enter("realm_1")
	check(not record.has("error"),"Client enters expanded realm")
	world = IslandWorld.new(record)
	world.enemy_director.remote = true
	add_child(world)
	player = Player.new()
	player.player_id = int(info.player_id)
	player.stats = stats
	add_child(player)
	player.set_physics_process(false)
	player.frozen = false
	var bullets := EnemyBullets.new()
	add_child(bullets)
	bullets.players.assign([player])
	var arrows := Arrows.new()
	add_child(arrows)
	client.attach_world(world,bullets,arrows,player)
	add_child(cinematic)
	for fort in world.generator.strongholds:
		if fort.biome_id==Biomes.DOOM:
			center = fort.center
			player.position = Vector3(center.x+.5+(role-1)*2,fort.base_height+1,center.y+12.5)
	if role==3:
		player.position = world.spawn_point
		check(world.gates.states().size()==1,"Late entrant receives closed-gate state without seeing boss")
		check(not cinematic.visible,"Distant player never gets dragged into cinematic")
		mark("ready")
		await until(func() -> bool: return FileAccess.file_exists(DIR+"reset1"))
		check(world.gates.states().is_empty(),"Distant client receives gate reopening")
		await until(func() -> bool: return not world.gates.states().is_empty())
		await until(func() -> bool: return world.gates.states().is_empty())
		mark("done")
	else:
		await until(func() -> bool:
			for candidate in Boss.all:
				if candidate.def.id=="vharok": boss = candidate; return true
			return false)
		await get_tree().create_timer(.8).timeout
		mark("ready")
		await until(func() -> bool: return FileAccess.file_exists(DIR+"ready1") and FileAccess.file_exists(DIR+"ready2"))
		if role==1:
			while boss.state!=Enemy.State.INTRO:
				Net.s_action.rpc_id(1,"hit",[boss.net_id,10,Vector3.FORWARD])
				await get_tree().create_timer(.06).timeout
		await until(func() -> bool: return cinematic.visible)
		check(player.cinematic_locked and cinematic._camera.current,"Participant gets cinematic camera and input lock")
		check(player.player_id in boss.intro_players,"Personal intro admission decoded from actual server snapshots")
		check(cinematic._name.text=="Vharok, the Cinder Tyrant","Correct boss name in cinematic")
		var before := cinematic._camera.global_position
		await get_tree().create_timer(1.6).timeout
		check(cinematic._camera.global_position.distance_to(before)>.1,"Network-driven cinematic camera moves")
		await until(func() -> bool: return world.gates.states().size()==1)
		check(world.gates.entries[center].locked,"Gate closure arrives as a network event")
		if role==1:
			var anchor := player.global_position
			Net.s_move.rpc_id(1,anchor+Vector3(5,0,0),0.0,1.0,0)
			await get_tree().create_timer(.4).timeout
			check(player.global_position.distance_to(anchor)<.2,"Server corrects movement attempted during intro")
		await until(func() -> bool: return boss.state==Enemy.State.ACTIVE)
		await get_tree().process_frame
		check(not player.cinematic_locked and not cinematic.visible and player.camera.current,"Both clients return to normal camera and controls")
		check(boss.max_hp==1200,"Two-player boss HP matches server")
		mark("active")
		await until(func() -> bool: return boss.state==Enemy.State.IDLE and world.gates.states().is_empty())
		check(not player.cinematic_locked,"Reset clears presentation/input state")
		mark("reset")
		await until(func() -> bool: return boss.state==Enemy.State.INTRO and boss.intro_serial==2)
		await until(func() -> bool: return cinematic.visible)
		check(player.cinematic_locked,"A retry plays its new intro")
		await until(func() -> bool: return boss.state==Enemy.State.DYING and world.gates.states().is_empty())
		await get_tree().process_frame
		check(not player.cinematic_locked and not cinematic.visible,"Death cancels camera and reopens gates on client")
		mark("done")
	await until(func() -> bool: return FileAccess.file_exists(DIR+"server_done"))
	cinematic.clear_world()
	Net.leave()
	print("NETWORK CLIENT %d: %d checks; %d failures" % [role,checks,failures])
	get_tree().quit(1 if failures else 0)
func _process(delta: float) -> void:
	if not is_instance_valid(player) or not is_instance_valid(world): return
	GameServer.report_position(player.player_id,world.realm_id,player.global_position)
	cinematic.update(player,world,delta,true)
