class_name ShipInterior
extends Node3D
## Stationary, enclosed first-person pocket with a clear central passage.

const Art = preload("res://scripts/space/art/ship_hull.gd").ArtBatch
var anchors := {}
var _root: Node3D
static var _stars: ShaderMaterial
static var _round_stars: ShaderMaterial
static var _window: QuadMesh

func build(server: bool) -> void:
	_root = ShipHull.content(self, _root)
	anchors = {spawn = Vector3(0, 0, 14.8), hatch = Vector3(0, 1.3, 17.1), seats = {
		pilot = {pos = Vector3(0, 0, -13), yaw = 0.0, kind = "pilot", stand = Vector3(0, 0, -14.5)},
		turret_top = {pos = Vector3(4.9, 0.75, -6), yaw = 0.0, kind = "turret", stand = Vector3(4.9, 0.75, -7.4)},
		turret_left = {pos = Vector3(-5.3, 0, 1), yaw = PI * 0.5, kind = "turret", stand = Vector3(-6.6, 0, 1)},
		turret_right = {pos = Vector3(5.3, 0, 1), yaw = -PI * 0.5, kind = "turret", stand = Vector3(6.6, 0, 1)},
		map = {pos = Vector3(-3.6, 0, -3.9), yaw = 0.0, kind = "map", stand = Vector3(-3.6, 0, -5.3)},
		# Armchairs around the crew table.
		chair_0 = {pos = Vector3(-4.7, 0, 4.1), yaw = PI, kind = "chair", stand = Vector3(-4.7, 0, 2.9)},
		chair_1 = {pos = Vector3(-4.7, 0, 8.3), yaw = 0.0, kind = "chair", stand = Vector3(-3.2, 0, 8.6)},
		chair_2 = {pos = Vector3(-2.6, 0, 6.2), yaw = PI*0.5, kind = "chair", stand = Vector3(-1.4, 0, 6.2)},
		chair_3 = {pos = Vector3(-6.8, 0, 6.2), yaw = -PI*0.5, kind = "chair", stand = Vector3(-6.6, 0, 4.4)}},
		# Where each part inside is mended (stand points), the airlock and the beer tap.
		repairs = {helm = Vector3(0, 0, -14.4), cannons = Vector3(4.9, 0.75, -7.3), heart = Vector3(5.6, 0, -2.6)},
		heart = Vector3(6.8, 0, -2.6),
		airlock = Vector3(-6.9, 0, -10.0),
		tap = Vector3(5.7, 0, 7.6),
		glasses = [Vector3(-4.7, 0.87, 5.45), Vector3(-4.7, 0.87, 6.95), Vector3(-3.95, 0.87, 6.2), Vector3(-5.45, 0.87, 6.2)]}
	var art := Art.new(_root, server)
	_structure(art)
	for seat: Dictionary in anchors.seats.values(): _chair(art, seat.pos, seat.yaw, seat.kind)
	if server: return
	_room_finish(art)
	_bridge(art)
	_crew(art)
	_systems(art)
	art.finish()
	for side: float in [-1.0, 1.0]:
		for z: float in [-11, 2, 11]:
			var light := OmniLight3D.new()
			light.position = Vector3(side * 4.2, 2.9, z)
			light.light_color = Color("ffce8b")
			light.light_energy = 1.1
			light.omni_range = 9.0
			light.shadow_enabled = false
			light.distance_fade_enabled = true
			light.distance_fade_begin = 14.0
			light.distance_fade_length = 16.0
			_root.add_child(light)

