class_name CityTextures
## Vesperis's pixel art, drawn in code at ten pixels a metre (the same grain as
## the voxel props): asphalt, concrete sidewalk slabs, kerb stones, cobbles and
## grass for the ground shader, and the fifteen graffiti on the city's walls.
## Everything tiles and is cached; filter it nearest so the pixels stay crisp.
const PX := 10.0  # pixels per metre
static var _cache := {}

static func _rand(x: int, y: int, salt: int) -> float:
	return CityLayout._hash(x*73856093 ^ y*19349663 ^ salt*83492791)

static func _tex(key: String, image: Image) -> ImageTexture:
	var t := ImageTexture.create_from_image(image)
	_cache[key] = t
	return t

## Tileable value noise (period `size` pixels, cells of `cell`).
static func _noise(x: int, y: int, size: int, cell: int, salt: int) -> float:
	var cells := size/cell
	var fx := float(x)/cell
	var fy := float(y)/cell
	var x0 := int(floor(fx))
	var y0 := int(floor(fy))
	var tx := smoothstep(0.0, 1.0, fx-x0)
	var ty := smoothstep(0.0, 1.0, fy-y0)
	var v := func(cx: int, cy: int) -> float: return _rand(posmod(cx, cells), posmod(cy, cells), salt)
	return lerpf(lerpf(v.call(x0, y0), v.call(x0+1, y0), tx), lerpf(v.call(x0, y0+1), v.call(x0+1, y0+1), tx), ty)

## Dark violet asphalt with grit, patches and the odd light pebble (6.4 m).
static func asphalt() -> ImageTexture:
	if _cache.has("asphalt"): return _cache.asphalt
	var size := 64
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var tones := [Color("23202b"), Color("2a2633"), Color("302b3a"), Color("1d1a24")]
	for y in size:
		for x in size:
			var patch := _noise(x, y, size, 16, 3)
			var r := _rand(x, y, 1)
			var c: Color = tones[int(r*3.0)] if r<0.97 else tones[3]
			c = c.darkened(0.12) if patch<0.32 else c.lightened(0.04) if patch>0.7 else c
			if _rand(x, y, 2)>0.985: c = Color("4a4552")
			image.set_pixel(x, y, c)
	return _tex("asphalt", image)

## Concrete sidewalk slabs (1.6 m): each slab its own grey, bevelled light at
## the top left and dark at the bottom right, cracks, stains and pebbles (6.4 m).
static func slabs() -> ImageTexture:
	if _cache.has("slabs"): return _cache.slabs
	var size := 64
	var slab := 16
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in size:
		for x in size:
			var sx := x/slab
			var sy := y/slab
			var lx := x % slab
			var ly := y % slab
			var tone := _rand(sx, sy, 11)
			var c := Color("8c8592").lerp(Color("a29aa0"), tone).lerp(Color("7e8a8c"), _rand(sx, sy, 12)*0.35)
			c = c.darkened((_rand(x, y, 13)-0.5)*0.09)
			if _rand(x, y, 14)>0.97: c = c.darkened(0.18)
			if _noise(x, y, size, 8, 15)<0.22 and tone>0.6: c = c.darkened(0.1)  # a stain
			if lx==0 or ly==0: c = Color("57505e")
			elif lx==1 or ly==1: c = c.lightened(0.12)
			elif lx==slab-1 or ly==slab-1: c = c.darkened(0.16)
			image.set_pixel(x, y, c)
	# A few cracks wandering across slabs.
	for k in 5:
		var px := int(_rand(k, 0, 16)*size)
		var py := int(_rand(k, 1, 16)*size)
		for step in 14:
			image.set_pixel(posmod(px, size), posmod(py, size), Color("5c5462"))
			px += 1 if _rand(k, step, 17)<0.6 else 0
			py += [-1, 0, 1][int(_rand(k, step, 18)*3.0)]
	return _tex("slabs", image)

## Kerb stones along the road (1 m long), pale with a bevel (6.4 x 1.6 m).
static func kerb() -> ImageTexture:
	if _cache.has("kerb"): return _cache.kerb
	var w := 64
	var h := 16
	var image := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var stone := x/10
			var c := Color("b8b0b0").lerp(Color("cfc6bc"), _rand(stone, 0, 21)).darkened((_rand(x, y, 22)-0.5)*0.08)
			if x % 10==0: c = Color("6a6270")
			elif y<2: c = c.lightened(0.14)
			elif y>h-3: c = c.darkened(0.2)
			image.set_pixel(x, y, c)
	return _tex("kerb", image)

