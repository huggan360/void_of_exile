class_name VoxModel
## Loads MagicaVoxel .vox files and turns them into meshes. Meshing is the
## slow part and gives the same mesh every time, so each one is made once and
## kept on disk (user://cache/vox/, see cached()): later starts, the server
## and singleplayer just load it. Editing a model or updating the game makes
## it anew.

## Bump when the mesher or how meshes are built changes (old files are skipped).
const CACHE_VERSION := 1
const CACHE_DIR := "user://cache/vox/"
static var _material: ShaderMaterial
static var _glow_material: ShaderMaterial
static var _memory := {}
static var _lock := Mutex.new()


## The mesh for `key` (what it is: a path, plus its colours if recoloured),
## built by `build` only if no copy is kept for this version of `source` (the
## .vox it comes from) and of the game. Safe from loading threads.
static func cached(key: String, source: String, build: Callable) -> Mesh:
	var stamp := FileAccess.get_modified_time(source) if source != "" and FileAccess.file_exists(source) else 0
	var id := ("%s|%d|%d|%s" % [key, stamp, CACHE_VERSION, Net.VERSION]).md5_text()
	_lock.lock()
	var known: Mesh = _memory.get(id)
	_lock.unlock()
	if known:
		return known
	var file := CACHE_DIR + id + ".res"
	var mesh: Mesh = null
	if FileAccess.file_exists(file):
		mesh = ResourceLoader.load(file, "Mesh", ResourceLoader.CACHE_MODE_IGNORE) as Mesh
	if mesh == null:
		mesh = build.call()
		if mesh != null:
			DirAccess.make_dir_recursive_absolute(CACHE_DIR)
			ResourceSaver.save(mesh, file, ResourceSaver.FLAG_COMPRESS)
	if mesh != null:
		_lock.lock()
		_memory[id] = mesh
		_lock.unlock()
	return mesh


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
	return cached(path, path, func() -> Mesh:
		var data := load_vox(path)
		return mesh_from_buffer(data[0], data[1]) if data else null)


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