## Shell and furniture collision are identical in client and server builds.
func _structure(art: Art) -> void:
	art.solid(Vector3(0, -0.2, 0), Vector3(16, 0.4, 36))
	art.solid(Vector3(0, 4.35, 0), Vector3(16, 0.3, 36))
	for side: float in [-1.0, 1.0]:
		art.solid(Vector3(side * 7.85, 2.1, 0), Vector3(0.3, 4.2, 36))
		art.solid(Vector3(0, 2.1, side * 17.85), Vector3(16, 4.2, 0.3))
	# Consoles leave room between the chair and its stand point.
	art.solid(Vector3(0, 0.55, -16.1), Vector3(4.4, 1.1, 1.0))
	for side: float in [-1.0, 1.0]:
		art.solid(Vector3(side * 7.35, 0.6, 1), Vector3(0.4, 1.2, 3.0))
	art.solid(Vector3(4.9, 0.375, -6.5), Vector3(4.0, 0.75, 5.0))
	art.solid(Vector3(4.9, 1.3, -8.35), Vector3(3, 1.1, 0.65))
	# Five low risers connect the upper seat to the main deck.
	for step in 5:
		var height := (5 - step) * 0.15
		var at := Vector3(4.9, height * 0.5, -3.775 + step * 0.45)
		var size := Vector3(1.8, height, 0.45)
		art.solid(at, size)
		art.box(at, size, Art.WOOD.lightened(step * 0.025))
		art.box(at + Vector3(0, height * 0.5 + 0.012, 0.16), Vector3(1.8, 0.025, 0.12), Art.BRASS)
	for x: float in [2.95, 6.85]: art.solid(Vector3(x, 1.2, -6.5), Vector3(0.15, 0.9, 4.8))
	var table := CylinderShape3D.new()
	table.radius = 1.2
	table.height = 1.1
	art.collision(table, Transform3D(Basis.IDENTITY, Vector3(-3.6, 0.55, -7)))
	art.solid(Vector3(-4.7, 0.43, 6.2), Vector3(2.6, 0.86, 2.6))
	art.solid(Vector3(6.65, 0.6, 6.5), Vector3(1.6, 1.2, 5.2))
	for side: float in [-1.0, 1.0]:
		art.solid(Vector3(side * 6.9, 1.4, 14.3), Vector3(1.25, 2.8, 3.2))
		art.solid(Vector3(side * 4.7, 0.5, 15.4), Vector3(1.3, 1, 1.4))
	art.solid(Vector3(6.8, 0.3, -2.6), Vector3(1.3, 0.6, 1.3))  # heart crystal pedestal
	for at: Vector3 in [Vector3(-6.8, 0.35, -11.7), Vector3(6.7, 0.35, 10.7)]:
		art.solid(at, Vector3(0.7, 0.7, 0.7))

func _chair(art: Art, at: Vector3, yaw: float, kind: String) -> void:
	var basis := Basis(Vector3.UP, yaw)
	art.solid(at + Vector3.UP * 0.34, Vector3(0.85, 0.68, 0.85), basis)
	art.solid(at + basis * Vector3(0, 0.95, 0.38), Vector3(0.9, 0.9, 0.16), basis)
	if art.server: return
	if kind == "chair":
		_armchair(art, at, basis)
		return
	var cloth := Art.PINK.darkened(0.33) if kind == "map" else Color("538c72")
	art.box(at + Vector3.UP * 0.5, Vector3(0.92, 0.22, 0.9), cloth, 0, basis)
	art.box(at + basis * Vector3(0, 0.99, 0.39), Vector3(0.92, 0.95, 0.18), Art.WOOD, 0, basis)
	art.box(at + basis * Vector3(0, 1.02, 0.27), Vector3(0.67, 0.67, 0.12), cloth, 0, basis)
	for side: float in [-1.0, 1.0]:
		art.box(at + basis * Vector3(side * 0.52, 0.72, -0.05), Vector3(0.16, 0.12, 0.75), Art.BRASS, 0, basis)
		for z: float in [-0.3, 0.3]:
			art.box(at + basis * Vector3(side * 0.32, 0.23, z), Vector3(0.14, 0.46, 0.14), Art.WOOD, 0, basis)
		if kind == "turret":
			var lever := at + basis * Vector3(side * 0.55, 0.92, -0.28)
			art.beam(lever, lever + basis * Vector3(0, 0.33, -0.12), 0.065, Art.BRASS)
			art.part("sphere", lever + basis * Vector3(0, 0.34, -0.12), Vector3.ONE * 0.16, Art.PINK, 1.0)

