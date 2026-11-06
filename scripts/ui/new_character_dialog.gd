class_name NewCharacterDialog
extends UIModal
## Choose a class for a new character: each one with its portrait, what it
## wields and wears, and what it's like. Uses a character slot.

signal created(character_id: int)

var _status := UIStyle.label("", 16, UIStyle.TEXT_DIM)
var _busy := false
var _tooltip := ItemTooltip.new()
var _cards_scroll := ScrollContainer.new()


func _init() -> void:
	super._init("New Character", 1180.0)
	var used := Account.characters().size()
	body.add_child(UIStyle.label("Character slots: %d / %d   (account levels unlock more)" % [used, Account.slots()], 16, UIStyle.TEXT_DIM))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	_cards_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cards_scroll.custom_minimum_size.y = 480
	_cards_scroll.add_child(row)
	body.add_child(_cards_scroll)
	for class_id: String in PlayerClasses.ORDER:
		row.add_child(_card(class_id))
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size.x = 0
	body.add_child(_status)
	if used >= Account.slots():
		_say("All your character slots are in use. Delete a character, or reach a higher account level for more.", UIStyle.HP_LIGHT)
	buttons([UIModal.button("Cancel", close, 130)])
	add_child(_tooltip)


func _ready() -> void:
	super._ready()
	_fit_cards()
	get_viewport().size_changed.connect(_fit_cards)


func _fit_cards() -> void:
	var view := get_viewport_rect().size
	panel.custom_minimum_size.x = minf(1180.0, maxf(320.0, view.x - 40.0))
	_cards_scroll.custom_minimum_size.y = clampf(view.y - 240.0, 160.0, 610.0)


func _card(class_id: String) -> Control:
	var def := PlayerClasses.get_def(class_id)
	var b := Button.new()
	UIStyle.button_styles(b)
	b.custom_minimum_size = Vector2(222, 610)
	b.disabled = Account.characters().size() >= Account.slots()
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.pressed.connect(func() -> void: _create(class_id))
	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.offset_left = 10
	col.offset_right = -10
	col.offset_top = 10
	col.offset_bottom = -14
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 6)
	var avatar := CharacterAvatar.new(class_id, 112, true)
	avatar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(avatar)
	var title := UIStyle.heading(def.name, 22, def.color)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	var gear := UIStyle.label("%s  -  %s" % [def.weapon, def.armor], 16, UIStyle.TEXT_DIM)
	gear.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(gear)
	var about := UIStyle.label(def.about, 16, UIStyle.TEXT_DIM)
	about.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	about.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	about.mouse_filter = Control.MOUSE_FILTER_IGNORE
	about.custom_minimum_size.y = 94
	col.add_child(about)
	var playstyles := {"archer": "Aim from a distance", "wizard": "Strike, then evade",
		"priest": "Shield and sustain", "alchemist": "Move and keep firing", "merrow": "Hold your ground"}
	var playstyle := UIStyle.label(playstyles[class_id], 16, UIStyle.PROJECTILE)
	playstyle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(playstyle)
	col.add_child(UIStyle.label("Starting stats", 16, UIStyle.TEXT_DIM))
	var rows := PackedStringArray()
	rows.append(UIStyle.stat_text("hp", int(def.hp), false) + "  -  " + UIStyle.stat_text("mp", int(def.mp), false))
	rows.append(UIStyle.stat_text("attack", int(def.base.attack), false) + "  -  " + UIStyle.stat_text("defense", int(def.base.defense), false))
	rows.append(UIStyle.stat_text("speed", int(def.base.speed), false) + "  -  " + UIStyle.stat_text("dexterity", int(def.base.dexterity), false))
	rows.append(UIStyle.stat_text("magic", int(def.base.magic), false))
	col.add_child(UIStyle.rich("[b]" + "\n".join(rows) + "[/b]"))
	var best := 0
	for stat: String in PlayerStats.STATS:
		best = maxi(best, int(def.growth[stat]))
	var strengths := PackedStringArray()
	for stat: String in PlayerStats.STATS:
		if int(def.growth[stat]) == best:
			strengths.append(PlayerStats.STAT_NAMES[stat])
	col.add_child(UIStyle.rich("[b]Class strengths[/b]\n" + " - ".join(strengths)))
	# What it starts with (hover for details).
	var kit := HBoxContainer.new()
	kit.alignment = BoxContainer.ALIGNMENT_CENTER
	kit.add_theme_constant_override("separation", 4)
	var kit_gear := PlayerClasses.starting_gear(class_id)
	for slot: String in ["weapon", "armor", "spell"]:
		var s := ItemSlot.new(slot.capitalize())
		s.set_item(kit_gear[slot])
		s.scale = Vector2.ONE * 0.62
		s.custom_minimum_size *= 0.62
		s.hovered.connect(func(_x: ItemSlot, it: Item) -> void:
			var preview := PlayerStats.new()
			preview.class_id = class_id
			preview.reset()
			_tooltip.stats = preview
			_tooltip.show_item(it))
		s.unhovered.connect(_tooltip.hide)
		s.mouse_filter = Control.MOUSE_FILTER_PASS
		kit.add_child(s)
	col.add_child(UIStyle.label("Starting gear", 16, UIStyle.TEXT_DIM))
	col.get_child(-1).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(kit)
	b.add_child(col)
	return b


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
