class_name CityCountry
## Vesperis outside its three towns is farmland: patchwork fields (drawn by
## the ground shader) in the blocks between the planet's streets (CityRoads:
## the same streets run through the towns and the fields), with a farmstead
## in some of the blocks. Fixed data, the same on the server and every client.

## Farmsteads: [direction from the planet centre (the block it stands in), a
## second point left from the old dirt roads, unused].
const FARMS := [
	[Vector3(-0.2707, 0.9446, 0.1857), Vector3(-0.2954, 0.9509, 0.0922)],
	[Vector3(-0.0187, 0.9019, -0.4315), Vector3(0.0008, 0.9499, -0.3124)],
	[Vector3(0.4475, 0.8582, -0.2515), Vector3(0.4082, 0.8976, -0.1665)],
	[Vector3(-0.1442, 0.7665, 0.6259), Vector3(-0.2323, 0.7380, 0.6336)],
	[Vector3(-0.6512, 0.6990, 0.2956), Vector3(-0.7340, 0.6230, 0.2704)],
	[Vector3(0.3335, 0.6623, -0.6709), Vector3(0.3911, 0.5949, -0.7022)],
	[Vector3(0.1909, 0.6326, 0.7506), Vector3(0.2502, 0.6946, 0.6745)],
	[Vector3(-0.6716, 0.6073, -0.4244), Vector3(-0.6518, 0.5587, -0.5129)],
	[Vector3(0.7996, 0.5671, -0.1974), Vector3(0.8568, 0.4970, -0.1376)],
	[Vector3(-0.4571, 0.5847, 0.6702), Vector3(-0.3864, 0.6428, 0.6614)],
	[Vector3(-0.1051, 0.5388, -0.8359), Vector3(-0.0172, 0.4997, -0.8660)],
	[Vector3(0.6696, 0.4412, 0.5974), Vector3(0.6080, 0.3981, 0.6869)],
	[Vector3(-0.9019, 0.4269, 0.0652), Vector3(-0.9319, 0.3433, 0.1169)],
	[Vector3(0.5948, 0.4163, -0.6877), Vector3(0.5483, 0.4966, -0.6728)],
	[Vector3(-0.0219, 0.4140, 0.9100), Vector3(0.0652, 0.4827, 0.8733)],
	[Vector3(-0.5829, 0.3553, -0.7307), Vector3(-0.5291, 0.2979, -0.7945)],
	[Vector3(0.9352, 0.3333, 0.1191), Vector3(0.9065, 0.4183, 0.0581)],
	[Vector3(-0.7549, 0.3558, 0.5509), Vector3(-0.6967, 0.4415, 0.5654)],
	[Vector3(0.2387, 0.2198, -0.9459), Vector3(0.3413, 0.1898, -0.9206)],
	[Vector3(0.4744, 0.2780, 0.8353), Vector3(0.5629, 0.3154, 0.7640)],
	[Vector3(-0.9438, 0.1865, -0.2730), Vector3(-0.9581, 0.2282, -0.1730)],
	[Vector3(0.8662, 0.1731, -0.4688), Vector3(0.8766, 0.0756, -0.4753)],
	[Vector3(-0.4111, 0.0842, 0.9077), Vector3(-0.4759, -0.0006, 0.8795)],
	[Vector3(-0.3716, 0.0772, -0.9252), Vector3(-0.4091, 0.1714, -0.8962)],
	[Vector3(0.8963, 0.0269, 0.4425), Vector3(0.8568, -0.0399, 0.5140)],
	[Vector3(-0.9524, 0.0921, 0.2906), Vector3(-0.9442, 0.1963, 0.2645)],
	[Vector3(0.5660, -0.0106, -0.8243), Vector3(0.6335, -0.0670, -0.7709)],
	[Vector3(0.1449, 0.0290, 0.9890), Vector3(0.0907, 0.1231, 0.9882)],
	[Vector3(-0.7881, -0.0812, -0.6101), Vector3(-0.7861, -0.1943, -0.5868)],
	[Vector3(0.9938, -0.0826, -0.0740), Vector3(0.9877, -0.1558, 0.0086)],
	[Vector3(-0.6892, -0.1655, 0.7054), Vector3(-0.6471, -0.0756, 0.7586)],
	[Vector3(-0.0115, -0.1404, -0.9900), Vector3(0.0494, -0.2153, -0.9753)],
	[Vector3(0.6680, -0.1658, 0.7255), Vector3(0.5965, -0.2155, 0.7732)],
	[Vector3(-0.9648, -0.2596, -0.0429), Vector3(-0.9465, -0.2855, -0.1506)],
	[Vector3(0.8107, -0.1901, -0.5538), Vector3(0.8264, -0.0947, -0.5551)],
	[Vector3(-0.1930, -0.2891, 0.9376), Vector3(-0.2635, -0.3570, 0.8962)],
	[Vector3(-0.4686, -0.3325, -0.8184), Vector3(-0.3712, -0.3877, -0.8437)],
	[Vector3(0.8958, -0.3769, 0.2357), Vector3(0.8375, -0.4592, 0.2963)],
	[Vector3(-0.8410, -0.3990, 0.3655), Vector3(-0.8479, -0.4513, 0.2781)],
	[Vector3(0.2611, -0.3905, -0.8828), Vector3(0.1739, -0.3535, -0.9191)],
	[Vector3(0.3963, -0.4183, 0.8173), Vector3(0.3336, -0.4927, 0.8037)],
	[Vector3(-0.8043, -0.4540, -0.3833), Vector3(-0.7412, -0.5308, -0.4110)],
	[Vector3(0.8524, -0.4770, -0.2141), Vector3(0.8303, -0.5400, -0.1380)],
	[Vector3(-0.4523, -0.5354, 0.7133), Vector3(-0.4882, -0.5894, 0.6436)],
	[Vector3(-0.2144, -0.5426, -0.8122), Vector3(-0.3179, -0.4954, -0.8084)],
	[Vector3(0.6871, -0.6033, 0.4049), Vector3(0.7662, -0.5531, 0.3270)],
	[Vector3(-0.7693, -0.6362, 0.0584), Vector3(-0.7862, -0.5990, 0.1520)],
	[Vector3(0.4845, -0.6719, -0.5601), Vector3(0.4055, -0.7138, -0.5711)],
	[Vector3(0.0851, -0.6330, 0.7695), Vector3(0.1784, -0.6019, 0.7784)],
	[Vector3(-0.5045, -0.6875, -0.5224), Vector3(-0.4900, -0.7500, -0.4443)],
	[Vector3(0.6957, -0.7152, 0.0667), Vector3(0.7197, -0.6712, 0.1776)],
	[Vector3(-0.4913, -0.7601, 0.4254), Vector3(-0.4692, -0.7216, 0.5091)],
	[Vector3(0.1489, -0.7932, -0.5904), Vector3(0.2330, -0.7577, -0.6096)],
	[Vector3(0.3654, -0.8202, 0.4401), Vector3(0.4504, -0.7704, 0.4513)],
	[Vector3(-0.4856, -0.8580, -0.1675), Vector3(-0.5148, -0.8183, -0.2558)],
	[Vector3(0.3357, -0.9080, -0.2506), Vector3(0.2746, -0.9486, -0.1571)],
	[Vector3(-0.1021, -0.9179, 0.3835), Vector3(-0.2090, -0.9003, 0.3817)],
	[Vector3(-0.0791, -0.9678, -0.2388), Vector3(-0.0338, -0.9914, -0.1262)],
	[Vector3(0.1418, -0.9893, 0.0350), Vector3(0.0819, -0.9943, -0.0680)],
]
static var _frames := {}
static var _cells: ImageTexture
static var _mask: ImageTexture
static var _mask_image: Image
static var _road_image: Image  # the roads alone, for trees that may stand in a yard
const MASK_SIZE := 1024  # texels a face side in mask_texture()
const MASK_REACH := 0.62  # the face coordinate (over the radius) at its texture's edge

