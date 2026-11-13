class_name IslandGenerator
extends VoxelGeneratorScript
## The Surface: a 2048 x 2048 m world baked by tools/surface/bake_surface.py
## (SurfaceMap) and streamed as 0.25 m voxels. The terrain node is scaled by
## 1 / FINE, so this generator works in voxels while the rest of the game
## keeps meters: column(), feature_at(), surface()... still answer per meter.
##
## Baked: the land, rivers, lakes, volcanoes, towns and farms, roads, trails,
## stairs, bridges and fences. Planned here from the seed: the biome features
## (ruins, shrines, towers...), breakable obstacles, trees and enemy packs.
## Fortresses and features are built from 1 m blocks (4 x 4 x 4 voxels each).
## Plans are immutable once built; worker threads only read.

const SEA_LEVEL := 8  # meters; at or below this is under the sea
const FINE := SurfaceMap.FINE
## Half the map's width (the playable area; the map is square, not round).
const RADIUS := 1000.0
const MAX_HEIGHT := SEA_LEVEL + 112
const OBSTACLE_CELL := 7
const TREE_CELL := 3
const PACK_CELL := 36  # enemy pack sites: at most one per cell
const PACK_KEEP_CLEAR := 26.0  # no packs this close to where players arrive
const TOWN_PACK_MARGIN := 14.0
const LAMP_SPACING := 30.0  # meters between lampposts along a road
const LAMP_SETBACK := [3.6, 4.4, 5.2]  # tried distances from the road's center line
const LAMP_CLEARANCE := 2.5  # obstacles keep this far from lampposts
const FEATURE_CELL_SHIFT := 4  # features are indexed in 16 x 16 m cells
const FEATURE_GAP := 8.0  # minimum meters between two features
## Flags where nothing grows or stands in the way.
const KEEP_OPEN := SurfaceMap.ROAD | SurfaceMap.TRAIL | SurfaceMap.FIELD | SurfaceMap.CLEAR | SurfaceMap.RIVER | SurfaceMap.LAKE | SurfaceMap.BRIDGE
## Breakable obstacles and features keep off these too.
const BUSY := KEEP_OPEN | SurfaceMap.TOWN

## Ground material -> [top block, under block, under depth (voxels)]; the
## deep rock comes from the biome (_deep).
const LAYERS := {
	SurfaceMap.Mat.GRASS: [SurfaceBlocks.GRASS, SurfaceBlocks.SOIL, 3],
	SurfaceMap.Mat.MEADOW: [SurfaceBlocks.MEADOW, SurfaceBlocks.SOIL, 3],
	SurfaceMap.Mat.FOREST: [SurfaceBlocks.FOREST_FLOOR, SurfaceBlocks.ROOTS, 3],
	SurfaceMap.Mat.DIRT: [SurfaceBlocks.SOIL, SurfaceBlocks.SOIL, 2],
	SurfaceMap.Mat.TRAIL: [SurfaceBlocks.DIRT_PATH, SurfaceBlocks.SOIL, 2],
	SurfaceMap.Mat.ROAD_COBBLE: [SurfaceBlocks.COBBLE, SurfaceBlocks.GRAVEL_FINE, 2],
	SurfaceMap.Mat.ROAD_DIRT: [SurfaceBlocks.DIRT_ROAD, SurfaceBlocks.SOIL, 2],
	SurfaceMap.Mat.PLAZA: [SurfaceBlocks.PLAZA_STONE, SurfaceBlocks.GRAVEL_FINE, 2],
	SurfaceMap.Mat.FARM: [SurfaceBlocks.FARM_SOIL, SurfaceBlocks.SOIL, 3],
	SurfaceMap.Mat.SAND: [SurfaceBlocks.SAND_FINE, SurfaceBlocks.SAND_FINE, 4],
	SurfaceMap.Mat.RIVERBED: [SurfaceBlocks.RIVERBED, SurfaceBlocks.GRAVEL_FINE, 2],
	SurfaceMap.Mat.ROCK: [SurfaceBlocks.STRATA_GREY, SurfaceBlocks.STRATA_GREY, 0],
	SurfaceMap.Mat.SNOW: [SurfaceBlocks.SNOW_FINE, SurfaceBlocks.SNOW_FINE, 2],
	SurfaceMap.Mat.TUNDRA: [SurfaceBlocks.TUNDRA_FINE, SurfaceBlocks.SOIL, 2],
	SurfaceMap.Mat.ASH: [SurfaceBlocks.ASH_FINE, SurfaceBlocks.BASALT, 2],
	SurfaceMap.Mat.BASALT: [SurfaceBlocks.BASALT, SurfaceBlocks.BASALT, 0],
	SurfaceMap.Mat.LAVA: [Blocks.LAVA, SurfaceBlocks.BASALT, 1],
	SurfaceMap.Mat.DESERT_SAND: [SurfaceBlocks.DESERT_FINE, SurfaceBlocks.DESERT_FINE, 4],
	SurfaceMap.Mat.DEEP_SAND: [SurfaceBlocks.DEEP_SAND_FINE, SurfaceBlocks.DEEP_SAND_FINE, 5],
	SurfaceMap.Mat.SANDSTONE: [SurfaceBlocks.STRATA_SAND, SurfaceBlocks.STRATA_SAND, 0],
	SurfaceMap.Mat.BLUE_MOSS: [SurfaceBlocks.BLUE_MOSS_FINE, Blocks.BLUE_ROCK, 2],
	SurfaceMap.Mat.DEEP_STONE: [SurfaceBlocks.DEEP_STONE_FINE, Blocks.DEEP_SLATE, 1],
	SurfaceMap.Mat.JUNGLE_GRASS: [SurfaceBlocks.JUNGLE_FINE, SurfaceBlocks.SOIL, 3],
	SurfaceMap.Mat.STAIRS: [SurfaceBlocks.PLANKS, SurfaceBlocks.PLANKS, 1],
	SurfaceMap.Mat.SEAFLOOR: [SurfaceBlocks.SEAFLOOR_FINE, SurfaceBlocks.SEAFLOOR_FINE, 3],
	SurfaceMap.Mat.CRACKED: [SurfaceBlocks.CRACKED_EARTH, SurfaceBlocks.DESERT_FINE, 2],
	SurfaceMap.Mat.BLACK_SAND: [SurfaceBlocks.BLACK_SAND, SurfaceBlocks.BASALT, 2],
	SurfaceMap.Mat.ICE: [SurfaceBlocks.ICE_FINE, SurfaceBlocks.ICE_FINE, 2],
	SurfaceMap.Mat.YARD: [SurfaceBlocks.YARD, SurfaceBlocks.SOIL, 2],
	SurfaceMap.Mat.ROAD_SAND: [SurfaceBlocks.ROAD_SAND, SurfaceBlocks.DESERT_FINE, 2],
	SurfaceMap.Mat.ROAD_ASH: [SurfaceBlocks.ROAD_ASH, SurfaceBlocks.BASALT, 2],
	SurfaceMap.Mat.ROAD_SNOW: [SurfaceBlocks.ROAD_SNOW, SurfaceBlocks.GRAVEL_FINE, 2],
	SurfaceMap.Mat.OBSIDIAN: [Blocks.OBSIDIAN, SurfaceBlocks.BASALT, 1],
	SurfaceMap.Mat.GRAVEL: [SurfaceBlocks.GRAVEL_FINE, SurfaceBlocks.SOIL, 2],
	SurfaceMap.Mat.MOSS_ROCK: [SurfaceBlocks.MOSS_ROCK, SurfaceBlocks.STRATA_GREY, 0],
}

