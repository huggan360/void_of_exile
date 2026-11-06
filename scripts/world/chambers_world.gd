class_name ChambersWorld
extends GameWorld
## An account's roofless cathedral vault, surrounded by an old churchyard.
## Chest slots and solid footprints are pure layout data: the dedicated
## server has no Chambers scene. Realm id: "chm_<account id>".

const PREFIX := "chm_"
const HALF_WIDTH := 16
const SOUTH := 22
const NORTH := -22
const APSE_NORTH := -30
const CHAPEL_WIDTH := 24
const CHAPEL_NORTH := -17
const CHAPEL_SOUTH := -2
const WALL_HEIGHT := 6
const YARD_EXTENT := 56
const ROW_STEP := 2.5
const FIRST_ROW := 15.0
const CHEST_BANKS := [10.0, 12.4, 14.8]
const DRESSING := preload("res://scripts/world/chambers_dressing.gd")
const SPAWN_POINT := Vector3.ZERO
const RETURN_PORTAL := Vector3(0,0,18.5)

var chests := 4
var _biome: BiomeDef
var _solids: Array[AABB] = []


static func is_chambers(id: String) -> bool:
	return id == "chambers" or id.begins_with(PREFIX)


static func id_for(account_id: int) -> String:
	return PREFIX + str(account_id)


## Stable entrance-first ordering, paired west/east. Ninety places in the
## side aisles and thirty in the transept; growing a vault never moves a slot.
static func chest_layout(count: int) -> Array:
	var slots: Array = []
	for row in 15:
		var z := FIRST_ROW - row * ROW_STEP
		var banks: Array = CHEST_BANKS.duplicate()
		if row >= 8 and row <= 12:
			banks.append_array([17.5, 20.0, 22.5])
		for x: float in banks:
			for side in [-1.0, 1.0]:
				slots.append([Vector3(side * x, 0.0, z), -side * PI / 2.0])
	return slots.slice(0, maxi(0, count))


## Kept for callers that used the old variable-length hall.
static func length_for(_count: int) -> int:
	return SOUTH - APSE_NORTH


static func inside_floor(x: float, z: float) -> bool:
	return (absf(x) < HALF_WIDTH and z > NORTH and z < SOUTH) \
			or (absf(x) < CHAPEL_WIDTH and z > CHAPEL_NORTH and z < CHAPEL_SOUTH) \
			or (absf(x) < 8.0 and z > APSE_NORTH and z <= NORTH)


## [kind, base center, solid envelope]. Dressing uses these same envelopes.
static func furnishing_layout() -> Array:
	var out: Array = []
	for side in [-1.0, 1.0]:
		for z in [12.0, 4.0, -4.0, -12.0, -20.0]:
			out.append(["column", Vector3(side * 7.6, 0, z), Vector3(1.6, 7.2, 1.6)])
		for z in [10.0, 6.0, 2.0, -2.0, -6.0, -10.0, -14.0]:
			out.append(["pew", Vector3(side * 5.0, 0, z), Vector3(3.5, 1.35, 1.1)])
		for z in [16.0, 8.0, 0.0, -8.0, -18.0]:
			out.append(["candle", Vector3(side * 3.15, 0, z), Vector3(0.95, 2.5, 0.5)])
	out.append(["altar", Vector3(0, 0, -26.5), Vector3(6.4, 1.9, 1.8)])
	out.append(["cross", Vector3(0, 0, -29.3), Vector3(1.2, 5.3, 0.7)])
	out.append(["lectern", Vector3(-5.2, 0, -23.6), Vector3(1.0, 1.6, 1.0)])
	# The return gate's own stone pillars, also reserved without a scene.
	for side in [-1.0,1.0]:
		out.append(["portal_pillar", RETURN_PORTAL+Vector3(side*2.3,0,0), Vector3(1.5, 6.0, 1.2)])
	return out


func _init(record := {}) -> void:
	realm_id = str(record.get("id", "chambers"))
	chests = maxi(1, int(record.get("chests", 4)))
	display_name = "Your Chambers"
	half_extent = YARD_EXTENT + 8
	spawn_point = SPAWN_POINT
	for entry: Array in furnishing_layout():
		var size: Vector3 = entry[2]
		_solids.append(AABB(entry[1] - Vector3(size.x * 0.5, 0, size.z * 0.5), size))


