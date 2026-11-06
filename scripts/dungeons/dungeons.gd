class_name Dungeons
## Dungeon records are ephemeral. A portal owns one instance, never a dungeon type.
const DEFINITIONS := {
	theory_of_everything = {
		id="theory_of_everything",name="Theory of Everything",rating=6.0,damage_hint="enemies hit hard, gravity and puzzles",
		portal_colors=[Color("67f0ff"),Color("ef70ff")],
		portal_hole={seed=8291,radius=1.9,voxel=0.18,earth=Color("151a30"),stone=Color("42516f"),moss=Color("7257d6"),leaf=Color("67f0ff"),root=Color("ef70ff")},
		generator_style="theory",params={},low_enemies=["hull_skitter","void_lamprey","gloom_spitter"],
		mid_enemies=["vent_stalker","crest_brute"],boss="void_empress",miniboss="",
		miniboss_chance=0.0,treasure_room_chance=0.0,enemy_hp_multiplier=1.0,enemy_damage_multiplier=1.0,
		loot_tier_bias=2,common_tier=6,theme="drowned_spire",
	},
	goblins_cave = {
		id = "goblins_cave", name = "Goblins Cave", rating = 2.5, damage_hint = "enemies hit lightly",
		portal_colors = [Color("79c646"), Color("ef963f")],
		portal_hole = {seed = 7319, radius = 1.65, voxel = 0.22,
			earth = Color("35291f"), stone = Color("343940"), moss = Color("56833a"),
			leaf = Color("8ba953"), root = Color("655038")},
		generator_style = "cave_maze", params = {rooms = 15, area = 62.0, room_radius = [6, 9], boss_radius = 13, wall_height = 6,
			corridor_radius = 2.0, loops = 0.2, dead_ends = 6},
		low_enemies = ["cave_slinger", "moss_bat", "mushroom_crawler"],
		mid_enemies = ["goblin_brute", "cave_shaman"], boss = "goblin_king",
		miniboss = "goblin_warlord", miniboss_chance = 0.35, treasure_room_chance = 0.25,
		enemy_hp_multiplier = 1.0, enemy_damage_multiplier = 1.0, loot_tier_bias = 0,
		common_tier = 4, divine_set = "Fallenwood",
		theme = "moss_cave",
	},
	# A buried hall of the Scarab Regent's court: square chambers, plank floors, sand walls.
	sunken_court = {
		id = "sunken_court", name = "The Sunken Court", rating = 4.0, damage_hint = "enemies hit moderately",
		portal_colors = [Color("e2b45a"), Color("f07f9e")],
		portal_hole = {seed = 7411, radius = 1.65, voxel = 0.22,
			earth = Color("b8955a"), stone = Color("d6b77a"), moss = Color("e9c86a"),
			leaf = Color("f3dd96"), root = Color("8a6a3c")},
		generator_style = "hall", params = {cells = 5, spacing = 26, room_half = [6, 10], boss_half = 13, wall_height = 7,
			corridor_radius = 2.0, loops = 0.15, dead_ends = 5, rooms = 16},
		low_enemies = ["tomb_scarab", "sand_imp", "dust_wisp"],
		mid_enemies = ["mummy_guard", "sun_priest"], boss = "gilded_vizier",
		miniboss = "gilded_sentinel", miniboss_chance = 0.35, treasure_room_chance = 0.3,
		enemy_hp_multiplier = 1.0, enemy_damage_multiplier = 1.0, loot_tier_bias = 1,
		common_tier = 5, theme = "sand_hall",
	},
	# Under a volcano: Goblins Cave's winding format, with glowing lava cracks that burn.
	cinder_depths = {
		id = "cinder_depths", name = "Cinder Depths", rating = 5.0, damage_hint = "enemies hit hard",
		portal_colors = [Color("ff6a1f"), Color("ffd24a")],
		portal_hole = {seed = 7517, radius = 1.65, voxel = 0.22,
			earth = Color("2a2220"), stone = Color("17121a"), moss = Color("ff5a12"),
			leaf = Color("ffb23a"), root = Color("6b1d10")},
		generator_style = "cave_maze", params = {rooms = 15, area = 64.0, room_radius = [6, 9], boss_radius = 14, wall_height = 7,
			corridor_radius = 2.0, loops = 0.2, dead_ends = 6, lava_cracks = true},
		low_enemies = ["magma_imp", "ash_crawler", "ember_bat"],
		mid_enemies = ["lava_golem", "cinder_cultist"], boss = "magma_warden",
		miniboss = "obsidian_brute", miniboss_chance = 0.35, treasure_room_chance = 0.25,
		enemy_hp_multiplier = 1.0, enemy_damage_multiplier = 1.0, loot_tier_bias = 1,
		common_tier = 5, theme = "volcano", follow_up = "cinder_depths_encore",
	},
	# The encore: a burning forest that is nearly all boss fight.
	cinder_depths_encore = {
		id = "cinder_depths_encore", name = "Cinder Depths Encore", rating = 7.0, damage_hint = "enemies hit very hard",
		portal_colors = [Color("ff3b0f"), Color("ffe066")],
		portal_hole = {seed = 7621, radius = 1.8, voxel = 0.22,
			earth = Color("1a1210"), stone = Color("2c1b14"), moss = Color("ff7a1a"),
			leaf = Color("ffd34d"), root = Color("3a1a0c")},
		generator_style = "arena", params = {arena_radius = 22, guard_rooms = 2, room_radius = [8, 9], wall_height = 9, corridor_radius = 2.5},
		low_enemies = ["cinder_sapling"], mid_enemies = ["flame_dryad"], boss = "pyre_ent",
		miniboss = "", miniboss_chance = 0.0, treasure_room_chance = 0.0,
		enemy_hp_multiplier = 1.0, enemy_damage_multiplier = 1.0, loot_tier_bias = 2,
		common_tier = 6, theme = "burning_forest",
	},
	# Bluelay: a flooded crystal grotto, and the sunken bell tower beneath it.
	azure_grotto = {
		id = "azure_grotto", name = "The Azure Grotto", rating = 5.5, damage_hint = "enemies hit hard",
		portal_colors = [Color("3ad1ff"), Color("9be8ff")],
		portal_hole = {seed = 7713, radius = 1.65, voxel = 0.22,
			earth = Color("143a52"), stone = Color("1f4f6e"), moss = Color("39b3d6"),
			leaf = Color("9be8ff"), root = Color("2a6f8a")},
		generator_style = "cave_maze", params = {rooms = 16, area = 66.0, room_radius = [6, 10], boss_radius = 14, wall_height = 7,
			corridor_radius = 2.0, loops = 0.25, dead_ends = 6},
		low_enemies = ["grotto_crab", "tide_wisp", "coral_skitter"],
		mid_enemies = ["deep_angler", "reef_guardian"], boss = "abyssal_siren",
		miniboss = "brine_matron", miniboss_chance = 0.35, treasure_room_chance = 0.25,
		enemy_hp_multiplier = 1.0, enemy_damage_multiplier = 1.0, loot_tier_bias = 1,
		common_tier = 5, theme = "blue_grotto",
	},
	drowned_spire = {
		id = "drowned_spire", name = "The Drowned Spire", rating = 6.5, damage_hint = "enemies hit very hard",
		portal_colors = [Color("2b6cff"), Color("d6e6ff")],
		portal_hole = {seed = 7817, radius = 1.7, voxel = 0.22,
			earth = Color("0e1a33"), stone = Color("23365c"), moss = Color("4f86ff"),
			leaf = Color("d6e6ff"), root = Color("1b2b4d")},
		generator_style = "hall", params = {cells = 5, spacing = 26, room_half = [6, 10], boss_half = 14, wall_height = 9,
			corridor_radius = 2.0, loops = 0.2, dead_ends = 6, rooms = 17},
		low_enemies = ["drowned_acolyte", "spire_eel", "bubble_jelly"],
		mid_enemies = ["tide_knight", "choir_wraith"], boss = "drowned_cantor",
		miniboss = "bell_warden", miniboss_chance = 0.4, treasure_room_chance = 0.3,
		enemy_hp_multiplier = 1.0, enemy_damage_multiplier = 1.0, loot_tier_bias = 2,
		common_tier = 6, theme = "drowned_spire",
	},
}

