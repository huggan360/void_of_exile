class_name FleetRecallTarget
extends InteractionTarget
## Owner-only recall beside the hatch, including remote planet landing sites.
var world: SpaceWorld
var ship_id := 0

func _ready() -> void:
	super._ready()
	title = "Store ship"
	description = ""
	action_text = "Store ship"
	response = "Return this ship to your fleet?"
	confirm_text = "Store ship"
	cancel_text = "Leave"
	reach = 3.0

func available(actor: Node3D) -> bool:
	var ship: SpaceShip = world.ships.get(ship_id) if is_instance_valid(world) else null
	return ship!=null and ship.fleet_id>0 and ship.account_id==int(Account.data.get("account", {}).get("id", 0)) and ship.mode in ["landed", "berth"] and super.available(actor)

func confirm(actor: Node3D) -> bool:
	if not available(actor) or not Net.is_client(): return false
	var ship := world.ships[ship_id] as SpaceShip
	Net.client.send_action("fleet", ["recall", ship.fleet_id])
	return true
