class_name ShopPanel
extends PanelContainer
## A shopkeeper's wares (ShopKeeper, Shops): on the right while you talk to
## them, your backpack on the left. Every item with its price in Dots, offers
## struck through and highlighted, rare pieces marked "1 left". Pick one and
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
var _subtitle := UIStyle.label("", UIStyle.SIZE_SMALL, UIStyle.TEXT_DIM)
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
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_subtitle)
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
	_button.add_theme_font_override("font", UIStyle.bold())
	_button.add_theme_font_size_override("font_size", 20)
	_button.custom_minimum_size = Vector2(220, 46)
	_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = {normal = Color(0.14, 0.55, 0.26), hover = Color(0.2, 0.68, 0.32), pressed = Color(0.1, 0.42, 0.2),
				disabled = Color(0.18, 0.26, 0.22), focus = Color(0.14, 0.55, 0.26)}[state]
		style.border_color = Color(0.6, 1.0, 0.65) if state != "disabled" else Color(0.3, 0.42, 0.34)
		style.set_border_width_all(2)
		style.set_corner_radius_all(4)
		style.set_content_margin_all(8)
		if state == "focus": style.draw_center = false
		_button.add_theme_stylebox_override(state, style)
	_button.add_theme_color_override("font_disabled_color", Color(0.6, 0.7, 0.62))
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
	_subtitle.text = str(def.get("title", ""))
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
		var price := UIStyle.rich("", UIStyle.SIZE_SMALL)
		price.fit_content = true
		price.custom_minimum_size.x = 80
		var text := "[center]"
		if int(e.off) > 0: text += "[s][color=#a7b8cd]%s[/color][/s] " % Dots.format(int(e.base))
		text += "[b][color=#%s]%s[/color][/b]" % [Dots.COLOR.to_html(false), Dots.format(int(e.price))]
		if int(e.left) == 0: text += "\n[color=#ff8080]sold out[/color]"
		elif int(e.left) > 0: text += "\n[color=#ffd84a]1 left[/color]"
		price.text = text+"[/center]"
		cell.add_child(price)
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
		_picked.text = "[center][color=#a7b8cd]Pick something to buy.[/color][/center]"
		_button.disabled = true
		_button.text = "Buy"
	else:
		var item := Items.make(str(e.id))
		var price := int(e.price)
		_picked.text = "[center][b]%s[/b]  for  [b][color=#%s]%s Dots[/color][/b]%s[/center]" % [item.item_name if item else str(e.id),
			Dots.COLOR.to_html(false), Dots.format(price), ("  [color=#ffd84a](%d%% off)[/color]" % int(e.off)) if int(e.off) > 0 else ""]
		_button.disabled = _waiting > 0.0 or int(e.left) == 0 or dots < price or not Net.is_client()
		_button.text = "Buying..." if _waiting > 0.0 else "Sold out" if int(e.left) == 0 else "Buy"
	if not Net.is_client():
		_hint.text = "Shops sell when you play online or in Singleplayer."
	elif not e.is_empty() and dots < int(e.price):
		_hint.text = "You have %s Dots. Sell things at a smith's forge for more." % Dots.format(dots)
	else:
		_hint.text = "You have %s Dots. Prices are the same in every world." % Dots.format(dots)


func buy() -> void:
	var e := _entry()
	if e.is_empty() or _waiting > 0.0 or not Net.is_client(): return
	if Account.dots() < int(e.price) or int(e.left) == 0: return
	_waiting = 1.2
	GameAudio.play("ui.purchase" , Vector3.INF, {cooldown = 0.3})
	Net.client.send_action("shop", [shop_id, str(e.id), int(e.price)])
	_refresh_button()
