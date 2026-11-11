class_name SpellFX
extends RefCounted
## The look of spell magic: soft motes instead of voxels, kept calm. Each
## spell has a style (see style()): a main color, a smaller share of accent
## motes, a sprite and how dense it is. Some spells are black magic: their
## main motes darken the world instead of glowing (Spell of the Blue is mostly
## darkness with a few blue sparks). Divine spells are denser and spin faster.
##
## The shield aura is two rings of motes around the bubble (aura_rings()),
## tilted against each other; MagicShield spins them in opposite directions
## and slowly turns their tilt the other way. Letting go of the shield flings
## the motes outward (gather() / release()). The one-shot effects (hit(),
## cast(), ring_burst()) clean themselves up.

const MOTE_SHADER := preload("res://shaders/spell_mote.gdshader")
const DARK_SHADER := preload("res://shaders/spell_mote_dark.gdshader")
## Mote sprites (see spell_mote.gdshaderinc).
const DOT := 0
const STAR := 1
const FLAKE := 2
const LEAF := 3
const BUBBLE := 4
const SHARD := 5
const INK := Color(0.96, 0.95, 0.91)  # the UI's white ivy
const VOID := Color(0.01, 0.012, 0.025, 0.95)
## How the two aura rings move: tilt (radians), spin and drift of the tilt
## (radians per second, opposite for the second ring).
const RING_TILT := 0.45
const RING_SPIN := 2.2
const RING_DRIFT := 0.5

static var _quads := {}  # "shape/energy/dark" -> QuadMesh


## How a spell's magic looks. Keys: shape, motes (per ring), size, heavy,
## main, main_dark, accent, accent_share, edge (rim of dark motes) and
## darkness (how much the warp bubble and ring darken the world).
static func style(spell: Item) -> Dictionary:
	var s := {shape = DOT, motes = 30, size = 0.14, heavy = false, main = INK, main_dark = false,
			accent = Color(0.85, 0.92, 1.0), accent_share = 0.25, edge = Color(0.2, 0.3, 0.6), darkness = 0.0}
	if spell == null:
		return s
	s.accent = spell.shield_arcs
	s.main = INK.lerp(spell.shield_arcs, 0.25)
	if spell.is_divine():
		s.merge({motes = 70, size = 0.18, heavy = true, shape = STAR}, true)
		match spell.id:
			"D_spell_oftheblue": s.merge({shape = DOT, main = VOID, main_dark = true, accent = Color("#2f6fe0"),
					accent_share = 0.3, edge = Color("#1d3f8f"), darkness = 0.6, size = 0.22}, true)
			"D_spell_ofthedivine": s.merge({main = INK.lerp(Color("#ffde46"), 0.2), accent = Color("#ffd75a"),
					accent_share = 0.35, motes = 90}, true)
			"D_spell_offrost": s.merge({shape = FLAKE, main = INK}, true)
			"D_spell_ofstorm": s.merge({shape = SHARD, main = INK}, true)
			"D_spell_ofiron": s.merge({main = VOID, main_dark = true, accent = INK, accent_share = 0.45,
					edge = Color(0.55, 0.55, 0.6), darkness = 0.3}, true)
		return s
	var tier := spell.tier
	s.motes = 16 + tier * 6
	if tier == 4: s.shape = STAR
	elif tier >= 5: s.shape = LEAF
	return s


## Fewer particles on lower particle settings.
static func quality() -> float:
	return 1.0 if str(AppSettings.graphics.get("particles", "high")) == "high" else 0.55


static func _count(n: float) -> int:
	return maxi(1, roundi(n * quality()))


# --- Shield aura ------------------------------------------------------------------

