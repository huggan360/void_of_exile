class_name CityDistrict
extends Node3D
## One of Vesperis's three districts built in full (clients, planet space): the
## spaceport with its pads and terminal, podiums whose ground floors are cafes,
## bars, noodle counters, teahouses, shops and arcades you can walk into and sit
## in, two elevator skyscrapers with real floors joined by a sky bridge, plazas
## with fountains (canals in Rosewater), a secret tunnel to a hidden bar, and
## lamps, lantern strings, benches and signs along every street.
const GLASS_TINT := Color(0.55, 0.75, 0.95, 0.16)
var city: CityPlanet
var data: Dictionary
var cars := {}  # elevator id -> {car: AnimatableBody3D, doors: [left, right], door_shape, landings: [{panels, shape}], buttons: [Vector3]}
var _props := PropBatch.new()
var _towers := CityPlanet.Batch.new()
var _body: StaticBody3D
var _neon: Color
var _tint: Color
static var _glass: StandardMaterial3D

## Codex props in bulk: one MultiMesh per prop for its base and its glow.
class PropBatch extends RefCounted:
	var items := {}  # id -> Array[Transform3D]
	func add(id: String, frame: Transform3D, at: Vector3, yaw := 0.0, scale := 1.0) -> void:
		var meta := CityProps.meta("res://props/city/"+id, "prop.json")
		if meta.is_empty(): return
		var voxel := float(meta.get("voxel_size", 0.1))*scale
		if not items.has(id): items[id] = []
		items[id].append(frame*Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE*voxel), at))
	func flush(parent: Node3D) -> void:
		for id: String in items:
			var folder := "res://props/city/"+id
			var base := CityProps._load(folder+"/model.vox")
			if base.is_empty(): continue
			var offset := CityProps.center_offset(base)
			if id in ["cafe_table", "shelf_goods", "vending_machine", "arcade_cabinet", "kiosk", "planter", "potted_tree"]:
				var body := StaticBody3D.new()
				body.collision_layer = Player.OBSTACLE_LAYER
				body.collision_mask = 0
				var box: AABB = base[1]
				for pose: Transform3D in items[id]:
					var shape := CollisionShape3D.new()
					var solid := BoxShape3D.new()
					solid.size = box.size*pose.basis.get_scale()
					shape.shape = solid
					shape.transform = Transform3D(pose.basis.orthonormalized(), pose*(offset+box.get_center()))
					body.add_child(shape)
				parent.add_child(body)
			for pair: Array in [[base, VoxModel.material()], [CityProps._load(folder+"/model_glow.vox"), VoxModel.glow_material()]]:
				var mesh_data: Array = pair[0]
				if mesh_data.is_empty(): continue
				var multi := MultiMesh.new()
				multi.transform_format = MultiMesh.TRANSFORM_3D
				multi.mesh = mesh_data[0]
				var list: Array = items[id]
				multi.instance_count = list.size()
				for i in list.size(): multi.set_instance_transform(i, (list[i] as Transform3D)*Transform3D(Basis.IDENTITY, offset))
				var node := MultiMeshInstance3D.new()
				node.name = "Prop_"+id
				node.multimesh = multi
				node.material_override = pair[1]
				node.visibility_range_end = 260.0
				parent.add_child(node)
		items.clear()

static func glass() -> StandardMaterial3D:
	if _glass==null:
		_glass = StandardMaterial3D.new()
		_glass.albedo_color = GLASS_TINT
		_glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_glass.roughness = 0.05
		_glass.metallic_specular = 0.9
		_glass.rim_enabled = true
		_glass.rim = 0.4
		_glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	return _glass

func build() -> void:
	_neon = Color(str(data.neon))
	_tint = Color(str(data.tint))
	_body = StaticBody3D.new()
	_body.name = "Solid"
	_body.collision_layer = Player.OBSTACLE_LAYER
	_body.collision_mask = 0
	add_child(_body)
	_port()
	var venues := CityLayout.venues(data)
	for item: Dictionary in CityLayout.district_cells(data):
		match str(item.role):
			"venues": _podium(item.cell, venues)
			"plaza": _plaza(item.cell)
			"secret": _secret(item.cell, venues)
	for v: Dictionary in venues:
		if v.kind!="lobby": _room(v)
	for e: Dictionary in CityLayout.elevators():
		if e.district==data.id: _elevator_tower(e)
	_bridge()
	_streets()
	_props.flush(self)
	_towers.flush(self, "district", 3000.0)

## A planet-space holder at `frame`.
func _holder(frame: Transform3D, label: String) -> Node3D:
	var node := Node3D.new()
	node.name = label
	node.transform = frame
	add_child(node)
	return node

## A solid box (planet space frame, local centre and size) on the district's body.
func _solid(frame: Transform3D, at: Vector3, size: Vector3) -> void:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.transform = frame*Transform3D(Basis.IDENTITY, at)
	_body.add_child(shape)

## A tower-shader mass (windows) with collision.
func _mass(frame: Transform3D, at: Vector3, size: Vector3, color: Color, windows := 0.6, trims := 1.0, solid := true) -> void:
	_towers.add("box", frame*Transform3D(Basis.from_scale(size), at), color, Color(CityLayout.rnd(at.x+at.z*0.1, 3), windows, 0, trims))
	if solid: _solid(frame, at, size)

func _sign(parent: Node3D, text: String, at: Vector3, color: Color, size := 1.0, yaw := 0.0) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font = UIStyle.font()
	label.font_size = int(72*size)
	label.pixel_size = 0.008
	label.modulate = color.lightened(0.25)
	label.outline_modulate = color.darkened(0.7)
	label.outline_size = 18
	label.position = at
	label.rotation.y = yaw
	label.double_sided = false
	# Drawn with the walls (not blended after them), so rooms hide the street's signs.
	label.alpha_cut = Label3D.ALPHA_CUT_OPAQUE_PREPASS
	label.visibility_range_end = 220.0
	parent.add_child(label)
	return label

func _light(parent: Node3D, at: Vector3, color: Color, energy := 1.2, reach := 9.0) -> void:
	var omni := OmniLight3D.new()
	omni.position = at
	omni.light_color = color
	omni.light_energy = energy
	omni.omni_range = reach
	omni.shadow_enabled = false
	omni.distance_fade_enabled = true
	omni.distance_fade_begin = 70.0
	omni.distance_fade_length = 30.0
	parent.add_child(omni)

# --- Spaceport --------------------------------------------------------------------------------

