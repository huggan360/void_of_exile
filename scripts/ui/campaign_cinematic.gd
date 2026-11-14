class_name CampaignCinematic
extends ResponsiveUILayer
## Plays a film (Cutscenes; scripts/cinematic/README.md): the chapter and
## title cards, then each shot, which only fades up once its place has
## streamed in (FilmSet.ready_at), with captions, depth of field on the shot's
## focus point and the film's look (FilmLook shader). Ends on a fade.
## Local presentation only; the film is plain network data.
signal finished

const FADE_OUT := .55
const FADE_IN := .8
const SKIP_SECONDS := .8
## Card timings, in seconds: fade in, hold, fade out.
const CHAPTER_CARD := [1.3, 1.9, 1.1]
const TITLE_CARD := [1.5, 3.0, 1.4]
const DEFAULT_LOOK := {vignette = 0.45, grain = 0.3, mono = 0.0, old = 0.0, warmth = 0.12, contrast = 1.05}
var _player: Player
var _set: FilmSet
var _camera := Camera3D.new()
var _focus := CameraAttributesPractical.new()
var _viewer: VoxelViewer
var _previous: Camera3D
var _was_locked := false
var _playing := false
var _film := {}
var _shots: Array = []
var _shot := -1
var _time := 0.0
var _elapsed := 0.0
var _skip_hold := 0.0
var _waited := 0.0
var _fade_in := 0.0
var _carry := 0.0  # seconds the next picture already streamed behind cards
var _reach := INF  # the spring arm's current length (_clear_view)
var _phase := ""
var _titles: Array = []  # the cards still to show on black: {title, subtitle, size, color, times}
var _hidden_layers: Array[CanvasLayer] = []
var _black: ColorRect
var _title_box: VBoxContainer
var _title: Label
var _subtitle: Label
var _card: PanelContainer
var _text: RichTextLabel
var _hint: Label
var _card_index := -1
var _writing: Tween
var _look_layer := CanvasLayer.new()
var _look := ShaderMaterial.new()

func _ready() -> void:
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS
	# The film's look sits under the letterbox and captions, over the world.
	_look_layer.layer = 89
	add_child(_look_layer)
	var screen := ColorRect.new()
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_look.shader = preload("res://shaders/film_look.gdshader")
	screen.material = _look
	_look_layer.add_child(screen)
	_look_layer.hide()
	var root := make_ui_root()
	root.theme = UIStyle.theme()
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	for bottom in [false,true]:
		var bar := ColorRect.new()
		bar.color = Color.BLACK
		bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE if bottom else Control.PRESET_TOP_WIDE)
		bar.offset_top = -72 if bottom else 0
		bar.offset_bottom = 0 if bottom else 72
		root.add_child(bar)
	_card = PanelContainer.new()
	_card.add_theme_stylebox_override("panel",UIStyle.panel_outlined(UIStyle.TEXT_DIM).duplicate())
	_card.self_modulate = Color(1,1,1,.82)
	root.add_child(_card)
	_card.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_card.anchor_left = .16
	_card.anchor_right = .84
	_card.anchor_top = .74
	_card.anchor_bottom = .74
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
	_black = ColorRect.new()
	_black.color = Color.BLACK
	root.add_child(_black)
	_black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_title_box = VBoxContainer.new()
	_title_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_title_box.add_theme_constant_override("separation",16)
	root.add_child(_title_box)
	_title_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_title_box.offset_left = 120
	_title_box.offset_right = -120
	_title = UIStyle.heading("",52,UIStyle.GOLD)
	_subtitle = UIStyle.label("",20,UIStyle.TEXT_DIM)
	for label in [_title,_subtitle]:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_title_box.add_child(label)
	_hint = UIStyle.label("hold Space to skip",16,UIStyle.TEXT_DIM)
	root.add_child(_hint)
	_hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_hint.offset_left = -260
	_hint.offset_right = -24
	_hint.offset_top = -48
	_hint.offset_bottom = -22
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_camera)
	_focus.dof_blur_far_enabled = true
	_focus.dof_blur_near_enabled = true
	_focus.dof_blur_amount = 0.07
	hide()

