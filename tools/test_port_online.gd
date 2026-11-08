extends "res://scripts/main.gd"
## Online check of the way between the Surface and Space (a --test server, p2):
## buy and launch at the pad, arrive at the helm, descend, land on the pad,
## the realm gate's return rules (hometown after the Surface, the same spot
## after Space).
var _failures := 0

func _parse_args() -> void:
	super._parse_args()
	# This scene owns completion; the generic online screenshot path must wait.
	_args["online-wait"] = "1000"
	_args["space-test"] = ""  # The dedicated scene, rather than the generic online path, owns quitting.

func _ready() -> void:
	super._ready()
	_run.call_deferred()
	get_tree().create_timer(420.0).timeout.connect(func() -> void:
		print("[port-online] TIMEOUT")
		get_tree().quit(2))

func check(ok: bool, what: String) -> void:
	print("[port-online] ", "PASS " if ok else "FAIL ", what)
	if not ok: _failures += 1

func _wait(cond: Callable, seconds: float) -> bool:
	var until := Time.get_ticks_msec()+int(seconds*1000.0)
	while not cond.call() and Time.get_ticks_msec()<until: await get_tree().process_frame
	return cond.call()

func _settled() -> bool:
	return is_instance_valid(world) and not _traveling and not player.frozen and world.is_presentation_ready()

func _to_surface_pad() -> IslandWorld:
	travel("realm_1")
	await _wait(func() -> bool: return world is IslandWorld and _settled(), 60.0)
	var island := world as IslandWorld
	if island==null:
		check(false, "Surface travel did not finish")
		get_tree().quit(1)
		return null
	player.global_position = island.launchpad_arrival()
	player.velocity = Vector3.ZERO
	await get_tree().create_timer(1.5).timeout
	return island

func _launch(island: IslandWorld) -> void:
	Net.client.send_action("port", ["board"])
	if not await _wait(func() -> bool: return SpaceLayout.pocket_at(player.global_position)>=0 and player.spatial_controller is SpaceTraversal, 10.0):
		check(false, "reboarding reaches the interior")
		get_tree().quit(1)
		return
	# Let the first post-correction position snapshot reach the authority.
	await get_tree().create_timer(0.5).timeout
	Net.client.send_action("port", ["ship", ["sit", "pilot"]])
	if not await _wait(func() -> bool: return island.surface_ships.ship_of(player.player_id)!=null, 5.0):
		check(false, "pilot seat is replicated on the Surface (position %s, ships %s)" % [player.global_position, island.surface_ships.ships.values().map(func(s: SpaceShip) -> Array: return [s.id, s.owner, s.mode, s.crew])])
		get_tree().quit(1)
		return
	check(true, "pilot seat is replicated on the Surface")
	Net.client.send_action("port", ["ship", ["pilot", [1.0, 0.0, 0.0, 0.0, false, false]]])
	await get_tree().create_timer(0.4).timeout
	check(world is IslandWorld and island.surface_ships.ship_of(player.player_id).mode=="landed", "thrust alone does not launch a grounded ship")
	var key := InputEventKey.new()
	key.physical_keycode = KEY_SPACE
	key.pressed = true
	(player.spatial_controller as SpaceTraversal)._input(key)
	await _wait(func() -> bool: return world is SpaceWorld and _settled(), 60.0)
	var traversal := player.spatial_controller as SpaceTraversal
	await _wait(func() -> bool: return traversal != null and not traversal.cinematic, 15.0)

