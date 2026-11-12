class_name PlanetFlora
extends Node3D
## A planet's trees, plants, stones and oddities: its own voxel models
## (tools/space/make_planet_models.py, "planet/...") with some of the realm's
## and the Surface's, recoloured for that world. They grow in groves and
## clearings (a slow noise), along the shores and reefs of its water, never
## deep in the water or on the levelled ground of pads, places and villages.
## Clients stream them in patches round the camera: near the crew each one
## shows its full model, further out a coarse copy (lod_band in
## voxel_model.gdshader), far patches are not built at all. The obstacles
## round the crew get the same collision as in the realm. Grass, flowers and
## pebbles are PlanetGroundCover's.
const PATCH_ARC := 220.0  # metres: obstacles are batched per patch this wide
const OBSTACLE_RANGE := 900.0
const NEAR := 130.0  # full models within this, coarse copies beyond
const STREAM_EVERY := 0.4
const BUILDS_PER_STEP := 2

## Per planet: weighted obstacles (inland), `shore` (within 2.5 m above the
## water) and `reef` (shallow water), one obstacle per `area` square metres,
## `clump` (0 even, 1 only in groves), size scale of the realm's obstacles,
## the voxel colour slots (stone, stone dark, foliage, wood, accent, foliage
## dark, glow), the water's shallow and deep colours, and the ground cover:
## `cover` [kind, weight, tint] picked for `density` of the samples, `bushes`
## (weights) on a coarser grid, `wet` plants at the water's edge.
const SETS := {
	verdance = {obstacles = {"planet/moss_oak": 5, "planet/moss_oak_gold": 1.2, "planet/glow_cap": 2, "planet/glow_cap_blue": 1, "planet/tree_fern": 2.5,
			"planet/firefly_bush": 3, "planet/mossy_boulder": 1.2, "tree_round": 1.2, "tree_tall": 0.8, "glowshroom": 1.2, "surface/log": 0.6, "surface/willow": 0.5},
		shore = {"surface/willow": 2, "planet/tree_fern": 1, "surface/fine_reeds": 2, "planet/mossy_boulder": 1},
		area = 380.0, clump = 0.75, scale = 1.6,
		colors = ["8a8676", "5f5c52", "4fae58", "7a5034", "f2d27a", "2f7a3e", "a8ffb0"], water = ["3fa89a", "0e4a4c"],
		density = 0.8, cover = [["tuft_0", 3, "ffffff"], ["tuft_1", 3, "ffffff"], ["tuft_2", 2, "ffffff"], ["tall_grass", 2.2, "f0fff0"],
			["clover", 1.4, "ffffff"], ["fern", 1.6, "ffffff"], ["flower_yellow", 0.35, "ffffff"], ["flower_white", 0.35, "ffffff"],
			["flower_blue", 0.3, "ffffff"], ["vox:planet/fine_glow_caps", 0.22, "ffffff"], ["vox:planet/fine_moss_stone", 0.12, "ffffff"],
			["vox:surface/fine_mushrooms", 0.08, "ffffff"]],
		bushes = {"planet/firefly_bush": 1, "surface/bush_green": 2, "surface/bush_berry": 1, "surface/stump": 0.3}, wet = ["vox:surface/fine_reeds", "vox:surface/fine_lilies"]},
	rosamund = {obstacles = {"planet/candy_tree": 3, "planet/candy_tree_mint": 1.5, "planet/candy_tree_lilac": 1.5, "planet/rose_crystal": 2.5,
			"planet/rose_bush": 2, "planet/giant_flower": 1.5, "planet/fairy_stone": 0.6, "crystal_cluster": 1.2, "tree_round": 0.8, "surface/blossom": 1.2},
		shore = {"planet/giant_flower": 2, "planet/rose_bush": 1, "surface/fine_reeds": 1},
		area = 420.0, clump = 0.6, scale = 1.5,
		colors = ["d9b8d0", "a07a98", "f29ac9", "8a5a6e", "8de0ff", "c25a96", "ffb8f0"], water = ["8fd8e8", "4a5aa8"],
		density = 0.75, cover = [["tuft_0", 2.5, "ffd8ec"], ["tuft_2", 2.5, "ffe4f2"], ["tall_grass", 1.6, "f4d2ff"], ["clover", 1.0, "ffe0f0"],
			["flower_pink", 1.5, "ffffff"], ["flower_white", 1.0, "ffffff"], ["flower_purple", 1.0, "ffffff"], ["lavender", 0.6, "ffffff"],
			["vox:planet/fine_petals", 1.0, "ffffff"], ["vox:planet/fine_pink_shards", 0.25, "ffffff"]],
		bushes = {"planet/rose_bush": 2, "surface/bush_flower": 1}, wet = ["vox:surface/fine_reeds", "vox:surface/fine_lilies"]},
	amberfall = {obstacles = {"planet/amber_spire": 1.5, "planet/date_palm": 1.6, "planet/barrel_cactus": 2.5, "planet/hoodoo": 1.2, "planet/honeycomb_rock": 1.2,
			"planet/dune_bush": 2, "cactus": 1.5, "palm": 0.8, "rock": 0.8, "pillar": 0.6, "ruin_wall": 0.3, "surface/saguaro": 1.2},
		shore = {"planet/date_palm": 3, "planet/dune_bush": 1, "surface/fine_reeds": 1},
		area = 700.0, clump = 0.5, scale = 1.5,
		colors = ["d8a868", "9a6a3a", "7fb84a", "8a5a2a", "ffcf6a", "5a8a32", "ffd27a"], water = ["f0b850", "8a4a10"],
		density = 0.22, cover = [["dry_grass", 3, "ffffff"], ["vox:planet/fine_sand_stone", 0.6, "ffffff"], ["vox:planet/fine_amber_shards", 0.4, "ffffff"],
			["vox:surface/fine_stone_sand", 0.4, "ffffff"]],
		bushes = {"planet/dune_bush": 2, "surface/bush_dry": 2}, wet = ["vox:surface/fine_reeds"]},
	tidewell = {obstacles = {"planet/sea_rock": 1, "surface/oak_round": 1.2, "tree_small": 1.2, "bush": 2, "palm": 1.5, "rock": 1, "lamppost": 0.2, "planet/conch": 0.5},
		shore = {"palm": 3, "planet/driftwood": 1.5, "planet/conch": 0.8, "planet/beach_grass": 2, "planet/sea_rock": 1.2},
		reef = {"planet/coral_pink": 2, "planet/coral_teal": 2, "planet/sea_rock": 0.6},
		area = 420.0, clump = 0.4, scale = 1.5,
		colors = ["e8d6a0", "b0a070", "3f9d6a", "8a6a48", "ffffff", "2a7a50", "a8f0ff"], water = ["3fc8d8", "0a3a7a"],
		density = 0.65, cover = [["tuft_0", 3, "ffffff"], ["tuft_1", 2, "ffffff"], ["tall_grass", 1.5, "ffffff"], ["flower_white", 0.5, "ffffff"],
			["flower_yellow", 0.4, "ffffff"], ["fern", 0.6, "ffffff"]],
		sand = [["vox:planet/fine_shells", 1.0, "ffffff"], ["vox:planet/fine_starfish", 0.4, "ffffff"], ["dry_grass", 1.2, "ffffff"]],
		bushes = {"surface/bush_green": 2, "planet/beach_grass": 1}, wet = ["vox:surface/fine_reeds"]},
	shardheart = {obstacles = {"planet/shard_spire": 4, "planet/shard_spire_pink": 2, "planet/geode": 2, "crystal_cluster": 3, "ice_spike": 1.5, "obelisk": 0.8, "rock": 1},
		area = 300.0, clump = 0.5, scale = 1.7,
		colors = ["3a5a6a", "22343e", "6af0c8", "34485c", "ff8ae0", "2a8a7a", "8afff0"], water = ["6af0c8", "1a3a4a"],
		density = 0.4, cover = [["vox:planet/fine_teal_shards", 2, "ffffff"], ["vox:decor_glow_sprouts", 1, "ffffff"], ["tuft_2", 2, "7ff0e0"],
			["vox:planet/fine_pink_shards", 0.5, "ffffff"]],
		bushes = {"surface/crystal_blue": 1}, wet = []},
	hollowmoon = {obstacles = {"planet/bone_tree": 3, "planet/ribcage": 0.5, "planet/ghost_lamp": 0.8, "planet/tombstones": 1.2, "planet/moon_rock": 2,
			"dead_tree": 2, "obelisk": 1, "boulder": 1, "ruin_wall": 0.8, "pillar": 0.8},
		shore = {"planet/ghost_lamp": 1, "planet/moon_rock": 1, "surface/fine_reeds": 1},
		area = 560.0, clump = 0.55, scale = 1.6,
		colors = ["9a9ea8", "5a5e68", "6a7a6a", "c8c4b0", "7dff6a", "3a4a3e", "7dff6a"], water = ["5aff8a", "0a2a1a"],
		density = 0.32, cover = [["vox:planet/fine_moon_pebbles", 2, "ffffff"], ["vox:planet/fine_bone_bits", 0.8, "ffffff"],
			["vox:planet/fine_ghost_sprouts", 1, "ffffff"], ["dry_grass", 2, "b8c4c0"]],
		bushes = {"surface/bush_dry": 1}, wet = ["vox:surface/fine_reeds"]},
	mawgrave = {obstacles = {"planet/fungal_stack": 3, "planet/spore_pod": 2.5, "planet/hive_mound": 1.2, "planet/tendrils": 2, "planet/shelf_tree": 1.5,
			"glowshroom": 2.5, "burnt_tree": 1, "crystal_cluster": 0.6, "boulder": 1},
		shore = {"planet/tendrils": 2, "planet/spore_pod": 1},
		area = 380.0, clump = 0.6, scale = 2.0,
		colors = ["5a3a6a", "2a1a32", "8a4aa0", "3a2230", "ff5fd2", "4a2a5a", "ff6ae0"], water = ["a04ad0", "1a0a2a"],
		density = 0.65, cover = [["vox:planet/fine_violet_tufts", 3, "ffffff"], ["vox:planet/fine_spore_caps", 1, "ffffff"],
			["tall_grass", 2, "c88cff"], ["tuft_0", 2, "b07ad8"]],
		bushes = {"surface/bush_blue": 1, "planet/spore_pod": 0.5}, wet = []},
	pale_eye = {obstacles = {"planet/obsidian_spire": 3, "planet/storm_rod": 0.6, "planet/storm_crystal": 1.5, "planet/charred_tree": 2, "planet/basalt": 2,
			"obelisk": 1.5, "ice_spike": 1, "boulder": 1.5, "pillar": 0.6},
		shore = {"planet/basalt": 2, "planet/obsidian_spire": 1},
		area = 640.0, clump = 0.6, scale = 2.0,
		colors = ["3a3e4e", "1c1f2b", "5a6478", "2a2a34", "ff4a5a", "2e3446", "9ab0ff"], water = ["5a6aa0", "080a18"],
		density = 0.24, cover = [["vox:planet/fine_obsidian", 2, "ffffff"], ["vox:planet/fine_storm_sparks", 0.8, "ffffff"], ["dry_grass", 2, "8a96b8"]],
		bushes = {"surface/bush_dry": 1}, wet = []},
}

