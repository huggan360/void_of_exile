class_name FineDungeonGenerator
extends VoxelGeneratorScript
## Dungeon terrain in the Surface's 0.25 m voxels and blocks (SurfaceBlocks;
## the terrain node is scaled by 1 / FINE, so this works in voxels).
##
## The rooms stay DungeonLayout's 1 m grid, so walking, spawning and the map
## don't change. Walls follow a smoothed outline of that grid with a little
## noise: caves get rounded corners, uneven faces and rock that climbs away from
## the room in ledges; built halls (`round = false`) keep straight walls.
##
## The look comes from the theme's `fine` entry (Dungeons.THEMES):
##   floor   [main, second, third] blocks, picked by noise
##   wall    [main, second] blocks; top: the block on wall tops; foot: optional
##           block at the foot of walls (moss, snowdrifts)
##   pool    optional block for flat pools in rooms; rug: optional carpet down
##           the middle of halls; crack: block for the layout's lava cracks
##   round   rounded cave walls (true) or built ones; jitter: how much noise
##           moves the walls (m); slope: how low a cave wall's face starts
##           (share of its height); top_jitter: wall-top variation in voxels

const FINE := 4
const FLOOR := 4  # floor voxels: the floor's top is at 1 m, like the old dungeons
const DEPTH := 8  # voxels of floor below 0

var layout: DungeonLayout
var spec: Dictionary
var _open := PackedFloat32Array()
var _min := Vector2i.ZERO
var _size := Vector2i.ZERO
var _wall_top := 24
var _noise := FastNoiseLite.new()
var _detail := FastNoiseLite.new()
var _pools := FastNoiseLite.new()


func _init(p_layout: DungeonLayout, theme: Dictionary) -> void:
	layout = p_layout
	spec = theme.get("fine", {})
	_wall_top = layout.wall_height * FINE
	_noise.seed = layout.seed_value + 11
	_noise.frequency = 0.045
	_noise.fractal_octaves = 3
	_detail.seed = layout.seed_value + 23
	_detail.frequency = 0.21
	_pools.seed = layout.seed_value + 37
	_pools.frequency = 0.035
	# How open each meter is, averaged with its neighbours: the walls are
	# traced where it crosses one half.
	var e := layout.extent + 3
	_min = Vector2i(-e, -e)
	_size = Vector2i(e * 2 + 1, e * 2 + 1)
	var raw := PackedFloat32Array()
	raw.resize(_size.x * _size.y)
	for cell: Vector2i in layout.floor_cells:
		var i := cell - _min
		if i.x >= 0 and i.y >= 0 and i.x < _size.x and i.y < _size.y:
			raw[i.y * _size.x + i.x] = 1.0
	if not bool(spec.get("round", true)):
		_open = raw
		return
	_open.resize(raw.size())
	for z in range(1, _size.y - 1):
		for x in range(1, _size.x - 1):
			var sum := 0.0
			for dz in [-1, 0, 1]:
				for dx in [-1, 0, 1]:
					sum += raw[(z + dz) * _size.x + x + dx]
			_open[z * _size.x + x] = sum / 9.0


func _get_used_channels_mask() -> int:
	return 1 << VoxelBuffer.CHANNEL_TYPE


## 0 deep in rock, 1 in the middle of a room (meters, bilinear between cell centers).
func openness(x: float, z: float) -> float:
	var fx := x - 0.5 - _min.x
	var fz := z - 0.5 - _min.y
	var ix := floori(fx)
	var iz := floori(fz)
	if ix < 0 or iz < 0 or ix >= _size.x - 1 or iz >= _size.y - 1:
		return 0.0
	var tx := fx - ix
	var tz := fz - iz
	var row := iz * _size.x
	var a := lerpf(_open[row + ix], _open[row + ix + 1], tx)
	var b := lerpf(_open[row + _size.x + ix], _open[row + _size.x + ix + 1], tx)
	return lerpf(a, b, tz)


func _generate_block(buffer: VoxelBuffer, origin: Vector3i, lod: int) -> void:
	if lod != 0: return
	var size := buffer.get_size()
	var y0 := origin.y
	var y1 := origin.y + size.y
	if y1 <= -DEPTH or y0 >= _wall_top + 12:
		return
	var floors: Array = spec.get("floor", [SurfaceBlocks.SOIL])
	var walls: Array = spec.get("wall", [SurfaceBlocks.STRATA_GREY])
	var top_block: int = spec.get("top", walls[0])
	var foot: int = spec.get("foot", -1)
	var pool: int = spec.get("pool", -1)
	var rug: int = spec.get("rug", -1)
	var crack: int = spec.get("crack", -1)
	var jitter: float = spec.get("jitter", 0.12)
	var slope: float = spec.get("slope", 0.6)
	var top_jitter: float = spec.get("top_jitter", 3.0)
	var round_walls: bool = spec.get("round", true)
	for z in size.z:
		for x in size.x:
			var vx := origin.x + x
			var vz := origin.z + z
			var mx := (vx + 0.5) / FINE
			var mz := (vz + 0.5) / FINE
			var shape := _noise.get_noise_2d(vx, vz)
			var v := openness(mx, mz) + shape * jitter
			var block: int
			var top: int
			if v >= 0.5:
				# Floor.
				top = FLOOR
				var pick := _detail.get_noise_2d(vx, vz) + shape * 0.6
				block = floors[0] if pick < 0.18 else floors[1 % floors.size()] if pick < 0.42 else floors[2 % floors.size()]
				if pool >= 0 and v > 0.85 and _pools.get_noise_2d(vx, vz) > 0.42:
					block = pool
				if rug >= 0 and _on_rug(mx, mz):
					block = rug
				if crack >= 0 and layout.is_crack(floori(mx), floori(mz)) and absf(_detail.get_noise_2d(vx * 0.6, vz * 0.6)) < 0.35:
					block = crack
				_fill(buffer, x, z, y0, y1, -DEPTH, top, block)
			else:
				# Wall: the face starts lower on caves and climbs into the rock.
				var into := clampf((0.5 - v) * 4.0, 0.0, 1.0)
				var height := float(_wall_top) * (lerpf(slope, 1.0, into) if round_walls else 1.0)
				top = int(height + _detail.get_noise_2d(vx * 0.5, vz * 0.5) * top_jitter)
				top = maxi(top, FLOOR + 4)
				block = walls[0] if shape < 0.15 else walls[1 % walls.size()]
				_fill(buffer, x, z, y0, y1, -DEPTH, top - 1, block)
				_fill(buffer, x, z, y0, y1, top - 1, top, top_block)
				if foot >= 0 and into < 0.25:
					_fill(buffer, x, z, y0, y1, FLOOR, FLOOR + 2 + int(absf(shape) * 6.0), foot)


func _fill(buffer: VoxelBuffer, x: int, z: int, y0: int, y1: int, from: int, to: int, block: int) -> void:
	var a := maxi(from, y0)
	var b := mini(to, y1)
	if b <= a: return
	buffer.fill_area(block, Vector3i(x, a - y0, z), Vector3i(x + 1, b - y0, z + 1), VoxelBuffer.CHANNEL_TYPE)


## A strip of carpet down the middle of each big hall, along its long side.
func _on_rug(x: float, z: float) -> bool:
	for room: Dictionary in layout.rooms:
		var c: Vector2i = room.center
		var r := float(room.radius)
		if r < 7.0: continue
		var dx := x - c.x - 0.5
		var dz := z - c.y - 0.5
		if absf(dz) < r - 1.5 and absf(dx) < 1.25: return true
	return false
