class_name NewCharacterDialog
extends UIModal
## Choose a class for a new character: one plain card per class with its
## portrait, name and playstyle, its starting stats, the gear it starts with
## (hover a slot for details) and Choose. The class's description is the
## card's tooltip. Uses a character slot.

signal created(character_id: int)

const CARD := Vector2(248, 0)
const GAP := 12
const PLAYSTYLES := {archer = "Aim from a distance", wizard = "Strike, then evade",
	priest = "Shield and sustain", alchemist = "Move and keep firing", merrow = "Hold your ground"}

var _status := UIStyle.label("", 16, UIStyle.TEXT_DIM)
var _busy := false
var _tooltip := ItemTooltip.new()
var _cards_scroll := ScrollContainer.new()


func _init() -> void:
	super._init("New Character", 1420.0)
	var used := Account.characters().size()
	var slots := UIStyle.label("Slots %d / %d" % [used, Account.slots()], 16, UIStyle.TEXT_DIM)
	slots.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(slots)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", GAP)
	_cards_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cards_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_cards_scroll.add_child(row)
	body.add_child(_cards_scroll)
	for class_id: String in PlayerClasses.ORDER:
		row.add_child(_card(class_id))
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(_status)
	if used >= Account.slots():
		_say("All your character slots are in use.", UIStyle.HP_LIGHT)
	buttons([UIModal.button("Cancel", close, 130)])
	add_child(_tooltip)


func _ready() -> void:
	super._ready()
	_fit_cards()
	get_viewport().size_changed.connect(_fit_cards)


func _fit_cards() -> void:
	var view := get_viewport_rect().size
	var full := PlayerClasses.ORDER.size()*(CARD.x+GAP)+120.0
	panel.custom_minimum_size.x = minf(full, maxf(320.0, view.x-40.0))
	_cards_scroll.custom_minimum_size.y = clampf(view.y-260.0, 200.0, 540.0)


func _card(class_id: String) -> Control:
	var def := PlayerClasses.get_def(class_id)
	var accent: Color = def.color
	var full := Account.characters().size() >= Account.slots()
	var card := PanelContainer.new()
	card.custom_minimum_size = CARD
	card.tooltip_text = str(def.about)
	var calm := _card_style(accent, false)
	var lit := _card_style(accent, true)
	card.add_theme_stylebox_override("panel", calm)
	card.mouse_entered.connect(func() -> void: card.add_theme_stylebox_override("panel", lit))
	card.mouse_exited.connect(func() -> void: card.add_theme_stylebox_override("panel", calm))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	card.add_child(col)
	var avatar := CharacterAvatar.new(class_id, 120, true)
	avatar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(avatar)
	var title := UIStyle.heading(def.name, 26, accent)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	var playstyle := UIStyle.label(str(PLAYSTYLES.get(class_id, "")), 16, UIStyle.TEXT_DIM)
	playstyle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(playstyle)
	col.add_child(_rule(accent))
	# Starting stats, two to a row.
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 4)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var values := {hp = int(def.hp), mp = int(def.mp)}
	for stat: String in ["attack", "defense", "speed", "dexterity", "magic"]: values[stat] = int(def.base[stat])
	for stat: String in values:
		var cell := HBoxContainer.new()
		cell.custom_minimum_size.x = 100
		cell.add_theme_constant_override("separation", 6)
		var value := UIStyle.label(str(values[stat]), 16, Color.WHITE)
		value.add_theme_font_override("font", UIStyle.bold())
		value.custom_minimum_size.x = 30
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		cell.add_child(value)
		cell.add_child(UIStyle.label(UIStyle.stat_name(stat), 16, UIStyle.stat_color(stat)))
		grid.add_child(cell)
	col.add_child(grid)
	col.add_child(_rule(accent))
	# The gear it starts with, at full size (hover for details).
	var kit := HBoxContainer.new()
	kit.alignment = BoxContainer.ALIGNMENT_CENTER
	kit.add_theme_constant_override("separation", 6)
	var kit_gear := PlayerClasses.starting_gear(class_id)
	for slot: String in ["weapon", "armor", "spell"]:
		var s := ItemSlot.new(slot.capitalize())
		s.set_item(kit_gear[slot])
		s.hovered.connect(func(_x: ItemSlot, it: Item) -> void:
			var preview := PlayerStats.new()
			preview.class_id = class_id
			preview.reset()
			_tooltip.stats = preview
			_tooltip.show_item(it))
		s.unhovered.connect(_tooltip.hide)
		s.mouse_filter = Control.MOUSE_FILTER_PASS
		kit.add_child(s)
	col.add_child(kit)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(spacer)
	var choose := UIModal.button("Choose", func() -> void: _create(class_id), 180)
	choose.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	choose.disabled = full
	col.add_child(choose)
	return card


## A plain dark card with a thin border in the class's colour (brighter on hover).
func _card_style(accent: Color, hovered: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.06, 0.09, 0.92) if not hovered else Color(0.08, 0.09, 0.13, 0.95)
	style.border_color = Color(accent, 0.85) if hovered else Color(accent.darkened(0.45), 0.7)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	return style


func _rule(accent: Color) -> Control:
	var line := ColorRect.new()
	line.color = Color(accent, 0.25)
	line.custom_minimum_size = Vector2(0, 1)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return line


func _create(class_id: String) -> void:
	if _busy or Account.characters().size() >= Account.slots():
		return
	_busy = true
	_say("Creating a %s..." % PlayerClasses.display_name(class_id))
	var r: Dictionary = await Account.create_character(class_id)
	_busy = false
	if not r.ok:
		_say(r.error, UIStyle.HP_LIGHT)
		return
	created.emit(int(r.data.id))
	close()


func _say(text: String, color := UIStyle.TEXT_DIM) -> void:
	_status.text = text
	_status.add_theme_color_override("font_color", color)
	_status.visible = text != ""
