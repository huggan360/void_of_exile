class_name Boss
extends Enemy
## A boss encounter, driven by its BossDef. Programmed like any enemy
## (movement and attacks come from Enemy), with on top:
##
##   sealed   (wake_on "shell") it sleeps inside a shell: walking near is
##            safe; player hits wear down the shell's own health (defense 0),
##            cracking it at 75%, 50% and 25%. Shell damage gives no loot,
##            XP or boss-damage credit.
##   hatch    the shell breaks (harmless fragments) and the boss unfolds over
##            intro_time while its bar fills. Its health is set at the end,
##            from how many players are near, and frozen for the attempt.
##            It can't attack for READY_DELAY more seconds.
##   phases   each phase changes how it fights (see BossDef). Blue Dragon's
##            phases are data (guards, sequences); the other bosses have their
##            own script (actor_script) built on the helpers here: support
##            registries (objectives, guards, hostile adds), a repeating
##            timeline, scheduled windups and telegraphed hazards. Phases only
##            ever move forward; a hit that crosses a threshold is capped at it.
##   reset    no player within abandon_radius for abandon_time: everything it
##            owns is removed and a fresh shell returns. A retry, not a respawn.
##   dying    at 1 health every encounter-owned damage source is switched off
##            first, then it glows and bursts. Rewards are rolled once, from its
##            scaled maximum health.
##
## Every boss registers in Boss.all, so the HUD can show the bar of the one
## you're fighting.

const PHASE_SHAKE := 0.4
const BURST_VOXELS := 1600
const BURST_SHAKE := 0.9
const READY_DELAY := 1.0
const CRACKS := [0.75, 0.5, 0.25]

static var all: Array[Boss] = []

var boss_def: BossDef
var phase := -1
var shielded := false:
	set(value):
		shielded = value
		if is_inside_tree(): sync_protection()
## Can't be hurt right now (guards up, in transit).
var immune := false:
	set(value):
		immune = value
		if is_inside_tree(): sync_protection()
## Health can't drop below this while it is set (crystal conduits).
var hp_floor := 0
## Shown under the bar instead of the default text ("" = default).
var status_text := ""
## Where the encounter lives (the stronghold center); it resets there.
var encounter_center := Vector3.ZERO
var hazards: BossHazards
var shell_hp := 0
var shell_max := 0
## Players counted when the fight started (support health scales with it).
var players_counted := 1
## Visual spin of the model (radians per second), separate from aiming.
var spin_rate := 0.0
var cycle_count := 0
## Hits stop at the next phase threshold (a boss may lift this while it
## holds a phase change back, e.g. during a stun).
var cap_thresholds := true

var _shell: CreatureModel
var _cracks := 0
var _intro_left := 0.0
var intro_players: Array = []
var intro_serial := 0
var intro_duration := 10.0
var _gate_center := Vector2i(1<<29,1<<29)
var _support := {}  # role -> Array[Enemy]
var _pips: Array[Dictionary] = []  # {enemy, color}: objectives shown on the bar
var _after_applied := false
var _sequence: Array = []
var _step := 0
var _step_timer := 0.0
var _dying_left := 0.0
var _light: OmniLight3D
var _last_by := 0  # who landed the last hit (they get the final point)
var _abandon := 0.0
var _scheduled: Array[Dictionary] = []  # {left, call}
var _cycle_t := 0.0
var _cycle_len := 0.0
var _cycle_events: Array = []  # [[time, Callable], ...] sorted by time
var _cycle_i := 0
var _spin_angle := 0.0
var _collider: CollisionShape3D
var _body_shape: Shape3D
var charge_arena_radius := 11.0
var _charge := {}  # an active charge: {dir, left, from, damage, hits, done, stuck}


func setup(p_def: EnemyDef, p_pack: EnemyPack, p_director: EnemyDirector) -> Enemy:
	boss_def = p_def
	super.setup(p_def, p_pack, p_director)
	set_attacks([])
	return self


func _ready() -> void:
	super._ready()
	encounter_id = get_instance_id()
	encounter_center = global_position
	all.append(self)
	hazards = BossHazards.create(director)
	hazards.boss = self
	for child in get_children():
		if child is CollisionShape3D:
			_collider = child
			_body_shape = child.shape
	if boss_def.wake_on == "shell":
		_make_shell()


func _exit_tree() -> void:
	if not mirror: _release_encounter()
	all.erase(self)
	if is_instance_valid(hazards):
		hazards.queue_free()


## The boss whose bar `pos` should see: cracked, woken, alive and close enough.
static func nearest_active(pos: Vector3) -> Boss:
	var best: Boss = null
	for b in all:
		if not is_instance_valid(b) or b.state == State.DEAD:
			continue
		if b.state == State.IDLE and not (b.is_sealed() and b.shell_hp < b.shell_max):
			continue
		var d := b.global_position.distance_to(pos)
		if d < b.boss_def.bar_radius and (best == null or d < best.global_position.distance_to(pos)):
			best = b
	return best


## 0..1 while the intro runs (how full its bar is), 1 after.
func intro_progress() -> float:
	if state == State.INTRO:
		return 1.0 - _intro_left / maxf(.01,intro_duration)
	return 1.0


func is_dying() -> bool:
	return state == State.DYING


func is_sealed() -> bool:
	return _shell != null and state == State.IDLE


func _notices(dist: float) -> bool:
	return boss_def.wake_on == "near" and dist < def.aggro_radius


