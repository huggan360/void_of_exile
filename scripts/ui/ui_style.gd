class_name UIStyle
## Shared look for every UI element: Bree Serif type, pixel-art frames (see
## PixelArt), colors and text settings. Build new UI from these so it all
## matches.

const BG := Color("141b2b")
const BG_LIGHT := Color("253149")
const OUTLINE := Color("080d16")
const BEVEL_LIGHT := Color("87724f")
const BEVEL_DARK := Color("0b1120")
const TEXT := Color("f6ead3")
const TEXT_DIM := Color("a7b8cd")
const ACCENT := Color("82d7ed")
const GOLD := Color("e5b96d")
const GOOD := Color(0.5, 0.95, 0.5)
## Semantic colors shared by labels and BBCode.
const STAT := Color(0.45, 0.78, 1.0)
const DAMAGE := TEXT
const PROJECTILE := Color(0.45, 0.88, 0.88)
const EFFECT := Color(1.0, 0.7, 0.4)
const BAD := Color(1.0, 0.5, 0.5)
const DOTS := Color(0.5, 0.95, 0.5)
const SOULBOUND := Color(0.78, 0.65, 1.0)
const MP := Color(1.0, 0.75, 0.15)
const HP := Color(0.9, 0.2, 0.3)
const HP_LIGHT := Color(1.0, 0.5, 0.5)
const MAGIC := Color(1.0, 0.75, 0.15)
const MAGIC_LIGHT := Color(1.0, 0.95, 0.6)
const XP := Color(0.62, 0.55, 1.0)
## Name/badge color per grade G1...G8, and for Divine items.
const GRADE_COLORS := [Color(0.82, 0.82, 0.86), Color(0.7, 0.9, 0.6), Color(0.45, 0.92, 0.5),
		Color(0.45, 0.78, 1.0), Color(0.62, 0.55, 1.0), Color(0.86, 0.5, 1.0), Color(1.0, 0.62, 0.35),
		Color(1.0, 0.85, 0.35)]
const DIVINE_COLOR := Color(1.0, 0.55, 0.8)


static func grade_color(item: Item) -> Color:
	if item.is_divine():
		return DIVINE_COLOR
	return GRADE_COLORS[clampi(item.tier - 1, 0, GRADE_COLORS.size() - 1)]


static func stat_color(stat: String) -> Color:
	return HP_LIGHT if stat == "hp" else MP if stat == "mp" else STAT


static func stat_name(stat: String) -> String:
	return {"speed": "SPD", "attack": "ATK", "dexterity": "DEX", "defense": "DEF",
		"magic": "MAG", "hp": "HP", "mp": "MP"}.get(stat, stat.to_upper())


static func stat_text(stat: String, value: int, signed := true) -> String:
	return TextMarkup.color("%s %s" % [("%+d" % value) if signed else str(value), stat_name(stat)],
		BAD if value < 0 else stat_color(stat))


static func rich(text: String, font_size := SIZE_NORMAL) -> RichTextLabel:
	var label := RichTextLabel.new()
	label.theme = theme()
	label.bbcode_enabled = true
	label.fit_content = true
	label.scroll_active = false
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("normal_font_size", font_size)
	label.add_theme_font_size_override("bold_font_size", font_size)
	label.text = text
	return label

## Shared readable text sizes, independent of the pixel-art assets.
const SIZE_SMALL := 16
const SIZE_NORMAL := 16
const SIZE_LARGE := 24

static var _font: Font
static var _bold: FontVariation
static var _italic: FontVariation
static var _theme: Theme
static var _boxes := {}
static var _skin_textures := {}


static var _file: FontFile
static var _heading_font: FontVariation


## Smooth book-style serif for dialogue, controls and numeric readouts.
static func font() -> Font:
	if _font == null:
		var v := FontVariation.new()
		v.base_font = _font_file()
		v.variation_embolden = 0.0
		_font = v
	return _font


