class_name UIStyle
## Shared look for every UI element: a pixel font, pixel-art frames (see
## PixelArt), colors and text settings. Build new UI from these so it all
## matches.

const BG := Color(0.11, 0.12, 0.2)
const BG_LIGHT := Color(0.17, 0.19, 0.3)
const OUTLINE := Color(0.03, 0.03, 0.06)
const BEVEL_LIGHT := Color(0.32, 0.36, 0.52)
const BEVEL_DARK := Color(0.07, 0.07, 0.13)
const TEXT := Color(0.96, 0.95, 0.9)
const TEXT_DIM := Color(0.6, 0.64, 0.78)
const ACCENT := Color(0.55, 0.85, 1.0)
const GOLD := Color(1.0, 0.82, 0.4)
const GOOD := Color(0.5, 0.95, 0.5)
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

## Font sizes that land on the pixel font's grid (stay crisp).
const SIZE_SMALL := 16
const SIZE_NORMAL := 16
const SIZE_LARGE := 24

static var _font: Font
static var _bold: FontVariation
static var _theme: Theme
static var _boxes := {}


static var _file: FontFile


## The UI font (Pixelify Sans, medium weight so it reads well at small sizes).
static func font() -> Font:
	if _font == null:
		var v := FontVariation.new()
		v.base_font = _font_file()
		v.variation_opentype = {"wght": 500}
		_font = v
	return _font


static func bold() -> Font:
	if _bold == null:
		_bold = FontVariation.new()
		_bold.base_font = _font_file()
		_bold.variation_opentype = {"wght": 700}
	return _bold


static func _font_file() -> FontFile:
	if _file == null:
		_file = load("res://fonts/PixelifySans.ttf")
		# Pixel fonts must not be smoothed, or the pixels go blurry.
		_file.antialiasing = TextServer.FONT_ANTIALIASING_NONE
		_file.hinting = TextServer.HINTING_NONE
		_file.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
		_file.multichannel_signed_distance_field = false
	return _file


## Theme for the whole HUD: pixel font everywhere, with a hard drop shadow
## instead of a soft outline.
static func theme() -> Theme:
	if _theme == null:
		_theme = Theme.new()
		_theme.default_font = font()
		_theme.default_font_size = SIZE_NORMAL
		for type in ["Label", "Button", "RichTextLabel"]:
			_theme.set_color("font_shadow_color", type, Color(0, 0, 0, 0.75))
			_theme.set_constant("shadow_offset_x", type, 2)
			_theme.set_constant("shadow_offset_y", type, 2)
			_theme.set_constant("shadow_outline_size", type, 0)
		_theme.set_font("bold_font", "RichTextLabel", bold())
		_theme.set_font("normal_font", "RichTextLabel", font())
		_theme.set_font("italics_font", "RichTextLabel", font())
		_theme.set_color("default_color", "RichTextLabel", TEXT)
		_theme.set_color("font_color", "Label", TEXT)
	return _theme


static func _cached(key: String, make: Callable) -> StyleBoxTexture:
	if not _boxes.has(key):
		_boxes[key] = make.call()
	return _boxes[key]


## Raised pixel panel (tabs, cards).
static func panel() -> StyleBoxTexture:
	return _cached("panel", func() -> StyleBoxTexture:
		return PixelArt.box(PixelArt.frame_image(BG, OUTLINE, BEVEL_LIGHT, BEVEL_DARK), 14.0))


## Panel with a colored outline (tooltips, toasts).
static func panel_outlined(color: Color) -> StyleBoxTexture:
	return _cached("panel_" + color.to_html(), func() -> StyleBoxTexture:
		return PixelArt.box(PixelArt.frame_image(BG, color.darkened(0.35), color, BEVEL_DARK), 12.0))


## Recessed item slot, lit when hovered.
static func slot(hovered := false) -> StyleBoxTexture:
	return _cached("slot_%s" % hovered, func() -> StyleBoxTexture:
		if hovered:
			return PixelArt.box(PixelArt.frame_image(Color(0.13, 0.15, 0.26), ACCENT.darkened(0.2),
					BEVEL_DARK, ACCENT, true), 0.0)
		return PixelArt.box(PixelArt.frame_image(Color(0.05, 0.055, 0.1), OUTLINE, BEVEL_DARK,
				Color(0.22, 0.24, 0.36), true), 0.0))


## Keycap-style pixel button: face on a darker lip; pressed sinks down.
static func button_styles(target: Button) -> void:
	var face := Color(0.27, 0.31, 0.5)
	var lip := Color(0.12, 0.13, 0.24)
	var normal := PixelArt.box(PixelArt.button_image(face, lip, OUTLINE, face.lightened(0.35)), 0.0)
	var hover := PixelArt.box(PixelArt.button_image(face.lightened(0.15), lip, OUTLINE, ACCENT), 0.0)
	var pressed := PixelArt.box(PixelArt.button_image(face.darkened(0.1), lip, OUTLINE, face, true), 0.0)
	for s in [normal, hover, pressed]:
		s.content_margin_left = 18
		s.content_margin_right = 18
		s.content_margin_top = 8
		s.content_margin_bottom = 14  # room for the lip
	pressed.content_margin_top = 14  # text drops with the face
	pressed.content_margin_bottom = 8
	target.add_theme_stylebox_override("normal", normal)
	target.add_theme_stylebox_override("hover", hover)
	target.add_theme_stylebox_override("pressed", pressed)
	target.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	target.add_theme_color_override("font_hover_color", ACCENT)
	text(target, SIZE_NORMAL)


## Applies the standard text look to a control.
static func text(target: Control, size := SIZE_NORMAL, color := TEXT) -> void:
	target.add_theme_font_override("font", font())
	target.add_theme_font_size_override("font_size", size)
	target.add_theme_color_override("font_color", color)
	target.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.75))
	target.add_theme_constant_override("shadow_offset_x", 2)
	target.add_theme_constant_override("shadow_offset_y", 2)


static func label(content: String, size := SIZE_NORMAL, color := TEXT) -> Label:
	var l := Label.new()
	l.text = content
	text(l, size, color)
	return l


## Bold heading label.
static func heading(content: String, size := SIZE_LARGE, color := GOLD) -> Label:
	var l := label(content, size, color)
	l.add_theme_font_override("font", bold())
	return l


## A reusable pixel button with a little press bounce.
static func button(caption: String) -> Button:
	var b := Button.new()
	b.text = caption
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button_styles(b)
	b.pressed.connect(func() -> void:
		b.pivot_offset = b.size * 0.5
		var t := b.create_tween()
		t.tween_property(b, "scale", Vector2(0.92, 0.92), 0.05)
		t.tween_property(b, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK))
	return b
