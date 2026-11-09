class_name RealmFeature
extends RefCounted
## A special area inside a biome. Regions (lava scars, ravines, glow pools)
## follow a winding path or blob; structures (shrines, towers, temples...)
## flatten a plot and build on it. Biomes list which features must generate
## and which may (BiomeDef.features). Required features are guaranteed, so
## enemies and bosses can be tied to them later.
##
## Features reshape terrain one column at a time in shape(), which runs on the
## generator's worker threads, so everything here is read-only after create().

## type: [display name, radius in blocks, light color (black = no lights)]
const TYPES := {
	woodland_lake = ["Willowmere Lake", 24, Color.BLACK],
	launchpad = ["Skyward Launch Pad", 22, Color(0.55, 0.8, 1.0)],
	lava_scar = ["Lava Scar", 0, Color(1.0, 0.4, 0.1)],
	ravine = ["Frozen Ravine", 0, Color.BLACK],
	glow_pool = ["Glow Pool", 7, Color(0.3, 0.85, 1.0)],
	ember_shrine = ["Ember Shrine", 10, Color(1.0, 0.4, 0.1)],
	frost_tower = ["Frost Tower", 7, Color(0.6, 0.8, 1.0)],
	crystal_spire = ["Crystal Spire", 8, Color(0.3, 0.85, 1.0)],
	stone_circle = ["Stone Circle", 8, Color.BLACK],
	sunken_temple = ["Sunken Temple", 9, Color.BLACK],
	ziggurat = ["Overgrown Ziggurat", 10, Color(1.0, 0.7, 0.35)],
	ruins = ["Ruins", 0, Color.BLACK],
	tide_rocks = ["Tide Rocks", 7, Color.BLACK],
	road = ["Old Road", 0, Color.BLACK],
}
const PATH_TYPES := ["lava_scar", "ravine", "road"]

var type := ""
var display_name := ""
var required := false
var center := Vector2i.ZERO
var radius := 8.0
## Ground height at the center; structures are built flat at this height.
var base_height := 0
var bounds := Rect2i()
var light_color := Color.BLACK
## Where lights go: x/z in world blocks, y = meters above the ground there.
var light_spots: Array[Vector3] = []
## Enemy packs that live here: [{pack, chance, offset}] (see BiomeDef.features).
var packs: Array = []

var _path := PackedVector2Array()
var _widths := PackedFloat32Array()
var _seed := 0
var road_heights := PackedFloat32Array()
## Biome under each road point: the paving matches the land it crosses.
var road_biomes := PackedInt32Array()
## Paved half width; a ragged edge of gravel runs ROAD_EDGE beyond it.
var road_width := 1.2
const ROAD_EDGE := 1.3
## biome id -> [paving, edge] blocks
const ROAD_PAVING := {
	Biomes.DESERT: [Blocks.SANDSTONE, Blocks.DESERT_ROCK], Biomes.DEEP_DESERT: [Blocks.SANDSTONE, Blocks.DESERT_ROCK],
	Biomes.FOSEN: [Blocks.PAVING, Blocks.FOSEN_ROCK], Biomes.BLUELAY: [Blocks.BLUE_ROCK, Blocks.GRAVEL],
	Biomes.DOOM: [Blocks.DOOM_ROCK, Blocks.OBSIDIAN], Biomes.DEEP_DARK: [Blocks.DEEP_SLATE, Blocks.DEEP_STONE],
}
# Ruins layout: half sizes, inner wall x, doorway positions, wall block.
var _half := Vector2i.ZERO
var _split := 0
var _doors := Vector2i.ZERO
var _wall_block := Blocks.RUIN_BRICK


static func create(p_type: String, p_center: Vector2i, p_required: bool, p_base_height: int,
		rng: RandomNumberGenerator, biome: BiomeDef = null) -> RealmFeature:
	var f := RealmFeature.new()
	var info: Array = TYPES[p_type]
	f.type = p_type
	f.display_name = info[0]
	f.radius = info[1]
	f.light_color = info[2]
	f.required = p_required
	f.center = p_center
	f.base_height = p_base_height
	f._seed = rng.randi()
	if biome:
		f._wall_block = biome.ruin_block
	if p_type == "ruins":
		f._half = Vector2i(rng.randi_range(5, 8), rng.randi_range(4, 6))
		f._split = rng.randi_range(-f._half.x + 3, f._half.x - 3)
		f._doors = Vector2i(rng.randi_range(-f._half.x + 2, f._half.x - 2), rng.randi_range(-f._half.y + 2, f._half.y - 2))
		f.radius = maxi(f._half.x, f._half.y) + 2
		var r := f._half + Vector2i(2, 2)
		f.bounds = Rect2i(p_center - r, r * 2 + Vector2i.ONE)
	elif p_type in PATH_TYPES:
		f._build_path(rng)
	else:
		f.bounds = Rect2i(p_center - Vector2i.ONE * ceili(f.radius), Vector2i.ONE * ceili(f.radius) * 2 + Vector2i.ONE)
	f._place_lights()
	return f


