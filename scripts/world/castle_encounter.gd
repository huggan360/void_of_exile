extends Node3D
## Authority owns progression, inventory and actors. Clients only replay castle events.
signal king_defeated(realm_id: String)
const DOOR := Vector3(0, 0, -29)
const GATE_Z := 13.0
var world: CastleWorld
var stage := 0 # entrance, knights, champions, key, throne intro, king, complete
var _pack := EnemyPack.new()
var _living: Array[Enemy] = []
var king: Boss
var _gate: StaticBody3D
var _door: StaticBody3D
var _holes: Array[Node3D] = []
var _target: InteractionTarget
var _seen: Array = []
var _last_positions := {}
var _camera: Camera3D
var _prior_camera: Camera3D
var _camera_tween: Tween
var _cut_serial := 0
var _cut_player: Player
var _prior_lock := false
var _seated: CreatureModel
var _hidden_gui: Array[CanvasLayer] = []
var _cut_audio := {}

func _process(_delta: float) -> void:
	if is_instance_valid(_camera): _hide_gui(get_tree().root)

func _hide_gui(node: Node) -> void:
	if node is CanvasLayer and node.get_viewport() == get_viewport() and node.visible:
		if not node in _hidden_gui: _hidden_gui.append(node)
		node.hide()
	for child in node.get_children(): _hide_gui(child)

func _ready() -> void:
	_pack.site = {id = "castle_encounter", pack = "", pos = Vector3(0, 0, -8), seed = 4107}
	_pack.respawn_time = -1.0
	_gate = _barrier(Vector3(0, 0, GATE_Z), 12.0, 8.0, true)
	_gate.position.y = 9.0
	_gate.collision_layer = 0
	_door = _barrier(DOOR, 16.0, 11.0, false)
	for side in [-1.0, 1.0]:
		var plug := Node3D.new()
		plug.position = Vector3(side * 23, 0, -9)
		add_child(plug)
		for y in 6:
			for z in 6:
				_box(plug, Vector3(0, y + 0.5, z - 2.5), Vector3(2, 1, 1), Color("474954"), true)
		_holes.append(plug)
	_target = InteractionTarget.new()
	_target.title = "The Throne Room"
	_target.description = "An iron door seals the last king's throne."
	_target.action_text = "Use the Throne Key"
	_target.reach = 8.0
	_target.difficulty = 8.0
	_target.enabled = false
	_target.position = DOOR + Vector3(0, 0, 2.0)
	_target.activated.connect(func(player: Node3D) -> void:
		if Net.is_client(): Net.client.send_action("castle", ["door"])
		else: on_action({player_id = player.player_id, realm = world.realm_id, pos = player.global_position}, ["door"]))
	add_child(_target)
	_seated = CreatureModel.new("hollow_king")
	_seated.position = CastleWorld.THRONE_SEAT
	_seated.scale = Vector3.ONE * 0.85
	_seated.rotation.y = PI
	add_child(_seated)
	_seated.boss_pose("sit", 86400.0)
	_seated.animate(0.0,2.0)  # Show the seated pose on the first visible frame.

func _physics_process(delta: float) -> void:
	if is_instance_valid(_seated) and _seated.visible: _seated.animate(0.0, delta)
	if Net.is_client() or world.enemy_director.bullets == null: return
	var players := world.enemy_director.players
	if players.is_empty(): return
	if Net.is_server():
		var ids: Array = []
		for peer: Dictionary in Net.server.peers.values():
			if peer.get("realm", "") != world.realm_id or peer.get("dead", false): continue
			ids.append(peer.player_id)
			var pos: Vector3 = peer.pos
			var previous: Vector3 = _last_positions.get(peer.player_id, pos)
			# NetServer only checks IslandWorld gates; this realm validates its own barriers.
			if _crosses_closed(previous, pos) or (stage < 4 and pos.z < -30) or (stage > 0 and pos.z > GATE_Z + 1):
				var safe := previous if not blocks_point(previous) and previous.z < GATE_Z else Vector3(0, 0, 7)
				if stage < 4 and safe.z < -28: safe = Vector3(0, 0, -24)
				_warp(peer.player_id, safe)
				pos = safe
			_last_positions[peer.player_id] = pos
		if ids != _seen:
			_seen = ids
			broadcast("state", [stage])
	if stage == 0:
		for player in players:
			if is_instance_valid(player) and not player.frozen and player.global_position.z < 11:
				_start_guardians()
				break

