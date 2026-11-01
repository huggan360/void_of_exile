class_name ChargeEffect
extends Node3D
## Charging a shot: glowing voxels get pulled in toward the bow from all
## around, a light grows in the weapon's color, and when the charge is full
## there's a bright flash and the voxels whirl faster.

signal fully_charged

var _particles := GPUParticles3D.new()
var _pm := ParticleProcessMaterial.new()
var _light := OmniLight3D.new()
var _flash := 0.0
var _level := 0.0
var _full := false
var magic_ball := false


func _ready() -> void:
	_pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE_SURFACE
	_pm.emission_sphere_radius = 1.3
	_pm.direction = Vector3.ZERO
	_pm.initial_velocity_min = 0.0
	_pm.initial_velocity_max = 0.0
	_pm.radial_accel_min = -14.0  # pulled into the middle
	_pm.radial_accel_max = -10.0
	_pm.orbit_velocity_min = 0.3
	_pm.orbit_velocity_max = 0.6
	_pm.gravity = Vector3.ZERO
	var grow := Curve.new()
	grow.add_point(Vector2(0, 0.3))
	grow.add_point(Vector2(0.6, 1))
	grow.add_point(Vector2(1, 0))
	var grow_tex := CurveTexture.new()
	grow_tex.curve = grow
	_pm.scale_curve = grow_tex
	var cube := BoxMesh.new()
	cube.size = Vector3.ONE * 0.09
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/fire_voxel.gdshader")
	mat.set_shader_parameter("brightness", 3.0)
	cube.material = mat
	_particles.process_material = _pm
	_particles.draw_pass_1 = cube
	_particles.amount = 48
	_particles.lifetime = 0.4
	_particles.local_coords = true
	_particles.emitting = false
	_particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_particles)
	_light.omni_range = 4.0
	_light.light_energy = 0.0
	add_child(_light)


## level: 0 = not charging, 1 = full. Call every frame while charging.
func set_level(level: float, color: Color) -> void:
	_level = level
	_pm.emission_sphere_radius = (0.15 + level * 0.3) if magic_ball else 1.3
	_pm.radial_accel_min = -2.0 if magic_ball else -14.0
	_pm.radial_accel_max = -1.0 if magic_ball else -10.0
	_particles.emitting = level > 0.0
	_pm.color = color.lerp(Color.WHITE, 0.25 * level)
	_light.light_color = color
	_particles.amount_ratio = clampf(0.3 + level, 0.0, 1.0)
	_pm.orbit_velocity_min = 0.3 + level * 1.2
	_pm.orbit_velocity_max = 0.6 + level * 1.6
	if level >= 1.0 and not _full:
		_full = true
		_flash = 1.0
		fully_charged.emit()
	elif level < 1.0:
		_full = false


func _process(delta: float) -> void:
	_flash = maxf(0.0, _flash - delta * 4.0)
	var pulse := 0.15 * sin(Time.get_ticks_msec() / 1000.0 * 24.0) if _full else 0.0
	_light.light_energy = _level * 1.6 + _flash * 4.0 + pulse
	_light.visible = _light.light_energy > 0.01
