class_name PetPanel
extends Control
## The Caretaker's page. Left: every pet as a portrait tile (level, a thin XP
## bar, rarity edge). Right: the chosen pet turning slowly, its level ring,
## its two abilities on one line each, and Feed / Lead / Merge. Kept minimal:
## no explanations. PetPanel.open_for(main); Main must expose player, world
## and hud (Hud.add_dialog). Closing or leaving the Caretaker frees it.
const TILE := 96.0
const COLUMNS := 5
const SIDE := 400.0
## How high PetFollower holds the flying gaits, to keep them in the preview.
const HOVER := {flap = 0.9, glide = 1.05, float = 0.55, pulse = 0.8, swim = 0.8}
var _main: Node
var _actor: Player
var _was_input_locked := false
var _selected := 0
var _partner := 0
var _merging := false
var _pending_select := 0
var _waiting := false
var _grid := GridContainer.new()
var _count := UIStyle.label("", UIStyle.SIZE_SMALL, UIStyle.TEXT_DIM)
var _balance := DotsCounter.amount(0, 22)
var _side := VBoxContainer.new()
var _empty := VBoxContainer.new()
var _preview: SubViewport
var _preview_pet: PetFollower
var _preview_root := Node3D.new()
var _preview_key := ""
var _camera := Camera3D.new()
var _ring := XpRing.new()
var _name := UIStyle.heading("", 30)
var _rarity := UIStyle.label("", 18)
var _xp_text := UIStyle.label("", UIStyle.SIZE_SMALL, UIStyle.TEXT_DIM)
var _abilities: Array[AbilityRow] = []
var _feeds: Array[Button] = []
var _prices: Array[HBoxContainer] = []
var _lead := UIStyle.button("Lead")
var _merge := UIStyle.button("Merge")
var _merge_hint := UIStyle.label("", UIStyle.SIZE_SMALL, UIStyle.TEXT_DIM)
var _portraits := {}  # species -> Texture2D, each rendered once

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
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.06, 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", UIStyle.ornament_panel())
	center.add_child(frame)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 14)
	frame.add_child(body)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 14)
	body.add_child(top)
	top.add_child(UIStyle.heading("Pets", 30))
	_count.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_count.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_count)
	_balance.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(_balance)
	var close_button := UIStyle.button("Close")
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.pressed.connect(close)
	top.add_child(close_button)

	var content := HBoxContainer.new()
	content.add_theme_constant_override("separation", 28)
	body.add_child(content)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 8)
	content.add_child(left)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(COLUMNS * (TILE + 8) + 6, 4 * (TILE + 8) + 70)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left.add_child(scroll)
	_grid.columns = COLUMNS
	_grid.add_theme_constant_override("h_separation", 8)
	_grid.add_theme_constant_override("v_separation", 8)
	scroll.add_child(_grid)
	_merge_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left.add_child(_merge_hint)

	_empty.alignment = BoxContainer.ALIGNMENT_CENTER
	_empty.custom_minimum_size.x = SIDE
	_empty.add_theme_constant_override("separation", 6)
	var none := UIStyle.heading("No pets yet", 26)
	none.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty.add_child(none)
	var how := UIStyle.label("Hatch an egg at the nest.", UIStyle.SIZE_NORMAL, UIStyle.TEXT_DIM)
	how.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty.add_child(how)
	content.add_child(_empty)

	_side.custom_minimum_size.x = SIDE
	_side.add_theme_constant_override("separation", 12)
	content.add_child(_side)
	_build_preview()
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 16)
	_side.add_child(head)
	head.add_child(_ring)
	var names := VBoxContainer.new()
	names.alignment = BoxContainer.ALIGNMENT_CENTER
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	names.add_theme_constant_override("separation", 2)
	head.add_child(names)
	_name.clip_text = true
	names.add_child(_name)
	names.add_child(_rarity)
	names.add_child(_xp_text)
	for i in 2:
		var row := AbilityRow.new()
		_side.add_child(row)
		_abilities.append(row)
	var feeds := HBoxContainer.new()
	feeds.add_theme_constant_override("separation", 8)
	_side.add_child(feeds)
	for i in 3:
		var cell := VBoxContainer.new()
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.add_theme_constant_override("separation", 2)
		feeds.add_child(cell)
		var button := UIStyle.button(["Feed 1", "Feed 10", "Level up"][i])
		button.focus_mode = Control.FOCUS_NONE
		var choice := i
		button.pressed.connect(func() -> void: _feed(choice))
		cell.add_child(button)
		_feeds.append(button)
		var price := DotsCounter.amount(0, UIStyle.SIZE_SMALL)
		price.alignment = BoxContainer.ALIGNMENT_CENTER
		cell.add_child(price)
		_prices.append(price)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	_side.add_child(actions)
	for button: Button in [_lead, _merge]:
		button.focus_mode = Control.FOCUS_NONE
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		actions.add_child(button)
	_lead.pressed.connect(_do_lead)
	_merge.pressed.connect(_do_merge)

	PetsClient.changed.connect(_on_changed)
	Account.dots_changed.connect(_dots_changed)
	if is_instance_valid(_main) and is_instance_valid(_main.player):
		_actor = _main.player
		_was_input_locked = _actor.input_locked
		_actor.begin_interaction(get_instance_id())
		_actor.input_locked = true
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.15)
	_rebuild()

