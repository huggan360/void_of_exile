@tool
extends Node3D
## Small hand-sculpted palette voxel models, meshed once per kind and shared.
@export_enum("sentinel", "brazier", "banner", "candelabra", "chandelier", "bones", "web", "window", "chain", "throne", "wall_ballista", "charred_tree", "burning_tree", "fallen_log", "stump", "embers", "armour") var kind := "sentinel"
@export var ember_particles := true
const STEP := 0.25
static var _cache: Dictionary = {}
static var _shared_flame: ShaderMaterial
var _voxels: Dictionary = {}
var _fire: Dictionary = {}
const COLORS := [Color("23252c"), Color("454851"), Color("bfc0b8"), Color("ebe8d8"), Color("090b10"), Color("ff5d16"), Color("ffba50"), Color("fff1c6"), Color("242024"), Color("4a4140"), Color("70605a"), Color("b59777")]

func _ready() -> void:
	if not _cache.has(kind):
		_sculpt()
		_cache[kind] = [_mesh(_voxels), _mesh(_fire)]
	for i in 2:
		if _cache[kind][i] == null: continue
		var instance := MeshInstance3D.new()
		instance.mesh = _cache[kind][i]
		instance.scale = Vector3.ONE * STEP
		instance.material_override = VoxModel.material() if i == 0 else _flame_material()
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if i == 1 else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		add_child(instance)
	var b := solid_bounds()
	if b.has_volume() and not Engine.is_editor_hint():
		var body := StaticBody3D.new()
		body.collision_layer = 2
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = b.size
		shape.shape = box
		shape.position = b.get_center()
		body.add_child(shape)
		add_child(body)
	if ember_particles and kind in ["brazier", "chandelier", "banner", "burning_tree", "embers"] and not Engine.is_editor_hint():
		_embers()
	_voxels.clear()
	_fire.clear()

func solid_bounds() -> AABB:
	match kind:
		"charred_tree", "burning_tree": return AABB(Vector3(-1, 0, -1), Vector3(2, 16, 2))
		"fallen_log": return AABB(Vector3(-1, 0, -1), Vector3(2, 2, 10))
		"stump": return AABB(Vector3(-1, 0, -1), Vector3(2, 2, 2))
		"sentinel": return AABB(Vector3(-1.5, 0, -1.5), Vector3(3, 7.5, 3))
		"brazier": return AABB(Vector3(-0.8, 0, -0.8), Vector3(1.6, 2.5, 1.6))
		"candelabra": return AABB(Vector3(-0.6, 0, -0.6), Vector3(1.2, 3, 1.2))
		# Only the backrest blocks movement; the king can reach the seat.
		"throne": return AABB(Vector3(-3, 0, 0.5), Vector3(6, 9, 1))
	return AABB()

func _box(a: Vector3i, b: Vector3i, color: int, burning := false) -> void:
	var target := _fire if burning else _voxels
	for x in range(a.x, b.x):
		for y in range(a.y, b.y):
			for z in range(a.z, b.z):
				target[Vector3i(x, y, z)] = color

func _b(x0: int, y0: int, z0: int, x1: int, y1: int, z1: int, color: int, burning := false) -> void:
	_box(Vector3i(x0, y0, z0), Vector3i(x1, y1, z1), color, burning)

func _flame(x: int, y: int, z: int, height: int = 8) -> void:
	for j in height:
		var r := maxi(0, 2 - j / 3)
		_b(x-r + j/5, y+j, z-r, x+r+1+j/5, y+j+1, z+r+1, 6 if j > height/2 else 7, true)
	_b(x, y, z, x+1, y+3, z+1, 8, true)

