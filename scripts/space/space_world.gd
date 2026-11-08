class_name SpaceWorld
extends SpatialWorld
## The Astral Reach: the Nexus station, open space with round planets, the
## Shardfield and the Gloam, and the parties' battleships. The authority
## (dedicated server, or the local game offline) flies the ships, seats the
## crew and moves players between station, ship rooms and planet pads.
const REALM := "astral"
const SNAPSHOT_INTERVAL := 0.1
const DOCK_RANGE := 1200.0
const RESCUE_TIME := 15.0
## A new battleship from the Nexus fleet or a town's shipwright.
const SHIP_PRICE := 500
const TRADER_REACH := 6.0
## How much harder parts wear than the hull (share of MAX_HP lost x this).
const PART_WEAR := 3.5
const REPAIR_REACH_INSIDE := 2.6
const REPAIR_REACH_OUTSIDE := 9.0
const AIRLOCK_OUTSIDE := Vector3(-11.6, -0.5, -10.0)  # hull space, just off the port airlock door
var record: Dictionary
var enemy_director := EnemyDirector.new()
var station: NexusStation
var backdrop: SpaceBackdrop
var planets := {}  # id -> SpacePlanet
var ships := {}  # id -> SpaceShip (authority and mirrors)
var ship_views := {}  # id -> SpaceShipView (clients)
var interiors := {}  # pocket slot -> ShipInterior
var interior_anchors := {}  # anchors of one interior (identical in every slot)
var hull_anchors := {}
var foes: SpaceFoes
var _biomes := {}
var _asteroids: Array = []
var _next_ship := 1
var _snapshot_timer := 0.0
var _rocket: SmallRocket
## Campaign marks per party id: [{id, name, pos, kind}] (ReachCampaign).
var marks := {}
var _mark_nodes: Array[Node] = []
var _npcs_built := false
var _warm := 0
var _rescues := {}  # player id -> when Orin's skiff arrives (ticks msec)
var _repairs := {}  # "ship:part" -> {pid, t, ship, part}
var _sips := {}  # player id -> drinks so far (each a separate drunk source)

static func is_space(id: String) -> bool:
	return id==REALM

func _init(data: Dictionary) -> void:
	record = data
	realm_id = str(data.get("id", REALM))
	display_name = "The Astral Reach"
	half_extent = 64
	spawn_point = Vector3(0, 0.1, 18)
	set_meta("full_3d", true)
	# The Reach is lit by its own sun (SpaceBackdrop); the game's sun stays dark here.
	for spec in [["station", "The Nexus", 0.5, 0.0], ["haven", "The Haven", 0.4, 0.0], ["shardfield", "The Shardfield", 0.35, 0.0],
			["gloam", "The Gloam", 0.2, 0.0], ["ship", "Aboard", 0.5, 0.0]]:
		var biome := BiomeDef.new()
		biome.id = Biomes.DEEP_DARK
		biome.biome_name = spec[1]
		biome.indoor = true
		biome.mood = 1.0
		biome.sky_top_color = Color("02020a")
		biome.sky_horizon_color = Color("060614")
		biome.sun_color = Color("ffe2b0")
		biome.ambient_energy = spec[2]
		biome.sun_energy = spec[3]
		biome.fog_of_war_enabled = false
		biome.fog_density = 0.0
		biome.volumetric_fog_density = 0.0
		biome.torch_energy = 0.0
		_biomes[spec[0]] = biome
	_asteroids = SpaceLayout.asteroids()

func _ready() -> void:
	enemy_director.world = self
	enemy_director.realm_id = realm_id
	enemy_director.remote = Net.is_client()
	add_child(enemy_director)
	foes = SpaceFoes.new()
	foes.world = self
	add_child(foes)
	var visual := not (server_build or Net.is_server())
	if visual:
		var helmets := SpaceHelmet.new()
		helmets.world = self
		add_child(helmets)
		queue_load_step(func() -> void:
			backdrop = SpaceBackdrop.new()
			add_child(backdrop)
			backdrop.build(false))
	queue_load_step(func() -> void:
		station = NexusStation.new()
		add_child(station)
		station.build(not visual)
		spawn_point = station.anchors.get("spawn", spawn_point)
		if visual: _station_props()
		if is_instance_valid(local_player) and local_player.global_position.distance_to(Vector3(0, 0.1, 18))<3.0:
			local_player.global_position = spawn_point)
	for p: Dictionary in SpaceLayout.PLANETS:
		queue_load_step(func() -> void:
			var body := SpacePlanet.new()
			body.position = p.center
			add_child(body)
			body.build(p, not visual)
			planets[p.id] = body)
	queue_load_step(func() -> void:
		# One interior's anchors are shared by every pocket slot.
		var probe := ShipInterior.new()
		probe.build(true)
		interior_anchors = probe.anchors.duplicate(true)
		probe.free()
		if visual:
			var hull := ShipHull.new()
			hull.build(Color.WHITE)
			hull_anchors = hull.anchors.duplicate(true)
			hull.free()
			_build_npcs()
			_show_marks())
	if server_build or Net.is_server():
		# The dedicated server builds everything right away.
		while not _load_steps.is_empty(): _load_steps.pop_front().call()
	if record.has("space_state"): apply_state.call_deferred(record.space_state)

