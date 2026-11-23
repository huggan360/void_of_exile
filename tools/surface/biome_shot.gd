extends "res://scripts/main.gd"
## Gameplay-angle stills of chosen Surface spots (offline, no HUD), for biome art reviews.
## godot --path . res://tools/surface/biome_shot.tscn -- --points=x,z;x,z --shots=<dir> [--tag=name]
##     [--window=1600,900] [--height=16] [--back=13] [--wide]   (--wide: a higher, longer view)

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
	var gen := (world as IslandWorld).generator
	if _args.has("window"):
		var d: PackedStringArray = str(_args.window).split(",")
		get_window().size = Vector2i(int(d[0]), int(d[1]))
	await get_tree().create_timer(3.0).timeout
	var out := str(_args.get("shots", "/home/hugo/godot/tmp/biome_shots"))
	DirAccess.make_dir_recursive_absolute(out)
	var tag := str(_args.get("tag", "shot"))
	var wide := _args.has("wide")
	var height := float(_args.get("height", "34" if wide else "16"))
	var back := float(_args.get("back", "40" if wide else "13"))
	var points: PackedStringArray = str(_args.get("points", "0,0")).split(";", false)
	for i in points.size():
		var xz: PackedStringArray = points[i].split(",")
		var at := Vector2(float(xz[0]), float(xz[1]))
		var ground: Vector3 = gen.surface(at)
		_place_player(ground)
		atmosphere.snap_to(world.biome_at(ground))
		await _wait_for_ground()
		await get_tree().create_timer(6.0).timeout
		_hide_ui()
		var cam := Camera3D.new()
		add_child(cam)
		cam.global_transform = Transform3D(Basis.IDENTITY, ground + Vector3(0, height, back)).looking_at(ground + Vector3.UP)
		cam.fov = 55.0
		cam.far = 900.0
		cam.make_current()
		for f in 45: await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/%s_%d.png" % [out, tag, i])
		print("SHOT ", tag, " ", i, " ", at)
		cam.queue_free()
	get_tree().quit()

func _hide_ui() -> void:
	for layer in get_tree().root.find_children("*", "CanvasLayer", true, false):
		(layer as CanvasLayer).visible = false
	for tag3d in get_tree().root.find_children("*", "Label3D", true, false):
		(tag3d as Label3D).visible = false
	if is_instance_valid(player): player.visible = false
