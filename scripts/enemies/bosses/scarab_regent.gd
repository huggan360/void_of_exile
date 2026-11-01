extends Boss
## Aureate Scarab Regent, Court of the Sun (desert). A gilded pharaoh scarab.
##
## 1 Gilded March (100-70%)  circles the center clockwise (3 m, 2 m/s).
##    Rears up and hurls eight solar discs in every direction; each bends
##    sideways into a wide loop (one pinwheel per throw, alternating sense).
##    Discs are heavy: armor piercing, through players and shields. Between
##    throws: needle fans and sun-mote patterns (curling sunflower arms and
##    a double corona that interlocks like a checkerboard).
## 2 Wings of Noon (70-35%)  walks back to the dais, then summons six Dawn
##    Scarabs on a hexagon (they rise, hold fire for two seconds). Two
##    opposite solar rays reach wall to wall and turn for eight seconds.
##    Aimed needle fans and sun-mote rings come much more often.
## 3 Exposed Sunheart (35-0%)  long charges through players (thrown aside,
##    135+ armor-piercing), each followed by 2.5 s with its heart open
##    (defense 6). Disc wheels, needles and sun motes from phase 1 return
##    between charges, with gapped rings and staggered comets.
## Each phase change is a three-second rest: attacks and shots are cleared,
## the Regent sinks onto its legs, flashes, and rises again.

const GOLD := Color(1.0, 0.82, 0.35)
const PINK := Color(1.0, 0.55, 0.8)
const WARN := Color(1.0, 0.75, 0.3)
const RAY_LENGTH := 27.0  # from the dais to the courtyard walls
const RAY_ACTIVE := 8.0
const RAY_TURN := deg_to_rad(26.0)  # per second while active
const DISC_SPEED := 6.5
const DISC_TURN := 0.6  # loop radius DISC_SPEED / DISC_TURN, about 11 m
const DAWN_COUNT := 6

var _march_angle := 0.0
var _ray_angle := 0.0
var _ray_sign := 1.0
var _ray_t := -1.0  # seconds since the rays started warning (-1 = none)
var _ray_angle_now := 0.0
var _exposed := 0.0
var _last_charge := Vector3.ZERO
var _disc_sign := 1.0
var _mote_angle := 0.0
var _resting := false
var _summoning := false
var _returning := false
var _return_time := 0.0
var _fan_timer := 0.0
var _mote_timer := 0.0
var _charge_passage: Array[PhysicsBody3D] = []


## Only the charge ignores player bodies; terrain and walls still stop it.
func _physics_process(delta: float) -> void:
	if not mirror:
		if is_charging():
			for player in players():
				if player is PhysicsBody3D and player not in _charge_passage:
					add_collision_exception_with(player)
					_charge_passage.append(player)
		else:
			_clear_charge_passage()
	super._physics_process(delta)
	if not mirror and not is_charging(): _clear_charge_passage()


func _clear_charge_passage() -> void:
	for body in _charge_passage:
		if is_instance_valid(body): remove_collision_exception_with(body)
	_charge_passage.clear()


func _charge_contact(player, contact: Vector3) -> void:
	# Thrown to the side of its path, never carried ahead of it.
	var direction: Vector3 = _charge.dir
	var side := Vector3(-direction.z, 0.0, direction.x)
	var offset: Vector3 = player.global_position - contact
	offset.y = 0.0
	var lateral := side.dot(offset)
	if lateral < 0.0 or (absf(lateral) < 0.01 and player.get_instance_id() % 2 == 0): side = -side
	player.knockback(side * 14.0)
	player.take_damage(float(randi_range(_charge.damage.x, _charge.damage.y)), true, false)


