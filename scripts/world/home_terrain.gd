@tool
class_name HomeTerrain
extends RefCounted
## The home island's ground, baked once from the editable Tavern scene:
## the "Coastline" curve gives the island its shape, HomeRoad curves and
## HomePlaza markers pave it. Read-only afterwards, so terrain worker threads,
## the minimap and the editor preview can all share it. Nothing here is seeded.

const EXTENT := 136  # half size of the baked area, in blocks
const SIDE := EXTENT * 2 + 1
const FLOOR := 9  # top block of the town plateau (you stand at FLOOR + 1)
const BEACH := 8  # top block of beaches and pier decks
const SEAFLOOR := 4
const PIER_POST := 2
## The Tavern floats in the sky: the lagoon reaches RIM blocks past the coast,
## then a shallow cloud rim (gaps where water spills over) and beyond it sky.
const RIM := 12.0
const VOID := -1000
## Waterfalls: angles (radians, from +x toward +z) and half widths of the gaps.
const FALLS := [[0.35, 0.09], [1.6, 0.07], [2.55, 0.1], [3.7, 0.08], [4.6, 0.06], [5.5, 0.09]]

var height := PackedByteArray()  # top block y per column
var top := PackedByteArray()  # top block id per column
var deck := PackedByteArray()  # 0 = none, 1 = pier deck over water, 2 = deck on a post
var _shore := PackedFloat32Array()  # distance to the coast (positive on land)


## Bakes the ground from a Tavern scene root (in play or in the editor).
static func from_scene(root: Node) -> HomeTerrain:
	var terrain := HomeTerrain.new()
	var coast := PackedVector2Array()
	var coastline := root.get_node_or_null("Coastline") as Path3D
	if coastline and coastline.curve and coastline.curve.point_count > 2:
		for p in coastline.curve.get_baked_points():
			var w := coastline.transform * p
			coast.append(Vector2(w.x, w.z))
	else:
		for i in 64:
			coast.append(Vector2.from_angle(i * TAU / 64.0) * 80.0)
	var roads: Array[Dictionary] = []
	var road_root := root.get_node_or_null("Roads")
	if road_root:
		for road in road_root.find_children("*", "Path3D", true, false):
			if not road is HomeRoad or road.curve == null or road.curve.point_count < 2:
				continue
			var points := PackedVector2Array()
			var to_root := _transform_to(road, root)
			for p in road.curve.get_baked_points():
				var w: Vector3 = to_root * p
				points.append(Vector2(w.x, w.z))
			roads.append({points = points, width = road.width, surface = road.surface, curbs = road.curbs})
	var plazas: Array[Dictionary] = []
	for plaza in root.find_children("*", "Marker3D", true, false):
		if plaza is HomePlaza:
			var at := _transform_to(plaza, root).origin
			plazas.append({center = Vector2(at.x, at.z), radius = plaza.radius, pattern = plaza.pattern})
	terrain.build(coast, roads, plazas)
	return terrain


static func _transform_to(node: Node3D, root: Node) -> Transform3D:
	var t := node.transform
	var parent := node.get_parent()
	while parent != null and parent != root:
		if parent is Node3D:
			t = (parent as Node3D).transform * t
		parent = parent.get_parent()
	return t


func build(coast: PackedVector2Array, roads: Array[Dictionary], plazas: Array[Dictionary]) -> void:
	height.resize(SIDE * SIDE)
	top.resize(SIDE * SIDE)
	deck.resize(SIDE * SIDE)
	deck.fill(0)
	var land := _rasterize(coast)
	_shore = _distance_field(land)
	for z in SIDE:
		for x in SIDE:
			var i := z * SIDE + x
			var d := _shore[i]
			var wx := x - EXTENT
			var wz := z - EXTENT
			if d < -RIM - 1.5:
				height[i] = 0  # open sky (top AIR marks it; heights are bytes)
				top[i] = Blocks.AIR
			elif d < -RIM + 0.5:
				# The lip round the lagoon, open where a waterfall pours over.
				height[i] = 6 if is_fall(wx, wz) else BEACH
				top[i] = Blocks.SEAFLOOR if is_fall(wx, wz) else Blocks.SNOW
			elif d <= 0.0:
				# Shallows, then a lagoon floor.
				height[i] = 7 if d > -1.5 else 6 if d > -4.0 else 5 if d > -9.0 else SEAFLOOR
				top[i] = Blocks.SAND if d > -4.0 else Blocks.SEAFLOOR
			elif d < 2.5:
				height[i] = BEACH
				top[i] = Blocks.SAND
			else:
				height[i] = FLOOR
				var sandy := d < 4.0 or (d < 6.0 and _hash(wx, wz, 3) < 0.5)
				top[i] = Blocks.SAND if sandy else Blocks.GRASS
	for road in roads:
		_pave_road(road)
	for plaza in plazas:
		_pave_plaza(plaza)