## How each theme looks: floor and wall blocks, light, fog and props.
## floor: [main, second, third] picked by noise; crack: the lava block.
const THEMES := {
	moss_cave = {name = "Mosslit Caves", base = Biomes.DEEP_DARK, floor = [Blocks.CAVE_CRACKED, Blocks.CAVE_DIRT, Blocks.CAVE_MOSS],
		wall = [Blocks.DEEP_SLATE, Blocks.CAVE_CRACKED, Blocks.CAVE_MOSS], sky = Color("526459"), horizon = Color("718069"),
		sun = Color("b5c7a2"), sun_energy = 0.45, ambient = 0.9, fog = Color("25352c"), fog_of_war = Color("141c19"),
		reveal = 18.0, torch = 1.2, light = Color("9cdb77"), map = Color("526449")},
	sand_hall = {name = "Sunken Court", base = Biomes.DESERT, floor = [Blocks.TIMBER, Blocks.TIMBER, Blocks.DESERT_SAND],
		wall = [Blocks.SANDSTONE, Blocks.DESERT_SAND, Blocks.RUNE_SAND], sky = Color("8a6a40"), horizon = Color("c79a5a"),
		sun = Color("ffd9a0"), sun_energy = 0.7, ambient = 1.1, fog = Color("6b5232"), fog_of_war = Color("2a2014"),
		reveal = 32.0, torch = 1.0, light = Color("ffc36a"), map = Color("a07a48")},
	volcano = {name = "Cinder Depths", base = Biomes.DOOM, floor = [Blocks.ASH, Blocks.DOOM_ROCK, Blocks.OBSIDIAN],
		wall = [Blocks.OBSIDIAN, Blocks.DOOM_ROCK, Blocks.ASH], crack = Blocks.LAVA, sky = Color("3a1510"), horizon = Color("6a2a12"),
		sun = Color("ff9a5a"), sun_energy = 0.4, ambient = 0.7, fog = Color("2a120c"), fog_of_war = Color("140806"),
		reveal = 20.0, torch = 1.3, light = Color("ff7a2a"), map = Color("5a3a30")},
	blue_grotto = {name = "The Azure Grotto", base = Biomes.BLUELAY, floor = [Blocks.BLUE_ROCK, Blocks.BLUE_MOSS, Blocks.WATER_TILE],
		wall = [Blocks.BLUE_ROCK, Blocks.DEEP_STONE, Blocks.BLUE_GLOW], sky = Color("0f3a2a"), horizon = Color("2a8a5a"),
		# Lit green: bioluminescent water and glowing algae (the Spire stays cold blue).
		sun = Color("a8ffc0"), sun_energy = 0.5, ambient = 0.9, fog = Color("0d3324"), fog_of_war = Color("05160e"),
		reveal = 22.0, torch = 1.1, light = Color("5dff9a"), map = Color("2f7a5a")},
	drowned_spire = {name = "The Drowned Spire", base = Biomes.BLUELAY, floor = [Blocks.RUNE_BLUE, Blocks.WATER_TILE, Blocks.BLUE_MOSS],
		wall = [Blocks.BLUE_ROCK, Blocks.RUNE_BLUE, Blocks.DEEP_STONE], sky = Color("0c1630"), horizon = Color("23365c"),
		sun = Color("b9d2ff"), sun_energy = 0.45, ambient = 0.85, fog = Color("0c1a33"), fog_of_war = Color("050a14"),
		reveal = 26.0, torch = 1.1, light = Color("8fb6ff"), map = Color("2a4470")},
	burning_forest = {name = "The Burning Forest", base = Biomes.DOOM, floor = [Blocks.ASH, Blocks.GRASS, Blocks.DOOM_ROCK],
		wall = [Blocks.TIMBER, Blocks.ASH, Blocks.DOOM_ROCK], sky = Color("4a1a0c"), horizon = Color("a8461a"),
		sun = Color("ffb070"), sun_energy = 0.55, ambient = 0.8, fog = Color("3a1a0e"), fog_of_war = Color("180a06"),
		reveal = 26.0, torch = 1.1, light = Color("ff8a2a"), map = Color("4a3a24")},
}

static func theme(dungeon: Dictionary) -> Dictionary:
	return THEMES.get(str(dungeon.get("theme", "moss_cave")), THEMES.moss_cave)

static func is_dungeon(id: String) -> bool:
	return id.begins_with("dng_")

static func definition(id: String) -> Dictionary:
	return DEFINITIONS.get(id, {})

static func record(id: String, dungeon: String, seed_value: int, origin := "hall") -> Dictionary:
	return {id = id, dungeon = dungeon, seed = seed_value, origin = origin,
		name = definition(dungeon).name, destroyed = []}


static func create_world(data: Dictionary) -> GameWorld:
	return TheoryWorld.new(data) if str(data.get("dungeon",""))=="theory_of_everything" else DungeonWorld.new(data)
