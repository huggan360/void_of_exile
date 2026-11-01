class_name CampaignServer
extends Node
## Runs campaigns on the dedicated server (Net.server.campaigns). See
## scripts/campaign/README.md for the step kinds.
##
## Each account keeps a book in the account service, so campaigns go on
## anywhere (any server, Singleplayer): {active, runs: {campaign: run},
## worlds: {pack: saved world state}}. A pack's campaigns are all told in one
## private world (realm "camp_<account>_<pack>" and its Tavern "ctav_...")
## belonging to whoever leads; when a campaign ends every member gets the
## completion (unlocking the next) and a copy of that world in their book.
##
## Clients get the campaign in the party state (summary()), plus
## ["camp_intro", script], ["camp_list", runs], ["camp_scene", scene],
## ["camp_scene_page", n], ["camp_scene_end"], ["camp_answer", key, text,
## fled] and ["camp_done", result].

const REACH := 9.0  # meters from an npc or object to use it (server check)
const SAVE_INTERVAL := 20.0
const GATHER_RANGE := 22.0  # the first member this close to a fight pulls the rest in
const VOTE_TIME := 30.0
## Realm record keys that make up a campaign world's saved state.
const WORLD_KEYS := ["destroyed", "cleared_packs", "pack_survivors", "opened_gates", "fog", "forced_open"]
const HELD_BACK := ["goblin", "goblin_master"]  # until The Lily Thief is told

var server: NetServer
var _books := {}  # account id -> book
var _saving := {}  # one in-flight book save per account
var _dirty := {}  # account id -> true
var _save_timer := SAVE_INTERVAL
var _gather_timer := 1.0
var _scenes := {}  # party id -> the shared conversation or vote playing (never saved)


func _ready() -> void:
	GameServer.bag_changed.connect(_on_bag)
	GameServer.bag_removed.connect(_on_bag)


func _process(delta: float) -> void:
	for party: Dictionary in server.social.parties.values():
		var run := _run_of(party)
		if not run.is_empty() and run.status == "active":
			run.elapsed = float(run.elapsed) + delta
			_dirty[party.campaign.account] = true
			var scene: Dictionary = _scenes.get(party.id, {})
			if scene.get("kind", "") == "vote" and Net.now() > float(scene.until):
				_count_votes(party)
	_gather_timer -= delta
	if _gather_timer <= 0.0:
		_gather_timer = 1.0
		for party: Dictionary in server.social.parties.values():
			_gather(party)
	_save_timer -= delta
	if _save_timer <= 0.0:
		_save_timer = SAVE_INTERVAL
		for party: Dictionary in server.social.parties.values():
			_keep_world(party)
		flush()


# --- Books (kept by the account service) --------------------------------------------------

func load_book(account_id: int) -> bool:
	if _books.has(account_id):
		return true
	var r := await server.api.call_api("POST", "/server/campaigns/load", {account_id = account_id})
	if not r.ok:
		return false
	var b: Variant = r.data.get("book", {})
	if not _books.has(account_id):
		_books[account_id] = b if b is Dictionary and b.has("runs") else {active = "", runs = {}}
	return true


func book(account_id: int) -> Dictionary:
	if not _books.has(account_id):
		_books[account_id] = {active = "", runs = {}}
	var b: Dictionary = _books[account_id]
	if not b.has("worlds"):
		b.worlds = {}
	return b


func _touch(account_id: int) -> void:
	_dirty[account_id] = true


func flush() -> void:
	for account_id: int in _dirty.keys():
		if _saving.has(account_id):
			continue
		_dirty.erase(account_id)
		_saving[account_id] = true
		var result := await server.api.call_api("POST", "/server/campaigns/save",
			{account_id = account_id, book = book(account_id).duplicate(true)})
		_saving.erase(account_id)
		if not result.ok:
			_dirty[account_id] = true
			push_warning("Campaign book save failed; will retry: %s" % result.error)


func _run_of(party: Dictionary) -> Dictionary:
	if party.is_empty() or party.campaign.is_empty():
		return {}
	return book(party.campaign.account).runs.get(party.campaign.id, {})


func _step(run: Dictionary) -> Dictionary:
	return Campaigns.step_def(run.id, int(run.step))


## What members see: {} or {id, title, owner, step, count, needed, side_step,
## side_done, done_objects, elapsed, deaths, realm, tavern, status, revealed}.
func summary(party: Dictionary) -> Dictionary:
	var run := _run_of(party)
	if run.is_empty():
		return {}
	return {id = run.id, title = Campaigns.get_def(run.id).title, owner = party.campaign.account,
		step = int(run.step), count = int(run.count), needed = _needed(_step(run)), side_step = int(run.side_step),
		side_done = bool(run.side_done), done_objects = run.done_objects, elapsed = float(run.elapsed),
		deaths = int(run.deaths), realm = party.campaign.realm, tavern = party.campaign.tavern, status = run.status,
		revealed = run.get("revealed", [])}


static func _needed(step: Dictionary) -> int:
	match str(step.get("kind", "")):
		"interact": return step.objects.size()
		"kill": return int(step.count)
	return 1


