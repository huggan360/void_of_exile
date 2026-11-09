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
## its windows line up with real openings: the bridge glazing, the windows
## either side of the helm and the portholes.
const INTERIOR_OFFSET := Vector3(0, -1.5, 0)
const DECK_Y := 3.3
const KEEL_Y := -6.2
const BOW_Z := -29.0
const STERN_Z := 22.0
## Forward of the bridge the foredeck sits low, so the helm sees over the bow.
const BRIDGE_Z := -18.0
const BOW_DECK_Y := -1.6
## Interior window openings in hull space: [centre, half size].
const BRIDGE_WINDOW := [Vector3(0, 0.55, -17.66), Vector2(7.3, 1.7)]
## [centre, half size (along z, along y)] on each side of the helm.
const SIDE_WINDOWS := [[Vector3(-7.66, 0.55, -15.6), Vector2(1.3, 1.2)], [Vector3(7.66, 0.55, -15.6), Vector2(1.3, 1.2)]]
const PORTHOLES: Array[float] = [-12.5, -7.5, 3.5, 11.5]
const PORTHOLE_Y := 0.05
## The hull is a hollow shell of these blocks; the main deck's top is DECK_TOP.
const VOXEL := 0.5
const DECK_TOP := DECK_Y+0.13
## Things standing on (or out of) the deck that the crew can't walk or fly
## through (hull space boxes: centre, half size): wheelhouse with the top
## cannon, the masts, the stern castle and the side cannons.
const SOLIDS := [[Vector3(0, 5.0, -15.0), Vector3(4.6, 1.7, 3.0)], [Vector3(0, 13.0, -4.0), Vector3(0.6, 9.6, 0.6)],
	[Vector3(0, 10.0, -12.0), Vector3(0.6, 6.6, 0.6)], [Vector3(0, 9.0, 10.0), Vector3(0.6, 5.6, 0.6)],
	[Vector3(0, 5.3, 17.25), Vector3(6.4, 2.0, 4.0)], [Vector3(-9.7, 2.9, -2.0), Vector3(1.5, 1.3, 1.5)],
	[Vector3(9.7, 2.9, -2.0), Vector3(1.5, 1.3, 1.5)]]

static var _shell: Array = []  # [centre, colour] of every visible hull block, shared by all ships

## Half beam at deck height along the keel.
static func beam(z: float) -> float:
	if z< -18.0: return 9.2*clampf((z-BOW_Z)/(-18.0-BOW_Z), 0.0, 1.0)
	if z>14.0: return lerpf(9.2, 6.8, clampf((z-14.0)/(STERN_Z-14.0), 0.0, 1.0))
	return 9.2

static func deck_at(z: float) -> float:
	return DECK_Y if z>=BRIDGE_Z else BOW_DECK_Y

static func keel_at(z: float) -> float:
	return KEEL_Y+maxf(0.0, -18.0-z)*0.35+maxf(0.0, z-16.0)*0.5

## Half width of the hull at height y over keel position z (sides taper down).
static func half_at(y: float, z: float) -> float:
	return beam(z)*lerpf(1.0, 0.45, clampf((DECK_Y-y)/(DECK_Y-KEEL_Y), 0.0, 1.0))

static func solid_at(p: Vector3) -> bool:
	return p.z>=BOW_Z and p.z<=STERN_Z and p.y<=deck_at(p.z) and p.y>=keel_at(p.z) and absf(p.x)<=half_at(p.y, p.z)

## The hull as a solid for the crew outside (SpaceTraversal): how far `p`
## (hull space) is inside it (> 0 inside) and the way out.
static func inside(p: Vector3) -> Array:
	if not solid_at(p): return [-1.0, Vector3.ZERO]
	var best := half_at(p.y, p.z)-absf(p.x)
	var out := Vector3(signf(p.x) if p.x!=0.0 else 1.0, 0, 0)
	for pair: Array in [[deck_at(p.z)+0.13-p.y, Vector3.UP], [p.y-keel_at(p.z), Vector3.DOWN], [p.z-BOW_Z, Vector3.FORWARD], [STERN_Z-p.z, Vector3.BACK]]:
		if float(pair[0])<best:
			best = pair[0]
			out = pair[1]
	return [best, out]

