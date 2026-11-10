extends SceneTree
## Contract checks for Astral Frontier mission 4.
## Run with the project's custom voxel-enabled Godot build:
## godot --headless --path . --script res://tools/check_shardfield_parts_campaign.gd

var failures := 0

func check(ok: bool, label: String) -> void:
	print("[starwright] ", "PASS " if ok else "FAIL ", label)
	if not ok: failures += 1

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var def: Dictionary = Campaigns.get_def("shardfield")
	check(not def.is_empty() and def.title=="The Starwright's Missing Parts" and int(def.revision)==2,
		"mission 4 reworked without changing saved id")
	check(def.requires=="lantern_road" and bool(def.reach), "Vesperis unlock and Reach authority preserved")
	check(Campaigns.get_def("hollowmoon").requires=="shardfield", "next mission dependency preserved")
	var steps: Array = def.steps
	var ids: Array = steps.map(func(s: Dictionary) -> String: return str(s.id))
	check(ids==["commission", "buy_core", "amber_key", "aurum", "amber_regulator",
		"fisher", "keeper", "tidal_stabilizer", "return_parts"], "nine-step three-planet arc")
	check(steps[0].get("cutscene", "")=="starwright_three_worlds", "talking to Fen triggers planet tour")
	var script: Dictionary = Campaigns.CUTSCENES.get("starwright_three_worlds", {})
	check(bool(script.get("anywhere", false)) and script.get("shots", []).size()==3,
		"actual three-world space flyover with 3 shots")
	for planet_id: String in ["vesperis", "amberfall", "tidewell"]:
		check(not SpaceLayout.planet(planet_id).is_empty(), "destination exists: "+planet_id)
	var venue: Dictionary = CityLayout.story_parts_venue()
	check(not venue.is_empty() and str(venue.get("district", ""))=="lanternheart" and str(venue.get("kind", "")).begins_with("shop"),
		"navigation core vendor placed at an existing Lanternheart shop")
	check(not venue.is_empty() and CityLayout.story_venue_door(venue).is_finite(), "shop has an actual accessible sidewalk door")
	check(steps[1].kind=="reach_buy_part" and int(steps[1].price)==500 and steps[1].item=="story_nav_core",
		"navigation core costs exactly 500 Dots")
	check(str(steps[1].text).contains("Story Chest"), "Vesperis objective directs players to collect from a Story Chest")
	check(ShardfieldCampaign._chest_spec(ShardfieldCampaign.CORE).get("id", "")=="nav_core",
		"paid navigation core has its own golden Story Chest")
	check(ShardfieldCampaign.new().ensure_chest({members = []}, {}, null, ShardfieldCampaign.CORE).is_empty(),
		"unpaid parties cannot receive a navigation-core Story Chest")
	check(steps[2].grant_key==SpaceLayout.FORTS.amberfall.key and steps[3].boss==SpaceLayout.FORTS.amberfall.boss,
		"the Honeywarden's key fits Aurum's actual existing fortress")
	var b: EnemyDef = Enemies.get_def("amber_colossus")
	check(b is BossDef and b.model=="amber_colossus", "Aurum is a real registered boss")
	check(steps[4].kind=="reach_part_chest" and steps[4].item=="story_amber_regulator",
		"amber regulator comes from boss's Story Chest")
	check(steps[5].npc=="tidewell_fisher" and steps[6].npc=="tidewell_keeper",
		"the two Tidewell NPC conversations happen in sequence")
	check(steps[7].planet=="tidewell" and steps[7].spot=="shell_shrine",
		"third component is found where the keeper says")
	check(SpaceLayout.PLACES.tidewell.has("shell_shrine"), "Shell Shrine is a real authored Tidewell story spot")
	check(steps[8].final and steps[8].return_items==ShardfieldCampaign.PARTS,
		"final dialogue requires all three components")
	for id: String in ShardfieldCampaign.PARTS:
		var item: Item = Items.make(id)
		check(item!=null and item.slot=="story", "real non-sale story item: "+id)
		var spec := ShardfieldCampaign._chest_spec(id)
		check(not spec.is_empty() and str(spec.get("item", ""))==id,
			"actual Story Chest supports all handover items: "+id)
	var party := {campaign = {id = "shardfield", realm = "camp_999_shardfield"}}
	check(ReachCampaign.space_realm(party)==PortServer.space_for("camp_999_shardfield"),
		"mission 4 uses a party-private Reach world")
	check(ReachCampaign.space_realm({campaign = {id = "hollowmoon", realm = "camp_999_hollowmoon"}})==SpaceWorld.REALM,
		"mission 5 still uses existing shared Space behavior")
	print("[starwright] complete, failures=", failures)
	quit(1 if failures>0 else 0)