## Two rings of motes just outside a bubble of `radius`. Each is a pivot to
## spin (meta "spin", "tilt", "drift") holding a main and an accent layer.
static func aura_rings(spell: Item, radius: float) -> Array[Node3D]:
	var s := style(spell)
	var out: Array[Node3D] = []
	var speed := 1.3 if s.heavy else 1.0
	for i in 2:
		var side := 1.0 if i == 0 else -1.0
		var pivot := Node3D.new()
		pivot.set_meta("spin", RING_SPIN * speed * side)
		pivot.set_meta("tilt", RING_TILT * side)
		pivot.set_meta("drift", -RING_DRIFT * side)
		pivot.set_meta("angle", randf() * TAU)
		pivot.set_meta("turn", 0.0)
		for accent in [false, true]:
			var share: float = s.accent_share if accent else 1.0 - s.accent_share
			var pm := ParticleProcessMaterial.new()
			pm.gravity = Vector3.ZERO
			pm.color = s.accent if accent else s.main
			pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
			pm.emission_ring_axis = Vector3.UP
			pm.emission_ring_radius = radius * 1.3
			pm.emission_ring_inner_radius = radius * 1.18
			pm.emission_ring_height = 0.08
			pm.initial_velocity_min = 0.0
			pm.initial_velocity_max = 0.0
			pm.angle_min = -180.0
			pm.angle_max = 180.0
			pm.angular_velocity_min = -60.0
			pm.angular_velocity_max = 60.0
			pm.scale_min = s.size * 0.7
			pm.scale_max = s.size * (1.2 if accent else 1.4)
			pm.scale_curve = _swell()
			var dark: bool = s.main_dark and not accent
			var layer := _layer(pm, _quad(s.shape, 2.2 if accent else 1.6, dark, s.edge), _count(s.motes * share), 1.2)
			layer.local_coords = true  # the rings follow the character
			pivot.add_child(layer)
		out.append(pivot)
	return out


## Spins a ring from aura_rings() on, by `delta` seconds.
static func spin(pivot: Node3D, delta: float) -> void:
	var angle: float = pivot.get_meta("angle") + float(pivot.get_meta("spin")) * delta
	var turn: float = pivot.get_meta("turn") + float(pivot.get_meta("drift")) * delta
	pivot.set_meta("angle", angle)
	pivot.set_meta("turn", turn)
	pivot.basis = Basis(Vector3.UP, turn) * Basis(Vector3.RIGHT, pivot.get_meta("tilt")) * Basis(Vector3.UP, angle)


## Starts a ring's motes again, calm and in place.
static func gather(pivot: Node3D) -> void:
	for p: GPUParticles3D in pivot.get_children():
		var pm := p.process_material as ParticleProcessMaterial
		pm.radial_accel_min = 0.0
		pm.radial_accel_max = 0.0
		pm.damping_min = 0.0
		pm.damping_max = 0.0
		if not p.emitting:
			p.restart()
		p.emitting = true


## Lets go: every mote still alive is flung outward and the ring stops.
static func release(pivot: Node3D, heavy: bool) -> void:
	for p: GPUParticles3D in pivot.get_children():
		var pm := p.process_material as ParticleProcessMaterial
		pm.radial_accel_min = 40.0 if heavy else 28.0
		pm.radial_accel_max = 60.0 if heavy else 40.0
		pm.damping_min = 2.0
		pm.damping_max = 3.0
		p.emitting = false


# --- One-shot effects -------------------------------------------------------------

## A spell striking something at `pos`, travelling along `direction`: a small
## flash and a puff of the spell's motes thrown onward.
static func hit(parent: Node, pos: Vector3, direction: Vector3, spell: Item) -> void:
	if not _can_spawn(parent):
		return
	var s := style(spell)
	flash(parent, pos, s.accent, 1.1 if s.heavy else 0.7)
	var dir := direction.normalized() if direction.length() > 0.01 else Vector3.UP
	for accent in [false, true]:
		var pm := ParticleProcessMaterial.new()
		pm.gravity = Vector3(0, -3, 0)
		pm.color = s.accent if accent else s.main
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		pm.emission_sphere_radius = 0.2
		pm.direction = dir
		pm.spread = 70.0
		pm.initial_velocity_min = 2.0
		pm.initial_velocity_max = 6.0 if s.heavy else 4.5
		pm.damping_min = 4.0
		pm.damping_max = 6.0
		pm.angle_min = -180.0
		pm.angle_max = 180.0
		pm.scale_min = s.size * 0.8
		pm.scale_max = s.size * 1.6
		pm.scale_curve = _swell()
		var amount: float = (20.0 if s.heavy else 10.0) * (s.accent_share if accent else 1.0 - s.accent_share)
		_fire(parent, _layer(pm, _quad(s.shape, 2.2, s.main_dark and not accent, s.edge), _count(amount), 0.5), pos)


