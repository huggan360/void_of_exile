extends Boss
## The Hollow Crown, Hollow Throne (Deep Dark). A floating crowned void spirit
## whose magic bends: its shots orbit, curl into whirlpools and fall inward.
##
## 1 Veiled Monarch (100-72%)  drifts within 4.5 m of the throne. A halo of
##    bolts orbits it, echo rings (a violet ring, then the same ring again
##    slower in magenta), a whirlpool of curling bolts, the black sun (a slow
##    orb that bursts into needles) and paired rune bolts.
## 2 Court of Echoes (72-35%)  four Mirror Shades rise around the throne.
##    It teleports between sockets; the spot it leaves bursts into an
##    afterimage ring. Reversed whirlpools, void seams, echo rings, the sun.
## 3 Crown Unbound (35-0%)  centered: it channels a vortex of curling arms,
##    then the crown collapses (rings of bolts flying in from the walls),
##    twin black suns, and a wide orbiting halo.
## Phase changes are a three-second rest (Boss.begin_rest).

const VIOLET := Color(0.75, 0.35, 0.95)
const MAGENTA := Color(1.0, 0.35, 0.85)
const WARN := Color(0.85, 0.4, 1.0)
const SOCKETS := 6
const SHADES := 4

var _drift_target := Vector3.ZERO
var _drift_timer := 0.0
var _teleporting := false
var _whirl_sign := 1.0
var _vortex := 0.0
var _vortex_angle := 0.0
var _vortex_next := 0.0
var _centering := false


func _phase_started(index: int) -> void:
	hazards.clear()
	_restore_body()
	status_text = ""
	match index:
		0:
			set_cycle(10.0, [[0.0, _halo.bind(3.5, 10, 1.25)], [2.0, _echo_rings], [4.4, _black_sun.bind(1)],
					[6.4, _whirlpool], [8.4, _rune_pairs]])
		1:
			_summon_court()
		2:
			despawn_support("add")  # the shades dissipate
			_centering = true
			set_cycle(12.0, [[0.0, _channel], [5.8, _collapse], [8.0, _black_sun.bind(2)], [9.8, _halo.bind(5.5, 14, 2.0)]])


func _threshold_reached(next: int) -> void:
	if resting: return
	_vortex = 0.0
	_restore_body()
	begin_rest(func() -> void: _enter_phase(next), "The Crown dims", "kneel")


func _combat(delta: float) -> void:
	if resting: return
	match phase:
		0:
			_drift_timer -= delta
			if _drift_timer <= 0.0 or global_position.distance_to(_drift_target) < 0.5:
				_drift_timer = randf_range(2.0, 3.5)
				_drift_target = in_arena(encounter_center + Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)) * 4.5, 4.5)
			steer_to(_drift_target, 1.7)
		1:
			if not _teleporting:
				behavior = "stationary"
		2:
			if _centering and Vector2(global_position.x - encounter_center.x, global_position.z - encounter_center.z).length() > 0.4:
				steer_to(encounter_center, 3.0)
			else:
				_centering = false
				behavior = "stationary"
			_run_vortex(delta)


# --- Shared attacks ---------------------------------------------------------------------

## A ring of bolts that orbits the Crown, `loops` times around.
func _halo(radius: float, count: int, loops: float) -> void:
	model.boss_pose("channel", 1.2)
	pulse_glow(1.8, 0.6)
	var sense := 1.0 if randf() < 0.5 else -1.0
	after(0.6, func() -> void:
		fire_orbit(global_position, radius, count, 5.0, loops, sense,
				Boss.shot("bolt", VIOLET, Vector2i(55, 70), 5.0, 0.16, 1.0), randf() * TAU))


## A ring, then the same ring again: slower, magenta, half a step turned.
func _echo_rings() -> void:
	model.boss_pose("cast", 1.4)
	pulse_glow(1.6, 0.5)
	var offset := randf() * TAU
	after(0.5, func() -> void: _ring(14, offset, Boss.shot("bolt", VIOLET, Vector2i(55, 70), 6.5, 0.16, 22.0)))
	after(1.0, func() -> void: _ring(14, offset + PI / 14.0, Boss.shot("bolt", MAGENTA, Vector2i(55, 70), 4.5, 0.16, 22.0)))


