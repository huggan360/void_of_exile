extends Node3D
## The Pet Yard island's look on clients: the enclosed walk-in Pet Store,
## the woods, bushes and rocks, grass and flowers in
## 24 m chunks (SurfaceFlora's plants, leaning away from players and pets),
## lanterns along the trail and a signpost at the meadow's gate.

const CHUNK := 24.0
const STEP := 0.7  # metres between ground-cover samples
## Where each shop detail level shows (metres from the camera).
const RANGES: Array[Vector2] = [Vector2(0, 90), Vector2(90, 260), Vector2(260, 2000)]
const KEEP_CLEAR: Array[Vector3] = [Vector3(0, 0, 17), Vector3(0, 0, 23), Vector3(0, 0, -13),
		Vector3(-15, 0, -7), Vector3(-16, 0, -14)]  # spawn, portal, nest, Caretaker, cottage (x, z)
var _world: PetYardWorld
var _pushers := PackedVector4Array()
var _rng := RandomNumberGenerator.new()


func build(world: PetYardWorld) -> void:
	_world = world
	_rng.seed = 51877
	_pushers.resize(24)
	_shop()
	_trees()
	_ground_cover()
	_trail_lanterns()
	_gate_sign()


# --- The Pet Store ----------------------------------------------------------------------

func _shop() -> void:
	var xform := Transform3D(Basis(Vector3.UP, PetYardWorld.SHOP_YAW), PetYardWorld.SHOP_POS)
	_model("pet_store_house", xform)
	_model("pet_store_roof", xform)
	var body := StaticBody3D.new()
	body.collision_layer = Player.OBSTACLE_LAYER
	body.collision_mask = 0
	add_child(body)
	for solid: AABB in PetYardWorld.shop_solids(): _collider(body, solid)
	# The planked floor you walk on (the terrain lies a voxel lower inside).
	var floor_rect := PetYardWorld.SHOP_FLOOR
	_collider(body, AABB(Vector3(floor_rect.position.x, PetYardWorld.SHOP_POS.y - 0.25, floor_rect.position.y),
		Vector3(floor_rect.size.x, 0.25, floor_rect.size.y)))
	for at: Vector3 in [Vector3(-3, 2.6, -1.8), Vector3(3, 2.6, -1.8), Vector3(0, 2.6, 1.0)]:
		_light(xform * at, Color("ffd49a"), 1.1, 8.0)
	for at: Vector3 in [Vector3(-2.4, 1.9, -5.5), Vector3(2.4, 1.9, -5.5)]:
		_light(xform * at, Color("ffc070"), 0.9, 6.0)
	_light(xform * Vector3(5.75, 1.6, -2.9), Color("5ac8ec"), 0.8, 4.0)  # the fish tank


func _model(name: String, xform: Transform3D) -> void:
	var info := CityHouses.info(name)
	var lods: Array = info.get("lods", [])
	for k in lods.size():
		var lod: Dictionary = lods[k]
		var at := xform * Transform3D(Basis.from_scale(Vector3.ONE * float(lod.scale)), Vector3(lod.offset[0], lod.offset[1], lod.offset[2]))
		var meshes: Array = [[str(lod.mesh), false]]
		if lod.has("glow"): meshes.append([str(lod.glow), true])
		for entry: Array in meshes:
			var node := MeshInstance3D.new()
			node.mesh = load(str(entry[0]))
			node.transform = at
			node.material_override = VoxModel.glow_material() if entry[1] else VoxModel.material()
			node.visibility_range_begin = RANGES[k].x
			node.visibility_range_end = RANGES[k].y
			node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if k == 0 and not entry[1] else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(node)


func _collider(body: StaticBody3D, box: AABB) -> void:
	var shape := BoxShape3D.new()
	shape.size = box.size
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position = box.get_center()
	body.add_child(collider)


func _light(at: Vector3, color: Color, energy: float, reach: float) -> void:
	var lamp := OmniLight3D.new()
	lamp.position = at
	lamp.light_color = color
	lamp.light_energy = energy
	lamp.omni_range = reach
	add_child(lamp)


# --- Trees ------------------------------------------------------------------------------

func _tree_kind(x: float, z: float, forest: float, pick: float) -> String:
	var land := PetYardWorld.land_at(x, z)
	if land < 9.0: return "palm" if pick < 0.7 else "oak_round"
	if Vector2(x - PetYardWorld.HILL.x, z - PetYardWorld.HILL.y).length() < PetYardWorld.HILL.z:
		return ["fir", "fir_tall", "pine_tall", "fir", "birch"][int(pick * 5.0)]
	if forest > 0.6:
		return ["oak_tall", "oak_round", "maple", "birch", "oak_tall", "maple_red"][int(pick * 6.0)]
	return ["blossom", "maple_gold", "orchard_apple", "oak_round", "maple_red", "willow"][int(pick * 6.0)]


