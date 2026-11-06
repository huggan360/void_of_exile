extends Node

var checks := 0
var failures := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func progress(level: int, fraction: float) -> Dictionary:
	var total := 0
	for l in range(1, level): total += AccountLevels.xp_to_next(l)
	return AccountLevels.progress(total + roundi(AccountLevels.xp_to_next(level) * fraction))

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	var original := Account.data.duplicate(true)
	Account.data = {progress = progress(8, 0.45), rewards = [
		{level = 2, type = "start_item", id = "elixir_hp", count = 2, text = "Two more health elixirs"},
		{level = 7, type = "start_tier", slot = "armor", tier = 2, text = "Grade 2 starting armor"},
		{level = 9, type = "chest", text = "One more vault chest"},
		{level = 9, type = "slot", text = "One more character slot"}]}
	var canvas := CanvasLayer.new()
	add_child(canvas)
	var root := Control.new()
	root.size = Vector2(1600, 900)
	root.theme = UIStyle.theme()
	canvas.add_child(root)
	var bar := AccountBar.new()
	bar.position = Vector2(400, 20)
	root.add_child(bar)
	bar.toggle()
	await get_tree().create_timer(0.35).timeout
	check(bar._markers.size() == AccountLevels.MAX_LEVEL, "Track includes every account level")
	check(bar._tiles.size() == 5, "Every reward is represented, including multiple rewards at one level")
	check(absf(bar.progress_position() - bar._scroll.scroll_horizontal - bar._scroll.size.x * 0.5) <= 1,
		"Opening the drawer centers current fractional XP progress")
	var wheel := InputEventMouseButton.new()
	wheel.pressed = true
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	var previous := bar._scroll.scroll_horizontal
	bar._scroll_input(wheel)
	check(bar._scroll.scroll_horizontal == previous, "Wheel scrolling starts without an instant jump")
	await get_tree().create_timer(0.26).timeout
	check(bar._scroll.scroll_horizontal > previous, "Mouse wheel scrolls the track horizontally")
	var scrolled := bar._scroll.scroll_horizontal
	Account.data.progress = progress(8, 0.6)
	Account.changed.emit()
	check(bar._scroll.scroll_horizontal == scrolled, "Incoming XP does not interrupt manual browsing")
	bar._center_current()
	check(absf(bar.progress_position() - bar._scroll.scroll_horizontal - bar._scroll.size.x * 0.5) <= 1,
		"Your level action recenters the updated XP position")
	var chest: AccountBar.RewardTile
	var gear: AccountBar.RewardTile
	for tile in bar._tiles:
		if tile.reward.type == "chest": chest = tile
		if tile.reward.type == "start_tier": gear = tile
	check(chest != null and not chest.unlocked and gear.unlocked, "Reward state distinguishes upcoming rewards from earned ones")
	var tip: Control = chest._make_custom_tooltip(chest.tooltip_text)
	root.add_child(tip)
	await get_tree().process_frame
	await get_tree().process_frame
	check(tip.size.x <= 360 and tip.size.y < 320, "Reward hover stays a compact wrapped card")
	var labels := tip.find_children("*", "Label", true, false)
	check(labels.any(func(label: Label) -> bool: return label.text == "New vault chest"), "Chest hover explains the icon's reward")
	check(labels.any(func(label: Label) -> bool: return label.text.contains("level 9")), "Hover includes the unlock level")
	check((gear.get_child(0) as AccountBar.RewardIcon).item != null, "Item reward retains its item and texture for rendering")
	tip.queue_free()
	for level in [1, AccountLevels.MAX_LEVEL]:
		Account.data.progress = progress(level, 0.0)
		Account.changed.emit()
		await get_tree().process_frame
		bar._center_current()
		check(absf(bar.progress_position() - bar._scroll.scroll_horizontal - bar._scroll.size.x * 0.5) <= 1,
			"Endpoint level %d can still be centered" % level)
	check(bar._text == "MAX ACCOUNT LEVEL", "Maximum level has a clear terminal state")
	var unchanged_fill := bar._fill_tween
	Account.changed.emit()
	check(bar._fill_tween == unchanged_fill, "Unrelated account updates do not restart the fill animation")
	check(bar._drawer.size.y <= bar._clip.size.y + 1, "Journey footer fits inside its visible drawer")
	var clicks: Array[int] = []
	var behind := Button.new()
	behind.text = "Behind journey"
	behind.position = Vector2(600, 140)
	behind.size = Vector2(180, 40)
	behind.pressed.connect(func() -> void: clicks.append(1))
	root.add_child(behind)
	root.move_child(behind, 0)
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(620, 150)
	Input.parse_input_event(motion)
	await get_tree().process_frame
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = motion.position
	Input.parse_input_event(click)
	click = click.duplicate()
	click.pressed = false
	Input.parse_input_event(click)
	await get_tree().process_frame
	check(clicks.is_empty(), "Journey blocks clicks on controls behind its panel")
	var button := UIStyle.button("Stable text")
	root.add_child(button)
	var normal := button.get_theme_stylebox("normal")
	var pressed := button.get_theme_stylebox("pressed")
	check(normal.content_margin_top == pressed.content_margin_top and normal.content_margin_bottom == pressed.content_margin_bottom,
		"Pressed button labels keep the same position")
	button.pressed.emit()
	check(button.scale == Vector2.ONE, "Button presses do not shrink the label")

	check(UIStyle.font().get_font_name().contains("Bree Serif"), "Shared font uses Bree Serif")
	check(not UIStyle._font_file().multichannel_signed_distance_field and UIStyle._font_file().oversampling >= 3,
		"Emboldened serif uses oversampled raster rendering to avoid broken strokes")
	check((UIStyle.bold() as FontVariation).variation_embolden > (UIStyle.font() as FontVariation).variation_embolden,
		"Emphasized text is heavier than body copy")
	check(UIStyle.dialogue_panel() is StyleBoxEmpty, "NPC conversations have no background")
	var separator := UIStyle.dialogue_separator()
	var line := separator.get_theme_stylebox("separator") as StyleBoxLine
	check(line.thickness == 3 and line.color == UIStyle.GOLD, "Dialogue separator uses a thicker brass-gold line")
	separator.free()
	var material := UIStyle.panel() as StyleBoxTexture
	check(material.texture != UIStyle.ornament_panel().texture,
		"Ivy decoration is reserved for larger windows")
	bar.toggle()
	await get_tree().create_timer(0.3).timeout
	check(not bar.is_open() and is_zero_approx(bar._clip.size.y), "Closed drawer clips away its content")
	canvas.queue_free()
	await get_tree().process_frame
	Account.data = original
	print("ACCOUNT UI: %d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures else 0)