var realm_seed := 0
var map: SurfaceMap
var _biomes: Array[BiomeDef] = []
## Every planned feature (towns, fortresses, landmarks, biome structures).
var features: Array[RealmFeature] = []
## Each road as a list of points (for lampposts).
var roads: Array[PackedVector2Array] = []
var _feature_grid := {}  # Vector2i cell -> Array[RealmFeature]
var _shape_grid := {}  # the same, only features that reshape the ground (towns are baked)
var villages: Array[VillageFeature] = []
var strongholds: Array[StrongholdFeature] = []
var _lamps: Array[Dictionary] = []
var _lamp_grid := {}  # Vector2i (8 x 8 m cell) -> Array[Vector3], to keep obstacles away
var _deep := {}  # biome id -> deep rock block
## The great peak above Snowbell (the winter campaign climbs it).
var _mountain_center := Vector2.ZERO
var _mountain_radius := 90.0


## layout: unused (the Surface is baked); kept for the world loader's call.
func _init(p_seed: int, _layout := {}) -> void:
	realm_seed = p_seed
	map = SurfaceMap.get_map()
	for id in Biomes.COUNT:
		_biomes.append(Biomes.get_biome(id))
	_deep = {Biomes.WOODS: SurfaceBlocks.STRATA_GREY, Biomes.BEACH: SurfaceBlocks.STRATA_GREY,
		Biomes.OCEAN: SurfaceBlocks.STRATA_GREY, Biomes.JUNGLE: SurfaceBlocks.STRATA_WARM,
		Biomes.FOSEN: SurfaceBlocks.STRATA_FROST, Biomes.DOOM: SurfaceBlocks.STRATA_DARK,
		Biomes.DESERT: SurfaceBlocks.STRATA_SAND, Biomes.DEEP_DESERT: SurfaceBlocks.STRATA_SAND,
		Biomes.BLUELAY: Blocks.BLUE_ROCK, Biomes.DEEP_DARK: Blocks.DEEP_SLATE}
	_plan_from_map()
	_plan_features()
	_plan_lamps()
	_find_mountain()


func _get_used_channels_mask() -> int:
	return 1 << VoxelBuffer.CHANNEL_TYPE


# --- Per-meter answers (the rest of the game) -----------------------------------------

## Vector2i(height of the top block in meters, biome id) for a column,
## including features. The ground (where feet stand) is one meter above.
func column(x: int, z: int) -> Vector2i:
	var base := _base_column(x, z)
	var fs: Variant = _shape_grid.get(Vector2i(x >> FEATURE_CELL_SHIFT, z >> FEATURE_CELL_SHIFT))
	if fs == null:
		return base
	var col := [base.x, -1, -1]
	for f: RealmFeature in fs:
		f.shape(x, z, col)
	return Vector2i(col[0], base.y)


