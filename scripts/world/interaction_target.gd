class_name InteractionTarget
extends Node3D
## Attach to any NPC, prop or landmark. UI handles proximity; game code handles activation.
signal activated(player: Node3D)
signal confirmed(player: Node3D)
@export var title := "Interact"
@export_multiline var description := "Would you like to interact?"
@export var portrait: Texture2D
@export var action_text := "Talk"
@export_multiline var response := "Welcome!"
@export_range(1, 8) var reach := 3.5
@export var enabled := true
## A second action offered once the card is open (e.g. "Use key"); "" hides it.
var extra_text := ""
## Optional final-page confirmation. Opening a conversation never confirms it.
var confirm_text := ""
var cancel_text := "No"
## Devices may receive an authoritative result while their card is open.
var live_response := false
## The key the card shows (and the action that answers it).
var key_action := "interact"
## Optional 1-10 dungeon rating.
var difficulty := -1.0

func _ready() -> void:
	add_to_group("interaction_targets")

func available(player: Node3D) -> bool:
	if not enabled or not is_instance_valid(player) or not is_inside_tree(): return false
	if get_parent() is TownNPC and (get_parent() as TownNPC).scared: return false
	return global_position.distance_to(player.global_position) <= reach

func activate(player: Node3D) -> bool:
	if not available(player): return false
	activated.emit(player)
	return true

## Called before the card shows its texts, so a target can describe the moment.
func refresh(_player: Node3D) -> void:
	pass

## What the camera turns to while the card is open.
func focus() -> Node3D:
	return get_parent() as Node3D if get_parent() is Node3D else self

## The second action was chosen.
func extra(_player: Node3D) -> void:
	pass


func confirm(player: Node3D) -> bool:
	if not available(player): return false
	confirmed.emit(player)
	return true
