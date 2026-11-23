class_name SurfaceDungeonEnemies
## The eight Surface dungeons' creatures, minibosses and bosses
## (docs/dungeons/SURFACE_DUNGEONS.md), and the Surface creatures that drop
## their portals. Their fights live in scripts/enemies/bosses/.
##
## Stats climb with each dungeon's rating; every creature fires its own
## authored shot (creatures/boss_projectiles/) in its own pattern.

## id, hp, defense, behavior, height, speed, attacks (see _attack).
## An attack: [model, color, damage, pattern, count, spread, speed, range, cooldown, extra].
const CREATURES := {
	# --- The Sporewomb (3.5) ---------------------------------------------------------
	spore_puffling = [320, 3, "dart", 0.9, 3.0, [["spore_puff", "ffc04a", 22, "ring", 6, 0, 4.5, 7.0, 2.6, {}]]],
	mycelid_crawler = [380, 5, "chase", 0.7, 3.4, [["mycelium_seed", "6fe8d6", 24, "burst", 3, 0, 7.5, 11.0, 2.2, {interval = 0.18}]]],
	glowcap_sprite = [300, 2, "orbit", 1.0, 3.6, [["spore_puff", "6fe8d6", 22, "spread", 3, 16, 6.5, 12.0, 2.0, {magic = true}]]],
	shroom_brute = [1300, 12, "chase", 2.4, 1.9, [["spore_bomb", "c98a3c", 38, "aimed", 1, 0, 5.0, 11.0, 2.8,
		{size = 1.3, ripple = {radius = 3.0, speed = 5.0, damage_min = 18, damage_max = 26}, magic = true}],
		["spore_puff", "ffc04a", 30, "spread", 5, 18, 6.0, 9.0, 3.6, {}]]],
	spore_witch = [1100, 8, "skirmish", 2.0, 2.4, [["spore_cluster", "ffb347", 34, "spread", 5, 14, 6.5, 13.0, 2.6, {}],
		["mycelium_seed", "6fe8d6", 30, "ring", 10, 0, 4.0, 12.0, 5.5, {effects = [{id = "speed", amount = -3, duration = 2.0}], effect_source = "Spore Witch"}]]],
	bracket_warden = [4300, 16, "stationary", 3.2, 0.0, [["spore_bomb", "c98a3c", 42, "ring", 12, 0, 4.2, 13.0, 4.5, {size = 1.2}],
		["spore_cluster", "ffb347", 40, "spread", 7, 12, 6.5, 14.0, 2.8, {}]]],
	# --- Saltbone Wreck (4.5) ------------------------------------------------------
	bilge_rat = [430, 4, "dart", 1.0, 3.8, [["tide_shard", "a8f0e8", 28, "spread", 3, 14, 7.5, 10.0, 1.8, {}]]],
	barnacle_crab = [560, 10, "dart", 0.9, 2.6, [["tide_pearl", "e0dccb", 30, "burst", 2, 0, 7.0, 11.0, 2.3, {interval = 0.25}]]],
	drowned_deckhand = [600, 6, "skirmish", 1.8, 2.8, [["brine_hook", "8a6a4a", 32, "aimed", 1, 0, 8.0, 12.0, 2.0, {returns = 0.6}]]],
	kelp_shambler = [1800, 14, "chase", 2.6, 1.8, [["tide_shard", "3fd8c8", 44, "ring", 8, 0, 4.5, 11.0, 3.2,
		{effects = [{id = "speed", amount = -3, duration = 2.0}], effect_source = "Kelp Shambler"}],
		["tide_pearl", "8ad8b0", 40, "spread", 3, 20, 6.0, 10.0, 2.4, {}]]],
	cannon_gunner = [1500, 12, "skirmish", 2.0, 2.0, [["cannonball", "3a3c40", 50, "aimed", 1, 0, 6.0, 15.0, 3.4,
		{size = 1.35, radius = 0.32, root = true, windup = 1.0, recover = 0.6}]]],
	first_mate_grisk = [5600, 20, "stationary", 3.2, 0.0, [["brine_hook", "8a6a4a", 50, "spread", 5, 16, 7.5, 14.0, 2.6, {returns = 0.55}],
		["cannonball", "3a3c40", 54, "ring", 10, 0, 4.5, 13.0, 5.0, {size = 1.2}]]],
	# --- The Jade Ziggurat (5.5) -------------------------------------------------
	temple_skink = [520, 5, "dart", 0.8, 4.2, [["jade_fang", "4fd88a", 32, "spread", 2, 10, 9.0, 11.0, 1.6, {}]]],
	vine_strangler = [700, 9, "stationary", 1.6, 0.0, [["thorn_spike", "5c9a42", 36, "spread", 3, 12, 7.5, 13.0, 2.0, {}],
		["thorn_spike", "ff7ab0", 34, "ring", 8, 0, 5.0, 10.0, 4.5, {effects = [{id = "speed", amount = -3, duration = 1.5}], effect_source = "Vine Strangler"}]]],
	plume_wisp = [560, 4, "strafe", 1.2, 3.8, [["gold_plume", "ffd060", 34, "sweep", 5, 0, 8.0, 12.0, 2.4, {arc_deg = 60.0, interval = 0.08}]]],
	jade_guardian = [2200, 22, "chase", 2.8, 1.7, [["sun_glyph", "ffd060", 54, "cross", 4, 0, 6.0, 12.0, 2.6, {size = 1.2}],
		["sun_glyph", "6af0a0", 50, "aimed", 1, 0, 7.5, 13.0, 3.6, {size = 1.4, magic = true,
			ripple = {radius = 3.0, speed = 6.0, damage_min = 24, damage_max = 32}}]]],
	serpent_priest = [1800, 12, "skirmish", 2.2, 2.6, [["jade_fang", "4fd88a", 50, "spread", 5, 13, 7.0, 13.0, 2.4, {}],
		["gold_plume", "ffd060", 46, "ring", 12, 0, 4.5, 12.0, 5.0, {turn = 0.35}]]],
	obsidian_jaguar = [6800, 20, "dart", 2.0, 4.6, [["jade_fang", "4fd88a", 60, "burst", 4, 0, 10.0, 13.0, 2.4, {interval = 0.12}],
		["jade_fang", "ffd060", 56, "spread", 7, 10, 8.0, 12.0, 3.4, {}]]],
	# --- Afterlife (6.0): quick, bright and slippery ----------------------------------
	lost_soul = [560, 4, "spirit", 1.2, 4.4, [["soul_wisp", "5ff0ff", 36, "burst", 3, 0, 9.0, 12.0, 2.0, {interval = 0.14, magic = true}]]],
	lantern_moth = [620, 5, "strafe", 1.3, 4.0, [["moth_scale", "e070ff", 38, "sweep", 6, 0, 7.5, 13.0, 2.6, {arc_deg = 70.0, interval = 0.07}]]],
	grave_creeper = [760, 10, "dart", 0.9, 3.6, [["pale_tear", "c8f8ff", 40, "spread", 3, 15, 8.0, 10.0, 2.0,
		{effects = [{id = "speed", amount = -3, duration = 1.5}], effect_source = "Grave Creeper"}]]],
	mourning_wraith = [2100, 12, "spirit", 2.6, 3.0, [["pale_tear", "c8f8ff", 54, "ring", 10, 0, 5.0, 12.0, 3.8, {magic = true}],
		["soul_wisp", "5ff0ff", 50, "sweep", 7, 0, 8.5, 13.0, 2.6, {arc_deg = 80.0, interval = 0.06, magic = true}]]],
	soul_warden = [2400, 20, "chase", 2.6, 2.2, [["lantern_flame", "ffd27a", 58, "aimed", 1, 0, 7.0, 13.0, 2.4,
		{size = 1.3, magic = true, ripple = {radius = 3.2, speed = 6.0, damage_min = 26, damage_max = 34}}],
		["soul_wisp", "e070ff", 52, "spread", 5, 12, 8.0, 12.0, 3.0, {magic = true}]]],
	willow_matron = [7400, 20, "stationary", 3.6, 0.0, [["soul_wisp", "5ff0ff", 60, "ring", 16, 0, 4.5, 14.0, 4.0, {magic = true, turn = 0.3}],
		["moth_scale", "e070ff", 62, "sweep", 9, 0, 7.0, 14.0, 2.6, {arc_deg = 100.0, interval = 0.05}]]],
	# --- Rimewake Barrow (7.0): heavy, slow and freezing --------------------------------
	barrow_wight = [880, 14, "skirmish", 1.9, 2.6, [["ice_bolt", "a8d8ff", 46, "spread", 3, 12, 8.0, 12.0, 2.2, {}]]],
	rime_hound = [760, 8, "dart", 1.2, 4.6, [["frost_shard", "d8f4ff", 44, "burst", 3, 0, 10.0, 11.0, 2.0, {interval = 0.13}]]],
	cairn_crow = [700, 6, "strafe", 1.0, 4.4, [["crow_feather", "3a3c48", 44, "sweep", 5, 0, 9.0, 13.0, 2.4, {arc_deg = 60.0, interval = 0.07}]]],
	draugr_huscarl = [3200, 28, "chase", 2.8, 1.8, [["ice_axe", "8ad8ff", 70, "spread", 3, 18, 6.5, 12.0, 2.8, {size = 1.3, pierce_players = true}],
		["frost_shard", "d8f4ff", 60, "ring", 10, 0, 5.0, 10.0, 4.6, {}]]],
	rune_seer = [2700, 14, "skirmish", 2.2, 2.4, [["frost_rune", "6ad0ff", 66, "ring", 10, 0, 4.5, 13.0, 3.6,
		{magic = true, effects = [{id = "speed", amount = -4, duration = 2.0}], effect_source = "Rune Seer"}],
		["frost_rune", "a0ffd8", 64, "aimed", 1, 0, 8.0, 14.0, 2.2, {size = 1.3, magic = true}]]],
	frostbound_shieldmaiden = [9200, 30, "stationary", 3.2, 0.0, [["ice_axe", "8ad8ff", 78, "ring", 12, 0, 4.5, 14.0, 4.2, {size = 1.2}],
		["crow_feather", "3a3c48", 72, "spread", 7, 10, 8.0, 14.0, 2.8, {}]]],
	# --- The Glass Labyrinth (8.0): precise, refracted ------------------------------------
	glass_mite = [950, 14, "dart", 0.8, 4.2, [["glass_shard", "e8f8ff", 52, "spread", 3, 12, 9.0, 11.0, 1.9, {}]]],
	mirror_wisp = [900, 8, "orbit", 1.2, 3.8, [["lens_disc", "fff6d8", 54, "ring", 6, 0, 6.0, 12.0, 2.6, {magic = true, turn = 0.4}]]],
	lens_crawler = [1100, 18, "skirmish", 1.0, 2.8, [["prism_ray", "ff8af0", 58, "aimed", 1, 0, 14.0, 18.0, 2.6,
		{root = true, windup = 0.9, recover = 0.4, pierce_players = true}]]],
	prism_golem = [3800, 30, "chase", 3.0, 1.7, [["glass_shard", "7af0ff", 80, "spread", 5, 11, 7.0, 13.0, 2.6, {}],
		["glass_shard", "ff8af0", 74, "ring", 12, 0, 5.0, 12.0, 4.8, {}]]],
	mirror_dervish = [3200, 18, "spirit", 2.2, 3.4, [["lens_disc", "fff6d8", 76, "sweep", 8, 0, 8.0, 13.0, 2.6, {arc_deg = 120.0, interval = 0.05, returns = 0.6}]]],
	the_refractor = [11500, 26, "stationary", 3.2, 0.0, [["prism_ray", "7af0ff", 90, "cross", 4, 0, 11.0, 18.0, 2.4, {pierce_players = true}],
		["glass_shard", "ff8af0", 84, "ring", 16, 0, 5.0, 15.0, 4.4, {turn = 0.25}]]],
	# --- The Unlit Cathedral (9.0): silence and heavy glass ----------------------------------
	candle_wraith = [1150, 10, "skirmish", 1.6, 3.0, [["candle_flame", "ffcf8a", 62, "burst", 3, 0, 8.5, 12.0, 2.2, {interval = 0.16, magic = true}]]],
	bell_imp = [1100, 12, "dart", 1.0, 4.4, [["bell_note", "c070ff", 60, "spread", 3, 14, 8.5, 11.0, 2.0, {}]]],
	censer_bearer = [1350, 16, "chase", 1.9, 2.4, [["wax_tear", "c070ff", 66, "ring", 8, 0, 5.0, 10.0, 3.0,
		{effects = [{id = "quiet", duration = 1.2}], effect_source = "Censer smoke"}]]],
	glass_knight = [4500, 34, "chase", 3.0, 1.8, [["glass_pane", "e04a8a", 94, "spread", 5, 11, 7.0, 13.0, 2.6, {size = 1.2, pierce_players = true}],
		["glass_pane", "8a4ae0", 86, "ring", 12, 0, 5.0, 12.0, 5.0, {}]]],
	hymn_abbess = [3900, 18, "skirmish", 2.4, 2.4, [["bell_note", "c070ff", 88, "ring", 12, 0, 4.8, 14.0, 3.6, {magic = true}],
		["wax_tear", "ffcf8a", 90, "sweep", 7, 0, 8.0, 14.0, 2.6, {arc_deg = 80.0, interval = 0.06,
			effects = [{id = "quiet", duration = 1.5}], effect_source = "Hymn Abbess"}]]],
	bellringer = [14000, 30, "stationary", 3.6, 0.0, [["bell_note", "c070ff", 104, "ring", 18, 0, 4.6, 15.0, 4.0, {size = 1.2}],
		["candle_flame", "ffcf8a", 98, "spread", 9, 9, 8.0, 15.0, 2.6, {}]]],
	# --- The Starless Sepulchre (10.0) ---------------------------------------------------------
	star_eater = [1600, 14, "strafe", 1.3, 4.6, [["void_shard", "8a7aff", 78, "sweep", 6, 0, 9.5, 13.0, 2.2, {arc_deg = 70.0, interval = 0.06}]]],
	kintsugi_shade = [1800, 20, "skirmish", 1.9, 3.4, [["gold_seam", "ffc24a", 82, "spread", 3, 12, 9.0, 13.0, 2.0, {}],
		["gold_seam", "fff0b0", 80, "burst", 4, 0, 10.0, 12.0, 3.4, {interval = 0.1}]]],
	astral_reaver = [6000, 38, "chase", 3.2, 2.0, [["kintsugi_star", "ffc24a", 110, "spread", 5, 11, 7.5, 13.0, 2.4, {size = 1.25, pierce_players = true}],
		["void_shard", "8a7aff", 104, "ring", 14, 0, 5.0, 13.0, 4.6, {}]]],
	unmade_herald = [5200, 24, "spirit", 2.6, 3.4, [["void_shard", "8a7aff", 106, "ring", 14, 0, 5.0, 14.0, 3.6, {magic = true, turn = 0.3}],
		["fallen_star", "fff0b0", 112, "aimed", 1, 0, 9.0, 15.0, 2.6, {size = 1.3, magic = true,
			ripple = {radius = 3.4, speed = 7.0, damage_min = 50, damage_max = 64}}]]],
}

