class_name Enemy
extends CharacterBody3D
## One living enemy, driven by its EnemyDef.
##
## States: BURIED (hidden underground until a player comes near; "burrow"
## spawns only), SPAWNING (playing its entrance), IDLE (strolling around its
## pack or leader), ACTIVE (fighting: moving by its behavior and firing its
## attacks), RETURNING (lost the player, heading home), DEAD. Bosses also
## have INTRO and DYING (see Boss).
##
## Enemies notice the player within aggro_radius (or when hit) and alert the
## whole pack; they lose the player quickly once they're out of lose_radius.
##
## How it fights (attacks, behavior, speed, defence) starts out from its def
## but lives on the enemy, so a Boss can change it from phase to phase.
##
## Online, enemies live on the server. It targets the nearest player in its
## realm (target()). On a client the same enemy is a `mirror`: no AI, it
## shows what the server's snapshots and events say (see Net), and hits on it
## are sent to the server.

signal died(enemy: Enemy)

enum State { BURIED, SPAWNING, IDLE, ACTIVE, RETURNING, DEAD, INTRO, DYING }

const GRAVITY := 30.0
const STEP_HEIGHT := 1.05
const TURN_SPEED := 10.0
const IDLE_SPEED := 0.4  # share of move speed while strolling
const MIN_DAMAGE_TAKEN := 0.15
const STRAFE_SWITCH := Vector2(0.8, 2.0)  # seconds between strafe direction changes
const LEADER_LEASH := 6.0  # followers drift back to their leader beyond this
const TOO_CLOSE := 0.5  # share of keep_distance where a skirmisher backs off
const RETREAT_TIME := Vector2(0.5, 1.0)
const RETREAT_SPEED := 1.35  # backing off is a little faster than walking
const SURGE_EVERY := Vector2(3.0, 7.0)  # seconds between dashes in close
const SURGE_TIME := 0.7
const SEPARATION := 1.6  # pack mates closer than this push apart
const MOVE_SMOOTHING := 7.0
const SHED_AT := [0.4, 0.7, 0.9]  # share of hp lost where outer voxels fly off
const SHED_SHARE := 0.12  # share of the outer voxels lost each time
const BURIED_DUST_EVERY := Vector2(2.0, 4.5)  # seconds between telltale dust puffs
const EMERGE_TIME := 0.55
const EMERGE_SHAKE := 0.18
const ORBIT_FOLLOW := 3.0  # how tightly orbiters keep to their circle
const BLINK_PUFF := 18

var def: EnemyDef
var pack: EnemyPack
var director: EnemyDirector
var _stand: Node3D  # the model's tilt on a planet (see _ready)
var buffs := StatusEffects.new()
var _status_flags := {}
var _status_revision := -1

var hp := 1
var max_hp := 1
var state := State.SPAWNING
var model: CreatureModel
## Summoned by a boss: not part of the pack's lasting members.
var is_minion := false
## Where on its circle an orbiter is (radians).
var orbit_angle := 0.0
## Set on a boss and its summons: their shots can be retired together.
var encounter_id := 0
## While > 0 it doesn't attack (a boss's safety window after hatching, a stun).
var attack_lock := 0.0
## behavior "scripted": the encounter steers it (a flat direction, scaled by move_speed).
var scripted_move := Vector3.ZERO
## Faces this flat direction instead of the player while set (a charge).
var face_override := Vector3.ZERO
## Online client copy of a server enemy (see Net): no AI of its own.
var mirror := false
## Its id on the server (0 offline).
var net_id := 0

# How it fights right now (from the def; bosses change these per phase).
var attacks: Array = []
var behavior := "skirmish"
var move_speed := 4.0
var defense := 0

var _home := Vector3.ZERO
var _wander_target := Vector3.ZERO
var _wander_timer := 0.0
var _lose_timer := 0.0
var _strafe := 1.0
var _strafe_timer := 0.0
var _attack_timers: Array[float] = []
var _windups: Array[float] = []  # >0 while an attack is being wound up
var _facing := 0.0
var _visual_offset := 0.0
var _age := 0.0
var _move := Vector3.ZERO  # smoothed fight movement
var _shed := 0  # how many SHED_AT steps have been reached
var _rooted := 0.0  # >0 while standing still to shoot
var _damage_by := {}  # player id -> damage dealt (who gets to roll for loot)
var _dust_timer := 0.0
var _blink_timer := 0.0
var _blink_busy := false
var _torch: OmniLight3D
var _torch_clock := 0.0
var _volleys: Array[Dictionary] = []  # attacks firing over time (bursts, sweeps)
var _target: Node3D
var _target_timer := 0.0
var _mirror_speed := 0.0

# Personality, rolled per enemy so a pack doesn't move as one.
var _pref_dist := 6.0
var _weave := 0.7  # how much it moves side to side
var _pulse_rate := 0.8
var _pulse_phase := 0.0
var _surge_timer := 0.0
var _surge := 0.0  # >0 while dashing in close
var _retreat := 0.0  # >0 while backing off


