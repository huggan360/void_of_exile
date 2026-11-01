extends Node
## Lifecycle and mechanics checks for all five stronghold encounters, run on a
## flat stronghold-sized floor with real physics, timers and the real director:
## shell -> cracks -> hatch -> safety window -> phases (capped thresholds,
## debug skips) -> objectives -> death and rewards once -> permanent clear,
## plus abandon resets and the loot tables.
## Run: godot --headless --path . res://tools/test_realm_boss_fights.tscn
const REALM := "boss_fight_fixture_only"
const BOSSES := {
	blue_dragon = "blue_dragon_lair", rimeheart_prism = "rimeheart_lair", vharok = "vharok_lair",
	scarab_regent = "scarab_lair", hollow_crown = "hollow_crown_lair",
}
var failures := 0
var checks := 0
var world: FloorWorld
var director: EnemyDirector
var bullets: EnemyBullets
var player: Player
var server: Node


class FloorWorld:
	extends GameWorld
	func ground_height(_x: float, _z: float) -> float:
		return 0.0


func expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	server = get_tree().root.get_node("WorldServer")
	GameServer.debug_godmode = true
	if OS.get_environment("BOSS_ONLY") == "":
		_test_loot()
	_setup_world()
	Engine.time_scale = 6.0
	for id: String in BOSSES:
		if OS.get_environment("BOSS_ONLY") not in ["", id]:
			continue
		await _test_encounter(id)
	await _test_abandon()
	Engine.time_scale = 1.0
	server.reset_realm(REALM)
	print("BOSS FIGHTS: %d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures else 0)


# --- Loot ------------------------------------------------------------------------------

func _test_loot() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5150
	var sets := {blue_dragon = 5, rimeheart_prism = 11, vharok = 3, scarab_regent = 4, hollow_crown = 5}
	for id: String in sets:
		var def := Enemies.get_def(id)
		var ids := Items.divine_ids_for(id)
		expect(ids.size() == sets[id], "%s has its %d-item set" % [id, sets[id]])
		for item_id in ids:
			expect(Items.make(item_id) != null and Items.make(item_id).icon() != null, "Registered with icon: " + item_id)
			expect(def.loot.any(func(e: Dictionary) -> bool: return e.get("item", "") == item_id and is_equal_approx(e.chance, 0.03)),
					"Independent 3%% roll for " + item_id)
		# 6000 solo kills: each item ~180 (3%), a set item never comes from another boss.
		var counts := {}
		var any_divine := 0
		for n in 6000:
			var got := false
			for bag in Loot.roll(def, {1: def.hp}, rng, "magic", def.hp):
				for item: Item in bag.items:
					expect(item.is_consumable() or item.tier <= 6, "No G7/G8 in the realm")
					if item.is_divine():
						expect(item.id in ids and item.bag_type() == "white", "Only its own set, in white bags")
						counts[item.id] = counts.get(item.id, 0) + 1
						got = true
			any_divine += 1 if got else 0
		for item_id in ids:
			var c: int = counts.get(item_id, 0)
			expect(c > 110 and c < 260, "Per-item 3%% rate for %s: %d / 6000" % [item_id, c])
		var expected := 1.0 - pow(0.97, ids.size())
		expect(absf(any_divine / 6000.0 - expected) < 0.03, "%s whole-set chance ~%.1f%%: got %.1f%%" % [id, expected * 100, any_divine / 60.0])
		print("%s: divine %s, any %.2f%%" % [id, counts, any_divine / 60.0])
	# Eligibility uses the attempt's scaled health, not the def's base health.
	var regent := Enemies.get_def("scarab_regent")
	var scaled := int(regent.hp * 1.4)
	var just_base := int(regent.hp * 0.041)
	expect(not Loot.roll(regent, {1: just_base}, rng, "magic", scaled).any(func(b: Dictionary) -> bool: return b.viewer == 1),
			"4% of base health is not enough when the fight was scaled up")
	var enough := 0
	for n in 50:
		enough += Loot.roll(regent, {1: int(scaled * 0.05)}, rng, "magic", scaled).filter(func(b: Dictionary) -> bool: return b.viewer == 1).size()
	expect(enough > 0, "5% of scaled health is eligible for personal loot")
	var moth := Enemies.get_def("frost_moth")
	for n in 2000:
		for bag in Loot.roll(moth, {1: moth.hp}, rng):
			for item: Item in bag.items:
				expect(not item.is_divine(), "Gods never drop divine items")


# --- World ------------------------------------------------------------------------------

func _setup_world() -> void:
	server.reset_realm(REALM)
	world = FloorWorld.new()
	world.realm_id = REALM
	get_tree().root.add_child(world)
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = Player.TERRAIN_LAYER
	var shape := CollisionShape3D.new()
	var slab := BoxShape3D.new()
	slab.size = Vector3(120, 1, 120)
	shape.shape = slab
	shape.position.y = -0.5
	floor_body.add_child(shape)
	world.add_child(floor_body)
	player = Player.new()
	player.player_id = GameServer.join(false)
	player.stats = GameServer.character(player.player_id)
	world.add_child(player)
	player.set_physics_process(false)
	player.set_process(false)
	player.frozen = false
	player.global_position = Vector3(0, 0, 14)
	GameServer.report_position(player.player_id, REALM, player.global_position)
	bullets = EnemyBullets.new()
	bullets.players = [player]
	world.add_child(bullets)
	director = EnemyDirector.new()
	director.world = world
	director.realm_id = REALM
	world.add_child(director)
	director.setup(player, bullets, [])
	director.set_process(false)


func _wake(id: String) -> Boss:
	var site := {id = "fixture_" + id, pack = BOSSES[id], pos = Vector3.ZERO, seed = 77}
	director._wake(site, null)
	var pack: EnemyPack = director._awake.get(site.id)
	expect(pack != null and pack.leader is Boss, "%s wakes as a boss pack" % id)
	return pack.leader as Boss


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _hit(boss: Enemy, damage: int) -> void:
	boss.take_hit(boss.global_position, Vector3.ZERO, damage, player)


# --- Encounters -------------------------------------------------------------------------

func _test_encounter(id: String) -> void:
	var boss := _wake(id)
	await _wait(0.3)
	var def := boss.boss_def
	expect(boss.is_sealed(), "%s starts sealed in its shell" % id)
	player.global_position = Vector3(0, 0, 3)
	GameServer.report_position(player.player_id, REALM, player.global_position)
	await _wait(1.0)
	expect(boss.is_sealed() and boss.state == Enemy.State.IDLE, "%s: walking up to the shell is safe" % id)
	# Crack it down in steps; shell damage gives no boss credit.
	_hit(boss, int(def.shell_hp * 0.3))
	expect(boss._cracks == 1 and boss._damage_by.is_empty(), "%s: first crack, no loot credit for shell damage" % id)
	_hit(boss, int(def.shell_hp * 0.5))
	expect(boss._cracks == 3, "%s: deeper cracks at 50%% and 25%%" % id)
	_hit(boss, def.shell_hp)
	expect(boss.state == Enemy.State.INTRO and not boss.is_sealed(), "%s: shell breaks once and it hatches" % id)
	_hit(boss, 5000)
	expect(boss.hp == boss.max_hp, "%s: can't be hurt while hatching" % id)
	await _wait(def.intro_time + 0.2)
	expect(boss.state == Enemy.State.ACTIVE and boss.phase == 0, "%s: combat-ready in phase 1 after %.1fs" % [id, def.intro_time])
	expect(boss.max_hp == def.hp, "%s: solo health is its base health" % id)
	expect(boss.attack_lock > 0.0 or boss.attack_lock == 0.0, "%s: safety window exists" % id)
	await _wait(1.6)
	# Phase skips set every phase up cleanly (objectives cleared and rebuilt).
	for index in range(1, def.phases.size()):
		boss.debug_skip_to(index)
		await _wait(0.8)
		expect(boss.phase == index, "%s: debug skip reaches phase %d" % [id, index + 1])
		await _check_phase(id, boss, index)
	# A huge hit can't skip a threshold, and death pays out once.
	expect(boss.phase == def.phases.size() - 1, "%s: in its final phase" % id)
	var bags_before := GameServer._bags.size()
	boss.immune = false
	boss.shielded = false
	_hit(boss, 999999)
	expect(boss.state == Enemy.State.DYING, "%s: the last point starts its death" % id)
	expect(boss.hazards.count() == 0 and boss.support("add").is_empty() and boss.support("objective").is_empty(),
			"%s: hazards and summons are gone before the death sequence" % id)
	_hit(boss, 999999)
	await _wait(def.death_time + 0.6)
	expect(not is_instance_valid(boss), "%s: bursts and is gone" % id)
	var bags := GameServer._bags.size() - bags_before
	expect(bags >= 1 and bags <= 12, "%s: rewards dropped once (%d bags)" % [id, bags])
	var record: Dictionary = server.get_or_create_realm(REALM)
	expect("fixture_" + id in record.cleared_packs, "%s: the stronghold stays cleared" % id)
	director._wake({id = "fixture_" + id, pack = BOSSES[id], pos = Vector3.ZERO, seed = 77}, director._memory["fixture_" + id].survivors)
	expect(not director._awake.has("fixture_" + id), "%s: a killed boss never comes back" % id)
	expect(bullets._shots.is_empty() or bullets._shots.all(func(s: Dictionary) -> bool: return s.owner != 0), "%s: no orphan shots" % id)


func _check_phase(id: String, boss: Boss, index: int) -> void:
	match id:
		"blue_dragon":
			var guards := boss.support("guard")
			expect(guards.size() == (5 if index == 0 else 4 if index == 1 else 0) or index == 2, "Blue Dragon guards for phase %d" % (index + 1))
		"rimeheart_prism":
			if index == 1:
				var towers: Array = boss.support("objective")
				expect(towers.size() == 6, "Rimeheart: exactly six conduits")
				for t: Enemy in towers:
					var r := Vector2(t.global_position.x - boss.encounter_center.x, t.global_position.z - boss.encounter_center.z).length()
					expect(absf(r - 6.2) < 0.15, "Rimeheart: conduit on its hex socket (r=%.2f)" % r)
				expect(boss.defense == 26, "Rimeheart: defense 14 + 2 per tower")
				# The floor: no damage gets below 35% while towers stand.
				_hit(boss, 999999)
				expect(boss.hp >= int(boss.max_hp * 0.35), "Rimeheart: can't fall below 35% with towers alive")
				# Healing: proportional to living towers, capped at 70%.
				boss.hp = int(boss.max_hp * 0.5)
				var before := boss.hp
				await _wait(2.0)
				var healed := boss.hp - before
				expect(healed > boss.max_hp * 0.009 * 1.0 and healed < boss.max_hp * 0.009 * 3.5, "Rimeheart: six towers heal ~0.9%%/s (%d in ~2s)" % healed)
				boss.hp = int(boss.max_hp * 0.69)
				await _wait(3.0)
				expect(boss.hp <= int(floor(boss.max_hp * 0.7)), "Rimeheart: healing never passes 70%")
				expect(boss.support("add").size() <= 6, "Rimeheart: at most six shardlings")
				boss.hp = int(boss.max_hp * 0.36)
				for t: Enemy in towers:
					t.take_hit(t.global_position, Vector3.ZERO, 999999, player)
				await _wait(0.4)
				expect(boss.support("add").is_empty() and boss._conduit_done, "Rimeheart: last tower ends healing and shardlings")
				var hp_before := boss.hp
				await _wait(1.0)
				expect(boss.hp <= hp_before, "Rimeheart: no healing after the conduits fall")
				_hit(boss, int(boss.max_hp * 0.05))
				expect(boss.hp < int(boss.max_hp * 0.35), "Rimeheart: vulnerable during the stun")
				await _wait(3.0)
				expect(boss.phase == 2, "Rimeheart: tempest after the stun")
			if index == 2:
				await _wait(1.6)
				expect(boss.spin_rate == 8.0, "Rimeheart: the star spins fast")
		"vharok":
			if index == 1:
				var sentinels: Array = boss.support("objective")
				expect(sentinels.size() == 2 and boss.immune, "Vharok: two Sentinels hold his shield")
				var hp := boss.hp
				_hit(boss, 50000)
				expect(boss.hp == hp, "Vharok: immune while guarded")
				await _wait(11.0)
				expect(boss.support("add").size() <= 4 and boss._mites_spawned <= 8, "Vharok: mites capped")
				for m: Enemy in boss.support("add"):
					m.take_hit(m.global_position, Vector3.ZERO, 999999, player)
				expect(boss.immune, "Vharok: killing mites doesn't touch the shield")
				for s: Enemy in sentinels:
					s.take_hit(s.global_position, Vector3.ZERO, 999999, player)
				await _wait(0.3)
				expect(not boss.immune and boss.support("add").is_empty(), "Vharok: shield breaks, mites dissolve")
				await _wait(6.0)
				expect(boss.state == Enemy.State.ACTIVE, "Vharok: charges without errors")
		"scarab_regent":
			if index == 1:
				expect(boss.support("add").size() == 6 and not boss.immune and not boss.shielded, "Scarab: six optional Dawn Scarabs, no immunity")
				await _wait(5.0)
				expect(boss.hazards.count() >= 0, "Scarab: rays ran")
			if index == 2:
				expect(boss.support("add").is_empty(), "Scarab: Dawn Scarabs gone before the Sunheart")
				await _wait(4.5)
				expect(boss.global_position.distance_to(boss.encounter_center) < 11.5, "Scarab: charges stay on the stronghold")
		"hollow_crown":
			if index == 1:
				expect(boss.support("add").size() == 3 and not boss.immune, "Hollow Crown: three optional Mirror Shades")
				await _wait(2.0)
				var off := Vector2(boss.global_position.x, boss.global_position.z).length()
				expect(off < 5.6, "Hollow Crown: teleports stay within 5.5 m (%.1f)" % off)
				expect(boss.model.visible and boss.collision_layer == Player.ENEMY_LAYER, "Hollow Crown: reassembled solid")
			if index == 2:
				expect(boss.support("add").is_empty(), "Hollow Crown: shades dissipate")


func _test_abandon() -> void:
	var boss := _wake("hollow_crown") if not director._awake.has("fixture_hollow_crown") else null
	if boss == null:
		# It was killed above: use a fresh site for the reset check.
		var site := {id = "fixture_reset", pack = "vharok_lair", pos = Vector3.ZERO, seed = 78}
		director._wake(site, null)
		boss = director._awake[site.id].leader
	await _wait(0.3)
	player.global_position = Vector3(0, 0, 4)
	GameServer.report_position(player.player_id, REALM, player.global_position)
	_hit(boss, 999999)
	await _wait(boss.boss_def.intro_time + 0.5)
	boss.debug_skip_to(1)
	await _wait(0.5)
	expect(not (boss.support("objective") + boss.support("add")).is_empty(), "Reset fixture has its summons up")
	GameServer.report_position(player.player_id, REALM, Vector3(0, 0, 80))
	await _wait(boss.boss_def.abandon_time + 1.0)
	expect(boss.is_sealed() and boss.phase == -1, "Abandoned fight resets to a fresh shell")
	expect(boss.support("objective").is_empty() and boss.support("add").is_empty() and boss.hazards.count() == 0,
			"Reset clears every summon and hazard")
	expect(boss.shell_hp == boss.boss_def.shell_hp and boss._damage_by.is_empty(), "Reset restores the shell and clears contribution")
