class_name SpaceMap
extends Control
## The star chart (M): the Reach seen from above at a tilt, centred on you.
## Planets are shaded globes with their air, standing on stems above the
## plane of the Reach so their height reads; range rings, the Shardfield's
## band, the Gloam, the passes, ships, nearby brood, campaign targets and
## the red edge of the Reach. Drag to turn the chart, wheel to zoom.
var world: SpaceWorld
var player: Player
var yaw := 0.0
var tilt := 0.95
var zoom := 0.032  # pixels per metre
var _dragging := false

const ZOOM_MIN := 0.0045
const ZOOM_MAX := 0.25
const EDGE := Color(1.0, 0.18, 0.22)
const INK := Color(0.82, 0.9, 1.0)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP

func _process(_delta: float) -> void:
	if visible: queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index==MOUSE_BUTTON_WHEEL_UP and button.pressed: zoom = clampf(zoom*1.2, ZOOM_MIN, ZOOM_MAX)
		elif button.button_index==MOUSE_BUTTON_WHEEL_DOWN and button.pressed: zoom = clampf(zoom/1.2, ZOOM_MIN, ZOOM_MAX)
		elif button.button_index==MOUSE_BUTTON_LEFT: _dragging = button.pressed
		accept_event()
	elif event is InputEventMouseMotion and _dragging:
		var motion := (event as InputEventMouseMotion).relative
		yaw -= motion.x*0.006
		tilt = clampf(tilt+motion.y*0.004, 0.25, 1.45)
		accept_event()

func _center() -> Vector3:
	var mine := world.ship_of(player.player_id) if is_instance_valid(player) else null
	if mine: return mine.xform.origin
	if is_instance_valid(player) and SpaceLayout.pocket_at(player.global_position)<0: return player.global_position
	return SpaceLayout.NEXUS

## World point to screen: turned by yaw, tipped by tilt (north, +Z, is up).
func _point(at: Vector3, center: Vector3) -> Vector2:
	var rel := (at-center).rotated(Vector3.UP, yaw)
	return size*0.5+Vector2(rel.x, -rel.z*cos(tilt)-rel.y*sin(tilt))*zoom

