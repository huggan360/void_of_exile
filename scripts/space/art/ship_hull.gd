class_name ShipHull
extends Node3D
## Timber galleon facing -Z. All anchors use the builder's local frame.

var anchors := {}
var _root: Node3D
var _flames: Array[Node3D] = []
var _fire: ShaderMaterial

## Shared primitive caches and per-object spatial batches.
class ArtBatch extends RefCounted:
	const WOOD := Color("895132")
	const DARK := Color("38272c")
	const BRASS := Color("d3a34e")
	const AMBER := Color("ffd38c")
	const GREEN := Color("77f5ad")
	const PINK := Color("ef96c2")
	static var _meshes: Dictionary = {}
	static var _materials: Dictionary = {}
	static var _heading_font: FontVariation
	var root: Node3D
	var server: bool
	var _groups := {}
	var _body: StaticBody3D

	func _init(parent: Node3D, server_only: bool = false) -> void:
		root = parent
		server = server_only

	static func mesh(kind: String) -> Mesh:
		if _meshes.has(kind): return _meshes[kind]
		var result: Mesh
		match kind:
			"sphere":
				var sphere := SphereMesh.new()
				sphere.radius = 0.5
				sphere.height = 1.0
				sphere.radial_segments = 16
				sphere.rings = 8
				result = sphere
			"cylinder", "cone", "crystal":
				var cylinder := CylinderMesh.new()
				cylinder.top_radius = 0.0 if kind != "cylinder" else 0.5
				cylinder.bottom_radius = 0.5
				cylinder.height = 1.0
				cylinder.radial_segments = 6 if kind == "crystal" else 16
				result = cylinder
			"ring":
				var ring := TorusMesh.new()
				ring.inner_radius = 0.36
				ring.outer_radius = 0.5
				ring.rings = 16
				ring.ring_segments = 6
				result = ring
			_:
				var cube := BoxMesh.new()
				cube.size = Vector3.ONE
				result = cube
		_meshes[kind] = result
		return result

	static func material(glow: float) -> ShaderMaterial:
		if not _materials.has(glow):
			var mat := ShaderMaterial.new()
			mat.shader = preload("res://shaders/space_art.gdshader")
			mat.set_shader_parameter("emission_strength", glow)
			_materials[glow] = mat
		return _materials[glow]

	static func heading_font() -> FontVariation:
		if not is_instance_valid(_heading_font):
			_heading_font = FontVariation.new()
			_heading_font.base_font = preload("res://fonts/BreeSerif.ttf")
			_heading_font.variation_embolden = 0.6
		return _heading_font

	func part(kind: String, at: Vector3, size: Vector3, color: Color, glow: float = 0.0, basis: Basis = Basis.IDENTITY) -> void:
		if server: return
		var key := kind + ":" + str(glow)
		if not _groups.has(key): _groups[key] = {kind = kind, glow = glow, frames = [], colors = []}
		var group: Dictionary = _groups[key]
		group.frames.append(Transform3D(basis.scaled_local(size), at))
		group.colors.append(color)

	func box(at: Vector3, size: Vector3, color: Color, glow: float = 0.0, basis: Basis = Basis.IDENTITY) -> void:
		part("box", at, size, color, glow, basis)

	func beam(a: Vector3, b: Vector3, width: float, color: Color, glow: float = 0.0) -> void:
		if server or a.is_equal_approx(b): return
		var up := (b - a).normalized()
		var ref := Vector3.FORWARD if absf(up.y) > 0.98 else Vector3.UP
		var right := up.cross(ref).normalized()
		part("box", (a + b) * 0.5, Vector3(width, a.distance_to(b), width), color, glow, Basis(right, up, right.cross(up)))

	func solid(at: Vector3, size: Vector3, basis: Basis = Basis.IDENTITY) -> void:
		var shape := BoxShape3D.new()
		shape.size = size
		collision(shape, Transform3D(basis, at))

	func collision(shape: Shape3D, frame: Transform3D) -> void:
		if not is_instance_valid(_body):
			_body = StaticBody3D.new()
			_body.name = "Terrain"
			_body.collision_layer = Player.TERRAIN_LAYER
			_body.collision_mask = 0
			root.add_child(_body)
		var node := CollisionShape3D.new()
		node.shape = shape
		node.transform = frame
		_body.add_child(node)

	func lantern(at: Vector3) -> void:
		box(at, Vector3(0.24, 0.37, 0.24), AMBER, 2.0)
		for y: float in [-0.23, 0.23]: box(at + Vector3.UP * y, Vector3(0.38, 0.09, 0.38), BRASS)
		for x: float in [-0.15, 0.15]:
			for z: float in [-0.15, 0.15]: box(at + Vector3(x, 0, z), Vector3(0.04, 0.42, 0.04), DARK)
		beam(at + Vector3.UP * 0.28, at + Vector3.UP * 0.58, 0.045, BRASS)

	func crystal(at: Vector3, size: Vector3, color: Color) -> void:
		part("crystal", at + Vector3.UP * size.y * 0.15, size * Vector3(1, 0.7, 1), color, 2.0)
		part("crystal", at - Vector3.UP * size.y * 0.35, size * Vector3(1, 0.3, 1), color.darkened(0.12), 2.0, Basis(Vector3.RIGHT, PI))

	func finish() -> void:
		if server: return
		for group: Dictionary in _groups.values():
			var batch := MultiMesh.new()
			batch.transform_format = MultiMesh.TRANSFORM_3D
			batch.use_colors = true
			batch.mesh = mesh(group.kind)
			batch.instance_count = group.frames.size()
			for i in batch.instance_count:
				batch.set_instance_transform(i, group.frames[i])
				batch.set_instance_color(i, group.colors[i])
			var node := MultiMeshInstance3D.new()
			node.name = "Batch_" + group.kind
			node.multimesh = batch
			node.material_override = material(group.glow)
			node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			root.add_child(node)
		_groups.clear()

