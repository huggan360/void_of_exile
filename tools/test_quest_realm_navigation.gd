extends Node
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(message)
func _ready() -> void: _run.call_deferred()
func _run() -> void:
	GameServer.set_physics_process(false)
	var island := IslandWorld.new({id = "quest_guide_fixture", seed = 4217, destroyed = []})
	# Intentionally keep the world outside the tree: no streamed collider can
	# help this test. Navigation must use the immutable obstacle plans.
	var player := Player.new()
	var guide := QuestGuide.new()
	add_child(guide)
	guide.set_process(false)
	guide.configure(island, player, Callable())
	var sites := island.generator.obstacle_sites(Rect2i(-180, -180, 360, 360), island._keep_clear, island.KEEP_CLEAR_RADIUS)
	var detected := false
	var released := false
	for site: Dictionary in sites:
		var prefab := ObstacleLibrary.get_prefab(str(site.prefab))
		if prefab.collision_boxes.is_empty(): continue
		var box: AABB = prefab.collision_boxes[0]
		var center: Vector3 = Transform3D(Basis(Vector3.UP, site.yaw), site.pos) * box.get_center()
		var point := Vector2(center.x, center.z)
		guide._sample_cache.clear()
		guide._box_cache.clear()
		if guide.sample(point).passable: continue
		detected = true
		island._destroyed[site.id] = true
		guide._sample_cache.clear()
		guide._box_cache.clear()
		if guide.sample(point).passable:
			released = true
			break
	check(detected, "A planned tree/prop blocks navigation before streaming")
	check(released, "Destroyed obstacle data opens the planned route")
	var building_blocked := false
	for buildings: Array in island._buildings_by_chunk.values():
		for spec: Dictionary in buildings:
			guide._sample_cache.clear()
			if not guide.sample(Vector2(spec.pos.x, spec.pos.z)).passable:
				building_blocked = true
				break
		if building_blocked: break
	check(building_blocked, "Town buildings block the route without loaded colliders")
	check(not guide.sample(Vector2(island.half_extent + 1, 0)).passable, "Navigation does not leave the world bounds")
	if "--benchmark" in OS.get_cmdline_user_args():
		var start := island.spawn_point
		var goal := start + Vector3(80, 0, 0)
		goal.y = island.ground_height(goal.x, goal.z)
		var finder := QuestPathfinder.new()
		var begun := Time.get_ticks_usec()
		finder.begin(start, [goal], guide.sample, Rect2i(-1100, -1100, 2200, 2200), 1.0)
		var begin_ms := (Time.get_ticks_usec() - begun) / 1000.0
		var slowest := 0
		var slices := 0
		while not finder.finished and Time.get_ticks_usec() - begun < 10000000:
			var tick := Time.get_ticks_usec()
			finder.step(128, 2000)
			slowest = maxi(slowest, Time.get_ticks_usec() - tick)
			slices += 1
		print("REALM ROUTE BENCH begin_ms=", begin_ms, " total_ms=", (Time.get_ticks_usec() - begun) / 1000.0,
			" max_slice_ms=", slowest / 1000.0, " reached=", finder.reached, " nodes=", finder._g_score.size(), " slices=", slices)
	print("QUEST REALM NAVIGATION: %d checks, %d failures" % [checks, failures])
	guide.free()
	player.free()
	island.gates.free()
	island.enemy_director.free()
	island.free()
	get_tree().quit(1 if failures else 0)
