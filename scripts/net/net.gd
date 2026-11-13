extends Node
## The network layer (autoloaded as Net). The game runs in one of three modes:
##
##   OFFLINE  the single-player sandbox (Play on the start screen): GameServer
##            and WorldServer run inside the game, as before.
##   SERVER   the dedicated server (scenes/server/dedicated.tscn, headless).
##            It owns everything: characters (loaded from and saved to the
##            account service), realms, enemies and their AI, loot, XP. See
##            NetServer.
##   CLIENT   a game connected to a server. See NetClient.
##
## How a fight works online (Realm of the Mad God style):
##   * Your own movement is yours: the client moves at once (no waiting for
##     the server) and reports where it is; the server only checks it's a
##     believable move and pulls you back if not.
##   * Enemies live on the server. Clients see them through snapshots (where
##     each one is, ~20 per second) and events (it fired, flinched, burst,
##     a hazard appeared...), all stamped with server time. A client shows
##     the world a fixed moment in the past (INTERP_DELAY) so it can move
##     everything smoothly between snapshots, and plays each event at its
##     stamp, so a shot leaves the enemy exactly as you see it fire.
##   * Enemy shots, ripples and boss hazards fly on every client; each client
##     decides whether its own player was hit (you can't be hit by a shot you
##     dodged on your screen) and reports it. The server applies the damage
##     and decides about death.
##   * Your shots fly on your client too; when one hits an enemy you report
##     it and the server checks it's possible before applying it. Other
##     players see your shots as harmless copies.
##
## All RPCs live here, so they have the same path on both ends (/root/Net).

enum Mode { OFFLINE, CLIENT, SERVER }

const PROTOCOL := 7
const VERSION := "0.15.0"
const DEFAULT_PORT := 24565
## UDP status queries (server list pings) go to the game port + this.
const STATUS_PORT_OFFSET := 1
## Servers announce themselves on the local network on this port.
const LAN_BEACON_PORT := 24564
## Clients show the world this far in the past, to move smoothly between
## snapshots and play events in step with them.
const INTERP_DELAY := 0.12
## Voxel bursts sent to clients are thinned to at most this many points.
const MAX_FX_POINTS := 260
const ENEMY_STRIDE := 13  # floats per enemy in a snapshot (see Enemy.net_state)
const PLAYER_STRIDE := 7  # floats per player in a snapshot

var mode := Mode.OFFLINE
var server: NetServer
var client: NetClient


func is_server() -> bool:
	return mode == Mode.SERVER


func is_client() -> bool:
	return mode == Mode.CLIENT


func is_online() -> bool:
	return mode != Mode.OFFLINE


func now() -> float:
	return Time.get_ticks_usec() / 1_000_000.0


## Starts the dedicated server.
func host(config: ServerConfig) -> Error:
	server = NetServer.new()
	server.name = "Server"
	mode = Mode.SERVER
	add_child(server)
	return server.start(config)


## Connects to a server. The client reports how it went through its signals.
func join(address: String, port: int, token: String, character_id: int, account_name: String) -> NetClient:
	leave()
	client = NetClient.new()
	client.name = "Client"
	mode = Mode.CLIENT
	add_child(client)
	client.start(address, port, token, character_id, account_name)
	return client


## Back to offline.
func leave() -> void:
	Leisure.reset()
	if client:
		client.stop()
		client.queue_free()
		client = null
	multiplayer.multiplayer_peer = null
	mode = Mode.OFFLINE


## Thins a voxel burst to MAX_FX_POINTS (evenly), for sending.
static func thin_points(points: PackedVector3Array, colors: PackedColorArray) -> Array:
	if points.size() <= MAX_FX_POINTS:
		return [points, colors]
	var p := PackedVector3Array()
	var c := PackedColorArray()
	for i in MAX_FX_POINTS:
		var k := i * points.size() / MAX_FX_POINTS
		p.append(points[k])
		c.append(colors[mini(k, colors.size() - 1)])
	return [p, c]


## The realm a node lives in (the world it was added to), or "".
static func realm_of(node: Node) -> String:
	while node != null:
		if node.has_meta(&"net_realm"):
			return node.get_meta(&"net_realm")
		node = node.get_parent()
	return ""


## Items for the wire: [{id, count} or null].
static func encode_items(items: Array) -> Array:
	return items.map(func(i: Variant) -> Variant: return {id = i.id, count = i.count} if i != null else null)


