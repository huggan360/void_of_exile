extends Boss
## Queen Briarrose, the Rose Bastion on Rosamund. A fairy queen of petals and
## thorns: she never walks, she floats and fills the bastion with petals.
##
## 1 (100-65%)  petal spirals (four arms, slowly turning), thorn volleys (three
##    staggered fans), rose blooms (buds that burst into rings of petals).
## 2 (65-30%)   "bloom": her sprites come, the spirals turn both ways at once,
##    thorn lanes cross the arena, the blooms grow.
## 3 (30-0%)    "wilted": walls of petals with gaps, a whirling petal storm and
##    thorns that erupt under everyone.
const PINK := Color("ff6eb4")
const ROSE := Color("ff9ccf")
const THORN := Color("7dffb0")
var _turn := 0.0

func _phase_started(index: int) -> void:
	behavior = "stationary"
	match index:
		0: set_cycle(12.0, [[0.5, _spiral.bind(4, 1.0)], [4.0, _thorns], [6.5, _blooms.bind(5)], [9.5, _thorns]])
		1:
			_sprites(4)
			set_cycle(13.0, [[0.8, _twin_spiral], [4.5, _thorn_lanes], [6.5, _blooms.bind(7)], [9.5, _thorns], [11.0, _sprites.bind(2)]])
		2: set_cycle(12.0, [[0.6, _petal_wall], [3.0, _storm], [7.0, _eruptions], [8.5, _petal_wall], [10.5, _thorns]])

func _threshold_reached(next: int) -> void:
	if resting: return
	begin_rest(func() -> void: _enter_phase(next),
		"The Queen's petals open wide" if next==1 else "The roses wilt... and the thorns wake", "kneel")

func _petal(speed := 5.5) -> Dictionary:
	return PlanetBosses.shot("rose_petal", "disc", ROSE, Vector2i(35, 48), speed, 22.0, 1.0)

func _thorn(speed := 8.0) -> Dictionary:
	return PlanetBosses.shot("thorn_spike", "needle", THORN, Vector2i(51, 68), speed, 20.0, 1.0)

## Arms of petals spiralling out of her gown.
func _spiral(arms: int, sense: float) -> void:
	model.boss_pose("channel", 3.2)
	pulse_glow(1.2, 0.6)
	_turn += 0.6
	var start := _turn
	for beat in 16:
		after(0.4+beat*0.18, func() -> void:
			for arm in arms:
				var attack := _petal(5.0)
				attack.turn = 0.08*sense
				shoot(shot_origin(), Vector3.FORWARD.rotated(Vector3.UP, start+sense*beat*0.17+arm*TAU/arms), attack))

func _twin_spiral() -> void:
	_spiral(3, 1.0)
	after(0.09, func() -> void: _spiral(3, -1.0))

## Three fans of thorns, each a little offset, aimed at someone.
func _thorns() -> void:
	model.play_attack(0.6)
	var base := aim_dir()
	for wave in 3:
		after(0.5+wave*0.28, func() -> void:
			fire_fan(shot_origin(1.0), base.rotated(Vector3.UP, deg_to_rad(6.0*(wave-1))), 7, 11.0, _thorn(8.5+wave)))

## Rose buds drift out and burst into rings of petals.
func _blooms(count: int) -> void:
	model.boss_pose("cast", 1.2)
	var bud := PlanetBosses.shot("rose_petal", "orb", PINK, Vector2i(43, 56), 4.0, 9.0, 1.6,
		{terminal = {delay = 0.4, count = 10 if phase<2 else 12, attack = _petal(4.5)}})
	after(0.8, func() -> void: fire_fan(shot_origin(), aim_dir(), count, 360.0/count, bud))

## Thorn lanes cross the arena through her, three times, turning.
func _thorn_lanes() -> void:
	var a := randf()*PI
	for k in 3:
		after(k*0.9, func() -> void:
			var dir := Vector3.FORWARD.rotated(Vector3.UP, a+k*PI/3.0)
			hazards.lane(encounter_center, dir, 56.0, 2.4, 1.1, 0.5, Vector2i(70, 93), 0.5, THORN))

## Rings of petals, each with a gap you have to find.
func _petal_wall() -> void:
	model.boss_pose("slam_windup", 1.0)
	var gap := atan2(-aim_dir().x, -aim_dir().z)+randf_range(-0.8, 0.8)
	mark_ring_gaps(gap, 40.0, 1.0, PINK)
	for k in 3:
		after(1.0+k*0.45, func() -> void: fire_ring(shot_origin(), 36, _petal(5.5), gap+k*0.12, 40.0))

## A whirling stream of petals for three seconds.
func _storm() -> void:
	model.boss_pose("channel", 3.6)
	pulse_glow(1.6, 3.0)
	var start := randf()*TAU
	for beat in 26:
		after(0.4+beat*0.12, func() -> void:
			for arm in 6:
				shoot(shot_origin(), Vector3.FORWARD.rotated(Vector3.UP, start+beat*0.21+arm*TAU/6.0), _petal(6.0)))

## Thorns burst out of the ground under everyone, then around her.
func _eruptions() -> void:
	for p in players():
		hazards.circle(in_arena(p.global_position, 27.0), 2.4, 1.0, Vector2i(88, 112), THORN)
	for k in 6:
		var a := TAU*k/6.0+randf()*0.5
		hazards.circle(in_arena(encounter_center+Vector3(cos(a), 0, sin(a))*randf_range(8.0, 22.0), 27.0), 2.4, 1.3, Vector2i(88, 112), THORN)

func _sprites(count: int) -> void:
	model.boss_pose("summon", 1.8)
	if support("sprites").size()>=6: return
	for i in count:
		var a := TAU*i/count+randf()
		var helper := spawn_support("petal_sprite_thrall", encounter_center+Vector3(cos(a), 0, sin(a))*12.0, "sprites", true)
		if helper: arm_summon(helper, 0.2*i)

func _reset_hook() -> void:
	_turn = 0.0
	resting = false

func _death_started() -> void:
	despawn_support("sprites")
