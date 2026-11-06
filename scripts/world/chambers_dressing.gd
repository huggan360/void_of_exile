extends Node3D
## Cathedral furniture and churchyard scenery, grouped into MultiMeshes.
## Only the furniture envelopes collide; the churchyard is never walkable.

const STONE := Color("b4aa96")
const PALE := Color("d6ceba")
const DARK_STONE := Color("706c65")
const WOOD := Color("63432e")
const WOOD_EDGE := Color("8c623b")
const GOLD := Color("bd934c")
const IRON := Color("343a40")
const WAX := Color("f2dfb0")
const GLASS := [Color("467cae"), Color("be4d63"), Color("dbac54"), Color("5c9a8f")]

var _boxes := {}
var _colors := {}
var _rng := RandomNumberGenerator.new()


func build(world) -> void:
	_rng.seed = 107031
	var bodies := StaticBody3D.new()
	bodies.name = "FurnitureCollision"
	bodies.collision_layer = Player.OBSTACLE_LAYER
	bodies.collision_mask = 0
	add_child(bodies)
	for entry: Array in world.furnishing_layout():
		var kind: String = entry[0]
		var at: Vector3 = entry[1]
		var size: Vector3 = entry[2]
		if kind == "portal_pillar":
			continue
		var collider := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		collider.shape = shape
		collider.position = at + Vector3.UP * size.y * 0.5
		bodies.add_child(collider)
		match kind:
			"column": _column(at)
			"pew": _pew(at, size.x)
			"candle": _candelabrum(at)
			"altar": _altar(at)
			"cross": _altar_cross(at)
			"lectern": _lectern(at)
	var steps: Array[Callable] = [_arcades,_windows.bind(world.terrain.generator),_wall_details,_chandeliers,
		_chest_inlays.bind(world.chest_layout(120)),_churchyard,_flush_boxes]
	for step in steps:
		if world.get_meta("asynchronous_load",false): world.queue_load_step(step)
		else: step.call()


func _column(at: Vector3) -> void:
	_box("stone", at + Vector3(0, 0.13, 0), Vector3(1.6, 0.26, 1.6), DARK_STONE)
	_box("stone", at + Vector3(0, 0.36, 0), Vector3(1.35, 0.2, 1.35), PALE)
	_box("stone", at + Vector3(0, 3.3, 0), Vector3(0.95, 5.7, 0.95), STONE)
	for side in [-1.0, 1.0]:
		_box("stone", at + Vector3(side * 0.51, 3.25, 0), Vector3(0.18, 5.55, 0.62), PALE)
		_box("stone", at + Vector3(0, 3.25, side * 0.51), Vector3(0.62, 5.55, 0.18), PALE)
	for y in [0.6, 5.8, 6.05]:
		_box("stone", at + Vector3(0, y, 0), Vector3(1.24, 0.16, 1.24), DARK_STONE if y == 5.8 else PALE)
	_box("stone", at + Vector3(0, 6.3, 0), Vector3(1.6, 0.36, 1.6), PALE)
	_box("stone", at + Vector3(0, 6.64, 0), Vector3(1.3, 0.3, 1.3), STONE)
	_box("brass", at + Vector3(0, 6.9, 0), Vector3(0.48, 0.22, 0.48), GOLD)
	# Side-facing candle brackets keep the main aisle visually open.
	var inward := -signf(at.x)
	_box("iron", at + Vector3(inward * 0.7, 2.7, 0), Vector3(0.45, 0.15, 0.3), IRON)
	_candle(at + Vector3(inward * 0.83, 2.8, 0), 0.38)


func _arcades() -> void:
	# Thin pointed arches along the two column rows, leaving the nave open.
	for side in [-1.0, 1.0]:
		for z in [8.0, 0.0, -8.0, -16.0]:
			for step in range(-8, 9):
				var offset := step * 0.5
				var outer := minf(4.0, absf(offset) + 0.25)
				var inner := maxf(0.0, absf(offset) - 0.25)
				var lower := 6.4 + sqrt(maxf(0.0, 64.0 - pow(4.0 + outer, 2))) / sqrt(48.0) * 2.2
				var upper := 6.4 + sqrt(maxf(0.0, 64.0 - pow(4.0 + inner, 2))) / sqrt(48.0) * 2.2
				var at := Vector3(side * 7.6, (lower + upper) * 0.5, z + offset)
				_box("stone", at, Vector3(0.42, upper - lower + 0.4, 0.55), PALE)
				_box("stone", Vector3(side * 7.65, upper + 0.28, z + offset), Vector3(0.44, 0.16, 0.55), STONE)
			_box("brass", Vector3(side * 7.6, 8.6, z), Vector3(0.48, 0.55, 0.32), GOLD)


