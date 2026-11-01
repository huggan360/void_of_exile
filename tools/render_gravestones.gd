extends Node
## Same-scale art renders of the five gravestone tiers.
const OUTPUT := "/home/hugo/Desktop/Voidrealm Gravestone Previews"
func _ready() -> void: _render.call_deferred()
func _render() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	var manifest: Array = JSON.parse_string(FileAccess.get_file_as_string("res://props/gravestones/manifest.json"))
	for entry: Dictionary in manifest:
		var viewport := SubViewport.new()
		viewport.size = Vector2i(720,900)
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
		environment.ambient_light_color = Color(.78,.83,.93)
		environment.ambient_light_energy = .8
		environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
		environment.glow_enabled = true
		environment.glow_intensity = .4
		world.environment = environment
		stage.add_child(world)
		var light := DirectionalLight3D.new()
		light.rotation_degrees = Vector3(-43,-26,0)
		light.light_energy = 1.1
		light.light_specular = 0
		light.shadow_enabled = true
		stage.add_child(light)
		var floor_mesh := MeshInstance3D.new()
		var plane := PlaneMesh.new()
		plane.size = Vector2(200,200)
		floor_mesh.mesh = plane
		floor_mesh.position.y = -.008
		var floor_material := StandardMaterial3D.new()
		floor_material.albedo_color = Color("#17202d")
		floor_material.roughness = 1
		floor_mesh.material_override = floor_material
		stage.add_child(floor_mesh)
		var packed := load("res://"+str(entry.scene)) as PackedScene
		stage.add_child(packed.instantiate())
		var camera := Camera3D.new()
		stage.add_child(camera)
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = 3.5
		var focus := Vector3(0,1.18,0)
		camera.position = focus+Vector3(7,5,-18)
		camera.look_at(focus)
		camera.current = true
		for frame in 5: await get_tree().process_frame
		await RenderingServer.frame_post_draw
		viewport.get_texture().get_image().save_png(OUTPUT+"/"+str(entry.id)+".png")
		viewport.queue_free()
		await get_tree().process_frame
	print("Gravestone renders saved to ",OUTPUT)
	get_tree().quit()
