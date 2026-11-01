extends Node3D
## Actual realm/cave terrain, no account or network connection.
func _ready() -> void:
	var args := {}
	for arg in OS.get_cmdline_user_args():
		var kv := arg.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else ""
	var cave: bool = args.get("mode", "realm") == "cave"
	var world: GameWorld
	var at: Vector3
	if cave:
		world = DungeonWorld.new(Dungeons.record("dng_review", "goblins_cave", 4217))
		add_child(world)
		at = (world as DungeonWorld).layout.boss if args.get("exit", "spawn") == "boss" else world.spawn_point + Vector3(0, 0, 4)
	else:
		world = IslandWorld.new({id = "realm_review", seed = 4217, destroyed = []})
		add_child(world)
		at = world.spawn_point + Vector3(5, 0, 5)
		at.y = world.ground_height(at.x, at.z)
	var viewer := VoxelViewer.new()
	viewer.view_distance = 80
	viewer.position = at + Vector3(0, 7, 12)
	add_child(viewer)
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("101912") if cave else Color("96bdd2")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("819579") if cave else Color("d7e3ea")
	env.ambient_light_energy = 0.35 if cave else 0.8
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = false
	environment.environment = env
	add_child(environment)
	if not cave:
		var sun := DirectionalLight3D.new()
		sun.rotation_degrees = Vector3(-55, -30, 0)
		sun.shadow_enabled = true
		add_child(sun)
	var portal := DungeonPortal.place(world, {id = "review", pos = at, dungeon = "goblins_cave", exit = cave})
	if cave and args.get("exit", "spawn") == "boss":
		for child in world.get_children():
			if child is DungeonPortal and child != portal: child.free()
	elif cave:
		# The spawn portal already uses this exact effect; show it by itself.
		portal.free()
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 7.0 if cave else 8.5
	camera.position = at + (Vector3(1.8, 2.4, 4.2) if cave else Vector3(3.0, 4.0, 8.5))
	add_child(camera)
	camera.look_at(at + Vector3.UP * 1.5)
	camera.current = true
	await get_tree().create_timer(6.0).timeout
	if args.has("remaining"):
		for child in world.get_children():
			if child is DungeonPortal: child.remaining = float(args.remaining)
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var output: String = args.get("out", "/tmp/dungeon_portal_" + ("cave" if cave else "realm") + ".png")
	get_viewport().get_texture().get_image().save_png(output)
	print("[review] ", output)
	get_tree().quit()
