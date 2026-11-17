extends Node
## Offline hover layout review; no character or account data is touched.
func _ready() -> void: run.call_deferred()

func run() -> void:
	GameAudio._disabled = true
	GameServer.set_physics_process(false)
	WorldServer.set_process(false)
	var view := SubViewport.new()
	view.size = Vector2i(1680, 900)
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(view)
	var root := Control.new()
	root.theme = UIStyle.theme()
	root.size = view.size
	view.add_child(root)
	var bg := ColorRect.new()
	bg.color = Color("101219")
	bg.size = view.size
	root.add_child(bg)
	var title := Label.new()
	title.text = "DIVINE SETS     I: 2 equipped     II: 3 equipped     III: 4 equipped"
	title.position = Vector2(28, 18)
	title.add_theme_font_size_override("font_size", 26)
	root.add_child(title)
	var examples := [
		["Iron", 1, "D_wand_ofiron", "Locked stages"],
		["Iron", 2, "D_wand_ofiron", "Two equipped pieces"],
		["Holy_Divine", 4, "D_robe_ofthedivine", "Health and mana focus"],
		["Madness", 4, "D_cloak_unlimitedmadness", "All three stages stack"]]
	for i in examples.size():
		var example: Array = examples[i]
		var stats := PlayerStats.new()
		stats.class_id = "wizard" if str(example[0]) != "Madness" else "merrow"
		for slot: String in PlayerStats.GEAR_SLOTS: stats.gear[slot] = null
		var count := 0
		for id: String in Items.DIVINE_SETS[example[0]]:
			var item := Items.make(id)
			if count < int(example[1]) and stats.gear[item.slot] == null and item.usable_by(stats.class_id):
				stats.gear[item.slot] = item
				count += 1
		var caption := Label.new()
		caption.text = str(example[3])
		caption.position = Vector2(24 + i * 414, 76)
		caption.add_theme_font_size_override("font_size", 19)
		root.add_child(caption)
		var tip := ItemTooltip.new()
		tip.stats = stats
		root.add_child(tip)
		tip.show_item(Items.make(str(example[2])))
		tip.set_process(false)
		tip.position = Vector2(24 + i * 414, 112)
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	view.get_texture().get_image().save_png("/home/hugo/tmp/divine_sets_tooltips.png")
	print("DIVINE SET TOOLTIP PREVIEW: /home/hugo/tmp/divine_sets_tooltips.png")
	for child in root.get_children(): child.queue_free()
	await get_tree().process_frame
	view.size = Vector2i(1280, 720)
	root.size = view.size
	var dense_bg := ColorRect.new()
	dense_bg.color = Color("101219")
	dense_bg.size = view.size
	root.add_child(dense_bg)
	var dense_stats := PlayerStats.new()
	dense_stats.class_id = "merrow"
	for slot: String in PlayerStats.GEAR_SLOTS: dense_stats.gear[slot] = null
	for id: String in Items.DIVINE_SETS.Madness:
		var item := Items.make(id)
		dense_stats.gear[item.slot] = item
	var dense := ItemTooltip.new()
	dense.stats = dense_stats
	root.add_child(dense)
	dense.show_item(Items.make("D_trident_ofmadness"))
	for frame in 16: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	view.get_texture().get_image().save_png("/home/hugo/tmp/divine_set_dense_tooltip.png")
	print("DENSE TOOLTIP: %.0f px at 720p" % dense.size.y)
	get_tree().quit()
