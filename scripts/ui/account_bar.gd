class_name AccountBar
extends Control
## Ornate account XP meter and an icon-led, horizontally scrollable journey.

const BAR_SIZE := Vector2(700, 110)
const HEADER_HEIGHT := 110.0
const DRAWER_WIDTH := 900.0
const DRAWER_HEIGHT := 380.0
const TRACK_INSET := DRAWER_WIDTH * 0.5
const CELL := 140.0
const TRACK_HEIGHT := 190.0
const YELLOW := Color("f9d882")
const RED := Color("dc883e")
const INK := Color("10131f")
const MUTED_GOLD := Color("886438")

var _frame_texture: Texture2D
var dots := DotsCounter.new()
var _bar := Control.new()
var _drawer := PanelContainer.new()
var _clip := Control.new()
var _scroll := ScrollContainer.new()
var _backdrop := ColorRect.new()
var _scroll_tween: Tween
var _scroll_target := 0.0
var _track := Control.new()
var _progress := Label.new()
var _open := false
var _fill := 0.0
var _shown_fill := 0.0
var _shown_level := -1
var _fill_tween: Tween
var _drawer_tween: Tween
var _text := ""
var _hovered := false
var _reward_key := ""
var _markers: Array[LevelDiamond] = []
var _tiles: Array[RewardTile] = []


## The few non-item rewards get pictograms rather than explanatory text.
class RewardIcon extends Control:
	var reward := {}
	var item: Item
	var _art := ItemIcon.new()
	func _ready() -> void:
		# Keep the texture's owner alive for retained CanvasItem draw commands.
		item = AccountBar.reward_item(reward)
		_art.outline_color = Color(0.85,0.92,1.0,0.8)
		add_child(_art)
	func _draw() -> void:
		var c := size * 0.5
		var art_scale := 6 if size.y >= 76 else 4
		if item:
			var extent := Vector2.ONE * (64 if size.y >= 76 else 44)
			var at := c - extent * 0.5
			_art.position = at
			_art.size = extent
			_art.show_item(item)
		elif str(reward.get("type", "")) == "chest":
			PixelArt.draw_rows(self, c - Vector2(6, 5.5) * art_scale, PackedStringArray([
				"..oooooooo..", ".oggggggggo.", "ogYgYYgYYggo", "ogYgYYgYYggo",
				"ogYggggggggo", "oooooooooooo", "ogYggooggYgo", "ogYggYYggYgo",
				"ogYggYYggYgo", "ogYggggggYgo", ".oooooooooo."]),
				{"o": Color("17131d"), "g": Color("935528"), "Y": YELLOW}, art_scale)
		else:
			PixelArt.draw_rows(self, c - Vector2(6, 5.5) * art_scale, PackedStringArray([
				"...oooo.....", "..ogYYYg....", "..oYYYYg....", "...oYYg.....",
				"....oo......", "..oggggo..Y.", ".ogYYYYgoYYY", "ogYYYYYYogY.",
				"ogYYYYYYgo..", "ogYYYYYYgo..", ".oooooooo..."]),
				{"o": Color("17131d"), "g": Color("935528"), "Y": YELLOW}, art_scale)



class RewardTile extends PanelContainer:
	var reward := {}
	var unlocked := false
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_HELP
		tooltip_text = str(reward.get("text", "Reward"))
		add_theme_stylebox_override("panel", UIStyle.panel_outlined(UIStyle.ACCENT) if unlocked else UIStyle.panel())
		var icon := RewardIcon.new()
		icon.reward = reward
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.modulate.a = 1.0 if unlocked else 0.65
		add_child(icon)
		if int(reward.get("count", 1)) > 1:
			var count := UIStyle.label("×%d" % int(reward.count), 16, YELLOW)
			count.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
			count.grow_horizontal = Control.GROW_DIRECTION_BEGIN
			count.grow_vertical = Control.GROW_DIRECTION_BEGIN
			count.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(count)
	func _make_custom_tooltip(_for_text: String) -> Object:
		var panel := PanelContainer.new()
		panel.add_theme_stylebox_override("panel", UIStyle.panel_outlined(UIStyle.GOLD))
		panel.custom_minimum_size.x = 340
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var col := VBoxContainer.new()
		col.custom_minimum_size.x = 308
		col.add_theme_constant_override("separation", 8)
		panel.add_child(col)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		col.add_child(row)
		var icon := RewardIcon.new()
		icon.reward = reward
		icon.custom_minimum_size = Vector2(64, 64)
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		row.add_child(icon)
		var title := UIStyle.heading(AccountBar.reward_title(reward), 21)
		title.custom_minimum_size.x = 220
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_child(title)
		var detail := UIStyle.label(str(reward.get("text", "")), 17)
		detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(detail)
		var status := UIStyle.label("Unlocked" if unlocked else "Unlocks at account level %d" % int(reward.level), 15, UIStyle.GOOD if unlocked else UIStyle.TEXT_DIM)
		status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(status)
		return panel


