extends "res://scripts/main.gd"
## Offline look at the way between the Surface and Space: the launch pad,
## the launch, rising into Space, the Surface below, descending and landing.
## --shots=<dir>.
func _parse_args() -> void:
	super._parse_args()
	_args.erase("online")
	_args["shot"] = ""
	_args["world"] = "realm"

func _take_screenshot() -> void:
	pass

func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/port_%s.png" % [str(_args.get("shots", "/tmp")), name])
	print("[port] shot ", name)

func _run() -> void:
	while not is_instance_valid(world) or _traveling or player.frozen: await get_tree().process_frame
	var island := world as IslandWorld
	var pad := island.launchpad_center()
	print("[port] pad at ", pad)
	player.global_position = island.launchpad_arrival()
	await get_tree().create_timer(4.0).timeout
	var eye := Camera3D.new()
	add_child(eye)
	eye.global_transform = Transform3D(Basis.IDENTITY, pad+Vector3(38, 26, -46)).looking_at(pad+Vector3(0, 3, 0))
	eye.make_current()
	await get_tree().create_timer(1.0).timeout
	await _shot("pad")
	eye.queue_free()
	player.camera.make_current()
	island.launchpad.set_state(true, true)
	var dock := island.surface_ships
	dock.local_player = player
	var vessel := dock.ensure_ship({player_id = player.player_id, name = "You", peer_id = 0, account_id = 0})
	player.global_position = dock.pocket_point(vessel.slot, dock.interior_anchors.get("spawn", Vector3(0, 0.1, 14)))
	player.set_spatial_world(dock)
	dock.request(["sit", "pilot"])
	dock.request(["takeoff"])
	await get_tree().create_timer(3.0).timeout
	await _shot("launch")
	while not (world is SpaceWorld) or _traveling: await get_tree().process_frame
	await get_tree().create_timer(1.2).timeout
	await _shot("rise")
	await get_tree().create_timer(3.0).timeout
	var space := world as SpaceWorld
	var ship := space.ship_of(player.player_id)
	print("[port] in space, ship ", ship.name if ship else "none", " seat ", ship.seat_of(player.player_id) if ship else "")
	await _shot("helm")
	# Down low over the Surface, then descend.
	ship.xform = Transform3D(ship.xform.basis, Vector3(0, SpaceLayout.DESCEND_HEIGHT-400.0, 0))
	await get_tree().create_timer(1.5).timeout
	await _shot("low")
	space.request(["descend"])
	await get_tree().create_timer(1.5).timeout
	await _shot("dive")
	while not (world is IslandWorld) or _traveling: await get_tree().process_frame
	await get_tree().create_timer(2.0).timeout
	await _shot("landing")
	await get_tree().create_timer(4.0).timeout
	print("[port] back on the Surface at ", player.global_position.distance_to((world as IslandWorld).launchpad_arrival()), " m from the pad arrival")
	await _shot("landed")
	get_tree().quit()

func _ready() -> void:
	super._ready()
	_run.call_deferred()