## Pushed out of the hull and everything standing on it (hull space), with
## `radius` of room around a body.
static func push_out(p: Vector3, radius := 0.45) -> Vector3:
	var hit: Array = inside(p)
	if float(hit[0])>0.0: p += (hit[1] as Vector3)*(float(hit[0])+0.05)
	for box: Array in SOLIDS:
		var c: Vector3 = box[0]
		var h: Vector3 = (box[1] as Vector3)+Vector3.ONE*radius
		var d := p-c
		var pen := h-d.abs()
		if pen.x<=0.0 or pen.y<=0.0 or pen.z<=0.0: continue
		if pen.x<pen.y and pen.x<pen.z: p.x += signf(d.x)*pen.x if d.x!=0.0 else pen.x
		elif pen.y<pen.z: p.y += signf(d.y)*pen.y if d.y!=0.0 else pen.y
		else: p.z += signf(d.z)*pen.z if d.z!=0.0 else pen.z
	return p

## Open where the room's windows look out (hull space block centre).
static func _window_at(c: Vector3) -> bool:
	var front: Vector3 = BRIDGE_WINDOW[0]
	var half: Vector2 = BRIDGE_WINDOW[1]
	if c.z< -16.0 and c.z> -19.0 and absf(c.x)<=half.x+0.1 and absf(c.y-front.y)<=half.y+0.1: return true
	for window: Array in SIDE_WINDOWS:
		var at: Vector3 = window[0]
		var size: Vector2 = window[1]
		if signf(c.x)==signf(at.x) and absf(c.x)>5.5 and absf(c.z-at.z)<=size.x+0.1 and absf(c.y-at.y)<=size.y+0.1: return true
	for pz in PORTHOLES:
		if absf(c.x)>5.0 and Vector2(c.y-PORTHOLE_Y, c.z-pz).length()<=0.75: return true
	return false

## Every block of the shell: inside the hull with open space beside it.
static func shell() -> Array:
	if not _shell.is_empty(): return _shell
	var plank := Color("aa7448")
	var steps: Array[Vector3] = [Vector3(VOXEL, 0, 0), Vector3(-VOXEL, 0, 0), Vector3(0, VOXEL, 0), Vector3(0, -VOXEL, 0), Vector3(0, 0, VOXEL), Vector3(0, 0, -VOXEL)]
	var rows := int((DECK_TOP-KEEL_Y)/VOXEL)+2
	for iz in int((STERN_Z-BOW_Z)/VOXEL):
		var z := BOW_Z+VOXEL*(iz+0.5)
		for iy in rows:
			var y := DECK_TOP-VOXEL*(iy+0.5)
			for ix in 40:
				var c := Vector3(VOXEL*(ix-19.5), y, z)
				if not solid_at(c) or _window_at(c): continue
				var open := -1
				for k in 6:
					if not solid_at(c+steps[k]):
						open = k
						break
				if open<0: continue
				var color: Color
				if not solid_at(c+steps[2]):
					color = plank.lightened(float((iz+ix*3) % 5)*0.02) if absf(c.x)<beam(z)-0.6 else ArtBatch.WOOD.darkened(0.1)
				elif not solid_at(c+steps[3]): color = ArtBatch.DARK
				elif iy==4 or iy==12: color = ArtBatch.BRASS
				else: color = ArtBatch.WOOD.lightened(float((iy+iz/4) % 4)*0.035)
				_shell.append([c, color])
		# The gunwale: two blocks of rail on the deck's outer edge (both decks).
		var top := deck_at(z)
		var ry := DECK_TOP-VOXEL*0.5 if z>=BRIDGE_Z else BOW_DECK_Y+0.03-VOXEL*0.5
		for ix in 40:
			var c := Vector3(VOXEL*(ix-19.5), ry, z)
			if not solid_at(c) or solid_at(c+Vector3(signf(c.x)*VOXEL, 0, 0)): continue
			if top<DECK_Y and z> -18.6: continue
			for lift in [1, 2]:
				_shell.append([c+Vector3.UP*VOXEL*lift, ArtBatch.BRASS if iz % 8==0 else ArtBatch.WOOD.darkened(0.18)])
	return _shell

