extends Node
## Headless check of Deep Dark dressing, streaming cleanup and client trails.
## godot --headless --path . res://tools/surface/check_deep_dark.tscn

var _failed := 0


func _ready() -> void:
	call_deferred("_check")


func _expect(ok: bool, message: String) -> void:
	if ok: return
	_failed += 1
	push_error("Deep Dark: " + message)


func _check() -> void:
	var world := IslandWorld.new({id = "deep_dark_check", seed = WorldServer.MAP_SEED, destroyed = []})
	var gen := world.generator
	var biome := Biomes.get_biome(Biomes.DEEP_DARK)
	var flora_uniforms: Array = SurfaceFlora.material().shader.get_shader_uniform_list().map(func(u: Dictionary) -> String: return u.name)
	var model_uniforms: Array = DeepDarkGlow.material().shader.get_shader_uniform_list().map(func(u: Dictionary) -> String: return u.name)
	_expect("trail_points" in flora_uniforms and "gr_count" in flora_uniforms, "flora shader did not compile")
	_expect("gr_count" in model_uniforms, "obstacle shader did not compile")
	_expect(biome.obstacles.has("surface/crystal_violet"), "the original pink cluster is missing")
	for name in biome.obstacles:
		var prefab := ObstacleLibrary.get_prefab(name)
		_expect(prefab.meshes_for(biome)[0] != null, "missing mesh for " + name)
		_expect(not prefab.collision_boxes.is_empty(), "missing obstacle collision for " + name)
	var best := Rect2i()
	var best_count := 0
	var obstacles := 0
	var trees := 0
	SurfaceFlora.prepare(gen.map)
	for z in range(-800, -400, 32):
		for x in range(400, 900, 32):
			if gen.map.cell_biome(x + 16, z + 16) != Biomes.DEEP_DARK: continue
			var area := Rect2i(x, z, 32, 32)
			var groups := {}
			var task := WorkerThreadPool.add_task(func() -> void: SurfaceFlora.gather(world, area, groups))
			WorkerThreadPool.wait_for_task_completion(task)
			var count := 0
			for kind: String in groups:
				for entry: Array in groups[kind]:
					var at: Vector3 = entry[0]
					if gen.map.cell_biome(floori(at.x), floori(at.z)) != Biomes.DEEP_DARK: continue
					_expect(gen.map.cell_flags(floori(at.x), floori(at.z)) & IslandGenerator.BUSY == 0, "plant on a path or clearing")
					_expect(kind in ["vox:surface/fine_deep_grass", "vox:surface/fine_deep_flowers", "vox:surface/fine_deep_fungus", "vox:surface/bush_deep", "vox:surface/fine_stone_dark"], "ordinary vegetation in Deep Dark: " + kind)
					count += 1
			if count > best_count:
				best_count = count
				best = area
			for site in gen.obstacle_sites(area, [], 0.0):
				if site.biome == Biomes.DEEP_DARK: obstacles += 1
			for site in gen.tree_sites(area, [], 0.0):
				if site.biome == Biomes.DEEP_DARK: trees += 1
	_expect(best_count > 500, "too little ground cover")
	_expect(obstacles > 50 and trees > 10, "missing obstacles or trees")
	# Keep the world off-tree, so the test only adds the client effect itself.
	var glow := DeepDarkGlow.new()
	glow.world = world
	add_child(glow)
	glow.set_process(false)
	var root := Node3D.new()
	add_child(root)
	var groups := {}
	SurfaceFlora.gather(world, best, groups)
	for kind: String in groups: SurfaceFlora.build_kind(root, kind, groups[kind], glow)
	var mesh_count := root.get_child_count()
	_expect(mesh_count == groups.size(), "plants must stay batched")
	_expect(glow._sources.size() >= 3, "plant batches did not register chatter")
	var at := Vector3(best.position.x + 16, 0, best.position.y + 16)
	at.y = gen.map.ground_y(at.x, at.z)
	for name: String in biome.obstacles:
		var obstacle := Obstacle.new().setup("", ObstacleLibrary.get_prefab(name), biome)
		obstacle.position = at
		root.add_child(obstacle)
		_expect(obstacle.find_children("*", "OmniLight3D").is_empty(), "extra obstacle light")
	glow._rng.seed = 7
	glow._chatter(at)
	_expect(not glow.ripples._ripples.is_empty(), "nearby plants did not chatter")
	var before := glow.ripples._ripples.size()
	glow._chatter(at + Vector3(400, 0, 400))
	_expect(glow.ripples._ripples.size() == before, "distant plants chattered")
	var player := Node3D.new()
	add_child(player)
	player.add_to_group("local_player")
	player.position = at
	glow._process(0.3)
	_expect(glow._trail_next == 1, "first trail sample missing")
	glow._process(0.3)
	_expect(glow._trail_next == 1, "standing still refreshed the trail")
	for i in 40:
		player.position = at + Vector3((i % 8) * 1.0, 0, 0)
		player.position.y = gen.map.ground_y(player.position.x, player.position.z)
		glow._process(0.3)
	_expect(glow._trail.size() == DeepDarkGlow.TRAIL_SIZE, "trail grew past its fixed buffer")
	player.position = Vector3.ZERO
	glow._process(0.3)
	var next := glow._trail_next
	glow._process(0.3)
	_expect(glow._trail_next == next, "trail recorded outside Deep Dark")
	glow._process(DeepDarkGlow.TRAIL_TIME + 0.3)
	for p in glow._trail:
		_expect(glow._now - p.w > DeepDarkGlow.TRAIL_TIME, "old trail did not expire")
	remove_child(root)
	root.free()
	_expect(glow._sources.is_empty(), "unloaded sources were retained")
	remove_child(glow)
	glow.free()
	_expect(SurfaceFlora.material().get_shader_parameter("trail_count") == 0, "trail survived leaving the Surface")
	player.free()
	world.gates.free()
	world.enemy_director.free()
	world.free()
	await _check_stream(at)
	print("Deep Dark %s: %d plants in best chunk, %d obstacles, %d trees, %d plant batches" % ["PASS" if _failed == 0 else "FAIL", best_count, obstacles, trees, mesh_count])
	get_tree().quit(0 if _failed == 0 else 1)


func _check_stream(at: Vector3) -> void:
	var world := IslandWorld.new({id = "deep_dark_stream_check", seed = WorldServer.MAP_SEED, destroyed = []})
	add_child(world)
	world.update_streaming(at, true)
	var sources := world.deep_dark_glow._sources.size()
	_expect(sources > 20, "streamed plants and obstacles did not register")
	_expect(GlowRipples.current == world.deep_dark_glow.ripples, "Surface glow controller is not active")
	world.update_streaming(world.spawn_point, true)
	_expect(world.deep_dark_glow._sources.is_empty(), "streamed sources survived unloading")
	# The dock's unused director is never added to its tree.
	if world.surface_ships and world.surface_ships.enemy_director.get_parent() == null:
		world.surface_ships.enemy_director.free()
	remove_child(world)
	world.free()
	await get_tree().process_frame
	await get_tree().process_frame
	print("Deep Dark stream: %d source batches registered and unloaded" % sources)
