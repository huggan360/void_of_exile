class_name LootBags
extends Node3D
## Shows the loot bags of the place the local player is in. The bags
## themselves live on the server (GameServer): this draws the ones the
## player may see, follows the server's bag_added / bag_removed signals, and
## tells which bag the player is standing on.
##
## It also answers the server's question "where does a bag fit?" for the
## loaded world: on open, walkable ground near where it dropped, never inside
## an obstacle or a wall, never on water or lava, never on top of another
## bag. If the spot itself is taken, rings further out are tried.

const SPACING := 1.65  # bags stay at least this far apart
const STAND_RADIUS := 1.15  # standing this close to a bag opens it
const CLEARANCE := 0.65  # free space a bag needs around it
const MAX_CLIMB := 1.6  # don't put bags up on ledges or down in pits
const SEARCH_RINGS := 6

## The player on this machine.
var local_player: Player
var realm_id := ""
var _views := {}  # bag id -> LootBag


func _ready() -> void:
	GameServer.bag_added.connect(_on_bag_added)
	GameServer.bag_removed.connect(_on_bag_removed)
	GameServer.bag_changed.connect(_on_chest_changed)


## Switches to another place: shows the bags already lying there, and lets
## the server place new ones in this world.
func show_realm(p_realm_id: String, world: GameWorld) -> void:
	for view in _views.values():
		view.queue_free()
	_views.clear()
	realm_id = p_realm_id
	GameServer.set_spot_finder(realm_id, func(origin: Vector3, taken: Array) -> Vector3:
		return find_spot(world, origin, taken) if is_instance_valid(world) else origin)
	for record in GameServer.bags_in(realm_id, local_player.player_id):
		_on_bag_added(record)


## The bag `player` is standing on (the closest one shown), or null.
func bag_at(player: Node3D) -> LootBag:
	var best: LootBag = null
	var best_d := INF
	for view: LootBag in _views.values():
		var d := Vector2(view.global_position.x - player.global_position.x,
				view.global_position.z - player.global_position.z).length()
		if d <= STAND_RADIUS and absf(view.global_position.y - player.global_position.y) < 1.5:
			if view.type == "vault":
				view.open_chest()
			elif not view.opened and "player_id" in player:
				if GameServer.request_open_chest(player.player_id, view.bag_id): view.open_chest()
			if d < best_d:
				best = view
				best_d = d
		elif view.type == "vault" and view.opened:
			view.close_chest()
	return best


func _on_bag_added(record: Dictionary) -> void:
	if record.realm != realm_id or _views.has(record.id):
		return
	if record.viewer != GameServer.PUBLIC and record.viewer != local_player.player_id:
		return  # someone else's personal loot
	var view := LootBag.new(record)
	add_child(view)
	_views[record.id] = view


func _on_chest_changed(chest_id: int) -> void:
	var view: LootBag = _views.get(chest_id)
	if not is_instance_valid(view): return
	var record := GameServer.bag(chest_id)
	if bool(record.get("opened", false)) and view.type != "vault": view.open_chest()


func _on_bag_removed(bag_id: int) -> void:
	if _views.has(bag_id):
		_views[bag_id].queue_free()
		_views.erase(bag_id)


## The nearest free spot to `origin` in `world`, searching outward ring by
## ring. taken: where other bags already are.
func find_spot(world: GameWorld, origin: Vector3, taken: Array) -> Vector3:
	var ground := Vector3(origin.x, world.ground_height(origin.x, origin.z), origin.z)
	if _free(world, ground, origin.y, taken):
		return ground
	for ring in range(1, SEARCH_RINGS + 1):
		var r := ring * SPACING * 0.75
		var steps := 6 * ring
		var start := randf() * TAU
		for i in steps:
			var a := start + TAU * i / steps
			var p := origin + Vector3(cos(a), 0.0, sin(a)) * r
			p.y = world.ground_height(p.x, p.z)
			if _free(world, p, origin.y, taken):
				return p
	return ground


func _free(world: GameWorld, p: Vector3, from_y: float, taken: Array) -> bool:
	if absf(p.y - from_y) > MAX_CLIMB or not world.is_walkable(p) or world.is_hazard(p):
		return false
	for other: Vector3 in taken:
		if other.distance_to(p) < SPACING:
			return false
	# Nothing solid where the bag would sit (obstacles, walls, overhangs).
	var query := PhysicsShapeQueryParameters3D.new()
	var shape := SphereShape3D.new()
	shape.radius = CLEARANCE
	query.shape = shape
	query.transform = Transform3D(Basis(), p + Vector3.UP * (CLEARANCE + 0.12))
	query.collision_mask = Player.TERRAIN_LAYER | Player.OBSTACLE_LAYER
	for hit in world.get_world_3d().direct_space_state.intersect_shape(query, 8):
		if not hit.collider is CharacterBody3D:  # players and enemies don't block a bag
			return false
	return true
