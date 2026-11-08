extends "res://scripts/main.gd"
## Look at the shops: offline in Vesperis by a shopkeeper, with a shop state
## exported from the account service (--state=<json>). Saves a speech bubble
## and the open shop panel for a few shops to --shots.
func _parse_args() -> void:
	super._parse_args()
	_args.erase("online")
	_args["play-space"] = ""

func _ready() -> void:
	super._ready()
	_run.call_deferred()

func _shot(name: String) -> void:
	for i in 12: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/shop_%s.png" % [str(_args.get("shots", "/tmp")), name])

func _run() -> void:
	while not (world is SpaceWorld) or player.frozen or not world.is_presentation_ready(): await get_tree().process_frame
	var traversal := player.spatial_controller as SpaceTraversal
	while traversal.cinematic: await get_tree().process_frame
	traversal.camera_mode = SpaceTraversal.CameraMode.FIRST_PERSON
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(str(_args.get("state", ""))))
	if data is Dictionary: Shops.set_state(data)
	var center: Vector3 = CityLayout.planet().center
	for shop: String in ["wizard", "relic", "bowyer"]:
		var v: Dictionary = {}
		for d: Dictionary in CityLayout.DISTRICTS:
			for venue: Dictionary in CityLayout.venues(d):
				if str(venue.get("shop", ""))==shop and v.is_empty(): v = venue
		var frame: Transform3D = v.frame
		var room := Transform3D(frame.basis, center+frame.origin)
		player.global_transform = Transform3D(room.basis, room*Vector3(0, 0.15, 0.5))
		player.up_direction = room.basis.y
		player.camera_yaw = PI
		traversal.look_pitch = 0.05
		(world as SpaceWorld).planets[CityLayout.ID].terrain.ensure_ground(player.global_position)
		await get_tree().create_timer(3.0).timeout
		var keeper: ShopKeeper = null
		for k: ShopKeeper in get_tree().get_nodes_in_group("shop_keepers"):
			if k.shop_id==shop and k.global_position.distance_to(player.global_position)<10.0: keeper = k
		if keeper==null:
			print("[shop] no keeper for ", shop)
			continue
		SpeechBubble.say(keeper, Shops.pitch(shop, 0), "shop", 2.4)
		await get_tree().create_timer(0.6).timeout
		await _shot(shop+"_bubble")
		hud.shop.pinned = true
		hud.shop.open_for(keeper.target, shop)
		var stock := Shops.stock(shop)
		for e: Dictionary in stock:
			if int(e.off)>0 or int(e.left)>0:
				hud.shop._selected = str(e.id)
				break
		hud.shop._mark()
		await _shot(shop+"_panel")
		hud.shop.pinned = false
		hud.shop.close()
	print("[shop] done")
	get_tree().quit()
