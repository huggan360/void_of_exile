extends Node
func _ready() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.theme = UIStyle.theme()
	add_child(root)
	var backdrop := ColorRect.new()
	backdrop.color = Color("101b2d")
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(backdrop)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var card := InteractionCard.new()
	card.opened = true
	var panel := FleetPanel.new()
	panel.interaction = card
	center.add_child(panel)
	panel.show()
	panel.receive({dots = 9000, price = 500, pad_clear = false, ships = [
		{id = 17, name = "Battleship", status = "stored", can_recall = false},
		{id = 18, name = "Battleship", status = "deployed", location = "Verdance shipyard", can_recall = true},
		{id = 19, name = "Battleship", status = "destroyed", can_recall = false}]})
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/home/hugo/godot/tmp/fleet_qa/shop_occupied.png")
	panel._data.pad_clear = true
	panel._render(true)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/home/hugo/godot/tmp/fleet_qa/shop_clear.png")
	print("[fleet-preview] Rendered occupied and clear pad states")
	get_tree().quit()
