class_name PetsClient
extends RefCounted
## Account state is shared by all client worlds, including the Pet Yard.
class Events:
	extends RefCounted
	signal changed
static var _events := Events.new()
static var changed: Signal = _events.changed
static var state := PetDefs.empty_state()

static func receive(data: Dictionary) -> void:
	state = data.duplicate(true)
	changed.emit()

static func hatch() -> void: _request("pet_hatch", [])
static func feed(id: int, bites: int) -> void: _request("pet_feed", [id, bites])
static func merge(a: int, b: int) -> void: _request("pet_merge", [a, b])
static func equip(id: int) -> void: _request("pet_equip", [id])

static func _request(kind: String, args: Array) -> void:
	if Net.is_client(): Net.client.send_action(kind, args)
