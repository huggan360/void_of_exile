class_name PlanetTerrain
extends Node3D
## A whole planet's ground as a streamed cube-sphere: six faces split into a
## quadtree of chunks around the camera (more detail nearby, coarse from
## orbit). Heights come from SpaceLayout.surface_height, so the ground the
## server reasons about is the ground drawn here. Chunks are meshed on worker
## threads; the chunks under the local player also get collision.
const GRID := 24
const LEAF_ARC := 32.0  # metres across a finest chunk
const SPLIT := 1.7  # split while the camera is within SPLIT chunk widths
const COLLIDE_RANGE := 110.0
const UPDATE_EVERY := 0.15
const MAX_TASKS := 6
const FACES: Array[Vector3] = [Vector3.RIGHT, Vector3.LEFT, Vector3.UP, Vector3.DOWN, Vector3.BACK, Vector3.FORWARD]

static var _material_cache := {}

class Chunk extends RefCounted:
	var face := 0
	var level := 0
	var x := 0
	var y := 0
	var center := Vector3.ZERO  # on the ground, planet space
	var arc := 0.0
	var node: MeshInstance3D
	var body: StaticBody3D
	var arrays: Array = []  # mesh arrays once built
	var faces := PackedVector3Array()  # collision triangles
	var task := -1
	var children: Array = []
	var shown := false

var planet: Dictionary
## The local player: chunks near it get collision.
var focus: Node3D
var radius := 1.0
var max_level := 4
var _roots: Array = []
var _timer := 0.0
var _active: Array = []  # [task id, Chunk]
var _material: ShaderMaterial

func setup(p: Dictionary) -> void:
	planet = p
	radius = float(p.radius)
	max_level = maxi(2, ceili(log(radius*PI*0.5/LEAF_ARC)/log(2.0)))
	# Warm the shared noise and flat-spot caches before threads read them.
	SpaceLayout.surface_height(p, Vector3.UP)
	_material = material_for(p)
	for f in 6:
		var root := _make(f, 0, 0, 0)
		_build(root)
		_roots.append(root)

static func material_for(p: Dictionary) -> ShaderMaterial:
	if _material_cache.has(p.id): return _material_cache[p.id]
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/city_ground.gdshader") if p.get("city", false) else preload("res://shaders/planet_terrain.gdshader")
	if p.get("city", false):
		mat.set_shader_parameter("planet_center", p.center)
		mat.set_shader_parameter("planet_radius", p.radius)
		mat.set_shader_parameter("cells", CityLayout.N)
		mat.set_shader_parameter("road", CityLayout.ROAD)
		mat.set_shader_parameter("walk", CityLayout.WALK)
		mat.set_shader_parameter("ring", CityRoads.RING)
		mat.set_shader_parameter("kerb_height", CityRoads.KERB)
		mat.set_shader_parameter("roads", CityRoads.texture())
		mat.set_shader_parameter("asphalt_tex", CityTextures.asphalt())
		mat.set_shader_parameter("slab_tex", CityTextures.slabs())
		mat.set_shader_parameter("kerb_tex", CityTextures.kerb())
		mat.set_shader_parameter("cobble_tex", CityTextures.cobbles())
		mat.set_shader_parameter("grass_tex", CityTextures.grass())
	mat.set_shader_parameter("magic", Color(str(p.palette[3])))
	mat.set_shader_parameter("detail_scale", 1.0/maxf(6.0, float(p.terrain.size)*0.04))
	_material_cache[p.id] = mat
	return mat

func _make(face: int, level: int, x: int, y: int) -> Chunk:
	var c := Chunk.new()
	c.face = face
	c.level = level
	c.x = x
	c.y = y
	var n := 1 << level
	var dir := _dir(face, (x+0.5)/n*2.0-1.0, (y+0.5)/n*2.0-1.0).normalized()
	c.center = dir*(radius+SpaceLayout.surface_height(planet, dir))
	c.arc = radius*PI*0.5/n
	return c