func _fresh_run(id: String) -> Dictionary:
	return {id = id, attempt = "%d_%d" % [Time.get_unix_time_from_system(), Time.get_ticks_usec()], status = "active", step = 0, count = 0, done_objects = [], side_step = 0, side_done = false,
		elapsed = 0.0, deaths = 0, wipes = 0, stars_best = 0, revealed = []}


# --- What players ask ---------------------------------------------------------------------

func on_action(p: Dictionary, args: Array) -> void:
	var party := server.social.party_for(p.player_id)
	match str(args[0]) if not args.is_empty() else "":
		"list":
			var runs := {}
			var b := book(p.account_id)
			for id: String in b.runs:
				var run: Dictionary = b.runs[id]
				runs[id] = {status = run.status, step = run.step, stars_best = run.get("stars_best", 0), active = b.active == id}
			server.social.send(p.player_id, ["camp_list", runs])
		"start":
			if args.size() > 1: start(p, str(args[1]), args.size() > 2 and bool(args[2]))
		"pause", "abandon":
			if party.is_empty() or party.leader != p.player_id or party.campaign.is_empty():
				server.social.system(p.player_id, "Only the party leader can do that.")
			elif args[0] == "pause":
				_pause(party, "%s paused the campaign. Its progress is saved: resume it at the Chronicler." % p.name)
			else:
				_abandon(party, "%s abandoned the campaign." % p.name)
		"quest":
			if args.size() > 1: quest(p, str(args[1]))
		"scene_next":
			var scene: Dictionary = _scenes.get(party.id, {})
			if scene.get("driver", 0) == p.player_id and scene.kind == "talk":
				scene.page = int(scene.page) + 1
				if scene.page >= scene.pages.size():
					_scene_done(party)
				else:
					_to_party(party, ["camp_scene_page", scene.page])
		"vote":
			var scene: Dictionary = _scenes.get(party.id, {})
			if args.size() > 1 and scene.get("kind", "") == "vote" and str(args[1]) in scene.options:
				scene.votes[p.player_id] = str(args[1])
				if scene.votes.size() >= party.members.size():
					_count_votes(party)


## The leader (or someone alone) starts or resumes a campaign; `restart`
## begins it again from the start. The whole party goes to its Tavern.
func start(p: Dictionary, id: String, restart := false) -> void:
	var def := Campaigns.get_def(id)
	if def.is_empty() or not Campaigns.unlocked(id, book(p.account_id)):
		return
	var party := server.social.party_for(p.player_id)
	if not party.is_empty() and party.leader != p.player_id:
		server.social.system(p.player_id, "Only the party leader can start a campaign.")
		return
	party = server.social.ensure_party(p)
	if not party.campaign.is_empty():
		if party.campaign.id == id and party.campaign.account == p.account_id and not restart and _run_of(party).status == "active":
			server.social.system(p.player_id, "Your party is already playing %s." % def.title)
			return
		_end(party, "")
	var b := book(p.account_id)
	var run: Dictionary = b.runs.get(id, {})
	var fresh: bool = run.is_empty() or restart or run.status in ["done", "abandoned"]
	if fresh:
		var best: int = run.get("stars_best", 0)
		run = _fresh_run(id)
		run.stars_best = best
		b.runs[id] = run
	run.status = "active"
	b.active = id
	party.campaign = {account = p.account_id, id = id, realm = Campaigns.realm_id(p.account_id, id),
		tavern = Campaigns.tavern_id(p.account_id, id), castle = Campaigns.castle_id(p.account_id, id)}
	for pid: int in party.members:
		_restore_items(server.social.record(pid), run)
	_touch(p.account_id)
	flush()
	server.social.broadcast(party)
	var in_tavern: bool = _step(run).get("world", "") == "hall"
	for pid: int in party.members:
		server.social.system(pid, ("%s began [b]%s[/b]." if fresh else "%s resumed [b]%s[/b].") % [p.name, def.title])
		# Only a story that starts in the Tavern brings the party to its private one.
		if in_tavern:
			server.social.send_to(pid, party.campaign.tavern)
			if fresh and def.has("intro"):
				server.social.send(pid, ["camp_intro", def.intro])
		else:
			server.social.system(pid, "The [place]Chronicle Gate[/place] south of the fountain is open to your party.")


func _pause(party: Dictionary, reason: String) -> void:
	var run := _run_of(party)
	if run.is_empty():
		return
	if run.status == "active":
		run.status = "paused"
	_end(party, reason)


## Gives the run up: the next start begins it from scratch (the world stays).
func _abandon(party: Dictionary, reason: String) -> void:
	var run := _run_of(party)
	if run.is_empty():
		return
	book(party.campaign.account).runs[run.id] = {id = run.id, status = "abandoned", step = 0, stars_best = run.get("stars_best", 0)}
	_end(party, reason)


