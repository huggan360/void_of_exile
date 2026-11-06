extends Node
## Real HUD render: -- --shot=/path.png --rewards=/tmp/rewards.json [--reward-tooltip]

func _ready() -> void:
	var args := {}
	for arg in OS.get_cmdline_user_args():
		var pair := arg.trim_prefix("--").split("=", true, 1)
		args[pair[0]] = pair[1] if pair.size() > 1 else ""
	var total := 0
	for level in range(1, 8):
		total += AccountLevels.xp_to_next(level)
	total += roundi(AccountLevels.xp_to_next(8) * 0.45)
	var rewards: Array = []
	if args.has("rewards"):
		rewards = JSON.parse_string(FileAccess.get_file_as_string(str(args.rewards)))
	Account.data = {progress = AccountLevels.progress(total), rewards = rewards}
	AppSettings.video.show_fps = true
	var game := preload("res://main.tscn").instantiate()
	add_child(game)
	if not args.has("dialogue") and not args.has("quests"):
		game.hud.account_bar.toggle()
	if args.has("quests"):
		game.social.party = {leader = "Preview", campaign = {
			id = "lily_thief", title = "The Lily Thief", owner = 1,
			realm = "camp_preview_hidden_power", tavern = "ctav_preview_hidden_power",
			step = 0 if args.has("trails") else Campaigns.step_index("lily_thief", "thief"), count = 0 if args.has("trails") else 2,
			side_step = 0, side_done = false, done_objects = [], status = "active",
			elapsed = 453, deaths = 0}}
		game.social.party_at = Time.get_ticks_msec() / 1000.0
		if args.has("trails"):
			game.campaign.refresh()
	await get_tree().process_frame
	await get_tree().process_frame
	game.hud.account_bar._center_current()
	if args.has("reward-tooltip"):
		for tile in game.hud.account_bar._tiles:
			if int(tile.reward.level) == 9:
				var tip: Control = tile._make_custom_tooltip(tile.tooltip_text)
				tip.position = Vector2(990, 570)
				game.hud.add_dialog(tip)
				break
