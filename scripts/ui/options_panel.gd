class_name OptionsPanel
extends Control
## Settings tabs, guarded video preview and a key/mouse capture modal.
signal back_requested
var tabs := TabContainer.new()
var _tab_buttons: Array[Button] = []
var _panel := PanelContainer.new()
var _mode := OptionButton.new()
var _resolution := OptionButton.new()
var _screen := OptionButton.new()
var _vsync := CheckButton.new()
var _resizable := CheckButton.new()
var _fps := OptionButton.new()
var _gui := OptionButton.new()
var _show_fps := CheckButton.new()
var _resolution_label: Label
var _apply: Button
var _draft := {}
var _refreshing := false
var _binding_buttons := {}
var _modal := Control.new()
var _modal_title: Label
var _modal_text: Label
var _modal_buttons := HBoxContainer.new()
var _modal_kind := ""
var _capture_action := ""
var _pending_binding := {}
var _deadline := 0
var _status: Label
var _preset := OptionButton.new()
var _graphics_options := {}  # feature id -> OptionButton
var _audio_output := OptionButton.new()
var _audio_dynamic := OptionButton.new()
var _audio_width := HSlider.new()
var _audio_master := HSlider.new()
var _audio_music := HSlider.new()
var _audio_sfx := HSlider.new()
var _audio_ambience := HSlider.new()
var _audio_ally_volume := HSlider.new()
var _audio_ally := CheckButton.new()
var _audio_ui := CheckButton.new()
var _audio_status: Label

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	_panel.add_theme_stylebox_override("panel",UIStyle.ornament_panel())
	center.add_child(_panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",18)
	_panel.add_child(column)
	var header := HBoxContainer.new()
	header.add_child(UIStyle.heading("Options",32))
	column.add_child(header)
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tabs.add_theme_font_override("font",UIStyle.bold())
	tabs.add_theme_font_size_override("font_size",18)
	tabs.add_theme_stylebox_override("panel",UIStyle.content_panel(0))
	tabs.add_theme_stylebox_override("tab_selected",UIStyle.panel_outlined(UIStyle.GOLD))
	tabs.add_theme_color_override("font_selected_color",UIStyle.GOLD)
	var navigation := HBoxContainer.new()
	navigation.add_theme_constant_override("separation", 8)
	column.add_child(navigation)
	tabs.tabs_visible = false
	var group := ButtonGroup.new()
	for caption in ["General", "Audio", "Video", "Graphics", "Controls"]:
		var button := UIStyle.button(caption)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size.y = 44
		button.toggle_mode = true
		button.button_group = group
		button.size_flags_stretch_ratio = 1.0
		button.pressed.connect(_select_tab.bind(_tab_buttons.size()))
		navigation.add_child(button)
		_tab_buttons.append(button)
	tabs.tab_changed.connect(_update_navigation)
	column.add_child(tabs)
	for name_value in ["General","Audio","Video","Graphics","Controls"]:
		var page := MarginContainer.new()
		page.name = name_value
		for edge in ["left","top","right","bottom"]: page.add_theme_constant_override("margin_"+edge,12)
		tabs.add_child(page)
	_build_general(tabs.get_child(0))
	_build_video(tabs.get_child(2))
	_build_audio(tabs.get_child(1))
	_build_graphics(tabs.get_child(3))
	_build_controls(tabs.get_child(4))
	tabs.current_tab = 2
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation",12)
	_status = UIStyle.label("",16,UIStyle.TEXT_DIM)
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(_status)
	var back := UIStyle.button("Back")
	back.custom_minimum_size.x = 130
	back.pressed.connect(_back)
	footer.add_child(back)
	_apply = UIStyle.button("Apply")
	_apply.custom_minimum_size.x = 130
	_apply.pressed.connect(apply_video)
	footer.add_child(_apply)
	column.add_child(footer)
	_build_modal()
	tabs.tab_changed.connect(func(_tab: int) -> void: _update_footer())
	resized.connect(_fit_panel)
	AppSettings.bindings_changed.connect(_refresh_bindings)
	AppSettings.graphics_changed.connect(_refresh_graphics)
	AppSettings.audio_changed.connect(_refresh_audio)
	GameAudio.test_step.connect(func(_label: String) -> void: _refresh_audio_status())
	_fit_panel()
	hide()

func _fit_panel() -> void:
	_panel.custom_minimum_size = Vector2(minf(1120,maxf(700,size.x-64)),minf(760,maxf(450,size.y-64)))

func _scroll_page(page: Control) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	page.add_child(scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation",8)
	scroll.add_child(column)
	return column

func _help(text: String) -> Button:
	var button := Button.new()
	button.text = "?"
	button.flat = true
	button.custom_minimum_size = Vector2(28, 28)
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.tooltip_text = text
	button.add_theme_font_override("font", UIStyle.bold())
	button.add_theme_font_size_override("font_size", 18)
	button.add_theme_color_override("font_color", UIStyle.ACCENT)
	button.pressed.connect(func() -> void: _show_modal("help", "Help", text, [["Close", cancel_modal]]))
	return button

func _style_dropdown(option: OptionButton) -> void:
	option.alignment = HORIZONTAL_ALIGNMENT_LEFT
	option.add_theme_font_size_override("font_size", 18)
	option.add_theme_constant_override("arrow_margin", 16)
	option.add_theme_constant_override("h_separation", 16)
	for state in ["normal", "hover", "pressed", "disabled", "hover_pressed"]:
		var style := option.get_theme_stylebox(state).duplicate() as StyleBox
		style.content_margin_left = 18
		style.content_margin_right = 42
		style.content_margin_top = 13 if state in ["pressed", "hover_pressed"] else 10
		style.content_margin_bottom = 7 if state in ["pressed", "hover_pressed"] else 10
		option.add_theme_stylebox_override(state, style)
	var popup := option.get_popup()
	popup.add_theme_font_override("font", UIStyle.font())
	popup.add_theme_font_size_override("font_size", 18)
	popup.add_theme_stylebox_override("panel", UIStyle.popup_panel())
	popup.add_theme_constant_override("v_separation", 14)
	popup.add_theme_constant_override("item_start_padding", 14)
	popup.add_theme_constant_override("item_end_padding", 14)

func _row(column: VBoxContainer, title: String, widget: Control, help_text := "") -> Label:
	var row := HBoxContainer.new()
	row.custom_minimum_size.y = 48
	row.add_theme_constant_override("separation", 16)
	var label := UIStyle.label(title, 19)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)
	var help := _help(help_text)
	help.visible = not help_text.is_empty()
	row.add_child(help)
	widget.custom_minimum_size.x = 340
	widget.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(widget)
	column.add_child(row)
	if widget is OptionButton: _style_dropdown(widget)
	if widget is CheckButton:
		for state in ["normal", "hover", "pressed", "disabled", "hover_pressed"]:
			widget.add_theme_stylebox_override(state, StyleBoxEmpty.new())
		widget.alignment = HORIZONTAL_ALIGNMENT_RIGHT
	return label

func _build_general(page: Control) -> void:
	var column := _scroll_page(page)
	_gui.add_item("Small",0)
	_gui.add_item("Medium",1)
	_gui.add_item("Large",2)
	_row(column,"Interface scale",_gui,"Scales the interface to your window size. Medium uses the original interface size.")
	_row(column,"Show FPS",_show_fps,"Show the frame rate while playing.")

func _build_video(page: Control) -> void:
	var column := _scroll_page(page)
	_mode.add_item("Windowed",0)
	_mode.add_item("Fullscreen",1)
	_row(column,"Window mode",_mode)
	_resolution_label = _row(column,"Resolution",_resolution,"Fullscreen resolution changes the game image; the interface stays sharp.")
	var count := DisplayServer.get_screen_count() if AppSettings.desktop_available() else 1
	for i in maxi(1,count):
		var dimensions := DisplayServer.screen_get_size(i) if AppSettings.desktop_available() else AppSettings.reference_size
		_screen.add_item("Display %d - %d × %d" % [i+1,dimensions.x,dimensions.y],i)
	_screen.disabled = count<=1
	_row(column,"Display",_screen)
	_row(column,"V-Sync",_vsync)
	for value in [0,30,60,120,144,165,240]: _fps.add_item("Unlimited" if value==0 else "%d FPS" % value,value)
	_row(column,"Frame rate limit",_fps)
	_row(column,"Resizable window",_resizable)
	var reset := UIStyle.button("Reset video defaults")
	reset.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	reset.pressed.connect(func() -> void: _draft = AppSettings.defaults(); _refresh_video())
	column.add_child(reset)
	_mode.item_selected.connect(func(index: int) -> void:
		if _refreshing: return
		_draft.mode = "windowed" if index==0 else "fullscreen"
		_refresh_video())
	_resolution.item_selected.connect(func(index: int) -> void:
		if _refreshing: return
		_draft["window_size" if _draft.mode=="windowed" else "fullscreen_resolution"] = _resolution.get_item_metadata(index)
		_update_footer())
	_screen.item_selected.connect(func(index: int) -> void:
		if not _refreshing: _draft.screen = _screen.get_item_id(index); _refresh_video())
	_vsync.toggled.connect(func(value: bool) -> void:
		if not _refreshing: _draft.vsync = value; _update_footer())
	_fps.item_selected.connect(func(index: int) -> void:
		if not _refreshing: _draft.max_fps = _fps.get_item_id(index); _update_footer())
	_gui.item_selected.connect(func(index: int) -> void:
		if not _refreshing: _draft.gui_scale = ["small","medium","large"][index]; _update_footer())
	_resizable.toggled.connect(func(value: bool) -> void:
		if not _refreshing: _draft.resizable = value; _update_footer())
	_show_fps.toggled.connect(func(value: bool) -> void:
		if not _refreshing: _draft.show_fps = value; _update_footer())

func _build_audio(page: Control) -> void:
	var column := _scroll_page(page)
	column.add_child(UIStyle.heading("Output",20))
	for item in [["Headphones", "headphones"], ["Speakers", "speakers"], ["Surround", "surround"]]:
		_audio_output.add_item(item[0])
		_audio_output.set_item_metadata(_audio_output.item_count-1,item[1])
	_row(column,"Listening setup",_audio_output,"Choose your speakers or headphones. For surround sound, enable 5.1 speakers in your operating system first.")
	_audio_width.min_value = 0
	_audio_width.max_value = 1
	_audio_width.step = .01
	_audio_width.tooltip_text = "Sound effects in headphones: 0% is mono, 35% is the narrow default, 100% is full width. Music and ambience keep their original width."
	var width_row := HBoxContainer.new()
	_audio_width.custom_minimum_size.x = 250
	_audio_width.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	width_row.add_child(_audio_width)
	var width_value := UIStyle.label("%d%%" % roundi(float(AppSettings.audio.stereo_width)*100),16,UIStyle.TEXT_DIM)
	width_value.custom_minimum_size.x = 55
	width_row.add_child(width_value)
	_row(column,"Headphone width",width_row,_audio_width.tooltip_text)
	_audio_width.value_changed.connect(func(value: float) -> void:
		width_value.text = "%d%%" % roundi(value*100)
		_commit_audio("stereo_width",value))
	AppSettings.audio_changed.connect(func() -> void: width_value.text = "%d%%" % roundi(float(AppSettings.audio.stereo_width)*100))
	var output_row := HBoxContainer.new()
	output_row.add_theme_constant_override("separation",12)
	var test := UIStyle.button("Test spatial direction")
	test.pressed.connect(func() -> void: GameAudio.test_output(); _refresh_audio_status())
	output_row.add_child(test)
	_audio_status = UIStyle.label("",15,UIStyle.TEXT_DIM)
	_audio_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_audio_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_audio_status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_audio_status.hide()
	output_row.add_child(_audio_status)
	output_row.add_child(_help("Play a sound from each direction to check your listening setup. Headphones use a binaural direction test."))
	column.add_child(output_row)
	column.add_child(UIStyle.heading("Levels",20))
	for slider in [_audio_master,_audio_music,_audio_sfx,_audio_ambience,_audio_ally_volume]:
		slider.min_value = 0
		slider.max_value = 1
		slider.step = .01
		slider.custom_minimum_size.x = 320
	_row(column,"Master volume",_audio_master)
	_row(column,"Music",_audio_music)
	_row(column,"Sound effects",_audio_sfx)
	_row(column,"Ambience",_audio_ambience)
	column.add_child(UIStyle.heading("Other sounds",20))
	_row(column,"Ally sounds",_audio_ally)
	_row(column,"Ally volume",_audio_ally_volume)
	_row(column,"Interface sounds",_audio_ui)
	column.add_child(UIStyle.heading("Dynamic range",20))
	for item in [["Balanced", "balanced"], ["Night", "night"], ["Wide", "wide"]]:
		_audio_dynamic.add_item(item[0])
		_audio_dynamic.set_item_metadata(_audio_dynamic.item_count-1,item[1])
	_row(column,"Range",_audio_dynamic,"Night makes quiet sounds easier to hear at low volume. Wide preserves more contrast between quiet and loud sounds.")
	_audio_output.item_selected.connect(func(_index: int) -> void: _commit_audio("output_mode",_audio_output.get_item_metadata(_audio_output.selected)))
	_audio_dynamic.item_selected.connect(func(_index: int) -> void: _commit_audio("dynamic_range",_audio_dynamic.get_item_metadata(_audio_dynamic.selected)))
	_audio_master.value_changed.connect(func(value: float) -> void: _commit_audio("master",value))
	_audio_music.value_changed.connect(func(value: float) -> void: _commit_audio("music",value))
	_audio_sfx.value_changed.connect(func(value: float) -> void: _commit_audio("sfx",value))
	_audio_ambience.value_changed.connect(func(value: float) -> void: _commit_audio("ambience",value))
	_audio_ally_volume.value_changed.connect(func(value: float) -> void: _commit_audio("ally_volume",value))
	_audio_ally.toggled.connect(func(value: bool) -> void: _commit_audio("ally_sounds",value))
	_audio_ui.toggled.connect(func(value: bool) -> void: _commit_audio("ui_sounds",value))
	_refresh_audio()

func _commit_audio(key: String, value: Variant) -> void:
	if _refreshing: return
	var updated: Dictionary = AppSettings.audio.duplicate(true)
	updated[key] = value
	AppSettings.set_audio(updated)
	_refresh_audio_status()

func _refresh_audio() -> void:
	if not is_instance_valid(_audio_status): return
	_refreshing = true
	var values: Dictionary = AppSettings.audio
	for index in _audio_output.item_count:
		if _audio_output.get_item_metadata(index)==values.output_mode: _audio_output.select(index)
	for index in _audio_dynamic.item_count:
		if _audio_dynamic.get_item_metadata(index)==values.dynamic_range: _audio_dynamic.select(index)
	_audio_width.set_value_no_signal(values.stereo_width)
	_audio_master.set_value_no_signal(values.master)
	_audio_music.set_value_no_signal(values.music)
	_audio_sfx.set_value_no_signal(values.sfx)
	_audio_ambience.set_value_no_signal(values.ambience)
	_audio_ally_volume.set_value_no_signal(values.ally_volume)
	_audio_ally.set_pressed_no_signal(values.ally_sounds)
	_audio_ui.set_pressed_no_signal(values.ui_sounds)
	_refreshing = false
	_refresh_audio_status()

func _refresh_audio_status() -> void:
	if is_instance_valid(_audio_status): _audio_status.text = GameAudio.output_description()

func open_page() -> void:
	_draft = AppSettings.video.duplicate(true)
	_refresh_video()
	_refresh_audio()
	_refresh_bindings()
	_refresh_graphics()
	show()
	_fit_panel()

func _refresh_video() -> void:
	_refreshing = true
	_mode.select(0 if _draft.mode=="windowed" else 1)
	_screen.select(clampi(int(_draft.screen),0,_screen.item_count-1))
	_resolution_label.text = "Window resolution" if _draft.mode=="windowed" else "Fullscreen resolution"
	_resolution.clear()
	var choices: Array[Vector2i] = [Vector2i(960,540),Vector2i(1280,720),Vector2i(1366,768),Vector2i(1600,900),Vector2i(1920,1080),Vector2i(2560,1440),Vector2i(3840,2160)]
	var selected: Vector2i = _draft.window_size if _draft.mode=="windowed" else _draft.fullscreen_resolution
	var native: Vector2i = DisplayServer.screen_get_size(_draft.screen) if AppSettings.desktop_available() else AppSettings.reference_size
	if _draft.mode=="fullscreen": choices.push_front(Vector2i.ZERO)
	if native not in choices: choices.append(native)
	if selected not in choices: choices.append(selected)
	for resolution: Vector2i in choices:
		var label := "Desktop - %d × %d" % [native.x,native.y] if resolution==Vector2i.ZERO else "%d × %d" % [resolution.x,resolution.y]
		_resolution.add_item(label)
		_resolution.set_item_metadata(_resolution.item_count-1,resolution)
		if selected==resolution: _resolution.select(_resolution.item_count-1)
	_vsync.set_pressed_no_signal(_draft.vsync)
	_resizable.set_pressed_no_signal(_draft.resizable)
	_resizable.disabled = _draft.mode!="windowed"
	_show_fps.set_pressed_no_signal(_draft.show_fps)
	var fps_index := _fps.get_item_index(int(_draft.max_fps))
	if fps_index<0:
		_fps.add_item("%d FPS" % _draft.max_fps,int(_draft.max_fps))
		fps_index = _fps.item_count-1
	_fps.select(fps_index)
	_gui.select(["small","medium","large"].find(_draft.gui_scale))
	_refreshing = false
	_update_footer()

func _update_footer() -> void:
	if not is_instance_valid(_apply): return
	_apply.visible = tabs.current_tab in [0,2]
	_apply.disabled = _draft==AppSettings.video
	_status.text = ""

func _build_graphics(page: Control) -> void:
	var column := _scroll_page(page)
	for preset in ["Low","Medium","High","Custom"]: _preset.add_item(preset)
	_preset.set_item_disabled(3,true)
	var adapter := RenderingServer.get_video_adapter_name() if AppSettings.desktop_available() else "Unavailable"
	_row(column,"Quality preset",_preset,"Low and Medium reduce graphics cost. High enables the full look. You can adjust each feature separately.\nGraphics card: "+adapter)
	_preset.item_selected.connect(func(index: int) -> void:
		if not _refreshing and index<3: AppSettings.set_graphics(GraphicsSettings.defaults(GraphicsSettings.PRESETS[index])))
	for f: Array in GraphicsSettings.FEATURES:
		var id: String = f[0]
		var option := OptionButton.new()
		for choice: Array in f[2]: option.add_item(str(choice[1]))
		option.custom_minimum_size.x = 320
		option.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		option.item_selected.connect(func(index: int) -> void:
			if _refreshing: return
			var values := AppSettings.graphics.duplicate()
			values[id] = f[2][index][0]
			if id=="upscaler" and values[id]=="off": values.render_scale = 100
			AppSettings.set_graphics(values))
		_row(column, str(f[1]), option, str(f[3]))
		_graphics_options[id] = option
	var reset := UIStyle.button("Auto-detect")
	reset.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	reset.pressed.connect(func() -> void: AppSettings.set_graphics(GraphicsSettings.defaults(GraphicsSettings.suggested_preset())))
	column.add_child(reset)

func _refresh_graphics() -> void:
	_refreshing = true
	var values := AppSettings.graphics
	_preset.select(maxi(0,(GraphicsSettings.PRESETS+["custom"]).find(values.preset)))
	for id: String in _graphics_options:
		_graphics_options[id].select(maxi(0,GraphicsSettings.choices(id).find(values[id])))
	if _graphics_options.has("render_scale"):
		_graphics_options["render_scale"].disabled = values.upscaler=="off"
	_refreshing = false

func _build_controls(page: Control) -> void:
	var column := _scroll_page(page)
	var help_row := HBoxContainer.new()
	help_row.alignment = BoxContainer.ALIGNMENT_END
	help_row.add_child(_help("Click a binding, then press a key or mouse button. Escape cancels. Flight and on-foot controls can share keys; flight controls take priority while flying. Conflicts within a section can be swapped."))
	column.add_child(help_row)
	var category := ""
	for entry: Dictionary in ControlBindings.ACTIONS:
		if category!=entry.category:
			category = entry.category
			column.add_child(UIStyle.heading(category,20))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation",12)
		var title := UIStyle.label(entry.title)
		title.custom_minimum_size.x = 240
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(title)
		var bind := UIStyle.button("")
		bind.custom_minimum_size = Vector2(260,44)
		bind.pressed.connect(begin_capture.bind(str(entry.id)))
		row.add_child(bind)
		_binding_buttons[entry.id] = bind
		row.add_child(_help("Default: "+ControlBindings.text(ControlBindings.default_binding(entry.id))))
		var reset := UIStyle.button("Reset")
		reset.custom_minimum_size.x = 90
		reset.pressed.connect(_request_binding.bind(str(entry.id),ControlBindings.default_binding(entry.id)))
		row.add_child(reset)
		column.add_child(row)
	var reset_all := UIStyle.button("Restore all default controls")
	reset_all.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	reset_all.pressed.connect(AppSettings.reset_bindings)
	column.add_child(reset_all)

func _refresh_bindings() -> void:
	for action: String in _binding_buttons: _binding_buttons[action].text = AppSettings.binding_text(action)

func _build_modal() -> void:
	_modal.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_modal)
	var shade := ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0,0,0,.75)
	_modal.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_modal.add_child(center)
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel",UIStyle.ornament_panel())
	box.custom_minimum_size.x = 620
	center.add_child(box)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",20)
	box.add_child(column)
	_modal_title = UIStyle.heading("",24)
	column.add_child(_modal_title)
	_modal_text = UIStyle.label("")
	_modal_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_modal_text.custom_minimum_size = Vector2(560,70)
	column.add_child(_modal_text)
	_modal_buttons.alignment = BoxContainer.ALIGNMENT_END
	_modal_buttons.add_theme_constant_override("separation",12)
	column.add_child(_modal_buttons)
	_modal.hide()