static var _biomes := {}

## A BiomeDef only for the recoloured obstacle meshes of planet `p`.
static func biome_for(p: Dictionary) -> BiomeDef:
	if _biomes.has(p.id): return _biomes[p.id]
	var set: Dictionary = SETS[p.id]
	var c: Array = set.colors
	var biome := BiomeDef.new()
	biome.id = 900+SpaceLayout.PLANETS.find(p)
	biome.obstacle_colors = Biomes._colors(Color(c[0]), Color(c[1]), Color(c[2]), Color(c[3]), Color(c[4]), Color(c[5]), Color(c[6]))
	_biomes[p.id] = biome
	return biome

static var _placements := {}
static var _index := {}
const CELL := 40.0  # metres, obstacle index for landing checks
const BODY_CELL := 120.0  # metres, collision is built per cell near the crew
var _planet: Dictionary
var _bodies := {}  # cell -> StaticBody3D
var _by_cell := {}  # cell -> obstacle placements
var _patches := {}  # patch key -> {center (planet space), items}
var _built := {}  # patch key -> Node3D
var _stream_timer := 0.0

## Every obstacle of planet `p`, deterministic (the server uses the same list
## to keep landing sites clear and to gather packs): [{name, frame, size,
## decor, dir, spin}], frames in planet space at the centre's ground.
static func placements(p: Dictionary) -> Array:
	if _placements.has(p.id): return _placements[p.id]
	if not SETS.has(p.id):
		_placements[p.id] = []
		return []
	var set: Dictionary = SETS[p.id]
	var radius := float(p.radius)
	var water := SpaceLayout.water_level(p)
	var rng := RandomNumberGenerator.new()
	rng.seed = absi(String(p.id).hash())+31
	var groves := FastNoiseLite.new()
	groves.seed = absi(String(p.id).hash())+77
	groves.frequency = 1.0/110.0
	groves.fractal_octaves = 2
	var clump := float(set.get("clump", 0.5))
	var out: Array = []
	var count := mini(18000, int(4.0*PI*radius*radius/float(set.area)*(1.0+clump)))
	for i in count:
		var dir := _random_dir(rng)
		var roll := rng.randf()
		var pick := rng.randf()
		var grow := rng.randf()
		var spin := rng.randf()*TAU
		# Groves and clearings: dense where the slow noise is high, a few strays elsewhere.
		var grove := smoothstep(-0.3, 0.45, groves.get_noise_3dv(dir*radius))
		if roll>lerpf(1.0, grove*0.95+0.05, clump): continue
		if not _clear(p, dir, 9.0): continue
		var h := SpaceLayout.surface_height(p, dir)
		var weights: Dictionary = set.obstacles
		if not is_nan(water):
			if h<water-2.5: continue
			elif h<water-0.2:
				if not set.has("reef"): continue
				weights = set.reef
			elif h<water+2.5:
				weights = set.get("shore", set.obstacles)
		var name := _pick(weights, pick)
		var size := (float(set.scale)*lerpf(0.85, 1.25, grow)*(1.5 if grow>0.92 else 1.0)) if not "/" in name else lerpf(0.8, 1.25, grow)
		out.append({name = name, frame = _frame(dir, radius+h-0.12, spin), size = size, decor = false, dir = dir, spin = spin})
	_placements[p.id] = out
	return out

