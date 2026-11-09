class_name NexusStation
extends Node3D
## Open timber tavern and six radial boarding walks.

var anchors: Dictionary = {}

## Shared primitive batches keep each sculpture to a handful of draw calls.
class Brush extends RefCounted:
	static var _meshes: Dictionary = {}
	static var _material: ShaderMaterial
	var root: Node3D
	var server_only: bool
	var far: float
	var body: StaticBody3D
	var batches: Dictionary = {}

	func _init(parent: Node3D, server: bool, distance := 0.0) -> void:
		root = parent
		server_only = server
		far = distance

	static func mesh(kind: String) -> Mesh:
		if _meshes.has(kind): return _meshes[kind]
		var result: Mesh
		match kind:
			"box":
				var box := BoxMesh.new()
				box.size = Vector3.ONE
				result = box
			"sphere":
				var sphere := SphereMesh.new()
				sphere.radius = 0.5
				sphere.height = 1.0
				sphere.radial_segments = 20
				sphere.rings = 10
				result = sphere
			_:
				var cylinder := CylinderMesh.new()
				cylinder.top_radius = 0.0 if kind == "cone" else 0.5
				cylinder.bottom_radius = 0.5
				cylinder.height = 1.0
				cylinder.radial_segments = 6 if kind == "cone" else 48
				result = cylinder
		_meshes[kind] = result
		return result

	func part(kind: String, frame: Transform3D, size: Vector3, color: Color, solid := false, glow := 0.0) -> void:
		if solid:
			if not is_instance_valid(body):
				body = StaticBody3D.new()
				body.collision_layer = Player.TERRAIN_LAYER
				body.collision_mask = 0
				root.add_child(body)
			var collision := CollisionShape3D.new()
			var shape: Shape3D
			if kind == "sphere":
				var sphere := SphereShape3D.new()
				sphere.radius = size.x * 0.5
				shape = sphere
			elif kind == "cylinder":
				var cylinder := CylinderShape3D.new()
				cylinder.radius = size.x * 0.5
				cylinder.height = size.y
				shape = cylinder
			else:
				var box := BoxShape3D.new()
				box.size = size
				shape = box
			collision.shape = shape
			collision.transform = frame
			body.add_child(collision)
		if server_only: return
		if not batches.has(kind): batches[kind] = []
		batches[kind].append([Transform3D(frame.basis.scaled_local(size), frame.origin), color, glow])

	func box(at: Vector3, size: Vector3, color: Color, solid := false, glow := 0.0) -> void:
		part("box", Transform3D(Basis.IDENTITY, at), size, color, solid, glow)

	func round_part(at: Vector3, radius: float, height: float, color: Color, solid := false, glow := 0.0) -> void:
		part("cylinder", Transform3D(Basis.IDENTITY, at), Vector3(radius * 2, height, radius * 2), color, solid, glow)

	func crystal(at: Vector3, height: float, color: Color, solid := false) -> void:
		part("cone", Transform3D(Basis.IDENTITY, at + Vector3.UP * height * 0.5), Vector3(height * 0.5, height, height * 0.5), color, false, 1.2)
		if solid: box(at + Vector3.UP * height * 0.28, Vector3(height * 0.22, height * 0.55, height * 0.22), color, true)

	## A small amber glass lantern in a copper cage, hung from a stepped bracket.
	func hanging_lantern(at: Vector3) -> void:
		var copper := Color("94704a")
		var iron := Color("343744")
		box(at, Vector3(0.32, 0.46, 0.32), Color("bc8246"), false, 0.35)
		box(at+Vector3(0, -0.02, 0), Vector3(0.16, 0.28, 0.16), Color("ffcf83"), false, 1.3)
		for y: float in [-0.28, 0.28]: box(at+Vector3.UP*y, Vector3(0.46, 0.08, 0.46), copper)
		for x: float in [-0.19, 0.19]:
			for z: float in [-0.19, 0.19]: box(at+Vector3(x, 0, z), Vector3(0.045, 0.54, 0.045), iron)
		for y: float in [-0.12, 0.12]:
			box(at+Vector3(0, y, 0.2), Vector3(0.42, 0.035, 0.035), copper)
			box(at+Vector3(0, y, -0.2), Vector3(0.42, 0.035, 0.035), copper)
		for tier in 3:
			var width := 0.54-float(tier)*0.12
			box(at+Vector3.UP*(0.34+tier*0.055), Vector3(width, 0.06, width), Color("43605b").lightened(tier*0.04))
		box(at+Vector3.UP*0.5, Vector3(0.08, 0.16, 0.08), copper)

	func lantern(at: Vector3, tall := 4.0) -> void:
		var height := clampf(tall*0.7, 2.2, 3.2)
		box(at+Vector3.UP*0.09, Vector3(0.4, 0.18, 0.4), Color("3e4148"))
		box(at+Vector3.UP*(height*0.5), Vector3(0.15, height, 0.15), Color("694b37"))
		for y: float in [0.22, height*0.6, height-0.1]:
			box(at+Vector3.UP*y, Vector3(0.22, 0.09, 0.22), Color("94704a"))
		box(at+Vector3(0.28, height, 0), Vector3(0.68, 0.09, 0.13), Color("343744"))
		box(at+Vector3(0.57, height-0.12, 0), Vector3(0.08, 0.3, 0.08), Color("94704a"))
		hanging_lantern(at+Vector3(0.57, height-0.8, 0))

	func finish() -> void:
		if server_only: return
		if _material == null:
			_material = ShaderMaterial.new()
			_material.shader = load("res://shaders/space_props.gdshader")
		for kind: String in batches:
			var entries: Array = batches[kind]
			var multi := MultiMesh.new()
			multi.transform_format = MultiMesh.TRANSFORM_3D
			multi.use_colors = true
			multi.use_custom_data = true
			multi.mesh = mesh(kind)
			multi.instance_count = entries.size()
			for i in entries.size():
				multi.set_instance_transform(i, entries[i][0])
				multi.set_instance_color(i, entries[i][1])
				multi.set_instance_custom_data(i, Color(entries[i][2], 0, 0, 0))
			var instance := MultiMeshInstance3D.new()
			instance.multimesh = multi
			instance.material_override = _material
			instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			instance.visibility_range_end = far
			instance.visibility_range_end_margin = 80.0 if far > 0 else 0.0
			root.add_child(instance)
		batches.clear()

