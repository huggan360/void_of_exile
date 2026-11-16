extends Node3D
## Fine voxel props and batched wooden details. Layout owns all collision.

const WOOD := Color("967049")
const PALE_WOOD := Color("c2a277")
const STRAW := Color("dfbb65")
var _boxes := {}
var _world: PetYardWorld


func build(world: PetYardWorld) -> void:
	_world = world
	var body := StaticBody3D.new()
	body.collision_layer = Player.OBSTACLE_LAYER
	body.collision_mask = 0
	add_child(body)
	for entry: Array in world.furnishing_layout():
		if entry[0] == "portal": continue
		var shape := BoxShape3D.new()
		shape.size = entry[2]
		var collider := CollisionShape3D.new()
		collider.shape = shape
		collider.position = entry[1] + Vector3.UP * shape.size.y * 0.5
		body.add_child(collider)
	if not pet_prop(["caretaker_cottage"], PetYardWorld.COTTAGE_POS, PI, 1.6):
		_prop("res://props/home/rose_cottage", PetYardWorld.COTTAGE_POS, PI)
	if not pet_prop(["hatching_nest", "nest"], PetYardWorld.NEST_POS, 0.0, 1.25): _nest(PetYardWorld.NEST_POS)
	for at: Vector3 in PetYardWorld.TREES:
		_prop("res://props/home/blossom_tree" if at.x < 0 else "res://props/home/orchard_tree", at)
	for at: Vector3 in PetYardWorld.LANTERNS:
		if not pet_prop(["lantern_post"], at, 0.0, 1.35): _prop("res://props/home/lantern", at)
		world._add_light(at + Vector3(0, 3, 0), Color("ffcf85"), 1.1, 8.0)
	_fence()
	_bridge()
	for at in [Vector3(-8, 0, 8), Vector3(-10, 0, 8), Vector3(7, 0, -2)]:
		if not pet_prop(["food_bowl", "bowl"], at): _bowl(at)
	for at in [Vector3(-9, 0, 2), Vector3(4, 0, 13)]:
		if not pet_prop(["toy_ball", "ball"], at): _ball(at)
	pet_prop(["egg_crate"], Vector3(-11, 0, -9))
	var water := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = PetYardWorld.POND.size
	water.mesh = plane
	water.position = Vector3(13, -0.3, 8)
	water.material_override = SurfaceWater.sea_material()
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(water)
	_flush()


## Support either art-session format, keeping the prefab's own palette.
func pet_prop(names: Array, at: Vector3, yaw := 0.0, size := 1.0) -> bool:
	for id: String in names:
		var folder := "res://props/pets/" + id
		if FileAccess.file_exists(folder + "/rig.json"):
			_prop(folder, at, yaw, size)
			return true
		var path := "res://obstacles/pets/" + id + ".vox"
		if FileAccess.file_exists(path):
			_obstacle("pets/" + id, at, yaw, size)
			return true
	return false


func _prop(folder: String, at: Vector3, yaw := 0.0, size := 1.0) -> void:
	var prop := VillageHouse.new().setup({asset = folder, pos = at, yaw = yaw, scale = size, solid_size = Vector3.ZERO})
	add_child(prop)


func _obstacle(id: String, at: Vector3, yaw := 0.0, size := 1.0) -> void:
	var prefab := ObstacleLibrary.get_prefab(id)
	var palette := BiomeDef.new()
	palette.id = -731
	palette.obstacle_colors = PackedColorArray()
	var meshes := prefab.meshes_for(palette)
	var holder := Node3D.new()
	holder.position = at
	holder.rotation.y = yaw
	holder.scale = Vector3.ONE * size
	add_child(holder)
	for i in 2:
		if meshes[i] == null: continue
		var mesh := MeshInstance3D.new()
		mesh.mesh = meshes[i]
		mesh.position = prefab.mesh_offset()
		mesh.scale = Vector3.ONE * prefab.voxel_size
		mesh.material_override = VoxModel.material() if i == 0 else VoxModel.glow_material()
		holder.add_child(mesh)