func _phase_started(index: int) -> void:
	hazards.clear()
	behavior = "stationary"
	scripted_move = Vector3.ZERO
	velocity = Vector3.ZERO
	_ray_t = -1.0
	_returning = false
	_summoning = false
	_resting = false
	immune = false
	status_text = ""
	charge_arena_radius = 24.0
	match index:
		0:
			_march_angle = randf() * TAU
			set_cycle(10.0, [[0.0, _disc_wheel], [2.6, _needles], [4.2, _sunflower], [6.6, _needles], [8.0, _corona]])
		1:
			if Vector2(global_position.x - encounter_center.x, global_position.z - encounter_center.z).length() > 0.3:
				_returning = true
				_return_time = 0.0
				immune = true
				status_text = "The Regent returns to the sun-dais"
			else:
				_start_noon()
		2:
			despawn_support("add")  # the Dawn Scarabs scatter before the final form
			set_cycle(16.0, [[0.0, _charge_lane.bind(false)], [3.6, _disc_wheel], [5.4, _ring], [6.8, _sunflower],
					[8.4, _charge_lane.bind(true)], [11.8, _needles], [12.6, _comets], [13.8, _corona]])


func _combat(delta: float) -> void:
	if _resting or _summoning: return
	match phase:
		0:
			_march_angle -= 2.0 / 3.0 * delta  # clockwise seen from above
			steer_to(encounter_center + Vector3(cos(_march_angle), 0, sin(_march_angle)) * 3.0, 2.0)
		1:
			if _returning:
				steer_to(encounter_center, 4.0)
				_return_time += delta
				# Close enough, or blocked on the way: it never waits there untouchable.
				if Vector2(global_position.x - encounter_center.x, global_position.z - encounter_center.z).length() < 0.6 or _return_time > 5.0:
					_returning = false
					_start_noon()
				return
			behavior = "stationary"
			_noon(delta)
		2:
			if _exposed > 0.0:
				_exposed -= delta
				if _exposed <= 0.0:
					defense = 15
					status_text = ""


# --- Rests between phases (as Vharok) -------------------------------------------------

func _threshold_reached(next: int) -> void:
	if _resting: return
	_begin_rest(func() -> void: _enter_phase(next))


func _begin_rest(resume: Callable) -> void:
	_resting = true
	immune = true
	behavior = "stationary"
	scripted_move = Vector3.ZERO
	velocity = Vector3.ZERO
	face_override = Vector3.ZERO
	_charge = {}
	_exposed = 0.0
	_ray_t = -1.0
	_scheduled.clear()
	_cycle_events = []
	_volleys.clear()
	set_attacks([])
	hazards.clear()
	# Shots already in the air keep flying; only new attacks stop.
	status_text = "The Regent folds its wings"
	model.boss_pose("kneel", 3.0)
	CameraShake.shake_from(self, global_position, 0.35, boss_def.bar_radius)
	after(2.25, func() -> void:
		model.hit_voxels(global_position + Vector3.UP * height() * 0.45)
		model.boss_pose("rise", 0.75)
		pulse_glow(2.0, 0.7))
	after(3.0, func() -> void:
		_resting = false
		immune = false
		status_text = ""
		resume.call())


## Summons materialize first; their first volley waits two seconds.
func _arm_summon(helper: Enemy, stagger := 0.0) -> void:
	helper.attack_lock = 9999.0
	after(2.0 + stagger, func() -> void:
		if not is_instance_valid(helper) or not helper.is_alive(): return
		helper.attack_lock = 0.0
		for i in helper._attack_timers.size():
			helper._attack_timers[i] = helper.attacks[i].cooldown
			helper._windups[i] = 0.0001)


# --- Shared patterns -------------------------------------------------------------------

## Eight heavy discs in every direction, each curling sideways into a wide loop.
func _disc_wheel() -> void:
	model.boss_pose("throw", 1.3)
	pulse_glow(2.2, 0.8)
	var spin := randf() * TAU
	var turn := DISC_TURN * _disc_sign
	_disc_sign = -_disc_sign
	for k in 8:
		var dir := Vector3.FORWARD.rotated(Vector3.UP, spin + k * TAU / 8.0)
		hazards.lane(global_position + dir * 3.5, dir, 5.0, 1.0, 0.75, 0.0, Vector2i.ZERO, 0.0, WARN)
	after(0.75, func() -> void:
		var attack := Boss.shot("disc", GOLD, Vector2i(85, 100), DISC_SPEED, 0.45, TAU * DISC_SPEED / DISC_TURN * 0.92,
				{size = 1.6, turn = turn, pierce_players = true, pierce_shields = true, armor_piercing = true})
		for k in 8:
			shoot(shot_origin(), Vector3.FORWARD.rotated(Vector3.UP, spin + k * TAU / 8.0), attack))