const WOOD := Color("8b583a")
const DARK := Color("42302d")
const BRASS := Color("d9ac60")
const GREEN := Color("85efac")
const PINK := Color("ef9ccf")

func build(server: bool) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	anchors = {
		spawn = Vector3(0, 0, 13),
		rocket_pad = Transform3D(Basis.IDENTITY, Vector3(31, 0, 17)),
		command_table = Vector3(-13, 0, 2),
		campaign_board = Vector3(-27, 0, -12),
		npc_captain = _facing(Vector3(-25, 0, -8), Vector3(-23, 0, 0)),
		npc_quartermaster = _facing(Vector3(-13, 0, -0.25), Vector3(-13, 0, 5)),
		npc_mechanic = _facing(Vector3(25, 0, 19), Vector3(31, 0, 17)),
		gangways = [],
	}
	var art := Brush.new(self, server)
	# The circular hull is continuous. Planks rise 2 cm above its collision top so the two
	# faces never share a plane (that z-fight drew long jagged streaks across the deck).
	art.round_part(Vector3(0, -1.1, 0), 51.5, 2.2, DARK, true)
	if not server:
		for row in range(-42, 43):
			var z := row * 1.2
			var half := sqrt(maxf(0, 51.2 * 51.2 - z * z))
			var count := maxi(1, ceili(half * 2 / 5.0))
			for column in count:
				var width := half * 2 / count
				art.box(Vector3(-half + (column + 0.5) * width, -0.06, z), Vector3(width - 0.035, 0.16, 1.15), WOOD.lightened(float((row + column * 3) % 5) * 0.025))
	# Rail sections leave six clear mouths for boarding.
	for i in 96:
		var angle := TAU * i / 96.0
		if i % 16 < 2 or i % 16 > 14: continue
		var frame := Transform3D(Basis(Vector3.UP, angle), Vector3(sin(angle), 0, cos(angle)) * 51)
		art.part("box", frame.translated_local(Vector3(0, 1.2, 0)), Vector3(0.24, 2.4, 0.24), BRASS, true)
		for height in [0.65, 2.2]:
			art.part("box", frame.translated_local(Vector3(0, height, 0)), Vector3(3.5, 0.16, 0.18), WOOD, true)
	for i in 6:
		var angle := TAU * i / 6.0
		var radial := Vector3(sin(angle), 0, cos(angle))
		var frame := Transform3D(Basis(Vector3.UP, angle), radial * 54.4)
		art.part("box", frame.translated_local(Vector3(0, -0.35, 0)), Vector3(6, 0.7, 10), WOOD, true)
		for side in [-1.0, 1.0]:
			art.part("box", frame.translated_local(Vector3(side * 2.9, 1.1, 0)), Vector3(0.2, 2.2, 10), BRASS, true)
			art.lantern(frame * Vector3(side * 2.8, 0, 3.5), 3.3)
		anchors.gangways.append(radial * 59.4)
	_tavern(art)
	_plaza(art, server)
	if not server: _floating_rock()
	# A standing-height shipwright's chart table, reachable from its front edge.
	var table: Vector3 = anchors.command_table
	art.round_part(table+Vector3.UP*0.46, 0.27, 0.92, DARK, true)
	art.round_part(table+Vector3.UP*0.08, 0.68, 0.16, DARK, true)
	art.round_part(table+Vector3.UP*1.0, 1.35, 0.16, WOOD, true)
	art.round_part(table+Vector3.UP*1.09, 1.2, 0.025, Color("253f4c"), false, 0.15)
	if not server:
		for i in 16:
			var angle := i*2.39996
			var at := table+Vector3(cos(angle), 0, sin(angle))*sqrt(float(i)/16.0)*1.05
			art.box(at+Vector3.UP*1.12, Vector3(0.055, 0.025, 0.055), GREEN if i%3 else PINK, false, 0.8)
		var sign := SignBoard.make("SHIPWRIGHT", "brass", "helm", Color("ffe0a0"), 0.65)
		sign.position = table+Vector3(-2.6, 1.65, 0)
		add_child(sign)
		art.box(table+Vector3(-2.6, 0.75, 0), Vector3(0.14, 1.5, 0.14), DARK)
		for i in 6:
			var angle := TAU*i/6.0
			var radial := Vector3(sin(angle), 0, cos(angle))
			var label := SignBoard.make("BERTH %d" % (i+1), "plank", "", Color("ffe0a0"), 0.55)
			label.transform = Transform3D(Basis(Vector3.UP, angle+PI), radial*49.0+Vector3(cos(angle), 0, -sin(angle))*2.9+Vector3.UP*1.65)
			add_child(label)
	var pad: Vector3 = anchors.rocket_pad.origin
	art.round_part(pad + Vector3.UP * 0.04, 5.1, 0.08, BRASS)
	art.round_part(pad + Vector3.UP * 0.09, 4.65, 0.02, DARK)
	for i in 12:
		var at := pad + Vector3(sin(i * TAU / 12) * 4.85, 0.1, cos(i * TAU / 12) * 4.85)
		art.box(at, Vector3(0.4, 0.05, 0.4), GREEN, false, 1.6)
	_board(art, anchors.campaign_board)
	for i in 3:
		_stall(art, stall_at(i), PINK if i % 2 else GREEN)
	# Framed lantern trees replace the giant luminous cones on bare poles.
	for at: Vector3 in [Vector3(-33, 0, 19), Vector3(-10, 0, 35), Vector3(15, 0, 35), Vector3(39, 0, -3), Vector3(-40, 0, -4)]:
		art.round_part(at+Vector3.UP*0.13, 0.6, 0.26, DARK, true)
		art.box(at+Vector3.UP*1.55, Vector3(0.22, 3.1, 0.22), WOOD, true)
		for side: float in [-1.0, 1.0]:
			art.box(at+Vector3(side*0.45, 3.0, 0), Vector3(1.0, 0.12, 0.16), BRASS)
			art.box(at+Vector3(side*0.85, 2.87, 0), Vector3(0.08, 0.3, 0.08), DARK)
			art.hanging_lantern(at+Vector3(side*0.85, 2.15, 0))
		art.box(at+Vector3.UP*3.15, Vector3(0.35, 0.13, 0.35), BRASS)
	for i in 16:
		var angle := TAU * (i + 0.5) / 16
		art.lantern(Vector3(sin(angle), 0, cos(angle)) * 44, 4.6)
	art.finish()
	if not server:
		_hearth_fire()
		_signpost(Vector3(-3.8, 0, 15.5))
		for at: Vector3 in [Vector3(0, 5, -23), Vector3(-13, 5, 2), Vector3(25, 5, -15), Vector3(0, 6, 12)]:
			var light := OmniLight3D.new()
			light.position = at
			light.light_color = Color("ffce8e")
			light.light_energy = 1.5
			light.omni_range = 22
			light.shadow_enabled = false
			light.distance_fade_enabled = true
			light.distance_fade_begin = 150
			light.distance_fade_length = 60
			add_child(light)

