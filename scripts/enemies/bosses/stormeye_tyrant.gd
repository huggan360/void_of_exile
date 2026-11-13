extends Boss
## Vaelith, the Stormeye Tyrant, in the Stormeye Citadel on The Pale Eye: the
## Pale One itself and the last and worst of the Reach's bosses. A floating
## storm-eye that fights with magic: freezing shards, mind bubbles that leave
## you drunk, heavy magic spheres, and eight squid arms out of the deep.
##
## 1 (100-75%)  "The Pale Eye": eye lances, freezing shard volleys, magic
##    spheres that burst into storm orbs, rings with gaps, lightning lanes,
##    drifting mind bubbles (drunk for 5 s).
## 2 (75-50%)   "The Deep Arms": it binds itself to eight huge squid arms and
##    can't be hurt. Each arm rises slowly, hangs, then slams down fast on a
##    marked spot (a bit random, sometimes on a player) and throws ink and
##    sucker discs. Arms can only be hit while they lie on the ground, and
##    every hit goes to Vaelith. Above them it keeps casting: orb spirals,
##    bubble streams, frost rings, spheres. The projectile-heavy stage.
## 3 (50-25%)   "Tempest": turning storm rays, frost spirals, lances that
##    split, lightning circles, bubble rain; its storm shards come.
## 4 (25-0%)    "Cataclysm": four faster rays, the storm (spirals both ways
##    and rings of lances), magic barrages and four arms that slam without
##    rest (they can't be hit). The second projectile-heavy stage.
const STORM := Color("9ab0ff")
const RED := Color("ff4a5a")
const FROST := Color("a0e8ff")
const MIND := Color("c88cff")
const INK := Color("8c5adc")
const ARCANE := Color("9ab0ff")
const ARM_COLOR := Color("3a2a5c")
const ARM_SUCKER := Color("d7bee6")
const ARM_SEGMENTS := 18
const ARM_REACH := Vector2(9.0, 21.0)
const ARM_LIFT := 13.0
var _turn := 0.0
var _ray_angle := 0.0
var _ray_speed := 0.0
## The squid arms: {enemy, socket, tip, from, k, mode, left, dur, hittable, alive}.
var _arms: Array[Dictionary] = []
var _arm_root: Node3D
var _arm_nodes: Array = []  # per arm: [MeshInstance3D, ...]
var _arm_mesh: BoxMesh
var _arm_mat: StandardMaterial3D
var _arm_hot: StandardMaterial3D
var _sucker_mesh: BoxMesh
var _sucker_mat: StandardMaterial3D

func _phase_started(index: int) -> void:
	behavior = "stationary"
	_ray_speed = 0.0
	immune = index==1
	match index:
		0:
			status_text = ""
			set_cycle(13.0, [[0.5, _lances], [2.2, _frost_volley], [4.5, _spheres.bind(3)], [6.5, _storm_ring],
				[8.5, _lightning], [10.5, _bubbles.bind(9)]])
		1:
			_grow_arms(8, true)
			status_text = "Strike the arms while they lie on the ground"
			set_cycle(12.0, [[1.0, _spiral.bind(5, 18)], [4.5, _bubble_stream], [7.0, _frost_ring], [9.5, _spheres.bind(2)]])
		2:
			status_text = ""
			_shards(4)
			set_cycle(14.0, [[0.5, _rays.bind(3, 0.5)], [1.5, _frost_spiral], [5.5, _split_lances], [7.0, _lightning_circles],
				[9.0, _bubbles.bind(12)], [11.0, _spheres.bind(4)]])
		3:
			status_text = ""
			_grow_arms(4, false)
			set_cycle(15.0, [[0.5, _rays.bind(4, 0.75)], [1.5, _storm], [7.5, _barrage], [9.5, _split_lances],
				[11.0, _lightning_circles], [12.5, _bubble_stream]])

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	_ray_angle += _ray_speed*delta
	if not mirror and state==State.ACTIVE:
		_update_arms(delta)
	_draw_arms()

func _threshold_reached(next: int) -> void:
	if resting: return
	_clear_arms()
	var text: String = ["", "The deep answers: eight arms rise round the Eye", "The arms tear free: the storm tightens",
		"The Eye cracks open: the cataclysm"][next]
	begin_rest(func() -> void: _enter_phase(next), text, "kneel")

