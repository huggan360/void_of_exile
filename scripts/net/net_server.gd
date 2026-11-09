class_name NetServer
extends Node
## The dedicated server's network side (Net.server). It
##
##   * accepts players: a client says hello with its login token and the
##     character it wants; the account service checks both and hands over
##     the character, which is "leased" to this server until it leaves
##   * keeps realm instances (RealmInstance): the Tavern is shared by
##     everyone and needs no simulation; realms open as players arrive, up
##     to max_players_per_realm each, and close a while after emptying
##   * runs a tick (tick_rate per second) that sends every player a
##     snapshot of the enemies and players around them, and the events that
##     happened near them, stamped with server time
##   * takes what players report (moves, hits taken, hits landed, inventory
##     requests...) and checks it before applying it to GameServer
##   * saves characters to the account service every save_interval seconds,
##     when they leave, and moves them to the dead table when they die
##   * answers status pings (the server list), announces itself on the LAN
##     and to the account service (so players on your network find it)

const MAX_HIT_RANGE := 45.0  # meters from the player to an enemy they report hitting
const HIT_SLACK := 1.25  # reported damage may be this much over the best possible roll
const SNAP_BACK_GRACE := 0.25  # seconds after a correction or a jump before moves are checked
const XP_PER_OBSTACLE := 3  # same as Main
const SNAPSHOT_ENEMIES := 18  # enemies per snapshot packet (keeps each under the MTU)

var config: ServerConfig
var api := AccountApi.new()
## Chat, parties, teleports, shared fog.
var social := SocialServer.new()
var dungeons := DungeonServer.new()
## Campaigns and their quests.
var campaigns := CampaignServer.new()
var economy := EconomyServer.new()
## The Skyward Launch Pad and the way between the Surface and Space.
var surface_port := PortServer.new()
var fleet := FleetServer.new()
var peer := ENetMultiplayerPeer.new()
## peer id -> player record (see on_hello)
var peers := {}
## player id -> peer id
var by_player := {}
## realm id -> RealmInstance
var realms := {}
## net id -> Enemy, every realm
var enemies := {}
## realm id -> [{pos, ev, enemy, peer}] waiting to be sent this tick
var _pending := {}
var _next_enemy := 1
var _tick_timer := 0.0
var _save_timer := 0.0
var _heartbeat_timer := 0.0
var _ping_timer := 0.0
var _status := PacketPeerUDP.new()
var _beacon := PacketPeerUDP.new()
var _beacon_timer := 0.0
var _attack_keys := {}  # key -> attack dict (stripped, for the wire)
var _shares: Array = []  # [[shared_hits Array, id], ...] recent shared hit lists
var _next_share := 1
var _next_status_shot := 1
var _status_shots := {}
var _bag_realms := {}  # bag id -> realm id


func start(p_config: ServerConfig) -> Error:
	config = p_config
	var port := int(config.value("server", "port", Net.DEFAULT_PORT))
	var err := peer.create_server(port, int(config.value("server", "max_players", 300)))
	if err != OK:
		push_error("Can't open port %d (%s)" % [port, error_string(err)])
		return err
	multiplayer.multiplayer_peer = peer
	multiplayer.peer_disconnected.connect(_on_peer_left)
	api.base_url = str(config.value("accounts", "url", ""))
	api.server_key = str(config.value("accounts", "server_key", ""))
	add_child(api)
	if _status.bind(port + Net.STATUS_PORT_OFFSET) != OK:
		push_warning("Status port %d is taken: the server list can't ping this server." % (port + Net.STATUS_PORT_OFFSET))
	if config.value("server", "lan_discovery", true):
		_beacon.set_broadcast_enabled(true)
		_beacon.set_dest_address("255.255.255.255", Net.LAN_BEACON_PORT)
	GameServer.bag_added.connect(_on_bag_added)
	GameServer.bag_changed.connect(_on_bag_changed)
	GameServer.bag_removed.connect(_on_bag_removed)
	GameServer.xp_dropped.connect(_on_xp_dropped)
	GameServer.player_died.connect(_on_player_died)
	GameServer.player_died.connect(func(player_id: int, _lost: int) -> void: campaigns.on_death(player_id))
	dungeons.server = self
	add_child(dungeons)
	social.server = self
	campaigns.server = self
	add_child(social)
	add_child(campaigns)
	economy.server = self
	add_child(economy)
	fleet.server = self
	add_child(fleet)
	surface_port.server = self
	add_child(surface_port)
	print("[server] %s listening on UDP %d (status %d), account service %s" % [
			config.value("server", "name"), port, port + Net.STATUS_PORT_OFFSET, api.base_url])
	if api.server_key == "":
		push_warning("accounts/server_key is empty in server.cfg: players can't log in until it's set.")
	if bool(config.value("realms", "preload", true)): _preload_worlds.call_deferred()
	return OK


## The worlds that are the same every time (realms/keep_loaded: the Surface,
## Space) are built at start, one a frame, and stay loaded (asleep while empty,
## RealmInstance) so nobody waits for them; only memory pressure unloads them.
func _preload_worlds() -> void:
	for id in _kept():
		if realms.has(id): continue
		var started := Time.get_ticks_msec()
		_open_kept(id)
		print("[server] prepared %s in %d ms" % [id, Time.get_ticks_msec()-started])
		await get_tree().process_frame

func _kept() -> PackedStringArray:
	return str(config.value("realms", "keep_loaded", "realm_1,astral")).replace(" ", "").split(",", false)

func _open_kept(id: String) -> RealmInstance:
	if SpaceWorld.is_space(id) and id == SpaceWorld.REALM:
		return open_realm_record(id, {id = id, seed = 0, destroyed = [], space = true, name = "The Space"})
	return _open_realm(id)

## Over server/max_memory_mb (0: no limit), in megabytes of static memory.
func _over_memory() -> bool:
	var cap := int(config.value("server", "max_memory_mb", 0))
	return cap > 0 and OS.get_static_memory_usage() > cap * 1048576


func player_count() -> int:
	return peers.values().filter(func(p: Dictionary) -> bool: return p.joined).size()


func _process(delta: float) -> void:
	_answer_status()
	_beacon_timer -= delta
	if _beacon_timer <= 0.0 and config.value("server", "lan_discovery", true):
		_beacon_timer = 2.0
		_beacon.put_packet(JSON.stringify(_status_info()).to_utf8_buffer())
	_heartbeat_timer -= delta
	if _heartbeat_timer <= 0.0 and not config.singleplayer:
		_heartbeat_timer = float(config.value("accounts", "heartbeat_interval", 5.0))
		_heartbeat()
	_save_timer -= delta
	if _save_timer <= 0.0:
		_save_timer = float(config.value("accounts", "save_interval", 30.0))
		for peer_id in peers:
			_save(peer_id)
	_ping_timer -= delta
	if _ping_timer <= 0.0:
		_ping_timer = 1.0
		for peer_id in peers:
			Net.c_ping.rpc_id(peer_id, Net.now(), peers[peer_id].rtt)
	_unload_empty_realms(delta)


func _physics_process(delta: float) -> void:
	_tick_timer -= delta
	if _tick_timer > 0.0:
		return
	_tick_timer += 1.0 / float(config.value("network", "tick_rate", 20))
	_tick_timer = maxf(_tick_timer, 0.0)
	var t := Net.now()
	for peer_id in peers:
		var p: Dictionary = peers[peer_id]
		if p.joined and not p.dead:
			_tick_peer(peer_id, p, t)
	_pending.clear()
	for token in _status_shots.keys():
		if float(_status_shots[token].expires)<t: _status_shots.erase(token)


# --- Joining and leaving -----------------------------------------------------------

