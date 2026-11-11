extends RefCounted
## Immutable, inexpensive top-down map geometry published while world art is built.
## The map snapshots these records, then paints them on a worker like the Tavern.
const GROUP := "space_map_geometry"
static var revision := 0

static func _record(records: Array, pose: Transform3D, kind: String, color: Color) -> void:
	var dimensions := pose.basis.get_scale()
	var area := dimensions.x*dimensions.z
	# Windows, chairs, railings and decals don't belong on the terrain map.
	if area<1.0 or (dimensions.y<2.5 and area<9.0): return
	records.append({pose=pose,kind=kind,color=Color(color,1.0)})

static func publish_brush(owner: Node3D, batches: Dictionary) -> void:
	var records: Array = []
	for kind: String in batches:
		for part: Array in batches[kind]: _record(records,part[0],kind,part[1])
	_publish(owner,records)

static func publish_packed(owner: Node3D, batches: Dictionary) -> void:
	var records: Array = []
	for key: String in batches:
		if key.begins_with("d:"): continue
		var kind := key.get_slice("@",0)
		if kind.begins_with("vox:"): continue
		var buffer: PackedFloat32Array = batches[key][1]
		for i in int(batches[key][0]):
			var at := i*20
			if buffer[at+18]>0.95: continue  # neon and window panes
			var basis := Basis(Vector3(buffer[at],buffer[at+4],buffer[at+8]),Vector3(buffer[at+1],buffer[at+5],buffer[at+9]),Vector3(buffer[at+2],buffer[at+6],buffer[at+10]))
			var pose := Transform3D(basis,Vector3(buffer[at+3],buffer[at+7],buffer[at+11]))
			_record(records,pose,kind,Color(buffer[at+12],buffer[at+13],buffer[at+14]))
	_publish(owner,records)

static func _publish(owner: Node3D, records: Array) -> void:
	if records.is_empty(): return
	var all: Array = owner.get_meta("map_geometry",[]).duplicate()
	all.append_array(records)
	var bounds: AABB = owner.get_meta("map_geometry_bounds",AABB())
	var first := not owner.has_meta("map_geometry_bounds")
	for record: Dictionary in records:
		var box: AABB = record.pose*AABB(-Vector3.ONE*0.5,Vector3.ONE)
		bounds = box if first else bounds.merge(box)
		first = false
	owner.set_meta("map_geometry",all)
	owner.set_meta("map_geometry_bounds",bounds)
	owner.add_to_group(GROUP)
	revision += 1

static func snapshot(source: Node3D, origin: Vector3, reach: float, up: Vector3) -> Array:
	var result: Array = []
	if not is_instance_valid(source) or not source.is_inside_tree(): return result
	for node in source.get_tree().get_nodes_in_group(GROUP):
		if not node is Node3D or not node.is_visible_in_tree(): continue
		if node!=source and not source.is_ancestor_of(node): continue
		var frame: Transform3D = node.global_transform
		var bounds: AABB = frame*(node.get_meta("map_geometry_bounds") as AABB)
		var offset := bounds.get_center()-origin
		var vertical := offset.dot(up)
		var extent := bounds.size.length()*0.5
		if (offset-up*vertical).length()>reach+extent or absf(vertical)>1000.0+extent: continue
		# Pure data only: projection and per-part filtering belong to the worker.
		result.append({frame=frame,records=(node.get_meta("map_geometry",[]) as Array).duplicate()})
	return result
