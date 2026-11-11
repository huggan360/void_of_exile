class_name NearbyLightShadows
extends Node
## Shared Tavern-style soft lamp shadows, with a fixed budget in every world.
const GROUP := "soft_practical_lights"
const SHADOW_LIMIT := 3
const SHADOW_DISTANCE := 40.0
var _timer := 0.0

static func register_light(light: OmniLight3D) -> void:
	light.light_size = 0.45
	light.shadow_blur = 1.2
	light.distance_fade_shadow = 32.0
	light.shadow_enabled = false
	light.add_to_group(GROUP)

func _ready() -> void:
	AppSettings.graphics_changed.connect(_refresh)

func _process(delta: float) -> void:
	_timer -= delta
	if _timer<=0.0:
		_timer = 0.5
		_refresh()

func _refresh() -> void:
	var camera := get_viewport().get_camera_3d()
	var lights: Array[OmniLight3D] = []
	var allow := camera!=null and GraphicsSettings.lamp_shadows(AppSettings.graphics) and not Net.is_server()
	for node in get_tree().get_nodes_in_group(GROUP):
		var light := node as OmniLight3D
		if light == null: continue
		if allow and light.is_visible_in_tree() and light.global_position.distance_squared_to(camera.global_position)<SHADOW_DISTANCE*SHADOW_DISTANCE:
			lights.append(light)
		else: light.shadow_enabled = false
	if camera:
		lights.sort_custom(func(a: OmniLight3D,b: OmniLight3D) -> bool:
			return a.global_position.distance_squared_to(camera.global_position)<b.global_position.distance_squared_to(camera.global_position))
	for i in lights.size(): lights[i].shadow_enabled = i<SHADOW_LIMIT
