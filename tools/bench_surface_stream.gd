extends Node3D
## Surface streaming benchmark: builds a Surface realm at its spawn, then jumps
## the view to another town (as a film cut or a teleport does) and reports how
## long the decor chunks and the voxel terrain take there, at 60 fps.
## godot --headless --path . res://tools/bench_surface_stream.tscn [-- --cold]
## --cold: an empty terrain cache (as a first visit, or a new version).
const TARGET := "Snowbell"
var world: IslandWorld
var viewer := VoxelViewer.new()

func _ready() -> void:
	Engine.max_fps = 60
	FrameTrace.enabled = true
	var cold := "--cold" in OS.get_cmdline_user_args()
	TerrainCache.enabled = not ("--no-cache" in OS.get_cmdline_user_args() or FileAccess.file_exists("res://scripts/_bench/no_cache"))
	if cold: DirAccess.remove_absolute(ProjectSettings.globalize_path(TerrainCache.DIR))
	if cold:
		for file in DirAccess.get_files_at(TerrainCache.DIR): DirAccess.remove_absolute(TerrainCache.DIR+file)
	WorldServer.save_dir = "user://bench/"
	WorldServer.reset_realm("bench_surface")
	world = IslandWorld.new(WorldServer.get_or_create_realm("bench_surface"))
	add_child(world)
	viewer.view_distance = 128
	viewer.requires_collisions = false
	add_child(viewer)
	_run.call_deferred()

func _run() -> void:
	print("BENCH cold=%s generator=%s" % ["--cold" in OS.get_cmdline_user_args(), world.terrain.generator.get_class()])
	await _measure("spawn", world.spawn_point)
	var target := Campaigns.resolve({village = TARGET}, world)
	await _measure("jump to %s (%d m)" % [TARGET, roundi(world.spawn_point.distance_to(target))], target)
	# Leaving while workers still gather: the world must wait for them.
	var away := Campaigns.resolve({village = "Sunveil"}, world)
	for i in 20:
		world.update_streaming(away)
		await get_tree().process_frame
	print("BENCH leaving with %d decor jobs and %d town grids in flight" % [world._decor_jobs.size(), world._town_jobs.size()])
	world.queue_free()
	for i in 10: await get_tree().process_frame
	print("BENCH left cleanly")
	get_tree().quit()

func _measure(label: String, at: Vector3) -> void:
	viewer.global_position = at+Vector3.UP*20.0
	var started := Time.get_ticks_msec()
	var frames := 0
	var worst := 0.0
	var decor := -1.0
	var near := -1.0
	var ring := -1.0
	var last := Time.get_ticks_usec()
	var own := 0.0
	while Time.get_ticks_msec()-started<90000:
		var call := Time.get_ticks_usec()
		world.update_streaming(at)
		own = maxf(own, (Time.get_ticks_usec()-call)/1000.0)
		await get_tree().process_frame
		frames += 1
		var now := Time.get_ticks_usec()
		if (now-last)/1000.0>150.0:
			var tasks: Dictionary = VoxelEngine.get_stats().get("tasks", {})
			print("BENCH   hitch %.0f ms at %.1fs (streaming call max so far %.1f ms) %s" % [(now-last)/1000.0, (Time.get_ticks_msec()-started)/1000.0, own, str(tasks)])
		worst = maxf(worst, (now-last)/1000.0)
		last = now
		var t := (Time.get_ticks_msec()-started)/1000.0
		if decor<0 and world.is_presentation_ready(): decor = t
		if near<0 and _meshed(at, 24.0): near = t
		if ring<0 and _meshed(at, 96.0): ring = t
		if frames%60==0:
			var tasks: Dictionary = VoxelEngine.get_stats().get("tasks", {})
			print("BENCH   %5.1fs streaming=%s generation=%s meshing=%s decor_queue=%d" % [t, tasks.get("streaming"), tasks.get("generation"), tasks.get("meshing"), world._queue.size()])
		if decor>=0 and ring>=0: break
	var rows: Array = []
	for name: String in FrameTrace.sections:
		rows.append([name, FrameTrace.sections[name]])
	rows.sort_custom(func(a: Array, b: Array) -> bool: return a[1].max_us > b[1].max_us)
	for row: Array in rows.slice(0, 6):
		print("BENCH   section %s: max %.1f ms, total %.0f ms, %d calls" % [row[0], row[1].max_us / 1000.0, row[1].total_us / 1000.0, row[1].calls])
	FrameTrace.sections.clear()
	print("BENCH %s: decor ring %.1fs, terrain 24 m %.1fs, terrain 96 m %.1fs, worst frame %.0f ms (streaming call %.1f ms), %d frames" % [label, decor, near, ring, worst, own, frames])

func _meshed(at: Vector3, reach: float) -> bool:
	var terrain := world.terrain
	var center := terrain.to_local(at)
	var box := (terrain.global_basis.inverse()*Vector3(reach, 12, reach)).abs()
	return terrain.is_area_meshed(AABB(center-box, box*2.0))
