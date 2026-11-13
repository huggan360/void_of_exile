class_name CampaignCinematic
extends ResponsiveUILayer
## Local presentation only; the campaign script is plain network data.
signal finished

const DIP_SECONDS := .35
const SKIP_SECONDS := .8
var _player: Player
var _camera := Camera3D.new()
var _previous: Camera3D
var _was_locked := false
var _playing := false
var _shots: Array = []
var _shot := -1
var _time := 0.0
var _elapsed := 0.0
var _skip_hold := 0.0
var _loading_seconds := 0.0
var _phase := ""
var _hidden_layers: Array[CanvasLayer] = []
var _loading: ColorRect
var _loading_text: VBoxContainer
var _title: Label
var _subtitle: Label
var _dip: ColorRect
var _card: PanelContainer
var _text: RichTextLabel
var _hint: Label
var _card_index := -1
var _writing: Tween

func _ready() -> void:
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root := make_ui_root()
	root.theme = UIStyle.theme()
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	for bottom in [false,true]:
		var bar := ColorRect.new()
		bar.color = Color.BLACK
		bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE if bottom else Control.PRESET_TOP_WIDE)
		bar.offset_top = -64 if bottom else 0
		bar.offset_bottom = 0 if bottom else 64
		root.add_child(bar)
	_card = PanelContainer.new()
	_card.add_theme_stylebox_override("panel",UIStyle.panel_outlined(UIStyle.TEXT_DIM).duplicate())
	_card.self_modulate = Color(1,1,1,.88)
	root.add_child(_card)
	_card.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_card.anchor_left = .16
	_card.anchor_right = .84
	_card.anchor_top = .72
	_card.anchor_bottom = .72
	_card.offset_top = -34
	_card.offset_bottom = 42
	# Rich text, so a card can highlight names (TextMarkup).
	_text = RichTextLabel.new()
	_text.bbcode_enabled = true
	_text.scroll_active = false
	_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text.add_theme_font_override("normal_font",UIStyle.font())
	_text.add_theme_font_override("bold_font",UIStyle.bold())
	_text.add_theme_font_size_override("normal_font_size",24)
	_text.add_theme_font_size_override("bold_font_size",24)
	_text.add_theme_font_override("italics_font",UIStyle.italic())
	_text.add_theme_font_size_override("italics_font_size",24)
	_text.add_theme_color_override("default_color",UIStyle.TEXT)
	_card.add_child(_text)
	_loading = _screen_panel(Color(.018,.02,.035))
	_loading_text = VBoxContainer.new()
	_loading_text.alignment = BoxContainer.ALIGNMENT_CENTER
	_loading_text.add_theme_constant_override("separation",18)
	_loading.add_child(_loading_text)
	_loading_text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_title = UIStyle.heading("",48,UIStyle.GOLD)
	_subtitle = UIStyle.label("",20,UIStyle.TEXT_DIM)
	for label in [_title,_subtitle]:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_loading_text.add_child(label)
	_dip = _screen_panel(Color.BLACK)
	_hint = UIStyle.label("hold Space to skip",16,UIStyle.TEXT_DIM)
	root.add_child(_hint)
	_hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_hint.offset_left = -260
	_hint.offset_right = -24
	_hint.offset_top = -44
	_hint.offset_bottom = -20
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_camera)
	hide()

func _screen_panel(color: Color) -> ColorRect:
	var panel := ColorRect.new()
	panel.color = color
	_ui_root.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return panel

func play(player: Player, script: Dictionary) -> void:
	if _playing: cancel()
	if not is_node_ready():
		push_error("Add CampaignCinematic to the scene before play().")
		finished.emit()
		return
	_player = player
	if not is_instance_valid(player):
		finished.emit()
		return
	_playing = true
	_was_locked = player.cinematic_locked
	_previous = get_viewport().get_camera_3d()
	player.cinematic_locked = true
	player._cancel_weapon_actions()
	_camera.fov = player.camera.fov if is_instance_valid(player.camera) else 65.0
	if is_instance_valid(_previous): _camera.global_transform = _previous.global_transform
	_camera.make_current()
	_shots = script.get("shots",[]).duplicate(true)
	_shot = -1
	_time = 0
	_elapsed = 0
	_skip_hold = 0
	_card_index = -1
	_card.hide()
	_dip.modulate.a = 0
	_hint.modulate.a = 0
	var loading: Dictionary = script.get("loading",{})
	_loading_seconds = maxf(0,float(loading.get("seconds",3.0))) if script.has("loading") else 0.0
	_title.text = str(loading.get("title",script.get("title","")))
	_subtitle.text = str(loading.get("subtitle",""))
	_loading.visible = _loading_seconds>0
	_loading.modulate.a = 1
	_loading_text.modulate.a = 0
	_phase = "loading" if _loading_seconds>0 else "shot"
	if not _shots.is_empty(): _begin_shot(0)
	_hide_ui(get_tree().root)
	show()
	if _loading_seconds<=0 and _shots.is_empty(): cancel()

func is_playing() -> bool:
	return _playing