func index(x: int, z: int) -> int:
	if absi(x) > EXTENT or absi(z) > EXTENT:
		return -1
	return (z + EXTENT) * SIDE + x + EXTENT


## Top block y of a column (VOID: open sky, past the rim or the baked area).
func top_y(x: int, z: int) -> int:
	var i := index(x, z)
	return VOID if i < 0 or top[i] == Blocks.AIR else height[i]


## A waterfall gap in the lip at this column.
static func is_fall(x: int, z: int) -> bool:
	var a := fposmod(atan2(float(z), float(x)), TAU)
	for fall: Array in FALLS:
		if absf(angle_difference(a, float(fall[0]))) < float(fall[1]): return true
	return false


func block(x: int, z: int) -> int:
	var i := index(x, z)
	return Blocks.SEAFLOOR if i < 0 else top[i]


func has_deck(x: int, z: int) -> bool:
	var i := index(x, z)
	return i >= 0 and deck[i] > 0


## Dry ground or a pier deck.
func is_land(x: int, z: int) -> bool:
	var i := index(x, z)
	return i >= 0 and (height[i] >= BEACH or deck[i] > 0)


## Where feet stand at this column.
func stand_height(x: int, z: int) -> float:
	var i := index(x, z)
	if i < 0:
		return SEAFLOOR + 1.0  # never walked on (is_land is false out there)
	return BEACH + 1.0 if deck[i] > 0 else height[i] + 1.0


## Distance to the coastline in blocks (negative at sea).
func shore_distance(x: int, z: int) -> float:
	var i := index(x, z)
	return -99.0 if i < 0 else _shore[i]


func map_color(x: int, z: int) -> Color:
	var i := index(x, z)
	if i < 0:
		return GameWorld.WATER_COLOR
	if deck[i] > 0:
		return Blocks.map_color(Blocks.TIMBER)
	var color := Blocks.map_color(top[i])
	if height[i] < BEACH:
		return color.lerp(GameWorld.WATER_COLOR, clampf(0.55 + (BEACH - height[i]) * 0.12, 0.0, 0.92))
	return color if height[i] == FLOOR else color.darkened(0.06)


# --- Baking ---------------------------------------------------------------------

## Scanline fill of the coast polygon.
func _rasterize(coast: PackedVector2Array) -> PackedByteArray:
	var land := PackedByteArray()
	land.resize(SIDE * SIDE)
	land.fill(0)
	var n := coast.size()
	for z in SIDE:
		var y := z - EXTENT + 0.5
		var hits := PackedFloat32Array()
		for k in n:
			var a := coast[k]
			var b := coast[(k + 1) % n]
			if (a.y <= y) != (b.y <= y):
				hits.append(a.x + (y - a.y) / (b.y - a.y) * (b.x - a.x))
		hits.sort()
		for k in range(0, hits.size() - 1, 2):
			var x0 := clampi(ceili(hits[k] - 0.5) + EXTENT, 0, SIDE)
			var x1 := clampi(floori(hits[k + 1] - 0.5) + EXTENT, -1, SIDE - 1)
			for x in range(x0, x1 + 1):
				land[z * SIDE + x] = 1
	return land


## Signed chamfer distance to the coast: positive on land, negative at sea.
func _distance_field(land: PackedByteArray) -> PackedFloat32Array:
	var inside := _chamfer(land, 1)
	var outside := _chamfer(land, 0)
	var out := PackedFloat32Array()
	out.resize(SIDE * SIDE)
	for i in SIDE * SIDE:
		out[i] = inside[i] if land[i] == 1 else -outside[i]
	return out