func _base_column(x: int, z: int) -> Vector2i:
	return Vector2i(roundi(map.cell_height(x, z) / float(FINE)) - 1, map.cell_biome(x, z))


## Ground height (meters) at a point: the voxel column there, or a feature's
## flat ground.
func ground_y(x: float, z: float) -> float:
	var mx := floori(x)
	var mz := floori(z)
	if _shape_grid.has(Vector2i(mx >> FEATURE_CELL_SHIFT, mz >> FEATURE_CELL_SHIFT)):
		var d: Variant = _feature_detail(mx, mz)
		if d != null: return float(d[0]) + 1.0
	return map.ground_y(x, z)


## The block on top of a column (after features), e.g. to keep players off lava.
func surface_block(x: int, z: int) -> int:
	return _detail(x, z)[2]


## Height and block of whatever is highest in a column (walls and pillars
## included), as Vector2i(height, block id). For the minimap.
func top_of(x: int, z: int) -> Vector2i:
	var d := _detail(x, z)
	var h: int = d[0]
	var block: int = d[2]
	for i in range(4, d.size(), 3):
		if d[i + 1] - 1 >= h:
			h = d[i + 1] - 1
			block = d[i + 2]
	return Vector2i(h, block)


## The feature covering this column, or null. Structures win over regions.
func feature_at(x: int, z: int) -> RealmFeature:
	var fs: Variant = _feature_grid.get(Vector2i(x >> FEATURE_CELL_SHIFT, z >> FEATURE_CELL_SHIFT))
	if fs != null:
		for f: RealmFeature in fs:
			if f.covers(x, z):
				return f
	return null


## Full meter column: [height, biome id, top block, under block, then
## segments y0, y1, block...] (meters).
func _detail(x: int, z: int) -> Array:
	var d: Variant = _feature_detail(x, z)
	if d != null: return d
	var base := _base_column(x, z)
	var layer: Array = _layer(map.cell_ground(x, z), base.y)
	return [base.x, base.y, layer[0], layer[1]]


## A feature's meter column, or null where no feature reshapes it.
func _feature_detail(x: int, z: int) -> Variant:
	var fs: Variant = _shape_grid.get(Vector2i(x >> FEATURE_CELL_SHIFT, z >> FEATURE_CELL_SHIFT))
	if fs == null: return null
	var base := _base_column(x, z)
	var col := [base.x, -1, -1]
	var shaped := false
	for f: RealmFeature in fs:
		if f.shape(x, z, col): shaped = true
	if not shaped: return null
	var layer: Array = _layer(map.cell_ground(x, z), base.y)
	var out := [col[0], base.y, col[1] if col[1] >= 0 else layer[0], col[2] if col[2] >= 0 else layer[1]]
	out.append_array(col.slice(3))
	return out


func _layer(mat: int, biome_id: int) -> Array:
	if mat == SurfaceMap.Mat.DEFAULT:
		var b := _biomes[biome_id]
		return [b.top_block, b.under_block, 2]
	return LAYERS.get(mat, [SurfaceBlocks.GRASS, SurfaceBlocks.SOIL, 3])


## Whether this meter column is road or town street (walking there is faster).
func is_road(x: int, z: int) -> bool:
	return map.cell_flags(x, z) & (SurfaceMap.ROAD | SurfaceMap.TRAIL) != 0


## Bridges always; water only while it is shallow enough to wade (rivers,
## lakes and the sea alike), so you can walk in and back out anywhere.
const WADE_DEPTH := 1.6


func walkable(x: float, z: float) -> bool:
	var mx := floori(x)
	var mz := floori(z)
	if map.cell_flags(mx, mz) & SurfaceMap.BRIDGE: return true
	var ground := ground_y(x, z)
	var w := map.cell_water(mx, mz)
	var surface := w / float(FINE) if w > 0 else SEA_LEVEL + 0.6
	return surface - ground < WADE_DEPTH


## Water surface (meters) here: a river, lake or the sea; -INF if dry.
func water_y(x: float, z: float) -> float:
	var w := map.cell_water(floori(x), floori(z))
	if w > 0: return w / float(FINE)
	return SEA_LEVEL + 0.6 if ground_y(x, z) < SEA_LEVEL + 0.6 else -INF


# --- Voxels -----------------------------------------------------------------------------

