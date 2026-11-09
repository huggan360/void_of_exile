class_name ServerConfig
extends RefCounted
## The dedicated server's settings, one folder of files (default
## res://server_config/, or --config=<folder>):
##
##   server.cfg    the global settings: name, port, max players, players per
##                 realm, player collision, the account service, tick rate...
##   enemies.json  every regular enemy: health, defence, XP, speed, awareness,
##                 and multipliers for its damage, attack rate and shot speed
##   bosses.json   every boss: health, shell, scaling per extra player, intro,
##                 reset timing, damage multiplier
##   loot.json     every enemy's loot table and threshold, bag lifetimes
##   spawns.json   every pack (members, leader, respawn time, wake radius),
##                 which packs live in each biome and how densely, and an
##                 overall density multiplier
##   player.json   regeneration, shield and ring costs, XP orbs, and what a
##                 new character starts with
##
## Missing files are written with the game's current values the first time
## the server starts, so every value is there to edit. Restart the server to
## apply changes.

const DEFAULT_DIR := "res://server_config"

var dir := ""
var global := ConfigFile.new()
var enemies := {}
var bosses := {}
var loot := {}
var spawns := {}
var player := {}
## Run by the game for Singleplayer (one player, not announced anywhere).
var singleplayer := false


static func load_from(folder: String) -> ServerConfig:
	var config := ServerConfig.new()
	var location := folder
	if location == "":
		location = OS.get_executable_path().get_base_dir().path_join("server_config") if OS.has_feature("template") else DEFAULT_DIR
	config.dir = ProjectSettings.globalize_path(location).trim_suffix("/") + "/"
	DirAccess.make_dir_recursive_absolute(config.dir)
	config._load_global()
	config.enemies = config._load_json("enemies.json", ServerConfig._default_enemies())
	config.bosses = config._load_json("bosses.json", ServerConfig._default_bosses())
	config.loot = config._load_json("loot.json", ServerConfig._default_loot())
	config.spawns = config._load_json("spawns.json", ServerConfig._default_spawns())
	config.player = config._load_json("player.json", ServerConfig._default_player())
	return config


func value(section: String, key: String, fallback: Variant = null) -> Variant:
	return global.get_value(section, key, fallback)


## Absolute path of the server's data folder (realm records).
func data_dir() -> String:
	var d: String = value("server", "data_dir", "data")
	return (d if d.is_absolute_path() else dir + d).trim_suffix("/") + "/"


## How much harder (or softer) this enemy hits than its def says.
func damage_multiplier(enemy_id: String) -> float:
	var own: Dictionary = enemies.get(enemy_id, bosses.get(enemy_id, {}))
	return float(value("gameplay", "enemy_damage_multiplier", 1.0)) * float(own.get("damage_multiplier", 1.0))


# --- Applying ---------------------------------------------------------------------

## Puts the settings into the game's definitions (call once at start-up,
## before any realm is made).
func apply() -> void:
	var hp_mult := float(value("gameplay", "enemy_hp_multiplier", 1.0))
	for id in Enemies.all_ids():
		var def := Enemies.get_def(id)
		var e: Dictionary = (bosses if def is BossDef else enemies).get(id, {})
		for key in ["defense", "xp", "move_speed", "aggro_radius", "lose_radius", "keep_distance", "wander_radius"]:
			if e.has(key):
				def.set(key, type_convert(e[key], typeof(def.get(key))))
		if e.has("hp"):
			def.hp = maxi(1, roundi(float(e.hp) * hp_mult))
		var rate := float(e.get("attack_speed_multiplier", 1.0))
		var shot_speed := float(e.get("projectile_speed_multiplier", 1.0))
		if rate != 1.0 or shot_speed != 1.0:
			var tuned: Array[Dictionary] = []
			for a in def.attacks:
				var t := a.duplicate(true)
				t.cooldown = float(t.get("cooldown", 1.0)) / maxf(0.05, rate)
				t.speed = float(t.get("speed", 10.0)) * shot_speed
				tuned.append(t)
			def.attacks = tuned
		if def is BossDef:
			var b := def as BossDef
			for key in ["shell_hp", "hp_per_extra_player", "support_hp_per_extra_player", "intro_time",
					"abandon_radius", "abandon_time", "bar_radius", "lock_gates"]:
				if e.has(key):
					b.set(key, type_convert(e[key], typeof(b.get(key))))
		var l: Dictionary = loot.get("enemies", {}).get(id, {})
		if l.has("loot"):
			var table: Array[Dictionary] = []
			for entry: Dictionary in l.loot:
				table.append(_loot_entry(entry))
			def.loot = table
		if l.has("loot_threshold"):
			def.loot_threshold = float(l.loot_threshold)
	# Packs and how densely they spread.
	for pack_id: String in spawns.get("packs", {}):
		Enemies.pack_overrides[pack_id] = _pack(spawns.packs[pack_id])
	var density := float(spawns.get("density_multiplier", 1.0)) * float(value("gameplay", "spawn_density_multiplier", 1.0))
	for b_id in Biomes.COUNT:
		var biome := Biomes.get_biome(b_id)
		var listed: Dictionary = spawns.get("biomes", {}).get(biome.biome_name, {})
		var packs: Array = listed.get("enemy_packs", biome.enemy_packs)
		biome.enemy_packs = packs.map(func(p: Dictionary) -> Dictionary:
			return {pack = str(p.pack), density = float(p.density) * density})
	# The player side (GameServer's tunables).
	for key in player.get("tunables", {}):
		if key.to_upper() in GameServer:
			GameServer.set(key.to_upper(), player.tunables[key])
	GameServer.xp_multiplier = float(value("gameplay", "xp_multiplier", 1.0))
	GameServer.BAG_LIFETIME = float(loot.get("bags", {}).get("lifetime", GameServer.BAG_LIFETIME))
	GameServer.PERSONAL_BAG_LIFETIME = float(loot.get("bags", {}).get("personal_lifetime", GameServer.PERSONAL_BAG_LIFETIME))
	WorldServer.save_dir = data_dir() + "realms/"