static func content(parent: Node3D, previous: Node3D) -> Node3D:
	if is_instance_valid(previous): previous.free()
	var node := Node3D.new()
	node.name = "Art"
	parent.add_child(node)
	return node

func build(tint: Color) -> void:
	for child in get_children():
		if child.has_meta("ship_art_mount"): child.free()
	_root = content(self, _root)
	_flames.clear()
	var accent := Color(tint.r, tint.g, tint.b).lerp(ArtBatch.AMBER, 0.16)
	var art := ArtBatch.new(_root)
	# Overlapping strakes follow a narrow bow, a broad belly and a rounded stern.
	for segment in 28:
		var z := -13.75 + segment
		var width := 5.3 * pow(sin((float(segment) + 1.0) / 30.0 * PI), 0.55)
		for row in 7:
			var t := float(row) / 6.0
			var x := width * sqrt(t)
			var y := -2.65 + t * 4.2
			for side: float in [-1.0, 1.0]:
				art.box(Vector3(side * x, y, z), Vector3(0.42, 0.65, 1.07), ArtBatch.WOOD.lightened(float((segment + row) % 4) * 0.035))
		art.box(Vector3(0, 1.55, z), Vector3(width * 2.0, 0.24, 1.03), Color("aa7448"))
		for side: float in [-1.0, 1.0]:
			art.box(Vector3(side * width, 1.9, z), Vector3(0.23, 0.33, 1.08), ArtBatch.BRASS)
			if segment % 3 == 0:
				art.box(Vector3(side * (width + 0.12), 0.2, z), Vector3(0.24, 2.9, 0.18), ArtBatch.BRASS)
	for x: float in [-2.4, -1.2, 0, 1.2, 2.4]:
		art.box(Vector3(x, 1.7, 2), Vector3(0.055, 0.035, 17), ArtBatch.DARK)
	# Forward bridge, bowed amber glazing and a tiled, tinted roof.
	art.box(Vector3(0, 3.0, -8.4), Vector3(6.6, 2.9, 5.2), ArtBatch.WOOD)
	art.box(Vector3(0, 3.4, -11.04), Vector3(5.8, 1.7, 0.12), ArtBatch.AMBER, 1.4)
	for x: float in [-3, -1.5, 0, 1.5, 3]: art.box(Vector3(x, 3.4, -11.15), Vector3(0.16, 1.95, 0.18), ArtBatch.BRASS)
	for side: float in [-1.0, 1.0]:
		for z: float in [-9.5, -7.5]:
			art.part("ring", Vector3(side * 3.36, 3.2, z), Vector3.ONE * 1.25, ArtBatch.BRASS, 0, Basis(Vector3.FORWARD, PI * 0.5))
			art.part("sphere", Vector3(side * 3.35, 3.2, z), Vector3(0.12, 0.88, 0.88), ArtBatch.AMBER, 1.4)
	for tier in 4:
		art.box(Vector3(0, 4.55 + tier * 0.23, -8.4), Vector3(7.5 - tier * 1.1, 0.3, 6.1), accent.darkened(tier * 0.04))
	art.beam(Vector3(0, 1.6, -12), Vector3(0, 2.5, -15.8), 0.32, ArtBatch.BRASS)
	art.crystal(Vector3(0, 3.0, -15.4), Vector3(1.15, 2.0, 1.15), ArtBatch.PINK)
	# Small cloth fins read as sails from the chase camera.
	for side: float in [-1.0, 1.0]:
		for strip in 7:
			var x := side * (4.6 + strip * 0.63)
			art.box(Vector3(x, 1.65 + strip * 0.11, 4.3), Vector3(0.67, 0.16, 6.0 - strip * 0.58), accent, 0, Basis(Vector3.FORWARD, side * 0.17))
		art.beam(Vector3(side * 4, 1.4, 1.1), Vector3(side * 8.8, 2.5, 3.4), 0.17, ArtBatch.BRASS)
		art.beam(Vector3(side * 4, 1.4, 7.4), Vector3(side * 8.8, 2.5, 5.2), 0.17, ArtBatch.BRASS)
		for z: float in [-10, -4, 6, 10]:
			art.lantern(Vector3(side * 4.5, 2.8, z))
			art.crystal(Vector3(side * 4.4, 2.15, z + 0.65), Vector3(0.35, 0.7, 0.35), ArtBatch.GREEN)
	# Folded brass boarding ramp, with its foot matching the landing anchor.
	art.box(Vector3(5.7, -1.5, 5), Vector3(3.6, 0.2, 2.2), ArtBatch.WOOD, 0, Basis(Vector3.FORWARD, -0.85))
	art.beam(Vector3(4.5, 0.6, 3.8), Vector3(7, -2.1, 3.8), 0.12, ArtBatch.BRASS)
	var exhausts: Array[Vector3] = []
	_fire = ShaderMaterial.new()
	_fire.shader = preload("res://shaders/space_magic.gdshader")
	for x: float in [-3.1, 0, 3.1]:
		var at := Vector3(x, -0.2, 12.4)
		art.part("cylinder", at, Vector3(1.9, 3.2, 1.9), ArtBatch.DARK, 0, Basis(Vector3.RIGHT, PI * 0.5))
		art.part("ring", at + Vector3(0, 0, 1.4), Vector3.ONE * 2.15, ArtBatch.BRASS, 0, Basis(Vector3.RIGHT, PI * 0.5))
		art.part("sphere", at + Vector3(0, 0, 1.52), Vector3(1.35, 1.35, 0.12), ArtBatch.GREEN, 2.0)
		var point := at + Vector3(0, 0, 1.65)
		exhausts.append(point)
		var flame := Node3D.new()
		flame.position = point
		_root.add_child(flame)
		var cone := MeshInstance3D.new()
		cone.mesh = ArtBatch.mesh("crystal")
		cone.material_override = _fire
		cone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		cone.rotation.x = PI * 0.5
		cone.position.z = 0.5
		flame.add_child(cone)
		_flames.append(flame)
	art.finish()
	_turret("Turret_top", Vector3(0, 3.0, 0), accent)
	_turret("Turret_left", Vector3(-5.0, 0.4, -1.8), accent)
	_turret("Turret_right", Vector3(5.0, 0.4, -1.8), accent)
	anchors = {cockpit = Transform3D(Basis.IDENTITY, Vector3(0, 3.55, -11.35)),
		chase = Vector3(0, 12, 29), engines = exhausts,
		hatch = Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(7, -3, 5)), length = 32.0, radius = 30.0}
	set_engine(0.0)

