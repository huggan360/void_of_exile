class_name SpaceFoes
extends Node3D
## The brood's ships between the stars. The authority flies them and resolves
## every bolt; clients draw BroodShip art between snapshots.
##
## They hunt only ships in open space. A ship that lands, docks or drops into
## a planet's air is left alone (the brood never enters air), so nothing ever
## shoots at a crew on the ground. Behaviour per kind:
## - skiffs fly in wings and make attack runs: close in, fire bursts with lead,
##   overshoot, swing out and come again;
## - void eels circle at a distance and fire spreads of spines, lunging now
##   and then;
## - carriers stand off, lob heavy acid and launch skiffs.
## Everyone steers around planets, the Nexus and the Shardfield's rocks.
signal foe_killed(kind: String, ship_id: int, at: Vector3)
const KINDS := {
	brood_skiff = {hp = 320, speed = 270.0, turn = 2.4, radius = 10.0, damage = 34, burst = 3, cooldown = 2.2, range = 650.0, bolt = 400.0},
	void_eel = {hp = 1500, speed = 175.0, turn = 1.3, radius = 18.0, damage = 52, burst = 5, cooldown = 3.4, range = 900.0, bolt = 340.0},
	brood_carrier = {hp = 5200, speed = 80.0, turn = 0.45, radius = 46.0, damage = 160, burst = 1, cooldown = 5.0, range = 1600.0, bolt = 210.0},
	brood_mother = {hp = 9800, speed = 70.0, turn = 0.35, radius = 70.0, damage = 220, burst = 2, cooldown = 4.0, range = 1800.0, bolt = 220.0},
}
## Brood near a flying ship per region (a wing at a time); ambushes add more.
const CAP := {haven = 0, shardfield = 4, gloam = 7}
const BOLT_SPEED := 460.0
const BOLT_DAMAGE := 120
const LOSE_INTEREST := 5000.0
var world: SpaceWorld
var foes := {}  # id -> {id, kind, pos, vel, fwd, hp, target, cooldown, state, timer, shots, home}
var surface_combat := false  # Surface ships share bolts without spawning the space brood.
var _bolts: Array = []  # authority: {pos, vel, life, friendly, ship, damage, radius}
var _views := {}  # id -> {node, target, vel}
var _next := 1
var _snapshot := 0.0
var _spawn_timer := 0.0
var _rng := RandomNumberGenerator.new()
var _bolt_meshes := {}
var _bolt_materials := {}
var _next_bolt := 1
var _bolt_snapshot := 0.0
var _lock_cursor := {}
var _visual_bolts: Array = []  # [node, vel, life]
var _rock_grid := {}
## Campaign hook: extra foes requested near a point {at, kind, count}.
var ambushes: Array = []

const ROCK_CELL := 400.0

func _ready() -> void:
	_rng.randomize()
	if surface_combat: return
	for rock: Array in SpaceLayout.asteroids():
		var key := Vector3i((rock[0] as Vector3)/ROCK_CELL)
		if not _rock_grid.has(key): _rock_grid[key] = []
		_rock_grid[key].append(rock)

func authority() -> bool:
	return not Net.is_client()

func _physics_process(delta: float) -> void:
	_update_visual_bolts(delta)
	if authority(): _simulate(delta)
	else: _interpolate(delta)

# --- Rules ---------------------------------------------------------------------------

## A ship the brood may hunt: flying, in open space (outside every planet's air).
static func huntable(ship: SpaceShip) -> bool:
	if ship==null or ship.mode!="flying": return false
	return SpaceFoes.in_air(ship.xform.origin).is_empty()

## The planet whose air (with a margin) holds `at`, or {}.
static func in_air(at: Vector3, margin := 250.0) -> Dictionary:
	for p: Dictionary in SpaceLayout.PLANETS:
		if at.distance_to(p.center)<float(p.radius)+SpaceLayout.air_height(p)+margin: return p
	return {}

# --- Authority ---------------------------------------------------------------------

func _simulate(delta: float) -> void:
	if surface_combat:
		_fly_bolts(delta)
		return
	_spawn_timer -= delta
	if _spawn_timer<=0.0:
		_spawn_timer = 2.0
		_populate()
	var hunted: Array = world.ships.values().filter(func(s: SpaceShip) -> bool: return huntable(s))
	for foe: Dictionary in foes.values().duplicate():
		_think(foe, hunted, delta)
	_fly_bolts(delta)
	_snapshot -= delta
	if _snapshot<=0.0 and not foes.is_empty():
		_snapshot = 0.1
		_emit(["foes", foes.values().map(func(f: Dictionary) -> Array: return [f.id, f.kind, f.pos, f.vel, f.fwd, float(f.hp)/float(KINDS[f.kind].hp), bool(f.get("targetable", true))])])

