extends "res://scripts/main.gd"
## Offline Astral Reach smoke test: launch, board, sit, fly, land, step out,
## gunnery and the space map. Screenshots go to --shots=<dir> (default /tmp).
var _out := "/tmp"
var _failures := 0

func _parse_args() -> void:
	super._parse_args()
	_args.erase("online")
	_args["play-space"] = ""

func _ready() -> void:
	super._ready()
	_out = str(_args.get("shots", "/tmp"))
	_run.call_deferred()

func check(ok: bool, what: String) -> void:
	print("[space] ", "PASS " if ok else "FAIL ", what)
	if not ok: _failures += 1

func _shot(name: String, frames := 30) -> void:
	for i in frames: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/space_%s.png" % [_out, name])

func _run() -> void:
	GameServer.debug_godmode = true
	while not (world is SpaceWorld) or player.frozen or not world.is_presentation_ready(): await get_tree().process_frame
	var space := world as SpaceWorld
	var traversal := player.spatial_controller as SpaceTraversal
	check(traversal!=null, "space traversal drives the player")
	check(space.zone_at(player.global_position)=="station", "arrival on the Nexus deck")
	await _shot("nexus", 60)
	traversal.play_intro()
	await get_tree().create_timer(6.0).timeout
	await _shot("intro", 2)
	while traversal.cinematic: await get_tree().process_frame
	space.request(["spawn"])
	check(space.ships.size()==1, "command table launches a ship")
	var ship: SpaceShip = space.ships.values()[0]
	space.request(["board", ship.id])
	await get_tree().process_frame
	check(SpaceLayout.pocket_at(player.global_position)==ship.slot, "boarding moves the player into the ship room")
	player.camera_yaw = 0.0
	await _shot("interior", 60)
	space.request(["sit", "pilot"])
	check(ship.pilot()==player.player_id, "player takes the helm")
	await _shot("berth_chase", 40)
	# Take off, then fly toward Verdance for a few seconds.
	var verdance := SpaceLayout.planet("verdance")
	var t := 0.0
	while t<6.0:
		t += get_process_delta_time()
		var to: Vector3 = verdance.center-ship.xform.origin
		var local := ship.xform.basis.inverse()*to.normalized()
		ship.input = [1.0, clampf(local.x*3.0, -1, 1), clampf(local.y*3.0, -1, 1), 0.0, true]
		ship.input_age = 0.0
		await get_tree().process_frame
	check(ship.mode=="flying" and ship.speed>50.0, "the ship takes off and flies (speed %d)" % ship.speed)
	await _shot("flight", 2)
	traversal._cockpit = true
	await _shot("cockpit", 20)
	traversal._cockpit = false
	# Jump the ship beside Verdance's pad and land.
	var pad := SpaceShip.landed_pose(verdance)
	ship.xform = Transform3D(pad.basis, pad.origin+pad.basis.y*120.0)
	ship.speed = 20.0
	ship.velocity = Vector3.ZERO
	await get_tree().create_timer(0.3).timeout
	check(not ship.landable().is_empty(), "Verdance is landable near its pad")
	space.request(["land"])
	var waited := 0.0
	while ship.mode!="landed" and waited<20.0:
		waited += get_process_delta_time()
		await get_tree().process_frame
	check(ship.mode=="landed" and ship.planet=="verdance", "the ship lands on Verdance")
	await _shot("landed", 10)
	space.request(["stand"])
	space.request(["hatch"])
	await get_tree().create_timer(0.5).timeout
	check(space.zone_at(player.global_position)=="planet:verdance", "the hatch lets the crew out onto Verdance")
	await get_tree().create_timer(1.5).timeout
	check(space.zone_at(player.global_position)=="planet:verdance", "the crew stays on the planet (%s)" % space.zone_at(player.global_position))
	await _shot("planet", 30)
	# Walk a little on the curved ground.
	player.debug_input = Vector2(0, -1)
	await get_tree().create_timer(2.0).timeout
	player.debug_input = Vector2.ZERO
	check(space.zone_at(player.global_position)=="planet:verdance", "walking on the round planet keeps its gravity")
	await _shot("planet_walk", 10)
	player.global_position = space.hatch_position(ship)
	space.request(["board", ship.id])
	check(SpaceLayout.pocket_at(player.global_position)==ship.slot, "boarding again from the planet")
	# Free landing: low over open ground far from the pad, the ship sets down
	# by itself on a clear, level spot; brood leave a landed ship alone.
	space.request(["sit", "pilot"])
	var far_dir := (verdance.pad as Vector3).normalized().cross(Vector3.UP).normalized()
	var far_ground := SpaceLayout.surface_point(verdance, (verdance.center as Vector3)+far_dir)
	ship.mode = "flying"
	ship.land_armed = true
	ship.speed = 60.0
	ship.xform = Transform3D(Basis.looking_at(far_dir.cross(Vector3.FORWARD).normalized(), far_dir), far_ground+far_dir*110.0)
	var waited_land := 0.0
	while ship.mode!="landed" and waited_land<15.0:
		waited_land += get_process_delta_time()
		await get_tree().process_frame
	var site := ship.xform.origin-(verdance.center as Vector3)
	check(ship.mode=="landed" and ship.planet=="verdance", "flying low over a planet lands the ship by itself (%s)" % ship.mode)
	check(site.normalized().angle_to((verdance.pad as Vector3).normalized())*float(verdance.radius)>300.0, "it lands where it is, not at the pad")
	check(not PlanetFlora.blocked(verdance, site.normalized()*(float(verdance.radius)+SpaceLayout.surface_height(verdance, site.normalized())), 15.0), "the landing spot is clear of trees and rocks")
	await _shot("landed_free", 40)
	var hull_before := ship.hp
	space.foes.ambushes.append({at = ship.xform.origin+far_dir*200.0, kind = "brood_skiff", count = 3})
	await get_tree().create_timer(4.0).timeout
	check(ship.hp==hull_before and space.foes.foes.values().all(func(f: Dictionary) -> bool: return int(f.target)!=ship.id), "the brood leave a landed ship alone")
	space.request(["stand"])
	space.request(["sit", "turret_left"])
	ship.mode = "flying"
	ship.xform = Transform3D(Basis.IDENTITY, SpaceLayout.SHARDFIELD.center+Vector3(300, -80, -900))
	space.foes.ambushes.append({at = ship.xform.origin+Vector3(-300, 0, 0), kind = "brood_skiff", count = 4})
	await get_tree().create_timer(3.0).timeout
	check(not space.foes.foes.is_empty(), "brood skiffs gather near a flying ship")
	for i in 10:
		space.request(["fire", Vector3.LEFT])
		await get_tree().create_timer(0.25).timeout
	await _shot("turret", 2)
	space.request(["stand"])
	traversal.toggle_map()
	await _shot("map", 10)
	traversal.toggle_map()
	# Quiet skies for the ship's own systems: no brood, ship parked.
	for foe: Dictionary in space.foes.foes.values().duplicate(): space.foes._remove(foe, false, 0)
	ship.mode = "berth"
	# No quick way home from a ship: R only helps the stranded.
	space.request(["rescue"])
	await get_tree().create_timer(0.3).timeout
	check(SpaceLayout.pocket_at(player.global_position)==ship.slot and space._rescues.is_empty(), "R does nothing aboard a ship")
	# The tavern: a drink in an armchair stacks the drunk buff; the tap refills.
	space.request(["sit", "chair_0"])
	space.request(["drink"])
	space.request(["drink"])
	check(player.stats.buffs.count("drunk")==2 and ship.glasses[0]<0.5, "two sips in an armchair: drunk x%d" % player.stats.buffs.count("drunk"))
	space.request(["cigar"])
	check(ship.smoking.has(player.player_id), "a cigar is lit")
	await _shot("tavern", 30)
	space.request(["stand"])
	player.global_position = space.pocket_point(ship.slot, space.interior_anchors.tap)
	space.request(["pour"])
	check(ship.glasses[0]>0.99, "the tap pours a fresh glass")
	# Hits wear the part nearest them; the hull bar is the ship's.
	space.hurt_ship(ship, 600, ship.xform*Vector3(0, -1, 21))
	check(ship.part("engines")<0.5, "a hit at the stern damages the engines (%d%%)" % roundi(ship.part("engines")*100.0))
	var hull_low := ship.hp
	# Out through the airlock onto the hull, jetpack and line.
	player.global_position = space.pocket_point(ship.slot, space.interior_anchors.airlock)
	space.request(["airlock"])
	await get_tree().create_timer(0.4).timeout
	check(space.zone_at(player.global_position)=="void" and traversal.spacewalk, "the airlock lets the crew out onto the hull")
	await _shot("spacewalk", 30)
	traversal._toggle_tether()
	check(not traversal.tether.is_empty(), "the line clips onto the ship")
	var before := ship.xform.origin
	ship.xform.origin += -ship.xform.basis.z*40.0
	await get_tree().create_timer(0.5).timeout
	check(player.global_position.distance_to(space.ship_views[ship.id].global_position)<40.0, "tethered, the crew rides along with the ship")
	ship.xform.origin = before
	await get_tree().create_timer(0.3).timeout
	# The line is 26 m: unhook to float back to the engines at the stern.
	traversal._toggle_tether()
	player.global_position = ship.xform*Vector3(0, -1, 25)
	space.request(["repair", ship.id, "engines"])
	await get_tree().create_timer(SpaceShip.REPAIR_TIME+0.6).timeout
	check(ship.part("engines")>=1.0 and ship.hp>hull_low, "mending the engines from outside restores them and some hull")
	player.global_position = ship.xform*SpaceWorld.AIRLOCK_OUTSIDE
	space.request(["airlock"])
	await get_tree().create_timer(0.3).timeout
	check(SpaceLayout.pocket_at(player.global_position)==ship.slot, "back in through the airlock")
	space.hurt_ship(ship, 100, ship.xform*Vector3(0, -2, 6))
	player.global_position = space.pocket_point(ship.slot, space.interior_anchors.repairs.heart)
	space.request(["repair", "heart"])
	await get_tree().create_timer(SpaceShip.REPAIR_TIME+0.6).timeout
	check(ship.part("heart")>=1.0, "the heart crystal is mended inside")
	# The ship breaks apart: the crew floats free and can call for rescue.
	space.hurt_ship(ship, SpaceShip.MAX_HP*2)
	await get_tree().create_timer(0.4).timeout
	check(space.zone_at(player.global_position)=="void" and space.stranded(player.player_id, player.global_position), "a lost ship leaves the crew floating in space")
	await _shot("adrift", 20)
	space.request(["rescue"])
	await get_tree().create_timer(SpaceWorld.RESCUE_TIME+0.8).timeout
	check(space.zone_at(player.global_position)=="station", "Orin's rescue skiff brings the stranded home")
	print("[space] camera distance ", player.camera_distance, " camera height ", player.camera.global_position.y)
	await _shot("nexus_return", 90)
	player.camera_distance = 22.0
	await _shot("nexus_far", 60)
	print("[space] smoke complete failures=", _failures)
	get_tree().quit()
