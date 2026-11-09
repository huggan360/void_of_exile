extends Control
## The centered shipwright window; --overflow exercises a long fleet.
func _ready() -> void:
	var layer := ResponsiveUILayer.new()
	add_child(layer)
	var ui := layer.make_ui_root()
	ui.theme = UIStyle.theme()
	var back := ColorRect.new()
	back.color = Color("2a2438")
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(back)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(center)
	var panel := FleetPanel.new()
	center.add_child(panel)
	panel.set_process(false)
	panel.show()
	panel._data = {dots = 1240, pad_clear = true, ships = [
		{id = 1, name = "The Astral Hearth", status = "stored"},
		{id = 2, name = "Moonwake", status = "deployed", location = "The Space", can_recall = true},
		{id = 3, name = "Old Bramble", status = "destroyed"}]}
	var args := OS.get_cmdline_user_args()
	if args.has("--overflow"):
		for i in 10: panel._data.ships.append({id = 4+i, name = "Battleship %d" % (4+i), status = "stored"})
	panel._render()
	await get_tree().create_timer(0.5).timeout
	var rect := panel.get_global_rect()
	var centered := rect.get_center().distance_to(ui.size*0.5)<1.0
	print("[fleet-preview] rect=", rect, " centered=", centered)
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		var dir := "/tmp"
		for a in args: if a.begins_with("--shots="): dir = a.substr(8)
		get_viewport().get_texture().get_image().save_png(dir+"/fleet.png")
	get_tree().quit(0 if centered and rect.size==CampaignBrowser.SIZE else 1)
