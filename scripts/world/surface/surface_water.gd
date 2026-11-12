class_name SurfaceWater
## Rivers, lakes and waterfalls of the Surface (the sea is one plane, see
## GameWorld._add_water). Built per 32 m chunk from SurfaceMap's water
## heights: a sheet whose corners average the neighbouring cells, so rivers
## slope smoothly downstream, and where the surface drops more than half a
## meter between cells, a falling curtain with foam at its foot. Vertex
## colours carry the flow direction for the shader.

const CHUNK := 32
const DROP := 0.5  # meters: a steeper step becomes a little fall
static var _material: ShaderMaterial
static var _fall_material: ShaderMaterial


static var _sea_material: ShaderMaterial


static func material() -> ShaderMaterial:
	if _material == null:
		_material = _water(true)
	return _material


## The sea: the same water without a current.
static func sea_material() -> ShaderMaterial:
	if _sea_material == null:
		_sea_material = _water(false)
		_sea_material.set_shader_parameter("clarity", 3.2)
	return _sea_material


static func _water(flowing: bool) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/surface_water.gdshader")
	mat.set_shader_parameter("use_flow", flowing)
	mat.set_shader_parameter("normal_a", _ripples(0.035, 41))
	mat.set_shader_parameter("normal_b", _ripples(0.09, 77))
	var foam := _ripples(0.05, 13)
	foam.as_normal_map = false
	mat.set_shader_parameter("foam_noise", foam)
	return mat


static func _ripples(frequency: float, seed_value: int) -> NoiseTexture2D:
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = frequency
	noise.fractal_octaves = 3
	noise.seed = seed_value
	var tex := NoiseTexture2D.new()
	tex.noise = noise
	tex.width = 256
	tex.height = 256
	tex.seamless = true
	tex.as_normal_map = true
	tex.bump_strength = 6.0
	tex.generate_mipmaps = true
	return tex


static func fall_material() -> ShaderMaterial:
	if _fall_material == null:
		_fall_material = ShaderMaterial.new()
		_fall_material.shader = preload("res://shaders/surface_waterfall.gdshader")
	return _fall_material


## The water of one chunk (null when it has none).
static func build_chunk(map: SurfaceMap, area: Rect2i) -> Node3D:
	var w := area.size.x
	var levels := PackedFloat32Array()
	levels.resize((w + 2) * (w + 2))
	var any := false
	for z in range(-1, w + 1):
		for x in range(-1, w + 1):
			var v := map.cell_water(area.position.x + x, area.position.y + z)
			levels[(z + 1) * (w + 2) + x + 1] = v / float(SurfaceMap.FINE) if v > 0 else -1.0
			if v > 0 and x >= 0 and z >= 0 and x < w and z < w: any = true
	if not any: return null
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var falls := SurfaceTool.new()
	falls.begin(Mesh.PRIMITIVE_TRIANGLES)
	var has_falls := false
	var origin := Vector2(area.position)
	var currents := {}  # corner -> flow colour
	for z in w:
		for x in w:
			var h := _level(levels, w, x, z)
			if h < 0.0: continue
			# Corner heights: the mean of the wet cells around each corner,
			# never more than a step from this cell (falls stay sharp).
			var corners: Array[float] = []
			for c: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1)]:
				var total := 0.0
				var count := 0
				for o: Vector2i in [Vector2i(-1, -1), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(0, 0)]:
					var v := _level(levels, w, x + c.x + o.x, z + c.y + o.y)
					if v >= 0.0 and absf(v - h) < DROP:
						total += v
						count += 1
				corners.append(total / count if count > 0 else h)
			var p := origin + Vector2(x, z)
			var verts := [Vector3(p.x, corners[0], p.y), Vector3(p.x + 1, corners[1], p.y),
				Vector3(p.x + 1, corners[2], p.y + 1), Vector3(p.x, corners[3], p.y + 1)]
			# The current per corner, from the river's course: it turns smoothly
			# with the river instead of jumping from cell to cell.
			var colors: Array[Color] = []
			for k in 4:
				var corner: Vector3 = verts[k]
				var key := Vector2i(roundi(corner.x), roundi(corner.z))
				if not currents.has(key):
					# The mean of the four cells around the corner: smooth.
					var c := (map.cell_current(key.x - 1, key.y - 1) + map.cell_current(key.x, key.y - 1)
						+ map.cell_current(key.x - 1, key.y) + map.cell_current(key.x, key.y)) * 0.25
					var dir := c.normalized() if c.length() > 0.001 else Vector2.ZERO
					currents[key] = Color(dir.x * 0.5 + 0.5, dir.y * 0.5 + 0.5, clampf(c.length(), 0.0, 1.0))
				colors.append(currents[key])
			st.set_normal(Vector3.UP)
			for i: int in [0, 1, 2, 0, 2, 3]:
				st.set_color(colors[i])
				st.add_vertex(verts[i])
			# Falls over the edges where the next cell's water lies lower.
			for side: Array in [[Vector2i(1, 0), 1, 2], [Vector2i(-1, 0), 3, 0], [Vector2i(0, 1), 2, 3], [Vector2i(0, -1), 0, 1]]:
				var o: Vector2i = side[0]
				var below := _level(levels, w, x + o.x, z + o.y)
				if below >= 0.0 and h - below > DROP:
					var a: Vector3 = verts[side[1]]
					var b: Vector3 = verts[side[2]]
					_curtain(falls, a, b, below, Vector3(o.x, 0, o.y))
					has_falls = true
	var root := Node3D.new()
	root.name = "Water"
	var sheet := MeshInstance3D.new()
	sheet.mesh = st.commit()
	sheet.material_override = material()
	sheet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sheet.visibility_range_end = 220.0
	root.add_child(sheet)
	if has_falls:
		var curtain := MeshInstance3D.new()
		curtain.mesh = falls.commit()
		curtain.material_override = fall_material()
		curtain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(curtain)
	return root