## Biome-like zone names for the HUD and lighting.
func biome_at(position: Vector3) -> BiomeDef:
	var zone := zone_at(position)
	if zone in ["station", "ship"]: return _biomes[zone]
	return _biomes[SpaceLayout.region_at(position)]

func region_at(position: Vector3) -> String:
	var zone := zone_at(position)
	if zone.begins_with("planet:"): return str(SpaceLayout.planet(zone.substr(7)).name)
	return biome_at(position).biome_name

func sample_gravity(position: Vector3) -> Dictionary:
	var slot := SpaceLayout.pocket_at(position)
	if slot>=0:
		return {frame = Transform3D(Basis.IDENTITY, Vector3(position.x, SpaceLayout.POCKET_ORIGIN.y, position.z)), zone = "ship", distance = 0.0, slot = slot}
	var flat := Vector2(position.x-SpaceLayout.NEXUS.x, position.z-SpaceLayout.NEXUS.z).length()
	if flat<SpaceLayout.STATION_RADIUS+6.0 and absf(position.y-SpaceLayout.NEXUS.y)<SpaceLayout.STATION_HALF_HEIGHT:
		return {frame = Transform3D(Basis.IDENTITY, Vector3(position.x, SpaceLayout.NEXUS.y, position.z)), zone = "station", distance = absf(position.y)}
	var p := SpaceLayout.planet_near(position)
	if not p.is_empty():
		var up: Vector3 = (position-p.center).normalized()
		var right := up.cross(Vector3.FORWARD if absf(up.dot(Vector3.FORWARD))<0.95 else Vector3.RIGHT).normalized()
		var surface: Vector3 = p.center+up*(float(p.radius)+SpaceLayout.surface_height(p, up))
		return {frame = Transform3D(Basis(right, up, right.cross(up)), surface), zone = "planet:"+str(p.id), distance = position.distance_to(surface)}
	return {frame = Transform3D(Basis.IDENTITY, position), zone = "void", distance = 1e6}

func first_person_at(position: Vector3) -> bool:
	return SpaceLayout.pocket_at(position)>=0

## Anywhere inside the Reach: spacewalkers float in open space on jetpacks.
func is_walkable(position: Vector3) -> bool:
	return position.is_finite() and (position.length()<SpaceLayout.WORLD_RADIUS or SpaceLayout.pocket_at(position)>=0)

func recovery_point(position: Vector3) -> Vector3:
	var state := sample_gravity(position)
	if state.zone=="void" or float(state.distance)>40.0: return spawn_point
	var frame: Transform3D = state.frame
	return frame.origin+frame.basis.y*0.12

func legal_recovery(from: Vector3, to: Vector3) -> bool:
	return to.distance_to(recovery_point(from))<2.5

func make_controller(actor: Player) -> SpatialController:
	local_player = actor
	return SpaceTraversal.new().setup(actor, self)

func map_color(_x: int, _z: int) -> Color: return Color("05060f")
func ground_height(_x: float, _z: float) -> float: return 0.0
func obstacles_near(_at: Vector3, _radius: float) -> Array[String]: return []
func remove_obstacle(_id: String) -> void: pass

# --- Requests -------------------------------------------------------------------

## Local player -> authority.
func request(args: Array) -> void:
	if Net.is_client(): Net.client.send_action("theory", args)
	elif is_instance_valid(local_player):
		server_action({player_id = local_player.player_id, peer_id = 0, pos = local_player.global_position,
			name = "You", account_id = 0}, args)

func _party_id(player_id: int) -> int:
	if Net.server==null: return 0
	return int(Net.server.social.party_for(player_id).get("id", 0))

func _may_board(ship: SpaceShip, player_id: int) -> bool:
	return ship.owner==player_id or (ship.party!=0 and ship.party==_party_id(player_id))

func ship_of(player_id: int) -> SpaceShip:
	for ship: SpaceShip in ships.values():
		if ship.seat_of(player_id)!="": return ship
	return null

func ship_in_slot(slot: int) -> SpaceShip:
	for ship: SpaceShip in ships.values():
		if ship.slot==slot: return ship
	return null

