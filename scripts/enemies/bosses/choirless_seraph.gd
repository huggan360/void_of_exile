extends SurfaceBoss
## The Choirless Seraph (9.0/10): a fallen angel that lost its voice. Its bell
## tolls roll across the nave as rings of warped air with notes in them, wax
## rains in a grid, its glass wings sweep the room from both sides, and a
## slow hymn silences whoever it touches. Kindled, its candle wings spiral
## flame; hollow, stained-glass light turns round the nave.
const HYMN := Color("c070ff")
const ROSE := Color("e04a8a")
const CANDLE := Color("ffcf8a")
const BELL := Color("d8c0ff")
var _ray_angle := 0.0
var _ray_speed := 0.0
var _flame := 0.0


func _ready() -> void:
	super._ready()
	glow_color = CANDLE
	glow_alt = HYMN


func _combat(delta: float) -> void:
	_ray_angle += _ray_speed * delta


func _phase_started(index: int) -> void:
	behavior = "stationary"
	_ray_speed = 0.0
	despawn_support("choir")
	match index:
		0: set_cycle(15.0, [[0.6, _toll], [4.0, _glass_wings], [8.0, _wax_rain], [11.5, _hymn]])
		1:
			_choir()
			set_cycle(16.0, [[0.6, _candle_spiral], [4.5, _toll], [8.0, _glass_wings], [11.0, _wax_rain], [13.5, _hymn]])
		2:
			GlowRipples.flood(self, -0.4, 2.0)
			set_cycle(16.0, [[0.6, _windows], [5.0, _toll], [7.5, _candle_spiral], [11.0, _glass_wings], [13.5, _hymn]])


func _rest_line(next: int) -> String:
	return "The candles in its wings catch fire" if next == 1 else "The glass breaks; something hollow looks out"


func _reset_hook() -> void:
	super._reset_hook()
	_ray_speed = 0.0


func _death_started() -> void:
	_ray_speed = 0.0
	super._death_started()


func _note(speed := 5.0) -> Dictionary:
	return bolt("bell_note", BELL, Vector2i(108, 136), speed, {size = 1.0})


## Bell strokes roll out as warped rings; notes ride them with two gaps.
func _toll() -> void:
	model.boss_pose("slam_windup", 1.8)
	var gap := gap_angle() + randf_range(-0.4, 0.4)
	mark_ring_gaps(gap, 50.0, 1.1, BELL)
	var strokes := 2 if phase == 0 else 3
	for stroke in strokes:
		after(1.1 + stroke * 0.9, func() -> void:
			model.boss_pose("slam_release", 0.5)
			cast_ripple(global_position, {radius = 18.0, speed = 4.2 + stroke * 0.5,
				damage_min = 70, damage_max = 92, knockback = 0.35}, BELL, players(), [])
			fire_ring(shot_origin(), 26, _note(5.0 + stroke * 0.4), gap + stroke * 0.12, 50.0)
			glow_wave(HYMN if stroke % 2 else CANDLE, {speed = 9.0, strength = 2.6}))


## The glass wings sweep from both sides, one after the other.
func _glass_wings() -> void:
	model.boss_pose("summon", 2.6)
	var center := gap_angle()
	for side: float in [-1.0, 1.0]:
		for k in 14:
			after((0.7 if side < 0 else 1.6) + k * 0.06, func() -> void:
				var a := center + side * deg_to_rad(90.0 - k * 12.0)
				shoot(shot_origin(), Vector3.FORWARD.rotated(Vector3.UP, a),
					bolt("glass_pane", ROSE if k % 2 else HYMN, Vector2i(112, 140), 8.0, {pierce_players = true})))


## Wax falls in a grid of circles; the lanes between them stay dry.
func _wax_rain() -> void:
	model.boss_pose("cast", 1.8)
	var forward := aim_dir()
	var across := forward.rotated(Vector3.UP, PI * 0.5)
	var r := room_radius()
	var lane := randi_range(-2, 2)
	for row in range(-4, 5):
		for col in range(-4, 5):
			if col == lane or row == -lane: continue  # a dry cross to stand in
			var spot := encounter_center + forward * row * 3.4 + across * col * 3.4
			if Vector2(spot.x - encounter_center.x, spot.z - encounter_center.z).length() > r: continue
			hazards.circle(spot, 1.4, 1.2 + (absi(row) + absi(col)) * 0.08, Vector2i(104, 130), CANDLE,
				{patch = {time = 1.6, tick = 0.6, damage = Vector2i(30, 38)}})


## A slow, heavy hymn: whoever it touches can't fight back for a while.
func _hymn() -> void:
	model.boss_pose("channel", 2.0)
	var direction := aim_dir()
	after(0.9, func() -> void:
		var hush := bolt("wax_tear", HYMN, Vector2i(120, 150), 4.2, {size = 1.8, radius = 0.42, magic = true,
			effects = [{id = "quiet", duration = 2.5}], effect_source = "The Choirless Seraph's hymn"})
		fire_fan(shot_origin(), direction, 3, 22.0, hush)
		fire_ring(shot_origin(), 12, _note(4.0), atan2(-direction.x, -direction.z), 70.0))


## Kindled: candle flames spiral out of its wings.
func _candle_spiral() -> void:
	model.boss_pose("channel", 3.4)
	_flame += 0.5
	var start := _flame
	for beat in 14:
		after(0.6 + beat * 0.22, func() -> void:
			for arm in 6:
				var a := start + beat * 0.17 * (1.0 if arm % 2 == 0 else -1.0) + arm * TAU / 6.0
				shoot(shot_origin(), Vector3.FORWARD.rotated(Vector3.UP, a), bolt("candle_flame", CANDLE, Vector2i(104, 130), 6.0)))


## Hollow: stained-glass light turns round the nave.
func _windows() -> void:
	model.boss_pose("cast", 1.6)
	_ray_speed = 0.5 * (1.0 if randf() < 0.5 else -1.0)
	for k in 4:
		var offset := TAU * k / 4.0
		var axis := func() -> Array:
			var dir := Vector3.FORWARD.rotated(Vector3.UP, _ray_angle + offset)
			return [global_position + dir * 2.2, dir]
		hazards.ray(axis, 32.0, 1.2, 1.2, 4.5, Vector2i(130, 160), 0.6, ROSE if k % 2 else HYMN, {group = "windows"})
	after(5.8, func() -> void: _ray_speed = 0.0)


func _choir() -> void:
	model.boss_pose("summon", 2.4)
	for side: float in [-1.0, 1.0]:
		var helper := spawn_support("candle_wraith", encounter_center + Vector3(side * 8.0, 0, 4.0), "choir", true)
		if helper: arm_summon(helper, 0.3)
