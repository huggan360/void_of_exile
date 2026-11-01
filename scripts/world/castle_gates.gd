extends RefCounted
## NetServer's realm snapshot expects a gate-state provider in every realm.
var entries := {}
func states() -> Array:
	return []
func try_open(_center: Vector2i, _stats: PlayerStats, _pos: Vector3) -> bool:
	return false
