extends "res://scripts/main.gd"
## Look-development shots of the Astral Reach (offline): free camera views of
## the Nexus rock, planets from orbit and on the ground, the Shardfield and
## the edge of the Reach. --shots=<dir>, --only=<name,...> to pick views.
var _out := "/tmp"

func _parse_args() -> void:
	super._parse_args()
	_args.erase("online")
	_args["play-space"] = ""

func _ready() -> void:
	super._ready()
	_out = str(_args.get("shots", "/tmp"))
	_run.call_deferred()

func _shot(name: String, frames := 40) -> void:
	for i in frames: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/lab_%s.png" % [_out, name])
	print("[lab] ", name)

func _view(eye: Vector3, at: Vector3, up := Vector3.UP, fov := 70.0) -> void:
	player.camera.global_transform = Transform3D(Basis.IDENTITY, eye).looking_at(at, up if absf((at-eye).normalized().dot(up))<0.98 else Vector3.FORWARD)
	player.camera.fov = fov

func _wanted(name: String) -> bool:
	return not _args.has("only") or name in str(_args.only).split(",")

func _run() -> void:
	while not (world is SpaceWorld) or player.frozen or not world.is_presentation_ready(): await get_tree().process_frame
	var space := world as SpaceWorld
	var traversal := player.spatial_controller as SpaceTraversal
	while traversal.cinematic: await get_tree().process_frame
	traversal.cinematic = true
	hud.visible = false
	var views := []
	views.append(["nexus_rock", Vector3(210, 30, 260), Vector3(0, -35, 0)])
	views.append(["nexus_under", Vector3(120, -150, 160), Vector3(0, -40, 0)])
	var verdance := SpaceLayout.planet("verdance")
	var c: Vector3 = verdance.center
	views.append(["verdance_orbit", c+Vector3(-1800, 600, 1200), c])
	views.append(["verdance_far", SpaceLayout.NEXUS+Vector3(0, 40, 0), c])
	var pad := SpaceLayout.pad_frame(verdance)
	views.append(["verdance_ground", pad.origin+pad.basis.y*2.0+pad.basis.z*20.0, pad.origin+pad.basis.y*6.0-pad.basis.z*200.0, pad.basis.y])
	views.append(["verdance_low", pad.origin+pad.basis.y*120.0+pad.basis.z*260.0, pad.origin, pad.basis.y])
	var field: Vector3 = SpaceLayout.passes()[1]
	views.append(["shardfield", field+Vector3(300, 200, -2600), field])
	var sun := SpaceLayout.SUN_CENTER
	views.append(["sun_far", Vector3(0, 30, 0), sun])
	views.append(["sun_near", sun+(Vector3.ZERO-sun).normalized()*9000.0+Vector3(1500, 800, 0), sun])
	views.append(["edge", Vector3(0, 0, -SpaceLayout.WORLD_RADIUS+900.0), Vector3(400, 300, -SpaceLayout.WORLD_RADIUS)])
	for p: Dictionary in SpaceLayout.PLANETS:
		var town := SpaceLayout.town_frame(p, "center")
		var at: Vector3 = (p.center as Vector3)+town.origin
		views.append(["town_"+str(p.id), at+town.basis.y*30.0+town.basis.z*52.0, at+town.basis.y*3.0, town.basis.y])
	for p: Dictionary in SpaceLayout.PLANETS:
		if p.id=="verdance": continue
		var pc: Vector3 = p.center
		views.append(["orbit_"+str(p.id), pc+(SpaceLayout.pad_frame(p).basis.y*2.6+Vector3(0.3, 0.4, 0))*float(p.radius), pc])
	if _args.has("gear"):
		# The local player's helmet and jetpack up close, flames on.
		await get_tree().create_timer(1.0).timeout
		SpaceHelmet.dress(player.model)
		var pack := SpaceHelmet._jetpack(player.model, true)
		for flame: Node3D in pack.get_meta("flames"): flame.visible = true
		var at := player.global_position+Vector3.UP*1.0
		_view(at+Vector3(2.2, 0.6, 1.6), at)
		await _shot("gear_side", 30)
		_view(at+Vector3(-0.6, 0.4, 2.6), at)
		await _shot("gear_back", 20)
		_view(at+Vector3(0.3, 0.5, -2.4), at+Vector3.UP*0.4)
		await _shot("gear_front", 20)
		get_tree().quit()
		return
	if _args.has("brood"):
		await _brood_views(space, traversal)
		get_tree().quit()
		return
	if _args.has("ship"):
		await _ship_views(space, traversal)
		get_tree().quit()
		return
	for v: Array in views:
		if not _wanted(v[0]): continue
		# Ground near the eye has to exist before the shot.
		for planet: SpacePlanet in space.planets.values():
			if planet.terrain and (v[1] as Vector3).distance_to(planet.global_position)<planet._radius*1.5: planet.terrain.ensure_ground(v[1])
		_view(v[1], v[2], v[3] if v.size()>3 else Vector3.UP)
		for hide: String in str(_args.get("hide", "")).split(",", false):
			for node in space.find_children(hide, "", true, false): node.visible = false
		await _shot(v[0], 90)
	get_tree().quit()

