class_name SpaceShip
extends RefCounted
## One battleship's authoritative state and arcade flight model. The crew walk
## in its interior room (a pocket slot, see SpaceLayout); the hull flies
## outside. Modes: "berth" (docked at the Nexus), "flying", "landing",
## "landed" (on a planet pad).
const MAX_SPEED := 154.0
const BOOST_SPEED := 240.0
## The pulse drive crosses open space; it drops out near planets, the
## Nexus, the Shardfield and the edge of the Reach.
const PULSE_SPEED := 1300.0
const PULSE_CLEARANCE := 1600.0
const ACCEL := 63.0
const TURN_RATE := 1.0
const PITCH_RATE := 0.8
const ROLL_RATE := 1.5
const RADIUS := 24.0
const MAX_HP := 3200
## Ships only set down at a planet's ports (SpaceLayout.ports): low over one,
## within PORT_RANGE of it and under PORT_ALTITUDE, the pilot may land (X).
## Lower than MIN_ALTITUDE the ship's charm lifts her nose, as at the edge of
## the Reach, so she never flies into the ground.
const PORT_RANGE := 340.0
const PORT_ALTITUDE := 240.0
const MIN_ALTITUDE := 120.0
const LAND_SPEED := 140.0
## Orbit: within ORBIT_CAPTURE metres of a planet's ground she settles by
## herself into a circle ORBIT_ALTITUDE up (higher over the Lantern City's
## towers), nose along the horizon. Any steering takes her out of it; she
## settles again after ORBIT_SETTLE quiet seconds still in the band.
const ORBIT_CAPTURE := 600.0
const ORBIT_ALTITUDE := 200.0
const ORBIT_ALTITUDE_CITY := 360.0
const ORBIT_SETTLE := 4.0
const ORBIT_PULL := 0.7  # how firmly she swings onto the orbit (per second)
## Off a planet's pad she climbs at least this throttle until she is up at
## orbit height: nobody can stop her halfway, inside the planet's sky.
const LAUNCH_THRUST := 0.4
const LAND_TIME := 6.0
## Seats a crew member can take; the pilot flies, gunners aim turrets, the
## tavern chairs are for a drink and a cigar.
const SEATS := ["pilot", "turret_top", "turret_left", "turret_right", "map", "chair_0", "chair_1", "chair_2", "chair_3"]
## Parts that take damage where the ship is hit and are mended by the crew:
## where they sit on the hull (hull space, for which part a hit strikes),
## whether they are mended inside the room or outside, and where outside
## (`mend`, hull space: on deck, or at the stern on the jetpack).
## Sails steer, engines thrust, the top cannon fires, the heart fills the boost.
const PARTS := {
	sails = {name = "Sails", hull = Vector3(0, 12.0, -4), mend = Vector3(1.5, 4.1, -4.0), inside = false},
	engines = {name = "Engines", hull = Vector3(0, -1, 21), mend = Vector3(0, -0.6, 25.2), inside = false},
	turret = {name = "Top cannon", hull = Vector3(0, 5.3, -15), mend = Vector3(5.6, 4.1, -13.5), inside = false},
	heart = {name = "Heart crystal", hull = Vector3(0, -2, 6), inside = true},
}
## Hull restored by mending a part.
const REPAIR_HULL := 0.12
const REPAIR_TIME := 4.0
const BOOST_DRAIN := 24.0
const BOOST_REGEN := 13.0

var fleet_id := 0  # Persistent account-server identity; id below is local replication only.
var account_id := 0
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
## The port she has landed at (SpaceLayout.ports key), and her place while
## waiting for a busy one: [port name, place in line] or [].
var port := ""
var queue := []
## Part id -> integrity 0..100.
var parts := {sails = 100.0, engines = 100.0, turret = 100.0, heart = 100.0}
## Boost energy 0..100 (the pilot's bar).
var boost := 100.0
## Tavern aboard: glass level per chair (0..1) and who is smoking (pid -> seconds left).
var glasses := [1.0, 1.0, 1.0, 1.0]
var smoking := {}
var input_age := 0.0
var landing := {}  # {from: Transform3D, to: Transform3D, t: float, time: float, planet, port}
var cooldowns := {}
## A campaign cripples the ship until its crew mends every repair aboard.
var broken := false
## The planet she circles ("" when free), and seconds since the helm last steered.
var orbit := ""
## The planet she is climbing away from after a launch ("" once in orbit).
var climbing := ""
var _quiet := ORBIT_SETTLE
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