## Round cobbles for courtyards and plazas (6.4 m).
static func cobbles() -> ImageTexture:
	if _cache.has("cobbles"): return _cache.cobbles
	var size := 64
	var cell := 6
	var cells := size/cell+1
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var centre := func(cx: int, cy: int) -> Vector2:
		var wx := posmod(cx, cells)
		var wy := posmod(cy, cells)
		return Vector2(cx*cell+1+_rand(wx, wy, 31)*(cell-2), cy*cell+1+_rand(wx, wy, 32)*(cell-2))
	for y in size:
		for x in size:
			var p := Vector2(x, y)
			var best := 1e9
			var second := 1e9
			var id := Vector2i.ZERO
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					var cx := x/cell+dx
					var cy := y/cell+dy
					var d := p.distance_to(centre.call(cx, cy))
					if d<best:
						second = best
						best = d
						id = Vector2i(posmod(cx, cells), posmod(cy, cells))
					elif d<second: second = d
			var c := Color("6e6474").lerp(Color("8a7c84"), _rand(id.x, id.y, 33))
			if second-best<1.2: c = Color("3e3844")
			elif best<1.4: c = c.lightened(0.1)
			image.set_pixel(x, y, c)
	return _tex("cobbles", image)

## Grass with blades, clover and small flowers (6.4 m).
static func grass() -> ImageTexture:
	if _cache.has("grass"): return _cache.grass
	var size := 64
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var greens := [Color("2f5a3a"), Color("3a6a42"), Color("447a4a"), Color("2a4e3a")]
	for y in size:
		for x in size:
			var patch := _noise(x, y, size, 16, 41)
			var c: Color = greens[int(_rand(x, y, 42)*3.0)]
			c = c.darkened(0.12) if patch<0.35 else c.lightened(0.06) if patch>0.7 else c
			if _rand(x, y, 43)>0.93: c = Color("5a9a5a")
			image.set_pixel(x, y, c)
	var petals := [Color("ff9ccf"), Color("ffe08a"), Color("f0f0ff"), Color("b89aff")]
	for k in 18:
		var fx := int(_rand(k, 1, 44)*size)
		var fy := int(_rand(k, 2, 44)*size)
		var col: Color = petals[k % petals.size()]
		for o: Vector2i in [Vector2i(0, -1), Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, 1)]:
			image.set_pixel(posmod(fx+o.x, size), posmod(fy+o.y, size), col)
		image.set_pixel(fx, fy, Color("ffcf4a"))
	return _tex("grass", image)

# --- Graffiti ---------------------------------------------------------------------------------------

const GRAFFITI_COUNT := 15
## Tags: word, fill top, fill bottom, outline.
const TAGS := [["VOID", "ff6eb4", "9a8aff", "1a1026"], ["LUX", "ffe08a", "ff8a5a", "2a1410"], ["ORIN", "6af0e0", "4a8aff", "0e1a2a"],
	["ZAP!", "fff06a", "8dff9a", "14200e"], ["DOTS", "8dff9a", "2fb8a8", "0a1e18"], ["HEX", "ff8a5a", "ff3a6a", "240a10"],
	["BOO", "f0f0ff", "b89aff", "1e1430"]]