func _ring(count: int, offset: float, attack: Dictionary, from := Vector3.INF) -> void:
	var origin := shot_origin() if from == Vector3.INF else from
	for k in count:
		shoot(origin, Vector3.FORWARD.rotated(Vector3.UP, offset + k * TAU / count), attack)


## Bolts leave in a ring and all curl the same way: a whirlpool.
func _whirlpool() -> void:
	model.boss_pose("channel", 1.3)
	pulse_glow(1.8, 0.6)
	var sense := _whirl_sign
	_whirl_sign = -_whirl_sign
	var offset := randf() * TAU
	after(0.6, func() -> void:
		_ring(16, offset, Boss.shot("bolt", MAGENTA, Vector2i(55, 70), 6.0, 0.16, 24.0, {turn = 0.45 * sense})))


func _black_sun(count: int) -> void:
	model.boss_pose("cast", 1.2)
	pulse_glow(2.2, 1.0)
	after(1.0, func() -> void:
		var needles := Boss.shot("needle", MAGENTA, Vector2i(45, 55), 6.0, 0.12, 14.0)
		var aim := aim_dir()
		for k in count:
			var dir := aim if count == 1 else aim.rotated(Vector3.UP, deg_to_rad(25.0) * (k * 2 - 1))
			shoot(shot_origin(), dir, Boss.shot("orb", Color(0.25, 0.08, 0.35), Vector2i(75, 90), 3.5, 0.45, 10.0,
					{size = 1.6, effects = [{id = "quiet", duration = 1.75}], effect_source = "Hollow Crown black sun",
						terminal = {delay = 0.4, count = 12 if count > 1 else 8, attack = needles}})))


func _rune_pairs() -> void:
	model.boss_pose("cast", 1.2)
	pulse_glow(1.6, 0.8)
	for k in 3:
		after(0.8 + k * 0.12, func() -> void:
			var dir := aim_dir()
			var side := dir.cross(Vector3.UP) * 0.6
			var attack := Boss.shot("bolt", VIOLET, Vector2i(60, 75), 7.5, 0.16, 20.0)
			shoot(shot_origin() + side, dir, attack)
			shoot(shot_origin() - side, dir, attack))


# --- Phase 2: the court -----------------------------------------------------------------

func _summon_court() -> void:
	behavior = "stationary"
	model.boss_pose("summon", 2.0)
	pulse_glow(2.6, 2.0)
	for i in SHADES:
		var a := TAU * i / SHADES + PI * 0.25
		var shade := spawn_support("mirror_shade", encounter_center + Vector3(cos(a), 0, sin(a)) * 8.0, "add", true)
		if shade:
			arm_summon(shade, 0.2 * i)
	status_text = "The Court of Echoes assembles"
	attack_lock = 2.0
	after(2.0, func() -> void:
		status_text = ""
		set_cycle(10.0, [[0.0, _teleport], [1.8, _whirlpool], [3.4, _seams], [5.0, _teleport], [6.8, _echo_rings], [8.4, _black_sun.bind(1)]]))


## Picks a socket at least 2.5 m from the player, within 8 m, and clear.
func _teleport_target() -> Vector3:
	var start := randi() % SOCKETS
	for k in SOCKETS:
		var a := TAU * ((start + k) % SOCKETS) / SOCKETS
		var socket := encounter_center + Vector3(cos(a), 0, sin(a)) * 4.5
		socket.y = director.world.ground_height(socket.x, socket.z)
		var flat_player := Vector2(socket.x - target().global_position.x, socket.z - target().global_position.z).length()
		var travel := Vector2(socket.x - global_position.x, socket.z - global_position.z).length()
		if flat_player < 2.5 or travel > 8.0 or travel < 2.0:
			continue
		if director.world.enemy_spawn_clear(socket, def.hit_radius * def.model_scale, 2.0):
			return socket
	return Vector3.INF