## Docked at the Nexus or landed on a planet: inside, only the helm and the
## boarding hatch work.
func grounded() -> bool:
	return mode in ["landed", "berth"]

## Just launched: helm cleared, straight into orbit (no waiting for quiet
## seconds), climbing at least LAUNCH_THRUST until up there.
func settle_orbit(from_planet: String) -> void:
	_quiet = ORBIT_SETTLE
	input = [0.0, 0.0, 0.0, 0.0, false, false]
	input_age = 0.0
	climbing = from_planet

## The throttle she holds (the helm's last), for a pilot taking the wheel.
func cruise() -> float:
	return clampf(float(input[0]), -1.0, 1.0)

## The planet whose orbit band she is in, or {}.
func orbit_planet() -> Dictionary:
	for p: Dictionary in SpaceLayout.PLANETS:
		if xform.origin.distance_to(p.center)>float(p.radius)+SpaceLayout.max_height(p)+ORBIT_CAPTURE: continue
		if altitude(p)<ORBIT_CAPTURE: return p
	return {}

## Swings the heading onto the orbit: along the horizon, climbing or sinking
## toward the orbit's height. Steering (yaw, pitch or roll) lets go at once.
func _orbit(basis: Basis, delta: float) -> Basis:
	var steering := absf(float(input[1]))+absf(float(input[2]))+absf(float(input[3]))>0.05
	_quiet = 0.0 if steering else _quiet+delta
	orbit = ""
	if pulse or _quiet<ORBIT_SETTLE: return basis
	var p := orbit_planet()
	if p.is_empty(): return basis
	orbit = str(p.id)
	var up := (xform.origin-(p.center as Vector3)).normalized()
	var ahead := (-basis.z).slide(up)
	if ahead.length()<0.05: ahead = basis.y.slide(up)
	var height := ORBIT_ALTITUDE_CITY if p.get("city", false) else ORBIT_ALTITUDE
	var climb := clampf((height-altitude(p))/150.0, -0.6, 0.6)
	var want := Basis.looking_at((ahead.normalized()+up*climb).normalized(), up)
	return basis.slerp(want, clampf(delta*ORBIT_PULL, 0.0, 1.0))

## The pad pose for this ship on a planet: keel resting just above the pad.
const LANDED_HEIGHT := 6.5
static func landed_pose(p: Dictionary) -> Transform3D:
	var frame := SpaceLayout.pad_frame(p)
	return Transform3D(frame.basis, frame.origin+frame.basis.y*LANDED_HEIGHT)

## Height above the ground below, or INF away from planets.
func altitude(p: Dictionary) -> float:
	var up: Vector3 = (xform.origin-(p.center as Vector3))
	return up.length()-float(p.radius)-SpaceLayout.surface_height(p, up.normalized())

## The port a pilot may land at from here (X): {planet, port}, or {}.
func landable() -> Dictionary:
	if mode!="flying" or speed>LAND_SPEED: return {}
	var best := {}
	var best_d := PORT_RANGE
	for p: Dictionary in SpaceLayout.PLANETS:
		if xform.origin.distance_to(p.center)>float(p.radius)+SpaceLayout.max_height(p)+PORT_ALTITUDE+PORT_RANGE: continue
		if altitude(p)>PORT_ALTITUDE: continue
		for entry: Dictionary in SpaceLayout.ports(p):
			var d := xform.origin.distance_to((entry.pose as Transform3D).origin)
			if d<best_d+PORT_ALTITUDE:
				var up := (entry.pose as Transform3D).basis.y
				var across := (xform.origin-(entry.pose as Transform3D).origin).slide(up).length()
				if across<best_d:
					best_d = across
					best = {planet = p, port = entry}
	return best