func _port() -> void:
	var frame := CityLayout.district_frame(data)
	var port := _holder(frame, "Port")
	var art := NexusStation.Brush.new(port, false, 1800.0)
	# The deck over the four port cells, with glowing guide lines.
	art.box(Vector3(0, 0.1, 0), Vector3(100, 0.3, 100), Color("2a2436"), true)
	for x in [-48.5, 48.5]: art.box(Vector3(x, 0.32, 0), Vector3(0.6, 0.08, 100), _neon, false, 1.6)
	for z in [-48.5, 48.5]: art.box(Vector3(0, 0.32, z), Vector3(100, 0.08, 0.6), _neon, false, 1.6)
	for k in 3:
		var pad := Vector3((k-1)*32.0, 0.26, 8.0)
		art.round_part(pad, 13.0, 0.06, Color("3a3248"), false)
		art.round_part(pad+Vector3.UP*0.03, 12.2, 0.05, _tint, false, 1.4)
		art.round_part(pad+Vector3.UP*0.06, 11.4, 0.05, Color("3a3248"), false)
		art.box(pad+Vector3(0, 0.1, 0), Vector3(1.0, 0.05, 12.0), _tint, false, 1.2)
		art.box(pad+Vector3(0, 0.1, -6.0), Vector3(6.0, 0.05, 1.0), _tint, false, 1.2)
		for c in 8:
			var a := TAU*c/8.0
			art.box(pad+Vector3(cos(a)*13.6, 0.4, sin(a)*13.6), Vector3(0.5, 0.5, 0.5), _neon if c % 2 else _tint, false, 2.2)
		_sign(port, "PAD %d" % (k+1), pad+Vector3(0, 0.3, 14.5), _tint, 2.0).rotation.x = -PI*0.5
	# The terminal: a long hall with a glass front to the pads, walk in at either end.
	# Four broad ramps connect the flat deck to the curved street below.
	for side in 4:
		var turn := Basis(Vector3.UP, side*PI*0.5)
		var a := Vector3(0, 0.25, 48.0)
		var b := Vector3(0, -2.05, 64.0)
		var slope := atan2(a.y-b.y, b.z-a.z)
		art.part("box", Transform3D(turn*Basis(Vector3.RIGHT, slope), turn*((a+b)*0.5-Vector3.UP*0.15)), Vector3(9, 0.3, a.distance_to(b)+0.5), Color("5a4a5a"), true)
	var hall := Vector3(80, 12, 18)
	var hz := -38.0
	art.box(Vector3(0, 12.2, hz), Vector3(hall.x+2.0, 0.6, hall.z+2.0), Color("4a3a5a"), true)
	art.box(Vector3(0, 12.8, hz), Vector3(hall.x-6.0, 1.0, hall.z-4.0), _neon.darkened(0.2), false, 1.2)
	art.box(Vector3(0, 6.0, hz-hall.z*0.5), Vector3(hall.x, 12.0, 0.8), Color("5a4a6a"), true)
	for side: float in [-1.0, 1.0]:
		art.box(Vector3(side*hall.x*0.5, 6.0, hz-4.0), Vector3(0.8, 12.0, 10.0), Color("5a4a6a"), true)
		art.box(Vector3(side*hall.x*0.5, 9.0, hz+6.5), Vector3(0.8, 6.0, 5.0), Color("5a4a6a"), true)
	# Glass front with brass mullions and doors in the middle.
	var front := hz+hall.z*0.5
	for k in 17:
		var x := -40.0+k*5.0
		art.box(Vector3(x, 6.0, front), Vector3(0.35, 12.0, 0.4), Color("d9ac60"), absf(x)>3.0)
	_glass_panel(port, Vector3(-21.5, 6.0, front), Vector3(37.0, 12.0, 0.1), true)
	_glass_panel(port, Vector3(21.5, 6.0, front), Vector3(37.0, 12.0, 0.1), true)
	_glass_panel(port, Vector3(0, 9.5, front), Vector3(6.0, 5.0, 0.1), true)
	art.box(Vector3(0, 0.25, hz), Vector3(hall.x-1.0, 0.2, hall.z-1.0), Color("6a5a6e"), true)
	for k in 6:
		_props.add("bench", port.transform, Vector3(-30.0+k*12.0, 0.35, hz-2.0), PI)
		_props.add("potted_tree", port.transform, Vector3(-36.0+k*14.4, 0.35, hz-7.0))
	_props.add("vending_machine", port.transform, Vector3(36.0, 0.35, hz-7.5))
	_props.add("kiosk", port.transform, Vector3(-36.0, 0.35, hz-6.0))
	_props.add("holo_board", port.transform, Vector3(0, 6.5, hz-8.6))
	_sign(port, str(data.port).to_upper(), Vector3(0, 14.5, front+0.6), _tint, 3.2)
	_sign(port, "Arrivals - Departures - Ship parking", Vector3(0, 5.2, hz-8.4), _neon, 0.9)
	for k in 4: _light(port, Vector3(-30.0+k*20.0, 10.0, hz), _tint, 1.6, 16.0)
	# Control tower with a beacon, landing light masts on the deck's edge.
	art.round_part(Vector3(44, 18, -44), 3.0, 36.0, Color("4a3a5a"), true)
	art.round_part(Vector3(44, 37, -44), 6.0, 4.0, Color("2a2a3a"), true)
	art.round_part(Vector3(44, 37, -44), 6.2, 2.0, _neon, false, 1.8)
	art.box(Vector3(44, 42, -44), Vector3(0.6, 6, 0.6), Color("d9ac60"))
	art.box(Vector3(44, 45.5, -44), Vector3.ONE*1.4, Color("ff5a6a"), false, 3.0)
	for k in 8:
		var a := TAU*k/8.0+0.2
		var at := Vector3(cos(a)*52.0, 0, sin(a)*52.0)
		if at.z<-30.0 and absf(at.x)<42.0: continue
		art.box(at+Vector3.UP*4.0, Vector3(0.4, 8.0, 0.4), Color("6a5a6e"), true)
		art.box(at+Vector3.UP*8.3, Vector3(1.0, 0.6, 1.0), _tint, false, 2.5)
	art.finish()

func _glass_panel(parent: Node3D, at: Vector3, size: Vector3, solid: bool) -> void:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = glass()
	mesh.position = at
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh.visibility_range_end = 600.0
	parent.add_child(mesh)
	if solid: _solid(parent.transform, at, size)

# --- Podiums and their rooms ---------------------------------------------------------------

## A podium filling the lot: two venue rooms on its front and back streets, the
## rest solid, and a tower rising out of it.
func _podium(c: Dictionary, venues: Array) -> void:
	var frame: Transform3D = c.frame
	var p := CityLayout.PODIUM*0.5
	var t := CityLayout.PODIUM_TALL
	var room := CityLayout.ROOM
	var facade := Color(CityPlanet.FACADES[int(float(c.seed)*97.0) % CityPlanet.FACADES.size()])
	var front_z := p-room.z
	# Side blocks, the middle between the two rooms and the roof over them.
	for side: float in [-1.0, 1.0]:
		_mass(frame, Vector3(side*(p+room.x*0.5)*0.5, t*0.5-0.4, 0), Vector3(p-room.x*0.5, t+0.8, p*2.0), facade, 0.0, 0.0)
	_mass(frame, Vector3(0, t*0.5-0.4, 0), Vector3(room.x, t+0.8, front_z*2.0), facade.darkened(0.1), 0.0, 0.0)
	for side: float in [-1.0, 1.0]:
		_mass(frame, Vector3(0, (room.y+0.2+t)*0.5, side*(front_z+room.z*0.5)), Vector3(room.x, t-room.y-0.2, room.z), facade, 0.4, 1.0)
	# Neon trim along the podium's top and a tower above.
	_towers.add("box", frame*Transform3D(Basis.from_scale(Vector3(p*2.0+0.4, 0.4, p*2.0+0.4)), Vector3(0, t+0.2, 0)), _neon, Color(0, 0, 1, 0))
	var solids: Array = []
	var height := lerpf(50.0, float(data.tower)*0.8, CityLayout.rnd(float(c.seed), 9))
	city._tower(_towers, frame, Vector2.ZERO, Vector2(p*1.4, p*1.4), height, t, facade.lightened(0.05), _neon, float(c.seed), solids)
	for solid: Array in solids:
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = solid[1]
		shape.shape = box
		shape.transform = solid[0]
		_body.add_child(shape)
	# Rooftop clutter on the podium around the tower.
	for k in 4:
		var corner := Vector3((1 if k % 2 else -1)*(p-3.0), t, (1 if k>1 else -1)*(p-3.0))
		_props.add(["ac_unit", "water_tank", "antenna", "ac_unit"][k], frame, corner, k*0.7)
	# Air vents and pipe runs on the side walls (Theory of Everything style).
	for side: float in [-1.0, 1.0]:
		_props.add("air_vent", frame, Vector3(side*(p+0.1), 1.6, -4.0), side*PI*0.5)
		_props.add("pipe_bundle", frame, Vector3(side*(p+0.3), 6.5, 6.0), side*PI*0.5)

