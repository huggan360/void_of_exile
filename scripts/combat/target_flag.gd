class_name TargetFlag
extends Node3D
## Add this child to any object to make it eligible for turret targeting.
## Its position is the aim point. Turn target off to opt out temporarily.
signal hit(damage: int, direction: Vector3, source: Node)
@export var target := true
@export var hit_radius := 1.0

func _ready() -> void:
	add_to_group("turret_targets")

func eligible() -> bool:
	if not target or not is_inside_tree(): return false
	var body := get_parent() as Node3D
	if not is_instance_valid(body) or not body.is_visible_in_tree(): return false
	if body is Enemy: return body.is_alive() and body.collision_layer!=0
	return true

func velocity() -> Vector3:
	var body := get_parent()
	return body.velocity if body is CharacterBody3D else Vector3.ZERO

func receive_hit(damage: int, direction: Vector3, source: Node) -> void:
	if not eligible(): return
	var body := get_parent()
	if body.has_method("take_hit"): body.take_hit(global_position, direction, damage, source)
	hit.emit(damage, direction, source)

## Find a flag on a collider's owner, including colliders nested under it.
static func for_body(body: Node) -> TargetFlag:
	var current := body
	while is_instance_valid(current) and not current is GameWorld:
		for child in current.get_children():
			if child is TargetFlag and child.eligible(): return child
		current = current.get_parent()
	return null
