class_name SpaceBackdrop
extends Node3D
## The dark between the worlds: a deep sky with the Haven sun, depth fog that
## swallows anything far away (only the glorias of planets reach across it),
## drifting dust around the camera, the crystal
## Shardfield with distance detail, and the red barrier at the edge of the
## Reach. On a planet's ground the fog and light take on that world's air.

## Toward the Haven sun (world space). The sky draws it; planets light by it.
const SUN_DIR := Vector3(-0.47, 0.32, -0.83)  # the far sun, drawn by the sky
const SPACE_FOG := Color(0.004, 0.005, 0.011)
const FOG_BEGIN := 2600.0
const FOG_END := 15000.0
const CELL := 5000.0  # asteroid batches, for distance culling

static var _sky_environment: Environment
static var _rocks: Array[ArrayMesh] = []
var _server := false
var _dust: GPUParticles3D
var _dust_material: ParticleProcessMaterial
var _barrier: MeshInstance3D
var _light: DirectionalLight3D
var _air_k := 0.0
var _air_up := Vector3.UP

## The sun as currently lit (it swings to daylight over a landing site).
static func sun_direction() -> Vector3:
	return _sun

func build(server: bool) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_server = server
	if server: return
	_asteroids()
	_pass_lanterns()
	_dust_field()
	_edge()
	_build_surface()
	var sun := DirectionalLight3D.new()
	_light = sun
	sun.name = "HavenSunlight"
	sun.basis = Basis.looking_at(-sun_direction(), Vector3.UP)
	sun.light_color = Color("ffdfab")
	sun.light_energy = 0.8
	sun.shadow_enabled = false
	add_child(sun)

func environment() -> Environment:
	if _server: return null
	if _sky_environment == null:
		_sky_environment = Environment.new()
		_sky_environment.background_mode = Environment.BG_SKY
		var sky := Sky.new()
		var material := ShaderMaterial.new()
		material.shader = load("res://shaders/space_sky.gdshader")
		material.set_shader_parameter("sun_dir", sun_direction())
		sky.sky_material = material
		sky.radiance_size = Sky.RADIANCE_SIZE_256
		_sky_environment.sky = sky
		_sky_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		_sky_environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
		_sky_environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
		# A darker, moodier Reach: lanterns and crystals carry the scenes.
		_sky_environment.tonemap_exposure = 0.78
		_sky_environment.glow_enabled = true
		_sky_environment.glow_intensity = 0.7
		_sky_environment.glow_bloom = 0.14
		_sky_environment.adjustment_enabled = true
		_sky_environment.adjustment_saturation = 1.18
		_sky_environment.adjustment_contrast = 1.06
		_sky_environment.fog_enabled = true
		_sky_environment.fog_mode = Environment.FOG_MODE_DEPTH
		_sky_environment.fog_sky_affect = 0.0
		_sky_environment.volumetric_fog_enabled = false
	set_air({}, 0.0)
	# The same light as the realms: the player's GI, occlusion and sun shadows.
	if is_instance_valid(_light): GraphicsSettings.apply_atmosphere(_sky_environment, _light, AppSettings.graphics)
	return _sky_environment

static var _sun := SUN_DIR.normalized()
static var _air_id := ""
static var _air_amount := 0.0

## How far the camera is inside planet `id`'s air (0 in space, 1 on the ground).
static func air_amount(id: String) -> float:
	return _air_amount if id==_air_id else 0.0

## Space by default; inside a planet's `air` (amount 0..1, 1 on the ground)
## its day sky replaces space, a light horizon haze hides the far ground and
## the sun swings toward a friendly afternoon over `up` so every landing
## site is in daylight.
func set_air(air: Dictionary, amount: float, up := Vector3.UP) -> void:
	var env := _sky_environment
	if env==null: return
	var k := smoothstep(0.0, 1.0, clampf(amount, 0.0, 1.0)) if not air.is_empty() else 0.0
	_air_id = str(air.get("id", ""))
	_air_amount = k
	var sky := Color(str(air.palette[5])) if not air.is_empty() else SPACE_FOG
	var horizon := sky.darkened(0.22)
	var top := sky.darkened(0.5)
	_air_k = k
	_air_up = up.normalized()
	var material := env.sky.sky_material as ShaderMaterial
	material.set_shader_parameter("air_mix", k)
	material.set_shader_parameter("air_up", up.normalized())
	material.set_shader_parameter("air_top", top)
	material.set_shader_parameter("air_horizon", horizon)
	env.fog_light_color = SPACE_FOG.lerp(horizon.darkened(0.1), k)
	env.fog_light_energy = 1.0
	env.fog_depth_begin = lerpf(FOG_BEGIN, 900.0, k)
	env.fog_depth_end = lerpf(FOG_END, 9000.0, k)
	env.fog_depth_curve = lerpf(1.6, 2.2, k)
	env.fog_density = lerpf(1.0, 0.75, k)
	env.ambient_light_color = Color("8e9cbc").lerp(sky.lerp(Color.WHITE, 0.5), k)
	env.ambient_light_energy = lerpf(0.24, 0.3, k)
	env.tonemap_exposure = lerpf(0.78, 0.66, k)