## Obstacles of `p` by 40 m cell of their planet-space position.
static func _obstacle_index(p: Dictionary) -> Dictionary:
	if _index.has(p.id): return _index[p.id]
	var index := {}
	for item: Dictionary in placements(p):
		if item.decor: continue
		var prefab := ObstacleLibrary.get_prefab(str(item.name))
		if prefab.is_fine(): continue
		var key := Vector3i(((item.frame as Transform3D).origin/CELL).floor())
		if not index.has(key): index[key] = []
		index[key].append([(item.frame as Transform3D).origin, maxf(prefab.footprint.x, prefab.footprint.y)*0.5*float(item.size)])
	_index[p.id] = index
	return index

## Whether any obstacle stands within `clearance` metres of planet-space `at`.
static func blocked(p: Dictionary, at: Vector3, clearance: float) -> bool:
	var index := _obstacle_index(p)
	var cell := Vector3i((at/CELL).floor())
	var reach := ceili(clearance/CELL)
	for dx in range(-reach, reach+1):
		for dy in range(-reach, reach+1):
			for dz in range(-reach, reach+1):
				for item: Array in index.get(cell+Vector3i(dx, dy, dz), []):
					if (item[0] as Vector3).distance_to(at)<clearance+float(item[1]): return true
	return false

func build(p: Dictionary) -> void:
	_planet = p
	for item: Dictionary in placements(p):
		var key := Vector3i(((item.dir as Vector3)*float(p.radius)/PATCH_ARC).round())
		if not _patches.has(key): _patches[key] = {center = Vector3.ZERO, items = []}
		_patches[key].items.append(item)
	for key: Vector3i in _patches:
		var patch: Dictionary = _patches[key]
		var sum := Vector3.ZERO
		for item: Dictionary in patch.items: sum += (item.frame as Transform3D).origin
		patch.center = sum/float(patch.items.size())
	_stream_timer = 0.0

