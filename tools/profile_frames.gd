extends Node
var frames := []
var game: Node
var route := false
var route_origin := Vector3.ZERO
var last := 0
var started := 0
var output := "/home/hugo/tmp/void_performance/baseline.json"
func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg=="--profile-route": route = true
		if arg.begins_with("--profile-out="): output = arg.trim_prefix("--profile-out=")
	FrameTrace.enabled = true
	get_tree().root.tree_exiting.connect(save)
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(),true)
	game = load("res://main.tscn").instantiate()
	add_child(game)
	route_origin = game.player.global_position
	Engine.max_fps = 160
	started = Time.get_ticks_usec()
	last = started
func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	if route and (now-started)>3000000 and game.world is IslandWorld:
		var progress := float(now-started-3000000)/1000000.0
		var at := route_origin+Vector3(progress*10,0,progress*3)
		game.player.global_position = Vector3(at.x,game.world.ground_height(at.x,at.z)+.1,at.z)
	frames.append({at_us=now,t=(now-started)/1000000.0,ms=(now-last)/1000.0,
		process_ms=Performance.get_monitor(Performance.TIME_PROCESS)*1000,
		physics_ms=Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000,
		gpu_ms=RenderingServer.viewport_get_measured_render_time_gpu(get_viewport().get_viewport_rid()),
		draws=Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)})
	last = now
func save() -> void:
	DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify({frames=frames,slow=FrameTrace.slow,sections=FrameTrace.sections,graphics=AppSettings.graphics,gpu=RenderingServer.get_video_adapter_name()},"\t"))
	print("Frame profile saved: ",output," frames=",frames.size())