## A venue's room: floor, the front wall with its door and shop window, the
## inside finish, the sign over the door, furniture and the people's spots.
func _room(v: Dictionary) -> void:
	var frame: Transform3D = v.frame
	var node := _holder(frame, "Venue_"+str(v.key))
	var art := NexusStation.Brush.new(node, false, 240.0)
	var size: Vector3 = v.size
	var hx := size.x*0.5
	var hz := size.z*0.5
	var look := _venue_look(str(v.kind))
	# Floor (solid), checker or planks by kind, a rug.
	art.box(Vector3(0, -0.12, 0), Vector3(size.x, 0.28, size.z), look.floor, true)
	for k in 6:
		art.box(Vector3(-hx+1.4+k*(size.x-2.8)/5.0, 0.03, 0), Vector3(0.06, 0.02, size.z-0.6), look.floor.darkened(0.2))
	art.box(Vector3(0, 0.035, -1.0), Vector3(size.x*0.55, 0.02, size.z*0.45), look.rug)
	# Inside finish (covers the podium's own faces), a ceiling with lamp strips.
	var hidden: bool = v.kind=="speakeasy"
	art.box(Vector3(0, size.y*0.5, hz-0.1), Vector3(size.x, size.y, 0.2), look.wall)
	for side: float in [-1.0, 1.0]:
		if hidden and side<0.0:
			# The tunnel comes in through the left wall.
			for part: float in [-1.0, 1.0]:
				art.box(Vector3(-hx+0.1, size.y*0.5, part*(hz+1.2)*0.5), Vector3(0.2, size.y, hz-1.2), look.wall)
			art.box(Vector3(-hx+0.1, (3.0+size.y)*0.5, 0), Vector3(0.2, size.y-3.0, 2.4), look.wall)
			art.box(Vector3(-hx+0.25, 3.1, 0), Vector3(0.2, 0.15, 2.6), Color("d9ac60"))
			continue
		art.box(Vector3(side*(hx-0.1), size.y*0.5, 0), Vector3(0.2, size.y, size.z), look.wall)
		art.box(Vector3(side*(hx-0.25), 1.0, 0), Vector3(0.12, 0.12, size.z-0.4), Color("d9ac60"))
	art.box(Vector3(0, size.y-0.05, 0), Vector3(size.x, 0.12, size.z), look.wall.darkened(0.35))
	for k in 3: art.box(Vector3(-hx+3.0+k*(size.x-6.0)/2.0, size.y-0.18, 0), Vector3(0.35, 0.08, size.z-2.0), look.lamp, false, 1.6)
	# Front wall: door in the middle (3 m), shop windows either side.
	var door := 1.6 if not hidden else 0.0
	for side: float in [-1.0, 1.0]:
		var span := hx-door
		art.box(Vector3(side*(door+span*0.5), 0.5, -hz), Vector3(span, 1.0, 0.4), look.wall.darkened(0.2), true)
		art.box(Vector3(side*(door+span*0.5), 2.6, -hz-0.02), Vector3(span-0.4, 3.2, 0.12), look.window, false, 0.55)
		_solid(frame, Vector3(side*(door+span*0.5), 2.6, -hz), Vector3(span, 3.2, 0.3))
		art.box(Vector3(side*(door+span*0.5), 4.6, -hz), Vector3(span, 1.2, 0.4), look.wall.darkened(0.2), true)
		art.box(Vector3(side*door, 1.7, -hz-0.25), Vector3(0.25, 3.4, 0.25), Color("d9ac60"))
	if hidden:
		art.box(Vector3(0, size.y*0.5, -hz+0.1), Vector3(size.x, size.y, 0.2), look.wall)
	else:
		art.box(Vector3(0, 4.3, -hz), Vector3(door*2.0, 1.8, 0.4), look.wall.darkened(0.2), true)
		art.box(Vector3(0, 3.45, -hz-0.26), Vector3(door*2.0+0.4, 0.14, 0.14), _neon, false, 2.0)
	_light(node, Vector3(0, size.y-0.8, 0), look.lamp, 1.4, 11.0)
	_furnish(node, v, art, look, frame, size)
	if hidden:
		art.finish()
		return
	# Awning and the sign over the door.
	art.box(Vector3(0, 5.6, -hz-1.2), Vector3(size.x*0.7, 0.18, 2.4), look.awning, false, 0.4)
	var sign_id: String = {cafe = "sign_cafe", teahouse = "sign_cafe", bar = "sign_bar", speakeasy = "sign_bar", noodle = "sign_noodles",
		arcade = "sign_arcade", shop_budget = "sign_shop", shop_premium = "sign_shop", shop_curio = "sign_shop"}.get(v.kind, "")
	if sign_id!="" and v.kind!="speakeasy": _props.add(sign_id, frame, Vector3(-hx+2.6, 6.0, -hz-0.4), PI)
	_sign(node, str(v.name), Vector3(1.8, 6.6, -hz-0.45), _neon if v.kind.begins_with("shop") else look.lamp, 1.1, PI)
	_light(node, Vector3(0, 3.0, -hz-2.0), look.lamp, 0.8, 6.0)
	art.finish()

func _furnish(node: Node3D, v: Dictionary, art: NexusStation.Brush, look: Dictionary, frame: Transform3D, size: Vector3) -> void:
	var hx := size.x*0.5
	var hz := size.z*0.5
	# Furniture by kind.
	match str(v.kind):
		"cafe", "teahouse":
			_counter(node, v, art, look, "coffee_machine")
			for k in 3:
				var tab := Vector3([-5.0, 0.0, 5.0][k], 0, [-1.5, 0.5, -1.5][k])
				_props.add("cafe_table", frame, tab)
				art.box(tab+Vector3(0, 2.6, 0), Vector3(0.6, 0.4, 0.6), look.lamp, false, 1.8)
			_props.add("potted_tree", frame, Vector3(hx-1.0, 0.02, -hz+1.2))
			_props.add("planter", frame, Vector3(-hx+1.0, 0.02, -hz+1.2))
		"bar", "speakeasy":
			_counter(node, v, art, look, "beer_taps")
			for side: float in [-1.0, 1.0]:
				_props.add("booth_sofa", frame, Vector3(side*7.0, 0.02, -1.6), -side*PI*0.5)
				art.box(Vector3(side*5.3, 0.45, -1.6), Vector3(1.4, 0.9, 2.6), Color("6a4a3a"), true)
			_props.add("arcade_cabinet", frame, Vector3(-hx+1.0, 0.02, hz-2.6), PI*0.5)
			_props.add("lantern_string", frame, Vector3(0, size.y-0.6, -1.0), 0.0, 0.8)
		"noodle":
			_counter(node, v, art, look, "noodle_stall")
			_props.add("lantern_string", frame, Vector3(0, size.y-0.6, 0.0), 0.0, 0.8)
		"shop_budget", "shop_premium", "shop_curio":
			if v.has("shop"):
				var staff: Dictionary = v.staff[0]
				ShopKeeper.place(node, str(v.shop), Transform3D(Basis(Vector3.UP, float(staff.yaw)), staff.pos))
			_counter(node, v, art, look, "")
			for side: float in [-1.0, 1.0]:
				for k in 3: _props.add("shelf_goods", frame, Vector3(side*(hx-0.8), 0.02, -3.5+k*2.6), -side*PI*0.5)
			_props.add("shelf_goods", frame, Vector3(-3.0, 0.02, -0.5), 0.0)
			_props.add("shelf_goods", frame, Vector3(3.0, 0.02, -0.5), PI)
		"arcade":
			for k in 3: _props.add("arcade_cabinet", frame, Vector3(-5.0+k*5.0, 0.02, -2.4), 0.0)
			for k in 4: _props.add("arcade_cabinet", frame, Vector3(-6.0+k*4.0, 0.02, 4.8), PI)
			_props.add("vending_machine", frame, Vector3(hx-1.0, 0.02, 0.0), -PI*0.5)
	# Seats: chairs or stools at each seat, a target to sit.
	for s: Dictionary in v.seats:
		var chair := "bar_stool" if v.kind in ["bar", "noodle", "speakeasy"] and absf(float((s.pos as Vector3).z)-3.0)<0.2 else "cafe_chair"
		if v.kind in ["bar", "speakeasy"] and chair=="cafe_chair": continue  # booth seats sit on the sofa
		_props.add(chair, frame, s.pos, float(s.yaw)+PI)
	for k in v.seats.size():
		var s: Dictionary = v.seats[k]
		if k in v.patrons: continue
		_seat_target(node, s, str(v.name))

