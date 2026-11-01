extends Node
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(message)
func settle() -> void: await get_tree().create_timer(.4).timeout
func _ready() -> void: _run.call_deferred()
func _run() -> void:
	if not AppSettings.desktop_available():
		push_error("This test requires the desktop display server")
		get_tree().quit(1)
		return
	var original := AppSettings.video.duplicate(true)
	var menus := Menus.new()
	add_child(menus)
	menus.show_pause()
	menus.show_options()
	var settings := original.duplicate(true)
	settings.mode = "fullscreen"
	settings.fullscreen_resolution = Vector2i.ZERO
	settings.gui_scale = "medium"
	settings.vsync = false
	settings.max_fps = 120
	AppSettings.begin_video_preview(settings)
	await settle()
	check(DisplayServer.window_get_mode()==DisplayServer.WINDOW_MODE_FULLSCREEN,"Actual desktop fullscreen mode applied")
	check(get_window().size==DisplayServer.screen_get_size(),"Fullscreen window matches desktop")
	check(is_equal_approx(menus.scale.x,1),"Medium fullscreen UI preserves original size")
	check(DisplayServer.window_get_vsync_mode()==DisplayServer.VSYNC_DISABLED,"V-Sync disabled on actual window")
	check(Engine.max_fps==120,"FPS cap applied")
	check(menus.options.size.is_equal_approx(menus._ui_root.size),"Options fills fullscreen logical canvas")
	AppSettings.revert_video()
	await settle()
	settings.mode = "windowed"
	settings.window_size = Vector2i(960,540)
	settings.gui_scale = "large"
	settings.vsync = true
	AppSettings.begin_video_preview(settings)
	await settle()
	check(DisplayServer.window_get_mode()==DisplayServer.WINDOW_MODE_WINDOWED,"Actual windowed mode applied")
	check(get_window().size==Vector2i(960,540),"Window resolution changes actual window")
	check(is_equal_approx(menus.scale.x,.6),"Large UI scales relative to half-size window")
	check(DisplayServer.window_get_vsync_mode()==DisplayServer.VSYNC_ENABLED,"V-Sync re-enabled")
	check(menus.options._panel.get_global_rect().end.x<=menus._ui_root.size.x and menus.options._panel.get_global_rect().end.y<=menus._ui_root.size.y,"Large settings panel fits small window")
	AppSettings.revert_video()
	await settle()
	settings.mode = "fullscreen"
	settings.fullscreen_resolution = Vector2i(1280,720)
	settings.gui_scale = "medium"
	AppSettings.begin_video_preview(settings)
	await settle()
	check(is_equal_approx(get_window().scaling_3d_scale,1280.0/get_window().size.x),"Fullscreen resolution adjusts actual 3D render scale")
	check(is_equal_approx(menus.scale.x,1),"Lower fullscreen render resolution keeps GUI sharp at original size")
	AppSettings.revert_video()
	await settle()
	check(AppSettings.video==original and is_equal_approx(get_window().scaling_3d_scale,1),"Revert restores original video and rendering")
	menus.free()
	await get_tree().process_frame
	print("DESKTOP VIDEO: %d checks; %d failures" % [checks,failures])
	get_tree().quit(1 if failures else 0)
