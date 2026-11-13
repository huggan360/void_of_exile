class_name IslandWorld
extends GameWorld
## A realm: a seeded island whose record (seed + destroyed obstacles) comes
## from the WorldServer. Players arrive in the central village next to a portal home.
##
## The Surface is big, so trees, obstacles, lampposts, water and ground cover
## are streamed: built in 32 x 32 m chunks around the player and freed again
## when the player moves away. Terrain streams on its own (VoxelTerrain, in
## 0.25 m voxels: the node is scaled by 1 / IslandGenerator.FINE).
##
## On the dedicated server (`server_build`) only what enemies collide with is
## built (terrain, obstacles, houses), around every player in the realm
## (update_streaming_multi); no decor, lights, signs or townsfolk.

const KEEP_CLEAR_RADIUS := 9.0
## Share of burnt trees that are still burning (Doom vs. elsewhere).
const BURNING_CHANCE_DOOM := 0.55
const BURNING_CHANCE := 0.3
const CHUNK := 32
const LOAD_RADIUS := 4  # chunks around the player that are kept built (~128 m)
const STREAM_BUDGET_USEC := 1000
const UNLOADS_PER_FRAME := 1
const BUILD_TILE := 4
const FLORA_TILE := 4

var gates := StrongholdGates.new()
var generator: IslandGenerator
## The Skyward Launch Pad (clients), if this island has one.
var surface_ships: SurfaceShipWorld
var launchpad: SurfaceLaunchpad
var _record: Dictionary
var _destroyed := {}  # obstacle id -> true
var _portal_pos := Vector3.ZERO
var _keep_clear: Array[Vector3] = []
var _buildings_by_chunk := {}
var _town_navigation := {}
var _village_plans := {}
var _services_by_chunk := {}
var _npcs_by_chunk := {}
var service_sites: Array[Dictionary] = []
var _lamps_by_chunk := {}  # Vector2i -> Array[Dictionary]
var _town_trees_by_chunk := {}  # Vector2i -> Array[Dictionary] (with the town's biome)
var _camps_by_chunk := {}  # Vector2i -> Array[Dictionary] (baked camps)
var _falls_by_chunk := {}  # Vector2i -> Array[Dictionary] (baked waterfalls)
var _pushers := PackedVector4Array()
var _retired: Array[Node3D] = []
var _chunks := {}  # Vector2i -> Node3D holding that chunk's content
var _queue: Array[Vector2i] = []
var _build_steps: Array[Callable] = []
var _building_root: Node3D
var _server_centers: Array[Vector2i] = []
var _server_want := {}
var _center_chunk := Vector2i(1 << 30, 0)
## Wakes enemy packs as the player comes near.
var enemy_director := EnemyDirector.new()
## Dedicated server: build only what matters for the simulation.
var server_build := false
var astral_site := Vector3.INF
var astral_station: AstralStation
var _obstacles := {}  # obstacle id -> Obstacle (built ones)


func _init(record: Dictionary, prepared_layout := {}) -> void:
	_record = record
	realm_id = record.id
	var number := str(record.id).trim_prefix("realm_")
	display_name = record.get("name", "The Surface" if number == "1" or not number.is_valid_int() else "The Surface %s" % number)
	for id in record.destroyed:
		_destroyed[id] = true
	# Every realm is the baked Surface (res://realm/surface/, see SurfaceMap).
	generator = IslandGenerator.new(record.seed, prepared_layout)
	if record.get("astral_station",false): astral_site = AstralStation.plan(generator)
	half_extent = SurfaceMap.HALF
	var spawn := generator.find_spawn()
	spawn_point = spawn[0]
	var inland: Vector2 = spawn[1]
	_portal_pos = generator.surface(Vector2(spawn_point.x, spawn_point.z) + inland * 7.0)
	_keep_clear = [spawn_point, _portal_pos]
	if astral_site.is_finite():
		for key in ["mechanic", "parts", "boarding", "rocket"]:
			_keep_clear.append(astral_anchor(key))
	for village in generator.villages:
		_village_plans[village.display_name] = village
		for building: Dictionary in village.houses + village.props:
			var chunk := _chunk_of(building.pos)
			if not _buildings_by_chunk.has(chunk):
				_buildings_by_chunk[chunk] = []
			_buildings_by_chunk[chunk].append(building)
		for tree: Dictionary in village.trees:
			var tree_chunk := _chunk_of(tree.pos)
			if not _town_trees_by_chunk.has(tree_chunk):
				_town_trees_by_chunk[tree_chunk] = []
			_town_trees_by_chunk[tree_chunk].append(tree.merged({biome = village.biome_id}))
		_place_townsfolk(village)
		service_sites.append_array(village.service_sites)
		for service in village.service_sites:
			var chunk := _chunk_of(service.door)
			if not _services_by_chunk.has(chunk):
				_services_by_chunk[chunk] = []
			_services_by_chunk[chunk].append(service)
		for resident in village.residents:
			var chunk := _chunk_of(resident.pos)
			if not _npcs_by_chunk.has(chunk):
				_npcs_by_chunk[chunk] = []
			_npcs_by_chunk[chunk].append(resident)
	for site in generator.lamp_sites():
		if site.pos.distance_to(spawn_point) < KEEP_CLEAR_RADIUS or site.pos.distance_to(_portal_pos) < KEEP_CLEAR_RADIUS:
			continue
		var c := _chunk_of(site.pos)
		if not _lamps_by_chunk.has(c):
			_lamps_by_chunk[c] = []
		_lamps_by_chunk[c].append(site)
	for camp: Dictionary in generator.map.data.get("camps", []):
		var c := _chunk_of(Vector3(camp.center[0], 0, camp.center[1]))
		if not _camps_by_chunk.has(c): _camps_by_chunk[c] = []
		_camps_by_chunk[c].append(camp)
	for fall: Dictionary in generator.map.data.get("waterfalls", []):
		var c := _chunk_of(Vector3(fall.x, 0, fall.z))
		if not _falls_by_chunk.has(c): _falls_by_chunk[c] = []
		_falls_by_chunk[c].append(fall)
	_pushers.resize(24)


