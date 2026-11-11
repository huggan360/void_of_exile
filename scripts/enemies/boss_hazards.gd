class_name BossHazards
extends Node3D
## Telegraphed ground attacks owned by one boss encounter: marked circles
## that erupt once, lingering patches, straight lanes and curtains, and
## sweeping rays. Every hazard shows a clear warning first (a dim outline
## whose fill grows until it fires), then a bright active look. Damage uses
## explicit hit groups: a player is hit at most once per `tick` seconds by a
## group, however many of its pieces overlap them. Positions lock when the
## warning appears; nothing follows the player after that.
##
## The owning boss calls clear() on death, reset or a phase change; nothing
## here can hurt anyone after that.
##
## Online the boss runs on the server, which keeps these only for its own
## bookkeeping (they hurt nobody there) and sends every one it makes to the
## clients near it: each client builds the same hazard and decides itself
## whether it was hit (see Net).

const FLOOR_LIFT := 0.06
const WARN_ALPHA := 0.22
const ACTIVE_ALPHA := 0.75
const SHAKE := 0.18

var director: EnemyDirector
var _hazards: Array[Dictionary] = []
var _last_hit := {}  # group -> {player: seconds}
var _next_group := 0
var _alarm_cycle := -1
## The boss these belong to (its net id names them online).
var boss: Node
var _net_depth := 0  # >0 while one public call builds through another
var _by_net := {}  # client: net id -> hazard
var _next_net := 0


static func create(p_director: EnemyDirector) -> BossHazards:
	var h := BossHazards.new()
	h.director = p_director
	h.name = "BossHazards"
	p_director.add_child(h)
	return h


## A marked circle that erupts once after `warn` seconds.
## opts: {patch = {time, tick, damage = Vector2i}} leaves a burning patch;
## {magic = true}; {group = "name"} shares a hit cooldown; {spikes = true}
## shatters into a ring of harmless voxel spikes.
func circle(pos: Vector3, radius: float, warn: float, damage: Vector2i, color: Color, opts := {}) -> Dictionary:
	var sent := [pos, radius, warn, damage, color, opts]
	_net_depth += 1
	pos.y = director.world.ground_height(pos.x, pos.z)
	var h := _make("circle", pos, color, warn, 0.05, opts)
	h.radius = radius
	h.damage = damage
	h.node = _disc(radius, color)
	h.fill = _disc(radius, color)
	h.node.add_child(h.fill)
	add_child(h.node)
	h.node.global_position = pos + Vector3.UP * FLOOR_LIFT
	_net_depth -= 1
	_send("circle", sent, h, 3)
	return h


## A straight strip from `center` along `dir` (flat), `length` long. Warns,
## then is active for `active` seconds, hitting at most once per `tick`.
## opts.height > 0 raises a visible curtain wall above it.
func lane(center: Vector3, dir: Vector3, length: float, width: float, warn: float, active: float,
		damage: Vector2i, tick: float, color: Color, opts := {}) -> Dictionary:
	var sent := [center, dir, length, width, warn, active, damage, tick, color, opts]
	_net_depth += 1
	center.y = director.world.ground_height(center.x, center.z)
	dir.y = 0.0
	var h := _make("lane", center, color, warn, active, opts)
	h.dir = dir.normalized()
	h.length = length
	h.width = width
	h.damage = damage
	h.tick = tick
	h.node = Node3D.new()
	add_child(h.node)
	h.node.global_position = center + Vector3.UP * FLOOR_LIFT
	h.node.look_at(h.node.global_position + h.dir)
	h.strip = _box(Vector3(width, 0.04, length), color)
	h.node.add_child(h.strip)
	h.fill = _box(Vector3(width, 0.05, length), color)
	h.node.add_child(h.fill)
	var height: float = opts.get("height", 0.0)
	if height > 0.0:
		h.wall = _box(Vector3(width * 0.5, height, length), color)
		h.wall.position.y = height * 0.5
		h.wall.visible = false
		h.node.add_child(h.wall)
	_net_depth -= 1
	_send("lane", sent, h, 6)
	return h