## Sunlight comes from the burning sun itself, as seen from the eye; on a
## planet's ground it swings toward a friendly afternoon over the landing site.
func _aim_sun(eye: Vector3) -> void:
	var toward := SUN_DIR.normalized()
	if SpaceLayout.pocket_at(eye)>=0:
		# Rooms are far from everything: they keep the light of the sky above.
		toward = SUN_DIR.normalized()
	var day := toward
	if _air_k>0.0:
		var tangent := (toward-_air_up*toward.dot(_air_up)).normalized()
		if not tangent.is_finite() or tangent.length()<0.1: tangent = _air_up.cross(Vector3.RIGHT).normalized()
		day = (_air_up*0.78+tangent*0.62).normalized()
	_sun = toward.slerp(day, _air_k) if _air_k>0.0 else toward
	if _sky_environment: (_sky_environment.sky.sky_material as ShaderMaterial).set_shader_parameter("sun_dir", _sun)
	if is_instance_valid(_light): _light.basis = Basis.looking_at(-_sun, Vector3.UP if absf(_sun.y)<0.98 else Vector3.FORWARD)

## Inside a ship room: warm lantern light, a little brighter than space.
func set_indoor() -> void:
	var env := _sky_environment
	if env==null: return
	env.ambient_light_color = Color("e8d2c0")
	env.ambient_light_energy = 0.2
	env.tonemap_exposure = 0.78

