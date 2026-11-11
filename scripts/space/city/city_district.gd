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
## Every prop model faces -Z (make_city_props.py): yaw 0 shows its front to -Z,
## a seat's own yaw (forward -Z turned by it) points a chair the same way.
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
	process_physics_priority = -100  # cars move before anyone rides them
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
			"venues": _shopfront(item.cell, venues)
			"plaza": _plaza(item.cell)
			"secret": _secret(item.cell, venues)
			"park", "lake": _green(item.cell)
	for v: Dictionary in venues:
		if v.kind!="lobby": _room(v)
	for e: Dictionary in CityLayout.elevators():
		if e.district==data.id: _elevator_tower(e)
	_bridge()
	_streets()
	_props.flush(self)
	_towers.flush(self, "district", 3000.0, CityPlanet.DETAIL_RANGE, {}, true, 96.0)

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

## A solid box at a planet space transform (any rotation), collision only.
func _solid_at(xform: Transform3D, size: Vector3) -> void:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.transform = xform
	_body.add_child(shape)

## A tower-shader mass (windows) with collision.
func _mass(frame: Transform3D, at: Vector3, size: Vector3, color: Color, windows := 0.6, trims := 1.0, solid := true) -> void:
	var facade := CityArt.new(_towers, frame, [])
	facade.seed = CityLayout.rnd(at.x+at.z*0.1, 3)
	facade.part("box", at, Basis.IDENTITY, size, color, CityArt.M_PLASTER, windows, false)
	if solid: _solid(frame, at, size)

## A real sign (SignBoard) on a wall or post: neon boxes, plank boards, brass plaques.
func _sign(parent: Node3D, text: String, at: Vector3, color: Color, size := 1.0, yaw := 0.0, style := "neon", icon := "") -> SignBoard:
	var sign := SignBoard.make(text, style, icon, color.lightened(0.2) if style in ["neon", "paint"] else Color(0, 0, 0, 0), size*1.4)
	sign.position = at
	sign.rotation.y = yaw
	parent.add_child(sign)
	return sign

func _light(parent: Node3D, at: Vector3, color: Color, energy := 1.2, reach := 9.0) -> OmniLight3D:
	var omni := OmniLight3D.new()
	omni.position = at
	omni.light_color = color
	omni.light_energy = energy
	omni.omni_range = reach
	NearbyLightShadows.register_light(omni)
	omni.distance_fade_enabled = true
	omni.distance_fade_begin = 70.0
	omni.distance_fade_length = 30.0
	parent.add_child(omni)
	return omni

# --- Spaceport --------------------------------------------------------------------------------

## The spaceport: one huge building over the port's four cells. A glass
## terminal hall on the ground with doors on all four streets, offices
## above, the three landing pads on the flat roof, and a stair core in one
## corner climbing round an open well from the hall to a stair house on the
## roof (CityLayout.PORT_*).
func _port() -> void:
	var frame := CityLayout.district_frame(data)
	var port := _holder(frame, "Port")
	var art := NexusStation.Brush.new(port, false, 1800.0)
	var half := CityLayout.PORT_HALF
	var roof := CityLayout.PORT_ROOF
	var hall := CityLayout.PORT_HALL
	var core := CityLayout.PORT_CORE
	var ch := CityLayout.CORE_HALF
	var wall := Color("5a4a6a")
	var stone := Color("6a5a6e")
	var brass := Color("d9ac60")
	# The core with its walls: x from cx0 to the building's edge, z from its edge to cz1.
	var cx0 := core.x-ch-0.6
	var cz1 := core.z+ch+0.6
	var around := func(y0: float, y1: float, color: Color) -> void:
		art.box(Vector3((cx0-half)*0.5, (y0+y1)*0.5, 0), Vector3(cx0+half, y1-y0, half*2.0), color, true)
		art.box(Vector3((cx0+half)*0.5, (y0+y1)*0.5, (cz1+half)*0.5), Vector3(half-cx0, y1-y0, half-cz1), color, true)
	# A stone plinth reaching down into the curved ground; its top is the hall floor.
	# Recess the terminal entrances: all four ramps stay inside the port lot.
	art.box(Vector3(0, -4.0, 0), Vector3(half*2.0, 1.0, half*2.0), stone, true)
	var inner := half-6.0
	art.box(Vector3(0, -1.75, 0), Vector3(inner*2.0, 3.5, inner*2.0), stone, true)
	for side in 4:
		var turn := Basis(Vector3.UP, side*PI*0.5)
		for sign: float in [-1.0, 1.0]:
			var at := turn*Vector3(sign*(half+5.0)*0.5, -1.75, half-3.0)
			art.box(at, (turn*Vector3(half-5.0, 3.5, 6.0)).abs(), stone, true)
	art.box(Vector3(0, 0.02, 0), Vector3((half-6.0)*2.0, 0.04, (half-6.0)*2.0), Color("8a7a8e"))
	art.round_part(Vector3(0, 0.10, 0), 9.0, 0.06, _tint, false, 0.8)
	art.round_part(Vector3(0, 0.20, 0), 8.2, 0.06, Color("3a3248"))
	var to_core := Vector2(core.x-ch+1.5, core.z+ch+0.6)
	art.part("box", Transform3D(Basis(Vector3.UP, atan2(to_core.x, to_core.y)), Vector3(to_core.x*0.5, 0.06, to_core.y*0.5)),
		Vector3(0.4, 0.04, to_core.length()), _neon, false, 1.4)
	# The hall's ceiling, the offices above it (tower windows) and the roof deck, all round the core.
	around.call(hall-0.5, hall, Color("3a3046"))
	var body := roof-0.6-hall
	_mass(frame, Vector3((cx0-half)*0.5, hall+body*0.5, 0), Vector3(cx0+half, body, half*2.0), Color("4a3a5a"), 0.7)
	_mass(frame, Vector3((cx0+half)*0.5, hall+body*0.5, (cz1+half)*0.5), Vector3(half-cx0, body, half-cz1), Color("4a3a5a"), 0.7)
	around.call(roof-0.6, roof, Color("3a3248"))
	for y: float in [hall, roof-0.6]: around.call(y-0.15, y+0.15, brass)
	# The hall's glass fronts with a door in the middle of each street side.
	for side in 4:
		var b := Basis(Vector3.UP, side*PI*0.5)
		# Along this front (x in the side's frame); the core's corner has its own walls.
		var span := Vector2(-half, half)
		if side==1: span = Vector2(-half, -cz1)  # the +x front (its x runs along -z)
		if side==2: span = Vector2(-cx0, half)  # the -z front (its x runs along -x)
		_port_front(port, art, b, span)
		_sign(port, str(data.port).to_upper(), b*Vector3(0, hall+3.0, half+0.5), _tint, 3.2, side*PI*0.5)
		# A ramp from the door down to the sidewalk.
		var a := Vector3(0, 0.0, half-6.0)
		var e := Vector3(0, CityRoads.drop(Vector2(0, half-0.3))+CityRoads.KERB, half-0.3)
		var slope := atan2(a.y-e.y, e.z-a.z)
		art.part("box", Transform3D(b*Basis(Vector3.RIGHT, slope), b*((a+e)*0.5-Vector3.UP*0.15)), Vector3(9, 0.3, a.distance_to(e)), stone, true)
	# Inside: pillars, the departures board with benches, check-in desks,
	# a kiosk and a noodle stall, vending machines and plenty of light.
	for x: float in [-16.0, 16.0]:
		for z: float in [-16.0, 16.0]:
			art.round_part(Vector3(x, hall*0.5, z), 1.1, hall, wall, true)
			art.round_part(Vector3(x, 1.0, z), 1.4, 0.3, brass)
			_prop("potted_tree", port.transform, Vector3(x+2.4, 0.04, z+2.4))
	art.box(Vector3(0, 4.5, -24.4), Vector3(16.0, 9.0, 0.6), wall, true)
	_sign(port, "Departures\nPads 1 - 2 - 3 on the roof", Vector3(0, 6.4, -24.0), _neon, 1.1, 0.0, "slate", "arrow")
	_prop("holo_board", port.transform, Vector3(0, 2.2, -24.8))
	for row in 2:
		for k in 4: _prop("bench", port.transform, Vector3(-9.0+k*6.0, 0.04, -17.0+row*4.0))
	for x: float in [-22.0, 22.0]:
		art.box(Vector3(x, 0.55, 30.0), Vector3(12.0, 1.1, 1.2), Color("6a3a2a"), true)
		art.box(Vector3(x, 1.13, 30.0), Vector3(12.2, 0.08, 1.4), brass)
		art.box(Vector3(x, 0.3, 29.38), Vector3(12.0, 0.06, 0.06), _neon, false, 1.6)
		_sign(port, "Check-in", Vector3(x, 4.0, 31.2), _tint, 0.9, PI, "brass")
		art.box(Vector3(x, 3.0, 31.6), Vector3(10.0, 6.0, 0.4), wall, true)
	_prop("kiosk", port.transform, Vector3(-32.0, 0.04, 8.0), -PI*0.5)
	_prop("noodle_stall", port.transform, Vector3(32.0, 0.04, 8.0), PI*0.5)
	for z: float in [-12.0, -8.0, -4.0]: _prop("vending_machine", port.transform, Vector3(-half+1.2, 0.04, z), -PI*0.5)
	for x: float in [-30.0, -15.0, 0.0, 15.0]: art.box(Vector3(x, hall-0.56, 0), Vector3(0.4, 0.08, half*2.0-4.0), _tint, false, 1.6)
	for x: float in [-28.0, 0.0, 28.0]:
		for z: float in [-28.0, 0.0, 28.0]:
			if x>0.0 and z<0.0: continue  # the stair core
			# Broad overlapping ceiling fill rather than isolated colored pools.
			# Keep the themed color in fixtures; floor illumination is warm white.
			var fill := _light(port, Vector3(x, hall-1.5, z), Color("fff0db").lerp(_tint, 0.08), 0.4, 46.0)
			fill.omni_attenuation = 0.9
			fill.light_specular = 0.15
			fill.light_indirect_energy = 0.25
			fill.distance_fade_begin = 110.0
			fill.distance_fade_length = 50.0
	_sign(port, "Stairs to the pads", Vector3(core.x-ch+1.5, 4.2, cz1+0.1), _neon, 0.9, 0.0, "slate", "arrow")
	_port_core(port, art)
	_port_roof(port, art)
	art.finish()

