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
	campaigns._scenes[party.id] = {kind = "talk", driver = a, pages = ["one", "two"], page = 1, title = "Mirela"}
	social.on_left(p)
	check(party.leader == b and party.members == [b], "Leader disconnect promotes p3 without disbanding")
	check(campaigns._run_of(party) == run and run.status == "active", "Campaign ownership and progress survive")
	check(campaigns._scenes[party.id].driver == b and campaigns._scenes[party.id].page == 1, "Shared conversation transfers driver and retains page")
	check(campaigns.home_for(q) == "", "Realm step uses public Tavern")
	check(not campaigns.may_enter(q, party.campaign.tavern), "Private Tavern denied outside Tavern steps")
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
	GameServer.remove_player(a)
	GameServer.remove_player(b)
	server.free()
	print("CAMPAIGN QA: %d checks passed" % checks)
	get_tree().quit()