func _crosses_closed(a: Vector3, b: Vector3) -> bool:
	return (stage > 0 and (a.z - GATE_Z) * (b.z - GATE_Z) < 0) or (stage < 4 and (a.z + 29) * (b.z + 29) < 0)

func blocks_point(pos: Vector3) -> bool:
	return (stage > 0 and absf(pos.z - GATE_Z) < 0.8 and absf(pos.x) < 6.5) or (stage < 4 and absf(pos.z + 29) < 0.9 and absf(pos.x) < 8.5)

func broadcast(kind: String, args: Array = []) -> void:
	var event: Array = ["castle", kind]
	event.append_array(args)
	world.castle_event(event)
	if Net.is_server(): Net.server._to_realm(world.realm_id, Vector3.INF, event)

func _start_guardians() -> void:
	stage = 1
	_gather(Vector3(0, 0, 5), 5.0, true)
	broadcast("gate_close")
	_spawn_pair("castle_knight", -7.0)
	for actor in _living:
		actor.behavior = "stationary"
		actor.attack_lock = 4.5
		actor.model.boss_pose("kneel", 2.5)
	broadcast("cutscene", ["guardians", 4.0])
	await get_tree().create_timer(2.5).timeout
	for actor in _living:
		if is_instance_valid(actor): actor.model.boss_pose("rise", 1.0)
	await get_tree().create_timer(1.5).timeout
	for actor in _living:
		if is_instance_valid(actor): actor.behavior = "chase"

func _spawn_pair(id: String, z: float) -> void:
	_living.clear()
	var count := maxi(1, world.enemy_director.players.size())
	for side in [-1.0, 1.0]:
		var definition := Enemies.get_def(id).duplicate(true) as EnemyDef
		definition.hp = roundi(definition.hp * (1.0 + 0.2 * (count - 1)))
		var actor := Enemy.new().setup(definition, _pack, world.enemy_director)
		actor.position = Campaigns.open_spot(Vector3(side * (21.0 if id == "castle_champion" else 7.0), 0, z), world)
		_pack.members.append(actor)
		_living.append(actor)
		world.enemy_director.add_child(actor)
		actor.died.connect(_guard_died)
		if id == "castle_champion":
			actor.position.y = world.ground_height(actor.position.x, actor.position.z)
			actor.behavior = "scripted"
			actor.scripted_move = Vector3(-side, 0, 0)
			actor.attack_lock = 2.5
			_release_guard(actor)
		actor.activate.call_deferred()

func _release_guard(actor: Enemy) -> void:
	await get_tree().create_timer(2.5).timeout
	if not is_instance_valid(actor): return
	actor.behavior = "chase"
	actor.scripted_move = Vector3.ZERO

func _guard_died(actor: Enemy) -> void:
	_living.erase(actor)
	_pack._on_member_died(actor)
	world.enemy_director.enemy_killed.emit(actor)
	if not _living.is_empty(): return
	if stage == 1:
		stage = 2
		broadcast("holes_open")
		await get_tree().create_timer(1.4).timeout
		_spawn_pair("castle_champion", -9.0)
	elif stage == 2:
		stage = 3
		GameServer.spawn_bag(world.realm_id, [Items.make("story_throne_key")], actor.global_position, GameServer.PUBLIC, "story")
		broadcast("key_dropped", [actor.global_position])

## Called by NetServer's "castle" action. Never trust a client stage or key claim.
func on_action(p: Dictionary, args: Array) -> void:
	if Net.is_client() or args != ["door"] or stage != 3: return
	if str(p.get("realm", "")) != world.realm_id: return
	var pos: Vector3 = p.get("pos", Vector3.INF)
	if Vector2(pos.x - DOOR.x, pos.z - DOOR.z).length() > 8.0: return
	var stats := GameServer.character(int(p.get("player_id", 0)))
	if stats == null: return
	var key := stats.find_item("story_throne_key")
	if key.is_empty(): return
	stats.take(key)
	stage = 4 # Consume and advance atomically, before the first await.
	broadcast("door_open")
	_gather(Vector3(0, 0, -23), 10.0)
	broadcast("cutscene", ["throne", 9.0])
	# Authoritative path through the doorway, with arrival protection throughout.
	for z in [-32.0, -39.0, -46.0]:
		await get_tree().create_timer(0.9).timeout
		_gather(Vector3(0, 0, z), 0.0)
	await get_tree().create_timer(2.3).timeout
	broadcast("king_rise")
	await get_tree().create_timer(4.0).timeout
	start_king(false)

