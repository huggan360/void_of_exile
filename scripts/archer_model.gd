class_name ArcherModel
extends Node3D
## The Archer's two-bone arms, bow grip and moving string. Faces -Z.
## The player owns facing and step smoothing; animation only moves the inner rig.

const ArmRig = preload("res://scripts/player_arm_rig.gd")
const VOXEL_SIZE := 1.8 / 16.0
const STRIDE_SPEED := 13.0
const STRIDE_ANGLE := deg_to_rad(40.0)
const ARM_SWING := 0.9
const BOUNCE_HEIGHT := 0.09
const WADDLE_ROLL := deg_to_rad(7.0)
const SWAY_PITCH := deg_to_rad(4.0)
const LEAN_FORWARD := deg_to_rad(6.0)
const BREATH_SPEED := 2.2
const BREATH_HEIGHT := 0.012
const SHOT_TIME := 0.25
const BOW_REST := Vector3(5.5, 6.5, -2.2) * VOXEL_SIZE
const BOW_EXTENDED := Vector3(0.4, 8.0, -4.0) * VOXEL_SIZE
const DRAW_GRIP := Vector3(0, 0, -0.3) * VOXEL_SIZE
const STRING_Z := 1.6 * VOXEL_SIZE
const STRING_DRAW := 0.5 * VOXEL_SIZE

var class_id := "archer"
## 0..1: string draw during windup/charge. At 1 the bow trembles a little.
var hold := 0.0
var _rig: Node3D
var _left_arm: Node3D
var _right_arm: Node3D
var _left_hand: Node3D
var _right_hand: Node3D
var _left_leg: Node3D
var _right_leg: Node3D
var _bow: Node3D
var _string_top: MeshInstance3D
var _string_bottom: MeshInstance3D
var _phase := 0.0
var _walk_blend := 0.0
var _time := 0.0
var _shot := 0.0


func _ready() -> void:
	var art := (load("res://characters/archer/model.tscn") as PackedScene).instantiate()
	add_child(art)
	_rig = art.get_node("Rig")
	_left_arm = _rig.get_node("ArmL")
	_right_arm = _rig.get_node("ArmR")
	_left_hand = _left_arm.get_node("ForearmL/LeftHand")
	_right_hand = _right_arm.get_node("ForearmR/RightHand")
	_left_leg = _rig.get_node("LegL")
	_right_leg = _rig.get_node("LegR")
	_bow = _right_hand.get_node("Bow")
	_string_top = _bow.get_node("StringTop")
	_string_bottom = _bow.get_node("StringBottom")
	_pose(0.0, 0.0)


## move_ratio: 0 = standing, 1 = full speed.
func animate(move_ratio: float, delta: float) -> void:
	_time += delta
	_walk_blend = lerpf(_walk_blend, clampf(move_ratio, 0.0, 1.0), minf(1.0, delta * 8.0))
	_phase = fmod(_phase + delta * STRIDE_SPEED * move_ratio, TAU)
	var w := _walk_blend
	var stride := sin(_phase)
	_left_leg.rotation.x = stride * STRIDE_ANGLE * w
	_right_leg.rotation.x = -stride * STRIDE_ANGLE * w
	_shot = maxf(0.0, _shot - delta)
	var shot := _shot / SHOT_TIME
	var drawn := clampf(hold, 0.0, 1.0)
	_pose(maxf(drawn, smoothstep(0.0, 0.7, shot)), maxf(drawn, clampf((shot - 0.75) * 4.0, 0.0, 1.0)))

	var bounce := absf(stride) * BOUNCE_HEIGHT * w
	var breath := sin(_time * BREATH_SPEED) * BREATH_HEIGHT * (1.0 - w)
	_rig.position.y = bounce + breath
	_rig.rotation.z = stride * WADDLE_ROLL * w
	_rig.rotation.x = (-LEAN_FORWARD + cos(_phase * 2.0) * SWAY_PITCH) * w


func play_shot() -> void:
	_shot = SHOT_TIME
	if _rig:
		_pose(1.0, 1.0)


func _pose(extension: float, draw: float) -> void:
	var stride := sin(_phase) * _walk_blend
	var target := BOW_REST.lerp(BOW_EXTENDED, extension)
	# Clear the face before bringing the bow across from the side.
	target.z = lerpf(BOW_REST.z, BOW_EXTENDED.z, smoothstep(0.0, 0.4, extension))
	target.x = lerpf(BOW_REST.x, BOW_EXTENDED.x, smoothstep(0.4, 1.0, extension))
	target.z += stride * 0.25 * VOXEL_SIZE * (1.0 - extension)
	if hold >= 1.0:
		target.y += sin(_time * 55.0) * 0.04 * VOXEL_SIZE
	ArmRig.reach(_right_arm, target, Vector3(1, -1, 0))

	var nock := Vector3(0, 0, STRING_Z + draw * STRING_DRAW)
	var string_target := _rig.to_local(_bow.to_global(nock)) - DRAW_GRIP
	ArmRig.pose(_left_arm, -stride * STRIDE_ANGLE * ARM_SWING, deg_to_rad(15.0 + absf(stride) * 12.0), 0.0, deg_to_rad(-10.0))
	var free_hand := _rig.to_local(_left_hand.global_position)
	var draw_target := free_hand.lerp(string_target, extension)
	var clearance := smoothstep(0.0, 0.25, extension) * (1.0 - smoothstep(0.75, 1.0, extension))
	draw_target.z = minf(draw_target.z, lerpf(free_hand.z, -3.8 * VOXEL_SIZE, clearance))
	ArmRig.reach(_left_arm, draw_target, Vector3(-0.2, -0.5, -1))
	_string_segment(_string_top, Vector3(0, 6 * VOXEL_SIZE, STRING_Z), nock)
	_string_segment(_string_bottom, nock, Vector3(0, -6 * VOXEL_SIZE, STRING_Z))


func _string_segment(segment: MeshInstance3D, start: Vector3, end: Vector3) -> void:
	var offset := end - start
	segment.position = (start + end) * 0.5
	segment.basis = Basis(Quaternion(Vector3.UP, offset.normalized()))
	segment.scale.y = offset.length()
