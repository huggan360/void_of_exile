extends Boss
## A crystal-tailed singer: curling tides, expanding sound and a living reef.
const WATER := Color("43dace")
const PEARL := Color("bfedff")
var _verse := 0.0

func _phase_started(index: int) -> void:
	behavior = "stationary"
	despawn_support("reef")
	match index:
		0: set_cycle(13.0, [[0.5, _tides], [3.6, _song], [7.0, _tides], [10.0, _crystals]])
		1:
			_reef()
			set_cycle(15.0, [[2.8, _song], [6.0, _tides], [9.0, _crystals], [12.0, _song]])
		2:
			_reef()
			set_cycle(14.0, [[2.5, _maelstrom], [5.5, _song], [8.0, _crystals], [11.0, _tides]])

func _threshold_reached(next: int) -> void:
	if not resting: begin_rest(func() -> void: _enter_phase(next), "The Siren draws a breath beneath the tide")

func _water(speed := 6.0) -> Dictionary:
	return Boss.shot("bolt", WATER, Vector2i(40, 52), speed, 0.18, 25.0,
		{voxel_model = "boss_projectiles/tide_shard", authored_projectile = true, pixel_projectile = true, size = 0.9})

func _tides() -> void:
	model.boss_pose("cast", 1.3)
	var direction := aim_dir()
	face_override = direction
	after(0.9, func() -> void:
		for side in [-1.0, 1.0]:
			var attack := _water(6.5)
			attack.turn = side * (0.16 if phase < 2 else 0.26)
			var origin: Vector3 = shot_origin() + direction.rotated(Vector3.UP, PI * 0.5) * side * 2.0
			fire_fan(origin, direction, 3 if phase < 2 else 4, 16.0, attack)
		face_override = Vector3.ZERO)

func _song() -> void:
	model.boss_pose("channel", 2.0)
	var at := global_position
	var gap := atan2(-aim_dir().x, -aim_dir().z)
	mark_ring_gaps(gap, 62.0, 1.2, PEARL)
	after(1.2, func() -> void:
		fire_ring(shot_origin(), 20 if phase < 2 else 26, Boss.shot("disc", PEARL, Vector2i(36, 46), 4.5, 0.2, 24.0,
			{voxel_model = "boss_projectiles/siren_echo", authored_projectile = true, pixel_projectile = true}), gap, 62.0)
		EnemyRipple.spawn(director.bullets, at, {radius = 15.0, speed = 3.4, damage_min = 26, damage_max = 36, knockback = 0.25}, WATER, players(), []))

func _crystals() -> void:
	model.boss_pose("summon", 1.8)
	_verse += PI / 5.0
	for i in 4:
		var at := encounter_center + Vector3.FORWARD.rotated(Vector3.UP, _verse + i * PI * 0.5) * 7.0
		hazards.circle(at, 1.8, 1.3 + i * 0.15, Vector2i(42, 56), WATER)

func _reef() -> void:
	model.boss_pose("summon", 2.5)
	for side in [-1.0, 1.0]:
		var helper := spawn_support("tide_wisp", encounter_center + Vector3(side * 7.0, 0, -4), "reef", true)
		if helper: arm_summon(helper)
		if phase == 2:
			var guard := spawn_support("grotto_crab", encounter_center + Vector3(side * 6.0, 0, 5), "reef", true)
			if guard: arm_summon(guard, 0.4)

func _maelstrom() -> void:
	model.boss_pose("channel", 2.0)
	hazards.circle(encounter_center, 5.5, 1.3, Vector2i.ZERO, WATER, {visual = true})
	after(1.3, func() -> void:
		fire_orbit(encounter_center, 5.5, 8, 4.5, 0.65, 1.0, _water(), _verse))

func _reset_hook() -> void:
	_verse = 0.0
	model.boss_pose("idle", 0.1)
