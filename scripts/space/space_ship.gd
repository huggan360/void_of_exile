class_name SpaceShip
extends RefCounted
## One battleship's authoritative state and arcade flight model. The crew walk
## in its interior room (a pocket slot, see SpaceLayout); the hull flies
## outside. Modes: "berth" (docked at the Nexus), "flying", "landing",
## "landed" (on a planet pad).
const MAX_SPEED := 220.0
const BOOST_SPEED := 520.0
## The pulse drive crosses open space; it drops out near planets, the
## Nexus, the Shardfield and the edge of the Reach.
const PULSE_SPEED := 2600.0
const PULSE_CLEARANCE := 1600.0
const ACCEL := 90.0
const TURN_RATE := 1.0
const PITCH_RATE := 0.8
const ROLL_RATE := 1.5
const RADIUS := 24.0
const MAX_HP := 3200
const LAND_ALTITUDE := 420.0
## Flying lower than this over a planet sets the ship down by itself; it has
## to climb above it again after a take-off before that rearms.
const AUTO_LAND_ALTITUDE := 130.0
const LAND_TIME := 6.0
## Seats a crew member can take; the pilot flies, gunners aim turrets, the
## tavern chairs are for a drink and a cigar.
const SEATS := ["pilot", "turret_top", "turret_left", "turret_right", "map", "chair_0", "chair_1", "chair_2", "chair_3"]
## Parts that take damage where the ship is hit and are mended by the crew:
## where they sit on the hull (hull space, for which part a hit strikes),
## and whether they are mended inside the room or outside on the hull.
const PARTS := {
	engines = {name = "Engines", hull = Vector3(0, -1, 21), inside = false},
	hull = {name = "Hull plating", hull = Vector3(8, 0, 4), inside = false},
	helm = {name = "Helm", hull = Vector3(0, 1, -17), inside = true},
	cannons = {name = "Cannons", hull = Vector3(0, 4, -4), inside = true},
	heart = {name = "Heart crystal", hull = Vector3(0, -2, 6), inside = true},
}
## Hull restored by mending a part.
const REPAIR_HULL := 0.12
const REPAIR_TIME := 4.0
const BOOST_DRAIN := 24.0
const BOOST_REGEN := 13.0

var id := 0
var slot := 0
var name := ""
var owner := 0  # player id who launched it
var party := 0  # party id at launch (0 = solo)
var tint := Color("ff8ad8")
var xform := Transform3D.IDENTITY
var velocity := Vector3.ZERO
var speed := 0.0
var mode := "berth"
var berth := 0
var planet := ""
var hp := MAX_HP
var crew := {}  # seat -> player id
var aims := {}  # turret seat -> Vector3 world direction
var input := [0.0, 0.0, 0.0, 0.0, false, false]  # thrust, yaw, pitch, roll, boost, pulse
var pulse := false
## True while the edge of the Reach steers the ship home.
var turned_back := false
var land_armed := true
## Part id -> integrity 0..100.
var parts := {engines = 100.0, hull = 100.0, helm = 100.0, cannons = 100.0, heart = 100.0}
## Boost energy 0..100 (the pilot's bar).
var boost := 100.0
## Tavern aboard: glass level per chair (0..1) and who is smoking (pid -> seconds left).
var glasses := [1.0, 1.0, 1.0, 1.0]
var smoking := {}
var input_age := 0.0
var landing := {}  # {from: Transform3D, to: Transform3D, t: float, planet}
var cooldowns := {}
## A campaign cripples the ship until its crew mends every repair aboard.
var broken := false
var repairs := {}  # id -> {name, seat}

func pilot() -> int:
	return int(crew.get("pilot", 0))

func seat_of(player_id: int) -> String:
	for seat: String in crew:
		if int(crew[seat])==player_id: return seat
	return ""

func dock(index: int) -> void:
	berth = index
	mode = "berth"
	planet = ""
	speed = 0.0
	velocity = Vector3.ZERO
	xform = SpaceLayout.berth_frame(index)

## The pad pose for this ship on a planet: keel resting just above the pad.
const LANDED_HEIGHT := 6.5
static func landed_pose(p: Dictionary) -> Transform3D:
	var frame := SpaceLayout.pad_frame(p)
	return Transform3D(frame.basis, frame.origin+frame.basis.y*LANDED_HEIGHT)

## Height above the ground below, or INF away from planets.
func altitude(p: Dictionary) -> float:
	var up: Vector3 = (xform.origin-(p.center as Vector3))
	return up.length()-float(p.radius)-SpaceLayout.surface_height(p, up.normalized())

## The planet a pilot may land on from here (X), or {}: anywhere low over it.
func landable() -> Dictionary:
	if mode!="flying" or speed>140.0: return {}
	for p: Dictionary in SpaceLayout.PLANETS:
		if xform.origin.distance_to(p.center)<float(p.radius)+LAND_ALTITUDE+SpaceLayout.max_height(p) and altitude(p)<LAND_ALTITUDE: return p
	return {}

