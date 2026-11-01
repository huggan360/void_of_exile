class_name XpRing
extends Control
## Round XP meter in pixel art: a chunky pixel ring that fills toward the
## next level, with the level number in the middle. Pulses on level up.

const PX := PixelArt.SCALE
const ART := 28  # art pixels across
const RING_OUT := 13.0
const RING_IN := 9.5

var level := 1
var progress := 0.0  # 0..1
var _shown := 0.0
var _pulse := 0.0
var _level_label := Label.new()


func _init() -> void:
	custom_minimum_size = Vector2(ART, ART) * PX


func _ready() -> void:
	_level_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_level_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_level_label.offset_top = 8
	UIStyle.text(_level_label, UIStyle.SIZE_LARGE, UIStyle.TEXT)
	_level_label.add_theme_font_override("font", UIStyle.bold())
	add_child(_level_label)


func set_values(p_level: int, p_progress: float) -> void:
	if p_level > level:
		_pulse = 1.0
		_shown = 0.0
	level = p_level
	progress = p_progress
	_level_label.text = str(level)
	tooltip_text = "Level %d · %d%% to next" % [level, int(progress * 100)]


func _process(delta: float) -> void:
	_shown = move_toward(_shown, progress, delta * 1.5)
	_pulse = maxf(0.0, _pulse - delta * 1.5)
	queue_redraw()


func _draw() -> void:
	var c := Vector2(ART, ART) * 0.5
	for y in ART:
		for x in ART:
			var d := Vector2(x + 0.5, y + 0.5) - c
			var r := d.length()
			var col := Color(0, 0, 0, 0)
			if r > RING_OUT + 1.0:
				continue
			elif r > RING_OUT:
				col = UIStyle.OUTLINE
			elif r > RING_IN:
				# Angle from the top, clockwise, 0..1.
				var a := fposmod(atan2(d.x, -d.y) / TAU, 1.0)
				if a <= _shown:
					col = UIStyle.ACCENT.lerp(UIStyle.XP, a)
					if r > RING_OUT - 1.0:
						col = col.lightened(0.3)  # lit outer edge
				else:
					col = Color(0.08, 0.08, 0.15)
			elif r > RING_IN - 1.0:
				col = UIStyle.OUTLINE
			else:
				col = UIStyle.BG if d.y > 0 else UIStyle.BG_LIGHT  # two-tone center
			if _pulse > 0.0 and r > RING_IN:
				col = col.lerp(UIStyle.GOLD, _pulse * 0.7)
			draw_rect(Rect2(Vector2(x, y) * PX, Vector2.ONE * PX), col)
	PixelArt.draw_tiny(self, Vector2(ART * 0.5 * PX - PixelArt.tiny_width("LV") * 0.5, 7 * PX), "LV", UIStyle.TEXT_DIM)
