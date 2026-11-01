extends Boss
## Rimeheart Prism, Crown of the Rime (Fosen). A living ice geode that stays
## at the stronghold's center and fights in turning rings.
##
## 1 Sealed Heart (100-70%)  a double helix: two counter-turning three-arm
##    streams weave a lattice, all phase long. Crystal blooms (slow orbs
##    that burst into six shards) and marked ice-spear eruptions between.
## 2 Hexagonal Conduit (70-35%)  two rings of six healing towers (6.2 m and
##    12 m, the outer ring turned 30 degrees), joined by beams. Living towers
##    heal it (never above 70%); while any tower stands or any of the eight
##    shardlings is unbroken, health can't fall below 35%. Shardlings rise
##    one at a time, eight in all. Inner and outer curtains alternate. The
##    Prism throws orbit rings (two speeds, interleaved, turning each cast)
##    and snowflake spokes along its towers.
##    Clearing the conduit stuns it for 3 s at defense 4; then the storm.
## 3 Rime Tempest (35-0%)  spins fast, four shard streams turning together
##    for seven seconds at a time, comet fans inside the storm and a closing
##    ring burst; almost no pause between storms.
## Phase changes are a three-second rest (Boss.begin_rest).

const ICE := Color(0.55, 0.9, 1.0)
const WARN := Color(0.45, 0.8, 1.0)
const INNER_RADIUS := 6.2
const OUTER_RADIUS := 12.0
const TOWER_HEAL := 0.0008  # share of max health per second, per living tower
const SHARDLING_TOTAL := 8
const SHARDLING_EVERY := 4.0
const BEAM_HEIGHT := 3.3

var _towers: Array = []  # 12 sockets (0-5 inner, 6-11 outer): Enemy or null
var _heal_cap := 0
var _heal_acc := 0.0
var _shard_timer := 0.0
var _shardlings_spawned := 0
var _curtain_timer := 0.0
var _curtain_parity := 0
var _curtains := {}  # edge index (0-5 inner, 6-11 outer) -> hazard
var _beams: Array[MeshInstance3D] = []  # inner edges, inner spokes, outer edges, outer links
var _conduit_done := false
var _stunned := 0.0
var _helix_timer := 0.0
var _helix_angle := 0.0
var _orbit_angle := 0.0
var _spoke_angle := 0.0
var _stream := 0.0  # > 0 while the tempest streams flow
var _stream_angle := 0.0
var _stream_sign := 1.0
var _stream_next := 0.0


func _hatch_update(k: float) -> void:
	super._hatch_update(k)
	# The inner prism rises out of the geode on a column of light.
	model.position.y = lerpf(-2.0, 0.0, clampf(k / 0.8, 0.0, 1.0))


func _phase_started(index: int) -> void:
	hazards.clear()
	behavior = "stationary"
	immune = false
	status_text = ""
	match index:
		0:
			_helix_timer = 0.6
			set_cycle(8.0, [[1.0, _bloom], [4.2, _spears], [6.0, _bloom]])
		1:
			_start_conduit()
		2:
			_end_conduit_visuals()
			spin_rate = 0.0
			model.boss_pose("storm", 999.0)
			pulse_glow(2.0, 0.6)
			after(0.6, func() -> void: spin_rate = 8.0)
			_stream_sign = 1.0
			set_cycle(8.4, [[0.0, _tempest_charge], [3.6, _comets], [7.6, _closing_ring]])


func _threshold_reached(next: int) -> void:
	if resting: return
	_stream = 0.0
	spin_rate = 0.0
	begin_rest(func() -> void: _enter_phase(next), "The Prism draws in the cold", "kneel")


func _combat(delta: float) -> void:
	if resting: return
	match phase:
		0:
			_helix(delta)
		1:
			_conduit(delta)
		2:
			_tempest(delta)


# --- Phase 1 --------------------------------------------------------------------------

## Two three-arm streams turning opposite ways: a weaving lattice.
func _helix(delta: float) -> void:
	_helix_timer -= delta
	while _helix_timer <= 0.0:
		_helix_timer += 0.42
		_helix_angle = wrapf(_helix_angle + deg_to_rad(13.0), 0.0, TAU)
		var a := Boss.shot("shard", ICE, Vector2i(45, 55), 6.5, 0.15, 22.0)
		var b := Boss.shot("shard", Color(0.75, 0.95, 1.0), Vector2i(45, 55), 5.5, 0.15, 22.0)
		for k in 3:
			shoot(shot_origin(), Vector3.FORWARD.rotated(Vector3.UP, _helix_angle + k * TAU / 3.0), a)
			shoot(shot_origin(), Vector3.FORWARD.rotated(Vector3.UP, -_helix_angle + k * TAU / 3.0 + PI / 3.0), b)