func _facing(at: Vector3, toward: Vector3) -> Transform3D:
	return Transform3D(Basis.looking_at((toward - at).normalized(), Vector3.UP), at)

func _tavern(art: Brush) -> void:
	var bar := NexusBar.new()
	bar.name = "LanternBar"
	add_child(bar)
	bar.build(art.server_only)

func _board(art: Brush, at: Vector3) -> void:
	for side in [-1.0, 1.0]:
		art.box(at + Vector3(side * 1.9, 2, 0), Vector3(0.45, 4, 0.5), DARK, true)
	art.box(at + Vector3(0, 3.2, 0), Vector3(4.8, 3.1, 0.45), WOOD, true)
	for i in 4:
		art.box(at + Vector3(-1.6 + i * 1.05, 3.2 + (i % 2) * 0.3, 0.26), Vector3(0.8, 1.5, 0.04), Color("ffe4ad"))
	art.lantern(at + Vector3(3, 0, 0), 4.0)

## The market stalls on the deck (each with a shopkeeper behind it, SpaceWorld).
const STALL_SHOPS := ["general", "premium", "curio"]

static func stall_at(i: int) -> Vector3:
	return Vector3(18 + i * 9, 0, -12 - i * 3)

## A stall: counter, awning (its front is +Z, the keeper stands behind at -Z).
func _stall(art: Brush, at: Vector3, cloth: Color) -> void:
	art.box(at + Vector3.UP * 0.55, Vector3(6, 1.1, 2), WOOD, true)
	art.box(at + Vector3.UP * 1.13, Vector3(6.2, 0.08, 2.2), BRASS)
	for side in [-1.0, 1.0]:
		art.box(at + Vector3(side * 3, 2.6, -0.7), Vector3(0.25, 5.2, 0.25), DARK, true)
	for i in 8:
		art.box(at + Vector3(-2.8 + i * 0.8, 4.4, 0), Vector3(0.8, 0.16, 3.8), cloth if i % 2 else Color("ffe0ae"))
		art.box(at + Vector3(-2.8 + i * 0.8, 4, 1.8), Vector3(0.8, 0.8, 0.15), cloth)
	for i in 5:
		art.crystal(at + Vector3(-2 + i, 1.17, 0.3), 0.5 + i % 2 * 0.3, GREEN if i % 2 else PINK)

