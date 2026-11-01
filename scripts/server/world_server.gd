extends Node
## Stand-in for the game server (autoloaded as WorldServer).
##
## The server owns each realm's record: its seed, picked once when the realm is
## first generated, which obstacles have been destroyed, and which
## non-respawning enemy packs have been wiped out (those stay gone). Records are saved
## to disk so every visit gets the same island. Online the dedicated server
## keeps them (in its data folder, see ServerConfig) and sends each client
## the record of the realm it enters; a client keeps none of its own.

const LAYOUT_VERSION := 6
## Every realm is the same island: the reviewed map (docs/realm_expansion/
## seed_20261031.json), no longer a random one per realm.
const MAP_SEED := 20261031
const SAVE_DIR := "user://server/realms/"

## Where records live (the dedicated server points this at its data folder).
var save_dir := SAVE_DIR

var _realms := {}


func get_or_create_realm(realm_id: String) -> Dictionary:
	if _realms.has(realm_id):
		return _realms[realm_id]
	var record := _load(realm_id)
	if record.is_empty():
		record = {
			id = realm_id,
			layout_version = LAYOUT_VERSION,
			seed = MAP_SEED,
			created = Time.get_datetime_string_from_system(true),
			destroyed = [],
			cleared_packs = [],
			pack_survivors = {},
		}
		_save(record)
	if int(record.get("layout_version",1))==5 and int(record.seed)==MAP_SEED:
		_migrate_expansion(record)
		_save(record)
	if int(record.get("layout_version", 1)) < LAYOUT_VERSION or int(record.seed) != MAP_SEED:
		record.seed = MAP_SEED
		# Coordinates now describe a different island layout. Preserve the old
		# progress as an archive instead of applying kills to unrelated new sites.
		record.legacy_layout_v1 = {destroyed = record.destroyed.duplicate(true),
			cleared_packs = record.cleared_packs.duplicate(true), pack_survivors = record.pack_survivors.duplicate(true)}
		record.destroyed = []
		record.cleared_packs = []
		record.pack_survivors = {}
		record.layout_version = LAYOUT_VERSION
		_save(record)
	_realms[realm_id] = record
	return record


## Expanding the island preserves casualties, including moved boss/guard sites.
func _migrate_expansion(record: Dictionary) -> void:
	var migration: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://realm/expansion_migration.json"))
	for move: Array in migration.stronghold_moves:
		var old := "feature_%d_%d" % [move[0][0],move[0][1]]
		var replacement := "feature_%d_%d" % [move[1][0],move[1][1]]
		for id: String in record.cleared_packs.duplicate():
			if id==old or id.begins_with(old+"_"):
				var mapped := replacement+id.trim_prefix(old)
				if mapped not in record.cleared_packs: record.cleared_packs.append(mapped)
		for id: String in record.pack_survivors.keys():
			if id==old or id.begins_with(old+"_"):
				var mapped := replacement+id.trim_prefix(old)
				if not record.pack_survivors.has(mapped): record.pack_survivors[mapped] = record.pack_survivors[id].duplicate()
	record.layout_version = LAYOUT_VERSION


## The fortresses whose gates are unsealed in this realm (keys used, no reset since).
func report_gates(realm_id: String, opened: Array) -> void:
	if Net.is_client():
		return
	var record := get_or_create_realm(realm_id)
	var cells: Array = opened.map(func(c: Vector2i) -> Array: return [c.x, c.y])
	if record.get("opened_gates", []) != cells:
		record.opened_gates = cells
		_save(record)


## Saves a realm record that was changed directly (shared fog...).
func save_record(record: Dictionary) -> void:
	if not Net.is_client():
		_save(record)


func report_obstacle_destroyed(realm_id: String, obstacle_id: String) -> void:
	if Net.is_client():
		return  # the server keeps the record (Main tells it)
	var record := get_or_create_realm(realm_id)
	if not obstacle_id in record.destroyed:
		record.destroyed.append(obstacle_id)
		_save(record)


## A pack that never respawns was wiped out: it stays gone in this realm.
func report_pack_cleared(realm_id: String, site_id: String) -> void:
	if Dungeons.is_dungeon(realm_id): return
	if Net.is_client():
		return
	var record := get_or_create_realm(realm_id)
	if not record.has("cleared_packs"):
		record.cleared_packs = []
	if not site_id in record.cleared_packs:
		record.cleared_packs.append(site_id)
		_save(record)


## Persist every finite-pack casualty, not only a full wipe. Dead gods cannot
## return if stars survive, a chunk unloads, or the player leaves the realm.
func report_pack_survivors(realm_id: String, site_id: String, survivors: Array) -> void:
	if Dungeons.is_dungeon(realm_id): return
	if Net.is_client():
		return
	var record := get_or_create_realm(realm_id)
	if not record.has("pack_survivors"):
		record.pack_survivors = {}
	record.pack_survivors[site_id] = survivors.duplicate()
	if survivors.is_empty() and not site_id in record.cleared_packs:
		record.cleared_packs.append(site_id)
	_save(record)


## Development helper: throws the realm away so the next visit makes a new one.
func reset_realm(realm_id: String) -> void:
	_realms.erase(realm_id)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(_path(realm_id)))


func _path(realm_id: String) -> String:
	return save_dir + realm_id + ".json"


func _load(realm_id: String) -> Dictionary:
	var file := FileAccess.open(_path(realm_id), FileAccess.READ)
	if file == null:
		return {}
	var data = JSON.parse_string(file.get_as_text())
	if not data is Dictionary:
		return {}
	if not data.has("pack_survivors"):
		data.pack_survivors = {}
	if not data.has("cleared_packs"):
		data.cleared_packs = []
	data.seed = int(data.seed)  # JSON numbers load as floats
	return data


func _save(record: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(save_dir))
	var file := FileAccess.open(_path(record.id), FileAccess.WRITE)
	file.store_string(JSON.stringify(record, "\t"))
