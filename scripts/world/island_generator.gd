class_name IslandGenerator
extends VoxelGeneratorScript
## Seeded island: central woodland capital, forest belt and lake, then five
## outer compass regions with mandatory villages, strongholds and routed roads.
## Plans are immutable once built; worker threads only read terrain columns.

const SEA_LEVEL := 8  # blocks at or below this are under water
const RADIUS := 640.0  # island radius in blocks
const MAX_HEIGHT := SEA_LEVEL + 70
const DEEP_DARK_RADIUS := 0.15  # as a fraction of RADIUS
const MOUNTAIN_HEIGHT := 58.0
const BEACH_START := 0.92  # as a fraction of RADIUS
const CENTER_START := 0.55
const OBSTACLE_CELL := 5
const DECOR_CELL := 2
const ROAD_POINT_SPACING := 4.0  # blocks between road path points
const ROAD_PIECE_POINTS := 6  # points per road feature piece (keeps bounds small)
const PACK_CELL := 36  # enemy pack sites: at most one per cell
const PACK_KEEP_CLEAR := 26.0  # no packs this close to where players arrive
const TOWN_PACK_MARGIN := 14.0
const MAIN_ROAD_WIDTH := 1.7  # paved half width of the stronghold spokes
const BRANCH_ROAD_WIDTH := 1.2
const LAMP_SPACING := 24.0  # blocks between lampposts along a road
const LAMP_SETBACK := [3.9, 4.6, 5.4]  # tried distances from the road's center line
const LAMP_CLEARANCE := 2.5  # obstacles keep this far from lampposts
const FEATURE_CELL_SHIFT := 4  # features are indexed in 16 x 16 block cells
const FEATURE_GAP := 8.0  # minimum blocks between two features
## The safe woodland heart reaches this far (share of RADIUS).
const WOODS_RADIUS := 0.47
const INNER_MAP_RADIUS := 400.0  # preserve the authored towns and forest belt
## Strongholds whose main road runs up to their gate (index into the five
## compass regions: 0 Doom, 1 Fosen, 2 Bluelay, 3 Desert, 4 Deep Dark).
const APPROACH_ROADS := [0, 1, 3]
## Where an approach road ends, before its straight run to the gate.
const APPROACH_DISTANCE := 92.0

var realm_seed := 0
var _coast := FastNoiseLite.new()
var _climate := FastNoiseLite.new()
var _sectors := FastNoiseLite.new()
var _hills := FastNoiseLite.new()
var _ridges := FastNoiseLite.new()
var _patches := FastNoiseLite.new()
var _sector_rotation := 0.0
var _mountain_center := Vector2.ZERO
var _mountain_radius := RADIUS * 0.20
var _biomes: Array[BiomeDef] = []
## Every planned feature (regions, structures and road pieces).
var features: Array[RealmFeature] = []
## Each road as a list of points (for lampposts).
var roads: Array[PackedVector2Array] = []
var _feature_grid := {}  # Vector2i cell -> Array[RealmFeature]
var villages: Array[VillageFeature] = []
var strongholds: Array[StrongholdFeature] = []
## Stronghold index -> the outpost its road passes through (Fosen and desert).
var _spoke_towns := {}
## Per stronghold index: where its biome's spoke ends (the outpost center if it has one).
var _spoke_ends: Array[Vector2] = []
## Pairs of spoke indices whose ends are joined by a road across a biome border.
var _links: Array[Vector2i] = []
const FORT_ROAD_CLEARANCE := 34.0  # roads stay this far beyond a stronghold's edge
var _road_grid: AStarGrid2D
var _lamps: Array[Dictionary] = []
var _lamp_grid := {}  # Vector2i (8 x 8 block cell) -> Array[Vector3], to keep obstacles away


## layout: a static realm (RealmLayout.data(): villages, strongholds, landmarks
## and roads placed by hand in res://realm/realm_layout.tscn). Empty = the
## procedural plan from the seed (kept for generated places like future portals).
func _init(p_seed: int, layout := {}) -> void:
	realm_seed = p_seed
	var noises := [_coast, _climate, _sectors, _hills, _ridges, _patches]
	var freqs := [0.012, 0.007, 0.01, 0.025, 0.06, 0.05]
	for i in noises.size():
		noises[i].seed = p_seed + i * 101
		noises[i].frequency = freqs[i]
	_ridges.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	_sector_rotation = _hash(0, 0, 1) * TAU
	# Fosen is sector 1, centered on angle -PI/4 - rotation (see _biome); its mountain sits there.
	var mountain_angle := -PI + 1.5 * TAU / 5.0 - _sector_rotation
	_mountain_center = Vector2(cos(mountain_angle), sin(mountain_angle)) * RADIUS * 0.82
	for id in Biomes.COUNT:
		_biomes.append(Biomes.get_biome(id))
	if layout.is_empty():
		_plan_civilization()
		_plan_features()
		_plan_roads()
	else:
		_plan_from_layout(layout)
	_plan_lamps()


func _get_used_channels_mask() -> int:
	return 1 << VoxelBuffer.CHANNEL_TYPE


## Returns Vector2i(height of the top block, biome id) for a column,
## including features.
func column(x: int, z: int) -> Vector2i:
	var base := _base_column(x, z)
	var fs: Variant = _feature_grid.get(Vector2i(x >> FEATURE_CELL_SHIFT, z >> FEATURE_CELL_SHIFT))
	if fs == null:
		return base
	var col := [base.x, -1, -1]
	for f: RealmFeature in fs:
		f.shape(x, z, col)
	return Vector2i(col[0], base.y)


## The block on top of a column (after features), e.g. to keep players off lava.
func surface_block(x: int, z: int) -> int:
	var col := _detail(x, z)
	return col[2]


