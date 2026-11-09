extends Node3D
## Runs the game: opens on the start screen (over the Tavern, blurred), then
## travels between worlds through portals with a jump to lightspeed and the
## loading screen in between, keeps the atmosphere and fog of war in step with
## the biome, and connects the character's stats to the HUD (levels, XP, damage).
##
## Main is the client: it joins the server (GameServer) as a player, sends
## where the player is and what they do, and shows what the server says.
## Characters, loot, XP and rewards are the server's; nothing here changes
## them directly. Nothing pauses: the game menu only locks your input.
##
## Everything needs a Void Realms account (Account): Singleplayer starts a
## server of your own on this computer and joins it; Servers joins a
## dedicated server (see Net). Either way the character is the account's,
## every trip goes through the server, enemies are the server's (shown here
## as mirrors), and dying ends the character for good: its record shows,
## then you pick or make another one. Characters are changed in the Tavern
## (the picker top left). The offline mode only remains for debug runs.
##
## Keys: C toggles the stats tab, Tab (hold) opens the backpack, Escape opens
## the game menu.
## Development: F3 toggles SDFGI, F4 toggles
## fog of war, F6 gives 100 XP, F7 deals a test hit of 25, F9 throws Realm 1
## away so the server generates a new one.
## Debug: run with  -- --shot=/path/out.png [--world=realm] [--biome=Name]
## [--feature=type] [--pos=X,Y,Z] [--closeup] [--zoom=N] [--walk=X,Y]
## [--aim=DX,DZ] [--aim-obstacle] [--shoot] [--nofog] [--destroy-test] [--shield] [--levelup]
## [--stats] [--tooltip] [--equip=G5_bow,...] [--ring] [--inventory]
## [--charge=SECONDS] [--after=SECONDS] (hold right click; shot taken
## `after` seconds after release, default 0.12)
## [--charging=SECONDS] (shot taken while still holding)
## [--goblins] (stand near the closest goblin pack) [--pack=ID] [--near=M]
## (stand M meters from the closest pack of that type; use with --biome)
## [--fight=SECONDS] (shoot the nearest enemy for a while)
## [--ripple=METERS] (an enemy warp ripple starts that far away; shot taken
## `after` seconds later; add --shield to see the shield brace)
## [--bags] (one loot bag of every color around you, standing on a gray one)
## [--clash=METERS] (also casts your ring at the same time, to see the rings
## clash; --ripple-damage=N sets the ripple's strength; needs a tier 4+ spell)
## [--title] [--menu] (the start screen / game menu) [--servers [--login=U:P]] (the server list) [--loading] (the loading
## screen) [--jump=SECONDS] [--jump-out=SECONDS] (partway into / out of
## hyperspace) [--travel=DEST] (a whole trip, e.g. realm_1; shot on arrival)
## [--boss[=blue|frost|lava|desert|dark]] (stand near that stronghold's boss;
## default Blue Dragon) [--boss-hp=N] (its base health, for quick tests)
## [--hatch] (break its shell at once) [--boss-phase=N] (skip to phase N: 1-3)
## [--interact=smith|magician|baker] [--accept-interaction] (home service review)
## [--godmode] (take no damage) [--wait=SECONDS] (before the shot; default 4)
## to save a screenshot after the world loads and quit. Debug runs skip the
## start screen and travel without the transition.
## Online test: -- --online=HOST[:PORT] --login=USER:PASS [--account=URL]
## [--realm] [--goblins] [--fight=SECONDS] [--online-wait=SECONDS] [--online-shot=PATH]
## logs in, joins, optionally goes into a realm and fights, prints a report and quits.

const DEBUG_FIRE_DELAY := 0.36
const XP_PER_OBSTACLE := 3
## Demo: start with a Backpack strapped on, one of every gear item in it,
## and a few elixirs in the quickslots.
const DEMO_ALL_ITEMS := true

var world: GameWorld
var player := Player.new()
var fog_of_war := FogOfWar.new()
var atmosphere := Atmosphere.new()
var arrows := Arrows.new()
var stats: PlayerStats  # our character, as the server has it (read only)
var enemy_bullets := EnemyBullets.new()
var xp_orbs := XpOrbs.new()
var loot_bags := LootBags.new()
var hud: Hud
var transition := Transition.new()
var _world_loader := WorldLoader.new()
var _preparing_world := false
var _world_generation := 0
var _async_world_build := false
var low_health := LowHealthOverlay.new()
var menus := Menus.new()
var _traveling := false
var _dead := false  # online: our character died, waiting for the next one
var _switching := false
var _creating_character := false
var _connecting := false
var _death_record := {}

var _args := {}


var boss_introduction := BossIntroduction.new()
## Chat, friends, the party (see SocialClient), and its campaign in the world.
var social := SocialClient.new()
var campaign := CampaignClient.new()
var _name_timer := 0.0

func _ready() -> void:
	# The game started as a Singleplayer server (see _start_singleplayer):
	# exported builds can't be given another scene on the command line.
	if "--dedicated" in OS.get_cmdline_user_args():
		set_process(false)
		set_process_unhandled_input(false)
		get_tree().change_scene_to_file.call_deferred("res://scenes/server/dedicated.tscn")
		return
	get_tree().node_added.connect(_readable_world_label)
	_setup_input()
	_parse_args()

	add_child(atmosphere)
	player.player_id = GameServer.join(DEMO_ALL_ITEMS)
	stats = GameServer.character(player.player_id)
	player.stats = stats
	add_child(player)
	add_child(player.aim_marker)
	add_child(GameCursor.new())
	add_child(fog_of_war)
	add_child(arrows)
	add_child(enemy_bullets)
	add_child(xp_orbs)
	add_child(loot_bags)
	loot_bags.local_player = player
	enemy_bullets.players = [player]
	xp_orbs.player = player
	atmosphere.fog_of_war = fog_of_war
	atmosphere.attach_particles(player)
	arrows.exclude = [player.get_rid()]
	player.shot.connect(_on_shot)
	player.ring_cast.connect(_on_ring_cast)
	arrows.hit.connect(_on_projectile_hit)
	arrows.ended.connect(_on_shot_burst)
	stats.changed.connect(player.refresh_gear)
	player.refresh_gear()

	hud = Hud.new(stats, player)
	hud.loot = loot_bags
	add_child(hud)
	stats.consumed.connect(_on_consumed)
	stats.leveled_up.connect(_on_level_up)
	GameServer.player_died.connect(_on_died)

	low_health.stats = stats
	add_child(low_health)
	add_child(menus)
	add_child(boss_introduction)
	add_child(social)
	campaign.social = social
	campaign.main = self
	add_child(campaign)
	hud.add_social(social, _body_of)
	hud.quest_markers = campaign.markers
	social.goto.connect(func(place: String, at: Vector3) -> void:
		if not _dead: travel.call_deferred(place, at))
	social.warp.connect(_warp)
	social.space_unlocked.connect(func() -> void:
		hud.toasts.push("The way to Space is open! Find the Skyward Launch Pad south of Hearthwick.", UIStyle.GOLD, 10.0))
	social.join_requested.connect(join_friend)
	add_child(transition)
	add_child(_world_loader)
	_world_loader.progress_changed.connect(transition.set_progress)
	menus.singleplayer_pressed.connect(_start_singleplayer)
	menus.join_requested.connect(_join_server)
	menus.leave_pressed.connect(func() -> void: _return_offline("You left."))
	menus.quit_pressed.connect(_quit)
	menus.closed.connect(func() -> void: player.input_locked = _traveling or _dead)
	get_tree().auto_accept_quit = false
	hud.picker.switch_requested.connect(_switch_character)
	hud.picker.new_requested.connect(_new_character)
	hud.picker.record_requested.connect(func(record: Dictionary) -> void:
		hud.add_dialog(DeathRecord.new(record, true, "Close")))

	if _args.has("play-winter"):
		_start_winter_play()
		return
	if _args.has("play-dungeon"):
		_start_dungeon_play()
		return
	if _args.has("play-space"):
		_prepare_manual_archer()
		_load_world(SpaceWorld.REALM, {id = SpaceWorld.REALM, seed = 0, destroyed = [], space = true, intro = _args.has("intro")})
		hud.toasts.push("Space (offline preview). Command table: launch a ship.", UIStyle.GOOD, 7.0)
		return
	if _args.has("watch-dungeon"):
		GameServer.debug_godmode = true
		_load_world("dng_goblins_cave_preview", Dungeons.record("dng_goblins_cave_preview", "goblins_cave", int(_args.get("seed", "4217"))))
		var watcher = load("res://tools/boss_watch/goblin_watcher.gd").new()
		watcher.game = self
		add_child(watcher)
		return
	if _args.has("watch-boss"):
		var key: String = str(_args["watch-boss"])
		if not BOSS_ARGS.has(key): key = "blue"
		WorldServer.save_dir = "user://boss_watch/"
		WorldServer.reset_realm("boss_watch_"+key)
		_load_world("boss_watch_"+key)
		var watcher = load("res://tools/boss_watch/fight_watcher.gd").new()
		watcher.game = self
		watcher.key = key
		add_child(watcher)
		return
	if _args.has("online"):
		_load_world("hall")
		_debug_online()
		return
	if _args.has("shot"):
		_load_world("realm_1" if _args.get("world", "") == "realm" else "hall")
		_take_screenshot()
		return
	# The start screen, over the Tavern turning slowly in the background.
	_traveling = true
	hud.visible = false
	player.input_locked = true
	# Branding is the first visible scene. Prepare the menu world underneath it;
	# booting is not portal travel and must never play the assembly animation.
	var intro := preload("res://scripts/ui/launch_intro.gd").new()
	add_child(intro)
	intro.play(true)
	if not await _load_world_async("hall"): return
	await _arrive(false)
	hud.visible = false
	player.input_locked = true
	menus.show_start()
	intro.release_to_menu()
	await intro.finished
	if not await Account.refresh():
		menus.show_login(false)


