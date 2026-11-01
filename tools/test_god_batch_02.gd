extends "res://tools/test_realm_integration.gd"
const GODS := ["basalt_bulwark", "furnace_maw", "cinder_oracle", "rime_stag", "glacier_hermit", "hail_harrier"]
const LESSER := ["ember_mite", "rime_skitter", "snow_wisp"]
class WallWorld:
	extends GameWorld
	var blocked_all := false
	func ground_height(_x: float, _z: float) -> float:
		return 0.0
	func enemy_spawn_clear(pos: Vector3, radius: float, height: float) -> bool:
		return not blocked_all and super.enemy_spawn_clear(pos, radius, height)
class GeneratedWorld:
	extends GameWorld
	var generator := IslandGenerator.new(20261031)
	func ground_height(x: float, z: float) -> float:
		return generator.column(floori(x), floori(z)).x + 1.0
	func biome_at(pos: Vector3) -> BiomeDef:
		return Biomes.get_biome(generator.column(floori(pos.x), floori(pos.z)).y)
	func is_walkable(pos: Vector3) -> bool:
		return generator.column(floori(pos.x), floori(pos.z)).x >= IslandGenerator.SEA_LEVEL
	func enemy_spawn_clear(pos: Vector3, radius: float, height: float) -> bool:
		return generator.enemy_spawn_clear(pos, radius, height) and super.enemy_spawn_clear(pos, radius, height)

func _test_spawns() -> void:
	super._test_spawns()
	var rng := RandomNumberGenerator.new()
	rng.seed = 3339
	var bullets := EnemyBullets.new()
	for id: String in GODS + LESSER:
		var def := Enemies.get_def(id)
		CreatureModel.preload_creature(def.model)
		expect(def.is_god == (id in GODS), "Correct god/follower classification: " + id)
		for attack in def.attacks:
			expect(bullets._mesh_for(attack) != null, "Authored projectile loads: " + id)
		if id in GODS:
			expect(Enemies.pack(id + "_pack").respawn_time < 0, "New god and followers remain finite")
			expect(def.attacks[0].damage_min >= 155, "God damage remains meaningful")
	bullets.free()
	for biome_id in [Biomes.DOOM, Biomes.FOSEN]:
		var biome := Biomes.get_biome(biome_id)
		expect(biome.god_stats == (["attack", "defense"] if biome_id == Biomes.DOOM else ["magic", "dexterity"]), "Two intended biome potion stats")
		var seen := {}
		for n in 400:
			var potion := Loot._make({biome_stat = true}, rng, biome.god_stats)
			seen[potion.consumable.stat] = true
			expect(potion.bag_type() == "blue" and potion.consumable.stat in biome.god_stats, "Correct blue potion family")
		expect(seen.size() == 2, "Both biome stats actually roll")

func _test_persistence_and_models() -> void:
	await super._test_persistence_and_models()
	var world := WallWorld.new()
	get_tree().root.add_child(world)
	var wall := StaticBody3D.new()
	wall.collision_layer = Player.OBSTACLE_LAYER
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(4, 4, 4)
	shape.shape = box
	wall.position = Vector3(0, 2, 0)
	wall.add_child(shape)
	world.add_child(wall)
	await get_tree().physics_frame
	var director := EnemyDirector.new()
	director.world = world
	world.add_child(director)
	director.set_process(false)
	director.realm_id = "batch02_runtime_fixture"
	for n in GODS.size():
		var id: String = GODS[n]
		var runtime_site := {id = "runtime_" + id, pack = id + "_pack", pos = Vector3(50 + n * 10, 0, 0), seed = 303 + n}
		director._wake(runtime_site, null)
		expect(director._awake.has(runtime_site.id), "New god pack instantiates: " + id)
		if director._awake.has(runtime_site.id):
			var live: EnemyPack = director._awake[runtime_site.id]
			for member in live.members:
				member.set_physics_process(false)
				member.model.animate(0.5, 0.1)
				member.model.play_attack(0.7)
				member.model.strike()
				member.model.flap()
	var def := Enemies.get_def("basalt_bulwark")
	expect(not world.enemy_spawn_clear(Vector3.ZERO, def.hit_radius, def.body_height), "Solid obstacle blocks enemy spawn")
	var spot := director.find_spawn_position(Vector3.ZERO, def)
	expect(not spot.is_empty() and world.enemy_spawn_clear(spot.pos, def.hit_radius, def.body_height), "Spawn search relocates outside the solid wall")
	world.blocked_all = true
	var site := {id = "blocked_fixture", pack = "rime_stag_pack", pos = Vector3.ZERO, seed = 2}
	director._wake(site, ["rime_stag", "rime_skitter"])
	expect(not director._awake.has(site.id), "No actor appears when all candidates are blocked")
	expect(director._memory[site.id].survivors == ["rime_stag", "rime_skitter"], "Blocked spawn retains exact finite roster for retry")
	world.queue_free()
	await get_tree().process_frame
	get_tree().root.get_node("WorldServer").reset_realm("batch02_runtime_fixture")
	var generated := GeneratedWorld.new()
	get_tree().root.add_child(generated)
	var placement := EnemyDirector.new()
	placement.world = generated
	generated.add_child(placement)
	placement.set_process(false)
	var checked := 0
	for feature in generated.generator.features:
		if feature.type != "ruins":
			continue
		var center := Vector3(feature.center.x + 0.5, 0, feature.center.y + 0.5)
		center.y = generated.ground_height(center.x, center.z)
		expect(not generated.enemy_spawn_clear(center, 0.65, 1.8), "Unloaded ruin interior is rejected by geometry, without a collider")
		var safe := placement.find_spawn_position(center, Enemies.get_def("spirit_brown"))
		expect(not safe.is_empty(), "Ruin encounter has a nearby safe spawn")
		if not safe.is_empty():
			expect(generated.generator.enemy_spawn_clear(safe.pos, 0.6, 2.2), "Relocated spirit clears ruin walls and footprints")
		checked += 1
		if checked == 8:
			break
	expect(checked > 0, "Procedural ruin regression cases exercised")
	generated.queue_free()
	await get_tree().process_frame
