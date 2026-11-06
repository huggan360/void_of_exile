class_name SocialPanel
extends PanelContainer
## Friends and party, over the chat (bottom left), opened with its two
## buttons.
##   Friends: find players by name and add them; who's online and on which
##            server; whisper, invite to the party, join them across public servers,
##            remove.
##   Party:   invitations to accept, the members (the leader wears a crown),
##            invite by name, leave, kick (leader), and the campaign you play.

const WIDTH := 500.0
const MIN_BODY := 440.0

var social: SocialClient
var chat: ChatPanel
var tab := ""
var _title := Label.new()
var _body := VBoxContainer.new()
var _scroll := ScrollContainer.new()
var _search := LineEdit.new()
var _results: Array = []
var _searching := false


func _ready() -> void:
	custom_minimum_size = Vector2(WIDTH, 0)
	add_theme_stylebox_override("panel", UIStyle.panel_outlined(UIStyle.BEVEL_LIGHT))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	add_child(column)
	var head := HBoxContainer.new()
	column.add_child(head)
	UIStyle.text(_title, UIStyle.SIZE_LARGE, UIStyle.GOLD)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_title)
	var close := _button("×", func() -> void: show_tab(""))
	head.add_child(close)
	_body.add_theme_constant_override("separation", 6)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.custom_maximum_size.y = get_viewport_rect().size.y * 0.65
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.custom_minimum_size.y = MIN_BODY
	_scroll.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_scroll.add_child(_body)
	column.add_child(_scroll)
	_search.placeholder_text = "Find a player by name"
	_search.max_length = 24
	_search.add_theme_font_override("font", UIStyle.font())
	_search.add_theme_font_size_override("font_size", UIStyle.SIZE_SMALL)
	_search.text_submitted.connect(func(_t: String) -> void:
		if tab == "party": _invite_name()
		else: _do_search())
	_search.focus_entered.connect(func() -> void: chat.player.typing = true)
	_search.focus_exited.connect(func() -> void: chat.player.typing = false)
	social.party_changed.connect(_rebuild)
	Account.friends_changed.connect(_rebuild)
	hide()


func show_tab(which: String) -> void:
	tab = "" if which == tab else which
	visible = tab != ""
	if tab != "":
		Account.friends()
	_rebuild()


func _rebuild() -> void:
	if not visible:
		return
	if _search.get_parent():
		_search.get_parent().remove_child(_search)
	for child in _body.get_children():
		child.free()
	if Account.social_error != "":
		_body.add_child(UIStyle.label("Social service unavailable - retrying. " + Account.social_error,
				UIStyle.SIZE_SMALL, UIStyle.TEXT_DIM))
	if tab == "friends":
		_title.text = "Friends"
		_friends()
	else:
		_title.text = "Party"
		_party()
	_fit_body.call_deferred()


func _fit_body() -> void:
	_scroll.custom_minimum_size.y = clampf(_body.get_combined_minimum_size().y, minf(MIN_BODY, get_viewport_rect().size.y * 0.55), get_viewport_rect().size.y * 0.65)
	reset_size()


# --- Friends --------------------------------------------------------------------------

func _friends() -> void:
	_search.placeholder_text = "Find a player by name"
	var row := HBoxContainer.new()
	_search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_search)
	row.add_child(_button("Search", _do_search))
	_body.add_child(row)
	for r: Dictionary in _results:
		var line := _row(str(r.username), "online - " + str(r.server) if r.online else "offline", r.online)
		var pending := Account.friend_requests.any(func(request: Dictionary) -> bool: return str(request.username).nocasecmp_to(str(r.username)) == 0)
		if not pending and not r.get("friend", false) and not Account.is_friend(str(r.username)):
			line.add_child(_button("Request", func() -> void:
				await Account.add_friend(str(r.username))
				_results.erase(r)
				_rebuild()))
		_body.add_child(line)
	if not _results.is_empty():
		_body.add_child(HSeparator.new())
	for request: Dictionary in Account.friend_requests:
		var request_name := str(request.username)
		var outgoing := bool(request.outgoing)
		var line := _row(request_name, "Friend request sent" if outgoing else "Wants to be your friend", false)
		if not outgoing:
			line.add_child(_button("Accept", func() -> void: Account.respond_friend(request_name, true)))
			line.add_child(_button("Decline", func() -> void: Account.respond_friend(request_name, false)))
		else:
			line.add_child(_button("Cancel", func() -> void: Account.remove_friend(request_name)))
		_body.add_child(line)
	if Account.friend_list.is_empty():
		var empty := UIStyle.label("No friends yet - add one by name.", UIStyle.SIZE_SMALL, UIStyle.TEXT_DIM)
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_body.add_child(empty)
	for f: Dictionary in Account.friend_list:
		var player_name := str(f.username)
		var status := "offline"
		if f.online:
			status = str(f.server) + ("  -  %s %d" % [PlayerClasses.display_name(str(f.get("class", "archer"))), int(f.get("level", 0))]
					if str(f.get("class", "")) != "" else "")
		var line := _row(player_name, status, f.online)
		if f.online and f.get("same_server", false):
			line.add_child(_button("Tell", func() -> void: chat.open("/t %s " % player_name)))
		if social.is_leader():
			line.add_child(_button("Invite", func() -> void: social.party_op("invite", player_name)))
		if f.online and str(f.server) != "Singleplayer" and (f.get("joinable", false) or f.get("same_server", false)):
			line.add_child(_button("Join", func() -> void: social.join_friend(player_name)))
		line.add_child(_button("×", func() -> void: Account.remove_friend(player_name)))
		_body.add_child(line)


