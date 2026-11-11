class_name MagicRing
extends WarpWave
## A warped annulus rolling outward from the caster (double-tap Space with a
## tier 4+ or Divine spell). Looks like the warp shield: bent space with
## crackling arcs in the spell's colors. Hits each obstacle once as the ring
## passes it, for less damage the further out it gets. Shakes nearby cameras.
## Clashes with enemy ripples where they touch (see WarpWave).
## It stays strong all the way out and then bursts into motes (SpellFX),
## and every hit flashes in the spell's style.

signal hit(target: Node, damage: int)

const START_RADIUS := 0.8
const BAND := 1.2  # ring thickness in meters
const MIN_DAMAGE_SHARE := 0.5  # what's left at the very edge of the range
const SHAKE_STRENGTH := 0.3
const SHAKE_RADIUS := 16.0
const BURST_TIME := 0.18  # the flare as it bursts at the edge of its range

var spell: Item
var damage_multiplier := 1.0
## Another player's ring online: shown, but hurts nothing here.
var visual_only := false
var _hit := {}  # instance id -> true
var _mesh := MeshInstance3D.new()
var _torus := TorusMesh.new()
var _sparks: Array[GPUParticles3D] = []
var _bursting := -1.0  # counts up while bursting


static func cast(parent: Node3D, origin: Vector3, p_spell: Item, delay := 0.0, multiplier := 1.0) -> MagicRing:
	var ring := MagicRing.new()
	ring.spell = p_spell
	ring.damage_multiplier = multiplier
	parent.add_child(ring)
	ring.global_position = origin
	if parent is SpatialWorld: ring.global_basis = parent.surface_frame(origin).basis
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
	_material.set_shader_parameter("darkness", SpellFX.style(spell).darkness)
	_sparks = SpellFX.edge_motes(spell)
	for p in _sparks:
		p.position.y = 0.6
		add_child(p)
	_apply()


func _begin() -> void:
	visible = true
	set_physics_process(true)
	for p in _sparks: p.emitting = true
	SpellFX.cast(get_parent(), global_position, spell)
	CameraShake.shake_at(global_position, SHAKE_STRENGTH * (1.4 if spell.is_divine() else 1.0), SHAKE_RADIUS)


func _physics_process(delta: float) -> void:
	if _bursting >= 0.0:
		_burst_step(delta)
		return
	var reach: float = spell.ring.range
	var previous := radius
	previous_radius = radius
	radius += spell.ring.speed * delta
	_clash(delta)
	_damage_band(previous, radius)
	_apply()
	if radius >= reach:
		_burst()


## Reached the edge: the ring flares, swells and scatters into sparks.
func _burst() -> void:
	_bursting = 0.0
	for p in _sparks: p.emitting = false
	SpellFX.ring_burst(get_parent(), global_transform, radius, spell)
	if spell.is_divine():
		CameraShake.shake_at(global_position, SHAKE_STRENGTH * 0.6, SHAKE_RADIUS)


func _burst_step(delta: float) -> void:
	_bursting += delta
	var t := _bursting / BURST_TIME
	if t >= 1.0:
		queue_free()
		return
	radius += spell.ring.speed * delta * 0.6
	band = BAND * (0.5 + t * 1.5)
	_torus.inner_radius = maxf(0.05, radius - band * 0.5)
	_torus.outer_radius = radius + band * 0.5
	_material.set_shader_parameter("intensity", (1.0 - t) * (1.0 - t))
	_material.set_shader_parameter("pulse", 1.0 - t)
	_material.set_shader_parameter("ring_radius", radius)


func _apply() -> void:
	var reach: float = spell.ring.get("range", 6.0)
	var t := clampf(radius / reach, 0.0, 1.0)
	# The band keeps the same thickness as the ring grows (and thins as it fades).
	band = BAND * (1.0 - t * 0.5)
	_torus.inner_radius = maxf(0.05, radius - band * 0.5)
	_torus.outer_radius = radius + band * 0.5
	_mesh.scale = Vector3(1.0, 0.6, 1.0)  # a little flatter than round
	_material.set_shader_parameter("intensity", 1.0 - t * 0.3)  # holds until it bursts
	_material.set_shader_parameter("ring_radius", radius)
	for p in _sparks:
		(p.process_material as ParticleProcessMaterial).emission_ring_radius = radius
		(p.process_material as ParticleProcessMaterial).emission_ring_inner_radius = maxf(0.0, radius - 0.3)


## Hits obstacles the ring passed over this frame.
func _damage_band(inner: float, outer: float) -> void:
	if visual_only:
		return
	var query := PhysicsShapeQueryParameters3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = outer + BAND * 0.5
	query.shape = sphere
	query.transform = Transform3D(Basis(), global_position + global_basis.y * 0.9)
	query.collision_mask = Player.OBSTACLE_LAYER | Player.ENEMY_LAYER
	for result in get_world_3d().direct_space_state.intersect_shape(query, 64):
		var target: Node = result.collider
		if _hit.has(target.get_instance_id()) or not target.has_method("take_hit"):
			continue
		var point: Vector3 = global_basis.inverse()*(target.global_position-global_position)
		var flat := Vector2(point.x,point.z)
		if flat.length() < inner - BAND:
			continue
		_hit[target.get_instance_id()] = true
		var strength := strength_toward(target.global_position)
		if strength < 0.05:
			continue  # this part of the ring was cancelled out
		var damage := damage_at_distance(flat.length(), strength)
		if target is Enemy:
			(target as Enemy).receive_weapon_hit(target.global_position + global_basis.y, (global_basis*Vector3(flat.x,0,flat.y)).normalized(), damage, spell, true)
		else:
			target.take_hit(target.global_position + global_basis.y, (global_basis*Vector3(flat.x,0,flat.y)).normalized(), damage)
		hit.emit(target, damage)
		SpellFX.hit(get_parent(), target.global_position + global_basis.y * 0.9, (global_basis*Vector3(flat.x,0,flat.y)).normalized(), spell)


## Damage at the current radius (it weakens the further out it gets).
func power() -> float:
	var reach: float = spell.ring.get("range", 6.0)
	return spell.ring.damage * damage_multiplier * lerpf(1.0, MIN_DAMAGE_SHARE, clampf(radius / reach, 0.0, 1.0))


## Damage before enemy defense; shared with integration checks.
func damage_at_distance(distance: float, arc_strength := 1.0) -> int:
	var falloff := lerpf(1.0, MIN_DAMAGE_SHARE, clampf(distance / spell.ring.range, 0.0, 1.0))
	return maxi(1, roundi(spell.ring.damage * damage_multiplier * falloff * arc_strength))
