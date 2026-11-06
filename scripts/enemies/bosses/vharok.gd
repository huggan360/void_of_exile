extends Boss
## Vharok, the Cinder Tyrant, Cinder Bastion (lava). A black-armored demon.
##
## 1: planted at the throne, six-arm white spiral every .5 s, frequent fans,
##    wide flame cleaves and brands.
## 2: four symmetric Sentinels; stationary while shielded. Eight small flame
##    shards every .8 s alternate 22.5 degrees throughout the entire phase.
##    Once unshielded, long telegraphed charges cross the larger arena.
## 3: aggressive slams, fans, cleaves and molten crosses.

const FIRE := Color(1.0, 0.42, 0.12)
const HOT := Color(1.0, 0.7, 0.3)
const WARN := Color(1.0, 0.35, 0.15)
const MITE_ALIVE := 4
const MITE_TOTAL := 8

var _shield: MeshInstance3D
var _guarded := false
var _mites_spawned := 0
var _mite_timer := 0.0
var _brand_timer := 0.0
var _charging := false
var _charge_timer := 0.0
var _last_charge_dir := Vector3.ZERO
var _lift := 0.0
var _spiral_timer := 0.0
var _spiral_angle := 0.0
var _shard_timer := 0.0
var _shard_offset := false
var _returning_for_pact := false
var _resting := false
var _summoning := false
var _charge_passage: Array[PhysicsBody3D] = []


## Only the charge ignores player bodies; terrain and structures still stop him.
func _physics_process(delta: float) -> void:
	if not mirror:
		if is_charging():
			for player in players():
				if player is PhysicsBody3D and player not in _charge_passage:
					add_collision_exception_with(player)
					_charge_passage.append(player)
		else:
			_clear_charge_passage()
	super._physics_process(delta)
	if not mirror and not is_charging(): _clear_charge_passage()


func _clear_charge_passage() -> void:
	for body in _charge_passage:
		if is_instance_valid(body): remove_collision_exception_with(body)
	_charge_passage.clear()


func _charge_contact(player, contact: Vector3) -> void:
	# Flatten the shove perpendicular to the charge, never ahead of his feet.
	var direction: Vector3 = _charge.dir
	var side := Vector3(-direction.z,0.0,direction.x)
	var offset: Vector3 = player.global_position-contact
	offset.y = 0.0
	var lateral := side.dot(offset)
	if lateral<0.0 or (absf(lateral)<0.01 and player.get_instance_id()%2==0): side = -side
	player.knockback(side*14.0)
	# Body impact bypasses armor: an unshielded player loses 135–160 HP.
	player.take_damage(float(randi_range(_charge.damage.x,_charge.damage.y)),true,false)


func _phase_started(index: int) -> void:
	hazards.clear()
	behavior = "stationary"
	scripted_move = Vector3.ZERO
	velocity = Vector3.ZERO
	_charging = false
	_returning_for_pact = false
	_resting = false
	_summoning = false
	immune = false
	status_text = ""
	model.position = Vector3.ZERO
	charge_arena_radius = 24.0
	match index:
		0:
			_spiral_timer = 0.0
			_spiral_angle = 0.0
			set_cycle(5.2, [[0.0, _fireball_fan], [1.5, _cleave], [3.4, _brands]])
		1:
			_shard_timer = 0.8
			_shard_offset = false
			# Usually already centered: no artificial trip or recentering pause.
			if Vector2(global_position.x-encounter_center.x,global_position.z-encounter_center.z).length()>0.25:
				_returning_for_pact = true
				immune = true
				status_text = "Returning to the furnace"
			else:
				_start_pact()
		2:
			_drop_shield()
			set_cycle(7.5, [[0.0, _slam], [2.3, _wing_fan], [3.6, _wing_fan], [4.5, _cleave], [5.8, _cross]])


func _combat(delta: float) -> void:
	if _resting or _summoning: return
	match phase:
		0:
			behavior = "stationary"
			_spiral_timer -= delta
			while _spiral_timer<=0.0:
				_spiral_timer += 0.5
				_white_spiral()
		1:
			if _returning_for_pact:
				steer_to(encounter_center,8.0)
				if Vector2(global_position.x-encounter_center.x,global_position.z-encounter_center.z).length()<0.3:
					global_position = encounter_center
					_returning_for_pact = false
					_start_pact()
				return
			_shard_timer -= delta
			while _shard_timer<=0.0:
				_shard_timer += 0.8
				_shard_ring()
			_pact(delta)
		2:
			behavior = "stationary"
			_lift = maxf(0.0, _lift - delta)
			# A deliberate gather and drop, without the old sinusoidal hop.
			model.position.y = 0.45*smoothstep(0.0,1.0,1.0-_lift/1.4) if _lift>0.0 else 0.0


