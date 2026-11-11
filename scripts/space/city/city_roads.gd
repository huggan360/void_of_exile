class_name CityRoads
## Vesperis's street network (data only, the same on the server and every
## client). The corners of the cell grid (CityLayout) are nudged about, streets
## bend between them, a few blocks are cut by a diagonal street and some
## corners are roundabouts, so the city reads as grown rather than ruled.
## Blocks that hold fixed rooms (the spaceport, the Lantern Spire) keep
## straight streets; the blocks of shop and bar halls only lean a little.
##
## Everything is kept as unit directions from the planet centre. The ground
## shader reads the same numbers from texture() (four texels per corner: the
## corner, the bend of the street along u, along v, and the diagonal), so the
## painted streets and the kerbs and buildings always agree.
const JITTER := 0.2  # corner nudge in cells, open city
const JITTER_SHOP := 0.07  # next to shop blocks
const BEND := 0.11  # sideways bend of a street's middle, in cells
const ISLAND := 4.5  # roundabout island radius (m)
const RING := 6.0  # ring road width round the island (m)
const KERB := 0.16  # sidewalk height (m)
static var _nodes := {}  # Vector3i(face, i, j) -> [dir, round radius, mid u dir, has u, mid v dir, has v, diag mid dir, diag type]
static var _texture: ImageTexture
static var _blocks := {}

static func _n() -> int: return CityLayout.N

# --- Rules -------------------------------------------------------------------------------

## How a corner may move: 0 still, 1 a little (shops), 2 freely; -1 keeps it
## still and never a roundabout (the port, the face edges).
static func _freedom(face: int, i: int, j: int) -> int:
	var n := _n()
	if i<=0 or j<=0 or i>=n or j>=n: return -1
	var out := 2
	for c: Vector2i in [Vector2i(i-1, j-1), Vector2i(i, j-1), Vector2i(i-1, j), Vector2i(i, j)]:
		match CityLayout.role(face, c.x, c.y):
			"port": return -1
			"spire": out = 0
			"venues": out = mini(out, 1)
	return out

## Cells whose street between them is dropped (a district's lake or park
## spans both, or its spaceport building stands over them).
static func merged(face: int, a: Vector2i, b: Vector2i) -> bool:
	var ra := CityLayout.role(face, a.x, a.y)
	if not ra in ["lake", "park", "port"] or ra!=CityLayout.role(face, b.x, b.y): return false
	var da := CityLayout.district_of(face, a.x, a.y)
	var db := CityLayout.district_of(face, b.x, b.y)
	return not da.is_empty() and not db.is_empty() and da.district.id==db.district.id

## No grid streets any more: the towns grow their own (CityTown) and the
## farmland has its winding country roads (CityCountry). The grid is kept for
## the ground shader's lookups and is empty.
static func _city_side(_face: int, _cells: Array) -> bool:
	return false

## Bending is only for streets between open blocks.
static func _may_bend(face: int, cells: Array) -> bool:
	for c: Vector2i in cells:
		if c.x<0 or c.y<0 or c.x>=_n() or c.y>=_n(): return false
		if CityLayout.role(face, c.x, c.y) in ["port", "spire", "venues"]: return false
	return true

static func _grid_dir(face: int, gi: float, gj: float) -> Vector3:
	return CityLayout.face_dir(face, gi/_n()*2.0-1.0, gj/_n()*2.0-1.0)

static func _r(face: int, i: int, j: int, salt: int) -> float:
	return CityLayout._hash(face*7919+i*104729+j*1299709+salt*15485863)

# --- Corners and streets -----------------------------------------------------------------------