func _do_search() -> void:
	if _searching or _search.text.strip_edges().is_empty():
		return
	_searching = true
	_results = await Account.search_players(_search.text.strip_edges())
	_searching = false
	_rebuild()


# --- Party --------------------------------------------------------------------------

func _party() -> void:
	for invitation: Dictionary in Account.party_invites:
		var accepted := bool(invitation.get("accepted", false))
		var line := _row(str(invitation.username), "Joining party..." if accepted else "Invites you to their party", true)
		line.add_child(_button("Retry" if accepted else "Accept", func() -> void: social.respond_invite(int(invitation.id), true)))
		line.add_child(_button("Decline", func() -> void: social.respond_invite(int(invitation.id), false)))
		_body.add_child(line)
	if Account.party_invites.is_empty() and social.invites.is_empty():
		_body.add_child(UIStyle.label("No pending party invitations.", UIStyle.SIZE_SMALL, UIStyle.TEXT_DIM))
	for leader: String in social.invites:
		var line := _row(leader, "invites you to their party", true)
		line.add_child(_button("Join", func() -> void: social.party_op("accept", leader)))
		line.add_child(_button("No", func() -> void:
			social.invites.erase(leader)
			social.party_op("decline", leader)
			_rebuild()))
		_body.add_child(line)
	var party := social.party
	if party.is_empty():
		_body.add_child(UIStyle.label("You're not in a party. Invite someone by name or from your friends.",
				UIStyle.SIZE_SMALL, UIStyle.TEXT_DIM))
	else:
		var leading := social.is_leader()
		for m: Dictionary in party.members:
			var player_name := str(m.name)
			var info := "%s %d  -  %s" % [PlayerClasses.display_name(str(m.class_id)) if str(m.class_id) != "" else "", int(m.level),
					"fallen" if m.dead else str(m.place)]
			var line := _row(player_name + ("  (leader)" if m.leader else ""), info, true, player_name)
			if player_name.to_lower() != social.my_name.to_lower():
				line.add_child(_button("Go", func() -> void: social.teleport(player_name)))
				if leading:
					line.add_child(_button("Kick", func() -> void: social.party_op("kick", player_name)))
			_body.add_child(line)
		var camp := social.campaign_state()
		if not camp.is_empty():
			_body.add_child(HSeparator.new())
			_body.add_child(UIStyle.label("Campaign: %s" % camp.title, UIStyle.SIZE_SMALL, UIStyle.GOLD))
			var step := Campaigns.step_def(camp.id, int(camp.step))
			_body.add_child(UIStyle.label(Campaigns.objective_text(step, int(camp.count)), UIStyle.SIZE_SMALL))
			if leading:
				_body.add_child(_button("Pause campaign (progress is kept)", func() -> void: social.campaign(["pause"])))
	_body.add_child(HSeparator.new())
	var row := HBoxContainer.new()
	_search.placeholder_text = "Invite a player by name"
	_search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_search)
	row.add_child(_button("Invite", _invite_name))
	_body.add_child(row)
	if not party.is_empty():
		_body.add_child(_button("Leave party" if not social.is_leader() else "Break up the party", func() -> void: social.party_op("leave")))


func _invite_name() -> void:
	if _search.text.strip_edges() != "":
		social.party_op("invite", _search.text.strip_edges())
		_search.text = ""


# --- Pieces ---------------------------------------------------------------------------

## A name (in its friend / party color), a line under it, a dot for online.
func _row(title: String, info: String, online: bool, color_name := "") -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var dot := ColorRect.new()
	dot.custom_minimum_size = Vector2(8, 8)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	dot.color = UIStyle.GOOD if online else Color(0.35, 0.37, 0.45)
	row.add_child(dot)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", 0)
	var name_label := UIStyle.label(title, UIStyle.SIZE_SMALL, social.name_color(color_name if color_name != "" else title))
	text.add_child(name_label)
	text.add_child(UIStyle.label(info, UIStyle.SIZE_SMALL, UIStyle.TEXT_DIM))
	row.add_child(text)
	return row


func _button(caption: String, action: Callable) -> Button:
	var b := UIStyle.button(caption)
	b.add_theme_font_size_override("font_size", UIStyle.SIZE_SMALL)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(action)
	return b
