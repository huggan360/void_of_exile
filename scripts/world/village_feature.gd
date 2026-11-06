class_name VillageFeature
extends RealmFeature
## Immutable seeded settlement plan. A round town: a paved plaza, main streets
## that leave toward the realm roads (`exits`), a ring lane and a few side
## lanes. Houses stand along the streets with their doors toward them.
## Column geometry is baked once on the main thread, then read by terrain
## workers. NPC and service records share this plan.
const CAPITAL_RADIUS := 46.0
const OUTPOST_RADIUS := 38.0
const HOUSE_SIZE := Vector2(8.5, 9.0)  # closed collision envelope, x by z
const HOUSE_MARGIN := 1.0
## Extra woodland styles: pick -> [asset folder, closed collision size].
const HOME_STYLES := {
	3: ["res://props/home/rose_cottage", Vector3(7.2, 7.2, 7.6)],
	4: ["res://props/home/blue_bakery", Vector3(8.5, 7.6, 7.6)],
	5: ["res://props/houses/desert_1", Vector3(8.5, 6.0, 8.5)],
}

var village_seed := 0
var biome_id := Biomes.WOODS
var capital := false
## Directions (radians, Vector2.from_angle) of the streets leaving town.
var exits := PackedFloat32Array()
var plaza_radius := 6.0
var houses: Array[Dictionary] = []
var props: Array[Dictionary] = []
## Seeded trees and bushes inside the town: [{prefab, pos, yaw}].
var trees: Array[Dictionary] = []
var residents: Array[Dictionary] = []
var service_sites: Array[Dictionary] = []
## Side-lane directions, kept clear of plaza furniture like the exits.
var exits_avoid: Array[float] = []
var _columns := {}
var _surface := {}  # Vector2i -> block for paved columns
var _ground := Blocks.GRASS
var _under := Blocks.DIRT
var _street := Blocks.PAVING
var _lane := Blocks.GRAVEL
var _footpath := Blocks.DIRT
## Its color on the map (each town has its own).
var map_color := Color(1.0, 0.8, 0.35)
var _plaza := Blocks.HALL_FLOOR
var _plaza_trim := Blocks.HALL_TRIM
# Planning only: local occupancy (0 free, 1 street, 2 solid) over the bounds.
var _occupied := PackedByteArray()
var _side := 0


static func plan(at: Vector2i, biome: int, seed_value: int, height: int, is_capital := false,
		exit_angles: Array = []) -> VillageFeature:
	var f := VillageFeature.new()
	f.type = "village"
	f.center = at
	f.base_height = height
	f.required = true
	f.capital = is_capital
	f.biome_id = biome
	f.village_seed = seed_value
	f.radius = CAPITAL_RADIUS if is_capital else OUTPOST_RADIUS
	f.plaza_radius = 9.5 if is_capital else 6.5
	f.light_color = Color(1.0, 0.72, 0.4)
	f.bounds = Rect2i(at - Vector2i.ONE * int(f.radius), Vector2i.ONE * (int(f.radius) * 2 + 1))
	f._side = int(f.radius) * 2 + 1
	f._occupied.resize(f._side * f._side)
	f._occupied.fill(0)
	var titles := ["Hearthwick", "Bramblebrook", "Sunveil", "Snowbell"]
	f.display_name = titles[0 if is_capital else 2 if biome == Biomes.DESERT else 3 if biome == Biomes.FOSEN else 1]
	match biome:
		Biomes.DESERT:
			f._ground = Blocks.DESERT_SAND
			f._under = Blocks.SANDSTONE
			f._street = Blocks.DESERT_ROCK
			f._lane = Blocks.SANDSTONE
			f._footpath = Blocks.SAND
			f._plaza = Blocks.RUNE_SAND
			f._plaza_trim = Blocks.DESERT_ROCK
		Biomes.FOSEN:
			f._ground = Blocks.SNOW
			f._lane = Blocks.FOSEN_ROCK
			f._footpath = Blocks.GRAVEL
			f._plaza = Blocks.HALL_FLOOR
			f._plaza_trim = Blocks.FOSEN_ROCK
	if exit_angles.is_empty():
		exit_angles = [0.0, PI * 0.5, PI, PI * 1.5] if is_capital else [Vector2(-at).angle()]
	for a in exit_angles:
		f.exits.append(a)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var streets := f._lay_streets(rng)
	f._place_houses(streets, rng)
	f._furnish(streets, rng)
	f._settle_residents()
	return f


# --- Streets ----------------------------------------------------------------------

