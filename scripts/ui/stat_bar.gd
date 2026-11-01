class_name StatBar
extends Control
## A resource bar (health, magic...) in pixel art, with no box around it: a
## pixel icon, then a row of little gem-like sections. Filled sections have a
## bright top edge and shaded bottom; empty ones are dark sockets. A shine
## sweeps across now and then, lost sections flash white, and the value sits
## in a small recessed box at the end.

const PX := PixelArt.SCALE
const SECTION_W := 6  # art pixels per section (inside the outline)
const GAP := 1
const VALUE_BOX := 30  # art pixels for the "87/100" box at the end

var color := UIStyle.HP
var light := UIStyle.HP_LIGHT
var sections := 20
var section_h := 6  # art pixels
var icon_rows: PackedStringArray = []
var icon_palette := {}
var value := 100.0
var max_value := 100.0

var _shown := 100.0
var _ghost := 100.0
var _shine := -1.0
var _shine_timer := 0.0
var _label := Label.new()


func _init(p_color: Color, p_light: Color, p_section_h := 6) -> void:
	color = p_color
	light = p_light
	section_h = p_section_h
	_resize()


func set_icon(rows: PackedStringArray, palette: Dictionary) -> void:
	icon_rows = rows
	icon_palette = palette
	_resize()


func _resize() -> void:
	var icon_w := 0 if icon_rows.is_empty() else icon_rows[0].length() + 2
	custom_minimum_size = Vector2((icon_w + sections * (SECTION_W + GAP) + 3 + VALUE_BOX) * PX,
			(maxi(maxi(section_h, icon_rows.size()), 7) + 2) * PX)


func _ready() -> void:
	_label.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	_label.offset_left = -VALUE_BOX * PX
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UIStyle.text(_label, UIStyle.SIZE_NORMAL)
	add_child(_label)


func set_values(p_value: float, p_max: float) -> void:
	value = clampf(p_value, 0.0, p_max)
	max_value = p_max
	_label.text = "%d/%d" % [ceili(value), int(max_value)]


func _process(delta: float) -> void:
	_shown = move_toward(_shown, value, maxf(1.0, absf(value - _shown)) * delta * 12.0)
	_ghost = _shown if _ghost < _shown else move_toward(_ghost, _shown, max_value * delta * 0.5)
	_shine_timer -= delta
	if _shine_timer <= 0.0:
		_shine_timer = 3.5
		_shine = 0.0
	if _shine >= 0.0:
		_shine += delta * 30.0  # sections per second
		if _shine > sections + 3:
			_shine = -1.0
	queue_redraw()


func _px(x: float, y: float, w: float, h: float, c: Color) -> void:
	draw_rect(Rect2(Vector2(x, y) * PX, Vector2(w, h) * PX), c)


func _draw() -> void:
	var x0 := 0
	var y0 := 1
	if not icon_rows.is_empty():
		var iy := (size.y / PX - icon_rows.size()) * 0.5
		PixelArt.draw_rows(self, Vector2(0, floor(iy) * PX), icon_rows, icon_palette)
		x0 = icon_rows[0].length() + 2
		y0 = int(floor((size.y / PX - section_h) * 0.5))
	var per := max_value / sections if sections > 0 else 1.0
	for i in sections:
		var x := x0 + i * (SECTION_W + GAP)
		var fill := clampf((_shown - i * per) / per, 0.0, 1.0)
		var ghost := clampf((_ghost - i * per) / per, 0.0, 1.0)
		# Outline, then the empty socket.
		_px(x - 1, y0 - 1, SECTION_W + 2, section_h + 2, Color(0.02, 0.02, 0.05, 0.9))
		_px(x, y0, SECTION_W, section_h, Color(0.1, 0.1, 0.17, 0.85))
		_px(x, y0 + section_h - 1, SECTION_W, 1, Color(0.18, 0.18, 0.28, 0.85))
		if ghost > fill:
			_px(x, y0, ceilf(SECTION_W * ghost), section_h, Color(1, 1, 1, 0.55))
		if fill <= 0.0:
			continue
		var w := ceilf(SECTION_W * fill)
		var c := color
		if _shine >= 0.0 and absf(_shine - i) < 1.5:
			c = color.lerp(Color.WHITE, 0.35)  # the shine passing over
		_px(x, y0, w, section_h, c)
		_px(x, y0, w, 1, light)  # bright top edge
		_px(x, y0 + 1, mini(int(w), 2), 1, light.lerp(Color.WHITE, 0.5))  # glint
		_px(x, y0 + section_h - 1, w, 1, color.darkened(0.35))  # shaded bottom
	# Value box at the end.
	draw_style_box(UIStyle.slot(), Rect2(Vector2(size.x - VALUE_BOX * PX, 0), Vector2(VALUE_BOX * PX, size.y)))
