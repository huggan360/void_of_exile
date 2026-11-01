extends Node3D
func _ready() -> void:
	var env := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color("#202832")
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("#c0d3df")
	settings.ambient_light_energy = 0.65
	env.environment = settings
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -30, 0)
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	add_child(sun)
	var index := 0
	for theme in ["woodland", "fosen", "desert"]:
		var building := VillageHouse.new().setup({asset = "res://props/houses/" + theme + "_0", pos = Vector3((index - 1) * 11, 0, 0), solid_size = Vector3(8.5, 6, 8.5)})
		add_child(building)
		index += 1
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 21
	camera.position = Vector3(13, 17, -30)
	add_child(camera)
	camera.look_at(Vector3(0, 4, 0))
	camera.current = true
	await get_tree().create_timer(2).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://docs/realm_expansion/log_houses_engine.png")
	get_tree().quit()