func on_hello(peer_id: int, protocol: int, token: String, character_id: int, account_name: String) -> void:
	if protocol != Net.PROTOCOL:
		_refuse(peer_id, "This server runs a different version of the game (protocol %d, you have %d)." % [Net.PROTOCOL, protocol])
		return
	if peers.has(peer_id):
		return
	if player_count() >= int(config.value("server", "max_players", 300)):
		_refuse(peer_id, "The server is full.")
		return
	for other: Dictionary in peers.values():
		if other.character_id == character_id:
			_refuse(peer_id, "That character is already playing here.")
			return
	peers[peer_id] = _new_record(peer_id, character_id, account_name)
	var r := await api.call_api("POST", "/server/claim", {token = token, character_id = character_id})
	if not peers.has(peer_id):
		if r.ok:
			api.call_api("POST", "/server/release", {character_id = character_id})
		return  # left while we waited
	if not r.ok:
		peers.erase(peer_id)
		_refuse(peer_id, r.error)
		return
	var account: Dictionary = r.data.account
	var stats := PlayerStats.new()
	var p: Dictionary = peers[peer_id]
	_take_character(p, stats, r.data)
	var player_id := GameServer.add_player(stats)
	p.player_id = player_id
	p.name = str(account.username)
	p.account_id = int(account.id)
	var loaded := await campaigns.load_book(p.account_id)
	if not loaded:
		peers.erase(peer_id)
		GameServer.remove_player(player_id)
		api.call_api("POST", "/server/release", {character_id = character_id})
		_refuse(peer_id, "Your campaign book could not be loaded. Please reconnect.")
		return
	if not peers.has(peer_id):
		GameServer.remove_player(player_id)
		return
	campaigns.migrate_story_inventory(p, p.get("story_migration", []))
	p.erase("story_migration")
	p.joined = true
	by_player[player_id] = peer_id
	economy.send_shops.call_deferred(p)
	stats.changed.connect(_on_stats_changed.bind(peer_id))
	stats.leveled_up.connect(func(level: int, gains: Dictionary) -> void:
		_to_peer(peer_id, ["lvl", level, gains]))
	stats.consumed.connect(func(item: Item) -> void: _to_peer(peer_id, ["use", item.id]))
	stats.xp_gained.connect(func(amount: int) -> void:
		# The account earns every point its characters earn.
		p.acct_pending += amount
		p.acct_xp += amount
		_to_peer(peer_id, ["acct", p.acct_xp]))
	Net.c_welcome.rpc_id(peer_id, {
		player_id = player_id, name = p.name, character_id = character_id, data = stats.to_data(),
		server_name = config.value("server", "name"), motd = config.value("server", "motd"),
		player_collision = config.value("gameplay", "player_collision", false),
		tick_rate = config.value("network", "tick_rate", 20), account_xp = p.acct_xp,
		singleplayer = config.singleplayer, dots = p.dots,
	})
	print("[server] %s joined with character #%d (%d online)" % [p.name, character_id, player_count()])


func _new_record(peer_id: int, character_id: int, account_name: String) -> Dictionary:
	return {
		peer_id = peer_id, character_id = character_id, name = account_name, account_id = 0, player_id = 0,
		joined = false, dead = false, realm = "", pos = Vector3.ZERO, facing = 0.0, speed = 0.0, flags = 0,
		moved_at = 0.0, grace = 0.0, known = {}, known_players = {}, sent_attacks = {}, ack = 0,
		dirty = false, rtt = 0.0, gear_key = "", acct_xp = 0, acct_pending = 0, switching = false,
		dots = 0, vault = {}, saving = false,
	}


## Commit before advancing a steward quest; every later character claim
## receives this account home, including newly created characters.
func _set_account_home(p: Dictionary, village: String) -> void:
	var realm: RealmInstance = realms.get(str(p.realm))
	if realm == null or not realm.world is IslandWorld or village.length() >= 40: return
	var town: VillageFeature = realm.world._village_plans.get(village)
	if town == null or Vector2(p.pos.x, p.pos.z).distance_to(Vector2(town.center)) > town.radius + 12.0: return
	var character_id := int(p.character_id)
	var result := await api.call_api("POST", "/server/home", {character_id = character_id, home = village})
	if not result.ok:
		social.system(p.player_id, "Could not save your account's spawn town. Please try again.")
		_send_character(int(by_player.get(p.player_id, 0)))
		return
	for other: Dictionary in peers.values():
		if other.get("joined", false) and int(other.get("account_id", 0)) == int(p.account_id):
			GameServer.request_set_home(int(other.player_id), village)
			other.dirty = true
	if int(p.character_id) == character_id: campaigns.home_set(p, village)


## Puts a claimed character (the account service's answer) into `stats`: its
## saved data, or a new character of its class with the account's starting
## rewards.
func _take_character(p: Dictionary, stats: PlayerStats, claim: Dictionary) -> void:
	var data: Dictionary = claim.character.get("data", {})
	p.dirty = data.is_empty()
	if data.is_empty():
		data = config.new_character(str(claim.character.get("class", "archer")), claim.account.get("rewards", [])).to_data()
	if claim.account.get("home") != null:
		if str(data.get("home", "")) != str(claim.account.home): p.dirty = true
		data = data.duplicate(true)
		data.home = str(claim.account.home)
	stats.load_data(data)
	var removed := stats.purge_story_items()
	if not removed.is_empty():
		p.dirty = true
		if int(p.get("account_id", 0)) == 0:
			p.story_migration = removed.map(func(item: Item) -> Dictionary: return {id = item.id, count = item.count})
	p.acct_xp = int(claim.account.get("progress", {}).get("xp", 0))
	p.acct_pending = 0
	economy.take_account(p, claim.account)


## The player picks another character (in the Tavern, or after dying): the
## one playing is saved and let go, the new one claimed in its place.
func _switch_character(peer_id: int, p: Dictionary, token: String, character_id: int) -> void:
	if p.switching or character_id == p.character_id and not p.dead:
		return
	if not p.dead and not Campaigns.is_tavern(p.realm):
		Net.c_events.rpc_id(peer_id, [[Net.now(), "switch_fail", "You can only change characters in the Tavern."]])
		return
	for other: Dictionary in peers.values():
		if other != p and other.character_id == character_id and other.joined:
			Net.c_events.rpc_id(peer_id, [[Net.now(), "switch_fail", "That character is already playing here."]])
			return
	campaigns._keep_items(social.party_for(p.player_id))
	p.switching = true
	var old_id: int = p.character_id
	if not p.dead:
		await _save_record(p)
		await api.call_api("POST", "/server/release", {character_id = old_id})
	var r := await api.call_api("POST", "/server/claim", {token = token, character_id = character_id})
	if not peers.has(peer_id):
		if r.ok:
			api.call_api("POST", "/server/release", {character_id = character_id})
		return
	p.switching = false
	if not r.ok:
		if not p.dead:  # keep playing the old one
			api.call_api("POST", "/server/claim", {token = token, character_id = old_id})
		Net.c_events.rpc_id(peer_id, [[Net.now(), "switch_fail", r.error]])
		return
	var stats := GameServer.character(p.player_id)
	p.character_id = character_id
	p.dead = false
	_take_character(p, stats, r.data)
	GameServer.revive(p.player_id)
	campaigns._restore_items(p, campaigns._run_of(social.party_for(p.player_id)))
	_send_character(peer_id)
	_to_peer(peer_id, ["switched", character_id, stats.class_id, p.acct_xp, stats.to_data()])  # (after dying they ask to enter the Tavern)
	print("[server] %s switched to character #%d (%s)" % [p.name, character_id, stats.class_id])


func _refuse(peer_id: int, reason: String) -> void:
	Net.c_refused.rpc_id(peer_id, reason)
	get_tree().create_timer(0.5).timeout.connect(func() -> void:
		if peer.get_peer(peer_id) != null:
			peer.disconnect_peer(peer_id))


func _on_peer_left(peer_id: int) -> void:
	var p: Dictionary = peers.get(peer_id, {})
	if p.is_empty():
		return
	if p.joined:
		campaigns._keep_world(social.party_for(p.player_id))
	peers.erase(peer_id)
	if not p.joined:
		return
	_leave_realm(p)
	social.on_left(p)
	campaigns.on_left(p)
	if not p.dead and not p.switching:
		await _save_record(p)
		await api.call_api("POST", "/server/release", {character_id = p.character_id})
	GameServer.remove_player(p.player_id)
	by_player.erase(p.player_id)
	print("[server] %s left (%d online)" % [p.name, player_count()])
	if config.singleplayer and peers.is_empty():
		print("[server] singleplayer session over")
		get_tree().quit()


