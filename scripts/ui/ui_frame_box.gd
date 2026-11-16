class_name UIFrameBox
extends StyleBox
## A dark card with the buttons' bevelled stone edge drawn inside its own
## rect (UIStyle.framed): the frame never makes a box larger.

@export var fill: StyleBox
@export var frame: StyleBox
@export var edge := 8.0


func _draw(to_canvas_item: RID, rect: Rect2) -> void:
	# The fill stops under the frame's band, so the bevelled corners stay open.
	fill.draw(to_canvas_item, rect.grow(-edge * 0.4))
	frame.draw(to_canvas_item, rect)
