class_name SurfaceShipWorld
extends SpaceWorld
## The same ship rooms and crew systems, docked in the Surface's physics world.
var surface: IslandWorld
var _departures := {}

func _init(island: IslandWorld) -> void:
	super({id = island.realm_id})
	surface = island
	server_build = island.server_build

func _ready() -> void:
	foes = SpaceFoes.new()
	foes.world = self
	foes.surface_combat = true
	add_child(foes)
	var probe := ShipInterior.new()
	probe.build(true)
	interior_anchors = probe.anchors.duplicate(true)
	probe.free()
	var hull := ShipHull.new()
	hull.build(Color.WHITE)
	hull_anchors = hull.anchors.duplicate(true)
	hull.free()

func game_root() -> Node:
	return surface.get_parent()

func pad_pose() -> Transform3D:
	return Transform3D(Basis.IDENTITY, surface.launchpad_center()+SurfaceLaunchpad.SHIP_REST)

func hatch_position(_ship: SpaceShip) -> Vector3:
	return surface.launchpad_arrival()

func request(args: Array) -> void:
	if Net.is_client(): Net.client.send_action("port", ["ship", args])
	elif is_instance_valid(local_player):
		server_action({player_id = local_player.player_id, peer_id = 0, pos = local_player.global_position, name = "You", account_id = 0}, args)

func server_action(p: Dictionary, args: Array) -> void:
	if args.is_empty(): return
	var op := str(args[0])
	if op == "board":
		var ship: SpaceShip = ships.get(int(args[1]) if args.size()>1 else 0)
		if ship==null or ship.mode!="landed" or not _may_board(ship, int(p.player_id)): return
		if (p.pos as Vector3).distance_to(surface.launchpad_arrival())>32.0: return
		teleport(p, pocket_point(ship.slot, interior_anchors.get("spawn", Vector3(0, 0.1, 14))), "board")
	elif op == "hatch":
		var ship := ship_in_slot(SpaceLayout.pocket_at(p.pos))
		if ship==null or ship.mode!="landed": return
		_stand(ship, int(p.player_id))
		_broadcast_ship(ship)
		teleport(p, surface.launchpad_arrival(), "surface")
	elif op == "takeoff":
		var ship := ship_of(int(p.player_id))
		if ship==null or ship.pilot()!=int(p.player_id) or ship.mode!="landed" or ship.broken: return
		if Net.is_server():
			for pid: int in _aboard(ship):
				if not Net.server._astral_unlocked(Net.server.social.record(pid)):
					_tell(p, "Everyone aboard must finish the Theory of Everything before travelling to Space.")
					return
		ship.mode = "ascending"
		_departures[ship.id] = 0.0
		_broadcast_ship(ship)
		var event: Array = ["launch_shake", ship.id]
		handle_event(event)
		world_event.emit(event)
	elif op in ["sit", "stand", "pilot", "drink", "cigar", "repair", "pour", "aim", "fire"]:
		if ship_in_slot(SpaceLayout.pocket_at(p.pos))!=null: super.server_action(p, args)

func _physics_process(delta: float) -> void:
	if Net.is_client(): return
	_burn_cigars(delta)
	_mend(delta)
	for ship: SpaceShip in ships.values().duplicate():
		if ship.mode=="ascending":
			var t := float(_departures.get(ship.id, 0.0))+delta
			_departures[ship.id] = t
			ship.xform = pad_pose()
			ship.xform.origin += Vector3.UP*maxf(0.0, t-1.0)*maxf(0.0, t-1.0)*20.0
			if t>=5.0:
				_departures.erase(ship.id)
				ship.mode = "transit"
				if Net.is_server(): Net.server.surface_port.launch_ship(self, ship)
				else: handle_event(["ship_travel", PortServer.space_for(realm_id), "launch", _aboard(ship)])
		elif ship.mode=="surface_landing":
			var t := minf(4.2, float(_departures.get(ship.id, 0.0))+delta)
			_departures[ship.id] = t
			ship.xform = pad_pose()
			ship.xform.origin += Vector3.UP*160.0*pow(1.0-t/4.2, 3.0)
			if t>=4.2:
				ship.mode = "landed"
				_departures.erase(ship.id)
	_snapshot_timer -= delta
	if _snapshot_timer<=0.0:
		_snapshot_timer = SNAPSHOT_INTERVAL
		for ship: SpaceShip in ships.values(): _broadcast_ship(ship)

func sample_gravity(at: Vector3) -> Dictionary:
	if SpaceLayout.pocket_at(at)>=0: return super.sample_gravity(at)
	return {frame = Transform3D(Basis.IDENTITY, Vector3(at.x, surface.ground_height(at.x, at.z), at.z)), zone = "surface", distance = 0.0}

func ensure_ship(p: Dictionary) -> SpaceShip:
	if Net.is_server(): return null  # Live ships must be claimed through the account fleet.
	var ship := _ship_of_owner(int(p.player_id))
	if ship: return ship
	ship = _launch_ship(int(p.player_id), str(p.get("name", "Captain")))
	if ship:
		ship.mode = "landed"
		ship.planet = "surface"
		ship.xform = pad_pose()
		_broadcast_ship(ship)
	return ship

func begin_arrival(_pid: int) -> void:
	var slot := SpaceLayout.pocket_at(local_player.global_position) if is_instance_valid(local_player) else -1
	var ship := ship_in_slot(slot)
	if ship and ship_views.has(ship.id): ship_views[ship.id].arrival_started = Time.get_ticks_msec()