## Returns [{points, half, block, kind}] in world x/z, already painted.
func _lay_streets(rng: RandomNumberGenerator) -> Array[Dictionary]:
	var c := Vector2(center) + Vector2(0.5, 0.5)
	var streets: Array[Dictionary] = []
	var ring_radius := radius * (0.56 if capital else 0.6)
	# Ring lane first so the main streets are painted over it.
	var ring := PackedVector2Array()
	var wobble := rng.randf() * TAU
	for k in 49:
		var a := k * TAU / 48.0
		ring.append(c + Vector2.from_angle(a) * (ring_radius + sin(a * 3.0 + wobble) * 1.3))
	streets.append({points = ring, half = 1.4, block = _lane, kind = "ring"})
	# Side lanes run out from the ring between the main streets.
	var lanes := 3 if capital else 2
	var tries := 0
	while lanes > 0 and tries < 40:
		tries += 1
		var a := rng.randf() * TAU
		if _near_exit(a, 0.6):
			continue
		var lane := PackedVector2Array()
		var bend := rng.randf_range(-0.25, 0.25)
		for k in 7:
			var t := k / 6.0
			lane.append(c + Vector2.from_angle(a + bend * t) * lerpf(ring_radius, radius - 7.0, t))
		streets.append({points = lane, half = 1.1, block = _footpath, kind = "lane"})
		exits_avoid.append(a)
		lanes -= 1
	for a in exits:
		var street := PackedVector2Array()
		var side := Vector2.from_angle(a).orthogonal()
		var bend := rng.randf_range(-1.8, 1.8)
		for k in 9:
			var t := k / 8.0
			street.append(c + Vector2.from_angle(a) * lerpf(plaza_radius - 1.0, radius + 1.0, t) + side * sin(t * PI) * bend)
		streets.append({points = street, half = 1.8 if capital else 1.5, block = _street, kind = "main"})
	for s in streets:
		_paint_street(s.points, s.half, s.block)
	# The plaza: concentric paving with a trimmed rim.
	for z in range(-ceili(plaza_radius), ceili(plaza_radius) + 1):
		for x in range(-ceili(plaza_radius), ceili(plaza_radius) + 1):
			var d := Vector2(x, z).length()
			if d <= plaza_radius:
				var p := center + Vector2i(x, z)
				_surface[p] = _plaza_trim if d > plaza_radius - 1.2 or int(d) % 3 == 2 else _plaza
				_mark(p, 1)
	return streets



func _near_exit(a: float, gap: float) -> bool:
	for e in exits:
		if absf(angle_difference(a, e)) < gap:
			return true
	for e in exits_avoid:
		if absf(angle_difference(a, e)) < gap:
			return true
	return false


func _paint_street(points: PackedVector2Array, half: float, block: int) -> void:
	for i in points.size() - 1:
		var a := points[i]
		var b := points[i + 1]
		var steps := maxi(1, ceili(a.distance_to(b) * 2.0))
		for n in steps + 1:
			var p := a.lerp(b, float(n) / steps)
			for z in range(floori(p.y - half - 1), ceili(p.y + half + 1)):
				for x in range(floori(p.x - half - 1), ceili(p.x + half + 1)):
					var d := Vector2(x + 0.5, z + 0.5).distance_to(p)
					var cell := Vector2i(x, z)
					if not _inside(cell, 0.5):
						continue
					if d < half:
						_surface[cell] = block if _hash(x, z, 9) > 0.08 else _lane
						_mark(cell, 1)
					elif d < half + 0.7 and not _surface.has(cell) and _hash(x, z, 10) < 0.45:
						_surface[cell] = _lane


# --- Houses -----------------------------------------------------------------------

func _place_houses(streets: Array[Dictionary], rng: RandomNumberGenerator) -> void:
	var wanted := 24 if capital else rng.randi_range(10, 12)
	var theme := "fosen" if biome_id == Biomes.FOSEN else "desert" if biome_id == Biomes.DESERT else "woodland"
	var order: Array[Dictionary] = []
	for kind in ["main", "ring", "lane"]:
		for s in streets:
			if s.kind == kind:
				order.append(s)
	for s in order:
		var pts: PackedVector2Array = s.points
		for side: float in [1.0, -1.0]:
			var walked := rng.randf_range(3.0, 6.0)
			var total := _length(pts)
			while walked < total - 3.0 and houses.size() < wanted:
				var at := _along(pts, walked)
				var ahead := _along(pts, minf(walked + 2.0, total)) - _along(pts, maxf(walked - 2.0, 0.0))
				var normal := ahead.normalized().orthogonal() * side
				var setback: float = s.half + rng.randf_range(1.6, 2.6)
				var pos: Vector2 = at + normal * (setback + HOUSE_SIZE.y * 0.5)
				var yaw := atan2(normal.x, normal.y)  # front (-Z) faces back toward the street
				if _house_fits(pos, yaw):
					_add_house(pos, yaw, theme, rng)
					_paint_path(pos - normal * (HOUSE_SIZE.y * 0.5 + 0.3), at + normal * (s.half - 0.4))
					walked += HOUSE_SIZE.x + rng.randf_range(2.5, 5.0)
				else:
					walked += 1.5


