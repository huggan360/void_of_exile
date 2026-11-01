class_name EnemyPatrol
extends RefCounted
## One seeded, bounded navigation grid shared by a three-person patrol.
## Uses real terrain/structure clearance. No targets inside towns, water or lava.
var world: GameWorld
var anchor := Vector3.ZERO
var radius := 18.0
var grid := AStarGrid2D.new()
var origin := Vector2.ZERO
var _rng := RandomNumberGenerator.new()
var _goal := Vector3.ZERO
var _paths := {}
var _refresh := {}
var _waiting := 0.0
const CELL := 1.0

func _init(p_world: GameWorld, at: Vector3, seed_value: int, patrol_radius := 18.0) -> void:
	world = p_world
	anchor = at
	radius = patrol_radius
	_rng.seed = seed_value
	var extent := ceili(radius)+2
	var side := extent*2+1
	origin = Vector2(at.x,at.z)-Vector2.ONE*extent
	grid.region = Rect2i(0,0,side,side)
	grid.cell_size = Vector2.ONE*CELL
	grid.offset = origin+Vector2.ONE*.5
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	grid.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	grid.update()
	var biome_id := world.biome_at(at).id
	for z in side:
		for x in side:
			var pos := Vector3(origin.x+x+.5,0,origin.y+z+.5)
			pos.y = world.ground_height(pos.x,pos.z)
			var blocked := Vector2(pos.x-at.x,pos.z-at.z).length()>radius or world.biome_at(pos).id!=biome_id
			blocked = blocked or not world.is_walkable(pos) or world.is_hazard(pos)
			if not blocked and world is IslandWorld:
				blocked = (world as IslandWorld).generator._near_town(Vector2(pos.x,pos.z))
			if not blocked: blocked = not world.enemy_spawn_clear(pos,.45,1.85)
			grid.set_point_solid(Vector2i(x,z),blocked)
	_goal = anchor
	_pick_goal()

func _id(pos: Vector3) -> Vector2i:
	var guess := Vector2i((Vector2(pos.x,pos.z)-origin).floor())
	for r in range(0,6):
		for z in range(-r,r+1):
			for x in range(-r,r+1):
				var id := guess+Vector2i(x,z)
				if grid.is_in_boundsv(id) and not grid.is_point_solid(id): return id
	return Vector2i(-1,-1)

func _pick_goal() -> void:
	var start := _id(_goal)
	if start.x<0: start = _id(anchor)
	if start.x<0: return
	for attempt in 60:
		var a := _rng.randf()*TAU
		var r := _rng.randf_range(radius*.45,radius*.85)
		var candidate := anchor+Vector3(cos(a)*r,0,sin(a)*r)
		var end := _id(candidate)
		if end.x<0 or grid.get_id_path(start,end).size()<5: continue
		_goal = Vector3(origin.x+end.x+.5,0,origin.y+end.y+.5)
		_goal.y = world.ground_height(_goal.x,_goal.z)
		_paths.clear()
		_refresh.clear()
		return

func direction(actor: Enemy, delta: float) -> Vector3:
	var leader := actor.pack.leader
	if not is_instance_valid(leader) or not leader.is_alive():
		for member in actor.pack.members:
			if is_instance_valid(member) and member.is_alive():
				actor.pack.leader = member
				leader = member
				break
	if actor==leader:
		_waiting = maxf(0,_waiting-delta)
		if Vector2(actor.global_position.x-_goal.x,actor.global_position.z-_goal.z).length()<1.3:
			_pick_goal()
			_waiting = _rng.randf_range(.6,1.6)
	if _waiting>0: return Vector3.ZERO
	var target := _goal
	if actor!=leader and is_instance_valid(leader):
		# The two followers stay behind/beside their leader while travelling.
		var index := actor.pack.members.find(actor)
		var side := -1.0 if index%2 else 1.0
		target = leader.global_position+Vector3(side*1.6,0,1.6).rotated(Vector3.UP,leader.model.rotation.y)
		if actor.global_position.distance_to(target)<1.1: return Vector3.ZERO
	var key := actor.get_instance_id()
	_refresh[key] = float(_refresh.get(key,0))-delta
	if float(_refresh[key])<=0 or not _paths.has(key):
		_refresh[key] = 1.0
		var first := _id(actor.global_position)
		var last := _id(target)
		_paths[key] = grid.get_point_path(first,last) if first.x>=0 and last.x>=0 else PackedVector2Array()
	var path: PackedVector2Array = _paths[key]
	while not path.is_empty():
		var toward := Vector3(path[0].x-actor.global_position.x,0,path[0].y-actor.global_position.z)
		if toward.length()>.35:
			_paths[key] = path
			return toward.normalized()
		path.remove_at(0)
	_paths[key] = path
	return Vector3.ZERO
