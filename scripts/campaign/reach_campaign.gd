class_name ReachCampaign
extends RefCounted
## Server-owned campaign extension for the tales told in the Astral Reach
## (definitions with `reach = true`, step kinds listed in Campaigns.LIST).
## Progress comes from the shared SpaceWorld: party ships, landings, cannon
## kills, and searches at planet spots or repairs aboard (published as marks).
var campaigns: CampaignServer
var _hooked_worlds := {}  # realm id -> instance id, so each private Reach is hooked only once

## The old First Light id is retained for progression compatibility. Only
## Space Travels is private; the later Reach tales keep their existing realm.
static func space_realm(party: Dictionary) -> String:
	if party.get("campaign", {}).get("id", "")=="first_light":
		return PortServer.space_for(str(party.campaign.realm))
	return SpaceWorld.REALM

static func tutorial_active(world: SpaceWorld) -> bool:
	if not Net.is_server() or world.realm_id==SpaceWorld.REALM: return false
	for party: Dictionary in Net.server.social.parties.values():
		if space_realm(party)!=world.realm_id: continue
		var run: Dictionary = Net.server.campaigns._run_of(party)
		if str(run.get("id", ""))=="first_light" and run.get("status", "")=="active": return true
	return false

func matches(run: Dictionary) -> bool:
	return bool(Campaigns.get_def(str(run.get("id", ""))).get("reach", false))

func _world(party: Dictionary) -> SpaceWorld:
	var realm: RealmInstance = campaigns.server.realms.get(space_realm(party))
	return realm.world as SpaceWorld if realm and realm.world is SpaceWorld else null

func _ships(party: Dictionary, world: SpaceWorld) -> Array:
	return world.ships.values().filter(func(s: SpaceShip) -> bool:
		return s.party==int(party.id) or int(s.owner) in party.members)

## A step target as a point in space.
static func target_point(target: String) -> Vector3:
	if target.begins_with("planet:"): return SpaceLayout.planet(target.substr(7)).get("center", Vector3.ZERO)
	if target.begins_with("pass:"): return SpaceLayout.passes()[clampi(int(target.substr(5)), 0, 2)]
	return SpaceLayout.NEXUS

func objective(party: Dictionary, _run: Dictionary, _step: Dictionary) -> Dictionary:
	return {world = space_realm(party)}