func _generate_block(out_buffer: VoxelBuffer, origin: Vector3i, lod: int) -> void:
	if lod != 0:
		return
	var size := out_buffer.get_size()
	var mx0 := origin.x >> 2
	var mz0 := origin.z >> 2
	var mx1 := (origin.x + size.x - 1) >> 2
	var mz1 := (origin.z + size.z - 1) >> 2
	var featured := false
	for cz in range(mz0 >> FEATURE_CELL_SHIFT, (mz1 >> FEATURE_CELL_SHIFT) + 1):
		for cx in range(mx0 >> FEATURE_CELL_SHIFT, (mx1 >> FEATURE_CELL_SHIFT) + 1):
			if _shape_grid.has(Vector2i(cx, cz)): featured = true
	var span := map.tile_range(origin.x, origin.z)
	if size.x != 16 or size.z != 16:
		span = Vector2i(0, MAX_HEIGHT * FINE)
	if origin.y >= span.y + (100 if featured else 0):
		return  # all air
	var deep: int = _deep.get(map.cell_biome(mx0 + 2, mz0 + 2), SurfaceBlocks.STRATA_GREY)
	if not featured and origin.y + size.y <= span.x:
		out_buffer.fill(deep, VoxelBuffer.CHANNEL_TYPE)
		return
	var cache := {}
	for lz in size.z:
		for lx in size.x:
			var fx := origin.x + lx
			var fz := origin.z + lz
			var mx := fx >> 2
			var mz := fz >> 2
			if featured:
				var key := Vector2i(mx, mz)
				if not cache.has(key): cache[key] = _feature_detail(mx, mz)
				var d: Variant = cache[key]
				if d != null:
					_fill_feature(out_buffer, origin, lx, lz, d, deep)
					_fill_overlays(out_buffer, origin, lx, lz, fx, fz)
					continue
			_fill_column(out_buffer, origin, lx, lz, fx, fz, mx, mz, deep)


## A legacy feature column: 1 m blocks drawn 4 voxels to a side.
func _fill_feature(buf: VoxelBuffer, origin: Vector3i, lx: int, lz: int, d: Array, deep: int) -> void:
	var h: int = d[0]
	_fill(buf, origin, lx, lz, -100000, (h - 2) * FINE, deep)
	_fill(buf, origin, lx, lz, (h - 2) * FINE, h * FINE, d[3])
	_fill(buf, origin, lx, lz, h * FINE, (h + 1) * FINE, d[2])
	for i in range(4, d.size(), 3):
		_fill(buf, origin, lx, lz, int(d[i]) * FINE, int(d[i + 1]) * FINE, d[i + 2])


func _fill_column(buf: VoxelBuffer, origin: Vector3i, lx: int, lz: int, fx: int, fz: int, mx: int, mz: int, deep: int) -> void:
	var top := map.fine_height(fx, fz)
	var mat := map.cell_ground(mx, mz)
	var biome_id := map.cell_biome(mx, mz)
	var bits := map.cell_shape(mx, mz)
	var layer: Array = _layer(mat, biome_id)
	var top_block: int = layer[0]
	var under: int = layer[1]
	var depth: int = layer[2]
	var flags := map.cell_flags(mx, mz)
	var r := SurfaceMap.hash01(fx, fz, 11)
	# Variety: lusher grass under the trees, meadows sprinkled with clover.
	if top_block == SurfaceBlocks.GRASS:
		var forest := map.cell_flora(mx, mz)
		if forest > 0.55: top_block = SurfaceBlocks.GRASS_LUSH
		elif r < 0.04: top_block = SurfaceBlocks.MEADOW
		elif flags & SurfaceMap.TOWN and r < 0.25: top_block = SurfaceBlocks.YARD
	elif top_block == SurfaceBlocks.DIRT_ROAD and r < 0.12:
		top_block = SurfaceBlocks.GRAVEL_FINE
	elif top_block == SurfaceBlocks.RIVERBED and r < 0.3:
		top_block = SurfaceBlocks.GRAVEL_FINE
	elif mat == SurfaceMap.Mat.BLUE_MOSS and r < 0.012:
		top_block = Blocks.BLUE_GLOW
	elif mat == SurfaceMap.Mat.ASH and r < 0.006:
		top_block = Blocks.EMBER
	elif mat == SurfaceMap.Mat.LAVA:
		top -= 1
	elif mat == SurfaceMap.Mat.FARM and (fz >> 1) & 1 == 1:
		top -= 1  # furrows
	# Stone walls show rock right under the grass lip (roads, trails and
	# stairs keep their own surface all the way over the edge).
	if bits & SurfaceMap.CLIFF and flags & (SurfaceMap.ROAD | SurfaceMap.TRAIL | SurfaceMap.BRIDGE) == 0:
		depth = 0
		if top_block in [SurfaceBlocks.DIRT_PATH, SurfaceBlocks.SOIL]: top_block = deep
	# Rough rock: a voxel up here and there.
	if bits & SurfaceMap.ROCKY and r > 0.72 and flags & BUSY == 0:
		top += 1
		if r > 0.9: top_block = deep if depth == 0 else top_block
	# Stones in the rivers, some breaking the surface.
	var w := map.cell_water(mx, mz)
	if w > 0 and flags & SurfaceMap.RIVER and flags & SurfaceMap.BRIDGE == 0:
		var clump := SurfaceMap.hash01(fx >> 1, fz >> 1, 12)
		if clump < 0.07:
			# Under the surface or clearly above it, never level with it
			# (the two would flicker against each other).
			top = maxi(top, w + [-2, -1, 1][int(clump * 40.0) % 3])
			top_block = SurfaceBlocks.RIVER_STONE
			depth = 0
		elif clump < 0.16:
			top += 1
			if top == w: top -= 2
			top_block = SurfaceBlocks.RIVER_STONE
	_fill(buf, origin, lx, lz, -100000, top - 1 - depth, deep)
	if depth > 0: _fill(buf, origin, lx, lz, top - 1 - depth, top - 1, under)
	_fill(buf, origin, lx, lz, top - 1, top, top_block)
	# Ivy on the walls: strands climbing from the foot of a wall.
	if bits & SurfaceMap.VINES:
		var wall := _wall_beside(fx, fz, mx, mz)
		if wall > top + 4 and SurfaceMap.hash01(fx, fz, 13) < 0.65:
			var reach := int((wall - top) * (0.35 + 0.65 * SurfaceMap.hash01(fx, fz, 14)))
			var vine := SurfaceBlocks.VINE_FLOWER if SurfaceMap.hash01(fx, fz, 15) < 0.15 else SurfaceBlocks.VINE
			_fill(buf, origin, lx, lz, top, top + reach, vine)
	_fill_overlays(buf, origin, lx, lz, fx, fz)


