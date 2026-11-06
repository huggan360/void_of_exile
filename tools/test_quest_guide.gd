extends Node3D

class GuideWorld extends GameWorld:
	var walls: Array[Rect2] = [Rect2(-1, -5, 2, 10)]
	func ground_height(x: float, _z: float) -> float: return 1.0 if x > 20 else 0.0
	func is_walkable(p: Vector3) -> bool:
		for wall in walls:
			if wall.has_point(Vector2(p.x, p.z)): return false
		return true
	func is_road(p: Vector3) -> bool: return p.z > 7 and p.z < 11

var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(message)
func _ready() -> void: _run.call_deferred()
func _run() -> void:
	GameServer.set_physics_process(false)
	var world := GuideWorld.new()
	world.half_extent = 40
	add_child(world)
	var player := Player.new()
	player.stats = PlayerStats.new()
	add_child(player)
	player.set_physics_process(false)
	player.set_process(false)
	player.global_position = Vector3(-14.5, 0, 0.5)
	player.frozen = false
	var goals: Array[Dictionary] = [
		{pos = Vector3(14.5, 0, 0.5), kind = "quest"},
		{pos = Vector3(14.5, 0, 12.5), kind = "side"}]
	var guide := QuestGuide.new()
	add_child(guide)
	guide.set_process(false)
	guide.configure(world, player, func() -> Array: return goals)
	var minimap := Minimap.new()
	minimap.player = player
	add_child(minimap)
	minimap.set_process(false)
	guide.routes_changed.connect(minimap.set_routes)
	for frame in 1000:
		guide._process(0.016)
		if not guide._searching and not guide.main_path.is_empty(): break
	check(not guide.main_path.is_empty() and not guide.side_path.is_empty(), "Both quest kinds produce routes")
	check(guide.segment_clear(guide.main_path[0], guide.main_path[1]), "Route starts with a clear player connector")
	var safe := true
	for i in range(guide.main_path.size() - 1): safe = safe and guide.segment_clear(guide.main_path[i], guide.main_path[i + 1])
	check(safe, "Every displayed segment avoids the wall and respects height")
	check(minimap.main_route == guide.main_path and minimap.side_route == guide.side_path, "Minimap and world guide share the same routes")
	var consumed := guide.main_path[mini(8, guide.main_path.size() - 1)]
	player.global_position = consumed
	guide._process(0.2)
	check(guide.main_path[0].distance_to(consumed) < 1, "Passed route disappears behind the player")
	minimap._center = Vector2(consumed.x, consumed.z)
	var yellow := minimap.route_pixels(guide.main_path)
	check(not yellow.is_empty(), "Route rasterizes into visible map pixels")
	var radius := Minimap.ART_PIXELS * 0.5 * Minimap.MAP_EDGE - 2.0
	check(yellow.keys().all(func(p: Vector2i) -> bool: return Vector2(p).length() <= radius), "Minimap route is clipped inside the frame")
	check(QuestTrail.overlaps_main(guide.main_path[0], guide.main_path), "Shared trail sections can suppress green below yellow")
	var sparse := PackedVector3Array([Vector3(0, 0, 0), Vector3(5, 0, 0)])
	check(not QuestTrail.overlaps_main(Vector3(1, 0, 2), sparse), "Distinct side paths remain visible")
	minimap.set_routes(guide.main_path, guide.main_path)
	var shared := minimap.visible_route_pixels()
	check(not shared.main.is_empty() and shared.side.is_empty(), "Yellow fully replaces overlapping green minimap pixels")
	minimap.set_routes(PackedVector3Array(), guide.side_path)
	check(not minimap.visible_route_pixels().side.is_empty(), "A distinct green minimap route remains visible")
	guide.invalidate()
	check(guide.main_path.is_empty() and minimap.main_route.is_empty(), "Geometry change clears obsolete routes")
	goals.clear()
	guide._process(1)
	check(guide._main_goals.is_empty() and guide._side_goals.is_empty(), "Completing a quest clears its targets")
	var obstacle := StaticBody3D.new()
	obstacle.collision_layer = Player.OBSTACLE_LAYER
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2, 3, 2)
	shape.shape = box
	shape.position.y = 1.5
	obstacle.add_child(shape)
	world.add_child(obstacle)
	obstacle.position = Vector3(-10, 0, 15)
	await get_tree().physics_frame
	await get_tree().physics_frame
	guide._sample_cache.clear()
	check(not guide.sample(Vector2(-10, 15)).passable, "Actual tree/prop colliders block the capsule probe")
	check(guide.sample(Vector2(-7, 15)).passable, "Open ground beside the obstacle remains passable")
	guide._trail.set_routes(PackedVector3Array([player.global_position, player.global_position]), PackedVector3Array(), player.global_position)
	check(guide._trail.mesh.get_surface_count() == 0, "An entirely consumed trail does not create an empty mesh surface")
	# A sealed side objective must not hold the main quest's result hostage.
	world.walls.append_array([Rect2(18, -8, 1, 16), Rect2(31, -8, 1, 16), Rect2(18, -8, 14, 1), Rect2(18, 7, 14, 1)])
	goals.append({pos = Vector3(-14.5, 0, 8.5), kind = "quest"})
	goals.append({pos = Vector3(25.5, 1, 0.5), kind = "side"})
	guide.configure(world, player, func() -> Array: return goals)
	for frame in 100:
		guide._process(0.016)
		if not guide.main_path.is_empty(): break
	check(not guide.main_path.is_empty() and guide._searching, "Main route is published while a blocked side route is still being searched")
	guide.free()
	minimap.free()
	world.queue_free()
	player.queue_free()
	await get_tree().process_frame
	print("QUEST GUIDE: %d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures else 0)
