class_name JoinScreen
extends Control
## The screen while a game starts or a server lets us in: "Joining
## Singleplayer" (or the server's name), white loading dots and Cancel.
## Cancel stops the join at once; Main takes us back where we came from.

signal cancel_requested

var _title: Label
var _detail: Label
var _cancel: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UIStyle.ornament_panel())
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 16)
	column.custom_minimum_size = Vector2(420, 0)
	panel.add_child(column)
	_title = UIStyle.heading("", 30)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_title)
	var dots := DotsLoader.new()
	dots.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(dots)
	_detail = UIStyle.label("", 16, UIStyle.TEXT_DIM)
	_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_detail)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	_cancel = UIModal.button("Cancel", func() -> void: cancel_requested.emit())
	buttons.add_child(_cancel)
	column.add_child(buttons)
	hide()


## `place`: "Singleplayer" or the server's name; `detail`: what is happening.
func open(place: String, detail := "") -> void:
	_title.text = "Joining %s" % place
	_detail.text = detail
	_detail.visible = detail != ""
	show()


func set_detail(detail: String) -> void:
	_detail.text = detail
	_detail.visible = detail != ""
