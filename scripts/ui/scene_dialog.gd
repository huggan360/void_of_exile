class_name SceneDialog
extends PanelContainer
## A conversation the whole party watches (CampaignServer scenes): the same
## camera and words for everyone, only the one who started it turns the
## pages. A vote shows its choices to everyone instead.

var social: SocialClient
var player: Player
var scene: Dictionary
var my_id := 0
var focus_camera := true
var _text := RichTextLabel.new()
var _buttons := VBoxContainer.new()
var _focus := Node3D.new()
var _typing: Tween
var _advance: Button
var _waiting := false
var _voice := DialogueVoice.new()


func _ready() -> void:
	player.begin_interaction(get_instance_id())
	add_child(_voice)
	set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	offset_left = -440
	offset_right = 440
	offset_top = -110
	offset_bottom = -110
	add_theme_stylebox_override("panel", UIStyle.dialogue_panel())
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	add_child(column)
	column.add_child(UIStyle.heading(str(scene.title), 32, UIStyle.GOLD))
	column.add_child(UIStyle.dialogue_separator())
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	column.add_child(row)
	_text.bbcode_enabled = true
	_text.fit_content = true
	_text.scroll_active = false
	_text.add_theme_font_override("normal_font", UIStyle.font())
	_text.add_theme_font_override("bold_font", UIStyle.bold())
	_text.add_theme_color_override("default_color", UIStyle.TEXT)
	_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UIStyle.dialogue_text(_text)
	row.add_child(_text)
	_buttons.alignment = BoxContainer.ALIGNMENT_END
	_buttons.add_theme_constant_override("separation", 8)
	_buttons.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_buttons)
	# Everyone's camera turns to the speaker (or the one holding the necklace).
	player.get_parent().add_child(_focus)
	_focus.global_position = scene.get("focus", player.global_position) if scene.has("focus") else player.global_position
	if focus_camera:
		player.talk_partner = _focus
	show_page(int(scene.get("page", 0)))


func _process(_delta: float) -> void:
	if scene.has("focus_player"):  # follow the carrier
		var body: Node3D = player if int(scene.focus_player) == player.player_id else \
				(Net.client._remote.get(int(scene.focus_player)) if Net.is_client() else null)
		if is_instance_valid(body):
			_focus.global_position = body.global_position


func show_page(index: int) -> void:
	scene.page = index
	_waiting = false
	_text.text = TextMarkup.to_bbcode(str(scene.pages[mini(index, scene.pages.size() - 1)]))
	_text.visible_ratio = 0.0
	if _typing: _typing.kill()
	_typing = TextMarkup.reveal_words(_text)
	# This runs for the driver and every listener receiving camp_scene_page.
	if scene.kind == "talk":
		_voice.start(_text, str(scene.title), str(scene.get("voice_mood", "")))
	else:
		_voice.stop()
	for child in _buttons.get_children():
		_buttons.remove_child(child)
		child.queue_free()
	if scene.kind == "vote":
		for choice: String in scene.options:
			var b := UIStyle.button(str(scene.options[choice]))
			UIStyle.text(b, 24)
			b.pressed.connect(func() -> void:
				social.campaign(["vote", choice])
				for c in _buttons.get_children(): (c as Button).disabled = true)
			_buttons.add_child(b)
	elif int(scene.driver) == my_id:
		var last: bool = index + 1 >= scene.pages.size()
		var b := UIStyle.button(("Exit" if last else "Next") + " [" + AppSettings.binding_text("interact") + "]")
		UIStyle.text(b, 24)
		_advance = b
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(_next)
		_buttons.add_child(b)
	else:
		_buttons.add_child(UIStyle.label("Listening...", 24, UIStyle.TEXT_DIM))


func _next() -> void:
	if _typing and _typing.is_running():
		_typing.kill()
		_text.visible_characters = -1
		_voice.stop()
		return
	if _waiting:
		return
	_waiting = true
	_advance.disabled = true
	social.campaign(["scene_next"])


func _input(event: InputEvent) -> void:
	if scene.kind == "talk" and int(scene.driver) == my_id and event.is_action_pressed("interact"):
		_next()
		get_viewport().set_input_as_handled()


func _exit_tree() -> void:
	if is_instance_valid(player): player.end_interaction(get_instance_id())
	_voice.stop()
	if _typing: _typing.kill()
	if is_instance_valid(player) and player.talk_partner == _focus:
		player.talk_partner = null
	_focus.queue_free()
