class_name DungeonPortalStyles
extends Node3D
## The dressing round a dungeon entrance, by its portal_hole.shape: every
## Surface dungeon's door looks like its dungeon (a fairy ring of glowing
## mushrooms, a whirlpool full of wreckage, a jade serpent arch, soul lanterns
## circling a dark pool, barrow stones, floating glass, a rose window, a gold
## crack in the world). DungeonPortal keeps the hole, the travel and the
## lifetime; this only draws and animates, and grows and withers with it.
##
## Pieces: {at, size, color, glow, move, a (phase), r (radius), h (height), s (speed)}
## move: "" still, "orbit" round the hole, "bob" up and down, "spin" in place,
## "rise" up out of the hole and again, "pulse" (glow pieces breathe).

var style: Dictionary
var _pieces: Array[Dictionary] = []
var _solid: MultiMeshInstance3D
var _lit: MultiMeshInstance3D
var _light: OmniLight3D
var _rng := RandomNumberGenerator.new()
var _t := 0.0
var _solid_index: Array[int] = []
var _lit_index: Array[int] = []


func _init(p_style: Dictionary) -> void:
	style = p_style
	_rng.seed = int(style.get("seed", 1)) + 501


func _ready() -> void:
	var r := float(style.radius)
	match str(style.shape):
		"fairy_ring": _fairy_ring(r)
		"whirlpool": _whirlpool(r)
		"serpent_arch": _serpent_arch(r)
		"soul_lanterns": _soul_lanterns(r)
		"barrow_stones": _barrow_stones(r)
		"prism_shards": _prism_shards(r)
		"cathedral_window": _cathedral_window(r)
		"kintsugi_rift": _kintsugi_rift(r)
	_solid = _batch(false)
	_lit = _batch(true)
	for i in _pieces.size():
		if _pieces[i].glow: _lit_index.append(i)
		else: _solid_index.append(i)
	_solid.multimesh.instance_count = _solid_index.size()
	_lit.multimesh.instance_count = _lit_index.size()
	for k in _solid_index.size(): _solid.multimesh.set_instance_color(k, _pieces[_solid_index[k]].color)
	for k in _lit_index.size(): _lit.multimesh.set_instance_color(k, _pieces[_lit_index[k]].color)
	_light = OmniLight3D.new()
	_light.light_color = style.get("glow", Color.WHITE)
	_light.omni_range = r * 4.0
	_light.position.y = 1.2
	_light.shadow_enabled = false
	add_child(_light)
	update(0.0, 0.0, 0.0)


func _batch(glow: bool) -> MultiMeshInstance3D:
	var batch := MultiMeshInstance3D.new()
	batch.multimesh = MultiMesh.new()
	batch.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	batch.multimesh.use_colors = true
	batch.multimesh.mesh = BoxMesh.new()
	if glow:
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.vertex_color_use_as_albedo = true
		m.emission_enabled = true
		m.emission_energy_multiplier = 1.0
		batch.material_override = m
	else:
		var m := ShaderMaterial.new()
		m.shader = preload("res://shaders/dungeon_voxel.gdshader")
		batch.material_override = m
	batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(batch)
	return batch


## Called every frame by the portal: `opening` 0..1 (the hole), `growth` 0..1
## (dressing growing in or withering away).
func update(delta: float, opening: float, growth: float) -> void:
	_t += delta
	_light.light_energy = 1.6 * growth * (0.85 + 0.15 * sin(_t * 2.3))
	for k in _solid_index.size():
		_solid.multimesh.set_instance_transform(k, _transform(_pieces[_solid_index[k]], opening, growth))
	for k in _lit_index.size():
		_lit.multimesh.set_instance_transform(k, _transform(_pieces[_lit_index[k]], opening, growth))


