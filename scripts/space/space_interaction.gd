class_name SpaceInteraction
extends InteractionTarget
## Station and ship devices: the command table (launch or board a ship), the
## rocket down to the Surface, a ship's seats and its hatch, and boarding a
## landed ship from outside. Each sends one request to the authority.
var world: SpaceWorld
var kind := "table"  # table, rocket, seat, hatch, outside, repair, ladder, deck_hatch, tap
var part := ""
var seat := ""
var ship_id := 0
var mark_id := ""

const SEAT_TITLES := {pilot = "Pilot's helm", turret_top = "Top cannon", turret_left = "Port cannon",
	turret_right = "Starboard cannon", map = "Star map table", chair_0 = "Chair", chair_1 = "Chair", chair_2 = "Chair", chair_3 = "Chair"}

func _ready() -> void:
	super._ready()
	reach = 3.0 if kind in ["seat", "hatch", "tap", "ladder", "repair", "deck_hatch"] else 3.5 if kind=="repair_out" else 6.0 if kind=="outside" else 4.0
	match kind:
		"table":
			title = "Bell's shipwright"
			description = "Battleships for 500 Dots. Buy one, then take it out to a Nexus berth."
		"board":
			title = "Campaign board"
			description = "Captain Isolde pins the tales of the Reach here."
			action_text = "Read"
		"rocket":
			title = "Rocket to the Surface"
			description = "Orin's shuttle lands at the Surface launch pad."
			action_text = "Fly to the Surface"
		"seat":
			title = SEAT_TITLES.get(seat, "Seat")
			description = "Bring a drink from the galley. Right-click to sip, C for a cigar, Z to stand." if seat.begins_with("chair") else "Take the seat. Z stands up again."
			action_text = "Sit"
		"repair", "repair_out":
			title = str(SpaceShip.PARTS.get(part, {}).get("name", "Part"))
			action_text = "Mend"
		"ladder":
			title = "Ladder to the deck"
			description = "Up through the deck hatch, jetpack on."
			action_text = "Climb up"
		"deck_hatch":
			title = "Deck hatch"
			description = "The ladder down into the ship."
			action_text = "Climb down"
		"wright":
			action_text = "Ships"
			response = "Need a ship, captain?"
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
	# On the Surface the ship stays fenced in: in and out only through the pad.
	if world is SurfaceShipWorld and kind in ["outside", "ladder", "deck_hatch", "repair_out"]: return false
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
	if kind=="table":
		action_text = "Buy / manage ships"
		response = "Battleships and your fleet."
		extra_text = ""

func _ships_for(actor: Node3D) -> Array:
	var pid := (actor as Player).player_id
	var party := 0
	var game := world.game_root()
	if game!=null and game.get("social") is SocialClient: party = int((game.get("social") as SocialClient).party.get("id", 0))
	return world.ships.values().filter(func(s: SpaceShip) -> bool:
		return s.owner==pid or (party!=0 and s.party==party))

func activate(actor: Node3D) -> bool:
	if not available(actor): return false
	match kind:
		"table":
			get_tree().call_group("fleet_panels", "open_for", self)
		"board":
			var game := world.game_root()
			if game!=null and game.get("campaign") is CampaignClient: (game.get("campaign") as CampaignClient).open_book()
		"rocket":
			if (actor as Player).spatial_controller is SpaceTraversal:
				((actor as Player).spatial_controller as SpaceTraversal).fly_rocket_surface()
		"seat":
			world.request(["sit", seat])
		"hatch":
			_through_black(["hatch"])
		"outside":
			_through_black(["board", ship_id])
		"mark":
			if Net.is_client(): Net.client.send_action("camp", ["quest", "obj:"+mark_id])
		"repair":
			world.request(["repair", part])
		"repair_out":
			world.request(["repair", ship_id, part])
		"ladder", "deck_hatch":
			_through_black(["deck"])
		"tap":
			world.request(["pour"])
		"wright":
			response = "Need a ship, captain?"
			get_tree().call_group("fleet_panels", "open_for", self)
	activated.emit(actor)
	return kind in ["table", "board", "wright"]

func _repair_ship(actor: Node3D) -> SpaceShip:
	if kind=="repair_out": return world.ships.get(ship_id)
	return world.ship_in_slot(SpaceLayout.pocket_at(actor.global_position))

func extra(_actor: Node3D) -> void:
	if kind=="table": world.request(["spawn"])

## Getting in or out of a ship: the screen fades to black, the move happens,
## and the game fades back up once we stand in the new place (main.gd).
func _through_black(args: Array) -> void:
	var game := world.game_root()
	var transition: Variant = game.get("transition") if game else null
	if transition is Transition:
		await (transition as Transition).fade_to_black(0.25)
		if game.has_method("expect_ship_move"): game.expect_ship_move()
	if is_instance_valid(world): world.request(args)
