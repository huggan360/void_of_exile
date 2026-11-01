class_name SocialServer
extends Node
## Chat, parties, teleports and shared fog on the dedicated server
## (Net.server.social). Everything goes to clients as Net.c_social events:
##
##   ["chat", channel, from name, from player id, text, to name]
##       channels: "say" (everyone in the same place), "tell" (private),
##       "party", "system" (only you), "announce" (everyone in a place)
##   ["party", state]      your party ({} when you're in none), see _state()
##   ["invite", party id, leader name]
##   ["goto", place, position]  travel there (teleports, being sent home)
##   ["fog", realm id, cells]   explored cells shared by your party
##
## Commands typed in chat: /t or /tell <name> <text>, /p <text> (party),
## /invite <name>, /accept, /decline, /leave, /kick <name>, /lead <name>,
## /tp <name>, /who, /help.
## Parties live on this server; a departing leader hands the lead to the next member.

const MAX_PARTY := 6
const CHAT_MAX := 180
const CHAT_BURST := 6  # messages allowed in CHAT_WINDOW seconds
const CHAT_WINDOW := 6.0
const INVITE_TIME := 90.0
const FOG_CELL := 4.0  # blocks per shared fog cell
const FOG_INTERVAL := 0.5
const FOG_SAVE_INTERVAL := 10.0
const HELP := "Commands: /t <name> <text> (private), /p <text> (party), /invite <name>, /accept, /decline, /leave, /kick <name>, /lead <name>, /tp <name>, /who"

var server: NetServer
var parties := {}  # party id -> {id, leader: player id, members: [player ids], invites: {player id: expires}, campaign}
var party_of := {}  # player id -> party id
var _next_party := 1
var _sent_at := {}  # player id -> [times of recent messages]
var _fog := {}  # fog key -> {cells: {int: true}, realm, dirty}
var _fog_timer := 0.0
var _fog_save_timer := 0.0
var _state_timer := 0.0


func _process(delta: float) -> void:
	_fog_timer -= delta
	if _fog_timer <= 0.0:
		_fog_timer = FOG_INTERVAL
		_share_fog()
	_fog_save_timer -= delta
	if _fog_save_timer <= 0.0:
		_fog_save_timer = FOG_SAVE_INTERVAL
		save_fog()
	_state_timer -= delta
	if _state_timer <= 0.0:
		_state_timer = 3.0  # where everyone is, their levels...
		for party: Dictionary in parties.values():
			broadcast(party)


# --- Sending -------------------------------------------------------------------------

func send(player_id: int, ev: Array) -> void:
	var peer_id: int = server.by_player.get(player_id, 0)
	if peer_id != 0 and server.peers.has(peer_id):
		Net.c_social.rpc_id(peer_id, ev)


func system(player_id: int, text: String) -> void:
	send(player_id, ["chat", "system", "", 0, text, ""])


## A line for everyone in a place (a gate opens, a boss falls...).
func announce(realm_id: String, text: String) -> void:
	for p: Dictionary in server.peers.values():
		if p.joined and p.realm == realm_id:
			send(p.player_id, ["chat", "announce", "", 0, text, ""])


func record(player_id: int) -> Dictionary:
	return server.peers.get(server.by_player.get(player_id, 0), {})


func find(player_name: String) -> Dictionary:
	var want := player_name.strip_edges().to_lower()
	for p: Dictionary in server.peers.values():
		if p.joined and str(p.name).to_lower() == want:
			return p
	return {}


# --- Chat ----------------------------------------------------------------------------

func on_chat(p: Dictionary, text: String) -> void:
	text = text.strip_edges().replace("\n", " ").left(CHAT_MAX)
	if text == "":
		return
	var now := Net.now()
	var times: Array = _sent_at.get(p.player_id, []).filter(func(t: float) -> bool: return now - t < CHAT_WINDOW)
	if times.size() >= CHAT_BURST:
		system(p.player_id, "Slow down a little.")
		return
	times.append(now)
	_sent_at[p.player_id] = times
	if text.begins_with("/"):
		_command(p, text)
		return
	for o: Dictionary in server.peers.values():
		if o.joined and o.realm == p.realm:
			send(o.player_id, ["chat", "say", p.name, p.player_id, text, ""])