func _room_finish(art: Art) -> void:
	for x in 20:
		for z in 24:
			art.box(Vector3(-7.6 + x * 0.8, -0.09, -17.25 + z * 1.5), Vector3(0.79, 0.18, 1.49), Art.WOOD.lightened(float((x * 7 + z * 3) % 5) * 0.025))
	art.box(Vector3(0, 4.35, 0), Vector3(16, 0.3, 36), Color("583a31"))
	for side: float in [-1.0, 1.0]:
		for row in 7:
			art.box(Vector3(side * 7.85, row * 0.6 + 0.3, 0), Vector3(0.3, 0.58, 36), Art.WOOD.lightened(row % 3 * 0.035))
		art.box(Vector3(0, 2.1, side * 17.85), Vector3(16, 4.2, 0.3), Art.WOOD)
		for z: float in [-15, -10, -5, 0, 5, 10, 15]:
			art.box(Vector3(side * 7.55, 2.1, z), Vector3(0.24, 4.2, 0.24), Art.DARK)
			art.lantern(Vector3(side * 7.25, 2.7, z))
			art.beam(Vector3(side * 7.5, 3.8, z), Vector3(side * 6.6, 4.14, z), 0.2, Art.BRASS)
		for z: float in [-12.5, -7.5, 3.5, 11.5]:
			var frame := Basis(Vector3.UP, -side * PI * 0.5)
			_star_window(Vector3(side * 7.66, 2.3, z), Vector2(1.15, 1.15), frame, true)
			art.part("ring", Vector3(side * 7.59, 2.3, z), Vector3.ONE * 1.65, Art.BRASS, 0, Basis(Vector3.FORWARD, PI * 0.5))
	for z: float in [-15, -10, -5, 0, 5, 10, 15]:
		art.box(Vector3(0, 4.08, z), Vector3(15.5, 0.24, 0.25), Art.DARK)
		art.box(Vector3(0, 3.93, z), Vector3(2, 0.06, 0.32), Art.BRASS)
	# A runner and a ceiling constellation guide the central passage.
	art.box(Vector3(0, 0.012, 3), Vector3(2.6, 0.024, 25), Color("6f4361"))
	for x: float in [-1.2, 1.2]: art.box(Vector3(x, 0.027, 3), Vector3(0.06, 0.01, 25), Art.BRASS)
	for z in 16: art.box(Vector3(sin(z * 1.7) * 1.5, 4.17, -14 + z * 1.8), Vector3.ONE * 0.09, Art.AMBER, 2.0)
	# Upper deck, guard rails and a readable brass console.
	art.box(Vector3(4.9, 0.375, -6.5), Vector3(4, 0.75, 5), Art.WOOD)
	art.box(Vector3(4.9, 0.76, -6.5), Vector3(3.9, 0.025, 4.9), Color("ab7952"))
	for x: float in [2.95, 6.85]:
		for z: float in [-8.75, -6.5, -4.25]: art.box(Vector3(x, 1.25, z), Vector3(0.12, 1.0, 0.12), Art.BRASS)
		art.box(Vector3(x, 1.7, -6.5), Vector3(0.13, 0.12, 4.6), Art.BRASS)
	_console(art, Vector3(4.9, 0.75, -8.35), Vector3(3, 1.1, 0.65))
	for side: float in [-1.0, 1.0]: _console(art, Vector3(side * 7.35, 0, 1), Vector3(0.4, 1.2, 3))
	# Round wooden boarding hatch, sealed by the room's end wall.
	var face := Basis(Vector3.RIGHT, PI * 0.5)
	art.part("cylinder", Vector3(0, 1.6, 17.62), Vector3(2.8, 0.18, 2.8), Art.DARK, 0, face)
	art.part("ring", Vector3(0, 1.6, 17.48), Vector3.ONE * 3.2, Art.BRASS, 0, face)
	for x in 7:
		var px := (x - 3) * 0.32
		var height := sqrt(1.2 * 1.2 - px * px) * 2
		art.box(Vector3(px, 1.6, 17.48), Vector3(0.3, height, 0.12), Art.WOOD.lightened(x % 2 * 0.06))
	art.part("ring", Vector3(0.7, 1.6, 17.32), Vector3.ONE * 0.4, Art.BRASS, 0, face)
	art.crystal(Vector3(0, 3.26, 17.5), Vector3(0.25, 0.4, 0.2), Art.GREEN)
	_label("BOARDING HATCH", Vector3(0, 3.7, 17.48), PI)
	_label("THE ASTRAL HEARTH", Vector3(0, 3.85, -17.55), 0)

## A deep, cushioned armchair facing along -Z of `basis`.
func _armchair(art: Art, at: Vector3, basis: Basis) -> void:
	var leather := Color("7a3f3a")
	var cushion := Color("b7655a")
	art.box(at + basis * Vector3(0, 0.3, 0), Vector3(1.1, 0.42, 1.0), leather, 0, basis)
	art.box(at + basis * Vector3(0, 0.56, -0.02), Vector3(0.86, 0.16, 0.86), cushion, 0, basis)
	art.box(at + basis * Vector3(0, 0.95, 0.42), Vector3(1.1, 0.95, 0.24), leather, 0, basis)
	art.box(at + basis * Vector3(0, 1.0, 0.3), Vector3(0.8, 0.62, 0.1), cushion, 0, basis)
	for side: float in [-1.0, 1.0]:
		art.box(at + basis * Vector3(side * 0.5, 0.72, 0.0), Vector3(0.18, 0.34, 0.95), leather.darkened(0.08), 0, basis)
		art.box(at + basis * Vector3(side * 0.5, 0.9, -0.38), Vector3(0.2, 0.08, 0.2), Art.BRASS, 0, basis)
		for z: float in [-0.38, 0.38]: art.box(at + basis * Vector3(side * 0.42, 0.05, z), Vector3(0.12, 0.1, 0.12), Art.DARK, 0, basis)