func _trees() -> void:
	var groups := {}
	var body := StaticBody3D.new()
	body.collision_layer = Player.OBSTACLE_LAYER
	body.collision_mask = 0
	add_child(body)
	var lo := PetYardWorld.GRID_MIN
	var hi := lo + PetYardWorld.GRID_SIZE
	for gz in range(lo.y, hi.y, 3):
		for gx in range(lo.x, hi.x, 3):
			var x := gx + 0.4 + SurfaceMap.hash01(gx, gz, 11) * 2.2
			var z := gz + 0.4 + SurfaceMap.hash01(gx, gz, 12) * 2.2
			var forest := PetYardWorld.forest_at(x, z)
			var chance := 0.04 + forest * forest * 0.7
			if SurfaceMap.hash01(gx, gz, 13) >= chance or not _open_ground(x, z, 3.2): continue
			if PetYardWorld.land_at(x, z) < 4.0: continue
			var kind := _tree_kind(x, z, forest, SurfaceMap.hash01(gx, gz, 14))
			var s := 0.8 + SurfaceMap.hash01(gx, gz, 15) * 0.45
			var at := Vector3(x, _world.ground_height(x, z) - 0.1, z)
			if not groups.has(kind): groups[kind] = []
			groups[kind].append(Transform3D(Basis(Vector3.UP, SurfaceMap.hash01(gx, gz, 16) * TAU).scaled(Vector3.ONE * s), at))
			var shape := CollisionShape3D.new()
			var trunk := CylinderShape3D.new()
			trunk.radius = (0.28 if kind in ["birch", "pine_tall", "palm"] else 0.45) * s
			trunk.height = 2.6
			shape.shape = trunk
			shape.position = at + Vector3.UP * 1.3
			body.add_child(shape)
	var biome := Biomes.get_biome(Biomes.WOODS)
	for kind: String in groups:
		var prefab := ObstacleLibrary.get_prefab("surface/" + kind)
		var meshes := prefab.meshes_for(biome)
		var local := Transform3D(Basis.from_scale(Vector3.ONE * prefab.voxel_size), prefab.mesh_offset())
		for i in 2:
			if meshes[i] == null: continue
			add_child(_multi(meshes[i], groups[kind], local, VoxModel.glow_material() if i == 1 else VoxModel.material(), 0.0, 120.0, i == 0))
		var far_local := Transform3D(Basis.from_scale(Vector3.ONE * prefab.voxel_size * 2.0), prefab.mesh_offset())
		add_child(_multi(prefab.lod_mesh_for(biome), groups[kind], far_local, VoxModel.material(), 114.0, 400.0, true))


func _multi(mesh: Mesh, transforms: Array, local: Transform3D, mat: Material, begin: float, end: float, shadow: bool) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = transforms.size()
	for j in transforms.size(): mm.set_instance_transform(j, transforms[j] * local)
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.visibility_range_begin = begin
	mmi.visibility_range_end = end
	mmi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	return mmi


## Off the meadow's furniture, the paths, the trail, the shop and its square.
func _open_ground(x: float, z: float, margin: float) -> bool:
	if absf(x) < PetYardWorld.FENCE + margin and absf(z) < PetYardWorld.FENCE + margin: return false
	if PetYardWorld.trail_at(x, z) > 0.02: return false
	if PetYardWorld._rect_distance(PetYardWorld.SHOP_FLAT, x, z) < margin: return false
	return true


# --- Ground cover -----------------------------------------------------------------------

