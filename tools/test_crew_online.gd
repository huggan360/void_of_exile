extends "res://scripts/main.gd"
## Online crew check, one process per player (--role=pilot|walker|rope|boots):
## the pilot takes a ship out on the Surface, the crew boards, she launches
## to Space and flies forward; the walker strolls her room, the rope crew
## spacewalks on the line, the boots crew stands on her deck. Each reports
## whether they kept up with her smoothly (no snaps, no falling behind).
var role := "pilot"
var _failures := 0

func _parse_args() -> void:
	super._parse_args()
	_args["space-test"] = ""
	role = str(_args.get("role", "pilot"))

func _ready() -> void:
	super._ready()
	_run.call_deferred()
	get_tree().create_timer(300.0).timeout.connect(func() -> void:
		print("[crew-%s] TIMEOUT" % role)
		get_tree().quit(2))

func check(ok: bool, what: String) -> void:
	print("[crew-%s] %s %s" % [role, "PASS" if ok else "FAIL", what])
	if not ok: _failures += 1

func _wait(cond: Callable, seconds: float) -> bool:
	var until := Time.get_ticks_msec()+int(seconds*1000.0)
	while not cond.call() and Time.get_ticks_msec()<until: await get_tree().process_frame
	return cond.call()

func _settled() -> bool:
	return is_instance_valid(world) and not _traveling and not player.frozen and world.is_presentation_ready()

class Probe extends Node:
	var data := {}
	func receive(value: Dictionary) -> void: data = value

func _fleet(args: Array) -> Dictionary:
	var probe: Probe = get_node_or_null("FleetProbe")
	if probe == null:
		probe = Probe.new()
		probe.name = "FleetProbe"
		add_child(probe)
		probe.add_to_group("fleet_panels")
	probe.data = {}
	Net.client.send_action("fleet", args)
	await _wait(func() -> bool: return not probe.data.is_empty(), 15.0)
	return probe.data

func _aboard_count() -> int:
	var n := 0
	for r: Node3D in get_tree().get_nodes_in_group("remote_players"):
		if SpaceLayout.pocket_at(r.global_position) >= 0: n += 1
	return n

func _run() -> void:
	check(await _wait(func() -> bool: return Net.is_client() and Net.client.connected and _settled(), 90.0), "connected")
	travel("realm_1")
	check(await _wait(func() -> bool: return world is IslandWorld and _settled(), 120.0), "on the Surface")
	var island := world as IslandWorld
	player.global_position = island.launchpad_arrival()
	await get_tree().create_timer(1.0).timeout
	# One crew: the pilot invites, the others accept (only the party may board).
	if role == "pilot":
		await get_tree().create_timer(4.0).timeout
		for name: String in ["p4", "p5", "p6"]: Net.client.send_action("party", ["invite", name])
		check(await _wait(func() -> bool: return social.party.get("members", []).size() >= 4, 40.0), "the crew joined the party")
	else:
		var until := Time.get_ticks_msec()+40000
		while social.party.is_empty() and Time.get_ticks_msec() < until:
			Net.client.send_action("party", ["accept", "p2"])
			await get_tree().create_timer(2.0).timeout
		check(not social.party.is_empty(), "joined the pilot's party")
	if role == "pilot":
		var list := await _fleet(["list"])
		if list.get("ships", []).is_empty(): list = await _fleet(["buy"])
		var stored: Array = list.get("ships", []).filter(func(s: Dictionary) -> bool: return str(s.status) == "stored")
		if not stored.is_empty(): await _fleet(["deploy", int(stored[0].id)])
	check(await _wait(func() -> bool: return not island.surface_ships.ships.is_empty(), 60.0), "a ship stands on the pad")
	var vessel: SpaceShip = island.surface_ships.ships.values()[0]
	player.global_position = island.launchpad_arrival()
	await get_tree().create_timer(0.5).timeout
	Net.client.send_action("port", ["board"])
	check(await _wait(func() -> bool: return SpaceLayout.pocket_at(player.global_position) >= 0, 15.0), "boarded")
	if role == "pilot":
		await get_tree().create_timer(1.0).timeout
		var until := Time.get_ticks_msec()+15000
		while vessel.pilot() != player.player_id and Time.get_ticks_msec() < until:
			Net.client.send_action("port", ["ship", ["sit", "pilot"]])
			await get_tree().create_timer(1.0).timeout
		check(vessel.pilot() == player.player_id, "at the helm")
		check(await _wait(func() -> bool: return _aboard_count() >= 3, 90.0), "the whole crew is aboard (%d others)" % _aboard_count())
		await get_tree().create_timer(2.0).timeout
		Net.client.send_action("port", ["ship", ["takeoff"]])
	check(await _wait(func() -> bool: return world is SpaceWorld and _settled(), 120.0), "carried up to Space with her")
	var space := world as SpaceWorld
	await _wait(func() -> bool: return not space.ships.is_empty(), 20.0)
	var ship: SpaceShip = space.ships.values()[0]
	var traversal := player.spatial_controller as SpaceTraversal
	await _wait(func() -> bool: return not traversal.cinematic, 20.0)
	await get_tree().create_timer(3.0).timeout
	match role:
		"pilot": await _fly(space, ship)
		"walker": await _walk(space, ship)
		"rope", "boots": await _outside(space, ship, traversal)
	print("[crew-%s] done failures=%d" % [role, _failures])
	get_tree().quit(0 if _failures == 0 else 1)

