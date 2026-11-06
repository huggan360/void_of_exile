extends Boss
## Four phases: iron oath, seated court, spellblade, and the last coronation.
const IRON := Color("8e939f")
const MAGIC := Color("e0ccff")
var _court := false
var _returning := false
var _ring_angle := 0.0
const WARNING := Color("ff302d")
const WALL_LEFT := -22.6
const WALL_RIGHT := 23.6
const WALL_SHOT_CAP := 192
var _wall_timer := 2.0
var _wall_step := 0
var _wall_clock := 0.0
var _wall_expiry: Array[float] = []
var _phase_clock := 0.0
var _barrage := false
var _barrage_done := false
var _barrage_step := 0

## The king is already present in the cinematic; never pop in or reset its intro.
func _play_spawn() -> void:
	state = State.IDLE

func _phase_started(index: int) -> void:
	_court = false
	_returning = false
	face_override = Vector3.ZERO
	immune = false
	status_text = ""
	behavior = "chase"
	move_speed = 2.6 + index * 0.35
	_phase_clock = 0.0
	_wall_timer = 0.0 if index == 3 else 2.0
	charge_arena_radius = 24.0
	match index:
		0: set_cycle(9.0, [[0.4, _sword], [2.6, _iron_fan], [4.6, _ring], [6.4, _rush]])
		1, 3:
			_returning = true
			immune = true
			status_text = "The king returns to his throne"
			set_cycle(0.0, [])
		2:
			# Hold the middle threshold so a heavy hit cannot skip the barrage.
			hp_floor = ceili(max_hp * 0.375)
			_spellblade_cycle()

func _threshold_reached(next: int) -> void:
	if resting: return
	director.bullets.clear_owner(encounter_id)
	_wall_expiry.clear()
	begin_rest(func() -> void: _enter_phase(next), "Even iron must draw breath")

func _combat(delta: float) -> void:
	if resting: return
	_wall_clock += delta
	_phase_clock += delta
	if phase == 2 and not _barrage_done and not _barrage and (hp <= hp_floor or _phase_clock >= 12.0):
		_begin_barrage()
	if not _returning and not _barrage:
		_wall_timer -= delta
		if _wall_timer <= 0.0:
			_wall_timer = 5.2 if phase < 2 else 4.4
			if phase == 3:
				_final_sweep()
			else:
				_wall_volley()
	if _returning:
		var throne: Vector3 = director.world.to_global(CastleWorld.THRONE_SEAT)
		steer_to(throne, 6.0)
		if Vector2(global_position.x - throne.x, global_position.z - throne.z).length() < 0.35:
			global_position = throne
			velocity = Vector3.ZERO
			_returning = false
			_court = true
			behavior = "stationary"
			scripted_move = Vector3.ZERO
			face_override = Vector3.BACK
			_facing = PI
			model.rotation.y = PI
			model.boss_pose("sit", 120.0)
			if _barrage:
				status_text = "Iron Barrage - rear half first, then the doorway half"
				after(0.8, _barrage_warning)
				return
			status_text = "Defeat the king's sworn guardians"
			for side in [-1.0, 1.0]:
				var helper := spawn_support("castle_champion" if phase == 3 else "castle_knight",
					Vector3(side * 9, 0, -53), "court", true)
				if helper != null: arm_summon(helper, 0.3)
			set_cycle(4.2, [[1.0, _magic], [3.0, _ring]])
	elif _court and not _barrage and support("court").is_empty():
		_court = false
		immune = false
		status_text = ""
		face_override = Vector3.ZERO
		model.boss_pose("rise", 1.0)
		behavior = "chase"
		set_cycle(9.0, [[0.3, _sword], [1.8, _magic], [3.0, _ring], [4.2, _spiral], [6.4, _rush]])

func _iron_fan() -> void:
	model.boss_pose("cast", 0.65)
	var origin := shot_origin()
	var direction := aim_dir()
	after(0.65, func() -> void:
		fire_fan(origin, direction, 7 if phase == 3 else 5, 13.0,
			_metal(Vector2i(65, 85), 13.0)))

func _sword() -> void:
	model.boss_pose("cleave_windup", 0.9)
	var direction := aim_dir()
	var origin := shot_origin() + direction * 1.8
	behavior = "stationary"
	face_override = direction
	hazards.lane(origin + direction * 12.0, direction, 24.0, 5.6, 0.9, 0.0, Vector2i.ZERO, 0.0, IRON)
	after(0.9, func() -> void:
		model.boss_pose("cleave_release", 0.5)
		var shard := _metal(Vector2i(100, 135), 11.0)
		shard.voxel_model = "boss_projectiles/iron_cleave"
		shard.half_extents = Vector3(2.8, 0.24, 0.7)
		shard.radius = 2.8
		shard.size = 1.0
		shard.effects = [{id = "attack", amount = -8, duration = 2.5}]
		shard.effect_source = "Hollow King dread cleave"
		shoot(origin, direction, shard)
		behavior = "chase"
		face_override = Vector3.ZERO)