## Casting a ring: a flash and a ring of motes spreading out from the caster.
static func cast(parent: Node, pos: Vector3, spell: Item) -> void:
	if not _can_spawn(parent):
		return
	var s := style(spell)
	flash(parent, pos + Vector3.UP * 0.9, s.accent, 1.6 if s.heavy else 1.1)
	_ring_puff(parent, Transform3D(Basis(), pos + Vector3.UP * 0.9), 0.6, s, 0.5, 6.0)


## A ring that reached its edge bursts: its motes scatter outward and up from
## the whole circle. `xform` is the ring's transform.
static func ring_burst(parent: Node, xform: Transform3D, radius: float, spell: Item) -> void:
	if not _can_spawn(parent):
		return
	var s := style(spell)
	_ring_puff(parent, Transform3D(xform.basis, xform.origin + xform.basis.y * 0.9), radius, s, 1.0 + radius * 0.15, 10.0 if s.heavy else 7.0)


static func _ring_puff(parent: Node, xform: Transform3D, radius: float, s: Dictionary, density: float, push: float) -> void:
	for accent in [false, true]:
		var pm := ParticleProcessMaterial.new()
		pm.gravity = Vector3(0, -2, 0)
		pm.color = s.accent if accent else s.main
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
		pm.emission_ring_axis = Vector3.UP
		pm.emission_ring_radius = radius
		pm.emission_ring_inner_radius = radius * 0.9
		pm.emission_ring_height = 0.2
		pm.direction = Vector3.UP
		pm.spread = 40.0
		pm.initial_velocity_min = 0.5
		pm.initial_velocity_max = 2.5
		pm.radial_velocity_min = push * 0.4
		pm.radial_velocity_max = push
		pm.damping_min = 3.0
		pm.damping_max = 5.0
		pm.angle_min = -180.0
		pm.angle_max = 180.0
		pm.angular_velocity_min = -120.0
		pm.angular_velocity_max = 120.0
		pm.scale_min = s.size * 0.8
		pm.scale_max = s.size * 1.6
		pm.scale_curve = _swell()
		var amount: float = s.motes * density * (s.accent_share if accent else 1.0 - s.accent_share)
		_fire(parent, _layer(pm, _quad(s.shape, 2.2, s.main_dark and not accent, s.edge), _count(amount), 0.9), xform.origin, xform.basis)


## Motes trailing along a rolling warp ring's edge (a main and an accent
## layer); MagicRing keeps their emission radius on its edge.
static func edge_motes(spell: Item) -> Array[GPUParticles3D]:
	var s := style(spell)
	var out: Array[GPUParticles3D] = []
	for accent in [false, true]:
		var pm := ParticleProcessMaterial.new()
		pm.gravity = Vector3(0, -1.5, 0)
		pm.color = s.accent if accent else s.main
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
		pm.emission_ring_axis = Vector3.UP
		pm.emission_ring_height = 0.2
		pm.direction = Vector3.UP
		pm.spread = 30.0
		pm.initial_velocity_min = 0.5
		pm.initial_velocity_max = 1.5
		pm.angle_min = -180.0
		pm.angle_max = 180.0
		pm.scale_min = s.size * 0.7
		pm.scale_max = s.size * 1.3
		pm.scale_curve = _swell()
		var amount: float = s.motes * 1.5 * (s.accent_share if accent else 1.0 - s.accent_share)
		var p := _layer(pm, _quad(s.shape, 2.0, s.main_dark and not accent, s.edge), _count(amount), 0.5)
		p.local_coords = true
		p.visibility_aabb = AABB(Vector3(-16, -2, -16), Vector3(32, 6, 32))
		out.append(p)
	return out


