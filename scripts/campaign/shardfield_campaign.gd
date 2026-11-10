class_name ShardfieldCampaign
extends RefCounted
## Mission 4: The Starwright's Missing Parts. The server owns purchases,
## authentic inventory checks, story loot and key recovery. The ReachCampaign
## routes the new step types here; the other Reach adventures are untouched.
var campaigns: CampaignServer

const CORE := "story_nav_core"
const REGULATOR := "story_amber_regulator"
const STABILIZER := "story_tidal_stabilizer"
const COST := 500
const PARTS := [CORE, REGULATOR, STABILIZER]

static func has_part(party: Dictionary, id: String) -> bool:
	for pid: int in party.members:
		var stats := GameServer.character(pid)
		if stats and not stats.find_item(id).is_empty(): return true
	return false

static func has_all(party: Dictionary) -> bool:
	for id: String in PARTS:
		if not has_part(party, id): return false
	return true

static func source(world: SpaceWorld, item_id: String) -> Vector3:
	match item_id:
		CORE: return world.npc_position("vesperis_partsmith")
		REGULATOR: return PlanetStrongholds.floor_center("amberfall")
		STABILIZER: return world.spot_position("tidewell", "shell_shrine")
	return Vector3.INF

static func _bag_has(bag: Dictionary, item_id: String) -> bool:
	for item: Variant in bag.get("items", []):
		if item is Item and item.id==item_id: return true
	return false

static func _chest_spec(item_id: String) -> Dictionary:
	match item_id:
		REGULATOR: return {id = "amber_regulator", item = REGULATOR}
		STABILIZER: return {id = "tidal_stabilizer", item = STABILIZER}
	return {}

## A persistent gold Story Chest, unique to the owning party's private Space
## and saved by step id. Never duplicate the item while someone carries it.
func ensure_chest(party: Dictionary, run: Dictionary, world: SpaceWorld, item_id: String) -> Dictionary:
	if has_part(party, item_id): return {}
	var spec := _chest_spec(item_id)
	if spec.is_empty(): return {}
	var keys: Dictionary = run.get("shard_chests", {})
	var record: Dictionary = GameServer.bag(int(keys.get(str(spec.id), 0)))
	if not record.is_empty() and _bag_has(record, item_id): return record
	var at := source(world, item_id)
	if not at.is_finite(): return {}
	var bag_id := GameServer.spawn_bag(world.realm_id, [Items.make(item_id)], at, GameServer.PUBLIC, "story")
	if bag_id<=0: return {}
	keys[str(spec.id)] = bag_id
	run.shard_chests = keys
	campaigns._touch(party.campaign.account)
	for pid: int in party.members:
		campaigns.server.social.system(pid, "A gold Story Chest contains the [b]%s[/b]. Open it and take the part." % str(Items.make(item_id).item_name))
	return GameServer.bag(bag_id)

## Called once per second, after the Reach has opened and connected to the
## correct private instance. True means this step advanced.
func tick(party: Dictionary, run: Dictionary, step: Dictionary, world: SpaceWorld) -> bool:
	match str(step.kind):
		"reach_buy_part":
			if has_part(party, CORE):
				campaigns._advance(party, {})
				return true
		"reach_part_chest":
			if has_part(party, str(step.item)):
				campaigns._advance(party, {})
				return true
			ensure_chest(party, run, world, str(step.item))
		"talk":
			if step.has("return_items"):
				# Parties can retrace their steps if a story item was dropped.
				# The navigation core must be repurchased from its vendor.
				ensure_chest(party, run, world, REGULATOR)
				ensure_chest(party, run, world, STABILIZER)
	return false

## Quest badges include the true shop door, actual story-bag locations,
## and, during final handover, whichever of the parts are still missing.
func markers(party: Dictionary, run: Dictionary, step: Dictionary, world: SpaceWorld) -> Array:
	var marks := []
	match str(step.kind):
		"reach_buy_part":
			var at := source(world, CORE)
			if at.is_finite(): marks.append({id = "core", name = "Buy Navigation Core (500 Dots)", pos = at, kind = "target"})
		"reach_part_chest":
			var item_id := str(step.item)
			var at := source(world, item_id)
			var spec := _chest_spec(item_id)
			var keys: Dictionary = run.get("shard_chests", {})
			var bag: Dictionary = GameServer.bag(int(keys.get(str(spec.get("id", "")), 0)))
			if not bag.is_empty(): at = bag.pos
			if at.is_finite(): marks.append({id = "part", name = str(step.text), pos = at, kind = "target"})
		"talk":
			if step.has("return_items"):
				for id: String in PARTS:
					if has_part(party, id): continue
					var at := source(world, id)
					if at.is_finite(): marks.append({id = id, name = "Missing: "+str(Items.make(id).item_name), pos = at, kind = "target"})
	return marks

