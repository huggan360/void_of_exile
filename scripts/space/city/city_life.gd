class_name CityLife
extends Node3D
## Authored citizens and two-way traffic follow the authority's clock. Only
## nearby citizens get rigs; vehicles share instanced meshes across the city.
var city: CityPlanet
var _people: Array[Dictionary] = []
var _districts := {}
var _traffic := {}
var _scan := 0.0
var _cups := {}
const CHAT := ["The sky garden is lovely tonight.", "Three moons and still late for work!", "Coffee first, galaxies later.", "Have you found the Hidden Valve?"]

func _ready() -> void:
	for lane: Dictionary in CityLayout.lanes():
		for k in int(lane.count):
			var id: String = lane.models[(k+int(lane.seed)) % lane.models.size()]
			if not _traffic.has(id): _traffic[id] = {entries = [], batches = []}
			_traffic[id].entries.append([lane, k])
	for id: String in _traffic:
		var entry: Dictionary = _traffic[id]
		var meshes := CityProps.vehicle_meshes(id)
		var offset := CityProps.center_offset(meshes[0])
		for part in 2:
			var data: Array = meshes[part]
			if data.is_empty(): continue
			var multi := MultiMesh.new()
			multi.transform_format = MultiMesh.TRANSFORM_3D
			multi.mesh = data[0]
			multi.instance_count = entry.entries.size()
			var node := MultiMeshInstance3D.new()
			node.multimesh = multi
			node.material_override = VoxModel.material() if part==0 else VoxModel.glow_material()
			node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(node)
			entry.batches.append([multi, float(meshes[2]), offset])

func add_district(d: Dictionary) -> void:
	if _districts.has(d.id): return
	_districts[d.id] = true
	for w: Dictionary in CityLayout.walkers(d):
		_people.append({walker = w, district = d, model = w.model, node = null, bubble = -1})
	for v: Dictionary in CityLayout.venues(d):
		var frame: Transform3D = v.frame
		frame.origin += CityLayout.planet().center as Vector3
		for staff: Dictionary in (v.staff if not v.has("shop") else []):  # shopkeepers are ShopKeepers
			_people.append({pose = frame*Transform3D(Basis(Vector3.UP, float(staff.yaw)), staff.pos), model = staff.model,
				node = null, bubble = -1, lines = staff.lines, title = v.name})
		for k: int in v.patrons:
			var s: Dictionary = v.seats[k]
			_people.append({pose = frame*Transform3D(Basis(Vector3.UP, float(s.yaw)), s.pos),
				model = CityLayout.FOLK[(k+absi(str(v.key).hash())) % CityLayout.FOLK.size()], seated = true, node = null, bubble = -1})
		for s: Dictionary in v.seats: _cup(str(s.id))
	for e: Dictionary in CityLayout.elevators():
		if e.district!=d.id: continue
		for s: Dictionary in CityLayout.tower_seats(e): _cup(str(s.id))

func _cup(id: String) -> void:
	var spec := CityLayout.any_seat(id)
	if spec.is_empty(): return
	var holder := Node3D.new()
	add_child(holder)
	var basis: Basis = spec.basis*Basis(Vector3.UP, float(spec.yaw))
	# The drink is on a small tray immediately in front of the seat.
	holder.global_transform = Transform3D(basis, spec.cup)
	var glass := MeshInstance3D.new()
	var shape := CylinderMesh.new()
	shape.top_radius = 0.105
	shape.bottom_radius = 0.085
	shape.height = 0.3
	shape.cap_top = false
	glass.mesh = shape
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.8, 0.93, 1.0, 0.25) if spec.drink=="beer" else Color("e8d8bf")
	if spec.drink=="beer": mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.roughness = 0.2
	glass.material_override = mat
	holder.add_child(glass)
	var liquid := MeshInstance3D.new()
	var inner := CylinderMesh.new()
	inner.top_radius = 0.095
	inner.bottom_radius = 0.077
	inner.height = 0.28
	liquid.mesh = inner
	var drink := ShaderMaterial.new()
	drink.shader = preload("res://shaders/beer_liquid.gdshader")
	drink.set_shader_parameter("height", 0.28)
	drink.set_shader_parameter("coffee", spec.drink=="coffee")
	liquid.material_override = drink
	holder.add_child(liquid)
	_cups[id] = {node = holder, material = drink}

