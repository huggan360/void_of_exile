class_name SpaceMap
extends Control
## The star chart (M): the Reach seen from above at a tilt, centred on you.
## A quiet night sky over the Surface (the floor of Space, painted below the
## Reach by space_map_surface.gdshader); planets are terrain miniatures
## standing on faint height guides, then ships, nearby brood, campaign
## targets and the edge of the Reach. Drag to turn the chart, wheel to zoom.
const MiniatureScript = preload("res://scripts/space/space_map_miniature.gd")

var world: SpaceWorld
var player: Player
var yaw := 0.0
var tilt := 0.95
var zoom := 0.032  # pixels per metre
var _dragging := false
var _miniatures := {}
var _stars: Array = []  # [unit position, size, brightness]: a fixed backdrop
var _sky := Control.new()  # night sky and stars, behind everything
var _surface := ColorRect.new()  # the Surface, between the sky and the chart
var _surface_material := ShaderMaterial.new()

const ZOOM_MIN := 0.0045
const ZOOM_MAX := 0.7
const EDGE := Color(1.0, 0.18, 0.22)
const INK := Color(0.82, 0.9, 1.0)

func _ready() -> void:
	clip_contents = true
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_STOP
	var rng := RandomNumberGenerator.new()
	rng.seed = 4417
	for i in 420:
		_stars.append([Vector2(rng.randf(), rng.randf()), rng.randf_range(0.5, 1.6), rng.randf_range(0.15, 0.7)])
	for layer: Control in [_sky, _surface]:
		layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.show_behind_parent = true
		add_child(layer)
	_sky.draw.connect(_draw_sky)
	resized.connect(_sky.queue_redraw)
	_surface_material.shader = preload("res://shaders/space_map_surface.gdshader")
	_surface_material.set_shader_parameter("surface_y", SpaceLayout.SURFACE_Y)
	_surface_material.set_shader_parameter("radius", SpaceLayout.WORLD_RADIUS*1.1)
	_surface.material = _surface_material

func _process(_delta: float) -> void:
	if not visible: return
	# Build one preview per frame, starting nearby, rather than stalling map opening.
	var order: Array = SpaceLayout.PLANETS.duplicate()
	var center := _center()
	order.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return (a.center as Vector3).distance_squared_to(center)<(b.center as Vector3).distance_squared_to(center))
	for p: Dictionary in order:
		if _miniatures.has(str(p.id)):
			if (_miniatures[str(p.id)] as MiniatureScript).refresh_art(world): break
			continue
		var preview := MiniatureScript.new()
		preview.build(self,p,world)
		_miniatures[str(p.id)] = preview
		break
	queue_redraw()

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
		tilt = clampf(tilt+motion.y*0.004, 0.12, 3.0)
		accept_event()

func _center() -> Vector3:
	var mine := world.ship_of(player.player_id) if is_instance_valid(player) else null
	if mine: return mine.xform.origin
	if is_instance_valid(player) and SpaceLayout.pocket_at(player.global_position)<0: return player.global_position
	return SpaceLayout.NEXUS

## Orthographic projection shared by the terrain previews and port markers.
func _point(at: Vector3, center: Vector3) -> Vector2:
	var rel := (at-center).rotated(Vector3.UP, yaw)
	return size*0.5+Vector2(rel.x, rel.z*cos(tilt)-rel.y*sin(tilt))*zoom

func _draw() -> void:
	if world==null: return
	var center := _center()
	var font := UIStyle.font()
	var bold := UIStyle.bold()
	_surface_material.set_shader_parameter("view_size", size)
	_surface_material.set_shader_parameter("center", center)
	_surface_material.set_shader_parameter("yaw", yaw)
	_surface_material.set_shader_parameter("tilt", tilt)
	_surface_material.set_shader_parameter("zoom", zoom)
	# The edge of the Reach: one quiet line round the plane, red only up close.
	var near_edge := clampf((center.length()-(SpaceLayout.WORLD_RADIUS-SpaceLayout.BOUNDARY_WARN*3.0))/(SpaceLayout.BOUNDARY_WARN*3.0), 0.0, 1.0)
	_ellipse(Vector3.ZERO, SpaceLayout.WORLD_RADIUS, center, Color(0.55, 0.6, 0.8, 0.25).lerp(Color(EDGE, 0.8), near_edge), 1.5)
	# Planets, far ones first so near ones overlap them.
	var order: Array = SpaceLayout.PLANETS.duplicate()
	order.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return _depth(a.center, center)<_depth(b.center, center))
	for p: Dictionary in order: _planet(p, center, font, bold)
	# The Nexus on its rock.
	var nexus := _point(SpaceLayout.NEXUS, center)
	draw_colored_polygon(PackedVector2Array([nexus+Vector2(0, -9), nexus+Vector2(8, 0), nexus+Vector2(0, 9), nexus+Vector2(-8, 0)]), UIStyle.GOLD)
	draw_string(bold, nexus+Vector2(12, 5), "The Nexus", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, UIStyle.GOLD)
	# The way down to the Surface (painted below), kept on screen at every zoom.
	var surface := Vector3(SpaceLayout.ASCENT.x,SpaceLayout.SURFACE_FLOOR,SpaceLayout.ASCENT.z)
	var surface_at := _point(surface,center).clamp(Vector2(50,105),size-Vector2(210,85))
	draw_line(_point(SpaceLayout.ASCENT,center),surface_at,Color(0.64,0.84,0.81,0.5),1.0)
	draw_circle(surface_at,4.0,Color("a4d6ce"))
	draw_string(font,surface_at+Vector2(10,4),"Descend to the Surface",HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("a4d6ce"))
	# Campaign targets. A search-zone is an uncertain, yellow *sphere*,
	# drawn with an equal projected radius on the chart. Unlike a normal
	# quest pin, it never identifies the diner or draws a world-space badge.
	for mark: Dictionary in world.my_marks():
		var at := _point(mark.pos, center)
		if str(mark.kind)=="zone":
			var radius := maxf(6.0, float(mark.get("radius", 0.0))*zoom)
			draw_circle(at, radius, Color(1.0, 0.78, 0.18, 0.11))
			draw_arc(at, radius, 0, TAU, 120, Color(1.0, 0.84, 0.20, 0.92), 3.0)
			draw_arc(at, radius*0.7, 0, TAU, 96, Color(1.0, 0.85, 0.3, 0.25), 1.0)
			draw_string(bold, at+Vector2(-radius*0.65, 0), "YELLOW SEARCH ZONE", HORIZONTAL_ALIGNMENT_LEFT,
				-1, 14, Color(1.0, 0.87, 0.30, 0.92))
			continue
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
	return rel.z*sin(tilt)+rel.y*cos(tilt)

