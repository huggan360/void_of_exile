class_name FrameTrace
extends RefCounted
## Opt-in timings for the repeatable desktop profiling scene.
static var enabled := false
static var sections := {}
static var slow := []
static func record(section: String, started: int) -> void:
	if not enabled: return
	var elapsed := Time.get_ticks_usec()-started
	var row: Dictionary = sections.get(section,{calls=0,total_us=0,max_us=0,over_4ms=0})
	row.calls += 1
	row.total_us += elapsed
	row.max_us = maxi(row.max_us,elapsed)
	if elapsed>4000: row.over_4ms += 1
	if elapsed>2000 and slow.size()<1000: slow.append({section=section,at_us=started,duration_us=elapsed})
	sections[section] = row