## The island of stone the Nexus is built on, tapering to a crystal tip.
const ROCK_DEPTH := 96.0
const ROCK_RADIUS := 56.0
const STONE_DARK := Color("4e4250")
const MOSS := Color("4f7a4a")
const CRYSTAL_GREEN := Color("39d983")
const CRYSTAL_PINK := Color("e05fb0")

static func rock_radius_at(y: float) -> float:
	if y>-1.0 or y< -ROCK_DEPTH: return 0.0
	return ROCK_RADIUS*pow(1.0+y/ROCK_DEPTH, 0.85)

## Voxel size of the floating rock (metres per block).
const VOXEL := 2.0

## The voxel island under the deck: block-stepped stone layers tapering to a
## crystal tip, moss on the lip, glowing ore and crystal growths built from
## blocks, roots and lantern chains hanging below. Only exposed faces are meshed.
func _floating_rock() -> void:
	var holder := Node3D.new()
	holder.name = "FloatingRock"
	add_child(holder)
	var noise := FastNoiseLite.new()
	noise.seed = 4471
	noise.frequency = 0.08
	var ore := FastNoiseLite.new()
	ore.seed = 913
	ore.frequency = 0.21
	var cells := {}  # Vector3i -> Color (alpha = glow)
	var top := -1
	var bottom := -int(ROCK_DEPTH/VOXEL)
	var reach := int(ROCK_RADIUS/VOXEL)+2
	for y in range(bottom, top+1):
		var r := rock_radius_at(y*VOXEL)/VOXEL
		if r<0.6: continue
		for x in range(-reach, reach+1):
			for z in range(-reach, reach+1):
				var wobble := noise.get_noise_3d(x, y*0.6, z)*3.2
				if Vector2(x, z).length()>r+wobble: continue
				var depth := float(-y)/(ROCK_DEPTH/VOXEL)
				var color := STONE.lerp(STONE_DARK, depth).lightened(noise.get_noise_3d(x*3.0, y*3.0, z*3.0)*0.08)
				if y==top: color = MOSS.lightened(absf(noise.get_noise_2d(x*4.0, z*4.0))*0.18)
				elif y==top-1 and Vector2(x, z).length()>r-2.5: color = MOSS.darkened(0.15)
				# Warm and cool bands in the stone, glowing ore seams.
				if posmod(y, 5)==0: color = color.lerp(Color("7a5a6e"), 0.35)
				var glint := ore.get_noise_3d(x, y, z)
				if glint>0.55 and y<top-1: color = Color(CRYSTAL_GREEN if glint>0.62 else CRYSTAL_PINK, 0.55)
				else: color.a = 0.0
				cells[Vector3i(x, y, z)] = color
	# Crystal growths: diagonal block spikes out of the slopes and the tip.
	var rng := RandomNumberGenerator.new()
	rng.seed = 4472
	for i in 34:
		var y := rng.randi_range(bottom+4, top-4)
		var angle := rng.randf()*TAU
		var out := Vector3(sin(angle), 0, cos(angle))
		var start := out*(rock_radius_at(y*VOXEL)/VOXEL-0.5)+Vector3(0, y, 0)
		var length := rng.randi_range(3, 7)
		var tint := Color(CRYSTAL_GREEN if i % 3 else CRYSTAL_PINK, 0.6)
		for k in length:
			var at := start+out*k*0.8+Vector3.DOWN*k*0.7
			cells[Vector3i(roundi(at.x), roundi(at.y), roundi(at.z))] = tint
	# The tip: a hanging cluster of crystal points, widest where it meets the stone.
	for spike in 7:
		var lean := Vector3(cos(spike*0.9), 0, sin(spike*0.9))*(0.0 if spike==0 else 0.45)
		var length := 12 if spike==0 else rng.randi_range(5, 8)
		for k in length:
			var width := maxi(0, 1-k/4) if spike==0 else 0
			var at := Vector3(0, bottom-k, 0)+lean*k
			for dx in range(-width, width+1):
				for dz in range(-width, width+1):
					cells[Vector3i(roundi(at.x)+dx, roundi(at.y), roundi(at.z)+dz)] = Color(CRYSTAL_GREEN if (spike+k/3) % 2==0 else CRYSTAL_PINK, 0.65)
	_mesh_voxels(holder, cells)
	var art := Brush.new(holder, false)
	# Roots and lantern chains hang from under the lip.
	for i in 30:
		var angle := TAU*(i+0.5)/30
		var out := Vector3(sin(angle), 0, cos(angle))
		var drop := rng.randf_range(10.0, 28.0)
		var anchor := out*(ROCK_RADIUS-rng.randf_range(4.0, 9.0))+Vector3(0, -4.0, 0)
		if i % 2==0:
			art.box(anchor+Vector3.DOWN*drop*0.5, Vector3(0.6, drop, 0.6), Color("5b4636"))
			art.box(anchor+Vector3.DOWN*drop, Vector3.ONE*1.4, Color("ffd28b"), false, 2.8)
		else:
			for k in 4: art.box(anchor+Vector3.DOWN*(k*drop/4.0+2.0), Vector3.ONE*0.7, Color("ffe6a8") if k % 2 else PINK, false, 2.4)
	art.finish()
	for light: Array in [[Vector3(0, -ROCK_DEPTH+2.0, 0), Color("6dffa4"), 60.0, 3.0], [Vector3(0, -40, 0), Color("ffc27a"), 90.0, 1.6]]:
		var omni := OmniLight3D.new()
		omni.position = light[0]
		omni.light_color = light[1]
		omni.omni_range = light[2]
		omni.light_energy = light[3]
		omni.shadow_enabled = false
		holder.add_child(omni)

