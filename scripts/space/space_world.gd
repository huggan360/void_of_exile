class_name SpaceWorld
extends SpatialWorld
## The Astral Reach: the Nexus station, open space with round planets, the
## Shardfield and the Gloam, and the parties' battleships. The authority
## (dedicated server, or the local game offline) flies the ships, seats the
## crew and moves players between station, ship rooms and planet pads.
const REALM := "astral"
const SNAPSHOT_INTERVAL := 0.05
const DOCK_RANGE := 1200.0
const RESCUE_TIME := 15.0
## A new battleship from the Nexus fleet or a town's shipwright.
const SHIP_PRICE := 500
const TRADER_REACH := 6.0
## How much harder parts wear than the hull (share of MAX_HP lost x this).
const PART_WEAR := 3.5
const REPAIR_REACH_INSIDE := 2.6
const REPAIR_REACH_OUTSIDE := 4.5
## The deck hatch the room's ladder climbs to (hull space, on the port side
## of the main deck), and where you stand when you come up through it.
const DECK_HATCH := Vector3(-5.5, 3.3, -9.0)
const DECK_ARRIVAL := Vector3(-5.5, 3.44, -7.2)
var city := CityState.new()
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
var gates: PlanetStrongholds  # the planets' boss fortresses (StrongholdGates for Boss and the gate keys)
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
## Ships waiting for a busy port: port key -> [ship id, ...] in order.
var port_queues := {}
## Farther than this from a planet's surface, a waiting ship leaves its line.
const QUEUE_RANGE := 1600.0

## The shared Space ("astral") or a private realm's own ("astral_<campaign realm>").
static func is_space(id: String) -> bool:
	return id==REALM or id.begins_with(REALM+"_")

func _init(data: Dictionary) -> void:
	record = data
	realm_id = str(data.get("id", REALM))
	display_name = "The Space"
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

func game_root() -> Node:
	return get_parent()

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
	queue_load_step(func() -> void:
		gates = PlanetStrongholds.new()
		gates.name = "PlanetStrongholds"
		add_child(gates)
		gates.build_planets(self, not visual)
		gates.changed.connect(func(center: Vector2i, locked: bool, sealed: bool) -> void:
			if Net.is_server(): Net.server.fortress_gate(self, center, locked, sealed)))
	for p: Dictionary in SpaceLayout.PLANETS: queue_load_step(_place_planet_packs.bind(p))
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
	if zone=="planet:"+CityLayout.ID:
		for d: Dictionary in CityLayout.DISTRICTS:
			var at: Vector3 = (CityLayout.planet().center as Vector3)+CityLayout.district_frame(d).origin
			if position.distance_to(at)<260.0: return "Vesperis - "+str(d.name)
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
		# The arena is one flat plane, with gravity aligned at its centre.
		if SpaceLayout.FORTS.has(p.id):
			var fort: Transform3D = SpaceLayout.fort_frame(p)
			var relative: Vector3 = position-(p.center as Vector3)
			var local: Vector3 = fort.affine_inverse()*relative
			if Vector2(local.x, local.z).length()<SpaceLayout.FORT_FLAT and relative.dot(fort.basis.y)>0.0:
				var ground: Vector3 = (p.center as Vector3)+fort*Vector3(local.x, 0.0, local.z)
				return {frame = Transform3D(fort.basis, ground), zone = "planet:"+str(p.id), distance = position.distance_to(ground)}
		var right := up.cross(Vector3.FORWARD if absf(up.dot(Vector3.FORWARD))<0.95 else Vector3.RIGHT).normalized()
		var surface: Vector3 = p.center+up*(float(p.radius)+SpaceLayout.surface_height(p, up))
		return {frame = Transform3D(Basis(right, up, right.cross(up)), surface), zone = "planet:"+str(p.id), distance = position.distance_to(surface)}
	return {frame = Transform3D(Basis.IDENTITY, position), zone = "void", distance = 1e6}

func first_person_at(position: Vector3) -> bool:
	return SpaceLayout.pocket_at(position)>=0 or city.car_at(position)>=0

## Anywhere inside the Reach: spacewalkers float in open space on jetpacks.
func is_walkable(position: Vector3) -> bool:
	return position.is_finite() and (position.length()<SpaceLayout.WORLD_RADIUS or SpaceLayout.pocket_at(position)>=0)

func recovery_point(position: Vector3) -> Vector3:
	var state := sample_gravity(position)
	if state.zone=="planet:"+CityLayout.ID: return position
	if state.zone=="void" or float(state.distance)>40.0: return spawn_point
	var frame: Transform3D = state.frame
	return frame.origin+frame.basis.y*0.12

func extra_speed(from: Vector3, to: Vector3) -> float:
	if SpaceLayout.pocket_at(to)>=0 or SpaceLayout.pocket_at(from)>=0: return 0.0
	var extra := 0.0
	if zone_at(to)=="void" or zone_at(from)=="void" or str(zone_at(to)).begins_with("planet:") or str(zone_at(from)).begins_with("planet:"):
		extra += SpaceTraversal.JET_MAX*1.8
	# Near a ship: she may be carrying them (on deck or on the line), turning included.
	for ship: SpaceShip in ships.values():
		if ship.xform.origin.distance_to(to)<90.0 or ship.xform.origin.distance_to(from)<90.0:
			extra = maxf(extra, ship.velocity.length()*1.3+ship.speed*0.3+25.0)
	return extra

func legal_recovery(from: Vector3, to: Vector3) -> bool:
	return to.distance_to(recovery_point(from))<2.5

func make_controller(actor: Player) -> SpatialController:
	local_player = actor
	return SpaceTraversal.new().setup(actor, self)

func map_color(_x: int, _z: int) -> Color: return Color("05060f")
## On a planet's top the real ground (arrows and bullets fly a fixed height
## above it, enemies walk on it); elsewhere the station deck.
## Enemy shots on a planet's top ride shot height over its ground (EnemyBullets).
func bullet_ground(x: float, z: float) -> float:
	var p := SpaceLayout.cap_planet(x, z)
	return SpaceLayout.cap_height(p, x, z) if not p.is_empty() else NAN

func ground_height(x: float, z: float) -> float:
	var p := SpaceLayout.cap_planet(x, z)
	return SpaceLayout.cap_height(p, x, z) if not p.is_empty() else 0.0

## Planet enemies keep to the ground (the server has no planet collision).
func hold_enemy(enemy: Enemy) -> void:
	var p := SpaceLayout.cap_planet(enemy.global_position.x, enemy.global_position.z)
	if p.is_empty(): return
	var ground := SpaceLayout.cap_height(p, enemy.global_position.x, enemy.global_position.z)
	if enemy.global_position.y<ground+0.35:
		enemy.global_position.y = ground
		enemy.velocity.y = 0.0

