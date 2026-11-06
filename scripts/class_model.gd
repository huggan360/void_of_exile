class_name ClassModel
extends Node3D
## A class's figure from its art (characters/<id>/model.tscn: Rig with Body,
## ArmL/ArmR with separate elbows and wrists, LegL/LegR). Faces -Z.
## Wrists keep the staff upright at rest and tip it forward while casting.

const ArmRig = preload("res://scripts/player_arm_rig.gd")
const STRIDE_SPEED := 13.0
const STRIDE_ANGLE := deg_to_rad(40.0)
const ARM_SWING := 0.8
const WEAPON_ARM_REST := deg_to_rad(32.0)
const ELBOW_REST := deg_to_rad(55.0)
const BOUNCE_HEIGHT := 0.09
const WADDLE_ROLL := deg_to_rad(7.0)
const SWAY_PITCH := deg_to_rad(4.0)
const LEAN_FORWARD := deg_to_rad(6.0)
const BREATH_SPEED := 2.2
const BREATH_HEIGHT := 0.012
const SHOT_TIME := 0.25
const CAST_RAISE := deg_to_rad(85.0)  # the weapon arm thrusts forward
const CAST_TIP := deg_to_rad(-35.0)  # +Y shaft tips toward -Z

var class_id := ""
## 0..1: how far a charged/wound-up attack is held.
var hold := 0.0
var _rig: Node3D
var _arm_l: Node3D
var _arm_r: Node3D
var _leg_l: Node3D
var _leg_r: Node3D
var _phase := 0.0
var _walk_blend := 0.0
var _time := 0.0
var _shot := 0.0


func _init(p_class_id: String) -> void:
	class_id = p_class_id


func _ready() -> void:
	var scene: PackedScene = load("res://characters/%s/model.tscn" % class_id)
	var art := scene.instantiate()
	add_child(art)
	_rig = art.get_node("Rig")
	_arm_l = _rig.get_node_or_null("ArmL")
	_arm_r = _rig.get_node_or_null("ArmR")
	_leg_l = _rig.get_node_or_null("LegL")
	_leg_r = _rig.get_node_or_null("LegR")
	_pose(0.0)


func animate(move_ratio: float, delta: float) -> void:
	if _rig == null:
		return
	_time += delta
	_walk_blend = lerpf(_walk_blend, clampf(move_ratio, 0.0, 1.0), minf(1.0, delta * 8.0))
	_phase = fmod(_phase + delta * STRIDE_SPEED * move_ratio, TAU)
	var w := _walk_blend
	var stride := sin(_phase)
	if _leg_l:
		_leg_l.rotation.x = stride * STRIDE_ANGLE * w
	if _leg_r:
		_leg_r.rotation.x = -stride * STRIDE_ANGLE * w
	_shot = maxf(0.0, _shot - delta)
	_pose(maxf(smoothstep(0.0, 0.7, _shot / SHOT_TIME), clampf(hold, 0.0, 1.0)))
	var bounce := absf(sin(_phase)) * BOUNCE_HEIGHT * w
	var breath := sin(_time * BREATH_SPEED) * BREATH_HEIGHT * (1.0 - w)
	_rig.position.y = bounce + breath
	_rig.rotation.z = stride * WADDLE_ROLL * w
	_rig.rotation.x = (-LEAN_FORWARD + cos(_phase * 2.0) * SWAY_PITCH) * w


func play_shot() -> void:
	_shot = SHOT_TIME
	if _rig:
		_pose(1.0)


func _pose(cast: float) -> void:
	var stride := sin(_phase) * _walk_blend
	ArmRig.pose(_arm_l, -stride * STRIDE_ANGLE * ARM_SWING, deg_to_rad(15.0 + absf(stride) * 12.0), 0.0, deg_to_rad(-10.0))
	var tremble := sin(_time * 55.0) * deg_to_rad(1.0) if hold >= 1.0 else 0.0
	var shoulder := lerpf(WEAPON_ARM_REST + stride * deg_to_rad(4.0), CAST_RAISE, cast)
	ArmRig.pose(_arm_r, shoulder + tremble, lerpf(ELBOW_REST, deg_to_rad(5.0), cast), CAST_TIP * cast)
