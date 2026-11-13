class_name SpacePlanet
extends Node3D
## One of the Reach's worlds: streamed terrain (PlanetTerrain), its air seen
## from orbit, a far gloria, its seas and lakes, the voxel landing pad, and
## (built only while the camera is near, PlanetProps) its town, villages and
## story landmarks, its flora (PlanetFlora) and ground cover (PlanetGroundCover).

var anchors: Dictionary = {}
var terrain: PlanetTerrain
var flora: PlanetFlora
var cover: PlanetGroundCover
static var _shell_mesh: SphereMesh
static var _quad: QuadMesh
var _planet: Dictionary
var _pad: Transform3D
var _radius: float
var _colors: Array[Color] = []
var _server := false
var _atmosphere: ShaderMaterial
var _plumes: ShaderMaterial
var _was_near := false
var _air_strength := 1.0
var _ground_at := Vector3.INF
## Settlements and landmarks: {kind, dir, index, node} built near the camera.
var _sites: Array = []
var _site_timer := 0.0
const SITE_BUILD := 650.0
const SITE_DROP := 850.0

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
		var spot := SpaceLayout.place_frame(planet, SpaceLayout.place_offset(planet, i))
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
	_water()
	_landing()
	flora = PlanetFlora.new()
	flora.name = "Flora"
	add_child(flora)
	flora.build(planet)
	cover = PlanetGroundCover.new()
	cover.name = "GroundCover"
	add_child(cover)
	cover.setup(planet)
	# The town, the villages and the story landmarks come and go with the camera.
	_sites.append({kind = "town", dir = SpaceLayout.place_frame_raw(planet, SpaceLayout.town_offset(planet)), index = 0, node = null})
	for v: Dictionary in SpaceLayout.settlements(planet):
		_sites.append({kind = "village", dir = v.dir, index = _sites.size(), village = v, node = null})
	for i in names.size():
		# Just beyond the search spot, still on its levelled ground.
		var offset := SpaceLayout.place_offset(planet, i)
		_sites.append({kind = "place", dir = SpaceLayout.place_frame_raw(planet, offset*(1.0+15.0/maxf(offset.length(), 1.0))), index = i, node = null})

func _process(delta: float) -> void:
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
	_stream_sites(delta)
	if _plumes: _plumes.set_shader_parameter("sun_dir", SpaceBackdrop.sun_direction())
	if _atmosphere:
		_atmosphere.set_shader_parameter("sun_dir", SpaceBackdrop.sun_direction())
		# Inside the air the sky itself turns to day; the shell would only fog it.
		_atmosphere.set_shader_parameter("strength", _air_strength*(1.0-smoothstep(0.0, 0.45, SpaceBackdrop.air_amount(_planet.id))))

## Builds the settlements and landmarks the camera nears (one a frame) and
## frees those it has left far behind.
func _stream_sites(delta: float) -> void:
	if _sites.is_empty(): return
	_site_timer -= delta
	if _site_timer>0.0: return
	_site_timer = 0.5
	var camera := get_viewport().get_camera_3d()
	if camera==null: return
	var eye := global_transform.affine_inverse()*camera.global_position
	var view := GraphicsSettings.view_scale()
	for site: Dictionary in _sites:
		var d := eye.distance_to((site.dir as Vector3)*_radius)/view
		if site.node!=null and d>SITE_DROP:
			(site.node as Node).queue_free()
			site.node = null
		elif site.node==null and d<SITE_BUILD:
			site.node = _build_site(site)
			_site_timer = 0.0  # the next one next frame
			return

func _build_site(site: Dictionary) -> Node3D:
	match str(site.kind):
		"town":
			var town := PlanetTown.new()
			town.name = "Town"
			town.world = get_parent() as SpaceWorld
			add_child(town)
			town.build_town(_planet)
			return town
		"village":
			var village := PlanetTown.new()
			village.name = "Village_%d" % int(site.index)
			village.world = get_parent() as SpaceWorld
			add_child(village)
			village.build_village(_planet, site.village)
			return village
	var place := Node3D.new()
	place.name = str(SpaceLayout.PLACES[_planet.id][int(site.index)])
	add_child(place)
	var spot: Vector3 = SpaceLayout.place_frame_raw(_planet, SpaceLayout.place_offset(_planet, int(site.index)))
	PlanetProps.place_art(place, _planet, int(site.index), site.dir, spot)
	return place

