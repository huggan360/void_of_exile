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
		CORE: return {id = "nav_core", item = CORE}
		REGULATOR: return {id = "amber_regulator", item = REGULATOR}
		STABILIZER: return {id = "tidal_stabilizer", item = STABILIZER}
	return {}

## Nix puts the prepaid navigation core in a proper golden chest beside his
## storefront, with the floor finder placing it on accessible pavement.
static func _chest_origin(world: SpaceWorld, item_id: String) -> Vector3:
	var at := source(world, item_id)
	if item_id==CORE and at.is_finite():
		var shop: Dictionary = CityLayout.story_parts_venue()
		if not shop.is_empty():
			at += (shop.frame as Transform3D).basis.x*3.5
	return at

## A persistent gold Story Chest, unique to the owning party's private Space
## and saved by step id. Never duplicate the item while someone carries it.
func ensure_chest(party: Dictionary, run: Dictionary, world: SpaceWorld, item_id: String) -> Dictionary:
	if has_part(party, item_id): return {}
	# The Vesperis chest cannot be created until the party has really paid.
	# A saved receipt allows a vanished or unloaded chest to be restored
	# without charging another 500 Dots.
	if item_id==CORE and not bool(run.get("shard_nav_paid", false)): return {}
	var spec := _chest_spec(item_id)
	if spec.is_empty(): return {}
	var keys: Dictionary = run.get("shard_chests", {})
	var record: Dictionary = GameServer.bag(int(keys.get(str(spec.id), 0)))
	if not record.is_empty() and _bag_has(record, item_id): return record
	var at := _chest_origin(world, item_id)
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
	# Migration for parties already past the 500-Dot purchase in the original
	# mission-4 implementation: recognise that receipt without a second charge.
	if not run.has("shard_nav_paid") and int(run.step)>Campaigns.step_index("shardfield", "buy_core"):
		run.shard_nav_paid = true
		campaigns._touch(party.campaign.account)
	match str(step.kind):
		"reach_buy_part":
			if has_part(party, CORE):
				campaigns._advance(party, {})
				return true
			ensure_chest(party, run, world, CORE)
		"reach_part_chest":
			if has_part(party, str(step.item)):
				campaigns._advance(party, {})
				return true
			ensure_chest(party, run, world, str(step.item))
		"talk":
			if step.has("return_items"):
				# Once bought, the Navigation Core can be recovered from its
				# prepaid Story Chest, just like the two found components.
				ensure_chest(party, run, world, CORE)
				ensure_chest(party, run, world, REGULATOR)
				ensure_chest(party, run, world, STABILIZER)
	return false

## Recovery remains available after the boss step, including after a reload.
static func _regulator_recovery(party: Dictionary, step: Dictionary) -> bool:
	return (step.get("item", "")==REGULATOR or step.has("return_items")) and not has_part(party, REGULATOR)

static func _needs_recovery_key(party: Dictionary, step: Dictionary, world: SpaceWorld) -> bool:
	if not _regulator_recovery(party, step) or has_part(party, "key_amber_ziggurat"): return false
	if not is_instance_valid(world.gates): return false
	var gate: Dictionary = world.gates.entries.get(PlanetStrongholds.center_of("amberfall"), {})
	return not gate.is_empty() and bool(gate.get("sealed", true))

## Quest badges include the true shop door, actual story-bag locations,
## and, during final handover, whichever of the parts are still missing.
func markers(party: Dictionary, run: Dictionary, step: Dictionary, world: SpaceWorld) -> Array:
	var marks := []
	if _needs_recovery_key(party, step, world):
		var warden: Vector3 = world.npc_position("amberfall_warden")
		if warden.is_finite():
			marks.append({id = "recovery_key", name = "Ask Warden Saffron for a replacement Ziggurat key", pos = warden, kind = "target"})
	match str(step.kind):
		"reach_buy_part":
			var paid := bool(run.get("shard_nav_paid", false))
			var at := source(world, CORE)
			if paid:
				var chest_ids: Dictionary = run.get("shard_chests", {})
				var bag: Dictionary = GameServer.bag(int(chest_ids.get("nav_core", 0)))
				at = bag.pos if not bag.is_empty() else _chest_origin(world, CORE)
			if at.is_finite():
				marks.append({id = "core", name = "Take Navigation Core from the Story Chest" if paid else "Pay Scrapper Nix 500 Dots", pos = at, kind = "target"})
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
					var at := _chest_origin(world, id) if id==CORE and bool(run.get("shard_nav_paid", false)) else source(world, id)
					var chest_spec: Dictionary = _chest_spec(id)
					var chest_ids: Dictionary = run.get("shard_chests", {})
					var bag: Dictionary = GameServer.bag(int(chest_ids.get(str(chest_spec.get("id", "")), 0)))
					if not bag.is_empty(): at = bag.pos
					if at.is_finite(): marks.append({id = id, name = "Missing: "+str(Items.make(id).item_name), pos = at, kind = "target"})
	return marks

## SpaceNPC sends 'npc:<id>' via the existing campaign quest action.
## Buying at this real shop authorises a golden Story Chest. No campaign
## component is injected into inventory by the merchant action.
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
		if bool(run.get("shard_nav_paid", false)):
			var chest: Dictionary = ensure_chest(party, run, world, CORE)
			campaigns.server.social.system(int(p.player_id),
				"Scrapper Nix: Already paid. Your Navigation Core is in the gold Story Chest beside the shop." if not chest.is_empty()
				else "Scrapper Nix: Your purchase is recorded. The Story Chest will be restored.")
			return true
		if int(p.get("dots", 0))<COST:
			campaigns.server.social.system(int(p.player_id), "Scrapper Nix: The Navigation Core costs 500 Dots. Come back when you can afford it.")
			return true
		# Charge the player for the chest, not an item put directly into their
		# backpack. Record the payment before spawning, so any retry/reload
		# can restore the chest without charging the party a second time.
		if not campaigns.server.economy.spend(p, COST, "campaign_part"):
			campaigns.server.social.system(int(p.player_id), "Scrapper Nix: The transaction did not complete.")
			return true
		run.shard_nav_paid = true
		campaigns._touch(party.campaign.account)
		var chest: Dictionary = ensure_chest(party, run, world, CORE)
		# Queue an immediate campaign-book save for the paid receipt and
		# chest ID, instead of waiting for the normal periodic save.
		campaigns.flush()
		campaigns.server.social.system(int(p.player_id),
			"Paid [b]500 Dots[/b]. Open the gold [b]Story Chest[/b] beside the shop to collect the Navigation Core."
			if not chest.is_empty() else "Paid 500 Dots. Your Story Chest will be restored shortly.")
		campaigns.server.social.broadcast(party)
		# The quest advances only after a member actually takes the core out
		# of its Story Chest and into their backpack.
		return true
	# The key is consumed at the fortress gate; if Aurum's arena resets,
	# the warden can issue a replacement so a party never becomes trapped.
	if objective=="npc:amberfall_warden" and ((step.kind=="reach_boss" and step.get("planet", "")=="amberfall") or _regulator_recovery(party, step)):
		var at := world.npc_position("amberfall_warden")
		if not at.is_finite() or pos.distance_to(at)>6.0: return true
		var gate: Dictionary = world.gates.entries.get(PlanetStrongholds.center_of("amberfall"), {}) if is_instance_valid(world.gates) else {}
		if not gate.is_empty() and not bool(gate.get("sealed", true)):
			campaigns.server.social.system(int(p.player_id), "The Amber Ziggurat is open. Recover the regulator from its Story Chest." if _regulator_recovery(party, step) else "The Amber Ziggurat is open. Face Aurum within.")
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
