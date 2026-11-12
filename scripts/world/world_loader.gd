class_name WorldLoader
extends Node
## One preparation worker owns detached world data and uncached mesh resources.
## Active SceneTree changes and rendering nodes stay on the main thread.
signal progress_changed(value: float)
var _thread: Thread
var _mutex := Mutex.new()
var _progress := 0.0
var _cancelled := false
var _busy := false
var _retired: Array[Node] = []

func prepare(destination: String, record: Dictionary) -> GameWorld:
	if _busy: return null
	_busy = true
	_mutex.lock()
	_cancelled = false
	_progress = 0.02
	_mutex.unlock()
	var kind := "island"
	var detached: GameWorld
	if Campaigns.is_tavern(destination):
		kind = "tavern"
		var packed := await _resource("res://scenes/home/tavern.tscn") as PackedScene
		if packed == null:
			_busy = false
			return null
		detached = packed.instantiate() as GameWorld
		detached.realm_id = destination
		if destination!="hall":
			detached.campaign_tavern = true
			detached.display_name = str(record.get("name",detached.display_name))
	elif record.get("castle",false):
		kind = "castle"
		var packed := await _resource("res://scenes/castle/hollow_castle.tscn") as PackedScene
		if packed == null:
			_busy = false
			return null
		detached = packed.instantiate() as GameWorld
		detached.realm_id = str(record.id)
		detached.display_name = str(record.get("name","The Hollow Castle"))
	elif record.get("chambers",false): kind = "chambers"
	elif record.get("space",false): kind = "space"
	elif record.has("dungeon"): kind = "dungeon"
	var layout := {}  # the Surface is baked (SurfaceMap); no hand layout to load
	var models: Array[String] = []
	# Resolve registries on the main thread; the worker gets immutable names.
	var enemy_ids: Array = Enemies.all_ids() if kind=="island" else []
	if kind=="castle": enemy_ids = ["castle_knight","castle_champion","hollow_king"]
	if kind=="space": enemy_ids = ["hull_skitter","void_lamprey"]
	if kind=="dungeon":
		var definition := Dungeons.definition(str(record.dungeon))
		for key in ["boss","miniboss","treasure"]:
			if definition.has(key) and str(definition[key])!="": enemy_ids.append(str(definition[key]))
		for key in ["low_enemies","mid_enemies","high_enemies"]: enemy_ids.append_array(definition.get(key,[]))
		var support_ids: Dictionary = {goblin_king=["cave_slinger","goblin_brute"],abyssal_siren=["tide_wisp","grotto_crab"],
			drowned_cantor=["choir_wraith","drowned_acolyte"],gilded_vizier=["tomb_scarab","sun_priest"],
			magma_warden=["cinder_cultist"],pyre_ent=["cinder_sapling","flame_dryad"]}
		enemy_ids.append_array(support_ids.get(str(definition.get("boss","")),[]))
	if kind!="tavern":
		for id: String in enemy_ids:
			var def := Enemies.get_def(id)
			if not def.model in models: models.append(def.model)
			if def is BossDef and def.shell_model!="" and not def.shell_model in models: models.append(def.shell_model)
	else:
		for marker in detached.get_node("Residents").get_children():
			var model := "npc_"+str(marker.role)
			if FileAccess.file_exists("res://creatures/"+model+"/rig.json") and not model in models: models.append(model)
	if cancelled():
		if is_instance_valid(detached): retire(detached)
		_busy = false
		return null
	_thread = Thread.new()
	var error := _thread.start(_prepare.bind(kind,record.duplicate(true),detached,layout,models))
	if error!=OK:
		_thread = null
		_busy = false
		if is_instance_valid(detached): retire(detached)
		return null
	while _thread.is_alive():
		progress_changed.emit(progress())
		await get_tree().process_frame
	var result: GameWorld = _thread.wait_to_finish() as GameWorld
	_thread = null
	_busy = false
	if cancelled():
		if is_instance_valid(result): retire(result)
		return null
	progress_changed.emit(0.85)
	return result

