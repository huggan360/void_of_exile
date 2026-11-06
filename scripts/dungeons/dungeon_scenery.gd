class_name DungeonScenery
extends Node3D
## Seeded, batched voxel dressing. No colliders or changes to navigation.
var _points: Array[Transform3D] = []
var _colors := PackedColorArray()
var _prepared := PackedFloat32Array()
var _rng := RandomNumberGenerator.new()
const STONE := Color("51594e")
const MOSS := Color("4c7139")
const WOOD := Color("60432c")
const BONE := Color("b1aa82")

## theme: Dungeons.THEMES key ("moss_cave", "sand_hall", "volcano", "burning_forest").
func build(layout: DungeonLayout, theme := "moss_cave") -> void:
	prepare(layout,theme)
	publish()

## CPU-only geometry plan; safe on the world preparation worker.
func prepare(layout: DungeonLayout, theme := "moss_cave") -> void:
	_rng.seed = layout.seed_value + 87133
	var props: Array[Callable] = [_rock, _stalagmites, _mushrooms, _bones, _crate, _camp]
	match theme:
		"sand_hall": props = [_pillar, _urns, _statue, _banner, _drift, _pillar]
		"volcano": props = [_obsidian, _ember_rock, _obsidian, _bones, _ember_rock, _stalagmites]
		"burning_forest": props = [_burning_tree, _stump, _burning_tree, _ember_rock, _burning_tree, _stump]
		"blue_grotto": props = [_crystal, _coral, _crystal, _shells, _kelp, _coral]
		"drowned_spire": props = [_blue_pillar, _bell, _pews, _kelp, _blue_pillar, _shells]
	for index in layout.rooms.size():
		var room: Dictionary = layout.rooms[index]
		var center := layout.point(index)
		# Keep cardinal corridors, room centers and encounter space completely clear.
		for corner in 4:
			var angle := PI * 0.25 + corner * PI * 0.5 + _rng.randf_range(-0.18, 0.18)
			var at := center + Vector3(cos(angle), 0, sin(angle)) * (float(room.radius) - 2.0)
			props[(index + corner) % 6].call(at)
		# Halls get pillars along their walls; the forest ring burns all round.
		if theme in ["sand_hall", "burning_forest", "drowned_spire"] and room.radius >= 10:
			for k in 8:
				var a := TAU * k / 8.0
				props[0].call(center + Vector3(cos(a), 0, sin(a)) * (float(room.radius) - 1.5))
	# Grow tendrils from the floor, following actual wall faces rather than
	# crossing an opening. Every sample comes from the layout seed.
	for cell: Vector2i in (layout.floor_cells if theme == "moss_cave" else {}):
		for normal: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			if layout.open(cell.x + normal.x, cell.y + normal.y) or _rng.randf() > 0.13: continue
			var n := Vector3(normal.x, 0, normal.y)
			var tangent := Vector3(-n.z, 0, n.x)
			var base := Vector3(cell.x + 0.5, 1.025, cell.y + 0.5) + n * 0.43
			var height := _rng.randi_range(9, 30)
			for k in height:
				var p := base + Vector3.UP * k * 0.15 + tangent * (sin(k * 0.65) * 0.13)
				_voxel(p, Vector3(0.075, 0.18, 0.075), Color("3a542f"))
				if k % 2 == 0:
					_voxel(p + tangent * (0.14 if k % 4 == 0 else -0.14) - n * 0.035,
						Vector3(0.2, 0.09, 0.2), MOSS.lightened(_rng.randf() * 0.18))
			for k in 5:
				_voxel(base - n * k * 0.14 + tangent * _rng.randf_range(-0.2, 0.2), Vector3(0.22, 0.045, 0.22), MOSS.darkened(0.12))
	_prepared.resize(_points.size()*16)
	for i in _points.size():
		var t := _points[i]
		var c := _colors[i]
		var o := i*16
		# MultiMesh's packed 3D transform uses three matrix rows.
		var values := [t.basis.x.x,t.basis.y.x,t.basis.z.x,t.origin.x,
			t.basis.x.y,t.basis.y.y,t.basis.z.y,t.origin.y,
			t.basis.x.z,t.basis.y.z,t.basis.z.z,t.origin.z,c.r,c.g,c.b,c.a]
		for j in 16: _prepared[o+j] = values[j]
	_points.clear()
	_colors.clear()

