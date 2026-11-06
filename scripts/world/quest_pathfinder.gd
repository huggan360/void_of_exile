class_name QuestPathfinder
extends RefCounted
## Incremental A* for safe, travel-time routes across sampled world cells.
## `bounds` uses integer cell coordinates. A cell (x, z) is sampled at the
## world-space center ((x + 0.5) * cell_size, (z + 0.5) * cell_size).

const STEP_HEIGHT := Player.STEP_HEIGHT
const ROAD_SPEED := Player.ROAD_SPEED
const MAX_SNAP_DISTANCE := 3.0
const MAX_DISCOVERED_NODES := 250000
const NEIGHBORS := [
	Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1),
	Vector2i(-1, 0), Vector2i(1, 0),
	Vector2i(-1, 1), Vector2i(0, 1), Vector2i(1, 1),
]

## Walkable cell centers, preceded by the supplied start. The last point is
## the selected walkable snap cell near a goal (the goal itself may be blocked).
var path := PackedVector3Array()
var finished := true
var reached := false
var travel_cost := INF

var _sample: Callable
var _bounds := Rect2i()
var _cell_size := 2.0
var _width := 0
var _height := 0
var _samples := {}  # linear cell id -> {passable, height, road}
var _g_score := {}  # cell id -> seconds-equivalent route cost
var _parent := {}  # cell id -> preceding cell id, -1 for start
var _closed := {}
var _heap: Array[int] = []
var _heap_pos := {}  # cell id -> heap index
var _goals := {}  # cell id -> [{cost, index}]
var _goal_points: Array[Vector3] = []
var _best_goal_id := -1
var _best_goal_cost := INF
var _best_goal_exact := false
var _best_goal_point := Vector3.ZERO
var _start := Vector3.ZERO
var _start_id := -1
var _node_limit := MAX_DISCOVERED_NODES


## Starts (or restarts) a search. The callback receives world XZ and returns
## {passable: bool, height: float, road: bool}. Bounds are integer cell indices.
func begin(start: Vector3, goals: Array[Vector3], sample: Callable, bounds: Rect2i,
		cell_size: float = 2.0) -> void:
	_reset()
	_sample = sample
	_bounds = bounds
	_cell_size = cell_size
	_start = start
	_goal_points = goals.duplicate()
	_width = bounds.size.x
	_height = bounds.size.y
	if not sample.is_valid() or cell_size <= 0.0 or _width <= 0 or _height <= 0 or goals.is_empty():
		finished = true
		return

	var start_candidates := _snap_candidates(start, false)
	if start_candidates.is_empty():
		finished = true
		return
	# The closest clear connector is the only start. This avoids using endpoint
	# snapping as a way to hop across an obstacle.
	start_candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.cost) < float(b.cost))
	var start_entry: Dictionary = start_candidates[0]
	_start_id = int(start_entry.id)
	_g_score[_start_id] = float(start_entry.cost)
	_parent[_start_id] = -1
	_heap_push_or_decrease(_start_id)

	for goal_index in goals.size():
		var goal: Vector3 = goals[goal_index]
		for candidate: Dictionary in _snap_candidates(goal, true):
			var id := int(candidate.id)
			if not _goals.has(id):
				_goals[id] = []
				_goals[id].append({cost = float(candidate.cost), index = goal_index,
						exact_goal = bool(candidate.get("exact_goal", false))})
			else:
				var entries: Array = _goals[id]
				var duplicate := false
				for entry: Dictionary in entries:
					if int(entry.index) == goal_index:
						duplicate = true
						if float(candidate.cost) < float(entry.cost):
							entry.cost = float(candidate.cost)
							entry.exact_goal = bool(candidate.get("exact_goal", false))
						break
				if not duplicate:
					entries.append({cost = float(candidate.cost), index = goal_index,
						exact_goal = bool(candidate.get("exact_goal", false))})

	if _goals.is_empty():
		_heap.clear()
		finished = true
		return
	finished = false


