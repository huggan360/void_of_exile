extends "res://tools/test_settlements.gd"
class FloorWorld:
	extends GameWorld
	func ground_height(_x: float, _z: float) -> float:
		return 0.0
class ScareCreature:
	extends Node3D
	func is_alive() -> bool:
		return true

func _test_npc_motion() -> void:
	await super._test_npc_motion()
	var world := FloorWorld.new()
	get_tree().root.add_child(world)
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = Player.TERRAIN_LAYER
	var shape := CollisionShape3D.new()
	var slab := BoxShape3D.new()
	slab.size = Vector3(150, 1, 150)
	shape.shape = slab
	shape.position.y = -0.5
	floor_body.add_child(shape)
	world.add_child(floor_body)
	var town := VillageFeature.plan(Vector2i.ZERO, Biomes.WOODS, 97, -1, true)
	for service in town.service_sites:
		var house: Dictionary = town.houses[service.house]
		var relative := Vector2(service.npc.pos.x - house.pos.x, service.npc.pos.z - house.pos.z).rotated(float(house.yaw))
		check(relative.y < -5, "Shopkeeper's station is outside the closed house")
	for house in town.houses:
		check(FileAccess.file_exists(house.asset + "/body.vox"), "Fine-grained VOX building exists")
		check(house.solid_size.y >= 6.0, "Solid envelope closes both floors")
	var house := VillageHouse.new().setup(town.houses[0])
	world.add_child(house)
	await get_tree().physics_frame
	var query := PhysicsRayQueryParameters3D.create(house.position + Vector3(0, 1, -9), house.position + Vector3(0, 1, 0), Player.OBSTACLE_LAYER)
	check(not world.get_world_3d().direct_space_state.intersect_ray(query).is_empty(), "Closed entrance blocks movement/projectiles")
	var nav := TownNavigation.new(town, world)
	var rng := RandomNumberGenerator.new()
	rng.seed = 199
	var goal := nav.random_goal(rng, true)
	check(not town.bounds.has_point(Vector2i(floori(goal.x), floori(goal.z))), "Residents can choose destinations outside the town")
	var across := nav.path(Vector3(-30, 0, -25), Vector3(30, 0, 25))
	check(across.size() > 30, "Navigation crosses the whole village, not a small plaza loop")
	for point in across:
		for h in town.houses:
			var delta := Vector2(point.x - h.pos.x, point.z - h.pos.z)
			check(maxf(absf(delta.x), absf(delta.y)) > 4, "Town paths do not enter buildings")
	var npc := TownNPC.new().setup({role = "smith", seed = 96, pos = Vector3(0, 0.1, 0), stationary = true, route = [Vector3.ZERO]}, nav)
	world.add_child(npc)
	var director := EnemyDirector.new()
	director.world = world
	world.add_child(director)
	director.set_process(false)
	var monster := Enemy.new().setup(Enemies.get_def("goblin"), EnemyPack.new(), director)
	monster.position = Vector3(0, 0, 7)
	world.add_child(monster)
	monster.set_physics_process(false)
	check(monster.is_in_group("realm_creatures"), "Live enemy registers as a creature threat")
	await get_tree().create_timer(1.5).timeout
	check(npc.scared and npc._alarm.visible, "Even shopkeepers display fear of nearby creatures")
	check(npc.global_position.distance_to(monster.global_position) > 7.5, "Frightened shopkeeper runs away from creature")
	monster.queue_free()
	await get_tree().create_timer(4.5).timeout
	check(not npc.scared, "Resident calms down once the creature is gone")
	world.queue_free()
	await get_tree().process_frame
