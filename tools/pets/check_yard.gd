extends Node3D
## Headless yard layout, artwork and account-state integration check.
var _failures := 0

class EggCarrier:
	extends Node3D
	var stats := PlayerStats.new()

func check(ok: bool, what: String) -> void:
	print("[pet-yard] ", "PASS " if ok else "FAIL ", what)
	if not ok: _failures += 1

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	var world := PetYardWorld.new({id = "pty_42"})
	check(PetYardWorld.id_for(42) == "pty_42" and PetYardWorld.is_pet_yard("pty_42"), "account realm ids")
	check(world.is_walkable(world.spawn_point), "spawn is open")
	check(not world.pet_walkable(Vector3(27, 0, 0)) and not world.is_walkable(Vector3(26, 0, 10)), "fence keeps pets inside")
	check(world.clear_segment(Vector3(24, 0, PetYardWorld.GATE_Z), Vector3(28, world.ground_height(28, PetYardWorld.GATE_Z), PetYardWorld.GATE_Z)), "gate opens onto the trail")
	check(world.is_water(Vector3(0, PetYardWorld.SEA_LEVEL, 80)) and not world.is_walkable(Vector3(0, PetYardWorld.SEA_LEVEL, 70)), "sea around the island")
	check(absf(world.ground_height(64, -37) - PetYardWorld.SHOP_POS.y) < 0.01, "shop floor is level")
	check(not world.is_walkable(Vector3(13, 0, 5)), "pond is closed to walking")
	check(world.clear_segment(Vector3(7, 0, 8), Vector3(19, 0, 8)), "bridge crosses the pond")
	check(not world.clear_segment(Vector3(13, 0, 3), Vector3(13, 0, 13)), "pond cannot be crossed away from the bridge")
	var reachable := _reachable(world)
	for entry in [["Caretaker", PetYardWorld.CARETAKER_POS], ["Pet Store counter", PetYardWorld.STORE_POS + Vector3(0, 0, 3.6)],
		["Nest", PetYardWorld.NEST_POS + Vector3(0, 0, 3)], ["Tavern portal", PetYardWorld.RETURN_PORTAL]]:
		var at: Vector3 = entry[1]
		check(reachable.has(Vector2i(roundi(at.x), roundi(at.z))), "%s reachable from spawn" % entry[0])
	var generator := PetYardTerrain.new()
	var buf := VoxelBuffer.new()
	buf.create(16, 16, 32)
	generator._generate_block(buf, Vector3i(48, -8, 16), 0)
	check(buf.get_voxel(4, 7, 16, VoxelBuffer.CHANNEL_TYPE) == SurfaceBlocks.PLANKS, "bridge has a voxel deck")
	check(buf.get_voxel(4, 7, 4, VoxelBuffer.CHANNEL_TYPE) == Blocks.AIR, "pond is dug into the terrain")
	var server_world := PetYardWorld.new({id = "pty_43"})
	server_world.server_build = true
	add_child(server_world)
	check(server_world.get_child_count() == 0 and server_world.terrain == null, "dedicated server needs only layout data")
	server_world.free()
	var state := PetDefs.empty_state()
	var rng := RandomNumberGenerator.new()
	for species: String in PetDefs.SPECIES:
		var pet := PetDefs.random_pet(rng)
		pet.id = state.next_id
		pet.species = species
		pet.name = PetDefs.SPECIES[species].name
		pet.rarity = "rare" if int(pet.id) % 3 == 0 else "divine" if int(pet.id) % 3 == 1 else "common"
		state.next_id += 1
		state.pets.append(pet)
	PetsClient.receive(state)
	add_child(world)
	var residents: Node3D
	for child in world.get_children():
		if child.get_script() == PetYardWorld.RESIDENTS: residents = child
	check(is_instance_valid(residents), "yard props and residents build headlessly")
	if not is_instance_valid(residents):
		get_tree().quit(1)
		return
	check(residents._wanderers.size() == 15, "all unequipped species wander")
	var stayed_open := true
	for frame in 600:
		for wanderer: PetYardWanderer in residents._wanderers.values():
			wanderer._process(1.0 / 30)
			if not world.pet_walkable(wanderer.position): stayed_open = false
	check(stayed_open, "wandering stays clear of pond, fence and furniture")
	state.equipped = 1
	PetsClient.receive(state)
	check(not residents._wanderers.has(1) and residents._wanderers.size() == 14, "equipped pet leaves the meadow")
	state.equipped = 0
	PetsClient.receive(state)
	check(residents._wanderers.has(1), "unequipped pet returns to play")
	var actor := EggCarrier.new()
	add_child(actor)
	actor.position = PetYardWorld.NEST_POS + Vector3(0, 0, 3)
	check(not residents._nest.available(actor), "nest requires an egg")
	actor.stats.backpack[0] = Items.make("pet_egg")
	check(residents._nest.available(actor), "egg enables nest interaction")
	residents._hatch()
	var newborn := PetDefs.random_pet(rng)
	newborn.id = state.next_id
	state.next_id += 1
	state.pets.append(newborn)
	PetsClient.receive(state)
	check(not residents._wanderers.has(int(newborn.id)), "new pet waits for the shell to crack")
	residents._hatch_time = 1.6
	residents._process(0.01)
	check(residents._wanderers.has(int(newborn.id)) and not residents._hatching, "new pet pops out after account confirmation")
	check(Shops.DEFS.has("pets") and Shops.fallback().shops.pets.stock[0].id == "pet_egg", "Pet Store uses the pets shop")
	_check_store_camera(world)
	world.free()
	actor.free()
	PetsClient.receive(PetDefs.empty_state())
	await get_tree().process_frame
	print("[pet-yard] complete failures=", _failures)
	get_tree().quit(1 if _failures else 0)

