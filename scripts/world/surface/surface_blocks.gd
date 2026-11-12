class_name SurfaceBlocks
## Block types of the Surface's 0.25 m voxel terrain. Ids below Blocks.COUNT
## are the shared blocks (fortress walls, ruins and runes keep theirs); the
## Surface's own ground follows. All of them draw with one material
## (surface_terrain.gdshader), which finds each block's palette row from the
## atlas tile the mesher writes, so a terrain chunk is a single draw call.
##
## A palette: [style, [color a, b, c, d, e], emission, roughness]; the styles
## are the shader's (Blocks.Style plus STRATA, PLANKS, LEAVES).

enum Style { STRATA = 12, PLANKS = 13, LEAVES = 14 }

enum {
	GRASS = Blocks.COUNT, GRASS_LUSH, GRASS_DRY, MEADOW, FOREST_FLOOR, MOSS, SOIL, DIRT_PATH,
	COBBLE, DIRT_ROAD, PLAZA_STONE, FARM_SOIL, SAND_FINE, RIVERBED, RIVER_STONE,
	STRATA_GREY, STRATA_WARM, STRATA_DARK, STRATA_SAND, STRATA_FROST, SNOW_FINE, TUNDRA_FINE,
	ASH_FINE, BASALT, DESERT_FINE, DEEP_SAND_FINE, BLUE_MOSS_FINE, DEEP_STONE_FINE, JUNGLE_FINE,
	PLANKS, SEAFLOOR_FINE, CRACKED_EARTH, BLACK_SAND, YARD, ROAD_SAND, ROAD_ASH, ROAD_SNOW,
	GRAVEL_FINE, MOSS_ROCK, VINE, VINE_FLOWER, ROOTS, ICE_FINE,
	COUNT,
}