func setup(p_def: EnemyDef, p_pack: EnemyPack, p_director: EnemyDirector) -> Enemy:
	def = p_def
	pack = p_pack
	director = p_director
	hp = def.hp
	max_hp = def.hp
	behavior = def.behavior
	move_speed = def.move_speed
	defense = def.defense
	set_attacks(def.attacks)
	if not def.blink.is_empty():
		_blink_timer = randf_range(def.blink.every[0], def.blink.every[1])
	_pref_dist = def.keep_distance * randf_range(0.8, 1.25)
	_weave = randf_range(0.4, 1.2)
	_pulse_rate = randf_range(0.5, 1.1)
	_pulse_phase = randf() * TAU
	_surge_timer = randf_range(SURGE_EVERY.x, SURGE_EVERY.y)
	return self


func _ready() -> void:
	buffs.burning_immune = self is Boss or def is BossDef
	if not Net.is_server():
		var burning := BurningVisuals.new()
		burning.effects = buffs
		burning.character_height = height()
		burning.show_icon = true
		add_child(burning)
	add_to_group("realm_creatures")
	var target_flag := TargetFlag.new()
	target_flag.name = "TurretTarget"
	target_flag.position = Vector3.UP*height()*0.5
	add_child(target_flag)
	if Net.is_server():
		net_id = Net.server.register_enemy(self)
	collision_layer = Player.ENEMY_LAYER
	collision_mask = Player.TERRAIN_LAYER | Player.OBSTACLE_LAYER
	floor_snap_length = STEP_HEIGHT + 0.05
	model = CreatureModel.new(def.model)
	model.scale = Vector3.ONE * def.model_scale
	if director != null and director.world is SpaceWorld and not Net.is_server():
		# On a planet the body keeps the realm's +Y (combat), but the model
		# stands straight out from the planet's centre at its own feet.
		_stand = Node3D.new()
		_stand.name = "Stand"
		add_child(_stand)
		_stand.add_child(model)
	else:
		add_child(model)
	if Net.is_server():
		model.recorder = func(method: StringName, args: Array) -> void: Net.server.model_call(self, method, args)
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = def.hit_radius * def.model_scale
	# Never shorter than the height shots fly at, or they sail over small creatures.
	capsule.height = maxf(maxf(capsule.radius * 2.0, height()), Player.SHOT_HEIGHT + 0.35)
	shape.shape = capsule
	shape.position.y = capsule.height * 0.5
	add_child(shape)
	_home = global_position
	_wander_target = _home
	_facing = randf() * TAU
	if def.carries_torch:
		_torch = OmniLight3D.new()
		_torch.name = "PatrolTorch"
		_torch.light_color = Color(1.0,.53,.22)
		_torch.omni_range = 7.0
		_torch.omni_attenuation = 1.2
		_torch.light_energy = 1.7
		_torch.shadow_enabled = false
		_torch.light_volumetric_fog_energy = .35
		_torch.distance_fade_enabled = true
		_torch.distance_fade_begin = 35
		_torch.distance_fade_length = 15
		add_child(_torch)
	if mirror:
		state = State.IDLE
		return  # the server's snapshots drive the entrance
	_play_spawn()


func _process(delta: float) -> void:
	if is_instance_valid(_stand):
		var up := (director.world as SpaceWorld).surface_frame(global_position).basis.y.normalized()
		_stand.basis = Basis(Quaternion(Vector3.UP, up)) if up.dot(Vector3.UP) < 0.99999 else Basis.IDENTITY
	if not Net.is_server() and buffs.revision != _status_revision:
		_sync_status_badges()
	if _torch!=null and is_instance_valid(model):
		_torch_clock += delta
		_torch.global_position = model.hand_position()+Vector3.UP*.08
		_torch.light_energy = 1.7*(1.0+.08*sin(_torch_clock*8.3)+.04*sin(_torch_clock*17.1))


## Flags are built only for active effects, keeping large packs inexpensive.
func _sync_status_badges() -> void:
	_status_revision = buffs.revision
	var active := buffs.active()
	var live := {}
	for i in active.size():
		var effect: Dictionary = active[i]
		live[effect.key] = true
		var flag: Sprite3D = _status_flags.get(effect.key)
		if flag == null:
			flag = Sprite3D.new()
			flag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			flag.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
			flag.pixel_size = 0.025
			flag.shaded = false
			add_child(flag)
			_status_flags[effect.key] = flag
		var row: int = i / 4
		var count := mini(4, active.size() - row * 4)
		flag.position = Vector3((i % 4 - (count - 1) * 0.5) * 0.46, height() + 0.45 + row * 0.45, 0)
		flag.texture = BuffArt.badge(effect)
	for key in _status_flags.keys():
		if live.has(key): continue
		_status_flags[key].queue_free()
		_status_flags.erase(key)


## Switches to another set of attacks (each fires on its own timer).
func set_attacks(list: Array) -> void:
	attacks = list
	_attack_timers.clear()
	_windups.clear()
	for a in attacks:
		_attack_timers.append(randf_range(0.3, a.cooldown))  # don't all fire at once
		_windups.append(-1.0)