func _pew(at: Vector3, width: float) -> void:
	_box("wood", at + Vector3(0, 0.54, 0), Vector3(width, 0.22, 0.88), WOOD_EDGE)
	_box("wood", at + Vector3(0, 0.97, 0.43), Vector3(width, 0.76, 0.22), WOOD)
	_box("wood", at + Vector3(0, 1.32, 0.43), Vector3(width, 0.09, 0.24), WOOD_EDGE)
	for side in [-1.0, 1.0]:
		_box("wood", at + Vector3(side * (width * 0.5 - 0.16), 0.63, 0), Vector3(0.26, 1.26, 1.1), WOOD)
		_box("brass", at + Vector3(side * (width * 0.5 - 0.16), 1.26, 0.37), Vector3(0.28, 0.08, 0.3), GOLD)
	for x in [-1.0, 0.0, 1.0]:
		_box("wood", at + Vector3(x, 0.95, 0.565), Vector3(0.11, 0.5, 0.04), WOOD_EDGE)
	_box("wood", at + Vector3(0, 0.17, -0.38), Vector3(width - 0.5, 0.16, 0.22), WOOD)


func _candle(at: Vector3, height := 0.4) -> void:
	_box("brass", at + Vector3(0, 0.025, 0), Vector3(0.23, 0.05, 0.23), GOLD)
	_box("wax", at + Vector3(0, height * 0.5 + 0.05, 0), Vector3(0.14, height, 0.14), WAX)
	_box("flame", at + Vector3(0, height + 0.14, 0), Vector3(0.1, 0.18, 0.1), Color("ffce76"))
	_box("flame", at + Vector3(0, height + 0.25, 0), Vector3(0.05, 0.07, 0.05), Color("fff1c3"))


func _candelabrum(at: Vector3) -> void:
	_box("iron", at + Vector3(0, 0.08, 0), Vector3(0.5, 0.16, 0.5), IRON)
	_box("brass", at + Vector3(0, 0.95, 0), Vector3(0.14, 1.75, 0.14), GOLD)
	_box("brass", at + Vector3(0, 1.67, 0), Vector3(0.86, 0.1, 0.1), GOLD)
	for x in [-0.35, 0.0, 0.35]:
		_candle(at + Vector3(x, 1.72, 0), 0.3 if x != 0 else 0.48)


func _altar(at: Vector3) -> void:
	_box("stone", at + Vector3(0, 0.12, 0), Vector3(6.4, 0.24, 1.8), DARK_STONE)
	_box("stone", at + Vector3(0, 0.32, 0), Vector3(6.0, 0.16, 1.5), PALE)
	for x in [-2.3, 2.3]:
		_box("stone", at + Vector3(x, 0.92, 0), Vector3(0.65, 1.08, 1.05), STONE)
	_box("stone", at + Vector3(0, 1.42, 0), Vector3(6.2, 0.25, 1.65), PALE)
	_box("cloth", at + Vector3(0, 1.57, 0), Vector3(3.6, 0.045, 1.67), Color("8e2431"))
	_box("cloth", at + Vector3(0, 1.12, 0.85), Vector3(3.6, 0.9, 0.055), Color("8e2431"))
	_box("brass", at + Vector3(0, 1.1, 0.89), Vector3(0.12, 0.5, 0.04), GOLD)
	_box("brass", at + Vector3(0, 1.18, 0.89), Vector3(0.44, 0.12, 0.04), GOLD)
	for x in [-2.5, -1.95, 1.95, 2.5]:
		_candle(at + Vector3(x, 1.57, 0), 0.4 if absf(x) > 2.0 else 0.25)


func _altar_cross(at: Vector3) -> void:
	_box("brass", at + Vector3(0, 3.0, 0), Vector3(0.22, 4.5, 0.22), GOLD)
	_box("brass", at + Vector3(0, 4.15, 0), Vector3(2.5, 0.22, 0.22), GOLD)
	_box("stone", at + Vector3(0, 0.25, 0), Vector3(1.2, 0.5, 0.7), STONE)


