extends Node3D
## Actual equipped meshes, lit consistently at four viewing angles.
const OUT := "/home/hugo/tmp/wand_review/"
var view: SubViewport
var world: Node3D
var camera: Camera3D
var pivots: Array[Node3D] = []

func _ready() -> void:
	run.call_deferred()

func run() -> void:
	GameAudio._disabled = true
	GameServer.set_physics_process(false)
	WorldServer.set_process(false)
	DirAccess.make_dir_recursive_absolute(OUT)
	view = SubViewport.new()
	view.size = Vector2i(2400, 1800)
	view.own_world_3d = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(view)
	world = Node3D.new()
	view.add_child(world)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("202532")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color.WHITE
	env.environment.ambient_light_energy = 0.65
	world.add_child(env)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-30, -30, 0)
	world.add_child(light)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 17
	world.add_child(camera)
	camera.look_at_from_position(Vector3(0, 7.3, -32), Vector3(0, 7.3, 0))
	var items: Array[Item] = []
	for item: Item in Items.all():
		if item.slot == "weapon" and "_wand" in item.id:
			items.append(item)
	items.sort_custom(func(a: Item, b: Item) -> bool: return a.id < b.id)
	for i in items.size():
		var item := items[i]
		var root := Node3D.new()
		root.position = Vector3((i % 8 - 3.5) * 2.6, (4 - i / 8) * 3.3, 0)
		world.add_child(root)
		root.rotation.x = -0.2
		pivots.append(root)
		var profile: Dictionary = EquipmentAppearance.profiles()[item.id]
		for suffix: String in (["", "_glow"] if profile.glow else [""]):
			var part := MeshInstance3D.new()
			part.mesh = VoxModel.load_mesh("res://characters/equipment/%s%s.vox" % [item.id, suffix])
			part.material_override = EquipmentAppearance.accent_material() if suffix != "" else VoxModel.material()
			part.scale = Vector3(profile.scale[0], profile.scale[1], profile.scale[2]) * EquipmentAppearance.UNIT
			part.position = Vector3(profile.offset[0], profile.offset[1], profile.offset[2]) * EquipmentAppearance.UNIT
			root.add_child(part)
		var label := Label3D.new()
		label.text = item.item_name
		label.font = UIStyle.bold()
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.font_size = 28
		label.pixel_size = 0.003
		label.position = root.position + Vector3(0, -0.6, 0)
		label.modulate = UIStyle.grade_color(item)
		world.add_child(label)
	for entry: Array in [["front", 0.0], ["back", PI], ["side", PI / 2], ["angled", PI / 4]]:
		for pivot: Node3D in pivots:
			pivot.rotation.y = entry[1]
		await capture("wands_" + entry[0])
	for child in world.get_children():
		if child is Label3D or (child is Node3D and child in pivots):
			child.free()
	pivots.clear()
	view.size = Vector2i(1800, 1000)
	camera.size = 9.5
	camera.look_at_from_position(Vector3(0, 2.8, -20), Vector3(0, 1.2, 0))
	for i in 6:
		var id: String = ["G1_wand", "G8_wand", "D_wand_offrost", "L_wand_silentbell", "L_wand_seedoftomorrow", "A_wand_pocketplanetarium"][i]
		var model := PlayerClasses.make_model(["wizard", "priest", "alchemist"][i % 3])
		model.position = Vector3((i - 2.5) * 2.5, 0, 0)
		world.add_child(model)
		model.set_equipment(Items.make(id), null)
		model.animate(0.0, 0.0)
		pivots.append(model)
	for entry: Array in [["front", -0.4], ["back", PI-0.4]]:
		for model: Node3D in pivots:
			model.rotation.y = entry[1]
		await capture("equipped_" + entry[0])
	get_tree().quit()

func capture(filename: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	view.get_texture().get_image().save_png(OUT + filename + ".png")
	print("Saved " + OUT + filename + ".png")