## SpaceNPC sends 'npc:<id>' via the existing campaign quest action.
## A merchant is therefore a genuine nearby in-world transaction rather than
## an item silently placed in someone's inventory or fake shop UI.
func action(party: Dictionary, run: Dictionary, p: Dictionary, objective: String, world: SpaceWorld, step: Dictionary) -> bool:
	if run.id!="shardfield" or run.status!="active": return false
	var pos: Vector3 = p.get("pos", Vector3.INF)
	if objective=="npc:vesperis_partsmith" and (step.kind=="reach_buy_part" or step.has("return_items")):
		var at := source(world, CORE)
		if not at.is_finite() or pos.distance_to(at)>6.0: return true
		if has_part(party, CORE):
			campaigns.server.social.system(int(p.player_id), "Scrapper Nix: Your crew already has the Navigation Core.")
			if step.kind=="reach_buy_part": campaigns._advance(party, p)
			return true
		if int(p.get("dots", 0))<COST:
			campaigns.server.social.system(int(p.player_id), "Scrapper Nix: The Navigation Core costs 500 Dots. Come back when you can afford it.")
			return true
		var stats := GameServer.character(int(p.player_id))
		if stats==null or stats.give([Items.make(CORE)])==0:
			campaigns.server.social.system(int(p.player_id), "Scrapper Nix: Make room in your backpack before you buy.")
			return true
		# Only charge once there is room; if the authoritative spend fails,
		# roll the staged story item back immediately.
		if not campaigns.server.economy.spend(p, COST, "campaign_part"):
			var slot: Dictionary = stats.find_item(CORE)
			if not slot.is_empty(): stats.take(slot)
			campaigns.server.social.system(int(p.player_id), "Scrapper Nix: The transaction did not complete.")
			return true
		campaigns.server.social.system(int(p.player_id), "Purchased [b]Salvaged Navigation Core[/b] for 500 Dots.")
		campaigns._touch(party.campaign.account)
		if step.kind=="reach_buy_part": campaigns._advance(party, p)
		else: campaigns.server.social.broadcast(party)
		return true
	# The key is consumed at the fortress gate; if Aurum's arena resets,
	# the warden can issue a replacement so a party never becomes trapped.
	if objective=="npc:amberfall_warden" and step.kind=="reach_boss" and step.get("planet", "")=="amberfall":
		var at := world.npc_position("amberfall_warden")
		if not at.is_finite() or pos.distance_to(at)>6.0: return true
		var gate: Dictionary = world.gates.entries.get(PlanetStrongholds.center_of("amberfall"), {}) if is_instance_valid(world.gates) else {}
		if not gate.is_empty() and not bool(gate.get("sealed", true)):
			campaigns.server.social.system(int(p.player_id), "The Amber Ziggurat is open. Face Aurum within.")
		elif has_part(party, "key_amber_ziggurat"):
			campaigns.server.social.system(int(p.player_id), "Someone in the crew already holds the Amber Ziggurat key.")
		else:
			var stats := GameServer.character(int(p.player_id))
			if stats and stats.give([Items.make("key_amber_ziggurat")])>0:
				campaigns.server.social.system(int(p.player_id), "Warden Saffron replaces the Ziggurat key. Use it at the gate.")
			else:
				campaigns.server.social.system(int(p.player_id), "Make room in your backpack for the Ziggurat key.")
		return true
	if objective=="npc:verdance_starwright" and step.kind=="talk" and step.has("return_items"):
		var at := world.npc_position("verdance_starwright")
		if not at.is_finite() or pos.distance_to(at)>6.0: return true
		if not has_all(party):
			var missing := []
			for id: String in PARTS:
				if not has_part(party, id): missing.append(str(Items.make(id).item_name))
			campaigns.server.social.system(int(p.player_id), "Starwright Fen still needs: "+", ".join(missing)+". Follow the markers to their sources.")
			return true
		campaigns._start_scene(party, p, step, at)
		return true
	return false
