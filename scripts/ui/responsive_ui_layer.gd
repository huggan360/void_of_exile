class_name ResponsiveUILayer
extends CanvasLayer
## Scale only screen UI; the 3D viewport/camera keep native window coordinates.
var _ui_root: Control
func make_ui_root() -> Control:
	_ui_root = Control.new()
	_ui_root.name = "ResponsiveUI"
	_ui_root.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_ui_root)
	AppSettings.gui_changed.connect(_resize_ui)
	get_viewport().size_changed.connect(_resize_ui)
	_resize_ui()
	return _ui_root
func _resize_ui() -> void:
	if not is_instance_valid(_ui_root): return
	var factor := AppSettings.ui_factor()
	scale = Vector2.ONE*factor
	_ui_root.size = get_viewport().get_visible_rect().size/factor