## One street front of the hall (in the side's frame: the glass at z = half,
## x across `span`): glass between brass mullions, an 8 m door in the middle
## under a glowing canopy.
func _port_front(port: Node3D, art: NexusStation.Brush, b: Basis, span: Vector2) -> void:
	var half := CityLayout.PORT_HALF-6.0
	var hall := CityLayout.PORT_HALL
	var front_span := Vector2(maxf(span.x, -half), minf(span.y, half))
	var door := 4.0
	for piece: Vector2 in [Vector2(front_span.x, minf(front_span.y, -door)), Vector2(maxf(front_span.x, door), front_span.y)]:
		if piece.y-piece.x<0.5: continue
		_glass_panel(port, b*Vector3((piece.x+piece.y)*0.5, hall*0.5, half), (b*Vector3(piece.y-piece.x, hall, 0.12)).abs(), true)
	var x := ceilf(front_span.x/6.0)*6.0
	while x<=front_span.y:
		if absf(x)>door+0.5: art.box(b*Vector3(x, hall*0.5, half), (b*Vector3(0.35, hall, 0.5)).abs(), Color("d9ac60"), true)
		x += 6.0
	for s: float in [-door, door]: art.box(b*Vector3(s, hall*0.5, half), (b*Vector3(0.5, hall, 0.6)).abs(), Color("d9ac60"), true)
	_glass_panel(port, b*Vector3(0, (4.4+hall)*0.5, half), (b*Vector3(door*2.0, hall-4.4, 0.12)).abs(), true)
	art.box(b*Vector3(0, 4.4, half), (b*Vector3(door*2.0, 0.3, 0.5)).abs(), Color("d9ac60"))
	art.box(b*Vector3(0, 4.9, half+2.0), (b*Vector3(door*2.0+4.0, 0.3, 4.0)).abs(), Color("4a3a5a"))
	art.box(b*Vector3(0, 4.72, half+3.9), (b*Vector3(door*2.0+4.0, 0.08, 0.2)).abs(), _neon, false, 2.0)
	_light(port, b*Vector3(0, 4.2, half+2.0), _tint, 1.0, 9.0)

