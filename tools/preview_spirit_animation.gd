extends Node
## Render actual articulated spirit poses for visual review.
var output := "/home/hugo/tmp/spirit_animation"
func _ready() -> void: _run.call_deferred()
func _run() -> void:
	GameServer.set_physics_process(false)
	WorldServer.set_process(false)
	DirAccess.make_dir_recursive_absolute(output)
	var view := SubViewport.new()
	view.size = Vector2i(720, 600)
	view.own_world_3d = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(view)
	var stage := Node3D.new()
	view.add_child(stage)
	var env := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color("101c2a")
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("9fb9da")
	settings.ambient_light_energy = 0.55
	settings.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	settings.glow_enabled = true
	settings.glow_intensity = 0.6
	env.environment = settings
	stage.add_child(env)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-40,-28,0)
	stage.add_child(light)
	var god := CreatureModel.new("spirit_purple")
	stage.add_child(god)
	god._phase = 0.0
	var helper := CreatureModel.new("genie_purple")
	helper.scale = Vector3.ONE * 0.7
	helper.position = Vector3(1.5, 0, 0.2)
	stage.add_child(helper)
	helper._phase = 1.2
	var spark := CreatureModel.new("spirit_spark")
	spark.scale = Vector3.ONE * 0.38
	spark.position = Vector3(-1.15, 0.1, -0.1)
	stage.add_child(spark)
	var camera := Camera3D.new()
	stage.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 4.7
	camera.position = Vector3(5.2,4.2,-10)
	camera.look_at(Vector3(0.15,1.35,0))
	camera.current = true
	for frame in 72:
		if frame in [18, 54]: god.play_attack(0.4); helper.play_attack(0.4)
		if frame in [30, 66]: god.strike(); helper.strike()
		god.animate(0.5, 1.0 / 24.0)
		helper.animate(0.7, 1.0 / 24.0)
		spark.animate(0.8, 1.0 / 24.0)
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		view.get_texture().get_image().save_png(output + "/%03d.png" % frame)
	view.queue_free()
	await get_tree().process_frame
	print("Spirit animation rendered to ", output)
	get_tree().quit()