func build(tint: Color) -> void:
	for child in get_children():
		if child.has_meta("ship_art_mount"): child.free()
	_root = content(self, _root)
	_flames.clear()
	var accent := Color(tint.r, tint.g, tint.b).lerp(ArtBatch.AMBER, 0.16)
	var art := ArtBatch.new(_root)
	for block: Array in shell(): art.box(block[0], Vector3.ONE*VOXEL, block[1])
	# Brass rims round the portholes and the frame of the bridge glass.
	for pz in PORTHOLES:
		for side: float in [-1.0, 1.0]:
			art.part("ring", Vector3(side*(half_at(PORTHOLE_Y, pz)+0.2), PORTHOLE_Y, pz), Vector3.ONE*2.2, ArtBatch.BRASS, 0, Basis(Vector3.FORWARD, PI*0.5))
	var window: Vector3 = BRIDGE_WINDOW[0]
	var half: Vector2 = BRIDGE_WINDOW[1]
	var open := Vector2(VOXEL*ceilf((half.x+0.1)/VOXEL), 0)
	var low := DECK_TOP-VOXEL*floorf((DECK_TOP-(window.y-half.y-0.1))/VOXEL)
	var high := DECK_TOP-VOXEL*ceilf((DECK_TOP-(window.y+half.y+0.1))/VOXEL)
	open.y = (high-low)*0.5
	var mid := (high+low)*0.5
	for x: float in [-open.x, -open.x*0.62, -open.x*0.3, open.x*0.3, open.x*0.62, open.x]:
		art.box(Vector3(x, mid, BRIDGE_Z-0.07), Vector3(0.16, open.y*2.0+0.16, 0.14), ArtBatch.BRASS)
	for y: float in [low, high]: art.box(Vector3(0, y, BRIDGE_Z-0.07), Vector3(open.x*2.0+0.16, 0.16, 0.14), ArtBatch.BRASS)
	# Wheelhouse above the bridge, tinted roof tiles; the top cannon sits on it.
	for tier in 4:
		art.box(Vector3(0, DECK_TOP+0.21+tier*0.42, -15.0), Vector3(9.0-tier*1.8, 0.42, 5.9-tier*1.0), accent.darkened(tier*0.05))
	# The deck hatch the ladder climbs to: coaming, open lid, ladder rails.
	var hatch := Vector3(-5.5, DECK_TOP, -9.0)
	for side: float in [-1.0, 1.0]:
		art.box(hatch+Vector3(side*0.75, 0.12, 0), Vector3(0.18, 0.24, 1.68), ArtBatch.BRASS)
		art.box(hatch+Vector3(0, 0.12, side*0.75), Vector3(1.32, 0.24, 0.18), ArtBatch.BRASS)
	art.box(hatch+Vector3(0, 0.02, 0), Vector3(1.32, 0.04, 1.32), Color("1d2d3a"), 0.4)
	art.box(hatch+Vector3(0, 0.75, -0.9), Vector3(1.3, 1.3, 0.12), ArtBatch.WOOD, 0, Basis(Vector3.RIGHT, -0.35))
	for x: float in [-0.4, 0.4]: art.beam(hatch+Vector3(x, 0.0, 0.2), hatch+Vector3(x, 0.95, 0.35), 0.08, ArtBatch.BRASS)
	art.lantern(hatch+Vector3(0.95, 0.6, 0.95))
	# Prow: bowsprit and a glowing crystal figurehead the pilot sees ahead.
	art.beam(Vector3(0, BOW_DECK_Y, BOW_Z+1.5), Vector3(0, 2.6, BOW_Z-6.0), 0.4, ArtBatch.BRASS)
	art.crystal(Vector3(0, BOW_DECK_Y+0.9, BOW_Z-0.8), Vector3(1.4, 2.6, 1.4), ArtBatch.GREEN)
	art.crystal(Vector3(0, 2.8, BOW_Z-5.0), Vector3(0.7, 1.4, 0.7), ArtBatch.PINK)
	# Stern castle: two warm-windowed storeys and a stepped tinted roof.
	var castle := Vector3(0, DECK_TOP+1.35, 17.25)
	art.box(castle, Vector3(12.0, 2.7, 7.5), ArtBatch.WOOD.lightened(0.04))
	art.box(castle+Vector3(0, 0.05, 0), Vector3(12.2, 0.16, 7.7), ArtBatch.BRASS)
	for x: float in [-4.0, -1.4, 1.4, 4.0]:
		for y: float in [-0.65, 0.75]:
			art.box(Vector3(x, castle.y+y, 13.45), Vector3(1.2, 0.9, 0.1), ArtBatch.AMBER, 1.6)
			art.box(Vector3(x, castle.y+y, 21.05), Vector3(1.2, 0.9, 0.1), ArtBatch.AMBER, 1.6)
	for tier in 3:
		art.box(Vector3(0, DECK_TOP+2.7+0.175+tier*0.35, 17.25), Vector3(12.8-tier*2.4, 0.35, 8.1-tier*1.6), accent.darkened(tier*0.04))
	# Masts with glowing sails (a breakable part) and crystal crow's nests.
	for mast: Array in [[-4.0, 19.0, 8.0], [-12.0, 13.0, 5.5], [10.0, 11.0, 4.5]]:
		var mz: float = mast[0]
		var tall: float = mast[1]
		var span: float = mast[2]
		art.box(Vector3(0, DECK_TOP+tall*0.5, mz), Vector3(0.7, tall, 0.7), Color("6d4839"))
		art.box(Vector3(0, DECK_TOP+tall*0.82, mz), Vector3(span*2.0, 0.35, 0.35), Color("6d4839"))
		art.box(Vector3(0, DECK_TOP+tall*0.42, mz), Vector3(span*2.2, 0.35, 0.35), Color("6d4839"))
		var strip_h := tall*0.36/6.0
		for strip in 6:
			var y := DECK_TOP+tall*0.45+(strip+0.5)*strip_h
			var belly := sin(float(strip)/5.0*PI)*0.9
			art.box(Vector3(0, y, mz+belly), Vector3(span*(2.0-strip*0.06), strip_h, 0.16), accent.lerp(Color.WHITE, 0.25) if strip % 2 else accent, 0.35)
		art.part("sphere", Vector3(0, DECK_TOP+tall+0.4, mz), Vector3(1.6, 1.0, 1.6), ArtBatch.BRASS)
		art.crystal(Vector3(0, DECK_TOP+tall+1.5, mz), Vector3(0.6, 1.6, 0.6), ArtBatch.GREEN if mz<0 else ArtBatch.PINK)
	# Lanterns standing on the gunwale.
	for side: float in [-1.0, 1.0]:
		for z: float in [-14.25, -2.25, 7.75]:
			art.lantern(Vector3(side*(beam(z)-0.25), DECK_TOP+VOXEL*2.0+0.28, z))
	# Soft crystal lights under the keel.
	for z in range(-16, 16, 4):
		art.crystal(Vector3(0, KEEL_Y-0.45, z+2), Vector3(0.6, 1.0, 0.6), ArtBatch.GREEN if z % 8==0 else ArtBatch.PINK)
	# Sponsons under the side cannons.
	for side: float in [-1.0, 1.0]:
		art.box(Vector3(side*9.45, 1.82, -2.0), Vector3(1.9, 0.36, 2.6), ArtBatch.WOOD.darkened(0.15))
		art.beam(Vector3(side*8.4, 0.2, -2.0), Vector3(side*9.9, 1.65, -2.0), 0.24, ArtBatch.BRASS)
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
	# Glass in every opening, faint enough for the room's live windows.
	_pane(Vector3(0, mid, BRIDGE_Z-0.02), Vector2(open.x*2.0, open.y*2.0), Basis.IDENTITY)
	for side_window: Array in SIDE_WINDOWS:
		var at: Vector3 = side_window[0]
		var size: Vector2 = side_window[1]
		_pane(Vector3(signf(at.x)*(half_at(at.y, at.z)+0.1), at.y, at.z), size*2.0+Vector2.ONE*0.4, Basis(Vector3.UP, PI*0.5))
	for pz in PORTHOLES:
		for side: float in [-1.0, 1.0]:
			_pane(Vector3(side*(half_at(PORTHOLE_Y, pz)+0.2), PORTHOLE_Y, pz), Vector2.ONE*1.6, Basis(Vector3.UP, PI*0.5))
	_turret("Turret_top", Vector3(0, DECK_TOP+1.68, -15.0), accent)
	_turret("Turret_left", Vector3(-9.7, 2.0, -2.0), accent)
	_turret("Turret_right", Vector3(9.7, 2.0, -2.0), accent)
	anchors = {cockpit = Transform3D(Basis.IDENTITY, window+Vector3(0, 0.2, 1.4)),
		chase = Vector3(0, 17, 56), engines = exhausts,
		hatch = Transform3D(Basis(Vector3.UP, -PI*0.5), Vector3(11.5, -5.6, 6.0)), length = 52.0, radius = 30.0}
	set_engine(0.0)

