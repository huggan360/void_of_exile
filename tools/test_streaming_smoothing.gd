extends Node3D

var failures := 0
var checks := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func snap(t: float, x: float, speed := 1.0, flags := 0) -> Array:
	return [t, PackedFloat32Array([1, x, 0, 0, 0, speed, flags])]

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	GameServer.set_physics_process(false)
	var buffer: Array = [snap(1.0, 0.0), snap(1.05, 0.5)]
	check(is_equal_approx(NetClient._sample_player(buffer, 1.025)[0].x, 0.25), "Snapshots interpolate")
	var predicted: Vector3 = NetClient._sample_player(buffer, 1.10)[0]
	check(predicted.x > 0.5 and predicted.x <= 1.0, "Brief loss predicts a bounded distance")
	var held: Array = NetClient._sample_player(buffer, 5.0)
	check(is_equal_approx(held[0].x, 1.0) and held[2] == 0.0, "Long outage holds position and stops walking animation")
	check(NetClient._sample_player(buffer, 50.0)[0] == held[0], "Prediction cannot drift over time")
	NetClient._push(buffer, snap(1.01, -100.0))
	check(buffer.size() == 2, "Old packets cannot reverse time")
	var teleport: Array = [snap(1.0, 0.0), snap(1.05, 100.0)]
	check(NetClient._sample_player(teleport, 1.025)[0].x == 0.0, "Teleport does not sweep through world")
	check(NetClient._sample_player(teleport, 1.10)[0].x == 100.0, "Teleport is never extrapolated")
	var frozen: Array = [snap(1.0, 0.0), snap(1.05, 0.5, 1.0, 2)]
	check(NetClient._sample_player(frozen, 1.1)[0].x == 0.5, "Frozen players do not predict")
	check(NetClient._sample_player([snap(1.0, 2.0)], 5.0)[2] == 0.0, "A lone stale snapshot also stops animation")
	var fast: Array = [snap(1.0, 0.0), snap(1.01, 5.0)]
	check(NetClient._sample_player(fast, 10.0)[0].x <= 6.0, "Velocity spikes have a one metre prediction cap")
	NetClient._push(buffer, snap(1.10, 0.8))
	check(is_equal_approx(NetClient._sample_player(buffer, 1.075)[0].x, 0.65), "Fresh packets restore interpolation")
	var world := IslandWorld.new({id = "stream_test", seed = 12345, destroyed = []})
	# Build real terrain and chunk content without running enemy simulation.
	world.enemy_director.remote = true
	add_child(world)
	world.set_process(false)
	world.enemy_director.set_process(false)
	var c := world._chunk_of(world.spawn_point + Vector3(96, 0, 64))
	var expected := {}
	for site in world.generator.obstacle_sites(Rect2i(c * 32, Vector2i(32, 32)), world._keep_clear, world.KEEP_CLEAR_RADIUS):
		expected[site.id] = true
	world._queue.assign([c])
	var frames := 0
	var peak := 0
	while not world._queue.is_empty() or not world._build_steps.is_empty():
		var start := Time.get_ticks_usec()
		world._build_queued(false)
		peak = maxi(peak, Time.get_ticks_usec() - start)
		frames += 1
	check(world._chunks.size() == 1, "Chunk builds to completion")
	check(world._obstacles.size() == expected.size(), "Tiled generation preserves obstacle count")
	for id: String in expected: check(world._obstacles.has(id), "Tiled generation preserves obstacle " + id)
	var groups := {}
	var area := Rect2i(c * 32, Vector2i(32, 32))
	for z in range(0, 32, 8):
		for x in range(0, 32, 8):
			world._gather_decor(groups, Rect2i(area.position + Vector2i(x, z), Vector2i(8, 8)))
	var original := world.generator.decor_sites(area)
	check(groups.size() == original.size(), "Tiled decor preserves groups and draw call count")
	for key: String in original:
		check(groups[key].size() == original[key].size(), "Tiled decor preserves instance counts")
		for transform: Transform3D in original[key]:
			check(groups[key].has(transform), "Tiled decor preserves placement")
	var guide := QuestGuide.new()
	guide.world = world
	for i in guide.MAX_COLUMN_CACHE:
		var cell := Vector2i(100000 + i, 100000)
		guide._column_order.append(cell)
		guide._column_cache[cell] = {}
	guide._island_column(Vector2.ZERO)
	check(guide._column_cache.size() == guide.MAX_COLUMN_CACHE, "Column cache has a hard size limit")
	check(not guide._column_cache.has(Vector2i(100000, 100000)), "Old columns are evicted")
	for i in guide.MAX_BOX_CACHE:
		var cell := Vector2i(100000 + i, 100000)
		guide._box_cache[cell] = []
		guide._box_grid[cell] = {}
	guide._island_boxes(c)
	check(guide._box_cache.size() == guide.MAX_BOX_CACHE and guide._box_grid.size() == guide.MAX_BOX_CACHE, "Navigation box caches are evicted together")
	guide.invalidate()
	check(guide._column_order.is_empty() and guide._column_cursor == 0, "World invalidation resets eviction bookkeeping")
	guide.free()
	world._start_chunk(c + Vector2i(1, 0))
	world._prune_chunks({c: true}, false)
	check(world._build_steps.is_empty(), "Unloading partial chunk cancels pending work")
	world._prune_chunks({}, false)
	check(world._chunks.is_empty() and world._obstacles.is_empty(), "Unloading releases chunks and obstacle references")
	print("STREAMING: %d build frames, peak step batch %.2f ms" % [frames, peak / 1000.0])
	world.server_build = true
	world.update_streaming_multi([world.spawn_point], false)
	check(world._server_want.size() == 81, "Server requests the neighborhood of occupied chunks")
	check(world._chunks.has(world._chunk_of(world.spawn_point)), "Server builds the nearest chunk first")
	world.update_streaming_multi([world.spawn_point + Vector3(0.1, 0, 0.1)], false)
	check(world._server_centers.size() == 1, "Movement inside a chunk reuses server streaming centers")
	world.update_streaming_multi([], false)
	while not world._chunks.is_empty(): world.update_streaming_multi([], false)
	check(world._queue.is_empty() and world._build_steps.is_empty(), "Empty server realm drains loaded and pending chunks")
	world.queue_free()
	await get_tree().process_frame
	print("STREAMING AND SMOOTHING: %d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures else 0)
