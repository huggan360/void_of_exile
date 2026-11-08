extends "res://scripts/main.gd"
## Headless: board a ship on the Surface pad, try to walk inside, get out.
func _parse_args() -> void:
	super._parse_args()
	_args.erase("online")
	_args["shot"] = ""
	_args["world"] = "realm"

func _take_screenshot() -> void:
	pass

func _ready() -> void:
	super._ready()
	_run.call_deferred()

func _run() -> void:
	while not is_instance_valid(world) or _traveling or player.frozen: await get_tree().process_frame
	var island := world as IslandWorld
	var ships := island.surface_ships
	var me := {player_id = player.player_id, peer_id = 0, pos = player.global_position, name = "You", account_id = 0}
	var ship := ships.ensure_ship(me)
	player.global_position = island.launchpad_arrival()
	for i in 3:
		await get_tree().physics_frame
		var hits := []
		for k in player.get_slide_collision_count():
			var c := player.get_slide_collision(k)
			hits.append([c.get_collider(), c.get_normal(), c.get_position()])
		print("[board] frame pos ", player.global_position, " real ", player.get_real_velocity(), " hits ", hits)
	await get_tree().create_timer(1.0).timeout
	print("[board] ship ", ship.id if ship else -1, " mode ", ship.mode if ship else "", " slot ", ship.slot if ship else -1)
	ships.request(["board", ship.id])
	var probe := Probe.new()
	probe.player = player
	add_child(probe)
	await get_tree().create_timer(1.0).timeout
	var a := player.global_position
	print("[board] in pocket ", SpaceLayout.pocket_at(a), " at ", a, " frozen ", player.frozen, " locked ", player.controls_locked(), " floor ", player.is_on_floor(), " walkable ", island.is_walkable(a), " controller ", player.spatial_controller)
	player.debug_input = Vector2(0, -1)
	await get_tree().create_timer(0.3).timeout
	probe.active = true
	await get_tree().create_timer(0.08).timeout
	probe.active = false
	await get_tree().create_timer(0.12).timeout
	var tr = player.spatial_controller
	print("[board] mid: vel ", player.velocity, " seat '", tr.seat, "' cinematic ", tr.cinematic, " spacewalk ", tr.spacewalk, " zone ", world.surface_ships.zone_at(player.global_position), " mode ", tr.camera_mode, " locked ", player.controls_locked(), " interacting ", player.interacting(), " input_locked ", player.input_locked, " cin_locked ", player.cinematic_locked)
	await get_tree().create_timer(1.0).timeout
	player.debug_input = Vector2.ZERO
	print("[board] walked ", a.distance_to(player.global_position), " m to ", player.global_position)
	ships.request(["hatch"])
	await get_tree().create_timer(1.5).timeout
	var p := player.global_position
	print("[board] out at ", p, " ground ", island.ground_height(p.x, p.z), " floor ", player.is_on_floor(), " frozen ", player.frozen)
	get_tree().quit()


class Probe extends Node:
	var player: Node3D
	var active := false
	var first := Node.new()
	func _ready() -> void:
		process_physics_priority = 1000
		process_priority = 1000
	func _physics_process(_d: float) -> void:
		if active:
			var b := player as CharacterBody3D
			var hits := []
			for k in b.get_slide_collision_count(): hits.append([b.get_slide_collision(k).get_collider(), b.get_slide_collision(k).get_normal()])
			print("[board] physics end ", b.global_position, " vel ", b.velocity, " real ", b.get_real_velocity(), " floor ", b.is_on_floor(), " phys ", b.is_physics_processing(), " mode ", b.process_mode, " hits ", hits)
	func _process(_d: float) -> void:
		if active: print("[board] process end ", player.global_position)