## Distance from each `value` cell to the nearest other cell.
func _chamfer(land: PackedByteArray, value: int) -> PackedFloat32Array:
	const BIG := 1e6
	const D := 1.0
	const DD := 1.4142
	var d := PackedFloat32Array()
	d.resize(SIDE * SIDE)
	for i in SIDE * SIDE:
		d[i] = BIG if land[i] == value else 0.0
	for z in SIDE:
		for x in SIDE:
			var i := z * SIDE + x
			if d[i] == 0.0:
				continue
			var best := d[i]
			if x > 0: best = minf(best, d[i - 1] + D)
			if z > 0:
				best = minf(best, d[i - SIDE] + D)
				if x > 0: best = minf(best, d[i - SIDE - 1] + DD)
				if x < SIDE - 1: best = minf(best, d[i - SIDE + 1] + DD)
			d[i] = best
	for z in range(SIDE - 1, -1, -1):
		for x in range(SIDE - 1, -1, -1):
			var i := z * SIDE + x
			if d[i] == 0.0:
				continue
			var best := d[i]
			if x < SIDE - 1: best = minf(best, d[i + 1] + D)
			if z < SIDE - 1:
				best = minf(best, d[i + SIDE] + D)
				if x < SIDE - 1: best = minf(best, d[i + SIDE + 1] + DD)
				if x > 0: best = minf(best, d[i + SIDE - 1] + DD)
			d[i] = best
	return d


func _pave_road(road: Dictionary) -> void:
	var half: float = road.width * 0.5
	var reach := half + 1.0
	var nearest := {}  # column index -> distance to the road's center line
	for p: Vector2 in road.points:
		for z in range(floori(p.y - reach), ceili(p.y + reach) + 1):
			for x in range(floori(p.x - reach), ceili(p.x + reach) + 1):
				var i := index(x, z)
				if i < 0:
					continue
				var d := Vector2(x + 0.5, z + 0.5).distance_to(p)
				if d < nearest.get(i, reach):
					nearest[i] = d
	for i: int in nearest:
		var d: float = nearest[i]
		var x := i % SIDE - EXTENT
		var z := i / SIDE - EXTENT
		var curb: bool = road.curbs and d > half - 1.0
		match road.surface:
			"cobble":
				if d < half:
					top[i] = Blocks.HALL_TRIM if curb else Blocks.GRAVEL if _hash(x, z, 11) < 0.07 else Blocks.PAVING
			"tiles":
				if d < half:
					top[i] = Blocks.HALL_TRIM if curb or (x % 5 == 0 and z % 5 == 0) else Blocks.HALL_FLOOR
			"gravel":
				if d < half or (d < half + 0.8 and _hash(x, z, 12) < 0.45):
					top[i] = Blocks.PAVING if _hash(x, z, 13) < 0.12 else Blocks.GRAVEL
			"dirt":
				if d < half or (d < half + 0.7 and _hash(x, z, 14) < 0.4):
					top[i] = Blocks.GRAVEL if _hash(x, z, 15) < 0.18 else Blocks.DIRT
			"pier":
				if d < half:
					if height[i] < BEACH:
						deck[i] = PIER_POST if d > half - 1.0 and posmod(x + z, 4) == 0 else 1
					else:
						top[i] = Blocks.TIMBER


func _pave_plaza(plaza: Dictionary) -> void:
	var c: Vector2 = plaza.center
	var r: float = plaza.radius
	for z in range(floori(c.y - r), ceili(c.y + r) + 1):
		for x in range(floori(c.x - r), ceili(c.x + r) + 1):
			var i := index(x, z)
			var offset := Vector2(x + 0.5, z + 0.5) - c
			var d := offset.length()
			if i < 0 or d >= r or height[i] < BEACH:
				continue
			var block := Blocks.PAVING
			match plaza.pattern:
				"rings":
					var spoke := absf(sin(offset.angle() * 4.0)) * d < 0.7 and d > 4.0
					block = Blocks.HALL_TRIM if spoke or d > r - 1.2 else Blocks.HALL_FLOOR if int(d / 2.5) % 2 == 0 else Blocks.PAVING
				"tiles":
					block = Blocks.HALL_TRIM if d > r - 1.2 or (posmod(x, 5) == 0 and posmod(z, 5) == 0) else Blocks.HALL_FLOOR
				_:
					block = Blocks.HALL_TRIM if d > r - 1.2 else Blocks.PAVING
			top[i] = block
			height[i] = FLOOR


static func _hash(x: int, z: int, salt: int) -> float:
	var n := x * 374761393 + z * 668265263 + salt * 982451653
	n = (n ^ (n >> 13)) * 1274126177
	n = n ^ (n >> 16)
	return float(n & 0xFFFFFF) / float(0xFFFFFF)
