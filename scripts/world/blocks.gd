class_name Blocks
## Terrain block types and their voxel textures. Generators write these ids into
## the voxel buffer; one shared mesher turns them into textured cubes.
##
## To add a texture: add a block id, then an entry in TEXTURES with a style
## (see shaders/voxel_terrain.gdshader for what each style does with its five
## colors) and a palette. Optional: emission (glow strength), roughness.

enum {
	AIR, STONE, DIRT, SAND, SEAFLOOR,
	GRASS, JUNGLE_GRASS, DESERT_SAND, DESERT_ROCK,
	ASH, DOOM_ROCK, EMBER,
	TUNDRA, SNOW, FOSEN_ROCK,
	BLUE_MOSS, BLUE_ROCK, BLUE_GLOW,
	HALL_FLOOR, HALL_TRIM, HALL_WALL, WARM_GLOW,
	LAVA, OBSIDIAN, ICE, SANDSTONE,
	GRAVEL, PAVING, RUIN_BRICK,
	DEEP_SAND, DEEP_STONE, DEEP_SLATE,
	TIMBER, PLASTER, ROOF_RED, ROOF_PINE, ROOF_SNOW, ADOBE, ROOF_TEAL, BRASS, WINDOW, WATER_TILE,
	RUNE_BLUE, RUNE_FROST, RUNE_SAND, RUNE_DARK, RUNE_FIRE,
	CAVE_MOSS, CAVE_CRACKED, CAVE_DIRT, CAVE_GRAVEL,
	CASTLE_STONE, CASTLE_MARBLE, CASTLE_LIGHT,
	COUNT,
}

# Texture styles (must match the constants in voxel_terrain.gdshader).
enum Style { SPECKLE, GRASS, SAND, COBBLE, CRACKED, SNOW, LAVA, TILES, BRICK, MOSS, CRYSTAL, ICE }

