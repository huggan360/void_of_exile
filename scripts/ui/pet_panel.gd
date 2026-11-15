class_name PetPanel
extends Control
## Caretaker entry: PetPanel.open_for(main). Main must expose player, world,
## and hud (Hud.add_dialog). Closing or leaving the Caretaker frees the panel.
var _main: Node
var _actor: Player
var _was_input_locked := false
var _selected := 0
var _second := 0
var _pending_select := 0
var _waiting := false
var _grid := GridContainer.new()
var _details := VBoxContainer.new()
var _title := UIStyle.heading("", 28)
var _balance := UIStyle.label("", 20, Dots.COLOR)
var _preview: SubViewport
var _preview_pet: PetFollower
var _preview_root := Node3D.new()
var _preview_key := ""
var _camera := Camera3D.new()
var _xp := ProgressBar.new()
var _xp_text := UIStyle.label("", 16, UIStyle.TEXT_DIM)
var _ability_labels: Array[Label] = []
var _feeds: Array[Button] = []
var _equip := UIStyle.button("Equip")
var _merge_pick := OptionButton.new()
var _merge_result := UIStyle.label("", 18)
var _merge_button := UIStyle.button("Confirm merge")
var _hint := UIStyle.label("", 16, UIStyle.TEXT_DIM)
var _content: HBoxContainer

static func open_for(main: Node) -> PetPanel:
	for node in main.get_tree().get_nodes_in_group("pet_panels"):
		if node is PetPanel: return node
	var panel := PetPanel.new()
	panel._main = main
	main.hud.add_dialog(panel)
	return panel

func _ready() -> void:
	add_to_group("pet_panels")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0.015, 0.02, 0.035, 0.87)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + side, 28)
	add_child(margin)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UIStyle.ornament_panel())
	margin.add_child(panel)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	panel.add_child(body)
	var top := HBoxContainer.new()
	body.add_child(top)
	var heading := UIStyle.heading("Caretaker", 30)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(heading)
	top.add_child(_balance)
	var close_button := UIStyle.button("Close")
	close_button.pressed.connect(close)
	top.add_child(close_button)
	_content = HBoxContainer.new()
	_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 24)
	body.add_child(_content)
	var collection := VBoxContainer.new()
	collection.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	collection.size_flags_stretch_ratio = 1.1
	_content.add_child(collection)
	collection.add_child(UIStyle.heading("Your pets", 22))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	collection.add_child(scroll)
	_grid.columns = 3
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override("h_separation", 8)
	_grid.add_theme_constant_override("v_separation", 8)
	scroll.add_child(_grid)
	var right_scroll := ScrollContainer.new()
	right_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_content.add_child(right_scroll)
	_details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_details.add_theme_constant_override("separation", 10)
	right_scroll.add_child(_details)
	_details.add_child(_title)
	_build_preview()
	_xp.show_percentage = false
	_xp.custom_minimum_size.y = 14
	_details.add_child(_xp)
	_details.add_child(_xp_text)
	for i in 2:
		var label := UIStyle.label("", 18)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_details.add_child(label)
		_ability_labels.append(label)
	var feed_row := HBoxContainer.new()
	_details.add_child(feed_row)
	for i in 3:
		var button := UIStyle.button("")
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 16)
		var choice := i
		button.pressed.connect(func() -> void: _feed(choice))
		feed_row.add_child(button)
		_feeds.append(button)
	_equip.pressed.connect(_do_equip)
	_details.add_child(_equip)
	_details.add_child(HSeparator.new())
	_details.add_child(UIStyle.heading("Merge", 22))
	_details.add_child(UIStyle.label("Choose a pet of the same species and rarity", 16, UIStyle.TEXT_DIM))
	_merge_pick.add_theme_font_override("font", UIStyle.font())
	_merge_pick.add_theme_font_size_override("font_size", 18)
	_merge_pick.item_selected.connect(func(index: int) -> void:
		_second = int(_merge_pick.get_item_metadata(index))
		_refresh_merge())
	_details.add_child(_merge_pick)
	_merge_result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_details.add_child(_merge_result)
	_merge_button.pressed.connect(_do_merge)
	_details.add_child(_merge_button)
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(_hint)
	PetsClient.changed.connect(_on_changed)
	Account.dots_changed.connect(_dots_changed)
	if is_instance_valid(_main) and is_instance_valid(_main.player):
		_actor = _main.player
		_was_input_locked = _actor.input_locked
		_actor.begin_interaction(get_instance_id())
		_actor.input_locked = true
	_rebuild()