## A real intermission: cancel windups, hazards and airborne shots, then kneel.
func _threshold_reached(next: int) -> void:
	if _resting: return
	_begin_rest(func() -> void: _enter_phase(next))


func _begin_rest(resume: Callable) -> void:
	_resting = true
	immune = true
	behavior = "stationary"
	scripted_move = Vector3.ZERO
	velocity = Vector3.ZERO
	face_override = Vector3.ZERO
	_charge = {}
	_charging = false
	_lift = 0.0
	model.position = Vector3.ZERO
	_scheduled.clear()
	_cycle_events = []
	_volleys.clear()
	set_attacks([])
	hazards.clear()
	# Shots already in the air keep flying; only new attacks stop.
	status_text = "The tyrant gathers his strength"
	model.boss_pose("kneel",3.0)
	after(2.25,func() -> void:
		model.hit_voxels(global_position+Vector3.UP*height()*0.45)
		model.boss_pose("rise",0.75)
		pulse_glow(1.8,0.65))
	after(3.0,func() -> void:
		_resting = false
		immune = false
		status_text = ""
		resume.call())


## Encounter summons materialize first; their first volley is held for two seconds.
func _arm_summon(helper: Enemy, stagger := 0.0) -> void:
	helper.attack_lock = 9999.0
	after(2.0+stagger,func() -> void:
		if not is_instance_valid(helper) or not helper.is_alive(): return
		helper.attack_lock = 0.0
		for i in helper._attack_timers.size():
			helper._attack_timers[i] = helper.attacks[i].cooldown
			helper._windups[i] = 0.0001)


func _white_spiral() -> void:
	var attack := Boss.shot("orb",Color(0.96,0.97,1.0),Vector2i(45,60),8.0,0.16,65.0,
		{size=0.85, authored_projectile=true, voxel_model="boss_projectiles/white_ember",pixel_projectile=true,projectile_glow=0.7})
	for k in 6:
		shoot(shot_origin(),Vector3.FORWARD.rotated(Vector3.UP,_spiral_angle+k*TAU/6.0),attack)
	_spiral_angle = wrapf(_spiral_angle+deg_to_rad(15.0),0.0,TAU)


func _shard_ring() -> void:
	var offset := PI/8.0 if _shard_offset else 0.0
	var attack := Boss.shot("flame_shard",FIRE,Vector2i(55,70),7.5,0.16,65.0,{size=1.0})
	for k in 8:
		shoot(shot_origin(),Vector3.FORWARD.rotated(Vector3.UP,offset+k*TAU/8.0),attack)
	_shard_offset = not _shard_offset


# --- Phase 1 ---------------------------------------------------------------------------

func _fireball_fan() -> void:
	model.boss_pose("cast",0.8)
	pulse_glow(1.8, 0.6)
	after(0.6, func() -> void:
		var heavy := Boss.shot("fireball", Color("ffd578"), Vector2i(70, 85), 7.0, 0.29, 60.0,
			{size = 1.65, effects = [{id = "defense", amount = -8, duration = 2.0}], effect_source = "Vharok searing fireball"})
		fire_fan(shot_origin(), aim_dir(), 5, 15.0,
			Boss.shot("fireball", FIRE, Vector2i(70, 85), 8.0, 0.22, 60.0, {size = 1.3}), heavy))


func _cleave() -> void:
	var dir := aim_dir()
	face_override = dir
	model.boss_pose("cleave_windup",0.8)
	# The 60 degree wedge it will sweep, drawn as three spokes.
	for deg in [-24.0, 0.0, 24.0]:
		var d := dir.rotated(Vector3.UP, deg_to_rad(deg))
		hazards.lane(global_position + d * 5.0, d, 14.0, 0.9, 0.8, 0.0, Vector2i.ZERO, 0.0, WARN)
	after(0.8, func() -> void:
		face_override = Vector3.ZERO
		model.boss_pose("cleave_release",0.5)
		var attack := Boss.shot("crescent", Color(1.0, 0.3, 0.1), Vector2i(90, 105), 6.0, 0.3, 60.0, {size = 1.4, shared_hits = [], pierce_players = true, pierce_shields = true, armor_piercing = true})
		for deg in [-12.0, 12.0]:
			shoot(shot_origin(), dir.rotated(Vector3.UP, deg_to_rad(deg)), attack))


