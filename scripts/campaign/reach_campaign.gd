class_name ReachCampaign
extends RefCounted
## Server-owned campaign extension for the tales told in the Astral Reach
## (definitions with `reach = true`, step kinds listed in Campaigns.LIST).
## Progress comes from the shared SpaceWorld: party ships, landings, cannon
## kills, and searches at planet spots or repairs aboard (published as marks).
var campaigns: CampaignServer
var _hooked: SpaceWorld

func matches(run: Dictionary) -> bool:
	return bool(Campaigns.get_def(str(run.get("id", ""))).get("reach", false))

func _world() -> SpaceWorld:
	var realm: RealmInstance = campaigns.server.realms.get(SpaceWorld.REALM)
	return realm.world as SpaceWorld if realm and realm.world is SpaceWorld else null

func _ships(party: Dictionary, world: SpaceWorld) -> Array:
	return world.ships.values().filter(func(s: SpaceShip) -> bool:
		return s.party==int(party.id) or int(s.owner) in party.members)

## A step target as a point in space.
static func target_point(target: String) -> Vector3:
	if target.begins_with("planet:"): return SpaceLayout.planet(target.substr(7)).get("center", Vector3.ZERO)
	if target.begins_with("pass:"): return SpaceLayout.passes()[clampi(int(target.substr(5)), 0, 2)]
	return SpaceLayout.NEXUS

func objective(_party: Dictionary, _run: Dictionary, _step: Dictionary) -> Dictionary:
	return {world = SpaceWorld.REALM}

func tick(party: Dictionary, run: Dictionary) -> void:
	if run.is_empty() or not matches(run) or run.status!="active": return
	var world := _world()
	if world==null: return
	if _hooked!=world:
		_hooked = world
		world.foes.foe_killed.connect(_on_foe_killed)
	var step := campaigns._step(run)
	var ships := _ships(party, world)
	var fresh := int(run.get("reach_step", -1))!=int(run.step)
	if fresh:
		run.reach_step = int(run.step)
		_begin(party, run, step, world, ships)
	match str(step.kind):
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
		"reach_repair":
			for ship: SpaceShip in ships:
				for id: String in ship.repairs:
					var seat := world.seat_spec(ship.slot, str(ship.repairs[id].seat))
					if not seat.is_empty(): marks.append({id = id, name = ship.repairs[id].name, pos = seat.stand, kind = "repair"})
		"reach_fly", "reach_kill":
			marks.append({id = "target", name = str(step.text), pos = target_point(str(step.get("target", "nexus"))), kind = "target"})
		"reach_land":
			var p := SpaceLayout.planet(str(step.planet))
			marks.append({id = "target", name = str(step.text), pos = SpaceLayout.pad_frame(p).origin, kind = "target"})
		"reach_dock":
			marks.append({id = "target", name = str(step.text), pos = SpaceLayout.NEXUS, kind = "target"})
		"talk":
			var at := world.npc_position(str(step.get("npc", "")))
			if at.is_finite(): marks.append({id = "npc", name = str(step.text), pos = at, kind = "target"})
	world.set_marks(int(party.id), marks)

func _on_foe_killed(kind: String, ship_id: int, _at: Vector3) -> void:
	var world := _world()
	if world==null: return
	var ship: SpaceShip = world.ships.get(ship_id)
	if ship==null: return
	for party: Dictionary in campaigns.server.social.parties.values():
		var run := campaigns._run_of(party)
		if run.is_empty() or not matches(run) or run.status!="active": continue
		var step := campaigns._step(run)
		if step.kind!="reach_kill" or not (ship.party==int(party.id) or int(ship.owner) in party.members): continue
		if step.has("foe") and str(step.foe)!=kind: continue
		run.count = int(run.count)+1
		if int(run.count)>=int(step.count): campaigns._advance(party, {})
		else: campaigns.server.social.broadcast(party)

## A party member talks to a Reach npc or touches a mark. True when handled.
func action(party: Dictionary, run: Dictionary, p: Dictionary, objective: String) -> bool:
	if not matches(run) or str(p.get("realm", ""))!=SpaceWorld.REALM: return false
	var world := _world()
	if world==null: return true
	var step := campaigns._step(run)
	var pos: Vector3 = p.get("pos", Vector3.ZERO)
	if objective.begins_with("npc:") and step.kind=="talk" and objective=="npc:"+str(step.npc):
		var at := world.npc_position(str(step.npc))
		if at.is_finite() and at.distance_to(pos)<6.0: campaigns._start_scene(party, p, step, at)
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
	var world := _world()
	if world: world.set_marks(int(party.id), [])