func server_action(p: Dictionary, args: Array) -> void:
	if args.is_empty(): return
	var pid := int(p.player_id)
	var pos: Vector3 = p.get("pos", Vector3.ZERO)
	match str(args[0]):
		"spawn", "buy_ship":  # [planet id] at a town's shipwright, or none at the Nexus table
			var town := str(args[1]) if args.size()>1 else ""
			if town=="" and zone_at(pos)!="station": return
			if town!="" and pos.distance_to(trader_position(town, "wright"))>TRADER_REACH: return
			for ship: SpaceShip in ships.values():
				if ship.owner==pid:
					_tell(p, "You already have %s. One ship per captain." % ship.name)
					return
			# A ship you own (bought, not lost) comes back free; Captain Isolde lends
			# one to crews on a Reach tale; otherwise it costs Dots.
			var owned := not _fleet(p).is_empty()
			var loan := owned or _on_reach_tale(pid)
			if not loan and not _pay(p, SHIP_PRICE):
				_tell(p, "A new ship costs %d Dots. Sell items at a smith or the Tavern forge." % SHIP_PRICE)
				return
			var ship := _launch_ship(pid, str(p.get("name", "Captain")))
			if ship and owned:
				ship.name = str(_fleet(p).get("name", ship.name))
				ship.set_meta("account", int(p.get("account_id", 0)))
			if ship and not loan: _remember(p, ship)
			if ship==null:
				if not loan: _refund(p, SHIP_PRICE)
				_tell(p, "Every ship room is taken. Try again soon.")
				return
			if town!="":
				var planet := SpaceLayout.planet(town)
				var dock := SpaceLayout.town_frame(planet, "dock")
				ship.mode = "landed"
				ship.planet = town
				ship.xform = Transform3D(dock.basis, (planet.center as Vector3)+dock.origin+dock.basis.y*SpaceShip.LANDED_HEIGHT)
				_broadcast_ship(ship)
				_tell(p, "%s waits on the shipyard pad. Walk up the ramp to board.%s" % [ship.name, "" if owned or not loan else " (On loan for your tale.)"])
			else:
				_tell(p, "%s waits at berth %d. Board it from the command table.%s" % [ship.name, ship.berth+1, "" if owned or not loan else " (On loan for your tale.)"])
		"board":
			var ship: SpaceShip = ships.get(int(args[1]) if args.size()>1 else 0)
			if ship==null or not _may_board(ship, pid):
				_tell(p, "That ship belongs to another crew.")
				return
			var near := zone_at(pos)=="station" if ship.mode=="berth" else pos.distance_to(hatch_position(ship))<9.0 if ship.mode=="landed" else false
			if not near:
				_tell(p, "You can only board at the Nexus or beside the landed ship.")
				return
			teleport(p, pocket_point(ship.slot, interior_anchors.get("spawn", Vector3(0, 0.1, 14))), "board")
		"hatch":
			var ship := ship_in_slot(SpaceLayout.pocket_at(pos))
			if ship==null: return
			_stand(ship, pid)
			match ship.mode:
				"berth": teleport(p, station.anchors.get("gangways", [spawn_point])[ship.berth % 6]+Vector3.UP*0.1 if station else spawn_point, "station")
				"landed": teleport(p, hatch_position(ship), "planet")
				_: _tell(p, "The hatch stays sealed in flight. Land on a planet or dock at the Nexus.")
		"sit":
			var ship := ship_in_slot(SpaceLayout.pocket_at(pos))
			var seat := str(args[1]) if args.size()>1 else ""
			if ship==null or not seat in SpaceShip.SEATS: return
			var taken := int(ship.crew.get(seat, 0))
			if taken!=0 and taken!=pid:
				_tell(p, "Someone already sits there.")
				return
			_stand(ship, pid)
			ship.crew[seat] = pid
			_broadcast_ship(ship)
		"stand":
			var ship := ship_of(pid)
			if ship!=null:
				_stand(ship, pid)
				_broadcast_ship(ship)
		"pilot":
			var ship := ship_of(pid)
			if ship==null or ship.pilot()!=pid or args.size()<2 or not args[1] is Array or not (args[1] as Array).size() in [5, 6]: return
			ship.input = (args[1] as Array)+([false] if (args[1] as Array).size()==5 else [])
			ship.input_age = 0.0
		"land":
			var ship := ship_of(pid)
			if ship==null or ship.pilot()!=pid: return
			var target := ship.landable()
			if target.is_empty():
				_tell(p, "Slow down near a planet's landing pad to land.")
				return
			ship.begin_landing(target)
			_broadcast_ship(ship)
		"dock":
			var ship := ship_of(pid)
			if ship==null or ship.pilot()!=pid or ship.mode!="flying": return
			if ship.xform.origin.distance_to(SpaceLayout.NEXUS)>DOCK_RANGE:
				_tell(p, "Fly closer to the Nexus to dock.")
				return
			ship.dock(ship.berth)
			_broadcast_ship(ship)
		"aim":
			var ship := ship_of(pid)
			if ship==null or args.size()<2 or not args[1] is Vector3: return
			var seat := ship.seat_of(pid)
			if seat.begins_with("turret"): ship.aims[seat] = (args[1] as Vector3).normalized()
		"fire":
			var ship := ship_of(pid)
			if ship==null or args.size()<2 or not args[1] is Vector3: return
			var seat := ship.seat_of(pid)
			if not seat.begins_with("turret") or Time.get_ticks_msec()<int(ship.cooldowns.get(seat, 0)): return
			# Damaged cannons fire slowly; broken ones jam.
			if ship.part("cannons")<=0.0:
				_tell(p, "The cannons are jammed! Mend them at the gunnery console.")
				ship.cooldowns[seat] = Time.get_ticks_msec()+3000
				return
			ship.cooldowns[seat] = Time.get_ticks_msec()+int(180.0*(1.0+2.0*(1.0-ship.part("cannons"))))
			var dir := (args[1] as Vector3).normalized()
			ship.aims[seat] = dir
			foes.fire_bolt(ship, turret_muzzle(ship, seat), dir)
		"repair":  # [part] inside, or [ship id, part] outside
			var ship: SpaceShip = (ships.get(int(args[1])) if args.size()>2 else ship_in_slot(SpaceLayout.pocket_at(pos)))
			var id := str(args[-1])
			if ship==null or not SpaceShip.PARTS.has(id) or not _may_board(ship, pid): return
			if float(ship.parts[id])>=100.0:
				_tell(p, "The %s need no mending." % str(SpaceShip.PARTS[id].name).to_lower())
				return
			if repair_point(ship, id, pos).is_finite():
				_repairs["%d:%s" % [ship.id, id]] = {pid = pid, t = 0.0, ship = ship.id, part = id}
				_tell(p, "Mending the %s... stay close." % str(SpaceShip.PARTS[id].name).to_lower())
			else:
				_tell(p, "Get closer to the %s." % str(SpaceShip.PARTS[id].name).to_lower())
		"drink":
			var ship := ship_of(pid)
			var seat := ship.seat_of(pid) if ship else ""
			if not seat.begins_with("chair"): return
			var i := int(seat.substr(6))
			if float(ship.glasses[i])<=0.01:
				_tell(p, "Your glass is empty. The tap is at the galley.")
				return
			ship.glasses[i] = maxf(0.0, float(ship.glasses[i])-0.34)
			_sips[pid] = int(_sips.get(pid, 0))+1
			var stats := GameServer.character(pid)
			if stats: stats.buffs.add("drunk", 150.0, 1, "sip_%d" % (int(_sips[pid]) % 8))
			_broadcast_ship(ship)
		"pour":
			var ship := ship_in_slot(SpaceLayout.pocket_at(pos))
			if ship==null: return
			for i in ship.glasses.size():
				if float(ship.glasses[i])<0.99:
					ship.glasses[i] = 1.0
					_broadcast_ship(ship)
					_tell(p, "A frothy mug of Nexus amber, poured at the table.")
					return
			_tell(p, "Every glass on the table is already full.")
		"cigar":
			var ship := ship_of(pid)
			if ship==null or not ship.seat_of(pid).begins_with("chair"): return
			if ship.smoking.has(pid): ship.smoking.erase(pid)
			else: ship.smoking[pid] = 40.0
			_broadcast_ship(ship)
		"airlock":
			# From the room out onto the hull, or from outside back in.
			var slot := SpaceLayout.pocket_at(pos)
			if slot>=0:
				var ship := ship_in_slot(slot)
				if ship==null or pos.distance_to(pocket_point(slot, interior_anchors.get("airlock", Vector3.ZERO)))>3.0: return
				_stand(ship, pid)
				teleport(p, ship.xform*AIRLOCK_OUTSIDE, "airlock_out")
			else:
				for ship: SpaceShip in ships.values():
					if _may_board(ship, pid) and pos.distance_to(ship.xform*AIRLOCK_OUTSIDE)<8.0:
						teleport(p, pocket_point(ship.slot, (interior_anchors.get("airlock", Vector3.ZERO) as Vector3)+Vector3(1.2, 0.1, 0)), "airlock_in")
						return
		"rescue":
			# Only the stranded (no ship of their own crew to go back to) can call Orin's skiff.
			if not stranded(pid, pos):
				_tell(p, "There is no quick way home out here. Fly your ship back to the Nexus.")
				return
			if not _rescues.has(pid):
				_rescues[pid] = Time.get_ticks_msec()+int(RESCUE_TIME*1000.0)
				_tell(p, "Orin's rescue skiff is on its way. Hold on for %d seconds." % int(RESCUE_TIME))

