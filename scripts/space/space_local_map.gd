class_name SpaceLocalMap
extends Control
## A camera-aligned geodesic patch: no longitude seam or polar boundary.
var contacts: Array[Dictionary] = []
var extra_markers: Array[Dictionary] = []
var diner := false
var world: SpaceWorld
var player: Player
var radius := 120.0
var planet := {}
var reference := Vector3.ZERO
var right := Vector3.RIGHT
var back := Vector3.BACK
var up := Vector3.UP
var _detail_shapes: Array[WeakRef] = []
var _detail_root: Node3D
var _detail_refresh := 0
var _task := -1
var _result := {}
var _painted_planet := ""
var _anchor := Vector3.ZERO
var _paint_radius := 0.0
var _skin := ShaderMaterial.new()
var _image := TextureRect.new()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_skin.shader = preload("res://shaders/space_local_map.gdshader")
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
	if not is_instance_valid(player) or not is_instance_valid(world): return false
	if _task>=0 and WorkerThreadPool.is_task_completed(_task):
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
		_image.texture = ImageTexture.create_from_image(_result.image)
		_skin.set_shader_parameter("atlas_up",_result.up)
		_skin.set_shader_parameter("atlas_right",_result.right)
		_skin.set_shader_parameter("atlas_back",_result.back)
		_skin.set_shader_parameter("atlas_span",_result.span)
		_painted_planet = _result.id
		_anchor = _result.up
		_paint_radius = _result.span/1.8
	reference = player.global_position
	var ship := world.ship_in_slot(SpaceLayout.pocket_at(reference))
	if ship!=null: reference = ship.xform.origin
	planet = SpaceLayout.planet_near(reference,120.0)
	diner = planet.is_empty() and reference.distance_to(SpaceLayout.DINER)<180.0
	var nexus: bool = planet.is_empty() and (reference.distance_to(SpaceLayout.NEXUS)<250.0 or diner)
	if planet.is_empty() and not nexus: return false
	radius = maxf(48.0,view_radius*3.0) if not nexus else maxf(48.0,view_radius*2.0)
	var orbit := player.global_basis*Basis(Vector3.UP,player.camera_yaw)
	right = orbit.x.normalized()
	back = orbit.z.normalized()
	up = (reference-(planet.center as Vector3)).normalized() if not nexus else Vector3.UP
	back = orbit.z.slide(up).normalized()
	if back.length_squared()<0.01: back = player.camera.global_basis.y.slide(up).normalized()
	right = up.cross(back).normalized()
	_image.visible = true
	_skin.set_shader_parameter("nexus_mode",nexus)
	_skin.set_shader_parameter("nexus_right",Vector2(right.x,right.z))
	_skin.set_shader_parameter("nexus_back",Vector2(back.x,back.z))
	_skin.set_shader_parameter("view_radius",radius)
	_skin.set_shader_parameter("nexus_offset",Vector2(((SpaceLayout.DINER if diner else SpaceLayout.NEXUS)-reference).dot(right),((SpaceLayout.DINER if diner else SpaceLayout.NEXUS)-reference).dot(back)))
	_skin.set_shader_parameter("map_ready",not nexus and _painted_planet==str(planet.get("id","")))
	if not nexus:
		var r := float(planet.radius)
		_skin.set_shader_parameter("planet_radius",r)
		_skin.set_shader_parameter("view_radius",radius)
		_skin.set_shader_parameter("view_up",up)
		_skin.set_shader_parameter("view_right",right)
		_skin.set_shader_parameter("view_back",back)
		if _task<0 and (_painted_planet!=str(planet.id) or _anchor.angle_to(up)*r>radius*0.35 or absf(radius-_paint_radius)>1.0):
			var snapshot := planet.duplicate(true)
			var heading := up
			var east := right
			var south := back
			var span := radius*1.8
			_task = WorkerThreadPool.add_task(func() -> void: _result = _paint(snapshot,heading,east,south,span))
	var detail_root: Node3D = world.planets.get(str(planet.get("id", ""))) if not planet.is_empty() else world.get_node_or_null("LastLightDiner") if diner else world.station
	if detail_root!=_detail_root or Time.get_ticks_msec()>_detail_refresh:
		_detail_root = detail_root
		_detail_refresh = Time.get_ticks_msec()+5000
		_detail_shapes.clear()
		if is_instance_valid(detail_root):
			for shape: Node in detail_root.find_children("*", "CollisionShape3D", true, false):
				_detail_shapes.append(weakref(shape))
		if not planet.is_empty() and is_instance_valid(world.gates):
			for entry: Dictionary in world.gates.entries.values():
				if str(entry.fort.get("planet", ""))!=str(planet.id): continue
				for shape: Node in (entry.root as Node3D).find_children("*", "CollisionShape3D", true, false):
					_detail_shapes.append(weakref(shape))
	queue_redraw()
	return true

