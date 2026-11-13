class_name TheoryEnemies
## The brood aboard the Theory of Everything (6/10): black chitin, acid-green
## and pink glows, long simulated tails (CreatureModel "tail_chain").
const ACID := Color("7dff6a")
const PINK := Color("ff5fd2")

static func build(defs: Dictionary) -> void:
	# id, name, hp, defense, damage, behavior, height, speed.
	for spec in [
		["hull_skitter", "Hull Skitter", 480, 4, 30, "dart", 0.9, 4.0],
		["void_lamprey", "Void Lamprey", 640, 5, 34, "strafe", 1.8, 3.6],
		["gloom_spitter", "Gloom Spitter", 820, 7, 38, "skirmish", 2.0, 2.4],
		["vent_stalker", "Vent Stalker", 1500, 12, 46, "chase", 2.6, 3.0],
		["crest_brute", "Crest Brute", 2600, 20, 55, "chase", 3.1, 1.9],
	]:
		var d := EnemyDef.new()
		d.id = spec[0]
		d.enemy_name = spec[1]
		d.model = d.id
		d.hp = spec[2]
		d.defense = spec[3]
		d.xp = int(d.hp / 10)
		d.behavior = spec[5]
		d.body_height = spec[6]
		d.move_speed = spec[7]
		d.hit_radius = 0.45 if d.hp < 700 else 0.65 if d.hp < 2000 else 0.95
		d.keep_distance = 6.0
		d.aggro_radius = 15.0
		d.lose_radius = 26.0
		d.wander_radius = 2.0
		d.spawn_anim = "rise"
		d.dust_color = Color("2a2238")
		var damage: int = spec[4]
		var glob := {style = "orb", color = ACID, voxel_model = "boss_projectiles/acid_glob", authored_projectile = true,
			pixel_projectile = true, projectile_glow = 0.9, damage_min = damage, damage_max = damage + 10, speed = 6.5,
			range = 15.0, size = 0.8, radius = 0.18, root = true, recover = 0.35}
		var spine := {style = "bolt", color = PINK, voxel_model = "boss_projectiles/void_spine", authored_projectile = true,
			pixel_projectile = true, projectile_glow = 0.8, damage_min = damage, damage_max = damage + 12, speed = 9.0,
			range = 13.0, size = 0.75, radius = 0.15}
		match d.id:
			"hull_skitter":
				# Swarmers: a short pair of acid flecks, often.
				d.attacks.assign([glob.merged({pattern = "spread", count = 2, spread_deg = 14.0, speed = 7.5, range = 10.0,
					size = 0.55, cooldown = 1.9, windup = 0.45, recover = 0.2}, true)])
			"void_lamprey":
				d.attacks.assign([spine.merged({pattern = "burst", count = 3, interval = 0.18, cooldown = 2.6, windup = 0.6}, true)])
			"gloom_spitter":
				d.attacks.assign([glob.merged({pattern = "spread", count = 3, spread_deg = 16.0, cooldown = 2.6, windup = 0.85,
					from_hand = true}, true)])
			"vent_stalker":
				# Hunts from the dark: blinks sideways, then rakes with short spines.
				d.blink = {every = [4.0, 7.5], distance = 4.0}
				d.attacks.assign([spine.merged({pattern = "spread", count = 3, spread_deg = 22.0, speed = 10.5, range = 7.5,
					cooldown = 1.8, windup = 0.55, root = true, recover = 0.25}, true)])
			"crest_brute":
				d.attacks.assign([glob.merged({pattern = "spread", count = 5, spread_deg = 13.0, cooldown = 3.0, windup = 0.9}, true),
					{pattern = "shockwave", range = 7.5, cooldown = 6.5, windup = 1.1, root = true, recover = 0.5, color = ACID,
						ripple = {radius = 6.5, speed = 4.5, damage_min = damage - 10, damage_max = damage}}])
		d.loot.assign([{item = "elixir_hp", chance = 0.25}, {pool = {tier = 4}, chance = 0.15}, {pool = {tier = 5}, chance = 0.05}])
		defs[d.id] = d
	var b := RealmBosses._boss("void_empress", "The Hollow Empress", "void_empress", "", "void_empress")
	b.wake_on = "near"
	b.aggro_radius = 17.0
	b.hp = 38000
	b.defense = 20
	b.body_height = 7.5
	b.hit_radius = 2.1
	b.xp = 3800
	b.intro_time = 5.0
	b.bar_radius = 40.0
	b.abandon_radius = 36.0
	b.dungeon_reward = true
	b.burst_color = PINK
	# Each threshold drops one ring of the Convergence (TheoryWorld.set_arena_stage).
	b.phases.assign([{until = 0.75, defense = 20}, {until = 0.5, defense = 20}, {until = 0.25, defense = 18, variant = "brood"},
		{until = 0.0, defense = 12, variant = "unmade"}])
	b.loot.assign([{item = "elixir_hp", chance = 1.0}, {item = "elixir_mp", chance = 1.0}, {pool = {tier = 5}, chance = 0.35},
		{pool = {tier = 6}, chance = 0.1}, {item = "elixir_of_dexterity", chance = 1.0}, {item = "backpack", chance = 0.03}])
	defs[b.id] = b
