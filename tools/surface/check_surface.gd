extends Node
## Headless smoke test of the Surface: builds the world plan, voxel blocks,
## trees, ground cover and water, and times them.
## Run: godot --headless --path . res://tools/surface/check_surface.tscn

func _ready() -> void:
	var t := Time.get_ticks_msec()
	var gen := IslandGenerator.new(WorldServer.MAP_SEED)
	print("plan: %d ms, %d villages, %d forts, %d features, %d lamps" % [Time.get_ticks_msec() - t, gen.villages.size(),
		gen.strongholds.size(), gen.features.size(), gen.lamp_sites().size()])
	var spawn: Vector3 = gen.find_spawn()[0]
	print("spawn ", spawn)
	t = Time.get_ticks_usec()
	var blocks := 0
	var solid := 0
	var buf := VoxelBuffer.new()
	var origin := Vector3i(floori(spawn.x * 4) & ~15, 0, floori(spawn.z * 4) & ~15)
	for y in range(0, 160, 16):
		for z in range(-64, 64, 16):
			for x in range(-64, 64, 16):
				buf.create(16, 16, 16)
				gen._generate_block(buf, origin + Vector3i(x, y, z), 0)
				blocks += 1
				if not buf.is_uniform(VoxelBuffer.CHANNEL_TYPE) or buf.get_voxel(0, 0, 0, VoxelBuffer.CHANNEL_TYPE) != 0: solid += 1
	print("blocks: %d (%d not empty) in %.1f ms (%.2f ms each)" % [blocks, solid, (Time.get_ticks_usec() - t) / 1000.0, (Time.get_ticks_usec() - t) / 1000.0 / blocks])
	var fort := gen.strongholds[0]
	t = Time.get_ticks_usec()
	for y in range(int(fort.base_height) * 4 - 16, int(fort.base_height) * 4 + 64, 16):
		for z in range(0, 64, 16):
			for x in range(0, 64, 16):
				buf.create(16, 16, 16)
				gen._generate_block(buf, Vector3i(fort.center.x * 4 + x, y, fort.center.y * 4 + z), 0)
	print("fortress blocks: %.1f ms" % ((Time.get_ticks_usec() - t) / 1000.0))
	var area := Rect2i(Vector2i(spawn.x, spawn.z) + Vector2i(40, 40), Vector2i(32, 32))
	t = Time.get_ticks_usec()
	var trees := gen.tree_sites(area, [], 0.0)
	print("trees: %d in %.1f ms" % [trees.size(), (Time.get_ticks_usec() - t) / 1000.0])
	t = Time.get_ticks_usec()
	var obstacles := gen.obstacle_sites(area, [], 0.0)
	print("obstacles: %d in %.1f ms" % [obstacles.size(), (Time.get_ticks_usec() - t) / 1000.0])
	var world := IslandWorld.new({id = "realm_1", seed = WorldServer.MAP_SEED, destroyed = []})
	add_child(world)
	t = Time.get_ticks_usec()
	var groups := {}
	for z in range(0, 32, 8):
		for x in range(0, 32, 8):
			SurfaceFlora.gather(world, Rect2i(area.position + Vector2i(x, z), Vector2i(8, 8)), groups)
	var count := 0
	for k in groups: count += groups[k].size()
	print("flora: %d plants of %d kinds in %.1f ms" % [count, groups.size(), (Time.get_ticks_usec() - t) / 1000.0])
	t = Time.get_ticks_usec()
	var root := Node3D.new()
	world.add_child(root)
	SurfaceFlora.build(root, groups)
	SurfaceFlora.build_trees(world, root, area, true)
	print("flora meshes: %.1f ms" % ((Time.get_ticks_usec() - t) / 1000.0))
	var wet := 0
	t = Time.get_ticks_usec()
	for cz in range(-8, 8):
		for cx in range(-8, 8):
			if SurfaceWater.build_chunk(gen.map, Rect2i(Vector2i(cx, cz) * 32, Vector2i(32, 32))): wet += 1
	print("water: %d of 256 chunks wet, %.1f ms" % [wet, (Time.get_ticks_usec() - t) / 1000.0])
	t = Time.get_ticks_usec()
	world.update_streaming(spawn, true)
	print("stream around spawn: %.1f ms, %d chunks" % [(Time.get_ticks_usec() - t) / 1000.0, world._chunks.size()])
	print("ground at spawn %.2f, walkable %s, road %s, biome %s" % [world.ground_height(spawn.x, spawn.z), world.is_walkable(spawn),
		world.is_road(spawn), world.biome_at(spawn).biome_name])
	get_tree().quit()