func _think(foe: Dictionary, hunted: Array, delta: float) -> void:
	var spec: Dictionary = KINDS[foe.kind]
	var pos: Vector3 = foe.pos
	var target: SpaceShip = world.ships.get(int(foe.target))
	if target==null or not huntable(target):
		target = _nearest(hunted, pos)
		foe.target = target.id if target else 0
	foe.timer = float(foe.timer)-delta
	foe.cooldown = float(foe.cooldown)-delta
	var goal: Vector3 = foe.home
	var speed := float(spec.speed)
	if target==null:
		# Nobody to hunt: drift back toward where they gathered, and fade away when far from everyone.
		foe.state = "patrol"
		goal = (foe.home as Vector3)+Vector3(sin(Time.get_ticks_msec()/4000.0+foe.id), 0.2, cos(Time.get_ticks_msec()/4000.0+foe.id))*400.0
		speed *= 0.5
		if _nearest(world.ships.values(), pos)==null or (_nearest(world.ships.values(), pos).xform.origin.distance_to(pos)>LOSE_INTEREST):
			foe.idle = float(foe.get("idle", 0.0))+delta
			if float(foe.idle)>20.0:
				_remove(foe, false, 0)
				return
	else:
		foe.idle = 0.0
		foe.home = target.xform.origin
		var at := target.xform.origin
		var to := at-pos
		var dist := to.length()
		match str(foe.kind):
			"brood_skiff":
				# Attack runs: in, burst, past, out, around.
				if foe.state!="run" and foe.state!="out": foe.state = "run"
				if foe.state=="run":
					goal = at+target.velocity*clampf(dist/float(spec.bolt), 0.0, 1.5)
					if dist<120.0:
						foe.state = "out"
						foe.timer = _rng.randf_range(2.5, 4.0)
						foe.away = (pos-at).normalized().slerp(Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-0.5, 0.5), _rng.randf_range(-1, 1)).normalized(), 0.5)
				else:
					goal = at+(foe.away as Vector3)*700.0
					speed *= 1.15
					if float(foe.timer)<=0.0: foe.state = "run"
			"void_eel":
				# Circle at spine range; now and then a lunge through.
				if foe.state=="lunge":
					goal = at
					speed *= 1.6
					if dist<90.0 or float(foe.timer)<=0.0:
						foe.state = "circle"
						foe.timer = _rng.randf_range(8.0, 13.0)
				else:
					foe.state = "circle"
					var side := to.cross(Vector3.UP).normalized()
					if side.length()<0.1: side = Vector3.RIGHT
					goal = at-to.normalized()*420.0+side*260.0
					if float(foe.timer)<=0.0:
						foe.state = "lunge"
						foe.timer = 5.0
			_:
				# Carriers keep their distance and let the swarm do the work.
				goal = at-to.normalized()*900.0
				if float(foe.timer)<=0.0:
					foe.timer = 14.0
					var wing := foes.values().filter(func(f: Dictionary) -> bool: return f.kind=="brood_skiff" and int(f.get("mother", 0))==int(foe.id)).size()
					for k in mini(3, 6-wing):
						var spawned := _spawn("brood_skiff", pos-(foe.fwd as Vector3)*float(spec.radius)+Vector3(_rng.randf_range(-20, 20), _rng.randf_range(-10, 10), _rng.randf_range(-20, 20)), target.id)
						spawned.mother = foe.id
		# Fire when the target is ahead and in range.
		var ahead := (foe.fwd as Vector3).dot(to.normalized())
		var wide := str(foe.kind)!="brood_skiff"
		if float(foe.cooldown)<=0.0 and dist<float(spec.range) and (ahead>0.85 or wide):
			foe.cooldown = float(spec.cooldown)*_rng.randf_range(0.85, 1.2)
			foe.shots = int(spec.burst)
			foe.shot_timer = 0.0
		if int(foe.get("shots", 0))>0:
			foe.shot_timer = float(foe.get("shot_timer", 0.0))-delta
			if float(foe.shot_timer)<=0.0:
				foe.shot_timer = 0.12
				foe.shots = int(foe.shots)-1
				var lead := at+target.velocity*(dist/float(spec.bolt))
				var aim := (lead-pos).normalized()
				if str(foe.kind)=="void_eel":
					var spread := (int(spec.burst)-1)*0.5-int(foe.shots)
					aim = aim.rotated(Vector3.UP, spread*0.06)
				_shoot(pos+(foe.fwd as Vector3)*float(spec.radius), aim*float(spec.bolt), false, 0, int(spec.damage), 3.0 if str(foe.kind).begins_with("brood_c") or str(foe.kind)=="brood_mother" else 1.0)
	_steer(foe, spec, goal, speed, delta)

