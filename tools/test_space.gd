extends "res://scripts/main.gd"
## Offline Astral Reach smoke test: launch, board, sit, fly, land, step out,
## gunnery and the space map. Screenshots go to --shots=<dir> (default /tmp).
var _out := "/tmp"
var _failures := 0

func _parse_args() -> void:
	super._parse_args()
	_args.erase("online")
	_args["play-space"] = ""

func _ready() -> void:
	super._ready()
	_out = str(_args.get("shots", "/tmp"))
	_run.call_deferred()

func check(ok: bool, what: String) -> void:
	print("[space] ", "PASS " if ok else "FAIL ", what)
	if not ok: _failures += 1

func _shot(name: String, frames := 30) -> void:
	for i in frames: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/space_%s.png" % [_out, name])

func _run() -> void:
	GameServer.debug_godmode = true
	while not (world is SpaceWorld) or player.frozen or not world.is_presentation_ready(): await get_tree().process_frame
	var space := world as SpaceWorld
	var traversal := player.spatial_controller as SpaceTraversal
	check(traversal!=null, "space traversal drives the player")
	check(space.zone_at(player.global_position)=="station", "arrival on the Nexus deck")
	await _shot("nexus", 60)
	traversal.play_intro()
	await get_tree().create_timer(6.0).timeout
	await _shot("intro", 2)
	while traversal.cinematic: await get_tree().process_frame
	space.request(["spawn"])
	check(space.ships.size()==1, "command table launches a ship")
	var ship: SpaceShip = space.ships.values()[0]
	space.request(["board", ship.id])
	await get_tree().process_frame
	check(SpaceLayout.pocket_at(player.global_position)==ship.slot, "boarding moves the player into the ship room")
	player.camera_yaw = 0.0
	await _shot("interior", 60)
	space.request(["sit", "pilot"])
	check(ship.pilot()==player.player_id, "player takes the helm")
	await _shot("berth_chase", 40)
	# Take off, then fly toward Verdance for a few seconds.
	var verdance := SpaceLayout.planet("verdance")
	var t := 0.0
	while t<6.0:
		t += get_process_delta_time()
		var to: Vector3 = verdance.center-ship.xform.origin
		var local := ship.xform.basis.inverse()*to.normalized()
		ship.input = [1.0, clampf(local.x*3.0, -1, 1), clampf(local.y*3.0, -1, 1), 0.0, true]
		ship.input_age = 0.0
		await get_tree().process_frame
	check(ship.mode=="flying" and ship.speed>50.0, "the ship takes off and flies (speed %d)" % ship.speed)
	await _shot("flight", 2)
	traversal._cockpit = true
	await _shot("cockpit", 20)
	traversal._cockpit = false
	# Jump the ship beside Verdance's pad and land.
	var pad := SpaceShip.landed_pose(verdance)
	ship.xform = Transform3D(pad.basis, pad.origin+pad.basis.y*120.0)
	ship.speed = 20.0
	ship.velocity = Vector3.ZERO
	await get_tree().create_timer(0.3).timeout
	check(not ship.landable().is_empty(), "Verdance is landable near its pad")
	space.request(["land"])
	var waited := 0.0
	while ship.mode!="landed" and waited<20.0:
		waited += get_process_delta_time()
		await get_tree().process_frame
	check(ship.mode=="landed" and ship.planet=="verdance", "the ship lands on Verdance")
	await _shot("landed", 10)
	space.request(["stand"])
	space.request(["hatch"])
	await get_tree().create_timer(0.5).timeout
	check(space.zone_at(player.global_position)=="planet:verdance", "the hatch lets the crew out onto Verdance")
	await get_tree().create_timer(1.5).timeout
	check(space.zone_at(player.global_position)=="planet:verdance", "the crew stays on the planet (%s)" % space.zone_at(player.global_position))
	await _shot("planet", 30)
	# Walk a little on the curved ground.
	player.debug_input = Vector2(0, -1)
	await get_tree().create_timer(2.0).timeout
	player.debug_input = Vector2.ZERO
	check(space.zone_at(player.global_position)=="planet:verdance", "walking on the round planet keeps its gravity")
	await _shot("planet_walk", 10)
	player.global_position = space.hatch_position(ship)
	space.request(["board", ship.id])
	check(SpaceLayout.pocket_at(player.global_position)==ship.slot, "boarding again from the planet")
	space.request(["sit", "turret_left"])
	ship.mode = "flying"
	ship.xform = Transform3D(Basis.IDENTITY, SpaceLayout.SHARDFIELD.center+Vector3(300, -80, -900))
	space.foes.ambushes.append({at = ship.xform.origin+Vector3(-300, 0, 0), kind = "brood_skiff", count = 4})
	await get_tree().create_timer(3.0).timeout
	check(not space.foes.foes.is_empty(), "brood skiffs gather near a flying ship")
	for i in 10:
		space.request(["fire", Vector3.LEFT])
		await get_tree().create_timer(0.25).timeout
	await _shot("turret", 2)
	space.request(["stand"])
	traversal.toggle_map()
	await _shot("map", 10)
	traversal.toggle_map()
	space.request(["home"])
	await get_tree().process_frame
	check(space.zone_at(player.global_position)=="station", "R (home) returns to the Nexus")
	print("[space] camera distance ", player.camera_distance, " camera height ", player.camera.global_position.y)
	await _shot("nexus_return", 90)
	player.camera_distance = 22.0
	await _shot("nexus_far", 60)
	print("[space] smoke complete failures=", _failures)
	get_tree().quit()
