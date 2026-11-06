class_name SpaceMap
extends Control
## The space map (M): the whole Reach seen from above, its regions, the
## Shardfield, planets, the Nexus, every ship and where you are.
var world: SpaceWorld
var player: Player
var span := 15000.0

func _process(_delta: float) -> void:
	if visible: queue_redraw()

func _point(at: Vector3, rect: Rect2) -> Vector2:
	# North (top) is +Z, toward the Gloam, so the danger lies ahead.
	return rect.get_center()+Vector2(at.x, -at.z)/span*rect.size.y*0.5

func _draw() -> void:
	if world==null: return
	var side := minf(size.x, size.y)*0.86
	var rect := Rect2((size-Vector2(side, side))*0.5, Vector2(side, side))
	draw_rect(rect.grow(10), Color("0b0a14"), true)
	draw_rect(rect.grow(10), UIStyle.GOLD.darkened(0.3), false, 3.0)
	var font := UIStyle.font()
	# Regions as horizontal bands.
	var gloam_y := _point(Vector3(0, 0, SpaceLayout.GLOAM_START), rect).y
	var field_y := _point(Vector3(0, 0, SpaceLayout.SHARDFIELD_START), rect).y
	draw_rect(Rect2(rect.position, Vector2(side, maxf(0.0, gloam_y-rect.position.y))), Color(0.28, 0.06, 0.12, 0.35))
	draw_rect(Rect2(Vector2(rect.position.x, gloam_y), Vector2(side, field_y-gloam_y)), Color(0.2, 0.5, 0.5, 0.18))
	draw_rect(Rect2(Vector2(rect.position.x, field_y), Vector2(side, rect.end.y-field_y)), Color(0.15, 0.35, 0.2, 0.16))
	for i in range(0, world._asteroids.size(), 3):
		var rock: Array = world._asteroids[i]
		draw_circle(_point(rock[0], rect), 1.2, Color(0.55, 0.6, 0.7, 0.5) if not bool(rock[2]) else Color(0.5, 1, 0.9, 0.7))
	for gap: Vector3 in SpaceLayout.passes():
		draw_circle(_point(gap, rect), 4.0, Color(1, 0.85, 0.4, 0.9))
	draw_string(font, Vector2(rect.position.x+12, gloam_y-10), "THE GLOAM", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 0.5, 0.55))
	draw_string(font, Vector2(rect.position.x+12, field_y-10), "THE SHARDFIELD", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.6, 1, 0.9))
	draw_string(font, Vector2(rect.position.x+12, rect.end.y-14), "THE HAVEN", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.7, 1, 0.6))
	for p: Dictionary in SpaceLayout.PLANETS:
		var at := _point(p.center, rect)
		var r := maxf(5.0, float(p.radius)/span*side*0.5*3.0)
		draw_circle(at, r, Color(str(p.palette[0])))
		draw_arc(at, r+2.0, 0, TAU, 32, Color(str(p.palette[1])), 1.5)
		draw_string(font, at+Vector2(r+5, 5), str(p.name), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, UIStyle.TEXT)
	var nexus := _point(SpaceLayout.NEXUS, rect)
	draw_circle(nexus, 6.0, UIStyle.GOLD)
	draw_string(font, nexus+Vector2(9, -6), "Nexus", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, UIStyle.GOLD)
	for mark: Dictionary in world.my_marks():
		var at := _point(mark.pos, rect)
		draw_arc(at, 9.0, 0, TAU, 24, Color(1, 0.85, 0.35), 2.5)
		draw_circle(at, 3.0, Color(1, 0.85, 0.35))
	var mine := world.ship_of(player.player_id) if is_instance_valid(player) else null
	for ship: SpaceShip in world.ships.values():
		var at := _point(ship.xform.origin, rect)
		var fwd := -ship.xform.basis.z
		var d := Vector2(fwd.x, -fwd.z).normalized()
		var tip := at+d*9.0
		draw_colored_polygon(PackedVector2Array([tip, at-d*5.0+d.orthogonal()*5.0, at-d*5.0-d.orthogonal()*5.0]), ship.tint if ship!=mine else Color.WHITE)
	if is_instance_valid(player) and mine==null and SpaceLayout.pocket_at(player.global_position)<0:
		draw_circle(_point(player.global_position, rect), 4.0, Color.WHITE)
	draw_string(font, Vector2(rect.position.x, rect.end.y+30), "M: close", HORIZONTAL_ALIGNMENT_CENTER, side, 15, UIStyle.TEXT)