func _brands() -> void:
	var at := target().global_position
	for offset: Vector3 in [Vector3.ZERO, Vector3(2.2, 0, 0.6), Vector3(-1.2, 0, 2.0)]:
		var opts := {}
		if hazards.count("patch") + hazards.count("circle") < 4:
			opts.patch = {time = 3.0, tick = 0.75, damage = Vector2i(20, 25), group = "vharok_patches"}
		hazards.circle(in_arena(at + offset, 23.0), 1.1, 1.2, Vector2i(75, 90), WARN, opts)


# --- Phase 2 -----------------------------------------------------------------------------

func _start_pact() -> void:
	behavior = "stationary"
	scripted_move = Vector3.ZERO
	velocity = Vector3.ZERO
	model.boss_pose("summon",2.0)
	_summoning = true
	_guarded = true
	_mites_spawned = 0
	_mite_timer = 3.0
	_brand_timer = 2.0
	for k in 4:
		var angle := k*TAU/4.0+PI/4.0
		var socket := encounter_center+Vector3(cos(angle),0,sin(angle))*10.0
		var sentinel := spawn_support("cinder_sentinel",socket,"objective",true)
		if sentinel:
			_arm_summon(sentinel,0.08*k)
			_pips.append({enemy=sentinel,color=Color(1.0,0.35,0.2)})
	immune = not support("objective").is_empty()
	_raise_shield()
	status_text = "The Cinder Sentinels awaken"
	after(2.0,func() -> void:
		_summoning = false
		_shard_timer = 0.0
		status_text = "Shielded by the Cinder Sentinels")


func _pact(delta: float) -> void:
	if _guarded:
		if support("objective").is_empty():
			_shield_breaks()
			return
		behavior = "stationary"
		_brand_timer -= delta
		if _brand_timer <= 0.0:
			_brand_timer = 2.8
			var at := target().global_position
			for offset: Vector3 in [Vector3.ZERO, Vector3(1.8, 0, -1.2)]:
				hazards.circle(in_arena(at + offset, 23.0), 1.1, 1.2, Vector2i(70, 85), WARN)
		_mite_timer -= delta
		if _mite_timer <= 0.0:
			_mite_timer = 6.0
			for k in 2:
				if support("add").size() >= MITE_ALIVE or _mites_spawned >= MITE_TOTAL:
					break
				var a := randf() * TAU
				var mite := spawn_support("pact_ember_mite", encounter_center + Vector3(cos(a), 0, sin(a)) * 9.0, "add")
				if mite:
					_arm_summon(mite)
					_mites_spawned += 1
		return
	if _charging:
		return
	_charge_timer -= delta
	if _charge_timer <= 0.0:
		_line_up_charge()


func _shield_breaks() -> void:
	_guarded = false
	_drop_shield()
	despawn_support("add")
	defense = 4
	CameraShake.shake_from(self,global_position,0.5,boss_def.bar_radius)
	_begin_rest(func() -> void:
		defense = 14
		_charge_timer = 0.3)


func _drop_shield() -> void:
	if is_instance_valid(_shield):
		_shield.queue_free()
	_shield = null
	immune = false


func _line_up_charge() -> void:
	_charging = true
	var dir := aim_dir()
	var end := in_arena(global_position + dir * 24.0, 24.0)
	var length := Vector2(end.x - global_position.x, end.z - global_position.z).length()
	if length>0.01: dir = (end-global_position).normalized()
	dir.y = 0.0
	dir = dir.normalized()
	model.boss_pose("charge_windup",0.8)
	_last_charge_dir = dir
	face_override = dir
	hazards.lane(global_position + dir * length * 0.5, dir, maxf(2.0, length), 2.6, 0.8, 0.0, Vector2i.ZERO, 0.0, WARN)
	after(0.8, func() -> void:
		model.boss_pose("charge",length/12.0+0.2)
		start_charge(dir, length, 12.0, Vector2i(135,160), _after_charge))


