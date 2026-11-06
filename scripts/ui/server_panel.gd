class_name ServerPanel
extends Control
## Servers, from the start screen: each server's name, how many players are
## on and a ping symbol (more bars = a faster connection, a red cross = no
## answer). Servers on your own network show up by themselves (the account
## service knows them by your public IP, and they announce themselves on
## the LAN); Add Server adds one by its IP address. Click a server to join it
## with the character you play (it's the same character everywhere).
##
## Emits join_requested; Main does the connecting.

signal join_requested(address: String, port: int)
signal back_requested

const ROW_WIDTH := 640.0

var browser := ServerBrowser.new()
var _panel := PanelContainer.new()
var _pages := {}
var _status: Label
var _rows := VBoxContainer.new()
var _empty: DotsLoader
var _joining := false
var _join_label: Label
var _join_buttons: Array[Button] = []
var _footer_buttons: Array[Button] = []
var _address := UIModal.field("192.168.1.20", false, ROW_WIDTH)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(browser)
	browser.changed.connect(_refresh_rows)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	_panel.add_theme_stylebox_override("panel", UIStyle.panel_outlined(UIStyle.GOLD))
	center.add_child(_panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	column.custom_minimum_size = Vector2(ROW_WIDTH + 40, 0)
	_panel.add_child(column)
	for page in ["servers", "add"]:
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 12)
		column.add_child(box)
		_pages[page] = box
	_status = UIStyle.label("", 16, UIStyle.TEXT_DIM)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size.x = ROW_WIDTH
	column.add_child(_status)
	_build_servers(_pages.servers)
	_build_add(_pages.add)
	hide()


func open() -> void:
	show()
	clear_joining()
	say("")
	_show_page("servers")
	browser.refresh()


func say(text: String, color := UIStyle.TEXT_DIM) -> void:
	_status.text = text
	_status.add_theme_color_override("font_color", color)


func show_joining(server_name: String) -> void:
	_joining = true
	_join_label.text = "Joining %s..." % server_name
	_join_label.visible = true
	_empty.visible = true
	for button in _join_buttons:
		button.disabled = true
	say("")


func server_name(address: String, port: int) -> String:
	if address == "127.0.0.1":
		return "Singleplayer"
	for server: Dictionary in browser.servers.values():
		if str(server.address) == address and int(server.port) == port:
			return str(server.name)
	return "%s:%d" % [address, port]


func clear_joining() -> void:
	_joining = false
	if is_instance_valid(_join_label):
		_join_label.hide()
	if is_instance_valid(_empty):
		_empty.visible = browser.servers.is_empty()
	for button in _join_buttons:
		if is_instance_valid(button):
			button.disabled = false


func _show_page(page: String) -> void:
	for p in _pages:
		_pages[p].visible = p == page


func _build_servers(page: VBoxContainer) -> void:
	var header := HBoxContainer.new()
	header.add_child(UIStyle.heading("Servers", 30))
	page.add_child(header)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(ROW_WIDTH, 340)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_rows.add_theme_constant_override("separation", 8)
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_rows)
	page.add_child(scroll)
	var feedback := HBoxContainer.new()
	feedback.alignment = BoxContainer.ALIGNMENT_CENTER
	feedback.add_theme_constant_override("separation", 8)
	_empty = DotsLoader.new()
	feedback.add_child(_empty)
	_join_label = UIStyle.label("", 16, UIStyle.TEXT_DIM)
	_join_label.visible = false
	feedback.add_child(_join_label)
	page.add_child(feedback)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	buttons.alignment = BoxContainer.ALIGNMENT_END
	_footer_buttons.append(UIModal.button("Back", func() -> void: back_requested.emit()))
	_footer_buttons.append(UIModal.button("Refresh", func() -> void: browser.refresh()))
	_footer_buttons.append(UIModal.button("Add Server", func() -> void:
		_address.text = ""
		_show_page("add")
		_address.grab_focus.call_deferred()))
	_join_buttons.append_array(_footer_buttons)
	for button in _join_buttons:
		buttons.add_child(button)
	page.add_child(buttons)


