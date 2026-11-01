class_name Enemies
## The bestiary: every enemy type and every pack (group) they spawn in.
##
## A pack is what the world places. Biomes list the packs that live in them
## (BiomeDef.enemy_packs). Pack definition:
##   members        [{enemy, min, max, chance}]: rolled from the site's seed;
##                  an entry with a chance (0..1) is only added that often
##   leader         {enemy, min_members}: added when the pack is big enough;
##                  members with follows_leader stay near it
##   respawn_time   seconds before a wiped-out pack comes back;
##                  -1 = never (the realm only ever has that many)
##   activate_radius  the pack appears when the player comes this close
##
## Packs that live at a structure (crabs, spirits, the Blue Dragon) are placed
## by the structure (BiomeDef.features packs); the rest spread over a biome
## (BiomeDef.enemy_packs).
##
## Gods (spirits, the blue genie) are regular enemies, just far tougher, with
## a chance at personal loot: stat elixirs and better graded items, in a blue
## bag. Bosses are BossDefs (see Boss).

const STAT_ELIXIR_IDS := ["elixir_of_attack", "elixir_of_defense", "elixir_of_speed", "elixir_of_dexterity",
		"elixir_of_magic", "elixir_of_hp", "elixir_of_mp"]

static var _defs := {}
## Pack definitions replaced by the server's spawn config (id -> pack).
static var pack_overrides := {}


static func get_def(id: String) -> EnemyDef:
	if _defs.is_empty():
		_build()
	return _defs[id]


static func all_ids() -> Array:
	if _defs.is_empty():
		_build()
	return _defs.keys()


static func pack(id: String) -> Dictionary:
	return pack_overrides[id] if pack_overrides.has(id) else PACKS[id]