func _after_charge() -> void:
	behavior = "stationary"
	model.boss_pose("charge_recover",0.7)
	pulse_glow(2.0, 0.6)
	after(0.6, func() -> void:
		fire_fan(shot_origin(), aim_dir(), 3, 14.0, Boss.shot("fireball", HOT, Vector2i(70, 85), 8.0, 0.22, 60.0, {size = 1.2}))
		after(0.7, func() -> void:
			_charging = false
			_charge_timer = 0.2))


# --- Phase 3 ------------------------------------------------------------------------------

func _slam() -> void:
	var land := in_arena(target().global_position, 22.0)
	var spot := clear_point(land, def.hit_radius * def.model_scale)
	if spot == Vector3.INF:
		spot = global_position
	hazards.marker(spot, 2.2, 1.4, WARN)
	_lift = 1.4
	model.boss_pose("slam_windup",1.4)
	after(1.4, func() -> void:
		global_position = Vector3(spot.x, global_position.y, spot.z)
		velocity = Vector3.ZERO
		model.position.y = 0.0
		model.boss_pose("slam_release",0.65)
		var hit: Array = []
		for p in players():
			if Vector2(p.global_position.x - spot.x, p.global_position.z - spot.z).length() < 2.2 + EnemyBullets.PLAYER_RADIUS * 0.6:
				p.take_damage(float(randi_range(95, 110)), false, false)
				hit.append(p)
		# The ring skips anyone the slam itself just hit.
		EnemyRipple.spawn(director.bullets, spot, {radius = 12.0, speed = 6.0, damage_min = 55, damage_max = 65},
				Color(1.0, 0.45, 0.2), director.bullets.players, hit)
		CameraShake.shake_from(self, spot, 0.6, 24.0)
		var pts := PackedVector3Array()
		var cols := PackedColorArray()
		for k in 60:
			var r := Vector2.from_angle(randf() * TAU) * randf() * 2.2
			pts.append(spot + Vector3(r.x, randf() * 0.6, r.y))
			cols.append(Color(0.12, 0.08, 0.1) if k % 3 else FIRE)
		Debris.burst_points(director, pts, cols, 0.16, 60, spot, spot.y, 0.6))


func _wing_fan() -> void:
	model.boss_pose("cast",0.9)
	pulse_glow(2.2, 0.7)
	after(0.7, func() -> void:
		fire_fan(shot_origin(), aim_dir(), 7, 16.0, Boss.shot("fireball", FIRE, Vector2i(50, 65), 7.0, 0.2, 60.0, {size = 1.1})))


func _cross() -> void:
	# Two crossing molten lanes through the throne; four corners stay open.
	var a := randf() * PI
	for k in 2:
		var dir := Vector3.FORWARD.rotated(Vector3.UP, a + k * PI * 0.5)
		hazards.lane(global_position, dir, 46.0, 0.8, 1.2, 1.5, Vector2i(80, 95), 0.8, Color(1.0, 0.5, 0.1), {group = "vharok_cross"})


func _reset_hook() -> void:
	_drop_shield()
	_guarded = false
	_charging = false
	_lift = 0.0
	_returning_for_pact = false
	_resting = false
	_summoning = false
	model.boss_pose("idle",0.1)


func _death_started() -> void:
	_drop_shield()
	model.boss_pose("defeated",boss_def.death_time+1.0)


func _dying_update(_k: float) -> void:
	# Hold the defeated silhouette steady until the final voxel burst.
	model.scale = Vector3.ONE*def.model_scale


## The Cinder Sentinels' bubble of warped heat around it.
func _raise_shield() -> void:
	if is_instance_valid(_shield):
		return
	_shield = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = height() * 0.45
	sphere.height = height() * 0.9
	_shield.mesh = sphere
	_shield.material_override = EnemyRipple.warp_material(Color(1.0, 0.25, 0.15), 0.08)
	_shield.position.y = height() * 0.45
	_shield.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_shield)


func net_visuals() -> Array:
	return [is_instance_valid(_shield)]


func mirror_visuals(extra: Array) -> void:
	var up: bool = not extra.is_empty() and extra[0]
	if up:
		_raise_shield()
	elif is_instance_valid(_shield):
		_drop_shield()
