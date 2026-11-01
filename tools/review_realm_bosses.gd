extends Node3D
## Offline review render of the live boss models: -- --set=eggs|bosses|minions --out=path.png
func _ready() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else ""
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("#20262e")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("#b8c4d4")
	e.ambient_light_energy = 0.7
	e.glow_enabled = true
	env.environment = e
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, -35, 0)
	sun.shadow_enabled = true
	add_child(sun)
	var rows: Array = {
		eggs = [["egg_blue_dragon", ""], ["egg_blue_dragon", "crack3"], ["egg_rimeheart", ""], ["egg_rimeheart", "crack3"], ["egg_vharok", ""], ["egg_vharok", "crack2"], ["egg_scarab", ""], ["egg_scarab", "crack3"], ["egg_hollow_crown", ""], ["egg_hollow_crown", "crack3"]],
		frost = [["rimeheart_prism", ""], ["rimeheart_prism", "conduit"], ["rimeheart_prism", "tempest"], ["rimeheart_conduit", ""], ["rimeheart_shardling", ""]],
		demon = [["vharok_cinder_tyrant", ""], ["vharok_cinder_tyrant", "infernal"], ["vharok_cinder_tyrant", "heart_unbound"], ["cinder_sentinel", ""]],
		scarab = [["aureate_scarab_regent", ""], ["aureate_scarab_regent", "sunwings"], ["aureate_scarab_regent", "sunheart"], ["dawn_scarab", ""]],
		wraith = [["hollow_crown", ""], ["hollow_crown", "fractured_court"], ["hollow_crown", "unbound"], ["mirror_shade", ""]],
	}[args.get("set", "eggs")]
	var x := 0.0
	var spacing := float(args.get("spacing", "9"))
	for r in rows:
		var m := CreatureModel.new(r[0])
		add_child(m)
		m.position = Vector3(x, 0, 0)
		m.rotation.y = deg_to_rad(float(args.get("yaw", "20")))
		m.set_variant(r[1])
		x += spacing
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = float(args.get("size", "16"))
	add_child(cam)
	cam.position = Vector3((x - spacing) * 0.5, 9, 30)
	cam.look_at(Vector3((x - spacing) * 0.5, 3.5, 0))
	cam.current = true
	await get_tree().create_timer(1.0).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(args.get("out", "/tmp/out.png"))
	get_tree().quit()
