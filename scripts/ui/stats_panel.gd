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
	_add_row("Level", str(stats.level), "%d / %d XP" % [stats.xp, stats.xp_to_next()])
	_add_row("Health", "%d" % stats.max_hp, "")
	_add_row("Magic power", "%d" % stats.max_mp, "")
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 4)
	_rows.add_child(spacer)
	for stat in PlayerStats.STATS:
		var bonus := stats.gear_bonus(stat)
		var value := str(stats.base[stat])
		if bonus != 0:
			value += "  [color=#%s](%+d)[/color]" % [UIStyle.GOOD.to_html(false), bonus]
		if stats.total(stat) != int(stats.base[stat])+bonus:
			value = str(stats.total(stat)) # effective total while a buff/debuff changes it
		_add_row(PlayerStats.STAT_NAMES[stat], value, _effect(stat))


func _effect(stat: String) -> String:
	match stat:
		"speed":
			return "+%d%% move speed" % [stats.total("speed")]
		"dexterity":
			return "+%.0f%% fire rate" % [(stats.shots_per_second_multiplier() - 1.0) * 100.0]
		"attack":
			return "+%d%% weapon damage" % [stats.total("attack") * 2]
		"defense":
			return "-%d damage per hit" % [stats.total("defense")]
		"magic":
			return "shield holds %d damage" % [int(stats.shield_capacity())]
	return ""


func _add_row(title: String, value: String, note: String) -> void:
	var row := HBoxContainer.new()
	var name_label := UIStyle.label(title, UIStyle.SIZE_NORMAL, UIStyle.TEXT_DIM)
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
	var note_label := UIStyle.label(note, UIStyle.SIZE_SMALL, UIStyle.TEXT_DIM * Color(1, 1, 1, 0.8))
	note_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	note_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(note_label)
	_rows.add_child(row)
