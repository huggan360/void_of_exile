class_name SoundSynth
extends RefCounted
## Small deterministic utility sound generator. No playback-rate tricks are
## used for timed alarms/risers; their frequency envelope is synthesized.
static var _cache := {}
static func make(kind: String) -> AudioStreamWAV:
	if _cache.has(kind): return _cache[kind]
	var duration := 0.16
	match kind:
		"trident": duration = 0.34
		"flight": duration = .4
		"portal": duration = 1.2
		"warning_pulse": duration = 0.36
		"boss_riser": duration = 1.4
		"test": duration = 0.5
		"test_bass": duration = 0.8
	if kind.begins_with("step_"): duration = .22
	var rate := 24000
	var bytes := PackedByteArray()
	bytes.resize(int(duration*rate)*2)
	var random := RandomNumberGenerator.new()
	random.seed = 421+kind.hash()
	var phase := 0.0
	var smooth_noise := 0.0
	var foot_noise := 0.0
	var foot_body := 0.0
	for i in bytes.size()/2:
		var t := float(i)/rate
		var x := t/duration
		var sample := 0.0
		var noise := random.randf_range(-1,1)
		smooth_noise = lerpf(smooth_noise,noise,.13)
		match kind:
			"trident": sample = smooth_noise*.6 + sin(TAU*190*t)*.25
			"flight": sample = smooth_noise*.55
			"portal": sample = smooth_noise*.5 + sin(TAU*(100*t+200*t*t))*.28
			"warning_pulse": sample = sin(TAU*690*t)*.4 + sin(TAU*1035*t)*.16
			"boss_riser":
				phase += TAU*lerpf(90,900,x*x)/rate
				sample = (smooth_noise*.5+sin(phase)*.35)*x
			"test": sample = sin(TAU*480*t)*.35 + smooth_noise*.15
			"test_bass": sample = sin(TAU*65*t)*.32
			_: sample = sin(TAU*(840*t+280*t*t))*.3
		if kind.begins_with("step_"):
			# A soft heel/body thump, with two low-pass stages instead of raw
			# broadband grit. Surface differences stay subtle and low in pitch.
			foot_noise = lerpf(foot_noise, noise, .045)
			foot_body = lerpf(foot_body, foot_noise, .045)
			var frequency := 82.0 if "wood" in kind else 66.0 if "stone" in kind else 58.0
			frequency += float(kind.right(1).to_int() - 1) * 2.0
			phase += TAU * (frequency + 24.0 * exp(-t * 55.0)) / rate
			var heel := sin(phase) * .25 * exp(-t * 32.0)
			var body := foot_body * .75 * exp(-t * (24.0 if "sand" in kind else 32.0))
			sample = heel + body

		var envelope := minf(1,t/.004)*minf(1,(duration-t)/.035)
		if not kind.begins_with("step_") and kind not in ["test","test_bass","warning_pulse","boss_riser","portal","flight"]: envelope *= exp(-x*5)
		bytes.encode_s16(i*2,roundi(clampf(sample*envelope,-.8,.8)*32767))
	if kind.begins_with("step_"):
		var peak := 1.0
		for i in bytes.size()/2: peak = maxf(peak, absf(float(bytes.decode_s16(i*2))))
		var gain := 0.30 * 32767.0 / peak
		for i in bytes.size()/2: bytes.encode_s16(i*2, roundi(bytes.decode_s16(i*2) * gain))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.stereo = false
	stream.data = bytes
	_cache[kind] = stream
	return stream
