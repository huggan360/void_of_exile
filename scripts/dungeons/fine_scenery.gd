class_name FineScenery
extends RefCounted
## The fine dungeons' dressing (DungeonScenery calls it): six props per theme
## for the room corners, a lamp for each lamp spot, and glowing growth that
## climbs the walls. Glowing voxels go through DungeonScenery.glow() and take
## part in the theme's blinking and ripples (GlowRipples); their bases are the
## points the plants "talk" from.

const THEMES := ["sporewomb", "shipwreck", "jade_temple", "afterlife", "ice_barrow", "glass_maze", "cathedral", "starless"]
## Themes whose big rooms get a ring of their first prop (pillars, candles...).
const RINGED := ["jade_temple", "ice_barrow", "glass_maze", "cathedral"]
## How much of the wall gets growth.
const GROWTH := {sporewomb = 0.16, shipwreck = 0.14, jade_temple = 0.12, afterlife = 0.34, ice_barrow = 0.1,
	glass_maze = 0.12, cathedral = 0.1, starless = 0.12}

var s: DungeonScenery
var rng: RandomNumberGenerator
var theme := ""


func _init(p_scenery: DungeonScenery, p_rng: RandomNumberGenerator, p_theme: String) -> void:
	s = p_scenery
	rng = p_rng
	theme = p_theme


func props() -> Array[Callable]:
	match theme:
		"sporewomb": return [_giant_mushroom, _puffballs, _fungus_log, _giant_mushroom, _spore_rock, _puffballs]
		"shipwreck": return [_hull, _barrels, _mast, _anchor, _barnacle_rock, _skeleton_chest]
		"jade_temple": return [_jade_pillar, _serpent_statue, _orchids, _stone_head, _jade_pillar, _altar]
		"afterlife": return [_bulb_stalks, _soul_ferns, _lotus_pool, _pale_arch, _bulb_stalks, _soul_stones]
		"ice_barrow": return [_runestone, _cairn, _ice_spikes, _frozen_warrior, _runestone, _shield_rack]
		"glass_maze": return [_glass_obelisk, _prisms, _mirror, _glass_dune, _glass_obelisk, _lens_stand]
		"cathedral": return [_candelabra, _pews, _angel, _organ, _candelabra, _fallen_bell]
		_: return [_floating_pillar, _star_cluster, _mended_statue, _void_crystal, _floating_pillar, _halo_piece]


func lamp(at: Vector3) -> void:
	match theme:
		"sporewomb": _lamp_mushrooms(at)
		"shipwreck": _ship_lantern(at)
		"jade_temple": _green_brazier(at)
		"afterlife": _soul_lantern(at)
		"ice_barrow": _cold_brazier(at)
		"glass_maze": _lens_lamp(at)
		"cathedral": _candle_tree(at)
		_: _star_brazier(at)


## Growth up the walls beside the floor (`cell` is the floor cell, `n` the
## direction of the wall, `t` along it).
func wall_growth(base: Vector3, n: Vector3, t: Vector3) -> void:
	match theme:
		"sporewomb": _shelf_fungus(base, n, t)
		"shipwreck": _kelp_strand(base, n, t)
		"jade_temple": _vines(base, n, t)
		"afterlife": _soul_vine(base, n, t)
		"ice_barrow": _icicles(base, n, t)
		"glass_maze": _wall_prisms(base, n, t)
		"cathedral": _wall_candles(base, n, t)
		_: _gold_seam(base, n, t)


# --- helpers ---------------------------------------------------------------------------

func _blob(at: Vector3, r: float, step: float, color: Color, glow := 0.0, rate := 0.4, rest := 0.5) -> void:
	var n := ceili(r / step)
	for y in range(-n, n + 1):
		for z in range(-n, n + 1):
			for x in range(-n, n + 1):
				var p := Vector3(x, y, z) * step
				if p.length() > r: continue
				# Only the shell: nothing inside shows.
				if (p + Vector3(step, 0, 0)).length() <= r and (p - Vector3(step, 0, 0)).length() <= r \
						and (p + Vector3(0, step, 0)).length() <= r and (p - Vector3(0, step, 0)).length() <= r \
						and (p + Vector3(0, 0, step)).length() <= r and (p - Vector3(0, 0, step)).length() <= r:
					continue
				if glow > 0.0: s.glow(at + p, Vector3.ONE * step, color, glow, rate, rest)
				else: s._voxel(at + p, Vector3.ONE * step, color.darkened(rng.randf() * 0.08))


func _stack(at: Vector3, height: int, step: float, width: float, color: Color, taper := 0.0) -> void:
	for y in height:
		var w := width * (1.0 - taper * float(y) / height)
		s._voxel(at + Vector3(0, y * step + step * 0.5, 0), Vector3(w, step, w), color.darkened(0.06 if y % 3 == 0 else 0.0))


func _jit(r: float) -> Vector3:
	return Vector3(rng.randf_range(-r, r), 0, rng.randf_range(-r, r))


# --- The Sporewomb ------------------------------------------------------------------

