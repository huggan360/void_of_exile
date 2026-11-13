extends Boss
## The Brood Matriarch, in the Rotting Hive on Mawgrave. A fungal hive queen
## with scythe arms: spores that burst into acid, pools, and endless brood.
##
## 1 (100-75%)  spore bursts (clusters that split into acid lances), scythe
##    sweeps (two crossing arcs of lances), acid pools under everyone.
## 2 (75-50%)   "swarm": hard to hurt while her broodlings live, a spore
##    spiral, and she calls more brood.
## 3 (50-25%)   "rot": lunges across the hive, double rings of acid, the
##    spores burst twice.
## 4 (25-0%)    "Queen of Rot": acid-soaked eggs (armour broken for 4 s) laid
##    in a spiral across the hive hatch into rings of lances, egg clutches
##    are flung at everyone, and she lunges twice in a row.
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
		3: set_cycle(14.0, [[0.6, _egg_spiral], [4.5, _clutches], [6.5, _lunge], [9.5, _lunge], [12.0, _clutches]])

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	# Swarm phase: her broodlings shield her; when they are all down she is open.
	if phase==1 and shielded and support("brood").is_empty():
		shielded = false
		status_text = ""

func _threshold_reached(next: int) -> void:
	if resting: return
	begin_rest(func() -> void: _enter_phase(next),
		["", "Her egg sacs burst: the brood shields her", "The hive rots from within", "The Queen of Rot lays her last clutch"][next], "kneel")

func _lance(speed := 7.5) -> Dictionary:
	return PlanetBosses.shot("acid_lance", "needle", ACID, Vector2i(120, 153), speed, 22.0, 1.0)

func _spore(burst: int) -> Dictionary:
	return PlanetBosses.shot("spore_cluster", "orb", PINK, Vector2i(162, 203), 4.5, 8.0, 1.6,
		{terminal = {delay = 0.35, count = burst, attack = _lance(6.0)}})

## Acid-soaked eggs: a hit breaks your armour for a while.
func _egg(speed := 4.5) -> Dictionary:
	return PlanetBosses.shot("brood_egg", "orb", PINK, Vector2i(120, 154), speed, 9.0, 1.4,
		{effects = [{id = "armour_broken", duration = 4.0}], effect_source = "the Matriarch's eggs",
		terminal = {delay = 0.5, count = 8, attack = _lance(5.5)}})

## Eggs laid in a winding spiral; each hatches into a ring of lances.
func _egg_spiral() -> void:
	model.boss_pose("channel", 3.4)
	var start := randf()*TAU
	for beat in 12:
		after(0.4+beat*0.25, func() -> void:
			for arm in 3:
				var egg := _egg(4.0)
				egg.range = 5.0+beat*1.4
				shoot(shot_origin(), Vector3.FORWARD.rotated(Vector3.UP, start+beat*0.4+arm*TAU/3.0), egg))

## Clutches of three eggs flung at everyone, landing at their feet.
func _clutches() -> void:
	model.boss_pose("cast", 1.0)
	for p in players():
		var to: Vector3 = p.global_position-global_position
		to.y = 0.0
		var egg := _egg(7.0)
		egg.range = clampf(to.length(), 5.0, 22.0)
		after(0.6, func() -> void: fire_fan(shot_origin(1.5), to.normalized(), 3, 18.0, egg))

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
		hazards.circle(at, 2.8, 1.3, Vector2i(164, 210), ACID, {patch = {time = 4.0, tick = 0.6, damage = Vector2i(24, 35)}})

## Five arms of spores winding out of her.
func _spiral() -> void:
	model.boss_pose("channel", 3.2)
	_turn += 0.5
	var start := _turn
	for beat in 20:
		after(0.4+beat*0.15, func() -> void:
			for arm in 5:
				var attack := PlanetBosses.shot("spore_cluster", "orb", PINK, Vector2i(107, 139), 5.0, 22.0, 1.0)
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
		fire_ring(shot_origin(), 24, PlanetBosses.shot("spore_cluster", "orb", PINK, Vector2i(107, 139), 4.5, 22.0, 1.0), gap+0.2, 44.0))

## She crouches, then lunges along a marked lane, spitting lances as she lands.
func _lunge() -> void:
	var dir := aim_dir()
	var length := 22.0
	model.boss_pose("charge_windup", 1.1)
	hazards.lane(global_position+dir*length*0.5, dir, length, 4.0, 1.1, 0.0, Vector2i.ZERO, 0.0, PINK)
	face_override = dir
	after(1.1, func() -> void:
		model.boss_pose("charge", 1.1)
		start_charge(dir, length, 15.0, Vector2i(163, 210), func() -> void:
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
