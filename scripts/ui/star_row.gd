class_name StarRow
extends Control
## Five small pixel-art stars: gold while earned or still within reach, dim
## once lost (the quest banner, a campaign's results).

const STAR := [  # 7 x 7, "#" filled
	"...#...",
	"...#...",
	"#######",
	".#####.",
	"..###..",
	".##.##.",
	"##...##",
]

var star_px := 2.0
var _kept: Array = [true, true, true, true, true]


func _init(px := 2.0) -> void:
	star_px = px
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(5 * 9 * star_px, 7 * star_px)


func set_stars(kept: Array) -> void:
	if kept != _kept:
		_kept = kept.duplicate()
		queue_redraw()


func _draw() -> void:
	for i in _kept.size():
		var color := UIStyle.GOLD if _kept[i] else Color(0.3, 0.32, 0.42)
		var origin := Vector2(i * 9 * star_px, 0)
		for y in STAR.size():
			for x in STAR[y].length():
				if STAR[y][x] == "#":
					draw_rect(Rect2(origin + Vector2(x, y) * star_px, Vector2.ONE * star_px), color)
