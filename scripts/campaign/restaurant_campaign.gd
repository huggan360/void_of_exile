class_name RestaurantCampaign
extends RefCounted
## Mission 5's server-only behaviour, reusing the pre-existing Last Light
## Diner, its two real berths 6/7, its tap, and Mawgrave's existing boss.
var campaigns: CampaignServer

## This broad signal is deliberately NOT centred on the actual diner.
## Only its yellow spherical zone is rendered on the star chart, not a pin.
const SEARCH_CENTER := Vector3(14350, 350, 33250)
const SEARCH_RADIUS := 3500.0
const DISCOVER_RADIUS := 520.0
const TAP := Vector3(-4, 1.25, -7)
const KEY := "key_rotting_hive"

static func _member(p: Dictionary) -> String:
	return str(p.get("character_id", p.get("player_id", 0)))

static func _near_diner(p: Dictionary) -> bool:
	var pos: Vector3 = p.get("pos", Vector3.INF)
	return pos.is_finite() and pos.distance_to(SpaceLayout.DINER)<40.0

static func _docked(party: Dictionary, ships: Array, server: NetServer, world: SpaceWorld) -> bool:
	# Only the two real diner berths count. A spare ship left at the diner
	# cannot advance a quest while the whole party is still on Mawgrave.
	var berth := false
	for ship: SpaceShip in ships:
		if ship.mode=="berth" and ship.berth in [6, 7]:
			berth = true
			break
	if not berth: return false
	for pid: int in party.members:
		var p: Dictionary = server.social.record(pid)
		if not p.is_empty() and str(p.get("realm", ""))==world.realm_id and not p.get("dead", false) and world.zone_at(p.get("pos", Vector3.INF))=="diner":
			return true
	return false

func tick(party: Dictionary, run: Dictionary, step: Dictionary, world: SpaceWorld, ships: Array) -> bool:
	match str(step.kind):
		"reach_diner_search":
			# Actually discover the diner, not merely enter the enormous
			# uncertainty sphere shown on the star chart.
			for ship: SpaceShip in ships:
				if ship.xform.origin.distance_to(SpaceLayout.DINER)<DISCOVER_RADIUS:
					campaigns._advance(party, {})
					return true
			for pid: int in party.members:
				var p: Dictionary = campaigns.server.social.record(pid)
				if not p.is_empty() and str(p.get("realm", ""))==world.realm_id and _near_diner(p):
					campaigns._advance(party, {})
					return true
		"reach_diner_dock":
			if _docked(party, ships, campaigns.server, world):
				campaigns._advance(party, {})
				return true
		"reach_diner_beers":
			if _check_beers(party, run): return true
	return false

## Quest marks are on the server. During the search, never send the real
## diner's coordinates to the map or in-world badges; just a big sphere.
func markers(step: Dictionary) -> Array:
	match str(step.kind):
		"reach_diner_search":
			return [{id = "lastlight_signal", kind = "zone", name = "Possible Last Light Diner location",
				pos = SEARCH_CENTER, radius = SEARCH_RADIUS}]
		"reach_diner_dock":
			return [{id = "lastlight_ports", kind = "target", name = "Dock at Last Light - berths 1 or 2",
				pos = SpaceLayout.DINER, kind = "target"}]
		"reach_diner_beers":
			return [{id = "lastlight_beer", kind = "target", name = "Order and finish a full beer at the diner's tap",
				pos = SpaceLayout.DINER+TAP}]
	return []

