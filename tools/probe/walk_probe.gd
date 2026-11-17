extends "res://scripts/main.gd"
## Walks the real player up and down Surface slopes and reports how much the
## body, model and camera bob (deviation from a 0.5 s average, direction
## reversals, biggest per-frame change). Run headless with a scratch XDG_DATA_HOME.
func _parse_args() -> void:
	super._parse_args()
	_args.erase("online")
	_args["shot"] = ""
	_args["world"] = "realm"
	GameServer.debug_godmode = true

func _take_screenshot() -> void: pass

func _ready() -> void:
	super._ready()
	_run.call_deferred()

func _run() -> void:
	while not is_instance_valid(world) or _traveling or player.frozen:
		await get_tree().process_frame
	var island := world as IslandWorld
	if _args.has("terrain-only"): player.collision_mask = Player.TERRAIN_LAYER
	var home := player.global_position
	# Find steep-ish runs: a direction where the ground climbs 3-8 m over 20 m.
	var runs: Array = []
	for r in [30.0, 60.0, 100.0, 160.0, 220.0]:
		for k in 24:
			var a := TAU*k/24.0
			var p: Vector3 = home+Vector3(cos(a), 0, sin(a))*r
			for j in 8:
				var b := TAU*j/8.0
				var d := Vector3(cos(b), 0, sin(b))
				var h0: float = island.ground_height(p.x, p.z)
				var h1: float = island.ground_height(p.x+d.x*20, p.z+d.z*20)
				if h1-h0 > 3.0 and h1-h0 < 8.0 and island.is_walkable(p) and island.is_walkable(p+d*20):
					runs.append([p, d, h1-h0])
		if runs.size() >= 3: break
	print("[walk] runs ", runs.size())
	for n in mini(int(_args.get("runs", 3)), runs.size()):
		var p: Vector3 = runs[n][0]
		var d: Vector3 = runs[n][1]
		for dir in [1, -1]:
			var start := p if dir == 1 else p+d*20
			player.global_position = Vector3(start.x, island.ground_height(start.x, start.z)+0.5, start.z)
			player.velocity = Vector3.ZERO
			var box := AABB(player.global_position-Vector3(24, 24, 24), Vector3(48, 48, 48))
			for w in 600:
				if island.terrain.is_area_meshed(island.terrain.global_transform.affine_inverse()*box): break
				await get_tree().physics_frame
			for w in 30: await get_tree().physics_frame
			var move: Vector3 = d*dir
			player.camera_yaw = atan2(-move.x, -move.z)
			player.debug_input = Vector2(0, -1)
			var trace: Array = []
			for f in 150:
				await get_tree().physics_frame
				trace.append([player.global_position.y, player.global_position.y+player._visual_offset, player.camera.global_position.y, Vector2(player.global_position.x, player.global_position.z), player._smooth_ground(player.global_position.x, player.global_position.z), player._on_terrain, player.is_on_floor(), player.is_on_wall(), player.velocity])
			player.debug_input = Vector2.ZERO
			_report("run%d %s rise=%.1f" % [n, "up" if dir == 1 else "down", runs[n][2]], trace)
	get_tree().quit()

func _report(label: String, trace: Array) -> void:
	# Bob: how far each height strays from a 0.5 s moving average; reversals of its vertical speed.
	for col in [0, 1, 2]:
		var ys: Array = trace.map(func(t): return float(t[col]))
		var dev := 0.0
		var rev := 0
		var jerk := 0.0
		var peak := 0
		for i in range(15, ys.size()-15):
			var avg := 0.0
			for j in range(i-15, i+15): avg += ys[j]
			avg /= 30.0
			dev = maxf(dev, absf(ys[i]-avg))
			var v0: float = ys[i]-ys[i-1]
			var v1: float = ys[i+1]-ys[i]
			if signf(v0) != signf(v1) and absf(v0-v1) > 0.004: rev += 1
			if absf(v1-v0)>jerk:
				jerk = absf(v1-v0)
				peak = i
		print("[walk] %s %s dev=%.3f reversals=%d max_dv=%.3f" % [label, ["body", "model", "camera"][col], dev, rev, jerk])
		if col == 1 and jerk > 0.04: print("[walk] peak trace ", label, " ", trace.slice(peak-1,peak+2))
	var flat: Array = []
	for i in range(1, trace.size()):
		flat.append((trace[i][3] as Vector2).distance_to(trace[i-1][3]))
	var slow := flat.filter(func(s): return s < 0.6*flat.max())
	print("[walk] %s horizontal step min=%.3f max=%.3f stalls=%d dist=%.1f" % [label, flat.min(), flat.max(), slow.size(), (trace[-1][3] as Vector2).distance_to(trace[0][3])])