## Rendering objects are published only on the main thread.
func publish() -> void:
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = true
	multi.mesh = BoxMesh.new()
	multi.instance_count = _prepared.size()/16
	multi.buffer = _prepared
	var visual := MultiMeshInstance3D.new()
	visual.multimesh = multi
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/dungeon_voxel.gdshader")
	visual.material_override = material
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(visual)
	_prepared.clear()

func _voxel(at: Vector3, size: Vector3, color: Color) -> void:
	_points.append(Transform3D(Basis.IDENTITY.scaled(size), at))
	_colors.append(color)

# --- The Sunken Court -------------------------------------------------------------

func _pillar(at: Vector3) -> void:
	var sand := Color("d6b77a")
	for y in 18:
		var w := 0.9 if y in [0, 17] else 0.7
		if y > 12 and _rng.randf() < 0.15:
			break  # some are broken off
		_voxel(at + Vector3(0, y * 0.25 + 0.125, 0), Vector3(w, 0.25, w), sand.darkened(0.08 if y % 4 == 0 else 0.0))


func _urns(at: Vector3) -> void:
	for k in _rng.randi_range(1, 3):
		var p := at + Vector3(_rng.randf_range(-0.8, 0.8), 0, _rng.randf_range(-0.8, 0.8))
		for spec: Array in [[0.15, 0.4], [0.4, 0.55], [0.65, 0.45], [0.82, 0.25]]:
			_voxel(p + Vector3(0, spec[0], 0), Vector3(spec[1], 0.2, spec[1]), Color("a8643a").darkened(_rng.randf() * 0.2))


func _statue(at: Vector3) -> void:
	_voxel(at + Vector3(0, 0.25, 0), Vector3(1.2, 0.5, 1.2), Color("bfa06a"))
	_voxel(at + Vector3(0, 1.0, 0), Vector3(0.6, 1.0, 0.45), Color("d9c08a"))
	_voxel(at + Vector3(0.25, 1.75, 0), Vector3(0.4, 0.5, 0.4), Color("e0c98f"))  # a head, knocked askew
	_voxel(at + Vector3(0.8, 0.12, 0.4), Vector3(0.4, 0.24, 0.3), Color("cbb07a"))  # its broken arm


func _banner(at: Vector3) -> void:
	_voxel(at + Vector3(0, 2.6, 0), Vector3(1.0, 0.12, 0.12), Color("6b4a2a"))
	for y in 8:
		_voxel(at + Vector3(0, 2.45 - y * 0.2, 0), Vector3(0.8, 0.2, 0.05), Color("a3242c") if y % 3 else Color("e2b45a"))


func _drift(at: Vector3) -> void:
	for k in 10:
		var p := at + Vector3(_rng.randf_range(-1.2, 1.2), 0, _rng.randf_range(-1.2, 1.2))
		_voxel(p + Vector3(0, 0.08, 0), Vector3(0.6, 0.16 + _rng.randf() * 0.2, 0.6), Color("e2c27e"))


# --- Bluelay: the Azure Grotto and the Drowned Spire ---------------------------------

func _crystal(at: Vector3) -> void:
	for k in 3:
		var p := at + Vector3(_rng.randf_range(-0.7, 0.7), 0, _rng.randf_range(-0.7, 0.7))
		var height := _rng.randi_range(5, 10)
		for y in height:
			var w := 0.36 * (1.0 - float(y) / height) + 0.1
			_voxel(p + Vector3(0, y * 0.22 + 0.11, 0), Vector3(w, 0.22, w), Color("9dffc8") if y > height / 2 else Color("2fbf7a"))


func _coral(at: Vector3) -> void:
	for k in 4:
		var p := at + Vector3(_rng.randf_range(-0.8, 0.8), 0, _rng.randf_range(-0.8, 0.8))
		var color: Color = [Color("ff7a8a"), Color("ffb36a"), Color("c48aff")][_rng.randi_range(0, 2)]
		for y in _rng.randi_range(3, 6):
			_voxel(p + Vector3(_rng.randf_range(-0.12, 0.12), y * 0.2 + 0.1, _rng.randf_range(-0.12, 0.12)), Vector3.ONE * 0.18, color)


func _shells(at: Vector3) -> void:
	for k in 6:
		_voxel(at + Vector3(_rng.randf_range(-1.0, 1.0), 0.06, _rng.randf_range(-1.0, 1.0)), Vector3(0.22, 0.1, 0.18), Color("f1e3cf"))