func _show_modal(kind: String, title: String, text: String, buttons: Array) -> void:
	_modal_kind = kind
	_modal_title.text = title
	_modal_text.text = text
	for child in _modal_buttons.get_children():
		_modal_buttons.remove_child(child)
		child.queue_free()
	for spec: Array in buttons:
		var button := UIStyle.button(str(spec[0]))
		button.pressed.connect(spec[1])
		_modal_buttons.add_child(button)
	_modal.show()
	if _modal_buttons.get_child_count()>0: _modal_buttons.get_child(0).grab_focus()

func begin_capture(action: String) -> void:
	_capture_action = action
	_show_modal("capture","Choose a binding","Press a key or mouse button for “%s”.\nPress Escape to cancel." % ControlBindings.spec(action).title,[["Cancel",cancel_modal]])

func _request_binding(action: String, binding: Dictionary) -> void:
	_capture_action = action
	_pending_binding = binding
	var conflict := AppSettings.conflict_for(action,binding)
	if conflict!="":
		_show_modal("conflict","Binding already used","%s is assigned to “%s”. Swap it with “%s”?" % [ControlBindings.text(binding),ControlBindings.spec(conflict).title,ControlBindings.spec(action).title],[["Swap bindings",_confirm_binding],["Cancel",cancel_modal]])
	else: _confirm_binding()