## Woken (by a player coming near, or a shot): the intro starts. Sealed
## bosses only wake when their shell breaks.
func activate() -> void:
	if state != State.IDLE or _shell != null:
		return
	_start_intro()


func _start_intro() -> void:
	state = State.INTRO
	intro_duration = maxf(8.0,boss_def.intro_time)
	_intro_left = intro_duration
	intro_serial += 1
	if model.uses_articulated_intro(): model.boss_pose("awaken",intro_duration)
	var ids: Array = []
	var gates := _gates()
	if gates: _gate_center = gates.center_for(encounter_center)
	for player: Node3D in director.players:
		if not is_instance_valid(player) or player.frozen: continue
		if player.global_position.distance_to(encounter_center)>boss_def.bar_radius: continue
		if gates and not gates.inside_arena(_gate_center,player.global_position): continue
		ids.append(player.player_id)
	intro_players = GameServer.begin_boss_intro(encounter_id,director.realm_id,ids,intro_duration)
	if gates and boss_def.lock_gates: gates.request(_gate_center,true)
	CameraShake.shake_from(self, global_position, PHASE_SHAKE, boss_def.bar_radius)
	model.flap()
	var tw := create_tween()
	tw.tween_method(model.set_glow, 0.0, 1.5, 0.4)
	tw.tween_method(model.set_glow, 1.5, 0.0, 1.2)


func _physics_process(delta: float) -> void:
	if not mirror: sync_protection()
	buffs.tick()
	if mirror:
		mirror_update(delta)
		return
	_target_timer -= delta
	if target() == null and state != State.IDLE and state != State.DYING:
		# Everyone left the realm mid-fight: it waits (and resets after a while).
		model.animate(0.0, delta)
		_check_abandon(delta)
		return
	match state:
		State.IDLE:
			if _shell != null:
				_shell_idle(delta)
				return
			super._physics_process(delta)
		State.INTRO:
			_intro_left -= delta
			_face_player(delta)
			model.animate(0.0, delta)
			_hatch_update(1.0 - _intro_left / maxf(.01,intro_duration))
			_check_abandon(delta)
			if _intro_left <= 0.0:
				_begin_fight()
		State.DYING:
			_update_dying(delta)
		_:
			var before := global_position
			super._physics_process(delta)
			if state == State.ACTIVE and not buffs.has_effect("static") and not buffs.has_effect("quiet"):
				_update_charge(before, delta)
				_update_scheduled(delta)
				_update_phase(delta)
				_check_abandon(delta)
	_spin_angle = wrapf(_spin_angle + spin_rate * delta, 0.0, TAU)
	if spin_rate != 0.0 or _spin_angle != 0.0:
		model.rotation.y = _facing + _spin_angle


func _face_player(delta: float) -> void:
	if target() == null:
		return
	var to := target().global_position - global_position
	_facing = lerp_angle(_facing, atan2(-to.x, -to.z), minf(1.0, delta * TURN_SPEED))
	model.rotation.y = _facing


## The fight starts: health from the number of players here, then phase 1.
func _begin_fight() -> void:
	players_counted = maxi(1, GameServer.players_near(director.realm_id, global_position, boss_def.bar_radius))
	max_hp = int(round(def.hp * (1.0 + boss_def.hp_per_extra_player * (players_counted - 1))))
	hp = max_hp
	state = State.ACTIVE
	_lose_timer = 0.0
	model.scale = Vector3.ONE * def.model_scale
	model.position = Vector3.ZERO
	attack_lock = READY_DELAY
	_enter_phase(0)


# --- Shell and hatch ----------------------------------------------------------------

func _make_shell() -> void:
	_shell = CreatureModel.new(boss_def.shell_model)
	_shell.scale = Vector3.ONE * boss_def.shell_scale
	add_child(_shell)
	if Net.is_server():
		_shell.recorder = func(method: StringName, args: Array) -> void: Net.server.model_call(self,method,args,true)
	_shell.rotation.y = randf() * TAU
	_cracks = 0
	shell_max = boss_def.shell_hp
	shell_hp = shell_max
	model.visible = false
	var capsule := CapsuleShape3D.new()
	capsule.radius = boss_def.shell_radius
	capsule.height = maxf(capsule.radius * 2.0, boss_def.shell_height)
	_collider.shape = capsule
	_collider.position.y = capsule.height * 0.5
	collision_layer = Player.ENEMY_LAYER
	state = State.IDLE


func _shell_idle(delta: float) -> void:
	_shell.animate(0.0, delta)
	# A slow heartbeat glows through the seams, stronger as it cracks.
	_shell.set_glow((0.5 + 0.5 * sin(Time.get_ticks_msec() / 1000.0 * 2.4)) * (0.2 + _cracks * 0.35))


func _hit_shell(damage: int, by: int, at := Vector3.INF, direction := Vector3.ZERO) -> void:
	if shell_hp == shell_max:
		# Like boss health, the shell scales with the players here at the first hit.
		var near := maxi(1, GameServer.players_near(director.realm_id, global_position, boss_def.bar_radius))
		shell_max = int(round(boss_def.shell_hp * (1.0 + boss_def.hp_per_extra_player * (near - 1))))
		shell_hp = shell_max
	shell_hp = maxi(0, shell_hp - damage)
	_last_by = by
	FloatingText.spawn(director, global_position + Vector3.UP * (boss_def.shell_height + 0.3), "-%d" % damage, Color(0.85, 0.85, 0.8))
	_shell.hit_voxels(at,direction)
	while _cracks < CRACKS.size() and float(shell_hp) / shell_max <= CRACKS[_cracks]:
		_cracks += 1
		_shell.set_variant("crack%d" % _cracks)
		var pts := _shell.voxel_points(160)
		Debris.burst_points(director, pts[0], pts[1], _shell.voxel_size(), 90,
				global_position + Vector3.UP * boss_def.shell_height * 0.5, global_position.y, 0.6)
		CameraShake.shake_from(self, global_position, 0.15 + _cracks * 0.05, 18.0)
	if shell_hp <= 0:
		_hatch()


