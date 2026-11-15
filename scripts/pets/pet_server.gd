class_name PetServer
extends Node
## NetServer owns this node. State and save queues are per account.
const SAVE_DELAY := 2.0
const RANGE := 12.0
var server: NetServer
var accounts := {}
var _loading := {}
var _rng := RandomNumberGenerator.new()

func _init() -> void: _rng.randomize()

func _memory_only() -> bool:
	return server.config == null or server.config.test_mode or server.api.base_url == ""

func load_account(p: Dictionary) -> void:
	var key := int(p.account_id)
	while _loading.has(key): await get_tree().process_frame
	var cached: Dictionary = accounts.get(key, {})
	if not cached.is_empty() and cached.persistent and not cached.dirty:
		var held := false
		for other: Dictionary in server.peers.values():
			if other.has("pets") and int(other.get("account_id", -1)) == key: held = true
		if not held: accounts.erase(key)
	if not accounts.has(key):
		_loading[key] = true
		var state := PetDefs.empty_state()
		var persistent := not _memory_only()
		if persistent:
			var r: Dictionary = await server.api.call_api("POST", "/server/pets/load", {character_id = p.character_id})
			if r.ok and r.data.get("pets") is Dictionary:
				state = _clean_state(r.data.pets)
			else:
				persistent = false
				push_warning("Pets kept in memory: %s" % str(r.get("error", "invalid account response")))
		accounts[key] = {state = state, persistent = persistent, dirty = false, revision = 0,
			timer = -1.0, saving = false, character_id = p.character_id}
		_loading.erase(key)
	accounts[key].character_id = int(p.character_id)
	p.pets = accounts[key].state
	p.pet_clock = 0.0
	if server.peers.has(p.peer_id): send_state(p)

func _clean_state(data: Dictionary) -> Dictionary:
	var state := PetDefs.empty_state()
	var used := {}
	if not data.get("pets", []) is Array: return state
	for raw: Variant in data.get("pets", []):
		if not raw is Dictionary or state.pets.size() >= PetDefs.MAX_PETS: continue
		var pet: Dictionary = raw.duplicate(true)
		var id := int(pet.get("id", 0))
		if id <= 0 or used.has(id) or not PetDefs.SPECIES.has(pet.get("species")): continue
		if not PetDefs.RARITY_MULTIPLIERS.has(pet.get("rarity")): continue
		var abilities: Variant = pet.get("abilities", [])
		if not abilities is Array or abilities.size() != 2: continue
		if not PetDefs.ABILITIES.has(abilities[0]) or not PetDefs.ABILITIES.has(abilities[1]): continue
		pet.id = id
		pet.level = clampi(int(pet.get("level", 1)), 1, 50)
		pet.xp = clampi(int(pet.get("xp", 0)), 0, PetDefs.xp_to_next(pet.level) - 1) if pet.level < 50 else 0
		pet.name = str(pet.get("name", PetDefs.SPECIES[pet.species].name)).left(48)
		pet.born = int(pet.get("born", 0))
		used[id] = true
		state.pets.append(pet)
		state.next_id = maxi(int(state.next_id), id + 1)
	state.next_id = maxi(int(state.next_id), int(data.get("next_id", 1)))
	state.equipped = int(data.get("equipped", 0)) if used.has(int(data.get("equipped", 0))) else 0
	return state

## Connected characters share the cached account; later visits reload saved data.
func leave(p: Dictionary) -> void:
	await save_account(p)
	var key := int(p.account_id)
	var entry: Dictionary = accounts.get(key, {})
	if entry.is_empty() or not entry.persistent or entry.dirty: return
	for other: Dictionary in server.peers.values():
		if int(other.get("account_id", -1)) == key: return
	accounts.erase(key)

func send_state(p: Dictionary) -> void:
	server.social.send(int(p.player_id), ["pets", p.get("pets", PetDefs.empty_state()).duplicate(true)])

func looks(p: Dictionary) -> Dictionary:
	var state: Dictionary = p.get("pets", {})
	var pet := PetDefs.find(state, int(state.get("equipped", 0)))
	return {species = pet.species, rarity = pet.rarity} if not pet.is_empty() else {}

