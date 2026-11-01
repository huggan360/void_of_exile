class_name DungeonGenerator
extends VoxelGeneratorScript
var layout: DungeonLayout
var theme: Dictionary  # Dungeons.THEMES entry: floor / wall blocks, lava crack block
var moss_noise := FastNoiseLite.new()
var strata_noise := FastNoiseLite.new()

func _init(p_layout: DungeonLayout, p_theme: Dictionary = Dungeons.THEMES.moss_cave) -> void:
	layout = p_layout
	theme = p_theme
	moss_noise.seed = int(layout.seed_value)
	moss_noise.frequency = 0.12
	moss_noise.fractal_octaves = 2
	strata_noise.seed = int(layout.seed_value) + 391
	strata_noise.frequency = 0.24

func _get_used_channels_mask() -> int:
	return 1 << VoxelBuffer.CHANNEL_TYPE

func _generate_block(buffer: VoxelBuffer, origin: Vector3i, lod: int) -> void:
	if lod != 0: return
	var size := buffer.get_size()
	for z in size.z:
		for x in size.x:
			var wx := origin.x + x
			var wz := origin.z + z
			var passage := layout.open(wx, wz)
			var moss := moss_noise.get_noise_2d(wx, wz) > 0.22
			var strata := strata_noise.get_noise_2d(wx, wz)
			var top := 1 if passage else layout.wall_height
			for y in size.y:
				var wy := origin.y + y
				if wy < top:
					var floors: Array = theme.floor
					var walls: Array = theme.wall
					var block: int = walls[0]
					if wy >= -1:
						if passage:
							block = floors[2] if moss else floors[1] if strata < -0.18 else floors[0]
							if theme.has("crack") and wy == 0 and layout.is_crack(wx, wz):
								block = theme.crack
						else:
							var growth := moss_noise.get_noise_3d(wx, wy * 0.7, wz)
							block = walls[2] if growth > 0.12 else walls[1] if strata > 0.0 else walls[0]
					buffer.set_voxel(block, x, y, z, VoxelBuffer.CHANNEL_TYPE)
