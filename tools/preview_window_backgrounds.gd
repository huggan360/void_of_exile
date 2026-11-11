extends Node
## Render the real window controls without starting a world or an account session.
func _ready() -> void:
	await get_tree().process_frame
	var canvas := Control.new()
	canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.theme = UIStyle.theme()
	add_child(canvas)
	var backdrop := ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color("101827")
	canvas.add_child(backdrop)
	var options := OptionsPanel.new()
	canvas.add_child(options)
	options.open_page()
	for index in [0, 1, 2, 3, 4]:
		options._select_tab(index)
		for frame in 4: await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("/home/hugo/Desktop/Void of Exile Settings %s.png" % ["General", "Audio", "Video", "Graphics", "Controls"][index])
	options._select_tab(2)
	for frame in 3: await get_tree().process_frame
	options._mode.show_popup()
	for frame in 3: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/home/hugo/Desktop/Void of Exile Settings Dropdown.png")
	options._mode.get_popup().hide()
	options.hide()
	Account.data = {progress = AccountLevels.progress(5200), rewards = [
		{level = 4, type = "slot", text = "Character slot"},
		{level = 5, type = "chest", text = "Vault chest"},
		{level = 6, type = "slot", text = "Character slot"}]}
	var account := AccountBar.new()
	account.position = Vector2(370, 100)
	canvas.add_child(account)
	account.toggle()
	await get_tree().create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/home/hugo/Desktop/Void of Exile Account Journey.png")
	var reward_tip := AccountBar.RewardTile.new()
	reward_tip.reward = {level = 9, type = "slot", text = "Unlock an additional character slot for your account. Create another adventurer from the Characters tab in the Tavern."}
	var tooltip: Control = reward_tip._make_custom_tooltip("")
	reward_tip.free()
	canvas.add_child(tooltip)
	tooltip.position = Vector2(1210, 310)
	for frame in 6: await get_tree().process_frame
	tooltip.reset_size()
	for frame in 3: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	print("Reward tooltip size: ", tooltip.size)
	get_viewport().get_texture().get_image().save_png("/home/hugo/Desktop/Void of Exile Reward Tooltip.png")
	get_tree().quit()
