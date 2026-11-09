class_name SignBoard
extends Node3D
## A real sign instead of floating text: a board (wood, a brass plaque, a dark
## neon box, or just paint on a surface) with its words in a chunky pixel font
## and, if it has one, a little pixel picture (a beer mug over a bar, a cup over
## a cafe, a helm wheel on the pilot's chair). Its face is +Z, its middle the
## node's origin. set_text() redraws it (displays that change).
const PX := 0.045  # metres per pixel at scale 1
const FONT := {
	"A": "01110100011000111111100011000110001", "B": "11110100011000111110100011000111110", "C": "01110100011000010000100001000101110",
	"D": "11110100011000110001100011000111110", "E": "11111100001000011110100001000011111", "F": "11111100001000011110100001000010000",
	"G": "01110100011000010111100011000101111", "H": "10001100011000111111100011000110001", "I": "01110001000010000100001000010001110",
	"J": "00111000100001000010000101001001100", "K": "10001100101010011000101001001010001", "L": "10000100001000010000100001000011111",
	"M": "10001110111010110101100011000110001", "N": "10001110011010110011100011000110001", "O": "01110100011000110001100011000101110",
	"P": "11110100011000111110100001000010000", "Q": "01110100011000110001101011001001101", "R": "11110100011000111110101001001010001",
	"S": "01111100001000001110000010000111110", "T": "11111001000010000100001000010000100", "U": "10001100011000110001100011000101110",
	"V": "10001100011000110001100010101000100", "W": "10001100011000110101101011010101010", "X": "10001100010101000100010101000110001",
	"Y": "10001100010101000100001000010000100", "Z": "11111000010001000100010001000011111",
	"0": "01110100011001110101110011000101110", "1": "00100011000010000100001000010001110", "2": "01110100010000100010001000100011111",
	"3": "11110000010000101110000010000111110", "4": "00010001100101010010111110001000010", "5": "11111100001111000001000011000101110",
	"6": "00110010001000011110100011000101110", "7": "11111000010001000100010000100001000", "8": "01110100011000101110100011000101110",
	"9": "01110100011000101111000010001001100", " ": "00000000000000000000000000000000000", ".": "00000000000000000000000000110001100",
	",": "00000000000000000000011000010001000", "!": "00100001000010000100001000000000100", "?": "01110100010000100010001000000000100",
	"'": "00100001000100000000000000000000000", "-": "00000000000000011111000000000000000", ":": "00000011000110000000011000110000000",
	"/": "00001000100001000100010000100010000", "&": "01100100101010001000101011001001101", "+": "00000001000010011111001000010000000",
	"(": "00010001000100001000010000010000010", ")": "01000001000001000010000100010001000", "#": "01010010101111101010111110101001010",
	"%": "11001110100001000100010000101110011", ">": "01000001000001000001000100010001000", "<": "00010001000100010000010000010000010",
	"=": "00000000001111100000111110000000000",
}
## Twelve-square pictures: rows, and what each letter paints.
const ICONS := {
	beer = [{a = "e8a23a", w = "f4ecd8", b = "c8902a", d = "5a3a2a"}, ["..wwwwww....", ".wwwwwwww...", ".aaaaaaaa...", ".aaaaaaaabb.", ".aaaaaaaa.b.", ".aaaaaaaa.b.",
		".aaaaaaaa.b.", ".aaaaaaaabb.", ".aaaaaaaa...", ".aaaaaaaa...", ".dddddddd...", "............"]],
	coffee = [{s = "d8d0e0", c = "f0e6d0", b = "6a3a22", d = "8a6a4a"}, ["...s..s.....", "..s..s......", "...s..s.....", "............", ".cccccccc...", ".cbbbbbbcc..",
		".cbbbbbbc.c.", ".cbbbbbbc.c.", ".cbbbbbbcc..", "..cccccc....", "dddddddddd..", "............"]],
	bowl = [{k = "c8905a", y = "ffe08a", r = "d84a4a", d = "5a2a2a"}, ["..k..k......", "..k..k......", "...k..k.....", "...k..k.....", "yyyyyyyyyyyy", "rrrrrrrrrrrr",
		".rrrrrrrrrr.", ".rrrrrrrrrr.", "..rrrrrrrr..", "...rrrrrr...", "....dddd....", "............"]],
	tea = [{t = "7ad8b0", d = "3a6a5a"}, ["....tt......", "...tttt.....", ".tttttttt...", "tttttttttt.t", "tt.tttttttt.", "tt.ttttttt..",
		"tt.ttttttt..", ".tttttttt...", "..tttttt....", "...dddd.....", "............", "............"]],
	potion = [{c = "c8a070", g = "d8e8f0", p = "c84ad8", w = "ffffff"}, ["....cc......", "....cc......", "...cccc.....", "....gg......", "....gg......", "...gppg.....",
		"..gppppg....", ".gppppppg...", ".gppwpppg...", ".gppppppg...", "..gggggg....", "............"]],
	sword = [{s = "d8e0f0", h = "d9ac60", g = "8a5a3a"}, ["..........s.", ".........ss.", "........ss..", ".......ss...", "......ss....", ".....ss.....",
		"..h.ss......", "...hs.......", "...hh.......", "..g..h......", ".g..........", "............"]],
	star = [{y = "ffd84a"}, [".....yy.....", ".....yy.....", "....yyyy....", "yyyyyyyyyyyy", ".yyyyyyyyyy.", "..yyyyyyyy..",
		"...yyyyyy...", "..yyyyyyyy..", "..yyy..yyy..", ".yyy....yyy.", ".yy......yy.", "............"]],
	gem = [{c = "6af0e0", w = "ffffff", b = "2a8a9a"}, ["............", "...cccccc...", "..cwcccccc..", ".cwccccccbc.", "cccccccccbbc", ".cccccccbbc.",
		"..ccccccbc..", "...ccccbc...", "....cccc....", ".....cc.....", "............", "............"]],
	arrow = [{a = "ffd27a"}, ["............", "......a.....", "......aa....", "......aaa...", "aaaaaaaaaa..", "aaaaaaaaaaa.",
		"aaaaaaaaaa..", "......aaa...", "......aa....", "......a.....", "............", "............"]],
	helm = [{w = "c8904a", h = "ffd27a"}, [".....w......", "..w..w..w...", "...wwwww....", "..ww...ww...", "wwww.h.wwww.", "..ww...ww...",
		"...wwwww....", "..w..w..w...", ".....w......", "............", "............", "............"]],
	cannon = [{m = "6a6a7a", w = "8a5a3a"}, ["............", "............", "......mmmmmm", "....mmmmmmmm", "...mmmmmmmmm", "....mmmmmmmm",
		"..ww..mmmmmm", ".wwww.......", ".w..w.......", ".wwww.......", "..ww........", "............"]],
	map = [{p = "e8d8b0", r = "d84a4a", x = "2a2a2a"}, ["pppppppppp..", "p...p...p...", "p.r.p...p...", "p..rp..rp...", "p...r.r.p...", "p...pr..p...",
		"p..xpr..p...", "p...p...p...", "pppppppppp..", "............", "............", "............"]],
	door = [{w = "d9ac60", d = "6a4a3a", y = "ffe08a"}, ["..wwwwwww...", "..wdddddw...", "..wdddddw...", "..wdddddw...", "..wddddyw...", "..wdddddw...",
		"..wdddddw...", "..wdddddw...", "..wwwwwww...", "............", "............", "............"]],
	game = [{g = "8a6ad8", w = "f0f0ff", r = "ff5a6a", b = "5ad8ff"}, ["............", "............", ".gggggggggg.", "gggggggggggg", "gwgggggggrgg", "wwwgggggrgbg",
		"gwgggggggbgg", "gggg....gggg", ".gg......gg.", "............", "............", "............"]],
	chair = [{w = "c8904a"}, ["..ww........", "..ww........", "..ww........", "..ww........", "..wwwwwww...", "..wwwwwww...",
		"..w.....w...", "..w.....w...", "..w.....w...", "............", "............", "............"]],
	lift = [{a = "ffd27a"}, ["....aa......", "...aaaa.....", "..aaaaaa....", "....aa......", "....aa......", "............",
		"....aa......", "....aa......", "..aaaaaa....", "...aaaa.....", "....aa......", "............"]],
	heart = [{a = "ff4a7a"}, ["............", ".aaa...aaa..", "aaaaa.aaaaa.", "aaaaaaaaaaa.", "aaaaaaaaaaa.", ".aaaaaaaaa..",
		"..aaaaaaa...", "...aaaaa....", "....aaa.....", ".....a......", "............", "............"]],
}
## board, frame, ink (text), glow.
const STYLES := {
	plank = ["8a5a3a", "4a3024", "f4e6c8", 0.12],
	brass = ["2a2030", "d9ac60", "ffd27a", 0.2],
	neon = ["161222", "3a2a4a", "", 1.8],
	paint = ["", "", "", 0.15],
	slate = ["3a3a44", "6a6a7a", "e8e8f0", 0.12],
}
static var _textures := {}
static var _materials := {}
var style := "plank"
var icon := ""
var ink := Color(0, 0, 0, 0)
var size := 1.0
var _face: MeshInstance3D
var _board: MeshInstance3D
var _frame: MeshInstance3D
var _text := ""

