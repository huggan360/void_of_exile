extends SurfaceBoss
## Jarl Hrimvald, the Barrow King (7.0/10): heavy and deliberate. Axe cleaves
## throw crescents of ice, the runes of his barrow erupt one after another
## round the hall, avalanches fall in lanes from the walls, and in his wrath he
## charges the length of the hall. The aurora answers him on the ice.
const ICE := Color("8ad8ff")
const RUNE := Color("6ad0ff")
const AURORA := Color("a0ffd8")
const VIOLET := Color("b08aff")
var _round := 0


func _ready() -> void:
	super._ready()
	glow_color = RUNE
	glow_alt = AURORA


func _phase_started(index: int) -> void:
	behavior = "stationary"
	despawn_support("oath")
	match index:
		0: set_cycle(14.0, [[0.8, _cleave], [4.0, _runes], [8.0, _avalanche], [11.5, _cleave]])
		1:
			_oathsworn()
			set_cycle(15.0, [[0.8, _rush], [4.5, _cleave], [7.5, _runes], [11.0, _avalanche]])
		2: set_cycle(14.0, [[0.6, _blizzard], [4.5, _cleave], [7.0, _rush], [10.5, _runes], [12.5, _crows]])


func _rest_line(next: int) -> String:
	return "The barrow wakes to its king's wrath" if next == 1 else "The ice around his heart gives way"


func _axe(speed := 6.5) -> Dictionary:
	return bolt("ice_axe", ICE, Vector2i(88, 110), speed, {size = 1.35, radius = 0.3, pierce_players = true})


## A cleave: a crescent of spinning axes, then a second, wider one.
func _cleave() -> void:
	var direction := aim_dir()
	model.boss_pose("cleave_windup", 1.1)
	after(1.0, func() -> void:
		model.boss_pose("cleave_release", 0.7)
		fire_fan(shot_origin(1.0), direction, 7, 12.0, _axe(7.0))
		glow_burst(global_position, ICE, {range = 11.0}))
	after(1.6, func() -> void:
		fire_fan(shot_origin(1.0), direction, 10, 11.0, _axe(5.5), {}))


## The barrow's runes erupt round the hall, one after another.
func _runes() -> void:
	model.boss_pose("summon", 2.4)
	var radius := room_radius() * 0.6
	var start := randf() * TAU
	var count := 6 if phase < 2 else 8
	for k in count:
		var spot := encounter_center + Vector3.FORWARD.rotated(Vector3.UP, start + TAU * k / count) * radius
		hazards.circle(spot, 2.6, 1.0 + k * 0.35, Vector2i(80, 104), RUNE, {spikes = true})
		after(1.05 + k * 0.35, func() -> void:
			glow_burst(spot, AURORA if k % 2 else RUNE, {range = 8.0})
			var origin := spot
			origin.y = shot_origin().y
			for i in 6:
				shoot(origin, Vector3.FORWARD.rotated(Vector3.UP, TAU * i / 6.0 + k), bolt("frost_rune", RUNE, Vector2i(70, 90), 5.0, {magic = true})))


## Ice comes down in lanes from the walls toward him; two lanes stay clear.
func _avalanche() -> void:
	model.boss_pose("slam_windup", 1.8)
	var start := gap_angle()
	var r := room_radius()
	for k in 10:
		if k in [0, 5]: continue  # the way through
		var dir := Vector3.FORWARD.rotated(Vector3.UP, start + TAU * k / 10.0)
		hazards.lane(encounter_center + dir * r * 0.6, dir, r * 0.9, 2.2, 1.8, 0.7, Vector2i(86, 108), 0.6, ICE, {height = 1.6})
	after(1.8, func() -> void:
		model.boss_pose("slam_release", 0.7)
		glow_wave(AURORA, {speed = 12.0, rings = 2, gap = 0.4}))


## He charges the length of the hall; frost bursts where he stops.
func _rush() -> void:
	var dir := aim_dir()
	model.boss_pose("charge_windup", 1.3)
	hazards.lane(global_position + dir * 10.0, dir, 20.0, 3.4, 1.3, 0.0, Vector2i.ZERO, 0.0, ICE)
	after(1.3, func() -> void:
		model.boss_pose("charge", 1.2)
		start_charge(dir, 18.0, 17.0, Vector2i(110, 135), func() -> void:
			model.boss_pose("charge_recover", 0.9)
			fire_ring(shot_origin(), 18, bolt("frost_shard", Color("d8f4ff"), Vector2i(72, 92), 5.5), gap_angle(), 36.0)
			glow_wave(VIOLET, {speed = 12.0})))


## A blizzard: slow curling snow from every side while the hall goes white.
func _blizzard() -> void:
	model.boss_pose("channel", 3.6)
	_round += 1
	var start := randf() * TAU
	for beat in 14:
		after(0.6 + beat * 0.25, func() -> void:
			for arm in 5:
				shoot(shot_origin(), Vector3.FORWARD.rotated(Vector3.UP, start + beat * 0.15 + arm * TAU / 5.0),
					bolt("frost_shard", Color("e8f8ff"), Vector2i(70, 88), 4.8, {turn = 0.28 if _round % 2 else -0.28}))
			if beat % 5 == 0: glow_wave(AURORA if beat % 10 == 0 else VIOLET, {speed = 8.0}))


func _crows() -> void:
	model.boss_pose("cast", 1.4)
	var direction := aim_dir()
	for k in 14:
		after(0.6 + k * 0.06, func() -> void:
			shoot(shot_origin(), direction.rotated(Vector3.UP, deg_to_rad(-65.0 + k * 10.0)),
				bolt("crow_feather", Color("3a3c48"), Vector2i(76, 96), 9.0)))


func _oathsworn() -> void:
	model.boss_pose("summon", 2.4)
	for side: float in [-1.0, 1.0]:
		var helper := spawn_support("barrow_wight", encounter_center + Vector3(side * 8.0, 0, 4.0), "oath", true)
		if helper: arm_summon(helper, 0.3)