func _command(p: Dictionary, text: String) -> void:
	var parts := text.split(" ", false, 2)
	var word := parts[0].to_lower()
	var arg: String = parts[1] if parts.size() > 1 else ""
	var rest: String = parts[2] if parts.size() > 2 else ""
	match word:
		"/t", "/tell", "/w", "/whisper", "/msg":
			_tell(p, arg, rest)
		"/p", "/party":
			var sub := arg.to_lower()
			if sub in ["invite", "accept", "decline", "leave", "kick", "lead"]:
				_command(p, "/%s %s" % [sub, rest])
			elif arg == "":
				system(p.player_id, "Write /p and your message to talk to your party.")
			else:
				party_chat(p, (arg + " " + rest).strip_edges())
		"/invite": invite(p, arg)
		"/accept": accept(p, arg)
		"/decline": decline(p)
		"/leave": leave(p)
		"/kick": kick(p, arg)
		"/lead": promote(p, arg)
		"/tp", "/teleport": teleport(p, arg)
		"/who":
			var here := server.peers.values().filter(func(o: Dictionary) -> bool: return o.joined and o.realm == p.realm)
			system(p.player_id, "%d here (%s), %d on this server." % [here.size(),
					", ".join(here.map(func(o: Dictionary) -> String: return str(o.name)).slice(0, 12)), server.player_count()])
		"/help", "/?": system(p.player_id, HELP)
		_: system(p.player_id, "Unknown command %s. %s" % [word, HELP])


func _tell(p: Dictionary, to_name: String, text: String) -> void:
	var o := find(to_name)
	if to_name == "" or text.strip_edges() == "":
		system(p.player_id, "Write /t <name> <message>.")
	elif o.is_empty():
		system(p.player_id, "%s isn't on this server." % to_name)
	elif o == p:
		system(p.player_id, "Talking to yourself?")
	else:
		var line := ["chat", "tell", p.name, p.player_id, text, o.name]
		send(o.player_id, line)
		send(p.player_id, line)


func party_chat(p: Dictionary, text: String) -> void:
	var party: Dictionary = parties.get(party_of.get(p.player_id, 0), {})
	if party.is_empty():
		system(p.player_id, "You're not in a party. Invite someone with /invite <name>.")
		return
	for pid: int in party.members:
		send(pid, ["chat", "party", p.name, p.player_id, text, ""])


# --- Parties -------------------------------------------------------------------------

func party_for(player_id: int) -> Dictionary:
	return parties.get(party_of.get(player_id, 0), {})


func is_leader(player_id: int) -> bool:
	var party := party_for(player_id)
	return not party.is_empty() and party.leader == player_id


## A new party with `p` as its leader (when they have none).
func ensure_party(p: Dictionary) -> Dictionary:
	var party := party_for(p.player_id)
	if not party.is_empty():
		return party
	party = {id = _next_party, leader = p.player_id, members = [p.player_id], invites = {}, campaign = {}}
	_next_party += 1
	parties[party.id] = party
	party_of[p.player_id] = party.id
	broadcast(party)
	return party


func invite(p: Dictionary, to_name: String) -> void:
	var o := find(to_name)
	if o.is_empty():
		system(p.player_id, "%s isn't on this server." % to_name if to_name != "" else "Write /invite <name>.")
		return
	if o == p:
		return
	var party := party_for(p.player_id)
	if not party.is_empty() and party.leader != p.player_id:
		system(p.player_id, "Only the party leader can invite.")
		return
	if not party.is_empty() and o.player_id in party.members:
		system(p.player_id, "%s is already in your party." % o.name)
		return
	party = ensure_party(p)
	if party.members.size() >= MAX_PARTY:
		system(p.player_id, "Your party is full (%d)." % MAX_PARTY)
		return
	party.invites[o.player_id] = Net.now() + INVITE_TIME
	send(o.player_id, ["invite", party.id, p.name])
	system(o.player_id, "%s invited you to their party. Type /accept, or open Party." % p.name)
	system(p.player_id, "You invited %s." % o.name)


func accept(p: Dictionary, leader_name := "") -> void:
	var chosen := {}
	for party: Dictionary in parties.values():
		if float(party.invites.get(p.player_id, 0.0)) < Net.now():
			continue
		if leader_name == "" or str(record(party.leader).get("name", "")).to_lower() == leader_name.strip_edges().to_lower():
			chosen = party
	if chosen.is_empty():
		system(p.player_id, "You have no party invitation.")
		return
	if chosen.members.size() >= MAX_PARTY:
		system(p.player_id, "That party is full.")
		return
	if party_of.has(p.player_id):
		leave(p, true)
	# Your own campaign pauses (saved) while you play someone else's.
	server.campaigns.pause_owner(p.account_id)
	chosen.invites.erase(p.player_id)
	chosen.members.append(p.player_id)
	party_of[p.player_id] = chosen.id
	for pid: int in chosen.members:
		system(pid, "%s joined the party." % p.name)
	broadcast(chosen)
	server.campaigns.joined_party(p, chosen)