## Clients and the server resolve identical stations before chunk indexing.
func _place_townsfolk(village: VillageFeature) -> void:
	# Baked towns already stand their people on street spots (VillageFeature.
	# from_baked); their walking grid is only built once someone spawns there
	# (_build_resident), so opening a Surface stays quick for the server.
	if village.kind != "":
		return
	var navigation := TownNavigation.new(village, self)
	_town_navigation[village.display_name] = navigation
	var plaza := navigation._node(Vector3(village.center.x + 0.5, 0, village.center.y + 0.5))
	var taken: Array[Vector3] = []
	for resident in village.residents:
		var desired: Vector3 = resident.pos
		var best := Vector3.INF
		var score := INF
		for z in navigation.side:
			for x in navigation.side:
				var cell := Vector2i(x, z)
				if navigation.grid.is_point_solid(cell):
					continue
				var point := navigation.grid.get_point_position(cell)
				if not village.is_street(floori(point.x), floori(point.y)):
					continue
				var at := Vector3(point.x, ground_height(point.x, point.y), point.y)
				var distance := at.distance_squared_to(desired)
				if distance >= score or taken.any(func(other: Vector3) -> bool: return at.distance_squared_to(other) < 2.25):
					continue
				if navigation.grid.get_id_path(plaza, cell).is_empty():
					continue
				best = at
				score = distance
		if best == Vector3.INF:
			best = Vector3(desired.x, ground_height(desired.x, desired.z), desired.z)
		resident.pos = best
		if resident.role == "steward" or not resident.stationary:
			var toward := Vector3(village.center.x + 0.5, best.y, village.center.y + 0.5) - best
			resident.yaw = atan2(-toward.x, -toward.z)
		taken.append(best)
	for service in village.service_sites:
		service.door = service.npc.pos


func _warm_stream_assets() -> void:
	# VOX parsing and meshing belong to world loading, not a walk into town.
	for buildings in _buildings_by_chunk.values():
		for building in buildings: VillageHouse.warm_asset(str(building.asset))
	for id in range(2,Biomes.COUNT):
		var biome := Biomes.get_biome(id)
		if server_build or Net.is_server(): continue  # nothing is drawn there: no meshes to warm
		for prefab in biome.obstacles: ObstacleLibrary.get_prefab(str(prefab)).meshes_for(biome)
		for group: Dictionary in IslandGenerator.TREES.get(id, []):
			for prefab: String in group:
				ObstacleLibrary.get_prefab(prefab).meshes_for(biome)
				ObstacleLibrary.get_prefab(prefab).lod_mesh_for(biome)
	if not server_build:
		VoxelFire.warm(1.0)
		VoxelFire.warm(1.4)