## [dir, round, mid_u, has_u, mid_v, has_v, mid_d, diag] for corner (i, j).
static func node(face: int, i: int, j: int) -> Array:
	var key := Vector3i(face, i, j)
	if _nodes.has(key): return _nodes[key]
	var n := _n()
	var free := _freedom(face, i, j)
	var amount := JITTER if free==2 else JITTER_SHOP if free==1 else 0.0
	var g := Vector2(i, j)+Vector2(_r(face, i, j, 1)-0.5, _r(face, i, j, 2)-0.5)*2.0*amount
	var dir := _grid_dir(face, g.x, g.y)
	var round := 0.0
	var out: Array = [dir, round, Vector3.ZERO, false, Vector3.ZERO, false, Vector3.ZERO, 0]
	_nodes[key] = out
	# Streets to the next corners (their middles bend sideways).
	if i<n:
		var keep := not (j>0 and j<n and merged(face, Vector2i(i, j-1), Vector2i(i, j))) and _city_side(face, [Vector2i(i, j-1), Vector2i(i, j)])
		var bend := (_r(face, i, j, 4)-0.5)*2.0*BEND if _may_bend(face, [Vector2i(i, j-1), Vector2i(i, j)]) else 0.0
		var a := _node_g(face, i, j)
		var b := _node_g(face, i+1, j)
		var mid := (a+b)*0.5+Vector2(-(b-a).y, (b-a).x).normalized()*bend
		out[2] = _grid_dir(face, mid.x, mid.y)
		out[3] = keep
	if j<n:
		var keep := not (i>0 and i<n and merged(face, Vector2i(i-1, j), Vector2i(i, j))) and _city_side(face, [Vector2i(i-1, j), Vector2i(i, j)])
		var bend := (_r(face, i, j, 5)-0.5)*2.0*BEND if _may_bend(face, [Vector2i(i-1, j), Vector2i(i, j)]) else 0.0
		var a := _node_g(face, i, j)
		var b := _node_g(face, i, j+1)
		var mid := (a+b)*0.5+Vector2(-(b-a).y, (b-a).x).normalized()*bend
		out[4] = _grid_dir(face, mid.x, mid.y)
		out[5] = keep
	if i<n and j<n and CityLayout.role(face, i, j) in ["skyline", "district"] and _r(face, i, j, 6)<0.11:
		var t := 1 if _r(face, i, j, 7)<0.5 else 2
		var a := _node_g(face, i, j) if t==1 else _node_g(face, i+1, j)
		var b := _node_g(face, i+1, j+1) if t==1 else _node_g(face, i, j+1)
		var mid := (a+b)*0.5+Vector2(-(b-a).y, (b-a).x).normalized()*(_r(face, i, j, 8)-0.5)*0.2
		out[6] = _grid_dir(face, mid.x, mid.y)
		out[7] = t
	return out

## A corner's nudged position in grid units (no recursion into node()).
static func _node_g(face: int, i: int, j: int) -> Vector2:
	var free := _freedom(face, i, j)
	var amount := JITTER if free==2 else JITTER_SHOP if free==1 else 0.0
	return Vector2(i, j)+Vector2(_r(face, i, j, 1)-0.5, _r(face, i, j, 2)-0.5)*2.0*amount

static func dir(face: int, i: int, j: int) -> Vector3: return node(face, i, j)[0]
static func round_at(face: int, i: int, j: int) -> float: return float(node(face, i, j)[1])

## The streets of a cell's four sides and its diagonal as unit-direction
## polylines: [{points: [a, mid, b], ends: [corner a, corner b]}].
static func cell_streets(face: int, i: int, j: int) -> Array:
	var out: Array = []
	var add := func(a: Vector2i, b: Vector2i, mid: Vector3) -> void:
		out.append({points = [dir(face, a.x, a.y), mid, dir(face, b.x, b.y)], ends = [a, b]})
	var here := node(face, i, j)
	if here[3]: add.call(Vector2i(i, j), Vector2i(i+1, j), here[2])
	if here[5]: add.call(Vector2i(i, j), Vector2i(i, j+1), here[4])
	var up := node(face, i, j+1)
	if up[3]: add.call(Vector2i(i, j+1), Vector2i(i+1, j+1), up[2])
	var right := node(face, i+1, j)
	if right[5]: add.call(Vector2i(i+1, j), Vector2i(i+1, j+1), right[4])
	match int(here[7]):
		1: add.call(Vector2i(i, j), Vector2i(i+1, j+1), here[6])
		2: add.call(Vector2i(i+1, j), Vector2i(i, j+1), here[6])
	return out