## A sign reading `text` (lines split by "\n"). `ink` empty uses the style's.
static func make(text: String, p_style := "plank", p_icon := "", p_ink := Color(0, 0, 0, 0), p_size := 1.0) -> SignBoard:
	var sign := SignBoard.new()
	sign.style = p_style
	sign.icon = p_icon
	sign.ink = p_ink
	sign.size = p_size
	sign.set_text(text)
	return sign

func set_text(text: String) -> void:
	if text==_text and _face: return
	_text = text
	var spec: Array = STYLES.get(style, STYLES.plank)
	var color := ink if ink.a>0.0 else Color(str(spec[2])) if str(spec[2])!="" else Color("ff6eb4")
	var tex := texture(text, color, icon)
	var px := PX*size
	var face := Vector2(tex.get_width(), tex.get_height())*px
	if _face==null:
		_face = MeshInstance3D.new()
		_face.mesh = QuadMesh.new()
		_face.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_face)
	(_face.mesh as QuadMesh).size = face
	_face.material_override = _material(tex, float(spec[3]))
	_face.position = Vector3(0, 0, 0.051 if style!="paint" else 0.0)
	if style=="paint": return
	var margin := px*4.0
	var board := Vector3(face.x+margin*2.0, face.y+margin*2.0, 0.08)
	if _board==null:
		_board = MeshInstance3D.new()
		_board.mesh = BoxMesh.new()
		add_child(_board)
		_frame = MeshInstance3D.new()
		_frame.mesh = BoxMesh.new()
		add_child(_frame)
		_board.material_override = _plain(Color(str(spec[0])), 0.0)
		_frame.material_override = _plain(Color(str(spec[1])) if style!="neon" else color, 1.4 if style=="neon" else 0.0)
	(_board.mesh as BoxMesh).size = board
	(_frame.mesh as BoxMesh).size = board+Vector3(px*2.0, px*2.0, -0.02)
	_frame.position = Vector3(0, 0, -0.02)

