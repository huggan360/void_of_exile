class_name CityCountryArt
## Vesperis's farmland on the client (CityCountry's data): each farmstead's red
## barn, silos, farmhouse, gravel yard, fenced pasture (the cows are CityLife's),
## sometimes a pond; trees along the country roads; and the roads themselves
## as dirt ribbons laid on the ground.
const RED := Color("a8322c")
const TRIM := Color("efe6d6")
const ROOF := Color("4a3a3a")
const METAL := Color("8f9ba6")
const WOOD := Color("7a5236")
const HAY := Color("d8b45a")
const GRAVEL := Color("9a8a70")
## Where the pasture fence stands in a yard frame (x from, x to, z from, z to).
const PASTURE := [-14.0, 14.0, 44.0, 68.0]

static var _road_material: ShaderMaterial

## Every farmstead and roadside tree into `batch`; collision per city cell into `solids`.
static func build(batch: CityPlanet.Batch, solids: Dictionary) -> void:
	for k in CityCountry.FARMS.size():
		if not CityCountry.farm_open(k): continue
		var frame := CityCountry.farm_frame(k)
		var list: Array = []
		var art := CityArt.new(batch, frame, list)
		art.seed = float(k)*0.137+0.05
		_farm(art, k)
		_keep(solids, frame.origin, list)
	var n := 0
	for curve: Array in CityCountry.curves():
		for i in range(6, curve.size()-6, 11):
			n += 1
			if CityLayout.rnd(float(n)*0.071, 3)>0.4 or _near_city(curve[i], 0.22): continue
			var dir: Vector3 = curve[i]
			var frame := CityLayout._tangent(dir, (curve[i+1] as Vector3)-dir)
			var list: Array = []
			var art := CityArt.new(batch, frame, list)
			var side := -1.0 if CityLayout.rnd(float(n)*0.071, 4)<0.5 else 1.0
			var spot := frame*Vector3(side*(CityCountry.ROAD_HALF+3.5), 0, 0)
			if CityCountry.masked(spot.normalized(), 1.5): continue  # another road or a yard
			art.tree(Vector2(side*(CityCountry.ROAD_HALF+3.5), 0), lerpf(2.6, 4.0, CityLayout.rnd(float(n)*0.071, 5)), float(n)*0.071)
			_keep(solids, frame.origin, list)

static func _near_city(dir: Vector3, angle: float) -> bool:
	for d: Dictionary in CityLayout.DISTRICTS:
		if dir.angle_to(CityLayout.district_frame(d).origin.normalized())<angle: return true
	return false

## Collision goes with the city cell it stands in (CityPlanet builds it near the player).
static func _keep(solids: Dictionary, at: Vector3, list: Array) -> void:
	if list.is_empty(): return
	var uv := CityLayout.face_uv(at.normalized())
	var n := CityLayout.N
	var key := Vector3i(int(uv[0]), clampi(int(floor((float(uv[1])+1.0)*0.5*n)), 0, n-1), clampi(int(floor((float(uv[2])+1.0)*0.5*n)), 0, n-1))
	if solids.has(key): (solids[key] as Array).append_array(list)
	else: solids[key] = list

static func _ground(x: float, z: float) -> float:
	return CityArt.ground(Vector2(x, z))

## One farmstead in its yard frame (+Z away from the roads).
static func _farm(art: CityArt, k: int) -> void:
	# A gravel yard where the roads come in.
	art.part("cyl", Vector3(0, _ground(0, 20)-0.12, 20), Basis.IDENTITY, Vector3(34, 0.3, 30), GRAVEL, CityArt.M_STONE)
	_barn(art, Vector2(9, 28), -0.2+art.r()*0.4)
	_silo(art, Vector2(22, 18), lerpf(11.0, 15.0, art.r()))
	if art.r()<0.6: _silo(art, Vector2(24, 24), lerpf(8.0, 12.0, art.r()))
	art._cottage(Vector3(-11, _ground(-11, 20), 20), 4.2)
	_pasture(art)
	for i in 3: _bale(art, Vector2(-4+i*2.2, 34+art.r()), art.r()*TAU)
	if k % 3==0: art.lake_pool(Vector2(-27, 32), 6.0)
	for spot: Vector2 in [Vector2(-20, 8), Vector2(30, 36), Vector2(-24, 52), Vector2(24, 60)]:
		if CityCountry.masked((art.frame*Vector3(spot.x, 0, spot.y)).normalized(), 3.0, true): continue  # a road runs there
		art.tree(spot, lerpf(2.8, 4.2, art.r()), art.seed+spot.x*0.01)