## Eight slow crystal orbs; each stops and bursts into six shards.
func _bloom() -> void:
	model.boss_pose("bloom", 1.6)
	pulse_glow(2.0, 0.7)
	var offset := randf() * TAU
	after(0.7, func() -> void:
		var burst := Boss.shot("shard", ICE, Vector2i(45, 55), 6.0, 0.14, 12.0)
		var orb := Boss.shot("orb", Color(0.7, 0.95, 1.0), Vector2i(70, 85), 4.0, 0.4, 8.0,
				{size = 1.5, terminal = {delay = 0.35, count = 6, attack = burst}})
		for k in 8:
			shoot(shot_origin(), Vector3.FORWARD.rotated(Vector3.UP, offset + k * TAU / 8.0), orb))


func _spears() -> void:
	model.boss_pose("cast", 1.0)
	var at := target().global_position
	for offset: Vector3 in [Vector3.ZERO, Vector3(1.7, 0, 0.9), Vector3(-1.4, 0, -1.4), Vector3(0.4, 0, 2.1)]:
		hazards.circle(in_arena(at + offset, 22.0), 0.9, 1.1, Vector2i(75, 85), WARN)


# --- Phase 2: the conduit ---------------------------------------------------------------

func _tower_socket(i: int) -> Vector3:
	var outer := i >= 6
	var a := TAU * (i % 6) / 6.0 + (PI / 6.0 if outer else 0.0)
	return encounter_center + Vector3(cos(a), 0, sin(a)) * (OUTER_RADIUS if outer else INNER_RADIUS)


## Tower indices at both ends of a curtain edge.
static func _edge(e: int) -> Array:
	return [e, (e + 1) % 6] if e < 6 else [6 + (e - 6), 6 + (e - 5) % 6]


func _start_conduit() -> void:
	_heal_cap = int(floor(max_hp * 0.7))
	_towers.clear()
	model.boss_pose("summon", 2.0)
	pulse_glow(2.6, 2.0)
	for i in 12:
		# Fixed sockets: a blocked socket fails open (counted as destroyed).
		var tower: Enemy = spawn_support("rimeheart_conduit", _tower_socket(i), "objective", true)
		_towers.append(tower)
	hp_floor = int(ceil(max_hp * 0.35))
	_conduit_done = false
	_heal_acc = 0.0
	_curtain_timer = 2.0
	_curtain_parity = 0
	_curtains.clear()
	_shardlings_spawned = 0
	_shard_timer = 2.0
	_orbit_angle = 0.0
	_spoke_angle = 0.0
	_build_beams()
	status_text = "Break the twelve conduits"
	set_cycle(6.0, [[0.8, _orbit_rings], [2.8, _spokes], [4.6, _orbit_rings]])


func _living_towers() -> Array:
	var out := []
	for i in _towers.size():
		var t: Variant = _towers[i]
		if t != null and is_instance_valid(t) and (t as Enemy).is_alive():
			out.append(i)
		else:
			_towers[i] = null
	return out


func _conduit(delta: float) -> void:
	if _stunned > 0.0:
		_stunned -= delta
		if _stunned <= 0.0:
			_after_stun()
		return
	if _conduit_done:
		return
	var living := _living_towers()
	defense = 14 + living.size()
	_shard_timer -= delta
	if _shard_timer <= 0.0 and _shardlings_spawned < SHARDLING_TOTAL:
		_shard_timer = SHARDLING_EVERY
		_summon_shardling()
	if living.is_empty() and _shardlings_spawned >= SHARDLING_TOTAL and support("add").is_empty():
		_conduits_broken()
		return
	# Healing, proportional to time and to living towers, capped at 70%.
	_heal_acc += max_hp * TOWER_HEAL * living.size() * delta
	if _heal_acc >= 1.0:
		heal(floorf(_heal_acc), _heal_cap)
		_heal_acc -= floorf(_heal_acc)
	_update_beams(living)
	_update_curtains(delta, living)


## One shardling at a time rises from the outer apron, away from the player.
func _summon_shardling() -> void:
	var away := encounter_center - target().global_position
	var a := atan2(away.x, away.z) + randf_range(-0.9, 0.9)
	var pos := encounter_center + Vector3(sin(a), 0, cos(a)) * 9.0
	_shardlings_spawned += 1
	hazards.marker(pos, 0.9, 0.8, Color(0.7, 0.95, 1.0))
	after(0.8, func() -> void:
		var shardling := spawn_support("rimeheart_shardling", pos, "add", true)
		if shardling:
			arm_summon(shardling))