## The counter along the back wall, with the venue's machine on it.
func _counter(node: Node3D, v: Dictionary, art: NexusStation.Brush, look: Dictionary, machine: String) -> void:
	var frame: Transform3D = v.frame
	art.box(Vector3(0, 0.55, 4.0), Vector3(9.0, 1.1, 1.0), look.counter, true)
	art.box(Vector3(0, 1.12, 4.0), Vector3(9.2, 0.08, 1.15), Color("d9ac60"))
	art.box(Vector3(0, 0.25, 3.45), Vector3(9.0, 0.06, 0.06), _neon, false, 1.6)
	if machine!="": _props.add(machine, frame, Vector3(-2.5, 1.16, 4.1), PI)
	_props.add("shelf_goods", frame, Vector3(3.5, 0.02, 5.6), PI)
	_props.add("shelf_goods", frame, Vector3(-3.5, 0.02, 5.6), PI)
	art.box(Vector3(0, 3.2, 5.85), Vector3(6.0, 1.6, 0.1), look.lamp.darkened(0.3), false, 0.9)

func _venue_look(kind: String) -> Dictionary:
	match kind:
		"cafe": return {floor = Color("8a5a3a"), rug = Color("6a3a4a"), wall = Color("e8c8a8"), lamp = Color("ffc27a"), window = Color("ffd8a0"), awning = Color("c25a6a"), counter = Color("6a3a2a")}
		"teahouse": return {floor = Color("9a7a4a"), rug = Color("4a6a4a"), wall = Color("d8e0c0"), lamp = Color("c8ff9a"), window = Color("e0ffc0"), awning = Color("4a8a5a"), counter = Color("5a4a2a")}
		"bar", "speakeasy": return {floor = Color("4a2e24"), rug = Color("5a2a3a"), wall = Color("5a3a3a"), lamp = Color("ff9a5a"), window = Color("ffb070"), awning = Color("8a3a2a"), counter = Color("3a2218")}
		"noodle": return {floor = Color("7a3a2a"), rug = Color("aa4a3a"), wall = Color("f0d8b0"), lamp = Color("ff7a5a"), window = Color("ffc890"), awning = Color("d84a3a"), counter = Color("6a2a1a")}
		"arcade": return {floor = Color("2a2440"), rug = Color("4a2a6a"), wall = Color("3a3060"), lamp = Color("9a8aff"), window = Color("c8a8ff"), awning = Color("6a4aaa"), counter = Color("2a2440")}
		"shop_premium": return {floor = Color("d8d0c0"), rug = Color("3a4a7a"), wall = Color("f0e8d8"), lamp = Color("fff0c8"), window = Color("fff0d0"), awning = Color("3a4a8a"), counter = Color("8a6a3a")}
		"shop_curio": return {floor = Color("5a3a5a"), rug = Color("7a4a6a"), wall = Color("6a4a6a"), lamp = Color("ff8ad8"), window = Color("ffb8e8"), awning = Color("8a3a7a"), counter = Color("4a2a3a")}
	return {floor = Color("a08060"), rug = Color("5a6a8a"), wall = Color("e0d0b8"), lamp = Color("ffd890"), window = Color("ffe0b0"), awning = Color("5a7aa0"), counter = Color("6a4a2a")}

func _seat_target(parent: Node3D, s: Dictionary, place: String) -> void:
	var target := CityTarget.new()
	target.world = city.world
	target.kind = "seat"
	target.seat = str(s.id)
	target.title = place
	target.description = "Sit down. A %s will be brought to you. X sips, C orders another, Z stands." % ("coffee" if s.drink=="coffee" else "beer")
	target.position = (s.pos as Vector3)+Vector3.UP*0.8
	parent.add_child(target)

# --- Elevator skyscrapers -------------------------------------------------------------------

## A tower with four real floors (lobby, sky garden, residences, sky bar) on a
## glass-walled skeleton, solid between them, and its elevator.
func _elevator_tower(e: Dictionary) -> void:
	var frame: Transform3D = e.frame
	var node := _holder(frame, "Tower_%d" % e.id)
	var art := NexusStation.Brush.new(node, false, 900.0)
	var half := CityLayout.TOWER*0.5
	var floors: Array = e.floors
	var facade := Color("3e3a5a") if e.id % 2==0 else Color("4a3550")
	var bridge := CityLayout.sky_bridge(str(e.district))
	var bridge_dir := Vector3.ZERO
	if not bridge.is_empty():
		var mine: Transform3D = bridge[2] if (bridge[2] as Transform3D).origin.distance_to(CityLayout.tower_world(e).origin)<1.0 else bridge[3]
		var end: Vector3 = bridge[0] if mine==bridge[2] else bridge[1]
		bridge_dir = (mine.affine_inverse()*end)
		bridge_dir.y = 0
		bridge_dir = bridge_dir.normalized()
	var tower_world := CityLayout.tower_world(e)
	for f in floors.size():
		var h := float(floors[f].h)
		var ceiling := CityLayout.FLOOR_TALL
		_slab(art, h, half)
		_slab(art, h+ceiling, half, true)
		# Glass walls all round (the lobby's front has its doors), brass mullions.
		for side in 4:
			var basis := Basis(Vector3.UP, side*PI*0.5)
			var out := basis*Vector3(0, 0, -1)
			var gap := 0.0
			if f==0 and side==0: gap = 2.5
			if floors[f].kind=="garden" and bridge_dir!=Vector3.ZERO and out.dot(bridge_dir)>0.9: gap = 2.2
			_glass_wall(node, art, h, ceiling, half, basis, gap)
		_floor_room(node, art, e, f, h, half)
		# Solid tower (windows) between this floor and the next.
		var next := float(floors[f+1].h) if f+1<floors.size() else float(e.height)
		var gap_h := next-(h+ceiling+0.3)
		if gap_h>1.0: _mass(frame, Vector3(0, h+ceiling+0.3+gap_h*0.5, 0), Vector3(half*2.0, gap_h, half*2.0), facade, 0.55, 1.0, false)
		if gap_h>1.0:
			for side in 4:
				var b := Basis(Vector3.UP, side*PI*0.5)
				_solid(frame, b*Vector3(0, h+ceiling+0.3+gap_h*0.5, -half+0.4), (b*Vector3(half*2.0, gap_h, 0.8)).abs())
	# Crown over the sky bar.
	var solids: Array = []
	city._tower(_towers, frame, Vector2.ZERO, Vector2(half*1.6, half*1.6), 22.0, float(e.height), facade.lightened(0.1), _neon, float(e.id)*0.31, solids)
	_sign(node, "%s TOWER" % str(data.name).to_upper(), Vector3(0, 7.5, -half-0.4), _neon, 1.8, PI)
	_shaft(node, art, e, half)
	art.finish()

