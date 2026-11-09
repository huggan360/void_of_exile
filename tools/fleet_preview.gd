extends Control
## The shipwright's window with sample ships, saved to --shots (art check).
func _ready() -> void:
	theme = UIStyle.theme()
	var back := ColorRect.new()
	back.color = Color("2a2438")
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(back)
	var panel := FleetPanel.new()
	add_child(panel)
	panel.position = Vector2(400, 60)
	panel.show()
	panel.set_process(false)
	panel._data = {dots = 1240, pad_clear = true, ships = [
		{id = 1, name = "The Astral Hearth", status = "stored"},
		{id = 2, name = "Moonwake", status = "deployed", location = "The Space", can_recall = true},
		{id = 3, name = "Old Bramble", status = "destroyed"}]}
	panel._render()
	await get_tree().create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	var args := OS.get_cmdline_user_args()
	var dir := "/tmp"
	for a in args: if a.begins_with("--shots="): dir = a.substr(8)
	get_viewport().get_texture().get_image().save_png(dir+"/fleet.png")
	get_tree().quit()
