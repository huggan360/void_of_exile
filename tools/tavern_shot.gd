extends "res://scripts/main.gd"
## Overhead views of the Tavern (offline) for placing things: --shots=<dir>.
## --at=x,z centre (default the fountain-to-chapel avenue), --height=m.
func _parse_args() -> void:
	super._parse_args()
	_args.erase("online")
	if _args.has("space"): _args["play-space"] = ""  # the Nexus instead
	else: _args["shot"] = ""  # straight into the Tavern, offline

func _take_screenshot() -> void:
	pass  # _run takes its own

func _ready() -> void:
	super._ready()
	_run.call_deferred()

func _run() -> void:
	while not is_instance_valid(world) or _traveling or player.frozen: await get_tree().process_frame
	await get_tree().create_timer(4.0).timeout
	var at := Vector3(4, 10, 46) if not _args.has("space") else Vector3(27, 0, -15)
	if _args.has("at"):
		var p := str(_args.at).split(",")
		at = Vector3(float(p[0]), at.y, float(p[1]))
	var eye := Camera3D.new()
	add_child(eye)
	eye.global_transform = Transform3D(Basis.IDENTITY, at+Vector3(0, float(_args.get("height", "95")), 0.01)).looking_at(at, Vector3.FORWARD)
	if _args.has("eye"):  # --eye=x,y,z: a view from there toward the centre
		var e := str(_args.eye).split(",")
		eye.global_transform = Transform3D(Basis.IDENTITY, Vector3(float(e[0]), float(e[1]), float(e[2]))).looking_at(at+Vector3.UP*2.0)
	eye.fov = 60.0
	eye.make_current()
	player.global_position = at+Vector3(0, 0, -60)
	for i in 30: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [str(_args.get("shots", "/tmp")), str(_args.get("name", "tavern_top"))])
	get_tree().quit()