## Five by seven letters.
const FONT := {
	"V": ["10001", "10001", "10001", "10001", "01010", "01010", "00100"],
	"O": ["01110", "10001", "10001", "10001", "10001", "10001", "01110"],
	"I": ["11111", "00100", "00100", "00100", "00100", "00100", "11111"],
	"D": ["11110", "10001", "10001", "10001", "10001", "10001", "11110"],
	"L": ["10000", "10000", "10000", "10000", "10000", "10000", "11111"],
	"U": ["10001", "10001", "10001", "10001", "10001", "10001", "01110"],
	"X": ["10001", "10001", "01010", "00100", "01010", "10001", "10001"],
	"R": ["11110", "10001", "10001", "11110", "10100", "10010", "10001"],
	"N": ["10001", "11001", "10101", "10101", "10011", "10001", "10001"],
	"Z": ["11111", "00001", "00010", "00100", "01000", "10000", "11111"],
	"A": ["01110", "10001", "10001", "11111", "10001", "10001", "10001"],
	"P": ["11110", "10001", "10001", "11110", "10000", "10000", "10000"],
	"!": ["00100", "00100", "00100", "00100", "00100", "00000", "00100"],
	"T": ["11111", "00100", "00100", "00100", "00100", "00100", "00100"],
	"S": ["01111", "10000", "10000", "01110", "00001", "00001", "11110"],
	"H": ["10001", "10001", "10001", "11111", "10001", "10001", "10001"],
	"E": ["11111", "10000", "10000", "11110", "10000", "10000", "11111"],
	"B": ["11110", "10001", "10001", "11110", "10001", "10001", "11110"],
}
## Little pictures, sixteen square: letter -> color (". " clear).
const ICONS := [
	{name = "heart", colors = {"a": "ff4a7a", "b": "ffb0c8"}, rows = [
		"................", "..aaa......aaa..", ".aabbaa..aaaaaa.", "aabbaaaaaaaaaaaa", "aabaaaaaaaaaaaaa", "aaaaaaaaaaaaaaaa",
		"aaaaaaaaaaaaaaaa", ".aaaaaaaaaaaaaa.", "..aaaaaaaaaaaa..", "...aaaaaaaaaa...", "....aaaaaaaa....", ".....aaaaaa.....",
		"......aaaa......", ".......aa.......", "................", "................"]},
	{name = "star", colors = {"a": "ffe08a", "b": "fff6c8"}, rows = [
		".......aa.......", ".......aa.......", "......abba......", "......abba......", "aaaaaaabbaaaaaaa", ".aaaabbbbbbaaaa.",
		"..aaaabbbbaaaa..", "...aaaaaaaaaa...", "....aaaaaaaa....", "....aaaaaaaa....", "...aaaa..aaaa...", "...aaa....aaa...",
		"..aaa......aaa..", "..aa........aa..", ".aa..........aa.", "................"]},
	{name = "smile", colors = {"a": "fff06a", "b": "2a2010", "c": "ff8a5a"}, rows = [
		".....aaaaaa.....", "...aaaaaaaaaa...", "..aaaaaaaaaaaa..", ".aaaabbaaabbaaa.", ".aaaabbaaabbaaa.", "aaaaabbaaabbaaaa",
		"aaaaaaaaaaaaaaaa", "aacaaaaaaaaaacaa", "aaaaaaaaaaaaaaaa", "aabaaaaaaaaaabaa", ".aabaaaaaaaabaa.", ".aaabbbbbbbbaaa.",
		"..aaaaaaaaaaaa..", "...aaaaaaaaaa...", ".....aaaaaa.....", "......a....a...."]},
	{name = "rocket", colors = {"a": "f0f0ff", "b": "ff4a5a", "c": "6af0e0", "d": "ffb84a"}, rows = [
		".......bb.......", "......bbbb......", ".....aaaaaa.....", ".....aaaaaa.....", ".....aaccaa.....", ".....acccca.....",
		".....aaccaa.....", ".....aaaaaa.....", ".....aaaaaa.....", "....baaaaaab....", "...bbaaaaaabb...", "...bb.aaaa.bb...",
		"......dddd......", ".......dd.......", "......d..d......", ".......dd......."]},
	{name = "mushroom", colors = {"a": "d83a4a", "b": "fff0e0", "c": "e8d8b8", "d": "2a1a1a"}, rows = [
		".....aaaaaa.....", "...aabaaaabaa...", "..aabbaaaaaaaa..", ".aaaaaaabbaaaaa.", ".abaaaaabbaaaba.", "aabbaaaaaaaabbaa",
		"aaaaaaaaaaaaaaaa", "aaaaaaaaaaaaaaaa", "....cccccccc....", ".....cdccdcc....", ".....cccccc.....", ".....cccccc.....",
		".....cccccc.....", "....cccccccc....", "...cccccccccc...", "................"]},
	{name = "cat", colors = {"a": "9a8aff", "b": "fff06a", "c": "ff9ccf", "d": "1a1026"}, rows = [
		".a............a.", ".aa..........aa.", ".aaa........aaa.", ".aaaaaaaaaaaaaa.", "aaaaaaaaaaaaaaaa", "aaabbaaaaaabbaaa",
		"aaabdaaaaaabdaaa", "aaaaaaaaaaaaaaaa", "aaaaaaacaaaaaaaa", "daaaaaccaaaaaaad", "aadaaaaaaaaaadaa", ".aaaadaaaadaaaa.",
		"..aaaaddddaaaa..", "...aaaaaaaaaa...", ".....aaaaaa.....", "................"]},
	{name = "crown", colors = {"a": "ffcf4a", "b": "ff4a7a", "c": "6af0e0"}, rows = [
		"................", "................", "a......a......a.", "aa....aaa....aa.", "aaa..aaaaa..aaa.", "aaaaaaaaaaaaaaa.",
		"aaaaaaaaaaaaaaa.", "aabaaacaaacaaba.", "aabaaacaaacaaba.", "aaaaaaaaaaaaaaa.", "aaaaaaaaaaaaaaa.", "................",
		"................", "................", "................", "................"]},
	{name = "eye", colors = {"a": "f0f0ff", "b": "4a8aff", "c": "1a1026", "d": "ff6eb4"}, rows = [
		"................", "................", "......dddd......", "...dddaaaaddd...", "..ddaaabbaaadd..", ".ddaaabbbbaaadd.",
		"ddaaabbccbbaaadd", "ddaaabbccbbaaadd", ".ddaaabbbbaaadd.", "..ddaaabbaaadd..", "...dddaaaaddd...", "......dddd......",
		"................", "................", "................", "................"]},
]

