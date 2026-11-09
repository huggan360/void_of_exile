class_name DeathRecord
extends Control
## A fallen character, full screen: who it was, what killed it and where,
## the stats and level it reached, everything it carried when it died, and
## what its death gave the account (25% of all its XP plus the worth of what
## it carried). Shown when you die, and from the Fallen tab of the character
## picker (where the record can also be deleted).

signal closed
signal deleted(character_id: int)
## Just died (death mode): "another" (play another character) or "new".
signal chosen(choice: String)

var record: Dictionary
var _tooltip := ItemTooltip.new()
var _stats := PlayerStats.new()
var _closing := false


## record: a dead character from the account service ({id, class, level,
## killed_by, realm, died, account_xp, data}) or from the server's death
## message. can_delete: show "Delete record". just_died: the death screen
## (the world and the blood stay visible behind it, and it offers to play
## another character or make a new one).
func _init(p_record: Dictionary, can_delete := true, continue_text := "Close", just_died := false) -> void:
	record = p_record
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var data: Dictionary = record.get("data", {})
	_stats.class_id = str(record.get("class", data.get("class_id", "archer")))
	_stats.reset()
	_stats.load_data(data)
	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.0, 0.02, 0.55) if just_died else Color(0.03, 0.02, 0.06, 0.94)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UIStyle.panel_outlined(UIStyle.HP))
	center.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	col.custom_minimum_size.x = 980
	panel.add_child(col)

	# Who, and how it ended.
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 22)
	col.add_child(top)
	top.add_child(CharacterAvatar.new(_stats.class_id, 170, true))
	var who := VBoxContainer.new()
	who.alignment = BoxContainer.ALIGNMENT_CENTER
	who.add_theme_constant_override("separation", 6)
	who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(who)
	who.add_child(UIStyle.label("FALLEN", 16, UIStyle.HP_LIGHT))
	who.add_child(UIStyle.heading(PlayerClasses.display_name(_stats.class_id), 38, PlayerClasses.get_def(_stats.class_id).color))
	who.add_child(UIStyle.label("Level %d" % int(record.get("level", _stats.level)), 24, UIStyle.TEXT))
	var killer := str(record.get("killed_by", ""))
	var place := str(record.get("realm", "")).replace("realm_1", "the Surface").replace("realm_", "the Surface ").replace("hall", "the Tavern")
	who.add_child(UIStyle.label("Killed by %s%s" % [killer if killer != "" else "something unseen", "  in " + place if place != "" else ""], 20, UIStyle.TEXT))
	var died := float(record.get("died", 0.0))
	if died > 0.0:
		who.add_child(UIStyle.label(Time.get_datetime_string_from_unix_time(int(died) + _utc_offset(), true), 16, UIStyle.TEXT_DIM))
	var bonus := int(record.get("account_xp", 0))
	if bonus > 0:
		var parts := ""
		if record.has("items_xp"):
			parts = "   (items carried %d  +  25%% of its XP %d)" % [int(record.items_xp), int(record.share_xp)]
		who.add_child(UIStyle.label("+%d account XP%s" % [bonus, parts], 18, UIStyle.XP))

	# Stats at death.
	col.add_child(UIStyle.heading("Stats", 22))
	var grid := GridContainer.new()
	grid.columns = 7
	grid.add_theme_constant_override("h_separation", 26)
	col.add_child(grid)
	for entry: Array in [["Max HP", _stats.max_hp], ["Max MP", _stats.max_mp]]:
		grid.add_child(_stat(entry[0], entry[1]))
	for stat: String in PlayerStats.STATS:
		grid.add_child(_stat(PlayerStats.STAT_NAMES[stat], _stats.total(stat)))

	# Everything it carried.
	col.add_child(UIStyle.heading("Carried when it fell", 22))
	var gear := HBoxContainer.new()
	gear.add_theme_constant_override("separation", 6)
	for slot: String in PlayerStats.GEAR_SLOTS:
		gear.add_child(_slot(_stats.gear.get(slot), slot.capitalize()))
	gear.add_child(_spacer(26))
	for item: Variant in _stats.quick:
		gear.add_child(_slot(item, "Quickslot"))
	col.add_child(gear)
	var pack := GridContainer.new()
	pack.columns = 8
	pack.add_theme_constant_override("h_separation", 6)
	pack.add_theme_constant_override("v_separation", 6)
	for item: Variant in _stats.backpack:
		pack.add_child(_slot(item, ""))
	col.add_child(pack)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_theme_constant_override("separation", 12)
	if can_delete:
		row.add_child(UIModal.button("Delete record", _delete, 180))
	if just_died:
		var others := Account.characters().filter(func(c: Dictionary) -> bool:
			return int(c.id) != int(record.get("id", 0)))
		var another := UIModal.button("Play another character", func() -> void: _choose("another"), 280)
		another.disabled = others.is_empty()
		if another.disabled:
			another.tooltip_text = "You have no other living characters."
		row.add_child(another)
		row.add_child(UIModal.button("Create a new character", func() -> void: _choose("new"), 280))
	else:
		row.add_child(UIModal.button(continue_text, close, 160))
	col.add_child(row)
	_tooltip.stats = _stats
	add_child(_tooltip)


func _ready() -> void:
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.35)


func close() -> void:
	if _closing:
		return
	_closing = true
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.15)
	await tw.finished
	hide()
	closed.emit()
	queue_free()


func _choose(choice: String) -> void:
	if _closing:
		return
	await close()
	chosen.emit(choice)


func _delete() -> void:
	var id := int(record.get("id", 0))
	if await Account.delete_dead(id):
		deleted.emit(id)
		close()


func _stat(caption: String, value: int) -> Control:
	var box := VBoxContainer.new()
	box.add_child(UIStyle.label(caption, 14, UIStyle.TEXT_DIM))
	box.add_child(UIStyle.heading(str(value), 26, UIStyle.HP_LIGHT if caption == "Max HP" else UIStyle.MP if caption == "Max MP" else UIStyle.STAT))
	return box


func _slot(item: Variant, caption: String) -> ItemSlot:
	var slot := ItemSlot.new(caption)  # no stats: read only
	slot.set_item(item)
	slot.hovered.connect(func(_s: ItemSlot, it: Item) -> void: _tooltip.show_item(it))
	slot.unhovered.connect(_tooltip.hide)
	return slot


func _spacer(width: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size.x = width
	return c


static func _utc_offset() -> int:
	return int(Time.get_time_zone_from_system().get("bias", 0)) * 60
