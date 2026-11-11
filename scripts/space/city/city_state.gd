class_name CityState
extends RefCounted
## Vesperis's shared state, decided by the authority (the server, or the game
## offline) and mirrored on every client: who sits where, the drink in front of
## each seat. Townsfolk and traffic need nothing here: they
## follow the server clock (clock()), so everyone sees the same city.
##
## Seats: sit at an empty one and the waiter brings your drink a moment later;
## X sips it (beer leaves you tipsy, coffee quickens your step), C orders another.
## The Lantern Spire's attendants take you up to its orb and back (no lift:
## the screen fades to black and you stand in the other place, see orb_trip()).
const ORDER_TIME := 2.5
const SIP := 0.25
var seats := {}  # seat id -> player id
var cups := {}  # seat id -> drink left (0..1)
var orders := {}  # seat id -> clock time it arrives
var changed := false  # authority: something to broadcast

static var _tick := -1
static var _tick_time := 0.0

## The shared clock, read once per physics step: the car and whoever rides it
## are placed for the very same moment.
static func clock() -> float:
	if Engine.is_in_physics_frame():
		var tick := Engine.get_physics_frames()
		if tick!=_tick:
			_tick = tick
			_tick_time = _now()
		return _tick_time
	return _now()

static func _now() -> float:
	if Net.is_client() and Net.client: return Net.client.server_time()
	return Net.now()

## Townsfolk already sitting there (from the layout) take a seat for good.
static func npc_seat(id: String) -> bool:
	var parts := id.split(":")
	if parts.size()!=3 or parts[1]=="orb": return false
	var v := CityLayout.venue(parts[1])
	return not v.is_empty() and int(parts[2]) in v.patrons

func seat_of(pid: int) -> String:
	for id: String in seats:
		if int(seats[id])==pid: return id
	return ""

func taken(id: String) -> bool:
	return seats.has(id) or npc_seat(id)

# --- Authority ---------------------------------------------------------------------------

## A request from player `pid` standing at `pos`: [op, ...]. Returns text to tell them, or "".
func handle(pid: int, pos: Vector3, args: Array) -> String:
	var op := str(args[1]) if args.size()>1 else ""
	match op:
		"sit":
			var id := str(args[2]) if args.size()>2 else ""
			var spec := CityLayout.any_seat(id)
			if spec.is_empty() or pos.distance_to(spec.pos)>4.0: return ""
			if taken(id) and int(seats.get(id, 0))!=pid: return "Someone already sits there."
			stand(pid)
			seats[id] = pid
			if float(cups.get(id, 0.0))<0.05:
				orders[id] = clock()+ORDER_TIME
			changed = true
			return "A %s is on its way." % ("coffee" if spec.drink=="coffee" else "frothy beer")
		"stand":
			if stand(pid): changed = true
		"sip":
			var id := seat_of(pid)
			if id=="": return ""
			if float(cups.get(id, 0.0))<0.05:
				return "Your cup is empty. C orders another." if not orders.has(id) else "It's coming, it's coming."
			cups[id] = maxf(0.0, float(cups[id])-SIP)
			changed = true
			var stats := GameServer.character(pid)
			if stats:
				if CityLayout.any_seat(id).drink=="coffee": stats.buffs.add("speed", 90.0, 4, "city_coffee")
				elif float(cups[id])<0.05: stats.buffs.drink_beer()
		"order":
			var id := seat_of(pid)
			if id=="" or orders.has(id): return ""
			orders[id] = clock()+ORDER_TIME
			changed = true
			return "Another one, coming right up."
	return ""

## Gives up any seat; true when there was one.
func stand(pid: int) -> bool:
	var id := seat_of(pid)
	if id=="": return false
	seats.erase(id)
	orders.erase(id)
	changed = true
	return true

func step() -> void:
	var now := clock()
	for id: String in orders.keys():
		if now>=float(orders[id]):
			orders.erase(id)
			cups[id] = 1.0
			changed = true

func wire() -> Dictionary:
	return {seats = seats.duplicate(), cups = cups.duplicate(), orders = orders.duplicate()}

func apply(data: Dictionary) -> void:
	seats = data.get("seats", {}).duplicate()
	cups = data.get("cups", {}).duplicate()
	orders = data.get("orders", {}).duplicate()

# --- The Lantern Spire's orb ----------------------------------------------------------------

## Where an attendant sends someone standing at `pos` (world space): up to the
## orb from the hall, down to the hall from the orb, or INF when nobody is near.
static func orb_trip(pos: Vector3) -> Vector3:
	var up := CityLayout.orb_spot(true)
	var down := CityLayout.orb_spot(false)
	if pos.distance_to(CityLayout.attendant(false))<5.0: return up
	if pos.distance_to(CityLayout.attendant(true))<5.0: return down
	return Vector3.INF

## The player rigs share leg pivots. Applied after their normal animation.
static func seated_pose(model: Node3D) -> void:
	var rig := model.find_child("Rig", true, false) as Node3D
	if rig==null: return
	for name in ["LegL", "LegR"]:
		var leg := rig.get_node_or_null(name) as Node3D
		if leg: leg.rotation.x = -PI*0.45
