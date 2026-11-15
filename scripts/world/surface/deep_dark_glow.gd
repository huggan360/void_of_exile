class_name DeepDarkGlow
extends Node
## Client light shared by the streamed Deep Dark plants and obstacles.

const PINK := Color(1.0, 0.28, 0.64)
const LIME := Color(0.68, 1.0, 0.16)
const TRAIL_SIZE := 32
const TRAIL_TIME := 4.0

static var _material: ShaderMaterial
var world: IslandWorld
var ripples := GlowRipples.new()
var _sources := {}  # batch id -> {owner, points, center}
var _trail := PackedVector4Array()
var _trail_next := 0
var _now := 0.0
var _sample_left := 0.0
var _chatter_left := 1.0
var _last := {}
var _rng := RandomNumberGenerator.new()


static func material() -> ShaderMaterial:
	if _material == null:
		_material = ShaderMaterial.new()
		_material.shader = preload("res://shaders/deep_dark_model.gdshader")
	return _material


func _ready() -> void:
	_rng.randomize()
	_trail.resize(TRAIL_SIZE)
	for i in TRAIL_SIZE: _trail[i] = Vector4(0, 0, 0, -TRAIL_TIME)
	add_child(ripples)
	ripples.watch(material())
	ripples.watch(SurfaceFlora.material())
	_write_trail()


func _exit_tree() -> void:
	SurfaceFlora.material().set_shader_parameter("trail_count", 0)


## A few representatives per batch, with no per-plant nodes or processing.
func register_points(owner: Node3D, points: PackedVector3Array) -> void:
	if points.is_empty(): return
	var id := owner.get_instance_id()
	var center := Vector3.ZERO
	for p in points: center += p
	center /= points.size()
	_sources[id] = {owner = weakref(owner), points = points, center = center}
	owner.tree_exiting.connect(func() -> void: _sources.erase(id), CONNECT_ONE_SHOT)


func _process(delta: float) -> void:
	_now += delta
	_sample_left -= delta
	_chatter_left -= delta
	if _sample_left > 0.0: return
	_sample_left = 0.25
	var players: Array = get_tree().get_nodes_in_group("local_player")
	players.append_array(get_tree().get_nodes_in_group("remote_players"))
	var near := Vector3.INF
	var tracked := {}
	for node in players:
		var body := node as Node3D
		if body == null or not body.is_visible_in_tree(): continue
		if body is Player and body.terrain != world.terrain: continue
		var at := body.global_position
		if not near.is_finite(): near = at
		if at.distance_squared_to(near) > 1600.0 or tracked.size() >= 2: continue
		var map := world.generator.map
		if map.cell_biome(floori(at.x), floori(at.z)) != Biomes.DEEP_DARK: continue
		# Airborne players and ships leave no trail on the ground below.
		if absf(at.y - map.ground_y(at.x, at.z)) > 1.2: continue
		var id := body.get_instance_id()
		tracked[id] = true
		var previous: Vector3 = _last.get(id, Vector3.INF)
		if not previous.is_finite() or at.distance_squared_to(previous) >= 0.64:
			_trail[_trail_next] = Vector4(at.x, at.y, at.z, _now)
			_trail_next = (_trail_next + 1) % TRAIL_SIZE
			_last[id] = at
	for id in _last.keys():
		if not tracked.has(id): _last.erase(id)
	_write_trail()
	if near.is_finite() and _chatter_left <= 0.0:
		_chatter_left = _rng.randf_range(1.8, 3.6)
		_chatter(near)


func _write_trail() -> void:
	var mat := SurfaceFlora.material()
	mat.set_shader_parameter("trail_points", _trail)
	mat.set_shader_parameter("trail_now", _now)
	mat.set_shader_parameter("trail_count", TRAIL_SIZE)


func _chatter(near: Vector3) -> void:
	var nearby: Array = []
	for source: Dictionary in _sources.values():
		var owner := source.owner.get_ref() as Node3D
		if owner and owner.is_visible_in_tree() and source.center.distance_squared_to(near) < 3600.0:
			nearby.append(source)
	for attempt in 16:
		if nearby.is_empty(): return
		var source: Dictionary = nearby[_rng.randi_range(0, nearby.size() - 1)]
		var points: PackedVector3Array = source.points
		var at := points[_rng.randi_range(0, points.size() - 1)]
		if at.distance_squared_to(near) > 1024.0: continue
		ripples.add(at, PINK if _rng.randf() < 0.5 else LIME,
			{speed = 3.2, width = 0.8, range = _rng.randf_range(7.0, 13.0), strength = 1.1, flat = true, chatter = true})
		return