func tick(party: Dictionary, run: Dictionary) -> void:
	if run.is_empty() or not matches(run) or run.status!="active": return
	var world := _world(party)
	if world==null: return
	if int(_hooked_worlds.get(world.realm_id, -1))!=world.get_instance_id():
		_hooked_worlds[world.realm_id] = world.get_instance_id()
		world.foes.foe_killed.connect(_on_foe_killed.bind(world))
		world.enemy_director.enemy_killed.connect(_on_enemy_killed.bind(world))
	var step := campaigns._step(run)
	var ships := _ships(party, world)
	var fresh := int(run.get("reach_step", -1))!=int(run.step)
	if fresh:
		run.reach_step = int(run.step)
		_begin(party, run, step, world, ships)
	# Before departure, losing the deployed ship returns the tutorial to the
	# command table. Later, players may acquire another at a planet shipwright.
	if run.id=="first_light" and str(step.id) in ["board", "travel", "ambush", "repairs", "port"] and ships.is_empty():
		_reset_to_order(party, run, world)
		return
	match str(step.kind):
		"reach_order":
			if not ships.is_empty():
				run.tutorial_ship = (ships[0] as SpaceShip).id
				campaigns._advance(party, {})
				return
		"reach_tutorial_fly":
			var goal: Vector3 = target_point("planet:"+str(step.planet))
			var total := SpaceLayout.NEXUS.distance_to(goal)
			for ship: SpaceShip in ships:
				if ship.mode=="flying" and ship.xform.origin.distance_to(SpaceLayout.NEXUS)>total*0.42 and ship.xform.origin.distance_to(goal)<total*0.62:
					run.tutorial_ship = ship.id
					campaigns._advance(party, {})
					return
		"reach_tutorial_ambush":
			var ship: SpaceShip = world.ships.get(int(run.get("tutorial_ship", 0)))
			if ship==null:
				_reset_to_order(party, run, world)
				return
			if int(run.get("count", 0))>=1 and ship.hp<=SpaceShip.MAX_HP/2:
				_cripple(party, run, world, ship)
				return
			if not world.foes.foes.has(int(run.get("tutorial_foe", 0))):
				_spawn_pursuer(party, run, world, ship, false)
		"reach_tutorial_repair":
			var ship: SpaceShip = world.ships.get(int(run.get("tutorial_ship", 0)))
			if ship==null:
				_reset_to_order(party, run, world)
				return
			var ready := 0
			for part: String in SpaceShip.PARTS:
				if ship.part(part)>=0.999: ready += 1
			if int(run.count)!=ready:
				run.count = ready
				campaigns.server.social.broadcast(party)
			if ready==SpaceShip.PARTS.size():
				ship.broken = false
				world._broadcast_ship(ship)
				campaigns._advance(party, {})
				return
		"reach_port":
			for ship: SpaceShip in ships:
				if ship.mode=="landed" and ship.planet==str(step.planet) and ship.port==str(step.port):
					campaigns._advance(party, {})
					return
		"reach_party_nexus":
			var ready := 0
			for pid: int in party.members:
				var p := campaigns.server.social.record(pid)
				if not p.is_empty() and p.get("realm", "")==world.realm_id and p.get("joined", false) and not p.get("dead", true) and world.zone_at(p.get("pos", Vector3.INF))=="station": ready += 1
			if ready==party.members.size() and ready>0:
				campaigns._advance(party, {})
				return
		"reach_ship":
			for ship: SpaceShip in ships:
				for pid: int in party.members:
					if SpaceLayout.pocket_at(campaigns.server.social.record(pid).get("pos", Vector3.ZERO))==ship.slot:
						campaigns._advance(party, {})
						return
		"reach_fly":
			var at := target_point(str(step.target))
			var reach := float(step.get("range", 500.0))+(float(SpaceLayout.planet(str(step.target).substr(7)).get("radius", 0.0)) if str(step.target).begins_with("planet:") else 0.0)
			for ship: SpaceShip in ships:
				if ship.xform.origin.distance_to(at)<reach:
					campaigns._advance(party, {})
					return
		"reach_land":
			for ship: SpaceShip in ships:
				if ship.mode=="landed" and ship.planet==str(step.planet):
					campaigns._advance(party, {})
					return
		"reach_dock":
			if run.id=="first_light" and str(step.id)=="return":
				var departed: Array = run.get("return_seen", [])
				for ship: SpaceShip in ships:
					if ship.mode!="berth" and not ship.id in departed: departed.append(ship.id)
				run.return_seen = departed
				# A lost ship need not be replaced and flown out again when
				# the entire crew has already made it safely back to the Nexus.
				var all_home := not party.members.is_empty()
				for pid: int in party.members:
					var member := campaigns.server.social.record(pid)
					if member.is_empty() or member.get("realm", "")!=world.realm_id or not member.get("joined", false) or member.get("dead", true) or world.zone_at(member.get("pos", Vector3.INF))!="station":
						all_home = false
						break
				if all_home:
					campaigns._advance(party, {})
					return
				for ship: SpaceShip in ships:
					if ship.mode=="berth" and ship.id in departed:
						campaigns._advance(party, {})
						return
			else:
				for ship: SpaceShip in ships:
					if ship.mode=="berth":
						campaigns._advance(party, {})
						return
		"reach_repair":
			for ship: SpaceShip in ships:
				if ship.repairs.is_empty() and ship.broken:
					ship.broken = false
			if ships.any(func(s: SpaceShip) -> bool: return s.repairs.is_empty()) and int(run.count)>=step.objects.size():
				campaigns._advance(party, {})
				return
	_publish(party, run, step, world, ships)

