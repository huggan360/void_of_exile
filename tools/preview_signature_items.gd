extends Node3D
## Offline rendered review of worn signatures, cut-glass shots and Artifacts.
## Run the voxel editor with --scene res://tools/preview_signature_items.tscn.
var _view: SubViewport
var _world: Node3D
var _camera: Camera3D

func _ready() -> void:
	run.call_deferred()

func run() -> void:
	GameAudio._disabled = true
	GameAudio.set_process(false)
	GameServer.set_physics_process(false)
	WorldServer.set_process(false)
	_view = SubViewport.new()
	_view.size = Vector2i(1920, 1440)
	_view.own_world_3d = true
	_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_view)
	_world = Node3D.new()
	_view.add_child(_world)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("151b2b")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("d8e2ff")
	env.environment.ambient_light_energy = 0.75
	env.environment.glow_enabled = true
	env.environment.glow_intensity = 0.9
	_world.add_child(env)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-40, -30, 0)
	_world.add_child(light)
	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_world.add_child(_camera)
	await _figures()
	await _projectiles()
	get_tree().quit()

func _label(text: String, at: Vector3, color := Color.WHITE, scale := 0.004) -> void:
	var label := Label3D.new()
	label.text = text
	label.font = UIStyle.bold()
	label.font_size = 42
	label.pixel_size = scale
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = at
	label.modulate = color
	_world.add_child(label)

func _figures() -> void:
	var stage := Node3D.new()
	_world.add_child(stage)
	_camera.size = 12
	_camera.look_at_from_position(Vector3(0, 5, -26), Vector3(0, 2.7, 0))
	var looks := [
		["archer", "L_bow_kaleidoscope", "L_cloak_secondheart"],
		["wizard", "L_wand_daybreaker", "L_robe_nosun"],
		["merrow", "L_trident_worldneedle", "L_cloak_wholestitch"],
		["archer", "L_bow_threadcutter", "L_cloak_unravelled"],
		["wizard", "A_wand_lastfirework", "A_robe_impossiblemorning"],
		["archer", "A_bow_midsummer", "A_cloak_starparade"],
		["alchemist", "A_wand_pocketplanetarium", "A_cloak_starparade"],
		["merrow", "A_trident_badidea", "A_cloak_starparade"],
	]
	for i in looks.size():
		var entry: Array = looks[i]
		var model := PlayerClasses.make_model(entry[0])
		model.position = Vector3((i % 4 - 1.5) * 4.0, (1 - i / 4) * 3.8, 0)
		model.rotation.y = -0.25
		stage.add_child(model)
		var weapon := Items.make(entry[1])
		var armor := Items.make(entry[2])
		model.set_equipment(weapon, armor)
		model.animate(0.0, 0.1)
		var aura := GearAura.new()
		model.add_child(aura)
		var stats := PlayerStats.new()
		stats.gear.weapon = weapon
		stats.gear.armor = armor
		aura.refresh(stats)
		_label(weapon.item_name + "\n" + armor.item_name, model.position + Vector3(0, -0.35, -0.5), UIStyle.grade_color(weapon), 0.003)
	await get_tree().create_timer(0.6).timeout
	await RenderingServer.frame_post_draw
	_view.get_texture().get_image().save_png("/home/hugo/tmp/signature_equipment.png")
	_camera.look_at_from_position(Vector3(0, 5, 26), Vector3(0, 2.7, 0))
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	_view.get_texture().get_image().save_png("/home/hugo/tmp/signature_equipment_back.png")
	stage.free()
	for child in _world.get_children():
		if child is Label3D: child.free()

func _projectiles() -> void:
	_camera.size = 43
	_camera.look_at_from_position(Vector3(0, 38, 23), Vector3.ZERO)
	var ids := ["L_bow_kaleidoscope", "L_trident_worldneedle", "L_wand_daybreaker",
		"L_wand_silentbell", "L_bow_blackcomet", "L_wand_seedoftomorrow",
		"A_wand_lastfirework", "A_wand_pocketplanetarium", "A_bow_midsummer"]
	var flights: Array[Arrows] = []
	for i in ids.size():
		var weapon := Items.make(ids[i])
		var center := Vector3((i % 3 - 1) * 14, 1.1, (i / 3 - 1) * 12)
		_label(weapon.item_name, center + Vector3(0, 0, 4.4), UIStyle.grade_color(weapon), 0.006)
		var arrows := Arrows.new()
		_world.add_child(arrows)
		arrows.set_physics_process(false)
		flights.append(arrows)
		var display := SignaturePatterns.primary(Vector3.RIGHT, Vector3.UP, weapon)
		if not display.is_empty():
			for entry: Dictionary in display:
				entry.mods.size = 1.8
				arrows.spawn(center, entry.direction, 0, weapon, entry.phase, "", entry.mods)
		else:
			for shot in weapon.shots:
				var origin := center + Vector3(-5, 0, (shot - weapon.shots * 0.5) * 1.4)
				arrows.spawn(origin, Vector3.RIGHT, 0, weapon, shot * PI, "", {visual = true, size = 2.4 if not weapon.is_artifact() else 1.0})
		if weapon.id == "A_wand_lastfirework":
			for entry: Dictionary in SignaturePatterns.burst(weapon, Vector3.UP, false):
				entry.mods.visual = true
				arrows.spawn(center + Vector3(2, 1.5, 0), entry.direction, 0, weapon, entry.phase, "", entry.mods)
	for frame in 18:
		for arrows: Arrows in flights: arrows._physics_step(1.0 / 60.0)
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	_view.get_texture().get_image().save_png("/home/hugo/tmp/signature_projectiles.png")
