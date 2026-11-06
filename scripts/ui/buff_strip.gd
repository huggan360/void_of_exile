class_name BuffStrip
extends Control
## Four flags per row, newest rows grow upward from the bottom edge.
const CELL := Vector2(60,80)
const COLUMNS := 4
var effects: StatusEffects
var _badges := {}
var _revision := -1
var _scale_factor := 1.0

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func _process(_delta: float) -> void:
	if effects == null: return
	if effects.revision != _revision:
		_revision = effects.revision
		_sync()
	for e: Dictionary in effects.active():
		var card: Control = _badges.get(e.key)
		if not is_instance_valid(card): continue
		var left := maxf(0.0,float(e.expires)-Net.now())
		var timer: Label = card.get_node("TimerPill/Timer")
		timer.text = StatusEffects.time_text(left)
		timer.modulate = Color(1,.7,.65) if left<3.0 else Color.WHITE

## Fit the gap between the resource bars and minimap at all supported UI scales.
func fit_gap(width: float) -> void:
	_scale_factor = clampf(width/(CELL.x*COLUMNS),.5,1.0)
	scale = Vector2.ONE*_scale_factor
	_layout()

func _sync() -> void:
	var live := {}
	for e: Dictionary in effects.active():
		live[e.key] = true
		if not _badges.has(e.key):
			var card := Control.new()
			card.mouse_filter = Control.MOUSE_FILTER_PASS
			card.size = CELL
			card.pivot_offset = CELL*.5
			var stone := Panel.new()
			stone.name = "Stone"
			stone.set_anchors_preset(Control.PRESET_FULL_RECT)
			stone.add_theme_stylebox_override("panel", UIStyle.panel())
			stone.mouse_filter = Control.MOUSE_FILTER_IGNORE
			card.add_child(stone)
			var timer_pill := PanelContainer.new()
			timer_pill.name = "TimerPill"
			timer_pill.position = Vector2(3, 0)
			timer_pill.size = Vector2(54, 22)
			var timer_style: StyleBoxTexture = UIStyle.panel_outlined(UIStyle.ACCENT).duplicate()
			timer_style.set_content_margin_all(2)
			timer_pill.add_theme_stylebox_override("panel", timer_style)
			timer_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
			card.add_child(timer_pill)
			var timer := Label.new()
			timer.name = "Timer"
			timer.set_anchors_preset(Control.PRESET_FULL_RECT)
			timer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			timer.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			UIStyle.text(timer, 14, UIStyle.TEXT)
			timer.add_theme_font_override("font", UIStyle.bold())
			timer.mouse_filter = Control.MOUSE_FILTER_IGNORE
			timer_pill.add_child(timer)
			var image := TextureRect.new()
			image.name = "Flag"
			image.position = Vector2(3,25)
			image.size = Vector2(54,54)
			image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			image.mouse_filter = Control.MOUSE_FILTER_IGNORE
			card.add_child(image)
			add_child(card)
			_badges[e.key] = card
			card.scale = Vector2.ONE*.35
			card.modulate.a = 0
			var tween := card.create_tween().set_parallel(true)
			tween.tween_property(card,"scale",Vector2.ONE,.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tween.tween_property(card,"modulate:a",1.0,.16)
		var card: Control = _badges[e.key]
		card.tooltip_text = StatusEffects.description(e)
		(card.get_node("Flag") as TextureRect).texture = BuffArt.badge(e)
	for key in _badges.keys():
		if live.has(key): continue
		var card: Control = _badges[key]
		_badges.erase(key)
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var tween := card.create_tween().set_parallel(true)
		tween.tween_property(card,"scale",Vector2.ONE*.3,.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		tween.tween_property(card,"modulate:a",0.0,.18)
		tween.tween_property(card,"position:y",card.position.y-12,.18)
		tween.chain().tween_callback(card.queue_free)
	_layout()

func _layout() -> void:
	var i := 0
	for card: Control in _badges.values():
		card.position = Vector2((i%COLUMNS)*CELL.x,-(i/COLUMNS+1)*CELL.y)
		i += 1
