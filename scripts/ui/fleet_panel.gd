class_name FleetPanel
extends PanelContainer
## The shipwright's counter (on the right while you talk to them, like a
## shop): your battleships, each its own ship on the account (FleetServer).
## Take a stored one out onto the pad, store one in use, or buy a new one.
## A lost ship is gone; a stored one costs nothing to take out.
## Drawn in the game's own skin: the ivy window, stone cards and buttons.
const WIDTH := 440.0
const SHIP_ICON := ["........w.......", ".......ww.......", "......wws.......", ".....wwss.......", "....wwsss..p....", "...wwssss..pp...",
	"........m..ppp..", "........m.......", "bbbbbbbbbbbbbbbb", ".bkkkkkkkkkkkkb.", "..bkokkkokkkokb.", "...bkkkkkkkkkb..",
	"....bbbbbbbbbb..", "......cccc......", ".......cc.......", "................"]
const SHIP_COLORS := {w = "f4e6c8", s = "c8b090", p = "ff6eb4", m = "6a4a2a", b = "3a2418", k = "8a5a3a", o = "ffd27a", c = "6af0e0"}
var interaction: InteractionCard
var _target: InteractionTarget
var _dots := UIStyle.rich("", UIStyle.SIZE_NORMAL)
var _list := VBoxContainer.new()
var _note := UIStyle.label("", UIStyle.SIZE_SMALL, UIStyle.TEXT_DIM)
var _buy := Button.new()
var _price := UIStyle.rich("", UIStyle.SIZE_NORMAL)
var _hint := UIStyle.label("", UIStyle.SIZE_SMALL, UIStyle.BAD)
var _waiting := false
var _refresh_in := 0.0
var _data := {}
static var _icon: ImageTexture

func _ready() -> void:
	add_to_group("fleet_panels")
	add_theme_stylebox_override("panel", UIStyle.ornament_panel())
	custom_minimum_size.x = WIDTH
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	add_child(column)
	var head := HBoxContainer.new()
	var title := UIStyle.heading("Shipwright", 28)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	_dots.fit_content = true
	_dots.autowrap_mode = TextServer.AUTOWRAP_OFF
	_dots.custom_minimum_size.x = 150
	_dots.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(_dots)
	column.add_child(head)
	column.add_child(_note)
	_list.add_theme_constant_override("separation", 8)
	column.add_child(_list)
	var buy_row := HBoxContainer.new()
	buy_row.alignment = BoxContainer.ALIGNMENT_CENTER
	buy_row.add_theme_constant_override("separation", 12)
	UIStyle.button_styles(_buy, "ivy")
	_buy.text = "Buy a battleship"
	_buy.custom_minimum_size = Vector2(220, 48)
	_buy.focus_mode = Control.FOCUS_NONE
	_buy.pressed.connect(func() -> void: _request(["buy"]))
	buy_row.add_child(_buy)
	_price.fit_content = true
	_price.autowrap_mode = TextServer.AUTOWRAP_OFF
	_price.custom_minimum_size.x = 110
	_price.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	buy_row.add_child(_price)
	column.add_child(buy_row)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_hint)
	var foot := Control.new()
	foot.custom_minimum_size.y = 8
	column.add_child(foot)
	Account.dots_changed.connect(func(_t: int, _g: int, _s: String) -> void: if visible: _render())
	hide()

## The battleship in pixels (cards here, anywhere else that shows a ship).
static func ship_icon() -> ImageTexture:
	if _icon: return _icon
	var image := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	for y in 16:
		for x in 16:
			var ch := str(SHIP_ICON[y])[x]
			if ch!=".": image.set_pixel(x, y, Color(str(SHIP_COLORS[ch])))
	_icon = ImageTexture.create_from_image(image)
	return _icon

func open_for(target: InteractionTarget) -> void:
	_target = target
	_data = {}
	_hint.text = ""
	show()
	_render()
	_request(["list"])

