class_name VoxModel
## Loads MagicaVoxel .vox files and turns them into meshes at runtime.

static var _material: ShaderMaterial
static var _glow_material: ShaderMaterial


## Returns [VoxelBuffer, VoxelColorPalette], or [] on failure. Voxel values are
## the file's palette indices.
static func load_vox(path: String) -> Array:
	var buf := VoxelBuffer.new()
	var palette := VoxelColorPalette.new()
	var err := VoxelVoxLoader.load_from_file(
			path, buf, palette, VoxelBuffer.CHANNEL_COLOR)
	if err != OK:
		push_error("Could not load %s (error %d)" % [path, err])
		return []
	return [buf, palette]


static func mesh_from_buffer(buf: VoxelBuffer, palette: VoxelColorPalette) -> Mesh:
	# The mesher needs one voxel of empty padding around the model.
	var size := buf.get_size()
	var padded := VoxelBuffer.new()
	padded.create(size.x + 2, size.y + 2, size.z + 2)
	padded.copy_channel_from_area(buf, Vector3i.ZERO, size, Vector3i.ONE, VoxelBuffer.CHANNEL_COLOR)
	var mesher := VoxelMesherCubes.new()
	mesher.color_mode = VoxelMesherCubes.COLOR_MESHER_PALETTE
	mesher.palette = palette
	return mesher.build_mesh(padded, [], {})


static func load_mesh(path: String) -> Mesh:
	var data := load_vox(path)
	return mesh_from_buffer(data[0], data[1]) if data else null


## Shared material: palette colors with a slight per-voxel variation.
static func material() -> ShaderMaterial:
	if _material == null:
		_material = ShaderMaterial.new()
		_material.shader = preload("res://shaders/voxel_model.gdshader")
	return _material


## Like material(), but the colors glow (crystals, runes, glowing mushrooms).
static func glow_material() -> ShaderMaterial:
	if _glow_material == null:
		_glow_material = ShaderMaterial.new()
		_glow_material.shader = preload("res://shaders/voxel_model.gdshader")
		_glow_material.set_shader_parameter("glow_strength", 3.0)
	return _glow_material
