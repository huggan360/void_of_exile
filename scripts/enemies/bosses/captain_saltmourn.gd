extends SurfaceBoss
## Captain Saltmourn (4.5/10): broadsides of slow cannonballs, hooks that come
## back, ghost lanterns that circle him, and in the storm, waves that sweep
## the hold with one gap to dive through.
const IRON := Color("3a3c40")
const SEA := Color("3fd8c8")
const LANTERN := Color("f0b060")
const ABYSS := Color("ff4a5a")
var _side := 1.0


func _ready() -> void:
	super._ready()
	glow_color = SEA
	glow_alt = LANTERN


func _phase_started(index: int) -> void:
	behavior = "stationary"
	despawn_support("crew")
	match index:
		0: set_cycle(14.0, [[0.8, _broadside], [4.5, _hooks], [8.0, _lanterns], [11.0, _broadside]])
		1:
			_crew()
			set_cycle(15.0, [[1.0, _tide], [5.0, _broadside], [8.5, _hooks], [11.5, _lanterns]])
		2: set_cycle(14.0, [[0.8, _tentacles], [4.5, _tide], [8.5, _broadside], [11.5, _grapeshot]])


func _rest_line(next: int) -> String:
	return "All hands! The storm is coming" if next == 1 else "The abyss answers the captain"


func _cannonball(speed := 6.0) -> Dictionary:
	return bolt("cannonball", IRON, Vector2i(56, 72), speed, {size = 1.35, radius = 0.32})


## A row of slow cannonballs, one after the other across a wide arc.
func _broadside() -> void:
	model.boss_pose("cast", 2.2)
	var direction := aim_dir()
	_side = -_side
	for k in 9:
		after(0.9 + k * 0.12, func() -> void:
			var turn := deg_to_rad((k - 4) * 11.0 * _side)
			shoot(shot_origin(0.8), direction.rotated(Vector3.UP, turn), _cannonball(6.0 + (k % 2) * 0.8)))
	after(0.9, func() -> void: glow_burst(global_position, LANTERN, {range = 12.0}))


## A hook at each player that reels itself back.
func _hooks() -> void:
	model.boss_pose("slam_windup", 1.0)
	after(0.7, func() -> void:
		model.boss_pose("slam_release", 0.5)
		for at in targets(4):
			var d := at - global_position
			d.y = 0.0
			fire_fan(shot_origin(), d.normalized() if d.length() > 0.5 else aim_dir(), 3, 12.0,
				bolt("brine_hook", Color("8a6a4a"), Vector2i(52, 66), 9.0, {returns = 0.55, size = 1.15})))


## Ghost lanterns circle him twice, then drift free.
func _lanterns() -> void:
	model.boss_pose("summon", 1.8)
	glow_wave(LANTERN, {speed = 7.0})
	fire_orbit(global_position, 4.5, 8, 4.5, 1.6 if phase < 2 else 2.2, _side,
		bolt("ghost_lantern", LANTERN, Vector2i(50, 64), 4.5, {light_energy = 0.6, light_range = 3.0}))


## A wave rolls across the hold with one gap in it.
func _tide() -> void:
	model.boss_pose("channel", 2.8)
	var across := aim_dir().rotated(Vector3.UP, PI * 0.5)
	var forward := aim_dir()
	var radius := room_radius()
	var gap := randf_range(-radius * 0.5, radius * 0.5)
	for row in 5:
		var center := encounter_center - forward * (radius - 2.0) + forward * row * radius * 0.45
		for piece: float in [-1.0, 1.0]:
			# Two half-walls leave a 4 m opening at `gap`.
			var reach := radius + 4.0
			var edge := gap + piece * 2.0
			var far := piece * reach
			var mid := (edge + far) * 0.5
			hazards.lane(center + across * mid, across, absf(far - edge), 1.8, 1.0 + row * 0.55, 0.6,
				Vector2i(58, 72), 0.6, SEA, {height = 1.2})
	after(1.0, func() -> void: glow_wave(SEA, {rings = 2, gap = 0.55, speed = 8.0}))


## The abyss: eight tentacle strips flail out from him in turn.
func _tentacles() -> void:
	model.boss_pose("summon", 3.0)
	var start := randf() * TAU
	for k in 8:
		var dir := Vector3.FORWARD.rotated(Vector3.UP, start + k * TAU / 8.0)
		hazards.lane(global_position + dir * 8.0, dir, 14.0, 1.6, 1.2 + (k % 2) * 0.8, 0.8, Vector2i(60, 76), 0.6, ABYSS, {height = 0.8})
	after(1.2, func() -> void: glow_wave(ABYSS, {speed = 12.0}))


func _grapeshot() -> void:
	model.boss_pose("cast", 1.6)
	var direction := aim_dir()
	after(0.8, func() -> void:
		for k in 3:
			after(k * 0.2, func() -> void:
				fire_fan(shot_origin(), direction.rotated(Vector3.UP, deg_to_rad(randf_range(-6.0, 6.0))), 7, 7.0,
					bolt("tide_pearl", Color("e0dccb"), Vector2i(48, 60), 9.5, {size = 0.8}))))


func _crew() -> void:
	model.boss_pose("summon", 2.4)
	for side: float in [-1.0, 1.0]:
		var helper := spawn_support("drowned_deckhand", encounter_center + Vector3(side * 8.0, 0, 4.0), "crew", true)
		if helper: arm_summon(helper, 0.3)