## Rough height of the creature in meters (for hit boxes and damage numbers).
func height() -> float:
	return def.body_height * def.model_scale


func is_alive() -> bool:
	return state != State.DEAD


func activate() -> void:
	if state == State.BURIED:
		_emerge()
	elif state == State.IDLE or state == State.RETURNING:
		state = State.ACTIVE
		_lose_timer = 0.0


## The player it's after: the nearest one in its world (re-picked a few
## times a second, so it doesn't flip every frame between two players).
func target() -> Node3D:
	if director == null:
		return null
	if _target_timer <= 0.0 or not is_instance_valid(_target):
		_target_timer = 0.3
		_target = director.target_for(global_position)
	return _target


func _physics_process(delta: float) -> void:
	if not FrameTrace.enabled:
		_physics_step(delta)
		return
	var started := Time.get_ticks_usec()
	_physics_step(delta)
	FrameTrace.record("enemies/move", started)


func _physics_step(delta: float) -> void:
	if not mirror and _tick_burning(delta): return
	buffs.tick()
	if mirror:
		mirror_update(delta)
		return
	_target_timer -= delta
	if state == State.BURIED:
		_buried(delta)
		return
	if state == State.SPAWNING or state == State.DEAD:
		return
	if _blink_busy:
		model.animate(0.0, delta)
		return
	_age += delta
	var player := target()
	if player == null:
		model.animate(0.0, delta)
		return
	var theory := director.world as TheoryWorld
	if theory!=null:
		global_basis = theory.surface_frame(global_position).basis
		up_direction = global_basis.y
	var to_player := player.global_position - global_position
	if theory!=null: to_player = global_basis.inverse()*to_player
	to_player.y = 0.0
	var dist := to_player.length()
	var move := Vector3.ZERO
	var speed := maxf(0.0, move_speed + buffs.additive("speed", move_speed))

	match state:
		State.IDLE:
			if _notices(dist) and not player.frozen:
				pack.alert()
			if pack.patrol!=null:
				move = pack.patrol.direction(self,delta)
				speed *= .65
			elif behavior == "orbit" and _orbit_center():
				move = _orbit_move(delta)
			else:
				move = _wander(delta)
				speed *= IDLE_SPEED
		State.RETURNING:
			var home := _anchor()
			var back := home - global_position
			if theory!=null: back = global_basis.inverse()*back
			back.y = 0.0
			if back.length() < 1.5:
				state = State.IDLE
			move = back.normalized()
			if dist < def.aggro_radius * 0.7:
				pack.alert()
		State.ACTIVE:
			if dist > def.lose_radius:
				_lose_timer += delta
				if _lose_timer > def.lose_time:
					state = State.RETURNING
			else:
				_lose_timer = 0.0
			move = _fight_move(to_player, dist, delta)
			attack_lock = maxf(0.0, attack_lock - delta)
			if attack_lock <= 0.0 and not buffs.has_effect("static") and not buffs.has_effect("quiet"):
				_update_attacks(delta, dist)
				_update_volleys(delta)
			if not buffs.has_effect("static"): _update_blink(delta, to_player)
			_rooted = maxf(0.0, _rooted - delta)
			if _rooted > 0.0:
				move = Vector3.ZERO
				_move = Vector3.ZERO

	if buffs.has_effect("static"):
		move = Vector3.ZERO
		_move = Vector3.ZERO
	var dy := 0.0
	if theory!=null:
		var previous := global_position
		theory.move_theory_enemy(self,move,speed,delta)
		dy = (global_position-previous).dot(up_direction)
	else:
		velocity.x = move.x * speed
		velocity.z = move.z * speed
		var ahead := global_position + Vector3(velocity.x, 0, velocity.z).normalized() * 0.6
		var t_checks := Time.get_ticks_usec() if FrameTrace.enabled else 0
		var blocked: bool = not director.world.is_walkable(ahead) or director.world.is_hazard(ahead) \
				or (director.world.has_method("enemy_blocked") and director.world.enemy_blocked(ahead)) \
				or (director.world.has_method("enemy_step_blocked") and director.world.enemy_step_blocked(global_position, ahead))
		if FrameTrace.enabled: FrameTrace.record("enemies/ground_checks", t_checks)
		if blocked:
			velocity.x = 0.0
			velocity.z = 0.0
			_wander_timer = 0.0  # pick somewhere else
			_strafe = -_strafe
		velocity.y = 0.0 if is_on_floor() else velocity.y - GRAVITY * delta
		var prev_y := global_position.y
		var t_slide := Time.get_ticks_usec() if FrameTrace.enabled else 0
		move_and_slide()
		if FrameTrace.enabled: FrameTrace.record("enemies/slide", t_slide)
		# Worlds without walkable collision everywhere (planets on the server) hold their enemies to the ground.
		if director.world.has_method("hold_enemy"): director.world.hold_enemy(self)
		if move != Vector3.ZERO and is_on_floor() and is_on_wall():
			_try_step_up(move)
		dy = global_position.y - prev_y
	if absf(dy) > 0.25:
		_visual_offset -= dy
	_visual_offset = lerpf(_visual_offset, 0.0, minf(1.0, delta * 12.0))
	model.position.y = _visual_offset

	# Face the player while fighting, otherwise the way it walks.
	var look := to_player if state == State.ACTIVE else move
	if face_override != Vector3.ZERO:
		look = face_override
	if look.length() > 0.01:
		_facing = lerp_angle(_facing, atan2(-look.x, -look.z), minf(1.0, delta * TURN_SPEED))
	model.rotation.y = _facing
	model.animate(Vector2(velocity.x, velocity.z).length() / maxf(0.1, move_speed), delta)
	if def.is_god:
		var glow := 0.0
		for i in _windups.size():
			if _windups[i] > 0.0:
				glow = maxf(glow, 1.0 - _windups[i] / maxf(0.01, attacks[i].get("windup", 0.4)))
		model.set_glow(glow * 0.8)