## Expands at most the requested count or time, whichever comes first.
## Returns true once the search has a final result.
func step(max_expansions: int = 64, max_usec: int = 2000) -> bool:
	if finished:
		return true
	var limit := maxi(1, max_expansions)
	var budget := maxi(1, max_usec)
	var started := Time.get_ticks_usec()
	var expanded := 0
	while expanded < limit and (expanded == 0 or Time.get_ticks_usec() - started < budget):
		if _heap.is_empty():
			_finish_best()
			return true
		if _best_goal_id >= 0 and _heap_priority(int(_heap[0])) >= _best_goal_cost:
			_finish_best()
			return true

		var current := _heap_pop()
		if _closed.has(current):
			continue
		_closed[current] = true
		expanded += 1
		_consider_goal(current)
		var current_cell := _cell_from_id(current)
		var current_sample: Dictionary = _sample_cell(current)
		for offset: Vector2i in NEIGHBORS:
			var next_cell := current_cell + offset
			if not _inside(next_cell):
				continue
			var next_id := _id(next_cell)
			if _closed.has(next_id):
				continue
			var next_sample: Dictionary = _sample_cell(next_id)
			if not bool(next_sample.passable):
				continue
			if absf(float(next_sample.height) - float(current_sample.height)) > STEP_HEIGHT:
				continue
			var edge := _edge_profile(current_cell, current_sample, next_cell, next_sample)
			if not bool(edge.clear):
				continue
			if offset.x != 0 and offset.y != 0 and not _diagonal_clear(current_cell, current_sample, next_cell, next_sample):
				continue
			var tentative := float(_g_score[current]) + float(edge.cost)
			if tentative + 0.000001 >= float(_g_score.get(next_id, INF)):
				continue
			_g_score[next_id] = tentative
			_parent[next_id] = current
			if not _heap_pos.has(next_id) and _g_score.size() > _node_limit:
				# Do not expose the best-so-far as if it were an optimal route.
				path = PackedVector3Array()
				reached = false
				travel_cost = INF
				finished = true
				return true
			_heap_push_or_decrease(next_id)

	return finished


## Abandons the current search and discards any result.
func cancel() -> void:
	_reset()


func _reset() -> void:
	path = PackedVector3Array()
	finished = true
	reached = false
	travel_cost = INF
	_sample = Callable()
	_bounds = Rect2i()
	_cell_size = 2.0
	_width = 0
	_height = 0
	_samples.clear()
	_g_score.clear()
	_parent.clear()
	_closed.clear()
	_heap.clear()
	_heap_pos.clear()
	_goals.clear()
	_goal_points.clear()
	_best_goal_id = -1
	_best_goal_cost = INF
	_best_goal_exact = false
	_best_goal_point = Vector3.ZERO
	_start = Vector3.ZERO
	_start_id = -1
	_node_limit = MAX_DISCOVERED_NODES


func _snap_candidates(endpoint: Vector3, allow_blocked_endpoint: bool) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var endpoint_sample := _sample_world(Vector2(endpoint.x, endpoint.z))
	var endpoint_passable := bool(endpoint_sample.passable)
	if not allow_blocked_endpoint and not endpoint_passable:
		return result
	var origin := Vector2i(roundi(endpoint.x / _cell_size - 0.5), roundi(endpoint.z / _cell_size - 0.5))
	if allow_blocked_endpoint and endpoint_passable and _inside(origin):
		var primary_id := _id(origin)
		var primary := _sample_cell(primary_id)
		if bool(primary.passable):
			var center := _center(origin, float(primary.height))
			var profile := _connector_profile(endpoint, center)
			if absf(center.y - endpoint.y) <= STEP_HEIGHT and bool(profile.clear):
				result.append({id = primary_id, cost = float(profile.cost), exact_goal = true})
				return result
	var radius := ceili(MAX_SNAP_DISTANCE / _cell_size) + 1
	for z in range(origin.y - radius, origin.y + radius + 1):
		for x in range(origin.x - radius, origin.x + radius + 1):
			var cell := Vector2i(x, z)
			if not _inside(cell):
				continue
			var id := _id(cell)
			var record := _sample_cell(id)
			if not bool(record.passable):
				continue
			var center := _center(cell, float(record.height))
			var horizontal_distance := Vector2(center.x - endpoint.x, center.z - endpoint.z).length()
			if horizontal_distance > MAX_SNAP_DISTANCE:
				continue
			if absf(center.y - endpoint.y) > STEP_HEIGHT:
				continue
			if allow_blocked_endpoint:
				# Blocked goals denote an approach radius, not a straight-line move
				# through the obstruction to the target.
				result.append({id = id, cost = 0.0, exact_goal = false})
			else:
				var profile := _connector_profile(endpoint, center)
				if bool(profile.clear):
					result.append({id = id, cost = float(profile.cost), exact_goal = false})
	return result


func _connector_profile(from: Vector3, to: Vector3) -> Dictionary:
	var from_record := _sample_world(Vector2(from.x, from.z))
	var to_record := _sample_world(Vector2(to.x, to.z))
	if not bool(from_record.passable) or not bool(to_record.passable):
		return {clear = false, cost = INF}
	return _sampled_profile(from, to, from_record, to_record, true)


