extends "res://tools/boss_watch/fight_watcher.gd"
## Uses the real boss definitions and helpers in the desert/lava courtyard.
var watched_boss := "gilded_vizier"

func _start() -> void:
	GameServer.debug_godmode = true
	game.menus.hide_all()
	game.hud.show()
	game.player.input_locked = true
	_overlay()
	var world := game.world as IslandWorld
	for candidate in world.generator.strongholds:
		if candidate.biome_id == BIOMES[key]: fort = candidate; break
	if fort == null:
		_status.text = "Stronghold not found. Escape to close."
		return
	var center := Vector3(fort.center.x + 0.5, fort.base_height + 1, fort.center.y + 0.5)
	game._place_player(center + Vector3(0, 0, 11))
	await game._wait_for_ground()
	game.player.set_physics_process(false)
	game.player.frozen = false
	world.enemy_director.set_process(false)
	world.enemy_director.set_physics_process(false)
	for actor in world.enemy_director.enemies(): actor.queue_free()
	await get_tree().process_frame
	game.enemy_bullets.clear()
	var pack := EnemyPack.new()
	pack.site = {id = "court_preview", pos = center, seed = 4217, pack = ""}
	var definition := Enemies.get_def(watched_boss)
	boss = EnemyDirector._make_actor(definition).setup(definition, pack, world.enemy_director)
	boss.position = world.enemy_director.to_local(center)
	pack.members.append(boss)
	pack.leader = boss
	world.enemy_director.add_child(boss)
	boss.died.connect(func(_actor: Enemy) -> void: finished = true)
	game.atmosphere.fog_of_war_hidden = true
	game.player.camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	game.player.camera.size = 46.0
	_camera()
	if game._args.has("watch-seconds"):
		_finish_after(float(game._args["watch-seconds"]))

func _finish_after(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
	get_tree().quit()

func _camera() -> void:
	if not is_instance_valid(game.player.camera) or fort == null: return
	var center := Vector3(fort.center.x + 0.5, fort.base_height + 3, fort.center.y + 0.5)
	game.player.camera.global_position = center + Vector3(0, 40, 29)
	game.player.camera.look_at(center)

func _process(delta: float) -> void:
	super._process(delta)
	if not is_instance_valid(boss): return
	var previous := int(get_meta("phase", -9))
	if boss.phase != previous:
		set_meta("phase", boss.phase)
		print("[watch] ", watched_boss, " phase=", boss.phase + 1, " hp=", boss.hp)
		if game._args.has("shots") and boss.phase >= 0: _phase_shot(boss.phase + 1)

func _phase_shot(index: int) -> void:
	await get_tree().create_timer(4.0).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/tmp/%s_phase_%d.png" % [watched_boss, index])
