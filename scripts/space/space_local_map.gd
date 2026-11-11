class_name SpaceLocalMap
extends Control
## The same cached pixel picture as the Tavern, projected onto a planet or
## the Nexus's flat ground. Static roofs/trees/roads are painted on a worker;
## only meaningful live markers and the player arrow are drawn every frame.
const ContactsScript = preload("res://scripts/ui/minimap_contacts.gd")
const MapArt = preload("res://scripts/space/space_map_geometry.gd")
const MAP_EDGE := 1.0-8.0/88.0
var contacts: Array[Dictionary] = []
var extra_markers: Array[Dictionary] = []
var diner := false
var world: SpaceWorld
var player: Player
var radius := 32.0
var planet := {}
var reference := Vector3.ZERO
var right := Vector3.RIGHT
var back := Vector3.BACK
var up := Vector3.UP
var _task := -1
var _result := {}
var _painted_id := ""
var _anchor := Vector3.ZERO
var _anchor_origin := Vector3.ZERO
var _paint_radius := 0.0
var _paint_revision := -1
var _last_request := 0
var _skin := ShaderMaterial.new()
var _image := TextureRect.new()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_skin.shader = preload("res://shaders/space_local_map.gdshader")
	_skin.set_shader_parameter("frame_tex",UIStyle._skin_texture("stone"))
	_skin.set_shader_parameter("outline_color",Color("080808") if UIStyle.TEXTURE_SET=="black" else UIStyle.OUTLINE)
	_skin.set_shader_parameter("brass_color",Color.WHITE if UIStyle.TEXTURE_SET=="black" else UIStyle.GOLD)
	_image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_image.show_behind_parent = true
	_image.material = _skin
	_image.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var blank := Image.create_empty(1,1,false,Image.FORMAT_RGB8)
	blank.fill(Color("182326"))
	_image.texture = ImageTexture.create_from_image(blank)
	add_child(_image)

func update_view(view_radius: float) -> bool:
	if not FrameTrace.enabled: return _update_view(view_radius)
	var started := Time.get_ticks_usec()
	var shown := _update_view(view_radius)
	FrameTrace.record("space/map_update",started)
	return shown

func _update_view(view_radius: float) -> bool:
	if not is_instance_valid(player) or not is_instance_valid(world): return false
	if _task>=0 and WorkerThreadPool.is_task_completed(_task):
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
		_image.texture = ImageTexture.create_from_image(_result.image)
		_skin.set_shader_parameter("atlas_up",_result.up)
		_skin.set_shader_parameter("atlas_right",_result.right)
		_skin.set_shader_parameter("atlas_back",_result.back)
		_skin.set_shader_parameter("atlas_origin",_result.origin)
		_skin.set_shader_parameter("atlas_span",_result.span)
		_painted_id = _result.id
		_anchor = _result.up
		_anchor_origin = _result.origin
		_paint_radius = _result.span/1.8
		_paint_revision = _result.revision
	reference = player.global_position
	var ship := world.ship_in_slot(SpaceLayout.pocket_at(reference))
	if ship!=null: reference = ship.xform.origin
	planet = SpaceLayout.planet_near(reference,120.0)
	diner = planet.is_empty() and reference.distance_to(SpaceLayout.DINER)<180.0
	var flat := planet.is_empty()
	if flat and reference.distance_to(SpaceLayout.NEXUS)>=250.0 and not diner: return false
	radius = maxf(16.0,view_radius)
	var orbit := player.global_basis*Basis(Vector3.UP,player.camera_yaw)
	up = (reference-(planet.center as Vector3)).normalized() if not flat else Vector3.UP
	back = orbit.z.slide(up).normalized()
	right = up.cross(back).normalized()
	var id := ("diner" if diner else "nexus") if flat else str(planet.id)
	_skin.set_shader_parameter("nexus_mode",flat)
	_skin.set_shader_parameter("view_radius",radius)
	_skin.set_shader_parameter("view_origin",reference)
	_skin.set_shader_parameter("view_up",up)
	_skin.set_shader_parameter("view_right",right)
	_skin.set_shader_parameter("view_back",back)
	_skin.set_shader_parameter("planet_radius",float(planet.get("radius",1000.0)))
	_skin.set_shader_parameter("map_ready",_painted_id==id)
	var moved := reference.distance_to(_anchor_origin)>radius*0.35 if flat else _anchor.angle_to(up)*float(planet.radius)>radius*0.35
	var changed := MapArt.revision!=_paint_revision and Time.get_ticks_msec()-_last_request>2000
	if _task<0 and (_painted_id!=id or moved or absf(radius-_paint_radius)>1.0 or changed):
		var snapshot := planet.duplicate(true)
		var origin := reference
		var heading := up
		var east := right
		var south := back
		var span := radius*1.8
		var batches := MapArt.snapshot(world,origin,span*1.5,heading)
		var revision := MapArt.revision
		_last_request = Time.get_ticks_msec()
		_task = WorkerThreadPool.add_task(func() -> void: _result = _paint(snapshot,heading,east,south,span,origin,batches,id,revision))
	queue_redraw()
	return true