## Leaves the campaign's world: everyone home, the world saved and closed.
func _end(party: Dictionary, reason: String) -> void:
	_keep_world(party)
	var run := _run_of(party)
	var places := [party.campaign.realm, party.campaign.tavern, party.campaign.get("castle", ""), run.get("dungeon", ""), run.get("encore", "")]
	_scenes.erase(party.id)
	_to_party(party, ["camp_scene_end"])
	if book(party.campaign.account).active == party.campaign.id:
		book(party.campaign.account).active = ""
	_touch(party.campaign.account)
	flush()
	party.campaign = {}
	for pid: int in party.members:
		if server.social.record(pid).get("realm", "") in places:
			server.social.send_to(pid, "hall")
		if reason != "":
			server.social.system(pid, reason)
	_close_realm(places[0])
	_close_realm(places[2])
	server.social.broadcast(party)


func pause_owner(account_id: int) -> void:
	for party: Dictionary in server.social.parties.values():
		if not party.campaign.is_empty() and party.campaign.account == account_id:
			_pause(party, "The campaign was paused. Its progress is saved.")


func party_disbanded(party: Dictionary) -> void:
	_pause(party, "")


func left_party(p: Dictionary, party: Dictionary) -> void:
	member_left(party, p.player_id)
	server.social.send(p.player_id, ["camp_scene_end"])
	server.dungeons.grants.erase(p.player_id)
	var run := _run_of(party)
	if not party.campaign.is_empty() and p.realm in [party.campaign.realm, party.campaign.tavern,
			party.campaign.get("castle", ""), run.get("dungeon", ""), run.get("encore", "")]:
		server.social.send_to(p.player_id, "hall")


func joined_party(p: Dictionary, party: Dictionary) -> void:
	_restore_items(p, _run_of(party))
	if home_for(p) != "":
		server.social.send_to(p.player_id, party.campaign.tavern)


# --- The campaign's worlds ------------------------------------------------------------------

## The private Tavern is only home while the story's current step happens in
## the Tavern; otherwise everyone shares the public one.
func home_for(p: Dictionary) -> String:
	var party := server.social.party_for(p.player_id)
	var run := _run_of(party)
	if run.is_empty() or run.status != "active" or _step(run).get("world", "") != "hall":
		return ""
	return str(party.campaign.tavern)


## The Chronicle Gate leads into the party's world only while a campaign is
## being played (a finished one can be played on in, but not entered again).
func realm_for(p: Dictionary) -> Array:
	var party := server.social.party_for(p.player_id)
	var run := _run_of(party)
	if run.is_empty() or run.status != "active":
		return ["", "Your party has no campaign underway. The Chronicler by the Grand Tavern keeps them."]
	return [party.campaign.realm, ""]


func may_enter(p: Dictionary, place: String) -> bool:
	var party := server.social.party_for(p.player_id)
	var run := _run_of(party)
	if Campaigns.is_tavern(place):
		return place == home_for(p) and place != ""
	return not run.is_empty() and run.status == "active" and place in [party.campaign.realm, party.campaign.tavern,
			party.campaign.get("castle", "")]


func tavern_record(p: Dictionary, place: String) -> Dictionary:
	var party := server.social.party_for(p.player_id)
	return {id = place, hall = true, name = "Hearthhaven · %s" % Campaigns.get_def(party.campaign.id).get("title", "")}


## Opens (or finds) a party's campaign world, as it was left.
func open_realm(party: Dictionary) -> RealmInstance:
	var realm_id: String = party.campaign.realm
	var realm: RealmInstance = server.realms.get(realm_id)
	if realm == null:
		WorldServer.reset_realm(realm_id)
		server.social.forget_fog(realm_id)
		var record := WorldServer.get_or_create_realm(realm_id)
		var owner := book(party.campaign.account)
		record.merge(owner.worlds.get(Campaigns.world_key(party.campaign.id), {}).duplicate(true), true)
		record.name = Campaigns.PACKS.get(Campaigns.world_key(party.campaign.id), Campaigns.get_def(party.campaign.id)).title
		realm = server.open_realm_record(realm_id, record)
		# Goblins only come to this world once The Lily Thief is told.
		if str(owner.runs.get("lily_thief", {}).get("status", "")) != "done":
			realm.world.enemy_director.banned = HELD_BACK.duplicate()
	_activate(party)
	return realm


## Opens (or finds) the party's Hollow Castle (CastleWorld, see scenes/castle).
func open_castle(party: Dictionary) -> RealmInstance:
	var castle_id: String = party.campaign.castle
	var realm: RealmInstance = server.realms.get(castle_id)
	if realm == null:
		realm = server.open_realm_record(castle_id, {id = castle_id, castle = true, seed = 0, destroyed = [],
			name = "The Hollow Castle"})
	return realm


func _keep_world(party: Dictionary) -> void:
	if party.is_empty() or party.campaign.is_empty():
		return
	_keep_items(party)
	var realm: RealmInstance = server.realms.get(party.campaign.realm)
	if realm == null:
		return
	server.social.save_fog()
	var world := {}
	for key: String in WORLD_KEYS:
		if realm.record.has(key):
			world[key] = realm.record[key].duplicate(true) if realm.record[key] is Array or realm.record[key] is Dictionary else realm.record[key]
	book(party.campaign.account).worlds[Campaigns.world_key(party.campaign.id)] = world
	_touch(party.campaign.account)