## Height and block of whatever is highest in a column (walls and pillars
## included), as Vector2i(height, block id). For the minimap.
func top_of(x: int, z: int) -> Vector2i:
	if not _feature_grid.has(Vector2i(x >> FEATURE_CELL_SHIFT, z >> FEATURE_CELL_SHIFT)):
		var base := _base_column(x, z)
		return Vector2i(base.x, _top_block(x, z, base.x, _biomes[base.y]))
	var d := _detail(x, z)
	var h: int = d[0]
	var block: int = d[2]
	for i in range(4, d.size(), 3):
		if d[i + 1] - 1 >= h:
			h = d[i + 1] - 1
			block = d[i + 2]
	return Vector2i(h, block)


## The feature covering this column, or null. Structures and regions win
## over roads running through them.
func feature_at(x: int, z: int) -> RealmFeature:
	var fs: Variant = _feature_grid.get(Vector2i(x >> FEATURE_CELL_SHIFT, z >> FEATURE_CELL_SHIFT))
	var road: RealmFeature = null
	if fs != null:
		for f: RealmFeature in fs:
			if f.covers(x, z):
				if f.type != "road":
					return f
				road = f
	return road


## Terrain without features.
func _base_column(x: int, z: int) -> Vector2i:
	var p := Vector2(x, z)
	var d := p.length() / RADIUS + _coast.get_noise_2d(x, z) * 0.1
	if d > 1.0:
		return Vector2i(maxi(2, SEA_LEVEL - 1 - int((d - 1.0) * 40.0)), Biomes.OCEAN)
	if d > BEACH_START:
		return Vector2i(SEA_LEVEL if d > 0.97 else SEA_LEVEL + 1, Biomes.BEACH)

	var biome := _biome(x, z, d)
	var h := SEA_LEVEL + 2
	var hill := _hills.get_noise_2d(x, z)
	if hill > 0.35:
		h += int((hill - 0.35) * 9.0)  # occasional low rises, mostly flat
	if biome == Biomes.FOSEN:
		var m := 1.0 - p.distance_to(_mountain_center) / _mountain_radius
		if m > 0.0:
			h += int(pow(m, 1.4) * MOUNTAIN_HEIGHT + _ridges.get_noise_2d(x, z) * 6.0 * m)
	elif biome == Biomes.DEEP_DESERT:
		# Long rolling dunes, at most one block per step so they stay walkable.
		var dune := sin(x * 0.11 + z * 0.04 + _climate.get_noise_2d(x, z) * 6.0) * 0.5 + 0.5
		h += int(dune * 3.5)
	elif biome == Biomes.DEEP_DARK:
		h = SEA_LEVEL + 1 + (1 if hill > 0.5 else 0)  # a low, sunken basin
	return Vector2i(h, biome)


func _biome(x: int, z: int, d: float) -> int:
	# A safe woodland heart gives way to five seeded compass regions.
	var inner_d := Vector2(x,z).length()/INNER_MAP_RADIUS + _coast.get_noise_2d(x,z)*.1
	if inner_d < WOODS_RADIUS + _sectors.get_noise_2d(x + 500, z) * 0.025:
		return Biomes.WOODS
	var a := atan2(float(z), float(x)) + _sectors.get_noise_2d(x, z) * 0.12 + _sector_rotation
	var sector := posmod(floori((a + PI) / (TAU / 5.0)), 5)
	var id: int = [Biomes.DOOM, Biomes.FOSEN, Biomes.BLUELAY, Biomes.DESERT, Biomes.DEEP_DARK][sector]
	if id == Biomes.DESERT and d > 0.88:
		return Biomes.DEEP_DESERT
	if inner_d < WOODS_RADIUS + 0.09 and id == Biomes.BLUELAY and _climate.get_noise_2d(x, z) > 0.0:
		return Biomes.JUNGLE
	return id


func _generate_block(out_buffer: VoxelBuffer, origin: Vector3i, lod: int) -> void:
	if lod != 0 or origin.y > MAX_HEIGHT:
		return
	var size := out_buffer.get_size()
	if origin.y + size.y <= 2:
		out_buffer.fill(Blocks.STONE, VoxelBuffer.CHANNEL_TYPE)
		return
	for lz in size.z:
		for lx in size.x:
			var x := origin.x + lx
			var z := origin.z + lz
			var cell := Vector2i(x >> FEATURE_CELL_SHIFT, z >> FEATURE_CELL_SHIFT)
			if not _feature_grid.has(cell):
				# Fast path: plain terrain.
				var col := _base_column(x, z)
				var h := col.x
				var biome := _biomes[col.y]
				_fill(out_buffer, origin, lx, lz, -1000, h - 3, biome.stone_block)
				_fill(out_buffer, origin, lx, lz, h - 3, h, biome.under_block)
				_fill(out_buffer, origin, lx, lz, h, h + 1, _top_block(x, z, h, biome))
				continue
			var d := _detail(x, z)
			var h: int = d[0]
			_fill(out_buffer, origin, lx, lz, -1000, h - 3, _biomes[d[1]].stone_block)
			_fill(out_buffer, origin, lx, lz, h - 3, h, d[3])
			_fill(out_buffer, origin, lx, lz, h, h + 1, d[2])
			for i in range(4, d.size(), 3):
				_fill(out_buffer, origin, lx, lz, d[i], d[i + 1], d[i + 2])


## Full column with features applied:
## [height, biome id, top block, under block, then segments y0, y1, block...].
func _detail(x: int, z: int) -> Array:
	var base := _base_column(x, z)
	var biome := _biomes[base.y]
	var col := [base.x, -1, -1]
	var fs: Variant = _feature_grid.get(Vector2i(x >> FEATURE_CELL_SHIFT, z >> FEATURE_CELL_SHIFT))
	if fs != null:
		for f: RealmFeature in fs:
			f.shape(x, z, col)
	var top: int = col[1] if col[1] >= 0 else _top_block(x, z, col[0], biome)
	var under: int = col[2] if col[2] >= 0 else biome.under_block
	var out := [col[0], base.y, top, under]
	out.append_array(col.slice(3))
	return out


