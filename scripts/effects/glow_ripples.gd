class_name GlowRipples
extends Node
## The glow framework: light that blinks and ripples through glowing things
## (dungeon vegetation, veins in the rock, glass, candles).
##
## Any ShaderMaterial whose shader includes shaders/include/glow_ripple.gdshaderinc
## can be watched (watch()); every frame the live ripples are written into it.
## The fine dungeon terrain and GlowFlora use it.
##
##   GlowRipples.emit(source, at, color, opts)   a ring of light from `at`.
##       opts: speed (m/s), width (m), range (m), strength, flat (measure along
##       the ground only, so a ring from a room's middle climbs whole walls),
##       rings + gap (several rings, `gap` seconds apart), delay.
##   GlowRipples.flood(source, level, time, back)   everything glows toward
##       `level` over `time` s (1 = all of it shines; a dungeon lights up when
##       its boss falls); back > 0 returns to the old level after that long.
##   Chatter: plants talking among themselves. Every few tenths of a second a
##       small ripple leaves one of `chatter_points`, so light seems to pass
##       from plant to plant.
##
## On the server emit() and flood() are sent to the players in that realm;
## the node itself only lives on clients (one per world, DungeonWorld adds it).

const MAX := 16

static var current: GlowRipples

var chatter_points := PackedVector3Array()
var chatter_colors: Array[Color] = []
var chatter_every := Vector2(0.3, 0.9)
var chatter_range := Vector2(5.0, 12.0)
var chatter_speed := 3.2
var chatter_strength := 0.9
var _materials: Array[ShaderMaterial] = []
var _ripples: Array[Dictionary] = []  # {at, start, speed, width, range, strength, color, flat}
var _now := 0.0
var _last_sound := -10.0
var _level := 0.0
var _level_from := 0.0
var _level_to := 0.0
var _level_time := 0.0
var _level_age := 0.0
var _level_back := -1.0
var _level_rest := 0.0
var _chatter_left := 0.5
var _rng := RandomNumberGenerator.new()


static func emit(source: Node, at: Vector3, color: Color, opts := {}) -> void:
	if Net.is_server():
		Net.server.fx(source, at, ["glow", at, color, opts])
	elif current:
		current.add(at, color, opts)


static func flood(source: Node, level: float, time := 1.5, back := -1.0) -> void:
	if Net.is_server():
		Net.server.fx(source, Vector3.INF, ["glowall", level, time, back])
	elif current:
		current.set_level(level, time, back)


func _enter_tree() -> void:
	current = self
	_rng.randomize()


func _exit_tree() -> void:
	if current == self:
		current = null
	for material in _materials:
		material.set_shader_parameter("gr_count", 0)
		material.set_shader_parameter("gr_level", 0.0)


func watch(material: ShaderMaterial) -> void:
	if material and not material in _materials:
		_materials.append(material)


func add(at: Vector3, color: Color, opts := {}) -> void:
	_sound(at, opts)
	for ring in int(opts.get("rings", 1)):
		_ripples.append({at = at, color = color, start = _now + float(opts.get("delay", 0.0)) + ring * float(opts.get("gap", 0.6)),
			speed = float(opts.get("speed", 6.0)), width = float(opts.get("width", 1.6)), range = float(opts.get("range", 20.0)),
			strength = float(opts.get("strength", 1.5)), flat = bool(opts.get("flat", false))})
	# The oldest give way when there are too many at once.
	while _ripples.size() > MAX:
		_ripples.pop_front()


## A soft bloom where a ripple starts: fuller for a big pulse, sparse and
## quiet for the plants' chatter.
func _sound(at: Vector3, opts: Dictionary) -> void:
	var chatter := bool(opts.get("chatter", false))
	if _now - _last_sound < (1.2 if chatter else 0.2) or chatter and _rng.randf() > 0.35:
		return
	_last_sound = _now
	var size := float(opts.get("range", 20.0)) * float(opts.get("strength", 1.5))
	var volume := -13.0 if chatter else lerpf(-9.0, 1.0, clampf(size / 60.0, 0.0, 1.0))
	var options := {bus = "SFX", volume_db = volume, max_distance = clampf(float(opts.get("range", 20.0)) + 20.0, 24.0, 70.0), cooldown = 0.1}
	var delay := float(opts.get("delay", 0.0))
	if delay > 0.0: get_tree().create_timer(delay).timeout.connect(func() -> void: GameAudio.play("glow_pulse", at, options))
	else: GameAudio.play("glow_pulse", at, options)


func set_level(level: float, time := 1.5, back := -1.0) -> void:
	_level_from = _level
	_level_to = level
	_level_time = maxf(0.01, time)
	_level_age = 0.0
	_level_rest = _level if back > 0.0 else level
	_level_back = back


func _process(delta: float) -> void:
	_now += delta
	_level_age += delta
	_level = lerpf(_level_from, _level_to, smoothstep(0.0, 1.0, _level_age / _level_time))
	if _level_back > 0.0 and _level_age >= _level_time + _level_back:
		set_level(_level_rest, _level_time)
	_chatter(delta)
	_ripples = _ripples.filter(func(r: Dictionary) -> bool:
		return (_now - r.start) * r.speed <= r.range + r.width * 2.0)
	var origins := PackedVector4Array()
	var colors := PackedVector4Array()
	var shapes := PackedVector4Array()
	origins.resize(MAX)
	colors.resize(MAX)
	shapes.resize(MAX)
	for i in _ripples.size():
		var r: Dictionary = _ripples[i]
		var c: Color = r.color
		origins[i] = Vector4(r.at.x, r.at.y, r.at.z, r.start)
		colors[i] = Vector4(c.r, c.g, c.b, r.strength)
		shapes[i] = Vector4(r.speed, r.width, r.range, 1.0 if r.flat else 0.0)
	for material in _materials:
		material.set_shader_parameter("gr_origin", origins)
		material.set_shader_parameter("gr_color", colors)
		material.set_shader_parameter("gr_shape", shapes)
		material.set_shader_parameter("gr_count", _ripples.size())
		material.set_shader_parameter("gr_now", _now)
		material.set_shader_parameter("gr_level", _level)


func _chatter(delta: float) -> void:
	if chatter_points.is_empty() or chatter_colors.is_empty():
		return
	_chatter_left -= delta
	if _chatter_left > 0.0:
		return
	_chatter_left = _rng.randf_range(chatter_every.x, chatter_every.y)
	# Only the plants near someone talk where it can be seen.
	var camera := get_viewport().get_camera_3d()
	var near := camera.global_position if camera else Vector3.ZERO
	for attempt in 6:
		var at := chatter_points[_rng.randi() % chatter_points.size()]
		if camera and Vector2(at.x - near.x, at.z - near.z).length() > 38.0:
			continue
		add(at, chatter_colors[_rng.randi() % chatter_colors.size()], {speed = chatter_speed,
			width = 0.9, range = _rng.randf_range(chatter_range.x, chatter_range.y), strength = chatter_strength, chatter = true})
		return
