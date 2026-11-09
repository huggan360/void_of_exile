class_name SpatialWorld
extends GameWorld
## A full 3D place (the Theory of Everything, open space): gravity follows
## local surfaces, movement is checked in 3D, and the world shares its own
## events between server and clients through `world_event` / handle_event.
signal world_event(event: Array)
var local_player: Player
var server_build := false

## {frame: Transform3D (origin on the ground, basis.y = up), zone, distance}
func sample_gravity(position: Vector3) -> Dictionary:
	return {frame=Transform3D(Basis.IDENTITY,Vector3(position.x,0.0,position.z)),zone="",distance=0.0}

func surface_frame(position: Vector3) -> Transform3D:
	return sample_gravity(position).frame

func zone_at(position: Vector3) -> String:
	return str(sample_gravity(position).zone)

func first_person_at(_position: Vector3) -> bool:
	return false

## A closed door between two points: {point} to put the mover back, or {}.
func barrier_between(_from: Vector3,_to: Vector3) -> Dictionary:
	return {}

func recovery_point(position: Vector3) -> Vector3:
	return surface_frame(position).origin

## Extra speed (m/s) a move from `from` to `to` may have beyond walking:
## a spacewalker's jetpack, a ship towing someone on its line or deck.
func extra_speed(_from: Vector3,_to: Vector3) -> float:
	return 0.0

func legal_recovery(_from: Vector3,_to: Vector3) -> bool:
	return false

## The local player's controller in this world.
func make_controller(_actor: Player) -> SpatialController:
	return null

## Authority: a player's request ([kind, ...]) from the "theory" action channel.
func server_action(_player_record: Dictionary,_args: Array) -> void:
	pass

func handle_event(_event: Array) -> void:
	pass

## Replicated state for players joining (entry record), and its reader.
func state_wire() -> Dictionary:
	return {}

func apply_state(_data: Dictionary) -> void:
	pass

func cleared_packs() -> Array: return []
func pack_survivors() -> Dictionary: return {}
func update_streaming_multi(_positions: Array,_force := false) -> void: pass