static func _paint(p: Dictionary, anchor: Vector3, east: Vector3, south: Vector3, span: float) -> Dictionary:
	var image := Image.create_empty(256,256,false,Image.FORMAT_RGB8)
	var r := float(p.radius)
	for y in 256:
		for x in 256:
			var offset := (Vector2(x+0.5,y+0.5)/256.0*2.0-Vector2.ONE)*span
			var angle := offset.length()/r
			var tangent := (east*offset.x+south*offset.y).normalized()
			var direction := (anchor*cos(angle)+tangent*sin(angle)).normalized()
			image.set_pixel(x,y,surface_color(p,direction))
	return {image=image,up=anchor,right=east,back=south,span=span,id=str(p.id)}

static func surface_color(p: Dictionary, direction: Vector3) -> Color:
	if p.get("city",false):
		var uv := CityLayout.face_uv(direction)
		var i := clampi(floori((float(uv[1])+1.0)*0.5*CityLayout.N),0,CityLayout.N-1)
		var j := clampi(floori((float(uv[2])+1.0)*0.5*CityLayout.N),0,CityLayout.N-1)
		match CityLayout.role(int(uv[0]),i,j):
			"park": return Color("426746")
			"lake": return Color("386978")
			"port": return Color("a39070")
			"farm":
				var field := CityCountry.field(direction*float(p.radius))
				return [Color("b8a15f"),Color("547d45"),Color("75523b"),Color("557549")][int(field[0])]
		return Color("746e66")
	var height := SpaceLayout.surface_height(p,direction)
	var color := PlanetPalette.ground(p,direction,height,direction)
	color.a = 1.0
	return color

## Logarithmic spherical projection takes the shortest arc to a marker.
func _point(at: Vector3) -> Vector2:
	var offset := at-reference
	if not planet.is_empty():
		var direction := (at-(planet.center as Vector3)).normalized()
		var angle := acos(clampf(up.dot(direction),-1.0,1.0))
		var tangent := direction-up*direction.dot(up)
		offset = (tangent.normalized() if tangent.length_squared()>0.000001 else right)*angle*float(planet.radius)
	return size*0.5+Vector2(offset.dot(right),offset.dot(back))*size.x*0.43/radius

func _mark(at: Vector3, color: Color, label := "") -> void:
	if not planet.is_empty() and at.distance_to(planet.center)>float(planet.radius)+500.0: return
	var point := _point(at)
	if point.distance_to(size*0.5)>size.x*0.42: return
	draw_circle(point,4.0,Color("15191d"))
	draw_circle(point,2.8,color)
	if label!="": draw_string(UIStyle.font(),point+Vector2(5,-3),label,HORIZONTAL_ALIGNMENT_LEFT,-1,11,color)

func _quest(at: Vector3) -> void:
	if not planet.is_empty() and at.distance_to(planet.center)>float(planet.radius)+500.0: return
	var point: Vector2 = _point(at)
	var offset: Vector2 = point-size*0.5
	point = size*0.5+offset.limit_length(size.x*0.39)
	var diamond := PackedVector2Array([point+Vector2(0,-6),point+Vector2(6,0),point+Vector2(0,6),point+Vector2(-6,0)])
	draw_colored_polygon(diamond,Color("ffdb56"))
	draw_circle(point,2.0,Color.WHITE)