func _draw() -> void:
	if world==null: return
	var center := _center()
	var font := UIStyle.font()
	var bold := UIStyle.bold()
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.01, 0.012, 0.03, 0.97))
	# Soft nebula patches for depth.
	for i in 7:
		var at := _point(Vector3(sin(i*1.9)*16000.0, 0, cos(i*2.7)*16000.0), center)
		var tint := Color(0.25, 0.55, 0.45, 0.035) if i % 2 else Color(0.55, 0.2, 0.45, 0.035)
		for k in 5: draw_circle(at, (3800.0+k*900.0)*zoom, tint)
	# The plane of the Reach: range rings around the Nexus every 5 km.
	for ring in range(1, 9):
		_ellipse(SpaceLayout.NEXUS, ring*5000.0, center, Color(0.4, 0.55, 0.8, 0.13 if ring % 2 else 0.22), 1.0)
		var label := _point(Vector3(0, 0, -ring*5000.0), center)
		draw_string(font, label+Vector2(4, -2), "%d km" % (ring*5), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.5, 0.65, 0.9, 0.5))
	for spoke in 12:
		var dir := Vector3(sin(spoke*TAU/12.0), 0, cos(spoke*TAU/12.0))
		draw_line(_point(dir*3000.0, center), _point(dir*SpaceLayout.WORLD_RADIUS, center), Color(0.4, 0.55, 0.8, 0.07), 1.0)
	# The Gloam beyond its border, and the Shardfield's band.
	var gloam := PackedVector2Array()
	for k in 49:
		var a := lerpf(-acos(SpaceLayout.GLOAM_START/SpaceLayout.WORLD_RADIUS), acos(SpaceLayout.GLOAM_START/SpaceLayout.WORLD_RADIUS), k/48.0)
		gloam.append(_point(Vector3(sin(a), 0, cos(a))*SpaceLayout.WORLD_RADIUS, center))
	draw_colored_polygon(gloam, Color(0.45, 0.05, 0.12, 0.18))
	var e: Vector3 = SpaceLayout.SHARDFIELD.extents
	var c: Vector3 = SpaceLayout.SHARDFIELD.center
	var band := PackedVector2Array([_point(c+Vector3(-e.x, 0, -e.z), center), _point(c+Vector3(e.x, 0, -e.z), center), _point(c+Vector3(e.x, 0, e.z), center), _point(c+Vector3(-e.x, 0, e.z), center)])
	draw_colored_polygon(band, Color(0.3, 0.85, 0.75, 0.1))
	for i in range(0, world._asteroids.size(), 5):
		var rock: Array = world._asteroids[i]
		draw_circle(_point(rock[0], center), maxf(1.0, float(rock[1])*zoom), Color(0.6, 0.6, 0.72, 0.45) if not bool(rock[2]) else Color(0.5, 1, 0.9, 0.7))
	for gap: Vector3 in SpaceLayout.passes():
		var at := _point(gap, center)
		draw_arc(at, maxf(5.0, SpaceLayout.PASS_RADIUS*zoom), 0, TAU, 28, Color(1, 0.85, 0.4, 0.9), 2.0)
		draw_string(font, at+Vector2(8, -8), "Pass", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 0.85, 0.4))
	# The edge of the Reach: the sphere's outline and its belt in red.
	draw_arc(_point(Vector3.ZERO, center), SpaceLayout.WORLD_RADIUS*zoom, 0, TAU, 128, EDGE, 3.0)
	_ellipse(Vector3.ZERO, SpaceLayout.WORLD_RADIUS, center, Color(EDGE, 0.5), 2.0)
	var north := _point(Vector3(0, 0, SpaceLayout.WORLD_RADIUS), center)
	draw_string(bold, north+Vector2(-80, -10), "THE EDGE OF THE REACH", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, EDGE)
	# Region names.
	draw_string(bold, _point(Vector3(-9000, 0, 30000), center), "THE GLOAM", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1, 0.45, 0.55, 0.9))
	draw_string(bold, _point(Vector3(-15000, 0, 18600), center), "THE SHARDFIELD", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.55, 1, 0.9, 0.9))
	draw_string(bold, _point(Vector3(-9000, 0, -9000), center), "THE HAVEN", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.7, 1, 0.65, 0.9))
	# The sun.
	var sun := _point(SpaceLayout.SUN_CENTER, center)
	var sun_r := maxf(10.0, SpaceLayout.SUN_RADIUS*zoom)
	for k in 6: draw_circle(sun, sun_r*(1.9-k*0.15), Color(1.0, 0.5, 0.15, 0.05))
	draw_circle(sun, sun_r, Color(1.0, 0.6, 0.2))
	draw_circle(sun, sun_r*0.7, Color(1.0, 0.85, 0.5))
	draw_string(bold, sun+Vector2(sun_r+8, 5), "The Sun  %s  -  burns" % _distance(SpaceLayout.SUN_CENTER, center), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(1, 0.7, 0.4))
	# Planets, far ones first so near ones overlap them.
	var order: Array = SpaceLayout.PLANETS.duplicate()
	order.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return _depth(a.center, center)<_depth(b.center, center))
	for p: Dictionary in order: _planet(p, center, font, bold)
	if center.distance_to(CityLayout.planet().center)<4000.0 and zoom>0.065:
		for district: Dictionary in CityLayout.DISTRICTS:
			var pos: Vector3 = (CityLayout.planet().center as Vector3)+CityLayout.district_frame(district).origin
			var at := _point(pos, center)
			draw_circle(at, 4.5, UIStyle.GOLD)
			draw_string(font, at+Vector2(8, -5), str(district.port), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UIStyle.GOLD)
	# The Nexus on its rock.
	var nexus := _point(SpaceLayout.NEXUS, center)
	draw_colored_polygon(PackedVector2Array([nexus+Vector2(0, -9), nexus+Vector2(8, 0), nexus+Vector2(0, 9), nexus+Vector2(-8, 0)]), UIStyle.GOLD)
	draw_string(bold, nexus+Vector2(12, 5), "The Nexus  %s" % _distance(SpaceLayout.NEXUS, center), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, UIStyle.GOLD)
	# Campaign targets.
	for mark: Dictionary in world.my_marks():
		var at := _point(mark.pos, center)
		var pulse := 1.0+sin(Time.get_ticks_msec()/250.0)*0.15
		draw_arc(at, 12.0*pulse, 0, TAU, 28, Color(1, 0.85, 0.35), 2.5)
		draw_arc(at, 20.0*pulse, 0, TAU, 28, Color(1, 0.85, 0.35, 0.4), 1.5)
	# Brood within sensor range.
	for view: Dictionary in world.foes._views.values():
		var node: Node3D = view.node
		if is_instance_valid(node) and node.global_position.distance_to(center)<6000.0:
			var at := _point(node.global_position, center)
			draw_colored_polygon(PackedVector2Array([at+Vector2(0, -5), at+Vector2(5, 4), at+Vector2(-5, 4)]), Color(1, 0.3, 0.4))
	# Ships, with heading.
	var mine := world.ship_of(player.player_id) if is_instance_valid(player) else null
	for ship: SpaceShip in world.ships.values():
		var at := _point(ship.xform.origin, center)
		var ahead := _point(ship.xform.origin-ship.xform.basis.z*800.0, center)
		var d := (ahead-at).normalized() if ahead.distance_to(at)>0.5 else Vector2.UP
		var tip := at+d*11.0
		draw_colored_polygon(PackedVector2Array([tip, at-d*6.0+d.orthogonal()*6.0, at-d*6.0-d.orthogonal()*6.0]), Color.WHITE if ship==mine else ship.tint)
		if ship==mine: draw_line(at, ahead, Color(1, 1, 1, 0.35), 1.0)
		draw_string(font, at+Vector2(10, 14), ship.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE if ship==mine else ship.tint)
	if mine==null and is_instance_valid(player) and SpaceLayout.pocket_at(player.global_position)<0:
		draw_circle(_point(player.global_position, center), 5.0, Color.WHITE)
	# Title, legend and controls.
	draw_string(bold, Vector2(28, 44), "STAR CHART OF THE ASTRAL REACH", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, UIStyle.GOLD)
	draw_string(font, Vector2(28, 70), "Your ship  %s" % SpaceLayout.region_name(SpaceLayout.region_at(center)), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, INK)
	draw_string(font, Vector2(0, size.y-24), "M: close  -  drag: turn the chart  -  wheel: zoom", HORIZONTAL_ALIGNMENT_CENTER, size.x, 15, UIStyle.TEXT)