func _process(delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera==null: return
	var eye := camera.global_position
	var t := CityState.clock()
	# Nothing animates on a planet outside the camera's neighbourhood.
	if eye.distance_to(CityLayout.planet().center)>CityLayout.radius()+2500.0:
		visible = false
		return
	visible = true
	_scan -= delta
	var scan := _scan<=0.0
	if scan: _scan = 0.3
	for entry: Dictionary in _people:
		var pose: Transform3D
		var moving := false
		if entry.has("walker"):
			var sample := CityLayout.walker_pose(entry.district, entry.walker, t)
			var up := ((sample[0] as Vector3)-(CityLayout.planet().center as Vector3)).normalized()
			pose = Transform3D(Basis.looking_at((sample[1] as Vector3).slide(up).normalized(), up), sample[0])
			moving = not bool(sample[2])
		else: pose = entry.pose
		if scan:
			var near := eye.distance_to(pose.origin)<85.0
			if near and not is_instance_valid(entry.node):
				var person := CreatureModel.new(str(entry.model))
				add_child(person)
				entry.node = person
				person.set_meta("city_actor", true)
				if entry.has("lines"):
					var talk := InteractionTarget.new()
					talk.title = str(entry.title)
					talk.description = str(entry.lines[0])
					talk.response = "Make yourself at home. The lifts lead to the sky gardens and bars."
					talk.position.y = 1.0
					person.add_child(talk)
			elif not near and is_instance_valid(entry.node):
				entry.node.queue_free()
				entry.node = null
		if not is_instance_valid(entry.node): continue
		var person: CreatureModel = entry.node
		person.global_transform = pose
		person._phase = fposmod(t*CreatureModel.STRIDE_SPEED, TAU)
		person._time = t
		person.animate(0.6 if moving else 0.0, delta)
		if entry.get("seated", false):
			for limb: Dictionary in person._moves:
				if limb.role=="leg": (limb.node as Node3D).rotation.x = -PI*0.45
		if scan and eye.distance_to(pose.origin)<16.0:
			var offset := absi(str(entry.model).hash()+int(pose.origin.x)) % 17
			var cycle := int((t+offset)/18.0)
			if cycle!=int(entry.bubble) and fposmod(t+offset, 18.0)<5.0:
				entry.bubble = cycle
				var lines: Array = entry.get("lines", CHAT)
				SpeechBubble.say(person, str(lines[cycle % lines.size()]), "say", 2.2)
	for id: String in _traffic:
		var entry: Dictionary = _traffic[id]
		for i in entry.entries.size():
			var pair: Array = entry.entries[i]
			var pose := CityLayout.vehicle_pose(pair[0], int(pair[1]), t)
			var up := ((pose[0] as Vector3)-(CityLayout.planet().center as Vector3)).normalized()
			var basis := Basis.looking_at((pose[1] as Vector3).slide(up).normalized(), up)
			for batch: Array in entry.batches:
				var scaled := basis.scaled(Vector3.ONE*float(batch[1]))
				(batch[0] as MultiMesh).set_instance_transform(i, global_transform.affine_inverse()*Transform3D(scaled, (pose[0] as Vector3)+scaled*(batch[2] as Vector3)))
	if scan:
		for id: String in _cups:
			var cup: Dictionary = _cups[id]
			var fill := 1.0 if CityState.npc_seat(id) else 0.0
			(cup.node as Node3D).visible = fill>0.0
			(cup.material as ShaderMaterial).set_shader_parameter("fill", fill*0.9)
