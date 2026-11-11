class_name IslandWorld
extends GameWorld
## A realm: a seeded island whose record (seed + destroyed obstacles) comes
## from the WorldServer. Players arrive in the central village next to a portal home.
##
## The island is big, so obstacles, lampposts and ground clutter are streamed:
## they're built in 32 x 32 block chunks around the player and freed again
## when the player moves away. Terrain streams on its own (VoxelTerrain).
##
## On the dedicated server (`server_build`) only what enemies collide with is
## built (terrain, obstacles, houses), around every player in the realm
## (update_streaming_multi); no decor, lights, signs or townsfolk.

const KEEP_CLEAR_RADIUS := 9.0
## Share of burnt trees that are still burning (Doom vs. elsewhere).
const BURNING_CHANCE_DOOM := 0.55
const BURNING_CHANCE := 0.3
const DECOR_DRAW_DISTANCE := 60.0
const CHUNK := 32
const LOAD_RADIUS := 4  # chunks around the player that are kept built (~128 m)
const STREAM_BUDGET_USEC := 1000
const UNLOADS_PER_FRAME := 1
const BUILD_TILE := 4

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
	# Every realm is the static island laid out in res://realm/realm_layout.tscn.
	generator = IslandGenerator.new(record.seed,prepared_layout if not prepared_layout.is_empty() else RealmLayout.data())
	if record.get("astral_station",false): astral_site = AstralStation.plan(generator)
	half_extent = int(IslandGenerator.RADIUS) + 48
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


## Clients and the server resolve identical stations before chunk indexing.
func _place_townsfolk(village: VillageFeature) -> void:
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
		assert(best != Vector3.INF, "No reachable town station in " + village.display_name)
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
		if not server_build:
			for prefab in biome.decor: ObstacleLibrary.get_prefab(str(prefab)).meshes_for(biome)
	if not server_build:
		VoxelFire.warm(1.0)
		VoxelFire.warm(1.4)

func _ready() -> void:
	if not get_meta("assets_prepared",false): _warm_stream_assets()
	var r := half_extent
	_add_terrain(generator, AABB(Vector3(-r, -8, -r), Vector3(r * 2, IslandGenerator.MAX_HEIGHT + 16, r * 2)),
		"surface_%d" % generator.realm_seed, ["res://realm/realm_layout.tscn", "res://scripts/world/realm_feature.gd"])
	if not server_build:
		_add_water(IslandGenerator.SEA_LEVEL + 0.6, r + 300.0)
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
	if center != _center_chunk:
		_center_chunk = center
		_queue.clear()
		for dz in range(-LOAD_RADIUS, LOAD_RADIUS + 1):
			for dx in range(-LOAD_RADIUS, LOAD_RADIUS + 1):
				var c := center + Vector2i(dx, dz)
				if not _chunks.has(c):
					_queue.append(c)
		# Nearest chunks first.
		_queue.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
			return (a - center).length_squared() < (b - center).length_squared())
	var keep := {}
	for c: Vector2i in _chunks:
		if maxi(absi(c.x - center.x), absi(c.y - center.y)) <= LOAD_RADIUS + 1:
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
	# Shallow water (one block under the surface) is fine; deeper is not.
	# Lava pits can be walked into, but they burn (see is_hazard).
	return generator.column(floori(pos.x), floori(pos.z)).x >= IslandGenerator.SEA_LEVEL - 1


func is_hazard(pos: Vector3) -> bool:
	if SpaceLayout.pocket_at(pos)>=0: return false
	return Blocks.is_hazard(generator.surface_block(floori(pos.x), floori(pos.z)))

func is_water(pos: Vector3) -> bool:
	if SpaceLayout.pocket_at(pos)>=0: return false
	# Also available on the headless server, where the water mesh is omitted.
	return pos.y<=IslandGenerator.SEA_LEVEL+0.7 and not is_hazard(pos)