## `text` broken into lines of at most `width` letters.
static func wrap(text: String, width := 28) -> String:
	var out: PackedStringArray = []
	for para in text.split("\n"):
		var line := ""
		for word in para.split(" "):
			if line!="" and line.length()+1+word.length()>width:
				out.append(line)
				line = word
			else: line = word if line=="" else line+" "+word
		out.append(line)
	return "\n".join(out)

## Two signs back to back (readable from both sides) under one node; the
## node's set_text-like update is pair_text().
static func pair(text: String, p_style := "slate", p_icon := "", p_ink := Color(0, 0, 0, 0), p_size := 1.0) -> Node3D:
	var root := Node3D.new()
	for k in 2:
		var sign := make(text, p_style, p_icon, p_ink, p_size)
		sign.rotation.y = k*PI
		sign.position = Vector3(0, 0, 0.045 if k==0 else -0.045)
		root.add_child(sign)
	return root

static func pair_text(root: Node3D, text: String) -> void:
	for sign in root.get_children():
		if sign is SignBoard: (sign as SignBoard).set_text(text)

## Width and height of the board (or the paint) in metres.
func extent() -> Vector2:
	if _board: return Vector2((_board.mesh as BoxMesh).size.x, (_board.mesh as BoxMesh).size.y)
	return (_face.mesh as QuadMesh).size if _face else Vector2.ZERO

