class_name ForgePanel
extends PanelContainer
## Bram's forge (talk to the smith in the Tavern): drag an item from your
## backpack onto the anvil, see what it's worth in Dots, and Dismantle it.
## The server takes the item and pays (EconomyServer.dismantle); the Dots
## fly from the forge's mouth up to the counter by the account bar.
## Shown under the backpack while the conversation with the smith is open.

signal item_hovered(item: Item)
signal item_unhovered

var stats: PlayerStats
var interaction: InteractionCard
## The forge's glowing mouth (where the Dots fly from), if the world has one.
var mouth: Node3D
var dots: DotsCounter
var _target: InteractionTarget
var _slot: ForgeSlot
var _value := UIStyle.label("", 28, Dots.COLOR)
var _hint := UIStyle.label("Drag an item from your backpack onto the anvil.", UIStyle.SIZE_SMALL, UIStyle.TEXT_DIM)
var _button := Button.new()
var _waiting := false


func _init(p_stats: PlayerStats) -> void:
	stats = p_stats


func _ready() -> void:
	add_to_group("forge_panels")
	add_theme_stylebox_override("panel", UIStyle.ornament_panel())
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(box)
	var title := UIStyle.heading("Bram's Forge", 22)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	_value.add_theme_font_override("font", UIStyle.bold())
	_value.add_theme_color_override("font_outline_color", Color(0.02, 0.1, 0.04))
	_value.add_theme_constant_override("outline_size", 6)
	_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_value)
	_slot = ForgeSlot.new(stats)
	_slot.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_slot.custom_minimum_size *= 1.25
	_slot.hovered.connect(func(_s: ItemSlot, item: Item) -> void: item_hovered.emit(item))
	_slot.unhovered.connect(func() -> void: item_unhovered.emit())
	_slot.changed.connect(_refresh)
	box.add_child(_slot)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.custom_minimum_size.x = 300
	box.add_child(_hint)
	_button.text = "Dismantle"
	_button.add_theme_font_override("font", UIStyle.bold())
	_button.add_theme_font_size_override("font_size", 20)
	_button.custom_minimum_size = Vector2(220, 48)
	_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = {normal = Color(0.72, 0.12, 0.1), hover = Color(0.86, 0.18, 0.13), pressed = Color(0.55, 0.08, 0.07),
				disabled = Color(0.32, 0.14, 0.13), focus = Color(0.72, 0.12, 0.1)}[state]
		style.border_color = Color(1.0, 0.62, 0.35) if state != "disabled" else Color(0.45, 0.25, 0.2)
		style.set_border_width_all(2)
		style.set_corner_radius_all(4)
		style.set_content_margin_all(8)
		if state == "focus":
			style.draw_center = false
		_button.add_theme_stylebox_override(state, style)
	_button.add_theme_color_override("font_disabled_color", Color(0.7, 0.55, 0.5))
	_button.pressed.connect(dismantle)
	box.add_child(_button)
	stats.changed.connect(_refresh)
	hide()
	_refresh()


## The smith was spoken to: the forge opens (under the backpack).
func open_for(target: InteractionTarget, forge_mouth: Node3D) -> void:
	_target = target
	mouth = forge_mouth
	_slot.clear()
	_waiting = false
	show()
	_refresh()


func close() -> void:
	_target = null
	_slot.clear()
	hide()
	item_unhovered.emit()


func _process(_delta: float) -> void:
	if visible and (interaction == null or not interaction.opened or interaction.target != _target):
		close()


func _refresh() -> void:
	if not is_instance_valid(_slot):
		return
	_slot.validate()
	var value := Dots.dismantle_value(_slot.item)
	_value.text = "+%s Dots" % Dots.format(value) if _slot.item else "Dots: —"
	_value.modulate.a = 1.0 if _slot.item else 0.5
	_hint.text = "%s becomes %s Dots. It is gone for good." % [_slot.item.item_name, Dots.format(value)] if _slot.item \
			else "Drag an item from your backpack onto the anvil."
	_button.disabled = _slot.item == null or _waiting
	_button.text = "Dismantling..." if _waiting else "Dismantle"


func dismantle() -> void:
	if _slot.item == null or _waiting:
		return
	if not Net.is_client():
		_hint.text = "The forge works when you play online or in Singleplayer."
		return
	var camera := get_viewport().get_camera_3d()
	if dots and camera and is_instance_valid(mouth) and not camera.is_position_behind(mouth.global_position):
		dots.next_origin = camera.unproject_position(mouth.global_position)
	elif dots:
		dots.next_origin = _slot.get_global_rect().get_center() * AppSettings.ui_factor()
	GameAudio.play("forge",mouth.global_position if is_instance_valid(mouth) else Vector3.INF,{cooldown=.5,volume_db=-5})
	_waiting = true
	Net.client.send_action("forge", [_slot.source, _slot.item.id])
	# Keep its artwork on the anvil until authority removes the source item.
	# Clearing now would briefly draw it back in the backpack while we wait.
	_refresh()
	# The answer arrives as a character update and a Dots event.
	get_tree().create_timer(0.6).timeout.connect(func() -> void:
		_waiting = false
		_refresh())


## The anvil stages an inventory item. Authority keeps it in the source place
## until confirmation; its source artwork stays hidden while it is staged.
class ForgeSlot:
	extends ItemSlot
	signal changed
	var source := {}
	var _item_id := ""
	var _item_count := 0

	func _init(p_stats: PlayerStats) -> void:
		super._init("", p_stats, {})

	func clear() -> void:
		release_artwork(self)
		source = {}
		_item_id = ""
		_item_count = 0
		set_item(null)
		changed.emit()

	## Forgets the item when it left the place it was taken from.
	func validate() -> void:
		if source.is_empty():
			return
		var there := stats.item_at(source)
		# Character snapshots reconstruct Item resources even when the same
		# inventory item is still here. Compare persistent data, then rebind.
		if there == null or there.id != _item_id or there.count != _item_count:
			release_artwork(self)
			source = {}
			_item_id = ""
			_item_count = 0
			set_item(null)
		else:
			set_item(there)

	func _exit_tree() -> void:
		release_artwork(self)

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
			clear()
			accept_event()

	func _get_drag_data(_at_position: Vector2) -> Variant:
		return null

	func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
		if not (data is Dictionary and data.has("from")) or not str(data.from.get("kind", "")) in ["pack", "gear", "quick"]:
			return false
		return Dots.dismantle_value(stats.item_at(data.from)) > 0

	func _drop_data(_at_position: Vector2, data: Variant) -> void:
		if not _can_drop_data(_at_position,data): return
		release_artwork(self)
		source = data.from.duplicate()
		var selected := stats.item_at(source)
		_item_id = selected.id
		_item_count = selected.count
		set_item(selected)
		hold_artwork(self,source,_item_id)
		changed.emit()