func astral_anchor(key: String) -> Vector3:
	if not astral_site.is_finite(): return Vector3.INF
	var at: Vector3 = astral_site+(AstralStation.ROCKET_OFFSET if key=="rocket" else AstralStation.OFFSETS.get(key,Vector3.ZERO))
	at.y = generator.column(floori(at.x), floori(at.z)).x+1.0
	return at


func ground_height(x: float, z: float) -> float:
	return generator.column(floori(x), floori(z)).x + 1.0


func map_color(x: int, z: int) -> Color:
	var top := generator.top_of(x, z)
	var c := shade_for_map(Blocks.map_color(top.y), top.x, generator.column(x - 1, z).x, IslandGenerator.SEA_LEVEL)
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
	_build_steps.append(_build_lamps.bind(root, c))
	for building: Dictionary in _buildings_by_chunk.get(c, []):
		_build_steps.append(_build_house.bind(root, building))
	if not server_build:
		var decor_groups := {}
		for z in range(0, CHUNK, BUILD_TILE):
			for x in range(0, CHUNK, BUILD_TILE):
				_build_steps.append(_gather_decor.bind(decor_groups, Rect2i(area.position + Vector2i(x, z), Vector2i(BUILD_TILE, BUILD_TILE))))
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
	var biome := Biomes.get_biome(Biomes.BEACH if tree.prefab == "palm" else tree.biome)
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


## Grass tufts, flowers, pebbles...: one MultiMesh per prefab and biome color
## set in the chunk. No collision; they're just decoration.
func _gather_decor(groups: Dictionary, area: Rect2i) -> void:
	var tile := generator.decor_sites(area)
	for key: String in tile:
		if not groups.has(key): groups[key] = []
		for transform: Transform3D in tile[key]:
			groups[key].append(transform)


func _finish_decor(root: Node3D, groups: Dictionary) -> void:
	for key: String in groups:
		_build_steps.append(_build_decor_group.bind(root, key, groups[key]))


func _build_decor_group(root: Node3D, key: String, transforms: Array) -> void:
	var parts := key.split("/")
	var prefab := ObstacleLibrary.get_prefab(parts[0])
	var meshes := prefab.meshes_for(Biomes.get_biome(int(parts[1])))
	var local := Transform3D(Basis.from_scale(Vector3.ONE * prefab.voxel_size), prefab.mesh_offset())
	for i in 2:
		if meshes[i] == null:
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = meshes[i]
		mm.instance_count = transforms.size()
		for j in mm.instance_count:
			mm.set_instance_transform(j, transforms[j] * local)
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = VoxModel.glow_material() if i == 1 else VoxModel.material()
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mmi.visibility_range_end = DECOR_DRAW_DISTANCE
		root.add_child(mmi)


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
	var typical := 0.74
	if biome_id in [Biomes.DOOM, Biomes.FOSEN, Biomes.BLUELAY, Biomes.DEEP_DESERT]:
		typical = 0.35
	elif biome_id == Biomes.DEEP_DARK:
		typical = 0.05
	var rings := range(6, int(IslandGenerator.RADIUS), 6)
	rings.sort_custom(func(a: int, b: int) -> bool:
		return absf(a - typical * IslandGenerator.RADIUS) < absf(b - typical * IslandGenerator.RADIUS))
	for ring: int in rings:
		for k in 48:
			var a := k / 48.0 * TAU
			var p := Vector2(cos(a), sin(a)) * ring
			var col := generator.column(floori(p.x), floori(p.y))
			if col.y == biome_id and col.x >= IslandGenerator.SEA_LEVEL:
				return generator.surface(p)
	return spawn_point


func enemy_spawn_clear(pos: Vector3, radius: float, height: float) -> bool:
	for clear in _keep_clear:
		if Vector2(pos.x - clear.x, pos.z - clear.z).length() < KEEP_CLEAR_RADIUS + radius:
			return false
	return generator.enemy_spawn_clear(pos, radius, height) and super.enemy_spawn_clear(pos, radius, height)