## Plays `film` (resolved by `film_set`, which this frees when it ends).
func play(player: Player, film: Dictionary, film_set: FilmSet = null) -> void:
	if _playing: cancel()
	if not is_node_ready():
		push_error("Add CampaignCinematic to the scene before play().")
		finished.emit()
		return
	_player = player
	_set = film_set
	if not is_instance_valid(player):
		_drop_set()
		finished.emit()
		return
	_playing = true
	_film = film
	_was_locked = player.cinematic_locked
	_previous = get_viewport().get_camera_3d()
	player.cinematic_locked = true
	player._cancel_weapon_actions()
	# The world's own sky and light: in Space that is the player camera's.
	var eye := player.camera if is_instance_valid(player.camera) else _previous
	if is_instance_valid(eye):
		_camera.environment = eye.environment
		_camera.far = eye.far
		_camera.near = eye.near
		_camera.cull_mask = eye.cull_mask | ShipWindowView.EXTERIOR_LAYER
		_camera.global_transform = eye.global_transform
	_camera.make_current()
	# The terrain streams round the film's camera, not round the player.
	_viewer = VoxelViewer.new()
	_viewer.view_distance = player.terrain_viewer.view_distance if is_instance_valid(player.terrain_viewer) else 128
	_viewer.requires_collisions = false
	_camera.add_child(_viewer)
	_shots = film.get("shots",[])
	_shot = -1
	_elapsed = 0
	_skip_hold = 0
	_card_index = -1
	_card.hide()
	_hint.modulate.a = 0
	_black.modulate.a = 1
	_title_box.modulate.a = 0
	_titles = _title_cards(film)
	_carry = 0.0
	_look_layer.show()
	_apply_look(DEFAULT_LOOK.merged(film.get("look", {}), true))
	_hide_ui(get_tree().root)
	show()
	if _shots.is_empty() and _titles.is_empty():
		_restore()
		return
	_next_shot()
	if not _titles.is_empty(): _set_phase("titles")

func is_playing() -> bool:
	return _playing

## Where the world should stream while a film plays (INF when none is).
func stream_point() -> Vector3:
	return _camera.global_position if _playing else Vector3.INF

## The chapter card ("Chapter Three"), then the title and its subtitle.
func _title_cards(film: Dictionary) -> Array:
	var cards: Array = []
	var chapter: Dictionary = film.get("chapter", film.get("loading", {}))
	if chapter.is_empty(): return cards
	if str(chapter.get("line", ""))!="":
		cards.append({title = str(chapter.line), subtitle = "", size = 30, color = UIStyle.TEXT_DIM, times = CHAPTER_CARD})
	cards.append({title = str(chapter.get("title", film.get("title", ""))), subtitle = str(chapter.get("subtitle", "")),
		size = 52, color = UIStyle.GOLD, times = TITLE_CARD})
	return cards

func _set_phase(phase: String) -> void:
	_phase = phase
	_time = 0
	_waited = 0

func _process(delta: float) -> void:
	if _phase=="after":
		_time += delta
		_black.modulate.a = 1.0-clampf(_time/.9,0,1)
		if _time>=.9:
			_phase = ""
			_black.modulate.a = 0
			hide()
		return
	if not _playing: return
	if not is_instance_valid(_player):
		cancel()
		return
	_hide_ui(get_tree().root)
	_elapsed += delta
	_time += delta
	var holding := Input.is_physical_key_pressed(KEY_SPACE) or Input.is_physical_key_pressed(KEY_ESCAPE)
	_skip_hold = _skip_hold+delta if holding and _phase!="outro" else 0.0
	_hint.modulate.a = clampf((_elapsed-2)/.6,0,1) if _phase!="outro" else 0.0
	_hint.text = "Skipping... %d%%" % roundi(_skip_hold/SKIP_SECONDS*100) if holding else "hold Space to skip"
	if _skip_hold>=SKIP_SECONDS:
		_clear_card()
		_title_box.modulate.a = 0
		_set_phase("outro")
		_time = _black.modulate.a*.7
	match _phase:
		"titles": _play_titles()
		"prepare":
			_waited += delta
			_black.modulate.a = 1
			if _set==null or _set.ready_at(_camera.global_position, _waited+_carry):
				_fade_in = FADE_IN
				_carry = 0.0
				_set_phase("shot")
				_start_shot_effects()
		"intertitle": _play_intertitle(delta)
		"shot": _play_shot(delta)
		"fade_out":
			_black.modulate.a = clampf(_time/FADE_OUT,0,1)
			_move_camera(_shots[_shot], 1.0)
			if _time>=FADE_OUT:
				_carry = 0.0
				_next_shot()
		"outro":
			_black.modulate.a = clampf(_time/.7,0,1)
			_title_box.modulate.a = minf(_title_box.modulate.a, 1.0-_black.modulate.a)
			if _time>=.7:
				_restore()
				_set_phase("after")
				_black.modulate.a = 1

