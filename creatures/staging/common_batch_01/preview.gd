extends Node3D
## Standalone asset review only. Never instantiates Enemy, packs or a game world.
## F6 preview.tscn; Space pauses, A/D turns models, Enter shows attack poses.
const IDS: Array[String] = ["sporeback", "thorn_hopper", "cinder_beetle", "frost_moth", "ruin_watcher"]
const TITLES: Array[String] = ["Sporeback", "Thorn Hopper", "Cinder Beetle", "Frost Moth", "Ruin Watcher"]
var models: Array[CreatureModel] = []
var projectiles: Array[CreatureModel] = []
var paused := false
var timer := 0.0
var captured := false

func _ready() -> void:
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color("202832")
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("c4daed")
	settings.ambient_light_energy = 0.65
	settings.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.environment = settings
	add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -28, 0)
	sun.light_energy = 1.4
	sun.shadow_enabled = true
	add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20, 140, 0)
	fill.light_color = Color("8db9e0")
	fill.light_energy = 0.45
	add_child(fill)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 8.7
	camera.position = Vector3(0, 7.3, -13)
	add_child(camera)
	camera.look_at(Vector3(0, 0.9, 0))
	camera.current = true
	for i in IDS.size():
		var x := (2 - i) * 3.05
		var stage := MeshInstance3D.new()
		var platform := CylinderMesh.new()
		platform.top_radius = 1.30
		platform.bottom_radius = 1.35
		platform.height = 0.15
		platform.radial_segments = 12
		stage.mesh = platform
		var material := StandardMaterial3D.new()
		material.albedo_color = Color("34414e")
		material.roughness = 0.95
		stage.material_override = material
		stage.position = Vector3(x, -0.08, 0)
		add_child(stage)
		var model := CreatureModel.new("staging/common_batch_01/" + IDS[i])
		model.position.x = x
		model.rotation_degrees.y = -18
		add_child(model)
		models.append(model)
		var shot := CreatureModel.new("staging/common_batch_01/" + IDS[i] + "/projectile")
		shot.position = Vector3(x + 0.85, 0.30, -0.95)
		shot.rotation_degrees = Vector3(0, -35, 0)
		add_child(shot)
		projectiles.append(shot)
		var label := Label3D.new()
		label.text = TITLES[i]
		label.font_size = 44
		label.pixel_size = 0.0036
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test = true
		label.position = Vector3(x, -0.08, -1.65)
		add_child(label)
		# Exercise attack hooks and actual VoxelVoxLoader/mesher for every part.
		model.animate(0.6, 0.016)
		model.play_attack(0.55)
		model.strike()
		model.flap()
		assert(model.hand_position().is_finite())
		assert(model.get_child_count() > 0)
	var ui := CanvasLayer.new()
	add_child(ui)
	var heading := Label.new()
	heading.text = "COMMON ENEMIES / BATCH 01  —  ART STAGING"
	heading.position = Vector2(32, 24)
	heading.add_theme_font_size_override("font_size", 26)
	ui.add_child(heading)
	var instructions := Label.new()
	instructions.text = "Space: pause  •  A/D: turn  •  Enter: attack pose     |     Small models beside each creature are projectile concepts."
	instructions.position = Vector2(32, 66)
	instructions.add_theme_font_size_override("font_size", 18)
	ui.add_child(instructions)
	if "--validate-only" in OS.get_cmdline_user_args():
		print("BATCH_01_OK: five creature rigs and five projectile rigs loaded and animated using CreatureModel / VoxelVoxLoader.")
		get_tree().quit()

func _process(delta: float) -> void:
	if paused:
		return
	timer += delta
	for model in models:
		model.animate(0.35, delta)
	for shot in projectiles:
		shot.rotation.y += delta * 0.4
	if timer > 1.2 and not captured and "--capture" in OS.get_cmdline_user_args():
		captured = true
		_capture()

func _capture() -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var error := image.save_png("res://creatures/staging/common_batch_01/engine_preview.png")
	print("BATCH_01_CAPTURE: ", error)
	get_tree().quit(error)

func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		for model in models:
			model.play_attack(0.55)
			model.strike()
			model.flap()
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE:
			paused = not paused
		if event.keycode == KEY_A or event.keycode == KEY_D:
			for model in models:
				model.rotation.y += 0.35 if event.keycode == KEY_A else -0.35
