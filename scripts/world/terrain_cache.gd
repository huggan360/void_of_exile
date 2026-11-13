class_name TerrainCache
## Generated terrain kept on disk for worlds that are the same every time (the
## Tavern, the Surface): the first visit generates and saves each chunk, later
## ones load it (VoxelStreamSQLite). One file per world, game version and
## generator version, under user://cache/terrain/; the server keeps its own
## (singleplayer runs one beside the game). Old versions are deleted.
##
## Not on Windows: the voxel module's SQLite commits every saved batch with a
## journal file and full disk syncs, which Windows (and its virus scanner) make
## so slow that chunk loads queue behind the saves for minutes. Generating is
## quick, so there the terrain is simply generated every visit.
const DIR := "user://cache/terrain/"
static var _open := {}  # file -> true while a terrain uses it

## A stream for world `name` built by the scripts/scenes in `sources`, or null
## if that file is already in use in this process (it then just generates).
static func open(name: String, sources: Array) -> VoxelStream:
	if OS.get_name() == "Windows":
		return null
	var stamp := ""
	for path: String in sources:
		stamp += str(FileAccess.get_modified_time(path) if FileAccess.file_exists(path) else 0)
	var role := "server" if Net.is_server() else "game"
	var tag := ("%s|%s|%s" % [name, stamp, Net.VERSION]).md5_text().substr(0, 10)
	var file := "%s%s_%s_%s.sqlite" % [DIR, role, name, tag]
	if _open.has(file): return null
	DirAccess.make_dir_recursive_absolute(DIR)
	_prune(role, name, file.get_file())
	var stream := VoxelStreamSQLite.new()
	stream.database_path = ProjectSettings.globalize_path(file)
	stream.save_generator_output = true
	# Saved chunk keys stay in memory: asking for a chunk never saved doesn't touch the disk.
	stream.set_key_cache_enabled(true)
	stream.set_meta("cache_file", file)
	_open[file] = true
	return stream

## The world that used `stream` is gone: its file may be opened again.
static func close(stream: VoxelStream) -> void:
	if stream and stream.has_meta("cache_file"): _open.erase(str(stream.get_meta("cache_file")))

## Copies for older versions of the same world go.
static func _prune(role: String, name: String, keep: String) -> void:
	for old in DirAccess.get_files_at(DIR):
		if old.begins_with("%s_%s_" % [role, name]) and old != keep and old.ends_with(".sqlite"):
			DirAccess.remove_absolute(DIR+old)
