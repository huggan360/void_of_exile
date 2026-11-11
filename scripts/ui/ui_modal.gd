class_name UIModal
extends Control
## A dialog over everything: the screen dims and a gold-framed panel sits in
## the middle. Put the content in `body`; close() fades it away.

signal closed

var body := VBoxContainer.new()
var panel := PanelContainer.new()


func _init(title := "", min_width := 560.0) -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.06, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	panel.add_theme_stylebox_override("panel", UIStyle.ornament_panel())
	panel.custom_minimum_size.x = min_width
	center.add_child(panel)
	body.add_theme_constant_override("separation", 12)
	panel.add_child(body)
	if title != "":
		body.add_child(UIStyle.heading(title, 30))


func _ready() -> void:
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.15)


func close() -> void:
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.12)
	await tw.finished
	closed.emit()
	queue_free()


## A row of buttons, right-aligned.
func buttons(list: Array) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_theme_constant_override("separation", 12)
	for b: Control in list:
		row.add_child(b)
	body.add_child(row)
	return row


static func button(caption: String, action: Callable, width := 0.0) -> Button:
	var b := UIStyle.button(caption)
	b.custom_minimum_size = Vector2(maxf(width, caption.length() * 13 + 44), 48)
	b.pressed.connect(action)
	return b


## A text field in the game's style.
static func field(placeholder: String, secret := false, width := 480.0) -> LineEdit:
	var e := LineEdit.new()
	e.placeholder_text = placeholder
	e.secret = secret
	e.custom_minimum_size = Vector2(width, 44)
	UIStyle.text(e, 18)
	return e