func _close_realm(realm_id: String) -> void:
	server.close_realm(realm_id)
	server.social.forget_fog(realm_id)


## Someone arrived somewhere: an "enter" step may be done, a dungeon
## remembered, the necklace vote begun.
func on_entered(p: Dictionary) -> void:
	var party := server.social.party_for(p.player_id)
	var run := _run_of(party)
	if run.is_empty() or run.status != "active":
		return
	var step := _step(run)
	if step.get("kind", "") == "dungeon" and Dungeons.is_dungeon(p.realm) and server.realms.has(p.realm):
		var origin: Vector3 = server.realms[p.realm].record.get("origin_pos", Vector3.INF)
		if origin != Vector3.INF: run.dungeon_origin = [origin.x, origin.y, origin.z]
		# The first dungeon, or its encore.
		if server.realms[p.realm].record.dungeon == step.get("encore", ""):
			run.encore = p.realm
		else:
			run.dungeon = p.realm
	if step.get("world", "") == "castle" and step.get("kind", "") == "enter" and p.realm == party.campaign.get("castle", ""):
		_advance(party, p)
		return
	if p.realm != party.campaign.realm:
		return
	_activate(party)
	match str(step.get("kind", "")):
		"enter": _advance(party, p)
		"vote":
			if _carries(p, step.item) and not _scenes.has(party.id):
				_start_vote(party, p, step)


## Puts what the current step needs into the world: its enemies, its story
## chest, its portal.
func _activate(party: Dictionary) -> void:
	var run := _run_of(party)
	var realm: RealmInstance = server.realms.get(party.campaign.realm) if not run.is_empty() else null
	if realm == null or run.status != "active":
		return
	var step := _step(run)
	match str(step.get("kind", "")):
		"kill":
			if step.has("pack"):
				var at := Campaigns.resolve(step.at, realm.world)
				if at != Vector3.INF:
					realm.world.enemy_director.add_quest_site({id = "quest_%s_%s_%s" % [run.id, run.get("attempt", "legacy"), step.id], pack = step.pack,
						pos = at, seed = hash(step.id)})
		"chest":
			if int(run.get("chest", 0)) == 0 or GameServer.bag(int(run.chest)).is_empty() and not run.get("chest_taken", false):
				_spawn_chest(party, run, step, realm)
		"dungeon":
			if str(run.get("portal", "")) == "" or not server.dungeons.portals.has(str(run.portal)):
				var death: Dictionary = run.get("last_death", {})
				var pos := _v(death.get("pos", [])) if str(step.get("at", "death")) == "death" and death.has("pos") \
						else Campaigns.resolve(step.get("at", {}), realm.world)
				pos = Campaigns.open_spot(pos, realm.world)
				if pos == Vector3.INF: return
				var portal := server.dungeons.spawn(party.campaign.realm, pos, step.dungeon, false, true)
				run.portal = portal.get("id", "")


func _spawn_chest(party: Dictionary, run: Dictionary, step: Dictionary, realm: RealmInstance) -> void:
	var where: String = party.campaign.realm
	var pos := Vector3.INF
	if step.at is String and step.at == "death":
		var death: Dictionary = run.get("last_death", {})
		where = str(death.get("realm", where))
		pos = _v(death.get("pos", []))
	else:
		pos = Campaigns.resolve(step.at, realm.world)
	if not server.realms.has(where):
		where = party.campaign.realm
		pos = _v(run.get("dungeon_origin", []))
		if pos == Vector3.INF: pos = realm.world.spawn_point
	if pos == Vector3.INF:
		return
	pos = Campaigns.open_spot(pos, server.realms[where].world)
	if pos == Vector3.INF: return
	var items := []
	for id: String in step.items:
		items.append(Items.make(id))
	run.chest = GameServer.spawn_bag(where, items, pos, GameServer.PUBLIC, "story")
	run.chest_taken = false
	if step.has("guards"):
		for k in int(step.guards.count):
			var a := TAU * k / float(step.guards.count)
			var at := pos + Vector3(cos(a), 0, sin(a)) * (12.0 + k * 5.0)
			at = Campaigns.open_spot(at, realm.world)
			if at == Vector3.INF: continue
			realm.world.enemy_director.add_quest_site({id = "quest_%s_%s_%s_%d" % [run.id, run.get("attempt", "legacy"), step.id, k], pack = step.guards.pack,
				pos = at, seed = hash(step.id) + k})


## A story chest changed: its step is done once the item it's for is taken.
func _on_bag(bag_id: int, _items: Variant = null) -> void:
	for party: Dictionary in server.social.parties.values():
		var run := _run_of(party)
		if run.is_empty() or int(run.get("chest", 0)) != bag_id or run.get("chest_taken", false):
			continue
		var step := _step(run)
		var record := GameServer.bag(bag_id)
		var left: bool = not record.is_empty() and record.items.any(func(i: Variant) -> bool: return i != null and i.id == step.get("until", ""))
		if not left:
			run.chest_taken = true
			_advance(party, {})