## Sets down on a port: an arc in from where she is.
func begin_landing(p: Dictionary, entry: Dictionary) -> void:
	var to: Transform3D = entry.pose
	landing = {from = xform, to = to, t = 0.0, time = LAND_TIME+xform.origin.distance_to(to.origin)/250.0, planet = p.id, port = entry.key}
	mode = "landing"
	queue = []
	speed = 0.0
	velocity = Vector3.ZERO

## Authority step. `asteroids` is SpaceLayout.asteroids(); returns impact damage taken.
func step(delta: float, asteroids: Array) -> int:
	input_age += delta
	# Nobody at the helm (or a pilot that went quiet): she holds her speed and
	# heading, so a crew can set a course and leave the wheel.
	if input_age>0.6: input = [float(input[0]), 0.0, 0.0, 0.0, false, bool(input[5]) if input.size()>5 else false]
	match mode:
		"descending":  # going down to the Surface (SpaceWorld retires it)
			return 0
		"landing":
			landing.t = minf(1.0, float(landing.t)+delta/float(landing.get("time", LAND_TIME)))
			var k := smoothstep(0.0, 1.0, float(landing.t))
			var from: Transform3D = landing.from
			var to: Transform3D = landing.to
			# Arc in from above the pad rather than through the ground.
			var lift := (to.basis.y*80.0)*sin(k*PI)*0.6
			xform = Transform3D(from.basis.slerp(to.basis, k), from.origin.lerp(to.origin, k)+lift)
			if landing.t>=1.0:
				mode = "landed"
				planet = str(landing.planet)
				port = str(landing.get("port", ""))
				landing = {}
			return 0
		"berth", "landed", "ascending", "transit", "surface_landing", "storing":
			return 0
	var thrust := 0.0 if broken else clampf(float(input[0]), -1.0, 1.0)
	if climbing!="":
		var from := SpaceLayout.planet(climbing)
		var height := ORBIT_ALTITUDE_CITY if from.get("city", false) else ORBIT_ALTITUDE
		if from.is_empty() or altitude(from)>=height*0.9: climbing = ""
		elif not broken: thrust = maxf(thrust, LAUNCH_THRUST)
	# Damaged parts: slow engines (never dead in space), sluggish helm, no boost without the heart.
	var engines := 0.3+0.7*part("engines")
	var heart_ok := part("heart")>0.35
	var boosting := bool(input[4]) and thrust>0.2 and heart_ok and boost>3.0 and climbing==""
	boost = clampf(boost-BOOST_DRAIN*delta if boosting else boost+BOOST_REGEN*part("heart")*delta, 0.0, 100.0)
	pulse = false  # the pulse drive is retired: Space boosts instead
	if pulse and (broken or thrust<0.2 or not heart_ok or not pulse_clear(xform.origin)): pulse = false
	var top := (PULSE_SPEED if pulse else BOOST_SPEED if boosting else MAX_SPEED)*engines
	var accel := ACCEL*engines*(8.0 if pulse or speed>BOOST_SPEED+1.0 else 2.2 if boosting else 1.0)
	speed = move_toward(speed, top*maxf(thrust, 0.0) if thrust>=0.0 else -25.0*-thrust, accel*delta)
	var steer := (0.45 if pulse else 1.0)*(0.4+0.6*part("sails"))
	var basis := xform.basis
	basis = basis.rotated(basis.y, -clampf(float(input[1]), -1.0, 1.0)*TURN_RATE*steer*delta)
	basis = basis.rotated(basis.x, clampf(float(input[2]), -1.0, 1.0)*PITCH_RATE*steer*delta)
	basis = basis.rotated(basis.z, -clampf(float(input[3]), -1.0, 1.0)*ROLL_RATE*delta)
	basis = _orbit(basis, delta)
	# The edge of the Reach: past the warning band the ship swings home.
	var out := xform.origin.length()-(SpaceLayout.WORLD_RADIUS-SpaceLayout.BOUNDARY_WARN)
	turned_back = out>0.0
	if turned_back:
		var home := Basis.looking_at(-xform.origin.normalized(), basis.y if absf(basis.y.dot(xform.origin.normalized()))<0.95 else Vector3.FORWARD)
		basis = basis.slerp(home, clampf(delta*(0.35+out/SpaceLayout.BOUNDARY_WARN*1.6), 0.0, 1.0))
		speed = minf(speed, BOOST_SPEED)
		pulse = false
	# Too low over a planet: the same charm lifts her nose away from the ground.
	for p: Dictionary in SpaceLayout.PLANETS:
		if xform.origin.distance_to(p.center)>float(p.radius)+SpaceLayout.max_height(p)+MIN_ALTITUDE+200.0: continue
		var low := MIN_ALTITUDE-altitude(p)
		if low<=0.0: continue
		var away := (xform.origin-(p.center as Vector3)).normalized()
		var ahead := (-basis.z).slide(away)
		if ahead.length()<0.1: ahead = basis.y.slide(away)
		var climb := (ahead.normalized()+away*0.7).normalized()
		basis = basis.slerp(Basis.looking_at(climb, away), clampf(delta*(0.6+low/MIN_ALTITUDE*3.0), 0.0, 1.0))
		var into := -velocity.dot(away)
		if into>0.0: velocity += away*into*clampf(delta*4.0, 0.0, 1.0)
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
	# The Surface's sky is the floor of Space.
	if next.y<SpaceLayout.SURFACE_FLOOR:
		next.y = SpaceLayout.SURFACE_FLOOR
		velocity.y = maxf(0.0, velocity.y)
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