## Two interleaved rings of sixteen at two speeds, turned a little each cast.
func _orbit_rings() -> void:
	model.boss_pose("cast", 1.0)
	pulse_glow(1.6, 0.5)
	_orbit_angle += TAU / 64.0 * 3.0
	var start := _orbit_angle
	after(0.5, func() -> void:
		for k in 16:
			var fast := k % 2 == 0
			shoot(shot_origin(), Vector3.FORWARD.rotated(Vector3.UP, start + k * TAU / 16.0),
					Boss.shot("shard", ICE if fast else Color(0.8, 0.97, 1.0), Vector2i(50, 60), 7.0 if fast else 4.5, 0.15, 24.0)))


## Six spokes along the hexagon, each a line of four shards at rising speeds.
func _spokes() -> void:
	model.boss_pose("bloom", 1.2)
	pulse_glow(2.0, 0.6)
	_spoke_angle += PI / 6.0
	var start := _spoke_angle
	after(0.6, func() -> void:
		for k in 6:
			var dir := Vector3.FORWARD.rotated(Vector3.UP, start + k * TAU / 6.0)
			for speed in [4.0, 5.5, 7.0, 8.5]:
				shoot(shot_origin(), dir, Boss.shot("shard", ICE, Vector2i(50, 60), speed, 0.15, 24.0)))


func _update_curtains(delta: float, living: Array) -> void:
	# A curtain dies the moment either of its towers does.
	for edge in _curtains.keys():
		var ends := _edge(edge)
		if not (ends[0] in living and ends[1] in living):
			hazards.remove(_curtains[edge])
			_curtains.erase(edge)
	_curtain_timer -= delta
	if _curtain_timer > 0.0:
		return
	_curtain_timer = 5.0  # 0.8 warning + 2.0 active + 2.2 rest
	_curtains.clear()
	# Alternate inner edges, and the outer edges between them.
	for edge in range(_curtain_parity, 6, 2) + range(6 + 1 - _curtain_parity, 12, 2):
		var ends := _edge(edge)
		if ends[0] in living and ends[1] in living:
			var a: Vector3 = (_towers[ends[0]] as Enemy).global_position
			var b: Vector3 = (_towers[ends[1]] as Enemy).global_position
			_curtains[edge] = hazards.segment(a, b, 0.6, 0.8, 2.0, Vector2i(55, 65), 0.7, ICE,
					{group = "curtains", height = BEAM_HEIGHT})
	_curtain_parity = 1 - _curtain_parity


func _conduits_broken() -> void:
	_conduit_done = true
	hp_floor = 0
	status_text = "The Prism is stunned!"
	_end_conduit_visuals()
	for edge in _curtains:
		hazards.remove(_curtains[edge])
	_curtains.clear()
	_cycle_events = []
	# Stunned and open for three seconds; the storm follows straight after.
	_stunned = 3.0
	defense = 4
	cap_thresholds = false
	model.boss_pose("stun", 3.0)
	hazards.marker(encounter_center, OUTER_RADIUS, 1.0, Color(0.4, 0.7, 1.0))
	CameraShake.shake_from(self, global_position, 0.5, boss_def.bar_radius)


func _after_stun() -> void:
	cap_thresholds = true
	defense = 14
	status_text = ""
	model.boss_pose("rise", 0.75)
	if float(hp) / max_hp <= 0.35:
		_enter_phase(2)  # the stun was its rest
	else:
		set_cycle(5.0, [[0.5, _orbit_rings], [2.5, _spokes]])


func _build_beams() -> void:
	_end_conduit_visuals()
	for i in 24:
		var mi := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.12, 0.12, 1.0)
		mi.mesh = mesh
		mi.material_override = BossHazards._material(ICE if i % 12 < 6 else Color(0.5, 1.0, 0.85))
		mi.transparency = 0.45
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		director.add_child(mi)
		_beams.append(mi)


## Beams 0-5 inner edges, 6-11 inner towers to the heart, 12-17 outer
## edges, 18-23 outer towers to their inner neighbours.
func _beam_ends(i: int) -> Array:
	var t := i % 6
	match i / 6:
		0: return [t, (t + 1) % 6]
		1: return [t, -1]
		2: return [6 + t, 6 + (t + 1) % 6]
		_: return [6 + t, t]


func _update_beams(living: Array) -> void:
	var heart := global_position + Vector3.UP * height() * 0.55
	for i in _beams.size():
		var mi := _beams[i]
		var ends := _beam_ends(i)
		var ok: bool = ends[0] in living and (ends[1] == -1 or ends[1] in living)
		mi.visible = ok
		if not ok:
			continue
		var a: Vector3 = (_towers[ends[0]] as Enemy).global_position + Vector3.UP * BEAM_HEIGHT
		var b: Vector3 = heart if ends[1] == -1 else (_towers[ends[1]] as Enemy).global_position + Vector3.UP * BEAM_HEIGHT
		mi.global_position = (a + b) * 0.5
		mi.look_at(b)
		mi.scale = Vector3(1, 1, a.distance_to(b))


