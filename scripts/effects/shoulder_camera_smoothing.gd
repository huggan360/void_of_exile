class_name ShoulderCameraSmoothing
extends RefCounted
## A small visual follow delay. Input and the player's movement stay immediate.
## Smooth the orbit rotation and its anchor, keeping the intended camera reach.
const FOLLOW_RATE := 24.0
const TURN_RATE := 26.0
const MAX_FOLLOW_LAG := 0.5
const TELEPORT_DISTANCE := 8.0
var _ready := false
var _focus := Vector3.ZERO
var _last_focus := Vector3.ZERO
var _basis := Basis.IDENTITY

func reset() -> void:
	_ready = false

func follow(wanted: Transform3D, focus: Vector3, delta: float) -> Transform3D:
	if not _ready or focus.distance_to(_last_focus) > TELEPORT_DISTANCE:
		_ready = true
		_focus = focus
		_basis = wanted.basis.orthonormalized()
	else:
		var dt := maxf(delta, 0.0)
		_focus = _focus.lerp(focus, 1.0 - exp(-FOLLOW_RATE * dt))
		_focus = focus + (_focus - focus).limit_length(MAX_FOLLOW_LAG)
		_basis = _basis.slerp(wanted.basis.orthonormalized(), 1.0 - exp(-TURN_RATE * dt)).orthonormalized()
	_last_focus = focus
	var offset := wanted.basis.inverse() * (wanted.origin - focus)
	return Transform3D(_basis, _focus + _basis * offset)