func _lectern(at: Vector3) -> void:
	_box("wood", at + Vector3(0, 0.1, 0), Vector3(1, 0.2, 1), WOOD)
	_box("wood", at + Vector3(0, 0.73, 0), Vector3(0.3, 1.2, 0.3), WOOD_EDGE)
	_box("wood", at + Vector3(0, 1.42, 0), Vector3(1, 0.18, 0.9), WOOD)
	_box("wax", at + Vector3(0, 1.54, 0), Vector3(0.74, 0.08, 0.58), WAX)
	_box("brass", at + Vector3(0, 1.59, 0), Vector3(0.04, 0.02, 0.58), GOLD)


func _windows(generator) -> void:
	# Quarter-meter glass blocks and dark leading fill the terrain openings.
	for z in range(-31, 23):
		for x in range(-25, 25):
			if not generator.wall_at(x, z):
				continue
			var offset: int = generator.window_offset(x, z)
			if offset < 0:
				continue
			var along_z := x == -17 or x == 16 or x == -25 or x == 24
			var top := 5.0 if offset == 0 else 4.0
			var at := Vector3(x + 0.5, 2.0, z + 0.5)
			for row in int((top - 2.0) * 4):
				for col in 4:
					var center := at + Vector3(0, row * 0.25 + 0.125, 0)
					center += Vector3(0, 0, col * 0.25 - 0.375) if along_z else Vector3(col * 0.25 - 0.375, 0, 0)
					var tint := posmod(row / 3 + col / 2 + x + z, GLASS.size())
					_box("glass_%d" % tint, center, Vector3(0.18, 0.225, 0.225) if along_z else Vector3(0.225, 0.225, 0.18), GLASS[tint])
			_box("iron", at + Vector3(0, 1.0, 0), Vector3(0.22, 0.065, 1.0) if along_z else Vector3(1.0, 0.065, 0.22), IRON)
			# Keep the sill top above the voxel ledge at y=2; coincident faces
			# flicker through one another as the gameplay camera moves.
			_box("stone", at + Vector3(0, -0.08, 0), Vector3(1.25, 0.24, 1.25), PALE)


func _wall_details() -> void:
	# Slim pilasters and pointed archivolts frame the stained glass.
	for side in [-1.0, 1.0]:
		for z in [16.5, 8.5, 0.5, -19.5]:
			for offset in [-1.6, 1.6]:
				_box("stone", Vector3(side * 15.81, 3.0, z + offset), Vector3(0.3, 5.8, 0.32), PALE)
			for step in 4:
				for end in [-1.0, 1.0]:
					_box("stone", Vector3(side * 15.78, 4.2 + step * 0.45, z + end * (1.4 - step * 0.35)), Vector3(0.35, 0.48, 0.4), PALE)
		# Votive shelves near the apse, outside the storage banks.
		for z in [-24.0, -27.5]:
			_box("stone", Vector3(side * 7.8, 1.8, z), Vector3(0.4, 0.18, 1.2), STONE)
			for dz in [-0.35, 0.0, 0.35]:
				_candle(Vector3(side * 7.7, 1.9, z + dz), 0.25)


func _chandeliers() -> void:
	# Open iron rings, offset over the pews so the camera sees the carpet.
	for side in [-1.0, 1.0]:
		for z in [8.0, -8.0]:
			var at := Vector3(side * 5.0, 4.8, z)
			for axis in [-1.0, 1.0]:
				_box("iron", at + Vector3(axis * 0.85, 0, 0), Vector3(0.09, 0.09, 1.8), IRON)
				_box("iron", at + Vector3(0, 0, axis * 0.85), Vector3(1.8, 0.09, 0.09), IRON)
				for other in [-1.0, 1.0]:
					_candle(at + Vector3(axis * 0.8, 0, other * 0.8), 0.25)
					_box("iron", at + Vector3(axis * 0.8, 0.55, other * 0.8), Vector3(0.04, 1.1, 0.04), IRON)
			_box("iron", at + Vector3(0, 1.1, 0), Vector3(1.7, 0.06, 0.08), IRON)
			_box("iron", at + Vector3(0, 1.1, 0), Vector3(0.08, 0.06, 1.7), IRON)