## The real existing beer tap creates a fresh server-side cup with exactly
## four sips. Require all four successive valid sips of ONE order and a
## player standing in the diner; ship beer or glasses from elsewhere don't
## count. The 4th sip completes one full beer for this one party member.
func sip(p: Dictionary, source: String, mug_id: String, remaining: int) -> void:
	if not Net.is_server() or source!="lastlight:beer" or mug_id=="" or remaining<0 or remaining>3: return
	var pos: Vector3 = p.get("pos", Vector3.INF)
	if not pos.is_finite() or pos.distance_to(SpaceLayout.DINER+TAP)>23.0: return
	var party: Dictionary = campaigns.server.social.party_for(int(p.player_id))
	if party.is_empty() or str(p.get("realm", ""))!=campaigns.reach.space_realm(party): return
	var run: Dictionary = campaigns._run_of(party)
	if run.is_empty() or str(run.get("id", ""))!="hollowmoon" or str(run.get("status", ""))!="active": return
	if str(campaigns._step(run).get("kind", ""))!="reach_diner_beers": return
	var key := _member(p)
	var finished: Dictionary = run.get("lastlight_beers", {})
	if bool(finished.get(key, false)): return
	var mugs: Dictionary = run.get("lastlight_mugs", {})
	var entry: Dictionary = mugs.get(key, {})
	# Each new beer order resets the partial cup; four complete sips
	# (3,2,1,0 remaining) are required, never just the last sip.
	if str(entry.get("id", ""))!=mug_id:
		if remaining!=3: return
		entry = {id = mug_id, sips = 0}
	var next_sip := int(entry.sips)+1
	if remaining!=4-next_sip: return
	entry.sips = next_sip
	if next_sip==4:
		finished[key] = true
		run.lastlight_beers = finished
		mugs.erase(key)
		campaigns.server.social.system(int(p.player_id), "Finished one full Last Light beer. Cheers!")
	else:
		mugs[key] = entry
	run.lastlight_mugs = mugs
	campaigns._touch(party.campaign.account)
	_check_beers(party, run)

func _check_beers(party: Dictionary, run: Dictionary) -> bool:
	var beers: Dictionary = run.get("lastlight_beers", {})
	var ready := 0
	for pid: int in party.members:
		var p: Dictionary = campaigns.server.social.record(pid)
		if not p.is_empty() and bool(beers.get(_member(p), false)): ready += 1
	if int(run.get("count", 0))!=ready:
		run.count = ready
		campaigns.server.social.broadcast(party)
	if ready>0 and ready==party.members.size():
		for pid: int in party.members:
			campaigns.server.social.system(pid, "Everyone finished a full beer. Ask Dot, the Last Light host, about her troubles.")
		campaigns._advance(party, {})
		return true
	return false

## The key is consumed by the real fortress lock. After a wiped/abandoned
## fight, Dot will replace it if the gate has resealed and nobody has one.
func action(party: Dictionary, run: Dictionary, p: Dictionary, objective: String, world: SpaceWorld, step: Dictionary) -> bool:
	if run.id!="hollowmoon" or run.status!="active": return false
	if objective!="npc:lastlight_host" or step.kind!="reach_boss" or str(step.get("planet", ""))!="mawgrave":
		return false
	var pos: Vector3 = p.get("pos", Vector3.INF)
	var at := world.npc_position("lastlight_host")
	if not at.is_finite() or pos.distance_to(at)>6.0: return true
	var gate: Dictionary = world.gates.entries.get(PlanetStrongholds.center_of("mawgrave"), {}) if is_instance_valid(world.gates) else {}
	if not gate.is_empty() and not bool(gate.get("sealed", true)):
		campaigns.server.social.system(int(p.player_id), "Dot: The Rotting Hive gate is open. Go on, finish the job!")
		return true
	for pid: int in party.members:
		var stats := GameServer.character(pid)
		if stats and not stats.find_item(KEY).is_empty():
			campaigns.server.social.system(int(p.player_id), "Dot: One of you still has the Rotting Hive key.")
			return true
	var stats := GameServer.character(int(p.player_id))
	if stats and stats.give([Items.make(KEY)])>0:
		campaigns.server.social.system(int(p.player_id), "Dot gives you a replacement Rotting Hive key. Take care out there.")
	else:
		campaigns.server.social.system(int(p.player_id), "Dot: Make some room in your backpack first, dear.")
	return true