func decline(p: Dictionary) -> void:
	for party: Dictionary in parties.values():
		if party.invites.has(p.player_id):
			party.invites.erase(p.player_id)
			system(party.leader, "%s declined your invitation." % p.name)


func leave(p: Dictionary, quiet := false) -> void:
	var party := party_for(p.player_id)
	if party.is_empty():
		if not quiet:
			system(p.player_id, "You're not in a party.")
		return
	if party.leader == p.player_id:
		if party.members.size() <= 1:
			disband(party, "%s broke up the party." % p.name)
			return
		_hand_over_lead(party, p.player_id)
	_remove(party, p.player_id)
	send(p.player_id, ["party", {}])
	server.campaigns.left_party(p, party)
	for pid: int in party.members:
		system(pid, "%s left the party." % p.name)
	broadcast(party)


func kick(p: Dictionary, who: String) -> void:
	var party := party_for(p.player_id)
	var o := find(who)
	if party.is_empty() or party.leader != p.player_id:
		system(p.player_id, "Only the party leader can kick.")
	elif o.is_empty() or not o.player_id in party.members or o == p:
		system(p.player_id, "%s isn't in your party." % who)
	else:
		_remove(party, o.player_id)
		send(o.player_id, ["party", {}])
		system(o.player_id, "You were removed from the party.")
		server.campaigns.left_party(o, party)
		for pid: int in party.members:
			system(pid, "%s was removed from the party." % o.name)
		broadcast(party)


## Hands the lead to another member (the campaign stays the old leader's).
func promote(p: Dictionary, who: String) -> void:
	var party := party_for(p.player_id)
	var o := find(who)
	if party.is_empty() or party.leader != p.player_id:
		system(p.player_id, "Only the party leader can do that.")
	elif o.is_empty() or not o.player_id in party.members:
		system(p.player_id, "%s isn't in your party." % who)
	else:
		party.leader = o.player_id
		for pid: int in party.members:
			system(pid, "%s now leads the party." % o.name)
		broadcast(party)


## The party breaks up: everyone in its campaign realm goes home.
func disband(party: Dictionary, reason: String) -> void:
	server.campaigns.party_disbanded(party)
	for pid: int in party.members:
		party_of.erase(pid)
		send(pid, ["party", {}])
		system(pid, reason)
	parties.erase(party.id)


func _remove(party: Dictionary, player_id: int) -> void:
	party.members.erase(player_id)
	party_of.erase(player_id)
	if party.members.size() <= 1 and party.campaign.is_empty():
		disband(party, "The party broke up.")


## A player left the game. If they led, the next member leads on: the party
## and its campaign go on uninterrupted (the campaign stays the first
## leader's, and keeps being saved to their book).
func on_left(p: Dictionary) -> void:
	_sent_at.erase(p.player_id)
	var party := party_for(p.player_id)
	if party.is_empty():
		return
	if party.leader == p.player_id:
		if party.members.size() <= 1:
			disband(party, "")
			return
		_hand_over_lead(party, p.player_id)
	server.campaigns._keep_items(party)
	_remove(party, p.player_id)
	server.campaigns.member_left(party, p.player_id)
	for pid: int in party.members:
		system(pid, "%s left the game." % p.name)
	broadcast(party)


func _hand_over_lead(party: Dictionary, leaving: int) -> void:
	for pid: int in party.members:
		if pid != leaving:
			party.leader = pid
			for other: int in party.members:
				system(other, "%s now leads the party." % record(pid).get("name", "?"))
			return


func broadcast(party: Dictionary) -> void:
	if not parties.has(party.id):
		return
	var state := _state(party)
	for pid: int in party.members:
		send(pid, ["party", state])


## What members see: {id, leader, members: [{player_id, name, leader, place,
## class_id, level, dead}], campaign (see CampaignServer.summary)}.
func _state(party: Dictionary) -> Dictionary:
	var members := []
	for pid: int in party.members:
		var p := record(pid)
		var stats := GameServer.character(pid)
		members.append({player_id = pid, name = p.get("name", "?"), leader = pid == party.leader,
			place = _place_name(str(p.get("realm", ""))), class_id = stats.class_id if stats else "",
			level = stats.level if stats else 0, dead = p.get("dead", false)})
	return {id = party.id, leader = record(party.leader).get("name", ""), members = members,
		campaign = server.campaigns.summary(party)}