## Turn toward the goal at the kind's turn rate, pushed off planets' air, the
## Nexus and rocks, then move.
func _steer(foe: Dictionary, spec: Dictionary, goal: Vector3, speed: float, delta: float) -> void:
	var pos: Vector3 = foe.pos
	var want := (goal-pos).normalized() if pos.distance_to(goal)>1.0 else foe.fwd as Vector3
	for p: Dictionary in SpaceLayout.PLANETS:
		var c: Vector3 = p.center
		var keep := float(p.radius)+SpaceLayout.air_height(p)+200.0
		var d := pos.distance_to(c)
		if d<keep+600.0:
			want += (pos-c).normalized()*clampf((keep+600.0-d)/600.0, 0.0, 3.0)
	var nexus := pos.distance_to(SpaceLayout.NEXUS)
	if nexus<700.0: want += (pos-SpaceLayout.NEXUS).normalized()*(700.0-nexus)/200.0
	var cell := Vector3i(pos/ROCK_CELL)
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			for dz in range(-1, 2):
				for rock: Array in _rock_grid.get(cell+Vector3i(dx, dy, dz), []):
					var r := float(rock[1])+float(spec.radius)+30.0
					var off: Vector3 = pos-(rock[0] as Vector3)
					if off.length()<r*1.8: want += off.normalized()*(r*1.8-off.length())/r
	if pos.length()>SpaceLayout.WORLD_RADIUS-SpaceLayout.BOUNDARY_WARN: want += -pos.normalized()*2.0
	want = want.normalized()
	var fwd: Vector3 = foe.fwd
	var angle := fwd.angle_to(want)
	if angle>0.001:
		var axis := fwd.cross(want)
		if axis.length()<0.001: axis = Vector3.UP
		fwd = fwd.rotated(axis.normalized(), minf(angle, float(spec.turn)*delta))
	foe.fwd = fwd.normalized()
	foe.vel = (foe.vel as Vector3).lerp(fwd*speed, 1.0-exp(-delta*2.0))
	foe.pos = pos+(foe.vel as Vector3)*delta

