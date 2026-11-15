class_name PetYardWorld
extends GameWorld
## Account meadow. Layout and movement data also work without a scene tree.

const PREFIX := "pty_"
const FENCE := 26.0
const SPAWN_POINT := Vector3(0, 0, 17)
const RETURN_PORTAL := Vector3(0, 0, 23)
const NEST_POS := Vector3(0, 1, -13)
const CARETAKER_POS := Vector3(-15, 0, -7)
const STORE_POS := Vector3(15, 0, -7)
const COTTAGE_POS := Vector3(-16, 0, -14)
const POND := Rect2(8, 4, 10, 8)
const BRIDGE := Rect2(7, 7, 12, 2)
const TREES := [Vector3(-23, 0, 22), Vector3(23, 0, 22), Vector3(-23, 0, 2),
		Vector3(23, 0, -22), Vector3(-8, 0, -24), Vector3(8, 0, -23)]
const LANTERNS := [Vector3(-5, 0, 20), Vector3(5, 0, 20), Vector3(-16, 0, -5),
		Vector3(16, 0, -5), Vector3(-5, 1, -15), Vector3(5, 1, -15)]
const DRESSING := preload("res://scripts/world/pet_yard_dressing.gd")
const RESIDENTS := preload("res://scripts/world/pet_yard_residents.gd")

var server_build := false
var _biome: BiomeDef
var _solids: Array[AABB] = []


static func is_pet_yard(id: String) -> bool:
	return id == "pet_yard" or id.begins_with(PREFIX)


static func id_for(account_id: int) -> String:
	return PREFIX + str(account_id)


## [kind, base center, size]. Collision never depends on installed artwork.
static func furnishing_layout() -> Array:
	var out: Array = [
		["cottage", COTTAGE_POS, Vector3(7.5, 7.5, 8)],
		["stall", STORE_POS, Vector3(4, 3, 2.8)],
		["nest", NEST_POS, Vector3(3.4, 0.65, 3.4)],
	]
	for z in [6.8, 9.2]:
		out.append(["bridge_rail", Vector3(13, 0, z), Vector3(12.3, 1.1, 0.22)])
	for at: Vector3 in TREES:
		out.append(["tree", at, Vector3(1.4, 4, 1.4)])
	for at: Vector3 in LANTERNS:
		out.append(["lantern", at, Vector3(0.5, 3.5, 0.5)])
	for side in [-1.0, 1.0]:
		out.append(["fence", Vector3(side * FENCE, 0, 0), Vector3(0.4, 1.5, FENCE * 2 + 0.4)])
		out.append(["fence", Vector3(0, 0, side * FENCE), Vector3(FENCE * 2, 1.5, 0.4)])
		out.append(["portal", RETURN_PORTAL + Vector3(side * 2.3, 0, 0), Vector3(1.5, 6, 1.2)])
	return out


func _init(record := {}) -> void:
	realm_id = str(record.get("id", "pet_yard"))
	display_name = "Your Pet Yard"
	half_extent = 40
	spawn_point = SPAWN_POINT
	for entry: Array in furnishing_layout():
		var size: Vector3 = entry[2]
		_solids.append(AABB(entry[1] - Vector3(size.x * 0.5, 0, size.z * 0.5), size))


func _ready() -> void:
	if server_build: return
	_add_terrain(YardGenerator.new(), AABB(Vector3(-48, -8, -48), Vector3(96, 32, 96)))
	var decor := DRESSING.new()
	add_child(decor)
	decor.build(self)
	var portal := _add_portal(RETURN_PORTAL, Vector3.FORWARD, "hall", Color("72b6a0"), Color("ffe4a0"))
	var sign := SignBoard.make("Tavern", "brass", "door", Color.TRANSPARENT, 0.8)
	sign.position = Vector3(0, 4.6, 0.06)
	portal.add_child(sign)
	var residents := RESIDENTS.new()
	add_child(residents)
	residents.setup(self)


static func on_bridge(x: float, z: float) -> bool:
	return BRIDGE.has_point(Vector2(x, z))


static func in_pond(x: float, z: float) -> bool:
	return POND.has_point(Vector2(x, z))


static func rise_height(x: float, z: float) -> float:
	# One voxel step, approached by a path from the south.
	return 1.0 if absf(x) < 6 and z < -9 and z > -19 else 0.0


func ground_height(x: float, z: float) -> float:
	return rise_height(floorf(x) + 0.5, floorf(z) + 0.5)