# --- Shots ---------------------------------------------------------------------------

func _orb(speed := 5.5) -> Dictionary:
	return PlanetBosses.shot("storm_orb", "orb", STORM, Vector2i(86, 110), speed, 24.0, 1.0)

func _lance(speed := 11.0) -> Dictionary:
	return PlanetBosses.shot("eye_lance", "bolt", RED, Vector2i(126, 161), speed, 26.0, 1.1)

## Freezing shards: frozen in place for a moment, then slowed.
func _frost(speed := 9.0) -> Dictionary:
	return PlanetBosses.shot("frost_shard", "shard", FROST, Vector2i(72, 94), speed, 24.0, 1.1,
		{effects = [{id = "static", duration = 0.9}, {id = "speed", amount = -4, duration = 2.5}], effect_source = "Vaelith's frost"})

## Mind bubbles: slow and wobbling; a hit leaves you drunk for five seconds.
func _bubble(speed := 4.0) -> Dictionary:
	return PlanetBosses.shot("dizzy_bubble", "orb", MIND, Vector2i(58, 76), speed, 22.0, 1.2,
		{effects = [{id = "drunk", duration = 5.0}], effect_source = "Vaelith's mind bubble"})

## A heavy ball of magic that bursts into a ring of storm orbs.
func _sphere(burst := 12) -> Dictionary:
	return PlanetBosses.shot("arcane_sphere", "orb", ARCANE, Vector2i(150, 190), 3.6, 11.0, 1.5,
		{magic = true, terminal = {delay = 0.35, count = burst, attack = _orb(5.0)}})

func _ink(speed := 5.5) -> Dictionary:
	return PlanetBosses.shot("abyss_ink", "orb", INK, Vector2i(95, 122), speed, 20.0, 1.1)

func _sucker(speed := 8.5) -> Dictionary:
	return PlanetBosses.shot("sucker_disc", "disc", ARM_SUCKER, Vector2i(102, 130), speed, 24.0, 1.2)

# --- Attacks -------------------------------------------------------------------------

## Bursts of eye lances: quick, aimed, re-aimed each burst.
func _lances() -> void:
	pulse_glow(1.6, 0.5)
	for wave in (4 if phase<3 else 6):
		after(0.5+wave*0.22, func() -> void: fire_fan(shot_origin(1.5), aim_dir(), 3 if phase==0 else 5, 7.0, _lance()))

## Three fans of freezing shards, each a little turned.
func _frost_volley() -> void:
	model.boss_pose("cast", 1.0)
	var base := aim_dir()
	for wave in 3:
		after(0.6+wave*0.3, func() -> void:
			fire_fan(shot_origin(1.5), base.rotated(Vector3.UP, deg_to_rad(5.0*(wave-1))), 5, 12.0, _frost(9.0+wave)))

## A ring of freezing shards with two gaps, then a second turned a little.
func _frost_ring() -> void:
	var gap := atan2(-aim_dir().x, -aim_dir().z)+randf_range(-0.7, 0.7)
	mark_ring_gaps(gap, 42.0, 0.9, FROST)
	after(0.9, func() -> void: fire_ring(shot_origin(), 26, _frost(6.5), gap, 42.0))
	after(1.5, func() -> void: fire_ring(shot_origin(), 26, _frost(5.5), gap+0.2, 42.0))

## Four arms of freezing shards winding out of it.
func _frost_spiral() -> void:
	model.boss_pose("channel", 3.4)
	_turn += 0.5
	var start := _turn
	for beat in 20:
		after(0.4+beat*0.16, func() -> void:
			for arm in 4:
				var attack := _frost(6.0)
				attack.turn = 0.1
				shoot(shot_origin(), Vector3.FORWARD.rotated(Vector3.UP, start+beat*0.19+arm*TAU/4.0), attack))

