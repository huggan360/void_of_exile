class_name SurfaceLaunchpad
extends Node3D
## The Skyward Launch Pad on the Surface, south of Hearthwick (the "launchpad"
## landmark paves its ground): a battleship resting in its cradle, gantry
## towers with lanterns, the shipwright who sells you one (500 Dots) and the
## launch console. Space opens once the Theory of Everything is told.
##
## The docked hull and walk-in rooms are shared with Space through SurfaceShipWorld.
## Launch belongs to whoever occupies the pilot seat, using Space.
const SHIP_REST := Vector3(0, SpaceShip.LANDED_HEIGHT, 2.0)
const ARRIVAL := Vector3(0, 0.2, -16.0)  # where you stand after landing (north, toward the city)
var world: GameWorld
var unlocked := false
var owned := false
var _wright: InteractionTarget
var _console: InteractionTarget
var _busy := false

func build(p_world: GameWorld) -> void:
	world = p_world
	add_to_group("surface_ports")
	var art := NexusStation.Brush.new(self, false, 900.0)
	# The cradle under the ship, brass rails and timber chocks.
	art.box(Vector3(0, 0.5, SHIP_REST.z), Vector3(7.0, 1.0, 22.0), Color("5a4a3a"), true)
	for z in [-7.0, 0.0, 7.0]:
		art.box(Vector3(0, 1.4, SHIP_REST.z+z), Vector3(9.0, 0.6, 1.2), Color("8a5a3a"))
	for side: float in [-1.0, 1.0]:
		art.box(Vector3(side*3.6, 1.1, SHIP_REST.z), Vector3(0.3, 0.2, 22.0), Color("d9ac60"))
	# Two gantry towers with lanterns and a walkway arm reaching for the ship.
	for side: float in [-1.0, 1.0]:
		var at := Vector3(side*11.0, 0, SHIP_REST.z-4.0)
		art.box(at+Vector3(0, 7.0, 0), Vector3(2.2, 14.0, 2.2), Color("6a5a6e"), true)
		for y in [3.0, 7.0, 11.0]:
			art.box(at+Vector3(0, y, 0), Vector3(2.6, 0.3, 2.6), Color("d9ac60"))
		art.box(at+Vector3(-side*3.2, 9.5, 0), Vector3(5.0, 0.4, 1.2), Color("8a5a3a"))
		art.lantern(at+Vector3(side*1.6, 0, 1.6), 4.5)
		art.box(at+Vector3(0, 14.4, 0), Vector3(1.0, 1.0, 1.0), Color("8ad8ff"), false, 2.6)
	# The shipwright's stall and the launch console by the gap in the wall.
	art.box(Vector3(-8.0, 0.55, -14.0), Vector3(4.0, 1.1, 1.4), Color("6a3a2a"), true)
	art.box(Vector3(-8.0, 1.14, -14.0), Vector3(4.2, 0.1, 1.6), Color("d9ac60"))
	art.box(Vector3(8.0, 0.7, -13.5), Vector3(1.6, 1.4, 1.0), Color("3a3a4a"), true)
	art.box(Vector3(8.0, 1.45, -13.8), Vector3(1.3, 0.1, 0.6), Color("8ad8ff"), false, 2.2)
	art.box(Vector3(8.0, 1.9, -13.2), Vector3(1.4, 0.8, 0.12), Color("ffd27a"), false, 1.2)
	art.finish()
	var wright := CreatureModel.new("city_mechanic")
	wright.position = Vector3(-8.0, 0, -12.6)
	wright.rotation.y = PI
	add_child(wright)
	_wright = InteractionTarget.new()
	_wright.title = "Shipwright Odessa"
	_wright.reach = 4.5
	_wright.position = Vector3(0, 1.0, 0.4)
	wright.add_child(_wright)
	_wright.activated.connect(_on_wright)
	_console = InteractionTarget.new()
	_console.title = "Boarding ramp"
	_console.reach = 3.5
	_console.position = Vector3(8.0, 1.0, -13.5)
	add_child(_console)
	_console.activated.connect(_on_launch)
	var lamp := OmniLight3D.new()
	lamp.position = Vector3(0, 6.0, SHIP_REST.z)
	lamp.light_color = Color("ffd8a0")
	lamp.omni_range = 22.0
	lamp.light_energy = 0.9
	lamp.shadow_enabled = false
	add_child(lamp)
	refresh()

func set_state(p_unlocked: bool, p_owned: bool) -> void:
	unlocked = p_unlocked
	owned = p_owned
	refresh()

func refresh() -> void:
	if not is_instance_valid(_wright): return
	_wright.description = "Shipwright"
	_wright.action_text = "Talk"
	_wright.confirm_text = ""
	_wright.cancel_text = "Leave"
	_console.description = ""
	_console.action_text = "Board"
	_console.response = "Boarding..."
	if not unlocked:
		_wright.response = "Finish the Theory of Everything to open the way to Space."
		_console.description = "Space is not unlocked yet."
	else:
		_wright.response = "Buy a battleship or take one out from your fleet."

func _on_wright(_actor: Node3D) -> void:
	refresh()
	if unlocked: get_tree().call_group("fleet_panels", "open_for", _wright)

func _on_launch(actor: Node3D) -> void:
	if not unlocked or _busy or not actor is Player: return
	if Net.is_client(): Net.client.send_action("port", ["board"])
	elif world is IslandWorld:
		var dock := (world as IslandWorld).surface_ships
		dock.local_player = actor
		var record := {player_id = actor.player_id, peer_id = 0, name = "You", account_id = 0, pos = actor.global_position}
		var vessel := dock.ensure_ship(record) if owned else null
		if vessel: dock.server_action(record, ["board", vessel.id])

func on_port_event(ev: Array) -> void:
	if str(ev[1])=="owned":
		owned = bool(ev[2])
		refresh()

func arrival_point() -> Vector3:
	return global_transform*ARRIVAL
