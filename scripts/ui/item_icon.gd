class_name ItemIcon
extends Control
## Smooth the hairline outline at fractional GUI scales; keep source pixels
## nearest-filtered on their own canvas, just as text has its own raster scale.
var item: Item
var outline_color := Color(1,1,1,0.9)
var _art := TextureRect.new()

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_art)

func show_item(value: Item) -> void:
	item = value
	_art.texture = item.icon() if item else null
	queue_redraw()

func _draw() -> void:
	if item == null: return
	var pad := size/Item.OUTLINE_CORE_SIZE
	draw_texture_rect(item.outline_mask(),Rect2(-pad,size+pad*2.0),false,outline_color)