const PACKS := {
	tide_heralds = {members = [{enemy = "genie_blue", min = 2, max = 3}, {enemy = "tide_snail", min = 2, max = 3}], respawn_time = -1.0, activate_radius = 30.0},
	spire_keeper = {members = [], leader = {enemy = "spire_keeper", min_members = 0}, respawn_time = -1.0, activate_radius = 34.0},
	dark_stalkers = {members = [{enemy = "gloam_bat", min = 2, max = 3}, {enemy = "bile_bandit", min = 2, max = 3}], respawn_time = -1.0, activate_radius = 30.0},
	hollow_ambush = {members = [{enemy = "gloam_bat", min = 3, max = 3}, {enemy = "bile_bandit", min = 3, max = 3}], respawn_time = -1.0, activate_radius = 30.0},
	goblin_pack = {
		members = [{enemy = "goblin", min = 3, max = 10}],
		leader = {enemy = "goblin_master", min_members = 4},
		respawn_time = 120.0,
		activate_radius = 34.0,
	},
	# Scorpions hunt alone, now and then in pairs.
	sand_scorpion_pack = {
		members = [{enemy = "sand_scorpion", min = 1, max = 1},
				{enemy = "sand_scorpion", min = 1, max = 1, chance = 0.2}],
		respawn_time = 150.0,
		activate_radius = 30.0,
	},
	black_scorpion_pack = {
		members = [{enemy = "black_scorpion", min = 1, max = 1}],
		respawn_time = 300.0,
		activate_radius = 30.0,
	},
	# A cluster of crabs scuttling around the Tide Rocks.
	crab_pack = {
		members = [{enemy = "crab", min = 3, max = 6}],
		respawn_time = 120.0,
		activate_radius = 30.0,
	},
	green_dragon_pack = {
		members = [{enemy = "green_dragon", min = 1, max = 1},
				{enemy = "green_dragon", min = 1, max = 1, chance = 0.3}],
		respawn_time = 240.0,
		activate_radius = 34.0,
	},
	# A spirit with its ring of stars and a few genies at its side.
	spirit_brown_pack = {
		members = [{enemy = "star", min = 5, max = 10}, {enemy = "genie_brown", min = 1, max = 4}],
		leader = {enemy = "spirit_brown", min_members = 0},
		respawn_time = -1.0,
		activate_radius = 36.0,
	},
	spirit_blue_pack = {
		members = [{enemy = "star", min = 5, max = 10}, {enemy = "genie_blue", min = 1, max = 4}],
		leader = {enemy = "spirit_blue", min_members = 0},
		respawn_time = -1.0,
		activate_radius = 36.0,
	},
	spirit_purple_pack = {
		members = [{enemy = "star", min = 5, max = 10}, {enemy = "genie_purple", min = 1, max = 4}],
		leader = {enemy = "spirit_purple", min_members = 0},
		respawn_time = -1.0,
		activate_radius = 36.0,
	},
	blue_genie_pack = {
		members = [{enemy = "star", min = 3, max = 6}],
		leader = {enemy = "blue_genie", min_members = 0},
		respawn_time = -1.0,
		activate_radius = 36.0,
	},
	blue_dragon_lair = {
		members = [],
		leader = {enemy = "blue_dragon", min_members = 0},
		respawn_time = -1.0,
		activate_radius = 60.0,
	},
	# The other stronghold bosses: one each, never respawning once killed.
	rimeheart_lair = {members = [], leader = {enemy = "rimeheart_prism", min_members = 0}, respawn_time = -1.0, activate_radius = 60.0},
	vharok_lair = {members = [], leader = {enemy = "vharok", min_members = 0}, respawn_time = -1.0, activate_radius = 60.0},
	scarab_lair = {members = [], leader = {enemy = "scarab_regent", min_members = 0}, respawn_time = -1.0, activate_radius = 60.0},
	hollow_crown_lair = {members = [], leader = {enemy = "hollow_crown", min_members = 0}, respawn_time = -1.0, activate_radius = 60.0},
	# Fortress defenders wake only after crossing inside the curtain walls.
	# Separate sites keep the boss's existing lair, home and activation intact.
	vharok_guards = {members = [{enemy = "cinder_beetle", min = 2, max = 3}, {enemy = "ember_mite", min = 3, max = 4}], respawn_time = -1.0, activate_radius = 30.0},
	rimeheart_guards = {members = [{enemy = "rime_skitter", min = 3, max = 4}, {enemy = "snow_wisp", min = 2, max = 3}], respawn_time = -1.0, activate_radius = 30.0},
	blue_dragon_guards = {members = [{enemy = "genie_blue", min = 2, max = 2}, {enemy = "star", min = 3, max = 5}], respawn_time = -1.0, activate_radius = 30.0},
	scarab_guards = {members = [{enemy = "sand_scorpion", min = 2, max = 3}, {enemy = "dune_crawler", min = 3, max = 4}], respawn_time = -1.0, activate_radius = 30.0},
	hollow_crown_guards = {members = [{enemy = "genie_purple", min = 1, max = 2}, {enemy = "gloam_bat", min = 4, max = 5}], respawn_time = -1.0, activate_radius = 30.0},
	# Campaign packs: placed by CampaignServer at a quest's anchor, never respawning.
	thornmaw = {members = [], leader = {enemy = "thornmaw_bloom", min_members = 0}, respawn_time = -1.0, activate_radius = 26.0},
	story_goblin = {members = [], leader = {enemy = "goblin_thief", min_members = 0}, respawn_time = -1.0, activate_radius = 30.0},
	dune_raiders = {members = [{enemy = "sand_scorpion", min = 3, max = 3}, {enemy = "dune_crawler", min = 2, max = 2}], respawn_time = -1.0, activate_radius = 28.0},
	ash_cult = {members = [{enemy = "ember_mite", min = 3, max = 3}, {enemy = "cinder_beetle", min = 3, max = 3}], respawn_time = -1.0, activate_radius = 28.0},
	mountain_guard = {members = [{enemy = "rime_skitter", min = 2, max = 2}, {enemy = "snow_wisp", min = 2, max = 2}], respawn_time = -1.0, activate_radius = 28.0},
	lily_eaters = {members = [{enemy = "thorn_hopper", min = 4, max = 4}, {enemy = "bramble_fox", min = 2, max = 2}], respawn_time = -1.0, activate_radius = 26.0},
	sporeback_pack = {members = [{enemy = "sporeback", min = 2, max = 4}], respawn_time = 150.0, activate_radius = 32.0},
	thorn_hopper_pack = {members = [{enemy = "thorn_hopper", min = 2, max = 4}], respawn_time = 150.0, activate_radius = 32.0},
	cinder_beetle_pack = {members = [{enemy = "cinder_beetle", min = 1, max = 3}], respawn_time = 180.0, activate_radius = 32.0},
	frost_moth_pack = {members = [{enemy = "frost_moth", min = 1, max = 2}], respawn_time = -1.0, activate_radius = 36.0},
	ruin_watcher_pack = {members = [{enemy = "ruin_watcher", min = 1, max = 2}], respawn_time = -1.0, activate_radius = 36.0},

	basalt_bulwark_pack = {members = [{enemy = "ember_mite", min = 2, max = 3}], leader = {enemy = "basalt_bulwark", min_members = 0}, respawn_time = -1.0, activate_radius = 36.0},
	furnace_maw_pack = {members = [{enemy = "furnace_maw", min = 1, max = 1}], respawn_time = -1.0, activate_radius = 36.0},
	cinder_oracle_pack = {members = [{enemy = "ember_mite", min = 2, max = 3}], leader = {enemy = "cinder_oracle", min_members = 0}, respawn_time = -1.0, activate_radius = 36.0},
	rime_stag_pack = {members = [{enemy = "rime_skitter", min = 2, max = 3}], leader = {enemy = "rime_stag", min_members = 0}, respawn_time = -1.0, activate_radius = 36.0},
	glacier_hermit_pack = {members = [{enemy = "rime_skitter", min = 2, max = 3}], leader = {enemy = "glacier_hermit", min_members = 0}, respawn_time = -1.0, activate_radius = 36.0},
	hail_harrier_pack = {members = [{enemy = "snow_wisp", min = 2, max = 3}], leader = {enemy = "hail_harrier", min_members = 0}, respawn_time = -1.0, activate_radius = 36.0},
	ember_mite_pack = {members = [{enemy = "ember_mite", min = 2, max = 4}], respawn_time = 180.0, activate_radius = 30.0},
	rime_skitter_pack = {members = [{enemy = "rime_skitter", min = 2, max = 4}], respawn_time = 180.0, activate_radius = 30.0},
	snow_wisp_pack = {members = [{enemy = "snow_wisp", min = 2, max = 4}], respawn_time = 180.0, activate_radius = 30.0},

	# Realm expansion 03: finite gods and ordinary fauna.
	slag_seraph_pack = {members = [{enemy = "slag_seraph", min = 1, max = 1}], respawn_time = -1.0, activate_radius = 36.0},
	obsidian_ram_pack = {members = [{enemy = "obsidian_ram", min = 1, max = 1}], respawn_time = -1.0, activate_radius = 36.0},
	ember_lich_pack = {members = [{enemy = "ember_lich", min = 1, max = 1}], respawn_time = -1.0, activate_radius = 36.0},
	aurora_sentinel_pack = {members = [{enemy = "aurora_sentinel", min = 1, max = 1}], respawn_time = -1.0, activate_radius = 36.0},
	hoarfrost_owl_pack = {members = [{enemy = "hoarfrost_owl", min = 1, max = 1}], respawn_time = -1.0, activate_radius = 36.0},
	icebound_colossus_pack = {members = [{enemy = "icebound_colossus", min = 1, max = 1}], respawn_time = -1.0, activate_radius = 36.0},
	prism_ray_pack = {members = [{enemy = "prism_ray", min = 1, max = 1}], respawn_time = -1.0, activate_radius = 36.0},
	runic_archivist_pack = {members = [{enemy = "runic_archivist", min = 1, max = 1}], respawn_time = -1.0, activate_radius = 36.0},
	azure_medusa_pack = {members = [{enemy = "azure_medusa", min = 1, max = 1}], respawn_time = -1.0, activate_radius = 36.0},
	sun_jackal_pack = {members = [{enemy = "sun_jackal", min = 1, max = 1}], respawn_time = -1.0, activate_radius = 36.0},
	dune_monolith_pack = {members = [{enemy = "dune_monolith", min = 1, max = 1}], respawn_time = -1.0, activate_radius = 36.0},
	glass_scorpion_pack = {members = [{enemy = "glass_scorpion", min = 1, max = 1}], respawn_time = -1.0, activate_radius = 36.0},
	umbral_reaper_pack = {members = [{enemy = "umbral_reaper", min = 1, max = 1}], respawn_time = -1.0, activate_radius = 36.0},
	amethyst_widow_pack = {members = [{enemy = "amethyst_widow", min = 1, max = 1}], respawn_time = -1.0, activate_radius = 36.0},
	nightbell_idol_pack = {members = [{enemy = "nightbell_idol", min = 1, max = 1}], respawn_time = -1.0, activate_radius = 36.0},
	bramble_fox_pack = {members = [{enemy = "bramble_fox", min = 2, max = 3}], respawn_time = 150.0, activate_radius = 32.0},
	moss_tortoise_pack = {members = [{enemy = "moss_tortoise", min = 1, max = 2}], respawn_time = 180.0, activate_radius = 32.0},
	vine_mantis_pack = {members = [{enemy = "vine_mantis", min = 2, max = 3}], respawn_time = 180.0, activate_radius = 32.0},
	tide_snail_pack = {members = [{enemy = "tide_snail", min = 2, max = 4}], respawn_time = 120.0, activate_radius = 32.0},
	dune_crawler_pack = {members = [{enemy = "dune_crawler", min = 2, max = 4}], respawn_time = 180.0, activate_radius = 32.0},
	gloam_bat_pack = {members = [{enemy = "gloam_bat", min = 3, max = 5}], respawn_time = 150.0, activate_radius = 32.0},
	bile_bandit_patrol = {members = [{enemy = "bile_bandit", min = 2, max = 2}], leader = {enemy = "bile_bandit", min_members = 0}, patrol_radius = 18.0, respawn_time = 240.0, activate_radius = 40.0},

}


