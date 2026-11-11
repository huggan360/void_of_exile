class_name CityTown
## The plan of one of Vesperis's towns, grown rather than ruled like the
## Tavern: a ring road round the spaceport, a few avenues winding out from it
## to the countryside (their ends are the gates the farm roads come in at),
## crescent lanes between the avenues at uneven distances and short lanes
## joining them, then plazas, parks and a pond in the gaps, the cafes, bars
## and shops along the inner streets and voxel houses along every street,
## doors to the sidewalk. Data only, the same on the server and every client.
##
## Plans are made on the town's tangent plane (CityLayout.district_frame,
## metres x/z) and laid onto the sphere by projecting through its centre
## (dir()), so every building gets its own level tangent frame (frame()).
const CELL := PI*0.5*1000.0/28.0  # a grid cell's size (m), for CityLayout's reach
const RING := 74.0  # the ring road round the spaceport (its ramps end at 63 m)
const RING_GAP := 58.0  # about how far apart the crescent lanes are
const WALK := 1.8  # sidewalk width
const HALF := {avenue = 4.0, ring = 3.4, lane = 2.6}
static var _plans := {}

## A point of the town's plane as a unit direction from the planet's centre.
static func dir(d: Dictionary, p: Vector2) -> Vector3:
	var f := CityLayout.district_frame(d)
	return (f.origin+f.basis.x*p.x+f.basis.z*p.y).normalized()

## The plane point under a unit direction (inverse of dir()).
static func plane(d: Dictionary, direction: Vector3) -> Vector2:
	var f := CityLayout.district_frame(d)
	var up := f.origin.normalized()
	var hit := direction*(f.origin.length()/maxf(0.0001, direction.dot(up)))
	var v := hit-f.origin
	return Vector2(v.dot(f.basis.x), v.dot(f.basis.z))

## A level frame (planet space) on the ground at plane point `p`, its -Z along
## the plane direction `forward`.
static func frame(d: Dictionary, p: Vector2, forward: Vector2, lift := 0.0) -> Transform3D:
	var f := CityLayout.district_frame(d)
	var up := dir(d, p)
	var ahead := f.basis.x*forward.x+f.basis.z*forward.y
	var out := CityLayout._tangent(up, -ahead)
	out.origin = up*(CityLayout.radius()+lift)
	return out

## How far the town reaches toward plane angle `a` (m).
static func edge(d: Dictionary, a: float) -> float:
	# The plane's +z runs along the grid's -v (CityLayout.frame_at).
	return CityLayout.edge(d, atan2(-sin(a), cos(a)))*CELL

static func inside(d: Dictionary, p: Vector2, margin := 0.0) -> bool:
	return p.length()<edge(d, p.angle())-margin

## Whether a unit direction lies in any town (the farm roads stop there).
static func in_any(direction: Vector3, margin := 0.0) -> bool:
	for d: Dictionary in CityLayout.DISTRICTS:
		var c := CityLayout.district_frame(d).origin.normalized()
		if direction.dot(c)<0.8: continue
		if inside(d, plane(d, direction), margin): return true
	return false

## A round park or pond as a block for CityArt and CityRoads.field(): a
## polygon whose edges stand ROAD+WALK outside the plot, so the art's usual
## "lot" from the street lands on the plot's own rim. In its own level frame.
static func green_block(d: Dictionary, spot: Array, role: String) -> Dictionary:
	var radius := float(spot[1])+CityLayout.ROAD+CityLayout.WALK
	var corners: Array[Vector2] = []
	var segs: Array = []
	for k in 20: corners.append(Vector2.from_angle(TAU*k/20.0)*radius)
	for k in 20: segs.append([corners[k], corners[(k+1) % 20], false])
	return {face = 0, i = 0, j = 0, sub = 0, key = "%s_%s_%d" % [d.id, role, int((spot[0] as Vector2).length())], segs = segs, rounds = [],
		corners = corners, seed = Vector2.ZERO, role = role, frame = frame(d, spot[0], Vector2(0, -1))}

static func _r(d: Dictionary, salt: int) -> float:
	return CityLayout.rnd(float(d.seed), salt)

# --- The plan ------------------------------------------------------------------------------

