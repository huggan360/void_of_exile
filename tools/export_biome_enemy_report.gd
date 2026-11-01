extends Node
## Read-only spawn-table audit and a fresh, untouched example realm. No server writes.
func _ready() -> void:
	var report := {spirit_packs = Biomes.SPIRIT_PACKS, spirit_packs_bluelay = Biomes.SPIRIT_PACKS_BLUELAY, example_seed = 20261031, biomes = [], packs = Enemies.PACKS, enemies = {}, example = {}}
	for id in Enemies.all_ids():
		var e := Enemies.get_def(id)
		var attacks: Array = []
		for attack: Dictionary in e.attacks:
			attacks.append({damage_min = attack.get("damage_min",0), damage_max = attack.get("damage_max",0), pattern = attack.get("pattern","aimed"), count = attack.get("count",1), cooldown = attack.get("cooldown",0), windup = attack.get("windup",0), speed = attack.get("speed",0), magic = attack.get("magic",false), armor_piercing = attack.get("armor_piercing",false)})
		report.enemies[id] = {name = e.enemy_name, is_god = e.is_god, is_boss = e is BossDef, god_potion_stats = e.god_potion_stats, hp = e.hp, defense = e.defense, xp = e.xp, behavior = e.behavior, speed = e.move_speed, aggro = e.aggro_radius, attacks = attacks}
	for i in Biomes.COUNT:
		var b := Biomes.get_biome(i)
		report.biomes.append({id = i, name = b.biome_name, packs = b.enemy_packs, features = b.features, god_stat = b.god_stat, god_stats = b.god_stats})
	var gen := IslandGenerator.new(report.example_seed)
	var spawn := gen.find_spawn()
	var spawn_pos: Vector3 = spawn[0]
	var inland: Vector2 = spawn[1]
	var portal := gen.surface(Vector2(spawn_pos.x,spawn_pos.z)+inland*7)
	var keep: Array[Vector3] = [spawn_pos,portal]
	var sites := gen.pack_sites(Rect2i(-448,-448,896,896),keep)
	for site: Dictionary in sites:
		var biome := Biomes.get_biome(gen.column(floori(site.pos.x),floori(site.pos.z)).y)
		if not report.example.has(biome.biome_name): report.example[biome.biome_name] = {packs = {}, enemies = {}, total_packs = 0, total_enemies = 0, god_enemies = 0, feature_packs = 0}
		var summary: Dictionary = report.example[biome.biome_name]
		summary.total_packs += 1
		if str(site.id).begins_with("feature_"): summary.feature_packs += 1
		summary.packs[site.pack] = summary.packs.get(site.pack,0)+1
		var spec: Dictionary = Enemies.PACKS[site.pack]
		var rng := RandomNumberGenerator.new()
		rng.seed = site.seed
		var ids: Array[String] = []
		for member: Dictionary in spec.members:
			if member.has("chance") and rng.randf()>=member.chance: continue
			for n in rng.randi_range(member.min,member.max): ids.append(member.enemy)
		if spec.has("leader") and ids.size()>=spec.leader.min_members: ids.push_front(spec.leader.enemy)
		for id in ids:
			summary.total_enemies += 1
			summary.enemies[id] = summary.enemies.get(id,0)+1
			if Enemies.get_def(id).is_god: summary.god_enemies += 1
	var streamed := {}
	for z in range(-448,448,32):
		for x in range(-448,448,32):
			for site: Dictionary in gen.pack_sites(Rect2i(x,z,32,32),keep):
				streamed[site.id] = site
	var streamed_counts := {}
	var missed_counts := {}
	for site: Dictionary in sites:
		var name: String = Biomes.get_biome(gen.column(floori(site.pos.x),floori(site.pos.z)).y).biome_name
		if not streamed_counts.has(name): streamed_counts[name] = {total_packs = 0, packs = {}}
		if streamed.has(site.id):
			streamed_counts[name].total_packs += 1
			streamed_counts[name].packs[site.pack] = streamed_counts[name].packs.get(site.pack,0)+1
		else:
			missed_counts[name] = missed_counts.get(name,0)+1
	report.streamed_example = streamed_counts
	report.streamed_missing = missed_counts
	print("Whole-area candidate sites: ",sites.size(),"; chunk-enumerated sites: ",streamed.size())
	var file := FileAccess.open("res://docs/realm_expansion/biome_enemy_report.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	print("Spawn audit exported: ",sites.size()," planned sites for example seed ",report.example_seed)
	get_tree().quit()
