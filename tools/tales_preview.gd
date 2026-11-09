extends Control
## The Chronicler's book with sample progress, saved to --shots (art check).
func _ready() -> void:
	theme = UIStyle.theme()
	var back := ColorRect.new()
	back.color = Color("2a2438")
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(back)
	var social := SocialClient.new()
	add_child(social)
	var book := CampaignBrowser.new(social)
	add_child(book)
	book.position = Vector2(340, 40)
	book._runs = {theory_of_everything = {status = "done", stars_best = 4}, first_light = {status = "active", step = 2, stars_best = 1},
		lily_thief = {status = "done", stars_best = 5}}
	book._fill()
	await get_tree().create_timer(0.6).timeout
	await RenderingServer.frame_post_draw
	var dir := "/tmp"
	for a in OS.get_cmdline_user_args(): if a.begins_with("--shots="): dir = a.substr(8)
	get_viewport().get_texture().get_image().save_png(dir+"/tales.png")
	get_tree().quit()
