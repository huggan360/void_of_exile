extends Node
## Account-free regressions for party continuity, private-world access and story inventory.
class CaptureSocial extends SocialServer:
	var events := []
	func send(pid: int, ev: Array) -> void: events.append([pid, ev])

var checks := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: push_error("FAILED: " + label); get_tree().quit(1)
	assert(ok, label)

func _ready() -> void:
	var server := NetServer.new()
	server.config = ServerConfig.new()
	server.social.free()
	var social := CaptureSocial.new()
	server.social = social
	social.server = server
	server.campaigns.server = server
	server.dungeons.server = server
	var campaigns := server.campaigns
	var a := GameServer.add_player(PlayerStats.new())
	var b := GameServer.add_player(PlayerStats.new())
	var p := {player_id = a, account_id = 2, peer_id = 20, name = "p2", realm = "hall", joined = true, dead = false, pos = Vector3.ZERO}
	var q := {player_id = b, account_id = 3, peer_id = 30, name = "p3", realm = "hall", joined = true, dead = false, pos = Vector3.ZERO}
	server.peers = {20: p, 30: q}
	server.by_player = {a: 20, b: 30}
	var party := social.ensure_party(p)
	party.members.append(b)
	social.party_of[b] = party.id
	var run := campaigns._fresh_run("drowned_choir")
	run.step = Campaigns.step_index(run.id, "seal")
	campaigns.book(2).runs[run.id] = run
	party.campaign = {id = run.id, account = 2, realm = "camp_2_hidden_power", tavern = "ctav_2_hidden_power", castle = "cst_2_hidden_power"}
	# Ordinary NPC conversations must reach the party even without a shared
	# cinematic flag, and must not teleport its listeners.
	campaigns._start_scene(party, p, {npc = "gerald", say = "Hello party.|Stay a while."}, Vector3.ZERO)
	for pid: int in [a, b]:
		check(social.events.any(func(ev: Array) -> bool: return ev[0] == pid and ev[1][0] == "camp_scene"), "Ordinary NPC dialogue reaches party member %d" % pid)
	check(not social.events.any(func(ev: Array) -> bool: return ev[1][0] == "goto"), "Listening to ordinary dialogue does not teleport party members")
	social.events.clear()
	campaigns._scene_event(party, ["camp_scene_page", 1])
	check(social.events.size() == 2, "Dialogue page changes reach both listeners")
	campaigns._scenes.clear()
	social.events.clear()
	var original_step := int(run.step)
	check(campaigns._try(party, run, p, {kind = "ask_around", world = "hall", chance = 0.0, yes = "I know.", no = "Ask someone else."},
		"ask:Villager@0,0", false), "Villager answer opens a conversation")
	check(social.events.filter(func(ev: Array) -> bool: return ev[1][0] == "camp_scene").size() == 2,
		"Villager answers appear in both party members' dialogue displays")
	campaigns._scene_done(party)
	check(run.step == original_step, "Closing a villager answer cannot advance the campaign twice")
	campaigns._scenes[party.id] = {kind = "talk", driver = a, pages = ["one", "two"], page = 1, title = "Mirela"}
	social.on_left(p)
	check(party.leader == b and party.members == [b], "Leader disconnect promotes p3 without disbanding")
	check(campaigns._run_of(party) == run and run.status == "active", "Campaign ownership and progress survive")
	check(campaigns._scenes[party.id].driver == b and campaigns._scenes[party.id].page == 1, "Shared conversation transfers driver and retains page")
	check(campaigns.home_for(q) == party.campaign.tavern, "Active realm step keeps the private Tavern as home")
	check(campaigns.may_enter(q, party.campaign.tavern), "Private Tavern stays accessible after a conversation")
	check(campaigns.may_enter(q, party.campaign.realm), "Active member can enter realm")
	for place: String in [party.campaign.realm, party.campaign.tavern, party.campaign.castle, "dng_test", "dng_encore"]:
		run.dungeon = "dng_test"
		run.encore = "dng_encore"
		q.realm = place
		server.dungeons.grants[b] = "dng_test"
		social.events.clear()
		campaigns.left_party(q, party)
		check(social.events.any(func(ev: Array) -> bool: return ev[0] == b and ev[1][0] == "goto" and ev[1][1] == "hall"), "Leave evicts from " + place)
		check(not server.dungeons.grants.has(b), "Leave revokes dungeon grant")
	run.status = "done"
	check(campaigns.realm_for(q)[0] == "" and not campaigns.may_enter(q, party.campaign.realm), "Finished run cannot be reentered")
	check(not campaigns.may_enter(q, party.campaign.castle), "Finished castle cannot be reentered")
	run.status = "active"
	var stats := GameServer.character(b)
	stats.reset()
	var pearl := Items.make("story_tide_pearl")
	stats.give([pearl])
	campaigns._keep_items(party)
	stats.take(stats.find_item(pearl.id))
	campaigns._restore_items(q, run)
	check(not stats.find_item(pearl.id).is_empty(), "Story item restored from run")
	campaigns._restore_items(q, run)
	check(stats.backpack.filter(func(item: Item) -> bool: return item != null and item.id == pearl.id).size() == 1, "Restore does not duplicate story items")
	party.campaign.id = "lily_thief"
	var lily := campaigns._fresh_run("lily_thief")
	campaigns.book(2).runs.lily_thief = lily
	check(campaigns.home_for(q) == party.campaign.tavern, "Gerald step uses private Tavern")
	check(campaigns.may_enter(q, party.campaign.tavern), "Gerald step allows private Tavern")
	q.realm = "hall"
	q.pos = Campaigns.NPCS.gerald.pos
	campaigns._scenes.clear()
	social.events.clear()
	check(campaigns._try(party, lily, q, Campaigns.step_def(lily.id, 0), "npc:gerald", false), "Talk starts Gerald's scene from the public Tavern too")
	check(lily.step == 0 and campaigns._scenes.has(party.id), "Talk keeps the story on Gerald until Exit")
	check(not social.events.any(func(ev: Array) -> bool: return ev[1][0] == "goto"), "Talking to Gerald never ejects the player")
	campaigns._scene_done(party)
	check(lily.step == Campaigns.step_index(lily.id, "gate"), "Exit advances Gerald's scene")
	lily.step = Campaigns.step_index(lily.id, "thief")
	campaigns.enemy_died(party.campaign.realm, Enemies.get_def("goblin"), Vector3.ZERO)
	check(lily.count == 0, "Ambient kills do not replace the marked Goblin Master pack")
	var site := "quest_%s_%s_thief" % [lily.id, lily.attempt]
	for n in 6:
		campaigns.enemy_died(party.campaign.realm, Enemies.get_def("goblin"), Vector3(500, 11, 500), site)
	check(lily.step == Campaigns.step_index(lily.id, "cave"), "Quest pack kills count even when chased away from its marker")
	var dungeon := RealmInstance.new(Dungeons.record("dng_campaign_qa", "goblins_cave", 4217, party.campaign.realm))
	add_child(dungeon)
	server.realms[dungeon.realm_id] = dungeon
	q.realm = dungeon.realm_id
	lily.step = Campaigns.step_index(lily.id, "necklace")
	lily.last_death = {realm = dungeon.realm_id, pos = [dungeon.world.layout.boss.x, 1.0, dungeon.world.layout.boss.z]}
	lily.dungeon = dungeon.realm_id
	campaigns._ensure_chest(party)
	var chest := GameServer.bag(int(lily.get("chest", 0)))
	check(not chest.is_empty() and chest.realm == dungeon.realm_id, "Dungeon chest spawns while campaign realm is unloaded")
	var first_chest := int(chest.id)
	campaigns._ensure_chest(party)
	check(lily.chest == first_chest, "Safety check does not duplicate an existing chest")
	GameServer._remove_bag(first_chest)
	campaigns._on_bag(first_chest)
	check(lily.step == Campaigns.step_index(lily.id, "necklace"), "Missing bag cannot complete the necklace step")
	campaigns._ensure_chest(party)
	chest = GameServer.bag(int(lily.chest))
	check(not chest.is_empty() and int(chest.id) != first_chest, "Safety check respawns the missing chest")
	stats.give([chest.items[0]])
	chest.items[0] = null
	campaigns._on_bag(int(chest.id))
	check(lily.step == Campaigns.step_index(lily.id, "vote"), "Taking the necklace advances the story")
	GameServer._remove_bag(int(chest.id))
	server.realms.clear()
	dungeon.free()
	var legacy := {id = "lily_thief", step = 9, pending_talk = {step = 9}}
	campaigns._migrate_run(legacy)
	check(legacy.step == Campaigns.step_index("lily_thief", "necklace"), "Inserted trail preserves saved necklace progress")
	check(legacy.pending_talk.step == legacy.step, "Pending handover follows migrated step")
	campaigns._migrate_run(legacy)
	check(legacy.step == Campaigns.step_index("lily_thief", "necklace"), "Migration is idempotent")
	GameServer.remove_player(a)
	GameServer.remove_player(b)
	for component in [server.api, server.social, server.dungeons, server.campaigns, server.economy]: component.free()
	server.free()
	print("CAMPAIGN QA: %d checks passed" % checks)
	get_tree().quit()