static func _level(levels: PackedFloat32Array, w: int, x: int, z: int) -> float:
	if x < -1 or z < -1 or x > w or z > w: return -1.0
	return levels[(z + 1) * (w + 2) + x + 1]


## A falling sheet from the edge a-b down to `bottom`, bowing outward a little.
static func _curtain(st: SurfaceTool, a: Vector3, b: Vector3, bottom: float, out: Vector3) -> void:
	var rows := 4
	var height := a.y - bottom
	for r in rows:
		var t0 := float(r) / rows
		var t1 := float(r + 1) / rows
		var a0 := a + out * (sin(t0 * PI * 0.5) * 0.35) + Vector3.DOWN * height * t0
		var b0 := b + out * (sin(t0 * PI * 0.5) * 0.35) + Vector3.DOWN * height * t0
		var a1 := a + out * (sin(t1 * PI * 0.5) * 0.35) + Vector3.DOWN * height * t1
		var b1 := b + out * (sin(t1 * PI * 0.5) * 0.35) + Vector3.DOWN * height * t1
		st.set_normal(out)
		for v: Array in [[a0, t0], [b0, t0], [b1, t1], [a0, t0], [b1, t1], [a1, t1]]:
			st.set_uv(Vector2(0.0, v[1]))
			st.set_uv2(Vector2(height, 0.0))
			st.add_vertex(v[0])


## Mist and spray at the foot of a big waterfall (from the baked list).
static func waterfall_mist(fall: Dictionary) -> GPUParticles3D:
	var mist := GPUParticles3D.new()
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(float(fall.width) * 0.5, 0.2, 0.6)
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 50.0
	pm.initial_velocity_min = 0.6
	pm.initial_velocity_max = 1.8
	pm.gravity = Vector3(0, -0.4, 0)
	pm.scale_min = 0.6
	pm.scale_max = 1.6
	pm.color = Color(0.92, 0.96, 1.0, 0.35)
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0.5))
	fade.set_color(1, Color(1, 1, 1, 0.0))
	var ramp := GradientTexture1D.new()
	ramp.gradient = fade
	pm.color_ramp = ramp
	mist.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(0.5, 0.5)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.vertex_color_use_as_albedo = true
	quad.material = mat
	mist.draw_pass_1 = quad
	mist.amount = 48
	mist.lifetime = 2.2
	mist.visibility_aabb = AABB(Vector3(-6, -1, -6), Vector3(12, 8, 12))
	mist.position = Vector3(float(fall.x), float(fall.bottom) + 0.2, float(fall.z))
	mist.rotation.y = -float(fall.dir) + PI * 0.5
	return mist
