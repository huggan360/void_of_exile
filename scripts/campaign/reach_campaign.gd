class_name ReachCampaign
extends RefCounted
## Server-owned campaign extension for the tales told in the Astral Reach
## (definitions with `reach = true`, step kinds listed in Campaigns.LIST).
## Progress comes from the shared SpaceWorld: party ships, landings, cannon
## kills, and searches at planet spots or repairs aboard (published as marks).
var campaigns: CampaignServer
var _hooked_worlds := {}  # realm id -> instance id, so each private Reach is hooked only once

## Missions 2 and 3 use party-owned private Space instances. Later Reach
## adventures continue in the shared world until they are reworked.
static func space_realm(party: Dictionary) -> String:
	if party.get("campaign", {}).get("id", "") in ["first_light", "lantern_road"]:
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

## One existing farmyard in the countryside around Lanternheart; its gravel
## approach is clear of the barn and farmhouse. Boss and story chest share it.
const VESPERIS_FARM := 0
const STARBALL := "story_wizard_starball"
const WAND := "G5_wand"

static func vesperis_farm_position() -> Vector3:
	var frame := CityCountry.farm_frame(VESPERIS_FARM)
	var local := Vector3(0, CityArt.ground(Vector2(0, 17)), 17)
	return (CityLayout.planet().center as Vector3)+frame*local

static func _vesperis_member_key(p: Dictionary) -> String:
	return str(p.get("character_id", p.get("player_id", 0)))

static func _contains_item(bag: Dictionary, id: String) -> bool:
	for item: Variant in bag.get("items", []):
		if item is Item and item.id==id: return true
	return false

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
		"reach_vesperis_port":
			for ship: SpaceShip in ships:
				if ship.mode=="landed" and ship.planet=="vesperis" and ship.port.begins_with("vesperis:lanternheart:"):
					campaigns._advance(party, {})
					return
		"reach_vesperis_beers":
			if _vesperis_check_beers(party, run): return
		"reach_vesperis_boss":
			_vesperis_ensure_farmer(run, world)
		"reach_vesperis_ball":
			if _vesperis_ball_step(party, run, world): return
		"reach_vesperis_wands":
			if _vesperis_wands_step(party, run, world): return
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
				# If the old tutorial ship was lost, the party can still
				# finish once everyone reaches the Nexus safely.
				var all_home: bool = not party.members.is_empty()
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
		"reach_vesperis_boss":
			_vesperis_ensure_farmer(run, world)
		"reach_vesperis_beers":
			if not run.has("vesperis_beers"): run.vesperis_beers = {}
			if not run.has("vesperis_mugs"): run.vesperis_mugs = {}
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
		"reach_vesperis_port":
			for pad: Dictionary in CityLayout.all_pads():
				if str(pad.district)=="lanternheart" and int(pad.index)==0:
					var at: Vector3 = (CityLayout.planet().center as Vector3)+(pad.frame as Transform3D).origin
					marks.append({id = "port", name = "Land at Lanternheart Spaceport", pos = at, kind = "target"})
					break
		"reach_vesperis_beers":
			var pub := CityLayout.story_pub_venue()
			var at := CityLayout.story_pub_tap()
			if at.is_finite():
				marks.append({id = "pub", name = "Order beer at "+str(pub.name), pos = at, kind = "target"})
		"reach_vesperis_boss":
			marks.append({id = "farm", name = "Mad Farmer's farm", pos = vesperis_farm_position(), kind = "target"})
		"reach_vesperis_ball":
			var record: Dictionary = GameServer.bag(int(run.get("vesperis_chest", 0)))
			var at: Vector3 = record.get("pos", vesperis_farm_position())
			marks.append({id = "ball", name = "Stolen starball - Story Chest", pos = at, kind = "target"})
		"reach_vesperis_wands":
			var at := CityLayout.story_venue_door(CityLayout.story_wizard_venue())
			if at.is_finite(): marks.append({id = "reward", name = "Collect your Tier 5 wand - Blue Chest", pos = at, kind = "target"})
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
		elif step.kind=="reach_vesperis_boss" and enemy.def.id=="mad_farmer" and enemy.pack!=null:
			var expected := "quest_%s_%s_farmer" % [run.id, run.get("attempt", "legacy")]
			if str(enemy.pack.site.get("id", ""))!=expected: continue
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
			if step.has("return_item"):
				var carried := false
				for pid: int in party.members:
					var stats := GameServer.character(pid)
					if stats and not stats.find_item(str(step.return_item)).is_empty():
						carried = true
						break
				if not carried:
					campaigns.server.social.system(int(p.player_id), "The wizard needs his stolen starball. Open the Story Chest at the farm.")
					return true
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