## Every stat elixir at `chance` each (gods and bosses).
static func _stat_elixirs(chance: float) -> Array:
	return STAT_ELIXIR_IDS.map(func(id: String) -> Dictionary: return {item = id, chance = chance})


static func _build() -> void:
	var goblin := EnemyDef.new()
	goblin.id = "goblin"
	goblin.enemy_name = "Goblin"
	goblin.model = "goblin"
	goblin.hp = 75
	goblin.defense = 0
	goblin.xp = 10
	goblin.behavior = "skirmish"
	goblin.move_speed = 4.2
	goblin.keep_distance = 6.5
	goblin.follows_leader = true
	goblin.loot.assign([
		{item = "elixir_hp", chance = 0.4},
		{item = "elixir_mp", chance = 0.15},
		{pool = {tier = 2, slots = ["weapon", "armor"]}, chance = 0.1},
	])
	goblin.attacks.assign([{
		damage_min = 10, damage_max = 15, style = "pellet",
		color = Color(0.62, 0.8, 0.3), size = 1.0, speed = 11.0, range = 9.5,
		pattern = "aimed", count = 1, cooldown = 1.5, windup = 0.25,
	}])
	_defs[goblin.id] = goblin
	# The Lily Thief's goblin: its own id, so it comes while goblins are held back.
	var thief := goblin.duplicate(true) as EnemyDef
	thief.id = "goblin_thief"
	thief.enemy_name = "Goblin Thief"
	thief.hp = goblin.hp * 4
	thief.loot.assign([])
	_defs[thief.id] = thief

	var master := EnemyDef.new()
	master.id = "goblin_master"
	master.portal_drop = {dungeon = "goblins_cave", chance = 0.2}
	master.enemy_name = "Goblin Master"
	master.model = "goblin_master"
	master.body_height = 1.875
	master.hp = 150
	master.defense = 15
	master.xp = 30
	master.behavior = "skirmish"
	master.move_speed = 2.8
	master.keep_distance = 7.5
	master.aggro_radius = 15.0
	master.loot.assign([
		{item = "elixir_hp", chance = 0.5},
		{item = "elixir_mp", chance = 0.25},
		{pool = {tier = 3}, chance = 0.03},
		{pool = {tier = 2, slots = ["weapon", "armor"]}, chance = 0.13},
		{pool = {tier = 2, slots = ["spell"]}, chance = 0.07},
		{item = "backpack", chance = 0.02},
	])
	master.attacks.assign([{
		damage_min = 15, damage_max = 25, style = "bolt",
		color = Color(1.0, 0.45, 0.25), size = 1.3, speed = 10.0, range = 10.5,
		pattern = "spread", count = 3, spread_deg = 14.0, cooldown = 1.9, windup = 0.4,
	}])
	_defs[master.id] = master

	# Desert scorpions lie buried in the sand and burst out when you come
	# near. They scuttle around you, stop, and flick shots off their tail.
	var scorpion := EnemyDef.new()
	scorpion.id = "sand_scorpion"
	scorpion.enemy_name = "Sand Scorpion"
	scorpion.model = "sand_scorpion"
	scorpion.body_height = 1.0
	scorpion.hit_radius = 0.85
	scorpion.hp = 220
	scorpion.defense = 6
	scorpion.xp = 35
	scorpion.behavior = "skirmish"
	scorpion.move_speed = 4.6
	scorpion.keep_distance = 6.0
	scorpion.aggro_radius = 9.0
	scorpion.lose_radius = 20.0
	scorpion.spawn_anim = "burrow"
	scorpion.dust_color = Color(0.88, 0.74, 0.52)
	scorpion.loot.assign([
		{item = "elixir_hp", chance = 0.4},
		{item = "elixir_mp", chance = 0.2},
		{pool = {tier = 2, slots = ["weapon", "armor"]}, chance = 0.12},
		{pool = {tier = 3, slots = ["weapon", "armor"]}, chance = 0.04},
		{item = "backpack", chance = 0.01},
	])
	scorpion.attacks.assign([{
		damage_min = 20, damage_max = 28, style = "bolt",
		color = Color(0.78, 0.92, 0.25), size = 1.2, speed = 12.0, range = 10.0,
		pattern = "spread", count = 3, spread_deg = 10.0, cooldown = 1.8, windup = 0.55,
		root = true, recover = 0.35, from_hand = true,
	}])
	_defs[scorpion.id] = scorpion

	# Rarer and bigger: also hurls magic orbs that burst into warp ripples.
	var black := EnemyDef.new()
	black.id = "black_scorpion"
	black.enemy_name = "Black Scorpion"
	black.model = "black_scorpion"
	black.model_scale = 1.2
	black.body_height = 1.0
	black.hit_radius = 0.85
	black.hp = 625
	black.defense = 15
	black.xp = 110
	black.behavior = "skirmish"
	black.move_speed = 4.0
	black.keep_distance = 7.0
	black.aggro_radius = 11.0
	black.lose_radius = 22.0
	black.spawn_anim = "burrow"
	black.dust_color = Color(0.88, 0.74, 0.52)
	black.loot.assign([
		{item = "elixir_mp", chance = 1.0},  # always drops a magic elixir
		{item = "elixir_hp", chance = 0.5},
		{pool = {tier = 3}, chance = 0.12},
		{pool = {tier = 4, slots = ["weapon", "armor"]}, chance = 0.05},
		{pool = {tier = 4, slots = ["spell"]}, chance = 0.02},
		{item = "backpack", chance = 0.04},
	])
	black.attacks.assign([{
		damage_min = 26, damage_max = 34, style = "bolt",
		color = Color(0.55, 0.3, 0.8), size = 1.2, speed = 12.0, range = 10.0,
		pattern = "spread", count = 2, spread_deg = 12.0, cooldown = 1.7, windup = 0.45,
		root = true, recover = 0.3, from_hand = true,
	}, {
		damage_min = 34, damage_max = 44, style = "orb",
		color = Color(0.72, 0.35, 1.0), size = 1.0, speed = 9.0, range = 11.0,
		pattern = "aimed", count = 1, cooldown = 3.2, windup = 0.75,
		root = true, recover = 0.45, from_hand = true,
		magic = true, ripple = {radius = 3.2, speed = 6.5, damage_min = 18, damage_max = 26},
	}])
	_defs[black.id] = black

	_build_shore_and_jungle()
	_build_spirits()
	_build_common_batch()
	_build_god_batch_02()
	_build_blue_dragon()
	RealmBosses.build(_defs)
	CastleEnemies.build(_defs)
	DungeonEnemies.build(_defs)
	RealmEnemyExpansion.build(_defs, _god_loot(), _medium_loot())
	CourtEnemies.build(_defs)
	BlueDungeonEnemies.build(_defs)
	_defs["sun_jackal"].portal_drop = {dungeon = "sunken_court", chance = 0.15}
	_defs["furnace_maw"].portal_drop = {dungeon = "cinder_depths", chance = 0.15}


