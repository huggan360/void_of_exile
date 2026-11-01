extends SceneTree
## Editor-visible props only. No world/death placement or gameplay registration.
func _initialize() -> void: _bake.call_deferred()
func _bake() -> void:
	var manifest: Array = JSON.parse_string(FileAccess.get_file_as_string("res://props/gravestones/manifest.json"))
	var lineup := Node3D.new()
	lineup.name = "GravestoneTiers"
	lineup.set_meta("status","art_only")
	for i in manifest.size():
		var entry: Dictionary = manifest[i]
		var folder: String = "res://"+str(entry.folder)+"/"
		var rig: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(folder+"rig.json"))
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder+"meshes"))
		var root := Node3D.new()
		root.name = str(entry.id).to_pascal_case()
		root.set_meta("tier",entry.tier)
		root.set_meta("rank_hint",entry.rank_hint)
		root.set_meta("voxel_source",folder+"model.vox")
		root.set_meta("status","art_only")
		var holder := Node3D.new()
		holder.name = "CarvedMarker"
		holder.position = _vec(rig.parts.body.frame_min)*float(rig.voxel_size)
		holder.scale = Vector3.ONE*float(rig.voxel_size)
		root.add_child(holder)
		holder.owner = root
		for suffix: String in ["","_glow"]:
			var path := folder+"body"+suffix+".vox"
			if not FileAccess.file_exists(path): continue
			var mesh := VoxModel.load_mesh(path)
			var saved := folder+"meshes/body"+suffix+".res"
			ResourceSaver.save(mesh,saved)
			var geometry := MeshInstance3D.new()
			geometry.name = "StoneAndWood" if suffix=="" else "SpiritAccent"
			geometry.mesh = load(saved)
			var material := ShaderMaterial.new()
			material.shader = preload("res://shaders/voxel_model.gdshader")
			material.set_shader_parameter("jitter",.035)
			material.set_shader_parameter("glow_strength",.95 if suffix!="" else 0.0)
			geometry.material_override = material
			holder.add_child(geometry)
			geometry.owner = root
		var packed := PackedScene.new()
		packed.pack(root)
		ResourceSaver.save(packed,folder+"model.tscn")
		var scene := load(folder+"model.tscn") as PackedScene
		var instance := scene.instantiate() as Node3D
		instance.position.x = (i-2)*2.7
		lineup.add_child(instance)
		instance.owner = lineup
		root.free()
		print("Authored gravestone scene: ",entry.name)
	var scene := PackedScene.new()
	scene.pack(lineup)
	ResourceSaver.save(scene,"res://props/gravestones/lineup.tscn")
	lineup.free()
	quit()
func _vec(value: Array) -> Vector3: return Vector3(value[0],value[1],value[2])
