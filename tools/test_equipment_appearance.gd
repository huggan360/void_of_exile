extends Node
## Run with the voxel editor --headless --path . res://tools/test_equipment_appearance.tscn
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func _ready() -> void:
	run.call_deferred()
func run() -> void:
	for pair: Array in [["G1_bow", "archer/bow_frame"], ["G1_wand", "wizard/staff"], ["G1_wand_glow", "wizard/staff_glow"], ["G1_trident", "merrow/staff"], ["G1_trident_glow", "merrow/staff_glow"]]:
		check(FileAccess.get_file_as_bytes("res://characters/equipment/%s.vox" % pair[0]) == FileAccess.get_file_as_bytes("res://characters/%s.vox" % pair[1]), "G1 differs from original sculpt: " + pair[0])
	var count := 0
	for class_id: String in PlayerClasses.ORDER:
		var model := PlayerClasses.make_model(class_id)
		get_tree().root.add_child(model)
		var body := model.find_child("Body", true, false).get_child(0) as MeshInstance3D
		var original := body.mesh
		for item: Item in Items.all():
			if item.slot not in ["weapon", "armor"] or not PlayerClasses.allows(class_id, item): continue
			check(EquipmentAppearance.profiles().has(item.id), "Missing art: " + item.id)
			var weapon := item if item.slot == "weapon" else PlayerClasses.gear_item(class_id, "weapon", 1)
			var armor := item if item.slot == "armor" else PlayerClasses.gear_item(class_id, "armor", 1)
			model.set_equipment(weapon, armor)
			model.animate(1.0, 0.1)
			model.hold = 1.0
			model.play_shot()
			model.animate(0.0, 0.1)
			check(model.get_meta("equipment_key") == weapon.id + "|" + armor.id, "Wrong gear key")
			if item.slot == "armor" and item.tier != 1:
				check(body.mesh != original, "Armor did not change: " + class_id + item.id)
				var before: PackedColorArray = original.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
				var after: PackedColorArray = body.mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
				check(before != after, "Cloth colors unchanged: " + class_id + item.id)
				var stationary_cloth_changed := false
				for i in before.size():
					if before[i].a < 0.5 and before[i] != after[i]: stationary_cloth_changed = true
					check(before[i].a == after[i].a, "Recolor lost cloth movement mask")
				check(stationary_cloth_changed, "Stationary cloth did not recolor: " + class_id + item.id)
				check(original.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] == body.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX], "Base geometry altered")
			count += 1
		model.set_equipment(null, null)
		check(body.mesh == original, "Default armor not restored: " + class_id)
		var socket := model.find_child("Bow" if class_id == "archer" else "Staff", true, false) as Node3D
		check(not socket.visible, "Unequipped weapon visible")
		model.set_equipment(PlayerClasses.gear_item(class_id, "weapon", 1), PlayerClasses.gear_item(class_id, "armor", 1))
		check(socket.visible, "Reequipped weapon invisible")
		check(body.mesh == original, "G1 armor changed default")
		if class_id in ["archer", "wizard", "merrow"]:
			var authored := socket.get_node("BowFrame" if class_id == "archer" else "Staff") as Node3D
			for part: Node3D in socket.get_children():
				if part.has_meta("equipped_art"):
					check(part.transform.is_equal_approx(authored.transform), "G1 socket fitting differs from original: " + class_id)
		model.set_equipment(null, null)
		model.animate(0.0, 1.0)
		var right := model.find_child("ArmR", true, false) as Node3D
		check(absf(right.rotation.x) < 0.001, "Unarmed shoulder still in weapon pose")
		var fist := model.find_child("RightHand", true, false).get_node("Hand/ClothAndEquipment") as MeshInstance3D
		check(fist.mesh.get_aabb().size.x < 2.0, "Hand still uses wide hollow ring")
		# Appearance and saved-data loading must never move equipment to inventory.
		var stats := PlayerStats.new()
		stats.class_id = class_id
		stats.reset()
		stats.backpack[0] = PlayerClasses.gear_item(class_id, "weapon", 8)
		stats.move({kind = "pack", key = 0}, {kind = "gear", key = "weapon"})
		var saved := stats.to_data()
		for frame in 3:
			model.set_equipment(stats.gear.weapon, stats.gear.armor)
			model.animate(0.0, 0.1)
		check(stats.to_data() == saved, "Appearance moved or changed inventory")
		var reloaded := PlayerStats.new()
		reloaded.load_data(saved)
		check(reloaded.gear.weapon.id == stats.gear.weapon.id, "Saved equipped weapon lost on reload")
		check(reloaded.to_data() == saved, "Saved inventory changed on reload")
		# Sample the complete stride, including maximum rearward boot travel.
		model.set_equipment(PlayerClasses.gear_item(class_id, "weapon", 8), PlayerClasses.gear_item(class_id, "armor", 8))
		var rig := model.find_child("Rig", true, false) as Node3D
		for frame in 65:
			model.set("_walk_blend", 1.0)
			model.set("_phase", TAU * frame / 64.0)
			model.animate(1.0, 0.0)
			var swing := float((body.material_override as ShaderMaterial).get_shader_parameter("garment_swing"))
			for leg_name: String in ["LegL", "LegR"]:
				var leg := rig.get_node(leg_name).get_child(0).get_child(0) as MeshInstance3D
				var vertices: PackedVector3Array = leg.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
				for vertex: Vector3 in vertices:
					var point := (rig.global_transform.affine_inverse() * leg.global_transform * vertex) / EquipmentAppearance.UNIT
					if point.y >= 5.5 or point.z <= 2.0 or point.x < -3 or point.x > 3: continue
					var cloth_front := 2.0 + (5.5-point.y) * swing
					check(point.z <= cloth_front + 0.04, "Leg crosses cloak: %s frame %d" % [class_id, frame])
		model.free()
	var remote := RemotePlayer.new()
	get_tree().root.add_child(remote)
	remote.set_look("Test", "wizard|G8_wand,G8_robe,,")
	check(remote.model.get_meta("equipment_key") == "G8_wand|G8_robe", "Remote gear not applied")
	remote.set_look("Test", "priest|,,,")
	check(remote.model.get_meta("equipment_key") == "|", "Remote class/unequip failed")
	# Exercise the per-frame presentation that the static model tests missed.
	remote.player_id = -998
	remote.set_look("Test", "archer|,,,")
	await get_tree().process_frame
	await get_tree().process_frame
	remote.set_look("Test", "archer|G8_bow,G8_cloak,,")
	await get_tree().process_frame
	await get_tree().process_frame
	var bow := remote.model.find_child("Bow", true, false) as Node3D
	check(bow.is_visible_in_tree(), "Presentation hides weapon equipped after binding empty slot")
	var rendered := false
	for part: MeshInstance3D in bow.find_children("*", "MeshInstance3D", true, false):
		if part.has_meta("equipped_art"):
			rendered = rendered or (part.mesh != null and part.is_visible_in_tree())
	check(rendered, "Equipped weapon has no visible geometry")
	Leisure.players[remote.player_id] = {cup = {kind = "coffee", sips = 3}, cigar = 0.0, use_at = -10.0, realm = ""}
	await get_tree().process_frame
	await get_tree().process_frame
	check(not bow.visible, "Weapon visible through social prop")
	remote.set_look("Test", "archer|G2_bow,G8_cloak,,")
	await get_tree().process_frame
	Leisure.players.erase(remote.player_id)
	await get_tree().process_frame
	await get_tree().process_frame
	check(bow.is_visible_in_tree(), "Weapon not restored after putting down cup")
	remote.set_look("Test", "archer|,G8_cloak,,")
	await get_tree().process_frame
	await get_tree().process_frame
	check(not bow.visible, "Presentation resurrects unequipped weapon")
	remote.free()
	var face := CharacterAvatar.new("wizard")
	face.set_gear({"weapon": null, "armor": {"id": "G8_robe"}})
	get_tree().root.add_child(face)
	await get_tree().process_frame
	check(face._model.get_meta("equipment_key") == "|G8_robe", "Portrait did not apply saved gear")
	face.set_gear({"weapon": "G2_wand", "armor": "G2_robe"})
	check(face._model.get_meta("equipment_key") == "G2_wand|G2_robe", "Account list gear IDs not applied")
	face.set_class("archer")
	face.set_gear({"weapon": null, "armor": null})
	await get_tree().process_frame
	check(face._model.get_meta("equipment_key") == "|", "Portrait did not clear equipment")
	face.queue_free()
	await get_tree().process_frame
	print("Equipment appearance: %d compatible combinations checked; %d failures" % [count, failures])
	get_tree().quit(1 if failures else 0)