func _process(_delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera==null: return
	var eye := camera.global_position
	_aim_sun(eye)
	if is_instance_valid(_dust):
		# Dust lives in world space; the emitter follows the eye in coarse steps.
		_dust.global_position = eye.snapped(Vector3.ONE*20.0)
		var region := SpaceLayout.region_at(eye)
		_dust_material.color = {haven = Color(1.0, 0.86, 0.6, 0.85), shardfield = Color(0.55, 1.0, 0.9, 0.9), gloam = Color(1.0, 0.45, 0.5, 0.7)}.get(region, Color.WHITE)
		_dust.visible = SpaceLayout.pocket_at(eye)<0
	# The ward is only drawn near the edge (its far side lies past the camera's reach).
	if is_instance_valid(_barrier): _barrier.visible = eye.length()>SpaceLayout.WORLD_RADIUS-9000.0

# --- Asteroids --------------------------------------------------------------------

## A chunky rock: an icosphere pushed out by noise and drawn flat-shaded.
func _rock_mesh(variant: int) -> ArrayMesh:
	if _rocks.size() > variant: return _rocks[variant]
	var noise := FastNoiseLite.new()
	noise.seed = 824+variant*237
	noise.frequency = 1.4
	noise.fractal_octaves = 3
	var warp := Vector3(1.0, 0.72+variant*0.08, 0.86)
	var faces := _icosphere(2)
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	for tri in range(0, faces.size(), 3):
		var points: Array[Vector3] = []
		for k in 3:
			var dir: Vector3 = faces[tri+k]
			var lump := 0.82+noise.get_noise_3dv(dir*1.7)*0.32+absf(noise.get_noise_3dv(dir*5.0))*0.08
			points.append(dir*warp*lump)
		var n := (points[2]-points[0]).cross(points[1]-points[0]).normalized()
		for k in 3:
			vertices.append(points[k])
			normals.append(n)
			# Vertex alpha marks crystal seams for the rock shader.
			var seam := 1.0 if noise.get_noise_3dv(faces[tri+k]*3.1)>0.38 else 0.0
			colors.append(Color(1, 1, 1, seam))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_rocks.append(mesh)
	return mesh

static func _icosphere(levels: int) -> PackedVector3Array:
	var t := (1.0+sqrt(5.0))*0.5
	var v: Array[Vector3] = [Vector3(-1, t, 0), Vector3(1, t, 0), Vector3(-1, -t, 0), Vector3(1, -t, 0), Vector3(0, -1, t), Vector3(0, 1, t),
		Vector3(0, -1, -t), Vector3(0, 1, -t), Vector3(t, 0, -1), Vector3(t, 0, 1), Vector3(-t, 0, -1), Vector3(-t, 0, 1)]
	var idx := [0, 11, 5, 0, 5, 1, 0, 1, 7, 0, 7, 10, 0, 10, 11, 1, 5, 9, 5, 11, 4, 11, 10, 2, 10, 7, 6, 7, 1, 8,
		3, 9, 4, 3, 4, 2, 3, 2, 6, 3, 6, 8, 3, 8, 9, 4, 9, 5, 2, 4, 11, 6, 2, 10, 8, 6, 7, 9, 8, 1]
	var tris := PackedVector3Array()
	for i in idx: tris.append(v[i].normalized())
	for l in levels:
		var next := PackedVector3Array()
		for i in range(0, tris.size(), 3):
			var a := tris[i]
			var b := tris[i+1]
			var c := tris[i+2]
			var ab := ((a+b)*0.5).normalized()
			var bc := ((b+c)*0.5).normalized()
			var ca := ((c+a)*0.5).normalized()
			next.append_array(PackedVector3Array([a, ab, ca, b, bc, ab, c, ca, bc, ab, bc, ca]))
		tris = next
	return tris

func _asteroids() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 52781
	var material := ShaderMaterial.new()
	material.shader = load("res://shaders/space_rock.gdshader")
	# Batches per cell (and giants apart) so far parts of the field cull away.
	var cells := {}
	var crystal_cells := {}
	for entry: Array in SpaceLayout.asteroids():
		var at: Vector3 = entry[0]
		var radius: float = entry[1]
		var rotation := Basis.from_euler(Vector3(rng.randf()*TAU, rng.randf()*TAU, rng.randf()*TAU))
		var variant := rng.randi_range(0, 2)
		var giant := radius>150.0
		var key := "%d:%d:%s" % [floori(at.x/CELL), floori(at.y/CELL), "g" if giant else str(variant)]
		if not cells.has(key): cells[key] = {variant = variant, giant = giant, items = []}
		var tone := Color("4d495e").lerp(Color("8b7470"), rng.randf()*0.65)
		cells[key].items.append([Transform3D(rotation.scaled_local(Vector3.ONE*radius), at), tone, rng.randf()])
		if entry[2]:
			var ckey := "%d:%d" % [floori(at.x/CELL), floori(at.y/CELL)]
			if not crystal_cells.has(ckey):
				var holder := Node3D.new()
				add_child(holder)
				# Glowing spikes only up close: far off they sparkle into a blur.
				crystal_cells[ckey] = NexusStation.Brush.new(holder, false, 3000.0)
			for j in 4:
				var size := Vector3(radius*0.24, radius*rng.randf_range(0.6, 1.3), radius*0.24)
				var frame := Transform3D(rotation, at).translated_local(Vector3((j-1.5)*radius*0.22, radius*0.62, 0))
				crystal_cells[ckey].part("cone", frame, size, Color("79e7c5") if variant % 2 else Color("e69cd5"), false, 1.7)
	for cell: Dictionary in cells.values():
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.use_colors = true
		multi.use_custom_data = true  # r: teal or pink crystal seams
		multi.mesh = _rock_mesh(cell.variant)
		multi.instance_count = cell.items.size()
		for i in cell.items.size():
			multi.set_instance_transform(i, cell.items[i][0])
			multi.set_instance_color(i, cell.items[i][1])
			multi.set_instance_custom_data(i, Color(cell.items[i][2], 0, 0, 0))
		var instance := MultiMeshInstance3D.new()
		instance.multimesh = multi
		instance.material_override = material
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# Giants loom out of the dark from further away.
		instance.visibility_range_end = 15000.0 if cell.giant else 9000.0
		instance.visibility_range_end_margin = 1500.0
		instance.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		add_child(instance)
	for brush: NexusStation.Brush in crystal_cells.values(): brush.finish()

func _pass_lanterns() -> void:
	var art := NexusStation.Brush.new(self, false, 12000.0)
	for pass_position: Vector3 in SpaceLayout.passes():
		for z in [-1900.0, -950.0, 0.0, 950.0, 1900.0]:
			for i in 10:
				var angle := TAU*i/10
				var at := pass_position+Vector3(cos(angle), sin(angle), 0)*(SpaceLayout.PASS_RADIUS-40.0)+Vector3(0, 0, z)
				art.part("sphere", Transform3D(Basis.IDENTITY, at), Vector3.ONE*9, Color("ffd18a"), false, 3.0)
				art.box(at+Vector3(0, -9, 0), Vector3(1.5, 13, 1.5), Color("bd935b"))
				art.crystal(at+Vector3(0, 6, 0), 8, Color("8bedbe"))
	art.finish()

# --- Atmosphere of space -----------------------------------------------------------

## Dust motes around the eye: they stream past and show speed and scale.
func _dust_field() -> void:
	_dust = GPUParticles3D.new()
	_dust.name = "Dust"
	_dust.amount = 1800
	_dust.lifetime = 9.0
	_dust.preprocess = 9.0
	_dust.local_coords = false
	_dust.visibility_aabb = AABB(-Vector3.ONE*400.0, Vector3.ONE*800.0)
	_dust_material = ParticleProcessMaterial.new()
	_dust_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	_dust_material.emission_box_extents = Vector3.ONE*260.0
	_dust_material.gravity = Vector3.ZERO
	_dust_material.initial_velocity_min = 0.0
	_dust_material.initial_velocity_max = 1.5
	_dust_material.direction = Vector3.UP
	_dust_material.spread = 180.0
	_dust_material.scale_min = 0.4
	_dust_material.scale_max = 1.6
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0))
	fade.add_point(0.2, Color(1, 1, 1, 1))
	fade.add_point(0.8, Color(1, 1, 1, 1))
	fade.set_color(fade.get_point_count()-1, Color(1, 1, 1, 0))
	var ramp := GradientTexture1D.new()
	ramp.gradient = fade
	_dust_material.color_ramp = ramp
	_dust.process_material = _dust_material
	var mote := QuadMesh.new()
	mote.size = Vector2.ONE*0.5
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.vertex_color_use_as_albedo = true
	mat.albedo_texture = _soft_dot()
	mat.disable_fog = true  # fog on additive motes would light the whole quad
	mote.material = mat
	_dust.draw_pass_1 = mote
	add_child(_dust)

