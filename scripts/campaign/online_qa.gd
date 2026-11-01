class_name OnlineQA
extends Node
## Automated online review using the actual cards, scene buttons, story portals and loot requests.
var main: Node
var folder := "/home/hugo/Desktop/campaign5_check"
var number := 0
var failed := false
var args := {}
var authority := {}

func pause(seconds := 1.0) -> void:
	await get_tree().create_timer(seconds).timeout

func ready_world() -> void:
	var until := Time.get_ticks_msec() + 45000
	while main._traveling or main.player.frozen:
		if Time.get_ticks_msec() > until:
			fail("world/ground timeout")
			return
		await get_tree().process_frame

func fail(message: String) -> void:
	failed = true
	push_error("[qa] " + message)

func shot(label: String) -> void:
	await pause(0.4)
	await RenderingServer.frame_post_draw
	number += 1
	var path := folder.path_join("%03d_%s.png" % [number, label.validate_filename()])
	get_viewport().get_texture().get_image().save_png(path)
	print("[qa] screenshot ", path)

func move_to(at: Vector3, offset := Vector3(0, 0, 2)) -> void:
	main.hud.interaction.close()
	main._place_player(at + offset)
	await ready_world()
	await pause(1.4)

func press_button(root: Node, caption: String) -> bool:
	for button in root.find_children("*", "Button", true, false):
		if button.text == caption and button.is_visible_in_tree() and not button.disabled:
			button.pressed.emit()
			return true
	return false

func interact(target: InteractionTarget, label: String) -> void:
	if not is_instance_valid(target):
		fail("missing interaction " + label)
		return
	await move_to(target.global_position)
	main.hud.interaction.update_prompt(main.player, false)
	if main.hud.interaction.target != target:
		fail("wrong proximity target: " + label)
		return
	await shot(label + "_prompt")
	main.hud.interaction.accept()
	await pause(0.5)
	var card: InteractionCard = main.hud.interaction
	var pages := 0
	while card.opened and pages < 15:
		await pause(3.2)
		await shot(label + "_page_%02d" % (card._page + 1))
		card.accept()
		pages += 1
	await pause(0.6)
	var turns := 0
	while is_instance_valid(main.campaign._dialog) and turns < 15:
		var dialog: SceneDialog = main.campaign._dialog
		await pause(1.5)
		await shot(label + "_shared_%02d" % (turns + 1))
		if dialog.scene.kind == "vote":
			press_button(dialog, str(dialog.scene.options.values()[0]))
		else:
			if not press_button(dialog, "Next"): press_button(dialog, "Exit")
		turns += 1
		await pause(0.6)

func run(options: Dictionary) -> void:
	args = options
	AppSettings.video.gui_scale = "large"
	AppSettings.gui_changed.emit()
	folder = str(args.get("qa-shots", folder))
	DirAccess.make_dir_recursive_absolute(folder)
	for existing in DirAccess.get_files_at(folder):
		if existing.ends_with(".png"): number = maxi(number, int(existing.get_slice("_", 0)))
	Net.client.social_event.connect(func(ev: Array) -> void:
		if ev[0] == "qa_state": authority = ev[1])
	main.social.line_added.connect(func(line: Dictionary) -> void: print("[qa chat] ", line.text))
	if args.has("qa-quick"):
		for id: String in Campaigns.PACKS.hidden_power.campaigns:
			if args.has("qa-from") and Campaigns.PACKS.hidden_power.campaigns.find(id) < int(args["qa-from"]) - 1: continue
			if args.has("qa-to") and Campaigns.PACKS.hidden_power.campaigns.find(id) > int(args["qa-to"]) - 1: continue
			await quick_campaign(id)
			if failed: break
	elif args.has("boss-sync-test"):
		await bosses()
	elif args.has("party-test"):
		await party_test()
	else:
		await campaign_test(str(args["campaign-test"]))
	if args.has("qa-control-after"):
		folder = folder.path_join("party")
		DirAccess.make_dir_recursive_absolute(folder)
		await party_test()
	print("[qa] FINISHED failures=", failed, " screenshots=", number)
	await main._quit()

