extends Node
class Api extends AccountApi:
	var calls: Array = []
	var delay := false
	func call_api(_method: String, _path: String, body: Dictionary = {}) -> Dictionary:
		calls.append(body.duplicate(true))
		if delay: await get_tree().process_frame
		return {ok = true, data = {lease_seconds = 90, ships = []}, error = ""}
class Server extends NetServer:
	func _ready() -> void:
		set_process(false)
		set_physics_process(false)
class Realm extends RealmInstance:
	func _ready() -> void: set_physics_process(false)
class World extends SpaceWorld:
	func _ready() -> void: set_physics_process(false)
	func _ensure_interior(_slot: int) -> void: pass
	func _broadcast_ship(_ship: SpaceShip) -> void: pass
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("[fleet-lifetime] ", "PASS " if ok else "FAIL ", label)
func _ready() -> void: _run.call_deferred()
func _run() -> void:
	var server := Server.new()
	add_child(server)
	server.api.free()
	var api := Api.new()
	server.api = api
	server.add_child(api)
	server.social.server = server
	Net.server = server
	Net.mode = Net.Mode.SERVER
	var fleet := server.fleet
	fleet.server = server
	server.add_child(fleet)
	fleet.set_process(false)
	var realm := Realm.new({id = "qa"})
	add_child(realm)
	var world := World.new({id = "qa"})
	realm.world = world
	realm.add_child(world)
	server.realms.qa = realm
	var proxy := Node3D.new()
	world.add_child(proxy)
	realm.proxies[8] = proxy
	var passenger := {player_id = 8, account_id = 80, peer_id = 0, pos = Vector3(1000, 0, 0), realm = "qa"}
	server.peers[8] = passenger
	server.by_player[8] = 8
	var ship := SpaceShip.new()
	ship.id = 1
	ship.fleet_id = 100
	ship.account_id = 70
	ship.owner = 7  # Owner is deliberately absent from the server.
	ship.slot = 0
	ship.mode = "landed"
	ship.hp = 1234
	world.ships[1] = ship
	var entry := {world = weakref(world), ship = ship, token = "same-claim", deadline = INF, idle = 119.0, saving = false, next = INF}
	fleet.active[100] = entry
	passenger.pos = SpaceLayout.pocket_origin(0)
	proxy.global_position = passenger.pos
	fleet._timer = 0.0
	fleet._process(1.0)
	check(fleet.active.has(100) and float(entry.idle)==0.0, "friend aboard protects the owner's ship after the owner disconnects")
	passenger.pos = Vector3(80, 0, 0)
	proxy.global_position = passenger.pos
	entry.idle = 119.0
	fleet._timer = 0.0
	fleet._process(1.0)
	check(fleet.active.has(100) and float(entry.idle)==0.0, "nearby players reset the absence timer")
	ship.mode = "flying"
	passenger.pos = Vector3(500, 0, 0)
	proxy.global_position = passenger.pos
	entry.idle = 119.0
	fleet._timer = 0.0
	fleet._process(1.0)
	check(fleet.active.has(100) and float(entry.idle)==0.0, "spacewalking and empty ships in flight never trigger automatic storage")
	ship.mode = "landed"
	entry.idle = 119.0
	fleet._timer = 0.0
	fleet._process(1.0)
	check(not fleet.active.has(100) and not world.ships.has(1) and api.calls[-1].operation=="store", "landed ship with no nearby crew is stored after two minutes")
	check(int(api.calls[-1].state.hp)==1234, "automatic storage saves existing hull condition")
	# A dying ship must not get lost when an older heartbeat is still in flight.
	world.ships[1] = ship
	fleet.active[100] = entry
	entry.saving = false
	entry.erase("pending_store")
	entry.erase("destroyed")
	ship.mode = "flying"
	ship.hp = 1234
	api.delay = true
	fleet._save(100, "heartbeat")
	ship.hp = 0
	fleet.destroyed(ship)
	await get_tree().process_frame
	check(fleet.active.has(100) and bool(entry.get("destroyed", false)), "fatal hit during an in-flight heartbeat remains queued for global destruction")
	api.delay = false
	fleet._timer = 0.0
	fleet._process(1.0)
	check(not fleet.active.has(100) and api.calls[-1].operation=="destroy", "queued wreck is committed instead of returning a free ship")
	# Loss of the deployment lease fails closed before another server may claim it.
	ship.hp = 1234
	world.ships[1] = ship
	fleet.active[100] = {world = weakref(world), ship = ship, token = "expired", deadline = Net.now()-1.0, idle = 0.0, saving = false, next = INF}
	passenger.pos = SpaceLayout.pocket_origin(0)
	proxy.global_position = passenger.pos
	fleet._timer = 0.0
	fleet._process(1.0)
	check(not world.ships.has(1) and not fleet.active.has(100), "expired global claim removes the old local ship to prevent duplication")
	check(SpaceLayout.pocket_at(passenger.pos)<0, "occupants are moved to safety before an expired deployment is removed")
	var public := fleet._view({deployment = {token = "private"}, ships = []}, {world = world, pose = Transform3D.IDENTITY, key = "qa:surface"})
	check(not public.has("deployment"), "fleet shop responses never expose the private deployment token")
	Net.mode = Net.Mode.OFFLINE
	Net.server = null
	print("[fleet-lifetime] RESULT %d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures else 0)
