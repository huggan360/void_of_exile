class_name LoginDialog
extends UIModal
## Log in to a Void Realms account (it's remembered on this computer, and you
## can be logged into several and switch between them).

signal logged_in

var _user := UIModal.field("Username")
var _pass := UIModal.field("Password", true)
var _url := UIModal.field("Account server", false, 480.0)
var _status := UIStyle.label("", 16, UIStyle.TEXT_DIM)
var _button: Button


func _init(can_cancel := true) -> void:
	super._init("Log in", 560.0)
	body.add_child(UIStyle.label("Your account holds your characters and everything they carry,\nin Singleplayer and on every server.", 16, UIStyle.TEXT_DIM))
	body.add_child(_user)
	body.add_child(_pass)
	var row := HBoxContainer.new()
	row.add_child(UIStyle.label("Account server  ", 14, UIStyle.TEXT_DIM))
	_url.text = Account.url()
	_url.custom_minimum_size = Vector2(340, 34)
	UIStyle.text(_url, 14, UIStyle.TEXT_DIM)
	_url.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_url)
	body.add_child(row)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size.x = 480
	body.add_child(_status)
	_button = UIModal.button("Log in", _login, 150)
	var list: Array = [_button]
	if can_cancel:
		list.push_front(UIModal.button("Cancel", close, 130))
	buttons(list)
	_user.text_submitted.connect(func(_t: String) -> void: _pass.grab_focus())
	_pass.text_submitted.connect(func(_t: String) -> void: _login())


func _ready() -> void:
	super._ready()
	_user.grab_focus.call_deferred()


func _login() -> void:
	if Account.busy or _user.text.strip_edges() == "":
		return
	if _url.text.strip_edges() != Account.url():
		Account.set_url(_url.text)
	_status.text = "Logging in..."
	_status.add_theme_color_override("font_color", UIStyle.TEXT_DIM)
	_button.disabled = true
	var r: Dictionary = await Account.login(_user.text, _pass.text)
	_button.disabled = false
	if not r.ok:
		_status.text = r.error
		_status.add_theme_color_override("font_color", UIStyle.HP_LIGHT)
		return
	logged_in.emit()
	close()
