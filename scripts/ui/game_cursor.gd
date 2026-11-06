class_name GameCursor
extends Node
## The game's own mouse pointer (ui/cursor, drawn by tools/make_cursor.py):
## a pointer head without the tail. Pressing a mouse button sinks it a
## little into the screen (the pressed image: smaller, darker, its shadow
## tucked in). It's the system's hardware cursor, so it never lags, sized
## with the GUI scale.

const NORMAL := preload("res://ui/cursor/cursor.png")
const PRESSED := preload("res://ui/cursor/cursor_pressed.png")
const SOURCE_HOTSPOT := Vector2(16, 14)  # the tip, in the 128 px images
const BASE_SIZE := 44.0  # on-screen pixels at GUI factor 1

var _normal: Texture2D
var _pressed: Texture2D
var _hotspot := Vector2.ZERO
var _down := false


func _ready() -> void:
	if not AppSettings.desktop_available():
		return
	AppSettings.gui_changed.connect(_build)
	_build()


func _build() -> void:
	var px := clampi(roundi(BASE_SIZE * AppSettings.ui_factor()), 24, 128)
	_normal = _sized(NORMAL, px)
	_pressed = _sized(PRESSED, px)
	_hotspot = (SOURCE_HOTSPOT * px / 128.0).floor()
	_apply()


static func _sized(texture: Texture2D, px: int) -> Texture2D:
	var image := texture.get_image()
	image.resize(px, px, Image.INTERPOLATE_LANCZOS)
	return ImageTexture.create_from_image(image)


func _apply() -> void:
	Input.set_custom_mouse_cursor(_pressed if _down else _normal, Input.CURSOR_ARROW, _hotspot)


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
		var down := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
		if down != _down and _normal:
			_down = down
			_apply()