## Whether it spots the player at this distance (bosses may only wake when hit).
func _notices(dist: float) -> bool:
	return dist < def.aggro_radius


# --- Movement ---------------------------------------------------------------------

## Where this enemy hangs around: its leader if it follows one, else home.
func _anchor() -> Vector3:
	if def.follows_leader and pack.leader and pack.leader != self and pack.leader.is_alive():
		return pack.leader.global_position
	return _home


func _wander(delta: float) -> Vector3:
	_wander_timer -= delta
	var anchor := _anchor()
	if _wander_timer <= 0.0 or global_position.distance_to(_wander_target) < 0.6:
		_wander_timer = randf_range(2.0, 4.5)
		var r := randf() * def.wander_radius
		_wander_target = anchor + Vector3.FORWARD.rotated(Vector3.UP, randf() * TAU) * r
		if randf() < 0.35:
			_wander_target = global_position  # sometimes just stand around
	var to := _wander_target - global_position
	to.y = 0.0
	return to.normalized() if to.length() > 0.5 else Vector3.ZERO


func _fight_move(to_player: Vector3, dist: float, delta: float) -> Vector3:
	var toward := to_player.normalized()
	var move := Vector3.ZERO
	match behavior:
		"stationary":
			return Vector3.ZERO
		"scripted":
			_move = scripted_move
			return scripted_move
		"orbit":
			if _orbit_center():
				return _orbit_move(delta)
			move = _skirmish_move(toward, dist, delta)
		"strafe":
			move = _strafe_move(toward, dist, delta)
		"spirit":
			move = _skirmish_move(toward, dist, delta, 2.2)
		"chase":
			move = toward
		"dart":
			_strafe_timer -= delta
			if _strafe_timer <= 0.0:
				_strafe_timer = randf_range(0.35, 0.8)
				_wander_target = Vector3.FORWARD.rotated(Vector3.UP, randf() * TAU) + toward * 0.6
			move = _wander_target.normalized()
		_:  # "skirmish"
			move = _skirmish_move(toward, dist, delta)
	# Followers don't wander too far from their leader, even in a fight.
	if def.follows_leader and pack.leader and pack.leader != self and pack.leader.is_alive():
		var to_leader := pack.leader.global_position - global_position
		if director.world is TheoryWorld: to_leader = global_basis.inverse()*to_leader
		to_leader.y = 0.0
		if to_leader.length() > LEADER_LEASH:
			move = (move + to_leader.normalized() * 0.8).normalized()
	if def.leash > 0.0:
		var to_home := _home - global_position
		if director.world is TheoryWorld: to_home = global_basis.inverse()*to_home
		to_home.y = 0.0
		if to_home.length() > def.leash:
			move = (move + to_home.normalized() * 1.2).normalized()
	move += _separation()
	if move.length() > RETREAT_SPEED:
		move = move.normalized() * RETREAT_SPEED
	_move = _move.lerp(move, minf(1.0, delta * MOVE_SMOOTHING))
	return _move


## Weaves side to side around a distance that breathes in and out, now and
## then dashes in close, and backs off quickly when the player gets too near.
## weave_boost: how much harder it moves sideways (spirits: a lot).
func _skirmish_move(toward: Vector3, dist: float, delta: float, weave_boost := 1.0) -> Vector3:
	_strafe_timer -= delta
	if _strafe_timer <= 0.0:
		_strafe_timer = randf_range(STRAFE_SWITCH.x, STRAFE_SWITCH.y) / weave_boost
		_strafe = -_strafe if randf() < 0.6 else _strafe
	_surge_timer -= delta
	if _surge_timer <= 0.0:
		_surge_timer = randf_range(SURGE_EVERY.x, SURGE_EVERY.y)
		_surge = SURGE_TIME
	_surge = maxf(0.0, _surge - delta)
	_retreat = maxf(0.0, _retreat - delta)

	var too_close := def.keep_distance * TOO_CLOSE
	if dist < too_close and _retreat <= 0.0:
		_retreat = randf_range(RETREAT_TIME.x, RETREAT_TIME.y)
		_surge = 0.0
		_strafe = -_strafe if randf() < 0.5 else _strafe

	var side := toward.cross(Vector3.UP) * _strafe
	if _retreat > 0.0:
		return -toward * RETREAT_SPEED + side * _weave * 0.5

	var want := _pref_dist + sin(_age * _pulse_rate + _pulse_phase) * 1.8
	if _surge > 0.0:
		want = too_close + 0.8
	var radial := clampf((dist - want) / 2.0, -1.0, 1.0)
	# The sideways weave swells and fades so it isn't a steady orbit.
	var weave := _weave * (0.55 + 0.45 * sin(_age * 2.3 + _pulse_phase * 3.0)) * weave_boost
	return toward * radial * (1.0 / weave_boost if weave_boost > 1.0 else 1.0) + side * weave