func _magic() -> void:
	if not _court: model.boss_pose("cast", 0.7)
	for sense in [-1.0, 1.0]:
		fire_fan(shot_origin(), aim_dir().rotated(Vector3.UP, sense * 0.25), 4, 17.0,
			shot("orb", MAGIC, Vector2i(55, 75), 9.0, 0.18, 36.0,
			{turn = sense * 0.28, voxel_model = "boss_projectiles/king_spell", authored_projectile = true, pixel_projectile = true}))

func _ring() -> void:
	_ring_angle += 0.43
	GameAudio.emit_from("boss_riser", self, {source_id = encounter_id, cooldown = 0.5, max_distance = 64.0, align_end=.8})
	mark_ring_gaps(_ring_angle, 36.0, 0.8, MAGIC)
	after(0.8, func() -> void:
		fire_ring(shot_origin(), 28 if phase == 3 else 22,
			shot("orb", MAGIC, Vector2i(55, 75), 8.0, 0.2, 38.0,
			{voxel_model = "boss_projectiles/king_spell", authored_projectile = true, pixel_projectile = true}), _ring_angle, 36.0))

func _metal(damage: Vector2i, speed: float) -> Dictionary:
	return shot("needle", IRON, damage, speed, 0.2, 38.0,
		{voxel_model = "boss_projectiles/iron_bolt", authored_projectile = true, pixel_projectile = true, projectile_glow = 0.15})

func _death_started() -> void:
	_court = false
	face_override = Vector3.ZERO
	model.boss_pose("kneel", boss_def.death_time + 1.0)

func _dying_update(_k: float) -> void:
	model.scale = Vector3.ONE * def.model_scale

func _reset_hook() -> void:
	_court = false
	_returning = false
	_barrage = false
	_barrage_done = false
	_barrage_step = 0
	_phase_clock = 0.0
	_wall_clock = 0.0
	_wall_expiry.clear()
	_wall_timer = 2.0
	_wall_step = 0
	model.boss_pose("idle", 0.1)


func _spellblade_cycle() -> void:
	set_cycle(10.0, [[0.3, _magic], [2.0, _sword], [3.8, _ring], [5.4, _spiral], [7.6, _rush]])


## A separate wall clock keeps the slits independent of the king's sword.
## Whole six-metre banks stay empty on a rotating rhythm, leaving broad gaps.
func _wall_volley() -> void:
	var lanes: Array[float] = []
	for bank in 8:
		if posmod(bank + _wall_step, 3) != 0: continue
		var z := -75.0 + bank * 6.0
		lanes.append(z)
		_floor_warning(z - 0.8, z + 0.8, 1.0, 2.7, IRON)
	var from_left := _wall_step % 2 == 0
	_wall_step += 1
	after(1.0, func() -> void: _wall_bolts(lanes, from_left, false))
	after(1.35, func() -> void: _wall_bolts(lanes, from_left, false))


## Split at the dais edges so warnings sit on the raised floor as well.
## These are visual hazards only: every damaging hit comes from a real bolt.
func _floor_warning(back: float, front: float, warn: float, active: float, color: Color) -> void:
	var cuts: Array[float] = [back]
	for edge in [-71.0, -69.0]:
		if edge > back and edge < front: cuts.append(edge)
	cuts.append(front)
	for row in cuts.size() - 1:
		var z := (cuts[row] + cuts[row + 1]) * 0.5
		var edges: Array[float] = [-23.0, -9.0, -7.0, 8.0, 10.0, 24.0]
		if z >= -69.0: edges.assign([-23.0, 24.0])
		for col in edges.size() - 1:
			var x := (edges[col] + edges[col + 1]) * 0.5
			hazards.lane(Vector3(x, 0, z), Vector3.RIGHT,
				edges[col + 1] - edges[col], cuts[row + 1] - cuts[row], warn, active,
				Vector2i.ZERO, 0.0, color, {warning_fill = true})


## Bounded volleys, no per-arrow particles or lights. Expiry accounting is
## authority-side too, where EnemyBullets forwards shots instead of storing them.
func _wall_bolts(lanes: Array[float], from_left: bool, dense: bool, speed := 32.0) -> void:
	if resting or state != State.ACTIVE: return
	_wall_expiry = _wall_expiry.filter(func(t: float) -> bool: return t > _wall_clock)
	var attack := _metal(Vector2i(320, 400) if dense else Vector2i(65, 85), speed if dense else 20.0)
	attack.range = 47.0
	attack.radius = 0.22 if dense else 0.18
	attack.pixel_projectile = false
	attack.pierce_players = dense
	var direction := Vector3.RIGHT if from_left else Vector3.LEFT
	for z in lanes:
		# Upper slits cover both steps of the throne dais; lower bolts meet stone.
		for y in [1.0, 2.0, 3.0] if z < -69.0 else [1.0]:
			if _wall_expiry.size() >= WALL_SHOT_CAP: return
			shoot(Vector3(WALL_LEFT if from_left else WALL_RIGHT, y, z), direction, attack)
			_wall_expiry.append(_wall_clock + 47.0 / float(attack.speed) + 0.1)


