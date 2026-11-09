class_name CityPlanet
extends Node3D
## Vesperis on the client (child of its SpacePlanet, so in planet space): the
## fairytale city over the whole sphere (CityArt: tree houses, crooked towers,
## mushroom houses, parks and lakes on every block the streets leave), built a
## few milliseconds a frame nearest first, in chunks so far ones are culled; the
## raised sidewalks and collision of the blocks around the player; the three
## districts built in full when you come near (CityDistrict) and the life in
## them (CityLife: townsfolk and traffic).
const FACADES := ["4a3550", "2c4a52", "6a3a44", "b8a088", "2a2f4a", "7a4058", "3e3a5a", "5a4a3a", "8a6a7a", "34404e"]
const NEON := ["ff6eb4", "6af0e0", "ffb86a", "9a8aff", "8dff9a", "ff8a5a"]
const DISTRICT_RANGE := 1300.0
const COLLIDE_RANGE := 110.0
const CHUNK := 14  # cells a side per skyline chunk (2 x 2 a face: few draw calls)
const BUDGET_USEC := 6000
const DETAIL_RANGE := 520.0
var world: SpaceWorld
var districts := {}  # id -> CityDistrict once built
var life: CityLife
var _solids := {}  # Vector3i cell -> Array of [Transform3D, Vector3 size, kind]
var _bodies := {}  # Vector3i cell -> Node3D (collision and raised sidewalks)
var _timer := 0.0
var _chunks: Array = []  # [face, ci, cj] still to build
var _building := false
var _done := {}  # Vector3i(face, chunk i, chunk j) -> true once built
static var _tower_material: ShaderMaterial
static var _meshes := {}

## Instanced parts: kind -> [transforms, colors, customs]; "d:" kinds are fine
## detail, drawn only up close.
class Batch extends RefCounted:
	var parts := {}
	func add(kind: String, xform: Transform3D, color: Color, custom: Color, detail := false) -> void:
		var key := ("d:" if detail else "")+kind
		if not parts.has(key): parts[key] = [[], [], []]
		parts[key][0].append(xform)
		parts[key][1].append(color)
		parts[key][2].append(custom)
	func flush(parent: Node3D, label: String, far: float, detail_far := CityPlanet.DETAIL_RANGE) -> void:
		for key: String in parts:
			var data: Array = parts[key]
			var detail := key.begins_with("d:")
			var multi := MultiMesh.new()
			multi.transform_format = MultiMesh.TRANSFORM_3D
			multi.use_colors = true
			multi.use_custom_data = true
			multi.mesh = CityPlanet.mesh(key.trim_prefix("d:"))
			multi.instance_count = data[0].size()
			for i in data[0].size():
				multi.set_instance_transform(i, data[0][i])
				multi.set_instance_color(i, data[1][i])
				multi.set_instance_custom_data(i, data[2][i])
			var node := MultiMeshInstance3D.new()
			node.name = "%s_%s" % [label, key.replace(":", "_")]
			node.multimesh = multi
			node.material_override = CityPlanet.tower_material()
			node.visibility_range_end = minf(far, detail_far) if detail else far
			node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if far<2000.0 and not detail else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
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
		"cyl", "trunk":
			var cyl := CylinderMesh.new()
			cyl.top_radius = 0.32 if kind=="trunk" else 0.5
			cyl.bottom_radius = 0.5
			cyl.height = 1.0
			cyl.radial_segments = 14
			cyl.rings = 1
			m = cyl
		"dome":
			var dome := SphereMesh.new()
			dome.radius = 0.5
			dome.height = 1.0
			dome.radial_segments = 14
			dome.rings = 6
			dome.is_hemisphere = true
			m = dome
		"sphere":
			var sphere := SphereMesh.new()
			sphere.radius = 0.5
			sphere.height = 1.0
			sphere.radial_segments = 12
			sphere.rings = 7
			m = sphere
		"cone":
			var cone := CylinderMesh.new()
			cone.top_radius = 0.0
			cone.bottom_radius = 0.5
			cone.height = 1.0
			cone.radial_segments = 10
			m = cone
		"torus", "ring":
			var torus := TorusMesh.new()
			torus.inner_radius = 0.38 if kind=="torus" else 0.28
			torus.outer_radius = 0.5
			torus.rings = 16 if kind=="torus" else 28
			torus.ring_segments = 6
			m = torus
		"tube":
			var tube := CylinderMesh.new()
			tube.top_radius = 0.5
			tube.bottom_radius = 0.5
			tube.height = 1.0
			tube.radial_segments = 28
			tube.rings = 1
			tube.cap_top = false
			tube.cap_bottom = false
			m = tube
	_meshes[kind] = m
	return m

func build() -> void:
	life = CityLife.new()
	life.city = self
	add_child(life)
	CityRoads.texture()  # every corner, before anything reads them
	for face in 6:
		for cj in range(0, CityLayout.N, CHUNK):
			for ci in range(0, CityLayout.N, CHUNK):
				_chunks.append([face, ci, cj])

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
	if not _chunks.is_empty() and not _building: _build_next(to_local(eye) if eye.is_finite() else Vector3.ZERO)
	_timer -= delta
	if _timer<=0.0 and is_instance_valid(local):
		_timer = 0.25
		_update_collision(to_local(local.global_position))