## Any enemy died somewhere (from GameServer): kills count, deaths are remembered.
func enemy_died(realm_id: String, def: EnemyDef, pos: Vector3) -> void:
	for party: Dictionary in server.social.parties.values():
		var run := _run_of(party)
		if run.is_empty() or run.status != "active" or realm_id not in [party.campaign.realm, run.get("dungeon", ""),
				run.get("encore", ""), party.campaign.get("castle", "")]:
			continue
		var step := _step(run)
		# "any": whatever falls near the step's spot counts (a mixed ambush).
		var near := false
		if step.get("any", false) and realm_id == party.campaign.realm and server.realms.has(realm_id):
			near = _flat(Campaigns.resolve(step.at, server.realms[realm_id].world), pos) < 40.0
		if step.get("kind", "") == "kill" and (def.id in step.enemies or near):
			run.last_death = {realm = realm_id, pos = [pos.x, pos.y, pos.z]}
			run.count = int(run.count) + 1
			_touch(party.campaign.account)
			if run.count >= int(step.count):
				_advance(party, {})
			else:
				server.social.broadcast(party)


## Is this dungeon part of a campaign's chain (its follow-up is the story's)?
func story_dungeon(realm_id: String) -> bool:
	for party: Dictionary in server.social.parties.values():
		var run := _run_of(party)
		if not run.is_empty() and _step(run).has("encore") and run.get("dungeon", "") == realm_id:
			return true
	return false


## A dungeon's boss fell. With an encore, the first one opens the story
## portal onward; the last one finishes the step and closes both portals.
func dungeon_cleared(realm_id: String, pos: Vector3) -> void:
	for party: Dictionary in server.social.parties.values():
		var run := _run_of(party)
		var step := _step(run) if not run.is_empty() else {}
		if step.get("kind", "") != "dungeon":
			continue
		if step.has("encore") and realm_id == run.get("dungeon", "") and str(run.get("encore_portal", "")) == "":
			run.encore_portal = server.dungeons.spawn(realm_id, pos + Vector3(4, 0, 0), step.encore, false, true).get("id", "")
			for pid: int in party.members:
				server.social.system(pid, "The ground splits: a second portal burns open. The [place]%s[/place] awaits." %
						Dungeons.definition(step.encore).name)
			continue
		if realm_id == run.get("encore" if step.has("encore") else "dungeon", ""):
			run.last_death = {realm = realm_id, pos = [pos.x, pos.y, pos.z]}
			for id: String in [str(run.get("portal", "")), str(run.get("encore_portal", ""))]:
				server.dungeons.despawn(id)
			run.erase("portal")
			run.erase("encore_portal")
			_advance(party, {})


## A boss got its full health back (everyone fell or fled): in the
## stronghold step the key waits outside the gate again.
func boss_reset(boss: Boss) -> void:
	var realm_id := Net.realm_of(boss)
	for party: Dictionary in server.social.parties.values():
		var run := _run_of(party)
		var step := _step(run) if not run.is_empty() else {}
		if step.get("kind", "") != "kill" or party.campaign.realm != realm_id or not boss.def.id in step.enemies:
			continue
		run.wipes = int(run.get("wipes", 0)) + 1
		var realm: RealmInstance = server.realms.get(realm_id)
		var center: Vector2i = realm.world.gates.center_for(boss.encounter_center)
		if realm.world.gates.entries.has(center):
			var outside: Vector3 = realm.world.gates.entries[center].root.to_global(Vector3(0.5, 0, -44))
			GameServer.spawn_bag(realm_id, [Items.make(realm.world.gates.key_for(center))], outside, GameServer.PUBLIC, "story")
			for pid: int in party.members:
				server.social.system(pid, "The gates have sealed again. The key waits in a story chest outside.")


func on_death(player_id: int) -> void:
	var party := server.social.party_for(player_id)
	var run := _run_of(party)
	if not run.is_empty() and run.status == "active":
		run.deaths = int(run.deaths) + 1
		_touch(party.campaign.account)
	# What they carried for the story waits for the others in a story chest.
	var p := server.social.record(player_id)
	var stats := GameServer.character(player_id)
	if p.is_empty() or stats == null or p.realm == "":
		return
	var dropped := []
	for i in stats.backpack.size():
		var item: Item = stats.backpack[i]
		if item and (item.is_story() or (item.is_key() and not run.is_empty())):
			dropped.append(stats.take({kind = "pack", key = i}))
	if not dropped.is_empty():
		GameServer.spawn_bag(p.realm, dropped, p.pos, GameServer.PUBLIC, "story")


func on_left(p: Dictionary) -> void:
	for party: Dictionary in server.social.parties.values():
		_keep_world(party)
	if _dirty.has(p.account_id):
		flush()


## A player signed a steward's book (set_home steps).
func home_set(p: Dictionary, village: String) -> void:
	var party := server.social.party_for(p.player_id)
	var run := _run_of(party)
	if not run.is_empty() and run.status == "active" and _step(run).get("kind", "") == "set_home" and _step(run).village == village:
		_advance(party, p)


# --- Quests -------------------------------------------------------------------------------