static func bold() -> Font:
	if _bold == null:
		_bold = FontVariation.new()
		_bold.base_font = _font_file()
		_bold.variation_embolden = 0.4
	return _bold


static func _font_file() -> FontFile:
	if _file == null:
		_file = load("res://fonts/BreeSerif.ttf")
		# Emboldened serif contours can intersect. Raster rendering handles
		# those overlaps correctly; MSDF can punch holes through the strokes.
		# Oversampling keeps the scaled screen UI and world labels readable.
		_file.multichannel_signed_distance_field = false
		_file.oversampling = 3.0
		_file.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
		_file.hinting = TextServer.HINTING_NONE
		_file.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_AUTO
		_file.generate_mipmaps = true
	return _file


static func heading_font() -> Font:
	if _heading_font == null:
		_heading_font = FontVariation.new()
		var file: FontFile = _font_file()
		_heading_font.base_font = file
		_heading_font.variation_embolden = 0.65
	return _heading_font


## Shared smooth font theme for both screen UI and world labels.
static func theme() -> Theme:
	if _theme == null:
		_theme = Theme.new()
		var tree := Engine.get_main_loop() as SceneTree
		if tree and not tree.node_added.is_connected(_shadow_added): tree.node_added.connect(_shadow_added)
		for type in ["Button", "OptionButton", "MenuButton"]:
			for state in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
				var tint := Color(0.74, 0.82, 0.95)
				if state == "hover": tint = Color(0.92, 0.98, 1.0)
				elif state in ["pressed", "hover_pressed"]: tint = Color(0.50, 0.62, 0.80)
				elif state == "disabled": tint = Color(0.38, 0.44, 0.54)
				var face := _skin_box("stone", tint, 8)
				face.content_margin_left = 18
				face.content_margin_right = 18
				_theme.set_stylebox(state, type, face)
				_theme.set_stylebox(state + "_mirrored", type, face)
		for type in ["TabContainer", "TabBar"]:
			_theme.set_stylebox("tab_hovered", type, panel_outlined(ACCENT))
			_theme.set_stylebox("tab_selected", type, panel_outlined(GOLD))
			_theme.set_stylebox("tab_unselected", type, panel())
			_theme.set_stylebox("tab_disabled", type, panel())
		_theme.default_font = font()
		_theme.default_font_size = SIZE_NORMAL
		for type in ["Label", "Button", "RichTextLabel"]:
			_theme.set_color("font_shadow_color", type, Color(0, 0, 0, 0.75))
			_theme.set_constant("shadow_offset_x", type, 2)
			_theme.set_constant("shadow_offset_y", type, 2)
			_theme.set_constant("shadow_outline_size", type, 0)
		_theme.set_font("bold_font", "RichTextLabel", bold())
		_theme.set_font("normal_font", "RichTextLabel", font())
		_italic = FontVariation.new()
		_italic.base_font = font()
		_italic.variation_transform = Transform2D(Vector2(1, 0), Vector2(-0.2, 1), Vector2.ZERO)
		_theme.set_font("italics_font", "RichTextLabel", _italic)
		_theme.set_color("default_color", "RichTextLabel", TEXT)
		_theme.set_color("font_color", "Label", TEXT)
		for type in ["LineEdit", "TextEdit"]:
			_theme.set_stylebox("normal", type, panel())
			_theme.set_stylebox("focus", type, panel_outlined(ACCENT))
			_theme.set_color("font_color", type, TEXT)
			_theme.set_color("font_placeholder_color", type, TEXT_DIM)
		for type in ["HScrollBar", "VScrollBar"]:
			_theme.set_stylebox("scroll", type, PixelArt.box(PixelArt.frame_image(OUTLINE, OUTLINE, BEVEL_DARK, BG_LIGHT), 0))
			_theme.set_stylebox("grabber", type, panel())
			_theme.set_stylebox("grabber_highlight", type, panel_outlined(ACCENT))
			_theme.set_stylebox("grabber_pressed", type, panel_outlined(GOLD))
		_theme.set_stylebox("panel", "TabContainer", panel())
		_theme.set_stylebox("tab_selected", "TabContainer", panel_outlined(GOLD))
		_theme.set_stylebox("tab_unselected", "TabContainer", panel())
	return _theme


