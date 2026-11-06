extends Boss
## The Blue Dragon of Bluelay. Its phase data (Enemies._build_blue_dragon)
## still brings the dragonlings, shields, big fire bursts, wing beats and the
## sweeping breath; this script adds its radial patterns, rests and poses.
##
## 1 (100-70%)  while the five dragonlings live: tide gates (rings of blue
##    flame with four turning gaps) and forward wing gusts. Then star breath
##    (five lines of fire at rising speeds) alongside the big bursts.
## 2 (70-30%)  while the four blue dragonlings circle: comet wheels (three
##    rings of heavy fire stepping round). Then twin breaths closing in from
##    both sides and a two-size nova while it strafes.
## 3 (30-0%)  enraged: layered tempest novas (three rings at three speeds),
##    meteor rain across the arena and a full-circle spiral breath, between
##    the wing beats and the sweep.
## Phase changes are a three-second rest (Boss.begin_rest).

const AZURE := Color(0.35, 0.65, 1.0)
const PALE := Color(0.55, 0.85, 1.0)
const WARN := Color(0.45, 0.8, 1.0)

var _gate_angle := 0.0
var _star_angle := 0.0
var _wheel_angle := 0.0
var _timer_a := 0.0
var _timer_b := 0.0


func _phase_started(index: int) -> void:
	status_text = ""
	model.boss_pose("summon", 1.8)
	var guards := support("guard")
	for i in guards.size():
		arm_summon(guards[i], 0.1 * i)
	_timer_a = 2.0
	_timer_b = 3.5
	if index == 2:
		set_cycle(9.0, [[1.0, _tempest_nova], [4.0, _meteor_rain], [6.2, _spiral_breath]])


func _threshold_reached(next: int) -> void:
	if resting: return
	begin_rest(func() -> void: _enter_phase(next), "The Dragon gathers its fury", "kneel")


func _combat(delta: float) -> void:
	if resting: return
	_timer_a -= delta
	_timer_b -= delta
	match phase:
		0:
			if shielded:
				if _timer_a <= 0.0:
					_timer_a = 2.4
					_tide_gates()
				if _timer_b <= 0.0:
					_timer_b = 4.8
					_wing_gust()
			elif _timer_a <= 0.0:
				_timer_a = 4.0
				_star_breath()
		1:
			if shielded:
				if _timer_a <= 0.0:
					_timer_a = 3.2
					_comet_wheel()
			else:
				if _timer_a <= 0.0:
					_timer_a = 5.0
					_twin_breath()
				if _timer_b <= 0.0:
					_timer_b = 6.0
					_nova()


static func _flame(size: float, speed: float, damage: Vector2i, color := AZURE) -> Dictionary:
	return Boss.shot("fireball", color, damage, speed, 0.18 * size, 24.0, {size = size})


# --- Phase 1 ------------------------------------------------------------------------------

## A ring of 24 flames with four gaps, turned 20 degrees each time.
func _tide_gates() -> void:
	model.flap()
	pulse_glow(1.6, 0.5)
	_gate_angle += deg_to_rad(20.0)
	var gate := _gate_angle
	after(0.45, func() -> void:
		for k in 24:
			var a := k * TAU / 24.0
			if absf(angle_difference(fposmod(a - gate, PI * 0.5), 0.0)) < deg_to_rad(16.0):
				continue
			shoot(shot_origin(), Vector3.FORWARD.rotated(Vector3.UP, a), _flame(0.9, 6.0, Vector2i(40, 50))))


## A forward wing beat that throws a wide fan of flame.
func _wing_gust() -> void:
	model.flap()
	pulse_glow(1.8, 0.4)
	after(0.4, func() -> void:
		fire_fan(shot_origin(), aim_dir(), 7, 12.0, _flame(1.3, 9.0, Vector2i(50, 60), PALE)))


## Five lines of fire, each four flames at rising speeds; the star turns.
func _star_breath() -> void:
	model.boss_pose("breath", 1.2)
	pulse_glow(2.0, 0.75)
	_star_angle += deg_to_rad(36.0) * 0.5
	var aim := aim_dir()
	var start := atan2(-aim.x, -aim.z) + _star_angle
	after(0.75, func() -> void:
		for k in 5:
			var dir := Vector3.FORWARD.rotated(Vector3.UP, start + k * TAU / 5.0)
			for speed in [5.0, 6.5, 8.0, 9.5]:
				shoot(shot_origin(), dir, _flame(1.2, speed, Vector2i(60, 70))))