## Planet enemies walk around trees, rocks and buildings, and stay on their world's top.
func enemy_blocked(pos: Vector3) -> bool:
	var p := SpaceLayout.cap_planet(pos.x, pos.z)
	if p.is_empty(): return false
	var up: Vector3 = (pos-(p.center as Vector3)).normalized()
	if up.y<cos(SpaceLayout.COMBAT_CAP+0.08): return true
	for flat: Array in SpaceLayout._flat_spots(p).slice(1):
		if flat.size()>2: continue  # the fortress terrace: its walls decide (below)
		if acos(clampf(up.dot(flat[0]), -1.0, 1.0))*float(p.radius)<float(flat[1])+6.0: return true
	if is_instance_valid(gates) and gates.blocks_enemy(pos): return true
	return PlanetFlora.blocked(p, pos-(p.center as Vector3), 0.3)

func enemy_spawn_clear(pos: Vector3, radius: float, height: float) -> bool:
	if enemy_blocked(pos): return false
	return super.enemy_spawn_clear(pos, radius, height)

## Packs across every planet's top (SpaceEnemies.PLANET_PACKS), seeded so all
## clients and the server agree; obstacle packs gather by their obstacles.
func _place_planet_packs(p: Dictionary) -> void:
	if true:
		var rng := RandomNumberGenerator.new()
		rng.seed = absi(String(p.id).hash())+977
		var r := float(p.radius)
		var used: Array[Vector3] = []
		var scale := _pack_scale(p)
		for spec: Array in SpaceEnemies.PLANET_PACKS.get(p.id, []):
			var near := str(spec[5])
			var spots: Array = []
			if near!="":
				for item: Dictionary in PlanetFlora.placements(p):
					if item.decor or str(item.name)!=near: continue
					var dir: Vector3 = item.dir
					if acos(clampf(dir.y, -1.0, 1.0))<SpaceLayout.COMBAT_CAP*0.9: spots.append(dir)
			var count := int(spec[3]) if str(spec[0])=="god" else maxi(1, roundi(int(spec[3])*scale))
			for i in count:
				var dir := Vector3.ZERO
				for attempt in 40:
					if not spots.is_empty():
						dir = spots[rng.randi() % spots.size()]
						# Beside the obstacle, not inside it.
						dir = (dir+Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)).normalized()*(5.0/r)).normalized()
					else:
						var angle := rng.randf()*TAU
						var arc := rng.randf_range(70.0, SpaceLayout.COMBAT_CAP*r*0.92)
						dir = Vector3(sin(arc/r)*cos(angle), cos(arc/r), sin(arc/r)*sin(angle))
					var at := SpaceLayout.surface_point(p, (p.center as Vector3)+dir)
					if enemy_blocked(at+Vector3(0.01, 0, 0)) and spots.is_empty(): continue
					if used.any(func(u: Vector3) -> bool: return u.distance_to(at)<24.0): continue
					if SpaceLayout.FORTS.has(p.id) and at.distance_to(PlanetStrongholds.floor_center(p.id))<80.0: continue
					used.append(at)
					_planet_site(p, "%s_%d" % [spec[0], i], spec, at)
					break

		if SpaceLayout.FORTS.has(p.id): _fort_sites(p)

## Enemies a planet holds at once: 40 on the gentlest worlds up to 100 on
## the most dangerous (danger 0..3).
const PLANET_ENEMIES := [40, 60, 80, 100]

## How many times the table's pack counts (SpaceEnemies.PLANET_PACKS) to
## place so planet `p` holds about its PLANET_ENEMIES (the god's pack once).
static func _pack_scale(p: Dictionary) -> float:
	var base := 0.0
	var god := 0.0
	for spec: Array in SpaceEnemies.PLANET_PACKS.get(p.id, []):
		var size := 1.0 if str(spec[2])!="" else 0.0
		for m: Array in spec[1]: size += (float(m[1])+float(m[2]))*0.5
		if str(spec[0])=="god": god += size
		else: base += size*int(spec[3])
	if base<=0.0: return 1.0
	var target := float(PLANET_ENEMIES[clampi(int(p.get("danger", 0)), 0, 3)])
	return maxf(1.0, (target-god)/base)

## The fortress's boss in the middle and its guards inside the walls (they
## wake only once someone is in). Both come back a while after they fall.
func _fort_sites(p: Dictionary) -> void:
	var fort: Dictionary = SpaceLayout.FORTS[p.id]
	var at := PlanetStrongholds.floor_center(p.id)
	var boss_key := "%s_%s_fort_boss" % [realm_id, p.id]
	Enemies.pack_overrides[boss_key] = {members = [], leader = {enemy = fort.boss, min_members = 0}, respawn_time = 480.0, activate_radius = 60.0}
	enemy_director.add_quest_site({id = boss_key, pack = boss_key, pos = at, seed = absi(boss_key.hash()) % 99991})
	var guards: Array = []
	for id: String in SpaceEnemies.CAST:
		var c: Array = SpaceEnemies.CAST[id]
		if str(c[1])==p.id and str(c[10]) in ["small", "big"]: guards.append({enemy = id, min = 1 if str(c[10])=="big" else 2, max = 2 if str(c[10])=="big" else 3})
	if guards.is_empty(): return
	var frame := SpaceLayout.fort_frame(p)
	for side in [-1, 1]:
		var key := "%s_%s_fort_guards_%d" % [realm_id, p.id, side+1]
		var spot: Vector3 = at+frame.basis*Vector3(side*18.0, 0, -12.0)
		Enemies.pack_overrides[key] = {members = guards.duplicate(true), respawn_time = 480.0, activate_radius = 30.0}
		enemy_director.add_quest_site({id = key, pack = key, pos = spot, seed = absi(key.hash()) % 99991})

