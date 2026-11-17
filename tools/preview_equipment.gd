extends Node3D
## Local art review: G1, G2, G8, Divine, then unequipped for each class.
func _ready() -> void:
	var view := SubViewport.new()
	view.size = Vector2i(1500, 1500)
	view.own_world_3d = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(view)
	var world := Node3D.new()
	view.add_child(world)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("252936")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color.WHITE
	env.environment.ambient_light_energy = 0.7
	world.add_child(env)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-40, -30, 0)
	world.add_child(light)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 17
	world.add_child(camera)
	var rear := "--rear" in OS.get_cmdline_user_args()
	var walk := "--walk" in OS.get_cmdline_user_args()
	camera.look_at_from_position(Vector3(0, 9, 28 if rear else -28), Vector3(0, 7.5, 0))
	for row in 5:
		for col in 5:
			var id: String = PlayerClasses.ORDER[col]
			var model := PlayerClasses.make_model(id)
			model.position = Vector3((col - 2) * 3.25, (4 - row) * 3, 0)
			model.rotation.y = -0.28
			world.add_child(model)
			var weapon: Item
			var armor: Item
			if walk:
				weapon = PlayerClasses.gear_item(id, "weapon", 8)
				armor = PlayerClasses.gear_item(id, "armor", 8)
			elif row < 3:
				var tier: int = [1, 2, 8][row]
				weapon = PlayerClasses.gear_item(id, "weapon", tier)
				armor = PlayerClasses.gear_item(id, "armor", tier)
			elif row == 3:
				weapon = Items.make("D_%s_ofthestormeye" % str(PlayerClasses.get_def(id).weapon).to_lower())
				armor = Items.make("D_%s_ofthestormeye" % str(PlayerClasses.get_def(id).armor).to_lower())
			model.set_equipment(weapon, armor)
			if walk:
				model.set("_walk_blend", 1.0)
				model.set("_phase", [-PI/2, -PI/4, 0.0, PI/4, PI/2][row])
			model.animate(1.0 if walk else 0.0, 0.0)
			var label := Label3D.new()
			label.text = id + " " + (["Stride -1", "Stride -.7", "Passing", "Stride .7", "Stride 1"][row] if walk else ["G1", "G2", "G8", "Stormeye", "Unequipped"][row])
			label.font_size = 32
			label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			label.position = model.position + Vector3(0, -0.2, -0.4)
			world.add_child(label)
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var output := "/tmp/equipment-walk-back.png" if rear else "/tmp/equipment-walk-front.png"
	if not walk: output = "/tmp/equipment-review-back.png" if rear else "/tmp/equipment-review.png"
	view.get_texture().get_image().save_png(output)
	get_tree().quit()