## A farmstead in a field block: not in or next to a town, alone in its block,
## and its whole yard (FARM_HALF either way) clear of the streets.
static func farm_open(k: int) -> bool:
	if _open.has(k): return _open[k]
	var ok := false
	var cell := _farm_cell(k)
	var face := cell.x
	if cell.x>=0:
		ok = true
		for dj in range(-1, 2):
			for di in range(-1, 2):
				if CityLayout.role(face, clampi(cell.y+di, 0, CityLayout.N-1), clampi(cell.z+dj, 0, CityLayout.N-1))!="farm": ok = false
		for other in k:
			if _farm_cell(other)==cell: ok = false
		if ok:
			var block: Dictionary = CityRoads.blocks(face, cell.y, cell.z)[0]
			for c: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
				var at: Vector2 = (block.seed as Vector2)+(c*FARM_HALF).rotated(-_farm_turn(k))
				if CityRoads.field(block, at)<CityLayout.ROAD+CityLayout.WALK+1.0: ok = false
	_open[k] = ok
	return ok

const FARM_HALF := 16.0  # a farmstead's yard reaches this far from its middle
static var _open := {}

## The grid cell a farmstead stands in: (face, i, j), or x = -1 off the grid.
static func _farm_cell(k: int) -> Vector3i:
	var uv := CityLayout.face_uv(FARMS[k][0])
	var n := CityLayout.N
	return Vector3i(int(uv[0]), clampi(int(floor((float(uv[1])+1.0)*0.5*n)), 0, n-1), clampi(int(floor((float(uv[2])+1.0)*0.5*n)), 0, n-1))

