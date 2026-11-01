extends Node3D
## Offline review: -- --mode=layout|cast --seed=4217 --out=/tmp/cave.png
func _ready() -> void:
	var args := {}
	for arg in OS.get_cmdline_user_args():
		var kv := arg.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else ""
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("202b29")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("b8ccb0")
	env.ambient_light_energy = 0.8
	env.glow_enabled = true
	environment.environment = env
	add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-65, -25, 0)
	light.shadow_enabled = true
	add_child(light)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	add_child(camera)
	camera.current = true
	var mode: String = args.get("mode", "layout")
	if mode == "layout":
		var world := DungeonWorld.new(Dungeons.record("dng_preview", str(args.get("dungeon", "goblins_cave")), int(args.get("seed", "4217"))))
		add_child(world)
		var viewer := VoxelViewer.new()
		viewer.view_distance = 250
		viewer.position = Vector3(0, 15, 0)
		add_child(viewer)
		camera.size = 155
		camera.position = Vector3(0, 180, 65)
		camera.look_at(Vector3.ZERO)
		for entry in [{pos = world.layout.spawn, color = Color("69bfff")}, {pos = world.layout.boss, color = Color("ffd24e")}]:
			var marker := MeshInstance3D.new()
			var mesh := CylinderMesh.new()
			mesh.top_radius = 2.0
			mesh.bottom_radius = 2.0
			mesh.height = 1.0
			marker.mesh = mesh
			var mat := StandardMaterial3D.new()
			mat.albedo_color = entry.color
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			marker.material_override = mat
			marker.position = entry.pos + Vector3.UP
			add_child(marker)
	else:
		var ids := ["goblin_king", "cave_slinger", "moss_bat", "mushroom_crawler", "goblin_brute", "cave_shaman", "goblin_warlord", "goblin_treasure"]
		var x := -14.0
		for id: String in ids:
			var model := CreatureModel.new(id)
			model.position = Vector3(x, 0, 0)
			model.rotation.y = PI - 0.2
			add_child(model)
			x += 5 if id == "goblin_king" else 3.8
		var world := GameWorld.new()
		add_child(world)
		DungeonPortal.place(world, {id = "review", pos = Vector3(18, 0, 0), dungeon = "goblins_cave"})
		camera.size = 24
		camera.position = Vector3(1, 12, 30)
		camera.look_at(Vector3(1, 1.5, 0))
	await get_tree().create_timer(5.0).timeout
	if DisplayServer.get_name() == "headless":
		print("[review] headless dungeon preview loaded")
		get_tree().quit()
		return
	await RenderingServer.frame_post_draw
	var output: String = args.get("out", "/tmp/goblins_cave_" + mode + ".png")
	get_viewport().get_texture().get_image().save_png(output)
	print("[review] ", output)
	get_tree().quit()
