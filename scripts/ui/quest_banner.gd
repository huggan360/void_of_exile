class_name QuestBanner
extends PanelContainer
## The campaign your party plays, under the account bar (like a boss's bar):
## its title and time, the objective now (with where it is when that's in
## another place), the side quest, and the five stars still within reach.
## Clicking it opens its details: what each star asks, and for the leader
## Pause (kept, resumed at the Chronicler) and Abandon.

var social: SocialClient
## The place you're in ("hall", a realm id...), to say where objectives are.
var place := ""
## The HUD hides the objective while a boss health bar is on screen.
var hidden_by_boss := false
var _title := Label.new()
var _time := Label.new()
var _objective := Label.new()
var _side := Label.new()
var _stars := StarRow.new()
var _shown := ""
var _details := VBoxContainer.new()
var _confirm_abandon := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	tooltip_text = "Click for the campaign's details"
	add_theme_stylebox_override("panel", UIStyle.panel_outlined(UIStyle.GOLD))
	gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_toggle_details()
			accept_event())
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(column)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	column.add_child(head)
	UIStyle.text(_title, UIStyle.SIZE_NORMAL, UIStyle.GOLD)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_title)
	_stars.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(_stars)
	UIStyle.text(_time, UIStyle.SIZE_SMALL, UIStyle.TEXT_DIM)
	head.add_child(_time)
	for label: Label in [_objective, _side]:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		column.add_child(label)
	UIStyle.text(_objective, UIStyle.SIZE_NORMAL)
	UIStyle.text(_side, UIStyle.SIZE_SMALL, UIStyle.TEXT_DIM)
	_details.add_theme_constant_override("separation", 6)
	_details.hide()
	column.add_child(_details)
	hide()


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
		_details.add_child(UIStyle.label("·  " + str(star.text), UIStyle.SIZE_SMALL, UIStyle.TEXT_DIM))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_theme_constant_override("separation", 8)
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
		_details.add_child(UIStyle.label("Only the party leader can pause or abandon the tale.", UIStyle.SIZE_SMALL, UIStyle.TEXT_DIM))
		row.add_child(_button("Leave party", func() -> void:
			social.party_op("leave")
			_details.hide()))
	row.add_child(_button("Close", func() -> void: _details.hide()))
	_details.add_child(row)


func _button(caption: String, action: Callable) -> Button:
	var b := UIStyle.button(caption)
	b.add_theme_font_size_override("font_size", UIStyle.SIZE_SMALL)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(action)
	return b


func _process(_delta: float) -> void:
	var camp := social.campaign_state() if social else {}
	visible = not hidden_by_boss and not camp.is_empty() and camp.get("status", "") != "done"
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
			"no_deaths": kept.append(int(camp.deaths) == 0)
			_: kept.append(true)
	_stars.set_stars(kept)
	var key := "%s/%d/%d/%d/%s/%s" % [camp.id, camp.step, camp.count, camp.side_step, camp.side_done, place]
	if key == _shown:
		return
	_shown = key
	_title.text = str(camp.title)
	var step := Campaigns.step_def(camp.id, int(camp.step))
	_objective.text = Campaigns.objective_text(step, int(camp.count)) + _where(step)
	var side := Campaigns.step_def(camp.id, int(camp.side_step), true)
	_side.visible = not camp.side_done and not side.is_empty() and (int(camp.side_step) > 0 or Campaigns.is_campaign_realm(place))
	_side.text = "Side quest: " + Campaigns.objective_text(side, 0) + _where(side) if _side.visible else ""


## " (in the Tavern)" when an objective waits somewhere else.
func _where(step: Dictionary) -> String:
	if step.get("world", "") == "hall" and not place.begins_with("ctav_"):
		return "  (in your party's Tavern)"
	if step.get("world", "") == "campaign" and not Campaigns.is_campaign_realm(place) and step.get("kind", "") != "enter":
		return "  (through the Chronicle Gate)"
	return ""
