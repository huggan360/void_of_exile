extends Node
## Read-only audit: evaluates source defaults and the existing config in an
## isolated process, exporting definitions without starting worlds or servers.
var output := "/home/hugo/tmp/void_wiki/catalog.json"

func _ready() -> void: _export.call_deferred()

func encode(value: Variant) -> Variant:
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_STRING: return value
		TYPE_FLOAT: return value if is_finite(value) else str(value)
		TYPE_COLOR: return {type = "Color", hex = value.to_html(), rgba = [value.r, value.g, value.b, value.a]}
		TYPE_VECTOR2, TYPE_VECTOR2I: return {x = value.x, y = value.y}
		TYPE_VECTOR3, TYPE_VECTOR3I: return {x = value.x, y = value.y, z = value.z}
		TYPE_RECT2, TYPE_RECT2I: return {position = encode(value.position), size = encode(value.size)}
		TYPE_ARRAY, TYPE_PACKED_STRING_ARRAY, TYPE_PACKED_FLOAT32_ARRAY, TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_VECTOR3_ARRAY:
			var result := []
			for v in value: result.append(encode(v))
			return result
		TYPE_DICTIONARY:
			var result := {}
			for key in value: result[str(key)] = encode(value[key])
			return result
		TYPE_OBJECT:
			if value is Resource: return properties(value)
			return {type = value.get_class() if value else "null"}
	return str(value)

