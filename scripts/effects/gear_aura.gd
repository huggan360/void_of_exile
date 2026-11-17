class_name GearAura
extends Node3D
## Voxel particles drifting around the character, built from the equipped
## gear: better gear means more, brighter particles in the items' colors, so
## high tiers and Divine items look powerful. Some Divine cloaks add their own
## trail (burning footprints, gold sparkle, rainbow madness).

var _orbit := GPUParticles3D.new()
var _trail := GPUParticles3D.new()
var _orbit_mat := ParticleProcessMaterial.new()
var _trail_mat := ParticleProcessMaterial.new()
var _crown := Node3D.new()
var _showoff_light := OmniLight3D.new()
var _showoff := false
var _time := 0.0


func _ready() -> void:
	_orbit_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	_orbit_mat.emission_ring_axis = Vector3.UP
	_orbit_mat.emission_ring_radius = 0.9
	_orbit_mat.emission_ring_inner_radius = 0.6
	_orbit_mat.emission_ring_height = 1.4
	_orbit_mat.direction = Vector3.UP
	_orbit_mat.spread = 15.0
	_orbit_mat.initial_velocity_min = 0.2
	_orbit_mat.initial_velocity_max = 0.6
	_orbit_mat.gravity = Vector3.ZERO
	_orbit_mat.orbit_velocity_min = 0.15
	_orbit_mat.orbit_velocity_max = 0.35
	_orbit_mat.scale_curve = _shrink_curve()
	_setup(_orbit, _orbit_mat, 1.6, 0.07)
	_orbit.position.y = 0.9
	_orbit.local_coords = true  # circles the character as they move

	_trail_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	_trail_mat.emission_sphere_radius = 0.3
	_trail_mat.direction = Vector3.UP
	_trail_mat.spread = 25.0
	_trail_mat.initial_velocity_min = 0.4
	_trail_mat.initial_velocity_max = 1.2
	_trail_mat.gravity = Vector3(0, 0.5, 0)
	_trail_mat.scale_curve = _shrink_curve()
	_setup(_trail, _trail_mat, 1.0, 0.09)
	_trail.position.y = 0.1
	_trail.local_coords = false  # left behind as the character walks
	add_child(_crown)
	_crown.position.y = 2.05
	_crown.hide()
	_showoff_light.position.y = 1.1
	_showoff_light.omni_range = 4.0
	_showoff_light.shadow_enabled = false
	_showoff_light.hide()
	add_child(_showoff_light)
	for i in 8:
		var mote := MeshInstance3D.new()
		var cube := BoxMesh.new()
		cube.size = Vector3.ONE * (0.07 if i % 2 else 0.1)
		mote.mesh = cube
		mote.material_override = VoxModel.glow_material()
		mote.position = Vector3(cos(TAU * i / 8) * 0.55, sin(i * 2.0) * 0.12, sin(TAU * i / 8) * 0.55)
		mote.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_crown.add_child(mote)


## Rebuilds the look from the equipped gear.
func refresh(stats: PlayerStats) -> void:
	_showoff = float(stats.effect("showoff", 0.0)) > 0.0
	_crown.visible = _showoff
	_showoff_light.visible = _showoff
	var power := 0.0
	var color := Color(0, 0, 0, 0)
	var weight := 0.0
	for item: Item in stats.gear.values():
		if item and item.aura_power > 0.0 and item.aura_color.a > 0.0:
			power += item.aura_power
			color += item.aura_color * item.aura_power
			weight += item.aura_power
	_orbit.emitting = power > 0.0
	if power > 0.0:
		_orbit.amount_ratio = clampf(power / 1.8, 0.1, 1.0)
		_orbit_mat.color = Color(color.r / weight, color.g / weight, color.b / weight)
		_orbit_mat.hue_variation_min = -0.04
		_orbit_mat.hue_variation_max = 0.04
		_showoff_light.light_color = Color(color.r / weight, color.g / weight, color.b / weight)
		_showoff_light.light_energy = 1.2

	var trail: Variant = stats.effect("trail", "")
	_trail.emitting = trail is String and trail != ""
	match trail:
		"festival", "constellation":
			_trail_mat.color = Color("a0f5c8")
			_trail_mat.hue_variation_min = -1.0
			_trail_mat.hue_variation_max = 1.0
			_orbit_mat.hue_variation_min = -1.0
			_orbit_mat.hue_variation_max = 1.0
		"embers":
			_trail_mat.color = Color(1.0, 0.5, 0.15)
			_trail_mat.hue_variation_min = -0.05
			_trail_mat.hue_variation_max = 0.05
		"gold":
			_trail_mat.color = Color(1.0, 0.82, 0.35)
			_trail_mat.hue_variation_min = 0.0
			_trail_mat.hue_variation_max = 0.0
		"venom":
			_trail_mat.color = Color("9cf03a")
			_trail_mat.hue_variation_min = -0.03
			_trail_mat.hue_variation_max = 0.03
		"eclipse":
			_trail_mat.color = Color("ffb347")
			_trail_mat.hue_variation_min = -0.12
			_trail_mat.hue_variation_max = 0.0
		"stormeye":
			_trail_mat.color = Color("a0e8ff")
			_trail_mat.hue_variation_min = -0.4
			_trail_mat.hue_variation_max = 0.05
		"rainbow":
			_trail_mat.color = Color(1.0, 0.4, 0.4)
			_trail_mat.hue_variation_min = -1.0
			_trail_mat.hue_variation_max = 1.0
			_orbit_mat.hue_variation_min = -1.0
			_orbit_mat.hue_variation_max = 1.0


func _process(delta: float) -> void:
	if not _showoff: return
	_time += delta
	_crown.rotation.y += delta * 0.8
	_crown.position.y = 2.05 + sin(_time * 1.7) * 0.08
	_showoff_light.light_energy = 1.1 + sin(_time * 2.0) * 0.15


func _setup(p: GPUParticles3D, pm: ParticleProcessMaterial, lifetime: float, cube_size: float) -> void:
	var cube := BoxMesh.new()
	cube.size = Vector3.ONE * cube_size
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/fire_voxel.gdshader")
	mat.set_shader_parameter("brightness", 2.5)
	cube.material = mat
	p.process_material = pm
	p.draw_pass_1 = cube
	p.amount = 48
	p.lifetime = lifetime
	p.emitting = false
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.visibility_aabb = AABB(Vector3(-3, -1, -3), Vector3(6, 5, 6))
	add_child(p)


func _shrink_curve() -> CurveTexture:
	var c := Curve.new()
	c.add_point(Vector2(0, 0.4))
	c.add_point(Vector2(0.3, 1))
	c.add_point(Vector2(1, 0))
	var t := CurveTexture.new()
	t.curve = c
	return t
