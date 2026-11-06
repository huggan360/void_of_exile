class_name SpatialController
extends Node
## Drives the local player in a full 3D world (SpatialWorld): its own gravity,
## camera and aiming. Player delegates physics and aim to it while it exists.
var player: Player
var first_person := 0.0
var look_pitch := 0.0
var cinematic := false

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
