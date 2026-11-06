extends Node3D
## Isolated integration checks, run with XDG_DATA_HOME pointing at a temp folder.
var errors := 0
func check(condition: bool, message: String) -> void:
	if not condition: errors += 1; push_error("AUDIO CHECK: "+message)
	else: print("AUDIO PASS: ",message)
func _ready() -> void: run.call_deferred()
func routed_through(bus: String, target: String) -> bool:
	for i in AudioServer.bus_count:
		if bus == target: return true
		if bus == "Master": return false
		bus = AudioServer.get_bus_send(AudioServer.get_bus_index(bus))
	return false
func run() -> void:
	GameServer.set_physics_process(false)
	WorldServer.set_process(false)
	var player := Player.new()
	player.player_id = GameServer.join(false)
	player.stats = GameServer.character(player.player_id)
	add_child(player)
	add_child(player.aim_marker)
	player.frozen = false
	player.set_physics_process(false)
	var world := GameWorld.new()
	world.realm_id = "hall"
	add_child(world)
	GameAudio.set_context(player,world)
	var original := AppSettings.audio.duplicate(true)
	for entry in GameAudio.events.values():
		for path in entry.get("paths",[]): check(GameAudio._stream(str(path),bool(entry.get("loop",false)))!=null,"asset "+str(path))
	for mode in ["headphones","speakers","surround"]:
		var prefs := original.duplicate()
		prefs.output_mode = mode
		AppSettings.set_audio(prefs)
		var voice := GameAudio.play("bow",Vector3(4,1,-3),{source_id=mode,cooldown=0})
		check(not voice.is_empty(),mode+" creates positional voice")
		await get_tree().create_timer(.08).timeout
		check(voice.players.size()==(1 if mode=="surround" else 2),mode+" output routing")
		check(voice.players.all(func(p: Node) -> bool: return routed_through(p.bus,"Effects")),mode+" spatial SFX uses effects width")
		var ambient := GameAudio.play("ambience.fire_close",Vector3(3,1,-2),{bus="Ambience",cooldown=0})
		var music := GameAudio.play("music.japanese",Vector3.INF,{bus="Music",cooldown=0})
		check(ambient.players.all(func(p: Node) -> bool: return not routed_through(p.bus,"Effects")),mode+" spatial ambience bypasses SFX width")
		check(music.players.all(func(p: Node) -> bool: return not routed_through(p.bus,"Effects")),mode+" music bypasses SFX width")
		GameAudio.stop(ambient,.02)
		GameAudio.stop(music,.02)
		GameAudio.stop(voice,.02)
	var own_shot := GameAudio.weapon_shot(Items.make("G1_bow"),Vector3(9,1,-7))
	check(not own_shot.is_empty() and not own_shot.positional and own_shot.players.size()==1,
		"Own firing stays centered regardless of muzzle or aim direction")
	var remote_shot := GameAudio.weapon_shot(Items.make("G1_bow"),Vector3(4,1,-3),true)
	check(not remote_shot.is_empty() and remote_shot.positional,"Other players' firing retains its world source")
	var prefs := original.duplicate()
	prefs.ally_sounds = false
	AppSettings.set_audio(prefs)
	check(GameAudio.play("wand",Vector3.ZERO,{ally=true,source_id=987}).is_empty(),"ally mute")
	prefs.ui_sounds = false
	AppSettings.set_audio(prefs)
	check(GameAudio.play("ui_click").is_empty(),"interface mute")
	check(not GameAudio.play("warning_pulse",Vector3.ZERO,{source_id=988}).is_empty(),"warning survives interface mute")
	prefs.music = .23
	prefs.ambience = .31
	AppSettings.set_audio(prefs)
	AppSettings.load_preferences()
	check(is_equal_approx(AppSettings.audio.music,.23) and is_equal_approx(AppSettings.audio.ambience,.31),"preferences persist")
	AppSettings.set_audio(original)
	check(GameAudio.enemy_death_event(Enemies.get_def("goblin_master")) == "enemy_die"
		and GameAudio.enemy_death_event(Enemies.get_def("crab")) == "small_enemy_die", "Death clips follow enemy size instead of random selection")
	for seconds in [2.0, 3.0, 5.0]:
		var build := GameAudio.play(GameAudio.rumble_event(seconds), Vector3.ZERO, {fixed_pitch=true,duration=seconds,cooldown=0})
		check(not build.is_empty() and is_zero_approx(build.seek) and is_equal_approx(build.pitch,1.0)
			and absf(float(build.length)-seconds)<.01, "Rumble starts at zero and reaches its peak at %ss without repitching" % seconds)
		GameAudio.stop(build,.01)
	var walker := RemotePlayer.new()
	world.add_child(walker)
	var before_steps := GameAudio.voices.filter(func(v: Dictionary) -> bool: return str(v.event).begins_with("step_")).size()
	for frame in 100:
		if frame % 4 == 0: walker.position.x += .1
		GameAudio._update_footsteps(1.0 / 240.0)
	check(GameAudio.voices.filter(func(v: Dictionary) -> bool: return str(v.event).begins_with("step_")).size() > before_steps,
		"Walking remains audible when rendering runs four times per physics move")
	walker.queue_free()
	var a := GameAudio.play("hurt",Vector3.ZERO,{cooldown=0})
	var b := GameAudio.play("hurt",Vector3.ZERO,{cooldown=0})
	check(a.stream!=b.stream,"variants do not repeat consecutively")
	check(absf(float(a.pitch)-1)<=.0351,"subtle pitch variation")
	var rumble := GameAudio.play("boss_rumble",Vector3.ZERO,{align_end=.6,cooldown=0})
	check(is_equal_approx(rumble.pitch,1) and rumble.seek>0,"rumble timing without repitch")
	player.shield.active = true
	await get_tree().create_timer(.6).timeout
	check(GameAudio._lowpass.cutoff_hz<2000,"shield smoothly muffles game mix")
	var held_loop: Dictionary = GameAudio._shield
	var held_raise: Dictionary = GameAudio._shield_cast
	check(held_loop.get("loop",false) and not held_loop.get("stopping",true),"Holding shield sustains the loop")
	player.shield.active = false
	await get_tree().create_timer(.8).timeout
	check(GameAudio._lowpass.cutoff_hz>19000,"shield smoothly releases filter")
	check(held_loop.get("stopping",false) and held_loop.players.is_empty(),"Releasing shield stops the sustain loop")
	check(held_raise.get("stopping",false) and held_raise.players.is_empty(),"Releasing shield also stops the six-second raise sound")
	world.realm_id = "dng_magma_42"
	GameAudio._update_context()
	check(GameAudio._ambience.has("ambience.cinematic") and not GameAudio._ambience.has("ambience.fire_dungeon"),"Dungeons use cinematic ambience, including fire dungeons")
	world.realm_id = "hall"
	# Verify that binaural routing produces the correct ear energy in the mixer.
	prefs = original.duplicate()
	prefs.output_mode = "headphones"
	prefs.music = 0
	prefs.ambience = 0
	AppSettings.set_audio(prefs)
	for voice in GameAudio.voices: GameAudio.stop(voice,.01)
	await get_tree().create_timer(.3).timeout
	var recorder := AudioEffectRecord.new()
	recorder.format = AudioStreamWAV.FORMAT_16_BITS
	var master := AudioServer.get_bus_index("Master")
	AudioServer.add_bus_effect(master,recorder)
	recorder.set_recording_active(true)
	GameAudio.play("test",Vector3(-5,1.4,0),{fixed_pitch=true,source_id=998,cooldown=0})
	await get_tree().create_timer(.7).timeout
	recorder.set_recording_active(false)
	var recording := recorder.get_recording()
	var left := 0.0
	var right := 0.0
	for sample in recording.data.size()/4:
		left += pow(float(recording.data.decode_s16(sample*4)),2)
		right += pow(float(recording.data.decode_s16(sample*4+2)),2)
	check(left>right*2 and left>0,"headphone mixer favors the source-side ear")
	# Width narrows SFX, while music and ambience bypass its bus.
	check(is_equal_approx(GameAudio._width.pan_pullout,.35),"headphone default width is narrow")
	prefs.stereo_width = 0.0
	AppSettings.set_audio(prefs)
	check(is_zero_approx(GameAudio._width.pan_pullout),"width slider reaches mono")
	prefs.stereo_width = 1.0
	AppSettings.set_audio(prefs)
	check(is_equal_approx(GameAudio._width.pan_pullout,1),"width slider reaches full stereo")
	prefs.stereo_width = .35
	AppSettings.set_audio(prefs)
	var step := GameAudio.footstep(Vector3.ZERO,false,91234)
	check(not step.is_empty() and step.stream is AudioStreamWAV,"synthesized footstep uses cached PCM")
	await get_tree().create_timer(.5).timeout
	var tone := GameAudio.play("test",Vector3.INF,{loop=true,fixed_pitch=true,cooldown=0})
	await get_tree().create_timer(.15).timeout
	recorder.set_recording_active(true)
	await get_tree().create_timer(.15).timeout
	# Simulate a severe main-thread generation/compilation hitch. Audio must
	# continue mixing while no game scripts can produce frames or samples.
	var before_stall: float = tone.players[0].get_playback_position()
	OS.delay_msec(400)
	var after_stall: float = tone.players[0].get_playback_position()
	print("STALL playback advanced=",fposmod(after_stall-before_stall,.5))
	await get_tree().create_timer(.45).timeout
	recorder.set_recording_active(false)
	var continuous := recorder.get_recording()
	var frames := continuous.data.size()/4
	var window := int(continuous.mix_rate*.05)
	var silent := 0
	for first in range(window,frames-window,window):
		var energy := 0.0
		for frame in range(first,first+window): energy += pow(float(continuous.data.decode_s16(frame*4)),2)
		if energy/window<100: silent += 1
	print("CONTINUITY seconds=",float(frames)/continuous.mix_rate," silent_windows=",silent)
	continuous.save_to_wav("/home/hugo/tmp/void_audio_continuity.wav")
	check(frames>continuous.mix_rate*.5 and silent==0,"mixer stays audible through a 400 ms main-thread stall")
	GameAudio.stop(tone,.03)
	AudioServer.remove_bus_effect(master,AudioServer.get_bus_effect_count(master)-1)
	AppSettings.set_audio(original)
	var relay := NetServer.new()
	Net.server = relay
	Net.mode = Net.Mode.SERVER
	GameAudio.play("boss_riser",Vector3.ZERO,{realm="audio_review",source_id=99123,cooldown=0,align_end=.4})
	var packet: Array = relay._pending["audio_review"][0].ev
	check(packet.size()==5 and packet[1]=="sfx" and packet[2]=="boss_riser","server stamps realm audio packet once")
	Net.mode = Net.Mode.OFFLINE
	Net.server = null
	var receiver := NetClient.new()
	receiver.world = world
	var count := GameAudio.voices.size()
	receiver._apply(packet)
	# Client throttling uses the server's source identity. Clear only this test
	# cooldown to model the independent process that receives the packet.
	GameAudio._cooldowns.erase("boss.riser:99123")
	receiver._apply(packet)
	check(GameAudio.voices.size()>count,"client receives positional realm audio")
	receiver.free()
	for child in [relay.api,relay.social,relay.dungeons,relay.campaigns,relay.economy]: child.free()
	relay.free()
	var owner := Node3D.new()
	world.add_child(owner)
	var looped := GameAudio.loop("shield_loop",owner,{bus="Shield"})
	owner.queue_free()
	await get_tree().create_timer(.6).timeout
	check(looped.stopping and looped.players.is_empty(),"owner removal releases loop")
	var panel := OptionsPanel.new()
	add_child(panel)
	panel.open_page()
	panel.tabs.current_tab = 1
	await get_tree().process_frame
	check(panel.tabs.get_child(1).get_child_count()>0,"audio settings page builds")
	if "--preview" in OS.get_cmdline_user_args():
		await get_tree().create_timer(.5).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("/home/hugo/Desktop/Void-of-Exile-Audio-Settings.png")
	GameAudio.set_context(null, null)
	for v in GameAudio.voices: GameAudio.stop(v,.01)
	player.queue_free()
	world.queue_free()
	panel.queue_free()
	await get_tree().create_timer(.2).timeout
	print("AUDIO TEST RESULT: ", "PASS" if errors==0 else "FAIL", " / ",errors," failures")
	get_tree().quit(0 if errors==0 else 1)