## Where `pos` is close enough to mend `id` on `ship` (the spot), or INF.
func repair_point(ship: SpaceShip, id: String, pos: Vector3) -> Vector3:
	if SpaceShip.PARTS[id].inside:
		var spot := pocket_point(ship.slot, (interior_anchors.get("repairs", {}) as Dictionary).get(id, Vector3.ZERO))
		return spot if SpaceLayout.pocket_at(pos)==ship.slot and pos.distance_to(spot)<REPAIR_REACH_INSIDE else Vector3.INF
	var local: Vector3 = SpaceShip.PARTS[id].hull
	for side: float in [1.0, -1.0]:
		var spot := ship.xform*Vector3(local.x*side, local.y, local.z)
		if pos.distance_to(spot)<REPAIR_REACH_OUTSIDE+(6.5 if ship.mode=="landed" else 0.0): return spot
	return Vector3.INF

## Repairs in progress: done after REPAIR_TIME if the mender stays close.
func _mend(delta: float) -> void:
	for key: String in _repairs.keys():
		var job: Dictionary = _repairs[key]
		var ship: SpaceShip = ships.get(int(job.ship))
		var p := _record(int(job.pid))
		if ship==null or p.is_empty() or not repair_point(ship, str(job.part), p.get("pos", Vector3.INF)).is_finite():
			_repairs.erase(key)
			continue
		job.t = float(job.t)+delta
		if float(job.t)>=SpaceShip.REPAIR_TIME:
			_repairs.erase(key)
			ship.parts[job.part] = 100.0
			ship.hp = mini(SpaceShip.MAX_HP, ship.hp+int(SpaceShip.MAX_HP*SpaceShip.REPAIR_HULL))
			_broadcast_ship(ship)
			_tell_crew(ship, "%s mended the %s." % [str(p.get("name", "Someone")), str(SpaceShip.PARTS[job.part].name).to_lower()])

## Repairs under way, for the menders' progress: "ship:part" -> 0..1.
func repair_progress(pid: int) -> float:
	for job: Dictionary in _repairs.values():
		if int(job.pid)==pid: return float(job.t)/SpaceShip.REPAIR_TIME
	return -1.0

## Smoke drifts away after a while.
func _burn_cigars(delta: float) -> void:
	for ship: SpaceShip in ships.values():
		for pid: int in ship.smoking.keys():
			ship.smoking[pid] = float(ship.smoking[pid])-delta
			if float(ship.smoking[pid])<=0.0 or not ship.seat_of(pid).begins_with("chair"):
				ship.smoking.erase(pid)
				_broadcast_ship(ship)