func _sample_cell(id: int) -> Dictionary:
	if _samples.has(id):
		return _samples[id]
	var cell := _cell_from_id(id)
	var position := _center(cell, 0.0)
	var record := _sample_world(Vector2(position.x, position.z))
	record.height = float(record.get("height", 0.0))
	record.passable = bool(record.get("passable", false))
	record.road = bool(record.get("road", false))
	_samples[id] = record
	return record


func _sample_world(world_xz: Vector2) -> Dictionary:
	var value: Variant = _sample.call(world_xz)
	return value if value is Dictionary else {passable = false, height = 0.0, road = false}


func _diagonal_clear(from_cell: Vector2i, from_sample: Dictionary, to_cell: Vector2i, to_sample: Dictionary) -> bool:
	var horizontal_a := _sample_cell(_id(Vector2i(to_cell.x, from_cell.y)))
	var horizontal_b := _sample_cell(_id(Vector2i(from_cell.x, to_cell.y)))
	if not bool(horizontal_a.passable) or not bool(horizontal_b.passable):
		return false
	for side: Dictionary in [horizontal_a, horizontal_b]:
		if absf(float(side.height) - float(from_sample.height)) > STEP_HEIGHT \
				or absf(float(side.height) - float(to_sample.height)) > STEP_HEIGHT:
			return false
	return true


## Sample each transition, not only its endpoints. Coarse cells can otherwise
## leap over a narrow obstacle or a steep intermediate height change.
func _edge_profile(from_cell: Vector2i, from_sample: Dictionary, to_cell: Vector2i, to_sample: Dictionary) -> Dictionary:
	var from_position := _center(from_cell, float(from_sample.height))
	var to_position := _center(to_cell, float(to_sample.height))
	return _sampled_profile(from_position, to_position, from_sample, to_sample, false)


## Integrate reciprocal speed over <=0.5m pieces. This models a boundary
## crossed halfway through a road-to-forest edge by its actual distance on
## each surface, instead of dividing by the mean speed of the endpoints.
func _sampled_profile(from: Vector3, to: Vector3, from_record: Dictionary, to_record: Dictionary,
		check_connector_corners: bool) -> Dictionary:
	var horizontal_distance := Vector2(to.x - from.x, to.z - from.z).length()
	var count := maxi(1, ceili(horizontal_distance / 0.5))
	var previous_cell := Vector2i(floori(from.x / _cell_size), floori(from.z / _cell_size))
	var previous_height := float(from_record.get("height", from.y))
	var previous_position := Vector3(from.x, previous_height, from.z)
	var cost := 0.0
	for i in range(1, count + 1):
		var midpoint_t := (float(i) - 0.5) / float(count)
		var end_t := float(i) / float(count)
		var midpoint := from.lerp(to, midpoint_t)
		var midpoint_record := _sample_world(Vector2(midpoint.x, midpoint.z))
		var endpoint := from.lerp(to, end_t)
		var endpoint_cell := Vector2i(floori(endpoint.x / _cell_size), floori(endpoint.z / _cell_size))
		var endpoint_record: Dictionary = to_record if i == count else _sample_world(Vector2(endpoint.x, endpoint.z))
		if not bool(midpoint_record.get("passable", false)) or not bool(endpoint_record.get("passable", false)):
			return {clear = false, cost = INF}
		var midpoint_height := float(midpoint_record.get("height", previous_height))
		var endpoint_height := float(endpoint_record.get("height", midpoint_height))
		if absf(midpoint_height - previous_height) > STEP_HEIGHT \
				or absf(endpoint_height - midpoint_height) > STEP_HEIGHT:
			return {clear = false, cost = INF}
		var midpoint_surface := Vector3(midpoint.x, midpoint_height, midpoint.z)
		var endpoint_surface := Vector3(endpoint.x, endpoint_height, endpoint.z)
		var inverse_speed := _inverse_speed_factor(bool(midpoint_record.get("road", false)))
		cost += previous_position.distance_to(midpoint_surface) * inverse_speed
		cost += midpoint_surface.distance_to(endpoint_surface) * inverse_speed
		if check_connector_corners and not _connector_corner_clear(previous_cell, endpoint_cell):
			return {clear = false, cost = INF}
		previous_cell = endpoint_cell
		previous_height = endpoint_height
		previous_position = endpoint_surface
	return {clear = true, cost = cost}


