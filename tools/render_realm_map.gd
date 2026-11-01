extends Node
func _ready() -> void:
	var gen := IslandGenerator.new(20261031)
	var image := Image.create_empty(420, 420, false, Image.FORMAT_RGB8)
	var colors := {Biomes.OCEAN: Color("#203d54"), Biomes.BEACH: Color("#c3b888"), Biomes.WOODS: Color("#436d4c"),
		Biomes.JUNGLE: Color("#306253"), Biomes.DESERT: Color("#b78c59"), Biomes.DEEP_DESERT: Color("#c69c62"),
		Biomes.FOSEN: Color("#9cbac9"), Biomes.BLUELAY: Color("#405f8b"), Biomes.DOOM: Color("#704238"), Biomes.DEEP_DARK: Color("#393548")}
	for z in 420:
		for x in 420:
			var wx := x * 2 - 420
			var wz := z * 2 - 420
			var base := gen._base_column(wx, wz)
			var color: Color = colors.get(base.y, Color.BLACK)
			var feature := gen.feature_at(wx, wz)
			if feature != null and feature.type == "woodland_lake":
				color = Color("#447b96")
			image.set_pixel(x, z, color.lightened(maxf(0, base.x - 12) * 0.002))
	image.save_png("res://docs/realm_expansion/map_base.png")
	get_tree().quit()