## {streets: [{pts: PackedVector2Array, half, kind}], gates: [Vector2],
##  spire: {at, forward} or {}, plazas/parks/lakes: [[at, radius]],
##  rooms: [{at, forward}], houses: [{name, at, forward}], green: [[at, radius]]}
static func plan(d: Dictionary) -> Dictionary:
	if _plans.has(d.id): return _plans[d.id]
	var out := {streets = [], gates = [], spire = {}, plazas = [], parks = [], lakes = [], rooms = [], houses = [], green = []}
	var k := 6 if d.id==CityLayout.SPIRE_DISTRICT else 5
	var turn := _r(d, 1)*TAU
	var aves: Array[float] = []
	for i in k: aves.append(turn+i*TAU/k+(_r(d, 10+i)-0.5)*0.4)
	var far := 0.0
	for i in 72: far = maxf(far, edge(d, TAU*i/72.0))
	# The ring road round the port.
	var ring := PackedVector2Array()
	for i in 61:
		var a := TAU*i/60.0
		ring.append(Vector2.from_angle(a)*RING*(1.0+0.03*sin(a*3.0+turn)))
	out.streets.append({pts = ring, half = HALF.ring, kind = "ring"})
	# Avenues: from the ring out past the edge, gently winding.
	for i in k:
		var pts := PackedVector2Array()
		var r := RING
		var stop := edge(d, aves[i])+6.0
		while r<=stop:
			pts.append(Vector2.from_angle(_ave_angle(d, aves[i], i, r))*r)
			r += 8.0
		out.streets.append({pts = pts, half = HALF.avenue, kind = "avenue"})
		out.gates.append(pts[pts.size()-1])
	# Reserved round places: the Spire, plazas, parks, a pond (in the gaps).
	var reserved: Array = []
	var radii: Array[float] = []
	var rr := RING+RING_GAP*(0.9+_r(d, 20)*0.25)
	while rr<far-30.0:
		radii.append(rr)
		rr += RING_GAP*(0.85+_r(d, 21+radii.size())*0.35)
	var gap_at := func(sector: int, band: int, size: float) -> Array:
		var a0 := aves[sector % k]
		var a1 := aves[(sector+1) % k]+(TAU if sector==k-1 else 0.0)
		var inner := RING if band==0 else radii[band-1]
		var outer := radii[band] if band<radii.size() else inner+RING_GAP
		var mid := (inner+outer)*0.5
		var a := (a0+a1)*0.5
		return [Vector2.from_angle(a)*mid, minf(size, (outer-inner)*0.5-5.0)]
	if d.id==CityLayout.SPIRE_DISTRICT:
		var spot: Array = gap_at.call(0, 0, 15.0)
		var at: Vector2 = spot[0]
		out.spire = {at = at, forward = -at.normalized()}
		reserved.append([at, 14.0])
		# A clear way from its door to the ring road.
		for t: float in [0.72, 0.86]: reserved.append([at*t, 6.5])
	for name: String in ["lakes", "parks", "plazas"]:
		var count: int = {plazas = 2, parks = 2, lakes = 1}[name]
		var tries := 0
		while (out[name] as Array).size()<count and tries<24:
			tries += 1
			var salt := tries*31+name.length()*7
			var sector := int(_r(d, 30+salt)*k) % k
			var band := int(_r(d, 40+salt)*(radii.size()+1)) % (radii.size()+1)
			var spot: Array = gap_at.call(sector, band, {plazas = 14.0, parks = 22.0, lakes = 19.0}[name])
			if float(spot[1])<9.0 or not inside(d, spot[0], float(spot[1])+6.0): continue
			if reserved.any(func(x: Array) -> bool: return (x[0] as Vector2).distance_to(spot[0])<float(x[1])+float(spot[1])+8.0): continue
			out[name].append(spot)
			reserved.append(spot)
	# Crescent lanes between the avenues, broken now and then, and short
	# lanes joining one crescent to the next.
	for band in radii.size():
		for s in k:
			if _r(d, 100+band*10+s)<0.18: continue
			var a0 := aves[s]
			var a1 := aves[(s+1) % k]+(TAU if s==k-1 else 0.0)
			var pts := PackedVector2Array()
			var steps := maxi(4, int((a1-a0)*radii[band]/7.0))
			for q in steps+1:
				var a := lerpf(a0, a1, float(q)/steps)
				var ra := radii[band]*(1.0+0.05*sin(a*3.0+band+turn))
				var at := Vector2.from_angle(_ave_angle(d, a0, s, ra) if q==0 else _ave_angle(d, aves[(s+1) % k], (s+1) % k, ra) if q==steps else a)*ra
				if not inside(d, at, 18.0) or _blocked(reserved, at, HALF.ring+6.0):
					if pts.size()>2: out.streets.append({pts = pts, half = HALF.ring, kind = "ring"})
					pts = PackedVector2Array()
					continue
				pts.append(at)
			if pts.size()>2: out.streets.append({pts = pts, half = HALF.ring, kind = "ring"})
			# A lane across to the next crescent, off the middle of the arc.
			if band+1<radii.size() and _r(d, 200+band*10+s)<0.75:
				var a := lerpf(a0, a1, 0.35+_r(d, 300+band*10+s)*0.3)
				var lane := PackedVector2Array()
				var r0 := radii[band]*(1.0+0.05*sin(a*3.0+band+turn))
				var r1 := radii[band+1]*(1.0+0.05*sin(a*3.0+band+1+turn))
				var ok := true
				for q in 7:
					var t := q/6.0
					var at := Vector2.from_angle(a+sin(t*PI)*0.06)*lerpf(r0, r1, t)
					if not inside(d, at, 18.0) or _blocked(reserved, at, HALF.lane+5.0): ok = false
					lane.append(at)
				if ok: out.streets.append({pts = lane, half = HALF.lane, kind = "lane"})
	# Rooms (cafes, bars, shops) along the avenues near the port, both sides.
	var index := _Index.new(out.streets)
	var target := 30 if d.id==CityLayout.SPIRE_DISTRICT else 18
	var rooms: Array = []
	for pass_k in 2:
		for i in k:
			var street: Dictionary = out.streets[1+i]
			for side: float in [-1.0, 1.0]:
				_line_up(street, side, 3.0+pass_k*9.5, func(at: Vector2, along: Vector2, normal: Vector2) -> float:
					if rooms.size()>=target or at.length()>RING+150.0: return -1.0
					var size := Vector2(19.5, 15.5)  # the hall round the room
					var center: Vector2 = at+normal*(float(street.half)+WALK+0.4+size.y*0.5)
					if not _fits(index, reserved, out.rooms, center, along, size, d): return 3.0
					out.rooms.append({at = center, forward = -normal, size = size, along = along})
					rooms.append(center)
					return size.x+3.0)
	# Houses along every street, both sides.
	var houses := CityHouses.HOUSES
	var salt := [0]  # shared with the lambda (captured locals are copies)
	for street: Dictionary in out.streets:
		for side: float in [-1.0, 1.0]:
			salt[0] += 1
			_line_up(street, side, _r(d, 500+salt[0])*5.0, func(at: Vector2, along: Vector2, normal: Vector2) -> float:
				salt[0] += 1
				var name: String = houses[int(_r(d, 1000+salt[0])*houses.size()) % houses.size()]
				var fp := CityHouses.footprint(name)
				var size := fp.size+Vector2(1.2, 1.2)
				var center := at+normal*(float(street.half)+WALK+0.5+size.y*0.5)
				if not _fits(index, reserved, out.rooms+out.houses, center, along, size, d): return 2.5
				var forward := -normal
				# The model's origin is its door: shift so the footprint's middle lands at `center`.
				var right := Vector2(-forward.y, forward.x)  # the model's +X
				var mid := fp.get_center()
				var origin := center-(right*mid.x-forward*mid.y)
				out.houses.append({name = name, at = origin, forward = forward, size = size, along = along, center = center})
				return size.x+lerpf(0.6, 3.5, _r(d, 2000+salt[0])))
	# A tree in some back gardens, clear of the streets and the other buildings.
	var all: Array = out.rooms+out.houses
	for n in out.houses.size():
		if _r(d, 3000+n)>0.55: continue
		var h: Dictionary = out.houses[n]
		var at: Vector2 = (h.center as Vector2)-(h.forward as Vector2)*((h.size as Vector2).y*0.5+3.2)
		if index.clearance(at)<2.0 or _blocked(reserved, at, 3.0) or not inside(d, at, 4.0): continue
		if all.any(func(o: Dictionary) -> bool: return _overlap(at, Vector2.RIGHT, Vector2(4.5, 4.5), o.get("center", o.at), o.along, o.size)): continue
		if out.green.any(func(g: Array) -> bool: return (g[0] as Vector2).distance_to(at)<6.0): continue
		out.green.append([at, lerpf(2.2, 3.4, _r(d, 4000+n))])
	_plans[d.id] = out
	return out

