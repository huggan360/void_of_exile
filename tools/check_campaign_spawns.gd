extends Node3D
## Real static realm, all main/side anchors. Exit 1 on missing/unsafe positions.
var failures := 0
var checked := 0
var marker_checks := 0
var client: CampaignClient
var world: IslandWorld

func _ready() -> void:
	_run.call_deferred()

func check(at: Variant, label: String) -> void:
	if at is String: return # death/dungeon origins checked at runtime
	var p := Campaigns.resolve(at, world)
	checked += 1
	if p == Vector3.INF or not Campaigns.spawn_clear(p, world) or absf(p.y - world.ground_height(p.x, p.z)) > 0.01:
		failures += 1
		push_error("SPAWN FAILED %s: %s" % [label, p])
	else:
		print("SPAWN OK ", label, " ", p)

func verify(ok: bool, label: String) -> void:
	checked += 1
	if not ok:
		failures += 1
		push_error("CAMPAIGN FAILED: " + label)

func _run() -> void:
	world = IslandWorld.new({id = "camp_qa_hidden_power", seed = 20261031, destroyed = []})
	world.server_build = true
	add_child(world)
	client = CampaignClient.new()
	client._world = world
	for id: String in Campaigns.PACKS.hidden_power.campaigns:
		var before := checked
		var bad := failures
		for npc: String in Campaigns.NPCS:
			var info: Dictionary = Campaigns.NPCS[npc]
			if info.get("campaign", "") == id:
				check(info.at, id + "/npc/" + npc)
				var actual := Campaigns.npc_position(npc, world.realm_id, world)
				if actual != Campaigns.resolve(info.at, world): failures += 1
				client._spawn_npc(npc, {})
				if client._spawned.is_empty():
					failures += 1
				else:
					var actor := client._spawned.back() as TownNPC
					actor._physics_process(0.016)
					var marker := QuestMarker.new()
					actor.add_child(marker)
					check_marker(actor, marker, id + "/" + npc)
		var definition := Campaigns.get_def(id)
		for step: Dictionary in definition.steps + definition.get("side", []):
			if step.get("world", "") != "campaign": continue
			if step.has("at"): check(step.at, id + "/" + step.id)
			if step.has("pack") and step.has("at") and not step.at is String:
				var center := Campaigns.encounter_position(step.at, world)
				check(center, id + "/encounter/" + step.id)
				var pack: Dictionary = step.get("formation", Enemies.pack(step.pack))
				var members: Array = pack.members.duplicate(true)
				if pack.has("leader"): members.push_front(pack.leader.merged({min = 1, max = 1}))
				var guaranteed := 0
				var reserved := []
				for member: Dictionary in members:
					if not member.has("chance") and (step.get("any", false) or member.enemy in step.enemies): guaranteed += int(member.min)
					for n in int(member.max):
						var def := Enemies.get_def(member.enemy)
						var spot := world.enemy_director.find_spawn_position(center, def, reserved, center, true)
						checked += 1
						if spot.is_empty():
							failures += 1
							push_error("No quest enemy placement: " + id + "/" + member.enemy)
						else:
							reserved.append({pos = spot.pos, radius = def.hit_radius * def.model_scale})
				checked += 1
				if guaranteed < int(step.count):
					failures += 1
					push_error("Quest pack cannot guarantee required kills: " + id + "/" + step.id)
			for object: Dictionary in step.get("objects", []):
				check(object.at, id + "/" + str(object.id))
				client._spawn_object(object, step, false)
				var root := client._spawned.back() as Node3D
				for child in root.get_children():
					if child is QuestMarker: check_marker(root, child, id + "/" + str(object.id))
			if step.has("guards") and step.at is Dictionary:
				var center := Campaigns.resolve(step.at, world)
				for k in int(step.guards.count):
					var angle := TAU * k / float(step.guards.count)
					check(center + Vector3(cos(angle), 0, sin(angle)) * (12.0 + k * 5.0), id + "/guard/" + str(k))
		if id == "frozen_whisper":
			var cabin := Campaigns.open_spot(Campaigns.resolve({cabin = "Snowbell"}, world) + Vector3(-3, 0, -3), world, 3.3, 4.0)
			checked += 1
			if not Campaigns.spawn_clear(cabin, world, 3.3, 4.0): failures += 1
		if id == "hollow_castle": check({village = "Hearthwick", offset = Vector3(-6, 0, 14)}, id + "/white_portal")
		print("CAMPAIGN SPAWNS ", id, ": ", checked - before, " checked, ", failures - bad, " failed")
	var authority := NetServer.new()
	authority.campaigns.server = authority
	var instance := RealmInstance.new({id = world.realm_id})
	instance.world = world
	authority.realms[world.realm_id] = instance
	var party := {campaign = {realm = world.realm_id}}
	var run := authority.campaigns._fresh_run("lily_thief")
	var roster := authority.campaigns._sync_npcs(party, run)
	verify(roster.has("wren") and not roster.has("maribel"), "Server hides unrevealed story actors")
	var actor: Node3D = authority.campaigns._actors[world.realm_id].wren
	verify(roster.wren.pos == actor.global_position, "Roster mirrors authoritative actor position")
	authority.campaigns._sync_npcs(party, run)
	verify(authority.campaigns._actors[world.realm_id].wren == actor, "Repeated summaries retain the same actor")
	run.step = Campaigns.step_index(run.id, "maribel")
	roster = authority.campaigns._sync_npcs(party, run)
	verify(roster.has("maribel"), "Server reveals actors at their story step")
	var account_id := 46
	var player_id := 604
	var private_tavern := Campaigns.tavern_id(account_id, "lily_thief")
	var private_party := {campaign = {account = account_id, id = "lily_thief", realm = world.realm_id,
		tavern = private_tavern, castle = "cst_46_hidden_power"}}
	authority.social.parties[1] = private_party
	authority.social.party_of[player_id] = 1
	var active_run := authority.campaigns._fresh_run("lily_thief")
	active_run.step = Campaigns.step_index("lily_thief", "gate") # realm objective, not a Tavern step
	authority.campaigns.book(account_id).runs.lily_thief = active_run
	verify(authority.campaigns.home_for({player_id = player_id}) == private_tavern,
		"Active campaign hall returns resolve to the private Tavern during a realm step")
	instance._bag_spots.free()
	instance.free()
	for component in [authority.api, authority.social, authority.dungeons, authority.campaigns, authority.economy]: component.free()
	authority.free()
	var route := {id = "lily_thief", owner = 0, realm = world.realm_id, castle = "castle", links = [
		{from = world.realm_id, to = "dng_route", pos = Vector3(50, 11, 50)},
		{from = "dng_route", to = world.realm_id, pos = Vector3(0, 1, 4)}]}
	verify(client._route_points("dng_route", route) == [Vector3(50, 11, 50)], "Realm route marks the dungeon entrance")
	verify(not client._route_points("hall", route).is_empty(), "Realm route marks the Tavern exit")
	var hall: HallWorld = load("res://scenes/home/tavern.tscn").instantiate()
	add_child(hall)
	for destination: String in ["realm_1", "campaign", "chambers"]:
		verify(hall.get_children().any(func(node: Node) -> bool: return node is Portal and node.destination == destination),
			"Public Tavern includes %s gate" % destination)
	hall.campaign_portal.set_active(true)
	client._world = hall
	verify(client._route_points("dng_route", route) == [hall.campaign_portal.global_position], "Tavern routes to dungeon through the Chronicle Gate")
	check_world_point(hall, Campaigns.npc_position("gerald", "hall", hall), "lily_thief/Gerald")
	var private_hall: HallWorld = load("res://scenes/home/tavern.tscn").instantiate()
	private_hall.campaign_tavern = true
	private_hall.realm_id = private_tavern
	add_child(private_hall)
	for destination: String in ["realm_1", "campaign", "chambers"]:
		verify(private_hall.get_children().any(func(node: Node) -> bool: return node is Portal and node.destination == destination),
			"Private Tavern includes %s gate" % destination)
	var chambers := ChambersWorld.new({id = ChambersWorld.id_for(account_id), chambers = true, chests = 0})
	add_child(chambers)
	client._world = chambers
	var chamber_return := chambers.get_node("ReturnToTavern") as Portal
	verify(client._route_points(private_tavern, {realm = world.realm_id, castle = "cst_46_hidden_power"}) == [chamber_return.global_position],
		"Chambers route points to its return gate on the private Tavern route")
	client._world = private_hall
	private_hall.campaign_portal.set_active(true)
	verify(client._route_points(world.realm_id, route) == [private_hall.campaign_portal.global_position],
		"Private Tavern Chronicle Gate leads to the campaign realm")
	var castle: CastleWorld = load("res://scenes/castle/hollow_castle.tscn").instantiate()
	castle.server_build = true
	add_child(castle)
	client._world = castle
	client._spawn_castle_exit(route)
	verify(not client._route_points(world.realm_id, route).is_empty(), "Castle route marks its return portal")
	for step: Dictionary in Campaigns.get_def("hollow_castle").steps:
		if step.world == "castle" and step.kind == "kill":
			client._objective_points(step, {}, false) # staged actors have no `at`
	for spec in [["castle_knight", -7.0], ["castle_champion", -9.0]]:
		castle.encounter._spawn_pair(spec[0], spec[1])
		for enemy: Enemy in castle.encounter._living:
			check_world_point(castle, enemy.global_position, "hollow_castle/" + str(spec[0]))
	check_world_point(castle, CastleWorld.THRONE_SEAT, "hollow_castle/throne", true)
	print("CAMPAIGN SPAWNS TOTAL ", checked, " checked, ", marker_checks, " model/marker bounds checked, ", failures, " failed")
	client.cinematic.free()
	client.free()
	castle.free()
	chambers.free()
	private_hall.free()
	hall.free()
	world.free()
	get_tree().quit(1 if failures else 0)


func check_marker(root: Node3D, marker: QuestMarker, label: String) -> void:
	marker_checks += 1
	var top := QuestMarker.model_top(root)
	if top <= 0.0 or marker.height < top + 0.6:
		failures += 1
		push_error("Marker intersects model " + label)
	if root is TownNPC and absf(root.position.y - world.ground_height(root.position.x, root.position.z)) > 0.01:
		failures += 1
		push_error("NPC below terrain " + label)


func check_world_point(place: GameWorld, p: Vector3, label: String, seated := false) -> void:
	checked += 1
	if not p.is_finite() or p.y < place.ground_height(p.x, p.z) - 0.05 or (not seated and not place.is_walkable(p)):
		failures += 1
		push_error("SPAWN FAILED " + label + ": " + str(p))
	else: print("SPAWN OK ", label, " ", p)
