class_name PlanetTown
extends Node3D
## A settlement on a planet, clients only, built from the world's own voxel
## houses (PlanetProps.STYLES): either its town (SpaceLayout.TOWNS: a plaza,
## two rings of houses round it, market stalls and lamps, the smith who sells
## your items for Dots, the shipwright by the shipyard pad) or one of its
## villages (SpaceLayout.settlements: a hamlet round a lamp, a village round a
## well, or a large village round a plaza with its big building). Townsfolk
## stroll about. SpacePlanet builds it only while the camera is near.
const FOLK := {town = 8, large = 6, village = 4, hamlet = 2}
var world: SpaceWorld
var planet: Dictionary
var center := Vector3.UP  # unit direction of the middle
var _folk: Array = []  # {model, at (Vector2 local metres), goal, wait} or {model, fixed}
var _rng := RandomNumberGenerator.new()
var _roam := 14.0

## The planet's town, with its traders and shipyard.
func build_town(p: Dictionary) -> void:
	planet = p
	var town: Dictionary = SpaceLayout.TOWNS[p.id]
	var look := PlanetProps.style(p)
	_rng.seed = absi(String(p.id).hash())+5
	center = SpaceLayout.place_frame_raw(p, SpaceLayout.town_offset(p))
	_roam = 16.0
	PlanetProps.building(self, p, str(look.plaza), center, Vector3.INF)
	PlanetProps.building(self, p, str(look.well), center, Vector3.INF)
	# The shipyard lies out along one side; the rings leave a lane open to it.
	var dock := SpaceLayout.place_frame_raw(p, SpaceLayout.dock_offset(p))
	var lane := _local_angle(dock)
	var houses: Array = look.houses
	var n := 0
	for ring: Array in [[29.0, 9, 0.2], [46.0, 13, 0.0]]:
		for i in int(ring[1]):
			var a := TAU*i/float(ring[1])+float(ring[2])
			if absf(angle_difference(a, lane))<0.42: continue
			var at := PlanetProps.offset_dir(p, center, Vector2.from_angle(a)*float(ring[0])*(1.0+_rng.randf_range(-0.05, 0.05)))
			PlanetProps.building(self, p, str(houses[n % houses.size()]), at, center)
			n += 1
	var stalls: Array = look.stalls
	for k in 3:
		var a := lane+PI+(k-1)*0.55
		PlanetProps.building(self, p, str(stalls[k % stalls.size()]), PlanetProps.offset_dir(p, center, Vector2.from_angle(a)*21.5), center)
	for k in 8:
		var a := TAU*(k+0.5)/8.0
		var at := PlanetProps.offset_dir(p, center, Vector2.from_angle(a)*19.0)
		PlanetProps.building(self, p, str(look.lamp), at, center)
		if k % 2==0: PlanetProps.light(self, p, at, 3.2, PlanetProps.lamp_color(p), 1.0, 12.0)
	_shipyard(p)
	_trader(p, "smith", str(town.smith), "%s's smith" % town.name, "Lay anything on the anvil and the forge turns it into Dots.")
	_trader(p, "wright", str(town.wright), "%s shipwright" % town.name, "A sound little sky-galleon, fitted and waiting on the shipyard pad.")
	_spawn_folk(p, look, FOLK.town)

## One of the planet's villages (an entry of SpaceLayout.settlements).
func build_village(p: Dictionary, v: Dictionary) -> void:
	planet = p
	var look := PlanetProps.style(p)
	_rng.seed = absi(String(p.id).hash())+31*int(v.index)+7
	center = v.dir
	var kind := str(v.kind)
	var houses: Array = look.houses
	var count := int(v.houses)
	var turn := _rng.randf()*TAU
	match kind:
		"hamlet":
			_roam = 8.0
			PlanetProps.building(self, p, str(look.lamp), center, Vector3.INF)
			PlanetProps.light(self, p, center, 3.2, PlanetProps.lamp_color(p), 1.0, 12.0)
			for i in count:
				var a := turn+TAU*i/count+_rng.randf_range(-0.25, 0.25)
				PlanetProps.building(self, p, str(houses[(i+int(v.index)) % houses.size()]), PlanetProps.offset_dir(p, center, Vector2.from_angle(a)*_rng.randf_range(11.0, 14.0)), center)
		"village":
			_roam = 12.0
			PlanetProps.building(self, p, str(look.well), center, Vector3.INF)
			for i in count:
				var a := turn+TAU*i/count+_rng.randf_range(-0.12, 0.12)
				PlanetProps.building(self, p, str(houses[(i+int(v.index)) % houses.size()]), PlanetProps.offset_dir(p, center, Vector2.from_angle(a)*_rng.randf_range(18.0, 21.0)), center)
			for k in 4:
				var at := PlanetProps.offset_dir(p, center, Vector2.from_angle(turn+TAU*(k+0.5)/4.0)*9.0)
				PlanetProps.building(self, p, str(look.lamp), at, center)
				if k % 2==0: PlanetProps.light(self, p, at, 3.2, PlanetProps.lamp_color(p), 1.0, 12.0)
			PlanetProps.building(self, p, str((look.stalls as Array)[0]), PlanetProps.offset_dir(p, center, Vector2.from_angle(turn+PI/count)*11.5), center)
		_:
			_roam = 15.0
			PlanetProps.building(self, p, str(look.plaza), center, Vector3.INF)
			PlanetProps.building(self, p, str(look.well), center, Vector3.INF)
			var inner := 6
			for i in count:
				var outer := i>=inner
				var slots := inner if not outer else count-inner
				var a := turn+TAU*(i-(inner if outer else 0))/slots+(PI/slots if outer else 0.0)
				var asset := str(look.big) if i==count-1 else str(houses[(i+int(v.index)) % houses.size()])
				var reach := 25.0 if not outer else 37.0
				if i==count-1: reach = 38.0
				PlanetProps.building(self, p, asset, PlanetProps.offset_dir(p, center, Vector2.from_angle(a)*reach), center)
			var stalls: Array = look.stalls
			for k in 2: PlanetProps.building(self, p, str(stalls[k % stalls.size()]), PlanetProps.offset_dir(p, center, Vector2.from_angle(turn+PI*k+0.3)*13.0), center)
			for k in 6:
				var at := PlanetProps.offset_dir(p, center, Vector2.from_angle(turn+TAU*(k+0.5)/6.0)*18.0)
				PlanetProps.building(self, p, str(look.lamp), at, center)
				if k % 2==0: PlanetProps.light(self, p, at, 3.2, PlanetProps.lamp_color(p), 1.0, 12.0)
	_spawn_folk(p, look, int(FOLK.get(kind, 3)))