## Sweeps from side to side in front of the player, keeping its distance.
func _strafe_move(toward: Vector3, dist: float, delta: float) -> Vector3:
	_strafe_timer -= delta
	if _strafe_timer <= 0.0:
		_strafe_timer = randf_range(0.8, 1.6)
		_strafe = -_strafe
	var radial := clampf((dist - _pref_dist) / 3.0, -1.0, 1.0) * 0.4
	return toward * radial + toward.cross(Vector3.UP) * _strafe


## What an orbiter circles: its pack leader (a spirit, a boss), if alive.
func _orbit_center() -> Enemy:
	var leader := pack.leader
	if leader and leader != self and is_instance_valid(leader) and leader.is_alive():
		return leader
	return null


## Keeps to its place on a circle around the leader, going round.
func _orbit_move(delta: float) -> Vector3:
	orbit_angle = wrapf(orbit_angle + def.orbit_speed * delta, 0.0, TAU)
	var spot := _orbit_center().global_position + Vector3(cos(orbit_angle), 0.0, sin(orbit_angle)) * def.orbit_radius
	var to := spot - global_position
	to.y = 0.0
	var follow := to * ORBIT_FOLLOW / maxf(0.1, move_speed)
	_move = follow.limit_length(1.6)
	return _move


## A readable squash/dissolve, short transfer, and voxel reassembly.
func _update_blink(delta: float, to_player: Vector3) -> void:
	if def.blink.is_empty() or _blink_busy:
		return
	_blink_timer -= delta
	if _blink_timer > 0.0:
		return
	# Finish a volley or windup instead of teleporting halfway through a shot.
	if _rooted > 0.0 or not _volleys.is_empty() or _windups.any(func(t: float) -> bool: return t > 0.0):
		return
	_blink_timer = randf_range(def.blink.every[0], def.blink.every[1])
	var side := to_player.normalized().cross(Vector3.UP) * (1.0 if randf() < 0.5 else -1.0)
	for flip in [1.0, -1.0]:
		var spot: Vector3 = global_position + side * flip * def.blink.distance
		spot.y = director.world.ground_height(spot.x, spot.z)
		if director.world.is_walkable(spot) and not director.world.is_hazard(spot) \
				and not test_move(global_transform, spot - global_position):
			_start_blink(spot)
			return


func _start_blink(spot: Vector3) -> void:
	_blink_busy = true
	velocity = Vector3.ZERO
	var pts := model.voxel_points()
	var from := global_position
	var center := from + Vector3.UP * height() * 0.5
	var original_scale := model.scale
	BlinkVoxels.spawn(director, pts[0], pts[1], center, model.voxel_size())
	var tween := create_tween()
	tween.tween_property(model, "scale", original_scale * Vector3(0.15, 1.2, 0.15), 0.14).set_trans(Tween.TRANS_QUAD)
	tween.tween_callback(func() -> void:
		if not is_alive():
			return
		global_position = spot
		var arrival: PackedVector3Array = pts[0].duplicate()
		for i in arrival.size():
			arrival[i] += spot - from
		BlinkVoxels.spawn(director, arrival, pts[1], center + spot - from, model.voxel_size(), true)
		_strafe = -_strafe)
	tween.tween_property(model, "scale", original_scale, 0.20).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func() -> void: _blink_busy = false)


## A gentle push away from pack mates that are too close, so they don't stack.
func _separation() -> Vector3:
	var push := Vector3.ZERO
	for m in pack.members:
		if m == self or not is_instance_valid(m) or not m.is_alive():
			continue
		var away := global_position - m.global_position
		if director.world is TheoryWorld: away = global_basis.inverse()*away
		away.y = 0.0
		var d := away.length()
		if d < SEPARATION and d > 0.01:
			push += away / d * (1.0 - d / SEPARATION)
	return push


func _try_step_up(dir: Vector3) -> void:
	var up := Vector3(0, STEP_HEIGHT, 0)
	if test_move(global_transform, up):
		return
	if test_move(global_transform.translated(up), dir.normalized() * 0.3):
		return
	global_position += up


# --- Attacks ----------------------------------------------------------------------