## The loot of each dungeon's ordinary creatures (pool tiers rise with the
## dungeon's loot_tier_bias, see EnemyDirector.scaled_definition).
const ORDINARY_LOOT := [{item = "elixir_hp", chance = 0.25}, {item = "elixir_mp", chance = 0.12},
	{pool = {tier = 3}, chance = 0.15}, {pool = {tier = 4}, chance = 0.05}]
const MINIBOSSES := ["bracket_warden", "first_mate_grisk", "obsidian_jaguar", "willow_matron", "frostbound_shieldmaiden",
	"the_refractor", "bellringer"]
const NAMES := {
	glowcap_sprite = "Glowcap Sprite", first_mate_grisk = "Grisk, the First Mate", obsidian_jaguar = "The Obsidian Jaguar",
	willow_matron = "The Willow Matron", frostbound_shieldmaiden = "Sigrun the Frostbound", the_refractor = "The Refractor",
	bellringer = "The Bellringer", kintsugi_shade = "Kintsugi Shade",
}

## id, name, hp, defense, height, hit radius, variants (phase 2, phase 3), burst color, phases' defense drop.
const BOSSES := [
	["mother_mycora", "Mother Mycora", 14000, 10, 5.5, 1.8, ["bloom", "rot"], "ffc04a"],
	["captain_saltmourn", "Captain Saltmourn", 25000, 14, 5.0, 1.6, ["storm", "abyss"], "3fd8c8"],
	["ixalith", "Ixalith, the Jade Coil", 33000, 18, 6.0, 1.9, ["radiant", "molted"], "6af0a0"],
	["lantern_shepherd", "Elegy, the Lantern Shepherd", 38000, 16, 6.0, 1.6, ["veil", "unbound"], "5ff0ff"],
	["jarl_hrimvald", "Jarl Hrimvald, the Barrow King", 48000, 26, 6.0, 1.9, ["wrath", "thaw"], "6ad0ff"],
	["solenne", "Solenne, the Prism Oracle", 62000, 24, 6.0, 1.8, ["refracted", "eclipse"], "fff6d8"],
	["choirless_seraph", "The Choirless Seraph", 82000, 28, 6.5, 2.0, ["kindled", "hollow"], "c070ff"],
	["oblivara", "Oblivara, the Unmade God", 140000, 32, 8.0, 2.4, ["awakened", "unmade"], "ffc24a"],
]
const BOSS_DEFENSE_DROP := 4

