class_name DungeonLayout
extends RefCounted
## A seeded cave maze. Rooms of different shapes are scattered over a round
## area (no grid): the spawn sits in the middle with ways out in every
## direction, or at the edge. Each room links to its nearest neighbours in any
## direction (diagonals too); a spanning tree keeps everything reachable and a
## few extra links make loops. Corridors wind and vary in width, and blind
## side passages end in dead ends. The boss waits in a big room far from the
## spawn; treasure and the miniboss hide in dead-end rooms.
##
## Other styles: "hall" (square chambers on a loose grid joined by straight
## passages, the Sunken Court) and "arena" (a short path through guardian
## rooms into one huge clearing, an encore). params.lava_cracks lays glowing
## cracks through the rooms (hazard_cells) that burn whoever stands on them.
##
## rooms: [{center, radius, kind, distance}]: `radius` is the room's clear
## core (always open floor), whatever its shape around it.

var rooms: Array[Dictionary] = []
var edges: Array[Vector2i] = []
var floor_cells := {}
var hazard_cells := {}  # lava cracks
var spawn := Vector3.ZERO
var boss := Vector3.ZERO
var extent := 80
var wall_height := 6
var treasure := -1
var miniboss := -1
var seed_value := 0
var _rng := RandomNumberGenerator.new()


func _init(definition: Dictionary, p_seed: int) -> void:
	seed_value = p_seed
	_rng.seed = p_seed
	var params: Dictionary = definition.params
	wall_height = params.wall_height
	match str(definition.get("generator_style", "cave_maze")):
		"hall": _hall(definition, params)
		"arena": _arena(params)
		_: _cave(definition, params)
	_prune(rooms[0].center)
	if params.get("lava_cracks", false):
		_cracks()
	var far := 0.0
	for cell: Vector2i in floor_cells:
		far = maxf(far, maxf(absf(cell.x), absf(cell.y)))
	extent = ceili(far) + 6
	spawn = point(0)
	boss = point(1)  # the boss room is placed right after the spawn


func _cave(definition: Dictionary, params: Dictionary) -> void:
	var area: float = params.area
	var shapes: Array = []
	_place_rooms(params, area, shapes)
	_connect(params)
	_assign(definition, _hops())
	for i in rooms.size():
		_stamp_room(rooms[i].center, shapes[i])
	var corridor: float = params.corridor_radius
	for edge in edges:
		_corridor(rooms[edge.x].center, rooms[edge.y].center, corridor)
	for k in int(params.dead_ends):
		_dead_end(corridor, area)