func _planet_site(p: Dictionary, name: String, spec: Array, at: Vector3) -> void:
	var key := "%s_%s_%s" % [realm_id, p.id, name]
	var members: Array = []
	for m: Array in spec[1]: members.append({enemy = m[0], min = m[1], max = m[2]})
	var pack := {members = members, respawn_time = float(spec[4]), activate_radius = 90.0}
	if str(spec[2])!="": pack.leader = {enemy = spec[2], min_members = 0}
	Enemies.pack_overrides[key] = pack
	enemy_director.add_quest_site({id = key, pack = key, pos = at, seed = absi(key.hash()) % 99991})
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
	if Net.is_server():
		var p := Net.server.social.record(player_id)
		if not p.is_empty() and ship.account_id>0 and int(p.get("account_id", 0))==ship.account_id: return true
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
		"rocket_surface":
			if not Net.is_server() or not is_instance_valid(station): return
			var pad: Transform3D = station.anchors.get("rocket_pad", Transform3D.IDENTITY)
			if pos.distance_to(station.to_global(pad.origin))>8.0 or zone_at(pos)!="station": return
			p.port = {kind = "rocket", destination = surface_realm()}
		"city":
			if args.size()>1 and str(args[1]) in ["sip", "order"]: return
			var before := city.seat_of(pid)
			var message := city.handle(pid, pos, args)
			var after := city.seat_of(pid)
			if before!=after:
				if after!="": teleport(p, CityLayout.any_seat(after).pos, "city_seat")
				elif before!="": teleport(p, CityLayout.any_seat(before).stand, "city_stand")
			if message!="": _tell(p, message)
			_broadcast_city()
		"spawn", "buy_ship":
			if Net.is_server(): Net.server.fleet.on_action(p, ["list"])
			else: _tell(p, "Fleet management needs an account connection.")
		"board":
			var ship: SpaceShip = ships.get(int(args[1]) if args.size()>1 else 0)
			if ship==null or not _may_board(ship, pid):
				_tell(p, "That ship belongs to another crew.")
				return
			var near := zone_at(pos)=="station" if ship.mode=="berth" else _beside_landed(ship, pos) if ship.mode=="landed" else false
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
			if ship.grounded() and seat!="pilot":
				_tell(p, "Only the helm and the boarding hatch work while she is grounded. Launch first.")
				return
			var taken := int(ship.crew.get(seat, 0))
			if taken!=0 and taken!=pid:
				_tell(p, "Someone already sits there.")
				return
			Leisure.before_travel(p)
			_stand(ship, pid)
			ship.crew[seat] = pid
			_broadcast_ship(ship)
		"stand":
			var ship := ship_of(pid)
			if ship!=null:
				# Up off the chair onto its standing spot (not left wedged in the chair).
				var spot: Vector3 = seat_spec(ship.slot, ship.seat_of(pid)).get("stand", Vector3.INF)
				_stand(ship, pid)
				_broadcast_ship(ship)
				if spot.is_finite(): teleport(p, spot+Vector3.UP*0.05, "ship_stand")
		"takeoff":
			var ship := ship_of(pid)
			if ship==null or ship.pilot()!=pid or not ship.mode in ["landed", "berth"] or ship.broken: return
			var from := ship.planet if ship.mode=="landed" else ""
			ship.mode = "flying"
			ship.planet = ""
			ship.port = ""
			ship.velocity = ship.xform.basis.y*30.0
			ship.speed = 0.0
			ship.settle_orbit(from)  # off a planet's pad she climbs straight into orbit
			_broadcast_ship(ship)
			var launch_event: Array = ["launch_shake", ship.id]
			handle_event(launch_event)
			world_event.emit(launch_event)
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
				_tell(p, "Fly in low and slow over one of the planet's ports (the red ship marks) to land.")
				return
			_ask_port(ship, target)
		"dock":
			var ship := ship_of(pid)
			if ship==null or ship.pilot()!=pid or ship.mode!="flying": return
			if ship.xform.origin.distance_to(SpaceLayout.NEXUS)>DOCK_RANGE:
				_tell(p, "Fly closer to the Nexus to dock.")
				return
			ship.dock(ship.berth)
			_broadcast_ship(ship)
		"descend":  # the pilot takes the ship down to the Surface
			var ship := ship_of(pid)
			if ship==null or ship.pilot()!=pid or ship.mode!="flying": return
			if not SpaceLayout.can_descend(ship.xform.origin):
				_tell(p, "Fly lower, down toward the Surface, to descend.")
				return
			if Net.is_server() and not Net.server.fleet.reserve_landing(self, ship):
				_tell(p, "The Surface launch pad is occupied. Wait until it is clear.")
				return
			var crew := _aboard(ship)
			if Net.is_server():
				Net.server.surface_port.prepare_transfer(self, ship, surface_realm(), "descend", crew)
			ship.mode = "descending"
			ship.speed = 0.0
			ship.velocity = Vector3.ZERO
			_broadcast_ship(ship)
			var event: Array = ["descend", ship.id, surface_realm(), crew]
			handle_event(event)
			world_event.emit(event)
			# The ship goes with them; it comes back up when they launch again.
			get_tree().create_timer(12.0).timeout.connect(func() -> void:
				if ships.has(ship.id) and ship.mode=="descending": _retire(ship))
		"aim":
			var ship := ship_of(pid)
			if ship==null or args.size()<2 or not args[1] is Vector3: return
			if not (args[1] as Vector3).is_finite() or (args[1] as Vector3).length_squared()<0.001: return
			var seat := ship.seat_of(pid)
			if seat.begins_with("turret"): ship.aims[seat] = (args[1] as Vector3).normalized()
		"fire":
			var ship := ship_of(pid)
			if ship==null or args.size()<2 or not args[1] is Vector3: return
			if not (args[1] as Vector3).is_finite() or (args[1] as Vector3).length_squared()<0.001: return
			var seat := ship.seat_of(pid)
			if Leisure.hands_busy(pid) or (seat!="pilot" and not seat.begins_with("turret")) or ship.mode!="flying" or Time.get_ticks_msec()<int(ship.cooldowns.get(seat, 0)): return
			# A damaged top cannon fires slowly; a broken one jams.
			var gun := ship.part("turret") if seat=="turret_top" else 1.0
			if gun<=0.0:
				_tell(p, "The top cannon is jammed! Mend it from the deck.")
				ship.cooldowns[seat] = Time.get_ticks_msec()+3000
				return
			ship.cooldowns[seat] = Time.get_ticks_msec()+int(180.0*(1.0+2.0*(1.0-gun)))
			var dir := -ship.xform.basis.z if seat=="pilot" else (args[1] as Vector3).normalized()
			ship.aims[seat] = dir
			foes.fire_bolt(ship, turret_muzzle(ship, seat), dir, pid, seat=="pilot")
		"repair":  # [part] inside, or [ship id, part] outside
			var ship: SpaceShip = (ships.get(int(args[1])) if args.size()>2 else ship_in_slot(SpaceLayout.pocket_at(pos)))
			var id := str(args[-1])
			if ship==null or not SpaceShip.PARTS.has(id) or not _may_board(ship, pid): return
			if args.size()<=2 and ship.grounded():
				_tell(p, "Only the helm and the boarding hatch work while she is grounded. Launch first.")
				return
			if float(ship.parts[id])>=100.0:
				_tell(p, "The %s need no mending." % str(SpaceShip.PARTS[id].name).to_lower())
				return
			if repair_point(ship, id, pos).is_finite():
				_repairs["%d:%s" % [ship.id, id]] = {pid = pid, t = 0.0, ship = ship.id, part = id}
				_tell(p, "Mending the %s... stay close." % str(SpaceShip.PARTS[id].name).to_lower())
			else:
				_tell(p, "Get closer to the %s." % str(SpaceShip.PARTS[id].name).to_lower())
		"drink":
			Leisure.action(p, ["sip"], self)
		"pour":
			var vessel := ship_in_slot(SpaceLayout.pocket_at(pos))
			if vessel and not vessel.grounded(): Leisure.action(p, ["use", "ship:%d:beer" % (vessel.fleet_id if vessel.fleet_id>0 else vessel.id)], self)
		"cigar":
			Leisure.action(p, ["cigar"], self)
		"deck":
			# Up the room's ladder onto the deck, or back down through the deck hatch.
			var slot := SpaceLayout.pocket_at(pos)
			if slot>=0:
				var ship := ship_in_slot(slot)
				if ship==null or pos.distance_to(pocket_point(slot, interior_anchors.get("ladder", Vector3.ZERO)))>3.5: return
				if ship.grounded():
					_tell(p, "The deck hatch stays shut while she is grounded. Go out through the boarding hatch.")
					return
				_stand(ship, pid)
				teleport(p, ship.xform*DECK_ARRIVAL, "deck")
			else:
				# [deck, ship id, where they stand in her frame]: checked in her
				# frame, since the client sees her a moment in the past.
				if args.size()>2 and args[2] is Vector3:
					var ship: SpaceShip = ships.get(int(args[1]))
					var slack := maxf(absf(ship.speed), ship.velocity.length())*1.0 if ship else 0.0
					if ship and _may_board(ship, pid) and (args[2] as Vector3).distance_to(DECK_HATCH)<5.0 and pos.distance_to(ship.xform*DECK_HATCH)<40.0+slack:
						teleport(p, pocket_point(ship.slot, (interior_anchors.get("ladder", Vector3.ZERO) as Vector3)+Vector3(1.2, 0.1, 0)), "below")
					return
				for ship: SpaceShip in ships.values():
					var slack := maxf(absf(ship.speed), ship.velocity.length())*(SpaceShipView.DELAY+0.25)
					if _may_board(ship, pid) and pos.distance_to(ship.xform*DECK_HATCH)<5.0+slack:
						teleport(p, pocket_point(ship.slot, (interior_anchors.get("ladder", Vector3.ZERO) as Vector3)+Vector3(1.2, 0.1, 0)), "below")
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
## Exact quest indicator for one native ship repair, on deck or in the room.
func repair_mark(ship: SpaceShip, id: String) -> Vector3:
	if not SpaceShip.PARTS.has(id): return Vector3.INF
	if bool(SpaceShip.PARTS[id].inside):
		return pocket_point(ship.slot, (interior_anchors.get("repairs", {}) as Dictionary).get(id, Vector3.ZERO))
	return ship.xform*(SpaceShip.PARTS[id].mend as Vector3)

