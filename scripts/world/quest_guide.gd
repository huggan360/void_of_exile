class_name QuestGuide
extends Node
## Local, time-budgeted quest navigation. Both displays use the same safe path.
signal routes_changed(main: PackedVector3Array, side: PackedVector3Array)

const RADIUS := 0.44
const BODY_HEIGHT := 1.75
const CHUNK := 32
const MAX_COLUMN_CACHE := 65536
## Every chunk of the island fits (41 x 41), so each is worked out once.
const MAX_BOX_CACHE := 4096
## Chunks around the player get their obstacle boxes ahead of the search, a
## slice per frame, so the search itself never stalls on a new chunk.
const PREWARM_RADIUS := 3
const PREWARM_USEC := 1000
const PREWARM_TILE := 8
const MAIN_COLOR := Color("f3cb58")
const SIDE_COLOR := Color("7dde88")

var world: GameWorld
var player: Player
var marker_source := Callable()
var main_path := PackedVector3Array()
var side_path := PackedVector3Array()
var _main_search := QuestPathfinder.new()
var _side_search := QuestPathfinder.new()
var _main_goals: Array[Vector3] = []
var _side_goals: Array[Vector3] = []
var _goal_key := ""
var _search_key := ""
var _same_goal := false
var _searching := false
var _main_applied := false
var _side_applied := false
var _refresh_left := 0.0
var _display_left := 0.0
var _retry_left := 0.0
var _sample_cache := {}
var _box_cache := {}
var _box_grid := {}
var _column_cache := {}
var _prewarm := {}  # chunk -> {sites, next}: obstacle sites gathered so far
var _column_order: Array[Vector2i] = []
var _column_cursor := 0
var _trail: QuestTrail
var _shape := CapsuleShape3D.new()
var _query := PhysicsShapeQueryParameters3D.new()


func _ready() -> void:
	_shape.radius = RADIUS
	_shape.height = BODY_HEIGHT
	_query.shape = _shape
	_query.collision_mask = Player.OBSTACLE_LAYER


func configure(value: GameWorld, body: Player, source: Callable) -> void:
	if is_instance_valid(world):
		if world.obstacle_broken.is_connected(_obstacle_changed): world.obstacle_broken.disconnect(_obstacle_changed)
		if world is IslandWorld and world.gates.changed.is_connected(_gate_changed): world.gates.changed.disconnect(_gate_changed)
	if is_instance_valid(_trail): _trail.queue_free()
	world = value
	player = body
	marker_source = source
	_main_search.cancel()
	_side_search.cancel()
	_searching = false
	_sample_cache.clear()
	_box_cache.clear()
	_box_grid.clear()
	_prewarm.clear()
	_column_cache.clear()
	_column_order.clear()
	_column_cursor = 0
	_goal_key = ""
	_search_key = ""
	_main_goals.clear()
	_side_goals.clear()
	main_path.clear()
	side_path.clear()
	routes_changed.emit(main_path, side_path)
	if is_instance_valid(_trail): _trail.set_routes(main_path, side_path, player.global_position)
	_refresh_left = 0.0
	_retry_left = 0.0
	if not is_instance_valid(world): return
	if Dungeons.is_dungeon(world.realm_id): return
	world.obstacle_broken.connect(_obstacle_changed)
	if world is IslandWorld: world.gates.changed.connect(_gate_changed)
	_trail = QuestTrail.new()
	_trail.main_color = MAIN_COLOR
	_trail.side_color = SIDE_COLOR
	world.add_child(_trail)


func _obstacle_changed(obstacle: Obstacle) -> void:
	if is_instance_valid(obstacle):
		var at := obstacle.global_position
		for dz in range(-1, 2):
			for dx in range(-1, 2):
				var c := Vector2i(floori((at.x + dx * 8.0) / CHUNK), floori((at.z + dz * 8.0) / CHUNK))
				_box_cache.erase(c)
				_box_grid.erase(c)
				_prewarm.erase(c)
	else:
		_box_cache.clear()
		_box_grid.clear()
	invalidate()