## Same as lane(), between two points (a beam curtain between two towers).
func segment(a: Vector3, b: Vector3, width: float, warn: float, active: float, damage: Vector2i,
		tick: float, color: Color, opts := {}) -> Dictionary:
	var flat := Vector3(b.x - a.x, 0.0, b.z - a.z)
	_net_depth += 1
	var h := lane((a + b) * 0.5, flat, flat.length(), width, warn, active, damage, tick, color, opts)
	_net_depth -= 1
	_send("segment", [a, b, width, warn, active, damage, tick, color, opts], h, 5)
	return h


## A ray whose axis is recomputed every frame by `axis` (returns [origin,
## flat direction]); it reaches `length` from the origin. Used for sweeping
## solar rays. Visual-only while warning.
func ray(axis: Callable, length: float, width: float, warn: float, active: float, damage: Vector2i,
		tick: float, color: Color, opts := {}) -> Dictionary:
	var spec: Array = axis.call()
	_net_depth += 1
	var h := lane(spec[0] + spec[1] * length * 0.5, spec[1], length, width, warn, active, damage, tick, color, opts)
	h.axis = axis
	h.reach = length
	_net_depth -= 1
	_send("ray", [spec, length, width, warn, active, damage, tick, color, opts], h, 5)
	return h


## A purely visual marker (a destination sigil, a charge lane preview).
func marker(pos: Vector3, radius: float, time: float, color: Color) -> Dictionary:
	_net_depth += 1
	var h := circle(pos, radius, time, Vector2i.ZERO, color, {visual = true})
	_net_depth -= 1
	_send("marker", [pos, radius, time, color], h, -1)
	return h


func clear() -> void:
	if Net.is_server() and not _hazards.is_empty():
		Net.server.hazard_event(boss, ["hzclr", _boss_net_id()])
	_by_net.clear()
	for h in _hazards:
		if is_instance_valid(h.node):
			h.node.queue_free()
	_hazards.clear()
	_last_hit.clear()


func count(kind := "") -> int:
	return _hazards.filter(func(h: Dictionary) -> bool: return kind == "" or h.kind == kind).size()


func remove(h: Dictionary) -> void:
	if Net.is_server() and h.has("net_id") and _hazards.has(h):
		Net.server.hazard_event(boss, ["hzrm", _boss_net_id(), h.net_id])
	_by_net.erase(h.get("net_id", -1))
	if is_instance_valid(h.get("node")):
		h.node.queue_free()
	_hazards.erase(h)


func _make(kind: String, pos: Vector3, color: Color, warn: float, active: float, opts: Dictionary) -> Dictionary:
	_next_group += 1
	_next_net += 1
	var h := {net_id = _next_net, kind = kind, pos = pos, color = color, warn = warn, warn_total = maxf(0.01, warn),
		active = active, opts = opts, group = opts.get("group", "h%d" % _next_group), fired = false,
		tick = 0.0, damage = Vector2i.ZERO}
	_hazards.append(h)
	return h


func _physics_process(delta: float) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	for i in range(_hazards.size() - 1, -1, -1):
		var h: Dictionary = _hazards[i]
		if h.has("axis"):
			_follow(h)
		if h.warn > 0.0:
			h.warn -= delta
			var k: float = 1.0 - maxf(0.0, h.warn) / h.warn_total
			_warn_look(h, k, now)
			if h.warn <= 0.0:
				_activate(h)
			continue
		h.active -= delta
		if h.kind == "lane" or h.kind == "patch":
			_damage_area(h, now)
		if h.active <= 0.0:
			if is_instance_valid(h.node):
				h.node.queue_free()
			_hazards.remove_at(i)


func _follow(h: Dictionary) -> void:
	var spec: Array = h.axis.call()
	var origin: Vector3 = spec[0]
	h.dir = (spec[1] as Vector3).normalized()
	h.pos = origin + h.dir * h.reach * 0.5
	h.pos.y = director.world.ground_height(origin.x, origin.z)
	h.node.global_position = h.pos + Vector3.UP * FLOOR_LIFT
	h.node.look_at(h.node.global_position + h.dir)


