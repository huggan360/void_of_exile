class_name Menus
extends ResponsiveUILayer
## The start screen and the in-game menu, both over a blurred, darkened view
## of the game:
##   start screen  the logo in the middle with Singleplayer, Servers,
##                 Options and Quit Game under it, while the world turns
##                 slowly behind; bottom left the account (AccountWidget).
##                 Nothing can be played without logging in.
##   game menu     (Escape) the logo in the top left, with Resume, Unstuck,
##                 Options, Leave and Quit Game in the middle
##   servers       the server list (ServerPanel)
## Options uses the same scaled canvas. Neither menu pauses anything: the world
## (and the server) keep going, only your character's input is locked.

signal singleplayer_pressed
signal closed
signal join_requested(address: String, port: int)
signal leave_pressed
signal unstuck_pressed
signal quit_pressed

const LOGO := preload("res://assets/branding/launch_logo.png")
const LOGO_SMALL := LOGO
const FADE_TIME := 0.25

var _backdrop := ColorRect.new()
var _backdrop_material := ShaderMaterial.new()
var _start := Control.new()
var _pause := Control.new()
var options := OptionsPanel.new()
var servers := ServerPanel.new()
var account := AccountWidget.new()
var _leave: Button
var _play_buttons: Array[Button] = []
var _from_start := true
var _root: Control


func _ready() -> void:
	layer = 80  # over the HUD, under loading transitions
	var root := make_ui_root()
	_root = root
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UIStyle.theme()
	_backdrop_material.shader = preload("res://shaders/menu_blur.gdshader")
	_backdrop.material = _backdrop_material
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(_backdrop)

	# Start screen: the logo and the buttons under it, all centered.
	_start.set_anchors_preset(Control.PRESET_FULL_RECT)
	_start.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_start)
	var start_box := _column(_start)
	var logo := _logo(LOGO, Vector2(820, 307))
	start_box.add_child(logo)
	start_box.add_child(_spacer(12))
	_play_buttons.append(_button("Singleplayer", func() -> void: singleplayer_pressed.emit()))
	_play_buttons.append(_button("Servers", show_servers))
	for b in _play_buttons:
		start_box.add_child(b)
	start_box.add_child(_button("Options", show_options))
	start_box.add_child(_button("Quit Game", func() -> void: quit_pressed.emit()))
	# Bottom left: the account.
	account.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	account.grow_vertical = Control.GROW_DIRECTION_BEGIN
	account.offset_left = 22
	account.offset_bottom = -22
	account.offset_top = -22
	account.login_requested.connect(func() -> void: show_login())
	_start.add_child(account)
	Account.changed.connect(_update_play)
	_update_play()

	# Game menu: small logo top left, buttons in the middle.
	_pause.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_pause)
	var corner := _logo(LOGO_SMALL, Vector2(400, 150))
	corner.position = Vector2(18, 12)
	_pause.add_child(corner)
	var pause_box := _column(_pause)
	pause_box.add_child(_button("Resume", close))
	pause_box.add_child(_button("Unstuck", func() -> void: unstuck_pressed.emit()))
	pause_box.add_child(_button("Options", show_options))
	_leave = _button("Leave Server", func() -> void: leave_pressed.emit())
	pause_box.add_child(_leave)
	pause_box.add_child(_button("Quit Game", func() -> void: quit_pressed.emit()))
	root.add_child(options)
	root.add_child(servers)
	servers.back_requested.connect(func() -> void:
		servers.hide()
		_start.visible = true)
	servers.join_requested.connect(func(a: String, p: int) -> void: join_requested.emit(a, p))
	options.back_requested.connect(back_from_options)
	hide_all()


## Login dialog (over the start screen). can_cancel: false when nobody is
## logged in yet.
func show_login(can_cancel := true) -> LoginDialog:
	var dialog := LoginDialog.new(can_cancel or Account.is_logged_in())
	_root.add_child(dialog)
	return dialog


## A dialog of the menus' own (a new character, a death record...), on the
## menus' scaled canvas.
func add_dialog(dialog: Control) -> void:
	_root.add_child(dialog)


func _update_play() -> void:
	for b in _play_buttons:
		b.disabled = not Account.is_logged_in()
		b.tooltip_text = "" if Account.is_logged_in() else "Log in first (bottom left)"


func show_start() -> void:
	_from_start = true
	_show(_start, 0.35, 1.6)


func show_pause() -> void:
	_from_start = false
	_show(_pause, 0.55, 3.0)


func is_open() -> bool:
	return visible


func is_game_menu_open() -> bool:
	return visible and not _from_start


func is_options_open() -> bool:
	return visible and (options.visible or servers.visible)


## The server list (from the start screen). message: shown on it (why a
## connection ended, for instance).
func show_servers(message := "", color := UIStyle.TEXT_DIM) -> void:
	if not visible or not _from_start:
		show_start()
	_start.hide()
	options.hide()
	servers.open()
	if message != "":
		servers.say(message, color)


func show_options() -> void:
	_start.hide()
	_pause.hide()
	options.open_page()


func back_from_options() -> void:
	options.discard_preview()
	options.hide()
	_start.visible = _from_start
	_pause.visible = not _from_start


## Fades the menu away.
func close() -> void:
	if not visible:
		return
	var tw := create_tween()
	tw.tween_property(get_child(0), "modulate:a", 0.0, FADE_TIME)
	await tw.finished
	hide_all()
	closed.emit()


func hide_all() -> void:
	options.discard_preview()
	options.hide()
	servers.hide()
	visible = false
	_start.hide()
	_pause.hide()


func _show(page: Control, dim: float, blur: float) -> void:
	options.discard_preview()
	options.hide()
	servers.hide()
	_leave.visible = Net.is_client()
	_leave.text = "Leave Singleplayer" if Net.is_client() and Net.client.info.get("singleplayer", false) else "Leave Server"
	_start.visible = page == _start
	_pause.visible = page == _pause
	_backdrop_material.set_shader_parameter("dim", dim)
	_backdrop_material.set_shader_parameter("blur", blur)
	visible = true
	var root: Control = get_child(0)
	root.modulate.a = 0.0
	create_tween().tween_property(root, "modulate:a", 1.0, FADE_TIME)


func _column(parent: Control) -> VBoxContainer:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(center)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 12)
	center.add_child(box)
	return box


func _logo(texture: Texture2D, logo_size: Vector2) -> TextureRect:
	var logo := TextureRect.new()
	logo.texture = texture
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.custom_minimum_size = logo_size
	logo.size = logo_size
	logo.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return logo


func _button(caption: String, action: Callable) -> Button:
	var b := UIStyle.button(caption)
	b.custom_minimum_size = Vector2(280, 52)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(action)
	return b


func _spacer(height: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, height)
	return c