func _prepare(kind: String, record: Dictionary, detached: GameWorld, layout: Dictionary, models: Array[String]) -> GameWorld:
	var result := detached
	match kind:
		"island": result = IslandWorld.new(record,layout)
		"dungeon": result = Dungeons.create_world(record)
		"chambers": result = ChambersWorld.new(record)
		"space": result = SpaceWorld.new(record)
	_set_progress(0.18)
	for index in models.size():
		if cancelled(): return result
		CreatureModel.preload_creature(models[index],true)
		_set_progress(0.18+0.32*float(index+1)/maxi(1,models.size()))
	if result.has_method("prepare_load"): result.call("prepare_load")
	if result is IslandWorld:
		result._warm_stream_assets()
		result.set_meta("assets_prepared",true)
	if kind=="castle":
		for prop in result.get_node("Props").get_children():
			if prop.has_method("warm_asset"): prop.warm_asset()
	_set_progress(0.62)
	if not cancelled():
		result.set_meta("prepared_fog",{} if result is SpatialWorld else FogOfWar.prepare_maps(result.half_extent,result.biome_at,result.ground_height))
	result.set_meta("asynchronous_load",true)
	_set_progress(0.82)
	return result

func _resource(path: String) -> Resource:
	if ResourceLoader.has_cached(path): return load(path)
	var error := ResourceLoader.load_threaded_request(path)
	if error!=OK and error!=ERR_BUSY: return null
	while ResourceLoader.load_threaded_get_status(path)==ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		await get_tree().process_frame
	if ResourceLoader.load_threaded_get_status(path)!=ResourceLoader.THREAD_LOAD_LOADED: return null
	return ResourceLoader.load_threaded_get(path)

func _set_progress(value: float) -> void:
	_mutex.lock()
	_progress = value
	_mutex.unlock()

func progress() -> float:
	_mutex.lock()
	var value := _progress
	_mutex.unlock()
	return value

func cancel_prepare() -> void:
	_mutex.lock()
	_cancelled = true
	_mutex.unlock()

func is_preparing() -> bool:
	return _busy

func cancelled() -> bool:
	_mutex.lock()
	var value := _cancelled
	_mutex.unlock()
	return value

## Detached old trees are dismantled within a small per-frame budget instead
## of deleting every mesh/physics RID in one queue_free frame.
func retire(root: Node) -> void:
	if root.get_parent(): root.get_parent().remove_child(root)
	# Constructors own these helpers before ready() attaches them. A cancelled
	# preparation must also dispose of helpers which never entered the tree.
	var helpers: Array[Node] = []
	if root is IslandWorld: helpers = [root.enemy_director,root.gates]
	elif root is DungeonWorld or root is TheoryWorld or root is SpaceWorld: helpers = [root.enemy_director]
	elif root is CastleWorld: helpers = [root.enemy_director]
	for helper in helpers:
		if is_instance_valid(helper) and helper.get_parent()==null: _retired.append(helper)
	_retired.append(root)

func _process(_delta: float) -> void:
	var deadline := Time.get_ticks_usec()+800
	while not _retired.is_empty() and Time.get_ticks_usec()<deadline:
		var node: Node = _retired.back()
		if not is_instance_valid(node):
			_retired.pop_back()
			continue
		if node.get_child_count()>0:
			var child: Node = node.get_child(node.get_child_count()-1)
			node.remove_child(child)
			_retired.append(child)
		else:
			node.free()
			_retired.pop_back()

func _exit_tree() -> void:
	cancel_prepare()
	if _thread!=null:
		var unfinished: GameWorld = _thread.wait_to_finish() as GameWorld
		if is_instance_valid(unfinished): retire(unfinished)
		_thread = null
	for node in _retired:
		if is_instance_valid(node): node.free()
	_retired.clear()
