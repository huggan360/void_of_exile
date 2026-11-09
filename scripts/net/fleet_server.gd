class_name FleetServer
extends Node
## Global account-service deployments, with local pad reservations and occupancy.
const IDLE_SECONDS := 120.0
const NEAR_DISTANCE := 120.0
const SAVE_EVERY := 15.0
var server: NetServer
var active := {}  # global ship id -> {world, ship, token, deadline, idle, saving, next}
var _players_busy := {}
var _pads := {}
var _sequence := 0
var _timer := 0.0

func _send(p: Dictionary, data: Dictionary) -> void:
	server.social.send(p.player_id, ["fleet", data])

func _error(p: Dictionary, message: String) -> void:
	_send(p, {error = message})
	server.social.system(p.player_id, message)

func _context(p: Dictionary) -> Dictionary:
	var realm: RealmInstance = server.realms.get(p.get("realm", ""))
	if realm==null: return {}
	var at: Vector3 = p.pos
	if realm.world is IslandWorld:
		var dock := (realm.world as IslandWorld).surface_ships
		if not is_instance_valid(dock) or at.distance_to(dock.surface.launchpad_center())>PortServer.PAD_REACH or not server._astral_unlocked(p): return {}
		return {world = dock, pose = dock.pad_pose(), key = realm.realm_id+":surface", planet = "surface", label = "Surface launch pad"}
	if realm.world is SpaceWorld:
		var space := realm.world as SpaceWorld
		if space.zone_at(at)=="station":
			for berth in SpaceLayout.BERTHS:
				var pose := SpaceLayout.berth_frame(berth)
				if not _occupied(space, pose.origin) and not _pads.has(realm.realm_id+":berth:"+str(berth)): return {world = space, pose = pose, key = realm.realm_id+":berth:"+str(berth), planet = "", berth = berth, label = "Nexus berth %d" % (berth+1)}
			return {world = space, pose = SpaceLayout.berth_frame(0), key = realm.realm_id+":berth:0", planet = "", berth = 0, label = "Nexus berth 1"}
		for spec: Dictionary in SpaceLayout.PLANETS:
			# The landing pad's crystal: ships come out onto that pad.
			if not spec.get("city", false) and at.distance_to(SpaceLayout.pad_crystal(spec))<=SpaceWorld.TRADER_REACH:
				var port: Dictionary = SpaceLayout.ports(spec)[0]
				return {world = space, pose = port.pose, key = realm.realm_id+":"+str(spec.id)+":pad", planet = str(spec.id), port = str(port.key), label = str(port.name), store = false}
			if at.distance_to(space.trader_position(str(spec.id), "wright"))>SpaceWorld.TRADER_REACH \
					and (spec.get("city", false) or at.distance_to(SpaceLayout.dock_crystal(spec))>SpaceWorld.TRADER_REACH): continue
			var frame := SpaceLayout.town_frame(spec, "dock")
			var pose := Transform3D(frame.basis, (spec.center as Vector3)+frame.origin+frame.basis.y*SpaceShip.LANDED_HEIGHT)
			return {world = space, pose = pose, key = realm.realm_id+":"+str(spec.id), planet = str(spec.id), label = str(spec.name)+" shipyard"}
	return {}

func _occupied(world: SpaceWorld, at: Vector3, except_id := 0) -> bool:
	for ship: SpaceShip in world.ships.values():
		if ship.id!=except_id and ship.xform.origin.distance_to(at)<45.0: return true
	return false

func _free_slot(world: SpaceWorld) -> bool:
	return world.ships.size()<SpaceLayout.POCKET_SLOTS

func on_action(p: Dictionary, args: Array) -> void:
	if args.is_empty() or p.get("dead", false) or p.get("switching", false): return
	var pid := int(p.player_id)
	if _players_busy.has(pid): return
	var context := _context(p)
	if context.is_empty():
		_error(p, "Visit a shipwright to manage your fleet.")
		return
	_players_busy[pid] = true
	await _action(p, args, context)
	_players_busy.erase(pid)

