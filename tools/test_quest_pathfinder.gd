extends Node

const PathfinderScript = preload("res://scripts/world/quest_pathfinder.gd")

var _failed := false

func _ready() -> void:
	_run.call_deferred()


func _expect(condition: bool, message: String) -> bool:
	if condition:
		return true
	_failed = true
	push_error("[quest-pathfinder] " + message)
	get_tree().quit(1)
	return false


func _sample_for(blocked: Dictionary = {}, roads: Dictionary = {}, heights: Dictionary = {}) -> Callable:
	return func(world_xz: Vector2) -> Dictionary:
		var cell := Vector2i(floori(world_xz.x), floori(world_xz.y))
		return {passable = not blocked.has(cell), road = roads.has(cell), height = float(heights.get(cell, 0.0))}


func _solve(start: Vector3, goals: Array[Vector3], sample: Callable, bounds: Rect2i,
		expansions: int = 64, usec: int = 2000) -> RefCounted:
	var finder = PathfinderScript.new()
	finder.begin(start, goals, sample, bounds, 1.0)
	var calls := 0
	while not finder.finished and calls < 100000:
		finder.step(expansions, usec)
		calls += 1
	if calls >= 100000:
		_failed = true
		push_error("[quest-pathfinder] search did not finish")
		get_tree().quit(1)
	return finder


func _run() -> void:
	_test_roads()
	if _failed: return
	_test_mixed_speed_cost()
	if _failed: return
	_test_barrier_and_corners()
	if _failed: return
	_test_slope_and_unreachable()
	if _failed: return
	_test_goal_snap_and_multiple_goals()
	if _failed: return
	_test_time_slicing()
	if _failed: return
	print("[quest-pathfinder] all pathfinding cases passed")
	get_tree().quit(0)


func _test_roads() -> void:
	var roads := {}
	for x in range(1, 10):
		roads[Vector2i(x, 3)] = true
	var bounds := Rect2i(0, 0, 12, 5)
	var start := Vector3(1.5, 0, 1.5)
	var goals: Array[Vector3] = [Vector3(9.5, 0, 1.5)]
	var finder := _solve(start, goals, _sample_for({}, roads), bounds)
	if not _expect(finder.reached, "A safe road route should be found"): return
	if not _expect(finder.travel_cost < 8.0, "The longer road route should beat the short forest line in travel time"): return
	var used_road := false
	for point in finder.path:
		if roads.has(Vector2i(floori(point.x), floori(point.z))): used_road = true
	if not _expect(used_road, "The selected faster route should use the road cells"): return
	if not _expect(finder.path[-1].distance_to(goals[0]) < 0.01, "An exact walkable goal should be the route's final point"): return
	var distant_road := {}
	for x in range(1, 10): distant_road[Vector2i(x, 8)] = true
	var shortcut := _solve(start, goals, _sample_for({}, distant_road), Rect2i(0, 0, 12, 10))
	if not _expect(shortcut.reached and is_equal_approx(shortcut.travel_cost, 8.0),
		"A short forest crossing should beat an unnecessarily long road detour"): return


func _test_mixed_speed_cost() -> void:
	var roads := {Vector2i(0, 0): true}
	var goals: Array[Vector3] = [Vector3(2.5, 0, 0.5)]
	var finder := _solve(Vector3(0.5, 0, 0.5), goals, _sample_for({}, roads), Rect2i(0, 0, 3, 1))
	if not _expect(finder.reached, "A straight mixed road and forest route should be found"): return
	# The first edge has 0.5m on road and 0.5m in forest. Its cost is
	# 0.5/1.5 + 0.5, then the forest-only edge costs 1: total 11/6.
	if not _expect(is_equal_approx(finder.travel_cost, 11.0 / 6.0),
		"Road-to-forest transition cost should be 11/6, got %.6f" % finder.travel_cost): return


