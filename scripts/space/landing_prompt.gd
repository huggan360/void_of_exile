class_name LandingPrompt
extends InteractionTarget
## The pilot's landing offer in the conversation card (as an NPC's would
## be): a pad below to land on, the way down to the Surface, or a Nexus port
## to dock at. The ship's land key (X) answers it, as in the seat's key help.
var traversal: SpaceTraversal

func _ready() -> void:
	super._ready()
	follows_player = true
	key_action = "ship_land"

func available(player: Node3D) -> bool:
	if not enabled or not is_inside_tree() or not is_instance_valid(traversal) or traversal.seat!="pilot": return false
	var ship := traversal._ship
	if ship==null or ship.mode!="flying" or not ship.queue.is_empty(): return false
	global_position = player.global_position  # nearest of all while at the helm
	var land := ship.landable()
	if not land.is_empty():
		title = "Land here"
		description = "%s. Set her down there?" % str(land.port.name)
		action_text = "Land"
	elif SpaceLayout.can_descend(ship.xform.origin):
		title = "The Surface"
		description = "The way down through the clouds. Take her down?"
		action_text = "Descend"
	elif ship.xform.origin.distance_to(SpaceLayout.NEXUS)<SpaceWorld.DOCK_RANGE:
		title = "The Nexus"
		description = "A free port at the station. Bring her in?"
		action_text = "Dock"
	else:
		return false
	return true

func activate(player: Node3D) -> bool:
	if not available(player): return false
	traversal.land()
	activated.emit(player)
	return false  # nothing to read: the card closes
