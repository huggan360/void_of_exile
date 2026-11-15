extends SurfaceBoss
## Ixalith, the Jade Coil (5.5/10): curling spiral arms of fangs, gold sun
## glyphs that fall on you and burst into feathers, plume storms sweeping
## back and forth, and once molted, a strike across the room.
const JADE := Color("4fd88a")
const GOLD := Color("ffd060")
const PLUME := Color("6af0a0")
var _coil := 0.0


func _ready() -> void:
	super._ready()
	glow_color = GOLD
	glow_alt = PLUME


func _phase_started(index: int) -> void:
	behavior = "stationary"
	despawn_support("wings")
	match index:
		0: set_cycle(14.0, [[0.8, _spiral], [4.5, _glyphs], [8.0, _plume_storm], [11.5, _spiral]])
		1:
			_wings()
			set_cycle(15.0, [[1.0, _glyph_cross], [4.5, _spiral], [8.0, _glyphs], [11.5, _plume_storm]])
		2: set_cycle(14.0, [[0.6, _strike], [4.0, _spiral], [7.0, _glyph_cross], [10.5, _plume_storm]])


func _rest_line(next: int) -> String:
	return "The plumes catch the sun" if next == 1 else "Ixalith sheds its skin"


func _fang(speed := 6.0, turn := 0.0) -> Dictionary:
	return bolt("jade_fang", JADE, Vector2i(62, 80), speed, {turn = turn})


## Four arms that curl as they go out.
func _spiral() -> void:
	model.boss_pose("channel", 3.0)
	var start := _coil
	var bend := 0.32 if phase != 1 else -0.32
	for beat in 9:
		after(0.8 + beat * 0.24, func() -> void:
			for arm in 4:
				shoot(shot_origin(), Vector3.FORWARD.rotated(Vector3.UP, start + beat * 0.12 + arm * TAU / 4.0), _fang(6.0, bend)))
	_coil += 0.7


## A gold glyph under each player bursts into a ring of feathers.
func _glyphs() -> void:
	model.boss_pose("cast", 1.8)
	for at in targets(4):
		var spot := at
		hazards.circle(spot, 2.4, 1.5, Vector2i(66, 84), GOLD, {spikes = true})
		after(1.55, func() -> void:
			glow_burst(spot, GOLD)
			var origin := spot
			origin.y = shot_origin().y
			for i in 8:
				shoot(origin, Vector3.FORWARD.rotated(Vector3.UP, TAU * i / 8.0 + 0.2), bolt("gold_plume", GOLD, Vector2i(54, 70), 5.5)))


## Plumes sweep across the room, there and back.
func _plume_storm() -> void:
	model.boss_pose("summon", 2.6)
	var center := gap_angle()
	for pass_index in 2:
		var sense := 1.0 if pass_index == 0 else -1.0
		for k in 12:
			after(0.8 + pass_index * 1.3 + k * 0.08, func() -> void:
				var a := center + sense * deg_to_rad(-70.0 + k * 140.0 / 11.0)
				shoot(shot_origin(), Vector3.FORWARD.rotated(Vector3.UP, a), bolt("gold_plume", GOLD, Vector2i(58, 74), 8.0)))


## Glyph lanes across the room: a cross, then the cross turned.
func _glyph_cross() -> void:
	model.boss_pose("slam_windup", 1.6)
	var base := randf() * PI
	var radius := room_radius() * 2.0
	for turn in 2:
		for k in 2:
			var dir := Vector3.FORWARD.rotated(Vector3.UP, base + k * PI * 0.5 + turn * PI * 0.25)
			hazards.lane(encounter_center, dir, radius, 2.4, 1.4 + turn * 1.2, 0.7, Vector2i(64, 82), 0.6, GOLD, {height = 0.6})
	after(1.4, func() -> void:
		model.boss_pose("slam_release", 0.6)
		glow_wave(GOLD, {speed = 14.0}))
	after(2.6, func() -> void: glow_wave(PLUME, {speed = 14.0}))


## It rears and strikes across the room, scattering fangs where it lands.
func _strike() -> void:
	var dir := aim_dir()
	model.boss_pose("charge_windup", 1.2)
	hazards.lane(global_position + dir * 9.0, dir, 18.0, 3.0, 1.2, 0.0, Vector2i.ZERO, 0.0, JADE)
	after(1.2, func() -> void:
		model.boss_pose("charge", 1.0)
		start_charge(dir, 16.0, 20.0, Vector2i(80, 100), func() -> void:
			model.boss_pose("charge_recover", 0.8)
			fire_ring(shot_origin(), 16, _fang(5.5), gap_angle(), 40.0)
			glow_burst(global_position, JADE, {range = 14.0})))


func _wings() -> void:
	model.boss_pose("summon", 2.4)
	for side: float in [-1.0, 1.0]:
		var helper := spawn_support("plume_wisp", encounter_center + Vector3(side * 8.0, 0, -3.0), "wings", true)
		if helper: arm_summon(helper, 0.4)
