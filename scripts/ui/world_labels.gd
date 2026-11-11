class_name WorldLabels
extends Node
## The "holograms" over the world (names, NPC titles, combat numbers, ship
## names, quest markers): they have a real size, so they shrink with distance
## like what they hang over, but never below a readable minimum on screen and
## never above a maximum up close; past their reach they are not drawn at all.
## Sized through pixel_size (not scale, which some of them animate).
##
## Per node (meta, optional): label_reach (m), label_world (m of text per font
## pixel, Label3D) or label_height (m, Sprite3D).
const REACH := 45.0
const WORLD := 0.011
## On-screen text height, as a share of the screen's height per 36 font pixels.
const MIN_SCREEN := 0.010
const MAX_SCREEN := 0.024


static func register(node: GeometryInstance3D) -> void:
	if node.has_meta("_world_label"): return
	node.set_meta("_world_label", true)
	node.add_to_group("world_labels")
	if node is Label3D: (node as Label3D).fixed_size = false
	elif node is SpriteBase3D: (node as SpriteBase3D).fixed_size = false
	node.visibility_range_end = float(node.get_meta("label_reach", REACH))


func _process(_delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null or camera.projection != Camera3D.PROJECTION_PERSPECTIVE: return
	var screen := get_viewport().get_visible_rect().size.y
	var focal := screen/(2.0*tan(deg_to_rad(camera.fov)*0.5))  # screen pixels per metre, 1 m away
	var eye := camera.global_position
	for node: Node in get_tree().get_nodes_in_group("world_labels"):
		var item := node as GeometryInstance3D
		if item == null or not item.is_visible_in_tree(): continue
		var distance := maxf(0.5, eye.distance_to(item.global_position))
		if distance > float(item.get_meta("label_reach", REACH)): continue
		var units: float  # font pixels (Label3D) or texture pixels (Sprite3D)
		var natural: float  # the metres it is tall at its own size
		var share: float  # how big it may get relative to a 36 px name
		if item is Label3D:
			units = float((item as Label3D).font_size)
			natural = units*float(item.get_meta("label_world", WORLD))
			share = units/36.0
		elif item is Sprite3D and (item as Sprite3D).texture:
			units = float((item as Sprite3D).texture.get_height())
			natural = float(item.get_meta("label_height", 0.9))
			share = 2.0
		else: continue
		var shown := clampf(natural*focal/distance, MIN_SCREEN*share*screen, MAX_SCREEN*share*screen)
		var pixel := shown*distance/focal/units
		var current: float = item.get("pixel_size")
		if absf(current-pixel) > current*0.02: item.set("pixel_size", pixel)
