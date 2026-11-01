class_name CastleWorld
extends GameWorld
## Fixed castle: all architecture and prop placements live in hollow_castle.tscn.
## Coordinates in the GameWorld query API are castle-local, as in HallWorld.
const Bake = preload("res://scenes/castle/castle_bake.gd")
const Brush = preload("res://scenes/castle/castle_brush.gd")
const THRONE_SEAT := Vector3(0, 2, -74.1)
signal king_defeated(realm: String)
var server_build := false
var cinematic_stage := false
var enemy_director: EnemyDirector
var encounter: Node
var gates := preload("res://scripts/world/castle_gates.gd").new()
var _biome: BiomeDef
var _surfaces: Array[Dictionary] = []
var _solids: Array[AABB] = []

func _init() -> void:
	realm_id = "castle"
	display_name = "The Hollow Castle"
	half_extent = 192

## A private atmosphere resource: never mutate the shared Tavern biome.
func biome_at(_pos: Vector3) -> BiomeDef:
	if _biome == null:
		_biome = BiomeDef.new()
		_biome.biome_name = "The Hollow Castle"
		_biome.indoor = true
		_biome.sky_top_color = Color("03050b")
		_biome.sky_horizon_color = Color("101521")
		_biome.sun_color = Color(0.78, 0.84, 0.96)
		_biome.sun_energy = 0.8
		_biome.sun_pitch = 56.0
		_biome.sun_yaw = -28.0
		_biome.ambient_energy = 0.48
		_biome.fog_density = 0.0
		_biome.volumetric_fog_density = 0.0
		_biome.fog_of_war_enabled = false
		_biome.torch_energy = 0.7
	return _biome

static func stage() -> Node3D:
	var instance = load("res://scenes/castle/hollow_castle.tscn").instantiate()
	instance.cinematic_stage = true
	return instance

func _ready() -> void:
	# Campaign cinematics instantiate this scene at their documented stage offset.
	if global_position.y < -200.0: cinematic_stage = true
	var bake := Bake.new()
	for node in $Architecture.get_children():
		if not node is Brush or not node.mesh is BoxMesh:
			continue
		var bounds: AABB = node.transform * AABB(-node.mesh.size / 2.0, node.mesh.size)
		var pieces: Array[AABB] = [bounds]
		if not cinematic_stage and not node.walk_surface:
			for side in [-1.0, 1.0]:
				var hole := AABB(Vector3(side * 23 - 1, 0, -12), Vector3(2, 6, 6))
				var remaining: Array[AABB] = []
				for piece in pieces: remaining.append_array(_subtract(piece, hole))
				pieces = remaining
		for piece in pieces: bake.brushes.append({bounds = piece, block = node.block, checker = node.checker})
		if node.walk_surface:
			_surfaces.append({bounds = bounds, checker = node.checker, block = node.block})
		else:
			_solids.append_array(pieces)
	_add_terrain(bake, AABB(Vector3(-192, -48, -192), Vector3(384, 144, 384)))
	spawn_point = $Spawn.position
	# Props supply small solid footprints without making overhead chains obstacles.
	for prop in $Props.get_children():
		# Overhead decorations obscure enemies from the gameplay camera.
		if not cinematic_stage and prop.get("kind") in ["chandelier", "chain"]: prop.hide()
		if prop.has_method("solid_bounds"):
			var bounds: AABB = prop.solid_bounds()
			if bounds.has_volume():
				_solids.append(prop.transform * bounds)

	if not cinematic_stage:
		enemy_director = EnemyDirector.new()
		enemy_director.world = self
		enemy_director.realm_id = realm_id
		enemy_director.remote = Net.is_client()
		add_child(enemy_director)
		encounter = preload("res://scripts/world/castle_encounter.gd").new()
		encounter.world = self
		add_child(encounter)
		_bind_client.call_deferred()

func castle_event(ev: Array) -> void:
	if is_instance_valid(encounter): encounter.apply_event(ev)

func update_streaming_multi(_positions: Array, _force := false) -> void:
	pass

func cleared_packs() -> Array:
	return []

func pack_survivors() -> Dictionary:
	return {}

func obstacles_near(_pos: Vector3, _radius: float) -> Array[String]:
	return []

func remove_obstacle(_id: String) -> void:
	pass

func ground_height(x: float, z: float) -> float:
	var h := -32.0
	for surface in _surfaces:
		var b: AABB = surface.bounds
		if x >= b.position.x and x < b.end.x and z >= b.position.z and z < b.end.z:
			h = maxf(h, b.end.y)
	return h

func is_walkable(pos: Vector3) -> bool:
	if is_instance_valid(encounter) and encounter.blocks_point(pos): return false
	var h := ground_height(pos.x, pos.z)
	if h < -20:
		return false
	for b in _solids:
		if pos.x >= b.position.x - 0.3 and pos.x < b.end.x + 0.3 and pos.z >= b.position.z - 0.3 and pos.z < b.end.z + 0.3 and b.position.y < h + 2.0 and b.end.y > h + 0.15:
			return false
	return true

func map_color(x: int, z: int) -> Color:
	if not is_walkable(Vector3(x + 0.5, 0, z + 0.5)):
		return Color("11131a")
	return Color("bfc1bf") if posmod(floori(float(x) / 3) + floori(float(z) / 3), 2) == 0 else Color("34353c")

func region_at(pos: Vector3) -> String:
	if pos.z < -29: return "The Hollow Throne"
	if pos.z < 14: return "Hall of the Forsaken"
	if pos.z < 45: return "Ashen Courtyard"
	return "The Last Bridge"


## Split masonry around the two authored champion passages before workers see it.
static func _subtract(bounds: AABB, hole: AABB) -> Array[AABB]:
	if not bounds.intersects(hole): return [bounds]
	var cut := bounds.intersection(hole)
	var pieces: Array[AABB] = []
	var core := bounds
	for axis in 3:
		if cut.position[axis] > core.position[axis]:
			var low := core
			low.size[axis] = cut.position[axis] - core.position[axis]
			pieces.append(low)
			core.size[axis] -= low.size[axis]
			core.position[axis] = cut.position[axis]
		if cut.end[axis] < core.end[axis]:
			var high := core
			high.position[axis] = cut.end[axis]
			high.size[axis] = core.end[axis] - cut.end[axis]
			pieces.append(high)
			core.size[axis] -= high.size[axis]
	return pieces


## Bind through NetClient's public fields after its attach_world call this frame.
## This also supports callers that instantiate the scene directly.
func _bind_client() -> void:
	if Net.is_client() and Net.client.world == self:
		Net.client.director = enemy_director
		enemy_director.setup(Net.client.player, Net.client.bullets, [], {})