const FACE_DIRS: Array[Vector3i] = [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 1, 0), Vector3i(0, -1, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]

## One mesh of the exposed block faces; colour alpha is glow.
func _mesh_voxels(parent: Node3D, cells: Dictionary) -> void:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	for cell: Vector3i in cells:
		var color: Color = cells[cell]
		var center := Vector3(cell)*VOXEL
		for d in FACE_DIRS:
			if cells.has(cell+d): continue
			var n := Vector3(d)
			var u := Vector3(n.y, n.z, n.x)
			var v := n.cross(u)
			var c := center+n*VOXEL*0.5
			var h := VOXEL*0.5
			var a := c-u*h-v*h
			var b := c+u*h-v*h
			var e := c+u*h+v*h
			var f := c-u*h+v*h
			# Shade faces a little by direction for the voxel look.
			var tone := Color(color.r, color.g, color.b, color.a)
			if d.y<0: tone = Color(color.darkened(0.3), color.a)
			elif d.y==0: tone = Color(color.darkened(0.12 if d.x!=0 else 0.06), color.a)
			for p in [a, e, b, a, f, e]:
				verts.append(p)
				normals.append(n)
				colors.append(tone)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var node := MeshInstance3D.new()
	node.name = "VoxelRock"
	node.mesh = mesh
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/voxel_glow.gdshader")
	node.material_override = mat
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)