## The stair core: walls from the hall to the stair house on the roof, a door
## at each end, and flights of steps climbing round the open well with
## landings in the corners (CityLayout.core_corners), railed on the well side.
func _port_core(port: Node3D, art: NexusStation.Brush) -> void:
	var half := CityLayout.PORT_HALF
	var roof := CityLayout.PORT_ROOF
	var core := CityLayout.PORT_CORE
	var ch := CityLayout.CORE_HALF
	var width := CityLayout.STAIR_WIDTH
	var rise := CityLayout.FLIGHT_RISE
	var top := roof+4.5
	var wall := Color("5a4a6a")
	var inside := Color("cbb8a8")
	var cx0 := core.x-ch-0.6
	var cz1 := core.z+ch+0.6
	var box := func(x0: float, x1: float, y0: float, y1: float, z0: float, z1: float, color: Color) -> void:
		art.box(Vector3((x0+x1)*0.5, (y0+y1)*0.5, (z0+z1)*0.5), Vector3(x1-x0, y1-y0, z1-z0), color, true)
	# Outer walls (the building's corner) and the hall side walls, with the doors.
	var door_x := Vector2(core.x-ch, core.x-ch+width)  # ground door, onto the first landing
	var door_z := Vector2(core.z-4.0, core.z)  # roof door, in the stair house
	box.call(core.x+ch, half, 0.0, top, -half, cz1, wall)
	box.call(cx0, core.x+ch, 0.0, top, -half, core.z-ch, wall)
	box.call(door_x.y, half, 0.0, top, cz1-0.6, cz1, wall)
	box.call(cx0, door_x.x, 0.0, top, cz1-0.6, cz1, wall)
	box.call(door_x.x, door_x.y, 3.2, top, cz1-0.6, cz1, wall)
	box.call(cx0, cx0+0.6, 0.0, roof, -half, cz1, wall)
	box.call(cx0, cx0+0.6, roof, top, -half, door_z.x, wall)
	box.call(cx0, cx0+0.6, roof, top, door_z.y, cz1, wall)
	box.call(cx0, cx0+0.6, roof+3.2, top, door_z.x, door_z.y, wall)
	box.call(cx0-0.2, half+0.2, top, top+0.5, -half-0.2, cz1+0.2, Color("3a3248"))
	for d: Array in [[Vector3(door_x.x+width*0.5, 3.35, cz1+0.05), Vector3(width+0.4, 0.3, 0.2)], [Vector3(cx0-0.05, roof+3.35, core.z-2.0), Vector3(0.2, 0.3, 4.4)]]:
		art.box(d[0], d[1], _neon, false, 2.0)
	# A pale lining inside so the well is light, glowing bands every few metres.
	for k in 4:
		var y := 4.0+k*8.0
		art.box(Vector3(core.x, y, core.z-ch+0.06), Vector3(ch*2.0, 0.12, 0.1), _tint, false, 1.4)
		art.box(Vector3(core.x+ch-0.06, y, core.z), Vector3(0.1, 0.12, ch*2.0), _tint, false, 1.4)
		_light(port, Vector3(core.x, y+2.0, core.z), _tint, 1.2, 14.0)
	art.box(Vector3(core.x, roof*0.5, core.z-ch+0.02), Vector3(ch*2.0, roof, 0.04), inside)
	art.box(Vector3(core.x+ch-0.02, roof*0.5, core.z), Vector3(0.04, roof, ch*2.0), inside)
	# The flights: steps to look at, a smooth ramp to walk on, a rail on the well side.
	var corners := CityLayout.core_corners()
	var flights := int(roof/rise)
	var steps := 20
	for k in flights:
		var a: Vector2 = corners[k % 4]
		var c: Vector2 = corners[(k+1) % 4]
		var dir := (c-a).normalized()
		var y0 := k*rise
		var run := a.distance_to(c)-width
		var tread := run/steps
		var basis := Basis(Vector3.UP, atan2(dir.x, dir.y))
		var start := a+dir*width*0.5
		if k>0: art.box(core+Vector3(a.x, y0-0.2, a.y), Vector3(width, 0.4, width), wall, true)
		for st in steps:
			var at := start+dir*(st+0.5)*tread
			var h := (st+1)*rise/steps
			art.part("box", Transform3D(basis, core+Vector3(at.x, y0+h-0.16, at.y)), Vector3(width, 0.32, tread), inside if st % 2 else inside.darkened(0.08))
			art.part("box", Transform3D(basis, core+Vector3(at.x, y0+h-0.005, at.y)-basis*Vector3(0, 0, tread*0.5-0.04)), Vector3(width, 0.02, 0.08), Color("d9ac60"))
		var pitch := atan2(rise, run)
		var mid := start+dir*run*0.5
		var tilt := basis*Basis(Vector3.RIGHT, -pitch)  # climbing along +dir
		# Under the steps a sloped slab (seen from the well); the walking ramp is collision only.
		art.part("box", Transform3D(tilt, core+Vector3(mid.x, y0+rise*0.5-0.35, mid.y)), Vector3(width, 0.3, run/cos(pitch)), wall)
		_solid_at(port.transform*Transform3D(tilt, core+Vector3(mid.x, y0+rise*0.5+rise/steps*0.5-0.2, mid.y)), Vector3(width, 0.4, run/cos(pitch)+0.6))
		var inner := Vector2(dir.y, -dir.x)
		if inner.dot(-a)<0.0: inner = -inner
		var rail := mid+inner*(width*0.5-0.08)
		art.part("box", Transform3D(tilt, core+Vector3(rail.x, y0+rise*0.5+1.0, rail.y)), Vector3(0.12, 0.1, run/cos(pitch)), Color("d9ac60"), false, 0.4)
		art.part("box", Transform3D(tilt, core+Vector3(rail.x, y0+rise*0.5+0.5, rail.y)), Vector3(0.06, 1.0, run/cos(pitch)), Color("4a3a5a"), true)
	# The stair house floor at the roof's height, open over the last flight and its landing.
	var lane := ch-width
	var edge := core.x+ch-width
	art.box(Vector3((cx0+edge)*0.5, roof-0.2, core.z), Vector3(edge-cx0, 0.4, ch*2.0), Color("3a3248"), true)
	art.box(Vector3(core.x+ch-width*0.5, roof-0.2, core.z-lane-width*0.5), Vector3(width, 0.4, width), Color("3a3248"), true)
	art.box(Vector3(core.x+lane, roof+0.55, core.z+width*0.5), Vector3(0.12, 1.1, ch*2.0-width), Color("d9ac60"), true)
	_sign(port, "Terminal - stairs down", Vector3(cx0-0.15, roof+4.0, door_z.x+2.0), _neon, 0.8, -PI*0.5, "slate", "arrow")
	_light(port, Vector3(core.x, roof+3.5, core.z), _tint, 1.2, 12.0)

## The roof: the three pads with their rings and lights, a parapet, landing
## light masts and the control tower with its beacon.
func _port_roof(port: Node3D, art: NexusStation.Brush) -> void:
	var half := CityLayout.PORT_HALF
	var roof := CityLayout.PORT_ROOF
	var core := CityLayout.PORT_CORE
	var ch := CityLayout.CORE_HALF
	var cz1 := core.z+ch+0.6
	var cx0 := core.x-ch-0.6
	var r := CityLayout.PAD_RADIUS
	var desk := CityLayout.SHIPWRIGHT
	art.box(desk+Vector3(0, 0.6, 0), Vector3(5.0, 1.2, 1.5), Color("65513d"), true)
	art.box(desk+Vector3(0, 1.25, 0), Vector3(5.2, 0.12, 1.7), Color("cfb47e"))
	_prop("holo_board", port.transform, desk+Vector3(0, 1.4, 0), 0.0, 0.65)
	_prop("potted_tree", port.transform, desk+Vector3(-4, 0, 0))
	_sign(port, "SHIPWRIGHT\nFleet orders - Pads 1, 2, 3", desk+Vector3(0, 3.0, -0.7), _tint, 0.9)
	var wright := SpaceInteraction.new()
	wright.world = city.world
	wright.kind = "wright"
	wright.part = CityLayout.ID
	wright.title = str(data.name)+" shipwright"
	wright.description = "Order your ship to the first available pad: 1, then 2, then 3."
	wright.position = desk+Vector3(0, 1.0, 1.7)
	port.add_child(wright)
	for k in CityLayout.PORT_PADS.size():
		var pad: Vector3 = CityLayout.PORT_PADS[k]+Vector3.UP*roof
		art.round_part(pad+Vector3.UP*0.04, r+1.0, 0.06, Color("2a2436"), false)
		art.round_part(pad+Vector3.UP*0.13, r+0.2, 0.06, _tint, false, 1.4)
		art.round_part(pad+Vector3.UP*0.22, r-0.6, 0.06, Color("3a3248"), false)
		art.box(pad+Vector3(0, 0.30, 0), Vector3(1.0, 0.04, r), _tint, false, 1.2)
		art.box(pad+Vector3(0, 0.30, -r*0.5), Vector3(6.0, 0.04, 1.0), _tint, false, 1.2)
		for c in 8:
			var a := TAU*c/8.0
			art.box(pad+Vector3(cos(a)*(r+1.6), 0.3, sin(a)*(r+1.6)), Vector3(0.5, 0.5, 0.5), _neon if c % 2 else _tint, false, 2.2)
		_sign(port, "PAD %d" % (k+1), pad+Vector3(0, 0.2, r+2.5), _tint, 2.0, 0.0, "paint").rotation.x = -PI*0.5
		_light(port, pad+Vector3.UP*4.0, _tint, 1.2, 18.0)
	# Parapet round the edge (the stair house stands in its corner), lights on top.
	for side in 4:
		var b := Basis(Vector3.UP, side*PI*0.5)
		var span := Vector2(-half, half)
		if side==1: span = Vector2(-half, -cz1)
		if side==2: span = Vector2(-cx0, half)
		var mid := (span.x+span.y)*0.5
		var length := span.y-span.x
		art.box(b*Vector3(mid, roof+0.5, half-0.25), (b*Vector3(length, 1.0, 0.5)).abs(), Color("4a3a5a"), true)
		art.box(b*Vector3(mid, roof+1.04, half-0.25), (b*Vector3(length, 0.08, 0.3)).abs(), _neon, false, 1.6)
	# Landing light masts, and the control tower in the far corner from the stairs.
	for at: Vector2 in [Vector2(-40, 40), Vector2(40, 40), Vector2(0, 41), Vector2(-41, 0), Vector2(41, 0)]:  # clear of the ships (51 m long)
		art.box(Vector3(at.x, roof+3.0, at.y), Vector3(0.4, 6.0, 0.4), Color("6a5a6e"), true)
		art.box(Vector3(at.x, roof+6.3, at.y), Vector3(1.0, 0.6, 1.0), _tint, false, 2.5)
	var tower := Vector3(-36, roof, -36)
	art.round_part(tower+Vector3.UP*9.0, 3.0, 18.0, Color("4a3a5a"), true)
	art.round_part(tower+Vector3.UP*19.0, 6.0, 4.0, Color("2a2a3a"), true)
	art.round_part(tower+Vector3.UP*19.0, 6.2, 2.0, _neon, false, 1.8)
	art.box(tower+Vector3.UP*24.0, Vector3(0.6, 6, 0.6), Color("d9ac60"))
	art.box(tower+Vector3.UP*27.5, Vector3.ONE*1.4, Color("ff5a6a"), false, 3.0)
	_sign(port, str(data.port).to_upper(), Vector3(core.x, roof+2.6, cz1+0.15), _tint, 1.4)

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

