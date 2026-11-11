class_name ItemSlot
extends Control
## An item slot in pixel art: a recessed square holding the item's 8 x 8 icon
## at 6x with a hairline white outline, a tiny grade badge ("G3", "D"), and a
## hover tooltip. Divine items shimmer with a soft glow. Empty slots show a
## faint dotted outline.
##
## Slots can be dragged between: give a slot `stats` and a `place`
## ({kind = "gear", key = "weapon"} or {kind = "pack", key = 7}) and items can
## be dragged out of it and dropped into any other slot that accepts them
## (gear slots only take their own kind of item; swaps happen automatically).
## Stacks show their count. Double-clicking does the obvious thing (see
## PlayerStats.activate): takes it out of a loot bag, drinks or uses a
## consumable, equips gear from the backpack or takes it off again.
## Slots only predict what's allowed; every change is a request to the
## server (GameServer), which checks it and applies it.

signal hovered(slot: ItemSlot, item: Item)
signal unhovered

const ICON_SCALE := 6
const SLOT_SIZE := 72.0
const SLOT_GAP := 6.0

var item: Item
var slot_name := ""  # e.g. "Bonus"
var key_hint := ""  # drawn in the corner, e.g. "F" on a quickslot
var stats: PlayerStats
var place := {}
var _hover := false
var _art := ItemIcon.new()
var _labels := SlotLabels.new()
static var _drag_source := {}
static var _held_sources := {}  # owner instance id -> staged inventory artwork


func _init(p_slot_name := "", p_stats: PlayerStats = null, p_place := {}) -> void:
	slot_name = p_slot_name
	stats = p_stats
	place = p_place
	custom_minimum_size = Vector2.ONE * SLOT_SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST  # crisp pixel-art icons
	mouse_entered.connect(func() -> void:
		_hover = true
		hovered.emit(self, item)
		queue_redraw())
	mouse_exited.connect(func() -> void:
		_hover = false
		unhovered.emit()
		queue_redraw())


func set_item(p_item: Item) -> void:
	item = p_item
	queue_redraw()


## Gear the character playing can't wear (another class's weapon or armor).
func unusable() -> bool:
	return item != null and stats != null and item.slot in ["weapon", "armor", "spell", "bonus"] \
			and not item.usable_by(stats.class_id)


func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.double_click and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if item == null or stats == null:
		return
	if item.is_story():  # read it
		StoryReader.open(item)
		accept_event()
		return
	GameServer.request_activate(stats.player_id, place)
	accept_event()


# --- Drag and drop -----------------------------------------------------------------

func _get_drag_data(_at_position: Vector2) -> Variant:
	if item == null or stats == null or artwork_held():
		return null
	var preview := ItemIcon.new()
	preview.show_item(item)
	preview.size = Vector2(Item.ICON_SIZE, Item.ICON_SIZE) * ICON_SCALE
	preview.position = -preview.size * 0.5
	var holder := Control.new()  # so the icon is centered on the cursor
	holder.add_child(preview)
	set_drag_preview(holder)
	_drag_source = {player_id=stats.player_id,place=place.duplicate(),item_id=item.id}
	queue_redraw()
	return {from = place}

func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		_drag_source.clear()
		queue_redraw()
	elif what == NOTIFICATION_DRAG_BEGIN:
		queue_redraw()

func hold_artwork(owner: Object, from: Dictionary, item_id: String) -> void:
	_held_sources[owner.get_instance_id()] = {player_id=stats.player_id,place=from.duplicate(),item_id=item_id}
	_redraw_slots()

func release_artwork(owner: Object) -> void:
	_held_sources.erase(owner.get_instance_id())
	_redraw_slots()

func _redraw_slots() -> void:
	if not is_inside_tree(): return
	for slot: ItemSlot in get_tree().get_nodes_in_group("item_slots"): slot.queue_redraw()

func artwork_held() -> bool:
	if item == null or stats == null: return false
	for held: Dictionary in _held_sources.values():
		if _matches_source(held): return true
	return false

func _matches_source(source: Dictionary) -> bool:
	return not source.is_empty() and item != null and stats != null \
		and int(source.player_id)==stats.player_id and source.place==place and source.item_id==item.id

func artwork_hidden() -> bool:
	return artwork_held() or (is_inside_tree() and get_viewport().gui_is_dragging() and _matches_source(_drag_source))


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return stats != null and data is Dictionary and data.has("from") and stats.can_move(data.from, place)


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	GameServer.request_move(stats.player_id, data.from, place)


