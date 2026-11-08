class_name SpaceEnemies
## The creatures of the Astral Reach's planets: three kinds and a god on each
## world, tougher further out (danger 0 to 3), each with its own projectile,
## behaviour and loot. Some live by certain obstacles, some lead workers or
## minions, gods drop a signature stat potion. PLANET_PACKS places them on
## each planet's top (SpaceWorld).

## Per danger level: hp, defense and damage scale, xp, and the gear tiers dropped.
const TIERS := [
	{hp = 1.0, defense = 0, damage = 1.0, tiers = [1, 2, 3]},
	{hp = 1.7, defense = 4, damage = 1.35, tiers = [2, 3, 4]},
	{hp = 2.6, defense = 9, damage = 1.75, tiers = [3, 4, 5]},
	{hp = 3.8, defense = 15, damage = 2.2, tiers = [4, 5, 6]},
]

## id: [name, planet, height m, hp, defense, damage, behavior, speed, glow colour, projectile, kind]
## kind: swarm, small, big, god. Hp and damage are danger-0 figures, scaled by TIERS.
const CAST := {
	# Verdance (danger 0): the mossy forest.
	moss_glimmer = ["Moss Glimmer", "verdance", 0.7, 120, 0, 18, "dart", 4.6, "f2e27a", "spore_puff", "swarm"],
	capling = ["Capling", "verdance", 1.0, 260, 2, 24, "skirmish", 2.6, "a8ffb0", "spore_puff", "small"],
	bark_warden = ["Bark Warden", "verdance", 2.4, 900, 6, 34, "chase", 2.0, "ffc070", "spore_puff", "big"],
	elder_thornheart = ["Elder Thornheart", "verdance", 4.0, 3200, 12, 130, "strafe", 2.4, "a8ffb0", "spore_puff", "god"],
	# Rosamund (danger 0): pink crystal meadows.
	petal_sprite = ["Petal Sprite", "rosamund", 0.7, 110, 0, 16, "orbit", 3.4, "ffb8f0", "rose_shard", "swarm"],
	quartz_hopper = ["Quartz Hopper", "rosamund", 1.0, 240, 3, 22, "skirmish", 3.2, "ffc6e2", "rose_shard", "small"],
	rose_golem = ["Rose Golem", "rosamund", 2.2, 950, 8, 32, "chase", 1.8, "ff8ad8", "rose_shard", "big"],
	queen_lumeria = ["Queen Lumeria", "rosamund", 3.2, 3000, 10, 125, "strafe", 2.8, "ffb8f0", "rose_shard", "god"],
	# Amberfall (danger 1): amber dunes.
	honey_mite = ["Honey Mite", "amberfall", 0.7, 130, 1, 18, "dart", 4.4, "ffcf6a", "honey_comet", "swarm"],
	amber_scarab = ["Amber Scarab", "amberfall", 1.3, 340, 6, 24, "strafe", 2.4, "ffb040", "honey_comet", "small"],
	dune_drake = ["Dune Drake", "amberfall", 2.6, 980, 7, 34, "chase", 2.8, "ff8a3a", "honey_comet", "big"],
	amber_sphinx = ["The Amber Sphinx", "amberfall", 4.5, 3100, 14, 128, "stationary", 0.0, "ffcf6a", "honey_comet", "god"],
	# Tidewell (danger 1): islands and sea.
	surf_crab = ["Surf Crab", "tidewell", 0.9, 220, 4, 20, "skirmish", 2.8, "a8f0ff", "tide_pearl", "small"],
	tide_siren = ["Tide Siren", "tidewell", 1.6, 420, 3, 26, "strafe", 3.0, "8ad2ff", "tide_pearl", "small"],
	kelp_horror = ["Kelp Horror", "tidewell", 2.2, 1100, 8, 30, "stationary", 0.0, "7fffb0", "tide_pearl", "big"],
	leviathan_herald = ["The Leviathan Herald", "tidewell", 4.0, 3300, 12, 128, "strafe", 2.6, "8ad2ff", "tide_pearl", "god"],
	# Shardheart (danger 2): the humming crystal.
	shard_wisp = ["Shard Wisp", "shardheart", 0.7, 120, 0, 16, "orbit", 3.6, "8afff0", "prism_note", "swarm"],
	prism_crawler = ["Prism Crawler", "shardheart", 1.1, 260, 4, 22, "dart", 3.8, "ff8ae0", "prism_note", "small"],
	resonance_sentinel = ["Resonance Sentinel", "shardheart", 2.4, 900, 10, 30, "stationary", 0.0, "8afff0", "prism_note", "big"],
	heart_choir = ["The Heart Choir", "shardheart", 3.5, 3000, 12, 120, "stationary", 0.0, "ff8ae0", "prism_note", "god"],
	# Hollowmoon (danger 2): bones and ghost-lights.
	lantern_ghost = ["Lantern Ghost", "hollowmoon", 1.4, 260, 2, 22, "spirit", 3.0, "7dff6a", "ghost_star", "small"],
	bone_crawler = ["Bone Crawler", "hollowmoon", 1.0, 220, 4, 22, "dart", 4.0, "c8c4b0", "ghost_star", "small"],
	grave_watcher = ["Grave Watcher", "hollowmoon", 2.6, 1000, 10, 32, "stationary", 0.0, "7dff6a", "ghost_star", "big"],
	pale_astronomer = ["The Pale Astronomer", "hollowmoon", 3.5, 3100, 11, 126, "strafe", 2.4, "b8ffe0", "ghost_star", "god"],
	# Mawgrave (danger 3): the fungal hives.
	spore_drone = ["Spore Drone", "mawgrave", 0.8, 110, 0, 16, "orbit", 3.8, "ff6ae0", "spore_bomb", "swarm"],
	hive_tender = ["Hive Tender", "mawgrave", 1.4, 300, 4, 22, "skirmish", 2.6, "7dff6a", "spore_bomb", "small"],
	fungal_brute = ["Fungal Brute", "mawgrave", 2.8, 1050, 9, 34, "chase", 1.9, "ff6ae0", "spore_bomb", "big"],
	hive_mother = ["The Hive Mother", "mawgrave", 4.5, 3400, 12, 124, "stationary", 0.0, "ff6ae0", "spore_bomb", "god"],
	# The Pale Eye (danger 3): the storm.
	storm_shard = ["Storm Shard", "pale_eye", 1.0, 160, 2, 18, "dart", 4.6, "9ab0ff", "storm_bolt", "swarm"],
	obsidian_knight = ["Obsidian Knight", "pale_eye", 2.2, 700, 10, 30, "chase", 2.6, "ff4a5a", "storm_bolt", "big"],
	eye_watcher = ["Eye Watcher", "pale_eye", 1.8, 560, 6, 26, "stationary", 0.0, "ff4a5a", "storm_bolt", "small"],
	storm_warden = ["The Storm Warden", "pale_eye", 4.5, 3500, 14, 132, "strafe", 2.4, "9ab0ff", "storm_bolt", "god"],
}

