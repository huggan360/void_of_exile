class_name VoxelFire
extends Node3D
## Flames made of little glowing voxels that rise, shrink and cool from yellow
## to red, plus a flickering light. Ground fires ignite actors passing through.

const DRAW_DISTANCE := 70.0

## 1 = campfire-sized; larger values make bigger, brighter fires.
static var _resources := {}
var size := 1.0
## Burning characters carry visual flames, never another contact hazard.
var contact_burn := true

var _light: OmniLight3D
var _time := randf() * 10.0


func _init(p_size := 1.0) -> void:
	size = p_size


static func warm(size: float) -> void:
	if _resources.has(size): return
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

	_resources[size] = {process=pm,mesh=cube}

func _ready() -> void:
	if contact_burn: _register_contact.call_deferred()
	if Net.is_server():
		set_process(false)
		return
	warm(size)
	var particles := GPUParticles3D.new()
	particles.process_material = _resources[size].process
	particles.draw_pass_1 = _resources[size].mesh
	particles.amount = int(36 * size)
	particles.lifetime = 0.9
	particles.visibility_aabb = AABB(Vector3(-1.5, -0.5, -1.5) * size, Vector3(3, 4, 3) * size)
	particles.visibility_range_end = DRAW_DISTANCE
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	particles.emitting = false
	add_child(particles)
	# Rendering distance alone does not stop GPU particle simulation. Activate
	# offscreen fires before their visible flames enter the camera frustum.
	var notifier := VisibleOnScreenNotifier3D.new()
	notifier.aabb = particles.visibility_aabb.grow(4)
	notifier.screen_entered.connect(func() -> void: particles.emitting = true; set_process(true))
	notifier.screen_exited.connect(func() -> void: particles.emitting = false; set_process(false))
	add_child(notifier)
	set_process(false)

	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.55, 0.2)
	_light.omni_range = 5.0 * size
	_light.position.y = 0.6 * size
	_light.light_volumetric_fog_energy = 1.5
	_light.distance_fade_enabled = true
	_light.distance_fade_begin = DRAW_DISTANCE - 20.0
	_light.distance_fade_length = 15.0
	add_child(_light)

func _register_contact() -> void:
	var ancestor := get_parent()
	while ancestor != null:
		if ancestor is GameWorld:
			(ancestor as GameWorld).register_contact_fire(self)
			return
		ancestor = ancestor.get_parent()


func _process(delta: float) -> void:
	_time += delta
	var flicker := 0.15 * sin(_time * 11.0) + 0.1 * sin(_time * 17.3 + 1.1) + 0.08 * sin(_time * 29.0)
	_light.light_energy = 2.2 * size * (1.0 + flicker)
