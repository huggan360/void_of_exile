class_name ClassModel
extends Node3D
## A class's figure from its art (characters/<id>/model.tscn: Rig with Body,
## ArmL, ArmR (staff or trident in RightHand), LegL, LegR, pivots at the
## shoulders and hips like the Archer). Walks with the same bouncy waddle as
## ArcherModel and swings the weapon arm forward to cast. Faces -Z.

const STRIDE_SPEED := 13.0
const STRIDE_ANGLE := deg_to_rad(40.0)
const ARM_SWING := 0.8
const WEAPON_ARM_REST := deg_to_rad(18.0)  # the staff held a little forward
const BOUNCE_HEIGHT := 0.09
const WADDLE_ROLL := deg_to_rad(7.0)
const SWAY_PITCH := deg_to_rad(4.0)
const LEAN_FORWARD := deg_to_rad(6.0)
const BREATH_SPEED := 2.2
const BREATH_HEIGHT := 0.012
const SHOT_TIME := 0.25
const CAST_RAISE := deg_to_rad(85.0)  # the weapon arm thrusts forward

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
	var cast := maxf(sin(_shot / SHOT_TIME * PI), hold)
	if _arm_l:
		_arm_l.rotation.x = -stride * STRIDE_ANGLE * ARM_SWING * w
	if _arm_r:
		var tremble := sin(_time * 55.0) * deg_to_rad(2.0) if hold >= 1.0 else 0.0
		_arm_r.rotation.x = lerpf(WEAPON_ARM_REST + stride * STRIDE_ANGLE * 0.25 * w, CAST_RAISE, cast) + tremble
	var bounce := absf(sin(_phase)) * BOUNCE_HEIGHT * w
	var breath := sin(_time * BREATH_SPEED) * BREATH_HEIGHT * (1.0 - w)
	_rig.position.y = bounce + breath
	_rig.rotation.z = stride * WADDLE_ROLL * w
	_rig.rotation.x = (-LEAN_FORWARD + cos(_phase * 2.0) * SWAY_PITCH) * w


func play_shot() -> void:
	_shot = SHOT_TIME