func _build_preview() -> void:
	var container := SubViewportContainer.new()
	container.custom_minimum_size = Vector2(SIDE, 190)
	container.stretch = true
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_side.add_child(container)
	_preview = SubViewport.new()
	_preview.own_world_3d = true
	_preview.transparent_bg = true
	_preview.msaa_3d = Viewport.MSAA_4X
	_preview.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	container.add_child(_preview)
	_preview.add_child(_preview_root)
	_light(_preview_root)
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_preview_root.add_child(_camera)
	_camera.current = true

static func _light(root: Node) -> void:
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("d6e1ff")
	env.ambient_light_energy = 0.85
	environment.environment = env
	root.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-40, 155, 0)
	light.light_energy = 1.4
	root.add_child(light)

## Bounds of every mesh under `model`, in its parent's space.
static func _bounds(model: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for part: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		if part.mesh == null: continue
		var local := model.global_transform.affine_inverse() * part.global_transform * part.mesh.get_aabb()
		box = local if first else box.merge(local)
		first = false
	return box if not first else AABB(Vector3(-0.3, 0, -0.3), Vector3(0.6, 0.6, 0.6))

## A still portrait per species, rendered once and shared by its tiles.
func _portrait(species: String) -> Texture2D:
	if _portraits.has(species): return _portraits[species]
	var view := SubViewport.new()
	view.size = Vector2i(192, 192)
	view.own_world_3d = true
	view.transparent_bg = true
	view.msaa_3d = Viewport.MSAA_4X
	add_child(view)
	_light(view)
	var model := PetFollower.make_model(species)
	view.add_child(model)
	var box := _bounds(model)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = maxf(box.size.x, box.size.y) * 1.25 + 0.05
	view.add_child(camera)
	var middle := box.get_center()
	camera.look_at_from_position(middle + Vector3(0.9, 0.55, -1.6).normalized() * 4.0, middle)
	camera.current = true
	view.render_target_update_mode = SubViewport.UPDATE_ONCE
	_portraits[species] = view.get_texture()
	return _portraits[species]

func _on_changed() -> void:
	if _pending_select > 0 and not PetDefs.find(PetsClient.state, _pending_select).is_empty():
		_selected = _pending_select
	_pending_select = 0
	_waiting = false
	_rebuild()

func _dots_changed(_total: int, _gained: int, _source: String) -> void:
	_refresh_side()

func _rebuild() -> void:
	for child in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()
	var state := PetsClient.state
	if PetDefs.find(state, _selected).is_empty():
		_selected = int(state.equipped)
		if _selected == 0 and not state.pets.is_empty(): _selected = int(state.pets[0].id)
		_merging = false
	if PetDefs.merge(PetDefs.find(state, _selected), PetDefs.find(state, _partner)).is_empty(): _partner = 0
	for pet: Dictionary in _sorted(state.pets):
		var id := int(pet.id)
		var tile := PetTile.new(pet, _portrait(str(pet.species)))
		tile.selected = id == _selected or id == _partner
		tile.leading = id == int(state.equipped)
		if _merging and id != _selected:
			tile.disabled = PetDefs.merge(PetDefs.find(state, _selected), pet).is_empty()
			tile.modulate.a = 0.3 if tile.disabled else 1.0
		tile.pressed.connect(func() -> void: _pick(id))
		_grid.add_child(tile)
	_refresh_side()

## The led pet first, then rarest, highest level, oldest.
func _sorted(pets: Array) -> Array:
	var order := {divine = 0, rare = 1, common = 2}
	var list := pets.duplicate()
	var led := int(PetsClient.state.equipped)
	list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if (int(a.id) == led) != (int(b.id) == led): return int(a.id) == led
		if a.rarity != b.rarity: return order.get(a.rarity, 3) < order.get(b.rarity, 3)
		if int(a.level) != int(b.level): return int(a.level) > int(b.level)
		return int(a.id) < int(b.id))
	return list

