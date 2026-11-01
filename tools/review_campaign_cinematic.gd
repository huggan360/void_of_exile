extends Node3D
## Run with -- --out=/tmp/c to capture loading and both drone shots.
const Cinematic = preload("res://scripts/ui/campaign_cinematic.gd")
var _player := Player.new()
var _cinematic := Cinematic.new()
var _out := ""
var _elapsed := 0.0
var _capture := 0
var _finished := 0
var _hud := CanvasLayer.new()
var _capturing := false
var _verifying := false

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): _out = arg.trim_prefix("--out=")
	var atmosphere := Atmosphere.new()
	add_child(atmosphere)
	atmosphere.snap_to(Biomes.neutral())
	_player.player_id = GameServer.join(false)
	_player.stats = GameServer.character(_player.player_id)
	add_child(_player)
	var world: HallWorld = $Tavern
	_player.ground_height = world.ground_height
	_player.hazard = world.is_hazard
	_player.road = world.is_road
	_player.place(world.spawn_point,world.terrain,world.is_walkable)
	_player.refresh_gear()
	add_child(_hud)
	var marker := UIStyle.label("HUD must be hidden during cinematic",24)
	_hud.add_child(marker)
	add_child(_cinematic)
	_cinematic.finished.connect(func() -> void: _finished += 1)
	_cinematic.play(_player,{
		title = "The Lily Thief",
		loading = {title = "The Lily Thief",subtitle = "A Hearthhaven tale",seconds = 3.0},
		shots = [
			{from = Vector3(-25,29,3),to = Vector3(-12,25,-8),look_from = Vector3(0,16,-42),look_to = Vector3(0,16,-48),duration = 6.0,
				cards = [{text = "Every evening, Hearthhaven closes its doors.",at = .5,hold = 1.2},
					{text = "But something still wanders the gardens.",at = 3.5,hold = 1.2}]},
			{from = Vector3(24,24,57),to = Vector3(16,21,40),look_from = Vector3(-4,11,38),look_to = Vector3(-9,11,28),duration = 6.0,
				cards = [{text = "Somebody has been eating Gerald's lilies.",at = .6,hold = 3.5}]}
		]
	})

func _process(delta: float) -> void:
	_elapsed += delta
	if not _out.is_empty() and _capture<3 and not _capturing:
		var times := [1.4,5.7,12.2]
		if _elapsed>=times[_capture]:
			_capturing = true
			await RenderingServer.frame_post_draw
			_capture += 1
			var path := "%s_%d.png" % [_out,_capture]
			var error := get_viewport().get_texture().get_image().save_png(path)
			assert(error==OK,"Could not save "+path)
			print("Captured ",path)
			_capturing = false
	if _elapsed>16 and _finished>0 and not _verifying:
		_verifying = true
		assert(_finished==1,"finished must emit once")
		assert(not _cinematic.is_playing() and not _player.cinematic_locked)
		assert(_player.camera.current and _hud.visible,"Camera and HUD must be restored")
		_cinematic.cancel()
		assert(_finished==1,"Idle cancellation must not emit finished")
		await _check_interruptions()
		print("Campaign cinematic review passed: completion, skip, cancel, empty script, camera, HUD and lock restoration.")
		get_tree().quit()

func _check_interruptions() -> void:
	var count := _finished
	_cinematic.play(_player,{loading = {title = "Skip check",seconds = 20.0}})
	assert(_player.cinematic_locked and not _hud.visible)
	var key := InputEventKey.new()
	key.keycode = KEY_SPACE
	key.physical_keycode = KEY_SPACE
	key.pressed = true
	Input.parse_input_event(key)
	await get_tree().create_timer(.35).timeout
	assert(_cinematic.is_playing(),"Short presses must not skip")
	key.pressed = false
	Input.parse_input_event(key)
	await get_tree().create_timer(.1).timeout
	assert(_cinematic.is_playing())
	key.pressed = true
	Input.parse_input_event(key)
	await get_tree().create_timer(.9).timeout
	key.pressed = false
	Input.parse_input_event(key)
	assert(not _cinematic.is_playing() and _finished==count+1,"Held Space must skip once")
	assert(_player.camera.current and _hud.visible and not _player.cinematic_locked)
	_player.cinematic_locked = true
	_cinematic.play(_player,{loading = {seconds = 20.0}})
	_cinematic.cancel()
	assert(_finished==count+2 and _player.cinematic_locked,"Cancel must preserve an existing lock")
	assert(_player.camera.current and _hud.visible)
	_player.cinematic_locked = false
	_cinematic.play(_player,{})
	assert(_finished==count+3 and not _cinematic.is_playing(),"Empty scripts must finish immediately")
	_cinematic.cancel()
	assert(_finished==count+3)
