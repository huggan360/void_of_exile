class_name ToastFeed
extends VBoxContainer
## Notices in the top-left corner ("+2 Attack", "Level 5!"...). Each toast
## slides in, waits, then fades out. Use push(text, color).

const LIFETIME := 4.0
const MAX_TOASTS := 6


func _init() -> void:
	add_theme_constant_override("separation", 6)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


var _pinned := {}  # key -> {toast, label}

## A toast that stays until unpin(key); pinning the same key again updates its text.
func pin(key: String, message: String, accent := UIStyle.ACCENT) -> void:
	if _pinned.has(key) and is_instance_valid(_pinned[key].toast):
		(_pinned[key].label as Label).text = message
		return
	var toast := PanelContainer.new()
	toast.add_theme_stylebox_override("panel", UIStyle.panel_outlined(accent))
	toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var gem := ColorRect.new()
	gem.color = accent
	gem.custom_minimum_size = Vector2(PixelArt.SCALE * 2, PixelArt.SCALE * 2)
	gem.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(gem)
	var label := UIStyle.label(message, UIStyle.SIZE_NORMAL)
	row.add_child(label)
	toast.add_child(row)
	add_child(toast)
	_pinned[key] = {toast = toast, label = label}
	toast.modulate.a = 0.0
	toast.create_tween().tween_property(toast, "modulate:a", 1.0, 0.2)

func unpin(key: String) -> void:
	if not _pinned.has(key): return
	var toast: Control = _pinned[key].toast
	_pinned.erase(key)
	if not is_instance_valid(toast): return
	var t := toast.create_tween()
	t.tween_property(toast, "modulate:a", 0.0, 0.4)
	t.tween_callback(toast.queue_free)


func push(message: String, accent := UIStyle.ACCENT, lifetime := LIFETIME) -> void:
	var toast := PanelContainer.new()
	toast.add_theme_stylebox_override("panel", UIStyle.panel_outlined(accent))
	toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var gem := ColorRect.new()  # little colored pixel gem
	gem.color = accent
	gem.custom_minimum_size = Vector2(PixelArt.SCALE * 2, PixelArt.SCALE * 2)
	gem.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(gem)
	row.add_child(UIStyle.label(message, UIStyle.SIZE_NORMAL))
	toast.add_child(row)
	add_child(toast)
	while get_child_count() > MAX_TOASTS:
		get_child(0).free()

	toast.modulate.a = 0.0
	var t := toast.create_tween()
	t.tween_property(toast, "modulate:a", 1.0, 0.2)
	t.parallel().tween_property(toast, "position:x", 0.0, 0.25).from(-40.0).set_trans(Tween.TRANS_BACK)
	t.tween_interval(lifetime)
	t.tween_property(toast, "modulate:a", 0.0, 0.5)
	t.tween_callback(toast.queue_free)
