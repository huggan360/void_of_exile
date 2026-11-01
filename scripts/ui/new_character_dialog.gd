class_name NewCharacterDialog
extends UIModal
## Choose a class for a new character: each one with its portrait, what it
## wields and wears, and what it's like. Uses a character slot.

signal created(character_id: int)

var _status := UIStyle.label("", 16, UIStyle.TEXT_DIM)
var _busy := false
var _tooltip := ItemTooltip.new()


func _init() -> void:
	super._init("New Character", 1180.0)
	var used := Account.characters().size()
	body.add_child(UIStyle.label("Character slots: %d / %d   (account levels unlock more)" % [used, Account.slots()], 16, UIStyle.TEXT_DIM))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	body.add_child(row)
	for class_id: String in PlayerClasses.ORDER:
		row.add_child(_card(class_id))
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size.x = 900
	body.add_child(_status)
	if used >= Account.slots():
		_say("All your character slots are in use. Delete a character, or reach a higher account level for more.", UIStyle.HP_LIGHT)
	buttons([UIModal.button("Cancel", close, 130)])
	add_child(_tooltip)


func _card(class_id: String) -> Control:
	var def := PlayerClasses.get_def(class_id)
	var b := Button.new()
	UIStyle.button_styles(b)
	b.custom_minimum_size = Vector2(222, 560)
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
	var avatar := CharacterAvatar.new(class_id, 150, true)
	avatar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(avatar)
	var title := UIStyle.heading(def.name, 22, def.color)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	var gear := UIStyle.label("%s  ·  %s" % [def.weapon, def.armor], 14, UIStyle.GOLD)
	gear.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(gear)
	var about := UIStyle.label(def.about, 13, UIStyle.TEXT_DIM)
	about.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	about.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	about.mouse_filter = Control.MOUSE_FILTER_IGNORE
	about.custom_minimum_size.y = 52
	col.add_child(about)
	# Base stats, with what it grows best in marked.
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 0)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var best := 0
	for stat: String in PlayerStats.STATS:
		best = maxi(best, int(def.growth[stat]))
	var rows := [["Health", str(def.hp), false], ["Magic points", str(def.mp), false]]
	for stat: String in PlayerStats.STATS:
		rows.append([PlayerStats.STAT_NAMES[stat], str(def.base[stat]), int(def.growth[stat]) == best and best > 1])
	for r: Array in rows:
		var name_label := UIStyle.label(r[0], 13, UIStyle.GOLD if r[2] else UIStyle.TEXT_DIM)
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		grid.add_child(name_label)
		var value := UIStyle.label(r[1] + (" ▲" if r[2] else ""), 13, UIStyle.GOLD if r[2] else UIStyle.TEXT)
		value.mouse_filter = Control.MOUSE_FILTER_IGNORE
		grid.add_child(value)
	col.add_child(grid)
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
		s.hovered.connect(func(_x: ItemSlot, it: Item) -> void: _tooltip.show_item(it))
		s.unhovered.connect(_tooltip.hide)
		s.mouse_filter = Control.MOUSE_FILTER_PASS
		kit.add_child(s)
	col.add_child(UIStyle.label("Starts with", 12, UIStyle.TEXT_DIM))
	col.get_child(-1).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(kit)
	b.add_child(col)
	return b


func _create(class_id: String) -> void:
	if _busy:
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
