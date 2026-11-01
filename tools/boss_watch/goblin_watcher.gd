extends Node
## Offline fight viewer: the live generated cave, enemies and encounter.
var game: Node3D
var boss: Boss
var clock := 0.0
var pulse := 0.0
var auto_damage := true
var _label: Label
var _center := Vector3.ZERO

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_start.call_deferred()

func _start() -> void:
	game.menus.hide_all()
	game.hud.show()
	game.player.input_locked = true
	_center = game.world.layout.boss
	game.atmosphere.fog_of_war_hidden = true
	game._place_player(_center + Vector3(0, 0, 9))
	await game._wait_for_ground()
	game.player.set_physics_process(false)
	game.player.frozen = false
	game.player.camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	game.player.camera.size = 36.0
	var layer := CanvasLayer.new()
	add_child(layer)
	_label = Label.new()
	_label.position = Vector2(24, 120)
	_label.add_theme_font_size_override("font_size", 22)
	layer.add_child(_label)
	for actor in game.world.enemy_director.enemies():
		if actor.def.id == "goblin_king": boss = actor
	while not is_instance_valid(boss):
		for actor in game.world.enemy_director.enemies():
			if actor.def.id == "goblin_king": boss = actor
		await get_tree().create_timer(0.1).timeout
	if game._args.has("out"):
		await get_tree().create_timer(4.0).timeout
		get_viewport().get_texture().get_image().save_png(game._args.out)
	if game._args.has("watch-seconds"):
		await get_tree().create_timer(float(game._args["watch-seconds"])).timeout
		get_tree().quit()

func _process(delta: float) -> void:
	if not is_instance_valid(game) or not _label or get_tree().paused: return
	clock += delta
	game.player.camera.global_position = _center + Vector3(0, 32, 24)
	game.player.camera.look_at(_center + Vector3.UP * 1.5)
	if is_instance_valid(boss):
		var angle := clock * 0.16
		if boss.phase != int(get_meta("last_phase", -9)):
			set_meta("last_phase", boss.phase)
			print("[watch] phase=", boss.phase + 1, " hp=", boss.hp)
			if game._args.has("shots") and boss.phase >= 0: _phase_shot(boss.phase + 1)
		game.player.global_position = _center + Vector3(sin(angle) * 8, 0, cos(angle) * 8)
		game.player.model.animate(0.4, delta)
		pulse -= delta
		if auto_damage and pulse <= 0.0 and boss.state == Enemy.State.ACTIVE:
			pulse = 0.5
			boss.take_hit(boss.global_position + Vector3.UP, Vector3.ZERO, ceili(boss.max_hp / 180.0) + boss.defense, game.player)
		_label.text = "Goblin King · Phase %d · %ds\nP: pause · D: auto damage %s · R: replay · Esc: close" % [boss.phase + 1, int(clock), "ON" if auto_damage else "OFF"]
	else:
		_label.text = "Goblin King defeated · R: replay · Esc: close"

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	match event.keycode:
		KEY_P: get_tree().paused = not get_tree().paused
		KEY_D: auto_damage = not auto_damage
		KEY_R:
			get_tree().paused = false
			get_tree().reload_current_scene()
		KEY_ESCAPE: get_tree().quit()


func _phase_shot(index: int) -> void:
	await get_tree().create_timer(4.0).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/tmp/goblin_king_phase_%d.png" % index)
