extends "res://scripts/main.gd"
## End-to-end city checks. Uses an isolated XDG_DATA_HOME; --shots saves views.
var _failures := 0

func _parse_args() -> void:
	super._parse_args()
	if not _args.has("online"): _args["play-space"] = ""
	else:
		_args["space-test"] = ""
		_args["qa-quick"] = ""

func _ready() -> void:
	super._ready()
	_run.call_deferred()
	get_tree().create_timer(100.0).timeout.connect(func() -> void:
		print("[city] TIMEOUT")
		get_tree().quit(2))

func check(ok: bool, label: String) -> void:
	print("[city] ", "PASS " if ok else "FAIL ", label)
	if not ok: _failures += 1

func _wait(seconds := 0.3) -> void:
	await get_tree().create_timer(seconds).timeout

func _place(at: Transform3D) -> void:
	player.global_transform = at
	player.up_direction = at.basis.y
	player.velocity = Vector3.ZERO
	(world as SpaceWorld).planets[CityLayout.ID].terrain.ensure_ground(at.origin)
	if Net.is_client(): Net.client.send_position(at.origin)

func _shot(label: String, pose: Transform3D) -> void:
	if not _args.has("shots"): return
	transition.hide()
	var camera := Camera3D.new()
	camera.far = 90000
	camera.environment = player.camera.environment
	add_child(camera)
	camera.global_transform = pose
	camera.make_current()
	await _wait(0.4)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(str(_args.shots)+"/city_"+label+".png")
	camera.queue_free()
	player.camera.make_current()