func _gather(at: Vector3, duration: float, outside_only := false) -> void:
	var ids: Array = []
	var index := 0
	for player in world.enemy_director.players:
		if not is_instance_valid(player) or player.frozen: continue
		ids.append(player.player_id)
		if not outside_only or player.global_position.z > 11:
			_warp(player.player_id, at + Vector3((index % 5 - 2) * 1.8, 0, floori(index / 5.0) * 1.8))
		index += 1
	if duration > 0.0: GameServer.begin_boss_intro(get_instance_id(), world.realm_id, ids, duration)

func _warp(id: int, pos: Vector3) -> void:
	_last_positions[id] = pos
	GameServer.report_position(id, world.realm_id, pos)
	if Net.is_server(): Net.server.social.warp(id, world.realm_id, pos)
	else:
		for player in world.enemy_director.players:
			if is_instance_valid(player) and player.player_id == id: player.global_position = pos
	# SocialServer.warp updates the peer; update its combat proxy in this frame too.
	for player in world.enemy_director.players:
		if is_instance_valid(player) and player.player_id == id: player.global_position = pos

func start_king(play_intro := true) -> Boss:
	if is_instance_valid(king): return king
	stage = 5
	broadcast("state", [stage])
	_pack.site.pos = Vector3(0, 0, -51)
	var definition := Enemies.get_def("hollow_king")
	king = EnemyDirector._make_actor(definition).setup(definition, _pack, world.enemy_director) as Boss
	king.position = CastleWorld.THRONE_SEAT
	_pack.members.append(king)
	_pack.leader = king
	world.enemy_director.add_child(king)
	king.encounter_center = Vector3(0, 0, -51)
	king.died.connect(_king_died)
	if play_intro: king.activate()
	else: king._begin_fight()
	return king

func _king_died(actor: Enemy) -> void:
	stage = 6
	_pack._on_member_died(actor)
	world.enemy_director.enemy_killed.emit(actor)
	broadcast("king_dead", [actor.global_position])
	king_defeated.emit(world.realm_id)
	world.king_defeated.emit(world.realm_id)

## Full event arrays, including ["castle", kind, ...], from NetClient or offline tools.
func apply_event(ev: Array) -> void:
	if ev.size() > 2 and ev[1] == "castle": ev = ev.slice(1)
	if ev.size() < 2 or ev[0] != "castle": return
	match str(ev[1]):
		"state":
			stage = int(ev[2])
			_set_gate(stage > 0, false)
			if stage >= 2: _open_holes(false)
			if stage >= 4: _open_door(false)
			_seated.visible = stage < 5
		"gate_close":
			stage = maxi(stage, 1)
			_set_gate(true, true)
		"holes_open":
			stage = maxi(stage, 2)
			_open_holes(true)
		"key_dropped": stage = maxi(stage, 3)
		"door_open":
			stage = maxi(stage, 4)
			_open_door(true)
		"cutscene":
			if not Net.is_server(): _cutscene(str(ev[2]), float(ev[3]))
		"king_rise": _seated.boss_pose("rise", 1.0)
		"king_dead":
			stage = 6
			_seated.visible = false
	_target.enabled = stage == 3

func _set_gate(closed: bool, animated: bool) -> void:
	_gate.collision_layer = Player.TERRAIN_LAYER if closed else 0
	var y := 0.0 if closed else 9.0
	if animated:
		create_tween().tween_property(_gate, "position:y", y, 0.32).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	else: _gate.position.y = y

func _open_door(animated: bool) -> void:
	_door.collision_layer = 0
	if animated: create_tween().tween_property(_door, "position:y", 12.0, 1.6)
	else: _door.position.y = 12.0

