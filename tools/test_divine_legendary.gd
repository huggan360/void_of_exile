extends Node3D
## Catalog, complete loadouts, authoritative loot, save migrations and UI rarity.
var checks := 0
var failures := 0

class RingTarget:
	extends StaticBody3D
	var hits: Array[int] = []
	func take_hit(_at: Vector3, _direction: Vector3, damage: int) -> void:
		hits.append(damage)

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	GameAudio._disabled = true
	GameAudio.set_process(false)
	GameServer.set_physics_process(false)
	WorldServer.set_process(false)
	_catalog()
	_migration()
	_loot()
	await _spells()
	await _presentation()
	print("DIVINE / LEGENDARY: %d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures else 0)

func _catalog() -> void:
	var all := Items.all()
	var seen := {}
	for item in all:
		check(not seen.has(item.id), "Unique catalog id: " + item.id)
		seen[item.id] = true
		check(item.icon() != null, "Item icon exists: " + item.id)
	var divine_count := 0
	for set_name: String in Items.DIVINE_SETS:
		var ids: Array = Items.DIVINE_SETS[set_name]
		check(ids.size() >= 4 and ids.size() <= 7, "Four to seven pieces: " + set_name)
		var pieces: Array[Item] = []
		for id: String in ids:
			var item := Items.make(id)
			check(item != null, "Set piece registered: " + id)
			if item == null: continue
			pieces.append(item)
			divine_count += 1
			check(item.is_divine() and not item.is_legendary() and item.badge() == "D", "Divine identity: " + id)
			check(item.soulbound() and not LootBag.can_hold("green", true, item), "Soulbound cannot enter public chest: " + id)
			check(LootBag.can_hold("vault", false, item), "Soulbound can enter owner's vault: " + id)
			check(item.icon().get_width() == 8 and item.icon().get_height() == 8, "8x8 set icon: " + id)
			if item.slot == "spell":
				check(not item.ring.is_empty() and not item.secondary_effects.is_empty(), "Spell has ring and themed effects: " + id)
				check(SpellFX.style(item).heavy, "Divine spell retains special presentation: " + id)
		for weapon: Item in pieces:
			if weapon.slot != "weapon": continue
			var complete := false
			for class_id: String in PlayerClasses.ORDER:
				if not weapon.usable_by(class_id): continue
				var slots := {}
				for piece: Item in pieces:
					if piece.usable_by(class_id): slots[piece.slot] = true
				if PlayerStats.GEAR_SLOTS.all(func(slot: String) -> bool: return slots.has(slot)):
					complete = true
			check(complete, "Weapon has a class-compatible four-slot loadout: " + weapon.id)
	for set_name in ["Storm", "Frost", "Venom", "Eclipse", "Stormeye"]:
		var ids: Array = Items.DIVINE_SETS[set_name]
		check(ids.size() == 7, "Large set reduced to seven: " + set_name)
		check(ids.filter(func(id: String) -> bool: return Items.make(id).slot == "bonus").size() == 1, "One signature relic: " + set_name)
	check(all.filter(func(i: Item) -> bool: return i.is_divine()).size() == divine_count, "Every Divine item belongs to a set")
	var legendary := all.filter(func(i: Item) -> bool: return i.is_legendary())
	check(legendary.size() == 42 and legendary.any(func(i: Item) -> bool: return i.id == "L_wand_thewandofash"), "All Legendary signatures are registered")
	check(not Items.DIVINE_SETS.has("Ash") and Items.divine_ids_for("mad_farmer").is_empty(), "Ash is outside Divine sets")
	var ash := Items.make("L_wand_thewandofash")
	check(ash.badge() == "L" and ash.grade_name() == "Legendary" and not ash.is_divine(), "Legendary name and badge")
	check(ash.soulbound() and ash.bag_type() == "black", "Legendary uses personal soulbound loot")
	check(UIStyle.grade_color(ash) == Color("4ba9ff"), "Legendary inventory glow is blue")
	check(UIStyle.grade_color(Items.make("D_bow_dragon")) == UIStyle.DIVINE_COLOR, "Divine inventory glow stays pink")
	var bound_copy := ash.duplicate() as Item
	bound_copy.drop_bag = "green"
	check(bound_copy.soulbound() and not LootBag.can_hold("green", true, bound_copy), "Legendary stays soulbound even with a bag override")
	check(Items.make("D_bonus_talisman_ofstorm").bonuses.get("magic", 0) > 0 and Items.make("D_bonus_talisman_ofstorm").bonuses.get("dexterity", 0) > 0, "Storm's surviving relic carries both casting and firing bonuses after final stat setup")
	check(ash.shots == 2 and ash.charge.style == "inferno" and ash.attack_effects()[0].id == "burning", "Ash retains ember shots and Ashfall")
	check(Dots.dismantle_value(ash) == Dots.DIVINE, "Ash retains its forge value")
	check(EquipmentAppearance.profiles().has(ash.id), "Legendary has an equipment model")
	for item: Item in all:
		if item.slot == "armor": check(EquipmentAppearance.profiles().has(item.id), "Armor appearance exists: " + item.id)
	var rng := RandomNumberGenerator.new()
	rng.seed = 92731
	for n in 300:
		var item := Items.from_pool({tier = (n % 8) + 1}, rng)
		check(item != null and not item.is_special(), "Graded pools exclude both special rarities")
	check(Loot.upgrade(ash, 1.0, rng) == ash, "Loot upgrades preserve Legendary identity")
	check(Loot.rarest_per_kind([Items.wand(8), ash])[0].id == ash.id, "Legendary takes priority over graded wand loot")
	# A temporary export supports documentation and the account-service checks.
	var data := {sets = Items.DIVINE_SETS, bosses = Items.BOSS_DIVINE_SET, legendary = Items.BOSS_LEGENDARY_ITEMS, artifacts = Items.BOSS_ARTIFACT_ITEMS,
		aliases = Items.RETIRED_ITEM_IDS, items = {}}
	for item: Item in all:
		if not item.is_special(): continue
		data.items[item.id] = {name = item.item_name, slot = item.slot, kind = item.kind, badge = item.badge(),
			bonuses = item.bonuses, effects = item.effects, ring = item.ring, damage = [item.damage_min, item.damage_max],
			rate = item.fire_rate, shots = item.shots, shares = item.projectile_shares, projectile_style = item.projectile.get("style", ""), chance = Items.signature_chance(item) if not item.is_divine() else 0.0}
	var file := FileAccess.open("/home/hugo/tmp/divine_legendary_catalog.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(data, "\t"))

func _migration() -> void:
	for old: String in Items.RETIRED_ITEM_IDS:
		var expected: String = Items.RETIRED_ITEM_IDS[old]
		check(Items.exists(old) and Items.make(old).id == expected, "Retired item migrates: " + old)
		var saved := PlayerStats._item_from({id = old, count = 1})
		check(saved != null and saved.id == expected, "Saved inventory migrates: " + old)
		var wire := Net.decode_items([{id = old, count = 1}, null])
		check(wire[0].id == expected and wire[1] == null, "Vault/network inventory migrates: " + old)
		check(not FileAccess.file_exists("res://items/textures/" + old + ".png"), "Retired icon removed: " + old)
	var stats := PlayerStats.new()
	stats.load_data({class_id = "wizard", gear = {weapon = {id = "D_wand_thewandofash"}},
		backpack = [{id = "D_bonus_crucifix_offrost"}, {id = "D_bonus_flame_offrost"}]})
	check(stats.gear.weapon.is_legendary() and stats.backpack[0].id == "D_bonus_crystal_offrost" and stats.backpack[1].id == "D_bonus_crystal_offrost", "Owned copies survive conversion independently")
	var roundtrip := PlayerStats.new()
	roundtrip.load_data(stats.to_data())
	check(roundtrip.gear.weapon.id == "L_wand_thewandofash" and roundtrip.backpack[1].id == "D_bonus_crystal_offrost", "Migrated ids survive save/reload")

func _loot() -> void:
	var ash := Items.make("L_wand_thewandofash")
	var farmer := Enemies.get_def("mad_farmer")
	check(Loot._allowed(farmer, ash), "Mad Farmer can drop Legendary Ash")
	for enemy_id: String in ["spirit_purple", "spirit_brown", "blue_dragon", "mother_mycora", "goblin_king"]:
		check(not Loot._allowed(Enemies.get_def(enemy_id), ash), "Other enemies cannot drop Ash: " + enemy_id)
	for boss: String in Items.BOSS_LEGENDARY_ITEMS:
		check(Items.legendary_ids_for(boss).size() <= 2, "At most two Legendary signatures per boss")
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261117
	var found := 0
	for n in 6000:
		for bag: Dictionary in Loot.roll(farmer, {1: farmer.hp, 2: 1}, rng):
			for item: Item in bag.items:
				if item.id != ash.id: continue
				found += 1
				check(item.id == ash.id and bag.viewer == 1 and bag.type == "black", "Ash loot is private and contributor-only")
	check(found > 130 and found < 240, "Legendary rolls independently near 3%% (%d / 6000)" % found)
	# Strong loot bonus guarantees every allowed set roll, including the added pieces.
	for enemy_id: String in Items.BOSS_DIVINE_SET:
		var enemy := Enemies.get_def(enemy_id)
		check(enemy != null, "Assigned encounter exists: " + enemy_id)
		if enemy == null: continue
		var found_ids := {}
		for bag: Dictionary in Loot.roll(enemy, {1: enemy.hp}, rng, "magic", enemy.hp, {1: {chance = 1000.0}}):
			for item: Item in bag.items:
				if item.is_divine(): found_ids[item.id] = true
		for id: String in Items.divine_ids_for(enemy_id):
			check(found_ids.has(id), "Assigned piece reaches real loot roll: %s / %s" % [enemy_id, id])
	# An old server override contains all five Frost relics. Only one may roll now.
	var legacy := BossDef.new()
	legacy.id = "rimeheart_prism"
	for kind: String in Items.BONUS_KINDS:
		legacy.loot.append({item = "D_bonus_%s_offrost" % kind, chance = 1.0})
	var rolls := Loot._with_special(legacy)
	check(rolls.filter(func(entry: Dictionary) -> bool: return str(entry.get("item", "")).begins_with("D_bonus_")).size() == 1, "Retired server overrides cannot multiply relic rolls")
	var config := ServerConfig.new()
	config.loot = JSON.parse_string(FileAccess.get_file_as_string("res://server_config/loot.json"))
	config.apply()
	check(Loot._with_special(Enemies.get_def("rimeheart_prism")).filter(func(e: Dictionary) -> bool: return str(e.get("item", "")).begins_with("D_bonus_")).size() == 1, "Bundled live override has one Frost relic")
	print("Legendary Ash: ", found, " / 6000 kills")

func _spells() -> void:
	var stage := Node3D.new()
	add_child(stage)
	var target := RingTarget.new()
	target.position = Vector3(2, 0, 0)
	target.collision_layer = Player.ENEMY_LAYER
	var collider := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.5
	collider.shape = sphere
	collider.position.y = 0.9
	target.add_child(collider)
	stage.add_child(target)
	var shield := MagicShield.new()
	stage.add_child(shield)
	await get_tree().physics_frame
	for spell: Item in Items.divine():
		if spell.slot != "spell": continue
		target.hits.clear()
		shield.set_spell(spell)
		var ring := MagicRing.cast(stage, Vector3.ZERO, spell)
		ring.set_physics_process(false)
		ring._physics_process(0.3)
		ring._physics_process(0.1)
		check(target.hits.size() == 1 and target.hits[0] > 0, "Real ring hits once with positive damage: " + spell.id)
		ring.free()
	var arrows := Arrows.new()
	stage.add_child(arrows)
	arrows.spawn(Vector3.ZERO, Vector3.FORWARD, 10, Items.make("L_wand_thewandofash"))
	arrows.clear()
	stage.queue_free()
	await get_tree().process_frame

func _presentation() -> void:
	var row := HBoxContainer.new()
	row.position = Vector2(30, 30)
	row.add_theme_constant_override("separation", 24)
	add_child(row)
	for id in ["L_bow_kaleidoscope", "D_bow_dragon", "A_wand_lastfirework", "A_cloak_starparade", "A_wand_pocketplanetarium"]:
		var slot := ItemSlot.new()
		row.add_child(slot)
		slot.item = Items.make(id)
	var tooltip := ItemTooltip.new()
	add_child(tooltip)
	tooltip.show_item(Items.make("L_wand_thewandofash"))
	tooltip.set_process(false)
	tooltip.position = Vector2(30, 150)
	await get_tree().process_frame
	if "--shot" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("/home/hugo/tmp/legendary_inventory.png")
	row.free()
	tooltip.free()
