extends Node3D
## Run with the voxel editor binary, no --headless, to write /tmp/castle_*.png.
## Pass -- --offset to exercise a cinematic stage inside an unrelated parent.
func _ready() -> void:
	var castle := CastleWorld.stage() as CastleWorld
	var offset := Vector3(0, -600, 0) if "--offset" in OS.get_cmdline_user_args() else Vector3.ZERO
	var parent := Node3D.new()
	parent.position = offset
	add_child(parent)
	parent.add_child(castle)
	var environment := WorldEnvironment.new()
	environment.environment = preload("res://scenes/castle/castle_environment.tres")
	add_child(environment)
	var moon := DirectionalLight3D.new()
	moon.rotation_degrees = Vector3(-56, -28, 0)
	moon.light_color = Color(0.78, 0.84, 0.96)
	moon.light_energy = 0.8
	moon.shadow_enabled = true
	moon.directional_shadow_max_distance = 230
	add_child(moon)
	var camera := Camera3D.new()
	camera.far = 500
	camera.fov = 65
	camera.current = true
	add_child(camera)
	var viewer := VoxelViewer.new()
	viewer.view_distance = 240
	viewer.position = offset
	add_child(viewer)
	# Check authored route, obstacles, stairs and offset-safe anchor transforms.
	for z in range(-66, 80):
		assert(castle.is_walkable(Vector3(0.5, 0, z + 0.5)), "Blocked central route at %s" % z)
	assert(not castle.is_walkable(Vector3(12, 0, 65)), "Chasm must not be walkable")
	assert(not castle.is_walkable(Vector3(14.5, 0, -8)), "Pillars must block navigation")
	assert(is_equal_approx(castle.ground_height(40, 0), 2))
	assert(castle.get_node("BossSpot").global_position.is_equal_approx(offset + Vector3(0, 0, -51)))
	for side in [-1, 1]:
		for j in range(5):
			var x: float = side * (22.5 + j)
			assert(castle.is_walkable(Vector3(x, 0, 7)), "Chapel stair route blocked")
			assert(is_equal_approx(castle.ground_height(x, 7), 1.0 if j < 3 else 2.0), "Stair height mismatch")
	await get_tree().create_timer(5).timeout
	await get_tree().physics_frame
	# Verify actual baked collision against the query API, including the stair.
	for sample: Vector3 in [Vector3(0.5, 0, 78.5), Vector3(22.5, 1, 7.5), Vector3(26.5, 2, 7.5), Vector3(0.5, 0, -51.5)]:
		var at := offset + sample
		var query := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 3, at - Vector3.UP * 3, 1)
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		assert(not hit.is_empty(), "Missing baked terrain collision at %s" % sample)
		assert(absf(hit.position.y - at.y) < 0.05, "Baked collision height differs at %s" % sample)
	if DisplayServer.get_name() == "headless":
		print("[castle] Headless scene / route / stage checks passed")
		get_tree().quit()
		return
	var shots := [{id = "overview", from = Vector3(92, 104, 112), look = Vector3(0, 7, -2)}]
	for shot in ["Bridge", "Hall", "Throne"]:
		shots.append({id = shot.to_lower(), from = castle.get_node("Shot" + shot + "From").position.lerp(castle.get_node("Shot" + shot + "To").position, .35), look = castle.get_node("Shot" + shot + "Look").position})
	for shot in shots:
		camera.fov = 50 if shot.id == "overview" else 65
		camera.global_position = offset + shot.from
		camera.look_at(offset + shot.look)
		await get_tree().create_timer(1).timeout
		await RenderingServer.frame_post_draw
		var path: String = "/tmp/castle_" + shot.id + ".png"
		get_viewport().get_texture().get_image().save_png(path)
		print("[castle] ", path)
	get_tree().quit()