func _update_attacks(delta: float, dist: float) -> void:
	for i in attacks.size():
		var a: Dictionary = attacks[i]
		if _windups[i] > 0.0:
			_windups[i] -= delta
			if _windups[i] <= 0.0:
				_fire(a)
			continue
		_attack_timers[i] -= delta
		if _attack_timers[i] <= 0.0 and dist < a.range * 0.95:
			_attack_timers[i] = a.cooldown * randf_range(0.85, 1.2)
			_windups[i] = a.get("windup", 0.0) + 0.0001
			model.play_attack(a.get("windup", 0.0))
			if a.get("root", false):
				_rooted = maxf(_rooted, _windups[i] + a.get("recover", 0.35))


func _fire(a: Dictionary) -> void:
	model.strike()
	if a.get("anim", "") == "flap":
		model.flap()
	var aim := _aim(a)
	var origin: Vector3 = aim[0]
	var dir: Vector3 = aim[1]
	var shot_y: float = aim[2]
	var count: int = a.get("count", 1)
	match a.get("pattern", "aimed"):
		"cross":
			# Two to the sides and two forward: weaving side to side, the
			# side shots sweep right across the space in front of it.
			var fwd := deg_to_rad(a.get("spread_deg", 8.0))
			for angle in [PI * 0.5, -PI * 0.5, fwd, -fwd]:
				director.bullets.fire(origin, dir.rotated(up_direction, angle), a, self, shot_y)
		"burst", "sweep":
			_volleys.append({attack = a, left = count, timer = 0.0, t = 0.0,
					side = 1.0 if randf() < 0.5 else -1.0, base = dir})
		"summon":
			# Calls workers or minions to its side, up to `max` of them at once.
			var kind := str(a.get("minion", ""))
			var alive := pack.members.filter(func(m: Enemy) -> bool: return is_instance_valid(m) and m.is_alive() and m.def.id == kind).size()
			for k in mini(count, int(a.get("max", 4)) - alive):
				director.spawn_minion(kind, global_position + Vector3.FORWARD.rotated(Vector3.UP, randf() * TAU) * 2.5, pack)
		"shockwave":
			EnemyRipple.spawn(director.bullets, global_position, a.ripple, a.get("color", Color.WHITE),
					director.bullets.players, [])
			CameraShake.shake_from(self, global_position, a.get("shake", 0.35), 22.0)
		"ring":
			for k in count:
				director.bullets.fire(origin, dir.rotated(up_direction, TAU * k / count), a, self, shot_y)
		"spread":
			var step := deg_to_rad(a.get("spread_deg", 12.0))
			for k in count:
				director.bullets.fire(origin, dir.rotated(up_direction, (k - (count - 1) * 0.5) * step), a, self, shot_y)
		_:
			director.bullets.fire(origin, dir, a, self, shot_y)


## [origin, flat direction to the player, shot height] for an attack.
func _aim(a: Dictionary) -> Array:
	if director.world is TheoryWorld and director.world.zone_at(global_position) in ["space","fracture"]:
		var magnetic_origin := model.hand_position() if a.get("from_hand",false) else global_position+up_direction*Player.SHOT_HEIGHT
		var victim := target()
		var aim_at := victim.global_position+victim.global_basis.y*Player.SHOT_HEIGHT
		return [magnetic_origin,(aim_at-magnetic_origin).normalized(),magnetic_origin.y]
	var origin := model.hand_position()
	var shot_y := global_position.y + Player.SHOT_HEIGHT
	if not a.get("from_hand", false):
		origin.y = shot_y
	var dir := target().global_position - origin
	dir.y = 0.0
	return [origin, dir.normalized(), shot_y]


## Attacks that fire over time: a burst re-aims each shot; a sweep fans its
## shots across an arc, from one side to the other, like a line of fire.
func _update_volleys(delta: float) -> void:
	for i in range(_volleys.size() - 1, -1, -1):
		var v: Dictionary = _volleys[i]
		var a: Dictionary = v.attack
		v.timer -= delta
		v.t += delta
		while v.timer <= 0.0 and v.left > 0:
			var aim := _aim(a)
			var dir: Vector3 = aim[1]
			if a.pattern == "sweep":
				var total: int = a.get("count", 1)
				var k := 1.0 - float(v.left - 1) / maxf(1.0, total - 1)
				var arc := deg_to_rad(a.get("arc_deg", 100.0))
				dir = (v.base as Vector3).rotated(up_direction, (k - 0.5) * arc * v.side)
			director.bullets.fire(aim[0], dir, a, self, aim[2])
			v.left -= 1
			v.timer += a.get("interval", 0.1)
		if v.left <= 0:
			_volleys.remove_at(i)


# --- Taking damage ------------------------------------------------------------------