## Sets down on the nearest clear, level ground below (PlanetLanding), or on
## the pad if nothing nearby is clear.
func begin_landing(p: Dictionary) -> void:
	var site := PlanetLanding.find_site(p, xform.origin, -xform.basis.z)
	landing = {from = xform, to = site.frame if not site.is_empty() else landed_pose(p), t = 0.0, planet = p.id}
	mode = "landing"
	speed = 0.0
	velocity = Vector3.ZERO

## Authority step. `asteroids` is SpaceLayout.asteroids(); returns impact damage taken.
func step(delta: float, asteroids: Array) -> int:
	input_age += delta
	if input_age>0.6: input = [0.0, 0.0, 0.0, 0.0, false, false]  # a pilot that went quiet
	match mode:
		"landing":
			landing.t = minf(1.0, float(landing.t)+delta/LAND_TIME)
			var k := smoothstep(0.0, 1.0, float(landing.t))
			var from: Transform3D = landing.from
			var to: Transform3D = landing.to
			# Arc in from above the pad rather than through the ground.
			var lift := (to.basis.y*80.0)*sin(k*PI)*0.6
			xform = Transform3D(from.basis.slerp(to.basis, k), from.origin.lerp(to.origin, k)+lift)
			if landing.t>=1.0:
				mode = "landed"
				planet = str(landing.planet)
				landing = {}
			return 0
		"berth", "landed":
			if pilot()!=0 and float(input[0])>0.3 and not broken:
				mode = "flying"
				planet = ""
				land_armed = false
				# Lift clear of the pad or berth before turning loose.
				velocity = xform.basis.y*30.0
				speed = 0.0
			return 0
	# Close over a planet: land on the nearest clear ground by itself.
	for p: Dictionary in SpaceLayout.PLANETS:
		if xform.origin.distance_to(p.center)>float(p.radius)+AUTO_LAND_ALTITUDE+200.0+SpaceLayout.max_height(p): continue
		var height := altitude(p)
		if height>AUTO_LAND_ALTITUDE+100.0: land_armed = true
		elif land_armed and height<AUTO_LAND_ALTITUDE and not broken:
			begin_landing(p)
			return 0
	var thrust := 0.0 if broken else clampf(float(input[0]), -1.0, 1.0)
	# Damaged parts: slow engines (never dead in space), sluggish helm, no boost without the heart.
	var engines := 0.3+0.7*part("engines")
	var heart_ok := part("heart")>0.35
	var boosting := bool(input[4]) and thrust>0.2 and heart_ok and boost>3.0
	boost = clampf(boost-BOOST_DRAIN*delta if boosting else boost+BOOST_REGEN*part("heart")*delta, 0.0, 100.0)
	pulse = bool(input[5]) if input.size()>5 else false
	if pulse and (broken or thrust<0.2 or not heart_ok or not pulse_clear(xform.origin)): pulse = false
	var top := (PULSE_SPEED if pulse else BOOST_SPEED if boosting else MAX_SPEED)*engines
	var accel := ACCEL*engines*(8.0 if pulse or speed>BOOST_SPEED+1.0 else 2.2 if boosting else 1.0)
	speed = move_toward(speed, top*maxf(thrust, 0.0) if thrust>=0.0 else -25.0*-thrust, accel*delta)
	var steer := (0.45 if pulse else 1.0)*(0.4+0.6*part("helm"))
	var basis := xform.basis
	basis = basis.rotated(basis.y, -clampf(float(input[1]), -1.0, 1.0)*TURN_RATE*steer*delta)
	basis = basis.rotated(basis.x, clampf(float(input[2]), -1.0, 1.0)*PITCH_RATE*steer*delta)
	basis = basis.rotated(basis.z, -clampf(float(input[3]), -1.0, 1.0)*ROLL_RATE*delta)
	# The edge of the Reach: past the warning band the ship swings home.
	var out := xform.origin.length()-(SpaceLayout.WORLD_RADIUS-SpaceLayout.BOUNDARY_WARN)
	turned_back = out>0.0
	if turned_back:
		var home := Basis.looking_at(-xform.origin.normalized(), basis.y if absf(basis.y.dot(xform.origin.normalized()))<0.95 else Vector3.FORWARD)
		basis = basis.slerp(home, clampf(delta*(0.35+out/SpaceLayout.BOUNDARY_WARN*1.6), 0.0, 1.0))
		speed = minf(speed, BOOST_SPEED)
		pulse = false
	xform.basis = basis.orthonormalized()
	var forward := -xform.basis.z
	velocity = velocity.lerp(forward*speed, 1.0-exp(-delta*2.5))
	var next := xform.origin+velocity*delta
	var damage := 0
	# Planets (with their terrain) and the station push the hull out; fast contact hurts.
	for p: Dictionary in SpaceLayout.PLANETS:
		var c: Vector3 = p.center
		if next.distance_to(c)>float(p.radius)+SpaceLayout.max_height(p)+RADIUS: continue
		var n := (next-c).normalized()
		var min_d := float(p.radius)+maxf(0.0, SpaceLayout.surface_height(p, n))+RADIUS
		if next.distance_to(c)<min_d:
			next = c+n*min_d
			var into := -velocity.dot(n)
			if into>30.0: damage += int(into*2.0)
			velocity = velocity.slide(n)*0.5
			speed *= 0.5
	if next.distance_to(SpaceLayout.NEXUS)<SpaceLayout.STATION_RADIUS+RADIUS+10.0:
		var n := (next-SpaceLayout.NEXUS).normalized()
		next = SpaceLayout.NEXUS+n*(SpaceLayout.STATION_RADIUS+RADIUS+10.0)
		velocity = velocity.slide(n)
	# Nobody flies into the sun.
	var sun := next-SpaceLayout.SUN_CENTER
	if sun.length()<SpaceLayout.SUN_RADIUS+RADIUS*4.0:
		next = SpaceLayout.SUN_CENTER+sun.normalized()*(SpaceLayout.SUN_RADIUS+RADIUS*4.0)
		velocity = velocity.slide(sun.normalized())
	# The Nexus stands on a floating rock cone.
	var cone := NexusStation.rock_radius_at(next.y)+RADIUS
	var flat := Vector2(next.x, next.z)
	if cone>RADIUS and flat.length()<cone:
		var n := Vector3(flat.x, 0, flat.y).normalized() if flat.length()>0.1 else Vector3.RIGHT
		next = Vector3(n.x*cone, next.y, n.z*cone)
		velocity = velocity.slide(n)
	if absf(next.z-SpaceLayout.SHARDFIELD.center.z)<SpaceLayout.SHARDFIELD.extents.z+400.0:
		for rock: Array in asteroids:
			var at: Vector3 = rock[0]
			var r: float = float(rock[1])+RADIUS*0.7
			if absf(at.x-next.x)>r or absf(at.y-next.y)>r or absf(at.z-next.z)>r: continue
			if next.distance_to(at)<r:
				var n := (next-at).normalized()
				next = at+n*r
				var into := -velocity.dot(n)
				if into>8.0: damage += int(20.0+into*1.5)
				velocity = velocity.bounce(n)*0.35
				speed *= 0.35
	if next.length()>SpaceLayout.WORLD_RADIUS:
		next = next.normalized()*SpaceLayout.WORLD_RADIUS
		velocity = velocity.slide(next.normalized())
	xform.origin = next
	return damage

