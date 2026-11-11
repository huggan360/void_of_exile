extends Node
## Render the real startup handoff without loading a world.
func _ready() -> void:
	get_viewport().disable_3d = true
	var menu := Menus.new()
	add_child(menu)
	var intro := preload("res://scripts/ui/launch_intro.gd").new()
	add_child(intro)
	menu.prepare_startup()
	intro.play(menu)
	await get_tree().create_timer(3.2).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/home/hugo/Desktop/Void of Exile Logo Moving.png")
	await intro.finished
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/home/hugo/Desktop/Void of Exile Black Start Menu.png")
	assert(is_equal_approx(menu._start_logo.modulate.a, 1.0))
	for control in menu._start_actions: assert(is_equal_approx(control.modulate.a, 1.0))
	print("Logo handoff complete: menu logo and actions visible; 3D remains disabled.")
	get_tree().quit()