func _ready() -> void:
	if not get_meta("assets_prepared",false): _warm_stream_assets()
	var r := half_extent * IslandGenerator.FINE
	var sources: Array = generator.map.sources + ["res://scripts/world/realm_feature.gd", "res://scripts/world/surface/surface_map.gd",
		"res://scripts/world/surface/surface_blocks.gd", "res://scripts/world/stronghold_feature.gd"]
	_add_terrain(generator, AABB(Vector3(-r, -32, -r), Vector3(r * 2, (IslandGenerator.MAX_HEIGHT + 8) * IslandGenerator.FINE, r * 2)),
		"surface_fine_%d" % generator.realm_seed, sources, SurfaceBlocks.mesher())
	terrain.scale = Vector3.ONE / IslandGenerator.FINE
	terrain.mesh_block_size = 32
	terrain.max_view_distance = 640
	terrain.material_override = SurfaceBlocks.material()
	var format := VoxelFormat.new()
	format.set_channel_depth(VoxelBuffer.CHANNEL_TYPE, VoxelBuffer.DEPTH_8_BIT)
	terrain.format = format
	if not server_build:
		var sea := _add_water(IslandGenerator.SEA_LEVEL + 0.6, half_extent + 400.0)
		var plane := sea.mesh as PlaneMesh
		plane.subdivide_width = 96  # room for the swell
		plane.subdivide_depth = 96
		sea.material_override = SurfaceWater.sea_material()
		for light: Dictionary in generator.map.data.get("lights", []):
			var lamp := _add_light(Vector3(light.x, light.y, light.z), Color(light.color[0], light.color[1], light.color[2]),
				float(light.energy), float(light.range))
			lamp.distance_fade_begin = 70.0
			lamp.distance_fade_length = 25.0
	_add_portal(_portal_pos, spawn_point - _portal_pos, "hall",
			Color(1.0, 0.6, 0.2), Color(1.0, 0.9, 0.5))
	if astral_site.is_finite():
		astral_station = AstralStation.new()
		astral_station.world = self
		add_child(astral_station)
	add_child(gates)
	var opened: Array = _record.get("opened_gates",[]).map(func(c: Array) -> Vector2i: return Vector2i(int(c[0]),int(c[1])))
	# Fortresses a campaign opened for good stay open.
	var forced: Array = _record.get("forced_open",[]).map(func(c: Array) -> Vector2i: return Vector2i(int(c[0]),int(c[1])))
	gates.build(generator.strongholds,server_build,opened+forced)
	gates.forced_open = forced
	gates.changed.connect(func(center: Vector2i, locked: bool, sealed: bool) -> void:
		if Net.is_server(): Net.server.fortress_gate(self,center,locked,sealed)
		if not Net.is_client(): WorldServer.report_gates(realm_id,gates.opened()))
	for state: Array in _record.get("stronghold_gates",[]):
		gates.apply_state(state[0],bool(state[1]),bool(state[2]) if state.size()>2 else bool(state[1]))
	enemy_director.world = self
	enemy_director.realm_id = realm_id
	add_child(enemy_director)
	for f in (generator.features if not server_build else []):
		for spot in f.light_spots:
			var ground := ground_height(spot.x, spot.z)
			_add_light(Vector3(spot.x, ground + spot.y, spot.z), f.light_color, 2.0, 8.0)
	var pad := launchpad_center()
	if pad.is_finite():
		surface_ships = SurfaceShipWorld.new(self)
		add_child(surface_ships)
		if _record.has("surface_ship_state"): surface_ships.apply_state(_record.surface_ship_state)
	if pad.is_finite() and not server_build:
		launchpad = SurfaceLaunchpad.new()
		launchpad.name = "SkywardLaunchPad"
		launchpad.position = pad
		add_child(launchpad)
		launchpad.build(self)


## The Skyward Launch Pad's centre on its paving (the "launchpad" landmark),
## or INF when this island has none.
func launchpad_center() -> Vector3:
	for f in generator.features:
		if f.type == "launchpad":
			var x := f.center.x + 0.5
			var z := f.center.y + 0.5
			return Vector3(x, ground_height(x, z), z)
	return Vector3.INF

## Where someone coming down from Space stands on the pad.
func launchpad_arrival() -> Vector3:
	var pad := launchpad_center()
	return pad + SurfaceLaunchpad.ARRIVAL if pad.is_finite() else Vector3.INF


## Builds chunks near `pos` and frees far ones. Call every frame.
func update_streaming(pos: Vector3, build_all_now := false) -> void:
	if SpaceLayout.pocket_at(pos)>=0: pos = launchpad_center()
	var center := _chunk_of(pos)
	# The View distance setting trims the client's ring (the server keeps LOAD_RADIUS).
	var radius := mini(LOAD_RADIUS, ceili(LOAD_RADIUS * GraphicsSettings.view_scale()))
	if center != _center_chunk:
		_center_chunk = center
		_queue.clear()
		for dz in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				var c := center + Vector2i(dx, dz)
				if not _chunks.has(c):
					_queue.append(c)
		# Nearest chunks first.
		_queue.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
			return (a - center).length_squared() < (b - center).length_squared())
	var keep := {}
	for c: Vector2i in _chunks:
		if maxi(absi(c.x - center.x), absi(c.y - center.y)) <= radius + 1:
			keep[c] = true
	_prune_chunks(keep, build_all_now)
	_build_queued(build_all_now)