func _house_fits(pos: Vector2, yaw: float) -> bool:
	var cells := _rect_cells(pos, HOUSE_SIZE * 0.5 + Vector2.ONE * HOUSE_MARGIN, yaw)
	for cell in cells:
		if _occupied_at(cell) != 0 or not _inside(cell, 2.0):
			return false
	return true


func _add_house(pos: Vector2, yaw: float, theme: String, rng: RandomNumberGenerator) -> void:
	for cell in _rect_cells(pos, HOUSE_SIZE * 0.5 + Vector2.ONE * 0.6, yaw):
		_mark(cell, 2)
	var i := houses.size()
	var role := "home"
	if i == 0:
		role = "smith" if capital or biome_id == Biomes.FOSEN else "magician" if biome_id == Biomes.DESERT else "herbalist"
	elif i == 1:
		role = "inn"
	var variant := rng.randi_range(0, 2)
	var asset := "res://props/houses/%s_%d" % [theme, variant]
	var scale_value := 0.94 + variant * 0.04
	var solid := Vector3(8.5, 6.0, 8.5)
	# Woodland towns mix in the home island's cottages and teal-roofed lodges.
	if theme == "woodland" and role == "home":
		var pick := rng.randi_range(0, 5)
		if pick in HOME_STYLES:
			asset = HOME_STYLES[pick][0]
			solid = HOME_STYLES[pick][1]
			scale_value = 1.0
	var spec := {center = Vector2i(pos.floor()), half = Vector2i(4, 4), turn = 0, yaw = yaw,
		role = role, variant = variant, seed = rng.randi(), asset = asset,
		pos = Vector3(pos.x, base_height + 1, pos.y), scale = scale_value,
		solid_size = solid, solid_offset = Vector3(0, solid.y * 0.5, -0.25 if solid.z > 8.0 else 0.0)}
	houses.append(spec)
	if role == "home":
		return
	var front := Vector2(-sin(yaw), -cos(yaw))
	var station := pos + front * 6.0 + front.orthogonal() * 1.5
	var npc_role: String = role if role in ["smith", "magician"] else "baker" if role == "inn" else "gardener"
	var npc := _npc(npc_role, station, spec.seed, true)
	npc.yaw = yaw
	residents.append(npc)
	service_sites.append({id = "%s_%d" % [display_name, i], role = role, house = i,
		door = Vector3(station.x, base_height + 1, station.y), npc = npc,
		portrait = "res://creatures/npc_%s/portrait.png" % npc_role, shop_enabled = false})


func _paint_path(from: Vector2, to: Vector2) -> void:
	var steps := maxi(1, ceili(from.distance_to(to) * 2.0))
	for n in steps + 1:
		var p := from.lerp(to, float(n) / steps)
		for offset in [Vector2.ZERO, Vector2(0.45, 0), Vector2(-0.45, 0), Vector2(0, 0.45), Vector2(0, -0.45)]:
			var cell := Vector2i((p + offset).floor())
			if _occupied_at(cell) != 2 and not _surface.has(cell):
				_surface[cell] = _footpath


# --- Plaza, lanterns, benches and trees ------------------------------------------

