class_name TheorySoftDetails
extends Node3D
## Server-owned Verlet ropes and curtain panels. Clients interpolate compact
## point snapshots; local capsule projection keeps the cloth out of the camera.
const COLS := 9
const ROWS := 12
const SIDES := 8
var world: TheoryWorld
var objects: Array[Dictionary] = []
var _actors_before := {}
var _send_left := 0.0
var _cloth_clean: ShaderMaterial
var _cloth_torn: ShaderMaterial

func setup(place: TheoryWorld) -> void:
	world = place
	for spec: Dictionary in world.art.cables:
		if world.server_build: _rope(spec)
		else: world.queue_load_step(_rope.bind(spec))
	for spec: Dictionary in world.art.curtains:
		for half in 2:
			if world.server_build: _curtain(spec,half)
			else: world.queue_load_step(_curtain.bind(spec,half))

func _add(spec: Dictionary,points: PackedVector3Array,pins: PackedByteArray,kind: String) -> Dictionary:
	var obj := {id=objects.size(),frame=spec.frame,rest=points.duplicate(),points=points,old=points.duplicate(),pins=pins,
		kind=kind,edges=PackedInt32Array(),lengths=PackedFloat32Array(),strengths=PackedFloat32Array(),
		indices=PackedInt32Array(),uv=PackedVector2Array(),stamp=-1.0,previous_stamp=-1.0,
		from=points.duplicate(),target=points.duplicate(),node=null,awake=0.0,dirty=true}
	objects.append(obj)
	if not world.server_build and not Net.is_server():
		var node := MeshInstance3D.new()
		node.mesh = ArrayMesh.new()
		node.transform = spec.frame
		node.visibility_range_end = 65
		node.material_override = _fabric(bool(spec.get("torn",false))) if kind=="cloth" else TheoryRoundDetails.metal()
		add_child(node)
		obj.node = node
	return obj

func _edge(obj: Dictionary,a: int,b: int,strength := 1.0) -> void:
	obj.edges.append(a)
	obj.edges.append(b)
	obj.lengths.append((obj.rest[a] as Vector3).distance_to(obj.rest[b]))
	obj.strengths.append(strength)

func _rope(spec: Dictionary) -> void:
	var points := PackedVector3Array()
	var pins := PackedByteArray()
	var count := clampi(ceili((spec.end as Vector3).length()/0.3),5,20)
	for i in count+1:
		var t := float(i)/count
		points.append((spec.end as Vector3)*t+Vector3(0,-sin(PI*t)*0.12,sin(PI*t)*0.10))
		pins.append(1 if i==0 or (i==count and spec.pin_end) else 0)
	var obj := _add(spec,points,pins,"rope")
	obj.radius = spec.radius
	obj.floor = (8.0 if spec.frame.origin.y>9.0 else 0.0)-spec.frame.origin.y+0.06
	for i in count: _edge(obj,i,i+1)
	for i in count-1: _edge(obj,i,i+2,0.22)
	if obj.node!=null:
		var collars: Array[Transform3D] = [Transform3D(Basis.IDENTITY.scaled_local(Vector3.ONE*float(spec.radius)*3.5),Vector3.ZERO)]
		TheoryRoundDetails.batch(obj.node,"CableGrommet",TheoryRoundDetails.mesh("ring"),collars,[],TheoryArt.TRIM)
		_upload(obj,points)

func _curtain(spec: Dictionary,half: int) -> void:
	var points := PackedVector3Array()
	var pins := PackedByteArray()
	var left := -2.12 if half==0 else 0.0
	for row in ROWS:
		var t := float(row)/(ROWS-1)
		for column in COLS:
			var x := left+2.12*column/(COLS-1)
			var rag := (0.25+0.65*absf(sin(column*3.7+int(spec.seed)+half*4.3)))*pow(t,5.0) if spec.torn else 0.0
			points.append(Vector3(x,5.25-t*5.05+rag,sin(column*PI*0.9)*0.16))
			pins.append(1 if row==0 else 0)
	var obj := _add(spec,points,pins,"cloth")
	obj.floor = 0.08
	for row in ROWS:
		for column in COLS:
			var i := row*COLS+column
			obj.uv.append(Vector2(float(column)/(COLS-1),float(row)/(ROWS-1)))
			if column<COLS-1: _edge(obj,i,i+1)
			if row<ROWS-1: _edge(obj,i,i+COLS)
			if row<ROWS-1 and column<COLS-1:
				_edge(obj,i,i+COLS+1,0.7)
				_edge(obj,i+1,i+COLS,0.7)
				var torn_hole: bool = spec.torn and row>2 and absf(sin((row*31+column*17+int(spec.seed)+half*13)*2.73))>0.978
				if not torn_hole:
					obj.indices.append_array(PackedInt32Array([i,i+1,i+COLS]))
					if not (spec.torn and row>4 and absf(sin((row*19+column*11+int(spec.seed))*1.73))>0.96):
						obj.indices.append_array(PackedInt32Array([i+1,i+COLS+1,i+COLS]))
	if obj.node!=null:
		_upload(obj,points)
		var rings: Array[Transform3D] = []
		for column in COLS:
			var at: Vector3 = points[column]+Vector3.UP*0.11
			rings.append(Transform3D(Basis(Vector3.FORWARD,PI*0.5).scaled_local(Vector3.ONE*0.18),at))
		TheoryRoundDetails.batch(obj.node,"CurtainRings",TheoryRoundDetails.mesh("ring"),rings,[],TheoryArt.TRIM)
		if half==0:
			var rail: Array[Transform3D] = [TheoryRoundDetails.along(Vector3(-2.27,5.42,0),Vector3(2.27,5.42,0),0.065)]
			TheoryRoundDetails.batch(obj.node,"CurtainRail",TheoryRoundDetails.mesh("cylinder"),rail,[],TheoryArt.TRIM)
			var mounts: Array[Transform3D] = []
			for x in [-2.22,2.22]: mounts.append(TheoryRoundDetails.along(Vector3(x,5.42,0),Vector3(x,5.42,-0.27),0.11))
			TheoryRoundDetails.batch(obj.node,"RailBrackets",TheoryRoundDetails.mesh("bolt"),mounts,[],TheoryArt.STEEL)