## The battleship: hull at the berth, the room's live windows, the helm in
## first person and the chase view, at the berth and in flight.
func _ship_views(space: SpaceWorld, traversal: SpaceTraversal) -> void:
	traversal.cinematic = false
	space.request(["spawn"])
	await get_tree().process_frame
	var ship: SpaceShip = space.ships.values()[0]
	await get_tree().create_timer(0.5).timeout
	var view: SpaceShipView = space.ship_views[ship.id]
	traversal.cinematic = true
	var pose := view.global_transform
	if _wanted("hull_side"):
		_view(pose*Vector3(46, 14, -10), pose*Vector3(0, 0, -2))
		await _shot("hull_side", 60)
	if _wanted("hull_front"):
		_view(pose*Vector3(-14, 6, -62), pose*Vector3(0, 2, 0))
		await _shot("hull_front", 30)
	if _wanted("hull_rear"):
		_view(pose*Vector3(20, 22, 70), pose*Vector3(0, 0, 0))
		await _shot("hull_rear", 30)
	traversal.cinematic = false
	space.request(["board", ship.id])
	await get_tree().create_timer(0.6).timeout
	space.request(["sit", "pilot"])
	await get_tree().create_timer(0.3).timeout
	# Take off and fly toward Verdance a little.
	var target: Vector3 = SpaceLayout.planet("verdance").center
	var until := Time.get_ticks_msec()+7000
	while Time.get_ticks_msec()<until:
		var local := ship.xform.basis.inverse()*(target-ship.xform.origin).normalized()
		ship.input = [1.0, clampf(local.x*3.0, -1, 1), clampf(local.y*3.0, -1, 1), 0.0, true, false]
		ship.input_age = 0.0
		await get_tree().process_frame
	if _wanted("chase"):
		traversal._cockpit = false
		await _shot("chase", 20)
	if _wanted("helm"):
		traversal._cockpit = true
		await _shot("helm", 20)
		traversal._cockpit = false
	if _wanted("room"):
		space.request(["stand"])
		await get_tree().create_timer(0.3).timeout
		var room := SpaceLayout.pocket_origin(ship.slot)
		player.global_position = room+Vector3(-4.0, 0.1, -9.5)
		player.camera_yaw = PI*0.5
		traversal.look_pitch = 0.0
		await _shot("room_porthole", 40)
		player.global_position = room+Vector3(0, 0.1, -10)
		player.camera_yaw = 0.0
		await _shot("room_bridge", 40)

## The brood's ships up close, and the star chart.
func _brood_views(space: SpaceWorld, traversal: SpaceTraversal) -> void:
	var at := Vector3(0, 400, 9000)
	var kinds := ["brood_skiff", "void_eel", "brood_carrier"]
	for i in kinds.size():
		var ship := BroodShip.new()
		space.foes.add_child(ship)
		ship.global_position = at+Vector3(-160+i*170, 0, 0)
		ship.build(kinds[i])
		ship.global_basis = Basis(Vector3.UP, 0.6)
		for k in 30:
			ship.animate(0.05)
	_view(at+Vector3(40, 90, 260), at+Vector3(10, 0, 0))
	await _shot("brood", 30)
	_view(at+Vector3(-160+12, 6, -30), at+Vector3(-160, 0, 0))
	await _shot("brood_skiff", 20)
	traversal.cinematic = false
	hud.visible = true
	traversal.toggle_map()
	await _shot("map", 20)
	traversal.map.zoom = 0.004
	await _shot("map_far", 20)
