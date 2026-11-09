class_name ShipHull
extends Node3D
## Timber sky-galleon facing -Z, built around the walk-in room so its windows
## are real openings. All anchors use the builder's local frame.

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
			node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if group.glow>0.0 else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			root.add_child(node)
		_groups.clear()

static func content(parent: Node3D, previous: Node3D) -> Node3D:
	if is_instance_valid(previous): previous.free()
	var node := Node3D.new()
	node.name = "Art"
	parent.add_child(node)
	return node

## The walk-in room (ShipInterior) sits inside this hull at this offset, so
## its windows line up with real openings: the bridge glazing and portholes.
const INTERIOR_OFFSET := Vector3(0, -1.5, 0)
const DECK_Y := 3.3
const KEEL_Y := -6.2
const BOW_Z := -29.0
const STERN_Z := 22.0
## Interior window openings in hull space: [centre, half size].
const BRIDGE_WINDOW := [Vector3(0, 1.2, -17.66), Vector2(5.3, 1.0)]
const PORTHOLES: Array[float] = [-12.5, -7.5, 3.5, 11.5]
const PORTHOLE_Y := 0.8

## Half beam at deck height along the keel.
static func beam(z: float) -> float:
	if z< -18.0: return 9.2*clampf((z-BOW_Z)/(-18.0-BOW_Z), 0.0, 1.0)
	if z>14.0: return lerpf(9.2, 6.8, clampf((z-14.0)/(STERN_Z-14.0), 0.0, 1.0))
	return 9.2

## The hull as a solid for ropes (SpaceTraversal): how far `p` (hull space)
## is inside it (> 0 inside) and the way out. The sides taper toward the keel.
static func inside(p: Vector3) -> Array:
	if p.z<BOW_Z or p.z>STERN_Z or p.y>DECK_Y or p.y<KEEL_Y: return [-1.0, Vector3.ZERO]
	var depth_frac := clampf((DECK_Y-p.y)/(DECK_Y-KEEL_Y), 0.0, 1.0)
	var half := beam(p.z)*lerpf(1.0, 0.45, depth_frac)
	var side := half-absf(p.x)
	if side<=0.0: return [-1.0, Vector3.ZERO]
	var top := DECK_Y-p.y
	var bottom := p.y-KEEL_Y
	var bow := p.z-BOW_Z
	var stern := STERN_Z-p.z
	var best := side
	var out := Vector3(signf(p.x) if p.x!=0.0 else 1.0, 0, 0)
	for pair: Array in [[top, Vector3.UP], [bottom, Vector3.DOWN], [bow, Vector3.FORWARD], [stern, Vector3.BACK]]:
		if float(pair[0])<best:
			best = pair[0]
			out = pair[1]
	return [best, out]

## The point on the hull's surface nearest `p` (hull space): where a line clips on.
static func surface_point(p: Vector3) -> Vector3:
	var q := Vector3(p.x, clampf(p.y, KEEL_Y, DECK_Y), clampf(p.z, BOW_Z+0.5, STERN_Z-0.5))
	var depth_frac := clampf((DECK_Y-q.y)/(DECK_Y-KEEL_Y), 0.0, 1.0)
	var half := beam(q.z)*lerpf(1.0, 0.45, depth_frac)
	q.x = clampf(q.x, -half, half)
	var hit: Array = inside(q)
	if float(hit[0])>0.0: q += (hit[1] as Vector3)*float(hit[0])
	return q

## Whether a strake (centre y, height, centre z) crosses a porthole opening.
func _porthole_at(y: float, height: float, z: float) -> bool:
	for pz in PORTHOLES:
		if absf(z-pz)<0.53+0.62 and absf(y-PORTHOLE_Y)<height*0.5+0.62: return true
	return false

