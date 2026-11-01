extends Node3D
## Which way each wing axis turns the Blue Dragon's wings (side and front).
const TESTS := [Vector3.ZERO, Vector3(0.6, 0, 0), Vector3(0, 0.6, 0), Vector3(0, 0, 0.6)]

func _ready() -> void:
	var out := "/tmp/wing_axes.png"
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
	for row in 2:
		for col in TESTS.size():
			var m := CreatureModel.new("blue_dragon")
			add_child(m)
			m.position = Vector3(col * 12.0, -row * 12.0, 0)
			m.rotation_degrees.y = 90.0 if row == 0 else 180.0
			m.animate(0.0, 0.0)
			for move in m._moves:
				if move.role == "wing":
					var side := -1.0 if move.node.position.x < 0.0 else 1.0
					var r: Vector3 = TESTS[col]
					move.node.rotation = Vector3(r.x, r.y * side, r.z * side)
				elif move.role == "sway":
					move.node.rotation = Vector3.ZERO
			m._rig.rotation = Vector3.ZERO
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 26.0
	add_child(cam)
	cam.position = Vector3(18, -2, 40)
	cam.look_at(Vector3(18, -2, 0))
	cam.current = true
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out)
	get_tree().quit()
