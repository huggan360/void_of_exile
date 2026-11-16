extends Node3D
## Headless: godot --headless --path . res://tools/check_pets.tscn
var checks := 0
var failures := 0

class RecordingSocial:
	extends SocialServer
	var messages: Array = []
	func send(pid: int, ev: Array) -> void: messages.append([pid, ev.duplicate(true)])

class MemoryApi:
	extends AccountApi
	signal finish_save
	var calls: Array = []
	var hold_save := false
	func call_api(method: String, path: String, body: Dictionary = {}) -> Dictionary:
		calls.append([method, path, body.duplicate(true)])
		if path.ends_with("/load"): return {ok = true, data = {pets = PetDefs.empty_state()}}
		if hold_save: await finish_save
		return {ok = true, data = {ok = true}}

class TargetEnemy:
	extends Enemy
	func _ready() -> void:
		model = CreatureModel.new("goblin")
		# take_hit only needs flinch; leave the rig unattached for this server check.
		set_physics_process(false)
		set_process(false)
	func _exit_tree() -> void: model.free()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func _ready() -> void: _run.call_deferred()

func _run() -> void:
	GameAudio._disabled = true
	GameServer.set_physics_process(false)
	_numbers()
	_random_and_merge()
	await _server_run()
	await _visual_smoke()
	print("[pets] %d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures else 0)

func _numbers() -> void:
	check(PetDefs.SPECIES.size() == 15 and PetDefs.ABILITIES.size() == 6, "Fixed species and ability counts")
	check(PetDefs.BITE_DOTS == 10 and PetDefs.BITE_XP == 10, "Bite price and XP")
	check(is_equal_approx(PetDefs.interval(1), 10) and is_equal_approx(PetDefs.interval(50), 5), "Interval endpoints")
	for row in [["regen", 2.0, 30.0], ["mana", 3.0, 36.0], ["attack", 15.0, 260.0], ["chain", 8.25, 143.0], ["ward", 2.0, 12.0], ["swift", 2.0, 10.0]]:
		for rarity: String in PetDefs.RARITY_MULTIPLIERS:
			var mult: float = PetDefs.RARITY_MULTIPLIERS[rarity]
			check(is_equal_approx(PetDefs.ability_value(row[0], 1, rarity), row[1] * mult), "%s %s level 1" % [row[0], rarity])
			check(is_equal_approx(PetDefs.ability_value(row[0], 50, rarity), row[2] * mult), "%s %s level 50" % [row[0], rarity])
	check(is_equal_approx(PetDefs.ability_value("attack", 25), 135), "Interior level power")
	check(is_equal_approx(PetDefs.interval(25), 10.0 - 5.0 * 24.0 / 49.0), "Interior level interval")
	check(PetDefs.xp_to_next(1) == 27 and PetDefs.xp_to_next(49) == 2475, "XP endpoints rounded")
	var previous := 0
	for level in range(1, 50):
		var xp := PetDefs.xp_to_next(level)
		check(xp == roundi(20 + 6 * level + 0.9 * level * level) and xp > previous, "XP curve level %d" % level)
		previous = xp
	var pet := {level = 1, xp = 0}
	check(PetDefs.bites_to_next(pet) == 3, "Three bites to first level")
	PetDefs.feed(pet, 3)
	check(int(pet.level) == 2 and int(pet.xp) == 3, "Feeding preserves excess XP")
	PetDefs.feed(pet, PetDefs.bites_to_cap(pet))
	check(int(pet.level) == 50 and int(pet.xp) == 0 and PetDefs.bites_to_cap(pet) == 0, "Feeding caps at 50")

func _random_and_merge() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 99881
	var seen := {}
	var doubles := false
	for i in 6000:
		var pet := PetDefs.random_pet(rng)
		if not (PetDefs.SPECIES.has(pet.species) and pet.rarity == "common" and int(pet.level) == 1 and int(pet.xp) == 0 and pet.abilities.size() == 2):
			check(false, "Random hatch is valid")
			return
		for ability: String in pet.abilities:
			if not PetDefs.ABILITIES.has(ability):
				check(false, "Random ability is valid")
				return
		seen[pet.species] = int(seen.get(pet.species, 0)) + 1
		doubles = doubles or pet.abilities[0] == pet.abilities[1]
	check(seen.size() == 15 and doubles, "Every species and doubled abilities can hatch")
	for count: int in seen.values(): check(count > 300 and count < 500, "Equal species selection")
	var a := PetDefs.random_pet(rng)
	a.merge({id = 1, species = "duck", level = 40, xp = 100, abilities = ["regen", "attack"]}, true)
	var b := a.duplicate(true)
	b.merge({id = 2, level = 31, abilities = ["mana", "ward"]}, true)
	var result := PetDefs.merge(a, b)
	check(result.rarity == "rare" and int(result.level) == 31 and int(result.xp) == 0 and result.abilities == ["regen", "mana"], "Merge inherits first abilities, lesser level, no XP")
	check(PetDefs.merge(a, a).is_empty(), "Cannot merge a pet with itself")
	b.species = "wisp"
	check(PetDefs.merge(a, b).is_empty(), "Cannot merge different species")
	b.species = "duck"
	b.rarity = "rare"
	check(PetDefs.merge(a, b).is_empty(), "Cannot merge different rarities")
	a.rarity = "rare"
	check(PetDefs.merge(a, b).rarity == "divine", "Two rare pets make divine")
	a.rarity = "divine"
	b.rarity = "divine"
	check(PetDefs.merge(a, b).is_empty(), "Divine cannot merge")

func _server_run() -> void:
	var server := NetServer.new()
	server.config = ServerConfig.new()
	server.config.test_mode = true
	server.set_process(false)
	server.set_physics_process(false)
	server.social.free()
	var social := RecordingSocial.new()
	server.social = social
	server.social.server = server
	server.economy.server = server
	server.pets.server = server
	add_child(server)
	# Parent all its owned nodes so this check leaves no orphan nodes.
	for owned: Node in [server.api, server.social, server.economy, server.pets, server.dungeons, server.campaigns, server.surface_port, server.fleet]:
		owned.set_process(false)
		owned.set_physics_process(false)
		server.add_child(owned)
	var pid := GameServer.add_player(PlayerStats.new())
	var stats := GameServer.character(pid)
	var p := server._new_record(77, 101, "pet_test")
	p.merge({account_id = 99, player_id = pid, joined = true, dots = 100000, realm = "pty_99", pos = PetYardWorld.NEST_POS}, true)
	server.peers[77] = p
	await server.pets.load_account(p)
	check(p.pets.pets.is_empty() and not server.pets.accounts[99].persistent, "Test server loads in memory")
	check(social.messages[-1][1][0] == "pets", "Load sends owner state")
	stats.give([Items.make("pet_egg"), Items.make("pet_egg")])
	var eggs := stats.item_at(stats.find_item("pet_egg"))
	check(eggs.count == 2, "Eggs stack")
	p.realm = "pty_98"
	check(not server.pets.hatch(p), "Cannot hatch in someone else's yard")
	p.realm = "pty_99"
	p.pos = Vector3.ZERO
	check(not server.pets.hatch(p), "Cannot hatch away from nest")
	p.pos = PetYardWorld.NEST_POS
	check(server.pets.hatch(p) and p.pets.pets.size() == 1 and eggs.count == 1, "Hatching consumes exactly one egg")
	check(server.pets.hatch(p) and stats.find_item("pet_egg").is_empty(), "Last egg leaves inventory")
	check(not server.pets.hatch(p) and p.pets.pets.size() == 2, "No egg cannot hatch")
	var first: Dictionary = p.pets.pets[0]
	var second: Dictionary = p.pets.pets[1]
	first.species = "duck"
	first.abilities = ["regen", "attack"]
	second.species = "duck"
	second.abilities = ["mana", "ward"]
	var first_id := int(first.id)
	var second_id := int(second.id)
	check(not server.pets.feed(p, first_id, 1), "Feeding requires Caretaker proximity")
	p.pos = PetYardWorld.CARETAKER_POS
	check(not server.pets.feed(p, first_id, -1), "Negative feeding refused")
	check(not server.pets.feed(p, 99999, 10), "Foreign pet refused")
	var balance := int(p.dots)
	p.dots = 0
	check(not server.pets.feed(p, first_id, 1) and int(first.xp) == 0, "Unfunded feeding refused")
	p.dots = balance
	server.pets.on_action(p, "pet_feed", [first_id, "10"])
	check(int(p.dots) == balance, "Malformed feeding refused")
	check(server.pets.feed(p, first_id, 3) and int(p.dots) == balance - 30 and int(first.level) == 2 and int(first.xp) == 3, "Feeding spends Dots and advances XP")
	check(server.pets.equip(p, first_id) and server.pets.looks(p) == {species = "duck", rarity = "common"}, "Equip is in player looks")
	check(not server.pets.equip(p, 123456), "Cannot equip another account pet")
	check(server.pets.merge(p, first_id, second_id), "Server merge succeeds")
	var merged: Dictionary = p.pets.pets[0]
	check(p.pets.pets.size() == 1 and int(merged.id) != first_id and int(merged.id) != second_id and int(p.pets.equipped) == int(merged.id), "Merge consumes both ids and equips result")
	check(merged.rarity == "rare" and merged.abilities == ["regen", "mana"] and int(merged.level) == 1, "Server merge follows shared contract")
	check(not server.pets.merge(p, int(merged.id), int(merged.id)), "Server self merge refused")
	balance = int(p.dots)
	var cap_bites := PetDefs.bites_to_cap(merged)
	check(server.pets.feed(p, int(merged.id), cap_bites + 100) and int(merged.level) == 50 and int(p.dots) == balance - cap_bites * 10, "Only needed bites charged at level cap")
	check(not server.pets.feed(p, int(merged.id), 1), "Max level feeding refused")
	var alt := p.duplicate()
	alt.character_id = 102
	await server.pets.load_account(alt)
	check(alt.pets == p.pets, "Characters share account pets")
	await server.pets.save_account(p)
	check(not server.pets.accounts[99].dirty and p.pets.pets.size() == 1, "Leave flush keeps in-memory pets")
	server.pets.accounts[99].dirty = true
	server.pets.accounts[99].timer = 0.01
	server.pets._process(0.02)
	check(not server.pets.accounts[99].dirty, "Debounced save flushes")
	await _combat(server, p, merged)
	check(server.pets.equip(p, 0) and server.pets.looks(p).is_empty(), "Unequip removes looks")
	# Egg rolls are independent of ordinary loot and reward the actual top hitter.
	var rng := RandomNumberGenerator.new()
	rng.seed = 7561
	var def := EnemyDef.new()
	def.hp = 100
	def.loot = []
	var egg_drops := 0
	for i in 10000:
		for drop: Dictionary in Loot.roll(def, {pid: 60, 999: 40}, rng):
			for item: Item in drop.items:
				if item.id == "pet_egg":
					egg_drops += 1
					check(int(drop.viewer) == pid, "Egg is personal to top damage dealer")
	check(egg_drops > 0 and egg_drops < 40, "Rare egg drops even without an ordinary loot table")
	await _persistence(server)
	GameServer.remove_player(pid)
	server.free()

func _persistence(server: NetServer) -> void:
	server.api.free()
	var api := MemoryApi.new()
	api.base_url = "memory://pets"
	server.api = api
	server.add_child(api)
	server.config.test_mode = false
	var p := server._new_record(78, 202, "saved_pets")
	p.account_id = 199
	server.peers[78] = p
	await server.pets.load_account(p)
	check(api.calls[0] == ["POST", "/server/pets/load", {character_id = 202}], "Account load endpoint and character payload")
	var pet := PetDefs.random_pet(RandomNumberGenerator.new())
	pet.id = 1
	p.pets.pets.append(pet)
	p.pets.next_id = 2
	server.pets.equip(p, 1)
	api.hold_save = true
	server.pets._process(1.9)
	check(api.calls.size() == 1, "Save waits for two second debounce")
	server.pets._process(0.11)
	check(api.calls.size() == 2 and api.calls[-1][1] == "/server/pets/save" and api.calls[-1][2].character_id == 202, "Debounce sends account save payload")
	check(int(api.calls[-1][2].pets.equipped) == 1, "Save carries whole pet state")
	server.pets.equip(p, 0)
	api.finish_save.emit()
	check(server.pets.accounts[199].dirty, "Changes during an HTTP save remain dirty")
	api.hold_save = false
	await server.pets.save_account(p)
	check(not server.pets.accounts[199].dirty and int(api.calls[-1][2].pets.equipped) == 0, "Leave flush sends newest revision after an in-flight save")
	server.peers.erase(78)
	await server.pets.leave(p)
	check(not server.pets.accounts.has(199), "Last persistent account visit is released for later reload")
	server.config.test_mode = true

func _combat(server: NetServer, p: Dictionary, pet: Dictionary) -> void:
	var stats := GameServer.character(int(p.player_id))
	stats.hp = 10
	stats.mp = 0
	pet.abilities = ["regen", "regen"]
	pet.level = 29
	pet.rarity = "common"
	p.pet_clock = 0.0
	p.realm = "hall"
	server.pets._process(20)
	check(stats.hp == 10, "No pulses in Tavern")
	p.realm = ChambersWorld.id_for(99)
	server.pets._process(20)
	check(stats.hp == 10, "No pulses in Chambers")
	p.realm = "pty_99"
	server.pets._process(20)
	check(stats.hp == 10, "No pulses in Pet Yard")
	p.realm = "pet_combat"
	server.pets._process(PetDefs.interval(29))
	check(is_equal_approx(stats.hp, 10 + PetDefs.ability_value("regen", 29)), "Second ability locked before 30")
	pet.level = 30
	stats.hp = 1
	server.pets._process(PetDefs.interval(30))
	check(is_equal_approx(stats.hp, 1 + 2 * PetDefs.ability_value("regen", 30)), "Double ability fires twice from level 30")
	var pending: int = server._pending.get(p.realm, []).size()
	stats.hp = stats.max_hp
	server.pets._process(PetDefs.interval(30))
	check(server._pending.get(p.realm, []).size() == pending, "Full owner skips heal pulses")
	server.pets.pulse(p, pet, "mana")
	check(is_equal_approx(stats.mp, PetDefs.ability_value("mana", 30)), "Mana pulse restores stats")
	server.pets.pulse(p, pet, "ward")
	server.pets.pulse(p, pet, "swift")
	check(stats.buffs.has_effect("defense") and stats.buffs.has_effect("speed"), "Ward and swift use buff system")
	check(is_equal_approx(float(stats.buffs.entries.defense.duration), 6.0), "Pet buffs last six seconds")
	stats.hp = 10
	p.dead = true
	server.pets._process(20)
	check(stats.hp == 10, "Dead owner never pulses")
	p.dead = false
	var realm := RealmInstance.new({id = "pet_combat"})
	server.realms[p.realm] = realm
	var proxy := NetPlayerProxy.new()
	proxy.player_id = int(p.player_id)
	add_child(proxy)
	realm.proxies[int(p.player_id)] = proxy
	var director := EnemyDirector.new()
	director.set_physics_process(false)
	director.set_process(false)
	add_child(director)
	for i in 5:
		var enemy := TargetEnemy.new()
		enemy.def = EnemyDef.new()
		enemy.def.sheds = false
		enemy.director = director
		enemy.pack = EnemyPack.new()
		enemy.hp = 10000
		enemy.max_hp = 10000
		enemy.defense = 5
		enemy.state = Enemy.State.IDLE if i != 4 else Enemy.State.SPAWNING
		enemy.net_id = i + 1
		add_child(enemy)
		enemy.global_position = p.pos + Vector3(2 + i * 2, 0, 0) if i != 3 else p.pos + Vector3(20, 0, 0)
		realm.enemies[enemy.net_id] = enemy
	var before: int = realm.enemies[1].hp
	server.pets.pulse(p, pet, "attack")
	check(int(realm.enemies[1].hp) == before - (roundi(PetDefs.ability_value("attack", 30)) - 5), "Attack uses normal enemy defence")
	check(realm.enemies[1]._damage_by.has(int(p.player_id)), "Pet damage credits owner for loot")
	server.pets.pulse(p, pet, "chain")
	check(realm.enemies[2].hp < 10000 and realm.enemies[3].hp < 10000 and realm.enemies[4].hp == 10000 and realm.enemies[5].hp == 10000, "Chain hits three awake enemies in 12 m")
	var events: Array = server._pending[p.realm]
	check(events[-1].ev.size() == 7 and events[-1].ev[6] is Vector3, "Chain carries prior enemy position for hopping beams")
	for enemy: Enemy in realm.enemies.values(): enemy.free()
	realm.bullets.free()
	realm._bag_spots.free()
	realm.free()
	server.realms.clear()
	proxy.free()
	director.free()

func _visual_smoke() -> void:
	var world := GameWorld.new()
	add_child(world)
	var actor := Node3D.new()
	world.add_child(actor)
	var follower := PetFollower.new({species = "missing_art", rarity = "divine"}, actor, world)
	world.add_child(follower)
	actor.position = Vector3(40, 0, 0)
	follower._process(0.016)
	check(follower.global_position.distance_to(actor.global_position) < 3, "Follower teleports to catch up")
	check(follower.model != null and follower.get_children().all(func(n: Node) -> bool: return not n is CollisionObject3D), "Missing art has a noncolliding placeholder")
	var beam := PetBeam.spawn(world, Vector3.ZERO, Vector3(1, 0, 0), "chain")
	beam._process(PetBeam.LIFE + 0.01)
	check(beam.is_queued_for_deletion(), "Beam expires after its life")
	# Build the full panel headlessly as well, including its isolated 3D preview.
	var rng := RandomNumberGenerator.new()
	var pet := PetDefs.random_pet(rng)
	pet.id = 1
	PetsClient.receive({next_id = 2, equipped = 1, pets = [pet]})
	var panel := PetPanel.new()
	add_child(panel)
	check(panel._preview_pet != null and panel._abilities[1]._value.text == "Level 30", "Caretaker builds preview and locked ability")
	panel.free()
	PetsClient.receive(PetDefs.empty_state())
	for species: String in PetDefs.SPECIES:
		var visual := PetFollower.new({species = species, rarity = "common"})
		world.add_child(visual)
		visual.animate_gait(1.0, 0.1)
		check(visual._pose.transform.is_finite(), "%s gait is finite" % species)
		visual.free()
	var client := NetClient.new()
	client.set_process(false)
	add_child(client)
	client.world = world
	client.info = {player_id = 1}
	client.social_event.emit(["pets", {next_id = 2, equipped = 1, pets = [pet]}])
	check(int(PetsClient.state.equipped) == 1, "Client receives account state through reliable event path")
	client._apply([0.0, "p+", 2, "Remote", "archer|G1_bow,,,|{}", {pet = {species = "duck", rarity = "rare"}}])
	check(client._pet_followers.has(2) and client._remote.has(2), "Remote looks create a companion")
	client._apply([0.0, "pet_pulse", 2, "chain", Vector3(4, 1, 0), 77, Vector3(2, 1, 0)])
	check(world.get_children().any(func(n: Node) -> bool: return n is PetBeam and n.global_position == Vector3(2, 1, 0)), "Client draws a chain hop from its previous target")
	client._apply([0.0, "p-", 2])
	check(not client._pet_followers.has(2), "Remote departure removes companion")
	client.clear_world()
	client.free()
	PetsClient.receive(PetDefs.empty_state())
	world.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
