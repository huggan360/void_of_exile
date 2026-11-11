extends Node
func _ready() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.theme = UIStyle.theme()
	add_child(root)
	var background := ColorRect.new()
	background.color = Color("101010")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(background)
	var row := HBoxContainer.new()
	row.position = Vector2(300, 230)
	row.add_theme_constant_override("separation", 40)
	root.add_child(row)
	for percent in [0.25, 0.6, 0.95]:
		var column := VBoxContainer.new()
		column.add_theme_constant_override("separation", 10)
		row.add_child(column)
		var wheel := XpRing.new()
		column.add_child(wheel)
		wheel.set_values(24, percent)
		wheel.set_process(false)
		var slots := GridContainer.new()
		slots.columns = 2
		slots.add_theme_constant_override("h_separation", int(ItemSlot.SLOT_GAP))
		slots.add_theme_constant_override("v_separation", int(ItemSlot.SLOT_GAP))
		column.add_child(slots)
		for item_id in ["elixir_hp", "elixir_mp", "story_starcoil", "story_aether_heart", "story_wizard_starball", "story_nav_core"]:
			var slot := ItemSlot.new()
			slots.add_child(slot)
			slot.set_item(Items.make(item_id))
	var map := Minimap.new()
	map.position = Vector2(940, 180)
	map.size = map.custom_minimum_size
	root.add_child(map)
	map.set_process(false)
	var image := Image.create_empty(16, 16, false, Image.FORMAT_RGB8)
	image.fill(Color("34452d"))
	for y in 16:
		for x in 16:
			if absi(x - y) < 2: image.set_pixel(x, y, Color("466078"))
	map._material.set_shader_parameter("map_tex", ImageTexture.create_from_image(image))
	map._material.set_shader_parameter("explored_tex", map._all_explored)
	map._material.set_shader_parameter("center", Vector2(256,256))
	for frame in 5: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/home/hugo/Desktop/Void of Exile Level Wheel and Minimap.png")
	get_tree().quit()
