extends Boss
## The Regent's treasurer: mirrored sand quills, a solar clock and a guarded court.
const GOLD := Color("efc358")
const ROSE := Color("f6a3bd")
var _dial := 0.0

func _phase_started(index: int) -> void:
	behavior = "stationary"
	despawn_support("court")
	match index:
		0: set_cycle(12.0, [[0.4, _quills], [3.2, _hourglass], [6.0, _quills], [8.8, _sundial]])
		1:
			_court()
			set_cycle(14.0, [[2.8, _sundial], [5.0, _quills], [8.0, _hourglass], [11.0, _quills]])
		2: set_cycle(12.0, [[0.5, _eclipse], [3.0, _quills], [5.2, _sundial], [8.0, _hourglass], [10.2, _quills]])

func _threshold_reached(next: int) -> void:
	if not resting: begin_rest(func() -> void: _enter_phase(next), "The Vizier weighs the sun")

func _sand(speed := 6.0) -> Dictionary:
	return Boss.shot("needle", GOLD, Vector2i(36, 46), speed, 0.16, 24.0,
		{voxel_model = "boss_projectiles/sand_needle", authored_projectile = true, pixel_projectile = true, size = 0.8})

func _quills() -> void:
	model.boss_pose("cast", 1.2)
	var direction := aim_dir()
	face_override = direction
	after(0.85, func() -> void:
		for side in [-1.0, 1.0]:
			var origin: Vector3 = shot_origin() + direction.rotated(Vector3.UP, PI * 0.5) * side * 1.6
			var attack := _sand(7.0)
			attack.turn = side * (0.12 if phase < 2 else 0.22)
			fire_fan(origin, direction, 3 if phase < 2 else 4, 14.0, attack)
		face_override = Vector3.ZERO)

func _hourglass() -> void:
	model.boss_pose("channel", 2.3)
	_dial += PI / 6.0
	var axis := Vector3.FORWARD.rotated(Vector3.UP, _dial)
	for side in [-1.0, 1.0]:
		for step in 4:
			var at: Vector3 = encounter_center + axis * side * (3.0 + step * 2.5)
			hazards.circle(at, 1.3, 1.2 + step * 0.18, Vector2i(46, 60), GOLD)
	after(1.0, func() -> void:
		fire_fan(shot_origin(), axis.rotated(Vector3.UP, PI * 0.5), 5, 18.0, _sand(5.0))
		fire_fan(shot_origin(), axis.rotated(Vector3.UP, -PI * 0.5), 5, 18.0, _sand(5.0)))

func _sundial() -> void:
	model.boss_pose("summon", 1.6)
	var gap := atan2(-aim_dir().x, -aim_dir().z)
	mark_ring_gaps(gap, 54.0, 1.0, GOLD)
	after(1.0, func() -> void:
		var attack := Boss.shot("disc", ROSE, Vector2i(38, 50), 5.0, 0.2, 23.0,
			{voxel_model = "boss_projectiles/sun_seal", authored_projectile = true, pixel_projectile = true, turn = 0.08,
				effects = [{id = "dexterity", amount = -10, duration = 2.0}], effect_source = "Gilded Vizier sun seal"})
		fire_ring(shot_origin(), 18 if phase < 2 else 24, attack, gap, 54.0))

func _court() -> void:
	model.boss_pose("summon", 2.5)
	for side in [-1.0, 1.0]:
		for row in [-1.0, 1.0]:
			var helper := spawn_support("tomb_scarab" if row < 0 else "sun_priest",
				encounter_center + Vector3(side * 7.0, 0, row * 5.0), "court", true)
			if helper: arm_summon(helper, 0.2 if row > 0 else 0.0)

func _eclipse() -> void:
	model.boss_pose("channel", 2.2)
	pulse_glow(1.8, 1.0)
	# The orbit stays close to the dais, leaving the outer hall clear.
	hazards.circle(global_position, 5.5, 1.2, Vector2i.ZERO, GOLD, {visual = true})
	after(1.2, func() -> void:
		fire_orbit(encounter_center, 5.5, 10, 4.5, 0.8, 1.0, _sand(), _dial))

func _reset_hook() -> void:
	_dial = 0.0
	model.boss_pose("idle", 0.1)

func _death_started() -> void:
	model.boss_pose("death", boss_def.death_time + 1.0)

func _dying_update(_k: float) -> void:
	model.scale = Vector3.ONE * def.model_scale
