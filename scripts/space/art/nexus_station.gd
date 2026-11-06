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

	func lantern(at: Vector3, tall := 4.0) -> void:
		box(at + Vector3.UP * tall * 0.5, Vector3(0.22, tall, 0.22), Color("94683f"))
		box(at + Vector3.UP * tall, Vector3(0.85, 1.0, 0.85), Color("ffd28b"), false, 2.4)
		for offset in [-0.55, 0.55]:
			box(at + Vector3.UP * (tall + offset), Vector3(1.05, 0.14, 1.05), Color("b18b49"))

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
			instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
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
		npc_quartermaster = _facing(Vector3(-17, 0, 5), Vector3(-10, 0, 6)),
		npc_mechanic = _facing(Vector3(25, 0, 19), Vector3(31, 0, 17)),
		gangways = [],
	}
	var art := Brush.new(self, server)
	# The circular hull is continuous; planks sit flush with its collision top.
	art.round_part(Vector3(0, -1.1, 0), 51.5, 2.2, DARK, true)
	if not server:
		for row in range(-42, 43):
			var z := row * 1.2
			var half := sqrt(maxf(0, 51.2 * 51.2 - z * z))
			var count := maxi(1, ceili(half * 2 / 5.0))
			for column in count:
				var width := half * 2 / count
				art.box(Vector3(-half + (column + 0.5) * width, -0.08, z), Vector3(width - 0.035, 0.16, 1.15), WOOD.lightened(float((row + column * 3) % 5) * 0.025))
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
	# Brass observatory table and an unobstructed landing mark, without a rocket.
	var table: Vector3 = anchors.command_table
	art.round_part(table + Vector3.UP * 0.8, 0.6, 1.6, DARK, true)
	art.round_part(table + Vector3.UP * 1.75, 3.7, 0.35, WOOD, true)
	art.round_part(table + Vector3.UP * 1.95, 3.25, 0.05, Color("253f4c"), false, 0.3)
	if not server:
		for i in 22:
			var angle := i * 2.39996
			var at := table + Vector3(cos(angle), 0, sin(angle)) * sqrt(float(i) / 22.0) * 2.9
			art.box(at + Vector3.UP * 2.0, Vector3(0.13, 0.06, 0.13), GREEN if i % 3 else PINK, false, 2.4)
	var pad: Vector3 = anchors.rocket_pad.origin
	art.round_part(pad + Vector3.DOWN * 0.035, 5.1, 0.07, BRASS)
	art.round_part(pad + Vector3.UP * 0.015, 4.65, 0.025, DARK)
	for i in 12:
		var at := pad + Vector3(sin(i * TAU / 12), 0.04, cos(i * TAU / 12)) * 4.85
		art.box(at, Vector3(0.4, 0.05, 0.4), GREEN, false, 1.6)
	_board(art, anchors.campaign_board)
	for i in 3:
		_stall(art, Vector3(18 + i * 9, 0, -12 - i * 3), PINK if i % 2 else GREEN)
	for at: Vector3 in [Vector3(-33, 0, 19), Vector3(-10, 0, 35), Vector3(15, 0, 35), Vector3(39, 0, -3), Vector3(-40, 0, -4)]:
		art.round_part(at + Vector3.UP * 0.55, 2.6, 1.1, DARK, true)
		art.box(at + Vector3.UP * 3, Vector3(0.8, 5, 0.8), WOOD, true)
		for j in 7:
			var angle := j * 2.4
			art.crystal(at + Vector3(sin(angle) * 2.0, 4 + j % 3, cos(angle) * 2.0), 2.4, GREEN if j % 2 else PINK)
	for i in 16:
		var angle := TAU * (i + 0.5) / 16
		art.lantern(Vector3(sin(angle), 0, cos(angle)) * 44, 4.6)
	art.finish()
	if not server:
		for at: Vector3 in [Vector3(0, 5, -23), Vector3(-13, 5, 2), Vector3(25, 5, -15)]:
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
	# Roofless courtyard inn, open toward the arrival plaza (+Z).
	art.box(Vector3(0, 3.2, -35), Vector3(29, 6.4, 0.65), DARK, true)
	for side in [-1.0, 1.0]:
		art.box(Vector3(side * 14.5, 2.4, -27), Vector3(0.65, 4.8, 16), WOOD, true)
		for z in [-34, -27, -20]:
			art.box(Vector3(side * 14.5, 4.3, z), Vector3(0.9, 8.6, 0.9), DARK, true)
			art.lantern(Vector3(side * 13.4, 0, z), 4.3)
	art.box(Vector3(0, 7.5, -35), Vector3(30, 0.65, 0.9), BRASS)
	art.box(Vector3(-4, 1.2, -29), Vector3(15, 2.4, 1.8), WOOD, true)
	art.box(Vector3(-4, 2.5, -29), Vector3(16, 0.25, 2.3), BRASS)
	for i in 9:
		art.box(Vector3(-10 + i * 1.5, 3.3, -34.4), Vector3(0.5, 0.8 + (i % 3) * 0.3, 0.5), GREEN if i % 2 else PINK, false, 0.4)
	for at: Vector3 in [Vector3(-7, 0, -20), Vector3(5, 0, -21)]:
		art.round_part(at + Vector3.UP * 1.4, 2.1, 0.35, WOOD, true)
		art.round_part(at + Vector3.UP * 0.65, 0.4, 1.3, DARK, true)
		for side in [-1.0, 1.0]:
			art.box(at + Vector3(side * 3.1, 0.6, 0), Vector3(1.1, 1.2, 3.5), WOOD, true)
	art.box(Vector3(9, 0.55, -32), Vector3(5, 1.1, 3.4), Color("695864"), true)
	for side in [-1.0, 1.0]:
		art.box(Vector3(9 + side * 2, 2.6, -32.5), Vector3(0.8, 4.2, 2.7), DARK, true)
	art.box(Vector3(9, 4.7, -32.5), Vector3(5, 0.8, 2.7), BRASS, true)
	for i in 7:
		art.crystal(Vector3(7.5 + i * 0.5, 1.1, -32), 1.4 + sin(i * 3.0) * 0.6, GREEN)
	# Hanging cloth and window light read from the overhead camera.
	for i in 5:
		art.box(Vector3(-11 + i * 4.0, 5, -34.5), Vector3(2.3, 2.5, 0.2), PINK if i % 2 else GREEN)