func _top_block(x: int, z: int, h: int, biome: BiomeDef) -> int:
	if biome.id == Biomes.FOSEN and (h > SEA_LEVEL + 14 or _patches.get_noise_2d(x, z) > 0.15):
		return Blocks.SNOW
	if biome.glow_chance > 0.0 and _hash(x, z, 7) < biome.glow_chance:
		return biome.glow_block
	return biome.top_block


## Fills world-space y range [y0, y1) of one column, clipped to the buffer.
func _fill(buf: VoxelBuffer, origin: Vector3i, lx: int, lz: int, y0: int, y1: int, value: int) -> void:
	var sy := buf.get_size().y
	var a := clampi(y0 - origin.y, 0, sy)
	var b := clampi(y1 - origin.y, 0, sy)
	if a < b:
		buf.fill_area(value, Vector3i(lx, a, lz), Vector3i(lx + 1, b, lz + 1), VoxelBuffer.CHANNEL_TYPE)


## Arrival in the central village plaza. The second value points toward its portal.
func find_spawn() -> Array:
	return [surface(Vector2(0.5, 0.5)), Vector2(0, 1)]


## Standing position on top of the column at p (x/z).
func surface(p: Vector2) -> Vector3:
	var x := floori(p.x)
	var z := floori(p.y)
	return Vector3(x + 0.5, column(x, z).x + 1, z + 0.5)


## Seeded obstacle placements inside `area` (x/z blocks): [{id, prefab,
## biome, pos, yaw}]. Skips sloped ground, water, features, lampposts and
## anything within keep_clear_radius of the given points.
func obstacle_sites(area: Rect2i, keep_clear: Array[Vector3], keep_clear_radius: float) -> Array[Dictionary]:
	var sites: Array[Dictionary] = []
	for cz in range(ceili(float(area.position.y) / OBSTACLE_CELL), ceili(float(area.end.y) / OBSTACLE_CELL)):
		for cx in range(ceili(float(area.position.x) / OBSTACLE_CELL), ceili(float(area.end.x) / OBSTACLE_CELL)):
			var x := cx * OBSTACLE_CELL + 1 + int(_hash(cx, cz, 21) * (OBSTACLE_CELL - 2))
			var z := cz * OBSTACLE_CELL + 1 + int(_hash(cx, cz, 22) * (OBSTACLE_CELL - 2))
			var col := column(x, z)
			var biome := _biomes[col.y]
			if col.x < SEA_LEVEL or _hash(cx, cz, 23) >= biome.obstacle_density:
				continue
			var prefab_name := _pick(biome.obstacles, _hash(cx, cz, 24))
			var prefab := ObstacleLibrary.get_prefab(prefab_name)
			if not _is_flat(x, z, col.x, ceili(maxf(prefab.footprint.x, prefab.footprint.y) * 0.5)):
				continue
			if _near_feature(x, z, ceili(maxf(prefab.footprint.x, prefab.footprint.y) * 0.5) + 1):
				continue
			var pos := Vector3(x + 0.5, col.x + 1, z + 0.5)
			if _near_lamp(pos, maxf(prefab.footprint.x, prefab.footprint.y) * 0.5 + LAMP_CLEARANCE):
				continue
			var blocked := false
			for p in keep_clear:
				blocked = blocked or Vector2(p.x - pos.x, p.z - pos.z).length() < keep_clear_radius
			if blocked:
				continue
			sites.append({
				id = "%d_%d" % [cx, cz], prefab = prefab_name, biome = col.y, pos = pos,
				yaw = floori(_hash(cx, cz, 25) * 4.0) * PI * 0.5,
			})
	return sites


func _near_feature(x: int, z: int, margin: int) -> bool:
	for offset in [Vector2i.ZERO, Vector2i(-margin, -margin), Vector2i(margin, -margin),
			Vector2i(-margin, margin), Vector2i(margin, margin)]:
		if feature_at(x + offset.x, z + offset.y) != null:
			return true
	return false


# --- Feature planning (main thread, once) ------------------------------------------

func _plan_features() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = realm_seed * 7 + 13
	for biome in _biomes:
		for spec in biome.features:
			var required: int = spec.get("required", 0)
			var count := required
			for i in spec.get("optional", 0):
				if rng.randf() < spec.get("chance", 0.5):
					count += 1
			for i in count:
				_place_feature(spec.type, biome.id, i < required, rng, spec.get("packs", []))


func _place_feature(type: String, biome_id: int, required: bool, rng: RandomNumberGenerator,
		packs: Array = []) -> void:
	# Required features get a second, looser pass so they always appear.
	for strict in ([true, false] if required else [true]):
		if _try_place_feature(type, biome_id, required, rng, strict):
			features[-1].packs = packs
			return
	if required:
		push_warning("Could not place required feature '%s'" % type)


func _try_place_feature(type: String, biome_id: int, required: bool, rng: RandomNumberGenerator,
		strict: bool) -> bool:
	for attempt in (3000 if required else 300):
		var c := Vector2i(rng.randi_range(-int(RADIUS), int(RADIUS)), rng.randi_range(-int(RADIUS), int(RADIUS)))
		var base := _base_column(c.x, c.y)
		if base.y != biome_id:
			continue
		if type == "ravine" and base.x < SEA_LEVEL + 12:
			continue  # ravines cut into the mountain's flanks
		var f := RealmFeature.create(type, c, required, base.x, rng, _biomes[biome_id])
		if _fits(f, biome_id, strict):
			_add_feature(f)
			return true
	return false


