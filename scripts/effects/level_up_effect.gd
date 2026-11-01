class_name LevelUpEffect
extends Node3D
## Level-up burst: glowing voxels spiral up around the character in shifting
## rainbow-gold colors, with a warm flash of light. Frees itself when done.

const LIFETIME := 2.2


static func play(parent: Node3D) -> void:
	var effect := LevelUpEffect.new()
	parent.add_child(effect)


func _ready() -> void:
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	pm.emission_ring_axis = Vector3.UP
	pm.emission_ring_radius = 1.0
	pm.emission_ring_inner_radius = 0.8
	pm.emission_ring_height = 0.1
	pm.direction = Vector3.UP
	pm.spread = 8.0
	pm.initial_velocity_min = 1.6
	pm.initial_velocity_max = 3.2
	pm.gravity = Vector3.ZERO
	pm.orbit_velocity_min = 0.35  # spiral around the character
	pm.orbit_velocity_max = 0.6
	pm.scale_min = 0.7
	pm.scale_max = 1.4
	var shrink := Curve.new()
	shrink.add_point(Vector2(0, 1))
	shrink.add_point(Vector2(0.7, 0.8))
	shrink.add_point(Vector2(1, 0))
	var shrink_tex := CurveTexture.new()
	shrink_tex.curve = shrink
	pm.scale_curve = shrink_tex
	pm.color = Color(1.0, 0.85, 0.4)
	pm.hue_variation_min = -0.25
	pm.hue_variation_max = 0.25

	var cube := BoxMesh.new()
	cube.size = Vector3.ONE * 0.12
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/fire_voxel.gdshader")
	cube.material = mat

	var particles := GPUParticles3D.new()
	particles.process_material = pm
	particles.draw_pass_1 = cube
	particles.amount = 90
	particles.lifetime = 1.4
	particles.one_shot = true
	particles.explosiveness = 0.55
	particles.position.y = 0.1
	particles.local_coords = true  # the spiral follows the character as they move
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	particles.emitting = true
	add_child(particles)

	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.85, 0.5)
	light.omni_range = 7.0
	light.position.y = 1.2
	add_child(light)
	var t := create_tween()
	t.tween_property(light, "light_energy", 4.0, 0.15).from(0.0)
	t.tween_property(light, "light_energy", 0.0, 1.2)
	t.tween_interval(LIFETIME - 1.35)
	t.tween_callback(queue_free)
