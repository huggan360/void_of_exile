class_name HallGenerator
extends VoxelGeneratorScript
## Voxel ground of the fixed home island. No seed or randomized layout: the
## shape and paving come from the editable Tavern scene (see HomeTerrain).
const FLOOR := HomeTerrain.FLOOR
const SEAFLOOR := HomeTerrain.SEAFLOOR

var terrain: HomeTerrain


func _init(p_terrain: HomeTerrain) -> void:
	terrain = p_terrain


func _get_used_channels_mask() -> int:
	return 1 << VoxelBuffer.CHANNEL_TYPE


func _generate_block(out_buffer: VoxelBuffer, origin: Vector3i, lod: int) -> void:
	if lod != 0 or origin.y > FLOOR + 2 or origin.y + out_buffer.get_size().y <= 0:
		return
	var size := out_buffer.get_size()
	for lz in size.z:
		for lx in size.x:
			_generate_column(out_buffer, origin, lx, lz)


func _generate_column(buf: VoxelBuffer, origin: Vector3i, lx: int, lz: int) -> void:
	var x := origin.x + lx
	var z := origin.z + lz
	var h := terrain.top_y(x, z)
	if h <= HomeTerrain.VOID: return  # sky
	var surface := terrain.block(x, z)
	var under := Blocks.SAND if surface in [Blocks.SAND, Blocks.SEAFLOOR] else Blocks.DIRT
	_fill(buf, origin, lx, lz, 0, h - 2, Blocks.STONE)
	_fill(buf, origin, lx, lz, h - 2, h, under)
	_fill(buf, origin, lx, lz, h, h + 1, surface)
	var i := terrain.index(x, z)
	if i >= 0 and terrain.deck[i] > 0:
		if terrain.deck[i] == HomeTerrain.PIER_POST:
			_fill(buf, origin, lx, lz, h + 1, HomeTerrain.BEACH, Blocks.TIMBER)
		_fill(buf, origin, lx, lz, HomeTerrain.BEACH, HomeTerrain.BEACH + 1, Blocks.TIMBER)


func _fill(buf: VoxelBuffer, origin: Vector3i, lx: int, lz: int, y0: int, y1: int, value: int) -> void:
	var sy := buf.get_size().y
	var a := clampi(y0 - origin.y, 0, sy)
	var b := clampi(y1 - origin.y, 0, sy)
	if a < b:
		buf.fill_area(value, Vector3i(lx, a, lz), Vector3i(lx + 1, b, lz + 1), VoxelBuffer.CHANNEL_TYPE)