## Graffiti `index` (0..14): seven tags, eight pictures.
static func graffiti(index: int) -> ImageTexture:
	var key := "graffiti_%d" % index
	if _cache.has(key): return _cache[key]
	var image: Image
	if index<TAGS.size(): image = _tag(TAGS[index], index)
	else: image = _icon(ICONS[(index-TAGS.size()) % ICONS.size()], index)
	return _tex(key, image)

static func _tag(spec: Array, salt: int) -> Image:
	var word := str(spec[0])
	var scale := 2
	var w := (word.length()*6)*scale+6
	var h := 7*scale+10
	var image := Image.create(w, h, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var fill := Image.create(w, h, false, Image.FORMAT_RGBA8)
	fill.fill(Color(0, 0, 0, 0))
	var top := Color(str(spec[1]))
	var bottom := Color(str(spec[2]))
	var line := Color(str(spec[3]))
	# Letters, a little bounce up and down as a hand would spray them.
	for k in word.length():
		var glyph: Array = FONT.get(word[k], FONT["O"])
		var lift := 1 if k % 2==1 else 0
		for gy in 7:
			for gx in 5:
				if str(glyph[gy])[gx]!="1": continue
				for sy in scale:
					for sx in scale:
						var x := 3+k*6*scale+gx*scale+sx
						var y := 3+gy*scale+sy-lift
						fill.set_pixel(x, y, top.lerp(bottom, float(y-3)/float(7*scale)))
	# Drips under a few columns.
	for x in w:
		if _rand(x, salt, 51)>0.9:
			var y := h-1
			for yy in range(h-1, -1, -1):
				if fill.get_pixel(x, yy).a>0.5:
					y = yy
					break
			if y<h-1:
				var c := fill.get_pixel(x, y)
				for d in range(1, 2+int(_rand(x, salt, 52)*5.0)):
					if y+d<h-1: fill.set_pixel(x, y+d, c)
	# A dark outline and a shadow, then the fill with a highlight.
	for y in h:
		for x in w:
			if fill.get_pixel(x, y).a>0.5: continue
			for o: Vector2i in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, -1), Vector2i(1, 1)]:
				var q := Vector2i(x, y)+o
				if q.x>=0 and q.y>=0 and q.x<w and q.y<h and fill.get_pixel(q.x, q.y).a>0.5:
					image.set_pixel(x, y, line)
					break
	for y in h:
		for x in w:
			var c := fill.get_pixel(x, y)
			if c.a<0.5: continue
			var above := y>0 and fill.get_pixel(x, y-1).a>0.5
			image.set_pixel(x, y, c if above else c.lightened(0.45))
	return image

static func _icon(spec: Dictionary, salt: int) -> Image:
	var rows: Array = spec.rows
	var pad := 2
	var size := 16+pad*2
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var outline := Color("140c1c")
	var at := func(x: int, y: int) -> String:
		if y<0 or y>=16 or x<0 or x>=16: return "."
		return str(rows[y])[x]
	for y in size:
		for x in size:
			var ch: String = at.call(x-pad, y-pad)
			if ch!=".":
				var c := Color(str(spec.colors[ch]))
				image.set_pixel(x, y, c.darkened((_rand(x, y, salt)-0.5)*0.12))
				continue
			for o: Vector2i in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
				if at.call(x-pad+o.x, y-pad+o.y)!=".":
					image.set_pixel(x, y, outline)
					break
	# A spray halo of loose dots round it.
	for k in 14:
		var x := int(_rand(k, salt, 61)*size)
		var y := int(_rand(k, salt, 62)*size)
		if image.get_pixel(x, y).a<0.1:
			var c := Color(str(spec.colors.values()[k % spec.colors.size()]))
			c.a = 0.7
			image.set_pixel(x, y, c)
	return image

## Size in metres of graffiti `index` at the city's pixel grain.
static func graffiti_size(index: int) -> Vector2:
	var t := graffiti(index)
	return Vector2(t.get_width(), t.get_height())/PX*(1.0 if index<TAGS.size() else 1.5)
