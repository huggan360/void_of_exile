class_name SpacePlanet
extends Node3D
## One of the Reach's worlds: streamed terrain (PlanetTerrain), its air seen
## from orbit, a far gloria, the landing pad, the story landmarks and the
## world's plants, crystals and ruins (PlanetFlora, the realm's voxel obstacles).

var anchors: Dictionary = {}
var terrain: PlanetTerrain
var flora: PlanetFlora
static var _shell_mesh: SphereMesh
static var _quad: QuadMesh
var _planet: Dictionary
var _pad: Transform3D
var _radius: float
var _colors: Array[Color] = []
var _server := false
var _atmosphere: ShaderMaterial
var _was_near := false
var _air_strength := 1.0
var _ground_at := Vector3.INF

## Kept for older callers: the story places per planet.
const PLACES := SpaceLayout.PLACES

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
	for hex: String in planet.palette: _colors.append(Color(hex))
	anchors = {pad = _pad, spots = {}}
	var names: Array = SpaceLayout.PLACES[planet.id]
	for i in names.size():
		var spot := SpaceLayout.place_frame(planet, SpaceLayout.PLACE_OFFSETS[i])
		anchors.spots[names[i]] = spot
	if server: return
	terrain = PlanetTerrain.new()
	terrain.name = "Terrain"
	add_child(terrain)
	terrain.setup(planet)
	_air()
	if planet.get("city", false):
		# Vesperis: the whole world is the city (streets, towers, ports, people).
		var city := CityPlanet.new()
		city.name = "City"
		city.world = get_parent() as SpaceWorld
		add_child(city)
		city.build()
		return
	_landing()
	for i in names.size():
		var place := Node3D.new()
		place.name = names[i]
		# Just behind the search spot, still on its flattened ground.
		place.transform = SpaceLayout.place_frame(planet, SpaceLayout.PLACE_OFFSETS[i]+Vector2(0, -12))
		place.scale = Vector3.ONE*1.3
		add_child(place)
		var art := NexusStation.Brush.new(place, false, 1200.0)
		_landmark(art, i)
		art.lantern(Vector3(-7, 0, 4), 3.3)
		art.finish()
	flora = PlanetFlora.new()
	flora.name = "Flora"
	add_child(flora)
	flora.build(planet)
	var town := PlanetTown.new()
	town.name = "Town"
	town.world = get_parent() as SpaceWorld
	add_child(town)
	town.build(planet)

func _process(_delta: float) -> void:
	if terrain==null: return
	var world := get_parent()
	var local: Node3D = world.get("local_player") if world else null
	terrain.focus = local
	var near := is_instance_valid(local) and local.global_position.distance_to(global_position)<_radius+SpaceLayout.max_height(_planet)+80.0
	# Arriving on the ground, or moved far (hatch, teleport): build it under the feet now.
	if near and (not _was_near or local.global_position.distance_to(_ground_at)>30.0):
		terrain.ensure_ground(local.global_position)
		_ground_at = local.global_position
	if near and flora: flora.update_collision(global_transform.affine_inverse()*local.global_position)
	_was_near = near
	if _atmosphere:
		_atmosphere.set_shader_parameter("sun_dir", SpaceBackdrop.sun_direction())
		# Inside the air the sky itself turns to day; the shell would only fog it.
		_atmosphere.set_shader_parameter("strength", _air_strength*(1.0-smoothstep(0.0, 0.45, SpaceBackdrop.air_amount(_planet.id))))

