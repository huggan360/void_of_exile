class_name ArcherModel
extends Node3D
## The Archer, assembled from .vox parts with pivots at the shoulders and hips
## so the limbs can swing. 16 voxels tall = 1.8 m. Faces -Z.
## The player owns this node's transform (facing, step smoothing); the walk
## animation only moves the inner rig.

const VOXEL_SIZE := 1.8 / 16.0
const PART_DIR := "res://characters/archer/"

# Min corner of each part's frame in its own voxel coords (see tools/make_hero.py).
const BODY_MIN := Vector3(-8, 0, -8)
const ARM_MIN := Vector3(-1, -5, -1)
const LEG_MIN := Vector3(-1, -4, -2)
const BOW_MIN := Vector3(0, -6, 0)

# Where the limbs attach, in body voxel coords.
const LEFT_SHOULDER := Vector3(-4, 9, 0)
const RIGHT_SHOULDER := Vector3(4, 9, 0)
const LEFT_HIP := Vector3(-2, 4, 0)
const RIGHT_HIP := Vector3(1, 4, 0)
const HAND := Vector3(0, -4.5, 0)

## The bow arm is held forward at this angle so the bow sits in front, clear of the ground.
const BOW_ARM_RAISE := deg_to_rad(60.0)

# Walk cycle: a short, bouncy waddle.
const STRIDE_SPEED := 13.0  # radians of walk phase per second at full speed
const STRIDE_ANGLE := deg_to_rad(40.0)
const ARM_SWING := 0.9  # free arm swing relative to the legs
const BOW_ARM_SWING := deg_to_rad(8.0)
const BOUNCE_HEIGHT := 0.09  # meters, one hop per step
const WADDLE_ROLL := deg_to_rad(7.0)  # rock side to side onto the stance leg
const SWAY_PITCH := deg_to_rad(4.0)  # rock back and forth with each step
const LEAN_FORWARD := deg_to_rad(6.0)
const BREATH_SPEED := 2.2
const BREATH_HEIGHT := 0.012
# Shooting: the free arm snaps back as if drawing the string, then returns.
const SHOT_TIME := 0.25
const SHOT_DRAW := deg_to_rad(-80.0)

var _rig: Node3D
var _left_arm: Node3D
var _right_arm: Node3D
var _left_leg: Node3D
var _right_leg: Node3D
var _phase := 0.0
var _walk_blend := 0.0
var _time := 0.0
var _shot := 0.0
## 0..1: how far the string is held drawn (windup and charged shots). At
## 1 the bow trembles a little.
var hold := 0.0


func _ready() -> void:
	var arm_mesh := VoxModel.load_mesh(PART_DIR + "arm.vox")
	var leg_mesh := VoxModel.load_mesh(PART_DIR + "leg.vox")

	# Rig pivot sits at the hips so rocking and leaning look natural.
	_rig = _add_pivot(self, Vector3.ZERO)
	_add_part(_rig, VoxModel.load_mesh(PART_DIR + "body.vox"), BODY_MIN)
	_left_arm = _add_pivot(_rig, LEFT_SHOULDER)
	_right_arm = _add_pivot(_rig, RIGHT_SHOULDER)
	_left_leg = _add_pivot(_rig, LEFT_HIP)
	_right_leg = _add_pivot(_rig, RIGHT_HIP)
	_add_part(_left_arm, arm_mesh, ARM_MIN)
	_add_part(_right_arm, arm_mesh, ARM_MIN)
	_add_part(_left_leg, leg_mesh, LEG_MIN)
	_add_part(_right_leg, leg_mesh, LEG_MIN)

	_left_arm.rotation.x = BOW_ARM_RAISE
	var bow := _add_pivot(_left_arm, HAND)
	bow.rotation.x = -BOW_ARM_RAISE  # keep the bow upright
	_add_part(bow, VoxModel.load_mesh(PART_DIR + "bow.vox"), BOW_MIN + Vector3(-0.5, 0, 0))


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
	var draw := sin(_shot / SHOT_TIME * PI)  # 0 -> 1 -> 0 over the shot
	draw = maxf(draw, hold)
	_right_arm.rotation.x = lerpf(stride * STRIDE_ANGLE * ARM_SWING * w, SHOT_DRAW, draw)
	var tremble := sin(_time * 55.0) * deg_to_rad(2.0) if hold >= 1.0 else 0.0
	_left_arm.rotation.x = BOW_ARM_RAISE + hold * deg_to_rad(20.0) - stride * BOW_ARM_SWING * w * (1.0 - hold) + tremble

	# Hop once per step (twice per cycle), rock toward the planted foot,
	# sway back and forth, and lean into the walk.
	var bounce := absf(sin(_phase)) * BOUNCE_HEIGHT * w
	var breath := sin(_time * BREATH_SPEED) * BREATH_HEIGHT * (1.0 - w)
	_rig.position.y = bounce + breath
	_rig.rotation.z = stride * WADDLE_ROLL * w
	_rig.rotation.x = (-LEAN_FORWARD + cos(_phase * 2.0) * SWAY_PITCH) * w


func play_shot() -> void:
	_shot = SHOT_TIME


func _add_pivot(parent: Node3D, voxel_pos: Vector3) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = voxel_pos * VOXEL_SIZE
	parent.add_child(pivot)
	return pivot


func _add_part(parent: Node3D, mesh: Mesh, min_corner: Vector3) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = VoxModel.material()
	mi.position = min_corner * VOXEL_SIZE
	mi.scale = Vector3.ONE * VOXEL_SIZE
	parent.add_child(mi)
