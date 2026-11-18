extends Node3D
## Offline review of actual portal targets and the shared interaction card.
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func _ready() -> void: run.call_deferred()
func run() -> void:
	GameAudio._disabled = true
	GameServer.set_physics_process(false)
	WorldServer.set_process(false)
	var world := GameWorld.new()
	add_child(world)
	var player := Player.new()
	player.stats = PlayerStats.new()
	player.player_id = GameServer.add_player(player.stats)
	player.frozen = false
	world.add_child(player)
	player.add_child(player.aim_marker)
	player.set_physics_process(false)
	player.set_process(false)
	var view := SubViewport.new()
	view.size = Vector2i(1280, 850)
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(view)
	var root := Control.new()
	root.size = view.size
	root.theme = UIStyle.theme()
	view.add_child(root)
	var background := ColorRect.new()
	background.color = Color("101724")
	background.size = view.size
	root.add_child(background)
	var label := UIStyle.label("DUNGEON PORTALS", 30, UIStyle.GOLD)
	label.position = Vector2(150, 35)
	root.add_child(label)
	var cards: Array[InteractionCard] = []
	var portals: Array[DungeonPortal] = []
	for dungeon: String in ["goblins_cave", "drowned_spire", "starless_sepulchre"]:
		var at := Vector3(portals.size() * 100, 0, 0)
		var portal := DungeonPortal.new({id = "preview_" + dungeon, dungeon = dungeon, pos = at})
		world.add_child(portal)
		portals.append(portal)
		player.position = at
		var card := InteractionCard.new()
		root.add_child(card)
		card.world = world
		card.set_meta("player", player)
		card.update_prompt(player, false)
		check(card.target == portal.target, "The real portal target is selected")
		check(card._title.text == Dungeons.definition(dungeon).name, "Portal name is the title")
		check(portal.target.description.is_empty() and not card._message.visible, "No difficulty prose or loot sentence")
		check(not card._portrait.visible, "No empty portrait space")
		check(card._difficulty.visible and card._difficulty.get_child_count() == 10, "Ten difficulty markers")
		var rating: float = Dungeons.definition(dungeon).rating
		for i in 10:
			var pip := card._difficulty.get_child(i) as TextureProgressBar
			check(pip.texture_under.get_size() == Vector2(8, 8) and pip.texture_progress.get_size() == Vector2(8, 8), "Native 8x8 art")
			check(is_equal_approx(pip.value, clampf(rating - i, 0, 1) * 100), "Exact full, half and black markers")
		card.set_anchors_preset(Control.PRESET_TOP_LEFT)
		card.position = Vector2(145, 125 + cards.size() * 225)
		card.size = Vector2(990, 0)
		cards.append(card)
	# A normal conversation must still show its description after an empty portal.
	for portal: DungeonPortal in portals: portal.target.enabled = false
	player.position = Vector3.ZERO
	var npc := InteractionTarget.new()
	npc.title = "Caretaker"
	npc.description = "A friendly greeting."
	world.add_child(npc)
	cards[0]._near_refresh = 0
	cards[0].update_prompt(player, false)
	check(cards[0]._message.visible and not cards[0]._difficulty.visible, "Normal text returns and markers disappear")
	npc.enabled = false
	portals[0].target.enabled = true
	cards[0].update_prompt(player, false)
	cards[0].accept()
	check(cards[0].opened and not cards[0]._message.visible, "Entering a portal does not reveal a Welcome text page")
	check(GameServer.interacting(player.player_id), "Portal interaction keeps its existing transition protection")
	cards[0].close()
	check(not GameServer.interacting(player.player_id), "Closing the prompt releases its protection")
	cards[0].update_prompt(player, false)
	# Theory uses the same clean entrance presentation; exits keep their return hint.
	var theory := DungeonPortal.new({id = "theory_preview", dungeon = "theory_of_everything", pos = Vector3(500, 0, 0)})
	world.add_child(theory)
	check(theory.target.description.is_empty(), "Theory no longer adds a separate explanation")
	var exit := DungeonPortal.new({id = "exit_preview", dungeon = "goblins_cave", exit = true, pos = Vector3(600, 0, 0)})
	world.add_child(exit)
	check(exit.target.difficulty < 0 and not exit.target.description.is_empty(), "Return portals have no difficulty")
	await get_tree().process_frame
	await get_tree().process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		view.get_texture().get_image().save_png("/home/hugo/tmp/dungeon_difficulty_preview.png")
	print("DUNGEON DIFFICULTY: %d failures" % failures)
	view.queue_free()
	await get_tree().process_frame
	GameServer.remove_player(player.player_id)
	world.free()
	get_tree().quit(1 if failures else 0)
