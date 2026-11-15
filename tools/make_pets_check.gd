extends Node
## Actual runtime loaders, without a window or a world/server session.
## godot_voxel_editor --headless --path . res://tools/make_pets_check.tscn


func _ready() -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://props/pets/manifest.json"))
	var checked := 0
	for group in ["pets", "npcs"]:
		for id: String in manifest[group]:
			var record: Dictionary = manifest[group][id]
			var folder: String = record.folder
			var model := CreatureModel.new(folder.get_file())
			add_child(model)
			assert(model.get_child_count() > 0, id)
			for moving in [0.0, 1.0]:
				model.animate(moving, 0.016)
			model.flap()
			model.animate(1.0, 0.016)
			model.free()
			checked += 1
	var egg := CreatureModel.new("pet_egg")
	add_child(egg)
	egg.animate(0.0, 0.016)
	egg.free()
	for id: String in manifest.props:
		var record: Dictionary = manifest.props[id]
		var prop := VillageHouse.new().setup({asset = "res://" + str(record.folder), pos = Vector3.ZERO, yaw = 0.0, solid_size = Vector3.ZERO})
		add_child(prop)
		assert(prop.get_child_count() > 0, id)
		prop.free()
	var icon: Texture2D = load("res://items/textures/pet_egg.png")
	assert(icon.get_width() == 64 and icon.get_height() == 64)
	print("PET ART PASS: %d creatures, egg, 11 prop folders, icon, idle and moving rigs" % checked)
	get_tree().quit()