static func _atlas_point(at: Vector3, p: Dictionary, origin: Vector3, anchor: Vector3, east: Vector3, south: Vector3, span: float, pixels: int) -> Vector2:
	var delta := at-origin
	if not p.is_empty():
		var direction := (at-(p.center as Vector3)).normalized()
		var tangent := direction-anchor*direction.dot(anchor)
		var angle := atan2(tangent.length(),clampf(anchor.dot(direction),-1.0,1.0))
		delta = tangent.normalized()*angle*float(p.radius) if tangent.length_squared()>0.000000000001 else Vector3.ZERO
	return (Vector2(delta.dot(east),delta.dot(south))/span*0.5+Vector2.ONE*0.5)*pixels

static func _fill_polygon(image: Image, polygon: PackedVector2Array, color: Color) -> void:
	if polygon.size()<3: return
	var ymin := image.get_height()
	var ymax := 0
	for point in polygon:
		if not point.is_finite(): return
		ymin = mini(ymin,floori(point.y))
		ymax = maxi(ymax,ceili(point.y))
	for y in range(maxi(0,ymin),mini(image.get_height(),ymax+1)):
		var intersections := PackedFloat32Array()
		for i in polygon.size():
			var a := polygon[i]
			var b := polygon[(i+1)%polygon.size()]
			var scan := y+0.5
			if (a.y<=scan and b.y>scan) or (b.y<=scan and a.y>scan):
				intersections.append(a.x+(scan-a.y)*(b.x-a.x)/(b.y-a.y))
		intersections.sort()
		for i in range(0,intersections.size()-1,2):
			var left := maxi(0,ceili(intersections[i]-0.5))
			var end := mini(image.get_width(),ceili(intersections[i+1]-0.5))
			if end>left: image.fill_rect(Rect2i(left,y,end-left,1),color)