## A human-controlled development session, isolated by its launcher data folder.
func _prepare_manual_archer() -> void:
	GameServer.debug_godmode = false
	stats.class_id = "archer"
	stats.reset()
	stats.gear = {weapon = Items.make("G8_bow"), armor = Items.make("D_cloak_ofiron"),
		spell = Items.make("D_spell_oftheblue"), bonus = Items.make("G8_bonus_flame")}
	stats.add_backpack()
	stats.give(["D_bow_offrost", "D_bow_ofstorm", "D_bow_ofiron", "D_bow_dragon", "D_bow_Fallenwoods",
		"G8_cloak", "D_cloak_silvershield", "D_spell_ofthedivine", "D_spell_ofstorm",
		"D_bonus_crucifix_ofiron", "G8_bonus_eye", "G8_bonus_crystal"].map(func(id: String) -> Item: return Items.make(id)).filter(func(item: Item) -> bool: return item != null))
	for index in PlayerStats.QUICKSLOTS:
		stats.quick[index] = Items.make("elixir_hp" if index == 0 else "elixir_mp")
		stats.quick[index].count = stats.quick[index].stack_max
	stats.level = PlayerStats.MAX_LEVEL
	stats.developer_max_stats()
	player.refresh_gear()
	menus.hide_all()
	hud.show()
	player.input_locked = false


func _start_dungeon_play() -> void:
	_prepare_manual_archer()
	var id := str(_args.get("play-dungeon", "goblins_cave"))
	if not Dungeons.DEFINITIONS.has(id): id = "goblins_cave"
	var realm := "dng_%s_manual" % id
	_load_world(realm, Dungeons.record(realm, id, int(_args.get("seed", "4217"))))
	hud.toasts.push("Level 50 archer - maxed stats and endgame gear. Tab: spare gear, F/G: potions.", UIStyle.GOOD, 7.0)
	print("[play] Ready in ", id, " as a maxed archer; gear ", stats.gear.values().map(func(item: Item) -> String: return item.id))


## Chapter-two checkpoint for a human-controlled local play session.
func _start_winter_play() -> void:
	_prepare_manual_archer()
	stats.home = "Snowbell"
	stats.give([Items.make("key_crown_of_the_rime"), Items.make("story_clue"), Items.make("story_ice_card")])
	var realm := Campaigns.realm_id(0, "frozen_whisper")
	WorldServer.reset_realm(realm)
	var chapter := Campaigns.get_def("frozen_whisper")
	social.party_at = Time.get_ticks_msec() / 1000.0
	social.party = {id = 1, leader = social.my_name, members = [{player_id = player.player_id,
		name = social.my_name, leader = true, class_id = "archer", level = 50, dead = false, place = "Crown of the Rime"}],
		campaign = {id = "frozen_whisper", title = chapter.title, owner = 0, status = "active", realm = realm,
			tavern = Campaigns.tavern_id(0, "frozen_whisper"), step = Campaigns.step_index("frozen_whisper", "stronghold"),
			count = 0, needed = 1, side_step = 0, side_done = true, done_objects = [], elapsed = 0.0, deaths = 0,
			revealed = ["tobias", "halvard"], objective = {}, side_objective = {}, links = []}}
	social.local_campaign_requested.connect(_manual_winter_action)
	stats.changed.connect(_manual_winter_inventory)
	_load_world(realm, {}, _winter_gate_spawn)
	(world as IslandWorld).enemy_director.enemy_killed.connect(_manual_winter_killed)
	hud.toasts.push("Chapter 2 - the Crown of the Rime key is in your backpack. E: talk to the gate lock.", UIStyle.GOOD, 8.0)
	print("[play] Chapter 2 ready outside winter gate at ", player.global_position, "; level ", stats.level,
		"; key ", not stats.find_item("key_crown_of_the_rime").is_empty())


func _winter_gate_spawn(place: GameWorld) -> Vector3:
	var island := place as IslandWorld
	for fort in island.generator.strongholds:
		if fort.biome_id != Biomes.FOSEN: continue
		var gate: Node3D = island.gates.entries[fort.center].root
		var at := gate.to_global(Vector3(0.5, 0, -38.0))
		at.y = island.ground_height(at.x, at.z)
		return at
	return place.spawn_point


func _manual_winter_killed(enemy: Enemy) -> void:
	var checkpoint := social.campaign_state()
	if enemy.def.id != "rimeheart_prism" or int(checkpoint.step) != Campaigns.step_index(checkpoint.id, "stronghold"): return
	checkpoint.step = Campaigns.step_index(checkpoint.id, "shard")
	checkpoint.chest = GameServer.spawn_bag(world.realm_id, [Items.make("story_clue")], enemy.global_position, GameServer.PUBLIC, "story")
	var chest := GameServer.bag(int(checkpoint.chest))
	checkpoint.objective = {world = world.realm_id, pos = chest.pos}
	social.party_changed.emit()


func _manual_winter_inventory() -> void:
	var checkpoint := social.campaign_state()
	if checkpoint.is_empty() or int(checkpoint.step) != Campaigns.step_index(checkpoint.id, "shard"): return
	var piece := stats.find_item("story_clue")
	if piece.is_empty() or stats.item_at(piece).count < 2: return
	checkpoint.step = Campaigns.step_index(checkpoint.id, "return")
	checkpoint.objective = {}
	social.party_changed.emit()


func _manual_winter_action(args: Array) -> void:
	var checkpoint := social.campaign_state()
	if args.size() < 2 or args[0] != "quest" or args[1] != "npc:halvard": return
	if int(checkpoint.step) != Campaigns.step_index(checkpoint.id, "return"): return
	if is_instance_valid(hud.interaction.target):
		hud.interaction.target.response = str(Campaigns.step_def(checkpoint.id, int(checkpoint.step)).say)
	checkpoint.status = "done"
	hud.toasts.push("Chapter 2 complete!", UIStyle.GOOD, 5.0)
	social.party_changed.emit()


## What the loading screen calls a place.
static func place_name(destination: String) -> String:
	if Dungeons.is_dungeon(destination):
		for id: String in Dungeons.DEFINITIONS:
			if destination.begins_with("dng_" + id + "_"): return Dungeons.definition(id).name
		return "Dungeon"
	if Campaigns.is_tavern(destination):
		return "The Tavern"
	if ChambersWorld.is_chambers(destination):
		return "Chambers"
	if SpaceWorld.is_space(destination):
		return "The Space"
	if destination == "castle" or Campaigns.is_castle(destination):
		return "The Hollow Castle"
	return "Campaign" if destination == "campaign" or Campaigns.is_campaign_realm(destination) else "The Surface"


## Goes to another place: a jump to lightspeed into the loading screen, the
## new place loads, and we drop out of hyperspace into it (at `at`, when
## set: a teleport to another player).
## A ship boarding or exit is under way behind a black screen: fade back up
## once we have moved (or after a moment, if the move was refused).
var _ship_move_until := 0
var _ship_moved := false
var _was_aboard := false

func expect_ship_move() -> void:
	_ship_move_until = Time.get_ticks_msec()+2500
	_ship_moved = false

func _update_ship_fade() -> void:
	var aboard := SpaceLayout.pocket_at(player.global_position)>=0
	if aboard!=_was_aboard:
		_ship_moved = true
		# The ground may still be building where we arrived: give it time.
		if _ship_move_until!=0: _ship_move_until = maxi(_ship_move_until, Time.get_ticks_msec()+4000)
	_was_aboard = aboard
	if _ship_move_until==0 or not transition.is_black(): return
	if (_ship_moved and not player.frozen) or Time.get_ticks_msec()>_ship_move_until:
		_ship_move_until = 0
		transition.fade_from_black(0.45)

## Set by the launch pad or a descending ship just before travelling: which
## arrival this is ("launch" up to Space, "descend" down to the pad).
var _port_arrival := ""
var _ship_travel := false
var _ship_view_state := {}
var _offline_ship_transfer := {}

func set_port_arrival(kind: String) -> void:
	_port_arrival = kind
	if player.spatial_controller is SpaceTraversal:
		var view := player.spatial_controller as SpaceTraversal
		_ship_view_state = {yaw = player.camera_yaw, pitch = view.look_pitch, mode = view.camera_mode, cockpit = view._cockpit}
	if not Net.is_client():
		var source: SpaceWorld = world if world is SpaceWorld else world.surface_ships if world is IslandWorld else null
		var vessel := source.ship_in_slot(SpaceLayout.pocket_at(player.global_position)) if source else null
		if vessel:
			_offline_ship_transfer = {wire = vessel.wire().duplicate(true), smoking = vessel.smoking.duplicate(),
				imported = {}, passengers = {player.player_id: player.global_position-SpaceLayout.pocket_origin(vessel.slot)}}

func travel(destination: String, at := Vector3.INF, cinematic_departure := false) -> void:
	if _traveling or _dead:
		return
	if ChambersWorld.is_chambers(destination) and not Net.is_client():
		hud.toasts.push("The Chambers open when you play online or in Singleplayer.", UIStyle.HP_LIGHT, 3.0)
		return
	_traveling = true
	_ship_travel = cinematic_departure or _port_arrival in ["launch", "descend"]
	boss_introduction.cancel()
	if world is CastleWorld and is_instance_valid(world.encounter): world.encounter._restore_camera()
	player.input_locked = true
	if menus.is_open(): menus.hide_all()
	hud.visible = false
	var original_client := Net.client
	var original_generation := _world_generation
	if _ship_travel:
		await transition.fade_in(place_name(destination))
		if cinematic_departure: await transition.fade_from_black(0.2)
	elif not _args.has("qa-quick"): await transition.jump_in(place_name(destination))
	if original_client!=Net.client or original_generation!=_world_generation: return
	var record := {}
	if Net.is_client():
		record = await Net.client.enter(destination)
		if record.has("error"):
			hud.visible = true
			if _ship_travel: await transition.reveal()
			elif not _args.has("qa-quick"): await transition.jump_out()
			player.input_locked = false
			hud.toasts.push(record.error, UIStyle.HP_LIGHT, 3.0)
			_traveling = false
			_ship_travel = false
			_port_arrival = ""
			boss_introduction.clear_world()
			return
	if not await _load_world_async(destination,record):
		_preparing_world = false
		if is_instance_valid(world): world.process_mode = Node.PROCESS_MODE_INHERIT
		hud.visible = true
		if _ship_travel: await transition.reveal()
		elif not _args.has("qa-quick"): await transition.jump_out()
		player.input_locked = _dead
		_traveling = false
		_ship_travel = false
		_port_arrival = ""
		return
	var port := str(record.get("port", _port_arrival))
	if cinematic_departure and not Net.is_client(): port = "rocket"
	_port_arrival = ""
	if not Net.is_client() and not _offline_ship_transfer.is_empty():
		var target: SpaceWorld = world if world is SpaceWorld else world.surface_ships if world is IslandWorld else null
		if target:
			var vessel := target.accept_transfer(_offline_ship_transfer, "surface_landing" if target is SurfaceShipWorld else "flying")
			if vessel: record.arrival_pos = target.pocket_point(vessel.slot, _offline_ship_transfer.passengers[player.player_id])
		_offline_ship_transfer = {}
	if record.has("arrival_pos"): at = record.arrival_pos
	elif port=="rocket" and world is IslandWorld: at = (world as IslandWorld).launchpad_arrival()
	if world is IslandWorld and SpaceLayout.pocket_at(at)>=0 and is_instance_valid(world.surface_ships):
		player.set_spatial_world(world.surface_ships)
	if at != Vector3.INF and (world.is_walkable(at) or (world is IslandWorld and SpaceLayout.pocket_at(at)>=0)):
		_place_player(at if record.has("arrival_pos") else Vector3(at.x, world.ground_height(at.x, at.z), at.z))
	if _ship_travel and player.spatial_controller is SpaceTraversal:
		var view := player.spatial_controller as SpaceTraversal
		player.camera_yaw = float(_ship_view_state.get("yaw", player.camera_yaw))
		view.look_pitch = float(_ship_view_state.get("pitch", view.look_pitch))
		view.camera_mode = int(_ship_view_state.get("mode", view.camera_mode))
		view._cockpit = bool(_ship_view_state.get("cockpit", true))
	if port=="descend" and world is IslandWorld and is_instance_valid(world.surface_ships):
		world.surface_ships.begin_arrival(player.player_id)
	await _arrive()



