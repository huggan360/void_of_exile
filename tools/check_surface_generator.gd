extends Node
## The C++ SurfaceVoxelGenerator must make exactly the voxels the GDScript
## IslandGenerator makes. Generates the same blocks with both and compares
## every voxel: random spots over the whole Surface, every feature cell,
## bridges and fences (overlays), towns, fortresses and the map's edges.
## godot --headless --path . res://tools/check_surface_generator.tscn [-- --blocks=4000]
## Needs an engine built with engine/modules (tools/release/build_templates.sh).
var gen: IslandGenerator
var native: VoxelGenerator
var checked := 0
var mixed := 0  # blocks holding both air and ground (not trivially equal)
var failed := 0

func _ready() -> void:
	if not ClassDB.class_exists(&"SurfaceVoxelGenerator"):
		print("CHECK FAIL this engine has no SurfaceVoxelGenerator (build it with engine/modules)")
		get_tree().quit(1)
		return
	gen = IslandGenerator.new(WorldServer.MAP_SEED)
	var started := Time.get_ticks_usec()
	native = gen.terrain_generator()
	print("CHECK configured in %.2f s" % ((Time.get_ticks_usec() - started) / 1e6))
	if native == gen:
		print("CHECK FAIL the C++ generator would not configure")
		get_tree().quit(1)
		return
	var count := 4000
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--blocks="): count = int(arg.get_slice("=", 1))
	var rng := RandomNumberGenerator.new()
	rng.seed = 2026
	# Random surface blocks anywhere (and a little beyond the map).
	for i in count:
		_check_column(Vector2i(rng.randi_range(-1100 * 4, 1100 * 4), rng.randi_range(-1100 * 4, 1100 * 4)), rng)
	# Every feature cell, a few blocks in each.
	for key: Vector2i in gen._shape_grid:
		for i in 3:
			_check_column(Vector2i((key.x << 6) + rng.randi_range(0, 63), (key.y << 6) + rng.randi_range(0, 63)), rng)
	# Bridges, rails, posts and fences.
	var keys: Array = gen.map.overlays.keys()
	for i in mini(count / 2, keys.size()):
		var key: Vector2i = keys[rng.randi_range(0, keys.size() - 1)]
		_check_column(key, rng)
	# Towns and fortresses.
	for v: VillageFeature in gen.villages:
		for i in 6: _check_column(Vector2i(v.center) * 4 + Vector2i(rng.randi_range(-160, 160), rng.randi_range(-160, 160)), rng)
	for s: StrongholdFeature in gen.strongholds:
		for i in 12: _check_column(Vector2i(s.center) * 4 + Vector2i(rng.randi_range(-200, 200), rng.randi_range(-200, 200)), rng)
	print("CHECK %s: %d blocks compared (%d with ground and air), %d differ" % ["PASS" if failed == 0 else "FAIL", checked, mixed, failed])
	get_tree().quit(0 if failed == 0 else 1)

## Every block of the column holding fine column `at` that isn't trivially
## air, from below the ground to above the tallest overlay or feature.
func _check_column(at: Vector2i, rng: RandomNumberGenerator) -> void:
	var origin := Vector2i(floori(at.x / 16.0) * 16, floori(at.y / 16.0) * 16)
	var span := gen.map.tile_range(origin.x, origin.y)
	var low := floori(span.x / 16.0) * 16 - 32
	var high := span.y + 112
	# One block below the ground keeps the check fast; all of them for every tenth column.
	var y := low if rng.randf() < 0.1 else maxi(low, floori(span.x / 16.0) * 16 - 16)
	while y <= high:
		_check(Vector3i(origin.x, y, origin.y))
		y += 16

func _check(origin: Vector3i) -> void:
	var a := VoxelBuffer.new()
	a.create(16, 16, 16)
	var b := VoxelBuffer.new()
	b.create(16, 16, 16)
	gen._generate_block(a, origin, 0)
	native.generate_block(b, Vector3(origin), 0)
	checked += 1
	if not a.is_uniform(VoxelBuffer.CHANNEL_TYPE): mixed += 1
	if VoxelBlockSerializer.serialize_to_byte_array(a, VoxelBlockSerializer.COMPRESSION_NONE) == VoxelBlockSerializer.serialize_to_byte_array(b, VoxelBlockSerializer.COMPRESSION_NONE):
		return
	# Byte layouts can differ for equal voxels (uniform vs. not): compare them.
	for y in 16:
		for z in 16:
			for x in 16:
				var va := a.get_voxel(x, y, z, VoxelBuffer.CHANNEL_TYPE)
				var vb := b.get_voxel(x, y, z, VoxelBuffer.CHANNEL_TYPE)
				if va != vb:
					failed += 1
					if failed <= 20:
						print("CHECK differ at voxel %s (block %s): GDScript %d, C++ %d" % [origin + Vector3i(x, y, z), origin, va, vb])
					return
