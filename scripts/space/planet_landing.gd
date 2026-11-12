class_name PlanetLanding
extends RefCounted
## Where a ship can set down on a planet: from the point below it, a spiral
## search for the nearest ground that is level under the whole hull, dry,
## clear of the planet's obstacles (PlanetFlora) and of the story landmarks.
## Close to the timber pad the ship always uses the pad.
const SEARCH := 480.0  # metres of arc around the point below the ship
const STEP := 18.0
const FOOT := 24.0  # half length of the hull's footprint
const BEAM := 10.0  # half width
const CLEARANCE := 24.0  # no obstacle this close to the landing point
const MAX_STEP := 3.2  # height difference allowed under the footprint
const PAD_SNAP := 70.0

## The landed pose (world space) for a ship over `near` heading `forward`,
## or {} when nothing in reach is clear.
static func find_site(p: Dictionary, near: Vector3, forward: Vector3) -> Dictionary:
	var center: Vector3 = p.center
	var radius := float(p.radius)
	var dir0 := (near-center).normalized()
	var pad := SpaceLayout.pad_frame(p)
	var heading := (forward-dir0*forward.dot(dir0)).normalized()
	if heading.length()<0.5: heading = dir0.cross(Vector3.RIGHT).normalized()
	if acos(clampf(dir0.dot(pad.basis.y), -1.0, 1.0))*radius<PAD_SNAP:
		return {frame = _pose(p, pad.basis.y, heading, SpaceLayout.base_level(p)), pad = true}
	var side := heading.cross(dir0).normalized()
	var ring := 0.0
	while ring<=SEARCH:
		var count := 1 if ring==0.0 else maxi(6, int(TAU*ring/STEP))
		for k in count:
			var a := TAU*k/count
			var tangent := heading*cos(a)+side*sin(a)
			var dir := dir0 if ring==0.0 else (dir0*cos(ring/radius)+tangent*sin(ring/radius)).normalized()
			var top := _clear(p, dir, heading)
			if top>-INF: return {frame = _pose(p, dir, heading, top), pad = false}
		ring += STEP
	return {}

## The highest ground under the footprint at `dir`, or -INF when unsuitable.
static func _clear(p: Dictionary, dir: Vector3, heading: Vector3) -> float:
	var radius := float(p.radius)
	var h := SpaceLayout.surface_height(p, dir)
	if SpaceLayout.underwater(p, dir, 1.2): return -INF
	for flat: Array in SpaceLayout._flat_spots(p).slice(1):
		if acos(clampf(dir.dot(flat[0]), -1.0, 1.0))*radius<float(flat[1])+FOOT: return -INF
	var forward := (heading-dir*heading.dot(dir)).normalized()
	var right := forward.cross(dir).normalized()
	var low := h
	var high := h
	for offset: Vector2 in [Vector2(FOOT, 0), Vector2(-FOOT, 0), Vector2(0, BEAM), Vector2(0, -BEAM), Vector2(FOOT, BEAM), Vector2(-FOOT, -BEAM)]:
		var at := (dir*radius+forward*offset.x+right*offset.y).normalized()
		var sample := SpaceLayout.surface_height(p, at)
		low = minf(low, sample)
		high = maxf(high, sample)
		if high-low>MAX_STEP: return -INF
	if PlanetFlora.blocked(p, dir*(radius+h), CLEARANCE): return -INF
	return high

static func _pose(p: Dictionary, dir: Vector3, heading: Vector3, ground: float) -> Transform3D:
	var forward := (heading-dir*heading.dot(dir)).normalized()
	var origin: Vector3 = (p.center as Vector3)+dir*(float(p.radius)+ground+SpaceShip.LANDED_HEIGHT)
	return Transform3D(Basis.looking_at(forward, dir), origin)
