extends Node
## Client soundscape. Native 3D output for surround; a binaural approximation
## for headphones uses ear delay, level difference and directional filtering.
signal test_step(label: String)
const MAX_VOICES := 48
# Balance the authored music against effects/ambience without changing sliders.
# Both battle layers share this trim, preserving their relative mix.
const MUSIC_MIX_GAIN_DB := 6.0
const MUSIC_DUCK_DB := 2.0
const SECTORS := 12
const ALIASES := {
	bow="projectile.arrow", wand="projectile.wand", fireball="projectile.fireball", enemy_shot="projectile.enemy_wind",
	hurt="combat.hit", enemy_hurt="combat.enemy_hurt", enemy_die="combat.enemy_death", boss_hurt="combat.boss_hurt", boss_die="combat.boss_death",
	small_enemy_die="combat.small_enemy_death",
	boss_impact="combat.boss_impact", boss_rumble="combat.boss_rumble", boss_riser="boss.riser",
	shield_up="magic.shield_cast", shield_loop="magic.shield_loop", magic_ring="magic.ring",
	magic_impact="combat.magic_hit", heal="player.heal", potion="item.potion", equip="item.equip",
	magic_explosion="magic.explosion",
	dot_gain="progression.dot_gain", warning_pulse="ui.warning_pulse", ui_click="ui.click", ui_hover="ui.hover",
	party_invite="notification.party_invite", campaign_complete="notification.campaign_complete"
}
var events := {}
var voices: Array[Dictionary] = []
var _streams := {}
var _loop_offsets := {}
var _last_variant := {}
var _cooldowns := {}
var _random := RandomNumberGenerator.new()
var _listener := AudioListener3D.new()
var _player: Player
var _world: GameWorld
var _scene_id := 0
var _ambience := {}
var _emitters := {}
var _remote_shields := {}
var _music := {}
var _music_key := ""
var _music_layer := {}
var _music_layer_key := ""
var _music_encounter := ""
var _music_defeated := {}
var _gear_signature := ""
var _shield := {}
var _shield_cast := {}
var _shield_up := false
var _bubble := 0.0
var _lowpass: AudioEffectLowPassFilter
var _reverb: AudioEffectReverb
var _compressor: AudioEffectCompressor
var _width: AudioEffectStereoEnhance
var _mix_tick := 0.0
var _footsteps := {}
var _mix_eq: AudioEffectEQ6
var _tick := 0.0
var _disabled := false
var _test_token := 0
var _test_label := ""
var _last_mode := ""
var _duck := 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_disabled = "--dedicated" in OS.get_cmdline_user_args()
	_random.randomize()
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://assets/audio/manifest.json"))
	if parsed is Dictionary: events = parsed.get("events",{})
	_customize_events()
	for entry: Dictionary in events.values():
		for path in entry.get("paths", []):
			_loop_offsets[str(path)] = float(entry.get("loop_offset", 0.0))
	if _disabled: set_process(false); return
	_build_buses()
	add_child(_listener)
	AppSettings.audio_changed.connect(_apply_settings)
	get_tree().node_added.connect(_node_added)
	_apply_settings()
	_warm_audio()

func _warm_audio() -> void:
	# Resolve imported resources and synthesize utility PCM before world streaming.
	for entry in events.values():
		for path in entry.get("paths",[]): _stream(str(path),bool(entry.get("loop",false)))
	for kind in ["trident","flight","portal","xp_pickup","test","test_bass"]: _synth_stream(kind,kind in ["flight","portal"])
	for surface in ["stone","grass","sand","wood"]:
		for variant in 4: _synth_stream("step_"+surface+str(variant),false)

func _customize_events() -> void:
	events["combat.enemy_death"] = {paths=["res://assets/audio/sfx/enemiy_die_sound_1.wav"],gain_db=-3.0,pitch_variance=.025}
	events["combat.small_enemy_death"] = {paths=["res://assets/audio/sfx/smalle_enemy_die.wav"],gain_db=-3.0,pitch_variance=.025}
	for ui_event in ["ui.click","ui.hover"]:
		if events.has(ui_event): events[ui_event].pitch_variance = .015
	# Similar filenames describe different surfaces, not random alternatives.
	for entry in [["arrow_impact","arrow_projectile_hit_wall_or_object.wav"],["trident_impact","trident_projectile_hit_wall_or_object.wav"],["wand_impact","wand_projectile_hit_wall_or_object.wav"],["shield_hit","hit_shield.wav"],["boss_dragon_hurt","boss_dragon_hurt_sound.wav"],["forge","forge.wav"],["forge_dismantle","forge_dismantle.wav"]]:
		events[entry[0]] = {paths=["res://assets/audio/sfx/"+entry[1]],gain_db=-8.0,pitch_variance=.035}
	events.magic_shield_hit = {paths=["res://assets/audio/sfx/magic_hit_shield1.wav","res://assets/audio/sfx/magic_hit_shield_2.wav"],gain_db=-7.0,pitch_variance=.035}
	events.boss_intro = {paths=["res://assets/audio/sfx/cinematic_horror_impact_1.wav"],gain_db=-8.0,pitch_variance=0}
	if events.has("combat.boss_impact"):
		events["combat.boss_impact"].paths = ["res://assets/audio/sfx/heavy_boss_impact.wav"]
	# Dragon vocalizations stay on the dragon; other bosses use human/monster variants.
	if events.has("combat.boss_hurt"):
		events["combat.boss_hurt"].paths = events["combat.boss_hurt"].paths.filter(func(p: String) -> bool: return not "dragon" in p)

