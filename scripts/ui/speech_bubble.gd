class_name SpeechBubble
extends Control
## Screen-space chat attached to a world-space character. New messages replace old ones.

const MAX_CHARACTERS := 140
const MAX_WIDTH := 260.0
static var _layer: ResponsiveUILayer
static var _root: Control
static var _bubbles := {}

var _anchor: WeakRef
var _anchor_id: int
var _height := 2.9
var _background := UIStyle.TEXT
var _border := UIStyle.OUTLINE


static func say(anchor: Node3D, text: String, kind: String, height := 2.9) -> void:
	if not is_instance_valid(anchor) or not anchor.is_inside_tree():
		return
	# Root children cannot be added while a scene is running its _ready callbacks.
	_show_message.call_deferred(weakref(anchor), text, kind, height)


static func _show_message(anchor_ref: WeakRef, text: String, kind: String, height: float) -> void:
	var anchor := anchor_ref.get_ref() as Node3D
	if not is_instance_valid(anchor) or not anchor.is_inside_tree():
		return
	var id := anchor.get_instance_id()
	if _bubbles.has(id):
		var previous = _bubbles[id].get_ref()
		if is_instance_valid(previous):
			previous.hide()
			previous.queue_free()
	if not is_instance_valid(_layer):
		_layer = ResponsiveUILayer.new()
		_layer.name = "SpeechBubbles"
		_layer.layer = 0  # Above the world, below the HUD (layer 1) and its windows.
		anchor.get_tree().root.add_child(_layer)
		_root = _layer.make_ui_root()
	var bubble := SpeechBubble.new()
	bubble._anchor = weakref(anchor)
	bubble._anchor_id = id
	bubble._height = height
	bubble._build(text, kind)
	_bubbles[id] = weakref(bubble)
	_root.add_child(bubble)
	anchor.tree_exiting.connect(bubble.queue_free, CONNECT_ONE_SHOT)
	bubble._follow()
	var tween := bubble.create_tween()
	tween.tween_property(bubble, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(minf(3.5 + 0.06 * mini(text.length(), MAX_CHARACTERS), 9.0) - 0.18)
	tween.tween_property(bubble, "modulate:a", 0.0, 0.4)
	tween.tween_callback(bubble.queue_free)


func _build(content: String, kind: String) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	match kind:
		"tell": _background = Color("b8e6bc")
		"party": _background = Color("d7c4f4")
		"system": _background = UIStyle.GOLD
		"shop": _background = Color("fff4dc")
	_border = _background.darkened(0.72)
	var shown := content.strip_edges().replace("\n", " ").replace("\r", " ").replace("\t", " ")
	if kind == "shop":
		_build_rich(shown)
		return
	if shown.length() > MAX_CHARACTERS:
		shown = shown.left(MAX_CHARACTERS - 1) + "…"
	var label := Label.new()
	label.text = shown
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UIStyle.text(label, UIStyle.SIZE_NORMAL, UIStyle.OUTLINE)
	label.add_theme_constant_override("shadow_offset_x", 0)
	label.add_theme_constant_override("shadow_offset_y", 0)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var width := clampf(UIStyle.font().get_string_size(shown, HORIZONTAL_ALIGNMENT_LEFT, -1, UIStyle.SIZE_NORMAL).x, 24.0, MAX_WIDTH - 24.0)
	var measured := UIStyle.font().get_multiline_string_size(shown, HORIZONTAL_ALIGNMENT_LEFT, width, UIStyle.SIZE_NORMAL, -1,
			TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE)
	size = Vector2(ceilf(width) + 24.0, ceilf(measured.y) + 16.0)
	# Containers size children to their minimum: hold the measured size.
	custom_minimum_size = size
	label.position = Vector2(12, 8)
	label.custom_minimum_size = size - Vector2(24, 16)
	label.size = size - Vector2(24, 16)
	add_child(label)
	pivot_offset = Vector2(size.x * 0.5, size.y + 8)
	scale = Vector2.ONE * 0.6


## Shopkeepers' bubbles (game text only, never player chat): BBCode for bold
## and coloured offers. Sized from the plain text, a little wider for bold.
func _build_rich(markup: String) -> void:
	var plain := markup
	var regex := RegEx.create_from_string("\\[[^\\]]*\\]")
	plain = regex.sub(plain, "", true)
	var font_size := UIStyle.SIZE_NORMAL
	var width := clampf(UIStyle.font().get_string_size(plain, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x*1.08, 24.0, MAX_WIDTH - 24.0)
	var measured := UIStyle.font().get_multiline_string_size(plain, HORIZONTAL_ALIGNMENT_LEFT, width, font_size, -1,
			TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE)
	size = Vector2(ceilf(width) + 24.0, ceilf(measured.y) + 18.0)
	custom_minimum_size = size
	var label := RichTextLabel.new()
	label.bbcode_enabled = true
	label.scroll_active = false
	label.fit_content = true
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("normal_font", UIStyle.font())
	label.add_theme_font_override("bold_font", UIStyle.bold())
	label.add_theme_font_size_override("normal_font_size", font_size)
	label.add_theme_font_size_override("bold_font_size", font_size)
	label.add_theme_color_override("default_color", UIStyle.OUTLINE)
	label.add_theme_color_override("font_outline_color", Color(0.12, 0.07, 0.04))
	label.text = markup
	label.position = Vector2(12, 8)
	label.size = size - Vector2(24, 14)
	label.custom_minimum_size = label.size
	add_child(label)
	pivot_offset = Vector2(size.x * 0.5, size.y + 8)
	scale = Vector2.ONE * 0.6


func _process(_delta: float) -> void:
	_follow()


func _follow() -> void:
	var anchor = _anchor.get_ref()
	if not is_instance_valid(anchor) or not anchor.is_inside_tree():
		queue_free()
		return
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		hide()
		return
	var point: Vector3 = anchor.global_position + anchor.global_basis.y.normalized() * _height
	visible = not camera.is_position_behind(point) and camera.global_position.distance_to(point) <= 80.0
	if visible and anchor.has_meta("city_actor"):
		var ray := PhysicsRayQueryParameters3D.create(camera.global_position, point, Player.TERRAIN_LAYER|Player.OBSTACLE_LAYER)
		visible = anchor.get_world_3d().direct_space_state.intersect_ray(ray).is_empty()
	if visible:
		position = (camera.unproject_position(point) / _layer.scale - pivot_offset).round()


func _draw() -> void:
	var center := size.x * 0.5
	draw_colored_polygon(PackedVector2Array([Vector2(center - 9, size.y - 2), Vector2(center, size.y + 9), Vector2(center + 9, size.y - 2)]), _border)
	draw_colored_polygon(_corners(Vector2.ZERO, size, 5), _border)
	draw_colored_polygon(_corners(Vector2(2, 2), size - Vector2(4, 4), 3), _background)
	draw_colored_polygon(PackedVector2Array([Vector2(center - 6, size.y - 3), Vector2(center, size.y + 6), Vector2(center + 6, size.y - 3)]), _background)


func _corners(origin: Vector2, extent: Vector2, cut: float) -> PackedVector2Array:
	return PackedVector2Array([origin + Vector2(cut, 0), origin + Vector2(extent.x - cut, 0),
		origin + Vector2(extent.x, cut), origin + Vector2(extent.x, extent.y - cut),
		origin + Vector2(extent.x - cut, extent.y), origin + Vector2(cut, extent.y),
		origin + Vector2(0, extent.y - cut), origin + Vector2(0, cut)])


func _exit_tree() -> void:
	if _bubbles.has(_anchor_id) and _bubbles[_anchor_id].get_ref() == self:
		_bubbles.erase(_anchor_id)