## A soft bloom that swells and fades in a blink.
static func flash(parent: Node, pos: Vector3, color: Color, size := 1.0) -> void:
	if not _can_spawn(parent):
		return
	var pm := ParticleProcessMaterial.new()
	pm.gravity = Vector3.ZERO
	pm.initial_velocity_min = 0.0
	pm.initial_velocity_max = 0.0
	pm.color_ramp = _ramp([color.lerp(INK, 0.5), Color(color, 0.0)])
	pm.scale_min = size
	pm.scale_max = size
	var grow := Curve.new()
	grow.add_point(Vector2(0, 0.4))
	grow.add_point(Vector2(1, 1.3))
	pm.scale_curve = _curve_tex(grow)
	_fire(parent, _layer(pm, _quad(DOT, 1.2, false, Color.BLACK), 1, 0.22), pos)


# --- Building blocks --------------------------------------------------------------

static func _layer(pm: ParticleProcessMaterial, mesh: Mesh, amount: int, lifetime: float) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.process_material = pm
	p.draw_pass_1 = mesh
	p.amount = amount
	p.lifetime = lifetime
	p.emitting = false
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.visibility_aabb = AABB(Vector3(-6, -3, -6), Vector3(12, 8, 12))
	return p


## Plays a one-shot layer at `pos` and frees it afterwards.
static func _fire(parent: Node, p: GPUParticles3D, pos: Vector3, basis := Basis()) -> void:
	p.one_shot = true
	p.explosiveness = 1.0
	p.local_coords = false
	var reach := 4.0 + (p.process_material as ParticleProcessMaterial).emission_ring_radius
	p.visibility_aabb = AABB(Vector3(-reach, -3, -reach), Vector3(reach * 2, 8, reach * 2))
	parent.add_child(p)
	p.global_transform = Transform3D(basis, pos)
	p.emitting = true
	p.finished.connect(p.queue_free)


static func _can_spawn(parent: Node) -> bool:
	return is_instance_valid(parent) and parent.is_inside_tree() and DisplayServer.get_name() != "headless"


static func _quad(shape: int, energy: float, dark: bool, edge: Color) -> QuadMesh:
	var key := "%d/%.2f/%s/%s" % [shape, energy, dark, edge.to_html() if dark else ""]
	if not _quads.has(key):
		var mat := ShaderMaterial.new()
		mat.shader = DARK_SHADER if dark else MOTE_SHADER
		mat.set_shader_parameter("shape", shape)
		mat.set_shader_parameter("energy", energy)
		if dark: mat.set_shader_parameter("edge", edge)
		var quad := QuadMesh.new()
		quad.material = mat
		_quads[key] = quad
	return _quads[key]


## Grows in quickly, then shrinks away.
static func _swell() -> CurveTexture:
	var c := Curve.new()
	c.add_point(Vector2(0, 0))
	c.add_point(Vector2(0.2, 1))
	c.add_point(Vector2(1, 0))
	return _curve_tex(c)


static func _curve_tex(c: Curve) -> CurveTexture:
	var t := CurveTexture.new()
	t.curve = c
	return t


static func _ramp(colors: Array) -> GradientTexture1D:
	var offsets := PackedFloat32Array()
	for i in colors.size():
		offsets.append(float(i) / (colors.size() - 1))
	var g := Gradient.new()
	g.offsets = offsets
	g.colors = PackedColorArray(colors)
	var t := GradientTexture1D.new()
	t.gradient = g
	return t