## A message to everyone who belongs to the ship.
func _tell_crew(ship: SpaceShip, text: String) -> void:
	if Net.is_server():
		var realm: RealmInstance = Net.server.realms.get(realm_id)
		if realm == null: return
		for pid: int in realm.proxies:
			var p: Dictionary = Net.server.social.record(pid)
			if not p.is_empty() and (SpaceLayout.pocket_at(p.pos)==ship.slot or ship.seat_of(pid)!="" or _may_board(ship, pid)): _tell(p, text)
	else: handle_event(["say", text])

## A town trader's place in the world: "smith" or "wright" on planet `id`.
func trader_position(id: String, which: String) -> Vector3:
	var planet := SpaceLayout.planet(id)
	if planet.is_empty(): return Vector3.INF
	return (planet.center as Vector3)+SpaceLayout.town_frame(planet, which).origin

## Whether `pos` stands by one of the Reach's smiths (selling at the forge).
func near_smith(pos: Vector3) -> bool:
	for planet: Dictionary in SpaceLayout.PLANETS:
		if pos.distance_to(trader_position(planet.id, "smith"))<TRADER_REACH: return true
	return false

## The party of `pid` is on a Reach tale (ships are lent for those).
func _on_reach_tale(pid: int) -> bool:
	if Net.server==null: return true
	var party: Dictionary = Net.server.social.party_for(pid)
	var camp: Dictionary = party.get("campaign", {})
	return not camp.is_empty() and bool(Campaigns.get_def(str(camp.get("id", ""))).get("reach", false))

## The ship this player's account owns (bought, not yet lost), or {}.
func _fleet(p: Dictionary) -> Dictionary:
	if Net.server==null or int(p.get("account_id", 0))==0: return {}
	return Net.server.campaigns.book(int(p.account_id)).get("reach_ship", {})

func _remember(p: Dictionary, ship: SpaceShip) -> void:
	if Net.server==null or int(p.get("account_id", 0))==0: return
	Net.server.campaigns.book(int(p.account_id)).reach_ship = {name = ship.name}
	ship.set_meta("account", int(p.account_id))
	Net.server.campaigns._touch(int(p.account_id))
	Net.server.campaigns.flush()

## A bought ship was destroyed: the account has to buy a new one.
func _forget(ship: SpaceShip) -> void:
	var account := int(ship.get_meta("account", 0))
	if Net.server==null or account==0: return
	Net.server.campaigns.book(account).erase("reach_ship")
	Net.server.campaigns._touch(account)
	Net.server.campaigns.flush()

## Takes Dots for a purchase (offline play is free; test servers too).
func _pay(p: Dictionary, amount: int) -> bool:
	if not Net.is_server() or Net.server.config.test_mode: return true
	return Net.server.economy.spend(p, amount, "ship")

func _refund(p: Dictionary, amount: int) -> void:
	if Net.is_server() and not Net.server.config.test_mode: Net.server.economy.award(p, amount, "ship refund")

## Adrift in space or on a planet with no ship of their crew in the Reach.
func stranded(pid: int, pos: Vector3) -> bool:
	if SpaceLayout.pocket_at(pos)>=0 or zone_at(pos)=="station": return false
	for ship: SpaceShip in ships.values():
		if _may_board(ship, pid): return false
	return true

func _arrive_rescues() -> void:
	for pid: int in _rescues.keys():
		if Time.get_ticks_msec()<int(_rescues[pid]): continue
		_rescues.erase(pid)
		var p := _record(pid)
		if not p.is_empty(): teleport(p, spawn_point, "home")

## The player's record (server) or the local player's (offline).
func _record(pid: int) -> Dictionary:
	if Net.is_server(): return Net.server.social.record(pid)
	if is_instance_valid(local_player) and local_player.player_id==pid:
		return {player_id = pid, peer_id = 0, pos = local_player.global_position, name = "You", account_id = 0}
	return {}

## Players in a ship room ride along: leaving the seat they were in.
func _stand(ship: SpaceShip, pid: int) -> void:
	var seat := ship.seat_of(pid)
	if seat=="": return
	ship.crew.erase(seat)
	if seat=="pilot": ship.input = [0.0, 0.0, 0.0, 0.0, false, false]

func _launch_ship(pid: int, captain: String) -> SpaceShip:
	var used_slots: Array = ships.values().map(func(s: SpaceShip) -> int: return s.slot)
	var used_berths: Array = ships.values().filter(func(s: SpaceShip) -> bool: return s.mode=="berth").map(func(s: SpaceShip) -> int: return s.berth)
	var slot := -1
	for i in SpaceLayout.POCKET_SLOTS:
		if not i in used_slots:
			slot = i
			break
	var berth := -1
	for i in SpaceLayout.BERTHS:
		if not i in used_berths:
			berth = i
			break
	if slot<0 or berth<0: return null
	var ship := SpaceShip.new()
	ship.id = _next_ship
	_next_ship += 1
	ship.slot = slot
	ship.owner = pid
	ship.party = _party_id(pid)
	ship.name = "%s's %s" % [captain, ["Lantern", "Thistle", "Comet", "Willow", "Bramble", "Starling"][ship.id % 6]]
	ship.tint = [Color("ff8ad8"), Color("7dff9a"), Color("ffd27a"), Color("8ad8ff"), Color("c89aff"), Color("ff9a6a")][ship.id % 6]
	ship.dock(berth)
	ships[ship.id] = ship
	_ensure_interior(slot)
	_broadcast_ship(ship)
	return ship

