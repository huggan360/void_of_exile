class_name WarpWave
extends Node3D
## Base for expanding rings of warped space: the player's MagicRing and the
## enemies' EnemyRipple. Rings of different teams clash where they touch.
##
## Each ring is split into SEGMENTS arcs with their own strength (0..1).
## Where two arcs meet, their power (the ring's power x the arc's strength)
## is compared: equal arcs cancel each other out, otherwise the weaker arc is
## wiped out and the stronger one loses as much as the weaker had. So the
## rings break apart only where they actually crossed. A cancelled arc
## fades out (see the warp shader's arc_strength) and hurts nothing.
##
## Subclasses set team, radius, band and _material, implement power(), and
## call _clash() each physics frame after growing.

const SEGMENTS := 64
const EVEN := 0.15  # powers within 15% of each other cancel out
const SPARK_EVERY := 0.05
const CLASH_SHAKE := 0.12

static var _waves: Array[WarpWave] = []

var team := ""
var radius := 0.0
var previous_radius := 0.0
var band := 1.0
var color := Color(0.8, 0.9, 1.0)  # for clash sparks
var segments := PackedFloat32Array()
var _material: ShaderMaterial
var _spark_timer := 0.0


func _init() -> void:
	segments.resize(SEGMENTS)
	segments.fill(1.0)


func _enter_tree() -> void:
	_waves.append(self)


func _exit_tree() -> void:
	_waves.erase(self)


## What this ring would deal right now at full strength.
func power() -> float:
	return 0.0


## Strength (0..1) of the arc facing `pos`; 0 where it was cancelled.
func strength_toward(pos: Vector3) -> float:
	return segments[_segment_at(pos)]


func _segment_at(pos: Vector3) -> int:
	var local := global_basis.inverse()*(pos-global_position)
	var a := atan2(local.z,local.x)
	return posmod(int(floor(a / TAU * SEGMENTS)), SEGMENTS)


func _active() -> bool:
	return is_inside_tree() and is_physics_processing() and radius > 0.05


## Clashes with every ring of another team this ring touches.
func _clash(delta: float) -> void:
	_spark_timer -= delta
	for other in _waves:
		if other != self and other.team != team and other._active() and _active():
			_clash_with(other)
	if _material:
		_material.set_shader_parameter("arc_strength", segments)


func _clash_with(other: WarpWave) -> void:
	var touch := (band + other.band) * 0.25
	var mine := power()
	var theirs := other.power()
	# The same stretch of contact covers fewer of the bigger ring's segments.
	var arc := radius / maxf(0.01, other.radius)
	var contact := Vector3.ZERO
	var contacts := 0
	for i in SEGMENTS:
		if segments[i] <= 0.0:
			continue
		var a := (i + 0.5) / SEGMENTS * TAU
		var p := global_position + Vector3(cos(a), 0.0, sin(a)) * radius
		var flat := Vector2(p.x - other.global_position.x, p.z - other.global_position.z)
		if absf(flat.length() - other.radius) > touch:
			continue
		var j := other._segment_at(p)
		var pa := mine * segments[i]
		var pb := theirs * other.segments[j]
		if pb <= 0.0:
			continue
		if absf(pa - pb) <= EVEN * maxf(pa, pb):
			segments[i] = 0.0
			other.segments[j] = 0.0
		elif pa > pb:
			segments[i] *= 1.0 - pb / pa * minf(1.0, 1.0 / arc)
			other.segments[j] = 0.0
		else:
			other.segments[j] *= 1.0 - pa / pb * minf(1.0, arc)
			segments[i] = 0.0
		contact += p
		contacts += 1
	if contacts > 0 and _spark_timer <= 0.0:
		_spark_timer = SPARK_EVERY
		contact /= contacts
		GameAudio.play("magic_shield_hit", contact, {source_id = get_instance_id(), cooldown = 0.1})
		_spark(contact + Vector3.UP * 0.9, color.lerp(other.color, 0.5))
		CameraShake.shake_at(contact, CLASH_SHAKE, 8.0)


## A quick spray of light where two rings tear each other apart.
func _spark(pos: Vector3, spark_color: Color) -> void:
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3.UP
	pm.spread = 180.0
	pm.initial_velocity_min = 2.0
	pm.initial_velocity_max = 5.0
	pm.gravity = Vector3(0, -6, 0)
	pm.color = spark_color.lightened(0.4)
	pm.hue_variation_min = -0.1
	pm.hue_variation_max = 0.1
	var cube := BoxMesh.new()
	cube.size = Vector3.ONE * 0.08
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/fire_voxel.gdshader")
	cube.material = mat
	var p := GPUParticles3D.new()
	p.process_material = pm
	p.draw_pass_1 = cube
	p.amount = 14
	p.lifetime = 0.4
	p.one_shot = true
	p.explosiveness = 1.0
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	get_parent().add_child(p)
	p.global_position = pos
	p.emitting = true
	p.finished.connect(p.queue_free)