const S := Blocks.Style
const TEXTURES := {
	GRASS: [S.GRASS, [Color("5f9a3e"), Color("6fa848"), Color("86b955"), Color("f2e27a"), Color("6b4a30")], 0.0, 0.92],
	GRASS_LUSH: [S.GRASS, [Color("4f8c38"), Color("5d9b40"), Color("74b04e"), Color("f0a8c8"), Color("5e4029")], 0.0, 0.92],
	GRASS_DRY: [S.GRASS, [Color("8a9c48"), Color("9aa852"), Color("b0b45e"), Color("e6d070"), Color("6f5234")], 0.0, 0.92],
	MEADOW: [S.GRASS, [Color("78ad4c"), Color("88ba56"), Color("9cc860"), Color("f5f0f8"), Color("6b4a30")], 0.0, 0.92],
	FOREST_FLOOR: [S.GRASS, [Color("3f6b30"), Color("4b7835"), Color("6a6a34"), Color("b8742e"), Color("4a3524")], 0.0, 0.95],
	MOSS: [S.GRASS, [Color("4e7a34"), Color("5b8a3a"), Color("6f9a44"), Color("c8d070"), Color("57493a")], 0.0, 0.95],
	SOIL: [S.SPECKLE, [Color("6b4a30"), Color("5e4029"), Color("7a563a"), Color("8f8478"), Color.BLACK], 0.0, 0.95],
	DIRT_PATH: [S.SPECKLE, [Color("9a7a52"), Color("8c6c46"), Color("a88a60"), Color("b8b0a0"), Color.BLACK], 0.0, 0.95],
	COBBLE: [S.COBBLE, [Color("9a958a"), Color("888378"), Color("5a564f"), Color.BLACK, Color("a8a090")], 0.0, 0.8],
	DIRT_ROAD: [S.SPECKLE, [Color("a08058"), Color("93734e"), Color("ab8f66"), Color("8a8a80"), Color.BLACK], 0.0, 0.95],
	PLAZA_STONE: [S.TILES, [Color("b4ab98"), Color("a69d8a"), Color("6e665a"), Color.BLACK, Color("c0b8a4")], 0.0, 0.75],
	FARM_SOIL: [S.SPECKLE, [Color("6e4c30"), Color("5f412a"), Color("7d5838"), Color("96a050"), Color.BLACK], 0.0, 0.95],
	SAND_FINE: [S.SAND, [Color("e6d6a6"), Color("dccb98"), Color("c8b582"), Color("f8f2e4"), Color.BLACK], 0.0, 0.9],
	RIVERBED: [S.SPECKLE, [Color("7d786a"), Color("6c6a60"), Color("8e8a78"), Color("a8a490"), Color.BLACK], 0.0, 0.7],
	RIVER_STONE: [S.SPECKLE, [Color("8d8a84"), Color("7a7872"), Color("a09c94"), Color("6a8a50"), Color.BLACK], 0.0, 0.55],
	STRATA_GREY: [Style.STRATA, [Color("8a8680"), Color("7a7670"), Color("9a958c"), Color("b8b0a0"), Color("5f8a3e")], 0.0, 0.9],
	STRATA_WARM: [Style.STRATA, [Color("9a8670"), Color("8a7660"), Color("a8957c"), Color("c8b090"), Color("5f8a3e")], 0.0, 0.9],
	STRATA_DARK: [Style.STRATA, [Color("3e3a3a"), Color("332f30"), Color("4a4442"), Color("ff6a20"), Color("2e2a2a")], 0.0, 0.85],
	STRATA_SAND: [Style.STRATA, [Color("c8946a"), Color("b8845c"), Color("d8a87c"), Color("e8c8a0"), Color("c8a070")], 0.0, 0.9],
	STRATA_FROST: [Style.STRATA, [Color("7c828e"), Color("6c7280"), Color("8c929c"), Color("c8d8e8"), Color("e8f0f8")], 0.0, 0.85],
	SNOW_FINE: [S.SNOW, [Color("eef3f8"), Color("dde7f2"), Color("6a7280"), Color("ffffff"), Color("7c828e")], 0.8, 0.6],
	TUNDRA_FINE: [S.GRASS, [Color("788c74"), Color("6c806c"), Color("8a9a84"), Color("e8eef6"), Color("5c5a58")], 0.0, 0.9],
	ASH_FINE: [S.CRACKED, [Color("4a4240"), Color("3e3836"), Color("1a1414"), Color("ff6a1a"), Color("332d2b")], 3.0, 0.95],
	BASALT: [S.SPECKLE, [Color("3a3434"), Color("2e2a2a"), Color("484040"), Color("6a3020"), Color.BLACK], 0.0, 0.8],
	DESERT_FINE: [S.SAND, [Color("e8bc78"), Color("dcae6a"), Color("c89a58"), Color("f8e0b0"), Color.BLACK], 0.0, 0.9],
	DEEP_SAND_FINE: [S.SAND, [Color("f2c460"), Color("e8b450"), Color("d8a040"), Color("fff0c0"), Color.BLACK], 0.0, 0.9],
	BLUE_MOSS_FINE: [S.MOSS, [Color("34557e"), Color("2c4a70"), Color("3e6690"), Color("5ae6ff"), Color("3a4058")], 3.0, 0.9],
	DEEP_STONE_FINE: [S.SPECKLE, [Color("232327"), Color("1c1c20"), Color("2a2a30"), Color("38384a"), Color.BLACK], 0.0, 0.9],
	JUNGLE_FINE: [S.GRASS, [Color("2f7a2c"), Color("38882f"), Color("4a9a38"), Color("ee5a7a"), Color("4c3a24")], 0.0, 0.92],
	PLANKS: [Style.PLANKS, [Color("9a6e44"), Color("8a6240"), Color("4e3624"), Color("2a2a2a"), Color.BLACK], 0.0, 0.85],
	SEAFLOOR_FINE: [S.SAND, [Color("a89c78"), Color("9a8e6c"), Color("8a7e5e"), Color("c8c0a8"), Color.BLACK], 0.0, 0.9],
	CRACKED_EARTH: [S.CRACKED, [Color("c89a68"), Color("b88a5a"), Color("8a6440"), Color("8a6440"), Color.BLACK], 0.0, 0.95],
	BLACK_SAND: [S.SAND, [Color("3a3638"), Color("312e30"), Color("4a4446"), Color("ff7a30"), Color.BLACK], 0.0, 0.85],
	YARD: [S.GRASS, [Color("7a9a48"), Color("8a8a4e"), Color("9a8458"), Color("e8d880"), Color("6b4a30")], 0.0, 0.94],
	ROAD_SAND: [S.COBBLE, [Color("d8b080"), Color("c8a070"), Color("9a7650"), Color.BLACK, Color("e0bc8c")], 0.0, 0.85],
	ROAD_ASH: [S.COBBLE, [Color("4a4040"), Color("3c3434"), Color("1c1818"), Color.BLACK, Color("5a4a44")], 0.0, 0.85],
	ROAD_SNOW: [S.COBBLE, [Color("a8acb4"), Color("989ca4"), Color("6a6e78"), Color.BLACK, Color("dfe6ee")], 0.0, 0.75],
	GRAVEL_FINE: [S.SPECKLE, [Color("9a968c"), Color("86827a"), Color("aaa498"), Color("6e6a62"), Color.BLACK], 0.0, 0.9],
	MOSS_ROCK: [Style.STRATA, [Color("7e7c74"), Color("6e6c66"), Color("8e8a80"), Color("a8a490"), Color("5f8a3e")], 0.0, 0.9],
	VINE: [Style.LEAVES, [Color("3e7a32"), Color("4a8a38"), Color("5c9a42"), Color("e8e0f0"), Color("3e7a32")], 0.0, 0.9],
	VINE_FLOWER: [Style.LEAVES, [Color("447e34"), Color("508c3a"), Color("5c9a42"), Color("d878b0"), Color("447e34")], 0.0, 0.9],
	ROOTS: [S.SPECKLE, [Color("5a3e28"), Color("4e3624"), Color("6a4a30"), Color("7a6040"), Color.BLACK], 0.0, 0.95],
	ICE_FINE: [S.ICE, [Color("b8d8ec"), Color("a4cce4"), Color("e4f4ff"), Color.BLACK, Color.BLACK], 0.0, 0.15],
}

