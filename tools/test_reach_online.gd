extends "res://scripts/main.gd"
## Online Reach tale check against a --test dedicated server (account p2 or p3):
## plays First Light end to end through the real requests. Talk to Isolde, launch
## and board, fly to Verdance, land, talk to Elder Moss, relight the three caps,
## fly home, dock and report. Run like tools/test_space_online.tscn (with --space-test).
const TALE := "first_light"
var _failures := 0
var _space: SpaceWorld

func _ready() -> void:
	super._ready()
	_run.call_deferred()

func check(ok: bool, what: String) -> void:
	print("[reach-online] ", "PASS " if ok else "FAIL ", what)
	if not ok: _failures += 1

func _wait(cond: Callable, seconds: float) -> bool:
	var until := Time.get_ticks_msec()+int(seconds*1000.0)
	while not cond.call() and Time.get_ticks_msec()<until:
		await get_tree().process_frame
	return cond.call()

func _state() -> Dictionary:
	return social.campaign_state()

func _step_id() -> String:
	var state := _state()
	if state.is_empty() or str(state.get("id", ""))!=TALE: return ""
	if str(state.get("status", ""))=="done": return "done"
	return str(Campaigns.step_def(TALE, int(state.get("step", 0))).get("id", ""))

func _at_step(id: String, seconds := 10.0) -> bool:
	return await _wait(func() -> bool: return _step_id()==id, seconds)

func _ship() -> SpaceShip:
	for ship: SpaceShip in _space.ships.values():
		if ship.owner==player.player_id: return ship
	return null

## Stand beside a point and let the server hear about it.
func _go(at: Vector3, offset := Vector3(0, 0.2, 1.5)) -> void:
	player.global_position = at+offset
	player.velocity = Vector3.ZERO
	await get_tree().create_timer(0.8).timeout

## Talk to a Reach npc and page through the shared scene until the step moves on.
func _talk(npc: String, step: String, next: String) -> void:
	var at := _space.npc_position(npc)
	if not at.is_finite():
		check(false, "%s has a position" % npc)
		return
	var offset := Vector3(0, 0.2, 2)
	var zone := _space.zone_at(at)
	if zone.begins_with("planet:"):
		# Beside the npc on the sphere: a little up and along the tangent.
		var up := (at-(SpaceLayout.planet(zone.substr(7)).center as Vector3)).normalized()
		offset = up*0.3+up.cross(Vector3.RIGHT).normalized()*2.0
	await _go(at, offset)
	Net.client.send_action("camp", ["quest", "npc:"+npc])
	var until := Time.get_ticks_msec()+20000
	while _step_id()==step and Time.get_ticks_msec()<until:
		await get_tree().create_timer(0.4).timeout
		Net.client.send_action("camp", ["scene_next"])
	check(_step_id()==next, "talk %s (%s -> %s, now %s)" % [npc, step, next, _step_id()])

## Fly the party ship toward `goal` with the pilot requests until `done` holds.
func _fly(goal: Vector3, done: Callable, seconds: float, slow_within := 0.0) -> bool:
	var until := Time.get_ticks_msec()+int(seconds*1000.0)
	while not done.call() and Time.get_ticks_msec()<until:
		var ship := _ship()
		var to := goal-ship.xform.origin
		var local := ship.xform.basis.inverse()*to.normalized()
		var far := to.length()>slow_within
		var thrust := 1.0 if far else (0.0 if ship.speed>60.0 else 0.4)
		# Turn first when the goal is behind, but lift clear of a berth or pad at once.
		if local.z>0.0 and ship.mode=="flying": thrust = minf(thrust, 0.2)
		_space.request(["pilot", [thrust, clampf(local.x*3.0, -1, 1), clampf(local.y*3.0, -1, 1), 0.0, far and local.z<-0.8 and to.length()>900.0]])
		await get_tree().create_timer(0.05).timeout
	_space.request(["pilot", [0.0, 0.0, 0.0, 0.0, false]])
	return done.call()

