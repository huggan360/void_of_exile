class_name SurfaceMap
extends RefCounted
## The baked Surface (res://realm/surface/, made by tools/surface/bake_surface.py):
## one value per meter for ground height, water, ground material, biome,
## forest density, flags and cliff shape over the 2048 x 2048 m world, plus
## the planned places (towns, fortresses, roads, stairs, bridges...) in
## surface.json. Loaded once; read-only afterwards, so terrain worker threads
## can read it freely.
##
## Heights are in voxels (0.25 m). The ground between meter samples is
## blended per voxel column (fine_height), except across stone walls, which
## stay sheer with a ragged voxel edge.

const DIR := "res://realm/surface/"
const N := 2048
const HALF := 1024
const FINE := 4  # voxels per meter
const TILE := 4  # meters per entry in the tile range table
const LAYERS := ["height", "water", "ground", "biome", "flora", "flags", "shape", "tiles", "current"]

## Ground materials (tools/surface/bake_surface.py M_*).
enum Mat { DEFAULT, GRASS, MEADOW, FOREST, DIRT, TRAIL, ROAD_COBBLE, ROAD_DIRT, PLAZA, FARM,
	SAND, RIVERBED, ROCK, SNOW, TUNDRA, ASH, BASALT, LAVA, DESERT_SAND, DEEP_SAND,
	SANDSTONE, BLUE_MOSS, DEEP_STONE, JUNGLE_GRASS, STAIRS, SEAFLOOR, CRACKED, BLACK_SAND,
	ICE, YARD, ROAD_SAND, ROAD_ASH, ROAD_SNOW, OBSIDIAN, GRAVEL, MOSS_ROCK }
## Flag bits.
const ROAD := 1
const TRAIL := 2
const TOWN := 4
const FIELD := 8
const RIVER := 16
const CLEAR := 32
const LAKE := 64
const BRIDGE := 128
## Shape bits.
const CLIFF := 1
const CLIFF_BASE := 2
const VINES := 4
const ROCKY := 8

static var _instance: SurfaceMap
static var _lock := Mutex.new()

var height := PackedByteArray()
var water := PackedByteArray()
var ground := PackedByteArray()
var biome := PackedByteArray()
var flora := PackedByteArray()
var flags := PackedByteArray()
var shape := PackedByteArray()
var tiles := PackedByteArray()
var current := PackedByteArray()
var data := {}
## Voxel overlays (rails, posts, bridge decks, fences): Vector2i fine column ->
## PackedInt32Array [y0, y1, block, ...] in voxels.
var overlays := {}
## Bridge decks: Vector2i fine column -> the deck's top (voxels).
var decks := {}
## Every source file, so caches of generated terrain notice a new bake.
var sources: Array[String] = []


static func get_map() -> SurfaceMap:
	_lock.lock()
	if _instance == null:
		_instance = SurfaceMap.new()
		_instance._load()
	_lock.unlock()
	return _instance


func _load() -> void:
	for layer: String in LAYERS:
		var path: String = DIR + layer + ".bin.gz"
		sources.append(path)
		var file := FileAccess.open(path, FileAccess.READ)
		assert(file != null, "Missing baked surface layer " + path)
		var packed := file.get_buffer(file.get_length())
		var size := N * N * (2 if layer in ["height", "water", "current"] else 1)
		if layer == "tiles":
			size = (N / TILE) * (N / TILE) * 4
		set(layer, packed.decompress(size, FileAccess.COMPRESSION_GZIP))
		assert(get(layer).size() == size, "Bad baked surface layer " + path)
	sources.append(DIR + "surface.json")
	data = JSON.parse_string(FileAccess.get_file_as_string(DIR + "surface.json"))
	_build_overlays()


# --- Lookups (meter cells; outside the map is open sea) -----------------------------

func _index(mx: int, mz: int) -> int:
	return (clampi(mz + HALF, 0, N - 1)) * N + clampi(mx + HALF, 0, N - 1)

func inside(mx: int, mz: int) -> bool:
	return mx >= -HALF and mz >= -HALF and mx < HALF and mz < HALF

## Ground height at a meter cell, in voxels.
func cell_height(mx: int, mz: int) -> int:
	if not inside(mx, mz): return 12
	return height.decode_u16(_index(mx, mz) * 2)

## River or lake surface at a meter cell in voxels (0 = none).
func cell_water(mx: int, mz: int) -> int:
	if not inside(mx, mz): return 0
	return water.decode_u16(_index(mx, mz) * 2)

func cell_ground(mx: int, mz: int) -> int:
	return ground[_index(mx, mz)] if inside(mx, mz) else Mat.SEAFLOOR

func cell_biome(mx: int, mz: int) -> int:
	return biome[_index(mx, mz)] if inside(mx, mz) else Biomes.OCEAN

func cell_flags(mx: int, mz: int) -> int:
	return flags[_index(mx, mz)] if inside(mx, mz) else 0

func cell_shape(mx: int, mz: int) -> int:
	return shape[_index(mx, mz)] if inside(mx, mz) else 0

## Forest density 0..1.
func cell_flora(mx: int, mz: int) -> float:
	return flora[_index(mx, mz)] / 255.0 if inside(mx, mz) else 0.0

## Lowest and highest voxel that can be solid in the 16 x 16 voxel tile
## holding fine column (fx, fz).
func tile_range(fx: int, fz: int) -> Vector2i:
	var tx := (fx >> 4) + N / TILE / 2
	var tz := (fz >> 4) + N / TILE / 2
	if tx < 0 or tz < 0 or tx >= N / TILE or tz >= N / TILE: return Vector2i(0, 40)
	var i := (tz * (N / TILE) + tx) * 4
	return Vector2i(tiles.decode_u16(i), tiles.decode_u16(i + 2))


