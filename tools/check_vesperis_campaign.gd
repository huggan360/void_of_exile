extends SceneTree
## Mission 3 contract checks. Run with the project's voxel-enabled Godot:
## /home/hugo/godot/engine/godot_voxel_editor --headless --path . --script res://tools/check_vesperis_campaign.gd

var failed := 0

func check(ok: bool, message: String) -> void:
	print("[vesperis-quest] ", "PASS " if ok else "FAIL ", message)
	if not ok: failed += 1

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var def := Campaigns.get_def("lantern_road")
	check(not def.is_empty() and def.title=="Vesperis" and int(def.revision)==2, "third mission is Vesperis revision 2")
	check(def.requires=="first_light" and def.reach, "previous tutorial unlock still works")
	var ids: Array = def.steps.map(func(s: Dictionary) -> String: return str(s.id))
	check(ids==["arrival", "wizard", "beers", "farmer", "starball", "return", "wands"],
		"arrival, wizard, pub, farm, starball, return, blue chests")
	check(Campaigns.get_def("shardfield").requires=="lantern_road", "next campaign unlock remains intact")
	check(Campaigns.NPCS.has("vesperis_wizard"), "Wizard Aldren NPC is registered")
	var wizard: Dictionary = CityLayout.story_wizard_venue()
	check(not wizard.is_empty(), "a real wizard shop exists in Lanternheart")
	if not wizard.is_empty():
		check(wizard.get("shop", "")=="wizard" and wizard.get("district", "")=="lanternheart",
			"wizard is at the actual shop, not a stand-in marker")
		check(CityLayout.story_venue_door(wizard).is_finite(), "wizard stands outside the shop entrance")
	var pub: Dictionary = CityLayout.story_pub_venue()
	check(not pub.is_empty(), "a real Lanternheart pub exists")
	if not pub.is_empty():
		check(pub.kind=="bar" and pub.district=="lanternheart", "pub is a beer-serving city bar")
		check(CityLayout.story_pub_tap().is_finite() and CityLayout.venue(str(pub.key))==pub,
			"pub quest marker points at its real beer tap")
	var farm := ReachCampaign.vesperis_farm_position()
	check(farm.is_finite() and CityCountry.FARMS.size()>ReachCampaign.VESPERIS_FARM,
		"encounter uses an existing country farmstead")
	if not wizard.is_empty():
		var distance := farm.distance_to(CityLayout.story_venue_door(wizard))
		check(distance>140.0 and distance<1100.0,
			"farm is away from the wizard shop but reachable on the planet (%.0f metres)" % distance)
	var boss := Enemies.get_def("mad_farmer")
	check(boss is BossDef and boss.model=="mad_farmer" and boss.actor_script.ends_with("mad_farmer.gd"),
		"registered Mad Farmer boss uses the authored shotgun script")
	var starball := Items.make("story_wizard_starball")
	check(starball!=null and starball.slot=="story", "stolen magical ball exists as a story item")
	var wand := Items.make("G5_wand")
	check(wand!=null and wand.tier==5 and wand.kind=="Wand", "reward is exactly a Tier 5 wand")
	check(def.steps[4].kind=="reach_vesperis_ball" and def.steps[5].return_item=="story_wizard_starball",
		"starball must be retrieved and returned")
	check(def.steps[-1].kind=="reach_vesperis_wands" and def.steps[-1].final,
		"campaign ends only after the personal blue-chest rewards are claimed")
	var party := {campaign = {id = "lantern_road", realm = "camp_999_lantern_road"}}
	check(ReachCampaign.space_realm(party)=="astral_camp_999_lantern_road",
		"Vesperis uses a private party Space world")
	print("[vesperis-quest] completed, failures=", failed)
	quit(1 if failed>0 else 0)
