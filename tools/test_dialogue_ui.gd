extends Node3D

class CaptureSocial extends SocialClient:
	var actions: Array = []
	func campaign(args: Array) -> void:
		actions.append(args)

var checks := 0
var failures := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	get_window().size = Vector2i(1600, 900)
	GameServer.set_physics_process(false)
	var stats := PlayerStats.new()
	var player := Player.new()
	player.player_id = GameServer.add_player(stats)
	player.stats = stats
	add_child(player)
	add_child(player.aim_marker)
	player.set_physics_process(false)
	player.set_process(false)
	var social := CaptureSocial.new()
	add_child(social)
	var hud := Hud.new(stats, player)
	add_child(hud)
	hud.add_social(social, Callable())
	hud.set_process(false)
	check(hud._fps_readout.anchor_top == 0 and hud._fps_readout.position.y == 4,
		"FPS sits in the upper-left overlay")
	check(hud.chat.offset_bottom == -Hud.MARGIN, "Friends and Party use the bottom screen margin")
	var world := GameWorld.new()
	world.realm_id = "realm_test"
	add_child(world)
	hud._world = world
	# Keep the synthetic mouse far away from the controls in the headless run.
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(-500, -500)
	get_viewport().push_input(motion)
	await get_tree().process_frame
	hud._update_world_ui_fade(1.0, Vector2(-500, -500))
	# Fade approaches its target exponentially; one second leaves a small remainder.
	check(absf(hud.account_bar.modulate.a - Hud.WORLD_UI_ALPHA) < .02, "Account XP fades outside the Tavern")
	check(absf(hud._equipment_column.modulate.a - Hud.WORLD_UI_ALPHA) < .02, "Stats button inherits the equipment column fade")
	check(absf(hud.chat.modulate.a - Hud.WORLD_UI_ALPHA) < .02, "Friends and Party buttons inherit the chat fade")
	check(hud._hp_bar.modulate.a == 1 and hud._mp_bar.modulate.a == 1 and hud.minimap.modulate.a == 1,
		"Health, magic and minimap remain opaque")
	motion = InputEventMouseMotion.new()
	hud._update_world_ui_fade(1.0, hud._stats_button.get_global_rect().get_center())
	check(is_equal_approx(hud._equipment_column.modulate.a, 1), "Hovered Stats button becomes fully opaque")
	motion = InputEventMouseMotion.new()
	motion.position = Vector2(-500, -500)
	get_viewport().push_input(motion)
	hud._update_world_ui_fade(1.0, Vector2(-500, -500))
	check(absf(hud._equipment_column.modulate.a - Hud.WORLD_UI_ALPHA) < .02, "Stats fades again after the pointer leaves")
	world.realm_id = "ctav_2_test"
	hud._update_world_ui_fade(1.0, Vector2(-500, -500))
	check(is_equal_approx(hud.account_bar.modulate.a, 1) and is_equal_approx(hud._equipment_column.modulate.a, 1),
		"Private Tavern restores full HUD opacity")
	social.party = {leader = "", campaign = {id = "lily_thief", title = "The Lily Thief", status = "active",
		step = Campaigns.step_index("lily_thief", "trail"), count = 1, side_step = 0, side_done = false, elapsed = 0.0}}
	hud.quest_banner.place = "hall"
	for gui_scale in ["small", "medium", "large"]:
		AppSettings.video.gui_scale = gui_scale
		AppSettings.gui_changed.emit()
		await get_tree().process_frame
		await get_tree().process_frame
		hud._profile_process(0.0)
		var bounds := hud.quest_banner.get_rect()
		print("QUEST BOUNDS ", gui_scale, ": ", bounds, " root=", hud._ui_root.size)
		check(bounds.position.x == Hud.MARGIN and bounds.end.x < hud._ui_root.size.x * .35,
			"Quest tracker stays at the left edge with " + gui_scale + " UI")
		check(bounds.position.y >= hud.picker.position.y + hud.picker._button.size.y,
			"Quest tracker clears the character controls with " + gui_scale + " UI")
		check(hud.toasts.position.y >= bounds.end.y, "Notices clear the quest tracker")
		if "--preview" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("/tmp/void_exile_quest_hud_" + gui_scale + ".png")
	var target := InteractionTarget.new()
	target.title = "Gerald"
	target.response = "Hello [npc]traveler[/npc]. Welcome home."
	world.add_child(target)
	hud.interaction.world = world
	player.frozen = false
	hud.interaction.update_prompt(player, false)
	check(hud.interaction.visible, "Nearby target offers an interaction prompt")
	hud.interaction.accept()
	check(stats.buffs.has_effect("invincible") and stats.buffs.has_effect("immune"), "Accepted interaction grants visible protection buffs")
	var protected_hp := stats.hp
	player.take_damage(5000, true)
	check(stats.hp == protected_hp, "Interaction protection blocks otherwise lethal damage")
	await get_tree().create_timer(.25).timeout
	var local_voice := hud.interaction._voice._handle
	check(not local_voice.is_empty() and local_voice.event.begins_with("voice.minion."), "Accepted NPC speech plays a minion voice")
	hud.interaction.close()
	check(not stats.buffs.has_effect("invincible") and not GameServer.interacting(player.player_id), "Closing interaction removes its protection")
	check(local_voice.get("stopping", false), "Walking away or closing local speech fades its voice")
	hud.interaction.update_prompt(player, false)
	hud.interaction.suppressed = true
	hud.interaction.update_prompt(player, false)
	check(not hud.interaction.visible, "Party conversation suppresses proximity prompt")
	hud.interaction.suppressed = false
	hud.interaction.update_prompt(player, false)
	check(hud.interaction.visible, "Prompt returns after party conversation ends")
	var dialog := SceneDialog.new()
	dialog.social = social
	dialog.player = player
	dialog.my_id = 7
	dialog.scene = {kind = "talk", driver = 7, title = "Gerald", pages = ["Hello [npc]traveler[/npc]. Welcome home.", "Goodbye."], page = 0}
	hud.add_dialog(dialog)
	dialog._typing.pause()
	dialog._typing.custom_step(0.01)
	check(dialog._text.visible_characters == 5, "Speech reveals the first complete word")
	dialog._typing.play()
	dialog._next()
	check(dialog._text.visible_characters == -1 and social.actions.is_empty(), "First advance finishes the current speech without skipping it")
	dialog._next()
	dialog._next()
	check(social.actions == [["scene_next"]], "Only one page request is sent while awaiting the server")
	dialog.show_page(1)
	check(dialog.scene.page == 1 and not dialog._waiting, "Server page change resets the advance action")
	dialog.queue_free()
	await get_tree().process_frame
	check(player.talk_partner == null, "Closing dialogue releases the camera focus")
	var listener := SceneDialog.new()
	listener.social = social
	listener.player = player
	listener.my_id = 8
	listener.scene = {kind = "talk", driver = 7, title = "Gerald", pages = ["Hello party."], page = 0}
	hud.add_dialog(listener)
	check(listener._buttons.get_child(0) is Label, "Other party members see listening text instead of an advance button")
	var event := InputEventAction.new()
	event.action = "interact"
	event.pressed = true
	listener._input(event)
	check(social.actions == [["scene_next"]], "A listener cannot advance the speaker's conversation")
	listener.queue_free()
	await get_tree().process_frame
	# Shared pages arrive at every participant. UI/ally mutes must not silence
	# an NPC just because this participant is listening rather than driving.
	var audio_preferences := AppSettings.audio.duplicate(true)
	var muted := audio_preferences.duplicate(true)
	muted.ui_sounds = false
	muted.ally_sounds = false
	AppSettings.set_audio(muted)
	var shared := {kind = "talk", driver = 7, title = "Gerald", page = 0,
		pages = ["Hello traveler. Will you help me find the lilies that have vanished from my garden this morning?",
			"Thank you! There is still hope for my garden and all the flowers that used to grow beside the old gate."]}
	var participants: Array[SceneDialog] = []
	for id in [7, 8]:
		var participant := SceneDialog.new()
		participant.social = social
		participant.player = player
		participant.my_id = id
		participant.scene = shared.duplicate(true)
		hud.add_dialog(participant)
		participants.append(participant)
	await get_tree().create_timer(.3).timeout
	var driver_voice := participants[0]._voice._handle
	var party_voice := participants[1]._voice._handle
	check(GameServer.interacting(player.player_id), "Shared conversation protects listening participants too")
	check(not driver_voice.is_empty() and not party_voice.is_empty(), "Both driver and listening party member play speech")
	if not driver_voice.is_empty() and not party_voice.is_empty():
		check(driver_voice.stream == party_voice.stream and driver_voice.pitch == party_voice.pitch,
			"Shared dialogue chooses identical audio on both participants")
		check(driver_voice.bus == "SFX" and not party_voice.positional and not party_voice.ally,
			"Conversation respects SFX volume and remains audible for distant party listeners")
	await get_tree().create_timer(2.7).timeout
	check(participants[0]._voice._phrase >= 2 and participants[1]._voice._phrase >= 2,
		"Long dialogue continues with another phrase while words reveal")
	for participant in participants: participant.show_page(1)
	check(driver_voice.get("stopping", false) and party_voice.get("stopping", false), "Page change retires previous voices")
	await get_tree().create_timer(.25).timeout
	var next_voice := participants[0]._voice._handle
	check(next_voice.get("event", "") == "voice.minion.excited", "Page sentiment selects an excited voice")
	participants[0]._next()
	check(next_voice.get("stopping", false), "Finishing text immediately fades current speech")
	var listening_voice := participants[1]._voice._handle
	for participant in participants: participant.queue_free()
	await get_tree().process_frame
	check(listening_voice.get("stopping", false), "Shared scene ending retires listener audio")
	check(not GameServer.interacting(player.player_id), "Ending the shared scene releases interaction protection")
	# Normal completion also stops speech without an extra click.
	var short_dialog := SceneDialog.new()
	short_dialog.social = social
	short_dialog.player = player
	short_dialog.scene = {kind = "talk", title = "Gerald", driver = 7, pages = ["Hello traveler."], page = 0}
	hud.add_dialog(short_dialog)
	await get_tree().create_timer(.1).timeout
	var finishing_voice := short_dialog._voice._handle
	await get_tree().create_timer(.6).timeout
	check(not finishing_voice.is_empty() and finishing_voice.get("stopping", false), "Natural text completion fades speech")
	short_dialog.queue_free()
	var vote := SceneDialog.new()
	vote.social = social
	vote.player = player
	vote.scene = {kind = "vote", title = "Player", driver = 7, pages = ["What should we do?"], options = {yes = "Continue"}}
	hud.add_dialog(vote)
	await get_tree().create_timer(.2).timeout
	check(vote._voice._handle.is_empty(), "Player vote text does not speak as an NPC")
	vote.queue_free()
	AppSettings.set_audio(audio_preferences)
	# The social search field stays detached until a tab is opened.
	if hud.social_panel._search.get_parent() == null: hud.social_panel._search.free()
	hud.queue_free()
	world.queue_free()
	player.queue_free()
	social.queue_free()
	await get_tree().process_frame
	print("DIALOGUE UI: %d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures else 0)