static func reward_item(reward: Dictionary) -> Item:
	match str(reward.get("type", "")):
		"start_item":
			return Items.make(str(reward.id)) if Items.exists(str(reward.get("id", ""))) else null
		"start_tier":
			var class_id := str(Account.character().get("class", "archer"))
			return PlayerClasses.gear_item(class_id, str(reward.get("slot", "weapon")), int(reward.get("tier", 1)))
	return null


static func reward_title(reward: Dictionary) -> String:
	match str(reward.get("type", "")):
		"chest": return "New vault chest"
		"slot": return "Character slot"
		"start_tier": return "Starting %s - Grade %d" % [str(reward.get("slot", "gear")), int(reward.get("tier", 1))]
		"start_item":
			var item := reward_item(reward)
			return item.item_name if item else "Starting supplies"
		"start": return "Your journey begins"
	return "Account reward"


func _ready() -> void:
	custom_minimum_size = BAR_SIZE
	_frame_texture = load("res://assets/ui/account_xp_frame.png")
	_bar.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_index = 10
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar.size = BAR_SIZE
	_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	_bar.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_bar.tooltip_text = "Account journey"
	_bar.draw.connect(_draw_bar)
	_bar.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			toggle()
			_bar.accept_event())
	_bar.mouse_entered.connect(_set_hovered.bind(true))
	_bar.mouse_exited.connect(_set_hovered.bind(false))
	add_child(_bar)
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_backdrop.color = Color(0.02, 0.025, 0.04, 0.16)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_backdrop.z_index = 49
	_backdrop.hide()
	get_parent().add_child(_backdrop)
	_backdrop.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			if _open: toggle()
		_backdrop.accept_event())
	_clip.position = Vector2((BAR_SIZE.x - DRAWER_WIDTH) * 0.5, HEADER_HEIGHT + 8)
	_clip.size = Vector2(DRAWER_WIDTH, 0)
	_clip.clip_contents = true
	_clip.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_clip)
	_drawer.size = Vector2(DRAWER_WIDTH, DRAWER_HEIGHT)
	_drawer.mouse_filter = Control.MOUSE_FILTER_STOP
	_drawer.add_theme_stylebox_override("panel", UIStyle.ornament_panel())
	_clip.add_child(_drawer)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	_drawer.add_child(col)
	var header := HBoxContainer.new()
	var title := UIStyle.heading("Account journey", 24)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	UIStyle.text(_progress, 18, YELLOW)
	header.add_child(_progress)
	var close := UIStyle.button("×")
	close.tooltip_text = "Close rewards"
	close.pressed.connect(toggle)
	header.add_child(close)
	col.add_child(header)
	_scroll.custom_minimum_size = Vector2(0, TRACK_HEIGHT + 18)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.mouse_force_pass_scroll_events = false
	_scroll.gui_input.connect(_scroll_input)
	_scroll.get_h_scroll_bar().gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and _scroll_tween:
			_scroll_tween.kill())
	_track.custom_minimum_size = Vector2(TRACK_INSET * 2 + (AccountLevels.MAX_LEVEL - 1) * CELL, TRACK_HEIGHT)
	_track.mouse_filter = Control.MOUSE_FILTER_PASS
	_track.gui_input.connect(_scroll_input)
	_track.draw.connect(_draw_track)
	_scroll.add_child(_track)
	col.add_child(_scroll)
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 8)
	var previous := UIStyle.button("‹")
	previous.tooltip_text = "Previous rewards"
	previous.pressed.connect(func() -> void: _pan_scroll(-CELL * 2))
	footer.add_child(previous)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	footer.add_child(spacer)
	var current := UIStyle.button("Your level")
	current.pressed.connect(func() -> void: _center_current(true))
	footer.add_child(current)
	var next := UIStyle.button("›")
	next.tooltip_text = "Next rewards"
	next.pressed.connect(func() -> void: _pan_scroll(CELL * 2))
	footer.add_child(next)
	col.add_child(footer)
	_drawer.position.y = -DRAWER_HEIGHT
	Account.changed.connect(_refresh)
	_refresh()