# --- Looks -------------------------------------------------------------------------

func _draw() -> void:
	var accepting := _hover and get_viewport().gui_is_dragging() \
			and _can_drop_data(Vector2.ZERO, get_viewport().gui_get_drag_data())
	draw_style_box(_frame_style(accepting), Rect2(Vector2.ZERO, size))
	if unusable():
		draw_rect(Rect2(Vector2.ONE * 4, size - Vector2.ONE * 8), Color(0.95, 0.12, 0.1, 0.22))
	if accepting:
		draw_rect(Rect2(Vector2.ONE * 6, size - Vector2.ONE * 12), Color(UIStyle.GOOD, 0.25))
	var icon_size := Vector2(Item.ICON_SIZE, Item.ICON_SIZE) * ICON_SCALE
	var icon_pos := ((size - icon_size) * 0.5).floor()
	_art.visible = item != null and not artwork_hidden()
	if item and not artwork_hidden():
		_art.position = icon_pos
		_art.size = icon_size
		_art.show_item(item)
		if item.is_divine():
			# Shimmer: small, quick, out-of-step flickers rather than a slow pulse.
			var t := Time.get_ticks_msec() / 1000.0
			var shimmer := 0.5 + 0.08 * sin(t * 9.1) + 0.06 * sin(t * 14.7 + 1.3) + 0.05 * sin(t * 23.3 + 0.7)
			var glow := Color(UIStyle.DIVINE_COLOR.lerp(Color.WHITE, 0.15 + 0.1 * sin(t * 6.3)), shimmer)
			draw_texture_rect(item.glow_mask(), Rect2(icon_pos - Vector2.ONE * ICON_SCALE, icon_size + Vector2.ONE * ICON_SCALE * 2), false, glow)
	elif item == null:
		# Dotted outline where an item would go.
		var c := Color(UIStyle.TEXT_DIM, 0.35)
		for i in range(0, int(icon_size.x), PixelArt.SCALE * 2):
			draw_rect(Rect2(icon_pos + Vector2(i, 0), Vector2.ONE * PixelArt.SCALE), c)
			draw_rect(Rect2(icon_pos + Vector2(i, icon_size.y - PixelArt.SCALE), Vector2.ONE * PixelArt.SCALE), c)
			draw_rect(Rect2(icon_pos + Vector2(0, i), Vector2.ONE * PixelArt.SCALE), c)
			draw_rect(Rect2(icon_pos + Vector2(icon_size.x - PixelArt.SCALE, i), Vector2.ONE * PixelArt.SCALE), c)

	_labels.queue_redraw()


## A foreground canvas keeps badges/counts above the separate icon canvas.
func _draw_labels(canvas: Control) -> void:
	if item != null and not artwork_hidden():
		var badge := item.badge()
		PixelArt.draw_tiny(canvas,size-Vector2(PixelArt.tiny_width(badge)+8,16),badge,UIStyle.grade_color(item))
		if item.stack_max>1 and item.count>1:
			var count_text := str(item.count)
			PixelArt.draw_tiny(canvas,Vector2(size.x-PixelArt.tiny_width(count_text)-8,8),count_text,UIStyle.TEXT)
	if key_hint != "":
		var hint_size := 16
		if UIStyle.font().get_string_size(key_hint,HORIZONTAL_ALIGNMENT_LEFT,-1,hint_size).x>size.x-16: hint_size = 11
		canvas.draw_string(UIStyle.font(),Vector2(8,18),key_hint,HORIZONTAL_ALIGNMENT_LEFT,size.x-16,hint_size,UIStyle.TEXT_DIM)


func _frame_style(highlighted: bool) -> StyleBoxTexture:
	return UIStyle.slot(highlighted)


func _process(_delta: float) -> void:
	if (_hover and get_viewport().gui_is_dragging()) or (item and item.is_divine()):
		queue_redraw()  # drop highlight follows dragging; divine glow pulses


func _ready() -> void:
	add_to_group("item_slots")
	add_child(_art)
	_labels.slot = self
	_labels.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_labels)
	UIStyle.add_shadow(self)


class SlotLabels extends Control:
	var slot: ItemSlot
	func _draw() -> void:
		if is_instance_valid(slot): slot._draw_labels(self)
