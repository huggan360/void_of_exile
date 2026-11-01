class_name LevelDiamond
extends Control
## The account level in a rhombus: a gold-edged diamond with the number in it.

var level := 1:
	set(value):
		level = value
		queue_redraw()
var fill := Color(0.75, 0.28, 0.12)


func _init(size_px := 48.0) -> void:
	custom_minimum_size = Vector2(size_px, size_px)
	mouse_filter = Control.MOUSE_FILTER_PASS


func _draw() -> void:
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.5
	var outer := PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0)])
	draw_colored_polygon(outer, UIStyle.OUTLINE)
	var g := r - 3.0
	draw_colored_polygon(PackedVector2Array([c + Vector2(0, -g), c + Vector2(g, 0), c + Vector2(0, g), c + Vector2(-g, 0)]), UIStyle.GOLD)
	var i := r - 6.0
	draw_colored_polygon(PackedVector2Array([c + Vector2(0, -i), c + Vector2(i, 0), c + Vector2(0, i), c + Vector2(-i, 0)]), fill)
	draw_colored_polygon(PackedVector2Array([c + Vector2(0, -i), c + Vector2(i, 0), c + Vector2(0, 0), c + Vector2(-i, 0)]), Color(1, 1, 1, 0.12))
	var text := str(level)
	var font := UIStyle.bold()
	var fs := int(r * (0.62 if text.length() < 3 else 0.48))
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string_outline(font, c + Vector2(-w * 0.5, fs * 0.36), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 6, UIStyle.OUTLINE)
	draw_string(font, c + Vector2(-w * 0.5, fs * 0.36), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UIStyle.TEXT)