const HEARTH := Vector3(0, 0, -2)
const STONE := Color("6a5660")
const RUG := Color("2f5a4a")
const RUG_ROSE := Color("7a3a5c")

## The cosy heart of the deck: a green-fire hearth ringed by benches, rugs that
## zone the floor, market clutter and strings of fairy lights. Floor layers stack
## 1-2 cm apart (planks top at 0.02) so no two faces share a plane.
func _plaza(art: Brush, server: bool) -> void:
	# Zoned floors: a brass-rimmed hearth circle, runners to the arrival gangway
	# and the inn, a teal carpet under the command table and a rose market floor.
	art.round_part(HEARTH + Vector3.UP * 0.035, 9.4, 0.03, BRASS)
	art.round_part(HEARTH + Vector3.UP * 0.05, 9.0, 0.03, Color("6e4630"))
	for i in 16:
		var angle := TAU * i / 16.0
		var frame := Transform3D(Basis(Vector3.UP, angle), HEARTH + Vector3(sin(angle), 0.075, cos(angle)) * Vector3(7.4, 1, 7.4))
		art.part("box", frame, Vector3(0.5, 0.02, 2.2), GREEN if i % 2 else PINK, false, 0.5)
	for run: Array in [[Vector3(0, 0, 21), Vector3(5.2, 0, 22)], [Vector3(0, 0, -15.5), Vector3(5.2, 0, 8)]]:
		var at: Vector3 = run[0]
		var size: Vector3 = run[1]
		art.box(at + Vector3.UP * 0.035, size + Vector3(0.6, 0.03, 0), RUG_ROSE)
		art.box(at + Vector3.UP * 0.05, size + Vector3(-0.4, 0.03, 0), RUG)
		for k in int(size.z / 2.0):
			art.box(at + Vector3(0, 0.07, -size.z * 0.5 + 1.0 + k * 2.0), Vector3(size.x - 1.6, 0.012, 0.18), BRASS)
	# One layer higher than the hearth circle, which it overlaps at its edge.
	art.round_part(anchors.command_table + Vector3.UP * 0.085, 3.3, 0.03, BRASS)
	art.round_part(anchors.command_table + Vector3.UP * 0.1, 3.0, 0.03, Color("244c55"))
	art.box(Vector3(27, 0.035, -15), Vector3(28, 0.03, 13), BRASS)
	art.box(Vector3(27, 0.05, -15), Vector3(27.2, 0.03, 12.2), Color("8a4c62"))
	# Arrival compass rose under the spawn point, laid on top of the runner.
	var spawn: Vector3 = anchors.spawn
	art.round_part(spawn + Vector3.UP * 0.085, 2.7, 0.03, BRASS)
	art.round_part(spawn + Vector3.UP * 0.1, 2.4, 0.03, DARK)
	for i in 8:
		var long := i % 2 == 0
		var frame := Transform3D(Basis(Vector3.UP, TAU * i / 8.0), spawn + Vector3.UP * 0.125)
		art.part("box", frame.translated_local(Vector3(0, 0, 1.0 if long else 0.7)), Vector3(0.32, 0.02, 2.0 if long else 1.3), GREEN if long else BRASS, false, 0.8 if long else 0.0)
	# The hearth: stone ring, ember bed and logs; the fire itself is a shader mesh.
	art.round_part(HEARTH + Vector3.UP * 0.45, 2.7, 0.9, STONE, true)
	art.round_part(HEARTH + Vector3.UP * 0.92, 2.25, 0.06, Color("1d2a24"), false, 0.6)
	for i in 10:
		var angle := TAU * i / 10.0
		art.box(HEARTH + Vector3(sin(angle) * 2.5, 0.95, cos(angle) * 2.5), Vector3(0.9, 0.2, 0.9), STONE.lightened(0.12 * (i % 2)))
	for i in 3:
		var frame := Transform3D(Basis(Vector3.UP, i * PI / 3.0), HEARTH + Vector3.UP * 1.1)
		art.part("box", frame, Vector3(0.38, 0.32, 3.0), Color("4a2e21"))
	for i in 6:
		var angle := TAU * (i + 0.5) / 6.0
		art.crystal(HEARTH + Vector3(sin(angle) * 2.9, 0.3, cos(angle) * 2.9), 1.2 + (i % 2) * 0.5, GREEN if i % 3 else PINK)
	# Curved benches around the fire; gaps face the spawn (+Z) and the inn (-Z).
	for i in 12:
		var angle := TAU * (i + 0.5) / 12.0
		if absf(sin(angle)) < 0.3: continue
		var frame := Transform3D(Basis(Vector3.UP, angle), HEARTH + Vector3(sin(angle), 0, cos(angle)) * 5.4)
		art.part("box", frame.translated_local(Vector3(0, 0.45, 0)), Vector3(2.7, 0.22, 0.9), WOOD, true)
		art.part("box", frame.translated_local(Vector3(0, 0.95, 0.45)), Vector3(2.7, 0.8, 0.16), WOOD.darkened(0.15), true)
		for side in [-1.1, 1.1]:
			art.part("box", frame.translated_local(Vector3(side, 0.18, 0)), Vector3(0.2, 0.36, 0.7), DARK)
	# Market clutter: barrels, crates, planters and little crystal trees.
	for at: Vector3 in [Vector3(10.5, 0, -5), Vector3(11.6, 0, -3.8), Vector3(10.2, 0, -3.3), Vector3(-30, 0, 4), Vector3(-31, 0, 5.3), Vector3(14, 0, -21)]:
		art.round_part(at + Vector3.UP * 0.65, 0.55, 1.3, Color("7a4a2c"), true)
		for band in [0.25, 1.05]:
			art.round_part(at + Vector3.UP * band, 0.58, 0.1, BRASS)
	for crate: Array in [[Vector3(-16, 0, -6), 1.2], [Vector3(-17.4, 0, -5.4), 1.0], [Vector3(-16.5, 1.2, -5.9), 0.8], [Vector3(41, 0, -10), 1.2], [Vector3(40, 0, -8.6), 0.9]]:
		var at: Vector3 = crate[0]
		var size: float = crate[1]
		art.box(at + Vector3.UP * size * 0.5, Vector3.ONE * size, Color("a0703f"), true)
		art.box(at + Vector3.UP * size * 0.5, Vector3(size + 0.04, size * 0.18, size + 0.04), DARK)
	for at: Vector3 in [Vector3(6.5, 0, 17.5), Vector3(-6.5, 0, 17.5), Vector3(13, 0, 9), Vector3(-7.5, 0, 24), Vector3(7.5, 0, 26), Vector3(19, 0, 4), Vector3(-22, 0, 15)]:
		art.box(at + Vector3.UP * 0.4, Vector3(2.2, 0.8, 1.0), WOOD.darkened(0.1), true)
		if server: continue
		for j in 5:
			var bloom := at + Vector3(-0.8 + j * 0.4, 0.95 + (j % 2) * 0.15, (j % 3 - 1) * 0.2)
			art.part("sphere", Transform3D(Basis.IDENTITY, bloom), Vector3.ONE * (0.42 + (j % 2) * 0.12), PINK if j % 2 else Color("ffe08f"), false, 0.5)
			art.part("sphere", Transform3D(Basis.IDENTITY, bloom + Vector3(0.1, -0.2, 0.25)), Vector3.ONE * 0.36, Color("5fae6e"))
	for at: Vector3 in [Vector3(8.5, 0, -12), Vector3(-8.5, 0, -12), Vector3(-19, 0, -2), Vector3(19, 0, 11)]:
		art.round_part(at+Vector3.UP*0.14, 0.55, 0.28, STONE, true)
		art.lantern(at, 4.0)
		for j in 4:
			var angle := j*PI*0.5
			art.box(at+Vector3(sin(angle)*0.37, 0.36, cos(angle)*0.37), Vector3(0.28, 0.24, 0.28), Color("5b805c").lightened((j%2)*0.06))
	# Lantern posts around the plaza with fairy lights sagging between them.
	# A ring around the hearth, pulled in on the west to clear the command table.
	var posts: Array[Vector3] = [Vector3(4.8, 0, 9.5), Vector3(11.5, 0, 2.8), Vector3(11.5, 0, -6.8), Vector3(4.8, 0, -13.5),
		Vector3(-4.8, 0, -13.5), Vector3(-11.5, 0, -6.8), Vector3(-8, 0, 6.5), Vector3(-4.8, 0, 9.5)]
	for at in posts: art.lantern(at, 4.2)
	if server: return
	for i in posts.size():
		var a := posts[i] + Vector3.UP * 2.94
		var b := posts[(i + 1) % posts.size()] + Vector3.UP * 2.94
		for k in range(1, 12):
			var t := k / 12.0
			var at := a.lerp(b, t) + Vector3.DOWN * sin(t * PI) * 1.3
			art.part("sphere", Transform3D(Basis.IDENTITY, at), Vector3.ONE * 0.2, [Color("ffd28b"), GREEN, PINK][k % 3], false, 2.6)

