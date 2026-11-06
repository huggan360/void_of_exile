class_name CharacterAvatar
extends SubViewportContainer
## A portrait of a class's character, face on: its real model in a little
## lit scene of its own. Used in the character picker, the class choice and
## the death record.

var class_id := ""
var _viewport := SubViewport.new()
var _model: Node3D
var _camera := Camera3D.new()
var _live := false


## size_px: square size; live: keeps animating (breathing) instead of a still.
func _init(p_class_id := "archer", size_px := 56, live := false) -> void:
	stretch = true
	custom_minimum_size = Vector2(size_px, size_px)
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_live = live
	_viewport.own_world_3d = true
	_viewport.transparent_bg = true
	_viewport.size = Vector2i(size_px, size_px) * 2
	_viewport.msaa_3d = Viewport.MSAA_4X
	add_child(_viewport)
	var light := DirectionalLight3D.new()
	light.rotation = Vector3(deg_to_rad(-35.0), deg_to_rad(200.0), 0.0)
	light.light_energy = 1.2
	_viewport.add_child(light)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.75, 0.78, 0.95)
	env.environment.ambient_light_energy = 0.9
	env.environment.background_mode = Environment.BG_CLEAR_COLOR
	_viewport.add_child(env)
	_viewport.add_child(_camera)
	set_class(p_class_id)


func set_class(p_class_id: String) -> void:
	if p_class_id == class_id and _model != null:
		return
	class_id = p_class_id
	if _model:
		_model.queue_free()
	_model = PlayerClasses.make_model(class_id)
	_viewport.add_child(_model)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_frame_head.call_deferred(_model)


## The head is part of the body mesh. Select its vertices above the shoulder
## pivots so hats and hair contribute to the fitted bounds, but weapons do not.
func _frame_head(model: Node3D) -> void:
	if not is_inside_tree():
		await tree_entered
	await get_tree().process_frame
	if model != _model or not is_instance_valid(model):
		return
	var body := model.find_child("Body", true, false) as Node3D
	var shoulder := model.find_child("ArmL", true, false) as Node3D
	if body == null or shoulder == null:
		return
	var points := PackedVector3Array()
	var cutoff := shoulder.global_position.y
	for node: Node in body.find_children("*", "MeshInstance3D", true, false):
		var mesh_node := node as MeshInstance3D
		if mesh_node.mesh == null:
			continue
		for surface in mesh_node.mesh.get_surface_count():
			var arrays := mesh_node.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			for vertex: Vector3 in vertices:
				var point := mesh_node.global_transform * vertex
				if point.y >= cutoff:
					points.append(point)
	if points.is_empty():
		return
	var bounds := AABB(points[0], Vector3.ZERO)
	for point: Vector3 in points:
		bounds = bounds.expand(point)
	var center := bounds.get_center()
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.size = maxf(bounds.size.x, bounds.size.y) * 1.22 + 0.04
	_camera.look_at_from_position(center + Vector3(0, 0, -bounds.size.z - 3.0), center)
	if not _live:
		_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE


func _process(delta: float) -> void:
	if _live and _model and _model.has_method("animate"):
		_model.animate(0.0, delta)