static var _glass: StandardMaterial3D

func _pane(at: Vector3, size: Vector2, basis: Basis) -> void:
	var quad := QuadMesh.new()
	quad.size = size
	var pane := MeshInstance3D.new()
	pane.mesh = quad
	pane.material_override = glass()
	pane.transform = Transform3D(basis, at)
	pane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_root.add_child(pane)

## Clear glass for the gunners' domes, seen from inside as well as out.
static func glass() -> StandardMaterial3D:
	if not is_instance_valid(_glass):
		_glass = StandardMaterial3D.new()
		_glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_glass.cull_mode = BaseMaterial3D.CULL_DISABLED
		_glass.albedo_color = Color(0.72, 0.95, 1.0, 0.13)
		_glass.roughness = 0.05
		_glass.metallic_specular = 0.9
		_glass.rim_enabled = true
		_glass.rim = 0.35
	return _glass

## A gunner's cannon: a brass ring, a glass dome the gunner looks out of
## (SpaceTraversal puts the camera inside it) and twin barrels on the
## turning, tilting mount.
func _turret(id: String, at: Vector3, accent: Color) -> void:
	var mount := Node3D.new()
	mount.name = id
	mount.position = at
	# Mounts are direct children for gameplay's stable node paths.
	add_child(mount)
	# Rebuild removes only the mounts owned by this builder.
	mount.set_meta("ship_art_mount", true)
	var base := ArtBatch.new(mount)
	base.part("cylinder", Vector3(0, 0.12, 0), Vector3(2.8, 0.24, 2.8), ArtBatch.BRASS)
	base.part("ring", Vector3(0, 0.3, 0), Vector3(2.75, 0.5, 2.75), accent)
	for i in 4:
		var a := i*TAU/4.0+PI*0.25
		base.beam(Vector3(cos(a), 0.25, sin(a))*Vector3(1.3, 1, 1.3), Vector3(cos(a)*0.32, 1.55, sin(a)*0.32), 0.05, ArtBatch.BRASS)
	base.part("sphere", Vector3(0, 1.58, 0), Vector3.ONE*0.18, ArtBatch.GREEN, 1.5)
	base.finish()
	var dome := MeshInstance3D.new()
	var shape := SphereMesh.new()
	shape.radius = 1.35
	shape.height = 1.35
	shape.is_hemisphere = true
	shape.radial_segments = 24
	shape.rings = 8
	dome.mesh = shape
	dome.material_override = glass()
	dome.position.y = 0.26
	dome.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mount.add_child(dome)
	var yaw := Node3D.new()
	yaw.name = "Yaw"
	mount.add_child(yaw)
	var seat := ArtBatch.new(yaw)
	seat.box(Vector3(0, 0.36, 0.45), Vector3(0.7, 0.16, 0.6), ArtBatch.DARK)
	seat.box(Vector3(0, 0.62, 0.72), Vector3(0.7, 0.5, 0.12), accent.darkened(0.2))
	seat.finish()
	var pitch := Node3D.new()
	pitch.name = "Pitch"
	pitch.position.y = 0.42
	yaw.add_child(pitch)
	var barrels := ArtBatch.new(pitch)
	for x: float in [-0.62, 0.62]:
		barrels.part("cylinder", Vector3(x, 0, -1.55), Vector3(0.3, 2.5, 0.3), ArtBatch.DARK, 0, Basis(Vector3.RIGHT, PI * 0.5))
		barrels.part("ring", Vector3(x, 0, -2.75), Vector3.ONE * 0.44, ArtBatch.BRASS, 0, Basis(Vector3.RIGHT, PI * 0.5))
		barrels.box(Vector3(x, 0, -0.35), Vector3(0.36, 0.36, 0.6), ArtBatch.BRASS)
	barrels.finish()
	var muzzle := Node3D.new()
	muzzle.name = "Muzzle"
	muzzle.position.z = -2.9
	pitch.add_child(muzzle)

## Idle retains a little fire; boost extends and brightens each exhaust.
func set_engine(strength: float) -> void:
	var power := clampf(strength, 0.0, 2.0)
	for flame in _flames:
		flame.scale = Vector3(1.1 + power * 0.23, 1.1 + power * 0.23, 0.9 + power * 3.0)
	if is_instance_valid(_fire): _fire.set_shader_parameter("strength", power)
