class_name ThrottleBar
extends Control
## The pilot's throttle, left of centre: a short upright bar in the hull
## bar's pixel style. Ten sections above the middle mark fill green going
## forward, ten below fill red in reverse (10% each); the percent sits under it.

const PX := PixelArt.SCALE
const STEPS := 10
const SECTION_H := 2  # art pixels
const GAP := 1
const WIDTH := 7
const RAIL := Color("2a3348")
const SOCKET := Color("10151f")
const FORWARD := Color("4fd67a")
const FORWARD_LIGHT := Color("b8ffcc")
const REVERSE := Color("e0484a")
const REVERSE_LIGHT := Color("ffb4b0")

var value := 0.0
var _label := Label.new()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(WIDTH+4, _half()*2+3+4)*PX+Vector2(0, 22)


func _ready() -> void:
	UIStyle.text(_label, UIStyle.SIZE_SMALL, UIStyle.TEXT)
	_label.add_theme_font_override("font", UIStyle.bold())
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.position = Vector2(-20, (_half()*2+3+4)*PX)
	_label.size = Vector2((WIDTH+4)*PX+40, 22)
	add_child(_label)


static func _half() -> int:
	return STEPS*(SECTION_H+GAP)


## -1..1 (reverse..full ahead).
func set_value(v: float) -> void:
	v = clampf(v, -1.0, 1.0)
	if is_equal_approx(v, value) and _label.text!="": return
	value = v
	_label.text = "%d%%" % roundi(v*100.0)
	_label.add_theme_color_override("font_color", FORWARD_LIGHT if v>0.001 else REVERSE_LIGHT if v<-0.001 else UIStyle.TEXT)
	queue_redraw()


func _rect(x: float, y: float, w: float, h: float, c: Color) -> void:
	draw_rect(Rect2(Vector2(x, y)*PX, Vector2(w, h)*PX), c)


func _draw() -> void:
	var half := _half()
	var height := half*2+3+4
	_rect(0, 0, WIDTH+4, height, UIStyle.OUTLINE)
	_rect(1, 1, WIDTH+2, height-2, RAIL)
	var mid := 2+half  # the middle mark's top row
	var lit := roundi(absf(value)*STEPS)
	for i in STEPS:
		# Forward sections climb from the middle mark; reverse ones hang below it.
		var up_y := mid-(i+1)*(SECTION_H+GAP)+GAP
		var down_y := mid+3+i*(SECTION_H+GAP)
		var on_up := value>0.0 and i<lit
		var on_down := value<0.0 and i<lit
		_rect(2, up_y, WIDTH, SECTION_H, FORWARD if on_up else SOCKET)
		if on_up: _rect(2, up_y, WIDTH, 1, FORWARD_LIGHT)
		_rect(2, down_y, WIDTH, SECTION_H, REVERSE if on_down else SOCKET)
		if on_down: _rect(2, down_y, WIDTH, 1, REVERSE_LIGHT)
	# The middle point: zero throttle.
	_rect(0, mid, WIDTH+4, 3, UIStyle.OUTLINE)
	_rect(1, mid+1, WIDTH+2, 1, UIStyle.GOLD)