func campaign_test(id: String) -> void:
	if not args.has("campaign-resume"):
		Net.client.send_action("camp_test", ["unlock", id])
	await pause(1.0)
	var chronicler: InteractionTarget = main.campaign._npc_target("Aldous the Chronicler")
	if chronicler == null:
		fail("Chronicler absent")
		return
	await move_to(chronicler.global_position)
	main.hud.interaction.update_prompt(main.player, false)
	await shot("chronicler_prompt")
	main.hud.interaction.accept()
	await pause(1.2)
	var browser: CampaignBrowser
	for node in main.hud.find_children("*", "CampaignBrowser", true, false): browser = node
	if browser == null:
		fail("Chronicler did not open book")
		return
	await shot("book_list")
	browser._open = id
	browser._fill()
	await shot("book_tale")
	if not args.has("campaign-resume") and press_button(browser, "Start over"):
		pass
	elif not press_button(browser, "Begin") and not press_button(browser, "Resume"):
		fail("no Begin/Resume button")
		return
	await pause(2.0)
	await ready_world()
	var cycles := 0
	while cycles < 100 and not failed:
		cycles += 1
		var state: Dictionary = main.social.campaign_state().duplicate(true)
		if state.is_empty():
			fail("campaign missing")
			break
		if state.status == "done":
			await pause(2.0)
			await shot("campaign_complete")
			break
		var step := Campaigns.step_def(id, int(state.step))
		print("[qa] STEP ", step.id, " world=", main.world.realm_id)
		await shot("step_" + str(step.id) + "_banner")
		if args.get("campaign-stop", "") == str(step.id):
			Net.client.send_action("camp_test", ["checkpoint"])
			await pause(3.0)
			Net.client.send_action("camp_test", ["state"])
			await pause(1.0)
			print("[qa] AUTHORITY ", JSON.stringify(authority))
			print("[qa] CHECKPOINT ", JSON.stringify(state), " inventory=", JSON.stringify(main.stats.to_data().backpack))
			return
		if Campaigns.is_tavern(main.world.realm_id) and step.world == "campaign":
			for child in main.world.get_children():
				if child is Portal and child.destination == "campaign":
					await move_to(child.global_position, Vector3(0, 0, 3))
					await shot("chronicle_gate_active")
					main._place_player(child.global_position + Vector3(0, 0.8, 0))
					break
			await pause(1.0)
			await ready_world()
			await pause(2.0)
			continue
		if step.world == "campaign" and main.world is DungeonWorld:
			var exit: DungeonPortal
			for child in main.world.get_children():
				if child is DungeonPortal and child.data.get("exit", false): exit = child
			if exit == null:
				fail("missing dungeon exit")
				break
			await move_to(exit.global_position, Vector3(0, 0, 1))
			await shot("dungeon_exit")
			exit.target.activate(main.player)
			await pause(1.0)
			await ready_world()
			await pause(1.5)
			continue
		# Finish the optional shore quest before progressing the main conversation.
		if not state.side_done and step.id == "mirela":
			var side := Campaigns.step_def(id, int(state.side_step), true)
			if side.kind == "talk":
				await interact(main.campaign._npc_target(Campaigns.NPCS[side.npc].name), "side_" + side.id)
			else:
				await use_object(side.objects[0], "side_" + side.id)
			continue
		match str(step.kind):
			"talk", "hand_over":
				await interact(main.campaign._npc_target(Campaigns.NPCS[step.npc].name), str(step.id))
			"kill":
				await move_to(Campaigns.resolve(step.at, main.world), Vector3(0, 0, 7))
				await pause(2.0)
				await shot(str(step.id) + "_gather_fight")
				for k in 12:
					Net.client.send_action("camp_test", ["kill"])
					await pause(0.7)
					if main.social.campaign_state().step != state.step: break
			"interact", "collect":
				for object: Dictionary in step.objects:
					if object.id not in state.done_objects: await use_object(object, str(step.id) + "_" + str(object.id))
			"dungeon": await dungeon(step)
			"chest": await chest(step)
			"vote":
				await pause(1.5)
				if is_instance_valid(main.campaign._dialog):
					await shot("vote_panel")
					press_button(main.campaign._dialog, str(step.options.values()[0]))
					await pause(1.0)
				else: fail("vote absent on return")
			_: fail("unsupported campaign step " + str(step.kind))
		await pause(1.0)
	if cycles >= 100: fail("campaign stalled")

func use_object(object: Dictionary, label: String) -> void:
	var at := Campaigns.resolve(object.at, main.world)
	await move_to(at, Vector3(0, 0, 1.6))
	var target: InteractionTarget
	for node in main.world.find_children("*", "InteractionTarget", true, false):
		if node.title == str(object.name) and node.global_position.distance_to(at) < 1: target = node
	await interact(target, label)