func _chest_inlays(slots: Array) -> void:
	# Flat, unraised stones reserve every slot even in a new account's hall.
	for entry: Array in slots:
		var at: Vector3 = entry[0]
		_box("stone", at + Vector3(0, 0.008, 0), Vector3(1.8, 0.016, 1.8), Color("817568"))
		for side in [-1.0, 1.0]:
			_box("brass", at + Vector3(side * 0.86, 0.02, 0), Vector3(0.035, 0.018, 1.72), GOLD.darkened(0.15))
			_box("brass", at + Vector3(0, 0.02, side * 0.86), Vector3(1.72, 0.018, 0.035), GOLD.darkened(0.15))


func _churchyard() -> void:
	var graves: Array = [[], [], []]
	var trees: Array[Transform3D] = []
	# Irregular family plots on every side; the processional paths stay clear.
	for z in range(-48, 49, 4):
		for x in range(-48, 49, 4):
			if not _yard_clear(x, z) or _rng.randf() < 0.3:
				continue
			var at := Vector3(x + _rng.randf_range(-0.5, 0.5), 0, z + _rng.randf_range(-0.45, 0.45))
			var yaw := PI + _rng.randf_range(-0.15, 0.15)
			var scale_factor := _rng.randf_range(0.9, 1.3)
			var basis := Basis(Vector3.UP, yaw).scaled(Vector3.ONE * scale_factor)
			graves[_rng.randi_range(0, 2)].append(Transform3D(basis, at))
			_box("earth", at + Vector3(0, 0.025, -0.9), Vector3(1.25, 0.05, 2.3), Color("504739"))
			if _rng.randf() < 0.17:
				_cross(at + Vector3(1.0, 0, -0.3))
	var paths := ["t1_wooden", "t2_fieldstone", "t3_veteran"]
	for i in paths.size():
		var scene: PackedScene = load("res://props/gravestones/%s/model.tscn" % paths[i])
		var model := scene.instantiate()
		_batch_scene(model, Transform3D.IDENTITY, graves[i], "GraveMarkers%d" % i)
		model.free()
	for at in [Vector3(-25, 0, 24), Vector3(25, 0, 24), Vector3(-38, 0, -25), Vector3(38, 0, -26),
			Vector3(-18, 0, -39), Vector3(18, 0, -42), Vector3(-43, 0, 15), Vector3(43, 0, 14),
			Vector3(-43, 0, 42), Vector3(42, 0, 40), Vector3(-12, 0, 43), Vector3(17, 0, 45)]:
		trees.append(Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3.ONE * _rng.randf_range(1.1, 1.65)), at))
	_trees(trees)
	_fences()
	for side in [-1.0, 1.0]:
		for z in [29.0, -35.0]:
			var lantern: Node3D = preload("res://scenes/home/prefabs/lantern.tscn").instantiate()
			lantern.position = Vector3(side * 6.0, 0, z)
			add_child(lantern)
	# Broken plot edging and small memorial candles, beyond the church walls.
	for side in [-1.0, 1.0]:
		for z in [-28.0, 8.0, 20.0]:
			var at := Vector3(side * 25.0, 0, z)
			_box("stone", at + Vector3(0, 0.15, 0), Vector3(2.3, 0.3, 1.2), DARK_STONE)
			_cross(at)
			_candle(at + Vector3(0.65, 0.3, 0.2), 0.25)


func _yard_clear(x: int, z: int) -> bool:
	# Church footprint + generous setback, four roads, and a ring path.
	if absi(x) < 20 and z > -34 and z < 26:
		return false
	if absi(x) < 28 and z > -21 and z < 2:
		return false
	if absi(x) < 5 or absi(z + 9) < 5:
		return false
	if absi(absi(x) - 30) < 3 or absi(absi(z) - 37) < 3:
		return false
	return true


func _cross(at: Vector3) -> void:
	_box("stone", at + Vector3(0, 0.15, 0), Vector3(0.9, 0.3, 0.65), DARK_STONE)
	_box("stone", at + Vector3(0, 1.0, 0), Vector3(0.22, 1.7, 0.25), STONE)
	_box("stone", at + Vector3(0, 1.3, 0), Vector3(1.0, 0.24, 0.25), STONE)