## The height of a wall right next to this voxel column (0 if none): only the
## voxels along the edge of the meter cell touch the wall.
func _wall_beside(fx: int, fz: int, mx: int, mz: int) -> int:
	var best := 0
	if fx & 3 == 3: best = maxi(best, map.cell_height(mx + 1, mz))
	if fx & 3 == 0: best = maxi(best, map.cell_height(mx - 1, mz))
	if fz & 3 == 3: best = maxi(best, map.cell_height(mx, mz + 1))
	if fz & 3 == 0: best = maxi(best, map.cell_height(mx, mz - 1))
	return best


func _fill_overlays(buf: VoxelBuffer, origin: Vector3i, lx: int, lz: int, fx: int, fz: int) -> void:
	var list: Variant = map.overlays.get(Vector2i(fx, fz))
	if list == null: return
	var segments: PackedInt32Array = list
	for i in range(0, segments.size(), 3):
		_fill(buf, origin, lx, lz, segments[i], segments[i + 1], segments[i + 2])


## Fills voxel range [y0, y1) of one column, clipped to the buffer.
func _fill(buf: VoxelBuffer, origin: Vector3i, lx: int, lz: int, y0: int, y1: int, value: int) -> void:
	var sy := buf.get_size().y
	var a := clampi(y0 - origin.y, 0, sy)
	var b := clampi(y1 - origin.y, 0, sy)
	if a < b:
		buf.fill_area(value, Vector3i(lx, a, lz), Vector3i(lx + 1, b, lz + 1), VoxelBuffer.CHANNEL_TYPE)


# --- Places -------------------------------------------------------------------------------

## Arrival in the capital's plaza. The second value points toward its portal.
func find_spawn() -> Array:
	var capital := villages[0]
	var at := Vector2(capital.center) + Vector2(0.5, 0.5) + Vector2(2.5, 2.5)
	return [surface(at), Vector2(0, 1)]


## Standing position on the ground at p (x/z).
func surface(p: Vector2) -> Vector3:
	return Vector3(p.x, ground_y(p.x, p.y), p.y)


## The baked towns, farms, fortresses and the launch pad.
func _plan_from_map() -> void:
	for s: Dictionary in map.settlements():
		var town := VillageFeature.from_baked(s, self)
		villages.append(town)
		_add_feature(town)
	for s: Dictionary in map.strongholds():
		var at := Vector2i(int(s.at[0]), int(s.at[1]))
		var toward := Vector2(at) + Vector2.from_angle(float(s.gate_angle)) * 10.0
		var fort := StrongholdFeature.plan(at, int(s.biome), int(s.height) - 1, int(s.seed), toward)
		fort.set_meta(&"gate_angle", float(s.gate_angle))
		strongholds.append(fort)
		_add_feature(fort)
	var rng := RandomNumberGenerator.new()
	rng.seed = realm_seed * 67 + 3
	for l: Dictionary in map.landmarks():
		var at := Vector2i(int(l.at[0]), int(l.at[1]))
		_add_feature(RealmFeature.create(str(l.type), at, true, int(l.height) - 1, rng))
	for r: Dictionary in map.data.get("roads", []):
		var points := PackedVector2Array()
		for p: Array in r.points: points.append(Vector2(p[0], p[1]))
		if points.size() >= 2: roads.append(points)


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
		if base.y != biome_id or base.x < SEA_LEVEL:
			continue
		if type == "ravine" and base.x < SEA_LEVEL + 12:
			continue  # ravines cut into the mountains' flanks
		var f := RealmFeature.create(type, c, required, base.x, rng, _biomes[biome_id])
		if _fits(f, biome_id, strict):
			_add_feature(f)
			return true
	return false


## Registers a feature in the lookup grid.
func _add_feature(f: RealmFeature) -> void:
	features.append(f)
	for cz in range(f.bounds.position.y >> FEATURE_CELL_SHIFT, (f.bounds.end.y >> FEATURE_CELL_SHIFT) + 1):
		for cx in range(f.bounds.position.x >> FEATURE_CELL_SHIFT, (f.bounds.end.x >> FEATURE_CELL_SHIFT) + 1):
			var key := Vector2i(cx, cz)
			if not _feature_grid.has(key):
				_feature_grid[key] = []
			_feature_grid[key].append(f)
			if f.shapes_terrain():
				if not _shape_grid.has(key):
					_shape_grid[key] = []
				_shape_grid[key].append(f)