## The roundabout nearest `at` (planet space) within `reach`, as planet space, or INF.
static func nearest_roundabout(at: Vector3, reach: float) -> Vector3:
	var uv := CityLayout.face_uv(at.normalized())
	var face := int(uv[0])
	var gi := roundi((float(uv[1])+1.0)*0.5*_n())
	var gj := roundi((float(uv[2])+1.0)*0.5*_n())
	var best := Vector3.INF
	var span := int(ceil(reach/50.0))+1
	for dj in range(-span, span+1):
		for di in range(-span, span+1):
			var i := gi+di
			var j := gj+dj
			if i<0 or j<0 or i>_n() or j>_n() or round_at(face, i, j)<=0.0: continue
			var p := dir(face, i, j)*CityLayout.radius()
			if p.distance_to(at)<reach and (not best.is_finite() or p.distance_to(at)<best.distance_to(at)): best = p
	return best

# --- The ground shader's copy -------------------------------------------------------------------

## Four texels per corner (x = i*4+k, y = face*(N+1)+j): the corner (a = island
## radius), the street along u (rgb its bend, a = 1 if there), along v, and
## the diagonal (a = 0 none, 1 from this corner to (i+1, j+1), 2 from (i+1, j) to (i, j+1)).
static func texture() -> ImageTexture:
	if _texture: return _texture
	var n := _n()
	var image := Image.create(4*(n+1), 6*(n+1), false, Image.FORMAT_RGBAF)
	for face in 6:
		for j in n+1:
			for i in n+1:
				var d := node(face, i, j)
				var y := face*(n+1)+j
				var pack := func(v: Vector3, a: float) -> Color: return Color(v.x, v.y, v.z, a)
				image.set_pixel(i*4, y, pack.call(d[0], float(d[1])))
				image.set_pixel(i*4+1, y, pack.call(d[2], 1.0 if d[3] else 0.0))
				image.set_pixel(i*4+2, y, pack.call(d[4], 1.0 if d[5] else 0.0))
				image.set_pixel(i*4+3, y, pack.call(d[6], float(d[7])))
	_texture = ImageTexture.create_from_image(image)
	return _texture

# --- Blocks --------------------------------------------------------------------------------------

## What stands between the streets of a cell, in the cell's own frame (metres,
## x/z of CityLayout.cell's frame): [{key, seed, segs: [[a, b, t0, t1]], rounds:
## [[centre, radius]], role, face, i, j, sub}]. A diagonal cuts a cell into two
## blocks. A district's lake or park over two cells, or its port over four,
## is one block (in the lowest cell; the others have none).
static func blocks(face: int, i: int, j: int) -> Array:
	var key := Vector3i(face, i, j)
	if _blocks.has(key): return _blocks[key]
	var out: Array = []
	var cells: Array[Vector2i] = [Vector2i(i, j)]
	for other: Vector2i in [Vector2i(i-1, j), Vector2i(i, j-1)]:
		if other.x>=0 and other.y>=0 and merged(face, other, Vector2i(i, j)):
			_blocks[key] = out
			return out
	for other: Vector2i in [Vector2i(i+1, j), Vector2i(i, j+1)]:
		if other.x<_n() and other.y<_n() and merged(face, Vector2i(i, j), other): cells.append(other)
	# The port's 2 x 2: the far cell too.
	if cells.size()==3 and merged(face, Vector2i(i+1, j), Vector2i(i+1, j+1)): cells.append(Vector2i(i+1, j+1))
	var frame: Transform3D = CityLayout.cell(face, i, j).frame
	var inv := frame.affine_inverse()
	var r := CityLayout.radius()
	var flat := func(d: Vector3) -> Vector2:
		var p := inv*(d*r)
		return Vector2(p.x, p.z)
	var segs: Array = []
	var rounds: Array = []
	var corners: Array[Vector2] = []
	var diag := 0
	for c: Vector2i in cells:
		for street: Dictionary in cell_streets(face, c.x, c.y):
			var pts: Array = street.points
			var a: Vector2 = flat.call(pts[0])
			var m: Vector2 = flat.call(pts[1])
			var b: Vector2 = flat.call(pts[2])
			var is_diag: bool = street.ends[1]-street.ends[0]==Vector2i(1, 1) or street.ends[1]-street.ends[0]==Vector2i(-1, 1)
			segs.append([a, m, is_diag])
			segs.append([m, b, is_diag])
		for k: Vector2i in [Vector2i(c.x, c.y), Vector2i(c.x+1, c.y), Vector2i(c.x+1, c.y+1), Vector2i(c.x, c.y+1)]:
			var p: Vector2 = flat.call(dir(face, k.x, k.y))
			if not p in corners: corners.append(p)
			var rr := round_at(face, k.x, k.y)
			if rr>0.0 and not rounds.any(func(x: Array) -> bool: return (x[0] as Vector2).distance_to(p)<0.1): rounds.append([p, rr+RING])
		diag = int(node(face, c.x, c.y)[7])
	var role := CityLayout.role(face, i, j)
	var base := {face = face, i = i, j = j, segs = segs, rounds = rounds, role = role, frame = frame}
	if diag==0 or cells.size()>1:
		var seed := Vector2.ZERO
		for p in corners: seed += p
		var block := base.duplicate()
		block.seed = seed/corners.size()
		block.sub = 0
		block.corners = corners
		out.append(block)
	else:
		# Two triangles either side of the diagonal (corners in cell order).
		var c4: Array[Vector2] = []
		for k: Vector2i in [Vector2i(i, j), Vector2i(i+1, j), Vector2i(i+1, j+1), Vector2i(i, j+1)]: c4.append(flat.call(dir(face, k.x, k.y)))
		var tris := [[c4[0], c4[1], c4[2]], [c4[0], c4[2], c4[3]]] if diag==1 else [[c4[0], c4[1], c4[3]], [c4[1], c4[2], c4[3]]]
		for t in 2:
			var tri: Array = tris[t]
			var block := base.duplicate()
			block.seed = ((tri[0] as Vector2)+(tri[1] as Vector2)+(tri[2] as Vector2))/3.0
			block.sub = t
			block.corners = tri
			out.append(block)
	for block: Dictionary in out: block.key = "%d_%d_%d_%d" % [face, i, j, int(block.sub)]
	_blocks[key] = out
	return out