func _fly_bolts(delta: float) -> void:
	for bolt: Dictionary in _bolts.duplicate():
		bolt.life = float(bolt.life)-delta
		var from: Vector3 = bolt.pos
		if bolt.friendly:
			bolt.vel = TurretTargeting.steer(bolt.vel, bolt.initial, from, TurretTargeting.sample(bolt.get("target", {}), world), delta)
		bolt.pos = from+(bolt.vel as Vector3)*delta
		var done := float(bolt.life)<=0.0
		if bolt.friendly:
			# Sweep the entire step so fast cannon bolts cannot skip ground
			# enemies or pass through terrain and buildings.
			var query := PhysicsRayQueryParameters3D.create(from, bolt.pos, Player.TERRAIN_LAYER | Player.OBSTACLE_LAYER | Player.ENEMY_LAYER)
			var impact := get_world_3d().direct_space_state.intersect_ray(query)
			var end: Vector3 = impact.position if not impact.is_empty() else bolt.pos
			for foe: Dictionary in foes.values():
				if Geometry3D.get_closest_point_to_segment(foe.pos, from, end).distance_to(foe.pos)<float(KINDS[foe.kind].radius):
					foe.hp = int(foe.hp)-BOLT_DAMAGE
					_emit(["hit", bolt.pos, "foe", int(foe.id), float(foe.hp)/float(KINDS[foe.kind].hp)])
					if int(foe.hp)<=0: _remove(foe, true, int(bolt.ship))
					done = true
					break
			var locked: Dictionary = bolt.get("target", {})
			if not done and str(locked.get("kind", ""))=="flag":
				var flag := (locked.flag as WeakRef).get_ref() as TargetFlag
				if is_instance_valid(flag) and flag.eligible() and not flag.get_parent() is Enemy:
					if Geometry3D.get_closest_point_to_segment(flag.global_position, from, end).distance_to(flag.global_position)<=flag.hit_radius:
						flag.receive_hit(int(bolt.damage), (bolt.vel as Vector3).normalized(), _gunner_source(int(bolt.get("gunner", 0))))
						_emit(["hit", flag.global_position, "ground", 0])
						done = true
			if not done and not impact.is_empty():
				var enemy := impact.collider as Enemy
				if is_instance_valid(enemy):
					var gunner := int(bolt.get("gunner", 0))
					var source: Node = world.local_player
					if Net.is_server():
						var realm: RealmInstance = Net.server.realms.get(world.realm_id)
						source = realm.proxies.get(gunner) if realm else null
					if is_instance_valid(source):
						var before := enemy.hp
						enemy.take_hit(end, (bolt.vel as Vector3).normalized(), int(bolt.damage), source)
						if enemy.hp<before: GameServer.report_hit_landed(gunner)
				else:
					var flag := TargetFlag.for_body(impact.collider)
					if is_instance_valid(flag): flag.receive_hit(int(bolt.damage), (bolt.vel as Vector3).normalized(), _gunner_source(int(bolt.get("gunner", 0))))
				_emit(["hit", end, "ground", 0])
				done = true
		else:
			for ship: SpaceShip in world.ships.values():
				if not huntable(ship): continue
				var radius := SpaceShip.RADIUS*float(bolt.get("radius", 1.0))
				if Geometry3D.get_closest_point_to_segment(ship.xform.origin, from, bolt.pos).distance_to(ship.xform.origin)<radius:
					world.hurt_ship(ship, int(bolt.damage), bolt.pos)
					_emit(["hit", bolt.pos, "ship", ship.id, float(ship.hp)/float(SpaceShip.MAX_HP)])
					done = true
					break
		if done:
			_emit(["bolt_end", int(bolt.id)])
			_bolts.erase(bolt)
	_bolt_snapshot -= delta
	if _bolt_snapshot<=0.0:
		_bolt_snapshot = 0.1
		var paths: Array = []
		for bolt: Dictionary in _bolts:
			if bolt.friendly: paths.append([bolt.id, bolt.pos, bolt.vel])
		if not paths.is_empty(): _emit(["bolt_path", paths])

func _gunner_source(gunner: int) -> Node:
	if Net.is_server():
		var realm: RealmInstance = Net.server.realms.get(world.realm_id)
		return realm.proxies.get(gunner) if realm else null
	return world.local_player

func _remove(foe: Dictionary, killed: bool, by_ship: int) -> void:
	foes.erase(foe.id)
	_emit(["foe-", foe.id, foe.pos, killed])
	if killed: foe_killed.emit(str(foe.kind), by_ship, foe.pos)

## Wings gather around ships flying in the Shardfield and the Gloam; ambushes
## (campaigns) come where asked, but always out in open space.
func _populate() -> void:
	for ship: SpaceShip in world.ships.values():
		if not huntable(ship): continue
		var region := SpaceLayout.region_at(ship.xform.origin)
		var near := foes.values().filter(func(f: Dictionary) -> bool: return (f.pos as Vector3).distance_to(ship.xform.origin)<2500.0).size()
		var cap := int(CAP.get(region, 0))
		if near>=cap: continue
		var origin := ship.xform.origin-ship.xform.basis.z*1600.0+Vector3(_rng.randf_range(-600, 600), _rng.randf_range(-250, 250), _rng.randf_range(-600, 600))
		if not in_air(origin).is_empty(): continue
		var roll := _rng.randf()
		if region=="gloam" and roll<0.12 and not foes.values().any(func(f: Dictionary) -> bool: return f.kind=="brood_carrier"):
			_spawn("brood_carrier", origin, ship.id)
		elif region=="gloam" and roll<0.5:
			_spawn("void_eel", origin, ship.id)
		else:
			for k in mini(3, cap-near):
				_spawn("brood_skiff", origin+Vector3(k*40.0, k*12.0, 0), ship.id)
	for ambush: Dictionary in ambushes.duplicate():
		var at := _open_space(ambush.at as Vector3)
		var kind := str(ambush.kind)
		for i in int(ambush.count):
			_spawn(kind, at+Vector3(_rng.randf_range(-260, 260), _rng.randf_range(-90, 90), _rng.randf_range(-260, 260)), 0)
		ambushes.erase(ambush)

