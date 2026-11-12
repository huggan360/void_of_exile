class_name SpatialController
extends Node
## Drives the local player in a full 3D world (SpatialWorld): its own gravity,
## camera and aiming. Player delegates physics and aim to it while it exists.
var player: Player
var first_person := 0.0
var look_pitch := 0.0
var cinematic := false
var _fp_shield: MeshInstance3D
var _fp_shield_material: ShaderMaterial
var _focus: CameraAttributesPractical
var _focus_camera: Camera3D
var _focus_distance := -1.0
var _see_through := 0.0

func physics_step(_delta: float) -> void:
	pass

## Where the cursor (or the first-person crosshair) points in the world.
func mouse_point() -> Vector3:
	return player.global_position-player.global_basis.z*10.0

## [origin, direction] of the player's next shot.
func aim_ray() -> Array:
	var origin := player.global_position+player.up_direction
	return [origin,(player._aim_point-origin).normalized()]

func hide_overlay() -> void:
	pass

func start_gate_cinematic(_scene: Dictionary) -> void:
	pass

## Renders the inside of the actual shield bubble for first person (the
## bubble itself only shows its outside). It surrounds the body, follows
## local gravity and stays in place as the player turns their head.
func _build_first_person_shield() -> void:
	_fp_shield = MeshInstance3D.new()
	_fp_shield.name = "FirstPersonShield"
	_fp_shield.set_meta("portal_ignore",true)
	var shield_shape := player.shield._mesh.mesh.duplicate() as SphereMesh
	shield_shape.flip_faces = true
	_fp_shield.mesh = shield_shape
	_fp_shield_material = ShaderMaterial.new()
	_fp_shield_material.shader = preload("res://shaders/warp_shield.gdshader")
	_fp_shield.material_override = _fp_shield_material
	_fp_shield.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_fp_shield.hide()
	player.shield._mesh.add_child(_fp_shield)

func _update_first_person_shield() -> void:
	if not is_instance_valid(_fp_shield): return
	var shield := player.shield
	var intensity := shield._intensity*smoothstep(0.75,1.0,first_person)
	_fp_shield.visible = intensity>0.01 and player.stats.hp>0.0 and not player.input_locked and not cinematic and not player.frozen
	if not _fp_shield.visible: return
	for parameter: String in ["tint","arc_color","rainbow","warp"]:
		var value: Variant = shield._material.get_shader_parameter(parameter)
		if value!=null: _fp_shield_material.set_shader_parameter(parameter,value)
	_fp_shield_material.set_shader_parameter("intensity",intensity)
	_fp_shield_material.set_shader_parameter("pulse",shield._pulse)
	_fp_shield_material.set_shader_parameter("brace",shield._brace*intensity)
	_fp_shield_material.set_shader_parameter("brace_dir",(_fp_shield.global_basis.inverse()*shield._brace_dir).normalized())

## Depth of field (Graphics setting) for the ground cameras: the character is
## in focus; the distance, and whatever stands between the camera and them
## (treetops seen from overhead), go a little soft. A null camera or `off`
## takes it away again.
func _update_focus(camera: Camera3D, delta: float, off := false) -> void:
	if camera != _focus_camera and is_instance_valid(_focus_camera) and _focus_camera.attributes == _focus:
		_focus_camera.attributes = null
	_focus_camera = camera
	if off or AppSettings.graphics.get("depth_of_field", "on") != "on" or not is_instance_valid(camera):
		if _focus and is_instance_valid(camera) and camera.attributes == _focus: camera.attributes = null
		_focus_distance = -1.0
		return
	if _focus == null or camera.attributes != _focus:
		if _focus == null:
			_focus = CameraAttributesPractical.new()
			_focus.dof_blur_far_enabled = true
			_focus.dof_blur_near_enabled = true
			_focus.dof_blur_amount = 0.028
		camera.attributes = _focus
	# Eased, so the blur bands don't breathe with every step, shake or hill.
	var aim := camera.global_position.distance_to(player.global_position + player.up_direction)
	if _focus_distance < 0.0 or absf(aim - _focus_distance) > 20.0:
		_focus_distance = aim
	else:
		_focus_distance = lerpf(_focus_distance, aim, 1.0 - exp(-4.0 * delta))
	var focus := _focus_distance
	# Overhead (focus ~38 m) the treetops a few meters above the character
	# already soften and the top of the screen blurs; over the shoulder the
	# same rules leave a few meters around the character sharp.
	_focus.dof_blur_far_distance = focus + maxf(26.0, focus * 0.6)
	_focus.dof_blur_far_transition = maxf(30.0, focus)
	_focus.dof_blur_near_distance = maxf(focus - maxf(4.0, focus * 0.15), focus * 0.5)
	_focus.dof_blur_near_transition = maxf(3.0, focus * 0.3)

## A soft round window opens around the character through whatever stands
## between them and the camera (treetops, roofs, trunks, bushes), overhead and
## over the shoulder: see voxel_model.gdshader. `share` is the window's radius
## as a share of the screen height; 0 closes it.
func _update_see_through(camera: Camera3D, delta: float, share: float) -> void:
	var want := 1.0 if share > 0.0 and is_instance_valid(camera) and player.stats.hp > 0.0 and not player.interacting() else 0.0
	_see_through = move_toward(_see_through, want, delta * 3.0)
	if _see_through <= 0.0 or not is_instance_valid(camera):
		RenderingServer.global_shader_parameter_set("see_through", Vector4.ZERO)
		return
	var body := player.global_position + player.up_direction * 0.9
	if camera.is_position_behind(body):
		RenderingServer.global_shader_parameter_set("see_through", Vector4.ZERO)
		return
	var viewport := get_viewport()
	var scale := viewport.scaling_3d_scale if viewport is Viewport else 1.0
	var at := camera.unproject_position(body) * scale
	var depth := -(camera.global_transform.affine_inverse() * body).z
	var radius := viewport.get_visible_rect().size.y * scale * share * _see_through
	RenderingServer.global_shader_parameter_set("see_through", Vector4(at.x, at.y, radius, depth))

func _clear_view_effects() -> void:
	RenderingServer.global_shader_parameter_set("see_through", Vector4.ZERO)
	if _focus and is_instance_valid(_focus_camera) and _focus_camera.attributes == _focus:
		_focus_camera.attributes = null