## Walk-through blocks (ivy on the walls).
const NO_COLLISION := [VINE, VINE_FLOWER]

static var _mesher: VoxelMesherBlocky
static var _material: ShaderMaterial


## Style, colors, emission, roughness of any block (shared or Surface).
static func texture(id: int) -> Array:
	if TEXTURES.has(id): return TEXTURES[id]
	if Blocks.TEXTURES.has(id): return Blocks.TEXTURES[id]
	return [S.SPECKLE, [Color.MAGENTA, Color.MAGENTA, Color.MAGENTA, Color.MAGENTA, Color.MAGENTA], 0.0, 0.9]


static func map_color(id: int) -> Color:
	if id == Blocks.AIR: return Color.BLACK
	return texture(id)[1][0]


static func mesher() -> VoxelMesherBlocky:
	if _mesher: return _mesher
	var lib := VoxelBlockyLibrary.new()
	for id in COUNT:
		if id == Blocks.AIR:
			lib.add_model(VoxelBlockyModelEmpty.new())
			continue
		var cube := VoxelBlockyModelCube.new()
		cube.color = Color.WHITE  # the mesher's ambient occlusion darkens this; the shader reads it
		cube.atlas_size_in_tiles = Vector2i(COUNT * 2, 1)
		for side in 6: cube.set_tile(side, Vector2i(id * 2, 0))
		if id in NO_COLLISION:
			cube.collision_aabbs = []
		lib.add_model(cube)
	lib.bake()
	_mesher = VoxelMesherBlocky.new()
	_mesher.library = lib
	_mesher.occlusion_enabled = true
	return _mesher


## The one material for the whole terrain.
static func material() -> ShaderMaterial:
	if _material: return _material
	var img := Image.create_empty(COUNT, 6, false, Image.FORMAT_RGBAF)
	for id in COUNT:
		var tex := texture(id)
		var colors: Array = tex[1]
		for i in 5:
			img.set_pixel(id, i, colors[i] if i < colors.size() else Color.BLACK)
		var emission: float = tex[2] if tex.size() > 2 else 0.0
		var rough: float = tex[3] if tex.size() > 3 else 0.9
		img.set_pixel(id, 5, Color(int(tex[0]) / 255.0, emission / 8.0, rough, 1.0))
	_material = ShaderMaterial.new()
	_material.shader = preload("res://shaders/surface_terrain.gdshader")
	_material.set_shader_parameter("palette", ImageTexture.create_from_image(img))
	_material.set_shader_parameter("atlas_width", float(COUNT * 2))
	return _material