func _gate_changed(_center: Vector2i, _locked: bool, _sealed: bool) -> void:
	invalidate()


func invalidate() -> void:
	_sample_cache.clear()
	_main_search.cancel()
	_side_search.cancel()
	_searching = false
	_search_key = ""
	_retry_left = 0.0
	_refresh_left = 0.0
	# Never leave a line pointing through a newly closed gate.
	main_path.clear()
	side_path.clear()
	routes_changed.emit(main_path, side_path)
	if is_instance_valid(_trail) and is_instance_valid(player):
		_trail.set_routes(main_path, side_path, player.global_position)


func _process(delta: float) -> void:
	if not is_instance_valid(world) or not world.is_inside_tree() or not is_instance_valid(player): return
	if Dungeons.is_dungeon(world.realm_id): return
	if world is IslandWorld: _prewarm_step()
	_retry_left -= delta
	_refresh_left -= delta
	_display_left -= delta
	if _refresh_left <= 0:
		_refresh_left = 0.75
		_update_goals()
		if not _searching:
			for path: PackedVector3Array in [main_path, side_path]:
				var blocked := false
				for i in mini(path.size() - 1, 10):
					if not segment_clear(path[i], path[i + 1], true): blocked = true; break
				if blocked:
					invalidate()
					break
	if player.frozen:
		if is_instance_valid(_trail): _trail.visible = false
		return
	if not _searching and _retry_left <= 0 and (not _main_goals.is_empty() or not _side_goals.is_empty()):
		if _search_key != _goal_key or _off_path(main_path, _main_goals) or _off_path(side_path, _side_goals):
			_begin_search()
	if _searching and _main_applied and _retry_left <= 0 and _off_path(main_path, _main_goals):
		_start_one(_main_search, _main_goals)
		_main_applied = false
		main_path.clear()
		_retry_left = 0.75
		_display_left = 0.0
	if _searching:
		var main_done := _main_search.step(128, 2000)
		if main_done and not _main_applied:
			_main_applied = true
			main_path = _main_search.path.duplicate() if _main_search.reached else PackedVector3Array()
			_display_left = 0.0
		var side_done := true if _same_goal else _side_search.step(96, 1500)
		if side_done and not _side_applied:
			_side_applied = true
			side_path = main_path.duplicate() if _same_goal else (_side_search.path.duplicate() if _side_search.reached else PackedVector3Array())
			_display_left = 0.0
		if _same_goal and main_done: side_path = main_path.duplicate()
		if main_done and side_done:
			_searching = false
			_retry_left = 3.0 if main_path.is_empty() and side_path.is_empty() else 0.75

	if _display_left <= 0:
		_display_left = 0.12
		main_path = _consume(main_path)
		side_path = _consume(side_path)
		routes_changed.emit(main_path, side_path)
		if is_instance_valid(_trail): _trail.set_routes(main_path, side_path, player.global_position)
	if is_instance_valid(_trail):
		_trail.visible = not player.cinematic_locked and player.talk_partner == null


func _update_goals() -> void:
	var main: Array[Vector3] = []
	var side: Array[Vector3] = []
	if marker_source.is_valid():
		for marker: Dictionary in marker_source.call():
			if not marker.get("pos", Vector3.INF).is_finite(): continue
			if marker.get("kind", "") == "quest": main.append(marker.pos)
			elif marker.get("kind", "") == "side": side.append(marker.pos)
	var key := _points_key(main) + "/" + _points_key(side)
	if key == _goal_key: return
	_goal_key = key
	_main_goals = main
	_side_goals = side
	_main_search.cancel()
	_side_search.cancel()
	_searching = false
	_search_key = ""
	main_path.clear()
	side_path.clear()
	_retry_left = 0.0
	routes_changed.emit(main_path, side_path)


static func _points_key(points: Array[Vector3]) -> String:
	var keys: Array[String] = []
	for p in points: keys.append("%d,%d,%d" % [roundi(p.x), roundi(p.y), roundi(p.z)])
	keys.sort()
	return ";".join(keys)


