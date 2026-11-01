extends Boss
## Thornmaw Bloom, the meadow beyond Bramblebrook (The Lily Thief). Rooted:
## it never moves, it reaches.
##
## 1 (100-50%)  seed spits (a fan of fat seeds), snapping lunges (a marked
##    circle under you, then the jaws come down), vine whips (two lanes).
## 2 (50-0%)    after a three-second droop it blooms: a turning ring of
##    seeds, faster snaps, and the vines lash in a cross.

const SEED := Color(0.62, 0.85, 0.3)
const MAW := Color(1.0, 0.5, 0.2)
const WARN := Color(0.9, 0.55, 0.25)

var _ring_angle := 0.0


func _phase_started(index: int) -> void:
	behavior = "stationary"
	if index == 0:
		set_cycle(6.0, [[0.0, _spit], [2.2, _snap], [4.0, _whip.bind(2)]])
	else:
		set_cycle(5.0, [[0.0, _ring], [1.2, _snap], [2.6, _ring], [3.4, _whip.bind(4)]])


func _threshold_reached(next: int) -> void:
	if resting: return
	begin_rest(func() -> void: _enter_phase(next), "The bloom droops... then opens wide", "kneel")


func _seed(speed := 6.5) -> Dictionary:
	return Boss.shot("orb", SEED, Vector2i(22, 30), speed, 0.22, 16.0, {size = 1.2})


func _spit() -> void:
	model.play_attack(0.5)
	pulse_glow(1.4, 0.5)
	after(0.5, func() -> void: fire_fan(shot_origin(), aim_dir(), 5, 14.0, _seed()))


func _snap() -> void:
	var at := in_arena(target().global_position, 18.0)
	hazards.circle(at, 1.6, 0.9, Vector2i(35, 45), MAW)


func _whip(count: int) -> void:
	var a := randf() * PI
	for k in count:
		var dir := Vector3.FORWARD.rotated(Vector3.UP, a + k * TAU / count)
		hazards.lane(global_position + dir * 6.0, dir, 12.0, 0.9, 1.0, 0.6, Vector2i(25, 32), 0.6, WARN)


func _ring() -> void:
	pulse_glow(1.6, 0.4)
	_ring_angle += 0.35
	after(0.4, func() -> void:
		for k in 12:
			shoot(shot_origin(), Vector3.FORWARD.rotated(Vector3.UP, _ring_angle + k * TAU / 12.0), _seed(5.0)))


func _reset_hook() -> void:
	resting = false
