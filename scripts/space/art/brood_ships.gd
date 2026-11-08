class_name BroodShip
extends Node3D
## The brood's living ships, kin of the Theory of Everything's creatures:
## black chitin, acid-green eyes and vents, fairy-pink glow sacs. Each faces
## -Z. Skiffs are darting fighters, void eels long serpents whose segments
## follow the head's path, carriers great hive-hulks that spill skiffs.
const Art = preload("res://scripts/space/art/ship_hull.gd").ArtBatch
const CHITIN := Color("0b0910")
const CHITIN_LIGHT := Color("1a1522")
const ACID := Color("7dff6a")
const PINK := Color("ff5fd2")
const SEGMENTS := 11
const SEGMENT_GAP := 5.2

var kind := ""
var segments: Array[Node3D] = []
var _trail: Array[Vector3] = []
var _wing: Array[Node3D] = []
var _time := 0.0
var health := 1.0
var _ghost := 1.0
var _bar: MeshInstance3D
var _bar_material: ShaderMaterial
static var _bar_mesh: QuadMesh
const BAR_HEIGHT := {brood_skiff = 7.0, void_eel = 9.0, brood_carrier = 34.0, brood_mother = 52.0}

func build(foe_kind: String) -> void:
	kind = foe_kind
	match kind:
		"void_eel": _eel()
		"brood_carrier", "brood_mother": _carrier(kind=="brood_mother")
		_: _skiff()
	if _bar_mesh==null:
		_bar_mesh = QuadMesh.new()
		_bar_mesh.size = Vector2.ONE
	_bar_material = ShaderMaterial.new()
	_bar_material.shader = preload("res://shaders/space_health_bar.gdshader")
	_bar = MeshInstance3D.new()
	_bar.mesh = _bar_mesh
	_bar.material_override = _bar_material
	_bar.position.y = float(BAR_HEIGHT.get(kind, 8.0))
	_bar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_bar.custom_aabb = AABB(-Vector3.ONE*4.0, Vector3.ONE*8.0)
	_bar.visible = false
	add_child(_bar)

## Health 0..1 from the authority; the bar shows once the ship is hurt.
func set_health(value: float) -> void:
	health = clampf(value, 0.0, 1.0)

## The game's hit glitch on the blocks near `at`.
func glitch(at: Vector3) -> void:
	ArtGlitch.flash(self, at, 5.0 if kind=="brood_skiff" else 9.0, 0.45 if kind=="brood_skiff" else 0.8)

## Moves the trailing segments and flaps; call each frame after placing the ship.
func animate(delta: float) -> void:
	_time += delta
	_ghost = move_toward(_ghost, health, delta*0.6)
	if is_instance_valid(_bar):
		var camera := get_viewport().get_camera_3d()
		_bar.visible = health<0.999 and camera!=null and camera.global_position.distance_to(global_position)<3500.0
		_bar_material.set_shader_parameter("fill", health)
		_bar_material.set_shader_parameter("ghost", _ghost)
	for i in _wing.size():
		_wing[i].rotation.z = sin(_time*7.0+i*PI)*0.18*(1.0 if i % 2 else -1.0)
	if segments.is_empty(): return
	# The eel's body follows the path its head took.
	if _trail.is_empty() or _trail[0].distance_to(global_position)>1.0:
		_trail.push_front(global_position)
		while _trail.size()>SEGMENTS*8: _trail.pop_back()
	for i in segments.size():
		var want := global_position+global_basis.z*SEGMENT_GAP*(i+1)
		var along := float(SEGMENT_GAP*(i+1))
		var walked := 0.0
		for k in range(1, _trail.size()):
			walked += _trail[k-1].distance_to(_trail[k])
			if walked>=along:
				want = _trail[k]
				break
		var seg := segments[i]
		var ahead := global_position if i==0 else segments[i-1].global_position
		seg.global_position = want+global_basis.x*sin(_time*3.0-i*0.6)*0.6*i*0.2
		if seg.global_position.distance_to(ahead)>0.1:
			seg.look_at(ahead, global_basis.y)

func _skiff() -> void:
	var art := Art.new(self)
	# A tapering chitin body, plated ridge and mandible prongs.
	for k in 9:
		var z := -8.0+k*2.0
		var w := 1.2+sin(float(k)/8.0*PI)*1.8
		art.box(Vector3(0, 0, z), Vector3(w*2.0, w*1.1, 2.1), CHITIN if k % 2 else CHITIN_LIGHT)
		art.box(Vector3(0, w*0.6, z), Vector3(0.5, 0.6, 1.6), CHITIN_LIGHT)
	for side: float in [-1.0, 1.0]:
		art.beam(Vector3(side*1.0, -0.2, -8.0), Vector3(side*0.4, -0.6, -13.0), 0.5, CHITIN_LIGHT)
		art.part("sphere", Vector3(side*1.3, 0.6, -7.2), Vector3.ONE*0.75, ACID, 4.0)
		art.box(Vector3(side*1.9, -0.5, 6.0), Vector3(0.4, 0.4, 1.6), PINK, 3.0)
	art.part("sphere", Vector3(0, 0, 9.2), Vector3(1.6, 1.6, 0.4), ACID, 4.5)
	# Tail spine.
	for k in 4: art.box(Vector3(0, 0.3+k*0.2, 10.0+k*1.6), Vector3(0.6-k*0.1, 0.6-k*0.1, 1.6), CHITIN)
	art.finish()
	for side: float in [-1.0, 1.0]:
		var wing := Node3D.new()
		wing.position = Vector3(side*2.4, 0.4, 0.0)
		add_child(wing)
		_wing.append(wing)
		var w := Art.new(wing)
		for k in 4:
			w.box(Vector3(side*(1.6+k*1.5), -k*0.15, 1.0+k*0.9), Vector3(1.6, 0.16, 5.5-k*0.9), CHITIN_LIGHT if k % 2 else CHITIN)
		w.box(Vector3(side*7.0, -0.5, 3.6), Vector3(0.5, 0.2, 2.0), ACID, 3.0)
		w.finish()

