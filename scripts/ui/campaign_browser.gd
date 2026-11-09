class_name CampaignBrowser
extends PanelContainer
## The Chronicler's book of tales: each pack a mossy dropdown (its tales told
## so far), opening onto its tales as cards (stars, and a word on where the
## party stands: new, half told, completed, locked).
## Choosing one opens its page: the whole story, what each star asks, and
## Begin / Resume / Start over for the party leader.

const SIZE := Vector2(600, 520)

var social: SocialClient
var _runs := {}
var _open := ""  # the tale whose page is open ("" = the list)
var _body := VBoxContainer.new()
## Packs folded open, kept while the game runs.
static var _open_packs := {}


func _init(p_social: SocialClient) -> void:
	social = p_social


func _ready() -> void:
	custom_minimum_size = SIZE
	add_theme_stylebox_override("panel", UIStyle.ornament_panel())
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	add_child(column)
	var head := HBoxContainer.new()
	var title := UIStyle.heading("The Chronicler's Tales", 28)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	head.add_child(_button("Close", queue_free))
	column.add_child(head)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 8)
	scroll.add_child(_body)
	social.campaigns_listed.connect(func(runs: Dictionary) -> void:
		_runs = runs
		_fill())
	social.party_changed.connect(_fill)
	social.campaign(["list"])
	_fill()


func _fill() -> void:
	for child in _body.get_children():
		child.queue_free()
	if _open == "":
		_list()
	else:
		_page(_open)


## A run's state in words, and whether the tale can be played.
func _status(id: String) -> Array:
	var def := Campaigns.get_def(id)
	var run: Dictionary = _runs.get(id, {})
	var playing := social.campaign_state()
	if not playing.is_empty() and playing.id == id:
		return ["Playing", UIStyle.GOOD, true]
	if not Campaigns.unlocked(id, {runs = _runs}):
		if def.get("coming_soon", false):
			return ["Coming soon", UIStyle.TEXT_DIM, false]
		return ["Locked", UIStyle.TEXT_DIM, false]
	match str(run.get("status", "")):
		"paused", "active":
			return ["Half told  %d/%d" % [int(run.step) + 1, def.steps.size()], UIStyle.ACCENT, true]
		"done":
			return ["Completed", UIStyle.GOLD, true]
	return ["New", UIStyle.TEXT, true]


func _list() -> void:
	# The tales of each pack (in order), the unpacked ones last.
	var packs: Array = []
	var tales := {}
	for id: String in Campaigns.LIST:
		var def: Dictionary = Campaigns.LIST[id]
		# Hidden tales appear only once the one before them is told.
		if def.get("hidden", false) and str(_runs.get(str(def.get("requires", "")), {}).get("status", "")) != "done":
			continue
		var pack := str(def.get("pack", ""))
		if not tales.has(pack):
			tales[pack] = []
			packs.append(pack)
		tales[pack].append(id)
	if _open_packs.is_empty() and not packs.is_empty():
		var playing := social.campaign_state()
		var pick: String = packs[0]
		for pack: String in packs:
			for id: String in tales[pack]:
				if (not playing.is_empty() and playing.id == id) or str(_runs.get(id, {}).get("status", "")) in ["paused", "active"]: pick = pack
		_open_packs[pick] = true
	for pack: String in packs:
		_body.add_child(_pack_header(pack, tales[pack]))
		if _open_packs.get(pack, false):
			for id: String in tales[pack]: _body.add_child(_tale_card(id))


