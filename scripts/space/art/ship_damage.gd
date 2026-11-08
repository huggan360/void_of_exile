class_name ShipDamage
extends Node3D
## What a hurt ship shows outside: smoke from parts below half, fire and
## sparks once they are nearly gone (engines trail it behind the ship).
var _fx := {}  # part id -> {smoke, fire}

func show_parts(parts: Dictionary) -> void:
	for id: String in SpaceShip.PARTS:
		var k := clampf(float(parts.get(id, 100.0))/100.0, 0.0, 1.0)
		var smoke := k<0.5
		var fire := k<0.25
		if not _fx.has(id):
			if not smoke: continue
			var at: Vector3 = SpaceShip.PARTS[id].hull
			_fx[id] = {smoke = _emitter(at, false), fire = _emitter(at, true)}
		_fx[id].smoke.emitting = smoke
		_fx[id].fire.emitting = fire

func _emitter(at: Vector3, fire: bool) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.position = at
	p.amount = 40 if fire else 60
	p.lifetime = 1.2 if fire else 4.0
	p.local_coords = false
	p.emitting = false
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	process.emission_sphere_radius = 1.6
	process.direction = Vector3.UP
	process.spread = 40.0
	process.initial_velocity_min = 2.0 if fire else 1.0
	process.initial_velocity_max = 5.0 if fire else 3.0
	process.gravity = Vector3.ZERO
	process.scale_min = 0.8
	process.scale_max = 2.4 if fire else 4.5
	var fade := Gradient.new()
	if fire:
		fade.set_color(0, Color(1.0, 0.85, 0.4, 1.0))
		fade.add_point(0.4, Color(1.0, 0.4, 0.1, 0.9))
		fade.set_color(fade.get_point_count()-1, Color(0.4, 0.1, 0.05, 0.0))
	else:
		fade.set_color(0, Color(0.3, 0.28, 0.3, 0.75))
		fade.set_color(1, Color(0.2, 0.2, 0.22, 0.0))
	var ramp := GradientTexture1D.new()
	ramp.gradient = fade
	process.color_ramp = ramp
	p.process_material = process
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE*1.2
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if fire else BaseMaterial3D.BLEND_MODE_MIX
	mat.vertex_color_use_as_albedo = true
	mat.albedo_texture = SpaceBackdrop._soft_dot()
	quad.material = mat
	p.draw_pass_1 = quad
	add_child(p)
	return p
