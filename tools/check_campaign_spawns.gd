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
			if step.has("pack") and step.has("at") and step.at is Dictionary:
				var center := Campaigns.resolve(step.at, world)
				var pack := Enemies.pack(step.pack)
				var members: Array = pack.members.duplicate()
				if pack.has("leader"): members.append(pack.leader)
				var reserved := []
				for member: Dictionary in members:
					var def := Enemies.get_def(member.enemy)
					var spot := world.enemy_director.find_spawn_position(center, def, reserved, center, true)
					checked += 1
					if spot.is_empty():
						failures += 1
						push_error("No quest enemy placement: " + id + "/" + member.enemy)
					else:
						reserved.append({pos = spot.pos, radius = def.hit_radius * def.model_scale})
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
	var hall: HallWorld = load("res://scenes/home/tavern.tscn").instantiate()
	add_child(hall)
	check_world_point(hall, Campaigns.npc_position("gerald", "hall", hall), "lily_thief/Gerald")
	var castle: CastleWorld = load("res://scenes/castle/hollow_castle.tscn").instantiate()
	castle.server_build = true
	add_child(castle)
	client._world = castle
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
