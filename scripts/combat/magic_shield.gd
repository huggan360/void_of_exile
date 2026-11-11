class_name MagicShield
extends Node3D
## The warp-shield bubble around the character. Purely visual; Player
## decides when it's up and what it blocks. All magic in the game uses this
## warped-space look.
##
## When a warp wave (an enemy ripple) washes over it, brace() makes the bubble
## lean into it: it dents where the wave hits, streams back into a teardrop
## and sheds streaks of light past its sides, like walking into a gale.
##
## Around the bubble spin two rings of the spell's motes (SpellFX), in
## opposite directions. Letting go flings the motes outward.

const RADIUS := 1.35
const FADE_SPEED := 7.0
const BRACE_RISE := 14.0  # how fast it gives way to a wave
const BRACE_FALL := 4.0   # and springs back after
const BRACE_HOLD := 0.08  # a push lasts this long (waves push from physics ticks)

var active := false
var _intensity := 0.0
var _pulse := 0.0
var _material := ShaderMaterial.new()
var _mesh := MeshInstance3D.new()
var _light := OmniLight3D.new()
var _time := 0.0
var _brace := 0.0
var _brace_target := 0.0
var _brace_hold := 0.0
var _brace_dir := Vector3.FORWARD  # world direction the wave travels
var _wind := _make_wind()
var _spell: Item
var _aura := Node3D.new()
var _rings: Array[Node3D] = []
var _was_active := false


func _ready() -> void:
	var sphere := SphereMesh.new()
	sphere.radius = RADIUS
	sphere.height = RADIUS * 2.0
	sphere.radial_segments = 48
	sphere.rings = 24
	_material.shader = preload("res://shaders/warp_shield.gdshader")
	_mesh.mesh = sphere
	_mesh.material_override = _material
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mesh.position.y = 0.95
	add_child(_mesh)
	_light.light_color = Color(0.6, 0.75, 1.0)
	_light.omni_range = 4.0
	_light.position.y = 1.0
	_light.light_volumetric_fog_energy = 0.5
	add_child(_light)
	add_child(_wind)
	_aura.position.y = _mesh.position.y
	add_child(_aura)
	_apply()


## Takes on the look of a spell: its tint, arc colors and how hard it warps.
func set_spell(spell: Item) -> void:
	if spell == null:
		return
	if spell != _spell:
		_spell = spell
		for ring in _rings: ring.queue_free()
		_rings = SpellFX.aura_rings(spell, RADIUS)
		for ring in _rings:
			_aura.add_child(ring)
			if active: SpellFX.gather(ring)
		_material.set_shader_parameter("darkness", SpellFX.style(spell).darkness)
	_material.set_shader_parameter("tint", spell.shield_tint)
	_material.set_shader_parameter("arc_color", spell.shield_arcs)
	(_wind.process_material as ParticleProcessMaterial).color = spell.shield_arcs
	_material.set_shader_parameter("rainbow", spell.shield_rainbow)
	_material.set_shader_parameter("warp", spell.warp)
	_light.light_color = spell.shield_tint.lerp(spell.shield_arcs, 0.5)


## A flash when the shield soaks up a hit.
func flash() -> void:
	_pulse = 1.0


## Every projectile dents the bubble in its incoming direction, like a warp wave.
func impact(direction: Vector3) -> void:
	flash()
	if is_inside_tree() and direction.length() > 0.01:
		var d := direction.normalized()
		SpellFX.hit(self, _mesh.global_position - d * RADIUS, -d, _spell)
	brace(direction, 1.0)
	_brace_hold = 0.18


## A warp wave travelling along `direction` is pushing on the shield this
## frame, with `strength` 0..1. Call every frame while it's in contact.
func brace(direction: Vector3, strength: float) -> void:
	direction.y = 0.0
	if direction.length() < 0.01 or not active:
		return
	if _brace < 0.05:
		_brace_dir = direction.normalized()
		_pulse = 1.0
	_brace_dir = _brace_dir.slerp(direction.normalized(), 0.5)
	_brace_target = maxf(_brace_target, clampf(strength, 0.0, 1.0))
	_brace_hold = BRACE_HOLD