func _bus(label: String, target := "Master") -> int:
	var idx := AudioServer.get_bus_index(label)
	if idx < 0:
		AudioServer.add_bus()
		idx = AudioServer.bus_count-1
		AudioServer.set_bus_name(idx,label)
	AudioServer.set_bus_send(idx,target)
	return idx

func _build_buses() -> void:
	var mix := _bus("GameMix")
	_lowpass = AudioEffectLowPassFilter.new()
	_lowpass.cutoff_hz = 20000
	_lowpass.resonance = .55
	AudioServer.add_bus_effect(mix,_lowpass)
	_compressor = AudioEffectCompressor.new()
	_compressor.threshold = -8
	_compressor.ratio = 1.3
	_compressor.attack_us = 12000
	_compressor.release_ms = 170
	_compressor.gain = 0
	AudioServer.add_bus_effect(mix,_compressor)
	var limiter := AudioEffectHardLimiter.new()
	limiter.ceiling_db = -1.0
	AudioServer.add_bus_effect(AudioServer.get_bus_index("Master"),limiter)
	var space := _bus("Space","GameMix")
	_reverb = AudioEffectReverb.new()
	_reverb.wet = .04
	_reverb.dry = 1
	_reverb.room_size = .3
	_reverb.damping = .65
	AudioServer.add_bus_effect(space,_reverb)
	var effects := _bus("Effects", "Space")
	_width = AudioEffectStereoEnhance.new()
	_width.time_pullout_ms = 0
	_width.surround = 0
	AudioServer.add_bus_effect(effects,_width)
	_bus("SFX", "Effects")
	_bus("Ambience", "Space")
	_bus("Music", "GameMix")
	_bus("UI", "GameMix")
	var shield_bus := _bus("Shield","SFX")
	var hp := AudioEffectHighPassFilter.new()
	hp.cutoff_hz = 280
	AudioServer.add_bus_effect(shield_bus,hp)
	_mix_eq = AudioEffectEQ6.new()
	_mix_eq.set_band_gain_db(0,-3)
	_mix_eq.set_band_gain_db(4,-1.5)
	AudioServer.add_bus_effect(AudioServer.get_bus_index("SFX"),_mix_eq)
	for category in ["SFX","Ambience","Shield"]:
		for ear in 2:
			var stereo := _bus("Stereo%s%d" % [category,ear],category)
			var pan := AudioEffectPanner.new()
			pan.pan = -1 if ear==0 else 1
			AudioServer.add_bus_effect(stereo,pan)
		# Share directional DSP across categories; category gain is applied per voice.
		if category!="SFX": continue
		for sector in SECTORS:
			var angle := float(sector)*TAU/SECTORS
			var side := sin(angle)
			var rear := maxf(0,-cos(angle))
			for ear in 2:
				var idx := _bus("EarSpatial%d_%d" % [sector,ear],"Effects")
				var far_ear := maxf(0,side if ear==0 else -side)
				var eq := AudioEffectEQ6.new()
				for band in eq.get_band_count():
					var hz: float = [32,100,320,1000,3200,10000][band]
					var shadow := -far_ear*7.0*clampf((hz-900)/6000,0,1)
					var back := -rear*4.5*exp(-pow((hz-6000)/2500,2))
					eq.set_band_gain_db(band,shadow+back)
				AudioServer.add_bus_effect(idx,eq)
				var delay := AudioEffectDelay.new()
				delay.dry = 0
				delay.tap1_active = true
				delay.tap1_delay_ms = .08+far_ear*.62
				delay.tap1_level_db = 0
				delay.tap1_pan = -1 if ear==0 else 1
				delay.tap2_active = false
				delay.feedback_active = false
				AudioServer.add_bus_effect(idx,delay)

func _music_volume_db(value: float) -> float:
	# Keep zero fully quiet even with the music trim applied.
	if value <= 0.0: return -100.0
	return linear_to_db(value) + MUSIC_MIX_GAIN_DB - _duck * MUSIC_DUCK_DB


func _apply_settings() -> void:
	if _disabled: return
	var a: Dictionary = AppSettings.audio
	for spec in [["Master","master"],["Music","music"],["SFX","sfx"],["UI","sfx"],["Ambience","ambience"]]:
		var volume := _music_volume_db(float(a[spec[1]])) if spec[0] == "Music" else linear_to_db(maxf(.00001, float(a[spec[1]])))
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index(spec[0]), volume)
	_width.pan_pullout = float(a.stereo_width) if a.output_mode=="headphones" else 1.0
	var mode: String = a.output_mode
	if _last_mode != "" and _last_mode != mode:
		_test_token += 1
		for v in voices: _rebuild_voice(v)
	_last_mode = mode
	match str(a.dynamic_range):
		"night": _compressor.threshold = -18; _compressor.ratio = 2.5; _compressor.gain = 0
		"wide": _compressor.threshold = -3; _compressor.ratio = 1.0; _compressor.gain = 0
		_: _compressor.threshold = -8; _compressor.ratio = 1.3; _compressor.gain = 0