func _off_path(path: PackedVector3Array, goals: Array[Vector3]) -> bool:
	if goals.is_empty(): return false
	for goal in goals:
		if Vector2(goal.x - player.global_position.x, goal.z - player.global_position.z).length() < 2.0: return false
	if path.is_empty(): return true
	var nearest := INF
	for p in path.slice(0, mini(path.size(), 128)):
		nearest = minf(nearest, Vector2(p.x - player.global_position.x, p.z - player.global_position.z).length())
	return nearest > 2.8


func _begin_search() -> void:
	_sample_cache.clear()
	_main_applied = false
	_side_applied = false
	_same_goal = not _main_goals.is_empty() and _points_key(_main_goals) == _points_key(_side_goals)
	_start_one(_main_search, _main_goals)
	if not _same_goal: _start_one(_side_search, _side_goals)
	_search_key = _goal_key
	_searching = true


func _start_one(search: QuestPathfinder, goals: Array[Vector3]) -> void:
	var cell := 1.0
	var distance := INF
	for goal in goals: distance = minf(distance, goal.distance_to(player.global_position))
	if world is IslandWorld and distance > 180.0: cell = 2.0
	var extent := ceili(world.half_extent / cell)
	search.begin(player.global_position, goals, sample, Rect2i(-extent, -extent, extent * 2, extent * 2), cell)


## Consume only nearby leading segments, never jump across a future loop.
func _consume(path: PackedVector3Array) -> PackedVector3Array:
	if path.size() < 2: return path
	var pos := player.global_position
	var best := INF
	var index := 0
	var projection := path[0]
	for i in mini(path.size() - 1, 128):
		var a := Vector2(path[i].x, path[i].z)
		var b := Vector2(path[i + 1].x, path[i + 1].z)
		var point := Geometry2D.get_closest_point_to_segment(Vector2(pos.x, pos.z), a, b)
		var d := point.distance_to(Vector2(pos.x, pos.z))
		if d >= best or d > 2.0: continue
		var at := Vector3(point.x, world.ground_height(point.x, point.y), point.y)
		if not segment_clear(pos, at): continue
		best = d
		index = i
		projection = at
	if best == INF: return path
	var out := PackedVector3Array([projection])
	for i in range(index + 1, path.size()): out.append(path[i])
	return out


func segment_clear(a: Vector3, b: Vector3, fresh := false) -> bool:
	var steps := maxi(1, ceili(Vector2(b.x - a.x, b.z - a.z).length() / 0.4))
	var previous := a.y
	for i in range(steps + 1):
		var at := a.lerp(b, float(i) / steps)
		if fresh: _sample_cache.erase(Vector2i(roundi(at.x * 16), roundi(at.z * 16)))
		var data := sample(Vector2(at.x, at.z))
		if not data.passable or absf(float(data.height) - previous) > Player.STEP_HEIGHT: return false
		previous = float(data.height)
	return true