func _air() -> void:
	if _shell_mesh==null:
		_shell_mesh = SphereMesh.new()
		_shell_mesh.radius = 1.0
		_shell_mesh.height = 2.0
		_shell_mesh.radial_segments = 64
		_shell_mesh.rings = 32
		_quad = QuadMesh.new()
		_quad.size = Vector2.ONE
	# `air` (optional) styles the look only: dusk colour, shell thickness and density.
	var air: Dictionary = _planet.get("air", {})
	var thick := SpaceLayout.air_height(_planet)*float(air.get("thick", 1.0))
	_atmosphere = ShaderMaterial.new()
	_atmosphere.shader = preload("res://shaders/planet_atmosphere.gdshader")
	_atmosphere.set_shader_parameter("sky", _colors[5])
	_atmosphere.set_shader_parameter("dusk", Color(str(air.dusk)) if air.has("dusk") else _colors[4].lerp(Color("ff9a6a"), 0.5))
	_atmosphere.set_shader_parameter("planet_radius", _radius)
	_atmosphere.set_shader_parameter("atmo_radius", _radius+thick)
	_air_strength = (1.0 if _planet.region=="haven" else 0.75)*float(air.get("strength", 1.0))
	_atmosphere.set_shader_parameter("strength", _air_strength)
	_atmosphere.set_shader_parameter("seed", float(abs(str(_planet.id).hash()) % 1000)*0.37)
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
	glow.set_shader_parameter("strength", (0.55 if _planet.region=="haven" else 0.35)*minf(float(air.get("strength", 1.0)), 1.3))
	halo.material_override = glow
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# The air streaming out into space (stronger where `air.storm` says so).
	var plumes := MeshInstance3D.new()
	plumes.name = "Plumes"
	plumes.mesh = _quad
	var span := 7.0
	plumes.scale = Vector3.ONE*_radius*span
	_plumes = ShaderMaterial.new()
	_plumes.shader = preload("res://shaders/planet_plumes.gdshader")
	_plumes.set_shader_parameter("sky", _colors[5])
	_plumes.set_shader_parameter("dusk", Color(str(air.dusk)) if air.has("dusk") else _colors[4].lerp(Color("ff9a6a"), 0.5))
	_plumes.set_shader_parameter("planet_radius", _radius)
	_plumes.set_shader_parameter("span", span)
	_plumes.set_shader_parameter("seed", float(abs(str(_planet.id).hash()) % 1000)*0.37)
	_plumes.set_shader_parameter("strength", (0.32 if _planet.region=="haven" else 0.22)*float(air.get("storm", 1.0)))
	plumes.material_override = _plumes
	plumes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	plumes.custom_aabb = AABB(-Vector3.ONE*3.0, Vector3.ONE*6.0)
	plumes.sorting_offset = -12.0
	add_child(plumes)
	halo.custom_aabb = AABB(-Vector3.ONE*3.0, Vector3.ONE*6.0)
	add_child(halo)

## The planet's seas and lakes: one sphere of the Surface's water at the
## water level (the lake beds keep it shallow, SpaceLayout._shape).
func _water() -> void:
	var level := SpaceLayout.water_level(_planet)
	if is_nan(level): return
	var set: Dictionary = PlanetFlora.SETS.get(_planet.id, {})
	var colors: Array = set.get("water", ["3fa89a", "0e4a4c"])
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/planet_water.gdshader")
	var ripples := SurfaceWater.sea_material()
	for texture: String in ["normal_a", "normal_b", "foam_noise"]: mat.set_shader_parameter(texture, ripples.get_shader_parameter(texture))
	mat.set_shader_parameter("shallow_color", Color(str(colors[0])))
	mat.set_shader_parameter("deep_color", Color(str(colors[1])))
	mat.set_shader_parameter("clarity", 3.2 if _planet.terrain.get("sea", false) else 1.6)
	mat.set_shader_parameter("glow", 0.35 if _planet.region=="gloam" else 0.0)
	var mesh := SphereMesh.new()
	mesh.radius = _radius+level
	mesh.height = (_radius+level)*2.0
	mesh.radial_segments = 192
	mesh.rings = 96
	var sea := MeshInstance3D.new()
	sea.name = "Water"
	sea.mesh = mesh
	sea.material_override = mat
	sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sea.visibility_range_end = _radius*14.0
	add_child(sea)

func _landing() -> void:
	var landing := Node3D.new()
	landing.name = "LandingPad"
	landing.transform = _pad
	add_child(landing)
	build_pad(landing, _planet, get_parent() as SpaceWorld, "%s pad crystal" % _planet.name)
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

## A planet's landing pad (a voxel model in the world's own style, PlanetProps
## STYLES `pad`: deck, glowing rim, lantern posts, a stone footing flaring
## into the ground) with the shipwright's crystal terminal (buy a ship, or
## bring one out onto this pad). Every port on a planet looks like this: the
## landing pad and the town's shipyard. Its collision is one solid sloped
## body (top and skirt together), so the rim has no seam to catch on.
static func build_pad(holder: Node3D, planet: Dictionary, world: SpaceWorld, terminal: String) -> void:
	var solid := NexusStation.Brush.new(holder, true)
	solid.round_part(Vector3(0, -0.45, 0), 27, 0.9, Color.WHITE, true)
	solid.apron(Vector3(0, 0.0, 0), 27, 4.0, Color.WHITE)
	var info: Dictionary = PlanetProps.catalog().get(str(PlanetProps.style(planet).pad), {})
	var model := VillageHouse.new().setup({asset = "res://props/"+str(PlanetProps.style(planet).pad), pos = Vector3.DOWN*(float(info.get("sink", 4.0))-0.03), yaw = 0.0, solid_size = Vector3.ZERO})
	holder.add_child(model)
	# The crystal on its pedestal glows in the world's own colour.
	var prefab := ObstacleLibrary.get_prefab("planet/shard_spire")
	var meshes := prefab.meshes_for(PlanetFlora.biome_for(planet))
	for slot in 2:
		if meshes[slot]==null: continue
		var mesh := MeshInstance3D.new()
		mesh.mesh = meshes[slot]
		mesh.material_override = VoxModel.glow_material() if slot==1 else VoxModel.material()
		mesh.position = SpaceLayout.PAD_CRYSTAL+Vector3.UP*0.5+prefab.mesh_offset()*0.55
		mesh.scale = Vector3.ONE*prefab.voxel_size*0.55
		holder.add_child(mesh)
	var shop := SpaceInteraction.new()
	shop.world = world
	shop.kind = "wright"
	shop.part = str(planet.id)
	shop.title = terminal
	shop.description = "A shipwright's terminal. Buy a ship or call one from your fleet onto this pad."
	shop.position = SpaceLayout.PAD_CRYSTAL+Vector3(0, 1.0, 1.6)
	holder.add_child(shop)
