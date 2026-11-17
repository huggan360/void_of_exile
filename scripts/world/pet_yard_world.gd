class_name PetYardWorld
extends GameWorld
## The account's Pet Yard: an island in a quiet sea, in the Surface's 0.25 m
## voxels. The flat, fenced meadow where you arrive is the pets' own (nest,
## Caretaker, pond, wandering pets); a gate in its east fence opens onto a dirt
## trail that winds over wooded hills to the Pet Store, a walk-in shop by the
## shore. Layout and movement data also work without a scene tree (the server
## builds only that): the island's shape is sampled once onto a 1 m grid,
## shared by every yard, and the terrain and ground_height() read it.

const PREFIX := "pty_"
const FENCE := 26.0
## The gate is three fence pieces wide (pieces are 52 / 22 m), centred on piece 8.
const GATE_Z := -5.91
const GATE_HALF := 3.54
const SPAWN_POINT := Vector3(0, 0, 17)
const RETURN_PORTAL := Vector3(0, 0, 23)
const NEST_POS := Vector3(0, 1, -13)
const CARETAKER_POS := Vector3(-15, 0, -7)
const COTTAGE_POS := Vector3(-16, 0, -14)
const POND := Rect2(8, 4, 10, 8)
const BRIDGE := Rect2(7, 7, 12, 2)
const TREES := [Vector3(-23, 0, 22), Vector3(23, 0, 22), Vector3(-23, 0, 2),
		Vector3(23, 0, -22), Vector3(-8, 0, -24), Vector3(8, 0, -23)]
const LANTERNS := [Vector3(-5, 0, 20), Vector3(5, 0, 20), Vector3(-16, 0, -5),
		Vector3(16, 0, -5), Vector3(-5, 1, -15), Vector3(5, 1, -15)]
const SEA_LEVEL := -1.5
## The Pet Store (model pet_store_house, its door facing +Z down the trail).
const SHOP_POS := Vector3(64, 1, -36)
const SHOP_YAW := PI
## Where the storekeeper stands, behind the counter.
const STORE_POS := Vector3(64, 1, -39.9)
## The shop's stone footing (its floor's top is SHOP_POS.y); the terrain sits
## a voxel lower inside so the planks never fight it.
const SHOP_FLOOR := Rect2(57.25, -41.25, 13.5, 10.5)
## Flat ground round the shop and its little cobbled square at the door.
const SHOP_FLAT := Rect2(55, -44, 18, 20)
const SHOP_SQUARE := Rect2(58, -31, 12, 6)
## The trail's middle line, from the meadow's gate to the shop door.
const TRAIL: Array[Vector2] = [Vector2(24, -6), Vector2(33, -6), Vector2(40, -9.5), Vector2(45.5, -15.5),
		Vector2(50.5, -22), Vector2(57, -25.5), Vector2(64, -26.5), Vector2(64, -30.5)]
## Land: round blobs (x, z, radius) plus noise on the coast.
const ISLAND: Array[Vector3] = [Vector3(0, 0, 54), Vector3(44, -16, 24), Vector3(66, -34, 30),
		Vector3(-24, -42, 22), Vector3(26, 34, 18), Vector3(-34, 18, 16)]
## A wooded hill in the north-west (x, z, radius; its top height).
const HILL := Vector3(-24, -44, 20)
const HILL_HEIGHT := 5.0
## The terrain grid (1 m cells) and the voxel terrain's bounds (whole 8 m blocks).
const GRID_MIN := Vector2i(-64, -80)
const GRID_SIZE := Vector2i(168, 152)
const DRESSING := preload("res://scripts/world/pet_yard_dressing.gd")
const RESIDENTS := preload("res://scripts/world/pet_yard_residents.gd")
const ISLAND_ART := preload("res://scripts/world/pet_yard_island.gd")

var server_build := false
var _biome: BiomeDef
var _solids: Array[AABB] = []

static var _grid_ready := false
static var _height := PackedFloat32Array()
static var _trail_weight := PackedFloat32Array()
static var _land := PackedFloat32Array()
static var _forest := PackedFloat32Array()
static var _noise := FastNoiseLite.new()
static var _patches := FastNoiseLite.new()
static var _coast := FastNoiseLite.new()


static func is_pet_yard(id: String) -> bool:
	return id == "pet_yard" or id.begins_with(PREFIX)


static func id_for(account_id: int) -> String:
	return PREFIX + str(account_id)


