class_name MagicRing
extends WarpWave
## A warped annulus rolling outward from the caster (double-tap Space with a
## tier 4+ or Divine spell). Looks like the warp shield: bent space with
## crackling arcs in the spell's colors. Hits each obstacle once as the ring
## passes it, for less damage the further out it gets. Shakes nearby cameras.
## Clashes with enemy ripples where they touch (see WarpWave).

signal hit(target: Node, damage: int)

const START_RADIUS := 0.8
const BAND := 1.2  # ring thickness in meters
const MIN_DAMAGE_SHARE := 0.5  # what's left at the very edge of the range
const SHAKE_STRENGTH := 0.3
const SHAKE_RADIUS := 16.0

var spell: Item
var damage_multiplier := 1.0
## Another player's ring online: shown, but hurts nothing here.
var visual_only := false
var _hit := {}  # instance id -> true
var _mesh := MeshInstance3D.new()
var _torus := TorusMesh.new()
var _sparks: GPUParticles3D


static func cast(parent: Node3D, origin: Vector3, p_spell: Item, delay := 0.0, multiplier := 1.0) -> MagicRing:
	var ring := MagicRing.new()
	ring.spell = p_spell
	ring.damage_multiplier = multiplier
	parent.add_child(ring)
	ring.global_position = origin
	if delay > 0.0:
		ring.visible = false
		ring.set_physics_process(false)
		ring.get_tree().create_timer(delay).timeout.connect(ring._begin)
	else:
		ring._begin()
	return ring


func _ready() -> void:
	team = "players"
	color = spell.shield_arcs
	radius = START_RADIUS
	_material = ShaderMaterial.new()
	_material.set_shader_parameter("use_arcs", true)
	_material.set_shader_parameter("arc_strength", segments)
	_torus.rings = 64
	_torus.ring_segments = 10
	_material.shader = preload("res://shaders/warp_shield.gdshader")
	_material.set_shader_parameter("tint", spell.shield_tint)
	_material.set_shader_parameter("arc_color", spell.shield_arcs)
	_material.set_shader_parameter("rainbow", spell.shield_rainbow)
	_material.set_shader_parameter("warp", spell.warp * 1.6)
	_mesh.mesh = _torus
	_mesh.material_override = _material
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mesh.position.y = 0.9
	add_child(_mesh)
	_sparks = _make_sparks()
	add_child(_sparks)
	_apply()


func _begin() -> void:
	visible = true
	set_physics_process(true)
	_sparks.emitting = true
	CameraShake.shake_at(global_position, SHAKE_STRENGTH * (1.4 if spell.is_divine() else 1.0), SHAKE_RADIUS)


func _physics_process(delta: float) -> void:
	var reach: float = spell.ring.range
	var previous := radius
	previous_radius = radius
	radius += spell.ring.speed * delta
	_clash(delta)
	_damage_band(previous, radius)
	_apply()
	if radius >= reach:
		queue_free()


func _apply() -> void:
	var reach: float = spell.ring.get("range", 6.0)
	var t := clampf(radius / reach, 0.0, 1.0)
	# The band keeps the same thickness as the ring grows (and thins as it fades).
	band = BAND * (1.0 - t * 0.5)
	_torus.inner_radius = maxf(0.05, radius - band * 0.5)
	_torus.outer_radius = radius + band * 0.5
	_mesh.scale = Vector3(1.0, 0.6, 1.0)  # a little flatter than round
	_material.set_shader_parameter("intensity", 1.0 - t * t)  # fades as it weakens
	_material.set_shader_parameter("ring_radius", radius)
	if _sparks:
		(_sparks.process_material as ParticleProcessMaterial).emission_ring_radius = radius
		(_sparks.process_material as ParticleProcessMaterial).emission_ring_inner_radius = maxf(0.0, radius - 0.3)


## Hits obstacles the ring passed over this frame.
func _damage_band(inner: float, outer: float) -> void:
	if visual_only:
		return
	var query := PhysicsShapeQueryParameters3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = outer + BAND * 0.5
	query.shape = sphere
	query.transform = Transform3D(Basis(), global_position + Vector3.UP * 0.9)
	query.collision_mask = Player.OBSTACLE_LAYER | Player.ENEMY_LAYER
	for result in get_world_3d().direct_space_state.intersect_shape(query, 64):
		var target: Node = result.collider
		if _hit.has(target.get_instance_id()) or not target.has_method("take_hit"):
			continue
		var flat := Vector2(target.global_position.x - global_position.x, target.global_position.z - global_position.z)
		if flat.length() < inner - BAND:
			continue
		_hit[target.get_instance_id()] = true
		var strength := strength_toward(target.global_position)
		if strength < 0.05:
			continue  # this part of the ring was cancelled out
		var damage := damage_at_distance(flat.length(), strength)
		if target is Enemy:
			(target as Enemy).receive_weapon_hit(target.global_position + Vector3.UP, Vector3(flat.x, 0, flat.y).normalized(), damage, spell, true)
		else:
			target.take_hit(target.global_position + Vector3.UP, Vector3(flat.x, 0, flat.y).normalized(), damage)
		hit.emit(target, damage)


## Damage at the current radius (it weakens the further out it gets).
func power() -> float:
	var reach: float = spell.ring.get("range", 6.0)
	return spell.ring.damage * damage_multiplier * lerpf(1.0, MIN_DAMAGE_SHARE, clampf(radius / reach, 0.0, 1.0))


## Damage before enemy defense; shared with integration checks.
func damage_at_distance(distance: float, arc_strength := 1.0) -> int:
	var falloff := lerpf(1.0, MIN_DAMAGE_SHARE, clampf(distance / spell.ring.range, 0.0, 1.0))
	return maxi(1, roundi(spell.ring.damage * damage_multiplier * falloff * arc_strength))


func _make_sparks() -> GPUParticles3D:
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	pm.emission_ring_axis = Vector3.UP
	pm.emission_ring_height = 0.2
	pm.direction = Vector3.UP
	pm.spread = 40.0
	pm.initial_velocity_min = 1.0
	pm.initial_velocity_max = 3.0
	pm.gravity = Vector3(0, -4, 0)
	pm.color = spell.shield_arcs
	pm.hue_variation_min = -spell.shield_rainbow * 0.5
	pm.hue_variation_max = spell.shield_rainbow * 0.5
	var shrink := Curve.new()
	shrink.add_point(Vector2(0, 1))
	shrink.add_point(Vector2(1, 0))
	var shrink_tex := CurveTexture.new()
	shrink_tex.curve = shrink
	pm.scale_curve = shrink_tex
	var cube := BoxMesh.new()
	cube.size = Vector3.ONE * 0.1
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/fire_voxel.gdshader")
	cube.material = mat
	var p := GPUParticles3D.new()
	p.process_material = pm
	p.draw_pass_1 = cube
	p.amount = 60 if spell.is_divine() else 36
	p.lifetime = 0.6
	p.emitting = false
	p.position.y = 0.6
	p.local_coords = true
	p.visibility_aabb = AABB(Vector3(-16, -2, -16), Vector3(32, 6, 32))
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p
