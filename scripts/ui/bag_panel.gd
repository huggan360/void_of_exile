class_name BagPanel
extends PanelContainer
## The loot chest you are beside: at least 8 slots, expanding in 4 columns,
## with the chest's name in its color. Shown under the backpack (which opens
## along with it): drag items across, or double-click them to take them.

signal item_hovered(item: Item)
signal item_unhovered

const COLUMNS := 4

var stats: PlayerStats
## The bag shown (a view of a server bag), or null.
var bag: LootBag
var _title := Label.new()
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
	UIStyle.text(_title, UIStyle.SIZE_NORMAL)
	title.add_child(_title)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_child(spacer)
	title.add_child(UIStyle.label("Double-click to take", UIStyle.SIZE_SMALL, UIStyle.TEXT_DIM))
	box.add_child(title)
	var grid := _grid
	grid.columns = COLUMNS
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	box.add_child(grid)
	_resize_slots(LootBag.SLOTS)
	stats.changed.connect(refresh)
	GameServer.bag_changed.connect(func(id: int) -> void:
		if bag and is_instance_valid(bag) and id == bag.bag_id:
			refresh())


func _resize_slots(count: int) -> void:
	while _slots.size() > count:
		var slot: ItemSlot = _slots.pop_back()
		_grid.remove_child(slot)
		slot.queue_free()
	while _slots.size() < count:
		var slot := ItemSlot.new("", stats, {})
		slot.hovered.connect(func(_s: ItemSlot, item: Item) -> void: item_hovered.emit(item))
		slot.unhovered.connect(func() -> void: item_unhovered.emit())
		_grid.add_child(slot)
		_slots.append(slot)


## Shows a bag (or hides the panel for null).
func show_bag(p_bag: LootBag) -> void:
	bag = p_bag
	visible = bag != null
	if bag == null:
		item_unhovered.emit()
		return
	var colors: Array = LootBag.COLORS[bag.type]
	_title.text = LootBag.display_name(bag.type)
	_title.add_theme_color_override("font_color", colors[0] if bag.type != "black" else colors[2])
	for i in _slots.size():
		_slots[i].place = {kind = "bag", key = i, bag = bag.bag_id}
	refresh()


func refresh() -> void:
	if bag == null or not is_instance_valid(bag):
		return
	var record := GameServer.bag(bag.bag_id)
	_resize_slots(record.items.size() if not record.is_empty() else LootBag.SLOTS)
	for i in _slots.size(): _slots[i].place = {kind = "bag", key = i, bag = bag.bag_id}
	var empty: bool = not record.is_empty() and record.items.all(func(item: Variant) -> bool: return item == null)
	if bag.type == "vault":
		_title.text = str(record.get("label", LootBag.display_name(bag.type)))
	else:
		_title.text = LootBag.display_name(bag.type) + (" - Empty" if empty else " - Opened")
	for i in _slots.size():
		_slots[i].set_item(record.items[i] if not record.is_empty() else null)