## Protect parked, orbiting and empty battleships in an active private tale:
## fleet inactivity timers must never store them while the story is running.
func protected_campaign_ship(ship: SpaceShip) -> bool:
	if realm_id==REALM or not Net.is_server(): return false
	for party: Dictionary in Net.server.social.parties.values():
		if party.get("campaign", {}).is_empty(): continue
		# The same fleet protection applies when the ship has temporarily
		# descended to the private Surface world of the campaign.
		var surface := str(party.campaign.realm)
		if realm_id!=surface and realm_id!=PortServer.space_for(surface): continue
		var run: Dictionary = Net.server.campaigns._run_of(party)
		if run.get("status", "")=="active" and (ship.party==int(party.id) or int(ship.owner) in party.members): return true
	return false

func repair_point(ship: SpaceShip, id: String, pos: Vector3) -> Vector3:
	if SpaceShip.PARTS[id].inside:
		var spot := pocket_point(ship.slot, (interior_anchors.get("repairs", {}) as Dictionary).get(id, Vector3.ZERO))
		return spot if SpaceLayout.pocket_at(pos)==ship.slot and pos.distance_to(spot)<REPAIR_REACH_INSIDE else Vector3.INF
	var spot := ship.xform*(SpaceShip.PARTS[id].mend as Vector3)
	if pos.distance_to(spot)<REPAIR_REACH_OUTSIDE+(9.0 if ship.mode=="landed" else 0.0): return spot
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
	# Leaving the helm: she keeps her throttle (holds speed and heading).
	if seat=="pilot": ship.input = [ship.cruise(), 0.0, 0.0, 0.0, false, false]

# --- To and from the Surface ---------------------------------------------------------------

## Up from the Surface (PortServer): the captain's battleship rises at
## SpaceLayout.ASCENT with the captain at the helm; crew arrive in its room.
## Returns where the player arrives (or INF).
func arrive_from_surface(p: Dictionary, captain: int, owned: bool) -> Vector3:
	var pid := int(p.player_id)
	var ship := _ship_of_owner(captain)
	if ship==null:
		if pid!=captain: return Vector3.INF
		ship = _launch_ship(captain, str(p.get("name", "Captain")))
		if ship==null: return Vector3.INF
		if owned:
			ship.name = str(_fleet(p).get("name", ship.name))
			ship.set_meta("account", int(p.get("account_id", 0)))
	if pid==captain:
		var toward := Vector3(SpaceLayout.NEXUS.x-SpaceLayout.ASCENT.x, 0, SpaceLayout.NEXUS.z-SpaceLayout.ASCENT.z).normalized()
		ship.xform = Transform3D(Basis.looking_at(toward, Vector3.UP), SpaceLayout.ASCENT)
		ship.mode = "flying"
		ship.planet = ""
		ship.speed = 40.0
		ship.velocity = toward*40.0
		for seat: String in ship.crew.keys():
			if int(ship.crew[seat])==pid: ship.crew.erase(seat)
		ship.crew["pilot"] = pid
		_broadcast_ship(ship)
		return seat_spec(ship.slot, "pilot").get("pos", pocket_point(ship.slot, interior_anchors.get("spawn", Vector3(0, 0.1, 14))))
	return pocket_point(ship.slot, interior_anchors.get("spawn", Vector3(0, 0.1, 14)))