func _giant_mushroom(at: Vector3) -> void:
	var p := at + _jit(0.4)
	var height := rng.randf_range(2.0, 3.6)
	var stem := Color("d8cdb0")
	var lean := Vector3(rng.randf_range(-0.25, 0.25), 0, rng.randf_range(-0.25, 0.25))
	var steps := int(height / 0.2)
	for y in steps:
		var k := float(y) / steps
		s._voxel(p + lean * k * k + Vector3(0, y * 0.2 + 0.1, 0), Vector3(0.38 - k * 0.1, 0.2, 0.38 - k * 0.1), stem.darkened(0.05 * (y % 2)))
	var top := p + lean + Vector3(0, height, 0)
	var cap := Color("c47a2c")
	var r := rng.randf_range(1.0, 1.6)
	for z in range(-8, 9):
		for x in range(-8, 9):
			var d := Vector2(x, z).length() * 0.2
			if d > r: continue
			var h := (1.0 - (d / r) * (d / r)) * 0.55
			s._voxel(top + Vector3(x * 0.2, h + 0.1, z * 0.2), Vector3(0.2, 0.2, 0.2), cap.lightened(0.12 if (x + z) % 3 == 0 else 0.0))
			# Teal gills glow under the brim.
			if d > r * 0.35: s.glow(top + Vector3(x * 0.2, h - 0.06, z * 0.2), Vector3(0.2, 0.05, 0.2), Color("6fe8d6"), 1.0, 0.25, 0.45)
			if rng.randf() < 0.05: s.glow(top + Vector3(x * 0.2, h + 0.22, z * 0.2), Vector3.ONE * 0.08, Color("ffe8a0"), 1.0, 0.6, 0.6)
	s.glow_point(top)


func _puffballs(at: Vector3) -> void:
	for k in rng.randi_range(3, 5):
		var p := at + _jit(1.0)
		var r := rng.randf_range(0.25, 0.5)
		_blob(p + Vector3(0, r, 0), r, 0.12, Color("e6dcc4"))
		for d in 3:
			s.glow(p + Vector3(rng.randf_range(-r, r) * 0.7, r * 1.6, rng.randf_range(-r, r) * 0.7), Vector3.ONE * 0.08, Color("ffc04a"), 1.0, 0.5, 0.4)
		s.glow_point(p + Vector3.UP * r)


func _fungus_log(at: Vector3) -> void:
	var dir := Vector3.RIGHT.rotated(Vector3.UP, rng.randf() * TAU)
	for i in 12:
		var p := at + dir * (i - 6) * 0.22 + Vector3.UP * 0.25
		s._voxel(p, Vector3(0.24, 0.45, 0.45), Color("4a3424").lightened(0.06 * (i % 2)))
		if i % 3 == 1:
			s.glow(p + Vector3.UP * 0.3, Vector3(0.3, 0.08, 0.3), Color("ffb347"), 0.8, 0.3, 0.4)
	s.glow_point(at + Vector3.UP * 0.5)


func _spore_rock(at: Vector3) -> void:
	_blob(at + Vector3(0, 0.3, 0), 0.7, 0.2, Color("5a4a3c"))
	for k in 6:
		s.glow(at + _jit(0.6) + Vector3(0, 0.75 + rng.randf() * 0.2, 0), Vector3(0.12, 0.06, 0.12), Color("6fe8d6"), 1.0, 0.5, 0.5)


func _lamp_mushrooms(at: Vector3) -> void:
	for k in 4:
		var p := at + _jit(0.5)
		var h := rng.randf_range(0.6, 1.5)
		_stack(p, int(h / 0.15), 0.15, 0.14, Color("d8cdb0"))
		_blob(p + Vector3(0, h + 0.1, 0), 0.32, 0.11, Color("ffb347"), 1.0, 0.35, 0.9)
	s.glow_point(at + Vector3.UP)


func _shelf_fungus(base: Vector3, n: Vector3, t: Vector3) -> void:
	var y := 0.3
	for k in rng.randi_range(2, 5):
		y += rng.randf_range(0.3, 0.7)
		var w := rng.randf_range(0.3, 0.6)
		var p := base + Vector3.UP * y + t * rng.randf_range(-0.2, 0.2)
		for i in range(-2, 3):
			s._voxel(p + t * i * w * 0.2 - n * 0.1, Vector3(0.14, 0.08, 0.14) + (t.abs() * w * 0.2), Color("c98a3c"))
		s.glow(p - n * 0.18 - Vector3.UP * 0.06, Vector3(0.1, 0.04, 0.1) + t.abs() * w * 0.7, Color("6fe8d6"), 1.0, 0.3, 0.4)
	s.glow_point(base + Vector3.UP * y)


# --- Saltbone Wreck -----------------------------------------------------------------

func _hull(at: Vector3) -> void:
	var dir := Vector3.RIGHT.rotated(Vector3.UP, rng.randf() * TAU)
	var side := dir.cross(Vector3.UP)
	var plank := Color("4c3828")
	for i in 9:
		var along := (i - 4) * 0.35
		var ribs := i % 3 == 0
		for h in 8:
			var a := h / 7.0 * PI * 0.5
			var p := at + dir * along + side * (cos(a) * 1.4 - 0.6) + Vector3.UP * (sin(a) * 1.8 + 0.1)
			if not ribs and rng.randf() < 0.25: continue  # holes stove in
			s._voxel(p, Vector3(0.36, 0.25, 0.14) if not ribs else Vector3(0.12, 0.26, 0.2), plank.darkened(0.15) if ribs else plank.lightened(0.05 * (h % 2)))
	for k in 4:
		s._voxel(at + _jit(1.0) + Vector3.UP * 0.05, Vector3(0.12, 0.08, 0.12), Color("e0dccb"))


func _barrels(at: Vector3) -> void:
	for k in rng.randi_range(2, 4):
		var p := at + _jit(0.9)
		for y in 5:
			var w := 0.45 if y in [1, 2, 3] else 0.38
			s._voxel(p + Vector3(0, y * 0.16 + 0.08, 0), Vector3(w, 0.16, w), Color("2a2a2c") if y in [1, 3] else Color("6a4a30"))


