class_name TheoryWreckFire
extends VoxelFire
## Large, uneven green ghost-fires. The one contact source stays authoritative while
## independent flame plumes, embers and spectral surges provide the visual variation.
var flame_height := 3.5
var variant := 0
var seed_value := 1
var _plumes: Array[GPUParticles3D] = []
var _fuel_phase := 0.0

func configure(spec: Dictionary) -> void:
	size = float(spec.size)
	flame_height = float(spec.get("height",3.5))
	variant = int(spec.get("style",0))
	seed_value = int(spec.get("seed",1))
	_fuel_phase = fposmod(float(seed_value)*0.173,TAU)

func _ready() -> void:
	if contact_burn: _register_contact.call_deferred()
	if Net.is_server():
		set_process(false)
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var count := 2 if variant==1 else 3 if variant==0 else 4
	for i in count:
		var height := flame_height*rng.randf_range(0.65,1.0)
		var at := Vector3(rng.randf_range(-0.3,0.3)*size,0,rng.randf_range(-0.3,0.3)*size)
		var plume := _plume(rng,height,i==0)
		plume.position = at
		add_child(plume)
		_plumes.append(plume)
	var embers := _embers(rng)
	add_child(embers)
	_plumes.append(embers)
	_light = OmniLight3D.new()
	_light.shadow_enabled = false
	_light.light_color = Color("a4e58a").lerp(Color("69bc82"),rng.randf_range(0.0,0.4))
	_light.omni_range = 7.0+size*2.5
	_light.position.y = flame_height*0.32
	_light.light_volumetric_fog_energy = 0.65
	_light.distance_fade_enabled = true
	_light.distance_fade_begin = 35
	_light.distance_fade_length = 20
	_light.light_energy = 0
	add_child(_light)
	var notifier := VisibleOnScreenNotifier3D.new()
	notifier.aabb = AABB(Vector3(-size*1.5,-0.3,-size*1.5),Vector3(size*3,flame_height*1.5,size*3)).grow(3)
	notifier.screen_entered.connect(func() -> void:
		for plume in _plumes: plume.emitting = true
		set_process(true))
	notifier.screen_exited.connect(func() -> void:
		for plume in _plumes: plume.emitting = false
		_light.light_energy = 0
		set_process(false))
	add_child(notifier)
	set_process(false)

func _plume(rng: RandomNumberGenerator,height: float,core: bool) -> GPUParticles3D:
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(size*0.15,0.08,size*0.13)
	process.direction = Vector3(rng.randf_range(-0.18,0.18),1,rng.randf_range(-0.18,0.18)).normalized()
	process.spread = 10 if variant==1 else 19
	process.initial_velocity_min = height*0.65
	process.initial_velocity_max = height*0.9
	process.gravity = Vector3(0,0.7,0)
	process.radial_accel_min = -0.2
	process.radial_accel_max = 0.4
	process.tangential_accel_min = -0.8
	process.tangential_accel_max = 0.8
	process.scale_min = 0.45
	process.scale_max = 1.25
	var shrink := Curve.new()
	shrink.add_point(Vector2(0,0.35))
	shrink.add_point(Vector2(0.18,1.0))
	shrink.add_point(Vector2(0.65,0.5))
	shrink.add_point(Vector2(1,0.02))
	var curve := CurveTexture.new()
	curve.curve = shrink
	process.scale_curve = curve
	var gradient := Gradient.new()
	gradient.set_color(0,Color("d8ffc0") if core else Color("a0ee99"))
	gradient.add_point(0.18,Color("8ee685"))
	gradient.add_point(0.45,Color("43b978"))
	gradient.add_point(0.75,Color(0.11,0.37,0.27,0.65))
	gradient.set_color(gradient.get_point_count()-1,Color(0.09,0.13,0.12,0))
	var ramp := GradientTexture1D.new()
	ramp.gradient = gradient
	process.color_ramp = ramp
	var shape := BoxMesh.new()
	shape.size = Vector3.ONE*(0.13 if core else 0.17)*clampf(size,1.0,2.4)
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/fire_voxel.gdshader")
	shape.material = material
	var particles := GPUParticles3D.new()
	particles.process_material = process
	particles.draw_pass_1 = shape
	particles.amount = 58 if core else 42
	particles.amount_ratio = 0.8
	particles.lifetime = rng.randf_range(0.95,1.18)
	particles.preprocess = 0.8
	particles.visibility_aabb = AABB(Vector3(-size*2,-0.5,-size*2),Vector3(size*4,height*1.6,size*4))
	particles.visibility_range_end = DRAW_DISTANCE
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	particles.emitting = false
	return particles

func _embers(rng: RandomNumberGenerator) -> GPUParticles3D:
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(size*0.3,0.2,size*0.3)
	process.direction = Vector3(0,1,0)
	process.spread = 28
	process.initial_velocity_min = 1.0
	process.initial_velocity_max = 2.3
	process.gravity = Vector3(0,0.15,0)
	process.color = Color("b8dd8c")
	process.scale_min = 0.4
	process.scale_max = 1.1
	var shrink := Curve.new()
	shrink.add_point(Vector2(0,0.5))
	shrink.add_point(Vector2(0.2,1.0))
	shrink.add_point(Vector2(1,0.0))
	var fade := CurveTexture.new()
	fade.curve = shrink
	process.scale_curve = fade
	var shape := BoxMesh.new()
	shape.size = Vector3(0.025,0.055,0.025)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.emission_enabled = true
	material.emission = Color("a2ce8f")
	shape.material = material
	var particles := GPUParticles3D.new()
	particles.process_material = process
	particles.draw_pass_1 = shape
	particles.amount = 16
	particles.lifetime = rng.randf_range(1.5,1.9)
	particles.visibility_aabb = AABB(Vector3(-5,-1,-5),Vector3(10,8,10))
	particles.visibility_range_end = 55
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	particles.emitting = false
	return particles

func _process(_delta: float) -> void:
	var parent := get_parent() as TheoryWorld
	var time := parent.clock_time() if parent!=null else Time.get_ticks_msec()*0.001
	time += _fuel_phase
	var surge := 0.78+0.13*sin(time*1.7)+0.09*sin(time*3.71+1.9)
	var flicker := 0.12*sin(time*11.3)+0.08*sin(time*23.9+_fuel_phase)
	_light.light_energy = (1.5+size*0.35)*maxf(0.35,surge+flicker)
	for i in _plumes.size(): _plumes[i].amount_ratio = clampf(surge+0.12*sin(time*2.9+i*1.7),0.5,1.0)
