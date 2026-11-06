class_name PixelArt
## Helpers for the UI's pixel-art look. Everything is drawn as small "art
## pixels" and scaled up by SCALE with hard edges, so frames, bars, icons
## and the minimap all share the same chunky pixel grid.

const SCALE := 3

## A tiny 3 x 5 pixel font for badges and small numbers ("G1", "LV").
const TINY := {
	"0": ["111", "101", "101", "101", "111"], "1": ["010", "110", "010", "010", "111"],
	"2": ["111", "001", "111", "100", "111"], "3": ["111", "001", "111", "001", "111"],
	"4": ["101", "101", "111", "001", "001"], "5": ["111", "100", "111", "001", "111"],
	"6": ["111", "100", "111", "101", "111"], "7": ["111", "001", "010", "010", "010"],
	"8": ["111", "101", "111", "101", "111"], "9": ["111", "101", "111", "001", "111"],
	"G": ["111", "100", "101", "101", "111"], "L": ["100", "100", "100", "100", "111"],
	"V": ["101", "101", "101", "101", "010"], "+": ["000", "010", "111", "010", "000"],
	"N": ["101", "111", "111", "111", "101"], "D": ["110", "101", "101", "101", "110"],
	"F": ["111", "100", "110", "100", "100"], "x": ["000", "101", "010", "101", "000"],
}


## Image from rows of characters; each character is a key in `palette`
## (unknown characters stay transparent).
static func image_from_rows(rows: PackedStringArray, palette: Dictionary) -> Image:
	var w := 0
	for row in rows:
		w = maxi(w, row.length())
	var img := Image.create_empty(maxi(1, w), maxi(1, rows.size()), false, Image.FORMAT_RGBA8)
	for y in rows.size():
		for x in rows[y].length():
			if palette.has(rows[y][x]):
				img.set_pixel(x, y, palette[rows[y][x]])
	return img


static func upscale(img: Image, factor := SCALE) -> Image:
	var big := img.duplicate() as Image
	big.resize(img.get_width() * factor, img.get_height() * factor, Image.INTERPOLATE_NEAREST)
	return big


## A 12 x 12 art-pixel frame: dark outline with cut corners, a lit top/left
## bevel and shaded bottom/right (inset = the other way round, like a hole).
static func frame_image(fill: Color, outline: Color, light: Color, shade: Color, inset := false) -> Image:
	var n := 12
	var img := Image.create_empty(n, n, false, Image.FORMAT_RGBA8)
	var top := shade if inset else light
	var bottom := light if inset else shade
	for y in n:
		for x in n:
			var edge_x := x == 0 or x == n - 1
			var edge_y := y == 0 or y == n - 1
			if edge_x and edge_y:
				continue  # cut corner
			var c := fill
			if edge_x or edge_y or ((x == 1 or x == n - 2) and (y == 1 or y == n - 2)):
				c = outline
			elif y == 1 or x == 1:
				c = top
			elif y == n - 2 or x == n - 2:
				c = bottom
			img.set_pixel(x, y, c)
	return img


## A 12 x 12 art-pixel button: textured slate with a warm metallic trim,
## highlight, sitting on a darker lip that gives it depth. Pressed, the face
## drops onto the lip.
static func button_image(face: Color, lip: Color, outline: Color, highlight: Color, pressed := false) -> Image:
	var n := 12
	var img := Image.create_empty(n, n, false, Image.FORMAT_RGBA8)
	var top := 2 if pressed else 0  # pressed: the whole cap sits 2 pixels lower
	var lip_rows := 1 if pressed else 3
	for y in range(top, n):
		for x in n:
			var edge_x := x == 0 or x == n - 1
			var edge_y := y == top or y == n - 1
			if edge_x and edge_y:
				continue  # cut corner
			var c := face
			if edge_x or edge_y:
				c = outline
			elif y >= n - 1 - lip_rows:
				c = lip
			elif y == top + 1:
				c = highlight
			img.set_pixel(x, y, c)
	return img


## A StyleBox from a frame image: the 4-pixel border keeps its pixels, the
## middle stretches.
static func box(img: Image, content_margin := 10.0) -> StyleBoxTexture:
	var s := StyleBoxTexture.new()
	s.texture = ImageTexture.create_from_image(upscale(img))
	var m := 4 * SCALE
	s.texture_margin_left = m
	s.texture_margin_top = m
	s.texture_margin_right = m
	s.texture_margin_bottom = m
	s.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	s.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	s.set_content_margin_all(content_margin)
	return s


## Draws rows of art pixels at `origin`, each `scale` screen pixels big.
static func draw_rows(ci: CanvasItem, origin: Vector2, rows: PackedStringArray, palette: Dictionary,
		scale := SCALE) -> void:
	for y in rows.size():
		for x in rows[y].length():
			if palette.has(rows[y][x]):
				ci.draw_rect(Rect2(origin + Vector2(x, y) * scale, Vector2.ONE * scale), palette[rows[y][x]])


## Small smooth text for icon badges, counts and compass labels.
static func draw_tiny(ci: CanvasItem, origin: Vector2, text: String, color: Color, scale := 2) -> void:
	var font := UIStyle.bold()
	var at := origin + Vector2(0, 5 * scale)
	ci.draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 7 * scale, 2, Color(0, 0, 0, 0.85))
	ci.draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 7 * scale, color)


static func tiny_width(text: String, scale := 2) -> float:
	return UIStyle.bold().get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 7 * scale).x