func _test_barrier_and_corners() -> void:
	var wall := {}
	for z in range(0, 7):
		wall[Vector2i(4, z)] = true
	var bounds := Rect2i(0, 0, 9, 8)
	var finder := _solve(Vector3(1.5, 0, 1.5), [Vector3(6.5, 0, 1.5)], _sample_for(wall), bounds)
	if not _expect(finder.reached, "The route should detour around a wall with an opening"): return
	var passed_gap := false
	for point in finder.path:
		if point.z >= 6.5: passed_gap = true
	if not _expect(passed_gap, "The wall detour should pass through its only opening"): return

	var corner_blocks := {Vector2i(1, 0): true, Vector2i(0, 1): true}
	var corner := _solve(Vector3(0.5, 0, 0.5), [Vector3(1.5, 0, 1.5)], _sample_for(corner_blocks), Rect2i(0, 0, 2, 2))
	if not _expect(not corner.reached, "A diagonal must not clip between two blocked orthogonal cells"): return
	var start_connector_sample := func(world_xz: Vector2) -> Dictionary:
		var blocked := world_xz.x >= 1.05 and world_xz.x <= 1.15
		return {passable = not blocked, road = false, height = 0.0}
	var blocked_start := _solve(Vector3(1.2, 0, 1.2), [Vector3(0.5, 0, 0.5)], start_connector_sample, Rect2i(0, 0, 1, 1))
	if not _expect(not blocked_start.reached, "Start snapping must refuse a blocked direct connector"): return

	# With 2m cells, inspect intermediate samples so a narrow obstacle cannot
	# be jumped over by a single coarse A* edge.
	var coarse_sample := func(world_xz: Vector2) -> Dictionary:
		var blocked := world_xz.x >= 2.0 and world_xz.x <= 2.5 and world_xz.y >= 0.5 and world_xz.y <= 1.5
		return {passable = not blocked, road = false, height = 0.0}
	var coarse = PathfinderScript.new()
	coarse.begin(Vector3(1.0, 0, 1.0), [Vector3(5.0, 0, 1.0)], coarse_sample, Rect2i(0, 0, 4, 2), 2.0)
	while not coarse.finished: coarse.step(32, 2000)
	if not _expect(coarse.reached, "The coarse search should route around a narrow obstacle"): return
	var avoided_subcell_block := false
	for point in coarse.path:
		if point.z >= 3.0: avoided_subcell_block = true
	if not _expect(avoided_subcell_block, "A 2m edge must sample around an intervening subcell obstacle"): return


func _test_slope_and_unreachable() -> void:
	var heights := {}
	for x in range(4, 9):
		for z in range(0, 5):
			heights[Vector2i(x, z)] = 3.0
	var slope := _solve(Vector3(1.5, 0, 2.5), [Vector3(7.5, 3, 2.5)], _sample_for({}, {}, heights), Rect2i(0, 0, 9, 5))
	if not _expect(not slope.reached, "A wall steeper than STEP_HEIGHT must block the route"): return

	var sealed := {}
	for z in range(8):
		sealed[Vector2i(4, z)] = true
	var unreachable := _solve(Vector3(1.5, 0, 2.5), [Vector3(7.5, 0, 2.5)], _sample_for(sealed), Rect2i(0, 0, 9, 8))
	if not _expect(not unreachable.reached and unreachable.path.is_empty(), "Unreachable search must return no partial path"): return


func _test_goal_snap_and_multiple_goals() -> void:
	var blocked_goal := {Vector2i(6, 2): true}
	var snap := _solve(Vector3(1.5, 0, 2.5), [Vector3(6.5, 0, 2.5)], _sample_for(blocked_goal), Rect2i(0, 0, 9, 5))
	if not _expect(snap.reached, "A blocked portal endpoint should snap to its clear nearby approach"): return
	var snapped_cell := Vector2i(floori(snap.path[-1].x), floori(snap.path[-1].z))
	if not _expect(snapped_cell != Vector2i(6, 2), "A snapped route must end on a passable cell"): return

	var goals: Array[Vector3] = [Vector3(9.5, 0, 1.5), Vector3(4.5, 0, 4.5)]
	var multi := _solve(Vector3(1.5, 0, 1.5), goals, _sample_for(), Rect2i(0, 0, 12, 7))
	if not _expect(multi.reached, "One of multiple goals should be reachable"): return
	if not _expect(multi.path[-1].distance_to(goals[1]) < multi.path[-1].distance_to(goals[0]),
		"The cheapest reachable goal should be selected"): return
	if not _expect(multi.path[-1].distance_to(goals[1]) < 0.01,
		"The selected exact goal should be appended to the path"): return


func _test_time_slicing() -> void:
	var blocked := {}
	for z in range(0, 8):
		if z != 6: blocked[Vector2i(5, z)] = true
	var start := Vector3(1.5, 0, 1.5)
	var goals: Array[Vector3] = [Vector3(9.5, 0, 1.5)]
	var sample := _sample_for(blocked)
	var bounds := Rect2i(0, 0, 11, 9)
	var batch := _solve(start, goals, sample, bounds, 4096, 100000)
	var sliced := _solve(start, goals, sample, bounds, 1, 1)
	if not _expect(batch.reached and sliced.reached, "Both time-slicing modes should find the route"): return
	if not _expect(is_equal_approx(batch.travel_cost, sliced.travel_cost), "Time slicing must preserve optimal travel cost"): return
	if not _expect(batch.path == sliced.path, "Time slicing must preserve deterministic path output"): return
	var capped = PathfinderScript.new()
	capped.begin(start, goals, _sample_for(), Rect2i(0, 0, 30, 30), 1.0)
	capped._node_limit = 8
	while not capped.finished: capped.step(100, 100000)
	if not _expect(not capped.reached and capped.path.is_empty(), "Node cap must finish without presenting a partial route"): return
