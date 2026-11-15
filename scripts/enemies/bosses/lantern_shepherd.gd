extends SurfaceBoss
## Elegy, the Lantern Shepherd (6.0/10): the guide of the dead. Quick and
## graceful, with many thin fast shots that leave clean lanes. Souls walk a
## circle round her before they go; her lantern sweeps the room like a
## lighthouse; she glides between the room's corners. From the second stage
## the walls answer her: every lantern sweep and every chime of the requiem
## sends light rippling from the middle of the room out over the plants.
const SOUL := Color("5ff0ff")
const VEIL := Color("e070ff")
const GOLD := Color("ffd27a")
const PALE := Color("c8f8ff")
var _sweep := 0.0
var _corner := 0


func _ready() -> void:
	super._ready()
	glow_color = SOUL
	glow_alt = VEIL


func _phase_started(index: int) -> void:
	behavior = "stationary"
	despawn_support("lost")
	match index:
		0: set_cycle(14.0, [[0.6, _procession], [4.0, _lantern_sweep], [7.5, _moth_veil], [10.5, _passage]])
		1:
			_lost_souls()
			set_cycle(15.0, [[0.5, _glide], [2.0, _lantern_sweep], [5.5, _procession], [8.5, _glide], [10.0, _moth_veil],
				[12.5, _passage]])
		2: set_cycle(15.0, [[0.6, _requiem], [5.5, _glide], [7.0, _lantern_sweep], [10.5, _procession], [12.5, _moth_veil]])


func _rest_line(next: int) -> String:
	return "The veil grows thin" if next == 1 else "Elegy lets go of the lantern's light"


func _wisp(color := SOUL, speed := 9.0, extra := {}) -> Dictionary:
	var a := bolt("soul_wisp", color, Vector2i(62, 84), speed, {size = 0.85, radius = 0.17})
	a.merge(extra, true)
	return a


## Souls walk a slow circle round her twice, then wander out.
func _procession() -> void:
	model.boss_pose("summon", 2.0)
	var sense := 1.0 if cycle_count % 2 == 0 else -1.0
	fire_orbit(global_position, 5.0, 10, 5.0, 2.0, sense, _wisp(PALE, 5.0, {magic = true}), randf() * TAU)
	after(0.4, func() -> void:
		fire_orbit(global_position, 8.0, 14, 5.5, 1.2, -sense, _wisp(SOUL, 5.5), randf() * TAU))
	glow_burst(global_position, PALE, {range = 10.0})


## The lantern turns like a lighthouse: a tight stream of wisps swinging
## through 200 degrees. The side behind her stays dark.
func _lantern_sweep() -> void:
	model.boss_pose("cast", 2.4)
	var start := gap_angle() + deg_to_rad(100.0) * (1.0 if randf() < 0.5 else -1.0)
	var sense := -signf(angle_difference(gap_angle(), start))
	var beats := 26 if phase < 2 else 34
	if phase > 0:
		glow_wave(GOLD, {speed = 9.0, rings = 2, gap = 0.7})
	for k in beats:
		after(0.7 + k * 0.055, func() -> void:
			var a := start + sense * deg_to_rad(200.0) * k / beats
			shoot(shot_origin(), Vector3.FORWARD.rotated(Vector3.UP, a), _wisp(GOLD, 11.0)))
	_sweep += 1.0


## Moth scales drift out in a wide waving fan.
func _moth_veil() -> void:
	model.boss_pose("channel", 1.8)
	var direction := aim_dir()
	for k in 3:
		after(0.7 + k * 0.4, func() -> void:
			fire_fan(shot_origin(), direction.rotated(Vector3.UP, deg_to_rad((k - 1) * 6.0)), 7, 12.0,
				bolt("moth_scale", VEIL, Vector2i(58, 76), 6.5, {turn = 0.25 if k % 2 else -0.25})))


## Doors of light open under each player and swallow whoever stays.
func _passage() -> void:
	model.boss_pose("cast", 1.6)
	for at in targets(4):
		var spot := at
		hazards.circle(spot, 2.6, 1.3, Vector2i(70, 90), PALE, {magic = true})
		after(1.35, func() -> void:
			glow_burst(spot, PALE, {range = 7.0, strength = 2.4})
			var origin := spot
			origin.y = shot_origin().y
			for i in 6:
				shoot(origin, Vector3.FORWARD.rotated(Vector3.UP, TAU * i / 6.0), _wisp(SOUL, 7.0)))


## She glides to another corner of the room, trailing souls.
func _glide() -> void:
	_corner = (_corner + 1 + randi() % 3) % 4
	var r := room_radius() * 0.55
	var spot := encounter_center + Vector3.FORWARD.rotated(Vector3.UP, PI * 0.25 + _corner * PI * 0.5) * r
	model.boss_pose("channel", 1.2)
	steer_to(spot, 11.0)
	for k in 6:
		after(0.15 + k * 0.17, func() -> void:
			fire_ring(shot_origin(), 6, _wisp(VEIL, 4.0), randf() * TAU))
	after(1.3, func() -> void:
		behavior = "stationary"
		scripted_move = Vector3.ZERO
		glow_burst(global_position, VEIL))


## Two counter-turning spirals, and with every chime the walls ripple from
## the middle of the room outward.
func _requiem() -> void:
	model.boss_pose("summon", 4.4)
	var start := randf() * TAU
	for beat in 16:
		after(0.8 + beat * 0.22, func() -> void:
			for arm in 3:
				var a := start + beat * 0.19 + arm * TAU / 3.0
				shoot(shot_origin(), Vector3.FORWARD.rotated(Vector3.UP, a), _wisp(SOUL, 7.5))
				shoot(shot_origin(), Vector3.FORWARD.rotated(Vector3.UP, -a + 0.4), _wisp(VEIL, 6.5))
			if beat % 4 == 0:
				glow_wave(SOUL if beat % 8 == 0 else VEIL, {speed = 11.0, strength = 2.6}))


func _lost_souls() -> void:
	model.boss_pose("summon", 2.4)
	for side: float in [-1.0, 1.0]:
		var helper := spawn_support("lost_soul", encounter_center + Vector3(side * 7.0, 0, -4.0), "lost", true)
		if helper: arm_summon(helper, 0.3)
