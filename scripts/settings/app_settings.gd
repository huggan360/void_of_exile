extends Node
## Local preferences only, independent from characters and realm saves.
signal gui_changed
signal bindings_changed
signal video_changed
signal graphics_changed
signal audio_changed
const PATH := "user://settings.cfg"
const GUI_FACTORS := {small=.85,medium=1.0,large=1.2}
var reference_size := Vector2i(1920,1080)
var video: Dictionary
## Graphics quality (see GraphicsSettings), applied and saved at once.
var graphics: Dictionary
## Audio mix and output preferences, applied and saved at once.
var audio: Dictionary
var bindings := {}
var preview_active := false
var _previous_video := {}

func _ready() -> void:
	if desktop_available():
		var actual := DisplayServer.screen_get_size()
		if actual.x>0 and actual.y>0: reference_size = actual
	video = defaults()
	load_preferences()
	install_bindings()
	_apply_video()
	_apply_graphics()
	get_window().size_changed.connect(_on_window_resize)

func desktop_available() -> bool:
	return DisplayServer.get_name()!="headless"

func defaults() -> Dictionary:
	return {mode="windowed",window_size=Vector2i(1600,900),fullscreen_resolution=Vector2i.ZERO,screen=0,vsync=true,max_fps=0,gui_scale="medium",resizable=true,show_fps=false,camera_angle="standard"}

func sanitize(value: Dictionary) -> Dictionary:
	var result := defaults()
	for key in result:
		if value.has(key) and typeof(value[key])==typeof(result[key]): result[key] = value[key]
	if result.mode not in ["windowed","fullscreen"]: result.mode = "windowed"
	if not GUI_FACTORS.has(result.gui_scale): result.gui_scale = "medium"
	if result.camera_angle not in ["standard", "overhead"]: result.camera_angle = "standard"
	result.window_size = Vector2i(clampi(result.window_size.x,640,7680),clampi(result.window_size.y,360,4320))
	if result.fullscreen_resolution!=Vector2i.ZERO:
		result.fullscreen_resolution = Vector2i(clampi(result.fullscreen_resolution.x,640,7680),clampi(result.fullscreen_resolution.y,360,4320))
	result.screen = clampi(result.screen,0,maxi(0,DisplayServer.get_screen_count()-1)) if desktop_available() else 0
	result.max_fps = clampi(result.max_fps,0,1000)
	return result

func load_preferences() -> void:
	var config := ConfigFile.new()
	var exists := config.load(PATH)==OK
	var saved := {}
	for key in defaults(): saved[key] = config.get_value("video",key,defaults()[key]) if exists else defaults()[key]
	video = sanitize(saved)
	if exists and config.has_section("graphics"):
		var values := {}
		for key in config.get_section_keys("graphics"): values[key] = config.get_value("graphics",key)
		graphics = GraphicsSettings.sanitize(values)
	else: graphics = GraphicsSettings.defaults(GraphicsSettings.suggested_preset())
	var saved_audio := {}
	for key in audio_defaults(): saved_audio[key] = config.get_value("audio",key,audio_defaults()[key]) if exists else audio_defaults()[key]
	audio = sanitize_audio(saved_audio)
	var reference: Variant = config.get_value("interface","reference_size",reference_size)
	if reference is Vector2i and reference.x>=640 and reference.y>=360: reference_size = reference
	bindings.clear()
	for entry: Dictionary in ControlBindings.ACTIONS: bindings[entry.id] = ControlBindings.default_binding(entry.id)
	if exists:
		for entry: Dictionary in ControlBindings.ACTIONS:
			var binding := ControlBindings.normalized(config.get_value("controls",entry.id,{}))
			# Enter used to interact; it opens the chat now.
			if entry.id=="interact" and binding.get("code",0)==KEY_ENTER and binding.get("kind","")=="key": continue
			if not binding.is_empty(): set_binding(entry.id,binding,false)

func save_preferences() -> Error:
	var config := ConfigFile.new()
	# During a display preview only the confirmed video state may reach disk.
	var stored: Dictionary = _previous_video if preview_active else video
	for key in stored: config.set_value("video",key,stored[key])
	for key in graphics: config.set_value("graphics",key,graphics[key])
	for key in audio: config.set_value("audio",key,audio[key])
	config.set_value("interface","reference_size",reference_size)
	for action in bindings: config.set_value("controls",action,bindings[action])
	return config.save(PATH)

func ui_factor(window_size: Vector2 = Vector2.ZERO) -> float:
	var pixels := window_size if window_size!=Vector2.ZERO else Vector2(get_window().size)
	return maxf(.1,minf(pixels.x/reference_size.x,pixels.y/reference_size.y)*float(GUI_FACTORS.get(video.gui_scale,1)))