func _build_preview() -> void:
	var container := SubViewportContainer.new()
	container.custom_minimum_size = Vector2(220, 195)
	container.stretch = true
	container.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_details.add_child(container)
	_preview = SubViewport.new()
	_preview.size = Vector2i(320, 195)
	_preview.own_world_3d = true
	_preview.transparent_bg = true
	_preview.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	container.add_child(_preview)
	_preview.add_child(_preview_root)
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("d6e1ff")
	env.ambient_light_energy = 0.8
	environment.environment = env
	_preview_root.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-40, -35, 0)
	light.light_energy = 1.5
	_preview_root.add_child(light)
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.size = 2.4
	_camera.position = Vector3(1.4, 1.3, 2.4)
	_preview_root.add_child(_camera)
	_camera.look_at(Vector3(0, 0.55, 0))
	_camera.current = true

func _on_changed() -> void:
	if _pending_select > 0 and not PetDefs.find(PetsClient.state, _pending_select).is_empty():
		_selected = _pending_select
		_second = 0
	_pending_select = 0
	_waiting = false
	_rebuild()

func _dots_changed(_total: int, _gained: int, _source: String) -> void:
	_refresh_details()

func _rebuild() -> void:
	for child in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()
	var state := PetsClient.state
	if PetDefs.find(state, _selected).is_empty():
		_selected = int(state.equipped)
		if _selected == 0 and not state.pets.is_empty(): _selected = int(state.pets[0].id)
	for pet: Dictionary in state.pets:
		var card := UIStyle.button("")
		card.custom_minimum_size = Vector2(155, 148)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var color: Color = PetDefs.RARITY_COLORS[pet.rarity]
		card.modulate = Color(1.2, 1.2, 1.1) if int(pet.id) == _selected else Color.WHITE
		var box := VBoxContainer.new()
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(box)
		box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		box.offset_left = 10
		box.offset_right = -10
		box.offset_top = 8
		box.offset_bottom = -8
		var name_label := UIStyle.heading(str(pet.name), 18, color)
		name_label.clip_text = true
		box.add_child(name_label)
		box.add_child(UIStyle.label(str(PetDefs.SPECIES[pet.species].name), 14, UIStyle.TEXT_DIM))
		box.add_child(UIStyle.label("%s  Level %d" % [str(pet.rarity).capitalize(), int(pet.level)], 15, color))
		for i in 2:
			var ability := str(pet.abilities[i])
			var chip := UIStyle.label(str(PetDefs.ABILITIES[ability].name), 14,
				PetDefs.ABILITIES[ability].color if i == 0 or int(pet.level) >= 30 else UIStyle.TEXT_DIM)
			chip.clip_text = true
			chip.tooltip_text = PetDefs.ability_text(ability, int(pet.level), str(pet.rarity))
			var chip_box := PanelContainer.new()
			var skin := StyleBoxFlat.new()
			skin.bg_color = Color(0.05, 0.065, 0.09, 0.85)
			skin.content_margin_left = 5
			skin.content_margin_right = 5
			chip_box.add_theme_stylebox_override("panel", skin)
			chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
			chip_box.add_child(chip)
			box.add_child(chip_box)
		if int(state.equipped) == int(pet.id): box.add_child(UIStyle.label("Equipped", 14, UIStyle.GOOD))
		for child in box.get_children(): child.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var id := int(pet.id)
		card.pressed.connect(func() -> void:
			_selected = id
			_second = 0
			_rebuild())
		_grid.add_child(card)
	_refresh_details()
	_build_merge_choices()

func _refresh_details() -> void:
	_balance.text = "%s Dots" % Dots.format(Account.dots())
	var pet := PetDefs.find(PetsClient.state, _selected)
	_details.visible = not pet.is_empty()
	_hint.text = "Hatch an egg at the nest to meet your first pet." if PetsClient.state.pets.is_empty() else "%d / %d pets" % [PetsClient.state.pets.size(), PetDefs.MAX_PETS]
	if pet.is_empty(): return
	_title.text = "%s  -  %s" % [str(pet.name), str(pet.rarity).capitalize()]
	_title.add_theme_color_override("font_color", PetDefs.RARITY_COLORS[pet.rarity])
	var key := "%s:%s" % [pet.species, pet.rarity]
	if key != _preview_key:
		_preview_key = key
		if is_instance_valid(_preview_pet): _preview_pet.queue_free()
		_preview_pet = PetFollower.new(pet)
		_preview_root.add_child(_preview_pet)
	_xp.max_value = PetDefs.xp_to_next(int(pet.level))
	_xp.value = float(pet.xp) if int(pet.level) < 50 else _xp.max_value
	_xp_text.text = "Level %d  -  %d / %d XP" % [int(pet.level), int(pet.xp), int(_xp.max_value)] if int(pet.level) < 50 else "Level 50  -  Max level"
	for i in 2:
		var ability := str(pet.abilities[i])
		var unlocked := i == 0 or int(pet.level) >= 30
		_ability_labels[i].text = str(PetDefs.ABILITIES[ability].name) + "\n" + PetDefs.ability_text(ability, int(pet.level), str(pet.rarity)) + ("\nUnlocks at level 30" if not unlocked else "")
		_ability_labels[i].add_theme_color_override("font_color", PetDefs.ABILITIES[ability].color if unlocked else UIStyle.TEXT_DIM)
	for i in 3:
		var count := _bite_count(pet, i)
		var price := count * PetDefs.BITE_DOTS
		_feeds[i].text = ("Feed 1" if i == 0 else "Feed 10" if i == 1 else "Feed to next level") + "\n%s Dots" % Dots.format(price)
		_feeds[i].disabled = _waiting or count == 0 or Account.dots() < price or not Net.is_client()
	_equip.text = "Unequip" if int(PetsClient.state.equipped) == _selected else "Equip"
	_equip.disabled = _waiting or not Net.is_client()
	_refresh_merge()

