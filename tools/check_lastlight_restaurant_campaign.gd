extends SceneTree
## Mission 5 integration contract: run with the project's voxel Godot build:
## godot --headless --path . --script res://tools/check_lastlight_restaurant_campaign.gd

var errors := 0

func check(ok: bool, label: String) -> void:
	print("[last-light] ", "PASS " if ok else "FAIL ", label)
	if not ok: errors += 1

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var def: Dictionary = Campaigns.get_def("hollowmoon")
	check(int(def.get("revision", 0))==2 and str(def.title)=="The Restaurant at the End of the Universe",
		"mission 5 replaces old story under the existing progression ID")
	check(def.requires=="shardfield" and Campaigns.get_def("pale_eye").requires=="hollowmoon",
		"missions 4 and 6 unlock dependencies remain intact")
	var steps: Array = def.steps
	var ids := steps.map(func(s: Dictionary) -> String: return str(s.id))
	check(ids==["land", "seer", "search", "dock", "beer", "host", "matriarch", "return_dock", "farewell"],
		"nine ordered steps: dark planet, discover diner, beer, boss and return")
	check(steps[0].planet=="hollowmoon" and steps[1].npc=="gloam_seer",
		"Seer Nyx waits on a Gloam planet behind the Shardfield")
	check(steps[1].cutscene=="last_light_reveal" and Campaigns.CUTSCENES.last_light_reveal.shots.size()==3,
		"the seer conversation triggers a three-shot diner flyover")
	check(bool(Campaigns.CUTSCENES.last_light_reveal.anywhere), "diner cinematic works in the private Space world")
	check(Campaigns.NPCS.has("lastlight_host") and bool(Campaigns.NPCS.lastlight_host.at.diner),
		"mission uses the existing permanent Last Light host model")
	check(SpaceLayout.DINER==Vector3(16000, 0, 34500) and SpaceLayout.DINER_RADIUS>30,
		"permanent diner location is unchanged")
	var diner := LastLightDiner.new()
	check(SpaceLayout.BERTHS==6 and diner is LastLightDiner,
		"Last Light uses the two existing extra diner ports, indices 6-7")
	diner.free()
	var quest := RestaurantCampaign.new()
	var marks: Array = quest.markers(steps[2])
	check(marks.size()==1 and marks[0].kind=="zone" and marks[0].radius>=3000,
		"the chart only receives a large yellow search sphere")
	check((marks[0].pos as Vector3).distance_to(SpaceLayout.DINER)>1200,
		"the search sphere centre does not reveal the diner location")
	check((marks[0].pos as Vector3).distance_to(SpaceLayout.DINER)<float(marks[0].radius),
		"the permanent diner is actually inside the search sphere")
	check(steps[3].kind=="reach_diner_dock" and steps[7].kind=="reach_diner_dock",
		"both visits require authentic diner docking")
	check(steps[4].kind=="reach_diner_beers" and RestaurantCampaign.TAP==Vector3(-4, 1.25, -7),
		"each player drinks a real four-sip diner beer from the original counter")
	check(steps[5].grant_key==SpaceLayout.FORTS.mawgrave.key,
		"the host grants the real Rotting Hive fortress key")
	check(steps[6].kind=="reach_boss" and steps[6].boss==SpaceLayout.FORTS.mawgrave.boss,
		"the boss is the existing Brood Matriarch on Mawgrave")
	check(steps[8].npc=="lastlight_host" and bool(steps[8].final),
		"the same diner host completes the mission after the boss")
	var party := {campaign = {id = "hollowmoon", realm = "camp_123_hollowmoon"}}
	check(ReachCampaign.space_realm(party)==PortServer.space_for("camp_123_hollowmoon"),
		"the encounter and loot are isolated in a party-private Space instance")
	check(ReachCampaign.space_realm({campaign = {id = "pale_eye", realm = "camp_123_pale_eye"}})==SpaceWorld.REALM,
		"mission 6's existing shared-space behaviour is unchanged")
	print("[last-light] checks finished: ", errors, " failures")
	quit(1 if errors>0 else 0)
