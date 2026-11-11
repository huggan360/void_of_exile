class_name AimMarker
extends Node3D
## Where your shots go, right under the cursor's tip (only you see it):
## a small white ring that snaps in when you start shooting (like a Dota
## move order) with motes streaming into its middle, staying under the
## cursor while you hold the button and fading when you let go.

const RADIUS := 0.38
const SNAP_FROM := 2.1  # the ring starts this much larger and snaps in
const FADE_SPEED := 5.0
const RING_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, depth_test_disabled, cull_disabled, shadows_disabled;
uniform float alpha = 1.0;
uniform float pulse = 0.0;
void fragment() {
	float r = length(UV - vec2(0.5)) * 2.0;  // 0 center, 1 edge of the quad
	float ring = smoothstep(0.80, 0.86, r) * (1.0 - smoothstep(0.92, 0.98, r));
	float glow = exp(-pow((r - 0.89) * 9.0, 2.0)) * 0.45;
	float dot = (1.0 - smoothstep(0.05, 0.11, r)) * 0.8;
	float a = (ring + glow + dot) * alpha * (0.85 + pulse * 0.15);
	ALBEDO = vec3(1.0);
	ALPHA = clamp(a, 0.0, 1.0);
}
"""

var _ring := MeshInstance3D.new()
var _material := ShaderMaterial.new()
var _motes := GPUParticles3D.new()
var _alpha := 0.0
var _snap := 1.0
var _held := false
var _time := 0.0


func _ready() -> void:
	top_level = true
	var quad := PlaneMesh.new()
	quad.size = Vector2.ONE * RADIUS * 2.0 / 0.89
	var shader := Shader.new()
	shader.code = RING_SHADER
	_material.shader = shader
	quad.material = _material
	_ring.mesh = quad
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ring)
	# Motes born on a wider circle, pulled into the middle.
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	pm.emission_ring_axis = Vector3.UP
	pm.emission_ring_radius = RADIUS * 2.0
	pm.emission_ring_inner_radius = RADIUS * 1.5
	pm.emission_ring_height = 0.0
	pm.gravity = Vector3.ZERO
	pm.radial_velocity_min = -RADIUS * 3.4
	pm.radial_velocity_max = -RADIUS * 2.6
	pm.direction = Vector3.UP
	pm.spread = 0.0
	pm.initial_velocity_min = 0.05
	pm.initial_velocity_max = 0.35
	var fade := Curve.new()
	fade.add_point(Vector2(0.0, 0.3))
	fade.add_point(Vector2(0.4, 1.0))
	fade.add_point(Vector2(1.0, 0.0))
	var scale_curve := CurveTexture.new()
	scale_curve.curve = fade
	pm.scale_curve = scale_curve
	pm.color = Color(1, 1, 1, 0.9)
	_motes.process_material = pm
	_motes.amount = 28
	_motes.lifetime = 0.45
	_motes.local_coords = true
	_motes.emitting = false
	_motes.visibility_aabb = AABB(Vector3(-2, -1, -2), Vector3(4, 2, 4))
	var mote := QuadMesh.new()
	mote.size = Vector2.ONE * 0.07
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.vertex_color_use_as_albedo = true
	mote.material = mat
	_motes.draw_pass_1 = mote
	_motes.position.y = 0.08
	add_child(_motes)
	visible = false


## Every frame: `point` = the ground under the aim; `held` = shooting; `up`
## = the ground's up there (a planet's gravity in Space), the ring lies flat to it.
func track(point: Vector3, held: bool, delta: float, up := Vector3.UP) -> void:
	_time += delta
	if held and not _held:
		_snap = SNAP_FROM  # a fresh press: the ring snaps in
		_alpha = 1.0
		_motes.restart()
	_held = held
	_motes.emitting = held
	_alpha = 1.0 if held else maxf(0.0, _alpha - delta * FADE_SPEED)
	_snap = lerpf(_snap, 1.0, minf(1.0, delta * 14.0))
	visible = _alpha > 0.01
	if not visible:
		return
	var side := up.cross(Vector3.FORWARD if absf(up.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
	global_transform = Transform3D(Basis(side, up, side.cross(up)).orthonormalized(), point + up * 0.06)
	_ring.scale = Vector3.ONE * _snap * (1.0 + 0.04 * sin(_time * 7.0))
	_material.set_shader_parameter("alpha", _alpha)
	_material.set_shader_parameter("pulse", 0.5 + 0.5 * sin(_time * 7.0))