func _node_added(node: Node) -> void:
	if node is BaseButton:
		var button := node as BaseButton
		button.pressed.connect(func() -> void: play("ui_click",Vector3.INF,{cooldown=.04}))
		button.mouse_entered.connect(func() -> void:
			if button.is_visible_in_tree() and not button.disabled: play("ui_hover",Vector3.INF,{volume_db=-10,cooldown=.09}))
	elif node is VoxelFire or node is Portal or node is DungeonPortal:
		_attach_fire.call_deferred(node)

func _attach_fire(node: Variant) -> void:
	# A portal can close before its deferred audio registration executes.
	if is_instance_valid(node) and node is Node3D and not Net.is_server(): _emitters[node.get_instance_id()] = {source=weakref(node),voice={}}

func canonical(event: String) -> String: return str(ALIASES.get(event,event))

func _stream(path: String, looping: bool) -> AudioStream:
	var key := path+str(looping)
	if _streams.has(key): return _streams[key]
	var stream: AudioStream = load(path) if ResourceLoader.exists(path) else null
	if stream:
		stream = stream.duplicate()
		if stream is AudioStreamOggVorbis:
			stream.loop = looping
			stream.loop_offset = float(_loop_offsets.get(path, 0.0)) if looping else 0.0
		elif stream is AudioStreamWAV:
			stream.loop_mode = AudioStreamWAV.LOOP_FORWARD if looping else AudioStreamWAV.LOOP_DISABLED
			if looping: stream.loop_end = stream.data.size()/(4 if stream.stereo else 2)
	_streams[key] = stream
	return stream

func _synth_stream(event: String, looping: bool) -> AudioStreamWAV:
	var key := "synth:"+event+str(looping)
	if _streams.has(key): return _streams[key]
	var stream := SoundSynth.make(event)
	# WAV duplication invokes audio-server setters. Do it once at loading,
	# never on every footfall while the mixer owns its buffer lock.
	if looping:
		stream = stream.duplicate()
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_end = stream.data.size()/(4 if stream.stereo else 2)
	_streams[key] = stream
	return stream

func play(event: String, at: Vector3 = Vector3.INF, options: Dictionary = {}) -> Dictionary:
	if _disabled and not Net.is_server(): return {}
	var key := canonical(event)
	var now := Time.get_ticks_msec()/1000.0
	var bucket := key+":"+str(options.get("source_id",0))
	var cooldown := float(options.get("cooldown",.055 if at.is_finite() else .025))
	if now-float(_cooldowns.get(bucket,-100))<cooldown: return {}
	_cooldowns[bucket] = now
	if Net.is_server():
		if options.has("realm"):
			var wire := options.duplicate()
			wire.erase("realm")
			Net.server._queue(str(options.realm),at,["sfx",event,at,wire])
		return {}
	if _disabled: return {}
	if bool(options.get("ally",false)) and not AppSettings.audio.ally_sounds: return {}
	if key.begins_with("ui.") and not AppSettings.audio.ui_sounds and key!="ui.warning_pulse": return {}
	var positional := at.is_finite()
	var distance := float(options.get("max_distance",42))
	if positional and is_instance_valid(_player) and _player.global_position.distance_to(at)>distance: return {}
	var entry: Dictionary = events.get(key,{})
	var paths: Array = entry.get("paths",[])
	var looping := bool(options.get("loop",false))
	var stream: AudioStream
	if paths.is_empty():
		stream = _synth_stream(event,looping)
	else:
		# Dialogue supplies a stable variant so every party member hears the
		# same phrase without sending an additional audio broadcast.
		var choice := posmod(int(options.variant), paths.size()) if options.has("variant") else _random.randi_range(0,paths.size()-1)
		if not options.has("variant") and paths.size()>1 and choice==int(_last_variant.get(key,-1)): choice = (choice+1)%paths.size()
		_last_variant[key] = choice
		stream = _stream(str(paths[choice]),looping)
	if stream==null: return {}
	var priority := int(options.get("priority",1))
	if voices.size()>=MAX_VOICES:
		var candidate := -1
		for i in voices.size():
			if not voices[i].loop and int(voices[i].priority)<=priority:
				candidate = i; break
		if candidate<0: return {}
		_dispose(voices[candidate])
		voices.remove_at(candidate)
	var variance := minf(.035,float(entry.get("pitch_variance",.025)))
	if looping or key in ["combat.boss_rumble","ui.warning_pulse","boss.riser","boss.charge"] or bool(options.get("fixed_pitch",false)): variance = 0
	var category := str(options.get("bus","Music" if key.begins_with("music.") else "Ambience" if key.begins_with("ambience.") else "UI" if not positional else "SFX"))
	var gain := float(entry.get("gain_db",-8))+float(options.get("volume_db",0))-4.0
	var pitch := _random.randf_range(1-variance,1+variance)
	var seek := maxf(0,stream.get_length()-float(options.align_end)) if options.has("align_end") else maxf(0,float(options.get("start_at",0)))
	var duration := float(options.get("duration",float(options.get("align_end",0))))
	var v := {event=key,stream=stream,position=at,positional=positional,bus=category,players=[],source=null,
		age=0.0,seek=seek,max_age=duration,length=(stream.get_length()-seek)/pitch,pitch=pitch,gain=gain,level=0.0 if looping else 1.0,target=1.0,
		loop=looping,stopping=false,fade=float(options.get("fade",.35)),max_distance=distance,priority=priority,
		ally=bool(options.get("ally",false)),mode=str(AppSettings.audio.output_mode),source_id=options.get("source_id",0)}
	voices.append(v)
	_start_players(v,seek)
	_update_voice(v)
	if priority>=3: _duck = maxf(_duck,1)
	return v