## A stretch of road along the given points (keep it short: ~20 blocks).
static func create_road(points: PackedVector2Array, p_seed: int, half_width := 1.2) -> RealmFeature:
	var f := RealmFeature.new()
	f.road_width = half_width
	f.type = "road"
	f.display_name = TYPES.road[0]
	f._seed = p_seed
	f._path = points
	for i in points.size():
		f._widths.append(1.2)
	f._fit_path_bounds()
	f.center = Vector2i(points[points.size() / 2].floor())
	return f


func is_structure() -> bool:
	return not type in PATH_TYPES


## Road points (for placing lampposts along them).
func path() -> PackedVector2Array:
	return _path


## Reshapes one terrain column. col = [height, top block (-1 = biome default),
## under block (-1), then extra segments as y0, y1, block, ...].
## Returns whether this feature covers the column.
func shape(x: int, z: int, col: Array) -> bool:
	if not bounds.has_point(Vector2i(x, z)):
		return false
	var p := Vector2(x + 0.5, z + 0.5)
	var c := Vector2(center) + Vector2(0.5, 0.5)
	var d := p.distance_to(c)
	var dx := absi(x - center.x)
	var dz := absi(z - center.y)
	var square := maxi(dx, dz)
	var h := base_height
	match type:
		"launchpad":
			# A paved landing circle on level ground, a rune ring where the ship
			# sets down, a low wall with a gap toward the city (north), and the
			# meadow eased back up to its own height around it.
			var blend := 10.0
			if d > radius + blend:
				return false
			if d > radius:
				col[0] = roundi(lerpf(h, float(col[0]), smoothstep(0.0, 1.0, (d - radius) / blend)))
				return true
			col[0] = h
			col[1] = Blocks.PAVING
			col[2] = Blocks.STONE
			var north := p.y < c.y and absf(p.x - c.x) < 4.0
			# The moored battleship lies east-west and runs out over the west
			# rim (SurfaceLaunchpad), so the wall opens for her there.
			var under_ship := p.x - c.x < -8.0 and p.y - c.y > -10.5
			if d > radius - 1.4 and not north and not under_ship:
				col.append_array([h + 1, h + 2, Blocks.RUIN_BRICK])
			elif absf(d - 14.0) < 0.6 or absf(d - 6.0) < 0.5:
				col[1] = Blocks.RUNE_BLUE
			elif d < 14.0 and (absf(p.x - c.x) < 0.6 or absf(p.y - c.y) < 0.6):
				col[1] = Blocks.OAK_PLANKS
		"woodland_lake":
			var edge := radius * (0.88 + sin(atan2(p.y - c.y, p.x - c.x) * 3 + _seed) * 0.08)
			if d > radius:
				return false
			col[0] = IslandGenerator.SEA_LEVEL - 3 if d < edge - 3 else IslandGenerator.SEA_LEVEL - 1 if d < edge else base_height
			col[1] = Blocks.SAND if d > edge - 4 else Blocks.SEAFLOOR
		"road":
			var near := _nearest(p)
			var outer := road_width + ROAD_EDGE
			if not road_heights.is_empty() and near.x < outer:
				var sample := near.z * (road_heights.size() - 1)
				var i := mini(floori(sample), road_heights.size() - 2)
				col[0] = roundi(lerpf(road_heights[i], road_heights[i + 1], sample - i))
			var blocks: Array = [Blocks.PAVING, Blocks.GRAVEL]
			if not road_biomes.is_empty():
				blocks = ROAD_PAVING.get(road_biomes[roundi(near.z * (road_biomes.size() - 1))], blocks)
			if near.x < road_width:
				col[1] = blocks[1] if _hash(x, z, 1) < 0.12 else blocks[0]
			elif near.x < outer and not (near.x > outer - 0.5 and _hash(x, z, 2) < 0.5):
				col[1] = blocks[1]  # ragged edges
			else:
				return false
		"ruins":
			var lx := x - center.x
			var lz := z - center.y
			var inside := absi(lx) <= _half.x and absi(lz) <= _half.y
			if inside:
				col[0] = h
				if _hash(x, z, 5) < 0.7:
					col[1] = Blocks.PAVING  # old floor, partly overgrown
				var wall := absi(lx) == _half.x or absi(lz) == _half.y or (lx == _split and absi(lz) < _half.y)
				var door := (lz == _half.y and absi(lx - _doors.x) <= 1) \
						or (lx == -_half.x and absi(lz - _doors.y) <= 1) \
						or (lx == _split and absi(lz) <= 1)
				if wall and not door:
					var wall_height := int(_hash(x, z, 6) * 4.6)  # 0 = collapsed, up to 4
					if wall_height > 0:
						col.append_array([h + 1, h + 1 + wall_height, _wall_block])
					else:
						col[1] = _wall_block
			elif _hash(x, z, 7) < 0.14:
				col.append_array([col[0] + 1, col[0] + 2, _wall_block])  # scattered rubble
			else:
				return false
		"lava_scar":
			var near := _nearest(p)
			var w: float = near.y
			if near.x < w:
				col[0] -= 1
				col[1] = Blocks.LAVA
				col[2] = Blocks.DOOM_ROCK
			elif near.x < w + 1.7:
				col[1] = Blocks.OBSIDIAN if _hash(x, z, 1) < 0.35 else Blocks.DOOM_ROCK
			else:
				return false
		"ravine":
			var near := _nearest(p)
			var w: float = near.y
			var t := near.z  # 0..1 along the ravine
			if near.x < w:
				var depth := 12.0 * pow(sin(t * PI), 0.5) * (1.0 - pow(near.x / w, 4.0))
				col[0] = maxi(IslandGenerator.SEA_LEVEL + 1, col[0] - int(depth))
				if depth > 3.0:
					col[1] = Blocks.ICE
				col[2] = Blocks.FOSEN_ROCK
			elif near.x < w + 1.5 and sin(t * PI) > 0.3:
				col[0] += 2  # raised, rocky rims make the walls steeper
				col[1] = Blocks.FOSEN_ROCK
			else:
				return false
		"glow_pool":
			var a := atan2(p.y - c.y, p.x - c.x)
			var edge := radius * (0.65 + 0.2 * sin(a * 3.0 + _seed % 7) + 0.1 * sin(a * 5.0 + _seed % 11))
			if d < edge:
				col[0] -= 1
				col[1] = Blocks.BLUE_GLOW
			elif d < edge + 1.2:
				col[1] = Blocks.BLUE_ROCK
			else:
				return false
		"ember_shrine":
			if d > radius:
				return false
			col[0] = h
			col[1] = Blocks.OBSIDIAN
			if d < 2.6:
				col[0] = h - 1
				col[1] = Blocks.LAVA
			elif d < 3.4:
				col.append_array([h + 1, h + 2, Blocks.DOOM_ROCK])
			for k in 8:
				var a := k * TAU / 8.0
				if p.distance_to(c + Vector2(cos(a), sin(a)) * 7.0) < 0.9:
					col.append_array([h + 1, h + 6, Blocks.OBSIDIAN, h + 6, h + 7, Blocks.EMBER])
		"frost_tower":
			if square > 6:
				return false
			col[0] = h
			col[1] = Blocks.FOSEN_ROCK
			if square == 4 and not (z > center.y and dx <= 1):  # walls with a doorway
				var top := h + 4 + int(_hash(x, z, 2) * 5.0)
				col.append_array([h + 1, top, Blocks.FOSEN_ROCK, top, top + 1, Blocks.SNOW])
		"crystal_spire":
			if d > radius:
				return false
			col[0] = h
			col[1] = Blocks.BLUE_ROCK
			if d < 2.8:
				col.append_array([h + 1, h + 1 + int(15.0 * (1.0 - d / 2.8)), Blocks.BLUE_GLOW])
			for k in 4:
				var a := k * TAU / 4.0 + PI / 4.0
				var ds := p.distance_to(c + Vector2(cos(a), sin(a)) * 5.0)
				if ds < 1.3:
					col.append_array([h + 1, h + 1 + int(6.0 * (1.0 - ds / 1.3)), Blocks.BLUE_GLOW])
		"tide_rocks":
			# A ring of jagged, barnacled rocks around a sandy hollow where
			# the crabs gather.
			if d > radius:
				return false
			col[0] = h - 1 if d < 3.5 else h
			col[1] = Blocks.SEAFLOOR if d < 3.5 else -1
			for k in 7:
				var a := k * TAU / 7.0 + _hash(k, 1, 6) * 0.5
				var rock := c + Vector2(cos(a), sin(a)) * (4.8 + _hash(k, 2, 6) * 1.2)
				var dr := p.distance_to(rock)
				var size := 1.0 + _hash(k, 3, 6) * 0.8
				if dr < size:
					col.append_array([h + 1, h + 2 + int((size - dr) * 2.5), Blocks.STONE])
		"stone_circle":
			if d > radius:
				return false
			col[0] = h
			if d < 1.2:
				col.append_array([h + 1, h + 2, Blocks.STONE])
			for k in 10:
				var a := k * TAU / 10.0
				if p.distance_to(c + Vector2(cos(a), sin(a)) * 6.0) < 0.75:
					col.append_array([h + 1, h + 3 + int(_hash(k, 0, 3) * 2.0), Blocks.STONE])
		"sunken_temple":
			if square > 9:
				return false
			col[1] = Blocks.SANDSTONE
			col[2] = Blocks.SANDSTONE
			col[0] = h - 2 if square <= 7 else (h - 1 if square == 8 else h)  # steps down
			if dx % 4 == 0 and dz % 4 == 0 and square <= 4 and square > 0:
				col.append_array([h - 1, h + 3, Blocks.SANDSTONE])
		"ziggurat":
			if square > 10:
				return false
			var level := clampi(10 - square, 0, 7)  # one block per ring = walkable steps
			col[0] = h + level
			col[1] = Blocks.JUNGLE_GRASS if level % 2 == 1 or _hash(x, z, 4) < 0.25 else Blocks.STONE
			col[2] = Blocks.STONE
			if square == 0:
				col.append_array([h + level + 1, h + level + 2, Blocks.WARM_GLOW])
	return true


