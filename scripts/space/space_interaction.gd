class_name SpaceInteraction
extends InteractionTarget
## Station and ship devices: the command table (launch or board a ship), the
## rocket home to the Tavern, a ship's seats and its hatch, and boarding a
## landed ship from outside. Each sends one request to the authority.
var world: SpaceWorld
var kind := "table"  # table, rocket, seat, hatch, outside, repair, airlock, tap
var part := ""
var seat := ""
var ship_id := 0
var mark_id := ""

const SEAT_TITLES := {pilot = "Pilot's helm", turret_top = "Top cannon", turret_left = "Port cannon",
	turret_right = "Starboard cannon", map = "Star map table", chair_0 = "Armchair", chair_1 = "Armchair", chair_2 = "Armchair", chair_3 = "Armchair"}

func _ready() -> void:
	super._ready()
	reach = 3.0 if kind in ["seat", "hatch", "tap", "airlock", "repair"] else 9.0 if kind in ["outside", "repair_out", "airlock_out"] else 4.0
	match kind:
		"table":
			title = "Command table"
			description = "A glowing star map of the Reach. Ships of the Nexus fleet answer to it."
		"board":
			title = "Campaign board"
			description = "Captain Isolde pins the tales of the Reach here."
			action_text = "Read"
		"rocket":
			title = "Rocket to the Tavern"
			description = "Orin's little rocket flies straight home to the Tavern."
			action_text = "Fly home"
		"seat":
			title = SEAT_TITLES.get(seat, "Seat")
			description = "Sink into it. X for a sip, C for a cigar, Z to stand." if seat.begins_with("chair") else "Take the seat. Z stands up again."
			action_text = "Sit"
		"repair", "repair_out":
			title = str(SpaceShip.PARTS.get(part, {}).get("name", "Part"))
			action_text = "Mend"
		"airlock":
			title = "Airlock"
			description = "Both doors cycle: out onto the hull, jetpack on."
			action_text = "Go out"
		"airlock_out":
			title = "Airlock"
			description = "Back inside the ship."
			action_text = "Go in"
		"wright":
			action_text = "Buy a ship (%d Dots)" % SpaceWorld.SHIP_PRICE
			response = "Fitting her out on the shipyard pad..."
		"tap":
			title = "Beer tap"
			description = "Nexus amber, brewed in the station's own cellar."
			action_text = "Pour a beer"
		"hatch":
			title = "Boarding hatch"
			description = "The round door at the stern."
			action_text = "Go out"
		"outside":
			title = "Ship's ramp"
			description = "Climb back aboard."
			action_text = "Board"
		"mark":
			description = "Part of your tale."
			action_text = "Search" if not title.begins_with("Cracked") and not title.begins_with("Shattered") and not title.begins_with("Jammed") else "Mend"

func available(actor: Node3D) -> bool:
	# Seated crew use their seat's own controls (X lands the ship).
	if kind=="mark": return super.available(actor)
	if kind in ["repair", "repair_out"]:
		var ship := _repair_ship(actor)
		if ship==null or ship.part(part)>=1.0: return false
	if actor is Player and is_instance_valid(world) and world.ship_of((actor as Player).player_id)!=null: return false
	return super.available(actor)

func refresh(actor: Node3D) -> void:
	if kind in ["repair", "repair_out"]:
		var ship := _repair_ship(actor)
		description = "%s: %d%%. Mending it restores some of the hull." % [title, roundi(ship.part(part)*100.0)] if ship else ""
		return
	if kind!="table": return
	var mine := _ships_for(actor)
	extra_text = ""
	if mine.is_empty():
		action_text = "Launch a ship (%d Dots)" % SpaceWorld.SHIP_PRICE
		response = "A new battleship is fitted at a free berth. Your party can board it with you. Free while your party is on a Reach tale."
	else:
		var ship: SpaceShip = mine[0]
		action_text = "Board %s" % ship.name
		response = "Boarding %s..." % ship.name
		if not world.ships.values().any(func(s: SpaceShip) -> bool: return s.owner==(actor as Player).player_id):
			extra_text = "Launch your own"

func _ships_for(actor: Node3D) -> Array:
	var pid := (actor as Player).player_id
	var party := 0
	var game := world.get_parent()
	if game!=null and game.get("social") is SocialClient: party = int((game.get("social") as SocialClient).party.get("id", 0))
	return world.ships.values().filter(func(s: SpaceShip) -> bool:
		return s.owner==pid or (party!=0 and s.party==party))

func activate(actor: Node3D) -> bool:
	if not available(actor): return false
	match kind:
		"table":
			var mine := _ships_for(actor)
			if mine.is_empty(): world.request(["spawn"])
			else: world.request(["board", (mine[0] as SpaceShip).id])
		"board":
			var game := world.get_parent()
			if game!=null and game.get("campaign") is CampaignClient: (game.get("campaign") as CampaignClient).open_book()
		"rocket":
			if (actor as Player).spatial_controller is SpaceTraversal:
				((actor as Player).spatial_controller as SpaceTraversal).fly_rocket_home()
		"seat":
			world.request(["sit", seat])
		"hatch":
			world.request(["hatch"])
		"outside":
			world.request(["board", ship_id])
		"mark":
			if Net.is_client(): Net.client.send_action("camp", ["quest", "obj:"+mark_id])
		"repair":
			world.request(["repair", part])
		"repair_out":
			world.request(["repair", ship_id, part])
		"airlock", "airlock_out":
			world.request(["airlock"])
		"tap":
			world.request(["pour"])
		"wright":
			world.request(["buy_ship", part])
	activated.emit(actor)
	return kind in ["table", "board"]

func _repair_ship(actor: Node3D) -> SpaceShip:
	if kind=="repair_out": return world.ships.get(ship_id)
	return world.ship_in_slot(SpaceLayout.pocket_at(actor.global_position))

func extra(_actor: Node3D) -> void:
	if kind=="table": world.request(["spawn"])
