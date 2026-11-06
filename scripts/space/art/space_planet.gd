class_name SpacePlanet
extends Node3D
## Radial landing gardens on eight distinct fairytale worlds.

var anchors: Dictionary = {}
static var _surface_mesh: SphereMesh
static var _shell_mesh: SphereMesh
static var _materials: Dictionary = {}
static var _atmospheres: Dictionary = {}
var _planet: Dictionary
var _pad: Transform3D
var _radius: float
var _colors: Array[Color] = []
var _server := false

const PLACES := {
	"verdance": ["treehouse_village", "mushroom_grove", "firefly_shrine", "elder_tree"],
	"rosamund": ["petal_shrine", "rose_crystal_garden", "fairy_court", "wishing_stones"],
	"amberfall": ["sleepy_market", "lantern_tower", "honey_well", "dune_caravan"],
	"tidewell": ["stilt_village", "lighthouse", "fishing_jetty", "shell_shrine"],
	"shardheart": ["singing_spires", "heart_shrine", "resonance_circle", "crystal_nest"],
	"hollowmoon": ["observatory_ruin", "bone_forest", "ghost_lanterns", "fallen_astrolabe"],
	"mawgrave": ["brood_hive", "spore_garden", "fungal_altar", "hollow_nest"],
	"pale_eye": ["obsidian_crown", "storm_observatory", "eye_shrine", "last_beacon"],
}

func build(planet: Dictionary, server: bool) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_planet = planet
	_server = server
	_radius = float(planet.radius)
	_pad = SpaceLayout.pad_frame(planet)
	_pad.origin -= planet.center as Vector3
	_colors.clear()
	if not server:
		for hex: String in planet.palette: _colors.append(Color(hex))
	anchors = {pad = _pad, spots = {}}
	var ground := StaticBody3D.new()
	ground.collision_layer = Player.TERRAIN_LAYER
	ground.collision_mask = 0
	var shape := SphereShape3D.new()
	shape.radius = _radius
	var collision := CollisionShape3D.new()
	collision.shape = shape
	ground.add_child(collision)
	add_child(ground)
	if not server: _globe()
	_landing()
	var offsets: Array[Vector2] = [Vector2(-40, -30), Vector2(48, -28), Vector2(-50, 53), Vector2(43, 78)]
	var names: Array = PLACES[planet.id]
	for i in names.size():
		var spot := _surface(offsets[i])
		anchors.spots[names[i]] = spot
		var place := Node3D.new()
		place.name = names[i]
		place.transform = _surface(offsets[i] + Vector2(0, -20))
		add_child(place)
		var art := NexusStation.Brush.new(place, server, 700.0)
		_landmark(art, i)
		art.lantern(Vector3(-7, 0, 4), 3.3)
		art.finish()
	_scatter()

func _surface(offset: Vector2) -> Transform3D:
	var distance := offset.length()
	var tangent := (_pad.basis.x * offset.x + _pad.basis.z * offset.y).normalized()
	var normal := _pad.basis.y if distance < 0.001 else _pad.basis.y * cos(distance / _radius) + tangent * sin(distance / _radius)
	var right := (_pad.basis.x - normal * normal.dot(_pad.basis.x)).normalized()
	return Transform3D(Basis(right, normal, right.cross(normal)), normal * _radius)

func _globe() -> void:
	if _surface_mesh == null:
		_surface_mesh = SphereMesh.new()
		_surface_mesh.radius = 1.0
		_surface_mesh.height = 2.0
		_surface_mesh.radial_segments = 256
		_surface_mesh.rings = 128
		_shell_mesh = SphereMesh.new()
		_shell_mesh.radius = 1.0
		_shell_mesh.height = 2.0
		_shell_mesh.radial_segments = 96
		_shell_mesh.rings = 48
	var id: String = _planet.id
	if not _materials.has(id):
		var material := ShaderMaterial.new()
		material.shader = load("res://shaders/space_planet.gdshader")
		for i in 5:
			material.set_shader_parameter(["earth", "bright", "shade", "magic", "accent"][i], _colors[i])
		material.set_shader_parameter("radius", _radius)
		material.set_shader_parameter("pad_normal", _pad.basis.y)
		material.set_shader_parameter("biome", PLACES.keys().find(id))
		_materials[id] = material
		var atmosphere := ShaderMaterial.new()
		atmosphere.shader = load("res://shaders/space_atmosphere.gdshader")
		atmosphere.set_shader_parameter("tint", _colors[3])
		atmosphere.set_shader_parameter("strength", 0.34 if _planet.region == "haven" else 0.18)
		_atmospheres[id] = atmosphere
	var surface := MeshInstance3D.new()
	surface.mesh = _surface_mesh
	surface.scale = Vector3.ONE * _radius
	surface.material_override = _materials[id]
	# Unit sphere displacement is converted to metres before instance scaling.
	surface.custom_aabb = AABB(-Vector3.ONE * 1.05, Vector3.ONE * 2.1)
	add_child(surface)
	var shell := MeshInstance3D.new()
	shell.mesh = _shell_mesh
	shell.scale = Vector3.ONE * (_radius + 3.7)
	shell.material_override = _atmospheres[id]
	shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(shell)
	if id == "tidewell":
		var sea := MeshInstance3D.new()
		sea.mesh = _shell_mesh
		sea.scale = Vector3.ONE * (_radius - 0.18)
		var water := StandardMaterial3D.new()
		water.albedo_color = _colors[0]
		water.emission_enabled = true
		water.emission = _colors[1] * 0.12
		water.roughness = 0.28
		sea.material_override = water
		add_child(sea)

