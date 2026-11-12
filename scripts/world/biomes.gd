class_name Biomes
## All biomes in the game. Add a biome here, then have a generator place it.
##
## Lighting is kept close to neutral everywhere so the character and terrain
## stay readable; each biome's mood comes from a gentle tint, its fog of war
## (how far you can see and its color) and particles, not from heavy filters.

enum { HALL, OCEAN, BEACH, WOODS, JUNGLE, DESERT, DOOM, FOSEN, BLUELAY, DEEP_DESERT, DEEP_DARK, COUNT }

static var _all: Array[BiomeDef] = []


static func get_biome(id: int) -> BiomeDef:
	if _all.is_empty():
		_build()
	return _all[id]


static func find(biome_name: String) -> int:
	if _all.is_empty():
		_build()
	for b in _all:
		if b.biome_name.to_lower() == biome_name.to_lower():
			return b.id
	return -1


static func _make(props: Dictionary) -> BiomeDef:
	var b := BiomeDef.new()
	for key in props:
		if not key in b:
			push_error("BiomeDef has no property '%s'" % key)
		if key == "features":
			b.features.assign(props[key])  # typed array: assign, don't replace
		else:
			b.set(key, props[key])
	return b


## Spirits haunt a minority of ruins; all spirit chances are 30% of the old rate.
const SPIRIT_PACKS := [{pack = "spirit_brown_pack", chance = 0.135}, {pack = "spirit_blue_pack", chance = 0.036},
		{pack = "spirit_purple_pack", chance = 0.015}]
## Blue spirits are at home in Bluelay.
const SPIRIT_PACKS_BLUELAY := [{pack = "spirit_brown_pack", chance = 0.135}, {pack = "spirit_blue_pack", chance = 0.06},
		{pack = "spirit_purple_pack", chance = 0.015}]


## Plain daylight: the outdoor biomes that don't set their own sky use it,
## and it's the shared look every biome's atmosphere is mixed with (see
## Atmosphere), so crossing between biomes only shifts the mood a little.
##
## It is the Tavern's warm late-afternoon light (a little higher sun), so the
## realm and home share one base look: no blue sky cast, a warm neutral haze.
const DAY := {
	sky_top_color = Color(0.27, 0.38, 0.62), sky_horizon_color = Color(0.94, 0.78, 0.6),
	sun_color = Color(1.0, 0.87, 0.7), sun_energy = 1.35, sun_pitch = 36.0, ambient_energy = 0.9,
	fog_color = Color(0.86, 0.8, 0.7), fog_density = 0.0008, volumetric_fog_density = 0.0,
	cinematic_grade = 0.25, saturation = 1.18, contrast = 1.06,
	fog_of_war_enabled = false,
}


static func neutral() -> BiomeDef:
	return _make(DAY)


## Obstacle palette slots 1..8: stone, stone dark, foliage, wood, accent,
## foliage dark, glow (lanterns, embers), char (burnt wood).
static func _colors(stone: Color, stone_dark: Color, foliage: Color, wood: Color,
		accent: Color, foliage_dark: Color, glow := Color(1.0, 0.72, 0.38)) -> PackedColorArray:
	return PackedColorArray([Color.BLACK, stone, stone_dark, foliage, wood, accent, foliage_dark,
			glow, Color(0.09, 0.08, 0.08)])