## Covers the column? (Uses shape() on a scratch column.)
func covers(x: int, z: int) -> bool:
	return shape(x, z, [0, -1, -1])


# --- Paths (lava scars, ravines) ---------------------------------------------------

func _build_path(rng: RandomNumberGenerator) -> void:
	var steps := 28 if type == "lava_scar" else 34
	var step_len := 1.8 if type == "lava_scar" else 2.2
	var drift := 0.35 if type == "lava_scar" else 0.2
	var p := Vector2(center) - Vector2.from_angle(rng.randf() * TAU) * steps * step_len * 0.4
	var a := (Vector2(center) - p).angle()
	for i in steps:
		_path.append(p)
		var t := float(i) / (steps - 1)
		if type == "lava_scar":
			_widths.append(0.5 + 1.8 * sin(t * PI) * rng.randf_range(0.7, 1.1))
		else:
			_widths.append(2.2 + 1.2 * sin(t * PI))
		a += rng.randf_range(-drift, drift)
		p += Vector2.from_angle(a) * step_len
	_fit_path_bounds()


func _fit_path_bounds() -> void:
	var lo := _path[0]
	var hi := _path[0]
	for q in _path:
		lo = lo.min(q)
		hi = hi.max(q)
	var margin := 6
	bounds = Rect2i(Vector2i(lo.floor()) - Vector2i.ONE * margin, Vector2i((hi - lo).ceil()) + Vector2i.ONE * margin * 2)
	radius = (hi - lo).length() * 0.5


