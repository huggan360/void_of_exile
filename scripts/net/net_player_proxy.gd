class_name NetPlayerProxy
extends Node3D
## A connected player as the server's enemies see them: where they are (from
## the client's reports), whether they can be chased yet, and a viewer that
## keeps the terrain around them loaded. Melee hits from bosses (a charge, a
## slam) land on this and are passed to the player's client, which applies
## them like any other hit.

var player_id := 0
var peer_id := 0
## True until the client says its ground has loaded.
var frozen := true
var shield_up := false
var _terrain_viewer: VoxelViewer


func _ready() -> void:
	_terrain_viewer = VoxelViewer.new()
	_terrain_viewer.view_distance = 96
	_terrain_viewer.requires_visuals = false
	add_child(_terrain_viewer)


func take_damage(amount: float, armor_piercing := false, magic := false) -> void:
	Net.server.melee_hit(self, amount, armor_piercing, magic, Vector3.ZERO)


func knockback(push: Vector3) -> void:
	Net.server.melee_hit(self, 0.0, false, false, push)

## Occupants are in a remote room; keep the Surface terrain at their hull
## loaded for authoritative cannon collision and the boarding hatch.
func _physics_process(_delta: float) -> void:
	var island := get_parent() as IslandWorld
	if island and SpaceLayout.pocket_at(global_position)>=0:
		_terrain_viewer.global_position = island.launchpad_center()
	else:
		_terrain_viewer.position = Vector3.ZERO