func _action(p: Dictionary, args: Array, context: Dictionary) -> void:
	var op := str(args[0])
	if op=="recall":
		# Ships are stored only at a shipwright (not at a pad crystal).
		if not bool(context.get("store", true)):
			_error(p, "Ships are stored at a shipwright.")
			return
		var id := int(args[1]) if args.size()>1 else 0
		var entry: Dictionary = active.get(id, {})
		if entry.is_empty() or int((entry.ship as SpaceShip).account_id)!=int(p.account_id):
			_error(p, "That ship is in use on another server or is not yours.")
			return
		var ship := entry.ship as SpaceShip
		var world := (entry.world as WeakRef).get_ref() as SpaceWorld
		if not is_instance_valid(world) or not ship.mode in ["landed", "berth"] or not world._aboard(ship).is_empty():
			_error(p, "Land the ship and have everyone disembark before storing it.")
			return
		if not await store(id):
			_error(p, "Couldn't store the ship. Try again.")
			return
		op = "list"
	if not op in ["list", "buy", "deploy"]: return
	var body := {operation = op, character_id = p.character_id}
	var key := str(context.key)
	if op=="deploy":
		if args.size()<2: return
		if _pads.has(key) or _occupied(context.world, context.pose.origin) or not _free_slot(context.world):
			_error(p, "The launch pad is occupied. Wait until it is clear.")
			return
		_pads[key] = INF
		body.ship_id = int(args[1])
		body.location = str(context.label)
	elif op=="buy":
		if not p.has("fleet_purchase_request"):
			_sequence += 1
			p.fleet_purchase_request = "%d:%d:%d:%d" % [Time.get_unix_time_from_system(), OS.get_process_id(), p.character_id, _sequence]
		body.request_id = p.fleet_purchase_request
	var response: Dictionary = await server.api.call_api("POST", "/server/fleet", body)
	if op=="deploy": _pads.erase(key)
	if not response.ok:
		_error(p, str(response.error))
		return
	if op=="buy": p.erase("fleet_purchase_request")
	if op=="deploy":
		var deployment: Dictionary = response.data.deployment
		var current := _context(p)
		if current.is_empty() or current.world!=context.world or _occupied(context.world, context.pose.origin):
			await server.api.call_api("POST", "/server/fleet", {operation = "store", ship_id = deployment.id, token = deployment.token, state = deployment.state})
			_error(p, "The launch pad changed. Your ship is still in storage.")
			return
		var world := context.world as SpaceWorld
		var ship := world.create_fleet_ship(p, deployment, context)
		if ship==null:
			await server.api.call_api("POST", "/server/fleet", {operation = "store", ship_id = deployment.id, token = deployment.token, state = deployment.state})
			_error(p, "No ship room is available. Your ship is still in storage.")
			return
		active[ship.fleet_id] = {world = weakref(world), ship = ship, token = deployment.token, deadline = Net.now()+float(deployment.lease_seconds)-AccountApi.TIMEOUT-5.0, idle = 0.0, saving = false, next = Net.now()+SAVE_EVERY}
		world._broadcast_ship(ship)
		# Re-read after deployment so the shop displays its authoritative status.
		var latest: Dictionary = await server.api.call_api("POST", "/server/fleet", {operation = "list", character_id = p.character_id})
		if latest.ok: response = latest
	p.dots = int(response.data.dots)
	server.social.send(p.player_id, ["dots", p.dots, 0, "fleet"])
	_send(p, _view(response.data, context))

func _view(data: Dictionary, context: Dictionary) -> Dictionary:
	var result := data.duplicate(true)
	result.erase("deployment")  # Deployment tokens are authority-only, including on a failed re-read.
	result.pad_clear = not _pads.has(str(context.key)) and not _occupied(context.world, context.pose.origin)
	for row: Dictionary in result.get("ships", []):
		var entry: Dictionary = active.get(int(row.id), {})
		var world := (entry.world as WeakRef).get_ref() as SpaceWorld if not entry.is_empty() else null
		row.can_recall = bool(context.get("store", true)) and is_instance_valid(world) and (entry.ship as SpaceShip).mode in ["landed", "berth"] and world._aboard(entry.ship).is_empty()
	return result

func adopt(world: SpaceWorld, ship: SpaceShip) -> void:
	if ship.fleet_id==0 or not active.has(ship.fleet_id): return
	var entry: Dictionary = active[ship.fleet_id]
	entry.world = weakref(world)
	entry.ship = ship
	entry.idle = 0.0
	entry.next = Net.now()  # Update the global location after the handoff.