## A floor slab with a hole for the shaft (or a ceiling under the next floor).
func _slab(art: NexusStation.Brush, y: float, half: float, ceiling := false) -> void:
	var color := Color("2e2a3a") if ceiling else Color("6a5a6e")
	var shaft := CityState.SHAFT
	var hole := Vector2(CityState.CAR.x*0.5+0.35, CityState.CAR.z*0.5+0.35)
	var top := y-0.15 if not ceiling else y+0.15
	# Four pieces round the hole.
	art.box(Vector3(0, top, (shaft.z-hole.y-half)*0.5), Vector3(half*2.0, 0.3, shaft.z-hole.y+half), color, true)
	art.box(Vector3(0, top, (shaft.z+hole.y+half)*0.5), Vector3(half*2.0, 0.3, half-shaft.z-hole.y), color, true)
	for side: float in [-1.0, 1.0]:
		art.box(Vector3(side*(hole.x+half)*0.5, top, shaft.z), Vector3(half-hole.x, 0.3, hole.y*2.0), color, true)
	if not ceiling:
		art.box(Vector3(0, y+0.005, 0), Vector3(half*2.0-1.0, 0.01, half*2.0-1.0), Color("8a7a8a"))
	else:
		for k in 4: art.box(Vector3(-half+3.0+k*(half*2.0-6.0)/3.0, y-0.02, -half*0.4), Vector3(0.3, 0.06, half*1.2), Color("ffd890"), false, 1.5)

## One side of a floor: glass from floor to ceiling, mullions, a rail; `gap`
## (half width) leaves a doorway in the middle.
func _glass_wall(node: Node3D, art: NexusStation.Brush, y: float, tall: float, half: float, basis: Basis, gap: float) -> void:
	for k in 9:
		var x := -half+k*half*2.0/8.0
		art.part("box", Transform3D(basis, basis*Vector3(x, y+tall*0.5, -half)), Vector3(0.25, tall, 0.3), Color("d9ac60"), false)
	art.part("box", Transform3D(basis, basis*Vector3(0, y+tall-0.1, -half)), Vector3(half*2.0, 0.25, 0.35), _neon, false, 1.4)
	for side: float in [-1.0, 1.0]:
		var from := gap if gap>0.0 else 0.0
		var span := half-from
		if span<=0.1: continue
		var center := basis*Vector3(side*(from+span*0.5), y+tall*0.5, -half)
		var mesh := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(span, tall, 0.08)
		mesh.mesh = box
		mesh.material_override = glass()
		mesh.transform = Transform3D(basis, center)
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.add_child(mesh)
		var shape := CollisionShape3D.new()
		var b := BoxShape3D.new()
		b.size = Vector3(span, tall, 0.3)
		shape.shape = b
		shape.transform = node.transform*Transform3D(basis, center)
		_body.add_child(shape)
	if gap>0.0:
		art.part("box", Transform3D(basis, basis*Vector3(0, y+3.2, -half)), Vector3(gap*2.0, 0.3, 0.4), _neon, false, 2.0)

## What each floor holds.
func _floor_room(node: Node3D, art: NexusStation.Brush, e: Dictionary, f: int, h: float, half: float) -> void:
	var frame: Transform3D = e.frame
	var kind: String = e.floors[f].kind
	_light(node, Vector3(0, h+4.2, -6.0), Color("ffd890"), 1.4, 16.0)
	_light(node, Vector3(0, h+4.2, 7.0), Color("ffc8e0"), 1.0, 14.0)
	_sign(node, str(e.floors[f].name), Vector3(0, h+3.6, CityState.SHAFT.z-CityState.CAR.z*0.5-0.45), _tint, 0.8, PI)
	match kind:
		"lobby":
			art.box(Vector3(-7.0, h+0.6, -4.0), Vector3(4.0, 1.2, 1.2), Color("6a3a2a"), true)
			art.box(Vector3(-7.0, h+1.25, -4.0), Vector3(4.2, 0.1, 1.4), Color("d9ac60"))
			for k in 4: _props.add("booth_sofa", frame, Vector3(7.0, h, -8.0+k*4.0), -PI*0.5)
			for k in 4: _props.add("potted_tree", frame, Vector3([-11.0, 11.0, -11.0, 11.0][k], h, [-11.0, -11.0, 11.0, 11.0][k]))
			_props.add("holo_board", frame, Vector3(0, h+1.0, 11.5), PI)
		"garden":
			for k in 6:
				var at := Vector3(-10.0+k*4.0, h, -9.0)
				_props.add("planter", frame, at)
				_props.add("potted_tree", frame, at+Vector3(0, 0, -2.0))
			art.round_part(Vector3(-7.0, h+0.4, 2.0), 2.4, 0.8, Color("8a7a8a"), true)
			art.round_part(Vector3(-7.0, h+0.82, 2.0), 2.1, 0.06, Color("6af0e0"), false, 1.2)
			for k in 4:
				var tab := Vector3(-8.0+k*5.3, h, 10.3)
				_props.add("cafe_table", frame, tab)
			for s: Dictionary in CityLayout.tower_seats(e):
				if absf(float((s.pos as Vector3).y)-h)<0.5:
					_props.add("cafe_chair", frame, s.pos, float(s.yaw)+PI)
					_seat_target(node, s, "Sky Garden")
		"residence":
			for k in 3:
				var x := -9.0+k*9.0
				art.box(Vector3(x, h+1.6, 8.0), Vector3(0.2, 3.2, 8.0), Color("d8c8b8"), true)
				art.box(Vector3(x+2.0, h+0.35, 10.0), Vector3(3.0, 0.7, 4.0), Color("8a6a9a"), true)
				art.box(Vector3(x+2.0, h+0.75, 11.4), Vector3(3.0, 0.3, 1.0), Color("f0e0e8"))
			for k in 3: _props.add("booth_sofa", frame, Vector3(-6.0+k*6.0, h, -8.0), 0.0)
			_props.add("arcade_cabinet", frame, Vector3(10.5, h, -2.0), -PI*0.5)
			_props.add("shelf_goods", frame, Vector3(-11.5, h, -2.0), PI*0.5)
		"skybar":
			art.round_part(Vector3(0, h+0.55, -5.0), 2.5, 1.1, Color("3a2218"), true)
			art.round_part(Vector3(0, h+1.12, -5.0), 2.7, 0.08, Color("d9ac60"))
			_props.add("beer_taps", frame, Vector3(0, h+1.16, -5.0), PI)
			for s: Dictionary in CityLayout.tower_seats(e):
				if absf(float((s.pos as Vector3).y)-h)<0.5:
					var p: Vector3 = s.pos
					var out := Vector3(p.x, 0, p.z).normalized()
					art.box(Vector3(p.x, h, p.z)+out*1.1+Vector3.UP*1.05, Vector3(1.4, 0.08, 0.7), Color("d9ac60"))
					_props.add("bar_stool", frame, p, float(s.yaw)+PI)
					_seat_target(node, s, "Sky Bar")
			_props.add("lantern_string", frame, Vector3(0, h+4.8, 0), 0.0, 1.2)
			_props.add("lantern_string", frame, Vector3(0, h+4.8, 0), PI*0.5, 1.2)