## A point near `at` outside every planet's air (toward the nearest ship).
func _open_space(at: Vector3) -> Vector3:
	var p := in_air(at)
	if p.is_empty(): return at
	var toward := at
	var ship := _nearest(world.ships.values(), at)
	if ship: toward = ship.xform.origin
	var out := (toward-(p.center as Vector3)).normalized()
	if out.length()<0.1: out = Vector3.UP
	return (p.center as Vector3)+out*(float(p.radius)+SpaceLayout.air_height(p)+700.0)

func _spawn(kind: String, at: Vector3, target: int) -> Dictionary:
	var spec: Dictionary = KINDS.get(kind, KINDS.brood_skiff)
	var foe := {id = _next, kind = kind if KINDS.has(kind) else "brood_skiff", pos = at, vel = Vector3.ZERO, fwd = Vector3.FORWARD, hp = int(spec.hp),
		target = target, targetable = true, cooldown = 3.0, state = "", timer = _rng.randf_range(3.0, 8.0), shots = 0, home = at, idle = 0.0}
	_next += 1
	foes[foe.id] = foe
	return foe

func _nearest(ships: Array, at: Vector3) -> SpaceShip:
	var best: SpaceShip
	for ship: SpaceShip in ships:
		if best==null or ship.xform.origin.distance_to(at)<best.xform.origin.distance_to(at): best = ship
	return best

## A cannon bolt from a ship's turret (authority).
func fire_bolt(ship: SpaceShip, from: Vector3, dir: Vector3, gunner := 0) -> void:
	var targets := TurretTargeting.select(world, from, dir)
	var target := {}
	if not targets.is_empty():
		var key := "%d:%d" % [ship.id, gunner]
		var cursor := int(_lock_cursor.get(key, 0))
		target = targets[cursor % targets.size()]
		_lock_cursor[key] = (cursor+1) % targets.size()
	var bolt := _shoot(from, dir*BOLT_SPEED+ship.velocity, true, ship.id, BOLT_DAMAGE, 1.0, gunner)
	bolt.target = target

func _shoot(from: Vector3, vel: Vector3, friendly: bool, ship: int, damage: int, size: float, gunner := 0) -> Dictionary:
	var bolt := {id = _next_bolt, pos = from, vel = vel, initial = vel.normalized(), life = 3.2, friendly = friendly, ship = ship, gunner = gunner, damage = damage, radius = 1.0+size*0.1}
	_next_bolt += 1
	_bolts.append(bolt)
	_emit(["bolt", from, vel, friendly, size, bolt.id])
	return bolt

func _emit(event: Array) -> void:
	if not (world.server_build or Net.is_server()): handle_event(event)
	world.world_event.emit(event)

# --- Clients ---------------------------------------------------------------------------

func handle_event(event: Array) -> void:
	if world.server_build or Net.is_server(): return
	match str(event[0]):
		"foes":
			for data: Array in event[1]:
				var id := int(data[0])
				if not _views.has(id):
					var ship := BroodShip.new()
					add_child(ship)
					ship.global_position = data[2]
					ship.build(str(data[1]))
					var flag := TargetFlag.new()
					flag.name = "TurretTarget"
					flag.set_meta("brood_id", id)
					ship.add_child(flag)
					_views[id] = {node = ship, target = data[2], fwd = data[4] if data.size()>4 else Vector3.FORWARD}
				var target_flag := (_views[id].node as Node3D).get_node("TurretTarget") as TargetFlag
				target_flag.target = bool(data[6]) if data.size()>6 else true
				_views[id].target = data[2]
				_views[id].fwd = data[4] if data.size()>4 else data[3]
				if data.size()>5: (_views[id].node as BroodShip).set_health(float(data[5]))
		"foe-":
			var id := int(event[1])
			if _views.has(id):
				(_views[id].node as Node3D).queue_free()
				_views.erase(id)
			if bool(event[3]): _burst(event[2])
		"bolt":
			_visual_bolt(event[1], event[2], bool(event[3]), float(event[4]) if event.size()>4 else 1.0, int(event[5]) if event.size()>5 else 0)
		"bolt_path":
			for path: Array in event[1]:
				for entry: Array in _visual_bolts:
					if int(entry[3])==int(path[0]):
						(entry[0] as Node3D).global_position = (entry[0] as Node3D).global_position.lerp(path[1], 0.65)
						entry[1] = path[2]
						break
		"bolt_end":
			for entry: Array in _visual_bolts.duplicate():
				if int(entry[3])==int(event[1]):
					(entry[0] as Node).queue_free()
					_visual_bolts.erase(entry)
		"hit":
			_flash(event[1], Color("ffd27a"), 14.0)
			if event.size()<4: return
			if str(event[2])=="foe" and _views.has(int(event[3])):
				var brood: BroodShip = _views[int(event[3])].node
				brood.set_health(float(event[4]))
				brood.glitch(event[1])
			elif str(event[2])=="ship" and world.ship_views.has(int(event[3])):
				(world.ship_views[int(event[3])] as SpaceShipView).hit(event[1])