func _kelp(at: Vector3) -> void:
	for k in 3:
		var p := at + Vector3(_rng.randf_range(-0.6, 0.6), 0, _rng.randf_range(-0.6, 0.6))
		for y in _rng.randi_range(6, 12):
			_voxel(p + Vector3(sin(y * 0.7) * 0.15, y * 0.24 + 0.12, 0), Vector3(0.12, 0.24, 0.12), Color("2f8a5a"))


func _blue_pillar(at: Vector3) -> void:
	for y in 22:
		if y > 15 and _rng.randf() < 0.12:
			break
		var w := 0.95 if y in [0, 21] else 0.72
		_voxel(at + Vector3(0, y * 0.25 + 0.125, 0), Vector3(w, 0.25, w), Color("2a4a7a") if y % 5 else Color("8fb6ff"))


func _bell(at: Vector3) -> void:  # a fallen bronze bell, green with age
	for y in 5:
		var w := 0.5 + y * 0.18
		_voxel(at + Vector3(0, 0.9 - y * 0.18, 0), Vector3(w, 0.18, w), Color("4f8f7a").darkened(y * 0.05))
	_voxel(at + Vector3(0, 0.05, 0), Vector3(0.25, 0.1, 0.25), Color("2a3a33"))


func _pews(at: Vector3) -> void:
	for k in 2:
		_voxel(at + Vector3(0, 0.35, k * 0.9), Vector3(1.6, 0.12, 0.4), Color("3a2a22"))
		_voxel(at + Vector3(0, 0.6, k * 0.9 + 0.2), Vector3(1.6, 0.5, 0.1), Color("2f221b"))


# --- Cinder Depths and its Encore ----------------------------------------------------

func _obsidian(at: Vector3) -> void:
	for i in 3:
		var p := at + Vector3(_rng.randf_range(-0.7, 0.7), 0, _rng.randf_range(-0.7, 0.7))
		var height := _rng.randi_range(4, 9)
		for y in height:
			var w := 0.4 * (1.0 - float(y) / height) + 0.08
			_voxel(p + Vector3(0, y * 0.22 + 0.11, 0), Vector3(w, 0.22, w), Color("17121a") if y % 3 else Color("3a2a44"))


func _ember_rock(at: Vector3) -> void:
	for y in 3:
		for z in range(-2, 3):
			for x in range(-2, 3):
				if Vector3(x, y * 1.5, z).length() > 2.6: continue
				_voxel(at + Vector3(x, y + 0.5, z) * 0.22, Vector3.ONE * 0.23,
					Color("ff7a1a") if _rng.randf() < 0.18 else Color("2a2220").lightened(_rng.randf() * 0.1))


func _burning_tree(at: Vector3) -> void:
	var trunk := Color("2a1a12")
	for y in 14:
		_voxel(at + Vector3(0, y * 0.3 + 0.15, 0), Vector3(0.6, 0.3, 0.6), trunk.lightened(0.05 if y % 3 == 0 else 0.0))
	for k in 4:
		var dir := Vector3.FORWARD.rotated(Vector3.UP, k * TAU / 4.0 + _rng.randf())
		for s in 4:
			_voxel(at + Vector3(0, 3.0 + k * 0.3 + s * 0.15, 0) + dir * (0.4 + s * 0.35), Vector3.ONE * 0.25, trunk)
	for k in 14:  # flames licking up the crown
		var p := at + Vector3(_rng.randf_range(-1.2, 1.2), 3.2 + _rng.randf() * 1.6, _rng.randf_range(-1.2, 1.2))
		_voxel(p, Vector3.ONE * _rng.randf_range(0.18, 0.32), [Color("ff4a12"), Color("ff9a2a"), Color("ffd24a")][_rng.randi_range(0, 2)])


func _stump(at: Vector3) -> void:
	_voxel(at + Vector3(0, 0.3, 0), Vector3(0.9, 0.6, 0.9), Color("2a1a12"))
	for k in 5:
		_voxel(at + Vector3(_rng.randf_range(-0.3, 0.3), 0.7 + _rng.randf() * 0.3, _rng.randf_range(-0.3, 0.3)), Vector3.ONE * 0.18, Color("ff8a2a"))