## Registers a feature in the lookup grid. Roads go first in each cell so
## structures built on top of them win.
func _add_feature(f: RealmFeature) -> void:
	features.append(f)
	for cz in range(f.bounds.position.y >> FEATURE_CELL_SHIFT, (f.bounds.end.y >> FEATURE_CELL_SHIFT) + 1):
		for cx in range(f.bounds.position.x >> FEATURE_CELL_SHIFT, (f.bounds.end.x >> FEATURE_CELL_SHIFT) + 1):
			var key := Vector2i(cx, cz)
			if not _feature_grid.has(key):
				_feature_grid[key] = []
			if f.type == "road":
				_feature_grid[key].push_front(f)
			else:
				_feature_grid[key].append(f)


## Main roads: one spoke from the capital into every outer biome. A spoke runs
## to its outpost, or stops a short way past the woodland edge. Some spoke ends
## are joined across a biome border to their neighbour's (never the Deep Dark's).
## Roads keep well away from the boss strongholds: those are found, not followed.
func _plan_roads() -> void:
	_build_road_grid()
	var rng := RandomNumberGenerator.new()
	rng.seed = realm_seed * 31 + 7
	var hub := villages[0]
	for index in strongholds.size():
		var waypoint := _town_exit(hub, Vector2(strongholds[index].center), true)
		if _spoke_towns.has(index):
			var village: VillageFeature = _spoke_towns[index]
			_route_road(waypoint, _town_exit(village, Vector2(hub.center), true), rng, MAIN_ROAD_WIDTH)
		else:
			_route_road(waypoint, _spoke_ends[index], rng, MAIN_ROAD_WIDTH)
	for pair in _links:
		var a := _link_point(pair.x, _spoke_ends[pair.y])
		var b := _link_point(pair.y, _spoke_ends[pair.x])
		_route_road(a, b, rng, BRANCH_ROAD_WIDTH)
	for index: int in APPROACH_ROADS:
		var fort := strongholds[index]
		var approach := Vector2(fort.center) + _gate_direction(fort) * APPROACH_DISTANCE
		_route_road(_link_point(index, approach), approach, rng, MAIN_ROAD_WIDTH)
		_approach(fort)
	for village in villages.slice(1):
		if village in _spoke_towns.values():
			continue
		var arrive := _town_exit(village, Vector2(hub.center), true)
		var leave := _town_exit(hub, Vector2(village.center), true)
		if leave == Vector2.INF:
			# No street of its own: branch off the nearest point of a spoke.
			leave = _nearest_road_point(arrive)
		_route_road(leave, arrive, rng, BRANCH_ROAD_WIDTH)
	_road_grid = null


## Where a spoke can be joined: its outpost's street toward `toward`, or its end.
func _link_point(index: int, toward: Vector2) -> Vector2:
	if _spoke_towns.has(index):
		return _town_exit(_spoke_towns[index], toward, true)
	return _spoke_ends[index]


func _exit_index(village: VillageFeature, angle: float) -> int:
	for i in village.exits.size():
		if absf(angle_difference(village.exits[i], angle)) < 0.3:
			return i
	return -1


## Just outside the town edge on the street facing `toward`. Adds the short
## connector from the street's end; INF if the town has no such street.
func _town_exit(village: VillageFeature, toward: Vector2, connect: bool) -> Vector2:
	var i := _exit_index(village, (toward - Vector2(village.center)).angle())
	if i < 0:
		return Vector2.INF
	var dir := Vector2.from_angle(village.exits[i])
	var c := Vector2(village.center) + Vector2(0.5, 0.5)
	var outside := c + dir * (village.radius + 7.0)
	if connect and not village.has_meta("exit_%d" % i):
		village.set_meta("exit_%d" % i, true)
		var rng := RandomNumberGenerator.new()
		rng.seed = realm_seed + i
		_add_road(c + dir * (village.radius - 3.0), outside, rng, MAIN_ROAD_WIDTH)
	return outside


func _nearest_road_point(p: Vector2) -> Vector2:
	var best := Vector2.INF
	for road in roads:
		for q in road:
			if q.length() > villages[0].radius + 10.0 and q.distance_to(p) < best.distance_to(p):
				best = q
	return best if best != Vector2.INF else Vector2.ZERO


func _build_road_grid() -> void:
	_road_grid = AStarGrid2D.new()
	_road_grid.region = Rect2i(-100, -100, 201, 201)
	_road_grid.cell_size = Vector2(4, 4)
	_road_grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_road_grid.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	_road_grid.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	_road_grid.update()
	for z in range(-100, 101):
		for x in range(-100, 101):
			var id := Vector2i(x, z)
			var blocked := false
			for offset in [Vector2i.ZERO, Vector2i(-3, -3), Vector2i(3, -3), Vector2i(-3, 3), Vector2i(3, 3)]:
				var p: Vector2i = id * 4 + offset
				var feature := feature_at(p.x, p.y)
				if _base_column(p.x, p.y).x < SEA_LEVEL + 1 or (feature != null and feature.type != "road") \
						or Blocks.is_hazard(surface_block(p.x, p.y)):
					blocked = true
					break
			for fort in strongholds:
				blocked = blocked or Vector2(id * 4).distance_to(Vector2(fort.center)) < fort.radius + FORT_ROAD_CLEARANCE
			_road_grid.set_point_solid(id, blocked)
			if not blocked:
				# Prefer level ground: steep cells (the Fosen mountain) cost more.
				var h := _base_column(x * 4, z * 4).x
				var slope := absi(h - _base_column(x * 4 + 4, z * 4).x) + absi(h - _base_column(x * 4, z * 4 + 4).x)
				_road_grid.set_point_weight_scale(id, 1.0 + slope * 0.9 + _hash(x, z, 95) * 0.4)


func _road_node(p: Vector2) -> Vector2i:
	var at := Vector2i((p / 4.0).round())
	for r in range(0, 14):
		for z in range(-r, r + 1):
			for x in range(-r, r + 1):
				var id := at + Vector2i(x, z)
				if _road_grid.is_in_boundsv(id) and not _road_grid.is_point_solid(id):
					return id
	return at