## God -> the permanent stat its potion raises.
const GOD_POTIONS := {elder_thornheart = "hp", queen_lumeria = "magic", amber_sphinx = "defense", leviathan_herald = "mp",
	heart_choir = "dexterity", pale_astronomer = "speed", hive_mother = "hp", storm_warden = "attack"}

## Per planet: packs [key, members, leader, sites, respawn seconds (-1 never), obstacle or ""].
## Obstacle packs gather by that kind of the planet's obstacles (PlanetFlora).
const PLANET_PACKS := {
	verdance = [
		["glimmers", [["moss_glimmer", 4, 7]], "", 4, 150.0, ""],
		["caplings", [["capling", 2, 4]], "", 4, 150.0, "glowshroom"],
		["warden", [["capling", 2, 3]], "bark_warden", 2, 240.0, "tree_tall"],
		["god", [["moss_glimmer", 4, 6]], "elder_thornheart", 1, -1.0, "tree_round"]],
	rosamund = [
		["hoppers", [["quartz_hopper", 2, 4]], "", 4, 150.0, ""],
		["golems", [["petal_sprite", 2, 4]], "rose_golem", 3, 240.0, "crystal_cluster"],
		["god", [["petal_sprite", 5, 7]], "queen_lumeria", 1, -1.0, "crystal_cluster"]],
	amberfall = [
		["mites", [["honey_mite", 4, 7]], "", 4, 150.0, ""],
		["scarabs", [["amber_scarab", 1, 3]], "", 3, 180.0, "cactus"],
		["drakes", [["dune_drake", 1, 2]], "", 2, 240.0, ""],
		["god", [["amber_scarab", 2, 2]], "amber_sphinx", 1, -1.0, "pillar"]],
	tidewell = [
		["crabs", [["surf_crab", 3, 5]], "", 4, 150.0, ""],
		["sirens", [["tide_siren", 1, 2]], "", 3, 180.0, "palm"],
		["kelp", [["surf_crab", 1, 2]], "kelp_horror", 3, 240.0, "rock"],
		["god", [["tide_siren", 2, 2]], "leviathan_herald", 1, -1.0, "palm"]],
	shardheart = [
		["crawlers", [["prism_crawler", 2, 4]], "", 4, 150.0, ""],
		["sentinels", [["shard_wisp", 3, 5]], "resonance_sentinel", 4, 240.0, "crystal_cluster"],
		["god", [["shard_wisp", 6, 8]], "heart_choir", 1, -1.0, "crystal_cluster"]],
	hollowmoon = [
		["crawlers", [["bone_crawler", 3, 5]], "", 4, 150.0, ""],
		["ghosts", [["lantern_ghost", 2, 3]], "", 3, 180.0, "dead_tree"],
		["watchers", [["bone_crawler", 2, 2]], "grave_watcher", 3, 240.0, "ruin_wall"],
		["god", [["lantern_ghost", 3, 3]], "pale_astronomer", 1, -1.0, "obelisk"]],
	mawgrave = [
		["tenders", [["spore_drone", 2, 3]], "hive_tender", 4, 180.0, "glowshroom"],
		["brutes", [["fungal_brute", 1, 2]], "", 3, 240.0, ""],
		["god", [["spore_drone", 3, 4]], "hive_mother", 1, -1.0, "glowshroom"]],
	pale_eye = [
		["shards", [["storm_shard", 3, 5]], "", 4, 150.0, ""],
		["knights", [["obsidian_knight", 1, 2]], "", 3, 240.0, ""],
		["watchers", [["storm_shard", 2, 2]], "eye_watcher", 3, 240.0, "obelisk"],
		["god", [["obsidian_knight", 2, 2]], "storm_warden", 1, -1.0, "obelisk"]],
}