## The black cards before the first shot; the first place streams meanwhile.
func _play_titles() -> void:
	_black.modulate.a = 1
	var card: Dictionary = _titles[0]
	if _time<=get_process_delta_time()+.001: _show_title(str(card.title), str(card.subtitle), int(card.size), card.color)
	var times: Array = card.times
	var total := float(times[0])+float(times[1])+float(times[2])
	_title_box.modulate.a = minf(clampf(_time/float(times[0]),0,1), clampf((total-_time)/float(times[2]),0,1))
	if _set: _set.ready_at(_camera.global_position, 0.3)
	if _time>=total:
		_titles.pop_front()
		_title_box.modulate.a = 0
		_carry += total
		if not _titles.is_empty(): _set_phase("titles")
		elif _is_intertitle(_shots[_shot]): _enter_intertitle()
		else: _set_phase("prepare")

func _show_title(text: String, subtitle: String, size: int, color: Color) -> void:
	_title.text = text
	_title.add_theme_font_size_override("font_size", size)
	_title.add_theme_color_override("font_color", color)
	_subtitle.text = subtitle
	_subtitle.visible = subtitle!=""

func _is_intertitle(shot: Dictionary) -> bool:
	return shot.has("title") and not shot.has("from")

## Words on black between the pictures (the old film's narration cards).
## The next picture's place streams in behind them.
func _enter_intertitle() -> void:
	var shot: Dictionary = _shots[_shot]
	_set_phase("intertitle")
	_show_title(str(shot.title), str(shot.get("subtitle", "")), int(shot.get("size", 34)), UIStyle.TEXT)
	_start_shot_effects()

func _play_intertitle(_delta: float) -> void:
	var shot: Dictionary = _shots[_shot]
	var duration := maxf(1.0, float(shot.get("duration", 5.0)))
	_black.modulate.a = 1
	var fade := minf(1.1, duration*.25)
	_title_box.modulate.a = minf(clampf(_time/fade,0,1), clampf((duration-_time)/fade,0,1))
	if _set: _set.ready_at(_camera.global_position, 0.3)
	if _time>=duration:
		_title_box.modulate.a = 0
		_next_shot()
		_carry += duration

func _play_shot(delta: float) -> void:
	var shot: Dictionary = _shots[_shot]
	var duration := _length(shot)
	var progress := clampf(_time/duration,0,1)
	_fade_in = maxf(0.0, _fade_in-delta)
	_black.modulate.a = _fade_in/FADE_IN
	_move_camera(shot, progress)
	_update_card(shot)
	if shot.has("grade_to"):
		_apply_look(_shot_look(shot).merged(shot.grade_to, true), smoothstep(0.0, 1.0, progress), _shot_look(shot))
	if _time>=duration:
		_clear_card()
		if _shot+1>=_shots.size(): _set_phase("outro")
		elif _shots[_shot+1].get("cut", false):
			_next_shot()
			_start_shot_effects()
		else: _set_phase("fade_out")

## The film's look for a shot: the film's, changed by the shot's `grade`.
func _shot_look(shot: Dictionary) -> Dictionary:
	return DEFAULT_LOOK.merged(_film.get("look", {}), true).merged(shot.get("grade", {}), true)

func _start_shot_effects() -> void:
	var shot: Dictionary = _shots[_shot]
	_apply_look(_shot_look(shot))
	if shot.has("sound"): GameAudio.play(str(shot.sound), Vector3.INF, {bus = "SFX", priority = 3})

## Moves on to the next shot (a card on black, or a picture to stream in).
func _next_shot() -> void:
	_shot += 1
	_clear_card()
	if _shot>=_shots.size():
		_set_phase("outro")
		return
	var shot: Dictionary = _shots[_shot]
	if _set: _set.on_shot(_shot)
	if _is_intertitle(shot):
		# Stand at the next picture meanwhile, so it is streamed when we cut.
		for i in range(_shot+1, _shots.size()):
			if not _is_intertitle(_shots[i]):
				_move_camera(_shots[i], 0.0)
				break
		if _phase!="titles": _enter_intertitle()
		return
	_move_camera(shot, 0.0)
	if _phase!="titles" and not shot.get("cut", false): _set_phase("prepare")
	elif shot.get("cut", false):
		_fade_in = 0.0
		_set_phase("shot")