func _changed(p: Dictionary) -> void:
	var entry: Dictionary = accounts[int(p.account_id)]
	entry.dirty = true
	entry.revision = int(entry.revision) + 1
	entry.timer = SAVE_DELAY
	entry.character_id = int(p.character_id)
	for other: Dictionary in server.peers.values():
		if int(other.get("account_id", -1)) == int(p.account_id) and other.has("pets"):
			other.pet_clock = 0.0
			send_state(other)

## Serial saves prevent an old HTTP response overwriting a newer snapshot.
func save_account(p: Dictionary) -> void:
	var entry: Dictionary = accounts.get(int(p.get("account_id", 0)), {})
	if entry.is_empty(): return
	while entry.saving: await get_tree().process_frame
	if not entry.dirty: return
	if not entry.persistent:
		entry.dirty = false
		entry.timer = -1.0
		return
	entry.saving = true
	var revision := int(entry.revision)
	var r: Dictionary = await server.api.call_api("POST", "/server/pets/save", {
		character_id = p.character_id, pets = entry.state.duplicate(true)})
	entry.saving = false
	if r.ok and revision == int(entry.revision):
		entry.dirty = false
		entry.timer = -1.0
	else:
		entry.timer = SAVE_DELAY
		if not r.ok: push_warning("Couldn't save pets: %s" % str(r.error))

func _process(delta: float) -> void:
	for key: int in accounts:
		var entry: Dictionary = accounts[key]
		if entry.dirty and not entry.saving and float(entry.timer) >= 0.0:
			entry.timer -= delta
			if entry.timer <= 0.0: save_account({account_id = key, character_id = entry.character_id})
	for p: Dictionary in server.peers.values():
		if not p.get("joined", false) or p.get("dead", false) or p.get("switching", false): continue
		var realm_id := str(p.get("realm", ""))
		if realm_id == "" or Campaigns.is_tavern(realm_id) or ChambersWorld.is_chambers(realm_id) or realm_id.begins_with("pty_"): continue
		var state: Dictionary = p.get("pets", {})
		var pet := PetDefs.find(state, int(state.get("equipped", 0)))
		var stats := GameServer.character(int(p.player_id))
		if pet.is_empty() or stats == null or stats.hp <= 0: continue
		p.pet_clock = float(p.get("pet_clock", 0.0)) + delta
		if float(p.pet_clock) < PetDefs.interval(int(pet.level)): continue
		p.pet_clock = 0.0
		pulse(p, pet, str(pet.abilities[0]))
		if int(pet.level) >= 30: pulse(p, pet, str(pet.abilities[1]))

func _owner_yard(p: Dictionary) -> bool:
	return int(p.get("account_id", 0)) > 0 and str(p.get("realm", "")) == "pty_%d" % int(p.account_id)

func _by_yard_prop(p: Dictionary, point: Vector3) -> bool:
	return _owner_yard(p) and p.get("pos") is Vector3 and (p.pos as Vector3).is_finite() and (p.pos as Vector3).distance_to(point) <= 4.0

func on_action(p: Dictionary, kind: String, args: Array) -> void:
	if p.get("dead", false) or p.get("switching", false) or not p.has("pets"): return
	match kind:
		"pet_hatch":
			if args.is_empty(): hatch(p)
		"pet_feed":
			if args.size() == 2 and _integer(args[0]) and _integer(args[1]): feed(p, int(args[0]), int(args[1]))
		"pet_merge":
			if args.size() == 2 and _integer(args[0]) and _integer(args[1]): merge(p, int(args[0]), int(args[1]))
		"pet_equip":
			if args.size() == 1 and _integer(args[0]): equip(p, int(args[0]))

func _integer(value: Variant) -> bool:
	return value is int or (value is float and is_finite(value) and value == floor(value) and absf(value) < 2147483647.0)

func hatch(p: Dictionary) -> bool:
	if not _by_yard_prop(p, PetYardWorld.NEST_POS) or p.pets.pets.size() >= PetDefs.MAX_PETS: return false
	var stats := GameServer.character(int(p.player_id))
	if stats == null: return false
	var place := stats.find_item("pet_egg")
	if place.is_empty(): return false
	var egg := stats.item_at(place)
	if egg.count > 1:
		egg.count -= 1
		stats.changed.emit()
	else: stats.take(place)
	var pet := PetDefs.random_pet(_rng)
	pet.id = int(p.pets.next_id)
	p.pets.next_id = int(p.pets.next_id) + 1
	p.pets.pets.append(pet)
	_changed(p)
	server.save_record(p)
	return true

