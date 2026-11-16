extends "res://scripts/main.gd"
## Pushes the real player into Surface voxel walls (ground that rises 2.5 m+
## within a metre) and reports what the physics costs per frame.
## Run headless with a scratch XDG_DATA_HOME.
func _parse_args() -> void:
	super._parse_args()
	_args.erase("online")
	_args["shot"] = ""
	_args["world"] = "realm"

func _take_screenshot() -> void: pass

func _ready() -> void:
	super._ready()
	_run.call_deferred()

func _run() -> void:
	while not is_instance_valid(world) or _traveling or player.frozen:
		await get_tree().process_frame
	var island := world as IslandWorld
	var home := player.global_position
	var walls: Array = []
	for r in [20.0, 40.0, 70.0, 110.0, 160.0, 220.0]:
		for k in 36:
			var a := TAU*k/36.0
			var p: Vector3 = home+Vector3(cos(a), 0, sin(a))*r
			for j in 8:
				var b := TAU*j/8.0
				var d := Vector3(cos(b), 0, sin(b))
				var h0: float = island.ground_height(p.x, p.z)
				var h1: float = island.ground_height(p.x+d.x*0.75, p.z+d.z*0.75)
				if h1-h0 > 2.5 and island.is_walkable(p) and island.is_walkable(p-d):
					walls.append([p-d*0.8, d, h1-h0])
					break
		if walls.size() >= 3: break
	print("[wall] found ", walls.size())
	FrameTrace.enabled = true
	for n in mini(3, walls.size()):
		var p: Vector3 = walls[n][0]
		var d: Vector3 = walls[n][1]
		player.global_position = Vector3(p.x, island.ground_height(p.x, p.z)+0.3, p.z)
		player.velocity = Vector3.ZERO
		var box := AABB(player.global_position-Vector3(24, 24, 24), Vector3(48, 48, 48))
		for w in 600:
			if island.terrain.is_area_meshed(island.terrain.global_transform.affine_inverse()*box): break
			await get_tree().physics_frame
		for w in 30: await get_tree().physics_frame
		FrameTrace.sections.clear()
		# Bare costs against the wall.
		var t := Time.get_ticks_usec()
		for i in 20: player.test_move(player.global_transform, d*0.3)
		var tm := (Time.get_ticks_usec()-t)/20.0
		player.camera_yaw = atan2(-d.x, -d.z)
		player.debug_input = Vector2(0, -1)
		var phys := 0.0
		var worst := 0.0
		var walled := 0
		for f in 120:
			await get_tree().physics_frame
			var pt := Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000.0
			phys += pt
			worst = maxf(worst, pt)
			if player.is_on_wall(): walled += 1
		player.debug_input = Vector2.ZERO
		print("[wall] %d rise=%.1f test_move=%.0fus physics avg=%.2fms worst=%.2fms on_wall=%d moved=%.2f %s" % [n, walls[n][2], tm, phys/120.0, worst, walled,
			Vector2(player.global_position.x-p.x, player.global_position.z-p.z).length(), FrameTrace.sections.get("player/slide")])
	get_tree().quit()