static func _build() -> void:
	_all.resize(COUNT)

	# Home base: calm golden evening, vibrant sky-tinted fill (no haze).
	_all[HALL] = _make({
		id = HALL, biome_name = "The Tavern",
		top_block = Blocks.HALL_FLOOR,
		sky_top_color = Color(0.22, 0.32, 0.58), sky_horizon_color = Color(0.95, 0.72, 0.5),
		sun_color = Color(1.0, 0.86, 0.68), sun_energy = 1.35, sun_pitch = 32.0,
		ambient_energy = 0.9, saturation = 1.18, contrast = 1.06, cinematic_grade = 0.25,
		fog_of_war_enabled = false, volumetric_fog_density = 0.0012, indoor = true,
		particle_color = Color(1.0, 0.82, 0.57, 0.14), particle_velocity = Vector3(0.06, 0.12, 0), particle_size = 0.04,
	})


	_all[OCEAN] = _make(DAY.merged({
		id = OCEAN, biome_name = "Ocean",
		top_block = Blocks.SEAFLOOR, under_block = Blocks.SEAFLOOR,
		reveal_radius = 24.0, fog_of_war_color = Color(0.5, 0.62, 0.72),
		particle_color = Color(1, 1, 1, 0.2), particle_velocity = Vector3(0.6, 0.2, 0),
	}))
	_all[BEACH] = _make(DAY.merged({
		id = BEACH,
		enemy_packs = [
			{pack = "tide_snail_pack", density = 0.18}
		], biome_name = "Shores", god_stat = "dexterity",
		top_block = Blocks.SAND, under_block = Blocks.SAND,
		obstacle_density = 0.18, obstacles = {"surface/rock_grey": 2, "surface/log": 1},
		obstacle_colors = _colors(Color(0.6, 0.58, 0.52), Color(0.42, 0.4, 0.36),
				Color(0.32, 0.62, 0.25), Color(0.58, 0.42, 0.26), Color(0.9, 0.85, 0.7), Color(0.2, 0.45, 0.18)),
		decor = {decor_pebbles = 2, decor_dry_grass = 1}, decor_density = 0.08,
		features = [{type = "tide_rocks", required = 2, optional = 8, chance = 0.7,
				packs = [{pack = "crab_pack", chance = 0.85}]}],
		reveal_radius = 24.0, fog_of_war_color = Color(0.62, 0.68, 0.7),
		particle_color = Color(1, 1, 1, 0.2), particle_velocity = Vector3(0.6, 0.2, 0),
	}))
	_all[WOODS] = _make(DAY.merged({
		id = WOODS, biome_name = "Woods",
		top_block = Blocks.GRASS,
		obstacle_density = 0.4,
		obstacles = {"surface/rock_grey": 3, "surface/rock_slab": 2, "surface/log": 2,
				"surface/stump": 1.5, "pillar": 0.3},
		fog_density = 0.0, volumetric_fog_density = 0.0,
		obstacle_colors = _colors(Color(0.55, 0.55, 0.55), Color(0.38, 0.38, 0.4),
				Color(0.3, 0.56, 0.22), Color(0.42, 0.3, 0.18), Color(0.36, 0.52, 0.26), Color(0.2, 0.4, 0.16)),
		decor = {decor_tuft = 6, decor_flowers = 3, decor_mushrooms = 1, decor_pebbles = 1},
		decor_density = 0.45,
		features = [{type = "stone_circle", optional = 4, chance = 0.6},
				{type = "ruins", optional = 14, chance = 0.7, packs = SPIRIT_PACKS}],
		god_stat = "speed",
		enemy_packs = [
			{pack = "goblin_pack", density = 0.26},
			{pack = "sporeback_pack", density = 0.12},
			{pack = "cinder_beetle_pack", density = 0.1},
			{pack = "thorn_hopper_pack", density = 0.12},
			{pack = "bramble_fox_pack", density = 0.12},
			{pack = "moss_tortoise_pack", density = 0.1}
		],
		reveal_radius = 22.0, fog_of_war_color = Color(0.16, 0.2, 0.16),
		particle_color = Color(0.9, 1.0, 0.6, 0.35), particle_velocity = Vector3(0.2, 0.15, 0.1),
	}))
	_all[JUNGLE] = _make({
		id = JUNGLE, biome_name = "Jungle",
		top_block = Blocks.JUNGLE_GRASS,
		obstacle_density = 0.35,
		obstacles = {"surface/rock_grey": 2, "surface/log": 2, "pillar": 0.5},
		obstacle_colors = _colors(Color(0.5, 0.52, 0.45), Color(0.3, 0.33, 0.28),
				Color(0.16, 0.55, 0.2), Color(0.4, 0.28, 0.16), Color(0.92, 0.35, 0.45), Color(0.08, 0.35, 0.12)),
		decor = {decor_fern = 6, decor_tuft = 3, decor_flowers = 2, decor_mushrooms = 1},
		decor_density = 0.55,
		features = [{type = "ziggurat", optional = 2, chance = 0.8},
				{type = "ruins", optional = 8, chance = 0.7, packs = SPIRIT_PACKS}],
		god_stat = "dexterity",
		enemy_packs = [
			{pack = "green_dragon_pack", density = 0.2},
			{pack = "thorn_hopper_pack", density = 0.16},
			{pack = "vine_mantis_pack", density = 0.18}
		],
		sky_top_color = Color(0.22, 0.45, 0.5), sky_horizon_color = Color(0.72, 0.86, 0.76),
		sun_color = Color(1.0, 0.96, 0.85), sun_energy = 1.3, sun_pitch = 50.0, ambient_energy = 0.85,
		fog_color = Color(0.62, 0.74, 0.64), fog_density = 0.002, volumetric_fog_density = 0.008,
		torch_energy = 0.3,
		reveal_radius = 18.0, fog_of_war_color = Color(0.1, 0.18, 0.12), fog_of_war_enabled = false,
		particle_color = Color(0.8, 1.0, 0.4, 0.5), particle_velocity = Vector3(0.1, 0.2, 0.1),
	})
	_all[DESERT] = _make({
		id = DESERT, biome_name = "Desert",
		top_block = Blocks.DESERT_SAND, under_block = Blocks.DESERT_SAND, stone_block = Blocks.DESERT_ROCK,
		ruin_block = Blocks.SANDSTONE,
		obstacle_density = 0.35,
		obstacles = {"surface/rock_sand": 4, "cactus": 2, "pillar": 1},
		obstacle_colors = _colors(Color(0.85, 0.68, 0.45), Color(0.65, 0.48, 0.3),
				Color(0.35, 0.55, 0.3), Color(0.6, 0.45, 0.28), Color(0.95, 0.4, 0.5), Color(0.25, 0.42, 0.22)),
		decor = {decor_dry_grass = 4, decor_pebbles = 3}, decor_density = 0.2,
		features = [{type = "sunken_temple", optional = 2, chance = 0.8},
				{type = "ruins", optional = 8, chance = 0.7, packs = SPIRIT_PACKS}],
		god_stat = "defense", god_stats = ["defense", "hp"],
		enemy_packs = [
			{pack = "sand_scorpion_pack", density = 0.18},
			{pack = "black_scorpion_pack", density = 0.05},
			{pack = "sun_jackal_pack", density = 0.12},
			{pack = "dune_monolith_pack", density = 0.12},
			{pack = "glass_scorpion_pack", density = 0.12},
			{pack = "dune_crawler_pack", density = 0.1}
		],
		sky_top_color = Color(0.35, 0.55, 0.85), sky_horizon_color = Color(0.95, 0.85, 0.65),
		sun_color = Color(1.0, 0.94, 0.8), sun_energy = 1.5, sun_pitch = 58.0, ambient_energy = 0.85,
		fog_color = Color(0.95, 0.85, 0.68), fog_density = 0.0015, volumetric_fog_density = 0.003,
		reveal_radius = 22.0, fog_of_war_color = Color(0.75, 0.62, 0.42), fog_of_war_enabled = false,
		particle_color = Color(0.95, 0.8, 0.55, 0.5), particle_velocity = Vector3(1.5, 0.05, 0.3),
	})

	# The three center biomes: darker and foggier around the edges of your
	# view (smaller fog-of-war radius), but still clear close to the player.
	_all[DOOM] = _make({
		id = DOOM, biome_name = "Doom",
		god_stat = "attack", god_stats = ["attack", "defense"],
		enemy_packs = [
			{pack = "basalt_bulwark_pack", density = 0.11},
			{pack = "furnace_maw_pack", density = 0.11},
			{pack = "cinder_oracle_pack", density = 0.11},
			{pack = "spirit_purple_pack", density = 0.015},
			{pack = "slag_seraph_pack", density = 0.1},
			{pack = "obsidian_ram_pack", density = 0.1},
			{pack = "ember_lich_pack", density = 0.1},
			{pack = "ember_mite_pack", density = 0.1}
		],
		top_block = Blocks.ASH, under_block = Blocks.DOOM_ROCK, stone_block = Blocks.DOOM_ROCK,
		glow_block = Blocks.EMBER, glow_chance = 0.006, ruin_block = Blocks.OBSIDIAN,
		obstacle_density = 0.4,
		obstacles = {"surface/rock_lava": 4, "surface/rock_dark": 2, "obelisk": 1.2},
		obstacle_colors = _colors(Color(0.2, 0.18, 0.18), Color(0.12, 0.1, 0.1),
				Color(0.32, 0.14, 0.1), Color(0.18, 0.13, 0.11), Color(0.8, 0.22, 0.08), Color(0.22, 0.1, 0.08),
				Color(1.0, 0.45, 0.12)),
		decor = {decor_embers = 3, decor_pebbles = 2}, decor_density = 0.2,
		features = [
			{type = "ember_shrine", required = 1},
			{type = "lava_scar", required = 4, optional = 4, chance = 0.5},
			{type = "ruins", optional = 6, chance = 0.6},
		],
		sky_top_color = Color(0.14, 0.08, 0.08), sky_horizon_color = Color(0.5, 0.26, 0.2),
		sun_color = Color(1.0, 0.8, 0.68), sun_energy = 1.1, sun_pitch = 35.0, ambient_energy = 0.75,
		fog_color = Color(0.38, 0.22, 0.18), fog_density = 0.003, volumetric_fog_density = 0.01,
		torch_energy = 1.0,
		reveal_radius = 11.0, fog_of_war_color = Color(0.09, 0.04, 0.04), mood = 0.45,
		particle_color = Color(1.0, 0.45, 0.15, 0.9), particle_velocity = Vector3(0, 1.2, 0),
	})
	_all[FOSEN] = _make({
		id = FOSEN, biome_name = "Fosen",
		god_stat = "magic", god_stats = ["magic", "dexterity"],
		enemy_packs = [
			{pack = "frost_moth_pack", density = 0.12},
			{pack = "rime_stag_pack", density = 0.1},
			{pack = "glacier_hermit_pack", density = 0.1},
			{pack = "hail_harrier_pack", density = 0.1},
			{pack = "aurora_sentinel_pack", density = 0.09},
			{pack = "hoarfrost_owl_pack", density = 0.09},
			{pack = "icebound_colossus_pack", density = 0.09},
			{pack = "rime_skitter_pack", density = 0.05},
			{pack = "snow_wisp_pack", density = 0.05}
		],
		top_block = Blocks.TUNDRA, under_block = Blocks.FOSEN_ROCK, stone_block = Blocks.FOSEN_ROCK,
		ruin_block = Blocks.FOSEN_ROCK,
		obstacle_density = 0.4,
		obstacles = {"surface/rock_snow": 4, "ice_spike": 1.5, "surface/rock_grey": 1},
		obstacle_colors = _colors(Color(0.55, 0.58, 0.62), Color(0.38, 0.4, 0.45),
				Color(0.16, 0.35, 0.28), Color(0.35, 0.25, 0.18), Color(0.93, 0.96, 1.0), Color(0.1, 0.25, 0.2)),
		decor = {decor_flowers = 3, decor_pebbles = 2}, decor_density = 0.25,
		features = [
			{type = "frost_tower", required = 1},
			{type = "ravine", required = 1, optional = 2, chance = 0.5},
			{type = "ruins", optional = 4, chance = 0.5, packs = SPIRIT_PACKS},
		],
		sky_top_color = Color(0.6, 0.64, 0.7), sky_horizon_color = Color(0.88, 0.89, 0.9),
		sun_color = Color(0.98, 0.97, 0.95), sun_energy = 1.15, sun_pitch = 38.0, ambient_energy = 0.95,
		fog_color = Color(0.86, 0.88, 0.9), fog_density = 0.0045, volumetric_fog_density = 0.012,
		torch_energy = 0.5, mood = 0.5,
		reveal_radius = 13.0, fog_of_war_color = Color(0.82, 0.85, 0.89), fog_of_war_enabled = false,
		particle_color = Color(1, 1, 1, 0.9), particle_velocity = Vector3(0.4, -1.5, 0.2),
	})
	_all[BLUELAY] = _make({
		id = BLUELAY, biome_name = "Bluelay",
		top_block = Blocks.BLUE_MOSS, under_block = Blocks.BLUE_ROCK, stone_block = Blocks.BLUE_ROCK,
		glow_block = Blocks.BLUE_GLOW, glow_chance = 0.012, ruin_block = Blocks.BLUE_ROCK,
		obstacle_density = 0.45,
		obstacles = {"glowshroom": 3, "crystal_cluster": 3, "surface/crystal_blue": 2, "surface/rock_blue": 2},
		obstacle_colors = _colors(Color(0.26, 0.3, 0.45), Color(0.16, 0.19, 0.3),
				Color(0.18, 0.4, 0.6), Color(0.2, 0.22, 0.36), Color(0.45, 0.8, 0.95), Color(0.1, 0.24, 0.4),
				Color(0.3, 0.85, 1.0)),
		decor = {decor_glow_sprouts = 4, decor_mushrooms = 2, decor_tuft = 2}, decor_density = 0.35,
		features = [
			# The Blue Dragon's lair: he waits beside the spire.
			{type = "crystal_spire", required = 1},
			{type = "glow_pool", required = 1, optional = 4, chance = 0.6},
			{type = "ruins", optional = 3, chance = 0.5, packs = SPIRIT_PACKS_BLUELAY},
		],
		god_stat = "mp",
		enemy_packs = [
			{pack = "ruin_watcher_pack", density = 0.22},
			{pack = "blue_genie_pack", density = 0.1},
			{pack = "spirit_blue_pack", density = 0.021},
			{pack = "prism_ray_pack", density = 0.11},
			{pack = "runic_archivist_pack", density = 0.11},
			{pack = "azure_medusa_pack", density = 0.11},
			{pack = "tide_snail_pack", density = 0.06}
		],
		sky_top_color = Color(0.08, 0.12, 0.22), sky_horizon_color = Color(0.25, 0.35, 0.5),
		sun_color = Color(0.8, 0.88, 1.0), sun_energy = 0.9, sun_pitch = 30.0, ambient_energy = 0.8,
		fog_color = Color(0.2, 0.3, 0.45), fog_density = 0.003, volumetric_fog_density = 0.01,
		torch_energy = 0.9,
		reveal_radius = 11.0, fog_of_war_color = Color(0.04, 0.07, 0.13), mood = 0.35,
		particle_color = Color(0.3, 0.9, 1.0, 1.0), particle_velocity = Vector3(0.1, 0.3, 0.1),
	})

	# Golden dunes under a blazing sun; ruins half-buried in sand.
	_all[DEEP_DESERT] = _make({
		id = DEEP_DESERT, biome_name = "Deep Desert",
		god_stat = "hp",
		enemy_packs = [
			{pack = "spirit_brown_pack", density = 0.072},
			{pack = "spirit_blue_pack", density = 0.042},
			{pack = "spirit_purple_pack", density = 0.036},
			{pack = "dune_crawler_pack", density = 0.20}
		],
		top_block = Blocks.DEEP_SAND, under_block = Blocks.DEEP_SAND, stone_block = Blocks.DESERT_ROCK,
		ruin_block = Blocks.SANDSTONE,
		obstacle_density = 0.3,
		obstacles = {"surface/rock_sand": 3, "cactus": 2, "pillar": 1.5, "obelisk": 0.8},
		obstacle_colors = _colors(Color(0.9, 0.72, 0.42), Color(0.7, 0.52, 0.3),
				Color(0.42, 0.55, 0.28), Color(0.62, 0.46, 0.28), Color(1.0, 0.85, 0.4), Color(0.3, 0.42, 0.2)),
		decor = {decor_dry_grass = 3, decor_pebbles = 2}, decor_density = 0.12,
		features = [
			{type = "sunken_temple", required = 1, optional = 1, chance = 0.6},
			{type = "ruins", optional = 6, chance = 0.6},
		],
		sky_top_color = Color(0.4, 0.58, 0.85), sky_horizon_color = Color(1.0, 0.86, 0.6),
		sun_color = Color(1.0, 0.92, 0.72), sun_energy = 1.6, sun_pitch = 62.0, ambient_energy = 0.9,
		fog_color = Color(0.98, 0.84, 0.55), fog_density = 0.003, volumetric_fog_density = 0.006,
		reveal_radius = 15.0, fog_of_war_color = Color(0.85, 0.68, 0.38), fog_of_war_enabled = false,
		particle_color = Color(1.0, 0.85, 0.5, 0.7), particle_velocity = Vector3(2.0, 0.1, 0.4),
	})

	# The very center: almost no light at all. Only your torch and a few
	# drifting rainbow motes; no glowing plants, lanterns or lava.
	_all[DEEP_DARK] = _make({
		id = DEEP_DARK, biome_name = "The Deep Dark",
		god_stat = "speed", god_stats = ["speed", "mp"],
		enemy_packs = [
			{pack = "spirit_purple_pack", density = 0.036},
			{pack = "blue_genie_pack", density = 0.04},
			{pack = "umbral_reaper_pack", density = 0.13},
			{pack = "amethyst_widow_pack", density = 0.13},
			{pack = "nightbell_idol_pack", density = 0.13},
			{pack = "bile_bandit_patrol", density = 0.14},
			{pack = "gloam_bat_pack", density = 0.11}
		],
		top_block = Blocks.DEEP_STONE, under_block = Blocks.DEEP_SLATE, stone_block = Blocks.DEEP_SLATE,
		ruin_block = Blocks.DEEP_SLATE, lampposts = false,
		obstacle_density = 0.35,
		obstacles = {"surface/rock_dark": 4, "obelisk": 1, "pillar": 1, "surface/crystal_violet": 1},
		obstacle_colors = _colors(Color(0.17, 0.17, 0.2), Color(0.1, 0.1, 0.12),
				Color(0.14, 0.16, 0.18), Color(0.13, 0.12, 0.12), Color(0.22, 0.22, 0.26), Color(0.08, 0.09, 0.1),
				Color(0.05, 0.05, 0.06)),
		decor = {decor_pebbles = 3, decor_tuft = 1}, decor_density = 0.15,
		features = [
			{type = "stone_circle", required = 1},
			{type = "ruins", optional = 4, chance = 0.6},
		],
		sky_top_color = Color(0.0, 0.0, 0.0), sky_horizon_color = Color(0.004, 0.004, 0.008),
		sun_color = Color(0.45, 0.45, 0.6), sun_energy = 0.0, sun_pitch = 30.0, ambient_energy = 0.0,
		fog_color = Color(0.008, 0.007, 0.012), fog_density = 0.004, volumetric_fog_density = 0.008,
		torch_energy = 2.2, mood = 1.0,
		reveal_radius = 10.0, fog_of_war_color = Color(0.0, 0.0, 0.0),
		particle_color = Color(1, 1, 1, 0.45), particle_velocity = Vector3(0.1, 0.2, 0.05),
		# Mostly dark ash; now and then a single white or violet mote.
		particle_palette = [[0.0, Color(0.13, 0.12, 0.15)], [0.5, Color(0.08, 0.075, 0.1)],
				[0.955, Color(0.9, 0.9, 0.95)], [0.975, Color(0.62, 0.32, 0.95)]],
	})
