extends Node3D
## Standalone offline castle fight; no account/login or live service calls.
var world: CastleWorld
var player := Player.new()
var bullets := EnemyBullets.new()
var boss: Boss
var _clock := 0.0
var _pulse := 0.0
var _auto := true
var _phase := -2
var _label: Label
var _limit := 0.0
var _fast := false
var _shots := false

func _ready() -> void:
	GameServer.debug_godmode = true
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--seconds="): _limit = float(arg.get_slice("=", 1))
		if arg == "--fast": _fast = true
		if arg == "--shots": _shots = true
	world = load("res://scenes/castle/hollow_castle.tscn").instantiate()
	world.realm_id = "cst_watch_king"
	add_child(world)
	add_child(bullets)
	player.player_id = GameServer.join(false)
	player.stats = GameServer.character(player.player_id)
	GameServer.enter_realm(player.player_id, world.realm_id)
	player.ground_height = world.ground_height
	player.hazard = world.is_hazard
	add_child(player)
	player.set_physics_process(false)
	player.input_locked = true
	player.frozen = false
	player.position = Vector3(0, 0, -46)
	bullets.players = [player]
	world.enemy_director.setup(player, bullets, [], {})
	var environment := WorldEnvironment.new()
	environment.environment = preload("res://scenes/castle/castle_environment.tres")
	add_child(environment)
	var moon := DirectionalLight3D.new()
	moon.rotation_degrees = Vector3(-56, -28, 0)
	moon.light_energy = 0.8
	add_child(moon)
	player.camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	player.camera.size = 46
	player.camera.far = 300
	var layer := CanvasLayer.new()
	add_child(layer)
	_label = Label.new()
	_label.position = Vector2(22, 22)
	layer.add_child(_label)
	boss = world.encounter.start_king()
	boss.died.connect(func(_enemy: Enemy) -> void:
		print("[king-watch] king defeated; completion signal delivered")
		if _fast: get_tree().create_timer(1.0).timeout.connect(func() -> void: get_tree().quit()))
	print("[king-watch] Castle throne fight loaded. P pause, D auto damage, R replay, Escape close.")

func _process(delta: float) -> void:
	_clock += delta
	if _limit > 0 and _clock > _limit: get_tree().quit()
	if not is_instance_valid(world): return
	player.camera.global_position = Vector3(0, 54, -18)
	player.camera.look_at(Vector3(0, 2, -55))
	if not is_instance_valid(boss):
		_label.text = "The Hollow King defeated - R replay - Escape close"
		return
	var a := _clock * 0.19
	player.global_position = Vector3(sin(a) * 12, 0, -53 + cos(a) * 12)
	GameServer.report_position(player.player_id, world.realm_id, player.global_position)
	player.model.animate(0.4, delta)
	if boss.phase != _phase:
		_phase = boss.phase
		print("[king-watch] phase=", _phase + 1, " hp=", boss.hp)
		if _shots and _phase >= 0: _screenshot(_phase + 1)
	_pulse -= delta
	if _auto and _pulse <= 0 and boss.state == Enemy.State.ACTIVE:
		_pulse = 0.5
		boss.take_hit(boss.global_position + Vector3.UP, Vector3.ZERO, ceili(boss.max_hp / (25.0 if _fast else 180.0)) + boss.defense, player)
		for role in boss._support.keys():
			for helper: Enemy in boss.support(role).duplicate():
				helper.take_hit(helper.global_position + Vector3.UP, Vector3.ZERO, ceili(helper.max_hp / (5.0 if _fast else 30.0)) + helper.defense, player)
	_label.text = "The Hollow King - phase %d/4 - %d HP\nP pause - D auto damage %s - R replay - Escape close" % [boss.phase + 1, boss.hp, "ON" if _auto else "OFF"]

func _screenshot(index: int) -> void:
	await get_tree().create_timer(2.0).timeout
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/tmp/hollow_king_phase_%d.png" % index)

func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	match event.keycode:
		KEY_ESCAPE: get_tree().quit()
		KEY_R: get_tree().reload_current_scene()
		KEY_D: _auto = not _auto
		KEY_P:
			if is_instance_valid(boss): boss.set_physics_process(not boss.is_physics_processing())
