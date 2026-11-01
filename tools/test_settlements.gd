extends Node
var failures := 0
var checks := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func _ready() -> void:
	_run.call_deferred()
func _run() -> void:
	for seed_value: int in [20261031, 17, 99123]:
		var started := Time.get_ticks_msec()
		var gen := IslandGenerator.new(seed_value)
		print("PLANNED ", seed_value, " in ", (Time.get_ticks_msec()-started)/1000.0, "s; roads=", gen.roads.size())
		check(gen.villages.size() == 4, "Four villages always exist")
		check(gen.villages[0].houses.size() >= 12, "Capital has at least 12 houses")
		check(Vector2(gen.find_spawn()[0].x, gen.find_spawn()[0].z).length() < 2, "Arrival is at the central village")
		check(gen.column(0, 0).y == Biomes.WOODS, "Woodland surrounds the capital")
		check(gen._detail(0, 0).size() == 4, "Spawn is free of building solids")
		for village in gen.villages:
			var roles := village.service_sites.map(func(s: Dictionary) -> String: return s.role)
			if village == gen.villages[0] or village.biome_id == Biomes.FOSEN:
				check("smith" in roles, "Capital and Fosen have guaranteed smiths")
			if village.biome_id == Biomes.DESERT:
				check("magician" in roles, "Desert has guaranteed magician")
			check(village.residents.size() >= 4, "Friendly residents planned")
			for house in village.houses:
				check(village.bounds.has_point(house.center), "House belongs to town bounds")
		check(gen.strongholds.size() == 5, "Five mandatory strongholds")
		var bosses := 0
		for fort in gen.strongholds:
			check(gen.column(fort.center.x, fort.center.y).y == fort.biome_id, "Stronghold is in its intended biome")
			for z in range(-8, 8):
				for x in range(-8, 8):
					var d := gen._detail(fort.center.x + x, fort.center.y + z)
					check(d[0] == fort.base_height and d.size() == 4, "Arena has a clear, level raised 16x16 floor")
			if not fort.packs.is_empty():
				bosses += 1
				var lairs := {Biomes.BLUELAY: "blue_dragon_lair", Biomes.FOSEN: "rimeheart_lair", Biomes.DOOM: "vharok_lair",
						Biomes.DESERT: "scarab_lair", Biomes.DEEP_DARK: "hollow_crown_lair"}
				check(fort.packs.size() == 2 and fort.packs[0].pack == lairs[fort.biome_id] and fort.packs[1].pack.ends_with("_guards"), "Each stronghold has its own boss and guardian pack")
		check(bosses == 5, "Five boss strongholds")
		var sites := gen.pack_sites(Rect2i(-704, -704, 1408, 1408), [])
		var dragon_sites := sites.filter(func(s: Dictionary) -> bool: return s.pack == "blue_dragon_lair")
		check(dragon_sites.size() == 1, "Blue Dragon is placed only once")
		for lair in ["rimeheart_lair", "vharok_lair", "scarab_lair", "hollow_crown_lair"]:
			check(sites.filter(func(s: Dictionary) -> bool: return s.pack == lair).size() == 1, "One encounter at its stronghold: " + lair)
		if dragon_sites.size() == 1:
			var pos: Vector3 = dragon_sites[0].pos
			check(gen.enemy_spawn_clear(pos, 3.4, 6.8), "Blue Dragon fits at arena center")
		for village in gen.villages:
			for site in sites:
				check(not village.bounds.has_point(Vector2i(floori(site.pos.x), floori(site.pos.z))), "Villages contain no hostile pack sites")
		# Seeded plans are independently reproducible; a different seed changes houses.
		var repeat := VillageFeature.plan(Vector2i.ZERO, Biomes.WOODS, seed_value * 41 + 1, IslandGenerator.SEA_LEVEL+2, true, Array(gen.villages[0].exits))
		check(repeat.houses == gen.villages[0].houses, "Town house layouts reproduce from the town seed")
		var broken_steps := 0
		var blocked_steps := 0
		for road in gen.roads:
			for i in range(road.size() - 1):
				var count := maxi(1, ceili(road[i].distance_to(road[i + 1]) * 2))
				var previous := -10000
				for n in count + 1:
					var pos := road[i].lerp(road[i + 1], float(n) / count)
					var d := gen._detail(floori(pos.x), floori(pos.y))
					if previous != -10000 and absi(d[0] - previous) > 1:
						broken_steps += 1
					var blocked: bool = d[0] < IslandGenerator.SEA_LEVEL or Blocks.is_hazard(d[2])
					for segment in range(4, d.size(), 3):
						if d[segment] < d[0] + 3.0 and d[segment + 1] > d[0] + 1.1:
							blocked = true
					if blocked:
						blocked_steps += 1
						if blocked_steps < 5:
							print("BLOCKED ROAD ", pos, " ", d)
					previous = d[0]
		check(broken_steps == 0, "Roads contain no unclimbable steps: " + str(broken_steps))
		check(blocked_steps == 0, "Road centerlines avoid solids, lava and water: " + str(blocked_steps))
		_dump_map(gen, seed_value)
	for role in ["smith", "magician", "baker", "gardener", "villager", "traveler"]:
		CreatureModel.preload_creature("npc_" + role)
		check(ResourceLoader.exists("res://creatures/npc_%s/portrait.png" % role), "Future shop portrait exists")
	_test_migration()
	await _test_npc_motion()
	print("SETTLEMENTS: ", checks, " checks, ", failures, " failures")
	get_tree().quit(1 if failures else 0)
