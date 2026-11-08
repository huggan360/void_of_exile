extends Node
func _ready() -> void:
	var background := ColorRect.new()
	background.color = Color("101b2d")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var sight := SpaceCrosshair.new()
	sight.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(sight)
	sight.mode = "turret"
	await get_tree().process_frame
	var size := sight.size
	var points: Array[Vector2] = [size*Vector2(0.43, 0.47), size*Vector2(0.54, 0.44), size*Vector2(0.58, 0.54)]
	sight.set_locks(points, ["first", "second", "third"])
	for id in sight.lock_ids: sight._appeared[id] = Time.get_ticks_msec()+100
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/home/hugo/godot/tmp/session_qa/shots/markers_square.png")
	for id in sight.lock_ids: sight._appeared[id] = Time.get_ticks_msec()
	await get_tree().create_timer(0.14).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/home/hugo/godot/tmp/session_qa/shots/markers_twisting.png")
	await get_tree().create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/home/hugo/godot/tmp/session_qa/shots/markers_diamond.png")
	print("[markers] rendered acquisition, animation midpoint and locked state")
	get_tree().quit()