## A gravestone where a character fell: it breaks the breakable things it
## lands on and pushes other players out of the way (so nobody gets stuck in
## it). Returns the event (for the one who died).
func _grave(p: Dictionary, stats: PlayerStats) -> Array:
	var realm: RealmInstance = realms.get(p.realm)
	if realm == null:
		return []
	var pos: Vector3 = p.pos
	pos.y = realm.world.ground_height(pos.x, pos.z)
	var title := "%s  -  %s, level %d" % [p.name, PlayerClasses.display_name(stats.class_id), stats.level]
	realm.graves.append({pos = pos, title = title})
	Gravestone.place(realm.world, pos, title, false)
	for obstacle_id: String in realm.world.obstacles_near(pos, Gravestone.CLEAR_RADIUS):
		WorldServer.report_obstacle_destroyed(p.realm, obstacle_id)
		realm.world.remove_obstacle(obstacle_id)
		_to_realm(p.realm, Vector3.INF, ["obs", obstacle_id])
	for other: Dictionary in peers.values():
		if other == p or other.realm != p.realm or not other.joined:
			continue
		var away := Vector3(other.pos.x - pos.x, 0.0, other.pos.z - pos.z)
		if away.length() < Gravestone.PUSH_RADIUS and realm.proxies.has(other.player_id):
			var dir := away.normalized() if away.length() > 0.05 else Vector3.FORWARD.rotated(Vector3.UP, randf() * TAU)
			melee_hit(realm.proxies[other.player_id], 0.0, false, false, dir * 10.0)
	var ev := ["grave", pos, title, true]
	_to_realm(p.realm, pos, ev.duplicate())
	return ev


## Saves and lets go of everyone (the server is stopping).
func save_all() -> void:
	await fleet.save_all()
	for party: Dictionary in social.parties.values(): campaigns._keep_world(party)
	await campaigns.flush()
	for p: Dictionary in peers.values():
		if p.joined and not p.dead and not p.switching:
			await _save_record(p)
			await api.call_api("POST", "/server/release", {character_id = p.character_id})


# --- Realms -----------------------------------------------------------------------

func on_enter(peer_id: int, destination: String) -> void:
	var p: Dictionary = peers.get(peer_id, {})
	if p.is_empty() or not p.joined or p.dead:
		return
	var record := {id = "hall"}
	var realm: RealmInstance = null
	var dungeon_return := Dungeons.is_dungeon(p.realm) and str(dungeons.grants.get(p.player_id, "")) == destination
	var arrival: Dictionary = p.get("dungeon_arrival", {}) if dungeon_return else {}
	# A dungeon return preserves the actual source Tavern as well.
	if not dungeon_return and destination == "hall" and campaigns.home_for(p) != "":
		destination = campaigns.home_for(p)
	if destination == "campaign":  # the Chronicle Gate: your party's campaign realm
		var found := campaigns.realm_for(p)
		if found[0] == "":
			Net.c_entered.rpc_id(peer_id, {error = found[1]})
			return
		destination = found[0]
	# Resolve the Chronicle Gate first so a private Space can be resumed too.
	destination = surface_port.redirect(p, destination)
	if ChambersWorld.is_chambers(destination):
		if p.account_id == 0:
			Net.c_entered.rpc_id(peer_id, {error = "The Chambers need an account."})
			return
		record = await economy.enter(p)
		if record.has("error") or not peers.has(peer_id) or p.dead:
			Net.c_entered.rpc_id(peer_id, record if record.has("error") else {error = "You can't go there right now."})
			return
	elif Campaigns.is_tavern(destination) and destination != "hall":
		if not campaigns.may_enter(p, destination):
			Net.c_entered.rpc_id(peer_id, {error = "That Tavern belongs to another party's tale."})
			return
		record = campaigns.tavern_record(p, destination)
	elif Campaigns.is_campaign_realm(destination):
		if not campaigns.may_enter(p, destination):
			Net.c_entered.rpc_id(peer_id, {error = "That campaign belongs to another party."})
			return
		realm = campaigns.open_realm(social.party_for(p.player_id))
	elif destination == "castle" or Campaigns.is_castle(destination):  # Aurelian's portal: the party's Hollow Castle
		var party := social.party_for(p.player_id)
		if party.is_empty() or party.campaign.is_empty():
			Net.c_entered.rpc_id(peer_id, {error = "The portal's light fades. You need the wizard's tale to go through."})
			return
		destination = party.campaign.castle
		if not campaigns.may_enter(p, destination):
			Net.c_entered.rpc_id(peer_id, {error = "That tale is no longer active."})
			return
		realm = campaigns.open_castle(party)
	elif SpaceWorld.is_space(destination):
		if not _astral_unlocked(p):
			Net.c_entered.rpc_id(peer_id, {error = "Space opens once the Theory of Everything is told."})
			return
		# A private realm's Space belongs to that campaign's party.
		if destination != SpaceWorld.REALM and not campaigns.may_enter(p, PortServer.surface_for(destination)):
			Net.c_entered.rpc_id(peer_id, {error = "That Space belongs to another party's tale."})
			return
		realm = realms.get(destination)
		if realm == null: realm = open_realm_record(destination, {id = destination, seed = 0, destroyed = [], space = true, name = "The Space"})
	elif Dungeons.is_dungeon(destination):
		if not dungeons.may_enter(p, destination):
			Net.c_entered.rpc_id(peer_id, {error = "Enter through a living dungeon portal."})
			return
		realm = realms.get(destination)
	elif destination != "hall":
		if Dungeons.is_dungeon(p.realm) and dungeons.may_enter(p, destination):
			realm = realms.get(destination)
		else:
			realm = _pick_realm(destination)
		if realm == null:
			Net.c_entered.rpc_id(peer_id, {error = "Every realm is full right now. Try again in a moment."})
			return
	_leave_realm(p)
	if realm:
		record = {id = realm.realm_id, seed = realm.record.seed, destroyed = realm.record.destroyed.duplicate(),
			name = realm.record.get("name", ""), layout_version = realm.record.get("layout_version", 1),
			cleared_packs = realm.record.get("cleared_packs", []).duplicate()}
		if realm.record.get("astral_station",false): record.astral_station=true
		if realm.record.get("castle", false):
			record.castle = true
		if realm.record.has("dungeon"):
			record.dungeon = realm.record.dungeon
			record.origin = realm.record.origin
			if realm.world is TheoryWorld: record.theory_state = realm.world.state_wire()
		elif realm.world is SpaceWorld:
			record.space = true
			record.space_state = realm.world.state_wire()
			record.intro = _astral_first_visit(p)
		else:
			record.stronghold_gates = realm.world.gates.states()
		realm.add_player(p.player_id, peer_id)
	surface_port.arrive(p, realm, record)
	if record.has("arrival_pos") and (record.arrival_pos as Vector3).is_finite():
		p.pos = record.arrival_pos
		if realm and realm.proxies.has(p.player_id): realm.proxies[p.player_id].global_position = record.arrival_pos
	if arrival.get("realm", "") == destination and (arrival.get("pos", Vector3.INF) as Vector3).is_finite():
		record.arrival_pos = arrival.pos
		p.pos = arrival.pos
		if realm and realm.proxies.has(p.player_id): realm.proxies[p.player_id].global_position = arrival.pos
	p.realm = record.id
	p.known.clear()
	p.known_players.clear()
	p.known_effects = {}
	p.known_enemy_effects = {}
	p.awaiting_arrival = true
	p.grace = SNAP_BACK_GRACE * 8.0
	p.moved_at = 0.0
	GameServer.enter_realm(p.player_id, record.id)
	if record.get("chambers", false):
		economy.spawn_chests(p)
	if Campaigns.is_tavern(str(record.get("id", destination))) or record.get("id", destination) == "hall":
		record.astral_unlocked = _astral_unlocked(p)
	Net.c_entered.rpc_id(peer_id, record)
	for bag_record in GameServer.bags_in(record.id, p.player_id):
		_to_peer(peer_id, ["bag+", _bag_wire(bag_record)])
	if realm:
		for g: Dictionary in realm.graves:
			_to_peer(peer_id, ["grave", g.pos, g.title, false])
	if record.get("chambers", false):
		social.system(p.player_id, "Your Chambers: %d chests, shared by every character of your account." % record.chests)
	else: social.system(p.player_id, ("Welcome to [place]the Tavern[/place], %s." % p.name if record.id == "hall" else
			"Back at [place]the Tavern[/place]. Your party's tale goes on.") if realm == null else
			"Welcome to %s. %s" % [realm.record.get("name", "the Surface"), "Your party's story continues here."
			if Campaigns.is_campaign_realm(realm.realm_id) else str(config.value("server", "motd", ""))])
	dungeons.entered(p)
	social.send_fog(p)
	campaigns.on_entered(p)