## Surface creatures that open each portal (chance per kill).
const PORTALS := {
	sporeback = ["sporewomb", 0.06], moss_tortoise = ["sporewomb", 0.05],
	tide_snail = ["saltbone_wreck", 0.025], crab = ["saltbone_wreck", 0.015],
	green_dragon = ["jade_ziggurat", 0.06], vine_mantis = ["jade_ziggurat", 0.03],
	spirit_brown = ["afterlife", 0.35], spirit_blue = ["afterlife", 0.35], spirit_purple = ["afterlife", 0.35],
	icebound_colossus = ["rimewake_barrow", 0.2], rime_stag = ["rimewake_barrow", 0.15], glacier_hermit = ["rimewake_barrow", 0.15],
	glass_scorpion = ["glass_labyrinth", 0.18], dune_monolith = ["glass_labyrinth", 0.12],
	nightbell_idol = ["unlit_cathedral", 0.15], umbral_reaper = ["unlit_cathedral", 0.12], amethyst_widow = ["unlit_cathedral", 0.08],
}


static func build(defs: Dictionary) -> void:
	for id: String in CREATURES:
		defs[id] = _creature(id, CREATURES[id])
	for spec: Array in BOSSES:
		defs[spec[0]] = _boss(spec)
	for id: String in PORTALS:
		if defs.has(id) and defs[id].portal_drop.is_empty():
			defs[id].portal_drop = {dungeon = PORTALS[id][0], chance = PORTALS[id][1]}