func first_person_at(position: Vector3) -> bool:
	return position.y > SHOP_POS.y - 0.5 and position.y < SHOP_POS.y + 3.75 \
		and SHOP_FLOOR.grow(-0.2).has_point(Vector2(position.x, position.z))


## [kind, base center, size]. Collision never depends on installed artwork.
static func furnishing_layout() -> Array:
	var out: Array = [
		["cottage", COTTAGE_POS, Vector3(7.5, 7.5, 8)],
		["nest", NEST_POS, Vector3(3.4, 0.65, 3.4)],
	]
	for z in [6.8, 9.2]:
		out.append(["bridge_rail", Vector3(13, 0, z), Vector3(12.3, 1.1, 0.22)])
	for at: Vector3 in TREES:
		out.append(["tree", at, Vector3(1.4, 4, 1.4)])
	for at: Vector3 in LANTERNS:
		out.append(["lantern", at, Vector3(0.5, 3.5, 0.5)])
	for side in [-1.0, 1.0]:
		out.append(["fence", Vector3(0, 0, side * FENCE), Vector3(FENCE * 2, 1.5, 0.4)])
		out.append(["portal", RETURN_PORTAL + Vector3(side * 2.3, 0, 0), Vector3(1.5, 6, 1.2)])
	out.append(["fence", Vector3(-FENCE, 0, 0), Vector3(0.4, 1.5, FENCE * 2 + 0.4)])
	# The east fence leaves a gate open onto the trail.
	var north := GATE_Z - GATE_HALF + FENCE
	var south := FENCE - GATE_Z - GATE_HALF
	out.append(["fence", Vector3(FENCE, 0, -FENCE + north * 0.5), Vector3(0.4, 1.5, north + 0.2)])
	out.append(["fence", Vector3(FENCE, 0, FENCE - south * 0.5), Vector3(0.4, 1.5, south + 0.2)])
	return out


## The shop's walls and furniture as world boxes (from the baked catalogue).
static func shop_solids() -> Array[AABB]:
	var out: Array[AABB] = []
	var xform := Transform3D(Basis(Vector3.UP, SHOP_YAW), SHOP_POS)
	for c: Dictionary in CityHouses.info("pet_store_house").get("colliders", []):
		var size := Vector3(c.size[0], c.size[1], c.size[2])
		var center := xform * Vector3(c.offset[0], c.offset[1], c.offset[2])
		out.append(AABB(center - size * 0.5, size).abs())
	return out


func _init(record := {}) -> void:
	realm_id = str(record.get("id", "pet_yard"))
	display_name = "Your Pet Yard"
	half_extent = 96
	spawn_point = SPAWN_POINT
	_water_surface = SEA_LEVEL
	build_grid()
	for entry: Array in furnishing_layout():
		if entry[0] == "portal": continue
		var size: Vector3 = entry[2]
		_solids.append(AABB(entry[1] - Vector3(size.x * 0.5, 0, size.z * 0.5), size))
	_solids.append_array(shop_solids())


func _ready() -> void:
	if server_build: return
	var f := 4
	_add_terrain(PetYardTerrain.new(), AABB(Vector3(GRID_MIN.x * f, -48, GRID_MIN.y * f), Vector3(GRID_SIZE.x * f, 96, GRID_SIZE.y * f)),
		"pet_yard", ["res://scripts/world/pet_yard_world.gd"], SurfaceBlocks.mesher())
	terrain.scale = Vector3.ONE / f
	terrain.mesh_block_size = 32
	terrain.max_view_distance = 400
	var format := VoxelFormat.new()
	format.set_channel_depth(VoxelBuffer.CHANNEL_TYPE, VoxelBuffer.DEPTH_8_BIT)
	terrain.format = format
	terrain.material_override = SurfaceBlocks.material()
	var sea := _add_water(SEA_LEVEL, 700.0)
	sea.material_override = SurfaceWater.sea_material()
	_water_surface = SEA_LEVEL
	var decor := DRESSING.new()
	add_child(decor)
	decor.build(self)
	var island := ISLAND_ART.new()
	add_child(island)
	island.build(self)
	var portal := _add_portal(RETURN_PORTAL, Vector3.FORWARD, "hall", Color("72b6a0"), Color("ffe4a0"))
	var sign := SignBoard.make("Tavern", "brass", "door", Color.TRANSPARENT, 0.8)
	sign.position = Vector3(0, 4.6, 0.06)
	portal.add_child(sign)
	var residents := RESIDENTS.new()
	add_child(residents)
	residents.setup(self)