func _route_road(from: Vector2, to: Vector2, rng: RandomNumberGenerator, width: float) -> void:
	var ids := _road_grid.get_id_path(_road_node(from), _road_node(to))
	if ids.is_empty():
		push_error("No road route between %s and %s" % [from, to])
		return
	# Pull the grid staircase into long straight runs, then let it wander a
	# little and round every corner, keeping each change clear of obstacles.
	var kept: Array[Vector2i] = [ids[0]]
	var i := 0
	while i < ids.size() - 1:
		var j := mini(i + 10, ids.size() - 1)
		while j > i + 1 and not _clear_line(ids[i], ids[j]):
			j -= 1
		kept.append(ids[j])
		i = j
	var rough := PackedVector2Array([from])
	for k in kept.size():
		var p := Vector2(kept[k]) * 4.0
		if k > 0 and k < kept.size() - 1:
			var wander := Vector2(_hash(kept[k].x, kept[k].y, 96) - 0.5, _hash(kept[k].x, kept[k].y, 97) - 0.5) * 5.0
			if _clear_point(p + wander):
				p += wander
		rough.append(p)
	rough.append(to)
	var smooth := rough
	for pass_index in 3:
		smooth = _chaikin(smooth)
	var resampled := _resample(smooth, ROAD_POINT_SPACING)
	for p in resampled:
		if not _clear_point(p):
			resampled = _resample(rough, ROAD_POINT_SPACING)
			break
	_store_road(resampled, rng, width)


func _clear_point(p: Vector2) -> bool:
	var id := Vector2i((p / 4.0).round())
	return _road_grid.is_in_boundsv(id) and not _road_grid.is_point_solid(id)


func _clear_line(a: Vector2i, b: Vector2i) -> bool:
	var steps := maxi(1, ceili(Vector2(a).distance_to(Vector2(b)) * 3.0))
	for n in steps + 1:
		if not _clear_point(Vector2(a).lerp(Vector2(b), float(n) / steps) * 4.0):
			return false
	return true