func _bite_count(pet: Dictionary, choice: int) -> int:
	return mini(PetDefs.bites_to_cap(pet), 1 if choice == 0 else 10 if choice == 1 else PetDefs.bites_to_next(pet))

func _build_merge_choices() -> void:
	_merge_pick.clear()
	_merge_pick.add_item("Choose second pet")
	_merge_pick.set_item_metadata(0, 0)
	var pet := PetDefs.find(PetsClient.state, _selected)
	if not pet.is_empty():
		for other: Dictionary in PetsClient.state.pets:
			if PetDefs.merge(pet, other).is_empty(): continue
			_merge_pick.add_item("%s  -  Level %d  -  %s" % [other.name, int(other.level), str(PetDefs.ABILITIES[other.abilities[0]].name)])
			var index := _merge_pick.item_count - 1
			_merge_pick.set_item_metadata(index, int(other.id))
			if int(other.id) == _second: _merge_pick.select(index)
	if _merge_pick.selected == 0: _second = 0
	_merge_pick.disabled = _merge_pick.item_count <= 1 or _waiting
	_refresh_merge()

func _refresh_merge() -> void:
	var pet := PetDefs.find(PetsClient.state, _selected)
	var result := PetDefs.merge(pet, PetDefs.find(PetsClient.state, _second))
	_merge_button.disabled = result.is_empty() or _waiting or not Net.is_client()
	if result.is_empty():
		_merge_result.text = "Divine pets cannot merge." if pet.get("rarity") == "divine" else "No matching pet." if _merge_pick.item_count <= 1 else ""
		return
	_merge_result.add_theme_color_override("font_color", PetDefs.RARITY_COLORS[result.rarity])
	_merge_result.text = "%s %s  -  Level %d\n%s + %s\nXP resets to 0. Both chosen pets become this pet." % [str(result.rarity).capitalize(), str(PetDefs.SPECIES[result.species].name), int(result.level), str(PetDefs.ABILITIES[result.abilities[0]].name), str(PetDefs.ABILITIES[result.abilities[1]].name)]

func _wait() -> void:
	_waiting = true
	_refresh_details()
	get_tree().create_timer(1.5).timeout.connect(func() -> void:
		if is_instance_valid(self):
			_waiting = false
			_pending_select = 0
			_refresh_details())

func _feed(choice: int) -> void:
	var pet := PetDefs.find(PetsClient.state, _selected)
	if pet.is_empty() or _waiting: return
	var bites := _bite_count(pet, choice)
	if bites <= 0 or Account.dots() < bites * PetDefs.BITE_DOTS: return
	_wait()
	PetsClient.feed(_selected, bites)

func _do_equip() -> void:
	if _waiting: return
	_wait()
	PetsClient.equip(0 if int(PetsClient.state.equipped) == _selected else _selected)

func _do_merge() -> void:
	if _waiting or PetDefs.merge(PetDefs.find(PetsClient.state, _selected), PetDefs.find(PetsClient.state, _second)).is_empty(): return
	var first := _selected
	var second := _second
	_wait()
	_pending_select = int(PetsClient.state.next_id)
	PetsClient.merge(first, second)

func _process(delta: float) -> void:
	if is_instance_valid(_preview_pet): _preview_pet.rotation.y += delta * 0.35
	if _content:
		_grid.columns = 3 if _content.size.x > 1120 else 2 if _content.size.x > 800 else 1
	if is_instance_valid(_main):
		if not is_instance_valid(_main.world) or not PetYardWorld.is_pet_yard(_main.world.realm_id) or not is_instance_valid(_main.player):
			close()
		elif _main.player.global_position.distance_to(PetYardWorld.CARETAKER_POS) > 5.5: close()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("menu"):
		close()
		get_viewport().set_input_as_handled()

func close() -> void:
	queue_free()

func _exit_tree() -> void:
	if is_instance_valid(_actor):
		_actor.end_interaction(get_instance_id())
		_actor.input_locked = _was_input_locked
