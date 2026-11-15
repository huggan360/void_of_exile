class_name PetYardWanderer
extends Node3D
## A client-only pet. Destinations and every step stay on open yard ground.
var pet := {}
var visual: PetFollower
var target: InteractionTarget
var _world: PetYardWorld
var _rng := RandomNumberGenerator.new()
var _goal := Vector3.ZERO
var _pause := 0.0
var _time := 0.0
var _gait := "trot"
var _moving := false
var _pop := 0.0


func setup(record: Dictionary, world: PetYardWorld, at := Vector3.INF) -> PetYardWanderer:
	pet = record.duplicate(true)
	_world = world
	_rng.seed = int(pet.id) * 19331
	_time = _rng.randf() * TAU
	_gait = str(PetDefs.SPECIES.get(str(pet.species), {}).get("gait", "trot"))
	position = at if at.is_finite() else _spot(Vector3.INF)
	_goal = position
	_pause = _rng.randf_range(0.5, 3.5)
	return self


func _ready() -> void:
	visual = PetFollower.new(pet, null, _world)
	add_child(visual)
	visual.set_process(false)
	target = InteractionTarget.new()
	target.title = str(pet.name)
	target.description = "Playing in the meadow."
	target.action_text = "Take %s along" % str(pet.name)
	target.response = "%s is coming along." % str(pet.name)
	target.reach = 2.8
	target.position.y = 0.4
	add_child(target)
	target.activated.connect(func(_actor: Node3D) -> void: PetsClient.equip(int(pet.id)))


func pop_out() -> void:
	_pop = 0.7


func _spot(from: Vector3) -> Vector3:
	for attempt in 60:
		var at := Vector3(_rng.randf_range(-23, 23), 0, _rng.randf_range(-22, 21))
		at.y = _world.ground_height(at.x, at.z)
		if _world.is_walkable(at) and (not from.is_finite() or _world.clear_segment(from, at)): return at
	return from if from.is_finite() else PetYardWorld.SPAWN_POINT


func _process(delta: float) -> void:
	_time += delta
	if is_instance_valid(target) and _talking():
		_moving = false
		_animate(delta, 0.0)
		return
	if _pause > 0:
		_pause -= delta
		_moving = false
		if _pause <= 0: _goal = _spot(position)
	else:
		var offset := _goal - position
		offset.y = 0
		var speed := 0.65 if _gait == "plod" else 1.0 if _gait == "stomp" else 1.65
		if _gait == "leap" and sin(_time * 4.0) < 0: speed = 0
		var next := position.move_toward(Vector3(_goal.x, position.y, _goal.z), speed * delta)
		if offset.length() < 0.15 or not _world.is_walkable(next):
			_pause = _rng.randf_range(1.5, 5)
			_moving = false
		else:
			position = next
			position.y = _world.ground_height(position.x, position.z)
			rotation.y = lerp_angle(rotation.y, atan2(-offset.x, -offset.z), minf(1, delta * 6))
			_moving = speed > 0
	_animate(delta, 1.0 if _moving else 0.0)


func _talking() -> bool:
	# Interaction protection freezes the player's input while choosing a pet.
	for actor in get_tree().get_nodes_in_group("local_player"):
		if actor.input_locked and actor.global_position.distance_to(global_position) < 3: return true
	return false


func _animate(delta: float, walking: float) -> void:
	if not is_instance_valid(visual): return
	visual.animate_gait(walking, delta)
	if _pop > 0:
		_pop = maxf(0, _pop - delta)
		visual.position.y = sin((1 - _pop / 0.7) * PI) * 1.6
	else:
		visual.position.y = 0
