extends Boss
## The Brood Matriarch, in the Rotting Hive on Mawgrave. A fungal hive queen
## with scythe arms: spores that burst into acid, pools, and endless brood.
##
## 1 (100-65%)  spore bursts (clusters that split into acid lances), scythe
##    sweeps (two crossing arcs of lances), acid pools under everyone.
## 2 (65-30%)   "swarm": hard to hurt while her broodlings live, a spore
##    spiral, and she calls more brood.
## 3 (30-0%)    "rot": lunges across the hive, double rings of acid, the
##    spores burst twice.
const PINK := Color("ff5fd2")
const ACID := Color("7dff6a")
var _turn := 0.0

func _phase_started(index: int) -> void:
	behavior = "stationary"
	charge_arena_radius = 24.0
	match index:
		0: set_cycle(12.0, [[0.6, _spores.bind(5)], [3.5, _scythes], [6.0, _pools], [8.5, _spores.bind(5)], [10.5, _scythes]])
		1:
			_brood(6)
			shielded = true
			status_text = "Shielded by her brood"
			set_cycle(13.0, [[0.6, _spiral], [4.5, _scythes], [6.5, _pools], [8.5, _spores.bind(7)], [11.0, _brood.bind(3)]])
		2: set_cycle(13.0, [[0.6, _lunge], [4.0, _double_ring], [6.0, _spores.bind(7)], [8.5, _lunge], [11.0, _pools]])

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	# Swarm phase: her broodlings shield her; when they are all down she is open.
	if phase==1 and shielded and support("brood").is_empty():
		shielded = false
		status_text = ""

func _threshold_reached(next: int) -> void:
	if resting: return
	begin_rest(func() -> void: _enter_phase(next),
		"Her egg sacs burst: the brood shields her" if next==1 else "The hive rots from within", "kneel")

func _lance(speed := 7.5) -> Dictionary:
	return PlanetBosses.shot("acid_lance", "needle", ACID, Vector2i(52, 66), speed, 22.0, 1.0)

func _spore(burst: int) -> Dictionary:
	return PlanetBosses.shot("spore_cluster", "orb", PINK, Vector2i(56, 70), 4.5, 8.0, 1.6,
		{terminal = {delay = 0.35, count = burst, attack = _lance(6.0)}})

## Spore clusters drift out and split into acid lances.
func _spores(count: int) -> void:
	model.boss_pose("cast", 1.2)
	var burst := 8 if phase<2 else 10
	after(0.7, func() -> void: fire_fan(shot_origin(), aim_dir(), count, 360.0/count, _spore(burst)))

## Two scythe arcs sweep in from opposite sides and cross.
func _scythes() -> void:
	model.boss_pose("cleave_windup", 1.0)
	var base := aim_dir()
	after(1.0, func() -> void:
		model.boss_pose("cleave_release", 0.6)
		model.strike()
		for k in 13:
			after(k*0.04, func() -> void:
				for side: float in [-1.0, 1.0]:
					var a := deg_to_rad(lerpf(-75.0, 75.0, k/12.0))*side
					shoot(shot_origin(1.5), base.rotated(Vector3.UP, a), _lance(8.0))))

## Acid pools under everyone and a few between.
func _pools() -> void:
	var marks: Array[Vector3] = []
	for p in players(): marks.append(in_arena(p.global_position, 27.0))
	for i in 3+phase*2:
		var a := randf()*TAU
		marks.append(in_arena(encounter_center+Vector3(cos(a), 0, sin(a))*randf_range(6.0, 25.0), 27.0))
	for at in marks:
		hazards.circle(at, 2.8, 1.3, Vector2i(50, 64), ACID, {patch = {time = 4.0, tick = 0.6, damage = Vector2i(14, 20)}})

## Five arms of spores winding out of her.
func _spiral() -> void:
	model.boss_pose("channel", 3.2)
	_turn += 0.5
	var start := _turn
	for beat in 20:
		after(0.4+beat*0.15, func() -> void:
			for arm in 5:
				var attack := PlanetBosses.shot("spore_cluster", "orb", PINK, Vector2i(46, 60), 5.0, 22.0, 1.0)
				attack.turn = 0.14
				shoot(shot_origin(), Vector3.FORWARD.rotated(Vector3.UP, start+beat*0.2+arm*TAU/5.0), attack))

## Two rings, acid then spores, each with gaps.
func _double_ring() -> void:
	var gap := atan2(-aim_dir().x, -aim_dir().z)+PI*0.5
	mark_ring_gaps(gap, 44.0, 1.0, ACID)
	after(1.0, func() -> void:
		model.strike()
		fire_ring(shot_origin(), 32, _lance(6.0), gap, 44.0))
	after(1.5, func() -> void:
		fire_ring(shot_origin(), 24, PlanetBosses.shot("spore_cluster", "orb", PINK, Vector2i(46, 60), 4.5, 22.0, 1.0), gap+0.2, 44.0))

## She crouches, then lunges along a marked lane, spitting lances as she lands.
func _lunge() -> void:
	var dir := aim_dir()
	var length := 22.0
	model.boss_pose("charge_windup", 1.1)
	hazards.lane(global_position+dir*length*0.5, dir, length, 4.0, 1.1, 0.0, Vector2i.ZERO, 0.0, PINK)
	face_override = dir
	after(1.1, func() -> void:
		model.boss_pose("charge", 1.1)
		start_charge(dir, length, 15.0, Vector2i(70, 90), func() -> void:
			model.boss_pose("charge_recover", 0.8)
			face_override = Vector3.ZERO
			fire_ring(shot_origin(), 18, _lance(6.5))
			after(1.0, func() -> void: steer_to(encounter_center, 3.5))
			after(3.5, func() -> void:
				behavior = "stationary"
				scripted_move = Vector3.ZERO)))

func _brood(count: int) -> void:
	model.boss_pose("summon", 1.8)
	if support("brood").size()>=8: return
	for i in count:
		var a := TAU*i/count+randf()*0.4
		var id := "hive_tender_thrall" if i % 3==0 else "spore_drone_thrall"
		var helper := spawn_support(id, encounter_center+Vector3(cos(a), 0, sin(a))*13.0, "brood", true)
		if helper: arm_summon(helper, 0.15*i)

func _reset_hook() -> void:
	_turn = 0.0
	status_text = ""
	resting = false

func _death_started() -> void:
	despawn_support("brood")
