class_name CityPlanet
extends Node3D
## Vesperis on the client (child of its SpacePlanet, so in planet space): the
## skyline over the whole sphere (instanced towers, lit windows), collision for
## the blocks around the player, the three districts built in full when you come
## near (CityDistrict) and the life in them (CityLife: townsfolk and traffic).
const FACADES := ["4a3550", "2c4a52", "6a3a44", "b8a088", "2a2f4a", "7a4058", "3e3a5a", "5a4a3a", "8a6a7a", "34404e"]
const NEON := ["ff6eb4", "6af0e0", "ffb86a", "9a8aff", "8dff9a", "ff8a5a"]
const DISTRICT_RANGE := 1300.0
const COLLIDE_RANGE := 110.0
var world: SpaceWorld
var districts := {}  # id -> CityDistrict once built
var life: CityLife
var _solids := {}  # Vector3i cell -> Array of [Transform3D, Vector3 size]
var _bodies := {}  # Vector3i cell -> StaticBody3D
var _timer := 0.0
static var _tower_material: ShaderMaterial
static var _meshes := {}

## Instanced parts: kind -> [transforms, colors, customs].
class Batch extends RefCounted:
	var parts := {}
	func add(kind: String, xform: Transform3D, color: Color, custom: Color) -> void:
		if not parts.has(kind): parts[kind] = [[], [], []]
		parts[kind][0].append(xform)
		parts[kind][1].append(color)
		parts[kind][2].append(custom)
	func flush(parent: Node3D, label: String, far: float) -> void:
		for kind: String in parts:
			var data: Array = parts[kind]
			var multi := MultiMesh.new()
			multi.transform_format = MultiMesh.TRANSFORM_3D
			multi.use_colors = true
			multi.use_custom_data = true
			multi.mesh = CityPlanet.mesh(kind)
			multi.instance_count = data[0].size()
			for i in data[0].size():
				multi.set_instance_transform(i, data[0][i])
				multi.set_instance_color(i, data[1][i])
				multi.set_instance_custom_data(i, data[2][i])
			var node := MultiMeshInstance3D.new()
			node.name = "%s_%s" % [label, kind]
			node.multimesh = multi
			node.material_override = CityPlanet.tower_material()
			node.visibility_range_end = far
			node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if far<2000.0 else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			parent.add_child(node)
		parts.clear()

static func tower_material() -> ShaderMaterial:
	if _tower_material==null:
		_tower_material = ShaderMaterial.new()
		_tower_material.shader = preload("res://shaders/city_tower.gdshader")
	return _tower_material

static func mesh(kind: String) -> Mesh:
	if _meshes.has(kind): return _meshes[kind]
	var m: Mesh
	match kind:
		"box":
			var box := BoxMesh.new()
			box.size = Vector3.ONE
			m = box
		"cyl":
			var cyl := CylinderMesh.new()
			cyl.top_radius = 0.5
			cyl.bottom_radius = 0.5
			cyl.height = 1.0
			cyl.radial_segments = 16
			cyl.rings = 1
			m = cyl
		"dome":
			var dome := SphereMesh.new()
			dome.radius = 0.5
			dome.height = 1.0
			dome.radial_segments = 16
			dome.rings = 8
			dome.is_hemisphere = true
			m = dome
		"cone":
			var cone := CylinderMesh.new()
			cone.top_radius = 0.0
			cone.bottom_radius = 0.5
			cone.height = 1.0
			cone.radial_segments = 8
			m = cone
	_meshes[kind] = m
	return m

func build() -> void:
	life = CityLife.new()
	life.city = self
	add_child(life)
	_skyline()

func _process(delta: float) -> void:
	var local: Node3D = world.local_player if is_instance_valid(world) else null
	var camera := get_viewport().get_camera_3d()
	var eye := camera.global_position if camera else Vector3.INF
	# Districts come in when the camera is near (from orbit they are skyline).
	for d: Dictionary in CityLayout.DISTRICTS:
		var at := to_global(CityLayout.district_frame(d).origin)
		if not districts.has(d.id) and eye.distance_to(at)<DISTRICT_RANGE:
			var district := CityDistrict.new()
			district.name = "District_"+str(d.id)
			district.city = self
			district.data = d
			add_child(district)
			district.build()
			districts[d.id] = district
			life.add_district(d)
	_timer -= delta
	if _timer<=0.0 and is_instance_valid(local):
		_timer = 0.4
		_update_collision(to_local(local.global_position))

# --- Skyline ------------------------------------------------------------------------------

## Every block of towers on the planet, one batch per face. Districts add their
## own detailed buildings; their outer ring is skyline too (taller, more neon).
func _skyline() -> void:
	for face in 6:
		var batch := Batch.new()
		for j in CityLayout.N:
			for i in CityLayout.N:
				var r := CityLayout.role(face, i, j)
				if r in ["skyline", "district"]: _block(batch, CityLayout.cell(face, i, j), r=="district")
		var holder := Node3D.new()
		holder.name = "Skyline_%d" % face
		add_child(holder)
		batch.flush(holder, "face%d" % face, 6000.0)