## Character-width terrain and obstacle probe. Planned obstacles are included
## even when their rendered meshes/colliders have not streamed into the client.
func sample(at: Vector2) -> Dictionary:
	var key := Vector2i(roundi(at.x * 16), roundi(at.y * 16))
	if _sample_cache.has(key): return _sample_cache[key]
	var island := world as IslandWorld
	var center_column := _island_column(at) if island else {}
	var h := float(center_column.height) if island else world.ground_height(at.x, at.y)
	var p := Vector3(at.x, h, at.y)
	var passable := is_finite(h) and absf(at.x) < world.half_extent and absf(at.y) < world.half_extent
	if passable:
		for offset: Vector2 in [Vector2.ZERO, Vector2(-RADIUS, -RADIUS), Vector2(RADIUS, -RADIUS), Vector2(-RADIUS, RADIUS), Vector2(RADIUS, RADIUS)]:
			var q := p + Vector3(offset.x, 0, offset.y)
			if island:
				var column := _island_column(Vector2(q.x, q.z))
				if not column.passable or float(column.height) > h + Player.STEP_HEIGHT:
					passable = false
					break
				var detail: Array = column.detail
				for j in range(4, detail.size(), 3):
					if detail[j] < h + BODY_HEIGHT and detail[j + 1] > h + 0.12:
						passable = false
						break
			elif not world.is_walkable(q) or world.is_hazard(q) or world.ground_height(q.x, q.z) > h + Player.STEP_HEIGHT:
				passable = false
				break
			elif world is HallWorld:
				var hall := world as HallWorld
				var id := hall.home_terrain.index(floori(q.x), floori(q.z))
				if id < 0 or hall._footprints[id] != 0: passable = false; break
			if not passable: break
	if passable and world is IslandWorld:
		for box: AABB in _boxes_at(at):
			if _box_blocks(box, p): passable = false; break
		if passable:
			for entry: Dictionary in world.gates.entries.values():
				var local: Vector3 = entry.root.to_local(p)
				for gate: Dictionary in entry.gates:
					if gate.body.collision_layer != 0 and _box_blocks(gate.box, local): passable = false; break
				if not passable: break
	# Authored scenes and dynamic obstructions use their actual collider too.
	if passable and world.is_inside_tree() and (not world is IslandWorld or p.distance_to(player.global_position) < 125.0):
		_query.transform = Transform3D(Basis(), p + Vector3.UP * (BODY_HEIGHT * 0.5 + 0.12))
		passable = world.get_world_3d().direct_space_state.intersect_shape(_query, 1).is_empty()
	var road := bool(center_column.road) if island else world.is_road(p)
	var result := {passable = passable, height = h, road = road if passable else false}
	_sample_cache[key] = result
	return result


## Terrain columns are immutable for a world. Each expensive feature/noise
## query is shared by the many sub-cell edge and capsule samples visiting it.
func _island_column(at: Vector2) -> Dictionary:
	var cell := Vector2i(floori(at.x), floori(at.y))
	if not _column_cache.has(cell):
		if _column_cache.size() >= MAX_COLUMN_CACHE:
			_column_cache.erase(_column_order[_column_cursor])
			_column_order[_column_cursor] = cell
			_column_cursor = (_column_cursor + 1) % MAX_COLUMN_CACHE
		else:
			_column_order.append(cell)
		var island := world as IslandWorld
		var detail := island.generator._detail(cell.x, cell.y)
		_column_cache[cell] = {height = float(detail[0]) + 1.0, detail = detail,
			passable = int(detail[0]) >= IslandGenerator.SEA_LEVEL - 1 and not Blocks.is_hazard(int(detail[2])),
			road = island.generator.is_road(cell.x, cell.y)}
	return _column_cache[cell]


static func _box_blocks(box: AABB, point: Vector3) -> bool:
	return point.x > box.position.x - RADIUS and point.x < box.end.x + RADIUS \
		and point.z > box.position.z - RADIUS and point.z < box.end.z + RADIUS \
		and box.position.y < point.y + BODY_HEIGHT and box.end.y > point.y + 0.12


func _boxes_at(at: Vector2) -> Array:
	var chunk := Vector2i(floori(at.x / CHUNK), floori(at.y / CHUNK))
	if not _box_cache.has(chunk): _island_boxes(chunk)
	var bin := Vector2i(floori(at.x / 4.0), floori(at.y / 4.0))
	return _box_grid[chunk].get(bin, [])


func _island_boxes(chunk: Vector2i) -> Array[AABB]:
	if _box_cache.has(chunk): return _box_cache[chunk]
	# Not prewarmed yet: gather what's left of it now.
	while not _gather_slice(chunk): pass
	return _finish_boxes(chunk, _prewarm[chunk].sites)


## The padded area around a chunk, in PREWARM_TILE squares.
func _chunk_area(chunk: Vector2i) -> Rect2i:
	return Rect2i(chunk * CHUNK - Vector2i(8, 8), Vector2i(CHUNK + 16, CHUNK + 16))