## Sets a new step up: ambushes and a crippled ship.
func _begin(party: Dictionary, run: Dictionary, step: Dictionary, world: SpaceWorld, ships: Array) -> void:
	run.count = 0
	match str(step.kind):
		"reach_kill":
			if int(step.get("ambush", 0))>0:
				world.foes.ambushes.append({at = target_point(str(step.get("target", "nexus"))), kind = str(step.get("foe", "brood_skiff")) if step.has("foe") else "brood_skiff", count = int(step.ambush)})
				if not step.has("foe") and int(step.ambush)>=8:
					world.foes.ambushes.append({at = target_point(str(step.target)), kind = "void_eel", count = int(step.ambush)/4})
		"reach_dock":
			if run.id=="first_light" and str(step.id)=="return":
				run.return_seen = ships.filter(func(s: SpaceShip) -> bool: return s.mode!="berth").map(func(s: SpaceShip) -> int: return s.id)
		"reach_tutorial_ambush":
			var ship := world.ships.get(int(run.get("tutorial_ship", 0))) as SpaceShip
			if ship==null: ship = _crewed(party, ships)
			if ship!=null: _spawn_pursuer(party, run, world, ship, true)
		"reach_repair":
			var ship := _crewed(party, ships)
			if ship==null and not ships.is_empty(): ship = ships[0]
			if ship:
				ship.broken = true
				ship.repairs = {}
				for o: Dictionary in step.objects: ship.repairs[o.id] = {name = o.name, seat = o.seat}
				world._broadcast_ship(ship)
				for pid: int in party.members: campaigns.server.social.system(pid, "A crystal shard tears through the hull! The ship is crippled.")

func _crewed(party: Dictionary, ships: Array) -> SpaceShip:
	for ship: SpaceShip in ships:
		for pid: int in party.members:
			if ship.seat_of(pid)!="" or SpaceLayout.pocket_at(campaigns.server.social.record(pid).get("pos", Vector3.ZERO))==ship.slot: return ship
	return null

## Marks this party sees: search spots, repairs aboard and flight targets.
func _publish(party: Dictionary, run: Dictionary, step: Dictionary, world: SpaceWorld, ships: Array) -> void:
	var marks: Array = []
	match str(step.kind):
		"reach_search":
			for o: Dictionary in step.objects:
				if o.id in run.done_objects: continue
				var at := world.spot_position(str(step.planet), str(o.spot))
				if at.is_finite(): marks.append({id = o.id, name = o.name, pos = at, kind = "search"})
		"reach_tutorial_ambush":
			var foe: Dictionary = world.foes.foes.get(int(run.get("tutorial_foe", 0)), {})
			if not foe.is_empty():
				marks.append({id = "pursuer", foe_id = int(foe.id), name = "Pursuing brood skiff", pos = foe.pos, kind = "foe"})
		"reach_tutorial_repair":
			var ship: SpaceShip = world.ships.get(int(run.get("tutorial_ship", 0)))
			if ship!=null:
				for part: String in SpaceShip.PARTS:
					if ship.part(part)>=0.999: continue
					var pos := world.repair_mark(ship, part)
					if pos.is_finite(): marks.append({id = part, name = "Mend "+str(SpaceShip.PARTS[part].name), pos = pos, kind = "target"})
		"reach_order":
			if is_instance_valid(world.station):
				marks.append({id = "table", name = "Bell's shipwright", pos = world.station.anchors.get("command_table", Vector3.ZERO), kind = "target"})
		"reach_port":
			var dest: Dictionary = SpaceLayout.port(str(step.port))
			if not dest.is_empty(): marks.append({id = "port", name = str(step.text), pos = (dest.port.pose as Transform3D).origin, kind = "target"})
		"reach_boss":
			marks.append({id = "fort", name = str(step.text), pos = PlanetStrongholds.floor_center(str(step.planet)), kind = "target"})
		"reach_party_nexus":
			marks.append({id = "station", name = "Return to the Nexus plaza", pos = world.spawn_point, kind = "target"})
		"reach_repair":
			for ship: SpaceShip in ships:
				for id: String in ship.repairs:
					var seat := world.seat_spec(ship.slot, str(ship.repairs[id].seat))
					if not seat.is_empty(): marks.append({id = id, name = ship.repairs[id].name, pos = seat.stand, kind = "repair"})
		"reach_fly", "reach_kill":
			marks.append({id = "target", name = str(step.text), pos = target_point(str(step.get("target", "nexus"))), kind = "target"})
		"reach_tutorial_fly":
			marks.append({id = "target", name = str(step.text), pos = target_point("planet:"+str(step.planet)), kind = "target"})
		"reach_land":
			var p := SpaceLayout.planet(str(step.planet))
			marks.append({id = "target", name = str(step.text), pos = SpaceLayout.pad_frame(p).origin, kind = "target"})
		"reach_dock":
			marks.append({id = "target", name = str(step.text), pos = SpaceLayout.NEXUS, kind = "target"})
		"talk":
			var at := world.npc_position(str(step.get("npc", "")))
			if at.is_finite(): marks.append({id = "npc", name = str(step.text), pos = at, kind = "target"})
	world.set_marks(int(party.id), marks)