## The shaft, its doors on every floor, the call panels and the car.
func _shaft(node: Node3D, art: NexusStation.Brush, e: Dictionary, half: float) -> void:
	var s := CityState.SHAFT
	var car := CityState.CAR
	var w := car.x*0.5+0.3
	var top := float(e.floors[-1].h)+CityLayout.FLOOR_TALL
	# Back and side walls the whole way up; front wall pieces between the doors.
	art.box(Vector3(0, top*0.5, s.z+w), Vector3(w*2.0+0.4, top, 0.3), Color("4a3a5a"), true)
	for side: float in [-1.0, 1.0]: art.box(Vector3(side*w, top*0.5, s.z), Vector3(0.3, top, w*2.0), Color("4a3a5a"), true)
	var landings: Array = []
	var floors: Array = e.floors
	for f in floors.size():
		var h := float(floors[f].h)
		var next := float(floors[f+1].h) if f+1<floors.size() else top
		art.box(Vector3(0, (h+3.0+next)*0.5, s.z-w), Vector3(w*2.0+0.4, next-h-3.0, 0.3), Color("4a3a5a"), true)
		for side: float in [-1.0, 1.0]: art.box(Vector3(side*(w-0.15), h+1.5, s.z-w), Vector3(0.3, 3.0, 0.3), Color("4a3a5a"), true)
		art.box(Vector3(0, h+3.05, s.z-w-0.2), Vector3(w*2.0+0.6, 0.12, 0.12), _neon, false, 2.0)
		_props.add("elevator_panel", node.transform, Vector3(w+0.8, h, s.z-w-0.4), PI)
		var call := CityTarget.new()
		call.world = city.world
		call.kind = "call"
		call.elevator = int(e.id)
		call.floor = f
		call.title = "Elevator - %s" % str(floors[f].name)
		call.description = "Press to call the car to this floor."
		call.position = Vector3(w+0.8, h+1.2, s.z-w-0.6)
		node.add_child(call)
		# Landing doors: two brass panels sliding apart, solid while shut.
		var panels: Array = []
		for side: float in [-1.0, 1.0]:
			var panel := MeshInstance3D.new()
			var box := BoxMesh.new()
			box.size = Vector3(w, 3.0, 0.12)
			panel.mesh = box
			var mat := StandardMaterial3D.new()
			mat.albedo_color = Color("b88a4a")
			mat.metallic = 0.6
			mat.roughness = 0.35
			panel.material_override = mat
			panel.position = Vector3(side*w*0.5, h+1.5, s.z-w-0.05)
			node.add_child(panel)
			panels.append(panel)
		var door_body := StaticBody3D.new()
		door_body.collision_layer = Player.TERRAIN_LAYER
		door_body.collision_mask = 0
		var door_shape := CollisionShape3D.new()
		var door_box := BoxShape3D.new()
		door_box.size = Vector3(w*2.0, 3.0, 0.3)
		door_shape.shape = door_box
		door_body.position = Vector3(0, h+1.5, s.z-w-0.05)
		door_body.add_child(door_shape)
		node.add_child(door_body)
		landings.append({panels = panels, body = door_body, h = h})
	# The car: a cosy brass box that carries whoever stands in it.
	# Moved from the shared state every frame; SpaceTraversal carries its riders.
	var body := StaticBody3D.new()
	body.name = "Car_%d" % e.id
	body.collision_layer = Player.TERRAIN_LAYER
	body.collision_mask = 0
	node.add_child(body)
	var car_art := NexusStation.Brush.new(body, false, 300.0)
	car_art.box(Vector3(0, -0.1, 0), Vector3(car.x, 0.2, car.z), Color("5a3a2a"))
	car_art.box(Vector3(0, car.y+0.1, 0), Vector3(car.x, 0.2, car.z), Color("3a2a2a"))
	car_art.box(Vector3(0, car.y-0.05, 0), Vector3(car.x-0.6, 0.06, car.z-0.6), Color("ffd890"), false, 1.8)
	car_art.box(Vector3(0, car.y*0.5, car.z*0.5), Vector3(car.x, car.y, 0.12), Color("8a5a3a"))
	for side: float in [-1.0, 1.0]:
		car_art.box(Vector3(side*car.x*0.5, car.y*0.5, 0), Vector3(0.12, car.y, car.z), Color("8a5a3a"))
		car_art.box(Vector3(side*(car.x*0.5-0.08), 1.0, 0), Vector3(0.06, 0.08, car.z-0.2), Color("d9ac60"))
	car_art.finish()
	for at: Array in [[Vector3(0, -0.1, 0), Vector3(car.x, 0.2, car.z)], [Vector3(0, car.y+0.1, 0), Vector3(car.x, 0.2, car.z)],
			[Vector3(0, car.y*0.5, car.z*0.5), Vector3(car.x, car.y, 0.12)], [Vector3(-car.x*0.5, car.y*0.5, 0), Vector3(0.12, car.y, car.z)],
			[Vector3(car.x*0.5, car.y*0.5, 0), Vector3(0.12, car.y, car.z)]]:
		var shape := CollisionShape3D.new()
		var b := BoxShape3D.new()
		b.size = at[1]
		shape.shape = b
		shape.position = at[0]
		body.add_child(shape)
	# The car's own doors (closed while it rides) and its button panel.
	var door_shape := CollisionShape3D.new()
	var door_b := BoxShape3D.new()
	door_b.size = Vector3(car.x, car.y, 0.12)
	door_shape.shape = door_b
	door_shape.position = Vector3(0, car.y*0.5, -car.z*0.5)
	body.add_child(door_shape)
	var doors: Array = []
	for side: float in [-1.0, 1.0]:
		var panel := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(car.x*0.5, car.y, 0.08)
		panel.mesh = box
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color("c8964a")
		mat.metallic = 0.6
		mat.roughness = 0.3
		panel.material_override = mat
		panel.position = Vector3(side*car.x*0.25, car.y*0.5, -car.z*0.5+0.06)
		body.add_child(panel)
		doors.append(panel)
	var buttons: Array[Vector3] = []
	var panel_x := car.x*0.5-0.08
	var plate := MeshInstance3D.new()
	var plate_box := BoxMesh.new()
	plate_box.size = Vector3(0.05, 1.0, 0.5)
	plate.mesh = plate_box
	var plate_mat := StandardMaterial3D.new()
	plate_mat.albedo_color = Color("3a2a2a")
	plate.material_override = plate_mat
	plate.position = Vector3(panel_x, 1.35, -0.6)
	body.add_child(plate)
	for f in floors.size():
		var at := Vector3(panel_x-0.04, 1.0+f*0.22, -0.6)
		buttons.append(at)
		var button := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.07
		cyl.bottom_radius = 0.07
		cyl.height = 0.04
		button.mesh = cyl
		var mat := StandardMaterial3D.new()
		mat.albedo_color = _tint
		mat.emission_enabled = true
		mat.emission = _tint
		mat.emission_energy_multiplier = 1.2
		button.material_override = mat
		button.position = at
		button.rotation.z = PI*0.5
		body.add_child(button)
		var label := Label3D.new()
		label.text = ["L", "G", "R", "B"][f]+"  "+str(floors[f].name)
		label.font = UIStyle.font()
		label.font_size = 18
		label.pixel_size = 0.004
		label.position = at+Vector3(-0.01, 0, 0.32)
		label.rotation.y = -PI*0.5
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		label.modulate = Color("fff0c8")
		body.add_child(label)
	var lamp := OmniLight3D.new()
	lamp.position = Vector3(0, car.y-0.4, 0)
	lamp.light_color = Color("ffd8a0")
	lamp.omni_range = 4.0
	lamp.light_energy = 1.0
	lamp.shadow_enabled = false
	body.add_child(lamp)
	cars[int(e.id)] = {car = body, doors = doors, door_shape = door_shape, landings = landings, buttons = buttons, node = node}
	_place_car(int(e.id))

