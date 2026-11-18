extends Node3D
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func _ready() -> void: run.call_deferred()
func run() -> void:
	GameAudio._disabled = true
	GameServer.set_physics_process(false)
	WorldServer.set_process(false)
	_smoothing()
	var old_mode: int = AppSettings.video.get("space_camera", 0)
	AppSettings.video.space_camera = 1
	var player := Player.new()
	player.stats = PlayerStats.new()
	add_child(player)
	player.add_child(player.aim_marker)
	player.set_physics_process(false)
	player.set_process(false)
	player.frozen = false
	player.camera.make_current()
	var fog := FogOfWar.new()
	add_child(fog)
	var map := Minimap.new()
	map.player = player
	map.fog_of_war = fog
	add_child(map)
	map.set_process(false)
	var count := 0
	for id: String in Dungeons.DEFINITIONS:
		if id == "theory_of_everything": continue
		var definition := Dungeons.definition(id)
		var base := Biomes.get_biome(Dungeons.theme(definition).base)
		var old_fog := base.fog_of_war_enabled
		var world := DungeonWorld.new({id = "dng_camera_test_" + id, dungeon = id, seed = 4217})
		var biome := world.biome_at(world.spawn_point)
		check(biome.fog_of_war_enabled and biome.fog_of_war_opacity == 1.0, "Dungeon always requires exploration: " + id)
		check(base.fog_of_war_enabled == old_fog, "Dungeon does not change its outdoor biome: " + id)
		player.position = world.spawn_point
		player.set_spatial_world(world)
		check(player.ground_view != null and player.spatial_controller == null, "Standard dungeon receives the normal ground camera: " + id)
		check(player.ground_view.camera_mode == 1 and player.ground_view.free_look(), "Dungeon inherits third-person preference: " + id)
		player._update_camera(1.0 / 60)
		check(player.camera.global_position.is_finite() and player.model.visible, "Shoulder camera works in this dungeon: " + id)
		fog.regional = false
		fog.setup(world.half_extent, world.biome_at, world.ground_height)
		fog.set_style(biome.fog_of_war_color, biome.reveal_radius, biome.fog_of_war_opacity)
		check(not fog.explored_at(world.spawn_point) and not fog.explored_at(world.layout.boss), "A fresh dungeon starts unexplored: " + id)
		fog.reveal_around(world.spawn_point)
		fog.reveal_around(world.spawn_point)
		check(fog.explored_at(world.spawn_point) and not fog.explored_at(world.layout.boss), "Entering reveals the spawn but not the distant boss: " + id)
		map.setup(world)
		map.set_process(false)
		check(map._material.get_shader_parameter("explored_tex") == fog.explored_texture(), "Minimap binds the dungeon exploration texture: " + id)
		map.set_expanded(true)
		check(map._material.get_shader_parameter("explored_tex") == fog.explored_texture(), "Expanded map cannot bypass discovery: " + id)
		map.set_expanded(false)
		fog.reveal_at(world.layout.boss)
		check(fog.explored_at(world.layout.boss), "Party discovery can reveal a visited room: " + id)
		player.set_spatial_world(null)
		map.world = null
		world.free()
		count += 1
	check(count == Dungeons.DEFINITIONS.size() - 1, "All standard dungeon definitions are covered")
	await _collision(player)
	var theory := TheoryWorld.new({id = "dng_camera_theory", dungeon = "theory_of_everything", seed = 4217, theory_state = {layout_seed = 4217}})
	player.set_spatial_world(theory)
	player.spatial_controller.set_process(false)
	check(player.ground_view == null and player.spatial_controller is TheoryTraversal, "Theory keeps its own programmed camera controller")
	check(not theory.biome_at(theory.spawn_point).fog_of_war_enabled, "Theory keeps its separate full-3D exploration behavior")
	player.set_spatial_world(null)
	theory.free()
	AppSettings.video.space_camera = old_mode
	map.queue_free()
	fog.queue_free()
	player.queue_free()
	await get_tree().process_frame
	print("DUNGEON CAMERA / EXPLORATION: %d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures else 0)

func _smoothing() -> void:
	var smooth := ShoulderCameraSmoothing.new()
	var offset := Vector3(0.35, 1.05, 4.6)
	var first := smooth.follow(Transform3D(Basis.IDENTITY, offset), Vector3.ZERO, 1.0 / 60)
	check(first.origin.is_equal_approx(offset), "First camera frame snaps to the correct pose")
	var wanted := Transform3D(Basis(Vector3.UP, 0.5), Vector3.RIGHT * 0.2 + Basis(Vector3.UP, 0.5) * offset)
	var eased := smooth.follow(wanted, Vector3.RIGHT * 0.2, 1.0 / 60)
	check(eased.origin.distance_to(wanted.origin) > 0.01, "Third-person follow is slightly eased")
	check(eased.basis.get_rotation_quaternion().angle_to(wanted.basis.get_rotation_quaternion()) > 0.01, "Third-person turn is slightly eased")
	for i in 30: eased = smooth.follow(wanted, Vector3.RIGHT * 0.2, 1.0 / 60)
	check(eased.origin.distance_to(wanted.origin) < 0.001, "Camera promptly catches up without a long cinematic drag")
	var a := ShoulderCameraSmoothing.new()
	var b := ShoulderCameraSmoothing.new()
	for follower in [a, b]: follower.follow(Transform3D(Basis.IDENTITY, offset), Vector3.ZERO, 0)
	var at_a := Transform3D.IDENTITY
	var at_b := Transform3D.IDENTITY
	for i in 12: at_a = a.follow(wanted, Vector3.RIGHT * 0.2, 1.0 / 30)
	for i in 48: at_b = b.follow(wanted, Vector3.RIGHT * 0.2, 1.0 / 120)
	check(at_a.origin.is_equal_approx(at_b.origin) and at_a.basis.is_equal_approx(at_b.basis), "Smoothing matches at 30 and 120 FPS")
	var teleported := Transform3D(Basis.IDENTITY, Vector3(100, 20, 100) + offset)
	check(smooth.follow(teleported, Vector3(100, 20, 100), 1.0 / 60).is_equal_approx(teleported), "Teleports snap instead of sweeping across the map")
	smooth.reset()
	check(smooth.follow(wanted, Vector3.RIGHT * 0.2, 1.0 / 60).is_equal_approx(wanted), "A mode change resets smoothing immediately")

func _collision(player: Player) -> void:
	var world := DungeonWorld.new({id = "dng_wall_test", dungeon = "goblins_cave", seed = 4217})
	player.position = Vector3.ZERO
	player.camera_yaw = 0
	player.set_spatial_world(world)
	player.ground_view.set_process(false)
	var wall := StaticBody3D.new()
	wall.collision_layer = Player.TERRAIN_LAYER
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	shape.shape.size = Vector3(20, 8, 0.4)
	wall.add_child(shape)
	wall.position = Vector3(0, 2, 2)
	add_child(wall)
	await get_tree().physics_frame
	player._update_camera(1.0 / 60)
	check(player.camera.global_position.z < 1.8, "Terrain blocks the eased camera before the wall")
	wall.collision_layer = Player.OBSTACLE_LAYER
	await get_tree().physics_frame
	player.camera_yaw = 0.15
	player._update_camera(1.0 / 60)
	check(player.camera.global_position.z < 1.8, "Dungeon scenery collision also blocks the eased camera")
	wall.free()
	player.set_spatial_world(null)
	world.free()