func _process(delta: float) -> void:
	_timer -= delta
	if _timer>0.0: return
	_timer = 1.0
	for key in _pads.keys():
		if float(_pads[key])<Net.now(): _pads.erase(key)
	for id: int in active.keys():
		var entry: Dictionary = active.get(id, {})
		if entry.is_empty(): continue
		var world := (entry.world as WeakRef).get_ref() as SpaceWorld
		var ship := entry.ship as SpaceShip
		if bool(entry.get("pending_store", false)):
			if not entry.saving: _save(id, "store")
			continue
		if bool(entry.get("destroyed", false)):
			if not entry.saving: _save(id, "destroy")
			continue
		if not is_instance_valid(world):
			# The world unloaded: release its snapshot instead of losing the paid ship.
			if not entry.saving: store(id)
			continue
		if Net.now()>=float(entry.deadline):
			# Fail closed before the account service may recycle the deployment.
			_evict(world, ship)
			active.erase(id)
			continue
		var nearby := not world._aboard(ship).is_empty()
		var realm: RealmInstance = server.realms.get(world.realm_id)
		if realm:
			for proxy in realm.proxies.values():
				if proxy.global_position.distance_to(ship.xform.origin)<=NEAR_DISTANCE: nearby = true
		if ship.mode in ["landed", "berth"] and not nearby: entry.idle = float(entry.idle)+1.0
		else: entry.idle = 0.0
		if float(entry.idle)>=IDLE_SECONDS and not entry.saving: store(id)
		elif Net.now()>=float(entry.next) and not entry.saving: _save(id, "heartbeat")

func _evict(world: SpaceWorld, ship: SpaceShip) -> void:
	for pid: int in world._aboard(ship):
		var p := server.social.record(pid)
		world.teleport(p, world.surface.launchpad_arrival() if world is SurfaceShipWorld else world.spawn_point, "station")
	world._retire(ship)

func _save(id: int, operation: String) -> bool:
	var entry: Dictionary = active.get(id, {})
	if entry.is_empty() or entry.saving: return false
	entry.saving = true
	var ship := entry.ship as SpaceShip
	if operation=="store": ship.mode = "storing"
	var world := (entry.world as WeakRef).get_ref() as SpaceWorld
	if operation=="store":
		entry.pending_store = true
		# Remove the empty hull before releasing its global claim. Even if the
		# acknowledgement is lost, another server can never duplicate this hull.
		if is_instance_valid(world) and world.ships.has(ship.id): world._retire(ship)
	var response: Dictionary = await server.api.call_api("POST", "/server/fleet", {operation = operation, ship_id = id, token = entry.token, state = ship.fleet_state(), location = world.display_name if is_instance_valid(world) else ""})
	entry.saving = false
	entry.next = Net.now()+(SAVE_EVERY if response.ok else 3.0)
	if not response.ok:
		if int(response.get("status", 0))==409 and operation in ["store", "destroy"]: active.erase(id)
		return false
	if operation=="heartbeat" and not active.has(id):
		await server.api.call_api("POST", "/server/fleet", {operation = "destroy" if ship.hp<=0 else "store", ship_id = id, token = entry.token, state = ship.fleet_state()})
		return true
	if operation in ["store", "destroy"]:
		active.erase(id)
		if is_instance_valid(world) and world.ships.has(ship.id): world._retire(ship)
	else:
		entry.deadline = Net.now()+float(response.data.lease_seconds)-AccountApi.TIMEOUT-5.0
		if ship.hp<=0:
			var committed := false
			for row: Dictionary in response.data.get("ships", []):
				if int(row.id)==id and str(row.status)=="destroyed": committed = true
			if committed: active.erase(id)
			else: entry.destroyed = true  # A fatal hit raced an older in-flight heartbeat.
	return true

func store(id: int) -> bool:
	return await _save(id, "store")

func destroyed(ship: SpaceShip) -> void:
	if ship.fleet_id>0 and active.has(ship.fleet_id):
		active[ship.fleet_id].destroyed = true
		if not active[ship.fleet_id].saving: _save(ship.fleet_id, "destroy")

func reserve_landing(source: SpaceWorld, ship: SpaceShip) -> bool:
	var destination := source.surface_realm()
	var key := destination+":surface"
	if _pads.has(key): return false
	var realm: RealmInstance = server.realms.get(destination)
	if realm and realm.world is IslandWorld:
		var dock := realm.world.surface_ships as SurfaceShipWorld
		if not is_instance_valid(dock) or _occupied(dock, dock.pad_pose().origin) or not _free_slot(dock): return false
	_pads[key] = Net.now()+45.0
	return true

func landed(realm: String) -> void:
	_pads.erase(realm+":surface")

## A graceful server shutdown returns paid ships to storage, not to wrecks.
func save_all() -> void:
	for id: int in active.keys():
		var until := Time.get_ticks_msec()+12000
		while active.has(id) and bool(active[id].saving) and Time.get_ticks_msec()<until:
			await get_tree().process_frame
		if not active.has(id) or bool(active[id].saving): continue
		var entry: Dictionary = active[id]
		await _save(id, "destroy" if bool(entry.get("destroyed", false)) or (entry.ship as SpaceShip).hp<=0 else "store")
