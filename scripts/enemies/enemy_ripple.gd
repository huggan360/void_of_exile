class_name EnemyRipple
extends WarpWave
## A small ring of warped space spreading out from where an enemy's magic
## shot landed (attack "ripple", see EnemyDef.attacks). It hits each player
## it passes once, as magic: the warp shield blocks it completely, and while
## the wave washes over a shield the bubble braces into it (MagicShield.brace)
## and the ring bends around the bubble. Without a shield the player is
## knocked back, harder the stronger the ripple is where it hits. Shakes the
## cameras of players close by, and clashes with players' rings (WarpWave).

const START_RADIUS := 0.2
const BAND := 0.7  # ring thickness in meters
const HEIGHT := 0.9  # ring height above the ground
const PLAYER_RADIUS := 0.45
const SHAKE_STRENGTH := 0.22
const SHAKE_RADIUS := 10.0
const KNOCKBACK_PER_DAMAGE := 0.55  # m/s of push per point of damage

var _players: Array = []
var _skip: Array = []  # players the shot itself already hit
var _reach := 3.0
var _speed := 6.0
var _damage := 10
var _knockback := 1.0
var _mesh := MeshInstance3D.new()
var _torus := TorusMesh.new()


## ripple: {radius, speed, damage_min, damage_max, knockback (multiplier,
## default 1)}. pos is on the ground.
static func spawn(parent: Node, pos: Vector3, ripple: Dictionary, color: Color, players: Array, skip: Array) -> void:
	if Net.is_server():
		Net.server.fx(parent, pos, ["rp", pos, Net.server.scaled_damage(parent, ripple), color])
		return
	var r := EnemyRipple.new()
	r._players = players
	r._skip = skip.duplicate()
	r._reach = ripple.get("radius", 3.0)
	r._speed = ripple.get("speed", 6.0)
	r._damage = randi_range(ripple.get("damage_min", 8), ripple.get("damage_max", 12))
	r._knockback = ripple.get("knockback", 1.0)
	r.team = "enemies"
	r.color = color
	r.band = BAND
	r.radius = START_RADIUS
	r._material = warp_material(color, 0.1)
	r._material.set_shader_parameter("use_arcs", true)
	r._material.set_shader_parameter("arc_strength", r.segments)
	parent.add_child(r)
	r.global_position = pos
	CameraShake.shake_at(pos, SHAKE_STRENGTH, SHAKE_RADIUS)


## The warp look (as the shield) in an enemy's color.
static func warp_material(color: Color, warp: float) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/warp_shield.gdshader")
	mat.set_shader_parameter("tint", color * 1.6)
	mat.set_shader_parameter("arc_color", color.lightened(0.55))
	mat.set_shader_parameter("rainbow", 0.1)
	mat.set_shader_parameter("warp", warp)
	mat.set_shader_parameter("pulse", 0.9)  # glows harder than the player's own magic
	return mat


func _ready() -> void:
	_torus.rings = 48
	_torus.ring_segments = 8
	_mesh.mesh = _torus
	_mesh.material_override = _material
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mesh.position.y = HEIGHT
	_mesh.scale = Vector3(1.0, 0.6, 1.0)
	add_child(_mesh)
	_apply()


func power() -> float:
	return float(_damage)


func _physics_process(delta: float) -> void:
	radius += _speed * delta
	_clash(delta)
	var bent := Vector4.ZERO
	for p: Player in _players:
		if not is_instance_valid(p) or p.frozen:
			continue
		var flat := Vector3(p.global_position.x - global_position.x, 0.0, p.global_position.z - global_position.z)
		var shielded := p.shield.active
		var body := MagicShield.RADIUS if shielded else PLAYER_RADIUS
		var gap := absf(flat.length() - radius)
		var strength := strength_toward(p.global_position)
		if gap > BAND * 0.5 + body or strength < 0.05:
			continue
		if shielded:
			p.shield.brace(flat, clampf((1.0 - gap / (BAND * 0.5 + body)) * 2.0, 0.0, 1.0) * strength)
			bent = Vector4(p.global_position.x, p.global_position.y, p.global_position.z, MagicShield.RADIUS)
		if not p in _skip:
			_skip.append(p)
			var damage := float(_damage) * strength
			p.take_damage(damage, false, true)  # magic: the shield blocks it
			if not shielded:
				p.knockback(flat.normalized() * damage * KNOCKBACK_PER_DAMAGE * _knockback)
	_material.set_shader_parameter("obstacle", bent)
	_apply()
	if radius >= _reach:
		queue_free()


func _apply() -> void:
	var t := clampf(radius / _reach, 0.0, 1.0)
	band = BAND * (1.0 - t * 0.4)
	_torus.inner_radius = maxf(0.02, radius - band * 0.5)
	_torus.outer_radius = radius + band * 0.5
	_material.set_shader_parameter("intensity", 1.0 - t * t)
	_material.set_shader_parameter("ring_radius", radius)