## Back from the Tavern to where they were. Their ship comes back too if it
## was lost while they were away (the Reach unloaded, the server restarted).
func arrive_back(p: Dictionary, travel: Dictionary, owned: bool) -> Vector3:
	var pid := int(p.player_id)
	var saved: Array = travel.get("pos", [])
	var at := Vector3(float(saved[0]), float(saved[1]), float(saved[2])) if saved.size()==3 else spawn_point
	var snap: Dictionary = travel.get("ship", {})
	var saved_fleet := int(snap.get("fleet_id", 0))
	var ship: SpaceShip
	if saved_fleet>0:
		for candidate: SpaceShip in ships.values():
			if candidate.fleet_id==saved_fleet: ship = candidate
	else: ship = _ship_of_owner(pid)
	var saved_slot := SpaceLayout.pocket_at(at)
	if bool(travel.get("aboard", false)) or saved_slot>=0:
		if ship:
			# Interior slots can change when a ship is restored. Keep the exact
			# position within the room rather than resetting to its entrance.
			if saved_slot>=0: return pocket_point(ship.slot, at-SpaceLayout.pocket_origin(saved_slot))
			return pocket_point(ship.slot, interior_anchors.get("spawn", Vector3(0, 0.1, 14)))
		var crew_ship := ship_in_slot(saved_slot) if saved_slot>=0 else null
		if crew_ship!=null and _may_board(crew_ship, pid): return at
		return spawn_point
	return at if zone_at(at)!="void" or ship!=null else spawn_point

## The player's own ship, for the way back ({} when they have none here).
func ship_snapshot(pid: int) -> Dictionary:
	var p := _record(pid)
	var ship := ship_in_slot(SpaceLayout.pocket_at(p.get("pos", Vector3.INF)))
	if ship==null: ship = _ship_of_owner(pid)
	if ship==null: return {}
	var b := ship.xform.basis
	var o := ship.xform.origin
	return {fleet_id = ship.fleet_id, name = ship.name, mode = ship.mode, planet = ship.planet,
		xform = [b.x.x, b.x.y, b.x.z, b.y.x, b.y.y, b.y.z, b.z.x, b.z.y, b.z.z, o.x, o.y, o.z]}

func _ship_of_owner(pid: int) -> SpaceShip:
	for ship: SpaceShip in ships.values():
		if ship.owner==pid: return ship
	return null

## Where a descending ship's crew lands: this Space's Surface.
func surface_realm() -> String:
	return PortServer.surface_for(realm_id)

## Everyone in a ship's room (the crew, seated or standing).
func _aboard(ship: SpaceShip) -> Array:
	var out: Array = []
	if Net.is_server():
		var realm: RealmInstance = Net.server.realms.get(realm_id)
		if realm:
			for pid: int in realm.proxies:
				var p: Dictionary = Net.server.social.record(pid)
				if not p.is_empty() and SpaceLayout.pocket_at(p.pos)==ship.slot: out.append(pid)
	elif is_instance_valid(local_player) and SpaceLayout.pocket_at(local_player.global_position)==ship.slot:
		out.append(local_player.player_id)
	return out

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
	if str(Leisure.state(int(p.player_id)).get("seat", ""))!="": Leisure.before_travel(p)
	if reason!="city_seat" and city.stand(int(p.player_id)): city.changed = true
	if Net.is_server():
		var peer := int(p.get("peer_id", 0))
		p.pos = to
		p.grace = NetServer.SNAP_BACK_GRACE*8.0
		p.moved_at = 0.0
		var realm: RealmInstance = Net.server.realms.get(realm_id)
		if realm and realm.proxies.has(int(p.player_id)): realm.proxies[int(p.player_id)].global_position = to
		if peer!=0:
			Net.c_correct.rpc_id(peer, to)
			Net.server._to_peer(peer, ["theory", ["moved", reason, to]])
	elif is_instance_valid(local_player):
		local_player.global_position = to
		local_player.velocity = Vector3.ZERO
		handle_event(["moved", reason])

func _tell(p: Dictionary, text: String) -> void:
	if Net.is_server():
		if int(p.get("peer_id", 0))!=0: Net.server._to_peer(int(p.peer_id), ["theory", ["say", text]])
	else: handle_event(["say", text])

## A ship room whose ship is gone (lost or stored): nobody belongs there.
func stale_pocket(pos: Vector3) -> bool:
	var slot := SpaceLayout.pocket_at(pos)
	return slot>=0 and ship_in_slot(slot)==null

func pocket_point(slot: int, local: Vector3) -> Vector3:
	return SpaceLayout.pocket_origin(slot)+local

## Whether `pos` stands beside landed `ship` (anywhere around her hull, as
## SpaceInteraction offers boarding), with a little slack for lag.
func _beside_landed(ship: SpaceShip, pos: Vector3) -> bool:
	if pos.distance_to(hatch_position(ship))<9.0: return true
	var local := ship.xform.affine_inverse()*pos
	var half := ShipHull.beam(clampf(local.z, ShipHull.BOW_Z, ShipHull.STERN_Z))
	var near := Vector2(clampf(local.x, -half, half), clampf(local.z, ShipHull.BOW_Z, ShipHull.STERN_Z))
	return near.distance_to(Vector2(local.x, local.z))<=SpaceInteraction.LANDED_REACH+3.0 and absf(local.y+SpaceShip.LANDED_HEIGHT)<8.0

## Where the crew steps out of a landed ship.
func hatch_position(ship: SpaceShip) -> Vector3:
	var hatch: Transform3D = hull_anchors.get("hatch", Transform3D(Basis.IDENTITY, Vector3(9, -3, 4)))
	var at := ship.xform*hatch.origin
	if ship.planet==CityLayout.ID:
		# Exit onto the flat port roof, above its surface (not the sphere below).
		return ship.xform*Vector3(hatch.origin.x, -SpaceShip.LANDED_HEIGHT+0.15, hatch.origin.z)
	var gravity := sample_gravity(at)
	return (gravity.frame as Transform3D).origin+(gravity.frame as Transform3D).basis.y*0.15 if gravity.zone!="void" else at

func turret_muzzle(ship: SpaceShip, seat: String) -> Vector3:
	# Muzzles of the hull's turret mounts (ShipHull), roughly where the barrels end.
	var offsets := {pilot = Vector3(0, 0.45, ShipHull.BOW_Z-7.0), turret_top = Vector3(0, ShipHull.DECK_TOP+2.1, -17.9), turret_left = Vector3(-10.2, 2.42, -4.9), turret_right = Vector3(10.2, 2.42, -4.9)}
	return ship.xform*(offsets.get(seat, Vector3.ZERO) as Vector3)

