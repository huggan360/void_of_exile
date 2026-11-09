extends "res://scripts/main.gd"
## Walk the docked ship's central aisle through the real player controller.
func _parse_args() -> void:
	super._parse_args()
	_args.erase("online")
	_args["shot"] = ""
	_args["world"] = "realm"

func _take_screenshot() -> void: pass

func _ready() -> void:
	super._ready()
	_run.call_deferred()

func _run() -> void:
	while not is_instance_valid(world) or _traveling or player.frozen:
		await get_tree().process_frame
	var dock := (world as IslandWorld).surface_ships
	dock.local_player = player
	var ship := dock.ensure_ship({player_id = player.player_id, name = "Walker", peer_id = 0, account_id = 0})
	var original_margin := player.safe_margin
	player.global_position = (world as IslandWorld).launchpad_arrival()
	dock.request(["board", ship.id])
	await get_tree().create_timer(0.5).timeout
	player.camera_yaw = 0.0
	var start := player.global_position
	player.debug_input = Vector2(0, -1)
	for i in 240: await get_tree().physics_frame
	player.debug_input = Vector2.ZERO
	var distance := start.z-player.global_position.z
	var passed := distance>17.0 and SpaceLayout.pocket_at(player.global_position)==ship.slot
	print("[surface-walk] ", "PASS" if passed else "FAIL", " continuous aisle walking: ", distance, " m")
	start = player.global_position
	player.debug_input = Vector2(-1, 0)
	for i in 30: await get_tree().physics_frame
	player.debug_input = Vector2.ZERO
	var sideways := start.x-player.global_position.x
	passed = passed and sideways>2.0
	print("[surface-walk] sideways=", sideways, " m")
	player.set_spatial_world(world)
	passed = passed and is_equal_approx(player.safe_margin, original_margin)
	print("[surface-walk] margin restored=", player.safe_margin, " result=", "PASS" if passed else "FAIL")
	get_tree().quit(0 if passed else 1)