## Called by arrows, rings and anything else that hurts it. source: the
## player who did it (null = the local player; for now every shot is theirs).
func take_hit(_hit_position: Vector3, direction: Vector3, damage := 10, source: Node = null) -> void:
	if mirror:
		Net.client.hit_enemy(self, damage, direction)
		return
	if buffs.has_effect("invincible"): return
	if state == State.DEAD or state == State.SPAWNING or state == State.BURIED:
		return
	var dealt := maxi(int(ceil(damage * MIN_DAMAGE_TAKEN)), damage - (0 if buffs.has_effect("armour_broken") else defense))
	var by := hitter_id(source)
	_damage_by[by] = _damage_by.get(by, 0) + mini(dealt, hp)
	hp -= dealt
	if hp > 0:
		GameAudio.emit_from("enemy_hurt", self, {source_id = get_instance_id(), cooldown = 0.12, max_distance = 40.0})
	FloatingText.spawn(director, global_position + Vector3.UP * (height() + 0.3), "-%d" % dealt, FloatingText.ENEMY_DAMAGE)
	model.flinch()
	velocity += direction * 2.0  # a small knock
	pack.alert()
	if hp <= 0:
		_die()
		return
	var lost := 1.0 - float(hp) / max_hp
	while def.sheds and _shed < SHED_AT.size() and lost >= SHED_AT[_shed]:
		_shed += 1
		_shed_voxels()


## Shared weapon/ring impact path. Online effects are derived from equipped
## items on the server; clients never submit arbitrary effect dictionaries.
func receive_weapon_hit(at: Vector3, direction: Vector3, damage: int, item: Item, secondary := false, source: Node = null) -> void:
	if mirror:
		Net.client.hit_enemy(self, damage, direction, item.id, secondary)
		return
	if self is Boss: (self as Boss).sync_protection()
	var before := hp
	take_hit(at, direction, damage, source)
	if hp >= before or state in [State.DEAD, State.DYING, State.INTRO]: return
	for effect: Dictionary in item.attack_effects(secondary):
		var duration := float(effect.get("duration", 0.0))
		if StatusEffects.canonical(str(effect.id)) == "burning" and director.world.is_water(global_position): continue
		# Bosses can be controlled briefly, with a recovery window between freezes.
		if self is Boss and StatusEffects.canonical(str(effect.id)) in ["static", "quiet"]:
			if Net.now() < _control_ready: continue
			duration = minf(duration, 0.8)
			_control_ready = Net.now() + duration + 4.0
		if buffs.add(str(effect.id), duration, effect.get("amount", 1), item.id) and StatusEffects.canonical(str(effect.id)) == "burning":
			_burn_by = hitter_id(source)

var _control_ready := 0.0
var _burn_by := 0
var _environment_timer := 0.0

## Fire ignores defence. Only authority ticks it; bosses never enter this path.
## Preserve the igniting player's kill credit when the last tick kills.
func _tick_burning(delta: float) -> bool:
	if buffs.burning_immune or state in [State.DEAD,State.SPAWNING,State.BURIED]: return false
	_environment_timer -= delta
	if _environment_timer<=0.0:
		_environment_timer = 0.15
		if is_instance_valid(director) and is_instance_valid(director.world):
			director.world.update_burning_contact(buffs,global_position)
	var damage := buffs.burning_damage(delta)
	if damage<=0 or buffs.has_effect("invincible"): return false
	_damage_by[_burn_by] = _damage_by.get(_burn_by,0)+mini(damage,hp)
	hp = maxi(0,hp-damage)
	FloatingText.spawn(director,global_position+Vector3.UP*(height()+0.3),"-%d" % damage,Color("ff9b45"))
	if pack != null: pack.alert()
	if hp<=0:
		_die()
		return true
	return false


## Who landed a hit: the player who sent it (online), else the local one.
func hitter_id(source: Node) -> int:
	if source != null and "player_id" in source:
		return source.player_id
	var p := target()
	return p.player_id if p != null and "player_id" in p else 0


## Bits of its outer shell fly off as it gets worn down.
func _shed_voxels() -> void:
	var pts := model.shed_outer_voxels(SHED_SHARE)
	Debris.burst_points(director, pts[0], pts[1], model.voxel_size(), pts[0].size(),
			global_position + Vector3.UP * height() * 0.45, global_position.y, 0.6)


func _die() -> void:
	state = State.DEAD
	GameAudio.emit_from(GameAudio.enemy_death_event(def, self), self, {cooldown = 0.08, max_distance = 52.0})
	var pts := model.voxel_points()
	Debris.burst_points(director, pts[0], pts[1], model.voxel_size(), 400,
			global_position + Vector3.UP * height() * 0.4, global_position.y)
	# The server rolls the loot and drops the XP.
	GameServer.enemy_killed(director.realm_id, def, global_position, _damage_by,
			_potion_stats())
	died.emit(self)
	queue_free()


## Leaves without dying: no loot, no XP, no kill (a boss's summons when the
## fight ends, resets or moves on). Dissolves into its own voxels.
func despawn() -> void:
	if state == State.DEAD:
		return
	state = State.DEAD
	collision_layer = 0
	if is_inside_tree() and model:
		var pts := model.voxel_points(200)
		BlinkVoxels.spawn(director, pts[0], pts[1], global_position + Vector3.UP * height() * 0.5, model.voxel_size())
	died.emit(self)
	queue_free()


# --- Spawning -----------------------------------------------------------------------