# --- The island's shape ----------------------------------------------------------------

## Samples the island onto the 1 m grid once (main thread, before any terrain).
static func build_grid() -> void:
	if _grid_ready: return
	_noise.seed = 4127
	_noise.frequency = 0.028
	_noise.fractal_octaves = 3
	_patches.seed = 991
	_patches.frequency = 0.045
	_coast.seed = 2203
	_coast.frequency = 0.05
	_coast.fractal_octaves = 2
	var count := (GRID_SIZE.x + 1) * (GRID_SIZE.y + 1)
	for list: PackedFloat32Array in [_height, _trail_weight, _land, _forest]: list.resize(count)
	for j in GRID_SIZE.y + 1:
		for i in GRID_SIZE.x + 1:
			var x := float(GRID_MIN.x + i)
			var z := float(GRID_MIN.y + j)
			var k := j * (GRID_SIZE.x + 1) + i
			var land := _land_at(x, z)
			var h := _base(x, z)
			var near := _trail_point(x, z)
			var w := 1.0 - smoothstep(1.4, 3.4, Vector2(x, z).distance_to(near))
			h = lerpf(h, _base(near.x, near.y), w)
			if maxf(absf(x), absf(z)) < FENCE + 1.0: land = maxf(land, 12.0)  # the meadow stays level
			if land < 12.0: h = lerpf(SEA_LEVEL + 0.25 + maxf(land, 0.0) * 0.12, h, smoothstep(3.0, 12.0, land))
			if land < 0.0: h = maxf(SEA_LEVEL - 7.0, SEA_LEVEL + 0.25 + land * 0.5)
			_height[k] = h
			_trail_weight[k] = w
			_land[k] = land
			var hill := maxf(0.0, 1.0 - Vector2(x - HILL.x, z - HILL.y).length() / HILL.z)
			_forest[k] = clampf(_patches.get_noise_2d(x, z) * 0.5 + 0.5 + hill * 0.45, 0.0, 1.0)
	_grid_ready = true


## Metres inside the coast (negative out at sea).
static func _land_at(x: float, z: float) -> float:
	var best := -INF
	for blob: Vector3 in ISLAND:
		best = maxf(best, blob.z - Vector2(x - blob.x, z - blob.y).length())
	return best + _coast.get_noise_2d(x, z) * 5.0


## The ground before the trail and the coast shape it: the flat meadow (with
## the nest's mound), rolling hills beyond, the shop's level square.
static func _base(x: float, z: float) -> float:
	var mound := 1.0 - smoothstep(4.6, 8.0, Vector2(x - NEST_POS.x, z + 13.5).length())
	var hills := 1.0 + 2.6 * (_noise.get_noise_2d(x, z) * 0.5 + 0.5)
	var hill := maxf(0.0, 1.0 - Vector2(x - HILL.x, z - HILL.y).length() / HILL.z)
	hills += HILL_HEIGHT * hill * hill * (3.0 - 2.0 * hill)
	var h := lerpf(mound, hills, smoothstep(FENCE + 1.5, FENCE + 14.0, maxf(absf(x), absf(z))))
	return lerpf(h, SHOP_POS.y, 1.0 - smoothstep(0.0, 7.0, _rect_distance(SHOP_FLAT, x, z)))


static func _rect_distance(rect: Rect2, x: float, z: float) -> float:
	var dx := maxf(rect.position.x - x, x - rect.end.x)
	var dz := maxf(rect.position.y - z, z - rect.end.y)
	return Vector2(maxf(dx, 0.0), maxf(dz, 0.0)).length()


## The nearest point on the trail's middle line.
static func _trail_point(x: float, z: float) -> Vector2:
	var p := Vector2(x, z)
	var best := TRAIL[0]
	for i in TRAIL.size() - 1:
		var q := Geometry2D.get_closest_point_to_segment(p, TRAIL[i], TRAIL[i + 1])
		if p.distance_squared_to(q) < p.distance_squared_to(best): best = q
	return best


## Bilinear sample of one grid list at (x, z) metres.
static func _sample(list: PackedFloat32Array, x: float, z: float) -> float:
	var fx := clampf(x - GRID_MIN.x, 0.0, GRID_SIZE.x - 0.001)
	var fz := clampf(z - GRID_MIN.y, 0.0, GRID_SIZE.y - 0.001)
	var i := int(fx)
	var j := int(fz)
	var tx := fx - i
	var tz := fz - j
	var row := GRID_SIZE.x + 1
	var k := j * row + i
	return lerpf(lerpf(list[k], list[k + 1], tx), lerpf(list[k + row], list[k + row + 1], tx), tz)


