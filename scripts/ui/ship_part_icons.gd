class_name ShipPartIcons
extends Control
## Aboard a ship: four pixel tiles over the hull bar, one per breakable part
## (sails, engines, top cannon, heart crystal), each in its own colour. A
## part below half gets an amber frame; a destroyed one turns grey with a
## red slash across it.

const PX := PixelArt.SCALE
const TILE := 11  # art pixels, frame included
const GAP := 3
const ORDER := ["sails", "engines", "turret", "heart"]
const COLORS := {
	sails = [Color("7cc8ff"), Color("e2f4ff")],
	engines = [Color("ff9a3c"), Color("ffe0a0")],
	turret = [Color("ff5a5a"), Color("ffc4c4")],
	heart = [Color("5dff9a"), Color("d8ffe6")],
}
const GLYPHS := {
	sails = ["..o....", "..oWo..", "..oCCo.", "..oCCCo", "..ooooo", "ooCCCCo", ".ooooo."],
	engines = [".ooooo.", "oCCCCCo", "oCWWWCo", "oCCCCCo", ".oCoCo.", ".oWoWo.", "..o.o.."],
	turret = [".....oo", "....oWo", "..ooCo.", ".oCCo..", "oCCCCo.", "oCWCCo.", "ooooooo"],
	heart = ["...o...", "..oWo..", ".oCWCo.", ".oCCCo.", ".oCCCo.", "..oCo..", "...o..."],
}
const GREY := Color(0.42, 0.44, 0.48)
const GREY_LIGHT := Color(0.6, 0.62, 0.66)
const FACE := Color("1b2433")
const WORN := Color("f0a43a")
const SLASH := Color("ff4a3a")

var _parts := {}


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(ORDER.size()*TILE+(ORDER.size()-1)*GAP, TILE)*PX


## parts: {id: 0..100} (SpaceShip.parts).
func set_parts(parts: Dictionary) -> void:
	var changed := false
	for id: String in ORDER:
		var value := float(parts.get(id, 100.0))
		if not _parts.has(id) or absf(float(_parts[id])-value)>0.01:
			_parts[id] = value
			changed = true
	if changed: queue_redraw()


func _draw() -> void:
	for i in ORDER.size():
		var id: String = ORDER[i]
		var value := float(_parts.get(id, 100.0))
		var destroyed := value<=0.5
		var origin := Vector2(i*(TILE+GAP), 0)*PX
		var size := Vector2.ONE*TILE*PX
		draw_rect(Rect2(origin, size), UIStyle.OUTLINE)
		draw_rect(Rect2(origin+Vector2.ONE*PX, size-Vector2.ONE*2*PX), WORN if value<50.0 and not destroyed else FACE)
		draw_rect(Rect2(origin+Vector2.ONE*2*PX, size-Vector2.ONE*4*PX), FACE)
		var tint: Array = [GREY, GREY_LIGHT] if destroyed else COLORS[id]
		PixelArt.draw_rows(self, origin+Vector2.ONE*2*PX, PackedStringArray(GLYPHS[id]),
				{"o": UIStyle.OUTLINE, "C": tint[0], "W": tint[1]})
		if destroyed:
			var from := origin+Vector2(2, TILE-2)*PX
			var to := origin+Vector2(TILE-2, 2)*PX
			draw_line(from, to, UIStyle.OUTLINE, PX*2.2)
			draw_line(from, to, SLASH, PX*1.2)
