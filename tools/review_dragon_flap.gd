extends Node3D
## Offline render of the Blue Dragon's wing beat: rows front / side / top,
## columns idle then through one flap. -- --out=path.png
const STEPS := [0.0, 0.15, 0.35, 0.55, 0.75]

func _ready() -> void:
	var out := "/tmp/dragon_flap.png"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="): out = a.trim_prefix("--out=")
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("#20262e")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("#b8c4d4")
	e.ambient_light_energy = 0.8
	env.environment = e
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, -35, 0)
	add_child(sun)
	var views := [Vector3(0, 180, 0), Vector3(0, 90, 0)]  # front, side (head left)
	for row in views.size():
		for col in STEPS.size():
			var m := CreatureModel.new("blue_dragon")
			var holder := Node3D.new()
			add_child(holder)
			holder.position = Vector3(col * 12.0, -row * 13.0, 0)
			holder.rotation_degrees = Vector3(views[row].x, 0, 0)
			holder.add_child(m)
			m.rotation_degrees.y = views[row].y
			for i in 120: m.animate(0.0, 1.0 / 60.0)  # settle into the stance
			if STEPS[col] > 0.0:
				m.flap()
				for i in int(STEPS[col] * CreatureModel.FLAP_TIME * 60.0): m.animate(0.0, 1.0 / 60.0)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 34.0
	add_child(cam)
	cam.position = Vector3(26, -3, 40)
	cam.look_at(Vector3(26, -3, 0))
	cam.current = true
	await get_tree().create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out)
	get_tree().quit()
