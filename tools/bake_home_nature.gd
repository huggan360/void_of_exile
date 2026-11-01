extends SceneTree
## Offline asset authoring only. Bakes realm trees, bushes and rocks (woodland
## colors; palms in beach colors) into editor-visible home prefabs.
const NATURE := {
	tree_round = Biomes.WOODS, tree_tall = Biomes.WOODS, tree_small = Biomes.WOODS,
	bush = Biomes.WOODS, pine = Biomes.WOODS, rock = Biomes.WOODS, boulder = Biomes.WOODS,
	palm = Biomes.BEACH,
}

func _initialize() -> void:
	call_deferred("_bake")

func _bake() -> void:
	for prefab_name: String in NATURE:
		var prefab := ObstacleLibrary.get_prefab(prefab_name)
		var meshes := prefab.meshes_for(Biomes.get_biome(NATURE[prefab_name]))
		var node := Node3D.new()
		node.name = prefab_name.to_pascal_case()
		for i in 2:
			if meshes[i] == null:
				continue
			var path := "res://scenes/home/prefabs/nature_%s%s.res" % [prefab_name, "_glow" if i == 1 else ""]
			ResourceSaver.save(meshes[i], path)
			var part := MeshInstance3D.new()
			part.name = "CarvedVoxels" if i == 0 else "Glow"
			part.mesh = load(path)
			part.material_override = VoxModel.material() if i == 0 else VoxModel.glow_material()
			part.position = prefab.mesh_offset()
			part.scale = Vector3.ONE * prefab.voxel_size
			node.add_child(part)
			part.owner = node
		var body := StaticBody3D.new()
		body.name = "SolidEnvelope"
		body.collision_layer = 2
		body.collision_mask = 0
		node.add_child(body)
		body.owner = node
		for box in prefab.collision_boxes:
			var collider := CollisionShape3D.new()
			var shape := BoxShape3D.new()
			shape.size = box.size
			collider.shape = shape
			collider.position = box.get_center()
			body.add_child(collider)
			collider.owner = node
		print(prefab_name, " footprint ", prefab.footprint, " height ", prefab.height, " boxes ", prefab.collision_boxes.size())
		var packed := PackedScene.new()
		packed.pack(node)
		ResourceSaver.save(packed, "res://scenes/home/prefabs/nature_%s.tscn" % prefab_name)
		node.free()
	quit()
