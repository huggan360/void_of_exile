extends Node
## Render the real projectile meshes and export real flight samples for review.
const OUT := "/home/hugo/tmp/legendary_review"
var view: SubViewport
var stage: Node3D
var camera: Camera3D
var arrows := Arrows.new()

func _ready() -> void: run.call_deferred()

func run() -> void:
	GameAudio._disabled = true
	GameServer.set_physics_process(false)
	WorldServer.set_process(false)
	DirAccess.make_dir_recursive_absolute(OUT)
	view = SubViewport.new()
	view.size = Vector2i(260, 180)
	view.own_world_3d = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(view)
	stage = Node3D.new()
	view.add_child(stage)
	stage.add_child(arrows)
	arrows.set_physics_process(false)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("111925")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("e6ebff")
	env.environment.ambient_light_energy = 0.8
	env.environment.glow_enabled = true
	env.environment.glow_intensity = 0.65
	stage.add_child(env)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-40, -30, 0)
	stage.add_child(light)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 1.45
	stage.add_child(camera)
	camera.look_at_from_position(Vector3(1.1, 0.85, 1.5), Vector3.ZERO)
	var data := []
	for row: Dictionary in SignatureItems.definitions():
		if row.rarity != "L" or row.slot != "weapon": continue
		var weapon := Items.make(row.id)
		var object := Node3D.new()
		stage.add_child(object)
		var meshes := arrows._meshes_for(weapon, str(weapon.projectile.style))
		for i in 2:
			if meshes[i] == null: continue
			var mi := MeshInstance3D.new()
			mi.mesh = meshes[i]
			mi.material_override = VoxModel.shot_material(i == 1)
			object.add_child(mi)
		await get_tree().process_frame
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		view.get_texture().get_image().save_png(OUT.path_join(weapon.id + ".png"))
		object.queue_free()
		var primary := SignaturePatterns.primary(Vector3.FORWARD, Vector3.UP, weapon)
		var charged := SignaturePatterns.charged(Vector3.FORWARD, Vector3.UP, weapon, 2.7)
		if charged.is_empty():
			charged = [{direction = Vector3.FORWARD, share = 2.6, phase = 0.0,
				mods = {secondary = true, speed = 1.4, size = 1.9, range = 1.3}}]
		data.append({id = weapon.id, name = weapon.item_name, kind = weapon.kind,
			primary = samples(weapon, primary), charged = samples(weapon, charged),
			description = row.projectile.description, charged_description = row.charge.description,
			charge_name = row.charge.name, colors = row.colors})
	var file := FileAccess.open(OUT.path_join("paths.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()
	print("LEGENDARY REVIEW: %d actual meshes and both firing patterns exported to %s" % [data.size(), OUT])
	get_tree().quit()

func samples(weapon: Item, entries: Array) -> Array:
	var result := []
	for entry: Dictionary in entries:
		var mods: Dictionary = entry.mods
		arrows.spawn(Vector3.ZERO, entry.direction, 0, weapon, entry.phase, "", mods)
		var shot: Dictionary = arrows._shots.back()
		var points := []
		for n in 81:
			var at := arrows._position_at(shot, float(shot.range) * n / 80.0)
			points.append([at.x, at.y, at.z])
		result.append({points = points, delay = mods.get("delay", 0), speed = shot.speed})
	arrows.clear()
	return result
