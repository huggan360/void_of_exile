class_name DungeonEnemies
## Five cave species, an optional warlord, a treasure cache and the King.
static func build(defs: Dictionary) -> void:
	var specs := [
		["cave_slinger", "Cave Goblin Slinger", 100, 0, "skirmish", 3.0, 10, 16, 8.0, 1, 2.0],
		["moss_bat", "Moss Bat", 65, 0, "dart", 4.0, 8, 13, 7.0, 1, 2.3],
		["mushroom_crawler", "Mushroom Crawler", 130, 2, "chase", 2.0, 12, 18, 5.0, 3, 2.8],
		["goblin_brute", "Goblin Brute", 300, 6, "chase", 2.1, 20, 28, 6.0, 3, 2.6],
		["cave_shaman", "Cave Shaman", 220, 3, "strafe", 2.4, 14, 22, 7.0, 5, 3.0],
		["goblin_warlord", "Goblin Warlord", 1300, 8, "skirmish", 2.2, 22, 32, 7.0, 5, 2.8],
	]
	for spec in specs:
		var d := EnemyDef.new()
		d.id = spec[0]
		d.enemy_name = spec[1]
		d.model = spec[0]
		d.hp = spec[2]
		d.defense = spec[3]
		d.behavior = spec[4]
		d.move_speed = spec[5]
		d.xp = 25 if d.hp < 200 else 60
		d.leash = 11.0
		d.keep_distance = 5.0
		d.aggro_radius = 12.0
		d.lose_radius = 22.0
		d.body_height = 1.2 if d.id in ["moss_bat", "mushroom_crawler"] else 2.2
		d.hit_radius = 0.45 if d.id == "moss_bat" else 0.65
		d.attacks.assign([{damage_min = spec[6], damage_max = spec[7], speed = spec[8], style = "orb",
			color = Color("a2b74e"), size = 0.65, range = 12.0, pattern = "spread", count = spec[9], spread_deg = 18.0,
			cooldown = spec[10], windup = 0.7, root = true, recover = 0.3}])
		d.loot.assign([{item = "elixir_hp", chance = 0.25}, {pool = {tier = 3 if d.hp < 200 else 4}, chance = 0.12}])
		if d.id == "goblin_warlord":
			d.xp = 250
			d.loot.append({item = "elixir_of_speed", chance = 0.35})
		defs[d.id] = d
	var chest := EnemyDef.new()
	chest.id = "goblin_treasure"
	chest.enemy_name = "Goblin Treasure Cache"
	chest.model = "goblin_treasure"
	chest.hp = 30
	chest.behavior = "stationary"
	chest.body_height = 1.0
	chest.loot.assign([{pool = {tier = 4}, chance = 1.0}, {item = "elixir_of_dexterity", chance = 0.3}])
	defs[chest.id] = chest
	var king := BossDef.new()
	king.id = "goblin_king"
	king.enemy_name = "Goblin King"
	king.model = "goblin_king"
	king.actor_script = "res://scripts/enemies/bosses/goblin_king.gd"
	king.hp = 5200
	king.defense = 5
	king.xp = 1200
	king.body_height = 4.5
	king.hit_radius = 1.7
	king.aggro_radius = 13.0
	king.bar_radius = 25.0
	king.abandon_radius = 28.0
	king.lose_radius = 40.0
	king.intro_time = 3.0
	king.death_time = 2.0
	king.loot_threshold = 0.04
	king.dungeon_reward = true
	king.phases.assign([{until = 0.68, behavior = "stationary", attacks = []},
		{until = 0.32, behavior = "stationary", attacks = []}, {until = 0.0, behavior = "stationary", attacks = []}])
	king.loot.assign([{pool = {tier = 4}, chance = 0.35}, {pool = {tier = 5}, chance = 0.08}, {item = "elixir_hp", chance = 1.0}])
	for item in Items.divine_ids_for(king.id): king.loot.append({item = item, chance = 0.02 if item == "D_wand_thewandofthefallenwood" else 0.025})
	defs[king.id] = king
