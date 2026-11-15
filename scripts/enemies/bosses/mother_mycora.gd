extends SurfaceBoss
## Mother Mycora (3.5/10): slow, soft and readable. Spore rings breathe out
## from her with wide gaps, mycelium threads run across the floor toward you,
## and in bloom spores settle in circles you can see coming.
const SPORE := Color("ffc04a")
const TEAL := Color("6fe8d6")
const ROT := Color("b07aff")
var _turn := 0.0


func _ready() -> void:
	super._ready()
	glow_color = SPORE
	glow_alt = TEAL


func _phase_started(index: int) -> void:
	behavior = "stationary"
	despawn_support("brood")
	match index:
		0: set_cycle(13.0, [[0.8, _breathe], [4.0, _puff_fan], [7.0, _threads], [10.0, _breathe]])
		1:
			_brood()
			set_cycle(14.0, [[1.5, _bloom], [4.5, _breathe], [8.0, _threads], [11.0, _puff_fan]])
		2: set_cycle(13.0, [[0.8, _rot_spiral], [5.0, _bloom], [8.5, _breathe], [11.0, _threads]])


func _rest_line(next: int) -> String:
	return "Her cap unfurls" if next == 1 else "The rot takes her"


func _spore(color := SPORE, speed := 4.2) -> Dictionary:
	return bolt("spore_puff", color, Vector2i(38, 50), speed, {size = 1.1, radius = 0.24})


## Two slow rings, the second offset into the first one's gaps.
func _breathe() -> void:
	model.boss_pose("channel", 2.2)
	glow_wave(TEAL, {speed = 6.0, strength = 1.6})
	for k in 2:
		after(0.9 + k * 0.9, func() -> void:
			var offset := k * PI / 14.0 + _turn
			for i in 14:
				shoot(shot_origin(), Vector3.FORWARD.rotated(Vector3.UP, offset + TAU * i / 14.0), _spore(SPORE if k == 0 else TEAL)))
	_turn += 0.2


func _puff_fan() -> void:
	model.boss_pose("cast", 1.6)
	var direction := aim_dir()
	after(0.8, func() -> void:
		fire_fan(shot_origin(), direction, 5, 15.0, bolt("spore_cluster", SPORE, Vector2i(44, 56), 6.0, {size = 1.1})))


## Pale threads race across the floor toward each player, then flare.
func _threads() -> void:
	model.boss_pose("slam_windup", 1.6)
	for at in targets(3):
		var dir := (at - global_position)
		dir.y = 0.0
		if dir.length() < 0.5: dir = Vector3.FORWARD
		hazards.lane(global_position + dir.normalized() * 9.0, dir, 18.0, 1.4, 1.6, 0.9, Vector2i(40, 52), 0.8, TEAL, {height = 0.3})
	after(1.6, func() -> void:
		model.boss_pose("slam_release", 0.6)
		glow_wave(TEAL, {speed = 12.0, width = 1.6}))


## Her cap opens: spores settle in circles round each player, and a few puff up.
func _bloom() -> void:
	model.boss_pose("summon", 2.0)
	glow_wave(SPORE, {rings = 2, gap = 0.5})
	for at in targets(4):
		for k in 3:
			var spot := at + Vector3(randf_range(-3.0, 3.0), 0, randf_range(-3.0, 3.0))
			hazards.circle(spot, 1.8, 1.4 + k * 0.3, Vector2i(42, 54), SPORE,
				{patch = {time = 2.5, tick = 0.8, damage = Vector2i(14, 18)}})
	after(1.8, func() -> void:
		fire_ring(shot_origin(), 10, bolt("spore_bomb", SPORE, Vector2i(46, 58), 3.6, {size = 1.2}), gap_angle(), 50.0))


## Rot: four slow arms turn while she sways.
func _rot_spiral() -> void:
	model.boss_pose("channel", 3.4)
	var start := _turn
	for beat in 10:
		after(0.6 + beat * 0.28, func() -> void:
			for arm in 4:
				shoot(shot_origin(), Vector3.FORWARD.rotated(Vector3.UP, start + beat * 0.2 + arm * TAU / 4.0),
					bolt("mycelium_seed", ROT, Vector2i(42, 54), 5.0)))
	_turn += 0.6


func _brood() -> void:
	model.boss_pose("summon", 2.4)
	for side: float in [-1.0, 1.0]:
		var helper := spawn_support("spore_puffling", encounter_center + Vector3(side * 7.0, 0, 3.0), "brood", true)
		if helper: arm_summon(helper, 0.2)
