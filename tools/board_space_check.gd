extends "res://scripts/main.gd"
## Headless: board a ship at the Nexus and walk in its room (compare with the Surface).
func _parse_args() -> void:
	super._parse_args()
	_args.erase("online")
	_args["play-space"] = ""

func _ready() -> void:
	super._ready()
	_run.call_deferred()

func _run() -> void:
	while not (world is SpaceWorld) or _traversing() or player.frozen or not world.is_presentation_ready(): await get_tree().process_frame
	var space := world as SpaceWorld
	await get_tree().create_timer(1.0).timeout
	var ship: SpaceShip = space._launch_ship(player.player_id, "You")
	player.global_position = space.spawn_point
	space.request(["board", ship.id])
	await get_tree().create_timer(1.0).timeout
	# Under way at speed, turning: the room must not care.
	ship.mode = "flying"
	ship.speed = 220.0
	ship.velocity = -ship.xform.basis.z*220.0
	ship.input = [1.0, 0.6, 0.2, 0.3, true, false]
	ship.input_age = -100.0
	await get_tree().create_timer(0.5).timeout
	var a := player.global_position
	var steps: Array[float] = []
	var last := a
	player.debug_input = Vector2(0, -1)
	for i in 30:
		await get_tree().physics_frame
		steps.append(player.global_position.distance_to(last))
		last = player.global_position
	print("[board-space] ship speed ", roundi(ship.speed), " moved ", roundi(ship.xform.origin.length()), " m from origin; walk steps min %.3f max %.3f" % [steps.min(), steps.max()])
	await get_tree().create_timer(1.0).timeout
	player.debug_input = Vector2.ZERO
	print("[board-space] walked ", a.distance_to(player.global_position), " from ", a)
	get_tree().quit()

func _traversing() -> bool:
	return player.spatial_controller is SpaceTraversal and (player.spatial_controller as SpaceTraversal).cinematic
