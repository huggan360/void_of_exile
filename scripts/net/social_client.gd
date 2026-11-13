class_name SocialClient
extends Node
## This game's side of chat, the party and campaigns (Main.social): what the
## server last said (see SocialServer and CampaignServer), and the requests
## that go back. The chat window, the friends and party panel, the quest
## banner and CampaignClient all read from here.

## The Theory of Everything is told: the Surface launch pad opens.
signal space_unlocked
signal line_added(line: Dictionary)
signal join_requested(target: Dictionary)
signal party_changed
signal invited(leader: String)
signal campaigns_listed(runs: Dictionary)
signal goto(place: String, pos: Vector3)
signal intro(script: Dictionary)
signal campaign_done(result: Dictionary)
signal pack_done(bonus: Dictionary)
signal fog(realm_id: String, cells: Array)
signal warp(pos: Vector3)
signal scene(ev: Array)  # ["camp_scene", ...], ["camp_scene_page", n], ["camp_scene_end"], ["camp_answer", ...]

## Local manual-play checkpoints can handle campaign actions without an account.
signal local_campaign_requested(args: Array)

const MAX_LINES := 80
## Name colors: you, your party, your friends, everyone else.
const SELF_COLOR := Color("#ffd35a")
const PARTY_COLOR := Color("#c58bff")
const FRIEND_COLOR := Color("#7ee08a")
const OTHER_COLOR := Color("#e8ecf4")

## [{channel, from, from_id, text, to, time}]
var lines: Array[Dictionary] = []
## {} or {id, leader, members: [{player_id, name, leader, place, class_id, level, dead}], campaign}
var party := {}
## Leaders who invited us: [name]
var invites: Array[String] = []
var _invite_until := {}
var my_name := ""
## When the party state last came (seconds), to run the campaign clock between updates.
var party_at := 0.0
var join_target := ""
var _arrived := false
var _arrival_timer := 0.0
var _responding := false


func _ready() -> void:
	Account.changed.connect(func() -> void: my_name = Account.username())
	my_name = Account.username()


func _process(delta: float) -> void:
	_arrival_timer -= delta
	if _arrival_timer > 0.0:
		return
	_arrival_timer = 4.0
	var expired := false
	for leader: String in invites.duplicate():
		if float(_invite_until.get(leader, 0.0)) < Time.get_ticks_msec() / 1000.0:
			invites.erase(leader)
			_invite_until.erase(leader)
			expired = true
	if expired:
		party_changed.emit()
	if _arrived and Net.is_client():
		for invitation: Dictionary in Account.party_invites:
			if bool(invitation.get("accepted", false)):
				Net.client.send_action("party", ["arrived", ""])
				break


## Main calls this once the initial Tavern has finished loading.
func arrived() -> void:
	_arrived = true
	_arrival_timer = 0.0
	if join_target != "":
		teleport(join_target)
		join_target = ""


func join_friend(player_name: String) -> void:
	var target := await Account.join_friend(player_name)
	if target.is_empty():
		return
	if not (target.get("same_server", false) and Net.is_client()):
		join_requested.emit(target)


func respond_invite(id: int, accept: bool) -> void:
	if _responding:
		return
	_responding = true
	var target := await Account.respond_party(id, accept)
	_responding = false
	if not accept or target.is_empty():
		return
	if target.get("same_server", false) and Net.is_client():
		_arrival_timer = 0.0
	else:
		target.party_invite = true
		join_requested.emit(target)


## Hooks up to a new connection.
func attach(client: NetClient) -> void:
	_arrived = false
	client.refused.connect(func(_reason: String) -> void: reset())
	client.social_event.connect(_on_event)
	client.welcomed.connect(func(info: Dictionary) -> void: my_name = str(info.get("name", my_name)))


## Back offline: nobody to talk to.
func reset() -> void:
	_arrived = false
	join_target = ""
	party = {}
	invites.clear()
	_invite_until.clear()
	party_changed.emit()