func _process(delta: float) -> void:
	if _planet.is_empty(): return
	var camera := get_viewport().get_camera_3d()
	if camera==null: return
	RenderingServer.global_shader_parameter_set("lod_eye", camera.global_position)
	_stream_timer -= delta
	if _stream_timer>0.0: return
	_stream_timer = STREAM_EVERY
	var eye := global_transform.affine_inverse()*camera.global_position
	var reach := OBSTACLE_RANGE+PATCH_ARC
	var want: Array = []
	for key: Vector3i in _patches:
		var d := eye.distance_to(_patches[key].center)
		if d<reach: want.append([d, key])
		elif _built.has(key) and d>reach+120.0:
			_built[key].queue_free()
			_built.erase(key)
	want.sort_custom(func(a: Array, b: Array) -> bool: return a[0]<b[0])
	var made := 0
	for entry: Array in want:
		if _built.has(entry[1]): continue
		_built[entry[1]] = _build_patch(_patches[entry[1]])
		made += 1
		if made>=BUILDS_PER_STEP:
			_stream_timer = 0.0  # more to do next frame
			break

## One patch: per model a batch of full meshes (and glow) shown near the
## camera and a batch of coarse copies further out.
func _build_patch(patch: Dictionary) -> Node3D:
	var holder := Node3D.new()
	add_child(holder)
	var biome := biome_for(_planet)
	var groups := {}
	for item: Dictionary in patch.items:
		if not groups.has(item.name): groups[item.name] = []
		groups[item.name].append(_low_frame(item))
	for name: String in groups:
		var prefab := ObstacleLibrary.get_prefab(name)
		var list: Array = groups[name]
		var meshes := prefab.meshes_for(biome)
		var fine := prefab.is_fine()
		for slot in 2:
			if meshes[slot]==null: continue
			holder.add_child(_batch(meshes[slot], list, prefab, 1.0, VoxModel.glow_material() if slot==1 else VoxModel.material(),
				Vector2(0.0, 45.0 if fine else NEAR), (45.0 if fine else NEAR)+PATCH_ARC, slot==0 and not fine))
		if not fine:
			holder.add_child(_batch(prefab.lod_mesh_for(biome), list, prefab, 2.0, VoxModel.material(), Vector2(NEAR, 1e9), OBSTACLE_RANGE+PATCH_ARC*0.5, true))
	return holder

