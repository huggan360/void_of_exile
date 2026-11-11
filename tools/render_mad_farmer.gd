extends Node
## Render actual live rigs and their phase variants for the desktop art sheet.
var output := "/home/hugo/Desktop/Void of Exile Farmer"
const BOSSES := [["mad_farmer", [""]]]
func _ready() -> void: _export.call_deferred()
func _export() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	var selected := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--only="): selected = argument.trim_prefix("--only=")
	for entry in BOSSES:
		if selected!="" and str(entry[0])!=selected: continue
		for form: String in entry[1]:
			var actor := CreatureModel.new(entry[0])
			await _render(actor,str(entry[0])+"_"+("default" if form=="" else form),form)
	print("Boss art images saved to ",output)
	get_tree().quit()
func _render(actor: CreatureModel, filename: String, form: String) -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(720,800)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.msaa_3d = Viewport.MSAA_4X
	add_child(viewport)
	var stage := Node3D.new()
	viewport.add_child(stage)
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color("#17202d")
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color(.7,.8,1)
	settings.ambient_light_energy = .8
	settings.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	settings.glow_enabled = true
	settings.glow_intensity = .35
	environment.environment = settings
	stage.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-40,-28,0)
	light.light_energy = 1.3
	stage.add_child(light)
	stage.add_child(actor)
	if form!="": actor.set_variant(form)
	actor.animate(0,0)
	var bounds := AABB()
	var first := true
	for mesh: MeshInstance3D in actor.find_children("*","MeshInstance3D",true,false):
		if mesh.mesh==null or not mesh.is_visible_in_tree(): continue
		var box: AABB = mesh.global_transform*mesh.mesh.get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
	var center := bounds.get_center()
	var camera := Camera3D.new()
	stage.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.position = center+Vector3(10,7,-24)
	camera.look_at(center)
	# Frame in camera space so every wing and crown fits without arbitrary crops.
	var camera_bounds := camera.global_transform.affine_inverse()*bounds
	camera.size = maxf(camera_bounds.size.y,camera_bounds.size.x/(720.0/800.0))*1.16
	camera.current = true
	for frame in 5: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png(output+"/"+filename+".png")
	viewport.queue_free()
	await get_tree().process_frame
