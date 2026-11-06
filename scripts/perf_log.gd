extends Node
## Lag hunting: launch with `-- --perf-log` and everything lands in
## res://perf_logs/perf_<time>.log. Off (and freed) otherwise.
##   every second  FPS, worst frame, process/physics time, memory, objects,
##                 orphans, resources, draw calls, video memory, voxel tasks,
##                 the FrameTrace sections that cost the most
##   every 5 s     node counts per script/class, with what grew since last time
##   on a hitch    (frame > 33 ms) which FrameTrace sections ate that frame
##   always        terrain blocks loaded/unloaded, and every spawned node of a
##                 gameplay script (enemies, loot bags, projectiles...) tallied

const HITCH_MS := 33.0
var _file: FileAccess
var _second := 0.0
var _census_timer := 0.0
var _frames := 0
var _worst_ms := 0.0
var _hitches := 0
var _prev_totals := {}
var _census := {}
var _spawns := {}
var _blocks_loaded := 0
var _blocks_unloaded := 0
var _start_ms := 0
var _pipelines := {}
const PIPELINE_INFO := {canvas = RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_CANVAS,
	mesh = RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_MESH,
	surface = RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_SURFACE,
	draw = RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_DRAW,
	spec = RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_SPECIALIZATION}


func _ready() -> void:
	if not "--perf-log" in OS.get_cmdline_user_args():
		queue_free()
		return
	var dir := ProjectSettings.globalize_path("res://perf_logs")
	DirAccess.make_dir_recursive_absolute(dir)
	var path := dir + "/perf_%s.log" % Time.get_datetime_string_from_system().replace(":", "-")
	_file = FileAccess.open(path, FileAccess.WRITE)
	print("PERF LOG -> ", path)
	_start_ms = Time.get_ticks_msec()
	FrameTrace.enabled = true
	process_priority = -1000
	_log("START %s  cpu=%s  gpu=%s  threads=%d" % [Engine.get_version_info().string, OS.get_processor_name(),
		RenderingServer.get_video_adapter_name(), OS.get_processor_count()])
	get_tree().node_added.connect(_on_node_added)
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)


## Shader pipelines compiled since the last call (a stall while new materials compile).
func _pipeline_delta() -> String:
	var parts := PackedStringArray()
	for k: String in PIPELINE_INFO:
		var now := RenderingServer.get_rendering_info(PIPELINE_INFO[k])
		var grew := now - int(_pipelines.get(k, now))
		_pipelines[k] = now
		if grew > 0: parts.append("%s+%d" % [k, grew])
	return ",".join(parts) if not parts.is_empty() else "none"


## Render timing of the last frame, compiles, and the voxel engine's queue.
func _render_state() -> String:
	var vp := get_viewport().get_viewport_rid()
	var text := "gpu=%.1fms render_cpu=%.1fms compiles=%s" % [RenderingServer.viewport_get_measured_render_time_gpu(vp),
		RenderingServer.viewport_get_measured_render_time_cpu(vp), _pipeline_delta()]
	if Engine.has_singleton("VoxelEngine"):
		var tasks: Dictionary = Engine.get_singleton("VoxelEngine").get_stats().get("tasks", {})
		text += " voxel_tasks=%s" % str(tasks).replace(" ", "")
	return text


func _log(line: String) -> void:
	_file.store_line("[%8.2f] %s" % [(Time.get_ticks_msec() - _start_ms) / 1000.0, line])


func _on_node_added(node: Node) -> void:
	# Terrain streaming: hook its block signals when a terrain appears.
	for sig: String in ["block_loaded", "block_unloaded"]:
		if node.has_signal(sig):
			node.connect(sig, _on_block.bind(sig))
	var kind := _kind(node)
	if kind != "":
		_spawns[kind] = int(_spawns.get(kind, 0)) + 1


func _on_block(_pos: Variant, sig: String) -> void:
	if sig == "block_loaded": _blocks_loaded += 1
	else: _blocks_unloaded += 1


## Gameplay scripts only (named classes or script file names), not engine nodes.
func _kind(node: Node) -> String:
	var script: Script = node.get_script()
	if script == null: return ""
	var name := script.get_global_name()
	return str(name) if name != &"" else script.resource_path.get_file().get_basename()