## A shop block: each room (on its own street) in a storybook cottage with a
## barrel, dome, stepped gable or turret roof, and fairytale houses in what
## the cottages leave of the block.
func _shopfront(c: Dictionary, venues: Array) -> void:
	var local: Vector2i = Vector2i(int(c.i)-(int(data.corner.x)-3), int(c.j)-(int(data.corner.y)-3))
	var prefix := "%s_%d_%d_" % [data.id, local.x, local.y]
	var avoid: Array = []
	for side: int in [-1, 1]:
		var v: Dictionary = {}
		for x: Dictionary in venues:
			if str(x.key)==prefix+str(side+1): v = x
		if v.is_empty(): continue
		_cottage(v, float(c.seed)+side*0.21)
		var street := CityLayout.room_street(c, side)
		var inward: Vector2 = street[1]
		avoid.append([street[0], Vector2(CityLayout.ROOM.x*0.5+1.4, CityLayout.ROOM.z*0.5+1.4), inward.orthogonal().angle()])
	var solids: Array = []
	for block: Dictionary in CityRoads.blocks(int(c.face), int(c.i), int(c.j)):
		var seed := CityLayout.rnd(float(c.seed), 30)
		var art := CityArt.new(_towers, block.frame, solids)
		var feet := CityArt.pack(block, CityLayout.ROAD+CityLayout.WALK+0.8, seed, 4, 3.0, 8.0, avoid)
		for k in feet.size():
			var tall := lerpf(22.0, float(data.tower)*0.7, CityLayout.rnd(seed, 9)) if k==0 else lerpf(8.0, 32.0*float(data.height_scale), CityLayout.rnd(seed, 10+k))
			art.building(feet[k][0], float(feet[k][1]), tall, CityLayout.rnd(seed, 20+k), CityLayout.architecture(data, CityLayout.rnd(seed, 20+k)), _neon)
		art.gardens(block, CityLayout.ROAD+CityLayout.WALK+0.8, seed, feet+avoid.map(func(a: Array) -> Array: return [a[0], (a[1] as Vector2).length()]))
	for solid: Array in solids: _solid_shape(solid)

## Collision for a CityArt solid ([planet-space transform, size, kind]).
func _solid_shape(solid: Array) -> void:
	var shape := CollisionShape3D.new()
	var size: Vector3 = solid[1]
	if str(solid[2])=="cyl":
		var cyl := CylinderShape3D.new()
		cyl.radius = size.x*0.5
		cyl.height = size.y
		shape.shape = cyl
	else:
		var box := BoxShape3D.new()
		box.size = size
		shape.shape = box
	shape.transform = solid[0]
	_body.add_child(shape)

