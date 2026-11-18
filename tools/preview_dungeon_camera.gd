extends "res://scripts/main.gd"
## Actual offline dungeon camera and discovery-map captures, no accounts.
func _parse_args() -> void:
	super._parse_args()
	_args.erase("online")
	_args["play-dungeon"] = str(_args.get("preview-dungeon", "saltbone_wreck"))
	_args["qa-quick"] = ""
	AppSettings.video.space_camera = 1
func _ready() -> void:
	super._ready()
	_capture.call_deferred()
func _capture() -> void:
	while not is_instance_valid(world) or not world is DungeonWorld or player.frozen or _traveling:
		await get_tree().process_frame
	while not world.is_presentation_ready(): await get_tree().process_frame
	player.input_locked = true
	for i in 40: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/home/hugo/tmp/dungeon_third_person.png")
	player.ground_view.camera_mode = 0
	for i in 12: await get_tree().process_frame
	hud.toggle_map()
	for i in 60: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/home/hugo/tmp/dungeon_exploration_map.png")
	print("DUNGEON CAMERA PREVIEW: third person and explored-only map captured")
	get_tree().quit()