## strict: the whole feature must lie in its biome on fairly level ground,
## clear of towns, roads, rivers and fields.
func _fits(f: RealmFeature, biome_id: int, strict := true) -> bool:
	for other in features:
		if Vector2(f.center).distance_to(Vector2(other.center)) < f.radius + other.radius + FEATURE_GAP:
			return false
	var reach := maxf(f.radius, 4.0)
	for k in 9:
		var p := Vector2(f.center) + (Vector2.from_angle(k * TAU / 8.0) * reach if k < 8 else Vector2.ZERO)
		var x := floori(p.x)
		var z := floori(p.y)
		if map.cell_flags(x, z) & BUSY or map.cell_water(x, z) > 0:
			return false
		if not strict: continue
		var col := _base_column(x, z)
		if col.y != biome_id:
			return false
		if f.is_structure() and absi(col.x - f.base_height) > 2:
			return false  # structures need fairly flat ground
	return true


## Whether a column is road or town street.
func _near_town(p: Vector2) -> bool:
	for village in villages:
		if p.distance_to(Vector2(village.center)) < village.radius + TOWN_PACK_MARGIN:
			return true
	return false


func _find_mountain() -> void:
	var near := Vector2.ZERO
	for v in villages:
		if v.biome_id == Biomes.FOSEN and v.kind == "town": near = Vector2(v.center)
	var best := -1
	for z in range(-260, 261, 4):
		for x in range(-260, 261, 4):
			var p := near + Vector2(x, z)
			if map.cell_biome(floori(p.x), floori(p.y)) != Biomes.FOSEN: continue
			var h := map.cell_height(floori(p.x), floori(p.y))
			if h > best:
				best = h
				_mountain_center = p


# --- Lamps --------------------------------------------------------------------------------

## Lamppost spots beside the roads: [{pos, yaw}], the lantern arm over the road.
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
				var pos := Vector3(x + 0.5, ground_y(x + 0.5, z + 0.5), z + 0.5)
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
	var biome := _biomes[map.cell_biome(x, z)]
	if not biome.lampposts or map.cell_height(x, z) < (SEA_LEVEL + 1) * FINE:
		return false
	var h := map.cell_height(x, z)
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			if absi(map.cell_height(x + dx, z + dz) - h) > 2 or map.cell_flags(x + dx, z + dz) & (KEEP_OPEN & ~SurfaceMap.CLEAR) \
					or feature_at(x + dx, z + dz) != null or map.cell_water(x + dx, z + dz) > 0:
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


# --- Obstacles and trees ------------------------------------------------------------------

## Seeded breakable obstacles inside `area` (meters): [{id, prefab, biome,
## pos, yaw}]. Rocks, boulders, crystals... on open ground, never on roads,
## trails, fields, in towns or water, nor near the given points.
func obstacle_sites(area: Rect2i, keep_clear: Array[Vector3], keep_clear_radius: float) -> Array[Dictionary]:
	var sites: Array[Dictionary] = []
	for cz in range(ceili(float(area.position.y) / OBSTACLE_CELL), ceili(float(area.end.y) / OBSTACLE_CELL)):
		for cx in range(ceili(float(area.position.x) / OBSTACLE_CELL), ceili(float(area.end.x) / OBSTACLE_CELL)):
			var site := _obstacle_in_cell(cx, cz)
			if site.is_empty():
				continue
			var pos: Vector3 = site.pos
			var blocked := false
			for p in keep_clear:
				blocked = blocked or Vector2(p.x - pos.x, p.z - pos.z).length() < keep_clear_radius
			if not blocked:
				sites.append(site)
	return sites


func _obstacle_in_cell(cx: int, cz: int) -> Dictionary:
	var x := cx * OBSTACLE_CELL + 1 + int(_hash(cx, cz, 21) * (OBSTACLE_CELL - 2))
	var z := cz * OBSTACLE_CELL + 1 + int(_hash(cx, cz, 22) * (OBSTACLE_CELL - 2))
	var biome := _biomes[map.cell_biome(x, z)]
	if biome.obstacles.is_empty() or _hash(cx, cz, 23) >= biome.obstacle_density:
		return {}
	var prefab_name := _pick(biome.obstacles, _hash(cx, cz, 24))
	var prefab := ObstacleLibrary.get_prefab(prefab_name)
	var half := ceili(maxf(prefab.footprint.x, prefab.footprint.y) * 0.5)
	var lowest := INF
	var highest := -INF
	for offset in [Vector2i.ZERO, Vector2i(-half, -half), Vector2i(half, -half), Vector2i(-half, half), Vector2i(half, half)]:
		var ox: int = x + offset.x
		var oz: int = z + offset.y
		if map.cell_flags(ox, oz) & BUSY or map.cell_water(ox, oz) > 0 or feature_at(ox, oz) != null:
			return {}
		var h := map.cell_height(ox, oz) / float(FINE)
		lowest = minf(lowest, h)
		highest = maxf(highest, h)
	if highest - lowest > 1.0 or lowest < SEA_LEVEL + 0.5:
		return {}
	var pos := Vector3(x + 0.5, lowest, z + 0.5)
	if _near_lamp(pos, maxf(prefab.footprint.x, prefab.footprint.y) * 0.5 + LAMP_CLEARANCE):
		return {}
	return {id = "%d_%d" % [cx, cz], prefab = prefab_name, biome = biome.id, pos = pos,
		yaw = _hash(cx, cz, 25) * TAU}


