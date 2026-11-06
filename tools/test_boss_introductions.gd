extends Node3D
var checks := 0
var failures := 0
class IntroDungeon extends DungeonWorld:
	func _ready() -> void:
		enemy_director.world = self
		enemy_director.realm_id = realm_id
		add_child(enemy_director)
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(message)
func _ready() -> void: _run.call_deferred()
func _run() -> void:
	var layout := RealmLayout.data()
	var gen := IslandGenerator.new(WorldServer.MAP_SEED,layout)
	check(IslandGenerator.RADIUS==640,"Realm expanded in every direction")
	var expected := {"Hearthwick":Vector2i.ZERO,"Bramblebrook":Vector2i(88,-47),"Snowbell":Vector2i(198,7),"Sunveil":Vector2i(-170,115)}
	for town in gen.villages: check(town.center==expected[town.display_name],"Authored town position preserved: "+town.display_name)
	for fort in gen.strongholds:
		check(Vector2(fort.center).length()>480,"Stronghold deep in expanded biome")
		check(gen._base_column(fort.center.x,fort.center.y).y==fort.biome_id,"Stronghold matches its natural biome")
		for other in gen.strongholds:
			if other!=fort: check(Vector2(other.center-fort.center).length()>500,"Strongholds are well separated")
	var record := {id="cinematic_fixture",seed=WorldServer.MAP_SEED,destroyed=[],cleared_packs=[],pack_survivors={}}
	var world := IslandWorld.new(record)
	add_child(world)
	world.enemy_director.set_physics_process(false)
	var shots := EnemyBullets.new()
	add_child(shots)
	shots.set_physics_process(false)
	var players: Array[Player] = []
	for i in 2:
		var player := Player.new()
		player.player_id = GameServer.join(false)
		player.stats = GameServer.character(player.player_id)
		add_child(player)
		add_child(player.aim_marker)
		player.set_physics_process(false)
		player.frozen = false
		players.append(player)
	world.enemy_director.setup(players[0],shots,[])
	world.enemy_director.players.append(players[1])
	var cinematic := BossIntroduction.new()
	add_child(cinematic)
	var ids := {Biomes.DOOM:"vharok",Biomes.FOSEN:"rimeheart_prism",Biomes.BLUELAY:"blue_dragon",Biomes.DESERT:"scarab_regent",Biomes.DEEP_DARK:"hollow_crown"}
	for fort in gen.strongholds:
		var boss := EnemyDirector._make_actor(Enemies.get_def(ids[fort.biome_id])) as Boss
		var pack := EnemyPack.new()
		boss.setup(Enemies.get_def(ids[fort.biome_id]),pack,world.enemy_director)
		boss.position = Vector3(fort.center.x+.5,fort.base_height+1,fort.center.y+.5)
		world.enemy_director.add_child(boss)
		boss.set_physics_process(false)
		for i in players.size():
			players[i].global_position = boss.global_position+Vector3(i*3,0,12)
			GameServer.report_position(players[i].player_id,world.realm_id,players[i].global_position)
		# Enter through an unlocked fortress, as a real keyed attempt does.
		world.gates.apply_state(fort.center, false, false)
		world.gates._end_shot()
		boss._hatch()
		check(boss.intro_duration>=10,"Longer intro: "+boss.def.id)
		check(boss.intro_players.size()==2,"Both participants admitted: "+boss.def.id)
		for player in players:
			check(GameServer.intro_locked(player.player_id),"Server locks participant actions")
			var hp := player.stats.hp
			GameServer.hit_player(player.player_id,5000,true)
			check(player.stats.hp==hp,"Participants protected from lethal hits during intro")
		players[0].camera.make_current()
		cinematic.update(players[0],world,.2,true)
		check(cinematic.visible and players[0].cinematic_locked and cinematic._camera.current,"Local name reveal and cinematic camera start")
		var before := cinematic._camera.global_position
		cinematic.update(players[0],world,2.0,true)
		check(cinematic._camera.global_position.distance_to(before)>.1,"Camera moves slowly over the boss")
		cinematic.cancel()
		check(not players[0].cinematic_locked and players[0].camera.current,"Normal camera and independent controls restored")
		var entry: Dictionary = world.gates.entries[fort.center]
		entry.close_at = 0
		world.gates._process(.01)
		var should_close := fort.biome_id in [Biomes.DOOM,Biomes.DESERT,Biomes.DEEP_DARK]
		check(entry.locked==should_close,"Selected fights close their gates")
		var start2d := Vector2(fort.center)+Vector2(fort.to_world(Vector2i(0,-30)))
		var end2d := Vector2(fort.center)+Vector2(fort.to_world(Vector2i(0,-39)))
		var a := Vector3(start2d.x,fort.base_height+1,start2d.y)
		var b := Vector3(end2d.x,fort.base_height+1,end2d.y)
		check(world.gates.blocks_segment(a,b)==should_close,"Server catches attempts to walk through shut gates")
		boss.reset_attempt()
		check(entry.sealed and not entry.requested,"Reset seals the fortress for another key")
		check(not GameServer.intro_locked(players[0].player_id),"Reset clears participant locks")
		if should_close:
			world.gates.apply_state(fort.center, false, false)
			entry.requested = true
			entry.close_at = 0
			players[0].global_position = a.lerp(b,.5)
			world.gates._process(0)
			check(not entry.locked,"Gates cannot close over a player")
			players[0].global_position = boss.global_position+Vector3(0,0,12)
			world.gates._process(0)
			check(entry.locked,"Gates close once passage is clear")
			boss._start_dying()
			check(not entry.locked,"Boss death reopens gates immediately")
		boss.free()
	world.gates._end_shot()
	var dungeon := IntroDungeon.new(Dungeons.record("dng_intro_check", "goblins_cave", 4217))
	add_child(dungeon)
	dungeon.enemy_director.set_physics_process(false)
	dungeon.enemy_director.setup(players[0], shots, [])
	dungeon.enemy_director.players.append(players[1])
	var king := EnemyDirector._make_actor(Enemies.get_def("goblin_king")) as Boss
	king.setup(Enemies.get_def("goblin_king"), EnemyPack.new(), dungeon.enemy_director)
	king.position = dungeon.layout.boss
	dungeon.enemy_director.add_child(king)
	king.set_physics_process(false)
	for player in players:
		player.global_position = king.global_position + Vector3(0,0,8)
		GameServer.report_position(player.player_id, dungeon.realm_id, player.global_position)
	king._start_intro()
	var gui := CanvasLayer.new()
	var hidden_gui := CanvasLayer.new()
	add_child(gui)
	add_child(hidden_gui)
	hidden_gui.hide()
	players[0].camera.make_current()
	cinematic.update(players[0], dungeon, .2, true)
	check(cinematic.visible and players[0].cinematic_locked and cinematic._camera.current,
		"Dungeon boss loading uses the intro camera and locks local movement consistently with the server")
	check(not gui.visible and not hidden_gui.visible, "Boss intro hides game GUI")
	check(cinematic._intro_audio.get("event", "") == "boss_intro", "Boss reveal plays the cinematic horror impact")
	king.state = Enemy.State.ACTIVE
	cinematic.update(players[0], dungeon, .2, true)
	check(gui.visible and not hidden_gui.visible and not players[0].cinematic_locked,
		"Intro end restores only previously visible GUI and returns local control")
	players[0].cinematic_locked = true
	cinematic.update(players[0], dungeon, .1, false)
	check(players[0].cinematic_locked, "Idle boss presenter cannot cancel another cinematic's input lock")
	players[0].cinematic_locked = false
	GameServer.cancel_boss_intro(king.encounter_id)
	gui.free()
	hidden_gui.free()
	dungeon.queue_free()
	# Preserve killed packs while relocating their fortresses.
	var old := {layout_version=5,cleared_packs=["feature_97_-268","pack_0_0"],pack_survivors={"feature_97_-268_1":["cinder_oracle"]},destroyed=["tree_old"]}
	WorldServer._migrate_expansion(old)
	check("feature_172_-475" in old.cleared_packs and "pack_0_0" in old.cleared_packs,"Expansion preserves and translates finite deaths")
	check(old.pack_survivors["feature_172_-475_1"]==["cinder_oracle"] and old.destroyed==["tree_old"],"Expansion preserves survivors and destroyed objects")
	cinematic.clear_world()
	cinematic.free()
	for player in players: GameServer.remove_player(player.player_id); player.free()
	shots.free()
	world.queue_free()
	GameAudio.set_context(null, null)
	for voice in GameAudio.voices: GameAudio.stop(voice, .01)
	await get_tree().create_timer(.2).timeout
	print("BOSS INTRODUCTIONS: %d checks; %d failures" % [checks,failures])
	get_tree().quit(1 if failures else 0)