## Unit direction for cube face coordinates u, v in -1..1 (spherified cube).
func _dir(face: int, u: float, v: float) -> Vector3:
	var n := FACES[face]
	var a := Vector3(n.y, n.z, n.x)
	var b := n.cross(a)
	var p := n+a*u+b*v
	var x2 := p.x*p.x
	var y2 := p.y*p.y
	var z2 := p.z*p.z
	return Vector3(p.x*sqrt(1.0-y2*0.5-z2*0.5+y2*z2/3.0), p.y*sqrt(1.0-z2*0.5-x2*0.5+z2*x2/3.0), p.z*sqrt(1.0-x2*0.5-y2*0.5+x2*y2/3.0))

func _process(delta: float) -> void:
	_finish_tasks()
	_timer -= delta
	if _timer>0.0: return
	_timer = UPDATE_EVERY
	var camera := get_viewport().get_camera_3d()
	if camera==null: return
	var eye := global_transform.affine_inverse()*camera.global_position
	var body := Vector3.INF
	if is_instance_valid(focus): body = global_transform.affine_inverse()*focus.global_position
	for root: Chunk in _roots: _visit(root, eye, body)

## Show the right chunks below `c`: split near the eye, merge far away.
func _visit(c: Chunk, eye: Vector3, body: Vector3) -> void:
	var want_split := c.level<max_level and eye.distance_to(c.center)<c.arc*SPLIT+c.arc*0.5
	if want_split:
		if c.children.is_empty():
			for i in 4: c.children.append(_make(c.face, c.level+1, c.x*2+(i & 1), c.y*2+(i >> 1)))
		var ready := true
		for child: Chunk in c.children:
			if not _built(child):
				ready = false
				_request(child)
		if ready:
			_show(c, false)
			for child: Chunk in c.children: _visit(child, eye, body)
			return
		_show(c, true)
		return
	_show(c, true)
	_collide(c, body)
	for child: Chunk in c.children: _drop(child)
	c.children.clear()

func _built(c: Chunk) -> bool:
	return c.task<0 and not c.arrays.is_empty()

func _show(c: Chunk, on: bool) -> void:
	if on and not _built(c):
		_request(c)
		return
	if on and c.node==null:
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, c.arrays)
		c.node = MeshInstance3D.new()
		c.node.mesh = mesh
		c.node.material_override = _material
		c.node.position = c.center
		c.node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(c.node)
	if c.node: c.node.visible = on
	if not on and c.body:
		c.body.queue_free()
		c.body = null

func _collide(c: Chunk, body: Vector3) -> void:
	var near := c.level==max_level and body.is_finite() and body.distance_to(c.center)<COLLIDE_RANGE+c.arc
	if near and c.body==null and not c.faces.is_empty():
		c.body = StaticBody3D.new()
		c.body.collision_layer = Player.TERRAIN_LAYER
		c.body.collision_mask = 0
		c.body.position = c.center
		var shape := ConcavePolygonShape3D.new()
		shape.set_faces(c.faces)
		var collision := CollisionShape3D.new()
		collision.shape = shape
		c.body.add_child(collision)
		add_child(c.body)
	elif not near and c.body:
		c.body.queue_free()
		c.body = null

func _drop(c: Chunk) -> void:
	for child: Chunk in c.children: _drop(child)
	c.children.clear()
	if c.node: c.node.queue_free()
	if c.body: c.body.queue_free()
	c.node = null
	c.body = null

func _request(c: Chunk) -> void:
	if c.task>=0 or not c.arrays.is_empty() or _active.size()>=MAX_TASKS: return
	c.task = WorkerThreadPool.add_task(_build.bind(c), false, "planet chunk")
	_active.append([c.task, c])

## Collects finished meshes (dropped chunks finish too, then are forgotten).
func _finish_tasks() -> void:
	for entry: Array in _active.duplicate():
		if not WorkerThreadPool.is_task_completed(int(entry[0])): continue
		WorkerThreadPool.wait_for_task_completion(int(entry[0]))
		(entry[1] as Chunk).task = -1
		_active.erase(entry)