## What trees grow where (prefab -> weight), by biome; the forest's mood
## changes from patch to patch (birch groves, autumn maples, blossom).
const TREES := {
	Biomes.WOODS: [{"surface/oak_round": 6, "surface/oak_tall": 3, "surface/birch": 1, "surface/pine_tall": 1},
		{"surface/birch": 6, "surface/oak_round": 1, "surface/blossom": 0.6},
		{"surface/maple": 3, "surface/maple_red": 2, "surface/maple_gold": 2, "surface/oak_round": 1},
		{"surface/fir": 3, "surface/pine_tall": 3, "surface/oak_tall": 1}],
	Biomes.JUNGLE: [{"surface/jungle_giant": 3, "surface/palm": 1, "surface/oak_tall": 1}],
	Biomes.FOSEN: [{"surface/fir_snow": 4, "surface/fir_snow_tall": 3, "surface/fir": 1, "surface/birch": 0.4}],
	Biomes.BEACH: [{"surface/palm": 1}],
	Biomes.DESERT: [{"surface/saguaro": 3, "surface/acacia": 2, "surface/palm": 0.5}],
	Biomes.DEEP_DESERT: [{"surface/saguaro": 2, "surface/dead_tree": 1}],
	Biomes.DOOM: [{"surface/burnt_tree": 4, "surface/dead_tree": 1}],
	Biomes.BLUELAY: [{"surface/mushroom_giant": 3, "surface/willow": 1}],
	Biomes.DEEP_DARK: [{"surface/ash_spire": 1}],
}
## How thick each biome's forest grows (Fosen's tall firs are spread out so
## you can walk between them).
const TREE_DENSITY := {Biomes.FOSEN: 0.4, Biomes.WOODS: 0.855, Biomes.JUNGLE: 0.9}
## Near water: willows and reeds in the green biomes.
const WATERSIDE := {"surface/willow": 3, "surface/birch": 1}


## Trees in `area` (meters), the same on the server (trunk collision) and
## every client (meshes): [{prefab, pos, yaw, scale, biome}].
func tree_sites(area: Rect2i, keep_clear: Array[Vector3], keep_clear_radius: float) -> Array[Dictionary]:
	var sites: Array[Dictionary] = []
	var rocks := {}  # obstacle cell -> its site (or {}), looked up once
	for cz in range(ceili(float(area.position.y) / TREE_CELL), ceili(float(area.end.y) / TREE_CELL)):
		for cx in range(ceili(float(area.position.x) / TREE_CELL), ceili(float(area.end.x) / TREE_CELL)):
			var fx := (cx + 0.15 + _hash(cx, cz, 61) * 0.7) * TREE_CELL
			var fz := (cz + 0.15 + _hash(cx, cz, 62) * 0.7) * TREE_CELL
			var x := floori(fx)
			var z := floori(fz)
			var density: float = map.cell_flora(x, z) * TREE_DENSITY.get(map.cell_biome(x, z), 1.0)
			if _hash(cx, cz, 63) >= density * 0.62:
				continue
			if map.cell_flags(x, z) & KEEP_OPEN or map.cell_water(x, z) > 0 or map.cell_shape(x, z) & SurfaceMap.CLIFF:
				continue
			var b := map.cell_biome(x, z)
			var groups: Array = TREES.get(b, [])
			if groups.is_empty():
				continue
			var mood := _mood(x, z)
			var choice: Dictionary = groups[mini(int(mood * groups.size()), groups.size() - 1)]
			if b in [Biomes.WOODS, Biomes.JUNGLE, Biomes.BLUELAY] and _near_water(x, z):
				choice = WATERSIDE
			var prefab := _pick(choice, _hash(cx, cz, 64))
			var pos := Vector3(fx, map.ground_y(fx, fz) - 0.1, fz)
			if pos.y < SEA_LEVEL + 0.6:
				continue
			var blocked := false
			for p in keep_clear:
				blocked = blocked or Vector2(p.x - pos.x, p.z - pos.z).length() < keep_clear_radius
			if blocked or feature_at(x, z) != null or _near_lamp(pos, 2.0) or _near_obstacle(pos, rocks):
				continue
			sites.append({prefab = prefab, pos = pos, yaw = _hash(cx, cz, 65) * TAU,
				scale = 0.8 + _hash(cx, cz, 66) * 0.45, biome = b})
	return sites


