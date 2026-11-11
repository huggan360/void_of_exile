class_name DotsCounter
extends HBoxContainer
## The account's Dots at the top right of the HUD: a green dot and the
## amount. Whenever Dots come in, green dots burst out from where they came
## from (the forge's mouth, or the player), swoop up into the counter and
## each one lands with a pop that ticks the number up.

const ICON := 32.0
const MIN_FLYERS := 7
const MAX_FLYERS := 30
const ICON_ROWS := [
	"..GGGG..",
	".GMMMMG.",
	"GMMMMMMG",
	"GMMWWMMG",
	"GMMWWMMG",
	"GMMMMMMG",
	".GMMMMG.",
	"..GGGG..",
]

## Where the next gain's dots start, in screen pixels (the forge sets it
## just before dismantling). INF = from the middle of the screen.
var next_origin := Vector2.INF
var _icon := TextureRect.new()
var _label := UIStyle.label("0", 30, Color.WHITE)
var _shown := 0
var _target := 0
var _pending := 0  # dots still in the air
var _flash := 0.0
static var _icon_texture: ImageTexture


## The dot icon itself (pixel art), shared by every price in the game.
static func icon_texture() -> ImageTexture:
	if _icon_texture == null:
		_icon_texture = ImageTexture.create_from_image(PixelArt.image_from_rows(PackedStringArray(ICON_ROWS), {
			"G": Dots.COLOR_DARK,
			"M": Dots.COLOR,
			"W": Color(0.9, 1.0, 0.82),
		}))
	return _icon_texture


## An amount of Dots as the number and the dot icon (never the word): white,
## or green when it is a sale price. Set it again with set_amount().
static func amount(value: int, font_size := 18, sale := false) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var label := UIStyle.label("", font_size, Color.WHITE)
	label.name = "Amount"
	label.add_theme_font_override("font", UIStyle.bold())
	label.add_theme_color_override("font_outline_color", Color(0.02, 0.04, 0.06))
	label.add_theme_constant_override("outline_size", 4)
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(label)
	var icon := TextureRect.new()
	icon.texture = icon_texture()
	icon.custom_minimum_size = Vector2.ONE*roundf(font_size*0.9)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_SCALE
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon)
	set_amount(row, value, sale)
	return row


static func set_amount(row: HBoxContainer, value: int, sale := false) -> void:
	var label := row.get_node("Amount") as Label
	label.text = Dots.format(value)
	label.add_theme_color_override("font_color", UIStyle.GOOD if sale else Color.WHITE)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", 6)
	tooltip_text = "Dots: dismantle items at the forge, finish campaigns for the first time"
	alignment = BoxContainer.ALIGNMENT_END
	_icon.texture = icon_texture()
	_icon.custom_minimum_size = Vector2(ICON, ICON)
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_SCALE
	_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_icon.pivot_offset = Vector2(ICON, ICON) / 2.0
	_icon.mouse_filter = Control.MOUSE_FILTER_PASS
	_label.add_theme_font_override("font", UIStyle.bold())
	_label.add_theme_font_size_override("font_size", 30)
	_label.add_theme_color_override("font_color", Color.WHITE)
	_label.add_theme_color_override("font_outline_color", Color(0.02, 0.1, 0.04))
	_label.add_theme_constant_override("outline_size", 6)
	_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_label.pivot_offset = Vector2(0, 18)
	add_child(_label)
	add_child(_icon)
	Account.dots_changed.connect(_on_dots)
	Account.changed.connect(func() -> void:
		if _pending == 0:
			_set_now(Account.dots()))
	_set_now(Account.dots())


func _set_now(total: int) -> void:
	_target = total
	_shown = total
	_label.text = Dots.format(total)


func _on_dots(total: int, gained: int, _source: String) -> void:
	if gained <= 0 or not is_visible_in_tree():
		if _pending == 0:
			_set_now(total)
		else:
			_target = total
		return
	_target = total
	var from := next_origin if next_origin != Vector2.INF else get_viewport_rect().size * Vector2(0.5, 0.58)
	next_origin = Vector2.INF
	fly(from / AppSettings.ui_factor(), gained)  # screen pixels -> the scaled HUD's


