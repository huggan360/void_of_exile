extends Boss
## Bell strokes expand across the floor; drowned voices braid into open spirals.
const BELL := Color("a6dbef")
const SOUL := Color("708cf5")
var _chant := 0.0

func _phase_started(index: int) -> void:
	behavior = "stationary"
	despawn_support("choir")
	match index:
		0: set_cycle(14.0, [[0.5, _bells], [4.0, _spiral], [8.0, _refrain], [11.0, _bells]])
		1:
			_choir()
			set_cycle(16.0, [[2.8, _spiral], [6.5, _bells], [10.0, _refrain], [13.0, _spiral]])
		2:
			_choir()
			set_cycle(15.0, [[2.8, _bells], [6.0, _spiral], [10.0, _refrain], [12.5, _bells]])

func _threshold_reached(next: int) -> void:
	if not resting: begin_rest(func() -> void: _enter_phase(next), "The drowned choir falls silent")

func _note(speed := 5.5) -> Dictionary:
	return Boss.shot("orb", SOUL, Vector2i(71, 93), speed, 0.19, 26.0,
		{voxel_model = "boss_projectiles/bell_note", authored_projectile = true, pixel_projectile = true, size = 0.85})

func _bells() -> void:
	model.boss_pose("slam_windup", 2.0)
	var at := global_position
	var gap := atan2(-aim_dir().x, -aim_dir().z)
	mark_ring_gaps(gap, 65.0, 1.2, BELL)
	for stroke in (3 if phase == 2 else 2):
		after(1.2 + stroke * 0.85, func() -> void:
			model.boss_pose("slam_release", 0.5)
			EnemyRipple.spawn(director.bullets, at, {radius = 17.0, speed = 3.6 + stroke * 0.5,
				damage_min = 39, damage_max = 55, knockback = 0.3}, BELL, players(), [])
			fire_ring(shot_origin(), 22, _note(5.0), gap, 65.0))

func _spiral() -> void:
	model.boss_pose("channel", 3.2)
	_chant += PI / 7.0
	var start := _chant
	# Three interleaved arms turn slowly; the broad wedges between them remain open.
	for beat in 8:
		after(0.9 + beat * 0.22, func() -> void:
			for voice in 3:
				var direction := Vector3.FORWARD.rotated(Vector3.UP, start + beat * 0.16 + voice * TAU / 3.0)
				var attack := _note(5.8)
				attack.turn = 0.11 if phase < 2 else -0.14
				shoot(shot_origin(), direction, attack))

func _refrain() -> void:
	model.boss_pose("cast", 1.8)
	var direction := aim_dir()
	for beat in 3:
		after(0.9 + beat * 0.35, func() -> void:
			var final_note := {}
			# Only the large centre note of the final refrain silences.
			if beat == 2:
				final_note = _note(6.0)
				final_note.merge({color = BELL, size = 1.25, radius = 0.25,
					effects = [{id = "quiet", duration = 1.75}], effect_source = "Drowned Cantor refrain"}, true)
			fire_fan(shot_origin(), direction, 5 if phase < 2 else 7, 14.0, _note(7.0), final_note))

func _choir() -> void:
	model.boss_pose("summon", 2.8)
	for side in [-1.0, 1.0]:
		var helper := spawn_support("choir_wraith", encounter_center + Vector3(side * 8.0, 0, -4), "choir", true)
		if helper: arm_summon(helper, 0.2)
		if phase == 2:
			var singer := spawn_support("drowned_acolyte", encounter_center + Vector3(side * 7.0, 0, 5), "choir", true)
			if singer: arm_summon(singer, 0.5)

func _reset_hook() -> void:
	_chant = 0.0
	model.boss_pose("idle", 0.1)

func _death_started() -> void:
	model.boss_pose("death", boss_def.death_time + 1.0)

func _dying_update(_k: float) -> void:
	model.scale = Vector3.ONE * def.model_scale
