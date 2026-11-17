extends Node3D
## Isolated real-player physics on voxel-meshed terrain. Never joins or saves an account.
class ProbePlayer extends Player:
	var attempts := 0
	var stepped := false
	var began_on_floor := false
	func _move_ground(delta: float) -> void:
		attempts = 0
		stepped = false
		began_on_floor = is_on_floor()
		super._move_ground(delta)
	func _try_step_up(dir: Vector3, normal := Vector3.UP, height := STEP_HEIGHT) -> bool:
		attempts += 1
		var result := super._try_step_up(dir, normal, height)
		stepped = stepped or result
		return result
	func _update_camera(_delta: float) -> void: pass
	func _update_combat(_delta: float, _dir: Vector3, _speed: float) -> void: pass
	func _update_magic(_delta: float) -> void: pass
	func _fall_guard() -> void: pass
var actor: ProbePlayer
var terrain: StaticBody3D
var overhead: StaticBody3D
var height_at: Callable
var failures := 0
var assert_results := "--assert" in OS.get_cmdline_user_args()
func _ready() -> void:
	run.call_deferred()
func make_terrain(sample: Callable) -> void:
	if is_instance_valid(terrain):
		remove_child(terrain)
		terrain.free()
	if is_instance_valid(overhead):
		overhead.free()
	height_at = sample
	var buffer := VoxelBuffer.new()
	buffer.create(80, 32, 80)
	for x in 80:
		for z in 80:
			var h := int(round(float(sample.call((x+0.5)*0.25-4.0, (z+0.5)*0.25-6.0))/0.25))+2
			for y in clampi(h, 0, 32): buffer.set_voxel(1, x, y, z, VoxelBuffer.CHANNEL_COLOR)
	var palette := VoxelColorPalette.new()
	palette.set_color(1, Color.GRAY)
	var mesh := VoxModel.mesh_from_buffer(buffer, palette)
	terrain = StaticBody3D.new()
	terrain.collision_layer = Player.TERRAIN_LAYER
	terrain.position = Vector3(-4.0, -0.5, -6.0)
	terrain.scale = Vector3.ONE*0.25
	var shape := CollisionShape3D.new()
	shape.shape = mesh.create_trimesh_shape()
	terrain.add_child(shape)
	add_child(terrain)
func simulate(input: Vector2, frames: int) -> Array:
	actor.debug_input = input
	var samples := []
	for frame in frames:
		await get_tree().physics_frame
		actor._physics_process(1.0/60.0)
		samples.append([actor.position, actor.position.y+actor._visual_offset, actor.is_on_floor(), actor.velocity, actor.is_on_wall(), actor.attempts, actor.stepped, actor.began_on_floor, actor._step_grounded_time])
	return samples
func check(ok: bool, detail: String) -> void:
	if not ok:
		failures += 1
		push_error(detail)
func route(label: String, sample: Callable, input: Vector2, start: Vector3, frames: int, expected: float, ceiling_height := -1.0) -> void:
	make_terrain(sample)
	if ceiling_height > 0.0:
		overhead = StaticBody3D.new()
		overhead.collision_layer = Player.OBSTACLE_LAYER
		overhead.position = Vector3(4, ceiling_height+0.1, 0)
		var collider := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(20, 0.2, 10)
		collider.shape = box
		overhead.add_child(collider)
		add_child(overhead)
	actor.position = start
	actor.velocity = Vector3.ZERO
	actor._visual_offset = 0.0
	actor._visual_speed = 0.0
	actor._on_terrain = 0.0
	actor._step_grounded_time = 0.0
	actor.ground_height = sample
	await simulate(Vector2.ZERO, 24)
	var origin := actor.position
	var trace: Array = await simulate(input, frames)
	var direction := Vector3(input.x,0,input.y).normalized()
	var distance := (actor.position-origin).dot(direction)
	var stalls := 0
	var max_jerk := 0.0
	var peak := 0
	for i in range(2, trace.size()):
		var progress: float = (trace[i][0]-trace[i-1][0]).dot(direction)
		if progress < Player.BASE_SPEED/60.0*0.4:
			stalls += 1
			if "--detail" in OS.get_cmdline_user_args() and label == "fine staircase" and stalls < 9:
				print("[surface-detail] ",i," progress=",progress," state=",trace[i])
		var jerk: float = absf(trace[i][1]-2.0*trace[i-1][1]+trace[i-2][1])
		if jerk>max_jerk:
			max_jerk = jerk
			peak = i
	print("[surface-motion] %s distance=%.3f required=%.2f stalls=%d visual_jerk=%.4f end=%s" % [label,distance,expected,stalls,max_jerk,actor.position])
	if max_jerk > 0.07: print("[surface-motion] peak=", trace.slice(peak-2,peak+1))
	if assert_results:
		check(distance>=expected, label+" blocked climbable terrain")
		if ceiling_height != 2.0: check(stalls <= 2, label+" stalls at voxel edges")
		check(max_jerk<0.07, label+" has abrupt visual height changes")