func _dump_map(gen: IslandGenerator, seed_value: int) -> void:
	var output := {seed = seed_value, spawn = [gen.find_spawn()[0].x, gen.find_spawn()[0].y, gen.find_spawn()[0].z], towns = [], forts = [], roads = []}
	for v in gen.villages:
		output.towns.append({name = v.display_name, x = v.center.x, z = v.center.y, radius = v.radius, houses = v.houses.size(), services = v.service_sites.map(func(s: Dictionary) -> String: return s.role)})
	for f in gen.strongholds:
		output.forts.append({name = f.display_name, x = f.center.x, z = f.center.y, biome = f.biome_id})
	for road in gen.roads:
		var points := []
		for p in road:
			points.append([p.x, p.y])
		output.roads.append(points)
	var file := FileAccess.open("/home/hugo/tmp/realm_plan_%d.json" % seed_value, FileAccess.WRITE)
	file.store_string(JSON.stringify(output))

func _test_migration() -> void:
	var server := get_tree().root.get_node("WorldServer")
	var id := "settlement_migration_fixture"
	server.reset_realm(id)
	server._save({id = id, seed = 7177, created = "fixture", destroyed = ["old_tree"], cleared_packs = ["old_god"], pack_survivors = {old_site = ["star"]}})
	var record: Dictionary = server.get_or_create_realm(id)
	check(record.seed == 7177 and record.layout_version == WorldServer.LAYOUT_VERSION, "Migration retains original realm seed")
	check(record.legacy_layout_v1.cleared_packs == ["old_god"], "Old kill progress is archived")
	check(record.cleared_packs.is_empty() and record.destroyed.is_empty(), "Old coordinates cannot clear unrelated new locations")
	server._realms.erase(id)
	record = server.get_or_create_realm(id)
	check(record.legacy_layout_v1.destroyed == ["old_tree"], "Archive survives reload without being overwritten")
	server.reset_realm(id)

func _test_npc_motion() -> void:
	var world := Node3D.new()
	get_tree().root.add_child(world)
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = Player.TERRAIN_LAYER
	var shape := CollisionShape3D.new()
	var slab := BoxShape3D.new()
	slab.size = Vector3(30, 1, 30)
	shape.shape = slab
	shape.position.y = -0.5
	floor_body.add_child(shape)
	world.add_child(floor_body)
	await get_tree().physics_frame
	var npc := TownNPC.new().setup({role = "baker", seed = 177, pos = Vector3(0, 0.1, 0), stationary = false,
		route = [Vector3.ZERO, Vector3(0, 0, 4), Vector3.ZERO]})
	world.add_child(npc)
	npc._waypoint = 1
	npc._wait = 0
	await get_tree().create_timer(1.2).timeout
	check(npc.position.z > 0.5 and npc.position.y > -0.2, "Friendly NPC walks its street route without falling through terrain")
	check(npc.collision_layer == 0, "Friendly NPC cannot be hit as an enemy")
	world.queue_free()
	await get_tree().process_frame