## The server validates genuine city pub orders. Each member has to finish
## TWO whole mugs of four sips apiece. A unique order id means discarding a
## half-empty cup or passing someone else's leftovers cannot cheat progress.
func vesperis_sip(p: Dictionary, source: String, mug_id: String, remaining: int) -> void:
	if not Net.is_server() or source=="" or mug_id=="" or not source.begins_with("citytap|"): return
	var venue: Dictionary = CityLayout.venue(source.trim_prefix("citytap|"))
	if venue.is_empty() or str(venue.get("district", ""))!="lanternheart" or not (str(venue.kind) in ["bar", "speakeasy"]): return
	# Beer must also be drunk in the actual pub. Simply carrying a mug
	# onto a battleship is not enough for the sightseeing objective.
	var frame: Transform3D = venue.frame
	var tap: Vector3 = (CityLayout.planet().center as Vector3)+frame*Vector3(-2.5, 1.3, 4.1)
	if (p.get("pos", Vector3.INF) as Vector3).distance_to(tap)>24.0: return
	var party: Dictionary = campaigns.server.social.party_for(int(p.player_id))
	if party.is_empty() or str(p.get("realm", ""))!=space_realm(party): return
	var run: Dictionary = campaigns._run_of(party)
	if run.is_empty() or run.status!="active" or run.id!="lantern_road" or campaigns._step(run).kind!="reach_vesperis_beers": return
	var key := _vesperis_member_key(p)
	var completed: Dictionary = run.get("vesperis_beers", {})
	if int(completed.get(key, 0))>=2: return
	var mugs: Dictionary = run.get("vesperis_mugs", {})
	var entry: Dictionary = mugs.get(key, {})
	if str(entry.get("id", ""))!=mug_id: entry = {id = mug_id, sips = 0}
	entry.sips = int(entry.sips)+1
	if remaining==0:
		if int(entry.sips)==4:
			completed[key] = mini(2, int(completed.get(key, 0))+1)
			run.vesperis_beers = completed
			campaigns.server.social.system(int(p.player_id), "Full mugs enjoyed: %d / 2." % int(completed[key]))
		mugs.erase(key)
	else:
		mugs[key] = entry
	run.vesperis_mugs = mugs
	campaigns._touch(party.campaign.account)
	_vesperis_check_beers(party, run)

func _vesperis_check_beers(party: Dictionary, run: Dictionary) -> bool:
	var completed: Dictionary = run.get("vesperis_beers", {})
	var ready := 0
	for pid: int in party.members:
		var p: Dictionary = campaigns.server.social.record(pid)
		if p.is_empty(): continue
		if int(completed.get(_vesperis_member_key(p), 0))>=2: ready += 1
	if ready!=int(run.get("count", 0)):
		run.count = ready
		campaigns.server.social.broadcast(party)
	if ready==party.members.size() and ready>0:
		for pid: int in party.members:
			campaigns.server.social.system(pid, "Every party member has finished two beers. Follow the country road to the farm.")
		campaigns._advance(party, {})
		return true
	return false

## A finite quest-owned Mad Farmer on the gravel approach to an existing
## red barn in Vesperis's countryside, away from the city core. The site key
## includes the attempt so an earlier party's kill cannot advance this one.
func _vesperis_ensure_farmer(run: Dictionary, world: SpaceWorld) -> void:
	var site := "quest_%s_%s_farmer" % [run.id, run.get("attempt", "legacy")]
	world.enemy_director.add_quest_site({id = site, pack = "mad_farmer",
		pos = vesperis_farm_position(), seed = absi(site.hash())})

## The real story chest is persistent; it appears after the boss actually
## dies, and a lost/expired ball can be recovered on a later visit.
func _vesperis_ball_step(party: Dictionary, run: Dictionary, world: SpaceWorld) -> bool:
	for pid: int in party.members:
		var stats := GameServer.character(pid)
		if stats and not stats.find_item(STARBALL).is_empty():
			campaigns._advance(party, {})
			return true
	var record: Dictionary = GameServer.bag(int(run.get("vesperis_chest", 0)))
	if not record.is_empty() and _contains_item(record, STARBALL): return false
	run.vesperis_chest = GameServer.spawn_bag(world.realm_id,
		[Items.make(STARBALL)], vesperis_farm_position(), GameServer.PUBLIC, "story")
	campaigns._touch(party.campaign.account)
	for pid: int in party.members:
		campaigns.server.social.system(pid, "The Mad Farmer is down! Find the golden Story Chest in his yard and take the stolen starball.")
	return false

## Each member gets exactly one player-owned Blue Chest with a guaranteed
## G5 wand. A depleted chest counts only for its designated recipient; expired
## chests are replenished and already claimed rewards never spawn twice.
func _vesperis_wands_step(party: Dictionary, run: Dictionary, world: SpaceWorld) -> bool:
	var venue := CityLayout.story_wizard_venue()
	if venue.is_empty(): return false
	var frame: Transform3D = venue.frame
	var door := CityLayout.story_venue_door(venue)
	var bags: Dictionary = run.get("vesperis_wand_bags", {})
	var claimed: Dictionary = run.get("vesperis_wand_claimed", {})
	var changed := false
	var ready := 0
	for i in party.members.size():
		var pid := int(party.members[i])
		var p: Dictionary = campaigns.server.social.record(pid)
		if p.is_empty(): continue
		var key := _vesperis_member_key(p)
		if bool(claimed.get(key, false)):
			ready += 1
			continue
		var record: Dictionary = GameServer.bag(int(bags.get(key, 0)))
		if not record.is_empty() and not _contains_item(record, WAND):
			claimed[key] = true
			changed = true
			ready += 1
			campaigns.server.social.system(pid, "You claimed your Tier 5 wand. Wait for the others to collect theirs.")
			continue
		if record.is_empty() and str(p.get("realm", ""))==world.realm_id:
			var offset := frame.basis.x*(float(i)-(float(party.members.size())-1.0)*0.5)*2.8
			var bag_id := GameServer.spawn_bag(world.realm_id, [Items.make(WAND)], door+offset, pid, "blue")
			if bag_id>0:
				bags[key] = bag_id
				changed = true
				campaigns.server.social.system(pid, "A personal Blue Chest with your Tier 5 wand is waiting outside Wizard Aldren's shop.")
	run.vesperis_wand_bags = bags
	run.vesperis_wand_claimed = claimed
	if changed: campaigns._touch(party.campaign.account)
	if ready!=int(run.get("count", 0)):
		run.count = ready
		campaigns.server.social.broadcast(party)
	if ready==party.members.size() and ready>0:
		campaigns._advance(party, {})
		return true
	return false

## The step ended: clear what it put in the world.
func step_ended(party: Dictionary) -> void:
	var world := _world(party)
	if world: world.set_marks(int(party.id), [])