func _run() -> void:
	if _args.has("online"):
		while not Net.is_client() or not Net.client.connected or not is_instance_valid(world) or _traveling or player.frozen: await get_tree().process_frame
		await _wait(1.0)
		await travel("astral")
	while not (world is SpaceWorld) or player.frozen or _traveling or not world.is_presentation_ready(): await get_tree().process_frame
	var space := world as SpaceWorld
	var control := player.spatial_controller as SpaceTraversal
	while control.cinematic: await get_tree().process_frame
	var planet: SpacePlanet = space.planets[CityLayout.ID]
	var city := planet.get_node("City") as CityPlanet
	var center: Vector3 = CityLayout.planet().center
	var districts: Array = CityLayout.DISTRICTS.slice(0, 1) if _args.has("focused") else CityLayout.DISTRICTS
	for d: Dictionary in districts:
		var port := CityLayout.district_frame(d)
		port.origin += center
		_place(port*Transform3D(Basis.IDENTITY, Vector3(0, 0.6, 25)))
		await _wait(0.8)
		check(city.districts.has(d.id), str(d.id)+": district streamed")
		check(player.global_position.distance_to(port.origin)<70.0, str(d.id)+": port deck holds player")
		var landing := CityLayout.landing_site(port*Vector3(0, 70, 8), 150.0, Callable())
		check(not landing.is_empty(), str(d.id)+": available landing pad")
		await _shot(str(d.id), Transform3D(Basis.IDENTITY, port*Vector3(140, 140, 220)).looking_at(port*Vector3(0, 20, 0), port.basis.y))
	await get_tree().physics_frame
	_paths(city)
	check(CityLayout.landing_site(center+Vector3.DOWN*1020, 150.0, Callable()).is_empty(), "no landing among arbitrary buildings")
	var first := CityLayout.DISTRICTS[0]
	var cafe: Dictionary = CityLayout.venues(first).filter(func(v: Dictionary) -> bool: return v.kind=="cafe")[0]
	var room: Transform3D = cafe.frame
	room.origin += center
	_place(room*Transform3D(Basis.IDENTITY, Vector3(0, 0.2, -7.5)))
	control.camera_mode = SpaceTraversal.CameraMode.SHOULDER
	control.player.camera_yaw = room.basis.get_euler().y
	await _wait()
	# Ray through the door must pass into the room, but one through the window must hit.
	var query := PhysicsRayQueryParameters3D.create(room*Vector3(0, 1.0, -8), room*Vector3(0, 1.0, -3), Player.TERRAIN_LAYER|Player.OBSTACLE_LAYER)
	query.exclude = [player.get_rid()]
	check(player.get_world_3d().direct_space_state.intersect_ray(query).is_empty(), "cafe doorway is clear")
	query.from = room*Vector3(4, 2, -8)
	query.to = room*Vector3(4, 2, -3)
	check(not player.get_world_3d().direct_space_state.intersect_ray(query).is_empty(), "cafe windows are solid")
	var s := CityLayout.any_seat(str(cafe.seats[0].id))
	_place(Transform3D(s.basis, s.stand))
	await _wait()
	space.request(["city", "sit", s.id])
	await _wait()
	space.request(["city", "order"])
	await _wait(3.0)
	check(space.city.seat_of(player.player_id)==s.id, "sit at cafe seat")
	check(float(space.city.cups.get(s.id, 0.0))>0.9, "coffee arrives")
	space.request(["city", "sip"])
	await _wait()
	check(is_equal_approx(float(space.city.cups.get(s.id, 0.0)), 0.75), "sip lowers shared fill")
	check(player.stats.buffs.has_effect("speed"), "coffee grants Speed")
	await _shot("cafe", Transform3D(Basis.IDENTITY, room*Vector3(5, 3, -4.5)).looking_at(room*Vector3(0, 1.0, 2), room.basis.y))
	space.request(["city", "stand"])
	await _wait()
	check(space.city.seat_of(player.player_id)=="", "stand releases seat")
	var bar: Dictionary = CityLayout.venues(first).filter(func(v: Dictionary) -> bool: return v.kind=="bar")[0]
	var bs := CityLayout.any_seat(str(bar.seats[0].id))
	_place(Transform3D(bs.basis, bs.stand))
	await _wait()
	space.request(["city", "sit", bs.id])
	await _wait(3.0)
	space.request(["city", "sip"])
	await _wait()
	check(player.stats.buffs.has_effect("drunk"), "beer grants existing drunk effect")
	space.request(["city", "stand"])
	await _wait()
	var e: Dictionary = CityLayout.elevators()[0]
	var tower := CityLayout.tower_world(e)
	_place(tower*Transform3D(Basis.IDENTITY, Vector3(2.6, 0.15, -2.0)))
	await _wait(0.5)
	space.request(["city", "call", 0, 0])
	var deadline := Time.get_ticks_msec()+24000
	while (int(space.city.elevators[0].floor)!=0 or space.city.elevators[0].phase!="idle") and Time.get_ticks_msec()<deadline: await get_tree().process_frame
	_place(tower*Transform3D(Basis.IDENTITY, CityState.SHAFT+Vector3(0, 0.12, 0)))
	await _wait(0.4)
	check(control._lift==0 and control.first_person>0.8, "elevator forces first person")
	space.request(["city", "call", 0, 1])
	await _wait(8.0)
	var local := tower.affine_inverse()*player.global_position
	check(absf(local.y-44.0)<0.5, "elevator carries rider to sky garden (y=%.2f)" % local.y)
	# Doors still opening (and the mirror a moment behind online): wait for it to settle.
	deadline = Time.get_ticks_msec()+5000
	while (space.city.elevators[0].phase!="idle" or int(space.city.elevators[0].floor)!=1) and Time.get_ticks_msec()<deadline: await get_tree().process_frame
	check(space.city.elevators[0].phase=="idle" and int(space.city.elevators[0].floor)==1, "elevator opens at selected floor")
	_place(tower*Transform3D(Basis.IDENTITY, Vector3(0, 44.1, -7)))
	await _wait()
	check(control.first_person<0.1 and control.camera_mode==SpaceTraversal.CameraMode.SHOULDER, "exit restores shoulder camera")
	await _shot("garden", Transform3D(Basis.IDENTITY, tower*Vector3(8, 47, -9)).looking_at(tower*Vector3(-4, 45, 6), tower.basis.y))
	for mode in 3:
		control.camera_mode = mode
		control.look_pitch = 0.2
		await _wait(0.4)
		check(player.camera.global_position.is_finite(), "camera mode %d has a valid pose" % mode)
		if mode==SpaceTraversal.CameraMode.SHOULDER:
			check(player.model.visible and Input.mouse_mode==Input.MOUSE_MODE_CAPTURED, "shoulder keeps model and captures free look")
		if mode==SpaceTraversal.CameraMode.FIRST_PERSON: check(not player.model.visible, "first person hides local model")
	# State transfer and request validation without changing the live authority.
	var copy := CityState.new()
	copy.apply(space.city.wire())
	check(copy.car_state(0)==space.city.car_state(0), "late join restores elevator pose")
	copy.handle(999, Vector3.ZERO, ["city", "sit", s.id])
	check(copy.seat_of(999)=="", "remote seat request rejected")
	check(CityLayout.any_seat("city:tower999:0").is_empty(), "invalid elevator seat rejected")
	check(city.life._traffic.size()==12, "all twelve traffic models active")
	check(city.life._people.size()>150, "staff, patrons and pedestrian population")
	print("[city] DONE failures=", _failures)
	get_tree().quit(0 if _failures==0 else 1)