func dungeon(step: Dictionary) -> void:
	var portal: DungeonPortal
	for child in main.world.get_children():
		if child is DungeonPortal and child.data.dungeon == step.dungeon and not child.data.get("exit", false): portal = child
	if portal == null:
		fail("story portal absent " + str(step.dungeon))
		return
	await move_to(portal.global_position, Vector3(0, 0, 1.5))
	main.hud.interaction.update_prompt(main.player, false)
	await shot(str(step.id) + "_portal")
	main.hud.interaction.accept()
	await pause(1.0)
	await ready_world()
	await pause(1.5)
	await shot(str(step.id) + "_interior")
	if not main.world is DungeonWorld:
		fail("portal did not enter " + str(step.dungeon))
		return
	await move_to(main.world.layout.boss, Vector3(0, 0, 9))
	await pause(6.0)
	await shot(str(step.id) + "_boss")
	for k in 4:
		Net.client.send_action("camp_test", ["damage_boss"])
		await pause(3.0)
		await shot(str(step.id) + "_fight_%d" % k)
	Net.client.send_action("camp_test", ["boss"])
	await pause(22.0)
	await shot(str(step.id) + "_defeated")

func chest(step: Dictionary) -> void:
	var bags: Array = GameServer.bags_in(main.world.realm_id, main.player.player_id)
	var record := {}
	for bag: Dictionary in bags:
		if bag.type == "story" and bag.items.any(func(item: Variant) -> bool: return item and item.id == step.until): record = bag
	if record.is_empty():
		fail("story chest missing " + str(step.id))
		return
	await move_to(record.pos, Vector3.ZERO)
	await shot(str(step.id) + "_story_chest")
	GameServer.request_open_chest(main.player.player_id, int(record.id))
	await pause(1.0)
	await shot(str(step.id) + "_chest_open")
	record = GameServer.bag(int(record.id))
	for i in record.items.size():
		if record.items[i]:
			GameServer.request_activate(main.player.player_id, {kind = "bag", key = i, bag = record.id})
			await pause(0.5)
	main.hud.debug_open_inventory()
	await shot(str(step.id) + "_story_inventory")
	Input.action_release("inventory")

func bosses() -> void:
	Net.client.send_action("camp_test", ["arena"])
	await pause(1.0)
	await ready_world()
	var ids := str(args.get("boss-sync-test", ""))
	if ids == "": ids = "blue_dragon,rimeheart_prism,vharok,scarab_regent,hollow_crown,thornmaw_bloom,goblin_king,gilded_vizier,magma_warden,pyre_ent,abyssal_siren,drowned_cantor,hollow_king"
	for id in ids.split(","):
		if id == "hollow_king":
			Net.client.send_action("camp_test", ["arena", "castle"])
			await pause(1.0)
			await ready_world()
		Net.client.send_action("camp_test", ["spawn_boss", id])
		await pause(2.0)
		await ready_world()
		var phases := {}
		var poses := {}
		var peak_hazards := 0
		var peak_helpers := 0
		var peak_bullets := 0
		for tick in (95 if id in ["hollow_king", "rimeheart_prism"] else 50):
			await pause(1.0)
			var actor: Boss
			for boss in Boss.all:
				if is_instance_valid(boss) and boss.def.id == id: actor = boss
			if actor:
				poses[actor.model._boss_pose_name] = true
				peak_hazards = maxi(peak_hazards, actor.hazards.count())
				peak_helpers = maxi(peak_helpers, Net.client._enemies.size() - 1)
				peak_bullets = maxi(peak_bullets, main.enemy_bullets.get_child_count())
				if tick % 10 == 0:
					Net.client.send_action("camp_test", ["inspect"])
				if not phases.has(actor.phase):
					phases[actor.phase] = true
					await shot(id + "_phase_%d" % actor.phase)
					print("[qa boss] ", id, " phase=", actor.phase, " hp=", actor.hp, " state=", actor.state, " hazards=", actor.hazards.count())
			if tick > 15 and tick % 5 == 0: Net.client.send_action("camp_test", ["damage_boss"])
		print("[qa boss] END ", id, " phases=", phases.keys(), " poses=", poses.keys(), " hazards=", peak_hazards, " helpers=", peak_helpers, " bullet_nodes=", peak_bullets)