## A wooden post with the sign on top, readable from both sides (face +Z and -Z).
static func post(text: String, p_style := "plank", p_icon := "", height := 2.2, p_size := 1.0) -> Node3D:
	var root := Node3D.new()
	var pole := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.16, height, 0.16)
	pole.mesh = box
	pole.material_override = _plain(Color("4a3024"), 0.0)
	pole.position = Vector3.UP*height*0.5
	root.add_child(pole)
	for k in 2:
		var sign := make(text, p_style, p_icon, Color(0, 0, 0, 0), p_size)
		sign.rotation.y = k*PI
		sign.position = Vector3(0, height+sign.extent().y*0.5-0.1, 0.05 if k==0 else -0.05)
		root.add_child(sign)
	return root

## Hang it from a bracket off a wall: an arm out from the wall and two chains.
## The sign then sits `drop` below the arm.
func hang(drop := 0.35) -> SignBoard:
	var arm := MeshInstance3D.new()
	var box := BoxMesh.new()
	var width := (_board.mesh as BoxMesh).size.x if _board else 1.0
	box.size = Vector3(width+0.3, 0.08, 0.08)
	arm.mesh = box
	arm.material_override = _plain(Color("2a2420"), 0.0)
	arm.position = Vector3(0, (_board.mesh as BoxMesh).size.y*0.5+drop if _board else 0.5, 0)
	add_child(arm)
	for side: float in [-1.0, 1.0]:
		var chain := MeshInstance3D.new()
		var link := BoxMesh.new()
		link.size = Vector3(0.03, drop, 0.03)
		chain.mesh = link
		chain.material_override = arm.material_override
		chain.position = arm.position+Vector3(side*width*0.4, -drop*0.5, 0)
		add_child(chain)
	return self

# --- Drawing -----------------------------------------------------------------------------------

## The words (and picture) in pixels, a shadow under every letter so it reads.
static func texture(text: String, color: Color, p_icon := "") -> ImageTexture:
	var key := "%s|%s|%s" % [text, color.to_html(), p_icon]
	if _textures.has(key): return _textures[key]
	var lines := text.to_upper().split("\n")
	var widest := 0
	for line in lines: widest = maxi(widest, line.length()*6-1)
	var text_h := lines.size()*9-2
	var pic := ICONS.has(p_icon)
	var w := widest+(14 if pic else 0)+2
	var h := maxi(text_h, 12 if pic else 0)+2
	var image := Image.create(maxi(w, 2), maxi(h, 2), false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var shade := color.darkened(0.75)
	shade.a = 0.9
	var x0 := 1
	if pic:
		var spec: Array = ICONS[p_icon]
		var colors: Dictionary = spec[0]
		var rows: Array = spec[1]
		var top := (h-12)/2
		for y in 12:
			for x in 12:
				var ch := str(rows[y])[x]
				if ch!=".": image.set_pixel(x0+x, top+y, Color(str(colors[ch])))
		x0 += 14
	var y0 := (h-text_h)/2
	for l in lines.size():
		var line := lines[l]
		var lx := x0+(widest-(line.length()*6-1))/2
		for k in line.length():
			var glyph := str(FONT.get(line[k], FONT["?"]))
			for gy in 7:
				for gx in 5:
					if glyph[gy*5+gx]!="1": continue
					var px := lx+k*6+gx
					var py := y0+l*9+gy
					if py+1<h and image.get_pixel(px, py+1).a<0.5: image.set_pixel(px, py+1, shade)
					image.set_pixel(px, py, color if gy>0 else color.lightened(0.3))
	var tex := ImageTexture.create_from_image(image)
	_textures[key] = tex
	return tex

static func _material(tex: ImageTexture, glow: float) -> StandardMaterial3D:
	var key := "%d|%f" % [tex.get_rid().get_id(), glow]
	if _materials.has(key): return _materials[key]
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = 0.5
	m.roughness = 0.85
	m.emission_enabled = true
	m.emission_texture = tex
	m.emission_energy_multiplier = glow
	_materials[key] = m
	return m

static func _plain(color: Color, glow: float) -> StandardMaterial3D:
	var key := "plain|%s|%f" % [color.to_html(), glow]
	if _materials.has(key): return _materials[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.8
	if glow>0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = glow
	_materials[key] = m
	return m