func _mast(at: Vector3) -> void:
	_stack(at, 18, 0.2, 0.3, Color("4a3424"))
	s._voxel(at + Vector3(0, 3.0, 0), Vector3(2.0, 0.14, 0.14), Color("4a3424"))
	for y in 8:
		for x in range(-4, 5):
			if rng.randf() < 0.3 + y * 0.06: continue
			s._voxel(at + Vector3(x * 0.2, 2.85 - y * 0.2, 0.1), Vector3(0.2, 0.2, 0.04), Color("cfc4a8").darkened(y * 0.04))


func _anchor(at: Vector3) -> void:
	var iron := Color("3a3c40")
	_stack(at, 9, 0.2, 0.14, iron)
	s._voxel(at + Vector3(0, 1.55, 0), Vector3(0.7, 0.12, 0.12), iron)
	for i in 5:
		var a := PI + i * PI / 4.0
		s._voxel(at + Vector3(cos(a) * 0.55, 0.3 + sin(a) * 0.3 + 0.3, 0), Vector3(0.14, 0.14, 0.14), iron.lightened(0.1))
	s._voxel(at + Vector3(0, 1.85, 0), Vector3(0.3, 0.3, 0.06), Color("8a6a3a"))


func _barnacle_rock(at: Vector3) -> void:
	_blob(at + Vector3(0, 0.35, 0), 0.8, 0.2, Color("4a5450"))
	for k in 8:
		s._voxel(at + _jit(0.7) + Vector3(0, 0.75 + rng.randf() * 0.3, 0), Vector3.ONE * 0.1, Color("e0dccb"))
	for k in 3:
		s.glow(at + _jit(0.6) + Vector3(0, 0.95, 0), Vector3.ONE * 0.12, Color("3fd8c8"), 1.0, 0.4, 0.5)
	s.glow_point(at + Vector3.UP)


func _skeleton_chest(at: Vector3) -> void:
	var p := at + _jit(0.3)
	s._voxel(p + Vector3(0, 0.25, 0), Vector3(0.8, 0.5, 0.5), Color("5a3a24"))
	s._voxel(p + Vector3(0, 0.55, -0.05), Vector3(0.82, 0.12, 0.55), Color("6a4a30"))
	for k in 6:
		s.glow(p + _jit(0.5) + Vector3(0, 0.05, 0.4), Vector3(0.1, 0.04, 0.1), Color("ffd060"), 0.6, 0.7, 0.3)
	s._voxel(p + Vector3(0.7, 0.15, 0.3), Vector3(0.27, 0.25, 0.23), DungeonScenery.BONE)


func _ship_lantern(at: Vector3) -> void:
	_stack(at, 12, 0.2, 0.12, Color("4a3424"))
	s._voxel(at + Vector3(0.25, 2.35, 0), Vector3(0.5, 0.08, 0.08), Color("2a2a2c"))
	var lamp := at + Vector3(0.45, 2.05, 0)
	s._voxel(lamp + Vector3(0, 0.22, 0), Vector3(0.3, 0.06, 0.3), Color("2a2a2c"))
	s.glow(lamp, Vector3(0.22, 0.32, 0.22), Color("ffb860"), 1.0, 2.2, 0.9)
	s.glow_point(lamp)


func _kelp_strand(base: Vector3, n: Vector3, t: Vector3) -> void:
	var h := rng.randi_range(8, 20)
	for k in h:
		var p := base + Vector3.UP * (k * 0.18 + 0.1) + t * sin(k * 0.6 + base.x) * 0.12 - n * 0.05
		s._voxel(p, Vector3(0.1, 0.2, 0.1), Color("2f4a2a").lightened(0.08 * (k % 3)))
		if k % 6 == 3: s._voxel(p + t * 0.1, Vector3(0.18, 0.06, 0.08), Color("3a5a30"))
	if rng.randf() < 0.5:
		s.glow(base + Vector3.UP * 0.1 - n * 0.15, Vector3(0.18, 0.12, 0.18), Color("3fd8c8"), 1.0, 0.5, 0.6)
		s.glow_point(base)


# --- The Jade Ziggurat -------------------------------------------------------------

func _jade_pillar(at: Vector3) -> void:
	for y in 22:
		var band := y % 6 == 0
		var w := 0.85 if y in [0, 21] else 0.65
		if band: s.glow(at + Vector3(0, y * 0.25 + 0.125, 0), Vector3(w + 0.04, 0.12, w + 0.04), Color("ffd060"), 0.7, 0.2, 0.3)
		else: s._voxel(at + Vector3(0, y * 0.25 + 0.125, 0), Vector3(w, 0.25, w), Color("4a9a74").darkened(0.08 * (y % 2)))
	s.glow_point(at + Vector3.UP * 1.5)


func _serpent_statue(at: Vector3) -> void:
	var jade := Color("3f8a6a")
	for i in 30:
		var a := i * 0.45
		var p := at + Vector3(cos(a) * 0.5, i * 0.08 + 0.15, sin(a) * 0.5)
		s._voxel(p, Vector3.ONE * 0.3, jade.lightened(0.1 * (i % 2)))
	var head := at + Vector3(0, 2.7, -0.3)
	s._voxel(head, Vector3(0.45, 0.35, 0.6), jade)
	for side in [-1.0, 1.0]:
		s.glow(head + Vector3(side * 0.16, 0.12, -0.25), Vector3.ONE * 0.08, Color("ffd060"), 1.0, 0.3, 0.8)
	for k in 5:
		s._voxel(head + Vector3((k - 2) * 0.12, 0.3, 0.15), Vector3(0.08, 0.3, 0.08), Color("d8b04a"))