## Crabs on the shore, green dragons in the jungle.
static func _build_shore_and_jungle() -> void:
	var crab := EnemyDef.new()
	crab.id = "crab"
	crab.enemy_name = "Shore Crab"
	crab.model = "crab"
	crab.body_height = 0.8
	crab.hit_radius = 0.6
	crab.hp = 180
	crab.defense = 4
	crab.xp = 18
	crab.behavior = "spirit"  # crabs scuttle sideways
	crab.move_speed = 3.6
	crab.keep_distance = 5.0
	crab.aggro_radius = 11.0
	crab.attacks.assign([{
		damage_min = 15, damage_max = 22, style = "pellet",
		color = Color(0.7, 0.92, 1.0), size = 1.1, speed = 9.0, range = 8.0,
		pattern = "spread", count = 3, spread_deg = 14.0, cooldown = 1.7, windup = 0.3,
	}])
	crab.loot.assign([
		{item = "elixir_hp", chance = 0.3},
		{item = "elixir_mp", chance = 0.12},
		{pool = {tier = 2, slots = ["weapon", "armor"]}, chance = 0.06},
	])
	_defs[crab.id] = crab

	# Small but fierce: every fireball hits for 55.
	var dragon := EnemyDef.new()
	dragon.id = "green_dragon"
	dragon.enemy_name = "Green Dragon"
	dragon.model = "green_dragon"
	dragon.body_height = 1.6
	dragon.hit_radius = 0.8
	dragon.hp = 1300
	dragon.defense = 12
	dragon.xp = 160
	dragon.behavior = "skirmish"
	dragon.move_speed = 4.4
	dragon.keep_distance = 7.5
	dragon.aggro_radius = 13.0
	dragon.lose_radius = 24.0
	dragon.attacks.assign([{
		damage_min = 55, damage_max = 55, style = "fireball",
		color = Color(1.0, 0.5, 0.12), size = 1.4, speed = 10.0, range = 12.0,
		pattern = "aimed", count = 1, cooldown = 1.4, windup = 0.35, anim = "flap",
	}, {
		damage_min = 55, damage_max = 55, style = "fireball",
		color = Color(1.0, 0.5, 0.12), size = 1.2, speed = 9.0, range = 11.0,
		pattern = "spread", count = 3, spread_deg = 16.0, cooldown = 4.0, windup = 0.6, root = true,
	}])
	dragon.loot.assign([
		{item = "elixir_hp", chance = 0.5},
		{item = "elixir_mp", chance = 0.3},
		{pool = {tier = 3}, chance = 0.1},
		{pool = {tier = 4, slots = ["weapon", "armor"]}, chance = 0.04},
		{item = "backpack", chance = 0.015},
	])
	_defs[dragon.id] = dragon


