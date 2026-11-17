extends Node
## Exercise the real equipment/stat/save paths, not copies of the calculation.
var checks := 0
var failures := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func _ready() -> void: run.call_deferred()

func loadout(name: String, class_id := "") -> Dictionary:
	for candidate: String in PlayerClasses.ORDER:
		if class_id != "" and candidate != class_id: continue
		var out := {}
		for id: String in Items.DIVINE_SETS[name]:
			var item := Items.make(id)
			if item.usable_by(candidate) and not out.has(item.slot): out[item.slot] = item
		if out.size() == 4: return {class_id = candidate, gear = out}
	return {}

func run() -> void:
	GameAudio._disabled = true
	GameServer.set_physics_process(false)
	WorldServer.set_process(false)
	var definitions := DivineSetBonuses.definitions()
	check(definitions.size() == Items.DIVINE_SETS.size(), "Every live Divine set has stages")
	for name: String in Items.DIVINE_SETS:
		var def: Dictionary = definitions[name]
		check(def.stages.size() == 3, "Three stages: " + name)
		for i in 3:
			check(int(def.stages[i].pieces) == i + 2, "Unlock at 2/3/4: " + name)
			check(def.stages[i].bonuses.size() <= (5 if name == "Madness" else 4), "Bounded stat variety: " + name)
		var setup := loadout(name)
		check(not setup.is_empty(), "Class-compatible four-slot set: " + name)
		if setup.is_empty(): continue
		var stats := PlayerStats.new()
		stats.class_id = setup.class_id
		stats.reset()
		for slot: String in PlayerStats.GEAR_SLOTS: stats.gear[slot] = null
		stats.give(setup.gear.values())
		check(DivineSetBonuses.bonuses_for(stats.gear).is_empty(), "Backpack never grants stages: " + name)
		var expected := {}
		for count in range(1, 5):
			var slot: String = PlayerStats.GEAR_SLOTS[count - 1]
			var item: Item = setup.gear[slot]
			var pack_index := stats.backpack.find(item)
			check(stats.activate({kind = "pack", key = pack_index}), "Equip via real inventory path: " + item.id)
			if count >= 2:
				for stat: String in def.stages[count - 2].bonuses:
					expected[stat] = int(expected.get(stat, 0)) + int(def.stages[count - 2].bonuses[stat])
			check(DivineSetBonuses.bonuses_for(stats.gear) == expected, "Stages accumulate at %d: %s" % [count, name])
			for stat: String in PlayerStats.STAT_NAMES:
				var own := 0
				for equipped: Item in stats.gear.values():
					if equipped: own += int(equipped.bonuses.get(stat, 0))
				check(stats.gear_bonus(stat) == own + int(expected.get(stat, 0)), "Adds to own item stats: %s/%s/%d" % [name, stat, count])
		stats.hp = stats.max_hp
		stats.mp = stats.max_mp
		var saved := stats.to_data()
		var restored := PlayerStats.new()
		for repeat in 3:
			restored.load_data(saved)
			check(restored.gear_bonus("magic") == stats.gear_bonus("magic") and restored.max_hp == stats.max_hp and restored.max_mp == stats.max_mp, "Save/load derives bonuses without accumulation: " + name)
		check(saved.base == stats.base and saved.base_hp == stats.base_hp, "Set bonuses never enter permanent stats")
		var foreign_spell := Items.spell(5)
		var predicted := stats.spell_multiplier(foreign_spell)
		var original_spell: Item = stats.gear.spell
		stats.gear.spell = foreign_spell
		check(is_equal_approx(predicted, stats.spell_multiplier(foreign_spell)), "Spell preview accounts for lost set stage: " + name)
		stats.gear.spell = original_spell
		var predicted_set := stats.spell_multiplier(original_spell)
		stats.gear.spell = foreign_spell
		check(is_equal_approx(stats.spell_multiplier(original_spell), predicted_set), "Spell preview accounts for gained set stage: " + name)
		stats.gear.spell = original_spell
		for slot: String in PlayerStats.GEAR_SLOTS:
			check(stats.activate({kind = "gear", key = slot}), "Unequip via real inventory path: " + name)
			check(stats.hp <= stats.max_hp and stats.mp <= stats.max_mp, "Resources clamp on losing bonuses: " + name)
		check(stats.set_bonus("hp") == 0 and DivineSetBonuses.bonuses_for(stats.gear).is_empty(), "All stages removed on unequip: " + name)
	var mixed := PlayerStats.new()
	var iron: Dictionary = loadout("Iron", "wizard").gear
	var holy: Dictionary = loadout("Holy_Divine", "wizard").gear
	mixed.gear = {weapon = iron.weapon, armor = iron.armor, spell = holy.spell, bonus = holy.bonus}
	check(mixed.set_bonus("attack") == 2 and mixed.set_bonus("hp") == 20 and mixed.set_bonus("speed") == 0, "Mixed two-plus-two unlocks both first stages only")
	mixed.backpack[0] = iron.spell
	check(mixed.set_bonus("speed") == 0, "Third matching piece in pack cannot unlock second stage")
	mixed.gear.bonus = Items.bonus(8, "flame")
	check(mixed.set_bonus("hp") == 0 and mixed.set_bonus("attack") == 2, "Graded equipment cannot complete a Divine set")
	var duplicate: Item = iron.weapon
	check(DivineSetBonuses.equipped_counts({weapon = duplicate, armor = duplicate, spell = duplicate, bonus = duplicate}).get("Iron", 0) == 1, "Duplicate and wrong-slot equipment cannot inflate counts")
	for item: Item in Items.all():
		if item.slot not in PlayerStats.GEAR_SLOTS: continue
		check(int(item.bonuses.get("attack", 0)) <= 7, "Attack stays within reduced item budget: " + item.id)
	for tier in range(1, 9):
		for family: String in ["bow", "wand", "trident", "cloak", "robe", "spell"]:
			if family == "spell" and tier > 5: continue
			var direct: Item
			match family:
				"bow": direct = Items.bow(tier)
				"wand": direct = Items.wand(tier)
				"trident": direct = Items.trident(tier)
				"cloak": direct = Items.cloak(tier)
				"robe": direct = Items.robe(tier)
				"spell": direct = Items.spell(tier)
			check(direct.bonuses == Items.make(direct.id).bonuses, "Direct constructor and catalog balance agree: " + direct.id)
	check(Items.cloak(8).bonuses.defense == 25 and Items.robe(8).bonuses.defense == 16, "Defense retains the current graded budget")
	var barrow := PlayerStats.new()
	barrow.gear = loadout("Barrow", "merrow").gear
	check(barrow.set_bonus("defense") == 3 and barrow.total("defense") > int(barrow.base.defense), "Defensive set stages enter effective defense")
	barrow.buffs.add("armour_broken", 10)
	check(barrow.total("defense") == int(barrow.base.defense), "Armour break suppresses equipment and set defense together")
	var legendary_low := 0
	var legendary_high := 0
	for item: Item in Items.legendary():
		if not item.is_weapon(): continue
		var graded := Items.make("G8_" + item.kind.to_lower())
		var shares := 0.0
		for i in graded.shots: shares += graded.shot_share(i)
		var reference := (graded.damage_min + graded.damage_max) * 0.5 * graded.fire_rate * shares
		var primary := (item.damage_min + item.damage_max) * 0.5 * item.fire_rate
		if primary < reference: legendary_low += 1
		else: legendary_high += 1
	check(legendary_low >= 10 and legendary_high >= 3, "Legendary catalog includes both lower-damage alternatives and high-damage signatures")
	var tooltip := ItemTooltip.new()
	tooltip.theme = UIStyle.theme()
	tooltip.stats = mixed
	var tooltip_root := Control.new()
	tooltip_root.size = Vector2(1280, 720)
	add_child(tooltip_root)
	tooltip_root.add_child(tooltip)
	tooltip.show_item(iron.weapon)
	check(tooltip._set_panel.visible and tooltip._set_panel._title.text.contains("2/4"), "Divine hover footer reads actual equipped count")
	check(tooltip._set_panel._labels[0].text == "+2 ATK", "First-stage compact stat row")
	tooltip.show_item(Items.legendary()[0])
	check(not tooltip._set_panel.visible, "Legendary hover never shows a Divine footer")
	tooltip.show_item(Items.bow(8))
	check(not tooltip._set_panel.visible, "Graded hover never shows a Divine footer")
	var max_height := 0.0
	var tallest := ""
	for item: Item in Items.divine():
		tooltip.show_item(item)
		for frame in 16: await get_tree().process_frame
		check(tooltip.size.y <= tooltip_root.size.y - 16, "Whole Divine hover fits viewport: " + item.id)
		if tooltip.size.y > max_height:
			max_height = tooltip.size.y
			tallest = item.id
		check(tooltip.size.x <= 600, "Hover width stays compact: " + item.id)
	print("Tallest Divine hover: %s %.0f px" % [tallest, max_height])
	tooltip_root.queue_free()
	print("DIVINE SET BONUSES: %d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures else 0)