static func _creature(id: String, spec: Array) -> EnemyDef:
	var d := EnemyDef.new()
	d.id = id
	d.enemy_name = NAMES.get(id, id.replace("_", " ").capitalize())
	d.model = id
	d.hp = spec[0]
	d.defense = spec[1]
	d.xp = int(d.hp / 10)
	d.behavior = spec[2]
	d.body_height = spec[3]
	d.move_speed = spec[4]
	var big: bool = id in MINIBOSSES
	d.hit_radius = 1.1 if big else 0.5 if d.hp < 1500 else 0.85
	d.keep_distance = 6.5
	d.aggro_radius = 18.0 if big else 16.0
	d.wander_radius = 0.0 if d.behavior == "stationary" else 2.0
	d.spawn_anim = "rise"
	d.sheds = not big
	for a: Array in spec[5]:
		d.attacks.append(_attack(a))
	if big:
		d.loot.assign([{item = "elixir_hp", chance = 0.6}, {item = "elixir_mp", chance = 0.4}, {pool = {tier = 4}, chance = 0.4},
			{pool = {tier = 5}, chance = 0.12}])
		d.loot_threshold = 0.05
	else:
		d.loot.assign(ORDINARY_LOOT.duplicate(true))
	return d


static func _attack(a: Array) -> Dictionary:
	var attack := {style = "orb", color = Color(a[1]), voxel_model = "boss_projectiles/" + str(a[0]),
		authored_projectile = true, pixel_projectile = true, projectile_glow = 0.8,
		damage_min = a[2], damage_max = int(a[2] * 1.2), pattern = a[3], count = a[4], spread_deg = float(a[5]),
		speed = a[6], range = a[7], cooldown = a[8], windup = 0.7, size = 0.9, radius = 0.2}
	attack.merge(a[9], true)
	return attack