func _orchids(at: Vector3) -> void:
	for k in 6:
		var p := at + _jit(0.9)
		var h := rng.randi_range(3, 7)
		for y in h:
			s._voxel(p + Vector3(0, y * 0.14 + 0.07, 0), Vector3(0.06, 0.14, 0.06), Color("3f7a2e"))
		s.glow(p + Vector3(0, h * 0.14 + 0.08, 0), Vector3(0.2, 0.12, 0.2), [Color("ff7ab0"), Color("ffd060"), Color("c87aff")][k % 3], 0.8, 0.3, 0.35)
	s.glow_point(at + Vector3.UP * 0.6)


func _stone_head(at: Vector3) -> void:
	_blob(at + Vector3(0, 0.6, 0), 0.65, 0.18, Color("a8a088"))
	for side in [-1.0, 1.0]:
		s.glow(at + Vector3(side * 0.22, 0.75, -0.55), Vector3(0.14, 0.08, 0.06), Color("6af0a0"), 1.0, 0.25, 0.5)
	s._voxel(at + Vector3(0, 0.4, -0.58), Vector3(0.4, 0.06, 0.06), Color("2a2a22"))


func _altar(at: Vector3) -> void:
	s._voxel(at + Vector3(0, 0.3, 0), Vector3(1.4, 0.6, 0.9), Color("9a927a"))
	s._voxel(at + Vector3(0, 0.65, 0), Vector3(1.5, 0.1, 1.0), Color("d8b04a"))
	s.glow(at + Vector3(0, 0.8, 0), Vector3(0.3, 0.2, 0.3), Color("6af0a0"), 1.0, 0.4, 0.8)
	s.glow_point(at + Vector3.UP)


func _green_brazier(at: Vector3) -> void:
	_stack(at, 6, 0.2, 0.3, Color("d8b04a"), 0.4)
	s._voxel(at + Vector3(0, 1.25, 0), Vector3(0.7, 0.15, 0.7), Color("b8902a"))
	for k in 6:
		s.glow(at + _jit(0.2) + Vector3(0, 1.4 + k * 0.1, 0), Vector3.ONE * (0.24 - k * 0.025), Color("6af0a0").lerp(Color("e0ffd0"), k / 6.0), 1.0, 1.6, 0.9)
	s.glow_point(at + Vector3.UP * 1.5)


func _vines(base: Vector3, n: Vector3, t: Vector3) -> void:
	var h := rng.randi_range(10, 24)
	for k in h:
		var p := base + Vector3.UP * (k * 0.15 + 0.1) + t * sin(k * 0.5) * 0.1 - n * 0.04
		s._voxel(p, Vector3(0.08, 0.16, 0.08), Color("3e7a32").lightened(0.06 * (k % 2)))
		if k % 3 == 0: s._voxel(p + t * 0.12, Vector3(0.14, 0.05, 0.1), Color("5c9a42"))
		if k % 7 == 5: s.glow(p - n * 0.06, Vector3.ONE * 0.1, Color("ff7ab0"), 0.7, 0.3, 0.25)
	if rng.randf() < 0.3:
		s.glow(base + Vector3.UP * rng.randf_range(1.2, 2.4) - n * 0.02, Vector3(0.3, 0.3, 0.04) + t.abs() * 0.0, Color("ffd060"), 1.0, 0.15, 0.25)
	s.glow_point(base + Vector3.UP)


# --- Afterlife -----------------------------------------------------------------------

const SOUL := [Color("5ff0ff"), Color("e070ff"), Color("ffd27a")]


func _bulb_stalks(at: Vector3) -> void:
	for k in rng.randi_range(4, 7):
		var p := at + _jit(1.0)
		var h := rng.randi_range(6, 16)
		var bend := Vector3(rng.randf_range(-0.3, 0.3), 0, rng.randf_range(-0.3, 0.3))
		for y in h:
			var q := float(y) / h
			s._voxel(p + bend * q * q + Vector3(0, y * 0.15 + 0.07, 0), Vector3(0.07, 0.15, 0.07), Color("2a3158").lightened(q * 0.15))
		var tip := p + bend + Vector3(0, h * 0.15 + 0.1, 0)
		_blob(tip, rng.randf_range(0.12, 0.22), 0.08, SOUL[rng.randi() % 3], 1.0, rng.randf_range(0.15, 0.5), 0.55)
		s.glow_point(tip)


func _soul_ferns(at: Vector3) -> void:
	for k in rng.randi_range(3, 5):
		var p := at + _jit(0.9)
		for f in 5:
			var dir := Vector3.FORWARD.rotated(Vector3.UP, f * TAU / 5.0 + rng.randf())
			for i in 7:
				var q := i / 6.0
				var at2 := p + dir * q * 0.9 + Vector3.UP * (sin(q * PI * 0.8) * 0.7 + 0.05)
				if i == 6: s.glow(at2, Vector3.ONE * 0.1, Color("5ff0ff"), 1.0, 0.35, 0.6)
				else: s._voxel(at2, Vector3(0.1, 0.06, 0.1), Color("1f3a44").lightened(q * 0.25))
		s.glow_point(p + Vector3.UP * 0.5)


