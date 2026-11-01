@tool
class_name LayoutRoad
extends Path3D
## A road of the static realm (see RealmLayout): drag the curve's points.
## Width: half the paved width in blocks (main roads 1.7, branches 1.2).

@export var width := 1.2


func to_data() -> Dictionary:
	var points := PackedVector2Array()
	for p in curve.get_baked_points() if curve.point_count > 1 else PackedVector3Array():
		points.append(Vector2(p.x, p.z) + Vector2(position.x, position.z))
	return {points = points, width = width}