func _interpolate(delta: float) -> void:
	for view: Dictionary in _views.values():
		var node: BroodShip = view.node
		node.global_position = node.global_position.lerp(view.target, 1.0-exp(-delta*8.0))
		var fwd: Vector3 = view.fwd
		if fwd.length()>0.1:
			var want := Basis.looking_at(fwd.normalized(), Vector3.UP if absf(fwd.normalized().y)<0.98 else Vector3.FORWARD)
			node.global_basis = node.global_basis.slerp(want, 1.0-exp(-delta*6.0)).orthonormalized()
		node.animate(delta)

func _visual_bolt(from: Vector3, vel: Vector3, friendly: bool, size: float, id := 0) -> void:
	var key := "%s:%d" % [friendly, roundi(size)]
	if not _bolt_meshes.has(key):
		var capsule := CapsuleMesh.new()
		capsule.radius = 0.6*size
		capsule.height = 8.0*sqrt(size)
		_bolt_meshes[key] = capsule
	if not _bolt_materials.has(friendly):
		var color := Color("9effc0") if friendly else Color("ff5fd2")
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = color
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = 4.0
		_bolt_materials[friendly] = mat
	var node := MeshInstance3D.new()
	node.mesh = _bolt_meshes[key]
	node.material_override = _bolt_materials[friendly]
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	node.global_position = from
	if vel.length()>0.1: node.global_basis = Basis.looking_at(vel.normalized(), Vector3.UP if absf(vel.normalized().y)<0.98 else Vector3.RIGHT)*Basis(Vector3.RIGHT, PI*0.5)
	_visual_bolts.append([node, vel, 3.2, id])

func _update_visual_bolts(delta: float) -> void:
	for entry: Array in _visual_bolts.duplicate():
		entry[2] = float(entry[2])-delta
		var node: MeshInstance3D = entry[0]
		if float(entry[2])<=0.0:
			node.queue_free()
			_visual_bolts.erase(entry)
			continue
		var vel: Vector3 = entry[1]
		if vel.length_squared()>0.001:
			node.global_basis = Basis.looking_at(vel.normalized(), Vector3.UP if absf(vel.normalized().y)<0.98 else Vector3.RIGHT)*Basis(Vector3.RIGHT, PI*0.5)
		node.global_position += vel*delta

func _flash(at: Vector3, color: Color, light_range: float) -> void:
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = 6.0
	light.omni_range = light_range
	add_child(light)
	light.global_position = at
	var tw := create_tween()
	tw.tween_property(light, "light_energy", 0.0, 0.6)
	tw.tween_callback(light.queue_free)

## A brood ship breaks apart: a green flash and a spray of chitin shards.
func _burst(at: Vector3) -> void:
	_flash(at, Color("7dff6a"), 60.0)
	var shards := GPUParticles3D.new()
	var process := ParticleProcessMaterial.new()
	process.direction = Vector3.UP
	process.spread = 180.0
	process.initial_velocity_min = 20.0
	process.initial_velocity_max = 60.0
	process.gravity = Vector3.ZERO
	process.scale_min = 0.8
	process.scale_max = 2.6
	shards.process_material = process
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE*0.8
	var mat := StandardMaterial3D.new()
	mat.albedo_color = BroodShip.CHITIN_LIGHT
	mat.emission_enabled = true
	mat.emission = BroodShip.ACID*0.6
	mesh.material = mat
	shards.draw_pass_1 = mesh
	shards.amount = 90
	shards.one_shot = true
	shards.explosiveness = 0.95
	shards.lifetime = 2.5
	add_child(shards)
	shards.global_position = at
	shards.emitting = true
	get_tree().create_timer(3.0).timeout.connect(shards.queue_free)
