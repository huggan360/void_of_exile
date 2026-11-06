class_name LootBag
extends Node3D
## Voxel loot chest. Internal bag IDs keep inventory and network saves compatible.
## Chests have no collision and their hinged lids never close once opened.

const SLOTS := 8
## "vault": a Chambers chest (never expires, closes when you step off it).
const TYPES := ["gray", "story", "green", "blue", "red", "purple", "white", "black", "vault"]
const NAMES := {gray = "Gray Chest", green = "Green Chest", blue = "Blue Chest", red = "Red Chest",
		purple = "Purple Chest", white = "White Chest", black = "Black Chest", story = "Story Chest", vault = "Vault Chest"}
## [paint, shaded paint, metal trim]
const COLORS := {
	gray = [Color(0.6, 0.6, 0.63), Color(0.44, 0.44, 0.48), Color(0.72, 0.58, 0.36)],
	green = [Color(0.34, 0.72, 0.32), Color(0.22, 0.52, 0.22), Color(0.72, 0.58, 0.36)],
	blue = [Color(0.28, 0.48, 0.96), Color(0.18, 0.32, 0.74), Color(0.9, 0.86, 0.7)],
	red = [Color(0.88, 0.22, 0.22), Color(0.62, 0.12, 0.14), Color(0.9, 0.8, 0.5)],
	purple = [Color(0.62, 0.3, 0.9), Color(0.42, 0.16, 0.66), Color(0.95, 0.8, 0.4)],
	white = [Color(0.97, 0.97, 0.95), Color(0.8, 0.8, 0.84), Color(1.0, 0.78, 0.3)],
	black = [Color(0.12, 0.11, 0.14), Color(0.05, 0.05, 0.07), Color(0.75, 0.45, 1.0)],
	story = [Color(1.0, 0.82, 0.22), Color(0.82, 0.6, 0.12), Color(0.55, 0.32, 0.14)],
	vault = [Color(0.55, 0.36, 0.2), Color(0.4, 0.25, 0.14), Color(0.82, 0.66, 0.34)],
}

const GRID := 32
const VOXEL := 0.035
const SIZES := {gray=0.72, green=0.82, blue=0.98, red=1.08, purple=1.18, white=1.35, black=1.42, story=1.7, vault=1.45}
const BLINK_TIME := 8.0
const POP_TIME := 0.35
static var _meshes := {}  # color -> [hollow base, hinged lid]
static var _beam_shader: Shader
static var _particle_material: ShaderMaterial

var bag_id := 0
var type := "gray"
var opened := false
var _initially_open := false
var _expires := 0
var _time := randf() * 10.0
var _model := Node3D.new()
var _lid := Node3D.new()
var _effects := Node3D.new()
var _light := OmniLight3D.new()
var _particles: GPUParticles3D
var _divine_particles: Array[GPUParticles3D] = []
var _open_amount := 0.0
var _yaw := NAN


static func is_personal(bag_type: String) -> bool:
	return TYPES.find(bag_type) >= TYPES.find("blue")


static func rank(bag_type: String) -> int:
	return TYPES.find(bag_type)


## The bag for a set of items: the color of the best one.
static func type_for(contents: Array) -> String:
	var best := "gray"
	for item: Item in contents:
		if rank(item.bag_type()) > rank(best):
			best = item.bag_type()
	return best


## Whether a bag may hold an item: soulbound items only go in personal
## bags, and elixirs only in gray ones.
static func can_hold(bag_type: String, public: bool, item: Item) -> bool:
	if bag_type == "vault":
		return not item.is_story()
	if item.is_story() or bag_type == "story":
		return item.is_story() and bag_type == "story"
	if item.is_elixir():
		return bag_type == "gray"
	return not (item.soulbound() and public)


static func display_name(bag_type: String) -> String:
	return NAMES[bag_type]


## record: the authoritative loot record, including its lasting opened flag.
func _init(record: Dictionary = {}) -> void:
	if record.is_empty(): return
	bag_id = record.id
	type = record.type
	_expires = record.expires
	_initially_open = bool(record.get("opened", false)) and record.type != "vault"
	position = record.pos
	if record.has("yaw"): _yaw = float(record.yaw)


