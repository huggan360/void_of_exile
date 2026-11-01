class_name ItemSlot
extends Control
## An item slot in pixel art: a recessed square holding the item's 8 x 8 icon
## at 5x with a hairline white outline, a tiny grade badge ("G3", "D"), and a
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

const ICON_SCALE := 5

var item: Item
var slot_name := ""  # e.g. "Bonus"
var key_hint := ""  # drawn in the corner, e.g. "F" on a quickslot
var stats: PlayerStats
var place := {}
var _hover := false


func _init(p_slot_name := "", p_stats: PlayerStats = null, p_place := {}) -> void:
	slot_name = p_slot_name
	stats = p_stats
	place = p_place
	custom_minimum_size = Vector2(20, 20) * PixelArt.SCALE
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
	if item == null or stats == null:
		return null
	var preview := TextureRect.new()
	preview.texture = item.icon()
	preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	preview.size = Vector2(Item.ICON_SIZE, Item.ICON_SIZE) * ICON_SCALE
	preview.position = -preview.size * 0.5
	var holder := Control.new()  # so the icon is centered on the cursor
	holder.add_child(preview)
	set_drag_preview(holder)
	return {from = place}


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return stats != null and data is Dictionary and data.has("from") and stats.can_move(data.from, place)


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	GameServer.request_move(stats.player_id, data.from, place)


# --- Looks -------------------------------------------------------------------------

func _draw() -> void:
	var accepting := _hover and get_viewport().gui_is_dragging() \
			and _can_drop_data(Vector2.ZERO, get_viewport().gui_get_drag_data())
	draw_style_box(UIStyle.slot(_hover), Rect2(Vector2.ZERO, size))
	if accepting:
		draw_rect(Rect2(Vector2.ONE * 6, size - Vector2.ONE * 12), Color(UIStyle.GOOD, 0.25))
	var icon_size := Vector2(Item.ICON_SIZE, Item.ICON_SIZE) * ICON_SCALE
	var icon_pos := ((size - icon_size) * 0.5).floor()
	if item:
		if _hover:
			icon_pos.y -= PixelArt.SCALE  # lifts a little when hovered
		if item.is_divine():
			# Shimmer: small, quick, out-of-step flickers rather than a slow pulse.
			var t := Time.get_ticks_msec() / 1000.0
			var shimmer := 0.5 + 0.08 * sin(t * 9.1) + 0.06 * sin(t * 14.7 + 1.3) + 0.05 * sin(t * 23.3 + 0.7)
			var glow := Color(UIStyle.DIVINE_COLOR.lerp(Color.WHITE, 0.15 + 0.1 * sin(t * 6.3)), shimmer)
			draw_texture_rect(item.glow_mask(), Rect2(icon_pos - Vector2.ONE * ICON_SCALE, icon_size + Vector2.ONE * ICON_SCALE * 2), false, glow)
		# Hairline outline: the white silhouette nudged one screen pixel each way.
		for d: Vector2 in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
			draw_texture_rect(item.silhouette(), Rect2(icon_pos + d, icon_size), false, Color(1, 1, 1, 0.9))
		draw_texture_rect(item.icon(), Rect2(icon_pos, icon_size), false)
		var badge := item.badge()
		PixelArt.draw_tiny(self, size - Vector2(PixelArt.tiny_width(badge) + 8, 16), badge, UIStyle.grade_color(item))
		if item.stack_max > 1 and item.count > 1:
			var n := str(item.count)
			PixelArt.draw_tiny(self, size - Vector2(PixelArt.tiny_width(n) + 8, 16), n, UIStyle.TEXT)
	else:
		# Dotted outline where an item would go.
		var c := Color(UIStyle.TEXT_DIM, 0.35)
		for i in range(0, int(icon_size.x), PixelArt.SCALE * 2):
			draw_rect(Rect2(icon_pos + Vector2(i, 0), Vector2.ONE * PixelArt.SCALE), c)
			draw_rect(Rect2(icon_pos + Vector2(i, icon_size.y - PixelArt.SCALE), Vector2.ONE * PixelArt.SCALE), c)
			draw_rect(Rect2(icon_pos + Vector2(0, i), Vector2.ONE * PixelArt.SCALE), c)
			draw_rect(Rect2(icon_pos + Vector2(icon_size.x - PixelArt.SCALE, i), Vector2.ONE * PixelArt.SCALE), c)


	if key_hint != "":
		var hint_size := 16
		if UIStyle.font().get_string_size(key_hint,HORIZONTAL_ALIGNMENT_LEFT,-1,hint_size).x>size.x-16: hint_size = 11
		draw_string(UIStyle.font(),Vector2(8,18),key_hint,HORIZONTAL_ALIGNMENT_LEFT,size.x-16,hint_size,UIStyle.TEXT_DIM)


func _process(_delta: float) -> void:
	if _hover or (item and item.is_divine()):
		queue_redraw()  # drop highlight follows dragging; divine glow pulses
