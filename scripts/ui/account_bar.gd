class_name AccountBar
extends VBoxContainer
## Top center of the HUD: the account's XP bar (it warms from yellow to red
## as it fills) with the account level in a diamond at its right end. The
## little arrow under it rolls a drawer down: the reward track, one row per
## level, showing what you've unlocked and what's coming. Levels without a
## reward yet are left open for things the game doesn't have yet.

const BAR_SIZE := Vector2(620, 24)
const DRAWER_HEIGHT := 420.0
const SHOW_LEVELS := 50
const YELLOW := Color(1.0, 0.86, 0.25)
const RED := Color(0.92, 0.18, 0.12)

var _bar := Control.new()
var _diamond := LevelDiamond.new(52.0)
var _arrow := Button.new()
var _drawer := PanelContainer.new()
var _clip := Control.new()
var _rows := VBoxContainer.new()
var _next := UIStyle.label("", 16, UIStyle.TEXT_DIM)
var _open := false
var _fill := 0.0
var _shown_fill := 0.0
var _text := ""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", 0)
	var top := HBoxContainer.new()
	top.alignment = BoxContainer.ALIGNMENT_CENTER
	top.add_theme_constant_override("separation", -6)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top)
	_bar.custom_minimum_size = BAR_SIZE
	_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_bar.mouse_filter = Control.MOUSE_FILTER_PASS
	_bar.draw.connect(_draw_bar)
	top.add_child(_bar)
	top.add_child(_diamond)
	_arrow.text = "▼"
	_arrow.flat = true
	_arrow.focus_mode = Control.FOCUS_NONE
	_arrow.custom_minimum_size = Vector2(46, 22)
	_arrow.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_arrow.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_arrow.tooltip_text = "Account rewards"
	UIStyle.text(_arrow, 16, UIStyle.GOLD)
	_arrow.pressed.connect(toggle)
	add_child(_arrow)
	# The drawer: clipped so it can roll down and up.
	_clip.clip_contents = true
	_clip.custom_minimum_size = Vector2(BAR_SIZE.x + 40, 0)
	_clip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_clip)
	_drawer.add_theme_stylebox_override("panel", UIStyle.panel_outlined(UIStyle.GOLD))
	_drawer.size = Vector2(BAR_SIZE.x + 40, DRAWER_HEIGHT)
	_clip.add_child(_drawer)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	_drawer.add_child(col)
	col.add_child(UIStyle.heading("Account Rewards", 24))
	_next.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_next)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(BAR_SIZE.x + 10, DRAWER_HEIGHT - 110)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_rows.add_theme_constant_override("separation", 4)
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_rows)
	col.add_child(scroll)
	_drawer.position.y = -DRAWER_HEIGHT
	Account.changed.connect(_refresh)
	_refresh()


func toggle() -> void:
	_open = not _open
	_arrow.text = "▲" if _open else "▼"
	if _open:
		_fill_rows()
	var tw := create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(_clip, "custom_minimum_size:y", DRAWER_HEIGHT if _open else 0.0, 0.3)
	tw.tween_property(_drawer, "position:y", 0.0 if _open else -DRAWER_HEIGHT, 0.3)


func is_open() -> bool:
	return _open


func _refresh() -> void:
	var p := Account.progress()
	_diamond.level = int(p.level)
	_fill = clampf(float(p.into) / maxf(1.0, float(p.needed)), 0.0, 1.0)
	_text = "%s / %s account XP" % [_grouped(int(p.into)), _grouped(int(p.needed))]
	_diamond.fill = YELLOW.lerp(RED, _fill).darkened(0.25)
	_diamond.queue_redraw()
	var upcoming := Account.rewards().filter(func(r: Dictionary) -> bool: return int(r.level) > int(p.level))
	_next.text = "Account level %d.  Your characters' XP counts here too, and a fallen character adds 25%% of its XP and the worth of what it carried." % int(p.level)
	if not upcoming.is_empty():
		_next.text += "\nNext: level %d  —  %s" % [int(upcoming[0].level), upcoming[0].text]
	if _open:
		_fill_rows()


func _fill_rows() -> void:
	for child in _rows.get_children():
		child.queue_free()
	var level := int(Account.progress().level)
	var by_level := {}
	for r: Dictionary in Account.rewards():
		by_level[int(r.level)] = r
	for l in range(1, maxi(SHOW_LEVELS, level + 10) + 1):
		var reward: Dictionary = by_level.get(l, {})
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var badge := LevelDiamond.new(34.0)
		badge.level = l
		badge.fill = Color(0.6, 0.45, 0.15) if l <= level else Color(0.18, 0.2, 0.32)
		row.add_child(badge)
		var text := "Start: 2 character slots" if l == 1 else str(reward.get("text", "—"))
		var color := UIStyle.GOLD if l <= level and (not reward.is_empty() or l == 1) else UIStyle.TEXT_DIM
		if l > level and not reward.is_empty():
			color = UIStyle.TEXT
		var label := UIStyle.label(text, 16, color)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(label)
		var state := "✓" if l <= level and (not reward.is_empty() or l == 1) else ("you are here" if l == level else "")
		var right := UIStyle.label(state, 14, UIStyle.GOOD if state == "✓" else UIStyle.GOLD)
		right.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(right)
		_rows.add_child(row)


func _process(delta: float) -> void:
	if absf(_shown_fill - _fill) > 0.0005:
		_shown_fill = lerpf(_shown_fill, _fill, minf(1.0, delta * 6.0))
		_bar.queue_redraw()


func _draw_bar() -> void:
	var r := Rect2(Vector2.ZERO, _bar.size)
	_bar.draw_rect(r, UIStyle.OUTLINE)
	var inner := r.grow(-3)
	_bar.draw_rect(inner, Color(0.09, 0.08, 0.14))
	var w := inner.size.x * _shown_fill
	if w > 1.0:
		# Yellow at the start, warming toward red the fuller it gets.
		var steps := maxi(1, int(w / 6.0))
		var end := YELLOW.lerp(RED, _shown_fill)
		for i in steps:
			var x0 := inner.position.x + w * i / steps
			var x1 := inner.position.x + w * (i + 1) / steps
			var c := YELLOW.lerp(end, float(i) / maxf(1.0, steps - 1))
			_bar.draw_rect(Rect2(x0, inner.position.y, x1 - x0 + 0.5, inner.size.y), c)
		_bar.draw_rect(Rect2(inner.position, Vector2(w, inner.size.y * 0.35)), Color(1, 1, 1, 0.18))
	var font := UIStyle.font()
	var fs := 15
	var tw := font.get_string_size(_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var at := Vector2((r.size.x - tw) * 0.5, r.size.y * 0.5 + fs * 0.36)
	_bar.draw_string_outline(font, at, _text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 5, UIStyle.OUTLINE)
	_bar.draw_string(font, at, _text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UIStyle.TEXT)


static func _grouped(n: int) -> String:
	var s := str(n)
	var out := ""
	while s.length() > 3:
		out = "," + s.right(3) + out
		s = s.left(s.length() - 3)
	return s + out
