class_name CityTarget
extends InteractionTarget
## City actions always go through the world's authority, including offline play.
var world: SpaceWorld
var kind := "seat"
var seat := ""

func available(actor: Node3D) -> bool:
	if not super.available(actor): return false
	if kind=="seat" and (world.city.taken(seat) or Leisure.occupied(world.realm_id, seat)): return false
	return true

func refresh(_actor: Node3D) -> void:
	if kind=="seat":
		title = "Chair"
		description = "Sit down for a while"
		action_text = "Sit"

func activate(actor: Node3D) -> bool:
	if not available(actor): return false
	if kind=="seat": Leisure.request(actor as Player, ["use", seat])
	activated.emit(actor)
	return false