func _hearth_fire() -> void:
	var fire := ShaderMaterial.new()
	fire.shader = preload("res://shaders/space_magic.gdshader")
	fire.set_shader_parameter("fire_color", Color("3dd977"))
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.5
	cone.height = 1.0
	cone.radial_segments = 7
	for flame: Array in [[Vector3(0, 1.9, 0), Vector3(1.6, 2.2, 1.6)], [Vector3(0.6, 1.6, 0.3), Vector3(0.9, 1.5, 0.9)], [Vector3(-0.5, 1.55, -0.4), Vector3(1.0, 1.4, 1.0)], [Vector3(-0.2, 1.5, 0.7), Vector3(0.7, 1.1, 0.7)]]:
		var mesh := MeshInstance3D.new()
		mesh.mesh = cone
		mesh.material_override = fire
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mesh.position = HEARTH + (flame[0] as Vector3)
		mesh.scale = flame[1]
		add_child(mesh)
	var glow := OmniLight3D.new()
	glow.position = HEARTH + Vector3.UP * 2.6
	glow.light_color = Color("6dffa4")
	glow.light_energy = 2.4
	glow.omni_range = 13.0
	glow.shadow_enabled = false
	add_child(glow)

## Hand-painted arrows pointing to the places a new arrival looks for.
func _signpost(at: Vector3) -> void:
	var art := Brush.new(self, false)
	art.box(at + Vector3.UP * 2.0, Vector3(0.3, 4.0, 0.3), Color("6b4a32"))
	art.box(at + Vector3.UP * 4.1, Vector3(0.5, 0.25, 0.5), BRASS)
	var targets := [["Tavern Inn", Vector3(0, 0, -30), 3.7], ["Shipwright", anchors.command_table, 2.9], ["Surface shuttle", anchors.rocket_pad.origin, 2.1], ["Berths", Vector3(0, 0, 54), 1.3]]
	for entry: Array in targets:
		var dir: Vector3 = ((entry[1] as Vector3) - at) * Vector3(1, 0, 1)
		# Board along local X toward the target, thin along Z. The label sits at the tip so
		# the overhead camera reads each name beside its own arrow, not stacked on the post.
		var along := dir.normalized()
		var frame := Transform3D(Basis(along, Vector3.UP, along.cross(Vector3.UP)), at + Vector3.UP * float(entry[2]))
		art.part("box", frame.translated_local(Vector3(1.05, 0, 0)), Vector3(2.1, 0.5, 0.12), Color("e8c48a"))
		art.part("box", frame.translated_local(Vector3(2.1, 0, 0)).rotated_local(Vector3.BACK, PI * 0.25), Vector3(0.36, 0.36, 0.12), Color("e8c48a"))
		# The name painted on both faces of its arrow.
		var words := str(entry[0])
		for k in 2:
			var paint := SignBoard.make(words, "paint", "", Color("4a3024"), minf(0.75, 1.85/(words.length()*6.0*SignBoard.PX)))
			paint.transform = frame*Transform3D(Basis(Vector3.UP, k*PI), Vector3(1.05, 0, 0.065 if k==0 else -0.065))
			add_child(paint)
	art.finish()
