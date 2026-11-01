extends Node
## Focused end-to-end checks for finite gods, realm drops, equipment and authored shots.
var failures := 0
var checks := 0
const FIXTURE_REALM := "integration_fixture_only"
class FlatWorld:
	extends GameWorld
	func ground_height(_x: float, _z: float) -> float:
		return 0.0
	func biome_at(_pos: Vector3) -> BiomeDef:
		return Biomes.get_biome(Biomes.FOSEN)

class HitProbe:
	extends StaticBody3D
	var hits: Array[int] = []
	func _ready() -> void:
		collision_layer = Player.ENEMY_LAYER
		var collider := CollisionShape3D.new()
		var shape := SphereShape3D.new()
		shape.radius = 0.4
		collider.shape = shape
		collider.position.y = 0.9
		add_child(collider)
	func take_hit(_pos: Vector3, _dir: Vector3, damage: int) -> void:
		hits.append(damage)

func _ready() -> void:
	_run.call_deferred()

func expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func _run() -> void:
	_test_items()
	_test_spells()
	_test_loot()
	_test_spawns()
	await _test_persistence_and_models()
	print("INTEGRATION: %d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures else 0)

func _test_items() -> void:
	var all := Items.all()
	var seen := {}
	var regular := 0
	var divine := 0
	var bonuses := 0
	for item in all:
		expect(not seen.has(item.id), "Duplicate catalog id: " + item.id)
		seen[item.id] = true
		expect(item.icon() != null, "Missing icon: " + item.id)
		if not item.is_consumable() and not item.is_key():
			if item.is_divine():
				divine += 1
			else:
				regular += 1
			if item.slot == "bonus" and not item.is_divine():
				bonuses += 1
	expect(regular == 85 and bonuses == 40, "Every regular source item is registered")
	expect(divine == 31, "The six boss sets (31 divine items) are enabled, nothing else")
	for id in Items.GATE_KEYS: expect(seen.has(id), "Fortress key is registered: " + id)
	var stats := PlayerStats.new()
	for kind in ["wand", "trident", "robe"]:
		var item := Items.make("G4_" + kind)
		expect(item != null, "Collectible exists: " + kind)
		expect(not stats.fits(item, {kind = "gear", key = item.slot}), "Archer cannot equip " + kind)
		expect(stats.fits(item, {kind = "pack", key = 0}), "Archer may carry " + kind)
		stats.backpack[0] = item
		expect(not stats.activate({kind = "pack", key = 0}), "Double-click cannot bypass class restriction")
	for id in ["G4_bow", "G4_cloak", "G4_spell", "G4_bonus_eye", "D_bonus_crucifix_oftheblue"]:
		var item := Items.make(id)
		expect(stats.fits(item, {kind = "gear", key = item.slot}), "Archer may equip " + id)
	var one := Items.make("G4_bonus_eye")
	one.bonuses.dexterity = 999
	expect(Items.make("G4_bonus_eye").bonuses.dexterity == 8, "Catalog copies do not share mutable stats")
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	var pool_seen := {}
	for i in 2000:
		pool_seen[Items.from_pool({tier = 4}, rng).id] = true
	for id in ["G4_wand", "G4_trident", "G4_robe", "G4_bonus_flame", "G4_bonus_crystal"]:
		expect(pool_seen.has(id), "New gear can actually roll: " + id)
	for lv in range(1, 50):
		stats.add_xp(stats.xp_to_next())
	stats.gear.armor = Items.cloak(4)
	stats.gear.bonus = Items.bonus(4, "crucifix")
	for id in ["frost_moth", "ruin_watcher", "spirit_brown", "spirit_blue", "spirit_purple", "blue_genie"]:
		var god := Enemies.get_def(id)
		expect(god.is_god, "God flag: " + id)
		var damage: float = stats.mitigate(god.attacks[0].damage_min)
		expect(damage >= 40, "God still deals >=40 through a level-50 G4 archer's defense: " + id)
		print("DAMAGE ", id, ": ", damage, " through ", stats.total("defense"), " defense")

func _test_spells() -> void:
	var stats := PlayerStats.new()
	var before := 0
	for spell in [Items.spell(4), Items.spell(5), Items.make("D_spell_oftheblue")]:
		var ring := MagicRing.new()
		ring.spell = spell
		get_tree().root.add_child(ring)
		ring.set_physics_process(false)
		ring.damage_multiplier = stats.spell_multiplier(spell)
		var edge := ring.damage_at_distance(spell.ring.range)
		var close := ring.damage_at_distance(0.0)
		expect(edge >= 140 and close >= 280, "Spell ring no longer falls to trivial damage: " + spell.id)
		expect(absi(close - edge * 2) <= 1, "Spell keeps half damage at full range")
		var initial := close
		stats.base.magic += 10
		ring.damage_multiplier = stats.spell_multiplier(spell)
		expect(ring.damage_at_distance(0.0) > initial, "Magic increases actual ring hit damage")
		stats.base.magic -= 10
		if spell.id == "G5_spell":
			expect(close > before, "G5 ring improves on G4")
		before = close
		print("SPELL ", spell.id, " level-1: ", edge, "-", close, " per pulse / ", spell.ring.get("pulses", 1), " pulses")
		ring.free()
	var source := Items.spell(4)
	stats.gear.spell = Items.spell(1)
	var predicted := stats.spell_multiplier(source)
	stats.gear.spell = source
	expect(is_equal_approx(predicted, stats.spell_multiplier(source)), "Tooltip spell comparison matches equipped damage")

func _test_loot() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 319776
	var boss := Enemies.get_def("blue_dragon")
	var rates := {}
	for entry in boss.loot:
		if entry.has("item") and entry.item in Items.BLUE_DIVINE_IDS:
			expect(is_equal_approx(entry.chance, 0.03), "Independent 3% Blue relic roll")
	for n in 10000:
		for bag in Loot.roll(boss, {1: boss.hp}, rng, "mp"):
			for item: Item in bag.items:
				expect(item.is_consumable() or item.is_divine() or item.tier <= 6, "Realm boss never drops G7/G8")
				if item.is_divine():
					expect(item.bag_type() == "white", "Blue divine items use white bags")
					rates[item.id] = rates.get(item.id, 0) + 1
	for id in Items.BLUE_DIVINE_IDS:
		var count: int = rates.get(id, 0)
		expect(count > 200 and count < 400, "Seeded 10k boss kills exercise each independent 3% roll: " + id)
	print("BLUE DIVINE / 10000 kills: ", rates)
	var moth := Enemies.get_def("frost_moth")
	var rare := 0
	var potions := 0
	for n in 20000:
		for bag in Loot.roll(moth, {1: moth.hp}, rng, "magic"):
			var bag_color := LootBag.type_for(bag.items)
			for item: Item in bag.items:
				expect(not item.is_divine(), "Gods never drop divine gear")
				if item.consumable.has("stat"):
					potions += 1
					expect(item.id == "elixir_of_magic" and bag_color == "blue", "Fosen's signature potion stays in blue bags")
				elif not item.is_consumable():
					expect(item.tier <= 5, "God gear capped at G5")
					if item.tier == 5:
						rare += 1
						expect(bag_color == "red", "Rare G5 is above blue and does not swallow potions")
	expect(rare >= 5 and rare < 45, "Seeded 20k god kills exercise the 0.1% G5 roll")
	expect(potions > 6500 and potions < 7500, "Signature potion chance is meaningful")
	print("GOD / 20000 kills: G5=", rare, ", signature potions=", potions)
	# Check policy even when a malformed table requests forbidden items at 100%.
	var fake := EnemyDef.new()
	fake.id = "bad_table"
	fake.is_god = true
	fake.loot.assign([{item = "G8_bow", chance = 1.0}, {item = "G6_wand", chance = 1.0}, {item = "D_spell_oftheblue", chance = 1.0}])
	expect(Loot.roll(fake, {1: 100}, rng).is_empty(), "Central loot policy rejects forbidden table entries")
	fake.loot.assign([{biome_stat = true, chance = 1.0}, {item = "G5_bow", chance = 1.0}])
	var separate := Loot.roll(fake, {1: 100}, rng, "mp")
	expect(separate.size() == 2, "Blue potion and red gear produce distinct bags")
	for bag in separate:
		if LootBag.type_for(bag.items) == "blue":
			expect(bag.items[0].id == "elixir_of_mp", "Biome potion follows the encounter biome")

func _test_spawns() -> void:
	for key in Enemies.PACKS:
		var pack := Enemies.pack(key)
		var ids: Array = pack.members.map(func(m: Dictionary) -> String: return m.enemy)
		if pack.has("leader"):
			ids.append(pack.leader.enemy)
		for id: String in ids:
			var enemy := Enemies.get_def(id)
			if enemy.is_god or enemy is BossDef:
				expect(pack.respawn_time < 0, "God/boss packs are finite: " + key)
	for biome in [Biomes.DOOM, Biomes.FOSEN, Biomes.BLUELAY, Biomes.DEEP_DESERT, Biomes.DEEP_DARK]:
		var density := 0.0
		for entry in Biomes.get_biome(biome).enemy_packs:
			density += entry.density
		if biome==Biomes.DEEP_DESERT:
			expect(is_equal_approx(density,.35), "Deep Desert keeps its reduced spirit population plus normal creatures")
		else:
			expect(density >= 0.7, "Frequent god sites in " + Biomes.get_biome(biome).biome_name)
	expect(Biomes.get_biome(Biomes.FOSEN).god_stat == "magic", "Fosen is famous for Magic")
	var generator := IslandGenerator.new(20261031)
	var area := Rect2i(-448, -448, 896, 896)
	var first := generator.pack_sites(area, [])
	var again := generator.pack_sites(area, [])
	expect(first == again, "Realm starts with a deterministic finite population")
	var counts := {}
	for site in first:
		counts[site.pack] = counts.get(site.pack, 0) + 1
		var biome := generator.column(floori(site.pos.x), floori(site.pos.z)).y
		if site.pack == "frost_moth_pack":
			expect(biome == Biomes.FOSEN, "Frost Moths only in Fosen")
		if site.pack == "ruin_watcher_pack":
			expect(biome == Biomes.BLUELAY, "Ruin Watchers only in Bluelay")
	for id in ["sporeback_pack", "thorn_hopper_pack", "cinder_beetle_pack", "frost_moth_pack", "ruin_watcher_pack"]:
		expect(counts.get(id, 0) >= 1, "Legacy enemy remains present after variety expansion: " + id)
	print("SEEDED REALM PACKS: ", counts)

func _test_persistence_and_models() -> void:
	var server := get_tree().root.get_node("WorldServer")
	server.reset_realm(FIXTURE_REALM)
	var world := FlatWorld.new()
	get_tree().root.add_child(world)
	var player := Player.new()
	player.stats = PlayerStats.new()
	world.add_child(player)
	player.set_physics_process(false)
	var bullets := EnemyBullets.new()
	world.add_child(bullets)
	var director := EnemyDirector.new()
	director.world = world
	director.realm_id = FIXTURE_REALM
	world.add_child(director)
	director.setup(player, bullets, [])
	director.set_process(false)
	for id in ["sporeback", "thorn_hopper", "cinder_beetle", "frost_moth", "ruin_watcher"]:
		var def := Enemies.get_def(id)
		CreatureModel.preload_creature(def.model)
		for attack in def.attacks:
			var mesh := bullets._mesh_for(attack)
			expect(mesh != null and mesh.get_surface_count() > 0, "Actual projectile mesh loads: " + id)
			bullets.fire(Vector3(0, 1, 0), Vector3.FORWARD, attack)
	expect(not bullets._shots.is_empty(), "Enemy projectile spawning works")
	bullets.clear()
	var site := {id = "fixture_pair", pack = "frost_moth_pack", pos = Vector3(20, 0, 20), seed = 1029}
	director._wake(site, ["frost_moth", "frost_moth"])
	var pack: EnemyPack = director._awake[site.id]
	for enemy in pack.members:
		enemy.set_physics_process(false)
	expect(pack.members.size() == 2, "Wake original finite pair")
	expect(pack.members[0]._home.is_equal_approx(site.pos), "Spawn home is the actual pack site")
	var victim := pack.members[0]
	victim.state = Enemy.State.DEAD
	victim.died.emit(victim)
	victim.queue_free()
	var record: Dictionary = server.get_or_create_realm(FIXTURE_REALM)
	expect(record.pack_survivors[site.id] == ["frost_moth"], "Individual god casualty saved before pack wipe")
	director._sleep(pack)
	director._wake(site, director._memory[site.id].survivors)
	pack = director._awake[site.id]
	expect(pack.members.size() == 1, "Chunk sleep/wake cannot revive the killed god")
	for enemy in pack.members:
		enemy.set_physics_process(false)
	director._sleep(pack)
	server._realms.erase(FIXTURE_REALM)
	record = server.get_or_create_realm(FIXTURE_REALM)
	expect(record.pack_survivors[site.id] == ["frost_moth"], "Survivor list survives save/reload")
	director._wake(site, record.pack_survivors[site.id])
	pack = director._awake[site.id]
	victim = pack.members[0]
	victim.state = Enemy.State.DEAD
	victim.died.emit(victim)
	victim.queue_free()
	expect(site.id in record.cleared_packs, "Final death permanently clears the site")
	expect(director._memory[site.id].back_at == -1, "Finite site has no respawn timer")
	director._wake(site, [])
	expect(not director._awake.has(site.id), "An explicit empty survivor list never re-rolls a pack")
	# The original failure mode: kill the spirit while its stars/genies remain.
	var mixed_site := {id = "fixture_spirit", pack = "spirit_brown_pack", pos = Vector3(-20, 0, 20), seed = 1030}
	director._wake(mixed_site, ["spirit_brown", "star", "genie_brown"])
	var mixed: EnemyPack = director._awake[mixed_site.id]
	for enemy in mixed.members:
		enemy.set_physics_process(false)
	var leader := mixed.leader
	leader.state = Enemy.State.DEAD
	leader.died.emit(leader)
	leader.queue_free()
	expect(record.pack_survivors[mixed_site.id] == ["star", "genie_brown"], "A killed spirit is saved while followers survive")
	director._sleep(mixed)
	director._wake(mixed_site, record.pack_survivors[mixed_site.id])
	mixed = director._awake[mixed_site.id]
	expect(mixed.leader == null and mixed.members.size() == 2, "Surviving followers never bring their dead god back")
	for enemy in mixed.members:
		enemy.set_physics_process(false)
	# Spirit visual transfer runs the real tween and voxel effect to completion.
	var spirit_pack := EnemyPack.new()
	var spirit := Enemy.new().setup(Enemies.get_def("spirit_brown"), spirit_pack, director)
	spirit.position = Vector3(0, 0, 4)
	director.add_child(spirit)
	spirit.set_physics_process(false)
	await get_tree().create_timer(0.45).timeout
	spirit.state = Enemy.State.ACTIVE
	var end := Vector3(3, 0, 4)
	spirit._start_blink(end)
	expect(spirit._blink_busy, "Blink has a visible transfer phase")
	await get_tree().create_timer(0.55).timeout
	expect(not spirit._blink_busy and spirit.global_position.is_equal_approx(end), "Blink reassembles at destination")
	expect(spirit.model.scale.is_equal_approx(Vector3.ONE), "Blink restores normal model scale")
	# Real physics-ring hits, at near and far range, not just a formula check.
	var near := HitProbe.new()
	near.position = Vector3(22, 0, -20)
	world.add_child(near)
	var far := HitProbe.new()
	far.position = Vector3(25.5, 0, -20)
	world.add_child(far)
	await get_tree().physics_frame
	var spell := Items.spell(4)
	var ring := MagicRing.cast(world, Vector3(20, 0, -20), spell, 0.0, player.stats.spell_multiplier(spell))
	var near_damage := ring.damage_at_distance(2.0)
	var far_damage := ring.damage_at_distance(5.5)
	await get_tree().create_timer(0.8).timeout
	expect(near.hits.size() == 1 and near.hits[0] == near_damage, "Actual near-range ring applies the scaled hit once")
	expect(far.hits.size() == 1 and far.hits[0] == far_damage and far.hits[0] >= 150, "Actual far-range spell hit is substantial, not ~10")
	world.queue_free()
	await get_tree().process_frame
	server.reset_realm(FIXTURE_REALM)