## A red barn: plank walls with white corners, a gable roof, the big X-braced door.
static func _barn(art: CityArt, at: Vector2, yaw: float) -> void:
	var b := Basis(Vector3.UP, yaw)
	var base := Vector3(at.x, _ground(at.x, at.y)-0.1, at.y)
	var w := 11.0
	var d := 15.0
	var h := 6.0
	art.part("box", base+b*Vector3(0, h*0.5, 0), b, Vector3(w, h, d), RED, CityArt.M_PLANK)
	art.solid(base+Vector3.UP*h*0.5, Vector3(w, h, d), "box")
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			art.part("box", base+b*Vector3(sx*(w*0.5+0.02), h*0.5, sz*(d*0.5+0.02)), b, Vector3(0.4, h+0.05, 0.4), TRIM, CityArt.M_PLANK)
	# Gable ends stepped up under the roof, then the two roof planes.
	for step in 8:
		var width := w*(1.0-float(step)/8.0)
		for sz: float in [-1.0, 1.0]:
			art.part("box", base+b*Vector3(0, h+0.25+step*0.5, sz*(d*0.5-0.15)), b, Vector3(width, 0.5, 0.3), RED, CityArt.M_PLANK)
	var slope := 0.6
	for side: float in [-1.0, 1.0]:
		art.part("box", base+b*Vector3(side*w*0.26, h+w*0.25*tan(slope)+0.2, 0), b*Basis(Vector3.FORWARD, side*slope), Vector3(w*0.6, 0.35, d+0.8), ROOF, CityArt.M_SHINGLE)
	# The big door and hayloft on the front (-Z), framed in white.
	var front := -d*0.5-0.08
	art.part("box", base+b*Vector3(0, 2.3, front), b, Vector3(4.4, 4.6, 0.1), Color("5a2420"), CityArt.M_PLANK)
	for x: float in [-2.25, 2.25]: art.part("box", base+b*Vector3(x, 2.35, front-0.04), b, Vector3(0.3, 4.7, 0.12), TRIM, CityArt.M_PLANK)
	art.part("box", base+b*Vector3(0, 4.7, front-0.04), b, Vector3(4.8, 0.3, 0.12), TRIM, CityArt.M_PLANK)
	for s: float in [-1.0, 1.0]:
		art.part("box", base+b*Vector3(0, 2.3, front-0.08), b*Basis(Vector3.FORWARD, s*0.81), Vector3(0.24, 5.9, 0.06), TRIM, CityArt.M_PLANK)
	art.part("box", base+b*Vector3(0, h+1.4, front-0.02), b, Vector3(1.8, 1.8, 0.1), TRIM, CityArt.M_PLANK)
	art.part("box", base+b*Vector3(0, h+1.4, front-0.06), b, Vector3(1.3, 1.3, 0.08), Color("3a1a18"), CityArt.M_PLANK)

## A tall metal silo with a domed cap and bands.
static func _silo(art: CityArt, at: Vector2, tall: float) -> void:
	var base := Vector3(at.x, _ground(at.x, at.y)-0.1, at.y)
	art.part("cyl", base+Vector3.UP*tall*0.5, Basis.IDENTITY, Vector3(4.2, tall, 4.2), METAL, CityArt.M_STONE)
	art.part("dome", base+Vector3.UP*tall, Basis.IDENTITY, Vector3(4.3, 2.0, 4.3), Color("6f7c88"), CityArt.M_STONE)
	art.solid(base+Vector3.UP*tall*0.5, Vector3(4.2, tall, 4.2))
	for k in int(tall/3.0):
		art.part("torus", base+Vector3.UP*(1.5+k*3.0), Basis.IDENTITY, Vector3(4.5, 0.4, 4.5), Color("5f6a74"), CityArt.M_STONE, 0.0, true, true)

## A round hay bale lying on its side.
static func _bale(art: CityArt, at: Vector2, yaw: float) -> void:
	var base := Vector3(at.x, _ground(at.x, at.y)+0.75, at.y)
	art.part("cyl", base, Basis(Vector3.UP, yaw)*Basis(Vector3.RIGHT, PI*0.5), Vector3(1.6, 1.4, 1.6), HAY, CityArt.M_LEAVES)

