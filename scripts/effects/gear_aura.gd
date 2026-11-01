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


## Rebuilds the look from the equipped gear.
func refresh(stats: PlayerStats) -> void:
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

	var trail: Variant = stats.effect("trail", "")
	_trail.emitting = trail is String and trail != ""
	match trail:
		"embers":
			_trail_mat.color = Color(1.0, 0.5, 0.15)
			_trail_mat.hue_variation_min = -0.05
			_trail_mat.hue_variation_max = 0.05
		"gold":
			_trail_mat.color = Color(1.0, 0.82, 0.35)
			_trail_mat.hue_variation_min = 0.0
			_trail_mat.hue_variation_max = 0.0
		"rainbow":
			_trail_mat.color = Color(1.0, 0.4, 0.4)
			_trail_mat.hue_variation_min = -1.0
			_trail_mat.hue_variation_max = 1.0
			_orbit_mat.hue_variation_min = -1.0
			_orbit_mat.hue_variation_max = 1.0


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