func _console(art: Art, at: Vector3, size: Vector3) -> void:
	art.box(at + Vector3.UP * size.y * 0.5, size, Art.WOOD)
	art.box(at + Vector3.UP * (size.y + 0.035), Vector3(size.x + 0.1, 0.07, size.z + 0.1), Art.BRASS)
	for i in 5:
		var delta := Vector3((i - 2) * size.x * 0.16, size.y + 0.09, 0)
		if size.z > size.x: delta = Vector3(0, size.y + 0.09, (i - 2) * size.z * 0.16)
		art.box(at + delta, Vector3(0.12, 0.06, 0.12), Art.GREEN if i % 2 else Art.PINK, 1.3)

func _bridge(art: Art) -> void:
	_star_window(Vector3(0, 2.7, -17.66), Vector2(10.6, 2.0), Basis.IDENTITY)
	for x: float in [-5.45, -2.75, 0, 2.75, 5.45]: art.box(Vector3(x, 2.7, -17.52), Vector3(0.16, 2.2, 0.18), Art.BRASS)
	for y: float in [1.64, 3.77]: art.box(Vector3(0, y, -17.52), Vector3(11, 0.16, 0.18), Art.BRASS)
	_console(art, Vector3(0, 0, -16.1), Vector3(4.4, 1.1, 1.0))
	# Helm spokes and handles surround a polished brass hub.
	var center := Vector3(0, 1.37, -15.3)
	art.beam(Vector3(0, 0, -15.45), center, 0.16, Art.BRASS)
	art.part("ring", center, Vector3.ONE * 1.15, Art.WOOD, 0, Basis(Vector3.RIGHT, PI * 0.5))
	art.part("sphere", center, Vector3.ONE * 0.22, Art.BRASS)
	for i in 8:
		var dir := Vector3(cos(i * TAU / 8), sin(i * TAU / 8), 0)
		art.beam(center + dir * 0.1, center + dir * 0.7, 0.065, Art.BRASS)
		art.part("sphere", center + dir * 0.71, Vector3.ONE * 0.12, Art.WOOD)
	# Circular map, a green orrery and tiny pink planetary markers.
	var at := Vector3(-3.6, 0, -7)
	art.part("cylinder", at + Vector3.UP * 0.5, Vector3(0.5, 1, 0.5), Art.BRASS)
	art.part("cylinder", at + Vector3.UP * 1.04, Vector3(2.4, 0.18, 2.4), Art.WOOD)
	art.part("cylinder", at + Vector3.UP * 1.14, Vector3(2.15, 0.035, 2.15), Color("193d40"), 0.35)
	for diameter: float in [0.8, 1.4, 2.0]: art.part("ring", at + Vector3.UP * 1.17, Vector3(diameter, 0.12, diameter), Art.BRASS, 0.6)
	art.crystal(at + Vector3.UP * 1.42, Vector3(0.25, 0.48, 0.25), Art.GREEN)
	for i in 9:
		var angle := i * 2.4
		art.part("sphere", at + Vector3(cos(angle) * 0.85, 1.22, sin(angle) * 0.85), Vector3.ONE * 0.09, Art.PINK if i % 2 else Art.AMBER, 1.5)

