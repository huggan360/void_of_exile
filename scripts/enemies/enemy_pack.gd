class_name EnemyPack
extends RefCounted
## A group of enemies spawned together at one site: they share alertness (hit
## one and they all come), and members can follow a leader.

signal wiped_out(pack: EnemyPack)
signal members_changed(pack: EnemyPack)

var site: Dictionary  # {id, pack, pos, seed}
var members: Array[Enemy] = []
var leader: Enemy
## Optional coordinated idle route; follows the living patrol leader.
var patrol: EnemyPatrol
## Captured at wake, so saved finite survivors remain finite after table updates.
var respawn_time := 120.0


func alert() -> void:
	for m in members:
		if is_instance_valid(m):
			m.activate()


func any_fighting() -> bool:
	for m in members:
		if is_instance_valid(m) and m.state == Enemy.State.ACTIVE:
			return true
	return false


## Enemy type ids of the members still alive (to bring back the same ones).
func survivors() -> Array:
	var out := []
	for m in members:
		if is_instance_valid(m) and m.is_alive() and not m.is_minion:
			out.append(m.def.id)
	return out


func _on_member_died(enemy: Enemy) -> void:
	members.erase(enemy)
	if enemy == leader:
		leader = null
	members_changed.emit(self)
	if members.is_empty():
		wiped_out.emit(self)