func _leave_realm(p: Dictionary) -> void:
	if ChambersWorld.is_chambers(p.realm):
		economy.leave(p)
	var realm: RealmInstance = realms.get(p.realm)
	surface_port.leaving(p, realm)
	if realm and realm.world is SpaceWorld:
		realm.world.player_left(p.player_id)
	elif realm and realm.world is IslandWorld and is_instance_valid(realm.world.surface_ships):
		realm.world.surface_ships.player_left(p.player_id)
	if realm:
		realm.remove_player(p.player_id)
	p.realm = ""


## The Reach opens after the Theory of Everything: for its tellers, and for a
## party standing in a Theory instance whose Empress has fallen.
func _astral_unlocked(p: Dictionary) -> bool:

	var here: RealmInstance = realms.get(p.realm)
	if here and here.world is TheoryWorld and here.world.boss_defeated: return true
	if int(p.get("account_id", 0)) == 0 or not is_instance_valid(campaigns): return false
	return str(campaigns.book(p.account_id).get("runs", {}).get("theory_of_everything", {}).get("status", "")) == "done"


## True once per account: the Nexus tour plays on the first arrival.
func _astral_first_visit(p: Dictionary) -> bool:
	if int(p.get("account_id", 0)) == 0 or not is_instance_valid(campaigns): return true
	var book: Dictionary = campaigns.book(p.account_id)
	if book.get("astral_intro", false): return false
	book.astral_intro = true
	campaigns._touch(p.account_id)
	return true


## A realm with room for one more (the asked-for one if it has room).
func _pick_realm(wanted: String) -> RealmInstance:
	var cap := int(config.value("realms", "max_players_per_realm", 85))
	if realms.has(wanted) and realms[wanted].proxies.size() < cap and not Campaigns.is_campaign_realm(wanted) and not Campaigns.is_castle(wanted) and not Dungeons.is_dungeon(wanted):
		return realms[wanted]
	var ids := realms.keys().filter(func(id: String) -> bool: return not Campaigns.is_campaign_realm(id) and not Campaigns.is_castle(id) and not Dungeons.is_dungeon(id))
	ids.sort()
	for id in ids:
		if realms[id].proxies.size() < cap:
			return realms[id]
	for i in range(1, int(config.value("realms", "max_realms", 8)) + 1):
		var id := "realm_%d" % i
		if not realms.has(id):
			return _open_realm(id)
	return null


func _open_realm(realm_id: String) -> RealmInstance:
	var record := WorldServer.get_or_create_realm(realm_id)
	var number := realm_id.trim_prefix("realm_")
	record.name = "The Surface" if number=="1" else "The Surface %s" % number
	return open_realm_record(realm_id, record)


func open_realm_record(realm_id: String, record: Dictionary) -> RealmInstance:
	var realm := RealmInstance.new(record)
	realm.name = realm_id
	add_child(realm)
	realms[realm_id] = realm
	print("[server] opened %s (seed %d)" % [realm_id, record.seed])
	return realm


## Closes a realm now (its state is already saved): a campaign that paused or ended.
func close_realm(realm_id: String) -> void:
	var realm: RealmInstance = realms.get(realm_id)
	if realm == null:
		return
	for p: Dictionary in peers.values():
		if p.realm == realm_id:
			_leave_realm(p)
	realms.erase(realm_id)
	realm.queue_free()
	print("[server] closed %s" % realm_id)


func _unload_empty_realms(_delta: float) -> void:
	var after := float(config.value("realms", "unload_after_empty", 120.0))
	var kept := _kept()
	var squeezed := _over_memory()
	for id in realms.keys():
		var realm: RealmInstance = realms[id]
		if not realm.proxies.is_empty() or dungeons.keeps_origin_open(id): continue
		# Kept worlds stay (asleep) unless memory runs short; others go when empty long enough.
		var due := realm.empty_for > (2.0 if squeezed else after)
		if due and (not id in kept or squeezed):
			realms.erase(id)
			realm.queue_free()
			print("[server] closed %s (empty)" % id)


# --- What players send ---------------------------------------------------------------

func on_move(peer_id: int, pos: Vector3, facing: float, speed: float, flags: int) -> void:
	var p: Dictionary = peers.get(peer_id, {})
	if p.is_empty() or not p.joined or p.dead or p.realm == "":
		return
	var t := Net.now()
	var stats := GameServer.character(p.player_id)
	if GameServer.intro_locked(p.player_id) or (stats and stats.buffs.has_effect("static")):
		if pos.distance_to(p.pos)>.15: Net.c_correct.rpc_id(peer_id,p.pos)
		pos = p.pos
		speed = 0.0
		if GameServer.intro_locked(p.player_id): flags = flags & ~1
	var active_realm: RealmInstance = realms.get(p.realm)
	if active_realm and active_realm.world is SpaceWorld:
		var seat := (active_realm.world as SpaceWorld).city.seat_of(int(p.player_id))
		if seat!="":
			pos = CityLayout.any_seat(seat).pos
			speed = 0.0
	var recovering := false
	var spatial: SpatialWorld = active_realm.world if active_realm and active_realm.world is SpatialWorld else null
	if active_realm and active_realm.world is IslandWorld and SpaceLayout.pocket_at(p.pos)>=0:
		spatial = active_realm.world.surface_ships
	if spatial:
		if not pos.is_finite(): return
		var barrier: Dictionary = spatial.barrier_between(p.pos,pos)
		if not barrier.is_empty():
			p.pos = barrier.point
			p.grace = SNAP_BACK_GRACE
			if active_realm.proxies.has(p.player_id): active_realm.proxies[p.player_id].global_position = p.pos
			Net.c_correct.rpc_id(peer_id,p.pos)
			return
		recovering = spatial.legal_recovery(p.pos,pos)
		if not spatial.is_walkable(pos):
			Net.c_correct.rpc_id(peer_id,spatial.recovery_point(p.pos))
			return
	if active_realm and active_realm.world is IslandWorld and spatial==null and active_realm.world.gates.blocks_segment(p.pos,pos):
		Net.c_correct.rpc_id(peer_id,p.pos)
		p.moved_at = t
		return
	if p.moved_at > 0.0 and p.grace <= 0.0:
		# Believable? Walking speed, with slack for knockback and lag, not a teleport.
		var dt := maxf(0.05, t - p.moved_at)
		var flat := pos.distance_to(p.pos) if spatial!=null else Vector2(pos.x-p.pos.x,pos.z-p.pos.z).length()
		var limit := Player.BASE_SPEED * stats.move_speed_multiplier() * float(config.value("network", "max_speed_tolerance", 1.6)) \
				+ Player.KNOCKBACK_MAX + (spatial.extra_speed(p.pos, pos) if spatial else 0.0)
		if flat > limit * dt + 0.75 and not recovering:
			Net.c_correct.rpc_id(peer_id, p.pos)
			p.grace = SNAP_BACK_GRACE
			p.moved_at = t
			return
	p.grace = maxf(0.0, p.grace - (t - p.moved_at if p.moved_at > 0.0 else 0.0))
	p.pos = pos
	p.facing = facing
	p.speed = speed
	p.flags = flags
	p.moved_at = t
	GameServer.report_position(p.player_id, p.realm, pos)
	var realm: RealmInstance = realms.get(p.realm)
	if realm and realm.proxies.has(p.player_id):
		var proxy: NetPlayerProxy = realm.proxies[p.player_id]
		proxy.global_position = pos
		proxy.frozen = (flags & 2) != 0
		proxy.shield_up = (flags & 1) != 0