## Distance-like field from a block's streets (m, local): under ROAD is the
## carriageway (or a roundabout's ring), ROAD..ROAD+WALK the sidewalk.
static func field(block: Dictionary, p: Vector2) -> float:
	var best := 1e9
	for s: Array in block.segs:
		var a: Vector2 = s[0]
		var b: Vector2 = s[1]
		var ab := b-a
		var t := clampf((p-a).dot(ab)/maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
		best = minf(best, p.distance_to(a+ab*t))
	for r: Array in block.rounds:
		best = minf(best, p.distance_to(r[0])-float(r[1])+CityLayout.ROAD)
	return best

## The line where field() = `offset` round the block, walked from its seed
## (star-shaped blocks): local points in order.
static func outline(block: Dictionary, offset: float, rays := 56, thin := true) -> PackedVector2Array:
	var seed: Vector2 = block.seed
	var angles: Array[float] = []
	for k in rays: angles.append(TAU*k/rays)
	for c: Vector2 in block.corners:
		var a := fposmod((c-seed).angle(), TAU)
		angles.append(a)
		angles.append(fposmod(a-0.02, TAU))
		angles.append(fposmod(a+0.02, TAU))
	angles.sort()
	var out := PackedVector2Array()
	for a in angles:
		# The field never changes faster than distance: step by how far it still is.
		var d := Vector2.from_angle(a)
		var t := 0.0
		for k in 24:
			var left := field(block, seed+d*t)-offset
			if left<0.03 or t>95.0: break
			t += maxf(left, 0.05)
		var p := seed+d*minf(t, 95.0)
		if not thin or out.is_empty() or out[out.size()-1].distance_to(p)>0.15: out.append(p)
	return out

## Where a cell's corner sits in its frame (local metres).
static func corner_local(face: int, i: int, j: int, cell_frame: Transform3D) -> Vector2:
	var p := cell_frame.affine_inverse()*(dir(face, i, j)*CityLayout.radius())
	return Vector2(p.x, p.z)

## Ground height (m, in a tangent frame) at local x/z: the sphere falls away.
static func drop(local: Vector2) -> float:
	var r := CityLayout.radius()
	return sqrt(maxf(r*r-local.length_squared(), 0.0))-r