func _scroll_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_LEFT, MOUSE_BUTTON_WHEEL_RIGHT]:
		_pan_scroll(CELL * 0.65 * event.factor * (1 if event.button_index in [MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_RIGHT] else -1))
		_scroll.accept_event()
	elif event is InputEventPanGesture:
		_pan_scroll((event.delta.x + event.delta.y) * 24.0)
		_scroll.accept_event()


func _scroll_to(value: float, smooth: bool) -> void:
	if _scroll_tween: _scroll_tween.kill()
	var bar := _scroll.get_h_scroll_bar()
	_scroll_target = clampf(value, bar.min_value, maxf(bar.min_value, bar.max_value - bar.page))
	if smooth:
		_scroll_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_scroll_tween.tween_property(_scroll, "scroll_horizontal", roundi(_scroll_target), 0.22).from(_scroll.scroll_horizontal)
	else:
		_scroll.scroll_horizontal = roundi(_scroll_target)


func _pan_scroll(amount: float) -> void:
	var start := _scroll_target if _scroll_tween and _scroll_tween.is_running() else float(_scroll.scroll_horizontal)
	_scroll_to(start + amount, true)


func handle_scroll(event: InputEvent) -> bool:
	if not _open or not _clip.get_global_rect().has_point(_clip.get_global_mouse_position()): return false
	if event is InputEventPanGesture or event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_LEFT, MOUSE_BUTTON_WHEEL_RIGHT]:
		_scroll_input(event)
		return true
	return false


func _set_hovered(value: bool) -> void:
	_hovered = value
	_bar.queue_redraw()


func toggle() -> void:
	_open = not _open
	if _drawer_tween: _drawer_tween.kill()
	if _open:
		# GUI picking follows tree order, independently of visual z_index.
		_backdrop.move_to_front()
		move_to_front()
		_backdrop.show()
		z_index = 50
		_fill_track()
		_center_current.call_deferred()
	else:
		if _scroll_tween: _scroll_tween.kill()
	_drawer_tween = create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_drawer_tween.tween_property(_clip, "size:y", DRAWER_HEIGHT if _open else 0.0, 0.25)
	_drawer_tween.tween_property(_drawer, "position:y", 0.0 if _open else -DRAWER_HEIGHT, 0.25)
	if not _open:
		_drawer_tween.chain().tween_callback(func() -> void:
			_backdrop.hide()
			z_index = 10)


func is_open() -> bool:
	return _open


func progress_position() -> float:
	var level := int(Account.progress().level)
	return minf(level_position(level) + _fill * CELL, level_position(AccountLevels.MAX_LEVEL))


static func level_position(level: int) -> float:
	return TRACK_INSET + (level - 1) * CELL


func _center_current(smooth := false) -> void:
	_scroll_to(progress_position() - _scroll.size.x * 0.5, smooth)


func _refresh() -> void:
	var p := Account.progress()
	var level := int(p.level)
	var previous_fill := _fill
	var previous_level := _shown_level
	_fill = 1.0 if level >= AccountLevels.MAX_LEVEL else clampf(float(p.into) / maxf(1.0, float(p.needed)), 0.0, 1.0)
	_text = "MAX ACCOUNT LEVEL" if level >= AccountLevels.MAX_LEVEL else "%s / %s  Account XP" % [_grouped(int(p.into)), _grouped(int(p.needed))]
	_progress.text = "Level %d    %d%% XP" % [level, roundi(_fill * 100)]
	if _shown_level < 0:
		_shown_fill = _fill
	elif previous_level != level or not is_equal_approx(previous_fill, _fill):
		if _fill_tween: _fill_tween.kill()
		_fill_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_fill_tween.tween_property(self, "_shown_fill", _fill, 0.3).from(_shown_fill)
	_shown_level = level
	_bar.queue_redraw()
	_track.queue_redraw()
	if _open: _fill_track()


