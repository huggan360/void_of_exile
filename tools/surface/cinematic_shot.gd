extends "res://scripts/main.gd"
## Cinematic stills of the Surface (offline, no HUD) for release covers.
## godot --path . res://tools/surface/cinematic_shot.tscn -- --shots=<dir> [--count=6] [--window=2560,1440]
## Each still frames a village, stronghold or biome from a low, slow-film angle.

func _parse_args() -> void:
	super._parse_args()
	_args.erase("online")
	_args["shot"] = ""
	_args["world"] = "realm"
	_args["nofog"] = ""

func _take_screenshot() -> void:
	pass  # _run takes its own

func _ready() -> void:
	super._ready()
	_run.call_deferred()

func _run() -> void:
	while not is_instance_valid(world) or _traveling or not world is IslandWorld: await get_tree().process_frame
	var island := world as IslandWorld
	var gen := island.generator
	if _args.has("window"):
		var d: PackedStringArray = str(_args.window).split(",")
		get_window().size = Vector2i(int(d[0]), int(d[1]))
	await get_tree().create_timer(3.0).timeout
	var sites: Array = []
	for v in gen.villages: sites.append(["village", Vector2(v.center)])
	for fort in gen.strongholds: sites.append(["fort", Vector2(fort.center)])
	var rng := RandomNumberGenerator.new()
	rng.seed = int(_args.get("seed", "7"))
	var out := str(_args.get("shots", "/tmp"))
	var first := int(_args.get("first", "0"))
	var angles := int(_args.get("angles", "3"))
	for i in range(first, mini(first + int(_args.get("count", "2")), sites.size())):
		var kind: String = sites[i][0]
		var at: Vector2 = sites[i][1]
		var ground: Vector3 = gen.surface(at)
		for a in angles:
			var angle := rng.randf_range(0.0, TAU)
			var dist := rng.randf_range(26.0, 40.0) if kind == "village" else 50.0
			var eye_xz := at + Vector2(cos(angle), sin(angle)) * dist
			var eye_ground: Vector3 = gen.surface(eye_xz)
			# The player stands behind the camera: streaming centres there and
			# no roof is cut away in frame.
			_place_player(gen.surface(at + Vector2(cos(angle), sin(angle)) * (dist + 6.0)))
			atmosphere.snap_to(world.biome_at(ground))
			await _wait_for_ground()
			await get_tree().create_timer(6.0).timeout
			_hide_ui()
			var eye_pos := Vector3(eye_xz.x, maxf(eye_ground.y, ground.y) + rng.randf_range(5.0, 11.0), eye_xz.y)
			var cam := Camera3D.new()
			add_child(cam)
			cam.global_transform = Transform3D(Basis.IDENTITY, eye_pos).looking_at(ground + Vector3.UP * rng.randf_range(1.0, 5.0))
			cam.fov = 50.0
			cam.far = 900.0
			cam.make_current()
			for f in 45: await get_tree().process_frame
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("%s/surface_%d_%s_%d.png" % [out, i, kind, a])
			print("SHOT ", i, " ", kind, " ", at, " angle ", a)
			cam.queue_free()
	get_tree().quit()

func _hide_ui() -> void:
	for node in [hud, menus]:
		if is_instance_valid(node) and node is CanvasItem: node.visible = false
		elif is_instance_valid(node) and node is CanvasLayer: node.visible = false
	for layer in get_tree().root.find_children("*", "CanvasLayer", true, false):
		(layer as CanvasLayer).visible = false
	for tag in get_tree().root.find_children("*", "Label3D", true, false):
		(tag as Label3D).visible = false
	if is_instance_valid(player): player.visible = false
