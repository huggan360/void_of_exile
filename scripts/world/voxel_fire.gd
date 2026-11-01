class_name VoxelFire
extends Node3D
## Flames made of little glowing voxels that rise, shrink and cool from yellow
## to red, plus a flickering light. Purely visual: you can walk through it.

const DRAW_DISTANCE := 70.0

## 1 = campfire-sized; larger values make bigger, brighter fires.
var size := 1.0

var _light := OmniLight3D.new()
var _time := randf() * 10.0


func _init(p_size := 1.0) -> void:
	size = p_size


func _ready() -> void:
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.3 * size
	pm.direction = Vector3.UP
	pm.spread = 12.0
	pm.initial_velocity_min = 1.0 * size
	pm.initial_velocity_max = 2.0 * size
	pm.gravity = Vector3(0, 0.8, 0)  # hot air keeps pushing them up
	pm.scale_min = 0.6
	pm.scale_max = 1.3
	var shrink := Curve.new()
	shrink.add_point(Vector2(0, 1))
	shrink.add_point(Vector2(1, 0))
	var shrink_tex := CurveTexture.new()
	shrink_tex.curve = shrink
	pm.scale_curve = shrink_tex
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.95, 0.6))
	ramp.set_color(1, Color(0.6, 0.08, 0.02, 0.0))
	ramp.add_point(0.35, Color(1.0, 0.55, 0.1))
	ramp.add_point(0.7, Color(0.85, 0.2, 0.04))
	var ramp_tex := GradientTexture1D.new()
	ramp_tex.gradient = ramp
	pm.color_ramp = ramp_tex

	var cube := BoxMesh.new()
	cube.size = Vector3.ONE * 0.13 * size
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/fire_voxel.gdshader")
	cube.material = mat

	var particles := GPUParticles3D.new()
	particles.process_material = pm
	particles.draw_pass_1 = cube
	particles.amount = int(36 * size)
	particles.lifetime = 0.9
	particles.visibility_aabb = AABB(Vector3(-1.5, -0.5, -1.5) * size, Vector3(3, 4, 3) * size)
	particles.visibility_range_end = DRAW_DISTANCE
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(particles)

	_light.light_color = Color(1.0, 0.55, 0.2)
	_light.omni_range = 5.0 * size
	_light.position.y = 0.6 * size
	_light.light_volumetric_fog_energy = 1.5
	_light.distance_fade_enabled = true
	_light.distance_fade_begin = DRAW_DISTANCE - 20.0
	_light.distance_fade_length = 15.0
	add_child(_light)


func _process(delta: float) -> void:
	_time += delta
	var flicker := 0.15 * sin(_time * 11.0) + 0.1 * sin(_time * 17.3 + 1.1) + 0.08 * sin(_time * 29.0)
	_light.light_energy = 2.2 * size * (1.0 + flicker)
