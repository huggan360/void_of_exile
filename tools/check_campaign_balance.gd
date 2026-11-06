extends Node3D
## Focused checks for campaign anchors and the regular god damage budget.
var failed := false
func verify(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		push_error(message)

func check_damage(value: Variant) -> void:
	if value is Dictionary:
		for key in value:
			if key in ["damage_min", "damage_max"]: verify(value[key] <= 80, "God damage exceeds 80")
			else: check_damage(value[key])
	elif value is Array:
		for part in value: check_damage(part)

func _ready() -> void:
	GameServer.set_physics_process(false)
	var gods := {}
	for id in Enemies.all_ids():
		var def := Enemies.get_def(id)
		if def.is_god and not def is BossDef:
			verify(def.hp <= 1600, "God HP exceeds budget: " + id)
			check_damage(def.attacks)
			gods[id] = def.hp
	var nested: Dictionary = Enemies.scale_attack_damage({damage_min = 45, damage_max = 55, terminal = {attack = {damage_min = 70, damage_max = 85}}}, 1.3)
	verify(nested.damage_max == 72 and nested.terminal.attack.damage_max == 111, "Prism shot scaling includes nested bursts")
	var world := IslandWorld.new({id = "campaign_anchor_probe", seed = 20261031, destroyed = []})
	# Terrain planning alone is enough; avoid streaming or rendering the realm.
	var town_checks := 0
	for id in Campaigns.NPCS:
		var info: Dictionary = Campaigns.NPCS[id]
		if not info.has("at") or not info.at is Dictionary or not info.at.has("village"): continue
		var pos := Campaigns.resolve(info.at, world)
		for town in world.generator.villages:
			if town.display_name != info.at.village: continue
			verify(Vector2(pos.x, pos.z).distance_to(Vector2(town.center)) < town.radius - 2.0, "NPC outside town: " + id)
			verify(Campaigns.spawn_clear(pos, world), "NPC obstructed: " + id)
			town_checks += 1
	var summit := Campaigns.resolve({summit = "Snowbell"}, world)
	var cabin := Campaigns.resolve({cabin = "Snowbell"}, world)
	var mountain := world.generator._mountain_center
	verify(summit.is_finite() and summit.y >= world.ground_height(mountain.x, mountain.y), "Chest must be at the mountain summit")
	# The stronghold cuts through the nominal center; compare against real terrain.
	var highest := 0.0
	for z in range(floori(mountain.y - 128), ceili(mountain.y + 128)):
		for x in range(floori(mountain.x - 128), ceili(mountain.x + 128)):
			if Vector2(x + 0.5, z + 0.5).distance_to(mountain) <= 128:
				highest = maxf(highest, world.ground_height(x + 0.5, z + 0.5))
	verify(summit.y == highest, "Chest must sit on the actual highest mountain terrain")
	verify(cabin.is_finite() and Vector2(cabin.x, cabin.z).distance_to(mountain) < world.generator._mountain_radius * 1.3, "Cabin must be at the mountain foot")
	verify(Campaigns.spawn_clear(cabin, world, 3.3, 4.0), "Cabin footprint must be clear and level")
	verify(Campaigns.spawn_clear(Campaigns.resolve(Campaigns.NPCS.halvard.at, world), world), "Halvard must have a clear spot beside the cabin")
	print("Campaign anchors: ", town_checks, " town NPCs; summit ", summit, "; cabin ", cabin, "; mountain ", mountain)
	var config := ServerConfig.load_from("res://server_config")
	config.apply()
	for id in gods:
		verify(Enemies.get_def(id).hp == gods[id], "Saved config must use the reduced god HP: " + id)
		check_damage(Enemies.get_def(id).attacks)
	print("God budgets: ", gods.size(), "; failures: ", failed)
	world.gates.free()
	world.enemy_director.free()
	world.free()
	get_tree().quit(1 if failed else 0)