## The angle an avenue (base `a`, index `i`) has at radius `r`.
static func _ave_angle(d: Dictionary, a: float, i: int, r: float) -> float:
	return a+0.16*sin(r/70.0+i*1.3+float(d.seed)*9.0)

static func _blocked(reserved: Array, at: Vector2, clear: float) -> bool:
	for x: Array in reserved:
		if (x[0] as Vector2).distance_to(at)<float(x[1])+clear: return true
	return false

## Walks one side of a street; `place(at, along, normal)` returns how far to
## step on (or < 0 to stop). `normal` points away from the street to that side.
static func _line_up(street: Dictionary, side: float, start: float, place: Callable) -> void:
	var pts: PackedVector2Array = street.pts
	var lengths := PackedFloat32Array([0.0])
	for i in pts.size()-1: lengths.append(lengths[i]+pts[i].distance_to(pts[i+1]))
	var total := lengths[lengths.size()-1]
	var s := start
	while s<total-2.0:
		var i := clampi(lengths.bsearch(s)-1, 0, pts.size()-2)
		var along := (pts[i+1]-pts[i]).normalized()
		var at := pts[i].lerp(pts[i+1], clampf((s-lengths[i])/maxf(0.01, lengths[i+1]-lengths[i]), 0.0, 1.0))
		var normal := Vector2(-along.y, along.x)*side
		var step: float = place.call(at, along, normal)
		if step<0.0: return
		s += step