func _pick(id: int) -> void:
	if _merging and id != _selected:
		_partner = 0 if _partner == id else id
	else:
		_selected = id
		_partner = 0
		_merging = false
	_rebuild()

func _refresh_side() -> void:
	DotsCounter.set_amount(_balance, Account.dots())
	var state := PetsClient.state
	_count.text = "%d / %d" % [state.pets.size(), PetDefs.MAX_PETS]
	var pet := PetDefs.find(state, _selected)
	_side.visible = not pet.is_empty()
	_empty.visible = pet.is_empty()
	_merge_hint.text = ""
	if pet.is_empty(): return
	var level := int(pet.level)
	var rarity := str(pet.rarity)
	var color: Color = PetDefs.RARITY_COLORS[rarity]
	var key := "%s:%s" % [pet.species, rarity]
	if key != _preview_key:
		_preview_key = key
		if is_instance_valid(_preview_pet): _preview_pet.queue_free()
		_preview_pet = PetFollower.new(pet)
		_preview_root.add_child(_preview_pet)
		var box := _bounds(_preview_pet.model)
		_camera.size = maxf(box.size.y * 1.5, box.size.x * 0.75) + 0.35
		var gait := str(PetDefs.SPECIES[pet.species].gait)
		var middle := box.get_center() + Vector3.UP * (0.08 + float(HOVER.get(gait, 0.0)))
		_camera.look_at_from_position(middle + Vector3(0, 0.5, -1.6).normalized() * 4.0, middle)
	var need := PetDefs.xp_to_next(level)
	_ring.set_values(level, float(pet.xp) / need if level < PetDefs.MAX_LEVEL else 1.0)
	_name.text = str(pet.name)
	_name.add_theme_color_override("font_color", color)
	_rarity.text = rarity.capitalize() + ("  -  Leading" if int(state.equipped) == _selected else "")
	_rarity.add_theme_color_override("font_color", color)
	_xp_text.text = "%s / %s XP" % [Dots.format(int(pet.xp)), Dots.format(need)] if level < PetDefs.MAX_LEVEL else "Max level"
	for i in 2:
		_abilities[i].show_ability(str(pet.abilities[i]), level, rarity, i == 0 or level >= 30)
	for i in 3:
		var bites := _bite_count(pet, i)
		var price := bites * PetDefs.BITE_DOTS
		DotsCounter.set_amount(_prices[i], price)
		_prices[i].modulate.a = 1.0 if bites > 0 else 0.0
		_feeds[i].disabled = _waiting or bites == 0 or Account.dots() < price or not Net.is_client()
	_lead.text = "Release" if int(state.equipped) == _selected else "Lead"
	_lead.disabled = _waiting or not Net.is_client()
	var partners: int = state.pets.filter(func(other: Dictionary) -> bool: return not PetDefs.merge(pet, other).is_empty()).size()
	var result := PetDefs.merge(pet, PetDefs.find(state, _partner))
	if _merging:
		_merge.text = "Merge into %s" % str(result.rarity).capitalize() if not result.is_empty() else "Cancel"
		UIStyle.button_styles(_merge, "green" if not result.is_empty() else "stone")
		_merge_hint.text = "Pick a second %s" % str(PetDefs.SPECIES[pet.species].name) if result.is_empty() else ""
	else:
		_merge.text = "Merge"
		UIStyle.button_styles(_merge)
	_merge.disabled = _waiting or not Net.is_client() or (not _merging and partners == 0)
	_merge.tooltip_text = "" if partners > 0 or _merging else "Divine pets don't merge" if rarity == "divine" else "Needs a second %s %s" % [rarity.capitalize(), str(PetDefs.SPECIES[pet.species].name)]