func _process(delta: float) -> void:
	_time += delta
	_intensity = move_toward(_intensity, 1.0 if active else 0.0, delta * FADE_SPEED)
	_pulse = maxf(0.0, _pulse - delta * 3.0)
	_brace_hold -= delta
	if not active or _brace_hold <= 0.0:
		_brace_target = 0.0  # waves have to keep pushing to keep it bent
	var rate := BRACE_RISE if _brace_target > _brace else BRACE_FALL
	_brace = move_toward(_brace, _brace_target, delta * rate)
	if active != _was_active:
		_was_active = active
		var heavy := _spell != null and _spell.is_divine()
		for ring in _rings:
			if active: SpellFX.gather(ring)
			else: SpellFX.release(ring, heavy)
		if not active and _spell != null and is_inside_tree():
			SpellFX.flash(self, _mesh.global_position, SpellFX.style(_spell).accent, 1.4 if heavy else 1.0)
	for ring in _rings: SpellFX.spin(ring, delta)
	_apply()


func _apply() -> void:
	_mesh.visible = _intensity > 0.01
	_light.visible = _mesh.visible
	_material.set_shader_parameter("intensity", _intensity)
	_material.set_shader_parameter("pulse", _pulse)
	# Light crackles like the arcs on the surface.
	var crackle := 0.6 + 0.4 * sin(_time * 31.0) * sin(_time * 17.0)
	_light.light_energy = (0.8 + _pulse * 2.0) * crackle * _intensity
	_mesh.scale = Vector3.ONE * (0.85 + 0.15 * _intensity + _pulse * 0.06)
	var local_dir := (_mesh.global_basis.inverse() * _brace_dir).normalized() if is_inside_tree() else _brace_dir
	_material.set_shader_parameter("brace", _brace * _intensity)
	_material.set_shader_parameter("brace_dir", local_dir)
	_wind.emitting = _brace > 0.12 and _intensity > 0.5
	var pm := _wind.process_material as ParticleProcessMaterial
	pm.direction = _brace_dir
	pm.emission_ring_axis = _brace_dir
	_wind.position = Vector3.UP * 0.95 - _brace_dir * 0.5


## Streaks of light whipping past the sides of the bubble while it braces.
func _make_wind() -> GPUParticles3D:
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	pm.emission_ring_radius = RADIUS * 1.02
	pm.emission_ring_inner_radius = RADIUS * 0.8
	pm.emission_ring_height = 0.05
	pm.spread = 10.0
	pm.initial_velocity_min = 6.0
	pm.initial_velocity_max = 10.0
	pm.gravity = Vector3.ZERO
	pm.damping_min = 4.0
	pm.damping_max = 8.0
	pm.particle_flag_align_y = true
	pm.color = Color(0.85, 0.92, 1.0)
	pm.hue_variation_min = -0.2
	pm.hue_variation_max = 0.2
	var shrink := Curve.new()
	shrink.add_point(Vector2(0, 1))
	shrink.add_point(Vector2(1, 0))
	var shrink_tex := CurveTexture.new()
	shrink_tex.curve = shrink
	pm.scale_curve = shrink_tex
	var streak := BoxMesh.new()
	streak.size = Vector3(0.035, 0.45, 0.035)
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/fire_voxel.gdshader")
	streak.material = mat
	var p := GPUParticles3D.new()
	p.process_material = pm
	p.draw_pass_1 = streak
	p.amount = 70
	p.lifetime = 0.3
	p.emitting = false
	p.local_coords = false
	p.visibility_aabb = AABB(Vector3(-4, -2, -4), Vector3(8, 6, 8))
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p
