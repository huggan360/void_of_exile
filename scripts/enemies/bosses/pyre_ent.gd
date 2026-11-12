extends Boss
## A burning canopy over a maze of roots. Dense slow embers; lanes and branch falls are warned.
const FIRE := Color("fa7629")
const HOT := Color("ffd077")
var _spiral := 0.0
var _ember_clock := 0.0

func _phase_started(index: int) -> void:
	behavior = "stationary"
	_ember_clock = 1.8
	despawn_support("grove")
	match index:
		0: set_cycle(14.0, [[1.0, _roots], [4.5, _canopy], [8.0, _branches], [11.5, _canopy]])
		1:
			_grove()
			set_cycle(16.0, [[2.5, _branches], [6.0, _roots], [10.0, _canopy], [13.0, _branches]])
		2: set_cycle(14.0, [[0.5, _roots], [4.5, _branches], [8.0, _canopy], [11.0, _branches]])

func _threshold_reached(next: int) -> void:
	if not resting: begin_rest(func() -> void: _enter_phase(next), "The old roots drink the flame")

func _ember(speed := 5.0) -> Dictionary:
	return Boss.shot("fireball", FIRE, Vector2i(59, 77), speed, 0.18, 28.0,
		{voxel_model = "boss_projectiles/pyre_leaf", authored_projectile = true, pixel_projectile = true,
			light_energy = 0.8, light_range = 3.5, projectile_glow = 1.2, size = 0.85})

func _combat(delta: float) -> void:
	if resting: return
	_ember_clock -= delta
	if _ember_clock > 0.0: return
	_ember_clock = 0.85 if phase == 2 else 1.2
	_spiral += 0.18
	# Six rotating arms leave broad moving gaps, even under the final canopy.
	for i in 6:
		var direction := Vector3.FORWARD.rotated(Vector3.UP, _spiral + TAU * i / 6.0)
		shoot(shot_origin(), direction, _ember(4.5))

func _roots() -> void:
	model.boss_pose("slam_windup", 1.7)
	var direction := aim_dir()
	var across := direction.rotated(Vector3.UP, PI * 0.5)
	# Parallel roots alternate sides of a wide safe lane; never an unavoidable full grid.
	for offset in [-10.0, -5.0, 5.0, 10.0]:
		hazards.lane(encounter_center + across * offset, direction, 26.0, 1.6, 1.6, 2.8,
			Vector2i(83, 109), 0.9, FIRE, {height = 0.65})
	after(1.6, func() -> void: model.boss_pose("slam_release", 0.7))

func _canopy() -> void:
	model.boss_pose("summon", 1.6)
	var direction := aim_dir()
	var gap := atan2(-direction.x, -direction.z)
	mark_ring_gaps(gap, 64.0, 1.2, HOT)
	after(1.2, func() -> void:
		# Only the first, brighter canopy wave carries choking ash.
		var ash := _ember(5.5)
		ash.merge({color = HOT, size = 1.15, radius = 0.22,
			effects = [{id = "speed", amount = -8, duration = 1.5}], effect_source = "Pyre Ent choking ash"}, true)
		fire_ring(shot_origin(), 32, ash, gap, 64.0)
		after(0.5, func() -> void: fire_ring(shot_origin(), 32, _ember(6.0), gap, 74.0)))

func _branches() -> void:
	model.boss_pose("cast", 2.2)
	var count := 0
	for player in players():
		if count >= 4: break
		count += 1
		var at: Vector3 = player.global_position
		var axis := (at - encounter_center).normalized()
		if axis.length_squared() < 0.1: axis = Vector3.FORWARD
		hazards.lane(at, axis, 7.5, 2.2, 1.8, 0.35, Vector2i(109, 134), 1.0, HOT, {height = 1.2})
		# A charred voxel branch drops into the warned strip; server damage stays in the hazard.
		after(1.35, func() -> void:
			shoot(at + Vector3.UP * 9.0, Vector3.DOWN, Boss.shot("bolt", FIRE, Vector2i.ZERO, 20.0, 0.05, 9.0,
				{voxel_model = "boss_projectiles/burning_branch", authored_projectile = true, pixel_projectile = true,
					light_energy = 0.8, falling = true, size = 1.0})))

func _grove() -> void:
	model.boss_pose("summon", 2.5)
	for side in [-1.0, 1.0]:
		for row in [-1.0, 1.0]:
			var helper := spawn_support("cinder_sapling", encounter_center + Vector3(side * 9, 0, row * 7), "grove", true)
			if helper: arm_summon(helper, 0.3 if row > 0 else 0.0)

func _reset_hook() -> void:
	_spiral = 0.0
	_ember_clock = 1.8
	model.boss_pose("idle", 0.1)