## A member talked to an npc ("npc:<id>"), used an object ("obj:<id>") or
## asked a villager ("ask:<key>").
func quest(p: Dictionary, objective: String) -> void:
	var party := server.social.party_for(p.player_id)
	var run := _run_of(party)
	if run.is_empty() or run.status != "active" or _scenes.has(party.id):
		return
	if _try(party, run, p, _step(run), objective, false):
		return
	if not run.side_done:
		_try(party, run, p, Campaigns.step_def(run.id, int(run.side_step), true), objective, true)


func _try(party: Dictionary, run: Dictionary, p: Dictionary, step: Dictionary, objective: String, side: bool) -> bool:
	if step.is_empty() or p.realm != (party.campaign.tavern if step.world == "hall" else party.campaign.realm):
		return false
	var world: GameWorld = _world_of(p.realm)
	match str(step.kind):
		"talk", "hand_over":
			if objective != "npc:" + str(step.npc):
				return false
			var at := Campaigns.npc_position(step.npc, p.realm, world)
			if at != Vector3.INF and _flat(at, p.pos) > REACH:
				return false
			if step.kind == "hand_over":
				var place: Dictionary = GameServer.character(p.player_id).find_item(step.item)
				var pending: Dictionary = run.get("pending_talk", {})
				if place.is_empty() and pending.get("step", -1) != run.step:
					return true  # they don't carry it: the npc only sighs (shown on their screen)
				if not place.is_empty():
					GameServer.character(p.player_id).take(place)
				if step.get("shared", false):
					run.pending_talk = {step = run.step}
					_keep_items(party)
			if step.get("shared", false):
				_start_scene(party, p, step, at)
			else:
				_advance(party, p, side)
			return true
		"ask_around":
			if not objective.begins_with("ask:") or objective in run.get("asked", []):
				return false
			if not run.has("asked"):
				run.asked = []
			run.asked.append(objective)
			var knows := randf() < float(step.chance)
			_to_party(party, ["camp_answer", objective.trim_prefix("ask:"), step.yes if knows else step.no,
					not knows and step.get("flee", false)])
			if knows:
				run.revealed = run.get("revealed", []) + [step.reveal]
				_advance(party, p)
			return true
		"interact", "collect":
			for o: Dictionary in step.objects:
				if objective != "obj:" + str(o.id) or o.id in run.done_objects:
					continue
				var at := Campaigns.resolve(o.at, world) if world else Vector3.INF
				if at != Vector3.INF and _flat(at, p.pos) > REACH:
					return false
				run.done_objects.append(o.id)
				_touch(party.campaign.account)
				var found := str(o.get("found", ""))
				if found != "":
					for pid: int in party.members:
						server.social.system(pid, found % p.name if found.contains("%s") else found)
				if side or str(step.kind) == "collect":
					_advance(party, p, side)
				else:
					run.count = int(run.count) + 1
					if run.count >= step.objects.size():
						_advance(party, p)
					else:
						server.social.broadcast(party)
				return true
	return false


## The step is done: rewards, then the next step (or a branch, or the end).
func _advance(party: Dictionary, p: Dictionary, side := false) -> void:
	var run := _run_of(party)
	var def := Campaigns.get_def(run.id)
	var step := Campaigns.step_def(run.id, int(run.side_step if side else run.step), side)
	if step.has("say") and not step.get("shared", false) and not p.is_empty():
		_to_party(party, ["chat", "npc", Campaigns.NPCS.get(step.get("npc", ""), {}).get("name", ""), 0,
				str(step.say).replace("|", " "), ""])
	_reward(party, step)
	if side:
		run.side_step = int(run.side_step) + 1
		if run.side_step >= def.side.size():
			run.side_done = true
			for pid: int in party.members:
				server.social.system(pid, "Side quest complete!")
	else:
		run.count = 0
		run.erase("chest")
		run.step = Campaigns.step_index(run.id, step.next) if step.has("next") else int(run.step) + 1
		if step.has("cutscene"):
			_to_party(party, ["camp_intro", Campaigns.CUTSCENES[step.cutscene]])
		if step.get("final", false) or run.step >= def.steps.size() or run.step < 0:
			_finish(party)
			return
		if _step(run).get("world", "") != "hall":
			for pid: int in party.members:
				if server.social.record(pid).get("realm", "") == party.campaign.tavern:
					server.social.send_to(pid, "hall")
		var next := Campaigns.objective_text(_step(run), 0)
		for pid: int in party.members:
			server.social.system(pid, "Quest updated: %s" % next)
	_keep_items(party)
	_touch(party.campaign.account)
	_activate(party)
	server.social.broadcast(party)


func _reward(party: Dictionary, step: Dictionary) -> void:
	for pid: int in party.members:
		var p := server.social.record(pid)
		var stats := GameServer.character(pid)
		if p.is_empty() or stats == null:
			continue
		if step.has("xp"):
			stats.add_xp(int(step.xp))
		var item: Item = null
		var reward := str(step.get("reward", ""))
		if reward == "dexterity":
			item = Items.stat_elixir("dexterity")
		elif reward.begins_with("t") and reward.substr(1).is_valid_int():  # "t3", "t4": a graded item of that tier
			var rng := RandomNumberGenerator.new()
			rng.randomize()
			item = Items.from_pool({tier = int(reward.substr(1))}, rng)
		if item:
			GameServer.spawn_bag(p.realm, [item], p.pos, pid, item.bag_type())