func _trees(placements: Array[Transform3D]) -> void:
	var biome := BiomeDef.new()
	biome.id = 107031
	biome.obstacle_colors = PackedColorArray([Color.TRANSPARENT, DARK_STONE, Color("424448"),
			Color("596044"), Color("53483d"), Color("92836a"), Color("3d483a"), Color("dca761")])
	var prefab := ObstacleLibrary.get_prefab("dead_tree")
	var meshes := prefab.meshes_for(biome)
	var transforms: Array[Transform3D] = []
	for placement in placements:
		transforms.append(placement * Transform3D(Basis().scaled(Vector3.ONE * prefab.voxel_size), prefab.mesh_offset()))
	_batch_mesh(meshes[0], VoxModel.material(), transforms, "OldYews")


func _fences() -> void:
	# Low iron rails with stone piers; gaps align with all four roads.
	for side in [-1.0, 1.0]:
		for step in range(-48, 49, 3):
			if absi(step) > 4:
				_fence(Vector3(step, 0, side * 51.0), false)
			if absi(step + 9) > 4:
				_fence(Vector3(side * 51.0, 0, step), true)


func _fence(at: Vector3, along_z: bool) -> void:
	var axis := Vector3.FORWARD if along_z else Vector3.RIGHT
	_box("stone", at + Vector3(0, 0.18, 0), Vector3(0.55, 0.36, 3.0) if along_z else Vector3(3.0, 0.36, 0.55), DARK_STONE)
	_box("stone", at + Vector3(0, 0.75, 0), Vector3(0.5, 1.5, 0.5), STONE)
	_box("stone", at + Vector3(0, 1.55, 0), Vector3(0.65, 0.15, 0.65), PALE)
	for y in [0.65, 1.15]:
		_box("iron", at + Vector3(0, y, 0), Vector3(0.07, 0.08, 3.0) if along_z else Vector3(3.0, 0.08, 0.07), IRON)
	for offset in [-1.2, -0.6, 0.6, 1.2]:
		_box("iron", at + axis * offset + Vector3(0, 0.9, 0), Vector3(0.07, 1.1, 0.07), IRON)
		_box("brass", at + axis * offset + Vector3(0, 1.48, 0), Vector3(0.1, 0.1, 0.1), GOLD.darkened(0.3))


func _box(group: String, center: Vector3, size: Vector3, color: Color) -> void:
	if not _boxes.has(group):
		_boxes[group] = []
		_colors[group] = []
	_boxes[group].append(Transform3D(Basis().scaled(size), center))
	_colors[group].append(color)


func _flush_boxes() -> void:
	var cube := BoxMesh.new()
	cube.size = Vector3.ONE
	for group: String in _boxes:
		var material := StandardMaterial3D.new()
		material.vertex_color_use_as_albedo = true
		material.roughness = 0.85
		if group == "brass" or group == "iron":
			material.metallic = 0.5
		if group == "flame" or group.begins_with("glass_"):
			material.emission_enabled = true
			material.emission = Color("ffc268") if group == "flame" else GLASS[int(group.trim_prefix("glass_"))]
			material.emission_energy_multiplier = 2.2 if group == "flame" else 0.85
		var transforms: Array[Transform3D] = []
		transforms.assign(_boxes[group])
		var batch := _batch_mesh(cube, material, transforms, group.capitalize(), _colors[group])
		if group == "flame" or group.begins_with("glass_"):
			batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_boxes.clear()
	_colors.clear()


func _batch_scene(node: Node3D, parent_transform: Transform3D, placements: Array, label: String) -> void:
	var local := parent_transform * node.transform
	if node is MeshInstance3D:
		var transforms: Array[Transform3D] = []
		for placement: Transform3D in placements:
			transforms.append(placement * local)
		_batch_mesh(node.mesh, node.material_override, transforms, label)
	for child in node.get_children():
		if child is Node3D:
			_batch_scene(child, local, placements, label)


func _batch_mesh(mesh: Mesh, material: Material, transforms: Array[Transform3D], label: String, colors: Array = []) -> MultiMeshInstance3D:
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = not colors.is_empty()
	multi.mesh = mesh
	multi.instance_count = transforms.size()
	for i in transforms.size():
		multi.set_instance_transform(i, transforms[i])
		if multi.use_colors:
			multi.set_instance_color(i, colors[i])
	var batch := MultiMeshInstance3D.new()
	batch.name = label
	batch.multimesh = multi
	batch.material_override = material
	add_child(batch)
	return batch