## Waits until the new place is ready around the player (as short as
## possible), then drops out of hyperspace into it.
func _arrive(animate := true) -> void:
	await get_tree().process_frame
	while player.frozen or (is_instance_valid(world) and not world.is_presentation_ready()):
		await get_tree().process_frame
	await get_tree().create_timer(0.15).timeout  # a moment for the first frames to settle
	# Portal capture is part of loading too; finish the bar only after it is ready.
	transition.set_progress(0.95)
	if _ship_travel:
		await transition.reveal()
		_ship_travel = false
	elif animate and not _args.has("qa-quick"): await transition.jump_out()
	hud.visible = true
	_async_world_build = false
	if is_instance_valid(world): world.set_meta("asynchronous_load",false)
	GameServer.grant_arrival_protection(player.player_id)
	if Net.is_client(): Net.s_action.rpc_id(1, "arrived", [])
	player.input_locked = _dead
	_traveling = false


## Builds every creature's meshes once, while the loading screen is up (the
## Blue Dragon alone is a few hundred thousand voxels).
func _preload_creatures() -> void:
	for id in Enemies.all_ids():
		CreatureModel.preload_creature(Enemies.get_def(id).model,true)


## Swaps in another world (no transition).
## online_record: the place the server gave us (online only).
func _load_world_async(destination: String, online_record := {}) -> bool:
	_world_generation += 1
	var generation := _world_generation
	_preparing_world = true
	if is_instance_valid(world): world.process_mode = Node.PROCESS_MODE_DISABLED
	var record: Dictionary = online_record if Net.is_client() or online_record.has("dungeon") else GameServer.enter_realm(player.player_id,destination)
	var actual_destination := str(record.get("id",destination)) if Net.is_client() else destination
	var prepared := await _world_loader.prepare(actual_destination,record)
	if generation!=_world_generation or not is_instance_valid(prepared):
		if is_instance_valid(prepared): _world_loader.retire(prepared)
		if generation==_world_generation:
			_preparing_world = false
			if is_instance_valid(world): world.process_mode = Node.PROCESS_MODE_INHERIT
		return false
	_async_world_build = true
	transition.set_destination_name(prepared.display_name)
	_load_world(actual_destination,record,Callable(),prepared)
	_preparing_world = false
	transition.set_progress(0.9)
	return true


func _load_world(destination: String, online_record := {}, spawn_resolver := Callable(), prepared: GameWorld = null) -> void:
	_world_generation += 1
	_world_loader.cancel_prepare()
	player.set_spatial_world(null)
	boss_introduction.clear_world()
	if world:
		_world_loader.retire(world)
	arrows.clear()
	enemy_bullets.clear()
	xp_orbs.clear()
	var record: Dictionary = online_record if prepared!=null or Net.is_client() else GameServer.enter_realm(player.player_id,destination)
	if online_record.has("dungeon"): record = online_record
	if Net.is_client():
		destination = str(record.get("id", destination))
	if prepared==null and not Campaigns.is_tavern(destination) and not record.get("chambers", false) and not record.get("space", false) and str(record.get("dungeon",""))!="theory_of_everything":
		_preload_creatures()
	if prepared!=null:
		world = prepared
	elif Campaigns.is_tavern(destination):
		world = load("res://scenes/home/tavern.tscn").instantiate()
		if destination != "hall":  # a campaign's own Tavern
			(world as HallWorld).campaign_tavern = true
			world.realm_id = destination
			world.display_name = str(record.get("name", world.display_name))
	elif record.get("chambers", false):
		world = ChambersWorld.new(record)
	elif record.get("space", false):
		world = SpaceWorld.new(record)
	elif record.get("castle", false):
		world = load("res://scenes/castle/hollow_castle.tscn").instantiate()
		world.realm_id = str(record.id)
		world.display_name = str(record.get("name", "The Hollow Castle"))
	elif record.has("dungeon"):
		world = Dungeons.create_world(record)
	else:
		world = IslandWorld.new(record)
	add_child(world)
	world.portal_entered.connect(func(dest: String) -> void: travel.call_deferred(dest))
	world.obstacle_broken.connect(func(o: Obstacle) -> void:
		if Net.is_client():
			Net.client.obstacle_broken(o)
			return
		GameServer.drop_xp(world.realm_id, o.global_position + Vector3.UP * minf(o.prefab.height * 0.5, 1.5),
				XP_PER_OBSTACLE))
	if world is IslandWorld:
		var island := world as IslandWorld
		island.enemy_director.setup(player, enemy_bullets, island.cleared_packs(), island.pack_survivors())
	if world is DungeonWorld or world is TheoryWorld or world is SpaceWorld:
		world.enemy_director.setup(player, enemy_bullets, [], {})
	if world is IslandWorld and is_instance_valid((world as IslandWorld).launchpad):
		# Offline previews: open, and the shipwright's battleship is free.
		(world as IslandWorld).launchpad.set_state(bool(record.get("astral_unlocked", not Net.is_client())), bool(record.get("ship_owned", false)))
	if Net.is_client():
		Net.client.attach_world(world, enemy_bullets, arrows, player)

	GameServer.set_environment(world)
	loot_bags.show_realm(world.realm_id, world)
	xp_orbs.realm_id = world.realm_id
	player.ground_height = world.ground_height
	player.hazard = world.is_hazard
	player.road = world.is_road
	xp_orbs.ground_height = world.ground_height
	if world is SpatialWorld: fog_of_war.setup(32)
	else: fog_of_war.setup(world.half_extent,world.biome_at,world.ground_height,world.get_meta("prepared_fog",{}))
	world.remove_meta("prepared_fog")
	if world is IslandWorld: fog_of_war.set_strongholds((world as IslandWorld).generator.strongholds)
	var arrive := world.spawn_point
	if world is IslandWorld and stats.home != "":
		var home := (world as IslandWorld).home_point(stats.home)
		if home != Vector3.INF:
			arrive = home  # the town you call home
	if spawn_resolver.is_valid():
		var requested: Vector3 = spawn_resolver.call(world)
		if requested.is_finite(): arrive = requested
	if Net.is_client():  # online, don't all land on the same spot
		var off := Vector2.from_angle(randf() * TAU) * randf_range(0.8, 2.2)
		var spot := arrive + Vector3(off.x, 0.0, off.y)
		if world.is_walkable(spot):
			arrive = Vector3(spot.x, maxf(arrive.y, world.ground_height(spot.x, spot.z)), spot.z)
	_place_player(arrive)
	player.set_spatial_world(world)
	player.facing = PI  # face the camera on arrival
	atmosphere.snap_to(world.biome_at(world.spawn_point))
	hud.set_world(world, fog_of_war)
	hud.picker.enabled = Net.is_client() and Campaigns.is_tavern(world.realm_id)
	hud.quest_banner.place = world.realm_id
	# The Hollow Castle is meant to be seen whole: no fog of war inside it.
	atmosphere.fog_of_war_hidden = world is CastleWorld or world is ChambersWorld or world is SpatialWorld
	campaign.set_world(world)
	hud.toasts.push("Entered %s" % world.display_name, Color(0.75, 0.55, 1.0), 2.5)


func _on_shot(origin: Vector3, direction: Vector3, damage: int, weapon: Item, phase: float,
		mods: Dictionary) -> void:
	GameAudio.weapon_shot(weapon,origin)
	var trail: Variant = stats.effect("trail", "")
	arrows.spawn(origin, direction, damage, weapon, phase, trail if trail == "gold" else "", mods)
	if Net.is_client():
		Net.client.send_shot(origin, direction, weapon, phase, mods)


## Charged shots that end in a burst: Dark Matter collapses into a warp ring,
## Dragonbreath bursts into a ring of fire and leaves flames behind.
func _on_shot_burst(pos: Vector3, burst: String, weapon: Item, hit_object: bool) -> void:
	if hit_object: GameAudio.play("magic_explosion", pos, {cooldown = 0.12})
	var c: Dictionary = weapon.charge
	var blast := Item.new()  # a one-off "spell" describing the ring
	blast.ring = {damage = c.get("ring_damage", 150), range = c.get("ring_range", 6.0), speed = 14.0}
	blast.id = weapon.id
	blast.secondary_effects = weapon.attack_effects(true)
	blast.tier = Item.DIVINE
	blast.shield_tint = weapon.projectile.get("color2", Color.BLACK)
	blast.shield_arcs = weapon.projectile.get("color", Color.WHITE)
	blast.shield_rainbow = 0.1
	blast.warp = 0.12 if burst == "singularity" else 0.06
	var ground := Vector3(pos.x, world.ground_height(pos.x, pos.z), pos.z)
	var ring := MagicRing.cast(world, ground, blast)
	ring.hit.connect(func(_t: Node, _d: int) -> void:
			if not _t is TheorySurface: _heal_from_hit())
	if burst == "inferno":
		var fire := VoxelFire.new(2.0)
		world.add_child(fire)
		fire.global_position = ground
		get_tree().create_timer(2.5).timeout.connect(fire.queue_free)