## Gathers one tile of a chunk's obstacle sites; true once all are in.
func _gather_slice(chunk: Vector2i) -> bool:
	if not _prewarm.has(chunk): _prewarm[chunk] = {sites = [], next = 0}
	var job: Dictionary = _prewarm[chunk]
	var area := _chunk_area(chunk)
	var across := area.size.x / PREWARM_TILE
	var total := across * (area.size.y / PREWARM_TILE)
	if job.next >= total: return true
	var tile := Rect2i(area.position + Vector2i(job.next % across, job.next / across) * PREWARM_TILE, Vector2i.ONE * PREWARM_TILE)
	var island := world as IslandWorld
	job.sites.append_array(island.generator.obstacle_sites(tile, island._keep_clear, island.KEEP_CLEAR_RADIUS))
	job.next += 1
	return job.next >= total


## Works out the boxes of the chunks near the player, PREWARM_USEC a frame.
func _prewarm_step() -> void:
	var deadline := Time.get_ticks_usec() + PREWARM_USEC
	var center := Vector2i(floori(player.global_position.x / CHUNK), floori(player.global_position.z / CHUNK))
	for ring in PREWARM_RADIUS + 1:
		for dz in range(-ring, ring + 1):
			for dx in range(-ring, ring + 1):
				if maxi(absi(dx), absi(dz)) != ring: continue
				var c := center + Vector2i(dx, dz)
				if _box_cache.has(c): continue
				while Time.get_ticks_usec() < deadline:
					if _gather_slice(c):
						_finish_boxes(c, _prewarm[c].sites)
						break
				if Time.get_ticks_usec() >= deadline: return


func _finish_boxes(chunk: Vector2i, sites: Array) -> Array[AABB]:
	_prewarm.erase(chunk)
	var island := world as IslandWorld
	var boxes: Array[AABB] = []
	for site: Dictionary in sites:
		if island._destroyed.has(site.id): continue
		_append_prefab(boxes, site)
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			var c := chunk + Vector2i(dx, dz)
			for spec: Dictionary in island._buildings_by_chunk.get(c, []):
				var size: Vector3 = spec.solid_size * float(spec.get("scale", 1.0))
				var offset: Vector3 = spec.get("solid_offset", Vector3(0, spec.solid_size.y * 0.5, 0)) * float(spec.get("scale", 1.0))
				var yaw := float(spec.get("yaw", -float(spec.get("turn", 0)) * PI * 0.5))
				boxes.append(Transform3D(Basis(Vector3.UP, yaw), spec.pos) * AABB(offset - size * 0.5, size))
			for spec: Dictionary in island._town_trees_by_chunk.get(c, []): _append_prefab(boxes, spec)
			for spec: Dictionary in island._lamps_by_chunk.get(c, []):
				_append_prefab(boxes, spec.merged({prefab = "lamppost"}))
	if _box_cache.size() >= MAX_BOX_CACHE:
		var oldest: Vector2i = _box_cache.keys()[0]
		_box_cache.erase(oldest)
		_box_grid.erase(oldest)
	_box_cache[chunk] = boxes
	var cells := {}
	for box in boxes:
		var low := Vector2i(floori((box.position.x - RADIUS) / 4.0), floori((box.position.z - RADIUS) / 4.0))
		var high := Vector2i(floori((box.end.x + RADIUS) / 4.0), floori((box.end.z + RADIUS) / 4.0))
		for z in range(maxi(low.y, chunk.y * 8), mini(high.y + 1, (chunk.y + 1) * 8)):
			for x in range(maxi(low.x, chunk.x * 8), mini(high.x + 1, (chunk.x + 1) * 8)):
				var bin := Vector2i(x, z)
				if not cells.has(bin): cells[bin] = []
				cells[bin].append(box)
	_box_grid[chunk] = cells
	return boxes


static func _append_prefab(boxes: Array[AABB], spec: Dictionary) -> void:
	var prefab := ObstacleLibrary.get_prefab(str(spec.prefab))
	var transform := Transform3D(Basis(Vector3.UP, float(spec.get("yaw", 0))), spec.pos)
	for box: AABB in prefab.collision_boxes: boxes.append(transform * box)
