extends SceneTree
## Offline only: editor-visible rigged rest-pose scenes, with native source metadata.
## Default: the live boss art (creatures/realm_boss_manifest.json). Pass
## -- --staging to rebake the original staged batch instead.
var ROOT := "res://creatures/"
var MANIFEST := "realm_boss_manifest.json"
func _initialize() -> void:
	call_deferred("_bake")
func _bake() -> void:
	if "--staging" in OS.get_cmdline_user_args():
		ROOT = "res://creatures/staging/realm_bosses_01/"
		MANIFEST = "manifest.json"
	var manifest: Array = JSON.parse_string(FileAccess.get_file_as_string(ROOT+MANIFEST))
	var selected := PackedStringArray()
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--only="): selected = argument.trim_prefix("--only=").split(",")
	for entry: Dictionary in manifest:
		if not selected.is_empty() and str(entry.id) not in selected: continue
		var folder: String = ROOT+str(entry.id)+"/"
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder+"meshes"))
		var rig: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(folder+"rig.json"))
		var meshes := {}
		for part: String in rig.parts:
			meshes[part] = []
			for suffix: String in ["", "_glow"]:
				var path := folder+part+suffix+".vox"
				if not FileAccess.file_exists(path):
					meshes[part].append(null)
					continue
				var mesh := VoxModel.load_mesh(path)
				assert(mesh != null, path)
				var saved := folder+"meshes/"+part+suffix+".res"
				assert(ResourceSaver.save(mesh,saved)==OK)
				meshes[part].append(load(saved))
		var variants: Dictionary = {"default": {}}
		variants.merge(rig.get("variants",{}))
		for variant: String in variants:
			var root := Node3D.new()
			root.name = str(entry.id).to_pascal_case()+variant.to_pascal_case()
			root.set_meta("status", "live" if MANIFEST == "realm_boss_manifest.json" else "art_staging_only")
			root.set_meta("voxel_source",folder+"model"+("" if variant=="default" else "_"+variant)+".vox")
			var animated := Node3D.new()
			animated.name = "Rig"
			animated.position.y = float(rig.get("hover",0))
			root.add_child(animated)
			animated.owner = root
			_add_part(animated,root,str(variants[variant].get("body","body")),rig,meshes)
			var pivots := {}
			for limb: String in rig.limbs:
				var spec: Dictionary = rig.limbs[limb]
				var pivot := Node3D.new()
				pivot.name = limb.to_pascal_case()
				pivot.position = _vec(spec.pivot)*float(rig.voxel_size)
				pivot.rotation.y = deg_to_rad(float(spec.get("yaw",0)))
				var parent: Node3D = pivots.get(spec.get("parent_limb",""),animated)
				parent.add_child(pivot)
				pivots[limb] = pivot
				pivot.owner = root
				_add_part(pivot,root,str(variants[variant].get(spec.part,spec.part)),rig,meshes)
			var packed := PackedScene.new()
			assert(packed.pack(root)==OK)
			var out := folder+"model"+("" if variant=="default" else "_"+variant)+".tscn"
			assert(ResourceSaver.save(packed,out)==OK)
			root.free()
		print("Baked editor models: ",entry.id)
	quit()
func _add_part(parent: Node3D, root: Node3D, part: String, rig: Dictionary, meshes: Dictionary) -> void:
	var holder := Node3D.new()
	holder.name = part.to_pascal_case()
	holder.position = _vec(rig.parts[part].frame_min)*float(rig.voxel_size)
	holder.scale = Vector3.ONE*float(rig.voxel_size)
	parent.add_child(holder)
	holder.owner = root
	for i in 2:
		if meshes[part][i] == null: continue
		var node := MeshInstance3D.new()
		node.name = "CarvedVoxels" if i==0 else "EmissiveVoxels"
		node.mesh = meshes[part][i]
		if rig.get("pixel_art",false):
			var material := ShaderMaterial.new()
			material.shader = preload("res://shaders/voxel_model.gdshader")
			material.set_shader_parameter("jitter",0.0)
			material.set_shader_parameter("glow_strength",float(rig.get("glow_strength",1.1)) if i==1 else 0.0)
			node.material_override = material
		else: node.material_override = VoxModel.material() if i==0 else VoxModel.glow_material()
		holder.add_child(node)
		node.owner = root
func _vec(array: Array) -> Vector3:
	return Vector3(array[0],array[1],array[2])