## A warp ring per pulse (Divine spells can send several, one after another).
func _on_ring_cast(spell: Item) -> void:
	for i in spell.ring.get("pulses", 1):
		var ring := MagicRing.cast(world, player.global_position, spell, i * 0.18, stats.spell_multiplier(spell))
		ring.hit.connect(func(_t: Node, _d: int) -> void: _heal_from_hit())


## Drinking an elixir: the amount floats up over the character.
func _on_consumed(item: Item) -> void:
	GameAudio.play("equip" if item.consumable.has("backpack") else "potion")
	if item.consumable.has("hp"): GameAudio.play("heal",Vector3.INF,{volume_db=-6})
	var origin := player.global_position + Vector3.UP * 2.3
	if item.consumable.has("stat"):
		var stat: String = item.consumable.stat
		FloatingText.spawn(self, origin, "+%d %s" % [item.consumable.amount,
				PlayerStats.STAT_NAMES.get(stat, stat)], UIStyle.MAGIC_LIGHT, true)
		return
	if item.consumable.has("backpack"):
		FloatingText.spawn(self, origin, "Backpack equipped", UIStyle.GOOD, true)
		return
	for key in ["hp", "mp"]:
		if item.consumable.has(key):
			var color := UIStyle.HP_LIGHT if key == "hp" else UIStyle.MAGIC_LIGHT
			FloatingText.spawn(self, origin, "+%d" % item.consumable[key], color, true)


func _on_projectile_hit(_target: Node, _damage: int, _weapon: Item) -> void:
	if not _target is TheorySurface: _heal_from_hit()


## Lifesteal from gear (Blood items): the server heals us for the hit.
func _heal_from_hit() -> void:
	GameServer.report_hit_landed(player.player_id)


func _on_level_up(level: int, gains: Dictionary) -> void:
	GameAudio.play("heal",Vector3.INF,{volume_db=-4})
	LevelUpEffect.play(player)
	hud.toasts.push("Level %d!" % level, Color(1.0, 0.85, 0.4))
	for stat in gains:
		hud.toasts.push("+%d %s" % [gains[stat], PlayerStats.STAT_NAMES[stat]], UIStyle.GOOD, 3.5)


## Offline: the character died for good (the server has already replaced it
## with a fresh one): back to the Tavern. Online deaths come from the server
## (_on_online_death).
func _on_died(player_id: int, items_lost: int) -> void:
	if player_id != player.player_id or Net.is_online():
		return
	GameAudio.shield(false)
	GameAudio.play("player.death", Vector3.INF, {bus = "SFX", priority = 3, fixed_pitch = true})
	hud.toasts.push("You died. Your character is gone, with everything it carried.", UIStyle.HP)
	if items_lost > 0:
		hud.toasts.push("%d items lost. A new adventurer wakes in the Tavern." % items_lost, UIStyle.HP, 3.5)
	travel.call_deferred("hall")


# --- Online ------------------------------------------------------------------------

## Singleplayer: a server of our own on this computer, for this account (it
## plays exactly like any server: the same characters and items). It stops
## by itself when we leave or the game closes.
func _start_singleplayer() -> void:
	if not await _ensure_character():
		return
	menus.show_servers()
	menus.servers.show_joining("Singleplayer")
	player.input_locked = true
	_traveling = true
	var key := await Account.singleplayer_key()
	var port := 24600 + randi() % 300
	var args := PackedStringArray()
	if not OS.has_feature("template"):
		args.append_array(["--headless", "--path", ProjectSettings.globalize_path("res://")])
	else:
		args.append("--headless")
	args.append_array(["--", "--dedicated", "--singleplayer", "--key=" + key,
			"--port=%d" % port, "--parent=%d" % OS.get_process_id(), "--accounts=" + Account.url()])
	if key == "" or OS.create_process(OS.get_executable_path(), args) <= 0:
		_traveling = false
		menus.show_servers("Singleplayer couldn't start.", UIStyle.HP_LIGHT)
		return
	if not await _wait_for_server(port, 40.0):
		_traveling = false
		menus.show_servers("Singleplayer didn't start.", UIStyle.HP_LIGHT)
		Account.problem.emit("Singleplayer didn't start.")
		return
	_traveling = false
	_join_server("127.0.0.1", port)


## Waits until a server answers its status ping (it's starting up).
func _wait_for_server(port: int, timeout: float) -> bool:
	var udp := PacketPeerUDP.new()
	udp.set_dest_address("127.0.0.1", port + Net.STATUS_PORT_OFFSET)
	var until := Time.get_ticks_msec() + int(timeout * 1000.0)
	while Time.get_ticks_msec() < until:
		udp.put_packet("VRPING 1".to_utf8_buffer())
		await get_tree().create_timer(0.25).timeout
		if udp.get_available_packet_count() > 0:
			udp.close()
			return true
	udp.close()
	return false


## The account needs a character to play: make one first if it has none.
func _ensure_character() -> bool:
	if not Account.is_logged_in():
		menus.show_login()
		return false
	if Account.character_id() != 0:
		return true
	var dialog := NewCharacterDialog.new()
	menus.add_dialog(dialog)
	var made := [false]
	dialog.created.connect(func(_id: int) -> void: made[0] = true)
	await dialog.closed
	return made[0]


## Social travel keeps the selected character and waits for its old server to save.
func join_friend(target: Dictionary) -> void:
	if _traveling or _switching or _dead or _connecting or not target.get("joinable", false):
		return
	var session := Account.token()
	var character_id := Account.character_id()
	if Net.is_client():
		_return_offline("Joining %s..." % str(target.username))
	menus.close()
	player.input_locked = true
	_traveling = true
	await transition.fade_in("Joining %s" % str(target.username))
	var released := await Account.wait_for_release(character_id, session)
	_traveling = false
	if not released or Account.token() != session:
		await transition.jump_out()
		menus.show_servers("Your previous server is still saving, or the character is unavailable. Try joining again.", UIStyle.HP_LIGHT)
		return
	Account.choose(character_id)
	social.join_target = "" if target.get("party_invite", false) else str(target.username)
	_join_server(str(target.address), int(target.port))


## A server was picked: connect with our login and the character we play.
func _join_server(address: String, port: int) -> void:
	if _connecting:
		return
	_connecting = true
	menus.servers.show_joining(menus.servers.server_name(address, port))
	if not await _ensure_character():
		_connecting = false
		menus.servers.clear_joining()
		return
	var client := Net.join(address, port, Account.token(), Account.character_id(), Account.username())
	social.attach(client)
	Account.friends()
	client.refused.connect(func(reason: String) -> void:
		Net.leave()
		_connecting = false
		_traveling = false
		menus.show_servers(reason, UIStyle.HP_LIGHT), CONNECT_ONE_SHOT)
	client.welcomed.connect(_on_welcomed, CONNECT_ONE_SHOT)
	client.lost.connect(func(reason: String) -> void: _return_offline(reason, UIStyle.HP_LIGHT))
	client.died.connect(_on_online_death)
	client.switched.connect(_on_switched)
	client.switch_failed.connect(_on_switch_failed)
	client.account_xp.connect(Account.set_total_xp)


## The server took us in: play our character, starting in its Tavern.
func _on_welcomed(info: Dictionary) -> void:
	_connecting = false
	GameServer.adopt(player.player_id, int(info.player_id))
	player.player_id = int(info.player_id)
	Net.client.stats = stats
	Net.client.player = player
	stats.load_data(info.data)
	Account.set_total_xp(int(info.get("account_xp", Account.progress().xp)))
	Account.set_dots(int(info.get("dots", Account.dots())))
	player.collision_mask = Player.TERRAIN_LAYER | Player.OBSTACLE_LAYER \
			| (Player.PLAYER_LAYER if info.get("player_collision", false) else 0)
	menus.close()
	_dead = false
	_traveling = true
	var record: Dictionary = await Net.client.enter("hall")
	await transition.fade_in(place_name("hall"))
	if not await _load_world_async("hall",record): return
	await _arrive()
	social.arrived()
	if not info.get("singleplayer", false):
		hud.toasts.push("Welcome to %s" % info.get("server_name", "the server"), Color(0.75, 0.55, 1.0), 3.0)
		if str(info.get("motd", "")) != "":
			hud.toasts.push(str(info.motd), UIStyle.TEXT_DIM, 4.0)


## The picker (in the Tavern, or after dying): play another character.
func _switch_character(character_id: int) -> void:
	if not Net.is_client() or _switching or _traveling:
		return
	_switching = true
	_traveling = true
	player.input_locked = true
	hud.picker.close_drop()
	hud.visible = false
	var client := Net.client
	if not _args.has("qa-quick"): await transition.jump_in(place_name("hall"))
	if not Net.is_client() or Net.client != client:
		return
	client.switch_character(character_id)


func _new_character() -> void:
	if _creating_character or _switching:
		return
	_creating_character = true
	var dialog := NewCharacterDialog.new()
	hud.add_dialog(dialog)
	var made := [0]
	dialog.created.connect(func(id: int) -> void: made[0] = id)
	await dialog.closed
	_creating_character = false
	if not Net.is_client():
		return
	if made[0] != 0:
		_switch_character(made[0])
	elif _dead:
		_death_choice(_death_record)


## The switch completes under the loading screen; only the Tavern reveals
## the new character. Keep the dead model hidden until the old world is gone.
func _on_switched(character_id: int, class_id: String) -> void:
	Account.choose(character_id)
	Account.refresh()
	var client := Net.client
	var record: Dictionary = await client.enter("hall")
	if not Net.is_client() or Net.client != client:
		return
	if record.has("error"):
		_return_offline(str(record.error), UIStyle.HP_LIGHT)
		return
	if not await _load_world_async("hall",record): return
	_dead = false
	_death_record = {}
	low_health.dead = false
	player.model.visible = true
	await _arrive()
	_switching = false
	hud.toasts.push("Now playing your %s" % PlayerClasses.display_name(class_id), PlayerClasses.get_def(class_id).color, 2.5)


func _on_switch_failed(reason: String) -> void:
	if not _switching:
		return
	hud.visible = true
	if not _args.has("qa-quick"): await transition.jump_out()
	_switching = false
	_traveling = false
	player.input_locked = _dead
	hud.toasts.push(reason, UIStyle.HP_LIGHT, 3.0)
	if _dead:
		_death_choice(_death_record)


