extends Node

var checks := 0
var failures := 0
var banner: QuestBanner
var social: SocialClient


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("QUEST UI FAILED: " + label)


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	social = SocialClient.new()
	social.my_name = "leader"
	var campaign := {
		id = "lily_thief", title = "The Lily Thief", status = "active",
		step = Campaigns.step_index("lily_thief", "gerald"), count = 0,
		side_step = 0, side_done = false, elapsed = 75.0, deaths = 0,
	}
	social.party = {leader = "leader", campaign = campaign}
	add_child(social)
	social.my_name = "leader"
	banner = QuestBanner.new()
	banner.social = social
	banner.place = Campaigns.realm_id(2, "lily_thief")
	banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	banner.offset_left = -240
	banner.offset_right = 240
	add_child(banner)
	await get_tree().process_frame
	await get_tree().process_frame

	check(banner.visible, "Active campaign shows the banner")
	check(banner._side_section.visible and banner._side.text == "Talk to Old Wren in Bramblebrook",
		"Side step zero stays visible from a campaign realm")
	check(banner._main_destination.visible and banner._main_destination.text == "Your party's Tavern",
		"Main objective destination appears on its own line outside the Tavern")
	check(not banner._objective.text.contains("Your party's Tavern"), "Destination is not appended to objective text")
	check(banner._objective.get_theme_font_size("font_size") == 22 and banner._side.get_theme_font_size("font_size") == 22,
		"Both objectives use the larger readable size")
	check(banner._objective.get_theme_color("font_color") == UIStyle.GOLD and banner._side.get_theme_color("font_color") == UIStyle.GOOD,
		"Main and side objectives use gold and green accents")
	check(banner._main_section.get_child_count() == 2 and banner._side_section.get_child_count() == 2,
		"Main and side sections each have one accent rail and one content column")

	campaign.step = Campaigns.step_index("lily_thief", "trail")
	campaign.count = 1
	banner._process(0.0)
	check(banner._objective.text.ends_with("(1/2)"), "Objective progress count updates in place")
	check(banner._side_section.visible, "Side objective remains visible while the main step advances")

	banner.place = "hall"
	banner._process(0.0)
	check(banner._side_destination.visible and banner._side_destination.text == "Campaign realm",
		"Side destination is visible separately from a Tavern")
	check(banner._objective.text == "Follow the stolen lilies through the eastern meadow (1/2)",
		"Main objective text stays free of destination suffixes")

	campaign.side_step = 1
	banner._process(0.0)
	check(banner._side.text == "Find Old Wren's bell", "Side objective updates when its step advances")
	campaign.side_done = true
	banner._process(0.0)
	check(not banner._side_section.visible and not banner._section_divider.visible,
		"Completed side quest section hides cleanly")
	campaign.side_done = false
	campaign.side_step = 0
	banner._process(0.0)
	check(banner._side_section.visible, "An active side quest section returns without duplication")
	check(banner.get_child_count() == 1 and banner._main_section.get_child_count() == 2 and banner._side_section.get_child_count() == 2,
		"Repeated state refreshes do not create duplicate sections")

	banner.boss_visible = true
	banner._process(0.0)
	check(not banner.visible, "Banner hides while the boss bar is visible")
	banner.boss_visible = false
	banner._process(0.0)
	check(banner.visible, "Banner returns after the boss bar hides")
	campaign.status = "done"
	banner._process(0.0)
	check(not banner.visible, "Finished campaign hides the banner")
	campaign.status = "active"
	banner.place = "hall"
	banner._process(0.0)
	check(banner.visible, "Banner returns for an active campaign")

	banner._toggle_details()
	await get_tree().process_frame
	var buttons := banner.find_children("*", "Button", true, false)
	check(banner._details.visible and buttons.any(func(b: Node) -> bool: return b.text == "Pause")
		and buttons.any(func(b: Node) -> bool: return b.text == "Abandon")
		and buttons.any(func(b: Node) -> bool: return b.text == "Close"),
		"Details retain pause, abandon and close controls")
	banner._toggle_details()
	await get_tree().process_frame
	banner._toggle_details()
	await get_tree().process_frame
	check(banner.find_children("*", "Button", true, false).size() == 3,
		"Opening details repeatedly does not duplicate controls")

	print("QUEST UI: %d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures else 0)