func _furnish(streets: Array[Dictionary], rng: RandomNumberGenerator) -> void:
	var c := Vector2(center) + Vector2(0.5, 0.5)
	# A well off-center on the plaza; stalls and benches around its rim.
	var well_angle := _free_angle(rng, 0.45)
	_prop("res://props/town/well", c + Vector2.from_angle(well_angle) * (plaza_radius * 0.55), 0.0, Vector3(2.5, 1.1, 2.5))
	var stalls := 3 if capital else 2
	for k in 12:
		if stalls == 0:
			break
		var a := _free_angle(rng, 0.42)
		var p := c + Vector2.from_angle(a) * (plaza_radius + 2.6)
		var to_center := c - p
		if _prop("res://props/town/market", p, atan2(-to_center.x, -to_center.y), Vector3(3.4, 1.1, 1.9)):
			stalls -= 1
	var seats := 8 if capital else 4
	for k in seats:
		var a := (k + 0.5) * TAU / seats + 0.2
		if _near_exit(a, 0.35):
			continue
		var p := c + Vector2.from_angle(a) * (plaza_radius - (2.6 if capital else 1.8))
		var to_center := c - p
		_prop("res://props/town/bench", p, atan2(-to_center.x, -to_center.y), Vector3(2.7, 1.6, 1.0), false)
	# Lanterns light both sides of the streets.
	for s in streets:
		var spacing := 9.0 if s.kind == "main" else 13.0
		var pts: PackedVector2Array = s.points
		var total := _length(pts)
		var walked := spacing * 0.5
		var side := 1.0
		while walked < total:
			var at := _along(pts, walked)
			var tangent := (_along(pts, minf(walked + 1.0, total)) - _along(pts, maxf(walked - 1.0, 0.0))).normalized()
			var p: Vector2 = at + tangent.orthogonal() * side * (s.half + 0.9)
			if Vector2(p - c).length() < radius - 2.5 and _prop("res://props/home/lantern", p, 0.0, Vector3(1.2, 4.0, 1.2), true, 0.4):
				light_spots.append(Vector3(p.x, 3.3, p.y))
				side = -side
			walked += spacing
	# Yard trees, kept off streets, doors and the town edge.
	var kinds: Array = ["pine", "pine", "tree_small"] if biome_id == Biomes.FOSEN \
			else ["palm", "palm", "bush"] if biome_id == Biomes.DESERT \
			else ["tree_round", "tree_small", "bush", "tree_tall"]
	var wanted := 18 if capital else 9
	for k in 220:
		if wanted == 0:
			break
		var p := c + Vector2.from_angle(rng.randf() * TAU) * sqrt(rng.randf()) * (radius - 4.0)
		var clear := true
		for cell in _rect_cells(p, Vector2(2.2, 2.2), 0.0):
			if _occupied_at(cell) != 0 or _surface.has(cell):
				clear = false
				break
		if not clear:
			continue
		for cell in _rect_cells(p, Vector2(1.0, 1.0), 0.0):
			_mark(cell, 2)
		trees.append({prefab = kinds[rng.randi() % kinds.size()], pos = Vector3(p.x, base_height + 1, p.y), yaw = rng.randf() * TAU})
		wanted -= 1
	# Ordinary residents start around the plaza and wander the whole town.
	for i in (10 if capital else 4):
		var role: String = ["baker", "gardener", "villager", "traveler"][i % 4]
		var start := c + Vector2.from_angle(i * TAU / 10.0 + 0.3) * (plaza_radius + 1.0)
		residents.append(_npc(role, start, rng.randi(), false))
	# The steward keeps the town book at the town hall table on the plaza:
	# talk to them to make this town the account home (where all its characters arrive in a realm).
	var hall_angle := _free_angle(rng, 0.45)
	var steward := _npc("steward", c + Vector2.from_angle(hall_angle) * (plaza_radius - 1.4), rng.randi(), true)
	steward.model = "npc_traveler"
	steward.title = "Steward  -  Town Hall"
	var inward := -Vector2.from_angle(hall_angle)
	steward.yaw = atan2(-inward.x, -inward.y)
	residents.append(steward)


## Resolve stations after all furniture and trees have claimed their footprints.
func _settle_residents() -> void:
	var taken: Array[Vector2] = []
	for resident in residents:
		var desired := Vector2(resident.pos.x, resident.pos.z)
		var best := desired
		var score := INF
		for cell: Vector2i in _surface:
			var at := Vector2(cell) + Vector2.ONE * 0.5
			var distance := at.distance_squared_to(desired)
			if distance >= score:
				continue
			var clear := true
			for footprint in _rect_cells(at, Vector2.ONE * 0.8, 0.0):
				if _occupied_at(footprint) == 2:
					clear = false
			for other in taken:
				if at.distance_squared_to(other) < 2.25:
					clear = false
			if clear:
				best = at
				score = distance
		assert(is_finite(score), "No open station in " + display_name)
		resident.pos = Vector3(best.x, base_height + 1, best.y)
		if not resident.has("yaw") or resident.role == "steward":
			var toward := Vector2(center) + Vector2.ONE * 0.5 - best
			resident.yaw = atan2(-toward.x, -toward.y)
		taken.append(best)
	for service in service_sites:
		service.door = service.npc.pos