## The flight: dots burst from `from` (HUD coordinates) and land in the counter one by one.
func fly(from: Vector2, gained: int) -> void:
	var count := clampi(gained / 15, MIN_FLYERS, MAX_FLYERS)
	var base := _target - gained
	if _pending == 0:
		_shown = mini(_shown, base)
	_pending += count
	_burst(from, 1.6)
	_float_text(from, "+%s" % Dots.format(gained))
	var landed := [0]
	for i in count:
		var dot := TextureRect.new()
		dot.top_level = true
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dot.texture = _icon.texture
		dot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		dot.stretch_mode = TextureRect.STRETCH_SCALE
		dot.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var flyer_size := float(randi_range(2, 3) * 8)
		dot.size = Vector2.ONE * flyer_size
		add_child(dot)
		var scatter := from + Vector2.from_angle(randf() * TAU) * randf_range(40.0, 120.0)
		var target := _icon.get_global_rect().get_center()
		var control := scatter.lerp(target, 0.35) + Vector2(randf_range(-160, 160), randf_range(-140, -40))
		dot.position = from - dot.size / 2.0
		dot.scale = Vector2.ONE * 0.2
		dot.pivot_offset = dot.size / 2.0
		var t := create_tween()
		t.tween_interval(i * 0.035)
		t.tween_property(dot, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.parallel().tween_property(dot, "position", scatter - dot.size / 2.0, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		var flight := randf_range(0.42, 0.62)
		t.tween_method(func(k: float) -> void:
			# The counter may have moved (window resize): aim at it every frame.
			var end := _icon.get_global_rect().get_center()
			var a := scatter.lerp(control, k)
			var b := control.lerp(end, k)
			dot.position = a.lerp(b, k) - dot.size / 2.0
			dot.scale = Vector2.ONE * lerpf(1.0, 0.55, k), 0.0, 1.0, flight).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		t.tween_callback(func() -> void:
			dot.queue_free()
			landed[0] += 1
			_pending -= 1
			_land(base + gained * landed[0] / count))


## One dot arrives: the number ticks up and the icon pops.
func _land(value: int) -> void:
	GameAudio.play("dot_gain",Vector3.INF,{cooldown=.035,volume_db=-4})
	_shown = maxi(_shown, mini(value, _target))
	if _pending <= 0:
		_pending = 0
		_shown = _target
	_label.text = Dots.format(_shown)
	_icon.scale = Vector2.ONE * 1.55
	_label.scale = Vector2.ONE * 1.18
	_flash = 0.8
	_icon.modulate = Color(1.0, 1.0 + _flash * 0.18, 1.0)
	var t := create_tween().set_parallel()
	t.tween_property(_icon, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	t.tween_property(_label, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_method(func(k: float) -> void:
		_flash = lerpf(0.8, 0.0, k)
		_icon.modulate = Color(1.0, 1.0 + _flash * 0.18, 1.0), 0.0, 1.0, 0.25)
	if _pending == 0:
		_burst(_icon.get_global_rect().get_center(), 1.0)


## A ring of sparks.
func _burst(at: Vector2, strength: float) -> void:
	for i in int(10 * strength):
		var spark := Control.new()
		spark.top_level = true
		spark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		spark.size = Vector2(6, 6)
		spark.draw.connect(func() -> void: spark.draw_rect(Rect2(Vector2.ZERO, spark.size), Dots.COLOR.lightened(0.4)))
		spark.position = at - spark.size / 2.0
		add_child(spark)
		var dir := Vector2.from_angle(TAU * i / (10.0 * strength) + randf() * 0.3)
		var t := create_tween().set_parallel()
		t.tween_property(spark, "position", spark.position + dir * randf_range(26, 54) * strength, 0.35) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t.tween_property(spark, "modulate:a", 0.0, 0.35)
		t.chain().tween_callback(spark.queue_free)


func _float_text(at: Vector2, text: String) -> void:
	var label := UIStyle.label(text, 30, Dots.COLOR)
	label.add_theme_font_override("font", UIStyle.bold())
	label.add_theme_color_override("font_outline_color", Color(0.02, 0.1, 0.04))
	label.add_theme_constant_override("outline_size", 8)
	label.top_level = true
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	label.position = at - Vector2(40, 60)
	label.scale = Vector2.ONE * 0.4
	var t := create_tween()
	t.tween_property(label, "scale", Vector2.ONE * 1.15, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(label, "scale", Vector2.ONE, 0.1)
	t.tween_property(label, "position:y", label.position.y - 50, 0.9).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(label, "modulate:a", 0.0, 0.9).set_delay(0.3)
	t.tween_callback(label.queue_free)