# --- Skyline ------------------------------------------------------------------------------

## The nearest unbuilt chunk, a slice at a time across frames.
func _build_next(eye: Vector3) -> void:
	var best := 0
	var best_d := 1e18
	for k in _chunks.size():
		var c: Array = _chunks[k]
		var mid := CityLayout.cell(int(c[0]), mini(int(c[1])+CHUNK/2, CityLayout.N-1), mini(int(c[2])+CHUNK/2, CityLayout.N-1))
		var d := (mid.frame as Transform3D).origin.distance_squared_to(eye)
		if d<best_d:
			best_d = d
			best = k
	var chunk: Array = _chunks.pop_at(best)
	_building = true
	_build_chunk(int(chunk[0]), int(chunk[1]), int(chunk[2]))

func _build_chunk(face: int, ci: int, cj: int) -> void:
	var batch := Batch.new()
	var start := Time.get_ticks_usec()
	for j in range(cj, mini(cj+CHUNK, CityLayout.N)):
		for i in range(ci, mini(ci+CHUNK, CityLayout.N)):
			var r := CityLayout.role(face, i, j)
			if r in ["skyline", "district", "park", "lake"]: _block(batch, face, i, j, r)
			_island(batch, face, i, j)
			if Time.get_ticks_usec()-start>BUDGET_USEC:
				await get_tree().process_frame
				if not is_inside_tree(): return
				start = Time.get_ticks_usec()
	var holder := Node3D.new()
	holder.name = "Skyline_%d_%d_%d" % [face, ci, cj]
	_done[Vector3i(face, ci/CHUNK, cj/CHUNK)] = true
	add_child(holder)
	batch.flush(holder, "c", 6000.0)
	_building = false

## A cell's blocks: buildings on round footprints, or a park or a lake.
func _block(batch: Batch, face: int, i: int, j: int, role: String) -> void:
	var key := Vector3i(face, i, j)
	var solids: Array = []
	var c := CityLayout.cell(face, i, j)
	var lot := CityLayout.ROAD+CityLayout.WALK+0.8
	for block: Dictionary in CityRoads.blocks(face, i, j):
		var seed := CityLayout.rnd(float(c.seed), 40+int(block.sub))
		var art := CityArt.new(batch, block.frame, solids)
		match role:
			"park": art.park(block, lot, seed, CityLayout.rnd(seed, 5)<0.35)
			"lake": art.lake(block, lot, seed)
			_:
				var near := role=="district"
				var feet := CityArt.pack(block, lot, seed, 6, 3.0, 9.0)
				for k in feet.size():
					var foot: Array = feet[k]
					var s := CityLayout.rnd(seed, 60+k)
					var tall := lerpf(10.0, 95.0, pow(s, 2.2))*(1.5 if near else 1.0)*(1.0 if k==0 else 0.5)
					art.building(foot[0], float(foot[1]), maxf(tall, 8.0), CityLayout.rnd(seed, 70+k), "", Color(NEON[int(s*NEON.size()) % NEON.size()]))
				art.gardens(block, lot, seed, feet)
	if _solids.has(key): (_solids[key] as Array).append_array(solids)
	else: _solids[key] = solids

## A roundabout's island at corner (i, j): a raised lawn, a kerb of stones
## and a big curly tree (or, now and then, a lantern on a plinth).
func _island(batch: Batch, face: int, i: int, j: int) -> void:
	var island := CityRoads.round_at(face, i, j)
	if island<=0.0: return
	var dir := CityRoads.dir(face, i, j)
	var frame := CityLayout._tangent(dir, Vector3.UP if absf(dir.y)<0.9 else Vector3.RIGHT)
	var key := Vector3i(face, mini(i, CityLayout.N-1), mini(j, CityLayout.N-1))
	var solids: Array = _solids.get(key, [])
	_solids[key] = solids
	var art := CityArt.new(batch, frame, solids)
	art.seed = CityLayout.rnd(float(face*1000+i*31+j), 9)
	art.part("cyl", Vector3(0, CityRoads.KERB*0.5, 0), Basis.IDENTITY, Vector3(island*2.0, CityRoads.KERB+0.1, island*2.0), Color("b8b0a8"), CityArt.M_STONE)
	art.part("cyl", Vector3(0, CityRoads.KERB+0.04, 0), Basis.IDENTITY, Vector3(island*2.0-0.8, 0.1, island*2.0-0.8), Color("3a6a42"), CityArt.M_GRASS)
	if art.r()<0.75: art.tree(Vector2.ZERO, lerpf(3.0, 4.2, art.r()), art.seed+0.3)
	else:
		art.part("cyl", Vector3(0, 1.0, 0), Basis.IDENTITY, Vector3(1.6, 1.8, 1.6), Color(CityArt.STONE[0]), CityArt.M_STONE)
		art.part("cyl", Vector3(0, 3.5, 0), Basis.IDENTITY, Vector3(0.35, 3.4, 0.35), Color("d9ac60"))
		art.part("sphere", Vector3(0, 5.6, 0), Basis.IDENTITY, Vector3.ONE*1.3, Color(NEON[int(art.r()*NEON.size()) % NEON.size()]), CityArt.M_GLOW)
		art.solid(Vector3(0, 1.0, 0), Vector3(1.6, 2.0, 1.6))

