class_name TownNPC
extends CharacterBody3D
## Outdoor shopkeepers and roaming residents. All flee creatures, then settle
## or return to their street-side station once the danger has passed.
var spec: Dictionary
var model: CreatureModel
var navigation: TownNavigation
var scared := false
var _waypoint := 0
var _wait := 0.0
var _rng := RandomNumberGenerator.new()
var _yaw := 0.0
var _path: Array[Vector3] = []
var _scan := 0.0
var _safe_time := 0.0
var _repath := 0.0
var _alarm := Label3D.new()
## The player talking to it (it stops and faces them), or null.
var _listening: Node3D

func setup(record: Dictionary, town_navigation: TownNavigation = null) -> TownNPC:
	spec = record
	navigation = town_navigation
	_rng.seed = int(spec.seed)
	_waypoint = _rng.randi_range(0, spec.route.size() - 1)
	_wait = _rng.randf_range(0.5, 3.0)
	position = spec.pos
	return self

func _ready() -> void:
	collision_layer = 0
	collision_mask = Player.TERRAIN_LAYER | Player.OBSTACLE_LAYER
	floor_snap_length = 1.1
	model = CreatureModel.new(str(spec.get("model", "npc_" + str(spec.role))))
	add_child(model)
	var collider := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.27
	capsule.height = 1.3
	collider.shape = capsule
	collider.position.y = 0.65
	add_child(collider)
	_alarm.text = "!"
	_alarm.font_size = 55
	_alarm.pixel_size = 0.007
	_alarm.modulate = Color("#ffd09a")
	_alarm.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_alarm.position.y = QuestMarker.model_top(self) + 0.45
	_alarm.visible = false
	add_child(_alarm)
	if spec.stationary:
		var title := Label3D.new()
		title.text = str(spec.get("title", str(spec.role).capitalize()))
		title.font_size = 30
		title.pixel_size = 0.004
		title.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		title.position.y = QuestMarker.model_top(self) + 0.35
		add_child(title)
	_yaw = float(spec.get("yaw", 0.0))
	model.rotation.y = _yaw

## Runs off, frightened (a question they didn't want to hear), for a few seconds.
func flee_from(from: Vector3) -> void:
	if navigation == null:
		return
	scared = true
	_safe_time = 0.0
	_wait = 0
	_path = navigation.escape_path(global_position, from, _rng)


## Stops to talk with someone (null: back to its day).
func listen_to(who: Node3D) -> void:
	_listening = who


func _physics_process(delta: float) -> void:
	# Story actors stand on the resolved terrain even while colliders stream out.
	if spec.get("story", false):
		position.y = spec.ground.call(position.x, position.z)
		velocity = Vector3.ZERO
		model.animate(0.0, delta)
		return
	if is_instance_valid(_listening):
		var to := _listening.global_position - global_position
		_yaw = lerp_angle(_yaw, atan2(-to.x, -to.z), minf(1.0, delta * 6.0))
		model.rotation.y = _yaw
		model.animate(0.0, delta)
		velocity = Vector3.ZERO
		return
	_scan -= delta
	_repath -= delta
	if navigation and _scan <= 0:
		_scan = 0.2
		var threat := navigation.nearest_threat(global_position, 18.0 if scared else 13.0)
		if threat:
			_safe_time = 0
			if not scared or _repath <= 0:
				_path = navigation.escape_path(global_position, threat.global_position, _rng)
				_repath = 0.9
				scared = true
				_wait = 0
		else:
			_safe_time += 0.2
			if scared and _safe_time >= 4:
				scared = false
				_path.clear()
				_wait = 0.6
	_alarm.visible = scared
	var ray := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 0.3, global_position - Vector3.UP * 3, Player.TERRAIN_LAYER)
	if get_world_3d().direct_space_state.intersect_ray(ray).is_empty():
		velocity = Vector3.ZERO
		model.animate(0, delta)
		return
	_wait -= delta
	var walk := Vector3.ZERO
	if navigation:
		if _path.is_empty() and _wait <= 0 and not scared:
			if spec.stationary:
				if global_position.distance_to(spec.pos) > 0.5:
					_path = navigation.path(global_position, spec.pos)
				else:
					_yaw = float(spec.get("yaw", 0))
			else:
				_path = navigation.path(global_position, navigation.random_goal(_rng, _rng.randf() < 0.3))
		if not _path.is_empty() and _wait <= 0:
			var toward := _path[0] - global_position
			toward.y = 0
			if toward.length() < 0.35:
				_path.pop_front()
				if _path.is_empty():
					_wait = _rng.randf_range(0.3, 2.5) if not scared else 0
			else:
				walk = toward.normalized()
	else:
		# Retain simple routes for standalone previews and fixtures.
		if not spec.stationary:
			var toward: Vector3 = spec.route[_waypoint] - global_position
			toward.y = 0
			if toward.length() < 0.45:
				_waypoint = (_waypoint + 1) % spec.route.size()
				_wait = _rng.randf_range(0.6, 2.7)
			walk = toward.normalized() if _wait <= 0 else Vector3.ZERO
	var speed := 2.9 if scared else 1.1
	velocity.x = walk.x * speed
	velocity.z = walk.z * speed
	velocity.y = 0.0 if is_on_floor() else velocity.y - 22 * delta
	move_and_slide()
	if is_on_wall():
		var up := Vector3.UP * 1.05
		if is_on_floor() and not test_move(global_transform, up) and not test_move(global_transform.translated(up), walk * 0.35):
			global_position += up
		else:
			_path.clear()
			_wait = 0.2
	if walk.length() > 0.01:
		_yaw = lerp_angle(_yaw, atan2(-walk.x, -walk.z), minf(delta * 8, 1))
	model.rotation.y = _yaw
	model.animate(walk.length() * (1.8 if scared else 1), delta)
