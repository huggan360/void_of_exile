class_name GroundView
extends SpatialController
## Camera and aiming only: the Surface and Tavern keep their terrain movement.
var camera_mode := 0
var _focus: CameraAttributesPractical
var _focus_camera: Camera3D
var _see_through := 0.0
var _hud: CanvasLayer
var _sight: SpaceCrosshair

func _ready() -> void:
	# Overhead (0) or over the shoulder (1); there is no first person here.
	camera_mode = clampi(int(AppSettings.video.get("space_camera", 0)), 0, 1)
	_hud = ResponsiveUILayer.new()
	_hud.layer = 32
	add_child(_hud)
	var root := (_hud as ResponsiveUILayer).make_ui_root()
	_sight = SpaceCrosshair.new()
	_sight.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_sight.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_sight)
	_build_first_person_shield()

func free_look() -> bool:
	return camera_mode != 0

func _input(event: InputEvent) -> void:
	if player.controls_locked() or player.ui_blocked or player.interacting(): return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_V:
		camera_mode = (camera_mode + 1) % 2
		AppSettings.video.space_camera = camera_mode
		AppSettings.save_preferences()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and free_look():
		player.camera_yaw -= event.relative.x * 0.0022
		look_pitch = clampf(look_pitch - event.relative.y * 0.0022, -1.35, 1.35)
		get_viewport().set_input_as_handled()

func update_camera(delta: float) -> void:
	var fp := false
	first_person = 1.0 if fp else 0.0
	var capture := free_look() and not player.controls_locked() and not player.ui_blocked and not player.interacting() and not player.frozen
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if capture else Input.MOUSE_MODE_VISIBLE
	_sight.mode = "fp" if capture else ""
	_sight.aim_center = _sight.size * 0.5
	_sight.queue_redraw()
	var alive := player.stats.hp > 0.0
	player.model.visible = not fp and alive
	player.status_visuals.visible = not fp and alive
	player.aura.visible = not fp and alive
	_update_first_person_shield()
	player.camera.fov = (78.0 if fp else 72.0) if free_look() else Player.CAMERA_FOV
	if not free_look(): return
	var head := player.global_position + Vector3.UP * (1.57 + player._visual_offset)
	var view := Basis(Vector3.UP, player.camera_yaw) * Basis(Vector3.RIGHT, look_pitch)
	var at := head
	if not fp:
		at += view * Vector3(0.35, 1.05, 4.6)  # over the head: the crosshair sits mid-screen
		# Only the ground pushes the camera in; trees and houses turn see-through.
		var ray := PhysicsRayQueryParameters3D.create(head, at, Player.TERRAIN_LAYER)
		ray.exclude = [player.get_rid()]
		var hit := player.get_world_3d().direct_space_state.intersect_ray(ray)
		if not hit.is_empty(): at = hit.position - (at-head).normalized() * 0.25
		player.model.visible = alive and at.distance_to(head) > 0.65
	player.camera.global_transform = Transform3D(view, at)
	player._apply_shake(delta)

func mouse_point() -> Vector3:
	var point := player.get_viewport().get_visible_rect().size * 0.5
	var origin := player.camera.project_ray_origin(point)
	var direction := player.camera.project_ray_normal(point)
	var ray := PhysicsRayQueryParameters3D.create(origin, origin + direction * 300.0, Player.TERRAIN_LAYER | Player.OBSTACLE_LAYER | Player.ENEMY_LAYER)
	ray.exclude = [player.get_rid()]
	var hit := player.get_world_3d().direct_space_state.intersect_ray(ray)
	return hit.position if not hit.is_empty() else origin + direction * 300.0

func aim_ray() -> Array:
	var origin := player.global_position + player.up_direction
	if first_person > 0.8:
		origin = player.camera.global_position + player.camera.global_basis * Vector3(0.36, -0.2, -0.45)
	var direction := (player._aim_point - origin).normalized()
	if direction.is_zero_approx(): direction = -player.camera.global_basis.z
	return [origin, direction]

## Depth of field (Surface and Tavern, Graphics setting): the character is in
## focus; the distance, and whatever stands between the camera and them
## (treetops seen from overhead), go a little soft.
func _process(delta: float) -> void:
	# The camera actually drawing the world (not always player.camera).
	var camera := get_viewport().get_camera_3d()
	_update_see_through(camera, delta)
	if camera != _focus_camera and is_instance_valid(_focus_camera) and _focus_camera.attributes == _focus:
		_focus_camera.attributes = null
	_focus_camera = camera
	if AppSettings.graphics.get("depth_of_field", "on") != "on" or not is_instance_valid(camera):
		if _focus and is_instance_valid(camera) and camera.attributes == _focus: camera.attributes = null
		return
	if _focus == null or camera.attributes != _focus:
		if _focus == null:
			_focus = CameraAttributesPractical.new()
			_focus.dof_blur_far_enabled = true
			_focus.dof_blur_near_enabled = true
			_focus.dof_blur_amount = 0.028
		camera.attributes = _focus
	var focus := camera.global_position.distance_to(player.global_position + Vector3.UP)
	# Overhead (focus ~38 m) the treetops a few meters above the character
	# already soften and the top of the screen blurs; over the shoulder the
	# same rules leave a few meters around the character sharp.
	_focus.dof_blur_far_distance = focus + maxf(26.0, focus * 0.6)
	_focus.dof_blur_far_transition = maxf(30.0, focus)
	_focus.dof_blur_near_distance = maxf(focus - maxf(4.0, focus * 0.15), focus * 0.5)
	_focus.dof_blur_near_transition = maxf(3.0, focus * 0.3)


## A soft round window opens around the character through whatever stands
## between them and the camera (treetops, roofs, trunks, bushes), overhead and
## over the shoulder: see voxel_model.gdshader.
func _update_see_through(camera: Camera3D, delta: float) -> void:
	var want := 1.0 if is_instance_valid(camera) and player.stats.hp > 0.0 and not player.interacting() else 0.0
	_see_through = move_toward(_see_through, want, delta * 3.0)
	if _see_through <= 0.0 or not is_instance_valid(camera):
		RenderingServer.global_shader_parameter_set("see_through", Vector4.ZERO)
		return
	var body := player.global_position + Vector3.UP * 0.9
	var viewport := get_viewport()
	var scale := viewport.scaling_3d_scale if viewport is Viewport else 1.0
	var at := camera.unproject_position(body) * scale
	var depth := -(camera.global_transform.affine_inverse() * body).z
	# Overhead a wide window; over the shoulder a smaller one round the body.
	var share := 0.2 if camera_mode == 0 else 0.3
	var radius := viewport.get_visible_rect().size.y * scale * share * _see_through
	RenderingServer.global_shader_parameter_set("see_through", Vector4(at.x, at.y, radius, depth))


func _exit_tree() -> void:
	RenderingServer.global_shader_parameter_set("see_through", Vector4.ZERO)
	if _focus and is_instance_valid(_focus_camera) and _focus_camera.attributes == _focus:
		_focus_camera.attributes = null
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if is_instance_valid(_fp_shield): _fp_shield.queue_free()
	player.model.visible = true
	player.status_visuals.visible = true
	player.aura.visible = true
	player.camera.fov = Player.CAMERA_FOV