## Full ahead for half a minute, a gentle turn halfway.
func _fly(space: SpaceWorld, ship: SpaceShip) -> void:
	check(ship.pilot() == player.player_id, "still at the helm in Space")
	var start := ship.xform.origin
	var until := Time.get_ticks_msec()+32000
	while Time.get_ticks_msec() < until:
		var turning := 0.3 if Time.get_ticks_msec() > until-16000 else 0.0
		player.debug_input = Vector2(turning, -1.0)  # full ahead through the helm
		await get_tree().create_timer(0.05).timeout
	player.debug_input = Vector2.ZERO
	check(ship.xform.origin.distance_to(start) > 500.0, "flew forward %d m (speed %d)" % [ship.xform.origin.distance_to(start), ship.speed])

## Stroll the room the whole flight: steady steps, never snapped back.
func _walk(space: SpaceWorld, ship: SpaceShip) -> void:
	var start := ship.xform.origin
	var steps: Array[float] = []
	var last := player.global_position
	var walked := 0.0
	for k in 900:  # about 15 s of physics frames
		player.debug_input = Vector2(0, -1 if (k / 120) % 2 == 0 else 1)
		await get_tree().physics_frame
		var step := player.global_position.distance_to(last)
		steps.append(step)
		walked += step
		last = player.global_position
	player.debug_input = Vector2.ZERO
	check(SpaceLayout.pocket_at(player.global_position) >= 0, "still in her room")
	check(walked > 30.0, "walked %d m while she flew %d m" % [walked, ship.xform.origin.distance_to(start)])
	check(steps.max() < 0.5, "no snaps while walking (largest step %.2f m)" % steps.max())

## Out through the airlock, then on the line or in boots while she flies.
func _outside(space: SpaceWorld, ship: SpaceShip, traversal: SpaceTraversal) -> void:
	var airlock: Vector3 = space.pocket_point(ship.slot, space.interior_anchors.get("airlock", Vector3.ZERO))
	player.global_position = airlock+Vector3.UP*0.1
	await get_tree().create_timer(0.8).timeout
	space.request(["airlock"])
	check(await _wait(func() -> bool: return traversal.spacewalk, 10.0), "out of the airlock, spacewalking")
	var view: Node3D = space.ship_views.get(ship.id)
	if role == "boots":
		player.global_position = view.global_transform*Vector3(0, ShipHull.DECK_Y+0.4, 0)
		await get_tree().create_timer(0.5).timeout
		check(not traversal.boots.is_empty(), "magnetic boots hold the deck")
	else:
		var here := view.global_transform.affine_inverse()*player.global_position
		print("[crew-rope] before clipping: hull space ", here, " surface point ", ShipHull.surface_point(here), " ships ", space.ships.size(), " views ", space.ship_views.size())
		await get_tree().create_timer(0.3).timeout
		check(not traversal.tether.is_empty(), "the safety line clipped on at the airlock")
		if traversal.tether.is_empty():
			print("[crew-%s] done failures=%d" % [role, _failures])
			get_tree().quit(1)
			return
	var start := ship.xform.origin
	var worst := 0.0
	var jumps := 0.0
	var last_local := view.global_transform.affine_inverse()*player.global_position
	var until := Time.get_ticks_msec()+15000
	while Time.get_ticks_msec() < until:
		await get_tree().process_frame
		await get_tree().create_timer(0.0).timeout  # after this frame's _process, as it renders
		var local := (view as SpaceShipView).pose().affine_inverse()*player.global_position
		worst = maxf(worst, local.length())
		var jump := local.distance_to(last_local)
		if jump > 2.0: print("[crew-%s] jump %.2f m at %d ms, from %s to %s (ship speed %d)" % [role, jump, Time.get_ticks_msec()-(until-15000), last_local, local, ship.speed])
		jumps = maxf(jumps, jump)
		last_local = local
	var moved := ship.xform.origin.distance_to(start)
	check(moved > 150.0, "she flew %d m meanwhile" % moved)
	if role == "boots":
		check(worst < 30.0 and _on_deck(last_local), "kept to the deck (%.1f m from her centre)" % worst)
	else:
		check(worst < 30.0 + traversal.rope_length, "towed along on the line (at most %.1f m from her centre)" % worst)
		var before := (last_local - (traversal.tether.anchor as Vector3)).length()
		traversal.rope_length = 3.0
		await get_tree().create_timer(4.0).timeout
		var after := ((view.global_transform.affine_inverse()*player.global_position) - (traversal.tether.anchor as Vector3)).length()
		check(after < before or after < 4.0, "reeling the line in pulls you closer (%.1f -> %.1f m)" % [before, after])
	check(jumps < 3.0, "no snaps relative to her (largest jump %.2f m)" % jumps)

func _on_deck(local: Vector3) -> bool:
	return absf(local.y-ShipHull.DECK_Y) < 1.0
