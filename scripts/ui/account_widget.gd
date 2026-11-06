class_name AccountWidget
extends VBoxContainer
## The start screen's bottom-left corner: who's logged in (with the account
## level), and a menu to switch to another saved account, add one, or log out.

signal login_requested

var _menu := PanelContainer.new()
var _list := VBoxContainer.new()
var _button := Button.new()
var _name := UIStyle.label("", 20, UIStyle.TEXT)
var _sub := UIStyle.label("", 14, UIStyle.TEXT_DIM)
var _diamond := LevelDiamond.new(46.0)


func _ready() -> void:
	alignment = BoxContainer.ALIGNMENT_END
	add_theme_constant_override("separation", 8)
	_menu.add_theme_stylebox_override("panel", UIStyle.panel_outlined(UIStyle.GOLD))
	_list.add_theme_constant_override("separation", 6)
	_menu.add_child(_list)
	_menu.hide()
	add_child(_menu)
	UIStyle.button_styles(_button)
	_button.custom_minimum_size = Vector2(320, 72)
	_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_button.pressed.connect(_toggle)
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 14
	row.offset_right = -14
	row.offset_bottom = -6
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_diamond)
	var names := VBoxContainer.new()
	names.alignment = BoxContainer.ALIGNMENT_CENTER
	names.mouse_filter = Control.MOUSE_FILTER_IGNORE
	names.add_child(_name)
	names.add_child(_sub)
	row.add_child(names)
	_diamond.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_button.add_child(row)
	add_child(_button)
	Account.changed.connect(_refresh)
	_refresh()


func _refresh() -> void:
	if Account.is_logged_in():
		_name.text = Account.username()
		_sub.text = "Account level %d  -  switch account" % int(Account.progress().level)
		_diamond.level = int(Account.progress().level)
		_diamond.show()
	else:
		_name.text = "Not logged in"
		_sub.text = "Log in to play"
		_diamond.hide()
	_menu.hide()


func _toggle() -> void:
	if not Account.is_logged_in() and Account.saved().is_empty():
		login_requested.emit()
		return
	_menu.visible = not _menu.visible
	if not _menu.visible:
		return
	for child in _list.get_children():
		child.queue_free()
	_list.add_child(UIStyle.heading("Accounts", 20))
	for user: String in Account.saved():
		var current := user == Account.username() and Account.is_logged_in()
		var b := UIModal.button(("▶  " if current else "") + user, func() -> void:
			_menu.hide()
			if not current:
				await Account.switch_to(user), 290)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		_list.add_child(b)
	_list.add_child(UIModal.button("Add account", func() -> void:
		_menu.hide()
		login_requested.emit(), 290))
	if Account.is_logged_in():
		_list.add_child(UIModal.button("Log out of %s" % Account.username(), func() -> void:
			_menu.hide()
			Account.logout(), 290))