func is_walkable(pos: Vector3) -> bool:
	if not pos.is_finite() or absf(pos.x) > FENCE - 0.65 or absf(pos.z) > FENCE - 0.65: return false
	for dx in [-0.35, 0.35]:
		for dz in [-0.35, 0.35]:
			if in_pond(pos.x + dx, pos.z + dz) and not on_bridge(pos.x + dx, pos.z + dz): return false
	for solid in _solids:
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
	return YardGenerator.path_at(pos.x, pos.z) or on_bridge(pos.x, pos.z)


func is_water(pos: Vector3) -> bool:
	return in_pond(pos.x, pos.z) and not on_bridge(pos.x, pos.z) and pos.y < -0.1


func map_color(x: int, z: int) -> Color:
	if in_pond(x + 0.5, z + 0.5) and not on_bridge(x + 0.5, z + 0.5): return WATER_COLOR
	for solid in _solids:
		if solid.has_point(Vector3(x + 0.5, solid.position.y + 0.1, z + 0.5)): return Color("a68a5d")
	return Blocks.map_color(YardGenerator.floor_block(x, z))


func region_at(pos: Vector3) -> String:
	if pos.distance_to(NEST_POS) < 6: return "Hatching Nest"
	if pos.distance_to(STORE_POS) < 6: return "Pet Store"
	if pos.distance_to(CARETAKER_POS) < 6: return "Caretaker's Cottage"
	return "Your Pet Yard"


func biome_at(_pos: Vector3) -> BiomeDef:
	if _biome == null:
		_biome = Biomes.get_biome(Biomes.HALL).duplicate()
		_biome.biome_name = "Pet Yard"
		_biome.indoor = false
		_biome.sky_top_color = Color("829fbe")
		_biome.sky_horizon_color = Color("f8d7a0")
		_biome.sun_color = Color("ffe0ad")
		_biome.sun_energy = 0.8
		_biome.sun_pitch = 38.0
		_biome.ambient_energy = 0.7
		_biome.fog_density = 0.001
		_biome.fog_of_war_enabled = false
	return _biome


class YardGenerator:
	extends VoxelGeneratorScript

	func _get_used_channels_mask() -> int:
		return 1 << VoxelBuffer.CHANNEL_TYPE

	static func path_at(x: float, z: float) -> bool:
		var corner := Vector2(maxf(0, absf(x) - 17), maxf(0, absf(z) - 17))
		var loop := absf(corner.length() - 4.0) < 1.1
		return loop or (absf(x) < 1.5 and z > -12 and z < 24) \
				or (absf(z + 6) < 1.4 and absf(x) < 17) \
				or (absf(z - 8) < 1.1 and x > 5 and x < 22)

	static func floor_block(x: int, z: int) -> int:
		if PetYardWorld.on_bridge(x + 0.5, z + 0.5): return Blocks.OAK_PLANKS
		if PetYardWorld.in_pond(x + 0.5, z + 0.5): return Blocks.SAND
		if path_at(x + 0.5, z + 0.5): return Blocks.DIRT if posmod(x * 17 + z * 13, 7) else Blocks.GRAVEL
		return Blocks.GRASS

	func _generate_block(buf: VoxelBuffer, origin: Vector3i, lod: int) -> void:
		if lod != 0: return
		var size := buf.get_size()
		for lz in size.z:
			for lx in size.x:
				var x := origin.x + lx
				var z := origin.z + lz
				var pond := PetYardWorld.in_pond(x + 0.5, z + 0.5)
				var top := -2 if pond else int(PetYardWorld.rise_height(x + 0.5, z + 0.5))
				_column(buf, origin, lx, lz, -8, top - 1, Blocks.DIRT)
				_column(buf, origin, lx, lz, top - 1, top, floor_block(x, z))
				if PetYardWorld.on_bridge(x + 0.5, z + 0.5): _column(buf, origin, lx, lz, -1, 0, Blocks.OAK_PLANKS)

	func _column(buf: VoxelBuffer, origin: Vector3i, x: int, z: int, low: int, high: int, block: int) -> void:
		var a := clampi(low - origin.y, 0, buf.get_size().y)
		var b := clampi(high - origin.y, 0, buf.get_size().y)
		if a < b: buf.fill_area(block, Vector3i(x, a, z), Vector3i(x + 1, b, z + 1), VoxelBuffer.CHANNEL_TYPE)