func _landing() -> void:
	var landing := Node3D.new()
	landing.name = "LandingPad"
	landing.transform = _pad
	add_child(landing)
	var art := NexusStation.Brush.new(landing, _server, 700.0)
	var timber := Color("785137")
	var brass := Color("d6ad67")
	art.round_part(Vector3(0, -0.2, 0), 14, 0.4, timber, true)
	# Overlapping shallow steps meet even the smallest sphere without a cliff.
	for i in range(12, 0, -1):
		var top := -0.25 * i
		art.round_part(Vector3(0, top - 0.22, 0), 14 + i * 0.45, 0.44, timber.darkened(0.12), true)
	if not _server:
		for i in 48:
			var angle := i * TAU / 48
			art.box(Vector3(sin(angle) * 13.3, 0.03, cos(angle) * 13.3), Vector3(0.45, 0.06, 0.45), brass, false, 0.9)
		for i in 9:
			art.box(Vector3(-3.2 + i * 0.8, 0.025, 0), Vector3(0.08, 0.04, 7), brass)
	for at: Vector3 in [Vector3(-10, 0, -7), Vector3(10, 0, -7), Vector3(-10, 0, 7), Vector3(10, 0, 7)]:
		art.lantern(at, 3.5)
	art.round_part(Vector3(0, 0.45, -11), 0.9, 0.9, brass, true)
	art.crystal(Vector3(0, 0.9, -11), 2.3, Color("85efb0"))
	art.finish()
	if not _server:
		var light := OmniLight3D.new()
		light.position = Vector3(0, 4, -8)
		light.light_color = Color("ffd6a0")
		light.light_energy = 1.2
		light.omni_range = 24
		light.distance_fade_enabled = true
		light.distance_fade_begin = 100
		light.distance_fade_length = 60
		light.shadow_enabled = false
		landing.add_child(light)