static func _shadow_added(node: Node) -> void:
	if node is Button or node is PanelContainer or node is Panel or node is ProgressBar:
		add_shadow.call_deferred(node)


static func add_shadow(target: Variant, rounded := false) -> void:
	# A page can remove a control before this deferred call runs. Accept the
	# freed reference here so validation happens before conversion to Control.
	if not is_instance_valid(target) or not target is Control or target.is_queued_for_deletion() or target.has_meta("drop_shadow"): return
	var shadow := preload("res://scripts/ui/ui_drop_shadow.gd").new()
	shadow.rounded = rounded
	target.set_meta("drop_shadow", shadow)
	target.add_child(shadow, false, Node.INTERNAL_MODE_FRONT)


static func _cached(key: String, make: Callable) -> StyleBoxTexture:
	if not _boxes.has(key):
		_boxes[key] = make.call()
	return _boxes[key]


## Source sprites are kept intact. Size overrides give nine-patch borders
## a consistent UI size without resampling their retained pixel artwork.
static func _skin_texture(kind: String) -> Texture2D:
	if not _skin_textures.has(kind):
		var baked := {panel = "ui_blue_stone_panel.png", ivy_panel = "ui_blue_ivy_panel.png", item_slot = "ui_item_slot.png"}
		if baked.has(kind):
			_skin_textures[kind] = load("res://assets/ui/" + str(baked[kind]))
			return _skin_textures[kind]
		var ivy := kind == "ivy"
		var path := "res://assets/ui/ui_ivy_panel.png" if ivy else "res://assets/ui/ui_stone_button.png"
		var source: Texture2D = load(path)
		var region := Rect2i(14, 12, 1223, 1219) if ivy else Rect2i(28, 152, 2116, 398)
		var texture := ImageTexture.create_from_image(source.get_image().get_region(region))
		texture.set_size_override(Vector2i(192, 192) if ivy else Vector2i(192, 48))
		_skin_textures[kind] = texture
	return _skin_textures[kind]


static func _skin_box(kind: String, tint: Color, margin: float) -> StyleBoxTexture:
	var box := StyleBoxTexture.new()
	box.texture = _skin_texture(kind)
	var edge := 48.0 if kind in ["ivy", "ivy_panel"] else 3.0 if kind == "item_slot" else 9.0
	box.texture_margin_left = edge
	box.texture_margin_right = edge
	box.texture_margin_top = edge
	box.texture_margin_bottom = edge
	box.modulate_color = tint
	if kind in ["panel", "ivy_panel"]:
		box.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
		box.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	box.set_content_margin_all(margin)
	return box


## Quiet blue stone for small cards; matching artwork without climbing ivy.
static func panel() -> StyleBoxTexture:
	return _cached("panel", func() -> StyleBoxTexture:
		return _skin_box("panel", Color(0.52, 0.60, 0.75), 14))


static func panel_outlined(color: Color) -> StyleBoxTexture:
	return _cached("panel_" + color.to_html(), func() -> StyleBoxTexture:
		var tint := Color(0.59, 0.67, 0.81)
		if color.is_equal_approx(ACCENT): tint = Color(0.74, 0.94, 1.0)
		return _skin_box("panel", tint, 12))


## Ivy belongs on selected larger windows, keeping text clear of the corners.
static func ornament_panel() -> StyleBoxTexture:
	return _cached("ivy_panel", func() -> StyleBoxTexture:
		var box := _skin_box("ivy_panel", Color.WHITE, 24)
		box.content_margin_left = 52
		box.content_margin_right = 52
		box.content_margin_bottom = 32
		return box)