## Magic spheres drift toward everyone and burst into rings of orbs.
func _spheres(count: int) -> void:
	model.boss_pose("cast", 1.2)
	pulse_glow(1.8, 0.8)
	after(0.8, func() -> void:
		var base := aim_dir()
		for k in count:
			shoot(shot_origin(1.5), base.rotated(Vector3.UP, deg_to_rad((k-(count-1)*0.5)*(360.0/count if count>2 else 30.0))), _sphere(12 if phase<3 else 14)))

## Mind bubbles in a wide fan, each curving a different way.
func _bubbles(count: int) -> void:
	model.play_attack(0.6)
	var base := aim_dir()
	after(0.5, func() -> void:
		for k in count:
			var attack := _bubble(randf_range(3.4, 4.6))
			attack.turn = randf_range(-0.35, 0.35)
			shoot(shot_origin(), base.rotated(Vector3.UP, deg_to_rad((k-(count-1)*0.5)*(200.0/count))), attack))

## A stream of bubbles that sweeps across, then back.
func _bubble_stream() -> void:
	model.boss_pose("channel", 2.6)
	var base := aim_dir()
	for beat in 18:
		after(0.4+beat*0.13, func() -> void:
			var swing := sin(beat*0.35)*1.1
			var attack := _bubble(4.4)
			attack.turn = -swing*0.3
			shoot(shot_origin(1.0), base.rotated(Vector3.UP, swing), attack))

## Two rings of storm orbs, each with a pair of gaps.
func _storm_ring() -> void:
	var gap := atan2(-aim_dir().x, -aim_dir().z)+randf_range(-0.6, 0.6)
	mark_ring_gaps(gap, 40.0, 0.9, STORM)
	after(0.9, func() -> void: fire_ring(shot_origin(), 36, _orb(5.5), gap, 40.0))
	after(1.4, func() -> void: fire_ring(shot_origin(), 36, _orb(4.8), gap+0.18, 40.0))

## Lightning strikes along lanes from the Eye toward everyone.
func _lightning() -> void:
	for p in players():
		var dir: Vector3 = p.global_position-global_position
		dir.y = 0.0
		dir = dir.normalized()
		hazards.lane(global_position+dir*15.0, dir, 30.0, 1.6, 0.9, 0.35, Vector2i(154, 194), 0.35, STORM)
		for side: float in [-1.0, 1.0]:
			var d := dir.rotated(Vector3.UP, side*0.5)
			hazards.lane(global_position+d*15.0, d, 30.0, 1.4, 1.1, 0.35, Vector2i(154, 194), 0.35, STORM)

## Storm rays out of the Eye, turning.
func _rays(count: int, speed: float) -> void:
	model.boss_pose("cast", 1.2)
	_ray_speed = speed*(1.0 if randf()<0.5 else -1.0)
	for k in count:
		var offset := TAU*k/count
		var axis := func() -> Array:
			var dir := Vector3.FORWARD.rotated(Vector3.UP, _ray_angle+offset)
			return [global_position+dir*2.5, dir]
		hazards.ray(axis, 30.0, 1.1, 1.1, 5.0, Vector2i(145, 185), 0.55, STORM, {group = "storm_rays"})
	after(6.2, func() -> void: _ray_speed = 0.0)

func _spiral(arms: int, beats: int) -> void:
	model.boss_pose("channel", 3.4)
	_turn += 0.55
	var start := _turn
	for beat in beats:
		after(0.4+beat*0.14, func() -> void:
			for arm in arms:
				shoot(shot_origin(), Vector3.FORWARD.rotated(Vector3.UP, start+beat*0.17+arm*TAU/arms), _orb(5.8)))

## The storm: spirals both ways and a ring of lances every second, for five seconds.
func _storm() -> void:
	model.boss_pose("channel", 5.5)
	pulse_glow(2.0, 5.0)
	_spiral(4, 22)
	var start := -_turn
	for beat in 30:
		after(0.4+beat*0.16, func() -> void:
			for arm in 4:
				var attack := _orb(5.2)
				attack.turn = -0.12
				shoot(shot_origin(), Vector3.FORWARD.rotated(Vector3.UP, start-beat*0.15+arm*TAU/4.0), attack))
	for k in 5:
		after(0.8+k*1.0, func() -> void: fire_ring(shot_origin(), 24, _lance(6.0), randf()*TAU, 0.0))

