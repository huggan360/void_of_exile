extends Node
## Isolated 2D loader render; never loads a game world.
func _ready() -> void:
	get_viewport().disable_3d = true
	var layer := ResponsiveUILayer.new()
	add_child(layer)
	var root := layer.make_ui_root()
	var loader := preload("res://scripts/ui/ink_loading_screen.gd").new()
	root.add_child(loader)
	loader.set_process(false)
	var output := "/home/hugo/Desktop/Void of Exile Loading Frames"
	DirAccess.make_dir_recursive_absolute(output)
	var frame_index := 0
	for variant in 3:
		loader.set_destination(["The Tavern", "The Surface", "The Astral Reach"][variant])
		loader._select_variant(variant)
		for tick in 18:
			loader._elapsed = tick*0.2
			loader._show_frame(tick%6)
			loader._footsteps.advance(0.2)
			loader._vine.progress = float(tick+1)/18.0
			for frame in 2: await get_tree().process_frame
			await RenderingServer.frame_post_draw
			var shot := get_viewport().get_texture().get_image()
			shot.save_png(output+"/frame_%03d.png" % frame_index)
			if tick==10: shot.save_png("/home/hugo/Desktop/Void of Exile Loading %s.png" % ["Bow", "Wand", "Trident"][variant])
			frame_index += 1
	print("Rendered all three 2D weapon loops; no game world or 3D viewport.")
	get_tree().quit()