func _open_holes(animated: bool) -> void:
	for plug in _holes:
		if not plug.visible: continue
		for block in plug.get_children():
			if block is StaticBody3D: block.collision_layer = 0
			if animated:
				var tw := create_tween().set_parallel(true)
				tw.tween_property(block, "position", block.position + Vector3(randf_range(-2, 2), -8, randf_range(-3, 3)), 1.2)
				tw.tween_property(block, "rotation", Vector3(randf(), randf(), randf()) * 3, 1.2)
		if animated: get_tree().create_timer(1.3).timeout.connect(func() -> void: if is_instance_valid(plug): plug.hide())
		else: plug.hide()

func _cutscene(kind: String, duration: float) -> void:
	_cut_serial += 1
	var serial := _cut_serial
	if _camera_tween: _camera_tween.kill()
	if not is_instance_valid(_camera):
		_prior_camera = get_viewport().get_camera_3d()
		_cut_player = world.enemy_director.player
		if is_instance_valid(_cut_player):
			_prior_lock = _cut_player.input_locked
			_cut_player.input_locked = true
			_cut_player.begin_interaction(get_instance_id())
		_camera = Camera3D.new()
		add_child(_camera)
		if is_instance_valid(_prior_camera): _camera.environment = _prior_camera.environment
	_camera.make_current()
	var throne := kind == "throne"
	_hide_gui(get_tree().root)
	if throne:
		GameAudio.stop(_cut_audio, .08)
		_cut_audio = GameAudio.play("boss_intro", Vector3.INF, {bus="SFX", priority=3, duration=duration})
	_camera.global_position = world.to_global(Vector3(10, 11, -48) if throne else Vector3(4, 15, 8))
	var look := world.to_global(Vector3(0, 6, -71) if throne else Vector3(0, 2, -7))
	_camera.look_at(look)
	_camera_tween = create_tween()
	_camera_tween.tween_property(_camera, "global_position", _camera.global_position + Vector3(-7, 2, -5), duration)
	await get_tree().create_timer(duration).timeout
	if serial != _cut_serial: return
	_restore_camera()

func _restore_camera() -> void:
	GameAudio.stop(_cut_audio, .12)
	_cut_audio = {}
	for gui in _hidden_gui:
		if is_instance_valid(gui): gui.show()
	_hidden_gui.clear()
	if is_instance_valid(_prior_camera): _prior_camera.make_current()
	if is_instance_valid(_cut_player):
		_cut_player.input_locked = _prior_lock
		_cut_player.end_interaction(get_instance_id())
	if is_instance_valid(_camera): _camera.queue_free()
	_camera = null

func _exit_tree() -> void:
	_restore_camera()
	GameServer.cancel_boss_intro(get_instance_id())

func _barrier(at: Vector3, width: float, height: float, bars: bool) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = Player.TERRAIN_LAYER
	body.collision_mask = 0
	body.position = at
	add_child(body)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(width, height, 0.8)
	shape.shape = box
	shape.position.y = height * 0.5
	body.add_child(shape)
	if bars:
		for i in int(width) + 1: _box(body, Vector3(i - width * 0.5, height * 0.5, 0), Vector3(0.22, height, 0.3), Color("171922"))
		for y in [1.5, 5.5]: _box(body, Vector3(0, y, 0), Vector3(width, 0.28, 0.4), Color("252732"))
	else:
		_box(body, Vector3(0, height * 0.5, 0), Vector3(width, height, 0.7), Color("242733"))
		for x in range(-7, 8, 2): _box(body, Vector3(x, height * 0.5, 0.42), Vector3(0.25, height, 0.2), Color("757987"))
	return body

func _box(parent: Node3D, at: Vector3, size: Vector3, color: Color, solid := false) -> void:
	var holder: Node3D = StaticBody3D.new() if solid else Node3D.new()
	holder.position = at
	parent.add_child(holder)
	if solid:
		holder.collision_layer = Player.TERRAIN_LAYER
		var collider := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		collider.shape = shape
		holder.add_child(collider)
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = 0.8
	material.roughness = 0.35
	mesh.material_override = material
	holder.add_child(mesh)
