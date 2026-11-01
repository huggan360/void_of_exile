extends VoxelGeneratorScript
## Immutable, scene-authored brush snapshot; worker threads never touch nodes.
var brushes: Array[Dictionary] = []

func _get_used_channels_mask() -> int:
	return 1 << VoxelBuffer.CHANNEL_TYPE

func _generate_block(buffer: VoxelBuffer, origin: Vector3i, lod: int) -> void:
	if lod != 0:
		return
	var chunk := AABB(Vector3(origin), Vector3(buffer.get_size()))
	for brush in brushes:
		var bounds: AABB = brush.bounds
		if not chunk.intersects(bounds):
			continue
		var a := Vector3i(bounds.position.max(chunk.position)) - origin
		var b := Vector3i(bounds.end.min(chunk.end)) - origin
		if brush.checker:
			for z in range(a.z, b.z):
				for x in range(a.x, b.x):
					var white := posmod(floori(float(x + origin.x) / 3.0) + floori(float(z + origin.z) / 3.0), 2) == 0
					buffer.fill_area(Blocks.CASTLE_MARBLE if white else Blocks.CASTLE_STONE, Vector3i(x, a.y, z), Vector3i(x + 1, b.y, z + 1), VoxelBuffer.CHANNEL_TYPE)
		else:
			buffer.fill_area(brush.block, a, b, VoxelBuffer.CHANNEL_TYPE)