# --- Collision and raised sidewalks -----------------------------------------------------------------

## Static shapes and kerbed sidewalks for the blocks within reach of the player (planet-space `at`).
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
			var c := CityLayout.cell(face, i, j)
			if (c.frame as Transform3D).origin.distance_to(at)>COLLIDE_RANGE+40.0: continue
			want[Vector3i(face, i, j)] = true
	for key: Vector3i in _bodies.keys():
		if not want.has(key): _drop_body(key)
	var made := 0
	for key: Vector3i in want:
		if _bodies.has(key) or made>=6 or not _done.has(Vector3i(key.x, key.y/CHUNK, key.z/CHUNK)): continue
		made += 1
		var holder := Node3D.new()
		holder.name = "Near_%d_%d_%d" % [key.x, key.y, key.z]
		add_child(holder)
		_bodies[key] = holder
		var body := StaticBody3D.new()
		body.collision_layer = Player.OBSTACLE_LAYER
		body.collision_mask = 0
		holder.add_child(body)
		for solid: Array in _solids.get(key, []):
			var shape := CollisionShape3D.new()
			var size: Vector3 = solid[1]
			if str(solid[2])=="cyl":
				var cyl := CylinderShape3D.new()
				cyl.radius = size.x*0.5
				cyl.height = size.y
				shape.shape = cyl
			else:
				var box := BoxShape3D.new()
				box.size = size
				shape.shape = box
			shape.transform = solid[0]
			body.add_child(shape)
		_sidewalks(holder, key)

## The sidewalks round a cell's blocks as raised slabs with kerbs, painted by
## the ground shader (slabs on top, kerb stones on the sides), and solid.
func _sidewalks(holder: Node3D, key: Vector3i) -> void:
	var role := CityLayout.role(key.x, key.y, key.z)
	if role=="port": return
	var r := CityLayout.radius()
	var h := CityRoads.KERB
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	for block: Dictionary in CityRoads.blocks(key.x, key.y, key.z):
		var frame: Transform3D = block.frame
		var outer := CityRoads.outline(block, CityLayout.ROAD, 40, false)
		var inner := CityRoads.outline(block, CityLayout.ROAD+CityLayout.WALK, 40, false)
		if outer.size()!=inner.size() or outer.size()<3: continue
		var at := func(p: Vector2, lift: float) -> Vector3: return (frame*Vector3(p.x, 0, p.y)).normalized()*(r+lift)
		var n := outer.size()
		for k in n:
			var o0: Vector3 = at.call(outer[k], h)
			var o1: Vector3 = at.call(outer[(k+1) % n], h)
			var i0: Vector3 = at.call(inner[k], h)
			var i1: Vector3 = at.call(inner[(k+1) % n], h)
			var up := o0.normalized()
			_quad(verts, normals, o0, o1, i1, i0, up)
			# The kerb's face down to the street, and the step into the courtyard.
			var ob0: Vector3 = at.call(outer[k], -0.05)
			var ob1: Vector3 = at.call(outer[(k+1) % n], -0.05)
			_quad(verts, normals, ob0, ob1, o1, o0, ((o0+o1)*0.5-frame*Vector3(block.seed.x, 0, block.seed.y)).slide(up).normalized())
			var ib0: Vector3 = at.call(inner[k], -0.05)
			var ib1: Vector3 = at.call(inner[(k+1) % n], -0.05)
			_quad(verts, normals, i1, i0, ib0, ib1, (frame*Vector3(block.seed.x, 0, block.seed.y)-(i0+i1)*0.5).slide(up).normalized())
	if verts.is_empty(): return
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = PlanetTerrain.material_for(CityLayout.planet())
	holder.add_child(node)
	var body := StaticBody3D.new()
	body.collision_layer = Player.TERRAIN_LAYER
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var tris := ConcavePolygonShape3D.new()
	tris.set_faces(verts)
	tris.backface_collision = true
	shape.shape = tris
	body.add_child(shape)
	holder.add_child(body)

## Two triangles a, b, c, d facing `normal` (wound to face it).
static func _quad(verts: PackedVector3Array, normals: PackedVector3Array, a: Vector3, b: Vector3, c: Vector3, d: Vector3, normal: Vector3) -> void:
	var flip := (b-a).cross(c-a).dot(normal)>0.0
	for p: Vector3 in ([a, c, b, a, d, c] if flip else [a, b, c, a, c, d]):
		verts.append(p)
		normals.append(normal)

func _drop_body(key: Vector3i) -> void:
	var body: Node = _bodies[key]
	_bodies.erase(key)
	if is_instance_valid(body): body.queue_free()