## Freezing shards, spheres and bubbles all at once, aimed at different players.
func _barrage() -> void:
	model.boss_pose("cast", 1.4)
	pulse_glow(2.2, 1.0)
	var targets := players()
	for k in 3:
		after(0.6+k*0.45, func() -> void:
			var dir := aim_dir()
			if not targets.is_empty():
				var p: Node3D = targets[k % targets.size()]
				if is_instance_valid(p):
					dir = p.global_position-global_position
					dir.y = 0.0
					dir = dir.normalized()
			fire_fan(shot_origin(1.5), dir, 7, 9.0, _frost(10.0))
			shoot(shot_origin(1.5), dir.rotated(Vector3.UP, 0.6), _sphere(10))
			shoot(shot_origin(1.5), dir.rotated(Vector3.UP, -0.6), _sphere(10)))
	after(2.2, func() -> void: _bubbles(10))

## Lances that stop short and split into rings of orbs.
func _split_lances() -> void:
	var lance := _lance(9.0)
	lance.range = 10.0
	lance.terminal = {delay = 0.3, count = 10, attack = _orb(5.0)}
	for wave in 3:
		after(0.4+wave*0.35, func() -> void: fire_fan(shot_origin(1.5), aim_dir(), 5, 24.0, lance))

## Lightning circles under everyone and around the citadel floor.
func _lightning_circles() -> void:
	for p in players(): hazards.circle(in_arena(p.global_position, 27.0), 2.6, 0.9, Vector2i(145, 185), STORM)
	for k in 8:
		var a := TAU*k/8.0+randf()*0.4
		hazards.circle(in_arena(encounter_center+Vector3(cos(a), 0, sin(a))*randf_range(8.0, 25.0), 27.0), 2.6, 1.2, Vector2i(145, 185), RED)

func _shards(count: int) -> void:
	model.boss_pose("summon", 1.8)
	for i in count:
		var a := TAU*i/count+PI/count
		var helper := spawn_support("storm_shard_thrall", encounter_center+Vector3(cos(a), 0, sin(a))*16.0, "shards", true)
		if helper: arm_summon(helper, 0.2*i)
	var watcher := spawn_support("eye_watcher_thrall", encounter_center+Vector3(0, 0, 18.0), "shards", true)
	if watcher: arm_summon(watcher, 0.9)

# --- The squid arms ------------------------------------------------------------------

## Arms burst out of the floor round it. `hittable` arms have a body on the
## ground (vaelith_arm) that passes its hits to Vaelith; the others only slam.
func _grow_arms(count: int, hittable: bool) -> void:
	_clear_arms()
	model.boss_pose("summon", 2.0)
	CameraShake.shake_from(self, global_position, 0.6, boss_def.bar_radius)
	for i in count:
		var socket := TAU*i/count+randf_range(-0.15, 0.15)
		var tip := _arm_spot(socket, false)
		var arm := {enemy = null, socket = socket, tip = tip, from = tip, k = 1.0, mode = "slam", left = 0.0,
			dur = 0.25, hittable = false, alive = hittable}
		# Each arm starts up high and comes down on its own beat.
		arm.mode = "hold"
		arm.left = 1.0+i*0.45+randf_range(0.0, 0.5)
		hazards.circle(tip, 3.4, arm.left+arm.dur, Vector2i(150, 190), INK)
		if hittable:
			var body := spawn_support("vaelith_arm", tip, "arms", true, false)
			if body:
				body.max_hp = 1000000
				body.hp = body.max_hp
				body.model.visible = false
				arm.enemy = body
				_set_hittable(arm, false)
		_arms.append(arm)

## Where an arm lands next: round its socket, a bit random, sometimes on a player.
func _arm_spot(socket: float, may_target: bool) -> Vector3:
	if may_target and randf()<0.35:
		var near := players().filter(func(p: Node3D) -> bool:
			var flat := Vector2(p.global_position.x-encounter_center.x, p.global_position.z-encounter_center.z)
			return absf(angle_difference(atan2(flat.y, flat.x), socket))<PI/3.0)
		if not near.is_empty():
			return in_arena((near.pick_random() as Node3D).global_position, 24.0)
	var a := socket+randf_range(-0.3, 0.3)
	return in_arena(encounter_center+Vector3(cos(a), 0, sin(a))*randf_range(ARM_REACH.x, ARM_REACH.y), 24.0)