static func _boss(spec: Array) -> BossDef:
	var b := RealmBosses._boss(spec[0], spec[1], spec[0], "", spec[0])
	b.wake_on = "near"
	b.hp = spec[2]
	b.defense = spec[3]
	b.body_height = spec[4]
	b.hit_radius = spec[5]
	b.model_scale = 1.0
	b.xp = int(b.hp / 10)
	b.intro_time = 5.0
	b.bar_radius = 44.0
	b.abandon_radius = 40.0
	b.dungeon_reward = true
	b.burst_color = Color(spec[7])
	var variants: Array = spec[6]
	b.phases.assign([{until = 0.66, defense = b.defense}, {until = 0.33, defense = b.defense - BOSS_DEFENSE_DROP, variant = variants[0]},
		{until = 0.0, defense = b.defense - BOSS_DEFENSE_DROP * 2, variant = variants[1]}])
	b.loot.assign([{item = "elixir_hp", chance = 1.0}, {item = "elixir_mp", chance = 1.0}, {item = "backpack", chance = 0.03}])
	match b.id:
		"solenne": b.follow_up = {dungeon = "starless_sepulchre", chance = 0.08}
		"choirless_seraph": b.follow_up = {dungeon = "starless_sepulchre", chance = 0.25}
		"oblivara":
			# The god of the hardest place in the world: five stages, more health per helper, more potions.
			b.phases.assign([{until = 0.8, defense = b.defense}, {until = 0.6, defense = b.defense, variant = variants[0]},
				{until = 0.4, defense = b.defense - 4, variant = variants[0]}, {until = 0.2, defense = b.defense - 6, variant = variants[1]},
				{until = 0.0, defense = b.defense - 8, variant = variants[1]}])
			b.hp_per_extra_player = 0.35
			b.dungeon_potions = ["attack", "defense", "speed", "dexterity", "magic", "vitality", "hp", "mp"]
			b.dungeon_potion_max = 3
			b.loot_threshold = 0.03
			b.intro_time = 8.0
			b.bar_radius = 60.0
			b.abandon_radius = 55.0
			b.loot.append({item = "backpack", chance = 0.1})
	return b
