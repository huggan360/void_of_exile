class_name LeisureProps
extends RefCounted
## Shared low-poly pixel props for first person, other players and tabletops.
static var _materials := {}
static func material(color: Color, glow := 0.0) -> StandardMaterial3D:
	var key := str(color)+str(glow)
	if not _materials.has(key):
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		mat.roughness = 0.7
		if glow>0.0:
			mat.emission_enabled = true
			mat.emission = color
			mat.emission_energy_multiplier = glow
		_materials[key] = mat
	return _materials[key]

static func box(parent: Node3D, at: Vector3, size: Vector3, color: Color, glow := 0.0) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var shape := BoxMesh.new()
	shape.size = size
	mesh.mesh = shape
	mesh.material_override = material(color, glow)
	mesh.position = at
	parent.add_child(mesh)
	return mesh

static func cup(kind: String) -> Node3D:
	var root := Node3D.new()
	root.name = "HeldCup"
	root.set_meta("kind", kind)
	var pottery := Color("d9c6a0") if kind=="coffee" else Color("9ac0bb")
	# An open, faceted mug: real walls and rim instead of a solid cylinder.
	for side in 8:
		var angle := TAU*side/8.0
		var panel := box(root, Vector3(sin(angle)*0.108, 0.155, cos(angle)*0.108), Vector3(0.09, 0.27, 0.018), pottery.lightened((side%3)*0.035))
		panel.rotation.y = angle
		var rim := box(root, Vector3(sin(angle)*0.109, 0.3, cos(angle)*0.109), Vector3(0.095, 0.025, 0.025), Color("f1e3c2"))
		rim.rotation.y = angle
	box(root, Vector3(0, 0.025, 0), Vector3(0.19, 0.035, 0.19), pottery)
	for y: float in [0.09, 0.23]: box(root, Vector3(0.155, y, 0), Vector3(0.11, 0.035, 0.055), pottery)
	box(root, Vector3(0.2, 0.16, 0), Vector3(0.035, 0.16, 0.055), pottery)
	var liquid := MeshInstance3D.new()
	var surface := CylinderMesh.new()
	surface.top_radius = 0.096
	surface.bottom_radius = 0.096
	surface.height = 0.014
	surface.radial_segments = 8
	liquid.mesh = surface
	liquid.name = "Liquid"
	liquid.material_override = material(Color("4b291b") if kind=="coffee" else Color("c68735"))
	root.add_child(liquid)
	if kind=="beer":
		var foam := box(root, Vector3(0, 0.28, 0), Vector3(0.16, 0.025, 0.16), Color("fff0d0"))
		foam.name = "Foam"
	fill(root, 4)
	return root

static func fill(cup_node: Node3D, sips: int) -> void:
	var liquid := cup_node.get_node_or_null("Liquid") as Node3D
	if liquid:
		liquid.visible = sips>0
		liquid.position.y = 0.045+0.235*clampf(sips/4.0, 0.0, 1.0)
	var foam := cup_node.get_node_or_null("Foam") as Node3D
	if foam:
		foam.visible = sips>0
		foam.position.y = liquid.position.y+0.012

static func cigar() -> Node3D:
	var root := Node3D.new()
	root.name = "HeldCigar"
	box(root, Vector3(0, 0, -0.07), Vector3(0.035, 0.035, 0.18), Color("74472c"))
	box(root, Vector3(0, 0, -0.15), Vector3(0.037, 0.037, 0.035), Color("e87838"), 1.4)
	box(root, Vector3(0, 0, -0.05), Vector3(0.038, 0.038, 0.025), Color("d9b862"))
	return root

static func drop(parent: Node3D, at: Vector3, kind: String, basis := Basis.IDENTITY) -> void:
	var body := RigidBody3D.new()
	body.collision_layer = 0
	body.collision_mask = Player.TERRAIN_LAYER | Player.OBSTACLE_LAYER
	body.mass = 0.15
	body.gravity_scale = 0.0
	body.constant_force = -basis.y*body.mass*18.0
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.11
	capsule.height = 0.3
	shape.shape = capsule
	shape.position.y = 0.15
	body.add_child(shape)
	var prop := cup(kind)
	fill(prop, 0)
	body.add_child(prop)
	parent.add_child(body)
	body.global_transform = Transform3D(basis, at)
	body.linear_velocity = basis*Vector3(0.3, 0.0, -0.45)
	body.angular_velocity = Vector3(1.5, 0.7, 0.0)
	parent.get_tree().create_timer(1.8).timeout.connect(body.queue_free)