func _lotus_pool(at: Vector3) -> void:
	for z in range(-6, 7):
		for x in range(-6, 7):
			if Vector2(x, z).length() > 6.0: continue
			s.glow(at + Vector3(x * 0.2, 0.02, z * 0.2), Vector3(0.2, 0.03, 0.2), Color("123048"), 0.4, 0.1, 0.4)
	for k in 6:
		var p := at + _jit(0.9) + Vector3.UP * 0.06
		s._voxel(p, Vector3(0.36, 0.03, 0.36), Color("1f4a3a"))
		if k % 2 == 0:
			for petal in 5:
				var d := Vector3.FORWARD.rotated(Vector3.UP, petal * TAU / 5.0) * 0.1
				s.glow(p + d + Vector3.UP * 0.1, Vector3(0.08, 0.12, 0.08), Color("f0b0ff"), 1.0, 0.3, 0.7)
			s.glow_point(p)


func _pale_arch(at: Vector3) -> void:
	var dir := Vector3.RIGHT.rotated(Vector3.UP, rng.randf() * PI)
	var stone := Color("8f8ca8")
	for i in 15:
		var a := i / 14.0 * PI
		var p := at + dir * cos(a) * 1.1 + Vector3.UP * (sin(a) * 2.0 + 0.2)
		s._voxel(p, Vector3(0.32, 0.32, 0.32), stone.lightened(0.1 * (i % 2)))
		if i == 7: s.glow(p + Vector3.UP * 0.05, Vector3(0.14, 0.14, 0.36), Color("c8f8ff"), 1.0, 0.2, 0.7)
	for side in [-1.0, 1.0]:
		_stack(at + dir * side * 1.1, 2, 0.2, 0.4, stone)


func _soul_stones(at: Vector3) -> void:
	for k in 4:
		var p := at + _jit(0.8) + Vector3.UP * rng.randf_range(0.6, 1.6)
		_blob(p, rng.randf_range(0.18, 0.3), 0.1, Color("34314f"))
		s.glow(p + Vector3.UP * 0.25, Vector3.ONE * 0.08, SOUL[k % 3], 1.0, 0.4, 0.8)
		s.glow_point(p)


func _soul_lantern(at: Vector3) -> void:
	var wood := Color("2c2a44")
	for y in 12:
		s._voxel(at + Vector3(sin(y * 0.3) * 0.08, y * 0.2 + 0.1, 0), Vector3(0.12, 0.2, 0.12), wood)
	var lamp := at + Vector3(0.3, 2.2, 0)
	s._voxel(lamp + Vector3(-0.15, 0.25, 0), Vector3(0.3, 0.06, 0.06), wood)
	for c in [Vector3(-0.12, 0, -0.12), Vector3(0.12, 0, -0.12), Vector3(-0.12, 0, 0.12), Vector3(0.12, 0, 0.12)]:
		s._voxel(lamp + c, Vector3(0.04, 0.34, 0.04), Color("c8c4d8"))
	s.glow(lamp, Vector3(0.18, 0.22, 0.18), Color("5ff0ff"), 1.0, 0.5, 1.0)
	s.glow_point(lamp)


## Vines up the wall with glowing nodes: the network the light runs through.
func _soul_vine(base: Vector3, n: Vector3, t: Vector3) -> void:
	var h := rng.randi_range(10, 30)
	var color: Color = SOUL[rng.randi() % 3]
	var drift := rng.randf_range(-0.4, 0.4)
	for k in h:
		var p := base + Vector3.UP * (k * 0.14 + 0.08) + t * (sin(k * 0.45 + base.z) * 0.14 + drift * k * 0.02) - n * 0.03
		s._voxel(p, Vector3(0.07, 0.15, 0.07), Color("1f2a44").lightened(0.05 * (k % 2)))
		if k % 4 == 2:
			s.glow(p - n * 0.05 + t * 0.06, Vector3.ONE * 0.09, color, 1.0, rng.randf_range(0.1, 0.4), 0.35)
		if k % 5 == 0:
			s.glow(p + t * 0.12, Vector3(0.12, 0.04, 0.1), Color("2a6a7a"), 0.6, 0.2, 0.3)
	for k in 3:  # glowing moss at the foot
		s.glow(base + t * rng.randf_range(-0.35, 0.35) + Vector3.UP * 0.03 - n * 0.2, Vector3(0.18, 0.05, 0.18), Color("1f5a66"), 0.7, 0.15, 0.35)
	s.glow_point(base + Vector3.UP * h * 0.07)


# --- Rimewake Barrow -------------------------------------------------------------------

func _runestone(at: Vector3) -> void:
	var stone := Color("4a5262")
	for y in 12:
		var w := 0.7 - absf(y - 5) * 0.025
		s._voxel(at + Vector3(0, y * 0.22 + 0.11, 0), Vector3(w, 0.22, 0.3), stone.lightened(0.05 * (y % 2)))
	for y in [3, 5, 7, 9]:
		s.glow(at + Vector3(rng.randf_range(-0.15, 0.15), y * 0.22 + 0.11, -0.16), Vector3(0.14, 0.14, 0.04), Color("6ad0ff"), 1.0, 0.15, 0.6)
	s._voxel(at + Vector3(0, 2.7, 0), Vector3(0.6, 0.06, 0.32), Color("e8f0f8"))
	s.glow_point(at + Vector3.UP * 1.4)


func _cairn(at: Vector3) -> void:
	for y in 4:
		for k in 7 - y * 2:
			var a := k * TAU / maxf(1, 7 - y * 2) + y
			var r := 0.6 - y * 0.15
			s._voxel(at + Vector3(cos(a) * r, y * 0.25 + 0.15, sin(a) * r), Vector3(0.3, 0.25, 0.3), Color("5a6474").darkened(rng.randf() * 0.2))
	s._voxel(at + Vector3(0, 1.15, 0), Vector3(0.5, 0.06, 0.5), Color("e8f0f8"))


