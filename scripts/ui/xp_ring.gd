class_name XpRing
extends Control
## A textured black-stone XP dial, exactly as wide as the two equipment columns.
const DIAMETER := ItemSlot.SLOT_SIZE * 2.0 + ItemSlot.SLOT_GAP
var level := 1
var progress := 0.0
var _shown := 0.0
var _initialized := false
var _pulse := 0.0
var _level_label := Label.new()
var _face := TextureRect.new()
var _skin := ShaderMaterial.new()

func _init() -> void:
	custom_minimum_size = Vector2.ONE * DIAMETER

func _ready() -> void:
	_face.texture = preload("res://assets/ui/black/ui_xp_ring.png")
	_face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_face.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_face.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_skin.shader = preload("res://shaders/xp_ring.gdshader")
	_face.material = _skin
	add_child(_face)
	var caption := UIStyle.label("LV", 16, Color.WHITE)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(caption)
	caption.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	caption.offset_top = 43
	caption.offset_bottom = -83
	_level_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_level_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UIStyle.text(_level_label, 32, Color.WHITE)
	_level_label.add_theme_font_override("font", UIStyle.bold())
	add_child(_level_label)
	_level_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_level_label.offset_top = 12
	_skin.set_shader_parameter("progress", _shown)

func set_values(p_level: int, p_progress: float) -> void:
	var target := 1.0 if p_level >= PlayerStats.MAX_LEVEL else clampf(p_progress, 0.0, 1.0)
	if _initialized and p_level == level and is_equal_approx(target, progress): return
	if not _initialized or p_level < level:
		_shown = target
	elif p_level > level:
		_pulse = 1.0
		_shown = 0.0
	_initialized = true
	level = p_level
	progress = target
	_level_label.text = str(level)
	_skin.set_shader_parameter("progress", _shown)
	tooltip_text = "Level %d - MAX" % level if level >= PlayerStats.MAX_LEVEL else "Level %d - %d%% to next" % [level, int(progress * 100)]


func _process(delta: float) -> void:
	_shown = move_toward(_shown, progress, delta * 1.5)
	_pulse = maxf(0.0, _pulse - delta * 1.5)
	_skin.set_shader_parameter("progress", _shown)
	_skin.set_shader_parameter("pulse", _pulse)