func _fabric(torn: bool) -> ShaderMaterial:
	if torn and _cloth_torn!=null: return _cloth_torn
	if not torn and _cloth_clean!=null: return _cloth_clean
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/theory_fabric.gdshader")
	material.set_shader_parameter("torn",torn)
	if torn: _cloth_torn = material
	else: _cloth_clean = material
	return material

func _bodies() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var actors: Array = world.enemy_director.players.duplicate()
	if is_instance_valid(world.local_player): actors.append(world.local_player)
	for actor: Node3D in actors:
		if not is_instance_valid(actor) or actor.frozen: continue
		var position := actor.global_position
		var previous: Vector3 = _actors_before.get(actor.player_id,position)
		result.append({pos=position,previous=previous})
		_actors_before[actor.player_id] = position
	return result

func _physics_process(delta: float) -> void:
	if not is_instance_valid(world) or not world.is_presentation_ready() or Net.is_client(): return
	var bodies := _bodies()
	var active: Array[Dictionary] = []
	for obj in objects:
		var local_bodies: Array[Dictionary] = []
		var inverse: Transform3D = (obj.frame as Transform3D).affine_inverse()
		for body in bodies:
			var local: Vector3 = inverse*body.pos
			var low := float(obj.floor)-2.0
			var high := 6.5 if obj.kind=="cloth" else 2.0
			if local.y>=low and local.y<high and Vector2(local.x,local.z).length()<20.0:
				local_bodies.append({pos=local,previous=inverse*body.previous})
		if not local_bodies.is_empty(): obj.awake = 2.5
		else: obj.awake = maxf(0.0,float(obj.awake)-delta)
		if obj.awake<=0.0: continue
		_simulate(obj,local_bodies,minf(delta,1.0/30.0))
		active.append(obj)
	_send_left -= delta
	if Net.is_server() and _send_left<=0.0:
		_send_left = 0.10
		var instance := world.get_parent() as RealmInstance
		if instance==null: return
		var stamp := Net.now()
		for obj in active:
			var packet := encode(obj.points)
			for proxy: NetPlayerProxy in instance.proxies.values():
				if proxy.frozen or proxy.global_position.distance_to((obj.frame as Transform3D).origin)>65.0: continue
				Net.c_theory_detail.rpc_id(proxy.peer_id,world.realm_id,stamp,int(obj.id),packet)

func _simulate(obj: Dictionary,bodies: Array[Dictionary],delta: float) -> void:
	var points: PackedVector3Array = obj.points
	var old: PackedVector3Array = obj.old
	var rest: PackedVector3Array = obj.rest
	var pins: PackedByteArray = obj.pins
	var wind := Vector3(0,0,sin(Net.now()*1.1+int(obj.id))*0.10)
	for i in points.size():
		if pins[i]: continue
		var position := points[i]
		var velocity := (position-old[i])*0.975
		old[i] = position
		points[i] = position+velocity+(Vector3.DOWN*9.0+wind)*delta*delta
	var edges: PackedInt32Array = obj.edges
	var lengths: PackedFloat32Array = obj.lengths
	var stiffness: PackedFloat32Array = obj.strengths
	for iteration in 5:
		for edge in lengths.size():
			var a := edges[edge*2]
			var b := edges[edge*2+1]
			var offset := points[b]-points[a]
			var distance := offset.length()
			var total := 2-int(pins[a])-int(pins[b])
			if distance<0.0001 or total==0: continue
			var correction := offset*(1.0-lengths[edge]/distance)*stiffness[edge]/total
			if not pins[a]: points[a] += correction
			if not pins[b]: points[b] -= correction
		for i in points.size():
			if pins[i]:
				points[i] = rest[i]
				continue
			points[i] = _project_body(points[i],old[i],bodies)
			points[i].y = maxf(float(obj.floor),points[i].y)
			if obj.kind=="cloth":
				# Keep fabric inside the doorway jambs while it swings through
				# the clear opening on either side of the bulkhead.
				points[i].x = clampf(points[i].x,-2.14,2.14)
	obj.points = points
	obj.old = old
	obj.dirty = true