func on_action(peer_id: int, kind: String, args: Array) -> void:
	var p: Dictionary = peers.get(peer_id, {})
	if p.is_empty() or not p.joined:
		return
	if kind == "switch":  # [token, character id]: also allowed after dying
		_switch_character(peer_id, p, str(args[0]), int(args[1]))
		return
	# Talking and the party work while choosing a new character too.
	match kind:
		"chat":  # [text]
			if args.size() == 1: social.on_chat(p, str(args[0]))
			return
		"party":  # [op, name]: invite, accept, decline, leave, kick, lead
			if args.size() == 2: social._command(p, "/%s %s" % [str(args[0]), str(args[1])])
			return
		"camp":  # [op, ...]: list, start, pause, quest (see CampaignServer.on_action)
			campaigns.on_action(p, args)
			return
	if p.dead or p.switching:
		return
	var pid: int = p.player_id
	if GameServer.interacting(pid) and kind in ["hit", "ring", "shield", "obstacle", "obstacle_hit"]: return
	if GameServer.intro_locked(pid) and kind in ["hit","ring","shield","obstacle","obstacle_hit"]: return
	match kind:
		"interaction":
			if args.size() == 1 and args[0] is bool: GameServer.set_interaction_protection(pid, args[0])
		"dungeon":
			if args.size() == 1: dungeons.interact(p, str(args[0]))
		"theory":
			var instance: RealmInstance = realms.get(p.realm)
			if instance!=null and instance.world is SpatialWorld: instance.world.server_action(p,args)
		"status_hit":
			if args.size()==1: _status_hit(p,int(args[0]))
		"hurt":  # [seq, amount, armor_piercing, shielded, by]: an enemy hit them on their screen
			p.ack = maxi(p.ack, int(args[0]))
			p.last_hit_by = str(args[4])
			GameServer.hit_player(pid, clampf(float(args[1]), 0.0, 5000.0), bool(args[2]), bool(args[3]),p.last_hit_by)
		"ring":  # [seq]
			p.ack = maxi(p.ack, int(args[0]))
			var stats := GameServer.character(pid)
			if GameServer.request_ring(pid) and stats.gear.spell:
				_to_realm(p.realm, p.pos, ["ring", pid, stats.gear.spell.id, p.pos, stats.spell_multiplier(stats.gear.spell)], 0, peer_id)
		"shield":
			GameServer.set_shield(pid, bool(args[0]))
		"shield_contact":
			if GameServer.shield_up(pid):
				_to_realm(p.realm, p.pos, ["sfx", "magic_shield_hit", p.pos + Vector3.UP * .9,
					{source_id = pid, cooldown = .08}], 0, peer_id)
		"open_chest":
			if args.size() == 1: GameServer.request_open_chest(pid, int(args[0]))
		"arrived":
			if p.get("awaiting_arrival", false):
				p.awaiting_arrival = false
				GameServer.grant_arrival_protection(pid)
		"hit":  # [enemy net id, damage, direction, equipped item, secondary]
			if args.size() >= 3:
				_player_hit_enemy(p, int(args[0]), int(args[1]), args[2] if args[2] is Vector3 else Vector3.ZERO,
					str(args[3]) if args.size() > 3 else "", bool(args[4]) if args.size() > 4 else false)
		"inv":  # [op, places...]
			match str(args[0]):
				"move": GameServer.request_move(pid, args[1], args[2])
				"activate": GameServer.request_activate(pid, args[1])
				"use": GameServer.request_use(pid, args[1])
				"drop": GameServer.request_drop(pid, args[1])
			_send_character(peer_id)  # even a refused request gets the true state back
		"xp":
			GameServer.collect_xp(pid, int(args[0]))
		"shop":  # [shop id, item id, price seen]: buy it for Dots
			if args.size() == 3: economy.buy(p, str(args[0]), str(args[1]), int(args[2]))
		"fleet":
			fleet.on_action(p, args)
		"port":  # ["buy"] / ["launch"] at the Skyward Launch Pad
			surface_port.on_action(p, args)
		"forge":  # [place, item id]: dismantle it at the forge for Dots
			if args.size() == 2:
				economy.dismantle(p, args[0], str(args[1]))
		"gate":  # [fortress center]: use the key they carry on its sealed gates
			if args.size() == 1: _use_gate_key(peer_id, p, args[0])
		"castle":  # [op...]: the Hollow Castle's doors and encounter (CastleWorld)
			var realm: RealmInstance = realms.get(p.realm)
			if realm and realm.world.get("encounter") != null:
				realm.world.encounter.on_action(p, args)
		"tp":  # [name]: go to another player
			if args.size() == 1: social.teleport(p, str(args[0]))
		"home":  # [village]: a steward changes the account's realm spawn town
			if args.size() == 1: _set_account_home(p, str(args[0]))
		"obstacle":  # [obstacle id, position]
			_obstacle_broken(p, str(args[0]), args[1] if args[1] is Vector3 else p.pos)
		"obstacle_hit":  # [obstacle id, damage, position]: others see the chips fly and keep count
			if p.realm != "" and p.realm != "hall":
				_to_realm(p.realm, args[2] if args[2] is Vector3 else p.pos, ["oh", str(args[0]), int(args[1]),
						args[2]], 0, peer_id)


func on_shot(peer_id: int, origin: Vector3, direction: Vector3, weapon_id: String, phase: float, mods: Dictionary) -> void:
	var p: Dictionary = peers.get(peer_id, {})
	if p.is_empty() or not p.joined or p.dead or p.switching or p.realm == "" or not Items.exists(weapon_id):
		return
	var stats := GameServer.character(p.player_id)
	if stats == null or GameServer.intro_locked(p.player_id) or GameServer.interacting(p.player_id) or stats.buffs.has_effect("quiet"): return
	var clean := {}
	for key in ["speed", "size", "range", "spiral", "pierce", "wave_amp", "burst", "secondary", "style", "cone_deg"]:
		if mods.has(key):
			clean[key] = mods[key]
	_to_realm(p.realm, origin, ["shot", p.player_id, origin, direction, weapon_id, phase, clean], 0, peer_id)


func on_pong(peer_id: int, t: float) -> void:
	if peers.has(peer_id):
		peers[peer_id].rtt = lerpf(peers[peer_id].rtt, Net.now() - t, 0.5 if peers[peer_id].rtt > 0.0 else 1.0)


## Checks a hit a player reports on an enemy, then applies it.
func _player_hit_enemy(p: Dictionary, net_id: int, damage: int, direction: Vector3, item_id := "", secondary := false) -> void:
	var enemy: Enemy = enemies.get(net_id)
	if not is_instance_valid(enemy) or Net.realm_of(enemy) != p.realm:
		return
	if Vector2(enemy.global_position.x - p.pos.x, enemy.global_position.z - p.pos.z).length() > MAX_HIT_RANGE:
		return
	var stats := GameServer.character(p.player_id)
	if stats == null or GameServer.intro_locked(p.player_id) or GameServer.interacting(p.player_id) or stats.buffs.has_effect("quiet"): return
	if damage <= 0 or damage > _max_hit(stats):
		return
	var realm: RealmInstance = realms.get(p.realm)
	var proxy: Node = realm.proxies.get(p.player_id) if realm else null
	var before_hp := enemy.hp
	var item: Item = null
	for slot in ["weapon", "spell"]:
		var equipped: Item = stats.gear.get(slot)
		if equipped != null and equipped.id == item_id: item = equipped
	if item != null:
		if secondary and item.charge.is_empty() and item.ring.is_empty(): return
		enemy.receive_weapon_hit(enemy.global_position, direction, damage, item, secondary, proxy)
	elif item_id == "":
		enemy.take_hit(enemy.global_position, direction, damage, proxy)
	else:
		return
	if enemy.hp < before_hp: GameServer.report_hit_landed(p.player_id)