## (distance to the path, path width there, 0..1 position along it)
func _nearest(p: Vector2) -> Vector3:
	var best := Vector3(1e9, 0.0, 0.0)
	for i in _path.size() - 1:
		var a := _path[i]
		var b := _path[i + 1]
		var ab := b - a
		var s := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
		var d := p.distance_to(a + ab * s)
		if d < best.x:
			best = Vector3(d, lerpf(_widths[i], _widths[i + 1], s), (i + s) / (_path.size() - 1))
	return best


func _place_lights() -> void:
	if light_color == Color.BLACK:
		return
	match type:
		"launchpad":
			for k in 6:
				var a: float = k * TAU / 6.0 + 0.5
				light_spots.append(Vector3(center.x + 0.5 + cos(a) * 18.0, 4.0, center.y + 0.5 + sin(a) * 18.0))
		"lava_scar":
			for i in range(2, _path.size() - 2, 5):
				light_spots.append(Vector3(_path[i].x, 1.0, _path[i].y))
		"ember_shrine":
			light_spots.append(Vector3(center.x + 0.5, 1.5, center.y + 0.5))
			for k in [0, 2, 4, 6]:
				var a: float = k * TAU / 8.0
				light_spots.append(Vector3(center.x + 0.5 + cos(a) * 7.0, 7.5, center.y + 0.5 + sin(a) * 7.0))
		"crystal_spire":
			light_spots.append(Vector3(center.x + 0.5, 8.0, center.y + 0.5))
		"ziggurat":
			light_spots.append(Vector3(center.x + 0.5, 2.0, center.y + 0.5))
		_:
			light_spots.append(Vector3(center.x + 0.5, 2.0, center.y + 0.5))


func _hash(x: int, z: int, salt: int) -> float:
	var n := x * 374761393 + z * 668265263 + (_seed + salt * 1013) * 982451653
	n = (n ^ (n >> 13)) * 1274126177
	n = n ^ (n >> 16)
	return float(n & 0xFFFFFF) / float(0xFFFFFF)