static func _project_body(point: Vector3,previous: Vector3,bodies: Array[Dictionary]) -> Vector3:
	for body in bodies:
		var feet: Vector3 = body.pos
		var closest := Vector3(feet.x,clampf(point.y,feet.y+0.2,feet.y+1.55),feet.z)
		var offset := point-closest
		if offset.length_squared()>=0.42: continue
		if offset.length_squared()<0.00001:
			offset = previous-(body.previous as Vector3)-Vector3.UP*0.9
			offset.y = 0
			if offset.is_zero_approx(): offset = Vector3.FORWARD
		point = closest+offset.normalized()*0.65
	return point

func _process(_delta: float) -> void:
	if world==null or world.server_build: return
	var camera := get_viewport().get_camera_3d()
	if camera==null: return
	for obj in objects:
		var node := obj.node as MeshInstance3D
		if node==null: continue
		node.visible = node.global_position.distance_squared_to(camera.global_position)<4225.0
		if not node.visible: continue
		var points: PackedVector3Array = obj.points
		if Net.is_client() and float(obj.stamp)>=0.0:
			var previous: PackedVector3Array = obj.from
			var target: PackedVector3Array = obj.target
			var alpha := clampf((Net.client.render_time()-float(obj.previous_stamp))/maxf(0.001,float(obj.stamp)-float(obj.previous_stamp)),0.0,1.0)
			var near_player := is_instance_valid(world.local_player) and node.global_position.distance_squared_to(world.local_player.global_position)<36.0
			if alpha>=1.0 and not obj.dirty and not near_player: continue
			points = PackedVector3Array()
			var local_bodies: Array[Dictionary] = []
			if is_instance_valid(world.local_player):
				var local: Vector3 = (obj.frame as Transform3D).affine_inverse()*world.local_player.global_position
				local_bodies.append({pos=local,previous=local})
			for i in target.size(): points.append(target[i] if obj.pins[i] else _project_body(previous[i].lerp(target[i],alpha),previous[i],local_bodies))
		elif not obj.dirty: continue
		_upload(obj,points)
		obj.dirty = false

func _upload(obj: Dictionary,points: PackedVector3Array) -> void:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices: PackedInt32Array = obj.indices
	var uv: PackedVector2Array = obj.uv
	if obj.kind=="rope":
		indices = PackedInt32Array()
		var previous_normal := Vector3.RIGHT
		for i in points.size():
			var tangent := (points[mini(i+1,points.size()-1)]-points[maxi(0,i-1)]).normalized()
			var normal := previous_normal.slide(tangent).normalized()
			if normal.length_squared()<0.1: normal = Vector3.FORWARD.slide(tangent).normalized()
			previous_normal = normal
			var other := tangent.cross(normal).normalized()
			for side in SIDES:
				var radial := normal*cos(TAU*side/SIDES)+other*sin(TAU*side/SIDES)
				vertices.append(points[i]+radial*float(obj.radius))
				normals.append(radial)
				if i<points.size()-1:
					var a := i*SIDES+side
					var b := i*SIDES+(side+1)%SIDES
					indices.append_array(PackedInt32Array([a,a+SIDES,b,b,a+SIDES,b+SIDES]))
	else:
		vertices = points
		normals.resize(points.size())
		for i in range(0,indices.size(),3):
			var a := indices[i]
			var b := indices[i+1]
			var c := indices[i+2]
			var normal := (points[c]-points[a]).cross(points[b]-points[a]).normalized()
			normals[a] += normal
			normals[b] += normal
			normals[c] += normal
		for i in normals.size(): normals[i] = normals[i].normalized()
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	if obj.kind=="cloth": arrays[Mesh.ARRAY_TEX_UV] = uv
	else:
		var colors := PackedColorArray()
		colors.resize(vertices.size())
		colors.fill(Color("635039"))
		arrays[Mesh.ARRAY_COLOR] = colors
	var mesh := (obj.node as MeshInstance3D).mesh as ArrayMesh
	mesh.clear_surfaces()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)

static func encode(points: PackedVector3Array) -> PackedByteArray:
	var packet := PackedByteArray()
	packet.resize(points.size()*6)
	for i in points.size():
		for axis in 3: packet.encode_s16(i*6+axis*2,clampi(roundi(points[i][axis]*1000),-32768,32767))
	return packet

func receive(id: int,stamp: float,packet: PackedByteArray) -> void:
	if id<0 or id>=objects.size(): return
	var obj := objects[id]
	if stamp<=float(obj.stamp) or packet.size()!=(obj.rest as PackedVector3Array).size()*6: return
	var target := PackedVector3Array()
	for i in packet.size()/6: target.append(Vector3(packet.decode_s16(i*6),packet.decode_s16(i*6+2),packet.decode_s16(i*6+4))*0.001)
	obj.from = obj.target
	obj.previous_stamp = float(obj.stamp) if float(obj.stamp)>=0.0 else stamp-0.1
	obj.target = target
	obj.stamp = stamp
	obj.dirty = true
