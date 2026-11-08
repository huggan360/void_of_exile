extends "res://scripts/main.gd"
## Offline: every planet stronghold (SpaceLayout.FORTS) stands on level ground,
## starts sealed, opens with its key, and its boss wakes and fights (bullets
## fly, arrows hurt it). --shots=<dir> for an overview and a fight screenshot
## per fortress; --only=<planet> for one.
var _failures := 0

func _parse_args() -> void:
	super._parse_args()
	_args.erase("online")
	_args["play-space"] = ""

func _ready() -> void:
	super._ready()
	_run.call_deferred()

func check(ok: bool, what: String) -> void:
	print("[fort] ", "PASS " if ok else "FAIL ", what)
	if not ok: _failures += 1

func _shot(name: String) -> void:
	for i in 20: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/fort_%s.png" % [str(_args.get("shots", "/tmp")), name])

func _stand(space: SpaceWorld, planet_id: String, at: Vector3) -> void:
	at.y = space.ground_height(at.x, at.z)+0.2
	player.global_position = at
	player.velocity = Vector3.ZERO
	(space.planets[planet_id] as SpacePlanet).terrain.ensure_ground(at)

func _run() -> void:
	while not (world is SpaceWorld) or player.frozen or not world.is_presentation_ready(): await get_tree().process_frame
	var space := world as SpaceWorld
	var traversal := player.spatial_controller as SpaceTraversal
	while traversal.cinematic: await get_tree().process_frame
	while not is_instance_valid(space.gates): await get_tree().process_frame
	var stats := GameServer.character(player.player_id)
	for planet_id: String in SpaceLayout.FORTS:
		if _args.has("only") and str(_args.only)!=planet_id: continue
		var fort: Dictionary = SpaceLayout.FORTS[planet_id]
		var center := PlanetStrongholds.center_of(planet_id)
		var entry: Dictionary = space.gates.entries.get(center, {})
		check(not entry.is_empty(), "%s has a stronghold" % planet_id)
		if entry.is_empty(): continue
		var root: Node3D = entry.root
		# Level: the whole arena and walls at one height.
		var low := INF
		var high := -INF
		for x in range(-36, 37, 4):
			for z in range(-36, 37, 4):
				var q := root.to_global(Vector3(x, 0, z))
				var h := space.ground_height(q.x, q.z)
				low = minf(low, h)
				high = maxf(high, h)
		check(high-low<0.15, "%s: the fortress ground is flat (%.2f m of difference)" % [planet_id, high-low])
		check(entry.sealed and entry.locked, "%s: the gates start sealed" % planet_id)
		# Overview from above the main gate.
		_stand(space, planet_id, root.to_global(Vector3(0, 0, -44)))
		var eye := Camera3D.new()
		add_child(eye)
		eye.global_transform = Transform3D(Basis.IDENTITY, root.to_global(Vector3(0, 46, -78))).looking_at(root.to_global(Vector3(0, 0, -4)))
		eye.make_current()
		await get_tree().create_timer(1.5).timeout
		await _shot(planet_id+"_overview")
		eye.queue_free()
		player.camera.make_current()
		# No key: nothing happens. With the key it opens.
		_stand(space, planet_id, root.to_global(Vector3(0, 0, -38)))
		await get_tree().create_timer(0.3).timeout
		space.gates.use_key(center, player)
		check(entry.sealed, "%s: no key, still sealed" % planet_id)
		stats.give([Items.make(str(fort.key))])
		space.gates.use_key(center, player)
		check(not entry.sealed and stats.find_item(str(fort.key)).is_empty(), "%s: the key opens the gates and is spent" % planet_id)
		await get_tree().create_timer(5.5).timeout  # the opening shot
		check(not entry.locked, "%s: the portcullis is up" % planet_id)
		# In, wake the boss, fight it.
		_stand(space, planet_id, root.to_global(Vector3(0, 0, -16)))
		var boss: Boss = null
		var until := Time.get_ticks_msec()+8000
		while boss==null and Time.get_ticks_msec()<until:
			await get_tree().process_frame
			for e: Enemy in space.enemy_director.enemies():
				if e is Boss and e.def.id==str(fort.boss): boss = e
		check(boss!=null, "%s: %s waits inside" % [planet_id, fort.boss])
		if boss==null: continue
		GameServer.debug_godmode = true
		until = Time.get_ticks_msec()+14000
		while boss.phase<0 and Time.get_ticks_msec()<until: await get_tree().process_frame
		check(boss.phase>=0, "%s: the boss wakes and fights (phase %d)" % [planet_id, boss.phase])
		check(entry.locked, "%s: the gates bar during the fight" % planet_id)
		var most := 0
		var hp0 := boss.hp
		until = Time.get_ticks_msec()+7000
		var shot_taken := false
		while Time.get_ticks_msec()<until and boss.is_alive():
			player._aim_point = boss.global_position
			player.shoot()
			most = maxi(most, space.enemy_director.bullets._shots.size())
			if not shot_taken and Time.get_ticks_msec()>until-3500:
				shot_taken = true
				await _shot(planet_id+"_fight")
			await get_tree().create_timer(0.1).timeout
		check(most>=20, "%s: bullet heavy (up to %d shots in the air)" % [planet_id, most])
		check(boss.hp<hp0, "%s: arrows hurt it (%d -> %d)" % [planet_id, hp0, boss.hp])
		# Phases: skip to the last and make sure it keeps firing.
		boss.debug_skip_to(2)
		await get_tree().create_timer(6.0).timeout
		check(boss.phase==2 and space.enemy_director.bullets._shots.size()>0, "%s: the last phase fights (phase %d, %d shots)" % [planet_id, boss.phase, space.enemy_director.bullets._shots.size()])
		await _shot(planet_id+"_phase3")
		GameServer.debug_godmode = false
		boss.reset_attempt()
		_stand(space, planet_id, root.to_global(Vector3(0, 0, -44)))
		await get_tree().create_timer(2.5).timeout
	print("[fort] done failures=", _failures)
	get_tree().quit()
