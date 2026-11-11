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
## A party conversation owns this part of the screen until it finishes.
var suppressed := false
var _portrait := TextureRect.new()
var _title := Label.new()
var _difficulty := HBoxContainer.new()
var _message := RichTextLabel.new()
var _accept := Button.new()
var _extra := Button.new()
var _pages: Array[String] = []
var _page := 0
var _typing: Tween
var _voice := DialogueVoice.new()
var _shown_response := ""
var _near_targets: Array[WeakRef] = []
var _near_world: GameWorld
var _near_origin := Vector3.INF
var _near_refresh := 0

func _ready() -> void:
	add_child(_voice)
	set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	offset_left = -440
	offset_right = 440
	offset_top = -104
	offset_bottom = -104
	add_theme_stylebox_override("panel", UIStyle.dialogue_panel())
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
	UIStyle.text(_title, 32, UIStyle.GOLD)
	column.add_child(_title)
	column.add_child(UIStyle.dialogue_separator())
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
	var speech_row := HBoxContainer.new()
	speech_row.add_theme_constant_override("separation", 18)
	column.add_child(speech_row)
	_message.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UIStyle.dialogue_text(_message)
	speech_row.add_child(_message)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	buttons.alignment = BoxContainer.ALIGNMENT_END
	buttons.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	speech_row.add_child(buttons)
	UIStyle.button_styles(_extra)
	UIStyle.text(_extra, 24)
	_extra.pressed.connect(_extra_pressed)
	_extra.hide()
	buttons.add_child(_extra)
	_accept.focus_mode = Control.FOCUS_NONE
	UIStyle.button_styles(_accept)
	UIStyle.text(_accept, 24)
	_accept.pressed.connect(accept)
	buttons.add_child(_accept)
	hide()

func set_world(value: GameWorld) -> void:
	close()
	world = value

func close() -> void:
	_voice.stop()
	if _typing:
		_typing.kill()
	if opened:
		conversation_closed.emit()
	var player: Player = get_meta("player", null)
	if is_instance_valid(player): player.end_interaction(get_instance_id())
	if player and opened:
		player.talk_partner = null
	if is_instance_valid(target) and target.get_parent() is TownNPC:
		(target.get_parent() as TownNPC).listen_to(null)
	opened = false
	_accept.disabled = false
	target = null
	_extra.hide()
	hide()

func _chair_target(candidate: InteractionTarget) -> bool:
	if candidate is LeisureTarget: return candidate.kind=="seat"
	if candidate is CityTarget: return candidate.kind=="seat"
	if candidate is SpaceInteraction: return candidate.kind=="seat" and candidate.seat.begins_with("chair")
	return false

func _seated(player: Player) -> bool:
	if not Leisure.seat_spec(player.player_id).is_empty(): return true
	if player.spatial_controller is SpaceTraversal:
		var space := player.spatial_controller as SpaceTraversal
		return space.seat!="" or space.city_seat!="" or space._lounge_seat!=""
	return false