func _connector_corner_clear(from_cell: Vector2i, to_cell: Vector2i) -> bool:
	if from_cell.x == to_cell.x or from_cell.y == to_cell.y:
		return true
	var side_cell_a := Vector2i(to_cell.x, from_cell.y)
	var side_cell_b := Vector2i(from_cell.x, to_cell.y)
	if not _inside(side_cell_a) or not _inside(side_cell_b):
		return false
	return bool(_sample_cell(_id(side_cell_a)).passable) and bool(_sample_cell(_id(side_cell_b)).passable)


func _inverse_speed_factor(road: bool) -> float:
	return 1.0 / ROAD_SPEED if road else 1.0


func _consider_goal(id: int) -> void:
	if not _goals.has(id):
		return
	for candidate: Dictionary in _goals[id]:
		var total := float(_g_score[id]) + float(candidate.cost)
		if total < _best_goal_cost:
			_best_goal_cost = total
			_best_goal_id = id
			_best_goal_exact = bool(candidate.get("exact_goal", false))
			_best_goal_point = _goal_points[int(candidate.index)]


func _finish_best() -> void:
	finished = true
	if _best_goal_id < 0:
		path = PackedVector3Array()
		reached = false
		travel_cost = INF
		return

	var ids: Array[int] = []
	var cursor := _best_goal_id
	while cursor >= 0:
		ids.append(cursor)
		cursor = int(_parent.get(cursor, -1))
	ids.reverse()
	path = PackedVector3Array([_start])
	for id in ids:
		var cell := _cell_from_id(id)
		var record: Dictionary = _sample_cell(id)
		var point := _center(cell, float(record.height))
		if path.is_empty() or path[path.size() - 1].distance_to(point) > 0.01:
			path.append(point)
	if _best_goal_exact and path[path.size() - 1].distance_to(_best_goal_point) > 0.01:
		path.append(_best_goal_point)
	reached = true
	travel_cost = _best_goal_cost


func _heuristic(id: int) -> float:
	var cell := _cell_from_id(id)
	var position := _center(cell, 0.0)
	var best := INF
	for goal in _goal_points:
		var distance := Vector2(position.x - goal.x, position.z - goal.z).length()
		best = minf(best, maxf(0.0, distance - MAX_SNAP_DISTANCE) / ROAD_SPEED)
	return best


func _heap_priority(id: int) -> float:
	return float(_g_score[id]) + _heuristic(id)


func _heap_less(a: int, b: int) -> bool:
	var pa := _heap_priority(a)
	var pb := _heap_priority(b)
	return pa < pb or (is_equal_approx(pa, pb) and a < b)


func _heap_push_or_decrease(id: int) -> void:
	if _heap_pos.has(id):
		_heap_sift_up(int(_heap_pos[id]))
		return
	_heap.append(id)
	var index := _heap.size() - 1
	_heap_pos[id] = index
	_heap_sift_up(index)


func _heap_pop() -> int:
	var result := _heap[0]
	var last: int = _heap.pop_back()
	_heap_pos.erase(result)
	if not _heap.is_empty():
		_heap[0] = last
		_heap_pos[last] = 0
		_heap_sift_down(0)
	return result


func _heap_sift_up(start_index: int) -> void:
	var index := start_index
	while index > 0:
		var parent_index := floori(float(index - 1) / 2.0)
		if not _heap_less(_heap[index], _heap[parent_index]):
			break
		_heap_swap(index, parent_index)
		index = parent_index


func _heap_sift_down(start_index: int) -> void:
	var index := start_index
	while true:
		var left := index * 2 + 1
		var right := left + 1
		var smallest := index
		if left < _heap.size() and _heap_less(_heap[left], _heap[smallest]):
			smallest = left
		if right < _heap.size() and _heap_less(_heap[right], _heap[smallest]):
			smallest = right
		if smallest == index:
			return
		_heap_swap(index, smallest)
		index = smallest


func _heap_swap(a: int, b: int) -> void:
	var temp := _heap[a]
	_heap[a] = _heap[b]
	_heap[b] = temp
	_heap_pos[_heap[a]] = a
	_heap_pos[_heap[b]] = b


func _inside(cell: Vector2i) -> bool:
	return cell.x >= _bounds.position.x and cell.y >= _bounds.position.y \
			and cell.x < _bounds.end.x and cell.y < _bounds.end.y


func _id(cell: Vector2i) -> int:
	return (cell.y - _bounds.position.y) * _width + cell.x - _bounds.position.x


func _cell_from_id(id: int) -> Vector2i:
	return Vector2i(id % _width + _bounds.position.x, floori(float(id) / float(_width)) + _bounds.position.y)


func _center(cell: Vector2i, height: float) -> Vector3:
	return Vector3((float(cell.x) + 0.5) * _cell_size, height, (float(cell.y) + 0.5) * _cell_size)