func _process(delta: float) -> void:
	if _file == null: return
	var ms := delta * 1000.0
	_frames += 1
	_worst_ms = maxf(_worst_ms, ms)
	# FrameTrace sections spent during the frame that just ended.
	var frame := {}
	for section: String in FrameTrace.sections:
		var total: int = FrameTrace.sections[section].total_us
		var spent: int = total - int(_prev_totals.get(section, 0))
		if spent > 0: frame[section] = spent
		_prev_totals[section] = total
	if ms > HITCH_MS:
		_hitches += 1
		var keys := frame.keys()
		keys.sort_custom(func(a: String, b: String) -> bool: return frame[a] > frame[b])
		var parts := PackedStringArray()
		for k: String in keys.slice(0, 8): parts.append("%s=%.1fms" % [k, frame[k] / 1000.0])
		_log("HITCH %.1fms  %s  nodes=%d  %s" % [ms, _render_state(), Performance.get_monitor(Performance.OBJECT_NODE_COUNT), "  ".join(parts)])
	elif _frames % 30 == 0:
		_pipeline_delta()  # keep the compile counter current between hitches
	_second += delta
	if _second >= 1.0:
		_second = 0.0
		_log_second()
	_census_timer += delta
	if _census_timer >= 5.0:
		_census_timer = 0.0
		_log_census()


func _log_second() -> void:
	var P := Performance
	_log("SEC fps=%d worst=%.1fms hitches=%d proc=%.1fms phys=%.1fms mem=%.0fMB vram=%.0fMB obj=%d nodes=%d orphans=%d res=%d draws=%d objs_drawn=%d phys_active=%d blocks+%d/-%d" % [
		_frames, _worst_ms, _hitches, P.get_monitor(P.TIME_PROCESS) * 1000.0, P.get_monitor(P.TIME_PHYSICS_PROCESS) * 1000.0,
		P.get_monitor(P.MEMORY_STATIC) / 1048576.0, P.get_monitor(P.RENDER_VIDEO_MEM_USED) / 1048576.0,
		P.get_monitor(P.OBJECT_COUNT), P.get_monitor(P.OBJECT_NODE_COUNT), P.get_monitor(P.OBJECT_ORPHAN_NODE_COUNT),
		P.get_monitor(P.OBJECT_RESOURCE_COUNT), P.get_monitor(P.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		P.get_monitor(P.RENDER_TOTAL_OBJECTS_IN_FRAME), P.get_monitor(P.PHYSICS_3D_ACTIVE_OBJECTS),
		_blocks_loaded, _blocks_unloaded])
	# Heaviest FrameTrace sections this second.
	var rows := PackedStringArray()
	var names := FrameTrace.sections.keys()
	names.sort_custom(func(a: String, b: String) -> bool: return FrameTrace.sections[a].total_us > FrameTrace.sections[b].total_us)
	for n: String in names.slice(0, 10):
		var r: Dictionary = FrameTrace.sections[n]
		rows.append("%s=%.1fms(max %.1f, x%d)" % [n, r.total_us / 1000.0, r.max_us / 1000.0, r.calls])
	if not rows.is_empty(): _log("  SECTIONS " + "  ".join(rows))
	if not _spawns.is_empty(): _log("  SPAWNS " + str(_spawns))
	if Engine.has_singleton("VoxelEngine"):
		_log("  VOXEL " + str(Engine.get_singleton("VoxelEngine").get_stats()))
	FrameTrace.sections.clear()
	_prev_totals.clear()
	_spawns.clear()
	_frames = 0
	_worst_ms = 0.0
	_hitches = 0
	_blocks_loaded = 0
	_blocks_unloaded = 0
	_file.flush()


## Live node count per kind; reports totals and growth (leaks show up here).
func _log_census() -> void:
	var started := Time.get_ticks_usec()
	var counts := {}
	var stack: Array[Node] = [get_tree().root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		var kind := _kind(node)
		if kind == "": kind = node.get_class()
		counts[kind] = int(counts.get(kind, 0)) + 1
		stack.append_array(node.get_children(true))
	var keys := counts.keys()
	keys.sort_custom(func(a: String, b: String) -> bool: return counts[a] > counts[b])
	var parts := PackedStringArray()
	for k: String in keys.slice(0, 25):
		var grew: int = counts[k] - int(_census.get(k, counts[k]))
		parts.append("%s=%d%s" % [k, counts[k], ("(%+d)" % grew) if grew != 0 else ""])
	_census = counts
	_log("CENSUS (%.1fms) %s" % [(Time.get_ticks_usec() - started) / 1000.0, "  ".join(parts)])