func _free_angle(rng: RandomNumberGenerator, gap: float) -> float:
	for k in 40:
		var a := rng.randf() * TAU
		if not _near_exit(a, gap):
			return a
	return rng.randf() * TAU


func _prop(asset: String, pos: Vector2, yaw: float, solid: Vector3, check := true, margin := 0.3) -> bool:
	var half := Vector2(solid.x, solid.z) * 0.5
	if check:
		for cell in _rect_cells(pos, half + Vector2.ONE * margin, yaw):
			if _occupied_at(cell) != 0:
				return false
	for cell in _rect_cells(pos, half, yaw):
		_mark(cell, 2)
	props.append({asset = asset, pos = Vector3(pos.x, base_height + 1, pos.y), yaw = yaw, solid_size = solid, scale = 1.0})
	return true


# --- Helpers ----------------------------------------------------------------------

## Cells under an oriented rectangle (half extents along local x/z, Godot Y rotation).
func _rect_cells(pos: Vector2, half: Vector2, yaw: float) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var c := cos(yaw)
	var s := sin(yaw)
	var reach := ceili(half.length()) + 1
	for z in range(floori(pos.y) - reach, floori(pos.y) + reach + 1):
		for x in range(floori(pos.x) - reach, floori(pos.x) + reach + 1):
			var d := Vector2(x + 0.5, z + 0.5) - pos
			var lx := d.x * c - d.y * s
			var lz := d.x * s + d.y * c
			if absf(lx) <= half.x and absf(lz) <= half.y:
				cells.append(Vector2i(x, z))
	return cells


func _inside(cell: Vector2i, margin: float) -> bool:
	return Vector2(cell - center).length() < radius - margin


func _occupied_at(cell: Vector2i) -> int:
	var l := cell - center + Vector2i.ONE * int(radius)
	if l.x < 0 or l.y < 0 or l.x >= _side or l.y >= _side:
		return 2
	return _occupied[l.y * _side + l.x]


func _mark(cell: Vector2i, value: int) -> void:
	var l := cell - center + Vector2i.ONE * int(radius)
	if l.x >= 0 and l.y >= 0 and l.x < _side and l.y < _side:
		var i := l.y * _side + l.x
		_occupied[i] = maxi(_occupied[i], value)


static func _length(points: PackedVector2Array) -> float:
	var total := 0.0
	for i in points.size() - 1:
		total += points[i].distance_to(points[i + 1])
	return total


static func _along(points: PackedVector2Array, distance: float) -> Vector2:
	for i in points.size() - 1:
		var step := points[i].distance_to(points[i + 1])
		if distance <= step:
			return points[i].lerp(points[i + 1], distance / maxf(step, 0.001))
		distance -= step
	return points[-1]


func _put(p: Vector2i, y: int, block: int) -> void:
	if not _columns.has(p):
		_columns[p] = []
	_columns[p].append_array([base_height + y, base_height + y + 1, block])


func _npc(role: String, at: Vector2, seed_value: int, stationary: bool) -> Dictionary:
	var route: Array[Vector3] = []
	for p in [Vector2.ZERO, Vector2(0, 8), Vector2.ZERO, Vector2(8, 0), Vector2.ZERO, Vector2(0, -8), Vector2.ZERO, Vector2(-8, 0)]:
		route.append(Vector3(center.x + p.x + 0.5, base_height + 1, center.y + p.y + 0.5))
	return {id = "%s_%s_%d" % [display_name, role, seed_value], role = role, seed = seed_value,
		pos = Vector3(at.x, base_height + 1, at.y), stationary = stationary,
		route = route, village = display_name, biome = biome_id, town_center = center, town_radius = radius}


## Whether a column is paved (plaza, streets, lanes, footpaths).
func is_street(x: int, z: int) -> bool:
	return _surface.has(Vector2i(x, z))


func shape(x: int, z: int, col: Array) -> bool:
	if not bounds.has_point(Vector2i(x, z)):
		return false
	var p := Vector2i(x, z)
	var distance := Vector2(x - center.x, z - center.y).length()
	if distance > radius:
		return false
	if distance > radius - 5.0:
		# Blend the town plateau into the surrounding terrain.
		col[0] = roundi(lerpf(float(col[0]), float(base_height), clampf((radius - distance) / 5.0, 0, 1)))
		if _surface.has(p):
			col[1] = _surface[p]
		return true
	col[0] = base_height
	col[1] = _surface.get(p, _ground)
	col[2] = _under
	if _columns.has(p):
		col.append_array(_columns[p])
	return true