## Moves a player (authority): the client is corrected to the new spot.
func teleport(p: Dictionary, to: Vector3, reason := "") -> void:
	if Net.is_server():
		var peer := int(p.get("peer_id", 0))
		p.pos = to
		p.grace = NetServer.SNAP_BACK_GRACE*8.0
		p.moved_at = 0.0
		var realm: RealmInstance = Net.server.realms.get(realm_id)
		if realm and realm.proxies.has(int(p.player_id)): realm.proxies[int(p.player_id)].global_position = to
		if peer!=0:
			Net.c_correct.rpc_id(peer, to)
			Net.server._to_peer(peer, ["theory", ["moved", reason]])
	elif is_instance_valid(local_player):
		local_player.global_position = to
		local_player.velocity = Vector3.ZERO
		handle_event(["moved", reason])

func _tell(p: Dictionary, text: String) -> void:
	if Net.is_server():
		if int(p.get("peer_id", 0))!=0: Net.server._to_peer(int(p.peer_id), ["theory", ["say", text]])
	else: handle_event(["say", text])

func pocket_point(slot: int, local: Vector3) -> Vector3:
	return SpaceLayout.pocket_origin(slot)+local

## Where the crew steps out of a landed ship.
func hatch_position(ship: SpaceShip) -> Vector3:
	var hatch: Transform3D = hull_anchors.get("hatch", Transform3D(Basis.IDENTITY, Vector3(9, -3, 4)))
	var at := ship.xform*hatch.origin
	var gravity := sample_gravity(at)
	return (gravity.frame as Transform3D).origin+(gravity.frame as Transform3D).basis.y*0.15 if gravity.zone!="void" else at

func turret_muzzle(ship: SpaceShip, seat: String) -> Vector3:
	# Muzzles of the hull's turret mounts (ShipHull), roughly where the barrels end.
	var offsets := {turret_top = Vector3(0, ShipHull.DECK_Y+2.6, -18.0), turret_left = Vector3(-10.2, 2.75, -5.0), turret_right = Vector3(10.2, 2.75, -5.0)}
	return ship.xform*(offsets.get(seat, Vector3.ZERO) as Vector3)

func _ensure_interior(slot: int) -> void:
	if interiors.has(slot): return
	var room := ShipInterior.new()
	room.position = SpaceLayout.pocket_origin(slot)
	add_child(room)
	room.build(server_build or Net.is_server())
	interiors[slot] = room
	if not (server_build or Net.is_server()): _interior_props(slot, room)

# --- Authority loop ------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if Net.is_client(): return
	_arrive_rescues()
	_mend(delta)
	_burn_cigars(delta)
	# Landing checks need every planet's obstacle list; build one per tick.
	if _warm<SpaceLayout.PLANETS.size():
		PlanetFlora._obstacle_index(SpaceLayout.PLANETS[_warm])
		_warm += 1
	for ship: SpaceShip in ships.values().duplicate():
		var damage := ship.step(delta, _asteroids)
		if damage>0: hurt_ship(ship, damage)
		# Too close to the sun: the hull scorches, faster the closer.
		var heat := 1.0-(ship.xform.origin.distance_to(SpaceLayout.SUN_CENTER)-SpaceLayout.SUN_RADIUS)/SpaceLayout.SUN_BURN
		if heat>0.0 and ships.has(ship.id):
			ship.set_meta("scorch", float(ship.get_meta("scorch", 0.0))+heat*heat*240.0*delta)
			if float(ship.get_meta("scorch"))>=1.0:
				var burn := int(ship.get_meta("scorch"))
				ship.set_meta("scorch", float(ship.get_meta("scorch"))-burn)
				if randf()<0.02: _tell_crew(ship, "The sun is scorching the hull! Turn away!")
				hurt_ship(ship, burn)
	# Ships nobody owns any more (owner left the server) are scuttled.
	if Net.is_server():
		for ship: SpaceShip in ships.values().duplicate():
			if Net.server.social.record(ship.owner).is_empty(): _scuttle(ship, "")
	_snapshot_timer -= delta
	if _snapshot_timer<=0.0 and not ships.is_empty():
		_snapshot_timer = SNAPSHOT_INTERVAL
		var event: Array = ["ships", ships.values().map(func(s: SpaceShip) -> Array: return s.wire())]
		handle_event(event)
		world_event.emit(event)

## A hit: the hull loses `damage` and the part nearest `at` (world) takes its share.
func hurt_ship(ship: SpaceShip, damage: int, at := Vector3.INF) -> void:
	if not ships.has(ship.id): return
	ship.hp = maxi(0, ship.hp-damage)
	var id: String = SpaceShip.part_at(ship.xform.affine_inverse()*at) if at.is_finite() else SpaceShip.PARTS.keys()[randi() % SpaceShip.PARTS.size()]
	var before := float(ship.parts.get(id, 100.0))
	ship.parts[id] = maxf(0.0, before-float(damage)/float(SpaceShip.MAX_HP)*100.0*PART_WEAR)
	if before>=50.0 and float(ship.parts[id])<50.0:
		_tell_crew(ship, "The %s %s damaged! Mend %s %s." % [str(SpaceShip.PARTS[id].name).to_lower(), "are" if id in ["engines", "cannons"] else "is",
			"them" if id in ["engines", "cannons"] else "it", "inside the ship" if SpaceShip.PARTS[id].inside else "from outside (airlock) or on the ground"])
	if ship.hp<=0:
		_forget(ship)
		_scuttle(ship, "%s breaks apart around you! Your jetpacks keep you floating." % ship.name)

