class_name StatsPanel
extends PanelContainer
## The Stats tab: level and XP, health and magic, then each stat as
## "base (+gear)" with a short note on what it currently does.

var stats: PlayerStats
var _rows := VBoxContainer.new()


func _init(p_stats: PlayerStats) -> void:
	stats = p_stats


func _ready() -> void:
	add_theme_stylebox_override("panel", UIStyle.panel())
	custom_minimum_size = Vector2(340, 0)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	add_child(box)
	box.add_child(UIStyle.heading("Stats"))
	var line := ColorRect.new()  # pixel divider
	line.color = UIStyle.BEVEL_LIGHT
	line.custom_minimum_size = Vector2(0, PixelArt.SCALE)
	box.add_child(line)
	_rows.add_theme_constant_override("separation", 6)
	box.add_child(_rows)
	stats.changed.connect(refresh)
	refresh()


func refresh() -> void:
	for child in _rows.get_children():
		child.queue_free()
	_add_row("Level", TextMarkup.color(str(stats.level), UIStyle.XP), "MAX" if stats.level >= PlayerStats.MAX_LEVEL else "%d / %d XP" % [stats.xp, stats.xp_to_next()], UIStyle.XP)
	_add_row("Health", _stat_value("hp"), "")
	_add_row("Magic points", _stat_value("mp"), "")
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 4)
	_rows.add_child(spacer)
	for stat in PlayerStats.STATS:
		_add_row(PlayerStats.STAT_NAMES[stat], _stat_value(stat), _effect(stat))


func _stat_value(stat: String) -> String:
	var value := stats.stat_display(stat).replace("#ffd56b", "#" + UIStyle.GOLD.to_html(false))
	return "[color=#%s]%s[/color]" % [UIStyle.stat_color(stat).to_html(false), value]


func _effect(stat: String) -> String:
	match stat:
		"speed":
			return "+%s%% move speed" % String.num((stats.move_speed_multiplier()-1.0)*100.0,2)
		"dexterity":
			return "+%s%% fire rate" % String.num((stats.dexterity_multiplier()-1.0)*100.0,2)
		"attack":
			return "+%s%% weapon damage" % String.num((stats.weapon_damage_multiplier()-1.0)*100.0,2)
		"defense":
			return "-%d damage per hit" % [stats.total("defense")]
		"magic":
			return "Shield: %s%% protection" % String.num(minf(99.99,stats.shield_reduction()*100.0),2)
	return ""


func _add_row(title: String, value: String, note: String, note_color := UIStyle.TEXT_DIM) -> void:
	var row := HBoxContainer.new()
	if title == PlayerStats.STAT_NAMES.magic:
		row.tooltip_text = "While held, MAG reduces regular projectile damage first, then Defence applies. Protection approaches 100% but never reaches it. Hits never break the shield; holding it drains MP. Magic projectiles are blocked completely."
	var name_label := UIStyle.label(title, UIStyle.SIZE_NORMAL, UIStyle.TEXT_DIM)
	name_label.add_theme_font_override("font", UIStyle.bold())
	name_label.custom_minimum_size = Vector2(110, 0)
	row.add_child(name_label)
	var value_label := RichTextLabel.new()
	value_label.bbcode_enabled = true
	value_label.fit_content = true
	value_label.scroll_active = false
	value_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	value_label.custom_minimum_size = Vector2(70, 0)
	value_label.add_theme_font_size_override("normal_font_size", UIStyle.SIZE_NORMAL)
	value_label.add_theme_font_size_override("bold_font_size", UIStyle.SIZE_NORMAL)
	value_label.text = "[b]%s[/b]" % value
	row.add_child(value_label)
	var note_label := UIStyle.label(note, UIStyle.SIZE_SMALL, note_color)
	note_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	note_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(note_label)
	_rows.add_child(row)
