class_name ShopPanel
extends PanelContainer
## A shopkeeper's wares (ShopKeeper, Shops): on the right while you talk to
## them, your backpack on the left. Every item with its price (the number and
## the dot icon: white, green on sale), the offers on top, rare pieces marked
## "1 left". Kept minimal: no explanations. Pick one and
## Buy: the server checks the account's Dots and the account service's stock
## (EconomyServer.buy), the item lands in the backpack.

signal item_hovered(item: Item)
signal item_unhovered

const COLUMNS := 6
var stats: PlayerStats
var interaction: InteractionCard
var shop_id := ""
var _target: InteractionTarget
var _title := UIStyle.heading("", 24)
var _offers := RichTextLabel.new()
var _grid := GridContainer.new()
var _empty := UIStyle.label("", UIStyle.SIZE_NORMAL, UIStyle.TEXT_DIM)
var _picked := UIStyle.rich("", UIStyle.SIZE_NORMAL)
var _button := Button.new()
var _hint := UIStyle.label("", UIStyle.SIZE_SMALL, UIStyle.TEXT_DIM)
var _selected := ""
var _waiting := 0.0
var _shown_revision := ""
var _cells := {}  # item id -> {box, slot}
## Stays open without a conversation (tools/shop_preview).
var pinned := false


func _init(p_stats: PlayerStats) -> void:
	stats = p_stats


func _ready() -> void:
	add_to_group("shop_panels")
	add_theme_stylebox_override("panel", UIStyle.ornament_panel())
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	add_child(box)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_title)
	_offers.bbcode_enabled = true
	_offers.fit_content = true
	_offers.scroll_active = false
	_offers.custom_minimum_size.x = 420
	_offers.add_theme_font_override("normal_font", UIStyle.font())
	_offers.add_theme_font_override("bold_font", UIStyle.bold())
	box.add_child(_offers)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(COLUMNS*86, 300)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	_grid.columns = COLUMNS
	_grid.add_theme_constant_override("h_separation", 8)
	_grid.add_theme_constant_override("v_separation", 8)
	scroll.add_child(_grid)
	_empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_empty)
	_picked.fit_content = true
	_picked.custom_minimum_size.x = 420
	box.add_child(_picked)
	_button.text = "Buy"
	UIStyle.button_styles(_button)
	_button.focus_mode = Control.FOCUS_NONE
	_button.custom_minimum_size = Vector2(220, 48)
	_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_button.pressed.connect(buy)
	box.add_child(_button)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.custom_minimum_size.x = 420
	box.add_child(_hint)
	stats.changed.connect(_refresh_button)
	Account.dots_changed.connect(func(_t: int, _g: int, _s: String) -> void: _refresh_button())
	hide()


## A keeper was spoken to: their shop opens on the right.
func open_for(target: InteractionTarget, shop: String) -> void:
	_target = target
	shop_id = shop
	_selected = ""
	_waiting = 0.0
	_shown_revision = ""
	var def: Dictionary = Shops.DEFS.get(shop, {})
	_title.text = str(def.get("name", "Shop"))
	_title.add_theme_color_override("font_color", Color(str(def.get("color", "e5b96d"))))
	show()
	_rebuild()


func close() -> void:
	_target = null
	hide()
	item_unhovered.emit()


func _process(delta: float) -> void:
	if not visible: return
	if not pinned and (interaction == null or not interaction.opened or interaction.target != _target):
		close()
		return
	_waiting = maxf(0.0, _waiting-delta)
	# New stock or offers from the server, or the clock moving the timers.
	var revision := "%s:%d" % [str(_state().get("window", _state().get("ends", 0))), int(Shops.now()/30.0)]
	if revision != _shown_revision: _rebuild()
	_refresh_button()


func _state() -> Dictionary:
	# Offline previews have no server: show the plain catalogue.
	if Shops.state.is_empty() and not Net.is_client(): return Shops.fallback()
	return Shops.state


func _stock() -> Array:
	return _state().get("shops", {}).get(shop_id, {}).get("stock", [])