## A part worn down to nothing (grey on the HUD, burning on the hull).
func part_destroyed(id: String) -> bool:
	return float(parts.get(id, 100.0))<=0.5

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
	if at.length()>SpaceLayout.WORLD_RADIUS-SpaceLayout.BOUNDARY_WARN: return false
	if absf(at.z-SpaceLayout.SHARDFIELD.center.z)<SpaceLayout.SHARDFIELD.extents.z+600.0 and absf(at.x)<SpaceLayout.SHARDFIELD.extents.x+600.0: return false
	for p: Dictionary in SpaceLayout.PLANETS:
		if at.distance_to(p.center)<float(p.radius)*1.6+PULSE_CLEARANCE: return false
	return true

## Compact snapshot for clients.
func wire() -> Array:
	return [id, slot, name, owner, party, tint.to_html(false), xform, speed, mode, planet, hp, crew.duplicate(), aims.duplicate(), broken, repairs.duplicate(true), pulse, turned_back,
		parts.duplicate(), roundi(boost), glasses.duplicate(), smoking.keys(), fleet_id, account_id, velocity, port, queue.duplicate(), orbit, climbing, cruise()]

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
	if data.size()>22:
		s.fleet_id = int(data[21])
		s.account_id = int(data[22])
	if data.size()>23 and data[23] is Vector3: s.velocity = data[23]
	if data.size()>25:
		s.port = str(data[24])
		s.queue = data[25]
	if data.size()>26: s.orbit = str(data[26])
	if data.size()>28:
		s.climbing = str(data[27])
		s.input[0] = float(data[28])
	return s

func fleet_state() -> Dictionary:
	return {hp = hp, parts = parts.duplicate(), boost = boost, glasses = glasses.duplicate(), tint = tint.to_html(false), broken = broken}

func apply_fleet_state(data: Dictionary) -> void:
	hp = clampi(int(data.get("hp", MAX_HP)), 1, MAX_HP)
	for key: String in PARTS:
		parts[key] = clampf(float(data.get("parts", {}).get(key, 100.0)), 0.0, 100.0)
	boost = clampf(float(data.get("boost", 100.0)), 0.0, 100.0)
	var drinks: Array = data.get("glasses", [1.0, 1.0, 1.0, 1.0])
	for i in 4: glasses[i] = clampf(float(drinks[i]) if i<drinks.size() else 1.0, 0.0, 1.0)
	tint = Color(str(data.get("tint", "ff9a6a")))
	broken = bool(data.get("broken", false))
