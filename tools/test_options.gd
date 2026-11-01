extends Node
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func key(code: int) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = true
	return event
func _ready() -> void: _run.call_deferred()
func _run() -> void:
	AppSettings.reset_bindings()
	var original_video: Dictionary = AppSettings.video.duplicate(true)
	AppSettings.reference_size = Vector2i(1920,1080)
	AppSettings.video.gui_scale = "medium"
	check(is_equal_approx(AppSettings.ui_factor(Vector2(1920,1080)),1),"Medium preserves the original fullscreen pixel sizes")
	check(is_equal_approx(AppSettings.ui_factor(Vector2(960,540)),.5),"GUI follows window size proportionally")
	check(is_equal_approx(AppSettings.ui_factor(Vector2(2560,1080)),1),"Ultrawide screen preserves height-relative UI scale")
	AppSettings.video.gui_scale = "small"
	check(is_equal_approx(AppSettings.ui_factor(Vector2(1920,1080)),.85),"Small GUI is smaller than medium")
	AppSettings.video.gui_scale = "large"
	check(is_equal_approx(AppSettings.ui_factor(Vector2(1920,1080)),1.2),"Large GUI is larger than medium")
	AppSettings.video = original_video.duplicate(true)
	AppSettings.install_bindings()
	AppSettings.install_bindings()
	for entry in ControlBindings.ACTIONS:
		check(InputMap.action_get_events(entry.id).size()==1,"Defaults never accumulate on repeated input setup")
		check(InputMap.event_is_action(ControlBindings.event_for(ControlBindings.default_binding(entry.id)),entry.id),"Every default works through InputMap")
	var menus := Menus.new()
	add_child(menus)
	menus.show_start()
	menus.show_options()
	var options := menus.options
	await get_tree().process_frame
	check(options.size.is_equal_approx(menus._ui_root.size),"Options fills its responsive parent canvas")
	check(options.tabs.get_tab_count()==5,"Five requested options tabs exist")
	for i in [0,1,3]: check(options.tabs.get_child(i).get_child_count()==0,"General, Audio and Graphics remain empty")
	check(options._binding_buttons.size()==ControlBindings.ACTIONS.size(),"Mapper exposes every actual game action")
	check(not menus.is_game_menu_open(),"Opening title Options preserves start-menu context")
	menus.back_from_options()
	check(menus._start.visible and not options.visible,"Back returns to title menu")
	menus.show_pause()
	menus.show_options()
	check(menus.is_game_menu_open(),"Pause Options preserves paused-input context")
	options.begin_capture("shoot")
	options._input(key(KEY_T))
	check(AppSettings.binding_text("shoot")=="T" and options._modal_kind=="","Keyboard capture immediately installs and saves a free binding")
	check(InputMap.event_is_action(key(KEY_T),"shoot"),"Rebound shoot uses the real gameplay InputMap")
	options.begin_capture("shoot")
	options._input(key(KEY_ESCAPE))
	check(AppSettings.binding_text("shoot")=="T" and options._modal_kind=="","Escape cancels capture without closing Options")
	options.begin_capture("shoot")
	options._input(key(KEY_F9))
	check(options._modal_kind=="capture" and AppSettings.binding_text("shoot")=="T","Development/reset keys cannot be accidentally assigned")
	options.cancel_modal()
	options.begin_capture("shoot")
	var click := InputEventMouseButton.new()
	click.pressed = true
	click.button_index = MOUSE_BUTTON_LEFT
	await get_tree().process_frame
	click.position = options._modal_buttons.get_global_transform_with_canvas()*(options._modal_buttons.size*.5)
	options._input(click)
	check(options._modal_kind=="" and AppSettings.binding_text("shoot")=="T","Clicking Cancel does not bind the cancel click")
	options.begin_capture("shoot")
	options._input(key(KEY_W))
	check(options._modal_kind=="conflict" and AppSettings.binding_text("move_forward")=="W","Duplicate keys require an explicit swap")
	options._input(key(KEY_UP))
	check(get_viewport().gui_get_focus_owner() in options._modal_buttons.get_children(),"Modal keyboard navigation cannot focus settings behind the dialog")
	options._confirm_binding()
	check(AppSettings.binding_text("shoot")=="W" and AppSettings.binding_text("move_forward")=="T","Swap preserves both actions rather than silently unbinding movement")
	options.begin_capture("quick_1")
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_XBUTTON1
	mouse.pressed = true
	options._input(mouse)
	check(AppSettings.bindings.quick_1.kind=="mouse" and InputMap.event_is_action(mouse,"quick_1"),"Mouse buttons can bind gameplay actions")
	AppSettings.save_preferences()
	AppSettings.bindings.shoot = ControlBindings.default_binding("shoot")
	AppSettings.load_preferences()
	AppSettings.install_bindings()
	check(AppSettings.binding_text("shoot")=="W" and AppSettings.bindings.quick_1.kind=="mouse","Bindings survive a real ConfigFile save/reload")
	# Video preview must never persist itself before confirmation.
	AppSettings.video = original_video.duplicate(true)
	AppSettings.save_preferences()
	options.open_page()
	options._draft.max_fps = 60
	options._draft.gui_scale = "large"
	options.apply_video()
	check(AppSettings.preview_active and Engine.max_fps==60 and AppSettings.video.gui_scale=="large","Apply previews actual video and GUI settings")
	AppSettings.save_preferences()
	var config := ConfigFile.new()
	config.load(AppSettings.PATH)
	check(config.get_value("video","max_fps")==original_video.max_fps,"Unconfirmed video settings cannot leak to disk")
	options._deadline = Time.get_ticks_msec()-1
	options._process(0)
	check(not AppSettings.preview_active and AppSettings.video==original_video,"Unconfirmed video changes automatically revert")
	options._draft.max_fps = 120
	options._draft.show_fps = true
	options.apply_video()
	options._keep_video()
	check(not AppSettings.preview_active and Engine.max_fps==120,"Keep commits actual frame cap")
	AppSettings.load_preferences()
	check(AppSettings.video.max_fps==120 and AppSettings.video.show_fps,"Confirmed video preferences survive restart")
	options.open_page()
	options._draft.gui_scale = "small"
	options.apply_video()
	menus.hide_all()
	check(not AppSettings.preview_active and AppSettings.video.gui_scale==original_video.gui_scale,"Closing menus cannot strand a display preview")
	# Every primary screen layer uses the same scale; changing UI never changes mouse aiming coordinates.
	var player := Player.new()
	player.stats = PlayerStats.new()
	add_child(player)
	player.set_physics_process(false)
	var hud := Hud.new(player.stats,player)
	add_child(hud)
	var transition := Transition.new()
	add_child(transition)
	AppSettings.video.gui_scale = "small"
	AppSettings.gui_changed.emit()
	check(is_equal_approx(hud.scale.x,menus.scale.x) and is_equal_approx(hud.scale.x,transition.scale.x),"HUD, menus and loading screens scale consistently")
	check(hud._ui_root.size.is_equal_approx(get_viewport().get_visible_rect().size/hud.scale.x),"Logical canvas fills the physical viewport exactly")
	AppSettings.set_binding("quick_1",ControlBindings.from_event(key(KEY_H)))
	check(hud._quick[0].key_hint=="H","HUD hints follow mapped keys")
	AppSettings.set_binding("interact",ControlBindings.from_event(key(KEY_J)))
	var card := hud.interaction
	card.show()
	check(not card.handle_input(key(KEY_ENTER)),"Old fixed Enter shortcut is no longer used after remap")
	check(card.handle_input(key(KEY_J)),"Conversation uses the mapped interact action")
	AppSettings.reset_bindings()
	AppSettings.video = original_video
	AppSettings._apply_video()
	AppSettings.save_preferences()
	hud.free()
	player.free()
	transition.free()
	menus.free()
	await get_tree().process_frame
	print("OPTIONS: ",checks," checks; ",failures," failures")
	get_tree().quit(1 if failures else 0)