static func _soft_dot() -> Texture2D:
	var image := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	for y in 16:
		for x in 16:
			var r := Vector2(x-7.5, y-7.5).length()/8.0
			image.set_pixel(x, y, Color(1, 1, 1, pow(clampf(1.0-r, 0.0, 1.0), 2.0)))
	return ImageTexture.create_from_image(image)

## The burning sun: churning plasma and a flickering corona.
## The Surface below all of Space: a sphere so big its top reads as a flat
## world of seas, meadows and clouds, its air glowing blue at the horizon.
const SURFACE_RADIUS := 600000.0

func _build_surface() -> void:
	var body := MeshInstance3D.new()
	body.name = "Surface"
	var sphere := SphereMesh.new()
	sphere.radius = SURFACE_RADIUS
	sphere.height = SURFACE_RADIUS*2.0
	sphere.radial_segments = 256
	sphere.rings = 128
	body.mesh = sphere
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/space_surface.gdshader")
	material.set_shader_parameter("sun_dir", SUN_DIR.normalized())
	material.set_shader_parameter("surface_y", SpaceLayout.SURFACE_Y)
	body.material_override = material
	body.position = Vector3(0, SpaceLayout.SURFACE_Y-SURFACE_RADIUS, 0)
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.extra_cull_margin = 16384.0
	add_child(body)

## The edge of the Reach: a red ward on the world sphere, seen only near it.
func _edge() -> void:
	var mesh := SphereMesh.new()
	mesh.radius = SpaceLayout.WORLD_RADIUS
	mesh.height = SpaceLayout.WORLD_RADIUS*2.0
	mesh.radial_segments = 192
	mesh.rings = 96
	_barrier = MeshInstance3D.new()
	_barrier.name = "EdgeOfTheReach"
	_barrier.mesh = mesh
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/space_barrier.gdshader")
	mat.set_shader_parameter("world_radius", SpaceLayout.WORLD_RADIUS)
	_barrier.material_override = mat
	_barrier.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_barrier.extra_cull_margin = 16384.0
	add_child(_barrier)