func _run() -> void:
	check(await _wait(func() -> bool: return Net.is_client() and Net.client.connected and is_instance_valid(world) and not _traveling and not player.frozen, 60.0), "connected and in a world")
	await get_tree().create_timer(2.0).timeout
	Net.client.send_action("camp_test", ["unlock", TALE])
	await get_tree().create_timer(1.0).timeout
	travel("astral")
	check(await _wait(func() -> bool: return world is SpaceWorld and not _traveling and not player.frozen and world.is_presentation_ready(), 60.0), "travel to the Astral Reach")
	_space = world as SpaceWorld
	if player.spatial_controller is SpaceTraversal:
		while (player.spatial_controller as SpaceTraversal).cinematic: await get_tree().process_frame
	Net.client.send_action("camp", ["start", TALE, true])
	check(await _at_step("captain"), "the leader starts First Light (step %s)" % _step_id())
	await _talk("isolde", "captain", "ship")
	# Launch and board.
	await _go(_space.station.anchors.command_table, Vector3(0, 0.2, 4.5))
	_space.request(["spawn"])
	check(await _wait(func() -> bool: return _ship()!=null, 5.0), "a ship launches for the party")
	var ship := _ship()
	_space.request(["board", ship.id])
	check(await _at_step("fly"), "boarding completes reach_ship (now %s)" % _step_id())
	await get_tree().create_timer(0.8).timeout
	_space.request(["sit", "pilot"])
	check(await _wait(func() -> bool: return ship.pilot()==player.player_id, 5.0), "the helm is ours")
	# Out to Verdance, then down onto its pad.
	var verdance := SpaceLayout.planet("verdance")
	var pad: Transform3D = SpaceShip.landed_pose(verdance)
	var above := pad.origin+pad.basis.y*140.0
	check(await _fly(above, func() -> bool: return _step_id()!="fly", 60.0), "reach_fly: the ship reaches Verdance (now %s)" % _step_id())
	check(await _fly(above, func() -> bool: return not ship.landable().is_empty() and ship.speed<60.0, 40.0, 250.0), "the ship slows near Verdance's pad (%d m, speed %d)" % [ship.xform.origin.distance_to(above), ship.speed])
	_space.request(["land"])
	check(await _at_step("moss", 20.0), "reach_land: landed on Verdance (mode %s, now %s)" % [ship.mode, _step_id()])
	_space.request(["stand"])
	await get_tree().create_timer(0.4).timeout
	_space.request(["hatch"])
	check(await _wait(func() -> bool: return _space.zone_at(player.global_position)=="planet:verdance", 5.0), "out of the hatch onto Verdance")
	await get_tree().create_timer(1.0).timeout
	await _talk("moss", "moss", "caps")
	# Relight the caps.
	for cap: Dictionary in Campaigns.step_def(TALE, Campaigns.step_index(TALE, "caps")).objects:
		var at := _space.spot_position("verdance", str(cap.spot))
		var up := (at-(verdance.center as Vector3)).normalized()
		await _go(at, up*0.3+up.cross(Vector3.RIGHT).normalized()*1.5)
		# The server hears of a teleport a moment later than the client: retry once.
		for attempt in 2:
			var before := int(_state().get("count", 0))
			Net.client.send_action("camp", ["quest", "obj:"+str(cap.id)])
			if await _wait(func() -> bool: return int(_state().get("count", 0))!=before or _step_id()!="caps", 2.5): break
		print("[reach-online] searched ", cap.id, " count=", _state().get("count", "?"), " standing ", snappedf(player.global_position.distance_to(at), 0.1), " m from the spot")
	check(await _at_step("moss2"), "reach_search: all three caps relit (now %s)" % _step_id())
	await _talk("moss", "moss2", "home")
	# Back aboard and home.
	var hatch := _space.hatch_position(ship)
	await _go(hatch, (hatch-(verdance.center as Vector3)).normalized()*0.3)
	_space.request(["board", ship.id])
	check(await _wait(func() -> bool: return SpaceLayout.pocket_at(player.global_position)==ship.slot, 5.0), "boarding again from Verdance")
	await get_tree().create_timer(0.8).timeout
	_space.request(["sit", "pilot"])
	await _wait(func() -> bool: return ship.pilot()==player.player_id, 5.0)
	# Climb clear of Verdance first, then home.
	var climb: Vector3 = pad.origin+pad.basis.y*900.0
	await _fly(climb, func() -> bool: return ship.xform.origin.distance_to(climb)<250.0, 30.0)
	check(await _fly(SpaceLayout.NEXUS+Vector3(0, 0, 400), func() -> bool: return ship.xform.origin.distance_to(SpaceLayout.NEXUS)<700.0, 60.0, 600.0), "fly back to the Nexus (%d m)" % ship.xform.origin.distance_to(SpaceLayout.NEXUS))
	_space.request(["dock"])
	check(await _at_step("report", 10.0), "reach_dock: docked at the Nexus (mode %s, now %s)" % [ship.mode, _step_id()])
	_space.request(["stand"])
	await get_tree().create_timer(0.4).timeout
	_space.request(["hatch"])
	check(await _wait(func() -> bool: return _space.zone_at(player.global_position)=="station", 5.0), "the hatch at the berth leads to the station")
	await get_tree().create_timer(1.0).timeout
	await _talk("isolde", "report", "done")
	check(_step_id()=="done", "First Light is complete")
	print("[reach-online] smoke complete failures=", _failures)
	get_tree().quit()