## The most one shot or ring of this character could deal.
func _max_hit(stats: PlayerStats) -> int:
	var best := 0.0
	var weapon: Item = stats.gear.weapon
	if weapon:
		var mult: float = weapon.charge.get("mult", 1.0) if not weapon.charge.is_empty() else 1.0
		best = weapon.damage_max * stats.weapon_damage_multiplier() * maxf(1.0, mult)
		best = maxf(best, weapon.charge.get("ring_damage", 0))
	var spell: Item = stats.gear.spell
	if spell and not spell.ring.is_empty():
		best = maxf(best, spell.ring.damage * stats.spell_multiplier(spell))
	return int(ceil(best * HIT_SLACK)) + 2


func _obstacle_broken(p: Dictionary, obstacle_id: String, pos: Vector3) -> void:
	var realm: RealmInstance = realms.get(p.realm)
	if realm == null or realm.world is DungeonWorld or obstacle_id in realm.record.destroyed:
		return
	WorldServer.report_obstacle_destroyed(p.realm, obstacle_id)
	realm.world.remove_obstacle(obstacle_id)
	if pos.distance_to(p.pos) < 40.0:
		GameServer.drop_xp(p.realm, pos + Vector3.UP, XP_PER_OBSTACLE)
	_to_realm(p.realm, Vector3.INF, ["obs", obstacle_id], 0, p.peer_id)


## A boss's melee (a charge, a slam) caught a player: their client applies it.
func melee_hit(proxy: NetPlayerProxy, amount: float, armor_piercing: bool, magic: bool, push: Vector3) -> void:
	if GameServer.intro_protected(proxy.player_id): return
	if peers.has(proxy.peer_id):
		_to_peer(proxy.peer_id, ["hit", amount, armor_piercing, magic, push])


# --- Death and saving -------------------------------------------------------------

func _on_player_died(player_id: int, lost: int) -> void:
	var peer_id: int = by_player.get(player_id, 0)
	var p: Dictionary = peers.get(peer_id, {})
	if p.is_empty() or p.dead:
		return
	p.dead = true
	var stats := GameServer.character(player_id)
	var killed_by: String = p.get("last_hit_by", "")
	if GameServer.last_damage_source(player_id)!="": killed_by = GameServer.last_damage_source(player_id)
	var realm_id: String = p.realm
	var grave := _grave(p, stats)
	_leave_realm(p)
	if not grave.is_empty():
		# Dead peers do not tick: send their effect directly, before saving the death.
		grave.push_front(Net.now())
		Net.c_events.rpc_id(peer_id, [grave])
	print("[server] %s's character #%d died (level %d, killed by %s)" % [p.name, p.character_id, stats.level, killed_by])
	var data := stats.to_data()
	var r := await api.call_api("POST", "/server/die", {character_id = p.character_id, data = data,
			killed_by = killed_by, realm = realm_id, account_xp = p.acct_pending})
	if not r.ok:
		push_error("Couldn't record the death of #%d: %s" % [p.character_id, r.error])
	else:
		p.acct_pending = 0
		p.acct_xp = int(r.data.get("progress", {}).get("xp", p.acct_xp))
	# They stay connected: next they pick (or make) another character.
	if multiplayer.get_peers().has(peer_id):
		Net.c_died.rpc_id(peer_id, {character_id = p.character_id, level = stats.level, killed_by = killed_by,
				items_lost = lost, realm = realm_id, data = data, died = Time.get_unix_time_from_system(),
				account_xp = int(r.data.get("account_xp", 0)) if r.ok else 0,
				items_xp = int(r.data.get("items_xp", 0)) if r.ok else 0,
				share_xp = int(r.data.get("share_xp", 0)) if r.ok else 0, total_account_xp = p.acct_xp})


func _save(peer_id: int) -> void:
	var p: Dictionary = peers.get(peer_id, {})
	if p.is_empty() or not p.joined or p.dead or p.switching or not (p.dirty or p.acct_pending > 0):
		return
	_save_record(p)


func _save_record(p: Dictionary) -> void:
	await save_record(p)


## Saves a character, one save at a time per player (so an older save can
## never land after a newer one). With a changed vault, the vault goes with
## it; `extra` {kind = "dismantle", item_id, count} pays Dots with it.
## Returns the account service's answer ({ok = false} when nothing was sent).
func save_record(p: Dictionary, extra := {}) -> Dictionary:
	var stats := GameServer.character(p.player_id)
	if stats == null:
		return {ok = false, error = "character unavailable"}
	while p.get("saving", false):
		await get_tree().process_frame
	if p.dead:
		return {ok = false, error = "dead"}
	p.saving = true
	p.dirty = false
	var r: Dictionary
	var vault: Variant = economy.pending_vault(p)
	var vault_revision := int(p.vault.get("revision", 0)) if vault != null else -1
	if extra.get("kind", "") == "buy":
		r = await api.call_api("POST", "/server/shop/buy", {character_id = p.character_id, data = stats.to_data(),
				shop = extra.shop, item_id = extra.item_id, price = extra.price})
	elif extra.get("kind", "") == "dismantle":
		r = await api.call_api("POST", "/server/dismantle", {character_id = p.character_id, data = stats.to_data(),
				item_id = extra.item_id, count = extra.count})
	elif vault != null:
		r = await api.call_api("POST", "/server/vault/save", {character_id = p.character_id, data = stats.to_data(),
				items = vault})
		if r.ok and int(p.vault.get("revision", 0)) == vault_revision:
			p.vault.dirty = false
	else:
		var sent_xp: int = p.acct_pending
		r = await api.call_api("POST", "/server/save", {character_id = p.character_id, data = stats.to_data(),
				account_xp = sent_xp})
		if r.ok:
			p.acct_pending = maxi(0, p.acct_pending - sent_xp)
			print("[server] saved #%d (level %d, +%d account xp)" % [p.character_id, stats.level, sent_xp])
	p.saving = false
	if not r.ok:
		p.dirty = true
		push_warning("Couldn't save #%d: %s" % [p.character_id, r.error])
	elif vault != null and extra.is_empty():
		print("[server] saved #%d with %s's Chambers" % [p.character_id, p.name])
	return r


func _on_stats_changed(peer_id: int) -> void:
	var p: Dictionary = peers.get(peer_id, {})
	if p.is_empty():
		return
	p.dirty = true
	if not p.get("send_queued", false):
		p.send_queued = true
		_send_character.call_deferred(peer_id)


func _send_character(peer_id: int) -> void:
	var p: Dictionary = peers.get(peer_id, {})
	if p.is_empty() or not p.joined:
		return
	p.send_queued = false
	var stats := GameServer.character(p.player_id)
	if stats:
		Net.c_character.rpc_id(peer_id, stats.to_data())


# --- Enemies (called from the game code) -----------------------------------------

func register_enemy(enemy: Enemy) -> int:
	var id := _next_enemy
	_next_enemy += 1
	enemies[id] = enemy
	var realm: RealmInstance = realms.get(Net.realm_of(enemy))
	if realm:
		realm.enemies[id] = enemy
	enemy.tree_exiting.connect(func() -> void:
		enemies.erase(id)
		if is_instance_valid(realm):
			realm.enemies.erase(id))
	return id


func model_call(enemy: Enemy, method: StringName, args: Array, shell := false) -> void:
	var event: Array = ["m", enemy.net_id, method, args]
	if shell: event.append(true)
	_queue(Net.realm_of(enemy), enemy.global_position, event, enemy.net_id)


## An effect (text, voxels, shake, ripple...) at `pos` in the realm `source` is in.
func fx(source: Node, pos: Vector3, ev: Array) -> void:
	_queue(Net.realm_of(source), pos, ev)


func fortress_gate(world: GameWorld, center: Vector2i, locked: bool, sealed: bool) -> void:
	_to_realm(world.realm_id,Vector3.INF,["fort_gate",center,locked,sealed])


## A player turns a key in a fortress gate: they must stand at it and carry
## that fortress's key, which is spent.
func _use_gate_key(peer_id: int, p: Dictionary, center: Variant) -> void:
	var realm: RealmInstance = realms.get(p.realm)
	if realm == null or not realm.world.get("gates") is StrongholdGates or not center is Vector2i:
		return
	if realm.world.gates.try_open(center, GameServer.character(p.player_id), p.pos):
		_send_character(peer_id)
		social.announce(p.realm, "%s turned a key. The gates of %s grind open." % [p.name,
				realm.world.gates.entries[center].fort.display_name])


