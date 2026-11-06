class_name ChatPanel
extends VBoxContainer
## The chat, bottom left: everyone in the same place, private messages
## (/t), the party (/p), and the server's announcements. Enter opens it
## (keys type, the mouse stops aiming) and sends; Esc closes it. The two
## buttons under it open the friends and party panel.
## Speech bubbles float over whoever spoke (SpeechBubble).

signal panel_requested(tab: String)

const LOG_SIZE := Vector2(440, 196)
const FADE_AFTER := 14.0  # seconds without news before the log dims
const BUBBLE := {say = "say", tell = "tell", party = "party"}

var social: SocialClient
var player: Player
## Finds the body of a player id (for speech bubbles), see Main.
var body_of := Callable()
var _log := RichTextLabel.new()
var _input := LineEdit.new()
var _back := Panel.new()
var _last_line := -100.0
## The Friends / Party buttons (their panel opens right above them).
var button_row := HBoxContainer.new()
var _friends := Button.new()
var _party := Button.new()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", 4)
	var holder := Control.new()
	holder.custom_minimum_size = LOG_SIZE
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(holder)
	var back := StyleBoxFlat.new()
	back.bg_color = Color(UIStyle.BG, 0.72)
	back.border_color = UIStyle.OUTLINE
	back.set_border_width_all(2)
	_back.add_theme_stylebox_override("panel", back)
	_back.set_anchors_preset(Control.PRESET_FULL_RECT)
	_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(_back)
	_log.set_anchors_preset(Control.PRESET_FULL_RECT)
	_log.offset_left = 8
	_log.offset_right = -6
	_log.offset_top = 4
	_log.offset_bottom = -4
	_log.bbcode_enabled = true
	_log.scroll_following = true
	_log.fit_content = false
	_log.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_log.add_theme_font_override("normal_font", UIStyle.font())
	_log.add_theme_font_override("bold_font", UIStyle.bold())
	_log.add_theme_font_size_override("normal_font_size", UIStyle.SIZE_SMALL)
	_log.add_theme_font_size_override("bold_font_size", UIStyle.SIZE_SMALL)
	_log.add_theme_constant_override("outline_size", 4)
	_log.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	holder.add_child(_log)
	_input.custom_minimum_size = Vector2(LOG_SIZE.x, 30)
	_input.max_length = SocialServer.CHAT_MAX
	_input.placeholder_text = "Say something  -  /t name  -  /p party  -  /help"
	_input.add_theme_font_override("font", UIStyle.font())
	_input.add_theme_font_size_override("font_size", UIStyle.SIZE_SMALL)
	_input.text_submitted.connect(_submit)
	_input.hide()
	add_child(_input)
	var row := button_row
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)
	for b: Array in [[_friends, "Friends", "friends"], [_party, "Party", "party"]]:
		var button: Button = b[0]
		button.text = b[1]
		UIStyle.button_styles(button)
		button.add_theme_font_size_override("font_size", UIStyle.SIZE_SMALL)
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(func() -> void: panel_requested.emit(b[2]))
		row.add_child(button)
	social.line_added.connect(_on_line)
	social.party_changed.connect(_redraw)
	social.invited.connect(func(_l: String) -> void: _party.text = "Party  (!)")
	social.party_changed.connect(_social_badges)
	Account.friends_changed.connect(_social_badges)
	_social_badges()
	_redraw()


func _social_badges() -> void:
	_party.text = "Party  (!)" if not social.invites.is_empty() or not Account.party_invites.is_empty() else "Party"
	_friends.text = "Friends  (!)" if Account.friend_requests.any(func(r: Dictionary) -> bool: return not bool(r.outgoing)) else "Friends"


func is_open() -> bool:
	return _input.visible


func open(prefill := "") -> void:
	_input.show()
	_input.text = prefill
	_input.grab_focus()
	_input.caret_column = prefill.length()
	player.typing = true
	player._cancel_weapon_actions()


func close() -> void:
	_input.hide()
	_input.release_focus()
	player.typing = false


func _submit(text: String) -> void:
	if text.strip_edges() != "":
		social.send_chat(text)
	close()


## Enter opens and sends, "/" opens with a command started, Esc closes.
func handle_input(event: InputEvent) -> bool:
	if is_open():
		if event.is_action_pressed("menu") or event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
			close()
			return true
		return false
	if not event is InputEventKey or not event.pressed or event.echo:
		return false
	if event.is_action_pressed("chat"):
		open()
		return true
	if (event as InputEventKey).keycode == KEY_SLASH:
		open("/")
		return true
	return false


func _process(_delta: float) -> void:
	var idle := Time.get_ticks_msec() / 1000.0 - _last_line > FADE_AFTER
	var target := 1.0 if is_open() or not idle else 0.4
	_log.modulate.a = move_toward(_log.modulate.a, target, _delta * 2.0)
	_back.modulate.a = move_toward(_back.modulate.a, 1.0 if is_open() else 0.0, _delta * 6.0)
	if is_open() and (player.frozen or player.input_locked):
		close()


func _on_line(line: Dictionary) -> void:
	_last_line = Time.get_ticks_msec() / 1000.0
	_log.append_text("\n" + _format(line) if _log.get_parsed_text() != "" else _format(line))
	if BUBBLE.has(line.channel) and body_of.is_valid():
		var body: Node3D = body_of.call(int(line.from_id))
		# A private message bubbles only for the one it was told to.
		var shown: bool = line.channel != "tell" or str(line.to).to_lower() == social.my_name.to_lower()
		if body and shown:
			SpeechBubble.say(body, str(line.text), BUBBLE[line.channel])


## Names change color as friends and party change: draw it all again.
func _redraw() -> void:
	_log.clear()
	var first := true
	for line: Dictionary in social.lines:
		_log.append_text(("" if first else "\n") + _format(line))
		first = false


func _name(player_name: String) -> String:
	return "[color=#%s][b]%s[/b][/color]" % [social.name_color(player_name).to_html(false), _escape(player_name)]


func _format(line: Dictionary) -> String:
	var text := _escape(str(line.text))
	match str(line.channel):
		"say":
			return "%s: %s" % [_name(line.from), text]
		"tell":
			var mine: bool = int(line.from_id) == player.player_id
			return "[color=#7ee08a]%s %s: %s[/color]" % ["To" if mine else "From", _name(line.to if mine else line.from), text]
		"party":
			return "[color=#c58bff][Party] %s: %s[/color]" % [_name(line.from), text]
		"announce":
			return "[color=#ffb347][b]%s[/b][/color]" % TextMarkup.to_bbcode(str(line.text))
		"npc":
			return "[color=#7ee08a][b]%s:[/b][/color] [color=#f3e3b5]%s[/color]" % [_escape(str(line.from)), TextMarkup.to_bbcode(str(line.text))]
	# The server's own lines may highlight words; players' never do.
	return "[color=#%s]%s[/color]" % [UIStyle.GOLD.to_html(false), TextMarkup.to_bbcode(str(line.text))]


static func _escape(text: String) -> String:
	return text.replace("[", "[lb]")