func party_test() -> void:
	var control := str(args.get("qa-control", "/tmp/voidrealm_qa_p2"))
	var previous := ""
	while true:
		var state := {realm = main.world.realm_id, pos = [main.player.position.x, main.player.position.y, main.player.position.z],
			party = main.social.party, campaign = main.social.campaign_state(), items = main.stats.to_data().backpack,
			authority = authority, traveling = main._traveling, frozen = main.player.frozen, scene = main.campaign._dialog.scene if is_instance_valid(main.campaign._dialog) else {}}
		var file := FileAccess.open(control + ".state", FileAccess.WRITE)
		file.store_string(JSON.stringify(state))
		file.close()
		if FileAccess.file_exists(control + ".command"):
			var raw := FileAccess.get_file_as_string(control + ".command")
			if raw != previous:
				previous = raw
				var command: Variant = JSON.parse_string(raw)
				if command is Dictionary:
					print("[qa control] ", raw)
					match str(command.op):
						"action": Net.client.send_action(command.kind, command.args)
						"travel": await main.travel(str(command.place))
						"move": await move_to(Vector3(command.at[0], command.at[1], command.at[2]), Vector3.ZERO)
						"npc_open":
							var target: InteractionTarget = main.campaign._npc_target(Campaigns.NPCS[command.npc].name)
							if target:
								await move_to(target.global_position)
								main.hud.interaction.update_prompt(main.player, false)
								main.hud.interaction.accept()
						"close": main.hud.interaction.close()
						"portal":
							for portal in main.world.get_children():
								if portal is DungeonPortal and portal.data.get("exit", false) == command.get("exit", false):
									await move_to(portal.global_position, Vector3(0, 0, 1))
									portal.target.activate(main.player)
									break
						"npc": await interact(main.campaign._npc_target(Campaigns.NPCS[command.npc].name), str(command.npc))
						"shot": await shot(str(command.label))
						"checkpoint": Net.client.send_action("camp_test", ["checkpoint"])
						"quit": return
		await pause(0.25)