## block id: [style, [color a, b, c, d, e], emission, roughness]
const TEXTURES := {
	CASTLE_STONE: [Style.BRICK, [Color("24262b"), Color("1b1d22"), Color("0b0d12"), Color("393b41"), Color("202229")], 0.0, 0.72],
	CASTLE_MARBLE: [Style.TILES, [Color("c9cbc8"), Color("bfc2c0"), Color("91979b"), Color("e2e1d9"), Color("c7c9c5")], 0.0, 0.48],
	CASTLE_LIGHT: [Style.CRYSTAL, [Color("dadfe2"), Color("ffffff"), Color("ffffff"), Color.BLACK, Color.BLACK], 2.0, 0.3],
	CAVE_CRACKED: [Style.CRACKED, [Color("383d3c"), Color("303532"), Color("131c19"), Color("253326"), Color("42463e")]],
	CAVE_DIRT: [Style.SPECKLE, [Color("403528"), Color("352d24"), Color("4d4130"), Color("6a604b"), Color("2b2923")]],
	CAVE_GRAVEL: [Style.COBBLE, [Color("51554b"), Color("41463f"), Color("252d28"), Color("65685a"), Color("72705d")]],
	CAVE_MOSS: [Style.MOSS, [Color("354b32"), Color("293c2c"), Color("567141"), Color("8dba62"), Color("22242b")]],
	STONE: [Style.COBBLE, [Color(0.46, 0.46, 0.48), Color(0.39, 0.39, 0.41), Color(0.24, 0.24, 0.26), Color(0.5, 0.5, 0.5), Color(0.43, 0.42, 0.41)]],
	DIRT: [Style.SPECKLE, [Color(0.38, 0.27, 0.18), Color(0.33, 0.23, 0.15), Color(0.28, 0.2, 0.13), Color(0.5, 0.45, 0.4), Color(0.3, 0.22, 0.15)]],
	SAND: [Style.SAND, [Color(0.88, 0.81, 0.6), Color(0.84, 0.76, 0.55), Color(0.76, 0.68, 0.48), Color(0.98, 0.95, 0.9), Color(0.8, 0.72, 0.5)]],
	SEAFLOOR: [Style.SAND, [Color(0.62, 0.57, 0.44), Color(0.58, 0.53, 0.4), Color(0.5, 0.46, 0.35), Color(0.72, 0.7, 0.62), Color(0.55, 0.5, 0.4)]],
	GRASS: [Style.GRASS, [Color(0.36, 0.6, 0.26), Color(0.31, 0.54, 0.22), Color(0.45, 0.68, 0.3), Color(0.96, 0.86, 0.3), Color(0.38, 0.27, 0.18)]],
	JUNGLE_GRASS: [Style.GRASS, [Color(0.2, 0.5, 0.18), Color(0.15, 0.42, 0.15), Color(0.28, 0.58, 0.2), Color(0.92, 0.3, 0.42), Color(0.3, 0.22, 0.14)]],
	DESERT_SAND: [Style.SAND, [Color(0.9, 0.72, 0.44), Color(0.86, 0.67, 0.4), Color(0.76, 0.58, 0.34), Color(0.6, 0.45, 0.3), Color(0.8, 0.62, 0.38)]],
	DESERT_ROCK: [Style.SPECKLE, [Color(0.72, 0.52, 0.33), Color(0.66, 0.46, 0.29), Color(0.58, 0.4, 0.25), Color(0.8, 0.62, 0.42), Color(0.6, 0.42, 0.27)]],
	ASH: [Style.CRACKED, [Color(0.26, 0.23, 0.22), Color(0.21, 0.19, 0.18), Color(0.08, 0.06, 0.06), Color(1.0, 0.4, 0.1), Color(0.18, 0.16, 0.15)], 4.0],
	DOOM_ROCK: [Style.COBBLE, [Color(0.34, 0.17, 0.14), Color(0.28, 0.14, 0.12), Color(0.12, 0.06, 0.05), Color(0.38, 0.2, 0.16), Color(0.25, 0.12, 0.1)]],
	EMBER: [Style.LAVA, [Color(0.15, 0.05, 0.03), Color(1.0, 0.3, 0.05), Color(1.0, 0.7, 0.2), Color.BLACK, Color.BLACK], 3.0],
	TUNDRA: [Style.GRASS, [Color(0.47, 0.55, 0.48), Color(0.42, 0.5, 0.44), Color(0.56, 0.63, 0.56), Color(0.86, 0.9, 0.96), Color(0.45, 0.48, 0.55)]],
	SNOW: [Style.SNOW, [Color(0.93, 0.96, 0.99), Color(0.83, 0.89, 0.97), Color(0.38, 0.4, 0.46), Color(1, 1, 1), Color(0.45, 0.48, 0.55)], 1.0, 0.6],
	FOSEN_ROCK: [Style.COBBLE, [Color(0.47, 0.5, 0.57), Color(0.4, 0.43, 0.5), Color(0.27, 0.29, 0.35), Color(0.5, 0.52, 0.58), Color(0.44, 0.47, 0.53)]],
	BLUE_MOSS: [Style.MOSS, [Color(0.2, 0.33, 0.52), Color(0.17, 0.28, 0.46), Color(0.24, 0.4, 0.6), Color(0.3, 0.9, 1.0), Color(0.26, 0.28, 0.38)], 3.0],
	BLUE_ROCK: [Style.COBBLE, [Color(0.28, 0.3, 0.42), Color(0.24, 0.26, 0.37), Color(0.12, 0.13, 0.2), Color(0.3, 0.32, 0.45), Color(0.2, 0.22, 0.32)]],
	BLUE_GLOW: [Style.CRYSTAL, [Color(0.12, 0.55, 0.85), Color(0.3, 0.88, 1.0), Color(0.85, 1.0, 1.0), Color.BLACK, Color.BLACK], 2.5, 0.3],
	HALL_FLOOR: [Style.TILES, [Color(0.66, 0.62, 0.56), Color(0.6, 0.56, 0.5), Color(0.38, 0.34, 0.3), Color.BLACK, Color(0.7, 0.66, 0.6)], 0.0, 0.7],
	HALL_TRIM: [Style.TILES, [Color(0.47, 0.4, 0.33), Color(0.42, 0.36, 0.3), Color(0.27, 0.23, 0.19), Color.BLACK, Color(0.5, 0.43, 0.36)], 0.0, 0.7],
	HALL_WALL: [Style.BRICK, [Color(0.6, 0.55, 0.49), Color(0.53, 0.48, 0.43), Color(0.35, 0.31, 0.27), Color.BLACK, Color.BLACK]],
	WARM_GLOW: [Style.LAVA, [Color(0.4, 0.15, 0.05), Color(1.0, 0.55, 0.15), Color(1.0, 0.85, 0.45), Color.BLACK, Color.BLACK], 3.0],
	LAVA: [Style.LAVA, [Color(0.12, 0.04, 0.03), Color(1.0, 0.28, 0.04), Color(1.0, 0.75, 0.2), Color.BLACK, Color.BLACK], 4.0],
	OBSIDIAN: [Style.BRICK, [Color(0.1, 0.08, 0.12), Color(0.14, 0.1, 0.16), Color(0.04, 0.03, 0.05), Color.BLACK, Color.BLACK], 0.0, 0.35],
	ICE: [Style.ICE, [Color(0.7, 0.85, 0.95), Color(0.62, 0.8, 0.92), Color(0.92, 0.98, 1.0), Color.BLACK, Color.BLACK], 0.0, 0.15],
	GRAVEL: [Style.SPECKLE, [Color(0.55, 0.52, 0.48), Color(0.47, 0.45, 0.42), Color(0.62, 0.6, 0.56), Color(0.36, 0.34, 0.32), Color.BLACK]],
	PAVING: [Style.COBBLE, [Color(0.6, 0.58, 0.54), Color(0.53, 0.51, 0.48), Color(0.33, 0.31, 0.29), Color.BLACK, Color(0.57, 0.55, 0.5)], 0.0, 0.8],
	RUIN_BRICK: [Style.BRICK, [Color(0.52, 0.5, 0.46), Color(0.44, 0.43, 0.4), Color(0.28, 0.3, 0.24), Color.BLACK, Color.BLACK]],
	DEEP_SAND: [Style.SAND, [Color(0.96, 0.76, 0.32), Color(0.92, 0.7, 0.28), Color(0.84, 0.6, 0.22), Color(1.0, 0.92, 0.7), Color(0.88, 0.66, 0.26)]],
	DEEP_STONE: [Style.SPECKLE, [Color(0.13, 0.13, 0.15), Color(0.11, 0.11, 0.13), Color(0.16, 0.16, 0.19), Color(0.2, 0.2, 0.24), Color.BLACK]],
	DEEP_SLATE: [Style.COBBLE, [Color(0.15, 0.15, 0.18), Color(0.12, 0.12, 0.15), Color(0.05, 0.05, 0.07), Color.BLACK, Color(0.14, 0.14, 0.17)]],
	SANDSTONE: [Style.TILES, [Color(0.86, 0.7, 0.48), Color(0.8, 0.64, 0.43), Color(0.6, 0.46, 0.3), Color.BLACK, Color(0.9, 0.76, 0.55)]],
	TIMBER: [Style.BRICK, [Color("#715035"), Color("#62422c"), Color("#3d2c21"), Color("#a57a49"), Color("#805b3a")], 0],
	PLASTER: [Style.SPECKLE, [Color("#e3d0a5"), Color("#d8c294"), Color("#c4aa7a"), Color("#f0dfb8"), Color("#ccb48b")], 0],
	ROOF_RED: [Style.TILES, [Color("#9e463a"), Color("#843b36"), Color("#502b2b"), Color("#c06749"), Color("#a74b3b")], 0],
	ROOF_PINE: [Style.TILES, [Color("#365c50"), Color("#2d4c45"), Color("#1d3330"), Color("#58816b"), Color("#3e6755")], 0],
	ROOF_SNOW: [Style.TILES, [Color("#e9eff1"), Color("#c5d6e0"), Color("#65849d"), Color("#ffffff"), Color("#9eb6c7")], 0],
	ADOBE: [Style.BRICK, [Color("#d9af7c"), Color("#c99b67"), Color("#946c4d"), Color("#edc997"), Color("#c39a72")], 0],
	ROOF_TEAL: [Style.TILES, [Color("#408b92"), Color("#347479"), Color("#224e5a"), Color("#73b7b5"), Color("#3b858b")], 0],
	BRASS: [Style.TILES, [Color("#c9a255"), Color("#b58a42"), Color("#705530"), Color("#e9ca7e"), Color("#c49a51")], 0],
	WINDOW: [Style.ICE, [Color("#a4d9dd"), Color("#83bbc7"), Color("#41616d"), Color("#d9f4eb"), Color("#78a7b3")], 0.12],
	WATER_TILE: [Style.ICE, [Color("#376e8f"), Color("#4286a5"), Color("#254962"), Color("#7dc7db"), Color("#4a91b3")], 0.05],
	RUNE_BLUE: [Style.TILES, [Color("#2c526f"), Color("#31435d"), Color("#182a40"), Color("#78d8df"), Color("#315c78")], 0.08],
	RUNE_FROST: [Style.TILES, [Color("#b0d3df"), Color("#8caec7"), Color("#405b78"), Color("#d7ffff"), Color("#6b9bb8")], 0.08],
	RUNE_SAND: [Style.TILES, [Color("#d7b061"), Color("#b78b46"), Color("#64502d"), Color("#f4dc8a"), Color("#be9651")], 0.08],
	RUNE_DARK: [Style.TILES, [Color("#302b43"), Color("#272237"), Color("#111521"), Color("#9979aa"), Color("#42334e")], 0.08],
	RUNE_FIRE: [Style.TILES, [Color("#503032"), Color("#39262d"), Color("#191e26"), Color("#ed8a45"), Color("#694039")], 0.08],
}