# --- Phase 2 ------------------------------------------------------------------------------

## Three rings of ten heavy flames, each stepped 12 degrees: a turning wheel.
func _comet_wheel() -> void:
	model.flap()
	pulse_glow(1.8, 0.5)
	_wheel_angle += deg_to_rad(18.0)
	var start := _wheel_angle
	for ring in 3:
		after(0.5 + ring * 0.3, func() -> void:
			for k in 10:
				var comet := _flame(1.8, 4.5, Vector2i(60, 75))
				comet.effects = [{id = "defense", amount = -8, duration = 2.0}]
				comet.effect_source = "Blue Dragon heavy comet"
				shoot(shot_origin(), Vector3.FORWARD.rotated(Vector3.UP, start + k * TAU / 10.0 + ring * deg_to_rad(12.0)),
						comet))


## Two breaths start 60 degrees to either side and close in on the target.
func _twin_breath() -> void:
	model.boss_pose("breath", 1.4)
	pulse_glow(2.0, 0.75)
	var aim := aim_dir()
	for k in 10:
		after(0.75 + k * 0.05, func() -> void:
			var step := deg_to_rad(60.0) * (1.0 - k / 9.0)
			for side in [-1.0, 1.0]:
				shoot(shot_origin(), aim.rotated(Vector3.UP, step * side), _flame(1.4, 9.0, Vector2i(55, 65), PALE)))


## A full ring alternating big slow flames and small fast ones.
func _nova() -> void:
	model.flap()
	pulse_glow(2.2, 0.5)
	var offset := randf() * TAU
	after(0.5, func() -> void:
		for k in 32:
			var big := k % 2 == 0
			shoot(shot_origin(), Vector3.FORWARD.rotated(Vector3.UP, offset + k * TAU / 32.0),
					_flame(1.7 if big else 0.9, 4.5 if big else 7.5, Vector2i(55, 70))))


# --- Phase 3 ------------------------------------------------------------------------------

## Three rings of eighteen at three speeds, each a third of a step turned.
func _tempest_nova() -> void:
	model.flap()
	pulse_glow(2.4, 0.5)
	var offset := randf() * TAU
	after(0.5, func() -> void:
		for ring in 3:
			for k in 18:
				shoot(shot_origin(), Vector3.FORWARD.rotated(Vector3.UP, offset + (k + ring / 3.0) * TAU / 18.0),
						_flame(1.3, 8.0 - ring * 2.0, Vector2i(60, 70), PALE if ring == 1 else AZURE)))


## Blue meteors fall across the arena, one on the target.
func _meteor_rain() -> void:
	model.boss_pose("roar", 1.6)
	pulse_glow(2.0, 1.0)
	var spots: Array[Vector3] = [target().global_position]
	for k in 7:
		var a := randf() * TAU
		spots.append(encounter_center + Vector3(cos(a), 0, sin(a)) * randf_range(4.0, 20.0))
	for k in spots.size():
		var spot := in_arena(spots[k], 22.0)
		after(k * 0.22, func() -> void:
			hazards.circle(spot, 1.6, 1.2, Vector2i(80, 95), WARN))


## A breath that turns a full circle, starting at the target.
func _spiral_breath() -> void:
	model.boss_pose("sweep", 3.0)
	pulse_glow(2.2, 0.6)
	var aim := aim_dir()
	var sense := 1.0 if randf() < 0.5 else -1.0
	for k in 48:
		after(0.6 + k * 0.05, func() -> void:
			shoot(shot_origin(), aim.rotated(Vector3.UP, sense * TAU * k / 48.0), _flame(1.4, 7.0, Vector2i(55, 65))))


func _reset_hook() -> void:
	resting = false
	model.boss_pose("idle", 0.1)


func _death_started() -> void:
	model.boss_pose("defeated", boss_def.death_time + 1.0)


func _dying_update(_k: float) -> void:
	model.scale = Vector3.ONE * def.model_scale