func _teleport() -> void:
	var dest := _teleport_target()
	if dest == Vector3.INF:
		pulse_glow(0.8, 0.4)  # the cast fizzles; it stays where it is
		return
	_teleporting = true
	model.boss_pose("vanish", 0.85)
	hazards.marker(dest, 1.6, 0.85, MAGENTA)  # the sigil, 0.85 s before arrival
	after(0.35, func() -> void:
		var pts := model.voxel_points(400)
		BlinkVoxels.spawn(director, pts[0], pts[1], global_position + Vector3.UP * height() * 0.5, model.voxel_size() * 1.5)
		var tw := create_tween()
		tw.tween_property(model, "scale", Vector3(0.1, 1.3, 0.1) * def.model_scale, 0.35))
	after(0.7, func() -> void:
		# A short, explicit transit: invisible and untouchable.
		model.visible = false
		collision_layer = 0
		immune = true
		# The afterimage it leaves behind bursts into a ring.
		_ring(12, randf() * TAU, Boss.shot("needle", MAGENTA, Vector2i(50, 60), 5.5, 0.12, 18.0), shot_origin()))
	after(0.85, func() -> void:
		global_position = Vector3(dest.x, global_position.y, dest.z)
		velocity = Vector3.ZERO
		model.visible = true
		var pts := model.voxel_points(400)
		BlinkVoxels.spawn(director, pts[0], pts[1], global_position + Vector3.UP * height() * 0.5, model.voxel_size() * 1.5, true)
		var tw := create_tween()
		tw.tween_property(model, "scale", Vector3.ONE * def.model_scale, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		collision_layer = Player.ENEMY_LAYER
		immune = false
		attack_lock = 0.5 + 0.6)
	after(1.35, func() -> void: _teleporting = false)


func _restore_body() -> void:
	_teleporting = false
	model.visible = true
	model.scale = Vector3.ONE * def.model_scale
	collision_layer = Player.ENEMY_LAYER
	immune = false


func _seams() -> void:
	model.boss_pose("cast", 1.0)
	var at := target().global_position
	var a := randf() * TAU
	for k in 2:
		var dir := Vector3.FORWARD.rotated(Vector3.UP, a + k * PI * 0.5)
		hazards.lane(in_arena(at, 20.0), dir, 8.0, 0.6, 0.9, 1.5, Vector2i(60, 70), 0.75, MAGENTA, {group = "void_seams"})


# --- Phase 3 -------------------------------------------------------------------------------

## Five seconds of curling arms that turn with the Crown.
func _channel() -> void:
	model.boss_pose("channel", 5.6)
	pulse_glow(2.4, 0.6)
	_vortex_angle = randf() * TAU
	after(0.6, func() -> void:
		_vortex = 5.0
		_vortex_next = 0.0)


func _run_vortex(delta: float) -> void:
	if _vortex <= 0.0:
		return
	_vortex -= delta
	_vortex_angle += 0.7 * _whirl_sign * delta
	_vortex_next -= delta
	while _vortex_next <= 0.0 and _vortex > 0.0:
		_vortex_next += 0.22
		var attack := Boss.shot("bolt", MAGENTA, Vector2i(60, 75), 6.0, 0.16, 24.0, {turn = -0.5 * _whirl_sign})
		for k in 3:
			shoot(shot_origin(), Vector3.FORWARD.rotated(Vector3.UP, _vortex_angle + k * TAU / 3.0), attack)
	if _vortex <= 0.0:
		_whirl_sign = -_whirl_sign


## The crown collapses: two rings of bolts fly in from the walls toward it.
func _collapse() -> void:
	model.boss_pose("implode", 2.0)
	pulse_glow(2.6, 1.0)
	var offset := randf() * TAU
	hazards.marker(global_position, 15.0, 1.0, WARN)
	for ring in 2:
		after(1.0 + ring * 0.6, func() -> void:
			var attack := Boss.shot("bolt", VIOLET if ring == 0 else MAGENTA, Vector2i(60, 75), 6.0, 0.16, 14.0)
			for k in 20:
				var radial := Vector3.FORWARD.rotated(Vector3.UP, offset + (k + ring * 0.5) * TAU / 20.0)
				var origin := in_arena(global_position + radial * 15.0, 24.0)
				origin.y = shot_origin().y
				shoot(origin, -radial, attack))


func _reset_hook() -> void:
	_restore_body()
	_vortex = 0.0
	resting = false
	model.boss_pose("idle", 0.1)


func _death_started() -> void:
	_restore_body()
	_vortex = 0.0
	model.boss_pose("defeated", boss_def.death_time + 1.0)


func _dying_update(_k: float) -> void:
	model.scale = Vector3.ONE * def.model_scale