static func _paint(p: Dictionary, anchor: Vector3, east: Vector3, south: Vector3, span: float, origin: Vector3, batches: Array, id: String, revision: int) -> Dictionary:
	# Approximately one texel per metre, matching the Tavern's block map.
	var pixels := clampi(ceili(span*2.0),64,384)
	var image := Image.create_empty(pixels,pixels,false,Image.FORMAT_RGB8)
	if p.is_empty(): image.fill(Color("142330"))
	else:
		var r := float(p.radius)
		for y in pixels:
			for x in pixels:
				var offset := (Vector2(x+0.5,y+0.5)/pixels*2.0-Vector2.ONE)*span
				var angle := offset.length()/r
				var tangent := (east*offset.x+south*offset.y).normalized()
				var direction := (anchor*cos(angle)+tangent*sin(angle)).normalized()
				image.set_pixel(x,y,surface_color(p,direction))
	var shapes: Array = []
	for batch: Dictionary in batches:
		for record: Dictionary in batch.records:
			var pose: Transform3D = batch.frame*record.pose
			var offset := pose.origin-origin
			var vertical := offset.dot(anchor)
			var extent := pose.basis.get_scale().length()*0.5
			if (offset-anchor*vertical).length()>span*1.5+extent or absf(vertical)>1000.0+extent: continue
			var height := (pose.origin-origin).dot(anchor)+0.5*(absf(pose.basis.x.dot(anchor))+absf(pose.basis.y.dot(anchor))+absf(pose.basis.z.dot(anchor)))
			shapes.append({pose=pose,kind=record.kind,color=record.color,height=height})
	if p.get("city",false): shapes.append_array(_road_shapes(p,anchor,span,origin))
	shapes.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return a.height<b.height)
	for shape: Dictionary in shapes:
		var points := PackedVector2Array()
		var pose: Transform3D = shape.pose
		if shape.kind in ["box"]:
			for y: float in [-0.5,0.5]:
				for corner: Vector2 in [Vector2(-0.5,-0.5),Vector2(0.5,-0.5),Vector2(0.5,0.5),Vector2(-0.5,0.5)]:
					points.append(_atlas_point(pose*Vector3(corner.x,y,corner.y),p,origin,anchor,east,south,span,pixels))
		else:
			for i in 12:
				var angle := TAU*i/12.0
				points.append(_atlas_point(pose*Vector3(cos(angle)*0.5,0,sin(angle)*0.5),p,origin,anchor,east,south,span,pixels))
		var hull := Geometry2D.convex_hull(points)
		if hull.size()>1 and hull[0].is_equal_approx(hull[-1]): hull.remove_at(hull.size()-1)
		_fill_polygon(image,hull,shape.color)
	return {image=image,up=anchor,right=east,back=south,origin=origin,span=span,id=id,revision=revision}

static func _road_shapes(p: Dictionary, anchor: Vector3, span: float, origin: Vector3) -> Array:
	var result: Array = []
	var uv := CityLayout.face_uv(anchor)
	var ci := floori((float(uv[1])+1.0)*0.5*CityLayout.N)
	var cj := floori((float(uv[2])+1.0)*0.5*CityLayout.N)
	var reach := ceili(span/45.0)+1
	for j in range(maxi(0,cj-reach),mini(CityLayout.N,cj+reach+1)):
		for i in range(maxi(0,ci-reach),mini(CityLayout.N,ci+reach+1)):
			for street: Dictionary in CityRoads.cell_streets(int(uv[0]),i,j):
				var line: Array = street.points
				for k in line.size()-1:
					var a: Vector3 = (p.center as Vector3)+(line[k] as Vector3)*float(p.radius)
					var b: Vector3 = (p.center as Vector3)+(line[k+1] as Vector3)*float(p.radius)
					var up := ((a+b)*0.5-(p.center as Vector3)).normalized()
					var along := (b-a).normalized()
					var frame := Basis(up.cross(along).normalized(),up,along)
					for width: float in [(CityLayout.ROAD+CityLayout.WALK)*2.0,CityLayout.ROAD*2.0]:
						result.append({pose=Transform3D(frame.scaled_local(Vector3(width,0.04,a.distance_to(b))),(a+b)*0.5),kind="box",color=Color("939087") if width>CityLayout.ROAD*2.0 else Color("302d36"),height=((a+b)*0.5-origin).dot(anchor)+(0.02 if width>CityLayout.ROAD*2.0 else 0.03)})
	return result

