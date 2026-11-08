extends "res://scripts/main.gd"
class Probe extends Node:
	var data := {}
	func receive(value: Dictionary) -> void: data = value
var _probe := Probe.new()
var _checks := 0
var _failures := 0
func _parse_args() -> void:
	super._parse_args()
	_args["space-test"] = ""
func _ready() -> void:
	super._ready()
	add_child(_probe)
	_probe.add_to_group("fleet_panels")
	_run.call_deferred()
	get_tree().create_timer(240.0).timeout.connect(func() -> void:
		print("[fleet-online] TIMEOUT")
		get_tree().quit(2))
func check(ok: bool, label: String) -> bool:
	_checks += 1
	if not ok: _failures += 1
	print("[fleet-online] ", "PASS " if ok else "FAIL ", label)
	return ok
func _wait(condition: Callable, seconds := 20.0) -> bool:
	var until := Time.get_ticks_msec()+int(seconds*1000)
	while not condition.call() and Time.get_ticks_msec()<until: await get_tree().process_frame
	return condition.call()
func _request(args: Array) -> Dictionary:
	_probe.data = {}
	Net.client.send_action("fleet", args)
	if not await _wait(func() -> bool: return not _probe.data.is_empty()):
		check(false, "response to "+str(args))
		return {error = "timeout"}
	return _probe.data
func _settled() -> bool:
	return is_instance_valid(world) and not _traveling and not player.frozen and world.is_presentation_ready()
func _run() -> void:
	if not check(await _wait(func() -> bool: return Net.is_client() and Net.client.connected and _settled(), 60.0), "connected to the isolated account service and game server"):
		get_tree().quit(1)
		return
	travel("realm_1")
	if not check(await _wait(func() -> bool: return world is IslandWorld and _settled(), 90.0), "Surface loaded"):
		get_tree().quit(1)
		return
	var island := world as IslandWorld
	player.global_position = island.launchpad_arrival()
	player.velocity = Vector3.ZERO
	await get_tree().create_timer(0.6).timeout
	var before := await _request(["list"])
	var balance := int(before.get("dots", 0))
	var old_count: int = before.get("ships", []).size()
	var first := await _request(["buy"])
	check(not first.has("error") and first.ships.size()==old_count+1 and int(first.dots)==balance-500, "buying adds a stored ship and charges exactly 500 Dots")
	if first.has("error"):
		get_tree().quit(1)
		return
	var first_id := int(first.ships[-1].id)
	var second := await _request(["buy"])
	var second_id := int(second.ships[-1].id)
	check(first_id!=second_id and second.ships.size()==old_count+2, "an account can own multiple distinct persistent ship IDs")
	var deployed := await _request(["deploy", first_id])
	check(not deployed.has("error") and await _wait(func() -> bool: return island.surface_ships.ships.size()==1), "taking a ship out creates its hull on the Surface")
	check(int(deployed.get("dots", 0))==balance-1000, "taking a stored ship out is free")
	var blocked := await _request(["deploy", second_id])
	check(blocked.has("error") and island.surface_ships.ships.size()==1, "occupied pad refuses a second ship without creating an overlapping hull")
	var stored := await _request(["recall", first_id])
	check(not stored.has("error") and await _wait(func() -> bool: return island.surface_ships.ships.is_empty()), "owner can store an empty landed ship")
	var out_again := await _request(["deploy", first_id])
	check(not out_again.has("error") and int(out_again.dots)==balance-1000, "the same persistent ship can be taken out again without another payment")
	if not check(await _wait(func() -> bool: return island.surface_ships.ships.size()==1), "redeployed hull reaches the client"):
		get_tree().quit(1)
		return
	var vessel: SpaceShip = island.surface_ships.ships.values()[0]
	check(vessel.fleet_id==first_id and vessel.account_id>0, "persistent ship ID and owner account replicate to the client")
	Net.client.send_action("port", ["board"])
	check(await _wait(func() -> bool: return SpaceLayout.pocket_at(player.global_position)>=0), "boarding the deployed fleet ship")
	await get_tree().create_timer(0.6).timeout
	Net.client.send_action("port", ["ship", ["sit", "pilot"]])
	check(await _wait(func() -> bool: return vessel.pilot()==player.player_id), "pilot can take control of a fleet ship")
	Net.client.send_action("port", ["ship", ["takeoff"]])
	check(await _wait(func() -> bool: return world is SpaceWorld and _settled(), 75.0), "fleet ship transfers from the Surface to Space")
	if world is SpaceWorld:
		var space := world as SpaceWorld
		var ship := space.ship_of(player.player_id)
		check(ship!=null and ship.fleet_id==first_id, "world handoff retains the same global fleet identity")
	print("[fleet-online] RESULT %d checks, %d failures" % [_checks, _failures])
	get_tree().quit(1 if _failures else 0)
