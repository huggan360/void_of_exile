extends "res://scripts/main.gd"
## Views of Vesperis (offline) for art checks: --shots=<dir> [--views=a,b].
## Views: aerial, street, round (a roundabout), houses, lift (riding the
## elevator, first person), lift_out (the tower from the street).
func _parse_args() -> void:
	super._parse_args()
	_args.erase("online")
	_args["play-space"] = ""

func _take_screenshot() -> void:
	pass

func _ready() -> void:
	super._ready()
	_run.call_deferred()
	get_tree().create_timer(330.0).timeout.connect(func() -> void: get_tree().quit(2))

func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout

func _place(at: Transform3D) -> void:
	player.global_transform = at
	player.up_direction = at.basis.y
	player.velocity = Vector3.ZERO
	(world as SpaceWorld).planets[CityLayout.ID].terrain.ensure_ground(at.origin)

func _snap(label: String, pose: Transform3D) -> void:
	transition.hide()
	var camera := Camera3D.new()
	camera.far = 90000
	camera.fov = 70.0
	camera.environment = player.camera.environment
	add_child(camera)
	camera.global_transform = pose
	camera.make_current()
	await _wait(1.2)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [str(_args.get("shots", "/tmp")), label])
	camera.queue_free()
	player.camera.make_current()