func emit_from(event: String, source: Node3D, options: Dictionary = {}) -> Dictionary:
	if not is_instance_valid(source): return {}
	var opts := options.duplicate()
	opts.source_id = source.get_instance_id()
	if source is Enemy and is_instance_valid(source.director): opts.realm = source.director.realm_id
	return play(event,source.global_position,opts)

func loop(event: String, owner: Node3D, options: Dictionary = {}) -> Dictionary:
	if not is_instance_valid(owner): return {}
	var opts := options.duplicate()
	opts.loop = true
	opts.source_id = owner.get_instance_id()
	var v := play(event,owner.global_position,opts)
	if not v.is_empty(): v.source = weakref(owner)
	return v

func stop(handle: Dictionary, fade := .2) -> void:
	if handle.is_empty(): return
	handle.stopping = true
	handle.target = 0.0
	handle.fade = maxf(.01,fade)

func _start_players(v: Dictionary, from := 0.0) -> void:
	var profile_started := Time.get_ticks_usec() if FrameTrace.enabled else 0
	if v.positional and str(AppSettings.audio.output_mode)=="surround":
		var p := AudioStreamPlayer3D.new()
		p.stream = v.stream
		p.bus = v.bus
		p.unit_size = 3
		p.max_distance = v.max_distance
		p.attenuation_filter_cutoff_hz = 11000
		p.attenuation_filter_db = -16
		p.max_db = 0
		p.pitch_scale = v.pitch
		add_child(p)
		p.global_position = v.position
		v.players.append(p)
		p.volume_db = -80
		p.play(from)
	else:
		for ear in (2 if v.positional else 1):
			var p := AudioStreamPlayer.new()
			p.stream = v.stream
			p.bus = v.bus
			p.pitch_scale = v.pitch
			add_child(p)
			v.players.append(p)
			p.volume_db = -80
			p.play(from)
	v.mode = str(AppSettings.audio.output_mode)
	if FrameTrace.enabled: FrameTrace.record("audio/start",profile_started)

func _rebuild_voice(v: Dictionary) -> void:
	var position := fmod(float(v.seek)+float(v.age)*float(v.pitch),maxf(.01,v.stream.get_length()))
	# A loop may skip its opening after the first pass. Preserve the actual
	# playback position when changing output routing, rather than guessing it.
	for p in v.players:
		if is_instance_valid(p) and p.playing:
			position = p.get_playback_position()
			break
	for p in v.players:
		if is_instance_valid(p): p.stop(); p.queue_free()
	v.players = []
	_start_players(v,position)

func _dispose(v: Dictionary) -> void:
	var profile_started := Time.get_ticks_usec() if FrameTrace.enabled else 0
	for p in v.players:
		if is_instance_valid(p): p.stop(); p.queue_free()
	v.players = []
	v.stopping = true
	if FrameTrace.enabled: FrameTrace.record("audio/dispose",profile_started)

func _process(delta: float) -> void:
	if not FrameTrace.enabled: _profile_process(delta); return
	var started := Time.get_ticks_usec()
	_profile_process(delta)
	FrameTrace.record("audio/game_audio",started)

