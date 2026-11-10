class_name LeisureTarget
extends InteractionTarget
## Reusable chair, dispenser, cigar box or tabletop spot. Stable keys and
## authored transforms work the same on clients and collision-only servers.
var key := ""
var kind := "tap"
var drink := "beer"
var place: GameWorld
var pose := Transform3D.IDENTITY
var stand := Vector3.ZERO
var seat_height := 0.45
var bench := false

func _ready() -> void:
	super._ready()
	add_to_group("leisure_targets")
	Leisure.register_target(self)
	reach = 2.5
	refresh(null)

func spec() -> Dictionary:
	if kind=="seat":
		var frame := global_transform*pose
		return {kind = kind, key = key, pos = frame.origin+frame.basis.y*(seat_height-0.6), basis = frame.basis.orthonormalized(), yaw = 0.0, stand = global_transform*stand, drink = drink}
	return {kind = kind, key = key, pos = global_position, basis = global_basis, drink = drink}

func available(actor: Node3D) -> bool:
	if not super.available(actor): return false
	if kind=="seat": return not Leisure.occupied(place.realm_id, key)
	if kind=="table" and actor is Player:
		var has_cup: bool = not Leisure.state(actor.player_id).get("cup", {}).is_empty()
		var table_full: bool = Leisure.tables.get(place.realm_id, {}).has(key)
		return has_cup!=table_full and not Leisure.smoking(actor.player_id)
	return true

func refresh(actor: Node3D) -> void:
	var s := Leisure.state(actor.player_id) if actor is Player else {}
	match kind:
		"seat": title = "Bench" if bench else "Chair"; action_text = "Sit"
		"tap":
			title = "Coffee pot" if drink=="coffee" else "Beer tap"
			action_text = "Refill" if not s.get("cup", {}).is_empty() and s.cup.kind==drink else "Order beer" if drink=="beer" and (key.begins_with("citytap|") or key=="lastlight:beer") else "Pour"
		"table":
			var occupied: bool = Leisure.tables.get(place.realm_id, {}).has(key)
			title = "Tabletop"
			action_text = "Pick up cup" if occupied else "Put cup down"
		"cigar": title = "Cigar box"; action_text = "Take a cigar"
	description = "Sit down for a while" if kind=="seat" else ""

func activate(actor: Node3D) -> bool:
	if not actor is Player or not available(actor): return false
	Leisure.request(actor, ["cigar"] if kind=="cigar" else ["use", key])
	activated.emit(actor)
	return false

func _exit_tree() -> void:
	if is_instance_valid(Leisure): Leisure.unregister_target(self)
