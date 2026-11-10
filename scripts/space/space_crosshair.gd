class_name SpaceCrosshair
extends Control
## Crosshairs: a dot on foot in first person, a flight reticle for the
## pilot and a ringed gunsight for turret gunners.
var mode := ""
var locks: Array[Vector2] = []
var lock_radius := 0.0
var aim_center := Vector2.INF
var lock_ids: Array[String] = []
var _appeared := {}
const LOCK_TWIST_TIME := 0.28

func set_locks(points: Array[Vector2], ids: Array[String]) -> void:
	locks = points
	lock_ids = ids
	var keep := {}
	for id in ids:
		keep[id] = _appeared.get(id, Time.get_ticks_msec())
	_appeared = keep
	queue_redraw()

func _process(_delta: float) -> void:
	if mode not in ["turret", "pilot"]:
		if not locks.is_empty():
			locks.clear()
			lock_ids.clear()
			_appeared.clear()
		return
	for started in _appeared.values():
		if float(Time.get_ticks_msec()-int(started))/1000.0<LOCK_TWIST_TIME:
			queue_redraw()
			break

func _draw() -> void:
	var c := aim_center if mode in ["pilot", "fp"] and aim_center.is_finite() else size*0.5
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
	if mode in ["pilot", "turret"]:
		if lock_radius>0.0: draw_arc(c, lock_radius, 0, TAU, 64, Color(0.55, 0.9, 1.0, 0.25), 1.0)
		for i in locks.size():
			var point := locks[i]
			var age := float(Time.get_ticks_msec()-int(_appeared.get(lock_ids[i], Time.get_ticks_msec())))/1000.0
			var t := clampf(age/LOCK_TWIST_TIME, 0.0, 1.0)
			var angle := (1.0-pow(1.0-t, 3.0))*PI*0.25
			var square := PackedVector2Array()
			for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1), Vector2(-1, -1)]:
				square.append(point+(corner*12.0).rotated(angle))
			draw_polyline(square, Color(0.12, 0.0, 0.0, 0.8), 4.0, true)
			draw_polyline(square, Color(1.0, 0.16, 0.12, 0.95), 2.0, true)
