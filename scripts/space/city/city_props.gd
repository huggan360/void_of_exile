class_name CityProps
## The Lantern City's voxel props (props/city/<id>) and vehicles (vehicles/<id>):
## meshes loaded once, placed centred on x/z with their bottom on the floor.
static var _meshes := {}  # path -> [Mesh, AABB] or []
static var _meta := {}

static func _load(path: String) -> Array:
	if _meshes.has(path): return _meshes[path]
	var out: Array = []
	if FileAccess.file_exists(path) or ResourceLoader.exists(path):
		var mesh := VoxModel.load_mesh(path)
		if mesh: out = [mesh, mesh.get_aabb()]
	_meshes[path] = out
	return out

static func meta(folder: String, file: String) -> Dictionary:
	var path := "%s/%s" % [folder, file]
	if _meta.has(path): return _meta[path]
	var data := {}
	if FileAccess.file_exists(path):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if parsed is Dictionary: data = parsed
	_meta[path] = data
	return data

## A prop node (base and glow) or null when the prop is missing. `scale` on top of its own size.
static func prop(id: String, scale := 1.0) -> Node3D:
	return _build("res://props/city/"+id, float(meta("res://props/city/"+id, "prop.json").get("voxel_size", 0.1))*scale)

static func vehicle_meshes(id: String) -> Array:
	var folder := "res://vehicles/"+id
	return [_load(folder+"/model.vox"), _load(folder+"/model_glow.vox"), float(meta(folder, "vehicle.json").get("voxel_size", 0.1))]

static func _build(folder: String, voxel: float) -> Node3D:
	var base := _load(folder+"/model.vox")
	if base.is_empty(): return null
	var holder := Node3D.new()
	holder.scale = Vector3.ONE*voxel
	var box: AABB = base[1]
	var offset := Vector3(-box.get_center().x, -box.position.y, -box.get_center().z)
	for pair: Array in [[base, VoxModel.material()], [_load(folder+"/model_glow.vox"), VoxModel.glow_material()]]:
		var data: Array = pair[0]
		if data.is_empty(): continue
		var mesh := MeshInstance3D.new()
		mesh.mesh = data[0]
		mesh.material_override = pair[1]
		mesh.position = offset
		mesh.visibility_range_end = 160.0
		holder.add_child(mesh)
	return holder

## Places prop `id` under `parent` at a local transform; returns it (or null).
static func place(parent: Node3D, id: String, at: Vector3, yaw := 0.0, scale := 1.0) -> Node3D:
	var node := prop(id, scale)
	if node==null: return null
	node.position = at
	node.rotation.y = yaw
	parent.add_child(node)
	return node

## The offset that centres a vehicle mesh (voxel units).
static func center_offset(data: Array) -> Vector3:
	var box: AABB = data[1]
	return Vector3(-box.get_center().x, -box.position.y, -box.get_center().z)