## Flames on the heart crystal in the ship's room while it is destroyed.
func _burn_heart(ship: SpaceShip) -> void:
	var room: Node3D = interiors.get(ship.slot)
	if room==null: return
	var fire := room.get_node_or_null("HeartFire")
	var on := ship.part_destroyed("heart")
	if on and fire==null:
		var blaze := ShipDamage.blaze(1.4)
		blaze.name = "HeartFire"
		blaze.position = (interior_anchors.get("heart", Vector3(6.8, 0, -2.6)) as Vector3)+Vector3.UP*0.7
		room.add_child(blaze)
	elif not on and fire!=null:
		fire.queue_free()

func _ensure_interior(slot: int) -> void:
	var vessel := ship_in_slot(slot)
	var identity := (vessel.fleet_id if vessel.fleet_id>0 else vessel.id) if vessel else 0
	if interiors.has(slot):
		var existing: ShipInterior = interiors[slot]
		if int(existing.get_meta("vessel", 0))==identity: return
		existing.set_meta("vessel", identity)
		var furniture := existing.get_node_or_null("LeisureFurniture")
		if furniture:
			existing.remove_child(furniture)
			furniture.queue_free()
		LeisureFurniture.ship(self, existing, slot, server_build or Net.is_server())
		return
	var room := ShipInterior.new()
	room.set_meta("vessel", identity)
	room.position = SpaceLayout.pocket_origin(slot)
	add_child(room)
	room.build(server_build or Net.is_server())
	interiors[slot] = room
	LeisureFurniture.ship(self, room, slot, server_build or Net.is_server())
	if not (server_build or Net.is_server()): _interior_props(slot, room)

# --- Authority loop ------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if Net.is_client():
		_follow_foe_marks()
		return
	city.step()
	_broadcast_city()
	_arrive_rescues()
	_mend(delta)
	_burn_cigars(delta)
	# Landing checks need every planet's obstacle list; build one per tick.
	if _warm<SpaceLayout.PLANETS.size():
		PlanetFlora._obstacle_index(SpaceLayout.PLANETS[_warm])
		_warm += 1
	if not port_queues.is_empty(): _update_queues()
	for ship: SpaceShip in ships.values().duplicate():
		if ship.mode=="descending": ship.xform.origin += Vector3.DOWN*600.0*delta
		var damage := ship.step(delta, _asteroids)
		if damage>0: hurt_ship(ship, damage)
	_snapshot_timer -= delta
	if _snapshot_timer<=0.0 and not ships.is_empty():
		_snapshot_timer = SNAPSHOT_INTERVAL
		# Stamped with server time: clients place each sample on the server's
		# clock, not on when it happened to arrive (at full speed a few
		# milliseconds of arrival jitter is metres of back-and-forth).
		var event: Array = ["ships", ships.values().map(func(s: SpaceShip) -> Array: return s.wire()), Net.now()]
		handle_event(event)
		world_event.emit(event)

## A hit: the hull loses `damage` and the part nearest `at` (world) takes its share.
func hurt_ship(ship: SpaceShip, damage: int, at := Vector3.INF) -> void:
	if not ships.has(ship.id) or ship.mode=="storing": return
	# Space Travels teaches damage without ever allowing a tutorial battle
	# (or an accidental asteroid impact during repairs) to destroy the ship.
	if Net.is_server() and realm_id!=REALM:
		for party: Dictionary in Net.server.social.parties.values():
			if party.get("campaign", {}).get("id", "")!="first_light" or PortServer.space_for(str(party.campaign.realm))!=realm_id: continue
			var run := Net.server.campaigns._run_of(party)
			if run.get("status", "")=="active" and Campaigns.step_def("first_light", int(run.step)).get("id", "") in ["ambush", "repairs"] and (ship.party==int(party.id) or int(ship.owner) in party.members):
				damage = mini(damage, maxi(0, ship.hp-SpaceShip.MAX_HP/2))
				break
	if damage<=0: return
	ship.hp = maxi(0, ship.hp-damage)
	var id: String = SpaceShip.part_at(ship.xform.affine_inverse()*at) if at.is_finite() else SpaceShip.PARTS.keys()[randi() % SpaceShip.PARTS.size()]
	var before := float(ship.parts.get(id, 100.0))
	ship.parts[id] = maxf(0.0, before-float(damage)/float(SpaceShip.MAX_HP)*100.0*PART_WEAR)
	if before>=50.0 and float(ship.parts[id])<50.0:
		var many := id in ["engines", "sails"]
		_tell_crew(ship, "The %s %s damaged! Mend %s %s." % [str(SpaceShip.PARTS[id].name).to_lower(), "are" if many else "is",
			"them" if many else "it", "inside the ship" if SpaceShip.PARTS[id].inside else "outside (ladder to the deck) or from the ground"])
	if ship.hp<=0:
		if Net.is_server() and ship.fleet_id>0: Net.server.fleet.destroyed(ship)
		else: _forget(ship)
		_scuttle(ship, "%s breaks apart around you! Your jetpacks keep you floating." % ship.name)

## The ship is lost: its crew wakes at the Nexus.
## A ship that went down to the Surface leaves Space quietly (no wreck).
func _retire(ship: SpaceShip) -> void:
	ships.erase(ship.id)
	var event: Array = ["ship-", ship.id, ship.xform.origin, "", true]
	handle_event(event)
	world_event.emit(event)

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
	var event: Array = ["ships", [ship.wire()], Net.now()]
	handle_event(event)
	world_event.emit(event)

## Players leaving the server or the world give up their seats.
func player_left(pid: int) -> void:
	if city.stand(pid): city.changed = true
	_broadcast_city()
	for ship: SpaceShip in ships.values():
		_stand(ship, pid)

# --- Replication --------------------------------------------------------------------------

## Whether another ship is on port `key` or setting down on it.
func _fleet_pad_reserved(key: String) -> bool:
	return Net.is_server() and Net.server.fleet.pad_reserved(realm_id, key)

func port_taken(key: String, except_id := 0) -> bool:
	for ship: SpaceShip in ships.values():
		if ship.id==except_id: continue
		if (ship.mode=="landed" and ship.port==key) or (ship.mode=="landing" and str(ship.landing.get("port", ""))==key): return true
	return false

