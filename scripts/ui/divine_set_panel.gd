class_name DivineSetPanel
extends VBoxContainer
## The same compact set treatment used on the wiki. Rows are cumulative.
const ICON = preload("res://assets/ui/divine_set_d.png")
const RED := Color("752c37")
const GOLD := Color("b98a48")
const PINK := Color("ff8ccc")
var _title := Label.new()
var _rows: Array[HBoxContainer] = []
var _labels: Array[Label] = []
var _pills: Array[PanelContainer] = []
var _set: Dictionary = {}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", 4)
	var header := PanelContainer.new()
	header.custom_minimum_size.y = 20
	header.add_theme_stylebox_override("panel", _style(RED, GOLD))
	add_child(header)
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 6)
	header.add_child(line)
	var badge := PanelContainer.new()
	badge.custom_minimum_size = Vector2(16, 16)
	badge.add_theme_stylebox_override("panel", _style(Color("48212f"), GOLD))
	line.add_child(badge)
	var center := CenterContainer.new()
	badge.add_child(center)
	var icon := TextureRect.new()
	icon.texture = ICON
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.custom_minimum_size = Vector2(8, 8)
	center.add_child(icon)
	var title := Label.new()
	title.text = "Divine set"
	title.add_theme_font_size_override("font_size", 14)
	line.add_child(title)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_title.add_theme_font_size_override("font_size", 12)
	_title.add_theme_color_override("font_color", Color("e6c69c"))
	line.add_child(_title)
	for numeral: String in ["I", "II", "III"]:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		add_child(row)
		_rows.append(row)
		var pill := PanelContainer.new()
		pill.custom_minimum_size = Vector2(24, 18)
		pill.add_theme_stylebox_override("panel", _style(Color("48212f"), GOLD))
		row.add_child(pill)
		_pills.append(pill)
		var roman := Label.new()
		roman.text = numeral
		roman.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		roman.add_theme_font_size_override("font_size", 12)
		roman.add_theme_color_override("font_color", PINK)
		pill.add_child(roman)
		var label := Label.new()
		label.add_theme_font_size_override("font_size", 14)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		_labels.append(label)
	# Parent tooltips own hover input; none of this footer intercepts it.
	for child in find_children("*", "Control", true, false): child.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hide()

func show_set(item: Item, stats: PlayerStats) -> void:
	_set = DivineSetBonuses.definition(item)
	visible = not _set.is_empty()
	if not visible: return
	var count := int(DivineSetBonuses.equipped_counts(stats.gear).get(DivineSetBonuses.set_id(item), 0)) if stats else 0
	_title.text = "%s  %d/4" % [_set.name, count]
	for i in 3:
		var stage: Dictionary = _set.stages[i]
		var active := count >= int(stage.pieces)
		var values := PackedStringArray()
		for stat: String in stage.bonuses:
			values.append("%+d %s" % [int(stage.bonuses[stat]), UIStyle.stat_name(stat)])
		_labels[i].text = "  ".join(values)
		_labels[i].add_theme_color_override("font_color", Color("f6ead3") if active else Color("8c8188"))
		_pills[i].modulate = Color.WHITE if active else Color(0.55, 0.55, 0.55)
		_rows[i].tooltip_text = "%d equipped pieces%s" % [int(stage.pieces), " - active" if active else " - locked"]

static func _style(fill: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	style.content_margin_left = 4
	style.content_margin_right = 4
	return style