static func in_meadow(x: float, z: float) -> bool:
	return absf(x) < FENCE and absf(z) < FENCE


static func on_bridge(x: float, z: float) -> bool:
	return BRIDGE.has_point(Vector2(x, z))


static func in_pond(x: float, z: float) -> bool:
	return POND.has_point(Vector2(x, z))


static func on_shop_floor(x: float, z: float) -> bool:
	return SHOP_FLOOR.has_point(Vector2(x, z))


static func path_at(x: float, z: float) -> bool:
	var corner := Vector2(maxf(0, absf(x) - 17), maxf(0, absf(z) - 17))
	var loop := absf(corner.length() - 4.0) < 1.1
	return loop or (absf(x) < 1.5 and z > -12 and z < 24) \
			or (absf(z - GATE_Z) < 1.4 and x > -17 and x < FENCE + 1.0) \
			or (absf(z - 8) < 1.1 and x > 5 and x < 22)


## The terrain column under (x, z): Vector2i(top voxel, block). The ground's
## top is top / 4 metres; the generator and ground_height() share this.
static func column(x: float, z: float) -> Vector2i:
	var cx := (floorf(x * 4.0) + 0.5) * 0.25
	var cz := (floorf(z * 4.0) + 0.5) * 0.25
	if in_meadow(cx, cz):
		if on_bridge(cx, cz): return Vector2i(0, SurfaceBlocks.PLANKS)
		if in_pond(cx, cz):
			var edge := minf(minf(cx - POND.position.x, POND.end.x - cx), minf(cz - POND.position.y, POND.end.y - cz))
			return Vector2i(-2 if edge < 0.75 else -4, SurfaceBlocks.SAND_FINE if edge < 0.75 else SurfaceBlocks.RIVERBED)
	if on_shop_floor(cx, cz): return Vector2i(roundi(SHOP_POS.y * 4.0) - 1, SurfaceBlocks.PLANKS)
	var top := roundi(_sample(_height, cx, cz) * 4.0)
	var land := _sample(_land, cx, cz)
	var spot := SurfaceMap.hash01(int(cx * 4.0), int(cz * 4.0), 7)
	if top < roundi(SEA_LEVEL * 4.0) - 1: return Vector2i(top, SurfaceBlocks.SEAFLOOR_FINE if top < roundi((SEA_LEVEL - 1.2) * 4.0) else SurfaceBlocks.SAND_FINE)
	if SHOP_SQUARE.has_point(Vector2(cx, cz)): return Vector2i(top, SurfaceBlocks.COBBLE)
	if in_meadow(cx, cz):
		if path_at(cx, cz): return Vector2i(top, SurfaceBlocks.DIRT_PATH if spot > 0.12 else SurfaceBlocks.GRAVEL_FINE)
		return Vector2i(top, SurfaceBlocks.MEADOW if _sample(_forest, cx, cz) < 0.33 else SurfaceBlocks.GRASS_LUSH)
	var trail := _sample(_trail_weight, cx, cz)
	if trail > 0.6 or (trail > 0.4 and spot < 0.5): return Vector2i(top, SurfaceBlocks.DIRT_PATH if spot > 0.15 else SurfaceBlocks.GRAVEL_FINE)
	if land < 4.5 + spot: return Vector2i(top, SurfaceBlocks.SAND_FINE)
	var slope := absf(_sample(_height, cx + 0.5, cz) - _sample(_height, cx - 0.5, cz)) + absf(_sample(_height, cx, cz + 0.5) - _sample(_height, cx, cz - 0.5))
	if slope > 1.1: return Vector2i(top, SurfaceBlocks.MOSS_ROCK)
	var forest := _sample(_forest, cx, cz)
	if forest > 0.62: return Vector2i(top, SurfaceBlocks.FOREST_FLOOR)
	return Vector2i(top, SurfaceBlocks.MEADOW if forest < 0.3 else SurfaceBlocks.GRASS)


## Plant density at (x, z): 0 open, 1 deep woods.
static func forest_at(x: float, z: float) -> float:
	return _sample(_forest, x, z)


static func land_at(x: float, z: float) -> float:
	return _sample(_land, x, z)


static func trail_at(x: float, z: float) -> float:
	return _sample(_trail_weight, x, z)