func _end_conduit_visuals() -> void:
	for mi in _beams:
		if is_instance_valid(mi):
			mi.queue_free()
	_beams.clear()


## Phase 2's health floor lets nothing through: say why.
func _on_blocked() -> void:
	if phase == 1 and not _conduit_done:
		var left := SHARDLING_TOTAL - _shardlings_spawned + support("add").size()
		status_text = "Break the conduits  ·  %d towers, %d shardlings left" % [_living_towers().size(), left]


func bar_pips() -> Array:
	if phase != 1:
		return super.bar_pips()
	var out := []
	for t in _towers:
		out.append({color = ICE, alive = t != null and is_instance_valid(t) and (t as Enemy).is_alive()})
	return out


# --- Phase 3: the tempest ----------------------------------------------------------------

func _tempest_charge() -> void:
	pulse_glow(2.4, 0.5)
	var aim := aim_dir()
	_stream_angle = atan2(-aim.x, -aim.z)  # Vector3.FORWARD rotated by this = aim
	after(0.5, func() -> void:
		_stream = 7.0
		_stream_next = 0.0)


func _tempest(delta: float) -> void:
	if _stream <= 0.0:
		return
	_stream -= delta
	_stream_angle += 0.55 * _stream_sign * delta  # much slower than the visual spin
	_stream_next -= delta
	while _stream_next <= 0.0 and _stream > 0.0:
		_stream_next += 0.2
		var attack := Boss.shot("shard", ICE, Vector2i(60, 75), 6.5, 0.15, 24.0)
		for k in 4:
			shoot(shot_origin(), Vector3.FORWARD.rotated(Vector3.UP, _stream_angle + k * PI * 0.5), attack)
	if _stream <= 0.0:
		_stream_sign = -_stream_sign  # the next storm turns the other way


func _comets() -> void:
	var dir := aim_dir()
	hazards.lane(global_position + dir * 6.0, dir, 12.0, 1.2, 0.7, 0.0, Vector2i.ZERO, 0.0, WARN)
	pulse_glow(2.0, 0.7)
	after(0.7, func() -> void:
		fire_fan(shot_origin(), dir, 3, 10.0, Boss.shot("comet", Color(0.75, 0.95, 1.0), Vector2i(75, 90), 7.5, 0.25, 22.0, {size = 1.2})))


## As each storm ends: a full ring that leaves no gaps, at half the speed.
func _closing_ring() -> void:
	var offset := randf() * TAU
	for k in 28:
		shoot(shot_origin(), Vector3.FORWARD.rotated(Vector3.UP, offset + k * TAU / 28.0),
				Boss.shot("shard", Color(0.8, 0.97, 1.0), Vector2i(50, 60), 4.0, 0.15, 24.0))


func _reset_hook() -> void:
	_end_conduit_visuals()
	_towers.clear()
	_curtains.clear()
	_conduit_done = false
	_stunned = 0.0
	_stream = 0.0
	resting = false
	spin_rate = 0.0
	model.boss_pose("idle", 0.1)


func _death_started() -> void:
	_end_conduit_visuals()
	_stream = 0.0
	spin_rate = 0.0
	model.boss_pose("defeated", boss_def.death_time + 1.0)


## The conduit beams: [index, from, to] for each one showing.
func net_visuals() -> Array:
	var out := []
	for i in _beams.size():
		var mi := _beams[i]
		if is_instance_valid(mi) and mi.visible:
			var half := mi.global_basis.z.normalized() * mi.scale.z * 0.5
			out.append([i, mi.global_position - half, mi.global_position + half])
	return out


func mirror_visuals(extra: Array) -> void:
	if extra.is_empty():
		if not _beams.is_empty():
			_end_conduit_visuals()
		return
	if _beams.is_empty():
		_build_beams()
	var shown := {}
	for beam: Array in extra:
		var i := int(beam[0])
		if i < 0 or i >= _beams.size():
			continue
		shown[i] = true
		var mi := _beams[i]
		var a: Vector3 = beam[1]
		var b: Vector3 = beam[2]
		mi.global_position = (a + b) * 0.5
		if a.distance_to(b) > 0.01:
			mi.look_at(b)
		mi.scale = Vector3(1, 1, a.distance_to(b))
	for i in _beams.size():
		_beams[i].visible = shown.has(i)