func _process(delta: float) -> void:
	if not _playing: return
	if not is_instance_valid(_player):
		cancel()
		return
	_hide_ui(get_tree().root)
	_elapsed += delta
	_time += delta
	var holding := Input.is_physical_key_pressed(KEY_SPACE) or Input.is_physical_key_pressed(KEY_ESCAPE)
	_skip_hold = _skip_hold+delta if holding else 0.0
	_hint.modulate.a = clampf((_elapsed-2)/.6,0,1)
	_hint.text = "Skipping... %d%%" % roundi(_skip_hold/SKIP_SECONDS*100) if holding else "hold Space to skip"
	if _skip_hold>=SKIP_SECONDS:
		cancel()
		return
	if _phase=="loading":
		var fade := minf(.65,_loading_seconds*.5)
		_loading_text.modulate.a = minf(clampf(_time/fade,0,1),clampf((_loading_seconds-_time)/fade,0,1))
		_loading.modulate.a = clampf((_loading_seconds-_time)/fade,0,1)
		if _time>=_loading_seconds:
			_loading.hide()
			_time = 0
			_phase = "shot"
			if _shots.is_empty(): cancel()
		return
	if _phase=="dip":
		_dip.modulate.a = 1-absf(_time/DIP_SECONDS*2-1)
		if _time>=DIP_SECONDS*.5 and _shot<int(_dip.get_meta("next")):
			_begin_shot(_shot+1)
		if _time>=DIP_SECONDS:
			_dip.modulate.a = 0
			_phase = "shot"
			_time = 0
		return
	var shot: Dictionary = _shots[_shot]
	var duration := maxf(.01,float(shot.get("duration",6.0)))
	_move_camera(shot,clampf(_time/duration,0,1))
	_update_card(shot)
	if _time>=duration:
		_clear_card()
		if _shot+1>=_shots.size():
			cancel()
		else:
			_phase = "dip"
			_time = 0
			_dip.set_meta("next",_shot+1)

func _begin_shot(index: int) -> void:
	_shot = index
	_clear_card()
	_move_camera(_shots[index],0)

func _move_camera(shot: Dictionary, progress: float) -> void:
	var blend := smoothstep(0,1,progress)
	var start: Vector3 = shot.get("from",_camera.global_position)
	var end: Vector3 = shot.get("to",start)
	_camera.global_position = start.lerp(end,blend)+Vector3.UP*sin(progress*PI)*.45
	var look_start: Vector3 = shot.get("look_from",start+Vector3.FORWARD)
	var look_end: Vector3 = shot.get("look_to",look_start)
	var focus := look_start.lerp(look_end,blend)
	var direction := focus-_camera.global_position
	if direction.length_squared()>.0001:
		_camera.look_at(focus,Vector3.FORWARD if absf(direction.normalized().dot(Vector3.UP))>.999 else Vector3.UP)

func _update_card(shot: Dictionary) -> void:
	var cards: Array = shot.get("cards",[])
	var active := -1
	var age := 0.0
	var reveal := 0.0
	var hold := 0.0
	for i in cards.size():
		var card: Dictionary = cards[i]
		var since := _time-float(card.get("at",0.0))
		var write := clampf(str(card.get("text","")).length()*.028,.3,1.8)
		var stay := maxf(0,float(card.get("hold",3.5)))
		if since>=0 and since<write+stay+.45:
			active = i
			age = since
			reveal = write
			hold = stay
	if active!=_card_index:
		_clear_card()
		_card_index = active
		if active>=0:
			_text.text = "[center]%s[/center]" % TextMarkup.to_bbcode(str(cards[active].get("text","")))
			_text.visible_ratio = clampf(age/reveal,0,1)
			_writing = create_tween()
			_writing.tween_property(_text,"visible_ratio",1.0,maxf(.01,reveal-age))
	_card.visible = active>=0
	if active>=0:
		_card.modulate.a = minf(clampf(age/.2,0,1),clampf((reveal+hold+.45-age)/.45,0,1))

func _clear_card() -> void:
	if _writing: _writing.kill()
	_writing = null
	_card_index = -1
	_card.hide()

func _hide_ui(node: Node) -> void:
	if node==self: return
	if node is CanvasLayer and node.get_viewport()==get_viewport() and node.visible:
		if not node in _hidden_layers: _hidden_layers.append(node)
		node.hide()
	for child in node.get_children(): _hide_ui(child)

func _input(event: InputEvent) -> void:
	if not _playing: return
	if event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton:
		get_viewport().set_input_as_handled()

func cancel() -> void:
	if not _playing: return
	_playing = false
	_clear_card()
	if is_instance_valid(_player): _player.cinematic_locked = _was_locked
	if _camera.current:
		if is_instance_valid(_previous): _previous.make_current()
		elif is_instance_valid(_player) and is_instance_valid(_player.camera): _player.camera.make_current()
		else: _camera.clear_current()
	for ui in _hidden_layers:
		if is_instance_valid(ui): ui.show()
	_hidden_layers.clear()
	_previous = null
	_player = null
	hide()
	finished.emit()

func _exit_tree() -> void:
	cancel()