## The shell breaks: harmless fragments fly, the boss unfolds over intro_time.
func _hatch() -> void:
	var pts := _shell.voxel_points(1400)
	Debris.burst_points(director, pts[0], pts[1], _shell.voxel_size() * 1.6, 900,
			global_position + Vector3.UP * boss_def.shell_height * 0.35, global_position.y, 1.2)
	_shell.queue_free()
	_shell = null
	_collider.shape = _body_shape
	_collider.position.y = (_body_shape as CapsuleShape3D).height * 0.5
	model.visible = true
	_start_intro()
	flash_light(director, global_position + Vector3.UP * height() * 0.5, boss_def.burst_color, 8.0, height() * 3.0, 1.6)


## The unfolding (k: 0..1 through the intro). Curled small and low at first,
## it rises and spreads, beats its wings and settles. Bosses can add to it.
func _hatch_update(k: float) -> void:
	if model.uses_articulated_intro():
		model.scale = Vector3.ONE * def.model_scale
		model.set_glow(maxf(0.0,1.2-k*1.6))
		return
	var rise := clampf(k / 0.75, 0.0, 1.0)
	var e := 1.0 - pow(1.0 - rise, 3.0)
	model.scale = Vector3(lerpf(0.55, 1.0, e), lerpf(0.35, 1.0, e), lerpf(0.55, 1.0, e)) * def.model_scale
	model.set_glow(maxf(0.0, 1.2 - k * 1.6))
	if k > 0.55 and k - get_physics_process_delta_time() / maxf(.01,intro_duration) <= 0.55:
		model.flap()
		CameraShake.shake_from(self, global_position, 0.3, boss_def.bar_radius)


# --- Phases -------------------------------------------------------------------------

func _enter_phase(index: int) -> void:
	if index <= phase or index >= boss_def.phases.size():
		return
	phase = index
	var p: Dictionary = boss_def.phases[index]
	defense = p.get("defense", def.defense)
	behavior = p.get("behavior", def.behavior)
	move_speed = p.get("move_speed", def.move_speed)
	model.set_variant(p.get("variant", ""))
	_after_applied = false
	_volleys.clear()
	_scheduled.clear()
	_cycle_events = []
	_charge = {}
	scripted_move = Vector3.ZERO
	face_override = Vector3.ZERO
	if p.has("summon"):
		_summon(p.summon)
	shielded = p.get("shielded", false) and not support("guard").is_empty()
	set_attacks(p.get("attacks_shielded", []) if shielded else p.get("attacks", []))
	_sequence = [] if shielded else p.get("sequence", [])
	_step = 0
	_step_timer = 1.0
	# A roar: the screen shakes and it flares up.
	CameraShake.shake_from(self, global_position, PHASE_SHAKE, boss_def.bar_radius)
	model.flap()
	var tw := create_tween()
	tw.tween_method(model.set_glow, 0.0, 2.5, 0.25)
	tw.tween_method(model.set_glow, 2.5, 0.0, 0.9)
	_phase_started(index)


## Each boss sets up its own phases here (summons, timelines, forms).
func _phase_started(_index: int) -> void:
	pass


## Each boss's own fight, every physics frame while active.
func _combat(_delta: float) -> void:
	pass


## Data-driven guards (Blue Dragon): spawned once, shown as pips on the bar.
func _summon(summon: Dictionary) -> void:
	var ids: Array = summon.enemies
	var radius: float = summon.get("radius", 6.0)
	for i in ids.size():
		var angle := TAU * i / ids.size()
		var pos := encounter_center + Vector3(cos(angle), 0.0, sin(angle)) * radius
		var minion := spawn_support(ids[i], pos, "guard", false, false)
		if minion == null:
			continue
		minion.orbit_angle = angle
		var color: Color = minion.def.attacks[0].get("color", Color.WHITE) if not minion.def.attacks.is_empty() else Color.WHITE
		_pips.append({enemy = minion, color = color})


func _update_phase(delta: float) -> void:
	var p: Dictionary = boss_def.phases[phase]
	if shielded and support("guard").is_empty():
		# Its guards are down: now it can be hurt, and it changes tactics.
		shielded = false
		set_attacks(p.get("attacks", []))
		_sequence = p.get("sequence", [])
		_step = 0
		_step_timer = 0.6
		CameraShake.shake_from(self, global_position, PHASE_SHAKE * 0.6, boss_def.bar_radius)
	if not shielded and not _after_applied and p.has("after"):
		_after_applied = true
		var after: Dictionary = p.after
		behavior = after.get("behavior", behavior)
		move_speed = after.get("move_speed", move_speed)
		if after.has("attacks"):
			set_attacks(after.attacks)
	if attack_lock > 0.0:
		return
	_run_sequence(delta)
	_run_cycle(delta)
	_combat(delta)


