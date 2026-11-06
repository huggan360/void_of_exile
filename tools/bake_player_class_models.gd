extends SceneTree
## Offline art generation only. No Player, stats, inventory or class registration.
const ArmRig = preload("res://scripts/player_arm_rig.gd")

func _initialize() -> void: _bake.call_deferred()
func _bake() -> void:
	VoxModel.material().set_shader_parameter("jitter",.07)
	VoxModel.material().set_shader_parameter("glow_strength",0.0)
	var manifest: Array = JSON.parse_string(FileAccess.get_file_as_string("res://characters/class_model_manifest.json"))
	var lineup := Node3D.new()
	lineup.name = "PlayerClassModels"
	lineup.set_meta("status","playable")
	for i in manifest.size():
		var entry: Dictionary = manifest[i]
		var folder: String = "res://"+str(entry.folder)+"/"
		var rig: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(folder+"rig.json"))
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder+"meshes"))
		var root := Node3D.new()
		root.name = str(entry.name)
		root.set_meta("status","playable")
		root.set_meta("voxel_source",folder+"model.vox")
		root.set_meta("reference","Archer proportions, +X right hand, -Z forward")
		var skeleton := Node3D.new()
		skeleton.name = "Rig"
		root.add_child(skeleton)
		skeleton.owner = root
		_add_part(skeleton,root,folder,"body",rig)
		var pivots := {}
		for key: String in rig.limbs:
			var info: Dictionary = rig.limbs[key]
			var pivot := Node3D.new()
			pivot.name = str(info.get("name", key.to_pascal_case()))
			pivot.position = _vec(info.pivot)*float(rig.voxel_size)
			pivot.set_meta("voxel_pivot",info.pivot)
			var parent: Node3D = pivots[str(info.parent)] if info.has("parent") else skeleton
			parent.add_child(pivot)
			pivot.owner = root
			pivots[key] = pivot
			_add_part(pivot,root,folder,str(info.part),rig,info)
		for key: String in rig.attachments:
			var info: Dictionary = rig.attachments[key]
			var socket := Node3D.new()
			socket.name = str(info.get("name", key.to_pascal_case()))
			socket.position = _vec(info.pivot)*float(rig.voxel_size)
			(pivots[str(info.parent)] as Node3D).add_child(socket)
			socket.owner = root
			_add_part(socket,root,folder,str(info.part),rig,info)
		if str(entry.id) == "archer":
			ArmRig.reach(pivots.arm_r, Vector3(5.5, 6.5, -2.2) * float(rig.voxel_size), Vector3(1, -1, 0))
			ArmRig.pose(pivots.arm_l, 0.0, deg_to_rad(15.0), 0.0, deg_to_rad(-10.0))
			_add_bow_string((pivots.hand_r as Node3D).get_node("Bow"), root, float(rig.voxel_size))
		else:
			ArmRig.pose(pivots.arm_r, deg_to_rad(32.0), deg_to_rad(55.0))
			ArmRig.pose(pivots.arm_l, 0.0, deg_to_rad(15.0), 0.0, deg_to_rad(-10.0))
		var scene := PackedScene.new()
		scene.pack(root)
		ResourceSaver.save(scene,folder+"model.tscn")
		var saved := load(folder+"model.tscn") as PackedScene
		var instance := saved.instantiate() as Node3D
		instance.position.x = (i-(manifest.size()-1)*0.5)*2.6
		lineup.add_child(instance)
		instance.owner = lineup
		root.free()
		print("Authored editor model: ",entry.name)
	var lineup_scene := PackedScene.new()
	lineup_scene.pack(lineup)
	ResourceSaver.save(lineup_scene,"res://characters/class_model_lineup.tscn")
	lineup.free()
	quit()


func _add_bow_string(bow: Node3D, root: Node3D, unit: float) -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.025, 1, 0.025)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color8(224, 222, 210)
	for top: bool in [true, false]:
		var segment := MeshInstance3D.new()
		segment.name = "StringTop" if top else "StringBottom"
		segment.mesh = mesh
		segment.material_override = material
		segment.position = Vector3(0, 3 if top else -3, 1.6) * unit
		segment.scale.y = 6 * unit
		bow.add_child(segment)
		segment.owner = root


func _add_part(parent: Node3D, root: Node3D, folder: String, part: String, rig: Dictionary, info: Dictionary = {}) -> void:
	var holder := Node3D.new()
	holder.name = part.to_pascal_case()
	var mesh_scale := _vec(info.get("mesh_scale", [1, 1, 1]))
	var offset := _vec(info.get("mesh_offset", [0, 0, 0]))
	holder.position = (_vec(rig.parts[part].frame_min)*mesh_scale+offset)*float(rig.voxel_size)
	holder.scale = mesh_scale*float(rig.voxel_size)
	parent.add_child(holder)
	holder.owner = root
	var suffixes: Array[String] = [""]
	if rig.parts[part].get("glow", false):
		suffixes.append("_glow")
	for suffix: String in suffixes:
		var path := folder+part+suffix+".vox"
		if not FileAccess.file_exists(path): continue
		var mesh := VoxModel.load_mesh(path)
		var resource_path := folder+"meshes/"+part+suffix+".res"
		ResourceSaver.save(mesh,resource_path)
		var geometry := MeshInstance3D.new()
		geometry.name = "ClothAndEquipment" if suffix=="" else "MagicAccent"
		geometry.mesh = load(resource_path)
		if suffix=="": geometry.material_override = VoxModel.material()
		else:
			var material := ShaderMaterial.new()
			material.shader = preload("res://shaders/voxel_model.gdshader")
			material.set_shader_parameter("jitter",.07)
			material.set_shader_parameter("glow_strength",.8)
			geometry.material_override = material
		holder.add_child(geometry)
		geometry.owner = root
func _vec(value: Array) -> Vector3:
	return Vector3(value[0],value[1],value[2])