func _turret(id: String, at: Vector3, accent: Color) -> void:
	var mount := Node3D.new()
	mount.name = id
	mount.position = at
	# Mounts are direct children for gameplay's stable node paths.
	add_child(mount)
	# Rebuild removes only the mounts owned by this builder.
	mount.set_meta("ship_art_mount", true)
	var base := ArtBatch.new(mount)
	base.part("cylinder", Vector3.ZERO, Vector3(1.9, 0.45, 1.9), ArtBatch.BRASS)
	base.finish()
	var yaw := Node3D.new()
	yaw.name = "Yaw"
	mount.add_child(yaw)
	var cap := ArtBatch.new(yaw)
	cap.part("sphere", Vector3(0, 0.55, 0), Vector3(1.7, 1.25, 1.7), accent)
	cap.box(Vector3(0, 0.8, 0.5), Vector3(1.4, 0.2, 0.4), ArtBatch.BRASS)
	cap.finish()
	var pitch := Node3D.new()
	pitch.name = "Pitch"
	pitch.position.y = 0.55
	yaw.add_child(pitch)
	var barrels := ArtBatch.new(pitch)
	for x: float in [-0.33, 0.33]:
		barrels.part("cylinder", Vector3(x, 0, -1.5), Vector3(0.32, 2.7, 0.32), ArtBatch.DARK, 0, Basis(Vector3.RIGHT, PI * 0.5))
		barrels.part("ring", Vector3(x, 0, -2.8), Vector3.ONE * 0.46, ArtBatch.BRASS, 0, Basis(Vector3.RIGHT, PI * 0.5))
	barrels.finish()
	var muzzle := Node3D.new()
	muzzle.name = "Muzzle"
	muzzle.position.z = -2.95
	pitch.add_child(muzzle)

## Idle retains a little fire; boost extends and brightens each exhaust.
func set_engine(strength: float) -> void:
	var power := clampf(strength, 0.0, 2.0)
	for flame in _flames:
		flame.scale = Vector3(1.1 + power * 0.23, 1.1 + power * 0.23, 0.9 + power * 3.0)
	if is_instance_valid(_fire): _fire.set_shader_parameter("strength", power)
