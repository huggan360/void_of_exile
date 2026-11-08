extends "res://scripts/main.gd"
## Online Astral Reach check against a --test dedicated server: travel,
## launch, board, sit, fly (replicated snapshots), land, step out, home.
var _failures := 0

func _ready() -> void:
	super._ready()
	_run.call_deferred()

func check(ok: bool, what: String) -> void:
	print("[space-online] ", "PASS " if ok else "FAIL ", what)
	if not ok: _failures += 1

func _wait(cond: Callable, seconds: float) -> bool:
	var t := 0.0
	while not cond.call() and t<seconds:
		t += get_process_delta_time()
		await get_tree().process_frame
	return cond.call()

func _run() -> void:
	check(await _wait(func() -> bool: return Net.is_client() and Net.client.connected and is_instance_valid(world) and not _traveling and not player.frozen, 60.0), "connected and in a world")
	await get_tree().create_timer(2.0).timeout
	travel("astral")
	check(await _wait(func() -> bool: return world is SpaceWorld and not _traveling and not player.frozen and world.is_presentation_ready(), 60.0), "travel to the Astral Reach")
	var space := world as SpaceWorld
	check(space.zone_at(player.global_position)=="station", "arrive on the Nexus (%s at %s)" % [space.zone_at(player.global_position), player.global_position])
	if player.spatial_controller is SpaceTraversal:
		while (player.spatial_controller as SpaceTraversal).cinematic: await get_tree().process_frame
	space.request(["spawn"])
	check(await _wait(func() -> bool: return space.ships.size()>=1, 5.0), "the server launches a ship and the client sees it")
	var ship: SpaceShip = space.ships.values()[0]
	space.request(["board", ship.id])
	check(await _wait(func() -> bool: return SpaceLayout.pocket_at(player.global_position)==ship.slot, 5.0), "the server boards the player")
	await get_tree().create_timer(1.0).timeout
	space.request(["sit", "pilot"])
	check(await _wait(func() -> bool: return ship.pilot()==player.player_id, 5.0), "the helm seat is replicated")
	var start := ship.xform.origin
	# Wall-clock cruise without boost: a few hundred metres, inside the 900 m docking range.
	var until := Time.get_ticks_msec()+3000
	while Time.get_ticks_msec()<until:
		space.request(["pilot", [1.0, 0.0, 0.0, 0.0, false]])
		await get_tree().create_timer(0.05).timeout
	space.request(["pilot", [0.0, 0.0, 0.0, 0.0, false]])
	await get_tree().create_timer(0.3).timeout
	check(ship.mode=="flying" and ship.xform.origin.distance_to(start)>100.0, "flight is simulated on the server and replicated (moved %d m)" % ship.xform.origin.distance_to(start))
	check(space.ship_views.has(ship.id) and space.ship_views[ship.id].global_position.distance_to(ship.xform.origin)<80.0, "the hull view follows the snapshots")
	print("[space-online] distance to the Nexus before docking: %d m" % ship.xform.origin.distance_to(SpaceLayout.NEXUS))
	# Online: R refused aboard, a drink in an armchair, out through the airlock and back.
	space.request(["stand"])
	await get_tree().create_timer(0.4).timeout
	space.request(["rescue"])
	await get_tree().create_timer(0.5).timeout
	check(SpaceLayout.pocket_at(player.global_position)==ship.slot, "R does not take the crew home from a ship")
	space.request(["sit", "chair_1"])
	await get_tree().create_timer(0.5).timeout
	space.request(["drink"])
	check(await _wait(func() -> bool: return player.stats.buffs.count("drunk")>=1, 4.0), "a drink online makes you drunk (buff replicated)")
	space.request(["stand"])
	await get_tree().create_timer(0.4).timeout
	player.global_position = space.pocket_point(ship.slot, space.interior_anchors.airlock)
	await get_tree().create_timer(0.5).timeout
	space.request(["airlock"])
	check(await _wait(func() -> bool: return (player.spatial_controller as SpaceTraversal).spacewalk, 5.0), "online: out through the airlock on a jetpack")
	await get_tree().create_timer(1.0).timeout
	space.request(["airlock"])
	check(await _wait(func() -> bool: return SpaceLayout.pocket_at(player.global_position)==ship.slot, 5.0), "online: back in through the airlock")
	await get_tree().create_timer(0.6).timeout
	space.request(["sit", "pilot"])
	await _wait(func() -> bool: return ship.pilot()==player.player_id, 5.0)
	space.request(["dock"])
	check(await _wait(func() -> bool: return ship.mode=="berth", 5.0), "docking at the Nexus")
	space.request(["stand"])
	await get_tree().create_timer(0.5).timeout
	space.request(["hatch"])
	check(await _wait(func() -> bool: return space.zone_at(player.global_position)=="station", 5.0), "the hatch at the berth leads to the station")
	await get_tree().create_timer(1.5).timeout
	check(space.zone_at(player.global_position)=="station", "no snap-back after the hatch move")
	print("[space-online] smoke complete failures=", _failures)
	get_tree().quit()
