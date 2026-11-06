class_name TheorySparks
extends Node3D
## Short ballistic streaks, crystal cores fading from green to pink, in irregular bursts.
## Audio attachment is intentionally left for the supplied ship SFX later.
var _emitter := GPUParticles3D.new()
var _light: OmniLight3D
var _timer := 0.2
var _rng := RandomNumberGenerator.new()
var active := true
var direction := Vector3(0.35,-0.7,0.3)
var interval := Vector2(0.45,3.8)
var light_strength := 1.0

func _ready() -> void:
	_rng.seed = hash(global_position)
	_timer = _rng.randf_range(0.1,1.0)
	var process := ParticleProcessMaterial.new()
	process.direction = direction
	process.spread = 48.0
	process.initial_velocity_min = 2.5
	process.initial_velocity_max = 7.0
	process.gravity = Vector3(0,-9,0)
	process.damping_min = 0.15
	process.damping_max = 0.45
	process.particle_flag_align_y = true
	process.scale_min = 0.6
	process.scale_max = 1.4
	var gradient := Gradient.new()
	gradient.set_color(0,Color("e5ffbd"))
	gradient.add_point(0.28,Color("9fe87c"))
	gradient.add_point(0.65,Color("d175a3"))
	gradient.set_color(gradient.get_point_count()-1,Color(0.18,0.025,0.10,0))
	var colors := GradientTexture1D.new()
	colors.gradient = gradient
	process.color_ramp = colors
	_emitter.process_material = process
	_emitter.amount = 32
	_emitter.lifetime = 0.75
	_emitter.one_shot = true
	_emitter.explosiveness = 0.88
	_emitter.visibility_aabb = AABB(Vector3(-7,-9,-7),Vector3(14,13,14))
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.018,0.13,0.018)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.emission_enabled = true
	material.emission = Color("bbd98b")
	material.emission_energy_multiplier = 2.8
	mesh.material = material
	_emitter.draw_pass_1 = mesh
	_emitter.emitting = false
	add_child(_emitter)
	if light_strength>0.0:
		_light = OmniLight3D.new()
		_light.light_color = Color("b6d981")
		_light.shadow_enabled = false
		_light.distance_fade_enabled = true
		_light.distance_fade_begin = 30.0
		_light.distance_fade_length = 20.0
		_light.omni_range = 5.0
		_light.light_energy = 0.0
		add_child(_light)

func set_active(value: bool) -> void:
	active = value
	if not is_inside_tree(): return
	set_process(value)
	if not value:
		_emitter.emitting = false
		if _light!=null: _light.light_energy = 0.0

func _process(delta: float) -> void:
	if get_viewport().get_camera_3d()==null: return
	if global_position.distance_to(get_viewport().get_camera_3d().global_position)>55.0: return
	_timer -= delta
	if _light!=null: _light.light_energy = move_toward(_light.light_energy,0.0,delta*18.0)
	if _timer<=0.0:
		_timer = _rng.randf_range(interval.x,interval.y)
		_emitter.restart()
		if _light!=null: _light.light_energy = _rng.randf_range(1.2,2.7)*light_strength