func _physics_process(_delta: float) -> void:
	for e: int in cars: _place_car(e)

## Car height and every door from the shared elevator state.
func _place_car(e: int) -> void:
	var state: CityState = city.world.city
	if state==null or not state.elevators.has(e): return
	var spec: Dictionary = cars[e]
	var pose := state.car_state(e)
	var h := float(pose[0])
	var open := float(pose[1])
	var body: StaticBody3D = spec.car
	body.position = Vector3(0, h, CityState.SHAFT.z)
	var car := CityState.CAR
	for k in 2:
		var side := -1.0 if k==0 else 1.0
		(spec.doors[k] as Node3D).position.x = side*car.x*(0.25+0.24*open)
	(spec.door_shape as CollisionShape3D).disabled = open>0.6
	for landing: Dictionary in spec.landings:
		var here := absf(float(landing.h)-h)<0.05
		var o := open if here else 0.0
		for k in 2:
			var side := -1.0 if k==0 else 1.0
			(landing.panels[k] as Node3D).position.x = side*(car.x*0.5+0.3)*(0.5+0.48*o)
		(landing.body as StaticBody3D).collision_layer = 0 if o>0.6 else Player.TERRAIN_LAYER

## The floor button under a ray (world space) in elevator `e`'s car, or -1.
func button_at(e: int, origin: Vector3, dir: Vector3) -> int:
	if not cars.has(e): return -1
	var body: Node3D = cars[e].car
	var inv := body.global_transform.affine_inverse()
	var o := inv*origin
	var d := (inv.basis*dir).normalized()
	var x := CityState.CAR.x*0.5-0.12
	if absf(d.x)<0.01: return -1
	var t := (x-o.x)/d.x
	if t<0.0 or t>3.0: return -1
	var hit := o+d*t
	var buttons: Array = cars[e].buttons
	for f in buttons.size():
		var b: Vector3 = buttons[f]
		if Vector2(hit.y-b.y, hit.z-b.z).length()<0.11: return f
	return -1

# --- Sky bridge, plazas, the secret tunnel ---------------------------------------------------

## The glass bridge between the district's two towers at the sky garden floor.
func _bridge() -> void:
	var ends := CityLayout.sky_bridge(str(data.id))
	if ends.is_empty(): return
	var center: Vector3 = CityLayout.planet().center
	var a: Vector3 = ends[0]-center
	var b: Vector3 = ends[1]-center
	var mid := (a+b)*0.5
	var up := mid.normalized()
	var along := (b-a)
	var length := along.length()
	along = along.normalized()
	var side := along.cross(up).normalized()
	var frame := Transform3D(Basis(side, up, -along).orthonormalized(), mid)
	var node := _holder(frame, "SkyBridge")
	var art := NexusStation.Brush.new(node, false, 1200.0)
	art.box(Vector3(0, -0.15, 0), Vector3(4.4, 0.3, length+0.6), Color("6a5a6e"), true)
	art.box(Vector3(0, -0.6, 0), Vector3(1.2, 0.7, length), Color("d9ac60"))
	for s: float in [-1.0, 1.0]:
		art.box(Vector3(s*2.1, 0.55, 0), Vector3(0.12, 0.12, length), Color("d9ac60"))
		art.box(Vector3(s*2.1, 0.02, 0), Vector3(0.2, 0.05, length), _neon, false, 2.0)
		_glass_panel(node, Vector3(s*2.15, 0.6, 0), Vector3(0.06, 1.2, length), true)
		for k in 5:
			var z := -length*0.4+k*length*0.2
			art.box(Vector3(s*2.1, 1.6, z), Vector3(0.1, 3.2, 0.1), Color("d9ac60"))
			art.box(Vector3(s*2.1, 3.3, z), Vector3(0.4, 0.5, 0.4), _tint, false, 2.2)
	# A soft arch overhead.
	for k in 9:
		var t := k/8.0
		var a2 := PI*t
		art.box(Vector3(cos(a2)*2.2, 2.6+sin(a2)*1.2, 0), Vector3(0.35, 0.35, length*0.98), _neon.darkened(0.2) if k % 2 else Color("d9ac60"), false, 0.8 if k % 2 else 0.0)
	_sign(node, "SKY BRIDGE", Vector3(0, 4.2, 0), _tint, 1.2, PI*0.5)
	art.finish()

## A plaza: paved, a fountain in the middle (a canal in Rosewater), trees,
## benches, lamps, a vendor's stall.
func _plaza(c: Dictionary) -> void:
	var frame: Transform3D = c.frame
	var node := _holder(frame, "Plaza_%d_%d" % [c.i, c.j])
	var art := NexusStation.Brush.new(node, false, 500.0)
	var half: Vector2 = c.half
	var lot := Vector2(half.x, half.y)-Vector2.ONE*(CityLayout.ROAD+CityLayout.WALK)
	art.box(Vector3(0, 0.0, 0), Vector3(lot.x*2.0, 0.2, lot.y*2.0), Color("5a4a5a"), true)
	art.round_part(Vector3(0, 0.12, 0), 14.0, 0.04, Color("7a6a7a"))
	art.round_part(Vector3(0, 0.14, 0), 13.4, 0.04, _neon, false, 1.0)
	if data.theme=="rose":
		# A canal across the plaza, two arched bridges over it.
		art.box(Vector3(0, 0.4, 0), Vector3(lot.x*2.0, 0.6, 6.4), Color("8a6a7a"), true)
		art.box(Vector3(0, 0.72, 0), Vector3(lot.x*2.0, 0.06, 5.6), Color("2a8aa8"), false, 0.5)
		for s: float in [-1.0, 1.0]: art.box(Vector3(0, 0.75, s*2.9), Vector3(lot.x*2.0, 0.08, 0.2), _neon, false, 1.4)
		for x: float in [-lot.x*0.5, lot.x*0.5]:
			for k in 8:
				var z0 := -7.0+k*1.75
				var z1 := z0+1.75
				var a := Vector3(x, 0.12+1.7*(1.0-pow(z0/7.0, 2)), z0)
				var b := Vector3(x, 0.12+1.7*(1.0-pow(z1/7.0, 2)), z1)
				var pitch := atan2(a.y-b.y, b.z-a.z)
				art.part("box", Transform3D(Basis(Vector3.RIGHT, pitch), (a+b)*0.5-Vector3.UP*0.12), Vector3(3.2, 0.24, a.distance_to(b)+0.04), Color("d8c8b8"), true)
			for s: float in [-1.0, 1.0]: art.box(Vector3(x+s*1.6, 1.8, 0), Vector3(0.12, 0.8, 6.0), Color("d9ac60"))
	else:
		# A tiered fountain with glowing water.
		art.round_part(Vector3(0, 0.45, 0), 5.0, 0.9, Color("8a7a8a"), true)
		art.round_part(Vector3(0, 0.92, 0), 4.6, 0.06, Color("4ac8e0"), false, 0.8)
		art.round_part(Vector3(0, 1.6, 0), 1.0, 1.6, Color("8a7a8a"), true)
		art.round_part(Vector3(0, 2.5, 0), 2.4, 0.4, Color("8a7a8a"))
		art.round_part(Vector3(0, 2.72, 0), 2.1, 0.05, Color("4ac8e0"), false, 1.0)
		art.crystal(Vector3(0, 2.7, 0), 2.6, _neon)
		var fountain: Node3D = load("res://scripts/world/voxel_fountain.gd").new()
		fountain.position = Vector3(0, 0.9, 0)
		fountain.scale = Vector3.ONE*1.6
		node.add_child(fountain)
		_light(node, Vector3(0, 3.0, 0), Color("6af0e0"), 1.0, 10.0)
	for k in 8:
		var a := TAU*k/8.0+0.39
		var at := Vector3(cos(a)*10.0, 0.1, sin(a)*10.0)
		_props.add("bench" if k % 2 else "planter", frame, at, -a+PI*0.5)
		_props.add("potted_tree", frame, Vector3(cos(a)*15.5, 0.1, sin(a)*15.5))
	for k in 4:
		var at := Vector3((1 if k % 2 else -1)*(lot.x-1.5), 0.1, (1 if k>1 else -1)*(lot.y-1.5))
		_props.add("street_lamp", frame, at)
	_props.add("noodle_stall" if c.i % 2 else "kiosk", frame, Vector3(lot.x-4.0, 0.1, 0), -PI*0.5)
	_props.add("hydrant_fountain", frame, Vector3(-lot.x+2.0, 0.1, 3.0))
	_props.add("holo_board", frame, Vector3(-lot.x+1.5, 0.1, -6.0), PI*0.5)
	art.finish()

