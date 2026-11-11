class_name LoadingVine
extends Control
## A living branch: the tip, twigs and leaves follow measured loading progress.
var progress := 0.0:
	set(value):
		progress = clampf(value, 0.0, 1.0)
		queue_redraw()
const SEGMENTS := 24
const INK := Color("f1f1ee")

func _init() -> void:
	custom_minimum_size = Vector2(370, 110)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _point(t: float) -> Vector2:
	return Vector2(14 + t * (size.x - 28), 76 - sin(t * PI * 1.35) * 13 - t * 22)

func _draw() -> void:
	var grown := progress * SEGMENTS
	# Fine dotted soil is a quiet indication of the branch's full span.
	for i in 42:
		if i % 3 == 0: draw_circle(Vector2(14 + i * (size.x - 28) / 41.0, 96), 0.7, Color(1,1,1,0.25))
	for i in SEGMENTS:
		var amount := clampf(grown-i, 0.0, 1.0)
		if amount <= 0.0: break
		var a := _point(float(i)/SEGMENTS)
		var b := _point((i+amount)/SEGMENTS)
		draw_line(a, b, INK, 2.4, true)
		if i % 2 == 0:
			var side := -1.0 if i % 4 == 0 else 1.0
			var growth := clampf((grown-i)*0.7, 0.0, 1.0)
			var tip := a + Vector2(10, side*(18+i%5*2)) * growth
			draw_line(a, tip, INK, 1.3, true)
			if growth > 0.65:
				_leaf(tip, Vector2(9, side*8), (growth-0.65)/0.35)
				_leaf(a.lerp(tip,0.55), Vector2(-9,side*5), (growth-0.65)/0.35)
	# Roots and the newest shoot complete the tree silhouette.
	var root := _point(0)
	for direction in [Vector2(-9,12), Vector2(2,14), Vector2(11,8)]:
		draw_line(root, root+direction, INK, 1.2, true)
	if progress > 0.02: _leaf(_point(progress), Vector2(13,-9), 1.0)

func _leaf(base: Vector2, direction: Vector2, amount: float) -> void:
	# A barely sprouted leaf collapses to a point and cannot be triangulated.
	if amount < 0.05: return
	var tip := base+direction*amount
	var normal := direction.orthogonal().normalized()*3.2*amount
	draw_colored_polygon(PackedVector2Array([base, base.lerp(tip,0.55)+normal, tip, base.lerp(tip,0.55)-normal]), INK)
	draw_line(base,tip,Color("171717"),0.7,true)