## The server says our character died. It's gone for good (the account
## service moved it to the dead table, and the account got its share): its
## record shows, then we pick or make another character and go home.
func _on_online_death(info: Dictionary) -> void:
	if _dead: return
	GameAudio.shield(false)
	GameAudio.play("player.death", Vector3.INF, {bus = "SFX", priority = 3, fixed_pitch = true})
	_dead = true
	player.input_locked = true
	low_health.dead = true
	player.model.visible = false  # its gravestone rises where it stood
	Account.set_total_xp(int(info.get("total_account_xp", Account.progress().xp)))
	var client := Net.client
	var reveal := get_tree().create_timer(1.6)
	await Account.refresh()
	if reveal.time_left > 0.0:
		await reveal.timeout
	if not _dead or not Net.is_client() or Net.client != client:
		return
	var record := info.duplicate()
	record.class = str(info.data.get("class_id", stats.class_id))
	record.id = int(info.character_id)
	_death_record = record
	_death_choice(record)


## The death screen: play another character, or make a new one (backing out
## of either brings the death screen back).
func _death_choice(record: Dictionary) -> void:
	var screen := DeathRecord.new(record, false, "", true)
	hud.add_dialog(screen)
	var choice: String = await screen.chosen
	if not _dead or not Net.is_client():
		return
	if choice == "new":
		_new_character()
		return
	hud.picker.enabled = true
	hud.picker.open()
	await get_tree().process_frame
	while _dead and hud.picker.is_open():
		await get_tree().process_frame
	if _dead and not _switching and not _creating_character:
		_death_choice(record)


## Leaves (or lost) the server: back to the start screen.
func _return_offline(message: String, color := UIStyle.TEXT_DIM) -> void:
	if not Net.is_client():
		return
	var was_singleplayer: bool = Net.client.info.get("singleplayer", false)
	Net.leave()
	_switching = false
	_death_record = {}
	social.reset()
	GameServer.forget_world()
	player.collision_mask = Player.TERRAIN_LAYER | Player.OBSTACLE_LAYER
	_traveling = true
	_dead = false
	_world_generation += 1
	_world_loader.cancel_prepare()
	while _world_loader.is_preparing(): await get_tree().process_frame
	while transition.is_animating(): await get_tree().process_frame
	await transition.fade_in(place_name("hall"))
	if not await _load_world_async("hall"): return
	await _arrive()
	hud.visible = false
	player.input_locked = true
	Account.refresh()
	if was_singleplayer:
		menus.show_start()
	else:
		menus.show_servers(message, color)


## Quit Game: say goodbye to the server first (so it saves at once).
func _quit() -> void:
	if _args.has("campaign-test") or _args.has("party-test") or _args.has("boss-sync-test"):
		print("[qa] quit requested: ", get_stack())
	if Net.is_client():
		Net.leave()
		await get_tree().create_timer(0.3).timeout
	get_tree().quit()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_quit()


## Places the player and requests nearby content. Animated travel waits for
## the bounded build queue under the loader; synchronous preview tools build now.
func _place_player(pos: Vector3) -> void:
	player.place(pos, world.terrain, world.is_walkable)
	if world is IslandWorld:
		(world as IslandWorld).update_streaming(pos,not _async_world_build)


## Pulled to the party in the same world: the same fracture and assembly,
## with nearby chunks prepared under the portal instead of a blocking rebuild.
func _warp(at: Vector3) -> void:
	if _traveling or _dead or not is_instance_valid(world):
		return
	_traveling = true
	player.input_locked = true
	var had_hud := hud.visible
	hud.visible = false
	_async_world_build = true
	world.set_meta("asynchronous_load",true)
	await transition.jump_in(world.display_name)
	_place_player(Vector3(at.x, world.ground_height(at.x, at.z), at.z))
	await _arrive()
	hud.visible = had_hud


## The body of a player (for speech bubbles): ours or one we see online.
func _body_of(player_id: int) -> Node3D:
	if player_id == player.player_id:
		return player
	return Net.client._remote.get(player_id) if Net.is_client() else null


## Names over heads in their colors: you, your party, your friends.
func _color_names() -> void:
	player.status_visuals.nameplate.modulate = SocialClient.SELF_COLOR
	for remote: RemotePlayer in get_tree().get_nodes_in_group("remote_players"):
		remote.status_visuals.nameplate.modulate = social.name_color(remote.status_visuals.player_name)


func _process(delta: float) -> void:
	if not is_instance_valid(world) or _preparing_world:
		if is_instance_valid(world): GameAudio.set_context(player,world)
		return
	if is_instance_valid(player.terrain_viewer): player.terrain_viewer.position = Vector3.ZERO
	var profile_started := Time.get_ticks_usec() if FrameTrace.enabled else 0
	_name_timer -= delta
	if _name_timer <= 0.0:
		_name_timer = 0.5
		_color_names()
	boss_introduction.update(player,world,delta,not _traveling and not _dead and not _args.has("watch-boss"))
	_update_ship_fade()
	if not _traveling:
		GameServer.report_position(player.player_id, world.realm_id, player.global_position)
	if menus.is_open() and not menus.is_game_menu_open():
		player.camera_yaw += delta * 0.08  # the start screen's world turns slowly
	if world is IslandWorld:
		var dock := (world as IslandWorld).surface_ships
		if is_instance_valid(dock):
			dock.local_player = player
			var aboard := SpaceLayout.pocket_at(player.global_position)>=0
			if aboard and is_instance_valid(player.terrain_viewer): player.terrain_viewer.global_position = world.launchpad_center()
			if aboard and not is_instance_valid(player.spatial_controller): player.set_spatial_world(dock)
			elif not aboard and is_instance_valid(player.spatial_controller):
				player.set_spatial_world(world)
				player.global_basis = Basis.IDENTITY
				# Off the ship: stand still until the ground there is built again.
				_place_player(player.global_position)
				player.model.visible = true
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		(world as IslandWorld).update_streaming(player.global_position)
	GameAudio.set_context(player,world)
	var biome := world.biome_at(player.global_position)
	atmosphere.blend_to(biome, delta)
	player.torch_strength = atmosphere.torch_energy()
	fog_of_war.reveal_around(player.global_position)

	# Only the place itself: The Tavern, The Surface, The Space.
	hud.set_location(world.display_name + ("  -  loading..." if player.frozen else ""))
	if FrameTrace.enabled: FrameTrace.record("main_process",profile_started)


func _unhandled_input(event: InputEvent) -> void:
	if menus.is_options_open(): return
	if event.is_action_pressed("nexus"):
		# Escape: straight back to the Tavern from anywhere in a realm.
		if not _traveling and not _dead and not menus.is_open() and not Campaigns.is_tavern(world.realm_id) and not player.frozen:
			get_viewport().set_input_as_handled()
			# In Space too: R goes home (the realm gate brings you back to the same spot).
			if world is SpaceWorld and player.spatial_controller is SpaceTraversal: (player.spatial_controller as SpaceTraversal).recall()
			else: travel("hall")
		return
	if event.is_action_pressed("menu"):
		if _traveling or (menus.is_open() and not menus.is_game_menu_open()): return
		if menus.is_game_menu_open(): menus.close()
		else:
			player.input_locked = true
			menus.show_pause()
		get_viewport().set_input_as_handled()
		return
	if menus.is_open() or not (event is InputEventKey and event.pressed and not event.echo): return
	match event.keycode:
		KEY_F3:
			atmosphere.env.sdfgi_enabled = not atmosphere.env.sdfgi_enabled
			# Space worlds light through the camera's own environment.
			if player.camera.environment: player.camera.environment.sdfgi_enabled = atmosphere.env.sdfgi_enabled
		KEY_F4:
			atmosphere.fog_of_war_hidden = not atmosphere.fog_of_war_hidden
		KEY_F6:
			GameServer.debug_grant_xp(player.player_id, 100)
		KEY_F7:
			if not Net.is_online():
				player.take_damage(25.0)
		KEY_F9:
			if Net.is_online():
				return
			WorldServer.reset_realm("realm_1")
			if world is IslandWorld:
				travel.call_deferred("realm_1")


func _setup_input() -> void:
	AppSettings.install_bindings()


# --- Debug screenshots -----------------------------------------------------------

## --boss=<key>: [boss id, lair pack, stronghold biome]
const BOSS_ARGS := {
	blue = ["blue_dragon", "blue_dragon_lair", Biomes.BLUELAY],
	frost = ["rimeheart_prism", "rimeheart_lair", Biomes.FOSEN],
	lava = ["vharok", "vharok_lair", Biomes.DOOM],
	desert = ["scarab_regent", "scarab_lair", Biomes.DESERT],
	dark = ["hollow_crown", "hollow_crown_lair", Biomes.DEEP_DARK],
}


func _boss_key() -> String:
	var key: String = _args.get("boss", "")
	return key if BOSS_ARGS.has(key) else "blue"


func _parse_args() -> void:
	for arg in OS.get_cmdline_user_args():
		var parts := arg.trim_prefix("--").split("=", true, 1)
		_args[parts[0]] = parts[1] if parts.size() > 1 else ""
	if _args.has("boss-hp"):
		Enemies.get_def(BOSS_ARGS[_boss_key()][0]).hp = int(_args["boss-hp"])
	GameServer.debug_godmode = _args.has("godmode")


func _wait_for_ground() -> void:
	while player.frozen:
		await get_tree().process_frame


