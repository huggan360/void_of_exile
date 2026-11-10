extends Node
## Temporary social items, seats and tabletop cups. The authority owns every
## sip, refill and seat reservation; equipment and inventory are never changed.
const SIP_TIME := 1.0
const CIGAR_TIME := 4.0
var players := {}
var tables := {}  # realm -> {spot id -> cup}
var world: GameWorld
var local_player: Player
var _revision := 0
var _table_nodes := {}
var _targets := {}
var _table_revisions := {}
var _hall_bench_seats := {}

func now() -> float:
	return Net.client.server_time() if Net.is_client() and Net.client else Net.now()

func state(pid: int) -> Dictionary:
	return players.get(pid, {})

func _ensure(pid: int, realm: String) -> Dictionary:
	if not players.has(pid):
		players[pid] = {realm = realm, cup = {}, seat = "", cigar = 0.0, use_at = -10.0, use = "", beer = [], rev = 0}
	return players[pid]

func hands_busy(pid: int) -> bool:
	var s := state(pid)
	return not s.get("cup", {}).is_empty() or float(s.get("cigar", 0.0))>now()

func smoking(pid: int) -> bool:
	return float(state(pid).get("cigar", 0.0))>now()

func request(actor: Player, args: Array) -> void:
	if Net.is_client(): Net.client.send_action("leisure", args)
	elif is_instance_valid(world):
		action({player_id = actor.player_id, realm = world.realm_id, pos = actor.global_position, peer_id = 0}, args, world)

func register_target(target: LeisureTarget) -> void:
	if not is_instance_valid(target.place): return
	var id := target.place.realm_id+"|"+target.key
	if not _targets.has(id): _targets[id] = []
	_targets[id].append(weakref(target))

func unregister_target(target: LeisureTarget) -> void:
	if not is_instance_valid(target.place): return
	var id := target.place.realm_id+"|"+target.key
	if not _targets.has(id): return
	_targets[id] = (_targets[id] as Array).filter(func(ref: WeakRef) -> bool: return is_instance_valid(ref.get_ref()) and ref.get_ref()!=target)
	if _targets[id].is_empty(): _targets.erase(id)

func reset() -> void:
	players.clear()
	tables.clear()
	_table_revisions.clear()
	_revision = 0
	for node in _table_nodes.values():
		if is_instance_valid(node): node.queue_free()
	_table_nodes.clear()
	world = null
	local_player = null

func resolve(place: GameWorld, id: String) -> Dictionary:
	if not is_instance_valid(place): return {}
	for ref: WeakRef in _targets.get(place.realm_id+"|"+id, []):
		var target := ref.get_ref() as LeisureTarget
		if is_instance_valid(target) and place.is_ancestor_of(target): return target.spec()
	# City furniture is streamed visually; its authored positions also exist
	# on the collision-only authority, so requests never depend on rendering.
	if place is SpaceWorld:
		if id.begins_with("citybench:"): return CityLayout.bench_seat(id)
		if id.begins_with("city:"):
			var spec := CityLayout.any_seat(id)
			if not spec.is_empty() and not CityState.npc_seat(id):
				return spec.merged({kind = "seat", key = id})
		elif id.begins_with("citycup|"):
			var seat := CityLayout.any_seat(id.substr(8))
			if not seat.is_empty(): return {kind = "table", key = id, pos = seat.cup, basis = seat.basis}
		elif id.begins_with("citytap|"):
			var venue := CityLayout.venue(id.substr(8))
			if not venue.is_empty() and venue.kind in ["bar", "speakeasy", "cafe", "teahouse"]:
				var frame: Transform3D = venue.frame
				frame.origin += CityLayout.planet().center as Vector3
				return {kind = "tap", key = id, pos = frame*Vector3(-2.5, 1.3, 4.1), drink = "coffee" if venue.kind in ["cafe", "teahouse"] else "beer"}
	return {}

func seat_spec(pid: int, place: GameWorld = null) -> Dictionary:
	var s := state(pid)
	var id := str(s.get("seat", ""))
	var at := place if place else world
	if id=="": return {}
	if not is_instance_valid(at): return _hall_bench(id) if s.get("realm", "")=="hall" else {}
	if s.get("realm", "")!=at.realm_id: return {}
	return resolve(at, id)

func occupied(realm: String, id: String, except_pid := 0) -> bool:
	for pid: int in players:
		if pid!=except_pid and players[pid].realm==realm and players[pid].seat==id: return true
	return false