func _warn_look(h: Dictionary, k: float, now: float) -> void:
	var pulse := 0.5 + 0.5 * sin(now * 14.0)
	# The same clock drives the red floor flash and its audible pulse on each client.
	if not Net.is_server() and h.opts.get("warning_fill",false) and pulse>.9 and is_instance_valid(boss) and boss.def.id=="hollow_king":
		var cycle := int(floor((now*14.0+PI*.5)/TAU))
		if cycle!=_alarm_cycle:
			_alarm_cycle = cycle
			GameAudio.play("warning_pulse",boss.global_position,{source_id=boss.get_instance_id(),cooldown=.3,max_distance=90,priority=3,volume_db=-4})
	match h.kind:
		"circle":
			h.fill.scale = Vector3(k, 1.0, k)
			(h.node as MeshInstance3D).transparency = 1.0 - WARN_ALPHA * (0.7 + 0.3 * pulse)
		"lane":
			h.fill.scale = Vector3(1.0, 1.0, 1.0 if h.opts.get("warning_fill", false) else maxf(0.01, k))
			if h.opts.get("warning_fill", false):
				h.fill.transparency = 1.0 - (0.28 + 0.22 * pulse)
			h.strip.transparency = 1.0 - WARN_ALPHA * (0.7 + 0.3 * pulse)


func _activate(h: Dictionary) -> void:
	match h.kind:
		"circle":
			if h.opts.get("visual", false):
				h.node.queue_free()
				_hazards.erase(h)
				return
			_erupt(h)
		"lane":
			_sound("hazard.strike", h.pos)
			h.strip.transparency = 1.0 - ACTIVE_ALPHA
			h.fill.visible = false
			if h.has("wall"):
				h.wall.visible = true
			if h.active <= 0.0:
				h.node.queue_free()
				_hazards.erase(h)


## A circle erupts: one hit to everyone inside, spikes or a burst, then
## optionally a lingering patch.
func _erupt(h: Dictionary) -> void:
	var pos: Vector3 = h.pos
	for p in _players():
		if Vector2(p.global_position.x - pos.x, p.global_position.z - pos.z).length() < h.radius + EnemyBullets.PLAYER_RADIUS * 0.6:
			_hurt(p, h, Time.get_ticks_msec() / 1000.0, 0.0)
	_spikes(pos, h.radius, h.color)
	_sound("hazard.slam", pos)
	CameraShake.shake_at(pos, SHAKE, 10.0)
	h.node.queue_free()
	_hazards.erase(h)
	var patch: Dictionary = h.opts.get("patch", {})
	if patch.is_empty():
		return
	var p := _make("patch", pos, h.color.darkened(0.2), 0.0, patch.get("time", 3.0), {group = patch.get("group", "patches")})
	p.radius = h.radius
	p.damage = patch.get("damage", Vector2i(20, 25))
	p.tick = patch.get("tick", 0.75)
	p.node = _disc(h.radius, h.color.darkened(0.2))
	(p.node as MeshInstance3D).transparency = 1.0 - ACTIVE_ALPHA * 0.8
	add_child(p.node)
	p.node.global_position = pos + Vector3.UP * FLOOR_LIFT


func _damage_area(h: Dictionary, now: float) -> void:
	if h.damage == Vector2i.ZERO:
		return
	for p in _players():
		var inside := false
		var rel: Vector3 = p.global_position - h.pos
		rel.y = 0.0
		if h.kind == "patch":
			inside = rel.length() < h.radius
		else:
			var along: float = rel.dot(h.dir)
			var side: float = (rel - h.dir * along).length()
			inside = absf(along) <= h.length * 0.5 and side <= h.width * 0.5 + EnemyBullets.PLAYER_RADIUS * 0.5
		if inside:
			_hurt(p, h, now, h.tick)