func _take_screenshot() -> void:
	await _wait_for_ground()
	if _args.has("biome") and world is IslandWorld:
		var id := Biomes.find(_args.biome)
		_place_player((world as IslandWorld).find_biome_point(id))
		atmosphere.snap_to(Biomes.get_biome(id))
		await _wait_for_ground()
	if _args.has("feature") and world is IslandWorld:
		var p := (world as IslandWorld).find_feature_point(_args.feature)
		_place_player(p)
		atmosphere.snap_to(world.biome_at(p))
		await _wait_for_ground()
	if _args.has("goblins") and world is IslandWorld:
		var island := world as IslandWorld
		var site := island.find_pack_site("goblin_pack", island.find_biome_point(Biomes.WOODS))
		if not site.is_empty():
			var stand: Vector3 = site.pos + Vector3(0, 0, 13)
			_place_player(Vector3(stand.x, world.ground_height(stand.x, stand.z), stand.z))
			await _wait_for_ground()
	if _args.has("boss") and world is IslandWorld:
		var spec: Array = BOSS_ARGS[_boss_key()]
		for fort in (world as IslandWorld).generator.strongholds:
			if fort.biome_id == spec[2]:
				var near := float(_args.get("near", "14"))
				_place_player((world as IslandWorld).generator.surface(Vector2(fort.center) + Vector2(0, near)))
				atmosphere.snap_to(Biomes.get_biome(spec[2]))
				await _wait_for_ground()
				break
	if _args.has("hatch"):
		await get_tree().create_timer(1.5).timeout
		for b in Boss.all:
			if b.is_sealed():
				b._hatch()
	if _args.has("pack") and world is IslandWorld:
		var site := (world as IslandWorld).find_pack_site(_args.pack, player.global_position)
		if not site.is_empty():
			var stand: Vector3 = site.pos + Vector3(0, 0, float(_args.get("near", 13.0)))
			_place_player(Vector3(stand.x, world.ground_height(stand.x, stand.z), stand.z))
			await _wait_for_ground()
	if _args.has("village") and world is IslandWorld:
		for village in (world as IslandWorld).generator.villages:
			if str(village.biome_id) == _args.village or village.display_name.to_lower() == _args.village.to_lower():
				_place_player((world as IslandWorld).generator.surface(Vector2(village.center)))
				await _wait_for_ground()
				break
	if _args.has("stronghold") and world is IslandWorld:
		for fort in (world as IslandWorld).generator.strongholds:
			if str(fort.biome_id) == _args.stronghold:
				_place_player((world as IslandWorld).generator.surface(Vector2(fort.center) + Vector2(0, -14)))
				await _wait_for_ground()
				break
	if _args.has("boss-phase"):
		await get_tree().create_timer(2.0).timeout
		for b in Boss.all:
			b.debug_skip_to(int(_args["boss-phase"]) - 1)
	if _args.has("pos"):
		var p: PackedFloat64Array = _args.pos.split_floats(",")
		_place_player(Vector3(p[0], p[1], p[2]))
		await _wait_for_ground()
	if _args.has("interact") and world is HallWorld:
		for npc in (world as HallWorld).residents:
			if str(npc.spec.role) == _args.interact and npc.spec.stationary:
				var toward := Vector3(2.5, 0, 0) if _args.interact == "smith" else Vector3(-2.5, 0, 0)
				_place_player(npc.global_position + toward)
				await _wait_for_ground()
				hud.interaction.update_prompt(player, false)
				if _args.has("accept-interaction"): hud.interaction.accept()
				break
	if _args.has("closeup"):
		player.set_zoom(5.0)
		player.camera_yaw = deg_to_rad(-30.0)
		player.facing = PI + player.camera_yaw
	if _args.has("zoom"):
		player.set_zoom(float(_args.zoom))
	if _args.has("overview"):
		var review_camera := Camera3D.new()
		review_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		review_camera.size = float(_args.overview)
		add_child(review_camera)
		review_camera.global_position = player.global_position + Vector3(0, 100, 65)
		review_camera.look_at(player.global_position + Vector3.UP * 2)
		review_camera.current = true
	if _args.has("aim"):
		var d: PackedFloat64Array = _args.aim.split_floats(",")
		player.debug_aim = player.global_position + Vector3(d[0], 0, d[1])
	if _args.has("aim-obstacle"):
		var nearest: Obstacle
		for o: Obstacle in world.find_children("", "Obstacle", true, false):
			var d := o.global_position.distance_to(player.global_position)
			if not o.indestructible and d > 4.0 and (nearest == null or d < nearest.global_position.distance_to(player.global_position)):
				nearest = o
		if nearest:
			player.debug_aim = nearest.global_position
	if _args.has("shoot"):
		Input.action_press("shoot")
	if _args.has("nofog"):
		atmosphere.fog_of_war_hidden = true
	if _args.has("shield"):
		Input.action_press("magic")
	if _args.has("stats"):
		hud.toggle_stats()
	if _args.has("ui") and AppSettings.GUI_FACTORS.has(_args.ui):
		AppSettings.video.gui_scale = _args.ui
		AppSettings.gui_changed.emit()
	if _args.has("window"):
		var dimensions: PackedStringArray = _args.window.split(",")
		get_window().size = Vector2i(int(dimensions[0]),int(dimensions[1]))
		await get_tree().process_frame
	if _args.has("options"):
		player.input_locked = true
		menus.show_pause()
		menus.show_options()
		menus.options.tabs.current_tab = 4 if _args.options in ["controls","capture","conflict"] else 2
		if _args.options=="capture": menus.options.begin_capture("shoot")
		if _args.options=="conflict": menus.options._request_binding("shoot",ControlBindings.default_binding("move_forward"))
	if _args.has("tooltip"):
		hud.debug_show_tooltip("weapon")
	if _args.has("equip"):
		for id in _args.equip.split(","):
			for i in stats.backpack.size():
				var item: Item = stats.backpack[i]
				if item and item.id == id:
					GameServer.request_move(player.player_id, {kind = "pack", key = i}, {kind = "gear", key = item.slot})
	if _args.has("inventory"):
		hud.debug_open_inventory()
	if _args.has("destroy-test"):
		await _destroy_test()
	elif _args.has("walk"):
		var xy: PackedFloat64Array = _args.walk.split_floats(",")
		player.debug_input = Vector2(xy[0], xy[1])
		await get_tree().create_timer(float(_args.get("walk-seconds",4.07))).timeout  # ends mid-stride
	elif _args.has("fight"):
		var until := Time.get_ticks_msec() + int(float(_args.fight) * 1000.0)
		while Time.get_ticks_msec() < until:
			var foes := (world as IslandWorld).enemy_director.enemies()
			foes = foes.filter(func(e: Enemy) -> bool:
				return e.state != Enemy.State.SPAWNING and e.state != Enemy.State.BURIED)
			if not foes.is_empty():
				foes.sort_custom(func(a: Enemy, b: Enemy) -> bool:
					return a.global_position.distance_to(player.global_position) < b.global_position.distance_to(player.global_position))
				player.debug_aim = foes[0].global_position
				Input.action_press("shoot")
			await get_tree().create_timer(0.1).timeout
	elif _args.has("charge") or _args.has("charging"):
		await get_tree().create_timer(2.5).timeout
		Input.action_press("charge")
		await get_tree().create_timer(float(_args.get("charge", _args.get("charging")))).timeout
		if _args.has("charge"):
			Input.action_release("charge")
			await get_tree().create_timer(float(_args.get("after", 0.12))).timeout
	elif _args.has("title") or _args.has("menu"):
		await get_tree().create_timer(2.5).timeout
		if _args.has("title"):
			player.input_locked = true
			hud.visible = false
			menus.show_start()
			await Account.refresh()
		else:
			menus.show_pause()
		await get_tree().create_timer(1.0).timeout
	elif _args.has("servers"):
		await get_tree().create_timer(1.0).timeout
		player.input_locked = true
		hud.visible = false
		if _args.has("login"):
			var cred: PackedStringArray = str(_args.login).split(":", true, 1)
			await Account.login(cred[0], cred[1])
		menus.show_servers()
		await get_tree().create_timer(float(_args.get("wait", 6.0))).timeout
	elif _args.has("loading"):
		await get_tree().create_timer(2.5).timeout
		transition.fade_in("The Surface")
		await get_tree().create_timer(1.5).timeout
	elif _args.has("travel"):
		await get_tree().create_timer(2.5).timeout
		var started := Time.get_ticks_msec()
		await travel(_args.travel)
		print("Arrived in %s after %.2f s, input %s" % [world.display_name,
				(Time.get_ticks_msec() - started) / 1000.0, "locked" if player.input_locked else "free"])
		await get_tree().create_timer(0.5).timeout
	elif _args.has("jump"):
		await get_tree().create_timer(3.0).timeout
		transition.jump_in("The Surface")
		await get_tree().create_timer(float(_args.jump)).timeout
	elif _args.has("jump-out"):
		await get_tree().create_timer(2.5).timeout
		await transition.fade_in("Tavern")
		transition.jump_out()
		await get_tree().create_timer(float(_args["jump-out"])).timeout
	elif _args.has("bags"):
		await get_tree().create_timer(2.5).timeout
		var here := player.global_position
		GameServer.spawn_bag(world.realm_id, [Items.make("elixir_hp"), Items.make("elixir_mp")], here)
		GameServer.spawn_bag(world.realm_id, [Items.make("G2_bow"), Items.make("backpack")], here)
		var picks := {green = "G3_cloak", blue = "elixir_of_magic", red = "G5_bow", purple = "G6_cloak",
				white = "D_cloak_theblue"}
		for type in picks:
			var item := Items.make(picks[type])
			GameServer.spawn_bag(world.realm_id, [item], here + Vector3(0, 0, -2.5),
					GameServer.PUBLIC if type == "green" else player.player_id)
		await get_tree().create_timer(1.0).timeout
	elif _args.has("ripple") or _args.has("clash"):
		await get_tree().create_timer(3.0).timeout
		var at := player.global_position + Vector3(float(_args.get("ripple", _args.get("clash"))), 0, 0)
		var dmg := int(_args.get("ripple-damage", 13))
		var reach := 6.0 if _args.has("clash") else 4.5
		EnemyRipple.spawn(enemy_bullets, at, {radius = reach, speed = 6.5, damage_min = dmg, damage_max = dmg},
				Color(0.72, 0.35, 1.0), enemy_bullets.players, [])
		if _args.has("clash"):
			player.cast_ring()
		await get_tree().create_timer(float(_args.get("after", 0.3))).timeout
	elif _args.has("shield-impact"):
		await get_tree().create_timer(2.0).timeout
		var at := player.global_position+Vector3(3,.95,1)
		var toward := (player.global_position+Vector3.UP*.95-at).normalized()
		enemy_bullets.fire(at,toward,{style=_args["shield-impact"],magic=true,speed=12.0,range=12.0,damage_min=30,damage_max=30,color=Color(.25,.8,1),size=1.3})
		await get_tree().create_timer(.2).timeout
	elif _args.has("ring"):
		await get_tree().create_timer(3.4).timeout
		player.cast_ring()
		await get_tree().create_timer(0.3).timeout  # ring halfway out
	elif _args.has("levelup"):
		await get_tree().create_timer(3.4).timeout
		GameServer.debug_grant_xp(player.player_id, stats.xp_to_next())
		await get_tree().create_timer(0.55).timeout  # mid-burst
	else:
		await get_tree().create_timer(float(_args.get("wait", 4.0))).timeout  # let GI and fog settle
	get_viewport().get_texture().get_image().save_png(_args.shot)
	get_tree().quit()