func _landmark(art: NexusStation.Brush, index: int) -> void:
	var timber := Color("75503d")
	var brass := Color("caa46a")
	var primary := Color("8ed0aa") if _server else _colors[0]
	var magic := Color("a4e3bc") if _server else _colors[3]
	match String(_planet.id):
		"verdance":
			if index == 1:
				for j in 7: _mushroom(art, Vector3((j % 3 - 1) * 4, 0, -floorf(j / 3.0) * 4), 5 + j % 3, primary, magic)
			else:
				_tree(art, Vector3.ZERO, 15 + index * 2, primary, true)
				art.box(Vector3(0, 8, 0), Vector3(10, 0.5, 9), timber, true)
				art.box(Vector3(0, 10.4, -2), Vector3(5, 4.5, 0.4), timber, true)
				for side in [-1.0, 1.0]:
					art.box(Vector3(side * 3, 10, 0), Vector3(0.4, 4, 4), timber, true)
				art.part("cone", Transform3D(Basis.IDENTITY, Vector3(0, 13.5, -1)), Vector3(10, 3, 9), magic)
				# Broad walkable stair run up to the open treehouse balcony.
				for stair in range(-8, 33):
					var top := (stair + 1) * 0.25
					art.box(Vector3(18.2 - stair * 0.42, top - 0.2, 0), Vector3(0.46, 0.4, 2.5), timber, true)
		"rosamund":
			_shrine(art, primary, magic, index)
			for j in 5:
				_tree(art, Vector3((j - 2) * 4, 0, -6), 7 + j % 3, primary.lightened(0.12), false)
		"amberfall":
			if index == 1:
				_tower(art, timber, magic, 23)
			elif index == 2:
				art.round_part(Vector3(0, 1, 0), 4, 2, brass, true)
				art.round_part(Vector3(0, 2.04, 0), 3, 0.08, Color("ffb83e"), false, 0.4)
			else:
				for j in 3: _hut(art, Vector3((j - 1) * 9, 0, -3), timber, primary, 0.0)
		"tidewell":
			if index == 1:
				_tower(art, Color("eee0ba"), magic, 27)
			else:
				for j in 3: _hut(art, Vector3((j - 1) * 9, 0, -4), timber, primary, 2.0)
				for j in 16:
					art.box(Vector3(0, 0.1 + j * 0.13, 12 - j * 0.65), Vector3(3.5, 0.25, 0.72), timber, true)
		"shardheart":
			for j in 9:
				var angle := j * TAU / 9
				art.crystal(Vector3(cos(angle) * 7, 0, sin(angle) * 7), 10 + (j * 7 + index * 3) % 17, magic if j % 2 else primary, true)
			_shrine(art, Color("34485c"), magic, index)
		"hollowmoon":
			if index == 0 or index == 3:
				_observatory(art, primary, magic)
			else:
				for j in 7: _bone_tree(art, Vector3((j % 3 - 1) * 5, 0, -floorf(j / 3.0) * 5), 9 + j % 4)
		"mawgrave":
			for j in 6:
				var at := Vector3((j % 3 - 1) * 6, 0, -floorf(j / 3.0) * 7)
				_mushroom(art, at, 11 + j % 3 * 3, primary, magic)
				if index != 1:
					art.part("sphere", Transform3D(Basis.IDENTITY, at + Vector3.UP * 5), Vector3(6, 10, 6), primary.darkened(0.3))
					art.box(at + Vector3(0, 3, 3), Vector3(1, 3.5, 0.15), magic, false, 1.4)
		"pale_eye":
			for j in 7:
				var angle := j * TAU / 7
				var at := Vector3(sin(angle) * 8, 0, cos(angle) * 8)
				art.crystal(at, 16 + (j * 7 + index) % 17, Color("232736"), true)
				art.crystal(at + Vector3(0, 8, 0), 7, magic)
			if index == 1: _observatory(art, Color("555e73"), magic)
			else: _shrine(art, Color("303344"), magic, index)

func _tree(art: NexusStation.Brush, at: Vector3, height: float, color: Color, solid: bool) -> void:
	art.box(at + Vector3.UP * height * 0.4, Vector3(1.5, height * 0.8, 1.5), Color("6d4839"), solid)
	for j in 7:
		var angle := j * 2.4
		art.box(at + Vector3(sin(angle) * 3, height * 0.7 + j % 3, cos(angle) * 3), Vector3(5, 3, 5), color.lightened(j % 3 * 0.06))

func _mushroom(art: NexusStation.Brush, at: Vector3, height: float, color: Color, magic: Color) -> void:
	art.round_part(at + Vector3.UP * height * 0.4, height * 0.09, height * 0.8, Color("c8b899"), true)
	art.part("sphere", Transform3D(Basis.IDENTITY, at + Vector3.UP * height * 0.8), Vector3(height * 0.9, height * 0.35, height * 0.9), color)
	for j in 5:
		art.box(at + Vector3(sin(j * 2.4) * height * 0.22, height * 0.96, cos(j * 2.4) * height * 0.22), Vector3.ONE * height * 0.07, magic, false, 1.4)

func _hut(art: NexusStation.Brush, at: Vector3, timber: Color, cloth: Color, stilts: float) -> void:
	for x in [-2.7, 2.7]:
		for z in [-2.3, 2.3]: art.box(at + Vector3(x, 2.5 + stilts * 0.5, z), Vector3(0.35, 5 + stilts, 0.35), timber, true)
	art.box(at + Vector3.UP * (0.3 + stilts), Vector3(6, 0.5, 5.5), timber, true)
	art.box(at + Vector3(0, 2.3 + stilts, -2.4), Vector3(5.5, 4, 0.3), timber, true)
	for j in 6:
		art.box(at + Vector3(-2.5 + j, 4.5 + stilts, 0), Vector3(1, 0.3, 6.5), cloth if j % 2 else Color("edcd99"))
	art.lantern(at + Vector3(2.5, stilts, 2.2), 3.5)

func _tower(art: NexusStation.Brush, color: Color, magic: Color, height: float) -> void:
	art.round_part(Vector3.UP * height * 0.5, 2.7, height, color, true)
	for level in 4:
		art.round_part(Vector3.UP * (3 + level * 5), 3.4, 0.45, Color("b99860"))
	art.round_part(Vector3.UP * (height + 0.2), 4.4, 0.4, Color("b99860"))
	art.part("sphere", Transform3D(Basis.IDENTITY, Vector3.UP * (height + 2)), Vector3(3, 3, 3), magic, false, 2.5)
	art.part("cone", Transform3D(Basis.IDENTITY, Vector3.UP * (height + 4.4)), Vector3(6, 2, 6), color)