func _refresh_rows() -> void:
	_join_buttons = _footer_buttons.duplicate()
	for button in _join_buttons:
		button.disabled = _joining
	for child in _rows.get_children():
		child.queue_free()
	var keys := browser.servers.keys()
	keys.sort_custom(func(a: String, b: String) -> bool:
		return browser.servers[a].name.naturalnocasecmp_to(browser.servers[b].name) < 0)
	for key: String in keys:
		_rows.add_child(_server_row(key, browser.servers[key]))
	_empty.visible = _joining or keys.is_empty()


func _server_row(key: String, s: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var b := UIStyle.button("")
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size.y = 58
	b.tooltip_text = "Join %s (%s:%d)" % [s.name, s.address, s.port]
	b.pressed.connect(func() -> void: _join(key))
	b.disabled = _joining
	_join_buttons.append(b)
	var inside := HBoxContainer.new()
	inside.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inside.offset_left = 18
	inside.offset_right = -14
	inside.offset_bottom = -6
	inside.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inside.add_theme_constant_override("separation", 16)
	var name_label := UIStyle.label(str(s.name), 20, UIStyle.TEXT)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.clip_text = true
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inside.add_child(name_label)
	var count := UIStyle.label("%d/%d" % [int(s.players), int(s.max_players)] if s.ping_ms >= 0 else "—", 18, UIStyle.TEXT_DIM)
	count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inside.add_child(count)
	var bars := PingBars.new()
	bars.ping_ms = s.ping_ms
	bars.tooltip_text = "%d ms" % roundi(s.ping_ms) if s.ping_ms >= 0 else "No answer"
	inside.add_child(bars)
	b.add_child(inside)
	row.add_child(b)
	if s.manual:
		var x := UIStyle.button("×")
		x.custom_minimum_size = Vector2(52, 58)
		x.tooltip_text = "Remove from the list"
		x.pressed.connect(func() -> void: browser.remove(key))
		x.disabled = _joining
		_join_buttons.append(x)
		row.add_child(x)
	return row


func _join(key: String) -> void:
	var s: Dictionary = browser.servers.get(key, {})
	if s.is_empty():
		return
	if s.get("protocol", Net.PROTOCOL) != Net.PROTOCOL:
		say("%s runs another version of the game." % s.name, UIStyle.HP_LIGHT)
		return
	join_requested.emit(str(s.address), int(s.port))


func _build_add(page: VBoxContainer) -> void:
	page.add_child(UIStyle.heading("Add Server", 30))
	page.add_child(UIStyle.label("The server's IP address (add :port if it isn't %d)." % Net.DEFAULT_PORT, 16, UIStyle.TEXT_DIM))
	_address.text_submitted.connect(func(_t: String) -> void: _add())
	page.add_child(_address)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	buttons.alignment = BoxContainer.ALIGNMENT_END
	buttons.add_child(UIModal.button("Back", func() -> void: _show_page("servers")))
	buttons.add_child(UIModal.button("Add", _add))
	page.add_child(buttons)


func _add() -> void:
	if _address.text.strip_edges() == "":
		return
	browser.add_manual(_address.text)
	_show_page("servers")


## The connection-quality symbol: four rising bars, lit by how fast the server
## answers (green to red); a red cross when it doesn't answer.
class PingBars:
	extends Control

	var ping_ms := -1.0

	func _init() -> void:
		custom_minimum_size = Vector2(34, 28)
		mouse_filter = Control.MOUSE_FILTER_PASS

	func _draw() -> void:
		var h := size.y
		if ping_ms < 0.0:
			var c := Color(0.95, 0.3, 0.3)
			draw_line(Vector2(8, 6), Vector2(26, h - 4), c, 3.0)
			draw_line(Vector2(26, 6), Vector2(8, h - 4), c, 3.0)
			return
		var lit := 4 if ping_ms < 60.0 else 3 if ping_ms < 120.0 else 2 if ping_ms < 220.0 else 1
		var color: Color = [Color(0.95, 0.3, 0.3), Color(1.0, 0.65, 0.25), Color(0.95, 0.9, 0.35), Color(0.45, 0.95, 0.5)][lit - 1]
		for i in 4:
			var bar_h := h * (0.3 + 0.7 * (i + 1) / 4.0)
			var rect := Rect2(i * 8 + 2, h - bar_h, 6, bar_h)
			draw_rect(rect, color if i < lit else Color(1, 1, 1, 0.15))
