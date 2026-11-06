extends Node
## Preview driver only: the real Hollow Empress fight, ring drops included.
## An invulnerable target circles the bowl; auto damage takes about 90 s of
## vulnerable boss HP. Brood helpers lose HP too.
var game: Node3D
var boss: Boss
var world: TheoryWorld
var clock := 0.0
var pulse := 0.0
var auto_damage := true
var finished := false
var _label: Label
var _camera := Camera3D.new()
var _orbit := 0.0
var _last_phase := -9

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_start.call_deferred()

func _start() -> void:
	add_child(_camera)
	var layer := CanvasLayer.new()
	layer.layer = 75
	add_child(layer)
	_label = UIStyle.label("Loading the Convergence...", 18, UIStyle.TEXT)
	_label.position = Vector2(24, 120)
	layer.add_child(_label)
	while not (game.world is TheoryWorld and (game.world as TheoryWorld).surfaces.has("arena_0")):
		await get_tree().create_timer(0.2).timeout
	world = game.world
	await game._wait_for_ground()
	game.menus.hide_all()
	game.hud.show()
	game.player.input_locked = true
	game.player.set_physics_process(false)
	game.player.frozen = false
	_place_target(0.0)
	_camera.fov = 55.0
	_camera.make_current()
	while not is_instance_valid(boss):
		for actor in world.enemy_director.enemies():
			if actor is Boss and actor.def.id == "void_empress": boss = actor
		if not is_instance_valid(boss): await get_tree().create_timer(0.1).timeout
	# Only the encounter: the entrance pack would otherwise join in.
	for actor in world.enemy_director.enemies():
		if actor != boss: actor.queue_free()
	boss.died.connect(func(_a: Enemy) -> void: finished = true)
	if game._args.has("watch-seconds"):
		await get_tree().create_timer(float(game._args["watch-seconds"])).timeout
		get_tree().quit()

func _place_target(angle: float) -> void:
	var radius := maxf(6.0, 15.0 - world.arena_stage * 3.0)
	var at := TheoryLayout.ARENA + Vector3(sin(angle) * radius, 0, cos(angle) * radius)
	at.y = world.ground_height(at.x, at.z) + 0.1
	game.player.global_position = at

func _process(delta: float) -> void:
	if world == null or get_tree().paused: return
	_orbit += delta * 0.05
	var center := TheoryLayout.ARENA + Vector3.UP * 2.0
	_camera.global_position = center + Vector3(sin(_orbit) * 14.0, 46.0, cos(_orbit) * 14.0)
	_camera.look_at(center)
	if finished or not is_instance_valid(boss):
		_label.text = "The Hollow Empress is defeated - R: replay - Esc: close" if finished else "Waiting for the Hollow Empress..."
		return
	clock += delta
	_place_target(clock * 0.16)
	var toward: Vector3 = boss.global_position - game.player.global_position
	game.player.model.rotation.y = atan2(-toward.x, -toward.z)
	game.player.model.animate(0.4, delta)
	pulse -= delta
	if auto_damage and pulse <= 0.0 and boss.state == Enemy.State.ACTIVE:
		pulse = 0.5
		boss.take_hit(boss.global_position + Vector3.UP, Vector3.ZERO, ceili(boss.max_hp * 0.5 / 90.0) + boss.defense, game.player)
		for role in boss._support.keys():
			for helper: Enemy in boss.support(str(role)).duplicate():
				if is_instance_valid(helper) and helper.is_alive():
					helper.take_hit(helper.global_position + Vector3.UP, Vector3.ZERO, ceili(helper.max_hp * 0.5 / 18.0) + helper.defense, game.player)
	if boss.phase != _last_phase:
		_last_phase = boss.phase
		if game._args.has("shots") and boss.phase >= 0: _shot("phase_%d" % (boss.phase + 1), 4.5)
	var stage := "Waiting" if boss.phase < 0 else "Phase %d of 4" % (boss.phase + 1)
	_label.text = "The Hollow Empress - %s - arena ring %d - %ds\nP: pause - D: auto damage %s - R: replay - Esc: close" % [stage, world.arena_stage, int(clock), "ON" if auto_damage else "OFF"]

## --shots=<dir>: a picture a few seconds into every phase.
func _shot(name: String, delay: float) -> void:
	await get_tree().create_timer(delay).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/empress_%s.png" % [game._args.shots, name])

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	match event.keycode:
		KEY_P, KEY_SPACE: get_tree().paused = not get_tree().paused
		KEY_D: auto_damage = not auto_damage
		KEY_R:
			get_tree().paused = false
			get_tree().reload_current_scene()
		KEY_ESCAPE: get_tree().quit()

func _exit_tree() -> void:
	get_tree().paused = false