func _run() -> void:
	while not (world is SpaceWorld) or player.frozen or _traveling or not world.is_presentation_ready(): await get_tree().process_frame
	var space := world as SpaceWorld
	var control := player.spatial_controller as SpaceTraversal
	while control.cinematic: await get_tree().process_frame
	var center: Vector3 = CityLayout.planet().center
	var d: Dictionary = CityLayout.DISTRICTS[int(_args.get("district", "0"))]
	var port := CityLayout.district_frame(d)
	port.origin += center
	var views := str(_args.get("views", "aerial,street,round,houses,lift_out,lift")).split(",")
	_place(port*Transform3D(Basis.IDENTITY, Vector3(0, 0.6, 25)))
	var city_planet := space.planets[CityLayout.ID].get_node("City") as CityPlanet
	var started := Time.get_ticks_msec()
	await _wait(3.0)
	print("[city-shot] after 3 s: %d of %d chunks still to build" % [city_planet._chunks.size(), 6*4])
	while not city_planet._chunks.is_empty() and Time.get_ticks_msec()-started<60000: await get_tree().process_frame
	print("[city-shot] whole planet built in %.1f s" % ((Time.get_ticks_msec()-started)/1000.0))
	var up := port.basis.y
	for view in views:
		match view:
			"aerial":
				await _snap("aerial", Transform3D(Basis.IDENTITY, port*Vector3(160, 120, 200)).looking_at(port*Vector3(0, 0, 40), up))
			"street":
				var at := port*Vector3(0, 0, 120)
				_place(Transform3D(port.basis, at))
				await _wait(1.0)
				await _snap("street", Transform3D(Basis.IDENTITY, port*Vector3(-6, 1.7, 118)).looking_at(port*Vector3(20, 3, 160), up))
			"round":
				var node: Vector3 = CityRoads.nearest_roundabout(port.origin-center, 400.0)
				if node.is_finite():
					var frame := CityLayout._tangent(node.normalized(), port.basis.z)
					frame.origin += center
					_place(frame*Transform3D(Basis.IDENTITY, Vector3(0, 0.3, 24)))
					await _wait(1.0)
					await _snap("round", Transform3D(Basis.IDENTITY, frame*Vector3(18, 14, 26)).looking_at(frame*Vector3(0, 0, 0), frame.basis.y))
			"lake", "park":
				var local := Vector2i(0, 1) if view=="lake" else Vector2i(5, 2)
				var cell := CityLayout.cell(int(d.face), int(d.corner.x)-3+local.x, int(d.corner.y)-3+local.y)
				var block: Dictionary = CityRoads.blocks(int(d.face), int(cell.i), int(cell.j))[0]
				var frame: Transform3D = block.frame
				frame.origin += center
				var seed: Vector2 = block.seed
				_place(frame*Transform3D(Basis.IDENTITY, Vector3(seed.x, 0.5, seed.y+30)))
				await _wait(1.5)
				await _snap(view, Transform3D(Basis.IDENTITY, frame*Vector3(seed.x+22, 16, seed.y+40)).looking_at(frame*Vector3(seed.x, 0, seed.y+10), frame.basis.y))
			"graffiti":
				var v: Dictionary = CityLayout.venues(d).filter(func(x: Dictionary) -> bool: return x.kind=="cafe")[0]
				var room: Transform3D = v.frame
				room.origin += center
				_place(room*Transform3D(Basis.IDENTITY, Vector3(0, 0.5, -12)))
				await _wait(1.0)
				await _snap("graffiti", Transform3D(Basis.IDENTITY, room*Vector3(17, 3, -9)).looking_at(room*Vector3(8.7, 2.5, 0), room.basis.y))
			"front":
				var v: Dictionary = CityLayout.venues(d).filter(func(x: Dictionary) -> bool: return x.kind=="bar")[0]
				var room: Transform3D = v.frame
				room.origin += center
				_place(room*Transform3D(Basis.IDENTITY, Vector3(0, 0.5, -12)))
				await _wait(1.0)
				await _snap("front", Transform3D(Basis.IDENTITY, room*Vector3(4, 3.5, -17)).looking_at(room*Vector3(0, 4.5, -6), room.basis.y))
			"ship":
				var ship: SpaceShip = space._launch_ship(player.player_id, "You")
				player.global_position = space.spawn_point
				space.request(["board", ship.id])
				await _wait(1.5)
				var room := space.pocket_point(ship.slot, Vector3.ZERO)
				await _snap("ship_front", Transform3D(Basis.IDENTITY, room+Vector3(2.5, 2.2, -7.5)).looking_at(room+Vector3(0, 1.0, -13.5), Vector3.UP))
				await _snap("ship_back", Transform3D(Basis.IDENTITY, room+Vector3(-1.5, 2.0, 9.0)).looking_at(room+Vector3(-5.0, 1.5, 6.2), Vector3.UP))
				await _snap("ship_exit", Transform3D(Basis.IDENTITY, room+Vector3(2.0, 2.2, 10.0)).looking_at(room+Vector3(0, 3.2, 17.6), Vector3.UP))
				await _snap("ship_lock", Transform3D(Basis.IDENTITY, room+Vector3(-2.5, 2.2, -10.0)).looking_at(room+Vector3(-7.6, 2.0, -10.0), Vector3.UP))
			"houses":
				await _snap("houses", Transform3D(Basis.IDENTITY, port*Vector3(-60, 30, -150)).looking_at(port*Vector3(-140, 25, -260), up))
			"lift_out":
				var e: Dictionary = CityLayout.elevators().filter(func(x: Dictionary) -> bool: return x.district==d.id)[0]
				var tower := CityLayout.tower_world(e)
				_place(tower*Transform3D(Basis.IDENTITY, Vector3(0, 0.2, -30)))
				await _wait(1.0)
				await _snap("lift_out", Transform3D(Basis.IDENTITY, tower*Vector3(-25, 3, -60)).looking_at(tower*Vector3(0, 60, 0), tower.basis.y))
			"lift":
				var e: Dictionary = CityLayout.elevators().filter(func(x: Dictionary) -> bool: return x.district==d.id)[0]
				var tower := CityLayout.tower_world(e)
				var id := int(e.id)
				_place(tower*Transform3D(Basis.IDENTITY, Vector3(0, 0.2, -4.0)))
				await _wait(0.5)
				space.request(["city", "call", id, 0])
				var until := Time.get_ticks_msec()+20000
				while (int(space.city.elevators[id].floor)!=0 or space.city.elevators[id].phase!="idle") and Time.get_ticks_msec()<until: await get_tree().process_frame
				await _snap("lift_lobby", Transform3D(Basis.IDENTITY, tower*Vector3(0, 1.7, -9)).looking_at(tower*Vector3(0, 1.6, 1.5), tower.basis.y))
				_place(tower*Transform3D(Basis.IDENTITY, CityState.SHAFT+Vector3(0, 0.15, 0.6)))
				await _wait(0.6)
				space.request(["city", "call", id, 2])
				await _wait(5.0)
				var local := tower.affine_inverse()*player.global_position
				var city_node := space.planets[CityLayout.ID].get_node("City") as CityPlanet
				var worst := 0.0
				for k in 120:
					await get_tree().physics_frame
					var car_y := float((city_node.districts[d.id].cars[id].car as Node3D).position.y)
					var gap := (tower.affine_inverse()*player.global_position).y-car_y
					if gap<-0.05: print("[city-shot] tick %d: rider %.2f below the car floor (car %.2f, phase %s, lift %d)" % [k, -gap, car_y, space.city.elevators[id].phase, control._lift])
					worst = minf(worst, gap)
				print("[city-shot] riding: rider at y %.1f, deepest below the car floor %.2f m" % [local.y, -worst])
				await _snap("lift_ride", Transform3D(Basis.IDENTITY, player.global_position+tower.basis.y*1.6).looking_at(tower*(CityState.SHAFT+Vector3(0, local.y+1.4, -3)), tower.basis.y))
				await _wait(6.0)
				local = tower.affine_inverse()*player.global_position
				print("[city-shot] arrived: rider at y %.1f, car at %.1f" % [local.y, float(space.city.car_state(id)[0])])
				await _snap("lift_top", Transform3D(Basis.IDENTITY, tower*Vector3(6, 90, -9)).looking_at(tower*Vector3(0, 89, 1.5), tower.basis.y))
	var city_node := space.planets[CityLayout.ID].get_node("City") as CityPlanet
	var frames := 0
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec()-t0<3000:
		await get_tree().process_frame
		frames += 1
	print("[city-shot] chunks left %d, %.0f fps over 3 s, %d draw calls" % [city_node._chunks.size(), frames/3.0, RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)])
	print("[city-shot] done")
	get_tree().quit()