## Scripted phases: steps of {attack = {...}} and {wait = s}, over and over.
func _run_sequence(delta: float) -> void:
	if _sequence.is_empty():
		return
	_step_timer -= delta
	while _step_timer <= 0.0:
		var step: Dictionary = _sequence[_step]
		_step = (_step + 1) % _sequence.size()
		if step.has("wait"):
			_step_timer += step.wait
		else:
			_fire(step.attack)
			_step_timer += step.get("then", 0.2)


## A repeating timeline: [[seconds into the cycle, Callable], ...].
func set_cycle(length: float, events: Array) -> void:
	_cycle_len = length
	_cycle_events = events.duplicate()
	_cycle_events.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	_cycle_t = 0.0
	_cycle_i = 0


func _run_cycle(delta: float) -> void:
	if _cycle_events.is_empty():
		return
	_cycle_t += delta
	while _cycle_i < _cycle_events.size() and _cycle_events[_cycle_i][0] <= _cycle_t:
		var call: Callable = _cycle_events[_cycle_i][1]
		_cycle_i += 1
		call.call()
		if _cycle_events.is_empty():
			return  # the event moved the fight on
	if _cycle_t >= _cycle_len:
		_cycle_t -= _cycle_len
		_cycle_i = 0
		cycle_count += 1


## True during a phase-change rest (begin_rest): no new attacks start.
var resting := false


## A three-second intermission between phases: windups, timelines and
## hazards stop (shots already flying keep going), it kneels, flashes and
## rises, then `resume` runs. `pose` is the kneel pose of its rig.
func begin_rest(resume: Callable, text: String, pose := "kneel") -> void:
	resting = true
	immune = true
	behavior = "stationary"
	scripted_move = Vector3.ZERO
	velocity = Vector3.ZERO
	face_override = Vector3.ZERO
	_charge = {}
	_scheduled.clear()
	_cycle_events = []
	_sequence = []
	_volleys.clear()
	set_attacks([])
	hazards.clear()
	status_text = text
	model.boss_pose(pose, 3.0)
	CameraShake.shake_from(self, global_position, 0.35, boss_def.bar_radius)
	after(2.25, func() -> void:
		model.hit_voxels(global_position + Vector3.UP * height() * 0.45)
		model.boss_pose("rise", 0.75)
		pulse_glow(2.0, 0.7))
	after(3.0, func() -> void:
		resting = false
		immune = false
		status_text = ""
		resume.call())


## A summoned helper materializes first; its first volley waits two seconds.
func arm_summon(helper: Enemy, stagger := 0.0) -> void:
	helper.attack_lock = 9999.0
	var pending: WeakRef = weakref(helper)
	after(2.0 + stagger, func() -> void:
		var summoned := pending.get_ref() as Enemy
		if summoned == null or not summoned.is_alive(): return
		summoned.attack_lock = 0.0
		for i in summoned._attack_timers.size():
			summoned._attack_timers[i] = summoned.attacks[i].cooldown
			summoned._windups[i] = 0.0001)


## Shots fired tangentially so they orbit `center` at `radius` for `loops`
## turns (sign of `sense` picks the direction).
func fire_orbit(center: Vector3, radius: float, count: int, speed: float, loops: float, sense: float,
		attack: Dictionary, offset := 0.0) -> void:
	var a := attack.duplicate()
	a.turn = sense * speed / radius
	a.speed = speed
	a.range = TAU * radius * loops
	for k in count:
		var radial := Vector3.FORWARD.rotated(Vector3.UP, offset + k * TAU / count)
		var origin := center + radial * radius
		origin.y = shot_origin().y
		shoot(origin, (-radial).rotated(Vector3.UP, -PI * 0.5 * sense), a)


## Runs `call` after `delay` seconds (a windup's release). Phase changes,
## resets and death cancel everything still pending.
func after(delay: float, call: Callable) -> void:
	_scheduled.append({left = delay, call = call})


func _update_scheduled(delta: float) -> void:
	var due: Array[Callable] = []
	for i in range(_scheduled.size() - 1, -1, -1):
		_scheduled[i].left -= delta
		if _scheduled[i].left <= 0.0:
			due.append(_scheduled[i].call)
			_scheduled.remove_at(i)
	for call in due:
		if state == State.ACTIVE:
			call.call()


# --- Support actors -----------------------------------------------------------------

## Summons a helper that belongs to this encounter. role: "objective" (must
## be destroyed: towers, sentinels), "guard" (Blue's dragonlings) or "add"
## (hostile minions). exact: placed at `pos` (its socket) rather than the
## nearest clear spot. Objectives and guards get support health scaling.
func spawn_support(def_id: String, pos: Vector3, role: String, exact := false, scale_hp := true) -> Enemy:
	var minion: Enemy
	if exact:
		pos.y = director.world.ground_height(pos.x, pos.z)
		var enemy_def := Enemies.get_def(def_id)
		minion = Enemy.new().setup(enemy_def, pack, director)
		minion.is_minion = true
		minion.position = director.to_local(pos)
		director.add_child(minion)
		minion.died.connect(pack._on_member_died)
		pack.members.append(minion)
		minion.activate.call_deferred()
	else:
		minion = director.spawn_minion(def_id, pos, pack)
	if minion == null:
		return null
	minion.encounter_id = encounter_id
	if scale_hp and role != "add":
		minion.max_hp = int(round(minion.def.hp * (1.0 + boss_def.support_hp_per_extra_player * (players_counted - 1))))
		minion.hp = minion.max_hp
	if not _support.has(role):
		_support[role] = []
	_support[role].append(minion)
	return minion