func _depth(at: Vector3, center: Vector3) -> float:
	var rel := (at-center).rotated(Vector3.UP, yaw)
	return -rel.z*sin(tilt)+rel.y*cos(tilt)

func _ellipse(at: Vector3, radius: float, center: Vector3, color: Color, width: float) -> void:
	var points := PackedVector2Array()
	for k in 97:
		var a := TAU*k/96.0
		points.append(_point(at+Vector3(sin(a), 0, cos(a))*radius, center))
	draw_polyline(points, color, width, true)

func _distance(at: Vector3, from: Vector3) -> String:
	var d := at.distance_to(from)
	return "%d m" % d if d<1000.0 else "%.1f km" % (d/1000.0)

## A shaded globe with its air on a stem down to the plane of the Reach.
func _planet(p: Dictionary, center: Vector3, font: Font, bold: Font) -> void:
	var at := _point(p.center, center)
	var foot := _point(Vector3((p.center as Vector3).x, 0, (p.center as Vector3).z), center)
	draw_line(foot, at, Color(0.7, 0.8, 1.0, 0.35), 1.0)
	draw_arc(foot, 4.0, 0, TAU, 16, Color(0.7, 0.8, 1.0, 0.45), 1.0)
	var r := maxf(6.0, float(p.radius)*zoom)
	var pal: Array = p.palette
	var sky := Color(str(pal[5]))
	for k in 6: draw_arc(at, r+2.0+k*1.6, 0, TAU, 40, Color(sky, 0.16-k*0.025), 2.0)
	draw_circle(at, r, Color(str(pal[2])))
	var light := Vector2(-0.35, -0.35)*r
	draw_circle(at+light*0.25, r*0.85, Color(str(pal[0])))
	draw_circle(at+light*0.5, r*0.55, Color(str(pal[1])))
	draw_circle(at+light*0.75, r*0.18, Color(1, 1, 1, 0.5))
	var danger: String = ["", "  -  wary", "  -  dangerous", "  -  deadly"][int(p.danger)]
	draw_string(bold, at+Vector2(r+8, -2), str(p.name), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)
	draw_string(font, at+Vector2(r+8, 15), "%s%s" % [_distance(p.center, center), danger], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 0.55, 0.55) if int(p.danger)>=2 else INK)