## Recessed item slot, lit when hovered.
static func slot(hovered := false) -> StyleBoxTexture:
	return _cached("slot_%s" % hovered, func() -> StyleBoxTexture:
		return _skin_box("item_slot", Color(1.25, 1.35, 1.45) if hovered else Color.WHITE, 0))


## Pixel button: state colors change without moving its label.
static func button_styles(target: Button, skin := "stone") -> void:
	# Moss keeps its own greens; stone gets the cool blue tint.
	var ivy := skin == "ivy"
	var normal := _skin_box(skin, Color(0.86, 0.9, 0.86) if ivy else Color(0.74, 0.82, 0.95), 0)
	var hover := _skin_box(skin, Color.WHITE if ivy else Color(0.92, 0.98, 1.0), 0)
	var pressed := _skin_box(skin, Color(0.62, 0.68, 0.62) if ivy else Color(0.50, 0.62, 0.80), 0)
	var disabled := _skin_box(skin, Color(0.5, 0.54, 0.5) if ivy else Color(0.38, 0.44, 0.54), 0)
	for s in [normal, hover, pressed, disabled]:
		s.content_margin_left = 18
		s.content_margin_right = 18
		s.content_margin_top = 8
		s.content_margin_bottom = 14  # room for the lip
	target.add_theme_stylebox_override("normal", normal)
	target.add_theme_stylebox_override("hover", hover)
	target.add_theme_stylebox_override("pressed", pressed)
	target.add_theme_stylebox_override("hover_pressed", pressed)
	target.add_theme_stylebox_override("disabled", disabled)
	# Every state has a face, so no hover/press combination drops the texture.
	for state: String in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		target.add_theme_stylebox_override(state + "_mirrored", target.get_theme_stylebox(state))
	var focus := StyleBoxFlat.new()
	focus.bg_color = Color.TRANSPARENT
	focus.border_color = ACCENT
	focus.set_border_width_all(1)
	target.add_theme_stylebox_override("focus", focus)
	target.add_theme_color_override("font_disabled_color", TEXT_DIM)
	target.add_theme_color_override("font_hover_color", ACCENT)
	text(target, SIZE_NORMAL)
	target.add_theme_font_override("font", bold())


## Applies the standard text look to a control.
static func text(target: Control, size := SIZE_NORMAL, color := TEXT) -> void:
	target.add_theme_font_override("font", heading_font() if size >= SIZE_LARGE else font())
	target.add_theme_font_size_override("font_size", size)
	target.add_theme_color_override("font_color", color)
	target.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.75))
	target.add_theme_constant_override("shadow_offset_x", 2)
	target.add_theme_constant_override("shadow_offset_y", 2)


## Conversation layout only: no panel fill or border behind the words.
static func dialogue_panel() -> StyleBoxEmpty:
	var style := StyleBoxEmpty.new()
	style.set_content_margin_all(16)
	return style


static func dialogue_separator() -> HSeparator:
	var separator := HSeparator.new()
	var line := StyleBoxLine.new()
	line.color = GOLD
	line.thickness = 3
	separator.add_theme_stylebox_override("separator", line)
	separator.add_theme_constant_override("separation", 12)
	separator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return separator


static func dialogue_text(target: RichTextLabel) -> void:
	target.add_theme_font_size_override("normal_font_size", 28)
	target.add_theme_font_size_override("bold_font_size", 28)
	target.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	target.add_theme_constant_override("shadow_offset_x", 2)
	target.add_theme_constant_override("shadow_offset_y", 2)
	target.add_theme_constant_override("outline_size", 4)
	target.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))


static func label(content: String, size := SIZE_NORMAL, color := TEXT) -> Label:
	var l := Label.new()
	l.text = content
	text(l, size, color)
	return l


## Bold heading label.
static func heading(content: String, size := SIZE_LARGE, color := GOLD) -> Label:
	var l := label(content, size, color)
	l.add_theme_font_override("font", heading_font())
	return l


## A reusable pixel button with stable text and geometry.
static func button(caption: String) -> Button:
	var b := Button.new()
	b.text = caption
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button_styles(b)
	return b