## Blocks that give off light.
const GLOWING := [EMBER, BLUE_GLOW, WARM_GLOW, LAVA]

static var _mesher: VoxelMesherBlocky


## Blocks that burn whoever stands on them (lava pits).
## A single color for the block, used by the minimap.
static func map_color(id: int) -> Color:
	if id == AIR or not TEXTURES.has(id):
		return Color.BLACK
	return TEXTURES[id][1][0]


static func is_hazard(id: int) -> bool:
	return id == LAVA


static func mesher() -> VoxelMesherBlocky:
	if _mesher:
		return _mesher
	var lib := VoxelBlockyLibrary.new()
	var shader := preload("res://shaders/voxel_terrain.gdshader")
	for id in COUNT:
		if id == AIR:
			lib.add_model(VoxelBlockyModelEmpty.new())
			continue
		var tex: Array = TEXTURES[id]
		var mat := ShaderMaterial.new()
		mat.shader = shader
		mat.set_shader_parameter("style", tex[0])
		var colors: Array = tex[1]
		for i in colors.size():
			mat.set_shader_parameter("color_" + "abcde"[i], colors[i])
		mat.set_shader_parameter("emission", tex[2] if tex.size() > 2 else 0.0)
		mat.set_shader_parameter("roughness", tex[3] if tex.size() > 3 else 0.9)
		var cube := VoxelBlockyModelCube.new()
		cube.color = Color.WHITE  # the mesher's AO darkens this; the shader reads it
		cube.set_material_override(0, mat)
		lib.add_model(cube)
	lib.bake()
	_mesher = VoxelMesherBlocky.new()
	_mesher.library = lib
	_mesher.occlusion_enabled = true
	return _mesher