func _ice_spikes(at: Vector3) -> void:
	for k in 4:
		var p := at + _jit(0.8)
		var h := rng.randi_range(5, 12)
		for y in h:
			var w := 0.36 * (1.0 - float(y) / h) + 0.06
			s.glow(p + Vector3(0, y * 0.2 + 0.1, 0), Vector3(w, 0.2, w), Color("8ac4ec").lerp(Color("e0f8ff"), float(y) / h), 0.35, 0.1, 0.4)
		s.glow_point(p + Vector3.UP * 0.6)


func _frozen_warrior(at: Vector3) -> void:
	# A dark figure inside a block of ice.
	for y in 10:
		for x in range(-2, 3):
			s.glow(at + Vector3(x * 0.25, y * 0.25 + 0.125, 0.3), Vector3(0.25, 0.25, 0.04), Color("7ab4dc"), 0.25, 0.05, 0.5)
	_stack(at, 6, 0.2, 0.3, Color("1a2230"))
	s._voxel(at + Vector3(0, 1.4, 0), Vector3(0.28, 0.3, 0.28), Color("1a2230"))
	s.glow(at + Vector3(0, 1.45, -0.15), Vector3(0.16, 0.05, 0.04), Color("6ad0ff"), 1.0, 0.1, 0.6)
	for x in [-0.3, 0.3]:
		s._voxel(at + Vector3(x, 0.9, 0), Vector3(0.12, 0.6, 0.12), Color("1a2230"))


func _shield_rack(at: Vector3) -> void:
	s._voxel(at + Vector3(0, 0.7, 0), Vector3(1.6, 0.1, 0.1), Color("4a3424"))
	for i in 3:
		var p := at + Vector3((i - 1) * 0.5, 0.65, -0.1)
		_blob(p, 0.24, 0.08, [Color("6a2a2a"), Color("2a3a6a"), Color("6a6a2a")][i])
		s._voxel(p + Vector3(0, 0, -0.08), Vector3(0.1, 0.1, 0.06), Color("8a8a90"))


func _cold_brazier(at: Vector3) -> void:
	_stack(at, 6, 0.2, 0.22, Color("3a3c44"))
	s._voxel(at + Vector3(0, 1.25, 0), Vector3(0.8, 0.12, 0.8), Color("2a2c34"))
	for k in 6:
		s.glow(at + _jit(0.25) + Vector3(0, 1.4 + k * 0.12, 0), Vector3.ONE * (0.26 - k * 0.03), Color("6ad0ff").lerp(Color("e0f8ff"), k / 6.0), 1.0, 1.4, 0.9)
	s.glow_point(at + Vector3.UP * 1.5)


func _icicles(base: Vector3, n: Vector3, t: Vector3) -> void:
	var top := base + Vector3.UP * rng.randf_range(2.6, 3.6) - n * 0.05
	for k in rng.randi_range(2, 5):
		var p := top + t * rng.randf_range(-0.4, 0.4)
		var h := rng.randi_range(3, 8)
		for y in h:
			s.glow(p - Vector3.UP * y * 0.14, Vector3.ONE * (0.14 - y * 0.012), Color("b8e4ff"), 0.3, 0.05, 0.4)
	if rng.randf() < 0.4:
		s.glow(base + Vector3.UP * rng.randf_range(1.0, 2.0) + n * 0.04, Vector3(0.2, 0.26, 0.04) + t.abs() * 0.06, Color("6ad0ff"), 1.0, 0.12, 0.3)
		s.glow_point(base + Vector3.UP * 1.5)
	for k in 3:
		s._voxel(base + t * rng.randf_range(-0.4, 0.4) + Vector3.UP * 0.04 - n * 0.15, Vector3(0.3, 0.08, 0.3), Color("eef3f8"))


# --- The Glass Labyrinth ---------------------------------------------------------------

const RAINBOW := [Color("ff8af0"), Color("7af0ff"), Color("fff07a"), Color("8aff9a"), Color("ffb07a")]


func _glass_obelisk(at: Vector3) -> void:
	for y in 18:
		var w := 0.6 * (1.0 - y / 22.0)
		var c: Color = RAINBOW[(y / 3) % RAINBOW.size()]
		s.glow(at + Vector3(0, y * 0.22 + 0.11, 0), Vector3(w, 0.22, w), Color("e6f2f6").lerp(c, 0.25), 0.45, 0.15, 0.35)
	s.glow_point(at + Vector3.UP * 2.0)


func _prisms(at: Vector3) -> void:
	for k in 5:
		var p := at + _jit(0.9)
		var h := rng.randi_range(3, 8)
		var c: Color = RAINBOW[k % RAINBOW.size()]
		for y in h:
			s.glow(p + Vector3(0, y * 0.16 + 0.08, 0), Vector3(0.18, 0.16, 0.18), c, 0.8, 0.3, 0.45)
		s.glow_point(p + Vector3.UP * 0.5)


func _mirror(at: Vector3) -> void:
	var dir := Vector3.RIGHT.rotated(Vector3.UP, rng.randf() * PI)
	for y in 10:
		for i in range(-3, 4):
			s.glow(at + dir * i * 0.2 + Vector3(0, y * 0.2 + 0.3, 0), Vector3(0.2, 0.2, 0.2) * Vector3(1, 1, 1) * 0.95,
				Color("f4f8ff") if (i + y) % 4 else Color("ffe08a"), 0.5, 0.2, 0.4)
	_stack(at, 2, 0.15, 0.6, Color("b8a888"))