func _exit_tree() -> void:
	for entry: Array in _active: WorkerThreadPool.wait_for_task_completion(int(entry[0]))
	_active.clear()

## Ground under the local player gets built at once (arrival, landing).
func ensure_ground(world_position: Vector3) -> void:
	var at := global_transform.affine_inverse()*world_position
	var dir := at.normalized()
	var c: Chunk = _roots[0]
	for root: Chunk in _roots:
		if FACES[root.face].dot(dir)>FACES[c.face].dot(dir): c = root
	# Down the tree toward `dir`, building synchronously to the finest level.
	while c.level<max_level:
		if c.children.is_empty():
			for i in 4: c.children.append(_make(c.face, c.level+1, c.x*2+(i & 1), c.y*2+(i >> 1)))
		var next: Chunk = c.children[0]
		for child: Chunk in c.children:
			if child.task>=0:
				for entry: Array in _active.duplicate():
					if entry[1]==child: _active.erase(entry)
				WorkerThreadPool.wait_for_task_completion(child.task)
				child.task = -1
			if child.arrays.is_empty(): _build(child)
			if child.center.normalized().dot(dir)>next.center.normalized().dot(dir): next = child
		c = next
	_collide(c, at)

## Mesh one chunk (worker thread): positions relative to its centre, normals,
## colours from height/slope/biome, skirts against cracks, collision faces.
func _build(c: Chunk) -> void:
	var n := 1 << c.level
	var step := 2.0/n/GRID
	var u0 := float(c.x)/n*2.0-1.0
	var v0 := float(c.y)/n*2.0-1.0
	var side := GRID+3
	var pos := PackedVector3Array()
	pos.resize(side*side)
	var dirs := PackedVector3Array()
	dirs.resize(side*side)
	var heights := PackedFloat32Array()
	heights.resize(side*side)
	for j in side:
		for i in side:
			# The outer ring (one step past the chunk) only feeds the normals.
			var dir := _dir(c.face, u0+(i-1)*step, v0+(j-1)*step).normalized()
			var h := SpaceLayout.surface_height(planet, dir)
			var k := j*side+i
			dirs[k] = dir
			heights[k] = h
			pos[k] = dir*(radius+h)
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	var count := GRID+1
	for j in count:
		for i in count:
			var k := (j+1)*side+(i+1)
			var normal := (pos[k+1]-pos[k-1]).cross(pos[k+side]-pos[k-side]).normalized()
			if normal.dot(dirs[k])<0.0: normal = -normal
			verts.append(pos[k]-c.center)
			normals.append(normal)
			colors.append(PlanetPalette.ground(planet, dirs[k], heights[k], normal))
	# Winding: keep the first triangle facing outward.
	var flip := (verts[count]-verts[0]).cross(verts[1]-verts[0]).dot(dirs[side+1])<0.0
	for j in GRID:
		for i in GRID:
			var a := j*count+i
			var tri: Array[int] = [a, a+1, a+count, a+1, a+count+1, a+count]
			if flip: tri = [a, a+count, a+1, a+1, a+count, a+count+1]
			for t in tri: indices.append(t)
	var faces := PackedVector3Array()
	for t in indices: faces.append(verts[t])
	# Skirts hang below each edge so neighbours of another level never gap.
	var drop := c.arc*0.06+2.0
	var edges: Array = [range(0, count), range(count*GRID, count*count), range(0, count*count, count), range(GRID, count*count, count)]
	for edge: Array in edges:
		var first := verts.size()
		for idx: int in edge:
			var dir: Vector3 = (verts[idx]+c.center).normalized()
			verts.append(verts[idx]-dir*drop)
			normals.append(normals[idx])
			colors.append(colors[idx].darkened(0.2))
		for e in edge.size()-1:
			var top_a: int = edge[e]
			var top_b: int = edge[e+1]
			var low_a := first+e
			var low_b := first+e+1
			for t in [top_a, low_a, top_b, top_b, low_a, low_b, top_a, top_b, low_a, top_b, low_b, low_a]: indices.append(t)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	c.faces = faces
	c.arrays = arrays
