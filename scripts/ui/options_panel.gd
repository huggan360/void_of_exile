class_name OptionsPanel
extends Control
## Settings tabs, guarded video preview and a key/mouse capture modal.
signal back_requested
var tabs := TabContainer.new()
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

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	_panel.add_theme_stylebox_override("panel",UIStyle.panel_outlined(UIStyle.GOLD))
	center.add_child(_panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",14)
	_panel.add_child(column)
	var header := HBoxContainer.new()
	header.add_child(UIStyle.heading("Options",32))
	var subtitle := UIStyle.label("Make yourself at home",16,UIStyle.TEXT_DIM)
	subtitle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	subtitle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(subtitle)
	column.add_child(header)
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tabs.add_theme_font_override("font",UIStyle.bold())
	tabs.add_theme_font_size_override("font_size",18)
	tabs.add_theme_stylebox_override("panel",UIStyle.panel())
	tabs.add_theme_stylebox_override("tab_selected",UIStyle.panel_outlined(UIStyle.GOLD))
	tabs.add_theme_color_override("font_selected_color",UIStyle.GOLD)
	column.add_child(tabs)
	for name_value in ["General","Audio","Video","Graphics","Controls"]:
		var page := MarginContainer.new()
		page.name = name_value
		for edge in ["left","top","right","bottom"]: page.add_theme_constant_override("margin_"+edge,12)
		tabs.add_child(page)
	_build_video(tabs.get_child(2))
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
	column.add_theme_constant_override("separation",12)
	scroll.add_child(column)
	return column

func _row(column: VBoxContainer, title: String, widget: Control) -> Label:
	var row := HBoxContainer.new()
	row.custom_minimum_size.y = 44
	row.add_theme_constant_override("separation",16)
	var label := UIStyle.label(title)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)
	widget.custom_minimum_size.x = 320
	widget.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(widget)
	column.add_child(row)
	return label

func _build_video(page: Control) -> void:
	var column := _scroll_page(page)
	_mode.add_item("Windowed",0)
	_mode.add_item("Fullscreen",1)
	_row(column,"Window mode",_mode)
	_resolution_label = _row(column,"Resolution",_resolution)
	var count := DisplayServer.get_screen_count() if AppSettings.desktop_available() else 1
	for i in maxi(1,count):
		var dimensions := DisplayServer.screen_get_size(i) if AppSettings.desktop_available() else AppSettings.reference_size
		_screen.add_item("Display %d · %d × %d" % [i+1,dimensions.x,dimensions.y],i)
	_screen.disabled = count<=1
	_row(column,"Display",_screen)
	_row(column,"V-Sync",_vsync)
	for value in [0,30,60,120,144,165,240]: _fps.add_item("Unlimited" if value==0 else "%d FPS" % value,value)
	_row(column,"Frame rate limit",_fps)
	_gui.add_item("Small",0)
	_gui.add_item("Medium · default",1)
	_gui.add_item("Large",2)
	_row(column,"GUI scale",_gui)
	_row(column,"Resizable window",_resizable)
	_row(column,"Show FPS",_show_fps)
	var note := UIStyle.label("Fullscreen resolution changes the game image; the interface stays sharp.\nGUI scale follows the window size. Medium matches the original fullscreen interface.",16,UIStyle.TEXT_DIM)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(note)
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

func open_page() -> void:
	_draft = AppSettings.video.duplicate(true)
	_refresh_video()
	_refresh_bindings()
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
		var label := "Desktop · %d × %d" % [native.x,native.y] if resolution==Vector2i.ZERO else "%d × %d" % [resolution.x,resolution.y]
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
	_apply.visible = tabs.current_tab==2
	_apply.disabled = _draft==AppSettings.video
	_status.text = "Apply to preview changes" if tabs.current_tab==2 and _draft!=AppSettings.video else "Changes saved automatically" if tabs.current_tab==4 else ""

func _build_controls(page: Control) -> void:
	var column := _scroll_page(page)
	var hint := UIStyle.label("Click a binding, then press a key or mouse button. Escape cancels. Conflicting bindings can be swapped.",16,UIStyle.TEXT_DIM)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(hint)
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
		bind.custom_minimum_size = Vector2(210,44)
		bind.pressed.connect(begin_capture.bind(str(entry.id)))
		row.add_child(bind)
		_binding_buttons[entry.id] = bind
		var default_label := UIStyle.label("Default: "+ControlBindings.text(ControlBindings.default_binding(entry.id)),14,UIStyle.TEXT_DIM)
		default_label.custom_minimum_size.x = 160
		default_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(default_label)
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
	box.add_theme_stylebox_override("panel",UIStyle.panel_outlined(UIStyle.ACCENT))
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
			if binding.is_empty(): _modal_text.text = "That key is reserved for development. Choose another key, or Escape to cancel."
			else: _request_binding(_capture_action,binding)
		get_viewport().set_input_as_handled()
	elif _modal_kind!="":
		if escape:
			cancel_modal()
			get_viewport().set_input_as_handled()
		elif event is InputEventKey and event.keycode in [KEY_TAB,KEY_LEFT,KEY_RIGHT,KEY_UP,KEY_DOWN]:
			var current := get_viewport().gui_get_focus_owner()
			var index := _modal_buttons.get_children().find(current)
			_modal_buttons.get_child(posmod(index+(-1 if event.shift_pressed or event.keycode in [KEY_LEFT,KEY_UP] else 1),_modal_buttons.get_child_count())).grab_focus()
			get_viewport().set_input_as_handled()
	elif escape or event.is_action_pressed("menu"):
		_back()
		get_viewport().set_input_as_handled()