# --- Shared conversations and the vote ---------------------------------------------------

## Everyone is pulled in and watches the same conversation; only `p` turns the pages.
func _start_scene(party: Dictionary, p: Dictionary, step: Dictionary, at: Vector3) -> void:
	var run := _run_of(party)
	var npc: Dictionary = Campaigns.NPCS.get(step.get("npc", ""), {})
	_scenes[party.id] = {kind = "talk", driver = p.player_id, page = 0, pages = TextMarkup.pages(str(step.get("say", ""))),
		title = npc.get("name", ""), focus = at if at != Vector3.INF else p.pos}
	_pull_party(party, p.realm, p.pos, p.player_id)
	_to_party(party, ["camp_scene", _scenes[party.id]])


func _scene_done(party: Dictionary) -> void:
	_scenes.erase(party.id)
	_run_of(party).erase("pending_talk")
	_to_party(party, ["camp_scene_end"])
	_advance(party, {})


func _start_vote(party: Dictionary, carrier: Dictionary, step: Dictionary) -> void:
	_scenes[party.id] = {kind = "vote", driver = carrier.player_id, title = carrier.name, focus_player = carrier.player_id,
		pages = [str(step.thought)], options = step.options, votes = {}, until = Net.now() + VOTE_TIME}
	_pull_party(party, carrier.realm, carrier.pos, carrier.player_id)
	_to_party(party, ["camp_scene", _scenes[party.id]])


## Most votes win; a tie hands it back.
func _count_votes(party: Dictionary) -> void:
	var run := _run_of(party)
	var step := _step(run)
	var tally := {}
	for choice: String in _scenes[party.id].votes.values():
		tally[choice] = int(tally.get(choice, 0)) + 1
	# Most votes win; a tie goes to the first option.
	var choice: String = step.options.keys()[0]
	for option: String in step.options:
		if int(tally.get(option, 0)) > int(tally.get(choice, 0)):
			choice = option
	_scenes.erase(party.id)
	_to_party(party, ["camp_scene_end"])
	for pid: int in party.members:
		server.social.system(pid, "The party chose: [b]%s[/b]." % step.options[choice])
	run.step = Campaigns.step_index(run.id, step.branches[choice])
	_activate(party)
	server.social.broadcast(party)


## Members not already close come to `pos` (only the portal flash).
func _pull_party(party: Dictionary, realm_id: String, pos: Vector3, except: int) -> void:
	for pid: int in party.members:
		var o := server.social.record(pid)
		if pid == except or o.is_empty() or o.dead:
			continue
		if o.realm != realm_id or _flat(o.pos, pos) > 12.0:
			var a := TAU * pid / 7.0
			server.social.warp(pid, realm_id, pos + Vector3(cos(a), 0, sin(a)) * 2.5)


## Before a fight: once the first member nears it, the rest are brought in.
func _gather(party: Dictionary) -> void:
	var run := _run_of(party)
	var step := _step(run) if not run.is_empty() else {}
	if not step.get("gather", false) or run.get("gathered", "") == step.id or run.status != "active":
		return
	var realm: RealmInstance = server.realms.get(party.campaign.realm)
	if realm == null:
		return
	var at := Campaigns.resolve(step.at if step.has("at") else Campaigns.NPCS[step.npc].at, realm.world)
	for pid: int in party.members:
		var o := server.social.record(pid)
		if not o.is_empty() and o.realm == party.campaign.realm and _flat(o.pos, at) < float(step.get("gather_range", GATHER_RANGE)):
			run.gathered = step.id
			_pull_party(party, o.realm, o.pos, pid)
			return


func _to_party(party: Dictionary, ev: Array) -> void:
	for pid: int in party.members:
		server.social.send(pid, ev)


## A position kept in the book (saved as JSON, so as [x, y, z]).
static func _v(a: Variant) -> Vector3:
	return Vector3(float(a[0]), float(a[1]), float(a[2])) if a is Array and a.size() == 3 else Vector3.INF


static func _carries(p: Dictionary, item_id: String) -> bool:
	var stats := GameServer.character(p.player_id)
	return stats != null and not stats.find_item(item_id).is_empty()


# --- The end ----------------------------------------------------------------------------

