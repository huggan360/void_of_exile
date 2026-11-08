class_name PlanetFlora
extends Node3D
## A planet's plants, stones and ruins, made of the realm's own voxel
## obstacles (ObstacleLibrary) recoloured for that world. Instances are
## batched per patch of sky-direction so distant patches drop out, the
## small decor only shows close up, and the obstacles around the crew get the
## same collision as in the realm.
const PATCH := 4.0  # direction quantisation: patches of roughly radius/4
const OBSTACLE_RANGE := 900.0
const DECOR_RANGE := 240.0
const DECOR_ARC := 520.0

## Per planet: weighted obstacles, weighted decor, obstacle density (one per
## so many square metres), size scale, and the voxel colour slots (stone,
## stone dark, foliage, wood, accent, foliage dark, glow).
const SETS := {
	verdance = {obstacles = {tree_round = 6, tree_tall = 3, tree_small = 3, bush = 4, glowshroom = 2.5, rock = 1, pine = 1},
		decor = {decor_tuft = 6, decor_flowers = 3, decor_fern = 3, decor_mushrooms = 2, decor_glow_sprouts = 1.5}, area = 520.0, scale = 1.6,
		colors = ["8a8676", "5f5c52", "4fae58", "7a5034", "f2d27a", "2f7a3e", "a8ffb0"]},
	rosamund = {obstacles = {tree_round = 5, crystal_cluster = 4, bush = 3, glowshroom = 2, tree_small = 2},
		decor = {decor_flowers = 6, decor_glow_sprouts = 2, decor_tuft = 3}, area = 560.0, scale = 1.5,
		colors = ["d9b8d0", "a07a98", "f29ac9", "8a5a6e", "8de0ff", "c25a96", "ffb8f0"]},
	amberfall = {obstacles = {cactus = 4, palm = 2, rock = 2, pillar = 1.5, ruin_wall = 0.6, lamppost = 0.5, campfire = 0.3},
		decor = {decor_dry_grass = 5, decor_pebbles = 3}, area = 900.0, scale = 1.5,
		colors = ["d8a868", "9a6a3a", "7fb84a", "8a5a2a", "ffcf6a", "5a8a32", "ffd27a"]},
	tidewell = {obstacles = {palm = 6, bush = 3, rock = 2, tree_small = 1.5, lamppost = 0.3},
		decor = {decor_tuft = 5, decor_pebbles = 3, decor_flowers = 1}, area = 640.0, scale = 1.5,
		colors = ["e8d6a0", "b0a070", "3f9d6a", "8a6a48", "ffffff", "2a7a50", "a8f0ff"]},
	shardheart = {obstacles = {crystal_cluster = 8, ice_spike = 4, obelisk = 1, rock = 2},
		decor = {decor_glow_sprouts = 5, decor_pebbles = 2}, area = 420.0, scale = 1.7,
		colors = ["3a5a6a", "22343e", "6af0c8", "34485c", "ff8ae0", "2a8a7a", "8afff0"]},
	hollowmoon = {obstacles = {dead_tree = 5, obelisk = 2, boulder = 2, ruin_wall = 1, pillar = 1, lamppost = 0.6},
		decor = {decor_pebbles = 4, decor_glow_sprouts = 1.5}, area = 760.0, scale = 1.6,
		colors = ["9a9ea8", "5a5e68", "6a7a6a", "c8c4b0", "7dff6a", "3a4a3e", "7dff6a"]},
	mawgrave = {obstacles = {glowshroom = 7, burnt_tree = 3, crystal_cluster = 1, boulder = 2},
		decor = {decor_mushrooms = 4, decor_glow_sprouts = 3, decor_embers = 1}, area = 520.0, scale = 2.0,
		colors = ["5a3a6a", "2a1a32", "8a4aa0", "3a2230", "ff5fd2", "4a2a5a", "ff6ae0"]},
	pale_eye = {obstacles = {obelisk = 4, ice_spike = 3, boulder = 3, burnt_tree = 2, pillar = 1},
		decor = {decor_embers = 2, decor_pebbles = 3}, area = 820.0, scale = 2.0,
		colors = ["3a3e4e", "1c1f2b", "5a6478", "2a2a34", "ff4a5a", "2e3446", "9ab0ff"]},
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

## Every obstacle and decor piece of planet `p`, deterministic (the server
## uses the same list to keep landing sites clear): [{name, frame, size, decor}],
## frames in planet space.
static func placements(p: Dictionary) -> Array:
	if _placements.has(p.id): return _placements[p.id]
	if not SETS.has(p.id):
		_placements[p.id] = []
		return []
	var set: Dictionary = SETS[p.id]
	var radius := float(p.radius)
	var pad := SpaceLayout.pad_frame(p).basis.y
	var sea := bool(p.terrain.get("sea", false))
	var rng := RandomNumberGenerator.new()
	rng.seed = absi(String(p.id).hash())+31
	var out: Array = []
	var obstacle_count := mini(14000, int(4.0*PI*radius*radius/float(set.area)))
	var decor_area := TAU*radius*radius*(1.0-cos(DECOR_ARC/radius))
	var decor_count := int(decor_area/60.0)
	for pass_index in 2:
		var decor := pass_index==1
		var weights: Dictionary = set.decor if decor else set.obstacles
		for i in (decor_count if decor else obstacle_count):
			var dir := _random_dir(rng) if not decor else _near_pad(rng, pad, radius)
			var clear := _clear(p, dir, 4.0 if decor else 9.0)
			var h := SpaceLayout.surface_height(p, dir)
			var name := _pick(weights, rng)
			var size := float(set.scale)*rng.randf_range(0.85, 1.25)*(1.0 if decor else (1.0 if rng.randf()>0.1 else 1.5))
			var spin := rng.randf()*TAU
			if not clear or (sea and h<1.6): continue
			out.append({name = name, frame = _frame(dir, radius+h-0.12, spin), size = size, decor = decor, dir = dir})
	_placements[p.id] = out
	return out

## Obstacles (not decor) of `p` by 40 m cell of their planet-space position.
static func _obstacle_index(p: Dictionary) -> Dictionary:
	if _index.has(p.id): return _index[p.id]
	var index := {}
	for item: Dictionary in placements(p):
		if item.decor: continue
		var prefab := ObstacleLibrary.get_prefab(str(item.name))
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
	var biome := biome_for(p)
	var batches := {}  # "patch|prefab|decor" -> [prefab, transforms, decor]
	for item: Dictionary in placements(p):
		var prefab := ObstacleLibrary.get_prefab(str(item.name))
		var size := float(item.size)
		var placed := (item.frame as Transform3D)*Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*prefab.voxel_size*size), prefab.mesh_offset()*size)
		var key := "%s|%s|%d" % [Vector3i(((item.dir as Vector3)*PATCH).round()), item.name, int(item.decor)]
		if not batches.has(key): batches[key] = [prefab, [], item.decor]
		batches[key][1].append(placed)
	for entry: Array in batches.values():
		var prefab: ObstacleLibrary.Prefab = entry[0]
		var meshes := prefab.meshes_for(biome)
		for slot in 2:
			if meshes[slot]==null: continue
			var multi := MultiMesh.new()
			multi.transform_format = MultiMesh.TRANSFORM_3D
			multi.mesh = meshes[slot]
			multi.instance_count = entry[1].size()
			for k in entry[1].size(): multi.set_instance_transform(k, entry[1][k])
			var node := MultiMeshInstance3D.new()
			node.multimesh = multi
			node.material_override = VoxModel.glow_material() if slot==1 else VoxModel.material()
			node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if entry[2] else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			node.visibility_range_end = DECOR_RANGE if entry[2] else OBSTACLE_RANGE
			node.visibility_range_end_margin = 40.0 if entry[2] else 200.0
			node.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
			add_child(node)