static func _farm_turn(k: int) -> float:
	return float(k % 4)*PI*0.5

## Whether a direction lies inside one of the towns.
static func _in_town(dir: Vector3) -> bool:
	var uv := CityLayout.face_uv(dir)
	var i := clampi(int(floor((float(uv[1])+1.0)*0.5*CityLayout.N)), 0, CityLayout.N-1)
	var j := clampi(int(floor((float(uv[2])+1.0)*0.5*CityLayout.N)), 0, CityLayout.N-1)
	return CityLayout.role(int(uv[0]), i, j)!="farm"

## A farmstead's yard frame (planet space, on the ground): in the middle of
## its block, turned a quarter now and then so they don't all look alike.
static func farm_frame(k: int) -> Transform3D:
	if _frames.has(k): return _frames[k]
	var cell := _farm_cell(k)
	var block: Dictionary = CityRoads.blocks(cell.x, cell.y, cell.z)[0]
	var bframe: Transform3D = block.frame
	var seed: Vector2 = block.seed
	var at := (bframe*Vector3(seed.x, 0, seed.y)).normalized()
	var out := CityLayout._tangent(at, bframe.basis*Basis(Vector3.UP, _farm_turn(k))*Vector3.BACK)
	_frames[k] = out
	return out

## Where no crops, hedges or trees grow (farm_flora.gdshader): the roads, the
## farmyards and the city cores, stamped onto each cube face (faces stacked
## top to bottom, the same face choice and axes as the ground shader).
static func mask_texture() -> ImageTexture:
	if _mask: return _mask
	var image := Image.create(MASK_SIZE, MASK_SIZE*6, false, Image.FORMAT_R8)
	# Every street of the planet, sidewalks and all.
	var reach := CityLayout.ROAD+CityLayout.WALK+1.0
	for face in 6:
		for j in CityLayout.N+1:
			for i in CityLayout.N+1:
				for street: Array in _corner_streets(face, i, j):
					for q in street.size()-1:
						var a: Vector3 = street[q]
						var b: Vector3 = street[q+1]
						var steps := maxi(1, ceili(a.angle_to(b)*CityLayout.radius()/4.0))
						for t in steps+1: _stamp(image, a.slerp(b, float(t)/steps), reach)
	_road_image = image.duplicate()
	for k in FARMS.size():
		if not farm_open(k): continue
		_stamp(image, farm_frame(k).origin.normalized(), FARM_HALF+2.0)
	var n := CityLayout.N
	for face in 6:
		for j in n:
			for i in n:
				# The cities and the ring of streets round them.
				if CityLayout.role(face, i, j)!="farm": _stamp(image, (CityLayout.cell(face, i, j).frame as Transform3D).origin.normalized(), 54.0)
	_mask_image = image
	_mask = ImageTexture.create_from_image(image)
	return _mask