func _board(art: Brush, at: Vector3) -> void:
	for side in [-1.0, 1.0]:
		art.box(at + Vector3(side * 1.9, 2, 0), Vector3(0.45, 4, 0.5), DARK, true)
	art.box(at + Vector3(0, 3.2, 0), Vector3(4.8, 3.1, 0.45), WOOD, true)
	for i in 4:
		art.box(at + Vector3(-1.6 + i * 1.05, 3.2 + (i % 2) * 0.3, 0.26), Vector3(0.8, 1.5, 0.04), Color("ffe4ad"))
	art.lantern(at + Vector3(3, 0, 0), 4.0)

func _stall(art: Brush, at: Vector3, cloth: Color) -> void:
	art.box(at + Vector3.UP * 1.05, Vector3(6, 2.1, 2), WOOD, true)
	for side in [-1.0, 1.0]:
		art.box(at + Vector3(side * 3, 2.6, -0.7), Vector3(0.25, 5.2, 0.25), DARK, true)
	for i in 8:
		art.box(at + Vector3(-2.8 + i * 0.8, 4.4, 0), Vector3(0.8, 0.16, 3.8), cloth if i % 2 else Color("ffe0ae"))
		art.box(at + Vector3(-2.8 + i * 0.8, 4, 1.8), Vector3(0.8, 0.8, 0.15), cloth)
	for i in 5:
		art.crystal(at + Vector3(-2 + i, 2.1, 0), 0.5 + i % 2 * 0.3, GREEN if i % 2 else PINK)