func action(p: Dictionary, args: Array, place: GameWorld = null) -> void:
	if args.is_empty() or p.get("dead", false) or p.get("switching", false): return
	var pid := int(p.player_id)
	var s := _ensure(pid, str(p.realm))
	var op := str(args[0])
	var pos: Vector3 = p.pos
	var time := now()
	if op=="stand":
		var seat := seat_spec(pid, place)
		if seat.is_empty(): return
		s.seat = ""
		_correct(p, seat.stand)
		_publish(pid)
		return
	if time-float(s.use_at)<SIP_TIME: return
	match op:
		"sip":
			if smoking(pid):
				s.use_at = time
				s.use = "puff"
				s.cigar = time+CIGAR_TIME
			elif not s.cup.is_empty() and int(s.cup.sips)>0:
				s.cup.sips = int(s.cup.sips)-1
				s.use_at = time
				s.use = "sip"
				var stats := GameServer.character(pid)
				if str(s.cup.kind)=="beer":
					# Tell the campaign only about a successful server-validated
					# sip from a uniquely ordered city-pub mug. Ship beer and
					# drinks from elsewhere cannot count toward Mission 3.
					if Net.is_server() and Net.server:
						Net.server.campaigns.reach.vesperis_sip(p, str(s.cup.get("source", "")),
							str(s.cup.get("order", "")), int(s.cup.sips))
						Net.server.campaigns.reach.diner_sip(p, str(s.cup.get("source", "")),
							str(s.cup.get("order", "")), int(s.cup.sips))
					s.beer = (s.beer as Array).filter(func(t: float) -> bool: return time-t<=60.0)
					s.beer.append(time)
					if s.beer.size()>8: s.beer.pop_front()
					if s.beer.size()>=8 and stats: stats.buffs.add("drunk", StatusEffects.DRUNK_DURATION, 1, "beer")
				elif int(s.cup.sips)==0 and stats:
					stats.buffs.add("speed", 90.0, 4, "coffee")
			else: return
		"cigar":
			if smoking(pid): s.cigar = 0.0
			else:
				s.cigar = time+CIGAR_TIME
				s.use_at = time
				s.use = "puff"
		"drop":
			if smoking(pid): s.cigar = 0.0
			elif not s.cup.is_empty(): _drop(pid, p, place)
			else: return
		"use":
			if args.size()!=2: return
			var id := str(args[1])
			var spec := _hall_bench(id) if not is_instance_valid(place) and str(p.realm)=="hall" else resolve(place, id)
			if spec.is_empty() or pos.distance_to(spec.pos)>3.2: return
			match str(spec.kind):
				"seat":
					if occupied(str(p.realm), id, pid): return
					# Give up any ship/city seat before using a general chair.
					var dock: SpaceWorld = place if place is SpaceWorld else place.surface_ships if place is IslandWorld else null
					if dock:
						var vessel := dock.ship_of(pid)
						if vessel: dock._stand(vessel, pid); dock._broadcast_ship(vessel)
						if dock.city.stand(pid): dock._broadcast_city()
					s.seat = id
					_correct(p, spec.pos)
				"tap":
					if smoking(pid): return
					s.cup = {kind = str(spec.drink), sips = 4, source = id,
						order = "%d:%d" % [pid, Time.get_ticks_usec()]}
				"table":
					if smoking(pid): return
					var cups: Dictionary = tables.get(str(p.realm), {})
					if not s.cup.is_empty() and not cups.has(id):
						cups[id] = s.cup.duplicate(true)
						s.cup = {}
					elif s.cup.is_empty() and cups.has(id):
						s.cup = cups[id]
						cups.erase(id)
					else: return
					tables[str(p.realm)] = cups
					_revision += 1
					_table_revisions[str(p.realm)] = _revision
					_emit(str(p.realm), ["tables", str(p.realm), cups.duplicate(true), _revision])
				_: return
		_: return
	_publish(pid)

func _correct(p: Dictionary, at: Vector3) -> void:
	p.pos = at
	p.grace = NetServer.SNAP_BACK_GRACE*8.0
	if Net.is_server():
		var instance: RealmInstance = Net.server.realms.get(str(p.realm))
		if instance and instance.proxies.has(int(p.player_id)): instance.proxies[int(p.player_id)].global_position = at
		if int(p.get("peer_id", 0))>0: Net.c_correct.rpc_id(int(p.peer_id), at)
	elif is_instance_valid(local_player) and local_player.player_id==int(p.player_id):
		local_player.global_position = at
		local_player.velocity = Vector3.ZERO

func _publish(pid: int) -> void:
	if not Net.is_client() and hands_busy(pid): GameServer.set_shield(pid, false)
	_revision += 1
	players[pid].rev = _revision
	_emit(str(players[pid].realm), ["player", pid, players[pid].duplicate(true)])

func _emit(realm: String, event: Array) -> void:
	if Net.is_server(): Net.server._to_realm(realm, Vector3.INF, ["leisure", event])
	else: receive(event)

