extends "res://scripts/main.gd"
## Offline: planet enemies wake on a planet's top, walk the real ground, shoot
## back, and the player's arrows (level at shot height over the hills) hit them.
## --shots=<dir> for screenshots.
var _failures := 0

func _parse_args() -> void:
	super._parse_args()
	_args.erase("online")
	_args["play-space"] = ""

func _ready() -> void:
	super._ready()
	_run.call_deferred()

func check(ok: bool, what: String) -> void:
	print("[planet] ", "PASS " if ok else "FAIL ", what)
	if not ok: _failures += 1

func _shot(name: String) -> void:
	for i in 20: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/planet_%s.png" % [str(_args.get("shots", "/tmp")), name])

func _run() -> void:
	while not (world is SpaceWorld) or player.frozen or not world.is_presentation_ready(): await get_tree().process_frame
	var space := world as SpaceWorld
	var traversal := player.spatial_controller as SpaceTraversal
	while traversal.cinematic: await get_tree().process_frame
	for planet_id in ["verdance", "mawgrave"]:
		var p := SpaceLayout.planet(planet_id)
		var site: Dictionary = {}
		for id: String in space.enemy_director._sites:
			if id.contains(planet_id) and not id.contains("god") and not id.contains("fort"): site = space.enemy_director._sites[id]
		check(not site.is_empty(), "%s has enemy packs" % planet_id)
		if site.is_empty(): continue
		var at: Vector3 = site.pos
		var up := (at-(p.center as Vector3)).normalized()
		var stand := SpaceLayout.surface_point(p, at+up.cross(Vector3.RIGHT).normalized()*9.0)+up*1.0
		player.global_position = stand
		(space.planets[planet_id] as SpacePlanet).terrain.ensure_ground(stand)
		var hp_before := player.stats.hp
		var near: Array = []
		var wake_until := Time.get_ticks_msec()+10000
		var woke_at := 0
		while Time.get_ticks_msec()<wake_until:
			await get_tree().process_frame
			near = space.enemy_director.enemies().filter(func(e: Enemy) -> bool: return e.is_alive() and e.global_position.distance_to(player.global_position)<40.0)
			if near.is_empty(): continue
			if woke_at==0: woke_at = Time.get_ticks_msec()
			if Time.get_ticks_msec()-woke_at>1000: break
		check(not near.is_empty(), "%s enemies wake near the player (%d)" % [planet_id, near.size()])
		if near.is_empty(): continue
		await get_tree().create_timer(2.0).timeout
		var grounded := near.all(func(e: Enemy) -> bool: return not is_instance_valid(e) or absf(e.global_position.y-space.ground_height(e.global_position.x, e.global_position.z))<0.6)
		check(grounded, "%s enemies stand on the planet's ground" % planet_id)
		await _shot(planet_id+"_fight")
		# Shoot the nearest one for a few seconds.
		near = near.filter(func(e: Enemy) -> bool: return is_instance_valid(e) and e.is_alive())
		check(not near.is_empty(), "%s: someone left to fight" % planet_id)
		if near.is_empty(): continue
		var target: Enemy = near[0]
		var max_hp := target.hp
		# Close to bow range, on the ground beside it.
		var side := (player.global_position-target.global_position)
		side.y = 0.0
		var spot := target.global_position+side.normalized()*8.0
		spot.y = space.ground_height(spot.x, spot.z)+0.2
		player.global_position = spot
		(space.planets[planet_id] as SpacePlanet).terrain.ensure_ground(spot)
		await get_tree().create_timer(0.3).timeout
		# Their shots climb and drop with the slope: stand well above or below the
		# target (with no hill between, which would stop them) and get hit.
		var best := spot
		var from := target.global_position
		for k in 24:
			var a := TAU*k/24.0
			for r: float in [7.0, 9.0, 11.0]:
				var q := from+Vector3(cos(a), 0, sin(a))*r
				q.y = space.ground_height(q.x, q.z)
				var clear := true
				for i in range(1, 10):
					var m := from.lerp(q, i/10.0)
					if space.ground_height(m.x, m.z)>m.y+Player.SHOT_HEIGHT-0.5: clear = false
				if clear and absf(q.y-from.y)>absf(best.y-from.y): best = q
		player.global_position = best+Vector3(0, 0.2, 0)
		(space.planets[planet_id] as SpacePlanet).terrain.ensure_ground(player.global_position)
		player.stats.hp = player.stats.max_hp
		var lowest := player.stats.hp
		var held_until := Time.get_ticks_msec()+6000
		while Time.get_ticks_msec()<held_until and lowest>=player.stats.max_hp:
			player.global_position = best+Vector3(0, 0.2, 0)
			player.velocity = Vector3.ZERO
			await get_tree().process_frame
			lowest = minf(lowest, player.stats.hp)
		check(lowest<player.stats.max_hp, "%s: enemy shots reach us %.1f m %s them (hp %d)" % [planet_id, absf(best.y-target.global_position.y),
			"above" if best.y>target.global_position.y else "below", lowest])
		player.global_position = spot
		# The cursor path: points at shot height over the hills around us project to
		# the screen and back; the aim must land on them (realm-like aiming).
		var worst := 0.0
		for k in 12:
			var a := TAU*k/12.0
			var q := spot+Vector3(cos(a), 0, sin(a))*(4.0+k)
			q.y = space.ground_height(q.x, q.z)+Player.SHOT_HEIGHT
			var screen := player.camera.unproject_position(q)
			var hit: Variant = traversal._cap_aim(player.camera.project_ray_origin(screen), player.camera.project_ray_normal(screen))
			worst = maxf(worst, q.distance_to(hit) if hit is Vector3 else 99.0)
		check(worst<0.5, "%s: the cursor aims at shot height over the ground under it (worst %.2f m)" % [planet_id, worst])
		GameServer.debug_godmode = true
		var until := Time.get_ticks_msec()+5000
		while Time.get_ticks_msec()<until and is_instance_valid(target) and target.is_alive():
			player._aim_point = target.global_position
			player.shoot()
			await get_tree().create_timer(0.15).timeout
		check(not is_instance_valid(target) or not target.is_alive() or target.hp<max_hp, "%s: arrows hit the enemy (%d -> %d)" % [planet_id, max_hp, target.hp if is_instance_valid(target) else 0])
		check(true, "%s: player hp %d -> %d while fighting" % [planet_id, hp_before, player.stats.hp])
		await _shot(planet_id+"_after")
		GameServer.debug_godmode = false
	print("[planet] done failures=", _failures)
	get_tree().quit()