## Foe kill signals are scoped to their own instance, never another party's.
func _on_foe_killed(kind: String, ship_id: int, _at: Vector3, world: SpaceWorld) -> void:
	var ship: SpaceShip = world.ships.get(ship_id)
	if ship==null: return
	for party: Dictionary in campaigns.server.social.parties.values():
		if space_realm(party)!=world.realm_id: continue
		var run := campaigns._run_of(party)
		if run.is_empty() or not matches(run) or run.status!="active": continue
		var step := campaigns._step(run)
		if str(step.kind)=="reach_tutorial_ambush":
			if ship.id!=int(run.get("tutorial_ship", 0)) or kind!="brood_skiff": continue
			run.count = int(run.count)+1
			run.tutorial_foe = 0
			# At least one kill is required. After two kills, a scripted glancing
			# strike completes the damage lesson even if the crew dodged every bolt.
			if ship.hp<=SpaceShip.MAX_HP/2 or int(run.count)>=2:
				_cripple(party, run, world, ship)
			else:
				_spawn_pursuer(party, run, world, ship, false)
				campaigns.server.social.broadcast(party)
			continue
		if step.kind!="reach_kill" or not (ship.party==int(party.id) or int(ship.owner) in party.members): continue
		if step.has("foe") and str(step.foe)!=kind: continue
		run.count = int(run.count)+1
		if int(run.count)>=int(step.count): campaigns._advance(party, {})
		else: campaigns.server.social.broadcast(party)

## Only an actual server-side death of this boss in this instance advances.
func _on_enemy_killed(enemy: Enemy, world: SpaceWorld) -> void:
	if not enemy is Boss: return
	for party: Dictionary in campaigns.server.social.parties.values():
		if space_realm(party)!=world.realm_id: continue
		var run := campaigns._run_of(party)
		if run.is_empty() or not matches(run) or run.status!="active": continue
		var step := campaigns._step(run)
		if step.kind=="reach_boss" and enemy.def.id==str(step.boss):
			campaigns._advance(party, {})

func _reset_to_order(party: Dictionary, run: Dictionary, world: SpaceWorld) -> void:
	if world.foes.foes.has(int(run.get("tutorial_foe", 0))):
		world.foes._remove(world.foes.foes[int(run.tutorial_foe)], false, 0)
	run.erase("tutorial_foe")
	run.erase("tutorial_ship")
	run.step = Campaigns.step_index(run.id, "order")
	run.reach_step = -1
	run.count = 0
	campaigns._touch(party.campaign.account)
	campaigns.server.social.broadcast(party)

func _spawn_pursuer(party: Dictionary, run: Dictionary, world: SpaceWorld, ship: SpaceShip, show_intro: bool) -> void:
	if ship.mode!="flying": return
	var at := ship.xform.origin+ship.xform.basis.z*210.0+ship.xform.basis.y*16.0
	var foe: Dictionary = world.foes._spawn("brood_skiff", at, ship.id)
	run.tutorial_ship = ship.id
	run.tutorial_foe = int(foe.id)
	campaigns._touch(party.campaign.account)
	if show_intro:
		world.world_event.emit(["reach_tutorial", "ambush", ship.id, int(foe.id)])
	campaigns.server.social.broadcast(party)