## Spirits (gods) in the ruins, their genies and stars, and Bluelay's blue genie.
static func _build_spirits() -> void:
	var colors := {brown = Color(1.0, 0.72, 0.38), blue = Color(0.4, 0.75, 1.0), purple = Color(0.82, 0.45, 1.0)}
	# [hp, defense, damage, xp, speed]
	var stats := {brown = [3000, 8, 150, 300, 5.0], blue = [4500, 12, 170, 450, 5.5], purple = [6500, 16, 190, 700, 6.0]}
	var names := {brown = "Brown Spirit", blue = "Blue Spirit", purple = "Purple Spirit"}
	for c in colors:
		var st: Array = stats[c]
		var spirit := EnemyDef.new()
		spirit.id = "spirit_" + c
		spirit.is_god = true
		spirit.enemy_name = names[c]
		spirit.model = "spirit_" + c
		spirit.body_height = 2.2
		spirit.hit_radius = 0.6
		spirit.hp = st[0]
		spirit.defense = st[1]
		spirit.xp = st[3]
		spirit.behavior = "spirit"
		spirit.move_speed = st[4]
		spirit.keep_distance = 7.0
		spirit.aggro_radius = 15.0
		spirit.lose_radius = 26.0
		spirit.blink = {every = [1.8, 4.0], distance = 3.5}
		spirit.attacks.assign([{
			damage_min = st[2] - 5, damage_max = st[2] + 5, style = "orb",
			color = colors[c], size = 1.0, speed = 11.0, range = 11.0,
			pattern = "cross", spread_deg = 9.0, cooldown = 1.25, windup = 0.4,
		}])
		spirit.loot.assign(_god_loot())
		_defs[spirit.id] = spirit

		# Its genies: small, quick, and they do hurt.
		var genie := EnemyDef.new()
		genie.id = "genie_" + c
		genie.enemy_name = "Genie"
		genie.model = "genie_" + c
		genie.body_height = 1.6
		genie.hit_radius = 0.45
		genie.hp = 500
		genie.defense = 4
		genie.xp = 40
		genie.behavior = "skirmish"
		genie.move_speed = 5.0
		genie.keep_distance = 5.5
		genie.follows_leader = true
		genie.attacks.assign([{
			damage_min = 24, damage_max = 32, style = "pellet",
			color = colors[c], size = 1.0, speed = 12.0, range = 9.0,
			pattern = "spread", count = 2, spread_deg = 10.0, cooldown = 1.2, windup = 0.2,
		}])
		genie.loot.assign([{item = "elixir_hp", chance = 0.25}])
		_defs[genie.id] = genie

	# Harmless stars that circle a spirit: easy elixirs.
	var star := EnemyDef.new()
	star.id = "star"
	star.enemy_name = "Star"
	star.model = "star"
	star.body_height = 1.4
	star.hit_radius = 0.4
	star.hp = 40
	star.xp = 4
	star.behavior = "orbit"
	star.move_speed = 5.0
	star.orbit_radius = 3.2
	star.orbit_speed = 1.4
	star.aggro_radius = 12.0
	star.loot.assign([{item = "elixir_hp", chance = 0.55}, {item = "elixir_mp", chance = 0.55}])
	_defs[star.id] = star

	# The blue genie: a glowing god of Bluelay.
	var blue_genie := EnemyDef.new()
	blue_genie.id = "blue_genie"
	blue_genie.is_god = true
	blue_genie.enemy_name = "Blue Genie"
	blue_genie.model = "blue_genie"
	blue_genie.model_scale = 1.15
	blue_genie.body_height = 2.4
	blue_genie.hit_radius = 0.7
	blue_genie.hp = 5000
	blue_genie.defense = 14
	blue_genie.xp = 550
	blue_genie.behavior = "spirit"
	blue_genie.move_speed = 5.5
	blue_genie.keep_distance = 7.5
	blue_genie.aggro_radius = 15.0
	blue_genie.lose_radius = 26.0
	blue_genie.blink = {every = [2.5, 5.0], distance = 4.0}
	blue_genie.attacks.assign([{
		damage_min = 165, damage_max = 185, style = "orb",
		color = Color(0.35, 0.75, 1.0), size = 1.1, speed = 10.0, range = 11.0,
		pattern = "spread", count = 3, spread_deg = 20.0, cooldown = 1.7, windup = 0.5,
	}, {
		damage_min = 145, damage_max = 165, style = "orb",
		color = Color(0.6, 0.9, 1.0), size = 0.9, speed = 8.0, range = 9.0,
		pattern = "ring", count = 8, cooldown = 4.5, windup = 0.7,
	}])
	blue_genie.loot.assign(_god_loot())
	_defs[blue_genie.id] = blue_genie