func _sculpt() -> void:
	match kind:
		"charred_tree", "burning_tree":
			# Split bark, buttress roots and angular snapped limbs; no foliage.
			for y in range(88):
				var r := maxi(1, 5 - y / 22)
				var bend := y / 29
				_b(-r+bend, y, -r, r+1+bend, y+1, r+1, 10 if y%11 == 0 else 9)
				if y%7 < 4: _b(-r+bend, y, -r-1, -r+1+bend, y+1, -r, 11)
			for side in [-1, 1]:
				for j in range(17):
					var y := 40 + j
					_b(side*j-2, y, -2, side*j+1, y+3, 2, 9)
					_b(side*(j/2)-1, 65+j, j/2, side*(j/2)+2, 68+j, j/2+3, 10)
				for j in range(10):
					_b(side*j-2, 0, -3, side*j+2, maxi(1, 6-j/2), 3, 9)
			_b(1, 88, -1, 4, 93, 1, 12)
			if kind == "burning_tree":
				for spot in [Vector3i(-3, 5, -5), Vector3i(4, 22, 0), Vector3i(-9, 46, 0), Vector3i(13, 54, 0), Vector3i(2, 76, 0)]:
					_flame(spot.x, spot.y, spot.z, 15)
		"fallen_log":
			for z in range(42):
				var r := 4 if z < 33 else 3
				_b(-r, 0, z, r+1, 7, z+1, 10 if z%9 == 0 else 9)
			_b(-3, 1, -1, 4, 6, 0, 12)
			_b(-2, 2, -2, 3, 5, -1, 10)
			for j in range(11): _b(j, 4+j/3, 18, j+2, 6+j/3, 21, 9)
		"stump":
			_b(-5, 0, -4, 6, 6, 5, 9)
			_b(-4, 6, -3, 5, 7, 4, 12)
			_b(-2, 6, -2, 3, 7, 3, 10)
			for x in [-5, 3]: _b(x, 6, -3, x+2, 12, -1, 10)
		"embers":
			for i in range(16):
				var x := posmod(i*7, 19)-9
				var z := posmod(i*11, 17)-8
				_b(x, 0, z, x+3, 1+i%2, z+2, 9)
				if i%3 == 0: _flame(x, 1, z, 3+i%4)
		"armour":
			_b(-3, 0, -5, 4, 2, 3, 2)
			_b(-2, 1, -4, 3, 3, 1, 1)
			_b(-2, 0, 5, 3, 4, 9, 3)
			_b(-2, 1, 4, 3, 2, 5, 5)
			_b(6, 0, -7, 7, 1, 9, 3)
			_b(4, 0, 4, 9, 1, 5, 2)
		"sentinel":
			_b(-6, 0, -6, 6, 2, 6, 3)
			_b(-5, 2, -5, 5, 4, 5, 1)
			# Hooded, faceless knight with a downward-pointing ivory sword.
			for y in range(4, 23):
				var r := 5 - (y-4)/6
				_b(-r, y, -3, r+1, y+1, 4, 2 if y%5 == 0 else 1)
			_b(-4, 22, -3, 5, 27, 4, 3)
			_b(-3, 24, -4, 4, 29, 3, 1)
			_b(-2, 24, -5, 3, 27, -3, 5)
			_b(-5, 17, -3, -3, 23, 1, 3)
			_b(4, 17, -3, 6, 23, 1, 3)
			_b(-4, 16, -6, 5, 18, -4, 3)
			_b(0, 5, -6, 1, 21, -5, 4)
			_b(-2, 18, -6, 3, 19, -5, 4)
		"brazier":
			_b(-4, 0, -4, 4, 1, 4, 3)
			_b(-2, 1, -2, 2, 7, 2, 1)
			_b(-4, 7, -4, 4, 9, 4, 2)
			for x in [-4, 3]:
				for z in [-4, 3]: _b(x, 8, z, x+1, 12, z+1, 3)
			_flame(-1, 9, -1, 12)
			_flame(2, 9, 1, 8)
		"banner":
			_b(-8, 26, 0, 9, 27, 2, 3)
			for x in range(-6, 7):
				for y in range(5 + posmod(x*7, 5), 26):
					_b(x, y, 0, x+1, y+1, 1, 3 if abs(x)==6 else 5)
			_b(-1, 13, -1, 2, 23, 0, 3)
			_b(-4, 19, -1, 5, 21, 0, 3)
			for x in [-5, 0, 5]: _flame(x, 6 + posmod(x, 3), 0, 7)
		"candelabra":
			_b(-3, 0, -3, 4, 1, 4, 3)
			_b(0, 1, 0, 1, 13, 1, 2)
			_b(-6, 10, 0, 7, 11, 1, 3)
			for x in [-6, -3, 0, 3, 6]:
				_b(x, 10, 0, x+1, 15 + (2 if x == 0 else 0), 1, 4)
				_flame(x, 15 + (2 if x == 0 else 0), 0, 3)
		"chandelier":
			for y in range(1, 24):
				_b(0, y, 0, 1, y+1, 1, 2)
			for x in range(-12, 13):
				for z in range(-12, 13):
					var d := Vector2(x, z).length()
					if d > 10 and d < 12:
						_b(x, 0, z, x+1, 2, z+1, 3)
			for x in [-9, 0, 9]:
				for z in [-9, 0, 9]:
					if x == 0 and z == 0: continue
					_b(x, 0, z, x+1, 5, z+1, 4)
					_flame(x, 5, z, 7)
			for i in 11:
				_b(i, i, 0, i+1, i+1, 1, 2)
				_b(-i, i, 0, -i+1, i+1, 1, 2)
				_b(0, i, i, 1, i+1, i+1, 2)
				_b(0, i, -i, 1, i+1, -i+1, 2)
		"bones":
			for i in 7:
				var x := posmod(i*13, 13)-6
				var z := posmod(i*7, 11)-5
				_b(x, i%2, z, x+5, i%2+1, z+1, 3)
			_b(-2, 1, -2, 2, 4, 2, 4)
			_b(-2, 2, -3, -1, 3, -2, 5)
			_b(1, 2, -3, 2, 3, -2, 5)
		"wall_ballista":
			# Recessed black arrow bank, iron frame and three fixed bow arms.
			_b(-12, 0, 0, 12, 16, 3, 1)
			_b(-11, 1, -1, 11, 15, 0, 4)
			for y in [0, 6, 10, 15]: _b(-12, y, -2, 12, y+1, 1, 2)
			for x in [-12, 11]: _b(x, 0, -2, x+1, 16, 1, 2)
			for x in [-8, 0, 8]:
				for y in [4, 8, 12]:
					_b(x-2, y, -4, x+3, y+1, -3, 2)
					_b(x, y, -6, x+1, y+1, 0, 3)
		"window":
			# Broken monochrome lancet: radiating shards, empty missing panes.
			for x in range(-12, 13):
				for y in range(0, 40-abs(x)):
					if abs(x)==12 or y==0 or y>=38-abs(x) or x==0 or y==16:
						_b(x, y, 0, x+1, y+1, 2, 3)
					elif y > 11 + abs(x)/2 + posmod(x*3, 5) and not (x > 3 and y < 22 + x/2):
						_b(x, y, 0, x+1, y+1, 1, 2 if posmod(x+y, 12) == 0 else 4)
		"web":
			for i in 25:
				_b(i, 24-i, 0, i+1, 25-i, 1, 3)
				_b(i, 24-i/2, 0, i+1, 25-i/2, 1, 3)
				_b(i/2, 24-i, 0, i/2+1, 25-i, 1, 3)
			for r in [7, 14, 21]:
				for i in range(r+1): _b(i, 24-r+i/3, 0, i+1, 25-r+i/3, 1, 3)
		"chain":
			for y in range(0, 60, 4):
				_b(-1, y, 0, 2, y+1, 1, 2)
				_b(-1, y+3, 0, 2, y+4, 1, 2)
				_b(-1, y, 0, 0, y+4, 1, 3)
				_b(1, y, 0, 2, y+4, 1, 3)
		"throne":
			_b(-12, 0, -6, 12, 2, 6, 3)
			_b(-9, 2, -4, 9, 4, 5, 1)
			_b(-9, 4, -4, 9, 6, 5, 3)
			_b(-9, 6, 2, 9, 29, 5, 1)
			for x in range(-9, 10, 3):
				_b(x, 7, 1, x+1, 34-abs(x)/2, 2, 4)
			for x in [-10, 8]:
				_b(x, 5, -5, x+2, 10, 5, 3)
				_b(x, 10, -5, x+2, 12, -3, 4)