## The streets leaving corner (i, j) along u and v: unit-direction polylines.
static func _corner_streets(face: int, i: int, j: int) -> Array:
	var out: Array = []
	var node := CityRoads.node(face, i, j)
	if node[3]: out.append([node[0], node[2], CityRoads.dir(face, i+1, j)])
	if node[5]: out.append([node[0], node[4], CityRoads.dir(face, i, j+1)])
	if int(node[7])==1: out.append([node[0], node[6], CityRoads.dir(face, i+1, j+1)])
	elif int(node[7])==2: out.append([CityRoads.dir(face, i+1, j), node[6], CityRoads.dir(face, i, j+1)])
	return out

static func _stamp(image: Image, dir: Vector3, radius: float) -> void:
	var texel := 2.0*MASK_REACH*CityLayout.radius()/MASK_SIZE
	var reach := ceili(radius/texel)
	for face in 6:
		var n: Vector3 = CityLayout.FACES[face]
		if dir.dot(n)<0.45: continue
		var ax := Vector3(n.y, n.z, n.x)
		var bx := n.cross(ax)
		var uv := Vector2(dir.dot(ax), dir.dot(bx))/MASK_REACH*0.5+Vector2(0.5, 0.5)
		if uv.x<-0.05 or uv.y<-0.05 or uv.x>1.05 or uv.y>1.05: continue
		var at := Vector2i(uv*MASK_SIZE)
		var rect := Rect2i(at-Vector2i(reach, reach), Vector2i(reach*2+1, reach*2+1)).intersection(Rect2i(0, 0, MASK_SIZE, MASK_SIZE))
		if rect.size.x<=0 or rect.size.y<=0: continue
		image.fill_rect(Rect2i(rect.position+Vector2i(0, face*MASK_SIZE), rect.size), Color(1, 0, 0))

# --- The fields (mirrors shaders/farm_fields.gdshaderinc exactly) ---------------------------

const FIELD_SIZE := 40.0
const M32 := 0xFFFFFFFF

static func hash3i(c: Vector3i, salt: int) -> Vector3:
	var x := (c.x+salt*7919) & M32
	var y := (c.y+salt*104729) & M32
	var z := (c.z+salt*1299709) & M32
	x = (x*1664525+1013904223) & M32
	y = (y*1664525+1013904223) & M32
	z = (z*1664525+1013904223) & M32
	x = (x+y*z) & M32
	y = (y+z*x) & M32
	z = (z+x*y) & M32
	x ^= x >> 16
	y ^= y >> 16
	z ^= z >> 16
	x = (x+y*z) & M32
	y = (y+z*x) & M32
	z = (z+x*y) & M32
	return Vector3(x, y, z)/4294967295.0