func _ground_cover() -> void:
	var chunks := {}
	var lo := PetYardWorld.GRID_MIN
	var furniture: Array[AABB] = []
	for entry: Array in PetYardWorld.furnishing_layout():
		var size: Vector3 = entry[2]
		furniture.append(AABB(entry[1] - Vector3(size.x * 0.5 + 0.6, 0, size.z * 0.5 + 0.6), size + Vector3(1.2, 0, 1.2)))
	var nx := int(PetYardWorld.GRID_SIZE.x / STEP)
	var nz := int(PetYardWorld.GRID_SIZE.y / STEP)
	for j in nz:
		for i in nx:
			var x := lo.x + (i + SurfaceMap.hash01(i, j, 81)) * STEP
			var z := lo.y + (j + SurfaceMap.hash01(i, j, 82)) * STEP
			if PetYardWorld.land_at(x, z) < 0.6: continue
			var h := SurfaceMap.hash01(i, j, 83)
			var h2 := SurfaceMap.hash01(i, j, 84)
			var c := PetYardWorld.column(x, z)
			var pos := Vector3(x, c.x * 0.25, z)
			var yaw := h2 * TAU
			var tone := Color(0.9 + h2 * 0.2, 0.9 + h * 0.15, 0.9 + SurfaceMap.hash01(i, j, 85) * 0.15)
			var kind := ""
			var size := 0.85 + h2 * 0.4
			var meadow := PetYardWorld.in_meadow(x, z)
			if meadow:
				if _near_furniture(furniture, x, z) or _kept_clear(x, z): continue
				if PetYardWorld.in_pond(x, z):
					if h >= 0.025 or PetYardWorld.on_bridge(x, z) or not PetYardWorld.POND.grow(-0.8).has_point(Vector2(x, z)): continue
					kind = "vox:surface/fine_lilies"
					pos.y = -0.32
				elif _by_pond(x, z) and h < 0.45: kind = "vox:surface/fine_reeds"
			if kind == "":
				match c.y:
					SurfaceBlocks.MEADOW:
						if h < 0.22: kind = _flower(h2)
						elif h < 0.45: kind = "tall_grass"
						elif h < 0.9: kind = "tuft_%d" % (int(h2 * 3.0) % 3)
					SurfaceBlocks.GRASS_LUSH, SurfaceBlocks.GRASS:
						if h < 0.05: kind = _flower(h2)
						elif h < 0.13: kind = "clover"
						elif h < 0.26: kind = "tall_grass"
						elif h < 0.8: kind = "tuft_%d" % (int(h2 * 3.0) % 3)
					SurfaceBlocks.FOREST_FLOOR:
						if h < 0.22: kind = "fern"
						elif h < 0.24: kind = "vox:surface/fine_mushrooms"
						elif h < 0.26: kind = "vox:surface/fine_stone_a"
						elif h < 0.5: kind = "tuft_%d" % (int(h2 * 3.0) % 3)
						elif h < 0.62: kind = "tall_grass"
						tone = tone.darkened(0.12)
					SurfaceBlocks.SAND_FINE:
						if h < 0.035: kind = "dry_grass"
						elif h < 0.045: kind = "vox:surface/fine_stone_sand"
					SurfaceBlocks.MOSS_ROCK:
						if h < 0.2: kind = "tuft_1"
					SurfaceBlocks.DIRT_PATH, SurfaceBlocks.GRAVEL_FINE:
						if not meadow and h < 0.05 and PetYardWorld.trail_at(x, z) < 0.75: kind = "tuft_%d" % (int(h2 * 3.0) % 3)
			if kind == "": continue
			_put(chunks, kind, pos, yaw, size, tone if not kind.begins_with("vox:") and not kind.begins_with("flower") else Color.WHITE)
	_bushes(chunks)
	for key: Vector2i in chunks:
		var root := Node3D.new()
		root.name = "Plants_%d_%d" % [key.x, key.y]
		add_child(root)
		SurfaceFlora.build(root, chunks[key])


## Bushes, rocks, logs and stumps on a coarser grid, and a hedge of bushes
## outside the meadow's fence.
func _bushes(chunks: Dictionary) -> void:
	var lo := PetYardWorld.GRID_MIN
	var hi := lo + PetYardWorld.GRID_SIZE
	for gz in range(lo.y, hi.y, 2):
		for gx in range(lo.x, hi.x, 2):
			var x := gx + 0.3 + SurfaceMap.hash01(gx, gz, 92) * 1.4
			var z := gz + 0.3 + SurfaceMap.hash01(gx, gz, 93) * 1.4
			if not _open_ground(x, z, 1.4) or PetYardWorld.land_at(x, z) < 2.0: continue
			var forest := PetYardWorld.forest_at(x, z)
			var fence := maxf(absf(x), absf(z)) < PetYardWorld.FENCE + 4.0 and absf(z - PetYardWorld.GATE_Z) > 5.0
			var chance := 0.35 if fence else 0.03 + forest * 0.12
			var h := SurfaceMap.hash01(gx, gz, 91)
			if h >= chance: continue
			var pick := SurfaceMap.hash01(gx, gz, 94)
			var kind := "vox:surface/bush_green"
			if PetYardWorld.land_at(x, z) < 7.0: kind = "vox:surface/bush_dry" if pick < 0.6 else "vox:surface/rock_sand"
			elif fence: kind = ["vox:surface/bush_green", "vox:surface/bush_flower", "vox:surface/bush_berry"][int(pick * 3.0)]
			elif forest > 0.55 and pick < 0.12: kind = "vox:surface/log"
			elif forest > 0.55 and pick < 0.2: kind = "vox:surface/stump"
			elif pick < 0.28: kind = "vox:surface/rock_mossy"
			elif pick < 0.55: kind = "vox:surface/bush_green"
			elif pick < 0.8: kind = "vox:surface/bush_berry"
			else: kind = "vox:surface/bush_flower"
			var at := Vector3(x, _world.ground_height(x, z) - 0.05, z)
			_put(chunks, kind, at, SurfaceMap.hash01(gx, gz, 95) * TAU, 0.75 + SurfaceMap.hash01(gx, gz, 96) * 0.5, Color.WHITE)