## The pilot asks to land at a port: straight down if it is free and nobody
## is waiting ahead, else into its line.
func _ask_port(ship: SpaceShip, target: Dictionary) -> void:
	var key := str(target.port.key)
	for other: String in port_queues.keys():
		if other!=key: port_queues[other].erase(ship.id)
	var line: Array = port_queues.get(key, [])
	if not port_taken(key, ship.id) and not _fleet_pad_reserved(key) and (line.is_empty() or int(line[0])==ship.id):
		line.erase(ship.id)
		ship.begin_landing(target.planet, target.port)
		_broadcast_ship(ship)
		return
	if not ship.id in line:
		line.append(ship.id)
		_tell_crew(ship, "%s is busy. You are number %d in line to land." % [target.port.name, line.size()])
	port_queues[key] = line
	_update_queues()

## Every tick: waiting ships that flew off leave their line; the first ship of
## a line whose port came free sets down by herself.
func _update_queues() -> void:
	for key: String in port_queues.keys():
		var found := SpaceLayout.port(key)
		var line: Array = port_queues[key]
		for id: int in line.duplicate():
			var ship: SpaceShip = ships.get(id)
			if ship==null or ship.mode!="flying":
				line.erase(id)
				if ship: ship.queue = []
				continue
			var p: Dictionary = found.get("planet", {})
			if p.is_empty() or ship.xform.origin.distance_to(p.center)>float(p.radius)+QUEUE_RANGE:
				line.erase(id)
				ship.queue = []
				_tell_crew(ship, "You flew away from %s and left the landing line." % str(p.get("name", "the planet")))
				_broadcast_ship(ship)
		if not line.is_empty() and not port_taken(key) and not _fleet_pad_reserved(key):
			var first: SpaceShip = ships[int(line.pop_front())]
			first.begin_landing(found.planet, found.port)
			_tell_crew(first, "%s is free. Setting down." % found.port.name)
			_broadcast_ship(first)
		for k in line.size():
			var ship: SpaceShip = ships[int(line[k])]
			var place := [str(found.port.name), k+1]
			if ship.queue!=place:
				ship.queue = place
				_broadcast_ship(ship)
		if line.is_empty(): port_queues.erase(key)
		else: port_queues[key] = line

func _broadcast_city() -> void:
	if not city.changed: return
	city.changed = false
	world_event.emit(["city", city.wire()])

func handle_event(event: Array) -> void:
	match str(event[0]):
		"city":
			if Net.is_client(): city.apply(event[1])
		"ships":
			for data: Array in event[1]:
				var id := int(data[0])
				var ship: SpaceShip = ships.get(id)
				if Net.is_client() or ship==null:
					ship = SpaceShip.from_wire(data, ship if Net.is_client() else null)
					ships[id] = ship
				_ensure_interior(ship.slot)
				if not (server_build or Net.is_server()):
					_view_for(ship).push(ship, float(event[2]) if event.size()>2 else -1.0)
					_burn_heart(ship)
		"ship-":
			var id := int(event[1])
			if Net.is_client(): ships.erase(id)
			if ship_views.has(id):
				if event.size()>4 and bool(event[4]): ship_views[id].queue_free()  # gone to the Surface
				else: ship_views[id].explode()
				ship_views.erase(id)
			if str(event[3])!="" and is_instance_valid(local_player) and local_player.spatial_controller is SpaceTraversal:
				(local_player.spatial_controller as SpaceTraversal).notice(str(event[3]))
		"bolt", "bolt_path", "bolt_end", "foes", "foe-", "hit":
			foes.handle_event(event)
		"reach_tutorial":
			if Net.is_client() and is_instance_valid(local_player) and local_player.spatial_controller is SpaceTraversal:
				(local_player.spatial_controller as SpaceTraversal).tutorial_cinematic(str(event[1]), int(event[2]), int(event[3]))
		"launch_shake":
			if is_instance_valid(local_player) and SpaceLayout.pocket_at(local_player.global_position)>=0:
				var aboard := ship_in_slot(SpaceLayout.pocket_at(local_player.global_position))
				if aboard and aboard.id==int(event[1]) and local_player.spatial_controller is SpaceTraversal:
					(local_player.spatial_controller as SpaceTraversal).launch_shake()
		"ship_travel":
			if is_instance_valid(local_player) and local_player.player_id in event[3]:
				var game := game_root()
				game.set_port_arrival(str(event[2]))
				game.travel(str(event[1]))
		"descend":  # [ship id, surface realm, crew]: those aboard go down with her
			if is_instance_valid(local_player) and int(local_player.player_id) in (event[3] as Array) and local_player.spatial_controller is SpaceTraversal:
				(local_player.spatial_controller as SpaceTraversal).descend(int(event[1]), str(event[2]))
		"marks":
			marks[int(event[1])] = event[2]
			if not (server_build or Net.is_server()): _show_marks()
		"say", "moved":
			if is_instance_valid(local_player) and local_player.spatial_controller is SpaceTraversal:
				(local_player.spatial_controller as SpaceTraversal).on_world_message(event)

func state_wire() -> Dictionary:
	return {city = city.wire(), ships = ships.values().map(func(s: SpaceShip) -> Array: return s.wire()), marks = marks.duplicate(true),
		forts = gates.states() if is_instance_valid(gates) else []}

func apply_state(data: Dictionary) -> void:
	if data.has("city"): city.apply(data.city)
	if data.has("ships"): handle_event(["ships", data.ships])
	for party_id in data.get("marks", {}): handle_event(["marks", int(party_id), data.marks[party_id]])
	if is_instance_valid(gates):
		for state: Array in data.get("forts", []): gates.apply_state(state[0], bool(state[1]), bool(state[2]))

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
	var spot: Vector3
	if at.has("city_venue"):
		# Vesperis shops are generated from deterministic CityLayout venue data.
		# Stand on the sidewalk outside the wizard's real shop door.
		if str(at.city_venue)=="wizard": return CityLayout.story_venue_door(CityLayout.story_wizard_venue())
		if str(at.city_venue)=="parts": return CityLayout.story_venue_door(CityLayout.story_parts_venue())
		return Vector3.INF
	if at.has("town"):
		var p: Dictionary = SpaceLayout.planet(str(at.planet))
		if p.is_empty(): return Vector3.INF
		spot = (p.center as Vector3)+SpaceLayout.town_frame(p, str(at.town)).origin
	else:
		spot = spot_position(str(at.planet), str(at.spot))
	if not spot.is_finite(): return spot
	# Beside the spot rather than on it, so its search mark stays clear.
	var frame := surface_frame(spot)
	return frame.origin+frame.basis.x*float(at.get("side", 3.0))

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
		if mark.kind=="foe": holder.set_meta("foe_id", int(mark.foe_id))
		if zone_at(mark.pos)!="void": holder.global_basis = surface_frame(mark.pos).basis
		var badge := QuestMarker.new("main")
		holder.add_child(badge)
		if mark.kind=="target":
			badge._material.disable_fog = true
			badge._material.no_depth_test = true
		_mark_nodes.append(holder)

