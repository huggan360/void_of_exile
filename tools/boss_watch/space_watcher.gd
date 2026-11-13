extends Node
## Preview driver only: the real Reach boss fights, in their real arenas. An
## invulnerable target circles the floor; auto damage takes about 90 s of
## vulnerable boss HP. Helpers (and Vaelith's arms, which pass hits on) lose HP too.
var game: Node3D
var key := "space_1"
var boss: Boss
var world: SpaceWorld
var frame: Transform3D  # the arena floor: origin at its centre, basis.y up
var clock := 0.0
var pulse := 0.0
var auto_damage := true
var finished := false
var _label: Label
var _camera := Camera3D.new()
var _orbit := 0.0
## key: [boss id, planet]
const BOSSES := {space_1 = ["queen_briarrose", "rosamund"], space_2 = ["amber_colossus", "amberfall"],
	space_3 = ["selenarch", "hollowmoon"], space_4 = ["brood_matriarch", "mawgrave"],
	space_5 = ["stormeye_tyrant", "pale_eye"], space_6 = ["veil_herald", "shardheart"]}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_start.call_deferred()

func _start() -> void:
	add_child(_camera)
	var layer := CanvasLayer.new()
	layer.layer = 75
	add_child(layer)
	_label = UIStyle.label("Loading the Reach...", 18, UIStyle.TEXT)
	_label.position = Vector2(24, 120)
	layer.add_child(_label)
	while not game.world is SpaceWorld:
		await get_tree().create_timer(0.2).timeout
	world = game.world
	var spec: Array = BOSSES[key]
	var p := SpaceLayout.planet(str(spec[1]))
	frame = Transform3D(SpaceLayout.fort_frame(p).basis, PlanetStrongholds.floor_center(str(spec[1])))
	await get_tree().process_frame
	game._place_player(frame.origin+frame.basis.y*1.0+frame.basis.z*12.0)
	await game._wait_for_ground()
	game.menus.hide_all()
	game.hud.show()
	game.player.input_locked = true
	game.player.set_physics_process(false)
	game.player.frozen = false
	_camera.fov = 55.0
	_camera.make_current()
	_place_target(0.0)
	while not is_instance_valid(boss):
		for actor in Boss.all:
			if is_instance_valid(actor) and actor.def.id==spec[0]: boss = actor
		if not is_instance_valid(boss): await get_tree().create_timer(0.1).timeout
	# Only the encounter: planet packs nearby would otherwise join in.
	for actor in world.enemy_director.enemies():
		if actor!=boss: actor.queue_free()
	game.enemy_bullets.clear()
	boss.died.connect(func(_a: Enemy) -> void: finished = true)
	if game._args.has("watch-seconds"):
		await get_tree().create_timer(float(game._args["watch-seconds"])).timeout
		get_tree().quit()

func _place_target(angle: float) -> void:
	var local := Vector3(sin(angle)*14.0, 0, cos(angle)*12.0)
	var at := frame.origin+frame.basis*local
	at.y = world.ground_height(at.x, at.z)+0.1
	game.player.global_position = at

func _process(delta: float) -> void:
	if world==null or frame==Transform3D() or get_tree().paused: return
	_orbit += delta*0.05
	var center := frame.origin+frame.basis.y*2.0
	_camera.global_position = center+frame.basis*Vector3(sin(_orbit)*14.0, 50.0, cos(_orbit)*14.0+30.0)
	_camera.look_at(center, frame.basis.y)
	if finished or not is_instance_valid(boss):
		_label.text = "%s is defeated - R: replay - Esc: close" % boss_name() if finished else "Waiting for the boss..."
		return
	clock += delta
	if boss.state==Enemy.State.ACTIVE:
		_place_target(clock*0.14)
		var toward: Vector3 = boss.global_position-game.player.global_position
		game.player.model.rotation.y = atan2(-toward.x, -toward.z)
		game.player.model.animate(0.4, delta)
	pulse -= delta
	if auto_damage and pulse<=0.0 and boss.state==Enemy.State.ACTIVE:
		pulse = 0.5
		boss.take_hit(boss.global_position+Vector3.UP, Vector3.ZERO, ceili(boss.max_hp*0.5/90.0)+boss.defense, game.player)
		for role in boss._support.keys():
			for helper: Enemy in boss.support(str(role)).duplicate():
				if not is_instance_valid(helper) or not helper.is_alive(): continue
				# Vaelith's arms take its share of the damage (only while down).
				var share := ceili(boss.max_hp*0.5/90.0/4.0) if helper.def.id=="vaelith_arm" else ceili(helper.max_hp*0.5/18.0)
				helper.take_hit(helper.global_position+Vector3.UP, Vector3.ZERO, share+helper.defense, game.player)
	var stage := "Waiting" if boss.phase<0 else "Phase %d of %d" % [boss.phase+1, boss.boss_def.phases.size()]
	_label.text = "%s - %s - %s - %ds\nP: pause - D: auto damage %s - R: replay - Esc: close" % [key, boss_name(), stage, int(clock),
		"ON" if auto_damage else "OFF"]

func boss_name() -> String:
	return boss.def.enemy_name if is_instance_valid(boss) else str(BOSSES[key][0])

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
