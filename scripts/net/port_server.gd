class_name PortServer
extends Node
## Between the Surface and Space, on the dedicated server:
##   * the Skyward Launch Pad (SurfaceLaunchpad): buying the battleship
##     (500 Dots, once per account: the campaign book's reach_ship) and
##     launching it, once the Theory of Everything is told;
##   * arrivals: up from a launch you come aboard at the helm where ships
##     rise (SpaceLayout.ASCENT); down from Space you land on the pad;
##   * where the Tavern's realm gate takes you: back to the same spot in Space
##     if that is where you were, else your hometown on the Surface
##     (PlayerStats.travel keeps it with the character).
## A private realm (a campaign's world) has its own private Space.
const PAD_REACH := 32.0
const CREW_REACH := 26.0

var server: NetServer
var _flight_id := 0


static func space_for(surface: String) -> String:
	return SpaceWorld.REALM + "_" + surface if Campaigns.is_campaign_realm(surface) else SpaceWorld.REALM


static func surface_for(space: String) -> String:
	return space.substr(SpaceWorld.REALM.length() + 1) if space.begins_with(SpaceWorld.REALM + "_") else "realm_1"


func owns_ship(p: Dictionary) -> bool:
	if server.config.test_mode: return bool(p.get("test_ship", false))
	if int(p.get("account_id", 0)) == 0: return false
	return not server.campaigns.book(int(p.account_id)).get("reach_ship", {}).is_empty()


## What a Surface world needs to show at its pad.
func state_for(p: Dictionary) -> Dictionary:
	return {astral_unlocked = server._astral_unlocked(p), ship_owned = owns_ship(p)}


func _pad_of(p: Dictionary) -> Vector3:
	var realm: RealmInstance = server.realms.get(p.get("realm", ""))
	if realm == null or not realm.world is IslandWorld: return Vector3.INF
	return (realm.world as IslandWorld).launchpad_center()


func _say(p: Dictionary, ev: Array) -> void:
	server.social.send(p.player_id, ["port"] + ev)


## Purchase and boarding at the pad; interior requests use the shared ship systems.
func on_action(p: Dictionary, args: Array) -> void:
	if args.size()==2 and str(args[0])=="ship" and args[1] is Array:
		var realm: RealmInstance = server.realms.get(p.get("realm", ""))
		if realm and realm.world is IslandWorld and is_instance_valid(realm.world.surface_ships):
			realm.world.surface_ships.server_action(p, args[1])
		return
	var pad := _pad_of(p)
	if not pad.is_finite() or (p.pos as Vector3).distance_to(pad) > PAD_REACH: return
	if not server._astral_unlocked(p):
		server.social.system(p.player_id, "Space opens once the Theory of Everything is told.")
		return
	match str(args[0]) if not args.is_empty() else "":
		"buy":
			server.fleet.on_action(p, ["buy"])
		"board":
			var realm: RealmInstance = server.realms.get(p.realm)
			var dock := (realm.world as IslandWorld).surface_ships
			for ship: SpaceShip in dock.ships.values():
				if dock._may_board(ship, int(p.player_id)):
					dock.server_action(p, ["board", ship.id])
					return
			server.social.system(p.player_id, "Buy a battleship from the shipwright first, or join its captain's party.")


## A ship goes down to the Surface: everyone aboard lands on the pad.
func descend(pid: int) -> void:
	var p: Dictionary = server.social.record(pid)
	if not p.is_empty(): p.port = {kind = "descend"}


## The Tavern's realm gate: back to the same spot in Space if that is where
## the character was (and Space is open to them). Returns the destination.
func redirect(p: Dictionary, destination: String) -> String:
	if not (Campaigns.is_tavern(str(p.get("realm", ""))) or str(p.get("realm", "")) == ""): return destination
	if destination != "realm_1" and not Campaigns.is_campaign_realm(destination): return destination
	var stats := GameServer.character(p.player_id)
	if stats == null or str(stats.travel.get("last", "")) != "space": return destination
	var space := str(stats.travel.get("space", SpaceWorld.REALM))
	# A private Space belongs to its campaign: only while that tale is yours.
	if space != SpaceWorld.REALM and not server.campaigns.may_enter(p, surface_for(space)): space = SpaceWorld.REALM
	if space_for(destination) != space and destination != "realm_1": return destination
	if not server._astral_unlocked(p): return destination
	p.port = {kind = "return"}
	return space