## Walks up to the nearest obstacle, shoots it until it breaks, and returns
## just after, while the debris is flying.
func _destroy_test() -> void:
	var target: Obstacle
	for child in world.find_children("", "Obstacle", true, false):
		if not (child as Obstacle).indestructible and (target == null or child.global_position.distance_to(player.global_position)
				< target.global_position.distance_to(player.global_position)):
			target = child
	if target == null:
		return
	var to := target.global_position - player.global_position
	to.y = 0.0
	var stand := target.global_position - to.normalized() * 5.0
	player.place(Vector3(stand.x, target.global_position.y + 0.5, stand.z), world.terrain, world.is_walkable)
	await _wait_for_ground()
	player.debug_aim = target.global_position
	await get_tree().create_timer(1.0).timeout
	while is_instance_valid(target):
		player.shoot()
		await get_tree().create_timer(DEBUG_FIRE_DELAY).timeout
	await get_tree().create_timer(0.35).timeout


# --- Online test (see the header) ---------------------------------------------------

## --social-test: chat, then the demo campaign alone as party leader: its
## start, Gerald, the Chronicle Gate and the first lily bed. Prints all chat.
func _social_test() -> void:
	social.line_added.connect(func(l: Dictionary) -> void: print("[chat] %s %s: %s" % [l.channel, l.from, l.text]))
	var pause := func(t: float) -> void: await get_tree().create_timer(t).timeout
	var shot := func(file: String) -> void:
		if _args.has("social-shots"):
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(str(_args["social-shots"]) + "/" + file)
	if _args.has("social-shots"):
		var book := CampaignBrowser.new(social)
		hud.add_centered(book)
		hud.social_panel.show_tab("friends")
		await pause.call(1.5)
		await shot.call("layout.png")
		book._open = "lily_thief"
		book._fill()
		await pause.call(0.5)
		await shot.call("book_page.png")
		book.queue_free()
		hud.social_panel.show_tab("")
	social.send_chat("hello from the test")
	social.send_chat("/who")
	social.send_chat("/p nobody hears this")
	await pause.call(1.0)
	social.campaign(["start", "lily_thief", true])
	await pause.call(1.0)
	while _traveling or player.frozen:
		await get_tree().process_frame
	await pause.call(0.5)
	print("[test] arrived in ", world.realm_id, " (", world.display_name, ")")
	print("[test] party: ", social.party.get("leader", "-"), " campaign: ", social.campaign_state().get("title", "-"),
			" cinematic playing: ", campaign.cinematic.is_playing())
	if _args.has("social-shots"):
		for t: float in [2.0, 4.5, 6.0]:
			await pause.call(t)
			await shot.call("intro_%d.png" % int(t * 10))
	campaign.cinematic.cancel()
	_place_player(Vector3(3, 10, 33))
	await pause.call(1.5)
	# Talk to Gerald for real: his speech comes in pages.
	hud.interaction.update_prompt(player, false)
	hud.interaction.accept()
	await pause.call(3.5)
	await shot.call("dialog.png")
	for k in 4:
		hud.interaction.accept()
		await pause.call(0.3)
	await pause.call(1.0)
	print("[test] after Gerald: step ", social.campaign_state().get("step", -1))
	await travel("campaign")
	while _traveling or player.frozen:
		await get_tree().process_frame
	await pause.call(1.0)
	print("[test] in %s (%s), step %s, markers %d" % [world.display_name, world.realm_id,
			social.campaign_state().get("step", -1), campaign.markers().size()])
	if _args.has("social-shots"):
		hud.quest_banner._toggle_details()
		hud.chat.open("/p on my way")
		hud.social_panel.show_tab("party")
		await pause.call(1.0)
		await shot.call("hud.png")
		hud.chat.close()


## --xsocial-test=host|guest (online, two servers): the host invites the
## guest (a friend, on another server) to its party; the guest accepts and
## must land on the host's server, in the party.
func _xsocial_test(role: String) -> void:
	var until := Time.get_ticks_msec() + 120000
	if role == "host":
		while Time.get_ticks_msec() < until:
			Net.client.send_action("chat", ["/invite p3"])
			await get_tree().create_timer(4.0).timeout
			var members: Array = social.party.get("members", [])
			if members.size() >= 2:
				print("[test] host: party has %d members: %s" % [members.size(), members])
				await get_tree().create_timer(5.0).timeout
				await _quit()
				return
		print("[test] host: nobody joined")
		get_tree().quit(20)
		return
	var port := Net.client.port
	print("[test] guest on port %d, waiting for an invite" % port)
	while Time.get_ticks_msec() < until:
		await Account.friends(true)
		if not Account.party_invites.is_empty():
			print("[test] guest: invite ", Account.party_invites[0])
			social.respond_invite(int(Account.party_invites[0].id), true)
			break
		await get_tree().create_timer(2.0).timeout
	while Time.get_ticks_msec() < until:
		await get_tree().create_timer(1.0).timeout
		if Net.client and Net.client.port != port and Net.client.connected and not _traveling:
			await get_tree().create_timer(5.0).timeout
			print("[test] guest: now on port %d in %s, party %s" % [Net.client.port, world.realm_id, social.party.get("members", [])])
			await _quit()
			return
	print("[test] guest: never moved")
	get_tree().quit(21)


## --economy-test (online): the Chambers vault, the forge and /give.
func _economy_test() -> void:
	var client := Net.client
	var wait := func(seconds: float) -> void:
		await get_tree().create_timer(seconds).timeout
		while _traveling or player.frozen: await get_tree().process_frame
	print("[test] dots %d, developer %s" % [Account.dots(), Account.is_developer()])
	await travel("chambers")
	await wait.call(1.5)
	var vault_bags := GameServer.bags_in(world.realm_id, player.player_id).filter(func(b: Dictionary) -> bool: return b.type == "vault")
	print("[test] in %s (%s): %d vault chests" % [world.display_name, world.realm_id, vault_bags.size()])
	if vault_bags.is_empty():
		get_tree().quit(10)
		return
	var first: Dictionary = vault_bags[0]
	client.send_action("chat", ["/give %s G2_bow" % Account.username()])
	await wait.call(1.5)
	var held := stats.backpack.find_custom(func(i: Variant) -> bool: return i != null)
	print("[test] chest 1 holds %s; backpack slot %d" % [first.items.map(func(i: Variant) -> String: return i.id if i else "-"), held])
	# Walk there (the server checks moves are believable).
	var start := player.global_position
	if _args.has("economy-shot"):
		await get_tree().create_timer(2.0).timeout
		get_viewport().get_texture().get_image().save_png(str(_args["economy-shot"]))
	var steps := maxi(40, ceili(start.distance_to(first.pos) / 0.2))
	for k in steps:
		player.global_position = start.lerp(Vector3(first.pos.x, start.y, first.pos.z), (k + 1.0) / steps)
		await get_tree().create_timer(0.05).timeout
	await wait.call(1.0)
	if held >= 0:
		var moving: String = stats.backpack[held].id
		var free: int = first.items.find(null)
		GameServer.request_move(player.player_id, {kind = "pack", key = held}, {kind = "bag", key = free, bag = first.id})
		await wait.call(3.0)
		print("[test] moved %s into the vault: chest now %s" % [moving, GameServer.bag(first.id).items.map(func(i: Variant) -> String: return i.id if i else "-")])
	await travel("hall")
	await wait.call(1.5)
	var forge_place := {}
	for i in stats.backpack.size():
		if Dots.dismantle_value(stats.backpack[i]) > 0:
			forge_place = {kind = "pack", key = i}
			break
	if forge_place.is_empty():
		client.send_action("chat", ["/give %s G5_bow" % Account.username()])
		await wait.call(1.5)
		forge_place = {kind = "pack", key = stats.backpack.find_custom(func(i: Variant) -> bool: return i != null and i.id == "G5_bow")}
	var before := Account.dots()
	var item: Item = stats.item_at(forge_place) if forge_place.key >= 0 else null
	print("[test] dismantling %s (worth %d) at %s" % [item.id if item else "nothing", Dots.dismantle_value(item), forge_place])
	if item:
		client.send_action("forge", [forge_place, item.id])
		await wait.call(3.0)
	print("[test] dots %d -> %d" % [before, Account.dots()])
	await _quit()


