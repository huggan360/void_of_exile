class_name SpaceBackdrop
extends Node3D
## Haven starlight, the distant Gloam and the crystal Shardfield.

static var _sky_environment: Environment
static var _rocks: Array[ArrayMesh] = []
var _server := false

func build(server: bool) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_server = server
	if server: return
	_asteroids()
	_pass_lanterns()
	var sun_position := Vector3(-7000, 4800, -12500)
	var sun := DirectionalLight3D.new()
	sun.name = "HavenSunlight"
	sun.basis = Basis.looking_at(-sun_position.normalized(), Vector3.UP)
	sun.light_color = Color("ffdfab")
	sun.light_energy = 1.15
	sun.shadow_enabled = false
	add_child(sun)
	var art := NexusStation.Brush.new(self, false)
	art.part("sphere", Transform3D(Basis.IDENTITY, sun_position), Vector3.ONE * 1150, Color("ffd49a"), false, 5.5)
	# Distant companion worlds add scale without intruding on playable space.
	for i in 3:
		var at := Vector3(-10500 + i * 9500, -3500 - i * 900, -14000 + i * 1800)
		art.part("sphere", Transform3D(Basis.IDENTITY, at), Vector3.ONE * (450 + i * 170), Color("354d63") if i % 2 else Color("795371"))
	art.finish()
	var halo := MeshInstance3D.new()
	halo.mesh = NexusStation.Brush.mesh("sphere")
	halo.position = sun_position
	halo.scale = Vector3.ONE * 1420
	var halo_material := ShaderMaterial.new()
	halo_material.shader = load("res://shaders/space_atmosphere.gdshader")
	halo_material.set_shader_parameter("tint", Color("ffc785"))
	halo_material.set_shader_parameter("strength", 2.3)
	halo.material_override = halo_material
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(halo)

func environment() -> Environment:
	if _server: return null
	if _sky_environment == null:
		_sky_environment = Environment.new()
		_sky_environment.background_mode = Environment.BG_SKY
		var sky := Sky.new()
		var material := ShaderMaterial.new()
		material.shader = load("res://shaders/space_sky.gdshader")
		sky.sky_material = material
		sky.radiance_size = Sky.RADIANCE_SIZE_256
		_sky_environment.sky = sky
		_sky_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		_sky_environment.ambient_light_color = Color("9ca9c4")
		_sky_environment.ambient_light_energy = 0.48
		_sky_environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
		_sky_environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
		_sky_environment.glow_enabled = true
		_sky_environment.glow_intensity = 0.85
		_sky_environment.glow_bloom = 0.12
		_sky_environment.fog_enabled = false
		_sky_environment.volumetric_fog_enabled = false
	return _sky_environment

func _rock_mesh(variant: int) -> ArrayMesh:
	if _rocks.size() > variant: return _rocks[variant]
	# Cube-sphere facets remain chunky even when the largest rocks fill the view.
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var rng := RandomNumberGenerator.new()
	rng.seed = 824 + variant * 237
	var warp := Vector3(rng.randf_range(0.75, 1), rng.randf_range(0.7, 1), rng.randf_range(0.8, 1))
	var faces: Array[Vector3] = [Vector3.RIGHT, Vector3.LEFT, Vector3.UP, Vector3.DOWN, Vector3.FORWARD, Vector3.BACK]
	for normal in faces:
		var u := normal.cross(Vector3.UP if absf(normal.y) < 0.9 else Vector3.RIGHT).normalized()
		var v := normal.cross(u)
		for y in 3:
			for x in 3:
				var points: Array[Vector3] = []
				for offset: Vector2 in [Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 1)]:
					var direction := (normal + u * ((x + offset.x) / 3.0 * 2 - 1) + v * ((y + offset.y) / 3.0 * 2 - 1)).normalized()
					var lump := 0.87 + sin(direction.dot(Vector3(7.3, 5.1, 8.7)) + variant) * 0.10
					points.append(direction * warp * lump)
				for tri: Vector3i in [Vector3i(0, 2, 1), Vector3i(1, 2, 3)]:
					var a := points[tri.x]
					var b := points[tri.y]
					var c := points[tri.z]
					var n := (c - a).cross(b - a).normalized()
					vertices.append_array(PackedVector3Array([a, b, c]))
					normals.append_array(PackedVector3Array([n, n, n]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_rocks.append(mesh)
	return mesh

func _asteroids() -> void:
	var rocks: Array = [[], [], []]
	var rng := RandomNumberGenerator.new()
	rng.seed = 52781
	var crystals := NexusStation.Brush.new(self, false)
	for entry: Array in SpaceLayout.asteroids():
		var at: Vector3 = entry[0]
		var radius: float = entry[1]
		var rotation := Basis.from_euler(Vector3(rng.randf() * TAU, rng.randf() * TAU, rng.randf() * TAU))
		var variant := rng.randi_range(0, 2)
		var color := Color("4d495e").lerp(Color("8b7470"), rng.randf() * 0.65)
		rocks[variant].append([Transform3D(rotation.scaled_local(Vector3.ONE * radius), at), color])
		if entry[2]:
			for j in 4:
				var size := Vector3(radius * 0.24, radius * rng.randf_range(0.6, 1.3), radius * 0.24)
				var frame := Transform3D(rotation, at).translated_local(Vector3((j - 1.5) * radius * 0.22, radius * 0.6, 0))
				crystals.part("cone", frame, size, Color("79e7c5") if variant % 2 else Color("e69cd5"), false, 1.7)
	for variant in 3:
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.use_colors = true
		multi.mesh = _rock_mesh(variant)
		multi.instance_count = rocks[variant].size()
		for i in rocks[variant].size():
			multi.set_instance_transform(i, rocks[variant][i][0])
			multi.set_instance_color(i, rocks[variant][i][1])
		var material := StandardMaterial3D.new()
		material.vertex_color_use_as_albedo = true
		material.roughness = 0.95
		var instance := MultiMeshInstance3D.new()
		instance.multimesh = multi
		instance.material_override = material
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(instance)
	crystals.finish()

func _pass_lanterns() -> void:
	var art := NexusStation.Brush.new(self, false)
	for pass_position: Vector3 in SpaceLayout.passes():
		for z in [-680.0, 0.0, 680.0]:
			for i in 8:
				var angle := TAU * i / 8
				var at := pass_position + Vector3(cos(angle) * 155, sin(angle) * 155, z)
				art.part("sphere", Transform3D(Basis.IDENTITY, at), Vector3.ONE * 6, Color("ffd18a"), false, 2.4)
				art.box(at + Vector3(0, -6, 0), Vector3(1, 9, 1), Color("bd935b"))
				art.crystal(at + Vector3(0, 4, 0), 5, Color("8bedbe"))
	art.finish()