func _batch(mesh: Mesh, list: Array, prefab: ObstacleLibrary.Prefab, coarse: float, mat: Material, band: Vector2, end: float, shadow: bool) -> MultiMeshInstance3D:
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = mesh
	multi.instance_count = list.size()
	for k in list.size():
		var entry: Array = list[k]
		var size: float = entry[1]
		multi.set_instance_transform(k, (entry[0] as Transform3D)*Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*prefab.voxel_size*coarse*size), prefab.mesh_offset()*size))
	var node := MultiMeshInstance3D.new()
	node.multimesh = multi
	node.material_override = mat
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	node.set_instance_shader_parameter("lod_band", band)
	node.visibility_range_end = end
	node.visibility_range_end_margin = 60.0
	return node

## [frame lowered to the lowest ground under the model, size]: on a slope or
## the curve of the world no side of it floats (computed once, clients only).
func _low_frame(item: Dictionary) -> Array:
	if not item.has("low"):
		var prefab := ObstacleLibrary.get_prefab(str(item.name))
		var half := maxf(prefab.footprint.x, prefab.footprint.y)*0.32*float(item.size)
		var frame := SpaceLayout.ground_frame(_planet, item.dir, float(item.spin), half) if half>0.6 else (item.frame as Transform3D)
		frame.origin -= frame.basis.y*0.12
		item.low = frame
	return [item.low, float(item.size)]