func _ellipse(at: Vector3, radius: float, center: Vector3, color: Color, width: float) -> void:
	var points := PackedVector2Array()
	for k in 97:
		var a := TAU*k/96.0
		points.append(_point(at+Vector3(sin(a), 0, cos(a))*radius, center))
	draw_polyline(points, color, width, true)

## The night sky behind the chart (drawn by the _sky layer).
func _draw_sky() -> void:
	_sky.draw_rect(Rect2(Vector2.ZERO, size), Color(0.008, 0.01, 0.025, 0.98))
	for star: Array in _stars:
		_sky.draw_circle((star[0] as Vector2)*size, star[1], Color(0.8, 0.86, 1.0, star[2]))

## An actual terrain miniature with a height guide down to the chart plane.
func _planet(p: Dictionary, center: Vector3, font: Font, bold: Font) -> void:
	var at := _point(p.center, center)
	var foot := _point(Vector3((p.center as Vector3).x, 0, (p.center as Vector3).z), center)
	draw_line(foot, at, Color(0.7, 0.8, 1.0, 0.18), 1.0)
	draw_circle(foot, 2.0, Color(0.7, 0.8, 1.0, 0.3))
	var r := maxf(6.0, float(p.radius)*zoom)
	var text_radius := r
	if _miniatures.has(str(p.id)):
		var miniature: MiniatureScript = _miniatures[str(p.id)]
		miniature.update_view(yaw,tilt)
		var half := maxf(6.0,float(p.radius)*zoom)*miniature.extent/float(p.radius)
		text_radius = half
		draw_texture_rect(miniature.texture(),Rect2(at-Vector2.ONE*half,Vector2.ONE*half*2.0),false)
	else: draw_circle(at,r,Color(str(p.palette[0])))
	if r>=40.0: _ports(p,center,font)
	var danger: String = ["", "  -  wary", "  -  dangerous", "  -  deadly"][int(p.danger)]
	draw_string(bold, at+Vector2(text_radius+8, -2), str(p.name), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)
	if danger!="": draw_string(font, at+Vector2(text_radius+8, 15), danger.trim_prefix("  -  "), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 0.55, 0.55) if int(p.danger)>=2 else INK)

## Ports use their real world positions, including the three numbered city pads.
## Farside ports stay dim and labelled so turning the chart can reveal them.
func _ports(p: Dictionary, center: Vector3, font: Font) -> void:
	var back := Vector3(0,cos(tilt),sin(tilt)).rotated(Vector3.UP,-yaw)
	var used: Array[Rect2] = []
	for port: Dictionary in SpaceLayout.ports(p):
		var pos: Vector3 = port.pose.origin
		var point := _point(pos,center)
		var hidden := (pos-(p.center as Vector3)).dot(back)<0.0
		var color := Color("a19b85") if hidden else UIStyle.GOLD
		draw_rect(Rect2(point-Vector2.ONE*3,Vector2.ONE*6),Color("151b23"))
		draw_rect(Rect2(point-Vector2.ONE*2,Vector2.ONE*4),color)
		var text := str(port.name)+(" (far side)" if hidden else "")
		var label := point+Vector2(8,-5)
		var box := Rect2(label-Vector2(0,13),Vector2(font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,12).x,16))
		for step in 12:
			if not used.any(func(rect: Rect2) -> bool: return rect.intersects(box)): break
			box.position.y += 17
			label.y += 17
		used.append(box)
		draw_line(point,label-Vector2(3,4),Color(color,0.55),1.0)
		draw_string(font,label,text,HORIZONTAL_ALIGNMENT_LEFT,-1,12,color)
