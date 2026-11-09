class_name CityTarget
extends InteractionTarget
## City actions always go through the world's authority, including offline play.
var world: SpaceWorld
var kind := "seat"
var seat := ""
var elevator := -1
var floor := 0

func available(actor: Node3D) -> bool:
	if not super.available(actor): return false
	if kind=="seat" and (world.city.taken(seat) or Leisure.occupied(world.realm_id, seat)): return false
	return true

func refresh(_actor: Node3D) -> void:
	action_text = "Sit down" if kind=="seat" else "Call elevator"

func activate(actor: Node3D) -> bool:
	if not available(actor): return false
	if kind=="seat": Leisure.request(actor as Player, ["use", seat])
	else: world.request(["city", "call", elevator, floor])
	activated.emit(actor)
	return false
