class_name ForgePanel
extends PanelContainer
## Bram's forge (talk to the smith in the Tavern): drag an item from your
## backpack onto the anvil, see what it's worth (the number and the dot
## icon) and Dismantle it. Kept minimal: no explanations.
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
var _value := DotsCounter.amount(0, 28)
var _hint := UIStyle.label("", UIStyle.SIZE_SMALL, UIStyle.TEXT_DIM)
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
	_value.alignment = BoxContainer.ALIGNMENT_CENTER
	_value.custom_minimum_size.y = 36
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
	UIStyle.button_styles(_button, "red")
	_button.focus_mode = Control.FOCUS_NONE
	_button.custom_minimum_size = Vector2(220, 48)
	_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
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
	DotsCounter.set_amount(_value, Dots.dismantle_value(_slot.item))
	_value.modulate.a = 1.0 if _slot.item else 0.0
	_hint.text = ""
	_hint.visible = false
	_button.disabled = _slot.item == null or _waiting
	_button.text = "Dismantling..." if _waiting else "Dismantle"


func dismantle() -> void:
	if _slot.item == null or _waiting:
		return
	if not Net.is_client():
		_hint.text = "Online or Singleplayer only"
		_hint.visible = true
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

	## Dragging it off the anvil: the anvil lets go, and it is an ordinary drag
	## of the item from where it really is (drop it anywhere in the backpack;
	## let go elsewhere and it is simply back in its place).
	func _get_drag_data(_at_position: Vector2) -> Variant:
		if item == null or source.is_empty():
			return null
		var from := source.duplicate()
		var preview := ItemIcon.new()
		preview.show_item(item)
		preview.size = Vector2(Item.ICON_SIZE, Item.ICON_SIZE) * ICON_SCALE
		preview.position = -preview.size * 0.5
		var holder := Control.new()  # so the icon is centered on the cursor
		holder.add_child(preview)
		set_drag_preview(holder)
		_drag_source = {player_id = stats.player_id, place = from, item_id = item.id}
		clear()
		return {from = from}

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