func _run() -> void:
	await _wait(func() -> bool: return Net.is_client() and Net.client.connected and _settled(), 60.0)
	await get_tree().create_timer(1.0).timeout
	var island := await _to_surface_pad()
	check(is_instance_valid(island.launchpad) and island.launchpad.unlocked, "the Surface has the launch pad, open (test mode)")
	Net.client.send_action("port", ["buy"])
	check(await _wait(func() -> bool: return island.launchpad.owned, 8.0), "buying the battleship at the pad")
	# Exercise boarding and disembarking before the actual launch.
	Net.client.send_action("port", ["board"])
	check(await _wait(func() -> bool: return SpaceLayout.pocket_at(player.global_position)>=0 and player.spatial_controller is SpaceTraversal, 10.0), "boarding enters the first-person ship interior")
	Net.client.send_action("port", ["ship", ["takeoff"]])
	await get_tree().create_timer(0.4).timeout
	check(world is IslandWorld, "an occupant without the pilot seat cannot launch")
	Net.client.send_action("port", ["ship", ["hatch"]])
	check(await _wait(func() -> bool: return SpaceLayout.pocket_at(player.global_position)<0, 5.0), "the hatch lets us disembark on the Surface")
	await get_tree().create_timer(0.5).timeout
	await _launch(island)
	if not world is SpaceWorld:
		check(false, "launch reaches Space")
		get_tree().quit(1)
		return
	var space := world as SpaceWorld
	var ship := space.ship_of(player.player_id) if space else null
	check(ship != null and ship.pilot() == player.player_id, "launched: aboard at the helm in Space")
	check(ship != null and ship.xform.origin.distance_to(SpaceLayout.ASCENT) < 400.0, "the ship rises where Surface ships come up")
	await _shot("space_helm")
	# Dive down to the descent height on the helm.
	var until := Time.get_ticks_msec()+60000
	while ship and ship.xform.origin.y > SpaceLayout.DESCEND_HEIGHT-200.0 and Time.get_ticks_msec() < until:
		var to := Vector3.DOWN
		var local := ship.xform.basis.inverse()*to
		space.request(["pilot", [1.0, clampf(local.x*3.0, -1, 1), clampf(local.y*3.0, -1, 1), 0.0, true]])
		await get_tree().create_timer(0.05).timeout
	space.request(["pilot", [0.0, 0.0, 0.0, 0.0, false]])
	check(ship != null and SpaceLayout.can_descend(ship.xform.origin), "flew low over the Surface (y %d)" % (ship.xform.origin.y if ship else 0))
	space.request(["descend"])
	await _wait(func() -> bool: return world is IslandWorld and _settled(), 60.0)
	check(world is IslandWorld, "descending lands us on the Surface")
	if world is IslandWorld:
		var pad := (world as IslandWorld).launchpad_arrival()
		await get_tree().create_timer(6.0).timeout
		check(SpaceLayout.pocket_at(player.global_position)>=0, "still aboard the ship after landing on the Surface")
	await _shot("surface_landed_interior")
	# Surface last: the gate goes to the hometown, not Space.
	travel("hall")
	await _wait(func() -> bool: return Campaigns.is_tavern(world.realm_id) and _settled(), 60.0)
	travel("realm_1")
	await _wait(func() -> bool: return not Campaigns.is_tavern(world.realm_id) and _settled(), 60.0)
	check(world is IslandWorld, "after the Surface, the realm gate leads to the Surface")
	# Space last: the gate goes back to the same spot in Space.
	island = await _to_surface_pad()
	await _launch(island)
	var before := player.global_position
	travel("hall")
	await _wait(func() -> bool: return Campaigns.is_tavern(world.realm_id) and _settled(), 60.0)
	travel("realm_1")
	await _wait(func() -> bool: return not Campaigns.is_tavern(world.realm_id) and _settled(), 60.0)
	check(world is SpaceWorld, "after Space, the realm gate leads back to Space")
	await get_tree().create_timer(1.0).timeout
	check(world is SpaceWorld and SpaceLayout.pocket_at(player.global_position) >= 0, "back aboard the ship (%s)" % SpaceLayout.pocket_at(player.global_position))
	check(world is SpaceWorld and player.global_position.distance_to(before) < 3.0, "returned to the saved position aboard (%.1f m)" % player.global_position.distance_to(before))
	print("[port-online] done failures=", _failures, " (was at ", before, ")")
	get_tree().quit(0 if _failures == 0 else 1)

func _shot(label: String) -> void:
	if DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/home/hugo/godot/tmp/session_qa/shots/%s.png" % label)
