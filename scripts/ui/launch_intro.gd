extends CanvasLayer
## A short branding reveal over the already prepared start screen.

var _root := Control.new()
var _background := TextureRect.new()
var _logo_group := Control.new()


func _ready() -> void:
	layer = 120
	add_child(_root)
	# Size explicitly: this root belongs to a CanvasLayer, not a Control.
	_resize()
	get_viewport().size_changed.connect(_resize)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	var black := ColorRect.new()
	black.color = Color.BLACK
	_root.add_child(black)
	black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_background.texture = preload("res://assets/branding/launch_background.png")
	_background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_background.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_background)
	_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_background.modulate.a = 0.0
	_root.add_child(_logo_group)
	_logo_group.anchor_left = 0.34
	_logo_group.anchor_top = 0.325
	_logo_group.anchor_right = 0.66
	_logo_group.anchor_bottom = 0.675
	_logo_group.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_logo_group.modulate.a = 0.0
	for is_shadow in [true, false]:
		var logo := TextureRect.new()
		logo.texture = preload("res://assets/branding/launch_logo.png")
		logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		logo.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_logo_group.add_child(logo)
		logo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		if is_shadow:
			logo.modulate = Color(0.0, 0.0, 0.0, 0.4)
			logo.position.y += 7.0


func play() -> void:
	# Preferences are applied by AppSettings before Main starts. Give the
	# desktop time to finish the fullscreen switch before starting the clock.
	await get_tree().process_frame
	await get_tree().create_timer(0.25).timeout
	await get_tree().process_frame
	_resize()
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_background, "modulate:a", 1.0, 1.2)
	tween.tween_property(_logo_group, "modulate:a", 1.0, 1.0)
	tween.tween_interval(1.6)
	tween.tween_property(_root, "modulate:a", 0.0, 1.2)
	await tween.finished
	queue_free()


func _resize() -> void:
	_root.size = get_viewport().get_visible_rect().size


func _input(event: InputEvent) -> void:
	# Keep clicks and keys from reaching the menu during the reveal.
	if event is InputEventKey or event is InputEventMouse or event is InputEventJoypadButton or event is InputEventJoypadMotion or event is InputEventScreenTouch or event is InputEventScreenDrag:
		get_viewport().set_input_as_handled()