func _confirm_binding() -> void:
	AppSettings.set_binding(_capture_action,_pending_binding)
	cancel_modal()

func cancel_modal() -> void:
	if _modal_kind=="video":
		_revert_video()
		return
	_modal_kind = ""
	_modal.hide()
	if _binding_buttons.has(_capture_action): _binding_buttons[_capture_action].grab_focus()
	_capture_action = ""
	_pending_binding.clear()

func apply_video() -> void:
	if _draft==AppSettings.video: return
	AppSettings.begin_video_preview(_draft)
	_deadline = Time.get_ticks_msec()+15000
	_show_modal("video","Keep these video settings?","",[["Keep changes",_keep_video],["Revert",_revert_video]])
	_update_countdown()

func _keep_video() -> void:
	AppSettings.confirm_video()
	_modal_kind = ""
	_modal.hide()
	_draft = AppSettings.video.duplicate(true)
	_refresh_video()

func _revert_video() -> void:
	AppSettings.revert_video()
	_modal_kind = ""
	_modal.hide()
	_draft = AppSettings.video.duplicate(true)
	_refresh_video()

func _update_countdown() -> void:
	var seconds := maxi(0,ceili(float(_deadline-Time.get_ticks_msec())/1000))
	_modal_text.text = "Your changes are being previewed.\nReverting in %d seconds unless you keep them." % seconds