## Moving quest badges follow the actual replicated enemy ship, not its
## original spawn position or a periodic static location snapshot.
func _follow_foe_marks() -> void:
	if not is_instance_valid(foes): return
	for node: Node in _mark_nodes:
		if not is_instance_valid(node) or not node.has_meta("foe_id"): continue
		var view: Dictionary = foes._views.get(int(node.get_meta("foe_id")), {})
		if not view.is_empty() and is_instance_valid(view.get("node")):
			(node as Node3D).global_position = (view.node as Node3D).global_position

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
	table.position = (station.anchors.get("command_table", Vector3(10, 0, 0)) as Vector3)+Vector3(0, 1.0, 1.7)
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
	# Shopkeepers behind the deck's market stalls, facing the plaza.
	for i in NexusStation.STALL_SHOPS.size():
		var at := station.global_transform*(NexusStation.stall_at(i)+Vector3(0, 0, -1.5))
		var keeper := ShopKeeper.place(self, str(NexusStation.STALL_SHOPS[i]), Transform3D(Basis(Vector3.UP, PI), at))
		keeper.target.reach = 5.0  # over the counter

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
	for spec: Array in [["ladder", anchors.get("ladder", Vector3.ZERO)]]:
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
	if seat.begins_with("chair"): spec.pos += Vector3.DOWN*0.32
	spec.stand = pocket_point(slot, spec.get("stand", seats[seat].pos))
	return spec

func rocket_node() -> SmallRocket:
	return _rocket

func _exit_tree() -> void:
	for key: String in Enemies.pack_overrides.keys():
		if key.begins_with(realm_id+"_"): Enemies.pack_overrides.erase(key)

## Import once per shared flight, preserving the complete hull and crew state.
func accept_transfer(transfer: Dictionary, mode: String) -> SpaceShip:
	var key := str(get_instance_id())
	if transfer.imported.has(key): return ships.get(int(transfer.imported[key]))
	var data: Array = transfer.wire.duplicate(true)
	var used: Array = ships.values().map(func(vessel: SpaceShip) -> int: return vessel.slot)
	var slot := -1
	for candidate in SpaceLayout.POCKET_SLOTS:
		if not candidate in used:
			slot = candidate
			break
	if slot<0: return null
	var ship := SpaceShip.new()
	ship.id = _next_ship
	_next_ship += 1
	ship.slot = slot
	ships[ship.id] = ship
	data[0] = ship.id
	data[1] = ship.slot
	SpaceShip.from_wire(data, ship)
	_ensure_interior(slot)
	Leisure.import_ship_tables(realm_id, ship, transfer.get("cups", {}))
	ship.smoking = transfer.get("smoking", {}).duplicate()
	ship.cooldowns = transfer.get("cooldowns", {}).duplicate()
	ship.set_meta("account", int(transfer.get("account", 0)))
	ship.mode = mode
	ship.input = [0.0, 0.0, 0.0, 0.0, false, false]
	ship.input_age = 0.0
	ship.velocity = Vector3.ZERO
	ship.speed = 0.0
	ship.pulse = false
	ship.planet = "surface" if self is SurfaceShipWorld else ""
	ship.xform = (self as SurfaceShipWorld).pad_pose() if self is SurfaceShipWorld else Transform3D(Basis.IDENTITY, SpaceLayout.ASCENT)
	transfer.imported[key] = ship.id
	if Net.is_server() and ship.fleet_id>0: Net.server.fleet.adopt(self, ship)
	_broadcast_ship(ship)
	return ship

## Instantiate an already claimed account-server ship. Claims and payments
## happen in FleetServer before any hull is made visible on the pad.
func create_fleet_ship(p: Dictionary, deployment: Dictionary, context: Dictionary) -> SpaceShip:
	var used: Array = ships.values().map(func(s: SpaceShip) -> int: return s.slot)
	var slot := -1
	for candidate in SpaceLayout.POCKET_SLOTS:
		if not candidate in used:
			slot = candidate
			break
	if slot<0: return null
	var ship := SpaceShip.new()
	ship.id = _next_ship
	_next_ship += 1
	ship.slot = slot
	ship.fleet_id = int(deployment.id)
	ship.account_id = int(deployment.account_id)
	ship.set_meta("account", ship.account_id)
	ship.owner = int(p.player_id)
	ship.party = _party_id(ship.owner)
	ship.name = "%s #%d" % [str(deployment.name), ship.fleet_id]
	ship.apply_fleet_state(deployment.get("state", {}))
	ship.xform = context.pose
	ship.mode = "berth" if context.has("berth") else "landed"
	ship.berth = int(context.get("berth", 0))
	ship.planet = str(context.planet)
	if ship.planet!="": ship.port = str(context.get("port", ship.planet+":dock"))
	ships[ship.id] = ship
	_ensure_interior(ship.slot)
	return ship

## Boss arenas and fortress airspace are ground-combat areas. Fortress bounds
## extend above the roof so a jetpack cannot bypass gates by dropping inside.
func jetpack_forbidden(at: Vector3) -> bool:
	if is_instance_valid(gates):
		for entry: Dictionary in gates.entries.values():
			var root := entry.root as Node3D
			var local := root.global_transform.affine_inverse()*at
			if absf(local.x)<PlanetStrongholds.WALL_OUT+2.0 and absf(local.z)<PlanetStrongholds.WALL_OUT+2.0 and local.y> -8.0 and local.y<120.0: return true
	for boss: Boss in Boss.all:
		if not is_instance_valid(boss) or not is_ancestor_of(boss): continue
		if boss.state not in [Enemy.State.ACTIVE,Enemy.State.INTRO,Enemy.State.DYING]: continue
		if boss.global_position.distance_to(at)<boss.boss_def.bar_radius: return true
	return false

func jetpack_blocks_segment(from: Vector3, to: Vector3) -> bool:
	if is_instance_valid(gates):
		for entry: Dictionary in gates.entries.values():
			var inverse := (entry.root as Node3D).global_transform.affine_inverse()
			var box := AABB(Vector3(-PlanetStrongholds.WALL_OUT-2.0,-8,-PlanetStrongholds.WALL_OUT-2.0),Vector3((PlanetStrongholds.WALL_OUT+2.0)*2.0,128,(PlanetStrongholds.WALL_OUT+2.0)*2.0))
			if box.intersects_segment(inverse*from,inverse*to): return true
	return jetpack_forbidden(to)
