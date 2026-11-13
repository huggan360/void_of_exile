extends Boss
## The Veiled Herald, mission 6's mini boss on Shardheart: the voice that
## carried the Pale One's whisper to the King. It floats over the crystal
## shrine and fights with runes, needles of veil light and pale tears.
##
## 1 (100-65%)  rune rings with a gap, aimed needle fans, tears falling on
##    everyone (circles that burst into needles).
## 2 (65-30%)   "unveiled": the veil tears away; runes orbit it both ways,
##    needle spirals, it slips across the shrine, two of the Eye's watchers come.
## 3 (30-0%)    "shattered": tears split into rings of needles, double
##    rune rings and crossing lanes of light.
const PALE := Color("e8f2ff")
const VEIL := Color("96beff")
const RED := Color("ff4a5a")
var _turn := 0.0

func _phase_started(index: int) -> void:
	behavior = "stationary" if index==0 else "skirmish"
	move_speed = 2.0+index*0.5
	match index:
		0:
			status_text = "The Herald speaks for something older"
			set_cycle(9.0, [[0.5, _rune_ring], [2.4, _needles], [4.2, _tears], [6.4, _needles], [7.6, _rune_ring]])
		1:
			status_text = "Unveiled - runes in orbit"
			_watchers()
			set_cycle(11.0, [[0.5, _orbit], [2.0, _spiral.bind(5)], [5.5, _needles], [7.0, _tears], [8.6, _rune_ring]])
		2:
			status_text = "Shattered - its tears split"
			set_cycle(11.0, [[0.5, _split_tears], [2.2, _rune_ring.bind(true)], [4.0, _crossing], [6.0, _spiral.bind(7)], [9.0, _needles]])

func _threshold_reached(next: int) -> void:
	if resting: return
	begin_rest(func() -> void: _enter_phase(next),
		"The veil tears away" if next==1 else "The Herald shatters into light", "kneel")

func _rune(speed := 5.0) -> Dictionary:
	return PlanetBosses.shot("herald_rune", "orb", VEIL, Vector2i(70, 92), speed, 24.0, 1.0)

func _needle(speed := 10.5) -> Dictionary:
	return PlanetBosses.shot("veil_needle", "bolt", PALE, Vector2i(88, 118), speed, 24.0, 1.0)

func _tear(speed := 7.0) -> Dictionary:
	return PlanetBosses.shot("pale_tear", "orb", RED if phase==2 else VEIL, Vector2i(96, 128), speed, 22.0, 1.2)

## A ring of runes with one gap, and with `twice` a second ring a beat later.
func _rune_ring(twice := false) -> void:
	var gap := atan2(-aim_dir().x, -aim_dir().z)+randf_range(-0.5, 0.5)
	mark_ring_gaps(gap, 42.0, 0.8, VEIL)
	after(0.8, func() -> void: fire_ring(shot_origin(), 30, _rune(5.2), gap, 42.0))
	if twice: after(1.5, func() -> void: fire_ring(shot_origin(), 30, _rune(4.4), gap+0.35, 42.0))

## Aimed fans of needles, re-aimed each wave.
func _needles() -> void:
	model.boss_pose("cast", 1.0)
	for wave in (3 if phase==0 else 4):
		after(0.35+wave*0.3, func() -> void: fire_fan(shot_origin(1.2), aim_dir(), 3 if phase==0 else 5, 9.0, _needle()))

## Pale tears fall where everyone stands; each lands as a small burst.
func _tears() -> void:
	pulse_glow(1.4, 0.8)
	for p in players():
		var at := in_arena(p.global_position, 26.0)
		hazards.circle(at, 2.4, 1.1, Vector2i(120, 150), VEIL)
		after(1.1, func() -> void:
			var spot := at
			spot.y = shot_origin().y
			fire_ring(spot, 6, _needle(7.0), randf()*TAU, 0.0))

## Two orbits of runes round the Herald, turning opposite ways.
func _orbit() -> void:
	model.boss_pose("channel", 2.2)
	fire_orbit(global_position, 6.0, 6, 5.0, 1.4, 1.0, _rune())
	fire_orbit(global_position, 10.0, 8, 5.5, 1.1, -1.0, _rune(), 0.3)

func _spiral(arms: int) -> void:
	model.boss_pose("channel", 3.0)
	_turn += 0.6
	var start := _turn
	for beat in 18:
		after(0.4+beat*0.15, func() -> void:
			for arm in arms:
				shoot(shot_origin(), Vector3.FORWARD.rotated(Vector3.UP, start+beat*0.19+arm*TAU/arms), _needle(7.5)))

## Tears that stop short and break into rings of needles.
func _split_tears() -> void:
	var tear := _tear(8.0)
	tear.range = 9.0
	tear.terminal = {delay = 0.25, count = 9, attack = _needle(6.5)}
	for wave in 3:
		after(0.3+wave*0.4, func() -> void: fire_fan(shot_origin(1.2), aim_dir(), 3, 30.0, tear))

## Lanes of light crossing the shrine through everyone.
func _crossing() -> void:
	for p in players():
		var at: Vector3 = p.global_position
		for angle: float in [0.0, PI*0.5]:
			var dir := Vector3.FORWARD.rotated(Vector3.UP, angle+randf()*0.4)
			hazards.lane(at, dir, 26.0, 1.5, 1.0, 0.35, Vector2i(130, 165), 0.35, PALE)

func _watchers() -> void:
	model.boss_pose("summon", 1.6)
	for i in 2:
		var helper := spawn_support("eye_watcher_thrall", encounter_center+Vector3(-10.0+20.0*i, 0, 8.0), "watchers", true)
		if helper: arm_summon(helper, 0.4*i)

func _reset_hook() -> void:
	_turn = 0.0
	resting = false

func _death_started() -> void:
	despawn_support("watchers")
