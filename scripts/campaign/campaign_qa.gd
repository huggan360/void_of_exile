class_name CampaignQA
extends RefCounted
## Local QA actions. Both dispatch and entry require the dedicated server's --test mode.
static func handle(server: NetServer, p: Dictionary, args: Array) -> void:
	if not server.config.test_mode or args.is_empty() or p.name not in ["p2", "p3"]: return
	var party := server.social.party_for(p.player_id)
	match str(args[0]):
		"unlock":
			if args.size() != 2 or p.name not in ["p2", "p3"]: return
			var stats := GameServer.character(p.player_id)
			for i in stats.backpack.size():
				if stats.backpack[i]: stats.take({kind = "pack", key = i})
			var map := Items.make("story_clue")
			map.count = 4
			stats.give([map])
			var id := str(Campaigns.get_def(str(args[1])).get("requires", ""))
			while id != "":
				var run := server.campaigns._fresh_run(id)
				run.status = "done"
				server.campaigns.book(p.account_id).runs[id] = run
				id = str(Campaigns.get_def(id).get("requires", ""))
			server.campaigns._touch(p.account_id)
			server.campaigns.flush()
		"quick_kill":
			var realm: RealmInstance = server.realms.get(p.realm)
			if realm == null: return
			for enemy: Enemy in realm.enemies.values().duplicate():
				if not is_instance_valid(enemy) or enemy.global_position.distance_to(p.pos) > 65.0: continue
				if enemy is Boss:
					if enemy.state not in [Enemy.State.DYING, Enemy.State.DEAD]: enemy._start_dying()
				else:
					enemy.take_hit(enemy.global_position, Vector3.ZERO, 100000, realm.proxies.get(p.player_id))
		"state":
			var run := server.campaigns._run_of(party)
			var world := {}
			if not party.is_empty() and not party.campaign.is_empty():
				var realm: RealmInstance = server.realms.get(party.campaign.realm)
				if realm:
					server.social.save_fog()
					for key: String in CampaignServer.WORLD_KEYS: world[key] = realm.record.get(key, [])
			server.social.send(p.player_id, ["qa_state", {run = run.duplicate(true), world = world}])
		"checkpoint":
			server.campaigns._keep_world(party)
			await server.campaigns.flush()
			server.social.system(p.player_id, "[qa] checkpoint saved")
		"kill":
			var realm: RealmInstance = server.realms.get(p.realm)
			if realm == null: return
			for enemy: Enemy in realm.enemies.values():
				if is_instance_valid(enemy) and enemy.global_position.distance_to(p.pos) < 42.0 and not enemy is Boss:
					enemy.take_hit(enemy.global_position, Vector3.ZERO, 100000, realm.proxies.get(p.player_id))
		"boss":
			server.dungeons.debug_defeat(p)
		"arena":
			var castle: bool = args.size() > 1 and args[1] == "castle"
			var id := "dng_qa_%s_%d" % ["castle" if castle else "arena", p.player_id]
			if not server.realms.has(id):
				server.open_realm_record(id, {id = id, castle = true, seed = 0, destroyed = [], name = "QA Castle"} if castle else Dungeons.record(id, "cinder_depths_encore", 4217, "hall"))
			server.dungeons.grants[p.player_id] = id
			server.social.send_to(p.player_id, id)
		"spawn_boss":
			if args.size() != 2 or not p.realm.begins_with("dng_qa_"): return
			var realm: RealmInstance = server.realms.get(p.realm)
			var def := Enemies.get_def(str(args[1]))
			if realm == null or not def is BossDef: return
			for enemy: Enemy in realm.enemies.values(): enemy.queue_free()
			await server.get_tree().process_frame
			var director: EnemyDirector = realm.world.enemy_director
			director.set_process(false)
			var pack := EnemyPack.new()
			pack.site = {id = "qa_boss", pos = realm.world.get_node("BossSpot").position if realm.world is CastleWorld else realm.world.layout.boss, seed = 4217}
			var actor := EnemyDirector._make_actor(def).setup(def, pack, director) as Boss
			actor.position = realm.world.get_node("BossSpot").position if realm.world is CastleWorld else realm.world.layout.boss
			if realm.world is CastleWorld:
				realm.world.encounter.set_process(false)
				realm.world.encounter.set_physics_process(false)
			director.add_child(actor)
			pack.members.append(actor)
			server.social.warp(p.player_id, p.realm, actor.global_position + Vector3(0, 0, 12))
			await server.get_tree().create_timer(2.5).timeout
			if is_instance_valid(actor):
				if actor.is_sealed(): actor._hatch()
				else: actor._start_intro()
		"inspect":
			for enemy: Enemy in server.realms[p.realm].enemies.values():
				if enemy is Boss:
					print("[qa server boss] ", enemy.def.id, " phase=", enemy.phase, " hp=", enemy.hp, " state=", enemy.state, " hazards=", enemy.hazards.count(), " pose=", enemy.model._boss_pose_name)
		"damage_boss":
			var realm: RealmInstance = server.realms.get(p.realm)
			if realm == null: return
			for enemy: Enemy in realm.enemies.values():
				if enemy is Boss:
					if enemy.state == Enemy.State.ACTIVE:
						enemy.take_hit(enemy.global_position, Vector3.ZERO, maxi(1, roundi(enemy.max_hp * (0.4 if p.realm.begins_with("dng_qa_") else 0.12))), realm.proxies.get(p.player_id))
				elif enemy.is_minion:
					enemy.take_hit(enemy.global_position, Vector3.ZERO, 100000, realm.proxies.get(p.player_id))