## The Blue Dragon of Bluelay, and the dragonlings he calls to his side.
static func _build_blue_dragon() -> void:
	var glow := {red = Color(1.0, 0.45, 0.35), gold = Color(1.0, 0.85, 0.35), purple = Color(0.8, 0.5, 1.0),
			pink = Color(1.0, 0.55, 0.85), cyan = Color(0.4, 0.95, 1.0), blue = Color(0.45, 0.75, 1.0)}
	for c in glow:
		var d := EnemyDef.new()
		d.id = "dragonling_" + c
		d.enemy_name = "%s Dragonling" % c.capitalize()
		d.model = "dragonling_" + c
		d.model_scale = 0.9
		d.body_height = 1.5
		d.hit_radius = 0.8
		d.hp = 2400 if c == "blue" else 3000
		d.defense = 10
		d.xp = 120
		d.behavior = "orbit" if c == "blue" else "skirmish"
		d.spawn_anim = "summon"
		d.dust_color = glow[c]
		d.move_speed = 5.5
		d.keep_distance = 7.0
		d.orbit_radius = 8.0
		d.orbit_speed = 0.8
		d.aggro_radius = 40.0
		d.lose_radius = 80.0
		d.lose_time = 9999.0
		d.attacks.assign([{
			damage_min = 32, damage_max = 40, style = "fireball",
			color = glow[c], size = 1.1, speed = 11.0, range = 16.0,
			pattern = "aimed", count = 1, cooldown = 1.1, windup = 0.2, anim = "flap",
		}])
		d.loot.assign([{item = "elixir_hp", chance = 0.4}, {item = "elixir_mp", chance = 0.4}])
		_defs[d.id] = d

	var big_fire := {
		damage_min = 70, damage_max = 85, style = "fireball",
		color = Color(0.35, 0.65, 1.0), size = 2.6, speed = 6.5, range = 22.0,
		pattern = "burst", count = 6, interval = 0.14, cooldown = 2.6, windup = 0.4, anim = "flap",
	}
	var boss := BossDef.new()
	boss.id = "blue_dragon"
	boss.enemy_name = "Blue Dragon"
	boss.model = "blue_dragon"
	boss.actor_script = "res://scripts/enemies/bosses/blue_dragon.gd"
	boss.body_height = 6.5
	boss.hit_radius = 3.4
	boss.hp = 40000
	boss.defense = 20
	boss.xp = 4000
	boss.behavior = "stationary"
	boss.move_speed = 3.0
	boss.keep_distance = 12.0
	boss.wander_radius = 0.0
	boss.leash = 9.0
	boss.aggro_radius = 24.0
	boss.lose_radius = 200.0
	boss.lose_time = 9999.0
	boss.sheds = false
	boss.loot_threshold = 0.04
	# Sleeps in an azure egg until its shell is broken.
	boss.wake_on = "shell"
	boss.shell_model = "egg_blue_dragon"
	boss.shell_hp = 2000
	boss.shell_height = 4.0
	boss.shell_radius = 1.6
	boss.burst_color = Color(0.55, 0.85, 1.0)
	boss.phases.assign([
		{  # Phase 1: five glowing dragonlings guard him; then slow, heavy fireball bursts.
			until = 0.7, defense = 20,
			summon = {enemies = ["dragonling_red", "dragonling_gold", "dragonling_purple",
					"dragonling_pink", "dragonling_cyan"], radius = 9.0},
			shielded = true, attacks = [big_fire],
		},
		{  # Phase 2: four blue dragonlings circle him and shoot while he throws
			# small fireballs; once they're down, big bursts again and he sweeps
			# from side to side.
			until = 0.3, defense = 25,
			summon = {enemies = ["dragonling_blue", "dragonling_blue", "dragonling_blue", "dragonling_blue"],
					radius = 8.0},
			shielded = true,
			attacks_shielded = [{
				damage_min = 28, damage_max = 34, style = "fireball",
				color = Color(0.45, 0.75, 1.0), size = 1.0, speed = 11.0, range = 18.0,
				pattern = "spread", count = 3, spread_deg = 12.0, cooldown = 1.1, windup = 0.2,
			}],
			attacks = [big_fire],
			after = {behavior = "strafe", move_speed = 4.5},
		},
		{  # Phase 3: weaker armor. Two wing beats send out magic, then a line
			# of blue fire sweeps across, then magic again.
			until = 0.0, defense = 5, behavior = "stationary", variant = "enraged",
			sequence = [
				{attack = _wing_beat(), then = 2.0},
				{attack = _wing_beat(), then = 1.2},
				{attack = {
					damage_min = 60, damage_max = 70, style = "fireball",
					color = Color(0.55, 0.85, 1.0), size = 3.2, speed = 9.5, range = 24.0,
					pattern = "sweep", count = 34, interval = 0.05, arc_deg = 120.0,
				}, then = 2.2},
				{attack = _wing_beat(), then = 2.5},
			],
		},
	])
	var loot := _stat_elixirs(0.5)
	loot.append_array([
		{item = "elixir_hp", chance = 1.0}, {item = "elixir_mp", chance = 1.0},
		{pool = {tier = 6}, chance = 0.5},
	])
	for item_id in Items.divine_ids_for("blue_dragon"):
		loot.append({item = item_id, chance = 0.03})
	boss.loot.assign(loot)
	_defs[boss.id] = boss


## A mighty wing beat that sends a ring of warped magic rolling out.
static func _wing_beat() -> Dictionary:
	return {
		pattern = "shockwave", anim = "flap", color = Color(0.45, 0.8, 1.0), shake = 0.45,
		ripple = {radius = 16.0, speed = 9.0, damage_min = 60, damage_max = 75, knockback = 1.3},
	}


## Realm gods: biome signature potion in its own blue bag, normal gear <= G4.
## The G5 roll is 0.1% per eligible player, and always makes a red bag.
static func _god_loot() -> Array:
	return [
		{item = "elixir_hp", chance = 0.4}, {item = "elixir_mp", chance = 0.4},
		{biome_stat = true, chance = 0.35},
		{pool = {tier = 3}, chance = 0.12}, {pool = {tier = 4}, chance = 0.10},
		{pool = {tier = 5}, chance = 0.001}, {item = "backpack", chance = 0.02},
	]


static func _medium_loot() -> Array:
	return [{item = "elixir_hp", chance = 0.35}, {item = "elixir_mp", chance = 0.2},
		{pool = {tier = 1}, chance = 0.16}, {pool = {tier = 2}, chance = 0.20},
		{pool = {tier = 3}, chance = 0.06},
		{pool = {tier = 4}, chance = 0.005}]


