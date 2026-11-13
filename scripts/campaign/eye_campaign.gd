class_name EyeCampaign
extends RefCounted
## Mission 6 (The Eye Behind the Stars), server side: the clues found at
## planet spots, the Veiled Herald on Shardheart (a quest site that wakes
## when the party comes near, like the Mad Farmer), its story chest with
## the Eye Sigil and the Stormeye Citadel key, and a spare key at the
## citadel so a wiped party is never locked out of the last fight.
var campaigns: CampaignServer

const SIGIL := "story_eye_sigil"
const KEY := "key_stormeye_citadel"

## The Herald's shrine: across Shardheart's top from Lumen Spire, well inside
## the cap where realm combat works.
static func herald_offset() -> Vector2:
	return -(SpaceLayout.TOWNS.shardheart.at as Vector2).normalized()*72.0

static func herald_position() -> Vector3:
	var p := SpaceLayout.planet("shardheart")
	return (p.center as Vector3)+SpaceLayout.place_frame(p, herald_offset()).origin

static func _site(run: Dictionary) -> String:
	return "quest_%s_%s_herald" % [run.id, run.get("attempt", "legacy")]

static func _carried(party: Dictionary, id: String) -> bool:
	for pid: int in party.members:
		var stats := GameServer.character(pid)
		if stats and not stats.find_item(id).is_empty(): return true
	return false

func tick(party: Dictionary, run: Dictionary, step: Dictionary, world: SpaceWorld) -> bool:
	match str(step.kind):
		"reach_herald":
			world.enemy_director.add_quest_site({id = _site(run), pack = "veil_herald",
				pos = herald_position(), seed = absi(_site(run).hash())})
		"reach_relic_chest":
			if _carried(party, SIGIL):
				campaigns._advance(party, {})
				return true
			var record: Dictionary = GameServer.bag(int(run.get("eye_chest", 0)))
			if record.is_empty():
				var at: Vector3 = run.get("herald_fell", herald_position())
				run.eye_chest = GameServer.spawn_bag(world.realm_id, [Items.make(SIGIL), Items.make(KEY)], at, GameServer.PUBLIC, "story")
				campaigns._touch(party.campaign.account)
				campaigns.server.social.broadcast(party)
		"reach_boss":
			if str(step.planet)=="pale_eye": _spare_key(party, run, world)
	return false

## A sealed citadel with no key anywhere in the party: the Sigil remembers
## the way and makes another (checked every few seconds).
func _spare_key(party: Dictionary, run: Dictionary, world: SpaceWorld) -> void:
	var now := Time.get_ticks_msec()
	if now<int(run.get("eye_key_check", 0)): return
	run.eye_key_check = now+4000
	var entry: Dictionary = world.gates.entries.get(PlanetStrongholds.center_of("pale_eye"), {}) if is_instance_valid(world.gates) else {}
	if entry.is_empty() or not bool(entry.get("sealed", true)) or _carried(party, KEY): return
	var record: Dictionary = GameServer.bag(int(run.get("eye_chest", 0)))
	if not record.is_empty() and ReachCampaign._contains_item(record, KEY): return
	for pid: int in party.members:
		var p: Dictionary = campaigns.server.social.record(pid)
		var stats := GameServer.character(pid)
		if stats and str(p.get("realm", ""))==world.realm_id and not p.get("dead", true):
			stats.give([Items.make(KEY)])
			campaigns.server.social.system(pid, "The Eye Sigil grows warm and shapes another [b]Stormeye Citadel key[/b] in your hand.")
			return

## The Herald fell: remember where, so its chest stands there.
func herald_killed(party: Dictionary, run: Dictionary, enemy: Enemy) -> bool:
	if enemy.def.id!="veil_herald" or enemy.pack==null or str(enemy.pack.site.get("id", ""))!=_site(run): return false
	run.herald_fell = enemy.global_position
	for pid: int in party.members:
		campaigns.server.social.system(pid, "The Veiled Herald breaks into light. Something golden is left where it fell.")
	campaigns._advance(party, {})
	return true

func markers(run: Dictionary, step: Dictionary) -> Array:
	match str(step.kind):
		"reach_herald":
			return [{id = "herald", name = "The Veiled Herald's shrine", pos = herald_position(), kind = "target"}]
		"reach_relic_chest":
			var record: Dictionary = GameServer.bag(int(run.get("eye_chest", 0)))
			return [{id = "sigil", name = "The Herald's Story Chest", pos = record.get("pos", herald_position()), kind = "target"}]
	return []