func _process(_delta: float) -> void:
	if _modal_kind=="video":
		_update_countdown()
		if Time.get_ticks_msec()>=_deadline: _revert_video()

func _back() -> void:
	if _modal_kind!="": cancel_modal(); return
	back_requested.emit()

func discard_preview() -> void:
	if AppSettings.preview_active: AppSettings.revert_video()
	_modal_kind = ""
	_modal.hide()

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree(): return
	var pressed: bool = event is InputEventKey and event.pressed and not event.echo or event is InputEventMouseButton and event.pressed
	if not pressed: return
	var escape: bool = event is InputEventKey and event.keycode==KEY_ESCAPE
	if _modal_kind=="capture":
		if escape or event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and Rect2(Vector2.ZERO,_modal_buttons.size).has_point(_modal_buttons.get_global_transform_with_canvas().affine_inverse()*event.position): cancel_modal()
		else:
			var binding := ControlBindings.from_event(event)
			if binding.is_empty(): _modal_text.text = "Choose a key or mouse button, or Escape to cancel."
			else: _request_binding(_capture_action,binding)
		get_viewport().set_input_as_handled()
	elif _modal_kind!="":
		if escape:
			cancel_modal()
			get_viewport().set_input_as_handled()
		elif event is InputEventKey and event.keycode in [KEY_LEFT,KEY_RIGHT,KEY_UP,KEY_DOWN]:
			var current := get_viewport().gui_get_focus_owner()
			var index := _modal_buttons.get_children().find(current)
			_modal_buttons.get_child(posmod(index+(-1 if event.shift_pressed or event.keycode in [KEY_LEFT,KEY_UP] else 1),_modal_buttons.get_child_count())).grab_focus()
			get_viewport().set_input_as_handled()
	elif escape or event.is_action_pressed("menu"):
		_back()
		get_viewport().set_input_as_handled()


func _update_navigation(index: int) -> void:
	for i in _tab_buttons.size():
		var button := _tab_buttons[i]
		button.set_pressed_no_signal(i == index)
		for state in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
			button.add_theme_color_override(state, UIStyle.GOLD if i==index else UIStyle.TEXT)

func _select_tab(index: int) -> void:
	tabs.current_tab = index
	_update_navigation(index)
