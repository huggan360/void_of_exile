extends Node3D
## Render the chat and quest badges: -- --out=/tmp/social_visuals.png

const Bubble = preload("res://scripts/ui/speech_bubble.gd")
const Marker = preload("res://scripts/world/quest_marker.gd")


func _ready() -> void:
	var environment := WorldEnvironment.new()
	var sky := Environment.new()
	sky.background_mode = Environment.BG_COLOR
	sky.background_color = Color("141b2c")
	sky.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	sky.ambient_light_color = Color("8aa9cd")
	sky.ambient_light_energy = 0.6
	sky.glow_enabled = true
	environment.environment = sky
	add_child(environment)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 18
	add_child(camera)
	camera.position = Vector3(0, 9, 22)
	camera.look_at(Vector3(0, 2.5, 0))
	camera.current = true
	var canvas := CanvasLayer.new()
	add_child(canvas)
	var title := UIStyle.heading("VOID REALMS  /  SOCIAL VISUALS", 24)
	title.position = Vector2(48, 32)
	canvas.add_child(title)
	var subtitle := UIStyle.label("Screen-space chat  /  emissive pixel quest badges", 16, UIStyle.TEXT_DIM)
	subtitle.position = Vector2(48, 65)
	canvas.add_child(subtitle)
	var messages := ["Meet me by the old gate. Bring a torch!", "Just for you: I found the hidden passage.",
		"Party up! We can face the Deep Dark together.", "A new realm has awakened. Your adventure begins."]
	var kinds := ["say", "tell", "party", "system"]
	var short_messages := ["Hello, traveler!", "Psst... over here.", "Ready when you are!", "Quest completed!"]
	for row in range(2):
		for i in range(4):
			var anchor := _dummy(Vector3(-6 + i * 4, 0, -6 + row * 5), Color("526e8c"))
			Bubble.say(anchor, messages[i] if row == 0 else short_messages[i], kinds[i])
			_caption(anchor.position + Vector3(0, -0.3, 0), kinds[i].to_upper())
	for i in range(3):
		var kind: String = ["main", "side", "turn_in"][i]
		var anchor := _dummy(Vector3(-5 + i * 5, 0, 6), Color("59606f"))
		anchor.add_child(Marker.new(kind))
		_caption(anchor.position + Vector3(0, -0.3, 0), kind.to_upper().replace("_", " "))
	await get_tree().create_timer(1.0).timeout
	if DisplayServer.get_name() == "headless":
		print("Social visuals runtime check passed; screenshot requires a rendering display.")
		get_tree().quit()
		return
	await RenderingServer.frame_post_draw
	var output := "/tmp/social_visuals.png"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			output = argument.trim_prefix("--out=")
	var error := get_viewport().get_texture().get_image().save_png(output)
	if error != OK:
		push_error("Could not save review screenshot: %s" % error_string(error))
	get_tree().quit(error)


func _dummy(at: Vector3, color: Color) -> Node3D:
	var anchor := Node3D.new()
	add_child(anchor)
	anchor.position = at
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	var body := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.65, 1.25, 0.4)
	body.mesh = mesh
	body.material_override = material
	body.position.y = 0.9
	anchor.add_child(body)
	var head := MeshInstance3D.new()
	var head_mesh := BoxMesh.new()
	head_mesh.size = Vector3.ONE * 0.55
	head.mesh = head_mesh
	head.material_override = material
	head.position.y = 1.8
	anchor.add_child(head)
	return anchor


func _caption(at: Vector3, content: String) -> void:
	var label := Label3D.new()
	label.text = content
	label.font = UIStyle.font()
	label.font_size = 32
	label.pixel_size = 0.007
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	add_child(label)
	label.position = at
