class_name SpaceFoes
extends Node3D
## Brood that hunt ships between the stars: skiffs and void eels gather
## around flying ships in the Shardfield and the Gloam. The authority moves
## them and resolves cannon bolts; clients draw scaled brood creatures.
signal foe_killed(kind: String, ship_id: int, at: Vector3)
const KINDS := {
	brood_skiff = {model = "hull_skitter", scale = 5.0, hp = 260, speed = 95.0, radius = 6.0, damage = 40, cooldown = 2.4},
	void_eel = {model = "void_lamprey", scale = 5.5, hp = 700, speed = 72.0, radius = 9.0, damage = 70, cooldown = 3.2},
}
const CAP := {haven = 0, shardfield = 3, gloam = 5}
const BOLT_SPEED := 420.0
const FOE_BOLT_SPEED := 210.0
const BOLT_DAMAGE := 120
var world: SpaceWorld
var foes := {}  # id -> {id, kind, pos, vel, hp, target, cooldown}
var _bolts: Array = []  # authority: {pos, vel, life, friendly, ship}
var _views := {}  # id -> {node, target}
var _next := 1
var _snapshot := 0.0
var _spawn_timer := 0.0
var _rng := RandomNumberGenerator.new()
var _bolt_mesh: Mesh
var _bolt_materials := {}
var _visual_bolts: Array = []  # [node, vel, life]
## Campaign hook: extra foes requested near a point {at, kind, count}.
var ambushes: Array = []

func _ready() -> void:
	_rng.randomize()

func authority() -> bool:
	return not Net.is_client()

func _physics_process(delta: float) -> void:
	_update_visual_bolts(delta)
	if authority(): _simulate(delta)
	else: _interpolate(delta)

func _simulate(delta: float) -> void:
	_spawn_timer -= delta
	if _spawn_timer<=0.0:
		_spawn_timer = 2.0
		_populate()
	var flying: Array = world.ships.values().filter(func(s: SpaceShip) -> bool: return s.mode=="flying")
	for foe: Dictionary in foes.values().duplicate():
		var target: SpaceShip = world.ships.get(int(foe.target))
		if target==null or target.mode!="flying":
			target = _nearest(flying, foe.pos)
			foe.target = target.id if target else 0
		var spec: Dictionary = KINDS[foe.kind]
		if target==null or (foe.pos as Vector3).distance_to(target.xform.origin)>2600.0:
			foes.erase(foe.id)
			_emit(["foe-", foe.id, foe.pos, false])
			continue
		# Circle the ship at a hunting distance, weaving.
		var to: Vector3 = target.xform.origin-foe.pos
		var side := to.cross(Vector3.UP).normalized()
		var want := to.normalized()*(1.0 if to.length()>140.0 else -0.4)+side*sin(Time.get_ticks_msec()/700.0+foe.id)*0.6
		foe.vel = (foe.vel as Vector3).lerp(want.normalized()*float(spec.speed), 1.0-exp(-delta*1.6))
		foe.pos += foe.vel*delta
		foe.cooldown = float(foe.cooldown)-delta
		if foe.cooldown<=0.0 and to.length()<520.0:
			foe.cooldown = float(spec.cooldown)*_rng.randf_range(0.8, 1.3)
			var lead: Vector3 = target.xform.origin+(-target.xform.basis.z*target.speed)*(to.length()/FOE_BOLT_SPEED)*0.6
			_shoot(foe.pos, (lead-foe.pos).normalized()*FOE_BOLT_SPEED, false, 0)
	for bolt: Dictionary in _bolts.duplicate():
		bolt.life = float(bolt.life)-delta
		var from: Vector3 = bolt.pos
		bolt.pos = from+(bolt.vel as Vector3)*delta
		var done := float(bolt.life)<=0.0
		if bolt.friendly:
			for foe: Dictionary in foes.values():
				if Geometry3D.get_closest_point_to_segment(foe.pos, from, bolt.pos).distance_to(foe.pos)<float(KINDS[foe.kind].radius):
					foe.hp = int(foe.hp)-BOLT_DAMAGE
					_emit(["hit", foe.pos])
					if int(foe.hp)<=0:
						foes.erase(foe.id)
						_emit(["foe-", foe.id, foe.pos, true])
						foe_killed.emit(str(foe.kind), int(bolt.ship), foe.pos)
					done = true
					break
		else:
			for ship: SpaceShip in world.ships.values():
				if ship.mode!="flying": continue
				if Geometry3D.get_closest_point_to_segment(ship.xform.origin, from, bolt.pos).distance_to(ship.xform.origin)<SpaceShip.RADIUS:
					world.hurt_ship(ship, int(bolt.damage))
					_emit(["hit", bolt.pos])
					done = true
					break
		if done: _bolts.erase(bolt)
	_snapshot -= delta
	if _snapshot<=0.0 and not foes.is_empty():
		_snapshot = 0.1
		_emit(["foes", foes.values().map(func(f: Dictionary) -> Array: return [f.id, f.kind, f.pos, f.vel])])

