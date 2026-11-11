extends Control
## A shared soft shadow, drawn behind its owning control without catching input.
## Added as an internal child, so containers don't lay it out and
## get_children() never sees it.
var rounded := false
var _style := StyleBoxFlat.new()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	show_behind_parent = true
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_style.bg_color = Color.TRANSPARENT
	_style.shadow_color = Color(0, 0, 0, 0.26)
	_style.shadow_size = 9
	_style.shadow_offset = Vector2(0, 3)
	resized.connect(queue_redraw)
	var owner_button := get_parent() as Button
	if owner_button:
		owner_button.button_down.connect(queue_redraw)
		owner_button.button_up.connect(queue_redraw)
		owner_button.toggled.connect(func(_pressed: bool) -> void: queue_redraw())

func _draw() -> void:
	if not _has_body(get_parent()): return
	var owner_button := get_parent() as Button
	var down: bool = owner_button != null and owner_button.is_pressed()
	_style.shadow_size = 2 if down else 9
	_style.shadow_offset = Vector2(0, 1 if down else 3)
	var radius := int(minf(size.x, size.y) * 0.5) if rounded else 5
	_style.set_corner_radius_all(radius)
	draw_style_box(_style, Rect2(Vector2(2, 2), (size - Vector2(4, 4)).max(Vector2.ZERO)))

## Invisible panels and flat buttons get no shadow (it would show as a dark box).
func _has_body(owner_control: Control) -> bool:
	if owner_control is Button:
		return not (owner_control as Button).flat and not owner_control.get_theme_stylebox("normal") is StyleBoxEmpty
	if owner_control is Panel or owner_control is PanelContainer:
		return not owner_control.get_theme_stylebox("panel") is StyleBoxEmpty
	return true