func update_prompt(player: Player, blocked: bool) -> void:
	if player.spatial_controller is SpaceTraversal:
		var space := player.spatial_controller as SpaceTraversal
		blocked = blocked or space.city_seat!="" or space._lift>=0
	if suppressed or blocked or not is_instance_valid(world) or player.frozen or player.input_locked:
		close()
		return
	var seated := _seated(player)
	if opened:
		if not is_instance_valid(target) or (seated and _chair_target(target)) or not target.available(player) or not world.is_ancestor_of(target):
			close()
			return
		target.refresh(player)
		if target.live_response and target.response!=_shown_response:
			_shown_response = target.response
			_pages = TextMarkup.pages(target.response)
			if _pages.is_empty(): _pages = [""]
			_show_page(0)
		_sync_choices()
		return
	var nearest: InteractionTarget
	var distance := INF
	if _near_world!=world or Time.get_ticks_msec()>=_near_refresh or player.global_position.distance_squared_to(_near_origin)>9.0:
		_near_world = world
		_near_origin = player.global_position
		_near_refresh = Time.get_ticks_msec()+150
		_near_targets.clear()
		for node in get_tree().get_nodes_in_group("interaction_targets"):
			if not node is InteractionTarget or not world.is_ancestor_of(node): continue
			if node.global_position.distance_squared_to(_near_origin)<=pow(node.reach+6.0,2.0): _near_targets.append(weakref(node))
	for ref: WeakRef in _near_targets:
		var candidate := ref.get_ref() as InteractionTarget
		if not is_instance_valid(candidate): continue
		var d := candidate.global_position.distance_squared_to(player.global_position)
		if d>candidate.reach*candidate.reach or not candidate.available(player): continue
		if seated and _chair_target(candidate): continue
		if d < distance:
			nearest = candidate
			distance = d
	target = nearest
	visible = target != null
	if visible:
		target.refresh(player)
		var person := target.get_parent() is TownNPC
		_portrait.visible = not person and not _chair_target(target)
		_message.visible = true
		_message.visible_ratio = 1.0
		_portrait.texture = target.portrait
		var quest := person and target.get_parent().get_children().any(func(n: Node) -> bool: return n is QuestMarker)
		_title.text = target.title + ("  !" if quest else "")
		_difficulty.visible = target.difficulty >= 0.0
		for index in 10:
			(_difficulty.get_child(index) as TextureProgressBar).value = clampf(target.difficulty - index, 0.0, 1.0) * 100.0
		_message.text = TextMarkup.to_bbcode(target.description)
		_accept.text = "Sit" if _chair_target(target) else ("Talk" if person else target.action_text) + " ["+AppSettings.binding_text(target.key_action)+"]"

func accept() -> void:
	if opened:
		if _typing and _typing.is_running():
			_typing.kill()
			_message.visible_ratio = 1.0  # the rest of the page at once
			_voice.stop()
			_sync_choices()
		elif _page + 1 < _pages.size():
			_show_page(_page + 1)
		else:
			if is_instance_valid(target) and target.confirm_text != "":
				var actor: Player = get_meta("player", null)
				if is_instance_valid(actor): target.confirm(actor)
			close()
		return
	var player: Player = get_meta("player", null)
	if not is_instance_valid(target) or not is_instance_valid(world) or not world.is_ancestor_of(target) or player == null or player.frozen or player.input_locked:
		close()
		return
	opened = true
	player.begin_interaction(get_instance_id())
	if not target.activate(player):
		close()
		return
	# Activation callbacks may travel or remove the source.
	if not is_instance_valid(target) or not is_instance_valid(world) or not target.is_inside_tree() or not world.is_ancestor_of(target):
		close()
		return
	_portrait.visible = not target.get_parent() is TownNPC
	_message.show()
	_pages = TextMarkup.pages(target.response)
	_shown_response = target.response
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
	_typing = TextMarkup.reveal_words(_message)
	if is_instance_valid(target) and (target.get_parent() is TownNPC or target.action_text == "Talk"):
		_voice.start(_message, target.title)
	else:
		_voice.stop()
	var last := index + 1 >= _pages.size()
	var confirm := last and is_instance_valid(target) and target.confirm_text != ""
	_accept.text = (target.confirm_text if confirm else "Exit" if last else "Next") + " [" + AppSettings.binding_text("interact") + "]"
	_sync_choices()


func _sync_choices() -> void:
	if not is_instance_valid(target):
		_extra.hide()
		return
	var last := _page + 1 >= _pages.size()
	var confirm := last and target.confirm_text != ""
	_accept.disabled = confirm and _typing != null and _typing.is_running()
	_extra.text = target.cancel_text if confirm else target.extra_text
	_extra.visible = last and (confirm or target.extra_text != "")

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
	if opened and is_instance_valid(target) and target.confirm_text != "" and _page + 1 >= _pages.size():
		close()  # No always exits without changing the home.
		return
	var player: Player = get_meta("player", null)
	if opened and is_instance_valid(target) and player != null and target.available(player):
		target.extra(player)


func _exit_tree() -> void:
	var player: Player = get_meta("player", null)
	if is_instance_valid(player): player.end_interaction(get_instance_id())
