extends Boss
## The Hollow Empress: queen of the brood in the Convergence. Her tail lashes
## spine fans, she rains acid, lunges and calls her brood. Every phase change
## drops one ring of the arena (TheoryWorld.set_arena_stage), so the fight
## closes in around her.
const ACID := Color("7dff6a")
const PINK := Color("ff5fd2")
var _turn := 0.0

func _phase_started(index: int) -> void:
	behavior = "stationary"
	if director.world is TheoryWorld: (director.world as TheoryWorld).set_arena_stage(index)
	match index:
		0: set_cycle(13.0, [[0.6, _lash], [4.0, _acid_rain], [7.5, _spine_ring], [10.5, _lash]])
		1:
			_brood(3, false)
			set_cycle(14.0, [[2.5, _lunge], [5.5, _lash], [8.5, _acid_rain], [11.5, _spine_ring]])
		2:
			_brood(3, true)
			set_cycle(13.5, [[2.5, _spiral], [6.0, _lunge], [8.5, _lash], [11.0, _acid_rain]])
		3:
			_brood(2, true)
			set_cycle(12.0, [[2.0, _spine_ring], [4.5, _spiral], [7.5, _lash], [9.5, _acid_rain]])

func _threshold_reached(next: int) -> void:
	if not resting: begin_rest(func() -> void: _enter_phase(next), "The Convergence unravels beneath her")

## Usable radius of the arena in the current phase (rings 27 to 10.5 m).
func _floor_radius() -> float:
	return 25.0 - phase * 5.5

func _spine(speed := 7.0) -> Dictionary:
	return Boss.shot("bolt", PINK, Vector2i(48, 65), speed, 0.17, 24.0,
		{voxel_model = "boss_projectiles/void_spine", authored_projectile = true, pixel_projectile = true, size = 1.0})

func _glob(speed := 5.5) -> Dictionary:
	return Boss.shot("orb", ACID, Vector2i(50, 71), speed, 0.2, 22.0,
		{voxel_model = "boss_projectiles/acid_glob", authored_projectile = true, pixel_projectile = true, size = 1.1})

## The tail coils over her back, then whips a sweeping fan of spines.
func _lash() -> void:
	model.boss_pose("cleave_windup", 1.1)
	model.play_attack(1.0)
	pulse_glow(1.4, 1.0)
	var base := aim_dir()
	face_override = base
	var side := 1.0 if randf() < 0.5 else -1.0
	after(1.0, func() -> void:
		model.strike()
		model.boss_pose("cleave_release", 0.6)
		var shots := 9 if phase < 2 else 12
		for k in shots:
			after(k * 0.05, func() -> void:
				var a := lerpf(-60.0, 60.0, float(k) / (shots - 1)) * side
				shoot(shot_origin(1.5), base.rotated(Vector3.UP, deg_to_rad(a)), _spine(7.5)))
		after(0.6, func() -> void: face_override = Vector3.ZERO))

## Acid lands on every player and between them, leaving burning pools.
func _acid_rain() -> void:
	model.boss_pose("cast", 1.6)
	var marks: Array[Vector3] = []
	for p in players(): marks.append(in_arena(p.global_position, _floor_radius()))
	var extra := 3 + phase
	for i in extra:
		var angle := randf() * TAU
		marks.append(in_arena(encounter_center + Vector3(cos(angle), 0, sin(angle)) * randf_range(5.0, _floor_radius()), _floor_radius()))
	for at in marks:
		hazards.circle(at, 2.6, 1.4, Vector2i(77, 105), ACID, {patch = {time = 3.5, tick = 0.6, damage = Vector2i(12, 18)}})
	after(0.8, func() -> void:
		fire_fan(shot_origin(), aim_dir(), 5, 18.0, _glob(5.0)))

## A ring of spines with two marked gaps.
func _spine_ring() -> void:
	model.boss_pose("slam_windup", 1.3)
	var gap := atan2(-aim_dir().x, -aim_dir().z) + PI * 0.5
	mark_ring_gaps(gap, 50.0, 1.2, PINK)
	after(1.2, func() -> void:
		model.boss_pose("slam_release", 0.5)
		model.strike()
		fire_ring(shot_origin(), 26, _spine(6.0), gap, 50.0)
		if phase >= 2:
			after(0.55, func() -> void: fire_ring(shot_origin(), 26, _glob(4.5), gap + 0.12, 50.0)))

## Crouches, then lunges across the bowl along a marked lane.
func _lunge() -> void:
	var dir := aim_dir()
	var length := minf(_floor_radius() * 1.4, 22.0)
	model.boss_pose("charge_windup", 1.2)
	hazards.lane(global_position + dir * length * 0.5, dir, length, 3.6, 1.2, 0.0, Vector2i.ZERO, 0.0, PINK)
	face_override = dir
	after(1.2, func() -> void:
		model.boss_pose("charge", 1.2)
		start_charge(dir, length, 13.0, Vector2i(90, 115), func() -> void:
			model.boss_pose("charge_recover", 0.8)
			face_override = Vector3.ZERO
			# Settles back toward the centre so the shrinking floor stays fair.
			after(0.9, func() -> void: steer_to(encounter_center, 3.0))
			after(3.0, func() -> void:
				behavior = "stationary"
				scripted_move = Vector3.ZERO)))

## Three arms of acid turning slowly around her.
func _spiral() -> void:
	model.boss_pose("channel", 3.0)
	_turn += PI / 5.0
	var start := _turn
	for beat in 10:
		after(0.8 + beat * 0.24, func() -> void:
			for arm in 3:
				var attack := _glob(5.2)
				attack.turn = 0.12 if phase < 3 else -0.15
				shoot(shot_origin(), Vector3.FORWARD.rotated(Vector3.UP, start + beat * 0.15 + arm * TAU / 3.0), attack))

## Brood hatches at the edge of the remaining floor.
func _brood(count: int, stalkers: bool) -> void:
	model.boss_pose("summon", 2.4)
	despawn_support("brood")
	var radius := _floor_radius() - 3.0
	for i in count:
		var angle := TAU * i / count + randf() * 0.4
		var helper := spawn_support("hull_skitter", encounter_center + Vector3(cos(angle), 0, sin(angle)) * radius, "brood", true)
		if helper: arm_summon(helper, 0.2 * i)
	if stalkers:
		var helper := spawn_support("vent_stalker", encounter_center + Vector3(0, 0, radius), "brood", true)
		if helper: arm_summon(helper, 0.6)

func _reset_hook() -> void:
	_turn = 0.0
	model.boss_pose("idle", 0.1)
	if director.world is TheoryWorld: (director.world as TheoryWorld).set_arena_stage(0)

func _death_started() -> void:
	despawn_support("brood")
	model.boss_pose("death", boss_def.death_time + 1.0)

func _dying_update(_k: float) -> void:
	model.scale = Vector3.ONE * def.model_scale