func _eel() -> void:
	var art := Art.new(self)
	# The head: a long jaw, rows of glowing eyes, a crest of spines.
	for k in 5:
		var z := -6.0+k*2.4
		var w := 2.2+k*0.35
		art.box(Vector3(0, 0, z), Vector3(w*2.0, w*1.2, 2.5), CHITIN if k % 2 else CHITIN_LIGHT)
		art.box(Vector3(0, w*0.75, z), Vector3(0.6, 1.2+k*0.3, 1.0), CHITIN_LIGHT)
	for side: float in [-1.0, 1.0]:
		art.box(Vector3(side*1.6, -1.6, -7.5), Vector3(0.8, 0.6, 5.0), CHITIN_LIGHT)
		for e in 3: art.part("sphere", Vector3(side*(1.9+e*0.25), 0.9, -5.0+e*1.4), Vector3.ONE*(0.7-e*0.12), ACID, 4.5)
	art.finish()
	for i in SEGMENTS:
		var seg := Node3D.new()
		seg.name = "Segment%d" % i
		add_child(seg)
		seg.top_level = true
		segments.append(seg)
		var a := Art.new(seg)
		var w := 3.2-i*0.22
		a.box(Vector3.ZERO, Vector3(w*2.0, w*1.2, SEGMENT_GAP*0.95), CHITIN if i % 2 else CHITIN_LIGHT)
		a.box(Vector3(0, w*0.7, 0), Vector3(0.5, 1.0+w*0.3, 2.0), CHITIN_LIGHT)
		if i % 3==1:
			for side: float in [-1.0, 1.0]:
				a.part("sphere", Vector3(side*w*1.02, -0.2, 0), Vector3(0.9, 1.3, 1.6), PINK, 3.0)
		if i % 2==0:
			for side: float in [-1.0, 1.0]:
				a.box(Vector3(side*(w+1.2), 0, 0.8), Vector3(2.4, 0.15, 2.2), CHITIN_LIGHT)
		a.finish()

func _carrier(mother: bool) -> void:
	var s := 1.5 if mother else 1.0
	var art := Art.new(self)
	# A swollen hive-hulk: lobed belly, ribbed back, a glowing launch maw.
	for k in 7:
		var z := (-36.0+k*12.0)*s
		var r := (14.0+sin(float(k)/6.0*PI)*10.0)*s
		art.part("sphere", Vector3(0, 0, z), Vector3(r*2.0, r*1.5, 16.0*s), CHITIN if k % 2 else CHITIN_LIGHT)
		art.box(Vector3(0, r*0.78, z), Vector3(3.0*s, 4.0*s+k % 3*2.0, 6.0*s), CHITIN_LIGHT)
		for side: float in [-1.0, 1.0]:
			art.beam(Vector3(side*r*0.8, r*0.4, z), Vector3(side*(r+8.0*s), -r*0.3, z+5.0*s), 1.4*s, CHITIN_LIGHT)
	for i in 18:
		var a := i*2.39996
		var at := Vector3(cos(a)*16.0*s, sin(a)*10.0*s-4.0*s, (-24.0+i*3.4)*s)
		art.part("sphere", at, Vector3.ONE*(2.0+i % 3)*s, ACID if i % 4 else PINK, 2.0)
	art.part("sphere", Vector3(0, -2.0*s, -46.0*s), Vector3(12.0, 9.0, 4.0)*s, ACID, 3.0)
	for side: float in [-1.0, 1.0]:
		art.box(Vector3(side*6.0*s, -2.0*s, -50.0*s), Vector3(2.0, 3.0, 12.0)*s, CHITIN_LIGHT)
		for e in 4: art.part("sphere", Vector3(side*(8.0+e*2.0)*s, 6.0*s, (-40.0+e*3.0)*s), Vector3.ONE*1.6*s, ACID, 4.5)
	if mother:
		for k in 8: art.box(Vector3(0, 0, (40.0+k*6.0)), Vector3(8.0-k*0.8, 8.0-k*0.8, 6.0), CHITIN if k % 2 else CHITIN_LIGHT)
	art.finish()