func _profile_process(delta: float) -> void:
	if Net.is_server(): return
	var segment_started := Time.get_ticks_usec() if FrameTrace.enabled else 0
	if is_instance_valid(_player):
		if is_instance_valid(_player.spatial_controller):
			_listener.global_transform = Transform3D(_player.camera.global_basis,_player.global_position+_player.up_direction*1.4)
		else:
			_listener.global_position = _player.global_position+Vector3.UP*1.4
			_listener.rotation = Vector3(0,_player.camera_yaw,0)
		if not _listener.is_current(): _listener.make_current()
		shield(_player.shield.active and not _player.frozen and _player.stats.hp>0 and (_player.model.visible or is_instance_valid(_player.spatial_controller)))
	else: shield(false)
	_bubble = move_toward(_bubble,1.0 if _shield_up else 0.0,delta*(3.0 if _shield_up else 2.0))
	var cutoff := exp(lerpf(log(20000.0),log(1250.0),_bubble))
	if absf(_lowpass.cutoff_hz-cutoff)>1: _lowpass.cutoff_hz = cutoff
	_duck = move_toward(_duck,0,delta*.7)
	var music_bus := AudioServer.get_bus_index("Music")
	var music_db := _music_volume_db(float(AppSettings.audio.music))
	if absf(AudioServer.get_bus_volume_db(music_bus)-music_db)>.05: AudioServer.set_bus_volume_db(music_bus,music_db)
	if FrameTrace.enabled: FrameTrace.record("audio/listener_mix",segment_started)
	segment_started = Time.get_ticks_usec() if FrameTrace.enabled else 0
	_update_footsteps(delta)
	if FrameTrace.enabled: FrameTrace.record("audio/steps",segment_started)
	_mix_tick -= delta
	var update_positions := _mix_tick<=0
	if update_positions: _mix_tick = 1.0/30.0
	_tick -= delta
	if _tick<=0:
		_tick = .15
		var context_start := Time.get_ticks_usec() if FrameTrace.enabled else 0
		_update_context()
		if FrameTrace.enabled: FrameTrace.record("audio/context",context_start)
		context_start = Time.get_ticks_usec() if FrameTrace.enabled else 0
		_update_emitters()
		if FrameTrace.enabled: FrameTrace.record("audio/emitters",context_start)
	segment_started = Time.get_ticks_usec() if FrameTrace.enabled else 0
	for i in range(voices.size()-1,-1,-1):
		var v := voices[i]
		v.age += delta
		if float(v.max_age)>0 and v.age>=float(v.max_age)-.08 and not v.stopping: stop(v,.08)
		if v.source is WeakRef:
			var owner: Object = v.source.get_ref()
			if not is_instance_valid(owner): stop(v)
			elif (owner as Node3D).is_inside_tree(): v.position = (owner as Node3D).global_position
		if bool(v.ally) and not AppSettings.audio.ally_sounds: stop(v)
		v.level = move_toward(float(v.level),float(v.target),delta/maxf(.01,float(v.fade)))
		if (v.stopping and v.level<=.001) or (not v.loop and v.age>v.length+.08):
			_dispose(v); voices.remove_at(i); continue
		if update_positions or v.stopping or absf(float(v.level)-float(v.target))>.001: _update_voice(v)
	if FrameTrace.enabled: FrameTrace.record("audio/voices",segment_started)
	if _cooldowns.size()>2048:
		var now := Time.get_ticks_msec()/1000.0
		for key in _cooldowns.keys():
			if now-float(_cooldowns[key])>5: _cooldowns.erase(key)

func _update_voice(v: Dictionary) -> void:
	var gain: float = v.gain+linear_to_db(maxf(.00001,float(v.level)))
	if bool(v.ally): gain += linear_to_db(maxf(.00001,float(AppSettings.audio.ally_volume)))-5
	if not v.positional:
		for p in v.players:
			if absf(p.volume_db-gain)>.05: p.volume_db = gain
		return
	var local: Vector3 = _listener.global_basis.inverse()*(Vector3(v.position)-_listener.global_position)
	var distance := local.length()
	if v.mode=="surround":
		var p: AudioStreamPlayer3D = v.players[0]
		p.global_position = v.position
		if absf(p.volume_db-gain)>.05: p.volume_db = gain
		return
	var pan := local.x/maxf(.001,Vector2(local.x,local.z).length())
	var angle := fposmod(atan2(local.x,-local.z),TAU)
	var sector := int(round(angle/TAU*SECTORS))%SECTORS
	var attenuation := minf(1.0,3.0/maxf(3,distance))*clampf(1-distance/float(v.max_distance),0,1)
	var category := "Ambience" if v.bus=="Ambience" else "Shield" if v.bus=="Shield" else "SFX"
	var binaural: bool = v.mode=="headphones" and category!="Ambience"
	if binaural: gain += linear_to_db(maxf(.00001,float(AppSettings.audio.sfx)))
	for ear in 2:
		var p: AudioStreamPlayer = v.players[ear]
		var target_bus := "EarSpatial%d_%d" % [sector,ear] if binaural else "Stereo%s%d" % [category,ear]
		if p.bus!=target_bus: p.bus = target_bus
		var ear_level := sqrt(clampf((1.0+(-pan if ear==0 else pan))*.5,.035,1))
		var volume := gain+linear_to_db(maxf(.00001,attenuation*ear_level))
		if absf(p.volume_db-volume)>.05: p.volume_db = volume

func _update_footsteps(delta: float) -> void:
	if not is_instance_valid(_player) or not is_instance_valid(_world): return
	var actors: Array = [_player]
	actors.append_array(get_tree().get_nodes_in_group("remote_players"))
	var present := {}
	for actor: Node3D in actors:
		var id := actor.get_instance_id()
		present[id] = true
		var at := actor.global_position
		if not _footsteps.has(id): _footsteps[id] = {position=at,distance=0.0,cooldown=0.0,idle=0.0,air=0.0}
		var step: Dictionary = _footsteps[id]
		var moved := Vector2(at.x-step.position.x,at.z-step.position.z).length()
		step.position = at
		step.cooldown = maxf(0,step.cooldown-delta)
		# Never catch up footsteps after a hitch or a teleport.
		if delta>.12 or moved>2 or (actor==_player and (_player.frozen or _player.controls_locked())):
			step.distance = 0.0
			continue
		# Render frames can run several times between physics moves. Preserve
		# stride distance on those stationary frames instead of losing every step.
		if moved < .00001:
			step.idle += delta
			if step.idle > .15: step.distance = 0.0
			continue
		step.idle = 0.0
		if actor==_player and not _player.is_on_floor():
			step.air += delta
			if step.air > .15: step.distance = 0.0
			continue
		step.air = 0.0
		step.distance += moved
		if step.distance>=1.35 and step.cooldown<=0:
			step.distance = fmod(float(step.distance), 1.35)
			step.cooldown = .20
			footstep(at,actor!=_player,id)
	for id in _footsteps.keys():
		if not present.has(id): _footsteps.erase(id)