static func _chaikin(points: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array([points[0]])
	for i in points.size() - 1:
		out.append(points[i].lerp(points[i + 1], 0.25))
		out.append(points[i].lerp(points[i + 1], 0.75))
	out.append(points[-1])
	return out


static func _resample(points: PackedVector2Array, spacing: float) -> PackedVector2Array:
	var out := PackedVector2Array([points[0]])
	var carry := 0.0
	for i in points.size() - 1:
		var a := points[i]
		var b := points[i + 1]
		var length := a.distance_to(b)
		var t := spacing - carry
		while t < length:
			out.append(a.lerp(b, t / length))
			t += spacing
		carry = length - (t - spacing)
	if out[-1].distance_to(points[-1]) > 0.5:
		out.append(points[-1])
	return out


func _store_road(points: PackedVector2Array, rng: RandomNumberGenerator, width := BRANCH_ROAD_WIDTH) -> void:
	var clean := PackedVector2Array()
	for p in points:
		if clean.is_empty() or p.distance_to(clean[-1]) > 0.01:
			clean.append(p)
	if clean.size() < 2:
		return
	var heights := PackedFloat32Array()
	var paving := PackedInt32Array()
	for p in clean:
		var col := column(floori(p.x), floori(p.y))
		heights.append(col.x)
		paving.append(col.y)
	# Grade the route so every terrain voxel step stays climbable.
	for pass_index in 3:
		for i in range(1, heights.size()):
			var grade := clean[i].distance_to(clean[i - 1]) * 0.32
			heights[i] = clampf(heights[i], heights[i - 1] - grade, heights[i - 1] + grade)
		for i in range(heights.size() - 2, -1, -1):
			var grade := clean[i].distance_to(clean[i + 1]) * 0.32
			heights[i] = clampf(heights[i], heights[i + 1] - grade, heights[i + 1] + grade)
	roads.append(clean)
	var start := 0
	while start < clean.size() - 1:
		var end := mini(start + ROAD_PIECE_POINTS, clean.size())
		var feature := RealmFeature.create_road(clean.slice(start, end), rng.randi(), width)
		feature.road_heights = heights.slice(start, end)
		feature.road_biomes = paving.slice(start, end)
		_add_feature(feature)
		start += ROAD_PIECE_POINTS - 1


func _add_road(from: Vector2, to: Vector2, rng: RandomNumberGenerator, width := BRANCH_ROAD_WIDTH) -> void:
	var steps := maxi(2, ceili(from.distance_to(to) / ROAD_POINT_SPACING))
	var points := PackedVector2Array()
	for i in steps + 1:
		points.append(from.lerp(to, float(i) / steps))
	_store_road(points, rng, width)


## Lamppost spots beside the roads: [{pos, yaw}]. Each stands just off the
## road on flat, open ground (never on the road, in a structure, water or
## lava) with its lantern arm turned to hang over the road.
func lamp_sites() -> Array[Dictionary]:
	return _lamps


func _plan_lamps() -> void:
	for points in roads:
		var walked := LAMP_SPACING * 0.5
		var flip := 1.0
		for i in points.size() - 1:
			var seg := points[i + 1] - points[i]
			walked += seg.length()
			if walked < LAMP_SPACING:
				continue
			flip = -flip
			for setback: float in LAMP_SETBACK:
				var p := points[i] + seg.normalized().orthogonal() * setback * flip
				var x := floori(p.x)
				var z := floori(p.y)
				if not _lamp_spot_ok(x, z):
					continue
				var pos := Vector3(x + 0.5, column(x, z).x + 1, z + 0.5)
				var to_road := points[i] - Vector2(pos.x, pos.z)
				# The lantern arm points along the prefab's +x; turn +x toward the road.
				_lamps.append({pos = pos, yaw = atan2(-to_road.y, to_road.x)})
				var cell := Vector2i(x >> 3, z >> 3)
				if not _lamp_grid.has(cell):
					_lamp_grid[cell] = []
				_lamp_grid[cell].append(pos)
				walked = 0.0
				break


func _lamp_spot_ok(x: int, z: int) -> bool:
	var col := column(x, z)
	if col.x < SEA_LEVEL or not _biomes[col.y].lampposts:
		return false
	# Flat 3 x 3 block base, with nothing built there.
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			if column(x + dx, z + dz).x != col.x or feature_at(x + dx, z + dz) != null:
				return false
	return true


func _near_lamp(pos: Vector3, distance: float) -> bool:
	var c := Vector2i(floori(pos.x) >> 3, floori(pos.z) >> 3)
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			for lamp: Vector3 in _lamp_grid.get(c + Vector2i(dx, dz), []):
				if Vector2(lamp.x - pos.x, lamp.z - pos.z).length() < distance:
					return true
	return false


## Seeded enemy pack sites inside `area`: [{id, pack, pos, seed}]. Packs
## sit on dry, walkable ground away from structures and the arrival point.
func pack_sites(area: Rect2i, keep_clear: Array[Vector3]) -> Array[Dictionary]:
	var sites: Array[Dictionary] = []
	for cz in range(floori(float(area.position.y) / PACK_CELL), ceili(float(area.end.y) / PACK_CELL)):
		for cx in range(floori(float(area.position.x) / PACK_CELL), ceili(float(area.end.x) / PACK_CELL)):
			var x := cx * PACK_CELL + 4 + int(_hash(cx, cz, 41) * (PACK_CELL - 8))
			var z := cz * PACK_CELL + 4 + int(_hash(cx, cz, 42) * (PACK_CELL - 8))
			if not area.has_point(Vector2i(x, z)):
				continue  # belongs to a neighbouring chunk
			var col := column(x, z)
			var biome := _biomes[col.y]
			if biome.enemy_packs.is_empty() or col.x < SEA_LEVEL or feature_at(x, z) != null or _near_town(Vector2(x, z)):
				continue
			var weights := {}
			var density := 0.0
			for entry in biome.enemy_packs:
				weights[entry.pack] = entry.density
				density += entry.density
			if _hash(cx, cz, 43) >= density:
				continue
			var pos := Vector3(x + 0.5, col.x + 1, z + 0.5)
			var blocked := false
			for p in keep_clear:
				blocked = blocked or Vector2(p.x - pos.x, p.z - pos.z).length() < PACK_KEEP_CLEAR
			if blocked:
				continue
			sites.append({id = "pack_%d_%d" % [cx, cz], pack = _pick(weights, _hash(cx, cz, 44)), pos = pos,
					seed = int(_hash(cx, cz, 45) * 1_000_000) + realm_seed})
	sites.append_array(_feature_pack_sites(area, keep_clear))
	return sites


## Packs that live at a structure (crabs at the Tide Rocks, spirits in
## ruins, the Blue Dragon at the Crystal Spire): each feature's `packs`
## ([{pack, chance, offset}]) roll once from the realm seed; offset puts
## the pack that many blocks from the center (outside a tall structure).
func _feature_pack_sites(area: Rect2i, keep_clear: Array[Vector3]) -> Array[Dictionary]:
	var sites: Array[Dictionary] = []
	for f in features:
		if f.packs.is_empty():
			continue
		# Entries with chance 1 always come (a boss and its guards, each in
		# its own spot); the others are one weighted roll.
		var weights := {}
		var chance := 0.0
		var offsets := {}
		var always: Array = []
		for entry in f.packs:
			if entry.chance >= 1.0:
				always.append(entry)
				continue
			weights[entry.pack] = entry.chance
			chance += entry.chance
			offsets[entry.pack] = entry.get("offset", 0.0)
		var picks: Array = []
		for k in always.size():
			picks.append([always[k].pack, float(always[k].get("offset", 0.0)), k])
		if chance > 0.0 and _hash(f.center.x, f.center.y, 46) < chance:
			var pack := _pick(weights, _hash(f.center.x, f.center.y, 47))
			picks.append([pack, float(offsets[pack]), always.size()])
		for pick: Array in picks:
			var k: int = pick[2]
			var angle := _hash(f.center.x + k * 17, f.center.y, 48) * TAU
			var at: Vector2 = Vector2(f.center) + Vector2.from_angle(angle) * pick[1]
			var x := floori(at.x)
			var z := floori(at.y)
			if not area.has_point(Vector2i(x, z)):
				continue  # another chunk's
			var pos := Vector3(x + 0.5, column(x, z).x + 1, z + 0.5)
			var blocked := _near_town(Vector2(x, z))
			for p in keep_clear:
				blocked = blocked or Vector2(p.x - pos.x, p.z - pos.z).length() < PACK_KEEP_CLEAR
			if not blocked:
				sites.append({id = "feature_%d_%d%s" % [f.center.x, f.center.y, "" if k == 0 else "_%d" % k], pack = pick[0], pos = pos,
						seed = int(_hash(f.center.x + k, f.center.y, 49) * 1_000_000) + realm_seed})
	return sites


## Hostile packs keep this far beyond a town's edge, so residents live in peace.
func _near_town(p: Vector2) -> bool:
	for village in villages:
		if p.distance_to(Vector2(village.center)) < village.radius + TOWN_PACK_MARGIN:
			return true
	return false


## Small ground clutter inside `area`: {"prefab/biome id": [Transform3D, ...]},
## so each prefab-and-color combination can be drawn as one MultiMesh.
func decor_sites(area: Rect2i) -> Dictionary:
	var groups := {}
	for cz in range(ceili(float(area.position.y) / DECOR_CELL), ceili(float(area.end.y) / DECOR_CELL)):
		for cx in range(ceili(float(area.position.x) / DECOR_CELL), ceili(float(area.end.x) / DECOR_CELL)):
			var x := cx * DECOR_CELL + int(_hash(cx, cz, 31) * DECOR_CELL)
			var z := cz * DECOR_CELL + int(_hash(cx, cz, 32) * DECOR_CELL)
			var col := _base_column(x, z)
			var biome := _biomes[col.y]
			if biome.decor_density <= 0.0 or _hash(cx, cz, 33) >= biome.decor_density:
				continue
			if _feature_grid.has(Vector2i(x >> FEATURE_CELL_SHIFT, z >> FEATURE_CELL_SHIFT)) and feature_at(x, z):
				continue  # keep roads and structures clean
			var key := "%s/%d" % [_pick(biome.decor, _hash(cx, cz, 34)), col.y]
			var offset := Vector2(_hash(cx, cz, 35), _hash(cx, cz, 36)) * 0.8 + Vector2(0.1, 0.1)
			var basis := Basis(Vector3.UP, _hash(cx, cz, 37) * TAU).scaled(Vector3.ONE * (0.8 + _hash(cx, cz, 38) * 0.5))
			if not groups.has(key):
				groups[key] = []
			groups[key].append(Transform3D(basis, Vector3(x + offset.x, col.x + 1, z + offset.y)))
	return groups


## strict: the whole feature must lie in its biome (and structures on flat
## ground); otherwise only overlaps with other features are ruled out.
func _fits(f: RealmFeature, biome_id: int, strict := true) -> bool:
	for other in features:
		if Vector2(f.center).distance_to(Vector2(other.center)) < f.radius + other.radius + FEATURE_GAP:
			return false
	if not strict:
		return true
	for k in 8:
		var p := Vector2(f.center) + Vector2.from_angle(k * TAU / 8.0) * f.radius
		var col := _base_column(floori(p.x), floori(p.y))
		if col.y != biome_id:
			return false
		if f.is_structure() and absi(col.x - f.base_height) > 2:
			return false  # structures need fairly flat ground
	return true


func _is_flat(x: int, z: int, h: int, half: int) -> bool:
	for offset in [Vector2i(-half, -half), Vector2i(half, -half), Vector2i(-half, half), Vector2i(half, half)]:
		if column(x + offset.x, z + offset.y).x != h:
			return false
	return true


func _pick(weights: Dictionary, r: float) -> String:
	var total := 0.0
	for w in weights.values():
		total += w
	r *= total
	for key in weights:
		r -= weights[key]
		if r <= 0.0:
			return key
	return weights.keys()[-1]


## Deterministic 0..1 value for a coordinate pair, mixed with the realm seed.
func _hash(x: int, z: int, salt: int) -> float:
	var n := x * 374761393 + z * 668265263 + (realm_seed + salt * 1013) * 982451653
	n = (n ^ (n >> 13)) * 1274126177
	n = n ^ (n >> 16)
	return float(n & 0xFFFFFF) / float(0xFFFFFF)


## Works before streamed terrain colliders are ready. Reject structure interiors,
## wall/ceiling segments and terrain penetrating the body's footprint.
func enemy_spawn_clear(pos: Vector3, radius: float, height: float, allow_towns := false) -> bool:
	var reach := radius + 0.12
	for z in range(floori(pos.z - reach), floori(pos.z + reach) + 1):
		for x in range(floori(pos.x - reach), floori(pos.x + reach) + 1):
			var feature := feature_at(x, z)
			if feature != null and feature.is_structure() and feature.type != "stronghold" and not (allow_towns and feature is VillageFeature):
				return false
			var detail := _detail(x, z)
			if detail[0] + 1 > pos.y + 0.15 or Blocks.is_hazard(detail[2]):
				return false
			for i in range(4, detail.size(), 3):
				if detail[i] < pos.y + height + 0.15 and detail[i + 1] > pos.y + 0.10:
					return false
	return true


# --- Static realm ------------------------------------------------------------------

## Builds the realm from a static layout (see RealmLayout): the villages and
## strongholds where they were placed, landmarks, then the optional biome
## features (fixed by the seed), and finally the roads as drawn.
func _plan_from_layout(layout: Dictionary) -> void:
	for v: Dictionary in layout.get("villages", []):
		var at: Vector2i = v.at
		var town := VillageFeature.plan(at, int(v.biome), int(v.seed), _base_column(at.x, at.y).x if not v.capital else SEA_LEVEL + 2,
				bool(v.capital), Array(v.exits))
		if str(v.get("name", "")) != "" and str(v.name) != town.display_name:
			town.display_name = str(v.name)
			for r: Dictionary in town.residents:
				r.village = town.display_name
		town.map_color = v.get("color", town.map_color)
		villages.append(town)
		_add_feature(town)
	for s: Dictionary in layout.get("strongholds", []):
		var at: Vector2i = s.at
		var toward: Vector2 = Vector2(at) + Vector2.from_angle(float(s.gate_angle)) * 10.0
		var gate_sample := Vector2(at)+Vector2.from_angle(float(s.gate_angle))*StrongholdFeature.FOOTPRINT
		var floor_height := mini(_base_column(at.x,at.y).x,_base_column(roundi(gate_sample.x),roundi(gate_sample.y)).x+6)
		var fort := StrongholdFeature.plan(at, int(s.biome), floor_height, int(s.seed), toward)
		fort.set_meta(&"approach", bool(s.get("approach", false)))
		fort.set_meta(&"gate_angle", float(s.gate_angle))
		strongholds.append(fort)
		_add_feature(fort)
	var rng := RandomNumberGenerator.new()
	rng.seed = realm_seed * 67 + 3
	for l: Dictionary in layout.get("landmarks", []):
		var at: Vector2i = l.at
		_add_feature(RealmFeature.create(str(l.type), at, true, SEA_LEVEL + 2 if str(l.type) == "woodland_lake" else _base_column(at.x, at.y).x, rng))
	_plan_features()
	var road_rng := RandomNumberGenerator.new()
	road_rng.seed = realm_seed * 31 + 7
	for r: Dictionary in layout.get("roads", []):
		var points: PackedVector2Array = r.points
		if points.size() >= 2:
			_store_road(_resample(points, ROAD_POINT_SPACING), road_rng, float(r.get("width", BRANCH_ROAD_WIDTH)))
	for fort in strongholds:
		if fort.get_meta(&"approach", false):
			_approach(fort)


## The way a stronghold's gate faces: toward the island's heart (or as laid out).
func _gate_direction(fort: StrongholdFeature) -> Vector2:
	if fort.has_meta(&"gate_angle"):
		return Vector2.from_angle(fort.get_meta(&"gate_angle"))
	return -Vector2(fort.center).normalized()


## The last straight stretch of an approach road, from where it was routed to
## just outside the gate (its length follows the stronghold's size).
func _approach(fort: StrongholdFeature) -> void:
	var dir := _gate_direction(fort)
	var rng := RandomNumberGenerator.new()
	rng.seed = realm_seed + fort.center.x * 7 + fort.center.y
	var c := Vector2(fort.center) + Vector2(0.5, 0.5)
	_add_road(c + dir * APPROACH_DISTANCE, c + dir * (fort.radius + 1.0), rng, MAIN_ROAD_WIDTH)


## Whether a column is road or town street (walking there is faster).
func is_road(x: int, z: int) -> bool:
	var f := feature_at(x, z)
	if f == null:
		return false
	if f.type == "road":
		return true
	return f is VillageFeature and (f as VillageFeature).is_street(x, z)


## Mandatory plans are placed before optional ruins, hazards and roads.
## Strongholds are located first so every town can lay a street toward its roads.
func _plan_civilization() -> void:
	var biomes: Array[int] = [Biomes.DOOM, Biomes.FOSEN, Biomes.BLUELAY, Biomes.DESERT, Biomes.DEEP_DARK]
	var fort_spots: Array[Vector2i] = []
	for index in 5:
		var angle := -PI + (index + 0.5) * TAU / 5.0 - _sector_rotation
		fort_spots.append(Vector2i((Vector2.from_angle(angle) * (272 if index == 1 else 285)).round()))
	var outpost_spots := {}
	for index: int in [1, 3]:
		var angle := -PI + (index + 0.5) * TAU / 5.0 - _sector_rotation
		outpost_spots[index] = Vector2i((Vector2.from_angle(angle) * (198 if index == 1 else 205)).round())
	var road_rng := RandomNumberGenerator.new()
	road_rng.seed = realm_seed * 29 + 5
	for index in 5:
		if outpost_spots.has(index):
			_spoke_ends.append(Vector2(outpost_spots[index]))
			continue
		# Stop a little way past where the woodland gives way to this biome.
		var dir := Vector2(fort_spots[index]).normalized()
		var entry := 60.0
		while entry < 260.0 and _base_column(roundi(dir.x * entry), roundi(dir.y * entry)).y == Biomes.WOODS:
			entry += 4.0
		var reach := minf(entry + road_rng.randf_range(22.0, 42.0), Vector2(fort_spots[index]).length() - 70.0)
		_spoke_ends.append(dir * reach)
	var candidates: Array[Vector2i] = []
	for i in 5:
		var j := (i + 1) % 5
		if biomes[i] != Biomes.DEEP_DARK and biomes[j] != Biomes.DEEP_DARK:
			candidates.append(Vector2i(i, j))
	# A road network around the island: every neighbouring pair is linked.
	_links.append_array(candidates)
	var forest_angle := _sector_rotation + 0.8
	var forest_at := Vector2i((Vector2.from_angle(forest_angle) * 100).round())
	var capital_exits: Array = []
	for spot in fort_spots:
		capital_exits.append(Vector2(spot).angle())
	if capital_exits.all(func(a: float) -> bool: return absf(angle_difference(a, forest_angle)) > 0.5):
		capital_exits.append(forest_angle)
	var capital := VillageFeature.plan(Vector2i.ZERO, Biomes.WOODS, realm_seed * 41 + 1, SEA_LEVEL + 2, true, capital_exits)
	villages.append(capital)
	_add_feature(capital)
	var forest := VillageFeature.plan(forest_at, Biomes.WOODS, realm_seed * 41 + 2, SEA_LEVEL + 2, false,
			[Vector2(-forest_at).angle()])
	villages.append(forest)
	_add_feature(forest)
	for index: int in [1, 3]:
		var at: Vector2i = outpost_spots[index]
		var biome := Biomes.FOSEN if index == 1 else Biomes.DESERT
		var exits := [Vector2(-at).angle()]
		for pair in _links:
			if index in [pair.x, pair.y]:
				var other := pair.y if pair.x == index else pair.x
				exits.append((_spoke_ends[other] - Vector2(at)).angle())
		var town := VillageFeature.plan(at, biome, realm_seed * 41 + index + 10, _base_column(at.x, at.y).x, false, exits)
		villages.append(town)
		_add_feature(town)
		_spoke_towns[index] = town
	for index in 5:
		var at := fort_spots[index]
		# The gate faces back toward the heart of the island.
		var fort := StrongholdFeature.plan(at, biomes[index], _base_column(at.x, at.y).x, realm_seed * 53 + index)
		strongholds.append(fort)
		_add_feature(fort)
	var lake_angle := forest_angle + PI
	# Keep Willowmere clear of the spokes that leave the capital.
	for k in 12:
		if capital_exits.all(func(a: float) -> bool: return absf(angle_difference(a, lake_angle)) > 0.35):
			break
		lake_angle += 0.18
	var lake_at := Vector2i((Vector2.from_angle(lake_angle) * 105).round())
	var lake_rng := RandomNumberGenerator.new()
	lake_rng.seed = realm_seed * 67 + 3
	var lake := RealmFeature.create("woodland_lake", lake_at, true, SEA_LEVEL + 2, lake_rng)
	_add_feature(lake)