## Tiny progression smoke test: real realms, interactions, loot and completion;
## only combat is shortened by the dedicated --test server.
func quick_campaign(id: String) -> void:
	var start_number := number
	Net.client.send_action("camp_test", ["unlock", id])
	await pause(0.3)
	main.social.campaign(["start", id, not args.has("qa-resume")])
	await pause(0.6)
	var deadline := Time.get_ticks_msec() + 180000
	var seen := {}
	var pictured := false
	while not failed and Time.get_ticks_msec() < deadline:
		if main.campaign.cinematic.is_playing(): main.campaign.cinematic.cancel()
		await ready_world()
		var state: Dictionary = main.social.campaign_state().duplicate(true)
		if state.is_empty() or state.get("id", "") != id:
			await pause(0.3)
			continue
		if state.status == "done":
			await shot(id + "_complete")
			print("[qa quick] PASS ", id, " steps=", seen.keys(), " shots=", number - start_number)
			return
		var step := Campaigns.step_def(id, int(state.step))
		if not seen.has(step.id):
			seen[step.id] = true
			print("[qa quick] ", id, " STEP ", step.id, " realm=", main.world.realm_id)
		if is_instance_valid(main.campaign._dialog):
			if main.campaign._dialog.scene.kind == "vote":
				main.social.campaign(["vote", main.campaign._dialog.scene.options.keys()[0]])
			else: main.social.campaign(["scene_next"])
			await pause(0.2)
			continue
		var destination := ""
		if step.world == "hall" and not Campaigns.is_tavern(main.world.realm_id): destination = "hall"
		if step.world == "castle" and not main.world is CastleWorld: destination = "castle"
		if step.world == "campaign" and not main.world is IslandWorld and not (step.kind == "dungeon" and main.world is DungeonWorld):
			if main.world is DungeonWorld:
				for portal in main.world.get_children():
					if portal is DungeonPortal and portal.data.get("exit", false):
						main._place_player(portal.global_position + Vector3(0, 0.2, 1))
						await ready_world()
						await pause(0.3)
						portal.target.activate(main.player)
						break
				await pause(0.5)
				continue
			else: destination = "campaign"
		if destination != "":
			await main.travel(destination)
			await pause(0.3)
			continue
		match str(step.kind):
			"talk", "hand_over":
				var target: InteractionTarget = main.campaign._npc_target(Campaigns.NPCS[step.npc].name)
				if target == null:
					fail(id + " missing NPC " + str(step.npc)); break
				main._place_player(target.global_position + Vector3(0, 0.2, 2))
				await ready_world()
				await pause(0.3)
				if not pictured:
					main.player.set_zoom(45.0)
					await shot(id + "_npc_zoomed_out")
					main.player.set_zoom(30.0)
					pictured = true
				main.social.quest("npc:" + str(step.npc))
			"ask_around":
				main.social.quest("ask:qa_%d" % Time.get_ticks_usec())
			"set_home": Net.client.send_action("home", [step.village])
			"interact", "collect":
				for object: Dictionary in step.objects:
					if object.id in state.done_objects: continue
					var at := Campaigns.resolve(object.at, main.world)
					var found := false
					for target in main.world.find_children("*", "InteractionTarget", true, false):
						if target.title == object.name and target.global_position.distance_to(at) < 1.0: found = true
					if not found: fail(id + " missing object " + str(object.id)); break
					main._place_player(at + Vector3(0, 0.2, 1.5))
					await ready_world()
					await pause(0.25)
					if number - start_number < 2: await shot(id + "_object_" + str(object.id))
					main.social.quest("obj:" + str(object.id))
					await pause(0.25)
			"kill":
				if main.world is CastleWorld:
					main._place_player(Vector3(0, 0.2, -8))
					if step.id == "king":
						for bag: Dictionary in GameServer.bags_in(main.world.realm_id, main.player.player_id):
							if bag.items.any(func(item: Variant) -> bool: return item and item.id == "story_throne_key"):
								await quick_loot(bag)
						main._place_player(Vector3(0, 0.2, -24))
						await pause(0.3)
						Net.client.send_action("castle", ["door"])
						await pause(0.5)
						for boss in Boss.all:
							if is_instance_valid(boss) and boss.def.id == "hollow_king": main._place_player(boss.global_position + Vector3(0, 0.2, 8))
				else:
					var at := Campaigns.resolve(step.at, main.world)
					main._place_player(at + Vector3(0, 0.2, 6))
				await ready_world()
				await pause(0.4)
				Net.client.send_action("camp_test", ["quick_kill"])
			"dungeon":
				var found := false
				for portal in main.world.get_children():
					if portal is DungeonPortal and portal.data.dungeon in [step.dungeon, step.get("encore", "")] and not portal.data.get("exit", false):
						found = true
						main._place_player(portal.global_position + Vector3(0, 0.2, 1))
						await ready_world()
						await pause(0.3)
						portal.target.activate(main.player)
						break
				if found:
					await pause(0.3)
				elif main.world is DungeonWorld:
					main._place_player(main.world.layout.boss + Vector3(0, 0.2, 7))
					await ready_world()
					await pause(0.3)
					Net.client.send_action("camp_test", ["quick_kill"])
				elif not found: fail(id + " missing dungeon portal " + str(step.dungeon))
			"chest":
				if step.at is Dictionary:
					main._place_player(Campaigns.resolve(step.at, main.world) + Vector3(0, 0.2, 1))
					await ready_world()
					await pause(0.4)
				var found := false
				for bag: Dictionary in GameServer.bags_in(main.world.realm_id, main.player.player_id):
					if bag.type == "story" and bag.items.any(func(item: Variant) -> bool: return item and item.id == step.until):
						found = true
						await quick_loot(bag)
				if not found: await pause(0.3)
			"enter", "vote": pass
			_: fail("unsupported quick step " + str(step.kind))
		await pause(0.3)
	fail("quick campaign did not complete: " + id)


func quick_loot(bag: Dictionary) -> void:
	main._place_player(bag.pos + Vector3(0, 0.2, 0))
	await ready_world()
	await pause(0.25)
	GameServer.request_open_chest(main.player.player_id, int(bag.id))
	await pause(0.2)
	for i in bag.items.size():
		if bag.items[i]: GameServer.request_activate(main.player.player_id, {kind = "bag", key = i, bag = bag.id})
	await pause(0.3)


func _process(_delta: float) -> void:
	if args.has("qa-quick") and is_instance_valid(main):
		main.transition.hide()
		if main.campaign.cinematic.is_playing(): main.campaign.cinematic.cancel()