## The ship is lost: its crew wakes at the Nexus.
func _scuttle(ship: SpaceShip, message: String) -> void:
	ships.erase(ship.id)
	var event: Array = ["ship-", ship.id, ship.xform.origin, message]
	handle_event(event)
	world_event.emit(event)
	# The crew is thrown clear around the wreck, floating on their jetpacks.
	var wreck := ship.xform.origin
	if Net.is_server():
		var realm: RealmInstance = Net.server.realms.get(realm_id)
		if realm:
			for pid: int in realm.proxies:
				var p: Dictionary = Net.server.social.record(pid)
				if not p.is_empty() and SpaceLayout.pocket_at(p.pos)==ship.slot: teleport(p, _adrift_point(wreck), "adrift")
	elif is_instance_valid(local_player) and SpaceLayout.pocket_at(local_player.global_position)==ship.slot:
		teleport({player_id = local_player.player_id}, _adrift_point(wreck), "adrift")

func _adrift_point(wreck: Vector3) -> Vector3:
	var at := wreck+Vector3(randf_range(-1, 1), randf_range(-0.5, 0.5), randf_range(-1, 1)).normalized()*randf_range(25.0, 40.0)
	var p := SpaceLayout.planet_near(at, 30.0)
	# Never inside a planet: push out above its ground.
	if not p.is_empty(): at = SpaceLayout.surface_point(p, at)+(at-(p.center as Vector3)).normalized()*4.0
	return at

func _broadcast_ship(ship: SpaceShip) -> void:
	var event: Array = ["ships", [ship.wire()]]
	handle_event(event)
	world_event.emit(event)

## Players leaving the server or the world give up their seats.
func player_left(pid: int) -> void:
	for ship: SpaceShip in ships.values():
		_stand(ship, pid)

# --- Replication --------------------------------------------------------------------------

func handle_event(event: Array) -> void:
	match str(event[0]):
		"ships":
			for data: Array in event[1]:
				var id := int(data[0])
				var ship: SpaceShip = ships.get(id)
				if Net.is_client() or ship==null:
					ship = SpaceShip.from_wire(data, ship if Net.is_client() else null)
					ships[id] = ship
				_ensure_interior(ship.slot)
				if not (server_build or Net.is_server()): _view_for(ship).push(ship)
		"ship-":
			var id := int(event[1])
			if Net.is_client(): ships.erase(id)
			if ship_views.has(id):
				ship_views[id].explode()
				ship_views.erase(id)
			if str(event[3])!="" and is_instance_valid(local_player) and local_player.spatial_controller is SpaceTraversal:
				(local_player.spatial_controller as SpaceTraversal).notice(str(event[3]))
		"bolt", "foes", "foe-", "hit":
			foes.handle_event(event)
		"marks":
			marks[int(event[1])] = event[2]
			if not (server_build or Net.is_server()): _show_marks()
		"say", "moved":
			if is_instance_valid(local_player) and local_player.spatial_controller is SpaceTraversal:
				(local_player.spatial_controller as SpaceTraversal).on_world_message(event)

func state_wire() -> Dictionary:
	return {ships = ships.values().map(func(s: SpaceShip) -> Array: return s.wire()), marks = marks.duplicate(true)}

func apply_state(data: Dictionary) -> void:
	if data.has("ships"): handle_event(["ships", data.ships])
	for party_id in data.get("marks", {}): handle_event(["marks", int(party_id), data.marks[party_id]])

# --- Campaign places ------------------------------------------------------------------------

## A named story place on a planet (SpacePlanet anchors), in world space.
func spot_position(planet_id: String, spot: String) -> Vector3:
	var body: SpacePlanet = planets.get(planet_id)
	var p := SpaceLayout.planet(planet_id)
	if body==null or p.is_empty(): return Vector3.INF
	var spots: Dictionary = body.anchors.get("spots", {})
	var frame: Transform3D
	if spots.has(spot): frame = spots[spot]
	elif not spots.is_empty():
		# An authored name the art does not have: a stable stand-in spot.
		var keys := spots.keys()
		keys.sort()
		frame = spots[keys[absi(spot.hash()) % keys.size()]]
	else: frame = body.anchors.get("pad", Transform3D(Basis.IDENTITY, Vector3.UP*float(p.radius)))
	return body.position+frame.origin

func npc_position(id: String) -> Vector3:
	var info: Dictionary = Campaigns.NPCS.get(id, {})
	if info.get("world", "")!=REALM: return Vector3.INF
	var at: Dictionary = info.at
	if at.has("nexus"):
		if station==null: return Vector3.INF
		var anchor: Variant = station.anchors.get(str(at.nexus))
		return (anchor as Transform3D).origin if anchor is Transform3D else anchor if anchor is Vector3 else Vector3.INF
	var spot := spot_position(str(at.planet), str(at.spot))
	if not spot.is_finite(): return spot
	# Beside the spot rather than on it, so its search mark stays clear.
	var frame := surface_frame(spot)
	return frame.origin+frame.basis.x*3.0

