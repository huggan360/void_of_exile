class_name InteractionCard
extends PanelContainer
## Reusable bottom-center proximity prompt, portrait and accepted conversation.
## It grows upward from above the health bars; a longer speech comes in
## pages (Next), the last button always leaves (Exit). Words marked in the
## text are highlighted (see TextMarkup).

## The conversation ended (left, walked away...): what it opened closes too.
signal conversation_closed
var world: GameWorld
var target: InteractionTarget
var opened := false
var _portrait := TextureRect.new()
var _title := Label.new()
var _difficulty := HBoxContainer.new()
var _message := RichTextLabel.new()
var _accept := Button.new()
var _extra := Button.new()
var _pages: Array[String] = []
var _page := 0
var _typing: Tween

func _ready() -> void:
	set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	offset_left = -300
	offset_right = 300
	offset_top = -104
	offset_bottom = -104
	add_theme_stylebox_override("panel", UIStyle.panel_outlined(UIStyle.GOLD))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	add_child(row)
	_portrait.custom_minimum_size = Vector2(88, 104)
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	row.add_child(_portrait)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(column)
	UIStyle.text(_title, UIStyle.SIZE_LARGE, UIStyle.GOLD)
	column.add_child(_title)
	_difficulty.add_theme_constant_override("separation", 3)
	for index in 10:
		var pip := TextureProgressBar.new()
		pip.custom_minimum_size = Vector2(13, 4)
		var image := Image.create_empty(1, 1, false, Image.FORMAT_RGBA8)
		image.fill(Color("394039"))
		pip.texture_under = ImageTexture.create_from_image(image)
		image = image.duplicate()
		image.fill(Color("a8cb6c"))
		pip.texture_progress = ImageTexture.create_from_image(image)
		pip.nine_patch_stretch = true
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_difficulty.add_child(pip)
	_difficulty.hide()
	column.add_child(_difficulty)
	_message.bbcode_enabled = true
	_message.fit_content = true
	_message.scroll_active = false
	_message.custom_minimum_size = Vector2(0, 44)
	_message.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_message.add_theme_font_override("normal_font", UIStyle.font())
	_message.add_theme_font_override("bold_font", UIStyle.bold())
	_message.add_theme_font_size_override("normal_font_size", UIStyle.SIZE_SMALL)
	_message.add_theme_font_size_override("bold_font_size", UIStyle.SIZE_SMALL)
	_message.add_theme_color_override("default_color", UIStyle.TEXT)
	column.add_child(_message)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	buttons.alignment = BoxContainer.ALIGNMENT_END
	column.add_child(buttons)
	UIStyle.button_styles(_extra)
	_extra.pressed.connect(_extra_pressed)
	_extra.hide()
	buttons.add_child(_extra)
	UIStyle.button_styles(_accept)
	_accept.pressed.connect(accept)
	buttons.add_child(_accept)
	hide()

func set_world(value: GameWorld) -> void:
	close()
	world = value

func close() -> void:
	if opened:
		conversation_closed.emit()
	var player: Player = get_meta("player", null)
	if player and opened:
		player.talk_partner = null
	if is_instance_valid(target) and target.get_parent() is TownNPC:
		(target.get_parent() as TownNPC).listen_to(null)
	opened = false
	target = null
	_extra.hide()
	hide()

func update_prompt(player: Player, blocked: bool) -> void:
	if blocked or not is_instance_valid(world) or player.frozen or player.input_locked:
		close()
		return
	if opened:
		if not is_instance_valid(target) or not target.available(player) or not world.is_ancestor_of(target):
			close()
			return
		target.refresh(player)
		_extra.text = target.extra_text
		_extra.visible = target.extra_text != "" and _page + 1 >= _pages.size()
		return
	var nearest: InteractionTarget
	var distance := INF
	for candidate in get_tree().get_nodes_in_group("interaction_targets"):
		if not candidate is InteractionTarget or not world.is_ancestor_of(candidate) or not candidate.available(player): continue
		var d: float = candidate.global_position.distance_squared_to(player.global_position)
		if d < distance:
			nearest = candidate
			distance = d
	target = nearest
	visible = target != null
	if visible:
		target.refresh(player)
		_portrait.texture = target.portrait
		_title.text = target.title
		_difficulty.visible = target.difficulty >= 0.0
		for index in 10:
			(_difficulty.get_child(index) as TextureProgressBar).value = clampf(target.difficulty - index, 0.0, 1.0) * 100.0
		_message.text = TextMarkup.to_bbcode(target.description)
		_accept.text = target.action_text + " ["+AppSettings.binding_text("interact")+"]"

func accept() -> void:
	if opened:
		if _typing and _typing.is_running():
			_typing.kill()
			_message.visible_ratio = 1.0  # the rest of the page at once
		elif _page + 1 < _pages.size():
			_show_page(_page + 1)
		else:
			close()
		return
	var player: Player = get_meta("player", null)
	if not is_instance_valid(target) or not is_instance_valid(world) or not world.is_ancestor_of(target) or player == null or player.frozen or player.input_locked or not target.activate(player):
		close()
		return
	# Activation callbacks may travel or remove the source.
	if not is_instance_valid(target) or not is_instance_valid(world) or not target.is_inside_tree() or not world.is_ancestor_of(target):
		close()
		return
	opened = true
	_pages = TextMarkup.pages(target.response)
	if _pages.is_empty():
		_pages = [""]
	_show_page(0)
	# The camera turns to the speaker.
	player.talk_partner = target.focus()
	if target.get_parent() is TownNPC:
		(target.get_parent() as TownNPC).listen_to(player)


## One page of the speech writes itself out; Next, or Exit on the last.
func _show_page(index: int) -> void:
	_page = index
	_message.text = TextMarkup.to_bbcode(_pages[index])
	_message.visible_ratio = 0.0
	if _typing:
		_typing.kill()
	_typing = create_tween()
	_typing.tween_property(_message, "visible_ratio", 1.0, clampf(TextMarkup.plain(_pages[index]).length() * 0.028, 0.3, 3.0))
	var last := index + 1 >= _pages.size()
	_accept.text = ("Exit" if last else "Next") + " [" + AppSettings.binding_text("interact") + "]"
	_extra.visible = last and is_instance_valid(target) and target.extra_text != ""

func handle_input(event: InputEvent) -> bool:
	if not visible: return false
	if event.is_action_pressed("interact"):
		accept()
		return true
	if opened and (event.is_action_pressed("menu") or event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE):
		close()
		return true
	return false

func _extra_pressed() -> void:
	var player: Player = get_meta("player", null)
	if opened and is_instance_valid(target) and player != null and target.available(player):
		target.extra(player)