## Square chambers on a loose grid, grown outward from the spawn cell (the
## middle, or an edge), with straight passages and blind stubs.
func _hall(definition: Dictionary, params: Dictionary) -> void:
	var n: int = params.cells
	var spacing: int = params.spacing
	var start := Vector2i(n / 2, n / 2) if _rng.randf() < 0.6 else Vector2i(_rng.randi_range(0, n - 1), 0)
	var used := {start: 0}
	var order: Array[Vector2i] = [start]
	var links: Array = []
	var frontier: Array = [start]
	var steps := [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
	while order.size() < mini(int(params.rooms), n * n) and not frontier.is_empty():
		var from: Vector2i = frontier[_rng.randi_range(0, frontier.size() - 1)]
		var options := steps.map(func(d: Vector2i) -> Vector2i: return from + d).filter(
				func(c: Vector2i) -> bool: return c.x >= 0 and c.y >= 0 and c.x < n and c.y < n and not used.has(c))
		if options.is_empty():
			frontier.erase(from)
			continue
		var cell: Vector2i = options[_rng.randi_range(0, options.size() - 1)]
		used[cell] = used[from] + 1
		order.append(cell)
		frontier.append(cell)
		links.append([from, cell])
	# Extra doors between neighbouring chambers make loops.
	for a: Vector2i in order:
		for d: Vector2i in [Vector2i.RIGHT, Vector2i.DOWN]:
			if used.has(a + d) and not [a, a + d] in links and not [a + d, a] in links and _rng.randf() < float(params.loops):
				links.append([a, a + d])
	var far: Vector2i = start
	for c: Vector2i in order:
		if used[c] > used[far]: far = c
	order.erase(far)
	order.insert(1, far)
	var index := {}
	var half: Array = params.room_half
	for i in order.size():
		var c := order[i]
		index[c] = i
		var center := Vector2i((c.x - n / 2) * spacing + _rng.randi_range(-2, 2), (c.y - n / 2) * spacing + _rng.randi_range(-2, 2))
		var rx: int = int(params.boss_half) if i == 1 else _rng.randi_range(int(half[0]), int(half[1]))
		var rz: int = int(params.boss_half) if i == 1 else _rng.randi_range(int(half[0]), int(half[1]))
		rooms.append({center = center, radius = mini(rx, rz), kind = "spawn" if i == 0 else "boss" if i == 1 else "guards", distance = used[c]})
		for z in range(-rz, rz + 1):
			for x in range(-rx, rx + 1):
				floor_cells[center + Vector2i(x, z)] = true
	for link: Array in links:
		edges.append(Vector2i(index[link[0]], index[link[1]]))
		_carve(Vector2(rooms[index[link[0]]].center), Vector2(rooms[index[link[1]]].center), float(params.corridor_radius))
	_assign(definition, _hops())
	# Blind passages toward empty cells.
	for k in int(params.dead_ends):
		var c: Vector2i = order[_rng.randi_range(2, order.size() - 1)]
		var d: Vector2i = steps[_rng.randi_range(0, 3)]
		if not used.has(c + d):
			var from := Vector2(rooms[index[c]].center)
			_carve(from, from + Vector2(d) * spacing * 0.7, float(params.corridor_radius) * 0.8)


## A short winding path through guardian rooms into one huge round clearing.
func _arena(params: Dictionary) -> void:
	var heading := _rng.randf() * TAU
	var spots := [Vector2.ZERO]
	for k in int(params.guard_rooms):
		heading += _rng.randf_range(-0.6, 0.6)
		spots.append(spots.back() + Vector2.from_angle(heading) * 26.0)
	heading += _rng.randf_range(-0.4, 0.4)
	var arena: Vector2 = spots.back() + Vector2.from_angle(heading) * (26.0 + float(params.arena_radius))
	var sizes: Array = params.room_radius
	rooms.append({center = Vector2i(0, 0), radius = int(sizes[0]), kind = "spawn", distance = 0})
	rooms.append({center = Vector2i(roundi(arena.x), roundi(arena.y)), radius = int(params.arena_radius), kind = "boss", distance = spots.size()})
	for k in range(1, spots.size()):
		rooms.append({center = Vector2i(roundi(spots[k].x), roundi(spots[k].y)), radius = _rng.randi_range(int(sizes[0]), int(sizes[1])), kind = "guards", distance = k})
	var path := [0] + range(2, rooms.size()) + [1]
	for k in path.size() - 1:
		edges.append(Vector2i(path[k], path[k + 1]))
		_corridor(rooms[path[k]].center, rooms[path[k + 1]].center, float(params.corridor_radius))
	for room in rooms:
		_stamp_room(room.center, {kind = "round", r = room.radius, angle = 0.0, wobble = _rng.randi(), long = room.radius, lobes = []})


## Thin glowing cracks through the rooms (never at a room's heart or in the spawn).
func _cracks() -> void:
	var noise := FastNoiseLite.new()
	noise.seed = seed_value + 4421
	noise.frequency = 0.08
	for cell: Vector2i in floor_cells:
		if absf(noise.get_noise_2d(cell.x, cell.y)) > 0.022:
			continue
		for i in rooms.size():
			var d := Vector2(cell - rooms[i].center).length()
			if i != 0 and d > 4.0 and d < float(rooms[i].radius) + 3.0:
				hazard_cells[cell] = true
				break


func is_crack(x: int, z: int) -> bool:
	return hazard_cells.has(Vector2i(x, z))


func point(index: int) -> Vector3:
	var c: Vector2i = rooms[index].center
	return Vector3(c.x + 0.5, 1, c.y + 0.5)


func open(x: int, z: int) -> bool:
	return floor_cells.has(Vector2i(x, z))


# --- Rooms ---------------------------------------------------------------------------

## Spawn first (middle or edge), the boss room far across from it, then the
## rest wherever they fit with a gap of rock between them.
func _place_rooms(params: Dictionary, area: float, shapes: Array) -> void:
	var size_range: Array = params.room_radius
	var from_edge := _rng.randf() < 0.35
	var spawn_at := Vector2.ZERO if not from_edge else Vector2.from_angle(_rng.randf() * TAU) * area * 0.8
	_add_room(spawn_at, int(size_range[0]) + 1, "spawn", shapes)
	var boss_dir := (-spawn_at).normalized() if from_edge else Vector2.from_angle(_rng.randf() * TAU)
	var boss_at := boss_dir.rotated(_rng.randf_range(-0.5, 0.5)) * area * _rng.randf_range(0.75, 0.9)
	_add_room(boss_at, int(params.boss_radius), "boss", shapes)
	var tries := 0
	while rooms.size() < int(params.rooms) and tries < 800:
		tries += 1
		var at := Vector2.from_angle(_rng.randf() * TAU) * area * sqrt(_rng.randf())
		var r := _rng.randi_range(int(size_range[0]), int(size_range[1]))
		var fits := true
		for other in rooms:
			if at.distance_to(Vector2(other.center)) < r + int(other.radius) + 9 + _rng.randf() * 4.0:
				fits = false
				break
		if fits:
			_add_room(at, r, "guards", shapes)


func _add_room(at: Vector2, r: int, kind: String, shapes: Array) -> void:
	rooms.append({center = Vector2i(roundi(at.x), roundi(at.y)), radius = r, kind = kind, distance = 0})
	var shape := {kind = "round", r = r, angle = _rng.randf() * PI, wobble = _rng.randi()}
	if kind == "guards":
		shape.kind = ["round", "oval", "hall", "blob", "blob"][_rng.randi_range(0, 4)]
	elif kind == "boss":
		shape.kind = "round"
	shape.long = r * _rng.randf_range(1.3, 1.8)
	shape.lobes = []
	for k in 2:
		shape.lobes.append([Vector2.from_angle(_rng.randf() * TAU) * r * _rng.randf_range(0.7, 1.0), r * _rng.randf_range(0.55, 0.8)])
	shapes.append(shape)


## Fills one room: a clear core of radius r plus its shape around it.
func _stamp_room(center: Vector2i, shape: Dictionary) -> void:
	var r: float = shape.r
	var reach := ceili(shape.long + r) + 2
	for z in range(-reach, reach + 1):
		for x in range(-reach, reach + 1):
			var p := Vector2(x, z)
			# Ragged edges, but the same on every machine (hash of the cell).
			var rough := (_hash(center.x + x, center.y + z, int(shape.wobble)) - 0.5) * 1.6
			var inside := p.length() <= r + 0.3
			match str(shape.kind):
				"round":
					inside = inside or p.length() <= r + 1.0 + rough
				"oval":
					var q := p.rotated(-shape.angle)
					inside = inside or pow(q.x / float(shape.long), 2) + pow(q.y / r, 2) <= 1.0 + rough * 0.08
				"hall":
					var q := p.rotated(-shape.angle)
					inside = inside or absf(q.x) <= float(shape.long) + rough * 0.5 and absf(q.y) <= r * 0.75 + rough * 0.5
				"blob":
					for lobe: Array in shape.lobes:
						inside = inside or p.distance_to(lobe[0]) <= float(lobe[1]) + rough
			if inside:
				floor_cells[center + Vector2i(x, z)] = true


# --- The maze ------------------------------------------------------------------------

## Candidate links to each room's nearest neighbours (any direction), a
## spanning tree over them, then a few extra links for loops.
func _connect(params: Dictionary) -> void:
	var candidates: Array = []
	for a in rooms.size():
		var near: Array = []
		for b in rooms.size():
			if a != b:
				near.append([Vector2(rooms[a].center).distance_to(Vector2(rooms[b].center)), b])
		near.sort_custom(func(x: Array, y: Array) -> bool: return x[0] < y[0])
		for k in mini(3, near.size()):
			if a + near[k][1] == 1:
				continue  # never straight from the spawn (0) into the boss room (1)
			candidates.append([near[k][0], mini(a, near[k][1]), maxi(a, near[k][1])])
	candidates.sort_custom(func(x: Array, y: Array) -> bool: return x[0] < y[0])
	var group := range(rooms.size())
	var spare: Array = []
	for c: Array in candidates:
		var ga: int = _find(group, c[1])
		var gb: int = _find(group, c[2])
		var edge := Vector2i(c[1], c[2])
		if ga != gb:
			group[ga] = gb
			edges.append(edge)
		elif not edge in edges and not edge in spare:
			spare.append(edge)
	for edge: Vector2i in spare:
		if _rng.randf() < float(params.loops):
			edges.append(edge)


static func _find(group: Array, i: int) -> int:
	while group[i] != i:
		i = group[i]
	return i


## Hops from the spawn to every room.
func _hops() -> Array:
	var out := []
	out.resize(rooms.size())
	out.fill(-1)
	out[0] = 0
	var queue := [0]
	while not queue.is_empty():
		var a: int = queue.pop_front()
		for edge in edges:
			var b := edge.y if edge.x == a else edge.x if edge.y == a else -1
			if b >= 0 and out[b] < 0:
				out[b] = out[a] + 1
				queue.append(b)
	return out


## Distances, and the treasure and miniboss in dead-end rooms.
func _assign(definition: Dictionary, hops: Array) -> void:
	var tips: Array[int] = []
	for i in rooms.size():
		rooms[i].distance = hops[i]
		var degree := edges.filter(func(e: Vector2i) -> bool: return e.x == i or e.y == i).size()
		if degree == 1 and rooms[i].kind == "guards":
			tips.append(i)
	tips.sort_custom(func(a: int, b: int) -> bool: return hops[a] > hops[b])
	if not tips.is_empty() and _rng.randf() < definition.treasure_room_chance:
		treasure = tips.pop_front()
		rooms[treasure].kind = "treasure"
	if not tips.is_empty() and _rng.randf() < definition.miniboss_chance:
		miniboss = tips.pop_front()
		rooms[miniboss].kind = "miniboss"


# --- Passages ------------------------------------------------------------------------

## A winding passage between two points: bent through a couple of jittered
## midpoints, a little wider or narrower along the way.
func _corridor(a: Vector2i, b: Vector2i, radius: float) -> void:
	var from := Vector2(a)
	var to := Vector2(b)
	var side := (to - from).orthogonal().normalized()
	var points := [from]
	var bends := _rng.randi_range(1, 3)
	for k in bends:
		var t := float(k + 1) / (bends + 1)
		points.append(from.lerp(to, t) + side * _rng.randf_range(-1.0, 1.0) * minf(9.0, from.distance_to(to) * 0.2))
	points.append(to)
	for k in points.size() - 1:
		_carve(points[k], points[k + 1], radius)


func _carve(from: Vector2, to: Vector2, radius: float) -> void:
	var steps := maxi(1, ceili(from.distance_to(to) * 2.0))
	for s in steps + 1:
		var p := from.lerp(to, float(s) / steps)
		var r := radius + sin(s * 0.37 + from.x) * 0.45
		for z in range(floori(p.y - r), ceili(p.y + r) + 1):
			for x in range(floori(p.x - r), ceili(p.x + r) + 1):
				if Vector2(x + 0.5, z + 0.5).distance_to(p) <= r:
					floor_cells[Vector2i(x, z)] = true


## A blind passage that wanders off a room and stops: part of the maze.
func _dead_end(radius: float, area: float) -> void:
	var start: Dictionary = rooms[_rng.randi_range(0, rooms.size() - 1)]
	if start.kind == "boss":
		return
	var p := Vector2(start.center)
	var heading := _rng.randf() * TAU
	p += Vector2.from_angle(heading) * float(start.radius)
	for leg in _rng.randi_range(2, 4):
		heading += _rng.randf_range(-0.9, 0.9)  # turns of up to ~50 degrees, diagonals included
		var next := p + Vector2.from_angle(heading) * _rng.randf_range(6.0, 11.0)
		if next.length() > area * 1.05 or _touches_room(next, 4.0):
			break
		_carve(p, next, radius * 0.85)
		p = next


## Ragged edges can leave specks of floor walled off from the rest: drop
## everything that can't be walked to from the spawn.
func _prune(from: Vector2i) -> void:
	var kept := {from: true}
	var queue: Array[Vector2i] = [from]
	var cursor := 0
	while cursor < queue.size():
		var cell := queue[cursor]
		cursor += 1
		for delta: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next := cell + delta
			if floor_cells.has(next) and not kept.has(next):
				kept[next] = true
				queue.append(next)
	floor_cells = kept


func _touches_room(p: Vector2, margin: float) -> bool:
	for room in rooms:
		if p.distance_to(Vector2(room.center)) < float(room.radius) + margin:
			return true
	return false


static func _hash(x: int, z: int, salt: int) -> float:
	var h := (x * 374761393 + z * 668265263 + salt * 2246822519) & 0x7fffffff
	h = ((h ^ (h >> 13)) * 1274126177) & 0x7fffffff
	return float(h % 10000) / 10000.0