func _hurt(p: Node3D, h: Dictionary, now: float, tick: float) -> void:
	if not _last_hit.has(h.group):
		_last_hit[h.group] = {}
	var last: float = _last_hit[h.group].get(p, -100.0)
	if now - last < maxf(tick, 0.05):
		return
	_last_hit[h.group][p] = now
	var mult := 1.0
	if not Net.is_client() and director.world is DungeonWorld: mult = float(director.world.definition.enemy_damage_multiplier)
	# Actual fire pools/eruptions ignite; their zero-damage floor warnings do not.
	if not Net.is_client() and h.damage.y>0 and is_instance_valid(boss) and boss.def.id in ["vharok", "magma_warden", "pyre_ent", "blue_dragon"]:
		GameServer.apply_buff(p.player_id,"burning",Burning.CONTACT_DURATION,1,boss.def.enemy_name)
	p.take_damage(float(randi_range(h.damage.x, h.damage.y)) * mult, false, h.opts.get("magic", false))


## The space bosses' hazards strike and slam audibly (clients only; one per
## boss at a time so a field of circles is one sound, not twenty).
func _sound(event: String, pos: Vector3) -> void:
	if Net.is_server() or not is_instance_valid(boss) or not GameAudio._in_spatial_world(boss): return
	GameAudio.play(event, pos, {source_id = boss.get_instance_id(), cooldown = 0.12, max_distance = 70.0})


func _players() -> Array:
	if Net.is_server():
		return []  # the clients decide who their hazards hit
	return director.bullets.players.filter(func(p: Variant) -> bool: return is_instance_valid(p) and not p.frozen)


## Harmless voxel shards thrown up where a circle erupted.
func _spikes(pos: Vector3, radius: float, color: Color) -> void:
	var pts := PackedVector3Array()
	var cols := PackedColorArray()
	for k in 40:
		var r := Vector2.from_angle(randf() * TAU) * sqrt(randf()) * radius
		pts.append(pos + Vector3(r.x, randf() * 1.4, r.y))
		cols.append(color.lightened(randf() * 0.4))
	Debris.burst_points(director, pts, cols, 0.14, 40, pos, pos.y, 0.35)


func _disc(radius: float, color: Color) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = 0.04
	mesh.radial_segments = 32
	mesh.rings = 1
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _material(color)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.transparency = 1.0 - WARN_ALPHA
	return mi


func _box(size: Vector3, color: Color) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _material(color)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.transparency = 1.0 - WARN_ALPHA
	return mi


static var _materials := {}


static func _material(color: Color) -> StandardMaterial3D:
	if _materials.has(color):
		return _materials[color]
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 1.4
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.no_depth_test = false
	_materials[color] = mat
	return mat


# --- Online ------------------------------------------------------------------------

## The sweeping rays (the server sends where they point with each snapshot).
func rays() -> Array:
	return _hazards.filter(func(h: Dictionary) -> bool: return h.has("axis"))


func _boss_net_id() -> int:
	return boss.net_id if is_instance_valid(boss) else 0


## Server: tells the clients about a hazard just made by a public call.
## damage_at: which argument is its damage (scaled by the server config).
func _send(method: String, args: Array, h: Dictionary, damage_at: int) -> void:
	if not Net.is_server() or _net_depth > 0:
		return
	if damage_at >= 0:
		args[damage_at] = Net.server.scaled_vector_damage(boss, args[damage_at])
	Net.server.hazard_event(boss, ["hz", _boss_net_id(), method, args, h.net_id])


## Client: builds the hazard the server made. Rays follow the axis the
## server keeps sending (see Boss.net_rays).
func net_create(method: String, args: Array, id: int) -> void:
	var h: Dictionary
	match method:
		"ray":
			var start: Array = args[0]
			var axis := func() -> Array:
				return boss.net_rays.get(id, start) if is_instance_valid(boss) else start
			args[0] = axis
			h = callv("ray", args)
		_:
			h = callv(method, args)
	_by_net[id] = h


func net_remove(id: int) -> void:
	if _by_net.has(id):
		remove(_by_net[id])