func _populate() -> void:
	for ship: SpaceShip in world.ships.values():
		if ship.mode!="flying": continue
		var region := SpaceLayout.region_at(ship.xform.origin)
		var near := foes.values().filter(func(f: Dictionary) -> bool: return (f.pos as Vector3).distance_to(ship.xform.origin)<1200.0).size()
		if near>=int(CAP.get(region, 0)): continue
		var kind := "void_eel" if region=="gloam" and _rng.randf()<0.45 else "brood_skiff"
		_spawn(kind, ship.xform.origin-ship.xform.basis.z*700.0+Vector3(_rng.randf_range(-300, 300), _rng.randf_range(-120, 120), _rng.randf_range(-300, 300)), ship.id)
	for ambush: Dictionary in ambushes.duplicate():
		for i in int(ambush.count):
			_spawn(str(ambush.kind), (ambush.at as Vector3)+Vector3(_rng.randf_range(-200, 200), _rng.randf_range(-60, 60), _rng.randf_range(-200, 200)), 0)
		ambushes.erase(ambush)

func _spawn(kind: String, at: Vector3, target: int) -> void:
	var foe := {id = _next, kind = kind, pos = at, vel = Vector3.ZERO, hp = int(KINDS[kind].hp), target = target, cooldown = 3.0}
	_next += 1
	foes[foe.id] = foe

func _nearest(ships: Array, at: Vector3) -> SpaceShip:
	var best: SpaceShip
	for ship: SpaceShip in ships:
		if best==null or ship.xform.origin.distance_to(at)<best.xform.origin.distance_to(at): best = ship
	return best

## A cannon bolt from a ship's turret (authority).
func fire_bolt(ship: SpaceShip, from: Vector3, dir: Vector3) -> void:
	_shoot(from, dir*BOLT_SPEED+ship.velocity, true, ship.id)

func _shoot(from: Vector3, vel: Vector3, friendly: bool, ship: int) -> void:
	_bolts.append({pos = from, vel = vel, life = 2.6, friendly = friendly, ship = ship, damage = 50})
	_emit(["bolt", from, vel, friendly])

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
					var spec: Dictionary = KINDS.get(str(data[1]), KINDS.brood_skiff)
					var model := CreatureModel.new(spec.model)
					model.scale = Vector3.ONE*float(spec.scale)
					add_child(model)
					model.global_position = data[2]
					_views[id] = {node = model, target = data[2], vel = data[3]}
				_views[id].target = data[2]
				_views[id].vel = data[3]
		"foe-":
			var id := int(event[1])
			if _views.has(id):
				(_views[id].node as Node3D).queue_free()
				_views.erase(id)
			if bool(event[3]): _flash(event[2], Color("7dff6a"), 30.0)
		"bolt":
			_visual_bolt(event[1], event[2], bool(event[3]))
		"hit":
			_flash(event[1], Color("ffd27a"), 10.0)

func _interpolate(delta: float) -> void:
	for view: Dictionary in _views.values():
		var node: CreatureModel = view.node
		var target: Vector3 = view.target
		node.global_position = node.global_position.lerp(target, 1.0-exp(-delta*8.0))
		var vel: Vector3 = view.vel
		if vel.length()>1.0: node.look_at(node.global_position-vel, Vector3.UP)
		node.animate(1.0, delta)

func _visual_bolt(from: Vector3, vel: Vector3, friendly: bool) -> void:
	if _bolt_mesh==null:
		var capsule := CapsuleMesh.new()
		capsule.radius = 0.5
		capsule.height = 7.0
		_bolt_mesh = capsule
	var color := Color("9effc0") if friendly else Color("ff5fd2")
	if not _bolt_materials.has(friendly):
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = color
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = 4.0
		_bolt_materials[friendly] = mat
	var node := MeshInstance3D.new()
	node.mesh = _bolt_mesh
	node.material_override = _bolt_materials[friendly]
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	node.global_position = from
	if vel.length()>0.1: node.global_basis = Basis.looking_at(vel.normalized(), Vector3.UP if absf(vel.normalized().y)<0.98 else Vector3.RIGHT)*Basis(Vector3.RIGHT, PI*0.5)
	_visual_bolts.append([node, vel, 2.6])

func _update_visual_bolts(delta: float) -> void:
	for entry: Array in _visual_bolts.duplicate():
		entry[2] = float(entry[2])-delta
		var node: MeshInstance3D = entry[0]
		if float(entry[2])<=0.0:
			node.queue_free()
			_visual_bolts.erase(entry)
			continue
		node.global_position += (entry[1] as Vector3)*delta

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