## Server: keeps chunks built around every player (and frees the rest).
func update_streaming_multi(positions: Array, build_all_now := false) -> void:
	var centers: Array[Vector2i] = []
	for pos: Vector3 in positions:
		if SpaceLayout.pocket_at(pos)>=0: pos = launchpad_center()
		var center := _chunk_of(pos)
		if not centers.has(center): centers.append(center)
	centers.sort()
	if centers == _server_centers:
		_prune_chunks(_server_want, build_all_now)
		_build_queued(build_all_now)
		return
	_server_centers = centers
	var want := {}
	var priority := {}
	for center: Vector2i in centers:
		for dz in range(-LOAD_RADIUS, LOAD_RADIUS + 1):
			for dx in range(-LOAD_RADIUS, LOAD_RADIUS + 1):
				var c := center + Vector2i(dx, dz)
				want[c] = true
				priority[c] = mini(int(priority.get(c, 1 << 30)), dx * dx + dz * dz)
	_server_want = want
	_prune_chunks(want, build_all_now)
	_queue.clear()
	for c: Vector2i in want:
		if not _chunks.has(c):
			_queue.append(c)
	_queue.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return priority[a] < priority[b])
	_build_queued(build_all_now)


func _retire_step() -> void:
	var started := Time.get_ticks_usec() if FrameTrace.enabled else 0
	var deadline := Time.get_ticks_usec()+600
	var count := 0
	while not _retired.is_empty() and count<8:
		var root := _retired[0]
		if root.get_child_count()==0:
			root.queue_free()
			_retired.pop_front()
		else:
			var child := root.get_child(root.get_child_count()-1)
			root.remove_child(child)
			child.queue_free()
		count += 1
		if Time.get_ticks_usec()>=deadline: break
	if FrameTrace.enabled: FrameTrace.record("stream/retire",started)

func _prune_chunks(keep: Dictionary, all_now: bool) -> void:
	_retire_step()
	var removed := 0
	for c: Vector2i in _chunks.keys():
		if keep.has(c): continue
		var root: Node3D = _chunks[c]
		if root == _building_root:
			_build_steps.clear()
			_building_root = null
		# Remove collision and processing immediately; destruction is deferred.
		var unload_started := Time.get_ticks_usec() if FrameTrace.enabled else 0
		if all_now or server_build:
			remove_child(root)
			root.queue_free()
		else:
			# Disable the subtree (including collision), then release small
			# batches instead of freeing hundreds of render/physics RIDs at once.
			root.hide()
			root.process_mode = Node.PROCESS_MODE_DISABLED
			_retired.append(root)
		_chunks.erase(c)
		if FrameTrace.enabled: FrameTrace.record("stream/unload",unload_started)
		enemy_director.remove_chunk(c)
		removed += 1
		if not all_now and removed >= UNLOADS_PER_FRAME: break


func _build_queued(build_all_now: bool) -> void:
	var deadline := Time.get_ticks_usec() + (3000 if get_meta("asynchronous_load",false) else STREAM_BUDGET_USEC)
	while not _queue.is_empty() or not _build_steps.is_empty():
		if _build_steps.is_empty():
			_start_chunk(_queue.pop_front())
		if not _build_steps.is_empty():
			var step: Callable = _build_steps.pop_front()
			var started := Time.get_ticks_usec() if FrameTrace.enabled else 0
			step.call()
			if FrameTrace.enabled: FrameTrace.record("stream/"+str(step.get_method()),started)
		if not build_all_now and Time.get_ticks_usec() >= deadline: break

func is_presentation_ready() -> bool:
	return super.is_presentation_ready() and _queue.is_empty() and _build_steps.is_empty()



## A conversation with a townsperson. The steward also offers to make the
## town your home.
func _talk_target(resident: Dictionary) -> InteractionTarget:
	var role := str(resident.role)
	var village := str(resident.village)
	var target := InteractionTarget.new()
	target.title = "%s of %s" % [str(resident.get("title", role.capitalize())).split("  ")[0], village]
	var portrait := "res://creatures/%s/portrait.png" % str(resident.get("model", "npc_" + role))
	if ResourceLoader.exists(portrait):
		target.portrait = load(portrait)
	target.position.y = 1.0
	target.reach = 3.0
	if role == "steward":
		target.description = "The steward keeps the town book of %s." % village
		target.action_text = "Talk"
		target.confirm_text = "Yes"
		target.cancel_text = "No"
		target.activated.connect(func(player: Node3D) -> void:
			var stats := GameServer.character(player.player_id)
			var welcome := "Welcome to %s. I keep this town's book of residents." % village
			if stats and stats.home == village:
				welcome = "Your characters already call %s home. You're always welcome here." % village
			target.response = welcome + "|Would you like to make %s the realm spawn town for all your characters?" % village)
		target.confirmed.connect(func(player: Node3D) -> void:
			GameServer.request_set_home(player.player_id, village))
	else:
		target.description = "Say hello?"
		target.action_text = "Talk"
		target.activated.connect(func(_player: Node3D) -> void: target.response = TownTalk.line(role, village))
	return target