func _bite_count(pet: Dictionary, choice: int) -> int:
	return mini(PetDefs.bites_to_cap(pet), 1 if choice == 0 else 10 if choice == 1 else PetDefs.bites_to_next(pet))

func _wait() -> void:
	_waiting = true
	_refresh_side()
	get_tree().create_timer(1.5).timeout.connect(func() -> void:
		if is_instance_valid(self):
			_waiting = false
			_pending_select = 0
			_refresh_side())

func _feed(choice: int) -> void:
	var pet := PetDefs.find(PetsClient.state, _selected)
	if pet.is_empty() or _waiting: return
	var bites := _bite_count(pet, choice)
	if bites <= 0 or Account.dots() < bites * PetDefs.BITE_DOTS: return
	_wait()
	PetsClient.feed(_selected, bites)

func _do_lead() -> void:
	if _waiting: return
	_wait()
	PetsClient.equip(0 if int(PetsClient.state.equipped) == _selected else _selected)

func _do_merge() -> void:
	if _waiting: return
	var result := PetDefs.merge(PetDefs.find(PetsClient.state, _selected), PetDefs.find(PetsClient.state, _partner))
	if not _merging or result.is_empty():
		_merging = not _merging
		_partner = 0
		_rebuild()
		return
	var first := _selected
	var second := _partner
	_merging = false
	_partner = 0
	_wait()
	_pending_select = int(PetsClient.state.next_id)
	PetsClient.merge(first, second)

func _process(delta: float) -> void:
	if is_instance_valid(_preview_pet): _preview_pet.rotation.y = sin(Time.get_ticks_msec() * 0.0006) * 0.6
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