## A new character of a class (data from the account service is empty for
## a character that has never played): the class's gear, graded up by the
## account's rewards, plus the config's starting kit.
func new_character(class_id: String, rewards: Array = []) -> PlayerStats:
	var stats := PlayerStats.new()
	stats.class_id = class_id if PlayerClasses.exists(class_id) else "archer"
	stats.reset()
	var kit: Dictionary = player.get("starting_kit", {})
	var tiers := {}
	var extra: Array = []
	for r: Dictionary in rewards:
		match str(r.get("type", "")):
			"start_tier": tiers[str(r.slot)] = maxi(int(tiers.get(str(r.slot), 1)), int(r.tier))
			"start_item": extra.append({id = str(r.id), count = int(r.get("count", 1))})
	var data := stats.to_data()
	var gear := PlayerClasses.starting_gear(stats.class_id, tiers)
	for slot in gear:
		data.gear[slot] = {id = gear[slot].id, count = 1} if gear[slot] else null
	for i in mini(kit.get("backpack", []).size(), data.backpack.size()):
		data.backpack[i] = kit.backpack[i]
	for i in mini(kit.get("quick", []).size(), PlayerStats.QUICKSLOTS):
		data.quick[i] = kit.quick[i].duplicate()
	for e: Dictionary in extra:  # rewards: more of the quickslot elixirs, or into the backpack
		var stacked := false
		for q: Variant in data.quick:
			if q is Dictionary and q.id == e.id:
				q.count = int(q.count) + e.count
				stacked = true
		if not stacked and data.backpack.find(null) >= 0:
			data.backpack[data.backpack.find(null)] = e
	stats.load_data(data)
	# Starting rewards can raise the maxima after reset() filled the base kit.
	stats.hp = stats.max_hp
	stats.mp = stats.max_mp
	return stats


static func _loot_entry(entry: Dictionary) -> Dictionary:
	var out := entry.duplicate(true)
	out.chance = float(entry.get("chance", 0.0))
	if out.has("pool"):
		out.pool.tier = int(out.pool.tier)
	return out


static func _pack(p: Dictionary) -> Dictionary:
	var out := p.duplicate(true)
	for m: Dictionary in out.get("members", []):
		m.min = int(m.get("min", 1))
		m.max = int(m.get("max", m.min))
	if out.has("leader"):
		out.leader.min_members = int(out.leader.get("min_members", 0))
	out.respawn_time = float(out.get("respawn_time", 120.0))
	out.activate_radius = float(out.get("activate_radius", 34.0))
	return out


# --- Files --------------------------------------------------------------------------

func _load_global() -> void:
	var path := dir + "server.cfg"
	if global.load(path) != OK:
		global = ConfigFile.new()
	var defaults := {
		server = {name = "Void Realm", port = Net.DEFAULT_PORT, max_players = 300, motd = "Welcome to the Void.",
			public = false, lan_discovery = true, data_dir = "data", max_memory_mb = 0},
		realms = {"max_players_per_realm": 85, "max_realms": 8, "unload_after_empty": 120.0, "keep_loaded": "realm_1,astral", "preload": true},
		gameplay = {player_collision = false, xp_multiplier = 1.0, enemy_hp_multiplier = 1.0,
			enemy_damage_multiplier = 1.0, spawn_density_multiplier = 1.0},
		network = {tick_rate = 20, interest_radius = 72.0, event_radius = 85.0, max_speed_tolerance = 1.6},
		accounts = {url = "https://void.plainshow.se", server_key = "", save_interval = 30.0, heartbeat_interval = 5.0},
	}
	var added := false
	for section: String in defaults:
		for key: String in defaults[section]:
			if not global.has_section_key(section, key):
				global.set_value(section, key, defaults[section][key])
				added = true
	if added:
		global.save(path)