func _request(args: Array) -> void:
	if _waiting: return
	if not Net.is_client():
		_hint.text = "Online or Singleplayer only"
		_render()
		return
	_waiting = true
	_refresh_in = 8.0
	_render()
	Net.client.send_action("fleet", args)

func receive(data: Dictionary) -> void:
	if not visible: return
	_waiting = false
	_refresh_in = 3.0
	if data.has("error"): _hint.text = str(data.error)
	else:
		_data = data
		_hint.text = ""
	_render()

func _dots_now() -> int:
	return int(_data.get("dots", Account.dots()))

func _render() -> void:
	for row in _list.get_children():
		_list.remove_child(row)
		row.queue_free()
	var clear := bool(_data.get("pad_clear", true))
	var dots_hex := Dots.COLOR.to_html(false)
	_dots.text = "[right][b][color=#%s]%s[/color][/b] [color=#%s]Dots[/color][/right]" % [dots_hex, Dots.format(_dots_now()), UIStyle.TEXT_DIM.to_html(false)]
	_price.text = "[b][color=#%s]%s[/color][/b] [color=#%s]Dots[/color]" % [dots_hex, Dots.format(SpaceWorld.SHIP_PRICE), UIStyle.TEXT_DIM.to_html(false)]
	_note.text = "" if clear else "The pad is in use: store that ship first."
	_note.visible = _note.text!=""
	_buy.disabled = _waiting or _dots_now()<SpaceWorld.SHIP_PRICE or not clear
	var ships: Array = _data.get("ships", [])
	for ship: Dictionary in ships: _list.add_child(_card(ship, clear))
	if ships.is_empty():
		var none := UIStyle.label("..." if _waiting else "You have no ships yet.", UIStyle.SIZE_NORMAL, UIStyle.TEXT_DIM)
		none.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_list.add_child(none)
	_hint.visible = _hint.text!=""

## One ship on a stone card: its picture, name, where it is, and one button.
func _card(ship: Dictionary, clear: bool) -> Control:
	var status := str(ship.get("status", ""))
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UIStyle.panel())
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	card.add_child(row)
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", UIStyle.slot())
	var icon := TextureRect.new()
	icon.texture = ship_icon()
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.custom_minimum_size = Vector2(48, 48)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.modulate = Color(1, 1, 1, 0.45) if status=="destroyed" else Color.WHITE
	frame.add_child(icon)
	row.add_child(frame)
	var words := VBoxContainer.new()
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.add_child(UIStyle.label(str(ship.get("name", "Battleship")), UIStyle.SIZE_LARGE, UIStyle.GOLD if status!="destroyed" else UIStyle.TEXT_DIM))
	var where: String = {stored = "In the hangar", deployed = str(ship.get("location", "Out")), destroyed = "Lost"}.get(status, status)
	var tone: Color = {stored = UIStyle.GOOD, deployed = UIStyle.ACCENT, destroyed = UIStyle.BAD}.get(status, UIStyle.TEXT_DIM)
	words.add_child(UIStyle.label(where, UIStyle.SIZE_SMALL, tone))
	row.add_child(words)
	if status=="destroyed": return card
	var button := Button.new()
	UIStyle.button_styles(button)
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(118, 44)
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var id := int(ship.get("id", 0))
	if status=="stored":
		button.text = "Take out"
		button.disabled = _waiting or not clear
		button.pressed.connect(func() -> void: _request(["deploy", id]))
	elif bool(ship.get("can_recall", false)):
		button.text = "Store"
		button.disabled = _waiting
		button.pressed.connect(func() -> void: _request(["recall", id]))
	else:
		button.text = "In use"
		button.disabled = true
	row.add_child(button)
	return card

func _process(delta: float) -> void:
	if not visible: return
	if interaction==null or not interaction.opened or interaction.target!=_target:
		hide()
		_waiting = false
		return
	_refresh_in -= delta
	if _refresh_in<=0.0:
		_waiting = false
		_request(["list"])
