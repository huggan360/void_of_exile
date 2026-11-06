class_name CharacterPicker
extends VBoxContainer
## Top left of the HUD: the character you play (its face, your name, class
## and level). Click it in the Tavern to open the picker:
##   Characters  every living character of the account: click one to play it,
##               × to delete it, New Character while there are free slots
##   Fallen      characters that died; click one for its full death record
## Outside the Tavern it only shows who you are (changing characters waits
## until you're back home).

signal switch_requested(character_id: int)
signal new_requested
signal record_requested(record: Dictionary)

var enabled := false:
	set(value):
		enabled = value
		_button.disabled = false
		_button.tooltip_text = "" if value else "Characters can be changed in the Tavern"
		_chevron.text = "▼" if value else ""
		if not value:
			_drop.hide()
var stats: PlayerStats

var _button := Button.new()
var _avatar := CharacterAvatar.new("archer", 64)
var _name := UIStyle.label("", 20, UIStyle.TEXT)
var _sub := UIStyle.rich("", 16)
var _chevron := UIStyle.label("▼", 16, UIStyle.ACCENT)
var _drop := PanelContainer.new()
var _tabs := TabContainer.new()
var _alive := VBoxContainer.new()
var _fallen := VBoxContainer.new()


func _init(p_stats: PlayerStats) -> void:
	stats = p_stats


func _ready() -> void:
	add_theme_constant_override("separation", 6)
	UIStyle.button_styles(_button, "ivy")
	_button.custom_minimum_size = Vector2(380, 106)
	_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_button.pressed.connect(_toggle)
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 10
	row.offset_right = -14
	row.offset_bottom = -6
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_avatar)
	var names := VBoxContainer.new()
	names.alignment = BoxContainer.ALIGNMENT_CENTER
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	names.mouse_filter = Control.MOUSE_FILTER_IGNORE
	names.add_child(_name)
	names.add_child(_sub)
	row.add_child(names)
	_chevron.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_chevron)
	_button.add_child(row)
	add_child(_button)

	_drop.add_theme_stylebox_override("panel", UIStyle.panel_outlined(UIStyle.GOLD))
	_drop.custom_minimum_size = Vector2(510, 0)
	_drop.z_index = 35
	_drop.hide()
	add_child(_drop)
	# Two toggle buttons pick the page; the TabContainer's own tab bar stays
	# hidden so there is no tab strip inside the panel.
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	_drop.add_child(column)
	var switcher := HBoxContainer.new()
	switcher.add_theme_constant_override("separation", 8)
	column.add_child(switcher)
	var group := ButtonGroup.new()
	var page_buttons: Array[Button] = []
	for i in 2:
		var page_button := UIStyle.button(["Characters", "Fallen"][i])
		page_button.toggle_mode = true
		page_button.button_group = group
		page_button.focus_mode = Control.FOCUS_NONE
		page_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		page_button.pressed.connect(func() -> void: _tabs.current_tab = i)
		switcher.add_child(page_button)
		page_buttons.append(page_button)
	page_buttons[0].set_pressed_no_signal(true)
	_tabs.tabs_visible = false
	_tabs.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	column.add_child(_tabs)
	for page: Array in [[_alive, "Characters"], [_fallen, "Fallen"]]:
		var scroll := ScrollContainer.new()
		scroll.name = page[1]
		scroll.custom_minimum_size = Vector2(490, 400)
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		(page[0] as VBoxContainer).add_theme_constant_override("separation", 6)
		(page[0] as VBoxContainer).size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.add_child(page[0])
		_tabs.add_child(scroll)
	_tabs.tab_changed.connect(func(tab: int) -> void:
		for i in page_buttons.size(): page_buttons[i].set_pressed_no_signal(i == tab)
		if tab == 1:
			_fill_fallen())
	Account.changed.connect(_refresh)
	stats.changed.connect(_refresh)
	_refresh()


## Opens the dropdown on the Characters tab.
func open() -> void:
	if not _drop.visible:
		_tabs.current_tab = 0
		_toggle()


func close_drop() -> void:
	_drop.hide()


func is_open() -> bool:
	return _drop.visible


func _refresh() -> void:
	_avatar.set_class(stats.class_id)
	_name.text = Account.username() if Account.username() != "" else "Adventurer"
	_sub.text = "%s - %s\n%s - %s" % [TextMarkup.escape(PlayerClasses.display_name(stats.class_id)),
		TextMarkup.color("Level %d" % stats.level, UIStyle.XP), UIStyle.stat_text("hp", stats.max_hp, false), UIStyle.stat_text("mp", stats.max_mp, false)]
	if _drop.visible and _tabs.current_tab == 0:
		_fill_alive()


func _toggle() -> void:
	if not enabled:
		return
	_drop.visible = not _drop.visible
	if _drop.visible:
		Account.refresh()
		_fill_alive()
		if _tabs.current_tab == 1:
			_fill_fallen()


func _fill_alive() -> void:
	for child in _alive.get_children():
		child.queue_free()
	# The account selection falls back to a survivor after death. Only the
	# connected character is actually in use.
	var playing := Net.client.character_id if Net.is_client() else 0
	for c: Dictionary in Account.characters():
		_alive.add_child(_alive_row(c, int(c.id) == playing))
	var used := Account.characters().size()
	var add := UIModal.button("New Character   (%d / %d slots)" % [used, Account.slots()], func() -> void:
		_drop.hide()
		new_requested.emit(), 400)
	add.disabled = used >= Account.slots()
	if add.disabled:
		add.tooltip_text = "Every slot is in use: higher account levels unlock more."
	_alive.add_child(add)


