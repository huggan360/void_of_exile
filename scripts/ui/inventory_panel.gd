class_name InventoryPanel
extends PanelContainer
## The backpack, shown in the middle of the screen while Tab is held (and
## while standing on a loot bag). Items can be dragged between backpack slots
## and onto the gear slots at the top right (and back), or double-clicked to
## equip or use them. Two rows to start with; a Backpack item adds two more.

signal item_hovered(item: Item)
signal item_unhovered

const COLUMNS := 8

var stats: PlayerStats
var _slots: Array[ItemSlot] = []
var _grid := GridContainer.new()


func _init(p_stats: PlayerStats) -> void:
	stats = p_stats


func _ready() -> void:
	add_theme_stylebox_override("panel", UIStyle.ornament_panel())
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	add_child(box)
	var title := HBoxContainer.new()
	title.add_child(UIStyle.heading("Backpack"))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_child(spacer)
	title.add_child(UIStyle.label("Drag or double-click to equip", UIStyle.SIZE_SMALL, UIStyle.TEXT_DIM))
	box.add_child(title)
	var line := ColorRect.new()  # pixel divider
	line.color = UIStyle.BEVEL_LIGHT
	line.custom_minimum_size = Vector2(0, PixelArt.SCALE)
	box.add_child(line)
	_grid.columns = COLUMNS
	_grid.add_theme_constant_override("h_separation", 6)
	_grid.add_theme_constant_override("v_separation", 6)
	box.add_child(_grid)
	stats.changed.connect(refresh)
	refresh()


func refresh() -> void:
	# The backpack grows (and shrinks) with the Backpack item.
	while _slots.size() < stats.backpack.size():
		var slot := ItemSlot.new("", stats, {kind = "pack", key = _slots.size()})
		slot.hovered.connect(func(_s: ItemSlot, item: Item) -> void: item_hovered.emit(item))
		slot.unhovered.connect(func() -> void: item_unhovered.emit())
		_grid.add_child(slot)
		_slots.append(slot)
	while _slots.size() > stats.backpack.size():
		_slots.pop_back().queue_free()
	for i in _slots.size():
		_slots[i].set_item(stats.backpack[i])
