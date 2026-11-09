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
## (the picker top left).
##
## Keys: C toggles the stats tab, Tab (hold) opens the backpack, Escape opens
## the game menu.
const XP_PER_OBSTACLE := 3

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

	add_child(atmosphere)
	player.player_id = GameServer.join()
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
			_offline_ship_transfer = {cups = Leisure.ship_tables(source.realm_id, vessel), wire = vessel.wire().duplicate(true), smoking = vessel.smoking.duplicate(),
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
	else: await transition.jump_in(place_name(destination))
	if original_client!=Net.client or original_generation!=_world_generation: return
	var record := {}
	if Net.is_client():
		record = await Net.client.enter(destination)
		if record.has("error"):
			hud.visible = true
			if _ship_travel: await transition.reveal()
			else: await transition.jump_out()
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
		else: await transition.jump_out()
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
	elif animate: await transition.jump_out()
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
	Leisure.enter_world(world, player, record.get("leisure_state", {}))
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
		# The server supplies the launch pad unlock and ownership state.
		(world as IslandWorld).launchpad.set_state(bool(record.get("astral_unlocked", false)), bool(record.get("ship_owned", false)))
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
	Leisure.forget_player(player_id)
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
	await transition.jump_in(place_name("hall"))
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
	await transition.jump_out()
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
	Leisure.forget_player(player.player_id)
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
	_name_timer -= delta
	if _name_timer <= 0.0:
		_name_timer = 0.5
		_color_names()
	boss_introduction.update(player,world,delta,not _traveling and not _dead)
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


func _setup_input() -> void:
	AppSettings.install_bindings()


## Fixed screen units keep names and combat text readable at every camera zoom.
func _readable_world_label(node: Node) -> void:
	if node is Label3D:
		node.fixed_size = true
		node.pixel_size = 0.0005
		node.no_depth_test = true
		if node.font == null: node.font = UIStyle.bold()
