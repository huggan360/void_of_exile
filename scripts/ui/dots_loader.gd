class_name DotsLoader
extends Control
## Three game-style dots that bounce in sequence while work is underway.

var _elapsed := 0.0


func _ready() -> void:
	custom_minimum_size = Vector2(58, 28)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)


func _process(delta: float) -> void:
	_elapsed += delta
	queue_redraw()


func _draw() -> void:
	var spacing := 17.0
	var center := size * 0.5
	for i in 3:
		var bounce := maxf(0.0, sin((_elapsed * 7.0) - i * 0.8)) * 5.0
		var alpha := 0.55 + 0.45 * (1.0 - float(i) * 0.12)
		draw_circle(center + Vector2((i - 1) * spacing, -bounce), 4.0, Color(UIStyle.ACCENT, alpha))