## The cottage round a shop room (its own frame, -Z the street): walls of
## plaster, stone or planks, timber corners, an attic over the room and a roof.
func _cottage(v: Dictionary, seed: float) -> void:
	var frame: Transform3D = v.frame
	var size: Vector3 = v.size
	var hx := size.x*0.5
	var hz := size.z*0.5
	var solids: Array = []
	var art := CityArt.new(_towers, frame, solids)
	art.seed = seed
	var wall_h := 8.4
	var mats := [[CityArt.PLASTER, CityArt.M_PLASTER], [CityArt.STONE, CityArt.M_STONE], [CityArt.BARK, CityArt.M_PLANK]]
	var look: Array = mats[int(art.r()*3.0) % 3]
	var wall := art.pick(look[0]).lightened(0.12 if look[1]==CityArt.M_PLANK else 0.0)
	var mat: float = look[1]
	for side: float in [-1.0, 1.0]:
		art.part("box", Vector3(side*(hx+0.35), wall_h*0.5-0.3, 0), Basis.IDENTITY, Vector3(0.7, wall_h, size.z), wall, mat, 0.3, false)
		_solid(frame, Vector3(side*(hx+0.35), wall_h*0.5-0.3, 0), Vector3(0.7, wall_h, size.z))
		_graffiti_on(frame, Vector3(side*(hx+0.72), 2.2, (art.r()-0.5)*5.0), Basis(Vector3.UP, side*PI*0.5), int(art.r()*CityTextures.GRAFFITI_COUNT), art.r()<0.55)
	art.part("box", Vector3(0, wall_h*0.5-0.3, hz+0.35), Basis.IDENTITY, Vector3(size.x+1.4, wall_h, 0.7), wall, mat, 0.3, false)
	_solid(frame, Vector3(0, wall_h*0.5-0.3, hz+0.35), Vector3(size.x+1.4, wall_h, 0.7))
	art.part("box", Vector3(0, (size.y+0.06+wall_h)*0.5, -hz), Basis.IDENTITY, Vector3(size.x+1.4, wall_h-size.y-0.06, 0.7), wall, mat, 0.4, false)
	# A neon glyph above the street entrance, mounted clear of the wall.
	art.neon_sign(Vector3(hx*0.65, size.y+1.5, -hz-0.48), Basis(Vector3.UP, PI), 1.5)
	var beam := art.pick(CityArt.BARK)
	for x: float in [-1.0, 1.0]:
		for z: float in [-1.0, 1.0]:
			art.part("box", Vector3(x*(hx+0.55), wall_h*0.5-0.3, z*(hz+0.35)), Basis.IDENTITY, Vector3(0.6, wall_h+0.2, 0.6), beam, CityArt.M_PLANK, 0.0, false, true)
	art.part("box", Vector3(0, size.y+0.2, -hz-0.4), Basis.IDENTITY, Vector3(size.x+1.6, 0.5, 0.5), beam, CityArt.M_PLANK, 0.0, false, true)
	var roof := art.pick(CityArt.ROOF)
	var depth := size.z+2.4
	match int(art.r()*4.0) % 4:
		0:
			# Barrel roof.
			art.part("cyl", Vector3(0, wall_h, 0.35), Basis(Vector3.FORWARD, PI*0.5), Vector3(5.6, size.x+2.2, depth), roof, CityArt.M_SHINGLE, 0.0, true)
		1:
			# Dome with a cupola.
			art.part("dome", Vector3(0, wall_h-0.3, 0.35), Basis.IDENTITY, Vector3(size.x+1.8, 6.0, depth), roof, CityArt.M_SHINGLE)
			art.part("cyl", Vector3(0, wall_h+6.2, 0.35), Basis.IDENTITY, Vector3(2.0, 1.6, 2.0), wall, mat, 0.6)
			art.part("cone", Vector3(0, wall_h+7.8, 0.35), Basis.IDENTITY, Vector3(2.6, 1.8, 2.6), roof, CityArt.M_SHINGLE)
		2:
			# A steep gable, stepped like a voxel staircase.
			for k in 7:
				var w := depth*(1.0-k/7.0)
				art.part("box", Vector3(0, wall_h+0.45+k*0.9, 0.35), Basis.IDENTITY, Vector3(size.x+2.2, 0.9, w), roof if k<6 else roof.lightened(0.2), CityArt.M_SHINGLE, 0.0, false)
		_:
			# Flat roof garden with a round turret at a front corner.
			art.part("box", Vector3(0, wall_h+0.1, 0.35), Basis.IDENTITY, Vector3(size.x+1.6, 0.5, depth-0.6), Color(str(CityArt.STONE[0])), CityArt.M_STONE, 0.0, false)
			art.part("box", Vector3(0, wall_h+0.45, 0.35), Basis.IDENTITY, Vector3(size.x, 0.3, depth-2.0), Color("3a6a42"), CityArt.M_GRASS, 0.0, false)
			var tx := (hx+0.6)*(1.0 if art.r()<0.5 else -1.0)
			art.part("cyl", Vector3(tx, wall_h+2.5, -hz), Basis.IDENTITY, Vector3(4.4, wall_h+6.0, 4.4), wall.darkened(0.08), mat, 0.5)
			art.part("cone", Vector3(tx, wall_h*2.0+0.2, -hz), Basis.IDENTITY, Vector3(5.4, 4.5, 5.4), roof, CityArt.M_SHINGLE)
			art.part("sphere", Vector3(tx, wall_h*2.0+2.6, -hz), Basis.IDENTITY, Vector3.ONE*0.7, _neon, CityArt.M_GLOW, 0.0, true, true)
	art.part("box", Vector3(hx*0.6, wall_h+2.5, hz*0.4), Basis.IDENTITY, Vector3(1.2, 4.0, 1.2), art.pick(CityArt.STONE), CityArt.M_STONE, 0.0, false, true)

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
		art.box(Vector3(-hx+1.4+k*(size.x-2.8)/5.0, 0.08, 0), Vector3(0.06, 0.02, size.z-0.6), look.floor.darkened(0.2))
	art.box(Vector3(0, 0.12, -1.0), Vector3(size.x*0.55, 0.02, size.z*0.45), look.rug)
	# Inside finish (covers the podium's own faces), a ceiling with lamp strips.
	var hidden: bool = v.kind=="speakeasy"
	art.box(Vector3(0, size.y*0.5, hz-0.16), Vector3(size.x, size.y, 0.2), look.wall)
	for side: float in [-1.0, 1.0]:
		if hidden and side<0.0:
			# The tunnel comes in through the left wall.
			for part: float in [-1.0, 1.0]:
				art.box(Vector3(-hx+0.1, size.y*0.5, part*(hz+1.2)*0.5), Vector3(0.2, size.y, hz-1.2), look.wall)
			art.box(Vector3(-hx+0.1, (3.0+size.y)*0.5, 0), Vector3(0.2, size.y-3.0, 2.4), look.wall)
			art.box(Vector3(-hx+0.25, 3.1, 0), Vector3(0.2, 0.15, 2.6), Color("d9ac60"))
			continue
		art.box(Vector3(side*(hx-0.16), size.y*0.5, 0), Vector3(0.2, size.y, size.z), look.wall)
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
	if sign_id!="" and v.kind!="speakeasy": _prop(sign_id, frame, Vector3(-hx+2.6, 6.0, -hz-0.4))
	var sign_look: Array = {cafe = ["plank", "coffee"], teahouse = ["plank", "tea"], bar = ["neon", "beer"], noodle = ["neon", "bowl"],
		arcade = ["neon", "game"], shop_budget = ["brass", "potion"], shop_premium = ["brass", "sword"], shop_curio = ["brass", "gem"]}.get(v.kind, ["plank", ""])
	_sign(node, str(v.name), Vector3(0, 6.8, -hz-0.75), _neon if v.kind.begins_with("shop") or v.kind=="arcade" else look.lamp, 0.9, PI, sign_look[0], sign_look[1])
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
				_prop("cafe_table", frame, tab)
				art.box(tab+Vector3(0, 2.6, 0), Vector3(0.6, 0.4, 0.6), look.lamp, false, 1.8)
			_prop("potted_tree", frame, Vector3(hx-1.0, 0.02, -hz+1.2))
			_prop("planter", frame, Vector3(-hx+1.0, 0.02, -hz+1.2))
		"bar", "speakeasy":
			_counter(node, v, art, look, "beer_taps")
			for side: float in [-1.0, 1.0]:
				_prop("booth_sofa", frame, Vector3(side*7.0, 0.02, -1.6), side*PI*0.5)
				art.box(Vector3(side*5.3, 0.45, -1.6), Vector3(1.4, 0.9, 2.6), Color("6a4a3a"), true)
			_prop("arcade_cabinet", frame, Vector3(-hx+1.0, 0.02, hz-2.6), -PI*0.5)
			_prop("lantern_string", frame, Vector3(0, size.y-0.6, -1.0), 0.0, 0.8)
		"noodle":
			_counter(node, v, art, look, "noodle_stall")
			_prop("lantern_string", frame, Vector3(0, size.y-0.6, 0.0), 0.0, 0.8)
		"shop_budget", "shop_premium", "shop_curio":
			if v.has("shop"):
				var staff: Dictionary = v.staff[0]
				ShopKeeper.place(node, str(v.shop), Transform3D(Basis(Vector3.UP, float(staff.yaw)), staff.pos))
			_counter(node, v, art, look, "")
			for side: float in [-1.0, 1.0]:
				for k in 3: _prop("shelf_goods", frame, Vector3(side*(hx-0.8), 0.02, -3.5+k*2.6), side*PI*0.5)
			_prop("shelf_goods", frame, Vector3(-3.0, 0.02, -0.5), 0.0)
			_prop("shelf_goods", frame, Vector3(3.0, 0.02, -0.5), 0.0)
		"arcade":
			for k in 3: _prop("arcade_cabinet", frame, Vector3(-5.0+k*5.0, 0.02, -2.4), PI)
			for k in 4: _prop("arcade_cabinet", frame, Vector3(-6.0+k*4.0, 0.02, 4.8), 0.0)
			_prop("vending_machine", frame, Vector3(hx-1.0, 0.02, 0.0), PI*0.5)
	# Seats: chairs or stools at each seat, a target to sit.
	for s: Dictionary in v.seats:
		var chair := "bar_stool" if v.kind in ["bar", "noodle", "speakeasy"] and absf(float((s.pos as Vector3).z)-3.0)<0.2 else "cafe_chair"
		if v.kind in ["bar", "speakeasy"] and chair=="cafe_chair": continue  # booth seats sit on the sofa
		_prop(chair, frame, s.pos, float(s.yaw))
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
	if machine!="":
		_prop(machine, frame, Vector3(-2.5, 1.16, 4.1))
		if machine in ["beer_taps", "coffee_machine"]:
			LeisureFurniture.target(node, "citytap|"+str(v.key), "tap", Transform3D(Basis.IDENTITY, Vector3(-2.5, 1.3, 4.1)), "coffee" if machine=="coffee_machine" else "beer")
	_prop("shelf_goods", frame, Vector3(3.5, 0.02, 5.6))
	_prop("shelf_goods", frame, Vector3(-3.5, 0.02, 5.6))
	art.box(Vector3(0, 3.2, 5.85), Vector3(6.0, 1.6, 0.1), look.lamp.darkened(0.3), false, 0.9)