## Collision for the obstacles around the crew (planet-space `at`), wherever
## the ship set down; cells far away are released again.
func update_collision(at: Vector3) -> void:
	if _planet.is_empty(): return
	if _by_cell.is_empty():
		for item: Dictionary in placements(_planet):
			if item.decor: continue
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
			var size := float(item.size)
			for box: AABB in prefab.collision_boxes:
				var shape := CollisionShape3D.new()
				var box_shape := BoxShape3D.new()
				box_shape.size = box.size*size
				shape.shape = box_shape
				shape.transform = (item.frame as Transform3D)*Transform3D(Basis.IDENTITY, box.get_center()*size)
				body.add_child(shape)

static func _random_dir(rng: RandomNumberGenerator) -> Vector3:
	var z := rng.randf_range(-1.0, 1.0)
	var a := rng.randf()*TAU
	var r := sqrt(1.0-z*z)
	return Vector3(cos(a)*r, sin(a)*r, z)

## Decor clusters around the pad, where the crew walks.
static func _near_pad(rng: RandomNumberGenerator, pad: Vector3, radius: float) -> Vector3:
	var right := pad.cross(Vector3.FORWARD if absf(pad.dot(Vector3.FORWARD))<0.95 else Vector3.RIGHT).normalized()
	var forward := right.cross(pad)
	var arc := sqrt(rng.randf())*DECOR_ARC
	var a := rng.randf()*TAU
	var tangent := right*cos(a)+forward*sin(a)
	return (pad*cos(arc/radius)+tangent*sin(arc/radius)).normalized()

static func _clear(p: Dictionary, dir: Vector3, margin: float) -> bool:
	var radius := float(p.radius)
	for flat: Array in SpaceLayout._flat_spots(p):
		if acos(clampf(dir.dot(flat[0]), -1.0, 1.0))*radius<float(flat[1])+margin: return false
	return true

static func _frame(dir: Vector3, distance: float, spin: float) -> Transform3D:
	var right := dir.cross(Vector3.FORWARD if absf(dir.dot(Vector3.FORWARD))<0.95 else Vector3.RIGHT).normalized()
	return Transform3D(Basis(right, dir, right.cross(dir)).rotated(dir, spin), dir*distance)

static func _pick(weights: Dictionary, rng: RandomNumberGenerator) -> String:
	var total := 0.0
	for w: float in weights.values(): total += w
	var roll := rng.randf()*total
	for key: String in weights:
		roll -= float(weights[key])
		if roll<=0.0: return key
	return weights.keys()[0]
