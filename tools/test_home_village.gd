extends Node
var failures := 0
var checks := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func _ready() -> void:
	_run.call_deferred()
func _run() -> void:
	var packed := load("res://scenes/home/tavern.tscn") as PackedScene
	check(packed != null, "Fixed authored home scene loads")
	var home := packed.instantiate() as HallWorld
	# Prove editor changes to stations, spawn and buildings survive instancing.
	home.get_node("Spawn").position.x = 2
	var first: Node3D = home.get_node("Buildings").get_child(0)
	first.position.x += 1
	add_child(home)
	check(home.spawn_point.x == 2, "Home uses edited Spawn marker")
	check(home.spawn_point.z < home.get_node("Fountain").position.z, "Arrival is north of fountain")
	var land := 0
	for z in range(-HomeTerrain.EXTENT, HomeTerrain.EXTENT + 1):
		for x in range(-HomeTerrain.EXTENT, HomeTerrain.EXTENT + 1):
			land += 1 if home.home_terrain.is_land(x, z) else 0
	check(land >= 45 * 45 * 10, "Home island exceeds ten old taverns")
	check(home.home_terrain.is_land(0, -104) and not home.home_terrain.is_land(0, -128), "Realm gate stands on the northern headland")
	check(home.home_terrain.has_deck(-90, 0) and home.is_walkable(Vector3(-90, 9, 0)), "Harbor pier is walkable over the water")
	check(home.ground_height(0, 0) == HomeTerrain.FLOOR + 1 and home.ground_height(0, -125) < HomeTerrain.BEACH, "Town plateau with beaches and sea floor")
	check(home.home_terrain.block(0, 40) == Blocks.GRAVEL or home.home_terrain.block(0, 40) == Blocks.PAVING, "Garden walk is paved from its scene curve")
	check(home.get_node("Buildings").get_child_count() >= 26, "Large village has at least 26 fixed buildings")
	check(home.get_node("Residents").get_child_count() == home.residents.size(), "Every editable resident marker becomes a resident")
	check(home.get_node("Buildings/Chapel") != null, "Chapel is an authored building")
	check(home.get_node("CoastWater") is MeshInstance3D and not home.is_walkable(Vector3(130, 10, 0)), "Water bounds the playable island")
	var patches := get_tree().get_nodes_in_group("home_ground_decor")
	check(patches.size()>40,"Tavern ground decor uses small spatial patches")
	var decor_count := 0
	for patch: MultiMeshInstance3D in patches:
		check(patch.visibility_range_end==0,"Grass cannot vanish at a distance from the island center")
		var bounds := patch.multimesh.custom_aabb
		check(bounds.size.x<40 and bounds.size.z<40,"Grass patch has tight local culling bounds")
		decor_count += patch.multimesh.instance_count
	check(decor_count>1000,"Grass density remains intact")
	for edge in [Vector3(80,10,0),Vector3(-80,10,0),Vector3(0,10,80),Vector3(0,10,-80)]:
		var nearby := false
		for patch: MultiMeshInstance3D in patches:
			var center := patch.position+patch.multimesh.custom_aabb.get_center()
			if Vector2(center.x-edge.x,center.z-edge.z).length()<40: nearby = true
		check(nearby,"Ground decor remains distributed toward every town edge")
	var shapes := home.find_children("*", "CollisionShape3D", true, false)
	check(shapes.size() > 70, "Buildings and garden props have solid collision")
	for building in home.get_node("Buildings").get_children():
		check(not building.find_children("*", "MeshInstance3D", true, false).is_empty(), "Building geometry is serialized and visible in editor")
		check(not building.find_children("*", "StaticBody3D", true, false).is_empty(), "Closed house has authored solid envelope")
	var route := home.navigation.path(Vector3(-22,10,-60), Vector3(22,10,60))
	check(route.size() > 90, "Residents navigate across the whole new village")
	for point in route:
		check(home.is_walkable(point), "Town paths avoid water")
	var map_thread := Thread.new()
	map_thread.start(home.map_color.bind(0, 0))
	check(map_thread.wait_to_finish() == Color(.3, .7, .85), "Minimap reads immutable geometry safely on a worker thread")
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for i in 40:
		check(home.is_walkable(home.navigation.random_goal(rng)), "Resident destinations stay on land")
	var flow: Node3D = home.get_node("Fountain/CascadingWater")
	var before: Vector3 = flow.drop_position(0)
	flow._process(.4)
	check(before != flow.drop_position(0), "Fountain animates individual voxel water drops")
	var player := Player.new()
	player.player_id = GameServer.join(false)
	player.stats = GameServer.character(player.player_id)
	add_child(player)
	player.set_physics_process(false)
	player.set_process(false)
	player.frozen = false
	var card := InteractionCard.new()
	add_child(card)
	card.set_meta("player", player)
	card.set_world(home)
	var targets := get_tree().get_nodes_in_group("interaction_targets")
	check(targets.size() == 5, "Smith, magician, chronicler, gardener and innkeeper expose outdoor interactions")
	for target: InteractionTarget in targets:
		var keeper := target.get_parent() as TownNPC
		player.global_position = target.global_position + Vector3(2,0,0)
		card.update_prompt(player, false)
		check(card.visible and card.target == target and card._portrait.texture != null, "Nearby service shows portrait card")
		card.accept()
		check(card.opened and card._message.text == target.response, "Accept opens the selected NPC greeting")
		var escape := InputEventKey.new()
		escape.keycode = KEY_ESCAPE
		escape.pressed = true
		check(card.handle_input(escape) and not card.opened, "Escape closes conversation before main menu")
		card.update_prompt(player, false)
		keeper.scared = true
		card.accept()
		check(not card.opened, "Scared shopkeeper cannot be activated")
		keeper.scared = false
		card.update_prompt(player, false)
		player.global_position += Vector3(15,0,0)
		card.accept()
		check(not card.opened, "Stale prompt rechecks distance before accepting")
		player.global_position = target.global_position + Vector3(2,0,0)
		card.update_prompt(player, false)
		card.accept()
		player.global_position += Vector3(15,0,0)
		card.update_prompt(player, false)
		check(not card.visible and not card.opened, "Walking away closes conversation")
	player.global_position = targets[0].global_position + Vector3(2,0,0)
	card.update_prompt(player, false)
	card.accept()
	card.set_world(null)
	check(not card.visible and card.target == null and not card.opened, "Travel clears interaction safely")
	# Any prop can reuse the same target, outside NPC code.
	var prop := InteractionTarget.new()
	prop.position = Vector3(0,10,20)
	home.add_child(prop)
	player.global_position = prop.global_position
	card.set_world(home)
	card.update_prompt(player, false)
	check(card.target == prop and card.visible, "Generic prop uses the same interaction framework")
	prop.free()
	card.accept()
	check(not card.visible, "Freed interaction targets are safe")
	player.free()
	card.free()
	home.queue_free()
	await get_tree().process_frame
	print("HOME VILLAGE: ", checks, " checks; ", failures, " failures")
	get_tree().quit(1 if failures else 0)
