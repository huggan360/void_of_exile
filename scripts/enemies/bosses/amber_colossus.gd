extends Boss
## Aurum, the Amber Colossus, in the Amber Ziggurat on Amberfall. A sandstone
## sphinx-beetle that slams, charges and drowns the ziggurat in honey.
##
## 1 (100-65%)  amber volleys (three wide fans), slams (a ring of honey and a
##    shockwave around it), honey rain (pools that spit honey when they land).
## 2 (65-30%)   "molten": sand walls (a line of shards across the arena with
##    one gap), charges that end in a burst, faster volleys.
## 3 (30-0%)    "hive": the shell splits, mites pour out, amber boomerangs and
##    a honey spiral join the walls.
const AMBER := Color("ffb84a")
const HONEY := Color("ffd27a")
var _turn := 0.0

func _phase_started(index: int) -> void:
	behavior = "stationary"
	charge_arena_radius = 25.0
	match index:
		0: set_cycle(12.0, [[0.6, _volley], [3.5, _slam], [6.5, _honey_rain], [9.5, _volley]])
		1: set_cycle(13.0, [[0.6, _sand_wall], [3.0, _rush], [7.0, _volley], [9.0, _sand_wall], [11.0, _slam]])
		2:
			_mites(5)
			set_cycle(13.0, [[0.6, _boomerangs], [2.8, _sand_wall], [5.0, _spiral], [8.5, _rush], [11.5, _honey_rain]])

func _threshold_reached(next: int) -> void:
	if resting: return
	begin_rest(func() -> void: _enter_phase(next),
		"Molten honey cracks through the Colossus" if next==1 else "The shell splits: the hive inside wakes", "kneel")

func _shard(speed := 7.5) -> Dictionary:
	return PlanetBosses.shot("amber_shard", "shard", AMBER, Vector2i(42, 56), speed, 24.0, 1.1)

func _honey(speed := 5.0) -> Dictionary:
	return PlanetBosses.shot("honey_orb", "orb", HONEY, Vector2i(38, 50), speed, 20.0, 1.2)

func _volley() -> void:
	model.boss_pose("cast", 1.0)
	var base := aim_dir()
	for wave in 3:
		after(0.6+wave*0.3, func() -> void:
			fire_fan(shot_origin(1.5), base.rotated(Vector3.UP, deg_to_rad(4.0*(wave-1))), 9 if phase==0 else 11, 9.0, _shard(7.5+wave*0.8)))

## Fists down: a shockwave around it and a ring of honey.
func _slam() -> void:
	model.boss_pose("slam_windup", 1.1)
	hazards.circle(global_position, 7.0, 1.1, Vector2i(55, 70), AMBER)
	after(1.1, func() -> void:
		model.boss_pose("slam_release", 0.5)
		model.strike()
		CameraShake.shake_from(self, global_position, 0.5, 30.0)
		fire_ring(shot_origin(), 28, _honey(5.5))
		after(0.35, func() -> void: fire_ring(shot_origin(), 28, _honey(4.5), 0.0, 0.0)))

## Honey falls on everyone and around; each pool spits a little ring.
func _honey_rain() -> void:
	var marks: Array[Vector3] = []
	for p in players(): marks.append(in_arena(p.global_position, 27.0))
	for i in 4+phase:
		var a := randf()*TAU
		marks.append(in_arena(encounter_center+Vector3(cos(a), 0, sin(a))*randf_range(6.0, 24.0), 27.0))
	for at in marks:
		hazards.circle(at, 2.4, 1.3, Vector2i(45, 58), HONEY, {patch = {time = 3.0, tick = 0.6, damage = Vector2i(10, 16)}})
		after(1.35, func() -> void:
			var o := at
			o.y = shot_origin().y
			for k in 8: shoot(o, Vector3.FORWARD.rotated(Vector3.UP, TAU*k/8.0), _honey(4.0)))

## A wall of shards sweeps across the whole arena; one gap lets you through.
func _sand_wall() -> void:
	var dir := aim_dir()
	var side := dir.cross(Vector3.UP).normalized()
	var back := encounter_center-dir*22.0
	var gap := randi_range(-7, 7)
	model.boss_pose("cast", 1.2)
	hazards.lane(encounter_center, dir, 50.0, 1.0, 1.0, 0.0, Vector2i.ZERO, 0.0, AMBER)
	after(1.0, func() -> void:
		for k in range(-10, 11):
			if absi(k-gap)<=1: continue
			var o := back+side*k*2.1
			o.y = shot_origin().y
			var attack := _shard(6.0)
			attack.range = 50.0
			shoot(o, dir, attack))

func _rush() -> void:
	var dir := aim_dir()
	var length := 24.0
	model.boss_pose("charge_windup", 1.2)
	hazards.lane(global_position+dir*length*0.5, dir, length, 4.0, 1.2, 0.0, Vector2i.ZERO, 0.0, AMBER)
	face_override = dir
	after(1.2, func() -> void:
		model.boss_pose("charge", 1.2)
		start_charge(dir, length, 14.0, Vector2i(60, 78), func() -> void:
			model.boss_pose("charge_recover", 0.8)
			face_override = Vector3.ZERO
			fire_ring(shot_origin(), 20, _shard(6.5))
			after(1.0, func() -> void: steer_to(encounter_center, 3.5))
			after(3.5, func() -> void:
				behavior = "stationary"
				scripted_move = Vector3.ZERO)))

## Amber discs that fly out and come back.
func _boomerangs() -> void:
	model.play_attack(0.6)
	var base := aim_dir()
	var disc := PlanetBosses.shot("amber_shard", "disc", AMBER, Vector2i(48, 60), 8.0, 32.0, 1.4, {returns = 15.0})
	after(0.6, func() -> void: fire_fan(shot_origin(), base, 8, 45.0, disc))

func _spiral() -> void:
	model.boss_pose("channel", 3.0)
	_turn += 0.7
	var start := _turn
	for beat in 18:
		after(0.4+beat*0.15, func() -> void:
			for arm in 5:
				var attack := _honey(5.2)
				attack.turn = -0.1
				shoot(shot_origin(), Vector3.FORWARD.rotated(Vector3.UP, start+beat*0.19+arm*TAU/5.0), attack))

func _mites(count: int) -> void:
	model.boss_pose("summon", 1.8)
	for i in count:
		var a := TAU*i/count
		var helper := spawn_support("honey_mite_thrall", encounter_center+Vector3(cos(a), 0, sin(a))*10.0, "mites", true)
		if helper: arm_summon(helper, 0.15*i)
	var scarab := spawn_support("amber_scarab_thrall", encounter_center+Vector3(0, 0, 14.0), "mites", true)
	if scarab: arm_summon(scarab, 0.8)

func _reset_hook() -> void:
	_turn = 0.0
	resting = false

func _death_started() -> void:
	despawn_support("mites")