## A pack's mossy header: its name, tales told, and a fold mark; click to open.
func _pack_header(pack: String, ids: Array) -> Button:
	var header := Button.new()
	UIStyle.button_styles(header, "ivy")
	header.custom_minimum_size = Vector2(0, 56)
	header.focus_mode = Control.FOCUS_NONE
	header.pressed.connect(func() -> void:
		_open_packs[pack] = not _open_packs.get(pack, false)
		_fill())
	var told := ids.filter(func(id: String) -> bool: return str(_runs.get(id, {}).get("status", "")) == "done").size()
	var inside := HBoxContainer.new()
	inside.set_anchors_preset(Control.PRESET_FULL_RECT)
	inside.offset_left = 18
	inside.offset_right = -18
	inside.offset_bottom = -6
	inside.add_theme_constant_override("separation", 12)
	inside.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var title := UIStyle.label(str(Campaigns.PACKS[pack].title) if Campaigns.PACKS.has(pack) else "Other tales", UIStyle.SIZE_LARGE, UIStyle.GOLD)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	inside.add_child(title)
	var count := UIStyle.label("%d/%d" % [told, ids.size()], UIStyle.SIZE_NORMAL, UIStyle.TEXT_DIM)
	count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	inside.add_child(count)
	var fold := UIStyle.label("-" if _open_packs.get(pack, false) else "+", UIStyle.SIZE_LARGE, UIStyle.TEXT)
	fold.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	fold.custom_minimum_size.x = 14
	inside.add_child(fold)
	for child in inside.get_children(): (child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(inside)
	return header


## A tale in its pack: name, a word on how far the party is, its stars.
func _tale_card(id: String) -> Button:
	var def := Campaigns.get_def(id)
	var status := _status(id)
	var card := Button.new()
	UIStyle.button_styles(card)
	card.custom_minimum_size = Vector2(0, 64)
	card.focus_mode = Control.FOCUS_NONE
	card.disabled = not status[2] and not def.get("coming_soon", false)
	card.pressed.connect(func() -> void:
		_open = id
		_fill())
	var inside := HBoxContainer.new()
	inside.set_anchors_preset(Control.PRESET_FULL_RECT)
	inside.offset_left = 30
	inside.offset_right = -14
	inside.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	text.add_theme_constant_override("separation", 0)
	text.add_child(UIStyle.label(str(def.title), UIStyle.SIZE_NORMAL+2, UIStyle.TEXT if status[2] else UIStyle.TEXT_DIM))
	text.add_child(UIStyle.label(str(status[0]), UIStyle.SIZE_SMALL, status[1]))
	inside.add_child(text)
	var stars := StarRow.new(2.0)
	var best := int(_runs.get(id, {}).get("stars_best", 0))
	stars.set_stars(range(def.get("stars", []).size()).map(func(i: int) -> bool: return i < best))
	stars.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	stars.visible = not def.get("stars", []).is_empty()
	inside.add_child(stars)
	for node: Control in [text, stars]:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for child in node.get_children():
			if child is Control: (child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(inside)
	return card


## One tale's page.
func _page(id: String) -> void:
	var def := Campaigns.get_def(id)
	var status := _status(id)
	var run: Dictionary = _runs.get(id, {})
	_body.add_child(UIStyle.label(str(def.title), UIStyle.SIZE_LARGE, UIStyle.GOLD))
	_body.add_child(UIStyle.label(str(status[0]), UIStyle.SIZE_SMALL, status[1]))
	_body.add_child(_note(str(def.blurb), UIStyle.TEXT))
	var defs: Array = def.get("stars", [])
	if not defs.is_empty():
		var best := int(run.get("stars_best", 0))
		var stars := StarRow.new(3.0)
		stars.set_stars(range(5).map(func(i: int) -> bool: return i < best))
		_body.add_child(stars)
		for star: Dictionary in defs:
			_body.add_child(UIStyle.label("-  " + str(star.text), UIStyle.SIZE_SMALL, UIStyle.TEXT_DIM))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_theme_constant_override("separation", 8)
	row.add_child(_button("Back", func() -> void:
		_open = ""
		_fill()))
	var playing := social.campaign_state()
	if status[2] and social.is_leader() and (playing.is_empty() or playing.id != id):
		var half_told: bool = str(run.get("status", "")) in ["paused", "active"]
		if half_told:
			row.add_child(_button("Start over", func() -> void:
				social.campaign(["start", id, true])
				queue_free()))
		row.add_child(_button("Resume" if half_told else "Begin", func() -> void:
			social.campaign(["start", id])
			queue_free()))
	elif status[2] and not social.is_leader():
		_body.add_child(_note("Only your party's leader can begin a tale."))
	_body.add_child(row)


func _note(text: String, color := UIStyle.TEXT_DIM) -> Label:
	var label := UIStyle.label(text, UIStyle.SIZE_SMALL, color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _button(caption: String, action: Callable) -> Button:
	var b := UIStyle.button(caption)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(action)
	return b
