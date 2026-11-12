class_name DungeonServer
extends Node
## Portal lifetimes and travel grants live only on the authoritative server.
var server: NetServer
var portals := {}
var grants := {}
var _serial := 0

func _process(_delta: float) -> void:
	for id: String in portals.keys():
		var portal: Dictionary = portals[id]
		if not server.realms.has(portal.realm) or (portal.expires > 0.0 and Net.now() >= portal.expires):
			despawn(id)

func despawn(id: String) -> void:
	var portal: Dictionary = portals.get(id, {})
	if portal.is_empty(): return
	portals.erase(id)
	server._to_realm(portal.realm, Vector3.INF, ["dng-", id])

## story: a campaign's portal, open until its dungeon's boss falls.
func spawn(realm_id: String, pos: Vector3, dungeon: String, exit := false, story := false) -> Dictionary:
	if not server.realms.has(realm_id) or Dungeons.definition(dungeon).is_empty(): return {}
	if story:
		pos = Campaigns.open_spot(pos, server.realms[realm_id].world)
		if pos == Vector3.INF: return {}
	_serial += 1
	var portal := {id = "portal_%d" % _serial, realm = realm_id, pos = pos, dungeon = dungeon,
		exit = exit, expires = -1.0 if exit or story else Net.now() + 30.0, instance = "", story = story}
	portals[portal.id] = portal
	server._to_realm(realm_id, Vector3.INF, ["dng+", wire(portal)])
	return portal

func wire(portal: Dictionary) -> Dictionary:
	return {id = portal.id, pos = portal.pos, dungeon = portal.dungeon, exit = portal.exit,
		remaining = -1.0 if portal.expires < 0.0 else maxf(0.0, portal.expires - Net.now())}

func entered(p: Dictionary) -> void:
	p.erase("dungeon_arrival")
	if str(grants.get(p.player_id, "")) == p.realm: grants.erase(p.player_id)
	var realm: RealmInstance = server.realms.get(p.realm)
	if realm and realm.record.has("dungeon"):
		server._to_peer(p.peer_id, ["dng+", {id = "spawn_exit", pos = realm.world.spawn_point + Vector3(0, 0, 4), dungeon = realm.record.dungeon, exit = true, remaining = -1.0}])
	for portal: Dictionary in portals.values():
		if portal.realm == p.realm: server._to_peer(p.peer_id, ["dng+", wire(portal)])

func enemy_killed(realm_id: String, definition: EnemyDef, pos: Vector3) -> void:
	var realm: RealmInstance = server.realms.get(realm_id)
	if realm == null: return
	if realm.record.has("dungeon"):
		if definition.id == Dungeons.definition(realm.record.dungeon).boss:
			# A campaign's story portals stay until its whole chain is done.
			for id: String in portals.keys():
				if portals[id].instance == realm_id and not portals[id].get("story", false): despawn(id)
			spawn(realm_id, pos, realm.record.dungeon, true)
			# Some bosses can open a follow-up (an encore): by chance, or always in a campaign.
			var follow := str(Dungeons.definition(realm.record.dungeon).get("follow_up", ""))
			var rule: Variant = definition.get("follow_up")
			var chance := float(rule.get("chance", 0.5)) if rule is Dictionary else 0.5
			var campaigns: CampaignServer = server.campaigns if is_instance_valid(server.campaigns) else null
			if follow != "" and not (campaigns and campaigns.story_dungeon(realm_id)) and randf() < chance:
				spawn(realm_id, pos + Vector3(4, 0, 0), follow)
			if campaigns: campaigns.dungeon_cleared(realm_id, pos)
	elif not definition.portal_drop.is_empty() and randf() < float(definition.portal_drop.chance):
		spawn(realm_id, pos, str(definition.portal_drop.dungeon))