## Where you arrive when `village` is your home (by its town hall), or INF.
func home_point(village: String) -> Vector3:
	for v in generator.villages:
		if v.display_name != village:
			continue
		for r: Dictionary in v.residents:
			if r.role == "steward":
				var p: Vector3 = r.pos
				var inward := (Vector3(v.center.x, p.y, v.center.y) - p).normalized()
				var at := p + inward * 2.2
				return Vector3(at.x, ground_height(at.x, at.z), at.z)
		return generator.surface(Vector2(v.center) + Vector2(3, 3))
	return Vector3.INF


func is_road(pos: Vector3) -> bool:
	return generator.is_road(floori(pos.x), floori(pos.z))


func biome_at(pos: Vector3) -> BiomeDef:
	if SpaceLayout.pocket_at(pos)>=0 and is_instance_valid(surface_ships): return surface_ships.biome_at(pos)
	return Biomes.get_biome(generator.column(floori(pos.x), floori(pos.z)).y)


func is_walkable(pos: Vector3) -> bool:
	if SpaceLayout.pocket_at(pos)>=0 and is_instance_valid(surface_ships): return surface_ships.ship_in_slot(SpaceLayout.pocket_at(pos))!=null
	# Shallow water is fine; deep rivers, lakes and the sea are not.
	# Lava pits can be walked into, but they burn (see is_hazard).
	return generator.walkable(pos.x, pos.z)


func is_hazard(pos: Vector3) -> bool:
	var x := floori(pos.x)
	var z := floori(pos.z)
	# Most of the land: one lookup (lava is a ground material).
	if not generator._shape_grid.has(Vector2i(x >> IslandGenerator.FEATURE_CELL_SHIFT, z >> IslandGenerator.FEATURE_CELL_SHIFT)):
		return generator.map.cell_ground(x, z) == SurfaceMap.Mat.LAVA
	if SpaceLayout.pocket_at(pos)>=0: return false
	return Blocks.is_hazard(generator.surface_block(x, z))

func is_water(pos: Vector3) -> bool:
	if SpaceLayout.pocket_at(pos)>=0: return false
	# Also available on the headless server, where the water mesh is omitted.
	return pos.y<=generator.water_y(pos.x, pos.z)+0.1 and not is_hazard(pos)


func astral_anchor(key: String) -> Vector3:
	if not astral_site.is_finite(): return Vector3.INF
	var at: Vector3 = astral_site+(AstralStation.ROCKET_OFFSET if key=="rocket" else AstralStation.OFFSETS.get(key,Vector3.ZERO))
	at.y = generator.ground_y(at.x, at.z)
	return at


func ground_height(x: float, z: float) -> float:
	return generator.ground_y(x, z)


## The whole Surface as one picture (baked with the map), for the map screen.
func full_map() -> Image:
	var file := FileAccess.open(SurfaceMap.DIR + "map.bin.gz", FileAccess.READ)
	if file == null: return null
	var size := SurfaceMap.N
	var pixels := file.get_buffer(file.get_length()).decompress(size * size * 3, FileAccess.COMPRESSION_GZIP)
	if pixels.size() != size * size * 3: return null
	return Image.create_from_data(size, size, false, Image.FORMAT_RGB8, pixels)


func map_color(x: int, z: int) -> Color:
	var top := generator.top_of(x, z)
	var map := generator.map
	var h := map.cell_height(x, z) / float(IslandGenerator.FINE)
	var west := map.cell_height(x - 1, z) / float(IslandGenerator.FINE)
	var c := SurfaceBlocks.map_color(top.y)
	if top.x + 1 > h + 0.5:
		h = top.x + 1  # a wall or tower
	var shade := 1.0 + clampf((h - west) * 0.12, -0.35, 0.35) + (h - IslandGenerator.SEA_LEVEL) * 0.004
	c = Color(c.r * shade, c.g * shade, c.b * shade)
	var water := map.cell_water(x, z)
	if water > 0:
		c = c.lerp(WATER_COLOR.lightened(0.15), 0.75)
	elif h < IslandGenerator.SEA_LEVEL + 0.6:
		c = c.lerp(WATER_COLOR, clampf(0.6 + (IslandGenerator.SEA_LEVEL - h) * 0.08, 0.0, 0.9))
	# Each town is washed in its own color on the map.
	for v in generator.villages:
		var d := Vector2(x - v.center.x, z - v.center.y).length()
		if d < v.radius:
			return c.lerp(v.map_color, 0.45 if d < v.radius - 2.0 else 0.85)
	if generator.is_road(x, z):
		c = c.lerp(Color(0.92, 0.86, 0.7), 0.35)
	return c


func region_at(pos: Vector3) -> String:
	var f := generator.feature_at(floori(pos.x), floori(pos.z))
	return f.display_name if f else ""


## Packs that were wiped out for good (they never respawn in this realm).
func cleared_packs() -> Array:
	return _record.get("cleared_packs", [])