## Every member gets the completion and a copy of the world; story items
## (all but the map pieces) are gone; the world stays open for the party.
func _finish(party: Dictionary) -> void:
	var run := _run_of(party)
	var def := Campaigns.get_def(run.id)
	var stars := Campaigns.stars_for(run.id, run)
	var earned := stars.count(true)
	var realm: RealmInstance = server.realms.get(party.campaign.realm)
	if realm and def.get("ice_open", false):
		for fort in realm.world.generator.strongholds:
			if fort.biome_id == Biomes.FOSEN:
				var cell := [fort.center.x, fort.center.y]
				realm.record.forced_open = realm.record.get("forced_open", []) + [cell]
				realm.world.gates.forced_open.append(fort.center)
	if realm and run.id == "lily_thief":
		realm.world.enemy_director.banned = []  # the goblins come back
	run.status = "done"
	run.stars_best = maxi(int(run.get("stars_best", 0)), earned)
	_keep_world(party)
	var world: Dictionary = book(party.campaign.account).worlds.get(Campaigns.world_key(run.id), {})
	for pid: int in party.members:
		var p := server.social.record(pid)
		var stats := GameServer.character(pid)
		if p.is_empty():
			continue
		if int(p.account_id) != int(party.campaign.account):
			var theirs := book(p.account_id)
			var mine: Dictionary = theirs.runs.get(run.id, {})
			theirs.runs[run.id] = {id = run.id, status = "done", step = 0, stars_best = maxi(int(mine.get("stars_best", 0)), earned)}
			theirs.worlds[Campaigns.world_key(run.id)] = world.duplicate(true)
			_touch(p.account_id)
		if stats:
			stats.add_xp(int(def.get("xp", 500)))
			for i in stats.backpack.size():
				var item: Item = stats.backpack[i]
				if item and (item.is_story() and item.id != "story_clue" or item.is_key()):
					stats.take({kind = "pack", key = i})
		var result := {id = run.id, title = def.title, stars = stars, elapsed = run.elapsed, xp = int(def.get("xp", 500))}
		if def.get("pack_end", false):
			_pack_done(pid, p, stats, def, result)
		else:
			server.social.send(pid, ["camp_done", result])
			server.social.system(pid, "[b]%s[/b] complete! %d of 5 stars." % [def.title, earned])
	book(party.campaign.account).active = ""
	_touch(party.campaign.account)
	flush()
	server.social.broadcast(party)
	if def.get("pack_end", false):
		# After the towns cheer, everyone goes home and the pack's worlds leave
		# this server (they live on in every member's book, to replay later).
		var places: Array = [party.campaign.realm, party.campaign.get("castle", "")]
		get_tree().create_timer(30.0).timeout.connect(func() -> void:
			if party.get("campaign", {}).get("id", "") == run.id:
				_end(party, "")
			for place: String in places:
				WorldServer.reset_realm(place))


## The last tale of a pack: its result (and, the first time, the pack's own
## reward card) waits until everyone is back in the Tavern.
func _pack_done(pid: int, p: Dictionary, stats: PlayerStats, def: Dictionary, result: Dictionary) -> void:
	var pack: Dictionary = Campaigns.PACKS.get(def.pack, {})
	var theirs := book(p.account_id)
	var done: Array = theirs.get("packs_done", [])
	var bonus := {}
	if not def.pack in done:
		theirs.packs_done = done + [def.pack]
		_touch(p.account_id)
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		var item := Items.from_pool({tier = 7}, rng)
		if stats:
			stats.add_xp(15000)
			if item: stats.give([item])
		bonus = {title = pack.get("title", ""), xp = 15000, item = item.item_name if item else ""}
	get_tree().create_timer(36.0).timeout.connect(func() -> void:
		server.social.send(pid, ["camp_done", result])
		if not bonus.is_empty():
			server.social.send(pid, ["camp_pack_done", bonus]))


func _world_of(realm_id: String) -> GameWorld:
	var realm: RealmInstance = server.realms.get(realm_id)
	return realm.world if realm else null


static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


## An absent speaker must never strand the remaining party on a shared page.
func member_left(party: Dictionary, player_id: int) -> void:
	var scene: Dictionary = _scenes.get(party.id, {})
	if scene.is_empty():
		return
	if scene.get("driver", 0) == player_id and not party.members.is_empty():
		scene.driver = party.leader
	if scene.kind == "vote":
		scene.votes.erase(player_id)
		if scene.votes.size() >= party.members.size():
			_count_votes(party)
			return
	_to_party(party, ["camp_scene", scene])


## Story inventory belongs to the run too, including in test mode where characters aren't saved.
func _keep_items(party: Dictionary) -> void:
	var run := _run_of(party)
	if run.is_empty() or run.status != "active":
		return
	if not run.has("items"):
		run.items = {}
	for pid: int in party.members:
		var p := server.social.record(pid)
		var stats := GameServer.character(pid)
		if p.is_empty() or stats == null:
			continue
		var items := []
		for item in stats.backpack:
			if item and (item.is_story() or item.is_key()):
				items.append({id = item.id, count = item.count})
		run.items[str(p.account_id)] = items
	_touch(party.campaign.account)


func _restore_items(p: Dictionary, run: Dictionary) -> void:
	if p.is_empty() or run.is_empty() or not run.has("items"):
		return
	var stats := GameServer.character(p.player_id)
	if stats == null or not run.items.has(str(p.account_id)):
		return
	for i in stats.backpack.size():
		var item: Item = stats.backpack[i]
		if item and (item.is_story() or item.is_key()):
			stats.take({kind = "pack", key = i})
	var items := []
	for data: Dictionary in run.items[str(p.account_id)]:
		var item := Items.make(str(data.id))
		item.count = int(data.count)
		items.append(item)
	stats.give(items)