## One block: a tower or a cluster of them on a podium, with crowns and neon.
func _block(batch: Batch, c: Dictionary, near_district: bool) -> void:
	var frame: Transform3D = c.frame
	var seed: float = c.seed
	var half: Vector2 = c.half
	var lot := Vector2(half.x, half.y)-Vector2.ONE*(CityLayout.ROAD+CityLayout.WALK+0.5)
	var key := Vector3i(c.face, c.i, c.j)
	var solids: Array = []
	var rnd := func(salt: int) -> float: return CityLayout.rnd(seed, salt)
	var facade := Color(FACADES[int(rnd.call(1)*FACADES.size()) % FACADES.size()])
	var neon := Color(NEON[int(rnd.call(2)*NEON.size()) % NEON.size()])
	var tall_k := 1.7 if near_district else 1.0
	var kind := float(rnd.call(3))
	var towers: Array = []  # [local centre x/z, size x/z, height]
	if kind<0.4:
		var s := Vector2(lot.x*2.0*lerpf(0.7, 0.95, rnd.call(4)), lot.y*2.0*lerpf(0.7, 0.95, rnd.call(5)))
		towers.append([Vector2.ZERO, s, lerpf(30.0, 130.0, pow(rnd.call(6), 1.6))*tall_k])
	elif kind<0.75:
		for qx in [-1, 1]:
			for qz in [-1, 1]:
				var salt: int = 10+(qx+1)*2+(qz+1)
				if rnd.call(salt)<0.15: continue
				var s := lot*lerpf(0.65, 0.9, rnd.call(salt+20))
				towers.append([Vector2(qx, qz)*lot*0.5, s, lerpf(18.0, 80.0, pow(rnd.call(salt+40), 1.4))*tall_k])
	elif kind<0.9:
		# A podium with a slender spire tower on it.
		_part(batch, frame, Vector3(0, 0, 0), Vector3(lot.x*1.9, 10.0, lot.y*1.9), facade.darkened(0.15), seed, 0.5, solids)
		var s := lot*lerpf(0.5, 0.7, rnd.call(4))
		towers.append([Vector2.ZERO, s, lerpf(70.0, 190.0, rnd.call(6))*tall_k, 10.0])
	else:
		# A garden block: low terraces and glowing trees.
		_part(batch, frame, Vector3.ZERO, Vector3(lot.x*1.9, 3.0, lot.y*1.9), Color("3a4a3a"), seed, 0.0, solids)
		for k in 5:
			var at := Vector3((rnd.call(50+k)-0.5)*lot.x*1.5, 3.0, (rnd.call(60+k)-0.5)*lot.y*1.5)
			batch.add("box", frame*Transform3D(Basis.from_scale(Vector3(0.6, 4.0, 0.6)), at+Vector3.UP*2.0), Color("5a3a2a"), Color(seed, 0, 0, 0))
			batch.add("dome", frame*Transform3D(Basis.from_scale(Vector3.ONE*5.0), at+Vector3.UP*3.6), Color(NEON[k % NEON.size()]).darkened(0.35), Color(seed, 0, 1, 0))
	for t: Array in towers:
		var base := float(t[3]) if t.size()>3 else 0.0
		_tower(batch, frame, t[0], t[1], float(t[2]), base, facade, neon, seed+float(towers.find(t))*0.13, solids)
	_solids[key] = solids

