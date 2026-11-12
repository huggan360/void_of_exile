class_name ObstacleLibrary
## Loads obstacle prefabs (obstacles/*.vox, made by tools/make_obstacles.py)
## once and caches everything derived from them: per-biome recolored meshes,
## the voxel list used for debris, and collision boxes.
##
## Voxels in the GLOW slot get their own glowing mesh (lanterns, embers, caps).
## Prefabs named decor_* are small, non-blocking ground clutter.

const VOXEL_SIZE := 0.25
const DECOR_VOXEL_SIZE := 0.125
const DIR := "res://obstacles/"
const GLOW_SLOT := 7
## Only voxels below this height (meters) block movement, so tree trunks
## collide but their canopies don't.
const COLLISION_HEIGHT := 1.5


class Prefab:
	var prefab_name := ""
	var voxel_size := VOXEL_SIZE
	var size := Vector3i.ZERO  # in voxels
	var height := 0.0  # meters
	var footprint := Vector2.ZERO  # meters, x/z
	var has_glow := false
	var hp := 1
	## Voxel centers in local meters (origin = base center) and their color slots.
	var voxel_positions := PackedVector3Array()
	var voxel_slots := PackedByteArray()
	var collision_boxes: Array[AABB] = []
	var _base_buffer: VoxelBuffer  # everything except glow voxels
	var _glow_buffer: VoxelBuffer  # only glow voxels
	var _palette: VoxelColorPalette
	var _meshes := {}  # biome id -> [base mesh or null, glow mesh or null]
	var _lods := {}  # biome id -> coarse mesh

	func is_decor() -> bool:
		return prefab_name.get_file().begins_with("decor_")

	## Small things drawn at half the voxel size (the Surface's fine_* stones,
	## reeds, mushrooms).
	func is_fine() -> bool:
		return is_decor() or prefab_name.get_file().begins_with("fine_")

	## A palette slot's colour in `biome`: the biome's obstacle colours
	## cover the low slots, the prefab's own palette the rest (the Surface
	## models use more slots than a biome lists).
	func slot_color(slot: int, biome: BiomeDef) -> Color:
		if slot >= 1 and slot < biome.obstacle_colors.size(): return biome.obstacle_colors[slot]
		return _palette.get_color(slot)

	## [base mesh, glow mesh] with the slots filled in from a biome's colors.
	func meshes_for(biome: BiomeDef) -> Array:
		if not _meshes.has(biome.id):
			# Keep slot 0 (empty) from the file; recolor the rest.
			var palette: VoxelColorPalette = _palette.duplicate()
			for slot in range(1, biome.obstacle_colors.size()):
				palette.set_color(slot, biome.obstacle_colors[slot])
			# Kept on disk per prefab and biome colours (VoxModel.cached).
			var source := DIR + prefab_name + ".vox"
			var colors := str(biome.id)+":"+str(Array(biome.obstacle_colors).map(func(c: Color) -> String: return c.to_html()))
			var base := VoxModel.cached("%s|base|%s" % [source, colors], source, func() -> Mesh: return VoxModel.mesh_from_buffer(_base_buffer, palette)) if voxel_positions.size() > 0 else null
			var glow := VoxModel.cached("%s|glow|%s" % [source, colors], source, func() -> Mesh: return VoxModel.mesh_from_buffer(_glow_buffer, palette)) if has_glow else null
			_meshes[biome.id] = [base, glow]
		return _meshes[biome.id]

	## A coarse copy for distant trees: voxels twice as big (2 x 2 x 2 merged),
	## one mesh with the glow voxels in their colour. Draw it at voxel_size * 2.
	func lod_mesh_for(biome: BiomeDef) -> Mesh:
		if _lods.has(biome.id): return _lods[biome.id]
		var palette: VoxelColorPalette = _palette.duplicate()
		for slot in range(1, biome.obstacle_colors.size()):
			palette.set_color(slot, biome.obstacle_colors[slot])
		var source := DIR + prefab_name + ".vox"
		var colors := str(biome.id)+":"+str(Array(biome.obstacle_colors).map(func(c: Color) -> String: return c.to_html()))
		_lods[biome.id] = VoxModel.cached("%s|lod|%s" % [source, colors], source, func() -> Mesh: return VoxModel.mesh_from_buffer(_coarse(), palette))
		return _lods[biome.id]

	func _coarse() -> VoxelBuffer:
		var half := Vector3i((size.x + 1) / 2, (size.y + 1) / 2, (size.z + 1) / 2)
		var out := VoxelBuffer.new()
		out.create(half.x, half.y, half.z)
		for i in voxel_positions.size():
			var v := Vector3i(((voxel_positions[i] - mesh_offset()) / voxel_size).floor()) / 2
			if out.get_voxel(v.x, v.y, v.z, VoxelBuffer.CHANNEL_COLOR) == 0:
				out.set_voxel(voxel_slots[i], v.x, v.y, v.z, VoxelBuffer.CHANNEL_COLOR)
		return out

	## Local offset to place the mesh so the prefab is centered on its origin.
	func mesh_offset() -> Vector3:
		return Vector3(-size.x * 0.5, 0, -size.z * 0.5) * voxel_size