## A rectangle (centre, its x along `along`, size) is clear of every street's
## sidewalk, the reserved places, the other buildings and the town's edge.
static func _fits(index: _Index, reserved: Array, others: Array, center: Vector2, along: Vector2, size: Vector2, d: Dictionary) -> bool:
	if not inside(d, center, size.length()*0.5+4.0): return false
	if absf(center.x)<66.0 and absf(center.y)<66.0: return false  # the spaceport and its ramps
	var normal := Vector2(-along.y, along.x)
	var corners: Array[Vector2] = []
	for c: Vector2 in [Vector2(-0.5, -0.5), Vector2(0.5, -0.5), Vector2(0.5, 0.5), Vector2(-0.5, 0.5), Vector2(0, -0.5), Vector2(0, 0.5), Vector2(-0.5, 0), Vector2(0.5, 0)]:
		corners.append(center+along*c.x*size.x+normal*c.y*size.y)
	for c: Vector2 in corners:
		if index.clearance(c)<0.15: return false
		for x: Array in reserved:
			if (x[0] as Vector2).distance_to(c)<float(x[1])+1.0: return false
	var r := size.length()*0.5
	for o: Dictionary in others:
		var oc: Vector2 = o.get("center", o.at)
		if oc.distance_to(center)>r+(o.size as Vector2).length()*0.5: continue
		if _overlap(center, along, size, oc, o.along, o.size): return false
	return true

## Two rectangles (centre, x axis, size) overlap (separating axes).
static func _overlap(ca: Vector2, xa: Vector2, sa: Vector2, cb: Vector2, xb: Vector2, sb: Vector2) -> bool:
	var axes: Array[Vector2] = [xa, Vector2(-xa.y, xa.x), xb, Vector2(-xb.y, xb.x)]
	for axis in axes:
		var pa := absf(xa.dot(axis))*sa.x*0.5+absf(Vector2(-xa.y, xa.x).dot(axis))*sa.y*0.5
		var pb := absf(xb.dot(axis))*sb.x*0.5+absf(Vector2(-xb.y, xb.x).dot(axis))*sb.y*0.5
		if absf((cb-ca).dot(axis))>pa+pb: return false
	return true

## Street segments in a coarse grid: how far a point is outside every
## street's sidewalk (negative inside one).
class _Index extends RefCounted:
	const SIZE := 24.0
	var cells := {}
	func _init(streets: Array) -> void:
		for st: Dictionary in streets:
			var pts: PackedVector2Array = st.pts
			for i in pts.size()-1:
				var lo := (pts[i].min(pts[i+1])/SIZE).floor()
				var hi := (pts[i].max(pts[i+1])/SIZE).floor()
				for x in range(int(lo.x)-1, int(hi.x)+2):
					for y in range(int(lo.y)-1, int(hi.y)+2):
						var key := Vector2i(x, y)
						if not cells.has(key): cells[key] = []
						cells[key].append([pts[i], pts[i+1], float(st.half)+CityTown.WALK])
	func clearance(p: Vector2) -> float:
		var best := 1e9
		for seg: Array in cells.get(Vector2i((p/SIZE).floor()), []):
			var a: Vector2 = seg[0]
			var ab: Vector2 = (seg[1] as Vector2)-a
			var t := clampf((p-a).dot(ab)/maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
			best = minf(best, p.distance_to(a+ab*t)-float(seg[2]))
		return best