static func _build_common_batch() -> void:
	var spore := EnemyDef.new()
	spore.id = "sporeback"
	spore.enemy_name = "Sporeback"
	spore.model = "sporeback"
	spore.hp = 360
	spore.defense = 4
	spore.xp = 40
	spore.body_height = 1.8
	spore.hit_radius = 0.65
	spore.move_speed = 2.8
	spore.keep_distance = 6.0
	spore.attacks.assign([{
		style = "pellet", voxel_model = spore.model + "/projectile", color = Color("#b3da56"),
		pattern = "spread", count = 3, spread_deg = 16.0, damage_min = 26, damage_max = 34,
		speed = 8.5, range = 10.0, size = 0.8, cooldown = 2.1, windup = 0.6,
		root = true, recover = 0.35, from_hand = true,
	}])
	spore.loot.assign(_medium_loot())
	_defs[spore.id] = spore

	var hopper := EnemyDef.new()
	hopper.id = "thorn_hopper"
	hopper.enemy_name = "Thorn Hopper"
	hopper.model = "thorn_hopper"
	hopper.hp = 300
	hopper.defense = 3
	hopper.xp = 35
	hopper.body_height = 1.25
	hopper.hit_radius = 0.8
	hopper.behavior = "dart"
	hopper.move_speed = 4.2
	hopper.keep_distance = 6.5
	hopper.attacks.assign([{
		style = "bolt", voxel_model = hopper.model + "/projectile", color = Color("#addc41"),
		pattern = "burst", count = 2, interval = 0.22, damage_min = 24, damage_max = 32,
		speed = 12.0, range = 10.5, size = 0.8, cooldown = 2.3, windup = 0.5,
		root = true, recover = 0.35, from_hand = true,
	}])
	hopper.loot.assign(_medium_loot())
	_defs[hopper.id] = hopper

	var beetle := EnemyDef.new()
	beetle.id = "cinder_beetle"
	beetle.enemy_name = "Cinder Beetle"
	beetle.model = "cinder_beetle"
	beetle.hp = 550
	beetle.defense = 10
	beetle.xp = 55
	beetle.body_height = 1.0
	beetle.hit_radius = 0.8
	beetle.move_speed = 2.7
	beetle.keep_distance = 6.0
	beetle.attacks.assign([{
		style = "fireball", color = Color("#f4631a"), pattern = "aimed", count = 1,
		damage_min = 36, damage_max = 46, speed = 8.0, range = 10.0, size = 0.65,
		cooldown = 2.2, windup = 0.65, root = true, recover = 0.4, from_hand = true,
	}])
	beetle.loot.assign(_medium_loot())
	_defs[beetle.id] = beetle

	var moth := EnemyDef.new()
	moth.id = "frost_moth"
	moth.enemy_name = "Frost Moth"
	moth.is_god = true
	moth.model = "frost_moth"
	moth.model_scale = 1.3
	moth.hp = 3200
	moth.defense = 10
	moth.xp = 350
	moth.body_height = 1.65
	moth.hit_radius = 0.5
	moth.behavior = "strafe"
	moth.move_speed = 4.2
	moth.keep_distance = 8.0
	moth.attacks.assign([{
		style = "bolt", voxel_model = moth.model + "/projectile", color = Color("#99e7f6"),
		pattern = "spread", count = 3, spread_deg = 20.0, damage_min = 150, damage_max = 170,
		speed = 11.0, range = 13.0, size = 1.1, cooldown = 1.8, windup = 0.6,
		root = true, recover = 0.25, from_hand = true, anim = "flap",
	}])
	moth.loot.assign(_god_loot())
	_defs[moth.id] = moth

	var watcher := EnemyDef.new()
	watcher.id = "ruin_watcher"
	watcher.enemy_name = "Ruin Watcher"
	watcher.is_god = true
	watcher.model = "ruin_watcher"
	watcher.model_scale = 1.25
	watcher.hp = 4200
	watcher.defense = 16
	watcher.xp = 420
	watcher.body_height = 1.6
	watcher.hit_radius = 0.65
	watcher.behavior = "stationary"
	watcher.move_speed = 0.0
	watcher.wander_radius = 0.0
	watcher.attacks.assign([{
		style = "orb", voxel_model = watcher.model + "/projectile", color = Color("#4fc3d8"),
		pattern = "burst", count = 3, interval = 0.25, damage_min = 160, damage_max = 180,
		speed = 10.0, range = 14.0, size = 1.0, cooldown = 2.5, windup = 0.7,
		root = true, recover = 0.4, from_hand = true, magic = true,
	}, {
		style = "orb", voxel_model = watcher.model + "/projectile", color = Color("#bef2f0"),
		pattern = "ring", count = 8, damage_min = 140, damage_max = 160,
		speed = 7.0, range = 11.0, size = 0.8, cooldown = 5.0, windup = 0.9,
		root = true, recover = 0.5, from_hand = true, magic = true,
	}])
	watcher.loot.assign(_god_loot())
	_defs[watcher.id] = watcher