func _begin_barrage() -> void:
	_barrage = true
	_barrage_step = 0
	_returning = true
	immune = true
	status_text = "Iron Barrage - rear half first, then the doorway half"
	_scheduled.clear()
	_charge = {}
	face_override = Vector3.ZERO
	hazards.clear()
	director.bullets.clear_owner(encounter_id)
	_wall_expiry.clear()
	set_cycle(0.0, [])


func _barrage_warning() -> void:
	# Start with two teaching halves, then shrink the safe corridor every wave.
	if _barrage_step >= 10:
		_end_barrage()
		return
	var safe_width := 24.5 if _barrage_step < 2 else 49.0 / float(_barrage_step + 1)
	var warn := maxf(0.65, 2.0 - _barrage_step * 0.16)
	var speed := 32.0 + _barrage_step * 3.0
	status_text = "Iron Barrage - find the shrinking safe floor"
	_sweep(safe_width, _barrage_step % 2 == 0, warn, speed)
	_barrage_step += 1
	var drain := 0.44 + 47.0 / speed + 0.18
	after(warn + drain + 0.08, _barrage_warning)


## The last coronation runs overlapping warnings alongside the king's spells.
func _final_sweep() -> void:
	_sweep(7.0, _wall_step % 2 == 0, 0.9, 48.0)
	_wall_step += 1
	_wall_timer = 2.4


func _sweep(safe_width: float, from_left: bool, warn: float, speed: float) -> void:
	var back := -78.0 if from_left else -78.0 + safe_width
	var front := -29.0 - safe_width if from_left else -29.0
	var drain := 0.44 + 47.0 / speed + 0.18
	# The warning_fill lanes below are the flashing red telegraph visible in phase 3.
	# Emit once here when that visual warning starts; subsequent lanes are one attack.
	_floor_warning(back, front, warn, drain, WARNING)
	var lanes: Array[float] = []
	var count := ceili((front - back - 1.4) / 0.95) + 1
	for i in count:
		lanes.append(lerpf(back + 0.7, front - 0.7, float(i) / (count - 1)))
	for wave in 3:
		after(warn + wave * 0.22, func() -> void: _wall_bolts(lanes, from_left, true, speed))


func _end_barrage() -> void:
	_court = false
	_returning = false
	hazards.clear()
	model.boss_pose("rise", 1.0)
	status_text = "The king takes up his blade"
	after(1.0, func() -> void:
		_barrage = false
		_barrage_done = true
		immune = false
		hp_floor = 0
		status_text = ""
		face_override = Vector3.ZERO
		behavior = "chase"
		move_speed = 3.3
		_wall_timer = 2.0
		_spellblade_cycle())


func _spiral() -> void:
	model.boss_pose("cast", 1.6)
	pulse_glow(1.2, 0.7)
	var origin := shot_origin()
	var angle := _ring_angle
	for step in 8:
		var offset := angle + step * 0.24
		after(0.7 + step * 0.12, func() -> void:
			for arm in 4:
				shoot(origin, Vector3.FORWARD.rotated(Vector3.UP, offset + arm * TAU / 4.0),
					_metal(Vector2i(60, 80), 10.0)))
	_ring_angle += 0.6


func _rush() -> void:
	var direction := aim_dir()
	var origin := global_position
	behavior = "stationary"
	face_override = direction
	model.boss_pose("cleave_windup", 1.0)
	hazards.lane(origin + direction * 8.0, direction, 16.0, 4.4, 1.0, 0.0, Vector2i.ZERO, 0.0, IRON)
	after(1.0, func() -> void:
		model.boss_pose("cleave_release", 0.8)
		start_charge(direction, 16.0, 14.0, Vector2i(110, 145), func() -> void:
			behavior = "chase"
			move_speed = 2.6 + phase * 0.35))


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if not mirror and _court:
		face_override = Vector3.BACK
		_facing = PI
		model.rotation.y = PI
		if model._boss_pose_left < 2.0:
			model.boss_pose("sit", 120.0)


func net_visuals() -> Array:
	return [_court]


func mirror_visuals(extra: Array) -> void:
	if extra.is_empty(): return
	var seated := bool(extra[0])
	if seated:
		model.rotation.y = PI
		if not _court or model._boss_pose_name != "sit" or model._boss_pose_left < 2.0:
			model.boss_pose("sit", 120.0)
	elif _court:
		model.boss_pose("rise", 1.0)
	_court = seated