func ground_height(x: float, z: float) -> float:
	if on_shop_floor(x, z): return SHOP_POS.y
	return column(x, z).x * 0.25


## Meadow pets stay inside the fence.
func pet_walkable(pos: Vector3) -> bool:
	return is_walkable(pos) and absf(pos.x) < FENCE - 0.65 and absf(pos.z) < FENCE - 0.65


func is_walkable(pos: Vector3) -> bool:
	if not pos.is_finite(): return false
	if pos.x < GRID_MIN.x + 2 or pos.z < GRID_MIN.y + 2 or pos.x > GRID_MIN.x + GRID_SIZE.x - 2 or pos.z > GRID_MIN.y + GRID_SIZE.y - 2: return false
	for dx in [-0.35, 0.35]:
		for dz in [-0.35, 0.35]:
			if in_pond(pos.x + dx, pos.z + dz) and not on_bridge(pos.x + dx, pos.z + dz): return false
	if ground_height(pos.x, pos.z) < SEA_LEVEL - 0.3: return false
	for solid in _solids:
		if pos.y + 0.5 < solid.position.y or pos.y > solid.end.y: continue
		if pos.x > solid.position.x - 0.35 and pos.x < solid.end.x + 0.35 \
				and pos.z > solid.position.z - 0.35 and pos.z < solid.end.z + 0.35: return false
	return true


func clear_segment(a: Vector3, b: Vector3) -> bool:
	if not is_walkable(b): return false
	var steps := maxi(1, ceili(a.distance_to(b) / 0.3))
	for i in range(1, steps + 1):
		if not is_walkable(a.lerp(b, float(i) / steps)): return false
	return true


func is_road(pos: Vector3) -> bool:
	return (in_meadow(pos.x, pos.z) and path_at(pos.x, pos.z)) or on_bridge(pos.x, pos.z) or trail_at(pos.x, pos.z) > 0.5


func is_water(pos: Vector3) -> bool:
	if in_pond(pos.x, pos.z) and not on_bridge(pos.x, pos.z): return pos.y < -0.1
	return pos.y <= SEA_LEVEL + 0.1


func map_color(x: int, z: int) -> Color:
	var c := column(x + 0.5, z + 0.5)
	if c.x < roundi(SEA_LEVEL * 4.0): return WATER_COLOR
	if in_meadow(x + 0.5, z + 0.5) and in_pond(x + 0.5, z + 0.5) and not on_bridge(x + 0.5, z + 0.5): return WATER_COLOR
	if on_shop_floor(x + 0.5, z + 0.5): return Color("c9a77a")
	for solid in _solids:
		if solid.has_point(Vector3(x + 0.5, solid.position.y + 0.1, z + 0.5)): return Color("a68a5d")
	match c.y:
		SurfaceBlocks.SAND_FINE: return Color("e3d3a2")
		SurfaceBlocks.DIRT_PATH, SurfaceBlocks.GRAVEL_FINE, SurfaceBlocks.COBBLE: return Color("a88a60")
		SurfaceBlocks.FOREST_FLOOR: return Color("3f6b30")
		SurfaceBlocks.MOSS_ROCK: return Color("6f7a5e")
		SurfaceBlocks.PLANKS: return Color("a07850")
	return Color("6fa848")


func region_at(pos: Vector3) -> String:
	if pos.distance_to(NEST_POS) < 6: return "Hatching Nest"
	if _rect_distance(SHOP_FLAT, pos.x, pos.z) < 2: return "Pet Store"
	if pos.distance_to(CARETAKER_POS) < 6: return "Caretaker's Cottage"
	if in_meadow(pos.x, pos.z): return "Pet Meadow"
	if trail_at(pos.x, pos.z) > 0.3: return "Store Trail"
	if land_at(pos.x, pos.z) < 6: return "Shore"
	return "Your Pet Yard"


func biome_at(_pos: Vector3) -> BiomeDef:
	if _biome == null:
		_biome = Biomes.get_biome(Biomes.HALL).duplicate()
		_biome.biome_name = "Pet Yard"
		_biome.indoor = false
		_biome.sky_top_color = Color("6f9cc8")
		_biome.sky_horizon_color = Color("f6d9a8")
		_biome.sun_color = Color("ffe2b0")
		_biome.sun_energy = 0.85
		_biome.sun_pitch = 40.0
		_biome.ambient_energy = 0.72
		_biome.fog_density = 0.0035
		_biome.fog_of_war_enabled = false
	return _biome
