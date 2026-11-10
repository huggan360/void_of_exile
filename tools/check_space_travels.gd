extends SceneTree
## Contract checks for Space Travels (mission 2). Run with the project's
## voxel-enabled Godot build, after a headless --import:
## godot --headless --path . --script res://tools/check_space_travels.gd

var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, message: String) -> void:
	print("[space-travels] ", "PASS " if ok else "FAIL ", message)
	if not ok: failures += 1

func _run() -> void:
	var def: Dictionary = Campaigns.get_def("first_light")
	check(not def.is_empty(), "tutorial keeps original first_light id for save compatibility")
	check(str(def.get("title", ""))=="Space Travels" and int(def.get("revision", 0))==2,
		"campaign title and revision")
	check(str(def.get("requires", ""))=="theory_of_everything" and bool(def.get("reach", false)),
		"unlocked only after Theory of Everything, using the Reach authority")
	var steps: Array = def.get("steps", [])
	var ids: Array = steps.map(func(step: Dictionary) -> String: return str(step.id))
	check(ids==["order", "board", "travel", "ambush", "repairs", "port", "warden", "boss", "return", "assemble"],
		"ordered ten-step tutorial arc")
	check(Campaigns.step_def("first_light", Campaigns.step_index("first_light", "ambush")).kind=="reach_tutorial_ambush",
		"pursuer uses the tutorial ambush")
	check(Campaigns.step_def("first_light", Campaigns.step_index("first_light", "repairs")).kind=="reach_tutorial_repair",
		"damage stage uses native repairs")
	check(SpaceShip.PARTS.size()==4 and SpaceShip.PARTS.has("sails") and SpaceShip.PARTS.has("engines") 		and SpaceShip.PARTS.has("turret") and SpaceShip.PARTS.has("heart"), "all four repairable parts exist")
	check(not SpaceLayout.port("rosamund:dock").is_empty(), "Petalgate shipyard is a genuine landing port")
	check(str(SpaceLayout.FORTS.rosamund.boss)=="queen_briarrose" 		and str(SpaceLayout.FORTS.rosamund.key)=="key_rose_bastion", "first stronghold has the easiest planetary boss and matching key")
	check(str(Campaigns.NPCS.petalgate_warden.at.planet)=="rosamund" 		and str(Campaigns.NPCS.petalgate_warden.at.town)=="center", "warden placed in the town")
	check(str(steps[6].get("grant_key", ""))==str(SpaceLayout.FORTS.rosamund.key), "warden grants correct fortress key")
	check(str(steps[7].get("boss", ""))==str(SpaceLayout.FORTS.rosamund.boss), "boss objective checks correct kill")
	check(str(steps[-1].get("kind", ""))=="reach_party_nexus" and bool(steps[-1].get("final", false)),
		"campaign ends only after whole party returns")
	var private_party := {campaign = {id = "first_light", realm = "camp_22_astral_frontier"}}
	check(ReachCampaign.space_realm(private_party)=="astral_camp_22_astral_frontier", "private Space is derived from party realm")
	check(ReachCampaign.space_realm({campaign = {id = "lantern_road", realm = "camp_22_astral_frontier"}}) 		==SpaceWorld.REALM, "later missions still use existing shared space")
	check(str(Campaigns.get_def("lantern_road").requires)=="first_light", "next campaign's prerequisite is preserved")
	print("[space-travels] completed; failures=", failures)
	quit(1 if failures>0 else 0)