## One pet in the grid: its portrait in an item-slot frame, the level in the
## corner, a thin XP bar along the bottom, an edge in its rarity colour, a gold
## frame when chosen and a green dot on the pet you lead.
class PetTile:
	extends Button
	var pet := {}
	var selected := false
	var leading := false
	var _picture := TextureRect.new()
	var _over := Control.new()

	func _init(record: Dictionary, portrait: Texture2D) -> void:
		pet = record
		custom_minimum_size = Vector2.ONE * PetPanel.TILE
		focus_mode = Control.FOCUS_NONE
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		for state in ["normal", "pressed", "focus"]: add_theme_stylebox_override(state, UIStyle.slot())
		for state in ["hover", "hover_pressed"]: add_theme_stylebox_override(state, UIStyle.slot(true))
		add_theme_stylebox_override("disabled", UIStyle.slot())
		tooltip_text = "%s - %s - Level %d" % [str(pet.name), str(pet.rarity).capitalize(), int(pet.level)]
		_picture.texture = portrait
		_picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_picture)
		_picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_picture.offset_left = 6
		_picture.offset_top = 4
		_picture.offset_right = -6
		_picture.offset_bottom = -14  # clear of the XP bar
		_over.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_over)
		_over.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_over.draw.connect(_draw_over)

	func _draw_over() -> void:
		var area := Rect2(Vector2.ZERO, _over.size)
		var color: Color = PetDefs.RARITY_COLORS.get(pet.rarity, Color.WHITE)
		if pet.rarity != "common": _over.draw_rect(area.grow(-4), Color(color, 0.85), false, 2.0)
		if selected: _over.draw_rect(area.grow(-1), UIStyle.GOLD, false, 3.0)
		# XP to the next level, like a tiny HP bar.
		var bar := Rect2(8, area.size.y - 12, area.size.x - 16, 5)
		_over.draw_rect(bar.grow(1), UIStyle.OUTLINE)
		_over.draw_rect(bar, Color(0.035, 0.055, 0.085))
		var level := int(pet.level)
		var progress := 1.0 if level >= PetDefs.MAX_LEVEL else float(pet.xp) / PetDefs.xp_to_next(level)
		if progress > 0.0:
			_over.draw_rect(Rect2(bar.position, Vector2(bar.size.x * progress, bar.size.y)), UIStyle.XP)
			_over.draw_rect(Rect2(bar.position, Vector2(bar.size.x * progress, 1)), UIStyle.XP.lightened(0.45))
		var font := UIStyle.bold()
		var text := str(level)
		_over.draw_string_outline(font, Vector2(9, 24), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, 5, UIStyle.OUTLINE)
		_over.draw_string(font, Vector2(9, 24), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, UIStyle.TEXT)
		if leading:
			var dot := Vector2(area.size.x - 14, 14)
			_over.draw_circle(dot, 6.0, UIStyle.OUTLINE)
			_over.draw_circle(dot, 4.0, UIStyle.GOOD)


## An ability on one line: a swatch in its bolt colour, the name, and what it
## does on the right. Locked abilities are dim and say when they open.
class AbilityRow:
	extends HBoxContainer
	var _swatch := ColorRect.new()
	var _label := UIStyle.label("", UIStyle.SIZE_NORMAL)
	var _value := UIStyle.label("", UIStyle.SIZE_SMALL, UIStyle.TEXT_DIM)

	func _init() -> void:
		add_theme_constant_override("separation", 10)
		_swatch.custom_minimum_size = Vector2(12, 12)
		_swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		add_child(_swatch)
		_label.add_theme_font_override("font", UIStyle.bold())
		_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		add_child(_label)
		_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		add_child(_value)

	func show_ability(id: String, level: int, rarity: String, unlocked: bool) -> void:
		var color: Color = PetDefs.ABILITIES[id].color
		_swatch.color = color if unlocked else Color(color, 0.25)
		_label.text = str(PetDefs.ABILITIES[id].name)
		_label.add_theme_color_override("font_color", UIStyle.TEXT if unlocked else UIStyle.TEXT_DIM)
		_label.modulate.a = 1.0 if unlocked else 0.55
		_value.text = "%s every %s s" % [_effect(id, level, rarity), String.num(PetDefs.interval(level), 1)] if unlocked else "Level 30"
		_value.modulate.a = 1.0 if unlocked else 0.55

	static func _effect(id: String, level: int, rarity: String) -> String:
		var value := String.num(PetDefs.ability_value(id, level, rarity), 0)
		match id:
			"regen": return "+%s HP" % value
			"mana": return "+%s MP" % value
			"attack": return "%s damage" % value
			"chain": return "%s damage x3" % value
			"ward": return "+%s defence" % value
			"swift": return "+%s speed" % value
		return value