## Living helpers of a role.
func support(role: String) -> Array:
	var alive: Array = _support.get(role, []).filter(func(e: Variant) -> bool: return is_instance_valid(e) and (e as Enemy).is_alive())
	_support[role] = alive
	return alive


## Removes helpers without rewards (all roles if "").
func despawn_support(role := "") -> void:
	for r in _support.keys():
		if role != "" and r != role:
			continue
		for e in _support[r]:
			if is_instance_valid(e):
				(e as Enemy).despawn()
		_support[r] = []


## The bar's objective pips: [{color, alive}].
func bar_pips() -> Array:
	var out := []
	for pip in _pips:
		out.append({color = pip.color, alive = is_instance_valid(pip.enemy) and pip.enemy.is_alive()})
	return out


## Keep encounter protection in the same visible status system as gear effects.
func sync_protection() -> void:
	if mirror: return
	var is_protected := shielded or immune or (hp_floor > 0 and hp <= hp_floor) or state in [State.INTRO, State.DYING, State.SPAWNING]
	if is_protected:
		for id in ["immune", "invincible"]:
			if not buffs.has_effect(id): buffs.add(id, 86400.0, 1, "boss_phase")
	else:
		buffs.remove("immune", "boss_phase")
		buffs.remove("invincible", "boss_phase")


func bar_status() -> String:
	if status_text != "":
		return status_text
	if shielded or immune:
		return "INVULNERABLE  -  defeat its guards"
	return ""


# --- Aiming and firing helpers ------------------------------------------------------

## Where its shots leave from: its center at shot height.
func shot_origin(forward := 0.0) -> Vector3:
	var o := global_position
	o.y = director.world.ground_height(o.x, o.z) + Player.SHOT_HEIGHT
	return o + aim_dir() * forward


## Flat direction to the player right now (snapshot it for aimed volleys).
func aim_dir(from := Vector3.INF) -> Vector3:
	var o := global_position if from == Vector3.INF else from
	var d := (target().global_position if target() != null else o + Vector3.FORWARD) - o
	d.y = 0.0
	return d.normalized() if d.length() > 0.01 else Vector3.FORWARD


func shoot(origin: Vector3, dir: Vector3, attack: Dictionary) -> void:
	if buffs.has_effect("static") or buffs.has_effect("quiet"): return
	if director.world is DungeonWorld:
		var mult: float = director.world.definition.enemy_damage_multiplier
		attack = attack.duplicate(true)
		attack.damage_min = roundi(float(attack.get("damage_min", 0)) * mult)
		attack.damage_max = roundi(float(attack.get("damage_max", 0)) * mult)
	director.bullets.fire(origin, dir, attack, self, origin.y)


## `count` shots spread `step_deg` apart around `dir`.
## An optional distinct centre shot replaces one bullet in an odd fan.
func fire_fan(origin: Vector3, dir: Vector3, count: int, step_deg: float, attack: Dictionary, center_attack: Dictionary = {}) -> void:
	for k in count:
		var bullet := center_attack if k*2 == count-1 and not center_attack.is_empty() else attack
		shoot(origin, dir.rotated(Vector3.UP, deg_to_rad((k - (count - 1) * 0.5) * step_deg)), bullet)


## A ring of `count` directions, leaving out the opposite safe sectors
## centered on `gap_angle` and gap_angle + PI (each `gap_deg` wide).
func fire_ring(origin: Vector3, count: int, attack: Dictionary, gap_angle := 0.0, gap_deg := 0.0) -> void:
	for k in count:
		var a := TAU * k / count
		if gap_deg > 0.0 and _in_gap(a, gap_angle, gap_deg):
			continue
		shoot(origin, Vector3.FORWARD.rotated(Vector3.UP, a), attack)


static func _in_gap(a: float, gap_angle: float, gap_deg: float) -> bool:
	var half := deg_to_rad(gap_deg) * 0.5
	return absf(angle_difference(a, gap_angle)) <= half or absf(angle_difference(a, gap_angle + PI)) <= half


## Shows the two safe gaps of a coming ring on the floor (visual only).
func mark_ring_gaps(gap_angle: float, gap_deg: float, time: float, color: Color) -> void:
	for side in [0.0, PI]:
		var dir := Vector3.FORWARD.rotated(Vector3.UP, gap_angle + side)
		hazards.lane(global_position + dir * 5.0, dir, 7.0, 2.0 * 7.0 * tan(deg_to_rad(gap_deg) * 0.5) * 0.6,
				time, 0.0, Vector2i.ZERO, 0.0, color)


## Steers toward a point (scripted movement), stopping when close.
func steer_to(point: Vector3, speed: float) -> void:
	behavior = "scripted"
	move_speed = speed
	var to := point - global_position
	to.y = 0.0
	scripted_move = to.normalized() * clampf(to.length() / 1.0, 0.0, 1.0) if to.length() > 0.2 else Vector3.ZERO


## An attack dictionary for EnemyBullets: raw damage range, the solid core's
## collision radius and its look.
## `size` may also be the extras dictionary itself (its own size key included).
static func shot(style: String, color: Color, damage: Vector2i, speed: float, radius: float,
		range_m: float, size: Variant = 1.0, extra := {}) -> Dictionary:
	if size is Dictionary:
		extra = size
		size = extra.get("size", 1.0)
	var a := {style = style, color = color, damage_min = damage.x, damage_max = damage.y, speed = speed,
		radius = radius, range = range_m, size = size}
	a.merge(extra, true)
	return a