func build(tint: Color) -> void:
	for child in get_children():
		if child.has_meta("ship_art_mount"): child.free()
	_root = content(self, _root)
	_flames.clear()
	var accent := Color(tint.r, tint.g, tint.b).lerp(ArtBatch.AMBER, 0.16)
	var art := ArtBatch.new(_root)
	# Strakes: a keel-deep timber belly, open where the room's portholes look out.
	for segment in range(int(BOW_Z)+1, int(STERN_Z)+1):
		var z := segment-0.5
		var w := beam(z)
		var deck := DECK_Y if z>=-18.0 else -0.3
		var keel := KEEL_Y+maxf(0.0, -18.0-z)*0.35+maxf(0.0, z-16.0)*0.5
		for row in 9:
			var t := float(row)/8.0
			var x := w*sqrt(t)
			var y := keel+t*(deck-keel)
			for side: float in [-1.0, 1.0]:
				var height := (deck-keel)/8.0+0.12
				if z>=-18.0 and _porthole_at(y, height, z): continue
				art.box(Vector3(side*maxf(x, 0.3), y, z), Vector3(0.5, height, 1.06), ArtBatch.WOOD.lightened(float((segment+row) % 4)*0.035))
		if z>=-18.0:
			# Deck boards and the brass gunwale.
			art.box(Vector3(0, deck, z), Vector3(w*2.0, 0.26, 1.04), Color("aa7448"))
			for side: float in [-1.0, 1.0]:
				art.box(Vector3(side*w, deck+0.55, z), Vector3(0.28, 0.9, 1.06), ArtBatch.BRASS if segment % 4==0 else ArtBatch.WOOD.darkened(0.1))
		else:
			art.box(Vector3(0, deck, z), Vector3(maxf(w*2.0, 0.6), 0.26, 1.04), Color("aa7448"))
		# Brass bands along the belly.
		for band: float in [0.62, 0.3]:
			var y := KEEL_Y+band*(deck-KEEL_Y)
			for side: float in [-1.0, 1.0]:
				if not (z>=-18.0 and _porthole_at(y, 0.2, z)):
					art.box(Vector3(side*(w*sqrt(band)+0.27), y, z), Vector3(0.12, 0.2, 1.08), ArtBatch.BRASS)
	# Each porthole: a timber frame closing the strake gap to a round-ish
	# opening, and a brass rim outside.
	for pz in PORTHOLES:
		for side: float in [-1.0, 1.0]:
			var x := side*beam(pz)*sqrt(clampf((PORTHOLE_Y-KEEL_Y)/(DECK_Y-KEEL_Y), 0.0, 1.0))
			for piece: Array in [[Vector3(0, 1.05, 0), Vector3(0.45, 0.9, 2.4)], [Vector3(0, -1.05, 0), Vector3(0.45, 0.9, 2.4)],
					[Vector3(0, 0, 1.05), Vector3(0.45, 1.3, 0.9)], [Vector3(0, 0, -1.05), Vector3(0.45, 1.3, 0.9)]]:
				art.box(Vector3(x, PORTHOLE_Y, pz)+(piece[0] as Vector3), piece[1], ArtBatch.WOOD.darkened(0.12))
			art.part("ring", Vector3(x+side*0.25, PORTHOLE_Y, pz), Vector3.ONE*1.6, ArtBatch.BRASS, 0, Basis(Vector3.FORWARD, PI*0.5))
	# Bridge front: a bulkhead with the great window open, framed like inside.
	var window: Vector3 = BRIDGE_WINDOW[0]
	var half: Vector2 = BRIDGE_WINDOW[1]
	for x in range(-9, 10):
		for y in range(-1, 4):
			var at := Vector3(x, y+0.2, -18.1)
			if absf(at.x)<half.x+0.2 and absf(at.y-window.y)<half.y+0.15: continue
			if absf(at.x)>beam(-18.0)*sqrt(clampf((at.y-KEEL_Y)/(DECK_Y-KEEL_Y), 0.0, 1.0))+0.2: continue
			art.box(at, Vector3(1.02, 1.02, 0.5), ArtBatch.WOOD.darkened(0.08))
	for x: float in [-5.45, -2.75, 0.0, 2.75, 5.45]: art.box(Vector3(x, window.y, -18.25), Vector3(0.18, 2.3, 0.2), ArtBatch.BRASS)
	for y: float in [window.y-1.08, window.y+1.08]: art.box(Vector3(0, y, -18.25), Vector3(11.2, 0.18, 0.2), ArtBatch.BRASS)
	# Wheelhouse dome above the bridge, tinted roof tiles.
	for tier in 4:
		art.box(Vector3(0, DECK_Y+0.5+tier*0.42, -15.0), Vector3(9.0-tier*1.8, 0.42, 6.0-tier*1.0), accent.darkened(tier*0.05))
	# The airlock's outer door on the port side, by the room's inner door.
	var lock := Vector3(-beam(-10.0)*sqrt(clampf((-0.5-KEEL_Y)/(DECK_Y-KEEL_Y), 0.0, 1.0))-0.3, -0.5, -10.0)
	art.part("ring", lock, Vector3.ONE*2.8, ArtBatch.BRASS, 0, Basis(Vector3.FORWARD, PI*0.5))
	art.box(lock+Vector3(-0.1, 0, 0), Vector3(0.2, 2.2, 1.7), ArtBatch.DARK)
	art.box(lock+Vector3(-0.25, 0.4, 0), Vector3(0.1, 0.25, 0.25), ArtBatch.GREEN, 2.0)
	# Prow: bowsprit and a glowing crystal figurehead the pilot sees ahead.
	art.beam(Vector3(0, -0.2, BOW_Z+1.0), Vector3(0, 2.6, BOW_Z-6.0), 0.4, ArtBatch.BRASS)
	art.crystal(Vector3(0, 1.0, BOW_Z-0.6), Vector3(1.6, 3.2, 1.6), ArtBatch.GREEN)
	art.crystal(Vector3(0, 2.8, BOW_Z-5.0), Vector3(0.7, 1.4, 0.7), ArtBatch.PINK)
	for side: float in [-1.0, 1.0]:
		for k in 5:
			art.lantern(Vector3(side*beam(-24.0+k*1.2)*0.9, 0.5, -24.0+k*1.2))
	# Stern castle with warm windows and a tinted roof.
	for tier in 5:
		var w := 6.6-tier*0.5
		art.box(Vector3(0, DECK_Y+0.6+tier*0.9, 17.5), Vector3(w*2.0, 0.92, 8.0-tier*0.6), ArtBatch.WOOD.lightened(tier*0.03))
	for x: float in [-4.0, -1.4, 1.4, 4.0]:
		art.box(Vector3(x, DECK_Y+2.2, 13.45), Vector3(1.2, 1.4, 0.1), ArtBatch.AMBER, 1.6)
		art.box(Vector3(x, DECK_Y+2.2, 21.3), Vector3(1.2, 1.4, 0.1), ArtBatch.AMBER, 1.6)
	for tier in 3:
		art.box(Vector3(0, DECK_Y+5.2+tier*0.35, 17.5), Vector3(11.0-tier*2.4, 0.35, 7.6-tier*1.6), accent.darkened(tier*0.04))
	# Masts with glowing membrane sails and crystal crow's nests.
	for mast: Array in [[-4.0, 19.0, 8.0], [-12.0, 13.0, 5.5], [10.0, 11.0, 4.5]]:
		var mz: float = mast[0]
		var tall: float = mast[1]
		var span: float = mast[2]
		art.box(Vector3(0, DECK_Y+tall*0.5, mz), Vector3(0.7, tall, 0.7), Color("6d4839"))
		art.box(Vector3(0, DECK_Y+tall*0.82, mz), Vector3(span*2.0, 0.35, 0.35), Color("6d4839"))
		art.box(Vector3(0, DECK_Y+tall*0.42, mz), Vector3(span*2.2, 0.35, 0.35), Color("6d4839"))
		for strip in 6:
			var y := DECK_Y+tall*0.45+strip*(tall*0.36/6.0)
			var belly := sin(float(strip)/5.0*PI)*0.9
			art.box(Vector3(0, y, mz+belly), Vector3(span*(2.0-strip*0.06), tall*0.36/6.0+0.04, 0.16), accent.lerp(Color.WHITE, 0.25) if strip % 2 else accent, 0.35)
		art.part("sphere", Vector3(0, DECK_Y+tall+0.4, mz), Vector3(1.6, 1.0, 1.6), ArtBatch.BRASS)
		art.crystal(Vector3(0, DECK_Y+tall+1.5, mz), Vector3(0.6, 1.6, 0.6), ArtBatch.GREEN if mz<0 else ArtBatch.PINK)
	# Wing fins with lanterns along their edge.
	for side: float in [-1.0, 1.0]:
		for strip in 9:
			var x := side*(9.4+strip*0.85)
			art.box(Vector3(x, 1.0-strip*0.16, 3.0+strip*0.2), Vector3(0.88, 0.18, 9.0-strip*0.75), accent if strip % 2 else ArtBatch.WOOD, 0, Basis(Vector3.FORWARD, side*0.12))
		art.beam(Vector3(side*9.2, 0.8, -1.0), Vector3(side*16.5, -0.4, 4.0), 0.22, ArtBatch.BRASS)
		art.beam(Vector3(side*9.2, 0.8, 8.0), Vector3(side*16.5, -0.4, 6.0), 0.22, ArtBatch.BRASS)
		art.lantern(Vector3(side*16.6, -0.1, 5.0))
		for z: float in [-14.0, -2.0, 8.0]:
			art.lantern(Vector3(side*(beam(z)+0.2), DECK_Y+1.4, z))
	# Under the keel: brass bands and soft crystal lights.
	for z in range(-16, 16, 4):
		art.box(Vector3(0, KEEL_Y-0.1, z), Vector3(2.2, 0.3, 0.5), ArtBatch.BRASS)
		art.crystal(Vector3(0, KEEL_Y-0.5, z+2), Vector3(0.6, 1.0, 0.6), ArtBatch.GREEN if z % 8==0 else ArtBatch.PINK)
	# Folded boarding ramp at the hatch on the starboard side.
	art.box(Vector3(9.8, -3.6, 6.0), Vector3(3.6, 0.22, 2.4), ArtBatch.WOOD, 0, Basis(Vector3.FORWARD, -0.75))
	var exhausts: Array[Vector3] = []
	_fire = ShaderMaterial.new()
	_fire.shader = preload("res://shaders/space_magic.gdshader")
	for engine: Vector3 in [Vector3(-4.2, -0.6, STERN_Z), Vector3(0, -2.2, STERN_Z+0.6), Vector3(4.2, -0.6, STERN_Z)]:
		art.part("cylinder", engine, Vector3(2.6, 3.6, 2.6), ArtBatch.DARK, 0, Basis(Vector3.RIGHT, PI*0.5))
		art.part("ring", engine+Vector3(0, 0, 1.6), Vector3.ONE*2.9, ArtBatch.BRASS, 0, Basis(Vector3.RIGHT, PI*0.5))
		art.part("sphere", engine+Vector3(0, 0, 1.75), Vector3(1.9, 1.9, 0.14), ArtBatch.GREEN, 2.0)
		var point := engine+Vector3(0, 0, 1.9)
		exhausts.append(point)
		var flame := Node3D.new()
		flame.position = point
		_root.add_child(flame)
		var cone := MeshInstance3D.new()
		cone.mesh = ArtBatch.mesh("crystal")
		cone.material_override = _fire
		cone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		cone.rotation.x = PI*0.5
		cone.position.z = 0.5
		cone.scale = Vector3.ONE*1.4
		flame.add_child(cone)
		_flames.append(flame)
	art.finish()
	_turret("Turret_top", Vector3(0, DECK_Y+2.0, -15.0), accent)
	_turret("Turret_left", Vector3(-9.7, 2.2, -2.0), accent)
	_turret("Turret_right", Vector3(9.7, 2.2, -2.0), accent)
	anchors = {cockpit = Transform3D(Basis.IDENTITY, window+Vector3(0, 0.2, 1.4)),
		chase = Vector3(0, 17, 56), engines = exhausts,
		hatch = Transform3D(Basis(Vector3.UP, -PI*0.5), Vector3(11.5, -5.6, 6.0)), length = 52.0, radius = 30.0}
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