func _debug_online() -> void:
	if _args.has("account"):
		Account.set_url(_args.account)
	var login: PackedStringArray = str(_args.get("login", "p2:12345")).split(":", true, 1)
	var r: Dictionary = await Account.login(login[0], login[1])
	if not r.ok:
		print("[test] login failed: ", r.error)
		get_tree().quit(2)
		return
	if Account.characters().is_empty():
		await Account.create_character(str(_args.get("class", "archer")))
	var target: PackedStringArray = str(_args.online).split(":")
	print("[test] logged in as %s, character #%d, joining %s" % [login[0], Account.character_id(), _args.online])
	if str(_args.online) == "singleplayer":
		_start_singleplayer()
	else:
		_join_server(target[0], int(target[1]) if target.size() > 1 else Net.DEFAULT_PORT)
	while Net.client == null:
		await get_tree().process_frame
	var client := Net.client
	var outcome: Array = []
	client.refused.connect(func(reason: String) -> void: outcome.append("refused: " + reason))
	client.welcomed.connect(func(_i: Dictionary) -> void: outcome.append("welcomed"))
	while outcome.is_empty():
		await get_tree().process_frame
	print("[test] ", outcome[0])
	if outcome[0] != "welcomed":
		get_tree().quit(3)
		return
	while _traveling or player.frozen:
		await get_tree().process_frame
	print("[test] in %s at %s, level %d, hp %d/%d" % [world.display_name, player.global_position, stats.level, stats.hp, stats.max_hp])
	print("[test] account level %d (%d xp), playing #%d %s, slots %d/%d" % [Account.progress().level, Account.progress().xp,
			Account.character_id(), stats.class_id, Account.characters().size(), Account.slots()])
	if _args.has("play"):
		return  # Interactive launch: stay in the game instead of taking a test screenshot and quitting.
	if _args.has("campaign-test") or _args.has("boss-sync-test") or _args.has("party-test"):
		var qa := OnlineQA.new()
		qa.main = self
		add_child(qa)
		await qa.run(_args)
		return
	if _args.has("economy-test"):
		await _economy_test()
		return
	if _args.has("space-test"):
		return  # tools/test_space_online.gd drives the session
	if _args.has("xsocial-test"):
		await _xsocial_test(str(_args["xsocial-test"]))
		return
	if _args.has("dungeon-test"):
		await travel("realm_1")
		while _traveling or player.frozen: await get_tree().process_frame
		await get_tree().create_timer(1.0).timeout
		client.send_action("dungeon_test", ["portal"])
		await get_tree().create_timer(1.0).timeout
		for child in world.get_children():
			if child is DungeonPortal and not child.data.get("exit", false):
				hud.interaction.update_prompt(player, false)
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png("/tmp/goblins_cave_online_portal.png")
				print("[test] interacting with ", child.data.id)
				child.target.activate(player)
				break
		await get_tree().create_timer(1.0).timeout
		while _traveling or player.frozen: await get_tree().process_frame
		if not world is DungeonWorld:
			print("[test] ERROR: did not arrive in dungeon")
			get_tree().quit(4)
			return
		print("[test] dungeon arrived: ", world.realm_id, " rooms=", world.layout.rooms.size(), " boss room=", world.layout.boss)
		await get_tree().create_timer(2.0).timeout
		get_viewport().get_texture().get_image().save_png("/tmp/goblins_cave_online_spawn.png")
		client.send_action("dungeon_test", ["boss"])
		await get_tree().create_timer(1.0).timeout
		while _traveling or player.frozen: await get_tree().process_frame
		await get_tree().create_timer(5.0).timeout
		var present := false
		for candidate in Boss.all:
			if candidate.def.id == "goblin_king": present = true
		print("[test] dungeon boss present=", present, " pos=", player.global_position)
		get_viewport().get_texture().get_image().save_png("/tmp/goblins_cave_online_boss.png")
		if not present:
			get_tree().quit(5)
			return
		client.send_action("dungeon_test", ["defeat"])
		await get_tree().create_timer(20.0).timeout
		var boss_exit: DungeonPortal
		for child in world.get_children():
			if child is DungeonPortal and str(child.data.id) != "spawn_exit" and child.data.get("exit", false): boss_exit = child
		print("[test] boss exit present=", is_instance_valid(boss_exit), " bags=", GameServer.bags_in(world.realm_id, player.player_id).size())
		if not is_instance_valid(boss_exit):
			get_tree().quit(6)
			return
		_place_player(boss_exit.global_position)
		while player.frozen: await get_tree().process_frame
		await get_tree().create_timer(1.0).timeout
		boss_exit.target.activate(player)
		await get_tree().create_timer(1.0).timeout
		while _traveling or player.frozen: await get_tree().process_frame
		print("[test] exit returned to ", world.realm_id)
		if world.realm_id != "realm_1":
			get_tree().quit(7)
			return
		await _quit()
		return
	if _args.has("ui-shots"):
		var dir: String = _args["ui-shots"]
		var snap := func(file: String) -> void:
			await get_tree().create_timer(0.8).timeout
			get_viewport().get_texture().get_image().save_png(dir + "/" + file)
		await snap.call("hud.png")
		hud.account_bar.toggle()
		await snap.call("drawer.png")
		hud.account_bar.toggle()
		hud.picker.open()
		await snap.call("picker.png")
		hud.picker._tabs.current_tab = 1
		await get_tree().create_timer(1.5).timeout
		await snap.call("fallen.png")
		hud.picker.close_drop()
		var dialog := NewCharacterDialog.new()
		hud.add_dialog(dialog)
		await snap.call("new_character.png")
		dialog.queue_free()
		var dead: Array = await Account.graveyard()
		if not dead.is_empty():
			var record := DeathRecord.new(dead[0], true, "Close")
			hud.add_dialog(record)
			await snap.call("death_record.png")
			record.queue_free()
	if _args.has("social-test"):
		await _social_test()
	if _args.has("switch-class"):
		var wanted: String = _args["switch-class"]
		var target_id := 0
		for c: Dictionary in Account.characters():
			if c.get("class", "") == wanted:
				target_id = int(c.id)
		if target_id == 0:
			var made: Dictionary = await Account.create_character(wanted)
			target_id = int(made.data.get("id", 0)) if made.ok else 0
			print("[test] created %s #%d: %s" % [wanted, target_id, made.get("error", "ok")])
		if target_id != 0:
			_switch_character(target_id)
			await Net.client.switched
			await get_tree().create_timer(0.5).timeout
			print("[test] switched: class %s, model %s, weapon %s, armor %s, hp %d/%d" % [stats.class_id,
					player.model.get_class() if player.model is ArcherModel else (player.model as ClassModel).class_id,
					stats.gear.weapon.id if stats.gear.weapon else "-", stats.gear.armor.id if stats.gear.armor else "-",
					stats.hp, stats.max_hp])
	if _args.has("realm"):
		await travel("realm_1")
		while _traveling or player.frozen:
			await get_tree().process_frame
		print("[test] in %s (%s)" % [world.display_name, world.realm_id])
		if _args.has("goblins") and world is IslandWorld:
			var island := world as IslandWorld
			var site := island.find_pack_site("goblin_pack", island.find_biome_point(Biomes.WOODS))
			if not site.is_empty():
				var stand: Vector3 = site.pos + Vector3(0, 0, 13)
				_place_player(Vector3(stand.x, world.ground_height(stand.x, stand.z), stand.z))
				await _wait_for_ground()
				print("[test] near goblins at ", player.global_position)
		if _args.has("boss") and world is IslandWorld:
			var spec: Array = BOSS_ARGS[_boss_key()]
			for fort in (world as IslandWorld).generator.strongholds:
				if fort.biome_id == spec[2]:
					_place_player((world as IslandWorld).generator.surface(Vector2(fort.center) + Vector2(0, float(_args.get("near", "12")))))
					await _wait_for_ground()
					print("[test] near the %s stronghold at %s" % [spec[0], player.global_position])
					break
	if _args.has("fight"):
		var until := Time.get_ticks_msec() + int(float(_args.fight) * 1000.0)
		var hits_seen := 0
		while Time.get_ticks_msec() < until and Net.is_client():
			var foes := get_tree().get_nodes_in_group("realm_creatures").filter(func(e: Node) -> bool:
				return e is Enemy and (e as Enemy).mirror and (e as Enemy).is_alive() and e.collision_layer != 0)
			if not foes.is_empty():
				foes.sort_custom(func(a: Node3D, b: Node3D) -> bool:
					return a.global_position.distance_to(player.global_position) < b.global_position.distance_to(player.global_position))
				player.debug_aim = foes[0].global_position
				Input.action_press("shoot")
			else:
				Input.action_release("shoot")
			hits_seen = maxi(hits_seen, foes.size())
			await get_tree().create_timer(0.1).timeout
		Input.action_release("shoot")
		print("[test] fought: most enemies seen at once %d" % hits_seen)
		for b in Boss.all:
			if is_instance_valid(b) and b.mirror:
				print("[test] boss %s: state %d phase %d hp %d/%d shell %d/%d hazards %d" % [b.def.id, b.state, b.phase,
						b.hp, b.max_hp, b.shell_hp, b.shell_max, b.hazards.count()])
	if _args.has("die-now"):  # test: go to the realm and take a lethal hit
		await travel("realm_1")
		while _traveling or player.frozen: await get_tree().process_frame
		await get_tree().create_timer(4.5).timeout  # past the arrival protection
		print("[test] stats before death: level %d, %s" % [stats.level, stats.to_data().get("stats", {})])
		Net.client.send_action("hurt", [999999, 5000.0, true, false, "test"])
		if not _args.has("die-wait"): _args["die-wait"] = "10"
	if _args.has("die-wait"):
		var until := Time.get_ticks_msec() + int(float(_args["die-wait"]) * 1000.0)
		while not _dead and Time.get_ticks_msec() < until:
			await get_tree().create_timer(0.2).timeout
		print("[test] died: %s" % _dead)
		if _dead:
			await get_tree().create_timer(2.5).timeout
			var records := get_tree().root.find_children("", "DeathRecord", true, false)
			print("[test] death record shown: %d, account %d xp" % [records.size(), Account.progress().xp])
			if _args.has("online-shot"):
				get_viewport().get_texture().get_image().save_png(str(_args["online-shot"]).replace(".png", "_death.png"))
			for shown in records:
				(shown as DeathRecord).close()
			await get_tree().create_timer(1.0).timeout
			var next := 0
			for c: Dictionary in Account.characters():
				next = int(c.id)
			if next == 0:
				var made: Dictionary = await Account.create_character("merrow")
				next = int(made.data.get("id", 0))
			_switch_character(next)
			while _dead or _traveling or player.frozen:
				await get_tree().process_frame
			print("[test] back in %s as %s #%d" % [world.display_name, stats.class_id, Account.character_id()])
	await get_tree().create_timer(float(_args.get("online-wait", 3.0))).timeout
	var mirrors := get_tree().get_nodes_in_group("realm_creatures").filter(func(e: Node) -> bool: return e is Enemy and (e as Enemy).mirror)
	print("[test] report: online=%s mirrors=%d remote_players=%d bags=%d hp=%d/%d mp=%d level=%d xp=%d rtt=%d ms" % [
			Net.is_client(), mirrors.size(), get_tree().get_nodes_in_group("remote_players").size(),
			GameServer.bags_in(world.realm_id, player.player_id).size(), stats.hp, stats.max_hp, stats.mp,
			stats.level, stats.xp, roundi(Net.client.rtt * 1000.0) if Net.client else -1])
	for other in get_tree().get_nodes_in_group("remote_players"):
		print("[test] remote player %d layer %d (my mask %d)" % [other.player_id, other.collision_layer, player.collision_mask])
	if _args.has("online-shot"):
		get_viewport().get_texture().get_image().save_png(_args["online-shot"])
	get_tree().quit()


## Fixed screen units keep names and combat text readable at every camera zoom.
func _readable_world_label(node: Node) -> void:
	if node is Label3D:
		node.fixed_size = true
		node.pixel_size = 0.0005
		node.no_depth_test = true
		if node.font == null: node.font = UIStyle.bold()