func interact(p: Dictionary, id: String) -> void:
	if p.dead or p.switching or not p.joined: return
	var realm: RealmInstance = server.realms.get(p.realm)
	if realm == null: return
	var portal: Dictionary = portals.get(id, {})
	if id == "spawn_exit" and realm.record.has("dungeon"):
		portal = {realm = p.realm, pos = realm.world.spawn_point + Vector3(0, 0, 4), expires = -1.0, exit = true}
	if portal.is_empty() or portal.realm != p.realm: return
	if portal.expires > 0.0 and Net.now() >= portal.expires: return
	if (p.pos as Vector3).distance_to(portal.pos) > 4.5: return
	if portal.exit:
		var point: Dictionary = p.get("dungeon_returns", {}).get(p.realm, {
			realm = realm.record.get("origin", "hall"), pos = realm.record.get("origin_pos", Vector3.INF)})
		var origin := str(point.realm)
		var back: Vector3 = point.pos
		if not Campaigns.is_tavern(origin) and not server.realms.has(origin):
			origin = "hall"
			back = Vector3.INF
		grants[p.player_id] = origin
		p.dungeon_arrival = {realm = origin, pos = back}
		if p.has("dungeon_returns"): p.dungeon_returns.erase(p.realm)
		server.social.send_to(p.player_id, origin, back)
		return
	if portal.instance == "" or not server.realms.has(portal.instance):
		if portal.get("preparing", false): return
		portal.preparing = true
		_serial += 1
		var instance := "dng_%s_%d" % [portal.dungeon, _serial]
		var record := Dungeons.record(instance, portal.dungeon, randi(), p.realm)
		record.origin_pos = portal.pos
		# Worked out on a worker thread: nobody else on the server waits for it.
		if portal.dungeon != "theory_of_everything":
			var definition := Dungeons.definition(portal.dungeon)
			var made: Array = [null]
			var task := WorkerThreadPool.add_task(func() -> void: made[0] = DungeonLayout.new(definition, int(record.seed)))
			while not WorkerThreadPool.is_task_completed(task): await get_tree().process_frame
			WorkerThreadPool.wait_for_task_completion(task)
			DungeonWorld.prepared[instance] = made[0]
		portal.preparing = false
		portal.instance = instance
		server.open_realm_record(record.id, record)
		# Meanwhile they may have gone: the dungeon stays open for the others.
		if p.dead or p.switching or not p.joined or p.realm != portal.realm: return
	var members: Array = [p.player_id]
	var party := server.social.party_for(p.player_id)
	if not party.is_empty():
		members = party.members.duplicate()
	var line := "%s led the party into %s" % [p.name, Dungeons.definition(portal.dungeon).name]
	for player_id: int in members:
		var other := server.social.record(player_id)
		if other.is_empty() or not other.joined or other.realm != p.realm or other.dead or other.switching: continue
		if not other.has("dungeon_returns"): other.dungeon_returns = {}
		other.dungeon_returns[portal.instance] = {realm = other.realm, pos = other.pos}
		grants[player_id] = portal.instance
		if not party.is_empty(): server.social.system(player_id, line)
		server.social.send_to(player_id, portal.instance)

func may_enter(p: Dictionary, destination: String) -> bool:
	if str(grants.get(p.player_id, "")) != destination: return false
	grants.erase(p.player_id)
	return destination == "hall" or server.realms.has(destination)


## A live dungeon keeps its origin (including parent dungeons) available.
func keeps_origin_open(realm_id: String) -> bool:
	for instance: RealmInstance in server.realms.values():
		if instance.record.has("dungeon") and instance.record.get("origin", "") == realm_id:
			return true
	return false


## Only reached from NetServer's --test action; normal damage/phase handling stays intact.
func debug_defeat(p: Dictionary) -> void:
	var realm: RealmInstance = server.realms.get(p.realm)
	if realm == null or not realm.world is DungeonWorld: return
	var actor: Boss
	for enemy: Enemy in realm.enemies.values():
		if enemy.def.id == realm.world.definition.boss: actor = enemy as Boss
	if actor == null: return
	var elapsed := 0.0
	while is_instance_valid(actor) and actor.is_alive() and elapsed < 25.0:
		if actor.state == Enemy.State.ACTIVE:
			actor.take_hit(actor.global_position + Vector3.UP, Vector3.ZERO, 100000, realm.proxies.get(p.player_id))
		await get_tree().create_timer(0.4).timeout
		elapsed += 0.4