func _ready() -> void:
	name = "LootChest_%d" % bag_id
	var meshes := _meshes_for(type)
	var body := _part(meshes[0])
	body.name = "HollowChest"
	body.position = Vector3(-16.5, -1.0, -16.5) * VOXEL
	_model.add_child(body)
	_lid.name = "HingedLid"
	_lid.position = Vector3(0, 16, 9.5) * VOXEL
	var top := _part(meshes[1])
	top.position = Vector3(-16.5, -1.0, -26.0) * VOXEL
	_lid.add_child(top)
	_model.add_child(_lid)
	_model.rotation.y = _yaw if not is_nan(_yaw) else fmod(float(bag_id) * 2.399963, TAU)
	add_child(_model)
	_build_light_and_particles()
	_model.scale = Vector3.ONE * float(SIZES[type]) * 0.01
	var tween := create_tween()
	tween.tween_property(_model, "scale", Vector3.ONE * float(SIZES[type]), POP_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if _initially_open: open_chest(true)


func _part(mesh: Mesh) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.mesh = mesh
	part.material_override = VoxModel.material()
	part.scale = Vector3.ONE * VOXEL
	return part


func divine() -> bool:
	return type in ["white", "black"]


func glow_color() -> Color:
	return Color(1.0, 0.76, 0.22) if divine() else COLORS[type][0].lightened(0.25)


func open_chest(instant := false) -> void:
	if opened: return
	opened = true
	if type == "vault":
		_swing_lid(1.0)
		return
	_effects.show()
	_particles.emitting = true
	for sparks in _divine_particles: sparks.emitting = true
	if instant:
		_set_open_amount(1.0)
	else:
		var tween := create_tween()
		tween.tween_method(_set_open_amount, 0.0, 1.0, 0.55).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


## Vault chests close again when you step off them.
func close_chest() -> void:
	if not opened: return
	opened = false
	_swing_lid(0.0)


func _swing_lid(to: float) -> void:
	var tween := create_tween()
	tween.tween_method(func(a: float) -> void: _lid.rotation.x = deg_to_rad(105.0) * a,
			_lid.rotation.x / deg_to_rad(105.0), to, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _set_open_amount(amount: float) -> void:
	_open_amount = amount
	_lid.rotation.x = deg_to_rad(105.0) * amount
	_effects.scale = Vector3.ONE * maxf(0.001, amount)


func _process(delta: float) -> void:
	_time += delta
	var life := (_expires - Time.get_ticks_msec()) / 1000.0
	_model.visible = life > BLINK_TIME or fmod(life, 0.5) > 0.2
	# This is a real light: it illuminates dungeon walls, floors and actors.
	_light.light_energy = _open_amount * (3.2 if divine() else 1.35 + rank(type) * 0.16) * (0.94 + 0.06 * sin(_time * 2.0))


func _build_light_and_particles() -> void:
	var color := glow_color()
	_model.add_child(_effects)
	_effects.position.y = 0.63
	_effects.hide()
	_light.light_color = color
	_light.light_energy = 0.0
	_light.omni_range = 8.0 if divine() else 4.0 + rank(type) * 0.45
	_light.omni_attenuation = 1.25
	_light.light_volumetric_fog_energy = 0.35 if divine() else 0.12
	_light.shadow_enabled = divine() and GraphicsSettings.lamp_shadows(AppSettings.graphics)
	_light.distance_fade_enabled = true
	_light.distance_fade_begin = 30.0
	_light.distance_fade_length = 12.0
	_light.position.y = 0.24
	_effects.add_child(_light)
	if _beam_shader == null:
		_beam_shader = Shader.new()
		_beam_shader.code = """shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec4 tint : source_color = vec4(1.0);
varying float height_fraction;
void vertex() { height_fraction = VERTEX.y / 1.8 + 0.5; }
void fragment() {
	float fade = pow(1.0 - clamp(height_fraction, 0.0, 1.0), 2.0);
	ALBEDO = tint.rgb * 2.0;
	ALPHA = fade * 0.16;
}
"""
	var beam := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.height = 1.8
	cone.bottom_radius = 0.22
	cone.top_radius = 0.6 if divine() else 0.4
	cone.radial_segments = 16
	cone.cap_top = false
	cone.cap_bottom = false
	beam.mesh = cone
	var material := ShaderMaterial.new()
	material.shader = _beam_shader
	material.set_shader_parameter("tint", color)
	beam.material_override = material
	beam.position.y = 0.9
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_effects.add_child(beam)
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(0.28, 0.03, 0.18)
	process.direction = Vector3.UP
	process.spread = 18.0 if divine() else 12.0
	process.initial_velocity_min = 0.45
	process.initial_velocity_max = 1.4 if divine() else 0.9
	process.gravity = Vector3(0, 0.12, 0)
	process.angular_velocity_min = -160.0
	process.angular_velocity_max = 160.0
	process.scale_min = 0.45
	process.scale_max = 1.2
	var gradient := Gradient.new()
	gradient.set_color(0, color.lightened(0.35))
	gradient.add_point(0.4, color)
	gradient.set_color(gradient.get_point_count() - 1, Color(color.r, color.g, color.b, 0.0))
	var ramp := GradientTexture1D.new()
	ramp.gradient = gradient
	process.color_ramp = ramp
	var shrink := Curve.new()
	shrink.add_point(Vector2(0, 0.3))
	shrink.add_point(Vector2(0.2, 1))
	shrink.add_point(Vector2(1, 0))
	var curve := CurveTexture.new()
	curve.curve = shrink
	process.scale_curve = curve
	var voxel := BoxMesh.new()
	voxel.size = Vector3.ONE * (0.065 if divine() else 0.045)
	if _particle_material == null:
		_particle_material = ShaderMaterial.new()
		_particle_material.shader = preload("res://shaders/fire_voxel.gdshader")
		_particle_material.set_shader_parameter("brightness", 3.5)
	voxel.material = _particle_material
	_particles = GPUParticles3D.new()
	_particles.process_material = process
	_particles.draw_pass_1 = voxel
	_particles.amount = 100 if divine() else 22 + rank(type) * 4
	_particles.lifetime = 2.0 if divine() else 1.5
	_particles.local_coords = false
	_particles.emitting = false
	_particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_particles.visibility_aabb = AABB(Vector3(-3, -1, -3), Vector3(6, 6, 6))
	_effects.add_child(_particles)
	if divine():
		# Two opposite spirals of gold motes crown the divine light column.
		var orbit := Node3D.new()
		_effects.add_child(orbit)
		for side in [-1.0, 1.0]:
			var sparks := GPUParticles3D.new()
			sparks.process_material = process
			sparks.draw_pass_1 = voxel
			sparks.amount = 24
			sparks.lifetime = 0.7
			sparks.local_coords = false
			sparks.emitting = false
			_divine_particles.append(sparks)
			sparks.position = Vector3(side * 0.22, 0.12, 0)
			sparks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			sparks.visibility_aabb = _particles.visibility_aabb
			orbit.add_child(sparks)
		var spin := create_tween().set_loops()
		spin.tween_property(orbit, "rotation:y", TAU, 3.0).from(0.0)


## A simple 32-voxel chest: hollow box, plank seams, two bands and a stepped lid.
## Separate meshes let the lid pivot about its back edge without deforming voxels.
static func _meshes_for(chest_type: String) -> Array:
	if _meshes.has(chest_type): return _meshes[chest_type]
	var colors: Array = COLORS[chest_type]
	var palette := VoxelColorPalette.new()
	palette.set_color(1, colors[0])
	palette.set_color(2, colors[1])
	palette.set_color(3, colors[2])
	palette.set_color(4, colors[0].lightened(0.15))
	palette.set_color(5, colors[1].darkened(0.65))
	palette.set_color(6, colors[2].lightened(0.15))
	var base := VoxelBuffer.new()
	var lid := VoxelBuffer.new()
	base.create(GRID, GRID, GRID)
	lid.create(GRID, GRID, GRID)
	for x in range(3, 29):
		for z in range(6, 26):
			for y in range(2, 16):
				if y > 4 and x > 4 and x < 27 and z > 7 and z < 24: continue
				var color := 1
				if z >= 24 or x >= 27 or y <= 4: color = 2
				if y == 15: color = 3
				elif y in [7, 11] and (z in [6, 25] or x in [3, 28]): color = 2
				if x in [7, 8, 23, 24] and (z <= 7 or z >= 24): color = 3
				if y <= 4 and x > 4 and x < 27 and z > 7 and z < 24: color = 5
				base.set_voxel(color, x, y, z, VoxelBuffer.CHANNEL_COLOR)
			var edge := mini(z - 6, 25 - z)
			var height := 3 + mini(3, edge / 2)
			for y in range(height):
				if y < height - 2 and x > 4 and x < 27 and z > 7 and z < 24: continue
				var color := 4 if y == height - 1 else 1
				if x in [7, 8, 23, 24] or x in [3, 28]: color = 3
				lid.set_voxel(color, x, y, z, VoxelBuffer.CHANNEL_COLOR)
	# Four block feet and a broad, readable front latch.
	for x in [4, 25]:
		for z in [7, 22]:
			for dx in 3:
				for dz in 3:
					for y in 2: base.set_voxel(2, x + dx, y, z + dz, VoxelBuffer.CHANNEL_COLOR)
	for x in range(14, 18):
		for y in range(12, 16): base.set_voxel(3, x, y, 5, VoxelBuffer.CHANNEL_COLOR)
	for x in range(14, 18):
		for y in range(3): lid.set_voxel(6, x, y, 5, VoxelBuffer.CHANNEL_COLOR)
	var meshes := [VoxModel.mesh_from_buffer(base, palette), VoxModel.mesh_from_buffer(lid, palette)]
	_meshes[chest_type] = meshes
	return meshes