static func build(defs: Dictionary) -> void:
	for id: String in CAST:
		var c: Array = CAST[id]
		var planet := SpaceLayout.planet(str(c[1]))
		var tier: Dictionary = TIERS[int(planet.get("danger", 0))]
		var kind := str(c[10])
		var d := EnemyDef.new()
		d.id = id
		d.enemy_name = c[0]
		d.model = id
		d.body_height = c[2]
		d.hp = int(float(c[3])*float(tier.hp))
		d.defense = int(c[4])+int(tier.defense)
		d.xp = maxi(8, int(d.hp/10.0))*(3 if kind=="god" else 1)
		d.behavior = c[6]
		d.move_speed = c[7]
		d.hit_radius = 0.35 if d.body_height<1.0 else 0.5 if d.body_height<2.0 else 0.8 if kind!="god" else 1.3
		d.keep_distance = 7.0 if kind=="god" else 5.0
		d.aggro_radius = 17.0 if kind=="god" else 14.0
		d.lose_radius = 28.0 if kind=="god" else 22.0
		d.wander_radius = 3.0
		d.follows_leader = kind=="swarm" or d.behavior=="orbit"
		d.orbit_radius = 3.5 if kind=="swarm" else 3.0
		d.spawn_anim = "rise" if str(c[1]) in ["hollowmoon", "mawgrave", "pale_eye"] else "pop"
		d.dust_color = Color(str(c[8])).darkened(0.4)
		d.is_god = kind=="god"
		if d.is_god: d.god_potion_stats.assign([GOD_POTIONS[id]])
		var damage := int(float(c[5])*float(tier.damage))
		d.attacks.assign(_attacks(id, kind, damage, Color(str(c[8])), "boss_projectiles/"+str(c[9])))
		d.loot.assign(_loot(kind, tier.tiers))
		# The planet's stronghold key: its god carries one often, its brutes rarely.
		var fort: Dictionary = SpaceLayout.FORTS.get(str(c[1]), {})
		if not fort.is_empty() and kind in ["god", "big"]:
			d.loot.append({item = fort.key, chance = 0.5 if kind=="god" else 0.04})
		defs[id] = d

