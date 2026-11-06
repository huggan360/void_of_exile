extends Boss
## A greedy, clumsy king: readable throws, a court of guards, then desperate charges.
const GOLD := Color("eac65b")
const MOSS := Color("9dc66a")
var _ring_angle := 0.0

func _phase_started(index: int) -> void:
	behavior = "stationary"
	charge_arena_radius = 11.0
	match index:
		0: set_cycle(11.0, [[0.4, _coins], [3.2, _clubs], [6.5, _coins], [8.4, _pound]])
		1:
			_court()
			set_cycle(13.0, [[2.4, _clubs], [5.0, _coins], [8.0, _pound], [10.5, _clubs]])
		2:
			despawn_support("court")
			set_cycle(14.0, [[0.5, _charge_king], [4.0, _coins], [6.5, _clubs], [9.0, _charge_king], [12.0, _pound]])

func _threshold_reached(next: int) -> void:
	if not resting: begin_rest(func() -> void: _enter_phase(next), "The King catches his breath")

func _coins() -> void:
	model.boss_pose("cast", 1.0)
	pulse_glow(1.6, 0.8)
	_ring_angle += TAU / 24.0
	var angle := _ring_angle
	after(0.8, func() -> void:
		for i in 12:
			shoot(shot_origin(), Vector3.FORWARD.rotated(Vector3.UP, angle + TAU * i / 12.0),
				Boss.shot("disc", GOLD, Vector2i(15, 22), 5.0, 0.18, 22.0,
				{voxel_model = "boss_projectiles/goblin_coin", authored_projectile = true, pixel_projectile = true, size = 0.8})))

func _clubs() -> void:
	model.boss_pose("throw", 1.2)
	var direction := aim_dir()
	face_override = direction
	after(0.85, func() -> void:
		fire_fan(shot_origin(), direction, 3, 25.0, Boss.shot("bolt", MOSS, Vector2i(22, 30), 6.0, 0.24, 19.0,
			{turn = 0.2 if cycle_count % 2 == 0 else -0.2, voxel_model = "boss_projectiles/goblin_club", authored_projectile = true, pixel_projectile = true,
				effects = [{id = "dexterity", amount = -8, duration = 1.75}], effect_source = "Goblin King bruising club"}))
		face_override = Vector3.ZERO)

func _pound() -> void:
	model.boss_pose("pound", 1.4)
	var at := global_position
	hazards.circle(at, 3.0, 1.1, Vector2i(24, 32), GOLD)
	after(1.1, func() -> void:
		CameraShake.shake_from(self, at, 0.35, 24.0)
		EnemyRipple.spawn(director.bullets, at, {radius = 10.0, speed = 4.0, damage_min = 16, damage_max = 24, knockback = 0.2}, MOSS, players(), []))

func _court() -> void:
	model.boss_pose("summon", 2.0)
	status_text = "Protect your King!"
	for side in [-1.0, 1.0]:
		var helper := spawn_support("cave_slinger", encounter_center + Vector3(side * 6, 0, -2), "court", true)
		if helper: arm_summon(helper)
		var brute := spawn_support("goblin_brute", encounter_center + Vector3(side * 6, 0, 4), "court", true)
		if brute: arm_summon(brute, 0.3)
	after(2.0, func() -> void: status_text = "")

func _charge_king() -> void:
	var direction := aim_dir()
	var end := in_arena(global_position + direction * 11.0, 10.0)
	var distance := global_position.distance_to(end)
	if distance < 1.0: return
	direction = (end - global_position).normalized()
	face_override = direction
	model.boss_pose("charge_windup", 1.2)
	hazards.lane(global_position + direction * distance * 0.5, direction, distance, 2.6, 1.2, 0.0, Vector2i.ZERO, 0.0, GOLD)
	after(1.2, func() -> void:
		model.boss_pose("charge", 1.5)
		start_charge(direction, distance, 7.0, Vector2i(24, 34), func() -> void:
			face_override = Vector3.ZERO
			model.boss_pose("kneel", 1.5)))

func _reset_hook() -> void:
	_ring_angle = 0.0
	model.boss_pose("idle", 0.1)
