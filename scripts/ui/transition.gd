class_name Transition
extends ResponsiveUILayer
## Tavern departure/arrival uses voxels; other worlds fade through loading.
const JUMP_TIME := 3.4
const ARRIVE_TIME := 4.0
const FADE_TIME := 0.8
var _warp := ColorRect.new()
var _warp_material := ShaderMaterial.new()
var _loading := preload("res://scripts/ui/ink_loading_screen.gd").new()
var _fracture := PortalFracture.new()
var _busy := false
## Plain black for small moves (getting in and out of a ship).
var _black := ColorRect.new()
var _black_tween: Tween

func _ready() -> void:
	layer = 90
	var root := make_ui_root()
	add_child(_fracture)
	_warp_material.shader = preload("res://shaders/hyperspace.gdshader")
	_warp.material = _warp_material
	_warp.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_warp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_warp.hide()
	root.add_child(_warp)
	root.add_child(_loading)
	_loading.hide()
	_black.color = Color.BLACK
	_black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_black.modulate.a = 0.0
	_black.hide()
	root.add_child(_black)

## Fades the screen to black over `time` (awaitable).
func fade_to_black(time := 0.25) -> void:
	if is_instance_valid(_black_tween): _black_tween.kill()
	_black.show()
	_black_tween = create_tween()
	_black_tween.tween_property(_black, "modulate:a", 1.0, time*(1.0-_black.modulate.a))
	await _black_tween.finished

## Fades back up from black over `time`.
func fade_from_black(time := 0.45) -> void:
	if not _black.visible: return
	if is_instance_valid(_black_tween): _black_tween.kill()
	_black_tween = create_tween()
	_black_tween.tween_property(_black, "modulate:a", 0.0, time)
	_black_tween.tween_callback(_black.hide)
	await _black_tween.finished

func is_black() -> bool:
	return _black.visible and _black.modulate.a>0.5

func is_loading() -> bool:
	return _loading.visible

func is_animating() -> bool:
	return _busy

func set_progress(value: float) -> void:
	_loading.set_progress(value)

func set_destination_name(place_name: String) -> void:
	_loading.set_destination_name(place_name)

func jump_in(place_name: String) -> void:
	if _busy: return
	_busy = true
	_loading.set_destination(place_name)
	_loading.modulate.a = 0.0
	await _fracture.capture(get_viewport().get_camera_3d(),false)
	_loading.show()
	_warp.show()
	_set_strength(0.0)
	var tween := create_tween()
	tween.tween_method(_departure,0.0,1.0,JUMP_TIME)
	await tween.finished
	_fracture.clear()
	_warp.hide()
	_busy = false

func _departure(value: float) -> void:
	_fracture.set_progress(value)
	# Let the solid, lit voxels break apart visibly before acceleration takes over.
	_set_strength(smoothstep(0.38,1.0,value))
	_loading.modulate.a = smoothstep(0.82,1.0,value)

func fade_in(place_name: String) -> void:
	_loading.set_destination(place_name)
	_loading.modulate.a = 0.0
	_loading.show()
	var tween := create_tween()
	tween.tween_property(_loading,"modulate:a",1.0,FADE_TIME)
	await tween.finished

func jump_out() -> void:
	if _busy: return
	_busy = true
	_loading.set_progress(0.97)
	await _fracture.capture(get_viewport().get_camera_3d(),true)
	_loading.set_progress(1.0)
	_warp.show()
	_set_strength(0.25)
	var tween := create_tween()
	tween.tween_method(_arrival,0.0,1.0,ARRIVE_TIME)
	await tween.finished
	_fracture.clear()
	_loading.hide()
	_warp.hide()
	_busy = false

func _arrival(value: float) -> void:
	_fracture.set_progress(value)
	# Keep the portal visible until the first cubes have passed the camera.
	_loading.modulate.a = 1.0-smoothstep(0.16,0.43,value)
	_set_strength(0.25*(1.0-smoothstep(0.1,0.45,value)))

func _set_strength(value: float) -> void:
	_warp_material.set_shader_parameter("strength",value)

## Reveal ordinary travel without capturing or meshing the world.
func reveal() -> void:
	_loading.set_progress(1.0)
	var tween := create_tween()
	tween.tween_property(_loading, "modulate:a", 0.0, FADE_TIME)
	await tween.finished
	_loading.hide()
