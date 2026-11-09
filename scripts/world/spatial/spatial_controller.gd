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