## The secret: an alley door on the west street, a service tunnel full of pipes,
## vents and steam, and the hidden bar inside the block.
func _secret(c: Dictionary, venues: Array) -> void:
	var frame: Transform3D = c.frame
	var p := CityLayout.PODIUM*0.5
	var t := CityLayout.PODIUM_TALL
	var facade := Color("3a3448")
	# Solid block around the room (z -2..10) and the tunnel (x -15..-8, z 2.8..5.2).
	_mass(frame, Vector3(0, t*0.5-0.4, (-p-2.0)*0.5), Vector3(p*2.0, t+0.8, p-2.0), facade, 0.0, 0.0)
	_mass(frame, Vector3(0, t*0.5-0.4, (p+10.0)*0.5), Vector3(p*2.0, t+0.8, p-10.0), facade, 0.0, 0.0)
	_mass(frame, Vector3((8.0+p)*0.5, t*0.5-0.4, 4.0), Vector3(p-8.0, t+0.8, 12.0), facade, 0.0, 0.0)
	_mass(frame, Vector3((-p-8.0)*0.5, t*0.5-0.4, 0.4), Vector3(p-8.0, t+0.8, 4.8), facade, 0.0, 0.0)
	_mass(frame, Vector3((-p-8.0)*0.5, t*0.5-0.4, 7.6), Vector3(p-8.0, t+0.8, 4.8), facade, 0.0, 0.0)
	_mass(frame, Vector3(0, (5.4+t)*0.5, 4.0), Vector3(16.0, t-5.4, 12.0), facade, 0.0, 0.0)
	_mass(frame, Vector3((-p-8.0)*0.5, (3.0+t)*0.5, 4.0), Vector3(p-8.0, t-3.0, 2.4), facade, 0.0, 0.0)
	var solids: Array = []
	city._tower(_towers, frame, Vector2.ZERO, Vector2(p*1.5, p*1.5), lerpf(60.0, 110.0, float(c.seed)), t, facade.lightened(0.1), _neon, float(c.seed), solids)
	for solid: Array in solids: _solid(solid[0], Vector3.ZERO, solid[1])
	# The tunnel uses the same conduit meshes and metal finish as Theory ships.
	var node := _holder(frame, "SecretTunnel")
	var art := NexusStation.Brush.new(node, false, 120.0)
	art.box(Vector3((-p-8.0)*0.5, 0.0, 4.0), Vector3(p-8.0+0.5, 0.2, 2.4), Color("3a3a3a"), true)
	var conduits: Array = []
	for k in 3:
		var y := 2.3+k*0.22
		var z := 3.2+k*0.55
		conduits.append({a = Vector3(-p, y, z), b = Vector3(-8.0, y, z), radius = 0.11, color = [TheoryArt.TRIM, TheoryArt.STEEL, Color("8a6a4a")][k]})
	TheoryRoundDetails.attach(node, conduits)
	_props.add("air_vent", frame, Vector3(-p+0.3, 1.9, 6.2), -PI*0.5, 0.8)
	_props.add("air_vent", frame, Vector3(-10.0, 0.8, 5.15), PI, 0.6)
	_props.add("pipe_bundle", frame, Vector3(-11.5, 0.3, 2.9), 0.0, 0.7)
	art.box(Vector3(-11.5, 2.6, 4.0), Vector3(0.4, 0.3, 0.4), Color("6af0e0"), false, 1.4)
	_light(node, Vector3(-11.5, 2.3, 4.0), Color("6af0e0"), 0.7, 5.0)
	# An open service hatch: the tunnel remains visibly walkable.
	art.box(Vector3(-p-0.2, 3.1, 4.0), Vector3(0.3, 0.3, 0.3), Color("ff9a5a"), false, 1.4)
	var steam := GPUParticles3D.new()
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3.UP
	pm.spread = 25.0
	pm.initial_velocity_min = 0.3
	pm.initial_velocity_max = 0.7
	pm.gravity = Vector3.UP*0.2
	pm.scale_min = 0.6
	pm.scale_max = 1.4
	pm.color = Color(0.85, 0.9, 0.95, 0.25)
	steam.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE*0.5
	var sm := StandardMaterial3D.new()
	sm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.albedo_color = Color(0.85, 0.9, 0.95, 0.18)
	sm.vertex_color_use_as_albedo = true
	quad.material = sm
	steam.draw_pass_1 = quad
	steam.amount = 24
	steam.lifetime = 3.0
	steam.position = Vector3(-12.5, 0.3, 4.4)
	node.add_child(steam)
	art.finish()

# --- Streets ------------------------------------------------------------------------------

## Lamps on both sidewalks of every district street, lantern strings across, a
## bench, bin or vending machine now and then.
func _streets() -> void:
	var f := int(data.face)
	var c: Vector2i = data.corner
	for k in 7:
		for along_u: bool in [true, false]:
			var fixed := float((c.y if along_u else c.x)-3+k)/CityLayout.N*2.0-1.0
			var start := float((c.x if along_u else c.y)-3)/CityLayout.N*2.0-1.0
			var span := 6.0/CityLayout.N*2.0
			var steps := 22
			for s in steps:
				var t := start+span*(s+0.5)/steps
				var u := t if along_u else fixed
				var v := fixed if along_u else t
				# Skip the port's deck.
				var cu := (u+1.0)*0.5*CityLayout.N
				var cv := (v+1.0)*0.5*CityLayout.N
				if absf(cu-c.x)<2.0 and absf(cv-c.y)<2.0: continue
				var frame := CityLayout.frame_at(f, u, v)
				if not along_u: frame.basis = frame.basis*Basis(Vector3.UP, PI*0.5)
				for side: float in [-1.0, 1.0]:
					var at := Vector3(0, 0.05, side*(CityLayout.ROAD+CityLayout.WALK*0.75))
					var salt := k*1000+s*10+(1 if side>0 else 0)+(500 if along_u else 0)
					if s % 3==0:
						_props.add("street_lamp", frame, at, PI*0.5 if side>0 else -PI*0.5)
					else:
						var roll := CityLayout.rnd(0.17, salt)
						if roll<0.12: _props.add("bench", frame, at+Vector3(0, 0, side*0.6), PI if side>0 else 0.0)
						elif roll<0.2: _props.add("trash_bin", frame, at)
						elif roll<0.25: _props.add("vending_machine", frame, at+Vector3(0, 0, side*0.9), PI if side>0 else 0.0)
						elif roll<0.3: _props.add("planter", frame, at)
				if s % 3==1:
					_props.add("lantern_string", frame, Vector3(0, 7.0, 0), PI*0.5, 2.2)
