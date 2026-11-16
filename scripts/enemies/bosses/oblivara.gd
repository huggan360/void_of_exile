extends SurfaceBoss
## Oblivara, the Unmade God (10.0/10), the hardest fight in the game. Five
## stages, each a little less calm:
##   The Still God    concentric rings with turning gaps, gold seams cracking
##                    the floor in a star, stars falling on everyone.
##   Awakened         its eyes open: two slow rays follow you, faster rings.
##   The Mending      it mends itself and can't be hurt until its three
##                    heralds fall; a slow spiral the whole time.
##   Unmade           it comes apart: counter-turning spirals, a starfall
##                    lattice, the seams again.
##   Oblivion         the light goes out, the edge of the room burns, and the
##                    Unmaking rolls out across everything: only a raised
##                    warp shield (or distance) saves you.
const GOLD := Color("ffc24a")
const PALE := Color("fff0b0")
const VOID := Color("8a7aff")
const WHITE := Color("ffffff")
var _gaze := [0.0, 0.0]
var _gazing := false
var _turn := 0.0


func _ready() -> void:
	super._ready()
	glow_color = GOLD
	glow_alt = PALE


func _combat(delta: float) -> void:
	if not _gazing: return
	# The eyes follow, but slowly: keep moving and they never catch you.
	var want := gap_angle()
	for i in 2:
		var target_angle: float = want + (0.35 if i == 0 else -0.35)
		_gaze[i] = _gaze[i] + clampf(angle_difference(_gaze[i], target_angle), -0.55 * delta, 0.55 * delta)


func _phase_started(index: int) -> void:
	behavior = "stationary"
	_gazing = false
	despawn_support("shades")
	match index:
		0: set_cycle(16.0, [[0.6, _mudra_rings], [5.0, _seams], [8.5, _starfall], [12.0, _mudra_rings]])
		1:
			_shades()
			set_cycle(16.0, [[0.6, _gaze_rays], [4.0, _mudra_rings], [8.0, _starfall], [11.5, _seams], [13.5, _mudra_rings]])
		2:
			_mending()
			set_cycle(12.0, [[0.6, _mending_spiral], [6.6, _mending_spiral], [9.0, _starfall]])
		3:
			_shades()
			set_cycle(16.0, [[0.6, _unmade_spirals], [5.5, _starfall], [8.5, _seams], [11.5, _gaze_rays], [13.5, _mudra_rings]])
		4:
			GlowRipples.flood(self, -0.75, 3.0)
			set_cycle(18.0, [[0.6, _burning_edge], [1.5, _unmaking], [5.5, _unmade_spirals], [10.0, _unmaking], [12.5, _seams],
				[15.0, _starfall]])


func _rest_line(next: int) -> String:
	match next:
		1: return "Oblivara opens its eyes"
		2: return "The god begins to mend itself"
		3: return "The gold gives way"
		_: return "Oblivion"


func _death_started() -> void:
	_gazing = false
	super._death_started()


func _star(color := GOLD, speed := 5.0, extra := {}) -> Dictionary:
	var a := bolt("kintsugi_star", color, Vector2i(130, 165), speed, {size = 1.05})
	a.merge(extra, true)
	return a


## Rings inside rings, their gaps turning against each other.
func _mudra_rings() -> void:
	model.boss_pose("summon", 2.4)
	var gap := gap_angle() + randf_range(-0.6, 0.6)
	mark_ring_gaps(gap, 44.0, 0.9, PALE)
	var rings := 3 if phase < 3 else 4
	for k in rings:
		after(0.9 + k * 0.45, func() -> void:
			var turn := gap + (k % 2 * 2 - 1) * k * 0.3
			fire_ring(shot_origin(), 30, _star(GOLD if k % 2 == 0 else PALE, 5.2 + k * 0.35), turn, 44.0)
			glow_wave(GOLD if k % 2 == 0 else PALE, {speed = 9.0}))


## Gold seams crack the floor in a star from the god outward.
func _seams() -> void:
	model.boss_pose("slam_windup", 1.6)
	var start := randf() * TAU
	var r := room_radius()
	for k in 8:
		var dir := Vector3.FORWARD.rotated(Vector3.UP, start + TAU * k / 8.0)
		hazards.lane(global_position + dir * r * 0.5, dir, r, 1.8, 1.4, 1.4, Vector2i(150, 185), 0.5, GOLD, {height = 0.5})
	after(1.4, func() -> void:
		model.boss_pose("slam_release", 0.6)
		glow_wave(GOLD, {speed = 16.0, rings = 2, gap = 0.3}))
	after(3.0, func() -> void:
		# The seams spit stars along themselves as they close.
		for k in 8:
			var dir := Vector3.FORWARD.rotated(Vector3.UP, start + TAU * k / 8.0 + PI / 8.0)
			fire_fan(shot_origin(), dir, 2, 6.0, bolt("gold_seam", GOLD, Vector2i(120, 150), 8.0)))