func _update_arms(delta: float) -> void:
	for arm: Dictionary in _arms:
		arm.left -= delta
		if arm.left>0.0:
			var t: float = 1.0-arm.left/arm.dur
			match arm.mode:
				"rise": arm.k = smoothstep(0.0, 1.0, t)  # slow up
				"slam": arm.k = 1.0-t*t  # fast down
			continue
		match arm.mode:
			"rest":
				# Up it goes, slowly: no longer hittable.
				arm.mode = "rise"
				arm.dur = randf_range(2.3, 3.4)
				_set_hittable(arm, false)
			"rise":
				arm.mode = "hold"
				arm.k = 1.0
				arm.dur = randf_range(0.4, 1.1)
				arm.from = arm.tip
				arm.tip = _arm_spot(arm.socket, true)
				hazards.circle(arm.tip, 3.4, arm.dur+0.25, Vector2i(150, 190), INK)
			"hold":
				arm.mode = "slam"
				arm.dur = 0.25
			"slam":
				arm.k = 0.0
				arm.mode = "rest"
				arm.dur = randf_range(2.6, 4.2) if arm.alive else randf_range(0.8, 1.6)
				_arm_impact(arm)
				_set_hittable(arm, arm.alive)
		arm.left = arm.dur
	if phase==1:
		_absorb_arm_hits()

## The arm hits the floor: the ground shakes, ink and sucker discs fly.
func _arm_impact(arm: Dictionary) -> void:
	var at: Vector3 = arm.tip
	CameraShake.shake_from(self, at, 0.45, 26.0)
	GameAudio.emit_from("boss_impact", self, {source_id = encounter_id, cooldown = 0.15, max_distance = 64.0})
	var body: Enemy = arm.enemy
	if is_instance_valid(body):
		body.global_position = at
	var o := at
	o.y = director.world.ground_height(o.x, o.z)+Player.SHOT_HEIGHT
	fire_ring(o, 12 if phase==1 else 10, _ink(5.2), randf()*TAU, 0.0)
	var dir := aim_dir(at)
	fire_fan(o, dir, 3, 22.0, _sucker(8.5))

func _set_hittable(arm: Dictionary, on: bool) -> void:
	arm.hittable = on
	var body: Enemy = arm.enemy
	if not is_instance_valid(body): return
	body.collision_layer = Player.ENEMY_LAYER if on else 0
	if on: body.buffs.remove("invincible", "vaelith_arm")
	else: body.buffs.add("invincible", 86400.0, 1, "vaelith_arm")

## Hits on the arms go to Vaelith (its own threshold caps still apply).
func _absorb_arm_hits() -> void:
	for arm: Dictionary in _arms:
		var body: Enemy = arm.enemy
		if not is_instance_valid(body) or body.hp>=body.max_hp: continue
		var lost := body.max_hp-body.hp
		body.hp = body.max_hp
		var credit: Dictionary = body._damage_by.duplicate()
		body._damage_by.clear()
		var until: float = boss_def.phases[phase].get("until", 0.0)
		var dealt := mini(lost, hp-int(floor(max_hp*until)))
		if dealt<=0: continue
		for by: int in credit:
			_damage_by[by] = _damage_by.get(by, 0)+int(round(float(credit[by])*dealt/lost))
			_last_by = by
		hp -= dealt
		GameAudio.emit_from("boss_hurt", self, {source_id = encounter_id, cooldown = 1.8, max_distance = 64.0})
		if float(hp)/max_hp<=until:
			_threshold_reached(phase+1)
			return

func _clear_arms() -> void:
	despawn_support("arms")
	_arms.clear()

# --- Arm visuals (server, offline and mirrors alike) ---------------------------------

