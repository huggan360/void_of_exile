class_name TownNavigation
extends RefCounted
## Shared per-town path grid: houses, props, terrain and trees block paths.
var world: GameWorld
var town: VillageFeature
var grid := AStarGrid2D.new()
var origin := Vector2.ZERO
var side := 0
var _threats: Array[Node3D] = []
var _threat_checked := -1000

func _init(plan: VillageFeature, realm: GameWorld) -> void:
	town = plan
	world = realm
	var extent := int(plan.radius) + 12
	origin = Vector2(plan.center) - Vector2.ONE * extent
	side = extent * 2 + 1
	grid.region = Rect2i(0, 0, side, side)
	grid.cell_size = Vector2.ONE
	grid.offset = origin + Vector2.ONE * 0.5
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	grid.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	grid.update()
	for z in side:
		for x in side:
			var p := Vector3(origin.x + x + 0.5, 0, origin.y + z + 0.5)
			p.y = world.ground_height(p.x, p.z)
			var blocked := not world.is_walkable(p) or world.is_hazard(p)
			if world is IslandWorld:
				var d := (world as IslandWorld).generator._detail(floori(p.x), floori(p.z))
				for i in range(4, d.size(), 3):
					if d[i] < p.y + 1.8 and d[i + 1] > p.y + 0.1:
						blocked = true
			grid.set_point_solid(Vector2i(x, z), blocked)
	for building: Dictionary in plan.houses + plan.props:
		var scale_value: float = building.get("scale", 1.0)
		var size: Vector3 = building.solid_size * scale_value
		var offset: Vector3 = building.get("solid_offset", Vector3.ZERO) * scale_value
		var yaw: float = building.yaw if building.has("yaw") else -float(building.get("turn", 0)) * PI * 0.5
		var center := Vector2(building.pos.x, building.pos.z) + Vector2(offset.x, offset.z).rotated(-yaw)
		var half := Vector2(size.x, size.z) * 0.5
		# Axis-aligned bounds of the turned envelope.
		half = Vector2(absf(cos(yaw)) * half.x + absf(sin(yaw)) * half.y, absf(sin(yaw)) * half.x + absf(cos(yaw)) * half.y)
		_block_rect(center, half + Vector2.ONE * 0.55)
	for tree: Dictionary in plan.trees:
		_block_rect(Vector2(tree.pos.x, tree.pos.z), Vector2.ONE * 1.1)
	# Use the same seeded obstacle plans before their streamed colliders exist.
	if world is IslandWorld:
		var island := world as IslandWorld
		var area := Rect2i(Vector2i(origin), Vector2i(side, side))
		for obstacle in island.generator.obstacle_sites(area, island._keep_clear, island.KEEP_CLEAR_RADIUS):
			var prefab := ObstacleLibrary.get_prefab(obstacle.prefab)
			for bounds in prefab.collision_boxes:
				var center3: Vector3 = bounds.get_center()
				var local := Vector2(center3.x, center3.z).rotated(-obstacle.yaw)
				var half := Vector2(bounds.size.x, bounds.size.z) * 0.5 + Vector2.ONE * 0.45
				if absf(sin(obstacle.yaw)) > 0.5:
					half = Vector2(half.y, half.x)
				_block_rect(Vector2(obstacle.pos.x, obstacle.pos.z) + local, half)

func _block_rect(center: Vector2, half: Vector2) -> void:
	var low := Vector2i((center - half - origin).floor())
	var high := Vector2i((center + half - origin).ceil())
	for z in range(maxi(0, low.y), mini(side, high.y + 1)):
		for x in range(maxi(0, low.x), mini(side, high.x + 1)):
			grid.set_point_solid(Vector2i(x, z), true)

func _node(pos: Vector3) -> Vector2i:
	var id := Vector2i((Vector2(pos.x, pos.z) - origin).floor())
	for radius in range(0, 9):
		for z in range(-radius, radius + 1):
			for x in range(-radius, radius + 1):
				var test := id + Vector2i(x, z)
				if grid.is_in_boundsv(test) and not grid.is_point_solid(test):
					return test
	return Vector2i(-1, -1)

func path(from: Vector3, to: Vector3) -> Array[Vector3]:
	var first := _node(from)
	var last := _node(to)
	var result: Array[Vector3] = []
	if first.x < 0 or last.x < 0:
		return result
	for point in grid.get_point_path(first, last):
		result.append(Vector3(point.x, world.ground_height(point.x, point.y), point.y))
	return result

func random_goal(rng: RandomNumberGenerator, outside := false) -> Vector3:
	for i in 160:
		var id := Vector2i(rng.randi_range(1, side - 2), rng.randi_range(1, side - 2))
		if grid.is_point_solid(id):
			continue
		var p := origin + Vector2(id) + Vector2.ONE * 0.5
		var from_center := p - Vector2(town.center)
		if outside and maxf(absf(from_center.x), absf(from_center.y)) < town.radius + 2:
			continue
		return Vector3(p.x, world.ground_height(p.x, p.y), p.y)
	return Vector3(town.center.x + 0.5, town.base_height + 1, town.center.y + 0.5)

func nearest_threat(pos: Vector3, reach: float) -> Node3D:
	var now := Time.get_ticks_msec()
	if now - _threat_checked > 150:
		_threat_checked = now
		_threats.clear()
		for node in world.get_tree().get_nodes_in_group("realm_creatures"):
			if node is Node3D and world.is_ancestor_of(node):
				_threats.append(node)
	var nearest: Node3D
	var distance := reach
	for node in _threats:
		if not is_instance_valid(node) or not node.has_method("is_alive") or not node.is_alive():
			continue
		if node is Enemy and (node.state == Enemy.State.BURIED or node.state == Enemy.State.DEAD):
			continue
		var d := Vector2(node.global_position.x - pos.x, node.global_position.z - pos.z).length()
		if d < distance:
			distance = d
			nearest = node
	return nearest

func escape_path(from: Vector3, threat: Vector3, rng: RandomNumberGenerator) -> Array[Vector3]:
	var best: Array[Vector3] = []
	var score := -INF
	for i in 24:
		var goal := random_goal(rng)
		var distance := Vector2(goal.x - threat.x, goal.z - threat.z).length()
		var travel := Vector2(goal.x - from.x, goal.z - from.z).length()
		var value := distance - travel * 0.25
		if value <= score or distance < 15:
			continue
		var candidate := path(from, goal)
		if not candidate.is_empty():
			best = candidate
			score = value
	return best