func footstep(at: Vector3, ally := false, source_id := 0) -> Dictionary:
	var surface := "stone"
	if is_instance_valid(_world):
		if Campaigns.is_tavern(_world.realm_id): surface = "wood"
		elif _world is IslandWorld:
			var biome := _world.biome_at(at).id
			surface = "stone" if _world.is_road(at) else "sand" if biome in [Biomes.DESERT,Biomes.DEEP_DESERT,Biomes.BEACH] else "grass"
	var variant := _random.randi_range(0,3)
	var bucket := "step:"+str(source_id)
	if variant==int(_last_variant.get(bucket,-1)): variant = (variant+1)%4
	_last_variant[bucket] = variant
	return play("step_"+surface+str(variant),at if ally else Vector3.INF,{bus="SFX",ally=ally,source_id=source_id,cooldown=.18,volume_db=-7,max_distance=12,priority=1})

func enemy_death_event(definition: EnemyDef) -> String:
	return "small_enemy_die" if definition.body_height * definition.model_scale <= 1.5 else "enemy_die"

func rumble_event(seconds: float) -> String:
	var event := "combat.boss_rumble_%dms" % roundi(seconds * 1000.0)
	return event if events.has(event) else "combat.boss_rumble"

func projectile_flight(node: Node3D, ally := false) -> void:
	if Net.is_server() or not is_instance_valid(node): return
	if voices.filter(func(v: Dictionary) -> bool: return v.event=="flight" and not v.stopping).size()>=6: return
	var handle := loop("flight",node,{ally=ally,volume_db=-22,max_distance=18,priority=0,fade=.08})
	node.set_meta("flight_audio",handle)

func weapon_shot(weapon: Item, at: Vector3, ally := false) -> Dictionary:
	var event := "bow" if weapon.kind=="Bow" else "trident" if weapon.kind=="Trident" else "wand"
	var source := at if ally else Vector3.INF
	return play(event,source,{bus="SFX",ally=ally,cooldown=.035,source_id=str(at.snapped(Vector3.ONE*2)),volume_db=-3})

func projectile_hit(weapon: Item, at: Vector3, entity: bool, ally := false) -> void:
	var event := "magic_impact" if entity and weapon.kind not in ["Bow","Trident"] else "arrow_impact" if weapon.kind=="Bow" else "trident_impact" if weapon.kind=="Trident" else "wand_impact"
	play(event,at,{ally=ally,source_id=str(at.snapped(Vector3.ONE*2)),cooldown=.07,volume_db=-5})

func shield(active: bool) -> void:
	if active==_shield_up: return
	_shield_up = active
	if active and is_instance_valid(_player):
		_shield_cast = play("shield_up",Vector3.INF,{bus="Shield"})
		_shield = play("shield_loop",Vector3.INF,{loop=true,bus="Shield",volume_db=-7,fade=.25})
	else:
		stop(_shield_cast,.04)
		stop(_shield,.04)
		_shield_cast = {}
		_shield = {}

## Static menus have no world ambience, spatial loops or combat music.
func clear_world_context() -> void:
	_player = null
	_world = null
	_scene_id = 0
	for voice: Dictionary in voices:
		if voice.positional or voice.bus in ["Ambience", "Music"]: stop(voice, 0.15)
	_ambience.clear()
	_emitters.clear()
	_remote_shields.clear()
	_footsteps.clear()
	_music = {}
	_music_key = ""
	_music_layer = {}
	_music_layer_key = ""
	_music_encounter = ""
	_shield = {}
	_shield_cast = {}
	_shield_up = false

func set_context(player: Player, world: GameWorld) -> void:
	_player = player
	_world = world
	if is_instance_valid(world) and world.get_instance_id()!=_scene_id:
		_footsteps.clear()
		_scene_id = world.get_instance_id()
		for v in voices:
			if v.positional: stop(v,.12)
		_tick = 0

func _update_emitters() -> void:
	if not is_instance_valid(_player): return
	var nearby := []
	for id in _emitters.keys():
		var entry: Dictionary = _emitters[id]
		var source: Node3D = entry.source.get_ref()
		if not is_instance_valid(source): stop(entry.voice); _emitters.erase(id); continue
		if not source.is_inside_tree(): stop(entry.voice); entry.voice = {}; continue
		var distance := _player.global_position.distance_to(source.global_position)
		var active: bool = distance<18 and (not source is Portal or source.active)
		if source.get_meta("ally_fire",false) and not AppSettings.audio.ally_sounds: active = false
		if not active:
			stop(entry.voice)
			entry.voice = {}
		else: nearby.append({id=id,distance=distance})
	nearby.sort_custom(func(a,b): return a.distance<b.distance)
	for n in nearby.size():
		var entry: Dictionary = _emitters[nearby[n].id]
		if n>=8: stop(entry.voice); entry.voice = {}; continue
		if entry.voice.is_empty() or entry.voice.get("stopping",false):
			var source: Node3D = entry.source.get_ref()
			var burning := bool(source.get_meta("burning_character",false))
			entry.voice = loop("ambience.fire_close" if source is VoxelFire else "portal",source,{bus="Ambience",volume_db=-16 if burning else -12 if source is VoxelFire else -24,max_distance=18,priority=1 if burning else 0,fade=0.2 if burning else 1.2})
	var known := {}
	for remote: RemotePlayer in get_tree().get_nodes_in_group("remote_players"):
		var id := remote.get_instance_id()
		known[id] = true
		if remote.shield.active and AppSettings.audio.ally_sounds and _player.global_position.distance_to(remote.global_position)<28:
			if not _remote_shields.has(id) or _remote_shields[id].get("stopping",false):
				_remote_shields[id] = loop("shield_loop",remote,{bus="Shield",ally=true,max_distance=28,volume_db=-10})
		else:
			stop(_remote_shields.get(id,{}))
			_remote_shields.erase(id)
	for id in _remote_shields.keys():
		if not known.has(id): stop(_remote_shields[id]); _remote_shields.erase(id)