func _arm_looks() -> void:
	if _arm_root != null: return
	_arm_root = Node3D.new()
	_arm_root.name = "SquidArms"
	_arm_root.top_level = true
	add_child(_arm_root)
	_arm_mesh = BoxMesh.new()
	_arm_mesh.size = Vector3.ONE
	_arm_mat = StandardMaterial3D.new()
	_arm_mat.albedo_color = ARM_COLOR
	_arm_mat.emission_enabled = true
	_arm_mat.emission = INK
	_arm_mat.emission_energy_multiplier = 0.35
	_arm_hot = _arm_mat.duplicate()
	_arm_hot.emission = FROST
	_arm_hot.emission_energy_multiplier = 1.3
	_sucker_mesh = BoxMesh.new()
	_sucker_mesh.size = Vector3(0.6, 0.25, 0.6)
	_sucker_mat = StandardMaterial3D.new()
	_sucker_mat.albedo_color = ARM_SUCKER
	_sucker_mat.emission_enabled = true
	_sucker_mat.emission = Color("ff78c8")
	_sucker_mat.emission_energy_multiplier = 0.6

## Lays each arm along a curve from the Eye's body to its tip.
func _draw_arms() -> void:
	if Net.is_server(): return
	var shown := _arm_view()
	if shown.is_empty() and _arm_nodes.is_empty(): return
	_arm_looks()
	while _arm_nodes.size()<shown.size():
		var segs := []
		for s in ARM_SEGMENTS:
			var mi := MeshInstance3D.new()
			mi.mesh = _arm_mesh
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			if s % 2==1:
				var sucker := MeshInstance3D.new()
				sucker.mesh = _sucker_mesh
				sucker.material_override = _sucker_mat
				sucker.position = Vector3(0, -0.5, 0)
				mi.add_child(sucker)
			_arm_root.add_child(mi)
			segs.append(mi)
		_arm_nodes.append(segs)
	var now := Time.get_ticks_msec()/1000.0
	var anchor := global_position+Vector3.UP*height()*0.3
	for i in _arm_nodes.size():
		var segs: Array = _arm_nodes[i]
		var on := i<shown.size()
		for mi: MeshInstance3D in segs: mi.visible = on
		if not on: continue
		var view: Array = shown[i]
		var tip: Vector3 = view[0]
		var k: float = view[1]
		var hot: bool = view[2]
		var out := Vector3(tip.x-anchor.x, 0, tip.z-anchor.z)
		var side := out.normalized().cross(Vector3.UP)
		var end := tip+Vector3.UP*(0.6+ARM_LIFT*k)-out*0.25*k
		var control := (anchor+end)*0.5+Vector3.UP*(2.5+5.0*k)+side*sin(now*1.7+i)*0.8
		var prev := anchor
		for s in ARM_SEGMENTS:
			var t := float(s+1)/ARM_SEGMENTS
			var p := anchor*(1.0-t)*(1.0-t)+control*2.0*(1.0-t)*t+end*t*t
			var mi: MeshInstance3D = segs[s]
			var length := prev.distance_to(p)
			var thick := lerpf(1.7, 0.5, t)
			mi.material_override = _arm_hot if hot else _arm_mat
			if length>0.01:
				mi.global_transform = Transform3D(Basis.looking_at(p-prev, Vector3.UP if absf((p-prev).normalized().y)<0.98 else Vector3.FORWARD),
					(prev+p)*0.5)
				mi.scale = Vector3(thick, thick, length*1.2)
			prev = p

## [[tip, height 0..1, hittable], ...] for each arm.
func _arm_view() -> Array:
	if mirror: return _mirror_arms
	var out := []
	for arm: Dictionary in _arms:
		var over: Vector3 = arm.tip
		if arm.mode=="hold":
			# Up high it swings over to where it will land.
			over = (arm.from as Vector3).lerp(arm.tip, smoothstep(0.0, 1.0, 1.0-arm.left/arm.dur))
		out.append([over, arm.k, arm.hittable])
	return out

var _mirror_arms: Array = []

func net_visuals() -> Array:
	return _arm_view()

func mirror_visuals(extra: Array) -> void:
	_mirror_arms = extra

func _reset_hook() -> void:
	_clear_arms()
	_turn = 0.0
	_ray_speed = 0.0
	resting = false
	status_text = ""

func _death_started() -> void:
	_ray_speed = 0.0
	_clear_arms()
	despawn_support("shards")