func _place_name(realm_id: String) -> String:
	if realm_id == "hall":
		return "Tavern"
	if Campaigns.is_tavern(realm_id):
		return "Campaign Tavern"
	if Campaigns.is_campaign_realm(realm_id):
		return "Campaign"
	var realm: RealmInstance = server.realms.get(realm_id)
	return str(realm.record.get("name", realm_id)) if realm else ""


# --- Teleports -----------------------------------------------------------------------

## To another player: the Tavern and public realms are open to anyone, a
## campaign realm only to its party.
func teleport(p: Dictionary, to_name: String) -> void:
	var o := find(to_name)
	if o.is_empty():
		system(p.player_id, "%s isn't on this server." % to_name if to_name != "" else "Write /tp <name>.")
	elif o == p or o.realm == "" or o.dead:
		system(p.player_id, "You can't go to %s right now." % o.name)
	elif Campaigns.is_campaign_realm(o.realm) and party_of.get(o.player_id, -1) != party_of.get(p.player_id, -2):
		system(p.player_id, "%s is in a private campaign." % o.name)
	elif p.dead:
		return
	else:
		send(p.player_id, ["goto", o.realm, o.pos])


## Sends a player somewhere (their game travels there).
func send_to(player_id: int, place: String, pos := Vector3.INF) -> void:
	send(player_id, ["goto", place, pos])


## Pulls a player to `pos` in `realm_id`: in the same world only the portal
## flash plays (no loading); from elsewhere they travel there.
func warp(player_id: int, realm_id: String, pos: Vector3) -> void:
	var p := record(player_id)
	if p.is_empty() or p.dead:
		return
	if p.realm != realm_id:
		send_to(player_id, realm_id, pos)
		return
	p.pos = pos
	p.grace = NetServer.SNAP_BACK_GRACE * 8.0
	p.moved_at = 0.0
	send(player_id, ["warp", pos])


# --- Shared fog --------------------------------------------------------------------

## Fog is shared in campaign realms (and saved with them), and between party
## members in the public realms (not saved).
func _fog_key(p: Dictionary) -> String:
	if Campaigns.is_campaign_realm(p.realm):
		return p.realm
	if p.realm != "" and not Campaigns.is_tavern(p.realm) and party_of.has(p.player_id):
		return "%s|%d" % [p.realm, party_of[p.player_id]]
	return ""


func _fog_entry(key: String, realm_id: String) -> Dictionary:
	if not _fog.has(key):
		var cells := {}
		if key == realm_id:  # a campaign realm: what was explored before
			var realm: RealmInstance = server.realms.get(realm_id)
			for c in (realm.record.get("fog", []) if realm else []):
				cells[int(c)] = true
		_fog[key] = {cells = cells, realm = realm_id, dirty = false}
	return _fog[key]


static func fog_cell(pos: Vector3) -> int:
	return (floori(pos.x / FOG_CELL) + 4096) * 8192 + floori(pos.z / FOG_CELL) + 4096


static func fog_point(cell: int) -> Vector3:
	return Vector3((cell / 8192 - 4096 + 0.5) * FOG_CELL, 0.0, (cell % 8192 - 4096 + 0.5) * FOG_CELL)


func _share_fog() -> void:
	var fresh := {}  # key -> [cells]
	for p: Dictionary in server.peers.values():
		if not p.joined or p.dead:
			continue
		var key := _fog_key(p)
		if key == "":
			continue
		var entry := _fog_entry(key, p.realm)
		var cell := fog_cell(p.pos)
		if entry.cells.has(cell):
			continue
		entry.cells[cell] = true
		entry.dirty = true
		if not fresh.has(key):
			fresh[key] = []
		fresh[key].append(cell)
	for key: String in fresh:
		var realm_id: String = _fog[key].realm
		for p: Dictionary in server.peers.values():
			if p.joined and p.realm == realm_id and _fog_key(p) == key:
				send(p.player_id, ["fog", realm_id, fresh[key]])


## Everything explored so far, for someone arriving.
func send_fog(p: Dictionary) -> void:
	var key := _fog_key(p)
	if key != "":
		send(p.player_id, ["fog", p.realm, _fog_entry(key, p.realm).cells.keys()])


func save_fog() -> void:
	for key: String in _fog:
		var entry: Dictionary = _fog[key]
		if not entry.dirty or key != entry.realm:
			continue
		entry.dirty = false
		var realm: RealmInstance = server.realms.get(key)
		if realm:
			realm.record.fog = entry.cells.keys()
			WorldServer.save_record(realm.record)


## A campaign realm starts over (a new run): its shared fog too.
func forget_fog(realm_id: String) -> void:
	for key: String in _fog.keys():
		if _fog[key].realm == realm_id:
			_fog.erase(key)