func pack_survivors() -> Dictionary:
	return _record.get("pack_survivors", {})


## Debug helper: the nearest enemy pack site of a type around `near`.
func find_pack_site(pack_id: String, near: Vector3) -> Dictionary:
	var best := {}
	var c := _chunk_of(near)
	for dz in range(-6, 7):
		for dx in range(-6, 7):
			var area := Rect2i((c + Vector2i(dx, dz)) * CHUNK, Vector2i(CHUNK, CHUNK))
			for site in generator.pack_sites(area, _keep_clear):
				if site.pack == pack_id and (best.is_empty() or site.pos.distance_to(near) < best.pos.distance_to(near)):
					best = site
	return best


## Required features: guaranteed spots for enemies and bosses later.
func required_features() -> Array[RealmFeature]:
	return generator.features.filter(func(f: RealmFeature) -> bool: return f.required)


func _chunk_of(pos: Vector3) -> Vector2i:
	return Vector2i(floori(pos.x / CHUNK), floori(pos.z / CHUNK))


func _build_chunk(c: Vector2i) -> void:
	while not _build_steps.is_empty(): _build_steps.pop_front().call()
	if _chunks.has(c): return
	_start_chunk(c)
	while not _build_steps.is_empty(): _build_steps.pop_front().call()


func _start_chunk(c: Vector2i) -> void:
	var root := Node3D.new()
	root.name = "Chunk_%d_%d" % [c.x, c.y]
	add_child(root)
	_chunks[c] = root
	_building_root = root
	var area := Rect2i(c * CHUNK, Vector2i(CHUNK, CHUNK))
	for z in range(0, CHUNK, BUILD_TILE):
		for x in range(0, CHUNK, BUILD_TILE):
			_build_steps.append(_build_obstacles.bind(root, Rect2i(area.position + Vector2i(x, z), Vector2i(BUILD_TILE, BUILD_TILE))))
	_build_steps.append(_build_trees.bind(root, area))
	_build_steps.append(_build_lamps.bind(root, c))
	for building: Dictionary in _buildings_by_chunk.get(c, []):
		_build_steps.append(_build_house.bind(root, building))
	for camp: Dictionary in _camps_by_chunk.get(c, []):
		_build_steps.append(_build_camp.bind(root, camp))
	if not server_build:
		_build_steps.append(_build_water.bind(root, c, area))
		var decor_groups := {}
		for z in range(0, CHUNK, FLORA_TILE):
			for x in range(0, CHUNK, FLORA_TILE):
				_build_steps.append(_gather_decor.bind(decor_groups, Rect2i(area.position + Vector2i(x, z), Vector2i(FLORA_TILE, FLORA_TILE))))
		_build_steps.append(_finish_decor.bind(root, decor_groups))
		for tree: Dictionary in _town_trees_by_chunk.get(c, []):
			_build_steps.append(_build_town_tree.bind(root, tree))
		for service: Dictionary in _services_by_chunk.get(c, []):
			_build_steps.append(_build_service.bind(root, service))
		for resident: Dictionary in _npcs_by_chunk.get(c, []):
			_build_steps.append(_build_resident.bind(root, resident))
	_build_steps.append(_build_pack_sites.bind(c, area))


func _build_house(root: Node3D, building: Dictionary) -> void:
	root.add_child(VillageHouse.new().setup(building))


func _build_pack_sites(c: Vector2i, area: Rect2i) -> void:
	enemy_director.add_sites(c, generator.pack_sites(area, _keep_clear))


func _build_town_tree(root: Node3D, tree: Dictionary) -> void:
	var biome := Biomes.get_biome(tree.biome)
	var planted := Obstacle.new().setup("", ObstacleLibrary.get_prefab(tree.prefab), biome, true)
	planted.position = tree.pos
	planted.rotation.y = tree.yaw
	root.add_child(planted)


func _build_service(root: Node3D, service: Dictionary) -> void:
	# A signpost beside the keeper, square to the house front.
	var words: String = {smith = "Forge", magician = "Arcane Lodge", inn = "Lodge", herbalist = "Herbs"}.get(service.role, "Home")
	var icon: String = {smith = "sword", magician = "potion", inn = "beer", herbalist = "heart"}.get(service.role, "")
	var sign := SignBoard.post(words, "plank", icon, 2.0, 0.55)
	var yaw := float(service.npc.get("yaw", 0.0))
	sign.position = service.door+Vector3(cos(yaw), 0, -sin(yaw))*1.6+Vector3.DOWN*1.0
	sign.rotation.y = yaw
	root.add_child(sign)


func _build_resident(root: Node3D, resident: Dictionary) -> void:
	if not _town_navigation.has(resident.village):
		_town_navigation[resident.village] = TownNavigation.new(_village_plans[resident.village], self)
	var npc := TownNPC.new().setup(resident, _town_navigation[resident.village])
	root.add_child(npc)
	npc.add_child(_talk_target(resident))


