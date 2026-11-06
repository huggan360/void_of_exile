class_name QuestBanner
extends PanelContainer
## Campaign objectives at the left edge below the character picker. Clicking opens details,
## pause and abandon controls while the banner keeps the main and side goals
## readable at a glance.

const MAIN_COLOR := UIStyle.GOLD
const SIDE_COLOR := UIStyle.GOOD
const OBJECTIVE_SIZE := 22

var social: SocialClient
var boss_visible := false
## The place you're in ("hall", a realm id...), to say where objectives are.
var place := ""
var _title := Label.new()
var _time := Label.new()
var _main_heading := Label.new()
var _objective := Label.new()
var _main_destination := Label.new()
var _side_heading := Label.new()
var _side := Label.new()
var _side_destination := Label.new()
var _main_section := HBoxContainer.new()
var _side_section := HBoxContainer.new()
var _section_divider: HSeparator
var _stars := StarRow.new()
var _shown := ""
var _details := VBoxContainer.new()
var _confirm_abandon := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	tooltip_text = "Click for the campaign's details"
	add_theme_stylebox_override("panel", UIStyle.panel_outlined(MAIN_COLOR))
	gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_toggle_details()
			accept_event())
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 5)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(column)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	column.add_child(head)
	UIStyle.text(_title, 20, MAIN_COLOR)
	_title.clip_text = true
	_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_title)
	_stars.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(_stars)
	UIStyle.text(_time, UIStyle.SIZE_SMALL, UIStyle.TEXT_DIM)
	head.add_child(_time)

	_configure_section(_main_section, _main_heading, "MAIN QUEST", _objective, _main_destination, MAIN_COLOR)
	column.add_child(_main_section)
	_section_divider = _divider(MAIN_COLOR)
	column.add_child(_section_divider)
	_configure_section(_side_section, _side_heading, "SIDE QUEST", _side, _side_destination, SIDE_COLOR)
	column.add_child(_side_section)
	_details.add_theme_constant_override("separation", 6)
	_details.hide()
	column.add_child(_details)
	hide()


func _configure_section(section: HBoxContainer, heading: Label, heading_text: String,
		objective: Label, destination: Label, accent: Color) -> void:
	section.add_theme_constant_override("separation", 8)
	section.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var marker := ColorRect.new()
	marker.color = accent
	marker.custom_minimum_size = Vector2(4, 0)
	marker.size_flags_vertical = Control.SIZE_EXPAND_FILL
	marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	section.add_child(marker)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 0)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	section.add_child(content)
	heading.text = heading_text
	UIStyle.text(heading, 15, accent)
	heading.add_theme_font_override("font", UIStyle.bold())
	content.add_child(heading)
	objective.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	objective.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	objective.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UIStyle.text(objective, OBJECTIVE_SIZE, accent)
	objective.add_theme_font_override("font", UIStyle.bold())
	content.add_child(objective)
	destination.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	destination.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	destination.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UIStyle.text(destination, UIStyle.SIZE_SMALL, accent.lightened(0.12))
	content.add_child(destination)


func _divider(color: Color) -> HSeparator:
	var line := HSeparator.new()
	var style := StyleBoxLine.new()
	style.color = color.darkened(0.28)
	style.thickness = 2
	line.add_theme_stylebox_override("separator", style)
	line.add_theme_constant_override("separation", 2)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return line


func _toggle_details() -> void:
	_details.visible = not _details.visible
	_confirm_abandon = false
	_fill_details()


func _fill_details() -> void:
	for child in _details.get_children():
		child.queue_free()
	var camp := social.campaign_state()
	if not _details.visible or camp.is_empty():
		return
	_details.add_child(HSeparator.new())
	for star: Dictionary in Campaigns.get_def(camp.id).get("stars", []):
		_details.add_child(_detail_label("-  " + str(star.text)))
	var row := HFlowContainer.new()
	row.alignment = FlowContainer.ALIGNMENT_END
	row.add_theme_constant_override("h_separation", 8)
	row.add_theme_constant_override("v_separation", 8)
	if social.is_leader():
		row.add_child(_button("Pause", func() -> void:
			social.campaign(["pause"])
			_details.hide()))
		row.add_child(_button("Click again to abandon" if _confirm_abandon else "Abandon", func() -> void:
			if _confirm_abandon:
				social.campaign(["abandon"])
				_details.hide()
			else:
				_confirm_abandon = true
				_fill_details()))
	else:
		_details.add_child(_detail_label("Only the party leader can pause or abandon the tale."))
		row.add_child(_button("Leave party", func() -> void:
			social.party_op("leave")
			_details.hide()))
	row.add_child(_button("Close", func() -> void: _details.hide()))
	_details.add_child(row)