static func _build_god_batch_02() -> void:
	var e: EnemyDef

	e = EnemyDef.new()
	e.id = "basalt_bulwark"
	e.enemy_name = "Basalt Bulwark"
	e.model = e.id
	e.is_god = true
	e.hp = 5500
	e.defense = 28
	e.xp = 500
	e.body_height = 1.8
	e.hit_radius = 0.65
	e.behavior = "skirmish"
	e.move_speed = 2.7
	e.keep_distance = 7.0
	e.aggro_radius = 16.0
	e.attacks.assign([{
		style = "bolt", color = Color("#f46c25"),
		pattern = "spread", count = 3, spread_deg = 20.0, arc_deg = 65.0, interval = 0.18,
		damage_min = 190, damage_max = 210, speed = 9.0, range = 14.0,
		size = 1.0, cooldown = 2.2, windup = 0.7, root = true, recover = 0.85, from_hand = true,
	}])
	e.attacks[0].voxel_model = e.model + "/projectile"
	e.loot.assign(_god_loot())
	_defs[e.id] = e

	e = EnemyDef.new()
	e.id = "furnace_maw"
	e.enemy_name = "Furnace Maw"
	e.model = e.id
	e.is_god = true
	e.hp = 6500
	e.defense = 18
	e.xp = 500
	e.body_height = 1.5
	e.hit_radius = 0.85
	e.behavior = "chase"
	e.move_speed = 3.1
	e.keep_distance = 7.0
	e.aggro_radius = 16.0
	e.attacks.assign([{
		style = "fireball", color = Color("#f46c25"),
		pattern = "burst", count = 3, spread_deg = 20.0, arc_deg = 65.0, interval = 0.18,
		damage_min = 200, damage_max = 220, speed = 9.0, range = 14.0,
		size = 1.0, cooldown = 2.6, windup = 0.7, root = true, recover = 0.85, from_hand = true,
	}])
	e.loot.assign(_god_loot())
	_defs[e.id] = e

	e = EnemyDef.new()
	e.id = "cinder_oracle"
	e.enemy_name = "Cinder Oracle"
	e.model = e.id
	e.is_god = true
	e.hp = 4800
	e.defense = 14
	e.xp = 500
	e.body_height = 1.8
	e.hit_radius = 0.65
	e.behavior = "spirit"
	e.move_speed = 4.2
	e.keep_distance = 7.0
	e.aggro_radius = 16.0
	e.attacks.assign([{
		style = "bolt", color = Color("#f46c25"),
		pattern = "sweep", count = 5, spread_deg = 20.0, arc_deg = 65.0, interval = 0.18,
		damage_min = 185, damage_max = 205, speed = 9.0, range = 14.0,
		size = 1.0, cooldown = 2.7, windup = 0.7, root = true, recover = 0.85, from_hand = true,
	}])
	e.attacks[0].voxel_model = e.model + "/projectile"
	e.attacks[0].magic = true
	e.loot.assign(_god_loot())
	_defs[e.id] = e

	e = EnemyDef.new()
	e.id = "rime_stag"
	e.enemy_name = "Rime Stag"
	e.model = e.id
	e.is_god = true
	e.hp = 3800
	e.defense = 12
	e.xp = 400
	e.body_height = 2.05
	e.hit_radius = 0.65
	e.behavior = "dart"
	e.move_speed = 4.6
	e.keep_distance = 8.0
	e.aggro_radius = 16.0
	e.attacks.assign([{
		style = "bolt", color = Color("#99e7f6"),
		pattern = "spread", count = 3, spread_deg = 20.0, arc_deg = 65.0, interval = 0.18,
		damage_min = 160, damage_max = 180, speed = 11.0, range = 14.0,
		size = 1.0, cooldown = 1.9, windup = 0.7, root = true, recover = 0.85, from_hand = true,
	}])
	e.attacks[0].voxel_model = e.model + "/projectile"
	e.loot.assign(_god_loot())
	_defs[e.id] = e

	e = EnemyDef.new()
	e.id = "glacier_hermit"
	e.enemy_name = "Glacier Hermit"
	e.model = e.id
	e.is_god = true
	e.hp = 4900
	e.defense = 24
	e.xp = 400
	e.body_height = 1.6
	e.hit_radius = 0.85
	e.behavior = "skirmish"
	e.move_speed = 2.4
	e.keep_distance = 8.0
	e.aggro_radius = 16.0
	e.attacks.assign([{
		style = "bolt", color = Color("#99e7f6"),
		pattern = "burst", count = 2, spread_deg = 20.0, arc_deg = 65.0, interval = 0.18,
		damage_min = 170, damage_max = 190, speed = 11.0, range = 14.0,
		size = 1.0, cooldown = 2.2, windup = 0.7, root = true, recover = 0.85, from_hand = true,
	}])
	e.attacks[0].voxel_model = e.model + "/projectile"
	e.loot.assign(_god_loot())
	_defs[e.id] = e

	e = EnemyDef.new()
	e.id = "hail_harrier"
	e.enemy_name = "Hail Harrier"
	e.model = e.id
	e.is_god = true
	e.hp = 3400
	e.defense = 10
	e.xp = 400
	e.body_height = 1.8
	e.hit_radius = 0.65
	e.behavior = "strafe"
	e.move_speed = 5.1
	e.keep_distance = 8.0
	e.aggro_radius = 16.0
	e.attacks.assign([{
		style = "bolt", color = Color("#99e7f6"),
		pattern = "sweep", count = 5, spread_deg = 20.0, arc_deg = 65.0, interval = 0.18,
		damage_min = 155, damage_max = 175, speed = 11.0, range = 14.0,
		size = 1.0, cooldown = 2.4, windup = 0.7, root = true, recover = 0.85, from_hand = true,
	}])
	e.attacks[0].voxel_model = e.model + "/projectile"
	e.attacks[0].anim = "flap"
	e.loot.assign(_god_loot())
	_defs[e.id] = e

	e = EnemyDef.new()
	e.id = "ember_mite"
	e.enemy_name = "Ember Mite"
	e.model = e.id
	e.hp = 220
	e.defense = 3
	e.xp = 25
	e.body_height = 0.8
	e.hit_radius = 0.4
	e.behavior = "dart"
	e.move_speed = 4.2
	e.keep_distance = 5.0
	e.follows_leader = true
	e.orbit_radius = 3.0
	e.attacks.assign([{style = "bolt", voxel_model = e.model + "/projectile", color = Color("#ffb34a"),
		pattern = "aimed", count = 1, damage_min = 32, damage_max = 44, speed = 10.0,
		range = 9.0, size = 0.65, cooldown = 1.8, windup = 0.35, from_hand = true}])
	e.loot.assign(_medium_loot())
	_defs[e.id] = e

	e = EnemyDef.new()
	e.id = "rime_skitter"
	e.enemy_name = "Rime Skitter"
	e.model = e.id
	e.hp = 220
	e.defense = 3
	e.xp = 25
	e.body_height = 0.8
	e.hit_radius = 0.4
	e.behavior = "dart"
	e.move_speed = 4.2
	e.keep_distance = 5.0
	e.follows_leader = true
	e.orbit_radius = 3.0
	e.attacks.assign([{style = "bolt", voxel_model = e.model + "/projectile", color = Color("#a5eaf2"),
		pattern = "aimed", count = 1, damage_min = 32, damage_max = 44, speed = 10.0,
		range = 9.0, size = 0.65, cooldown = 1.8, windup = 0.35, from_hand = true}])
	e.loot.assign(_medium_loot())
	_defs[e.id] = e

	e = EnemyDef.new()
	e.id = "snow_wisp"
	e.enemy_name = "Snow Wisp"
	e.model = e.id
	e.hp = 180
	e.defense = 3
	e.xp = 25
	e.body_height = 1.1
	e.hit_radius = 0.4
	e.behavior = "orbit"
	e.move_speed = 4.2
	e.keep_distance = 5.0
	e.follows_leader = true
	e.orbit_radius = 3.0
	e.attacks.assign([{style = "bolt", voxel_model = e.model + "/projectile", color = Color("#a5eaf2"),
		pattern = "aimed", count = 1, damage_min = 32, damage_max = 44, speed = 10.0,
		range = 9.0, size = 0.65, cooldown = 1.8, windup = 0.35, from_hand = true}])
	e.loot.assign(_medium_loot())
	_defs[e.id] = e