func _crew(art: Art) -> void:
	# Cloth hammocks hang outside the central route and have no collision.
	for side: float in [-1.0, 1.0]:
		for strip in 12:
			var z := 9.0 + strip * 0.25
			var sag := sin(float(strip) / 11 * PI) * 0.36
			art.box(Vector3(side * 5.0, 1.3 - sag, z), Vector3(1.25, 0.08, 0.27), Color("568f77") if side < 0 else Color("b96e90"))
		for z: float in [8.9, 11.9]:
			for x: float in [-0.6, 0.6]: art.beam(Vector3(side * 5.0 + x, 1.4, z), Vector3(side * 5.0, 3.9, z), 0.035, Art.BRASS)
		art.box(Vector3(side * 5, 1.35, 9.3), Vector3(0.85, 0.18, 0.45), Art.AMBER)
	# Galley, stove and a deliberately small magical hearth.
	art.box(Vector3(6.65, 0.6, 6.5), Vector3(1.6, 1.2, 5.2), Art.WOOD)
	art.box(Vector3(6.65, 1.24, 6.5), Vector3(1.7, 0.12, 5.3), Art.BRASS)
	art.box(Vector3(6.55, 0.65, 4.5), Vector3(1.1, 1.25, 1.1), Art.DARK)
	art.box(Vector3(5.96, 0.67, 4.5), Vector3(0.035, 0.55, 0.65), Art.GREEN, 2.0)
	for z: float in [4.25, 4.5, 4.75]: art.box(Vector3(5.92, 0.68, z), Vector3(0.06, 0.65, 0.055), Art.BRASS)
	art.part("cylinder", Vector3(6.55, 2.65, 4.5), Vector3(0.28, 2.9, 0.28), Art.DARK)
	art.part("sphere", Vector3(6.55, 1.53, 4.5), Vector3(0.65, 0.45, 0.65), Art.DARK)
	art.part("ring", Vector3(6.55, 1.83, 4.5), Vector3.ONE * 0.45, Art.BRASS, 0, Basis(Vector3.FORWARD, PI * 0.5))
	for z: float in [6.4, 7.1, 7.8]: art.part("cylinder", Vector3(6.6, 1.5, z), Vector3(0.3, 0.4, 0.3), Art.AMBER)
	# Shared table with chunky mugs, books and a small vase.
	# A low tavern table to sit at.
	art.box(Vector3(-4.7, 0.78, 6.2), Vector3(2.6, 0.16, 2.6), Color("aa7547"))
	for x: float in [-5.6, -3.8]:
		for z: float in [5.3, 7.1]: art.box(Vector3(x, 0.36, z), Vector3(0.2, 0.72, 0.2), Art.WOOD)
	# A candle and a little crystal in the middle; the glasses are live (ShipTavern).
	art.part("cylinder", Vector3(-4.7, 0.98, 6.2), Vector3(0.16, 0.22, 0.16), Color("f3e6c8"))
	art.box(Vector3(-4.7, 1.14, 6.2), Vector3(0.05, 0.1, 0.05), Art.AMBER, 3.0)
	art.crystal(Vector3(-4.45, 1.11, 6.45), Vector3(0.12, 0.3, 0.12), Art.PINK)
	# Bookshelves and strapped crates along the aft walls.
	for side: float in [-1.0, 1.0]:
		var x := side * 6.9
		art.box(Vector3(x + side * 0.52, 1.4, 14.3), Vector3(0.18, 2.8, 3.2), Art.DARK)
		for z: float in [12.75, 15.85]: art.box(Vector3(x, 1.4, z), Vector3(1.2, 2.8, 0.16), Art.WOOD)
		for shelf in 4:
			var y := 0.15 + shelf * 0.8
			art.box(Vector3(x, y, 14.3), Vector3(1.25, 0.12, 3.2), Art.WOOD)
			if shelf == 3: continue
			for book in 13:
				var color: Color = [Color("65977b"), Art.PINK.darkened(0.2), Art.BRASS, Color("6688a3")][(book + shelf) % 4]
				art.box(Vector3(x - side * 0.14, y + 0.32, 12.95 + book * 0.21), Vector3(0.65, 0.48 + book % 3 * 0.07, 0.16), color)
		var crate := Vector3(side * 4.7, 0.5, 15.4)
		art.box(crate, Vector3(1.3, 1, 1.4), Art.WOOD)
		for dx: float in [-0.43, 0.43]: art.box(crate + Vector3(dx, 0, 0), Vector3(0.09, 1.04, 1.44), Art.BRASS)
	for at: Vector3 in [Vector3(-6.8, 0, -11.7), Vector3(6.7, 0, 10.7)]:
		art.part("cylinder", at + Vector3.UP * 0.32, Vector3(0.75, 0.64, 0.75), Color("bd7559"))
		for stem in 7:
			var angle := stem * 2.4
			var tip := at + Vector3(cos(angle) * 0.35, 1.1 + stem % 3 * 0.2, sin(angle) * 0.35)
			art.beam(at + Vector3.UP * 0.55, tip, 0.055, Color("59874c"))
			art.box(tip, Vector3(0.3, 0.16, 0.24), Color("8bb968"))
			if stem % 3 == 0: art.crystal(tip + Vector3.UP * 0.14, Vector3(0.13, 0.24, 0.13), Art.PINK)