## Arrival hooks once the realm is known: sets record.arrival_pos (and
## record.port, so the client plays the right shot), and remembers the world.
func arrive(p: Dictionary, realm: RealmInstance, record: Dictionary) -> void:
	var port: Dictionary = p.get("port", {})
	p.erase("port")
	var stats := GameServer.character(p.player_id)
	if realm == null or stats == null: return
	if port.has("transfer") and str(port.get("destination", ""))==realm.realm_id:
		record.intro = false  # Occupants keep their ship view, including on their first flight.
		var dock: SpaceWorld = realm.world if realm.world is SpaceWorld else realm.world.surface_ships if realm.world is IslandWorld else null
		if dock:
			var transfer: Dictionary = port.transfer
			var ship := dock.accept_transfer(transfer, "surface_landing" if dock is SurfaceShipWorld else "flying")
			if ship:
				if dock is SurfaceShipWorld: server.fleet.landed(realm.realm_id)
				var local: Vector3 = transfer.passengers.get(int(p.player_id), Vector3(0, 0.1, 14))
				record.arrival_pos = dock.pocket_point(ship.slot, local)
				record.port = port.kind
				if dock is SurfaceShipWorld: record.surface_ship_state = dock.state_wire()
				else: record.space_state = dock.state_wire()
	if realm.world is SpaceWorld:
		var space := realm.world as SpaceWorld
		var at := Vector3.INF
		match "transfer" if port.has("transfer") else str(port.get("kind", "")):
			"launch": at = space.arrive_from_surface(p, int(port.captain), owns_ship(p))
			"return": at = space.arrive_back(p, stats.travel, owns_ship(p))
		if at.is_finite():
			record.arrival_pos = at
			record.port = port.kind
		stats.travel.last = "space"
		stats.travel.space = realm.realm_id
		p.dirty = true
	elif realm.world is IslandWorld:
		if is_instance_valid(realm.world.surface_ships): record.surface_ship_state = realm.world.surface_ships.state_wire()
		if (str(port.get("kind", "")) == "descend" or (str(port.get("kind", "")) == "rocket" and str(port.get("destination", ""))==realm.realm_id)) and not port.has("transfer"):
			var at := (realm.world as IslandWorld).launchpad_arrival()
			if at.is_finite():
				record.arrival_pos = at
				record.port = str(port.kind)
		if str(stats.travel.get("last", "")) != "surface":
			stats.travel.last = "surface"
			p.dirty = true
		record.merge(state_for(p), true)


## Leaving Space: where they were, and their ship, for the way back.
func leaving(p: Dictionary, realm: RealmInstance) -> void:
	if realm == null or not realm.world is SpaceWorld: return
	var stats := GameServer.character(p.player_id)
	if stats == null: return
	var space := realm.world as SpaceWorld
	stats.travel.pos = [p.pos.x, p.pos.y, p.pos.z]
	stats.travel.space = realm.realm_id
	stats.travel.ship = space.ship_snapshot(int(p.player_id))
	stats.travel.aboard = SpaceLayout.pocket_at(p.pos) >= 0
	p.dirty = true

## Capture one shared hull and every occupant before anybody leaves the source.
func prepare_transfer(source: SpaceWorld, ship: SpaceShip, destination: String, kind: String, crew: Array) -> void:
	_flight_id += 1
	var transfer := {cups = Leisure.ship_tables(source.realm_id, ship), flight = _flight_id, wire = ship.wire().duplicate(true), smoking = ship.smoking.duplicate(),
		passengers = {}, imported = {}, account = int(ship.get_meta("account", 0)), cooldowns = ship.cooldowns.duplicate()}
	for pid: int in crew:
		var p := server.social.record(pid)
		if p.is_empty(): continue
		transfer.passengers[pid] = (p.pos as Vector3)-SpaceLayout.pocket_origin(ship.slot)
		p.port = {kind = kind, destination = destination, transfer = transfer}

func launch_ship(source: SurfaceShipWorld, ship: SpaceShip) -> void:
	var crew := source._aboard(ship)
	if crew.is_empty():
		ship.mode = "landed"
		ship.xform = source.pad_pose()
		return
	var destination := space_for(source.realm_id)
	prepare_transfer(source, ship, destination, "launch", crew)
	var event: Array = ["ship_travel", destination, "launch", crew]
	source.world_event.emit(event)
	source.get_tree().create_timer(15.0).timeout.connect(func() -> void:
		if source.ships.has(ship.id) and ship.mode=="transit": source._retire(ship))