func _draw() -> void:
	if not is_instance_valid(world) or not is_instance_valid(player): return
	var mid := size*0.5
	var edge := size.x*0.46
	draw_arc(mid,edge,0,TAU,96,UIStyle.OUTLINE,8.0)
	draw_arc(mid,edge,0,TAU,96,UIStyle.GOLD,2.0)
	_draw_structures()
	if planet.is_empty():
		for k in range(6,8) if diner else range(SpaceLayout.BERTHS):
			_mark(SpaceLayout.berth_frame(k).origin,UIStyle.GOLD,str(k+1))
		if not diner and is_instance_valid(world.station):
			_mark(world.station.anchors.command_table,UIStyle.GOLD,"Shipwright")
			_mark(world.station.anchors.rocket_pad.origin,Color("82c5ca"),"Surface")
			_mark(Vector3(0,0,-30),Color("c9ad80"),"Inn")
	else:
		for port: Dictionary in SpaceLayout.ports(planet):
			var label := str(int(str(port.key).get_slice(":",2))+1) if planet.get("city",false) else "Yard" if str(port.key).ends_with(":dock") else "Pad"
			_mark(port.pose.origin,UIStyle.GOLD,label)
		if SpaceLayout.FORTS.has(str(planet.id)):
			_mark((planet.center as Vector3)+SpaceLayout.fort_frame(planet).origin,UIStyle.BAD,"Fort")
		if planet.get("city",false): _draw_streets()
	for contact: Dictionary in contacts: _mark(contact.pos,contact.color)
	for ship: SpaceShip in world.ships.values(): _mark(ship.xform.origin,MinimapContacts.INTERACT)
	for mark: Dictionary in world.my_marks():
		if str(mark.get("kind", ""))!="zone": _quest(mark.pos)
	for mark: Dictionary in extra_markers:
		if str(mark.get("kind", "")) in ["quest", "side"]: _quest(mark.pos)
	var forward := -player.global_basis.z.rotated(player.up_direction,player.facing)
	var facing := Vector2(forward.dot(right),forward.dot(back)).normalized()
	if facing.length_squared()<0.01: facing = Vector2.UP
	draw_colored_polygon(PackedVector2Array([mid+facing*8,mid-facing*5+facing.orthogonal()*4,mid-facing*5-facing.orthogonal()*4]),Color.WHITE)
	draw_circle(mid, 4.0, Color("101522"))
	draw_circle(mid, 2.5, Color.WHITE)
	var title: String = ("Last Light Diner" if diner else "The Nexus") if planet.is_empty() else str(planet.name)
	draw_string(UIStyle.bold(),Vector2(0,size.y-3),title,HORIZONTAL_ALIGNMENT_CENTER,size.x,14,UIStyle.GOLD)

## Actual collision footprints show buildings, furniture, walls and walks.
## All scene access stays on the main thread; terrain painting stays in its worker.
func _draw_structures() -> void:
	for ref: WeakRef in _detail_shapes:
		var collider := ref.get_ref() as CollisionShape3D
		if not is_instance_valid(collider) or collider.disabled or not collider.shape is BoxShape3D: continue
		var box := collider.shape as BoxShape3D
		if box.size.x<0.25 or box.size.z<0.25: continue
		var at: Vector3 = collider.global_position
		if at.distance_to(reference)>radius+box.size.length()*0.5: continue
		if absf((at-reference).dot(up))>30.0: continue
		var points := PackedVector2Array()
		var inside := true
		for corner: Vector2 in [Vector2(-1,-1),Vector2(1,-1),Vector2(1,1),Vector2(-1,1)]:
			var point: Vector2 = _point(collider.global_transform*Vector3(corner.x*box.size.x*0.5,box.size.y*0.5,corner.y*box.size.z*0.5))
			if point.distance_to(size*0.5)>size.x*0.405: inside = false
			points.append(point)
		if not inside: continue
		if absf((points[1]-points[0]).cross(points[3]-points[0]))<0.2: continue
		draw_colored_polygon(points,Color("7b8588") if box.size.y>1.5 else Color("586b65"))
		draw_polyline(points+PackedVector2Array([points[0]]),Color("26343e"),1.0)

func _draw_streets() -> void:
	var uv := CityLayout.face_uv(up)
	var ci := floori((float(uv[1])+1.0)*0.5*CityLayout.N)
	var cj := floori((float(uv[2])+1.0)*0.5*CityLayout.N)
	for j in range(maxi(0,cj-2),mini(CityLayout.N,cj+3)):
		for i in range(maxi(0,ci-2),mini(CityLayout.N,ci+3)):
			for street: Dictionary in CityRoads.cell_streets(int(uv[0]),i,j):
				var points := PackedVector2Array()
				for dir: Vector3 in street.points: points.append(_point((planet.center as Vector3)+dir*float(planet.radius)))
				for k in points.size()-1:
					if points[k].distance_to(size*0.5)<size.x*0.40 and points[k+1].distance_to(size*0.5)<size.x*0.40: draw_line(points[k],points[k+1],Color("292f34"),2.0)

func _exit_tree() -> void:
	if _task>=0: WorkerThreadPool.wait_for_task_completion(_task)