func _build_obstacles(root: Node3D, area: Rect2i) -> void:
	for site in generator.obstacle_sites(area, _keep_clear, KEEP_CLEAR_RADIUS):
		if _destroyed.has(site.id):
			continue
		var obstacle := Obstacle.new().setup(site.id, ObstacleLibrary.get_prefab(site.prefab),
				Biomes.get_biome(site.biome))
		obstacle.position = site.pos
		obstacle.rotation.y = site.yaw
		obstacle.destroyed.connect(_on_obstacle_destroyed)
		root.add_child(obstacle)
		_obstacles[site.id] = obstacle
		obstacle.tree_exiting.connect(func() -> void: _obstacles.erase(site.id))
		if site.prefab == "campfire":
			obstacle.ignite(0.15, 1.0)
		elif site.prefab == "burnt_tree":
			var chance := BURNING_CHANCE_DOOM if site.biome == Biomes.DOOM else BURNING_CHANCE
			if hash(site.id) % 100 < chance * 100.0:
				obstacle.ignite(-1.0, 1.4)


func _build_lamps(root: Node3D, c: Vector2i) -> void:
	if _lamps_by_chunk.get(c, []).is_empty(): return
	var prefab := ObstacleLibrary.get_prefab("lamppost")
	for site in _lamps_by_chunk.get(c, []):
		var biome := biome_at(site.pos)
		if biome.obstacle_colors.is_empty():
			biome = Biomes.get_biome(Biomes.WOODS)
		var lamp := Obstacle.new().setup("", prefab, biome, true)
		lamp.position = site.pos
		lamp.rotation.y = site.yaw
		root.add_child(lamp)


## Grass, flowers, crops, reeds, bushes, small stones (SurfaceFlora): one
## MultiMesh per kind in the chunk. No collision; clients only.
func _gather_decor(groups: Dictionary, area: Rect2i) -> void:
	SurfaceFlora.gather(self, area, groups)


func _finish_decor(root: Node3D, groups: Dictionary) -> void:
	# One kind of plant per step, so no single frame builds them all.
	for kind: String in groups:
		_build_steps.push_front(SurfaceFlora.build_kind.bind(root, kind, groups[kind]))


## Trees: trunk collision everywhere, meshes on clients.
func _build_trees(root: Node3D, area: Rect2i) -> void:
	SurfaceFlora.build_trees(self, root, area, not server_build)


## Rivers, lakes and waterfalls in this chunk.
func _build_water(root: Node3D, c: Vector2i, area: Rect2i) -> void:
	var water := SurfaceWater.build_chunk(generator.map, area)
	if water: root.add_child(water)
	for fall: Dictionary in _falls_by_chunk.get(c, []):
		if float(fall.top) - float(fall.bottom) > 1.6:
			root.add_child(SurfaceWater.waterfall_mist(fall))


## A camp: tents around a crackling fire in a stone ring.
func _build_camp(root: Node3D, camp: Dictionary) -> void:
	for tent: Dictionary in camp.tents:
		root.add_child(VillageHouse.new().setup({asset = tent.asset, pos = Vector3(tent.pos[0], tent.pos[1], tent.pos[2]),
			yaw = float(tent.yaw), scale = float(tent.scale), solid_size = Vector3(tent.solid[0], tent.solid[1], tent.solid[2]),
			solid_offset = Vector3(tent.offset[0], tent.offset[1], tent.offset[2])}))
	var ring := Obstacle.new().setup("", ObstacleLibrary.get_prefab("surface/campfire_ring"), Biomes.get_biome(int(camp.biome)), true)
	ring.position = Vector3(camp.fire[0], camp.fire[1], camp.fire[2])
	root.add_child(ring)
	if not server_build:
		ring.ignite(0.2, 1.0)


## Who the grass leans away from: the local player, other players and
## creatures near the camera (clients only; the server grows no grass).
func _process(delta: float) -> void:
	super._process(delta)
	if server_build or Net.is_server(): return
	var camera := get_viewport().get_camera_3d()
	if camera == null: return
	var eye := camera.global_position
	var found: Array = []
	for node in get_tree().get_nodes_in_group("local_player") + get_tree().get_nodes_in_group("remote_players"):
		var body := node as Node3D
		if body and body.is_visible_in_tree():
			found.append([body.global_position, 0.75])
	for node in get_tree().get_nodes_in_group("realm_creatures"):
		var creature := node as Enemy
		if creature == null or not creature.is_inside_tree(): continue
		var at := creature.global_position
		if at.distance_squared_to(eye) > 4900.0: continue
		var size := 0.6
		if creature.def: size = maxf(0.5, creature.def.hit_radius * creature.def.model_scale + 0.25)
		found.append([at, size])
	found.sort_custom(func(a: Array, b: Array) -> bool: return (a[0] as Vector3).distance_squared_to(eye) < (b[0] as Vector3).distance_squared_to(eye))
	for i in _pushers.size():
		if i < found.size():
			var p: Vector3 = found[i][0]
			_pushers[i] = Vector4(p.x, p.y, p.z, found[i][1])
		else:
			_pushers[i] = Vector4.ZERO
	SurfaceFlora.set_pushers(_pushers)