func _play_spawn() -> void:
	if def.spawn_anim == "burrow":
		_bury()
		return
	state = State.SPAWNING
	var tw := create_tween()
	match def.spawn_anim:
		"summon":
			model.position.y = -height()-0.1
			_dirt_puff(def.dust_color,48,0.9*def.model_scale,0.65)
			Boss.flash_light(director,global_position+Vector3.UP*0.5,def.dust_color,2.0,4.0,0.8)
			tw.tween_property(model,"position:y",0.0,0.85).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		"rise":
			# Claws up out of the ground, kicking up dirt.
			model.position.y = -height() - 0.2
			_dirt_puff(def.dust_color)
			tw.tween_property(model, "position:y", 0.0, 1.0).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_:
			# Pops into existence in a little puff.
			model.scale = Vector3.ONE * 0.01
			_dirt_puff(Color(0.85, 0.85, 0.8))
			tw.tween_property(model, "scale", Vector3.ONE * def.model_scale * 1.15, 0.22).set_trans(Tween.TRANS_BACK)
			tw.tween_property(model, "scale", Vector3.ONE * def.model_scale, 0.12)
	tw.tween_callback(func() -> void: state = State.IDLE)


## Hides under the ground: invisible and untouchable until a player comes near.
func _bury() -> void:
	state = State.BURIED
	model.visible = false
	collision_layer = 0
	_dust_timer = randf_range(0.5, BURIED_DUST_EVERY.y)


func _buried(delta: float) -> void:
	var player := target()
	if player == null:
		return
	var flat := Vector2(player.global_position.x - global_position.x, player.global_position.z - global_position.z)
	if flat.length() < def.aggro_radius and not player.frozen:
		pack.alert()  # wakes the whole pack, this one included (see activate)
		return
	# A little sand stirs now and then where it lies.
	_dust_timer -= delta
	if _dust_timer <= 0.0:
		_dust_timer = randf_range(BURIED_DUST_EVERY.x, BURIED_DUST_EVERY.y)
		_dirt_puff(def.dust_color, 5, 0.6 * def.model_scale)


## Bursts up out of the ground in a spray of sand, straight into the fight.
func _emerge() -> void:
	state = State.SPAWNING
	model.visible = true
	collision_layer = Player.ENEMY_LAYER
	model.position.y = -height() * 0.9
	_dirt_puff(def.dust_color, 70, 1.4 * def.model_scale, 1.2)
	CameraShake.shake_from(self, global_position, EMERGE_SHAKE, 12.0)
	var tw := create_tween()
	tw.tween_property(model, "position:y", 0.25, EMERGE_TIME * 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(model, "position:y", 0.0, EMERGE_TIME * 0.4).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void:
		state = State.ACTIVE
		_lose_timer = 0.0)


func _dirt_puff(color: Color, count := 14, spread := 0.5, life_scale := 0.5) -> void:
	var pts := PackedVector3Array()
	var cols := PackedColorArray()
	for i in count:
		var r := Vector2.from_angle(randf() * TAU) * sqrt(randf()) * spread
		pts.append(global_position + Vector3(r.x, 0.1, r.y))
		cols.append(color.darkened(randf() * 0.3).lightened(randf() * 0.1))
	Debris.burst_points(director, pts, cols, 0.12, count, global_position, global_position.y, life_scale)


func _potion_stats() -> Variant:
	if not def.god_potion_stats.is_empty():
		return def.god_potion_stats
	var biome := director.world.biome_at(pack.site.pos)
	return biome.god_stats if not biome.god_stats.is_empty() else biome.god_stat


# --- Online mirror (client) ----------------------------------------------------------

## Shows the server's state for this enemy, interpolated (see Net).
func mirror_update(delta: float) -> void:
	if not is_instance_valid(Net.client): return
	var s: Dictionary = Net.client.enemy_state(net_id)
	if s.is_empty():
		return
	var before := global_position
	global_position = s.pos
	if director!=null and director.world is TheoryWorld:
		global_basis = (director.world as TheoryWorld).surface_frame(global_position).basis
		up_direction = global_basis.y
	if delta > 0.0:
		var moved := Vector2(global_position.x - before.x, global_position.z - before.z).length() / delta
		_mirror_speed = lerpf(_mirror_speed, moved, minf(1.0, delta * 10.0))
	state = s.state
	hp = s.hp
	model.rotation.y = s.rot
	model.scale = s.scale
	model.position.y = s.model_y
	model.visible = s.visible
	model.set_glow(s.glow)
	collision_layer = Player.ENEMY_LAYER if s.solid else 0
	model.animate(_mirror_speed / maxf(0.1, move_speed), delta)
	mirror_extra(s, delta)


## Bosses show more (their shell, bar...).
func mirror_extra(_s: Dictionary, _delta: float) -> void:
	pass


## Server snapshot of this enemy (see Net): what a mirror needs to look right.
func net_state() -> PackedFloat32Array:
	var p := global_position
	var flags := (1 if model.visible else 0) | (2 if collision_layer != 0 else 0) | net_flags()
	return PackedFloat32Array([net_id, p.x, p.y, p.z, model.rotation.y, model.scale.x, model.scale.y, model.scale.z,
			model.position.y, model.glow(), state, hp, flags])


func net_flags() -> int:
	return 0