static var _cache := {}


static func get_prefab(prefab_name: String) -> Prefab:
	if _cache.has(prefab_name):
		return _cache[prefab_name]
	var data := VoxModel.load_vox(DIR + prefab_name + ".vox")
	var p := Prefab.new()
	p.prefab_name = prefab_name
	p.voxel_size = DECOR_VOXEL_SIZE if p.is_fine() else VOXEL_SIZE
	var buffer: VoxelBuffer = data[0]
	p._palette = data[1]
	p.size = buffer.get_size()
	p.height = p.size.y * p.voxel_size
	p.footprint = Vector2(p.size.x, p.size.z) * p.voxel_size
	_split_glow(p, buffer)
	_read_voxels(p, buffer)
	p.hp = clampi(p.voxel_positions.size() / 120, 2, 14)
	if not p.is_fine():
		_build_collision(p, buffer)
	_cache[prefab_name] = p
	return p


static func _split_glow(p: Prefab, buffer: VoxelBuffer) -> void:
	p._base_buffer = VoxelBuffer.new()
	p._glow_buffer = VoxelBuffer.new()
	p._base_buffer.create(p.size.x, p.size.y, p.size.z)
	p._glow_buffer.create(p.size.x, p.size.y, p.size.z)
	for y in p.size.y:
		for z in p.size.z:
			for x in p.size.x:
				var slot := buffer.get_voxel(x, y, z, VoxelBuffer.CHANNEL_COLOR)
				if slot == GLOW_SLOT:
					p._glow_buffer.set_voxel(slot, x, y, z, VoxelBuffer.CHANNEL_COLOR)
					p.has_glow = true
				elif slot != 0:
					p._base_buffer.set_voxel(slot, x, y, z, VoxelBuffer.CHANNEL_COLOR)


static func _read_voxels(p: Prefab, buffer: VoxelBuffer) -> void:
	var offset := p.mesh_offset() + Vector3.ONE * p.voxel_size * 0.5
	for y in p.size.y:
		for z in p.size.z:
			for x in p.size.x:
				var slot := buffer.get_voxel(x, y, z, VoxelBuffer.CHANNEL_COLOR)
				if slot != 0:
					p.voxel_positions.append(Vector3(x, y, z) * p.voxel_size + offset)
					p.voxel_slots.append(slot)


## Merges the low voxels' footprint into a few boxes (greedy rectangles).
static func _build_collision(p: Prefab, buffer: VoxelBuffer) -> void:
	var low_rows := ceili(COLLISION_HEIGHT / p.voxel_size)
	var solid := {}
	for y in mini(low_rows, p.size.y):
		for z in p.size.z:
			for x in p.size.x:
				if buffer.get_voxel(x, y, z, VoxelBuffer.CHANNEL_COLOR) != 0:
					solid[Vector2i(x, z)] = true
	var used := {}
	for z in p.size.z:
		for x in p.size.x:
			var start := Vector2i(x, z)
			if not solid.has(start) or used.has(start):
				continue
			var x1 := x
			while solid.has(Vector2i(x1 + 1, z)) and not used.has(Vector2i(x1 + 1, z)):
				x1 += 1
			var z1 := z
			while _row_free(solid, used, x, x1, z1 + 1):
				z1 += 1
			for zz in range(z, z1 + 1):
				for xx in range(x, x1 + 1):
					used[Vector2i(xx, zz)] = true
			var min_corner := Vector3(x, 0, z) * p.voxel_size + p.mesh_offset()
			var box_size := Vector3(x1 - x + 1, 0, z1 - z + 1) * p.voxel_size
			box_size.y = p.height
			p.collision_boxes.append(AABB(min_corner, box_size))


static func _row_free(solid: Dictionary, used: Dictionary, x0: int, x1: int, z: int) -> bool:
	for x in range(x0, x1 + 1):
		var c := Vector2i(x, z)
		if not solid.has(c) or used.has(c):
			return false
	return true