func _fence() -> void:
	var fence := PetYardWorld.FENCE
	for side in [-1.0, 1.0]:
		var art := false
		for i in 22:
			var offset := -fence + (i + 0.5) * fence * 2.0 / 22.0
			art = pet_prop(["pet_fence", "fence"], Vector3(offset, 0, side * fence))
			if side < 0 or not _in_gate(offset): pet_prop(["pet_fence", "fence"], Vector3(side * fence, 0, offset), PI * 0.5)
		# The existing fallback uses squared timber posts and rails.
		if not art:
			for step in range(-26, 27, 2):
				if side < 0 or not (_in_gate(step) or _in_gate(step + 2)): _fence_segment(Vector3(side * fence, 0, step), true, step < 26)
				_fence_segment(Vector3(step, 0, side * fence), false, step < 26)
	# A timber arch over the gate onto the trail.
	for z in [PetYardWorld.GATE_Z - PetYardWorld.GATE_HALF, PetYardWorld.GATE_Z + PetYardWorld.GATE_HALF]:
		_box(Vector3(fence, 1.5, z), Vector3(0.36, 3.0, 0.36), WOOD)
		_box(Vector3(fence, 3.05, z), Vector3(0.46, 0.14, 0.46), PALE_WOOD)
	_box(Vector3(fence, 2.75, PetYardWorld.GATE_Z), Vector3(0.3, 0.26, PetYardWorld.GATE_HALF * 2.0 + 0.8), PALE_WOOD)
	_box(Vector3(fence, 2.45, PetYardWorld.GATE_Z), Vector3(0.18, 0.14, PetYardWorld.GATE_HALF * 2.0), WOOD)


## A fence piece centred at `offset` along the east side would block the gate.
func _in_gate(offset: float) -> bool:
	return absf(offset - PetYardWorld.GATE_Z) < PetYardWorld.GATE_HALF


func _fence_segment(at: Vector3, along_z: bool, rails: bool) -> void:
	_box(at + Vector3(0, 0.75, 0), Vector3(0.3, 1.5, 0.3), WOOD)
	_box(at + Vector3(0, 1.55, 0), Vector3(0.38, 0.12, 0.38), PALE_WOOD)
	if rails:
		for y in [0.5, 1.15]:
			_box(at + Vector3(0, y, 1) if along_z else at + Vector3(1, y, 0),
					Vector3(0.16, 0.18, 2) if along_z else Vector3(2, 0.18, 0.16), PALE_WOOD)


func _bridge() -> void:
	# The walkable planks are terrain; quarter-block rails frame both sides.
	for z in [6.8, 9.2]:
		for x in range(7, 20, 2):
			_box(Vector3(x, 0.55, z), Vector3(0.22, 1.1, 0.22), WOOD)
		_box(Vector3(13, 0.9, z), Vector3(12.3, 0.18, 0.18), PALE_WOOD)


func _nest(at: Vector3) -> void:
	# Straw is small squared bundles, matching the voxel furniture style.
	for i in 32:
		var angle := TAU * i / 32.0
		var offset := Vector3(cos(angle), 0, sin(angle))
		for layer in 3:
			_box(at + offset * (1.25 + layer * 0.1) + Vector3.UP * (0.15 + layer * 0.16),
					Vector3(0.65, 0.16, 0.4), STRAW.darkened(0.08 * (i % 3)))
	_box(at + Vector3(0, 0.12, 0), Vector3(2.3, 0.24, 2.3), Color("927444"))


func _bowl(at: Vector3) -> void:
	_box(at + Vector3.UP * 0.12, Vector3(0.7, 0.24, 0.7), Color("ab6951"))
	_box(at + Vector3.UP * 0.25, Vector3(0.5, 0.06, 0.5), Color("d6b66d"))
	for x in [-0.35, 0.35]:
		_box(at + Vector3(x, 0.28, 0), Vector3(0.12, 0.14, 0.72), Color("e4c6a0"))
	for z in [-0.35, 0.35]:
		_box(at + Vector3(0, 0.28, z), Vector3(0.72, 0.14, 0.12), Color("e4c6a0"))


func _ball(at: Vector3) -> void:
	_box(at + Vector3.UP * 0.35, Vector3(0.6, 0.7, 0.6), Color("dd8a76"))
	_box(at + Vector3.UP * 0.35, Vector3(0.72, 0.3, 0.62), Color("f2d686"))


func _box(at: Vector3, size: Vector3, color: Color) -> void:
	if not _boxes.has(color): _boxes[color] = []
	_boxes[color].append(Transform3D(Basis.from_scale(size), at))


func _flush() -> void:
	for color: Color in _boxes:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		mat.roughness = 0.95
		var cube := BoxMesh.new()
		cube.size = Vector3.ONE
		cube.material = mat
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.mesh = cube
		multi.instance_count = _boxes[color].size()
		for i in multi.instance_count: multi.set_instance_transform(i, _boxes[color][i])
		var batch := MultiMeshInstance3D.new()
		batch.multimesh = multi
		add_child(batch)
	_boxes.clear()