func run() -> void:
	actor = ProbePlayer.new()
	actor.stats = PlayerStats.new()
	actor.frozen = false
	actor.smooth_ground = true
	add_child(actor)
	actor.set_physics_process(false)
	add_child(actor.aim_marker)
	for rise in [0.25, 0.5, 0.75, 1.0]:
		await route("ledge %.2f" % rise, func(x: float,_z: float)->float: return rise if x>=0.0 else 0.0, Vector2.RIGHT, Vector3(-2,0.1,0), 100, 8.0)
	await route("fine staircase", func(x:float,_z:float)->float: return clampf(floorf(x/0.25)*0.25,0.0,4.0), Vector2.RIGHT, Vector3(-2,0.1,0), 120, 10.0)
	await route("large repeated steps", func(x:float,_z:float)->float: return clampf(floorf(x/0.75),0.0,5.0), Vector2.RIGHT, Vector3(-2,0.1,0),120,10.0)
	await route("gentle staircase", func(x:float,_z:float)->float: return clampf(floorf(x/0.5)*0.25,0.0,3.0), Vector2.RIGHT, Vector3(-2,0.1,0), 120, 10.0)
	await route("diagonal corners", func(x:float,z:float)->float: return clampf((floorf(x/0.5)+floorf(z/0.5))*0.25,0.0,3.0), Vector2(1,1).normalized(), Vector3(-1,0.1,-1), 120, 10.0)
	await route("short drop", func(x:float,_z:float)->float: return 1.5 if x<0.0 else 0.0, Vector2.RIGHT, Vector3(-2,1.6,0),100,8.0)
	await route("descending", func(x:float,_z:float)->float: return 4.0-clampf(floorf(x/0.5)*0.25,0.0,4.0), Vector2.RIGHT, Vector3(-2,4.1,0), 120, 10.0)
	await route("low ceiling with clearance", func(x:float,_z:float)->float: return 0.25 if x>=0.0 else 0.0, Vector2.RIGHT, Vector3(-2,0.1,0),100,8.0,2.10)
	await route("blocked headroom", func(x:float,_z:float)->float: return 0.25 if x>=0.0 else 0.0, Vector2.RIGHT, Vector3(-2,0.1,0),100,1.0,2.0)
	if assert_results: check(actor.position.x < 0.0 and actor.position.y < 0.25, "Passed through a low ceiling")
	# High walls must remain solid; no accumulating lifts while held against them.
	for wall_height in [1.25, 2.0]:
		make_terrain(func(x:float,_z:float)->float: return wall_height if x>=0.0 else 0.0)
		actor.ground_height = height_at
		actor.position = Vector3(-2,0.1,0)
		actor.velocity = Vector3.ZERO
		actor._step_grounded_time = 0.0
		await simulate(Vector2.ZERO,24)
		await simulate(Vector2.RIGHT,100)
		print("[surface-motion] wall %.2f stop=" % wall_height,actor.position)
		if assert_results: check(actor.position.x < -0.2 and actor.position.y < 0.1, "Climbed an over-height wall")
	print("[surface-motion] failures=",failures)
	actor.aim_marker.free()
	actor.free()
	get_tree().quit(1 if failures else 0)