func properties(value: Object) -> Dictionary:
	var result := {}
	for p: Dictionary in value.get_property_list():
		var key := str(p.name)
		if key.begins_with("_") or not (int(p.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE): continue
		result[key] = encode(value.get(key))
	var script: Script = value.get_script()
	if script: result.source_script = script.resource_path
	return result

func item_record(item: Item, live: bool) -> Dictionary:
	var row := properties(item)
	row.registered = live
	row.icon_path = "res://items/textures/%s.png" % item.id
	row.icon_exists = ResourceLoader.exists(row.icon_path)
	row.bag_type = item.bag_type()
	row.usable_classes = []
	for class_id in PlayerClasses.ORDER:
		if PlayerClasses.allows(class_id, item): row.usable_classes.append(class_id)
	row.shot_shares = []
	for i in item.shots: row.shot_shares.append(item.shot_share(i))
	return row

func enemy_record(def: EnemyDef) -> Dictionary:
	var row := properties(def)
	row.is_boss = def is BossDef
	row.stat_potions = encode(Loot.BOSS_POTIONS.get(def.id, [])) if def is BossDef else []
	row.max_grade = Loot.BOSS_GRADES.get(def.id, 6) if def is BossDef else 5 if def.is_god else 4
	row.grade_rolls = encode(Loot.GRADE_ROLLS.get(Loot.BOSS_GRADES.get(def.id, 0), [])) if def is BossDef else []
	if def is BossDef and def.actor_script != "":
		row.actor_source = FileAccess.get_file_as_string(def.actor_script)
		var script: GDScript = load(def.actor_script)
		if script: row.actor_constants = encode(script.get_script_constant_map())
	return row

func read_json(path: String, fallback: Dictionary = {}) -> Dictionary:
	if not FileAccess.file_exists(path): return fallback
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return value if value is Dictionary else fallback

func _export() -> void:
	GameServer.set_physics_process(false)
	WorldServer.set_process(false)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): output = arg.trim_prefix("--out=")
	var data := {schema = 1, project = "Void of Exile", generated = Time.get_datetime_string_from_system(),
		items = [], authored_items = [], enemies = [], default_enemies = [], biomes = [], default_biomes = [],
		packs = {}, default_packs = {}, warnings = []}
	var live_ids := {}
	for item in Items.all():
		live_ids[item.id] = true
		data.items.append(item_record(item, true))
	# Inspect the already-authored Divine definitions before their live-set
	# filter, without changing the gameplay file or global Items catalog.
	var source := FileAccess.get_file_as_string("res://scripts/game/items.gd")
	source = source.replace("class_name Items", "")
	source = source.replace("return out.filter(func(i: Item) -> bool: return i.id in live)", "return out")
	var all_script := GDScript.new()
	all_script.source_code = source
	var error := all_script.reload()
	if error == OK:
		var instance = all_script.new()
		for item: Item in instance.divine(): data.authored_items.append(item_record(item, live_ids.has(item.id)))
	else:
		data.warnings.append("Unable to evaluate authored Divine items before the live filter.")
	data.divine_sets = encode(Items.DIVINE_SETS)
	data.boss_divine_sets = encode(Items.BOSS_DIVINE_SET)
	data.boss_divine_extras = encode(Items.BOSS_DIVINE_EXTRAS)
	data.item_gate_keys = encode(Items.GATE_KEYS)
	data.item_story = encode(Items.STORY_ITEMS)
	data.player_classes = encode(PlayerClasses.CLASSES)
	data.account_levels = {max = AccountLevels.MAX_LEVEL, xp_formula = "600 + 400 * (level - 1)"}
	data.dungeons = encode(Dungeons.DEFINITIONS)
	data.dungeon_themes = encode(Dungeons.THEMES)
	data.campaigns = encode(Campaigns.LIST)
	data.campaign_npcs = encode(Campaigns.NPCS)
	data.realm_layout = encode(RealmLayout.data())
	for id in Enemies.all_ids(): data.default_enemies.append(enemy_record(Enemies.get_def(id)))
	for id in Biomes.COUNT: data.default_biomes.append(properties(Biomes.get_biome(id)))
	for id in Enemies.PACKS: data.default_packs[str(id)] = encode(Enemies.pack(id))
	# The official game: what every release server plays (locked, ServerConfig.locked),
	# never a local server_config folder.
	var config := ServerConfig.new()
	config.dir = OS.get_user_data_dir().path_join("wiki_server_config/")
	DirAccess.make_dir_recursive_absolute(config.dir)
	config.locked = true
	config._load_global()
	config.enemies = ServerConfig._default_enemies()
	config.bosses = ServerConfig._default_bosses()
	config.loot = ServerConfig._default_loot()
	config.spawns = ServerConfig._default_spawns()
	config.player = ServerConfig._default_player()
	config.apply()
	data.config = {enemies = encode(config.enemies), bosses = encode(config.bosses), loot = encode(config.loot),
		spawns = encode(config.spawns), player = encode(config.player), gameplay = {}}
	for key in config.global.get_section_keys("gameplay"):
		data.config.gameplay[key] = encode(config.global.get_value("gameplay", key))
	for id in Enemies.all_ids():
		var row := enemy_record(Enemies.get_def(id))
		row.damage_multiplier = config.damage_multiplier(str(id))
		data.enemies.append(row)
	for id in Biomes.COUNT: data.biomes.append(properties(Biomes.get_biome(id)))
	var pack_ids := Enemies.PACKS.keys()
	for id in Enemies.pack_overrides:
		if not pack_ids.has(id): pack_ids.append(id)
	for id in pack_ids: data.packs[str(id)] = encode(Enemies.pack(str(id)))
	data.loot_rules = {others_chance = Loot.OTHERS_CHANCE, boss_potions = encode(Loot.BOSS_POTIONS),
		boss_potion_rule = "Each player over the boss's damage threshold always gets one stat elixir: one of its two, 50/50.", public_bags = ["gray", "green"],
		personal_bags = ["blue", "red", "purple", "white", "black"], source = "res://scripts/loot/loot.gd"}
	data.projectile_manifest = JSON.parse_string(FileAccess.get_file_as_string("res://creatures/boss_projectiles/manifest.json"))
	DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	var file := FileAccess.open(output, FileAccess.WRITE)
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	print("WIKI CATALOG: ", data.items.size(), " registered items, ", data.authored_items.size(),
		" authored Divine items, ", data.enemies.size(), " enemies/bosses; saved ", output)
	get_tree().quit()