func _mesh(voxels: Dictionary) -> Mesh:
	if voxels.is_empty(): return null
	var lo := Vector3i(0, 0, 0)
	var hi := lo
	for p: Vector3i in voxels:
		lo = lo.min(p)
		hi = hi.max(p)
	var buffer := VoxelBuffer.new()
	var size := hi - lo + Vector3i.ONE
	buffer.create(size.x, size.y, size.z)
	var palette := VoxelColorPalette.new()
	for i in COLORS.size(): palette.set_color(i+1, COLORS[i])
	for p: Vector3i in voxels: buffer.set_voxel(voxels[p], p.x-lo.x, p.y-lo.y, p.z-lo.z, VoxelBuffer.CHANNEL_COLOR)
	var result := VoxModel.mesh_from_buffer(buffer, palette) as ArrayMesh
	# Mesher adds one padding voxel. Move vertices back to sculpt coordinates.
	var shifted := ArrayMesh.new()
	for i in result.get_surface_count():
		var arrays := result.surface_get_arrays(i)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		for j in vertices.size(): vertices[j] += Vector3(lo - Vector3i.ONE)
		arrays[Mesh.ARRAY_VERTEX] = vertices
		shifted.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return shifted

func _flame_material() -> ShaderMaterial:
	if _shared_flame == null:
		_shared_flame = ShaderMaterial.new()
		_shared_flame.shader = preload("res://props/castle/flame.gdshader")
	return _shared_flame

func _embers() -> void:
	var particles := GPUParticles3D.new()
	particles.amount = 12 if kind != "chandelier" else 24
	particles.lifetime = 3.5
	particles.position.y = 2.5 if kind == "brazier" else 1.7
	particles.visibility_aabb = AABB(Vector3(-5, -2, -5), Vector3(10, 12, 10))
	var process := ParticleProcessMaterial.new()
	process.direction = Vector3.UP
	process.spread = 22
	process.initial_velocity_min = 0.3
	process.initial_velocity_max = 1.1
	process.gravity = Vector3(0.12, 0.25, 0)
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(0.7, 0.1, 0.7)
	process.scale_min = 0.035
	process.scale_max = 0.09
	particles.process_material = process
	var cube := BoxMesh.new()
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color("ffb46c")
	material.emission_enabled = true
	material.emission = Color("ff8b32")
	material.emission_energy_multiplier = 2.5
	cube.material = material
	particles.draw_pass_1 = cube
	add_child(particles)
