extends Node
## Determinism/connectivity, optional rooms, threshold rewards and the dungeon loot contract.
class CaptureSocial extends SocialServer:
	var sent: Array = []
	func send(player_id: int, event: Array) -> void:
		sent.append([player_id, event])

class OriginRealm extends RealmInstance:
	func _ready() -> void:
		pass
	func _physics_process(_delta: float) -> void:
		pass

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	var definition := Dungeons.definition("goblins_cave")
	var treasures := 0
	var minibosses := 0
	for seed_value in 128:
		var a := DungeonLayout.new(definition, seed_value)
		var b := DungeonLayout.new(definition, seed_value)
		assert(a.floor_cells == b.floor_cells and a.boss == b.boss)
		var n := a.rooms.size()
		assert(n >= 10 and a.edges.size() >= n - 1)
		var reached := {0: true}
		var distances := {0: 0}
		var queue: Array[int] = [0]
		while not queue.is_empty():
			var index: int = queue.pop_front()
			for edge in a.edges:
				var next := edge.y if edge.x == index else edge.x if edge.y == index else -1
				if next >= 0 and not reached.has(next):
					reached[next] = true
					distances[next] = distances[index] + 1
					queue.append(next)
		assert(reached.size() == n)
		for i in n:
			# Every room's clear core is open floor (props and packs stand there).
			var c: Vector2i = a.rooms[i].center
			var r := int(a.rooms[i].radius) - 1
			for z in range(-r, r + 1):
				for x in range(-r, r + 1):
					if Vector2(x, z).length() <= r: assert(a.open(c.x + x, c.y + z))
			if a.rooms[i].kind == "boss": assert(distances[i] >= 2)
		var floor_reached := {Vector2i(floori(a.spawn.x), floori(a.spawn.z)): true}
		var cells: Array[Vector2i] = [Vector2i(floori(a.spawn.x), floori(a.spawn.z))]
		var cursor := 0
		while cursor < cells.size():
			var cell := cells[cursor]
			cursor += 1
			for delta: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				var next := cell + delta
				if a.floor_cells.has(next) and not floor_reached.has(next):
					floor_reached[next] = true
					cells.append(next)
		assert(floor_reached.size() == a.floor_cells.size())
		treasures += int(a.treasure >= 0)
		minibosses += int(a.miniboss >= 0)
	var boss := Enemies.get_def("goblin_king")
	var rng := RandomNumberGenerator.new()
	rng.seed = 71
	var rewarded := 0
	var secondary := 0
	var white := 0
	var black := 0
	for i in 2000:
		var has_reward := false
		var has_secondary := false
		for bag in Loot.roll(boss, {1: boss.hp, 2: boss.hp * 0.1, 3: 1}, rng):
			assert(bag.viewer != 3)
			for item: Item in bag.items:
				if item.is_divine():
					assert(item.id in Items.divine_ids_for(boss.id))
					white += int(item.bag_type() == "white")
					black += int(item.bag_type() == "black")
				if item.bag_type() == "blue":
					if bag.viewer == 1: has_reward = true
					if bag.viewer == 2: has_secondary = true
		rewarded += int(has_reward)
		secondary += int(has_secondary)
	assert(rewarded > 1850 and rewarded < 1950)
	assert(secondary > 1850 and secondary < 1950)
	assert(white > 0 and black > 0)
	assert(treasures > 12 and treasures < 48 and minibosses > 20 and minibosses < 65)
	print("[check] PASS 128 connected deterministic layouts; treasure=", treasures, " miniboss=", minibosses,
		"; 2000 loot rolls: blue eligible=", rewarded, " secondary=", secondary, " white=", white, " black=", black)
	var world := GameWorld.new()
	add_child(world)
	var portal := DungeonPortal.place(world, {id = "fade_check", dungeon = "goblins_cave", remaining = 4.0})
	portal._process(0.1)
	assert(portal.target.enabled and portal.remaining < 4.0 and portal._surface.get_shader_parameter("opening") < 1.0)
	portal._process(3.8)
	portal._process(0.11)
	assert(portal._closing and not portal.target.enabled and not portal.is_queued_for_deletion())
	portal._process(DungeonPortal.CLOSE_TIME)
	assert(portal.is_queued_for_deletion() and not portal.visible)
	print("[check] PASS hole opening, expiry disables interaction, animated seal")
	await _travel_checks()
	await get_tree().process_frame
	get_tree().quit()


