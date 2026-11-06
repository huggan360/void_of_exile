extends Node
## Run with --headless --path . res://tools/test_town_npc_placement.tscn.
## Builds the baked realm's actual streamed buildings, props, trees and NPCs.
var checks := 0
var failures := 0

func _ready() -> void:
	_run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func _run() -> void:
	var world := IslandWorld.new({id = "town_npc_fixture", seed = 20261031, destroyed = []})
	add_child(world)
	world.set_process(false)
	world.enemy_director.set_process(false)
	world.enemy_director.set_physics_process(false)
	check(not world.generator.villages.is_empty(), "Baked realm contains towns")
	var count := 0
	for town in world.generator.villages:
		var low := world._chunk_of(Vector3(town.center.x - town.radius - 12, 0, town.center.y - town.radius - 12))
		var high := world._chunk_of(Vector3(town.center.x + town.radius + 12, 0, town.center.y + town.radius + 12))
		for z in range(low.y, high.y + 1):
			for x in range(low.x, high.x + 1):
				var chunk := Vector2i(x, z)
				if not world._chunks.has(chunk):
					world._build_chunk(chunk)
		for npc in world.find_children("*", "TownNPC", true, false):
			npc.set_physics_process(false)
		await get_tree().physics_frame
		await get_tree().physics_frame
		var nav: TownNavigation = world._town_navigation[town.display_name]
		var plaza := nav._node(Vector3(town.center.x + 0.5, 0, town.center.y + 0.5))
		var stewards := 0
		var before := count
		for npc: TownNPC in world.find_children("*", "TownNPC", true, false):
			if npc.spec.village != town.display_name:
				continue
			count += 1
			stewards += 1 if npc.spec.role == "steward" else 0
			var at := npc.global_position
			var label := "%s %s at %s" % [town.display_name, npc.spec.role, at]
			check(world.is_walkable(at) and not world.is_hazard(at), "Walkable ground: " + label)
			check(is_equal_approx(at.y, world.ground_height(at.x, at.z)), "Feet on terrain: " + label)
			var cell := Vector2i((Vector2(at.x, at.z) - nav.origin).floor())
			check(nav.grid.is_in_boundsv(cell) and not nav.grid.is_point_solid(cell), "Open navigation cell: " + label)
			check(not nav.grid.get_id_path(plaza, cell).is_empty(), "Reachable from plaza: " + label)
			var capsule := CapsuleShape3D.new()
			capsule.radius = 0.3
			capsule.height = 1.3
			var query := PhysicsShapeQueryParameters3D.new()
			query.shape = capsule
			query.transform = Transform3D(Basis.IDENTITY, at + Vector3.UP * 0.7)
			query.collision_mask = Player.OBSTACLE_LAYER
			var hits := world.get_world_3d().direct_space_state.intersect_shape(query)
			check(hits.is_empty(), "No building/obstacle collider overlap: " + label)
			if npc.spec.role == "steward":
				check(Vector2(at.x - town.center.x, at.z - town.center.y).length() <= town.plaza_radius + 1, "Steward stays at plaza: " + label)
		check(stewards == 1, "Exactly one steward in " + town.display_name)
		check(count - before == town.residents.size(), "Every planned NPC instantiated in " + town.display_name)
	_test_facing(world)
	print("TOWN NPC PLACEMENT: %d NPCs, %d checks, %d failures" % [count, checks, failures])
	world.queue_free()
	await get_tree().process_frame
	get_tree().quit(1 if failures else 0)

## Exercise the ordinary and server-mirrored story actor conversation branches.
func _test_facing(world: IslandWorld) -> void:
	var listener := Node3D.new()
	world.add_child(listener)
	for story in [false, true]:
		var at := world.spawn_point
		var npc := TownNPC.new().setup({role = "traveler", seed = 1, pos = at, stationary = true,
			route = [at], yaw = 0.0, story = story, mirror = true})
		world.add_child(npc)
		npc.set_physics_process(false)
		listener.global_position = at + Vector3.RIGHT * 4
		npc.listen_to(listener)
		npc._physics_process(0.05)
		check(npc.model.rotation.y < 0.0 and npc.model.rotation.y > -PI * 0.5, "Conversation turns smoothly, story=" + str(story))
		for i in 30:
			npc._physics_process(0.05)
		check(absf(angle_difference(npc.model.rotation.y, -PI * 0.5)) < 0.01, "Faces listener, story=" + str(story))
		listener.global_position = at + Vector3.LEFT * 4
		for i in 30:
			npc._physics_process(0.05)
		check(absf(angle_difference(npc.model.rotation.y, PI * 0.5)) < 0.01, "Tracks moving listener, story=" + str(story))
		check(npc.global_position == at and npc.velocity == Vector3.ZERO, "Conversation keeps actor in place, story=" + str(story))
		npc.listen_to(null)
		if story:
			for i in 30:
				npc._physics_process(0.05)
			check(absf(npc.model.rotation.y) < 0.01, "Story mirror returns to server yaw after dialogue")
		npc.queue_free()
	listener.queue_free()
