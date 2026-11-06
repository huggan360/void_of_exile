class_name TheoryRoundDetails
extends RefCounted
## Real round conduit, split clamps, ceiling hangers and hex fasteners.
static var _meshes := {}
static var _material: ShaderMaterial

static func mesh(kind: String) -> Mesh:
	if _meshes.has(kind): return _meshes[kind]
	var result: Mesh
	if kind=="block":
		var box := BoxMesh.new()
		box.size = Vector3.ONE
		result = box
	elif kind=="ring":
		var ring := TorusMesh.new()
		ring.inner_radius = 0.37
		ring.outer_radius = 0.5
		ring.rings = 16
		ring.ring_segments = 8
		result = ring
	else:
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = 0.5
		cylinder.bottom_radius = 0.5
		cylinder.height = 1.0
		cylinder.radial_segments = 6 if kind=="bolt" else 12
		cylinder.rings = 1
		result = cylinder
	_meshes[kind] = result
	return result

static func metal() -> ShaderMaterial:
	if _material==null:
		_material = ShaderMaterial.new()
		_material.shader = preload("res://shaders/theory_metal.gdshader")
	return _material

static func attach_fittings(owner: Node3D,details: Array) -> void:
	for kind: String in ["block","cylinder","ring","bolt"]:
		var transforms: Array[Transform3D] = []
		var colors: Array[Color] = []
		for detail: Dictionary in details:
			if detail.kind==kind:
				transforms.append(detail.frame)
				colors.append(detail.color)
		batch(owner,"Service_"+kind,mesh(kind),transforms,colors)

static func along(a: Vector3,b: Vector3,radius: float) -> Transform3D:
	var axis := b-a
	if axis.is_zero_approx(): return Transform3D(Basis.from_scale(Vector3.ONE*0.001),a)
	return Transform3D(Basis(Quaternion(Vector3.UP,axis.normalized())).scaled_local(Vector3(radius*2,axis.length(),radius*2)),(a+b)*0.5)

static func attach(owner: Node3D,pipes: Array) -> void:
	var cylinders: Array[Transform3D] = []
	var colors: Array[Color] = []
	var clamps: Array[Transform3D] = []
	var bolts: Array[Transform3D] = []
	var bay := str(owner.name).trim_prefix("aurora_").trim_prefix("wreck_").is_valid_int()
	for pipe: Dictionary in pipes:
		var a: Vector3 = pipe.a
		var b: Vector3 = pipe.b
		var radius := float(pipe.radius)
		cylinders.append(along(a,b,radius))
		colors.append(pipe.color)
		var axis := (b-a).normalized()
		var rotation := Basis(Quaternion(Vector3.UP,axis))
		var count := maxi(1,ceili(a.distance_to(b)/1.8))
		for i in count+1:
			var at := a.lerp(b,float(i)/count)
			clamps.append(Transform3D(rotation.scaled_local(Vector3.ONE*radius*2.55),at))
			if bay and absf(a.y-b.y)<0.01 and ((at.y>6 and at.y<7.4) or (at.y>14 and at.y<17.2)) and i%2==0:
				var ceiling := 17.2 if at.y>10 else 7.4
				cylinders.append(along(at+Vector3.UP*radius,Vector3(at.x,ceiling-0.05,at.z),0.035))
				colors.append(TheoryArt.TRIM)
				bolts.append(Transform3D(Basis.from_scale(Vector3(0.25,0.045,0.25)),Vector3(at.x,ceiling-0.025,at.z)))
	batch(owner,"Conduits",mesh("cylinder"),cylinders,colors)
	batch(owner,"ConduitClamps",mesh("ring"),clamps,[],TheoryArt.TRIM)
	batch(owner,"MountingBolts",mesh("bolt"),bolts,[],TheoryArt.STEEL)

static func batch(owner: Node3D,label: String,shape: Mesh,transforms: Array[Transform3D],colors: Array[Color] = [],fallback := Color.WHITE) -> MultiMeshInstance3D:
	if transforms.is_empty(): return null
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = true
	multi.mesh = shape
	multi.instance_count = transforms.size()
	for i in transforms.size():
		multi.set_instance_transform(i,transforms[i])
		multi.set_instance_color(i,colors[i] if not colors.is_empty() else fallback)
	var instance := MultiMeshInstance3D.new()
	instance.name = label
	instance.multimesh = multi
	instance.material_override = metal()
	instance.visibility_range_end = 110
	owner.add_child(instance)
	return instance
