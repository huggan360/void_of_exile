class_name EyeCampaign
extends RefCounted
## Mission 6 (The Eye Behind the Stars), server side: the clues found at
## planet spots, the Veiled Herald in the Veiled Shrine on Shardheart (a
## stronghold; its key is found at the heart shrine), her story chest with
## the Eye Sigil and the Stormeye Citadel key, and spare keys at both
## strongholds so a wiped party is never locked out of a fight.
var campaigns: CampaignServer

const SIGIL := "story_eye_sigil"
const KEY := "key_stormeye_citadel"
const SHRINE_KEY := "key_veiled_shrine"

## The middle of the Veiled Shrine's arena (SpaceLayout.FORTS.shardheart).
static func herald_position() -> Vector3:
	return PlanetStrongholds.floor_center("shardheart")

static func _carried(party: Dictionary, id: String) -> bool:
	for pid: int in party.members:
		var stats := GameServer.character(pid)
		if stats and not stats.find_item(id).is_empty(): return true
	return false

func tick(party: Dictionary, run: Dictionary, step: Dictionary, world: SpaceWorld) -> bool:
	match str(step.kind):
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
			if str(step.planet)=="pale_eye": _spare_key(party, run, world, "pale_eye", KEY,
				"The Eye Sigil grows warm and shapes another [b]Stormeye Citadel key[/b] in your hand.")
			elif str(step.planet)=="shardheart": _spare_key(party, run, world, "shardheart", SHRINE_KEY,
				"Shardheart hums its low note again, and another [b]Veiled Shrine Key[/b] forms in your hand.")
	return false

## A sealed stronghold with no key anywhere in the party: another is made
## (checked every few seconds).
func _spare_key(party: Dictionary, run: Dictionary, world: SpaceWorld, planet: String, key: String, text: String) -> void:
	var now := Time.get_ticks_msec()
	if now<int(run.get("eye_key_check", 0)): return
	run.eye_key_check = now+4000
	var entry: Dictionary = world.gates.entries.get(PlanetStrongholds.center_of(planet), {}) if is_instance_valid(world.gates) else {}
	if entry.is_empty() or not bool(entry.get("sealed", true)) or _carried(party, key): return
	var record: Dictionary = GameServer.bag(int(run.get("eye_chest", 0)))
	if not record.is_empty() and ReachCampaign._contains_item(record, key): return
	for pid: int in party.members:
		var p: Dictionary = campaigns.server.social.record(pid)
		var stats := GameServer.character(pid)
		if stats and str(p.get("realm", ""))==world.realm_id and not p.get("dead", true):
			stats.give([Items.make(key)])
			campaigns.server.social.system(pid, text)
			return

## The Herald fell (ReachCampaign advances): remember where, so its chest stands there.
func herald_killed(party: Dictionary, run: Dictionary, enemy: Enemy) -> void:
	run.herald_fell = enemy.global_position
	for pid: int in party.members:
		campaigns.server.social.system(pid, "The Veiled Herald breaks into light. Something golden is left where it fell.")

func markers(run: Dictionary, step: Dictionary) -> Array:
	match str(step.kind):
		"reach_relic_chest":
			var record: Dictionary = GameServer.bag(int(run.get("eye_chest", 0)))
			return [{id = "sigil", name = "The Herald's Story Chest", pos = record.get("pos", herald_position()), kind = "target"}]
	return []