# --- Voxel columns -------------------------------------------------------------------

## Ground height of a fine (0.25 m) column, in voxels: blended between meter
## samples, sheer and ragged where they step by more than a wall's height.
func fine_height(fx: int, fz: int) -> int:
	var mx := fx >> 2
	var mz := fz >> 2
	var ux := ((fx & 3) + 0.5) * 0.25 - 0.5  # -0.375 .. 0.375 from the cell center
	var uz := ((fz & 3) + 0.5) * 0.25 - 0.5
	var ax := mx - 1 if ux < 0.0 else mx
	var az := mz - 1 if uz < 0.0 else mz
	var tx := ux + 1.0 if ux < 0.0 else ux
	var tz := uz + 1.0 if uz < 0.0 else uz
	var h00 := cell_height(ax, az)
	var h10 := cell_height(ax + 1, az)
	var h01 := cell_height(ax, az + 1)
	var h11 := cell_height(ax + 1, az + 1)
	var lo := mini(mini(h00, h10), mini(h01, h11))
	var hi := maxi(maxi(h00, h10), maxi(h01, h11))
	if hi - lo > 5:
		# A stone wall: the nearest sample decides, its edge wobbling per voxel.
		var jx := tx + (hash01(fx, fz, 3) - 0.5) * 0.45
		var jz := tz + (hash01(fx, fz, 4) - 0.5) * 0.45
		var h := (h11 if jz >= 0.5 else h10) if jx >= 0.5 else (h01 if jz >= 0.5 else h00)
		return h
	var top := lerpf(lerpf(h00, h10, tx), lerpf(h01, h11, tx), tz)
	return roundi(top)

## Ground height (meters) at a point, the top of the voxel column there (or
## of the bridge deck above it).
func ground_y(x: float, z: float) -> float:
	var fx := floori(x * FINE)
	var fz := floori(z * FINE)
	if cell_flags(fx >> 2, fz >> 2) & BRIDGE:
		var deck: Variant = decks.get(Vector2i(fx, fz))
		if deck != null: return int(deck) / float(FINE)
	return fine_height(fx, fz) / float(FINE)


static func hash01(x: int, z: int, salt: int) -> float:
	var n := x * 374761393 + z * 668265263 + salt * 982451653
	n = (n ^ (n >> 13)) * 1274126177
	n = n ^ (n >> 16)
	return float(n & 0xFFFFFF) / float(0xFFFFFF)


# --- Overlays: beams and posts drawn as voxels into the terrain ----------------------

func _build_overlays() -> void:
	for post: Dictionary in data.get("posts", []):
		var fx := floori(float(post.x) * FINE)
		var fz := floori(float(post.z) * FINE)
		_add_overlay(Vector2i(fx, fz), floori(float(post.y0) * FINE), ceili(float(post.y1) * FINE), _block(str(post.block)))
	for beam: Dictionary in data.get("beams", []):
		var line: Array = []
		if beam.has("line"):
			line = beam.line
		else:
			for p: Array in beam.points: line.append([p[0], p[1], beam.y])
		var half := float(beam.width) * 0.5
		var thick := maxi(1, roundi(float(beam.thick) * FINE))
		var block := _block(str(beam.block))
		var wide := half > 0.3
		var deck := bool(beam.get("deck", false))
		for i in line.size() - 1:
			var a := Vector3(line[i][0], line[i][2], line[i][1])
			var b := Vector3(line[i + 1][0], line[i + 1][2], line[i + 1][1])
			var length := Vector2(b.x - a.x, b.z - a.z).length()
			var steps := maxi(1, ceili(length * FINE * 2.0))
			var side := Vector2(-(b.z - a.z), b.x - a.x).normalized()
			var done := {}
			for s in steps + 1:
				var p := a.lerp(b, float(s) / steps)
				var top := roundi(p.y * FINE)
				for w in range(-ceili(half * FINE), ceili(half * FINE) + 1):
					var at := Vector2(p.x, p.z) + side * (w / float(FINE))
					var key := Vector2i(floori(at.x * FINE), floori(at.y * FINE))
					if done.has(key): continue
					done[key] = true
					# Wide decks get darker edge planks; rails are one beam.
					var edge := wide and absi(w) >= ceili(half * FINE) - 1
					_add_overlay(key, top - thick, top, Blocks.TIMBER if edge else block)
					if deck: decks[key] = maxi(int(decks.get(key, -1)), top)


func _add_overlay(key: Vector2i, y0: int, y1: int, block: int) -> void:
	if not overlays.has(key): overlays[key] = PackedInt32Array()
	var list: PackedInt32Array = overlays[key]
	list.append_array([y0, y1, block])
	overlays[key] = list


static func _block(name: String) -> int:
	match name:
		"planks": return SurfaceBlocks.PLANKS
		"timber": return Blocks.TIMBER
	return Blocks.OAK_PLANKS


# --- River currents -----------------------------------------------------------------

## The river current in a meter cell: Vector2 along the flow, its length the
## speed 0..1 (zero on lakes, the sea and dry land).
func cell_current(mx: int, mz: int) -> Vector2:
	if not inside(mx, mz): return Vector2.ZERO
	var i := _index(mx, mz) * 2
	return Vector2((current[i] - 128) / 127.0, (current[i + 1] - 128) / 127.0)


# --- Planned places ------------------------------------------------------------------

func settlements() -> Array:
	return data.get("settlements", [])

func strongholds() -> Array:
	return data.get("strongholds", [])

func landmarks() -> Array:
	return data.get("landmarks", [])