func _check_store_camera(world: PetYardWorld) -> void:
	var player := Player.new()
	player.stats = PlayerStats.new()
	player.frozen = false
	add_child(player)
	player.add_child(player.aim_marker)
	player.set_physics_process(false)
	player.set_spatial_world(world)
	var view := player.ground_view
	var indoors := Vector3(64, 1, -33)
	var outdoors := Vector3(64, 1, -30)
	check(world.first_person_at(indoors) and world.first_person_at(Vector3(64, 1, -31.1)), "store room and doorway force first person")
	check(not world.first_person_at(outdoors) and not world.first_person_at(indoors + Vector3(0, 6, 0)), "square and rooftop keep the outdoor view")
	for mode in 2:
		view.camera_mode = mode
		player.position = outdoors
		player._update_camera(1.0 / 60)
		check(view.first_person == 0.0 and player.model.visible, "outdoor mode %d shows the player" % mode)
		player.position = indoors
		player._update_camera(1.0 / 60)
		check(view.free_look() and view.first_person == 1.0 and not player.model.visible, "entering from mode %d forces first person" % mode)
		check(player.camera.global_position.distance_to(indoors + Vector3(0, 1.57, 0)) < 0.01, "indoor camera stays at eye height")
		check(not player.status_visuals.visible and not player.aura.visible, "first person hides local equipment effects")
		check(view._sight.mode == "fp", "indoor view enables mouse aiming and crosshair")
		view._see_through = 1.0
		view._process(1.0)
		check(view._see_through == 0.0 and view._focus_distance == -1.0, "first person closes the see-through window and ground focus")
		player.ui_blocked = true
		player._update_camera(1.0 / 60)
		check(view.first_person == 1.0 and view._sight.mode == "", "shop UI keeps first person and releases aiming")
		player.ui_blocked = false
		player.position = outdoors
		player._update_camera(1.0 / 60)
		check(view.camera_mode == mode and view.first_person == 0.0 and view.free_look() == (mode != 0) and player.model.visible, "leaving restores outdoor mode %d" % mode)
	player.position = indoors
	player._update_camera(1.0 / 60)
	var roofs := 0
	var roof_visible := true
	for child in world.get_children():
		if child.get_script() != PetYardWorld.ISLAND_ART: continue
		child._process(1.0 / 60)
		for mesh in child.get_children():
			if mesh is MeshInstance3D and mesh.mesh.resource_path.begins_with("res://scenes/vesperis/pet_store_roof"):
				roofs += 1
				roof_visible = roof_visible and mesh.visible
	check(roofs > 0 and roof_visible, "store roof meshes stay visible with the player inside")
	player.set_spatial_world(null)
	player.free()

func _reachable(world: PetYardWorld) -> Dictionary:
	var start := Vector2i(roundi(world.spawn_point.x), roundi(world.spawn_point.z))
	var found := {start: true}
	var todo: Array[Vector2i] = [start]
	var index := 0
	while index < todo.size():
		var at := todo[index]
		index += 1
		for step in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next: Vector2i = at + step
			if found.has(next) or not world.is_walkable(Vector3(next.x, world.ground_height(next.x, next.y), next.y)): continue
			found[next] = true
			todo.append(next)
	return found