static func decode_items(items: Array) -> Array:
	return items.map(func(d: Variant) -> Variant:
		if not d is Dictionary or not Items.exists(str(d.get("id", ""))):
			return null
		var item := Items.make(str(d.id))
		item.count = int(d.get("count", 1))
		return item)


# --- Client -> server --------------------------------------------------------------

@rpc("any_peer", "call_remote", "reliable")
func s_hello(protocol: int, token: String, character_id: int, account_name: String) -> void:
	if server:
		server.on_hello(multiplayer.get_remote_sender_id(), protocol, token, character_id, account_name)


@rpc("any_peer", "call_remote", "reliable")
func s_enter(destination: String) -> void:
	if server:
		server.on_enter(multiplayer.get_remote_sender_id(), destination)


@rpc("any_peer", "call_remote", "unreliable_ordered", 1)
func s_move(pos: Vector3, facing: float, speed: float, flags: int) -> void:
	if server:
		server.on_move(multiplayer.get_remote_sender_id(), pos, facing, speed, flags)


## Everything else a player does: [kind, args] (see NetServer.on_action).
@rpc("any_peer", "call_remote", "reliable")
func s_action(kind: String, args: Array) -> void:
	if server:
		server.on_action(multiplayer.get_remote_sender_id(), kind, args)


@rpc("any_peer", "call_remote", "unreliable", 2)
func s_shot(origin: Vector3, direction: Vector3, weapon_id: String, phase: float, mods: Dictionary) -> void:
	if server:
		server.on_shot(multiplayer.get_remote_sender_id(), origin, direction, weapon_id, phase, mods)


@rpc("any_peer", "call_remote", "unreliable")
func s_pong(t: float) -> void:
	if server:
		server.on_pong(multiplayer.get_remote_sender_id(), t)


# --- Server -> client --------------------------------------------------------------

@rpc("authority", "call_remote", "reliable")
func c_welcome(info: Dictionary) -> void:
	if client:
		client.on_welcome(info)


@rpc("authority", "call_remote", "reliable")
func c_refused(reason: String) -> void:
	if client:
		client.on_refused(reason)


@rpc("authority", "call_remote", "reliable")
func c_entered(record: Dictionary) -> void:
	if client:
		client.on_entered(record)


@rpc("authority", "call_remote", "unreliable_ordered", 1)
func c_snapshot(t: float, enemies: PackedFloat32Array, bosses: Array, players: PackedFloat32Array, me: Array) -> void:
	if client:
		client.on_snapshot(t, enemies, bosses, players, me)


## Large boss visual state (Prism beams, guardians) needs reliable fragmentation.
@rpc("authority", "call_remote", "reliable", 2)
func c_boss_snapshot(t: float, bosses: Array) -> void:
	if client:
		client.on_snapshot(t, PackedFloat32Array(), bosses, PackedFloat32Array(), [])


@rpc("authority", "call_remote", "reliable")
func c_events(events: Array) -> void:
	if client:
		client.on_events(events)


@rpc("authority", "call_remote", "reliable")
func c_character(data: Dictionary) -> void:
	if client:
		client.on_character(data)


@rpc("authority", "call_remote", "reliable")
func c_died(info: Dictionary) -> void:
	if client:
		client.on_died(info)


@rpc("authority", "call_remote", "reliable")
func c_correct(pos: Vector3) -> void:
	if client:
		client.on_correct(pos)


## Chat, party, campaign and teleport events (see SocialServer), right away
## rather than on the snapshot clock.
@rpc("authority", "call_remote", "reliable")
func c_social(ev: Array) -> void:
	if client:
		client.social_event.emit(ev)


@rpc("authority", "call_remote", "unreliable")
func c_ping(t: float, rtt: float) -> void:
	if client:
		client.on_ping(t, rtt)

## Small independent cloth/rope snapshots must never hold up reliable combat.
@rpc("authority", "call_remote", "unreliable", 3)
func c_theory_detail(realm: String, stamp: float, id: int, points: PackedByteArray) -> void:
	if client and client.world is TheoryWorld and client.world.realm_id==realm:
		var place := client.world as TheoryWorld
		if is_instance_valid(place.soft_details): place.soft_details.receive(id,stamp,points)