func _paths(city: CityPlanet) -> void:
	var center: Vector3 = CityLayout.planet().center
	var physics := player.get_world_3d().direct_space_state
	for d: Dictionary in CityLayout.DISTRICTS:
		if not city.districts.has(d.id): continue
		var district: CityDistrict = city.districts[d.id]
		var port := CityLayout.district_frame(d)
		port.origin += center
		var ramps_ok := true
		for side in 4:
			var turn := Basis(Vector3.UP, side*PI*0.5)
			for k in 8:
				var point := port*(turn*Vector3(0, 0, 49+k*2.0))
				var ray := PhysicsRayQueryParameters3D.create(point+port.basis.y*3.0, point-port.basis.y*5.0, Player.TERRAIN_LAYER|Player.OBSTACLE_LAYER)
				var hit := physics.intersect_ray(ray)
				if hit.is_empty() or (hit.normal as Vector3).dot(port.basis.y)<0.85: ramps_ok = false
		check(ramps_ok, str(d.id)+": port ramps have continuous walkable surfaces")
		for item: Dictionary in CityLayout.district_cells(d):
			if item.role!="secret": continue
			var frame: Transform3D = item.cell.frame
			frame.origin += center
			var query := PhysicsRayQueryParameters3D.create(frame*Vector3(-17, 1.2, 4), frame*Vector3(-7, 1.2, 4), Player.TERRAIN_LAYER|Player.OBSTACLE_LAYER)
			check(physics.intersect_ray(query).is_empty(), str(d.id)+": service tunnel connects to hidden bar")
		var bridge := CityLayout.sky_bridge(str(d.id))
		var up := ((bridge[0] as Vector3)-center).normalized()
		var query := PhysicsRayQueryParameters3D.create((bridge[0] as Vector3)+up, (bridge[1] as Vector3)+up, Player.TERRAIN_LAYER|Player.OBSTACLE_LAYER)
		var blocker := physics.intersect_ray(query)
		if not blocker.is_empty():
			var shape_owner: Node = blocker.collider
			var a: Vector3 = bridge[0]
			print("[city] bridge blocked by %s at %.1f m of %.1f (%s)" % [shape_owner.get_path(), a.distance_to(blocker.position),
				a.distance_to(bridge[1]), CityLayout.tower_world(CityLayout.elevators()[4]).affine_inverse()*blocker.position])
		check(blocker.is_empty(), str(d.id)+": sky bridge doorway path is clear")
		for e: int in district.cars:
			var car: Node3D = district.cars[e].car
			for f in 4:
				var eye := car.to_global(Vector3(0, 1.5, 0))
				var button := car.to_global(district.cars[e].buttons[f])
				check(district.button_at(e, eye, (button-eye).normalized())==f, "lift %d: physical button %d selects correct floor" % [e, f])
	# Different players contend for one seat on the authority; stale/remote
	# requests must not displace the occupant.
	var state := CityState.new()
	var venue: Dictionary = CityLayout.venues(CityLayout.DISTRICTS[0])[0]
	var seat := CityLayout.any_seat(str(venue.seats[0].id))
	state.handle(9001, seat.stand, ["city", "sit", seat.id])
	state.handle(9002, seat.stand, ["city", "sit", seat.id])
	check(state.seat_of(9001)==seat.id and state.seat_of(9002)=="", "seat contention preserves first occupant")
	state.stand(9001)
	check(not state.orders.has(seat.id), "disconnect cancels outstanding drink order")
	var pad: Transform3D = CityLayout.all_pads()[0].frame
	pad.origin += center
	check(CityLayout.landing_site(pad.origin, 150, func(_pose: Transform3D) -> bool: return true).is_empty(), "full ports reject landing")