## Stars fall on everyone, and burst.
func _starfall() -> void:
	model.boss_pose("cast", 1.8)
	for at in targets(6):
		for k in (2 if phase < 3 else 3):
			var spot := at + Vector3(randf_range(-2.5, 2.5), 0, randf_range(-2.5, 2.5)) * float(k)
			hazards.circle(spot, 2.2, 1.3 + k * 0.4, Vector2i(150, 190), WHITE, {spikes = true})
			after(1.35 + k * 0.4, func() -> void:
				glow_burst(spot, PALE, {range = 7.0})
				var origin := spot
				origin.y = shot_origin().y
				for i in 8:
					shoot(origin, Vector3.FORWARD.rotated(Vector3.UP, TAU * i / 8.0 + k * 0.4), bolt("void_shard", VOID, Vector2i(110, 140), 5.5)))


## Its eyes open: two slow rays that follow you.
func _gaze_rays() -> void:
	model.boss_pose("channel", 5.0)
	_gaze = [gap_angle() + 1.2, gap_angle() - 1.2]
	_gazing = true
	for i in 2:
		var eye := i
		var axis := func() -> Array:
			var dir := Vector3.FORWARD.rotated(Vector3.UP, float(_gaze[eye]))
			return [global_position + dir * 2.4, dir]
		hazards.ray(axis, 34.0, 1.2, 1.4, 4.4, Vector2i(160, 200), 0.5, PALE, {group = "gaze"})
	after(5.9, func() -> void: _gazing = false)


## While it mends itself, a slow spiral turns round it.
func _mending_spiral() -> void:
	model.boss_pose("channel", 5.2)
	_turn += 0.4
	var start := _turn
	for beat in 20:
		after(0.4 + beat * 0.25, func() -> void:
			for arm in 5:
				shoot(shot_origin(), Vector3.FORWARD.rotated(Vector3.UP, start + beat * 0.13 + arm * TAU / 5.0),
					_star(PALE, 4.6, {turn = 0.18})))


## Unmade: two spirals turning against each other.
func _unmade_spirals() -> void:
	model.boss_pose("summon", 4.2)
	_turn += 0.6
	var start := _turn
	for beat in 16:
		after(0.6 + beat * 0.24, func() -> void:
			for arm in 4:
				var a := start + beat * 0.16 + arm * TAU / 4.0
				shoot(shot_origin(), Vector3.FORWARD.rotated(Vector3.UP, a), _star(GOLD, 6.0))
				shoot(shot_origin(), Vector3.FORWARD.rotated(Vector3.UP, -a), bolt("void_shard", VOID, Vector2i(120, 150), 5.0))
			if beat % 4 == 0: glow_wave(VOID if beat % 8 else GOLD, {speed = 10.0}))


## Oblivion: the edge of the room burns, and keeps burning.
func _burning_edge() -> void:
	var r := room_radius() - 1.5
	var count := int(TAU * r / 3.0)
	for k in count:
		var spot := encounter_center + Vector3.FORWARD.rotated(Vector3.UP, TAU * k / count) * r
		hazards.circle(spot, 1.9, 1.5, Vector2i(80, 100), VOID, {patch = {time = 17.0, tick = 0.7, damage = Vector2i(60, 75)}})


## The Unmaking: a ring of warped nothing rolls over the whole room. Raise
## your warp shield or be far away when it reaches you.
func _unmaking() -> void:
	model.boss_pose("slam_windup", 2.6)
	status_text = "RAISE YOUR SHIELD"
	glow_wave(WHITE, {speed = 4.0, rings = 3, gap = 0.6, strength = 1.2})
	after(2.6, func() -> void:
		model.boss_pose("slam_release", 0.8)
		status_text = ""
		cast_ripple(global_position, {radius = room_radius() + 6.0, speed = 6.5,
			damage_min = 170, damage_max = 210, knockback = 0.6}, WHITE, players(), [])
		glow_wave(GOLD, {speed = 6.5, strength = 3.0, width = 3.0}))


## The Mending: three heralds hold it together; until they fall it can't be hurt.
func _mending() -> void:
	model.boss_pose("summon", 3.0)
	for k in 3:
		var spot := encounter_center + Vector3.FORWARD.rotated(Vector3.UP, TAU * k / 3.0 + randf()) * room_radius() * 0.6
		var herald := spawn_support("unmade_herald", spot, "guard", true)
		if herald:
			arm_summon(herald, 0.4 * k)
			_pips.append({enemy = herald, color = GOLD})
	shielded = not support("guard").is_empty()


func _shades() -> void:
	model.boss_pose("summon", 2.4)
	for side: float in [-1.0, 1.0]:
		var helper := spawn_support("kintsugi_shade", encounter_center + Vector3(side * 9.0, 0, 4.0), "shades", true)
		if helper: arm_summon(helper, 0.3)