func _glass_dune(at: Vector3) -> void:
	for k in 10:
		s._voxel(at + _jit(1.2) + Vector3(0, 0.08, 0), Vector3(0.6, 0.16 + rng.randf() * 0.15, 0.6), Color("f0e2c0"))
	for k in 6:
		s.glow(at + _jit(1.0) + Vector3(0, 0.3, 0), Vector3(0.06, 0.25, 0.12), RAINBOW[k % RAINBOW.size()], 0.8, 0.4, 0.3)


func _lens_stand(at: Vector3) -> void:
	_stack(at, 7, 0.2, 0.14, Color("b8902a"))
	for i in 12:
		var a := i * TAU / 12.0
		s._voxel(at + Vector3(cos(a) * 0.4, 1.8 + sin(a) * 0.4, 0), Vector3.ONE * 0.12, Color("d8b04a"))
	s.glow(at + Vector3(0, 1.8, 0), Vector3(0.6, 0.6, 0.06), Color("f4f8ff"), 0.9, 0.3, 0.6)
	s.glow_point(at + Vector3.UP * 1.8)


func _lens_lamp(at: Vector3) -> void:
	_stack(at, 9, 0.2, 0.16, Color("b8902a"))
	s.glow(at + Vector3(0, 2.0, 0), Vector3(0.32, 0.32, 0.32), Color("fff6d8"), 1.0, 0.3, 1.0)
	for k in 4:
		var d := Vector3.FORWARD.rotated(Vector3.UP, k * TAU / 4.0) * 0.32
		s.glow(at + Vector3(0, 2.0, 0) + d, Vector3.ONE * 0.1, RAINBOW[k], 1.0, 0.6, 0.6)
	s.glow_point(at + Vector3.UP * 2.0)


func _wall_prisms(base: Vector3, n: Vector3, t: Vector3) -> void:
	for k in rng.randi_range(2, 4):
		var p := base + t * rng.randf_range(-0.4, 0.4) - n * 0.1
		var h := rng.randi_range(2, 6)
		var c: Color = RAINBOW[rng.randi() % RAINBOW.size()]
		for y in h:
			s.glow(p + Vector3(0, y * 0.14 + 0.07, 0) - n * y * 0.02, Vector3(0.12, 0.14, 0.12), c, 0.8, 0.25, 0.3)
	s.glow_point(base + Vector3.UP * 0.4)


# --- The Unlit Cathedral ---------------------------------------------------------------

const WAX := Color("ece6d8")
const FLAME := Color("ffcf8a")


func _candle(p: Vector3, h: int) -> void:
	for y in h:
		s._voxel(p + Vector3(0, y * 0.08 + 0.04, 0), Vector3(0.07, 0.08, 0.07), WAX.darkened(0.04 * (y % 2)))
	s.glow(p + Vector3(0, h * 0.08 + 0.07, 0), Vector3(0.05, 0.1, 0.05), FLAME, 1.0, 2.4, 1.0)


func _candelabra(at: Vector3) -> void:
	var iron := Color("26242e")
	_stack(at, 10, 0.2, 0.12, iron)
	for side in [-1.0, 0.0, 1.0]:
		var arm := at + Vector3(side * 0.45, 2.0 - absf(side) * 0.2, 0)
		s._voxel(arm, Vector3(0.12, 0.08, 0.12), iron)
		s._voxel(at + Vector3(side * 0.22, 1.85, 0), Vector3(0.45, 0.06, 0.06), iron)
		_candle(arm + Vector3.UP * 0.05, 4)
	s.glow_point(at + Vector3.UP * 2.2)


func _pews(at: Vector3) -> void:
	for k in 3:
		s._voxel(at + Vector3(0, 0.35, k * 0.8 - 0.8), Vector3(1.8, 0.1, 0.4), Color("2a1e1a"))
		s._voxel(at + Vector3(0, 0.65, k * 0.8 - 0.6), Vector3(1.8, 0.5, 0.08), Color("221814"))
		for x in [-0.8, 0.8]:
			s._voxel(at + Vector3(x, 0.17, k * 0.8 - 0.8), Vector3(0.08, 0.35, 0.35), Color("221814"))


func _angel(at: Vector3) -> void:
	var stone := Color("4a4654")
	s._voxel(at + Vector3(0, 0.25, 0), Vector3(0.9, 0.5, 0.9), Color("2e2c36"))
	_stack(at + Vector3.UP * 0.5, 7, 0.2, 0.4, stone, 0.3)
	_blob(at + Vector3(0, 2.1, 0), 0.18, 0.08, stone)
	for side in [-1.0, 1.0]:
		for i in 6:
			s._voxel(at + Vector3(side * (0.3 + i * 0.12), 1.6 + i * 0.1 - (i * i) * 0.02, 0.15), Vector3(0.14, 0.5 - i * 0.05, 0.06), stone.lightened(0.05 * i))
	s.glow(at + Vector3(0, 2.1, -0.16), Vector3(0.1, 0.04, 0.04), Color("c070ff"), 0.8, 0.2, 0.3)


func _organ(at: Vector3) -> void:
	for i in 9:
		var h := 8 + int(abs(4 - i) * -1.5 + 6)
		for y in h:
			s._voxel(at + Vector3((i - 4) * 0.22, y * 0.22 + 0.11, 0), Vector3(0.18, 0.22, 0.18), Color("b8902a").darkened(0.15 if y % 4 == 0 else 0.0))
	s._voxel(at + Vector3(0, 0.5, -0.4), Vector3(2.0, 1.0, 0.5), Color("2a1e1a"))


