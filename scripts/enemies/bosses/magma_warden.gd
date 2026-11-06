extends Boss
## A living furnace: eruptions crawl outward, rings leave a marked escape, then a breach.
const FIRE := Color("f46b27")
const HOT := Color("ffd578")

func _phase_started(index: int) -> void:
	behavior = "stationary"
	charge_arena_radius = 13.0
	despawn_support("furnace")
	match index:
		0: set_cycle(13.0, [[0.5, _magma_ring], [3.5, _eruption], [7.0, _cinders], [10.0, _magma_ring]])
		1:
			_guards()
			set_cycle(14.0, [[2.5, _eruption], [6.0, _magma_ring], [9.0, _cinders], [11.5, _eruption]])
		2: set_cycle(15.0, [[0.5, _breach], [4.0, _magma_ring], [6.5, _eruption], [10.0, _cinders], [12.0, _magma_ring]])

func _threshold_reached(next: int) -> void:
	if not resting: begin_rest(func() -> void: _enter_phase(next), "The furnace draws breath")

func _ember(speed := 6.0) -> Dictionary:
	return Boss.shot("fireball", FIRE, Vector2i(45, 58), speed, 0.2, 26.0,
		{voxel_model = "boss_projectiles/magma_seed", authored_projectile = true, pixel_projectile = true,
			light_energy = 0.6, light_range = 3.0, projectile_glow = 1.1, size = 0.9})

func _magma_ring() -> void:
	model.boss_pose("cast", 1.4)
	var gap := atan2(-aim_dir().x, -aim_dir().z)
	mark_ring_gaps(gap, 58.0, 1.1, HOT)
	after(1.1, func() -> void:
		fire_ring(shot_origin(), 20 if phase < 2 else 28, _ember(5.0), gap, 58.0)
		if phase == 2:
			after(0.45, func() -> void: fire_ring(shot_origin(), 20, _ember(6.0), gap, 70.0)))

func _eruption() -> void:
	model.boss_pose("slam_windup", 1.3)
	var axis := aim_dir().rotated(Vector3.UP, PI * 0.5)
	# Two mirrored seams with a clear center corridor; all pools expire before the next cast.
	for side in [-1.0, 1.0]:
		for step in 4:
			var at: Vector3 = encounter_center + axis * side * (3.5 + step * 2.6)
			hazards.circle(at, 1.65, 1.2 + step * 0.22, Vector2i(52, 68), FIRE,
				{patch = {time = 2.5, damage = Vector2i(24, 32), tick = 0.9}})
	after(1.2, func() -> void: model.boss_pose("slam_release", 0.6))

func _cinders() -> void:
	model.boss_pose("cast", 1.6)
	var direction := aim_dir()
	for volley in 3:
		after(0.9 + volley * 0.25, func() -> void:
			var slag := {}
			if volley == 2:
				slag = _ember(6.0)
				slag.merge({color = HOT, size = 1.3, radius = 0.27,
					effects = [{id = "defense", amount = -8, duration = 2.0}], effect_source = "Magma Warden molten slag"}, true)
			fire_fan(shot_origin(), direction, 5, 17.0, _ember(7.0), slag))

func _guards() -> void:
	model.boss_pose("summon", 2.4)
	for side in [-1.0, 1.0]:
		var helper := spawn_support("cinder_cultist", encounter_center + Vector3(side * 8, 0, -4), "furnace", true)
		if helper: arm_summon(helper)

func _breach() -> void:
	var end := in_arena(global_position + aim_dir() * 12.0, 12.0)
	var distance := global_position.distance_to(end)
	if distance < 1.0: return
	var direction := (end - global_position).normalized()
	face_override = direction
	model.boss_pose("charge_windup", 1.3)
	hazards.lane(global_position + direction * distance * 0.5, direction, distance, 3.0, 1.3, 0.0, Vector2i.ZERO, 0.0, HOT)
	after(1.3, func() -> void:
		model.boss_pose("charge", 1.8)
		start_charge(direction, distance, 8.0, Vector2i(55, 72), func() -> void:
			face_override = Vector3.ZERO
			model.boss_pose("charge_recover", 1.0)))

func _reset_hook() -> void:
	model.boss_pose("idle", 0.1)

func _death_started() -> void:
	model.boss_pose("death", boss_def.death_time + 1.0)

func _dying_update(_k: float) -> void:
	model.scale = Vector3.ONE * def.model_scale