## The field at p (planet space, on the ground): [kind (0 wheat, 1 green crop,
## 2 ploughed, 3 meadow), metres to its border, the border is a hedge, shade,
## row direction hash].
static func field(p: Vector3) -> Array:
	var w := p+Vector3(sin(p.y*0.031+p.z*0.017), sin(p.z*0.027+p.x*0.021), sin(p.x*0.029+p.y*0.019))*7.0 \
		+Vector3(sin(p.z*0.11), sin(p.x*0.13), sin(p.y*0.12))*1.6
	var g := Vector3i(floori(w.x/FIELD_SIZE), floori(w.y/FIELD_SIZE), floori(w.z/FIELD_SIZE))
	var d1 := 1e9
	var d2 := 1e9
	var c1 := g
	var c2 := g
	for x in range(-1, 2):
		for y in range(-1, 2):
			for z in range(-1, 2):
				var cell := g+Vector3i(x, y, z)
				var seed := (Vector3(cell)+Vector3.ONE*0.1+0.8*hash3i(cell, 0))*FIELD_SIZE
				var d := w.distance_to(seed)
				if d<d1:
					d2 = d1
					c2 = c1
					d1 = d
					c1 = cell
				elif d<d2:
					d2 = d
					c2 = cell
	var id := hash3i(c1, 1)
	var id2 := hash3i(c2, 1)
	var farm_id := hash3i(Vector3i(floori(w.x/130.0), floori(w.y/130.0), floori(w.z/130.0)), 2)
	if hash3i(c1, 3).x<0.55: id.x = farm_id.x
	if hash3i(c2, 3).x<0.55: id2.x = farm_id.x
	var kind1 := _kind(id.x)
	var kind2 := _kind(id2.x)
	var hedged := kind1!=kind2 or hash3i(c1+c2, 4).y<0.35
	return [kind1, (d2-d1)*0.5, hedged, id.z, id.y]

static func _kind(x: float) -> int:
	return 0 if x<0.42 else 1 if x<0.64 else 2 if x<0.8 else 3

## Across a field's sowing rows, 0..1 (at = the face's ground coordinates).
static func row(at: Vector2, row_hash: float) -> float:
	var a := row_hash*3.14159
	return fposmod(at.dot(Vector2(-sin(a), cos(a)))/0.9, 1.0)

## Whether nothing should grow within `radius` m of `dir` (roads, yards, cities).
static func masked(dir: Vector3, radius := 0.0, roads_only := false) -> bool:
	mask_texture()
	var source := _road_image if roads_only else _mask_image
	var n: Vector3 = CityLayout.FACES[0]
	var face := 0
	for f in 6:
		if dir.dot(CityLayout.FACES[f])>dir.dot(n):
			n = CityLayout.FACES[f]
			face = f
	var ax := Vector3(n.y, n.z, n.x)
	var bx := n.cross(ax)
	var uv := Vector2(dir.dot(ax), dir.dot(bx))/MASK_REACH*0.5+Vector2(0.5, 0.5)
	var texel := 2.0*MASK_REACH*CityLayout.radius()/MASK_SIZE
	var reach := ceili(radius/texel)
	var at := Vector2i(uv*MASK_SIZE)
	for dy in range(-reach, reach+1, maxi(1, reach)):
		for dx in range(-reach, reach+1, maxi(1, reach)):
			var x := clampi(at.x+dx, 0, MASK_SIZE-1)
			var y := clampi(at.y+dy, 0, MASK_SIZE-1)
			if source.get_pixel(x, face*MASK_SIZE+y).r>0.4: return true
	return false

## One texel per city cell (CityLayout.N wide, six faces tall): 1 where the
## cell is farmland, 0 in a city core. The ground shader paints fields there.
static func cell_texture() -> ImageTexture:
	if _cells: return _cells
	var n := CityLayout.N
	var image := Image.create(n, 6*n, false, Image.FORMAT_R8)
	for face in 6:
		for j in n:
			for i in n:
				image.set_pixel(i, face*n+j, Color(1, 0, 0) if CityLayout.role(face, i, j)=="farm" else Color(0, 0, 0))
	_cells = ImageTexture.create_from_image(image)
	return _cells
