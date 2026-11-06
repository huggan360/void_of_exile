extends SceneTree
## Convert generated artwork to the native UI pixel grid. Mirrored tile
## quadrants give matching opposite edges and preserve the source palette.

func _init() -> void:
	var tile := Image.load_from_file(ProjectSettings.globalize_path("res://assets/ui/ui_blue_stone_tile_source.png"))
	tile.convert(Image.FORMAT_RGBA8)
	tile.resize(128, 128, Image.INTERPOLATE_NEAREST)
	var seamless := Image.create_empty(256, 256, false, Image.FORMAT_RGBA8)
	for y in 2:
		for x in 2:
			var quadrant := tile.duplicate() as Image
			if x == 1: quadrant.flip_x()
			if y == 1: quadrant.flip_y()
			seamless.blit_rect(quadrant, Rect2i(0, 0, 128, 128), Vector2i(x * 128, y * 128))
	assert(seamless.save_png("res://assets/ui/ui_blue_stone_tile.png") == OK)
	var stone := Image.load_from_file(ProjectSettings.globalize_path("res://assets/ui/ui_stone_button.png")).get_region(Rect2i(28, 152, 2116, 398))
	stone.resize(192, 48, Image.INTERPOLATE_NEAREST)
	_bake_panel(seamless, stone, 9, "res://assets/ui/ui_blue_stone_panel.png")
	var ivy := Image.load_from_file(ProjectSettings.globalize_path("res://assets/ui/ui_ivy_panel.png")).get_region(Rect2i(14, 12, 1223, 1219))
	ivy.resize(192, 192, Image.INTERPOLATE_NEAREST)
	_bake_panel(seamless, ivy, 48, "res://assets/ui/ui_blue_ivy_panel.png")
	var slot := Image.load_from_file(ProjectSettings.globalize_path("res://assets/ui/ui_item_slot_source.png"))
	slot.resize(60, 60, Image.INTERPOLATE_NEAREST)
	assert(slot.save_png("res://assets/ui/ui_item_slot.png") == OK)
	print("UI textures baked: seamless fill, stone/ivy nine-patches, dedicated 60px item slot")
	quit()


func _bake_panel(fill: Image, frame: Image, edge: int, path: String) -> void:
	var size := fill.get_width() + edge * 2
	var panel := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	for y in size:
		for x in size:
			if x >= edge and x < size - edge and y >= edge and y < size - edge:
				panel.set_pixel(x, y, fill.get_pixel(x - edge, y - edge))
			else:
				var sx := x if x < edge else frame.get_width() - (size - x) if x >= size - edge else edge + posmod(x - edge, frame.get_width() - edge * 2)
				var sy := y if y < edge else frame.get_height() - (size - y) if y >= size - edge else edge + posmod(y - edge, frame.get_height() - edge * 2)
				panel.set_pixel(x, y, frame.get_pixel(sx, sy))
	assert(panel.save_png(path) == OK)