## The cows' pasture: posts and two rails round it, a trough inside.
static func _pasture(art: CityArt) -> void:
	var x0: float = PASTURE[0]
	var x1: float = PASTURE[1]
	var z0: float = PASTURE[2]
	var z1: float = PASTURE[3]
	var corners: Array[Vector2] = [Vector2(x0, z0), Vector2(x1, z0), Vector2(x1, z1), Vector2(x0, z1)]
	# Grazed grass inside the fence, laid in strips so it follows the curve of the ground.
	for s in 6:
		var z := lerpf(z0, z1, (s+0.5)/6.0)
		art.part("box", Vector3((x0+x1)*0.5, _ground(0, z)-0.1, z), Basis.IDENTITY, Vector3(x1-x0, 0.26, (z1-z0)/6.0+0.02), Color("5f8f45").lightened(float(s % 2)*0.03), CityArt.M_GRASS)
	for i in 4:
		var a := corners[i]
		var b := corners[(i+1) % 4]
		var count := ceili(a.distance_to(b)/3.0)
		for s in count:
			var p := a.lerp(b, float(s)/count)
			var q := a.lerp(b, float(s+1)/count)
			var y := _ground(p.x, p.y)
			art.part("box", Vector3(p.x, y+0.6, p.y), Basis.IDENTITY, Vector3(0.22, 1.3, 0.22), WOOD, CityArt.M_PLANK)
			var mid := (p+q)*0.5
			var along := Basis(Vector3.UP, atan2(q.x-p.x, q.y-p.y))
			for lift: float in [0.5, 1.05]:
				art.part("box", Vector3(mid.x, _ground(mid.x, mid.y)+lift, mid.y), along, Vector3(0.1, 0.12, p.distance_to(q)), WOOD.lightened(0.08), CityArt.M_PLANK, 0.0, true, true)
		art.solid(Vector3((a.x+b.x)*0.5, _ground((a.x+b.x)*0.5, (a.y+b.y)*0.5)+0.6, (a.y+b.y)*0.5), Vector3(absf(b.x-a.x)+0.2, 1.3, absf(b.y-a.y)+0.2), "box")
	var trough := Vector3(x1-3.0, _ground(x1-3.0, z0+5.0)+0.35, z0+5.0)
	art.part("box", trough, Basis.IDENTITY, Vector3(0.9, 0.6, 2.6), WOOD, CityArt.M_PLANK)
	art.part("box", trough+Vector3.UP*0.28, Basis.IDENTITY, Vector3(0.7, 0.06, 2.4), Color("2a6a8a"), CityArt.M_WATER)

## A cow's spot in its farm's pasture at server time `t` (planet space pose):
## each of five cows strolls a slow loop of its own.
static func cow_pose(farm: int, cow: int, t: float) -> Transform3D:
	var frame := CityCountry.farm_frame(farm)
	var seed := float(farm*5+cow)*0.173
	var cx := lerpf(PASTURE[0]+4.0, PASTURE[1]-4.0, CityLayout.rnd(seed, 1))
	var cz := lerpf(PASTURE[2]+4.0, PASTURE[3]-4.0, CityLayout.rnd(seed, 2))
	var speed := 0.025+CityLayout.rnd(seed, 3)*0.02
	var a := t*speed+CityLayout.rnd(seed, 4)*TAU
	var at := Vector2(clampf(cx+sin(a)*5.0, PASTURE[0]+1.5, PASTURE[1]-1.5), clampf(cz+cos(a*0.7)*4.0, PASTURE[2]+1.5, PASTURE[3]-1.5))
	var heading := Vector2(cos(a)*5.0, -sin(a*0.7)*2.8).normalized()
	var local := Vector3(at.x, _ground(at.x, at.y), at.y)
	var basis := Basis.looking_at(Vector3(heading.x, 0, heading.y), Vector3.UP)
	return frame*Transform3D(basis, local)

## The country roads as dirt ribbons a few centimetres over the fields.
static func road_meshes(parent: Node3D) -> void:
	var r := CityLayout.radius()
	for curve: Array in CityCountry.curves():
		var verts := PackedVector3Array()
		var normals := PackedVector3Array()
		var uvs := PackedVector2Array()
		var along := 0.0
		for i in curve.size():
			var dir: Vector3 = curve[i]
			var ahead: Vector3 = (curve[mini(i+1, curve.size()-1)] as Vector3)-(curve[maxi(i-1, 0)] as Vector3)
			var side := dir.cross(ahead).normalized()
			if i>0: along += (dir-(curve[i-1] as Vector3)).length()*r
			for s: float in [-1.0, 1.0]:
				verts.append(dir*(r+0.05)+side*s*CityCountry.ROAD_HALF)
				normals.append(dir)
				uvs.append(Vector2(0.5+s*0.5, along))
		var indices := PackedInt32Array()
		for i in curve.size()-1:
			var a := i*2
			indices.append_array([a, a+1, a+2, a+1, a+3, a+2])
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = verts
		arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_TEX_UV] = uvs
		arrays[Mesh.ARRAY_INDEX] = indices
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var node := MeshInstance3D.new()
		node.mesh = mesh
		node.material_override = road_material()
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.visibility_range_end = 2600.0
		parent.add_child(node)

static func road_material() -> ShaderMaterial:
	if _road_material == null:
		_road_material = ShaderMaterial.new()
		_road_material.shader = preload("res://shaders/country_road.gdshader")
	return _road_material