## Charges along `dir` for up to `distance` meters at `speed`, hitting each
## player it touches once (knocked aside, not flung far). Stops at walls or
## the edge of the stronghold apron. on_done runs when it stops.
func start_charge(dir: Vector3, distance: float, speed: float, damage: Vector2i, on_done: Callable) -> void:
	if director.world is DungeonWorld:
		var mult: float = director.world.definition.enemy_damage_multiplier
		damage = Vector2i(roundi(damage.x * mult), roundi(damage.y * mult))
	dir.y = 0.0
	dir = dir.normalized()
	GameAudio.emit_from("boss_impact", self, {source_id = encounter_id, cooldown = 0.25, max_distance = 64.0})
	_charge = {dir = dir, left = distance, damage = damage, hits = [], done = on_done, stuck = 0.0}
	behavior = "scripted"
	move_speed = speed
	scripted_move = dir
	face_override = dir


func is_charging() -> bool:
	return not _charge.is_empty()


func _update_charge(before: Vector3, delta: float) -> void:
	if _charge.is_empty():
		return
	var moved := Vector2(global_position.x - before.x, global_position.z - before.z).length()
	_charge.left -= moved
	_charge.stuck = _charge.stuck + delta if moved < move_speed * delta * 0.3 else 0.0
	var reach := def.hit_radius * def.model_scale + EnemyBullets.PLAYER_RADIUS + 0.3
	for p in players():
		if p in _charge.hits:
			continue
		var contact := Geometry2D.get_closest_point_to_segment(
			Vector2(p.global_position.x,p.global_position.z),Vector2(before.x,before.z),Vector2(global_position.x,global_position.z))
		if Vector2(p.global_position.x,p.global_position.z).distance_to(contact)<reach:
			_charge.hits.append(p)
			_charge_contact(p,Vector3(contact.x,global_position.y,contact.y))
	var ahead: Vector3 = global_position + _charge.dir * 1.5
	var off_apron := Vector2(ahead.x - encounter_center.x, ahead.z - encounter_center.z).length() > charge_arena_radius
	if _charge.left <= 0.0 or _charge.stuck > 0.25 or off_apron:
		var done: Callable = _charge.done
		_charge = {}
		scripted_move = Vector3.ZERO
		face_override = Vector3.ZERO
		if done.is_valid():
			done.call()


## Boss-specific contact damage and shove; called once per player per charge.
func _charge_contact(player, _contact: Vector3) -> void:
	player.take_damage(float(randi_range(_charge.damage.x,_charge.damage.y)),false,false)
	GameAudio.emit_from("boss_impact", self, {source_id = encounter_id, cooldown = 0.25, max_distance = 64.0})
	var side: Vector3 = (player.global_position-global_position).normalized()
	player.knockback((side+_charge.dir*0.5).normalized()*4.0)


## Players that can be hurt right now.
func players() -> Array:
	return director.players.filter(func(p: Variant) -> bool: return is_instance_valid(p) and not p.frozen)


## A point pulled back inside `radius` of the stronghold center.
func in_arena(pos: Vector3, radius: float) -> Vector3:
	var flat := Vector2(pos.x - encounter_center.x, pos.z - encounter_center.z).limit_length(radius)
	var out := Vector3(encounter_center.x + flat.x, 0.0, encounter_center.z + flat.y)
	out.y = director.world.ground_height(out.x, out.z)
	return out


## A quick flare of its glow (a windup's tell).
func pulse_glow(strength: float, time: float) -> void:
	GameAudio.emit_from("boss_riser", self, {source_id = encounter_id, cooldown = 1.0, max_distance = 64.0, align_end=time, priority=2, volume_db=-5})
	var tw := create_tween()
	tw.tween_method(model.set_glow, 0.0, strength, time * 0.7)
	tw.tween_method(model.set_glow, strength, 0.0, time * 0.3 + 0.2)


## The nearest walkable, clear point to `pos` (keeps attacks off walls).
func clear_point(pos: Vector3, radius := 0.6) -> Vector3:
	for ring: float in [0.0, 1.0, 2.0, 3.0]:
		for i in (1 if ring == 0.0 else 8):
			var c := pos + Vector3(cos(TAU * i / 8.0), 0, sin(TAU * i / 8.0)) * ring
			c.y = director.world.ground_height(c.x, c.z)
			if director.world.is_walkable(c) and not director.world.is_hazard(c) and director.world.enemy_spawn_clear(c, radius, 1.5):
				return c
	return Vector3.INF


# --- Damage, reset and death --------------------------------------------------------