func _ambient_for(biome: int) -> String:
	match biome:
		Biomes.HALL: return "ambience.tavern"
		Biomes.DESERT, Biomes.DEEP_DESERT: return "ambience.desert"
		Biomes.DOOM: return "ambience.fire_dungeon"
		Biomes.DEEP_DARK: return "ambience.cinematic"
	return "ambience.wind"

func _update_context() -> void:
	if not is_instance_valid(_world) or not is_instance_valid(_player): return
	var signature := ""
	for item in _player.stats.gear.values(): signature += (item.id if item else "-")+","
	if _gear_signature!="" and signature!=_gear_signature: play("equip",Vector3.INF,{cooldown=.2})
	_gear_signature = signature
	var tavern := Campaigns.is_tavern(_world.realm_id)
	_update_music()
	var weights := {}
	if _world is TheoryWorld:
		pass  # The authored space/ship score and ambience will be supplied later.
	elif _world is IslandWorld:
		for offset in [Vector3.ZERO,Vector3(14,0,0),Vector3(-14,0,0),Vector3(0,0,14),Vector3(0,0,-14)]:
			var id := _world.biome_at(_player.global_position+offset).id
			var name := _ambient_for(id)
			weights[name] = float(weights.get(name,0))+(.5 if offset==Vector3.ZERO else .125)
	else:
		var ambient := "ambience.tavern" if tavern else "ambience.cinematic"
		weights[ambient] = 1.0
	for name in weights:
		if not _ambience.has(name) or _ambience[name].get("stopping",false):
			_ambience[name] = play(name,Vector3.INF,{loop=true,bus="Ambience",fade=3.5,volume_db=-9 if name == "ambience.tavern" else -7,priority=0})
		if not _ambience[name].is_empty(): _ambience[name].target = sqrt(float(weights[name]))
	for name in _ambience.keys():
		if not weights.has(name): stop(_ambience[name],3.5); _ambience.erase(name)
	var indoor := tavern or not _world is IslandWorld
	var cave := "cave" in _world.realm_id
	var target_wet := .26 if cave else .17 if indoor and not tavern else .10 if tavern else .035
	_reverb.wet = lerpf(_reverb.wet,target_wet,.12)
	_reverb.room_size = lerpf(_reverb.room_size,.78 if cave else .6 if indoor else .2,.12)
	_reverb.damping = lerpf(_reverb.damping,.36 if cave else .65,.12)

## Music is selected independently of ambience. Overlays are created only
## when audible combat begins; they never run silently under exploration.
func _update_music() -> void:
	var plan := _music_plan()
	var bed := str(plan.get("bed", ""))
	if bed != _music_key or (bed != "" and _music.is_empty()):
		stop(_music, 2.5)
		_music = {}
		_music_key = bed
		if bed != "" and events.has(bed):
			_music = play(bed, Vector3.INF, {loop = true, bus = "Music", fade = 2.5, fixed_pitch = true})
	var audible := float(AppSettings.audio.music) > 0.0001 and float(AppSettings.audio.master) > 0.0001
	var layer := str(plan.get("layer", "")) if audible else ""
	var encounter := str(plan.get("encounter", "")) if layer != "" else ""
	if layer != _music_layer_key or encounter != _music_encounter or (layer != "" and _music_layer.is_empty()):
		stop(_music_layer, 2.0 if audible else 0.02)
		_music_layer = {}
		_music_layer_key = layer
		_music_encounter = encounter
		if layer != "" and events.has(layer):
			_music_layer = play(layer, Vector3.INF, {loop = true, bus = "Music", fade = 1.5,
				fixed_pitch = true, start_at = 0.0, cooldown = 0.0})


## The reliable death event also covers a missed dying snapshot or a frame
## stall, so returning to a cleared winter arena cannot restart its score.
func boss_defeated(id: String, realm: String) -> void:
	if Net.is_server():
		Net.server._queue(realm, Vector3.INF, ["boss_defeated", id])
		return
	if is_instance_valid(_world) and _world.realm_id == realm:
		_music_defeated[_music_world_key() + "/" + id] = true
		_tick = 0.0


func _music_world_key() -> String:
	var connection := Net.client.get_instance_id() if Net.is_client() and is_instance_valid(Net.client) else 0
	return "%d/%s" % [connection, _world.realm_id]