func biome_at(_pos: Vector3) -> BiomeDef:
	if _biome == null:
		_biome = BiomeDef.new()
		_biome.biome_name = "The Chambers"
		_biome.indoor = true
		_biome.sky_top_color = Color("171c30")
		_biome.sky_horizon_color = Color("67504e")
		_biome.sun_color = Color("ffd5a0")
		_biome.sun_energy = 0.65
		_biome.sun_pitch = 58.0
		_biome.sun_yaw = -35.0
		_biome.ambient_energy = 0.62
		_biome.fog_color = Color("363c4a")
		_biome.fog_density = 0.0015
		_biome.volumetric_fog_density = 0.004
		_biome.fog_of_war_enabled = false
		_biome.torch_energy = 0.25
		_biome.particle_color = Color(1.0, 0.8, 0.5, 0.15)
		_biome.particle_velocity = Vector3(0.03, 0.12, 0)
	return _biome


func _ready() -> void:
	_add_terrain(ChambersGenerator.new(),
			AABB(Vector3(-64, -8, -64), Vector3(128, 32, 128)))
	var decor := DRESSING.new()
	decor.name = "CathedralAndChurchyard"
	add_child(decor)
	decor.build(self)
	var portal := _add_portal(RETURN_PORTAL, Vector3.FORWARD, "hall",
			Color(0.55, 0.3, 0.8), Color(0.95, 0.65, 0.3))
	portal.name = "ReturnToTavern"
	for child in portal.get_children():
		if child is OmniLight3D:
			child.distance_fade_enabled = true
			child.distance_fade_begin = 45.0
			child.distance_fade_length = 15.0
	# Ten nave pools, two chapel pools, two altar pools and four yard lanterns.
	# The portal supplies the nineteenth light. Candles themselves are batched.
	for side in [-1.0, 1.0]:
		for z in [15.0, 7.0, -1.0, -9.0, -18.0]:
			_add_light(Vector3(side * 7.6, 4.3, z), Color("ffc884"), 1.5, 10.5)
		_add_light(Vector3(side * 20.0, 3.5, -9.0), Color("ffce91"), 1.7, 9.0)
		_add_light(Vector3(side * 3.0, 3.0, -26.0), Color("ffbc76"), 1.7, 9.0)
		for z in [29.0, -35.0]:
			_add_light(Vector3(side * 6.0, 3.2, z), Color("ffca7d"), 1.0, 8.0)


func is_walkable(pos: Vector3) -> bool:
	for dx in [-0.35, 0.35]:
		for dz in [-0.35, 0.35]:
			if not inside_floor(pos.x + dx, pos.z + dz):
				return false
	for solid in _solids:
		if pos.x > solid.position.x - 0.25 and pos.x < solid.end.x + 0.25 \
				and pos.z > solid.position.z - 0.25 and pos.z < solid.end.z + 0.25:
			return false
	return true


func ground_height(_x: float, _z: float) -> float:
	return 0.0


func map_color(x: int, z: int) -> Color:
	var px := x + 0.5
	var pz := z + 0.5
	if inside_floor(px, pz):
		for solid in _solids:
			if px >= solid.position.x and px < solid.end.x and pz >= solid.position.z and pz < solid.end.z:
				return Color("746452")
		return Blocks.map_color(ChambersGenerator.floor_block(x, z))
	if ChambersGenerator.wall_at(x, z):
		return Color("a59b89")
	if maxi(absi(x), absi(z)) >= YARD_EXTENT:
		return Color("242c2b")
	return Blocks.map_color(ChambersGenerator.yard_block(x, z)).darkened(0.23)


func region_at(pos: Vector3) -> String:
	if pos.z < NORTH:
		return "The Candlelit Apse"
	if absf(pos.x) > HALF_WIDTH:
		return "The Reliquary Chapels"
	return "Your Chambers"