func _load_json(file: String, defaults: Dictionary) -> Dictionary:
	var path := dir + file
	if FileAccess.file_exists(path):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if parsed is Dictionary:
			return parsed
		push_error("%s is not valid JSON; using the defaults for now (fix or delete it)." % path)
		return defaults
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(defaults, "\t"))
	return defaults


static func _default_enemies() -> Dictionary:
	var out := {_about = "Regular enemies. hp/defense/xp/speeds/radii replace the game's values; the multipliers scale its damage, how often it attacks and how fast its shots fly. Bosses are in bosses.json."}
	for id in Enemies.all_ids():
		var d := Enemies.get_def(id)
		if d is BossDef:
			continue
		out[id] = {name = d.enemy_name, hp = d.hp, defense = d.defense, xp = d.xp, move_speed = d.move_speed,
			aggro_radius = d.aggro_radius, lose_radius = d.lose_radius, keep_distance = d.keep_distance,
			wander_radius = d.wander_radius, damage_multiplier = 1.0, attack_speed_multiplier = 1.0,
			projectile_speed_multiplier = 1.0}
	return out


static func _default_bosses() -> Dictionary:
	var out := {_about = "Bosses. hp is solo health (it grows by hp_per_extra_player for each other player near when it hatches). damage_multiplier scales every shot, ripple and hazard of the encounter."}
	for id in Enemies.all_ids():
		var d := Enemies.get_def(id)
		if not d is BossDef:
			continue
		var b := d as BossDef
		out[id] = {name = b.enemy_name, hp = b.hp, defense = b.defense, xp = b.xp, shell_hp = b.shell_hp,
			hp_per_extra_player = b.hp_per_extra_player, support_hp_per_extra_player = b.support_hp_per_extra_player,
			intro_time = b.intro_time, lock_gates = b.lock_gates, abandon_radius = b.abandon_radius, abandon_time = b.abandon_time,
			bar_radius = b.bar_radius, damage_multiplier = 1.0}
	return out


static func _default_loot() -> Dictionary:
	var table := {}
	for id in Enemies.all_ids():
		var d := Enemies.get_def(id)
		table[id] = {loot_threshold = d.loot_threshold, loot = d.loot.map(func(e: Dictionary) -> Dictionary: return e.duplicate(true))}
	return {
		_about = "Loot tables. Entries: {item, chance} a specific item; {pool: {tier, slots}, chance} any graded item; {biome_stat: true, chance} a stat elixir of the biome. chance 1.0 = always. loot_threshold: share of its health a player must deal to roll personal loot.",
		bags = {lifetime = GameServer.BAG_LIFETIME, personal_lifetime = GameServer.PERSONAL_BAG_LIFETIME},
		enemies = table,
	}


static func _default_spawns() -> Dictionary:
	var biomes := {}
	for b_id in Biomes.COUNT:
		var b := Biomes.get_biome(b_id)
		if not b.enemy_packs.is_empty():
			biomes[b.biome_name] = {enemy_packs = b.enemy_packs.duplicate(true)}
	return {
		_about = "Packs: members [{enemy, min, max, chance}], leader {enemy, min_members}, respawn_time seconds (-1 never), activate_radius meters. biomes: which packs spread over each biome and how densely (density = chance per spawn cell). density_multiplier scales all of them.",
		density_multiplier = 1.0,
		packs = Enemies.PACKS.duplicate(true),
		biomes = biomes,
	}


static func _default_player() -> Dictionary:
	var tunables := {}
	for key in ["HP_REGEN", "HP_REGEN_DELAY", "MP_REGEN", "MP_REGEN_DELAY", "SHIELD_DRAIN", "SHIELD_MIN_MP",
			"RING_COOLDOWN", "XP_PER_ORB", "MAX_ORBS_PER_DROP", "XP_ORB_LIFETIME"]:
		tunables[key.to_lower()] = GameServer.get(key)
	return {
		_about = "tunables: health/magic regeneration (per second, after a delay), warp shield MP drain, ring cooldown, XP orbs. Shield protection scales with MAG. starting_kit: what a new character has besides its class gear (backpack and quickslot item ids). Class gear comes from the class, graded up by account level rewards.",
		tunables = tunables,
		starting_kit = {
			backpack = [],
			quick = [{id = "elixir_hp", count = 2}, {id = "elixir_mp", count = 2}],
		},
	}
