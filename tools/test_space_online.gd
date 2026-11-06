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
	check(space.zone_at(player.global_position)=="station", "arrive on the Nexus (%s)" % space.zone_at(player.global_position))
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
	var t := 0.0
	while t<4.0:
		t += get_process_delta_time()
		space.request(["pilot", [1.0, 0.0, 0.0, 0.0, true]])
		await get_tree().create_timer(0.05).timeout
	check(ship.mode=="flying" and ship.xform.origin.distance_to(start)>100.0, "flight is simulated on the server and replicated (moved %d m)" % ship.xform.origin.distance_to(start))
	check(space.ship_views.has(ship.id) and space.ship_views[ship.id].global_position.distance_to(ship.xform.origin)<80.0, "the hull view follows the snapshots")
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
