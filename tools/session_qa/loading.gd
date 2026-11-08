extends "res://scripts/main.gd"
func _parse_args() -> void:
	super._parse_args()
	_args["online-wait"] = "1000"
func _ready() -> void:
	super._ready()
	_run.call_deferred()
func _wait_ready(seconds: float) -> bool:
	var until := Time.get_ticks_msec()+int(seconds*1000.0)
	while Time.get_ticks_msec()<until:
		if is_instance_valid(world) and not _traveling and not player.frozen and Net.is_client() and Net.client.connected: return true
		await get_tree().process_frame
	return false
func _run() -> void:
	if not await _wait_ready(60.0):
		print("[loading-qa] FAIL initial connection")
		get_tree().quit(1)
		return
	var monitor := Timer.new()
	monitor.wait_time = 3.0
	add_child(monitor)
	monitor.timeout.connect(func() -> void:
		print("[loading-qa] world=", world.realm_id, " travel=", _traveling, " preparing=", _preparing_world, " frozen=", player.frozen,
			" ready=", world.is_presentation_ready(), " mode=", world.process_mode, " steps=", world._load_steps.size(),
			" pos=", player.global_position, " viewer=", player.terrain_viewer.global_position,
			" queue=", world._queue.size() if world is IslandWorld else -1))
	monitor.start()
	travel("realm_1")
	var ok := await _wait_ready(120.0)
	monitor.stop()
	print("[loading-qa] ", "PASS Realm 1 loads and releases the player" if ok and world is IslandWorld else "FAIL stuck loading")
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("/home/hugo/godot/tmp/session_qa/shots/realm_loading.png")
	get_tree().quit(0 if ok else 1)