## The angle (in `center`'s tangent frame, as offset_dir uses) toward `dir`.
func _local_angle(dir: Vector3) -> float:
	var right := center.cross(Vector3.FORWARD if absf(center.dot(Vector3.FORWARD))<0.95 else Vector3.RIGHT).normalized()
	var forward := right.cross(center)
	return atan2(dir.dot(forward), dir.dot(right))

func _spawn_folk(p: Dictionary, look: Dictionary, count: int) -> void:
	var folk: Array = look.folk
	for i in count:
		var model := CreatureModel.new(str(folk[i % folk.size()]))
		add_child(model)
		var at := Vector2.from_angle(_rng.randf()*TAU)*_rng.randf_range(3.0, _roam)
		_folk.append({model = model, at = at, goal = at, wait = _rng.randf_range(0.0, 4.0)})
		_place(model, at, 0.0)

func _shipyard(p: Dictionary) -> void:
	var dock := Node3D.new()
	dock.transform = SpaceLayout.town_frame(p, "dock")
	add_child(dock)
	SpacePlanet.build_pad(dock, p, world, "%s shipyard crystal" % str(SpaceLayout.TOWNS[p.id].name))
	var dir := SpaceLayout.place_frame_raw(p, SpaceLayout.dock_offset(p))
	for side in [-1.0, 1.0]:
		var post := dock.transform*Vector3(-24.5, 0, side*3.4)
		PlanetProps.building(self, p, str(PlanetProps.style(p).lamp), post.normalized(), dir)
	# Painted on a board between the two lamps, both faces.
	for k in 2:
		var sign := SignBoard.make("SHIPYARD", "paint", "", Color("4a3024"), 1.6)
		sign.position = Vector3(-24.5+(0.16 if k==0 else -0.16), 2.4, 0)
		sign.rotation.y = PI*0.5 if k==0 else -PI*0.5
		dock.add_child(sign)

func _trader(p: Dictionary, which: String, model_id: String, title: String, line: String) -> void:
	var frame := SpaceLayout.town_frame(p, which)
	var holder := Node3D.new()
	holder.transform = frame
	add_child(holder)
	var model := CreatureModel.new(model_id)
	holder.add_child(model)
	_folk.append({model = model, fixed = true})
	if which=="smith":
		# The forge: a stall behind the smith and a fire beside it.
		var at := frame.origin.normalized()
		PlanetProps.building(self, p, "planet/market_stall_red", PlanetProps.offset_dir(p, at, Vector2(0, -3.4)), at)
		PlanetProps.obstacle(self, p, "campfire", PlanetProps.offset_dir(p, at, Vector2(-3.2, -0.8)), 0.0, 1.2)
		var target := InteractionTarget.new()
		target.title = title
		target.description = line
		target.response = line
		target.action_text = "Sell items"
		target.reach = 4.0
		target.position = Vector3.UP
		holder.add_child(target)
		target.activated.connect(func(_actor: Node3D) -> void: get_tree().call_group("forge_panels", "open_for", target, holder))
	else:
		var shop := SpaceInteraction.new()
		shop.world = world
		shop.kind = "wright"
		shop.part = str(p.id)
		shop.title = title
		shop.description = line
		shop.position = Vector3.UP
		holder.add_child(shop)

func _place(model: Node3D, at: Vector2, yaw: float) -> void:
	var dir := PlanetProps.offset_dir(planet, center, at)
	var frame := SpaceLayout.ground_frame(planet, dir, yaw)
	model.transform = frame

func _process(delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera==null or planet.is_empty(): return
	if camera.global_position.distance_to(global_transform*(center*float(planet.radius)))>300.0: return
	# Townsfolk stroll between spots round the middle.
	for folk: Dictionary in _folk:
		var model: CreatureModel = folk.model
		if folk.get("fixed", false):
			model.animate(0.0, delta)
			continue
		folk.wait = float(folk.wait)-delta
		var at: Vector2 = folk.at
		var goal: Vector2 = folk.goal
		if at.distance_to(goal)<0.3:
			model.animate(0.0, delta)
			if float(folk.wait)<=0.0:
				folk.goal = Vector2.from_angle(_rng.randf()*TAU)*_rng.randf_range(3.0, _roam)
				folk.wait = _rng.randf_range(2.0, 6.0)
			continue
		var step := (goal-at).normalized()*1.4*delta
		folk.at = at+step
		_place(model, folk.at, atan2(-step.x, -step.y))
		model.animate(1.0, delta)
