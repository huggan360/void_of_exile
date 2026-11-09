class_name KeyHelp
extends VBoxContainer
## The keys that matter right now, above the minimap: each row a keycap (the
## key the player has actually bound) and what it does. Shown only while
## doing something particular (at the helm, at a cannon, on a line, in a
## lift); hidden otherwise. Rows: [[keys, what]], a key "@action" naming an
## input action (its bound key is shown), anything else shown as written.
## Kept small and quiet: no box behind it, short words, right-aligned.
var _shown := ""

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", 5)
	alignment = BoxContainer.ALIGNMENT_END
	hide()

func set_rows(rows: Array) -> void:
	var key := str(rows)
	if key==_shown: return
	_shown = key
	for child in get_children():
		remove_child(child)
		child.queue_free()
	visible = not rows.is_empty()
	for row: Array in rows:
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 4)
		line.alignment = BoxContainer.ALIGNMENT_END
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var what := UIStyle.label(str(row[1]), UIStyle.SIZE_SMALL, UIStyle.TEXT)
		what.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		what.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
		what.add_theme_constant_override("outline_size", 4)
		line.add_child(what)
		var gap := Control.new()
		gap.custom_minimum_size.x = 2
		line.add_child(gap)
		for k: String in row[0]: line.add_child(_cap(key_name(k)))
		add_child(line)

static var _cap_box: StyleBoxFlat

## A small keycap: dark, a thin warm rim, a darker lip underneath.
func _cap(text: String) -> Control:
	var cap := PanelContainer.new()
	if _cap_box==null:
		_cap_box = StyleBoxFlat.new()
		_cap_box.bg_color = Color(UIStyle.BG, 0.88)
		_cap_box.border_color = UIStyle.BEVEL_LIGHT
		_cap_box.set_border_width_all(1)
		_cap_box.border_width_bottom = 3
		_cap_box.set_corner_radius_all(3)
		_cap_box.content_margin_left = 7
		_cap_box.content_margin_right = 7
		_cap_box.content_margin_top = 2
		_cap_box.content_margin_bottom = 3
	cap.add_theme_stylebox_override("panel", _cap_box)
	cap.custom_minimum_size = Vector2(24, 24)
	var label := UIStyle.label(text, UIStyle.SIZE_SMALL, UIStyle.TEXT)
	label.add_theme_font_override("font", UIStyle.bold())
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cap.add_child(label)
	return cap

## The name of the key behind "@action" (as the player bound it), or `entry`.
static func key_name(entry: String) -> String:
	if not entry.begins_with("@"): return entry
	return AppSettings.binding_text(entry.substr(1))