func _move_camera(shot: Dictionary, progress: float) -> void:
	if not shot.has("from"): return
	var blend := smoothstep(0,1,progress)
	var start: Vector3 = shot.from
	var end: Vector3 = shot.get("to",start)
	var at := start.lerp(end,blend)
	var look_start: Vector3 = shot.get("look_from",start+Vector3.FORWARD)
	var look_end: Vector3 = shot.get("look_to",look_start)
	var target := look_start.lerp(look_end,blend)
	if _set:
		at = _set.clamp_camera(at)
		at = _clear_view(shot.get("focus", target), at, progress)
	_camera.global_position = at
	var direction := target-at
	if direction.length_squared()>.0001:
		_camera.look_at(target,Vector3.FORWARD if absf(direction.normalized().dot(Vector3.UP))>.999 else Vector3.UP)
	var fov := float(shot.get("fov", _film.get("fov", 55.0)))
	_camera.fov = lerpf(fov, float(shot.get("fov_to", fov)), blend)
	_update_focus(shot.get("focus", target), at)

## The spring arm: when something stands between the subject and the lens the
## camera comes in to just in front of it at once, and eases back out after.
func _clear_view(subject: Vector3, eye: Vector3, progress: float) -> Vector3:
	var length := subject.distance_to(eye)
	var free := _set.clear_reach(_shot, subject, eye)
	if progress <= 0.0 or free < _reach: _reach = free
	else: _reach = minf(free, lerpf(_reach, free, 1.0 - exp(-2.5 * get_process_delta_time())))
	if _reach >= length or length < 0.01: return eye
	return subject + (eye - subject) / length * _reach

## Depth of field (when the Graphics setting allows it): sharp on the shot's
## focus point, the foreground and the far distance going soft.
func _update_focus(point: Vector3, eye: Vector3) -> void:
	if AppSettings.graphics.get("depth_of_field", "on")!="on":
		_camera.attributes = null
		return
	_camera.attributes = _focus
	var d := maxf(eye.distance_to(point), 1.0)
	_focus.dof_blur_far_distance = d+maxf(4.0, d*.45)
	_focus.dof_blur_far_transition = maxf(8.0, d*.9)
	_focus.dof_blur_near_distance = maxf(.3, d*.45)
	_focus.dof_blur_near_transition = maxf(.5, d*.3)

func _apply_look(look: Dictionary, weight := 1.0, from := {}) -> void:
	for key: String in DEFAULT_LOOK:
		var value := float(look.get(key, DEFAULT_LOOK[key]))
		if weight<1.0: value = lerpf(float(from.get(key, DEFAULT_LOOK[key])), value, weight)
		_look.set_shader_parameter(key, value)

## How long a caption takes to write itself out.
static func _write_time(text: String) -> float:
	return clampf(text.length()*.036,.5,2.2)

## A shot's length: its duration, stretched so every caption can be read.
static func _length(shot: Dictionary) -> float:
	var length := maxf(.01, float(shot.get("duration", 6.0)))
	for card: Dictionary in shot.get("cards", []):
		length = maxf(length, float(card.get("at", 0.0))+_write_time(str(card.get("text", "")))+minf(float(card.get("hold", 3.5)), 2.6)+.4)
	return length

func _update_card(shot: Dictionary) -> void:
	var cards: Array = shot.get("cards",[])
	var active := -1
	var age := 0.0
	var reveal := 0.0
	var hold := 0.0
	for i in cards.size():
		var card: Dictionary = cards[i]
		var since := _time-float(card.get("at",0.0))
		var write := _write_time(str(card.get("text","")))
		var stay := maxf(0,float(card.get("hold",3.5)))
		if since>=0 and since<write+stay+.8:
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
		_card.modulate.a = minf(clampf(age/.5,0,1),clampf((reveal+hold+.8-age)/.8,0,1))

func _clear_card() -> void:
	if _writing: _writing.kill()
	_writing = null
	_card_index = -1
	_card.hide()

func _hide_ui(node: Node) -> void:
	if node==self: return
	if node is CanvasLayer and node.get_viewport()==get_viewport() and node.visible and not node.is_in_group("film_keep"):
		if not node in _hidden_layers: _hidden_layers.append(node)
		node.hide()
	for child in node.get_children(): _hide_ui(child)

func _input(event: InputEvent) -> void:
	if not _playing: return
	if event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton:
		get_viewport().set_input_as_handled()

## Back to the game: camera, controls and the hidden interface.
func _restore() -> void:
	if not _playing: return
	_playing = false
	_clear_card()
	_title_box.modulate.a = 0
	_look_layer.hide()
	if is_instance_valid(_viewer): _viewer.queue_free()
	_viewer = null
	_camera.attributes = null
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
	_drop_set()
	finished.emit()

func _drop_set() -> void:
	if is_instance_valid(_set): _set.queue_free()
	_set = null

## Stops at once (no fade).
func cancel() -> void:
	if not _playing: return
	_restore()
	_phase = ""
	hide()

func _exit_tree() -> void:
	cancel()
