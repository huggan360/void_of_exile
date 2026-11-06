extends Node3D

const WAND := "D_wand_thewandofthespitit"
var checks := 0
var failures := 0

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
	var wand := Items.make(WAND)
	check(wand != null and wand.icon() != null, "Spirit wand and original texture are registered")
	check(wand.is_divine() and wand.bag_type() == "white" and wand.soulbound(), "Spirit wand uses personal White Chests")
	check(wand.bonuses == {speed = 5, dexterity = 5}, "Wand grants exactly five speed and dexterity")
	check(wand.usable_by("wizard") and not wand.usable_by("archer"), "Spirit wand follows normal wand class restrictions")
	var stats := PlayerStats.new()
	stats.class_id = "wizard"
	var before_speed := stats.total("speed")
	var before_dex := stats.total("dexterity")
	stats.gear.weapon = wand
	check(stats.total("speed") == before_speed + 5 and stats.total("dexterity") == before_dex + 5, "Equipping applies both stat bonuses")
	stats.gear.weapon = null
	check(stats.total("speed") == before_speed and stats.total("dexterity") == before_dex, "Unequipping removes both bonuses")
	var tooltip := ItemTooltip.new()
	add_child(tooltip)
	tooltip.show_item(wand)
	check(tooltip._text.get_parsed_text().contains("3 - equal shares"), "Tooltip shows three equally shared charged projectiles")
	check(tooltip._text.get_parsed_text().contains("Dreadcoil Trinity"), "Tooltip names the special secondary attack")
	tooltip.queue_free()
	var arrows := Arrows.new()
	add_child(arrows)
	arrows.set_physics_process(false)
	check(arrows._meshes_for(wand, "serpent")[1] != null, "Dedicated serpent projectile has glowing geometry")
	var player := Player.new()
	player.stats = stats
	add_child(player)
	add_child(player.aim_marker)
	player.set_physics_process(false)
	player.set_process(false)
	stats.gear.weapon = wand
	player.frozen = false
	player._aim_point = Vector3(0, 0, -20)
	var fired: Array = []
	player.shot.connect(func(origin: Vector3, direction: Vector3, damage: int, weapon: Item, phase: float, mods: Dictionary) -> void:
		fired.append({direction = direction, damage = damage, phase = phase, mods = mods.duplicate()})
		arrows.spawn(origin, direction, damage, weapon, phase, "", mods))
	player._fire()
	check(fired.size() == 2 and is_equal_approx(fired[1].phase - fired[0].phase, PI), "Primary fires counterphase twin serpents")
	var left: Vector3 = arrows._position_at(arrows._shots[0], 3.0)
	var right: Vector3 = arrows._position_at(arrows._shots[1], 3.0)
	check(left.distance_to(right) > 0.1, "Twin serpents weave apart in flight")
	fired.clear()
	player._release_charge(wand, 1.0)
	check(fired.size() == 3, "Dreadcoil Trinity fires three serpents")
	check(fired[0].direction != fired[1].direction and fired[1].direction != fired[2].direction, "Charged serpents form a fan")
	for shot: Dictionary in fired:
		check(shot.mods.secondary and shot.mods.pierce and shot.mods.spiral and shot.mods.style == "serpent", "Charged shot preserves secondary status, piercing and network visual parameters")
	check(wand.secondary_effects[0].id == "armour_broken", "Charged attack has its own armour break")
	for id in ["spirit_brown", "spirit_blue", "spirit_purple", "genie_brown", "genie_blue", "genie_purple", "star"]:
		var def := Enemies.get_def(id)
		var model := CreatureModel.new(def.model)
		add_child(model)
		var data := CreatureModel._load(def.model)
		check(data.rig.animation_style == "serpent", "Serpent animation enabled for " + id)
		check(model._limbs.size() == 3 and data.rig.hover > 0, "Articulated floating model for " + id)
		for pair: Array in data.meshes.values():
			check(pair[0] == null and pair[1] != null, "Whole-body genie-style glow for " + id)
		model.animate(0, 0.016)
		var idle: Vector3 = model._limbs.neck.rotation
		model.play_attack(0.4)
		model.animate(1.0, 0.2)
		check(model._limbs.neck.rotation != idle, "Attack windup animates neck for " + id)
		model.strike()
		model.animate(0, 0.12)
		check(model._limbs.jaw.rotation.x < -0.1, "Strike animates jaw for " + id)
		model.queue_free()
	_test_loot()
	player.aim_marker.free()
	player.queue_free()
	arrows.queue_free()
	await get_tree().process_frame
	print("SPIRIT REWORK: %d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures else 0)

func _test_loot() -> void:
	var wand := Items.make(WAND)
	for id in ["spirit_brown", "spirit_blue", "genie_purple", "star", "blue_genie"]:
		check(not Loot._allowed(Enemies.get_def(id), wand), "Unassigned encounter cannot drop Spirit wand: " + id)
	var purple := Enemies.get_def("spirit_purple")
	check(Loot._allowed(purple, wand), "Purple Spirit can drop its assigned wand")
	var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://server_config/loot.json"))
	var live_config := ServerConfig.new()
	live_config.loot = config
	live_config.apply()
	var entry_found := false
	for entry: Dictionary in config.enemies.spirit_purple.loot:
		if entry.get("item", "") == WAND:
			entry_found = is_equal_approx(float(entry.chance), 0.03)
	check(entry_found, "Dedicated server override includes the 3% wand drop")
	check(purple.loot.any(func(entry: Dictionary) -> bool: return entry.get("item", "") == WAND), "Applying live server config preserves the wand loot entry")
	var rng := RandomNumberGenerator.new()
	rng.seed = 412612
	var drops := {1: 0, 2: 0}
	for i in 10000:
		for bag: Dictionary in Loot.roll(purple, {1: purple.hp, 2: purple.hp * 0.5, 3: 1}, rng):
			for item: Item in bag.items:
				if item.id != WAND: continue
				check(bag.viewer in [1, 2] and LootBag.type_for(bag.items) == "white", "Wand is personal, eligible-only White Chest loot")
				drops[bag.viewer] += 1
	check(drops[1] > 230 and drops[1] < 370 and drops[2] > 230 and drops[2] < 370, "Seeded loot rolls exercise independent 3% chances for both eligible players")
	print("SPIRIT WAND / 10000 kills: ", drops)