func receive(event: Array) -> void:
	match str(event[0]):
		"player":
			var pid := int(event[1])
			if int(event[2].get("rev", 0))>=int(state(pid).get("rev", 0)): players[pid] = event[2]
		"tables":
			var realm := str(event[1])
			var revision := int(event[3]) if event.size()>3 else 0
			if revision>=int(_table_revisions.get(realm, 0)):
				tables[realm] = event[2]
				_table_revisions[realm] = revision
		"drop":
			if is_instance_valid(world) and world.realm_id==str(event[1]): LeisureProps.drop(world, event[2], str(event[3]), event[4] if event.size()>4 else Basis.IDENTITY)

func _drop(pid: int, p: Dictionary, place: GameWorld) -> void:
	var s := state(pid)
	if s.cup.is_empty(): return
	var basis: Basis = (place.sample_gravity(p.pos).frame as Transform3D).basis if place is SpaceWorld else Basis.IDENTITY
	_emit(str(p.realm), ["drop", str(p.realm), (p.pos as Vector3)+basis.y, str(s.cup.kind), basis])
	s.cup = {}

func before_travel(p: Dictionary) -> void:
	var pid := int(p.player_id)
	if not players.has(pid): return
	players[pid].seat = ""
	_publish(pid)

func enter_player(p: Dictionary) -> void:
	var s := _ensure(int(p.player_id), str(p.realm))
	s.realm = str(p.realm)
	s.seat = ""
	_publish(int(p.player_id))

func forget_player(pid: int) -> void:
	if players.has(pid):
		var s: Dictionary = players[pid]
		s.cup = {}
		s.seat = ""
		s.cigar = 0.0
		s.beer = []
		_publish(pid)
	players.erase(pid)

func ship_tables(realm: String, ship: SpaceShip) -> Dictionary:
	var prefix := "ship:%d:" % (ship.fleet_id if ship.fleet_id>0 else ship.id)
	var result := {}
	for id: String in tables.get(realm, {}):
		if id.begins_with(prefix): result[id.substr(prefix.length())] = tables[realm][id].duplicate(true)
	if not result.is_empty():
		for suffix: String in result: tables[realm].erase(prefix+suffix)
		_revision += 1
		_table_revisions[realm] = _revision
		_emit(realm, ["tables", realm, tables[realm].duplicate(true), _revision])
	return result

func import_ship_tables(realm: String, ship: SpaceShip, cups: Dictionary) -> void:
	var prefix := "ship:%d:" % (ship.fleet_id if ship.fleet_id>0 else ship.id)
	if not tables.has(realm): tables[realm] = {}
	for id: String in tables[realm].keys():
		if id.begins_with(prefix): tables[realm].erase(id)
	for suffix: String in cups: tables[realm][prefix+suffix] = cups[suffix].duplicate(true)
	_revision += 1
	_table_revisions[realm] = _revision
	_emit(realm, ["tables", realm, tables[realm].duplicate(true), _revision])

func snapshot(realm: String) -> Dictionary:
	var list := {}
	for pid: int in players:
		if players[pid].realm==realm: list[pid] = players[pid].duplicate(true)
	return {players = list, tables = tables.get(realm, {}).duplicate(true), tables_rev = int(_table_revisions.get(realm, 0))}

func enter_world(place: GameWorld, actor: Player, data: Dictionary) -> void:
	world = place
	local_player = actor
	_table_nodes.clear()
	for pid in data.get("players", {}): receive(["player", int(pid), data.players[pid]])
	if data.has("tables"): receive(["tables", place.realm_id, data.tables, int(data.get("tables_rev", 0))])
	if not Net.is_client():
		var s := _ensure(actor.player_id, place.realm_id)
		if s.realm!=place.realm_id: s.seat = ""
		s.realm = place.realm_id

func _process(_delta: float) -> void:
	if not Net.is_client():
		for pid: int in players.keys():
			var s: Dictionary = players[pid]
			if not s.cup.is_empty() and int(s.cup.sips)==0 and now()-float(s.use_at)>=SIP_TIME:
				var p := Net.server.social.record(pid) if Net.is_server() and Net.server else {player_id = pid, pos = local_player.global_position if is_instance_valid(local_player) else Vector3.ZERO}
				var at: GameWorld = null
				if Net.is_server() and Net.server:
					var realm: RealmInstance = Net.server.realms.get(str(s.realm))
					if realm: at = realm.world
				else: at = world
				if not p.is_empty():
					p.realm = str(s.realm)
					_drop(pid, p, at)
					_publish(pid)
			if float(s.cigar)>0.0 and float(s.cigar)<=now():
				s.cigar = 0.0
				_publish(pid)
	if Net.is_server() or not is_instance_valid(world): return
	for id: String in tables.get(world.realm_id, {}):
		var spec := resolve(world, id)
		if spec.is_empty(): continue
		var cup: Dictionary = tables[world.realm_id][id]
		var node: Node3D = _table_nodes.get(id)
		if is_instance_valid(node) and str(node.get_meta("kind", ""))!=str(cup.kind):
			node.queue_free()
			node = null
		if not is_instance_valid(node):
			node = LeisureProps.cup(str(cup.kind))
			world.add_child(node)
			_table_nodes[id] = node
		node.global_transform = Transform3D(spec.get("basis", Basis.IDENTITY), spec.pos)
		LeisureProps.fill(node, int(cup.sips))
	for id: String in _table_nodes.keys():
		if not tables.get(world.realm_id, {}).has(id) or resolve(world, id).is_empty():
			if is_instance_valid(_table_nodes[id]): _table_nodes[id].queue_free()
			_table_nodes.erase(id)

