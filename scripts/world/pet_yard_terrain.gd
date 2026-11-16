class_name PetYardTerrain
extends VoxelGeneratorScript
## The Pet Yard island in the Surface's 0.25 m voxels and blocks (the terrain
## node is scaled by 1/4, so this works in voxels). Each column's top and
## block come from PetYardWorld.column(); below the top a few voxels of soil
## (sand under sand), then rock. The bridge's planks are a deck over the pond.

func _get_used_channels_mask() -> int:
	return 1 << VoxelBuffer.CHANNEL_TYPE


func _generate_block(buf: VoxelBuffer, origin: Vector3i, lod: int) -> void:
	if lod != 0: return
	var size := buf.get_size()
	for lz in size.z:
		for lx in size.x:
			var x := (origin.x + lx + 0.5) * 0.25
			var z := (origin.z + lz + 0.5) * 0.25
			var c := PetYardWorld.column(x, z)
			var top := c.x
			var block := c.y
			if block == SurfaceBlocks.PLANKS and PetYardWorld.on_bridge(x, z):
				# The pond's bed under the deck, the planks on top.
				_fill(buf, origin, lx, lz, -48, -5, SurfaceBlocks.STRATA_GREY)
				_fill(buf, origin, lx, lz, -5, -4, SurfaceBlocks.RIVERBED)
				_fill(buf, origin, lx, lz, -1, 0, SurfaceBlocks.PLANKS)
				continue
			var sandy := block in [SurfaceBlocks.SAND_FINE, SurfaceBlocks.SEAFLOOR_FINE, SurfaceBlocks.RIVERBED]
			_fill(buf, origin, lx, lz, -48, top - 5, SurfaceBlocks.STRATA_GREY)
			_fill(buf, origin, lx, lz, top - 5, top - 1, SurfaceBlocks.SAND_FINE if sandy else SurfaceBlocks.SOIL)
			_fill(buf, origin, lx, lz, top - 1, top, block)


func _fill(buf: VoxelBuffer, origin: Vector3i, x: int, z: int, low: int, high: int, block: int) -> void:
	var a := clampi(low - origin.y, 0, buf.get_size().y)
	var b := clampi(high - origin.y, 0, buf.get_size().y)
	if a < b: buf.fill_area(block, Vector3i(x, a, z), Vector3i(x + 1, b, z + 1), VoxelBuffer.CHANNEL_TYPE)
