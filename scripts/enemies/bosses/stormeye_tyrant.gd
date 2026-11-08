extends Boss
## The Stormeye Tyrant, in the Stormeye Citadel on The Pale Eye: the last and
## worst of the Reach's bosses. A floating storm-eye that fills the citadel
## with lightning and orbs; every phase is denser than the one before.
##
## 1 (100-65%)  eye lances (fast aimed bursts), storm rings with gaps,
##    lightning that strikes along lanes toward everyone.
## 2 (65-30%)   "tempest": three storm rays turn round it, six-armed orb
##    spirals, lightning circles, its storm shards come.
## 3 (30-0%)    "cataclysm": four faster rays, the storm (rings and
##    spirals at once for five seconds), lances that split.
const STORM := Color("9ab0ff")
const RED := Color("ff4a5a")
var _turn := 0.0
var _ray_angle := 0.0
var _ray_speed := 0.0

func _phase_started(index: int) -> void:
	behavior = "stationary"
	_ray_speed = 0.0
	match index:
		0: set_cycle(11.0, [[0.5, _lances], [2.5, _storm_ring], [5.0, _lightning], [7.0, _lances], [8.8, _storm_ring]])
		1:
			_shards(4)
			set_cycle(13.0, [[0.5, _rays.bind(3, 0.5)], [1.5, _spiral.bind(6)], [5.5, _lances], [7.0, _lightning_circles], [9.0, _storm_ring], [11.0, _lances]])
		2: set_cycle(14.0, [[0.5, _rays.bind(4, 0.75)], [1.5, _storm], [7.5, _split_lances], [9.0, _lightning_circles], [10.5, _storm_ring], [12.5, _lightning]])

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	_ray_angle += _ray_speed*delta

func _threshold_reached(next: int) -> void:
	if resting: return
	begin_rest(func() -> void: _enter_phase(next),
		"The storm around the Eye tightens" if next==1 else "The Eye cracks open: the cataclysm", "kneel")

func _orb(speed := 5.5) -> Dictionary:
	return PlanetBosses.shot("storm_orb", "orb", STORM, Vector2i(56, 72), speed, 24.0, 1.0)

func _lance(speed := 11.0) -> Dictionary:
	return PlanetBosses.shot("eye_lance", "bolt", RED, Vector2i(66, 84), speed, 26.0, 1.1)

## Bursts of eye lances: quick, aimed, re-aimed each burst.
func _lances() -> void:
	pulse_glow(1.6, 0.5)
	for wave in (4 if phase<2 else 6):
		after(0.5+wave*0.22, func() -> void: fire_fan(shot_origin(1.5), aim_dir(), 3 if phase==0 else 5, 7.0, _lance()))

## Two rings of storm orbs, each with a pair of gaps.
func _storm_ring() -> void:
	var gap := atan2(-aim_dir().x, -aim_dir().z)+randf_range(-0.6, 0.6)
	mark_ring_gaps(gap, 40.0, 0.9, STORM)
	after(0.9, func() -> void: fire_ring(shot_origin(), 36, _orb(5.5), gap, 40.0))
	after(1.4, func() -> void: fire_ring(shot_origin(), 36, _orb(4.8), gap+0.18, 40.0))

## Lightning strikes along lanes from the Eye toward everyone.
func _lightning() -> void:
	for p in players():
		var dir: Vector3 = p.global_position-global_position
		dir.y = 0.0
		dir = dir.normalized()
		hazards.lane(global_position+dir*15.0, dir, 30.0, 1.6, 0.9, 0.35, Vector2i(70, 88), 0.35, STORM)
		for side: float in [-1.0, 1.0]:
			var d := dir.rotated(Vector3.UP, side*0.5)
			hazards.lane(global_position+d*15.0, d, 30.0, 1.4, 1.1, 0.35, Vector2i(70, 88), 0.35, STORM)

## Storm rays out of the Eye, turning.
func _rays(count: int, speed: float) -> void:
	model.boss_pose("cast", 1.2)
	_ray_speed = speed*(1.0 if randf()<0.5 else -1.0)
	for k in count:
		var offset := TAU*k/count
		var axis := func() -> Array:
			var dir := Vector3.FORWARD.rotated(Vector3.UP, _ray_angle+offset)
			return [global_position+dir*2.5, dir]
		hazards.ray(axis, 30.0, 1.1, 1.1, 5.0, Vector2i(66, 84), 0.55, STORM, {group = "storm_rays"})
	after(6.2, func() -> void: _ray_speed = 0.0)

func _spiral(arms: int) -> void:
	model.boss_pose("channel", 3.4)
	_turn += 0.55
	var start := _turn
	for beat in 22:
		after(0.4+beat*0.14, func() -> void:
			for arm in arms:
				shoot(shot_origin(), Vector3.FORWARD.rotated(Vector3.UP, start+beat*0.17+arm*TAU/arms), _orb(5.8)))

## The storm: spirals both ways and a ring every second, for five seconds.
func _storm() -> void:
	model.boss_pose("channel", 5.5)
	pulse_glow(2.0, 5.0)
	_spiral(4)
	var start := -_turn
	for beat in 30:
		after(0.4+beat*0.16, func() -> void:
			for arm in 4:
				var attack := _orb(5.2)
				attack.turn = -0.12
				shoot(shot_origin(), Vector3.FORWARD.rotated(Vector3.UP, start-beat*0.15+arm*TAU/4.0), attack))
	for k in 5:
		after(0.8+k*1.0, func() -> void: fire_ring(shot_origin(), 24, _lance(6.0), randf()*TAU, 0.0))

## Lances that stop short and split into rings of orbs.
func _split_lances() -> void:
	var lance := _lance(9.0)
	lance.range = 10.0
	lance.terminal = {delay = 0.3, count = 10, attack = _orb(5.0)}
	for wave in 3:
		after(0.4+wave*0.35, func() -> void: fire_fan(shot_origin(1.5), aim_dir(), 5, 24.0, lance))

## Lightning circles under everyone and around the citadel floor.
func _lightning_circles() -> void:
	for p in players(): hazards.circle(in_arena(p.global_position, 27.0), 2.6, 0.9, Vector2i(66, 84), STORM)
	for k in 8:
		var a := TAU*k/8.0+randf()*0.4
		hazards.circle(in_arena(encounter_center+Vector3(cos(a), 0, sin(a))*randf_range(8.0, 25.0), 27.0), 2.6, 1.2, Vector2i(66, 84), RED)

func _shards(count: int) -> void:
	model.boss_pose("summon", 1.8)
	for i in count:
		var a := TAU*i/count+PI/count
		var helper := spawn_support("storm_shard_thrall", encounter_center+Vector3(cos(a), 0, sin(a))*16.0, "shards", true)
		if helper: arm_summon(helper, 0.2*i)
	var watcher := spawn_support("eye_watcher_thrall", encounter_center+Vector3(0, 0, 18.0), "shards", true)
	if watcher: arm_summon(watcher, 0.9)

func _reset_hook() -> void:
	_turn = 0.0
	_ray_speed = 0.0
	resting = false

func _death_started() -> void:
	_ray_speed = 0.0
	despawn_support("shards")