func take_hit(_hit_position: Vector3, direction: Vector3, damage := 10, source: Node = null) -> void:
	if mirror:
		Net.client.hit_enemy(self, damage, direction)
		return
	var by := hitter_id(source)
	match state:
		State.IDLE:
			if _shell != null:
				_hit_shell(damage, by, _hit_position, direction)
			else:
				pack.alert()  # shooting it wakes it
			return
		State.INTRO, State.DYING, State.DEAD, State.SPAWNING:
			return
	sync_protection()
	if buffs.has_effect("invincible"):
		if shielded:
			GameAudio.emit_from("magic_shield_hit", self, {cooldown = .1})
		_on_blocked()
		FloatingText.spawn(director, global_position + Vector3.UP * (height() + 0.3), "Immune", Color(0.6, 0.8, 1.0))
		return
	var dealt := maxi(int(ceil(damage * MIN_DAMAGE_TAKEN)), damage - (0 if buffs.has_effect("armour_broken") else defense))
	dealt = mini(dealt, hp - maxi(1, hp_floor))  # the last point goes in the burst
	# A hit can't skip a phase: it stops at the next threshold.
	var until: float = boss_def.phases[phase].get("until", 0.0) if phase >= 0 else 0.0
	if cap_thresholds and until > 0.0 and phase + 1 < boss_def.phases.size():
		dealt = mini(dealt, hp - int(floor(max_hp * until)))
	if dealt <= 0:
		FloatingText.spawn(director, global_position + Vector3.UP * (height() + 0.3), "Blocked", Color(0.6, 0.9, 1.0))
		_on_blocked()
		return
	_damage_by[by] = _damage_by.get(by, 0) + dealt  # only health actually lost counts
	_last_by = by
	hp -= dealt
	GameAudio.emit_from("boss_dragon_hurt" if def.id == "blue_dragon" else "boss_hurt",
			self, {source_id = encounter_id, cooldown = 1.8, max_distance = 64.0})
	FloatingText.spawn(director, global_position + Vector3.UP * (height() + 0.3), "-%d" % dealt, FloatingText.ENEMY_DAMAGE)
	model.hit_voxels(_hit_position,direction)
	if hp <= 1:
		_start_dying()
		return
	_on_hurt(dealt)
	var share := float(hp) / max_hp
	# Held at a health floor (towers still standing) the phase can't advance.
	if cap_thresholds and phase + 1 < boss_def.phases.size() and share <= until and hp > hp_floor:
		_threshold_reached(phase + 1)


## A threshold was reached; bosses can delay the change (after a stun...).
func _threshold_reached(next: int) -> void:
	_enter_phase(next)


func _on_hurt(_dealt: int) -> void:
	pass


## A hit was fully held back by its health floor.
func _on_blocked() -> void:
	pass


## Heals (never past `cap` health, and never back into an earlier phase).
func heal(amount: float, cap: int) -> void:
	if state != State.ACTIVE:
		return
	hp = mini(cap, hp + int(round(amount)))


func _check_abandon(delta: float) -> void:
	if GameServer.players_near(director.realm_id, encounter_center, boss_def.abandon_radius) > 0:
		_abandon = 0.0
		return
	_abandon += delta
	if _abandon >= boss_def.abandon_time:
		reset_attempt()


## Abandoned: everything it owns goes away and a fresh shell comes back.
func reset_attempt() -> void:
	if Net.is_server():
		Net.server.campaigns.boss_reset(self)
	# Nobody is left fighting: the fortress seals again and needs a new key.
	if _gates(): _gates().seal(_gate_center)
	_release_encounter()
	_abandon = 0.0
	despawn_support()
	_pips.clear()
	hazards.clear()
	director.bullets.clear_owner(encounter_id)
	_scheduled.clear()
	_cycle_events = []
	_volleys.clear()
	_sequence = []
	set_attacks([])
	phase = -1
	shielded = false
	immune = false
	hp_floor = 0
	status_text = ""
	spin_rate = 0.0
	_spin_angle = 0.0
	cap_thresholds = true
	attack_lock = 0.0
	scripted_move = Vector3.ZERO
	face_override = Vector3.ZERO
	_charge = {}
	_damage_by.clear()
	hp = def.hp
	max_hp = def.hp
	velocity = Vector3.ZERO
	global_position = encounter_center
	behavior = def.behavior
	model.set_variant("")
	model.scale = Vector3.ONE * def.model_scale
	model.position = Vector3.ZERO
	model.set_glow(0.0)
	_reset_hook()
	if boss_def.wake_on == "shell":
		_make_shell()
	else:
		state = State.IDLE


func _release_encounter() -> void:
	GameServer.cancel_boss_intro(encounter_id)
	intro_players.clear()
	if _gates(): _gates().request(_gate_center,false)


## The fortress gates of this world (the realm's strongholds, the planets'), or null.
func _gates() -> StrongholdGates:
	if not is_instance_valid(director) or not is_instance_valid(director.world): return null
	var gates: Variant = director.world.get("gates")
	return gates if gates is StrongholdGates and is_instance_valid(gates) else null


func _reset_hook() -> void:
	pass


## Down to its last point: every damage source it owns stops first, then it
## stands still and starts to glow.
func _start_dying() -> void:
	GameAudio.emit_from(GameAudio.rumble_event(boss_def.death_time),self,{duration=boss_def.death_time,fixed_pitch=true,priority=3,max_distance=80,volume_db=-5})
	GameAudio.emit_from("boss_die",self,{priority=3,max_distance=80,volume_db=-4,cooldown=2})
	_release_encounter()
	if Net.is_server():
		Net.server.social.announce(director.realm_id, "%s has fallen!" % def.enemy_name)
	state = State.DYING
	_dying_left = boss_def.death_time
	set_attacks([])
	_volleys.clear()
	_sequence = []
	_cycle_events = []
	_scheduled.clear()
	_charge = {}
	hazards.clear()
	director.bullets.clear_owner(encounter_id)
	despawn_support()
	velocity = Vector3.ZERO
	scripted_move = Vector3.ZERO
	spin_rate = 0.0
	_light = OmniLight3D.new()
	_light.light_color = boss_def.burst_color
	_light.omni_range = height() * 3.0
	_light.position.y = height() * 0.6
	add_child(_light)
	_death_started()