func _travel_checks() -> void:
	var server := NetServer.new()
	server.set_process(false)
	server.set_physics_process(false)
	server.api.free()
	server.campaigns.free()
	server.social.free()
	server.social = CaptureSocial.new()
	server.social.server = server
	server.dungeons.server = server
	server.add_child(server.social)
	server.social.set_process(false)
	server.add_child(server.dungeons)
	server.dungeons.set_process(false)
	add_child(server)
	var origin := OriginRealm.new({id = "realm_1", seed = 1, destroyed = []})
	origin.bullets.free()
	server.add_child(origin)
	server.realms["realm_1"] = origin
	for id in [1, 2, 3]:
		server.by_player[id] = id + 10
		server.peers[id + 10] = {player_id = id, peer_id = id + 10, realm = "hall" if id == 3 else "realm_1",
			name = "Probe%d" % id, pos = Vector3.ZERO, joined = true, dead = false, switching = false}
	server.social.parties[1] = {id = 1, members = [1, 2, 3]}
	for id in [1, 2, 3]: server.social.party_of[id] = 1
	var player: Dictionary = server.peers[11]
	var portal := server.dungeons.spawn("realm_1", Vector3.ZERO, "goblins_cave")
	assert(portal.expires - Net.now() > 29.0 and portal.expires - Net.now() <= 30.0)
	player.pos = Vector3(100, 1, 100)
	server.dungeons.interact(player, portal.id)
	assert(server.dungeons.grants.is_empty())
	player.pos = Vector3(1.25, 1, 2)
	portal.expires = Net.now() - 1.0
	server.dungeons.interact(player, portal.id)
	assert(server.dungeons.grants.is_empty())
	portal.expires = Net.now() + 30.0
	server.peers[12].pos = Vector3(-1, 1, 1)
	server.dungeons.interact(player, portal.id)
	var first: String = portal.instance
	assert(server.dungeons.grants.get(1) == first and server.dungeons.grants.get(2) == first)
	assert(not server.dungeons.grants.has(3))
	assert(server.realms[first].record.origin == "realm_1")
	assert(player.dungeon_returns[first].pos == Vector3(1.25, 1, 2))
	assert(server.peers[12].dungeon_returns[first].pos == Vector3(-1, 1, 1))
	server.dungeons.interact(server.peers[12], portal.id)
	assert(portal.instance == first and server.realms.size() == 2)
	var other := server.dungeons.spawn("realm_1", Vector3.ZERO, "goblins_cave")
	server.dungeons.interact(player, other.id)
	assert(other.instance != first and server.realms.size() == 3)
	assert(not server.dungeons.may_enter(server.peers[13], first))
	player.realm = first
	player.pos = server.realms[first].world.spawn_point + Vector3(0, 0, 4)
	server.dungeons.interact(player, "spawn_exit")
	assert(server.dungeons.grants[1] == "realm_1")
	assert(server.social.sent.back()[1] == ["goto", "realm_1", Vector3(1.25, 1, 2)])
	server.config = ServerConfig.new()
	origin.empty_for = 10000
	server._unload_empty_realms(0)
	assert(server.realms.has("realm_1"), "Origin remains available beyond its empty-realm timeout")
	# Completion removes only the entrance linked to this instance, even early.
	server.dungeons.grants.clear()
	server._pending.clear()
	server.dungeons.enemy_killed(first, Enemies.get_def("goblin_king"), server.realms[first].world.layout.boss)
	assert(not server.dungeons.portals.has(portal.id))
	assert(server.dungeons.portals.has(other.id))
	var removals: Array = server._pending["realm_1"].filter(func(entry: Dictionary) -> bool: return entry.ev[1] == "dng-")
	assert(removals.size() == 1)
	var removal: Dictionary = removals[0]
	assert(removal.ev[2] == portal.id and removal.pos == Vector3.INF and removal.only == 0 and removal.skip == 0)
	# Two independent client worlds consume the actual broadcast event.
	for i in 2:
		var client := NetClient.new()
		client.world = GameWorld.new()
		add_child(client.world)
		client._apply([Net.now(), "dng+", server.dungeons.wire(portal)])
		var mirror: DungeonPortal = client.world.get_child(0)
		client._apply(removal.ev)
		assert(mirror._closing and not mirror.target.enabled and not mirror.is_queued_for_deletion())
		mirror._process(DungeonPortal.CLOSE_TIME)
		assert(mirror.is_queued_for_deletion() and not mirror.visible)
		client.world.queue_free()
		client.free()
	player.realm = "realm_1"
	player.pos = Vector3.ZERO
	server.dungeons.interact(player, portal.id)
	assert(server.dungeons.grants.is_empty())
	server._pending.clear()
	server.dungeons.entered(player)
	assert(not server._pending["realm_1"].any(func(entry: Dictionary) -> bool: return entry.ev[1] == "dng+" and entry.ev[2].id == portal.id))
	player.realm = first
	player.pos = server.realms[first].world.spawn_point + Vector3(0, 0, 4)
	# Expiry is tested while the origin realm still exists.
	assert(server.realms.has(other.realm))
	other.expires = Net.now() - 1.0
	server._pending.clear()
	server.dungeons._process(0.1)
	assert(not server.dungeons.portals.has(other.id))
	assert(server._pending["realm_1"].any(func(entry: Dictionary) -> bool: return entry.ev[1] == "dng-" and entry.ev[2] == other.id and entry.pos == Vector3.INF and entry.only == 0))
	assert(server.dungeons.portals.values().any(func(entry: Dictionary) -> bool: return entry.realm == first and entry.exit and entry.expires < 0.0))
	var boss_exit: Dictionary = server.dungeons.portals.values().filter(func(entry: Dictionary) -> bool: return entry.realm == first and entry.exit)[0]
	var second: Dictionary = server.peers[12]
	second.realm = first
	second.pos = boss_exit.pos
	server.dungeons.interact(second, boss_exit.id)
	assert(server.social.sent.back()[1] == ["goto", "realm_1", Vector3(-1, 1, 1)], "Boss exit restores each party member's exact entry point")
	var nested := server.dungeons.spawn(first, player.pos, "goblins_cave")
	var nested_entry: Vector3 = player.pos
	server.dungeons.interact(player, nested.id)
	var nested_id := str(nested.instance)
	assert(server.realms[nested_id].record.origin == first)
	server.realms[first].empty_for = 10000
	server._unload_empty_realms(0)
	assert(server.realms.has(first) and server.realms.has("realm_1"), "Nested dungeons preserve the entire return chain")
	player.realm = nested_id
	player.pos = server.realms[nested_id].world.spawn_point + Vector3(0,0,4)
	server.dungeons.interact(player, "spawn_exit")
	assert(server.social.sent.back()[1] == ["goto", first, nested_entry])
	player.realm = first
	player.pos = server.realms[first].world.spawn_point + Vector3(0,0,4)
	server.dungeons.grants.clear()
	server.dungeons.interact(server.peers[12], other.id)
	assert(server.dungeons.grants.is_empty())
	server.realms.erase("realm_1")
	server.dungeons.interact(player, "spawn_exit")
	assert(server.dungeons.grants[1] == "hall")
	assert(server.dungeons.portals.values().any(func(entry: Dictionary) -> bool: return entry.realm == first and entry.exit))
	print("[check] PASS portal distance/expiry, same-portal grouping, distinct instances, party realm filter, completion broadcast/two client removals/late arrival/rejected entry, boss exit, realm/Tavern returns")
	server.queue_free()
	await get_tree().process_frame
