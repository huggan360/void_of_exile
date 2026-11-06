extends SceneTree
## Offline asset authoring only. Bakes actual editable meshes/colliders into scenes.
func _initialize() -> void:
	call_deferred("_bake")

func _bake() -> void:
	var folders: Array[String] = []
	for name in DirAccess.get_directories_at("res://props/home"):
		folders.append("res://props/home/" + name)
	for name in DirAccess.get_directories_at("res://props/houses"):
		folders.append("res://props/houses/" + name)
	for name in ["market", "bench", "well"]:
		folders.append("res://props/town/" + name)
	var selected := OS.get_cmdline_user_args()
	if not selected.is_empty():
		folders = folders.filter(func(folder: String) -> bool: return folder.get_file() in selected)
	for folder: String in folders:
		var node := Node3D.new()
		node.name = folder.get_file().to_pascal_case()
		var rig: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(folder + "/rig.json"))
		var frame: Array = rig.parts.body.frame_min
		var unit: float = rig.voxel_size
		for suffix in ["", "_glow"]:
			if not FileAccess.file_exists(folder + "/body" + suffix + ".vox"):
				continue
			var mesh := VoxModel.load_mesh(folder + "/body" + suffix + ".vox")
			if mesh == null: continue
			var resource_path: String = "res://scenes/home/prefabs/" + folder.get_file() + suffix + ".res"
			ResourceSaver.save(mesh, resource_path)
			var part := MeshInstance3D.new()
			part.name = "CarvedVoxels" if suffix.is_empty() else "LitWindows"
			part.mesh = load(resource_path)
			part.material_override = VoxModel.material() if suffix.is_empty() else VoxModel.glow_material()
			part.position = Vector3(frame[0], frame[1], frame[2]) * unit
			part.scale = Vector3.ONE * unit
			node.add_child(part)
			part.owner = node
		var size := Vector3(8.5, 9, 9)
		var info: Dictionary = {}
		if folder.contains("/home/"):
			info = JSON.parse_string(FileAccess.get_file_as_string(folder + "/building.json"))
			var s: Array = info.solid_size
			size = Vector3(s[0], s[1], s[2])
		elif folder.contains("/town/"):
			size = Vector3(3.5, 3.8, 2.8) if folder.ends_with("market") else Vector3(2.8, 4, 2.8) if folder.ends_with("well") else Vector3(2.7, 1.7, 1.3)
		if info.has("colliders"):
			for entry: Dictionary in info.colliders:
				var s: Array = entry.size
				var at: Array = entry.offset
				_add_box(node, Vector3(s[0], s[1], s[2]), Vector3(at[0], at[1], at[2]))
		else:
			_add_box(node, size, Vector3(0, size.y / 2, 0))
		for marker_name: String in info.get("markers", {}):
			var at: Array = info.markers[marker_name]
			var marker := Marker3D.new()
			marker.name = marker_name
			marker.position = Vector3(at[0], at[1], at[2])
			node.add_child(marker)
			marker.owner = node
		if folder.ends_with("smithy"):
			_add_box(node, Vector3(1.7, 7, 2.3), Vector3(2.2, 3.5, -6.6))
			_add_box(node, Vector3(2.5, 1.3, 1.7), Vector3(-1.8, .65, -6.5))
		node.set_meta("voxel_source", folder + "/model.vox")
		var packed := PackedScene.new()
		packed.pack(node)
		ResourceSaver.save(packed, "res://scenes/home/prefabs/" + folder.get_file() + ".tscn")
		node.free()
	print("Baked ", folders.size(), " editor-visible home prefabs")
	quit()

func _add_box(node: Node3D, size: Vector3, offset: Vector3) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 2
	body.collision_mask = 0
	node.add_child(body)
	body.owner = node
	body.name = "SolidEnvelope" + str(node.get_child_count())
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collider.shape = shape
	collider.position = offset
	body.add_child(collider)
	collider.owner = node
	collider.name = "ClosedCollision"