## A tower with setbacks and a crown: dome, spire, neon ring or antenna.
func _tower(batch: Batch, frame: Transform3D, at: Vector2, size: Vector2, height: float, base: float, facade: Color, neon: Color,
		seed: float, solids: Array) -> void:
	var rnd := func(salt: int) -> float: return CityLayout.rnd(seed, salt)
	var round: bool = rnd.call(70)<0.22
	var levels := 1+int(rnd.call(71)*3.0)
	var y := base
	var s := size
	var windows := lerpf(0.35, 0.8, rnd.call(72))
	for level in levels:
		var h := height*(0.62 if level==0 and levels>1 else 0.38/maxf(1, levels-1)) if levels>1 else height
		var center := Vector3(at.x, y, at.y)
		if round:
			batch.add("cyl", frame*Transform3D(Basis.from_scale(Vector3(minf(s.x, s.y), h, minf(s.x, s.y))), center+Vector3.UP*(h*0.5-0.6)),
				facade.lightened(level*0.06), Color(seed, windows, 0, 2.0))
		else:
			_part(batch, frame, center, Vector3(s.x, h, s.y), facade.lightened(level*0.06), seed+level, windows, solids, 1.0 if rnd.call(73+level)<0.5 else 0.0)
		# A neon band at each setback.
		for edge: float in [-1.0, 1.0]:
			batch.add("box", frame*Transform3D(Basis.from_scale(Vector3(s.x+0.3, 0.24, 0.24)), center+Vector3(0, h-0.6, edge*s.y*0.5)), neon, Color(seed, 0, 1, 0))
			batch.add("box", frame*Transform3D(Basis.from_scale(Vector3(0.24, 0.24, s.y+0.3)), center+Vector3(edge*s.x*0.5, h-0.6, 0)), neon, Color(seed, 0, 1, 0))
		y += h
		s *= lerpf(0.6, 0.8, rnd.call(74+level))
	var top := Vector3(at.x, y-0.6, at.y)
	var crown := float(rnd.call(80))
	if crown<0.3:
		batch.add("dome", frame*Transform3D(Basis.from_scale(Vector3(minf(s.x, s.y), minf(s.x, s.y)*0.9, minf(s.x, s.y))), top), facade.lightened(0.25), Color(seed, 0.2, 0, 0))
		batch.add("box", frame*Transform3D(Basis.from_scale(Vector3(0.4, 6.0, 0.4)), top+Vector3.UP*(minf(s.x, s.y)*0.45+3.0)), Color("d9ac60"), Color(seed, 0, 0, 0))
		batch.add("dome", frame*Transform3D(Basis.from_scale(Vector3.ONE*1.4), top+Vector3.UP*(minf(s.x, s.y)*0.45+6.0)), neon, Color(seed, 0, 1, 0))
	elif crown<0.55:
		batch.add("cone", frame*Transform3D(Basis.from_scale(Vector3(minf(s.x, s.y)*0.7, height*0.22, minf(s.x, s.y)*0.7)), top+Vector3.UP*height*0.11), facade.lightened(0.15), Color(seed, 0, 0, 0))
		batch.add("box", frame*Transform3D(Basis.from_scale(Vector3.ONE*0.9), top+Vector3.UP*height*0.22), neon, Color(seed, 0, 1, 0))
	elif crown<0.75:
		for k in 3:
			batch.add("cyl", frame*Transform3D(Basis.from_scale(Vector3(minf(s.x, s.y)*(1.1-k*0.25), 0.4, minf(s.x, s.y)*(1.1-k*0.25))), top+Vector3.UP*(1.5+k*2.4)),
				neon if k % 2==0 else Color(NEON[(NEON.find(neon.to_html(false))+2) % NEON.size()]), Color(seed, 0, 1, 0))
	else:
		batch.add("box", frame*Transform3D(Basis.from_scale(Vector3(s.x*0.4, 3.0, s.y*0.4)), top+Vector3.UP*1.5), Color("4a4a5a"), Color(seed, 0, 0, 0))
		batch.add("box", frame*Transform3D(Basis.from_scale(Vector3(0.3, 14.0, 0.3)), top+Vector3.UP*10.0), Color("9a9aa8"), Color(seed, 0, 0, 0))
		batch.add("box", frame*Transform3D(Basis.from_scale(Vector3.ONE*0.6), top+Vector3.UP*17.0), Color("ff4a5a"), Color(seed, 0, 1, 0))

func _part(batch: Batch, frame: Transform3D, center: Vector3, size: Vector3, color: Color, seed: float, windows: float, solids: Array,
		trims := 0.0) -> void:
	var xform := Transform3D(Basis.from_scale(size), center+Vector3.UP*(size.y*0.5-0.6))
	batch.add("box", frame*xform, color, Color(seed, windows, 0, trims))
	solids.append([frame*Transform3D(Basis.IDENTITY, xform.origin), size])

# --- Collision ------------------------------------------------------------------------------

## Static boxes for the blocks within reach of the player (planet-space `at`).
func _update_collision(at: Vector3) -> void:
	if at.length()>CityLayout.radius()+400.0:
		for key: Vector3i in _bodies.keys(): _drop_body(key)
		return
	var uv := CityLayout.face_uv(at.normalized())
	var face := int(uv[0])
	var ci := int(floor((float(uv[1])+1.0)*0.5*CityLayout.N))
	var cj := int(floor((float(uv[2])+1.0)*0.5*CityLayout.N))
	var want := {}
	for dj in range(-2, 3):
		for di in range(-2, 3):
			var i := ci+di
			var j := cj+dj
			if i<0 or j<0 or i>=CityLayout.N or j>=CityLayout.N: continue
			var key := Vector3i(face, i, j)
			if not _solids.has(key): continue
			var c := CityLayout.cell(face, i, j)
			if (c.frame as Transform3D).origin.distance_to(at)>COLLIDE_RANGE+40.0: continue
			want[key] = true
	for key: Vector3i in _bodies.keys():
		if not want.has(key): _drop_body(key)
	for key: Vector3i in want:
		if _bodies.has(key): continue
		var body := StaticBody3D.new()
		body.collision_layer = Player.OBSTACLE_LAYER
		body.collision_mask = 0
		for solid: Array in _solids[key]:
			var shape := CollisionShape3D.new()
			var box := BoxShape3D.new()
			box.size = solid[1]
			shape.shape = box
			shape.transform = solid[0]
			body.add_child(shape)
		add_child(body)
		_bodies[key] = body

func _drop_body(key: Vector3i) -> void:
	var body: Node = _bodies[key]
	_bodies.erase(key)
	if is_instance_valid(body): body.queue_free()