## Integrity of a part, 0..1.
func part(id: String) -> float:
	return clampf(float(parts.get(id, 100.0))/100.0, 0.0, 1.0)

## The part a hit at hull-space `local` strikes (the nearest one).
static func part_at(local: Vector3) -> String:
	var best := "hull"
	var best_d := INF
	for id: String in PARTS:
		var d := local.distance_to(PARTS[id].hull)
		if d<best_d:
			best_d = d
			best = id
	return best

## Whether the pulse drive may run here: clear of planets, the Nexus, the
## Shardfield and the edge of the Reach.
static func pulse_clear(at: Vector3) -> bool:
	if at.distance_to(SpaceLayout.NEXUS)<PULSE_CLEARANCE: return false
	if at.distance_to(SpaceLayout.SUN_CENTER)<SpaceLayout.SUN_RADIUS+SpaceLayout.SUN_BURN+PULSE_CLEARANCE: return false
	if at.length()>SpaceLayout.WORLD_RADIUS-SpaceLayout.BOUNDARY_WARN: return false
	if absf(at.z-SpaceLayout.SHARDFIELD.center.z)<SpaceLayout.SHARDFIELD.extents.z+600.0 and absf(at.x)<SpaceLayout.SHARDFIELD.extents.x+600.0: return false
	for p: Dictionary in SpaceLayout.PLANETS:
		if at.distance_to(p.center)<float(p.radius)*1.6+PULSE_CLEARANCE: return false
	return true

## Compact snapshot for clients.
func wire() -> Array:
	return [id, slot, name, owner, party, tint.to_html(false), xform, speed, mode, planet, hp, crew.duplicate(), aims.duplicate(), broken, repairs.duplicate(true), pulse, turned_back,
		parts.duplicate(), roundi(boost), glasses.duplicate(), smoking.keys()]

static func from_wire(data: Array, into: SpaceShip = null) -> SpaceShip:
	var s := into if into!=null else SpaceShip.new()
	s.id = int(data[0])
	s.slot = int(data[1])
	s.name = str(data[2])
	s.owner = int(data[3])
	s.party = int(data[4])
	s.tint = Color(str(data[5]))
	s.xform = data[6]
	s.speed = float(data[7])
	s.mode = str(data[8])
	s.planet = str(data[9])
	s.hp = int(data[10])
	s.crew = data[11]
	s.aims = data[12]
	s.broken = bool(data[13])
	s.repairs = data[14]
	s.pulse = bool(data[15]) if data.size()>15 else false
	s.turned_back = bool(data[16]) if data.size()>16 else false
	if data.size()>20:
		s.parts = data[17]
		s.boost = float(data[18])
		s.glasses = data[19]
		s.smoking = {}
		for pid: int in data[20]: s.smoking[pid] = 1.0
	return s
