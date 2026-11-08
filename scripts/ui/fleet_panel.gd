class_name FleetPanel
extends PanelContainer
## The shipwright's counter (on the right while you talk to them, like a
## shop): your battleships, each its own ship on the account (FleetServer):
## take a stored one out onto the pad, store one that is in use, or buy a new
## one. A lost ship is gone; a ship in storage costs nothing to take out.
const CARD_WIDTH := 430.0
var interaction: InteractionCard
var _target: InteractionTarget
var _title := UIStyle.heading("Shipwright", 24)
var _list := VBoxContainer.new()
var _pad := UIStyle.rich("", UIStyle.SIZE_SMALL)
var _buy := Button.new()
var _hint := UIStyle.label("", UIStyle.SIZE_SMALL, UIStyle.TEXT_DIM)
var _waiting := false
var _refresh_in := 0.0
var _data := {}

func _ready() -> void:
	add_to_group("fleet_panels")
	add_theme_stylebox_override("panel", UIStyle.panel_outlined(Color(0.55, 0.85, 1.0)))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	add_child(box)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_color_override("font_color", Color("ffcf6a"))
	box.add_child(_title)
	_pad.fit_content = true
	_pad.custom_minimum_size.x = CARD_WIDTH
	box.add_child(_pad)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(CARD_WIDTH + 12, 230)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	_list.add_theme_constant_override("separation", 6)
	_list.custom_minimum_size.x = CARD_WIDTH
	scroll.add_child(_list)
	_style(_buy, Color(0.14, 0.55, 0.26), Color(0.6, 1.0, 0.65), 20)
	_buy.custom_minimum_size = Vector2(260, 46)
	_buy.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_buy.pressed.connect(func() -> void: _request(["buy"]))
	box.add_child(_buy)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.custom_minimum_size.x = CARD_WIDTH
	box.add_child(_hint)
	Account.dots_changed.connect(func(_t: int, _g: int, _s: String) -> void: if visible: _render())
	hide()

## The shop panel's button look, in `color`.
static func _style(button: Button, color: Color, border: Color, font_size := 16) -> void:
	button.add_theme_font_override("font", UIStyle.bold())
	button.add_theme_font_size_override("font_size", font_size)
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = {normal = color, hover = color.lightened(0.15), pressed = color.darkened(0.2),
				disabled = Color(0.2, 0.22, 0.26), focus = color}[state]
		style.border_color = border if state != "disabled" else Color(0.32, 0.35, 0.4)
		style.set_border_width_all(2)
		style.set_corner_radius_all(4)
		style.set_content_margin_all(6)
		if state == "focus": style.draw_center = false
		button.add_theme_stylebox_override(state, style)
	button.add_theme_color_override("font_disabled_color", Color(0.6, 0.64, 0.7))

func open_for(target: InteractionTarget) -> void:
	_target = target
	_data = {}
	show()
	_render()
	_hint.text = ""
	_request(["list"])

func _request(args: Array) -> void:
	if _waiting: return
	if not Net.is_client():
		_hint.text = "Online or Singleplayer only"
		_hint.visible = true
		return
	_waiting = true
	_refresh_in = 8.0
	_render()
	Net.client.send_action("fleet", args)

func receive(data: Dictionary) -> void:
	if not visible: return
	_waiting = false
	_refresh_in = 3.0
	if data.has("error"):
		_hint.text = str(data.error)  # only errors are spelled out
	else:
		_data = data
		_hint.text = ""
	_render()

func _dots() -> int:
	return int(_data.get("dots", Account.dots()))

func _render() -> void:
	for row in _list.get_children():
		_list.remove_child(row)
		row.queue_free()
	var clear := bool(_data.get("pad_clear", true))
	_pad.text = "[center][b][color=#%s]%s Dots[/color][/b]%s[/center]" % [Dots.COLOR.to_html(false), Dots.format(_dots()),
		"" if clear else "   [color=#ffb070]Pad in use[/color]"]
	_buy.text = "..." if _waiting else "Buy  %s Dots" % Dots.format(SpaceWorld.SHIP_PRICE)
	_buy.disabled = _waiting or _dots() < SpaceWorld.SHIP_PRICE or not clear
	var ships: Array = _data.get("ships", [])
	for ship: Dictionary in ships: _list.add_child(_card(ship, clear))
	if ships.is_empty():
		var none := UIStyle.label("No ships yet", UIStyle.SIZE_NORMAL, UIStyle.TEXT_DIM)
		none.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		none.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		none.custom_minimum_size.x = CARD_WIDTH
		_list.add_child(none)
	_hint.visible = _hint.text != ""

## One ship: name, where it is, and what can be done with it.
func _card(ship: Dictionary, clear: bool) -> Control:
	var status := str(ship.get("status", ""))
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UIStyle.slot())
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	card.add_child(row)
	var badge := ColorRect.new()
	badge.custom_minimum_size = Vector2(6, 38)
	badge.color = {stored = Color("8dff9a"), deployed = Color("ffcf6a"), destroyed = Color("ff6a6a")}.get(status, Color.GRAY)
	row.add_child(badge)
	var words := VBoxContainer.new()
	words.add_theme_constant_override("separation", 0)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(words)
	var label := UIStyle.label(str(ship.get("name", "Battleship")), UIStyle.SIZE_NORMAL, UIStyle.TEXT if status != "destroyed" else UIStyle.TEXT_DIM)
	label.add_theme_font_override("font", UIStyle.bold())
	words.add_child(label)
	var where := {stored = "Stored", deployed = str(ship.get("location", "In use")), destroyed = "Lost"}.get(status, status) as String
	words.add_child(UIStyle.label(where, UIStyle.SIZE_SMALL, badge.color.lerp(UIStyle.TEXT_DIM, 0.35)))
	if status == "destroyed": return card
	var button := Button.new()
	button.custom_minimum_size = Vector2(110, 34)
	var id := int(ship.get("id", 0))
	if status == "stored":
		button.text = "Take out"
		_style(button, Color(0.14, 0.55, 0.26), Color(0.6, 1.0, 0.65))
		button.disabled = _waiting or not clear
		button.pressed.connect(func() -> void: _request(["deploy", id]))
	elif bool(ship.get("can_recall", false)):
		button.text = "Store"
		_style(button, Color(0.55, 0.4, 0.14), Color(1.0, 0.82, 0.45))
		button.disabled = _waiting
		button.pressed.connect(func() -> void: _request(["recall", id]))
	else:
		button.text = "In use"
		_style(button, Color(0.2, 0.22, 0.26), Color(0.32, 0.35, 0.4))
		button.disabled = true
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(button)
	return card

func _process(delta: float) -> void:
	if not visible: return
	if interaction == null or not interaction.opened or interaction.target != _target:
		hide()
		_waiting = false
		return
	_refresh_in -= delta
	if _refresh_in <= 0.0:
		_waiting = false
		_request(["list"])