func _on_event(ev: Array) -> void:
	match str(ev[0]):
		"chat":
			add_line(str(ev[1]), str(ev[2]), int(ev[3]), str(ev[4]), str(ev[5]))
		"party":
			party = ev[1]
			party_at = Time.get_ticks_msec() / 1000.0
			if not party.is_empty():
				invites.erase(str(party.leader))
			party_changed.emit()
		"invite":
			_invite_until[str(ev[2])] = Time.get_ticks_msec() / 1000.0 + SocialServer.INVITE_TIME
			if not str(ev[2]) in invites:
				invites.append(str(ev[2]))
			GameAudio.play("party_invite")
			invited.emit(str(ev[2]))
			party_changed.emit()
		"goto": goto.emit(str(ev[1]), ev[2] if ev[2] is Vector3 else Vector3.INF)
		"fog": fog.emit(str(ev[1]), ev[2])
		"camp_list": campaigns_listed.emit(ev[1])
		"camp_intro": intro.emit(ev[1])
		"camp_done": campaign_done.emit(ev[1])
		"dots":
			if int(ev[2])>0 and str(ev[3])=="forge": GameAudio.play("forge_dismantle")
			if int(ev[2])<0 and str(ev[3])=="shop": GameAudio.play("buy", Vector3.INF, {cooldown = 0.1})
			Account.set_dots(int(ev[1]), int(ev[2]), str(ev[3]))
		"camp_pack_done": pack_done.emit(ev[1])
		"space_unlocked":  # the Theory of Everything is told: Space is open
			get_tree().call_group("surface_ports", "set_state", true, false)
			space_unlocked.emit()
		"port":  # the Skyward Launch Pad's answers (SurfaceLaunchpad)
			get_tree().call_group("surface_ports", "on_port_event", ev)
		"fleet": get_tree().call_group("fleet_panels", "receive", ev[1])
		"shops":
			if ev[1] is Dictionary: Shops.set_state(ev[1])
		"warp": warp.emit(ev[1])
		"camp_scene", "camp_scene_page", "camp_scene_end", "camp_answer": scene.emit(ev)


func add_line(channel: String, from: String, from_id: int, text: String, to := "") -> void:
	var line := {channel = channel, from = from, from_id = from_id, text = text, to = to, time = Time.get_ticks_msec() / 1000.0}
	lines.append(line)
	if lines.size() > MAX_LINES:
		lines.pop_front()
	line_added.emit(line)


# --- Requests -----------------------------------------------------------------------

func send_chat(text: String) -> void:
	var parts := text.strip_edges().split(" ", false, 2)
	if not parts.is_empty() and parts[0].to_lower() in ["/accept", "/decline"]:
		party_op(parts[0].trim_prefix("/").to_lower(), str(parts[1]) if parts.size() > 1 else "")
		return
	if parts.size() >= 2 and parts[0].to_lower() in ["/party", "/p"] and parts[1].to_lower() in ["accept", "decline"]:
		party_op(parts[1].to_lower(), str(parts[2]) if parts.size() > 2 else "")
		return
	if Net.is_client():
		Net.client.send_action("chat", [text])
	else:
		add_line("system", "", 0, "Chat needs a server: play Singleplayer or join one.")


func party_op(op: String, player_name := "") -> void:
	if op in ["accept", "decline"]:
		for invitation: Dictionary in Account.party_invites:
			if player_name == "" or str(invitation.username).nocasecmp_to(player_name) == 0:
				respond_invite(int(invitation.id), op == "accept")
				return
		if op == "decline":
			if player_name == "":
				invites.clear()
				_invite_until.clear()
			else:
				invites.erase(player_name)
				_invite_until.erase(player_name)
			party_changed.emit()
	if Net.is_client():
		Net.client.send_action("party", [op, player_name])


func teleport(player_name: String) -> void:
	if Net.is_client():
		Net.client.send_action("tp", [player_name])


func campaign(args: Array) -> void:
	if Net.is_client():
		Net.client.send_action("camp", args)
	else:
		local_campaign_requested.emit(args)


func quest(objective: String) -> void:
	campaign(["quest", objective])


# --- Who is who ------------------------------------------------------------------------

func in_party(player_name: String) -> bool:
	for m: Dictionary in party.get("members", []):
		if str(m.name).to_lower() == player_name.to_lower():
			return true
	return false


func is_leader() -> bool:
	return party.is_empty() or str(party.leader).to_lower() == my_name.to_lower()


func campaign_state() -> Dictionary:
	return party.get("campaign", {})


## The campaign's time played, counting on since the last update.
func campaign_elapsed() -> float:
	var camp := campaign_state()
	if camp.is_empty():
		return 0.0
	var since := Time.get_ticks_msec() / 1000.0 - party_at if camp.get("status", "") == "active" else 0.0
	return float(camp.elapsed) + since


func name_color(player_name: String) -> Color:
	if player_name.to_lower() == my_name.to_lower():
		return SELF_COLOR
	if in_party(player_name):
		return PARTY_COLOR
	if Account.has_method("is_friend") and Account.is_friend(player_name):
		return FRIEND_COLOR
	return OTHER_COLOR