## Authority: a party's marks changed.
func set_marks(party_id: int, list: Array) -> void:
	if marks.get(party_id, [])==list: return
	var event: Array = ["marks", party_id, list]
	handle_event(event)
	world_event.emit(event)

func _local_party() -> int:
	var game := get_parent()
	if game!=null and game.get("social") is SocialClient: return int((game.get("social") as SocialClient).party.get("id", 0))
	return 0

## This player's party's marks: search and repair spots to touch, beacons.
func my_marks() -> Array:
	return marks.get(_local_party(), [])

func _show_marks() -> void:
	for node in _mark_nodes:
		if is_instance_valid(node): node.queue_free()
	_mark_nodes.clear()
	for mark: Dictionary in my_marks():
		if mark.kind in ["search", "repair"]:
			var spot := SpaceInteraction.new()
			spot.world = self
			spot.kind = "mark"
			spot.mark_id = str(mark.id)
			spot.title = str(mark.name)
			add_child(spot)
			spot.global_position = mark.pos
			_mark_nodes.append(spot)
		# The game's own quest badge; far flight targets show it through fog and walls.
		var holder := Node3D.new()
		add_child(holder)
		holder.global_position = mark.pos
		if zone_at(mark.pos)!="void": holder.global_basis = surface_frame(mark.pos).basis
		var badge := QuestMarker.new("main")
		holder.add_child(badge)
		if mark.kind=="target":
			badge._material.disable_fog = true
			badge._material.no_depth_test = true
		_mark_nodes.append(holder)

## The Reach's people stand at the station and on their planets.
func _build_npcs() -> void:
	if _npcs_built or server_build or Net.is_server(): return
	_npcs_built = true
	for id: String in Campaigns.NPCS:
		var info: Dictionary = Campaigns.NPCS[id]
		if info.get("world", "")!=REALM: continue
		var at := npc_position(id)
		if not at.is_finite(): continue
		var npc := SpaceNPC.new()
		npc.world = self
		npc.npc_id = id
		add_child(npc)
		npc.place(at, surface_frame(at).basis)

func _view_for(ship: SpaceShip) -> SpaceShipView:
	if ship_views.has(ship.id): return ship_views[ship.id]
	var view := SpaceShipView.new()
	view.world = self
	view.ship_id = ship.id
	add_child(view)
	view.setup(ship)
	ship_views[ship.id] = view
	return view

# --- Interactables --------------------------------------------------------------------------

func _station_props() -> void:
	var table := SpaceInteraction.new()
	table.world = self
	table.kind = "table"
	table.position = station.anchors.get("command_table", Vector3(10, 0, 0))
	add_child(table)
	var board := SpaceInteraction.new()
	board.world = self
	board.kind = "board"
	board.position = station.anchors.get("campaign_board", Vector3(-10, 0, 0))
	add_child(board)
	var pad: Transform3D = station.anchors.get("rocket_pad", Transform3D(Basis.IDENTITY, Vector3(-20, 0, 0)))
	_rocket = SmallRocket.new()
	_rocket.transform = pad
	add_child(_rocket)
	_rocket.build()
	var rocket := SpaceInteraction.new()
	rocket.world = self
	rocket.kind = "rocket"
	rocket.position = pad.origin+pad.basis.z*3.5
	add_child(rocket)

func _interior_props(slot: int, room: ShipInterior) -> void:
	var anchors: Dictionary = room.anchors
	var seats: Dictionary = anchors.get("seats", {})
	for seat: String in seats:
		var spot := SpaceInteraction.new()
		spot.world = self
		spot.kind = "seat"
		spot.seat = seat
		spot.position = room.position+(seats[seat].pos as Vector3)
		add_child(spot)
	var hatch := SpaceInteraction.new()
	hatch.world = self
	hatch.kind = "hatch"
	hatch.position = room.position+(anchors.get("hatch", Vector3(0, 1, 17)) as Vector3)
	add_child(hatch)
	hatch.set_meta("slot", slot)
	for id: String in anchors.get("repairs", {}):
		var mend := SpaceInteraction.new()
		mend.world = self
		mend.kind = "repair"
		mend.part = id
		mend.position = room.position+(anchors.repairs[id] as Vector3)+Vector3.UP*0.8
		add_child(mend)
	for spec: Array in [["airlock", anchors.get("airlock", Vector3.ZERO)], ["tap", anchors.get("tap", Vector3.ZERO)]]:
		var spot := SpaceInteraction.new()
		spot.world = self
		spot.kind = spec[0]
		spot.position = room.position+(spec[1] as Vector3)+Vector3.UP*1.0
		add_child(spot)
	var tavern := ShipTavern.new()
	tavern.world = self
	tavern.slot = slot
	tavern.anchors = anchors
	room.add_child(tavern)

## Seat data of this interior: {pos, yaw, kind, stand} in world space for `slot`.
func seat_spec(slot: int, seat: String) -> Dictionary:
	var seats: Dictionary = interior_anchors.get("seats", {})
	if not seats.has(seat): return {}
	var spec: Dictionary = (seats[seat] as Dictionary).duplicate()
	spec.pos = pocket_point(slot, spec.pos)
	spec.stand = pocket_point(slot, spec.get("stand", seats[seat].pos))
	return spec

func rocket_node() -> SmallRocket:
	return _rocket