func apply_seat(actor: Player, delta: float) -> bool:
	var spec := seat_spec(actor.player_id)
	if spec.is_empty(): return false
	actor.global_transform = Transform3D(spec.get("basis", Basis.IDENTITY), spec.pos)
	actor.velocity = Vector3.ZERO
	actor._visual_offset = 0.0
	actor.model.position.y = 0.0
	actor.up_direction = actor.global_basis.y
	actor.facing = float(spec.get("yaw", 0.0))
	actor.model.rotation.y = actor.facing
	actor._cancel_weapon_actions()
	actor._set_shield(false)
	actor.model.animate(0.0, delta)
	CityState.seated_pose(actor.model)
	if not is_instance_valid(actor.spatial_controller): actor._update_camera(delta)
	return true

func handle_input(actor: Player, event: InputEvent, interaction: InteractionCard) -> bool:
	if actor.controls_locked() or actor.frozen or actor.ui_blocked or actor.interacting(): return false
	if not event.is_pressed() or (event is InputEventKey and event.echo): return false
	var s := state(actor.player_id)
	if event.is_action_pressed("leisure_smoke"):
		var traversal := actor.spatial_controller as SpaceTraversal
		if traversal and traversal.seat!="" and not traversal.seat.begins_with("chair"): return false
		var seated := str(s.get("seat", ""))!="" or (traversal!=null and (traversal.seat.begins_with("chair") or traversal.city_seat!=""))
		if not hands_busy(actor.player_id) and not seated: return false
		request(actor, ["cigar"])
	elif event.is_action_pressed("leisure_sip") and hands_busy(actor.player_id): request(actor, ["sip"])
	elif event.is_action_pressed("seat_stand") and str(s.get("seat", ""))!="": request(actor, ["stand"])
	elif event.is_action_pressed("interact") and hands_busy(actor.player_id):
		if not smoking(actor.player_id) and is_instance_valid(interaction.target) and interaction.target.available(actor): return false
		request(actor, ["drop"])
	else: return false
	actor.get_viewport().set_input_as_handled()
	return true

func hint_rows(pid: int) -> Array:
	var rows: Array = []
	var s := state(pid)
	if smoking(pid):
		rows.append([["@leisure_sip"], "Puff"])
		rows.append([["@interact"], "Put cigar away"])
	elif not s.get("cup", {}).is_empty():
		rows.append([["@leisure_sip"], "%s  %d/4" % [str(s.cup.kind).capitalize(), int(s.cup.sips)]])
		rows.append([["@interact"], "Use table / tap, or drop cup"])
	if str(s.get("seat", ""))!="": rows.append([["@seat_stand"], "Stand up"])
	if hands_busy(pid) or str(s.get("seat", ""))!="": rows.append([["@leisure_smoke"], "Cigar"])
	return rows

## The shared Tavern has no running RealmInstance on the dedicated server.
## Read only its authored bench transforms; do not build its terrain or visuals.
func _hall_bench(id: String) -> Dictionary:
	if not id.begins_with("bench:"): return {}
	if _hall_bench_seats.is_empty():
		var scene := load("res://scenes/home/tavern.tscn") as PackedScene
		var hall := scene.instantiate() as Node3D
		var pending: Array[Node] = [hall]
		while not pending.is_empty():
			var node: Node = pending.pop_back()
			for child: Node in node.get_children(): pending.append(child)
			if not node is Node3D or str(node.get_meta("voxel_source", ""))!="res://props/town/bench/model.vox": continue
			var pose := HomeTerrain._transform_to(node, hall)
			for slot in 2:
				var frame := pose*Transform3D(Basis.IDENTITY, Vector3((slot-0.5)*2.7*0.48, 0, -0.08))
				var key := "bench:"+str(hall.get_path_to(node))+":"+str(slot)
				_hall_bench_seats[key] = {kind = "seat", key = key, pos = frame*Vector3(0, 0.2, 0), basis = frame.basis.orthonormalized(),
					yaw = 0.0, stand = frame*Vector3(0, 0.05, -1.25), drink = "beer"}
		hall.free()
	return _hall_bench_seats.get(id, {})
