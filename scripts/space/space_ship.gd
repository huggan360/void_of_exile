class_name SpaceShip
extends RefCounted
## One battleship's authoritative state and arcade flight model. The crew walk
## in its interior room (a pocket slot, see SpaceLayout); the hull flies
## outside. Modes: "berth" (docked at the Nexus), "flying", "landing",
## "landed" (on a planet pad).
const MAX_SPEED := 150.0
const BOOST_SPEED := 330.0
const ACCEL := 70.0
const TURN_RATE := 1.15
const PITCH_RATE := 0.9
const ROLL_RATE := 1.6
const RADIUS := 15.0
const MAX_HP := 2400
const LAND_RANGE := 320.0
const LAND_TIME := 5.0
## Seats a crew member can take; the pilot flies, gunners aim turrets.
const SEATS := ["pilot", "turret_top", "turret_left", "turret_right", "map"]

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
var input := [0.0, 0.0, 0.0, 0.0, false]  # thrust, yaw, pitch, roll, boost
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

## The pad pose for this ship on a planet: hull floating 3 m above the pad.
static func landed_pose(p: Dictionary) -> Transform3D:
	var frame := SpaceLayout.pad_frame(p)
	return Transform3D(frame.basis, frame.origin+frame.basis.y*3.0)

## The planet a pilot may land on from here, or {}.
func landable() -> Dictionary:
	if mode!="flying" or speed>90.0: return {}
	for p: Dictionary in SpaceLayout.PLANETS:
		var to_pad := landed_pose(p).origin
		if xform.origin.distance_to(to_pad)<LAND_RANGE+float(p.radius)*0.5: return p
	return {}

func begin_landing(p: Dictionary) -> void:
	landing = {from = xform, to = landed_pose(p), t = 0.0, planet = p.id}
	mode = "landing"
	speed = 0.0
	velocity = Vector3.ZERO

## Authority step. `asteroids` is SpaceLayout.asteroids(); returns impact damage taken.
func step(delta: float, asteroids: Array) -> int:
	input_age += delta
	if input_age>0.6: input = [0.0, 0.0, 0.0, 0.0, false]  # a pilot that went quiet
	match mode:
		"landing":
			landing.t = minf(1.0, float(landing.t)+delta/LAND_TIME)
			var k := smoothstep(0.0, 1.0, float(landing.t))
			var from: Transform3D = landing.from
			var to: Transform3D = landing.to
			# Arc in from above the pad rather than through the ground.
			var lift := (to.basis.y*60.0)*sin(k*PI)*0.6
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
				# Lift clear of the pad or berth before turning loose.
				velocity = xform.basis.y*25.0
				speed = 0.0
			return 0
	var thrust := 0.0 if broken else clampf(float(input[0]), -1.0, 1.0)
	var top := BOOST_SPEED if bool(input[4]) else MAX_SPEED
	speed = move_toward(speed, top*maxf(thrust, 0.0) if thrust>=0.0 else -25.0*-thrust, ACCEL*delta*(2.2 if bool(input[4]) else 1.0))
	var basis := xform.basis
	basis = basis.rotated(basis.y, -clampf(float(input[1]), -1.0, 1.0)*TURN_RATE*delta)
	basis = basis.rotated(basis.x, clampf(float(input[2]), -1.0, 1.0)*PITCH_RATE*delta)
	basis = basis.rotated(basis.z, -clampf(float(input[3]), -1.0, 1.0)*ROLL_RATE*delta)
	xform.basis = basis.orthonormalized()
	var forward := -xform.basis.z
	velocity = velocity.lerp(forward*speed, 1.0-exp(-delta*2.5))
	var next := xform.origin+velocity*delta
	var damage := 0
	# Planets and the station push the hull out; fast contact hurts.
	for p: Dictionary in SpaceLayout.PLANETS:
		var c: Vector3 = p.center
		var min_d := float(p.radius)+RADIUS
		if next.distance_to(c)<min_d:
			var n := (next-c).normalized()
			next = c+n*min_d
			var into := -velocity.dot(n)
			if into>30.0: damage += int(into*2.0)
			velocity = velocity.slide(n)*0.5
			speed *= 0.5
	if next.distance_to(SpaceLayout.NEXUS)<SpaceLayout.STATION_RADIUS+RADIUS+10.0:
		var n := (next-SpaceLayout.NEXUS).normalized()
		next = SpaceLayout.NEXUS+n*(SpaceLayout.STATION_RADIUS+RADIUS+10.0)
		velocity = velocity.slide(n)
	if absf(next.z-SpaceLayout.SHARDFIELD.center.z)<SpaceLayout.SHARDFIELD.extents.z+60.0:
		for rock: Array in asteroids:
			var at: Vector3 = rock[0]
			var r: float = float(rock[1])+RADIUS*0.7
			if absf(at.x-next.x)>r or absf(at.y-next.y)>r: continue
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

## Compact snapshot for clients.
func wire() -> Array:
	return [id, slot, name, owner, party, tint.to_html(false), xform, speed, mode, planet, hp, crew.duplicate(), aims.duplicate(), broken, repairs.duplicate(true)]

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
	return s