func _music_plan() -> Dictionary:
	if _world is TheoryWorld: return {}
	var normal := "music.tavern" if Campaigns.is_tavern(_world.realm_id) else "music.japanese"
	if _player.stats.hp <= 0.0 or not _player.model.visible:
		return {}  # Give the death cue space until the next character/world.
	var world_key := _music_world_key()
	var active: Boss
	var castle_king: Boss
	for boss: Boss in Boss.all:
		if not is_instance_valid(boss) or not _world.is_ancestor_of(boss): continue
		if boss.boss_def.id == "hollow_king": castle_king = boss
		if boss.boss_def.id == "rimeheart_prism" and boss.state in [Enemy.State.DYING, Enemy.State.DEAD]:
			_music_defeated[world_key + "/rimeheart_prism"] = true
		if not boss.state in [Enemy.State.INTRO, Enemy.State.ACTIVE, Enemy.State.RETURNING, Enemy.State.DYING]: continue
		var distance := boss.global_position.distance_to(_player.global_position)
		if _world is IslandWorld and distance > maxf(boss.boss_def.bar_radius, boss.boss_def.abandon_radius) + 16.0: continue
		if active == null or distance < active.global_position.distance_to(_player.global_position): active = boss
	var fighting := active != null and active.state != Enemy.State.DYING
	var encounter := ""
	if active != null:
		var actor_id := active.net_id if active.net_id != 0 else active.get_instance_id()
		encounter = "%s/%d/%d" % [world_key, actor_id, active.intro_serial]
	var dungeon := _world as DungeonWorld
	if dungeon != null and str(dungeon.record.get("dungeon", "")) == "goblins_cave":
		return {bed = "music.battle2.layer1", layer = "music.battle2.layer2" if fighting else "", encounter = encounter}
	var castle := _world as CastleWorld
	if castle != null and is_instance_valid(castle.encounter):
		var stage := int(castle.encounter.get("stage"))
		# The throne cinematic precedes the live boss actor by nine seconds.
		# Keep the overlay running across the handoff from the cinematic to
		# the first network snapshot of the king, without restarting it.
		var king_fighting := castle_king == null or castle_king.state in [Enemy.State.INTRO, Enemy.State.ACTIVE, Enemy.State.RETURNING]
		var king_active := stage in [4, 5] and king_fighting
		var serial := castle_king.intro_serial if castle_king != null else 0
		return {bed = "music.battle3.layer1", layer = "music.battle3.layer2" if king_active else "",
			encounter = "%s/hollow_king/%d" % [world_key, serial]}
	var island := _world as IslandWorld
	if island != null:
		# Other realm bosses silence normal music, even near the winter region.
		if active != null and active.boss_def.id != "rimeheart_prism": return {}
		for fort in island.generator.strongholds:
			if fort.biome_id != Biomes.FOSEN: continue
			var site := "feature_%d_%d" % [fort.center.x, fort.center.y]
			if site in island.cleared_packs() or _music_defeated.has(world_key + "/rimeheart_prism"): break
			var distance := Vector2(_player.global_position.x, _player.global_position.z).distance_to(Vector2(fort.center))
			# Enter before reaching the gate, and avoid chatter at the boundary.
			var radius := 140.0 if _music_key == "music.battle1.layer1" else 110.0
			if distance <= radius:
				return {bed = "music.battle1.layer1", layer = "music.battle1.layer2" if fighting else "", encounter = encounter}
	# Unscored bosses keep ambience, with music faded away through their death.
	return {} if active != null else {bed = normal}


func output_description() -> String:
	var mode := str(AppSettings.audio.get("output_mode","headphones"))
	var driver := AudioServer.get_speaker_mode()
	var channels := "5.1" if driver==AudioServer.SPEAKER_SURROUND_51 else "7.1" if driver==AudioServer.SPEAKER_SURROUND_71 else "3.1" if driver==AudioServer.SPEAKER_SURROUND_31 else "stereo"
	var text := "Headphone directional processing" if mode=="headphones" else "Stereo speakers" if mode=="speakers" else "Surround output / driver: "+channels
	if mode=="surround" and channels=="stereo": text += ". Enable 5.1 in your system audio settings and restart the game."
	if _test_label!="": text += " / Test: "+_test_label
	return text

func test_output() -> void:
	_test_token += 1
	_test_sequence(_test_token)

func _test_sequence(token: int) -> void:
	var center := _listener.global_position
	var basis := _listener.global_basis
	for entry in [["Front left",Vector3(-5,0,-5)],["Front center",Vector3(0,0,-6)],["Front right",Vector3(5,0,-5)],["Rear right",Vector3(5,0,5)],["Rear left",Vector3(-5,0,5)],["Low rumble",Vector3(0,0,-3)]]:
		if token!=_test_token: return
		_test_label = entry[0]
		test_step.emit(_test_label)
		play("test_bass" if entry[0]=="Low rumble" else "test",center+basis*entry[1],{fixed_pitch=true,volume_db=-4,source_id=token,cooldown=0,max_distance=60})
		await get_tree().create_timer(.9).timeout
	if token==_test_token:
		_test_label = ""
		test_step.emit("")
