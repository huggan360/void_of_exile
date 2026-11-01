extends Node
## Art export only: actual authored boss projectile meshes and palette shader.
const OUTPUT := "/home/hugo/Desktop/Voidrealm Boss Projectile Previews"
func _ready() -> void: _export.call_deferred()
func _export() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	var manifest: Array = JSON.parse_string(FileAccess.get_file_as_string("res://creatures/boss_projectiles/manifest.json"))
	var selected := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--only="): selected = argument.trim_prefix("--only=")
	for entry: Dictionary in manifest:
		if selected!="" and str(entry.id)!=selected: continue
		var viewport := SubViewport.new()
		viewport.size = Vector2i(720,360)
		viewport.own_world_3d = true
		viewport.msaa_3d = Viewport.MSAA_4X
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		add_child(viewport)
		var stage := Node3D.new()
		viewport.add_child(stage)
		var world := WorldEnvironment.new()
		var environment := Environment.new()
		environment.background_mode = Environment.BG_COLOR
		environment.background_color = Color("#17202d")
		environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		environment.ambient_light_color = Color(.7,.8,1)
		environment.ambient_light_energy = .75
		environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
		environment.glow_enabled = true
		environment.glow_intensity = .35
		world.environment = environment
		stage.add_child(world)
		var light := DirectionalLight3D.new()
		light.rotation_degrees = Vector3(-40,-28,0)
		light.light_energy = .8
		light.light_specular = 0.0
		stage.add_child(light)
		var geometry := MeshInstance3D.new()
		geometry.mesh = VoxModel.load_mesh("res://"+str(entry.folder)+"/model.vox")
		var unit: float = entry.voxel_size
		geometry.scale = Vector3.ONE*unit
		geometry.position = -geometry.mesh.get_aabb().get_center()*unit
		var material := ShaderMaterial.new()
		material.shader = preload("res://shaders/voxel_model.gdshader")
		material.set_shader_parameter("jitter",0.0)
		material.set_shader_parameter("glow_strength",.85 if str(entry.id).begins_with("fire_") else .65)
		geometry.material_override = material
		stage.add_child(geometry)
		var bounds: AABB = geometry.transform*geometry.mesh.get_aabb()
		var camera := Camera3D.new()
		stage.add_child(camera)
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.position = Vector3(14,18,-24)
		camera.look_at(Vector3.ZERO)
		var camera_bounds := camera.global_transform.affine_inverse()*bounds
		camera.size = maxf(camera_bounds.size.y,camera_bounds.size.x*.5)*1.3
		camera.current = true
		for frame in 4: await get_tree().process_frame
		await RenderingServer.frame_post_draw
		viewport.get_texture().get_image().save_png(OUTPUT+"/"+str(entry.id)+".png")
		viewport.queue_free()
		await get_tree().process_frame
	print("Projectile renders saved to ",OUTPUT)
	get_tree().quit()