func _transform(p: Dictionary, opening: float, growth: float) -> Transform3D:
	var at: Vector3 = p.at
	var size: Vector3 = p.size
	var basis := Basis.IDENTITY
	var phase: float = p.get("a", 0.0)
	var speed: float = p.get("s", 1.0)
	match str(p.get("move", "")):
		"orbit":
			var a := phase + _t * speed
			var r: float = p.get("r", 1.0) * lerpf(0.6, 1.0, opening)
			at = Vector3(cos(a) * r, at.y + sin(_t * 1.3 + phase) * 0.12, sin(a) * r)
			basis = Basis(Vector3.UP, -a)
		"bob":
			at.y += sin(_t * speed + phase) * float(p.get("h", 0.15))
			basis = Basis(Vector3.UP, _t * 0.4 + phase)
		"spin":
			basis = Basis(Vector3.UP, _t * speed + phase) * Basis(Vector3.RIGHT, 0.4)
			at.y += sin(_t * 0.9 + phase) * 0.1
		"rise":
			var k := fmod(_t * speed + phase, 1.0)
			at = Vector3(at.x * (1.0 - k * 0.3), lerpf(0.1, float(p.get("h", 3.0)), k), at.z * (1.0 - k * 0.3))
			size *= sin(k * PI)
		"pulse":
			size *= 0.85 + 0.25 * (0.5 + 0.5 * sin(_t * speed + phase))
	return Transform3D(basis * Basis.from_scale(size * maxf(0.001, growth)), at * Vector3(1, growth, 1))


func _add(at: Vector3, size: Vector3, color: Color, glow := false, extra := {}) -> void:
	var p := {at = at, size = size, color = color, glow = glow}
	p.merge(extra, true)
	_pieces.append(p)


func _rim(r: float) -> Vector3:
	var a := _rng.randf() * TAU
	return Vector3(cos(a) * r, 0, sin(a) * r / 1.08)


# --- The eight doors ------------------------------------------------------------------

func _fairy_ring(r: float) -> void:
	for k in 11:
		var a := TAU * k / 11.0 + _rng.randf_range(-0.1, 0.1)
		var base := Vector3(cos(a), 0, sin(a)) * (r + 0.45 + _rng.randf() * 0.3)
		var h := _rng.randf_range(0.35, 0.8)
		_add(base + Vector3.UP * h * 0.5, Vector3(0.12, h, 0.12), Color("d8cdb0"))
		var cap := _rng.randf_range(0.32, 0.5)
		_add(base + Vector3.UP * (h + 0.05), Vector3(cap, 0.14, cap), Color("c47a2c"))
		_add(base + Vector3.UP * (h - 0.04), Vector3(cap * 0.85, 0.03, cap * 0.85), Color("6fe8d6"), true, {move = "pulse", s = 1.5, a = k})
	for k in 24:
		_add(_rim(r * 0.7), Vector3.ONE * 0.06, Color("ffc04a"), true, {move = "rise", h = 2.6, s = 0.25, a = k / 24.0})


func _whirlpool(r: float) -> void:
	for k in 9:
		var color: Color = [Color("5a4330"), Color("6a4a30"), Color("4c3828")][k % 3]
		_add(Vector3(0, 0.12, 0), Vector3(0.5, 0.1, 0.18) if k % 3 else Vector3(0.3, 0.32, 0.3), color, false,
			{move = "orbit", r = r * _rng.randf_range(0.45, 0.9), s = 0.6 + k * 0.05, a = TAU * k / 9.0})
	for k in 16:
		_add(Vector3(0, 0.06, 0), Vector3(0.14, 0.04, 0.14), Color("a8f0e8"), true, {move = "orbit", r = r * _rng.randf_range(0.3, 0.95),
			s = 1.2 + _rng.randf(), a = _rng.randf() * TAU})
	# A broken mast leaning out of the water, and a lantern on a post.
	for y in 10:
		_add(Vector3(r + 0.3 - y * 0.06, 0.15 + y * 0.2, 0.4), Vector3(0.18, 0.2, 0.18), Color("4a3424"))
	_add(Vector3(-r - 0.5, 0.9, 0), Vector3(0.1, 1.8, 0.1), Color("4a3424"))
	_add(Vector3(-r - 0.3, 1.75, 0), Vector3(0.22, 0.3, 0.22), Color("ffb860"), true, {move = "pulse", s = 6.0})


