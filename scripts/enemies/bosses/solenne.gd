extends SurfaceBoss
## Solenne, the Prism Oracle (8.0/10): light, split. Prism rays sweep the room
## from her halo, lenses fly out and split into rings where they stop, a
## spectrum of seven colored fans turns round her, and in eclipse her light
## inverts: the room goes dark and only her rays and the glass still shine.
const WHITE := Color("fff6d8")
const RAINBOW := [Color("ff6a7a"), Color("ffb07a"), Color("fff07a"), Color("8aff9a"), Color("7af0ff"), Color("8a9aff"), Color("ff8af0")]
const DARK := Color("6a4aff")
var _ray_angle := 0.0
var _ray_speed := 0.0
var _hue := 0


func _ready() -> void:
	super._ready()
	glow_color = WHITE
	glow_alt = RAINBOW[6]


func _combat(delta: float) -> void:
	_ray_angle += _ray_speed * delta


func _phase_started(index: int) -> void:
	behavior = "stationary"
	_ray_speed = 0.0
	despawn_support("mirrors")
	match index:
		0: set_cycle(15.0, [[0.6, _rays.bind(3, 0.45)], [6.0, _lenses], [9.5, _spectrum], [12.5, _lenses]])
		1:
			_mirrors()
			set_cycle(16.0, [[0.6, _rays.bind(4, 0.5)], [5.0, _spectrum], [8.5, _lenses], [11.5, _shards]])
		2:
			GlowRipples.flood(self, -0.6, 2.0)
			set_cycle(16.0, [[0.6, _rays.bind(5, -0.55)], [5.5, _shards], [8.0, _spectrum], [11.0, _lenses], [13.5, _shards]])


func _rest_line(next: int) -> String:
	return "The light breaks into pieces" if next == 1 else "Solenne turns her light inside out"


func _reset_hook() -> void:
	super._reset_hook()
	_ray_speed = 0.0


func _death_started() -> void:
	_ray_speed = 0.0
	super._death_started()


## Rays out of her halo, sweeping round the floor.
func _rays(count: int, speed: float) -> void:
	model.boss_pose("cast", 1.4)
	_ray_speed = speed * (1.0 if randf() < 0.5 else -1.0)
	for k in count:
		var offset := TAU * k / count
		var color: Color = RAINBOW[(k * 2 + _hue) % RAINBOW.size()]
		var axis := func() -> Array:
			var dir := Vector3.FORWARD.rotated(Vector3.UP, _ray_angle + offset)
			return [global_position + dir * 2.0, dir]
		hazards.ray(axis, 30.0, 1.0, 1.2, 4.6, Vector2i(120, 150), 0.6, color, {group = "prism_rays"})
	_hue += 1
	glow_wave(WHITE, {speed = 12.0})
	after(5.8, func() -> void: _ray_speed = 0.0)


## Lenses fly out and split into small rings where they stop.
func _lenses() -> void:
	model.boss_pose("summon", 1.8)
	var start := gap_angle() + PI / 6.0
	var count := 6
	for k in count:
		var dir := Vector3.FORWARD.rotated(Vector3.UP, start + TAU * k / count)
		var travel := 7.0
		after(0.7, func() -> void:
			shoot(shot_origin(), dir, bolt("lens_disc", WHITE, Vector2i(100, 124), 7.0, {range = travel})))
		after(0.7 + travel / 7.0, func() -> void:
			var at := shot_origin() + dir * travel
			glow_burst(at, RAINBOW[k], {range = 6.0})
			for i in 7:
				shoot(at, Vector3.FORWARD.rotated(Vector3.UP, TAU * i / 7.0 + k), bolt("glass_shard", RAINBOW[(k + i) % 7], Vector2i(92, 116), 5.5)))


## Seven fans, each its own color, turning round her.
func _spectrum() -> void:
	model.boss_pose("channel", 3.0)
	var base := randf() * TAU
	for k in 7:
		after(0.6 + k * 0.32, func() -> void:
			var dir := Vector3.FORWARD.rotated(Vector3.UP, base + k * TAU / 7.0 * 1.15)
			fire_fan(shot_origin(), dir, 5, 9.0, bolt("prism_ray", RAINBOW[k], Vector2i(96, 120), 8.5 if phase < 2 else 9.5))
			if k % 2 == 0: glow_wave(RAINBOW[k], {speed = 9.0, strength = 1.6}))


## Glass rains in a lattice; the stripes between stay clear.
func _shards() -> void:
	model.boss_pose("slam_windup", 1.4)
	var forward := aim_dir()
	var across := forward.rotated(Vector3.UP, PI * 0.5)
	var r := room_radius()
	var shift := randf() * 4.0
	for row in range(-3, 4):
		for col in range(-3, 4):
			if (row + col) % 2 != 0: continue
			var spot := encounter_center + forward * (row * 4.0 + shift) + across * col * 4.0
			if Vector2(spot.x - encounter_center.x, spot.z - encounter_center.z).length() > r: continue
			hazards.circle(spot, 1.7, 1.3 + absi(row) * 0.15, Vector2i(104, 128), RAINBOW[(row + col + 6) % 7], {spikes = true})
	after(1.4, func() -> void: model.boss_pose("slam_release", 0.6))


func _mirrors() -> void:
	model.boss_pose("summon", 2.4)
	for side: float in [-1.0, 1.0]:
		var helper := spawn_support("mirror_wisp", encounter_center + Vector3(side * 8.0, 0, -4.0), "mirrors", true)
		if helper: arm_summon(helper, 0.3)