func _detail_label(caption: String) -> Label:
	var label := UIStyle.label(caption, UIStyle.SIZE_SMALL, UIStyle.TEXT_DIM)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label


func _button(caption: String, action: Callable) -> Button:
	var b := UIStyle.button(caption)
	b.add_theme_font_size_override("font_size", UIStyle.SIZE_SMALL)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(action)
	return b


func _process(_delta: float) -> void:
	var camp := social.campaign_state() if social else {}
	visible = not boss_visible and not camp.is_empty() and camp.get("status", "") != "done"
	if not visible:
		_details.hide()
		return
	var elapsed := social.campaign_elapsed()
	_time.text = "%d:%02d" % [int(elapsed) / 60, int(elapsed) % 60]
	# Stars: lost ones go dark (deaths); the time stars dim once missed.
	var kept: Array = []
	for star: Dictionary in Campaigns.get_def(camp.id).get("stars", []):
		match str(star.id):
			"time": kept.append(elapsed <= float(star.seconds))
			"no_deaths": kept.append(int(camp.get("deaths", 0)) == 0)
			_: kept.append(true)
	_stars.set_stars(kept)
	var step := Campaigns.step_def(camp.id, int(camp.get("step", 0)))
	var side_step := Campaigns.step_def(camp.id, int(camp.get("side_step", 0)), true)
	var side_visible := not bool(camp.get("side_done", false)) and not side_step.is_empty()
	var player_id := int(Net.client.info.get("player_id", 0)) if Net.is_client() else 0
	var key := "%s/%s/%d/%d/%d/%s/%s/%s" % [camp.get("id", ""), camp.get("title", ""),
		int(camp.get("step", 0)), int(camp.get("count", 0)), int(camp.get("side_step", 0)),
		str(camp.get("side_done", false)), place, str(side_visible)] + JSON.stringify(camp.get("home_progress", {})) + JSON.stringify(camp.get("astral",{})) + "/" + str(player_id)
	if key == _shown:
		return
	_title.text = str(camp.get("title", ""))
	_objective.text = Campaigns.objective_text(step, int(camp.get("count", 0)), camp.get("home_progress", {}), player_id)
	if step.kind=="astral_board":
		var launch: Dictionary=camp.get("astral",{})
		_objective.text="Launching for the Aurora..." if not launch.get("flight",{}).is_empty() else "Board the magic rocket (%d/%d aboard). Waiting for your party." % [launch.get("boarded",[]).size(),int(launch.get("required",1))]
	_main_destination.text = _where(step)
	_main_destination.visible = not _main_destination.text.is_empty()
	_side_section.visible = side_visible
	_section_divider.visible = side_visible
	if side_visible:
		_side.text = Campaigns.objective_text(side_step, 0)
		_side_destination.text = _where(side_step)
		_side_destination.visible = not _side_destination.text.is_empty()
	if _details.visible:
		_fill_details()
	_shown = key


## Keep destination information on its own subdued line, away from the goal.
func _where(step: Dictionary) -> String:
	match str(step.get("world", "")):
		"hall":
			return "Your party's Tavern" if not Campaigns.is_tavern(place) else ""
		"campaign":
			if Campaigns.is_campaign_realm(place):
				return ""
			return "Chronicle Gate" if step.get("kind", "") == "enter" and Campaigns.is_tavern(place) else "Campaign realm"
		"castle":
			return "Hollow Castle" if not Campaigns.is_castle(place) else ""
		"dungeon":
			return "Story dungeon" if not Dungeons.is_dungeon(place) else ""
	return ""