func _fallen_bell(at: Vector3) -> void:
	for y in 6:
		var w := 0.5 + y * 0.18
		s._voxel(at + Vector3(0, 1.1 - y * 0.18, 0), Vector3(w, 0.18, w), Color("6a5a3a").darkened(y * 0.04))
	for k in 5: _candle(at + _jit(1.2), rng.randi_range(2, 5))


func _candle_tree(at: Vector3) -> void:
	var iron := Color("26242e")
	_stack(at, 12, 0.2, 0.14, iron)
	for ring in 2:
		var r := 0.5 - ring * 0.2
		for k in 6:
			var a := k * TAU / 6.0 + ring
			var p := at + Vector3(cos(a) * r, 1.6 + ring * 0.6, sin(a) * r)
			s._voxel(p, Vector3(0.1, 0.06, 0.1), iron)
			_candle(p + Vector3.UP * 0.03, 3 + ring)
	s.glow_point(at + Vector3.UP * 2.0)


func _wall_candles(base: Vector3, n: Vector3, t: Vector3) -> void:
	for k in rng.randi_range(3, 7):
		_candle(base + t * rng.randf_range(-0.45, 0.45) - n * rng.randf_range(0.0, 0.25), rng.randi_range(2, 7))
	for k in 3:  # wax pooled under them
		s._voxel(base + t * rng.randf_range(-0.4, 0.4) + Vector3.UP * 0.02 - n * 0.1, Vector3(0.2, 0.03, 0.2), WAX.darkened(0.1))
	s.glow_point(base + Vector3.UP * 0.4)


# --- The Starless Sepulchre -----------------------------------------------------------

const GOLD := Color("ffc24a")


func _floating_pillar(at: Vector3) -> void:
	var lift := rng.randf_range(0.3, 1.0)
	var tilt := rng.randf_range(-0.15, 0.15)
	for y in 14:
		var p := at + Vector3(tilt * y * 0.2, lift + y * 0.25 + 0.125, 0)
		if y in [4, 9]:
			s.glow(p, Vector3(0.7, 0.06, 0.7), GOLD, 1.0, 0.12, 0.6)
		else:
			s._voxel(p, Vector3(0.62, 0.25, 0.62), Color("18161e").lightened(0.04 * (y % 2)))
	s.glow_point(at + Vector3.UP * 2.0)


func _star_cluster(at: Vector3) -> void:
	for k in 14:
		var p := at + _jit(1.2) + Vector3.UP * rng.randf_range(0.4, 3.0)
		s.glow(p, Vector3.ONE * rng.randf_range(0.04, 0.1), Color("ffffff") if k % 3 else Color("fff0b0"), 1.0, rng.randf_range(0.3, 1.2), 0.5)
	s.glow_point(at + Vector3.UP * 1.5)


func _mended_statue(at: Vector3) -> void:
	var porcelain := Color("e8e4f0")
	_stack(at, 6, 0.22, 0.6, porcelain, 0.3)
	_blob(at + Vector3(0.3, 0.25, 0.5), 0.3, 0.1, porcelain)  # its fallen head
	for y in 6:
		s.glow(at + Vector3(sin(y * 1.3) * 0.2, y * 0.22 + 0.11, -0.31), Vector3(0.04, 0.22, 0.04), GOLD, 1.0, 0.1, 0.6)


func _void_crystal(at: Vector3) -> void:
	for k in 3:
		var p := at + _jit(0.6)
		var h := rng.randi_range(6, 12)
		for y in h:
			var w := 0.4 * (1.0 - float(y) / h) + 0.08
			s.glow(p + Vector3(0, y * 0.2 + 0.1, 0), Vector3(w, 0.2, w), Color("2a1a48").lerp(Color("8a7aff"), float(y) / h), 0.6, 0.2, 0.4)
		s.glow_point(p + Vector3.UP)


func _halo_piece(at: Vector3) -> void:
	var start := rng.randf() * TAU
	for i in 10:
		var a := start + i * 0.18
		s.glow(at + Vector3(cos(a) * 1.2, 0.15 + sin(a) * 0.1 + 0.2, sin(a) * 1.2), Vector3(0.24, 0.18, 0.24), GOLD, 0.8, 0.2, 0.6)


func _star_brazier(at: Vector3) -> void:
	var lift := Vector3.UP * 1.6
	_blob(at + lift, 0.3, 0.1, Color("fff6d8"), 1.0, 0.3, 1.0)
	for k in 6:
		var a := k * TAU / 6.0
		s._voxel(at + lift + Vector3(cos(a) * 0.5, -0.35, sin(a) * 0.5), Vector3(0.12, 0.12, 0.12), Color("18161e"))
	s.glow_point(at + lift)


func _gold_seam(base: Vector3, n: Vector3, t: Vector3) -> void:
	var h := rng.randi_range(8, 22)
	var x := 0.0
	for k in h:
		x += rng.randf_range(-0.12, 0.12)
		s.glow(base + Vector3.UP * (k * 0.12 + 0.06) + t * x + n * 0.06, Vector3(0.06, 0.13, 0.04) + n.abs() * 0.04, GOLD, 1.0, 0.1, 0.5)
	for k in 3:
		s.glow(base + Vector3.UP * rng.randf_range(0.5, 3.0) + t * rng.randf_range(-0.4, 0.4) - n * 0.1, Vector3.ONE * 0.05, Color("ffffff"), 1.0, 1.0, 0.3)
	s.glow_point(base + Vector3.UP * h * 0.06)