func _on_window_resize() -> void:
	_apply_render_scale()
	gui_changed.emit()

func begin_video_preview(value: Dictionary) -> void:
	if preview_active: revert_video()
	_previous_video = video.duplicate(true)
	preview_active = true
	video = sanitize(value)
	_apply_video()

func confirm_video() -> void:
	preview_active = false
	_previous_video.clear()
	save_preferences()
	video_changed.emit()

func revert_video() -> void:
	if not preview_active: return
	video = _previous_video.duplicate(true)
	preview_active = false
	_previous_video.clear()
	_apply_video()

func _apply_video() -> void:
	Engine.max_fps = int(video.max_fps)
	if desktop_available():
		var window := get_window()
		var moved := window.current_screen!=int(video.screen)
		var target_mode := Window.MODE_FULLSCREEN if video.mode=="fullscreen" else Window.MODE_WINDOWED
		if moved:
			window.mode = Window.MODE_WINDOWED
			window.current_screen = video.screen
		window.unresizable = not video.resizable
		if window.mode!=target_mode: window.mode = target_mode
		if video.mode=="windowed" and (moved or window.size!=video.window_size):
			window.size = video.window_size
			var usable := DisplayServer.screen_get_usable_rect(video.screen)
			window.position = usable.position+(usable.size-video.window_size)/2
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if video.vsync else DisplayServer.VSYNC_DISABLED)
	_apply_render_scale()
	gui_changed.emit()
	video_changed.emit()

func _apply_render_scale() -> void:
	var ratio := 1.0
	if video.mode=="fullscreen" and video.fullscreen_resolution!=Vector2i.ZERO:
		var pixels := Vector2(get_window().size)
		var target := Vector2(video.fullscreen_resolution)
		ratio = minf(target.x/maxf(1,pixels.x),target.y/maxf(1,pixels.y))
	GraphicsSettings.apply_viewport(get_window(),graphics,ratio)

func set_graphics(value: Dictionary) -> void:
	graphics = GraphicsSettings.sanitize(value)
	_apply_graphics()
	save_preferences()

func audio_defaults() -> Dictionary:
	return {output_mode="headphones",stereo_width=.35,master=.85,music=.55,sfx=.8,ambience=.5,ally_sounds=true,ally_volume=.35,ui_sounds=true,dynamic_range="balanced"}

func sanitize_audio(value: Dictionary) -> Dictionary:
	var result := audio_defaults()
	for key in result:
		if value.has(key) and typeof(value[key])==typeof(result[key]): result[key] = value[key]
	if result.output_mode not in ["headphones","speakers","surround"]: result.output_mode = "headphones"
	if result.dynamic_range not in ["balanced","night","wide"]: result.dynamic_range = "balanced"
	for key in ["master","music","sfx","ambience","ally_volume","stereo_width"]: result[key] = clampf(float(result[key]),0.0,1.0)
	return result

func set_audio(value: Dictionary) -> void:
	audio = sanitize_audio(value)
	save_preferences()
	audio_changed.emit()

func _apply_graphics() -> void:
	_apply_render_scale()
	graphics_changed.emit()

func install_bindings() -> void:
	# Tab belongs to the held inventory action, including Shift+Tab.
	for action in ["ui_focus_next", "ui_focus_prev"]:
		for event in InputMap.action_get_events(action):
			if event is InputEventKey and (event.keycode == KEY_TAB or event.physical_keycode == KEY_TAB):
				InputMap.action_erase_event(action, event)
	for entry: Dictionary in ControlBindings.ACTIONS:
		var action: String = entry.id
		if not InputMap.has_action(action): InputMap.add_action(action)
		Input.action_release(action)
		InputMap.action_erase_events(action)
		InputMap.action_add_event(action,ControlBindings.event_for(bindings[action]))

func conflict_for(action: String, binding: Dictionary) -> String:
	for other: String in bindings:
		if other!=action and bindings[other]==binding: return other
	return ""

func set_binding(action: String, value: Dictionary, persist := true) -> void:
	if ControlBindings.spec(action).is_empty(): return
	var binding := ControlBindings.normalized(value)
	if binding.is_empty(): return
	var previous: Dictionary = bindings.get(action,ControlBindings.default_binding(action)).duplicate(true)
	var conflict := conflict_for(action,binding)
	if conflict!="": bindings[conflict] = previous
	bindings[action] = binding
	if persist:
		install_bindings()
		save_preferences()
		bindings_changed.emit()

func reset_bindings() -> void:
	for entry: Dictionary in ControlBindings.ACTIONS: bindings[entry.id] = ControlBindings.default_binding(entry.id)
	install_bindings()
	save_preferences()
	bindings_changed.emit()

func binding_text(action: String) -> String:
	return ControlBindings.text(bindings.get(action,ControlBindings.default_binding(action)))