func feed(p: Dictionary, id: int, bites: int) -> bool:
	if not _by_yard_prop(p, PetYardWorld.CARETAKER_POS) or bites <= 0: return false
	var pet := PetDefs.find(p.pets, id)
	if pet.is_empty(): return false
	bites = mini(bites, PetDefs.bites_to_cap(pet))
	if bites <= 0 or not server.economy.spend(p, bites * PetDefs.BITE_DOTS, "pet_feed"): return false
	PetDefs.feed(pet, bites)
	_changed(p)
	return true

func merge(p: Dictionary, a: int, b: int) -> bool:
	if not _by_yard_prop(p, PetYardWorld.CARETAKER_POS): return false
	var first := PetDefs.find(p.pets, a)
	var second := PetDefs.find(p.pets, b)
	var result := PetDefs.merge(first, second)
	if result.is_empty(): return false
	result.id = int(p.pets.next_id)
	p.pets.next_id = int(p.pets.next_id) + 1
	p.pets.pets.erase(first)
	p.pets.pets.erase(second)
	p.pets.pets.append(result)
	if int(p.pets.equipped) in [a, b]: p.pets.equipped = result.id
	_changed(p)
	return true

func equip(p: Dictionary, id: int) -> bool:
	if id < 0 or (id != 0 and PetDefs.find(p.pets, id).is_empty()): return false
	if int(p.pets.equipped) == id: return true
	p.pets.equipped = id
	_changed(p)
	return true

func pulse(p: Dictionary, pet: Dictionary, ability: String) -> void:
	var stats := GameServer.character(int(p.player_id))
	if stats == null or stats.hp <= 0: return
	var value := PetDefs.ability_value(ability, int(pet.level), str(pet.rarity))
	match ability:
		"regen":
			if stats.hp >= stats.max_hp: return
			stats.hp = minf(stats.max_hp, stats.hp + value)
		"mana":
			if stats.mp >= stats.max_mp: return
			stats.mp = minf(stats.max_mp, stats.mp + value)
		"ward", "swift":
			stats.buffs.add("defense" if ability == "ward" else "speed", 6.0, value, "pet")
		"attack", "chain":
			var realm: RealmInstance = server.realms.get(p.realm)
			if realm == null: return
			var proxy: Node = realm.proxies.get(int(p.player_id))
			if proxy == null: return
			var candidates: Array[Enemy] = []
			for enemy: Enemy in realm.enemies.values():
				if is_instance_valid(enemy) and enemy.state in [Enemy.State.IDLE, Enemy.State.ACTIVE, Enemy.State.RETURNING] and enemy.global_position.distance_to(p.pos) <= RANGE:
					candidates.append(enemy)
			var origin: Vector3 = p.pos
			for hop in (3 if ability == "chain" else 1):
				candidates = candidates.filter(func(e: Enemy) -> bool: return is_instance_valid(e) and e.hp > 0)
				if candidates.is_empty(): break
				candidates.sort_custom(func(a: Enemy, b: Enemy) -> bool: return a.global_position.distance_squared_to(origin) < b.global_position.distance_squared_to(origin))
				var enemy: Enemy = candidates.pop_front()
				var target := enemy.global_position + Vector3.UP * enemy.height() * 0.5
				# Optional origin on subsequent hops keeps the standard pulse fields intact.
				var event := ["pet_pulse", int(p.player_id), ability, target, enemy.net_id]
				if hop > 0: event.append(origin)
				server._to_realm(str(p.realm), p.pos, event)
				var before := enemy.hp
				enemy.take_hit(enemy.global_position, (enemy.global_position - origin).normalized(), roundi(value), proxy)
				if enemy.hp < before: GameServer.report_hit_landed(int(p.player_id))
				origin = target
			return
	server._to_realm(str(p.realm), p.pos, ["pet_pulse", int(p.player_id), ability, Vector3.INF, 0])