## Breakable obstacles (ids) within `radius` of `pos` (a gravestone landing).
func obstacles_near(pos: Vector3, radius: float) -> Array:
	var out := []
	for id: String in _obstacles:
		var o: Obstacle = _obstacles[id]
		if is_instance_valid(o) and not o.indestructible and Vector2(o.global_position.x - pos.x, o.global_position.z - pos.z).length() < radius:
			out.append(id)
	return out


## Someone else hit this obstacle (online): it chips here too, and keeps count.
func hit_obstacle(obstacle_id: String, damage: int, at: Vector3) -> void:
	var o: Obstacle = _obstacles.get(obstacle_id)
	if is_instance_valid(o):
		o.net_remote = true
		o.take_hit(at, Vector3.ZERO, damage)
		if is_instance_valid(o):
			o.net_remote = false


## Someone else broke this obstacle (online): it breaks here too.
func remove_obstacle(obstacle_id: String) -> void:
	_destroyed[obstacle_id] = true
	var o: Obstacle = _obstacles.get(obstacle_id)
	if is_instance_valid(o):
		o.destroyed.disconnect(_on_obstacle_destroyed)
		o.net_remote = true
		o.take_hit(o.global_position, Vector3.ZERO, 1 << 30)


func _on_obstacle_destroyed(obstacle: Obstacle) -> void:
	_destroyed[obstacle.obstacle_id] = true
	obstacle_broken.emit(obstacle)
	WorldServer.report_obstacle_destroyed(realm_id, obstacle.obstacle_id)


## Debug helper: an open, walkable spot as close as possible to the middle
## of the first feature of a type (not inside a wall or pillar).
func find_feature_point(type: String) -> Vector3:
	for f in generator.features:
		if f.type != type:
			continue
		for ring in range(0, int(f.radius) + 6):
			for k in maxi(1, ring * 8):
				var p := Vector2(f.center) + Vector2.from_angle(k * TAU / maxi(1, ring * 8)) * ring
				var x := floori(p.x)
				var z := floori(p.y)
				if generator._detail(x, z).size() == 4 and is_walkable(Vector3(x, 0, z)):
					return generator.surface(Vector2(x, z))
	return spawn_point


## Debug helper: a walkable spot inside the given biome, searching rings
## outward from where that biome usually lies.
func find_biome_point(biome_id: int) -> Vector3:
	var from := Vector2(spawn_point.x, spawn_point.z)
	for ring in range(6, int(IslandGenerator.RADIUS) * 2, 6):
		for k in 64:
			var p := from + Vector2.from_angle(k / 64.0 * TAU) * ring
			if generator.map.cell_biome(floori(p.x), floori(p.y)) == biome_id and generator.walkable(p.x, p.y):
				return generator.surface(p)
	return spawn_point


## Enemies on the Surface walk on the ground height instead of sliding
## their bodies over the fine voxel terrain (far too costly for a whole pack):
## they stop colliding with the terrain and are set onto it every frame. Trees,
## rocks and houses still block them physically.
func hold_enemy(enemy: CharacterBody3D) -> void:
	if enemy.collision_mask & Player.TERRAIN_LAYER:
		enemy.collision_mask &= ~Player.TERRAIN_LAYER
	var ground := ground_height(enemy.global_position.x, enemy.global_position.z)
	enemy.global_position.y = ground
	enemy.velocity.y = 0.0


## What the terrain collision used to stop: walls more than a step high and
## the walls of fortresses and ruins.
func enemy_step_blocked(from: Vector3, to: Vector3) -> bool:
	if ground_height(to.x, to.z) > from.y + Player.STEP_HEIGHT:
		return true
	if not generator._shape_grid.has(Vector2i(floori(to.x) >> IslandGenerator.FEATURE_CELL_SHIFT, floori(to.z) >> IslandGenerator.FEATURE_CELL_SHIFT)):
		return false
	var detail: Variant = generator._feature_detail(floori(to.x), floori(to.z))
	if detail == null: return false
	for i in range(4, detail.size(), 3):
		if detail[i] < from.y + 1.8 and detail[i + 1] > from.y + 0.1:
			return true
	return false


func enemy_spawn_clear(pos: Vector3, radius: float, height: float) -> bool:
	for clear in _keep_clear:
		if Vector2(pos.x - clear.x, pos.z - clear.z).length() < KEEP_CLEAR_RADIUS + radius:
			return false
	return generator.enemy_spawn_clear(pos, radius, height) and super.enemy_spawn_clear(pos, radius, height)
