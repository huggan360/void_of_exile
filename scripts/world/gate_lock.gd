class_name GateLock
extends InteractionTarget
## The lock of a fortress gate (StrongholdGates). Walking up offers to
## inspect it; inspecting turns the camera onto you and the gate, and if you
## carry the fortress's key it offers to use it. While a battle bars the
## gate there is nothing to do but look.
var gates: StrongholdGates
var center := Vector2i.ZERO
var _focus := Node3D.new()
var _key: Item


func _ready() -> void:
	super._ready()
	action_text = "Inspect"
	add_child(_focus)
	# The gate's middle, a few blocks inward from where the lock is offered.
	_focus.position = Vector3(0.5, 2.5, 5.0 if position.z < 0.0 else -5.0)
	_key = Items.make(gates.key_for(center))
	if _key: portrait = _key.icon()


func available(player: Node3D) -> bool:
	return super.available(player) and gates.entries.has(center) \
			and (gates.entries[center].locked or gates.entries[center].sealed)


func refresh(player: Node3D) -> void:
	var entry: Dictionary = gates.entries[center]
	title = entry.fort.display_name
	var key_name := _key.item_name if _key else "its key"
	extra_text = ""
	if not entry.sealed:
		description = "The portcullis is down. A battle rages inside."
		response = "Iron bars, thick as your arm. Nobody gets in or out until the fight is over."
		return
	description = "A sealed gate. Its lock is shaped for the %s." % key_name
	var stats := GameServer.character(player.player_id) if player is Player else null
	if stats and not stats.find_item(gates.key_for(center)).is_empty():
		response = "Your %s fits the lock. It would turn, but it will not come back out." % key_name
		extra_text = "Use key"
	else:
		response = "The gate is shut. Find the %s to open it." % key_name


func focus() -> Node3D:
	return _focus


func extra(player: Node3D) -> void:
	extra_text = ""
	gates.use_key(center, player)