func _near_furniture(furniture: Array[AABB], x: float, z: float) -> bool:
	for box in furniture:
		if x > box.position.x and x < box.end.x and z > box.position.z and z < box.end.z: return true
	return PetYardWorld.path_at(x, z) or PetYardWorld.on_bridge(x, z)


func _kept_clear(x: float, z: float) -> bool:
	for p: Vector3 in KEEP_CLEAR:
		if Vector2(p.x - x, p.z - z).length() < 3.2: return true
	return false


func _by_pond(x: float, z: float) -> bool:
	return PetYardWorld.POND.grow(0.9).has_point(Vector2(x, z)) and not PetYardWorld.BRIDGE.grow(0.6).has_point(Vector2(x, z))


static func _flower(h: float) -> String:
	return ["flower_yellow", "flower_white", "flower_pink", "flower_blue", "flower_red", "flower_purple"][int(h * 6.0) % 6]


func _put(chunks: Dictionary, kind: String, pos: Vector3, yaw: float, size: float, tint: Color) -> void:
	var key := Vector2i(floori(pos.x / CHUNK), floori(pos.z / CHUNK))
	if not chunks.has(key): chunks[key] = {}
	var groups: Dictionary = chunks[key]
	if not groups.has(kind): groups[kind] = []
	groups[kind].append([pos, yaw, size, tint])


# --- Trail and gate ---------------------------------------------------------------------

func _trail_lanterns() -> void:
	var trail := PetYardWorld.TRAIL
	var walked := 0.0
	var next := 6.0
	var side := 1.0
	for i in trail.size() - 1:
		var a: Vector2 = trail[i]
		var b: Vector2 = trail[i + 1]
		var length := a.distance_to(b)
		while next <= walked + length:
			var t := (next - walked) / length
			var p := a.lerp(b, t)
			var across := (b - a).normalized().orthogonal() * 2.3 * side
			var at := Vector3(p.x + across.x, 0, p.y + across.y)
			at.y = _world.ground_height(at.x, at.z)
			_prop("res://props/pets/lantern_post", at, atan2(across.x, across.y))
			_light(at + Vector3.UP * 2.0, Color("ffcf85"), 0.9, 7.0)
			side = -side
			next += 9.0
		walked += length


func _gate_sign() -> void:
	var at := Vector3(PetYardWorld.FENCE + 2.0, 0, PetYardWorld.GATE_Z - PetYardWorld.GATE_HALF - 0.8)
	at.y = _world.ground_height(at.x, at.z)
	var post := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.22, 2.4, 0.22)
	post.mesh = mesh
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color("7a5636")
	wood.roughness = 0.95
	post.material_override = wood
	post.position = at + Vector3.UP * 1.2
	add_child(post)
	var sign := SignBoard.make("Pet Store", "plank", "", Color.TRANSPARENT, 0.55)
	sign.position = at + Vector3(0, 2.0, 0.14)
	sign.rotation.y = 0.0
	add_child(sign)


func _prop(folder: String, at: Vector3, yaw := 0.0, size := 1.0) -> void:
	add_child(VillageHouse.new().setup({asset = folder, pos = at, yaw = yaw, scale = size, solid_size = Vector3.ZERO}))


# --- Every frame ------------------------------------------------------------------------

func _process(_delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null: return
	var eye := camera.global_position
	var found: Array = []
	for node in get_tree().get_nodes_in_group("local_player") + get_tree().get_nodes_in_group("remote_players"):
		var body := node as Node3D
		if body == null or not body.is_visible_in_tree(): continue
		found.append([body.global_position, 0.75])
	for node in get_tree().get_nodes_in_group("pet_visuals"):
		var pet := node as Node3D
		if pet and pet.is_inside_tree() and pet.global_position.distance_squared_to(eye) < 3600.0: found.append([pet.global_position, 0.45])
	found.sort_custom(func(a: Array, b: Array) -> bool: return (a[0] as Vector3).distance_squared_to(eye) < (b[0] as Vector3).distance_squared_to(eye))
	for i in _pushers.size():
		var p: Vector3 = found[i][0] if i < found.size() else Vector3.ZERO
		_pushers[i] = Vector4(p.x, p.y, p.z, found[i][1]) if i < found.size() else Vector4.ZERO
	SurfaceFlora.set_pushers(_pushers)