func _serpent_arch(r: float) -> void:
	var jade := Color("4a9a74")
	for side in [-1.0, 1.0]:
		for y in 8:
			_add(Vector3(side * (r + 0.4), y * 0.3 + 0.15, 0), Vector3(0.45, 0.3, 0.45), jade.darkened(0.1 * (y % 2)))
	for i in 17:
		var a := i / 16.0 * PI
		_add(Vector3(cos(a) * (r + 0.4), 2.4 + sin(a) * 1.0, 0), Vector3(0.36, 0.36, 0.4), jade.lightened(0.08 * (i % 2)))
		if i % 4 == 2:
			_add(Vector3(cos(a) * (r + 0.4), 2.62 + sin(a) * 1.0, 0), Vector3(0.12, 0.2, 0.12), Color("ffd060"), true, {move = "pulse", s = 2.0, a = i})
	_add(Vector3(0, 3.55, -0.25), Vector3(0.5, 0.4, 0.55), jade)  # the serpent's head at the crown
	for side in [-1.0, 1.0]:
		_add(Vector3(side * 0.15, 3.65, -0.5), Vector3.ONE * 0.09, Color("ffd060"), true)
	for k in 5:
		_add(Vector3(_rng.randf_range(-r, r), 1.0 + k * 0.3, _rng.randf_range(-0.5, 0.5)), Vector3(0.25, 0.25, 0.04), Color("ffd060"), true,
			{move = "bob", h = 0.25, s = 1.2, a = k})


func _soul_lanterns(r: float) -> void:
	var colors := [Color("5ff0ff"), Color("e070ff"), Color("ffd27a")]
	for k in 7:
		var height := 1.4 + (k % 3) * 0.45
		_add(Vector3(0, height, 0), Vector3(0.22, 0.28, 0.22), colors[k % 3], true,
			{move = "orbit", r = r + 0.2 + (k % 2) * 0.5, s = 0.35 if k % 2 else -0.28, a = TAU * k / 7.0})
		_add(Vector3(0, height + 0.2, 0), Vector3(0.28, 0.05, 0.28), Color("2c2a44"), false,
			{move = "orbit", r = r + 0.2 + (k % 2) * 0.5, s = 0.35 if k % 2 else -0.28, a = TAU * k / 7.0})
	for k in 30:
		_add(_rim(r * 0.6), Vector3(0.07, 0.12, 0.07), colors[k % 3], true, {move = "rise", h = 3.4, s = 0.2, a = k / 30.0})
	# Glowing fronds round the rim.
	for k in 14:
		var a := TAU * k / 14.0
		var base := Vector3(cos(a), 0, sin(a) / 1.08) * (r + 0.3)
		for i in 4:
			_add(base + Vector3(cos(a), 0, sin(a)) * i * 0.12 + Vector3.UP * (0.1 + i * 0.12), Vector3(0.08, 0.08, 0.08),
				Color("1f3a44"), false)
		_add(base + Vector3(cos(a), 0, sin(a)) * 0.55 + Vector3.UP * 0.55, Vector3.ONE * 0.09, colors[k % 3], true, {move = "pulse", s = 1.0, a = k})


func _barrow_stones(r: float) -> void:
	for k in 5:
		var a := TAU * k / 5.0 + 0.3
		var base := Vector3(cos(a), 0, sin(a)) * (r + 0.7)
		var h := _rng.randi_range(6, 9)
		for y in h:
			_add(base + Vector3.UP * (y * 0.22 + 0.11), Vector3(0.45, 0.22, 0.3), Color("4a5262").lightened(0.05 * (y % 2)))
		_add(base + Vector3.UP * (h * 0.22 + 0.04), Vector3(0.48, 0.06, 0.33), Color("e8f0f8"))
		for y in [2, 4]:
			_add(base - Vector3(cos(a), 0, sin(a)) * 0.16 + Vector3.UP * (y * 0.22 + 0.11), Vector3(0.12, 0.14, 0.04), Color("6ad0ff"), true,
				{move = "pulse", s = 1.4, a = k + y})
	for k in 20:
		_add(_rim(r * 0.8), Vector3.ONE * 0.05, Color("e8f8ff"), true, {move = "rise", h = 2.0, s = 0.18, a = k / 20.0})


