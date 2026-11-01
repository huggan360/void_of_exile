class_name SceneDialog
extends PanelContainer
## A conversation the whole party watches (CampaignServer scenes): the same
## camera and words for everyone, only the one who started it turns the
## pages. A vote shows its choices to everyone instead.

var social: SocialClient
var player: Player
var scene: Dictionary
var my_id := 0
var _text := RichTextLabel.new()
var _buttons := HBoxContainer.new()
var _focus := Node3D.new()


func _ready() -> void:
	set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	offset_left = -320
	offset_right = 320
	offset_top = -110
	offset_bottom = -110
	add_theme_stylebox_override("panel", UIStyle.panel_outlined(UIStyle.GOLD))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	add_child(column)
	column.add_child(UIStyle.label(str(scene.title), UIStyle.SIZE_LARGE, UIStyle.GOLD))
	_text.bbcode_enabled = true
	_text.fit_content = true
	_text.scroll_active = false
	_text.add_theme_font_override("normal_font", UIStyle.font())
	_text.add_theme_font_override("bold_font", UIStyle.bold())
	_text.add_theme_color_override("default_color", UIStyle.TEXT)
	column.add_child(_text)
	_buttons.alignment = BoxContainer.ALIGNMENT_END
	_buttons.add_theme_constant_override("separation", 8)
	column.add_child(_buttons)
	# Everyone's camera turns to the speaker (or the one holding the necklace).
	player.get_parent().add_child(_focus)
	_focus.global_position = scene.get("focus", player.global_position) if scene.has("focus") else player.global_position
	player.talk_partner = _focus
	show_page(int(scene.get("page", 0)))


func _process(_delta: float) -> void:
	if scene.has("focus_player"):  # follow the carrier
		var body: Node3D = player if int(scene.focus_player) == player.player_id else \
				(Net.client._remote.get(int(scene.focus_player)) if Net.is_client() else null)
		if is_instance_valid(body):
			_focus.global_position = body.global_position


func show_page(index: int) -> void:
	_text.text = TextMarkup.to_bbcode(str(scene.pages[mini(index, scene.pages.size() - 1)]))
	_text.visible_ratio = 0.0
	create_tween().tween_property(_text, "visible_ratio", 1.0, 1.2)
	for child in _buttons.get_children():
		child.queue_free()
	if scene.kind == "vote":
		for choice: String in scene.options:
			var b := UIStyle.button(str(scene.options[choice]))
			b.pressed.connect(func() -> void:
				social.campaign(["vote", choice])
				for c in _buttons.get_children(): (c as Button).disabled = true)
			_buttons.add_child(b)
	elif int(scene.driver) == my_id:
		var last: bool = index + 1 >= scene.pages.size()
		var b := UIStyle.button("Exit" if last else "Next")
		b.pressed.connect(func() -> void: social.campaign(["scene_next"]))
		_buttons.add_child(b)
	else:
		_buttons.add_child(UIStyle.label("Listening...", UIStyle.SIZE_SMALL, UIStyle.TEXT_DIM))


func _exit_tree() -> void:
	if is_instance_valid(player) and player.talk_partner == _focus:
		player.talk_partner = null
	_focus.queue_free()
