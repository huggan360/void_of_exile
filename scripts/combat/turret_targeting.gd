class_name TurretTargeting
extends RefCounted
## Shared selection for the sight and the authority. Closest by distance,
## only inside a narrow sight cone, in range, and with a clear shot.
const MAX_TARGETS := 3
const RANGE := 1200.0
const CONE := deg_to_rad(8.0)
const TURN_RATE := deg_to_rad(24.0)
const MAX_BEND := deg_to_rad(18.0)

static func select(world: SpaceWorld, origin: Vector3, aim: Vector3) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	if not aim.is_finite() or aim.length_squared()<0.001: return found
	var forward := aim.normalized()
	for node in world.get_tree().get_nodes_in_group("turret_targets"):
		var flag := node as TargetFlag
		if not is_instance_valid(flag) or flag.get_world_3d()!=world.get_world_3d() or not flag.eligible(): continue
		if not Net.is_client() and flag.has_meta("brood_id"): continue
		_add(found, world, origin, forward, {kind = "flag", flag = weakref(flag), pos = flag.global_position, vel = flag.velocity()})
	if is_instance_valid(world.foes) and not Net.is_client():
		for foe: Dictionary in world.foes.foes.values():
			if not bool(foe.get("targetable", true)) or int(foe.hp)<=0: continue
			_add(found, world, origin, forward, {kind = "brood", id = int(foe.id), pos = foe.pos, vel = foe.vel})
	found.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.distance)<float(b.distance))
	if found.size()>MAX_TARGETS: found.resize(MAX_TARGETS)
	return found

static func _add(found: Array[Dictionary], world: SpaceWorld, origin: Vector3, forward: Vector3, candidate: Dictionary) -> void:
	var offset: Vector3 = candidate.pos-origin
	var distance := offset.length()
	if distance<0.01 or distance>RANGE or forward.dot(offset/distance)<cos(CONE): return
	var ray := PhysicsRayQueryParameters3D.create(origin, candidate.pos, Player.TERRAIN_LAYER | Player.OBSTACLE_LAYER)
	var obstruction := world.get_world_3d().direct_space_state.intersect_ray(ray)
	if not obstruction.is_empty():
		var flag := (candidate.flag as WeakRef).get_ref() as TargetFlag if str(candidate.kind)=="flag" else null
		var hit_flag := TargetFlag.for_body(obstruction.collider)
		if flag==null or hit_flag!=flag: return
	candidate.distance = distance
	found.append(candidate)

static func sample(target: Dictionary, world: SpaceWorld) -> Dictionary:
	if target.is_empty(): return {}
	if str(target.kind)=="brood":
		var foe: Dictionary = world.foes.foes.get(int(target.id), {})
		if foe.is_empty() or int(foe.hp)<=0 or not bool(foe.get("targetable", true)): return {}
		return {pos = foe.pos, vel = foe.vel}
	var flag := (target.flag as WeakRef).get_ref() as TargetFlag
	if not is_instance_valid(flag) or not flag.eligible(): return {}
	return {pos = flag.global_position, vel = flag.velocity()}

static func steer(velocity: Vector3, initial: Vector3, from: Vector3, sample: Dictionary, delta: float) -> Vector3:
	if sample.is_empty() or velocity.length_squared()<0.001: return velocity
	var distance := from.distance_to(sample.pos)
	if distance>RANGE: return velocity
	var lead: Vector3 = sample.pos+(sample.vel as Vector3)*minf(0.5, distance/velocity.length())
	var offset := lead-from
	if offset.length_squared()<0.001: return velocity
	var want := offset.normalized()
	# Never swing around or turn the cannon into an unrestricted homing missile.
	if initial.dot(want)<cos(MAX_BEND): return velocity
	var current := velocity.normalized()
	var angle := current.angle_to(want)
	if angle<0.0001: return velocity
	return current.slerp(want, minf(1.0, TURN_RATE*delta/angle)).normalized()*velocity.length()