func _prism_shards(r: float) -> void:
	var rainbow := [Color("ff8af0"), Color("7af0ff"), Color("fff07a"), Color("8aff9a"), Color("ffb07a"), Color("8a9aff")]
	for k in 9:
		var color: Color = rainbow[k % rainbow.size()]
		_add(Vector3(0, 1.0 + (k % 3) * 0.6, 0), Vector3(0.18, 0.55, 0.08), color, true,
			{move = "orbit", r = r + 0.3, s = 0.4 if k % 2 else -0.3, a = TAU * k / 9.0})
	for y in 14:
		_add(Vector3(0, 0.3 + y * 0.3, 0), Vector3(0.12, 0.3, 0.12), Color("fff6d8"), true, {move = "pulse", s = 3.0, a = y * 0.4})
	for k in 6:
		_add(Vector3(0, 2.2, 0), Vector3(0.3, 0.3, 0.3), rainbow[k], true, {move = "spin", s = 0.8, a = k})


func _cathedral_window(r: float) -> void:
	var stone := Color("2e2c36")
	var glass := [Color("e04a8a"), Color("8a4ae0"), Color("4a6ae0"), Color("f0c04a")]
	var back := -r - 0.4
	for side in [-1.0, 1.0]:
		for y in 12:
			_add(Vector3(side * 1.5, y * 0.3 + 0.15, back), Vector3(0.4, 0.3, 0.4), stone)
	for i in 13:
		var a := i / 12.0 * PI
		_add(Vector3(cos(a) * 1.5, 3.6 + sin(a) * 1.3, back), Vector3(0.36, 0.36, 0.4), stone)
	# The rose window: rings of colored panes round a gold heart.
	for ring in 3:
		var count := 6 + ring * 6
		for k in count:
			var a := TAU * k / count
			var rr := 0.25 + ring * 0.3
			_add(Vector3(cos(a) * rr, 3.4 + sin(a) * rr, back + 0.05), Vector3(0.22, 0.22, 0.05), glass[(k + ring) % 4], true,
				{move = "pulse", s = 0.7, a = k * 0.5 + ring})
	_add(Vector3(0, 3.4, back + 0.06), Vector3(0.2, 0.2, 0.05), Color("fff0b0"), true)
	for k in 14:
		var a := TAU * k / 14.0
		var base := Vector3(cos(a), 0, sin(a) / 1.08) * (r + 0.35)
		var h := _rng.randi_range(2, 6)
		_add(base + Vector3.UP * h * 0.04, Vector3(0.08, h * 0.08, 0.08), Color("ece6d8"))
		_add(base + Vector3.UP * (h * 0.08 + 0.06), Vector3(0.05, 0.1, 0.05), Color("ffcf8a"), true, {move = "pulse", s = 9.0, a = k})


func _kintsugi_rift(r: float) -> void:
	var gold := Color("ffc24a")
	for k in 9:
		var a := TAU * k / 9.0 + _rng.randf_range(-0.2, 0.2)
		var dir := Vector3(cos(a), 0, sin(a))
		var at := dir * r
		for i in _rng.randi_range(6, 12):
			at += dir.rotated(Vector3.UP, _rng.randf_range(-0.5, 0.5)) * 0.2
			_add(at + Vector3.UP * 0.03, Vector3(0.1, 0.03, 0.1), gold, true, {move = "pulse", s = 1.0, a = k + i * 0.3})
	for k in 8:
		_add(Vector3(0, 0.8 + (k % 3) * 0.5, 0), Vector3(0.3, 0.42, 0.1), Color("18161e"), false,
			{move = "orbit", r = r + 0.6, s = 0.18 if k % 2 else -0.14, a = TAU * k / 8.0})
		_add(Vector3(0, 0.8 + (k % 3) * 0.5 + 0.22, 0), Vector3(0.32, 0.04, 0.12), gold, true,
			{move = "orbit", r = r + 0.6, s = 0.18 if k % 2 else -0.14, a = TAU * k / 8.0})
	# A broken halo turning above.
	for k in 14:
		if k in [3, 4, 10]: continue
		_add(Vector3(0, 3.2, 0), Vector3(0.22, 0.16, 0.22), gold, true, {move = "orbit", r = 1.3, s = 0.25, a = TAU * k / 14.0})
	for k in 26:
		_add(_rim(r * 0.9), Vector3.ONE * 0.05, Color("ffffff"), true, {move = "rise", h = 4.0, s = 0.12, a = k / 26.0})