func _cripple(party: Dictionary, run: Dictionary, world: SpaceWorld, ship: SpaceShip) -> void:
	# Protected hull: this lesson never destroys the tutorial ship.
	ship.hp = SpaceShip.MAX_HP/2
	ship.velocity = Vector3.ZERO
	ship.speed = 0.0
	ship.input = [0.0, 0.0, 0.0, 0.0, false, false]
	ship.pulse = false
	for part: String in SpaceShip.PARTS: ship.parts[part] = 0.0
	ship.broken = true
	if world.foes.foes.has(int(run.get("tutorial_foe", 0))):
		world.foes._remove(world.foes.foes[int(run.tutorial_foe)], false, 0)
	run.tutorial_foe = 0
	world._broadcast_ship(ship)
	world.world_event.emit(["reach_tutorial", "repair", ship.id, 0])
	campaigns._advance(party, {})

## A party member talks to a Reach npc or touches a mark. True when handled.
func action(party: Dictionary, run: Dictionary, p: Dictionary, objective: String) -> bool:
	if not matches(run) or str(p.get("realm", ""))!=space_realm(party): return false
	var world := _world(party)
	if world==null: return true
	var step := campaigns._step(run)
	var pos: Vector3 = p.get("pos", Vector3.ZERO)
	if objective.begins_with("npc:") and step.kind=="talk" and objective=="npc:"+str(step.npc):
		var at := world.npc_position(str(step.npc))
		if at.is_finite() and at.distance_to(pos)<6.0:
			if step.has("grant_key"): run.key_receiver = int(p.player_id)
			campaigns._start_scene(party, p, step, at)
		return true
	# The fortress closes again after a defeated party abandons an attempt.
	# Elowen replaces a consumed key so the tutorial can never softlock.
	if step.kind=="reach_boss" and objective=="npc:petalgate_warden":
		var at := world.npc_position("petalgate_warden")
		if not at.is_finite() or at.distance_to(pos)>6.0: return true
		var entry: Dictionary = world.gates.entries.get(PlanetStrongholds.center_of(str(step.planet)), {}) if is_instance_valid(world.gates) else {}
		if not entry.is_empty() and not bool(entry.get("sealed", true)):
			campaigns.server.social.system(int(p.player_id), "The Rose Bastion is open. Defeat Queen Briarrose inside.")
			return true
		var carried := false
		for pid: int in party.members:
			var member := GameServer.character(pid)
			if member and not member.find_item("key_rose_bastion").is_empty(): carried = true
		if carried:
			campaigns.server.social.system(int(p.player_id), "Someone in your party already carries the Rose Bastion key.")
		else:
			var stats := GameServer.character(int(p.player_id))
			if stats:
				stats.give([Items.make("key_rose_bastion")])
				campaigns.server.social.system(int(p.player_id), "Warden Elowen replaces your Rose Bastion key. Use it at the fortress gate.")
		return true
	if not objective.begins_with("obj:"): return false
	var id := objective.substr(4)
	match str(step.kind):
		"reach_search":
			for o: Dictionary in step.objects:
				if o.id!=id or id in run.done_objects: continue
				var at := world.spot_position(str(step.planet), str(o.spot))
				if not at.is_finite() or at.distance_to(pos)>6.0: return true
				run.done_objects.append(id)
				run.count = int(run.count)+1
				for pid: int in party.members: campaigns.server.social.system(pid, str(o.get("found", "Found.")))
				if int(run.count)>=step.objects.size(): campaigns._advance(party, p)
				else: campaigns.server.social.broadcast(party)
				return true
		"reach_repair":
			for ship: SpaceShip in _ships(party, world):
				if not ship.repairs.has(id): continue
				var seat := world.seat_spec(ship.slot, str(ship.repairs[id].seat))
				if seat.is_empty() or (seat.stand as Vector3).distance_to(pos)>5.0: return true
				ship.repairs.erase(id)
				run.count = int(run.count)+1
				for pid: int in party.members: campaigns.server.social.system(pid, "%s mended the %s." % [p.name, str(step.objects.filter(func(o: Dictionary) -> bool: return o.id==id)[0].name).to_lower()])
				world._broadcast_ship(ship)
				campaigns.server.social.broadcast(party)
				return true
	return true

## The step ended: clear what it put in the world.
func step_ended(party: Dictionary) -> void:
	var world := _world(party)
	if world: world.set_marks(int(party.id), [])