## 0..1 slowly varying across the land: which kind of wood grows here.
func _mood(x: int, z: int) -> float:
	var a := _hash(x >> 6, z >> 6, 71)
	var b := _hash((x >> 6) + 1, z >> 6, 71)
	var c := _hash(x >> 6, (z >> 6) + 1, 71)
	var d := _hash((x >> 6) + 1, (z >> 6) + 1, 71)
	var tx := smoothstep(0.0, 1.0, (x & 63) / 64.0)
	var tz := smoothstep(0.0, 1.0, (z & 63) / 64.0)
	return lerpf(lerpf(a, b, tx), lerpf(c, d, tx), tz)


func _near_water(x: int, z: int) -> bool:
	for o in [Vector2i(4, 0), Vector2i(-4, 0), Vector2i(0, 4), Vector2i(0, -4)]:
		if map.cell_water(x + o.x, z + o.y) > 0: return true
	return false


func _near_obstacle(pos: Vector3, rocks: Dictionary) -> bool:
	var cx := floori(pos.x / OBSTACLE_CELL)
	var cz := floori(pos.z / OBSTACLE_CELL)
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			var key := Vector2i(cx + dx, cz + dz)
			if not rocks.has(key): rocks[key] = _obstacle_in_cell(key.x, key.y)
			var site: Dictionary = rocks[key]
			if not site.is_empty() and Vector2(site.pos.x - pos.x, site.pos.z - pos.z).length() < 3.0:
				return true
	return false


# --- Enemies ----------------------------------------------------------------------------------

## Seeded enemy pack sites inside `area`: [{id, pack, pos, seed}]. Packs
## sit on dry, walkable ground away from towns, roads and the arrival point.
func pack_sites(area: Rect2i, keep_clear: Array[Vector3]) -> Array[Dictionary]:
	var sites: Array[Dictionary] = []
	for cz in range(floori(float(area.position.y) / PACK_CELL), ceili(float(area.end.y) / PACK_CELL)):
		for cx in range(floori(float(area.position.x) / PACK_CELL), ceili(float(area.end.x) / PACK_CELL)):
			var x := cx * PACK_CELL + 4 + int(_hash(cx, cz, 41) * (PACK_CELL - 8))
			var z := cz * PACK_CELL + 4 + int(_hash(cx, cz, 42) * (PACK_CELL - 8))
			if not area.has_point(Vector2i(x, z)):
				continue  # belongs to a neighbouring chunk
			var biome := _biomes[map.cell_biome(x, z)]
			if biome.enemy_packs.is_empty() or feature_at(x, z) != null or _near_town(Vector2(x, z)):
				continue
			if not walkable(x + 0.5, z + 0.5) or map.cell_flags(x, z) & (SurfaceMap.ROAD | SurfaceMap.LAKE):
				continue
			var weights := {}
			var density := 0.0
			for entry in biome.enemy_packs:
				weights[entry.pack] = entry.density
				density += entry.density
			if _hash(cx, cz, 43) >= density:
				continue
			var pos := surface(Vector2(x + 0.5, z + 0.5))
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
## ruins, the bosses in their fortresses): each feature's `packs`
## ([{pack, chance, offset}]) roll once from the realm seed.
func _feature_pack_sites(area: Rect2i, keep_clear: Array[Vector3]) -> Array[Dictionary]:
	var sites: Array[Dictionary] = []
	for f in features:
		if f.packs.is_empty():
			continue
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
			var pos := Vector3(x + 0.5, ground_y(x + 0.5, z + 0.5), z + 0.5)
			var blocked := _near_town(Vector2(x, z))
			for p in keep_clear:
				blocked = blocked or Vector2(p.x - pos.x, p.z - pos.z).length() < PACK_KEEP_CLEAR
			if not blocked:
				sites.append({id = "feature_%d_%d%s" % [f.center.x, f.center.y, "" if k == 0 else "_%d" % k], pack = pick[0], pos = pos,
						seed = int(_hash(f.center.x + k, f.center.y, 49) * 1_000_000) + realm_seed})
	return sites


## Works before streamed terrain colliders are ready. Rejects structure
## interiors, walls, water and ground rising through the body's footprint.
func enemy_spawn_clear(pos: Vector3, radius: float, height: float, allow_towns := false) -> bool:
	var reach := radius + 0.12
	for z in range(floori(pos.z - reach), floori(pos.z + reach) + 1):
		for x in range(floori(pos.x - reach), floori(pos.x + reach) + 1):
			var feature := feature_at(x, z)
			if feature != null and feature.is_structure() and feature.type != "stronghold" and not (allow_towns and feature is VillageFeature):
				return false
			if not walkable(x + 0.5, z + 0.5):
				return false
			var detail: Variant = _feature_detail(x, z)
			if detail == null:
				if map.cell_height(x, z) / float(FINE) > pos.y + 0.6:
					return false
				continue
			if detail[0] + 1 > pos.y + 0.15 or Blocks.is_hazard(detail[2]):
				return false
			for i in range(4, detail.size(), 3):
				if detail[i] < pos.y + height + 0.15 and detail[i + 1] > pos.y + 0.10:
					return false
	return not Blocks.is_hazard(surface_block(floori(pos.x), floori(pos.z)))


# --- Helpers -------------------------------------------------------------------------------

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