func _rock(at: Vector3) -> void:
	for y in 4:
		for z in range(-3, 4):
			for x in range(-3, 4):
				if Vector3(x, y * 1.5, z).length() > 3.6: continue
				_voxel(at + Vector3(x, y + 0.5, z) * 0.21, Vector3.ONE * 0.22,
					MOSS if y >= 2 and _rng.randf() < 0.5 else STONE.darkened(_rng.randf() * 0.3))

func _stalagmites(at: Vector3) -> void:
	for i in 4:
		var p := at + Vector3(_rng.randf_range(-0.6, 0.6), 0, _rng.randf_range(-0.6, 0.6))
		var height := _rng.randi_range(5, 11)
		for y in height:
			var width := 0.14 + (height - y) * 0.042
			_voxel(p + Vector3.UP * (y + 0.5) * 0.18, Vector3(width, 0.18, width), STONE.lightened(y * 0.015))

func _mushrooms(at: Vector3) -> void:
	for i in 7:
		var p := at + Vector3(_rng.randf_range(-0.65, 0.65), 0, _rng.randf_range(-0.65, 0.65))
		var height := _rng.randf_range(0.2, 0.65)
		_voxel(p + Vector3.UP * height * 0.5, Vector3(0.09, height, 0.09), Color("ada47a"))
		for z in range(-1, 2):
			for x in range(-1, 2):
				_voxel(p + Vector3(x * 0.12, height + (0.07 if x == 0 and z == 0 else 0), z * 0.12), Vector3(0.13, 0.12, 0.13), Color("819955") if i % 2 else Color("98704d"))
		_voxel(p + Vector3(0.12, height + 0.07, 0), Vector3.ONE * 0.055, BONE)

func _bones(at: Vector3) -> void:
	for i in 9:
		var p := at + Vector3(_rng.randf_range(-0.65, 0.65), 0.08, _rng.randf_range(-0.65, 0.65))
		var size := Vector3(0.38, 0.08, 0.08) if i % 2 else Vector3(0.08, 0.08, 0.38)
		_voxel(p, size, BONE.darkened(_rng.randf() * 0.2))
	_voxel(at + Vector3.UP * 0.16, Vector3(0.27, 0.25, 0.23), BONE)
	for side in [-1.0, 1.0]:
		_voxel(at + Vector3(side * 0.07, 0.19, 0.12), Vector3.ONE * 0.065, Color("282b22"))

func _crate(at: Vector3) -> void:
	for i in 5:
		_voxel(at + Vector3((i - 2) * 0.18, 0.06, 0), Vector3(0.16, 0.12, 0.85), WOOD)
		if i != 2:
			_voxel(at + Vector3((i - 2) * 0.18, 0.28 + (i % 2) * 0.1, -0.4), Vector3(0.16, 0.5 + (i % 2) * 0.2, 0.1), WOOD.lightened(0.12))
	for y in [0.16, 0.42]:
		_voxel(at + Vector3(0, y, -0.46), Vector3(0.92, 0.07, 0.06), Color("353a32"))
	for i in 3:
		_voxel(at + Vector3(_rng.randf_range(-0.7, 0.7), 0.06, 0.65 + i * 0.16), Vector3(0.7, 0.09, 0.12), WOOD)

func _camp(at: Vector3) -> void:
	for i in 9:
		var angle := i * TAU / 9.0
		_voxel(at + Vector3(cos(angle) * 0.45, 0.12, sin(angle) * 0.45), Vector3(0.2, 0.22, 0.2), STONE)
	_voxel(at + Vector3.UP * 0.04, Vector3(0.65, 0.07, 0.65), Color("1d211c"))
	for i in 3:
		_voxel(at + Vector3(0, 0.13, (i - 1) * 0.15), Vector3(0.6, 0.12, 0.1), WOOD.darkened(0.4))
	var pole := at + Vector3(0.9, 0, 0.6)
	_voxel(pole + Vector3.UP * 0.9, Vector3(0.09, 1.8, 0.09), WOOD)
	for x in 4:
		for y in range(2 if x % 2 else 1, 5):
			_voxel(pole + Vector3(0.1 + x * 0.14, 0.8 + y * 0.16, 0), Vector3(0.14, 0.16, 0.055), Color("6b4732") if x % 2 else Color("53633a"))
	_bones(at + Vector3(-0.6, 0, 0.7))
