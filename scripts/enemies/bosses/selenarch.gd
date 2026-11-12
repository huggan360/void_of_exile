extends Boss
## Selenarch, the Moon-Eater, in the Shattered Observatory on Hollowmoon. A
## floating astronomer-lich with an orrery of little moons: it fights with
## orbits, curving ghost-lights and beams of cold moonlight.
##
## 1 (100-65%)  orreries (two rings of moons orbiting it, opposite ways),
##    ghost-light fans that curve in from both sides, crescent bursts.
## 2 (65-30%)   "eclipse": moonbeams sweep the floor, ghost rings with gaps,
##    and it blinks across the observatory.
## 3 (30-0%)    "void": twice the beams, turning faster, falling stars that
##    burst into rings, and its ghosts come to help.
const MOON := Color("c8ffd0")
const GHOST := Color("7dff6a")
var _turn := 0.0
var _beam_angle := 0.0
var _beam_speed := 0.0

func _phase_started(index: int) -> void:
	behavior = "stationary"
	_beam_speed = 0.0
	match index:
		0: set_cycle(12.0, [[0.6, _orrery], [3.5, _wisps], [6.5, _crescents], [8.5, _orrery], [10.5, _wisps]])
		1: set_cycle(14.0, [[0.6, _beams.bind(3, 0.45)], [2.0, _ghost_ring], [5.5, _blink], [7.0, _orrery], [10.0, _wisps], [12.0, _crescents]])
		2:
			_ghosts(3)
			set_cycle(14.0, [[0.6, _beams.bind(6, 0.6)], [2.5, _stars], [5.5, _blink], [6.5, _ghost_ring], [9.0, _orrery], [11.5, _stars]])

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	_beam_angle += _beam_speed*delta

func _threshold_reached(next: int) -> void:
	if resting: return
	begin_rest(func() -> void: _enter_phase(next),
		"The moon behind Selenarch goes dark" if next==1 else "Its ribs open on a green star", "kneel")

func _moon(speed := 5.5) -> Dictionary:
	return PlanetBosses.shot("moon_shard", "crescent", MOON, Vector2i(105, 136), speed, 22.0, 1.0)

func _wisp(speed := 5.0) -> Dictionary:
	return PlanetBosses.shot("ghost_wisp", "orb", GHOST, Vector2i(77, 102), speed, 24.0, 1.1)

## Two rings of moons orbit it, one each way, then fly loose.
func _orrery() -> void:
	model.boss_pose("channel", 2.0)
	pulse_glow(1.4, 0.8)
	_turn += 0.4
	after(0.6, func() -> void:
		fire_orbit(global_position, 5.0, 10, 6.0, 1.25, 1.0, _moon(), _turn)
		fire_orbit(global_position, 9.0, 14, 6.5, 0.9, -1.0, _moon(), -_turn))

## Ghost-lights curve in from both sides toward someone.
func _wisps() -> void:
	model.play_attack(0.6)
	var base := aim_dir()
	for side: float in [-1.0, 1.0]:
		for k in 6:
			after(0.5+k*0.12, func() -> void:
				var attack := _wisp(6.0)
				attack.turn = -side*0.55
				shoot(shot_origin(), base.rotated(Vector3.UP, side*deg_to_rad(40.0+k*6.0)), attack))

## Bursts of crescents, aimed, five at a time.
func _crescents() -> void:
	for wave in 4:
		after(0.4+wave*0.3, func() -> void: fire_fan(shot_origin(1.0), aim_dir(), 5, 12.0, _moon(8.0+wave*0.5)))

## Moonbeams out of the halo, sweeping round the floor.
func _beams(count: int, speed: float) -> void:
	model.boss_pose("cast", 1.4)
	_beam_speed = speed*(1.0 if randf()<0.5 else -1.0)
	for k in count:
		var offset := TAU*k/count
		var axis := func() -> Array:
			var dir := Vector3.FORWARD.rotated(Vector3.UP, _beam_angle+offset)
			return [global_position+dir*2.0, dir]
		hazards.ray(axis, 28.0, 1.0, 1.2, 4.5, Vector2i(139, 176), 0.6, MOON, {group = "moonbeams"})
	after(5.8, func() -> void: _beam_speed = 0.0)

## A ring of ghosts with two gaps, then another turned a little.
func _ghost_ring() -> void:
	var gap := atan2(-aim_dir().x, -aim_dir().z)
	mark_ring_gaps(gap, 46.0, 1.0, GHOST)
	after(1.0, func() -> void: fire_ring(shot_origin(), 30, _wisp(5.0), gap, 46.0))
	after(1.6, func() -> void: fire_ring(shot_origin(), 30, _wisp(4.4), gap+0.25, 46.0))

## It fades and comes back somewhere else in the observatory.
func _blink() -> void:
	var a := randf()*TAU
	var to := in_arena(encounter_center+Vector3(cos(a), 0, sin(a))*randf_range(6.0, 16.0), 18.0)
	hazards.marker(to, 2.5, 1.0, GHOST)
	pulse_glow(2.0, 1.0)
	after(1.0, func() -> void:
		global_position = to
		fire_ring(shot_origin(), 16, _moon(5.0)))

## Stars fall on everyone and burst into rings of moon shards.
func _stars() -> void:
	model.boss_pose("summon", 1.4)
	var star := PlanetBosses.shot("ghost_wisp", "comet", GHOST, Vector2i(88, 112), 3.5, 7.0, 1.8,
		{terminal = {delay = 0.35, count = 12, attack = _moon(5.0)}})
	after(0.7, func() -> void: fire_fan(shot_origin(), aim_dir(), 7, 360.0/7.0, star))
	for p in players():
		hazards.circle(in_arena(p.global_position, 27.0), 2.6, 1.2, Vector2i(139, 176), GHOST)

func _ghosts(count: int) -> void:
	for i in count:
		var a := TAU*i/count
		var helper := spawn_support("lantern_ghost_thrall", encounter_center+Vector3(cos(a), 0, sin(a))*14.0, "ghosts", true)
		if helper: arm_summon(helper, 0.3*i)

func _reset_hook() -> void:
	_turn = 0.0
	_beam_speed = 0.0
	resting = false

func _death_started() -> void:
	_beam_speed = 0.0
	despawn_support("ghosts")