func _shrine(art: NexusStation.Brush, stone: Color, magic: Color, index: int) -> void:
	art.round_part(Vector3(0, 0.12, 0), 5, 0.24, stone, true)
	for side in [-1.0, 1.0]:
		art.box(Vector3(side * 3.5, 3, -2), Vector3(1, 6, 1), stone, true)
	art.box(Vector3(0, 6, -2), Vector3(8, 0.8, 1), stone, true)
	art.crystal(Vector3(0, 0.24, -1), 4 + index, magic, true)

func _bone_tree(art: NexusStation.Brush, at: Vector3, height: float) -> void:
	var bone := Color("c8c4b0")
	art.box(at + Vector3.UP * height * 0.5, Vector3(0.9, height, 0.9), bone, true)
	for side in [-1.0, 1.0]:
		art.part("box", Transform3D(Basis(Vector3.FORWARD, side * 0.7), at + Vector3(side * 1.8, height * 0.7, 0)), Vector3(0.65, 5, 0.65), bone)
		art.crystal(at + Vector3(side * 3.1, height * 0.9, 0), 1.2, Color("9cfb94"))

func _observatory(art: NexusStation.Brush, stone: Color, magic: Color) -> void:
	for j in 9:
		if j % 4 == 0: continue
		var angle := j * TAU / 9
		art.box(Vector3(sin(angle) * 7, 2 + j % 3, cos(angle) * 7), Vector3(1.5, 4 + j % 3 * 2, 1.5), stone, true)
	art.round_part(Vector3(0, 0.12, 0), 5, 0.24, stone, true)
	art.box(Vector3(0, 1.5, 0), Vector3(1.5, 3, 1.5), stone, true)
	art.part("cylinder", Transform3D(Basis(Vector3.RIGHT, 0.9), Vector3(0, 4, 0)), Vector3(2, 7, 2), Color("947c53"), true)
	art.part("sphere", Transform3D(Basis.IDENTITY, Vector3(0, 6.2, 2.8)), Vector3.ONE * 1.5, magic, false, 1.5)

func _scatter() -> void:
	var grove := Node3D.new()
	grove.name = "SurfaceGardens"
	grove.transform = _pad
	add_child(grove)
	var art := NexusStation.Brush.new(grove, _server, 700.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = String(_planet.id).hash()
	for i in 54:
		var angle := i * 2.39996
		var arc := 30 + sqrt(float(i) / 54.0) * 112
		var offset := Vector2(cos(angle), sin(angle)) * arc
		var clear := false
		for spot: Transform3D in anchors.spots.values():
			if spot.origin.distance_to(_surface(offset).origin) < 23: clear = true
		if clear: continue
		var frame := _pad.affine_inverse() * _surface(offset)
		var height := rng.randf_range(2.5, 7.0)
		var color := Color("738566") if _server else _colors[i % 2]
		match String(_planet.id):
			"verdance", "rosamund":
				art.part("box", frame.translated_local(Vector3.UP * height * 0.4), Vector3(0.65, height * 0.8, 0.65), Color("75503d"), true)
				art.part("box", frame.translated_local(Vector3.UP * height * 0.9), Vector3(height * 0.8, height * 0.5, height * 0.8), color)
			"amberfall":
				art.part("box", frame.translated_local(Vector3.UP * 1.2), Vector3(0.18, 2.4, 0.18), Color("8a6944"))
				art.part("box", frame.translated_local(Vector3.UP * 2.5), Vector3(0.6, 0.8, 0.6), Color("ffd58e"), false, 2.0)
			"tidewell":
				art.part("box", frame.translated_local(Vector3.UP * 1.4), Vector3(0.5, 2.8, 0.5), Color("679c63"))
				art.part("box", frame.translated_local(Vector3.UP * 2.8), Vector3(3.5, 0.3, 3.5), Color("82c77d"))
			"mawgrave":
				art.part("cylinder", frame.translated_local(Vector3.UP * height * 0.35), Vector3(0.8, height * 0.7, 0.8), color, true)
				art.part("sphere", frame.translated_local(Vector3.UP * height * 0.75), Vector3(height, height * 0.3, height), color, false, 0.12)
			_:
				art.part("cone", frame.translated_local(Vector3.UP * height * 0.5), Vector3(height * 0.4, height, height * 0.4), color, false, 0.25)
				art.part("box", frame.translated_local(Vector3.UP * height * 0.2), Vector3(height * 0.15, height * 0.4, height * 0.15), color, true)
	art.finish()