func _needles() -> void:
	model.boss_pose("cast", 0.8)
	pulse_glow(1.6, 0.6)
	after(0.6, func() -> void:
		fire_fan(shot_origin(), aim_dir(), 7, 10.0, Boss.shot("needle", GOLD, Vector2i(55, 70), 10.0, 0.13, 20.0)))


static func _mote(speed := 6.0) -> Dictionary:
	return Boss.shot("orb", Color(1.0, 0.75, 0.4), Vector2i(45, 60), speed, 0.2, 22.0,
			{size = 1.0, authored_projectile = true, voxel_model = "boss_projectiles/gold_sunmote", pixel_projectile = true,
			projectile_glow = 0.8, fire_brightness = 0.9})


## Five sun-mote arms that curl as they leave: seven quick volleys, each turned 9 degrees.
func _sunflower() -> void:
	model.boss_pose("cast", 1.8)
	pulse_glow(1.8, 0.5)
	var start := randf() * TAU
	var sense := 1.0 if randf() < 0.5 else -1.0
	for v in 7:
		after(0.5 + v * 0.18, func() -> void:
			for k in 5:
				shoot(shot_origin(), Vector3.FORWARD.rotated(Vector3.UP, start + k * TAU / 5.0 + sense * deg_to_rad(9.0) * v), _mote()))


## Two rings of sixteen; the second sits in the gaps of the first.
func _corona() -> void:
	model.boss_pose("cast", 1.2)
	pulse_glow(1.8, 0.5)
	var a := randf() * TAU
	for ring in 2:
		after(0.5 + ring * 0.45, func() -> void: _mote_ring(16, a + ring * TAU / 32.0, 5.5 + ring))


func _mote_ring(count: int, offset: float, speed: float) -> void:
	for k in count:
		shoot(shot_origin(), Vector3.FORWARD.rotated(Vector3.UP, offset + k * TAU / count), _mote(speed))


# --- Phase 2 ----------------------------------------------------------------------------

func _start_noon() -> void:
	behavior = "stationary"
	scripted_move = Vector3.ZERO
	velocity = Vector3.ZERO
	global_position = Vector3(encounter_center.x, global_position.y, encounter_center.z)
	immune = false
	status_text = ""
	_summoning = true
	model.boss_pose("summon", 2.0)
	pulse_glow(2.6, 2.0)
	CameraShake.shake_from(self, global_position, 0.3, boss_def.bar_radius)
	for i in DAWN_COUNT:
		var a := TAU * i / DAWN_COUNT + PI / 6.0
		var dawn := spawn_support("dawn_scarab", encounter_center + Vector3(cos(a), 0, sin(a)) * 9.0, "add", true)
		if dawn:
			_arm_summon(dawn, 0.15 * i)
	status_text = "Dawn Scarabs answer the Regent"
	after(2.0, func() -> void:
		_summoning = false
		status_text = ""
		_fan_timer = 0.4
		_mote_timer = 1.4
		set_cycle(12.0, [[0.0, _rays], [9.2, _sand_spears]]))


func _noon(delta: float) -> void:
	if _ray_t >= 0.0:
		_ray_t += delta
		_ray_angle_now = _ray_angle + clampf(_ray_t - 1.1, 0.0, RAY_ACTIVE) * RAY_TURN * _ray_sign
		if _ray_t > 1.1 + RAY_ACTIVE:
			_ray_t = -1.0
	_fan_timer -= delta
	if _fan_timer <= 0.0:
		_fan_timer = 1.6
		_gold_fan()
	_mote_timer -= delta
	if _mote_timer <= 0.0:
		_mote_timer = 2.4
		_mote_angle += TAU / 24.0  # each ring turns half a gap from the last
		_mote_ring(12, _mote_angle, 5.0)