func _alive_row(c: Dictionary, playing: bool) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var b := Button.new()
	UIStyle.button_styles(b, "ivy")
	b.custom_minimum_size = Vector2(420, 108)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.disabled = playing
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var id := int(c.id)
	b.pressed.connect(func() -> void:
		_drop.hide()
		switch_requested.emit(id))
	var inside := HBoxContainer.new()
	inside.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inside.offset_left = 8
	inside.offset_bottom = -6
	inside.add_theme_constant_override("separation", 10)
	inside.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inside.add_child(CharacterAvatar.new(str(c.get("class", "archer")), 48))
	var text := VBoxContainer.new()
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inside.offset_right = -8
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var class_id := str(c.get("class", "archer"))
	text.add_child(UIStyle.rich("[b]%s[/b]  -  %s" % [TextMarkup.escape(PlayerClasses.display_name(class_id)),
		TextMarkup.color("Level %d" % int(c.level), UIStyle.XP)]))
	var shown := _row_stats(c, playing)
	for group: Array in [["hp", "mp"]]:
		var values := PackedStringArray()
		for stat: String in group:
			if shown == null:
				values.append("%s --" % PlayerStats.STAT_NAMES[stat])
			else:
				var value: int = shown.max_hp if stat == "hp" else shown.max_mp if stat == "mp" else shown.total(stat)
				values.append(UIStyle.stat_text(stat, value, false))
		text.add_child(UIStyle.rich("  -  ".join(values), 16))
	inside.add_child(text)
	b.add_child(inside)
	row.add_child(b)
	var x := UIStyle.button("×")
	x.custom_minimum_size = Vector2(52, 108)
	x.tooltip_text = "Delete this character"
	x.disabled = playing
	x.pressed.connect(func() -> void: _confirm_delete(c))
	row.add_child(x)
	return row


## Live totals for the connected character; saved permanent stats plus gear
## for everyone else. Both use the same stat calculation and row layout.
func _row_stats(c: Dictionary, playing: bool) -> PlayerStats:
	if playing: return stats
	var saved: Dictionary = c.get("stats", {})
	# Older account services cannot supply accurate trained character stats.
	if saved.is_empty() and int(c.get("level", 1)) > 1: return null
	var data := saved.duplicate(true)
	data.class_id = str(c.get("class", "archer"))
	data.level = int(c.get("level", 1))
	data.xp = int(c.get("xp", 0))
	var gear: Dictionary = c.get("gear", {})
	if not gear.is_empty():
		data.gear = {}
		for slot in gear:
			data.gear[slot] = {id = str(gear[slot]), count = 1} if gear[slot] != null else null
	var preview := PlayerStats.new()
	preview.load_data(data)
	return preview


func _confirm_delete(c: Dictionary) -> void:
	var dialog := UIModal.new("Delete character?", 520.0)
	dialog.body.add_child(UIStyle.label("%s (level %d) and everything it carries\nwill be gone for good." % [
			PlayerClasses.display_name(str(c.get("class", "archer"))), int(c.level)], 18, UIStyle.TEXT))
	dialog.buttons([UIModal.button("Keep it", dialog.close, 140), UIModal.button("Delete", func() -> void:
		await Account.delete_character(int(c.id))
		dialog.close()
		_fill_alive(), 140)])
	get_tree().root.add_child(dialog)


func _fill_fallen() -> void:
	for child in _fallen.get_children():
		child.queue_free()
	var loading := UIStyle.label("Looking up the fallen...", 16, UIStyle.TEXT_DIM)
	_fallen.add_child(loading)
	var dead: Array = await Account.graveyard()
	if not is_instance_valid(loading):
		return
	loading.queue_free()
	if dead.is_empty():
		_fallen.add_child(UIStyle.label("Nobody has fallen yet.", 16, UIStyle.TEXT_DIM))
	for d: Dictionary in dead:
		var b := Button.new()
		UIStyle.button_styles(b, "ivy")
		b.custom_minimum_size = Vector2(400, 100)
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		b.pressed.connect(func() -> void:
			_drop.hide()
			record_requested.emit(d))
		var inside := HBoxContainer.new()
		inside.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		inside.offset_left = 8
		inside.offset_bottom = -6
		inside.add_theme_constant_override("separation", 10)
		inside.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var face := CharacterAvatar.new(str(d.get("class", "archer")), 48)
		face.modulate = Color(0.7, 0.7, 0.75)
		inside.add_child(face)
		var text := VBoxContainer.new()
		text.alignment = BoxContainer.ALIGNMENT_CENTER
		text.mouse_filter = Control.MOUSE_FILTER_IGNORE
		text.add_child(UIStyle.label("%s  -  Level %d" % [PlayerClasses.display_name(str(d.get("class", "archer"))), int(d.level)], 17, UIStyle.TEXT))
		var killer := str(d.get("killed_by", ""))
		text.add_child(UIStyle.label("Killed by %s" % (killer if killer != "" else "something unseen"), 13, UIStyle.HP_LIGHT))
		inside.add_child(text)
		b.add_child(inside)
		_fallen.add_child(b)