func hazard_event(boss: Node, ev: Array) -> void:
	if is_instance_valid(boss):
		_queue(Net.realm_of(boss), boss.global_position, ev, boss.net_id)


func enemy_shot(bullets: Node, origin: Vector3, direction: Vector3, attack: Dictionary, source: Node, shot_y: float) -> void:
	var def: EnemyDef = (source as Enemy).def if source is Enemy else null
	var wire: Dictionary = _strip(attack)
	var mult := config.damage_multiplier(def.id) if def else float(config.value("gameplay", "enemy_damage_multiplier", 1.0))
	if mult != 1.0:
		wire.damage_min = roundi(float(wire.get("damage_min", 5)) * mult)
		wire.damage_max = roundi(float(wire.get("damage_max", 10)) * mult)
	if def:
		wire.by = def.enemy_name
	var key := hash(wire)
	if not _attack_keys.has(key):
		_attack_keys[key] = wire
	var share := 0
	if attack.has("shared_hits"):
		share = _share_id(attack.shared_hits)
	var boss_id := def.id if def is BossDef else ""
	var status_tokens := _authorize_status_shots(wire,Net.realm_of(bullets),origin,def.id if def else "projectile")
	_queue(Net.realm_of(bullets), origin, ["b", origin, direction, key, EnemyBullets._owner_id(source),
			shot_y, boss_id, share, status_tokens])


## A ripple's damage, scaled by the server config.
func scaled_damage(_parent: Node, ripple: Dictionary) -> Dictionary:
	var mult := float(config.value("gameplay", "enemy_damage_multiplier", 1.0))
	var realm: RealmInstance = realms.get(Net.realm_of(_parent))
	if realm and realm.world is DungeonWorld: mult *= float(realm.world.definition.enemy_damage_multiplier)
	if mult == 1.0:
		return ripple
	var out := ripple.duplicate()
	out.damage_min = roundi(float(ripple.get("damage_min", 8)) * mult)
	out.damage_max = roundi(float(ripple.get("damage_max", 12)) * mult)
	return out


func scaled_vector_damage(boss: Node, damage: Vector2i) -> Vector2i:
	var mult := config.damage_multiplier(boss.def.id) if boss is Enemy else 1.0
	var realm: RealmInstance = realms.get(Net.realm_of(boss))
	if realm and realm.world is DungeonWorld: mult *= float(realm.world.definition.enemy_damage_multiplier)
	return Vector2i(roundi(damage.x * mult), roundi(damage.y * mult))


## An attack for the wire: no runtime state (hit lists) and nothing that isn't plain data.
static func _strip(value: Variant) -> Variant:
	if value is Dictionary:
		var out := {}
		for k in value:
			if k == "shared_hits":
				continue
			var v: Variant = _strip(value[k])
			if v != null or value[k] == null:
				out[k] = v
		return out
	if value is Array:
		return (value as Array).map(_strip)
	if value is Object or value is Callable or value is Signal:
		return null
	return value


func _share_id(list: Array) -> int:
	for entry: Array in _shares:
		if is_same(entry[0], list):
			return entry[1]
	_next_share += 1
	_shares.append([list, _next_share])
	if _shares.size() > 64:
		_shares.pop_front()
	return _next_share


# --- Bags and XP ------------------------------------------------------------------

func _bag_wire(record: Dictionary) -> Dictionary:
	var wire := {id = record.id, realm = record.realm, type = record.type, viewer = record.viewer,
		items = Net.encode_items(record.items), pos = record.pos, opened = record.get("opened", false)}
	for key in ["yaw", "label"]:
		if record.has(key):
			wire[key] = record[key]
	return wire


func _on_bag_added(record: Dictionary) -> void:
	_bag_realms[record.id] = record.realm
	var only: int = by_player.get(record.viewer, -1) if record.viewer != GameServer.PUBLIC else 0
	if only != -1:
		# Story chests can appear far ahead of the party; they must already be
		# known when approached, just like the realm-wide bag updates/removals.
		_to_realm(record.realm, Vector3.INF if record.type == "story" else record.pos, ["bag+", _bag_wire(record)], 0, 0, only)


func _on_bag_changed(bag_id: int) -> void:
	var record := GameServer.bag(bag_id)
	if record.is_empty():
		return
	var only: int = by_player.get(record.viewer, -1) if record.viewer != GameServer.PUBLIC else 0
	if only != -1:
		_to_realm(record.realm, Vector3.INF, ["bag~", bag_id, Net.encode_items(record.items), record.get("opened", false)], 0, 0, only)


func _on_bag_removed(bag_id: int) -> void:
	var realm_id: String = _bag_realms.get(bag_id, "")
	_bag_realms.erase(bag_id)
	if realm_id != "":
		_to_realm(realm_id, Vector3.INF, ["bag-", bag_id])


func _on_xp_dropped(realm_id: String, pos: Vector3, orbs: Array) -> void:
	_to_realm(realm_id, pos, ["xp", realm_id, pos, orbs])


# --- Sending ----------------------------------------------------------------------

func _queue(realm_id: String, pos: Vector3, ev: Array, enemy := 0) -> void:
	_to_realm(realm_id, pos, ev, enemy)


## An event for the players in a realm: near `pos` (INF = everyone there),
## who know `enemy` (if set), except `skip`, or only `only` (a peer id).
func _to_realm(realm_id: String, pos: Vector3, ev: Array, enemy := 0, skip := 0, only := 0) -> void:
	if realm_id == "":
		return
	if not _pending.has(realm_id):
		_pending[realm_id] = []
	ev.push_front(Net.now())
	_pending[realm_id].append({pos = pos, ev = ev, enemy = enemy, skip = skip, only = only})


func _to_peer(peer_id: int, ev: Array) -> void:
	var p: Dictionary = peers.get(peer_id, {})
	if not p.is_empty():
		_to_realm(p.realm if p.realm != "" else "_limbo", Vector3.INF, ev, 0, 0, peer_id)


