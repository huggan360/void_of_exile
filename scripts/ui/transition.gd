class_name Transition
extends ResponsiveUILayer
## Getting from one place to another. Entering a portal jumps to lightspeed
## (the view zooms and smears into streaks for about a second) and fades into
## the loading screen; once the new place is ready it drops back out of
## hyperspace into it. Starting the game fades straight into the loading
## screen instead.
##
##   await transition.jump_in("Realm")   # or fade_in(...)
##   ... load the place ...
##   await transition.jump_out()

const JUMP_TIME := 1.0
const FADE_TIME := 0.3

var _warp := ColorRect.new()
var _warp_material := ShaderMaterial.new()
var _loading := LoadingScreen.new()


func _ready() -> void:
	layer = 90  # over the HUD and menus
	var root := make_ui_root()
	_warp_material.shader = preload("res://shaders/hyperspace.gdshader")
	_warp.material = _warp_material
	_warp.set_anchors_preset(Control.PRESET_FULL_RECT)
	_warp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_warp.hide()
	root.add_child(_warp)
	_loading.hide()
	root.add_child(_loading)


func is_loading() -> bool:
	return _loading.visible


## Jumps to lightspeed, ending on the loading screen for `place_name`.
func jump_in(place_name: String) -> void:
	_loading.set_destination(place_name)
	_loading.modulate.a = 0.0
	_loading.show()
	_warp.show()
	_warp_material.set_shader_parameter("strength", 0.0)
	var tw := create_tween()
	tw.tween_method(_set_strength, 0.0, 1.0, JUMP_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(_loading, "modulate:a", 1.0, FADE_TIME).set_delay(JUMP_TIME - FADE_TIME)
	await tw.finished
	_warp.hide()


## Fades straight into the loading screen (starting the game).
func fade_in(place_name: String) -> void:
	_loading.set_destination(place_name)
	_loading.modulate.a = 0.0
	_loading.show()
	var tw := create_tween()
	tw.tween_property(_loading, "modulate:a", 1.0, FADE_TIME)
	await tw.finished


## Drops out of hyperspace from the loading screen into the world.
func jump_out() -> void:
	_warp.show()
	_set_strength(1.0)
	var tw := create_tween()
	tw.tween_property(_loading, "modulate:a", 0.0, FADE_TIME)
	tw.parallel().tween_method(_set_strength, 1.0, 0.0, JUMP_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tw.finished
	_loading.hide()
	_warp.hide()


func _set_strength(value: float) -> void:
	_warp_material.set_shader_parameter("strength", value)


## The loading screen: a spiralling tunnel of voxel pixels, a pixel-art
## loader in the middle, and where you're going under it.
class LoadingScreen extends Control:
	var _where := Label.new()

	func _init() -> void:
		set_anchors_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_STOP  # nothing gets clicked through it
		theme = UIStyle.theme()
		var tunnel := ColorRect.new()
		var mat := ShaderMaterial.new()
		mat.shader = preload("res://shaders/void_tunnel.gdshader")
		tunnel.material = mat
		tunnel.set_anchors_preset(Control.PRESET_FULL_RECT)
		tunnel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(tunnel)
		var center := CenterContainer.new()
		center.set_anchors_preset(Control.PRESET_FULL_RECT)
		center.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(center)
		var box := VBoxContainer.new()
		box.alignment = BoxContainer.ALIGNMENT_CENTER
		box.add_theme_constant_override("separation", 14)
		center.add_child(box)
		var loader := PixelLoader.new()
		loader.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		box.add_child(loader)
		var going := UIStyle.label("TRAVELLING TO", UIStyle.SIZE_SMALL, UIStyle.TEXT_DIM)
		going.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(going)
		UIStyle.text(_where, UIStyle.SIZE_LARGE, Color(0.85, 0.75, 1.0))
		_where.add_theme_font_override("font", UIStyle.bold())
		_where.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(_where)

	func set_destination(place_name: String) -> void:
		_where.text = place_name


## Eight pixel blocks chasing each other around a ring.
class PixelLoader extends Control:
	const BLOCKS := 8
	const RADIUS := 8.0  # art pixels
	const PX := 6  # screen pixels per art pixel
	const STEP_TIME := 0.08

	func _init() -> void:
		custom_minimum_size = Vector2.ONE * (RADIUS * 2.0 + 4.0) * PX
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var head := int(Time.get_ticks_msec() / 1000.0 / STEP_TIME) % BLOCKS
		var mid := size * 0.5
		for i in BLOCKS:
			var a := TAU * i / BLOCKS - PI * 0.5
			var p := (mid / PX + Vector2(cos(a), sin(a)) * RADIUS).floor() * PX
			var behind := (head - i + BLOCKS) % BLOCKS  # 0 = the leading block
			var c := Color(0.95, 0.92, 1.0).lerp(Color(0.45, 0.22, 0.85), behind / 4.0)
			c.a = clampf(1.0 - behind / float(BLOCKS - 2), 0.15, 1.0)
			var s := (3 if behind == 0 else 2) * PX
			draw_rect(Rect2(p - Vector2.ONE * s * 0.5, Vector2.ONE * s), c)
