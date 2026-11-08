class_name CityState
extends RefCounted
## Vesperis's shared state, decided by the authority (the server, or the game
## offline) and mirrored on every client: who sits where, the drink in front of
## each seat, and every elevator. Townsfolk and traffic need nothing here: they
## follow the server clock (clock()), so everyone sees the same city.
##
## Seats: sit at an empty one and the waiter brings your drink a moment later;
## X sips it (beer leaves you tipsy, coffee quickens your step), C orders another.
## Elevators: a call (from a floor's panel or a button in the car) queues that
## floor; the car closes its doors, rides, and opens them again.
const ORDER_TIME := 2.5
const SIP := 0.25
const DOORS := 1.2  # seconds to close or open
const STAY := 4.0  # doors stay open this long with nobody calling
var seats := {}  # seat id -> player id
var cups := {}  # seat id -> drink left (0..1)
var orders := {}  # seat id -> clock time it arrives
## id -> {floor, target, phase (idle, closing, moving, opening), t0, t1, from, to, queue: Array}
var elevators := {}
var changed := false  # authority: something to broadcast

static func clock() -> float:
	if Net.is_client() and Net.client: return Net.client.server_time()
	return Net.now()

func _init() -> void:
	for e: Dictionary in CityLayout.elevators():
		elevators[int(e.id)] = {floor = 0, target = 0, phase = "idle", t0 = 0.0, t1 = 0.0, from = 0, to = 0, queue = []}

## Townsfolk already sitting there (from the layout) take a seat for good.
static func npc_seat(id: String) -> bool:
	var parts := id.split(":")
	if parts.size()!=3 or parts[1].begins_with("tower"): return false
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
				else: stats.buffs.add("drunk", 150.0, 1, "city_sip_%d" % (Time.get_ticks_msec() % 8))
		"order":
			var id := seat_of(pid)
			if id=="" or orders.has(id): return ""
			orders[id] = clock()+ORDER_TIME
			changed = true
			return "Another one, coming right up."
		"call":
			var e := int(args[2]) if args.size()>2 else -1
			var floor := int(args[3]) if args.size()>3 else -1
			if not elevators.has(e) or floor<0 or floor>=4: return ""
			var lift: Dictionary = elevators[e]
			# Only from inside the car or at that floor's door.
			if not (inside_car(e, pos) or at_landing(e, floor, pos)): return ""
			if floor==int(lift.floor) and lift.phase=="idle":
				lift.t0 = clock()  # hold the doors open
				changed = true
				return ""
			if not floor in lift.queue and floor!=int(lift.target): lift.queue.append(floor)
			changed = true
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
	for e: int in elevators:
		var lift: Dictionary = elevators[e]
		match str(lift.phase):
			"idle":
				if not lift.queue.is_empty() and now-float(lift.t0)>1.0:
					lift.target = int(lift.queue.pop_front())
					lift.phase = "closing"
					lift.t0 = now
					changed = true
			"closing":
				if now-float(lift.t0)>=DOORS:
					var spec: Dictionary = CityLayout.elevators()[e]
					var dh := absf(float(spec.floors[lift.target].h)-float(spec.floors[lift.floor].h))
					lift.phase = "moving"
					lift.from = lift.floor
					lift.to = lift.target
					lift.t0 = now
					lift.t1 = now+maxf(3.0, dh/CityLayout.ELEVATOR_SPEED)
					changed = true
			"moving":
				if now>=float(lift.t1):
					lift.floor = lift.to
					lift.phase = "opening"
					lift.t0 = now
					changed = true
			"opening":
				if now-float(lift.t0)>=DOORS:
					lift.phase = "idle"
					lift.t0 = now
					changed = true

func wire() -> Dictionary:
	return {seats = seats.duplicate(), cups = cups.duplicate(), orders = orders.duplicate(), elevators = elevators.duplicate(true)}

func apply(data: Dictionary) -> void:
	seats = data.get("seats", {}).duplicate()
	cups = data.get("cups", {}).duplicate()
	orders = data.get("orders", {}).duplicate()
	for e in data.get("elevators", {}):
		elevators[int(e)] = (data.elevators[e] as Dictionary).duplicate(true)

# --- Elevator geometry (shared) ------------------------------------------------------------

## Height of the car's floor above the tower's ground at clock time `t`, and
## how open its doors are (0 shut, 1 open).
func car_state(e: int, t := NAN) -> Array:
	if is_nan(t): t = clock()
	var lift: Dictionary = elevators[e]
	var spec: Dictionary = CityLayout.elevators()[e]
	var floors: Array = spec.floors
	match str(lift.phase):
		"moving":
			var k := clampf((t-float(lift.t0))/maxf(0.01, float(lift.t1)-float(lift.t0)), 0.0, 1.0)
			k = k*k*(3.0-2.0*k)
			return [lerpf(float(floors[lift.from].h), float(floors[lift.to].h), k), 0.0]
		"closing":
			return [float(floors[lift.floor].h), 1.0-clampf((t-float(lift.t0))/DOORS, 0.0, 1.0)]
		"opening":
			return [float(floors[lift.floor].h), clampf((t-float(lift.t0))/DOORS, 0.0, 1.0)]
	return [float(floors[lift.floor].h), 1.0]

const CAR := Vector3(3.4, 3.0, 3.4)
## The car's middle sits at the tower's centre, a little behind (its door faces -Z).
const SHAFT := Vector3(0, 0, 1.5)

func inside_car(e: int, pos: Vector3) -> bool:
	var spec: Dictionary = CityLayout.elevators()[e]
	var local := CityLayout.tower_world(spec).affine_inverse()*pos-SHAFT
	var h := float(car_state(e)[0])
	return absf(local.x)<CAR.x*0.5+0.3 and absf(local.z)<CAR.z*0.5+0.3 and local.y>h-1.0 and local.y<h+CAR.y

func at_landing(e: int, floor: int, pos: Vector3) -> bool:
	var spec: Dictionary = CityLayout.elevators()[e]
	var local := CityLayout.tower_world(spec).affine_inverse()*pos-SHAFT
	var h := float(spec.floors[floor].h)
	return absf(local.x)<4.0 and local.z>-CAR.z*0.5-6.0 and local.z<0.0 and absf(local.y-h)<3.0

## The elevator whose car holds `pos`, or -1.
func car_at(pos: Vector3) -> int:
	for e: int in elevators:
		if inside_car(e, pos): return e
	return -1

## The player rigs share leg pivots. Applied after their normal animation.
static func seated_pose(model: Node3D) -> void:
	var rig := model.find_child("Rig", true, false) as Node3D
	if rig==null: return
	for name in ["LegL", "LegR"]:
		var leg := rig.get_node_or_null(name) as Node3D
		if leg: leg.rotation.x = -PI*0.45