func _rays() -> void:
	var aim := aim_dir()
	_ray_angle = atan2(-aim.x, -aim.z) + PI * 0.5  # across the player, not straight at them
	_ray_angle_now = _ray_angle
	_ray_sign = 1.0 if cycle_count % 2 == 0 else -1.0
	_ray_t = 0.0
	model.boss_pose("ray", 1.1 + RAY_ACTIVE)
	pulse_glow(2.4, 1.1)
	for side in [0.0, PI]:
		var axis := func() -> Array:
			var dir := Vector3.FORWARD.rotated(Vector3.UP, _ray_angle_now + side)
			return [global_position + dir * (def.hit_radius * def.model_scale), dir]
		hazards.ray(axis, RAY_LENGTH, 0.7, 1.1, RAY_ACTIVE, Vector2i(70, 85), 0.75, Color(1.0, 0.9, 0.5), {group = "solar_rays"})


func _gold_fan() -> void:
	pulse_glow(1.3, 0.5)
	after(0.5, func() -> void:
		fire_fan(shot_origin(), aim_dir(), 5, 12.0, Boss.shot("needle", GOLD, Vector2i(60, 75), 8.5, 0.13, 20.0)))


func _sand_spears() -> void:
	var at := target().global_position
	for offset: Vector3 in [Vector3.ZERO, Vector3(1.6, 0, 1.2), Vector3(-1.8, 0, 0.6)]:
		hazards.circle(in_arena(at + offset, 22.0), 0.8, 1.2, Vector2i(75, 90), Color(0.95, 0.75, 0.4))


# --- Phase 3 ------------------------------------------------------------------------------

func _charge_lane(second: bool) -> void:
	if _exposed > 0.0:
		_exposed = 0.0
		defense = 15
		status_text = ""
	var dir := aim_dir()
	if second and _last_charge != Vector3.ZERO and dir.angle_to(_last_charge) < deg_to_rad(25.0):
		dir = dir.rotated(Vector3.UP, deg_to_rad(30.0))  # a different line than the last one
	var end := in_arena(global_position + dir * 22.0, 22.0)
	var length := Vector2(end.x - global_position.x, end.z - global_position.z).length()
	if length > 0.01: dir = (end - global_position).normalized()
	dir.y = 0.0
	dir = dir.normalized()
	_last_charge = dir
	face_override = dir
	model.boss_pose("charge_windup", 1.0)
	hazards.lane(global_position + dir * length * 0.5, dir, maxf(2.0, length), 3.0, 1.0, 0.0, Vector2i.ZERO, 0.0, PINK)
	after(1.0, func() -> void:
		model.boss_pose("charge", length / 13.0 + 0.2)
		start_charge(dir, length, 13.0, Vector2i(135, 155), _expose))


## Plants its legs and opens the shell: the damage window.
func _expose() -> void:
	behavior = "stationary"
	_exposed = 2.5
	defense = 6
	status_text = "Its heart is exposed!"
	model.boss_pose("expose", 2.5)
	pulse_glow(1.5, 2.5)


func _ring() -> void:
	var gap := randf() * PI
	mark_ring_gaps(gap, 60.0, 0.9, Color(1.0, 0.95, 0.7))
	after(0.9, func() -> void:
		fire_ring(shot_origin(), 22, Boss.shot("needle", GOLD, Vector2i(65, 80), 6.5, 0.14, 22.0), gap, 60.0))


func _comets() -> void:
	var at := target().global_position
	var offsets := [Vector3(0, 0, 0), Vector3(2.6, 0, 1.0), Vector3(-2.2, 0, 2.0), Vector3(0.6, 0, -2.8)]
	for k in 4:
		var spot: Vector3 = in_arena(at + offsets[k], 22.0)
		after(k * 0.5, func() -> void:
			hazards.circle(spot, 1.1, 1.2, Vector2i(80, 95), PINK))


func _reset_hook() -> void:
	_ray_t = -1.0
	_exposed = 0.0
	_resting = false
	_summoning = false
	_returning = false
	model.boss_pose("idle", 0.1)


func _death_started() -> void:
	_ray_t = -1.0
	model.boss_pose("defeated", boss_def.death_time + 1.0)


func _dying_update(_k: float) -> void:
	# Hold the collapsed silhouette steady until the final voxel burst.
	model.scale = Vector3.ONE * def.model_scale