func _death_started() -> void:
	pass


func _update_dying(delta: float) -> void:
	_dying_left -= delta
	var k := 1.0 - clampf(_dying_left / boss_def.death_time, 0.0, 1.0)
	model.set_glow(k * k * 6.0)
	model.animate(0.0, delta)
	model.scale = Vector3.ONE * def.model_scale * (1.0 + sin(k * 40.0) * 0.015 * k)
	_light.light_energy = k * k * 8.0
	CameraShake.shake_from(self, global_position, 0.05 + k * 0.1, boss_def.bar_radius)
	_dying_update(k)
	if _dying_left <= 0.0:
		_burst()


func _dying_update(_k: float) -> void:
	pass


## Bursts into light and a storm of voxels; the server hands out XP and loot
## exactly once, judged against its scaled maximum health.
func _burst() -> void:
	if state == State.DEAD:
		return
	state = State.DEAD
	GameAudio.boss_defeated(def.id, director.realm_id)
	GameAudio.emit_from("boss_impact", self, {source_id = encounter_id, cooldown = 0.2, max_distance = 80.0, priority=3})
	var pts := model.voxel_points(BURST_VOXELS)
	Debris.burst_points(director, pts[0], pts[1], model.voxel_size() * 2.5, BURST_VOXELS,
			global_position + Vector3.UP * height() * 0.4, global_position.y, 1.6)
	CameraShake.shake_from(self, global_position, BURST_SHAKE, boss_def.bar_radius * 1.5)
	flash_light(director, global_position + Vector3.UP * height() * 0.5, boss_def.burst_color, 16.0, height() * 5.0, 0.9)
	_damage_by[_last_by] = _damage_by.get(_last_by, 0) + 1
	GameServer.enemy_killed(director.realm_id, def, global_position, _damage_by,
			_potion_stats(), max_hp)
	died.emit(self)
	queue_free()


# --- Online ------------------------------------------------------------------------

## Mirror: the boss bar's numbers and the shell come from the server.
var net_rays := {}  # hazard net id -> [origin, flat dir] for sweeping rays (server-driven)


## A burst of light that fades out (hatching, bursting). On the server it's
## sent to the players near it.
static func flash_light(parent: Node, pos: Vector3, color: Color, energy: float, light_range: float, fade: float) -> void:
	if Net.is_server():
		Net.server.fx(parent, pos, ["light", pos, color, energy, light_range, fade])
		return
	var flash := OmniLight3D.new()
	flash.light_color = color
	flash.omni_range = light_range
	flash.light_energy = energy
	parent.add_child(flash)
	flash.global_position = pos
	var tw := flash.create_tween()
	tw.tween_property(flash, "light_energy", 0.0, fade).set_ease(Tween.EASE_OUT)
	tw.tween_callback(flash.queue_free)


func mirror_extra(s: Dictionary, delta: float) -> void:
	var b: Dictionary = Net.client.boss_state(net_id)
	if _shell != null:
		_shell.visible = (int(s.flags) & 4) != 0
		if _shell.visible:
			_shell.animate(0.0, delta)
		collision_layer = Player.ENEMY_LAYER if _shell.visible or (int(s.flags) & 2) != 0 else 0
	# The dying glow: its light follows the glow the server sends.
	if state == State.DYING:
		if _light == null:
			_light = OmniLight3D.new()
			_light.light_color = boss_def.burst_color
			_light.omni_range = height() * 3.0
			_light.position.y = height() * 0.6
			add_child(_light)
		_light.light_energy = s.glow * 8.0 / 6.0
	if b.is_empty():
		return
	mirror_visuals(b.get("extra", []))
	max_hp = b.max_hp
	shell_hp = b.shell_hp
	shell_max = b.shell_max
	phase = b.phase
	_intro_left = b.intro_left
	intro_players = b.get("intro_players",[])
	intro_serial = int(b.get("intro_serial",0))
	intro_duration = float(b.get("intro_duration",boss_def.intro_time))
	shielded = b.shielded
	immune = b.immune
	status_text = b.status
	_pips = []
	for pip: Array in b.pips:
		_pips.append({enemy = Net.client.enemy_node(int(pip[0])), color = pip[1]})
	net_rays = b.rays


func net_flags() -> int:
	return 4 if _shell != null and _shell.visible and is_sealed() else 0


## What the boss bar needs, sent with each snapshot to players near it.
func net_boss_state(viewer_id := 0) -> Array:
	var pips := []
	for pip in _pips:
		pips.append([pip.enemy.net_id if is_instance_valid(pip.enemy) and pip.enemy.is_alive() else 0, pip.color])
	var rays := {}
	for h: Dictionary in hazards.rays():
		rays[h.net_id] = h.axis.call()
	return [net_id, max_hp, shell_hp, shell_max, phase, _intro_left, shielded, immune, status_text, pips, rays, net_visuals(), intro_players if viewer_id==0 else ([viewer_id] if viewer_id in intro_players else []), intro_serial, intro_duration]


## A boss's own extra visuals for its mirrors (plain data; see mirror_visuals).
func net_visuals() -> Array:
	return []


## Mirror: shows the extra visuals the server's boss has (net_visuals).
func mirror_visuals(_extra: Array) -> void:
	pass