func _tick_peer(peer_id: int, p: Dictionary, t: float) -> void:
	var events: Array = []
	var here: Vector3 = p.pos
	var interest := float(config.value("network", "interest_radius", 72.0))
	var event_radius := float(config.value("network", "event_radius", 85.0))
	var realm: RealmInstance = realms.get(p.realm)
	# Ship rooms use remote coordinates. Gunners also need the enemies,
	# players and effects around their real hull on the ground.
	var outside := here
	if realm and SpaceLayout.pocket_at(here)>=0:
		var fleet: SpaceWorld = realm.world if realm.world is SpaceWorld else realm.world.surface_ships if realm.world is IslandWorld else null
		var vessel := fleet.ship_in_slot(SpaceLayout.pocket_at(here)) if fleet else null
		if vessel and vessel.mode=="landed": outside = vessel.xform.origin
	# Enemies coming into view and leaving it.
	var snap := PackedFloat32Array()
	var bosses: Array = []
	if realm:
		var seen := {}
		for id: int in realm.enemies:
			var e: Enemy = realm.enemies[id]
			if not is_instance_valid(e) or not e.is_inside_tree():
				continue
			var flat := minf(Vector2(e.global_position.x - here.x, e.global_position.z - here.z).length(), Vector2(e.global_position.x - outside.x, e.global_position.z - outside.z).length())
			if flat > interest and not (e is Boss and flat < (e as Boss).boss_def.bar_radius + 10.0):
				continue
			seen[id] = true
			if not p.known.has(id):
				events.append([t, "e+", id, e.def.id, e.global_position, e.model.rotation.y, e.state, e.hp, e.max_hp,
						e.is_minion, e.encounter_id])
			if not p.has("known_enemy_effects"): p.known_enemy_effects = {}
			if not p.known.has(id) or p.known_enemy_effects.get(id, -1) != e.buffs.revision:
				events.append([t, "enemy_buffs", id, e.buffs.wire()])
				p.known_enemy_effects[id] = e.buffs.revision
			snap.append_array(e.net_state())
			if e is Boss:
				bosses.append((e as Boss).net_boss_state(int(p.player_id)))
		for id in p.known:
			if not seen.has(id):
				events.append([t, "e-", id])
				if p.has("known_enemy_effects"): p.known_enemy_effects.erase(id)
		p.known = seen
	# Other players.
	var players := PackedFloat32Array()
	var seen_players := {}
	if not p.has("known_effects"): p.known_effects = {}
	for other_id: int in peers:
		var o: Dictionary = peers[other_id]
		if other_id == peer_id or not o.joined or o.dead or o.realm != p.realm or p.realm == "":
			continue
		if minf(Vector2(o.pos.x - here.x, o.pos.z - here.z).length(), Vector2(o.pos.x - outside.x, o.pos.z - outside.z).length()) > interest:
			continue
		seen_players[o.player_id] = true
		var gear := _gear_key(o.player_id)
		if p.known_players.get(o.player_id, "") != gear:
			events.append([t, "p+", o.player_id, o.name, gear])
		var other_stats := GameServer.character(o.player_id)
		if other_stats and p.known_effects.get(o.player_id,-1) != other_stats.buffs.revision:
			events.append([t,"buffs",o.player_id,other_stats.buffs.wire()])
			p.known_effects[o.player_id] = other_stats.buffs.revision
		players.append_array(PackedFloat32Array([o.player_id, o.pos.x, o.pos.y, o.pos.z, o.facing, o.speed, o.flags]))
	for pid in p.known_players:
		if not seen_players.has(pid):
			events.append([t, "p-", pid])
			p.known_effects.erase(pid)
	var known_players := {}
	for pid in seen_players:
		known_players[pid] = _gear_key(pid)
	p.known_players = known_players
	var own_stats := GameServer.character(p.player_id)
	if own_stats and p.known_effects.get(p.player_id,-1) != own_stats.buffs.revision:
		events.append([t,"buffs",p.player_id,own_stats.buffs.wire()])
		p.known_effects[p.player_id] = own_stats.buffs.revision
	# Events near them.
	for queue_id in [p.realm, "_limbo"]:
		for entry: Dictionary in _pending.get(queue_id, []):
			if entry.only != 0 and entry.only != peer_id:
				continue
			if entry.skip == peer_id:
				continue
			if entry.enemy != 0 and not p.known.has(entry.enemy):
				continue
			if entry.pos != Vector3.INF and minf(Vector2(entry.pos.x - here.x, entry.pos.z - here.z).length(), Vector2(entry.pos.x - outside.x, entry.pos.z - outside.z).length()) > event_radius:
				continue
			var ev: Array = entry.ev
			if ev[1] == "b" and not p.sent_attacks.has(ev[4]):
				p.sent_attacks[ev[4]] = true
				events.append([ev[0], "ad", ev[4], _attack_keys[ev[4]]])
			events.append(ev)
	if not events.is_empty():
		Net.c_events.rpc_id(peer_id, events)
	var stats := GameServer.character(p.player_id)
	var me := [stats.hp, stats.mp, p.ack, GameServer.shield_up(p.player_id)] if stats else []
	# Send each component separately: combining enemy+player slices exceeds
	# the MTU even when each slice is small. Intro admission is per viewer.
	for boss_state: Array in bosses:
		if var_to_bytes(boss_state).size() > 1000:
			Net.c_boss_snapshot.rpc_id(peer_id, t, [boss_state])
		else:
			Net.c_snapshot.rpc_id(peer_id, t, PackedFloat32Array(), [boss_state], PackedFloat32Array(), [])
	Net.c_snapshot.rpc_id(peer_id,t,PackedFloat32Array(),[],PackedFloat32Array(),me)
	var per := SNAPSHOT_ENEMIES*Net.ENEMY_STRIDE
	for at in range(0,snap.size(),per):
		Net.c_snapshot.rpc_id(peer_id,t,snap.slice(at,at+per),[],PackedFloat32Array(),[])
	var per_players := SNAPSHOT_ENEMIES*2*Net.PLAYER_STRIDE
	for at in range(0,players.size(),per_players):
		Net.c_snapshot.rpc_id(peer_id,t,PackedFloat32Array(),[],players.slice(at,at+per_players),[])


## What another player looks like: their gear (for colors and auras).
func _gear_key(player_id: int) -> String:
	var stats := GameServer.character(player_id)
	if stats == null:
		return ""
	var ids := []
	for slot in PlayerStats.GEAR_SLOTS:
		ids.append(stats.gear[slot].id if stats.gear[slot] else "")
	return stats.class_id + "|" + ",".join(ids)


# --- Finding the server -----------------------------------------------------------

func _status_info() -> Dictionary:
	return {game = "voidrealms", name = config.value("server", "name"), players = player_count(),
		max_players = config.value("server", "max_players", 300), motd = config.value("server", "motd", ""),
		version = Net.VERSION, protocol = Net.PROTOCOL, port = int(config.value("server", "port", Net.DEFAULT_PORT))}


## Status pings from server lists: "VRPING <nonce>" -> JSON with the nonce.
func _answer_status() -> void:
	while _status.get_available_packet_count() > 0:
		var packet := _status.get_packet().get_string_from_utf8()
		if not packet.begins_with("VRPING"):
			continue
		var info := _status_info()
		info.nonce = packet.substr(7)
		_status.set_dest_address(_status.get_packet_ip(), _status.get_packet_port())
		_status.put_packet(JSON.stringify(info).to_utf8_buffer())


func _heartbeat() -> void:
	if api.server_key == "":
		return
	var info := _status_info()
	info.lan = Array(IP.get_local_addresses()).filter(func(a: String) -> bool:
		return a.begins_with("192.168.") or a.begins_with("10.") or (a.begins_with("172.") and not a.begins_with("172.17.")))
	info.public = config.value("server", "public", false)
	info.characters = peers.values().filter(func(p: Dictionary) -> bool: return p.joined and not p.dead).map(
			func(p: Dictionary) -> int: return p.character_id)
	var r := await api.call_api("POST", "/server/heartbeat", info)
	if not r.ok and not has_meta(&"warned_heartbeat"):
		set_meta(&"warned_heartbeat", true)
		push_warning("Account service heartbeat failed: %s" % r.error)
	elif r.ok and has_meta(&"warned_heartbeat"):
		remove_meta(&"warned_heartbeat")


## Only metadata issued for an actual enemy shot may grant an online impact effect.
## Follows the game's existing client-hit/server-resolution combat model.
func _authorize_status_shots(attack: Dictionary, realm_id: String, origin: Vector3, source: String, path := "", inherited_life := 0.0, inherited_reach := 0.0) -> Dictionary:
	var tokens := {}
	var reach := maxf(0.0,float(attack.get("range",10.0)))+inherited_reach
	var life := float(attack.get("range",10.0))/maxf(.1,float(attack.get("speed",10.0)))+inherited_life+3.0
	if attack.get("effects",[]) is Array and not attack.get("effects",[]).is_empty():
		var token := _next_status_shot
		_next_status_shot += 1
		_status_shots[token] = {realm=realm_id,origin=origin,reach=reach+6.0,expires=Net.now()+life,
			effects=attack.effects.duplicate(true),source=str(attack.get("effect_source",source)),hits={},
			returns=float(attack.get("returns",0.0))>0.0}
		tokens[path] = token
	if attack.has("terminal") and attack.terminal is Dictionary and attack.terminal.get("attack") is Dictionary:
		tokens.merge(_authorize_status_shots(attack.terminal.attack,realm_id,origin,source,path+"t",life+float(attack.terminal.get("delay",.4)),reach))
	return tokens

func _status_hit(p: Dictionary, token: int) -> void:
	var shot: Dictionary = _status_shots.get(token,{})
	if shot.is_empty() or p.realm!=shot.realm or Net.now()>float(shot.expires): return
	if GameServer.intro_protected(p.player_id) or p.pos.distance_to(shot.origin)>float(shot.reach): return
	var hits: Array = shot.hits.get(p.player_id,[])
	if hits.size()>=(2 if shot.returns else 1): return
	if not hits.is_empty() and Net.now()-float(hits.back())<EnemyBullets.RETURN_REHIT: return
	hits.append(Net.now())
	shot.hits[p.player_id] = hits
	GameServer.apply_effects(p.player_id,shot.effects,shot.source)
