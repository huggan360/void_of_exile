class_name SpaceCrosshair
extends Control
## Crosshairs: a dot on foot in first person, a flight reticle for the
## pilot and a ringed gunsight for turret gunners.
var mode := ""

func _draw() -> void:
	var c := size*0.5
	var ink := Color(1, 0.95, 0.85, 0.9)
	var shade := Color(0, 0, 0, 0.55)
	match mode:
		"fp":
			draw_circle(c, 3.5, shade)
			draw_circle(c, 2.2, ink)
		"pilot":
			for a in 4:
				var d := Vector2.from_angle(a*PI*0.5+PI*0.25)
				draw_line(c+d*14.0, c+d*26.0, shade, 4.0)
				draw_line(c+d*14.0, c+d*26.0, ink, 2.0)
			draw_arc(c, 40.0, PI*0.15, PI*0.85, 24, Color(0.5, 1, 0.7, 0.6), 2.0)
		"turret":
			draw_arc(c, 22.0, 0, TAU, 48, shade, 4.0)
			draw_arc(c, 22.0, 0, TAU, 48, Color(0.6, 1, 0.75, 0.95), 2.0)
			for a in 4:
				var d := Vector2.from_angle(a*PI*0.5)
				draw_line(c+d*8.0, c+d*16.0, ink, 2.0)
			draw_circle(c, 2.0, Color(1, 0.4, 0.8))
