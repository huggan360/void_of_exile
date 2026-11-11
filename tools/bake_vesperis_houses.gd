extends Node
## Offline asset authoring only. Bakes props/vesperis/* (make_vesperis_houses.py)
## into meshes under scenes/vesperis/ and one catalogue (catalog.json) that
## CityHouses reads: per model its kind, footprint, colliders and, per detail
## level, the mesh, its offset and its scale (voxels to metres).
## Run: godot --headless --path . res://tools/bake_vesperis_houses.tscn
const SRC := "res://props/vesperis/"
const OUT := "res://scenes/vesperis/"

func _ready() -> void:
	call_deferred("_bake")

func _bake() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var catalog := {}
	for name in DirAccess.get_directories_at(SRC):
		var folder := SRC+name
		var rig: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(folder+"/rig.json"))
		var info: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(folder+"/building.json"))
		var unit: float = rig.voxel_size
		var frame: Array = rig.parts.body.frame_min
		var entry := info.duplicate()
		entry.lods = []
		# Level 0: full detail and its glowing windows; 1 and 2: coarse copies.
		var lod0 := {mesh = _save(folder+"/body.vox", name), offset = _vec(frame, unit), scale = unit}
		if FileAccess.file_exists(folder+"/body_glow.vox"): lod0.glow = _save(folder+"/body_glow.vox", name+"_glow")
		entry.lods.append(lod0)
		for lod: Dictionary in rig.get("lods", []):
			var k: int = (entry.lods as Array).size()
			var f := float(lod.scale)
			entry.lods.append({mesh = _save(folder+"/body_lod%d.vox" % k, name+"_lod%d" % k), offset = _vec(lod.frame_min, unit*f), scale = unit*f})
		catalog[name] = entry
	var file := FileAccess.open(OUT+"catalog.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(catalog, "\t"))
	print("Baked ", catalog.size(), " Vesperis buildings")
	get_tree().quit()

func _save(vox: String, name: String) -> String:
	var mesh := VoxModel.load_mesh(vox)
	var path := OUT+name+".res"
	ResourceSaver.save(mesh, path)
	return path

func _vec(a: Array, scale: float) -> Array:
	return [float(a[0])*scale, float(a[1])*scale, float(a[2])*scale]