func _venue_look(kind: String) -> Dictionary:
	match kind:
		"cafe": return {floor = Color("8a5a3a"), rug = Color("6a3a4a"), wall = Color("e8c8a8"), lamp = Color("ffc27a"), window = Color("e5d2ad"), awning = Color("c25a6a"), counter = Color("6a3a2a")}
		"teahouse": return {floor = Color("9a7a4a"), rug = Color("4a6a4a"), wall = Color("d8e0c0"), lamp = Color("c8ff9a"), window = Color("e5d2ad"), awning = Color("4a8a5a"), counter = Color("5a4a2a")}
		"bar", "speakeasy": return {floor = Color("4a2e24"), rug = Color("5a2a3a"), wall = Color("5a3a3a"), lamp = Color("ff9a5a"), window = Color("e5d2ad"), awning = Color("8a3a2a"), counter = Color("3a2218")}
		"noodle": return {floor = Color("7a3a2a"), rug = Color("aa4a3a"), wall = Color("f0d8b0"), lamp = Color("ff7a5a"), window = Color("e5d2ad"), awning = Color("d84a3a"), counter = Color("6a2a1a")}
		"arcade": return {floor = Color("2a2440"), rug = Color("4a2a6a"), wall = Color("3a3060"), lamp = Color("9a8aff"), window = Color("e5d2ad"), awning = Color("6a4aaa"), counter = Color("2a2440")}
		"shop_premium": return {floor = Color("d8d0c0"), rug = Color("3a4a7a"), wall = Color("f0e8d8"), lamp = Color("fff0c8"), window = Color("e5d2ad"), awning = Color("3a4a8a"), counter = Color("8a6a3a")}
		"shop_curio": return {floor = Color("5a3a5a"), rug = Color("7a4a6a"), wall = Color("6a4a6a"), lamp = Color("ff8ad8"), window = Color("e5d2ad"), awning = Color("8a3a7a"), counter = Color("4a2a3a")}
	return {floor = Color("a08060"), rug = Color("5a6a8a"), wall = Color("e0d0b8"), lamp = Color("ffd890"), window = Color("e5d2ad"), awning = Color("5a7aa0"), counter = Color("6a4a2a")}

