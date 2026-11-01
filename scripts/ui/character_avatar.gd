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
	# Small portraits show the face; big ones the whole figure. They face -Z.
	if size_px >= 110:
		_camera.fov = 30.0
		_camera.look_at_from_position(Vector3(0.0, 1.25, -4.1), Vector3(0.0, 0.92, 0.0))
	else:
		_camera.fov = 26.0
		_camera.look_at_from_position(Vector3(0.0, 1.32, -1.75), Vector3(0.0, 1.22, 0.0))
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
	if not _live:
		_still.call_deferred()


## Draws a couple of frames (the model builds itself), then holds still.
func _still() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if is_instance_valid(_viewport) and not _live:
		_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE


func _process(delta: float) -> void:
	if _live and _model and _model.has_method("animate"):
		_model.animate(0.0, delta)