## Collision for the obstacles around the crew (planet-space `at`), wherever
## the ship set down; cells far away are released again.
func update_collision(at: Vector3) -> void:
	if _planet.is_empty(): return
	if _by_cell.is_empty():
		for item: Dictionary in placements(_planet):
			if item.decor or ObstacleLibrary.get_prefab(str(item.name)).is_fine(): continue
			var key := Vector3i(((item.frame as Transform3D).origin/BODY_CELL).floor())
			if not _by_cell.has(key): _by_cell[key] = []
			_by_cell[key].append(item)
	var cell := Vector3i((at/BODY_CELL).floor())
	var want := {}
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			for dz in range(-1, 2): want[cell+Vector3i(dx, dy, dz)] = true
	for key: Vector3i in _bodies.keys():
		if not want.has(key):
			_bodies[key].queue_free()
			_bodies.erase(key)
	for key: Vector3i in want:
		if _bodies.has(key): continue
		var body := StaticBody3D.new()
		body.collision_layer = Player.OBSTACLE_LAYER
		body.collision_mask = 0
		add_child(body)
		_bodies[key] = body
		for item: Dictionary in _by_cell.get(key, []):
			var prefab := ObstacleLibrary.get_prefab(str(item.name))
			var low: Array = _low_frame(item)
			var size := float(item.size)
			for box: AABB in prefab.collision_boxes:
				var shape := CollisionShape3D.new()
				var box_shape := BoxShape3D.new()
				box_shape.size = box.size*size
				shape.shape = box_shape
				shape.transform = (low[0] as Transform3D)*Transform3D(Basis.IDENTITY, box.get_center()*size)
				body.add_child(shape)

static func _random_dir(rng: RandomNumberGenerator) -> Vector3:
	var z := rng.randf_range(-1.0, 1.0)
	var a := rng.randf()*TAU
	var r := sqrt(1.0-z*z)
	return Vector3(cos(a)*r, sin(a)*r, z)

static func _clear(p: Dictionary, dir: Vector3, margin: float) -> bool:
	var radius := float(p.radius)
	for flat: Array in SpaceLayout._flat_spots(p):
		if dir.dot(flat[0])<float(flat[4]): continue
		if acos(clampf(dir.dot(flat[0]), -1.0, 1.0))*radius<float(flat[1])+margin: return false
	return true

static func _frame(dir: Vector3, distance: float, spin: float) -> Transform3D:
	var right := dir.cross(Vector3.FORWARD if absf(dir.dot(Vector3.FORWARD))<0.95 else Vector3.RIGHT).normalized()
	return Transform3D(Basis(right, dir, right.cross(dir)).rotated(dir, spin), dir*distance)

static func _pick(weights: Dictionary, roll: float) -> String:
	var total := 0.0
	for w: float in weights.values(): total += w
	roll *= total
	for key: String in weights:
		roll -= float(weights[key])
		if roll<=0.0: return key
	return weights.keys()[0]