## Windows share two materials (square and round) so the ship's live view
## can be switched on for every window at once (ShipWindowView).
static func window_materials() -> Array[ShaderMaterial]:
	if not is_instance_valid(_stars):
		_stars = ShaderMaterial.new()
		_stars.shader = preload("res://shaders/ship_window.gdshader")
		_round_stars = _stars.duplicate() as ShaderMaterial
		_round_stars.set_shader_parameter("round_window", true)
		_window = QuadMesh.new()
		_window.size = Vector2.ONE
	return [_stars, _round_stars]

## The heart crystal, the airlock's inner door and the beer tap.
func _systems(art: Art) -> void:
	var heart: Vector3 = anchors.heart
	art.part("cylinder", heart + Vector3.UP * 0.3, Vector3(1.3, 0.6, 1.3), Art.BRASS)
	art.part("ring", heart + Vector3.UP * 0.62, Vector3.ONE * 1.35, Art.DARK)
	art.crystal(heart + Vector3.UP * 1.4, Vector3(0.7, 1.6, 0.7), Art.GREEN)
	for i in 4:
		var a := i * TAU / 4.0
		art.beam(heart + Vector3(cos(a) * 0.55, 0.6, sin(a) * 0.55), heart + Vector3(cos(a) * 0.2, 2.6, sin(a) * 0.2), 0.06, Art.BRASS)
	# Airlock: a round brass-bound door in the port wall (it slides open, ShipTavern).
	var lock: Vector3 = anchors.airlock + Vector3(-0.7, 0, 0)
	art.part("ring", lock + Vector3(0, 1.3, 0), Vector3.ONE * 2.7, Art.BRASS, 0, Basis(Vector3.FORWARD, PI * 0.5))
	art.box(lock + Vector3(0.05, 2.75, 0), Vector3(0.2, 0.4, 1.8), Art.DARK)
	art.box(lock + Vector3(0.25, 1.3, 1.25), Vector3(0.12, 0.5, 0.3), Art.DARK)
	art.box(lock + Vector3(0.32, 1.42, 1.25), Vector3(0.05, 0.12, 0.12), Art.GREEN, 2.0)
	art.box(lock + Vector3(0.32, 1.22, 1.25), Vector3(0.05, 0.12, 0.12), Color("ff6a5a"), 2.0)
	# Beer tap on the galley counter, with its barrel.
	var tap: Vector3 = anchors.tap + Vector3(0.9, 0, 0)
	art.part("cylinder", tap + Vector3(0.1, 1.55, 0), Vector3(0.16, 0.5, 0.16), Art.BRASS)
	art.beam(tap + Vector3(0.1, 1.75, 0), tap + Vector3(-0.25, 1.75, 0), 0.08, Art.BRASS)
	art.box(tap + Vector3(0.1, 2.0, 0), Vector3(0.08, 0.3, 0.08), Art.WOOD)
	art.part("sphere", tap + Vector3(0.1, 2.18, 0), Vector3.ONE * 0.14, Art.PINK, 1.2)
	art.part("cylinder", tap + Vector3(0.45, 0.7, 1.1), Vector3(1.0, 1.3, 1.0), Art.WOOD, 0, Basis(Vector3.FORWARD, PI * 0.5))
	for x: float in [-0.35, 0.35]: art.part("ring", tap + Vector3(0.45 + x * 0.0, 0.7, 1.1 + x), Vector3.ONE * 1.05, Art.BRASS, 0, Basis(Vector3.RIGHT, PI * 0.5))

func _star_window(at: Vector3, size: Vector2, basis: Basis, round_window: bool = false) -> void:
	var materials := window_materials()
	var panel := MeshInstance3D.new()
	panel.mesh = _window
	panel.material_override = materials[1] if round_window else materials[0]
	panel.transform = Transform3D(basis.scaled_local(Vector3(size.x, size.y, 1)), at)
	panel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_root.add_child(panel)

func _label(text: String, at: Vector3, yaw: float) -> void:
	var label := Label3D.new()
	label.text = text
	label.font = Art.heading_font()
	label.font_size = 64
	label.outline_size = 10
	label.pixel_size = 0.004
	label.modulate = Art.AMBER
	label.position = at
	label.rotation.y = yaw
	_root.add_child(label)