func _rebuild() -> void:
	_shown_revision = "%s:%d" % [str(_state().get("window", _state().get("ends", 0))), int(Shops.now()/30.0)]
	for child in _grid.get_children():
		child.queue_free()
	_cells.clear()
	# Offers on top: bold and coloured, with the time left.
	var lines: Array[String] = []
	for o: Dictionary in Shops.offers(shop_id):
		var cut := "[b][color=#ffd84a]%d%% off[/color][/b]" % int(o.percent)
		var what := "[b][color=#8af0ff]%s[/color][/b]" % Shops.family_name(str(o.family))
		lines.append("%s %s%s  [color=#a7b8cd]%s left[/color]" % [cut, what, " in every shop" if str(o.shop)=="*" else "",
			Shops.time_left(float(o.ends))])
	_offers.text = "[center]%s[/center]" % "\n".join(lines) if not lines.is_empty() else ""
	_offers.visible = not lines.is_empty()
	var stock := _stock().duplicate()
	# Rare pieces first, then by name.
	stock.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if (int(a.left)<0) != (int(b.left)<0): return int(a.left)>=0
		return str(a.id) < str(b.id))
	for e: Dictionary in stock:
		var item := Items.make(str(e.id))
		if item == null: continue
		var cell := VBoxContainer.new()
		cell.add_theme_constant_override("separation", 2)
		var slot := ItemSlot.new()
		slot.set_item(item)
		slot.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		slot.hovered.connect(func(_s: ItemSlot, it: Item) -> void: item_hovered.emit(it))
		slot.unhovered.connect(func() -> void: item_unhovered.emit())
		var id := str(e.id)
		slot.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				_selected = id
				_mark()
				if event.double_click: buy())
		cell.add_child(slot)
		var price := DotsCounter.amount(int(e.price), UIStyle.SIZE_SMALL, int(e.off) > 0)
		price.alignment = BoxContainer.ALIGNMENT_CENTER
		cell.add_child(price)
		if int(e.left) >= 0:
			var left := UIStyle.label("sold out" if int(e.left) == 0 else "1 left", UIStyle.SIZE_SMALL, Color("ff8080") if int(e.left) == 0 else Color("ffd84a"))
			left.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			cell.add_child(left)
		_grid.add_child(cell)
		_cells[id] = {box = cell, slot = slot, entry = e}
	_empty.visible = _cells.is_empty()
	if shop_id == "relic":
		_empty.text = "\"Nothing today. Come back in %s.\"" % Shops.time_left(float(_state().get("ends", 0)))
	else:
		_empty.text = "The shelves are being restocked..."
	_mark()


func _mark() -> void:
	for id: String in _cells:
		var cell: Dictionary = _cells[id]
		(cell.box as Control).modulate = Color(1.25, 1.25, 1.05) if id == _selected else Color.WHITE
	_refresh_button()


func _entry() -> Dictionary:
	return _cells[_selected].entry if _cells.has(_selected) else {}


func _refresh_button() -> void:
	if not is_instance_valid(_button): return
	var e := _entry()
	var dots := Account.dots()
	if e.is_empty():
		_picked.text = ""
		_button.disabled = true
		_button.text = "Buy"
	else:
		var item := Items.make(str(e.id))
		_picked.text = "[center][b]%s[/b][/center]" % (item.item_name if item else str(e.id))
		_button.disabled = _waiting > 0.0 or int(e.left) == 0 or dots < int(e.price) or not Net.is_client()
		_button.text = "Buying..." if _waiting > 0.0 else "Sold out" if int(e.left) == 0 else "Buy"
	_hint.text = "" if Net.is_client() else "Online or Singleplayer only"
	_hint.visible = _hint.text != ""
	_picked.visible = _picked.text != ""


func buy() -> void:
	var e := _entry()
	if e.is_empty() or _waiting > 0.0 or not Net.is_client(): return
	if Account.dots() < int(e.price) or int(e.left) == 0: return
	_waiting = 1.2
	GameAudio.play("ui.purchase" , Vector3.INF, {cooldown = 0.3})
	Net.client.send_action("shop", [shop_id, str(e.id), int(e.price)])
	_refresh_button()