static func surface_color(p: Dictionary, direction: Vector3) -> Color:
	if p.get("city",false):
		var uv := CityLayout.face_uv(direction)
		var i := clampi(floori((float(uv[1])+1.0)*0.5*CityLayout.N),0,CityLayout.N-1)
		var j := clampi(floori((float(uv[2])+1.0)*0.5*CityLayout.N),0,CityLayout.N-1)
		match CityLayout.role(int(uv[0]),i,j):
			"park": return Color("426746")
			"lake": return Color("386978")
			"port": return Color("756c63")
			"farm":
				var field := CityCountry.field(direction*float(p.radius))
				return [Color("b8a15f"),Color("547d45"),Color("75523b"),Color("557549")][int(field[0])]
		return Color("8c8271")
	var height := SpaceLayout.surface_height(p,direction)
	var color := PlanetPalette.ground(p,direction,height,direction)
	return Color(color,1.0)

func _point(at: Vector3) -> Vector2:
	return _atlas_point(at,planet,reference,up,right,back,radius,int(size.x*MAP_EDGE))+size*0.5-Vector2.ONE*size.x*MAP_EDGE*0.5

func _mark(at: Vector3, color: Color, label := "") -> void:
	if not planet.is_empty() and at.distance_to(planet.center)>float(planet.radius)+500.0: return
	var point := _point(at)
	if point.distance_to(size*0.5)>size.x*MAP_EDGE*0.47: return
	draw_circle(point,4.0,Color("101522"))
	draw_circle(point,2.8,color)
	if label!="": draw_string(UIStyle.font(),point+Vector2(5,-3),label,HORIZONTAL_ALIGNMENT_LEFT,-1,11,color)

func _quest(at: Vector3) -> void:
	if not planet.is_empty() and at.distance_to(planet.center)>float(planet.radius)+500.0: return
	var point := _point(at)
	point = size*0.5+(point-size*0.5).limit_length(size.x*MAP_EDGE*0.43)
	draw_colored_polygon(PackedVector2Array([point+Vector2(0,-6),point+Vector2(6,0),point+Vector2(0,6),point+Vector2(-6,0)]),Color("ffdb56"))

func _draw() -> void:
	if not is_instance_valid(world) or not is_instance_valid(player): return
	if planet.is_empty():
		if not diner and is_instance_valid(world.station):
			_mark(world.station.anchors.command_table,UIStyle.GOLD)
			_mark(world.station.anchors.rocket_pad.origin,Color("82c5ca"))
	else:
		for port: Dictionary in SpaceLayout.ports(planet): _mark(port.pose.origin,UIStyle.GOLD)
		if SpaceLayout.FORTS.has(str(planet.id)): _mark((planet.center as Vector3)+SpaceLayout.fort_frame(planet).origin,UIStyle.BAD)
	for contact: Dictionary in contacts: _mark(contact.pos,contact.color)
	for ship: SpaceShip in world.ships.values(): _mark(ship.xform.origin,ContactsScript.INTERACT)
	for marker: Dictionary in world.my_marks():
		if str(marker.get("kind",""))!="zone": _quest(marker.pos)
	for marker: Dictionary in extra_markers:
		if str(marker.get("kind","")) in ["quest","side"]: _quest(marker.pos)
	var forward := -player.global_basis.z.rotated(player.up_direction,player.facing)
	var facing := Vector2(forward.dot(right),forward.dot(back)).normalized()
	if facing.length_squared()<0.01: facing = Vector2.UP
	var mid := size*0.5
	draw_colored_polygon(PackedVector2Array([mid+facing*8,mid-facing*5+facing.orthogonal()*4,mid-facing*5-facing.orthogonal()*4]),Color.WHITE)
	var north := Vector2(Vector3.FORWARD.dot(right),Vector3.FORWARD.dot(back)).normalized()*size.x*MAP_EDGE*0.44
	PixelArt.draw_tiny(self,mid+north-Vector2(3,6),"N",UIStyle.GOLD,PixelArt.SCALE)

func _exit_tree() -> void:
	if _task>=0: WorkerThreadPool.wait_for_task_completion(_task)
