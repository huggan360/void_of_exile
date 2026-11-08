class_name RealmInstance
extends SubViewport
## One running realm on the dedicated server: its island (built only for
## collision, see IslandWorld.server_build), its enemies and their director,
## in a physics world of its own so realms never touch each other.
## Players in it are NetPlayerProxy nodes.

var realm_id := ""
var record: Dictionary
var world
var bullets := EnemyBullets.new()
## player id -> NetPlayerProxy
var proxies := {}
## net id -> Enemy (registered as they enter the tree, see NetServer)
var enemies := {}
## Gravestones of characters who fell here: [{pos, title}].
var graves: Array[Dictionary] = []
## How long it has been empty (it's unloaded after a while).
var empty_for := 0.0
var _bag_spots := LootBags.new()


func _init(p_record: Dictionary) -> void:
	record = p_record
	realm_id = record.id
	own_world_3d = true
	size = Vector2i(2, 2)
	render_target_update_mode = SubViewport.UPDATE_DISABLED
	set_meta(&"net_realm", realm_id)


func _ready() -> void:
	if record.get("castle", false):
		world = load("res://scenes/castle/hollow_castle.tscn").instantiate()
		world.realm_id = realm_id
		world.display_name = record.get("name", "The Hollow Castle")
	else:
		world = Dungeons.create_world(record) if record.has("dungeon") else SpaceWorld.new(record) if record.get("space", false) else IslandWorld.new(record)
	world.server_build = true
	world.set_meta(&"net_realm", realm_id)
	add_child(world)
	if world is SpatialWorld:
		world.world_event.connect(func(event: Array) -> void:
			if Net.server!=null: Net.server._to_realm(realm_id,Vector3.INF,["theory",event]))
	if world is IslandWorld and is_instance_valid(world.surface_ships):
		world.surface_ships.world_event.connect(func(event: Array) -> void:
			if Net.server!=null: Net.server._to_realm(realm_id,Vector3.INF,["theory",event]))
	GameServer.set_environment(world)
	bullets.name = "EnemyBullets"
	world.add_child(bullets)
	world.enemy_director.setup(null, bullets, world.cleared_packs(), world.pack_survivors())
	GameServer.set_spot_finder(realm_id, func(origin: Vector3, taken: Array) -> Vector3:
		return _bag_spots.find_spot(world, origin, taken) if is_instance_valid(world) else origin)


func _exit_tree() -> void:
	_bag_spots.free()


func add_player(player_id: int, peer_id: int) -> NetPlayerProxy:
	var proxy := NetPlayerProxy.new()
	proxy.player_id = player_id
	proxy.peer_id = peer_id
	proxy.name = "Player_%d" % player_id
	world.add_child(proxy)
	proxy.global_position = world.spawn_point
	proxies[player_id] = proxy
	world.enemy_director.players.append(proxy)
	world.update_streaming_multi(_positions(), true)
	empty_for = 0.0
	return proxy


func remove_player(player_id: int) -> void:
	var proxy: NetPlayerProxy = proxies.get(player_id)
	if proxy:
		world.enemy_director.players.erase(proxy)
		proxy.queue_free()
	proxies.erase(player_id)


func _physics_process(delta: float) -> void:
	if proxies.is_empty():
		empty_for += delta
		return
	world.update_streaming_multi(_positions())


func _positions() -> Array:
	return proxies.values().map(func(p: NetPlayerProxy) -> Vector3: return p.global_position)
