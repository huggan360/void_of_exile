class_name ServerBrowser
extends Node
## Finds game servers for the server list, three ways:
##   * the account service lists the servers that announced themselves from
##     the same public IP as you (your own network), with their LAN
##     addresses, plus servers that chose to be public
##   * servers on the local network announce themselves (UDP broadcast on
##     Net.LAN_BEACON_PORT)
##   * addresses you added yourself (like Minecraft: just the IP, or IP:port)
## Each one is pinged every couple of seconds on its status port (game port
## + 1) for its name, how many players are on, and the round trip time.

signal changed

const PING_EVERY := 2.0
const FORGET_AFTER := 12.0  # seconds without an answer before a found server is dropped
const PROFILE := "user://servers.cfg"  # servers you added

## "address:port" -> {name, address, port, candidates: Array[String], players,
## max_players, ping_ms (-1 = no answer yet), source, seen, manual}
var servers := {}
var profile := ConfigFile.new()

var _ping := PacketPeerUDP.new()
var _lan := PacketPeerUDP.new()
var _lan_ok := false
var _timer := 0.0
var _sent := {}  # nonce -> [key, address, sent at]
var _nonce := 0


func _ready() -> void:
	profile.load(PROFILE)
	_ping.bind(0)
	_lan_ok = _lan.bind(Net.LAN_BEACON_PORT) == OK
	for entry: String in profile.get_value("servers", "manual", []):
		_add_manual(entry, false)


func _exit_tree() -> void:
	_ping.close()
	_lan.close()


## Adds a server by address ("192.168.1.20" or "host:port"). Returns its key.
func add_manual(text: String) -> String:
	var key := _add_manual(text, true)
	_ping_all()
	return key


func remove(key: String) -> void:
	servers.erase(key)
	var manual: Array = profile.get_value("servers", "manual", [])
	manual.erase(key)
	profile.set_value("servers", "manual", manual)
	profile.save(PROFILE)
	changed.emit()


func _add_manual(text: String, store: bool) -> String:
	var t := text.strip_edges()
	if t == "":
		return ""
	var host := t
	var port := Net.DEFAULT_PORT
	var colon := t.rfind(":")
	if colon > 0 and t.count(":") == 1:
		host = t.substr(0, colon)
		port = int(t.substr(colon + 1))
	var key := "%s:%d" % [host, port]
	if not servers.has(key):
		servers[key] = {name = host, address = host, port = port, candidates = [host], players = 0, max_players = 0,
			ping_ms = -1, source = "manual", seen = Time.get_ticks_msec(), manual = true}
	servers[key].manual = true
	if store:
		var manual: Array = profile.get_value("servers", "manual", [])
		if not key in manual:
			manual.append(key)
		profile.set_value("servers", "manual", manual)
		profile.save(PROFILE)
	changed.emit()
	return key


## Asks the account service for the servers on your network.
func refresh() -> void:
	_ping_all()
	if Account.token() == "":
		return
	var r := await Account.api.call_api("GET", "/servers")
	if not r.ok:
		return
	for s: Dictionary in r.data.get("servers", []):
		var port := int(s.get("port", Net.DEFAULT_PORT))
		var candidates: Array = []
		if s.get("same_network", false):
			candidates.append_array(s.get("lan", []))  # inside the network, the LAN address works
		candidates.append(str(s.address))
		var key := "%s:%d" % [str(s.address), port]
		for other in servers.keys():  # found on the LAN first: the same server
			if servers[other].source == "lan" and servers[other].port == port and servers[other].address in candidates:
				servers.erase(other)
		var entry: Dictionary = servers.get(key, {ping_ms = -1, manual = false})
		entry.merge({name = str(s.name), address = entry.get("address", candidates[0]), port = port,
			candidates = candidates, players = int(s.players), max_players = int(s.max_players),
			source = "account", seen = Time.get_ticks_msec()}, true)
		servers[key] = entry
	changed.emit()
	_ping_all()


func _process(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		_timer = PING_EVERY
		_ping_all()
		_forget_stale()
	var dirty := false
	while _ping.get_available_packet_count() > 0:
		var data: Variant = JSON.parse_string(_ping.get_packet().get_string_from_utf8())
		var from := _ping.get_packet_ip()
		if data is Dictionary and _sent.has(str(data.get("nonce", ""))):
			var sent: Array = _sent[str(data.nonce)]
			_sent.erase(str(data.nonce))
			if servers.has(sent[0]):
				var s: Dictionary = servers[sent[0]]
				var ms := (Time.get_ticks_usec() - int(sent[2])) / 1000.0
				s.ping_ms = ms if s.ping_ms < 0 else lerpf(s.ping_ms, ms, 0.5)
				s.address = sent[1] if sent[1] != "" else from
				s.name = str(data.get("name", s.name))
				s.players = int(data.get("players", 0))
				s.max_players = int(data.get("max_players", 0))
				s.protocol = int(data.get("protocol", 0))
				s.seen = Time.get_ticks_msec()
				dirty = true
	while _lan_ok and _lan.get_available_packet_count() > 0:
		var data: Variant = JSON.parse_string(_lan.get_packet().get_string_from_utf8())
		var from := _lan.get_packet_ip()
		if data is Dictionary and data.get("game", "") == "voidrealms":
			var port := int(data.get("port", Net.DEFAULT_PORT))
			var known := servers.values().any(func(s: Dictionary) -> bool:
				return s.port == port and (s.address == from or from in s.candidates))
			if not known:
				servers["%s:%d" % [from, port]] = {name = str(data.get("name", from)), address = from, port = port,
					candidates = [from], players = int(data.get("players", 0)),
					max_players = int(data.get("max_players", 0)), ping_ms = -1, source = "lan",
					seen = Time.get_ticks_msec(), manual = false}
				dirty = true
				_ping_all()
	if dirty:
		changed.emit()


func _ping_all() -> void:
	for key: String in servers:
		var s: Dictionary = servers[key]
		var targets: Array = s.candidates if s.ping_ms < 0 else [s.address]
		for address: String in targets:
			var ip := address if address.is_valid_ip_address() else IP.resolve_hostname(address, IP.TYPE_IPV4)
			if ip == "":
				continue
			_nonce += 1
			_sent[str(_nonce)] = [key, address, Time.get_ticks_usec()]
			_ping.set_dest_address(ip, int(s.port) + Net.STATUS_PORT_OFFSET)
			_ping.put_packet(("VRPING %d" % _nonce).to_utf8_buffer())
	if _sent.size() > 512:
		_sent.clear()


func _forget_stale() -> void:
	var now := Time.get_ticks_msec()
	var dirty := false
	for key in servers.keys():
		var s: Dictionary = servers[key]
		if now - int(s.seen) > FORGET_AFTER * 1000.0:
			if s.manual:
				if s.ping_ms >= 0:
					s.ping_ms = -1  # still listed, shown as unreachable
					dirty = true
			else:
				servers.erase(key)
				dirty = true
	if dirty:
		changed.emit()
