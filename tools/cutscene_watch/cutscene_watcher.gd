extends Node
## Preview driver only: plays one of the game's real cutscenes offline, in the
## world it is played in. Never changes their definitions.
## main.tscn -- --watch-cutscene=<key>: any Cutscenes film id (they are all
## picked up automatically), or one of the SHOTS below.
var game: Node3D
var key := "lily_intro"
var _status: Label

## Camera sequences outside Cutscenes. key: [title, where it is played]
const SHOTS := {
	castle_guardians = ["Castle: the knight guardians", "castle"],
	castle_throne = ["Castle: the throne room", "castle"],
	astral_launch = ["Theory of Everything: the launch", "station"],
	nexus_intro = ["The Nexus tour", "space"],
	rocket_surface = ["Orin's rocket to the Surface", "space"],
	launch_intro = ["Game start logo", "menu"],
}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not SHOTS.has(key) and not Cutscenes.has(key): key = "lily_intro"
	_start.call_deferred()

func _title() -> String:
	return str(SHOTS[key][0]) if SHOTS.has(key) else str(Cutscenes.film(key).get("title", key))

func _where() -> String:
	if SHOTS.has(key): return str(SHOTS[key][1])
	var film := Cutscenes.film(key)
	if film.get("astral_station", false): return "station"
	return {tavern = "tavern", surface = "surface", space = "space", castle = "castle"}.get(str(film.get("world", "any")), "surface")

func _start() -> void:
	GameServer.debug_godmode = true
	_overlay()
	_status.text = "Loading %s..." % _title()
	match _where():
		"menu":
			_launch_intro()
			return
		"tavern": game._load_world("hall")
		"surface": game._load_world(_surface("cutscene_watch_surface"))
		"station":
			var id := _surface("cutscene_watch_station")
			WorldServer.get_or_create_realm(id).astral_station = true
			game._load_world(id)
		"space": game._load_world(SpaceWorld.REALM)
		"castle":
			var record := {id = "castle", castle = true}
			var castle: GameWorld = await game._world_loader.prepare("castle", record)
			game._load_world("castle", record, Callable(), castle)
			castle.enemy_director.setup(game.player, game.enemy_bullets, [], {})
	game.menus.hide_all()
	game.player.input_locked = true
	await game._wait_for_ground()
	await get_tree().create_timer(1.0).timeout
	match key:
		"castle_guardians": await _castle_guardians()
		"castle_throne": await _castle_throne()
		"astral_launch": await _astral_launch()
		"nexus_intro": await _traversal().play_intro()
		"rocket_surface": await _rocket_surface()
		_: await _film()
	_finished()

## A fresh Surface realm in the viewer's own save folder.
func _surface(id: String) -> String:
	WorldServer.save_dir = "user://cutscene_watch/"
	WorldServer.reset_realm(id)
	return id

## A Cutscenes film, through the real CampaignClient path (its map, its set).
func _film() -> void:
	var film := Cutscenes.film(key)
	film.world = "any"  # the Lily intro is normally held for a campaign Tavern
	_status.text = ""
	game.campaign._films.append(film)
	while not game.campaign.cinematic.is_playing():
		await get_tree().process_frame
	await game.campaign.cinematic.finished
	await get_tree().create_timer(1.0).timeout

func _castle_guardians() -> void:
	var encounter = game.world.encounter
	game.player.global_position = Vector3(0, 0.15, 14)
	_status.text = ""
	encounter._start_guardians()
	await get_tree().create_timer(4.5).timeout

func _castle_throne() -> void:
	var encounter = game.world.encounter
	encounter.apply_event(["castle", "state", 3])
	game.player.global_position = encounter.DOOR+Vector3(0, 0.15, 4)
	game.stats.give([Items.make("story_throne_key")])
	_status.text = ""
	encounter.on_action({player_id = game.player.player_id, realm = game.world.realm_id, pos = game.player.global_position}, ["door"])
	await get_tree().create_timer(9.5).timeout

## The launch reads a server-clock flight; this one starts now and is driven here.
func _astral_launch() -> void:
	var world: IslandWorld = game.world
	if not is_instance_valid(world.astral_station):
		_status.text = "The launch station did not load."
		return
	game._place_player(world.astral_anchor("boarding"))
	await game._wait_for_ground()
	await get_tree().create_timer(2.0).timeout
	_status.text = ""
	game.campaign.set_process(false)
	var launch: AstralLaunchCinematic = game.campaign.astral_launch
	var camp := {status = "active", astral = {flight = {start = Net.now()+0.5, members = []}}}
	var t := 0.0
	while t < AstralCampaign.FLIGHT_SECONDS+1.5:
		launch.update(camp, world)
		t += get_process_delta_time()
		await get_tree().process_frame
	launch.cancel()
	world.astral_station.update_campaign({})

## The shot from SpaceTraversal.fly_rocket_surface, without the trip after it.
func _rocket_surface() -> void:
	var traversal := _traversal()
	var rocket: SmallRocket = game.world.rocket_node()
	if rocket == null:
		_status.text = "Orin's rocket did not load."
		return
	_status.text = ""
	var start := rocket.global_transform
	traversal.cinematic = true
	game.player.cinematic_locked = true
	game.player.model.visible = false
	traversal._hide_hud(true)
	var shots := SpaceCinematic.new()
	traversal.add_child(shots)
	await shots.rocket_launch(game.player.camera, rocket, "To the Surface")
	shots.queue_free()
	await get_tree().create_timer(1.0).timeout
	rocket.global_transform = start
	rocket.set_flame(0.0)
	game.player.model.visible = true
	traversal._hide_hud(false)
	game.player.cinematic_locked = false
	traversal.cinematic = false

func _traversal() -> SpaceTraversal:
	return game.player.spatial_controller as SpaceTraversal

func _launch_intro() -> void:
	game._set_menu_only(true)
	var intro = preload("res://scripts/ui/launch_intro.gd").new()
	game.add_child(intro)
	game.menus.prepare_startup()
	_status.text = ""
	intro.play(game.menus)
	await intro.finished
	_finished()

func _finished() -> void:
	game.hud.visible = false
	_status.text = "%s  -  finished\nR: replay   Esc: close" % _title()

func _overlay() -> void:
	var layer := ResponsiveUILayer.new()
	layer.layer = 125
	add_child(layer)
	var root := layer.make_ui_root()
	root.theme = UIStyle.theme()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_status = UIStyle.label("", 17, UIStyle.TEXT)
	_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_status.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_status.offset_left = 22
	_status.offset_right = 620
	_status.offset_top = -110
	_status.offset_bottom = -50
	root.add_child(_status)

func _input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo): return
	match event.keycode:
		KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			get_tree().quit()
		KEY_R:
			get_viewport().set_input_as_handled()
			get_tree().reload_current_scene()

func _exit_tree() -> void:
	if is_instance_valid(game) and is_instance_valid(game.player): GameServer.remove_player(game.player.player_id)