## A base projectile in the planet's colour and voxel model.
static func _shot(damage: int, color: Color, model: String, extra := {}) -> Dictionary:
	var shot := {style = "orb", color = color, voxel_model = model, authored_projectile = true, pixel_projectile = true,
		projectile_glow = 0.9, damage_min = damage, damage_max = damage+int(damage*0.15)+2, speed = 7.5, range = 13.0,
		size = 0.7, radius = 0.16, cooldown = 2.4, windup = 0.55, recover = 0.3}
	return shot.merged(extra, true)

## Every creature fights its own way; gods are bullet-heavy with telegraphed patterns.
static func _attacks(id: String, kind: String, damage: int, color: Color, model: String) -> Array:
	match id:
		"moss_glimmer", "honey_mite":
			return [_shot(damage, color, model, {pattern = "aimed", speed = 9.0, range = 9.0, size = 0.45, cooldown = 1.6, windup = 0.3})]
		"petal_sprite", "shard_wisp", "spore_drone":
			return [_shot(damage, color, model, {pattern = "spread", count = 2, spread_deg = 18.0, speed = 8.0, range = 10.0, size = 0.45, cooldown = 2.2})]
		"storm_shard":
			return [_shot(damage, color, model, {style = "bolt", pattern = "burst", count = 2, interval = 0.12, speed = 12.0, range = 11.0, size = 0.55, cooldown = 1.8})]
		"capling", "hive_tender":
			return [_shot(damage, color, model, {pattern = "spread", count = 3, spread_deg = 20.0, speed = 6.5, cooldown = 2.4, from_hand = true})]
		"quartz_hopper", "prism_crawler":
			return [_shot(damage, color, model, {style = "shard", pattern = "spread", count = 3, spread_deg = 14.0, speed = 10.0, range = 11.0, cooldown = 2.0})]
		"amber_scarab":
			return [_shot(damage, color, model, {style = "comet", pattern = "burst", count = 3, interval = 0.2, speed = 8.5, cooldown = 2.6})]
		"surf_crab":
			return [_shot(damage, color, model, {pattern = "cross", spread_deg = 10.0, speed = 6.5, range = 10.0, cooldown = 2.4})]
		"tide_siren":
			return [_shot(damage, color, model, {style = "needle", pattern = "sweep", count = 7, arc_deg = 70.0, interval = 0.08, speed = 10.5, cooldown = 3.0, root = true})]
		"lantern_ghost":
			return [_shot(damage, color, model, {pattern = "ring", count = 6, speed = 5.5, range = 10.0, cooldown = 3.2, windup = 0.7})]
		"bone_crawler":
			return [_shot(damage, color, model, {style = "needle", pattern = "spread", count = 2, spread_deg = 10.0, speed = 11.0, range = 8.0, cooldown = 1.7})]
		"eye_watcher":
			return [_shot(damage, color, model, {style = "bolt", pattern = "ring", count = 8, speed = 7.0, cooldown = 3.0, windup = 0.9}),
				_shot(damage, color, model, {style = "bolt", pattern = "burst", count = 4, interval = 0.15, speed = 11.0, cooldown = 2.2})]
		"bark_warden", "rose_golem", "fungal_brute":
			return [_shot(damage, color, model, {pattern = "spread", count = 5, spread_deg = 13.0, speed = 7.0, cooldown = 2.8, windup = 0.85, root = true}),
				{pattern = "shockwave", range = 7.5, cooldown = 6.5, windup = 1.1, root = true, recover = 0.5, color = color,
					ripple = {radius = 6.0, speed = 4.5, damage_min = damage, damage_max = damage+8}}]
		"dune_drake", "obsidian_knight":
			return [_shot(damage, color, model, {style = "crescent" if id=="obsidian_knight" else "comet", pattern = "spread", count = 3, spread_deg = 24.0, speed = 9.0, range = 9.0, cooldown = 2.2, root = true}),
				_shot(damage, color, model, {pattern = "burst", count = 4, interval = 0.14, speed = 10.0, cooldown = 3.4})]
		"kelp_horror", "resonance_sentinel", "grave_watcher":
			return [_shot(damage, color, model, {pattern = "ring", count = 10, speed = 6.0, range = 14.0, cooldown = 3.2, windup = 0.8}),
				_shot(damage, color, model, {style = "needle" if id=="grave_watcher" else "shard", pattern = "cross", spread_deg = 12.0, speed = 9.5, cooldown = 2.4})]
	# Gods: dense, telegraphed bullet patterns, each with a signature.
	var big := _shot(damage, color, model, {size = 1.1, radius = 0.22, speed = 6.5, range = 16.0, windup = 0.9, root = true, recover = 0.5, from_hand = true})
	var fast := _shot(int(damage*0.8), color, model, {size = 0.75, speed = 10.5, range = 15.0, windup = 0.6})
	var attacks: Array = [
		big.merged({pattern = "ring", count = 16, cooldown = 3.6}, true),
		fast.merged({pattern = "sweep", count = 12, arc_deg = 110.0, interval = 0.07, cooldown = 4.2}, true),
		fast.merged({pattern = "burst", count = 6, interval = 0.12, cooldown = 2.8}, true)]
	match id:
		"queen_lumeria", "heart_choir":
			attacks.append(big.merged({pattern = "cross", spread_deg = 14.0, cooldown = 2.2, windup = 0.5}, true))
		"amber_sphinx", "storm_warden":
			attacks.append({pattern = "shockwave", range = 7.5, cooldown = 7.0, windup = 1.2, root = true, recover = 0.6, color = color,
				ripple = {radius = 9.0, speed = 5.0, damage_min = damage, damage_max = damage+15}})
		"hive_mother":
			attacks.append({pattern = "summon", range = 22.0, minion = "spore_drone", count = 3, max = 8, cooldown = 9.0, windup = 1.0})
		"elder_thornheart":
			attacks.append({pattern = "summon", range = 22.0, minion = "moss_glimmer", count = 2, max = 7, cooldown = 10.0, windup = 0.8})
		"pale_astronomer", "leviathan_herald":
			attacks.append(big.merged({pattern = "spread", count = 7, spread_deg = 12.0, cooldown = 3.0}, true))
	return attacks

## Loot by kind and the planet's gear tiers; most drop refills, gods the potion.
static func _loot(kind: String, tiers: Array) -> Array:
	match kind:
		"swarm":
			return [{item = "elixir_hp", chance = 0.12}, {pool = {tier = tiers[0]}, chance = 0.08}, {pool = {tier = tiers[1]}, chance = 0.03}]
		"small":
			return [{item = "elixir_hp", chance = 0.3}, {item = "elixir_mp", chance = 0.15}, {pool = {tier = tiers[0]}, chance = 0.14},
				{pool = {tier = tiers[1]}, chance = 0.08}, {pool = {tier = tiers[2]}, chance = 0.01}]
		"big":
			return [{item = "elixir_hp", chance = 0.45}, {item = "elixir_mp", chance = 0.35}, {pool = {tier = tiers[1]}, chance = 0.2},
				{pool = {tier = tiers[2]}, chance = 0.05}]
	return [{item = "elixir_hp", chance = 0.6}, {item = "elixir_mp", chance = 0.6}, {biome_stat = true, chance = 0.35},
		{pool = {tier = tiers[1]}, chance = 0.2}, {pool = {tier = tiers[2]}, chance = 0.08}, {item = "backpack", chance = 0.02}]