## Roofless stone shell. Fine furniture, glass and yard props are batched
## separately, keeping the terrain generator independent of scene resources.
class ChambersGenerator:
	extends VoxelGeneratorScript

	func _get_used_channels_mask() -> int:
		return 1 << VoxelBuffer.CHANNEL_TYPE

	static func wall_at(x: int, z: int) -> bool:
		var px := x + 0.5
		var pz := z + 0.5
		if ChambersWorld.inside_floor(px, pz):
			return false
		return ChambersWorld.inside_floor(px - 1, pz) or ChambersWorld.inside_floor(px + 1, pz) \
				or ChambersWorld.inside_floor(px, pz - 1) or ChambersWorld.inside_floor(px, pz + 1) \
				or ChambersWorld.inside_floor(px - 1, pz - 1) or ChambersWorld.inside_floor(px + 1, pz + 1) \
				or ChambersWorld.inside_floor(px - 1, pz + 1) or ChambersWorld.inside_floor(px + 1, pz - 1)

	static func floor_block(x: int, z: int) -> int:
		var ax := absf(x + 0.5)
		if ax < 3.0 and z >= -26:
			return Blocks.CARPET_RED if ax < 2.0 else Blocks.CARPET_GOLD
		if z >= -9 and z <= -8:
			return Blocks.CARPET_GOLD if z == -9 else Blocks.CARPET_RED
		if z < -24:
			return Blocks.CASTLE_MARBLE if posmod(x + z, 4) != 0 else Blocks.CARPET_GOLD
		if ax > 9.0:
			return Blocks.HALL_TRIM if posmod(z + 22, 5) == 0 else Blocks.HALL_FLOOR
		return Blocks.CASTLE_MARBLE if posmod(floori(x / 2.0) + floori(z / 2.0), 2) == 0 else Blocks.HALL_FLOOR

	static func yard_block(x: int, z: int) -> int:
		var edge := maxi(absi(x), absi(z))
		var noise := posmod(x * 73 + z * 137 + x * z * 19, 101)
		var road := (absi(x) <= 2 and (z > SOUTH or z < APSE_NORTH)) \
				or (absi(z + 9) <= 2 and absi(x) > CHAPEL_WIDTH) \
				or (absi(x) >= 29 and absi(x) <= 31 and absi(z) < 38) \
				or (absi(z) >= 36 and absi(z) <= 38 and absi(x) < 32)
		if road and noise > maxi(0, edge - 43) * 7:
			return Blocks.GRAVEL if noise > 25 else Blocks.DIRT
		return Blocks.CAVE_MOSS if noise > 22 else Blocks.CAVE_DIRT

	func _generate_block(buf: VoxelBuffer, origin: Vector3i, lod: int) -> void:
		if lod != 0:
			return
		var size := buf.get_size()
		for lz in size.z:
			for lx in size.x:
				var x := origin.x + lx
				var z := origin.z + lz
				_column(buf, origin, lx, lz, -8, -1, Blocks.STONE)
				var inside := ChambersWorld.inside_floor(x + 0.5, z + 0.5)
				_column(buf, origin, lx, lz, -1, 0, floor_block(x, z) if inside else yard_block(x, z))
				if wall_at(x, z):
					_column(buf, origin, lx, lz, 0, WALL_HEIGHT, Blocks.HALL_WALL)
					_column(buf, origin, lx, lz, 0, 1, Blocks.HALL_TRIM)
					_column(buf, origin, lx, lz, WALL_HEIGHT, WALL_HEIGHT + 1, Blocks.CASTLE_MARBLE)
					# Narrow pointed window openings, filled with colored glass by dressing.
					var window := window_offset(x, z)
					if window >= 0:
						_column(buf, origin, lx, lz, 2, 5 if window == 0 else 4, Blocks.AIR)
					# A closed oak entrance, with a stone arch and brass bosses.
					if z == SOUTH and absi(x) <= 2:
						_column(buf, origin, lx, lz, 0, 5 if absi(x) < 2 else 4, Blocks.TIMBER)
						_column(buf, origin, lx, lz, 2, 3, Blocks.BRASS)
				# Low foundation buttresses articulate the exterior without a roof.
				if (x == -18 or x == 17) and z > NORTH and z < SOUTH and posmod(z - 2, 8) <= 1 \
						and not ChambersWorld.inside_floor(x + 0.5, z + 0.5):
					_column(buf, origin, lx, lz, 0, 3, Blocks.HALL_TRIM)

	## Offset from a window's center block, or -1 outside the opening.
	static func window_offset(x: int, z: int) -> int:
		if (x == -17 or x == 16) and (z > -2 or z < CHAPEL_NORTH):
			for center in [16, 8, 0, -20]:
				if absi(z - center) <= 1:
					return absi(z - center)
		if x == -25 or x == 24:
			if absi(z + 10) <= 1:
				return absi(z + 10)
		if z == -31 and absi(x) <= 2:
			return 0 if absi(x) <= 1 else 1
		if z == SOUTH and (absi(x - 11) <= 1 or absi(x + 12) <= 1):
			return mini(absi(x - 11), absi(x + 12))
		return -1

	func _column(buf: VoxelBuffer, origin: Vector3i, lx: int, lz: int, y0: int, y1: int, value: int) -> void:
		var sy := buf.get_size().y
		var a := clampi(y0 - origin.y, 0, sy)
		var b := clampi(y1 - origin.y, 0, sy)
		if a < b:
			buf.fill_area(value, Vector3i(lx, a, lz), Vector3i(lx + 1, b, lz + 1), VoxelBuffer.CHANNEL_TYPE)