func _seat_target(parent: Node3D, s: Dictionary, place: String) -> void:
	var target := CityTarget.new()
	target.world = city.world
	target.kind = "seat"
	target.seat = str(s.id)
	target.title = "Chair"
	target.description = "Sit down for a while"
	target.position = (s.pos as Vector3)+Vector3.UP*0.8
	parent.add_child(target)
	var spec := CityLayout.any_seat(str(s.id))
	if not spec.is_empty():
		var cup_target := LeisureTarget.new()
		cup_target.key = "citycup|"+str(s.id)
		cup_target.kind = "table"
		cup_target.place = city.world
		parent.add_child(cup_target)
		cup_target.global_position = spec.cup

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
		# Between floors a round shell, open in the middle so the shaft runs clear
		# from the lobby to the sky bar; a stone ledge under and over each glass floor.
		var shell := half*2.0*1.42
		if gap_h>1.0:
			var mid := h+ceiling+0.3+gap_h*0.5
			_towers.add("tube", frame*Transform3D(Basis.from_scale(Vector3(shell, gap_h, shell)), Vector3(0, mid, 0)), facade, Color(float(e.id)*0.13, 0.55, 0.0, 2.0))
			_towers.add("ring", frame*Transform3D(Basis.from_scale(Vector3(shell+0.6, 0.9, shell+0.6)), Vector3(0, h+ceiling+0.45, 0)), Color("8a7a7a"), Color(0, 0, CityArt.M_STONE, 2.0))
			_towers.add("ring", frame*Transform3D(Basis.from_scale(Vector3(shell+0.6, 0.9, shell+0.6)), Vector3(0, next-0.15, 0)), Color("8a7a7a"), Color(0, 0, CityArt.M_STONE, 2.0))
		if gap_h>1.0:
			for side in 4:
				var b := Basis(Vector3.UP, side*PI*0.5)
				_solid(frame, b*Vector3(0, h+ceiling+0.3+gap_h*0.5, -half+0.4), (b*Vector3(half*2.0, gap_h, 0.8)).abs())
	# A lid over the shell and an onion dome over the sky bar.
	var solids: Array = []
	_towers.add("cyl", frame*Transform3D(Basis.from_scale(Vector3(half*2.0*1.42, 0.6, half*2.0*1.42)), Vector3(0, float(e.height), 0)), facade.lightened(0.1), Color(0, 0, CityArt.M_STONE, 2.0))
	var crown := CityArt.new(_towers, frame, solids)
	crown.building(Vector2.ZERO, half*0.75, 30.0, float(e.id)*0.31+0.05, "onion", _neon, float(e.height))
	_sign(node, "%s TOWER" % str(data.name).to_upper(), Vector3(0, 7.5, -half-0.4), _neon, 1.6, PI, "neon", "lift")
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
		# The floor's finish, cut round the shaft like the slab (the car rides through here).
		var inner := half-0.5
		art.box(Vector3(0, y+0.005, (shaft.z-hole.y-inner)*0.5), Vector3(inner*2.0, 0.01, shaft.z-hole.y+inner), Color("8a7a8a"))
		art.box(Vector3(0, y+0.005, (shaft.z+hole.y+inner)*0.5), Vector3(inner*2.0, 0.01, inner-shaft.z-hole.y), Color("8a7a8a"))
		for side: float in [-1.0, 1.0]:
			art.box(Vector3(side*(hole.x+inner)*0.5, y+0.005, shaft.z), Vector3(inner-hole.x, 0.01, hole.y*2.0), Color("8a7a8a"))
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
	_sign(node, str(e.floors[f].name), Vector3(0, h+3.6, CityState.SHAFT.z-CityState.CAR.z*0.5-0.62), _tint, 0.6, PI, "brass", "lift")
	match kind:
		"lobby":
			art.box(Vector3(-7.0, h+0.6, -4.0), Vector3(4.0, 1.2, 1.2), Color("6a3a2a"), true)
			art.box(Vector3(-7.0, h+1.25, -4.0), Vector3(4.2, 0.1, 1.4), Color("d9ac60"))
			for k in 4: _prop("booth_sofa", frame, Vector3(7.0, h, -8.0+k*4.0), PI*0.5)
			for k in 4: _prop("potted_tree", frame, Vector3([-11.0, 11.0, -11.0, 11.0][k], h, [-11.0, -11.0, 11.0, 11.0][k]))
			_prop("holo_board", frame, Vector3(0, h+1.0, 11.5))
		"garden":
			for k in 6:
				var at := Vector3(-10.0+k*4.0, h, -9.0)
				_prop("planter", frame, at)
				_prop("potted_tree", frame, at+Vector3(0, 0, -2.0))
			art.round_part(Vector3(-7.0, h+0.4, 2.0), 2.4, 0.8, Color("8a7a8a"), true)
			art.round_part(Vector3(-7.0, h+0.82, 2.0), 2.1, 0.06, Color("6af0e0"), false, 1.2)
			for k in 4:
				var tab := Vector3(-8.0+k*5.3, h, 10.3)
				_prop("cafe_table", frame, tab)
			for s: Dictionary in CityLayout.tower_seats(e):
				if absf(float((s.pos as Vector3).y)-h)<0.5:
					_prop("cafe_chair", frame, s.pos, float(s.yaw))
					_seat_target(node, s, "Sky Garden")
		"residence":
			for k in 3:
				var x := -9.0+k*9.0
				art.box(Vector3(x, h+1.6, 8.0), Vector3(0.2, 3.2, 8.0), Color("d8c8b8"), true)
				art.box(Vector3(x+2.0, h+0.35, 10.0), Vector3(3.0, 0.7, 4.0), Color("8a6a9a"), true)
				art.box(Vector3(x+2.0, h+0.75, 11.4), Vector3(3.0, 0.3, 1.0), Color("f0e0e8"))
			for k in 3: _prop("booth_sofa", frame, Vector3(-6.0+k*6.0, h, -8.0), PI)
			_prop("arcade_cabinet", frame, Vector3(10.5, h, -2.0), PI*0.5)
			_prop("shelf_goods", frame, Vector3(-11.5, h, -2.0), -PI*0.5)
		"skybar":
			art.round_part(Vector3(0, h+0.55, -5.0), 2.5, 1.1, Color("3a2218"), true)
			art.round_part(Vector3(0, h+1.12, -5.0), 2.7, 0.08, Color("d9ac60"))
			_prop("beer_taps", frame, Vector3(0, h+1.16, -5.0), PI)
			for s: Dictionary in CityLayout.tower_seats(e):
				if absf(float((s.pos as Vector3).y)-h)<0.5:
					var p: Vector3 = s.pos
					var out := Vector3(p.x, 0, p.z).normalized()
					art.box(Vector3(p.x, h, p.z)+out*1.1+Vector3.UP*1.05, Vector3(1.4, 0.08, 0.7), Color("d9ac60"))
					_prop("bar_stool", frame, p, float(s.yaw))
					_seat_target(node, s, "Sky Bar")
			_prop("lantern_string", frame, Vector3(0, h+4.8, 0), 0.0, 1.2)
			_prop("lantern_string", frame, Vector3(0, h+4.8, 0), PI*0.5, 1.2)

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
		_prop("elevator_panel", node.transform, Vector3(w+0.8, h, s.z-w-0.4))
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
	# A thick floor (only its top is seen): a late step can never drop a rider through it.
	for at: Array in [[Vector3(0, -0.7, 0), Vector3(car.x, 1.4, car.z)], [Vector3(0, car.y+0.1, 0), Vector3(car.x, 0.2, car.z)],
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
		# The floor's letter painted beside its button.
		var mark := SignBoard.make(["L", "G", "R", "B"][f], "paint", "", Color("fff0c8"), 0.35)
		mark.position = at+Vector3(-0.01, 0, 0.14)
		mark.rotation.y = -PI*0.5
		body.add_child(mark)
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
	for end: float in [-1.0, 1.0]:
		_sign(node, "SKY BRIDGE", Vector3(0, 3.6, end*length*0.5), _tint, 0.8, 0.0 if end>0.0 else PI, "plank", "star")
	art.finish()

## A plaza on its block: cobbles (the ground's), a ring of paving round a
## fountain (a canal in Rosewater), benches and planters in a circle, trees,
## lamps and a vendor's stall, all sized to the room the streets leave.
func _plaza(c: Dictionary) -> void:
	var blocks := CityRoads.blocks(int(c.face), int(c.i), int(c.j))
	if blocks.is_empty(): return
	var block: Dictionary = blocks[0]
	var cell_frame: Transform3D = block.frame
	var seed: Vector2 = block.seed
	var room := CityRoads.field(block, seed)-CityLayout.ROAD-CityLayout.WALK-1.0
	if room<7.0: return
	var frame := Transform3D(cell_frame.basis, cell_frame*Vector3(seed.x, CityRoads.drop(seed), seed.y))
	var node := _holder(frame, "Plaza_%d_%d" % [c.i, c.j])
	var art := NexusStation.Brush.new(node, false, 500.0)
	var ring := minf(13.4, room*0.75)
	art.round_part(Vector3(0, 0.08, 0), ring+0.6, 0.12, Color("7a6a7a"))
	art.round_part(Vector3(0, 0.20, 0), ring, 0.08, _neon, false, 0.6)
	if data.theme=="rose":
		# A canal across the plaza, two arched bridges over it.
		var span := maxf(4.0, room*2.0-3.0)
		art.box(Vector3(0, 0.4, 0), Vector3(span, 0.6, 6.4), Color("8a6a7a"), true)
		art.box(Vector3(0, 0.72, 0), Vector3(span, 0.06, 5.6), Color("2a8aa8"), false, 0.5)
		for s: float in [-1.0, 1.0]: art.box(Vector3(0, 0.75, s*2.9), Vector3(span, 0.08, 0.2), _neon, false, 1.4)
		for x: float in [-room*0.5, room*0.5]:
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
		fountain.position = Vector3(0, 0.25, 0)
		fountain.scale = Vector3.ONE*minf(0.82, room/8.0)
		node.add_child(fountain)
		_light(node, Vector3(0, 3.0, 0), Color("6af0e0"), 1.0, 10.0)
	var bench := minf(10.0, ring*0.75)
	for k in 8:
		var a := TAU*k/8.0+0.39
		_prop("bench" if k % 2 else "planter", frame, Vector3(cos(a)*bench, 0.1, sin(a)*bench), -a+PI*0.5)
		var at := Vector2(cos(a), sin(a))*minf(15.5, room*0.92)
		if CityRoads.field(block, seed+at)>CityLayout.ROAD+CityLayout.WALK+1.0: _prop("potted_tree", frame, Vector3(at.x, 0.1, at.y))
	for k in 4:
		var a := TAU*k/4.0+PI*0.25
		_prop("street_lamp", frame, Vector3(cos(a), 0, sin(a))*room*0.95+Vector3.UP*0.1)
	_prop("noodle_stall" if int(c.i) % 2 else "kiosk", frame, Vector3(room*0.8, 0.1, 0), PI*0.5)
	_prop("hydrant_fountain", frame, Vector3(-room*0.8, 0.1, 3.0))
	_prop("holo_board", frame, Vector3(-room*0.75, 0.1, -6.0), -PI*0.5)
	art.finish()

## The district's lake and park (the lawns, water and trees are the
## skyline's; here what people use): benches round the water, lamps, a
## wooden bridge over the big pool, a kiosk and lantern strings.
func _green(c: Dictionary) -> void:
	for block: Dictionary in CityRoads.blocks(int(c.face), int(c.i), int(c.j)):
		var frame: Transform3D = block.frame
		var seed := CityLayout.rnd(float(c.seed), 40+int(block.sub))
		var lot := CityLayout.ROAD+CityLayout.WALK+0.8
		var lake: bool = block.role=="lake"
		var spots := CityArt.pack(block, lot+1.5, seed, 3, 6.0, 60.0) if lake else CityArt.pack(block, lot, seed, 4, 5.0, 40.0)
		var lift := func(at: Vector2, y: float) -> Vector3: return Vector3(at.x, CityRoads.drop(at)+y, at.y)
		for k in spots.size():
			var at: Vector2 = spots[k][0]
			var rr := float(spots[k][1])+(2.6 if lake else 0.0)
			var benches := 6 if lake else 4
			for b in benches:
				var a := TAU*(b+0.5)/benches+k
				var p := at+Vector2.from_angle(a)*(rr+1.6 if lake else rr*0.85)
				if CityRoads.field(block, p)<lot+0.5: continue
				_prop("bench" if b % 2==0 else "street_lamp", frame, lift.call(p, 0.15), -a+PI*0.5 if lake else -a-PI*0.5)
			if lake and k==0 and rr>11.0:
				_bridge_over(frame, at, rr-2.6, seed)
		if not spots.is_empty():
			var edge: Vector2 = spots[0][0]+Vector2.from_angle(seed*TAU)*(float(spots[0][1])+(5.5 if lake else 0.5))
			if CityRoads.field(block, edge)>lot+2.0: _prop("kiosk" if lake else "noodle_stall", frame, lift.call(edge, 0.15), seed*TAU)

## A humped wooden footbridge across a round pool (in a block frame).
func _bridge_over(frame: Transform3D, at: Vector2, radius: float, seed: float) -> void:
	var a := seed*TAU
	var along := Vector2.from_angle(a)
	var basis := Basis(Vector3.UP, -a)
	var holder := _holder(Transform3D(frame.basis*basis, frame*Vector3(at.x, CityRoads.drop(at), at.y)), "LakeBridge")
	var art := NexusStation.Brush.new(holder, false, 400.0)
	var half := radius+2.0
	var steps := 12
	for k in steps:
		var x0 := -half+k*half*2.0/steps
		var x1 := x0+half*2.0/steps
		var y0 := 0.3+2.2*(1.0-pow(x0/half, 2))
		var y1 := 0.3+2.2*(1.0-pow(x1/half, 2))
		var pitch := atan2(y1-y0, x1-x0)
		art.part("box", Transform3D(Basis(Vector3.BACK, pitch), Vector3((x0+x1)*0.5, (y0+y1)*0.5-0.12, 0)), Vector3(Vector2(x1-x0, y1-y0).length()+0.05, 0.24, 2.8), Color("8a5a3a"), true)
		for s: float in [-1.0, 1.0]:
			art.box(Vector3((x0+x1)*0.5, (y0+y1)*0.5+0.5, s*1.35), Vector3(0.12, 1.0, 0.12), Color("d9ac60"))
	for s: float in [-1.0, 1.0]:
		art.box(Vector3(0, 3.1, s*1.35), Vector3(half*1.2, 0.1, 0.1), Color("d9ac60"))
	_prop("lantern_string", holder.transform, Vector3(0, 4.2, 0), 0.0, 1.0)
	art.finish()

## A graffiti on a wall: `basis` turns the picture's face (+Z) outward from it.
func _graffiti_on(frame: Transform3D, at: Vector3, basis: Basis, index: int, show := true) -> void:
	if not show: return
	var size := CityTextures.graffiti_size(index)
	var quad := QuadMesh.new()
	quad.size = size
	var node := MeshInstance3D.new()
	node.mesh = quad
	node.material_override = graffiti_material(index)
	node.transform = frame*Transform3D(basis, at)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.visibility_range_end = 160.0
	add_child(node)

static var _graffiti_mats := {}
static func graffiti_material(index: int) -> StandardMaterial3D:
	if _graffiti_mats.has(index): return _graffiti_mats[index]
	var m := StandardMaterial3D.new()
	m.albedo_texture = CityTextures.graffiti(index)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = 0.5
	m.roughness = 0.9
	m.emission_enabled = true
	m.emission_texture = m.albedo_texture
	m.emission_energy_multiplier = 0.25
	_graffiti_mats[index] = m
	return m

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
	CityArt.new(_towers, frame, solids).building(Vector2.ZERO, p*0.7, lerpf(60.0, 110.0, float(c.seed)), float(c.seed), "crooked", _neon, t)
	for solid: Array in solids: _solid_shape(solid)
	# The alley is where the city's painters work.
	for k in 4:
		_graffiti_on(frame, Vector3(-p-0.05, 2.3, -11.0+k*2.6 if k<2 else 9.0+(k-2)*3.0), Basis(Vector3.UP, -PI*0.5), (int(float(c.seed)*97.0)+k*4) % CityTextures.GRAFFITI_COUNT, true)
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
	_prop("air_vent", frame, Vector3(-p+0.3, 1.9, 6.2), -PI*0.5, 0.8)
	_prop("air_vent", frame, Vector3(-10.0, 0.8, 5.15), PI, 0.6)
	_prop("pipe_bundle", frame, Vector3(-11.5, 0.3, 2.9), 0.0, 0.7)
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

## Lamps on the sidewalks of every district street (whichever way it runs),
## benches, bins and vending machines now and then, lantern strings across;
## nothing at the junctions or in front of shop doors.
func _streets() -> void:
	for item: Array in CityLayout.street_furniture(data):
		if item[0]=="lantern_span": _lantern_span(item[1])
		else: _prop(str(item[0]), item[1], item[2], float(item[3]) if item.size()>3 else 0.0)

## Supported festoon lights: the cable terminates on two sidewalk posts.
func _lantern_span(frame: Transform3D) -> void:
	var art := CityArt.new(_towers, frame, [])
	var span := CityLayout.ROAD+CityLayout.WALK*0.65
	var metal := Color("48443c")
	for side: float in [-1.0, 1.0]:
		var base := Vector3(0, CityRoads.drop(Vector2(0, side*span))+CityRoads.KERB, side*span)
		art.part("box", base+Vector3.UP*3.9, Basis.IDENTITY, Vector3(0.24, 7.8, 0.24), metal)
		art.part("box", base+Vector3.UP*0.3, Basis.IDENTITY, Vector3(0.6, 0.6, 0.6), Color("797369"), CityArt.M_STONE)
		_solid(frame, base+Vector3.UP*3.9, Vector3(0.24, 7.8, 0.24))
	for k in 16:
		var z0 := lerpf(-span, span, k/16.0)
		var z1 := lerpf(-span, span, (k+1)/16.0)
		var a := Vector3(0, 6.6+1.2*pow(z0/span, 2), z0)
		var b := Vector3(0, 6.6+1.2*pow(z1/span, 2), z1)
		var basis := Basis.looking_at((b-a).normalized(), Vector3.RIGHT)
		art.part("box", (a+b)*0.5, basis, Vector3(0.06, 0.06, a.distance_to(b)+0.02), metal)
	for k in 5:
		var z := lerpf(-span*0.78, span*0.78, k/4.0)
		var y := 6.6+1.2*pow(z/span, 2)
		art.part("box", Vector3(0, y-0.2, z), Basis.IDENTITY, Vector3(0.06, 0.4, 0.06), metal)
		art.part("box", Vector3(0, y-0.6, z), Basis.IDENTITY, Vector3(0.5, 0.55, 0.5), Color("e8cf9e"), CityArt.M_GLOW)
		art.part("box", Vector3(0, y-0.3, z), Basis.IDENTITY, Vector3(0.62, 0.12, 0.62), metal)

## A bench's visible prop and its two seats share the same authored transform.
func _prop(id: String, frame: Transform3D, at: Vector3, yaw := 0.0, scale := 1.0) -> void:
	_props.add(id, frame, at, yaw, scale)
	if id=="bench":
		var pose := frame*Transform3D(Basis(Vector3.UP, yaw), at)
		LeisureFurniture.bench_targets(self, CityLayout.bench_key(str(data.id), pose), pose, 0.65, 2.2)