func _air() -> void:
	if _shell_mesh==null:
		_shell_mesh = SphereMesh.new()
		_shell_mesh.radius = 1.0
		_shell_mesh.height = 2.0
		_shell_mesh.radial_segments = 64
		_shell_mesh.rings = 32
		_quad = QuadMesh.new()
		_quad.size = Vector2.ONE
	var thick := SpaceLayout.air_height(_planet)
	_atmosphere = ShaderMaterial.new()
	_atmosphere.shader = preload("res://shaders/planet_atmosphere.gdshader")
	_atmosphere.set_shader_parameter("sky", _colors[5])
	_atmosphere.set_shader_parameter("dusk", _colors[4].lerp(Color("ff9a6a"), 0.5))
	_atmosphere.set_shader_parameter("planet_radius", _radius)
	_atmosphere.set_shader_parameter("atmo_radius", _radius+thick)
	_air_strength = 1.0 if _planet.region=="haven" else 0.75
	_atmosphere.set_shader_parameter("strength", _air_strength)
	var shell := MeshInstance3D.new()
	shell.name = "Air"
	shell.mesh = _shell_mesh
	shell.scale = Vector3.ONE*(_radius+thick)
	shell.material_override = _atmosphere
	shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shell.sorting_offset = -10.0
	add_child(shell)
	var halo := MeshInstance3D.new()
	halo.name = "Gloria"
	halo.mesh = _quad
	halo.scale = Vector3.ONE*_radius*4.2
	var glow := ShaderMaterial.new()
	glow.shader = preload("res://shaders/planet_halo.gdshader")
	glow.set_shader_parameter("tint", _colors[5])
	glow.set_shader_parameter("planet_radius", _radius)
	glow.set_shader_parameter("strength", 0.55 if _planet.region=="haven" else 0.35)
	halo.material_override = glow
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	halo.custom_aabb = AABB(-Vector3.ONE*3.0, Vector3.ONE*6.0)
	add_child(halo)
	if bool(_planet.terrain.get("sea", false)):
		var sea := MeshInstance3D.new()
		sea.name = "Sea"
		var mesh := SphereMesh.new()
		mesh.radius = _radius
		mesh.height = _radius*2.0
		mesh.radial_segments = 160
		mesh.rings = 80
		sea.mesh = mesh
		var water := StandardMaterial3D.new()
		water.albedo_color = Color(_colors[0], 0.86)
		water.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		water.emission_enabled = true
		water.emission = _colors[1]*0.1
		water.roughness = 0.12
		water.metallic_specular = 0.8
		sea.material_override = water
		sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(sea)

func _landing() -> void:
	var landing := Node3D.new()
	landing.name = "LandingPad"
	landing.transform = _pad
	add_child(landing)
	var art := NexusStation.Brush.new(landing, false, 1500.0)
	var timber := Color("785137")
	var brass := Color("d6ad67")
	# Broad timber pad on the flattened ground, ringed in brass and lanterns.
	art.round_part(Vector3(0, -0.4, 0), 27, 0.9, timber, true)
	art.round_part(Vector3(0, 0.06, 0), 27.6, 0.06, brass)
	art.round_part(Vector3(0, 0.08, 0), 26.4, 0.04, timber.lightened(0.06))
	for i in 64:
		var angle := i*TAU/64
		art.box(Vector3(sin(angle)*25.6, 0.12, cos(angle)*25.6), Vector3(0.6, 0.08, 0.6), brass, false, 0.9)
	for i in 13:
		art.box(Vector3(-6+i, 0.11, 0), Vector3(0.12, 0.05, 12), brass)
	for i in 8:
		var angle := i*TAU/8+0.2
		art.lantern(Vector3(sin(angle)*23, 0, cos(angle)*23), 4.2)
	art.round_part(Vector3(0, 0.6, -21), 1.2, 1.2, brass, true)
	art.crystal(Vector3(0, 1.2, -21), 3.2, _colors[3].lerp(Color("85efb0"), 0.5))
	art.finish()
	var light := OmniLight3D.new()
	light.position = Vector3(0, 6, -10)
	light.light_color = Color("ffd6a0")
	light.light_energy = 1.4
	light.omni_range = 36
	light.distance_fade_enabled = true
	light.distance_fade_begin = 220
	light.distance_fade_length = 80
	light.shadow_enabled = false
	landing.add_child(light)

func _landmark(art: NexusStation.Brush, index: int) -> void:
	var timber := Color("75503d")
	var brass := Color("caa46a")
	var primary := _colors[0]
	var magic := _colors[3]
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
