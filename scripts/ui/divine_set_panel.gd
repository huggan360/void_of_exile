class_name DivineSetPanel
extends VBoxContainer
## The same compact set treatment used on the wiki. Rows are cumulative.
const ICON = preload("res://assets/ui/divine_set_d.png")
const STROKE = preload("res://assets/ui/divine_set_stroke.png")
## 8 x 8 pixel art, drawn at 16 x 16.
const NUMERALS := [preload("res://assets/ui/divine_set_i.png"), preload("res://assets/ui/divine_set_ii.png"),
	preload("res://assets/ui/divine_set_iii.png")]
var _title := Label.new()
var _rows: Array[HBoxContainer] = []
var _labels: Array[Label] = []
var _numerals: Array[TextureRect] = []
var _set: Dictionary = {}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", 6)
	# A painted red stroke behind the header, no box or border. It bleeds past
	# the strip so the brush's feathered edges don't thin out the body.
	var header := PanelContainer.new()
	header.custom_minimum_size.y = 26
	var stroke := StyleBoxTexture.new()
	stroke.texture = STROKE
	stroke.expand_margin_left = 6
	stroke.expand_margin_right = 6
	stroke.expand_margin_top = 6
	stroke.expand_margin_bottom = 6
	stroke.content_margin_left = 8
	stroke.content_margin_right = 10
	header.add_theme_stylebox_override("panel", stroke)
	header.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(header)
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 6)
	header.add_child(line)
	var icon := TextureRect.new()
	icon.texture = ICON
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(16, 16)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(icon)
	var title := Label.new()
	title.text = "Divine set"
	title.add_theme_font_size_override("font_size", 14)
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(title)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_title.add_theme_font_size_override("font_size", 12)
	_title.add_theme_color_override("font_color", Color("e6c69c"))
	_title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(_title)
	for i in 3:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		add_child(row)
		_rows.append(row)
		var numeral := TextureRect.new()
		numeral.texture = NUMERALS[i]
		numeral.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		numeral.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		numeral.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		numeral.custom_minimum_size = Vector2(16, 16)
		numeral.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(numeral)
		_numerals.append(numeral)
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
		_numerals[i].modulate = Color.WHITE if active else Color(0.55, 0.55, 0.55)
		_rows[i].tooltip_text = "%d equipped pieces%s" % [int(stage.pieces), " - active" if active else " - locked"]