func _fill_track() -> void:
	var key := JSON.stringify([Account.rewards(), Account.character().get("class", "archer"), int(Account.progress().level)])
	if key == _reward_key: return
	_reward_key = key
	for child in _track.get_children():
		_track.remove_child(child)
		child.queue_free()
	_markers.clear()
	_tiles.clear()
	var by_level := {1: [{type = "start", level = 1, text = "Create your characters and explore the realms."}]}
	for reward: Dictionary in Account.rewards():
		var l := int(reward.level)
		if not by_level.has(l): by_level[l] = []
		by_level[l].append(reward)
	var current := int(Account.progress().level)
	for level in range(1, AccountLevels.MAX_LEVEL + 1):
		var marker := LevelDiamond.new(46.0)
		marker.position = Vector2(level_position(level) - 23, 29)
		marker.size = Vector2(46, 46)
		marker.level = level
		marker.fill = Color("775128") if level <= current else Color("202638")
		marker.tooltip_text = "Account level %d" % level
		_track.add_child(marker)
		_markers.append(marker)
		var rewards: Array = by_level.get(level, [])
		for i in rewards.size():
			var tile := RewardTile.new()
			tile.reward = rewards[i]
			tile.unlocked = level <= current
			tile.position = Vector2(level_position(level) - rewards.size() * 38 + i * 76, 104)
			tile.size = Vector2(68, 68)
			_track.add_child(tile)
			_tiles.append(tile)
	_track.queue_redraw()


func _process(_delta: float) -> void:
	if _fill_tween and _fill_tween.is_running(): _bar.queue_redraw()


func _draw_track() -> void:
	var start := Vector2(level_position(1), 52)
	var end := Vector2(level_position(AccountLevels.MAX_LEVEL), 52)
	_track.draw_line(start, end, Color("34323b"), 10, true)
	_track.draw_line(start + Vector2(0, -4), end + Vector2(0, -4), MUTED_GOLD, 1, true)
	_track.draw_line(start, Vector2(progress_position(), 52), YELLOW, 6, true)
	for tile in _tiles:
		var x := level_position(int(tile.reward.level))
		_track.draw_line(Vector2(x, 77), Vector2(x, 100), MUTED_GOLD, 1, true)
	var x := progress_position()
	_track.draw_circle(Vector2(x, 52), 8, Color(1, 0.85, 0.45, 0.16))
	_track.draw_circle(Vector2(x, 52), 4, Color("fff1bc"))
	var caption := "MAX" if int(Account.progress().level) == AccountLevels.MAX_LEVEL else "YOU"
	_track.draw_string(UIStyle.bold(), Vector2(x - 15, 17), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, YELLOW)


func _draw_bar() -> void:
	if not _frame_texture: return
	# The generated atlas preserves the supplied pixel-art frame; runtime
	# XP and type stay independent of its decorative gold and blank badge.
	_bar.draw_texture_rect_region(_frame_texture, Rect2(Vector2.ZERO, BAR_SIZE), Rect2(64, 184, 2048, 320))
	var inset := Rect2(52, 45, 512, 21)
	var width := floorf(inset.size.x * _shown_fill)
	if width > 0:
		var steps := maxi(1, ceili(width / 4.0))
		for i in steps:
			var x0 := floorf(width * i / steps)
			var x1 := floorf(width * (i + 1) / steps)
			var color := YELLOW.lerp(RED, float(i) / maxf(1, steps - 1))
			_bar.draw_rect(Rect2(inset.position + Vector2(x0, 0), Vector2(x1 - x0, inset.size.y)), color)
		_bar.draw_rect(Rect2(inset.position, Vector2(width, 3)), Color("fff1b8"))
		_bar.draw_rect(Rect2(inset.position + Vector2(0, 18), Vector2(width, 3)), Color("a95b28"))
	var font := UIStyle.bold()
	var fs := 22
	var text_w := font.get_string_size(_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var pos := Vector2(inset.get_center().x - text_w * 0.5, 63)
	_bar.draw_string_outline(font, pos, _text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 3, Color("0b0b12"))
	_bar.draw_string(font, pos, _text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UIStyle.TEXT)
	var center := Vector2(621, 54)
	var label := str(maxi(1, _shown_level))
	var number_size := 32 if label.length() < 3 else 26
	var number_w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, number_size).x
	_bar.draw_string_outline(font, center + Vector2(-number_w * 0.5, 18), label, HORIZONTAL_ALIGNMENT_LEFT, -1, number_size, 2, INK)
	_bar.draw_string(font, center + Vector2(-number_w * 0.5, 18), label, HORIZONTAL_ALIGNMENT_LEFT, -1, number_size, YELLOW)
	_bar.draw_string(font, center + Vector2(-10, -9), "Lv", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, YELLOW)


static func _grouped(n: int) -> String:
	var s := str(n)
	var out := ""
	while s.length() > 3:
		out = "," + s.right(3) + out
		s = s.left(s.length() - 3)
	return s + out


func _exit_tree() -> void:
	if is_instance_valid(_backdrop): _backdrop.queue_free()
